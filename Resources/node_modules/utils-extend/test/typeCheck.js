var assert = require('assert');
var util = require('../index');

describe('Type check', function() {
  it('isObject', function() {
    var fn = function() {};

    assert.equal(true, util.isObject({}));
    assert.equal(false, util.isObject([]));
    assert.equal(false, util.isObject(fn));
  });

  it('isString', function() {
    assert.equal(true, util.isString(''));
    assert.equal(false, util.isString(/a/));
  });
  
  it('isNumber', function() {
    assert.equal(true, util.isNumber(1));
    assert.equal(false, util.isNumber('1'));
  });

  it('isDate', function() {
    var now = new Date();

    assert.equal(true, util.isDate(now));
  });

  it('isRegExp', function() {
    var reg = /a/;

    assert.equal(true, util.isRegExp(reg));
  });

  it('isArray', function() {
    assert.equal(true, util.isArray([]));
  });

  it('isUndefined', function() {
    var a;

    assert.equal(true, util.isUndefined(a));
  });
});