"use strict";
var __spreadArrays = (this && this.__spreadArrays) || function () {
    for (var s = 0, i = 0, il = arguments.length; i < il; i++) s += arguments[i].length;
    for (var r = Array(s), k = 0, i = 0; i < il; i++)
        for (var a = arguments[i], j = 0, jl = a.length; j < jl; j++, k++)
            r[k] = a[j];
    return r;
};
Object.defineProperty(exports, "__esModule", { value: true });
var buffer_1 = require("buffer");
exports.Buffer = buffer_1.Buffer;
function bufferV0P12Ponyfill(arg0) {
    var args = [];
    for (var _i = 1; _i < arguments.length; _i++) {
        args[_i - 1] = arguments[_i];
    }
    return new (buffer_1.Buffer.bind.apply(buffer_1.Buffer, __spreadArrays([void 0, arg0], args)))();
}
var bufferAllocUnsafe = buffer_1.Buffer.allocUnsafe || bufferV0P12Ponyfill;
exports.bufferAllocUnsafe = bufferAllocUnsafe;
var bufferFrom = buffer_1.Buffer.from || bufferV0P12Ponyfill;
exports.bufferFrom = bufferFrom;
