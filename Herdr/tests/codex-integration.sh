#!/bin/bash
# Use a disposable a-Shell mini Simulator app with Codex and Herdr. Start at
# the host prompt with the software keyboard hidden and Herdr onboarding done.
# Pass the expected Codex home (the shared default, or the explicit override
# used at app launch). It must not contain an existing Herdr hook installation.
set -euo pipefail
if [[ $# -ne 4 ]]; then
	printf 'usage: %s SIMULATOR_UDID APP_BUNDLE_ID EXPECTED_HOME RECEIPT_DIR\n' "$0" >&2
	exit 2
fi
sim=$1
bundle=$2
expected=$3
out=$4
data=$(xcrun simctl get_app_container "$sim" "$bundle" data)
app=$(xcrun simctl get_app_container "$sim" "$bundle" app)
group_id=$(plutil -extract AppGroupIdentifier raw "$app/Info.plist")
group=$(xcrun simctl get_app_container "$sim" "$bundle" groups | awk -F '\t' -v id="$group_id" '$1 == id { print $2 }')
if [[ -z $group || $expected != "$group/"* && $expected != "$data/"* || -e $expected/herdr-agent-state.sh ]]; then
	printf 'Use an unused Codex home inside this disposable install.\n' >&2
	exit 2
fi
mkdir -p "$out"
shared_hooks="$group/Library/codex/hooks.json"
shared_hooks_state() {
	if [[ -e $shared_hooks || -L $shared_hooks ]]; then
		shasum -a 256 "$shared_hooks"
	else
		printf 'absent\n'
	fi
}
if [[ $expected != "$group/Library/codex" ]]; then
	shared_hooks_state > "$out/shared-hooks.before"
fi
axe type --layout us --udid "$sim" '  herdr' > "$out/type.log"
printf 'sleep 0.4\nkey 40\nsleep 3\nkey-combo --modifiers 224 --key 5\nsleep 0.4\nkey 22\nsleep 0.5\nkey-sequence --keycodes 43,43,43,43 --delay 0.2\nsleep 1\nkey 40\nsleep 1\n' |
	axe batch --udid "$sim" --stdin > "$out/menu.log"
if [[ ! -x $expected/herdr-agent-state.sh || ! -f $expected/hooks.json ]] ||
	! jq -e --arg hook "$expected/herdr-agent-state.sh" '[.. | objects | .command? | strings | contains($hook)] | any' "$expected/hooks.json" >/dev/null; then
	printf 'Agent Integrations did not install the Codex hook in the expected home.\n' >&2
	exit 1
fi
if [[ -e $data/.codex/herdr-agent-state.sh || -e $data/Documents/.codex/herdr-agent-state.sh ]]; then
	printf 'Agent Integrations wrote a hook under the app HOME fallback.\n' >&2
	exit 1
fi
if [[ $expected != "$group/Library/codex" ]]; then
	shared_hooks_state > "$out/shared-hooks.after"
	if ! cmp -s "$out/shared-hooks.before" "$out/shared-hooks.after"; then
		printf 'The override run changed the shared Codex hooks.\n' >&2
		exit 1
	fi
fi
cp "$expected/hooks.json" "$out/hooks.json"
printf 'Agent Integrations installed the Codex hook in the expected home: PASS\n'
