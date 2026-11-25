#!/bin/bash
# Run against an installed a-Shell build on a fresh portrait iPhone Simulator.
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
command -v python3 >/dev/null
data=$(xcrun simctl get_app_container "$sim" "$bundle" data)
receipts=$(mktemp -d "$data/Documents/terminal-links.XXXXXX")
mkdir "$receipts/www"
printf '<!doctype html><title>Terminal link fixture</title>Terminal link fixture\n' >"$receipts/www/plain.html"
cp "$receipts/www/plain.html" "$receipts/www/osc8.html"
printf '<!doctype html><title>In-app browser fixture</title>In-app browser fixture\n' >"$receipts/www/internal.html"
python3 -u -m http.server 0 --bind 127.0.0.1 --directory "$receipts/www" >"$receipts/http.log" 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null || true' EXIT

wait_for() {
    local message=$1
    shift
    local attempt
    for ((attempt = 0; attempt < 50; attempt++)); do
        if "$@"; then return 0; fi
        sleep 0.2
    done
    echo "$message (receipts: $receipts)" >&2
    return 1
}
server_port() {
    grep -q '^Serving HTTP .* port ' "$receipts/http.log"
}
wait_for 'Loopback server did not start' server_port
port=$(awk '/^Serving HTTP /{print $6; exit}' "$receipts/http.log")

focus_shell() {
    xcrun simctl launch "$sim" "$bundle" >/dev/null
}
run_command() {
    local encoded
    focus_shell
    encoded=$(jq -nr --arg command "$1" '$command | @uri')
    xcrun simctl openurl "$sim" "$scheme:$encoded"
    # A fresh Simulator asks permission the first time it opens a custom URL.
    if axe describe-ui --udid "$sim" | jq -e 'any(.. | objects; .type? == "Sheet" and ((.AXLabel // "") | startswith("Open in")))' >/dev/null; then
        axe tap --udid "$sim" --label Open --element-type Button >/dev/null
    fi
}

show_fixture() {
    local source=$1 before=${2:-}
    printf '%s\r\n\r\n' "$source" >"$receipts/output-$case_name"
    run_command "${before}cat -u $receipts/output-$case_name"$'\n'"touch $receipts/ready-$case_name"
    wait_for 'The terminal fixture command did not finish' test -e "$receipts/ready-$case_name"
}

browser_requested() {
    grep -Fq "\"GET $1 HTTP/" "$receipts/http.log"
}

terminal_frame() {
    axe describe-ui --udid "$sim" | jq -cer '[.. | objects | select(.type? == "TextArea" and .frame.width > 0) | .frame][0] // empty'
}

foreground_app() {
    axe describe-ui --udid "$sim" | jq -er '[.. | objects | select(.type? == "Application") | .AXLabel][0] // empty'
}

# The fixture erases the screen and starts in the first cell. Use the
# accessible terminal frame rather than a hard-coded status-bar inset.
tap_output() {
    local row=$1 frame x y
    shift
    frame=$(wait_for 'The a-Shell terminal is not visible' terminal_frame)
    x=$(jq -r '.x + 18' <<<"$frame")
    y=$(jq -r --argjson row "$row" '.y + 8 + 17 * ($row - 1)' <<<"$frame")
    axe tap --udid "$sim" --tap-style physical -x "$x" -y "$y" "$@" >/dev/null
}

url="http://127.0.0.1:$port"
xcrun simctl terminate "$sim" "$bundle" >/dev/null 2>&1 || true
case_name=plain
plain_url="$url/plain.html?value=%2F"
show_fixture "$(printf '\033[2J\033[H%s' "$plain_url")" $'unsetenv BROWSER\n'
shell_app=$(foreground_app)
external_browser_visible() {
    local label
    label=$(foreground_app) && [ "$label" != "$shell_app" ]
}
# Prove the fixture appeared without opening a browser, and exercise selection.
tap_output 1 --hold 1
axe tap --udid "$sim" --label Copy --element-type GenericElement --wait-timeout 4 >/dev/null
clipboard_has_url() { [ "$(xcrun simctl pbpaste "$sim")" = "$plain_url" ]; }
wait_for 'Long-press Copy did not preserve the printed URL' clipboard_has_url
if browser_requested '/plain.html?value=%2F'; then
    echo 'Long-press Copy opened the URL' >&2
    exit 1
fi
printf 'long-press Copy returned the exact printed URL\n'
# With the selection still active, the tap dismisses it instead of opening.
tap_output 1 --hold 1
tap_output 1 --post-delay 1
if browser_requested '/plain.html?value=%2F'; then
    echo 'A tap opened a link while its text was selected' >&2
    exit 1
fi
printf 'tap with an active selection did not open the link: PASS\n'
tap_output 1
wait_for 'Tapping a plain URL did not open the exact address in the browser' browser_requested '/plain.html?value=%2F'
wait_for 'The default opener did not leave a-Shell' external_browser_visible
printf 'plain URL in default browser: PASS\n'

case_name=wrapped
wrapped_path='/plain.html?token=abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz'
show_fixture "$(printf '\033[2J\033[H%s%s' "$url" "$wrapped_path")"
# Tap the continuation row, not the row containing the scheme.
tap_output 2
wait_for 'Tapping the wrapped continuation did not open the complete URL' browser_requested "$wrapped_path"
printf 'wrapped URL: PASS\n'

# Prove this custom scheme can create the marker before testing its rejection.
marker="$receipts/nonweb-was-opened"
action=$(jq -nr --arg command "touch $marker" '$command | @uri')
run_command "touch $marker"
wait_for 'The custom URL did not create its marker' test -e "$marker"
mv "$marker" "$receipts/nonweb-control"

# The alternate screen routes input to cat's stdin. Keep cat running:
# printing a new shell prompt would reset mouse reporting.
start_mouse_fixture() {
    local name=$1 target=$2 output="$receipts/tui-output-$1"
    mouse_bytes="$receipts/mouse-bytes-$name"
    {
        printf '\033[?1049h\033[?1000h\033[?1006h\033[2J\033[H%s/plain.html?mouse=%s\r\n' "$url" "$name"
        printf '\033]8;;%s\033\134Read more\033]8;;\033\134\r\n' "$target"
    } >"$output"
    run_command "cat -u $output"$'\n'"cat -u >$mouse_bytes"
    wait_for 'The mouse fixture did not start reading stdin' test -f "$mouse_bytes"
    tap_output 1
    wait_for 'Tapping the implicit URL did not send the SGR press and release for row 1' mouse_reported
    if browser_requested "/plain.html?mouse=$name"; then
        echo 'An implicit link opened during TUI mouse reporting' >&2
        exit 1
    fi
    cp "$mouse_bytes" "$receipts/mouse-after-control"
}
mouse_reported() {
    local sgr
    sgr=$(printf '\033\\[<0;[0-9]+;1')
    LC_ALL=C grep -Eq "${sgr}M${sgr}m" "$mouse_bytes"
}
start_mouse_fixture web "$url/osc8.html"
printf 'implicit link forwarded the SGR button press without opening: PASS\n'
tap_output 2
wait_for 'Tapping the OSC 8 label in mouse-reporting mode did not open its hidden URL' browser_requested /osc8.html
cmp "$mouse_bytes" "$receipts/mouse-after-control"
printf 'OSC 8 with TUI mouse reporting: PASS\n'

# Repeat with the same label and tap position, changing only its hidden scheme
# and target. A tap outside the link would send another mouse report.
xcrun simctl terminate "$sim" "$bundle"
start_mouse_fixture nonweb "$scheme:$action"
tap_output 2 --post-delay 2
cmp "$mouse_bytes" "$receipts/mouse-after-control"
test ! -e "$marker"
printf 'non-web OSC 8 target consumed the tap without opening: PASS\n'
xcrun simctl terminate "$sim" "$bundle"

# The toolbar long press dismisses the keyboard and resigns the terminal.
case_name=focus
show_fixture "$(printf '\033[2J\033[Hordinary text')"
keyboard_height=$(terminal_frame | jq -r .height)
terminal_taller() { terminal_frame | jq -e --argjson height "$keyboard_height" '.height > $height + 100' >/dev/null; }
terminal_restored() { terminal_frame | jq -e --argjson height "$keyboard_height" '.height == $height' >/dev/null; }
axe tap --udid "$sim" --label Escape --element-type Button --hold 1.1 >/dev/null
wait_for 'Long-press did not dismiss the keyboard' terminal_taller
tap_output 1
wait_for 'Tapping ordinary text did not refocus the terminal' terminal_restored
printf 'non-link focus: PASS\n'

case_name=internal
show_fixture "$(printf '\033[2J\033[H%s/internal.html' "$url")" $'setenv BROWSER internalbrowser\n'
tap_output 1
wait_for 'The configured in-app browser did not request the link' browser_requested /internal.html
internal_browser_visible() {
    axe describe-ui --udid "$sim" | jq -e --arg app "$shell_app" '
        any(.. | objects; .type? == "Application" and .AXLabel? == $app) and
        any(.. | objects; .type? == "Button" and .AXUniqueId? == "apple.terminal")' >/dev/null
}
wait_for 'The fixture was not shown in the a-Shell browser' internal_browser_visible
printf 'BROWSER=internalbrowser: PASS\n'
