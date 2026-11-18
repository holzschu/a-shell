#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
out=${1:?Usage: check-install.sh OWNED_OUTPUT MODEL_FILE LICENSE_FILE}
model=${2:?Pass the pinned Apple MNIST source}
license=${3:?Pass the pinned Apple MIT license}
mkdir -p "$out"
out=$(cd "$out" && pwd)
flags=(-fobjc-arc -fblocks -Wall -Wextra -Werror -Wno-deprecated-declarations)
bash "$root/ml/build.sh" --host "$out"
xcrun clang "${flags[@]}" -I"$root/ml" -c "$root/ml/tests/lease.m" -o "$out/objects/lease.o"
xcrun clang "$out/objects/lease.o" "$out/objects/AShellML.o" "$out/objects/AShellMLInstall.o" "$out/objects/AShellMLJob.o" "$out/objects/AShellEmbedding.o" -framework Foundation -framework CoreML -framework CoreVideo -framework Accelerate -o "$out/lease"
xcrun clang -dynamiclib -Wall -Wextra -Werror "$root/ml/tests/install-faults.c" -o "$out/install-faults.dylib"
uv run "$root/ml/tests/install.py" "$out/coreml" "$model" "$license" "$out/receipt.json"
