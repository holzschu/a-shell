Launch the built app on an owned Simulator and let its terminal initialize, then run this host-side regression with Xcode's command-line tools:

```sh
sh tests/url-logging/check.sh SIMULATOR_UDID APP_BUNDLE_ID
```

The app must register `ashellmini:`. Confirm the OS Open dialog if shown. The test sends a command URL containing literal `%s`, requires the original app process to remain alive, checks exact command output, and checks that the callback's public log preserves the literal sequence. It prints `URL_LOGGING_PASS` and exits 0 on success.

Before the fix, the callback replaces `%s` with `(null)` in the log. The log assertion detects the format-string misuse in the callback. The test uses a unique receipt for each invocation so an older queued URL cannot satisfy it.
