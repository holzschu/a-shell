#!/bin/bash
# Check the built app's public symbol boundary used by ios_system SELF loading.
set -euo pipefail
app=${1:?Usage: app-link.sh BUILT_APP}
executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Info.plist")
binary="$app/$executable"
if test -f "$binary.debug.dylib"; then binary="$binary.debug.dylib"; fi
if ! nm -gU "$binary" | grep ' _coreml_main$' >/dev/null; then
    echo 'coreml_main is not exported for ios_system SELF loading' >&2
    exit 1
fi
echo COREML_APP_LINK_PASS
