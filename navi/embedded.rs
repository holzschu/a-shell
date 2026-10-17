//! Per-invocation state and synchronous registered-command dispatch.
use std::cell::RefCell;
use std::collections::HashMap;
use std::ffi::{CStr, CString, OsStr, OsString};
use std::fs::File;
use std::io::{self, Read, Seek, SeekFrom};
use std::os::fd::{AsRawFd, FromRawFd};
use std::os::unix::process::ExitStatusExt;
use std::process::{ExitStatus, Output};

unsafe extern "C" {
    fn navi_host_run(command: *const i8, input: i32, output: i32, errors: i32) -> i32;
    fn navi_host_write(errors: i32, bytes: *const u8, length: usize);
    fn navi_host_tmpfd() -> i32;
    fn navi_host_input() -> i32;
    fn navi_host_getenv(name: *const i8) -> *const i8;
    fn navi_host_size(columns: *mut u16, rows: *mut u16) -> i32;
}
thread_local! {
    static VALUES: RefCell<HashMap<OsString, Option<OsString>>> = RefCell::new(HashMap::new());
}
pub fn get(name: impl AsRef<OsStr>) -> Result<String, std::env::VarError> {
    let name = name.as_ref();
    if let Some(value) = VALUES.with(|values| values.borrow().get(name).cloned()) {
        return value
            .ok_or_else(|| std::env::VarError::NotPresent)?
            .into_string()
            .map_err(std::env::VarError::NotUnicode);
    }
    use std::os::unix::ffi::OsStrExt;
    let key = CString::new(name.as_bytes()).map_err(|_| std::env::VarError::NotPresent)?;
    let value = unsafe { navi_host_getenv(key.as_ptr()) };
    if value.is_null() {
        return Err(std::env::VarError::NotPresent);
    }
    Ok(unsafe { CStr::from_ptr(value) }
        .to_string_lossy()
        .into_owned())
}
pub fn set(name: impl AsRef<OsStr>, value: impl AsRef<OsStr>) {
    VALUES.with(|values| {
        values
            .borrow_mut()
            .insert(name.as_ref().to_owned(), Some(value.as_ref().to_owned()))
    });
}
pub fn remove(name: impl AsRef<OsStr>) {
    VALUES.with(|values| values.borrow_mut().insert(name.as_ref().to_owned(), None));
}
pub fn write(errors: bool, args: std::fmt::Arguments<'_>) {
    let text = args.to_string();
    unsafe {
        navi_host_write(i32::from(errors), text.as_ptr(), text.len());
    }
}
pub fn width() -> u16 {
    let (mut columns, mut rows) = (0, 0);
    if unsafe { navi_host_size(&mut columns, &mut rows) } == 0 {
        columns
    } else {
        80
    }
}
pub fn input() -> io::Result<File> {
    let fd = unsafe { navi_host_input() };
    if fd < 0 {
        Err(io::Error::last_os_error())
    } else {
        Ok(unsafe { File::from_raw_fd(fd) })
    }
}
fn temporary() -> io::Result<File> {
    let fd = unsafe { navi_host_tmpfd() };
    if fd < 0 {
        Err(io::Error::last_os_error())
    } else {
        Ok(unsafe { File::from_raw_fd(fd) })
    }
}
#[derive(Clone, Copy, Debug, Default)]
pub enum Stdio {
    #[default]
    Inherit,
    Piped,
}
impl Stdio {
    pub fn inherit() -> Self {
        Self::Inherit
    }
    pub fn piped() -> Self {
        Self::Piped
    }
}
#[derive(Clone, Debug)]
pub struct Command {
    words: Vec<String>,
    stdin: Stdio,
    stdout: Stdio,
    stderr: Stdio,
}
impl Command {
    pub fn new(word: impl AsRef<OsStr>) -> Self {
        Self {
            words: vec![word.as_ref().to_string_lossy().into_owned()],
            stdin: Stdio::Inherit,
            stdout: Stdio::Inherit,
            stderr: Stdio::Inherit,
        }
    }
    pub fn arg(&mut self, word: impl AsRef<OsStr>) -> &mut Self {
        self.words
            .push(word.as_ref().to_string_lossy().into_owned());
        self
    }
    pub fn args(&mut self, words: impl IntoIterator<Item = impl AsRef<OsStr>>) -> &mut Self {
        for word in words {
            self.arg(word);
        }
        self
    }
    pub fn stdin(&mut self, value: Stdio) -> &mut Self {
        self.stdin = value;
        self
    }
    pub fn stdout(&mut self, value: Stdio) -> &mut Self {
        self.stdout = value;
        self
    }
    pub fn stderr(&mut self, value: Stdio) -> &mut Self {
        self.stderr = value;
        self
    }
    pub fn env(&mut self, key: &str, value: String) -> &mut Self {
        // Finder does not launch a shell: its parser consumes only piped records.
        assert_eq!(key, "SHELL");
        let _ = value;
        self
    }
    pub fn spawn(&mut self) -> io::Result<Child> {
        Ok(Child {
            command: self.clone(),
            stdin: if matches!(self.stdin, Stdio::Inherit) {
                None
            } else {
                Some(temporary()?)
            },
        })
    }
    pub fn output(&mut self) -> io::Result<Output> {
        self.stdout = Stdio::Piped;
        self.stderr = Stdio::Piped;
        self.spawn()?.wait_with_output()
    }
}
pub struct Child {
    command: Command,
    pub stdin: Option<File>,
}
impl Child {
    fn run(&mut self) -> io::Result<Output> {
        if let Some(input) = &mut self.stdin {
            input.seek(SeekFrom::Start(0))?;
        }
        let mut out = if matches!(self.command.stdout, Stdio::Inherit) {
            None
        } else {
            Some(temporary()?)
        };
        let mut err = if matches!(self.command.stderr, Stdio::Inherit) {
            None
        } else {
            Some(temporary()?)
        };
        let quote = |s: &str| format!("'{}'", s.replace('\'', "'\\''"));
        let command = self
            .command
            .words
            .iter()
            .map(|s| quote(s))
            .collect::<Vec<_>>()
            .join(" ");
        let command = CString::new(command)?;
        let fd = |f: &Option<File>| f.as_ref().map_or(-1, AsRawFd::as_raw_fd);
        let code = unsafe { navi_host_run(command.as_ptr(), fd(&self.stdin), fd(&out), fd(&err)) };
        if code < 0 {
            return Err(io::Error::last_os_error());
        }
        let mut stdout = Vec::new();
        let mut stderr = Vec::new();
        if let Some(file) = &mut out {
            file.seek(SeekFrom::Start(0))?;
            file.read_to_end(&mut stdout)?;
        }
        if let Some(file) = &mut err {
            file.seek(SeekFrom::Start(0))?;
            file.read_to_end(&mut stderr)?;
        }
        Ok(Output {
            status: ExitStatus::from_raw(code << 8),
            stdout,
            stderr,
        })
    }
    pub fn wait(&mut self) -> io::Result<ExitStatus> {
        Ok(self.run()?.status)
    }
    pub fn wait_with_output(mut self) -> io::Result<Output> {
        self.run()
    }
}
#[derive(Debug)]
pub struct CommandExit(pub i32);
impl std::fmt::Display for CommandExit {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Command returned {}", self.0)
    }
}
impl std::error::Error for CommandExit {}

#[no_mangle]
pub unsafe extern "C" fn navi_embedded_run(argc: i32, argv: *const *const i8) -> i32 {
    VALUES.with(|values| values.borrow_mut().clear());
    let words = unsafe { std::slice::from_raw_parts(argv, argc as usize) }
        .iter()
        .map(|p| unsafe { CStr::from_ptr(*p) }.to_string_lossy().into_owned())
        .collect::<Vec<_>>();
    let code = match std::panic::catch_unwind(|| {
        if let Err(error) = crate::config::initialize(words) {
            write(error.use_stderr(), format_args!("{error}"));
            return error.exit_code();
        }
        match crate::handle() {
            Ok(()) => 0,
            Err(error) => {
                if let Some(code) = error.downcast_ref::<CommandExit>() {
                    code.0
                } else {
                    write(true, format_args!("navi: {error:#}\n"));
                    1
                }
            }
        }
    }) {
        Ok(code) => code,
        Err(value) => value.downcast_ref::<CommandExit>().map_or(1, |e| e.0),
    };
    crate::config::clear();
    VALUES.with(|values| values.borrow_mut().clear());
    code
}
