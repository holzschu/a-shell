#!/usr/bin/env bash
# Build navi 2.24.0 as an ios_system command framework.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
cache=${NAVI_BUILD_DIR:-$HOME/Library/Caches/a-shell/navi}
source=$cache/source
revision=5515367dc8a2a561d2d82b8352f729b1da4120d3
sha=210190d87a7b3beea620fd21a11b78c660483093e842b03873e7096b2704a025
export CARGO_TARGET_DIR=$cache/target CARGO_BUILD_JOBS=2

prepare() {
	mkdir -p "$cache"
	if [[ ! -f $cache/source.tar.gz ]]; then
		curl -fLsS --connect-timeout 15 --max-time 120 "https://codeload.github.com/denisidoro/navi/tar.gz/$revision" -o "$cache/source.tar.gz.part"
		echo "$sha  $cache/source.tar.gz.part" | shasum -a 256 -c -
		mv "$cache/source.tar.gz.part" "$cache/source.tar.gz"
	fi
	echo "$sha  $cache/source.tar.gz" | shasum -a 256 -c -
	patch_sha=$(shasum -a 256 "$here/native.patch" | cut -d ' ' -f 1)
	if [[ $(cat "$cache/source.patch-sha256" 2>/dev/null) != "$patch_sha" ]]; then
		rm -rf "$source" "$cache/source.patch-sha256"
		mkdir -p "$source"
		tar -xzf "$cache/source.tar.gz" --strip-components=1 -C "$source"
		patch -s -f -F 0 -p1 -d "$source" <"$here/native.patch"
		echo "$patch_sha" >"$cache/source.patch-sha256"
	fi
	cp "$here/embedded.rs" "$source/src/embedded.rs"
}

framework() {
	local platform=${1:?device or simulator required} frameworks=${2:?Matching ios_system framework directory required}
	local sdk_name target rust_target mach_platform sdk output
	case $platform in
	device)
		sdk_name=iphoneos
		target=arm64-apple-ios14.0
		rust_target=aarch64-apple-ios
		mach_platform=IOS
		;;
	simulator)
		sdk_name=iphonesimulator
		target=arm64-apple-ios14.0-simulator
		rust_target=aarch64-apple-ios-sim
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
	rustup target add --toolchain 1.96.1 "$rust_target"
	SDKROOT=$(xcrun --sdk "$sdk_name" --show-sdk-path) IPHONEOS_DEPLOYMENT_TARGET=14.0 \
		cargo +1.96.1 build --locked --release --lib --target "$rust_target" --manifest-path "$source/Cargo.toml"
	sdk=$(xcrun --sdk "$sdk_name" --show-sdk-path)
	output=$cache/$platform/navi.framework
	mkdir -p "$output"
	xcrun --sdk "$sdk_name" clang -target "$target" -isysroot "$sdk" \
		-Wall -Wextra -Werror -I "$frameworks/ios_system.framework/Headers" \
		-dynamiclib "$here/command.m" "$cache/target/$rust_target/release/libnavi.a" \
		-F "$frameworks" -framework ios_system -framework Foundation -framework UIKit -framework Security -liconv \
		-Wl,-install_name,@rpath/navi.framework/navi -o "$output/navi"
	cp "$source/LICENSE" "$output/LICENSE"
	cat >"$output/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>navi</string>
<key>CFBundleIdentifier</key><string>org.a-shell.navi</string>
<key>CFBundleName</key><string>navi</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleShortVersionString</key><string>2.24.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>MinimumOSVersion</key><string>14.0</string>
</dict></plist>
PLIST
	nm -gU "$output/navi" | grep ' T _navi_ios_main$' >/dev/null
	xcrun vtool -show-build "$output/navi"
	shasum -a 256 "$output/navi"
}

case ${1:-} in
framework) framework "${2:?}" "${3:?}" ;;
xcframework)
	rm -rf "${2:?XCFramework output path required}"
	xcodebuild -create-xcframework -framework "$cache/device/navi.framework" -framework "$cache/simulator/navi.framework" -output "${2:?XCFramework output path required}"
	;;
*)
	echo 'Usage: build.sh framework device|simulator IOS_SYSTEM_FRAMEWORKS | xcframework OUTPUT' >&2
	exit 2
	;;
esac
