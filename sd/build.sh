#!/usr/bin/env bash
# Build the pinned sd CLI with command-owned ios_system streams.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
cache=${SD_BUILD_CACHE:-${TMPDIR:-/tmp}/a-shell-sd}
source=$cache/source
version=v1.1.0 # 4a7b216552d64134c0fa17a59b9d557d89019f0f
sha=defdce484f8c92f265e1282490572575028967c2c55d356111d1e49a3ea9a88e
export CARGO_TARGET_DIR=$cache/target

prepare() {
  mkdir -p "$cache"
  cargo +1.96.1 --version
  if [[ ! -f $cache/source.tar.gz ]]; then
    curl -fLsS --connect-timeout 15 --max-time 120 \
      "https://codeload.github.com/chmln/sd/tar.gz/refs/tags/$version" -o "$cache/source.tar.gz.part"
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
  cp "$here/host_io.rs" "$source/sd/src/host_io.rs"
}

framework() {
  local frameworks=${1:?Matching Frameworks directory required} platform=${2:-device}
  local target sdk_name mach_platform sdk output
  case $platform in
  simulator)
    target=aarch64-apple-ios-sim
    sdk_name=iphonesimulator
    mach_platform=IOSSIMULATOR
    ;;
  device)
    target=aarch64-apple-ios
    sdk_name=iphoneos
    mach_platform=IOS
    ;;
  *) return 2 ;;
  esac
  [[ -f $frameworks/ios_system.framework/ios_system ]]
  xcrun vtool -show-build "$frameworks/ios_system.framework/ios_system" | grep -E "platform +$mach_platform$" >/dev/null
  prepare
  rustup target add --toolchain 1.96.1 "$target"
  sdk=$(xcrun --sdk "$sdk_name" --show-sdk-path)
  # SDK 27 rejects the LINKEDIT layout produced by upstream's strip=true.
  SDKROOT=$sdk IPHONEOS_DEPLOYMENT_TARGET=14.0 CARGO_PROFILE_RELEASE_STRIP=none \
    cargo +1.96.1 rustc --locked --release --target "$target" \
    --manifest-path "$source/Cargo.toml" -p sd-cli --lib -- \
    --remap-path-prefix "$cache=sd-build" \
    -L "framework=$frameworks" -l framework=ios_system \
    -C link-arg=-Wl,-install_name,@rpath/sd.framework/sd
  output=$cache/$platform/sd.framework
  mkdir -p "$output"
  cp "$cache/target/$target/release/libsd_ios.dylib" "$output/sd"
  cp "$source/LICENSE" "$output/LICENSE"
  cat >"$output/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>sd</string>
<key>CFBundleIdentifier</key><string>com.asheKube.a-Shell.sd</string>
<key>CFBundleName</key><string>sd</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>MinimumOSVersion</key><string>14.0</string>
</dict></plist>
PLIST
  nm -gU "$output/sd" | grep ' T _sd_ios_main$' >/dev/null
  xcrun vtool -show-build "$output/sd"
  shasum -a 256 "$output/sd"
}

case ${1:-} in
framework) framework "${2:?}" "${3:-device}" ;;
xcframework)
  framework "${2:?Device frameworks required}" device
  framework "${3:?Simulator frameworks required}" simulator
  staging=$(mktemp -d "$cache/xcframework.XXXXXX")
  xcodebuild -create-xcframework \
    -framework "$cache/device/sd.framework" \
    -framework "$cache/simulator/sd.framework" \
    -output "$staging/sd.xcframework"
  rm -rf "$here/sd.xcframework"
  mv "$staging/sd.xcframework" "$here/sd.xcframework"
  rmdir "$staging"
  ;;
*)
  echo 'Usage: build.sh framework MATCHING_FRAMEWORKS [device|simulator] | xcframework DEVICE_FRAMEWORKS SIMULATOR_FRAMEWORKS' >&2
  exit 2
  ;;
esac
