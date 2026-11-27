#!/bin/bash
# Check the resources that ios_system and Dash see in a generated worker bundle.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -r "$work"' EXIT
for catalog in Resources_mini Resources; do
    bundle="$work/$catalog.appex"
    SRCROOT="$root" TARGET_BUILD_DIR="$work" UNLOCALIZED_RESOURCES_FOLDER_PATH="$catalog.appex" \
        DERIVED_FILE_DIR="$work/$catalog-derived" ASHELL_WORKER_HOST_IDENTIFIER=test.a-Shell \
        ASHELL_WORKER_COMMAND_CATALOG="$catalog/commandDictionary.plist" \
        bash "$root/ShellWorkers/resources.sh"
    plist="$bundle/commandDictionary.plist"
    plutil -extract wasmkit xml1 -o "$work/wasmkit.plist" "$plist"
    plutil -extract wasm xml1 -o "$work/wasm.plist" "$plist"
    cmp "$work/wasmkit.plist" "$work/wasm.plist"
    test -x "$bundle/bin/wasm"
    printf '%s: wasm resolves to the worker WasmKit registration\n' "$catalog"
done
