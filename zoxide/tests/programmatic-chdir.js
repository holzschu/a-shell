// Run with native jsc; this reaches the same WebView dispatch as WASI chdir.
// Seed a zoxide match for MISSING, enable _ZO_CD=1, and supply an existing absolute directory.
// jsc prints the JSON result; its exit status alone does not report JavaScript failures.
(() => {
    const args = process.argv;
    if (args.length !== 4 || !args[2] || args[2].includes("/") || args[2].includes("\n") || !args[3].startsWith("/") || args[3].includes("\n")) {
        return JSON.stringify({result: "FAIL", error: "Usage: jsc programmatic-chdir.js MISSING EXISTING_ABSOLUTE_DIRECTORY"});
    }
    if (prompt("libc\ngetenv\n_ZO_CD") !== "1") {
        return JSON.stringify({result: "FAIL", error: "Enable _ZO_CD=1 before running this probe"});
    }
    const before = prompt("libc\ngetcwd");
    if (!before || !before.startsWith("/") || before === args[3]) {
        return JSON.stringify({result: "FAIL", error: "Start in a different existing absolute directory"});
    }
    const report = {before, missing: args[2], existing: args[3]};
    try {
        report.missing_return = prompt("libc\nchdir\n" + args[2]);
        report.after_missing = prompt("libc\ngetcwd");
        report.existing_return = prompt("libc\nchdir\n" + args[3]);
        report.after_existing = prompt("libc\ngetcwd");
    } finally {
        report.restore_return = prompt("libc\nchdir\n" + before);
        report.after_restore = prompt("libc\ngetcwd");
    }
    report.result = report.missing_return === "false" && report.after_missing === before &&
        report.existing_return === "true" && report.after_existing === args[3] &&
        report.restore_return === "true" && report.after_restore === before ? "PASS" : "FAIL";
    return JSON.stringify(report);
})();
