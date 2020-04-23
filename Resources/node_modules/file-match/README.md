file-match
==========

Match filepath is validated, or exclude filepath that don't need

```js
var fileMatch = require('file-match');

var filter = fileMatch('*.js');

filter('a.js');            // true
filter('path/a.js');       // false

var filter = fileMatch([
  '**/*',
  '!path/*.js'
  '!img/**/.{jpg,png,gif}'
]);

filter('src/demo.js')           // true
filter('path/demo.js')          // false
filter('path/path/demo.js')     // true
filter('img/demo.png')          // false
filter('img/path/demo.png')     // false

var filter = fileMatch([
  'path/*.js'
], true);

```

If the filter value is empty string or empty arry, it will always return false,
if it's ``null``, will always return true.

#### filter description
* `*.js`  only match js files in current dir.
* `**/*.js` match all js files.
* `path/*.js` match js files in path.
* `!*.js` exclude js files in current dir.
* ``.{jpg,png,gif}`` means jpg, png or gif
```
'**/*'                 // Match all files
'!**/*.js'             // Exclude all js files
'**/*.{jpg,png,gif}'   // Match jpg, png, or gif files
```

### ignore case
* ignore {boolean} [ignore = false]