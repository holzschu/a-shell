#!/bin/sh
# Run the production CLI/parser with substitutes only for external OS services.
set -eu
scratch=$(mktemp -d /private/tmp/keychain-host.XXXXXX)
trap 'rm -r "$scratch"' EXIT HUP INT TERM
swiftc -swift-version 5 -module-cache-path "$scratch/modules" a-Shell/Credentials.swift tests/keychain.swift tests/keychain-scene.swift -o "$scratch/keychain-contract"
"$scratch/keychain-contract"
