# In-app SSH server

This a-Shell mini adapter uses libssh 0.12.2 and the generic isolated-pane API from #1089 and the ios_system spawn prerequisite. The companion ios_system direct-interruption change exporting `ios_interruptpid` is a hard prerequisite: the pane calls that API and must never substitute process-directed SIGINT. Stock OpenSSH sshd requires forked monitor/session processes and reexec descriptors outside the available spawn contract; libssh provides a maintained embeddable server instead. libssh is LGPL-2.1; preserve its source and relinking obligations when distributing the resulting framework.

Build the framework before building the mini application:

```sh
bash SSHServer/build.sh iphonesimulator SOURCE_INPUTS SERVER_OUTPUT VERIFIED_FRAMEWORKS
mkdir -p SSHServer/build/sdk
ditto SERVER_OUTPUT/sdk/SSHServer.framework SSHServer/build/sdk/SSHServer.framework
```

SOURCE_INPUTS contains libssh-0.12.2.tar.xz with SHA256 49560f677d96e3706a904ac2de1116e25f3680937d51e5c92198fcba4a1c1e9f. VERIFIED_FRAMEWORKS supplies matching ios_system.framework and openssl.framework inputs. The existing mini Embed Frameworks phase signs the resulting SSHServer/build/sdk/SSHServer.framework. Use a fresh SERVER_OUTPUT for each SDK or changed input, and select matching SDK inputs. For an iPhone build, use iphoneos and copy that output into the embed path before building the application. Source archives and build products stay outside Git.

Create Documents/.ssh mode 700 and authorized_keys mode 600 with an authorized plain public key. `sshd on` starts a key-only IPv4 listener on port 2222 and prints connection addresses. `sshd status` reports state; `sshd off` closes the listener and sessions. The server starts off and does not persist an enabled state. Passwords, forwarding, authorized_keys options/certificates, security-key (sk-*) public keys and the SFTP subsystem are unsupported. Remote shell and exec requests use isolated Dash panes; PTY resize uses the pane API. The host Ed25519 private key remains in Documents/.ssh/ssh_host_ed25519_key; bootstrap its public fingerprint through a trusted channel, then use strict host-key checking.

The shared service indicator shows port, active shell count and the public host-key fingerprint, with a Stop action. It takes colors from the terminal theme.

The server retains the invoking command environment, keeping the pane cwd and dimensions, overriding HOME and setting TERM to the negotiated value, or xterm-256color without a PTY, for each pane. It appends Codex to ASHELL_HOST_COMMANDS because the measured phone extension memory budget is insufficient for that program. This requires the separate ios_system host-routing policy and the generic application host runner/broker; the client-only runtime commit does not implement that policy. Missing or busy host execution must fail rather than falling back into an extension.

Run `bash SSHServer/server-check.sh HOST PORT USER THROWAWAY_IDENTITY KNOWN_HOSTS` for actual SSH exec/pipeline, interactive prompt, inherited environment, default 80x24 dimensions, Ctrl-C status 130 with same-shell recovery, remote exit statuses 0/7/0 across channel close, and password rejection. Its interactive input sends an echo, `printf abc | wc` and exit in one burst followed by EOF; the pipeline must report zero lines, one word and three bytes. This covers queued editor input returned by a retiring command lease. Run `bash SSHServer/host-memory-check.sh HOST PORT USER THROWAWAY_IDENTITY KNOWN_HOSTS` to allocate 64 MiB and require host placement. The fixture prints the execution process identity for comparison with the app process. Neither fixture proves phone Codex recovery or background lifetime.
