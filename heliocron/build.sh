#!/usr/bin/env bash
# Build pinned heliocron as a native a-Shell command.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
cache=${HELIOCRON_BUILD_CACHE:-${TMPDIR:-/tmp}/a-shell-heliocron}
version=1.0.0
revision=45494f235b442f64aa82d24d5610844190a5004c
sha=ebd66d25792921c21d92859c38f29df030b176dfd30f033c459d1e9545ccd4d5
source=$cache/heliocron-$version

prepare() {
  mkdir -p "$cache"
  if [[ ! -f $cache/heliocron.tar.gz ]]; then
    curl -fLsS --connect-timeout 15 --max-time 120 \
      "https://codeload.github.com/mfreeborn/heliocron/tar.gz/$revision" -o "$cache/heliocron.tar.gz.part"
    echo "$sha  $cache/heliocron.tar.gz.part" | shasum -a 256 -c -
    mv "$cache/heliocron.tar.gz.part" "$cache/heliocron.tar.gz"
  fi
  echo "$sha  $cache/heliocron.tar.gz" | shasum -a 256 -c -
  if [[ ! -d $source ]]; then
    mkdir -p "$source"
    tar -xzf "$cache/heliocron.tar.gz" --strip-components=1 -C "$source"
  fi
  if ! patch -s -f -F 0 --dry-run -R -p1 -d "$source" <"$here/native.patch" >/dev/null 2>&1; then
    patch -s -f -F 0 --dry-run -p1 -d "$source" <"$here/native.patch" >/dev/null
    patch -s -f -F 0 -p1 -d "$source" <"$here/native.patch"
  fi
}

framework() {
  local frameworks=${1:?Matching Frameworks directory required} platform=${2:?device or simulator required}
  local target sdk_name triple mach_platform sdk output
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
  *)
    echo 'Expected device or simulator' >&2
    return 2
    ;;
  esac
  [[ -f $frameworks/ios_system.framework/ios_system ]]
  xcrun vtool -show-build "$frameworks/ios_system.framework/ios_system" | grep -E "platform +$mach_platform$" >/dev/null
  prepare
  cargo +1.96.1 --version >/dev/null || {
    echo 'Rust 1.96.1 is missing; run: rustup toolchain install 1.96.1 --profile minimal' >&2
    return 1
  }
  rustup target add --toolchain 1.96.1 "$target"
  (cd "$source" && CARGO_TARGET_DIR="$cache/target" \
    CARGO_PROFILE_RELEASE_DEBUG=0 IPHONEOS_DEPLOYMENT_TARGET=14.0 \
    cargo +1.96.1 build --locked --release --target "$target" --lib)
  sdk=$(xcrun --sdk "$sdk_name" --show-sdk-path)
  output=$cache/$platform/heliocron.framework
  mkdir -p "$output"
  xcrun --sdk "$sdk_name" clang -target "$triple" -isysroot "$sdk" \
    -Wall -Wextra -Werror -I "$frameworks/ios_system.framework/Headers" \
    -dynamiclib "$here/command.m" "$cache/target/$target/release/libheliocron.a" \
    -F "$frameworks" -framework ios_system \
    -Wl,-install_name,@rpath/heliocron.framework/heliocron -Wl,-exported_symbol,_heliocron_ios_main \
    -o "$output/heliocron"
  cp "$source/LICENSE-MIT" "$source/LICENSE-APACHE" "$output/"
  cat >"$output/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>heliocron</string>
<key>CFBundleIdentifier</key><string>com.asheKube.a-Shell.heliocron</string>
<key>CFBundleName</key><string>heliocron</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>1</string>
<key>MinimumOSVersion</key><string>14.0</string>
</dict></plist>
PLIST
  nm -gU "$output/heliocron" | grep ' T _heliocron_ios_main$' >/dev/null
  xcrun vtool -show-build "$output/heliocron"
  shasum -a 256 "$output/heliocron"
}

case ${1:-} in
framework) framework "${2:?Frameworks directory required}" "${3:?device or simulator required}" ;;
xcframework)
  framework "${2:?Device Frameworks directory required}" device
  framework "${3:?Simulator Frameworks directory required}" simulator
  # Replace only this recipe's generated output.
  rm -rf "$here/heliocron.xcframework"
  xcodebuild -create-xcframework -framework "$cache/device/heliocron.framework" \
    -framework "$cache/simulator/heliocron.framework" -output "$here/heliocron.xcframework"
  ;;
*)
  echo 'Usage: build.sh framework FRAMEWORKS device|simulator | xcframework DEVICE_FRAMEWORKS SIMULATOR_FRAMEWORKS' >&2
  exit 2
  ;;
esac
