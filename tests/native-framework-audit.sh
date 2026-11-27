#!/usr/bin/env bash
# Exercise the artifact gate with real iOS objects, without compiling a command.
set -euo pipefail
app=$(cd "$(dirname "$0")/.." && pwd -P)
work=$(mktemp -d "${TMPDIR:-/tmp}/native-framework-audit.XXXXXX")
trap 'rm -rf "$work"' EXIT

archive() {
  local sdk=$1 triple=$2 output=$3
  mkdir -p "$output"
  printf 'int fixture(void) { return 0; }\n' | xcrun --sdk "$sdk" clang \
    -target "$triple" -x c -c - -o "$output/fixture.o"
  xcrun libtool -static -o "$output/libfixture.a" "$output/fixture.o"
}
archive iphoneos arm64-apple-ios15.0 "$work/device"
archive iphonesimulator arm64-apple-ios15.0-simulator "$work/arm64"
archive iphonesimulator x86_64-apple-ios15.0-simulator "$work/x86_64"
mkdir "$work/simulator"
xcrun lipo -create "$work/arm64/libfixture.a" "$work/x86_64/libfixture.a" \
  -output "$work/simulator/libfixture.a"
product=$work/fixture.xcframework
xcodebuild -create-xcframework -library "$work/device/libfixture.a" \
  -library "$work/simulator/libfixture.a" -output "$product"
zip=$work/fixture.xcframework.zip
ditto -c -k --norsrc --keepParent "$product" "$zip"
checksum=$(shasum -a 256 <"$zip" | cut -d ' ' -f1)
uv run "$app/ci/audit-artifact.py" "$zip" --sha256 "$checksum" --max-minos 15.0 >"$work/audit.json"
jq -e '[.binaries[].slices[] | [.platform, .arch, .minos]] | sort ==
  [["IOS", "arm64", "15.0"], ["IOSSIMULATOR", "arm64", "15.0"], ["IOSSIMULATOR", "x86_64", "15.0"]]' \
  "$work/audit.json" >/dev/null

# Keep metadata and architectures intact; only an archive member has the wrong platform.
xcrun lipo -create "$work/device/libfixture.a" "$work/x86_64/libfixture.a" \
  -output "$product/ios-arm64_x86_64-simulator/libfixture.a"
if uv run "$app/ci/audit-artifact.py" "$product" --max-minos 15.0 >"$work/rejected.log" 2>&1; then
  echo 'Audit accepted a device object in a Simulator archive' >&2
  exit 1
fi
grep -F 'incompatible member IOS' "$work/rejected.log"
cp "$work/simulator/libfixture.a" "$product/ios-arm64_x86_64-simulator/libfixture.a"

# One valid member must not mask another member that lacks platform metadata.
xcrun vtool -remove-build-version ios -output "$work/device/untagged.o" "$work/device/fixture.o"
xcrun ar -r "$product/ios-arm64/libfixture.a" "$work/device/untagged.o"
if uv run "$app/ci/audit-artifact.py" "$product" --max-minos 15.0 >"$work/rejected.log" 2>&1; then
  echo 'Audit accepted an untagged member alongside a valid device member' >&2
  exit 1
fi
grep -F 'untagged.o:' "$work/rejected.log"
echo 'PASS: static XCFramework ZIP accepted; wrong-platform and untagged members rejected'
