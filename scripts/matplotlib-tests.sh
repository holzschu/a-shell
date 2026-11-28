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
stdlib=$bundle/Library/lib/python3.13
matplotlib=$stdlib/site-packages/matplotlib
if [ ! -f "$matplotlib/__init__.py" ]; then
    echo "Matplotlib missing from $bundle" >&2
    exit 2
fi
case "$mode" in
    --remove)
        for directory in "$bundle" "$bundle/Library" "$bundle/Library/lib" "$stdlib" \
                         "$stdlib/site-packages" "$matplotlib"; do
            if [ -L "$directory" ]; then
                echo "Refusing to prune through a symlink: $directory" >&2
                exit 2
            fi
        done
        rm -rf -- "$matplotlib/tests"
        ;;
    --check) ;;
    *) echo "Unknown mode: $mode" >&2; exit 2 ;;
esac
if [ -e "$matplotlib/tests" ] || [ -L "$matplotlib/tests" ]; then
    echo "Unexpected Matplotlib test package: matplotlib/tests" >&2
    exit 1
fi
