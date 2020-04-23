var assert = require("assert");
var file = require('../file-system');
var fs = require('fs');
var path = require('path');

function getPath(filepath) {
  return path.join(__dirname, filepath);
}

describe('recurse', function() {
  var allFiles = [
    [
      getPath('var/recurse/simple/1/1.html'),
      getPath('var/recurse/simple/1/2.html'),
      getPath('var/recurse/simple/1.html')
    ],
    [
      getPath('var/recurse/filter/1/demo.js'),
      getPath('var/recurse/filter/1/2/demo.js'),
      getPath('var/recurse/filter/1/2/demo.css'),
      getPath('var/recurse/filter/1/2/demo.html'),
      getPath('var/recurse/filter/demo.html'),
      getPath('var/recurse/filter/demo.js'),
      getPath('var/recurse/filter/demo.css')
    ],
    [
      getPath('var/recurse/copy/1/demo.js'),
      getPath('var/recurse/copy/1/2/demo.js'),
      getPath('var/recurse/copy/1/2/demo.css'),
      getPath('var/recurse/copy/1/2/demo.html'),
      getPath('var/recurse/copy/demo.html'),
      getPath('var/recurse/copy/demo.js'),
      getPath('var/recurse/copy/demo.css')
    ]
  ];

  before(function() {
    allFiles.forEach(function(files) {
      files.forEach(function(item) {
        file.writeFileSync(item);
      });
    });
  });

  it('recurse files', function(done) {
    var filesPath = allFiles[0];
    var count = 0;

    file.recurse(getPath('var/recurse/simple'), function(filepath, relative, filename) {
      if (filename) {
        assert.equal(true, filesPath.indexOf(filepath) != -1);
        
        if (++count == filesPath.length) {
          done();
        }
      }
    });
  });

  it('recurseSync files', function() {
    var filesPath = [];
    file.recurseSync(getPath('var/recurse/filter'), function(filepath, relative, filename) {
      if (filename) {
        filesPath.push(filepath);
      }
    });

     assert.equal(filesPath.length, allFiles[1].length);
  });

  it('recurseSync filter files', function() {
    var filesPath = [];
    file.recurseSync(getPath('var/recurse/filter'), [
      'demo.js',
      '1/**/*.css'
    ], function(filepath, filename) {
      if (filename) {
        filesPath.push(filepath);
      }
    });
    var filterPath = [
      getPath('var/recurse/filter/1/2/demo.css'),
      getPath('var/recurse/filter/demo.js')
    ];

     assert.deepEqual(filesPath, filterPath);
  });

  it('copySync files', function() {
    var dest = getPath('var/recurse/dest');
    var destFiles = [];

    file.copySync(getPath('var/recurse/copy'), dest);

    file.recurseSync(dest, function(filepath, relative, filename) {
      if (!filename) return;

      destFiles.push(filepath);
    });

    assert.equal(destFiles.length, allFiles[2].length);
  });

  it('copySync empty folder', function() {
    var dest = getPath('var/recurse/copy/emptydest');
    var src = getPath('var/recurse/copy/empty');

    file.mkdirSync(src);
    file.copySync(src, dest);

    var existsSync = fs.existsSync(dest);

    assert.equal(existsSync, true);
  });

  it('copySync process content', function() {
    var src = getPath('var/recurse/copyprocess/');
    var dest = getPath('var/recurse/copyprocess/dest');

    file.writeFileSync(path.join(src, '1.html'), 'a');

    file.copySync(src, dest, {
      process: function(contents, filepath) {
        return 'b';
      }
    });

     var contents = fs.readFileSync(path.join(dest, '1.html'));

     assert.equal('b',  contents);
  });

  after(function() {
    file.rmdirSync(getPath('var/recurse'));
  });
});