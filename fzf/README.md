# Embedded fzf

This port preserves fzf 0.74.5 at `c0a193e031f01fb50bf6f7be4381990a3753f7cf`, built with Go 1.27.2. The recipe verifies the source archive and Go runtime source before patching them. It uses the original finder and renderer with command-owned stream duplicates and the ios_system terminal route. No process fd 0/1/2 replacement is required.

## Integration prerequisites

The command adapter requires [ios_system #177](https://github.com/holzschu/ios_system/pull/177), which exports `ios_getWindowSize(int *, int *, const void *)`. It reads the command's session geometry without switching the calling Go thread's session. Until an ios_system framework release includes that change, build matching frameworks from its getter revision. Once released, use those upstream frameworks instead. Terminal input and raw mode use ios_system's existing callbacks.

The recipe targets iOS 14.0. Only arm64 device and arm64 Simulator slices are currently produced.

## Build

Provide matching device and Simulator ios_system frameworks with the required terminal API. Run from the repository root:

```sh
bash fzf/build.sh xcframework DEVICE_FRAMEWORKS SIMULATOR_FRAMEWORKS
```

Build files default to a temporary cache; set `FZF_BUILD_CACHE` to choose another external directory. The result is `fzf/fzf.xcframework`, which is ignored by Git. The project embeds it in full a-Shell. `Resources/commandDictionary.plist` maps `fzf` to `fzf_ios_main`; `createFakeCommands.sh` supplies its command placeholder. Mini and extensions have no new framework entry.

## Supported behavior

Piped input, filtering, interactive selection and Unicode use the upstream fzf implementation. Invocation state is reset and owned workers are joined before return. Escape, Ctrl-C and EOF are parsed as cancellation and return 130. One invocation is allowed per process; another returns 2.

External preview/execute actions, listeners, tmux/Zellij, shell integration generation and `FZF_DEFAULT_COMMAND` are rejected with status 2. Supply candidate input through stdin. Filesystem walker behavior and saved-state behavior still require qualification in the upstream app.

## Validation status

The source archive checksum, zero-fuzz patch application and shell syntax have been checked. The existing port's compiled Mac public-entry fixture passed selection, Unicode, cancellation and repeated invocation on 2026-10-16. This is host evidence using an external iOS API stand-in.

Full a-Shell 2.2.2 built and passed on a fresh iOS 27 Simulator on 2026-10-16, using the real ios_system terminal callbacks and the getter revision from #177. Independent file assertions checked exact selection bytes/status 0, Escape and Ctrl-C/status 130, repeated selection without an app restart, the next ordinary shell command, Unicode filtering, no-match/status 1 and unsupported preview/status 2. A separate fresh-process first invocation preserved cwd and wrote its status and next-command files into the requested directory. The local fixture omitted unavailable optional frameworks; these build adaptations are outside the contribution.

For app acceptance, check filter and selection, cancellation 130, the first ordinary command after return, same-process fzf re-entry, terminal resize and cold first invocation preserving cwd. Read output files and native command status back independently of UI automation. The Go runtime overlay prevents its first initialization from changing the host app's working directory. Run `tests/cold-shell.sh` as the first Go command in a fresh app process, using one native Dash invocation or sourcing it with the work and bundle paths as positional parameters. Terminal resize, background/foreground and saved-session restoration have not been qualified for this PR.

Xcode 27 rejects an iOS 14 deployment target in its build planner. A local app/framework test can use `IPHONEOS_DEPLOYMENT_TARGET=15.0` without changing the repository's deployment settings. Testing on a newer Simulator does not qualify behavior on iOS 14 or a physical device.

For option re-entry, compare `fzf --height=40%` with the following plain invocation in one app process. Repeat with `--reverse`, `--multi` (Tab must select only with this flag), `--border`, `--no-mouse`, and `--style=full:double` followed by plain `--border` (rounded again). Also compare `--ambidouble` with its following default, and a monochrome/no-bold invocation with its following default. Use the native app commands `setenv FZF_DEFAULT_OPTS --reverse` and `unsetenv FZF_DEFAULT_OPTS` for environment re-entry. Unsupported `--preview` must return 2 without affecting the following plain invocation. Run `tests/reentry.sh WORK` in one native Dash invocation for an automated public-command matching regression: default/path/default must restore the original ranking. The port resets the package border default, scheme character classes and ambiguous width, copies theme templates before mutation, and refreshes the tmux environment marker per invocation.
