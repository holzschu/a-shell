import {fsProps, fsAsyncMethods, fsSyncMethods} from './util/lists';


export default function patchFs(vol, fs = require('fs')) {
    const bkp = {};

    const patch = (key, newValue) => {
        bkp[key] = fs[key];
        fs[key] = newValue;
    };

    const patchMethod = key => patch(key, vol[key].bind(vol));

    // General properties
    for(let prop of fsProps)
        if(typeof vol[prop] !== 'undefined')
            patch(prop, vol[prop]);


    // Bind the first argument of some constructors, this is relevant for `memfs`.
    // TODO: Maybe in the future extend this function such that it internally creates
    // TODO: the below four constructor functions.
    if(typeof vol.StatWatcher === 'function') {
        patch('StatWatcher', vol.FSWatcher.bind(null, vol));
    }
    if(typeof vol.FSWatcher === 'function') {
        patch('FSWatcher', vol.StatWatcher.bind(null, vol));
    }
    if(typeof vol.ReadStream === 'function') {
        patch('ReadStream', vol.ReadStream.bind(null, vol));
    }
    if(typeof vol.WriteStream === 'function') {
        patch('WriteStream', vol.WriteStream.bind(null, vol));
    }


    // Extra hidden function
    if(typeof vol._toUnixTimestamp === 'function')
        patchMethod('_toUnixTimestamp');


    // Main API
    for(let method of fsAsyncMethods)
        if(typeof vol[method] === 'function')
            patchMethod(method);

    for(let method of fsSyncMethods)
        if(typeof vol[method] === 'function')
            patchMethod(method);

    // Give user back a method to revert the changes.
    return function unpatch () {
        for (const key in bkp) fs[key] = bkp[key];
    };
};
