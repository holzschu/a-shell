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
        # Do not follow a resource symlink back out of the built app.
        for directory in "$bundle" "$bundle/Library" "$bundle/Library/lib" "$stdlib" \
                         "$stdlib/idlelib" "$stdlib/tkinter" "$stdlib/lib2to3"; do
            if [ -L "$directory" ]; then
                echo "Refusing to prune through a symlink: $directory" >&2
                exit 2
            fi
        done
        ;;
    --check) ;;
    *) echo "Unknown mode: $mode" >&2; exit 2 ;;
esac

status=0
# The additional paths cover alternate layouts if a packaging input supplies them.
for package in test idlelib/idle_test idlelib/test tkinter/test tkinter/tests lib2to3/tests; do
    path=$stdlib/$package
    if [ "$mode" = --remove ]; then
        rm -rf -- "$path"
    fi
    if [ -e "$path" ] || [ -L "$path" ]; then
        echo "Unexpected CPython test package: $package" >&2
        status=1
    fi
done
exit "$status"
