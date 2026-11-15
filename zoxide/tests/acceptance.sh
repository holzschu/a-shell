#!/bin/sh
# Run with the app's Dash; retain this directory for independent host readback.
set -u
work=${1:?Empty absolute result directory required}
nonce=${2:?Fresh run nonce required}
case $work in /*) ;; *) exit 2 ;; esac
[ ! -e "$work" ] || exit 2
mkdir -p "$work/fixture/space café 東京" || exit 1
printf '%s\n' "$nonce" >"$work/run.nonce"

# Stop before dependent work if registration or the native command is missing.
zoxide --version >"$work/version.out" 2>"$work/version.err"
status=$?
printf '%s\n' "$status" >"$work/version.status"
[ "$status" -eq 0 ] || exit 1
printf 'zoxide 0.10.0\n' >"$work/version.expected"
# Use a-Shell's registered diff for exact text comparisons.
diff "$work/version.expected" "$work/version.out" || exit 1
[ ! -s "$work/version.err" ] || exit 1
export _ZO_DATA_DIR="$work/data"
export _ZO_EXCLUDE_DIRS=
export _ZO_ECHO=0 _ZO_RESOLVE_SYMLINKS=0 _ZO_MAXAGE=10000

zoxide query absent >"$work/missing.out" 2>"$work/missing.err"
status=$?
printf '%s\n' "$status" >"$work/missing.status"
[ "$status" -eq 1 ] && [ ! -s "$work/missing.out" ] || exit 1

set -- "$work/fixture/space café 東京"
i=1
while [ "$i" -lt 1000 ]; do
    path=$(printf '%s/fixture/directory %04d' "$work" "$i")
    mkdir -p "$path" || exit 1
    set -- "$@" "$path"
    if [ "$#" -eq 50 ]; then
        zoxide add "$@" >"$work/add-$i.out" 2>"$work/add-$i.err"
        status=$?
        printf '%s\n' "$status" >"$work/add-$i.status"
        [ "$status" -eq 0 ] && [ ! -s "$work/add-$i.err" ] || exit 1
        set --
    fi
    i=$((i + 1))
done

zoxide query --list >"$work/list.out" 2>"$work/list.err"
status=$?
printf '%s\n' "$status" >"$work/list.status"
[ "$status" -eq 0 ] && [ ! -s "$work/list.err" ] || exit 1
[ "$(wc -l <"$work/list.out")" -eq 1000 ] || exit 1
zoxide query café >"$work/unicode.out" 2>"$work/unicode.err"
status=$?
printf '%s\n' "$status" >"$work/unicode.status"
[ "$status" -eq 0 ] && [ ! -s "$work/unicode.err" ] || exit 1
printf '%s\n' "$work/fixture/space café 東京" >"$work/unicode.expected"
diff "$work/unicode.expected" "$work/unicode.out" || exit 1

zoxide add --score 100 "$work/fixture/directory 0007" >"$work/rank-add.out" 2>"$work/rank-add.err"
status=$?
printf '%s\n' "$status" >"$work/rank-add.status"
[ "$status" -eq 0 ] || exit 1
zoxide query directory >"$work/ranked.out" 2>"$work/ranked.err"
status=$?
printf '%s\n' "$status" >"$work/ranked.status"
[ "$status" -eq 0 ] || exit 1
printf '%s\n' "$work/fixture/directory 0007" >"$work/ranked.expected"
diff "$work/ranked.expected" "$work/ranked.out" || exit 1
zoxide remove "$work/fixture/directory 0007" >"$work/remove.out" 2>"$work/remove.err"
status=$?
printf '%s\n' "$status" >"$work/remove.status"
[ "$status" -eq 0 ] || exit 1
zoxide query 0007 >"$work/removed.out" 2>"$work/removed.err"
status=$?
printf '%s\n' "$status" >"$work/removed.status"
[ "$status" -eq 1 ] && [ ! -s "$work/removed.out" ] || exit 1

mkdir -p "$work/corrupt" || exit 1
printf 'broken database\n' >"$work/corrupt/db.zo"
cp "$work/corrupt/db.zo" "$work/corrupt.expected" || exit 1
export _ZO_DATA_DIR="$work/corrupt"
zoxide query absent >"$work/corrupt.out" 2>"$work/corrupt.err"
status=$?
printf '%s\n' "$status" >"$work/corrupt.status"
[ "$status" -eq 1 ] && [ ! -s "$work/corrupt.out" ] && [ -s "$work/corrupt.err" ] || exit 1
diff "$work/corrupt.expected" "$work/corrupt/db.zo" || exit 1
export _ZO_DATA_DIR="$work/data"

zoxide --invalid-option >"$work/invalid.out" 2>"$work/invalid.err"
status=$?
printf '%s\n' "$status" >"$work/invalid.status"
[ "$status" -eq 2 ] && [ ! -s "$work/invalid.out" ] || exit 1
zoxide query --interactive >"$work/interactive.out" 2>"$work/interactive.err"
status=$?
printf '%s\n' "$status" >"$work/interactive.status"
[ "$status" -eq 1 ] && [ ! -s "$work/interactive.out" ] || exit 1

zoxide init posix --hook prompt >"$work/init.sh" 2>"$work/init.err"
status=$?
printf '%s\n' "$status" >"$work/init.status"
[ "$status" -eq 0 ] && [ ! -s "$work/init.err" ] || exit 1
# This is the real shell capture/init path, including query status and builtin cd.
# shellcheck source=/dev/null
. "$work/init.sh"
cd "$work/fixture" || exit 1
z café >"$work/posix-z.out" 2>"$work/posix-z.err"
status=$?
printf '%s\n' "$status" >"$work/posix-z.status"
[ "$status" -eq 0 ] || exit 1
pwd >"$work/posix-cwd.out"
diff "$work/unicode.expected" "$work/posix-cwd.out" || exit 1
echo ZOXIDE_STREAMS_OK >"$work/ordinary.out"
zoxide query --list >"$work/after.out" 2>"$work/after.err"
status=$?
printf '%s\n' "$status" >"$work/after.status"
[ "$status" -eq 0 ] || exit 1
printf '%s\n' "$nonce" >"$work/complete.nonce"
echo 'zoxide app command: PASS'
