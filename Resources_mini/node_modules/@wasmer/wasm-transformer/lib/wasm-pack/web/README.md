# wasm_transformer

Library to run transformations on WebAssembly binaries. 🦀♻️

**This README covers the instructions for installing, using, and contributing to the `wasm_transformer` rust crate. [The `wasm-transformer` Javascript package is available here](../../packages/wasm-transformer).**

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Reference API](#reference-api)
- [Contributing](#contributing)
  - [Guidelines](#guidelines)
  - [Building the project](#building-the-project)

## Features

This project depends on [wasmparser](https://github.com/yurydelendik/wasmparser.rs), and the [wasm-pack](https://github.com/rustwasm/wasm-pack) workflow. Huge shoutout to them! 🙏

- Runs transformations on Wasm binaries to modify the actual code that gets run, and introduces new features (such as introducing trampoline functions for i64 WASI imports). ✨

- Installable on both crates.io, and npm! 📦

- The project builds with [wasm-pack](https://github.com/rustwasm/wasm-pack). Thus, you can use this library in a Javascript library, to modify WebAssembly Binaries, with WebAssembly. 🤯

- Super fast! Can run the `lower_i64_imports` transformations on my 2018 MackBook Pro, with the Chrome Devtools 6x CPU slowdown in ~ 1 second. ⚡

## Installation

```
# Cargo.toml
[dependencies]
wasm_transformer = "LATEST_VERSION_HERE"
```

## Quick Start

For a larger example, see the simple [wasm_transformer_cli](../../examples/wasm_transformer_cli).

```rust
use wasm_transformer::*;

// Some Code here

// Read in a Wasm file as a Vec<u8>
let mut Wasm = fs::read(wasm_file_path).unwrap();
// Add trampoline functions to lower the i64 imports in the Wasm file
let lowered_wasm = wasm_transformer::lower_i64_imports(wasm);
// Write back out the new Wasm file
fs::write("./out.wasm", &lowered_wasm).expect("Unable to write file");
```

## Reference API

`version()`

Returns the version of the crate/package

---

`lower_i64_imports(mut wasm_binary: Vec<u8>) -> Vec<u8>`

Inserts trampoline functions for imports that have i64 params or returns. This is useful for running Wasm modules in browsers that [do not support JavaScript BigInt -> Wasm i64 integration](https://github.com/WebAssembly/proposals/issues/7). Especially in the case for [i64 WASI Imports](https://github.com/CraneStation/wasmtime/blob/master/docs/WASI-api.md#clock_time_get).

## Contributing

### Guidelines

This project follows the [all-contributors](https://github.com/kentcdodds/all-contributors) specification.

Contributions of any kind are welcome! 👍

### Building the project

To get started using the project:

- Install the latest Nightly version of [Rust](https://www.rust-lang.org/tools/install) (which includes cargo).

- Install the latest version of [wasm-pack](https://github.com/rustwasm/wasm-pack).

- To test and build the project, run the `wasm_transformer_build.sh` script. Or, feel free to [look through the script](./wasm_transformer_build.sh) to see the documented commands for performing their respective actions individually. The script performs:

  - Running Clippy

  - Running tests

  - Building the project, moving output into the correct directories in the [javascript package](../../packages/wasm-transformer).
