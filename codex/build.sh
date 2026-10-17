#!/bin/bash
# Build the pinned Codex CLI as an embedded iOS command.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
cache=${CODEX_BUILD_CACHE:-${TMPDIR:-/tmp}/a-shell-codex}
source=$cache/upstream
export CARGO_TARGET_DIR=${CARGO_TARGET_DIR:-$cache/target}
export CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS:-2}
export IPHONEOS_DEPLOYMENT_TARGET=26.2 CARGO_PROFILE_RELEASE_LTO=off
cargo=${CODEX_CARGO:-cargo}
rustup=${CODEX_RUSTUP:-rustup}

fetch() {
  local name=$1 url=$2 checksum=$3
  if [[ ! -f $cache/$name ]]; then
    echo "Fetch $name"
    curl -fLsS --http1.1 --connect-timeout 15 --max-time 1800 "$url" -o "$cache/$name.part"
    echo "$checksum  $cache/$name.part" | shasum -a 256 -c -
    mv "$cache/$name.part" "$cache/$name"
  fi
  echo "$checksum  $cache/$name" | shasum -a 256 -c -
}

prepare() {
  mkdir -p "$cache"
  fetch codex.tar.gz https://codeload.github.com/openai/codex/tar.gz/refs/tags/rust-v0.160.0 e9ba182239bb984f1d24a57c8b3abb3da127e0a108e5f17d7a9038688cf4369c
  fetch crossterm.tar.gz https://codeload.github.com/openai-oss-forks/crossterm/tar.gz/efa177859fd9623d57b9fe7ae9bf491ae1ac6ec4 ee95e114d05aaf4cf1e3b2f879657daeb6864bfa7fcfefd10c02f1816cbb58d6
  local stage name
  stage=$(mktemp -d "$cache/source.XXXXXX")
  # Rebuild the source overlay from pins; checksum synchronization retains Cargo's cache.
  tar -xzf "$cache/codex.tar.gz" --strip-components=1 -C "$stage"
  mkdir "$stage/ios-crossterm"
  tar -xzf "$cache/crossterm.tar.gz" --strip-components=1 -C "$stage/ios-crossterm"
  for name in crossterm-lifecycle crossterm-terminal; do
    patch -s -f -V never -F 0 -p1 -d "$stage/ios-crossterm" <"$here/$name.patch"
  done
  cp "$here/ashell-terminal.rs" "$stage/ios-crossterm/src/terminal/sys/ios.rs"
  for name in codex home auth-refresh cli tui code-mode sandbox shell tool-driver tool-policy tool-search notify mcp-helper stdio snapshot snapshot-capability environment git-info tui-terminal keyboard metrics-reinit terminal-probe colors relocation; do
    patch -s -f -V never -F 0 -p1 -d "$stage/codex-rs" <"$here/$name.patch"
  done
  cp "$here/ios-relocation.rs" "$stage/codex-rs/rollout/src/ios_relocation.rs"
  cp "$here/tests/relocation.rs" "$stage/codex-rs/thread-store/src/local/ios_relocation_tests.rs"
  cp -R "$here/embedded" "$stage/codex-rs/ios-embedded"
  for name in lock stderr; do
    patch -s -f -V never -F 0 -p1 -d "$stage/codex-rs" <"$here/$name.patch"
  done
  mkdir -p "$source"
  rsync -a --no-times --checksum --delete "$stage/" "$source/"
  rm -r "$stage"
}

apple_target() {
  case ${1:?device or simulator required} in
  device)
    sdk_name=iphoneos
    target=aarch64-apple-ios
    triple=arm64-apple-ios26.2
    mach_platform=IOS
    ;;
  simulator)
    sdk_name=iphonesimulator
    target=aarch64-apple-ios-sim
    triple=arm64-apple-ios26.2-simulator
    mach_platform=IOSSIMULATOR
    ;;
  *)
    echo 'Expected device or simulator' >&2
    return 2
    ;;
  esac
}

rust_build() {
  local free_kb
  free_kb=$(df -k /System/Volumes/Data | awk 'NR==2 {print $4}')
  ((free_kb > 10 * 1024 * 1024)) || {
    echo 'Less than 10 GiB free' >&2
    return 1
  }
  prepare
  "$rustup" target add --toolchain 1.96.1 "$target"
  echo "Build Codex 0.160.0 for $target with $CARGO_BUILD_JOBS jobs"
  (cd "$source/codex-rs" && "$cargo" +1.96.1 build --locked --release --target "$target" -p codex-ios-embedded) >"$cache/build-$target.log" 2>&1 || {
    tail -n 30 "$cache/build-$target.log" >&2
    return 1
  }
}

framework() {
  local frameworks=${1:?Matching Frameworks directory required} platform=${2:?device or simulator required} sdk output symbol
  apple_target "$platform"
  xcrun vtool -show-build "$frameworks/ios_system.framework/ios_system" | grep -E "platform +$mach_platform$" >/dev/null
  for symbol in ashell_register_owned_streams ashell_wait_owned_streams ashell_cancel_owned_streams ashell_unregister_owned_streams ios_useNativeTTY ios_getWindowSize; do
    nm -gU "$frameworks/ios_system.framework/ios_system" | grep " T _$symbol\$" >/dev/null || {
      echo "Missing ios_system prerequisite: $symbol" >&2
      return 1
    }
  done
  rust_build
  sdk=$(xcrun --sdk "$sdk_name" --show-sdk-path)
  output=$cache/$platform/codex.framework
  mkdir -p "$output"
  xcrun --sdk "$sdk_name" clang -target "$triple" -isysroot "$sdk" -Wall -Wextra -Werror \
    -I "$frameworks/ios_system.framework/Headers" \
    -dynamiclib "$here/command.m" "$here/home.m" "$CARGO_TARGET_DIR/$target/release/libcodex_ios_embedded.a" \
    -F "$frameworks" -framework ios_system -framework UIKit -framework Foundation -framework CoreFoundation -framework Security -framework SystemConfiguration \
    -lobjc -lc++ -lz -liconv -Wl,-dead_strip -Wl,-S -Wl,-install_name,@rpath/codex.framework/codex -Wl,-exported_symbol,_codex_ios_main -o "$output/codex"
  cp "$source/LICENSE" "$output/LICENSE"
  cat >"$output/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>codex</string>
<key>CFBundleIdentifier</key><string>com.asheKube.a-Shell.codex</string>
<key>CFBundleName</key><string>codex</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleVersion</key><string>0.160.0</string>
<key>CFBundleShortVersionString</key><string>0.160.0</string>
<key>MinimumOSVersion</key><string>26.2</string>
</dict></plist>
PLIST
  xcrun vtool -show-build "$output/codex"
  shasum -a 256 "$output/codex"
}

case ${1:-} in
prepare) prepare ;;
archive)
  apple_target "${2:?}"
  rust_build
  ;;
framework) framework "${2:?}" "${3:?}" ;;
xcframework)
  framework "${2:?Device frameworks required}" device
  framework "${3:?Simulator frameworks required}" simulator
  staging=$(mktemp -d "$cache/xcframework.XXXXXX")
  xcodebuild -create-xcframework -framework "$cache/device/codex.framework" -framework "$cache/simulator/codex.framework" -output "$staging/codex.xcframework"
  [[ ! -d $here/codex.xcframework ]] || rm -rf "$here/codex.xcframework"
  mv "$staging/codex.xcframework" "$here/codex.xcframework"
  rmdir "$staging"
  ;;
*)
  echo 'Usage: build.sh prepare | archive device|simulator | framework MATCHING_FRAMEWORKS device|simulator | xcframework DEVICE_FRAMEWORKS SIMULATOR_FRAMEWORKS' >&2
  exit 2
  ;;
esac
