# Interactive-state regression

Build `interactive-state.m` as a temporary Simulator framework linked against the matching `ios_system`, export `interactive_state_main`, and register it as `interactive-state` only in an owned test app command dictionary. Run from the actual a-Shell terminal, not the main queue or an OS process. The app must use its real `ExtraCommands.swift` callbacks.

Run the command twice without restarting the app and capture stdout/status through Dash. Both calls must emit exactly `0 1 0\n0 1 0\n`, return 0, and allow the next ordinary shell command. The unchanged callback returns zero before its asynchronous read; its first active-mode assertion must fail. Do not replace the production callback with a test double: that only tests the double.

Remove the temporary command/framework registration after testing. The fixture is a normal public ios_system consumer; production code has no test mode or extra entry point.

Verified on 2026-10-16 in a fresh iPhone 17 Simulator running iOS 27, through the full app terminal. With the upstream callback, both command invocations emitted `0 0 0` and returned 1. With this fix, both emitted exactly `0 1 0\n0 1 0\n`, returned 0 with empty stderr, and ran the next ordinary shell command. The app process remained unchanged across both invocations in each phase.
