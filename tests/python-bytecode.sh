#!/bin/sh
set -eu

script=${1:-scripts/python-bytecode.sh}
fixture=$(mktemp -d)
trap 'rm -r "$fixture"' EXIT
bundle=$fixture/a-Shell.app
stdlib=$bundle/Library/lib/python3.13
cache=$stdlib/encodings/__pycache__
mkdir -p "$cache" "$bundle/tests/__pycache__" "$fixture/outside"
touch "$stdlib/encodings/__init__.py" "$cache/__init__.cpython-313.pyc" \
    "$cache/__init__.cpython-313.opt-1.pyc" "$cache/__init__.cpython-313.opt-2.pyc" \
    "$bundle/tests/sample.py" "$bundle/tests/sample.pyc" \
    "$bundle/tests/__pycache__/sample.cpython-313.pyc" "$fixture/outside/keep.pyc"
ln -s "$fixture/outside" "$bundle/linked"

status=0
sh "$script" --check "$bundle" || status=$?
[ "$status" -eq 1 ]
sh "$script" --remove "$bundle"
sh "$script" --check "$bundle"
[ ! -e "$cache" ] && [ ! -e "$bundle/tests/__pycache__" ] && [ ! -e "$bundle/tests/sample.pyc" ] || exit 1
[ -f "$stdlib/encodings/__init__.py" ] && [ -f "$bundle/tests/sample.py" ] && [ -f "$fixture/outside/keep.pyc" ] || exit 1
sh "$script" --remove "$bundle"

# A cache directory should contain only caches. Fail instead of removing other data.
mkdir "$cache"
touch "$cache/keep.txt"
status=0
sh "$script" --remove "$bundle" || status=$?
[ "$status" -eq 1 ] && [ -f "$cache/keep.txt" ]
