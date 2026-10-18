#!/bin/sh
# Run inside one native a-Shell Dash invocation; fzf must stay in one app process.
set -eu
work=${1:?Pass an empty test directory}
mkdir -p "$work"
cd "$work"
printf 'ab\na,b\na/b\nza,b\nxa|b\na:b\nxxab\na b\n' >candidates.txt
fzf --scheme=default --filter=ab <candidates.txt >before.out
[ -s before.out ]
fzf --scheme=path --filter=ab <candidates.txt >path.out
fzf --scheme=default --filter=ab <candidates.txt >after.out
[ "$(cat before.out)" = "$(cat after.out)" ]
printf 'Same-process scheme reset PASS\n'
