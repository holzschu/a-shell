'use strict';

var _lib = require('../../../memfs/lib');

var _index = require('../index');

_lib.vol.fromJSON({ '/dir/foo': 'bar' });
(0, _index.patchFs)(_lib.vol);
console.log(require('fs').readdirSync('/'));