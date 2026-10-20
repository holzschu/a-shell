# Worker WASM consumer

`worker-wasm.m` is a real app-command consumer of `ashell_pane_spawn`, `ashell_pane_poll`, and `ashell_pane_release`. It runs a WASI guest through Dash and the worker's normal command catalogue, checks exact output and statuses, and reads the files left by the guest. It uses actual extensions and interpreters without mocks or production test switches.

Build `worker-wasm-guest.c` with a WASI compiler. For example, with Zig 0.16.0:

```sh
zig cc -target wasm32-wasi -O2 -g0 -mno-bulk-memory -Wl,--strip-all -Wl,-z,stack-size=65536 -Wl,--initial-memory=1048576 -Wl,--max-memory=16777216 tests/worker-wasm-guest.c -o worker-wasm-guest.wasm
```

In a disposable mini host build, compile `worker-wasm.m` into a dynamic framework linked with Foundation and ios_system, embed it under the host Frameworks directory, and register its exported `worker_wasm_check_main` symbol through the normal command catalogue. Use the framework registration procedure in `worker-pool.md`, with command name `worker-wasm-check`. Copy the compiled guest into the app's Documents. Run through the normal terminal:

```sh
worker-wasm-check ~/Documents/worker-wasm-guest.wasm path
worker-wasm-check ~/Documents/worker-wasm-guest.wasm wasmkit
worker-wasm-check ~/Documents/worker-wasm-guest.wasm wasm3
```

The `path` case discovers an executable `.wasm` file through PATH and exercises the worker-only WasmKit registration. `wasmkit` selects the same interpreter explicitly. Both run sequential guests in one worker, require stdout/stderr and statuses `0,0,17`, create absolute and cwd-relative files, write `/dev/null`, and create `opened/child.txt` through an opened directory descriptor. The consumer verifies the child was not misplaced in cwd and that nine `/dev/tty` open/write/close cycles preserve subsequent stdout/stderr. `wasm3` checks the basic absolute/relative/device cases and statuses; it does not qualify directory-relative `openat` support. Every invocation uses a fresh directory.

On a pool-only baseline without the override, the `path` case must print `wasm: command not found`, report statuses `127,127,127`, and end in `FAIL` with consumer status 1. The identical consumer with the override must end in `PASS` and status 0. After each run, execute an ordinary host command and verify its output file to establish return to the main terminal. Check a stock main-app `wasm` command separately to verify the WebView route remains available.

Use matching interpreter artifacts. The old v3.0.5 shell framework lacks the absolute-path retry already in upstream wasm3 commit `0e791b31dd4335cc8928bec6a74a9c39edcdefad`. WasmKit's iOS bridge must honor the supplied directory descriptor and handle creation when WASI libc strips the root preopen prefix; restoring a slash only when the target exists cannot create a new absolute file. Do not infer these properties from a successful framework build.

On 2026-10-20, an iPhone 16 Pro running iOS 27.0.1 passed all three routes with three provisioned workers, the updated WasmKit framework and the checksum-verified v3.0.6 shell release. The pool-only PATH baseline returned `127,127,127`. Physical memory pressure, background lifetime, larger modules, unsupported WASM features, cancellation and simultaneous WASM commands require separate coverage.
