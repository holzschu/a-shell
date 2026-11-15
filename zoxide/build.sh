#!/usr/bin/env bash
# Build the pinned upstream engine through the existing native-framework route.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
cache=${ZOXIDE_BUILD_CACHE:-$HOME/Library/Caches/a-shell/zoxide}
version=0.10.0
checksum=4fcd4272b013a10b637dbcc299c58a9924b94470a9042677ca1a204cc2e9150e
export CARGO_BUILD_JOBS=4
export CARGO_PROFILE_RELEASE_OPT_LEVEL=z CARGO_PROFILE_RELEASE_LTO=fat
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1 CARGO_PROFILE_RELEASE_DEBUG=0
export CARGO_PROFILE_RELEASE_STRIP=none

prepare() {
    mkdir -p "$cache"
    if [[ ! -f $cache/zoxide.tar.gz ]]; then
        curl -fLsS --connect-timeout 15 --max-time 120 \
            "https://codeload.github.com/ajeetdsouza/zoxide/tar.gz/refs/tags/v$version" -o "$cache/zoxide.tar.gz.part"
        echo "$checksum  $cache/zoxide.tar.gz.part" | shasum -a 256 -c -
        mv "$cache/zoxide.tar.gz.part" "$cache/zoxide.tar.gz"
    fi
    echo "$checksum  $cache/zoxide.tar.gz" | shasum -a 256 -c -
    # New source/adapter bytes get their own build graph and native object cache.
    key=$({
        printf '%s\n' "$checksum"
        cat "$here/native.patch" "$here/embedded.rs"
    } | shasum -a 256 | cut -d ' ' -f 1)
    source=$cache/source-$key
    if [[ ! -d $source ]]; then
        local staging
        staging=$(mktemp -d "$cache/source.XXXXXX")
        tar -xzf "$cache/zoxide.tar.gz" --strip-components=1 -C "$staging"
        patch -s -f -F 0 -p1 -d "$staging" <"$here/native.patch"
        cp "$here/embedded.rs" "$staging/src/embedded.rs"
        mv "$staging" "$source"
    fi
    patch -s -f -F 0 --dry-run -R -p1 -d "$source" <"$here/native.patch" >/dev/null
    cmp "$here/embedded.rs" "$source/src/embedded.rs"
    rustup run 1.96.1 cargo --version
    rustup run 1.96.1 rustc --version
}

framework() {
    local frameworks=${1:?Matching Frameworks directory required} platform=${2:?Platform required}
    local target sdk_name triple mach_platform sdk output
    case $platform in
        device)
            target=aarch64-apple-ios sdk_name=iphoneos
            triple=arm64-apple-ios14.0 mach_platform=IOS
            ;;
        simulator)
            target=aarch64-apple-ios-sim sdk_name=iphonesimulator
            triple=arm64-apple-ios14.0-simulator mach_platform=IOSSIMULATOR
            ;;
        simulator-x86_64)
            target=x86_64-apple-ios sdk_name=iphonesimulator
            triple=x86_64-apple-ios14.0-simulator mach_platform=IOSSIMULATOR
            ;;
        *)
            echo 'Expected device, simulator or simulator-x86_64' >&2
            return 2
            ;;
    esac
    [[ -f $frameworks/ios_system.framework/ios_system ]]
    xcrun vtool -show-build "$frameworks/ios_system.framework/ios_system" | grep -E "platform +$mach_platform$" >/dev/null
    prepare
    rustup target add --toolchain 1.96.1 "$target"
    sdk=$(xcrun --sdk "$sdk_name" --show-sdk-path)
    CARGO_TARGET_DIR="$cache/target-$key-$platform-ios14" SDKROOT="$sdk" IPHONEOS_DEPLOYMENT_TARGET=14.0 \
        rustup run 1.96.1 cargo build --locked --release --lib --target "$target" --manifest-path "$source/Cargo.toml"
    output=$cache/$platform/zoxide.framework
    mkdir -p "$output"
    xcrun --sdk "$sdk_name" clang -target "$triple" -isysroot "$sdk" \
        -Oz -Wall -Wextra -Werror -Werror=unguarded-availability-new \
        -I "$frameworks/ios_system.framework/Headers" -dynamiclib "$here/command.m" \
        "$cache/target-$key-$platform-ios14/$target/release/libzoxide_embedded.a" \
        -F "$frameworks" -framework ios_system -framework Foundation \
        -Wl,-install_name,@rpath/zoxide.framework/zoxide \
        -Wl,-exported_symbol,_zoxide_ios_main -Wl,-exported_symbol,_zoxide_z_main \
        -o "$output/zoxide"
    xcrun strip -S -x "$output/zoxide"
    cp "$source/LICENSE" "$output/LICENSE"
    cat >"$output/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>zoxide</string>
<key>CFBundleIdentifier</key><string>org.a-shell.zoxide</string>
<key>CFBundleName</key><string>zoxide</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>1</string>
<key>MinimumOSVersion</key><string>14.0</string>
</dict></plist>
PLIST
    nm -gU "$output/zoxide" | grep ' T _zoxide_ios_main$' >/dev/null
    nm -gU "$output/zoxide" | grep ' T _zoxide_z_main$' >/dev/null
    xcrun vtool -show-build "$output/zoxide"
    shasum -a 256 "$output/zoxide"
}

case ${1:-} in
    prepare) prepare ;;
    framework) framework "${2:?Frameworks directory required}" "${3:?Platform required}" ;;
    host)
        prepare
        CARGO_TARGET_DIR="$cache/target-$key-host" rustup run 1.96.1 cargo build --locked --release --lib --manifest-path "$source/Cargo.toml"
        clang -Oz -Wall -Wextra -Werror -I "$here/tests" "$here/command.m" "$here/tests/host.c" \
            "$cache/target-$key-host/release/libzoxide_embedded.a" -framework Foundation -o "$cache/host-command"
        ;;
    *)
        echo 'Usage: build.sh prepare | host | framework FRAMEWORKS device|simulator|simulator-x86_64' >&2
        exit 2
        ;;
esac
