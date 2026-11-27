#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
build=${1:-"$root/.build/multimarkdown"}
mkdir -p "$build"
build=$(cd "$build" && pwd)
mkdir -p "$build/downloads" "$build/dist"
scratch=$(mktemp -d "$build/work.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
fetch() (
  local url=$1 checksum=$2 destination=$3 download
  if [[ -f $destination ]] && printf '%s  %s\n' "$checksum" "$destination" | shasum -a 256 -c -s -; then
    return 0
  fi
  download=$(mktemp "$destination.part.XXXXXX")
  trap 'rm -f "$download"' EXIT
  curl -fLsS --retry 3 "$url" -o "$download"
  printf '%s  %s\n' "$checksum" "$download" | shasum -a 256 -c -
  mv -f "$download" "$destination"
)
revision=6b6155d5041a023d0de44adf182506c52202a03c
fetch "https://codeload.github.com/fletcher/MultiMarkdown-6/tar.gz/$revision" be64aee483ead7c1411a9dc55a98403aee2f998728ba4e08cfade904138a3ba2 "$build/downloads/source.tar.gz"
fetch https://github.com/holzschu/ios_system/releases/download/v3.0.5/ios_system.xcframework.zip d429e68102926f58bedd8e8b7105dcd169478cd6da1cef494a5f468482d1c8f5 "$build/downloads/ios_system.xcframework.zip"
unzip -q "$build/downloads/ios_system.xcframework.zip" -d "$scratch/dependencies"
source=$scratch/source
mkdir "$source"
tar -xzf "$build/downloads/source.tar.gz" --strip-components 1 -C "$source"
patch -f -p1 -d "$source" < "$root/multimarkdown/borrowed-stdin.patch"
host=$scratch/host-contract
stream_flags="-DCMAKE_C_FLAGS=-include \"$root/multimarkdown/ios-streams.h\""
cmake -S "$source" -B "$host" -G Ninja -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_BUILD_TYPE=MinSizeRel "$stream_flags"
cmake --build "$host" --target libMultiMarkdown --parallel 4
for name in main argtable3; do
  flags=(-Oz -DNDEBUG -include "$root/multimarkdown/ios-streams.h" -I"$source/src" -I"$host")
  if [[ $name == main ]]; then flags+=(-Dmain=multimarkdown_main); fi
  xcrun clang "${flags[@]}" -c "$source/src/$name.c" -o "$host/$name.o"
done
xcrun clang -Oz "$root/multimarkdown/verify.c" "$host/main.o" "$host/argtable3.o" \
  "$host/libMultiMarkdown.framework/Versions/A/libMultiMarkdown" -o "$host/verify"
"$host/verify"
for target in iphoneos-arm64 iphonesimulator-arm64 iphonesimulator-x86_64; do
  sdk=${target%-*}
  arch=${target##*-}
  triple=$arch-apple-ios14.0
  slice=ios-arm64
  platform=iPhoneOS
  if [[ $sdk == iphonesimulator ]]; then
    triple+=-simulator
    slice=ios-arm64_x86_64-simulator
    platform=iPhoneSimulator
  fi
  work=$scratch/$target
  sdk_path=$(xcrun --sdk "$sdk" --show-sdk-path)
  cc=$(xcrun --sdk "$sdk" -f clang)
  cmake -S "$source" -B "$work" -G Ninja -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_C_COMPILER="$cc" \
    -DCMAKE_C_COMPILER_TARGET="$triple" -DCMAKE_OSX_SYSROOT="$sdk_path" \
    -DCMAKE_OSX_ARCHITECTURES="$arch" -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY "$stream_flags"
  cmake --build "$work" --target libMultiMarkdown --parallel 4
  flags=(-target "$triple" -isysroot "$sdk_path" -Oz -fPIC -DNDEBUG -include "$root/multimarkdown/ios-streams.h" -I"$source/src" -I"$work")
  for name in main argtable3; do
    "$cc" "${flags[@]}" -c "$source/src/$name.c" -o "$work/$name.o"
  done
  framework=$work/multimarkdown.framework
  mkdir -p "$framework"
  "$cc" -target "$triple" -isysroot "$sdk_path" -dynamiclib -Wl,-undefined,error \
    -Wl,-install_name,@rpath/multimarkdown.framework/multimarkdown \
    "$work/main.o" "$work/argtable3.o" "$work/libMultiMarkdown.framework/libMultiMarkdown" \
    -F"$scratch/dependencies/ios_system.xcframework/$slice" -framework ios_system -lm -o "$framework/multimarkdown"
  xcrun strip -x "$framework/multimarkdown"
  cat > "$framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>multimarkdown</string>
<key>CFBundleIdentifier</key><string>net.fletcherpenney.multimarkdown.command</string>
<key>CFBundleName</key><string>multimarkdown</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>6.7.0</string>
<key>MinimumOSVersion</key><string>14.0</string>
<key>CFBundleSupportedPlatforms</key><array><string>$platform</string></array>
</dict></plist>
PLIST
  cp "$source/LICENSE" "$framework/LICENSE"
  nm -gU "$framework/multimarkdown" | grep ' _main$' > /dev/null
  if nm -u "$framework/multimarkdown" | grep -E '(^|[[:space:]])_(exit|abort|printf|perror|puts|putchar|__stdinp|__stdoutp|__stderrp)$' > /dev/null; then
    echo 'MultiMarkdown imports process-global streams or termination' >&2
    exit 1
  fi
done
universal=$scratch/iphonesimulator-universal/multimarkdown.framework
mkdir -p "$universal"
cp -R "$scratch/iphonesimulator-arm64/multimarkdown.framework/" "$universal/"
lipo -create "$scratch/iphonesimulator-arm64/multimarkdown.framework/multimarkdown" \
  "$scratch/iphonesimulator-x86_64/multimarkdown.framework/multimarkdown" -output "$universal/multimarkdown"
[[ ! -d $build/dist/multimarkdown.xcframework ]] || rm -rf "$build/dist/multimarkdown.xcframework"
xcodebuild -create-xcframework -framework "$scratch/iphoneos-arm64/multimarkdown.framework" \
  -framework "$universal" -output "$build/dist/multimarkdown.xcframework"
rm -f "$build/dist/multimarkdown.xcframework.zip"
ditto -c -k --norsrc --noextattr --noacl --keepParent "$build/dist/multimarkdown.xcframework" "$build/dist/multimarkdown.xcframework.zip"
(cd "$build/dist" && shasum -a 256 multimarkdown.xcframework.zip > checksums.txt)
checksum=$(awk '{print $1}' "$build/dist/checksums.txt")
uv run --script "$root/ci/audit-artifact.py" "$build/dist/multimarkdown.xcframework.zip" --sha256 "$checksum" --max-minos 14 > "$build/dist/multimarkdown-audit.json"
