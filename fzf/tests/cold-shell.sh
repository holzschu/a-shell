#!/bin/sh
# Run through native Dash in a fresh app process, before any Go command.
# Supply an empty absolute work directory and the installed app bundle path.
set -u
work=${1:?Supply an existing absolute test directory}
bundle=${2:?Supply the installed absolute app bundle directory}
case $work:$bundle in
/*:/*) ;;
*)
  printf '%s\n' 'Both directories must be absolute' >&2
  exit 2
  ;;
esac
# A fresh installed candidate must not already contain the misplaced output.
test ! -e "$bundle/fzf-cold.status" || exit 1
cd "$work" || exit 2
pwd -P >expected.cwd
printf 'alpha\nbeta\n' >input.txt
fzf --filter '^beta$' <input.txt >fzf-cold.out 2>fzf-cold.err
printf '%s\n' "$?" >fzf-cold.status
pwd -P >"$work/fzf-cold.cwd"
printf 'after\n' >fzf-cold.after
# Use shell builtins: cmp is unavailable in the stock a-Shell command map.
# Resolve assertions absolutely so a misplaced relative write cannot pass.
IFS= read -r selection <"$work/fzf-cold.out" || exit 1
IFS= read -r status <"$work/fzf-cold.status" || exit 1
IFS= read -r before <"$work/expected.cwd" || exit 1
IFS= read -r after <"$work/fzf-cold.cwd" || exit 1
IFS= read -r marker <"$work/fzf-cold.after" || exit 1
test "$selection" = beta && test "$status" = 0 || exit 1
test "$before" = "$after" && test "$marker" = after || exit 1
test ! -s "$work/fzf-cold.err" || exit 1
test ! -e "$bundle/fzf-cold.status" || exit 1
printf '%s\n' 'Cold fzf: selection, status, cwd and next command PASS'
