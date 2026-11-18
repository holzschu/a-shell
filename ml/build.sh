#!/bin/bash
# Build the same Objective-C runtime used by the app for macOS CLI qualification.
set -euo pipefail
root=$(cd "$(dirname "$0")" && pwd)
if [ "${1:-}" != --host ] || [ "$#" -ne 2 ]; then
    echo 'Usage: build.sh --host OWNED_OUTPUT' >&2
    exit 2
fi
output=$2
mkdir -p "$output/objects"
output=$(cd "$output" && pwd)
flags=(-fobjc-arc -fblocks -O2 -Wall -Wextra -Werror -Wno-deprecated-declarations)
for name in AShellML AShellMLInstall AShellMLJob AShellEmbedding host; do
    xcrun clang "${flags[@]}" -c "$root/$name.m" -o "$output/objects/$name.o"
done
xcrun clang "$output/objects/AShellML.o" "$output/objects/AShellMLInstall.o" "$output/objects/AShellMLJob.o" "$output/objects/AShellEmbedding.o" "$output/objects/host.o" -framework Foundation -framework CoreML -framework CoreVideo -framework Accelerate -o "$output/coreml"
