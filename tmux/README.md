# tmux for a-Shell mini

The native port keeps tmux 3.8's server, command parser, layouts, renderer and session state. Server and client engines run in isolated shell worker extensions. Pane commands use the nested worker broker and ios_system logical terminals. Resize messages carry logical terminal dimensions, so the bundled client and server use an iOS protocol variant. No kernel PTY or forked child is simulated.

## Build

This change follows the worker pool in a-shell#1089, the Herdr integration in a-shell#1090, and the nested-worker broker. It also requires the ios_system worker execution, targeted interruption, native lifecycle, worker ownership and command-environment snapshot changes, plus Dash socket input and foreground-input ownership support.

Download [tmux 3.8](https://github.com/tmux/tmux/releases/download/3.8/tmux-3.8.tar.gz) and [libevent 2.1.13](https://github.com/libevent/libevent/releases/download/release-2.1.13-stable/libevent-2.1.13-stable.tar.gz) into `ARCHIVES`; their checksums are listed in `sources.sha256`. Supply the matching ios_system source headers and framework, and ncurses headers. Build each platform separately:

```sh
bash tmux/build.sh iphoneos "$ARCHIVES" "$OUTPUT/iphoneos" "$IOS_SYSTEM_SOURCE" "$DEVICE_FRAMEWORKS" "$NCURSES_INCLUDE"
bash tmux/build.sh iphonesimulator "$ARCHIVES" "$OUTPUT/iphonesimulator" "$IOS_SYSTEM_SOURCE" "$SIMULATOR_FRAMEWORKS" "$NCURSES_INCLUDE"
```

The recipe verifies source checksums, applies the iOS boundary patch and builds static libevent with the native tmux framework. It produces `sdk/TmuxNative.framework`, `sdk/TmuxHost.framework` and the separate `sdk/TmuxAcceptance.framework`. Package both platform slices as XCFrameworks in `tmux/build` before building the mini app:

```sh
for name in TmuxNative TmuxHost TmuxAcceptance; do
    xcodebuild -create-xcframework -framework "$OUTPUT/iphoneos/sdk/$name.framework" -framework "$OUTPUT/iphonesimulator/sdk/$name.framework" -output "tmux/build/$name.xcframework"
done
```

The host framework carries its compiled terminal description. The default pane terminal is `screen.xterm-256color`, which the bundled Vim recognizes without additional flags. Socket pane output translates bare LF to CRLF before tmux parses it, retaining existing CRLF across read chunks and preserving redirected data.

## Use and verification

Run `tmux new -s t`. Split with `C-b %` and `C-b "`, detach with `C-b d`, and return with `tmux attach -t t`. The app retains the server independently of each client invocation. Start new servers from an app terminal; a command running inside a worker can attach to an existing server.

`phone-check.sh` invokes the public `tmux` command through ios_system sessions. The mini app embeds and registers the acceptance command, which checks three panes, exact command/pipeline output, ordinary Vim with arrow keys and indexed colors, resize, detach/reattach, interruption and shutdown. It then repeats file/pipe/substitution/error cases 20 times. The `/dev/fd` glob is a diagnostic and is not an independent OS descriptor count.

```sh
dash /absolute/path/to/phone-check.sh "$HOME/Documents/tmux-qualification-UNIQUE"
```

`socket-check.sh /absolute/unused/long-prefix` checks long sockets, stale-socket restart, command aliases and socket selection. The prefix must exceed 104 bytes and permit worker socket access. The labelled case uses a unique name in the App Group default directory; the unsuffixed cases use an owned `TMUX_TMPDIR`. Neither touches the user's default server. Successful completion removes its test files.

Use an owned directory and exclusive access to the worker pool. Bound the invocation externally; a failed assertion can leave its test server alive. Expected markers are `TMUX_ACCEPTANCE_PASS` and `TMUX_PHONE_CHECK_PASS`.

## Runtime boundaries

The default Unix socket lives in the app's existing shared App Group. Host and engine workers require real membership; a bookmark granting file access to Documents does not grant Unix socket binding there. Explicit `-S` and `TMUX_TMPDIR` overrides need actual worker bind/connect permission. Long paths are handled by changing directory only for bind/connect and retaining the full path for discovery and cleanup.

Each active server, client and pane consumes a worker slot. Other commands share that capacity. App or iOS termination loses sessions. Background jobs (`run-shell`, `if-shell`, `#(...)`), `pipe-pane`, popups, copy piping, daemonization, `-D`, `-CC`, kernel process introspection and arbitrary POSIX process/signals are unsupported. Some report errors; popup and copy-pipe operations can return without starting a job. Pane shells must already be registered in the app; this does not execute downloaded native binaries.

The recipe copies the tmux and libevent licenses into the native framework and `NCURSES-LICENSE` beside the host framework's compiled terminal description.
