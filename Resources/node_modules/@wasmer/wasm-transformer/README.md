# wasm-transformer

Library to run transformations on WebAssembly binaries. 🦀♻️

Documentation for Wasmer-JS Stack can be found on the [Wasmer Docs](https://docs.wasmer.io/wasmer-js/wasmer-js).

**This README covers the instructions for installing, using, and contributing to the `wasm-transformer` Javascript package. [The `wasm_transformer` Rust crate is available here](../../packages/wasm-transformer).**

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
  - [Node](#node)
  - [Browser](#browser)
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
npm install --save @wasmer/wasm-transformer
```

## Quick Start

For a larger example, see the [wasm-terminal](../../packages/wasm-terminal) package.

### Node

```js
const wasmTransformer = require("@wasmer/wasm-transformer");

// Read in the input Wasm file
const wasmBuffer = fs.readFileSync("./my-wasm-file.wasm");

// Transform the binary
const wasmBinary = new Uint8Array(wasmBuffer);
const loweredBinary = wasmTransformer.lowerI64Imports(wasmBinary);

// Do something with loweredBinary
```

### Browser

```js
import { lowerI64Imports } from "@wasmer/wasm-transformer";

const fetchAndTransformWasmBinary = async () => {
  // Get the original Wasm binary
  const fetchedOriginalWasmBinary = await fetch("/original-wasm-module.wasm");
  const originalWasmBinaryBuffer = await fetchedOriginalWasmBinary.arrayBuffer();
  const originalWasmBinary = new Uint8Array(originalWasmBinaryBuffer);

  // Transform the binary, by running the lower_i64_imports from the wasm-transformer
  const transformedBinary = await lowerI64Imports(originalWasmBinary);

  // Compile the transformed binary
  const transformedWasmModule = await WebAssembly.compile(transformedBinary);
  return transformedWasmModule;
};
```

## Reference API

The Reference API Documentation can be found on the [`@wasmer/wasm-transformer` Reference API Wasmer Docs](https://docs.wasmer.io/integrations/js/reference-api/wasmer-wasm-transformer).

## Contributing

### Guidelines

This project follows the [all-contributors](https://github.com/kentcdodds/all-contributors) specification.

Contributions of any kind are welcome! 👍

### Building the project

To get started using the project:

- Set up the [`wasm_transformer` rust crate](../../crates/wasm_transformer)

- Install the latest LTS version of Node.js (which includes `npm` and `npx`). An easy way to do so is with nvm. (Mac and Linux: [here](https://github.com/creationix/nvm), Windows: [here](https://github.com/coreybutler/nvm-windows)).

- `npm run build`.
