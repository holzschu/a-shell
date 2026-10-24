#!/bin/bash
# Exercise an installed disposable Simulator app through its public terminal UI.
set -euo pipefail
if [ "$#" -ne 3 ]; then
	echo "usage: $0 SIMULATOR_UDID APP_BUNDLE_ID URL_SCHEME" >&2
	exit 2
fi
sim=$1
bundle=$2
scheme=$3
command -v axe >/dev/null
command -v jq >/dev/null
data=$(xcrun simctl get_app_container "$sim" "$bundle" data)
app=$(xcrun simctl get_app_container "$sim" "$bundle" app)
receipts=$(mktemp -d "$data/Documents/herdr-ui.XXXXXX")
steps=$(mktemp)
trap 'rm -f "$steps"' EXIT

# HID bursts can overrun Simulator input. Preserve characters and modifier order.
type_command() {
	local character escaped
	while IFS= read -r -n 1 character; do
		escaped=${character//\\/\\\\}
		escaped=${escaped//\"/\\\"}
		printf 'type "%s"\nsleep 0.08\n' "$escaped"
	done < <(printf '%s' "$1")
	printf 'sleep 0.5\nkey 40\nsleep 2\n'
}
wait_output() {
	local attempt
	for ((attempt = 0; attempt < 200; attempt++)); do
		if [ -s "$1" ]; then return 0; fi
		sleep 0.1
	done
	echo "missing or empty receipt: $1" >&2
	return 1
}

# Start at a fresh shell, with default Herdr keybindings and tab-name prompts.
xcrun simctl launch "$sim" "$bundle" >/dev/null
xcrun simctl openurl "$sim" "$scheme:herdr"
printf 'sleep 3\ntap -x 130 -y 260\nsleep 1\n' >"$steps"
axe batch --udid "$sim" --file "$steps" >/dev/null
pids=()
for pane in a b c; do
	: >"$steps"
	if [ "$pane" != a ]; then
		# Ctrl+B,c opens a name dialog; Return creates the tab, not a shell command.
		printf 'key-combo --modifiers 224 --key 5\nsleep 0.4\ntype c\nsleep 0.5\n' >>"$steps"
		type_command "pane-$pane" >>"$steps"
	fi
	printf -v command 'printenv ASHELL_WORKER_PID > %q' "$receipts/$pane"
	type_command "$command" >>"$steps"
	axe batch --udid "$sim" --file "$steps" >/dev/null
	wait_output "$receipts/$pane"
	pid=$(cat "$receipts/$pane")
	case "$pid" in
	'' | *[!0-9]*)
		echo "invalid worker PID for pane $pane" >&2
		exit 1
		;;
	esac
	pids+=("$pid")
done
if [ "${pids[0]}" = "${pids[1]}" ] || [ "${pids[0]}" = "${pids[2]}" ] || [ "${pids[1]}" = "${pids[2]}" ]; then
	echo "panes share a worker PID" >&2
	exit 1
fi
# Simulator workers are Mac processes. Verify all belong to this installed app
# and remain alive together after all three commands have produced output.
for pid in "${pids[@]}"; do
	worker=$(ps -p "$pid" -o comm=)
	case "$worker" in
	"$app"/Extensions/ShellWorker?.appex/ShellWorker?) ;;
	*)
		echo "PID $pid is not a live worker of the tested app" >&2
		exit 1
		;;
	esac
done
printf 'three concurrent workers: %s %s %s\n' "${pids[@]}"

# Leave the real shell usable and prove same-process command re-entry.
printf 'key-combo --modifiers 224 --key 5\nsleep 0.4\ntype q\nsleep 3\n' >"$steps"
axe batch --udid "$sim" --file "$steps" >/dev/null
printf -v command 'herdr --version > %q' "$receipts/reentry"
encoded=$(jq -nr --arg command "$command" '$command | @uri')
xcrun simctl openurl "$sim" "$scheme:$encoded"
wait_output "$receipts/reentry"
printf 'herdr 0.9.3\n' | cmp - "$receipts/reentry"
printf 'detach and same-process re-entry: PASS\nreceipts: %s\n' "$receipts"
