#!/usr/bin/env bash
# Verify a real toolbar touch in a freshly launched, owned Simulator app.
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  printf 'Usage: %s OWNED_SIMULATOR_UUID [MATRIX_XCTESTRUN]\n' "$0" >&2
  exit 2
fi
device=$1
matrix=${2:-}
bundle=${NVIM_APP_BUNDLE:-local.herdr.hostbridge.a-Shell-mini}
source_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
data=$(xcrun simctl get_app_container "$device" "$bundle" data)
name="nvim-escape-$(date +%s)-$$"
result="$data/Documents/$name"
mkdir "$result"
cp "$source_dir/escape.lua" "$result/init.lua"
printf 'local x = 1\n' >"$result/sample.lua"
printf 'Results: %s\n' "$result"

fail() {
  printf 'Toolbar Escape failed: %s\n' "$*" >&2
  exit 1
}

wait_for() {
  local file=$1 expected=$2 attempt
  for ((attempt = 0; attempt < 100; attempt++)); do
    if [ -f "$file" ] && grep -Fxq "$expected" "$file"; then
      return
    fi
    sleep 0.1
  done
  fail "expected $expected in $file"
}

type_line() {
  axe type "$1" --udid "$device"
  axe key 40 --udid "$device"
}

tap_button() {
  local label=$1 frame frames attempt count x y
  for ((attempt = 0; attempt < 11; attempt++)); do
    axe describe-ui --udid "$device" >"$result/accessibility.json"
    frames=$(jq -ce --arg label "$label" '[.. | objects | select(.type? == "Button" and ((.AXLabel // "") | ascii_downcase) == $label) | .frame | select(.width > 0 and .height > 0)] | unique' "$result/accessibility.json")
    count=$(jq length <<<"$frames")
    if [ "$count" -eq 1 ]; then break; fi
    [ "$count" -eq 0 ] || fail "$label button is ambiguous"
    if [ "$attempt" -eq 0 ]; then
      # HID input can hide the accessory. Use a-Shell's Show Key Toolbar shortcut,
      # then still require the actual toolbar touch to deliver the key.
      axe key-combo --modifiers 227,226 --key 23 --udid "$device"
    fi
    sleep 0.2
  done
  [ "$count" -eq 1 ] || fail "$label button is missing"
  frame=$(jq -ce '.[0]' <<<"$frames")
  x=$(printf '%s' "$frame" | jq '.x + .width / 2')
  y=$(printf '%s' "$frame" | jq '.y + .height / 2')
  axe tap -x "$x" -y "$y" --udid "$device"
}

orient() {
  local method=$1
  TEST_RUNNER_NVIM_APP_BUNDLE="$bundle" nice -n 15 xcodebuild test-without-building -xctestrun "$matrix" \
    -destination "platform=iOS Simulator,id=$device" -only-testing:"Probe/Probe/$method" \
    -parallel-testing-enabled NO -collect-test-diagnostics never \
    -resultBundlePath "$result/$method.xcresult" >"$result/$method.log" 2>&1
}

launch=$(xcrun simctl launch "$device" "$bundle")
process_before=${launch##* }
printf '%s\n' "$process_before" >"$result/app-pid-before.out"
if [ -n "$matrix" ]; then
  [ -f "$matrix" ] || fail 'missing orientation xctestrun'
  [ -d "$data/Documents/lazy.nvim" ] || fail 'stage the pinned lazy.nvim checkout in Documents first'
  orient testPortraitOrientation
fi
terminal=''
for ((attempt = 0; attempt < 5; attempt++)); do
  if axe describe-ui --udid "$device" >"$result/startup-accessibility.json" &&
    terminal=$(jq -ce '[.. | objects | select(.role? == "AXTextArea") | .frame | select(.width > 0 and .height > 0)] | if length == 1 then .[0] else error("expected one terminal") end' "$result/startup-accessibility.json"); then
    break
  fi
  sleep 0.2
done
[ -n "$terminal" ] || fail 'terminal is not ready'
axe tap -x "$(printf '%s' "$terminal" | jq '.x + .width / 2')" -y "$(printf '%s' "$terminal" | jq '.y + .height / 2')" --udid "$device"
type_line 'cd ~/Documents'
type_line herdr
sleep 2
type_line "echo SHELL_READY > ~/Documents/$name/shell-ready.out"
wait_for "$result/shell-ready.out" SHELL_READY
type_line "nvim -u ~/Documents/$name/init.lua ~/Documents/$name/sample.lua"
wait_for "$result/ready.out" READY
axe type 'Go-- toolbar Escape' --udid "$device"
wait_for "$result/mode.out" i

# XCTest can report a non-hittable accessory item and synthesize no touch.
# AXe sends the real touch to the button in UIKit's UITextEffectsWindow.
tap_button escape
wait_for "$result/mode.out" n
grep -Fxq 27 "$result/keys.out" || fail 'Neovim did not receive Escape'

type_line ':EscapeProbe'
wait_for "$result/getchar-ready.out" WAITING
tap_button escape
wait_for "$result/getchar.out" '<Esc>'
type_line ':wq'
printf 'local x = 1\n-- toolbar Escape\n' >"$result/expected.lua"
cmp "$result/expected.lua" "$result/sample.lua" || fail 'saved edit differs'
type_line "echo ESCAPE_RECOVERED > ~/Documents/$name/recovered.out"
wait_for "$result/recovered.out" ESCAPE_RECOVERED
printf 'NVIM_TOOLBAR_ESCAPE_PASS\n'

if [ -n "$matrix" ]; then
  mkdir -p "$result/.config/nvim"
  cp "$source_dir/init.lua" "$result/.config/nvim/init.lua"
  cp "$source_dir/sample.lua" "$result/sample.lua"
  for fixture in lazy-smoke.lua phone-subprocess.sh subprocess.lua; do
    cp "$source_dir/$fixture" "$result/$fixture"
  done
  cp -R "$data/Documents/lazy.nvim" "$result/lazy.nvim"
  type_line "cd ~/Documents/$name"
  type_line 'nvim --version > version.out 2> version.err'
  type_line 'echo VERSION_READY > version-ready.out'
  wait_for "$result/version-ready.out" VERSION_READY
  grep -Fxq 'NVIM v0.12.6' "$result/version.out" || fail 'wrong Neovim version'
  printf 'GREEN version\n'

  rm "$result/ready.out"
  type_line 'nvim -u .config/nvim/init.lua -S init.lua sample.lua'
  wait_for "$result/ready.out" READY
  axe type 'Go-- edited in Herdr' --udid "$device"
  wait_for "$result/mode.out" i
  tap_button escape
  wait_for "$result/mode.out" n
  type_line ':MatrixState portrait'
  wait_for "$result/state-ready.out" portrait
  orient testLandscapeOrientation
  type_line ':MatrixState landscape'
  wait_for "$result/editor-state.out" lua:keyword
  printf 'GREEN init.lua and Lua Tree-sitter capture\n'
  portrait_cols=$(head -1 "$result/portrait-state.out")
  portrait_lines=$(tail -1 "$result/portrait-state.out")
  cols=$(sed -n '3p' "$result/editor-state.out")
  lines=$(sed -n '4p' "$result/editor-state.out")
  [ "$cols" -gt "$portrait_cols" ] && [ "$lines" -lt "$portrait_lines" ] || fail "resize $portrait_cols x $portrait_lines -> $cols x $lines"
  printf 'GREEN resize %sx%s -> %sx%s\n' "$portrait_cols" "$portrait_lines" "$cols" "$lines"
  type_line ':wq'
  type_line 'echo NVIM_RECOVERED > recovered.out'
  wait_for "$result/recovered.out" NVIM_RECOVERED
  printf 'local message = "Neovim in a Herdr pane"\nprint(message)\n-- edited in Herdr\n' >"$result/expected.lua"
  cmp "$result/expected.lua" "$result/sample.lua" || fail 'matrix saved edit differs'
  printf 'GREEN edit/save/quit and shell recovery\n'

  rm "$result/ready.out"
  type_line 'nvim -u .config/nvim/init.lua -S init.lua sample.lua'
  wait_for "$result/ready.out" READY
  axe type 'Go-- discarded with Ctrl-C' --udid "$device"
  wait_for "$result/mode.out" i
  tap_button control
  axe type c --udid "$device"
  wait_for "$result/mode.out" n
  type_line ":lua vim.fn.writefile({vim.api.nvim_get_mode().mode}, 'ctrl-c.out')"
  wait_for "$result/ctrl-c.out" n
  type_line ':q!'
  type_line 'echo REENTRY_RECOVERED > reentry-recovered.out'
  wait_for "$result/reentry-recovered.out" REENTRY_RECOVERED
  cmp "$result/expected.lua" "$result/sample.lua" || fail 'Ctrl-C discarded edit was saved'
  printf 'GREEN repeated TUI, toolbar Ctrl-C and discarded edit\n'
  type_line "nvim --headless -u NONE '+call writefile([\"SECOND_SESSION\"], \"second.out\")' +qa"
  wait_for "$result/second.out" SECOND_SESSION
  type_line "nvim --headless -u NONE '+luafile lazy-smoke.lua' +qa > lazy.stdout 2> lazy.err"
  type_line 'echo LAZY_RECOVERED > lazy-recovered.out'
  wait_for "$result/lazy-recovered.out" LAZY_RECOVERED
  wait_for "$result/lazy-smoke.out" LAZY_LOCAL_PLUGIN_LOADED
  wait_for "$result/lazy-smoke.out" JIT_DISABLED
  printf 'GREEN local lazy.nvim plugin and interpreter LuaJIT\n'
  type_line "dash phone-subprocess.sh ~/Documents/$name/pane-subprocess ~/Documents/$name > pane-subprocess.out 2>&1"
  wait_for "$result/pane-subprocess.out" NVIM_PHONE_SUBPROCESS_PASS
  printf 'GREEN subprocess driver in real Herdr pane\n'
  launch=$(xcrun simctl launch "$device" "$bundle")
  process_after=${launch##* }
  printf '%s\n' "$process_after" >"$result/app-pid-after.out"
  [ "$process_before" = "$process_after" ] || fail 'app process changed during matrix'
  bash "$source_dir/verify.sh" "$data" "$name"
  printf 'NVIM_REAL_TOUCH_MATRIX_PASS pid=%s\n' "$process_after"
fi
