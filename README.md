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

Use macOS with Xcode and its iOS SDKs installed. Start with `a-Shell-noPython`, which uses the publicly downloadable frameworks. Both `a-Shell` and `a-Shell-mini` embed Python and need the frameworks from the maintainer's Python build.

```sh
git clone https://github.com/holzschu/a-shell.git
cd a-shell
git submodule update --init SwiftTerm
./downloadFrameworks.sh
```

In an existing checkout, run `git submodule sync` before updating initialized submodules. Avoid `--recursive`: the pinned CPython tree contains nested SSH URLs and an unavailable rasterio commit.

`downloadFrameworks.sh` installs the binary targets from `xcfs/Package.swift` under `xcfs/.build/artifacts/xcfs`, with Swift Package Manager checksum verification. Its `pythonInstall.tar.gz` contains Python 3.9 files, while the Python targets require Python 3.13.

Additional prerequisites:

- Python and its associated libraries cannot be built from this clone alone: they require an iOS Fortran compiler built from a patched gcc. The Python targets therefore need the frameworks produced by the maintainer's build, which are not currently published; see [the build discussion](https://github.com/holzschu/a-shell/pull/1100#issuecomment-6265206051).
- For full `a-Shell`, build the local frameworks using [node/README.md](node/README.md), [fd/README.md](fd/README.md), [fzf/README.md](fzf/README.md), [navi/README.md](navi/README.md), [gitoxide/README.md](gitoxide/README.md) and [ruff/README.md](ruff/README.md).
- The Python targets also reference inputs absent from the downloads, including `openrsync`/`openrsyncA`, `curl-impersonate`, `WasmKitCommand` and `blink`; full `a-Shell` references additional TeX, `cbc` and `perlC` frameworks. This list is not exhaustive; see [#1005](https://github.com/holzschu/a-shell/issues/1005).

Open `a-Shell.xcodeproj` and select `a-Shell-noPython`. For an x86_64 Simulator build with the downloaded frameworks:

```sh
xcodebuild -project a-Shell.xcodeproj -scheme a-Shell-noPython -configuration Debug -destination 'generic/platform=iOS Simulator' ARCHS=x86_64 IPHONEOS_DEPLOYMENT_TARGET=15.0 CODE_SIGNING_ALLOWED=NO build
```

Several downloaded frameworks, including ImageMagick and its freetype/harfbuzz/libpng dependencies, provide only x86_64 Simulator slices. Running this build requires an x86_64-capable Simulator runtime.

For device builds, copy `Configuration.sample.xcconfig` to `Configuration.xcconfig` and replace the team ID and prefixes with your own.

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
