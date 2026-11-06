# Native Codex

Embeds OpenAI Codex CLI 0.160.0 (source tag `rust-v0.160.0`, commit `a956835d020762cb2b570053af06f643a11c0ecc`) as `codex` in the full app. The app embeds, but does not link against, `codex.xcframework`; ios_system loads it when the command runs. The framework targets iOS 26.2. On older iOS, the command returns status 1 and prints `codex requires iOS 26.2 or later.` Mini has no Codex entry. Extensions do not embed the framework or list Codex as a local command.

## Build

Use Xcode, Rust 1.96.1 and its `aarch64-apple-ios` and `aarch64-apple-ios-sim` targets. Supply matching device and arm64 Simulator ios_system frameworks with the owned-stream and native-TTY prerequisites below, including `Headers/ios_system.h`:

```sh
nice -n 15 bash codex/build.sh xcframework DEVICE_FRAMEWORKS SIMULATOR_FRAMEWORKS
```

The build checks source archive SHA-256 values, applies the patches from clean pinned sources, and runs Cargo with `--locked`, two jobs and fat release LTO, one codegen unit, opt-level z, no debug information and symbol stripping. `CODEX_BUILD_CACHE` selects the disposable source/build directory; `CODEX_CARGO` and `CODEX_RUSTUP` select installed toolchain executables. Standard `CARGO_HOME`, `RUSTUP_HOME` and `CARGO_TARGET_DIR` overrides also work. Build the full a-Shell scheme after generating `codex/codex.xcframework`. The framework is intentionally excluded from git.

Required ios_system exports are `ashell_register_owned_streams`, `ashell_wait_owned_streams`, `ashell_cancel_owned_streams`, `ashell_unregister_owned_streams`, `ios_useNativeTTY` and `ios_getWindowSize`. Owned command descendants must finish cleanup before their streams close; waits must be cancellation safe. The terminal getter is needed because Rust event/rendering threads have no ios_system session TLS. `storeInteractive()` must return its actual state (a-Shell #1083). The port uses the app's bundled CA asset for HTTPS.

## Runtime contract

The upstream CLI parser, TUI, event parser, session store and Responses client remain in use. The adapter captures the command environment and streams, starts a joined Rust runtime on a 16 MiB stack, and returns a status instead of terminating the app. The iOS Crossterm backend uses a-Shell's interactive-input callbacks and captured terminal stream; it does not require `/dev/tty` or a kernel PTY. UIKit supplies clipboard access. The command uses process descriptors 0 and 1 during its invocation, so it requires exclusive ownership of the app's command execution. A second Codex invocation in that process fails explicitly.

Shell tools run embedded Dash through fresh ios_system sessions, with copied argv/environment, duplicated streams, serialized cwd ownership and a descendant-completion barrier. They are threads in the app, not operating-system processes. Interactive tool terminals (`tty=true`), independent process groups and local stdio MCP servers are unsupported. HTTP MCP retains its upstream transport. Shell snapshots and JavaScript code mode are disabled on iOS. Desktop filesystem/network sandbox policies cannot be enforced here: the port rejects those policies instead of silently claiming protection, and runs inside the signed iOS app sandbox. Approval policy remains separate.

An explicit nonempty `CODEX_HOME` takes precedence. Otherwise state lives in `$GROUP/Library/codex`; first use can atomically migrate the older `$HOME/Library/codex` directory while retaining the original for rollback. The app performs migration without exposing credentials. Refreshes use a cross-process file lock, and saved sessions can relocate after application-container UUID changes. Authentication belongs to the user: run `codex login --device-auth` if needed.

## Verification

Run CLI checks from a disposable app directory through `dash codex-terminal.sh`, after copying `codex/tests/terminal.sh` into that directory. They check version, help, parser errors, status 2, repeated invocation and the next shell command.

`uv run codex/tests/tool-transport.py OUTPUT_DIRECTORY` serves a local Responses fixture without paid model calls or credentials. Configure a disposable Codex home with its printed base URL, `wire_api="responses"` and `requires_openai_auth=false`; run `codex exec --skip-git-repo-check` against it. The fixture requests real native and WASM commands, checks stdout/stderr and statuses 0/1/7, and requires the recovery command to succeed. It fakes only the external model API. The test requires the app's WASM `mktemp` command. Set `export CODEX_HOME=...` at the app prompt before launching Dash. Run tool checks after the normal prompt appears: the WebAssembly interpreter loads after startup profiles finish. Interrupting a turn preserves background unified-exec commands, as upstream does; exiting Codex terminates them. A retained command holds the serialized working-directory slot until it exits.

Interactive acceptance must also cover UTF-8 input, paste, colors, resize, resume, Ctrl-C, quitting and same-process re-entry. A Simulator result does not qualify the full app on a physical device, older iOS, background execution or App Store distribution. Login credentials and existing conversations are not test fixtures.
