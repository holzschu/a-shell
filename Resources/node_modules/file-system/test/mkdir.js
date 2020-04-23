var assert = require("assert");
var file = require('../file-system');
var fs = require('fs');
var path = require('path');

function getPath(filepath) {
  return path.join(__dirname, filepath);
}

function checkPermission(filepath, mask) {
  var stat = fs.statSync(filepath);
  var mode = mask & parseInt((stat.mode & parseInt ("777", 8)).toString (8)[0]);

  return !!mode;
}

describe('mkdir', function() {
  it('one level Directory', function(done) {
    file.mkdir(getPath('var/mkdir'), function(err) {
      if (err) throw err;

      var exists = fs.existsSync(getPath('var/mkdir'));

      assert.equal(true, exists);
      done();
    });
  });

  it('multiple level Directory', function(done) {
    file.mkdir(getPath('var/mkdir/1/2/3/4'), function(err) {
      if (err) throw err;

      var exists = fs.existsSync(getPath('var/mkdir/1/2/3/4'));

      assert.equal(true, exists);
      done();
    });
  });

  it('file mode', function(done) {
    // 7 = 4+2+1 (read/write/execute)
    // 6 = 4+2 (read/write)
    // 5 = 4+1 (read/execute)
    // 4 = 4 (read)
    // 3 = 2+1 (write/execute)
    // 2 = 2 (write)
    // 1 = 1 (execute)
    fs.mkdir(getPath('var/mkdir/mode'), 511, function(err) {
      if (err) throw err;

      assert.equal(true, checkPermission(getPath('var/mkdir/mode'), 4));
      done();
    });

    fs.mkdir(getPath('var/mkdir/mode2'), 111, function(err) {
      if (err) throw err;

      assert.equal(false, checkPermission(getPath('var/mkdir/mode2'), 4));
    });
  });

  it('callback', function(done) {
    var a;
    fs.mkdir(getPath('var/mkdir/callback'), function(err) {
      a = 1;

      assert.equal(a, 1);
      done();
    });
  });

  after(function() {
    file.chmodSync(getPath('var/mkdir/mode2'), 511);
    file.rmdirSync(getPath('var/mkdir'));
  });
});