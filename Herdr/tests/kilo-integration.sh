#!/bin/bash
# Start at the mini prompt on a disposable portrait Simulator with Herdr
# onboarding completed and the software keyboard hidden. Install the editor
# with `pkg install kilo`. Leave the Kilo Code config directory absent.
set -euo pipefail
if [ "$#" -ne 3 ]; then
	echo "usage: $0 SIMULATOR_UDID APP_BUNDLE_ID RECEIPT_DIR" >&2
	exit 2
fi
sim=$1
bundle=$2
out=$3
command -v axe >/dev/null
command -v uv >/dev/null
data=$(xcrun simctl get_app_container "$sim" "$bundle" data)
config="$data/.config/kilo"
test ! -L "$data/.config"
test ! -e "$config" && test ! -L "$config" || exit 2
mkdir -p "$out"
receipts=$(mktemp -d "$data/Documents/herdr-kilo.XXXXXX")
created_config=false
trap 'if $created_config; then rmdir "$config"; fi' EXIT

# Pace terminal input as in three-panes.sh. Both commands run in the same
# a-Shell window. Dash resolves its PATH without launching the editor.
type_command() {
	local character escaped
	while IFS= read -r -n 1 character; do
		escaped=${character//\\/\\\\}
		escaped=${escaped//\"/\\\"}
		printf 'type "%s"\nsleep 0.13\n' "$escaped"
	done < <(printf '%s' "$1")
	printf 'sleep 0.35\nkey 40\nsleep 2\n'
}

status=0
for fixture in without-config with-config; do
	expected='not found'
	if [ "$fixture" = with-config ]; then
		mkdir -p "$data/.config"
		mkdir "$config"
		created_config=true
		expected=available
	fi
	case_out="$out/$fixture"
	mkdir -p "$case_out"
	path_file="$receipts/$fixture"
	# HOME expands in the launched app, not in the harness.
	# shellcheck disable=SC2016
	printf -v command 'dash -c "command -v kilo" > "$HOME/Documents/%s/%s"' "${receipts##*/}" "$fixture"
	type_command "$command" | axe batch --udid "$sim" --stdin >"$case_out/path-input.log"
	if ! grep -Fxq "$data/Documents/bin/kilo" "$path_file"; then
		echo "The running a-Shell did not resolve the Kilo editor on PATH ($fixture)" >&2
		exit 2
	fi
	cp "$path_file" "$case_out/kilo-path.txt"

	{
		type_command herdr
		printf 'key-combo --modifiers 224 --key 5\nsleep 0.35\nkey 22\nsleep 0.5\nkey-sequence --keycodes 43,43,43,43 --delay 0.2\nsleep 1\n'
	} | axe batch --udid "$sim" --stdin >"$case_out/input.log"
	xcrun simctl io "$sim" screenshot "$case_out/integrations.png" # ios-proof: layout
	uv run --quiet --with ocrmac python -I -c '
import sys
from ocrmac import ocrmac
for text, _, _ in ocrmac.OCR(sys.argv[1], recognition_level="accurate").recognize():
    print(text.lower().strip())
' "$case_out/integrations.png" >"$case_out/integrations.txt"
	if ! grep -Fq 'agent integrations' "$case_out/integrations.txt"; then
		echo "Integrations panel did not open; see $case_out/integrations.txt" >&2
		exit 2
	fi
	if ! actual=$(awk '
		/^[^[:alnum:]]*kilo +(not found|available)$/ { sub(/^[^[:alnum:]]*kilo +/, ""); print; found = 1; exit }
		/^[^[:alnum:]]*kilo$/ { getline; if ($0 ~ /^(not found|available)$/) { print; found = 1; exit } }
		END { exit !found }
	' "$case_out/integrations.txt"); then
		echo "Could not read the Kilo row; see $case_out/integrations.txt" >&2
		exit 2
	fi
	printf '%s: kilo %s (expected %s)\n' "$fixture" "$actual" "$expected"
	if [ "$actual" != "$expected" ]; then status=1; fi

	printf 'key 41\nsleep 0.5\nkey-combo --modifiers 224 --key 5\nsleep 0.35\nkey 20\nsleep 2\n' |
		axe batch --udid "$sim" --stdin >"$case_out/return-to-shell.log"
done
exit "$status"
