var assert = require('assert');
var fileMatch = require('../file-match');

describe('File match', function() {
  describe('empty value', function() {
    it('Empty string', function() {
      var filter = fileMatch('');

      assert.equal(false, filter('demo.js'));
    });

    it('Empty array', function() {
      var filter = fileMatch([]);

      assert.equal(false, filter('demo.js'));
    });

    it('Null', function() {
      var filter = fileMatch(null);

      assert.equal(true, filter('demo.js'));
      assert.equal(true, filter('path/demo.js'));
    });
  });

  describe('Normal value', function() {
    it('String', function() {
      var filter = fileMatch('**/*.js');

      assert.equal(true, filter('demo.js'));
      assert.equal(true, filter('path/demo.js'));
      assert.equal(false, filter('path/.js/demo.css'));
    });

    it('Array', function() {
      var filter = fileMatch([
        '*.js',
        'img/**/*.{png,jgp,gif}',
        'js/my-*.js',
        'css/*.css'
      ]);

      assert.equal(true, filter('demo.js'));
      assert.equal(true, filter('img/demo.png'));
      assert.equal(true, filter('img/path/pic.gif'));
      assert.equal(true, filter('css/demo.css'));
      assert.equal(false, filter('css/src/demo.css'));
      assert.equal(false, filter('img/path/pic.jpeg'));
      assert.equal(true, filter('js/my-.js'));
      assert.equal(true, filter('js/my-demo.js'));
      assert.equal(false, filter('js/my-demo.js.css'));
    });

    it('Exclude', function() {
      var filter = fileMatch([
        '**/*',
        '!.*',
        '!dest/**/*',
        '!img/dest/*.{png, jpg, gif}'
      ]);

      assert.equal(true, filter('img/dest/demo.jpeg'));
      assert.equal(false, filter('.gitignore'));
      assert.equal(true, filter('path/.gitignore'));
      assert.equal(false, filter('dest/demo.css'));
      assert.equal(false, filter('img/dest/demo.jpg'));
    });

    it('Ignore case', function() {
      var filter = fileMatch([
        'path/demo.js'
      ]);

      var filter2 = fileMatch([
        'path/demo.js'
      ], true);

      assert.equal(false, filter('path/DEMO.js'));
      assert.equal(true, filter2('path/DEMO.js'));
    });
  });
});