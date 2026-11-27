# DuckDB for a-Shell

`duckdb -c SQL` runs a batch against a fresh in-memory DuckDB database and returns CSV with a header. `duckdb --version` reports the linked engine. The CLI does not provide an interactive shell, persist its database across invocations, or download extensions. It embeds Core Functions, JSON and Parquet. CSV is part of the engine. Use an absolute document path if the caller does not control the command's working directory.

## Build

The `DuckDB command framework` workflow builds `DuckDBCommand.xcframework.zip` and `SHA256SUMS` from the pinned DuckDB 1.5.4 sources on `macos-26`. It targets iOS 15 because the pinned `ios_system` framework requires iOS 15. The two slices are device arm64 and Simulator arm64/x86_64. No binary is committed or published by the workflow.

## Qualify on a-Shell

Use an owned copy of a successfully built a-Shell Mini Simulator app. Check the CI run and artifact checksum, and match the `ios_system` UUID of the host and the pinned Simulator slice before composing the app. Do not use the original downloaded `.app` as the writable candidate.

1. Copy the Simulator `DuckDBCommand.framework` into the candidate's `Frameworks/`. Add `duckdb` to `commandDictionary.plist` as `["DuckDBCommand.framework/DuckDBCommand", "duckdb_ios_main", "c:", "no"]`, and create the empty `bin/duckdb` command marker.
2. Ad hoc sign the new framework, then re-sign the app preserving its application-group entitlements. Verify the app with `codesign --verify --deep` before installing it on the owned Simulator. Do not apply this signing step to a physical-device candidate; use the phone lane's packager and matching device slice.
3. Copy `tests/duckdb/{smoke.sh,fixture.csv,fixture.json}` to a dedicated Documents directory. Invoke `sh smoke.sh duckdb` from the app, not through `simctl spawn`. Capture stdout, stderr, status and wall time. The script checks CSV and JSON aggregation, a Parquet write/read round trip, a failing SQL statement and recovery. The expected CSV is:

   ```csv
   category,total
   alpha,42
   beta,5
   ```

Rollback on Simulator removes only the owned candidate or restores the unmodified app. On iPhone, follow the lease holder's signed-candidate and build-585 restore/readback procedure, without uninstalling the app.
