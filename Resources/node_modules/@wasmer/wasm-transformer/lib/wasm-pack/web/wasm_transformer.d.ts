/* tslint:disable */
/**
* get the versioon of the package
* @returns {string} 
*/
export function version(): string;
/**
* i64 lowering that can be done by the browser
* @param {Uint8Array} wasm_binary 
* @returns {Uint8Array} 
*/
export function lowerI64Imports(wasm_binary: Uint8Array): Uint8Array;

/**
* If `module_or_path` is {RequestInfo}, makes a request and
* for everything else, calls `WebAssembly.instantiate` directly.
*
* @param {RequestInfo | BufferSource | WebAssembly.Module} module_or_path
*
* @returns {Promise<any>}
*/
export default function init (module_or_path?: RequestInfo | BufferSource | WebAssembly.Module): Promise<any>;
        