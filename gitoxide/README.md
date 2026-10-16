# Embedded gitoxide

This port adds `gix` and `ein` from gitoxide v0.60.0, revision `0115e902fd0334b8f370766993eb17babed3157f`, to full a-Shell. It preserves the upstream repository implementation and CLI, with a small embedded stream and argument boundary. Mini and extensions are unchanged; `lg2` remains available.

## Build

Install Rust 1.96.1 and its `aarch64-apple-ios` and `aarch64-apple-ios-sim` targets through rustup, and provide matching ios_system frameworks for each platform. Run from the repository root:

```sh
bash gitoxide/build.sh xcframework DEVICE_FRAMEWORKS SIMULATOR_FRAMEWORKS
bash createFakeCommands.sh
```

The directories must contain `ios_system.framework` and its headers. The recipe checks the source archive SHA-256, applies the patch with zero fuzz, builds with the upstream lockfile and release profile, and packages `gitoxide/gitoxide.xcframework`. Generated frameworks are ignored by Git. Set `GITOXIDE_BUILD_CACHE` to keep build output outside the checkout. The recipe builds arm64 iOS and arm64 Simulator slices and targets iOS 14. Cargo uses its default parallelism unless the caller sets `CARGO_BUILD_JOBS`.

The app project embeds the framework. `Resources/commandDictionary.plist` registers both names against `gix_ios_main`; run `createFakeCommands.sh` before building the app so native Dash can resolve both names through PATH. The compiled framework is a local build product; no binary download URL or release checksum is assumed.

## Command boundary and limits

The Objective-C adapter duplicates the command's ios_system stdin, stdout and stderr. Rust owns those descriptors and invokes the original CLI on a joined thread with a 16 MiB stack. Process descriptors 0/1/2 are never redirected. Help and argument errors return normally. Caught panics write a failure to the command's stderr and return 1. Progress renderers and process signal handlers are skipped for embedded invocations.

Enabled Cargo features are `sha1,pretty-cli,prodash-render-line,gitoxide-core-blocking-client,http-client-reqwest`. Anonymous HTTPS uses reqwest/rustls with certificate verification. SHA-256 repositories, optional TUI, parallel performance features and optional analytics/archive tools are excluded. External programs, SSH, credential protocol commands/helpers, hooks, filters, signing and editors return an explicit unsupported error. Authenticated remotes require separate qualification.

This CLI supports repository inspection, HTTPS clone/fetch and linked worktrees. It has no commit creation, rebase or push command; `ein` primarily supplies init and completions with this feature set. It is not a replacement for Git's complete CLI. Use explicit `gix -r PATH` when selecting repositories; cwd and environment belong to the host app.

## Verification

Run the acceptance script through native Dash in the real app terminal with a fresh absolute results directory as its first argument. Read every output/status file independently from the app container. Repeat with a second results directory in the same app process and verify the next ordinary shell command still works.

Verified on 2026-10-16 with Rust 1.96.1 and Xcode 27.0: this recipe built optimized release frameworks for arm64 iOS and arm64 Simulator from the pinned source and packaged both slices. Full a-Shell Debug built with that framework and ran on a fresh arm64 iOS 27 Simulator. Two native Dash acceptance batches passed in one app process, with output bytes, exit statuses and real repository files checked independently from the container. HTTPS clone/fetch, repository HEAD/README/log, linked-worktree isolation, dirty-removal rejection, clean removal, help/completions/config-tree and argument-error recovery passed. The upstream debug-only `ein panic` command returned an argument error in release. The next ordinary terminal command also produced its expected file. `lg2 --help` retained its usage output/status 1 and gix remained callable afterward.

The iOS 14 runtime, physical-device execution, Release app configuration, caught-panic behavior in release, extensions, authenticated remotes, cancellation and background lifecycle remain unverified here. The local Simulator fixture used a matching ios_system framework with minimum OS 15, so its successful iOS 27 run does not qualify iOS 14.

To remove the integration, revert its command registration, placeholder and framework project entries and rebuild without the generated framework. No global Git alias or user configuration is changed.
