#!/bin/sh
# Check the worker build phase and its compiler input without building the app.
set -eu
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
binding=org.example.fixture.a-Shell-mini

SRCROOT="$PWD" TARGET_BUILD_DIR="$work" UNLOCALIZED_RESOURCES_FOLDER_PATH=resources \
    DERIVED_FILE_DIR="$work/derived" ASHELL_WORKER_HOST_IDENTIFIER="$binding" \
    /bin/bash ShellWorkers/resources.sh
if ! grep -Fq "AppExtensionPoint.Identifier(host: \"$binding\", name: \"ShellWorker\")" "$work/derived/Worker.swift"; then
    echo 'FAIL generated Worker.swift does not bind to the configured host' >&2
    exit 1
fi

plutil -convert json -o "$work/project.json" a-Shell.xcodeproj/project.pbxproj
if ! jq -e '
    .objects as $objects
    | [$objects[] | select(.isa == "PBXNativeTarget" and (.name | test("^ShellWorker[A-Z]$")))]
    | length > 0 and all(.[];
        [.buildPhases[] | $objects[.] | select(.isa == "PBXSourcesBuildPhase")
         | .files[] | $objects[$objects[.].fileRef]
         | select(.path | endswith("/Worker.swift"))]
        | length == 1 and .[0].path == "$(DERIVED_FILE_DIR)/Worker.swift")
' "$work/project.json" >/dev/null; then
    echo 'FAIL worker targets do not compile the generated Worker.swift' >&2
    exit 1
fi
printf 'PASS worker targets use the generated host binding\n'
