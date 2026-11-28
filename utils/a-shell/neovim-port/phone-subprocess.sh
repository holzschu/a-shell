#!/bin/sh
# Replay unchanged on Simulator and through the phone owner's granted build lane.
set -u
main() {
  case_dir=${1:-$HOME/Documents/nvim44-subprocess-$(date +%s)-$$}
  fixtures=${2:-$HOME/Documents/nvim44-fixtures}
  if [ -e "$case_dir" ]; then
    echo "Case directory already exists: $case_dir" >&2
    return 1
  fi
  mkdir -p "$case_dir" || return 1
  cd "$case_dir" || return 1
  nvim --version >version.txt 2>version.err || return 1
  nvim --headless -u NONE -l "$fixtures/subprocess.lua" >subprocess.out 2>subprocess.err
  status=$?
  printf '%s\n' "$status" >subprocess.status
  [ "$status" -eq 0 ] || return 1
  [ "$(cat subprocess-result.txt)" = "NVIM_SUBPROCESS_PASS
0.12.6" ] || return 1
  nvim --headless -u NONE '+call writefile(["NVIM_REENTERED"], "reentered.txt")' +qa >reentered.out 2>reentered.err || return 1
  [ "$(cat reentered.txt)" = NVIM_REENTERED ] || return 1
  echo NVIM_PHONE_SUBPROCESS_PASS
  printf 'Results: %s\n' "$case_dir"
}
main "$@"
