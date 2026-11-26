# App build matrix

`.github/workflows/app-build.yml` builds the existing `a-Shell-noPython`, `a-Shell-mini` and `a-Shell` targets for generic iOS and iOS Simulator. All device builds use arm64. The noPython and mini Simulator builds use arm64 and x86_64 in the same app. The full Simulator build uses arm64 only because the pinned Node framework has no x86_64 Simulator slice. These are unsigned compile, link and architecture checks, not signing, installation or runtime tests. Use a `ci/app-build-*` branch for a fork run without updating its default branch. CI defaults to `macos-26-intel`; a manual dispatch can set `runner` to `macos-26` to use an Arm64 host instead. This does not change the app architectures.

Use Xcode 26.6 and uv from a clean, dedicated checkout:

```sh
uv run ci/build-app.py build a-Shell-noPython device
uv run ci/build-app.py build a-Shell-noPython simulator
```

Use `prepare` instead of `build` to verify and install the inputs without compiling. Add `--dry-run` to list the selected installation paths without downloading or replacing files. Repeated runs verify cached archives and replace only outputs the script previously installed. Do not use a checkout populated by `downloadFrameworks.sh` or another framework installation. The script leaves `project.pbxproj` unchanged. The build produces apps under `.build/app/`, and the job summary lists each unavailable framework path, including inputs of dependent targets. The workflow also attaches the same summary as a text artifact.

## Update an input

`xcfs/frameworks.json` owns the pins. `releases` contains the published SwiftPM ZIPs and their SHA-256 digests. `artifacts` groups exact `.xcframework.zip` members by fork Actions archive; each record pins the archive URL, SHA-256, producer run attempt and source revision. A release is preferred if it contains the required architecture set. Simulator inputs must still be universal except for Node in the full app. The resolver tries the pinned fork artifact if the release lacks a compatible slice; a checksum failure never falls back. Compatibility is checked against both the xcframework's `Info.plist` and its Mach-O architectures. For the app's second Python interpreter, the build driver stages `pythonA.framework` and the `PythonA*` extensions from the same pinned inputs, with separate bundle and Mach-O identities.

Fill in a pending input by adding the exact artifact member to its producer archive's `frameworks` map. For a new producer run, verify the outer archive digest and audit the inner ZIP and its binaries before changing a pin. Actions archives expire; replace an unavailable archive with a verified upstream release when published or with a new qualified artifact pinned to its exact run attempt. `extra` lists link inputs specified through build settings rather than file references. `resources` lists non-framework runtime files supplied by the same producer archives.

After changing a release pin, regenerate and check the existing release-only SwiftPM package:

```sh
uv run ci/build-app.py package > xcfs/Package.swift
uv run ci/build-app.py package --check
```

Run `bash tests/app-frameworks.sh` to check the staging CLI's missing-input summary, universal Simulator fallback, rerun, checksum failure and second-interpreter packaging without network downloads.
