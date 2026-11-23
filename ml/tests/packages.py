#!/usr/bin/env -S uv run --script
# /// script
# requires-python = "==3.12.13"
# dependencies = ["typer==0.16.0", "rich==14.0.0", "coremltools==9.0", "numpy==2.2.6"]
# ///
"""Exercise supplied portable archives through the real installer CLI."""

import hashlib
import io
import json
import math
import os
import subprocess
import tarfile
from pathlib import Path
from typing import Annotated

import typer
from rich.console import Console

app = typer.Typer(pretty_exceptions_enable=False)
console = Console(stderr=True)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def unpack(package):
    with tarfile.open(package) as archive:
        assert archive.getnames()[0] == "manifest.json"
        return {
            entry.name: archive.extractfile(entry).read() if entry.isfile() else None
            for entry in archive
        }


def validate(package):
    files = unpack(package)
    manifest = json.loads(files["manifest.json"])
    assert set(files) == {"manifest.json", *manifest["members"]}
    for name, record in manifest["members"].items():
        data = files[name]
        assert record["type"] == ("directory" if data is None else "file")
        assert len(data or b"") == record["bytes"]
        assert sha(data or b"") == record["sha256"]
    return manifest


def write_archive(path, files):
    with tarfile.open(path, "w", format=tarfile.USTAR_FORMAT) as archive:
        for name, data in files.items():
            entry = tarfile.TarInfo(name)
            entry.size = len(data) if data is not None else 0
            entry.type = tarfile.REGTYPE if data is not None else tarfile.DIRTYPE
            entry.mode = 0o644 if data is not None else 0o755
            archive.addfile(entry, io.BytesIO(data) if data is not None else None)


@app.command()
def check(
    output: Path,
    archive: Annotated[Path, typer.Option(exists=True, dir_okay=False)],
    program_archive: Annotated[Path, typer.Option(exists=True, dir_okay=False)],
    image: Annotated[Path, typer.Option(exists=True, dir_okay=False)],
    installer: Annotated[Path | None, typer.Option(exists=True, dir_okay=False)] = None,
):
    import coremltools as ct

    image = image.resolve()
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    evidence = []

    def run(argv, expected=0, env=None):
        result = subprocess.run(
            [str(arg) for arg in argv],
            env=env,
            check=False,
            capture_output=True,
            text=True,
            timeout=180,
        )
        evidence.append(
            {
                "argv": [str(arg) for arg in argv],
                "exit": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
            }
        )
        (output / "commands.json").write_text(json.dumps(evidence, indent=2) + "\n")
        assert result.returncode == expected, evidence[-1]
        return result

    package = output / "first/mnist.asmodel"
    package.parent.mkdir()
    package.write_bytes(archive.read_bytes())
    manifest = validate(package)
    files = unpack(package)
    assert manifest["model"].endswith(".mlmodel"), "Pass the single-file MNIST archive"
    assert len(image.read_bytes()) == 784
    model = output / manifest["model"]
    model.write_bytes(files[manifest["model"]])
    spec = ct.utils.load_spec(str(model))
    spec.description.input[0].type.imageType.width = 27
    ct.utils.save_spec(spec, str(output / "wrong-model-feature.mlmodel"))

    for case in ("bad-feature", "bad-hash", "oversize", "unsupported-task"):
        changed = files.copy()
        if case == "bad-feature":
            wrong = json.loads(changed["manifest.json"])
            wrong["features"]["image"]["shape"] = [1, 784]
            changed["manifest.json"] = json.dumps(wrong).encode()
        elif case == "bad-hash":
            bad_model = bytearray(changed[manifest["model"]])
            bad_model[-1] ^= 1
            changed[manifest["model"]] = bytes(bad_model)
        elif case == "oversize":
            changed[manifest["model"]] = bytes(manifest["limits"]["member_bytes"] + 1)
            wrong = json.loads(changed["manifest.json"])
            oversized = changed[manifest["model"]]
            wrong["members"][manifest["model"]].update(
                bytes=len(oversized), sha256=sha(oversized)
            )
            wrong.update(source_bytes=len(oversized), source_sha256=sha(oversized))
            changed["manifest.json"] = json.dumps(wrong).encode()
        else:
            wrong = json.loads(changed["manifest.json"])
            wrong["task"] = "embedding"
            changed["manifest.json"] = json.dumps(wrong).encode()
        write_archive(output / f"{case}.asmodel", changed)

    program = output / "program/mnist.asmodel"
    program.parent.mkdir()
    program.write_bytes(program_archive.read_bytes())
    program_manifest = validate(program)
    assert program_manifest["model"].endswith(".mlpackage")
    assert program_manifest["minimum_ios"] == "15.0"

    renamed = []
    for name, original in (
        ("renamed", package),
        ("renamed-program", output / "program/mnist.asmodel"),
    ):
        original_files = unpack(original)
        original_plan = json.loads(original_files["manifest.json"])
        old_model = original_plan["model"]
        new_model = "renamed-model" + Path(old_model).suffix
        names = {
            original_plan["license_file"]: "terms.txt",
            original_plan["recipe"]: "conversion.json",
            original_plan["validation"]["input"]: "kat.gray",
        }
        for member in original_plan["members"]:
            if member == old_model or member.startswith(old_model + "/"):
                names[member] = new_model + member[len(old_model) :]
        original_plan.update(
            model=new_model, license_file="terms.txt", recipe="conversion.json"
        )
        original_plan["validation"]["input"] = "kat.gray"
        original_plan["members"] = {
            names.get(member, member): record
            for member, record in original_plan["members"].items()
        }
        renamed_files = {
            names.get(member, member): data for member, data in original_files.items()
        }
        renamed_files["manifest.json"] = json.dumps(
            original_plan, sort_keys=True
        ).encode()
        target = output / f"{name}.asmodel"
        write_archive(target, renamed_files)
        validate(target)
        renamed.append(target)
    validate(output / "oversize.asmodel")
    console.print(
        "PASS: renamed model/license/recipe/KAT fixtures for both formats; oversize fixture has matching hashes and exact sizes"
    )

    if installer:
        installer = installer.resolve()
        env = dict(os.environ, CFFIXED_USER_HOME=str(output / "home"))
        for candidate in (
            package,
            renamed[0],
            output / "program/mnist.asmodel",
            renamed[1],
        ):
            installed = json.loads(
                run(
                    [
                        installer,
                        "install",
                        candidate,
                        "--sha256",
                        sha(candidate.read_bytes()),
                    ],
                    env=env,
                ).stdout
            )
            repeat = json.loads(run([installer, "install", candidate], env=env).stdout)
            assert installed["manifest_sha256"] == repeat["manifest_sha256"]
            predicted = json.loads(
                run(
                    [installer, "run", "mnist", image], env=env
                ).stdout
            )
            assert len(predicted["runs"]) == 1
            prediction = predicted["runs"][0]
            assert prediction["label"] == "7"
            assert set(prediction["scores"]) == {str(i) for i in range(10)}
            scores = prediction["scores"].values()
            assert all(math.isfinite(value) and 0 <= value <= 1 for value in scores)
            assert abs(sum(scores) - 1) <= 1e-4
        active = json.loads(run([installer, "ls"], env=env).stdout)["manifest_sha256"]
        for case in ("bad-feature", "bad-hash", "oversize", "unsupported-task"):
            run([installer, "install", output / f"{case}.asmodel"], expected=2, env=env)
            assert (
                json.loads(run([installer, "ls"], env=env).stdout)["manifest_sha256"]
                == active
            )
        console.print(
            "PASS: real S2 installer, default/renamed single-file pinned/unpinned installs, prediction, four rejections preserve active version"
        )
        (output / "installer.json").write_text(
            json.dumps(
                {"binary": str(installer), "sha256": sha(installer.read_bytes())},
                indent=2,
            )
            + "\n"
        )

    print(
        json.dumps(
            {
                "commands": len(evidence),
                "installer_verified": bool(installer),
                "archive_sha256": sha(package.read_bytes()),
                "program_sha256": sha((output / "program/mnist.asmodel").read_bytes()),
            }
        )
    )


if __name__ == "__main__":
    app()
