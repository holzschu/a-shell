import Foundation
import UIKit
import ios_system

// Use the host app's resources and the caller's writable directories in both processes.
@discardableResult
func initializeCommandEnvironment(hostBundle: Bundle, documentsUrl: URL, libraryURL: URL, groupURL: URL?) -> String {
    numPythonInterpreters = 2; // so pip can work (it runs python setup.py). Some packages, eg nexusforge need 3 interpreters.
    //  = a-Shell
    setenv("APPNAME", hostBundle.infoDictionary?["CFBundleName"] as! String, 1)  // a-Shell or a-Shell-mini
    setenv("APPVERSION", hostBundle.infoDictionary?["CFBundleShortVersionString"] as! String, 1) // 1.15.2
    setenv("APPBUILDNUMBER", hostBundle.infoDictionary?["CFBundleVersion"] as! String, 1) // 422
    setenv("VIMRUNTIME", hostBundle.resourcePath! + "/vim", 1); // main resource for vim files
    setenv("TERM_PROGRAM", "a-Shell", 1) // let's inform users of who we are
    setenv("COLORTERM", "truecolor", 1) // tell programs that we can display 16-bit colors (required by Python package rich).
    setenv("SSL_CERT_FILE", hostBundle.resourcePath! +  "/cacert.pem", 1); // SLL cacert.pem in $APPDIR/cacert.pem
    setenv("MAGIC", hostBundle.resourcePath! +  "/usr/share/magic.mgc", 1); // magic file for file command
    setenv("SHORTCUTS", groupURL?.path, 1) // directory used by shortcuts
    setenv("GROUP", groupURL?.path, 1) // directory used by shortcuts
    setenv("MANPATH", hostBundle.resourcePath! +  "/man:" + libraryURL.path + "/man", 1)
    setenv("PAGER", "less", 1) // send control sequences directly to terminal
    setenv("TERM", "xterm-256color", 1); // now that we use SwiftTerm
    setenv("MAGICK_HOME", hostBundle.resourcePath! +  "/ImageMagick-7", 1)
    setenv("MAGICK_CONFIGURE_PATH", hostBundle.resourcePath! +  "/ImageMagick-7/config", 1)
    if (UIDevice.current.model.hasPrefix("iPad")) {
        setenv("PS1", "[\\w]\\$ ", 1) // iPad default prompt: path name
    } else {
        setenv("PS1", "[\\W]\\$ ", 1) // iPhone default prompt: last path component
    }
    setenv("TERMINFO", hostBundle.resourcePath! +  "/terminfo/", 1) // Provide terminfo so termcap has a database
    setenv("TZ", TimeZone.current.identifier, 1) // TimeZone information, since "systemsetup -gettimezone" won't work.
    // Make sure aws (Python package) can work:
    setenv("AWS_SHARED_CREDENTIALS_FILE", documentsUrl.appendingPathComponent(".aws/credentials").path, 1)
    setenv("AWS_CONFIG_FILE", documentsUrl.appendingPathComponent(".aws/config").path, 1)
    // Pip options:
    setenv("PIP_CONFIG_FILE", documentsUrl.appendingPathComponent(".config/pip/pip.conf").path, 1)
    setenv("PIP_NO_BUILD_ISOLATION", "false", 1)
    setenv("SPACEVIMDIR", documentsUrl.appendingPathComponent(".SpaceVim.d").path + "/", 1); // configuration directory for SpaceVim
    // Help aiohttp install itself:
    setenv("YARL_NO_EXTENSIONS", "1", 1)
    setenv("MULTIDICT_NO_EXTENSIONS", "1", 1)
    setenv("AIOHTTP_NO_EXTENSIONS", "1", 1)
    // This one is not required, but it helps:
    setenv("DISABLE_SQLALCHEMY_CEXT", "1", 1)
    var appDependentPath = String(utf8String: getenv("PATH")) ?? ""
    if (hostBundle.infoDictionary?["CFBundleName"] as? String != "a-Shell-mini") {
        // clang options:
        setenv("SYSROOT", libraryURL.path + "/usr", 1) // sysroot for clang compiler
        // set up C and C++ compile options: silently add "--target=wasm32-wasi" at the beginning of arguments
        // and "-lunwind" at the end.
        // use legacy exception handling for iOS 14 to 17, new exception handling for iOS 18 and above.
        // - Apple wasm interpreter accepts the new EH on iOS 18 and above,
        // - wasmkit only accepts the new EH and only runs on iOS 18 and above
        // - wasm3 does not accept any kind of exception handling.
        if #available(iOS 18.0, *) {
            setenv("CCC_OVERRIDE_OPTIONS", "#^--target=wasm32-wasip1 ^-fwasm-exceptions ^-mllvm=-wasm-use-legacy-eh=false +-lunwind", 1)
        } else {
            setenv("CCC_OVERRIDE_OPTIONS", "#^--target=wasm32-wasip1 ^-fwasm-exceptions ^-mllvm=-wasm-use-legacy-eh=true  +-lunwind", 1)
        }
        // TeX variables (for tlmgr to work) = only when installing from scratch
        // default texmf.cnf available:
        // setenv("TEXMFCNF", hostBundle.resourcePath!, 1)
        // Make:
        setenv("MAKESYSPATH", hostBundle.resourcePath! +  "/usr/share/mk" , 1)
        // Perl location of modules:
        setenv("PERL5LIB", documentsUrl.appendingPathComponent("perl5/lib/perl5").path + ":" + hostBundle.resourcePath! +  "/Perl" , 1)
        // set-up for local::lib:
        setenv("PERL_LOCAL_LIB_ROOT", documentsUrl.appendingPathComponent("perl5").path, 1)
        setenv("PERL_CPANM_HOME", documentsUrl.appendingPathComponent(".cpanm").path, 1)
        setenv("PERL_MM_OPT", "'INSTALL_BASE=" + documentsUrl.appendingPathComponent("perl5").path + "'", 1)
        setenv("PERL_MB_OPT", "--install_base \"" + documentsUrl.appendingPathComponent("perl5").path + "\"", 1)
        appDependentPath = documentsUrl.appendingPathComponent("perl5").appendingPathComponent("bin").path + ":" + appDependentPath
        setenv("PATH", appDependentPath, 1)
        setenv("MANPATH", hostBundle.resourcePath! +  "/man:" + libraryURL.path + "/man:" + documentsUrl.appendingPathComponent("perl5").appendingPathComponent("man").path, 1)
        // help Sunpy too: https://github.com/sunpy/sunpy/pull/6166
        setenv("SUNPY_NO_BUILD_ANA_EXTENSION", "1", 1)
        // SUNPY_CONFIGDIR is ~/Library/Application Support/sunpy, by default, so it is OK.
        // default sunpy config file, forces working_dir to ~/Documents/sunpy:
        // data_manager.db has an issue with $HOME but not with ~.
        let sunpyDirectory = libraryURL.appendingPathComponent("Application Support/sunpy")
        let sunpyrcFile = sunpyDirectory.appendingPathComponent("sunpyrc")
        if (!FileManager().fileExists(atPath: sunpyrcFile.path)) {
            if (!FileManager().fileExists(atPath: sunpyDirectory.path)) {
                do {
                    try FileManager().createDirectory(at: sunpyDirectory, withIntermediateDirectories: true)
                }
                catch {}
            }
            if (FileManager().fileExists(atPath: sunpyDirectory.path)) {
                let sunpyrcContent = """
;;;;;;;;;;;;;;;;;;;
; General Options ;
;;;;;;;;;;;;;;;;;;;
[general]

; The SunPy working directory is the parent directory where all generated
; and download files will be stored.
; Default Value: <user's home directory>/sunpy
; data_manager.db has an issue with $HOME but not with ~
working_dir = ~/Documents/sunpy
"""
                let sunpyrcData: Data = sunpyrcContent.data(using: String.Encoding.utf8)!
                FileManager().createFile(atPath: sunpyrcFile.path, contents: sunpyrcData, attributes: nil)
            }
        }
        let nltkData = documentsUrl.appendingPathComponent("nltk_data")
        setenv("NLTK_DATA", nltkData.path, 1)
        setenv("PIP_CONFIG_FILE", documentsUrl.appendingPathComponent(".config/pip/pip.conf").path, 1)
        // Place downloaded files for sunpy in ~/Documents/sunpy
        setenv("SUNPY_DOWNLOADDIR", documentsUrl.appendingPathComponent("sunpy").path, 1)
        // PyProj options:
        setenv("PYPROJ_GLOBAL_CONTEXT", "ON", 1) // This helps pyproj in cleaning up.
        let projDirPath = hostBundle.resourcePath! + "/proj"
        setenv("PROJ_LIB", projDirPath, 1)  // proj <= 9.1
        setenv("PROJ_DATA", projDirPath, 1) // proj 9.1+
        setenv("PROJ_NETWORK", "ON", 1)
        setenv("QUTIP_NUM_PROCESSES", "1", 1) // number of processors in qutip
        let seabornData = libraryURL.appendingPathComponent("seaborn-data")
        setenv("SEABORN_DATA", seabornData.path, 1)
        let sklearnData = libraryURL.appendingPathComponent("scikit_learn_data")
        setenv("SCIKIT_LEARN_DATA", sklearnData.path, 1)
        let statsmodelsData = libraryURL.appendingPathComponent("statsmodels_data")
        setenv("STATSMODELS_DATA", statsmodelsData.path, 1)
        let pysalData = libraryURL.appendingPathComponent("pysal_data")
        setenv("PYSALDATA", pysalData.path, 1)
    } // end !a-Shell mini
    // All calls to setenv() before calls to executeCommandAndWait otherwise we can be redefining the environment
    // while copying it
    // Main Python install: $APPDIR/Library/lib/python3.x
    setenv("PYTHONHOME", hostBundle.resourcePath! + "/Library", 1)
    // Compiled files: ~/Library/__pycache__
    setenv("PYTHONPYCACHEPREFIX", (libraryURL.appendingPathComponent("__pycache__")).path, 1)
    setenv("PYTHONUSERBASE", libraryURL.path, 1)
    setenv("PYTHON_HISTORY", documentsUrl.appendingPathComponent(".python_history").path, 1)
    setenv("PYZMQ_BACKEND", "cffi", 1)
    // Node modules installed in ~/Library/node_modules resolve from any directory; npm itself is in $APPDIR/npm.
    setenv("NODE_PATH", libraryURL.path + "/node_modules", 1)
    // Frameworks are in $APPDIR/Frameworks:
    setenv("DYLD_FRAMEWORK_PATH", hostBundle.resourcePath! + "/Frameworks", 1)
    setenv("BLINK_OVERLAYS", (libraryURL.appendingPathComponent("blinkroot").path + ":"), 1)
    return appDependentPath
}
