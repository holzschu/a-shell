#!/usr/bin/env bash
# Verify observable files produced by the real terminal UI scenario.
set -euo pipefail
root=${1:?Usage: verify.sh APP_DATA_CONTAINER [CASE_NAME]}/Documents${2:+/$2}
rg -q '^NVIM v0.12.6$' "$root/version.out"
rg -q '^LuaJIT ' "$root/version.out"
[[ ! -s $root/version.err ]]
diff -u <(printf 'local message = "Neovim in a Herdr pane"\nprint(message)\n-- edited in Herdr\n') "$root/sample.lua"
mapfile_compat=()
while IFS= read -r line; do mapfile_compat+=("$line"); done <"$root/editor-state.out"
[[ ${mapfile_compat[0]} == INIT_LUA_LOADED && ${mapfile_compat[1]} == lua && ${mapfile_compat[4]} == 'Lua 5.1' ]]
[[ ${mapfile_compat[5]} == lua:keyword ]]
portrait_cols=$(head -1 "$root/portrait-state.out")
portrait_lines=$(tail -1 "$root/portrait-state.out")
[[ ${mapfile_compat[2]} -gt $portrait_cols && ${mapfile_compat[3]} -lt $portrait_lines ]]
diff -u <(printf 'NVIM_RECOVERED\n') "$root/recovered.out"
diff -u <(printf 'SECOND_SESSION\n') "$root/second.out"
diff -u <(printf 'n\n') "$root/ctrl-c.out"
rg -q '^LAZY_LOCAL_PLUGIN_LOADED$' "$root/lazy-smoke.out"
rg -q '^JIT_DISABLED$' "$root/lazy-smoke.out"
diff -u <(printf 'LAZY_RECOVERED\n') "$root/lazy-recovered.out"
rg -q '^NVIM_PHONE_SUBPROCESS_PASS$' "$root/pane-subprocess.out"
diff -u <(printf 'NVIM_REENTERED\n') "$root/pane-subprocess/reentered.txt"
echo "PASS: version, edit/save/quit, init.lua, Lua syntax, resize ${portrait_cols}x${portrait_lines} -> ${mapfile_compat[2]}x${mapfile_compat[3]}, repeated TUI, Ctrl-C/Esc, local lazy.nvim plugin, real-pane subprocesses"
