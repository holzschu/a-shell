# Embedded Helix

This port builds Helix 25.07.1 (`a05c151bb6e8e9c65ec390b0ae2afe7a5efd619b`) with Rust 1.96.1 as a native command in full a-Shell. It retains the upstream editor, key parser, renderer and runtime data. Seven statically linked tree-sitter parsers cover Rust, Python, Markdown (block and inline), TOML, JSON and Bash. Source and parser archives are pinned and checksummed.

## Prerequisites and build

The command requires `ios_getWindowSize(int *, int *, const void *)` from [ios_system #177](https://github.com/holzschu/ios_system/pull/177), plus a synchronous a-Shell `storeInteractive` callback so the previous input mode can be restored. Helix reads dimensions and polls resize events on a separate Rust editor thread with a 16 MiB stack, which does not inherit the command thread's ios_system session TLS needed by `getenv("COLUMNS")`/`getenv("LINES")`. The existing callback schedules its read asynchronously and returns before reading. These prerequisites must land before this tool is enabled in a release.

Install Rust 1.96.1 with rustup and provide matching arm64 device and Simulator ios_system frameworks. From the repository root:

```sh
bash createFakeCommands.sh
bash helix/build.sh xcframework DEVICE_FRAMEWORKS SIMULATOR_FRAMEWORKS
```

The generated `helix/helix.xcframework` is ignored by Git and embedded only in full a-Shell. `Resources/commandDictionary.plist` registers `hx_ios_main` as `hx`; `createFakeCommands.sh` adds the command placeholder. Mini and extensions are unchanged. The recipe targets iOS 14 and produces arm64 device and arm64 Simulator slices. Supply `HELIX_BUILD_CACHE` for build outputs, `HELIX_RUSTUP_HOME`/`HELIX_CARGO_HOME` for isolated toolchain/cache locations, and `HELIX_CARGO` for a cargo executable outside PATH. Prefer a per-worker CARGO_HOME during parallel builds; do not remove live package-cache locks. If changing the deployment target in an existing build cache, clean both Cargo targets before rebuilding; parser object paths already include the deployment target.

For one platform, run `bash helix/build.sh framework MATCHING_FRAMEWORKS simulator` (or `device`). `prepare` checks and patches sources without compiling; repeated preparation recognizes the final patch state. Roll back by removing the generated XCFramework and restoring the project's embedding and command registration changes.

## Runtime contract

The adapter duplicates the invoking command's ios_system streams, uses ios_system callbacks for dimensions and raw input, and restores the prior mode on return. It never replaces process descriptors 0, 1 or 2. Only one Helix invocation per app process is allowed at a time. Bundled runtime data is resolved relative to the loaded framework.

LSP and Git integration are disabled. External shell commands, formatters, language servers, debugger processes and URL launch are unsupported iOS process boundaries. Grammar fetch/build return explicit errors; only the bundled parsers are available. Clipboard writes use a-Shell's existing `pbcopy`; clipboard reads are unsupported. Normal `:q`/`:wq` exit and same-process re-entry were verified below. Redirected editor stdin, live cancellation/EOF, background/foreground, saved-session restoration, oldest-supported-iOS behavior and this contribution's physical-device runtime remain unqualified. Cursor-shape restoration is a separate host-terminal issue.

## Validation

Source checksums, zero-fuzz patch application, repeated preparation, shell syntax and plist parsing passed locally. The arm64 device and Simulator framework recipes and Simulator full a-Shell build passed. Both framework binaries report minimum iOS 14 and export only `hx_ios_main`; all constituent Rust and parser objects were checked to require no version above 14. The local ios_system test frameworks were built for iOS 16 and emitted a linker warning; an iOS 14 app needs matching dependencies rebuilt at its baseline. The app used both prerequisites above and the generated command placeholders.

On 2026-10-16, a fresh iPhone 17 Simulator running iOS 27 passed real terminal input and independent file readback: edit a synthetic UTF-8 file and `:wq`, compare exact bytes and status 0, execute the first ordinary command after return, reopen and `:q` with status 0, then run the next command without restarting the app. Version before and after was `helix 25.07.1 (a05c151b)`, status 0. Grammar fetch returned its explicit unsupported error and status 1. All six language health checks returned 0 and confirmed tree-sitter parsers and highlight queries. Markdown lacks textobject/indent queries and TOML lacks indent queries in the bundled upstream runtime. Expected stderr was empty apart from the grammar-fetch error. Screenshots document synthetic editor views; file bytes and exit statuses establish behavior.

After rebuilding both slices for iOS 14 from a fresh target cache, the Simulator framework was swapped into the same full-app build. A second real-terminal open/edit/save/quit check passed exact UTF-8 readback, status 0 and the next command in the same process. This archive-source build reports `helix 25.07.1` without a Git suffix. Minimum-iOS runtime remains untested.
