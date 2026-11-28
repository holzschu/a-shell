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
if [ ! -f "$stdlib/encodings/__init__.py" ]; then
    echo "Python standard library missing from $bundle" >&2
    exit 2
fi
case "$mode" in
    --remove)
        for directory in "$bundle" "$bundle/Library" "$bundle/Library/lib" "$stdlib"; do
            if [ -L "$directory" ]; then
                echo "Refusing to prune through a symlink: $directory" >&2
                exit 2
            fi
        done
        ;;
    --check) ;;
    *) echo "Unknown mode: $mode" >&2; exit 2 ;;
esac

# Keep default caches, source-less bytecode and separately packaged test trees.
find "$stdlib" \( -type d \( -name test -o -name tests -o -name idle_test \) -prune \) -o \
    -type f -path '*/__pycache__/*.cpython-313.opt-[12].pyc' -exec sh -eu -c '
        mode=$1
        shift
        for path do
            cache=${path%/*}
            filename=${path##*/}
            source=${cache%/*}/${filename%.cpython-313.opt-?.pyc}.py
            [ -f "$source" ] || continue
            if [ "$mode" = --check ]; then
                echo "Unexpected optimized Python cache: $path" >&2
                exit 1
            fi
            rm -f -- "$path"
        done
    ' sh "$mode" {} +
