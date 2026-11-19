# Model packages

An `.asmodel` is a portable POSIX ustar archive with `manifest.json` first. It contains an `.mlmodel` or `.mlpackage`, its license, the conversion recipe and a known-answer input. Compiled `.mlmodelc` products are device-local cache data and cannot be distributed as portable packages. Only the registered MNIST, MiniLM-L6 and Qwen3-Embedding-0.6B adapters are accepted.

The schema-1 manifest declares `package_format: "ashell-model-ustar-v1"`, `model_id`, version, runtime `CoreML`, `runtime_abi: 1`, minimum iOS version, model and license paths, recipe and validation paths, source provenance, input/output contracts, memory and disk estimates, and byte limits. Every member is declared in `members` with type, byte count and SHA256; parent directories are explicit. The adapter declarations in `AShellMLInstall.swift` and `AShellEmbedding.swift` define the accepted schema; package-side converters emit manifests against that contract.

The installer rejects undeclared or duplicate members, absolute paths, traversal, links, unsupported tar extensions, incorrect sizes or hashes and excess archive/member limits. The license and validation fixtures are authenticated with the model. An optional caller-supplied archive SHA256 authenticates the complete transport object. HTTPS is required for downloads; literal loopback HTTP is available for local test catalogs.

Installation stages a generation, verifies portable members, compiles with Apple's Core ML compiler, runs the adapter's known-answer check under the shared inference permit, records compiled-file integrity and atomically activates the new version. The previous version remains available for rollback. Version leases protect active consumers from removal. Warm requests reuse authenticated metadata only while the live version identity remains unchanged; modified compiled files are rejected, including edits that restore their modification time.

Downloaded content is model and vocabulary data; all executable adapters ship signed with the app. MNIST known-answer image and embedding tokenizer hashes, sizes and pooling rules are fixed by those adapters. Changing an archive cannot change the adapter contract.
