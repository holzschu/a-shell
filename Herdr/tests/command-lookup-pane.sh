#!/bin/sh
# Source this file in a disposable Herdr pane. The Simulator driver provides
# LOOKUP_FIXTURE and LOOKUP_APP, with these fixtures in LOOKUP_FIXTURE/bin:
#   pi (a-Shell seq package), claude.wasm (same payload),
#   omp (Python shebang script printing PYTHON_FIXTURE_OK).
lookup_root=${LOOKUP_FIXTURE:?fixture directory required}
lookup_app=${LOOKUP_APP:?installed app directory required}
lookup_path=$PATH
lookup_home=${CODEX_HOME-}
lookup_normal="$lookup_root/bin:$lookup_app/Extensions/ShellWorkerA.appex/bin:$lookup_app/bin"
export CODEX_HOME="$lookup_root/codex-home"
lookup_probe() {
    lookup_name=$1
    shift
    "$@" > "$lookup_root/$lookup_name.stdout" 2> "$lookup_root/$lookup_name.stderr"
    printf '%s\n' "$?" > "$lookup_root/$lookup_name.status"
}
# Change PATH explicitly rather than using a subshell: iOS Dash can share shell
# state across the subshell boundary.
export PATH="$lookup_normal"
lookup_probe worker-marker codex --version
lookup_probe pkg pi 3
lookup_probe python omp
lookup_probe wasm-with-suffix claude.wasm 3
lookup_probe wasm-bare claude 3
PATH="$lookup_app/bin"
lookup_probe marker-0644 codex --version
# Deliberately exclude every bundled marker for this case.
# shellcheck disable=SC2123
PATH="$lookup_root/empty"
lookup_probe native-only codex --version
export PATH="$lookup_path"
if [ -n "$lookup_home" ]; then export CODEX_HOME="$lookup_home"; else unset CODEX_HOME; fi
printf '%s %s\n' "$HERDR_PANE_ID" "$ASHELL_WORKER_PID" > "$lookup_root/complete.txt"
