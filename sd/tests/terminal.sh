#!/bin/sh
# Run in the app's real terminal; read guest results back independently.
cd "${1:?Disposable result directory required}" || exit 1
printf '%s\n' started >sd-started.out
sd --version >sd-version.out 2>sd-version.err
status=$?
echo "$status" >sd-version.status
[ "$status" -eq 0 ] || exit "$status"
cat sd-version.out
printf 'cat cat\n' >sd-file.txt
printf 'catfish\n' >sd-second.txt
sd cat dog sd-file.txt sd-second.txt >sd-files.out 2>sd-files.err
echo $? >sd-files.status
cat sd-file.txt sd-second.txt
printf 'a.b axb a.b\n' >sd-fixed.txt
# shellcheck disable=SC2016 # The replacement is a literal dollar string.
sd -F 'a.b' '$1' sd-fixed.txt >sd-fixed.out 2>sd-fixed.err
echo $? >sd-fixed.status
cat sd-fixed.txt
printf 'name-42 name-7\n' >sd-captures.txt
# shellcheck disable=SC2016 # sd expands captures; Dash must not expand them.
sd '([a-z]+)-([0-9]+)' '$2:$1' sd-captures.txt >sd-captures.out 2>sd-captures.err
echo $? >sd-captures.status
cat sd-captures.txt
printf 'red red\n' | sd red blue >sd-pipe.out 2>sd-pipe.err
echo $? >sd-pipe.status
cat sd-pipe.out
sd '[' x sd-file.txt >sd-invalid.out 2>sd-invalid.err
echo $? >sd-invalid.status
sd --not-an-option >sd-option.out 2>sd-option.err
echo $? >sd-option.status
printf 'caf\303\251 cat\n' >sd-unicode.txt
sd cat kitten sd-unicode.txt >sd-unicode.out 2>sd-unicode.err
echo $? >sd-unicode.status
printf 'red red\n' >sd-preview.txt
sd -p red blue sd-preview.txt >sd-preview.out 2>sd-preview.err
echo $? >sd-preview.status
sd cat dog sd-does-not-exist.txt >sd-missing.out 2>sd-missing.err
echo $? >sd-missing.status
sd --version >sd-recovery.out 2>sd-recovery.err
echo $? >sd-recovery.status
printf '%s\n' ordinary-command-returned >sd-after.out
echo SD_PROBE_COMPLETE >sd-complete.out
echo SD_PROBE_COMPLETE
