#!/bin/sh
# Exercise the production intent entry with failures at its platform boundaries.
# Usage: sh tests/long-commands-errors.sh [ExecuteLongCommandIntent.swift]
set -eu
source=${1:-a-Shell-LongCommands/ExecuteLongCommandIntent.swift}
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
trap 'exit 130' HUP INT TERM
build() { nice -n 15 xcrun swiftc -j 4 -swift-version 5 -module-cache-path "$scratch/modules" "$@"; }
build -emit-library -emit-module -module-name AppIntents tests/long-commands-appintents.swift -o "$scratch/libAppIntents.dylib"
build -emit-library -emit-module -module-name ios_system tests/long-commands-runtime.swift -o "$scratch/libios_system.dylib"
grep -v '^import UIKit$' Util/CommandEnvironment.swift > "$scratch/CommandEnvironment.swift"
build -parse-as-library -I "$scratch" -L "$scratch" -lAppIntents -lios_system -Xlinker -rpath -Xlinker "$scratch" "$source" a-Shell-LongCommands/ProgressCommand.swift "$scratch/CommandEnvironment.swift" tests/long-commands-errors.swift -o "$scratch/intent"
app="$scratch/a-Shell.app"
appex="$app/Extensions/a-Shell-LongCommands.appex"
mkdir -p "$appex" "$scratch/group"
cat > "$app/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.example.host</string>
<key>CFBundleName</key><string>a-Shell-mini</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
cat > "$appex/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.example.host.LongCommands</string>
<key>CFBundleName</key><string>LongCommands</string>
<key>CFBundleExecutable</key><string>LongCommands</string>
<key>CFBundlePackageType</key><string>XPC!</string>
</dict></plist>
PLIST
cp "$scratch/intent" "$appex/LongCommands"
status=0
for failure in host group none; do
    LONG_COMMANDS_FAILURE="$failure" LONG_COMMANDS_GROUP="$scratch/group" LONG_COMMANDS_RESOURCES="$app" "$appex/LongCommands" || status=1
done
exit "$status"
