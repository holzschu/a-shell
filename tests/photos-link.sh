#!/bin/sh
# Run against the built iPhone app executable: the picker is a PhotosUI category.
set -eu
if ! xcrun otool -L "${1:?Pass the built app executable}" | grep -q '/PhotosUI.framework/PhotosUI '; then
    printf 'FAIL PhotosUI is absent from runtime dependencies\n'
    exit 1
fi
printf 'PASS PhotosUI is linked for the limited-library picker\n'
