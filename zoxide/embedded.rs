//! The upstream command engine uses the invoking ios_system thread's services.
use std::ffi::{CStr, CString, OsStr, OsString, c_char};
use std::io::{self, Write};
use std::os::unix::ffi::{OsStrExt, OsStringExt};
use std::path::PathBuf;

use anyhow::{Context, Result, bail};
use clap::{CommandFactory, FromArgMatches};

use crate::cmd::{Add, Cmd, Query, Run};
use crate::error::SilentExit;

unsafe extern "C" {
    fn ios_getenv(name: *const c_char) -> *const c_char;
    fn zoxide_host_canonical(bytes: *const c_char) -> *mut c_char;
    fn zoxide_host_write(errors: i32, bytes: *const u8, length: usize) -> usize;
    fn zoxide_host_flush(errors: i32) -> i32;
    fn zoxide_host_cd(path: *const c_char) -> i32;
    fn zoxide_host_fzf(
        bytes: *const u8,
        length: usize,
        options: *const c_char,
        selection: *mut *mut c_char,
    ) -> i32;
    fn zoxide_host_free(selection: *mut c_char);
}

#[derive(Default)]
pub struct FzfChild {
    input: Vec<u8>,
}

impl FzfChild {
    pub fn write(&mut self, dir: &crate::db::Dir, now: crate::db::Epoch) -> Result<Option<String>> {
        write!(
            self.input,
            "{}\0",
            dir.display().with_score(now).with_separator('\t')
        )?;
        Ok(None)
    }

    pub fn wait(&mut self) -> Result<String> {
        let options = crate::config::fzf_opts()
            .map(|value| CString::new(value.as_bytes()))
            .transpose()?;
        let mut selected = std::ptr::null_mut();
        let status = unsafe {
            zoxide_host_fzf(
                self.input.as_ptr(),
                self.input.len(),
                options
                    .as_ref()
                    .map_or(std::ptr::null(), |value| value.as_ptr()),
                &mut selected,
            )
        };
        let selection = if selected.is_null() {
            None
        } else {
            let value = unsafe { CStr::from_ptr(selected) }
                .to_str()
                .map(str::to_owned);
            unsafe { zoxide_host_free(selected) };
            Some(value)
        };
        match status {
            0 => selection
                .context("could not read selection from fzf")?
                .context("invalid unicode in fzf selection"),
            1 => bail!("no match found"),
            2 => bail!("fzf returned an error"),
            130 => bail!(SilentExit { code: 130 }),
            128..=254 => bail!("fzf was terminated"),
            _ => bail!("could not run fzf"),
        }
    }
}

pub fn canonical(value: OsString) -> OsString {
    let Ok(bytes) = CString::new(value.as_bytes()) else {
        return value;
    };
    // The host transfers a copy; Foundation's temporary storage may expire on return.
    let text = unsafe { zoxide_host_canonical(bytes.as_ptr()) };
    if text.is_null() {
        return value;
    }
    let composed = unsafe { CStr::from_ptr(text) }.to_bytes().to_vec();
    unsafe { zoxide_host_free(text) };
    OsString::from_vec(composed)
}

pub fn var_os(name: impl AsRef<OsStr>) -> Option<OsString> {
    let name = CString::new(name.as_ref().as_bytes()).ok()?;
    let value = unsafe { ios_getenv(name.as_ptr()) };
    if value.is_null() {
        None
    } else {
        Some(canonical(OsString::from_vec(
            unsafe { CStr::from_ptr(value) }.to_bytes().to_vec(),
        )))
    }
}

pub fn home_dir() -> Option<PathBuf> {
    var_os("HOME").map(PathBuf::from)
}

pub fn data_local_dir() -> Option<PathBuf> {
    home_dir().map(|home| home.join("Library/Application Support"))
}

pub struct Stream(bool);
pub fn stdout() -> Stream {
    Stream(false)
}
pub fn stderr() -> Stream {
    Stream(true)
}
impl Stream {
    // The command adapter serializes invocations; each fwrite locks its FILE.
    pub fn lock(self) -> Self {
        self
    }
}
impl Write for Stream {
    fn write(&mut self, bytes: &[u8]) -> io::Result<usize> {
        let count = unsafe { zoxide_host_write(i32::from(self.0), bytes.as_ptr(), bytes.len()) };
        if count == 0 && !bytes.is_empty() {
            Err(io::Error::last_os_error())
        } else {
            Ok(count)
        }
    }
    fn flush(&mut self) -> io::Result<()> {
        if unsafe { zoxide_host_flush(i32::from(self.0)) } == 0 {
            Ok(())
        } else {
            Err(io::Error::last_os_error())
        }
    }
}

fn command(words: Vec<OsString>) -> Result<()> {
    // Clap's normal parse()/exit() would terminate the containing application.
    let matches = Cmd::command()
        .color(clap::ColorChoice::Never)
        .try_get_matches_from(words);
    let matches = match matches {
        Ok(matches) => matches,
        Err(error) => {
            let mut stream = Stream(error.use_stderr());
            write!(stream, "{error}")?;
            bail!(SilentExit {
                code: error.exit_code() as u8
            });
        }
    };
    let cmd = Cmd::from_arg_matches(&matches)?;
    match &cmd {
        Cmd::Edit(_) | Cmd::Import(_) => bail!("this port supports add, query, remove and init"),
        _ => cmd.run(),
    }
}

fn logical_cwd() -> Result<PathBuf> {
    match var_os("PWD")
        .map(PathBuf::from)
        .filter(|path| path.is_absolute())
    {
        // ios_system keeps a trailing slash from native cd/tab completion.
        Some(path) => crate::util::resolve_path(path),
        None => crate::util::current_dir(),
    }
}

fn jump(words: Vec<OsString>, mode: i32) -> Result<()> {
    let interactive = mode >= 2;
    let exclude_current = mode != 2;
    let args = &words[1..];
    let directory = if interactive {
        None
    } else {
        match args {
            [] => Some(home_dir().context("HOME is not set")?),
            [arg] if arg == "-" => Some(PathBuf::from("-")),
            [arg] => {
                let path = PathBuf::from(arg);
                let path = if path.is_absolute() {
                    Some(path)
                } else {
                    logical_cwd().ok().map(|cwd| cwd.join(path))
                };
                path.filter(|path| path.is_dir())
                    .map(crate::util::resolve_path)
                    .transpose()?
            }
            _ => None,
        }
    };
    let path = match directory {
        Some(path) => path,
        None => {
            let keywords = args
                .iter()
                .map(|arg| {
                    arg.to_str()
                        .map(str::to_owned)
                        .context("invalid unicode in query")
                })
                .collect::<Result<Vec<_>>>()?;
            // Upstream's shell hook tolerates a failing pwd when excluding cwd.
            let exclude = if !exclude_current {
                None
            } else {
                logical_cwd()
                    .ok()
                    .and_then(|cwd| {
                        if crate::config::resolve_symlinks() {
                            crate::util::canonicalize(cwd).ok()
                        } else {
                            Some(cwd)
                        }
                    })
                    .and_then(|cwd| cwd.into_os_string().into_string().ok())
            };
            let query = Query {
                keywords,
                all: false,
                interactive,
                list: false,
                score: false,
                exclude,
                base_dir: None,
            };
            PathBuf::from(query.first_path()?)
        }
    };
    let target = CString::new(path.as_os_str().as_bytes())?;
    if unsafe { zoxide_host_cd(target.as_ptr()) } != 0 {
        return Err(io::Error::last_os_error()).context("could not change directory");
    }
    let path = if path == std::path::Path::new("-") {
        logical_cwd()?
    } else {
        path
    };
    if crate::config::echo() {
        let shown = if crate::config::resolve_symlinks() {
            crate::util::canonicalize(&path)?
        } else {
            path.clone()
        };
        writeln!(stdout(), "{}", shown.display())?;
    }
    Add {
        // Keep the logical destination; upstream add resolves symlinks only
        // when _ZO_RESOLVE_SYMLINKS requests it.
        paths: vec![path],
        score: None,
    }
    .run()
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn zoxide_embedded_run(
    argc: i32,
    argv: *const *const c_char,
    is_jump: i32,
) -> i32 {
    if argc < 1 || argv.is_null() {
        return 2;
    }
    // Preserve the host's panic hook; it may emit an additional process-stderr
    // diagnostic before catch_unwind returns control to this command boundary.
    let result = std::panic::catch_unwind(|| {
        let words = unsafe { std::slice::from_raw_parts(argv, argc as usize) }
            .iter()
            .map(|word| {
                if word.is_null() {
                    bail!("invalid command argument");
                }
                Ok(canonical(OsString::from_vec(
                    unsafe { CStr::from_ptr(*word) }.to_bytes().to_vec(),
                )))
            })
            .collect::<Result<Vec<_>>>()?;
        if is_jump != 0 {
            jump(words, is_jump)
        } else {
            command(words)
        }
    });
    let status = match result {
        Ok(Ok(())) => 0,
        Ok(Err(error)) => match error.downcast::<SilentExit>() {
            Ok(SilentExit { code }) => i32::from(code),
            Err(error) => {
                // Display keeps the error chain without shared-process backtraces.
                let _ = writeln!(stderr(), "zoxide: {error:#}");
                1
            }
        },
        Err(_) => {
            let _ = writeln!(stderr(), "zoxide: command panicked");
            1
        }
    };
    let flush_failed = [stdout().flush(), stderr().flush()]
        .into_iter()
        .any(|result| result.is_err_and(|error| error.kind() != io::ErrorKind::BrokenPipe));
    if status == 0 && flush_failed {
        1
    } else {
        status
    }
}
