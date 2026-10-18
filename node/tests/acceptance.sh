#!/bin/sh
# Source in the same Dash process after ../acceptance.sh; reuse its check/failures.
# shellcheck disable=SC2154
node -e 'process.stdout.write("x\n".repeat(3))' | node -e 'let s="";process.stdin.on("data",x=>s+=x);process.stdin.on("end",()=>console.log(s.split("\n").filter(Boolean).length))' >node-pipe.out 2>node-pipe.err
check "$?" 0 node-pipe-status
check "$(cat node-pipe.out)" 3 node-pipe-count
for iteration in 1 2 3 4 5; do
  node tests/worker.cjs </dev/null >worker.out 2>worker.err
  check "$?" 0 "worker-$iteration-status"
  check "$(cat worker.out)" 42 "worker-$iteration-value"
done
node tests/worker.cjs error </dev/null >worker-error.out 2>worker-error.err
check "$?" 0 worker-error-parent-status
check "$(cat worker-error.out)" 'parent caught worker-boom' worker-error-parent-message
node -e 'console.log("alive")' </dev/null >worker-alive.out 2>worker-alive.err
check "$?" 0 worker-app-alive-status
check "$(cat worker-alive.out)" alive worker-app-alive-output
echo "FAILURES: $failures"
[ "$failures" -eq 0 ]
