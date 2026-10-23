#!/usr/bin/env bash
# Build one pinned app command, including both Simulator architectures.
set -euo pipefail
app=$(cd "$(dirname "$0")/.." && pwd -P)
product=${1:?Usage: ci/native-frameworks.sh helix|fd|fzf|navi|gitoxide|Ruff|rg|node}
recipe=$product
case $product in
  helix|fd|fzf|navi|gitoxide|Ruff|rg|node) ;;
  *) echo "Unknown native product: $product" >&2; exit 2 ;;
esac
work=$app/.build/native/$product
dist=$app/.build/dist
mkdir -p "$work" "$dist"
export CARGO_BUILD_JOBS=4 CMAKE_BUILD_PARALLEL_LEVEL=4
export CARGO_PROFILE_RELEASE_OPT_LEVEL=z CARGO_PROFILE_RELEASE_LTO=fat
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1 CARGO_PROFILE_RELEASE_DEBUG=0
export CARGO_PROFILE_RELEASE_STRIP=symbols
export HELIX_BUILD_CACHE=$work/command FD_BUILD_CACHE=$work/command
export FZF_BUILD_CACHE=$work/command NAVI_BUILD_DIR=$work/command
export GITOXIDE_BUILD_CACHE=$work/command RUFF_BUILD_CACHE=$work/command RG_BUILD_CACHE=$work/command

# All commands link the same public ios_system ABI. Never use a developer's SDK cache.
revision=df998e76cea0266bd3615bb9a1f4f7d745f318a2
checksum=6d2201c1dee131b831b8108b578ede560277d1c205fd8c64f2fb9dcd70e7baca
if [[ ! -f $work/ios-system.tar.gz ]]; then
  curl -fLsS --retry 2 --connect-timeout 15 --max-time 300 \
    "https://codeload.github.com/holzschu/ios_system/tar.gz/$revision" -o "$work/ios-system.tar.gz.part"
  echo "$checksum  $work/ios-system.tar.gz.part" | shasum -a 256 -c -
  mv "$work/ios-system.tar.gz.part" "$work/ios-system.tar.gz"
fi
echo "$checksum  $work/ios-system.tar.gz" | shasum -a 256 -c -
if [[ ! -d $work/ios-system ]]; then
  mkdir -p "$work/ios-system"
  tar -xzf "$work/ios-system.tar.gz" --strip-components=1 -C "$work/ios-system"
fi
for platform in device simulator simulator-x86_64; do
  sdk=iphonesimulator
  arch=arm64
  [[ $platform != device ]] || sdk=iphoneos
  [[ $platform != simulator-x86_64 ]] || arch=x86_64
  if ! xcodebuild -project "$work/ios-system/ios_system.xcodeproj" -target ios_system \
    -configuration Release -sdk "$sdk" -jobs 4 ARCHS="$arch" ONLY_ACTIVE_ARCH=NO \
    IPHONEOS_DEPLOYMENT_TARGET=14.0 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    CONFIGURATION_BUILD_DIR="$work/sdk/$platform" build >"$work/sdk-$platform.log" 2>&1; then
    tail -n 60 "$work/sdk-$platform.log" >&2
    exit 1
  fi
done

if [[ $product == node ]]; then
  arch -x86_64 /usr/bin/true || {
    echo 'Rosetta 2 is required for Node x64 build-time tools.' >&2
    exit 1
  }
  # Node's packaging recipe consumes an xcframework rather than loose frameworks.
  mkdir -p "$work/sdk/universal"
  ditto "$work/sdk/simulator/ios_system.framework" "$work/sdk/universal/ios_system.framework"
  xcrun lipo -create "$work/sdk/simulator/ios_system.framework/ios_system" \
    "$work/sdk/simulator-x86_64/ios_system.framework/ios_system" \
    -output "$work/sdk/universal/ios_system.framework/ios_system"
  [[ ! -d $work/ios_system.xcframework ]] || rm -rf "$work/ios_system.xcframework"
  xcodebuild -create-xcframework -framework "$work/sdk/device/ios_system.framework" \
    -framework "$work/sdk/universal/ios_system.framework" -output "$work/ios_system.xcframework"
  export IOS_SYSTEM_XCFRAMEWORK=$work/ios_system.xcframework
  export NODE_IOS_XCFRAMEWORK=$work/node-package.xcframework
  export IOS_SYSTEM_SIMULATOR_SLICE=ios-arm64_x86_64-simulator NODE_IOS_JOBS=4
  export NODE_IOS_CACHE=$work/node-arm64
  bash "$app/node/build.sh" node
  bash "$app/node/build.sh" device
  bash "$app/node/build.sh" package
  export NODE_IOS_CACHE=$work/node-x86_64 NODE_IOS_SIMULATOR_ARCH=x86_64 NODE_IOS_PLATFORMS=simulator
  bash "$app/node/build.sh" node
  bash "$app/node/build.sh" package
  device=$work/node-arm64/framework/device/node.framework
  simulator=$work/node-arm64/framework/simulator/node.framework
  intel=$work/node-x86_64/framework/simulator/node.framework
  # These scripts belong in app resources, never inside a signed framework.
  ditto -c -k --norsrc "$app/Resources/npm" "$dist/node-npm.zip"
  ditto -c -k --norsrc "$app/Resources/node-fetch" "$dist/node-fetch.zip"
else
  recipe=$product
  [[ $product != Ruff ]] || recipe=ruff
  for platform in device simulator simulator-x86_64; do
    if [[ $product == navi ]]; then
      bash "$app/$recipe/build.sh" framework "$platform" "$work/sdk/$platform"
    else
      bash "$app/$recipe/build.sh" framework "$work/sdk/$platform" "$platform"
    fi
  done
  device=$work/command/device/$product.framework
  simulator=$work/command/simulator/$product.framework
  intel=$work/command/simulator-x86_64/$product.framework
fi

mkdir -p "$work/universal"
ditto "$simulator" "$work/universal/$product.framework"
xcrun lipo -create "$simulator/$product" "$intel/$product" \
  -output "$work/universal/$product.framework/$product"
case $product in
  helix) symbols=hx_ios_main ;;
  gitoxide) symbols=gix_ios_main ;;
  Ruff) symbols=ruff_ios_main ;;
  node) symbols='node_ios_main npm_ios_main npx_ios_main' ;;
  *) symbols=${product}_ios_main ;;
esac
printf 'slice\tstripped_bytes\tgzip_bytes\n' >"$dist/$product.sizes.tsv"
slice=device
for binary in "$device/$product" "$work/universal/$product.framework/$product"; do
  xcrun strip -S -x "$binary"
  for arch in $(xcrun lipo -archs "$binary"); do
    exports=$(xcrun nm -arch "$arch" -gU "$binary")
    for symbol in $symbols; do
      grep -E " T _$symbol$" <<<"$exports" >/dev/null || {
        echo "$binary ($arch): missing export _$symbol" >&2
        exit 1
      }
    done
  done
  printf '%s\t%s\t%s\n' "$slice" "$(stat -f %z "$binary")" "$(gzip -c "$binary" | wc -c | tr -d ' ')" >>"$dist/$product.sizes.tsv"
  slice=simulator
done
[[ ! -d $work/$product.xcframework ]] || rm -rf "$work/$product.xcframework"
xcodebuild -create-xcframework -framework "$device" \
  -framework "$work/universal/$product.framework" -output "$work/$product.xcframework"
ditto -c -k --norsrc --keepParent "$work/$product.xcframework" "$dist/$product.xcframework.zip"
minimum=14.0
[[ $product != node ]] || minimum=16.0
sum=$(swift package compute-checksum "$dist/$product.xcframework.zip")
uv run "$app/ci/audit-artifact.py" "$dist/$product.xcframework.zip" \
  --sha256 "$sum" --max-minos "$minimum" >"$dist/$product.audit.json"
unzip -tq "$dist/$product.xcframework.zip"
shasum -a 256 "$dist/$product.xcframework.zip"
# Each matrix job writes a distinct manifest, then the release job joins them.
(
  cd "$dist"
  files=("$product.xcframework.zip")
  [[ $product != node ]] || files+=(node-npm.zip node-fetch.zip)
  shasum -a 256 "${files[@]}" >"$product.checksums.txt"
)
cat >"$dist/$product.release.md" <<EOF
## $product

Device arm64 and universal arm64/x86_64 Simulator; minimum iOS $minimum.
Sources and patches: the repository's $recipe/build.sh recipe.
Link dependency: ios_system $revision, archive SHA256 $checksum.
Build source: ${GITHUB_SHA:-local}.

EOF
if [[ $product == node ]]; then
  printf '%s\n\n' 'Extract node-npm.zip into Resources/npm and node-fetch.zip into Resources/node-fetch.' >>"$dist/$product.release.md"
fi
