#!/bin/sh
# Exercise the production intent entry with failures at its platform boundaries.
# Usage: sh tests/long-commands-errors.sh [ExecuteLongCommandIntent.swift]
set -eu
source=${1:-a-Shell-LongCommands/ExecuteLongCommandIntent.swift}
scratch=$(mktemp -d)
trap 'chmod -R u+rwx "$scratch"; rm -rf "$scratch"' EXIT
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
for failure in bundle group none; do
    LONG_COMMANDS_FAILURE="$failure" LONG_COMMANDS_GROUP="$scratch/group" LONG_COMMANDS_RESOURCES="$app" "$appex/LongCommands" || status=1
done
# Without Bundle and without Info.plist the app name comes from the directory and no version is known.
mkdir -p "$scratch/NoPlist.app/Extensions"
cp -R "$appex" "$scratch/NoPlist.app/Extensions/"
test ! -e "$scratch/NoPlist.app/Info.plist"
LONG_COMMANDS_FAILURE=host LONG_COMMANDS_GROUP="$scratch/group" LONG_COMMANDS_RESOURCES="$scratch/NoPlist.app" "$scratch/NoPlist.app/Extensions/a-Shell-LongCommands.appex/LongCommands" || status=1
run_layout() {
    printf '%s\n' "$1"
    LONG_COMMANDS_FAILURE=none LONG_COMMANDS_GROUP="$scratch/group" LONG_COMMANDS_RESOURCES="$app" "$2" || status=1
}
mv "$app/Extensions" "$app/PlugIns"
run_layout 'Flat PlugIns' "$app/PlugIns/a-Shell-LongCommands.appex/LongCommands"
mkdir -p "$scratch/Wrapper.app/Wrapper"
mv "$app" "$scratch/Wrapper.app/Wrapper/"
app="$scratch/Wrapper.app/Wrapper/a-Shell.app"
run_layout 'Wrapped iOS app' "$app/PlugIns/a-Shell-LongCommands.appex/LongCommands"
# Handle an app as the main bundle, too.
cp "$scratch/intent" "$app/LongCommands"
/usr/libexec/PlistBuddy -c 'Add :CFBundleExecutable string LongCommands' "$app/Info.plist"
run_layout 'App as main bundle' "$app/LongCommands"
# A Contents layout is a portability fixture, not the current iOS build product.
mkdir -p "$app/Contents/Resources"
mv "$app/Info.plist" "$app/Contents/"
mv "$app/PlugIns" "$app/Contents/Extensions"
run_layout 'Contents/Extensions' "$app/Contents/Extensions/a-Shell-LongCommands.appex/LongCommands"
mv "$app/Contents/Extensions" "$app/Contents/PlugIns"
run_layout 'Contents/PlugIns' "$app/Contents/PlugIns/a-Shell-LongCommands.appex/LongCommands"
cp -R "$app/Contents/PlugIns/a-Shell-LongCommands.appex" "$scratch/Detached.appex"
LONG_COMMANDS_FAILURE=detached LONG_COMMANDS_GROUP="$scratch/group" "$scratch/Detached.appex/LongCommands" || status=1
# An app directory that can be traversed but not listed: Foundation's Bundle(url:) fails, Info.plist stays readable.
mkdir -p "$scratch/Unlistable/a-Shell.app/Extensions"
cp "$scratch/Wrapper.app/Wrapper/a-Shell.app/Contents/Info.plist" "$scratch/Unlistable/a-Shell.app/Info.plist"
cp -R "$scratch/Wrapper.app/Wrapper/a-Shell.app/Contents/PlugIns/a-Shell-LongCommands.appex" "$scratch/Unlistable/a-Shell.app/Extensions/"
chmod 311 "$scratch/Unlistable/a-Shell.app"
LONG_COMMANDS_FAILURE=unlistable LONG_COMMANDS_GROUP="$scratch/group" LONG_COMMANDS_RESOURCES="$scratch/Unlistable/a-Shell.app" "$scratch/Unlistable/a-Shell.app/Extensions/a-Shell-LongCommands.appex/LongCommands" || status=1
exit "$status"
