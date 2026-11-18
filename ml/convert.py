#!/usr/bin/env -S uv run --script
# /// script
# requires-python = "==3.12.13"
# dependencies = ["coremltools==9.0", "numpy==2.2.6", "pillow==11.3.0", "typer==0.16.0", "rich==14.0.0", "torch==2.7.0", "transformers==4.51.3", "tokenizers==0.21.4"]
# ///
"""Convert and qualify the bounded affine image fixture; publish portable data."""

import hashlib
import importlib.metadata
import io
import json
import logging
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile
import uuid
from enum import Enum
from pathlib import Path
from typing import Annotated

import typer
from rich.console import Console
from rich.logging import RichHandler

app = typer.Typer(no_args_is_help=True, pretty_exceptions_enable=False)
console = Console(stderr=True)
log = logging.getLogger(__name__)
INPUTS = {"image": {"type": "image", "dtype": "uint8", "shape": [28, 28]}}
OUTPUTS = {
    "classLabel": {"type": "int64"},
    "labelProbabilities": {"type": "dictionary", "key_type": "int64", "count": 10},
}
PARITY = {
    "precision": "float32",
    "atol": 1e-4,
    "rtol": 1e-4,
    "fixtures": ["seven", "zeros", "full", "ramp"],
}


class ModelFormat(str, Enum):
    neuralnetwork = "neuralnetwork"
    mlprogram = "mlprogram"


def encoded(value):
    return (
        json.dumps(value, sort_keys=True, indent=2, allow_nan=False) + "\n"
    ).encode()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def file_record(data):
    return {"bytes": len(data), "sha256": digest(data)}


def read_source(path):
    source = json.loads(path.read_bytes())
    if (
        source.get("schema") != 1
        or source.get("features") != INPUTS
        or source.get("outputs") != OUTPUTS
    ):
        raise ValueError(
            "Unsupported source feature metadata; require image uint8[28,28] and ten int64-key probabilities"
        )
    if (
        source.get("parity") != PARITY
        or source.get("image_scale") != 1 / 255
        or source.get("license") != "BSD-3-Clause"
    ):
        raise ValueError(
            "Unsupported source precision, preprocessing, license or parity contract"
        )
    import numpy as np

    weights = np.zeros((10, 784), dtype=np.float32)
    seen = set()
    for row, column, weight in source["weights"]:
        if (
            type(row) is not int
            or type(column) is not int
            or not 0 <= row < 10
            or not 0 <= column < 784
            or (row, column) in seen
        ):
            raise ValueError("Invalid or duplicate sparse source weight")
        seen.add((row, column))
        weights[row, column] = weight
    bias = np.asarray(source["bias"], dtype=np.float32)
    if (
        bias.shape != (10,)
        or not np.isfinite(weights).all()
        or not np.isfinite(bias).all()
    ):
        raise ValueError("Source requires ten finite biases and finite FP32 weights")
    return source, weights, bias


def convert(source, weights, bias, output, model_format):
    import coremltools as ct
    from coremltools.models import datatypes
    from coremltools.models.neural_network import NeuralNetworkBuilder

    if model_format == ModelFormat.mlprogram:
        from coremltools.converters.mil import Builder as mb

        @mb.program(
            input_specs=[mb.TensorSpec(shape=(1, 1, 28, 28))],
            opset_version=ct.target.iOS15,
        )
        def graph(image):
            pixels = mb.reshape(x=image, shape=(1, 784))
            logits = mb.linear(x=pixels, weight=weights, bias=bias)
            return mb.softmax(x=logits, axis=-1, name="probabilities")

        converted = ct.convert(
            graph,
            convert_to="mlprogram",
            compute_precision=ct.precision.FLOAT32,
            minimum_deployment_target=ct.target.iOS15,
            inputs=[
                ct.ImageType(
                    name="image",
                    shape=(1, 1, 28, 28),
                    color_layout=ct.colorlayout.GRAYSCALE,
                    scale=source["image_scale"],
                )
            ],
            classifier_config=ct.ClassifierConfig(
                list(range(10)), predicted_feature_name="classLabel"
            ),
            skip_model_load=True,
        )
        spec = converted.get_spec()
        ct.utils.rename_feature(spec, "classLabel_probs", "labelProbabilities")
        # coremltools adds today's date; it is not part of portable graph identity.
        spec.description.metadata.userDefined.pop(
            "com.github.apple.coremltools.conversion_date", None
        )
        ct.models.MLModel(
            spec, weights_dir=converted.weights_dir, skip_model_load=True
        ).save(str(output))
        # Use protobuf's stock deterministic map encoding, not randomized map order.
        (output / "Data/com.apple.CoreML/model.mlmodel").write_bytes(
            spec.SerializeToString(deterministic=True)
        )
        index = output / "Manifest.json"
        plan = json.loads(index.read_bytes())
        mapping = {
            old: str(uuid.uuid5(uuid.NAMESPACE_URL, entry["path"])).upper()
            for old, entry in plan["itemInfoEntries"].items()
        }
        plan["itemInfoEntries"] = {
            mapping[key]: value for key, value in plan["itemInfoEntries"].items()
        }
        plan["rootModelIdentifier"] = mapping[plan["rootModelIdentifier"]]
        index.write_bytes(encoded(plan))
        return

    builder = NeuralNetworkBuilder(
        [("image", datatypes.Array(1, 28, 28))],
        [("labelProbabilities", datatypes.Array(10))],
        mode="classifier",
    )
    builder.add_flatten("flatten", mode=0, input_name="image", output_name="pixels")
    builder.add_inner_product(
        "affine", weights, bias, 784, 10, True, "pixels", "logits"
    )
    builder.add_softmax("probabilities", "logits", "labelProbabilities")
    builder.set_class_labels(
        list(range(10)),
        predicted_feature_name="classLabel",
        prediction_blob="labelProbabilities",
    )
    builder.set_pre_processing_parameters(
        image_input_names=["image"], image_scale=source["image_scale"]
    )
    builder.spec.description.metadata.shortDescription = source["description"]
    builder.spec.description.metadata.license = "BSD-3-Clause; see included LICENSE.txt"
    output.write_bytes(builder.spec.SerializeToString(deterministic=True))


def qualify(source, bias, model, seven):
    import coremltools as ct
    import numpy as np
    from PIL import Image

    spec = ct.utils.load_spec(str(model))
    description = spec.description
    if (
        len(description.input) != 1
        or description.input[0].name != "image"
        or description.input[0].type.WhichOneof("Type") != "imageType"
    ):
        raise ValueError("Converted model input metadata differs from source")
    image = description.input[0].type.imageType
    outputs = {item.name: item.type.WhichOneof("Type") for item in description.output}
    probabilities = next(
        (item for item in description.output if item.name == "labelProbabilities"), None
    )
    if (
        (image.width, image.height, image.colorSpace) != (28, 28, 10)
        or outputs
        != {"classLabel": "int64Type", "labelProbabilities": "dictionaryType"}
        or probabilities.type.dictionaryType.WhichOneof("KeyType") != "int64KeyType"
    ):
        raise ValueError(
            "Converted model feature metadata differs from declared adapter"
        )
    runtime = ct.models.MLModel(str(model), compute_units=ct.ComputeUnit.CPU_ONLY)
    fixtures = [
        np.frombuffer(seven, dtype=np.uint8).reshape(28, 28),
        np.zeros((28, 28), dtype=np.uint8),
        np.full((28, 28), 255, dtype=np.uint8),
        (np.arange(784) % 256).astype(np.uint8).reshape(28, 28),
    ]
    maximum = 0.0
    rows = []
    for name, pixels in zip(source["parity"]["fixtures"], fixtures, strict=True):
        # Evaluate the source's sparse graph independently of the dense Core ML graph.
        logits = bias.copy()
        for row, column, weight in source["weights"]:
            logits[row] += (
                np.float32(weight)
                * np.float32(pixels.flat[column])
                * np.float32(source["image_scale"])
            )
        expected = np.exp(logits - logits.max())
        expected /= expected.sum()
        result = runtime.predict({"image": Image.fromarray(pixels)})
        actual = np.array([result["labelProbabilities"][i] for i in range(10)])
        label = int(result["classLabel"])
        if (
            not np.isfinite(actual).all()
            or not np.allclose(
                actual, expected, atol=PARITY["atol"], rtol=PARITY["rtol"]
            )
            or label != int(expected.argmax())
            or abs(actual.sum() - 1) > 1e-4
            or (name == "seven" and label != 7)
        ):
            raise ValueError(
                f"FP32 parity failed for {name}; package was not published"
            )
        error = float(np.max(np.abs(actual - expected)))
        maximum = max(maximum, error)
        rows.append(
            {
                "fixture": name,
                "label": label,
                "reference": expected.tolist(),
                "coreml": actual.tolist(),
                "max_absolute_error": error,
            }
        )
    return {
        "passed": True,
        "fixtures": len(fixtures),
        "atol": PARITY["atol"],
        "rtol": PARITY["rtol"],
        "max_absolute_error": maximum,
        "results": rows,
    }


def publish(source_path, model, output):
    source, _, bias = read_source(source_path)
    root = Path(__file__).resolve().parent
    seven = (root / "tests/seven.gray").read_bytes()
    if (
        digest(seven)
        != "8f6a418c9a639f9e14e96feca47a97df2a35a0a68ae2875431c5c80e05536941"
    ):
        raise ValueError("Known-answer fixture hash mismatch")
    is_program = model.is_dir() and model.suffix == ".mlpackage"
    model_name = "model.mlpackage" if is_program else "MNISTClassifier.mlmodel"
    portable = {}
    if is_program:
        portable[model_name] = None
        for path in sorted(model.rglob("*")):
            if path.is_symlink():
                raise ValueError("Symlink in converted model")
            portable[model_name + "/" + path.relative_to(model).as_posix()] = (
                None if path.is_dir() else path.read_bytes()
            )
    else:
        if model.stat().st_size > 1048576:
            raise ValueError("Model exceeds the fixture's bounded 1 MiB member limit")
        portable[model_name] = model.read_bytes()
    model_bytes = sum(len(data) for data in portable.values() if data is not None)
    model_hash = (
        digest(
            "".join(
                f"{digest(data)}  {name[len(model_name) + 1 :]}\n"
                for name, data in portable.items()
                if data is not None
            ).encode()
        )
        if is_program
        else digest(portable[model_name])
    )
    parity = qualify(source, bias, model, seven)
    minimum_ios = "15.0" if is_program else "14.0"
    license_data = (root.parent / "LICENSE").read_bytes()
    versions = {
        name: importlib.metadata.version(name)
        for name in ("coremltools", "numpy", "pillow", "typer", "rich", "protobuf")
    }
    revision = subprocess.check_output(
        ["git", "-C", str(root), "rev-parse", "HEAD"], text=True
    ).strip()
    recipe = {
        "source": source,
        "source_file_sha256": digest(source_path.read_bytes()),
        "converter": "coremltools MIL: sparse affine -> FP32 ML Program classifier"
        if is_program
        else "coremltools NeuralNetworkBuilder: sparse affine -> flatten/innerProduct/softmax classifier",
        "converter_sha256": digest(Path(__file__).read_bytes()),
        "dependencies": versions,
        "python": platform.python_version(),
        "precision": "float32",
        "compute_units_for_parity": "CPU_ONLY",
        "minimum_ios": minimum_ios,
        "model_format": "mlprogram" if is_program else "neuralnetwork",
        "portable_model": {"bytes": model_bytes, "sha256": model_hash},
        "fixture": {
            "sha256": digest(seven),
            "label": 7,
            "provenance": "First MNIST test image; archive and label digests in ml/README.md",
        },
    }
    members = {
        **portable,
        "LICENSE.txt": license_data,
        "recipe.json": encoded(recipe),
        "seven.gray": seven,
    }
    manifest = {
        "schema": 1,
        "package_format": "ashell-model-ustar-v1",
        "model_id": "mnist",
        "version": source["version"],
        "task": "drawing-classification",
        "runtime": "CoreML",
        "runtime_abi": 1,
        "minimum_ios": minimum_ios,
        "model": model_name,
        "license_file": "LICENSE.txt",
        "recipe": "recipe.json",
        "limits": {"archive_bytes": 2097152, "member_bytes": 1048576},
        "source_revision": "sha256:" + digest(source_path.read_bytes()),
        "source_url": "https://example.invalid/affine-image-fixture",
        "source_bytes": model_bytes,
        "source_sha256": model_hash,
        "features": INPUTS,
        "outputs": OUTPUTS,
        "adapter_version": 1,
        "preprocessing": "28x28 grayscale uint8; scale 1/255; no resize",
        "tokenizer": None,
        "decoder": "classLabel and labelProbabilities",
        "license": "BSD-3-Clause",
        "license_url": "https://github.com/holzschu/a-shell/blob/master/LICENSE",
        "license_bytes": len(license_data),
        "license_sha256": digest(license_data),
        "disk_estimate_bytes": 8388608,
        "memory_profile": {
            "kind": "bounded-skeleton-estimate",
            "additional_peak_bytes": 67108864,
        },
        "validation": {"input": "seven.gray", "input_hex": seven.hex(), "label": "7"},
        "members": {
            name: {
                "type": "directory" if data is None else "file",
                **file_record(data or b""),
            }
            for name, data in members.items()
        },
    }
    manifest_data = encoded(manifest)
    if len(manifest_data) > 1048576 or any(
        len(data) > 1048576 for data in members.values() if data is not None
    ):
        raise ValueError("Package exceeds the fixture's declared member limits")
    archive_bytes = io.BytesIO()
    with tarfile.open(
        fileobj=archive_bytes, mode="w", format=tarfile.USTAR_FORMAT
    ) as archive:
        for name, data in {"manifest.json": manifest_data, **members}.items():
            entry = tarfile.TarInfo(name)
            entry.size = len(data) if data is not None else 0
            entry.mode = 0o644 if data is not None else 0o755
            entry.type = tarfile.REGTYPE if data is not None else tarfile.DIRTYPE
            archive.addfile(entry, io.BytesIO(data) if data is not None else None)
    data = archive_bytes.getvalue()
    if len(data) > manifest["limits"]["archive_bytes"]:
        raise ValueError("Package exceeds the fixture's declared archive limit")
    # The output directory is exclusively owned by this invocation; never replace evidence.
    output.mkdir(parents=True, exist_ok=False)
    package = output / "mnist.asmodel"
    pending = output / ".mnist.asmodel.tmp"
    pending.write_bytes(data)
    pending.replace(package)
    receipt = {
        "package": str(package.resolve()),
        "archive": file_record(data),
        "manifest_sha256": digest(encoded(manifest)),
        "members": manifest["members"],
        "source": {
            "git_revision": revision,
            "recipe_sha256": digest(source_path.read_bytes()),
            "converter_sha256": recipe["converter_sha256"],
        },
        "runtime": {
            "platform": platform.platform(),
            "macos_build": subprocess.check_output(
                ["sw_vers", "-buildVersion"], text=True
            ).strip(),
            "python": platform.python_version(),
            "dependencies": versions,
            "dependency_lock_sha256": digest(
                Path(__file__).with_suffix(".py.lock").read_bytes()
            ),
        },
        "parity": parity,
    }
    (output / "receipt.json").write_bytes(encoded(receipt))
    return receipt


def execute(source, output, model=None, model_format=ModelFormat.neuralnetwork):
    try:
        if platform.system() != "Darwin":
            raise ValueError("Core ML parity requires macOS")
        if output.exists():
            raise ValueError(
                "Output already exists; choose a clean owned output directory"
            )
        if model is None:
            parsed, weights, bias = read_source(source)
            with tempfile.TemporaryDirectory(prefix="ashell-convert-") as scratch:
                converted = Path(scratch) / (
                    "fixture.mlpackage"
                    if model_format == ModelFormat.mlprogram
                    else "fixture.mlmodel"
                )
                convert(parsed, weights, bias, converted, model_format)
                receipt = publish(source, converted, output)
        else:
            receipt = publish(source, model, output)
        sys.stdout.buffer.write(encoded(receipt))
    except (KeyboardInterrupt, BrokenPipeError) as error:
        raise typer.Exit(130 if isinstance(error, KeyboardInterrupt) else 0) from None
    except Exception as error:
        log.error("%s", error)
        log.debug("Conversion failed", exc_info=True)
        raise typer.Exit(1) from None


@app.callback()
def main(
    verbose: Annotated[bool, typer.Option("--verbose", "-v")] = False,
    quiet: Annotated[bool, typer.Option("--quiet", "-q")] = False,
):
    logging.basicConfig(
        level=logging.DEBUG if verbose else logging.ERROR if quiet else logging.WARNING,
        handlers=[RichHandler(console=console, markup=False, show_path=False)],
    )


@app.command()
def build(
    source: Annotated[Path, typer.Option(exists=True, dir_okay=False)],
    output: Annotated[Path, typer.Option()],
    model_format: Annotated[
        ModelFormat, typer.Option("--format")
    ] = ModelFormat.neuralnetwork,
):
    """Convert the supported source, check features/parity, then write one archive."""
    execute(source, output, model_format=model_format)


@app.command()
def package(
    source: Annotated[Path, typer.Option(exists=True, dir_okay=False)],
    model: Annotated[Path, typer.Option(exists=True)],
    output: Annotated[Path, typer.Option()],
):
    """Qualify an existing converted model against its source before packaging."""
    execute(source, output, model)


class EmbeddingPrecision(str, Enum):
    float32 = "float32"
    float16 = "float16"
    int8 = "int8"


def embedding_space(path, additional):
    free = shutil.disk_usage(path).free
    required = 30 * 1024**3 + additional
    if free < required:
        raise ValueError(
            f"Embedding stage needs {required} free bytes including the 30 GiB reserve; observed {free}"
        )


def embedding_build(model_id, source, precision, runtime, output):
    """Export fixed hidden states; qualify native tokenization and pooling independently."""
    root = Path(__file__).resolve().parent
    recipe_bytes = (root / "models/embeddings.json").read_bytes()
    recipe = json.loads(recipe_bytes)["models"][model_id]
    if output.exists():
        raise ValueError("Output already exists; choose a clean owned directory")
    output.parent.mkdir(parents=True, exist_ok=True)
    # Qwen FP32 is a host reference, larger than the existing 2 GiB package ceiling.
    if model_id.startswith("qwen") and precision == EmbeddingPrecision.float32:
        raise ValueError(
            "Qwen FP32 exceeds package v1's 2 GiB ceiling; use source FP32 reference with float16 or int8 export"
        )
    embedding_space(
        output.parent, max(1024**3, recipe["files"]["model.safetensors"]["bytes"] * 10)
    )
    for name, expected in recipe["files"].items():
        path = source / name
        if (
            path.is_symlink()
            or not path.is_file()
            or file_record(path.read_bytes()) != expected
        ):
            raise ValueError(f"Pinned embedding source receipt mismatch: {name}")
    # Host conversion dependencies only; the app still links Apple's Core ML runtime.
    import coremltools as ct
    import numpy as np
    import torch
    from tokenizers import Tokenizer
    from transformers import AutoModel

    is_qwen = model_id.startswith("qwen")
    width = 1024 if is_qwen else 384
    torch.set_num_threads(2)
    model = AutoModel.from_pretrained(
        str(source.resolve()),
        local_files_only=True,
        torch_dtype=torch.float32,
        attn_implementation="eager",
    ).eval()
    model.config.use_cache = False
    tokenizer = Tokenizer.from_file(str(source / "tokenizer.json"))
    tokenizer.enable_truncation(max_length=128)
    tokenizer.enable_padding(
        length=128,
        direction="left" if is_qwen else "right",
        pad_id=151643 if is_qwen else 0,
        pad_token="<|endoftext|>" if is_qwen else "[PAD]",
    )
    corpus_bytes = (root / "models/embedding-corpus.json").read_bytes()
    corpus = json.loads(corpus_bytes)
    frozen_tokens = json.loads(
        (root / "models/embedding-tokenizers.json").read_bytes()
    )["models"][model_id]
    cases = [entry["request"] for entry in frozen_tokens["cases"]]
    query = {"texts": corpus["queries"]}
    if is_qwen:
        query["instruction"] = corpus["instruction"]
    requests = [*cases, {"texts": corpus["documents"]}, query]

    def inputs(request):
        texts = request["texts"]
        if "instruction" in request:
            texts = [
                f"Instruct: {request['instruction']}\nQuery:{text}" for text in texts
            ]
        return tokenizer.encode_batch(texts)

    def pool(hidden, mask):
        pooled = (
            hidden[:, -1]
            if is_qwen
            else (hidden * mask[..., None]).sum(1) / mask.sum(1, keepdims=True)
        )
        return pooled / np.linalg.norm(pooled, axis=1, keepdims=True)

    class Graph(torch.nn.Module):
        def __init__(self, transformer):
            super().__init__()
            self.transformer = transformer

        def forward(self, input_ids, attention_mask):
            return self.transformer(
                input_ids=input_ids,
                attention_mask=attention_mask,
                return_dict=False,
                use_cache=False,
            )[0]

    graph = Graph(model).eval()
    references = []
    with torch.no_grad():
        for request in requests:
            encodings = inputs(request)
            masks = np.asarray([e.attention_mask for e in encodings], dtype=np.int32)
            hidden = np.concatenate(
                [
                    graph(
                        torch.tensor([e.ids]), torch.tensor([e.attention_mask])
                    ).numpy()
                    for e in encodings
                ]
            )
            vectors = pool(hidden, masks)
            references.append(
                {
                    "request": request,
                    "expected": vectors.tolist(),
                    "token_counts": masks.sum(1).tolist(),
                    "truncated": [bool(e.overflowing) for e in encodings],
                }
            )
        encoding = inputs(requests[0])[0]
        example = (
            torch.tensor([encoding.ids], dtype=torch.int32),
            torch.tensor([encoding.attention_mask], dtype=torch.int32),
        )
        traced = torch.jit.trace(graph, example, strict=True)
    del graph, model
    # The source attention mask uses -FLT_MAX. Keep its arithmetic and norms in
    # FP32: casting that sentinel to FP16 overflows and produced nonfinite states.
    # Qwen's causal mask also traverses selection/shape updates; FP16 infinities
    # there contaminated every hidden state in the public conversion parity run.
    # Qwen explicitly evaluates RMSNorm in FP32. Source inputs reach 6922;
    # squaring them in FP16 overflows and can reduce the final vector to zero.
    qwen_fp32_ops = (
        (
            "select",
            "expand_dims",
            "tile",
            "slice_by_index",
            "slice_update",
            "concat",
            "pow",
            "reduce_mean",
            "rsqrt",
        )
        if is_qwen
        else ()
    )
    compute = (
        ct.precision.FLOAT32
        if precision == EmbeddingPrecision.float32
        else ct.transform.FP16ComputePrecision(
            op_selector=lambda op: (
                op.op_type
                not in (
                    "gather",
                    "gather_nd",
                    "add",
                    "sub",
                    "mul",
                    "real_div",
                    "layer_norm",
                    "softmax",
                )
                and op.op_type not in qwen_fp32_ops
            )
        )
    )
    converted = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="input_ids", shape=(1, 128), dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=(1, 128), dtype=np.int32),
        ],
        outputs=[ct.TensorType(name="hidden_states", dtype=np.float32)],
        minimum_deployment_target=ct.target.iOS18,
        compute_precision=compute,
        convert_to="mlprogram",
        skip_model_load=True,
    )
    del traced
    baseline_predictions = []

    def qualify_model(candidate, threshold, against):
        rows, predictions = [], []
        engine = ct.models.MLModel(
            candidate.get_spec(),
            weights_dir=candidate.weights_dir,
            compute_units=ct.ComputeUnit.CPU_ONLY,
        )
        for index, entry in enumerate(references):
            encodings = inputs(entry["request"])
            masks = np.asarray([e.attention_mask for e in encodings], dtype=np.int32)
            hidden = np.concatenate(
                [
                    engine.predict(
                        {
                            "input_ids": np.asarray([e.ids], dtype=np.int32),
                            "attention_mask": np.asarray(
                                [e.attention_mask], dtype=np.int32
                            ),
                        }
                    )["hidden_states"]
                    for e in encodings
                ]
            )
            if (
                hidden.shape != (len(encodings), 128, width)
                or not np.isfinite(hidden).all()
            ):
                raise ValueError(
                    f"Converted hidden states case {index} have shape {hidden.shape}, nonfinite count {np.count_nonzero(~np.isfinite(hidden))}"
                )
            vectors = pool(hidden, masks)
            expected = np.asarray(against[index])
            cosine = np.sum(vectors * expected, axis=1) / np.linalg.norm(
                expected, axis=1
            )
            if not np.isfinite(cosine).all() or cosine.min() < threshold:
                raise ValueError(
                    f"Embedding case {index}, row {int(cosine.argmin())} cosine below predeclared {threshold}: {cosine.tolist()}"
                )
            predictions.append(vectors)
            rows.append(
                {
                    "case": index,
                    "minimum_cosine": float(cosine.min()),
                    "threshold": threshold,
                }
            )
        del engine
        return rows, predictions

    parity, baseline_predictions = qualify_model(
        converted, 0.999, [e["expected"] for e in references]
    )
    if precision == EmbeddingPrecision.int8:
        from coremltools.optimize.coreml import (
            OpLinearQuantizerConfig,
            OptimizationConfig,
            linear_quantize_weights,
        )

        # Full/linear INT8 failed the frozen [MASK]/[SEP] fixture at 0.9761.
        # Keep attention and embeddings at the qualified mixed precision; apply
        # stock INT8 block quantization only to feed-forward weights.
        selected = set()
        for function in converted.get_spec().mlProgram.functions.values():
            for block in function.block_specializations.values():
                for operation in block.operations:
                    if operation.type == "linear":
                        for argument in operation.inputs["weight"].arguments:
                            if "_mlp_" in argument.name or (
                                "_dense_weight" in argument.name
                                and "_attention_" not in argument.name
                            ):
                                selected.add(argument.name)
        if len(selected) != (84 if is_qwen else 12):
            raise ValueError(
                f"Unexpected feed-forward compression scope: {len(selected)} weights"
            )
        quantizer = OpLinearQuantizerConfig(
            mode="linear_symmetric",
            dtype="int8",
            granularity="per_block",
            block_size=32,
        )
        compressed = linear_quantize_weights(
            converted,
            config=OptimizationConfig(
                op_name_configs={name: quantizer for name in selected}
            ),
        )
        compressed_parity, predictions = qualify_model(
            compressed, 0.99, baseline_predictions
        )
        converted = compressed
    else:
        compressed_parity, predictions = [], baseline_predictions
    k = corpus["k"]
    ref_docs, ref_queries = (np.asarray(e["expected"]) for e in references[-2:])

    # Accelerate matmul on this host emits spurious FP flags even for bounded
    # finite vectors (independent einsum agreed within 1.23e-15). Use explicit
    # accumulation so warning-free retrieval scores remain independently finite.
    def scores(queries, documents):
        values = np.einsum("id,jd->ij", queries, documents)
        if not np.isfinite(values).all():
            raise ValueError("Nonfinite retrieval scores")
        return values

    top_k = np.argsort(-scores(ref_queries, ref_docs), axis=1, kind="stable")[:, :k]
    comparisons = []
    for label, ranking in [
        ("source", top_k),
        (
            "uncompressed",
            np.argsort(
                -scores(baseline_predictions[-1], baseline_predictions[-2]),
                axis=1,
                kind="stable",
            )[:, :k],
        ),
    ]:
        actual = np.argsort(
            -scores(predictions[-1], predictions[-2]), axis=1, kind="stable"
        )[:, :k]
        overlap = [
            len(set(a.tolist()) & set(b.tolist())) / k
            for a, b in zip(actual, ranking, strict=True)
        ]
        if min(overlap) < corpus["thresholds"]["top_k_overlap"]:
            raise ValueError(f"Top-k overlap against {label} below 0.9: {overlap}")
        comparisons.append({"reference": label, "overlap": overlap})
    reference = {
        "model_id": model_id,
        "source_revision": recipe["source_revision"],
        "corpus_sha256": digest(corpus_bytes),
        "retrieval_top_k": top_k.tolist(),
        "cases": references,
        "source_files": recipe["files"],
        "tools": {
            name: importlib.metadata.version(name)
            for name in ("torch", "transformers", "tokenizers", "numpy")
        },
    }
    frozen_reference = root / f"models/{model_id}-reference.json"
    if (
        frozen_reference.exists()
        and json.loads(frozen_reference.read_bytes()) != reference
    ):
        raise ValueError(
            "Source outputs differ from the frozen reference; investigate before publishing"
        )
    with tempfile.TemporaryDirectory(
        prefix="embedding-", dir=output.parent
    ) as temporary:
        scratch = Path(temporary)
        portable = scratch / "Embedding.mlpackage"
        spec = converted.get_spec()
        spec.description.metadata.userDefined.pop(
            "com.github.apple.coremltools.conversion_date", None
        )
        ct.models.MLModel(
            spec, weights_dir=converted.weights_dir, skip_model_load=True
        ).save(str(portable))
        (portable / "Data/com.apple.CoreML/model.mlmodel").write_bytes(
            spec.SerializeToString(deterministic=True)
        )
        index = portable / "Manifest.json"
        plan = json.loads(index.read_bytes())
        mapping = {
            old: str(uuid.uuid5(uuid.NAMESPACE_URL, entry["path"])).upper()
            for old, entry in plan["itemInfoEntries"].items()
        }
        plan["itemInfoEntries"] = {
            mapping[key]: value for key, value in plan["itemInfoEntries"].items()
        }
        plan["rootModelIdentifier"] = mapping[plan["rootModelIdentifier"]]
        index.write_bytes(encoded(plan))
        # The original authenticated tokenizer stays separate from the graph package.
        data_members = {
            "LICENSE.txt": (source / "LICENSE.txt").read_bytes(),
            "tokenizer.json": (source / "tokenizer.json").read_bytes(),
            "recipe.json": encoded(
                {
                    "source": recipe,
                    "tool_versions": {
                        name: importlib.metadata.version(name)
                        for name in (
                            "torch",
                            "transformers",
                            "tokenizers",
                            "coremltools",
                            "numpy",
                        )
                    },
                    "precision": precision.value,
                    "fp32_ops": []
                    if precision == EmbeddingPrecision.float32
                    else [
                        "gather",
                        "gather_nd",
                        "add",
                        "sub",
                        "mul",
                        "real_div",
                        "layer_norm",
                        "softmax",
                    ]
                    + list(qwen_fp32_ops),
                    "compression": {
                        "dtype": "int8",
                        "mode": "linear_symmetric",
                        "granularity": "per_block",
                        "block_size": 32,
                        "scope": "feed-forward-linear-weights",
                        "selected_weight_names": sorted(selected),
                    }
                    if precision == EmbeddingPrecision.int8
                    else None,
                    "sequence_length": 128,
                    "pooling": "last-token" if is_qwen else "masked-mean",
                    "normalized": True,
                    "converter_sha256": digest(Path(__file__).read_bytes()),
                    "corpus_sha256": digest(corpus_bytes),
                }
            ),
            "validation.json": encoded(
                {
                    "request": references[0]["request"],
                    "expected": references[0]["expected"],
                }
            ),
            "reference.json": encoded(reference),
            "corpus.json": corpus_bytes,
        }
        paths = {
            p.relative_to(scratch).as_posix(): p for p in sorted(portable.rglob("*"))
        }
        paths["Embedding.mlpackage"] = portable
        members = {
            name: {"type": "directory", "bytes": 0, "sha256": digest(b"")}
            if path.is_dir()
            else {"type": "file", **file_record(path.read_bytes())}
            for name, path in paths.items()
        }
        members.update(
            {
                name: {"type": "file", **file_record(data)}
                for name, data in data_members.items()
            }
        )
        source_bytes = sum(
            e["bytes"]
            for n, e in members.items()
            if n.startswith("Embedding.mlpackage/")
        )
        identity = "".join(
            f"{e['sha256']}  {n[len('Embedding.mlpackage/') :]}\n"
            for n, e in sorted(members.items())
            if n.startswith("Embedding.mlpackage/") and e["type"] == "file"
        )
        manifest = {
            "schema": 1,
            "package_format": "ashell-model-ustar-v1",
            "model_id": model_id,
            "version": f"{recipe['source_revision'][:12]}-{precision.value}-128-v1",
            "task": "text-embedding",
            "runtime": "CoreML",
            "runtime_abi": 1,
            "adapter_version": 1,
            "minimum_ios": "18.0",
            "source_revision": recipe["source_revision"],
            "source_url": recipe["source_url"],
            "source_bytes": source_bytes,
            "source_sha256": digest(identity.encode()),
            "model": "Embedding.mlpackage",
            "license_file": "LICENSE.txt",
            "recipe": "recipe.json",
            "limits": {"archive_bytes": 2147483648, "member_bytes": 2147483648},
            "features": {
                "input_ids": {"dtype": "int32", "shape": [1, 128]},
                "attention_mask": {"dtype": "int32", "shape": [1, 128]},
            },
            "outputs": {
                "embedding": {"dtype": "float32", "shape": [width], "normalized": True}
            },
            "preprocessing": "qwen3-last-token-v1"
            if is_qwen
            else "minilm-masked-mean-v1",
            "tokenizer": "tokenizer.json",
            "decoder": "l2-v1",
            "license": "Apache-2.0",
            "license_url": recipe["license_url"],
            "license_bytes": members["LICENSE.txt"]["bytes"],
            "license_sha256": members["LICENSE.txt"]["sha256"],
            "disk_estimate_bytes": max(2147483648, source_bytes * 6),
            "memory_profile": {
                "kind": "bounded-embedding-qualification",
                "additional_peak_bytes": (
                    5 * 1024**3 // 2
                    if is_qwen
                    and digest(identity.encode())
                    == "b46d02f0fd85253ae1647af28acb74f76665f5d7a75145187dd67fc8717f52db"
                    else 3 * 1024**3 if is_qwen else 512 * 1024**2
                ),
            },
            "validation": {"input": "validation.json"},
            "members": members,
        }
        archive_path = scratch / f"{model_id}.asmodel"
        embedding_space(scratch, source_bytes * 3)
        with tarfile.open(archive_path, "w", format=tarfile.USTAR_FORMAT) as archive:
            for name in ["manifest.json", *sorted(members)]:
                entry = tarfile.TarInfo(name)
                entry.mode = 0o644
                if name == "manifest.json" or name in data_members:
                    data = (
                        encoded(manifest)
                        if name == "manifest.json"
                        else data_members[name]
                    )
                    entry.size = len(data)
                    archive.addfile(entry, io.BytesIO(data))
                elif members[name]["type"] == "directory":
                    entry.type, entry.mode = tarfile.DIRTYPE, 0o755
                    archive.addfile(entry)
                else:
                    entry.size = members[name]["bytes"]
                    with paths[name].open("rb") as member:
                        archive.addfile(entry, member)
        archive_record = file_record(archive_path.read_bytes())
        if archive_record["bytes"] > 2147483648:
            raise ValueError(
                "Embedding archive exceeds the existing package v1 ceiling"
            )
        environment = dict(os.environ, CFFIXED_USER_HOME=str(scratch / "home"))
        argv = [
            str(runtime.resolve()),
            "install",
            model_id,
            str(archive_path),
            "--sha256",
            archive_record["sha256"],
        ]
        installed = subprocess.run(
            argv,
            env=environment,
            capture_output=True,
            text=True,
            timeout=600,
            check=False,
        )
        if installed.returncode:
            raise ValueError(
                f"Native embedding install/known-answer failed: {installed.returncode}: {installed.stderr}"
            )
        check_argv = [
            "uv",
            "run",
            str(root / "tests/embeddings.py"),
            str(runtime.resolve()),
            model_id,
            str(scratch / "reference.json"),
            str(scratch / "cli"),
            "--precision",
            precision.value,
        ]
        (scratch / "reference.json").write_bytes(encoded(reference))
        checked = subprocess.run(
            check_argv,
            env=environment,
            capture_output=True,
            text=True,
            timeout=1200,
            check=False,
        )
        if checked.returncode:
            raise ValueError(
                f"Public embedding CLI qualification failed: {checked.returncode}: {checked.stderr}"
            )
        output.mkdir()
        archive_path.replace(output / archive_path.name)
        (output / "reference.json").write_bytes(encoded(reference))
        shutil.copytree(scratch / "cli", output / "cli")
        receipt = {
            "archive": archive_record,
            "model": {"bytes": source_bytes, "sha256": manifest["source_sha256"]},
            "manifest_sha256": digest(encoded(manifest)),
            "model_id": model_id,
            "precision": precision.value,
            "source_revision": recipe["source_revision"],
            "runtime_sha256": digest(runtime.read_bytes()),
            "runtime_source_files": {
                name: digest((root / name).read_bytes())
                for name in (
                    "AShellML.m",
                    "AShellML.h",
                    "AShellMLInstall.m",
                    "AShellMLInstall.h",
                    "AShellMLJob.m",
                    "AShellEmbedding.m",
                    "AShellEmbedding.h",
                    "host.m",
                    "build.sh",
                )
            },
            "converter_sha256": digest(Path(__file__).read_bytes()),
            "converter_lock_sha256": digest((root / "convert.py.lock").read_bytes()),
            "checkout_revision": subprocess.check_output(
                ["git", "-C", str(root), "rev-parse", "HEAD"], text=True
            ).strip(),
            "compiler": subprocess.check_output(
                ["xcrun", "clang", "--version"], text=True
            ).strip(),
            "source_recipe_sha256": digest(recipe_bytes),
            "reference_sha256": digest(encoded(reference)),
            "corpus_sha256": digest(corpus_bytes),
            "minimum_ios": "18.0",
            "os": platform.platform(),
            "python": platform.python_version(),
            "conversion_parity": parity,
            "compressed_parity": compressed_parity,
            "retrieval": comparisons,
            "install": {
                "argv": argv,
                "exit": installed.returncode,
                "stdout": installed.stdout,
                "stderr": installed.stderr,
            },
            "cli": {
                "argv": check_argv,
                "exit": checked.returncode,
                "stdout": checked.stdout,
                "stderr": checked.stderr,
            },
        }
        (output / "receipt.json").write_bytes(encoded(receipt))
        return receipt


@app.command()
def embedding(
    model_id: Annotated[str, typer.Option()],
    source: Annotated[Path, typer.Option(exists=True, file_okay=False)],
    runtime: Annotated[Path, typer.Option(exists=True, dir_okay=False)],
    output: Annotated[Path, typer.Option()],
    precision: Annotated[
        EmbeddingPrecision, typer.Option()
    ] = EmbeddingPrecision.float16,
):
    """Convert pinned MiniLM/Qwen source, qualify pooling/retrieval, then publish a v1 archive."""
    try:
        sys.stdout.buffer.write(
            encoded(embedding_build(model_id, source, precision, runtime, output))
        )
    except (KeyboardInterrupt, BrokenPipeError) as error:
        raise typer.Exit(130 if isinstance(error, KeyboardInterrupt) else 0) from None
    except Exception as error:
        log.error("%s", error)
        log.debug("Embedding conversion failed", exc_info=True)
        raise typer.Exit(1) from None


if __name__ == "__main__":
    app()
