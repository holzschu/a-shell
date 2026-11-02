#!/bin/sh
# Host-side regression through the app's public command URL scheme.
set -eu
if [ "$#" -ne 2 ]; then
    printf 'usage: sh check.sh SIMULATOR_UDID APP_BUNDLE_ID\n' >&2
    exit 64
fi
udid=$1
bundle=$2
container=$(xcrun simctl get_app_container "$udid" "$bundle" data)
receipt="$container/Documents/url-logging-$$.txt"
trap 'rm -f "$receipt"' EXIT
launch=$(xcrun simctl launch "$udid" "$bundle")
pid=${launch##*: }
# %25s decodes to literal %s in the command, rather than a logging format.
literal='URI_LOG_%s_OK'
xcrun simctl openurl "$udid" "ashellmini:echo%20URI_LOG_%25s_OK%20%3E%20$receipt"
attempt=0
while [ "$attempt" -lt 100 ]; do
    if ! kill -0 "$pid" 2>/dev/null; then
        printf 'FAIL: app exited while opening a URL containing %%s\n' >&2
        exit 1
    fi
    if [ -s "$receipt" ]; then
        actual=$(cat "$receipt")
        if [ "$actual" != "$literal" ]; then
            printf 'FAIL: command output did not preserve literal %%s\n' >&2
            exit 1
        fi
        logs=$(xcrun simctl spawn "$udid" log show --last 1m --style compact --predicate "processIdentifier == $pid AND composedMessage CONTAINS 'url-logging-$$.txt' AND (composedMessage BEGINSWITH 'Calling openURLContexts with ' OR composedMessage BEGINSWITH 'We received an URL in openURLContexts:')")
        if ! printf '%s\n' "$logs" | grep -F 'We received an URL in openURLContexts:' >/dev/null; then
            sleep 0.2
            attempt=$((attempt + 1))
            continue
        fi
        if ! printf '%s\n' "$logs" | grep -F "$literal" >/dev/null || ! printf '%s\n' "$logs" | grep -F 'URI_LOG_%25s_OK' >/dev/null; then
            printf 'FAIL: URL logging did not preserve literal %%s\n' >&2
            printf '%s\n' "$logs" >&2
            exit 1
        fi
        printf 'URL_LOGGING_PASS\n'
        exit 0
    fi
    sleep 0.2
    attempt=$((attempt + 1))
done
printf 'FAIL: command receipt timed out\n' >&2
exit 1
