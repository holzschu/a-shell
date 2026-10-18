#!/bin/sh
# Run through the full a-Shell terminal with Dash; never run on the host.
ruff_acceptance() {
  mkdir -p "$HOME/Documents/ruff-acceptance/bad" "$HOME/Documents/ruff-acceptance/clean" "$HOME/Documents/ruff-acceptance/fix" "$HOME/Documents/ruff-acceptance/format"
  cd "$HOME/Documents/ruff-acceptance" || return 2
  rm -f complete.out ui-after.out ui-after.rc shell-after.out clean/error.py bad/ruff.toml
  printf '%s\n' "${1:?A fresh run marker is required}" >nonce.out
  printf 'import os\nprint("hello")\n' >bad/main.py
  printf 'print("hello")\n' >clean/main.py
  cp bad/main.py fix/main.py
  printf "x= { 'a':1,'b':2}\n" >format/main.py
  printf '\n$ ruff --version\n'
  ruff --version >version.out 2>version.err
  printf '%s\n' "$?" >version.rc
  cat version.out
  printf '\n$ ruff check bad\n'
  ruff check bad >bad.out 2>bad.err
  printf '%s\n' "$?" >bad.rc
  cat bad.out
  cat bad.rc
  printf '\n$ ruff check clean\n'
  ruff check clean >clean.out 2>clean.err
  printf '%s\n' "$?" >clean.rc
  cat clean.out
  cat clean.rc
  printf '\n$ ruff check --fix fix\n'
  ruff check --fix fix >fix.out 2>fix.err
  printf '%s\n' "$?" >fix.rc
  cat fix.out
  cat fix/main.py
  printf '\n$ ruff format format\n'
  ruff format format >format.out 2>format.err
  printf '%s\n' "$?" >format.rc
  cat format.out
  cat format/main.py
  ruff format format >format-second.out 2>format-second.err
  printf '%s\n' "$?" >format-second.rc
  # Check changed cwd and local configuration in the same app process.
  printf '[lint]\nselect = ["F821"]\n' >bad/ruff.toml
  cd bad || return 2
  ruff check . >../cwd-bad.out 2>../cwd-bad.err
  printf '%s\n' "$?" >../cwd-bad.rc
  cd ../clean || return 2
  printf 'missing_name\n' >error.py
  ruff check . >../cwd-clean.out 2>../cwd-clean.err
  printf '%s\n' "$?" >../cwd-clean.rc
  cd .. || return 2
  ruff --invalid-option >invalid.out 2>invalid.err
  printf '%s\n' "$?" >invalid.rc
  ruff --version >after-version.out 2>after-version.err
  printf '%s\n' "$?" >after-version.rc
  printf 'x=1\n' >stdin.py
  ruff format - <stdin.py >stdin.out 2>stdin.err
  printf '%s\n' "$?" >stdin.rc
  printf 'RUFF_ACCEPTANCE_COMPLETE\n' >complete.out
  cat complete.out
}
ruff_acceptance "$@"
