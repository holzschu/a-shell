#!/bin/sh
set -eu

library=${1-}
case "$library" in
    /*/Library) ;;
    *) echo "Expected an absolute Python Library path: $library" >&2; exit 2 ;;
esac
if [ ! -d "$library" ] || [ -L "$library" ] || [ -L "$library/bin" ]; then
    echo "Expected a real Python Library directory: $library" >&2
    exit 2
fi

# Keep the manual updater and the CI resource staging on the same cleanup list.
find -P "$library" \( -name '*.a' -o -name '*.dylib' -o -name '*.so' -o \
    -name '*.exe' -o -name '*.dll' -o -name '.*' -o -name cbc \) \
    \( -type f -o -type l \) -delete
find -P "$library" -type d -name '.*' -empty -delete

rm -f -- "$library/bin/maturin"
for binary in "$library/bin/python3" "$library/bin/python3.13"; do
    # Empty placeholders are dispatched by a-Shell, not executed by iOS.
    if [ -L "$binary" ] || [ -s "$binary" ]; then
        rm -f -- "$binary"
        touch "$binary"
    fi
done
