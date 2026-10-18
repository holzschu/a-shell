# Embedded fd

This port embeds sharkdp/fd 10.5.0 at `4f81778774463bf414a184cbe6d5219ad2229646`, built with Rust 1.96.1 and the upstream Cargo lockfile. The recipe verifies the source archive SHA-256 before applying the embedding patch. Only arm64 iPhoneOS and arm64 Simulator slices are produced, targeting iOS 14.0.

Build matching ios_system frameworks first, then run from the repository root:

```sh
bash fd/build.sh xcframework DEVICE_FRAMEWORKS SIMULATOR_FRAMEWORKS
sh createFakeCommands.sh
```

Each argument is a directory containing `ios_system.framework` with its public headers. Install Rust 1.96.1 with rustup (`rustup toolchain install 1.96.1 --profile minimal`); the build adds the `aarch64-apple-ios` or `aarch64-apple-ios-sim` target to that toolchain itself. Build outputs default to an external temporary cache; `FD_BUILD_CACHE` selects another directory. The generated `fd/fd.xcframework` is ignored by Git. Xcode embeds it only in full a-Shell; the command dictionary maps `fd` to `fd_ios_main`, and `createFakeCommands.sh` creates the lookup placeholder. Mini and extensions have no new framework entry.

The original filename matching, ignore handling and parallel directory traversal stay upstream. The adapter supplies owned duplicates of ios_system's command stdout and stderr to the Rust workers. It does not redirect process descriptors 0, 1 or 2, install a process-wide signal handler, or terminate the app when Clap handles help, version or invalid arguments. A mutex rejects simultaneous fd invocations; a pthread cleanup handler restores the working directory before returning.

Automatic color follows a-Shell's terminal, not the duplicated descriptor. The adapter asks `ios_isatty` on the invoking command thread whether stdout is the terminal, and reads `NO_COLOR` and `LS_COLORS` from `environmentVariables(ios_currentPid())`, so values set for a single command (`NO_COLOR=1 fd ...`) are honored. Redirected output stays free of escape sequences, and `--color=always` still forces them.

`-x`, `-X` and `--list-details` return status 1 with an explicit unsupported-process error. This port has no child-command execution adapter. Cancellation, background/foreground transitions and physical-device runtime remain unverified.

## Acceptance

In a disposable app container, run the fixture through the real a-Shell terminal with one native Dash invocation:

```sh
dash fd/tests/acceptance.sh WORK_DIRECTORY RUN_NONCE
```

Use an empty work directory and copy the script into the container first. Read the result files back to the Mac, then run:

```sh
bash fd/tests/verify.sh WORK_DIRECTORY RUN_NONCE
```

The checks cover real filename search, extension and directory filters, hidden files, ignore overrides, spaces and Unicode, invalid patterns/options, unsupported command execution, working-directory restoration and repeated invocation followed by an ordinary shell command. The verifier compares literal expected output, explicit statuses, stderr and the fresh run nonce independently of UI automation.

Verified on 2026-10-16: device and arm64 Simulator frameworks built successfully, followed by a full a-Shell Simulator build. On a fresh iOS 27.0 Simulator, the fixture failed in a control bundle without fd and passed twice in the candidate without restarting the app. The local Xcode 27 app build and its ios_system Simulator dependency used a minimum of iOS 15.0; this does not qualify iOS 14 runtime.
