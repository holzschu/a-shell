var assert = require("assert");
var file = require('../file-system');
var fs = require('fs');
var path = require('path');

function getPath(filepath) {
  return path.join(__dirname, filepath);
}

describe('copy', function() {
  var allFiles = [
    [
      getPath('var/copy/simple/1/demo.html'),
      getPath('var/copy/simple/1/demo.css'),
      getPath('var/copy/simple/1/demo.js'),
      getPath('var/copy/simple/1/2/demo.css'),
      getPath('var/copy/simple/1/2/demo.html'),
      getPath('var/copy/simple/file.js/demo.css'),
      getPath('var/copy/simple/demo.js'),
      getPath('var/copy/simple/demo.css')
    ]
  ];

  before(function() {
    allFiles.forEach(function(files) {
      files.forEach(function(item) {
        file.writeFileSync(item, 'a');
      });
    });
  });

  it('copySync files with filter', function() {
    var dirpath = getPath('var/copy/simple');
    var destpath = getPath('var/copy/simpledest');

    file.copySync(dirpath, destpath, {
      filter: [
        '**/*.js',
        '1/**/*.css',
        '1/demo.html'
      ]
    });

    var dirDest = [
      getPath('var/copy/simpledest/1/demo.html'),
      getPath('var/copy/simpledest/1/demo.css'),
      getPath('var/copy/simpledest/1/2/demo.css'),
      getPath('var/copy/simpledest/1/demo.js'),
      getPath('var/copy/simpledest/demo.js')
    ];
    var result = [];

    file.recurseSync(destpath, function(filepath, relative,filename) {
      if (!filename) return;

      result.push(filepath);
    });

    assert.equal(result.length, dirDest.length);
  });

  it('copySync replace filepath', function() {
    var dirpath = getPath('var/copy/simple');
    var destpath = getPath('var/copy/simple-replace');

    file.copySync(dirpath, destpath, {
      process: function(contents, filepath, relative) {
        var basename = path.basename(filepath);
        var newpath = path.join(destpath, relative);

        // Validate relative
        assert(path.relative(dirpath, filepath), relative);

        // Replace html to txt
        newpath = newpath.replace(
          /\.html$/,
          '.txt'
        );

        // Move all css to rootpath of destpath
        if (/\.css$/.test(basename)) {
          var prefix = path.basename(path.dirname(newpath));
          newpath = path.join(destpath, prefix + '-' + basename);
        }

        return {
          contents: contents,
          filepath: newpath
        };
      }
    });

    assert.equal(true, file.existsSync(
      path.join(destpath, '1/demo.txt')
    ));
  });

  it('copySync with noProcess', function() {
    var dirpath = getPath('var/copy/simple');
    var destpath = getPath('var/copy/simple-noprocess');

    file.copySync(dirpath, destpath, {
      filter: [
        '**/*demo.css',
        '!**/1/demo.css'
      ],
      noProcess: 'demo.css',
      process: function(contents, filepath) {
        return 'b';
      }
    });

    assert.equal(true, file.existsSync(
      path.join(destpath, 'demo.css')
    ));

    assert.equal(false, file.existsSync(
      path.join(destpath, '1/demo.css')
    ));

    assert.equal(true, file.existsSync(
      path.join(destpath, '1/2/demo.css')
    ));

    assert.equal(true, file.existsSync(
      path.join(destpath, 'file.js/demo.css')
    ));

    var content = file.readFileSync(
      path.join(destpath, 'demo.css'),
      { encoding: 'utf8' }
    );

    assert.equal('a',  content);
  });


  after(function() {
   file.rmdirSync(getPath('var/copy'));
  });
});