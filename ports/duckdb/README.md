# DuckDB for a-Shell

`duckdb -c SQL` runs SQL against a fresh in-memory DuckDB database and prints the first query result as CSV with a header. For multiple statements, use one result-producing query per invocation when you need its output. `duckdb --version` reports the linked engine. The CLI does not provide an interactive shell, persist its database across invocations, or download extensions. It embeds Core Functions, JSON and Parquet. CSV is part of the engine. Use an absolute document path if the caller does not control the command's working directory.

## Build

The `DuckDB command framework` workflow builds `DuckDBCommand.xcframework.zip` and `SHA256SUMS` from the pinned DuckDB 1.5.4 sources on `macos-26`. It uses the `ios_system` release and checksum from `xcfs/frameworks.json`, the same manifest used by App build. The current runtime requires iOS 15. The two slices are device arm64 and Simulator arm64/x86_64. The workflow uploads a run artifact; it does not commit binaries or publish a release.

## Qualify on a-Shell

Use an owned copy of a successfully built a-Shell Mini Simulator app. Check the CI run and artifact checksum, and match the `ios_system` UUID of the host and the pinned Simulator slice before composing the app. Do not use the original downloaded `.app` as the writable candidate.

1. After copying or thinning the Simulator app, run `bash ports/duckdb/stage-app.sh PATH_TO_APP PATH_TO_SIMULATOR_SLICE/DuckDBCommand.framework`. The script checks the platform and architectures, copies the framework, and adds the command catalog entry and `bin/duckdb` discovery marker. It refuses to overwrite an existing DuckDB; use a fresh app copy for a rerun. The noPython artifact is not part of this integration.
2. For App build CI, stage the framework after copying/thinning and before the existing app signing step. Ad hoc sign the new framework, then sign the app with its application-group entitlements. Verify the app with `codesign --verify --deep` before installing it on the owned Simulator. To test on a physical device, use the device slice and sign the composed app and its embedded code with your development team identity and the app's entitlements.
3. Copy `tests/duckdb/{smoke.sh,fixture.csv,fixture.json}` to a dedicated Documents directory. Invoke `sh smoke.sh duckdb` from the app, not through `simctl spawn`. Capture stdout, stderr, status and wall time. The script checks CSV and JSON aggregation, a Parquet write/read round trip, a failing SQL statement and recovery. The expected CSV is:

   ```csv
   category,total
   alpha,42
   beta,5
   ```

On Simulator, reinstall the unmodified app to roll back. On device, keep the previous signed build available and reinstall it over the test app without uninstalling.
