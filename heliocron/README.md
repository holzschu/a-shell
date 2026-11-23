# Native heliocron

Embeds heliocron 1.0.0 at revision `45494f235b442f64aa82d24d5610844190a5004c`, licensed under Apache-2.0 OR MIT, with Rust 1.96.1. The recipe checks the source archive's SHA-256 and builds its locked dependencies. Both license files accompany the generated framework.

The patch retains upstream solar calculations, reports, configuration and event selection. The native entry point parses arguments without exiting the app, returns command status and writes to duplicated ios_system command streams. Darwin lacks the POSIX timer APIs used by upstream's Unix implementation; on Apple platforms a per-invocation Tokio timer waits in intervals of at most one second, checking wall-clock time again after each interval. Upstream's past-event and missed-event checks remain in effect. Waiting does not grant background execution time or schedule an iOS notification.

## Build

Install Rust 1.96.1 with `rustup toolchain install 1.96.1 --profile minimal`. Provide matching device and arm64 Simulator ios_system frameworks with `Headers/ios_system.h`, then run from the repository root:

```sh
CARGO_BUILD_JOBS=2 nice -n 15 bash heliocron/build.sh xcframework DEVICE_FRAMEWORKS SIMULATOR_FRAMEWORKS
```

The recipe adds the required Rust targets. Its output, `heliocron/heliocron.xcframework`, is ignored by Git. Inputs and intermediates use a temporary cache; set `HELIOCRON_BUILD_CACHE` to retain them elsewhere. `build.sh framework FRAMEWORKS device|simulator` builds one slice. Both slices target arm64 and iOS 14. The project embeds the framework in both full a-Shell and a-Shell mini and registers `heliocron` with a Dash lookup placeholder.

## Use

```sh
heliocron --latitude 51.4769 --longitude -0.0005 report
heliocron --latitude 51.4769 --longitude -0.0005 report --json
heliocron --latitude 51.4769 --longitude -0.0005 wait --event sunset
```

`wait` returns at the event so a shell script can run its next command. `--offset [-]HH:MM[:SS]` shifts that time; past events return an error. Coordinates can come from a separate `location` command. This contribution does not add location permission or the `location` command itself.

## Validation

Run `dash ~/Documents/terminal.sh ABSOLUTE_FRESH_RESULT_DIRECTORY` after copying `heliocron/tests/terminal.sh` to Documents. It requires native Dash, Python 3 and a `location --timeout` command that returns Core Location JSON. The script pipes that JSON to Python, passes the coordinates to heliocron, checks text and JSON reports, checks a fixed-date Greenwich sunset, verifies help and invalid-argument status, repeats a report, and shifts today's sunset to about one minute ahead before waiting. `result.json` records elapsed time and lateness. The fixed-date check uses an explicit UTC offset; heliocron requires `+00:00`, including the sign.

The existing upstream host suite runs with `TZ=Etc/GMT-1 cargo +1.96.1 test --locked --features integration-test`; two upstream fixtures assume a fixed UTC+1 offset. Simulator acceptance and device compilation are separate checks. iOS 14 runtime, cancellation, unattended long-duration background suspension and `poll --watch` are unverified.

On 2026-10-20, both native framework slices compiled. The terminal script passed in a full a-Shell arm64 iOS 27 Simulator using a test-only framework with the existing Core Location command. The shifted sunset wait returned 0 after 59.48 seconds, 0.021 seconds after its target. An ordinary shell command returned afterward. Before installation, the same app reported `heliocron: command not found`; the unmodified heliocron source also failed to compile for Darwin because its POSIX timer APIs are unavailable.

The device framework also passed on a physical iPhone in a development a-Shell-mini build with a separate background-location feature enabled. While the app was off screen, the shell script piped JSON from `location` to jq, used its coordinates for text and JSON reports, and shifted sunset to about one minute ahead. The wait returned 0 after 60 seconds, with zero lateness at one-second measurement resolution; an ordinary shell command returned afterward. The original development app was restored and its off-screen bridge verified. The separate location/background feature is outside this contribution.
