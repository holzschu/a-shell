# Interactive command restoration

Run this regression through the terminal and a normal app relaunch. A displayed transcript alone does not pass: the original process must be gone and the relaunched terminal must accept input in the same conversation.

## Host checkpoint contract

Run from the repository root:

```sh
swiftc -swift-version 6 a-Shell/InteractiveCommandRestoration.swift tests/interactive-restoration.swift -o /tmp/interactive-restoration
/tmp/interactive-restoration
```

This checks the notification-to-activity handoff and the generated resume invocation. It does not test whether UIKit restores the activity after process death.

## Codex on a physical iPhone

1. On an iPhone running an a-Shell build with native Codex, enable "Keep screen content between sessions". Launch `codex` from the terminal, signed in. Send a throwaway prompt asking for a unique reply and wait for the reply to be visible. Use `/status` to record the conversation ID. Do not inspect any authentication files.
2. Open another app. Wait for a-Shell's background transition in the device log. Read the PID of the a-Shell process and kill that exact PID with `devicectl device process terminate --kill --pid`. Verify the original PID has disappeared.
3. Launch a-Shell normally, without a payload URL, debugger or terminal input. Verify a new process is running and shows the reply from step 1 inside Codex, not just in shell scrollback. Use `/status` to check the same conversation ID and submit a follow-up prompt to verify the restored TUI accepts input.
4. Exit Codex normally. Background and kill a-Shell again, then relaunch it. It must return to an ordinary shell prompt without starting Codex.
5. Repeat steps 1–3 with "Keep screen content between sessions" disabled. Relaunch must not start Codex. Restore the prior setting when the test finishes.

The first relaunch on the baseline must fail step 3: it shows a shell prompt, even if the saved terminal text contains the reply. Record baseline and candidate bundle versions, before/after PIDs, any device termination evidence, and the displayed conversation ID and reply. An unauthenticated Codex screen or a substitute conversation does not qualify a device run.
