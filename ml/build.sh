#!/bin/bash
# Build the same Swift runtime used by the app for macOS CLI qualification.
set -euo pipefail
root=$(cd "$(dirname "$0")" && pwd)
if [ "${1:-}" != --host ] || [ "$#" -ne 2 ]; then
    echo 'Usage: build.sh --host OWNED_OUTPUT' >&2
    exit 2
fi
output=$2
mkdir -p "$output/objects"
output=$(cd "$output" && pwd)
sources=()
for name in AShellML AShellMLInstall AShellMLJob AShellEmbedding host; do
    sources+=("$root/$name.swift")
done
(
    cd "$output/objects"
    xcrun swiftc -swift-version 5 -parse-as-library -O -emit-object "${sources[@]}"
)
xcrun swiftc "$output/objects/AShellML.o" "$output/objects/AShellMLInstall.o" "$output/objects/AShellMLJob.o" "$output/objects/AShellEmbedding.o" "$output/objects/host.o" -o "$output/coreml"
