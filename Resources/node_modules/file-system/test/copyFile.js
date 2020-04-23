var assert = require("assert");
var file = require('../file-system');
var fs = require('fs');
var path = require('path');

function getPath(filepath) {
  return path.join(__dirname, filepath);
}

describe('copy file async', function() {
  before(function() {
    file.writeFileSync(getPath('var/copy-file/index.html'), 1);
  });
});

describe('copy file', function() {
  before(function() {
    file.writeFileSync(getPath('var/copy-file/index.html'), 1);
  });

  describe('copy file async', function() {
    it('only copy', function(done) {
      var oldpath = getPath('var/copy-file/index.html');
      var newpath = getPath('var/copy-file/dest/index.async.dest.html');

      file.copyFile(oldpath, newpath, {
        process: function() {
          return 2;
        },
        done: function() {
          var contents = file.readFileSync(newpath, { encoding: 'utf8' });
          assert.equal(2, contents);
          assert.equal(true, file.existsSync(newpath));
          done();
        }
      });
    });

    it('copy image', function(done) {
      var oldpath = getPath('test.png');
      var newpath = getPath('var/copy-file/test.async.dest.png');

      file.copyFile(oldpath, newpath, {
        done: function() {
          assert.equal(file.readFileSync(oldpath).length, file.readFileSync(newpath).length);
          done();
        }
      });
    });
  });

  describe('copy file sync', function() {
    it('only copy', function() {
      var oldpath = getPath('var/copy-file/index.html');
      var newpath = getPath('var/copy-file/dest/index.dest.html');

      file.copyFileSync(oldpath, newpath);
      assert.equal(true, file.existsSync(newpath));
    });

    it('copy with process', function() {
      var oldpath = getPath('var/copy-file/index.html');
      var newpath = getPath('var/copy-file/dest/index.dest.html');

      file.copyFileSync(oldpath, newpath, {
        process: function(contents) {
          return 2;
        }
      });

      var contents = file.readFileSync(newpath, { encoding: 'utf8' });

      assert.equal(2, contents);
    });

    it('copy image', function() {
      var oldpath = getPath('test.png');
      var newpath = getPath('var/copy-file/test.dest.png');

      file.copyFileSync(oldpath, newpath);
      assert.equal(file.readFileSync(oldpath).length, file.readFileSync(newpath).length);
    });
  });

  after(function() {
    file.rmdirSync(getPath('var/copy-file'));
  });
});