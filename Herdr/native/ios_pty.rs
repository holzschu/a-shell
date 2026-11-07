//! Original pane actor integration with the host-owned ios_system backend.
use portable_pty::{Child, ChildKiller, CommandBuilder, ExitStatus};
use std::collections::HashMap;
use std::ffi::CString;
use std::os::fd::{FromRawFd, OwnedFd};
use std::sync::{Arc, Mutex, OnceLock, Weak};
use std::{io, thread, time::Duration};
unsafe extern "C" {
    fn ashell_pane_spawn(
        command: *const libc::c_char,
        cwd: *const libc::c_char,
        cols: u32,
        rows: u32,
        envp: *const *const libc::c_char,
        fd: *mut i32,
        job: *mut *mut libc::c_void,
    ) -> i32;
    fn ashell_pane_poll(job: *mut libc::c_void, status: *mut i32) -> i32;
    fn ashell_pane_resize(job: *mut libc::c_void, cols: u32, rows: u32) -> i32;
    fn ashell_pane_cancel(job: *mut libc::c_void) -> i32;
    fn ashell_pane_interrupt(job: *mut libc::c_void) -> i32;
    fn ashell_pane_close_stdin(job: *mut libc::c_void) -> i32;
    fn ashell_pane_release(job: *mut libc::c_void);
}
fn jobs() -> &'static Mutex<HashMap<i32, Weak<Job>>> {
    static JOBS: OnceLock<Mutex<HashMap<i32, Weak<Job>>>> = OnceLock::new();
    JOBS.get_or_init(|| Mutex::new(HashMap::new()))
}
fn positive_errno(status: i32) -> io::Result<()> {
    if status == 0 {
        Ok(())
    } else {
        Err(io::Error::from_raw_os_error(status))
    }
}
#[derive(Debug)]
struct Job {
    pointer: usize,
    fd: i32,
    calls: Mutex<()>,
}
impl Drop for Job {
    fn drop(&mut self) {
        jobs().lock().unwrap().remove(&self.fd);
        unsafe { ashell_pane_release(self.pointer as *mut _) }
    }
}
pub(crate) fn resize(fd: i32, rows: u16, cols: u16) -> io::Result<()> {
    let job = jobs()
        .lock()
        .unwrap()
        .get(&fd)
        .and_then(Weak::upgrade)
        .ok_or_else(|| io::Error::from(io::ErrorKind::NotFound))?;
    let _call = job.calls.lock().unwrap();
    positive_errno(unsafe { ashell_pane_resize(job.pointer as *mut _, cols.into(), rows.into()) })
}
pub(crate) fn interrupt(fd: i32) -> io::Result<bool> {
    let job = jobs()
        .lock()
        .unwrap()
        .get(&fd)
        .and_then(Weak::upgrade)
        .ok_or_else(|| io::Error::from(io::ErrorKind::NotFound))?;
    let _call = job.calls.lock().unwrap();
    match unsafe { ashell_pane_interrupt(job.pointer as *mut _) } {
        0 => Ok(true),
        libc::ENOTSUP => Ok(false),
        error => Err(io::Error::from_raw_os_error(error)),
    }
}
pub(crate) fn cancel(fd: i32) {
    let job = jobs().lock().unwrap().get(&fd).and_then(Weak::upgrade);
    if let Some(job) = job {
        let _call = job.calls.lock().unwrap();
        let _ = unsafe { ashell_pane_cancel(job.pointer as *mut _) };
    }
}
pub(crate) fn close_all_stdin() {
    let live: Vec<_> = jobs()
        .lock()
        .unwrap()
        .values()
        .filter_map(Weak::upgrade)
        .collect();
    for job in live {
        let _call = job.calls.lock().unwrap();
        let _ = positive_errno(unsafe { ashell_pane_close_stdin(job.pointer as *mut _) });
    }
}
#[derive(Debug)]
struct CommandChild {
    job: Arc<Job>,
}
impl ChildKiller for CommandChild {
    fn kill(&mut self) -> io::Result<()> {
        let _call = self.job.calls.lock().unwrap();
        positive_errno(unsafe { ashell_pane_cancel(self.job.pointer as *mut _) })
    }
    fn clone_killer(&self) -> Box<dyn ChildKiller + Send + Sync> {
        Box::new(Self {
            job: self.job.clone(),
        })
    }
}
impl Child for CommandChild {
    fn try_wait(&mut self) -> io::Result<Option<ExitStatus>> {
        let mut status = 0;
        let _call = self.job.calls.lock().unwrap();
        match unsafe { ashell_pane_poll(self.job.pointer as *mut _, &mut status) } {
            0 => Ok(None),
            1 => Ok(Some(ExitStatus::with_exit_code(status as u32))),
            error => Err(io::Error::from_raw_os_error(-error)),
        }
    }
    fn wait(&mut self) -> io::Result<ExitStatus> {
        loop {
            if let Some(status) = self.try_wait()? {
                return Ok(status);
            }
            thread::sleep(Duration::from_millis(10));
        }
    }
    fn process_id(&self) -> Option<u32> {
        None
    }
}
pub(crate) struct SpawnedPty {
    pub master_fd: OwnedFd,
    pub child: Box<dyn Child + Send + Sync>,
}
pub(crate) fn spawn_with_portable_pty(
    rows: u16,
    cols: u16,
    cmd: CommandBuilder,
) -> io::Result<SpawnedPty> {
    let mut args: Vec<String> = cmd
        .get_argv()
        .iter()
        .map(|a| {
            a.to_str().map(str::to_owned).ok_or_else(|| {
                io::Error::new(io::ErrorKind::InvalidInput, "pane argument is not UTF-8")
            })
        })
        .collect::<io::Result<_>>()?;
    if args.is_empty() {
        return Err(io::Error::from(io::ErrorKind::InvalidInput));
    }
    if args[0] == "/bin/sh" {
        args[0] = "sh".into();
    }
    if args[0] == "/bin/dash" {
        args[0] = "dash".into();
    }
    // ios_system sh only dispatches commands; native dash owns interactive input.
    if args[0] == "sh" && !args.iter().any(|a| a == "-c") {
        args[0] = "dash".into();
    }
    if matches!(args[0].as_str(), "sh" | "dash") && !args.iter().any(|a| a == "-c" || a == "-i") {
        args.push("-i".into());
    }
    if args[0] == "dash"
        && !args
            .iter()
            .any(|arg| arg == "-c" || arg == "-E" || arg == "-V")
    {
        args.push("-E".into());
    }
    let command = CString::new(
        args.iter()
            .map(|a| format!("'{}'", a.replace('\'', "'\\''")))
            .collect::<Vec<_>>()
            .join(" "),
    )
    .map_err(io::Error::other)?;
    let fallback_cwd = std::env::current_dir()?.into_os_string();
    let cwd = CString::new(
        cmd.get_cwd()
            .unwrap_or(&fallback_cwd)
            .to_str()
            .ok_or_else(|| {
                io::Error::new(io::ErrorKind::InvalidInput, "pane directory is not UTF-8")
            })?,
    )
    .map_err(io::Error::other)?;
    let env: Vec<CString> = cmd
        .iter_full_env()
        .map(|(k, v)| {
            let k = k.to_str().ok_or_else(|| {
                io::Error::new(
                    io::ErrorKind::InvalidInput,
                    "pane environment key is not UTF-8",
                )
            })?;
            let v = v.to_str().ok_or_else(|| {
                io::Error::new(
                    io::ErrorKind::InvalidInput,
                    "pane environment value is not UTF-8",
                )
            })?;
            CString::new(format!("{k}={v}")).map_err(io::Error::other)
        })
        .collect::<io::Result<_>>()?;
    let mut envp: Vec<_> = env.iter().map(|v| v.as_ptr()).collect();
    envp.push(std::ptr::null());
    let mut fd = -1;
    let mut pointer = std::ptr::null_mut();
    let error = unsafe {
        ashell_pane_spawn(
            command.as_ptr(),
            cwd.as_ptr(),
            cols.into(),
            rows.into(),
            envp.as_ptr(),
            &mut fd,
            &mut pointer,
        )
    };
    if error == libc::ENOSPC {
        return Err(io::Error::other("Worker pool full. Close a pane."));
    }
    positive_errno(error)?;
    if fd < 0 || pointer.is_null() {
        return Err(io::Error::other("pane backend returned an invalid handle"));
    }
    let job = Arc::new(Job {
        pointer: pointer as usize,
        fd,
        calls: Mutex::new(()),
    });
    jobs().lock().unwrap().insert(fd, Arc::downgrade(&job));
    Ok(SpawnedPty {
        master_fd: unsafe { OwnedFd::from_raw_fd(fd) },
        child: Box::new(CommandChild { job }),
    })
}
