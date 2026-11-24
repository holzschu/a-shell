#!/bin/bash
# Reuse the host catalogue; workers locate shared libraries through their rpaths.
set -euo pipefail
source_dictionary="$SRCROOT/Resources_mini/commandDictionary.plist"
resources="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
mkdir -p "$resources/bin" "$DERIVED_FILE_DIR"
# ExtensionFoundation requires a literal StaticString for its host binding.
/usr/bin/sed "s|@ASHELL_WORKER_HOST_IDENTIFIER@|$ASHELL_WORKER_HOST_IDENTIFIER|g" "$SRCROOT/ShellWorkers/Worker.swift" >"$DERIVED_FILE_DIR/Worker.swift"
/usr/bin/sed -E 's|<string>([^<]*\.framework/[^<]*)</string>|<string>@rpath/\1</string>|' "$source_dictionary" >"$resources/commandDictionary.plist"
# Dash discovers a command through PATH before asking ios_system to dispatch it.
/usr/bin/sed -n 's|.*<key>\([^<]*\)</key>.*|\1|p' "$source_dictionary" | while IFS= read -r command; do
	touch "$resources/bin/$command"
	chmod 755 "$resources/bin/$command"
done
