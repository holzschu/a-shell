# In-app SSH server

This a-Shell mini adapter uses libssh 0.12.2 and the generic isolated-pane API from #1089 and the ios_system spawn prerequisite. Stock OpenSSH sshd requires forked monitor/session processes and reexec descriptors outside the available spawn contract; libssh provides a maintained embeddable server instead. libssh is LGPL-2.1; preserve its source and relinking obligations when distributing the resulting framework.

Build the framework before building the mini application:

```sh
bash SSHServer/build.sh iphonesimulator SOURCE_INPUTS SSHServer/build VERIFIED_FRAMEWORKS
```

SOURCE_INPUTS contains libssh-0.12.2.tar.xz with SHA256 49560f677d96e3706a904ac2de1116e25f3680937d51e5c92198fcba4a1c1e9f. VERIFIED_FRAMEWORKS supplies matching ios_system.framework and openssl.framework inputs. The existing mini Embed Frameworks phase signs the resulting SSHServer/build/sdk/SSHServer.framework. Use iphoneos only in the authorized device lane. Source archives and build products stay outside Git.

Create Documents/.ssh mode 700 and authorized_keys mode 600 with an authorized plain public key. Never replace existing user keys for qualification. `sshd on` starts a key-only IPv4 listener on port 2222 and prints connection addresses. `sshd status` reports state; `sshd off` closes the listener and sessions. The server starts off and does not persist an enabled state. Passwords, forwarding, authorized_keys options/certificates and the SFTP subsystem are unsupported. Remote shell and exec requests use isolated Dash panes; PTY resize uses the pane API. The host Ed25519 private key remains in Documents/.ssh/ssh_host_ed25519_key; bootstrap its public fingerprint through a trusted channel, then use strict host-key checking.

The shared service indicator shows port, active shell count and the public host-key fingerprint, with a Stop action. It takes colors from the terminal theme. Other services can use the same indicator collection without adding another overlay.

The server retains the invoking command environment, overriding HOME and negotiated TERM for each pane. It appends Codex to ASHELL_HOST_COMMANDS because the measured phone extension memory budget is insufficient for that program. This requires the separate ios_system host-routing policy and the generic application host runner/broker; the client-only runtime commit does not implement that policy. Missing or busy host execution must fail rather than falling back into an extension.

Run `bash SSHServer/server-check.sh HOST PORT USER THROWAWAY_IDENTITY KNOWN_HOSTS` for actual SSH exec/pipeline, interactive prompt, inherited environment, and password rejection. Run `bash SSHServer/host-memory-check.sh HOST PORT USER THROWAWAY_IDENTITY KNOWN_HOSTS` to allocate 64 MiB and require host placement; correlate it with the host lifecycle receipt. Neither fixture proves phone Codex recovery, background lifetime or hardware security-key support.

Integrated phone qualification previously passed core key login, pipeline, Vim input/quit, resize and stop/refused reconnect. Codex displayed startup then lost its extension before the first interrupt; no model prompt was sent. The corrected private Simulator passed core checks, repeated isolated logins and 64 MiB in the actual host process. This extracted generic application has not yet had its own fresh build, UI Stop or SSH qualification. Preserve that distinction when reporting results.
