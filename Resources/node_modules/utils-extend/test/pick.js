var assert = require('assert');
var util = require('../index');

describe('pick', function() {
  it('Pick with keys', function() {
    var obj = {
      key1: 1,
      key2: 2
    };
    var result = util.pick(obj, 'key1', 'key3');

    assert.deepEqual(result, { key1: 1 });
  });

  it('Pick with function', function() {
    var obj = {
      key1: 1,
      key2: '2',
      key3: {
        k: 'v'
      }
    };
    var result = util.pick(obj, function(value) {
      return util.isNumber(value) || util.isObject(value);
    });

    assert.deepEqual(result, { key1: 1, key3: { k: 'v' } });
  });
});