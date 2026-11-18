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

See [PACKAGE.md](PACKAGE.md) for archives and [MAC-CONVERSION.md](MAC-CONVERSION.md) for conversion and qualification. No archive hosting service is configured here. A distributor builds the archives, publishes the archives and their SHA256 values at its own HTTPS URLs, and users pass those URLs or local paths to `coreml install`. The converter records source revisions, licenses and hashes; model weights are not bundled in the application.
