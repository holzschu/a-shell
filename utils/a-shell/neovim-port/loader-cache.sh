#!/usr/bin/env bash
# Run the same public Neovim loader scenario through the app's Dash command.
main() {
  if [ "$#" -ne 2 ]; then
    printf 'Usage: loader-cache.sh RESULTS_DIR FIXTURE_LUA\n' >&2
    return 2
  fi
  mkdir -p "$1" || return
  nvim --headless -u NONE -l "$2" "$1" >"$1/stdout" 2>"$1/stderr"
  status=$?
  printf '%s\n' "$status" >"$1/status"
  return "$status"
}
main "$@"
