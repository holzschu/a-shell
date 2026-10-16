#!/usr/bin/env bash
# Build pinned gitoxide with command-owned streams for a-Shell.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
cache=${GITOXIDE_BUILD_CACHE:-${TMPDIR:-/tmp}/a-shell-gitoxide}
source=$cache/source
# v0.60.0 resolves to 0115e902fd0334b8f370766993eb17babed3157f.
sha=7414812a006ac67d38a8d7e5fa74ebb2863dac10d50fce6cdc2e0c3ddd419f2e
export CARGO_TARGET_DIR=$cache/target IPHONEOS_DEPLOYMENT_TARGET=14.0

prepare() {
  mkdir -p "$cache"
  rustup run 1.96.1 rustc --version
  if [[ ! -f $cache/source.tar.gz ]]; then
    curl -fLsS --connect-timeout 15 --max-time 300 \
      https://codeload.github.com/GitoxideLabs/gitoxide/tar.gz/refs/tags/v0.60.0 -o "$cache/source.tar.gz.part"
    echo "$sha  $cache/source.tar.gz.part" | shasum -a 256 -c -
    mv "$cache/source.tar.gz.part" "$cache/source.tar.gz"
  fi
  echo "$sha  $cache/source.tar.gz" | shasum -a 256 -c -
  if [[ ! -d $source ]]; then
    mkdir -p "$source"
    tar -xzf "$cache/source.tar.gz" --strip-components=1 -C "$source"
  fi
  if ! patch -s -f -F 0 --dry-run -R -p1 -d "$source" <"$here/embedded.patch" >/dev/null 2>&1; then
    patch -s -f -F 0 --dry-run -p1 -d "$source" <"$here/embedded.patch" >/dev/null
    patch -s -f -F 0 -p1 -d "$source" <"$here/embedded.patch"
  fi
  cp "$here/embedded.rs" "$source/src/embedded.rs"
}

framework() {
  local frameworks=${1:?Matching ios_system Frameworks directory required} platform=${2:-device}
  local sdk_name target triple sdk output
  case $platform in
    device)
      sdk_name=iphoneos
      target=aarch64-apple-ios
      triple=arm64-apple-ios14.0
      ;;
    simulator)
      sdk_name=iphonesimulator
      target=aarch64-apple-ios-sim
      triple=arm64-apple-ios14.0-simulator
      ;;
    *)
      echo 'Expected device or simulator' >&2
      return 2
      ;;
  esac
  [[ -f $frameworks/ios_system.framework/ios_system ]]
  prepare
  rustup target list --toolchain 1.96.1 --installed | grep -Fx "$target" >/dev/null || {
    echo "Install the Rust 1.96.1 target before building: $target" >&2
    return 1
  }
  cargo +1.96.1 build --release --manifest-path "$source/Cargo.toml" --locked --target "$target" --lib --no-default-features \
    --features sha1,pretty-cli,prodash-render-line,gitoxide-core-blocking-client,http-client-reqwest
  sdk=$(xcrun --sdk "$sdk_name" --show-sdk-path)
  output=$cache/$platform/gitoxide.framework
  mkdir -p "$output"
  xcrun --sdk "$sdk_name" clang -target "$triple" -isysroot "$sdk" -Wall -Wextra -Werror \
    -I "$frameworks/ios_system.framework/Headers" -F "$frameworks" -dynamiclib \
    "$here/command.m" "$cache/target/$target/release/libgitoxide.a" -framework ios_system \
    -framework Foundation -framework Security -framework SystemConfiguration -lc++ -lz -liconv \
    -Wl,-install_name,@rpath/gitoxide.framework/gitoxide -o "$output/gitoxide"
  cp "$source/LICENSE-MIT" "$output/LICENSE-MIT"
  cp "$source/LICENSE-APACHE" "$output/LICENSE-APACHE"
  cat >"$output/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>gitoxide</string>
<key>CFBundleIdentifier</key><string>com.asheKube.a-Shell.gitoxide</string>
<key>CFBundleName</key><string>gitoxide</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleShortVersionString</key><string>0.60.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>MinimumOSVersion</key><string>14.0</string>
</dict></plist>
PLIST
  nm -gU "$output/gitoxide" | grep ' T _gix_ios_main$' >/dev/null
  xcrun vtool -show-build "$output/gitoxide"
  shasum -a 256 "$output/gitoxide"
}

case ${1:-} in
  framework) framework "${2:?}" "${3:-device}" ;;
  xcframework)
    framework "${2:?Device frameworks required}" device
    framework "${3:?Simulator frameworks required}" simulator
    staging=$(mktemp -d "$cache/xcframework.XXXXXX")
    xcodebuild -create-xcframework -framework "$cache/device/gitoxide.framework" \
      -framework "$cache/simulator/gitoxide.framework" -output "$staging/gitoxide.xcframework"
    rm -rf "$here/gitoxide.xcframework"
    mv "$staging/gitoxide.xcframework" "$here/gitoxide.xcframework"
    rmdir "$staging"
    ;;
  *)
    echo 'Usage: build.sh framework MATCHING_FRAMEWORKS [device|simulator] | xcframework DEVICE_FRAMEWORKS SIMULATOR_FRAMEWORKS' >&2
    exit 2
    ;;
esac
