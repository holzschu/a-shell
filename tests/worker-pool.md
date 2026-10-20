# Extension worker pool consumer

`worker-pool.m` calls the public C interface in `ShellWorkers/NativePane.h` through `dlsym`. It uses real extensions, XPC, socket streams and Dash.

For a disposable app, compile this source into a dynamic framework named `WorkerPoolChecks.framework` linked with Foundation and ios_system. In the host command catalogue register `worker-pool-check` as `["WorkerPoolChecks.framework/WorkerPoolChecks", "worker_pool_check_main", "", "file"]`. In each worker catalogue register `worker-pool-crash` as `["@rpath/WorkerPoolChecks.framework/WorkerPoolChecks", "worker_pool_crash_main", "", "file"]` and add its executable PATH marker in the worker's `bin` directory. Embed the framework in the host's Frameworks directory and sign it before signing the extensions and app. These registrations belong only to the disposable test build. No production test entry point is needed.

Use the matching ios_system session/stream and Dash terminal changes, then run these commands in the app terminal:

```sh
worker-pool-check
worker-pool-check completion
worker-pool-check capacity
worker-pool-check lifecycle
worker-pool-check lifecycle-busy
worker-pool-check lifecycle-close
```

Each command returns zero on success and prints assertions to its output stream. The capacity check reads `ShellWorkerCount` from the host Info.plist (1 through 10), keeps that many commands open, requires distinct real process IDs and independent cwd/environment, rejects one additional request with `ENOSPC`, then sends input after six seconds and checks exact exit statuses and output EOF. It compares directory device/inode pairs because the phone can return `/private/var/...` for a cwd requested through its `/var/...` alias.

The completion check leaves output unread until polling reports status 7, checks that a second poll preserves it, then reads the exact pending output and EOF.

The lifecycle checks cancel or close one worker, ask a second worker to terminate itself with `SIGKILL`, verify the surviving worker's input/output/status, and repeat the full capacity check. The busy variants make the first command ignore EOF. iOS denies host-to-extension `kill` with `EPERM`, so process loss is injected by the normal disposable command inside the worker. Run these checks only in a disposable build: they deliberately terminate its worker processes.

Register the same consumer in an unmodified host for the baseline. It must print `worker pool unavailable: FAIL` and return one. A Release build must export the public C functions and callbacks loaded through `dlsym`; a consumer compiled into an executable with hidden symbols does not prove that interface usable by a dynamic command.

The upstream configuration remains ten workers. Historical iOS 27 Simulator tests passed ten-slot capacity and lifecycle checks. A physical run with three provisioned identities qualifies three-worker behavior only; it does not qualify ten-worker device capacity, background lifetime or App Store acceptance.
