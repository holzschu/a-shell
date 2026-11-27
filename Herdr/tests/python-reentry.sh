#!/bin/bash
# Start with a disposable a-Shell mini Simulator focused in an onboarded Herdr pane.
set -euo pipefail
if [[ $# -ne 3 ]]; then
	printf 'usage: %s SIMULATOR_UDID APP_BUNDLE_ID RECEIPT_DIR\n' "$0" >&2
	exit 2
fi
sim=$1
bundle=$2
out=$3
data=$(xcrun simctl get_app_container "$sim" "$bundle" data)
fixture=$(mktemp -d "$data/Documents/herdr-python.XXXXXX")
mkdir -p "$out"
printf '%s\n' 'print("python-reentry")' > "$fixture/probe.py"
cat > "$fixture/run.sh" <<'EOF'
printenv HERDR_PANE_ID > pane
for call in 1 2 3 4; do
	python3 probe.py > "$call.out" 2> "$call.err"
	printf '%s\n' "$?" > "$call.rc"
done
EOF
printf 'key-combo --modifiers 224 --key 5\nsleep 0.4\ntype v\nsleep 1.5\n' |
	axe batch --udid "$sim" --stdin > "$out/split.input.log"
axe type --layout us --udid "$sim" "cd \$HOME/Documents/${fixture##*/} && . ./run.sh" > "$out/launch.input.log"
printf 'sleep 0.4\nkey 40\n' | axe batch --udid "$sim" --stdin > "$out/return.input.log"
for ((attempt=0; attempt<120; attempt++)); do
	[[ ! -s $fixture/4.rc ]] || break
	sleep 0.1
done
if [[ ! -s $fixture/4.rc ]]; then
	printf 'Missing command receipts; inspect %s\n' "$fixture" >&2
	exit 2
fi
cp "$fixture/pane" "$fixture/"{1,2,3,4}.{out,err,rc} "$out/"
grep -Eq '^w[0-9]+:p[0-9]+$' "$out/pane"
printf 'pane=%s\n' "$(head -1 "$out/pane")"
status=0
for call in 1 2 3 4; do
	rc=$(head -1 "$out/$call.rc")
	printf 'call %s: status=%s, stdout=%s, stderr=%s\n' "$call" "$rc" "$(head -1 "$out/$call.out")" "$(head -1 "$out/$call.err")"
	if [[ $rc != 0 || -s $out/$call.err ]] || ! printf 'python-reentry\n' | cmp -s - "$out/$call.out"; then status=1; fi
done
exit "$status"
