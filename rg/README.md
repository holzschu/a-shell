# Native ripgrep

Embeds ripgrep 15.2.0, revision `e89fff89ac9af12e8d4ce9d5fd07beb408ca730f`, with Rust 1.96.1. The source archive is SHA-256 checked and Cargo builds with `--locked`. The patch retains upstream searching, globbing, ignore rules, Unicode and parallel traversal. The C adapter supplies command-local ios_system streams; Rust owns duplicated descriptors and invocation state. It does not replace process descriptors 0, 1 or 2. Each invocation returns its status instead of exiting the application.

## Build

Install Rust 1.96.1 with rustup (`rustup toolchain install 1.96.1 --profile minimal`); the build adds the `aarch64-apple-ios` or `aarch64-apple-ios-sim` target to that toolchain itself. Provide matching device and arm64 Simulator ios_system frameworks, including Headers/ios_system.h, then run from the repository root:

```sh
bash rg/build.sh xcframework DEVICE_FRAMEWORKS SIMULATOR_FRAMEWORKS
```

The output is `rg/rg.xcframework`, ignored by Git. Build inputs and intermediates default to a temporary external cache; set `RG_BUILD_CACHE` to retain them elsewhere. `build.sh framework FRAMEWORKS simulator` builds only one platform. Both slices target iOS 14 and arm64. The project embeds the framework in full a-Shell; mini and extensions are unchanged. The command dictionary registers `rg`, and `createFakeCommands.sh` supplies the Dash lookup placeholder.

## Limits

PCRE2 is disabled. External preprocessors and compressed-file helpers require subprocess facilities unavailable on iOS; do not rely on them. Working-directory and environment ownership remain host responsibilities. The patch isolates command streams, arguments, diagnostics and error state, including parallel search workers. It does not provide general process isolation or cancellation.

Automatic color follows a-Shell's terminal: rg asks `ios_isatty` whether stdout is the terminal and reads only `NO_COLOR` and `TERM` with `ios_getenv`, so values set for a single command (`NO_COLOR=1 rg ...`) are honored. Redirected output stays free of escape sequences, and `--color=always` still forces them. Other variables rg reads (`RIPGREP_CONFIG_PATH`, `GIT_CONFIG_*`, `XDG_CONFIG_HOME`, `PWD`) still come from the process environment.

An installed `Documents/bin/rg.wasm3` may take precedence over the bundled command; remove or rename that package to exercise this native entry. The WASM package remains independently available through `pkg install rg`.

## Validation

For app acceptance, invoke rg through the real a-Shell terminal and capture exact output, stderr and status in fresh files. Check recursive file reads, ignore/glob rules, Unicode, no match (1), missing file (2), invalid expression (2), stdin and parallel output, then repeat a successful search and an ordinary shell command without restarting the app. Treat Simulator, device compilation and physical-device execution as separate evidence. The full a-Shell build may need the documented local Simulator adaptations for unavailable optional frameworks; keep those outside this contribution.

The native framework and full app built for an arm64 iOS Simulator. `rg/tests/terminal.sh` passed twice through the full-app terminal in one app process, including UTF-8 file reads, default recursive search, ignore/glob rules, stdin redirection, a pipeline, parallel output and statuses 0/1/2. A direct no-path search and subsequent ordinary shell command also returned. Device compilation, physical-device execution, iOS 14 runtime, cancellation, background/foreground and saved-session restoration are unverified.
