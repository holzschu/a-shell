#!/bin/bash
set -euo pipefail

if [[ $# != 3 ]]; then
    echo "Usage: $0 APP_SOURCE IOS_SYSTEM_XCFRAMEWORK device|simulator" >&2
    exit 2
fi
source=$1
bundle=$2
case "$3" in
    device)
        sdk=iphoneos
        slice=ios-arm64
        variant=
        archs=(arm64)
        ;;
    simulator)
        sdk=iphonesimulator
        slice=ios-arm64_x86_64-simulator
        variant=-simulator
        archs=(arm64 x86_64)
        ;;
    *) echo "Expected device or simulator, got $3" >&2; exit 2 ;;
esac
workers="$source/ShellWorkers"
deployment=$(awk '$1 == "IPHONEOS_DEPLOYMENT_TARGET" && $2 == "=" {print $3}' "$workers/Worker.xcconfig")
if [[ -z "$deployment" ]]; then
    echo "IPHONEOS_DEPLOYMENT_TARGET is missing from $workers/Worker.xcconfig" >&2
    exit 1
fi
binary="$bundle/$slice/ios_system.framework/ios_system"
if [[ ! -f "$binary" ]]; then
    echo "ios_system binary is missing from the selected slice: $binary" >&2
    exit 1
fi
sysroot=$(xcrun --sdk "$sdk" --show-sdk-path)

# Link the real Objective-C worker sources so missing declarations and dylib
# exports both fail without maintaining a separate ios_system symbol list.
for arch in "${archs[@]}"; do
    echo "Checking shell worker ABI against ios_system ($sdk/$arch)"
    xcrun --sdk "$sdk" clang -target "${arch}-apple-ios${deployment}${variant}" \
        -isysroot "$sysroot" -fobjc-arc -fapplication-extension \
        -Werror=implicit-function-declaration -dynamiclib \
        -F "$bundle/$slice" -framework ios_system -framework Foundation \
        "$workers/NativePane.m" "$workers/Worker.m" -o /dev/null
done
