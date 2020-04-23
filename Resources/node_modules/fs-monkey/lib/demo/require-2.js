'use strict';

var _lib = require('../../../memfs/lib');

var _patchRequire = require('../patchRequire');

var _patchRequire2 = _interopRequireDefault(_patchRequire);

var _fs = require('fs');

var fs = _interopRequireWildcard(_fs);

function _interopRequireWildcard(obj) { if (obj && obj.__esModule) { return obj; } else { var newObj = {}; if (obj != null) { for (var key in obj) { if (Object.prototype.hasOwnProperty.call(obj, key)) newObj[key] = obj[key]; } } newObj.default = obj; return newObj; } }

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

var _require = require('../../../unionfs/lib'),
    ufs = _require.ufs;

_lib.vol.fromJSON({ '/foo/bar.js': 'console.log("obi trice");' });
ufs.use(_lib.vol).use(fs);

(0, _patchRequire2.default)(ufs);
require('/foo/bar.js');