#!/bin/sh
# Run through a-Shell's Dash, in a disposable working directory.
set -eu
out=./codex-acceptance-$$
mkdir "$out"
trap 'rm -rf "$out"' EXIT HUP INT TERM
for _run in 1 2 3; do
  codex --version >"$out/version" 2>"$out/error"
  grep -qx 'codex-cli 0.160.0' "$out/version"
  codex --help >"$out/help" 2>"$out/error"
  grep -q 'Usage: codex' "$out/help"
  codex exec --help >"$out/help" 2>"$out/error"
  grep -q 'Usage: codex exec' "$out/help"
  status=0
  codex --this-option-does-not-exist >"$out/invalid" 2>"$out/error" || status=$?
  test "$status" -eq 2
  grep -q 'unexpected argument' "$out/error"
  printf 'HOST_RESTORED\n' >"$out/host"
  grep -qx HOST_RESTORED "$out/host"
done
printf 'CODEX_CLI_PASS\n'
