// make the "require" function available to all
Tarp.require({expose: true});
// Have a global variable:
if (typeof window !== 'undefined') {
	window.global = window;
}
// and Buffer and process variables
var Buffer = require('buffer').Buffer;
var process = require('process');
// (we don't use "require" anymore, but JavaScript files calling JSC might need it)
// This file handles communication between the system and
// the WebWorker in charge of executing WebAssembly.
// Everything related to WebAssembly is in wasm_worker_wasm.js
const sab = new SharedArrayBuffer(8196);
const sharedArray = new Int32Array(sab)
const wasmWorker = new Worker("wasm_worker_wasm.js");
var inputString = ''; // stores keyboard input
var commandIsRunning = false;

function wakeUpWorker(chunkSize) {
	const d = new Date();
	let resultStorage = -1;
	let resultNotify = -1;
	let tries = 0;
	resultStorage = Atomics.store(sharedArray, 0, chunkSize + 1);
	resultNotify = Atomics.notify(sharedArray, 0);

	while ((resultStorage !=  chunkSize +1) && (resultNotify != 0) && (tries < 10)) {
		resultStorage = Atomics.store(sharedArray, 0, chunkSize + 1);
		resultNotify = Atomics.notify(sharedArray, 0);
		tries += 1;
	}
}

function executeWebAssembly(bufferString, args, cwd, tty, env) {
	inputString = '';
	commandIsRunning = true;
	// create a webWorker to run webAssembly code:
	wasmWorker.postMessage([bufferString, args, cwd, tty, env, sab]);
	let result = "";
	
	// Dealing with communications with the system:
	wasmWorker.onmessage =(e) => {
		// system calls go through the "prompt()" command
		// Easiest way to make it synchronous
		if (e.data[0] == "prompt") {
			sharedArray[0] = 0;
			Atomics.store(sharedArray, 0, 0);
			result = prompt(e.data[1]);
			// Sending the data to the worker by slices of 2047 bytes:
			// (need to keep one for length of each chunk)
			// The CPU side has already truncated data at ^D.
			let chunkSize = result.length;
			if (chunkSize > 8192) chunkSize = 8192;
			let chunk = result.substring(0, chunkSize);
			for (var i = 0, j = 1; i < chunkSize; i+=4, j++) {
				sharedArray[j] = chunk.charCodeAt(i) 
					| (chunk.charCodeAt(i+1) << 8)
					| (chunk.charCodeAt(i+2) << 16)
				    | (chunk.charCodeAt(i+3) << 24);
			}
			result = result.substring(chunkSize);
			wakeUpWorker(chunkSize);
		} else if (e.data[0] == "keyboard") { // keyboard input
			let length = Number(e.data[1]);
			result = inputString.substring(0, length); // send what was asked
			let chunkSize = result.length;
			if (chunkSize > 2047) chunkSize = 2047;
			let chunk = result.substring(0, chunkSize);
			for (var i = 0; i < chunkSize; i++) {
				sharedArray[i+1] = chunk.charCodeAt(i);
				// cut after ^D if present, only send up to ^D
				if (chunk.charCodeAt(i) == 4)
					break;
			}
			chunkSize = chunk.length;
			result = result.substring(chunkSize);
			inputString = inputString.substring(chunkSize); // remove what's already been sent
			Atomics.store(sharedArray, 0, chunkSize + 1);
			Atomics.notify(sharedArray, 0);
		} else if (e.data[0] == "sendNextChunk") {
			sharedArray[0] = 0;
			Atomics.store(sharedArray, 0, 0);
			let chunkSize = result.length;
			if (chunkSize > 8192) chunkSize = 8192;
			let chunk = result.substring(0, chunkSize);
			for (var i = 0, j=1; i < chunkSize; i+=4, j++) {
				sharedArray[j] = chunk.charCodeAt(i) 
					| (chunk.charCodeAt(i+1) << 8)
					| (chunk.charCodeAt(i+2) << 16)
				    | (chunk.charCodeAt(i+3) << 24);
			}
			result = result.substring(chunkSize);
			wakeUpWorker(chunkSize);
		} else if (e.data[0] == "commandTerminated") {
			// We need the "command is finished" signal to be in sync with the printing, 
			// so it uses the same signal transmission system:
			commandIsRunning = false;
			prompt("libc\ncommandTerminated\n" + e.data[1] + "\n" + e.data[2]);
		}
	}
}
