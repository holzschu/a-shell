# Embedded Ruff

Ruff 0.17.0 at `5b27c1ccfaa230fb195855f5cf3404a21e3379cd` runs as a native command in full a-Shell. The source archive is SHA-256 checked and compiled with Rust 1.99.0 using the upstream minimal-size profile, no default features and the system allocator. Only arm64 iOS and arm64 Simulator are produced; the deployment target is iOS 14.0, matching the app.

## Build

Install Rust 1.99.0 and select it before invoking the recipe. Supply directories containing matching `ios_system.framework` binaries and headers:

```sh
bash ruff/build.sh xcframework DEVICE_FRAMEWORKS SIMULATOR_FRAMEWORKS
```

`RUFF_BUILD_CACHE` selects an external build directory; the default is a temporary directory. For one platform, use `bash ruff/build.sh framework MATCHING_FRAMEWORKS device` or `simulator`. The combined result is `ruff/Ruff.xcframework`, ignored by Git. Full a-Shell embeds it through the project, `Resources/commandDictionary.plist` registers `ruff_ios_main`, and `createFakeCommands.sh` adds the lookup placeholder. Mini and extensions have no new entries. A maintainer-controlled binary release URL and checksum remain necessary before adding this generated artifact to the existing download catalogue.

## Adapter

`command.m` duplicates the command-owned ios_system streams. Only Ruff.framework binds read/write/readv/writev/isatty/fstat to these duplicates; the exported-symbol list hides those bindings from other frameworks. Process descriptors 0/1/2 are never replaced. Ordinary file descriptors pass through unchanged. One invocation runs at a time; an overlapping call returns 2. The main Rust thread and two Rayon workers use 16 MiB stacks and join before the stream copies close.

`native.patch` removes iOS jemalloc, exposes the static library, initializes process-wide logging/version/panic-hook state once and resolves cwd per invocation. These changes let a subsequent command run after changing directory or configuration. Lint/fix/format use the upstream implementation and return statuses 0/1/2.

## Checks and limits

Copy `tests/acceptance.sh` into the app Documents directory and invoke `dash ~/Documents/acceptance.sh FRESH_MARKER` through the app terminal. Then run `tests/verify.sh APP_DOCUMENTS/ruff-acceptance FRESH_MARKER` on the build host. The driver creates only throwaway files; it checks real file reads, fixed/formatted bytes, configuration changes, stdin, invalid input, exit codes and repeat invocation. A following interactive version command must write `ui-after.out` and its status to `ui-after.rc`; an ordinary shell command must write `RUFF_SHELL_ALIVE` to `shell-after.out` in the same results directory without an app restart. Host compilation alone does not qualify this contract.

Validated on 2026-10-16 with Xcode 27.0 (27A266a), Rust 1.99.0 and a fresh arm64 iOS 27.0 Simulator. The full-app terminal passed the driver and host verifier twice with distinct markers, separate interactive follow-ups and the same surviving app process. An earlier negative-control app copy without the Ruff dictionary entry returned 127 and failed the verifier. The Simulator framework is 14,565,416 bytes. The test fixture uses a local bundle identifier and server port and omits unavailable optional frameworks; these fixture adaptations are outside this contribution. Xcode 27 rejects app deployment targets below 15, so the fixture uses target 15 while the embedded Ruff framework targets 14. Its ios_system binary also targets 15 and produces a deployment-target linker warning; this bench does not qualify iOS 14 runtime.

Both arm64 device and Simulator framework recipes were executed successfully. The device framework is 14,472,792 bytes and reports platform IOS with minimum iOS 14.0. Physical-device runtime, iOS 14 runtime, language-server/watch modes, cancellation, overlapping commands, background/foreground and saved-session restoration remain unverified. No process or PTY emulation is included.

Rollback by removing the framework embed entry, command dictionary entry and fake-command line, then rebuilding the app. Build sources, frameworks, app bundles and demo screenshots stay outside Git.
