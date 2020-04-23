'use strict';

Object.defineProperty(exports, "__esModule", {
    value: true
});
exports.patchRequire = exports.patchFs = undefined;

var _patchFs = require('./patchFs');

var _patchFs2 = _interopRequireDefault(_patchFs);

var _patchRequire = require('./patchRequire');

var _patchRequire2 = _interopRequireDefault(_patchRequire);

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

exports.patchFs = _patchFs2.default;
exports.patchRequire = _patchRequire2.default;