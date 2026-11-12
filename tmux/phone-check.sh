#!/bin/dash
set -eu
test "$#" -eq 1 || exit 64
directory=$1
case "$directory" in /*) ;; *) exit 64 ;; esac
mkdir -p "$directory"
# A short-lived detached client may finish during the initial terminal resize.
label="short-client-${directory##*/}"
tmux -L "$label" new-session -d -s short-client 'cat'
# Ordinary control clients detach and reattach with status 0.
printf 'detach-client\n' | tmux -L "$label" -C attach-session -t short-client > "$directory/control-first" || { tmux -L "$label" kill-server || :; exit 1; }
printf 'detach-client\n' | tmux -L "$label" -C attach-session -t short-client > "$directory/control-second" || { tmux -L "$label" kill-server || :; exit 1; }
echo TMUX_CONTROL_CLIENT_STATUS_PASS
# Respawning a live pane must release its old worker before allocating another.
i=0
while test "$i" -lt 12; do
    tmux -L "$label" respawn-pane -k -t short-client cat || { tmux -L "$label" kill-server || :; exit 1; }
    i=$((i + 1))
done
tmux -L "$label" send-keys -t short-client RESPAWN_LIVE_OK Enter || { tmux -L "$label" kill-server || :; exit 1; }
sleep 1
tmux -L "$label" capture-pane -p -t short-client > "$directory/respawn-capture" || { tmux -L "$label" kill-server || :; exit 1; }
grep -q RESPAWN_LIVE_OK "$directory/respawn-capture" || { tmux -L "$label" kill-server || :; exit 1; }
echo TMUX_RESPAWN_LIVE_PASS
tmux -L "$label" kill-server
echo TMUX_SHORT_CLIENT_STATUS_PASS
tmux-acceptance "$directory/interactive"
# Warm the worker pool before measuring repeated CLI descriptor ownership.
tmux -V > "$directory/version"
sleep 1
set -- /dev/fd/*
baseline=$#
i=0
while test "$i" -lt 20; do
    tmux -V < "$directory/version" > "$directory/file"
    cat "$directory/version" | tmux -V > "$directory/pipe-in"
    tmux -V | cat > "$directory/pipe-out"
    version=$(tmux -V)
    test "$version" = 'tmux 3.8'
    if tmux -N -L tmux-acceptance-absent list-sessions > "$directory/error" 2>&1; then
        echo 'FAIL missing-server exit status'
        exit 1
    fi
    i=$((i + 1))
done
sleep 1
set -- /dev/fd/*
final=$#
echo "descriptor glob warm=$baseline final=$final"
test "$final" -le "$((baseline + 2))"
echo TMUX_PHONE_CHECK_PASS
