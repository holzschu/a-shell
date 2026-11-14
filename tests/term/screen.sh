#!/bin/sh
set -eu
work="${TMPDIR:-/tmp}/term-screen-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT
printf 'TERM-COMBINING:é\n'
term wait --text '(?m)^TERM-COMBINING:' --timeout 10 > /dev/null
term screen > "$work/screen.txt"
term screen --json > "$work/screen.json"
term scrollback --lines 100 > "$work/scrollback.txt"
term scrollback --lines 100 --json > "$work/scrollback.json"
for output in screen.txt screen.json scrollback.txt scrollback.json; do
    case "$(cat "$work/$output")" in
        *'TERM-COMBINING:é'*) ;;
        *) printf 'FAIL: %s lost the combining grapheme\n' "$output" >&2; exit 1 ;;
    esac
done
printf 'PASS: screen and scrollback preserve combining graphemes in plain and JSON rows\n'
