#!/usr/bin/env bash
# Build pinned fd as an embedded Rust archive and iOS framework.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
cache=${FD_BUILD_CACHE:-${TMPDIR:-/tmp}/a-shell-fd}
source=$cache/fd-10.5.0
sha=e6d9e90730bf316101691e49d59cc02565278dc3779d33a77423801569484851
export CARGO_TARGET_DIR=$cache/target

apple_target() {
  case ${1:?device or simulator required} in
  device)
    sdk_name=iphoneos
    rust_target=aarch64-apple-ios
    clang_target=arm64-apple-ios14.0
    mach_platform=IOS
    ;;
  simulator)
    sdk_name=iphonesimulator
    rust_target=aarch64-apple-ios-sim
    clang_target=arm64-apple-ios14.0-simulator
    mach_platform=IOSSIMULATOR
    ;;
  *)
    echo 'Expected device or simulator' >&2
    return 2
    ;;
  esac
}

prepare() {
  mkdir -p "$cache"
  if [[ ! -f $cache/fd.tar.gz ]]; then
    curl -fLsS --connect-timeout 15 --max-time 180 \
      https://codeload.github.com/sharkdp/fd/tar.gz/refs/tags/v10.5.0 -o "$cache/fd.tar.gz.part"
    echo "$sha  $cache/fd.tar.gz.part" | shasum -a 256 -c -
    mv "$cache/fd.tar.gz.part" "$cache/fd.tar.gz"
  fi
  echo "$sha  $cache/fd.tar.gz" | shasum -a 256 -c -
  [[ -d $source ]] || tar -xzf "$cache/fd.tar.gz" -C "$cache"
  if ! patch -s -f -F 0 --dry-run -R -p1 -d "$source" <"$here/fd.patch" >/dev/null 2>&1; then
    patch -s -f -F 0 --dry-run -p1 -d "$source" <"$here/fd.patch" >/dev/null
    patch -s -f -F 0 -p1 -d "$source" <"$here/fd.patch"
  fi
}

archive() {
  local sdk_name rust_target clang_target mach_platform
  apple_target "${1:?device or simulator required}"
  prepare
  cargo +1.96.1 --version >/dev/null || {
    echo 'Rust 1.96.1 is missing; run: rustup toolchain install 1.96.1 --profile minimal' >&2
    return 1
  }
  rustup target add --toolchain 1.96.1 "$rust_target"
  IPHONEOS_DEPLOYMENT_TARGET=14.0 cargo +1.96.1 build --manifest-path "$source/Cargo.toml" \
    --locked --release --lib --no-default-features --target "$rust_target"
}

framework() {
  local frameworks=${1:?Matching Frameworks directory required} platform=${2:-device}
  local sdk sdk_name rust_target clang_target mach_platform output
  apple_target "$platform"
  output=$cache/$platform/fd.framework
  [[ -f $frameworks/ios_system.framework/ios_system ]]
  xcrun vtool -show-build "$frameworks/ios_system.framework/ios_system" | grep -E "platform +$mach_platform$" >/dev/null
  archive "$platform"
  sdk=$(xcrun --sdk "$sdk_name" --show-sdk-path)
  mkdir -p "$output"
  xcrun --sdk "$sdk_name" clang -target "$clang_target" -isysroot "$sdk" \
    -Wall -Wextra -Werror -I "$frameworks/ios_system.framework/Headers" \
    -F "$frameworks" -dynamiclib "$here/command.m" \
    "$cache/target/$rust_target/release/libfd_ios_embedded.a" -framework ios_system \
    -Wl,-install_name,@rpath/fd.framework/fd -Wl,-exported_symbol,_fd_ios_main -o "$output/fd"
  cp "$source/LICENSE-APACHE" "$source/LICENSE-MIT" "$output/"
  cat >"$output/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.asheKube.a-Shell.fd</string>
<key>CFBundleExecutable</key><string>fd</string>
<key>CFBundleName</key><string>fd</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>10.5.0</string>
<key>MinimumOSVersion</key><string>14.0</string>
</dict></plist>
PLIST
  nm -gU "$output/fd" | grep ' T _fd_ios_main$' >/dev/null
  xcrun vtool -show-build "$output/fd"
  shasum -a 256 "$output/fd"
}

case ${1:-} in
archive) archive "${2:?}" ;;
framework) framework "${2:?}" "${3:-device}" ;;
xcframework)
  framework "${2:?Device frameworks required}" device
  framework "${3:?Simulator frameworks required}" simulator
  staging=$(mktemp -d "$cache/xcframework.XXXXXX")
  xcodebuild -create-xcframework \
    -framework "$cache/device/fd.framework" -framework "$cache/simulator/fd.framework" \
    -output "$staging/fd.xcframework"
  rm -rf "$here/fd.xcframework"
  mv "$staging/fd.xcframework" "$here/fd.xcframework"
  rmdir "$staging"
  ;;
*)
  echo 'Usage: build.sh archive device|simulator | framework MATCHING_FRAMEWORKS [device|simulator] | xcframework DEVICE_FRAMEWORKS SIMULATOR_FRAMEWORKS' >&2
  exit 2
  ;;
esac
