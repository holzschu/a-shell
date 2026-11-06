#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
build=${1:-"$root/.build/openrsync"}
command -v bmake >/dev/null
mkdir -p "$build"
build=$(cd "$build" && pwd)
mkdir -p "$build/downloads" "$build/dist" "$build/dependencies"
fetch() {
  local url=$1 checksum=$2 destination=$3
  if [[ ! -f $destination ]]; then
    curl -fLsS --retry 3 "$url" -o "$destination.part"
    mv "$destination.part" "$destination"
  fi
  printf '%s  %s\n' "$checksum" "$destination" | shasum -a 256 -c -
}
fetch https://codeload.github.com/kristapsdz/openrsync/tar.gz/8235c68f11b4fad5e24849a01d04ea153c29ee28 256dad12f25aceb4adb712b52e5f69db66fa7d4d1450d802ab23d066f4d1c27d "$build/downloads/openrsync.tar.gz"
fetch https://raw.githubusercontent.com/holzschu/ios_system/7658fcf551935b42d6bb5bedc9315d8f53f760c4/ios_error.h 51d46b912eb30399cbb5c36c8c8f15eb1a44adcfc9ee581304ac9d3739a84716 "$build/downloads/ios_error.h"
fetch https://raw.githubusercontent.com/holzschu/ios_system/7658fcf551935b42d6bb5bedc9315d8f53f760c4/LICENSE 62efa5b983ed9d140ce90e39da6d37e2b86ebcdf8530ac78c4705e1fdc19c804 "$build/downloads/ios-system-LICENSE"
fetch https://github.com/holzschu/ios_system/releases/download/v3.0.5/ios_system.xcframework.zip d429e68102926f58bedd8e8b7105dcd169478cd6da1cef494a5f468482d1c8f5 "$build/downloads/ios_system.xcframework.zip"
unzip -oq "$build/downloads/ios_system.xcframework.zip" -d "$build/dependencies"
for target in iphoneos-arm64 iphonesimulator-arm64 iphonesimulator-x86_64; do
  sdk=${target%-*}
  arch=${target##*-}
  triple="$arch-apple-ios14.0"
  platform=iPhoneOS
  slice=ios-arm64
  if [[ $sdk == iphonesimulator ]]; then triple+=-simulator; platform=iPhoneSimulator; slice=ios-arm64_x86_64-simulator; fi
  work="$build/$target"
  source="$work/source"
  if [[ ! -d $source ]]; then
    mkdir -p "$source"
    tar -xzf "$build/downloads/openrsync.tar.gz" --strip-components 1 -C "$source"
    for patch in openrsync-source-fixes openrsync-ios; do patch -f -p1 -d "$source" < "$root/patches/$patch.patch"; done
  else
    for patch in openrsync-source-fixes openrsync-ios; do patch -f -R --dry-run -p1 -d "$source" < "$root/patches/$patch.patch"; done
  fi
  cp "$build/downloads/ios_error.h" "$source/ios_error.h"
  sdk_path=$(xcrun --sdk "$sdk" --show-sdk-path)
  cc=$(xcrun --sdk "$sdk" -f clang)
  flags="-target $triple -isysroot $sdk_path -Oz -fPIC"
  frameworks="$build/dependencies/ios_system.xcframework/$slice"
  (
    cd "$source"
    ./configure -j4 CC="$cc" CFLAGS="$flags"
    bmake -j4 CC="$cc" CFLAGS="$flags -DOPENRSYNC_IOS" LDADD_Z=-lz CFLAGS_Z= LDADD_FTS= CFLAGS_FTS= LDFLAGS="$flags -F$frameworks -framework ios_system"
    for name in openrsync openrsyncA; do
      framework="$work/$name.framework"
      mkdir -p "$framework"
      "$cc" -target "$triple" -isysroot "$sdk_path" -dynamiclib -Wl,-undefined,error -Wl,-install_name,@rpath/$name.framework/$name \
        ./*.o -lz -F"$frameworks" -framework ios_system -o "$framework/$name"
      xcrun strip -x "$framework/$name"
      cat > "$framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$name</string>
<key>CFBundleIdentifier</key><string>org.openrsync.$name</string>
<key>CFBundleName</key><string>$name</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>MinimumOSVersion</key><string>14.0</string>
<key>CFBundleSupportedPlatforms</key><array><string>$platform</string></array>
</dict></plist>
PLIST
      cp LICENSE.md "$framework/LICENSE.md"
      cp "$build/downloads/ios-system-LICENSE" "$framework/ios-system-LICENSE"
      for file in ./*.c ./*.h; do
        awk 'NR==1 && /^\/\*/ {copy=1} copy {print} copy && /\*\// {exit}' "$file"
      done > "$framework/SourceNotices.txt"
      lipo "$framework/$name" -verify_arch "$arch"
      nm -gU "$framework/$name" | grep ' _main$' >/dev/null
      if nm -u "$framework/$name" | grep -E '^_(exit|_exit|fork|vfork|execv|execvp|waitpid|system|printf|putchar|puts|abort|kill|signal|__assert_rtn|__stdinp|__stdoutp|__stderrp)$' >/dev/null; then
        echo 'openrsync imports a process-global entry point' >&2; exit 1
      fi
      if nm -m -u "$framework/$name" | grep -E ' _(err|errx|verr|verrx) .*\(from libSystem\)' >/dev/null; then
        echo 'openrsync error handling binds to libSystem' >&2; exit 1
      fi
    done
  ) > "$build/dist/$target-build.log" 2>&1
  echo "Built $target"
done
: > "$build/dist/checksums.txt"
for name in openrsync openrsyncA; do
  universal="$build/iphonesimulator-universal/$name.framework"
  mkdir -p "$(dirname "$universal")"
  if [[ -d $universal ]]; then rm -rf "${universal:?}"; fi
  cp -R "$build/iphonesimulator-arm64/$name.framework" "$universal"
  lipo -create "$build/iphonesimulator-arm64/$name.framework/$name" "$build/iphonesimulator-x86_64/$name.framework/$name" -output "$universal/$name"
  lipo "$universal/$name" -verify_arch arm64
  lipo "$universal/$name" -verify_arch x86_64
  if [[ -d $build/dist/$name.xcframework ]]; then rm -rf "${build:?}/dist/$name.xcframework"; fi
  xcodebuild -create-xcframework -framework "$build/iphoneos-arm64/$name.framework" -framework "$universal" -output "$build/dist/$name.xcframework"
  ditto -c -k --keepParent "$build/dist/$name.xcframework" "$build/dist/$name.xcframework.zip"
  checksum=$(shasum -a 256 "$build/dist/$name.xcframework.zip" | awk '{print $1}')
  printf '%s  %s\n' "$checksum" "$name.xcframework.zip" >> "$build/dist/checksums.txt"
  test "$(swift package compute-checksum "$build/dist/$name.xcframework.zip")" = "$checksum"
  uv run --script "$root/ci/audit-artifact.py" "$build/dist/$name.xcframework.zip" --sha256 "$checksum" --max-minos 14 > "$build/dist/$name-audit.json"
done
cat > "$build/dist/release.md" <<'NOTES'
openrsync at 8235c68f11b4fad5e24849a01d04ea153c29ee28 for iOS14: openrsync and openrsyncA, each with arm64 device and universal arm64/x86_64 Simulator slices. Uses ios_system streams, nested command dispatch and wait. Local transfers retain the two framework slots. Ctrl-C shuts down the transport so protocol cleanup can finish. Separate source corrections fix checksum success handling, a traversal root-reference leak and tagged acknowledgements on unframed receiver streams. Per-command options and borrowed logging state are reset for re-entry.

Source ISC licenses/notices and the BSD-3-Clause ios_system license are included.
NOTES
