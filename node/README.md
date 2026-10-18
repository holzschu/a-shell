# Node for full a-Shell

This command embeds upstream Node 26.11.1 and its matching npm 11.20.0 in the full a-Shell target. Only the full a-Shell target embeds the framework; mini keeps its existing command dictionary and discovery markers. V8 stays alive for the app process; each invocation gets a fresh Environment, isolate, CLI options and event loop. Scripts return their exit status to the shell. Concurrent Node invocations and worker_threads use separate environments.

## Build

Use Apple Silicon and Xcode with the arm64 iPhoneOS and Simulator SDKs. Start with the ios_system source tree at revision `fb7a9057874290bff2765f82b4ba3ba1d76dadb3`. Set `IOS_SYSTEM_SOURCE` to its unmodified source directory; the recipe copies it before patching and builds only its ios_system target, then packages its two arm64 slices with Xcode. `IOS_SYSTEM_XCFRAMEWORK` must point to the app's own writable framework copy.

```bash
export IOS_SYSTEM_SOURCE=/path/to/ios_system
export IOS_SYSTEM_XCFRAMEWORK=/path/to/ios_system.xcframework
./node/build.sh sdk
./node/build.sh node
./node/build.sh device
./node/build.sh package
```

`NODE_IOS_CACHE` defaults to `$HOME/.cache/a-shell-node/v26.11.1`. The Node source revision and archive checksum are pinned in `build.sh`. Node and device builds share a source directory and must run sequentially; each saves stripped archives. All stages accept `--dry-run`. Compilation uses four jobs and suppresses Release debug symbols. Package writes `xcfs/node.xcframework`, including licenses, npm and a locked node-fetch 3.3.2 fallback. It does not build, install or sign the app. No binary is checked in; the app project embeds `xcfs/node.xcframework` directly, so it is not part of `xcfs/Package.swift`. Prepare a-Shell's usual dependencies and rerun `./node/build.sh sdk` before building the app: dependency preparation may replace ios_system with the stock release. The SDK rerun reuses its compiled slices and restores the patched framework.

`ios-system-streams.patch` protects caller-owned FILE streams until detached command cleanup finishes and waits for thread completion with a condition variable. `command-path.patch` makes executable lookup use the command environment's PATH. These changes must accompany the ios_system binary; packaging checks the ownership API before linking. The Node patches adapt upstream iOS configuration, macOS cross-build generators, embedding options, environment and diagnostics, libuv child dispatch and npm script/bin handling. The archive stages compile the core and libuv changes with stock GYP definitions; packaging derives the adapter's V8 ABI definitions from the generated build. npm's bundled npmrc defaults its cache to the writable `${HOME}/Library/Caches/npm`; normal CLI/user overrides still apply. No local host adapter or separate application is required.

## Behavior and limits

Supported CLI options include `-e`, `-p`, `--import`, `--require`/`-r`, `--input-type=module`, `--input-type=commonjs`, `--no-warnings`, `--` and standalone `--version`/`-v`. Other process-wide CLI switches return 9. A bare invocation starts the REPL. The terminal routes Ctrl-C to the active Node session; scripts without a SIGINT listener return 130. Ctrl-D closes REPL input.

Command stdin/stdout/stderr use owned duplicate descriptors without replacing app fd 0/1/2. Raw descriptor APIs still address the app's descriptors. Each Environment clones Node's stock environment map and receives the ios_system command's environment before bootstrap. `process.env` writes stay in that map; Workers copy it by default. The host's cwd, PID and descriptor table remain shared. Node's non-owning Environment flags prohibit `process.chdir`, changing the umask and the native process-title setter; other host commands can still change cwd. Commands run on threads in the app. Native addons are disabled. V8 runs jitless with small ICU; WebAssembly and built-in Undici fetch/WebSocket are unavailable. For HTTPS use `node --import "$APPDIR/Frameworks/node.framework/fetch-preload.mjs" script.js`; certificate verification stays enabled.

`child_process` dispatches a-Shell commands through ios_system. It does not fork OS processes. Only one child command runs at a time; another returns EBUSY. Detached children, IPC/fork, arbitrary executables and child signal delivery are unsupported. npm/npx use the matching bundled npm tree; pure-JavaScript packages and their bins are supported. Native compiler/node-gyp install scripts fail with ENOSYS. This PR does not add another package manager or registry service. The port has physical-iPhone qualification in a-Shell mini, described below; this PR embeds Node only in full a-Shell. Extension execution and App Store acceptance remain unverified. The plain build has no WebAssembly, so Node's WebAssembly-backed TypeScript path is unavailable; DrumBrake is outside this draft.

## Verification

Verified on 2026-10-15 in full a-Shell 2.2.2 (585), arm64 iOS 27 Simulator: the CLI acceptance scripts in this directory and ten child-process cases passed with status 0 and empty runner stderr. Five sequential invocations shared one app process. Node 26.11.1, npm 11.20.0, Node-to-Node pipes, Workers, CommonJS/ESM and HTTPS passed. Real terminal UI Ctrl-C stopped a synchronous loop with status 130; the next Node invocation returned 42 with empty stderr. App RSS after the suite was 400,703,488 bytes (382.1 MiB), measured for the whole app.

The matching Release Simulator bundle grew from 522,078,682 to 589,274,878 apparent bytes: +67,196,196 bytes (64.1 MiB), including npm, fetch dependencies, licenses and the SDK changes. The Node framework was 66,422,159 bytes, with a 41,786,352-byte native library. The local full-target build omits unavailable optional frameworks equally in both measurements. These are uncompressed file sizes, not an App Store download estimate. Both arm64 native slices build for iOS 16.

The same Node port was separately tested on a physical iPhone in a-Shell mini 2.2.2 (585). Its corrected npm build passed 26 base, 16 Worker, ten child-process and 25 npm checks, plus overlapping Node commands. Pure-JavaScript package install/require, scripts, npx and uninstall passed. UI interruption returned 130 for synchronous and asynchronous scripts, a SIGINT handler returned 23, and the REPL exited successfully. Each left the next command working. Simple-eval whole-app RSS on that device was 167,936,000 bytes (160.2 MiB). The mini fork has other host changes; these results qualify the Node port, not this PR's full a-Shell device integration. The full app has not been run on a physical device. Extension execution and App Store acceptance remain unverified.

The included `acceptance.sh` runs through real Dash/ios_system: source it from a disposable Documents directory and require `FAILURES: 0`, status 0 and empty runner stderr. `child-process-test.cjs` exercises command dispatch and pipe/status handling. `interactive.sh` covers interruption and REPL through the app UI; startup-profile execution cannot prove Ctrl-C routing because it does not set the scene's current command.
