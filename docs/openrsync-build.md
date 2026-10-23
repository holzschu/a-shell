# Build openrsync frameworks

Run on macOS with Xcode, BSD make (`brew install bmake`) and uv:

```sh
nice -n 15 bash scripts/build-openrsync.sh
```

The recipe verifies pinned openrsync source and ios_system 3.0.5 inputs before extraction, uses openrsync's configure and BSD Makefile, and writes two ZIPs under `.build/openrsync/dist`: `openrsync.xcframework.zip` and `openrsyncA.xcframework.zip`. Each contains an arm64 iOS 14 framework and one universal arm64/x86_64 iOS 14 Simulator framework. Each framework contains its license notices; `checksums.txt` and audit reports are written beside the ZIPs. The optional first argument selects the build directory. Cached patched sources must match both patches, otherwise the recipe fails rather than reusing different input.

The iOS patch uses ios_system's thread-local streams, nested command dispatch and wait. It retains the two framework images required by the existing rsync dispatcher. Ctrl-C shuts down the protocol socket and allows protocol cleanup before returning 130, including daemon connections. The separate source patch corrects checksum success handling, releases the directory traversal's root reference and skips tagged receiver acknowledgements on unframed streams. Each invocation resets options, filters and borrowed logging state before the host closes its streams. Assertions end the command with status 14. One command runs per framework image; concurrent clients are not supported. Cancellation uses the session identity supplied by the host with `ios_setContext` and forwards another session's SIGINT to the prior simple handler. Another command replacing the process SIGINT handler can interfere with cancellation.

Run the public command acceptance fixture on an owned booted arm64 Simulator:

```sh
bash tests/openrsync/run.sh "$PWD/.build/openrsync" SIMULATOR_UUID
```

The fixture checks protocol compatibility (an incompatible version header returns status 2 without an abort), a client-side receiver pulling from a server started through a local transport helper with the real rsync server argv, and 20 iterations of checksum transfers with Unicode names and paths containing spaces, missing-source status 23, actual-transfer cancellation status 130, signal restoration, real transfer after cancellation, borrowed stream validity and no descriptor growth after the runtime's first dispatch. It retains both command images, changes borrowed output streams, checks filter reset, and verifies that cancelling a separate session preserves the active transfer and reaches the prior simple SIGINT handler. A loopback daemon peer verifies status 130 and socket closure while waiting for a daemon handshake. It uses published ios_system 3.0.5 and does not require an SSH client. x86_64 is audited statically.

The workflow builds and tests these products for pull requests and manual runs. Upstream tags matching `openrsync-v*` publish the already-audited ZIPs as an auxiliary release without changing the latest release. Fork runs never publish. Updating SwiftPM consumers requires downloading and verifying the eventual upstream release assets; fork artifact checksums do not identify future upstream ZIPs.
