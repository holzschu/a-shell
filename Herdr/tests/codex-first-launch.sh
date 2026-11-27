#!/bin/bash
# Use a disposable a-Shell mini Simulator install with first-run screens completed.
# Quit at the host prompt and move aside any Codex home created on initial launch.
# The test refuses to replace existing homes and uses no credentials.
set -euo pipefail
if [[ $# -ne 3 ]]; then
	printf 'usage: %s SIMULATOR_UDID APP_BUNDLE_ID RECEIPT_DIR\n' "$0" >&2
	exit 2
fi
sim=$1
bundle=$2
out=$3
app=$(xcrun simctl get_app_container "$sim" "$bundle" app)
data=$(xcrun simctl get_app_container "$sim" "$bundle" data)
group_id=$(plutil -extract AppGroupIdentifier raw "$app/Info.plist")
group=$(xcrun simctl get_app_container "$sim" "$bundle" groups | awk -F '\t' -v id="$group_id" '$1 == id { print $2 }')
[[ -n $group && -d $group ]]
legacy="$data/Library/codex"
shared="$group/Library/codex"
for directory in "$legacy" "$shared"; do
	if [[ -e $directory || -L $directory ]]; then
		printf 'Refusing to replace existing Codex data; use a fresh disposable install.\n' >&2
		exit 2
	fi
done
mkdir -p "$out" "$legacy"
printf '%s\n' '# disposable first-launch migration fixture' > "$legacy/config.toml"
env -u SIMCTL_CHILD_CODEX_HOME xcrun simctl launch --terminate-running-process "$sim" "$bundle" > "$out/app-launch.log"
prepared_at_launch=0
for ((attempt=0; attempt<30; attempt++)); do
	if cmp -s "$legacy/config.toml" "$shared/config.toml"; then
		prepared_at_launch=1
		break
	fi
	sleep 0.2
done
# A migrated config is not a terminal-ready signal. Let the prompt settle before typing.
sleep 6
fixture=$(mktemp -d "$data/Documents/herdr-codex.XXXXXX")
cat > "$fixture/run.sh" <<'EOF'
printenv HERDR_PANE_ID > pane
printenv CODEX_HOME > codex-home
codex --version > version.out 2> version.err
printf '%s\n' "$?" > version.rc
EOF
axe type --layout us --udid "$sim" '  herdr' > "$out/herdr.input.log"
printf 'sleep 0.4\nkey 40\nsleep 4\n' | axe batch --udid "$sim" --stdin > "$out/launch.input.log"
printf 'key 40\nsleep 1.2\nkey 41\nsleep 2\n' | axe batch --udid "$sim" --stdin > "$out/onboarding.input.log"
# A leading space is harmless if the keyboard handoff drops the first key.
axe type --layout us --udid "$sim" "  cd \$HOME/Documents/${fixture##*/} && . ./run.sh" > "$out/codex.input.log"
printf 'sleep 0.4\nkey 40\n' | axe batch --udid "$sim" --stdin > "$out/return.input.log"
for ((attempt=0; attempt<120; attempt++)); do
	[[ ! -s $fixture/version.rc ]] || break
	sleep 0.1
done
if [[ ! -s $fixture/version.rc ]]; then
	printf 'Missing command receipts; inspect %s\n' "$fixture" >&2
	exit 2
fi
cp "$fixture/pane" "$fixture/codex-home" "$fixture/"version.{out,err,rc} "$out/"
grep -Eq '^w[0-9]+:p[0-9]+$' "$out/pane"
printf 'pane=%s status=%s stdout=%s stderr=%s\n' "$(head -1 "$out/pane")" "$(head -1 "$out/version.rc")" "$(head -1 "$out/version.out")" "$(head -1 "$out/version.err")"
if [[ $(head -1 "$out/version.rc") != 0 || -s $out/version.err ]] || ! grep -Eq '^codex-cli [0-9]' "$out/version.out"; then
	exit 1
fi
if ! cmp -s "$legacy/config.toml" "$shared/config.toml"; then
	printf 'The legacy Codex configuration was not preserved in the shared home.\n' >&2
	exit 1
fi
if [[ $prepared_at_launch != 1 ]]; then
	printf 'The host did not migrate the configuration before starting Herdr.\n' >&2
	exit 1
fi
if [[ $(<"$out/codex-home") != "$shared" ]]; then
	printf 'The pane did not inherit the shared CODEX_HOME.\n' >&2
	exit 1
fi
printf 'First Codex launch and legacy configuration migration: PASS\n'
