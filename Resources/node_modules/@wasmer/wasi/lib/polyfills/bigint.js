"use strict";
// A very simple workaround for Big int. Works in conjunction with our custom
// Dataview workaround at ./dataview.ts
Object.defineProperty(exports, "__esModule", { value: true });
const globalObj = typeof globalThis !== "undefined"
    ? globalThis
    : typeof global !== "undefined"
        ? global
        : {};
exports.BigIntPolyfill = typeof BigInt !== "undefined" ? BigInt : globalObj.BigInt || Number;
