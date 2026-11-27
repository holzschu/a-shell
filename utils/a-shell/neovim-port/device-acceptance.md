# Neovim device acceptance

Use the existing mini app identity and canonical signing lane. Obtain an explicit device lease before any phone action, and keep the designated restore build ready. Simulator evidence does not close this checklist.

| Field | Value |
| --- | --- |
| Source | Record the source and exact package receipt before installation. |
| Neovim | v0.12.6 |
| Runtime | LuaJIT `fbb36bb6bfa88716a47c58bcf9ce9f2ef752abac`, JIT disabled |
| Spawn prerequisite | Worker-capable ios_system with the `ios_posix_spawn` ABI and app-side worker broker. |
| Payload | iPhoneOS arm64 `Nvim` and `NvimCommand`; verify with the signing lane. Never use Simulator images. |
| App/device/OS/date | Local source-built 608, iPhone 16 Pro, 2026-11-27; keep device build and installed package receipt with raw evidence. |

Copy only the fixture files from this directory into `Documents/nvim44-fixtures`: `phone-subprocess.sh`, `subprocess.lua`, `sample.lua`, `init.lua`, `lazy-smoke.lua`, `loader-cache.sh`, `loader-cache.lua`, and the pinned lazy.nvim checkout described in README. Prepare a dedicated writable case directory and retain existing user configuration. Run the unchanged subprocess driver with a fresh absolute case path, then retrieve its complete result files and status through the existing granted transport. Expected final marker: `NVIM_PHONE_SUBPROCESS_PASS`.

| Scenario | Required route/result | Result file | Status |
| --- | --- | --- | --- |
| Startup | Fresh process, prompt and `dash -c 'echo ok'` succeed before port checks | Lane startup smoke receipt | PASS on 608 |
| Version | Native command reports 0.12.6 and interpreter LuaJIT | case/version.txt | PASS on 608 |
| system | `system('echo ok')` returns exact `ok` plus LF and status0 | case/subprocess-result.txt, subprocess.status | UNVERIFIED |
| Shell escape | `:!ls` returns status0 | Same scenario result | UNVERIFIED |
| Async job | jobstart dash returns stdout `job-ok`, separate stderr `job-err` and exit7; native ls missing-path job returns separate stderr and failure status | Same scenario result | UNVERIFIED |
| Reentry | Two editor invocations return status 0 to the same host process | exit.status, exit.repeated, host PIDs | PASS on 608; strict subprocess driver reentry not verified on device |
| Real TUI | Herdr pane, Lua init loaded, edit/save/quit, public Lua keyword capture | editor-state.out and edited sample.lua | PASS on 608 for the ASCII Lua fixture; Unicode input not tested |
| Input/resize | Esc, Ctrl-C, portrait/landscape and shell return | ctrl-c.out, grid-events.out, exit.status | PASS on 608, including a 71×9 landscape grid and discarded repeat edit |
| Plugin | Local lazy.nvim plugin loads with JIT disabled, then shell recovers | lazy.err, lazy-recovered.out | Headless PASS on 586 with writable XDG cache/state; 608 replay timed out in XCTest before proof |
| Deep-path Lua cache | Fresh absolute case: run loader-cache.sh with loader-cache.lua; cold/warm cache, distinct keys, source invalidation and fast callbacks; rebuilt native images required | loader case/status0 and result.out NVIM_LOADER_CACHE_PASS | UNVERIFIED |
| Isolation | Unrelated pane output never enters Neovim streams | Fresh pane result files | UNVERIFIED |
| Lifecycle | Background/foreground, host kill/relaunch and persistence; name the actual terminal backend | Host and worker PID, active Herdr command, editor screen marker, crash-list delta | All six Settings/Safari survival rows on 608 passed (15/60/180 s each); forced-kill editor recovery not tested |
| PTY/terminal | Explicit ENOSYS; phone has no kernel PTY and the bridge currently supplies streams | Named unsupported result | UNVERIFIED |
| Worker budget | Record process/worker memory and any jetsam; Simulator RSS is not a phone limit proof | Owner receipt | UNVERIFIED |

Rehearse the exact scripts and transfer/readback on the owned Simulator before phone replay. A failure found on the phone returns to Simulator qualification. Keep this bead open until the lead accepts the integrated device receipt.
