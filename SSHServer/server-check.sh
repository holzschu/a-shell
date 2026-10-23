#!/bin/bash
set -euo pipefail
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 HOST PORT USER THROWAWAY_IDENTITY KNOWN_HOSTS" >&2
    exit 64
fi
host=$1; port=$2; user=$3; identity=$4; known_hosts=$5
work=$(mktemp -d "${TMPDIR:-/tmp}/ashell-ssh-server.XXXXXX")
trap 'rm -rf "$work"' EXIT
options=(-o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$known_hosts" -o ConnectTimeout=5 -i "$identity" -p "$port")
ssh "${options[@]}" "$user@$host" 'echo ASHELL_SSH_EXEC_OK; printf abc | wc -c' > "$work/exec"
grep -qx ASHELL_SSH_EXEC_OK "$work/exec"
grep -Eq '^[[:space:]]*3$' "$work/exec"
ssh "${options[@]}" "$user@$host" 'test -n "$GROUP" && echo ASHELL_SSH_GROUP_PRESENT' > "$work/environment"
grep -qx ASHELL_SSH_GROUP_PRESENT "$work/environment"
# Without a PTY request the server supplies its documented 80x24 default.
# Startup terminal dimensions must not overwrite the new session's values.
ssh "${options[@]}" "$user@$host" 'printf "ASHELL_SSH_DIMS_%s_%s_END\n" "$COLUMNS" "$LINES"' > "$work/dimensions"
grep -qx ASHELL_SSH_DIMS_80_24_END "$work/dimensions"
# Keep this input in one burst followed by EOF: a retired command lease must
# return queued commands before the relay closes the editor pipe.
# shellcheck disable=SC2016 # Arithmetic must run in the remote shell.
printf 'echo ASHELL_SSH_PROMPT_$((40+2))\nprintf abc | wc\nexit\n' | ssh -tt "${options[@]}" "$user@$host" > "$work/shell" 2>&1
grep -Eq '(^|[[:space:]])ASHELL_SSH_PROMPT_42$' "$work/shell"
grep -Eq '(^|[[:space:]])0[[:space:]]+1[[:space:]]+3[[:space:]]*$' "$work/shell"
# An SSH PTY sends ETX as channel data while a foreground command owns input.
# The next command must observe interruption rather than a successful sleep.
{
    printf 'sleep 30\n'
    sleep 1
    printf '\003'
    sleep 1
    printf 'printf "ASHELL_SSH_INTERRUPT_%%s_END\\n" "$?"\nexit\n'
} | ssh -tt "${options[@]}" "$user@$host" > "$work/interrupt" 2>&1
grep -Eq '(^|[[:space:]])ASHELL_SSH_INTERRUPT_130_END$' "$work/interrupt"
if ssh "${options[@]}" -o PubkeyAuthentication=no -o PasswordAuthentication=yes -o KbdInteractiveAuthentication=no "$user@$host" true > "$work/password" 2>&1; then
    echo 'Password-only login unexpectedly succeeded' >&2
    exit 1
fi
grep -q 'Permission denied (publickey)' "$work/password"
echo ASHELL_SSH_SERVER_CORE_PASS
echo 'This fixture covers SSH exec, shell input, interruption and authentication. Check resize, TUIs, the service indicator, shutdown and background lifetime separately.'
