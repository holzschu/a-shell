const assert = require('node:assert/strict');
const { Worker } = require('node:worker_threads');

const expectError = process.argv[2] === 'error';
const worker = new Worker(expectError
  ? 'throw new Error("worker-boom")'
  : 'const { parentPort, workerData } = require("node:worker_threads"); parentPort.postMessage(workerData * 7)',
{ eval: true, workerData: 6 });
let value;
let error;
worker.on('message', message => { value = message; });
worker.on('error', failure => { error = failure; });
worker.on('exit', status => {
  if (expectError) {
    assert.equal(error?.message, 'worker-boom');
    assert.equal(status, 1);
    console.log('parent caught worker-boom');
  } else {
    assert.equal(error, undefined);
    assert.equal(status, 0);
    assert.equal(value, 42);
    console.log(value);
  }
});
