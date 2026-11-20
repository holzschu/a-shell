#!/bin/sh
# Reproduce the three historical active-only decisions without changing the working tree.
set -eu
scratch=$(mktemp -d /private/tmp/keychain-scene-revert.XXXXXX)
trap 'rm -r "$scratch"' EXIT HUP INT TERM
for boundary in entry presentation export; do
	awk -v boundary="$boundary" '
		/^[[:space:]]*if boundary == \.export, !exportAuthorized \{$/ {
			print "        if boundary == ." boundary ", activation == .inactive {"
			print "            throw CredentialError.denied(\"historical active-only gate\")"
			print "        }"
			matched++
		}
		{ print }
		END { if (matched != 1) exit 2 }
	' a-Shell/Credentials.swift > "$scratch/Credentials.swift"
	swiftc -swift-version 5 -module-cache-path "$scratch/modules" "$scratch/Credentials.swift" tests/keychain.swift tests/keychain-scene.swift -o "$scratch/reverted-$boundary"
	if "$scratch/reverted-$boundary" > "$scratch/$boundary.stdout" 2> "$scratch/$boundary.stderr"; then
		printf 'FAIL active-only %s gate was not detected\n' "$boundary" >&2
		exit 1
	else
		test "$?" -eq 1
	fi
	case "$boundary" in
		entry) expected=entry-foregroundInactive-proceeds ;;
		presentation) expected=presentation-foregroundInactive-proceeds ;;
		export) expected=export-foregroundInactive-after-auth-proceeds ;;
	esac
	grep -Fx "FAIL scene-gate $expected: status/bytes did not match the contract" "$scratch/$boundary.stderr"
	printf 'PASS red-on-revert %s (compiled historical decision; contract exited1)\n' "$boundary"
done
