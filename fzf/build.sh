#!/usr/bin/env bash
# Build pinned fzf as an embedded Go archive and iOS framework.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
cache=${FZF_BUILD_CACHE:-${TMPDIR:-/tmp}/a-shell-fzf}
source=$cache/fzf-source
revision=c0a193e031f01fb50bf6f7be4381990a3753f7cf
sha=efa12216c49af772f267153e161f927033b4f4bb5c9b4eb0d0dd78c61451b208
export GOCACHE=$cache/go-cache GOPATH=$cache/go GOMAXPROCS=2

apple_target() {
  case ${1:?device or simulator required} in
  device)
    sdk_name=iphoneos
    clang_target=arm64-apple-ios14.0
    mach_platform=IOS
    ;;
  simulator)
    sdk_name=iphonesimulator
    clang_target=arm64-apple-ios14.0-simulator
    mach_platform=IOSSIMULATOR
    ;;
  simulator-x86_64)
    sdk_name=iphonesimulator
    clang_target=x86_64-apple-ios14.0-simulator
    mach_platform=IOSSIMULATOR
    ;;
  *)
    echo 'Expected device, simulator or simulator-x86_64' >&2
    return 2
    ;;
  esac
}

prepare() {
  mkdir -p "$cache"
  [[ $(go env GOVERSION) == go1.27.2 ]] || {
    echo 'Go 1.27.2 is required' >&2
    return 1
  }
  if [[ ! -f $cache/fzf.tar.gz ]]; then
    curl -fLsS --connect-timeout 15 --max-time 120 \
      "https://codeload.github.com/junegunn/fzf/tar.gz/$revision" -o "$cache/fzf.tar.gz.part"
    echo "$sha  $cache/fzf.tar.gz.part" | shasum -a 256 -c -
    mv "$cache/fzf.tar.gz.part" "$cache/fzf.tar.gz"
  fi
  echo "$sha  $cache/fzf.tar.gz" | shasum -a 256 -c -
  if [[ ! -d $source ]]; then
    mkdir -p "$source"
    tar -xzf "$cache/fzf.tar.gz" --strip-components=1 -C "$source"
  fi
  if ! patch -s -f -F 0 --dry-run -R -p1 -d "$source" <"$here/native.patch" >/dev/null 2>&1; then
    patch -s -f -F 0 --dry-run -p1 -d "$source" <"$here/native.patch" >/dev/null
    patch -s -f -F 0 -p1 -d "$source" <"$here/native.patch"
  fi
  mkdir -p "$source/embedded" "$source/src/iosbridge"
  cp "$here/entry.go" "$source/embedded/main.go"
  cp "$here/bridge.go" "$source/src/iosbridge/bridge.go"
  cp "$here/options.go" "$source/src/embedded.go"
}

archive() {
  local platform=${1:?host, device or simulator required}
  prepare
  case $platform in
  host)
    go build -C "$source" -p 2 -trimpath -buildvcs=false -buildmode=c-archive -o "$cache/fzf-host.a" ./embedded
    ;;
  device | simulator | simulator-x86_64)
    local sdk sdk_name clang_target mach_platform
    apple_target "$platform"
    sdk=$(xcrun --sdk "$sdk_name" --show-sdk-path)
    local runtime_source runtime_copy overlay goarch=arm64
    [[ $platform != simulator-x86_64 ]] || goarch=amd64
    runtime_source=$(go env GOROOT)/src/runtime/os_workdir_ios_arm64.go
    runtime_copy=$cache/os_workdir_ios_arm64.go
    overlay=$cache/go-ios-overlay.json
    # Embedded Go must preserve the host's process directory on first dlopen.
    # Keep the pinned toolchain untouched and fail closed if its source changes.
    echo "4382ac94186c24d0087bf378af0fd2fc860fefee29554488b94fe9eddbba6bdf  $runtime_source" | shasum -a 256 -c -
    cp "$runtime_source" "$runtime_copy"
    patch -s -f -F 0 "$runtime_copy" <"$here/runtime-cwd.patch"
    jq -n --arg original "$runtime_source" --arg replacement "$runtime_copy" \
      '{Replace: {($original): $replacement}}' >"$overlay"
    # GOOS=ios supplies the ios/darwin tags on both platforms; clang selects
    # the Simulator ABI. A macOS Go archive is not a Simulator archive.
    GOOS=ios GOARCH="$goarch" CGO_ENABLED=1 CC="$(xcrun --sdk "$sdk_name" --find clang)" \
    CGO_CFLAGS="-Oz -isysroot $sdk -target $clang_target" \
    CGO_LDFLAGS="-isysroot $sdk -target $clang_target" \
      go build -C "$source" -ldflags="-s -w" -overlay "$overlay" -p 2 -trimpath -buildvcs=false -buildmode=c-archive -o "$cache/fzf-$platform.a" ./embedded
    ;;
  *) return 2 ;;
  esac
}

framework() {
  local frameworks=${1:?Matching Frameworks directory required} platform=${2:-device} sdk sdk_name clang_target mach_platform output
  apple_target "$platform"
  output=$cache/$platform/fzf.framework
  [[ -f $frameworks/ios_system.framework/ios_system ]]
  xcrun vtool -show-build "$frameworks/ios_system.framework/ios_system" | grep -E "platform +$mach_platform$" >/dev/null
  nm -gU "$frameworks/ios_system.framework/ios_system" | grep ' T _ios_getWindowSize$' >/dev/null
  archive "$platform"
  sdk=$(xcrun --sdk "$sdk_name" --show-sdk-path)
  mkdir -p "$output"
  xcrun --sdk "$sdk_name" clang -target "$clang_target" -isysroot "$sdk" \
    -Oz -Wall -Wextra -Werror -I "$frameworks/ios_system.framework/Headers" \
    -dynamiclib "$here/command.m" "$cache/fzf-$platform.a" -F "$frameworks" -framework ios_system \
    -framework Foundation -framework UIKit -framework Security -lresolv \
    -Wl,-install_name,@rpath/fzf.framework/fzf -o "$output/fzf"
  cp "$source/LICENSE" "$output/LICENSE"
  cat >"$output/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>fzf</string>
<key>CFBundleIdentifier</key><string>com.asheKube.a-Shell.fzf</string>
<key>CFBundleName</key><string>fzf</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleShortVersionString</key><string>0.74.5</string>
<key>CFBundleVersion</key><string>1</string>
<key>MinimumOSVersion</key><string>14.0</string>
</dict></plist>
PLIST
  nm -gU "$output/fzf" | grep ' T _fzf_ios_main$' >/dev/null
  xcrun vtool -show-build "$output/fzf"
  shasum -a 256 "$output/fzf"
}

case ${1:-} in
archive) archive "${2:?}" ;;
framework) framework "${2:?}" "${3:-device}" ;;
xcframework)
  framework "${2:?Device frameworks required}" device
  framework "${3:?Simulator frameworks required}" simulator
  staging=$(mktemp -d "$cache/xcframework.XXXXXX")
  xcodebuild -create-xcframework \
    -framework "$cache/device/fzf.framework" \
    -framework "$cache/simulator/fzf.framework" \
    -output "$staging/fzf.xcframework"
  rm -rf "$here/fzf.xcframework"
  mv "$staging/fzf.xcframework" "$here/fzf.xcframework"
  rmdir "$staging"
  ;;
*)
  echo 'Usage: build.sh archive host|device|simulator | framework MATCHING_FRAMEWORKS [device|simulator] | xcframework DEVICE_FRAMEWORKS SIMULATOR_FRAMEWORKS' >&2
  exit 2
  ;;
esac
