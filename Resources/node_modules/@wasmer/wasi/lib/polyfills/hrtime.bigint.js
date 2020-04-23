"use strict";
// Simply polyfill for hrtime
// https://nodejs.org/api/process.html#process_process_hrtime_time
Object.defineProperty(exports, "__esModule", { value: true });
const NS_PER_SEC = 1e9;
const getBigIntHrtime = (nativeHrtime) => {
    return (time) => {
        const diff = nativeHrtime(time);
        // Return the time
        return (diff[0] * NS_PER_SEC + diff[1]);
    };
};
exports.default = getBigIntHrtime;
