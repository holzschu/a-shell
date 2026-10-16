#!/usr/bin/env bash
# Compare fresh command results independently of app UI automation.
set -euo pipefail
work=${1:?Result directory required}
nonce=${2:?Expected run nonce required}
[[ $(cat "$work/run.nonce") == "$nonce" ]]
check() {
  printf '%s\n' "$2" | LC_ALL=C sort | cmp - <(LC_ALL=C sort "$work/$1.out")
  [[ $(cat "$work/$1.status") == 0 && ! -s $work/$1.err ]]
}
check version 'fd 10.5.0'
check pattern PATTERN.txt
check md $'README.md\ndocs/café.md\ndocs/guide.md\ndocs/space note.md'
check directories 'docs/'
check default $'PATTERN.txt\nREADME.md\ndocs/\ndocs/café.md\ndocs/guide.md\ndocs/space note.md'
check hidden $'.git/\n.gitignore\n.hidden.md\nPATTERN.txt\nREADME.md\ndocs/\ndocs/café.md\ndocs/guide.md\ndocs/space note.md'
check ignore-override ignored.md
check unicode 'docs/café.md'
check base $'café.md\nguide.md\nspace note.md'
check after-version 'fd 10.5.0'
[[ $(cat "$work/after-cwd.out") == */fixture ]]
[[ $(cat "$work/complete.out") == FD_COMPLETE ]]
for label in exec exec-batch list-details; do
  [[ $(cat "$work/$label.status") == 1 && ! -s $work/$label.out ]]
  grep -F 'Command execution (-x/-X/--list-details) is unsupported in embedded iOS fd' "$work/$label.err" >/dev/null
done
[[ $(cat "$work/invalid.status") == 1 && ! -s $work/invalid.out ]]
[[ $(cat "$work/invalid-option.status") == 2 && ! -s $work/invalid-option.out ]]
grep -F 'regex parse error' "$work/invalid.err" >/dev/null
grep -F 'unexpected argument' "$work/invalid-option.err" >/dev/null
echo 'fd full-app acceptance: PASS'
