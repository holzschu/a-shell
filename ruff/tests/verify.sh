#!/bin/bash
# Verify freshly produced consumer-visible results from the owned Simulator.
set -euo pipefail
root=${1:?Usage: verify.sh APP_DATA/Documents/ruff-acceptance}
nonce=${2:?Expected fresh run marker required}
expect() {
  diff -u <(printf '%s\n' "$2") "$root/$1"
}
expect complete.out RUFF_ACCEPTANCE_COMPLETE
expect nonce.out "$nonce"
expect version.out 'ruff 0.17.0'
expect after-version.out 'ruff 0.17.0'
expect ui-after.out 'ruff 0.17.0'
for name in version clean fix format format-second cwd-bad after-version stdin ui-after; do
  expect "$name.rc" 0
done
expect bad.rc 1
expect cwd-clean.rc 1
expect invalid.rc 2
expect clean.out 'All checks passed!'
expect cwd-bad.out 'All checks passed!'
rg -q '^F401' "$root/bad.out"
rg -q '^F821' "$root/cwd-clean.out"
rg -q 'Found 1 error \(1 fixed, 0 remaining\)' "$root/fix.out"
expect fix/main.py 'print("hello")'
expect format/main.py 'x = {"a": 1, "b": 2}'
expect format.out '1 file reformatted'
expect format-second.out '1 file left unchanged'
expect stdin.out 'x = 1'
expect shell-after.out RUFF_SHELL_ALIVE
rg -q 'unexpected argument' "$root/invalid.err"
echo 'PASS: version, lint exit 1/0, real fix/format writes, repeat invocation, cwd/config changes, invalid CLI exit 2 and recovery'
