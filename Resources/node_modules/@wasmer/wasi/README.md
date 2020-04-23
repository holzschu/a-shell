# `@wasmer/wasi`

Isomorphic Javascript library for interacting with WASI Modules in Node.js and the Browser. 📚

Documentation for Wasmer-JS Stack can be found on the [Wasmer Docs](https://docs.wasmer.io/wasmer-js/wasmer-js).

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Reference API](#reference-api)
- [Contributing](#contributing)

## Features

This project is forked from [node-wasi](https://github.com/devsnek/node-wasi), a Node implementation made by Gus Caplan. 🙏😄
It uses the same API than the [future WASI integration in Node](https://github.com/nodejs/wasi), to help transition to it once it becomes available in Node.

However, `@wasmer/wasi` is focused on:

- Bringing [WASI](https://github.com/webassembly/wasi) to an Isomorphic context (Node.js and the Browser) 🖥️
- Make it easy to plug in different filesystems (via [wasmfs](https://github.com/wasmerio/wasmer-js/tree/master/packages/wasmfs)) 📂
- Make it type-safe using [Typescript](http://www.typescriptlang.org/) 👷
- Pure JavaScript implementation (no Native bindings needed) 🚀
- ~ 15KB minified + gzipped 📦

## Installation

For instaling `@wasmer/wasi`, just run this command in your shell:

```bash
npm install --save @wasmer/wasi
```

## Quick Start

**This quick start is for browsers. For node, WasmFs is not required**

```js
import { WASI } from "@wasmer/wasi";
import wasiBindings from "@wasmer/wasi/lib/bindings/node";
// Use this on the browser
// import wasiBindings from "@wasmer/wasi/lib/bindings/browser";

import { WasmFs } from "@wasmer/wasmfs";

// Instantiate a new WASI Instance
const wasmFs = new WasmFs();
let wasi = new WASI({
  args: [],
  env: {},
  bindings: {
    ...wasiBindings,
    fs: wasmFs.fs
  }
});

const startWasiTask = async () => {
  // Fetch our Wasm File
  const response = await fetch("./my-wasi-module.wasm");
  const responseArrayBuffer = await response.arrayBuffer();

  // Instantiate the WebAssembly file
  const wasm_bytes = new Uint8Array(responseArrayBuffer).buffer;
  let module = await WebAssembly.compile(wasm_bytes);
  let instance = await WebAssembly.instantiate(module, {
    ...wasi.getImports(module)
  });

  // Start the WebAssembly WASI instance!
  wasi.start(instance);

  // Output what's inside of /dev/stdout!
  const stdout = await wasmFs.getStdOut();
  console.log(stdout);
};
startWasiTask();
```

## Reference API

The Reference API Documentation can be found on the [`@wasmer/wasi` Reference API Wasmer Docs](https://docs.wasmer.io/integrations/js/reference-api/wasmer-wasi).

## Contributing

This project follows the [all-contributors](https://github.com/kentcdodds/all-contributors) specification.

Contributions of any kind are welcome! 👍
