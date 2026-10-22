# a-shell: A terminal for iOS, with multiple windows

<p align="center">
<img src="https://img.shields.io/badge/Platform-iOS%2014.0+-lightgrey.svg" alt="Platform: iOS">
<a href="https://twitter.com/a_Shell_iOS"><img src="https://img.shields.io/badge/Twitter-@a__Shell__iOS-blue.svg?style=flat" alt="Twitter"/></a>
<a href="https://discord.gg/cvYnZm69Gy"><img src="https://img.shields.io/discord/935519150305050644?color=5865f2&label=Discord&style=flat" alt="Discord"/></a>
</p>

The goal in this project is to provide a simple Unix-like terminal on iOS. It uses [ios_system](https://github.com/holzschu/ios_system/) for command interpretation, and includes all commands from the [ios_system](https://github.com/holzschu/ios_system/) ecosystem (nslookup, whois, python3, lua, pdflatex, lualatex...) 

The project uses iPadOS 13 ability to create and manage multiple windows. Each window has its own context, appearance, command history and current directory. `newWindow` opens a new window, `exit` closes the current window. 

For help, type `help` in the command line. `help -l` lists all the available commands. `help -l | grep command` will tell you if your favorite command is already installed.

You can change the appearance of a-Shell using `config`. It lets you change the font, the font size, the background color, the text color and the cursor color and shape. Each window can have its own appearance. `config -p` will make the settings for the current window permanent, that is used for all future windows. With `config -t` you can also configure the toolbar.

When opening a new window, a-Shell executes the file `.profile` if it exists. You can use this mechanism to customize further, e.g. have custom environment variables or cleanup temporary files.

For more tips on how to use a-Shell, see <a href="https://bianshen00009.gitbook.io/a-guide-to-a-shell/">the document</a>.

## AppStore

a-Shell is now <a href="https://holzschu.github.io/a-Shell_iOS/">available on the AppStore</a>.

## How to compile it?

Use macOS with Xcode and its iOS SDKs installed. Start with `a-Shell-noPython`, which uses the publicly downloadable frameworks. Both `a-Shell` and `a-Shell-mini` embed Python and need prebuilt Python frameworks, which are not currently published.

```sh
git clone https://github.com/holzschu/a-shell.git
cd a-shell
git submodule update --init SwiftTerm
./downloadFrameworks.sh
```

In an existing checkout, run `git submodule sync` before updating initialized submodules. Avoid `--recursive`: the pinned CPython tree contains nested SSH URLs and an unavailable rasterio commit.

`downloadFrameworks.sh` installs the binary targets from `xcfs/Package.swift` under `xcfs/.build/artifacts/xcfs`, with Swift Package Manager checksum verification. Its `pythonInstall.tar.gz` contains Python 3.9 files, while the Python targets require Python 3.13.

Additional prerequisites:

- Python and its associated libraries cannot be built from this clone alone: they require an iOS Fortran compiler built from a patched gcc. The Python targets therefore need prebuilt frameworks, which are not currently published; see [the build discussion](https://github.com/holzschu/a-shell/pull/1100#issuecomment-6265206051).
- For full `a-Shell`, build the local frameworks using [node/README.md](node/README.md), [fd/README.md](fd/README.md), [fzf/README.md](fzf/README.md), [navi/README.md](navi/README.md), [gitoxide/README.md](gitoxide/README.md), [ruff/README.md](ruff/README.md), [rg/README.md](rg/README.md) and [helix/README.md](helix/README.md).
- The Python targets also reference inputs absent from the downloads, including `openrsync`/`openrsyncA`, `curl-impersonate`, `WasmKitCommand` and `blink`; full `a-Shell` references additional TeX, `cbc` and `perlC` frameworks. This list is not exhaustive; see [#1005](https://github.com/holzschu/a-shell/issues/1005).

Open `a-Shell.xcodeproj` and select `a-Shell-noPython`. To build an unsigned app for iOS devices:

```sh
xcodebuild -project a-Shell.xcodeproj -scheme a-Shell-noPython -configuration Debug -destination 'generic/platform=iOS' IPHONEOS_DEPLOYMENT_TARGET=15.0 CODE_SIGNING_ALLOWED=NO build
```

Xcode 27.1 rejects the project's 14.0 deployment target with "the range of supported deployment target versions is 15.0 to 27.1.x", so this command sets 15.0. To build a signed app, copy `Configuration.sample.xcconfig` to `Configuration.xcconfig`, replace the team ID and prefixes with your own, and omit `CODE_SIGNING_ALLOWED=NO`.

For an x86_64 Simulator build:

```sh
xcodebuild -project a-Shell.xcodeproj -scheme a-Shell-noPython -configuration Debug -destination 'generic/platform=iOS Simulator' ARCHS=x86_64 IPHONEOS_DEPLOYMENT_TARGET=15.0 CODE_SIGNING_ALLOWED=NO build
```

The Simulator build needs the same deployment-target override on Xcode 27.1. The downloaded Simulator slices have mixed architectures: ImageMagick and its freetype/harfbuzz/libpng dependencies are x86_64-only, while `bc_ios` is arm64-only. A successful build does not make every command runnable on the same Simulator.

Because Python 3.x uses functions that are only available on the iOS 14 SDK, I've set the minimum iOS version to 14.0. It also reduces the size of the binaries, so `ios_system` and the other frameworks have the same settings. If you need to run it on an iOS 13 device, you'll have to recompile most frameworks.

## Home directory

 In iOS, you cannot write in the `~` directory, only in `~/Documents/`, `~/Library/` and `~/tmp`. Most Unix programs assume the configuration files are in `$HOME`. 

 So a-Shell changes several environment variables so that they point to `~/Documents`. Type `env` to see them.

Most configuration files (Python packages, TeX files, Clang SDK...) are in `~/Library`. 

## Sandbox and Bookmarks 

a-Shell uses iOS 13 ability to access directories in other Apps sandbox. Type `pickFolder` to access a directory inside another App. Once you have selected a directory, you can do pretty much anything you want here, so be careful. 

All the directories you access with `pickFolder` are bookmarked, so you can return to them later without `pickFolder`. You can also bookmark the current directory with `bookmark`. `showmarks` will list all the existing bookmarks, `jump mark` and `cd ~mark` will change the current directory to this specific bookmark, `renamemark` will let you change the name of a specific bookmark and `deletemark` will delete a bookmark. 

A user-configurable option in Settings lets you use the commands `s`, `g`, `l`, `r` and `d` instead or as well. 

If you are lost, `cd` will always bring you back to `~/Documents/`. `cd -` will change to the previous directory. 

## Shortcuts

a-Shell is compatible with Apple Shortcuts, giving users full control of the Shell. You can write complex Shortcuts to download, process and release files using a-Shell commands. There are three shortcuts: 
- `Execute Command`, which takes a list of commands and executes them in order. The input can also be a file or a text node, in which case the commands inside the node are executed. 
- `Put File` and `Get File` are used to transfer files to and from a-Shell. 

Shortcuts can be executed either "In Extension" or "In App". "In Extension" means the shortcut runs in a lightweight version of the App, without no graphical user interface. It is good for light commands that do not require configuration files or system libraries (mkdir, nslookup, whois, touch, cat, echo...). "In App" opens the main application to execute the shortcut. It has access to all the commands, but will take longer. Once a shortcut has opened the App, you can return to the Shortcuts app by calling the command `open shortcuts://`. The default behaviour is to try to run the commands "in Extension" as much as possible, based on the content of the commands. You can force a specific shortcut to run "in App" or "in Extension", with the warning that it won't always work. 

Both kind of shortcuts run by default in the same specific directory, `$SHORTCUTS` or `~shortcuts`. Of course, since you can run the commands `cd` and `jump` in a shortcut, you can pretty much go anywhere.

## Programming / add more commands:

a-Shell has several programming languages installed: Python, Lua, JS, C, C++ and TeX. 

For C and C++, you compile your programs with `clang program.c` and it produces a webAssembly file. You can then execute it with either `wasm a.out` or `a.out`. You can also link multiple object files together, make a static library with `ar`, etc. Once you are satisfied with your program, if you move it to a directory in the `$PATH` (e.g. `~/Documents/bin`), it will be executed if you type `program` on the command line. 

You can also cross-compile programs on your main computer using our specific [WASI-sdk](https://github.com/holzschu/wasi-sdk), and transfer the WebAssembly file to your iPad or iPhone. 

Precompiled WebAssembly commands specific for a-Shell are available here: https://github.com/holzschu/a-Shell-commands These include `zip`, `unzip`, `xz`, `ffmpeg`... You install them on your iPad using the `pkg` command: `pkg install zip`.

We have the limitations of WebAssembly: no sockets, no forks (we do have interactive user input, now). Piping input from other commands with `command | wasm program.wasm` works fine. 

For Python, you can install more packages with `pip install packagename`, but only if they are pure Python. The C compiler is not yet able to produce dynamic libraries that could be used by Python. 

TeX files are not installed by default. Type any TeX command and the system will prompt you to download them. Same with LuaTeX files. 

## VoiceOver

If you enable VoiceOver in Settings, a-Shell will work with VoiceOver: reading commands as you type them, reading the result, letting you read the screen with your finger...

## Run commands remotely with relay

The loopback HTTPS server used by WebAssembly and the optional relay share a Network.framework HTTP/1.1 transport. Their listeners and routes are separate: the WASM listener serves files from Library first, then the app bundle; the relay listener serves only authenticated command requests.

Each app target sets `WasmServerPort` and `RelayServerPort` in its Info.plist. Full a-Shell uses 8443 and 8765; mini uses 8334 and 8766. Missing or invalid keys fall back to 8443 and 8765. The public a-Shell-noPython target uses its own plist with the same ports as mini. To run mini and noPython together, assign one an unused port pair in its plist. The WASM page URL reads the same `WasmServerPort` key as the listener. The relay key supplies the initial `.relay.json` port; an existing config always keeps its explicit override. The WASM listener always binds to loopback and cannot execute relay commands. Turning relay off leaves the WASM listener running.

`relay` is an optional HTTPS server built into the app. It is off by default. It executes commands in a separate, noninteractive a-Shell session with stdin connected to `/dev/null`. It does not expose the terminal screen or keyboard. iOS can suspend the app when it leaves the foreground; enabling relay does not grant background execution time.

Run `relay status` once to create `~/Documents/.relay.json` with a random token. Edit that file to configure the listener, then run `relay on`. This starts the listener and saves `enabled: true` so it starts at the next app launch. `relay off` stops the listener and saves `enabled: false`. `relay` or `relay help` prints usage.

`relay status` prints the state, autostart setting, absolute config path and effective settings, certificate path and SHA-256 fingerprint, client CA path, loaded state, fingerprint and subject, and a Mac curl command, one item per line. It describes the running listener when active and the saved configuration when stopped; autostart always reflects the saved `enabled` setting. Copy the public server certificate to the Mac as `.relay-cert.pem`. For an all-interface bind, the curl command uses the phone's Wi-Fi address when available; otherwise replace `PHONE_IP` with a reachable address. A loopback bind requires the config edit shown below before connecting from a Mac.

With mutual TLS on, status keeps the token hidden and uses `$RELAY_TOKEN` in the curl command. Run `relay tokens` explicitly to retrieve it and set that variable on the Mac. With mutual TLS off, status prints the full token and includes it in the curl command, together with a warning that anyone reaching the port with that token can execute commands. Treat that status output as a credential. `relay on`, `relay off` and startup never print credentials.

Every field below except `indicator` is required in `.relay.json`. Changes take effect on `relay on` or the next app launch. Invalid configuration prevents startup.

| Field | Default | Meaning |
| --- | --- | --- |
| `enabled` | `false` | Start at app launch. `relay on` and `relay off` update this field. |
| `bind` | `"127.0.0.1"` | Numeric IPv4 or IPv6 address. Loopback accepts connections only from this device. Set `"0.0.0.0"` for all IPv4 interfaces, `"::"` for IPv6, or a specific interface address to connect from a Mac. |
| `port` | `8765` (full), `8766` (mini) | TCP port, from 0 to 65535. Zero asks the OS to choose a port; `relay status` reports it. |
| `mutualTLS` | `true` | Require a client certificate signed by the CA enrolled in `.relay-client-ca.der`. Missing or invalid enrollment prevents startup. Set `false` explicitly to accept clients without certificates. HTTPS and the token remain required. |
| `indicator` | `true` | Show a small yellow dot while listening and a green dot with the active connection count when clients connect. Set `false` to hide it. Older config files that omit this field use `true`. |
| `token` | Random 256-bit value | Value of the `X-Token` request header. Must contain 32 to 256 printable ASCII characters without spaces. Use `relay tokens` to retrieve it; `relay status` also prints it when mutual TLS is off. |

The indicator floats above the terminal without changing its height or moving its rows. The dot stays green for ten seconds after the last connection closes; the count appears only while connections are active. It disappears when relay stops or `indicator` is false. Its contrasting border works with light and dark appearances.

`/run` passes the submitted line directly to `ios_system`, just as the a-Shell terminal does, without an extra shell layer. Native commands, pipes and redirections follow a-Shell's command syntax. For compound commands, explicitly invoke an available shell, for example `sh -c 'echo first && echo second'`, or run a script file with its interpreter. The chosen interpreter determines which shell syntax and commands are available.

TLS is always enabled. On first successful setup relay creates a separate server identity for this app installation in `.relay-identity.p12` and exports its public certificate to `.relay-cert.pem`, both in Documents. Copy only the public certificate to your Mac through a trusted channel such as USB file sharing. Keep the private identity and `.relay.json` private. To replace the server identity, run `relay off`, delete `.relay-identity.p12`, run `relay on`, then export and trust the new public certificate.

For mutual TLS, create a client CA and certificate on your Mac with OpenSSL 3 or later. Keep both private keys on the Mac; enroll only the CA's public DER certificate on the phone:

```sh
umask 077
openssl req -x509 -newkey rsa:2048 -nodes -keyout client-ca.key -out client-ca.pem -days 365 -subj '/CN=relay client CA' -addext 'basicConstraints=critical,CA:TRUE' -addext 'keyUsage=critical,keyCertSign,cRLSign'
openssl req -newkey rsa:2048 -nodes -keyout client.key -out client.csr -subj '/CN=relay Mac client'
printf 'basicConstraints=critical,CA:FALSE\nextendedKeyUsage=clientAuth\nkeyUsage=critical,digitalSignature\n' > client.ext
openssl x509 -req -in client.csr -CA client-ca.pem -CAkey client-ca.key -CAcreateserial -out client.pem -days 365 -extfile client.ext
openssl x509 -in client-ca.pem -outform DER -out .relay-client-ca.der
```

Copy `.relay-client-ca.der` to a-Shell's Documents through USB file sharing. In `.relay.json`, change `"bind": "127.0.0.1"` to `"bind": "0.0.0.0"` (or `"bind": "::"` for IPv6), keep `"port": 8765` for this example, and run `relay on`. Copy `.relay-cert.pem` from Documents to the Mac. Obtain the token with `relay tokens` and put it into the Mac's `RELAY_TOKEN` environment variable without committing it to a file or including it in a URL. Replace `PHONE_IP` below with the phone's address and adjust the port if configured:

```sh
curl --cacert .relay-cert.pem --cert client.pem --key client.key \
    --resolve "relay.local:8765:PHONE_IP" \
    -H "X-Token: $RELAY_TOKEN" \
    --data-binary 'echo hello' \
    https://relay.local:8765/run
```

The certificate names `relay.local` and `localhost`; `--resolve` connects to the actual address while checking the certificate name. Do not use `curl -k`. With `mutualTLS: false`, omit `--cert` and `--key`. This reduces authentication to possession of the token; anyone who obtains it can execute commands with the app's access. With either setting, relay is intended for trusted networks. In-app commands share the app's sandbox and can read its credential files; file permissions do not isolate commands from one another.

For example, after changing `"mutualTLS": true` to `"mutualTLS": false` and running `relay on`, use:

```sh
curl --cacert .relay-cert.pem --resolve "relay.local:8765:PHONE_IP" \
    -H "X-Token: $RELAY_TOKEN" --data-binary 'pwd' \
    https://relay.local:8765/run
```

`POST /run` takes a UTF-8 command line as its body and requires `Content-Length` and `X-Token`. Optional `X-Cwd` selects a directory, relative to Documents unless absolute; percent-encode non-ASCII characters and spaces. Tilde paths are accepted. Success returns HTTP 200 with JSON fields `stdout`, `stderr` and integer `status`, for example `{"stdout":"hello\n","stderr":"","status":0}`. A command's nonzero exit status is still HTTP 200. Output is decoded as UTF-8, replacing invalid sequences. If either stdout or stderr exceeds 8 MiB, relay closes both output pipes, requests thread cancellation, discards both streams and immediately returns HTTP 413 with the message "relay: command output exceeded 8 MiB; redirect output to a file." The app also logs that message. Programs normally exit when their next write fails with EPIPE. A new `/run` request waits up to two seconds for cancellation to finish. A program that ignores write errors and cancellation can keep running; after that wait new requests receive HTTP 503, and requests already queued at the time of overflow receive HTTP 503 immediately. Restart the app to recover from such a program. The limit is checked while the command runs; output is never truncated and returned as a successful result. Commands execute serially, with at most eight outstanding requests. Headers are limited to 16 KiB and the command body to 1 MiB. Incomplete requests are closed after 15 seconds. A wrong or missing token returns HTTP 401; missing or untrusted client certificates fail the TLS handshake when mutual TLS is enabled. Other routes return HTTP 404 after authentication.

There is no execution timeout or client cancellation. A command such as `sleep 100000` that never exceeds the output limit keeps the command queue occupied until it finishes or the app process is restarted. A client disconnect or `relay off` closes the connection and discards queued requests; a command already running continues, subject to the output limit, and keeps its side effects. Avoid interactive or unbounded commands. Stopping and restarting relay does not run two commands concurrently. Relay executes with the app's file and network permissions; it is not a restricted shell.
