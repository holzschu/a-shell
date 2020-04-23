import * as path from 'path';

const isWin32 = process.platform === 'win32';
const correctPath = isWin32 ? require('./correctPath').correctPath : p => p;

/**
 * Remove byte order marker. This catches EF BB BF (the UTF-8 BOM)
 * because the buffer-to-string conversion in `fs.readFileSync()`
 * translates it to FEFF, the UTF-16 BOM.
 */
function stripBOM(content) {
    if (content.charCodeAt(0) === 0xFEFF) {
        content = content.slice(1);
    }
    return content;
}

/**
 * Rewrites `modules.js`, which is the factory for the `require` function.
 * You give this function your custom file system object and this function
 * will patch `module.js` to use that instead of the built-it `fs.js` file system.
 *
 * This function expects an object with three methods:
 *
 *     patchRequire({
 *         readFileSync: () => {},
 *         realpathSync: () => {},
 *         statSync: () => {},
 *     });
 *
 * The methods should behave like the ones on the native `fs` object.
 *
 * @param {Object} vol
 * @param {Object} Module Module loader to patch.
 */
export default function patchRequire(vol, unixifyPaths = false, Module = require('module')) {

    // ensure all paths are corrected before use.
    if(isWin32 && unixifyPaths) {
        const original = vol;
        vol = {
            readFileSync: (path,options) => {
                return original.readFileSync(correctPath(path),options);
            },
        
            realpathSync: (path) => {
                return original.realpathSync(correctPath(path));
            },
        
            statSync: (path) => {
                return original.statSync(correctPath(path));
            }
        };
    }

    // Used to speed up module loading.  Returns the contents of the file as
    // a string or undefined when the file cannot be opened.  The speedup
    // comes from not creating Error objects on failure.
    function internalModuleReadFile(path) {
        try {
            return vol.readFileSync(path, 'utf8');
        } catch(err) {

        }
    }

    // Used to speed up module loading.  Returns 0 if the path refers to
    // a file, 1 when it's a directory or < 0 on error (usually -ENOENT.)
    // The speedup comes from not creating thousands of Stat and Error objects.
    function internalModuleStat(filename) {
        try {
            return vol.statSync(filename).isDirectory() ? 1 : 0;
        } catch(err) {
            return -2; // ENOENT
        }
    }

    function stat(filename) {
        filename = path._makeLong(filename);
        const cache = stat.cache;
        if (cache !== null) {
            const result = cache.get(filename);
            if (result !== undefined) return result;
        }
        const result = internalModuleStat(filename);
        if (cache !== null) cache.set(filename, result);
        return result;
    }
    stat.cache = null;


    const preserveSymlinks = false;


    function toRealPath(requestPath) {
        return vol.realpathSync(requestPath);
    }


    const packageMainCache = Object.create(null);
    function readPackage(requestPath) {
        const entry = packageMainCache[requestPath];
        if (entry)
            return entry;

        const jsonPath = path.resolve(requestPath, 'package.json');
        const json = internalModuleReadFile(path._makeLong(jsonPath));

        if (json === undefined) {
            return false;
        }

        let pkg;
        try {
            pkg = packageMainCache[requestPath] = JSON.parse(json).main;
        } catch (e) {
            e.path = jsonPath;
            e.message = 'Error parsing ' + jsonPath + ': ' + e.message;
            throw e;
        }
        return pkg;
    }


    function tryFile(requestPath, isMain) {
        const rc = stat(requestPath);
        if (preserveSymlinks && !isMain) {
            return rc === 0 && path.resolve(requestPath);
        }
        return rc === 0 && toRealPath(requestPath);
    }


    // given a path check a the file exists with any of the set extensions
    function tryExtensions(p, exts, isMain) {
        for (var i = 0; i < exts.length; i++) {
            const filename = tryFile(p + exts[i], isMain);

            if (filename) {
                return filename;
            }
        }
        return false;
    }


    function tryPackage(requestPath, exts, isMain) {
        let pkg = readPackage(requestPath);

        if (!pkg) return false;

        let filename = path.resolve(requestPath, pkg);
        return tryFile(filename, isMain) ||
            tryExtensions(filename, exts, isMain) ||
            tryExtensions(path.resolve(filename, 'index'), exts, isMain);
    }


    // Native extension for .js
    Module._extensions['.js'] = function(module, filename) {
        let content = vol.readFileSync(filename, 'utf8');
        module._compile(stripBOM(content), filename);
    };

    // Native extension for .json
    Module._extensions['.json'] = function(module, filename) {
        let content = vol.readFileSync(filename, 'utf8');
        try {
            module.exports = JSON.parse(stripBOM(content));
        } catch (err) {
            err.message = filename + ': ' + err.message;
            throw err;
        }
    };

    let warned = true;
    Module._findPath = function(request, paths, isMain) {
        if (path.isAbsolute(request)) {
            paths = [''];
        } else if (!paths || paths.length === 0) {
            return false;
        }

        var cacheKey = request + '\x00' +
            (paths.length === 1 ? paths[0] : paths.join('\x00'));
        var entry = Module._pathCache[cacheKey];
        if (entry)
            return entry;

        var exts;
        var trailingSlash = request.length > 0 &&
            request.charCodeAt(request.length - 1) === 47/*/*/;

        // For each path
        for (var i = 0; i < paths.length; i++) {
            // Don't search further if path doesn't exist
            const curPath = paths[i];
            if (curPath && stat(curPath) < 1) continue;
            var basePath = correctPath( path.resolve(curPath, request) );
            var filename;

            var rc = stat(basePath);
            if (!trailingSlash) {
                if (rc === 0) {  // File.
                    if (preserveSymlinks && !isMain) {
                        filename = path.resolve(basePath);
                    } else {
                        filename = toRealPath(basePath);
                    }
                } else if (rc === 1) {  // Directory.
                    if (exts === undefined)
                        exts = Object.keys(Module._extensions);
                    filename = tryPackage(basePath, exts, isMain);
                }

                if (!filename) {
                    // try it with each of the extensions
                    if (exts === undefined)
                        exts = Object.keys(Module._extensions);
                    filename = tryExtensions(basePath, exts, isMain);
                }
            }

            if (!filename && rc === 1) {  // Directory.
                if (exts === undefined)
                    exts = Object.keys(Module._extensions);
                filename = tryPackage(basePath, exts, isMain);
            }

            if (!filename && rc === 1) {  // Directory.
                // try it with each of the extensions at "index"
                if (exts === undefined)
                    exts = Object.keys(Module._extensions);
                filename = tryExtensions(path.resolve(basePath, 'index'), exts, isMain);
            }

            if (filename) {
                // Warn once if '.' resolved outside the module dir
                if (request === '.' && i > 0) {
                    if (!warned) {
                        warned = true;
                        process.emitWarning(
                            'warning: require(\'.\') resolved outside the package ' +
                            'directory. This functionality is deprecated and will be removed ' +
                            'soon.',
                            'DeprecationWarning', 'DEP0019');
                    }
                }

                Module._pathCache[cacheKey] = filename;
                return filename;
            }
        }
        return false;
    };
}
