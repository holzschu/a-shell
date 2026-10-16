#!/bin/bash
# Verify fresh guest files produced through the real app terminal.
set -euo pipefail
documents=${1:?Simulator Documents directory required}
compare() {
  printf '%s\n' "$2" | cmp - "$documents/$1"
}
compare sd-version.out 'sd 1.0.0'
compare sd-started.out started
compare sd-version.status 0
[[ ! -s $documents/sd-version.err ]]
compare sd-file.txt 'dog dog'
compare sd-second.txt dogfish
# shellcheck disable=SC2016 # Literal expected output from fixed replacement.
compare sd-fixed.txt '$1 axb $1'
compare sd-captures.txt '42:name 7:name'
compare sd-pipe.out 'blue blue'
for name in files fixed captures pipe unicode preview recovery; do
  compare "sd-$name.status" 0
  [[ ! -s $documents/sd-$name.err ]]
done
for name in files fixed captures invalid option; do
  [[ ! -s $documents/sd-$name.out ]]
done
compare sd-invalid.status 1
grep -Fq 'regex parse error' "$documents/sd-invalid.err"
compare sd-option.status 2
grep -Fq 'unexpected argument' "$documents/sd-option.err"
compare sd-recovery.out 'sd 1.0.0'
compare sd-unicode.txt 'café kitten'
compare sd-preview.txt 'red red'
grep -Fq blue "$documents/sd-preview.out"
compare sd-missing.status 1
[[ ! -s $documents/sd-missing.out ]]
grep -Fq 'sd-does-not-exist.txt' "$documents/sd-missing.err"
compare sd-after.out ordinary-command-returned
compare sd-complete.out SD_PROBE_COMPLETE
echo 'sd files, stdin, Unicode, preview, errors and command re-entry: PASS'
