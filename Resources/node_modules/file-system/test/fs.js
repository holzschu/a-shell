var assert = require("assert");
var file = require('../file-system');
var path = require('path');
var fs = require('fs');

function getPath(filepath) {
  return path.join(__dirname, filepath);
}

describe('extend fs', function() {
  var allFiles = [
    [
      getPath('var/fs/1.html'),
      getPath('var/fs/index.html')
    ]
  ];

  before(function() {
    allFiles.forEach(function(files) {
      files.forEach(function(item) {
        file.writeFileSync(item);
      });
    });
  });

  it('node fs object', function() {
    assert.equal(file.fs, fs);
  });

  it('node origin methods', function() {
    var srcPath = getPath('var/fs/mkdir');

    file.fs.mkdirSync(srcPath);

    var exists = file.existsSync(srcPath);

    assert.equal(exists, true);
  });

  after(function() {
    file.rmdirSync(getPath('var/fs'));
  });
});