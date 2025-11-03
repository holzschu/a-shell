// Load the "require" function:
importScripts("require.js");
// make the "require" function available to all
Tarp.require({expose: true});
// Have a global variable:
var global = self;
var sharedArray;
const decoder = new TextDecoder();
// and a Buffer variable
var Buffer = require('buffer').Buffer;
// var process = require('process');

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

function bytesToBase64(bytes) {
  const binString = Array.from(bytes, (byte) =>
    String.fromCodePoint(byte),
  ).join("");
  return btoa(binString);
}


function interactiveKeyboardInput(inputLength) {
	// Send a request to the outside:
	Atomics.store(sharedArray, 0, 0);
	sharedArray[0] = 0;
	postMessage(["keyboard", inputLength]);
	// Freeze ourselves until the response is ready:
	Atomics.wait(sharedArray, 0, 0);
	result = '';
	// Decode the response (by slices of 2047 bytes):
	let length = sharedArray[0] - 1;
	while (length >= 0) {
		let bytes = new Int8Array(length);
		for (let i = 0; i < length; i++) {
			result += String.fromCharCode(sharedArray[i+1]);
		}
		if (length == 2047) {
			// wait for the next chunk:
			// Need to tell it to send the next chunk!
			Atomics.store(sharedArray, 0, 0);
			sharedArray[0] = 0;
			postMessage(["sendNextChunk"]);
			Atomics.wait(sharedArray, 0, 0, 10000);
			length = sharedArray[0] - 1;
		} else {
			break;
		}
	}
	// Need to base64-encode in case there are emojis or other utf-8 characters:
	return bytesToBase64(new TextEncoder().encode(result));
}

function prompt(string) {
	// Send a request to the outside:
	sharedArray[0] = 0;
	Atomics.store(sharedArray, 0, 0);
	postMessage(["prompt", string]);
	// Freeze ourselves until the response is ready:
	let reason = Atomics.wait(sharedArray, 0, 0, 500);
	result = '';
	// Decode the response (by slices of 8192 bytes):
	let length = sharedArray[0] - 1;
	while (length >= 0) {
		let bytes = new Int8Array(length);
		for (let i = 0, j=1; i < length; i+=4, j++) {
			bytes[i  ] = sharedArray[j] & 0xFF;
			bytes[i+1] = (sharedArray[j] >>  8) & 0xFF;
			bytes[i+2] = (sharedArray[j] >> 16) & 0xFF;
			bytes[i+3] = (sharedArray[j] >> 24) & 0xFF;
		}
		result += decoder.decode(bytes);
		if (length == 8192) {
			// wait for the next chunk:
			// Need to tell it to send the next chunk!
			sharedArray[0] = 0;
			Atomics.store(sharedArray, 0, 0);
			postMessage(["sendNextChunk"]);
			let reason = Atomics.wait(sharedArray, 0, 0, 10000);
			length = sharedArray[0] - 1;
		} else {
			break;
		}
	}
	return result;
}

// bufferString: program in base64 format
// args: arguments (argv[argc])
// stdinBuffer: standard input
// cwd: current working directory
function executeWebAssemblyWorker(bufferString, args, cwd, tty, env) {
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
		// This line must be commented on release (it breaks tlmgr):
		// console.log("Wasm error: " + error.message + " Error code: " + error.code);
        if (error.code === undefined) {
			errorCode = 1; 
			errorMessage = 'wasm: ' + error;
		} else if (error.code != null) { 
			// Numerical error code. Send the return code back to Swift.
			errorCode = error.code;
			if (errorCode > 0) 
				errorMessage = error.message;
		} else {
			errorCode = 1; 
		}
	}
	postMessage(["commandTerminated", errorCode, errorMessage]);
}

onmessage = (e) => {
	if (typeof sharedArray === 'undefined') {
		sharedArray = new Int32Array(e.data[5]);
	}
	executeWebAssemblyWorker(e.data[0], e.data[1], e.data[2], e.data[3], e.data[4]);
}
