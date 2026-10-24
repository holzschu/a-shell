#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
build=${1:-"$root/.build/openrsync"}
device=${2:?Pass an owned booted Simulator UUID}
build=$(cd "$build" && pwd)
app="$build/openrsync-runtime.app"
{
mkdir -p "$app/Frameworks"
for name in openrsync openrsyncA; do
  cp -R "$build/dist/$name.xcframework/ios-arm64_x86_64-simulator/$name.framework" "$app/Frameworks/"
done
cp -R "$build/dependencies/ios_system.xcframework/ios-arm64_x86_64-simulator/ios_system.framework" "$app/Frameworks/"
xcrun --sdk iphonesimulator clang -target arm64-apple-ios14.0-simulator -fobjc-arc "$root/tests/openrsync/main.m" \
  -F"$app/Frameworks" -framework ios_system -framework Foundation \
  -Wl,-rpath,@executable_path/Frameworks -o "$app/openrsync-runtime"
mkdir -p "$app/Frameworks/peer.framework"
xcrun --sdk iphonesimulator clang -target arm64-apple-ios14.0-simulator -dynamiclib -I"$build/downloads" "$root/tests/openrsync/peer.m" \
  -F"$app/Frameworks" -framework ios_system -framework Foundation \
  -Wl,-install_name,@rpath/peer.framework/peer -o "$app/Frameworks/peer.framework/peer"
cat > "$app/Frameworks/peer.framework/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>peer</string>
<key>CFBundleIdentifier</key><string>org.openrsync.peer</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleVersion</key><string>1</string>
</dict></plist>
PLIST
cat > "$app/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>openrsync-runtime</string>
<key>CFBundleIdentifier</key><string>org.openrsync.acceptance</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
</dict></plist>
PLIST
cat > "$app/commandDictionary.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>openrsync</key><array><string>openrsync.framework/openrsync</string><string>main</string><string></string><string>file</string></array>
<key>waiting-command</key><array><string>peer.framework/peer</string><string>openrsync_wait_main</string><string></string><string>none</string></array>
<key>local-transport</key><array><string>peer.framework/peer</string><string>openrsync_transport_main</string><string></string><string>none</string></array>
<key>protocol-peer</key><array><string>peer.framework/peer</string><string>openrsync_peer_main</string><string></string><string>file</string></array>
<key>rsync</key><array><string>openrsync.framework/openrsync</string><string>main</string><string></string><string>file</string></array>
</dict></plist>
PLIST
for framework in "$app"/Frameworks/*.framework; do codesign --force --sign - "$framework"; done
codesign --force --sign - "$app"
} > "$build/dist/openrsync-test-build.log" 2>&1
output=$(mktemp -d "$build/runtime-output.XXXXXX")
status=0
xcrun simctl spawn "$device" "$app/openrsync-runtime" "$output" > "$build/dist/openrsync-runtime.log" 2>&1 || status=$?
grep '^OPENRSYNC_' "$build/dist/openrsync-runtime.log" || true
echo "OPENRSYNC_DRIVER_EXIT=$status"
test "$status" = 0
test "$(grep -c '^OPENRSYNC_PASS ' "$build/dist/openrsync-runtime.log")" = 20
grep -q '^OPENRSYNC_ACCEPTANCE_PASSED$' "$build/dist/openrsync-runtime.log"
