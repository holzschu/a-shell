# Interactive command restoration

Run this regression through the terminal and a normal app relaunch. A displayed transcript alone does not pass: the original process must be gone and the relaunched terminal must accept input in the same conversation.

## Host checkpoint contract

Run from the repository root:

```sh
swiftc -swift-version 6 a-Shell/InteractiveCommandRestoration.swift tests/interactive-restoration.swift -o /tmp/interactive-restoration
/tmp/interactive-restoration
```

This checks that the checkpoint pairs the conversation ID with the original directory, is consumed once, and is removed on normal exit. It also checks the restart preference independently of the scrollback preference. It does not test whether UIKit reconnects the same scene after process death.

## Codex on Simulator and iPhone

1. In an a-Shell build with native Codex, run with "Restart vim/dash/codex after closing a-Shell" on and "Keep screen content between sessions" off. Create a disposable subdirectory under Documents with a space in its name. Enter it, verify `pwd`, and launch `codex`, signed in. Send a throwaway prompt asking for a unique reply and wait for the reply to be visible. Use `/status` to record the conversation ID and workspace. Do not inspect any authentication files.
2. Open another app and wait for a-Shell's background transition. Terminate the backgrounded a-Shell process (`simctl terminate` on Simulator or `devicectl device process terminate --kill --pid` on iPhone). Verify the original PID has disappeared.
3. Launch a-Shell normally, without a payload URL, debugger or terminal input. Verify a new process shows the reply inside Codex with no directory chooser. Then use `/status` to check both the original conversation ID and workspace, and submit a follow-up prompt to verify that the restored TUI accepts input.
4. Exit Codex normally and confirm the shell prompt. Kill a-Shell again without sending it to the background first. Relaunch normally; it must return to the shell without restarting Codex from the earlier background save.
5. Disable "Restart vim/dash/codex after closing a-Shell" and enable "Keep screen content between sessions". Start another signed-in conversation, background a-Shell, kill its process, and relaunch normally. Verify that the shell can execute a new command and that Codex did not start, even if terminal text was restored. Restore the prior settings when the test finishes.

On Simulator, repeat steps 1 and 2 with a second disposable workspace. With the app stopped, remove that workspace from the app container before relaunching. The app must leave you at a working shell prompt instead of launching Codex in another directory. Verify that a new shell command runs.

On a build with Codex restart but without the working-directory fix, step 3 can stop at Codex's directory chooser. Choosing the workspace manually is not a pass. Record the baseline and candidate builds, before/after PIDs, and the conversation and workspace match. An unauthenticated screen or a substitute conversation does not pass the signed-in check.
