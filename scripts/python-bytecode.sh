#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "usage: $0 --remove|--check APP_BUNDLE" >&2
    exit 2
fi
mode=$1
bundle=${2%/}
case "$bundle" in
    /*.app) ;;
    *) echo "Expected an absolute app bundle path: $bundle" >&2; exit 2 ;;
esac
if [ -L "$bundle" ] || [ ! -f "$bundle/Library/lib/python3.13/encodings/__init__.py" ]; then
    echo "Expected a Python app bundle: $bundle" >&2
    exit 2
fi
case "$mode" in
    --remove)
        # Do not follow symlinks or delete non-bytecode files in cache directories.
        find -P "$bundle" \( -type f -o -type l \) -iname '*.pyc' -delete
        find -P "$bundle" -type d -name __pycache__ -empty -delete
        ;;
    --check) ;;
    *) echo "Unknown mode: $mode" >&2; exit 2 ;;
esac

remaining=$(find -P "$bundle" \( -iname '*.pyc' -o -name __pycache__ \) -print -quit)
if [ -n "$remaining" ]; then
    printf 'Unexpected Python bytecode or cache directory: %s\n' "$remaining" >&2
    exit 1
fi
