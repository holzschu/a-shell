#!/bin/bash
# Build Ruff as a framework with private command-stream bindings.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
cache=${RUFF_BUILD_CACHE:-${TMPDIR:-/tmp}/a-shell-ruff}
source=$cache/source
# Ruff 0.17.0, revision 5b27c1ccfaa230fb195855f5cf3404a21e3379cd.
sha=2df40dc573eb751154b49055d0949668ec4f72f928d9c7fe5d86f451bfb3d7d5
export CARGO_TARGET_DIR=$cache/target
export IPHONEOS_DEPLOYMENT_TARGET=14.0

prepare() {
  [[ $(rustc --version) == 'rustc 1.99.0 (b940084d7 2026-09-28)' ]] || {
    echo 'Rust 1.99.0 is required' >&2
    return 1
  }
  mkdir -p "$cache"
  if [[ ! -f $cache/source.tar.gz ]]; then
    curl -fLsS --connect-timeout 15 --max-time 600 \
      'https://codeload.github.com/astral-sh/ruff/tar.gz/refs/tags/0.17.0' -o "$cache/source.tar.gz.part"
    echo "$sha  $cache/source.tar.gz.part" | shasum -a 256 -c -
    mv "$cache/source.tar.gz.part" "$cache/source.tar.gz"
  fi
  echo "$sha  $cache/source.tar.gz" | shasum -a 256 -c -
  if [[ ! -d $source ]]; then
    mkdir -p "$source"
    tar -xzf "$cache/source.tar.gz" --strip-components=1 -C "$source"
  fi
  if ! patch -s -f -F 0 --dry-run -R -p1 -d "$source" <"$here/native.patch" >/dev/null 2>&1; then
    patch -s -f -F 0 --dry-run -p1 -d "$source" <"$here/native.patch" >/dev/null
    patch -s -f -F 0 -p1 -d "$source" <"$here/native.patch"
  fi
  cmp -s "$here/ios.rs" "$source/crates/ruff/src/ios.rs" || cp "$here/ios.rs" "$source/crates/ruff/src/ios.rs"
}

framework() {
  local frameworks=${1:?Matching frameworks directory required} platform=${2:?device or simulator required}
  local target sdk_name triple mach_platform sdk output archive
  case $platform in
    device)
      target=aarch64-apple-ios
      sdk_name=iphoneos
      triple=arm64-apple-ios14.0
      mach_platform=IOS
      ;;
    simulator)
      target=aarch64-apple-ios-sim
      sdk_name=iphonesimulator
      triple=arm64-apple-ios14.0-simulator
      mach_platform=IOSSIMULATOR
      ;;
    simulator-x86_64)
      target=x86_64-apple-ios
      sdk_name=iphonesimulator
      triple=x86_64-apple-ios14.0-simulator
      mach_platform=IOSSIMULATOR
      ;;
    *)
      echo 'Expected device, simulator or simulator-x86_64' >&2
      return 2
      ;;
  esac
  [[ -f $frameworks/ios_system.framework/ios_system ]]
  xcrun vtool -show-build "$frameworks/ios_system.framework/ios_system" | grep -E "platform +$mach_platform$" >/dev/null
  prepare
  rustup target add "$target"
  # Remap local build paths in the shipped framework.
  RUSTFLAGS="--remap-path-prefix=$cache=/ruff-build" \
    cargo build --manifest-path "$source/Cargo.toml" --locked -p ruff --lib \
    --no-default-features --profile minimal-size --target "$target"
  sdk=$(xcrun --sdk "$sdk_name" --show-sdk-path)
  archive=$cache/target/$target/minimal-size/libruff.a
  output=$cache/$platform/Ruff.framework
  mkdir -p "$output"
  xcrun --sdk "$sdk_name" clang -target "$triple" -isysroot "$sdk" -Oz -Wall -Wextra -Werror \
    -I "$frameworks/ios_system.framework/Headers" -dynamiclib "$here/command.m" "$archive" \
    -F "$frameworks" -framework ios_system -framework CoreFoundation -framework Security -liconv \
    -Wl,-install_name,@rpath/Ruff.framework/Ruff -Wl,-exported_symbol,_ruff_ios_main -Wl,-dead_strip \
    -o "$output/Ruff"
  xcrun strip -S -x "$output/Ruff"
  cp "$source/LICENSE" "$output/LICENSE"
  cat >"$output/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Ruff</string>
<key>CFBundleIdentifier</key><string>com.asheKube.a-Shell.Ruff</string>
<key>CFBundleName</key><string>Ruff</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.17.0</string>
<key>MinimumOSVersion</key><string>14.0</string>
</dict></plist>
PLIST
  nm -gU "$output/Ruff" | grep ' T _ruff_ios_main$'
  xcrun vtool -show-build "$output/Ruff"
  shasum -a 256 "$output/Ruff"
}

case ${1:-} in
  framework) framework "${2:?}" "${3:?}" ;;
  xcframework)
    framework "${2:?Device frameworks required}" device
    framework "${3:?Simulator frameworks required}" simulator
    staging=$(mktemp -d "$cache/xcframework.XXXXXX")
    xcodebuild -create-xcframework -framework "$cache/device/Ruff.framework" \
      -framework "$cache/simulator/Ruff.framework" -output "$staging/Ruff.xcframework"
    rm -rf "$here/Ruff.xcframework"
    mv "$staging/Ruff.xcframework" "$here/Ruff.xcframework"
    rmdir "$staging"
    ;;
  *)
    echo 'Usage: build.sh framework MATCHING_FRAMEWORKS device|simulator | xcframework DEVICE_FRAMEWORKS SIMULATOR_FRAMEWORKS' >&2
    exit 2
    ;;
esac
