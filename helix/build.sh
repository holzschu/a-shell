#!/bin/bash
# Build pinned Helix and bundled parsers as an iOS XCFramework.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
cache=${HELIX_BUILD_CACHE:-${TMPDIR:-/tmp}/a-shell-helix}
toolchain=${HELIX_RUSTUP_HOME:-$HOME/.rustup}
source=$cache/upstream
export RUSTUP_HOME=$toolchain
export CARGO_HOME=${HELIX_CARGO_HOME:-$HOME/.cargo}
export CARGO_TARGET_DIR=$cache/target HELIX_DISABLE_AUTO_GRAMMAR_BUILD=1
export IPHONEOS_DEPLOYMENT_TARGET=14.0
cargo=${HELIX_CARGO:-cargo}

apple_target() {
  case ${1:?device or simulator required} in
    device)
      sdk_name=iphoneos
      target=aarch64-apple-ios
      triple=arm64-apple-ios14.0
      mach_platform=IOS
      ;;
    simulator)
      sdk_name=iphonesimulator
      target=aarch64-apple-ios-sim
      triple=arm64-apple-ios14.0-simulator
      mach_platform=IOSSIMULATOR
      ;;
    *)
      echo 'Expected device or simulator' >&2
      return 2
      ;;
  esac
}

preflight() {
  command -v "$cargo" >/dev/null
  "$cargo" +1.96.1 --version
  local free_kb
  free_kb=$(df -k /System/Volumes/Data | awk 'NR==2 {print $4}')
  if ((free_kb < 6 * 1024 * 1024)); then
    echo 'Data volume has less than 6 GiB free; stop and report to the lead' >&2
    return 1
  fi
  mkdir -p "$cache"
}

prepare() {
  preflight
  if [[ ! -f $cache/helix.tar.gz ]]; then
    curl -fLsS --connect-timeout 15 --max-time 180 \
      https://codeload.github.com/helix-editor/helix/tar.gz/a05c151bb6e8e9c65ec390b0ae2afe7a5efd619b -o "$cache/helix.tar.gz.part"
    echo "1f3ae387cd529d63ce7043eec05e3e1c08468a64e6e6164ee9580a6962869ffa  $cache/helix.tar.gz.part" | shasum -a 256 -c -
    mv "$cache/helix.tar.gz.part" "$cache/helix.tar.gz"
  fi
  echo "1f3ae387cd529d63ce7043eec05e3e1c08468a64e6e6164ee9580a6962869ffa  $cache/helix.tar.gz" | shasum -a 256 -c -
  if [[ ! -d $source ]]; then
    mkdir -p "$source"
    tar -xzf "$cache/helix.tar.gz" --strip-components=1 -C "$source"
  fi
  local dependency=$source/ios-crossterm
  if [[ ! -f $cache/crossterm-0.28.1.crate ]]; then
    echo 'Fetch pinned crossterm 0.28.1'
    curl -fLsS --connect-timeout 15 --max-time 180 https://static.crates.io/crates/crossterm/crossterm-0.28.1.crate -o "$cache/crossterm-0.28.1.crate"
  fi
  echo "829d955a0bb380ef178a640b91779e3987da38c9aea133b20614cfed8cdea9c6  $cache/crossterm-0.28.1.crate" | shasum -a 256 -c -
  if [[ ! -d $dependency ]]; then
    mkdir -p "$dependency"
    tar -xzf "$cache/crossterm-0.28.1.crate" --strip-components=1 -C "$dependency"
  fi
  # The released crate uses CRLF; normalize only the six patched files before exact application.
  python3 - "$dependency" <<'PYCODE'
import sys
from pathlib import Path
root = Path(sys.argv[1])
for name in ["src/event.rs", "src/terminal/sys/file_descriptor.rs", "src/terminal/sys/unix.rs", "src/cursor/sys/unix.rs", "src/event/source/unix/mio.rs", "src/tty.rs"]:
    path = root / name
    data = path.read_bytes()
    normalized = data.replace(b"\r\n", b"\n")
    if data != normalized:
        path.write_bytes(normalized)
PYCODE
  # The overlay changes both base patches; recognize its final state before reapplying either.
  if ! patch -s -f -F 0 --dry-run -R -p1 -d "$source" <"$here/ashell-terminal.patch" >/dev/null 2>&1; then
    if ! patch -s -f -F 0 --dry-run -R -p1 -d "$dependency" <"$here/crossterm.patch" >/dev/null 2>&1; then
      echo 'Apply command-owned crossterm terminal boundary'
      patch -s -f -F 0 --dry-run -p1 -d "$dependency" <"$here/crossterm.patch" >/dev/null
      patch -s -f -F 0 -p1 -d "$dependency" <"$here/crossterm.patch"
    fi
    if ! git -C "$source" apply --reverse --check "$here/helix.patch" 2>/dev/null; then
      git -C "$source" apply --check "$here/helix.patch"
      echo 'Apply embedded iOS boundary patch'
      git -C "$source" apply "$here/helix.patch"
    fi
    patch -s -f -F 0 --dry-run -p1 -d "$source" <"$here/ashell-terminal.patch" >/dev/null
    patch -s -f -F 0 -p1 -d "$source" <"$here/ashell-terminal.patch"
  fi
  cmp -s "$here/ios-terminal.rs" "$dependency/src/terminal/sys/ios.rs" || cp "$here/ios-terminal.rs" "$dependency/src/terminal/sys/ios.rs"

}

rust_build() {
  prepare
  rustup target add --toolchain 1.96.1 "$target"
  echo "Build Helix staticlib for $target"
  (cd "$source" && "$cargo" +1.96.1 build --locked --release --target "$target" -p helix-term --lib --no-default-features) >"$cache/embedded-$target.log" 2>&1 || {
    tail -n 30 "$cache/embedded-$target.log" >&2
    return 1
  }
  mkdir -p "$cache/out/$target"
  cp "$CARGO_TARGET_DIR/$target/release/libhelix_term.a" "$cache/out/$target/"
  shasum -a 256 "$cache/out/$target/libhelix_term.a"
}

grammars() {
  preflight
  local sdk name url rev subpath checksum src file object_dir
  sdk=$(xcrun --sdk "$sdk_name" --show-sdk-path)
  object_dir=$cache/objects/$target-ios$IPHONEOS_DEPLOYMENT_TARGET
  mkdir -p "$cache/grammars" "$object_dir" "$cache/out/$target"
  while IFS=$'\t' read -r name url rev subpath checksum; do
    src=$cache/grammars/$name
    if [[ ! -f $cache/grammars/$name.tar.gz ]]; then
      echo "Fetch pinned $name grammar"
      curl -fLsS --connect-timeout 15 --max-time 180 "https://codeload.github.com/${url#https://github.com/}/tar.gz/$rev" -o "$cache/grammars/$name.tar.gz.part"
      echo "$checksum  $cache/grammars/$name.tar.gz.part" | shasum -a 256 -c -
      mv "$cache/grammars/$name.tar.gz.part" "$cache/grammars/$name.tar.gz"
    fi
    echo "$checksum  $cache/grammars/$name.tar.gz" | shasum -a 256 -c -
    if [[ ! -d $src ]]; then
      mkdir -p "$src"
      tar -xzf "$cache/grammars/$name.tar.gz" --strip-components=1 -C "$src"
    fi
    for file in "$src/$subpath/src/parser.c" "$src/$subpath/src/scanner.c" "$src/$subpath/src/scanner.cc"; do
      [[ -f $file ]] || continue
      local object
      object=$object_dir/$name-$(basename "$file").o
      if [[ ! -f $object || $file -nt $object ]]; then
        echo "Compile $name $(basename "$file")"
        xcrun --sdk "$sdk_name" clang -target "$triple" -isysroot "$sdk" -O2 -fPIC -I "$src/$subpath/src" -c "$file" -o "$object"
      fi
    done
  done <"$here/grammars.tsv"
  xcrun ar rcs "$cache/out/$target/libhelix_grammars.a" "$object_dir/"*.o
}

framework() {
  local frameworks=${1:?Matching Frameworks directory required} platform=${2:-device} sdk output name
  apple_target "$platform"
  [[ -f $frameworks/ios_system.framework/ios_system ]]
  xcrun vtool -show-build "$frameworks/ios_system.framework/ios_system" | grep -E "platform +$mach_platform$" >/dev/null
  nm -gU "$frameworks/ios_system.framework/ios_system" | grep ' T _ios_getWindowSize$' >/dev/null
  rust_build
  grammars
  output=$cache/$platform/helix.framework
  mkdir -p "$output"
  sdk=$(xcrun --sdk "$sdk_name" --show-sdk-path)
  xcrun --sdk "$sdk_name" clang -target "$triple" -isysroot "$sdk" -Wall -Wextra -Werror \
    -dynamiclib "$here/command.m" "$cache/out/$target/libhelix_term.a" "$cache/out/$target/libhelix_grammars.a" \
    -F "$frameworks" -framework ios_system -framework Foundation -framework Security -framework SystemConfiguration -lc++ -liconv \
    -Wl,-install_name,@rpath/helix.framework/helix -Wl,-exported_symbol,_hx_ios_main -o "$output/helix"
  rsync -a --checksum --exclude grammars "$source/runtime/" "$output/runtime/"
  cp "$source/LICENSE" "$output/LICENSE"
  mkdir -p "$output/licenses"
  while IFS=$'\t' read -r name _; do
    cp "$cache/grammars/$name/LICENSE" "$output/licenses/$name.txt"
  done <"$here/grammars.tsv"
  cat >"$output/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>helix</string>
<key>CFBundleIdentifier</key><string>com.asheKube.a-Shell.helix</string>
<key>CFBundleName</key><string>helix</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleVersion</key><string>25.7.1</string>
<key>CFBundleShortVersionString</key><string>25.7.1</string>
<key>MinimumOSVersion</key><string>14.0</string>
</dict></plist>
PLIST
  nm -gU "$output/helix" | grep ' T _hx_ios_main$' >/dev/null
  xcrun vtool -show-build "$output/helix"
  shasum -a 256 "$output/helix"
}

case ${1:-} in
  prepare) prepare ;;
  archive)
    apple_target "${2:?}"
    rust_build
    grammars
    ;;
  framework) framework "${2:?}" "${3:-device}" ;;
  xcframework)
    framework "${2:?Device frameworks required}" device
    framework "${3:?Simulator frameworks required}" simulator
    staging=$(mktemp -d "$cache/xcframework.XXXXXX")
    xcodebuild -create-xcframework -framework "$cache/device/helix.framework" -framework "$cache/simulator/helix.framework" -output "$staging/helix.xcframework"
    [[ ! -d $here/helix.xcframework ]] || rm -rf "$here/helix.xcframework"
    mv "$staging/helix.xcframework" "$here/helix.xcframework"
    rmdir "$staging"
    ;;
  *)
    echo 'Usage: build.sh prepare | archive device|simulator | framework MATCHING_FRAMEWORKS [device|simulator] | xcframework DEVICE_FRAMEWORKS SIMULATOR_FRAMEWORKS' >&2
    exit 2
    ;;
esac
