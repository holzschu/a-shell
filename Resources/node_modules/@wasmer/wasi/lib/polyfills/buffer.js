"use strict";
// Return our buffer depending on browser or node
Object.defineProperty(exports, "__esModule", { value: true });
/*ROLLUP_REPLACE_BROWSER
// @ts-ignore
import { Buffer } from "buffer-es6";
ROLLUP_REPLACE_BROWSER*/
const isomorphicBuffer = Buffer;
exports.default = isomorphicBuffer;
