var slice = Array.prototype.slice;

exports.extend = function extend(a, b) {
    for(var key in b) a[key] = b[key];

    return arguments.length < 3
        ? a
        : extend.apply(null, [a].concat(slice.call(arguments, 2)));
}
