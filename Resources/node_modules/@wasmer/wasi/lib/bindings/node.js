"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const crypto = require("crypto");
const fs = require("fs");
const { isatty: isTTY } = require("tty");
const path = require("path");
const hrtime_bigint_1 = require("../polyfills/hrtime.bigint");
let bigIntHrtime = hrtime_bigint_1.default(process.hrtime);
if (process.hrtime && process.hrtime.bigint) {
    bigIntHrtime = process.hrtime.bigint;
}
const bindings = {
    hrtime: bigIntHrtime,
    exit: (code) => {
        process.exit(code);
    },
    kill: (signal) => {
        process.kill(process.pid, signal);
    },
    randomFillSync: crypto.randomFillSync,
    isTTY: isTTY,
    fs: fs,
    path: path
};
exports.default = bindings;
