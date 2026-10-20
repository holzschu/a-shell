#!/bin/sh
# Invoke from the real a-Shell terminal using one native Dash invocation.
set -u
work=${1:?Absolute result directory required}
cd "$work" || exit 2
rg --version >version.out 2>version.err
command_status=$?
printf '%s\n' "$command_status" >version.status
[ "$command_status" -eq 0 ] || exit 1
mkdir -p project
printf 'ordinary line\nNEEDLE caf\303\251\n' >project/input.txt
cd project || exit 2
printf '%s\n' explicit-file >../phase
rg -n --no-heading --color never NEEDLE input.txt >../explicit.out 2>../explicit.err
command_status=$?
printf '%s\n' "$command_status" >../explicit.status
[ "$command_status" -eq 0 ] || exit 1
printf '2:NEEDLE caf\303\251\n' >../explicit.expected
diff -u ../explicit.expected ../explicit.out >../explicit.diff || exit 1
printf '%s\n' default-search >../phase
rg -n --no-heading --color never NEEDLE >../default.out 2>../default.err
command_status=$?
printf '%s\n' "$command_status" >../default.status
[ "$command_status" -eq 0 ] || exit 1
printf 'input.txt:2:NEEDLE caf\303\251\n' >../default.expected
diff -u ../default.expected ../default.out >../default.diff || exit 1
run() {
    name=$1
    expected_status=$2
    shift 2
    "$@" >"../$name.out" 2>"../$name.err"
    actual_status=$?
    printf '%s\n' "$actual_status" >"../$name.status"
    [ "$actual_status" -eq "$expected_status" ] || exit 1
}
printf '%s\n' recursive-ignore-glob >../phase
mkdir -p nested
printf 'NEEDLE notes\n' >nested/readme.md
printf 'NEEDLE second\n' >nested/second.txt
printf 'NEEDLE ignored\n' >ignored.txt
printf 'ignored.txt\n' >.ignore
run recursive 0 rg -n --no-heading --color never --sort path NEEDLE .
printf './input.txt:2:NEEDLE caf\303\251\n./nested/readme.md:1:NEEDLE notes\n./nested/second.txt:1:NEEDLE second\n' >../recursive.expected
diff -u ../recursive.expected ../recursive.out >../recursive.diff || exit 1
[ ! -s ../recursive.err ] || exit 1
run glob 0 rg -n --no-heading --color never -g '*.md' NEEDLE .
printf './nested/readme.md:1:NEEDLE notes\n' >../glob.expected
diff -u ../glob.expected ../glob.out >../glob.diff || exit 1
[ ! -s ../glob.err ] || exit 1
printf '%s\n' statuses-stdin-parallel-reentry >../phase
run no-match 1 rg ABSENT input.txt
[ ! -s ../no-match.out ] && [ ! -s ../no-match.err ] || exit 1
run missing 2 rg NEEDLE missing.txt
[ ! -s ../missing.out ] || exit 1
grep -F missing.txt ../missing.err >/dev/null || exit 1
run invalid 2 rg '[' input.txt
[ ! -s ../invalid.out ] || exit 1
grep -F 'regex parse error' ../invalid.err >/dev/null || exit 1
# Redirect the native command directly; Dash function redirects do not reach ios_system.
rg -n --color never NEEDLE <input.txt >../stdin.out 2>../stdin.err
command_status=$?
printf '%s\n' "$command_status" >../stdin.status
[ "$command_status" -eq 0 ] || exit 1
diff -u ../explicit.expected ../stdin.out >../stdin.diff || exit 1
[ ! -s ../stdin.err ] || exit 1
printf 'ordinary\nNEEDLE pipe\n' | rg -n --color never NEEDLE >../pipe.out 2>../pipe.err
command_status=$?
printf '%s\n' "$command_status" >../pipe.status
[ "$command_status" -eq 0 ] || exit 1
printf '2:NEEDLE pipe\n' >../pipe.expected
diff -u ../pipe.expected ../pipe.out >../pipe.diff || exit 1
[ ! -s ../pipe.err ] || exit 1
run parallel 0 rg -n --no-heading --color never -j 2 NEEDLE .
LC_ALL=C sort ../parallel.out >../parallel.sorted
diff -u ../recursive.expected ../parallel.sorted >../parallel.diff || exit 1
[ ! -s ../parallel.err ] || exit 1
run reentry 0 rg -n --no-heading --color never NEEDLE input.txt
diff -u ../explicit.expected ../reentry.out >../reentry.diff || exit 1
[ ! -s ../reentry.err ] || exit 1
run version-again 0 rg --version
diff -u ../version.out ../version-again.out >../version-again.diff || exit 1
[ ! -s ../version-again.err ] || exit 1
printf '%s\n' ORDINARY_RETURNED >../ordinary.out
printf '%s\n' complete >../phase
printf '%s\n' RG_TERMINAL_CONTRACT_COMPLETE
