'use strict';

var _index = require('../index');

var myfs = {
    readFileSync: function readFileSync() {
        return 'hello world';
    }
};

(0, _index.patchFs)(myfs);
console.log(require('fs').readFileSync('/foo/bar'));