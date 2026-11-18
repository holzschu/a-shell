#!/bin/bash
# Public command/file and shared-process cancellation checks; no phone access.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
output=${1:?Usage: check-jobs.sh FRESH_OWNED_OUTPUT INSTALLED_MODEL_HOME IMAGE}
model_home=${2:?Pass CFFIXED_USER_HOME containing the pinned MNIST install}
image=${3:?Pass the package-side known-answer image}
test -f "$image"
mkdir "$output"
output=$(cd "$output" && pwd)
bash "$root/ml/build.sh" --host "$output/host"
xcrun clang -fobjc-arc -fblocks -O2 -Wall -Wextra -Werror -I"$root/ml" -c "$root/ml/tests/job-session.m" -o "$output/session.o"
objects=()
for name in AShellML AShellMLInstall AShellMLJob AShellEmbedding; do objects+=("$output/host/objects/$name.o"); done
xcrun clang "$output/session.o" "${objects[@]}" -framework Foundation -framework CoreML -framework CoreVideo -framework Accelerate -o "$output/job-session"
export CFFIXED_USER_HOME=$model_home
sh "$root/ml/tests/jobs.sh" "$output/host/coreml" "$output/jobs" "$image" > "$output/cli.stdout" 2> "$output/cli.stderr"
mkdir "$output/session"
"$output/job-session" "$output/session" "$image" > "$output/session.stdout" 2> "$output/session.stderr"
cat "$output/session.stdout"
echo COREML_JOBS_CLI_AND_SESSION_PASS
