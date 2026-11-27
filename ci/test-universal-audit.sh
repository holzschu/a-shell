#!/bin/bash
# Reject a Simulator framework missing either architecture, even when its plist agrees.
set -euo pipefail
archive=$(cd "$(dirname "${1:?usage: bash ci/test-universal-audit.sh PACKAGE.zip}")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/xcframework-audit.XXXXXX")
trap 'rm -rf "$work"' EXIT

failed=0
for remaining in arm64 x86_64; do
    fixture="$work/$remaining"
    mkdir "$fixture"
    unzip -q "$archive" -d "$fixture"
    xcframeworks=("$fixture/"*.xcframework)
    xcframework=${xcframeworks[0]}
    plist="$xcframework/Info.plist"
    index=0
    if [[ $(plutil -extract AvailableLibraries.0.SupportedPlatformVariant raw -o - "$plist" 2>/dev/null) != simulator ]]; then
        index=1
    fi
    library="AvailableLibraries.$index"
    test "$(plutil -extract "$library.SupportedPlatformVariant" raw -o - "$plist")" = simulator
    path=$(plutil -extract "$library.LibraryIdentifier" raw -o - "$plist")
    framework=$(plutil -extract "$library.LibraryPath" raw -o - "$plist")
    product="$xcframework/$path/$framework"
    binary="$product/$(plutil -extract CFBundleExecutable raw -o - "$product/Info.plist")"
    xcrun lipo -thin "$remaining" "$binary" -output "$binary.thin"
    mv "$binary.thin" "$binary"
    plutil -replace "$library.SupportedArchitectures" -json "[\"$remaining\"]" "$plist"
    zip="$work/simulator-$remaining-only.zip"
    (cd "$fixture" && zip -qry "$zip" "${xcframework##*/}")
    checksum=$(shasum -a 256 "$zip" | awk '{print $1}')
    status=0
    uv run --script "$here/audit-artifact.py" "$zip" --sha256 "$checksum" \
        > "$work/audit.json" 2> "$work/audit.log" || status=$?
    if [[ $status != 1 ]] ||
        ! tr '\n' ' ' < "$work/audit.log" |
            grep -Eq 'unexpected[[:space:]]+slice[[:space:]]+architectures|Require[[:space:]]+arm64[[:space:]]+iOS[[:space:]]+and[[:space:]]+arm64/x86_64[[:space:]]+Simulator'; then
        tail -20 "$work/audit.log" >&2
        printf 'FAIL: expected rejection of Simulator %s-only ZIP (audit exit %s)\n' "$remaining" "$status" >&2
        failed=1
    else
        printf 'PASS: rejected Simulator %s-only ZIP with matching plist\n' "$remaining"
    fi
done

fixture="$work/executable"
mkdir "$fixture"
unzip -q "$archive" -d "$fixture"
xcframeworks=("$fixture/"*.xcframework)
xcframework=${xcframeworks[0]}
plist="$xcframework/Info.plist"
index=0
if [[ $(plutil -extract AvailableLibraries.0.SupportedPlatformVariant raw -o - "$plist" 2>/dev/null) == simulator ]]; then
    index=1
fi
library="AvailableLibraries.$index"
path=$(plutil -extract "$library.LibraryIdentifier" raw -o - "$plist")
framework=$(plutil -extract "$library.LibraryPath" raw -o - "$plist")
product="$xcframework/$path/$framework"
binary="$product/$(plutil -extract CFBundleExecutable raw -o - "$product/Info.plist")"
sdk=$(xcrun --sdk iphoneos --show-sdk-path)
printf 'int main(void) { return 0; }\n' |
    xcrun --sdk iphoneos clang -target arm64-apple-ios14.0 -isysroot "$sdk" -x c - -o "$binary"
xcrun otool -arch arm64 -hv "$binary" | grep -Fw EXECUTE
zip="$work/executable-in-framework.zip"
(cd "$fixture" && zip -qry "$zip" "${xcframework##*/}")
checksum=$(shasum -a 256 "$zip" | awk '{print $1}')
status=0
uv run --script "$here/audit-artifact.py" "$zip" --sha256 "$checksum" \
    > "$work/audit.json" 2> "$work/audit.log" || status=$?
if [[ $status != 1 ]] || ! tr '\n' ' ' < "$work/audit.log" | grep -Eq 'expected[[:space:]]+MH_DYLIB'; then
    tail -20 "$work/audit.log" >&2
    printf 'FAIL: expected rejection of MH_EXECUTE framework member (audit exit %s)\n' "$status" >&2
    failed=1
else
    printf '%s\n' 'PASS: rejected MH_EXECUTE framework member'
fi
exit "$failed"
