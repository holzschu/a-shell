#!/bin/bash
# Match literal Markdown backticks in summary assertions.
# shellcheck disable=SC2016
set -euo pipefail

repo=$(git rev-parse --show-toplevel)
fixture=$(mktemp -d)
trap 'rm -r "$fixture"' EXIT
mkdir "$fixture/a-Shell.xcodeproj"
cat > "$fixture/a-Shell.xcodeproj/project.pbxproj" <<'PROJECT'
{
  objects = {
    ROOT = {isa = PBXGroup; sourceTree = "<group>"; children = (VENDOR);};
    VENDOR = {isa = PBXGroup; sourceTree = "<group>"; path = Vendor; children = (FIRST, SECOND, SDK);};
    FIRST = {isa = PBXFileReference; sourceTree = "<group>"; path = First.xcframework;};
    SECOND = {isa = PBXFileReference; sourceTree = "<group>"; path = Second.xcframework;};
    SDK = {isa = PBXFileReference; sourceTree = SDKROOT; path = System/Library/Frameworks/UIKit.framework;};
    BUILD_FIRST = {isa = PBXBuildFile; fileRef = FIRST;};
    BUILD_SECOND = {isa = PBXBuildFile; fileRef = SECOND;};
    BUILD_SDK = {isa = PBXBuildFile; fileRef = SDK;};
    APP_LINK = {isa = PBXFrameworksBuildPhase; files = (BUILD_FIRST, BUILD_SDK);};
    EXT_LINK = {isa = PBXFrameworksBuildPhase; files = (BUILD_SECOND);};
    EXT_DEP = {isa = PBXTargetDependency; target = EXT;};
    APP = {isa = PBXNativeTarget; name = a-Shell-mini; buildPhases = (APP_LINK); dependencies = (EXT_DEP);};
    EXT = {isa = PBXNativeTarget; name = Extension; buildPhases = (EXT_LINK); dependencies = ();};
  };
}
PROJECT
cat > "$fixture/manifest.json" <<'MANIFEST'
{
  "releases": {},
  "artifacts": {},
  "pending": {"First": "First producer"}
}
MANIFEST

status=0
GITHUB_STEP_SUMMARY="$fixture/summary" uv run "$repo/ci/build-app.py" prepare \
  a-Shell-mini simulator --root "$fixture" --manifest "$fixture/manifest.json" || status=$?
[[ $status == 1 ]]
grep -Fqx -- '- `Vendor/First.xcframework`: no pinned artifact (First producer)' "$fixture/summary"
grep -Fqx -- '- `Vendor/Second.xcframework`: no manifest entry' "$fixture/summary"
if grep -Fq UIKit "$fixture/summary"; then
  exit 1
fi

# The cache is the external download boundary. Its contents must still pass the pin.
mkdir -p "$fixture/.build/app-frameworks/archives"
cache="$fixture/.build/app-frameworks/archives"
printf 'int n;\n' > "$fixture/input.c"
xcrun --sdk iphonesimulator clang -target arm64-apple-ios15.0-simulator -c "$fixture/input.c" -o "$fixture/arm64.o"
xcrun --sdk iphonesimulator clang -target x86_64-apple-ios15.0-simulator -c "$fixture/input.c" -o "$fixture/x86_64.o"

make_framework() {
  local name=$1 arch=$2 binary="$fixture/Staged/$1.xcframework/ios-sim/libFixture.a"
  mkdir -p "$(dirname "$binary")"
  if [[ $arch == universal ]]; then
    xcrun lipo -create "$fixture/arm64.o" "$fixture/x86_64.o" -output "$binary"
    arch='<string>arm64</string><string>x86_64</string>'
  else
    cp "$fixture/arm64.o" "$binary"
    arch='<string>arm64</string>'
  fi
  cat > "$fixture/Staged/$name.xcframework/Info.plist" <<PLIST
<plist version="1.0"><dict><key>AvailableLibraries</key><array><dict>
<key>LibraryIdentifier</key><string>ios-sim</string>
<key>LibraryPath</key><string>libFixture.a</string>
<key>SupportedArchitectures</key><array>$arch</array>
<key>SupportedPlatform</key><string>ios</string>
<key>SupportedPlatformVariant</key><string>simulator</string>
</dict></array></dict></plist>
PLIST
  ditto -c -k --keepParent "$fixture/Staged/$name.xcframework" "$fixture/$name.xcframework.zip"
}

make_framework First thin
first=$(shasum -a 256 "$fixture/First.xcframework.zip" | cut -d ' ' -f 1)
cp "$fixture/First.xcframework.zip" "$cache/$first.zip"
make_framework First universal
make_framework Second universal
mkdir -p "$fixture/data/iphonesimulator/lib" "$fixture/data/iphoneos/lib"
printf 'simulator library\n' > "$fixture/data/iphonesimulator/lib/receipt.txt"
printf 'device library\n' > "$fixture/data/iphoneos/lib/receipt.txt"
tar -czf "$fixture/python.tar.gz" -C "$fixture/data" iphonesimulator iphoneos
(cd "$fixture" && zip -q "$fixture/fork.zip" First.xcframework.zip Second.xcframework.zip python.tar.gz)
fork=$(shasum -a 256 "$fixture/fork.zip" | cut -d ' ' -f 1)
cp "$fixture/fork.zip" "$cache/$fork.zip"
cat > "$fixture/manifest.json" <<MANIFEST
{
  "releases": {"First": {"sha256": "$first", "url": "https://example.invalid/release.zip"}},
  "artifacts": {"fork": {
    "sha256": "$fork", "url": "https://example.invalid/fork.zip",
    "frameworks": {"First": "First.xcframework.zip", "Second": "Second.xcframework.zip"}
  }},
  "pending": {},
  "resources": {"a-Shell-mini": {"Resources/Library/lib": [
    {"artifact": "fork", "member": "python.tar.gz", "source": "{sdk}/lib"}
  ]}}
}
MANIFEST

prepare() {
  GITHUB_STEP_SUMMARY="$fixture/summary" uv run "$repo/ci/build-app.py" prepare \
    a-Shell-mini simulator --root "$fixture" --manifest "$fixture/manifest.json"
}

prepare
file "$fixture/Vendor/First.xcframework/ios-sim/libFixture.a" > "$fixture/file.txt"
grep -Fq '[arm64:' "$fixture/file.txt"
grep -Fq '[x86_64:' "$fixture/file.txt"
grep -Fqx 'simulator library' "$fixture/Resources/Library/lib/receipt.txt"
prepare

test -d "$fixture/Vendor/Second.xcframework"
printf 'corrupted cache\n' > "$cache/$fork.zip"
status=0
prepare || status=$?
[[ $status == 1 ]]
grep -Fq -- '- `Vendor/First.xcframework`: cached SHA-256 mismatch' "$fixture/summary"
grep -Fq -- '- `Vendor/Second.xcframework`: cached SHA-256 mismatch' "$fixture/summary"
