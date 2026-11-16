#!/usr/bin/env bash
# Verify app result files after readback, including the native root-prompt jump.
set -euo pipefail
work=${1:?Result directory required}
nonce=${2:?Expected fresh nonce required}
[[ $(cat "$work/run.nonce") == "$nonce" && $(cat "$work/complete.nonce") == "$nonce" ]]
for label in version list unicode rank-add ranked remove init posix-z after; do
    [[ $(cat "$work/$label.status") == 0 && ! -s $work/$label.err ]]
done
for ((i = 49; i < 1000; i += 50)); do
    [[ $(cat "$work/add-$i.status") == 0 && ! -s $work/add-$i.err && ! -s $work/add-$i.out ]]
done
for label in missing removed corrupt unsupported; do
    [[ $(cat "$work/$label.status") == 1 && ! -s $work/$label.out && -s $work/$label.err ]]
done
[[ $(cat "$work/invalid.status") == 2 && ! -s $work/invalid.out ]]
grep -F 'no match found' "$work/missing.err" >/dev/null
grep -F 'no match found' "$work/removed.err" >/dev/null
grep -F 'unexpected argument' "$work/invalid.err" >/dev/null
grep -F 'this port supports add, query, remove and init' "$work/unsupported.err" >/dev/null
printf 'zoxide 0.10.0\n' | cmp - "$work/version.out"
[[ $(wc -l <"$work/list.out" | tr -d ' ') == 1000 ]]
[[ $(wc -l <"$work/after.out" | tr -d ' ') == 999 ]]
cmp "$work/unicode.expected" "$work/unicode.out"
cmp "$work/ranked.expected" "$work/ranked.out"
cmp "$work/corrupt.expected" "$work/corrupt/db.zo"
cmp "$work/unicode.expected" "$work/posix-cwd.out"
printf 'ZOXIDE_STREAMS_OK\n' | cmp - "$work/ordinary.out"
cmp "$work/unicode.expected" "$work/root-cwd.out"
[[ ! -s $work/root-missing.out ]]
grep -Fx 'zoxide: no match found' "$work/root-missing.err" >/dev/null
destination=$(cat "$work/unicode.expected")
printf '%s\n' "${destination%/*}" | cmp - "$work/root-missing-cwd.out"
printf 'ZOXIDE_ROOT_STREAMS_OK\n' | cmp - "$work/root-next.out"
[[ ! -s $work/root-z.out && ! -s $work/root-z.err ]]
echo 'zoxide app readback: PASS'
