#!/bin/sh
set -eu
unset TMUX TMUX_TMPDIR
# Exercise the shipped CLI with an iOS container-length socket path.
root=${1:?Usage: socket-check.sh /absolute/long-prefix}
case "$root" in /*) ;; *) exit 64 ;; esac
socket="$root/tmux.sock"
[ "${#socket}" -gt 104 ] || { echo 'Socket test prefix must exceed 104 bytes' >&2; exit 64; }
[ ! -e "$root" ] || { echo 'Socket test requires an unused directory' >&2; exit 64; }
mkdir -p "${root%/*}"
tmux -S "$socket" -V > "$root.version"
IFS= read -r version < "$root.version"
[ "$version" = 'tmux 3.8' ]
[ ! -e "$root" ]
tmux -S "$socket" -h > "$root.help" 2>&1
[ ! -e "$root" ]
echo TMUX_SOCKETLESS_VERSION_HELP_PASS
echo "TMUX_SOCKET_PATH_BYTES=${#socket}"
mkdir -p "$root"
tmux -S "$socket" start-server \; set-option -g exit-empty off
tmux -S "$socket" show-options -gv exit-empty > "$root.option"
IFS= read -r option < "$root.option"
[ "$option" = off ]
tmux -S "$socket" kill-server
if tmux -N -S "$socket" show-options -g >/dev/null 2>&1; then
	echo 'Server still accepts commands after kill-server' >&2
	exit 1
fi
# Restart without removing the stale socket, using the stock command abbreviation.
tmux -S "$socket" new-s -d -s restarted 'cat'
tmux -S "$socket" has-session -t restarted
tmux -S "$socket" show-options -gv exit-empty > "$root/restart.option"
IFS= read -r option < "$root/restart.option"
[ "$option" = on ]
tmux -S "$socket" kill-session -t restarted
attempt=0
while tmux -N -S "$socket" show-options -g >/dev/null 2>&1; do
	[ "$attempt" -lt 10 ] || { echo 'Empty server did not exit' >&2; exit 1; }
	attempt=$((attempt + 1))
	sleep 1
done
echo TMUX_EXIT_EMPTY_PASS
echo TMUX_STALE_SOCKET_RESTART_PASS
rm -f "$socket"
echo TMUX_LONG_SOCKET_PASS
label="socketcheck-${root##*/}"
tmux -L "$label" start-server \; set-option -g exit-empty off
tmux -L "$label" display-message -p '#{socket_path}' > "$root/default.socket"
IFS= read -r socket_path < "$root/default.socket"
case "$socket_path" in
	*"/tmux-ios/$label") ;;
	*) cat "$root/default.socket" >&2; exit 1 ;;
esac
tmux -L "$label" show-options -gv exit-empty > "$root/default.option"
IFS= read -r option < "$root/default.option"
[ "$option" = off ]
tmux -L "$label" kill-server
if tmux -N -L "$label" show-options -g >/dev/null 2>&1; then
	echo 'Default server still accepts commands after kill-server' >&2
	exit 1
fi
case "$socket_path" in "$HOME"/*) echo 'Default socket is inside the host container' >&2; exit 1 ;; esac
rm -f "$socket_path"
echo TMUX_LONG_DEFAULT_SOCKET_PASS
# Use an owned temporary domain: never stop the user's real default server.
TMUX_TMPDIR="$root"
export TMUX_TMPDIR
# The unsuffixed command retains the stock default socket name.
tmux start-server \; set-option -g exit-empty off
tmux display-message -p '#{socket_path}' > "$root/stock-default.socket"
IFS= read -r socket_path < "$root/stock-default.socket"
[ "$socket_path" = "$root/tmux-ios/default" ]
tmux show-options -gv exit-empty > "$root/stock-default.option"
IFS= read -r option < "$root/stock-default.option"
[ "$option" = off ]
# Explicit -L wins over inherited TMUX; empty/malformed TMUX uses default.
TMUX="$root/missing,0,0" tmux -L default show-options -gv exit-empty > "$root/explicit-default.option"
TMUX= tmux show-options -gv exit-empty > "$root/empty-tmux.option"
TMUX=',0,0' tmux show-options -gv exit-empty > "$root/malformed-tmux.option"
for result in explicit-default empty-tmux malformed-tmux; do
	IFS= read -r option < "$root/$result.option"
	[ "$option" = off ]
done
echo TMUX_SOCKET_SELECTION_PASS
tmux kill-server
if tmux -N show-options -g >/dev/null 2>&1; then
	echo 'Stock default server still accepts commands after kill-server' >&2
	exit 1
fi
case "$socket_path" in "$HOME"/*) echo 'Default socket is inside the host container' >&2; exit 1 ;; esac
rm -f "$socket_path"
echo TMUX_ISOLATED_DEFAULT_SOCKET_PASS
rm -f "$root.version" "$root.help" "$root.option" "$root/default.socket" "$root/default.option" "$root/stock-default.socket" "$root/stock-default.option" "$root/explicit-default.option" "$root/empty-tmux.option" "$root/malformed-tmux.option" "$root/restart.option"
rmdir "$root/tmux-ios" "$root"
