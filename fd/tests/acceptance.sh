#!/bin/sh
# Invoke from the app terminal, with an empty disposable work directory.
set -u
work=${1:?Absolute work directory required}
nonce=${2:?Fresh run nonce required}
mkdir -p "$work/fixture/.git" "$work/fixture/docs"
printf '%s\n' ignored.md >"$work/fixture/.gitignore"
for name in PATTERN.txt README.md ignored.md .hidden.md 'docs/guide.md' 'docs/space note.md' 'docs/café.md'; do
  printf 'demo\n' >"$work/fixture/$name"
done
cd "$work/fixture" || return 1
printf '%s\n' "$nonce" >"$work/run.nonce"
run() {
  label=$1
  shift
  "$@" >"$work/$label.out" 2>"$work/$label.err"
  printf '%s\n' "$?" >"$work/$label.status"
}
run version fd --version
run pattern fd PATTERN
run md fd -e md
run directories fd -t d
run hidden fd -H
run default fd
run ignore-override fd -I ignored
run unicode fd café
run exec fd -x echo '{}'
run exec-batch fd -X echo '{}'
run list-details fd --list-details
run invalid fd '['
run invalid-option fd --definitely-invalid
run base fd --base-directory docs -e md
pwd >"$work/after-cwd.out"
run after-version fd --version
printf '%s\n' FD_COMPLETE >"$work/complete.out"
