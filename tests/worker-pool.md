# Extension worker pool consumer

`worker-pool.m` calls the public C interface in `ShellWorkers/NativePane.h` through `dlsym`. It uses real extensions, XPC, socket streams and Dash.

For a disposable app, compile this source into a dynamic framework named `WorkerPoolChecks.framework` linked with Foundation and ios_system. In the host command catalogue register `worker-pool-check` as `["WorkerPoolChecks.framework/WorkerPoolChecks", "worker_pool_check_main", "", "file"]`. In each worker catalogue register `worker-pool-crash` as `["@rpath/WorkerPoolChecks.framework/WorkerPoolChecks", "worker_pool_crash_main", "", "file"]` and add its executable PATH marker in the worker's `bin` directory. Embed the framework in the host's Frameworks directory and sign it before signing the extensions and app. These registrations belong only to the disposable test build. No production test entry point is needed.

Use the matching ios_system session/stream and Dash terminal changes, then run these commands in the app terminal:

```sh
worker-pool-check
worker-pool-check completion
worker-pool-check identity
worker-pool-check capacity
worker-pool-check limit
worker-pool-check lifecycle
worker-pool-check lifecycle-busy
worker-pool-check lifecycle-close
```

Each command returns zero on success and prints assertions to its output stream. The capacity check asks the host for the effective cap (`ashell_pane_capacity`: the `worker_limit` setting, or the physical core count when unset, at most `ShellWorkerCount` from the host Info.plist), keeps that many commands open, requires distinct real process IDs and independent cwd/environment, rejects one additional request with `ENOSPC`, then sends input after six seconds and checks exact exit statuses and output EOF. It compares directory device/inode pairs because the phone can return `/private/var/...` for a cwd requested through its `/var/...` alias.

Dash fixture spawns pass `_DASH_LOGIN_SHELL=1` through the public environment argument. The published Dash otherwise treats its first invocation as a login shell, even with `-c`, and reads the user's profile; an `alias exit=clear` can turn the fixture's `exit 7` into an unresolved command returning 127. The fixture leaves the user's profile and production shell behavior unchanged. For a regression check, add `alias exit=clear` to the disposable Simulator profile: the original fixture must return 127, while the explicit non-login environment must preserve status 7, exact pending output and EOF.

The completion check leaves output unread until polling reports status 7, checks that a second poll preserves it, then reads the exact pending output and EOF. On failure it prints the first and repeated poll results and statuses, byte count, output match, EOF result, read errno and socket readiness. A skipped repeated poll or read retains its initial sentinel; the diagnostic does not drain output before the status checks.

The identity check supplies stale worker markers and runs real Dash with a nested Dash command. Both shells must see positive worker and root markers through their own environment import, and the nested command must resolve through the host's packaged PATH. It also checks status, pending output and EOF through the public pane API.

The limit check requires the default cap to equal `min(hw.physicalcpu, ShellWorkerCount)`, then sets `worker_limit` to 2, to the bundled count and above it (clamped to the bundled count), repeats the capacity check under each and restores the setting. Build the host with more workers than cores to see the default and the raised cap differ.

The lifecycle checks cancel or close one worker, ask a second worker to terminate itself with `SIGKILL`, verify the surviving worker's input/output/status, and repeat the full capacity check. The busy variants make the first command ignore EOF. iOS denies host-to-extension `kill` with `EPERM`, so process loss is injected by the normal disposable command inside the worker. Run these checks only in a disposable build: they deliberately terminate its worker processes.

Register the same consumer in an unmodified host for the baseline. It must print `worker pool unavailable: FAIL` and return one. A Release build must export the public C functions and callbacks loaded through `dlsym`; a consumer compiled into an executable with hidden symbols does not prove that interface usable by a dynamic command.

The upstream configuration remains ten workers. Historical iOS 27 Simulator tests passed ten-slot capacity and lifecycle checks. A physical run with three provisioned identities qualifies three-worker behavior only; it does not qualify ten-worker device capacity, background lifetime or App Store acceptance.

`pane-descriptors.m` is a standalone consumer of the public native pane API. Compile it together with `ShellWorkers/NativePane.m`, linking Foundation and the matching ios_system framework, for an owned Simulator and run it with `xcrun simctl spawn <UUID> <binary>`. It limits only its disposable process to 64 descriptors, fills the table, and retries separate-stderr/plain-stream spawns with zero through six available descriptors. Every call must return `EMFILE`, leave all outputs empty and preserve the open-descriptor count. It restores the original limit before reporting. The baseline leaks one descriptor with three available slots; the fixed runner passes all seven budgets. Do not run it inside the app process.

`pane-interrupt.m` is a standalone consumer of public `spawn_ex`, `interrupt` and `poll`. Compile it with `ShellWorkers/NativePane.m`, Foundation and the matching ios_system framework. Supply a commandDictionary.plist and current Dash and shell frameworks beside the executable, with their runtime dependencies resolvable through `@rpath`. Create `bin/dash`, `bin/sleep` and `bin/pane-raw-reader` PATH markers beside it. Run the executable through an owned Simulator. The default mode starts real interactive Dash, interrupts a direct `sleep 30`, requires status 130, runs the next command and waits for the shell's actual completion with status 0. Run again with argument `raw`: a registered terminal reader switches its real PTY to raw mode, requires interrupt to return `ENOTSUP`, accepts input and completes normally. PTY denial fails that control rather than claiming raw-reader coverage. Both runs are bounded by a process alarm. The matching runtime must preserve direct-command SIGINT status through its targeted `ios_killpid` API; a proxy-only implementation does not qualify this path.

`worker-pool-check loss` starts the disposable crash command and requires `-EPIPE` with no fabricated command status. Explicit cancellation remains distinct from unexpected XPC loss.

`worker-pool-check host` starts a real extension command, which calls `ashell_worker_host_spawn_ex` to run the payload back in the app process. Register `worker-pool-nested-host` and `worker-pool-host-payload` with entries `worker_pool_nested_host_main` and `worker_pool_host_payload_main` in the disposable catalogues. It checks the original app PID, absence of worker identity markers, plain streams, separate stderr, status, resource usage and `EBUSY` for a second host pane. The command admission policy and high-memory workload qualification belong to the caller.

`worker-pool-check nested` exercises the public `spawn_ex` contract through two real extension processes. Register `worker-pool-nested` and `worker-pool-payload` in the disposable worker catalogues with entries `worker_pool_nested_main` and `worker_pool_payload_main` from the same checks framework and corresponding PATH markers. The outer command calls the host API; its worker calls `ashell_worker_spawn_ex` over the broker. The caller supplies HOME with a trailing `/.` to exercise bookmark path normalization. The payload checks a distinct process, non-terminal output, HOME naming the same directory by device/inode, and a writable TMPDIR matching its own Foundation temporary directory. Literal HOME spelling can differ on the phone (`/var` versus `/private/var`); it must still name the same directory. The outer worker reports root identity and HOME context if its preconditions fail. Both levels drain stdout and stderr independently, require exact bytes, exit status 7, descriptor close-on-exec and a final resource-usage snapshot. The baseline without the extended API must fail. No Herdr engine or terminal UI is involved.
