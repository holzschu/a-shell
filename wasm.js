// make the "require" function available to all
Tarp.require({expose: true});
// Have a global variable:
if (typeof window !== 'undefined') {
	window.global = window;
}
// and a Buffer variable
var Buffer = require('buffer').Buffer;
var process = require('process');

// Functions to deal with WebAssembly:
// These should load a wasm program: http://andrewsweeney.net/post/llvm-to-wasm/
/* Array of bytes to base64 string decoding */
// Modules for @wasmer:
const WASI = require('@wasmer/wasi/lib').WASI;
const browserBindings = require('@wasmer/wasi/lib/bindings/browser').default;
const WasmFs = require('@wasmer/wasmfs').WasmFs;
// Experiment: don't call lowerI64Imports, see if that works.
// const lowerI64Imports = require("@wasmer/wasm-transformer").lowerI64Imports

function b64ToUint6 (nChr) {

	return nChr > 64 && nChr < 91 ?
		nChr - 65
		: nChr > 96 && nChr < 123 ?
		nChr - 71
		: nChr > 47 && nChr < 58 ?
		nChr + 4
		: nChr === 43 ?
		62
		: nChr === 47 ?
		63
		:
		0;

}

function base64DecToArr (sBase64, nBlockSize) {
	var
	sB64Enc = sBase64.replace(/[^A-Za-z0-9\+\/]/g, ""), nInLen = sB64Enc.length,
		nOutLen = nBlockSize ? Math.ceil((nInLen * 3 + 1 >>> 2) / nBlockSize) * nBlockSize : nInLen * 3 + 1 >>> 2, aBytes = new Uint8Array(nOutLen);

	for (var nMod3, nMod4, nUint24 = 0, nOutIdx = 0, nInIdx = 0; nInIdx < nInLen; nInIdx++) {
		nMod4 = nInIdx & 3;
		nUint24 |= b64ToUint6(sB64Enc.charCodeAt(nInIdx)) << 18 - 6 * nMod4;
		if (nMod4 === 3 || nInLen - nInIdx === 1) {
			for (nMod3 = 0; nMod3 < 3 && nOutIdx < nOutLen; nMod3++, nOutIdx++) {
				aBytes[nOutIdx] = nUint24 >>> (16 >>> nMod3 & 24) & 255;
			}
			nUint24 = 0;
		}
	}
	return aBytes;
}

// bufferString: program in base64 format
// args: arguments (argv[argc])
// stdinBuffer: standard input
// cwd: current working directory
function executeWebAssembly(bufferString, args, cwd, tty, env) {
	// Input: base64 encoded binary wasm file
	if (typeof window !== 'undefined') {
		if (!('WebAssembly' in window)) {
			window.webkit.messageHandlers.aShell.postMessage('WebAssembly not supported');
			return;
		}
	}
	var arrayBuffer = base64DecToArr(bufferString); 
	// Experiment: don't call lowerI64Imports, see if that works.
	const loweredWasmBytes = arrayBuffer; // lowerI64Imports(arrayBuffer);
	var errorMessage = '';
	var errorCode = 0; 
	// TODO: link with other libraries/frameworks? impossible, I guess.
	// TODO: keyboard input (directly from onkeypress)
	try {
		const wasmFs = new WasmFs(); // local file system. Used less often.
		let wasi = new WASI({
			preopens: {'.': cwd, '/': '/'},
			args: args,
			env: env,
			bindings: {
				...browserBindings,
				fs: wasmFs.fs,
			}
		})
		wasi.args = args
		if (tty != 1) {
			wasi.bindings.isTTY = (fd) => false;
		}
		const module = new WebAssembly.Module(loweredWasmBytes); 
		const instance = new WebAssembly.Instance(module, wasi.getImports(module));
		wasi.start(instance);
	}
	catch (error) {
		// WASI returns an error even in some cases where things went well. 
		// We find the type of the error, and return the appropriate error message
		if (error.code === 'undefined') {
			errorCode = 1; 
			errorMessage = '\nwasm: ' + error + '\n';
		} else if (error.code != null) { 
			// Numerical error code. Send the return code back to Swift.
			errorCode = error.code;
		} else {
			errorCode = 1; 
		}
	}
	return [errorCode, errorMessage];
}

