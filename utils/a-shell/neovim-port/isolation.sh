#!/usr/bin/env bash
# Run the owned-stream and legacy controls in separate Simulator processes.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
sim=${1:?Usage: isolation.sh OWNED_SIMULATOR_UUID BUILT_APP IOS_SYSTEM_SLICE RECEIPTS}
app=$(cd "${2:?Built Simulator app required}" && pwd -P)
slice=${3:?ios_system framework slice with SDK headers required}
receipts=${4:?Owned receipt directory required}
probe=$(mktemp "$app/nvim-isolation.XXXXXXXX")
trap 'rm -f "$probe"' EXIT
mkdir -p "$receipts"
xcrun --sdk iphonesimulator clang -target arm64-apple-ios16.0-simulator \
  -Wall -Wextra -Werror -I "$slice/ios_system.framework/Headers" -F "$slice" \
  -framework ios_system -framework Foundation -Wl,-rpath,@executable_path/Frameworks \
  "$here/isolation.m" "$here/command.m" -o "$probe"
codesign -s - "$probe"
for variant in green red; do
  args=()
  [[ $variant != red ]] || args=(legacy)
  xcrun simctl spawn "$sim" "$probe" ${args[@]+"${args[@]}"} \
    >"$receipts/isolation-$variant.out" 2>"$receipts/isolation-$variant.err"
done
diff -u <(for ((i = 0; i < 20; i++)); do echo PANE_B_FD1; done) "$receipts/isolation-green.out"
[[ ! -s $receipts/isolation-red.out ]]
grep -E 'NVIM_OVERLAP.*B_in_A=0 status=0' "$receipts/isolation-green.err"
grep -E 'NVIM_OVERLAP.*B_in_A=20 status=0' "$receipts/isolation-red.err"
