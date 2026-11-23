#!/bin/bash
set -euo pipefail
recipe=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
swiftc "$recipe/../../a-Shell/Term.swift" "$recipe/TermHost.swift" -o "$work/term"
"$work/term" --help >"$work/help"
grep -q 'Script and debug programs' "$work/help"
grep -q 'Anything running in a-Shell' "$work/help"
check_error() {
  local expected=$1
  shift
  local code=0
  "$work/term" "$@" >"$work/out" 2>"$work/error" || code=$?
  [[ $code == "$expected" && ! -s "$work/out" && -s "$work/error" ]]
}
check_error 1 screen --json --window missing
jq -e '.error == "no connected terminal"' "$work/error" >/dev/null
check_error 2 resize 0x24
check_error 2 wait --text '['
check_error 2 wait --text x --timeout nan
check_error 2 type --key
check_error 2 screen unexpected
check_error 2 keys '\xZZ'
check_error 2 screen --pane main
check_error 2 panes
echo "PASS: CLI help, stdout/stderr, error statuses and invalid input"
swiftc "$recipe/../../a-Shell/Term.swift" "$recipe/TermContract.swift" -o "$work/contract"
"$work/contract"
