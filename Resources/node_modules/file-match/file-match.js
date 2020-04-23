var util = require('utils-extend');
/**
 * @description
 * @example
 * `**\/*` match all files
 * `*.js`  only match current dir files
 * '**\/*.js' match all js files
 * 'path/*.js' match js files in path
 * '!*.js' exclude js files 
 */
function fileMatch(filter, ignore) {
  if (filter === null) {
    return function() {
      return true;
    };
  } else if (filter === '' || (util.isArray(filter) && !filter.length)) {
    return function() {
      return false;
    };
  }

  if (util.isString(filter)) {
    filter = [filter];
  }

  var match = [];
  var negate = [];
  var isIgnore = ignore ? 'i' : '';

  filter.forEach(function(item) {
    var isNegate = item.indexOf('!') === 0;
    item = item
      .replace(/^!/, '')
      .replace(/\*(?![\/*])/, '[^/]*?')
      .replace('**\/', '([^/]+\/)*')
      .replace(/\{([^\}]+)\}/g, function($1, $2) {
        var collection = $2.split(',');
        var length = collection.length;
        var result = '(?:';

        collection.forEach(function(item, index) {
          result += '(' + item.trim() + ')';

          if (index + 1 !== length) {
            result += '|';
          }
        });

        result += ')';

        return result;
      })
      .replace(/([\/\.])/g, '\\$1');

    item = '(^' + item + '$)';

    if (isNegate) {
      negate.push(item);
    } else {
      match.push(item);
    }
  });

  match = match.length ?  new RegExp(match.join('|'), isIgnore) : null;
  negate = negate.length ? new RegExp(negate.join('|'), isIgnore) : null;

  return function(filepath) {
    // Normalize \\ paths to / paths.
    filepath = util.path.unixifyPath(filepath);

    if (negate && negate.test(filepath)) {
      return false;
    }

    if (match && match.test(filepath)) {
      return true;
    }

    return false;
  };
}

module.exports = fileMatch;