#!/usr/bin/env bash
# Exercise the exported command entry, not a replacement zoxide executable.
set -euo pipefail
command=${1:?Host command fixture required}
work=${2:?Empty absolute result directory required}
[[ $work == /* && ! -e $work ]]
mkdir -p "$work/fixture/space café 東京"
export _ZO_DATA_DIR=$work/data
export _ZO_ECHO=0 _ZO_RESOLVE_SYMLINKS=0 _ZO_EXCLUDE_DIRS='' _ZO_MAXAGE=10000
"$command" zoxide --version >"$work/version.out"
printf 'zoxide 0.10.0\n' | cmp - "$work/version.out"
"$command" zoxide add "$work/fixture/space café 東京"
"$command" zoxide query café >"$work/query.out"
printf '%s\n' "$work/fixture/space café 東京" | cmp - "$work/query.out"

# Native z must change the caller's cwd, including the very next ordinary command.
"$command" z café :: pwd >"$work/jump.out" 2>"$work/jump.err"
cmp "$work/query.out" "$work/jump.out"
printf 'status=0\n' | cmp - "$work/jump.err"

# The native root jump must use the selected database, even beside a matching directory.
"$command" cd "$work/fixture" :: setenv _ZO_DATA_DIR "$work/native-missing" :: \
    z café :: pwd >"$work/root-missing.out" 2>"$work/root-missing.err"
printf '%s\n' "$work/fixture" | cmp - "$work/root-missing.out"
grep -Fx 'zoxide: no match found' "$work/root-missing.err" >/dev/null
grep -Fx 'status=1' "$work/root-missing.err" >/dev/null

# z - uses the same previous-directory state as the native cd command.
"$command" cd "$work/fixture" :: cd "$work/fixture/space café 東京" :: \
    z - :: pwd >"$work/previous.out" 2>"$work/previous.err"
printf '%s\n' "$work/fixture" | cmp - "$work/previous.out"
printf 'status=0\nstatus=0\nstatus=0\n' | cmp - "$work/previous.err"

# A 1,000-directory database uses upstream ordering, filtering and persistence.
paths=("$work/fixture/space café 東京")
for ((i = 1; i < 1000; i++)); do
    path=$(printf '%s/fixture/directory %04d' "$work" "$i")
    mkdir -p "$path"
    paths+=("$path")
done
"$command" zoxide add "${paths[@]}"
"$command" zoxide query --list >"$work/list.out"
[[ $(wc -l <"$work/list.out" | tr -d ' ') == 1000 ]]
printf '%s\n' "${paths[@]}" | LC_ALL=C sort >"$work/expected.out"
LC_ALL=C sort "$work/list.out" | cmp - "$work/expected.out"
"$command" zoxide add --score 100 "$work/fixture/directory 0007"
"$command" zoxide query directory >"$work/ranked.out"
printf '%s\n' "$work/fixture/directory 0007" | cmp - "$work/ranked.out"
"$command" zoxide remove "$work/fixture/directory 0007"
status=0
"$command" zoxide query 0007 >"$work/removed.out" 2>"$work/removed.err" || status=$?
[[ $status == 1 && ! -s $work/removed.out ]]
grep -F 'no match found' "$work/removed.err" >/dev/null

status=0
"$command" zoxide --invalid-option >"$work/invalid.out" 2>"$work/invalid.err" || status=$?
[[ $status == 2 && ! -s $work/invalid.out ]]
grep -F 'unexpected argument' "$work/invalid.err" >/dev/null

status=0
_ZO_DATA_DIR="$work/missing" "$command" zoxide query nowhere >"$work/missing.out" 2>"$work/missing.err" || status=$?
[[ $status == 1 && ! -s $work/missing.out ]]
grep -F 'no match found' "$work/missing.err" >/dev/null
mkdir -p "$work/corrupt"
printf 'broken database\n' >"$work/corrupt/db.zo"
cp "$work/corrupt/db.zo" "$work/corrupt.before"
status=0
_ZO_DATA_DIR="$work/corrupt" "$command" zoxide query nowhere >"$work/corrupt.out" 2>"$work/corrupt.err" || status=$?
[[ $status == 1 && ! -s $work/corrupt.out && -s $work/corrupt.err ]]
cmp "$work/corrupt.before" "$work/corrupt/db.zo"

# A changed environment in the same app process must select a different database.
"$command" zoxide query café :: setenv _ZO_DATA_DIR "$work/second" :: \
    zoxide add "$work/fixture/directory 0042" :: zoxide query --list >"$work/reentry.out" 2>"$work/reentry.err"
printf '%s\n' "$work/fixture/space café 東京" "$work/fixture/directory 0042" | cmp - "$work/reentry.out"
printf 'status=0\nstatus=0\nstatus=0\n' | cmp - "$work/reentry.err"
"$command" zoxide init posix --hook prompt >"$work/init.sh"
dash -n "$work/init.sh"
if grep -F '__zoxide_zi' "$work/init.sh"; then exit 1; fi

for args in 'query --interactive' 'edit' 'import atuin'; do
    status=0
    # Intentional word splitting: these are fixed CLI arguments above.
    # shellcheck disable=SC2086
    "$command" zoxide $args >"$work/unsupported.out" 2>"$work/unsupported.err" || status=$?
    [[ $status == 1 && ! -s $work/unsupported.out && -s $work/unsupported.err ]]
done

# Re-enter after parser/database/unsupported failures without terminating the host.
"$command" zoxide query --interactive :: zoxide --version :: \
    setenv _ZO_DATA_DIR "$work/corrupt" :: zoxide query nowhere :: \
    setenv _ZO_DATA_DIR "$work/data" :: zoxide query café >"$work/recovery.out" 2>"$work/recovery.err"
printf 'zoxide 0.10.0\n%s\n' "$work/fixture/space café 東京" | cmp - "$work/recovery.out"

HOST_DATA_DIR="$work/scoped" HOST_OUTPUT="$work/scoped.out" HOST_ERRORS="$work/scoped.err" \
    "$command" zoxide add "$work/fixture/space café 東京" :: zoxide query café :: \
    zoxide --invalid-option :: pwd >"$work/ordinary.out" 2>"$work/scoped.status"
printf '%s\n' "$work/fixture/space café 東京" | cmp - "$work/scoped.out"
pwd -P >"$work/ordinary.expected"
cmp "$work/ordinary.expected" "$work/ordinary.out"
grep -F 'unexpected argument' "$work/scoped.err" >/dev/null
[[ -s $work/scoped/db.zo ]]

# ios_system's unsuccessful cd must not be reported as a successful visit.
HOST_DENY_CD=1 "$command" z café :: pwd >"$work/denied.out" 2>"$work/denied.err"
cmp "$work/ordinary.expected" "$work/denied.out"
grep -F 'could not change directory' "$work/denied.err" >/dev/null
grep -F 'status=1' "$work/denied.err" >/dev/null

calls=(fds ::)
for ((i = 0; i < 20; i++)); do calls+=(zoxide query café ::); done
calls+=(fds)
"$command" "${calls[@]}" >"$work/lifetime.out" 2>"$work/lifetime.err"
[[ $(head -1 "$work/lifetime.out") == "$(tail -1 "$work/lifetime.out")" ]]

ln -s "$work/fixture/space café 東京" "$work/logical-link"
"$command" z "$work/logical-link" :: zoxide query logical-link >"$work/symlink.out" 2>"$work/symlink.err"
printf '%s\n' "$work/logical-link" | cmp - "$work/symlink.out"
status=0
"$command" z "$work/logical-link" :: z logical-link >"$work/current-link.out" 2>"$work/current-link.err" || status=$?
[[ $status == 1 && ! -s $work/current-link.out ]]
grep -F 'you are already in the only match' "$work/current-link.err" >/dev/null
status=0
"$command" cd "$work/logical-link/" :: z logical-link >"$work/trailing.out" 2>"$work/trailing.err" || status=$?
[[ $status == 1 && ! -s $work/trailing.out ]]
grep -F 'you are already in the only match' "$work/trailing.err" >/dev/null
mkdir -p "$work/fixture/space café 東京/child"
"$command" z "$work/logical-link" :: z child :: zoxide query child >"$work/relative-link.out" 2>"$work/relative-link.err"
printf '%s\n' "$work/logical-link/child" | cmp - "$work/relative-link.out"
_ZO_RESOLVE_SYMLINKS=1 _ZO_ECHO=1 "$command" z "$work/logical-link" >"$work/physical-echo.out" 2>"$work/physical-echo.err"
printf '%s\n' "$work/fixture/space café 東京" | cmp - "$work/physical-echo.out"

HOST_OUTPUT_ERROR=EPIPE "$command" zoxide query --list >"$work/pipe.out" 2>"$work/pipe.err"
status=0
HOST_OUTPUT_ERROR=EIO "$command" zoxide query --list >"$work/io.out" 2>"$work/io.err" || status=$?
[[ $status == 1 ]]
status=0
HOST_ERRORS_ERROR=EIO "$command" zoxide --invalid-option >"$work/flush.out" 2>"$work/flush.err" || status=$?
[[ $status == 2 ]]
status=0
"$command" z - >"$work/previous-unset.out" 2>"$work/previous-unset.err" || status=$?
[[ $status == 1 && ! -s $work/previous-unset.out ]]
grep -F 'could not change directory' "$work/previous-unset.err" >/dev/null
status=0
RUST_BACKTRACE=1 RUST_LIB_BACKTRACE=1 "$command" zoxide query unfindable-backtrace >"$work/backtrace.out" 2>"$work/backtrace.err" || status=$?
[[ $status == 1 && ! -s $work/backtrace.out ]]
printf 'zoxide: no match found\n' | cmp - "$work/backtrace.err"
mkdir "$work/deleted-cwd"
"$command" z "$work/deleted-cwd" :: rmdir "$work/deleted-cwd" :: \
    setenv _ZO_RESOLVE_SYMLINKS 1 :: z 0042 :: pwd >"$work/deleted.out" 2>"$work/deleted.err"
printf '%s\n' "$work/fixture/directory 0042" | cmp - "$work/deleted.out"
printf 'status=0\nstatus=0\nstatus=0\nstatus=0\n' | cmp - "$work/deleted.err"
echo 'zoxide host command: PASS'
