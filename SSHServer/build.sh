#!/bin/bash
set -euo pipefail
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <iphoneos|iphonesimulator> <source-inputs> <output> <verified-frameworks>" >&2
    exit 64
fi
sdk=$1; inputs=$2; output=$3; frameworks=$4
case "$sdk" in
    iphoneos) target=arm64-apple-ios16.0 ;;
    iphonesimulator) target=arm64-apple-ios16.0-simulator ;;
    *) echo "Unsupported SDK: $sdk" >&2; exit 64 ;;
esac
recipe=$(cd "$(dirname "$0")" && pwd)
inputs=$(cd "$inputs" && pwd)
frameworks=$(cd "$frameworks" && pwd)
mkdir -p "$output"
output=$(cd "$output" && pwd)
(cd "$inputs" && printf '%s\n' '49560f677d96e3706a904ac2de1116e25f3680937d51e5c92198fcba4a1c1e9f  libssh-0.12.2.tar.xz' | shasum -a 256 -c -)
for path in ios_system.framework/ios_system openssl.framework/openssl openssl.framework/Headers/opensslv.h; do
    test -f "$frameworks/$path" || { echo "Missing verified framework input: $path" >&2; exit 1; }
done
{
    printf '%s\n' "$sdk" "$target"
    xcodebuild -version
    cmake --version
    shasum -a 256 "$recipe/build.sh" "$recipe/server.c" "$recipe/../ShellWorkers/NativePane.h" "$frameworks/ios_system.framework/ios_system" "$frameworks/openssl.framework/openssl"
} > "$output/recipe-next.txt"
if [ -f "$output/recipe.txt" ] && ! cmp -s "$output/recipe.txt" "$output/recipe-next.txt"; then
    echo "Build inputs changed; use a fresh output directory" >&2
    exit 1
fi
mv "$output/recipe-next.txt" "$output/recipe.txt"
if [ ! -d "$output/source" ]; then
    source_stage=$(mktemp -d "$output/source.XXXXXX")
    trap 'rm -rf "$source_stage"' EXIT
    tar -xf "$inputs/libssh-0.12.2.tar.xz" -C "$source_stage" --strip-components=1
    mv "$source_stage" "$output/source"
    trap - EXIT
fi
mkdir -p "$output/crypto/include" "$output/crypto/lib"
ln -sfn "$frameworks/openssl.framework/Headers" "$output/crypto/include/openssl"
ln -sfn "$frameworks/openssl.framework/openssl" "$output/crypto/lib/libcrypto.dylib"
cmake -S "$output/source" -B "$output/build" -G Ninja -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$sdk" -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_SHARED_LIBS=OFF -DWITH_GSSAPI=OFF -DWITH_EXAMPLES=OFF -DWITH_SYMBOL_VERSIONING=OFF -DPKG_CONFIG_EXECUTABLE=/usr/bin/false -DOPENSSL_INCLUDE_DIR="$output/crypto/include" -DOPENSSL_CRYPTO_LIBRARY="$output/crypto/lib/libcrypto.dylib"
nice -n 15 cmake --build "$output/build" -j2
framework="$output/sdk/SSHServer.framework"
mkdir -p "$framework"
xcrun --sdk "$sdk" clang -target "$target" -Oz -fPIC -Wall -Wextra -Werror -I"$output/source/include" -I"$output/build/include" -I"$recipe/../ShellWorkers" -dynamiclib -Wl,-exported_symbol,_ashell_sshd_main -Wl,-install_name,@rpath/SSHServer.framework/SSHServer "$recipe/server.c" "$output/build/src/libssh.a" -F"$frameworks" -framework ios_system -framework openssl -lz -o "$framework/SSHServer"
cat > "$framework/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>SSHServer</string><key>CFBundleIdentifier</key><string>org.a-shell.SSHServer</string><key>CFBundleName</key><string>SSHServer</string><key>CFBundlePackageType</key><string>FMWK</string><key>CFBundleVersion</key><string>1</string><key>CFBundleShortVersionString</key><string>0.12.2</string><key>MinimumOSVersion</key><string>16.0</string></dict></plist>
PLIST
shasum -a 256 "$framework/SSHServer"
