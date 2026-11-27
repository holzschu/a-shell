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
fetch https://ftp.gnu.org/gnu/ncurses/ncurses-6.6.tar.gz 355b4cbbed880b0381a04c46617b7656e362585d52e9cf84a67e2009b749ff11 "$build/downloads/ncurses-6.6.tar.gz"
unzip -oq "$build/downloads/ios_system.xcframework.zip" -d "$build/dependencies"
tar -xf "$build/downloads/ncurses-6.6.tar.gz" -C "$build/dependencies"
ncurses="$build/dependencies/ncurses-6.6"
build_host=$(sh "$ncurses/config.guess")
build_cc="$(xcrun --sdk macosx -f clang) -isysroot $(xcrun --sdk macosx --show-sdk-path)"
termcap_symbols='tgetent|tgetflag|tgetnum|tgetstr|tgoto|tputs'
namespace='-Dtgetent=pico_tgetent -Dtgetflag=pico_tgetflag -Dtgetnum=pico_tgetnum -Dtgetstr=pico_tgetstr -Dtgoto=pico_tgoto -Dtputs=pico_tputs'
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
  target_flags="-target $triple -isysroot $sdk_path"
  flags="$target_flags -O2 -fPIC -DPICO_IOS -Wno-implicit-function-declaration -Wno-int-conversion $namespace"
  tinfo="$work/tinfo"
  mkdir -p "$tinfo"
  (
    cd "$tinfo"
    # a-Shell sets TERMINFO to its bundled hex-directory database.
    "$ncurses/configure" --build="$build_host" --host="$host_arch-apple-darwin" \
      --with-build-cc="$build_cc" --with-termlib --with-ospeed=speed_t --prefix=/usr \
      --enable-database --disable-mixed-case --disable-widec \
      --without-shared --without-debug --without-ada --without-cxx --without-cxx-binding \
      --without-manpages --without-progs --without-tests --disable-db-install \
      CC="$cc" CFLAGS="$target_flags -O2 -fPIC $namespace" CPPFLAGS="$target_flags" \
      LDFLAGS="$target_flags" LIBS=
    make -j4 -C include
    # Route ncurses' fatal errors out of the command thread, not the app.
    make -j4 -C ncurses "CFLAGS_NORMAL=\$(CCFLAGS) -DNCURSES_STATIC -Dexit=ios_exit" ../lib/libtinfo.a
  ) > "$build/dist/$target-tinfo.log" 2>&1
  (
    cd "$source"
    CC="$cc" CPP="$cc -E $target_flags" CFLAGS="$flags" \
      LDFLAGS="$target_flags -L$tinfo/lib -F$ios_frameworks -framework ios_system" \
      ./configure --host="$host_arch-apple-ios" --without-ssl --without-ldap --without-krb5 \
        --without-smime --without-tcl --disable-nls --disable-rpath --disable-debug
    grep -Fx '#define HAS_TERMINFO 1' include/config.h
    # Only headers and the UTF-8 object are used from the mail toolkit.
    if [[ ! -d imap/c-client ]]; then printf 'y\n' | make -j4 -C imap an SSLTYPE=none; fi
    if [[ ! -f imap/c-client/osdep.h ]]; then make -j4 -C imap/c-client onceenv OS=osx SSLTYPE=none; fi
    make c-client.d
    xcrun --sdk macosx clang pith/help_h_gen.c -o "$work/help_h_gen"
    "$work/help_h_gen" < pith/pine.hlp > pith/helptext.h
    # Older build directories may contain objects compiled without the namespace.
    make -C pico/osdep clean
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
      pith/osdep/libpithosd.a pith/charconv/libpithcc.a \
      -Wl,-dead_strip -Wl,-load_hidden,"$tinfo/lib/libtinfo.a" -liconv \
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
    symbols=$(nm -j "$framework/pico")
    if grep -Ex "_($termcap_symbols)" <<< "$symbols"; then
      echo 'Pico contains an unprefixed termcap symbol' >&2
      exit 1
    fi
    defined=$(nm -j -U "$framework/pico")
    grep -Fx '_pico_tgoto' <<< "$defined"
    grep -Fx '_pico_tputs' <<< "$defined"
    dependencies=$(otool -L "$framework/pico")
    if grep -E '/lib(ncursesw?|curses|tinfow?)\.' <<< "$dependencies"; then
      echo 'Pico links a dynamic terminal library' >&2
      exit 1
    fi
    xcrun vtool -show-build "$framework/pico" > "$build/dist/$target-platform.txt"
    mkdir -p "$framework/Notices"
    cp "$ncurses/COPYING" "$framework/Notices/ncurses-COPYING"
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

Pico uses statically linked ncurses 6.6 tinfo with private, Pico-prefixed termcap names. Set TERMINFO to a-Shell's bundled terminfo database when running outside a-Shell.

The source is Apache-2.0; the ios_system adapter is BSD-3-Clause. The framework includes both licenses, the ncurses license, and the Alpine and IMAP NOTICE files.
NOTES
