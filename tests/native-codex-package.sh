#!/usr/bin/env bash
# Package real thin Mach-O fixtures without fetching or compiling Codex.
set -euo pipefail
app=$(cd "$(dirname "$0")/.." && pwd -P)
work=$(mktemp -d "${TMPDIR:-/tmp}/native-codex-package.XXXXXX")
trap 'rm -r "$work"' EXIT
mkdir -p "$work/ci" "$work/.build/codex-slices"
cp "$app/ci/native-frameworks.sh" "$app/ci/audit-artifact.py" "$work/ci/"
input=$work/.build/codex-slices

slice() {
  local platform=$1 sdk=$2 triple=$3
  local framework=$work/fixtures/$platform/codex.framework
  mkdir -p "$framework"
  printf 'int codex_ios_main(void) { return 0; }\n' | xcrun --sdk "$sdk" clang \
    -target "$triple" -dynamiclib -x c - -Wl,-install_name,@rpath/codex.framework/codex \
    -o "$framework/codex"
  cat >"$framework/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>codex</string>
<key>CFBundleIdentifier</key><string>org.example.codex-fixture</string>
<key>CFBundlePackageType</key><string>FMWK</string>
</dict></plist>
PLIST
  tar -czf "$input/codex-$platform.tar.gz" -C "$work/fixtures" "$platform"
  (cd "$input"; shasum -a 256 "codex-$platform.tar.gz" >"codex-$platform.sha256")
}

slice device iphoneos arm64-apple-ios26.2
slice simulator iphonesimulator arm64-apple-ios26.2-simulator
slice simulator-x86_64 iphonesimulator x86_64-apple-ios26.2-simulator
bash "$work/ci/native-frameworks.sh" codex package
dist=$work/.build/dist
(cd "$dist"; shasum -a 256 -c codex.checksums.txt)
jq -e '[.binaries[].slices[] | [.platform, .arch, .minos]] | sort ==
  [["IOS", "arm64", "26.2"], ["IOSSIMULATOR", "arm64", "26.2"], ["IOSSIMULATOR", "x86_64", "26.2"]]' \
  "$dist/codex.audit.json" >/dev/null

# A damaged input must not overwrite the last successful package.
cp "$dist/codex.xcframework.zip" "$work/first.zip"
printf 'corrupt\n' >>"$input/codex-simulator-x86_64.tar.gz"
if bash "$work/ci/native-frameworks.sh" codex package >"$work/rejected.log" 2>&1; then
  echo 'Packager accepted a slice with the wrong checksum' >&2
  exit 1
fi
grep -Eq 'codex-simulator-x86_64.tar.gz: FAILED' "$work/rejected.log"
cmp "$dist/codex.xcframework.zip" "$work/first.zip"
(cd "$dist"; shasum -a 256 -c codex.checksums.txt)
echo 'PASS: Codex packaging joins three checked slices; corrupt input leaves the previous ZIP unchanged'
