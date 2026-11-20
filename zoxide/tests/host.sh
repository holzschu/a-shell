#!/usr/bin/env bash
# Exercise the exported command entry, not a replacement zoxide executable.
# Darwin/APFS only; the absolute result path must have no symlinked components.
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

# Native a-Shell input is NFD; queries, learning and exclusion must still agree with NFC paths.
nfd_keyword=$'cafe\314\201'
nfd_path="$work/fixture/space "$'cafe\314\201 東京'
"$command" zoxide query "$nfd_keyword" >"$work/nfd-query.out"
cmp "$work/query.out" "$work/nfd-query.out"
"$command" z "$nfd_keyword" :: pwd >"$work/nfd-jump.out" 2>"$work/nfd-jump.err"
cmp "$work/query.out" "$work/nfd-jump.out"
printf 'status=0\n' | cmp - "$work/nfd-jump.err"
"$command" cd "$nfd_path" :: zoxide query --list >"$work/nfd-learn.out" 2>"$work/nfd-learn.err"
cmp "$work/query.out" "$work/nfd-learn.out"
printf 'status=0\n' | cmp - "$work/nfd-learn.err"
status=0
"$command" cd "$nfd_path" :: z café >"$work/nfd-current.out" 2>"$work/nfd-current.err" || status=$?
[[ $status == 1 && ! -s $work/nfd-current.out ]]
grep -F 'you are already in the only match' "$work/nfd-current.err" >/dev/null
mkdir -p "$work/nfd-exclude-data"
cp "$work/data/db.zo" "$work/nfd-exclude-data/db.zo"
_ZO_DATA_DIR="$work/nfd-exclude-data" _ZO_EXCLUDE_DIRS="$nfd_path" "$command" zoxide query café :: \
    printenv _ZO_EXCLUDE_DIRS >"$work/nfd-exclude.out" 2>"$work/nfd-exclude.err"
printf '%s\n' "$nfd_path" | cmp - "$work/nfd-exclude.out"
printf 'zoxide: no match found\nstatus=1\n' | cmp - "$work/nfd-exclude.err"
nfd_resolved="$work/fixture/"$'resolved-cafe\314\201'
mkdir -p "$nfd_resolved"
ln -s "$nfd_resolved" "$work/resolved-link"
_ZO_DATA_DIR="$work/nfd-resolved-data" _ZO_RESOLVE_SYMLINKS=1 "$command" zoxide add "$work/resolved-link" :: \
    zoxide query --list >"$work/nfd-resolved.out" 2>"$work/nfd-resolved.err"
printf '%s\n' "$work/fixture/resolved-café" | cmp - "$work/nfd-resolved.out"
printf 'status=0\n' | cmp - "$work/nfd-resolved.err"
status=0
HOST_NO_PWD=1 _ZO_DATA_DIR="$work/nfd-resolved-data" "$command" cd "$nfd_resolved" :: \
    z resolved-café >"$work/nfd-no-pwd.out" 2>"$work/nfd-no-pwd.err" || status=$?
[[ $status == 1 && ! -s $work/nfd-no-pwd.out ]]
grep -F 'you are already in the only match' "$work/nfd-no-pwd.err" >/dev/null
status=0
"$command" zoxide query $'\377' >"$work/invalid-utf8.out" 2>"$work/invalid-utf8.err" || status=$?
[[ $status == 2 && ! -s $work/invalid-utf8.out ]]
grep -F 'UTF-8' "$work/invalid-utf8.err" >/dev/null

# Load an existing v3 database with both spellings; preserve their combined rank.
write_u64() {
    local value=$1 octal byte
    for ((byte = 0; byte < 8; byte++)); do
        printf -v octal '%03o' "$((value & 255))"
        printf '%b' "\\$octal"
        value=$((value >> 8))
    done
}
mkdir -p "$work/nfd-legacy-data"
legacy_now=$(date +%s)
canonical_path="$work/fixture/space café 東京"
{
    # bincode v3: u32 version, u64 count, then (UTF-8 string, f64 rank, u64 epoch).
    printf '\003\000\000\000'
    write_u64 2
    write_u64 "$(LC_ALL=C printf '%s' "$nfd_path" | wc -c)"
    printf '%s' "$nfd_path"
    printf '\000\000\000\000\000\000\360\077' # rank 1.0
    write_u64 "$((legacy_now - 7200))"
    write_u64 "$(LC_ALL=C printf '%s' "$canonical_path" | wc -c)"
    printf '%s' "$canonical_path"
    printf '\000\000\000\000\000\000\000\100' # rank 2.0
    write_u64 "$legacy_now"
} >"$work/nfd-legacy-data/db.zo"
_ZO_DATA_DIR="$work/nfd-legacy-data" "$command" zoxide query --list --score "$nfd_keyword" \
    >"$work/nfd-legacy.out" 2>"$work/nfd-legacy.err"
printf '%6.1f %s\n' 12 "$canonical_path" | cmp - "$work/nfd-legacy.out"
[[ ! -s $work/nfd-legacy.err ]]
_ZO_DATA_DIR="$work/nfd-legacy-data" "$command" cd "$nfd_path" :: zoxide query --list --score \
    >"$work/nfd-legacy-learn.out" 2>"$work/nfd-legacy-learn.err"
printf '%6.1f %s\n' 16 "$canonical_path" | cmp - "$work/nfd-legacy-learn.out"
printf 'status=0\n' | cmp - "$work/nfd-legacy-learn.err"

# Native z must change the caller's cwd, including the very next ordinary command.
"$command" z café :: pwd >"$work/jump.out" 2>"$work/jump.err"
cmp "$work/query.out" "$work/jump.out"
printf 'status=0\n' | cmp - "$work/jump.err"

# The native root jump must use the selected database, even beside a matching directory.
_ZO_DATA_DIR="$work/native-root-before" "$command" cd "$work/fixture" :: setenv _ZO_DATA_DIR "$work/native-missing" :: \
    z café :: pwd >"$work/root-missing.out" 2>"$work/root-missing.err"
printf '%s\n' "$work/fixture" | cmp - "$work/root-missing.out"
grep -Fx 'zoxide: no match found' "$work/root-missing.err" >/dev/null
grep -Fx 'status=1' "$work/root-missing.err" >/dev/null

# z - uses the same previous-directory state as the native cd command.
_ZO_DATA_DIR="$work/previous-data" "$command" cd "$work/fixture" :: cd "$work/fixture/space café 東京" :: \
    z - :: pwd >"$work/previous.out" 2>"$work/previous.err"
printf '%s\n' "$work/fixture" | cmp - "$work/previous.out"
printf 'status=0\nstatus=0\nstatus=0\n' | cmp - "$work/previous.err"

# Ordinary native cd learns a successful visit, but never a failed destination.
_ZO_DATA_DIR="$work/cd-data" "$command" cd "$work/fixture/space café 東京" :: \
    zoxide query café >"$work/cd.out" 2>"$work/cd.err"
cmp "$work/query.out" "$work/cd.out"
printf 'status=0\n' | cmp - "$work/cd.err"
_ZO_DATA_DIR="$work/cd-data" "$command" cd "$work/fixture/not-created" :: \
    zoxide query --list >"$work/cd-failed.out" 2>"$work/cd-failed.err"
cmp "$work/query.out" "$work/cd-failed.out"
grep -Fx 'cd: could not change directory' "$work/cd-failed.err" >/dev/null
mkdir -p "$work/cd-corrupt"
printf 'broken database\n' >"$work/cd-corrupt/db.zo"
cp "$work/cd-corrupt/db.zo" "$work/cd-corrupt.before"
_ZO_DATA_DIR="$work/cd-corrupt" "$command" cd "$work/fixture" :: pwd \
    >"$work/cd-corrupt.out" 2>"$work/cd-corrupt.err"
printf '%s\n' "$work/fixture" | cmp - "$work/cd-corrupt.out"
printf 'status=0\n' | cmp - "$work/cd-corrupt.err"
cmp "$work/cd-corrupt.before" "$work/cd-corrupt/db.zo"

# Keyword fallback is opt-in, and an existing relative path always wins.
_ZO_CD=1 _ZO_DATA_DIR="$work/cd-data" "$command" cd café :: pwd \
    >"$work/cd-keyword.out" 2>"$work/cd-keyword.err"
cmp "$work/query.out" "$work/cd-keyword.out"
printf 'status=0\n' | cmp - "$work/cd-keyword.err"
mkdir -p "$work/fixture/café"
_ZO_CD=1 _ZO_DATA_DIR="$work/cd-data" "$command" cd "$work/fixture" :: cd café :: pwd \
    >"$work/cd-existing.out" 2>"$work/cd-existing.err"
printf '%s\n' "$work/fixture/café" | cmp - "$work/cd-existing.out"
printf 'status=0\nstatus=0\n' | cmp - "$work/cd-existing.err"
_ZO_CD=0 _ZO_DATA_DIR="$work/cd-data" "$command" cd café :: pwd \
    >"$work/cd-disabled.out" 2>"$work/cd-disabled.err"
pwd -P >"$work/cd-disabled.expected"
cmp "$work/cd-disabled.expected" "$work/cd-disabled.out"
grep -Fx 'cd: could not change directory' "$work/cd-disabled.err" >/dev/null

# Run the real fzf CLI at the external ios_system boundary, without a test UI.
_ZO_FZF_OPTS='--filter=café' "$command" zoxide query --interactive \
    >"$work/interactive.out" 2>"$work/interactive.err"
cmp "$work/query.out" "$work/interactive.out"
[[ ! -s $work/interactive.err ]]
_ZO_FZF_OPTS='--filter=café' "$command" zi café :: pwd \
    >"$work/zi.out" 2>"$work/zi.err"
cmp "$work/query.out" "$work/zi.out"
printf 'status=0\n' | cmp - "$work/zi.err"
# Ordinary zi includes cwd; Space-Tab's command excludes it before selection.
mkdir -p "$work/completion-current" "$work/completion-alternate"
_ZO_DATA_DIR="$work/completion-data" _ZO_FZF_OPTS='--filter=completion' \
    "$command" cd "$work/completion-current" :: zi completion :: pwd \
    >"$work/zi-current.out" 2>"$work/zi-current.err"
printf '%s\n' "$work/completion-current" | cmp - "$work/zi-current.out"
printf 'status=0\nstatus=0\n' | cmp - "$work/zi-current.err"
_ZO_DATA_DIR="$work/completion-data" _ZO_FZF_OPTS='--filter=completion' \
    "$command" zoxide add "$work/completion-alternate" :: cd "$work/completion-current" :: \
    __zoxide_zi_complete completion :: pwd >"$work/zi-exclude.out" 2>"$work/zi-exclude.err"
printf '%s\n' "$work/completion-alternate" | cmp - "$work/zi-exclude.out"
printf 'status=0\nstatus=0\nstatus=0\n' | cmp - "$work/zi-exclude.err"
# Every ordinary zi argument remains a keyword, including completion-like names.
mkdir -p "$work/literal--exclude-current"
_ZO_DATA_DIR="$work/zi-literal-data" _ZO_FZF_OPTS='--filter=literal' \
    "$command" cd "$work/literal--exclude-current" :: zi --exclude-current :: pwd \
    >"$work/zi-literal.out" 2>"$work/zi-literal.err"
printf '%s\n' "$work/literal--exclude-current" | cmp - "$work/zi-literal.out"
printf 'status=0\nstatus=0\n' | cmp - "$work/zi-literal.err"
FZF_DEFAULT_OPTS='--filter=parent-only' _ZO_FZF_OPTS='--filter=café' \
    "$command" zoxide query --interactive :: printenv FZF_DEFAULT_OPTS \
    >"$work/fzf-env.out" 2>"$work/fzf-env.err"
printf '%s\n--filter=parent-only\n' "$work/fixture/space café 東京" | cmp - "$work/fzf-env.out"
printf 'status=0\n' | cmp - "$work/fzf-env.err"
_ZO_FZF_OPTS='--filter=no-such-zoxide-result' "$command" zoxide query --interactive :: \
    zoxide --version >"$work/fzf-reentry.out" 2>"$work/fzf-reentry.err"
cmp "$work/version.out" "$work/fzf-reentry.out"
printf 'zoxide: no match found\nstatus=1\n' | cmp - "$work/fzf-reentry.err"

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
grep -F '__zoxide_zi' "$work/init.sh" >/dev/null

for args in 'edit' 'import atuin'; do
    status=0
    # Intentional word splitting: these are fixed CLI arguments above.
    # shellcheck disable=SC2086
    "$command" zoxide $args >"$work/unsupported.out" 2>"$work/unsupported.err" || status=$?
    [[ $status == 1 && ! -s $work/unsupported.out && -s $work/unsupported.err ]]
done

# Re-enter after parser/database/unsupported failures without terminating the host.
"$command" zoxide edit :: zoxide --version :: \
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
# Previous-directory navigation retains the logical link in its database visit.
status=0
_ZO_DATA_DIR="$work/previous-link-data" "$command" cd "$work/logical-link" :: \
    cd "$work/fixture" :: z - :: zoxide query logical-link :: zoxide query café \
    >"$work/previous-link.out" 2>"$work/previous-link.err" || status=$?
[[ $status == 1 ]]
printf '%s\n' "$work/logical-link" | cmp - "$work/previous-link.out"
grep -Fx 'zoxide: no match found' "$work/previous-link.err" >/dev/null
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
