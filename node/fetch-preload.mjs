// Node's built-in Undici parser requires WebAssembly, unavailable with jitless.
import { createRequire } from 'node:module';

// ESM enumerates node:http exports, which eagerly invokes Undici's lazy WebSocket
// getters. Keep the getters for CommonJS; unsupported named ESM WebSocket exports
// are excluded. HTTP request/response behavior stays on the native parser.
const http = createRequire(import.meta.url)('node:http');
const descriptors = {};
for (const name of ['WebSocket', 'CloseEvent', 'MessageEvent']) {
  if (Object.hasOwn(http, name)) {
    descriptors[name] = Object.getOwnPropertyDescriptor(http, name);
    delete http[name];
  }
}
const { default: fetch, Headers, Request, Response, FormData, Blob, File } =
  await import('./fetch/node_modules/node-fetch/src/index.js');
Object.defineProperties(http, descriptors);

for (const [name, value] of Object.entries({ fetch, Headers, Request, Response, FormData, Blob, File })) {
  // Defining over Node's lazy data properties invokes Undici; remove them first.
  delete globalThis[name];
  Object.defineProperty(globalThis, name, { value, writable: true, configurable: true });
}
