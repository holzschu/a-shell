#!/usr/bin/env sh
# Run in the app's real Dash session; send Ctrl-C/Ctrl-D through a-Shell's UI.
# Copy beside acceptance.sh in Documents/node-port before invoking it.
mode=${1:?Use sync, async, warm-server, npm, npx, handler, or repl}
case "$mode" in
sync)
  node -e 'console.log("READY"); while (true) {}' >sync.out 2>sync.err
  ;;
async)
  node -e 'console.log("READY"); setInterval(() => {}, 1000)' >async.out 2>async.err
  ;;
warm-server)
  node -e 'console.log(42)' >warmup.out 2>warmup.err
  node -e 'require("http").createServer((q,s)=>s.end("ok")).listen(8099, () => console.log("READY"))' >"$mode.out" 2>"$mode.err"
  ;;
npm|npx)
  if [ ! -f node_modules/interrupt-server/server.cjs ]; then
    echo 'Copy package.json and node_modules from a tests/interrupt.sh output directory first.' >&2
    return 2
  fi
  node -e 'console.log(42)' >warmup.out 2>warmup.err
  if [ "$mode" = npm ]; then
    npm run serve --offline -- 8099 >npm.out 2>npm.err
  else
    npx --offline --no --call 'node node_modules/interrupt-server/server.cjs 8099' >npx.out 2>npx.err
  fi
  ;;
handler)
  node -e 'process.on("SIGINT", () => { console.log("SIGINT handled"); process.exit(23); }); console.log("READY"); setInterval(() => {}, 1000)' >handler.out 2>handler.err
  ;;
repl)
  node
  ;;
*)
  echo 'Use sync, async, warm-server, npm, npx, handler, or repl.' >&2
  return 2
  ;;
esac
echo "$?" >"$mode.status"
node -e 'console.log(42)' >"$mode.next" 2>"$mode.next.err"
echo complete >"$mode.done"
