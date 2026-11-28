#!/bin/bash
# Compose a writable CI/packager app. The caller owns final signing and installation.
set -euo pipefail

if [[ $# != 2 ]]; then
    echo 'usage: stage-app.sh APP DuckDBCommand.framework' >&2
    exit 2
fi
app=$1
framework=$2
name=DuckDBCommand
catalog="$app/commandDictionary.plist"
bin="$app/bin/duckdb"
source="$framework/$name"
destination="$app/Frameworks/$name.framework"
[[ -f $catalog && -d $app/bin && -d $app/Frameworks && -f $source ]] || {
    echo 'Expected an a-Shell app and the matching DuckDBCommand.framework slice' >&2
    exit 2
}
if [[ -e $bin || -e $destination ]] || plutil -extract duckdb json -o - "$catalog" >/dev/null 2>&1; then
    echo 'DuckDB is already present; stage into a fresh app copy' >&2
    exit 2
fi
app_executable=$(plutil -extract CFBundleExecutable raw -o - "$app/Info.plist")
architecture_list=$(xcrun lipo -archs "$app/$app_executable")
read -r -a architectures <<<"$architecture_list"
for arch in "${architectures[@]}"; do
    xcrun lipo "$source" -verify_arch "$arch"
    app_platform=$(xcrun vtool -arch "$arch" -show-build "$app/$app_executable" | awk '$1 == "platform" {print $2}')
    framework_platform=$(xcrun vtool -arch "$arch" -show-build "$source" | awk '$1 == "platform" {print $2}')
    [[ -n $app_platform && $app_platform == "$framework_platform" ]] || {
        echo "DuckDB framework platform does not match the app ($arch)" >&2
        exit 2
    }
done
xcrun nm -gU "$source" | awk '$NF == "_duckdb_ios_main" { found = 1 } END { exit !found }'

if [[ ${#architectures[@]} == 1 ]]; then
    ditto --arch "${architectures[0]}" "$framework" "$destination"
else
    ditto "$framework" "$destination"
fi
plutil -insert duckdb -json '["DuckDBCommand.framework/DuckDBCommand","duckdb_ios_main","c:","no"]' "$catalog"
: >"$bin"
