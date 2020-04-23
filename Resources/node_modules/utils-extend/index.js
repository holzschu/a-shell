/**
 * @fileoverview Extend node util module
 * @author douzi <liaowei08@gmail.com> 
 */
var util = require('util');
var toString = Object.prototype.toString;
var isWindows = process.platform === 'win32';

function isObject(value) {
  return toString.call(value) === '[object Object]';
}

// And type check method: isFunction, isString, isNumber, isDate, isRegExp, isObject
['Function', 'String', 'Number', 'Date', 'RegExp'].forEach(function(item) {
  exports['is' + item]  = function(value) {
    return toString.call(value) === '[object ' + item + ']';
  };
});

/**
 * @description
 * Deep extend
 * @example
 * extend({ key: { k1: 'v1'} }, { key: { k2: 'v2' }, none: { k: 'v' } });
 * extend({ arr: [] }, { arr: [ {}, {} ] });
 */
function extend(target, source) {
  var value;

  for (var key in source) {
    value = source[key];

    if (Array.isArray(value)) {
      if (!Array.isArray(target[key])) {
        target[key] = [];
      }

      extend(target[key], value);
    } else if (isObject(value)) {
      if (!isObject(target[key])) {
        target[key]  = {};
      }

      extend(target[key], value);
    } else {
      target[key] = value;
    }
  }

  return target;
}

extend(exports, util);

// fixed util.isObject 
exports.isObject = isObject;

exports.extend = function() {
  var args = Array.prototype.slice.call(arguments, 0);
  var target = args.shift();

  args.forEach(function(item) {
    extend(target, item);
  });

  return target;
};

exports.isArray = Array.isArray;

exports.isUndefined = function(value) {
  return typeof value == 'undefined';
};

exports.noop = function() {};

exports.unique = function(array) {
  var result = [];

  array.forEach(function(item) {
    if (result.indexOf(item) == -1) {
      result.push(item);
    }
  });

  return result;
};

exports.escape = function(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
};

exports.unescape = function(value) {
  return String(value)
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');
};

exports.hrtime = function(time) {
  if (time) {
    var spend = process.hrtime(time);
    
    spend = (spend[0] + spend[1] / 1e9) * 1000 + 'ms';

    return spend;
  } else {
    return process.hrtime();
  }
};

/**
 * @description
 * Return a copy of the object with list keys
 * @example
 * util.pick({ key: 'value' }, 'key', 'key1');
 * util.pick(obj, function(value, key, object) { });
 */
exports.pick = function(obj, iteratee) {
  var result = {};

  if (exports.isFunction(iteratee)) {
    for (var key in obj) {
      var value = obj[key];
      if (iteratee(value, key, obj)) {
        result[key] = value;
      }
    }
  } else {
    var keys = Array.prototype.slice.call(arguments, 1);

    keys.forEach(function(key) {
      if (key in obj) {
        result[key] = obj[key];
      }
    });
  }

  return result;
};

exports.path = {};

if (isWindows) {
  // Regex to split a windows path into three parts: [*, device, slash,
  // tail] windows-only
  var splitDeviceRe =
      /^([a-zA-Z]:|[\\\/]{2}[^\\\/]+[\\\/]+[^\\\/]+)?([\\\/])?([\s\S]*?)$/;

  exports.path.isAbsolute = function(filepath) {
    var result = splitDeviceRe.exec(filepath),
        device = result[1] || '',
        isUnc = !!device && device.charAt(1) !== ':';
    // UNC paths are always absolute
    return !!result[2] || isUnc;
  };

  // Normalize \\ paths to / paths.
  exports.path.unixifyPath = function(filepath) {
    return filepath.replace(/\\/g, '/');
  };

} else {
  exports.path.isAbsolute = function(filepath) {
    return filepath.charAt(0) === '/';
  };

  exports.path.unixifyPath = function(filepath) {
    return filepath;
  };
}