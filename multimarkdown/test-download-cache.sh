#!/bin/bash
# Exercise the build entry point with both downloads left truncated.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/multimarkdown-downloads.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir "$work/downloads"
printf 'truncated source\n' > "$work/downloads/source.tar.gz"
printf 'truncated runtime\n' > "$work/downloads/ios_system.xcframework.zip"
bash "$root/scripts/build-multimarkdown.sh" "$work"
(cd "$work/dist" && shasum -a 256 -c checksums.txt)
printf '%s\n' 'PASS: MultiMarkdown rebuilt after both cached downloads were truncated'
