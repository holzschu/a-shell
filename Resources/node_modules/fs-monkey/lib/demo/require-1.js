'use strict';

var _lib = require('../../../memfs/lib');

var _patchRequire = require('../patchRequire');

var _patchRequire2 = _interopRequireDefault(_patchRequire);

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

_lib.vol.fromJSON({ '/foo/bar.js': 'console.log("obi trice");' });
(0, _patchRequire2.default)(_lib.vol);

require('/foo/bar');