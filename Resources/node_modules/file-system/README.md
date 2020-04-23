# file-system — Simplified file system
[![NPM](https://nodei.co/npm/file-system.png?downloads=true&downloadRank=true&stars=true)](https://nodei.co/npm/file-system/)

This module make file opertaion apis simple, you don't need to care the dir exits. and the api is same as node's filesystem. This is no exists time cost for this plugin.  
```js
var fs = require('file-system');

fs.mkdir('1/2/3/4/5', [mode], function(err) {});
fs.mkdirSync('1/2/3/4/5', [mode]);
fs.writeFile('path/test.txt', 'aaa', function(err) {})
```

### install
```
npm install file-system --save
```

## API
### .fs
file extend node fs origin methods, and overwrite some methods with next list chart
```js
var file = require('file-system');
var fs = require('fs');

file.readFile === fs.readFile // true
```

### .mkdir
The api is same as node's mkdir

### .mkdirSync
The api is same as node's mkdir

### .writeFile
The api is same as node's writeFile

### .writeFileSync
The api is same as node's writeFile

### .fileMatch
The api equal [file-match](https://github.com/douzi8/file-match)
      
### .copyFile(srcpath, destpath, options)
Asynchronously copy a file into newpath
* {string} ``srcpath`` required
* {string} ``destpath`` required
* {object} ``options``
  * {string} ``options.encoding`` [options.encoding=utf8]
  * {function} ``options.done(err)``
  * {function} ``options.process(content)``  
  The process argument must return processed content
```js
fs.copyFile('deom.png', 'dest/demo.png', {
  done: function(err) {
    console.log('done');
  }
});
```

### .copyFileSync(srcpath, destpath, options)
The api same as copyFile, but it's synchronous
```js
fs.copyFileSync('demo.png', 'dest/demo.png');
fs.copyFileSync('demo.css', 'dest/demo.css', {
  process: function(contents) {
    return contents;
  }
})
```

### .recurse(dirpath, filter, callback)
Recurse into a directory, executing callback for each file and folder.
if the filename is undefiend, the callback is for folder, otherwise for file.
* {string} ``dirpath`` required
* {string|array|function} ``filter``  
If the filter is function, executing callback for all files and folder 
* {function} ``callback(filepath, filename, relative)``
```js
fs.recurse('path', function(filepath, relative, filename) { });

fs.recurse('path', [
  '*.css',
  '**/*.js', 
  'path/*.html',
  '!**/path/*.js'
], function(filepath, relative, filename) {  
  if (filename) {
  // it's file
  } else {
  // it's folder
  }
});

//  Only using files
fs.recurse('path', function(filepath, relative, filename) {  
  if (!filename) return;
});
```
[filter params description](https://github.com/douzi8/file-match#filter-description)

### .recurseSync(dirpath, filter, callback)
The api is same as recurse, but it is synchronous
```js
fs.recurseSync('path', function(filepath, relative, filename) {
  
});

fs.recurseSync('path', ['**/*.js', 'path/**/*.html'], function(filepath, relative, filename) {
  
});
```

### .rmdirSync(dirpath)
Recurse into a directory, remove all of the files and folder in this directory.
```js
fs.rmdirSync('path');
```

### .copySync(dirpath, destpath, options)
Recurse into a directory, copy all files into dest.
* {string} ``dirpath`` required
* {string} ``destpath`` required
* {object} ``options``
  * {string|array} ``options.filter``
  * {function} ``options.process(contents, filepath, relative)``  
  If custom the destpath, return object, otherwise return content
  * {string|array} ``options.noProcess``
```js
fs.copySync('path', 'dest', { clear: true });

fs.copySync('src', 'dest/src');

fs.copySync('src', 'dest/src', { filter: ['*.js', 'path/**/*.css'] });

fs.copySync('path', 'dest', { 
  noProcess: '**/*.{jpg, png}',            // Don't process images
  process: function(contents, filepath, relative) {
    // only process file content
    return contents;
    // or custom destpath
    return {
      contents: '',
      filepath: ''
    };
  } 
});

//Handler self files
fs.copySync('path', 'path', { filter: ['*.html.js'], process: function(contents, filepath) {} });
```

### .base64
Deprecated, move to [base64](https://github.com/douzi8/base64-img#base64filename-callback)
### .base64Sync
Deprecated, move to [base64Sync](https://github.com/douzi8/base64-img#base64syncfilename)