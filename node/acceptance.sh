#!/bin/sh
# Run inside a-Shell's Dash, from Documents/node-port; observe real CLI results.
failures=0
check() {
  if [ "$1" = "$2" ]; then
    echo "PASS $3"
  else
    echo "FAIL $3: expected $2, got $1"
    failures=$((failures + 1))
  fi
}

node -e 'console.log(41)' </dev/null >first.out 2>first.err
check "$?" 0 first-status
check "$(cat first.out)" 41 first-output
node -e 'console.log(42)' </dev/null >second.out 2>second.err
check "$?" 0 second-status
check "$(cat second.out)" 42 second-output
echo 'console.log(43)' >local.cjs
node local.cjs </dev/null >third.out 2>third.err
check "$?" 0 third-status
check "$(cat third.out)" 43 third-output
node -e 'console.log(44)' </dev/null >fourth.out 2>fourth.err
check "$?" 0 fourth-status
check "$(cat fourth.out)" 44 fourth-output
node local.cjs </dev/null >fifth.out 2>fifth.err
check "$?" 0 fifth-status
check "$(cat fifth.out)" 43 fifth-output
node -e 'process.exit(7)' </dev/null >exit.out 2>exit.err
check "$?" 7 explicit-exit
node -e 'throw new Error("node-acceptance")' </dev/null >throw.out 2>throw.err
check "$?" 1 uncaught-exception
grep -q node-acceptance throw.err
check "$?" 0 exception-stderr
node -e 'console.error("separate");console.log("stdout")' </dev/null >streams.out 2>streams.err
check "$?" 0 streams-status
check "$(cat streams.out)" stdout stdout-redirection
check "$(cat streams.err)" separate stderr-redirection
echo x | node -e 'let s="";process.stdin.on("data",x=>s+=x);process.stdin.on("end",()=>console.log(s.trim().toUpperCase()))' >pipe.out 2>pipe.err
check "$?" 0 stdin-status
check "$(cat pipe.out)" X stdin-pipe
printf '%s\n' 'console.log("first\nsecond")' >pipe.cjs
node pipe.cjs </dev/null | head -n 1 >head.out
check "$(cat head.out)" first stdout-pipe
echo 'module.exports = 45' >dependency.cjs
echo 'console.log(require("./dependency.cjs"))' >require.cjs
node require.cjs </dev/null >require.out 2>require.err
check "$?" 0 require-status
check "$(cat require.out)" 45 require-output
echo 'export default 46' >dependency.mjs
echo 'import n from "./dependency.mjs"; console.log(n)' >import.mjs
node import.mjs </dev/null >import.out 2>import.err
check "$?" 0 esm-status
check "$(cat import.out)" 46 esm-output
node --import "$APPDIR/node-fetch/fetch-preload.mjs" -e 'fetch("https://example.com").then(r=>console.log(r.status)).catch(e=>{console.error(e);process.exitCode=1})' </dev/null >fetch.out 2>fetch.err
check "$?" 0 https-status
check "$(cat fetch.out)" 200 https-output
node -e 'console.log("alive",process.memoryUsage().rss)' </dev/null >memory.out 2>memory.err
check "$?" 0 app-alive
echo "FAILURES: $failures"

[ "$failures" -eq 0 ]
