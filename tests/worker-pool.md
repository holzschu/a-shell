# Extension worker pool consumer

`worker-pool.m` is an app command that calls the public C interface in `ShellWorkers/NativePane.h` through `dlsym`. It uses real extensions, XPC, socket streams and Dash. It does not mock the pool or add a production test entry point.

In a disposable a-Shell mini build, add this source to the host target and register `replaceCommand("worker-pool-check", "worker_pool_check_main", true)` after `initializeEnvironment()` in `AppDelegate.swift`. Build the host with the matched ios_system#179–#184 and dash_iOS#1–#2 frameworks and libedit patch. Run these commands in the app terminal:

```sh
worker-pool-check
worker-pool-check capacity
worker-pool-check lifecycle
worker-pool-check lifecycle-busy
worker-pool-check lifecycle-close
```

Each command returns zero on success and prints its assertions to the command output stream. The capacity check keeps ten commands open, requires ten distinct real process IDs and independent cwd/environment, rejects the eleventh request with `ENOSPC`, then sends input after six seconds and checks exact exit statuses and output EOF. The lifecycle checks cancel or close one worker, inject `SIGKILL` into another worker that identified itself through stdout, check the surviving worker's input/output/status, and repeat the full capacity check. The busy variants make the first command ignore EOF. Run them only in a disposable build: they deliberately terminate worker processes belonging to that build.

For a baseline, register the same command in unmodified a-Shell mini. It must print `worker pool unavailable: FAIL` and return one. The final stock baseline and patched app were built with byte-identical consumer source (SHA-256 `6e9dd2d1bc22548c5932dbc173983a51bd423e0883bb9632bc63849532d35967`). The stock baseline returned the missing-API failure for `lifecycle-close`; the patched app completed the lifecycle and ten-slot checks.

Verified on iOS 27 Simulator: the stock baseline failed at missing pool API; the patched app passed the single-command and ten-worker checks. A first busy-loop lifecycle run failed with `EBUSY` after invalidation; explicit worker termination made that same regression pass. Simulator does not qualify physical-device sandbox enforcement, memory limits, ten-worker device capacity, background lifetime or App Store acceptance. Keep those checks separate.
