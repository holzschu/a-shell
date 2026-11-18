# Convert and qualify models on macOS

Use Xcode's command-line tools and uv. `convert.py` is a PEP 723 script with a committed lock file. Core ML compilation and execution require macOS. Source recipes and their expected file sizes and SHA256 values are under `models/`; obtain the named source revision from the public repository in `models/embeddings.json` before conversion.

```sh
bash ml/build.sh --host /absolute/output/runtime
uv run --locked ml/convert.py build --source ml/models/affine-fixture.json --output /absolute/output/fixture
uv run --locked ml/convert.py embedding --model-id minilm-l6 --source /absolute/sources/minilm --runtime /absolute/output/runtime/coreml --output /absolute/output/minilm --precision float16
uv run --locked ml/convert.py embedding --model-id qwen3-embedding-0.6b --source /absolute/sources/qwen --runtime /absolute/output/runtime/coreml --output /absolute/output/qwen --precision float16
```

The converter verifies pinned source members, exports a fixed 128-token graph, compares it with the original transformer, validates native tokenization and pooling, builds a deterministic archive and runs the archive through the real installer and embedding CLI. It writes a receipt with archive hashes, source revisions, numerical parity and runtime identity. Keep the receipt with the archive. Publication of the archive to an HTTPS host is a separate distributor action; there is no default archive host.

MiniLM uses mean pooling. Qwen uses the last unmasked token and retains FP32 source weights through the RMSNorm decomposition to avoid zero-norm output from intermediate FP16 overflow. The mixed FP16 export retains the selected operations in FP32. Float32 and int8 conversions are available for qualification experiments; use the float16 archives for the qualified CPU path. The frozen references and retrieval corpus under `models/` supply independent expected vectors, token counts, truncation flags and retrieval rankings.

Host checks use the public CLI and C API. Outputs must be fresh absolute directories; `CFFIXED_USER_HOME` isolates model storage.

```sh
bash ml/tests/check-install.sh /absolute/output/install /absolute/sources/MNISTClassifier.mlmodel /absolute/sources/LICENSE-MIT.txt
CFFIXED_USER_HOME=/absolute/output/model-home /absolute/output/runtime/coreml install --manifest ml/catalog/mnist.json --sha256 MANIFEST_SHA256
bash ml/tests/check-jobs.sh /absolute/output/jobs /absolute/output/model-home
bash ml/tests/embedding-host.sh /absolute/output/minilm-host minilm-l6 /absolute/output/minilm/minilm-l6.asmodel ml/models/minilm-l6-reference.json /absolute/sources/minilm/tokenizer.json float16
bash ml/tests/embedding-host.sh /absolute/output/qwen-host qwen3-embedding-0.6b /absolute/output/qwen/qwen3-embedding-0.6b.asmodel ml/models/qwen3-embedding-0.6b-reference.json /absolute/sources/qwen/tokenizer.json float16
uv run ml/tests/packages.py /absolute/output/packages --installer /absolute/output/runtime/coreml
```

The installer suite covers interrupted transactions, integrity failures, rollback, removal and leases. Job tests cover active and queued cancellation, nonce isolation and recovery. Embedding qualification covers known-answer vectors, retrieval, tokenization, bad input, cancellation without partial output, cache recovery and compiled-file tampering with restored modification times.

After building an app, run `bash ml/tests/app-link.sh /absolute/output/a-Shell.app` to check that the native command entry point is exported for ios_system. On device, verify `coreml --help` and terminal Ctrl-C during both inference and a slow installation, then run another command to check recovery.

For device qualification, transfer the archive and the `phone` fixtures emitted by `embedding-host.sh` to a fresh owned directory. Run `embedding-phone.sh` there through the shell with a phase and model ID: `install MODEL ARCHIVE_SHA256`, `measure MODEL cpu`, `matrix-cpu MODEL`, `bad MODEL` and `cancel-window MODEL`. Run `cancel-observe` concurrently from another foreground command route using an absolute path rooted in `$HOME`. Retain exit codes, stdout, stderr, request UUIDs and recovery results. A host result or requested compute policy is not device qualification.
