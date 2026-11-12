#!/bin/bash
set -euo pipefail
# Produce framework inputs. Xcode packages and signs the app.
if [ "$#" -ne 6 ]; then
    echo "Usage: $0 <iphoneos|iphonesimulator> <archives> <output> <ios-system-source> <frameworks> <ncurses-include>" >&2
    exit 64
fi
sdk=$1; archives=$2; output=$3; ios_source=$4; frameworks=$5; curses=$6
case "$sdk" in
    iphoneos) target=arm64-apple-ios14.0 ;;
    iphonesimulator) target=arm64-apple-ios14.0-simulator ;;
    *) echo "Unsupported SDK: $sdk" >&2; exit 64 ;;
esac
recipe=$(cd "$(dirname "$0")" && pwd)
pane_headers="$recipe/../ShellWorkers"
for path in "$ios_source/ios_error.h" "$ios_source/ios_system/ios_system.h" "$frameworks/ios_system.framework/ios_system" "$curses/ncurses.h" "$curses/term.h"; do
    test -f "$path" || { echo "Missing input: $path" >&2; exit 1; }
done
(cd "$archives" && shasum -a 256 -c "$recipe/sources.sha256")
mkdir -p "$output"
output=$(cd "$output" && pwd)
archives=$(cd "$archives" && pwd)
ios_source=$(cd "$ios_source" && pwd)
frameworks=$(cd "$frameworks" && pwd)
curses=$(cd "$curses" && pwd)
receipt="$output/inputs.sha256"
shasum -a 256 "$recipe/build.sh" "$recipe/ios.patch" "$recipe/ios-engine.c" "$recipe/ios-engine.h" "$recipe/ios-boundary.h" "$recipe/host.m" "$recipe/acceptance.m" "$recipe/terminal.terminfo" "$recipe/sources.sha256" "$recipe/NCURSES-LICENSE" "$pane_headers/NativePane.h" "$ios_source/ios_error.h" "$ios_source/ios_system/ios_system.h" "$frameworks/ios_system.framework/ios_system" "$curses/ncurses.h" "$curses/term.h" > "$receipt.new"
{
    xcrun --sdk "$sdk" clang --version
    xcrun --sdk "$sdk" --show-sdk-version
    printf '%s\n' "$target"
} >> "$receipt.new"
if [ -f "$receipt" ] && ! cmp -s "$receipt" "$receipt.new"; then
    echo "Build inputs changed; use a fresh output directory: $output" >&2
    rm "$receipt.new"
    exit 1
fi
mv "$receipt.new" "$receipt"
if [ ! -d "$output/libevent-2.1.13-stable" ]; then
    staging=$(mktemp -d "$output/source.XXXXXX")
    trap 'rm -rf "$staging"' EXIT
    tar -xzf "$archives/libevent-2.1.13-stable.tar.gz" -C "$staging"
    mv "$staging/libevent-2.1.13-stable" "$output/libevent-2.1.13-stable"
    rmdir "$staging"
    trap - EXIT
fi
if [ ! -d "$output/tmux-3.8" ]; then
    staging=$(mktemp -d "$output/source.XXXXXX")
    trap 'rm -rf "$staging"' EXIT
    tar -xzf "$archives/tmux-3.8.tar.gz" -C "$staging"
    (cd "$staging/tmux-3.8" && patch -p1 < "$recipe/ios.patch")
    mv "$staging/tmux-3.8" "$output/tmux-3.8"
    rmdir "$staging"
    trap - EXIT
fi
cp "$recipe/ios-engine.c" "$recipe/ios-engine.h" "$recipe/ios-boundary.h" "$output/tmux-3.8/"
sysroot=$(xcrun --sdk "$sdk" --show-sdk-path)
cmake -S "$output/libevent-2.1.13-stable" -B "$output/event-build" -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$sysroot" -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 '-DCMAKE_C_FLAGS=-Oz -Werror=unguarded-availability-new' -DEVENT__HAVE_PIPE2=OFF -DEVENT__DISABLE_OPENSSL=ON -DEVENT__DISABLE_TESTS=ON -DEVENT__DISABLE_REGRESS=ON -DEVENT__DISABLE_SAMPLES=ON -DEVENT__LIBRARY_TYPE=STATIC -DCMAKE_INSTALL_PREFIX="$output/event"
nice -n 15 cmake --build "$output/event-build" --parallel 2
cmake --install "$output/event-build"
(cd "$output/tmux-3.8" && autoreconf -fi)
mkdir -p "$output/engine" "$output/sdk" "$output/share/terminfo"
/usr/bin/tic -x -o "$output/share/terminfo" "$recipe/terminal.terminfo"
(cd "$output/engine" && "$output/tmux-3.8/configure" --host=aarch64-apple-ios --with-TERM=screen.xterm-256color --disable-utf8proc --disable-sixel --disable-jemalloc CC="xcrun --sdk $sdk clang -target $target" CFLAGS="-Oz -fvisibility=hidden -Werror=unguarded-availability-new" CPPFLAGS="-I$output/event/include -I$curses -I$ios_source -I$pane_headers -F$frameworks" LDFLAGS="-L$output/event/lib -F$frameworks -framework ios_system" PKG_CONFIG_LIBDIR="$output/event/lib/pkgconfig")
nice -n 15 make -C "$output/engine" -j2
for name in TmuxNative TmuxHost TmuxAcceptance; do
    framework="$output/sdk/$name.framework"
    mkdir -p "$framework"
    if [ "$name" = TmuxNative ]; then
        cp "$output/engine/tmux" "$framework/$name"
        cp "$output/tmux-3.8/COPYING" "$framework/TMUX-LICENSE"
        cp "$output/libevent-2.1.13-stable/LICENSE" "$framework/LIBEVENT-LICENSE"
    else
        source="$recipe/host.m"
        if [ "$name" = TmuxAcceptance ]; then source="$recipe/acceptance.m"; fi
        xcrun --sdk "$sdk" clang -target "$target" -Oz -fvisibility=hidden -Werror=unguarded-availability-new -dynamiclib -fobjc-arc -fblocks -I"$ios_source" -I"$pane_headers" -F"$frameworks" -framework Foundation -framework ios_system -install_name "@rpath/$name.framework/$name" "$source" -o "$framework/$name"
    fi
    if [ "$name" = TmuxHost ]; then
        cp -R "$output/share/terminfo" "$framework/"
        cp "$recipe/NCURSES-LICENSE" "$framework/NCURSES-LICENSE"
    fi
    xcrun --sdk "$sdk" strip -x "$framework/$name"
    cat > "$framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>$name</string><key>CFBundleIdentifier</key><string>local.tmux.$name</string><key>CFBundleName</key><string>$name</string><key>CFBundlePackageType</key><string>FMWK</string><key>CFBundleVersion</key><string>1</string><key>CFBundleShortVersionString</key><string>3.8</string><key>MinimumOSVersion</key><string>14.0</string></dict></plist>
PLIST
    file "$framework/$name"
    shasum -a 256 "$framework/$name"
    wc -c < "$framework/$name"
    gzip -c "$framework/$name" | wc -c
done
