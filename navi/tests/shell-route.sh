#!/bin/sh
# Run with native Dash inside a-Shell, using an existing absolute work directory.
set -u
work=${1:?Supply an existing absolute test directory}
case $work in
/*) ;;
*)
	printf '%s\n' 'Test directory must be absolute' >&2
	exit 2
	;;
esac
cd "$work" || exit 2
mkdir -p builtin tight spaced dependent || exit 2
cat >builtin/demo.cheat <<'CHEAT'
% shell-route

# Print builtin
printf 'NAVI_PRINTF_OK\n'

# Return seven
exit 7
CHEAT
cat >tight/demo.cheat <<'CHEAT'
% shell-route

# Suggested value
echo '<message>'

$ message:echo SUGGESTION_OK --- --prevent-extra --filter SUGGESTION_OK
CHEAT
cat >spaced/demo.cheat <<'CHEAT'
% shell-route

# Suggested value
echo '<message>'

$ message: echo SUGGESTION_OK --- --prevent-extra --filter SUGGESTION_OK
CHEAT
cat >dependent/demo.cheat <<'CHEAT'
% shell-route

# Dependent value
echo '<first> <second>'

$ first: echo FIRST --- --prevent-extra --filter FIRST
$ second: echo "$first"_SECOND --- --prevent-extra --filter FIRST_SECOND
CHEAT
navi --path "$work/builtin" --query 'Print builtin' --best-match >"$work/printf.out" 2>"$work/printf.err"
printf '%s\n' "$?" >"$work/printf.status"
navi --path "$work/builtin" --query 'Return seven' --best-match >"$work/exit.out" 2>"$work/exit.err"
printf '%s\n' "$?" >"$work/exit.status"
for phase in tight spaced; do
	navi --path "$work/$phase" --query 'Suggested value' --best-match >"$work/$phase.out" 2>"$work/$phase.err"
	printf '%s\n' "$?" >"$work/$phase.status"
done
navi --path "$work/dependent" --query 'Dependent value' --best-match >"$work/dependent.out" 2>"$work/dependent.err"
printf '%s\n' "$?" >"$work/dependent.status"
IFS= read -r output <"$work/printf.out" || exit 1
IFS= read -r status <"$work/printf.status" || exit 1
test "$output" = NAVI_PRINTF_OK && test "$status" = 0 || exit 1
IFS= read -r status <"$work/exit.status" || exit 1
test "$status" = 7 && test ! -s "$work/exit.out" || exit 1
for phase in tight spaced; do
	IFS= read -r output <"$work/$phase.out" || exit 1
	IFS= read -r status <"$work/$phase.status" || exit 1
	test "$output" = SUGGESTION_OK && test "$status" = 0 || exit 1
done
IFS= read -r output <"$work/dependent.out" || exit 1
IFS= read -r status <"$work/dependent.status" || exit 1
test "$output" = 'FIRST FIRST_SECOND' && test "$status" = 0 || exit 1
test -z "${first-}" && test -z "${second-}" || exit 1
for phase in printf exit tight spaced dependent; do
	test ! -s "$work/$phase.err" || exit 1
done
printf '%s\n' 'Navi shell: builtin, exit status, suggestion whitespace and dependent variables PASS'
