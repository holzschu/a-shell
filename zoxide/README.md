# Native zoxide

This port embeds upstream zoxide 0.10.0 with its ranking, filtering, database format and atomic writes. The source archive is pinned by SHA256 in `build.sh`, and Rust 1.96.1 builds against the upstream Cargo lockfile. No dependency is added to zoxide's manifest. The patch changes the command entry, configuration environment and output boundary, and shares upstream first-match selection with the native `z` command.

## Use

The native `z` command uses upstream queries because the existing a-Shell prompt cannot retain POSIX functions. It changes directory through ios_system's `cd_main`, verifies the destination, and records the visit through upstream `add`. For example:

```sh
zoxide add "/path/to/project notes"
z notes
pwd
```

`z DIRECTORY` also visits an existing directory and records it. `z` without arguments uses `HOME`; `z -` uses the native shell's previous directory. Successful native `cd` and `chdir` visits, including directory picker and bookmark navigation, are recorded through upstream `add`. Failed changes are not recorded, and a database error leaves the original `cd` result and output intact. In a persistent POSIX shell such as Dash, upstream's prompt hook remains available:

```sh
eval "$(zoxide init posix --hook prompt)"
```

Set `_ZO_CD=1` to let native `cd KEYWORDS` query zoxide when its first argument is a missing relative path. Existing directories, files and symlinks retain stock `cd` behavior. Absolute paths, `cd -` and home expansion also keep their original meaning. The default leaves keyword fallback disabled.

Use `zi KEYWORDS` for interactive selection with the bundled fzf, or type `z KEYWORDS` followed by Space and Tab at the native prompt. Space-Tab excludes the current directory, while ordinary `zi` includes it. Tab after bare `z ` keeps directory completion. `zoxide query --interactive` prints a selection without changing directory. `_ZO_FZF_OPTS` supplies fzf options in the nested command's environment. The bundled fzf does not support subprocess previews or execute bindings, so the default selector omits upstream's directory preview. Database editing and imports return an explicit error. Shell initializers retain their upstream templates and require their corresponding shell.

Configuration is read through `ios_getenv` on every invocation. `_ZO_DATA_DIR` selects an absolute database directory. The default is `HOME/Library/Application Support/zoxide`, inside the app's writable home. `_ZO_EXCLUDE_DIRS`, `_ZO_MAXAGE`, `_ZO_RESOLVE_SYMLINKS` and `_ZO_ECHO` retain upstream semantics. Command output and handled errors use the invoking ios_system thread's borrowed streams. An unexpected Rust panic is caught, but the host's panic hook may also write to process stderr. The adapter neither replaces nor closes process descriptors or host streams and retains no invocation cache. ios_system owns directory changes. Relative native jumps and current-directory exclusion use the session's logical `PWD`, with upstream symlink resolution when requested.

Concurrent zoxide invocations in one app are rejected while another invocation runs, preventing overlapping database updates. Pthread cancellation is deferred until Rust returns and releases its database state and the command lock. This port does not provide general process isolation or interruptible database operations.

## Build

Install the rustup-managed Rust 1.96.1 toolchain. From the repository root, use the existing native-framework producer:

```sh
nice -n 15 bash ci/native-frameworks.sh zoxide
```

It builds the pinned ios_system dependency, device arm64 and Simulator arm64/x86_64 frameworks, joins the Simulator architectures, and audits `./.build/dist/zoxide.xcframework.zip`. Both platforms target iOS 14. The producer checks command exports, artifact platform/dependencies, stripped and gzip sizes, and the host command contract. It uses the existing Actions matrix and release manifest.

To build a single slice against a matching ios_system framework with headers:

```sh
ZOXIDE_BUILD_CACHE=/absolute/owned/cache bash zoxide/build.sh framework FRAMEWORKS device
ZOXIDE_BUILD_CACHE=/absolute/owned/cache bash zoxide/build.sh framework FRAMEWORKS simulator
ZOXIDE_BUILD_CACHE=/absolute/owned/cache bash zoxide/build.sh framework FRAMEWORKS simulator-x86_64
```

For an app build, extract the audited XCFramework into `zoxide/zoxide.xcframework`, then run the repository's normal `createFakeCommands.sh` and app build. Full a-Shell embeds it; mini and extension embedding are unchanged. No binary-target URL or checksum is added until an upstream release asset is published.

## Verification

The host fixture links the real exported command entries and upstream engine. It substitutes only ios_system's external stream, environment and directory services, and cannot qualify app session restoration or iOS loading:

```sh
ZOXIDE_BUILD_CACHE=/absolute/owned/cache nice -n 15 bash zoxide/build.sh host
bash zoxide/tests/host.sh /absolute/owned/cache/host-command /absolute/empty/results
```

The host checks cover a 1,000-directory fixture with spaces and Unicode, ranking, add/query/remove, missing/corrupt databases, no match, invalid options, unsupported operations, POSIX initialization, same-process environment changes and recovery, scoped output, failed directory changes, and descriptor stability over 20 calls.

Host selection checks run the fzf CLI in filter mode through the external command boundary. CI pins the CLI to fzf 0.74.5, the version used by the bundled port. These checks do not qualify the bundled iOS selector's terminal interaction or restrictions; those require the app probes.

For Simulator and phone acceptance, copy `tests/acceptance.sh` into the app's Documents directory and run it through Dash with a new absolute result directory and nonce. Capture the same script on a baseline without this port first: its version gate must fail before creating the database fixture. On the candidate:

```sh
dash /absolute/app/Documents/acceptance.sh /absolute/app/Documents/zoxide-results fresh-nonce
```

After that script passes, execute these as separate commands at the existing native a-Shell prompt, replacing `RESULTS` with that same absolute app result directory:

```sh
setenv _ZO_DATA_DIR "RESULTS/data"
setenv _ZO_ECHO 0
z café >"RESULTS/root-z.out" 2>"RESULTS/root-z.err"
pwd -P >"RESULTS/root-cwd.out"
cd "RESULTS/fixture"
setenv _ZO_DATA_DIR "RESULTS/native-missing"
z caf >"RESULTS/root-missing.out" 2>"RESULTS/root-missing.err"
pwd -P >"RESULTS/root-missing-cwd.out"
setenv _ZO_DATA_DIR "RESULTS/data"
echo ZOXIDE_ROOT_STREAMS_OK >"RESULTS/root-next.out"
```

Read back the entire result directory and run `bash zoxide/tests/verify.sh RESULTS fresh-nonce` on the Mac. Repeat in the same app process. Restore the prior environment and cwd afterward; preserve any existing database.

On the physical phone, measure at least 20 alternating native-prompt jumps between the fixture fragments `0042` and `café`, after verifying their exact destinations. Record each monotonic interval from submitted jump to correct cwd and an editable prompt, including query and database writes but excluding relay/network submission. Require nearest-rank p95 at most 50 ms. Host or query-only timings do not satisfy this requirement. Record the app source, selected framework/runtime hashes, backend, device/OS and result-file nonce. Also execute the changed framework path in the iPad app on macOS; compilation alone does not qualify sandbox loading.

Simulator, phone timing, signed app loading and macOS app behavior require separate execution receipts.
