# On-device Core ML

`coreml` installs model data and runs inference locally. The AShellML runtime is compiled into the full, mini and noPython app targets and registered at startup alongside the app's other native commands. It needs no worker process, Python interpreter or downloaded executable code. Models live under `Library/Application Support/a-Shell/Models`, outside Documents, and are excluded from backups.

```sh
coreml install minilm-l6 /path/to/minilm-l6.asmodel --sha256 ARCHIVE_SHA256
coreml ls minilm-l6
coreml embed minilm-l6 input.json
coreml remove minilm-l6
```

Embedding input is JSON, for example `{"texts":["A local search query","A document to index"]}`. MiniLM-L6 produces 384-dimensional English embeddings. Qwen3-Embedding-0.6B produces 1024-dimensional multilingual embeddings and accepts an optional `instruction` for queries. Both adapters use a fixed 128-token export. Overlength text fails unless `"truncate":true` is explicit. The output contains normalized vectors, token counts, truncation flags, model hashes, cache information, timings and process memory. Embedding packages require iOS 18 or newer.

CPU is the default. `--units all|cpu-gpu|cpu-ane` selects a diagnostic Core ML compute policy; it does not establish which hardware executed an operation. Neural Engine execution is not qualified as supported.

For the small drawing-classification fixture, `coreml predict mnist image.gray` accepts exactly 784 grayscale bytes. `coreml run` is an alias. `coreml info mnist` reports the model contract.

The process shares one inference permit and one warm model cache. Requests queue before loading, cached versions retain a lease, and removal or rollback cannot replace a leased version. The cache expires after 60 seconds idle and is evicted on cancellation, memory pressure, backgrounding or protected-data loss. Background downloads may finish, but compilation, validation and activation require foreground execution. Repeating an installation retries its transaction; archive downloads restart, and a failed validation preserves the active version. `coreml install-status MODEL`, `cancel-install MODEL GENERATION`, and `rollback MODEL` expose transaction control.

`coreml request` returns a process-local UUID. Pass it with `--request UUID` to `predict` or `embed`; another command can call `coreml cancel UUID`. `coreml status` reports queue activity and progress. When a native command is running, terminal interruption cancels all inference and installation in that ios_system session, including background Core ML commands. Use a request UUID or installation generation to cancel one operation. Cancellation returns 130 and publishes no partial inference result; temporary unavailability returns 75 and invalid input returns 2. Native cleanup completes before admission is released. File verification polls cancellation between 64 KiB reads. A running Core ML compilation or prediction call finishes before cancellation takes effect.

For callers that exchange files, `coreml job create DIRECTORY`, `job run DIRECTORY coreml run mnist IMAGE [OPTIONS]`, and `job status DIRECTORY` use an absolute caller-owned directory. Write the job's nonce to its fixed `cancel` file to cancel that job. Directory descriptors fence access and symlinks are rejected. No transport or server is included.

See [PACKAGE.md](PACKAGE.md) for the archive contract. Conversion recipes, source and tokenizer fixtures, and model qualification tools belong in the `models/coreml/` directory of a-Shell-commands. Archives and generated reference vectors are distributed separately. The app contains the adapter contract, including fixed known-answer and tokenizer pins; an archive cannot replace that contract.

## Host checks

Build the public host executable with `bash ml/build.sh --host /absolute/output/runtime`. Tests that install a model require explicit package-side artifacts and fail when an input is missing. No model is downloaded implicitly.

```sh
uv run ml/tests/fixtures.py /absolute/output/tokenizers
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -Werror ml/AShellEmbedding.m ml/tests/embedding-tokenizer.m -framework Foundation -framework CoreML -o /absolute/output/tokenizer
/absolute/output/tokenizer /absolute/output/tokenizers/tokenizers.json minilm-l6 /absolute/output/tokenizers/minilm-l6-tokenizer.json
/absolute/output/tokenizer /absolute/output/tokenizers/tokenizers.json qwen3-embedding-0.6b /absolute/output/tokenizers/qwen3-embedding-0.6b-tokenizer.json
uv run ml/tests/packages.py /absolute/output/packages --archive /absolute/artifacts/mnist.asmodel --program-archive /absolute/artifacts/mnist-program.asmodel --image /absolute/artifacts/seven.gray --installer /absolute/output/runtime/coreml
uv run ml/tests/package-install.py /absolute/output/runtime/coreml /absolute/output/packages /absolute/artifacts/seven.gray /absolute/output/package-receipt.json
bash ml/tests/check-install.sh /absolute/output/install /absolute/artifacts/mnist.asmodel /absolute/artifacts/seven.gray
CFFIXED_USER_HOME=/absolute/output/model-home /absolute/output/runtime/coreml install /absolute/artifacts/mnist.asmodel
CFFIXED_USER_HOME=/absolute/output/model-home bash ml/tests/cli.sh /absolute/output/runtime/coreml /absolute/artifacts/mnist.asmodel ARCHIVE_SHA256 /absolute/output/cli /absolute/artifacts/seven.gray
bash ml/tests/check-jobs.sh /absolute/output/jobs /absolute/output/model-home /absolute/artifacts/seven.gray
```

The MNIST suites require the single-file and ML Program archives plus their 784-byte known-answer image. `packages.py` derives malformed archive fixtures from those supplied packages. The installer suite covers interrupted transactions, integrity failures, rollback, removal and leases. The CLI and job suites cover repeated inference, active and queued cancellation, nonce isolation and recovery. The tiny generated vocabularies test the public tokenizer C API without model weights; `tests/affine-fixture.json` records the untrained image conversion contract.

Embedding qualification needs each real archive, its generated reference, pinned tokenizer and the package-side corpus fixtures. Run `models/coreml/tests/embedding-host.sh` from a-Shell-commands with this app checkout as its seventh argument. It builds this checkout's runtime and uses `embedding-tokenizer.m` and `embedding-session.m` to test tokenization, same-process cancellation, cache recovery and compiled-file tampering through public APIs. These native test consumers retain no model content.

After an app build, run `bash ml/tests/app-link.sh /absolute/output/a-Shell.app` to verify the native entry point is exported for ios_system.
