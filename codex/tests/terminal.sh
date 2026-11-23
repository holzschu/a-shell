#!/bin/sh
# Run through a-Shell's Dash, in a disposable working directory.
set -eu
out=./codex-acceptance-$$
mkdir "$out"
trap 'rm -rf "$out"' EXIT HUP INT TERM
mkdir "$out/login-home"
export CODEX_HOME="$(pwd -P)/$out/login-home"
for _run in 1 2 3; do
  codex --version >"$out/version" 2>"$out/error"
  grep -qx 'codex-cli 0.160.0' "$out/version"
  codex --help >"$out/help" 2>"$out/error"
  grep -q 'Usage: codex' "$out/help"
  codex exec --help >"$out/help" 2>"$out/error"
  grep -q 'Usage: codex exec' "$out/help"
  status=0
  codex --this-option-does-not-exist >"$out/invalid" 2>"$out/error" || status=$?
  test "$status" -eq 2
  grep -q 'unexpected argument' "$out/error"
  printf 'HOST_RESTORED\n' >"$out/host"
  grep -qx HOST_RESTORED "$out/host"
done

# Reject ChatGPT login by policy before either route performs auth I/O.
log="$CODEX_HOME/log/codex-login.log"
check_login_logging() {
  event=$1
  shift
  status=0
  RUST_LOG=codex_cli=info codex -c 'forced_login_method="api"' login "$@" >"$out/login" 2>"$out/error" || status=$?
  test "$status" -eq 1
  grep -qx 'ChatGPT login is disabled. Use API key login instead.' "$out/error"
  if grep -q 'failed to initialize login log file' "$out/error"; then
    cat "$out/error" >&2
    exit 1
  fi
  test "$(grep -c "$event" "$log")" -eq "$_run"
}
for _run in 1 2; do
  check_login_logging 'starting device code login flow' --device-auth
  check_login_logging 'starting browser login flow'
done
printf 'CODEX_CLI_PASS\n'
