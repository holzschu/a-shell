#!/usr/bin/env bash
# Build pinned Neovim framework/runtime inputs for the canonical phone lane.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
cache=${NVIM_IOS_CACHE:-$HOME/.cache/a-shell-ports/nvim12}
export CCACHE_DIR="$cache/ccache"
sdk_name=${NVIM_IOS_SDK:-iphonesimulator}
arch=${NVIM_IOS_ARCH:-arm64}
case "$sdk_name:$arch" in
iphoneos:arm64) target=arm64-apple-ios16.0 ;;
iphonesimulator:arm64 | iphonesimulator:x86_64) target=$arch-apple-ios16.0-simulator ;;
*)
  echo "Unsupported SDK and architecture: $sdk_name / $arch" >&2
  exit 2
  ;;
esac
# CMake ExternalProjects inherit the target through the toolchain environment.
export NVIM_IOS_SDK=$sdk_name NVIM_IOS_ARCH=$arch
sdk=$(xcrun --sdk "$sdk_name" --show-sdk-path)
cc=(xcrun --sdk "$sdk_name" clang -target "$target" -isysroot "$sdk")

fetch() {
  local url=$1 name=$2 sha=$3 directory=$4
  mkdir -p "$cache"
  if [[ ! -f $cache/$name.tar.gz ]]; then
    echo "Fetch $name"
    curl -fLsS --retry 2 --connect-timeout 15 --max-time 180 "$url" -o "$cache/$name.tar.gz.part"
    echo "$sha  $cache/$name.tar.gz.part" | shasum -a 256 -c -
    mv "$cache/$name.tar.gz.part" "$cache/$name.tar.gz"
  fi
  echo "$sha  $cache/$name.tar.gz" | shasum -a 256 -c -
  if [[ ! -d $cache/$directory ]]; then
    nice -n 15 tar -xzf "$cache/$name.tar.gz" -C "$cache"
  fi
}
apply_patch() {
  local root=$1 name=$2
  if patch -s -f -F0 -R --dry-run -p1 -d "$root" <"$here/$name" >/dev/null 2>&1; then return; fi
  patch -s -f -F0 --dry-run -p1 -d "$root" <"$here/$name" >/dev/null
  echo "Apply $name"
  patch --no-backup-if-mismatch -s -f -F0 -p1 -d "$root" <"$here/$name"
}

native() {
  local tool ios_frameworks
  ios_frameworks=${NVIM_IOS_FRAMEWORKS:?Set NVIM_IOS_FRAMEWORKS to the worker-capable ios_system framework directory}
  # The bundled Make/CMake compiler flag variables are shell word lists.
  if [[ $here = *[[:space:]]* || $cache = *[[:space:]]* || $ios_frameworks = *[[:space:]]* || $sdk = *[[:space:]]* ]]; then
    echo 'The recipe, cache, ios_system framework and SDK paths must not contain whitespace' >&2
    return 1
  fi
  [[ -f $ios_frameworks/ios_system.framework/Headers/ios_spawn.h ]] || { echo 'Missing ios_spawn.h' >&2; return 1; }
  for tool in cmake ninja luajit perl; do command -v "$tool" >/dev/null; done
  [[ $(df -k /System/Volumes/Data | tail -1 | awk '{print $4}') -ge 8388608 ]] || { echo 'At least 8 GiB free on the data volume is required' >&2; return 1; }
  fetch https://codeload.github.com/neovim/neovim/tar.gz/refs/tags/v0.12.6 source 8629fdc5eb951daf89a76f68cad12f2f1e03fab0d539150ba3fe6d177d254b7f neovim-0.12.6
  fetch https://github.com/luajit/luajit/archive/fbb36bb6bfa88716a47c58bcf9ce9f2ef752abac.tar.gz luajit e60cd2f3057aa39d33d1c895a20087ab54494d9a1ca45aa488ff0378af42df48 luajit-fbb36bb6bfa88716a47c58bcf9ce9f2ef752abac
  local lj=$cache/luajit-fbb36bb6bfa88716a47c58bcf9ce9f2ef752abac
  apply_patch "$lj" luajit.patch
  nice -n 15 make -C "$lj/src" -j4 libluajit.a HOST_CC=clang TARGET_SYS=iOS BUILDMODE=static "CC=clang -target $target -isysroot $sdk" "TARGET_FLAGS=-DLUAJIT_DISABLE_JIT -Dexit=nvim_port_exit -include $here/stdio.h"
  mkdir -p "$cache/deps/usr/include/luajit-2.1" "$cache/deps/usr/lib"
  cp "$lj/src/libluajit.a" "$cache/deps/usr/lib/libluajit-5.1.a"
  cp "$lj"/src/lua.h "$lj"/src/lauxlib.h "$lj"/src/lualib.h "$lj"/src/luaconf.h "$lj"/src/luajit.h "$cache/deps/usr/include/luajit-2.1/"
  nice -n 15 cmake -S "$cache/neovim-0.12.6" -B "$cache/host" -G Ninja -DENABLE_LIBINTL=OFF -DCMAKE_BUILD_TYPE=Release
  nice -n 15 cmake --build "$cache/host" --target nlua0 -j4
  apply_patch "$cache/neovim-0.12.6" parsers.patch
  nice -n 15 cmake -S "$cache/neovim-0.12.6/cmake.deps" -B "$cache/deps" -G Ninja -DCMAKE_TOOLCHAIN_FILE="$here/simulator.cmake" -DCMAKE_OSX_SYSROOT="$sdk_name" -DUSE_BUNDLED_LUAJIT=OFF -DUSE_BUNDLED_LUA=OFF -DUSE_BUNDLED_TS_PARSERS=ON -DLUAJIT_INCLUDE_DIR="$cache/deps/usr/include/luajit-2.1" -DLUAJIT_LIBRARY="$cache/deps/usr/lib/libluajit-5.1.a"
  nice -n 15 cmake --build "$cache/deps" -j4
  apply_patch "$cache/deps/build/src/libuv" libuv.patch
  cp "$here/worker-process.c" "$cache/deps/build/src/libuv/src/unix/worker-process.c"
  nice -n 15 cmake -S "$cache/deps/build/src/libuv" -B "$cache/deps/build/src/libuv-build" -DCMAKE_C_FLAGS="-include $here/stdio.h -I$ios_frameworks/ios_system.framework/Headers"
  nice -n 15 cmake --build "$cache/deps/build/src/libuv-build" -j4
  nice -n 15 cmake --install "$cache/deps/build/src/libuv-build"
  nice -n 15 cmake -S "$cache/deps/build/src/luv" -B "$cache/deps/build/src/luv-build" -DCMAKE_C_FLAGS="-I$cache/deps/usr/include -I$cache/deps/usr/include/luajit-2.1 -Dexit=nvim_port_exit -include $here/stdio.h"
  nice -n 15 cmake --build "$cache/deps/build/src/luv-build" -j4
  nice -n 15 cmake --install "$cache/deps/build/src/luv-build"
  nice -n 15 cmake -S "$cache/deps/build/src/treesitter" -B "$cache/deps/build/src/treesitter-build" -DCMAKE_C_FLAGS="-include $here/stdio.h -I$ios_frameworks/ios_system.framework/Headers"
  nice -n 15 cmake --build "$cache/deps/build/src/treesitter-build" -j4
  nice -n 15 cmake --install "$cache/deps/build/src/treesitter-build"
  apply_patch "$cache/neovim-0.12.6" neovim.patch
  apply_patch "$cache/neovim-0.12.6" worker-commands.patch
  apply_patch "$cache/neovim-0.12.6" attached-workers.patch
  apply_patch "$cache/neovim-0.12.6" terminal.patch
  apply_patch "$cache/neovim-0.12.6" loader-cache.patch
  nice -n 15 cmake -S "$cache/neovim-0.12.6" -B "$cache/build" -G Ninja -DCMAKE_TOOLCHAIN_FILE="$here/simulator.cmake" -DCMAKE_OSX_SYSROOT="$sdk_name" -DCMAKE_PREFIX_PATH="$cache/deps/usr" -DNLUA0_HOST_PRG="$cache/host/lib/libnlua0.so" -DLUA_GEN_PRG="$(command -v luajit)" -DLUA_PRG="$(command -v luajit)" -DENABLE_LIBINTL=OFF -DENABLE_LTO=OFF -DCMAKE_MACOSX_BUNDLE=OFF -DHAVE_BE64TOH=OFF -DHAVE_BE64TOH_FUNC=OFF -DCMAKE_C_FLAGS="-Dexit=nvim_port_exit -Dfork=nvim_port_fork -fvisibility=hidden -include $here/stdio.h" -DCMAKE_BUILD_TYPE=Release
  nice -n 15 cmake --build "$cache/build" --target libnvim -j4
  echo _nvim_port_run >"$cache/exports.txt"
  local parsers=() lang
  for lang in c lua markdown markdown_inline query vim vimdoc; do
    parsers+=("$cache/deps/usr/lib/nvim/parser/$lang.a")
  done
  mkdir -p "$cache/Nvim.framework"
  nice -n 15 "${cc[@]}" -O2 -fvisibility=hidden -dynamiclib -install_name @rpath/Nvim.framework/Nvim -Wl,-exported_symbols_list,"$cache/exports.txt" -F"$ios_frameworks" -framework ios_system -I"$cache/deps/usr/include" "$here/entry.c" "$here/parsers.c" "$cache/build/lib/libnvim.a" "${parsers[@]}" -L"$cache/deps/usr/lib" -lluv -lluajit-5.1 -llpeg -luv -lunibilium -ltree-sitter -lutf8proc -liconv -framework Foundation -o "$cache/Nvim.framework/Nvim"
  shasum -a 256 "$cache/Nvim.framework/Nvim"
  mkdir -p "$cache/NvimCommand.framework"
  "${cc[@]}" -O2 -dynamiclib -install_name @rpath/NvimCommand.framework/NvimCommand -I"$ios_frameworks/ios_system.framework/Headers" -F"$ios_frameworks" -framework ios_system -framework Foundation "$here/command.m" -o "$cache/NvimCommand.framework/NvimCommand"
}

payload() {
  local output=${1:?Owned payload directory required} image
  mkdir -p "$output/Frameworks" "$output/bin"
  for image in Nvim NvimCommand; do
    rsync -a --delete "$cache/$image.framework/" "$output/Frameworks/$image.framework/"
    cat >"$output/Frameworks/$image.framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.a-shell.$image</string>
<key>CFBundleExecutable</key><string>$image</string>
<key>CFBundleName</key><string>$image</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleVersion</key><string>0.12.6</string>
<key>MinimumOSVersion</key><string>16.0</string>
</dict></plist>
PLIST
    shasum -a 256 "$output/Frameworks/$image.framework/$image"
  done
  local resources="$output/Frameworks/Nvim.framework"
  # Existing build caches may still contain backups from an older patch invocation.
  rsync -a --delete --delete-excluded --exclude='*.orig' --exclude='*.rej' \
    "$cache/neovim-0.12.6/runtime/" "$resources/runtime/"
  install -m644 "$cache/neovim-0.12.6/LICENSE.txt" "$resources/LICENSE.txt"
  local licenses="$resources/licenses" deps="$cache/deps/build/src" dep notice
  mkdir -p "$licenses"
  for dep in libuv lua_compat53 luv treesitter treesitter_c treesitter_lua \
    treesitter_markdown treesitter_query treesitter_vim treesitter_vimdoc unibilium utf8proc; do
    for notice in "$deps/$dep"/LICENSE*; do
      install -m644 "$notice" "$licenses/$dep-${notice##*/}"
    done
  done
  install -m644 "$cache/luajit-fbb36bb6bfa88716a47c58bcf9ce9f2ef752abac/COPYRIGHT" "$licenses/LuaJIT-COPYRIGHT"
  # LPeg ships its license in the upstream manual.
  install -m644 "$deps/lpeg/lpeg.html" "$licenses/lpeg.html"
  touch "$output/bin/nvim"
  chmod 755 "$output/bin/nvim"
}

xcframeworks() {
  local device=${1:?Device payload} sim_arm=${2:?Arm Simulator payload}
  local sim_intel=${3:?Intel Simulator payload} output=${4:?New output directory}
  local image platform
  diff -qr "$sim_arm/Frameworks/Nvim.framework/runtime" "$sim_intel/Frameworks/Nvim.framework/runtime"
  diff -qr "$sim_arm/Frameworks/Nvim.framework/runtime" "$device/Frameworks/Nvim.framework/runtime"
  mkdir "$output"
  mkdir "$output/Simulator"
  for image in Nvim NvimCommand; do
    local relative="Frameworks/$image.framework" binary="$image.framework/$image"
    local sim="$output/Simulator/$image.framework"
    cp -R "$sim_arm/$relative" "$sim"
    xcrun lipo -create "$sim_arm/$relative/$image" "$sim_intel/$relative/$image" -output "$output/Simulator/$binary"
    [[ $(xcrun lipo -archs "$device/$relative/$image") == arm64 ]]
    for platform in arm64 x86_64; do
      xcrun lipo -verify_arch "$platform" "$sim/$image"
      xcrun vtool -arch "$platform" -show-build "$sim/$image" | grep -Eq 'platform IOSSIMULATOR$'
    done
    xcrun vtool -show-build "$device/$relative/$image" | grep -Eq 'platform IOS$'
    xcodebuild -create-xcframework -framework "$device/$relative" -framework "$sim" \
      -output "$output/$image.xcframework"
    ditto -c -k --keepParent "$output/$image.xcframework" "$output/$image.xcframework.zip"
    shasum -a 256 "$output/$image.xcframework.zip"
  done
}

case ${1:-} in
native) native ;;
payload) payload "${2:?}" ;;
xcframeworks) xcframeworks "${2:?}" "${3:?}" "${4:?}" "${5:?}" ;;
*)
  echo 'Usage: build.sh native | payload OUTPUT | xcframeworks DEVICE SIM_ARM64 SIM_X86_64 OUTPUT' >&2
  exit 2
  ;;
esac
