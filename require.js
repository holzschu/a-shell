//
//  This file is part of //\ Tarp.
//
//  Copyright (C) 2013-2020 Torben Haase <https://pixelsvsbytes.com>
//
//  Tarp is free software: you can redistribute it and/or modify it under the
//  terms of the GNU Lesser General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option)
//  any later version.
//
//  Tarp is distributed in the hope that it will be useful, but WITHOUT ANY
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
//  details. You should have received a copy of the GNU Lesser General Public
//  License along with Tarp. If not, see <https://www.gnu.org/licenses/>.
//
////////////////////////////////////////////////////////////////////////////////

// NOTE The load parameter points to the function, which prepares the
//      environment for each module and runs its code. Scroll down to the end of
//      the file to see the function definition.
(self.Tarp = self.Tarp || {}).require = function(config) {
	// iOS changes: all loading is synchronous
	// Should be config. How can I make it config?
  "use strict";

  function resolve(id, pwd, suffix) {
    var matches = id.match(/^((\.)?.*\/|)(.[^.]*|)(\..*|)$/);
    return (new URL(
      // matches[1] + matches[3] + (matches[3] && (matches[4] || ".js")),
      matches[1] + matches[3] + matches[4] + suffix,
      pwd
    )).href;
  }

  function load(id, pwd, suffix, asyn) {
    var href, cached, request;
    // NOTE resolve href from id.
    href = config.resolve(id, pwd, suffix, resolve);
    // NOTE create cache item if required.
    cached = cache[href] = cache[href] || {
      e: undefined, // error
      m: undefined, // module
      p: undefined, // promise
      r: undefined, // request
      s: undefined, // source
      t: undefined, // type
      u: href, // url
    };
    if (!cached.p) {
      cached.p = new Promise(function(res, rej) {
        request = cached.r = new XMLHttpRequest();
        request.onload = request.onerror = function() {
          var tmp, done, source, pattern, match, loading = 0, pwd2;
          if (request.responseText == "") {
          	  rej(cached.e = new Error("Empty file " + href + " " + request.status));
          	  return null;
		  }
          // `request` might have been changed by line 54.
          if (request = cached.r) {
            cached.r = null;
            if (((request.status > 99) || (request.status == 0)) && ((href = request.responseURL || href) != cached.u)) {
              if (cache[href]) {
                cached = cache[cached.u] = cache[href];
                cached.p.then(res, rej);
                // NOTE Replace pending request of actual module with the already completed request and abort the
                //      pending request.
                if (cached.r) {
                  tmp = cached.r;
                  cached.r = request;
                  tmp.abort();
                  tmp.onload();
                }
                return;
              }
              else {
                cached.u = href;
                cache[href] = cached;
              }
            }
            // iOS returns 0 for succesful sync http queries
            if ((request.status == 0) || ((request.status > 99) && (request.status < 400))) {
              // console.log("Loaded: " + href); 
     		  // window.webkit.messageHandlers.aShell.postMessage('JS loaded ' + href);                  	  
              cached.s = source = request.responseText;
              cached.t = request.getResponseHeader("Content-Type");
              	// iOS: ensure we get application/json set
				var regex = /\.json$/;
				if (regex.test(href)) {
					cached.t = "application/json";
				}
              done = function() { if (--loading < 0) res(cached); };
              // NOTE Pre-load submodules if the request is asynchronous (request.$ is true).
              if (request.$) {
                // Remove comments from the source
                source = source.replace(/\/\/.*|\/\*[\s\S]*?\*\//g, '');
                // TODO Write a real parser that returns all modules that are preloadable.
                pattern = /require\s*(?:\.\s*resolve\s*(?:\.\s*paths\s*)?)?\(\s*(?:"((?:[^"\\]|\\.)+)"|'((?:[^'\\]|\\.)+)')\s*\)/g;
                while((match = pattern.exec(source)) !== null) {
                  // NOTE Only add modules to the loading-queue that are still pending.
                  pwd2 = (new URL((match[1]||match[2])[0] == "." ? href : config.paths[0], config.root)).href;
                  if ((tmp = load(match[1]||match[2], pwd2, true)).r) {
                    loading++;
                    tmp.p.then(done, done);
                  }
                }
              }
              done();
            }
            else {
              rej(cached.e = new Error(href + " " + request.status));
            }
          }
        };
      });
    }
    // NOTE `request` is only defined if the module is requested for the first time.
    if (request = request || (!asyn && cached.r)) {
      try {
        request.abort();
        request.$ = asyn;
        // NOTE IE requires a true boolean value as third param.
        request.open("GET", href, !!asyn);
        request.send();
      }
      catch (e) {
        request.onerror();
      }
    }
    if (cached.e) {
      return null; 
      // throw cached.e;
	}
    return cached;
  }

  function evaluate(cached, parent) {
    var module;
    if (!cached.m) {
      module = cached.m = {
        children: new Array(),
        exports: new Object(),
        filename: cached.u,
        id: cached.u,
        loaded: false,
        parent: parent,
        paths: config.paths.slice(),
        require: undefined,
        uri: cached.u
      },
      module.require = factory(module);
      parent && parent.children.push(module);
      if (cached.t == "application/json") {
        module.exports = JSON.parse(cached.s);
	  } else
        (new Function(
          "exports,require,module,__filename,__dirname",
          cached.s + "\n//# sourceURL=" + module.uri
        ))(module.exports, module.require, module, module.uri, module.uri.match(/.*\//)[0]);
      module.loaded = true;
    }
    return cached.m;
  }

  function factory(parent) {
    function requireEngine(mode, id, asyn) {
      function afterLoad(cached) {
        var regex = /package\.json$/;
        if (regex.test(cached.u) && !regex.test(id)) {
          // iOS: content-type is not set, so we set it manually
          var pkg = evaluate(cached, parent);
          return typeof pkg.exports.main == "string" ?
            (factory(pkg))(pkg.exports.main.replace(/^\.*\/*/, "./"), asyn): // */ (close comment for editor parsing)
            pkg.exports;
        }
        else if (mode == 1)
          return cached.u;
        else if (mode == 2)
          return [pwd.match(/.*\//)[0]];
        else
          return evaluate(cached, parent).exports;
      }

      var pwd = (new URL(id[0] == "." ? (parent ? parent.uri : config.root) : config.paths[0], config.root)).href;
      var cachedModule = load(id, pwd, "", false); // no suffix at all
      	// "browser" modules must take priority over package.json 
      	// This might be a larger issue: package.json contains (often) index.js
      	// Could be: "replace index.js with browser.js" (if it exists)
      	// Or: edit package.json in the few relevant cases.
      if (cachedModule == null) {
		 cachedModule = load(id, pwd, "/browser.js", false);
	  }
      if (cachedModule == null) {
		 cachedModule = load(id, pwd, "-browserify/index.js", false);
	  }
	  	// package.json contains the name of the module
      if (cachedModule == null) {
		 cachedModule = load(id, pwd, "/package.json", false);
	  }
      if (cachedModule == null) {
		 cachedModule = load(id, pwd, ".js", false);
	  }
      if (cachedModule == null) {
		 cachedModule = load(id, pwd, "/index.js", false);
	  }
      if (cachedModule == null) {
		 cachedModule = load(id, pwd, "/" + id + ".js", false);
	  }
      if (cachedModule == null) {
      	  throw Error("Could not find module " + id)
	  }
      return afterLoad(cachedModule); 
      /* return asyn ?
        new Promise(function(res, rej) { load(id, pwd, "/index.js", asyn).p.then(afterLoad).then(res, rej); }):
        afterLoad(load(id, pwd, "/index.js", asyn)); */
    }

    var require = requireEngine.bind(undefined, 0);
    require.resolve = requireEngine.bind(require, 1);
    require.resolve.paths = requireEngine.bind(require.resolve, 2);
    return require;
  }

  var cache, require;

  // NOTE Web-worker will use the origin, since location.href is not available.
  cache = Object.create(null);
  config = config || new Object();
  config.paths = config.paths || ["./node_modules/"];
  config.resolve = config.resolve || resolve;
  config.root = config.root || location.href;
  require = factory(null);
  if (config.expose)
    self.require = require;
  if (config.main)
    return require(config.main, !config.sync);
};
