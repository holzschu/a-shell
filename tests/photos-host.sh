#!/bin/sh
# Compile the real command with host substitutes for the external iOS APIs.
# Usage: sh tests/photos-host.sh [ExtraCommands.swift]
set -eu
source=${1:-a-Shell/ExtraCommands.swift}
scratch=$(mktemp -d)
trap 'chmod -R u+w "$scratch"; rm -rf "$scratch"' EXIT HUP INT TERM
cat tests/photos-host.swift > "$scratch/main.swift"
awk '/^private struct PhotoCacheEntry:/{copy=1} /^\/\/ hide the on-screen keyboard/{copy=0} copy' "$source" >> "$scratch/main.swift"
grep -q '^public func photosMain' "$scratch/main.swift" || { printf 'FAIL source slice markers not found\n'; exit 1; }
cat >> "$scratch/main.swift" <<'SWIFT'
DispatchQueue.global().async {
    let args = CommandLine.arguments.map { strdup($0) }
    let status = args.withUnsafeBufferPointer { buffer in
        photosMain(argc: Int32(args.count), argv: UnsafeMutablePointer(mutating: buffer.baseAddress))
    }
    exit(status)
}
dispatchMain()
SWIFT
swiftc -swift-version 5 -module-cache-path "$scratch/modules" "$scratch/main.swift" -o "$scratch/photos"
export PHOTOS_TEST_HOME="$scratch/home"
mkdir -p "$PHOTOS_TEST_HOME"
"$scratch/photos" --help > "$scratch/help"
grep -q -- '--select' "$scratch/help" || { printf 'FAIL help omits --select\n'; exit 1; }
printf 'PASS help advertises --select\n'
PHOTOS_TEST_ACCESS=full "$scratch/photos" --select > "$scratch/out" 2> "$scratch/err" && { printf 'FAIL --select succeeded with full access\n'; exit 1; }
grep -q 'limited' "$scratch/err" || { printf 'FAIL full-access error omits limited requirement\n'; exit 1; }
test ! -s "$scratch/out" || { printf 'FAIL --select printed a path with full access\n'; exit 1; }
printf 'PASS full access explains limited requirement\n'
PHOTOS_TEST_ACCESS=limited "$scratch/photos" > "$scratch/root"
test -s "$scratch/root" || { printf 'FAIL photos did not print a path\n'; exit 1; }
cache="$PHOTOS_TEST_HOME/Photos"
cat "$cache"/*/* | sort > "$scratch/before"
test "$(tr -d '\n' < "$scratch/before")" = AB || { printf 'FAIL initial cache does not contain A and B\n'; exit 1; }
retained=$(grep -l '^B$' "$cache"/*/*) || { printf 'FAIL initial cache omits B\n'; exit 1; }
stat -f '%i %m' "$retained" > "$scratch/retained-before"
PHOTOS_TEST_ACCESS=limited "$scratch/photos" --select > "$scratch/root"
test -s "$scratch/root" || { printf 'FAIL --select did not print a path\n'; exit 1; }
test -f "$PHOTOS_TEST_HOME/picker-finished" || { printf 'FAIL picker did not finish\n'; exit 1; }
test "$(cat "$PHOTOS_TEST_HOME/fetched")" = changed || { printf 'FAIL assets fetched before picker finished\n'; exit 1; }
printf 'PASS picker finishes before refreshed fetch\n'
cat "$cache"/*/* | sort > "$scratch/after"
test "$(tr -d '\n' < "$scratch/after")" = BC || { printf 'FAIL changed cache does not contain B and C\n'; exit 1; }
stat -f '%i %m' "$retained" > "$scratch/retained-after"
cmp "$scratch/retained-before" "$scratch/retained-after" || { printf 'FAIL unchanged B was rewritten\n'; exit 1; }
printf 'PASS removes A, adds C, preserves B\n'
