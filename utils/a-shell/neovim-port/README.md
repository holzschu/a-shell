# Native Neovim for a-Shell mini

This port adds `nvim` alongside `vim` in the existing mini app. It targets iOS 16 or later and uses Neovim 0.12.6, the latest release checked on 2026-11-27. LuaJIT is pinned to `fbb36bb6bfa88716a47c58bcf9ce9f2ef752abac` and compiled with `LUAJIT_DISABLE_JIT`. Pure Lua and Vimscript plugins can load without executable JIT memory.

## Runtime

Neovim keeps its upstream split UI: the TUI launches `nvim --embed` via the a-Shell worker pool and uses the stock RPC protocol. The server ran in a separate worker on Simulator, and the TUI reached the editor in a source-built arm64 app on iPhone. The [historical failure](evidence/stock-server-spawn.err), E903 `Function not implemented` followed by `Failed to start Nvim server!`, predates that runtime. A second in-process server image is no longer needed.

`NvimCommand.framework` registers `nvim_ios_main`. It opens `Nvim.framework` using a path relative to the host app, including when called from a worker extension. It duplicates the command's three logical streams into owned descriptors above 2 without replacing process descriptors 0–2. The port uses ios_system terminal dimensions and interactive-input hooks. The editor's runtime and licenses live in `Nvim.framework`; seven pinned upstream Tree-sitter parsers are linked statically rather than loaded as separately signed libraries.

| Feature | Status on the current Simulator build |
| --- | --- |
| TUI, Lua config, Lua syntax capture, edit/save/quit, rotation, repeat invocation, toolbar Esc and Ctrl-C | Passed in a Herdr pane using actual toolbar touches and saved-state readbacks. Rotation changed 52×45 to 71×20. |
| Local lazy.nvim | Passed with LuaJIT and JIT disabled. The 0.8.3 port could not load this checkout. |
| `system()`, `:!`, non-PTY `jobstart()` | `system('echo ok')` and `:!ls` exited 0. A direct `ls` job returned stderr and status 1 for a missing file. Dash jobs using `>&2` appended `worker connection failed: Bad file descriptor` and returned 125 instead of the command's exit status, so the strict subprocess check remains red. |
| PTY jobs and `:terminal` | Unsupported: the worker stream API cannot allocate a PTY. `:terminal dash` returned E903 `function not implemented`. |
| LSP | On Simulator, `vim.lsp.start()` completed initialize and shutdown over stdio with a Lua fixture launched by the registered `nvim` command. Other LSP servers, providers and native plugin binaries were not tested. |
| Lua `os.execute` | Unsupported; raises `os.execute is unsupported on iOS`. |
| Physical iPhone | A framework overlay on an older worker failed at E903 `Operation not supported`. In the source-built app, a Herdr pane passed Lua init and syntax capture, toolbar Esc, edit/save/quit, rotation, and a second edit discarded with toolbar Ctrl-C. Both invocations returned status 0 to the same host process. The final lazy.nvim replay timed out waiting for XCTest input. An earlier device package with the same Neovim framework pins passed headless with cache and state in a writable test directory. |

The current overlap control delivered 20 unrelated output lines to their original fd 1 and zero to Neovim. The test-only legacy redirect leaked all 20 into Neovim.

On iPhone 16 Pro, the same live editor survived 15, 60 and 180 seconds behind Settings and behind Safari. All six rows retained the app and editor worker PIDs, the active Herdr command and the editor's screen marker. No new crash paths appeared. This measures survival across foreground switches, not continuous execution while backgrounded.

On arm64 Simulator, the 0.8.3 image was 4,390,160 bytes and its runtime occupied 20,388 KiB. The 0.12.6 two-image payload is 8,518,784 bytes and its runtime occupies 26,420 KiB. For each version, launch the same mini app in portrait, open a Herdr pane, and edit the same one-line Lua file. Check `nvim --version` separately, write the editor PID and grid dimensions at `VimEnter`, then sample the host and editor RSS five times with `ps` before quitting. Both runs returned to the shell. The grid differed by two rows; this is a comparison of the same workload, not a controlled peak memory benchmark.

| Neovim | Grid | Host before edit (KiB) | Host during edit (KiB) | Worker during edit (KiB) |
| --- | --- | ---: | ---: | ---: |
| 0.8.3 | 52×48 | 441,744 | 431,856–443,024 | 107,712–107,728 |
| 0.12.6 | 52×46 | 442,960 | 444,000–444,128 | 107,408–107,616 |

RSS includes shared pages. Do not add the two processes or use these readings as a phone memory limit.

## Build and package

Requirements: Xcode, CMake, Ninja, host LuaJIT, Perl, curl, rsync, patch and shasum. Point `NVIM_IOS_FRAMEWORKS` at the matching slice directory of a worker-capable `ios_system.framework` that includes `Headers/ios_spawn.h`. The app must ship a runtime that exports the corresponding spawn ABI. The old ios_system pin in a-Shell master does not. Use a separate build cache for each SDK and architecture. The recipe verifies upstream source digests and uses the pinned Neovim dependency superbuild.

```sh
port=utils/a-shell/neovim-port
NVIM_IOS_CACHE=/path/to/device-cache NVIM_IOS_SDK=iphoneos NVIM_IOS_ARCH=arm64 \
  NVIM_IOS_FRAMEWORKS=/path/to/device-sdk bash "$port/build.sh" native
NVIM_IOS_CACHE=/path/to/device-cache NVIM_IOS_SDK=iphoneos NVIM_IOS_ARCH=arm64 \
  bash "$port/build.sh" payload /path/to/device-payload
```

Repeat with `iphonesimulator` for `arm64` and `x86_64`, with separate caches, payloads and SDK directories. Assemble both products:

```sh
bash "$port/build.sh" xcframeworks /path/to/device-payload \
  /path/to/simulator-arm64-payload /path/to/simulator-x86_64-payload /path/to/new-output
```

The output includes a ZIP and SHA-256 for each XCFramework. Both contain iPhoneOS arm64 and a universal Simulator slice. The build checks the platform of each Mach-O and requires identical runtime trees across all three inputs. For source builds, place the XCFramework directories at `Neovim/Nvim.xcframework` and `Neovim/NvimCommand.xcframework`. The mini target embeds and signs them; its workers inherit the mini command dictionary and marker. Do not install a Simulator slice on a device.

The app build pipeline in [a-Shell #1201](https://github.com/holzschu/a-shell/pull/1201) resolves these names from `xcfs/frameworks.json`. Add the two verified ZIPs there after publication, using the actual asset URLs and digests, and regenerate `xcfs/Package.swift` with `uv run ci/build-app.py package`. The local archives passed `ci/audit-artifact.py --max-minos 16.0` and the resolver staged both paths for both platforms. No published pins or complete CI app build are claimed. The app must contain both the worker-enabled ios_system runtime and app and extension executables compiled with its broker API before registration ships. A framework overlay on a seed with older worker executables cannot supply their missing exports. If the packaging lane keeps a separate worker command dictionary and `bin` directory, register `nvim` in those resources too. Check each signed worker's broker exports, dictionary and command marker before installing.

## Verify

Use an owned Simulator and an already built mini app. `isolation.sh` compiles the retained overlap fixture against the exact SDK headers, then exercises the production command entry point. Run it against a disposable copy of the app; the script temporarily places a standalone probe next to the app binary.

```sh
bash "$port/isolation.sh" OWNED_SIMULATOR_UUID BUILT_APP IOS_SYSTEM_SLICE RECEIPTS
```

For the UI, stage lazy.nvim v11.17.5 (`85c7ff3711b730b4030d03144f6db6375044ae82`, tag archive SHA-256 `54f4db00d3e0fadbe29a26ba5df9959a2331556dcab317cfd4e945d443b7c2ee`) at `Documents/lazy.nvim` in a fresh disposable app. Disable Herdr onboarding and keep the shell profile at `cd ~/Documents`. Build the orientation test runner with:

```sh
xcodebuild build-for-testing -jobs 4 -project "$port/ui/Probe.xcodeproj" \
  -scheme Probe -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /path/to/owned/ui-derived ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
NVIM_APP_BUNDLE=YOUR_MINI_BUNDLE_ID bash "$port/escape-acceptance.sh" \
  OWNED_SIMULATOR_UUID /path/to/Probe.xctestrun
```

XCTest supplies orientation changes only. AXe sends terminal input and taps the actual accessory buttons. If HID input hid the accessory, the driver opens it with a-Shell's Option-Command-T shortcut before matching and tapping the button. A keyboard substitute cannot pass the toolbar check. The driver prints its receipt directory and runs `verify.sh` on the files saved by the live pane. The strict subprocess row is part of this check. See [device-acceptance.md](device-acceptance.md) for the physical matrix.

### Long Lua paths

Neovim 0.12.6 can encode the full source path into a cache filename longer than the filesystem limit. `loader-cache.patch` hashes oversized basenames, keeping normal names and cache validation. Remove the carry when the pinned release includes [Neovim #42179](https://github.com/neovim/neovim/pull/42179) or an equivalent fix, then rebuild both frameworks and rerun the long-path and UI tests. Copy `loader-cache.sh` and `loader-cache.lua` to a fixture directory and invoke the driver via the app with a fresh absolute case path. Require `NVIM_LOADER_CACHE_PASS` and zero status.

## Rollback

Rebuild the prior mini app without the `nvim` registration, marker and two frameworks. This port does not migrate user configuration or replace `vim`.
