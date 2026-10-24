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

## Independent shell workers

On iOS 26 and later, the mini target includes ten dedicated Generic Non-UI extensions, `ShellWorkerA` through `ShellWorkerJ`. Each worker owns one native command and its ios_system state. The original Intents and IntentsUI targets remain separate. Consumers call `ashell_pane_spawn` from a background thread, read the returned full-duplex descriptor, poll completion and release the opaque handle. The API and stream ownership rules are in `ShellWorkers/NativePane.h`.

The host retains each `AppExtensionProcess` and XPC connection until release or interruption. A full pool returns `ENOSPC`; earlier iOS versions return `ENOTSUP`. Cancel and release terminate the dedicated worker through XPC before freeing its reservation; releasing an ExtensionFoundation assertion alone permits process reuse. Commands that ignore EOF therefore cannot retain a released slot. A lost worker reports status 137 while the host and other workers remain available. Directory access uses security-scoped bookmarks and is checked with actual file operations in the worker.

Workers share the host's command libraries. Build with ios_system changes #179–#184 and dash_iOS#1–#2, including the matched libedit dependency described there. The build derives each worker's catalogue and executable markers from `Resources_mini/commandDictionary.plist`; it generates the ExtensionFoundation binding from `PRODUCT_BUNDLE_PREFIX`. Keep worker versions in `ShellWorkers/Worker.xcconfig` aligned with the containing app. The mini bundle suffixes are `.ShellWorkerA` through `.ShellWorkerJ`; each requires its own App ID and profile for a device build.

`tests/worker-pool.m` is a real app-command consumer for Simulator qualification. Device memory limits, background execution without other host background modes, and App Store acceptance require separate validation. Retaining the process handle provides no promise of unlimited background execution.

## Embedded Herdr

The mini target registers `herdr` as a native embedded command. Build its pinned static archive with `./Herdr/build.sh aarch64-apple-ios-sim` before a Simulator build, or select `aarch64-apple-ios` for a device build. See [Herdr/README.md](Herdr/README.md) for toolchain requirements, supported operations and qualification limits.

## Terminal color themes

Use `config --theme` to list bundled presets and JSON files in `~/Documents/Themes`. Select a theme with `config --theme dracula`. Add `-g` to update every open window and save the theme in Settings, for example `config --theme catppuccin-latte -g`. Use `-p` to save the current window settings, including font and color overrides. Choosing a theme in Settings or with `config --theme name -g` or `config --theme name -p` clears saved background, foreground and cursor overrides. The presets include all four Catppuccin flavors and Catppuccin OLED, adapted from Mocha with a pure black background and distinct neutral ANSI colors ordered from black through bright white. Catppuccin Latte and Rose Pine Dawn are light presets. Existing font and color options still work. `config --theme default` restores the saved theme and color overrides without changing the font. `config --theme factory` restores system foreground, background and cursor colors and the default ANSI palette; `config -r` also resets the other terminal settings.

For a custom theme, the recommended path is to put `name.json` in `~/Documents/Themes`, run `config --theme` to list it, then run `config --theme name -g` to apply and save it. Settings automatically shows "Custom file" and its name. You can also select themes in iOS Settings: open a-Shell or a-Shell mini and choose "Terminal theme". For "Custom file", enter the file name with or without `.json` in "Custom theme file name"; names ignore case. An unknown name reports the available files in `Documents/Themes` when you return to the terminal. A Settings change updates open windows when returning to the app. After changing a theme from the terminal, reopen the a-Shell settings page to refresh a selection that was already on screen.

To make a theme, create the visible `Themes` folder in a-Shell Documents and copy a preset into it:

```sh
mkdir -p ~/Documents/Themes
cp "$APPDIR/Themes/dracula.json" ~/Documents/Themes/my-theme.json
config --theme
config --theme my-theme -g
```

Edit the JSON file in Files or a text editor. It uses the Windows Terminal color scheme format: `background`, `foreground`, `cursorColor`, `black`, `red`, `green`, `yellow`, `blue`, `purple`, `cyan`, `white`, followed by `brightBlack`, `brightRed`, `brightGreen`, `brightYellow`, `brightBlue`, `brightPurple`, `brightCyan` and `brightWhite`. Every color must be a `#RRGGBB` string. Extra fields such as `name`, `selectionBackground` and attribution are allowed. Files must be regular JSON files of at most 64 KiB inside the Themes folder. Bundled preset names and `default`/`factory` are reserved; choose another file name for edits.

Files are read again whenever themes are listed or selected, so adding or editing one needs no rebuild or restart. Selecting an invalid file from the terminal reports an error and keeps the current colors. An invalid saved theme falls back to the stored or system colors with a message. Each bundled JSON file records its pinned upstream source and license; the corresponding notices are in `Themes/Licenses` inside the app.
## Terminal fonts

`config -n picker` opens the font picker without a monospace-trait filter, since some terminal fonts do not declare that trait. Listing user-installed system fonts requires the Fonts capability (Use Installed Fonts) on the signing team; the project already requests its entitlement. Installed fonts can also be selected by PostScript name with `config -n "face name"`. Choose a fixed-width face for aligned terminal output. The selected face is kept, including its weight and style.

For font files, create `~/Documents/Fonts` and drop `.ttf` or `.otf` files there using Files. Run `config --fonts` to register them and list available face names. Select a face with `config -n "face name"`, or select the first face in a file with `config -n "filename.ttf"`. The picker also lists these local faces. Files are registered only for a-Shell's process; no font is installed system-wide or bundled with the app. Use a user-supplied Nerd Font for Powerline and icon glyphs.

`config -n "face name" -s 17 -g` updates all open windows and saves the font and size. `-p` saves the current window's settings without applying them to other windows. In iOS Settings, open a-Shell or a-Shell mini and use "Font", "Custom font name", and "Font size". Choose "Custom" for another installed face or a file in `Documents/Fonts`. Changes apply when returning to the app and survive relaunch. Reopen the app's Settings page to refresh values changed from the terminal.

Font files are refreshed when running `config` or returning to the app. Removing a file unregisters it; a window using an unavailable font displays Menlo until the file returns or another face is selected. An invalid name passed to `config -n` reports an error and keeps the current selection.
