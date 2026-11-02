#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
build=${1:-"$root/.build/pico"}
mkdir -p "$build"
build=$(cd "$build" && pwd)
mkdir -p "$build/downloads" "$build/dist"
fetch() {
  local url=$1 checksum=$2 destination=$3
  if [[ ! -f $destination ]]; then curl -fLsS --retry 3 "$url" -o "$destination"; fi
  printf '%s  %s\n' "$checksum" "$destination" | shasum -a 256 -c -
}
fetch https://alpineapp.email/alpine/release/src/alpine-2.26.tar.xz c0779c2be6c47d30554854a3e14ef5e36539502b331068851329275898a9baba "$build/downloads/alpine-2.26.tar.xz"
fetch https://raw.githubusercontent.com/holzschu/ios_system/b51dd90d778499b3592258988423008515282196/ios_error.h 51d46b912eb30399cbb5c36c8c8f15eb1a44adcfc9ee581304ac9d3739a84716 "$build/downloads/ios_error.h"
fetch https://raw.githubusercontent.com/holzschu/ios_system/b51dd90d778499b3592258988423008515282196/LICENSE 62efa5b983ed9d140ce90e39da6d37e2b86ebcdf8530ac78c4705e1fdc19c804 "$build/downloads/ios-system-LICENSE"
fetch https://github.com/holzschu/ios_system/releases/download/v3.0.5/ios_system.xcframework.zip d429e68102926f58bedd8e8b7105dcd169478cd6da1cef494a5f468482d1c8f5 "$build/downloads/ios_system.xcframework.zip"
unzip -oq "$build/downloads/ios_system.xcframework.zip" -d "$build/dependencies"
for target in iphoneos-arm64 iphonesimulator-arm64 iphonesimulator-x86_64; do
  sdk=${target%-*}
  arch=${target##*-}
  host_arch=$arch
  if [[ $arch == arm64 ]]; then host_arch=aarch64; fi
  triple="$arch-apple-ios14.0"
  platform=iPhoneOS
  slice=ios-arm64
  if [[ $sdk == iphonesimulator ]]; then
    triple+=-simulator
    platform=iPhoneSimulator
    slice=ios-arm64_x86_64-simulator
  fi
  work="$build/$target"
  source="$work/source"
  if [[ ! -d $source ]]; then
    mkdir -p "$source"
    tar -xJf "$build/downloads/alpine-2.26.tar.xz" --strip-components 1 -C "$source"
    patch -p1 -d "$source" < "$root/patches/pico-ios.patch"
  else
    patch -R --dry-run -p1 -d "$source" < "$root/patches/pico-ios.patch"
  fi
  cp "$build/downloads/ios_error.h" "$source/include/ios_error.h"
  sdk_path=$(xcrun --sdk "$sdk" --show-sdk-path)
  cc=$(xcrun --sdk "$sdk" -f clang)
  ios_frameworks="$build/dependencies/ios_system.xcframework/$slice"
  flags="-target $triple -isysroot $sdk_path -O2 -fPIC -DPICO_IOS -Wno-implicit-function-declaration -Wno-int-conversion"
  # The SDK ships the versioned stub without the unversioned configure name.
  mkdir -p "$work/sdk-libs"
  ln -sf "$sdk_path/usr/lib/libncurses.5.4.tbd" "$work/sdk-libs/libncurses.tbd"
  (
    cd "$source"
    CC="$cc" CPP="$cc -E -target $triple -isysroot $sdk_path" CFLAGS="$flags" \
      LDFLAGS="-target $triple -isysroot $sdk_path -L$work/sdk-libs" \
      ./configure --host="$host_arch-apple-ios" --without-ssl --without-ldap --without-krb5 \
        --without-smime --without-tcl --disable-nls --disable-rpath --disable-debug
    # Only headers and the UTF-8 object are used from the mail toolkit.
    if [[ ! -d imap/c-client ]]; then printf 'y\n' | make -j4 -C imap an SSLTYPE=none; fi
    if [[ ! -f imap/c-client/osdep.h ]]; then make -j4 -C imap/c-client onceenv OS=osx SSLTYPE=none; fi
    make c-client.d
    xcrun --sdk macosx clang pith/help_h_gen.c -o "$work/help_h_gen"
    "$work/help_h_gen" < pith/pine.hlp > pith/helptext.h
    make -j4 -C pico/osdep
    make -j4 -C pith/osdep
    make -j4 -C pith/charconv
    make -j4 -C pico libpico.a main.o utf8stub.o
    # The mail toolkit reads compiler settings from files, not Make variables.
    printf '%s\n' "$cc" > imap/c-client/CCTYPE
    printf '%s\n' "$flags -DHAVE_CONFIG_H -I$source/include -include $source/include/system.h" > imap/c-client/CFLAGS
    rm -f imap/c-client/utf8.o
    make -j4 -C imap/c-client utf8.o
    framework="$work/pico.framework"
    mkdir -p "$framework/Resources"
    "$cc" -target "$triple" -isysroot "$sdk_path" -dynamiclib -Wl,-undefined,error \
      -Wl,-install_name,@rpath/pico.framework/pico -o "$framework/pico" \
      pico/main.o pico/utf8stub.o c-client/utf8.o pico/libpico.a pico/osdep/libpicoosd.a \
      pith/osdep/libpithosd.a pith/charconv/libpithcc.a -lncurses.5.4 -liconv \
      -F"$ios_frameworks" -framework ios_system
    cat > "$framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>pico</string>
<key>CFBundleIdentifier</key><string>org.alpine.pico</string>
<key>CFBundleName</key><string>pico</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>5.09</string>
<key>MinimumOSVersion</key><string>14.0</string>
<key>CFBundleSupportedPlatforms</key><array><string>$platform</string></array>
</dict></plist>
PLIST
    cp LICENSE "$framework/Resources/Alpine-LICENSE"
    cp NOTICE "$framework/Resources/Alpine-NOTICE"
    cp imap/NOTICE "$framework/Resources/IMAP-NOTICE"
    cp "$build/downloads/ios-system-LICENSE" "$framework/Resources/ios-system-LICENSE"
    lipo "$framework/pico" -verify_arch "$arch"
    nm -gU "$framework/pico" | grep ' _main$' >/dev/null
    if nm -j -u "$framework/pico" | grep -Ex '_(exit|_exit|fork|vfork|system|printf|putchar|puts)' >/dev/null; then
      echo 'Pico imports a process-global entry point' >&2
      exit 1
    fi
    xcrun vtool -show-build "$framework/pico" > "$build/dist/$target-platform.txt"
  ) > "$build/dist/$target-build.log" 2>&1
  echo "Built $target"
done
universal="$build/iphonesimulator-universal/pico.framework"
mkdir -p "$(dirname "$universal")"
if [[ -d $universal ]]; then rm -rf "${universal:?}"; fi
cp -R "$build/iphonesimulator-arm64/pico.framework" "$universal"
lipo -create "$build/iphonesimulator-arm64/pico.framework/pico" "$build/iphonesimulator-x86_64/pico.framework/pico" -output "$universal/pico"
lipo "$universal/pico" -verify_arch arm64
lipo "$universal/pico" -verify_arch x86_64
if [[ -d $build/dist/pico.xcframework ]]; then rm -rf "${build:?}/dist/pico.xcframework"; fi
xcodebuild -create-xcframework -framework "$build/iphoneos-arm64/pico.framework" -framework "$universal" -output "$build/dist/pico.xcframework"
ditto -c -k --norsrc --keepParent "$build/dist/pico.xcframework" "$build/dist/pico.xcframework.zip"
(cd "$build/dist" && shasum -a 256 pico.xcframework.zip > checksums.txt)
checksum=$(awk '{print $1}' "$build/dist/checksums.txt")
test "$(swift package compute-checksum "$build/dist/pico.xcframework.zip")" = "$checksum"
uv run --script "$root/ci/audit-artifact.py" "$build/dist/pico.xcframework.zip" --sha256 "$checksum" --max-minos 14 > "$build/dist/pico-audit.json"
cat > "$build/dist/release.md" <<'NOTES'
Pico 5.09 from Alpine 2.26, built for iOS 14 with an arm64 device slice and a universal arm64/x86_64 Simulator slice. The editor uses ios_system streams, interactive mode and command dispatch. It restores signal handlers when the embedded command exits. POSIX job suspension is unavailable and reports an error.

The source is Apache-2.0; the ios_system adapter is BSD-3-Clause. The framework includes both licenses and the Alpine and IMAP NOTICE files.
NOTES
