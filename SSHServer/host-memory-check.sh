#!/bin/bash
set -euo pipefail
# Start the disposable server with ASHELL_HOST_COMMANDS="codex lua" for this check.
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 HOST PORT USER THROWAWAY_IDENTITY KNOWN_HOSTS" >&2
    exit 64
fi
host=$1; port=$2; user=$3; identity=$4; known_hosts=$5
ssh -T -p "$port" -i "$identity" -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$known_hosts" "$user@$host" 'lua -' <<'LUA'
local allocation = string.rep("x", 64 * 1024 * 1024)
local worker = os.getenv("ASHELL_WORKER_PID")
local root = os.getenv("ASHELL_WORKER_ROOT_PID")
print("allocated_bytes=" .. #allocation)
print("worker_marker_present=" .. tostring(worker ~= nil))
assert(worker == nil and root == nil, "high-footprint command ran in extension worker")
print("ASHELL_HOST_MEMORY_PASS")
LUA
