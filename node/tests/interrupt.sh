#!/usr/bin/env bash
# Exercise real Node/npm/npx commands and ios_kill on a booted arm64 Simulator.
set -euo pipefail
if [[ $# != 3 ]]; then
  echo 'Usage: interrupt.sh <simulator-uuid> <full-a-Shell.app> <output-directory>' >&2
  exit 2
fi
simulator=$1
app=$(cd "$2" && pwd)
mkdir -p "$(dirname "$3")"
mkdir "$3"
output=$(cd "$3" && pwd)
here=$(cd "$(dirname "$0")" && pwd)
for framework in node ios_system dash shell text; do
  [[ -f $app/Frameworks/$framework.framework/$framework ]] || {
    echo "Missing framework: $framework" >&2
    exit 2
  }
done
headers=$app/Frameworks/ios_system.framework/Headers
if [[ ! -f $headers/ios_system.h ]]; then
  headers=$(dirname "$app")/ios_system.framework/Headers
fi
[[ -f $headers/ios_system.h ]] || {
  echo 'Missing ios_system headers; use the app in its Xcode build-products directory.' >&2
  exit 2
}
[[ -f $app/npm/bin/npx-cli.js ]] || {
  echo 'Missing bundled npm.' >&2
  exit 2
}
mkdir -p "$output/bin" "$output/node_modules/.bin" "$output/node_modules/interrupt-server"
for command in node npm npx dash dirname sed uname; do
  touch "$output/bin/$command"
  chmod +x "$output/bin/$command"
done
[[ -e $output/npm ]] || ln -s "$app/npm" "$output/npm"
cat >"$output/package.json" <<'EOF'
{"name":"interrupt-test","version":"1.0.0","scripts":{"serve":"node node_modules/interrupt-server/server.cjs"}}
EOF
cat >"$output/node_modules/interrupt-server/package.json" <<'EOF'
{"name":"interrupt-server","version":"1.0.0","bin":{"interrupt-server":"server.cjs"}}
EOF
cat >"$output/node_modules/interrupt-server/server.cjs" <<'EOF'
#!/usr/bin/env node
if (process.argv.includes('handler')) process.on('SIGINT', () => process.exit(23));
require('http').createServer((q,s) => s.end('ok')).listen(Number(process.argv[2]) || 18099, () => console.log('READY'));
EOF
chmod +x "$output/node_modules/interrupt-server/server.cjs"
nice -n 15 xcrun --sdk iphonesimulator clang -target arm64-apple-ios16.0-simulator \
  -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -I "$headers" -F "$app/Frameworks" \
  -framework Foundation -framework ios_system -Wl,-rpath,"$app/Frameworks" \
  "$here/interrupt.m" -o "$output/interrupt"
for mode in server handler npm npm-handler npx npx-handler; do
  expected=130
  case $mode in
    server) command="node node_modules/interrupt-server/server.cjs" ;;
    handler)
      command="node node_modules/interrupt-server/server.cjs handler"
      expected=23
      ;;
    npm) command='npm run serve --offline' ;;
    npm-handler)
      command='npm run serve --offline -- handler'
      expected=23
      ;;
    npx) command='npx --offline --no interrupt-server' ;;
    npx-handler)
      command='npx --offline --no interrupt-server handler'
      expected=23
      ;;
  esac
  if ! xcrun simctl spawn "$simulator" "$output/interrupt" "$command" "$expected" "$app" >"$output/$mode.log" 2>&1; then
    echo "FAIL: $mode (see $output/$mode.log)" >&2
    exit 1
  fi
  echo "PASS: $mode"
done
