# Embedded navi

navi 2.24.0 is pinned at `5515367dc8a2a561d2d82b8352f729b1da4120d3` and built with Rust 1.96.1. `native.patch` adapts command dispatch, output and invocation state for an embedded ios_system command. This integration requires the separate fzf command and the public `ios_getWindowSize` getter in [ios_system #177](https://github.com/holzschu/ios_system/pull/177). a-Shell's current v3.0.5 binary target lacks that getter; update its URL and checksum in `xcfs/Package.swift` when an ios_system release includes #177, then rebuild both tools against that release.

Build arm64 device and Simulator frameworks against matching ios_system frameworks, then package them:

```sh
bash navi/build.sh framework device DEVICE_FRAMEWORKS
bash navi/build.sh framework simulator SIMULATOR_FRAMEWORKS
bash navi/build.sh xcframework "$PWD/navi/navi.xcframework"
```

Install Rust 1.96.1 with rustup before building; the recipe adds the iOS target to that toolchain. `NAVI_BUILD_DIR` selects an external cache; the default is `~/Library/Caches/a-shell/navi`. The recipe verifies the source archive and applies the patch with zero fuzz. Generated frameworks are ignored by Git. Before building the app, run `bash createFakeCommands.sh` from the repository root to generate command placeholders. Full a-Shell embeds the XCFramework and registers `navi_ios_main` in its command dictionary.

Child commands run through ios_system. Captures use regular files in an invocation-owned temporary directory, removed when the command returns, including failure and cancellation. fzf reads keys from the session tty and renders through inherited terminal stderr. No process-wide fd replacement or private stream ownership API is used. Invocation configuration and environment overrides are cleared before return. Users supply their own cheat files through navi's normal paths or `--path` option.

The embedded backend uses fzf. Skim, previews, launching an external editor and installing shell widgets are unavailable. Shell commands and variable suggestions execute through the registered `dash -c` command, including shell builtins and normal shell exit statuses. Variables chosen earlier in a cheat are exported to the commands of later suggestions, so `$ second: echo "$first"` works. Ctrl-C interrupts the command that is running inside a snippet, but the snippet's remaining commands still run, so a loop such as `while true; do sleep 1; done` cannot be interrupted from the keyboard. The embedded build fixes this route rather than using the desktop `shell.command` configuration or ios_system compatibility `sh`; it does not provide desktop process or PTY facilities.

The recipe targets iOS 14. Xcode 27 requires an iOS 15 override when building the ios_system test framework locally; running on a newer Simulator does not qualify iOS 14 runtime behavior. A fresh iOS 27 Simulator full-app check passed exact Unicode selection, Escape and Ctrl-C returning 130, same-process re-entry and zero temporary captures after return. Physical-device behavior remains unverified.

Run `dash navi/tests/shell-route.sh ABSOLUTE_TEST_DIRECTORY` inside the built app to check shell builtins, nonzero snippet status and variable suggestions with and without whitespace after the colon. The directory must exist and contain only disposable test data.
