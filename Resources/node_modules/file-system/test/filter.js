var assert = require("assert");
var file = require('../file-system');
var path = require('path');
var fs = require('fs');

function getPath(filepath) {
  return path.join(__dirname, 'var', filepath);
}

describe('filter params', function() {
  var allFiles = [
    getPath('filter/index.css'),
    getPath('filter/index.js'),
    getPath('filter/index.html'),
    getPath('filter/1/ab.css'),
    getPath('filter/1/abc.js'),
    getPath('filter/1/a.html'),
    getPath('filter/1/1/ac.css'),
    getPath('filter/1/1/bc.js'),
    getPath('filter/1/1/a-b-c.html'),
    getPath('filter/2/a_b_c.css'),
    getPath('filter/2/2/a_b_c.css'),
    getPath('filter/2/a-c.js'),
    getPath('filter/2/b.html')
  ];

  before(function() {
    allFiles.forEach(function(item) {
      file.writeFileSync(item);
    });
  });

  it('match css files in current dir', function() {
    var result = [];

    file.recurseSync(getPath('filter'), [
      '*.css'
    ], function(filepath, filename) {
      if (!filename) return;

      result.push(filepath);
    });

    assert.equal(result.length, 1); 
  });

  it('match all css files', function() {
    var result = [];
    
    file.recurseSync(getPath('filter'), [
      '**/*.css'
    ], function(filepath, filename) {
      if (!filename) return;
      result.push(filepath);
    });

    assert.equal(result.length, 5); 
  });

  it('match all css files in specific folder', function() {
    var result = [];

    file.recurseSync(getPath('filter'), [
      '2/*.css'
    ], function(filepath, filename) {
      if (!filename) return;
      result.push(filepath);
    });

    assert.equal(result.length, 1); 
  });

  it('specific file * name', function() {
    var result = [];

    file.recurseSync(getPath('filter'), [
      '2/**/*c.css'
    ], function(filepath, filename) {
      if (!filename) return;
      result.push(filepath);
    });

    assert.equal(result.length, 2); 
  });

  it('exclude all css files in specific folder', function() {
    var result = [];

    file.recurseSync(getPath('filter'), [
      '**/*.css',
      '!2/**/*.css'
    ], function(filepath, filename) {
      if (!filename) return;
      result.push(filepath);
    });

    assert.equal(result.length, 3); 
  });

  after(function() {
    file.rmdirSync(getPath('filter'));
  });
});