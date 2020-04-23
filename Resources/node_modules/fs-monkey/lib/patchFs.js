'use strict';

Object.defineProperty(exports, "__esModule", {
    value: true
});
exports.default = patchFs;

var _lists = require('./util/lists');

function patchFs(vol) {
    var fs = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : require('fs');

    var bkp = {};

    var patch = function patch(key, newValue) {
        bkp[key] = fs[key];
        fs[key] = newValue;
    };

    var patchMethod = function patchMethod(key) {
        return patch(key, vol[key].bind(vol));
    };

    var _iteratorNormalCompletion = true;
    var _didIteratorError = false;
    var _iteratorError = undefined;

    try {
        for (var _iterator = _lists.fsProps[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true) {
            var prop = _step.value;

            if (typeof vol[prop] !== 'undefined') patch(prop, vol[prop]);
        }
    } catch (err) {
        _didIteratorError = true;
        _iteratorError = err;
    } finally {
        try {
            if (!_iteratorNormalCompletion && _iterator.return) {
                _iterator.return();
            }
        } finally {
            if (_didIteratorError) {
                throw _iteratorError;
            }
        }
    }

    if (typeof vol.StatWatcher === 'function') {
        patch('StatWatcher', vol.FSWatcher.bind(null, vol));
    }
    if (typeof vol.FSWatcher === 'function') {
        patch('FSWatcher', vol.StatWatcher.bind(null, vol));
    }
    if (typeof vol.ReadStream === 'function') {
        patch('ReadStream', vol.ReadStream.bind(null, vol));
    }
    if (typeof vol.WriteStream === 'function') {
        patch('WriteStream', vol.WriteStream.bind(null, vol));
    }

    if (typeof vol._toUnixTimestamp === 'function') patchMethod('_toUnixTimestamp');

    var _iteratorNormalCompletion2 = true;
    var _didIteratorError2 = false;
    var _iteratorError2 = undefined;

    try {
        for (var _iterator2 = _lists.fsAsyncMethods[Symbol.iterator](), _step2; !(_iteratorNormalCompletion2 = (_step2 = _iterator2.next()).done); _iteratorNormalCompletion2 = true) {
            var method = _step2.value;

            if (typeof vol[method] === 'function') patchMethod(method);
        }
    } catch (err) {
        _didIteratorError2 = true;
        _iteratorError2 = err;
    } finally {
        try {
            if (!_iteratorNormalCompletion2 && _iterator2.return) {
                _iterator2.return();
            }
        } finally {
            if (_didIteratorError2) {
                throw _iteratorError2;
            }
        }
    }

    var _iteratorNormalCompletion3 = true;
    var _didIteratorError3 = false;
    var _iteratorError3 = undefined;

    try {
        for (var _iterator3 = _lists.fsSyncMethods[Symbol.iterator](), _step3; !(_iteratorNormalCompletion3 = (_step3 = _iterator3.next()).done); _iteratorNormalCompletion3 = true) {
            var _method = _step3.value;

            if (typeof vol[_method] === 'function') patchMethod(_method);
        }
    } catch (err) {
        _didIteratorError3 = true;
        _iteratorError3 = err;
    } finally {
        try {
            if (!_iteratorNormalCompletion3 && _iterator3.return) {
                _iterator3.return();
            }
        } finally {
            if (_didIteratorError3) {
                throw _iteratorError3;
            }
        }
    }

    return function unpatch() {
        for (var key in bkp) {
            fs[key] = bkp[key];
        }
    };
};