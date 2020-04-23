var assert = require('assert');
var util = require('../index');

describe('extend', function() {
  it('Two arguments', function() {
    var target = { k: 'v' };
    var source = { k: 'v2' };

    util.extend(target, source);

    assert.deepEqual(target, { k: 'v2' });
  });

  it('More arguments', function() {
    var target = { k: 'v' };
    var source = { k: 'v2' };
    var source2 = { k: 'v3' };

    util.extend(target, source, source2);

    assert.deepEqual(target, { k: 'v3' });
  });

  it('deep clone', function() {
    var target = {};
    var target2 = {
      k1: { age: 5 },
      k3: [{ age: 5 }]
    };
    var source = {
      k1: { k: 'v' },
      k2: [1, 2, 3 ],
      k3: [
        { k: 'v' },
        { k2: 'v2' },
        { k3: 'v3' }
      ]
    };

    util.extend(target, source);
    util.extend(target2, source);
    
    assert.deepEqual(target, source);
    assert.deepEqual(target2, {
      k1: { k: 'v', age: 5 },
      k2: [1, 2, 3],
      k3: [
        { k: 'v', age: 5},
        { k2: 'v2' },
        { k3: 'v3' }
      ]
    });
  });
});