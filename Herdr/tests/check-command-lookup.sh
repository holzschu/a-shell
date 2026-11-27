#!/bin/bash
# Test bare-name resolution through a ready, focused Herdr pane in a disposable Simulator.
# FIXTURES contains bin/pi, bin/claude.wasm and bin/omp (see command-lookup-pane.sh).
set -euo pipefail
if [ "$#" -ne 3 ]; then
	echo "usage: $0 SIMULATOR_UDID APP_BUNDLE_ID FIXTURES" >&2
	exit 2
fi
sim=$1
bundle=$2
fixtures=$3
here=$(cd "$(dirname "$0")" && pwd)
data=$(xcrun simctl get_app_container "$sim" "$bundle" data)
app=$(xcrun simctl get_app_container "$sim" "$bundle" app)
[ "$(stat -f '%OLp %z' "$app/bin/codex")" = '644 0' ]
root=$(mktemp -d "$data/Documents/herdr-lookup.XXXXXX")
printf 'Receipts: %s\n' "$root"
cp -Rp "$fixtures/bin" "$root/bin"
mkdir "$root/empty" "$root/codex-home"
{
	printf 'LOOKUP_FIXTURE=%q\nLOOKUP_APP=%q\n' "$root" "$app"
	cat "$here/command-lookup-pane.sh"
} > "$root/run.sh"
steps=$(mktemp)
trap 'rm -f "$steps"' EXIT
# Pace HID input as in three-panes.sh. Only mktemp's ASCII basename is typed.
while IFS= read -r -n 1 character; do
	printf 'type "%s"\nsleep 0.08\n' "$character"
done < <(printf '. ~/Documents/%s/run.sh' "${root##*/}") > "$steps"
printf 'sleep 0.5\nkey 40\n' >> "$steps"
axe batch --udid "$sim" --file "$steps"
for ((i=0;i<150;i++)); do
	[ ! -s "$root/complete.txt" ] || break
	sleep 0.2
done
if ! read -r pane pid < "$root/complete.txt"; then
	echo 'missing pane completion receipt' >&2
	exit 1
fi
[[ $pane =~ ^w[0-9]+:p[0-9]+$ && $pid =~ ^[0-9]+$ ]]
[[ $(ps -p "$pid" -o comm=) == "$app/Extensions/"ShellWorker?.appex/ShellWorker? ]]
printf 'Pane %s, worker %s\n' "$pane" "$pid"
failed=0
for name in worker-marker marker-0644 native-only wasm-with-suffix wasm-bare pkg python; do
	status=$(<"$root/$name.status")
	printf '%s exit=%s stdout=%s stderr=%s\n' "$name" "$status" "$(tr '\n' ' ' < "$root/$name.stdout")" "$(tr '\n' ' ' < "$root/$name.stderr")"
	[ "$status" = 0 ] || failed=1
	case $name in
		worker-marker|marker-0644|native-only) grep -Eq '^codex-cli [0-9]' "$root/$name.stdout" || failed=1 ;;
		python) grep -qx PYTHON_FIXTURE_OK "$root/$name.stdout" || failed=1 ;;
		*) printf '1\n2\n3\n' | cmp -s - "$root/$name.stdout" || failed=1 ;;
	esac
done
exit "$failed"
