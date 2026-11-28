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
mkdir -p "$fixture/data/iphonesimulator/lib/bin" "$fixture/data/iphonesimulator/bin" "$fixture/data/iphoneos/lib"
printf 'simulator library\n' > "$fixture/data/iphonesimulator/lib/receipt.txt"
for file in lib/.lock lib/sample.a lib/sample.dylib lib/sample.so lib/sample.exe lib/sample.dll lib/cbc bin/maturin bin/python3.13; do
  printf 'packaged file\n' > "$fixture/data/iphonesimulator/$file"
done
touch "$fixture/data/iphonesimulator/bin/python3" \
  "$fixture/data/iphonesimulator/lib/keep.pyc" "$fixture/data/iphonesimulator/lib/bin/python3.13"
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
  "resources": {"a-Shell-mini": {
    "Resources/Library": [{"artifact": "fork", "member": "python.tar.gz", "source": "{sdk}"}],
    "Resources_mini/Library/lib/python3.13": [{"artifact": "fork", "member": "python.tar.gz", "source": "{sdk}/lib"}],
    "Resources/node-fetch": [{"artifact": "fork", "member": "python.tar.gz", "source": "{sdk}/lib"}]
  }}
}
MANIFEST

prepare() {
  GITHUB_STEP_SUMMARY="$fixture/summary" uv run "$repo/ci/build-app.py" prepare \
    a-Shell-mini simulator --root "$fixture" --manifest "$fixture/manifest.json"
}

# The first install must be recoverable even if a later input aborts prepare.
mkdir -p "$fixture/Malformed/Second.xcframework"
printf '<plist version="1.0"><integer>not-an-integer</integer></plist>\n' > "$fixture/Malformed/Second.xcframework/Info.plist"
ditto -c -k --keepParent "$fixture/Malformed/Second.xcframework" "$fixture/malformed.zip"
malformed=$(shasum -a 256 "$fixture/malformed.zip" | cut -d ' ' -f 1)
cp "$fixture/malformed.zip" "$cache/$malformed.zip"
cp "$fixture/manifest.json" "$fixture/good-manifest.json"
jq --arg sha "$malformed" '.releases.Second = {sha256: $sha, url: "https://example.invalid/malformed.zip"}' \
  "$fixture/good-manifest.json" > "$fixture/manifest.json"
status=0
prepare > "$fixture/interrupted.log" 2>&1 || status=$?
[[ $status == 1 ]]
grep -Fq 'not-an-integer' "$fixture/interrupted.log"
cmp "$fixture/Staged/First.xcframework/ios-sim/libFixture.a" "$fixture/Vendor/First.xcframework/ios-sim/libFixture.a"
test ! -e "$fixture/Vendor/Second.xcframework"
mv "$fixture/good-manifest.json" "$fixture/manifest.json"

# Retry may replace the first input, but must leave an unmanaged path alone.
unmanaged="$fixture/Vendor/Second.xcframework"
mkdir "$unmanaged"
printf 'unmanaged\n' > "$unmanaged/receipt.txt"
status=0
prepare > "$fixture/unmanaged.log" 2>&1 || status=$?
[[ $status == 1 ]]
grep -Fq 'Vendor/Second.xcframework; use a clean worktree' "$fixture/unmanaged.log"
grep -Fxq 'unmanaged' "$unmanaged/receipt.txt"
rm "$unmanaged/receipt.txt"
rmdir "$unmanaged"

prepare
file "$fixture/Vendor/First.xcframework/ios-sim/libFixture.a" > "$fixture/file.txt"
grep -Fq '[arm64:' "$fixture/file.txt"
grep -Fq '[x86_64:' "$fixture/file.txt"
grep -Fqx 'simulator library' "$fixture/Resources/Library/lib/receipt.txt"
for file in lib/.lock lib/sample.a lib/sample.dylib lib/sample.so lib/sample.exe lib/sample.dll lib/cbc bin/maturin; do
  test ! -e "$fixture/Resources/Library/$file"
done
for file in python3 python3.13; do
  test -f "$fixture/Resources/Library/bin/$file"
  test ! -s "$fixture/Resources/Library/bin/$file"
done
test -f "$fixture/Resources/Library/lib/keep.pyc"
test -f "$fixture/Resources/Library/lib/bin/python3.13"
test ! -e "$fixture/Resources_mini/Library/lib/python3.13/.lock"
test -f "$fixture/Resources_mini/Library/lib/python3.13/keep.pyc"
test -f "$fixture/Resources/node-fetch/.lock"
prepare

test -d "$fixture/Vendor/Second.xcframework"
printf 'corrupted cache\n' > "$cache/$fork.zip"
status=0
prepare || status=$?
[[ $status == 1 ]]
grep -Fq -- '- `Vendor/First.xcframework`: cached SHA-256 mismatch' "$fixture/summary"
grep -Fq -- '- `Vendor/Second.xcframework`: cached SHA-256 mismatch' "$fixture/summary"

# Package the same interpreter and extension under two load identities.
cat > "$fixture/a-Shell.xcodeproj/project.pbxproj" <<'PROJECT'
{
  objects = {
    CORE = {isa = PBXFileReference; sourceTree = SOURCE_ROOT; path = Frameworks/Python.framework;};
    EXT = {isa = PBXFileReference; sourceTree = SOURCE_ROOT; path = Frameworks/Python-fixture.framework;};
    CORE_A = {isa = PBXFileReference; sourceTree = SOURCE_ROOT; path = Frameworks/pythonA.framework;};
    EXT_A = {isa = PBXFileReference; sourceTree = SOURCE_ROOT; path = Frameworks/PythonAfixture.framework;};
    BUILD_CORE = {isa = PBXBuildFile; fileRef = CORE;};
    BUILD_EXT = {isa = PBXBuildFile; fileRef = EXT;};
    BUILD_CORE_A = {isa = PBXBuildFile; fileRef = CORE_A;};
    BUILD_EXT_A = {isa = PBXBuildFile; fileRef = EXT_A;};
    EMBED = {isa = PBXCopyFilesBuildPhase; files = (BUILD_CORE, BUILD_EXT, BUILD_CORE_A, BUILD_EXT_A);};
    APP = {isa = PBXNativeTarget; name = a-Shell-mini; buildPhases = (EMBED); dependencies = ();};
  };
}
PROJECT

printf 'int fixture_core(void) { return 42; }\n' > "$fixture/core.c"
printf 'extern int fixture_core(void); int fixture_extension(void) { return fixture_core(); }\n' > "$fixture/extension.c"
for spec in iphoneos:arm64-apple-ios15.0:ios-arm64 iphonesimulator:arm64-apple-ios15.0-simulator:ios-arm64_x86_64-simulator iphonesimulator:x86_64-apple-ios15.0-simulator:ios-arm64_x86_64-simulator; do
  IFS=: read -r sdk target slice <<< "$spec"
  arch=${target%%-*}
  for name in Python Python-fixture; do
    bundle="$fixture/Staged/$name.xcframework/$slice/$name.framework"
    mkdir -p "$bundle"
    cat > "$bundle/Info.plist" <<PLIST
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$name</string>
<key>CFBundleIdentifier</key><string>org.example.$name</string>
<key>CFBundleName</key><string>$name</string>
<key>CFBundlePackageType</key><string>FMWK</string>
</dict></plist>
PLIST
    common=(-target "$target" -dynamiclib -Xlinker -headerpad_max_install_names -install_name "@rpath/$name.framework/$name")
    if [[ $name == Python ]]; then
      xcrun --sdk "$sdk" clang "${common[@]}" "$fixture/core.c" -o "$bundle/$name.$arch"
    else
      core="$fixture/Staged/Python.xcframework/$slice/Python.framework/Python.$arch"
      xcrun --sdk "$sdk" clang "${common[@]}" "$fixture/extension.c" "$core" -o "$bundle/$name.$arch"
      printf 'lib/python3.13/fixture.fwork\n' > "$bundle/$name.origin"
    fi
  done
done

for name in Python Python-fixture; do
  xcframework="$fixture/Staged/$name.xcframework"
  device="$xcframework/ios-arm64/$name.framework/$name"
  sim="$xcframework/ios-arm64_x86_64-simulator/$name.framework/$name"
  mv "$device.arm64" "$device"
  xcrun lipo -create "$sim.arm64" "$sim.x86_64" -output "$sim"
  rm "$sim.arm64" "$sim.x86_64"
  cat > "$xcframework/Info.plist" <<PLIST
<plist version="1.0"><dict><key>AvailableLibraries</key><array><dict>
<key>LibraryIdentifier</key><string>ios-arm64</string>
<key>LibraryPath</key><string>$name.framework</string>
<key>SupportedArchitectures</key><array><string>arm64</string></array>
<key>SupportedPlatform</key><string>ios</string>
</dict><dict>
<key>LibraryIdentifier</key><string>ios-arm64_x86_64-simulator</string>
<key>LibraryPath</key><string>$name.framework</string>
<key>SupportedArchitectures</key><array><string>arm64</string><string>x86_64</string></array>
<key>SupportedPlatform</key><string>ios</string>
<key>SupportedPlatformVariant</key><string>simulator</string>
</dict></array></dict></plist>
PLIST
  ditto -c -k --keepParent "$xcframework" "$fixture/$name.xcframework.zip"
  sha=$(shasum -a 256 "$fixture/$name.xcframework.zip" | cut -d ' ' -f 1)
  cp "$fixture/$name.xcframework.zip" "$cache/$sha.zip"
  if [[ $name == Python ]]; then core_sha=$sha; else extension_sha=$sha; fi
done
cat > "$fixture/manifest.json" <<MANIFEST
{
  "releases": {
    "Python": {"sha256": "$core_sha", "url": "https://example.invalid/Python.xcframework.zip"},
    "Python-fixture": {"sha256": "$extension_sha", "url": "https://example.invalid/Python-fixture.xcframework.zip"}
  },
  "artifacts": {}, "pending": {}
}
MANIFEST

for platform in simulator device; do
  uv run "$repo/ci/build-app.py" prepare a-Shell-mini "$platform" --root "$fixture" --manifest "$fixture/manifest.json"
  for name in pythonA PythonAfixture; do
    bundle="$fixture/Frameworks/$name.framework"
    [[ $(plutil -extract CFBundleExecutable raw -o - "$bundle/Info.plist") == "$name" ]]
    [[ $(plutil -extract CFBundleIdentifier raw -o - "$bundle/Info.plist") == "Nicolas-Holzschuch.$name" ]]
    codesign --verify --strict "$bundle"
    archs=(arm64)
    if [[ $platform == simulator ]]; then archs+=(x86_64); fi
    for arch in "${archs[@]}"; do
      xcrun otool -arch "$arch" -D "$bundle/$name" | grep -Fx "@rpath/$name.framework/$name"
      if [[ $name == PythonAfixture ]]; then
        xcrun otool -arch "$arch" -L "$bundle/$name" | grep -F '@rpath/pythonA.framework/pythonA ('
        if xcrun otool -arch "$arch" -L "$bundle/$name" | grep -Fq '@rpath/Python.framework/Python ('; then exit 1; fi
      fi
    done
  done
  cmp "$fixture/Frameworks/Python-fixture.framework/Python-fixture.origin" "$fixture/Frameworks/PythonAfixture.framework/PythonAfixture.origin"
  xcrun otool -arch arm64 -L "$fixture/Frameworks/Python-fixture.framework/Python-fixture" | grep -F '@rpath/Python.framework/Python ('
done
