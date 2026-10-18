#!/usr/bin/env sh
# Run in the app's real Dash session; send Ctrl-C/Ctrl-D through a-Shell's UI.
# Copy beside acceptance.sh in Documents/node-port before invoking it.
mode=${1:?Use sync, async, handler, or repl}
case "$mode" in
sync)
  node -e 'console.log("READY"); while (true) {}' >sync.out 2>sync.err
  ;;
async)
  node -e 'console.log("READY"); setInterval(() => {}, 1000)' >async.out 2>async.err
  ;;
handler)
  node -e 'process.on("SIGINT", () => { console.log("SIGINT handled"); process.exit(23); }); console.log("READY"); setInterval(() => {}, 1000)' >handler.out 2>handler.err
  ;;
repl)
  node
  ;;
*)
  echo 'Use sync, async, handler, or repl.' >&2
  return 2
  ;;
esac
echo "$?" >"$mode.status"
node -e 'console.log(42)' >"$mode.next" 2>"$mode.next.err"
echo complete >"$mode.done"
