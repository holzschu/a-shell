#!/bin/sh
# Exercise the command executable, including repeated calls in one host process.
set -eu
command=${1:?Pass the host coreml executable}
manifest=${2:?Pass the pinned manifest}
digest=${3:?Pass its SHA256}
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
output=${4:?Pass an owned result directory}
mkdir -p "$output"
"$command" install --manifest "$manifest" --sha256 "$digest"
"$command" info mnist
"$command" run mnist "$root/seven.gray" --repeat 2 > "$output/result.json"
jq -e '.runs | length == 2 and all(.[]; .label == "7" and (.scores | length == 10) and ((.scores | add) > 0.9999) and ((.scores | add) < 1.0001))' "$output/result.json"
jq -e '.runs[0].cache_id == .runs[1].cache_id and .runs[1].cache_hit == true' "$output/result.json"
cp "$root/seven.gray" "$output/digit-unicode-é.gray"
"$command" predict mnist "$output/digit-unicode-é.gray" > "$output/unicode.json"
jq -e '.runs[0].label == "7"' "$output/unicode.json"
if "$command" run mnist "$root/missing.gray"; then exit 1; else test "$?" -eq 2; fi
if "$command" run mnist "$manifest"; then exit 1; else test "$?" -eq 2; fi
"$command" unload
printf '%s\n' '{"texts":["hello"]}' > "$output/embedding.json"
if "$command" embed minilm-l6 "$output/embedding.json" --units cpu --units cpu > "$output/duplicate.stdout" 2> "$output/duplicate.stderr"; then exit 1; else test "$?" -eq 2; fi
test ! -s "$output/duplicate.stdout"
grep 'Unknown or duplicate embedding option' "$output/duplicate.stderr"
if "$command" predict qwen3-embedding-0.6b "$root/seven.gray" > "$output/wrong-model.stdout" 2> "$output/wrong-model.stderr"; then exit 1; else test "$?" -eq 2; fi
test ! -s "$output/wrong-model.stdout"
grep 'predict/run accepts only mnist' "$output/wrong-model.stderr"
echo COREML_CLI_PASS
