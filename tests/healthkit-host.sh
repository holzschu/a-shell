#!/bin/sh
# Run from the repository root on macOS.
set -eu
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$scratch/modules" a-Shell/HealthKit.swift tests/healthkit-host.swift -o "$scratch/archive-test"
"$scratch/archive-test" "$scratch/export.zip"
unzip -tq "$scratch/export.zip"
unzip -p "$scratch/export.zip" '*/export.xml' > "$scratch/export.xml"
unzip -p "$scratch/export.zip" '*/workout-routes/*.gpx' > "$scratch/route.gpx"
unzip -p "$scratch/export.zip" '*/deleted.jsonl' > "$scratch/deleted.jsonl"
test "$(xmllint --xpath 'string(/HealthData/Record/@sourceName)' "$scratch/export.xml")" = 'Synthetic & <source> "only"'
test "$(xmllint --xpath 'string(/HealthData/Workout/WorkoutRoute/FileReference/@path)' "$scratch/export.xml")" = 'workout-routes/00000000-0000-0000-0000-000000000002.gpx'
test "$(xmllint --xpath 'local-name(/*/*/*/*)' "$scratch/route.gpx")" = trkpt
jq -es '. == [{uuid:"00000000-0000-0000-0000-000000000003",type:"HKQuantityTypeIdentifierStepCount"}]' "$scratch/deleted.jsonl" >/dev/null
printf 'PASS synthetic ZIP, XML escaping, GPX and deletion sidecar\n'
