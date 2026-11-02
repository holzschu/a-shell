#!/bin/sh
# Run against a running relay with a disposable enrolled client identity.
set -eu
: "${RELAY_URL:?Set RELAY_URL, for example https://localhost:8765}"
: "${RELAY_CA:?Set RELAY_CA to the exported .relay-cert.pem}"
: "${RELAY_CLIENT_CERT:?Set RELAY_CLIENT_CERT to the enrolled client certificate}"
: "${RELAY_CLIENT_KEY:?Set RELAY_CLIENT_KEY to the client private key}"
: "${RELAY_TOKEN:?Set RELAY_TOKEN from relay tokens}"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
request() {
    curl --silent --show-error --max-time 15 --cacert "$RELAY_CA" \
        --cert "$RELAY_CLIENT_CERT" --key "$RELAY_CLIENT_KEY" "$@"
}
for attempt in 1 2; do
    request --fail --header "X-Token: $RELAY_TOKEN" \
        --data-binary 'echo relay-out' \
        "$RELAY_URL/run" > "$work/result"
    jq -e '.stdout == "relay-out\n" and .stderr == "" and .status == 0' "$work/result"
    request --fail --header "X-Token: $RELAY_TOKEN" \
        --data-binary 'ls /relay-test-missing-directory' \
        "$RELAY_URL/run" > "$work/result"
    jq -e '.stdout == "" and (.stderr | contains("relay-test-missing-directory")) and .status == 1' "$work/result"
done
request --fail --header "X-Token: $RELAY_TOKEN" \
    --data-binary 'echo relay-pipe | cat' "$RELAY_URL/run" > "$work/result"
jq -e '.stdout == "relay-pipe\n" and .stderr == "" and .status == 0' "$work/result"
for bytes in 872767 1048576 4194304; do
    # Slow the consumer so queued TLS records must drain before close.
    request --fail --max-time 90 --limit-rate 128k --header "X-Token: $RELAY_TOKEN" \
        --data-binary "awk 'BEGIN { for (i = 0; i < $bytes; i++) printf \"x\" }'" \
        "$RELAY_URL/run" > "$work/large-result"
    jq -e --argjson bytes "$bytes" '(.stdout | utf8bytelength) == $bytes and .stderr == "" and .status == 0' "$work/large-result"
    request --fail --max-time 2 --header "X-Token: $RELAY_TOKEN" \
        --data-binary 'echo relay-after-large' "$RELAY_URL/run" > "$work/next"
    jq -e '.stdout == "relay-after-large\n" and .stderr == "" and .status == 0' "$work/next"
    printf 'relay large response %s bytes PASS\n' "$bytes"
done
code=$(request -o "$work/bad-token" -w '%{http_code}' -H 'X-Token: invalid' --data-binary true "$RELAY_URL/run")
[ "$code" = 401 ]
code=$(request -o "$work/missing-token" -w '%{http_code}' --data-binary true "$RELAY_URL/run")
[ "$code" = 401 ]
code=$(request -o "$work/unknown-route" -w '%{http_code}' -H "X-Token: $RELAY_TOKEN" --data-binary true "$RELAY_URL/screen")
[ "$code" = 404 ]
if [ "${RELAY_MUTUAL_TLS:-true}" = true ]; then
    if curl --silent --show-error --max-time 5 --cacert "$RELAY_CA" \
        -H "X-Token: $RELAY_TOKEN" --data-binary true "$RELAY_URL/run" > "$work/no-cert" 2> "$work/no-cert-error"; then
        echo 'Client without certificate was accepted' >&2
        exit 1
    fi
else
    curl --silent --show-error --fail --max-time 15 --cacert "$RELAY_CA" \
        -H "X-Token: $RELAY_TOKEN" --data-binary 'echo token-only' "$RELAY_URL/run" > "$work/no-cert"
    jq -e '.stdout == "token-only\n" and .stderr == "" and .status == 0' "$work/no-cert"
fi
printf '%s\n' 'relay: command output exceeded 8 MiB; redirect output to a file.' > "$work/refusal"
for command in "awk 'BEGIN { for (i = 0; i < 1048577; i++) printf \"12345678\" }'" \
    "awk 'BEGIN { for (i = 0; i < 1048577; i++) printf \"12345678\" > \"/dev/stderr\" }'" \
    "awk 'BEGIN { while (1) print \"relay-overflow\" }'" \
    "awk 'BEGIN { while (1) print \"relay-overflow\" > \"/dev/stderr\" }'"; do
    code=$(request --max-time 10 -o "$work/overflow" -w '%{http_code}' \
        -H "X-Token: $RELAY_TOKEN" --data-binary "$command" "$RELAY_URL/run")
    [ "$code" = 413 ]
    cmp "$work/refusal" "$work/overflow"
    request --fail --max-time 2 -H "X-Token: $RELAY_TOKEN" --data-binary 'echo ok' "$RELAY_URL/run" > "$work/next"
    jq -e '.stdout == "ok\n" and .stderr == "" and .status == 0' "$work/next"
done
echo 'relay command output, token authentication and client certificate mode PASS'
