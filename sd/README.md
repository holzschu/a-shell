# Embedded sd

Build chmln/sd tag `v1.1.0` at `4a7b216552d64134c0fa17a59b9d557d89019f0f` with Rust 1.96.1 and its locked dependencies. The tag's workspace still declares version `1.0.0`, so `sd --version` prints `sd 1.0.0`. The recipe checks the source archive SHA-256 before applying the patch.

The adapter exports `sd_ios_main`, borrows the calling command's ios_system FILE streams and returns native exit statuses. Clap help and argument errors return instead of terminating the host app. Upstream replacement logic, regular expressions, fixed strings, capture expansion, preview, streaming and atomic file replacement are retained. It does not redirect process descriptors.

## Build and integration

Install Rust 1.96.1 with rustup. Supply ios_system frameworks matching each SDK, then run from the repository root:

```sh
bash sd/build.sh xcframework DEVICE_FRAMEWORKS SIMULATOR_FRAMEWORKS
bash createFakeCommands.sh
```

The recipe produces arm64 device and arm64 Simulator slices with minimum iOS 14.0. Build intermediates default to a temporary directory; set `SD_BUILD_CACHE` to retain them elsewhere. Upstream's release stripping is disabled because its LINKEDIT layout is rejected by SDK 27's loader. Generated `sd/sd.xcframework` is ignored by Git.

The full app embeds the XCFramework, maps `sd` to its exported entry in `Resources/commandDictionary.plist`, and creates the empty command lookup resource through `createFakeCommands.sh`. Mini and extensions have no new framework dependency. Remove these three integration entries to roll back; no application data migration is required.

## Acceptance

Run `tests/terminal.sh` through the full app's terminal with a fresh disposable directory as its argument. Run the host verifier against that directory after retrieving the results:

```sh
bash sd/tests/verify.sh RESULT_DIRECTORY
```

The public boundary is the real app command: exact version/stdin/file output, multiple file replacement, fixed strings, captures, Unicode, preview without mutation, invalid regex status 1, invalid option status 2, missing file status 1, and successful re-entry followed by an ordinary shell command. No host executable substitutes for sd.

Verified with Xcode 27.0 on an arm64 iOS 27.0 Simulator: two full-terminal runs passed without restarting the app, followed by an ordinary terminal command. The local Simulator bench used adapted public dependency frameworks and an app deployment target of iOS 15.0. Physical-device execution and earlier iOS runtime behavior remain unverified.
