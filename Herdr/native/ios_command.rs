use std::ffi::{c_char, c_int, CString};
use std::fs::File;
use std::io::Read;
use std::path::Path;

extern "C" {
    fn ios_executable(command: *const c_char) -> c_int;
}

fn registered_command(command: &str) -> bool {
    CString::new(command).is_ok_and(|name| unsafe { ios_executable(name.as_ptr()) != 0 })
}

fn script_interpreter(header: &[u8]) -> Option<&str> {
    let header = header.strip_prefix(b"#!")?;
    let line = std::str::from_utf8(header.split(|byte| *byte == b'\n').next()?).ok()?;
    let mut words = line.split_ascii_whitespace();
    let mut interpreter = words.next()?;
    if interpreter.ends_with("env") {
        interpreter = words.next()?;
    }
    match interpreter.rsplit('/').next()? {
        "sh" => Some("dash"),
        "node" => Some("jsc"),
        name => Some(name),
    }
}

fn file_command(path: &Path, suffix_interpreter: Option<&str>) -> bool {
    let mut prefix = [0; 256];
    let Ok(len) = File::open(path).and_then(|mut file| file.read(&mut prefix)) else {
        return false;
    };
    let prefix = &prefix[..len];
    if prefix.starts_with(b"\0asm") {
        return registered_command(suffix_interpreter.unwrap_or("wasm"));
    }
    suffix_interpreter.is_none() && script_interpreter(prefix).is_some_and(registered_command)
}

pub(crate) fn command_available(command: &str) -> bool {
    if registered_command(command) {
        return true;
    }
    let Some(path) = std::env::var_os("PATH") else {
        return false;
    };
    let wasm3 = format!("{command}.wasm3");
    let wasm = format!("{command}.wasm");
    // ios_executable only queries the command dictionary. ios_system also
    // dispatches PATH scripts and Wasm modules without requiring an execute bit.
    std::env::split_paths(&path).any(|dir| {
        if dir.as_os_str().is_empty() {
            return false;
        }
        [
            (dir.join(command), None),
            (dir.join(&wasm3), Some("wasm3")),
            (dir.join(&wasm), Some("wasm")),
        ]
        .into_iter()
        .find(|(path, _)| path.is_file())
        .is_some_and(|(path, suffix_interpreter)| file_command(&path, suffix_interpreter))
    })
}
