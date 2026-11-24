//! Embedded original client/server lifecycle. The host owns terminal and pane execution.
use std::ffi::CStr;
use std::io::{self, Write};
use std::sync::{
    atomic::{AtomicBool, AtomicU32, Ordering},
    Arc, Mutex, OnceLock,
};
use std::thread::JoinHandle;
unsafe extern "C" {
    fn ios_startInteractive();
    fn ios_stopInteractive();
    fn ios_getenv(name: *const libc::c_char) -> *const libc::c_char;
}
static ACTIVE: AtomicBool = AtomicBool::new(false);
static GRID: AtomicU32 = AtomicU32::new(0);
static INTERACTIVE: AtomicBool = AtomicBool::new(false);
static SERVER: Mutex<Option<JoinHandle<io::Result<()>>>> = Mutex::new(None);
static CLIENT_QUIT: Mutex<Option<Arc<AtomicBool>>> = Mutex::new(None);
static CLIENT_THREADS: Mutex<Vec<JoinHandle<()>>> = Mutex::new(Vec::new());
static STARTUP_CWD: Mutex<Option<std::path::PathBuf>> = Mutex::new(None);
pub(crate) fn take_startup_cwd() -> Option<std::path::PathBuf> {
    STARTUP_CWD.lock().unwrap().take()
}
pub(crate) fn remember_client_quit(flag: Arc<AtomicBool>) {
    *CLIENT_QUIT.lock().unwrap() = Some(flag);
}
pub(crate) fn spawn_client_thread(operation: impl FnOnce() + Send + 'static) {
    CLIENT_THREADS
        .lock()
        .unwrap()
        .push(std::thread::spawn(operation));
}
pub(crate) fn server_stop_flag() -> Arc<AtomicBool> {
    static STOP: OnceLock<Arc<AtomicBool>> = OnceLock::new();
    STOP.get_or_init(|| Arc::new(AtomicBool::new(false)))
        .clone()
}
pub(crate) fn start_server() -> io::Result<u32> {
    let mut server = SERVER.lock().unwrap();
    if server.is_some() {
        return Err(io::Error::from(io::ErrorKind::AlreadyExists));
    }
    server_stop_flag().store(false, Ordering::Release);
    *server = Some(
        std::thread::Builder::new()
            .name("herdr-ios-server".into())
            .spawn(
                || match std::panic::catch_unwind(crate::server::headless::run_server) {
                    Ok(result) => result,
                    Err(payload) => Err(io::Error::other(
                        if let Some(status) = payload.downcast_ref::<crate::host_io::ExitStatus>() {
                            format!("server returned status {}", status.0)
                        } else {
                            "server panicked".into()
                        },
                    )),
                },
            )?,
    );
    Ok(std::process::id())
}
pub(crate) fn output(error: bool, args: std::fmt::Arguments<'_>) {
    let _ = if error {
        crate::host_io::stderr().write_fmt(args)
    } else {
        crate::host_io::stdout().write_fmt(args)
    };
}
#[no_mangle]
pub extern "C" fn herdr_ios_resize(cols: u16, rows: u16) {
    if cols != 0 && rows != 0 {
        GRID.store((u32::from(cols) << 16) | u32::from(rows), Ordering::Release);
    }
}
pub(crate) fn grid_size() -> io::Result<(u16, u16)> {
    let grid = GRID.load(Ordering::Acquire);
    if grid == 0 {
        Err(io::Error::new(
            io::ErrorKind::NotConnected,
            "host terminal geometry is missing",
        ))
    } else {
        Ok(((grid >> 16) as u16, grid as u16))
    }
}
pub(crate) fn terminal_start() -> io::Result<()> {
    if INTERACTIVE.swap(true, Ordering::AcqRel) {
        return Ok(());
    }
    unsafe {
        ios_startInteractive();
    }
    crate::host_io::stdout().write_all(b"\x1b[?1049h")
}
pub(crate) fn terminal_stop() -> io::Result<()> {
    if INTERACTIVE.swap(false, Ordering::AcqRel) {
        // Resume a-Shell's line editor at column zero in the normal screen buffer.
        let result = crate::host_io::stdout().write_all(b"\x1b[?1049l\x1b[?25h\r\n");
        unsafe {
            ios_stopInteractive();
        }
        result
    } else {
        Ok(())
    }
}
struct CommandGuard;
impl Drop for CommandGuard {
    fn drop(&mut self) {
        if let Some(flag) = CLIENT_QUIT.lock().unwrap().take() {
            flag.store(true, Ordering::Release);
        }
        crate::host_io::INPUT_STOP.store(true, Ordering::Release);
        server_stop_flag().store(true, Ordering::Release);
        crate::pty::backend::close_all_stdin();
        let threads = std::mem::take(&mut *CLIENT_THREADS.lock().unwrap());
        for thread in threads {
            let _ = thread.join();
        }
        if let Some(server) = SERVER.lock().unwrap().take() {
            let _ = server.join();
        }
        let _ = terminal_stop();
        crate::host_io::release();
        ACTIVE.store(false, Ordering::Release);
    }
}
/// Borrow argv and capture streams on the ios_system command thread; never unwind into C.
#[no_mangle]
pub unsafe extern "C" fn herdr_ios_main(
    argc: libc::c_int,
    argv: *const *const libc::c_char,
) -> libc::c_int {
    if !(1..=64).contains(&argc) || argv.is_null() {
        return 2;
    }
    if ACTIVE
        .compare_exchange(false, true, Ordering::AcqRel, Ordering::Acquire)
        .is_err()
    {
        return 16;
    }
    if crate::host_io::capture().is_err() {
        ACTIVE.store(false, Ordering::Release);
        return 1;
    }
    let _guard = CommandGuard;
    let result = std::panic::catch_unwind(|| {
        let mut args = Vec::with_capacity(argc as usize);
        for index in 0..argc as usize {
            let arg = *argv.add(index);
            if arg.is_null() {
                return 2;
            }
            let Ok(arg) = CStr::from_ptr(arg).to_str() else {
                return 2;
            };
            args.push(arg.to_owned());
        }
        // Ancillary process-launching CLI paths require their own host contracts.
        if args.len() != 1
            && !(args.len() == 2
                && matches!(
                    args[1].as_str(),
                    "--version" | "-V" | "--help" | "-h" | "--skill" | "--default-config"
                ))
        {
            output(
                true,
                format_args!(
                    "herdr: this embedded build supports local UI and informational flags\n"
                ),
            );
            return 78;
        }
        for (name, shift) in [(c"COLUMNS", 16), (c"LINES", 0)] {
            let value = ios_getenv(name.as_ptr());
            if !value.is_null() {
                if let Ok(value) = CStr::from_ptr(value).to_string_lossy().parse::<u16>() {
                    if value != 0 {
                        GRID.fetch_update(Ordering::AcqRel, Ordering::Acquire, |grid| {
                            Some((grid & !(0xffff << shift)) | (u32::from(value) << shift))
                        })
                        .ok();
                    }
                }
            }
        }
        // Keep early keystrokes in the host stdin pipe while worker restoration runs.
        if args.len() == 1 {
            // PWD belongs to the invoking a-Shell session. The server thread's
            // process cwd can instead be the Simulator data or extension directory.
            use std::os::unix::ffi::OsStrExt;
            let cwd = ios_getenv(c"PWD".as_ptr());
            if cwd.is_null() {
                output(true, format_args!("herdr: a-Shell session directory is missing\n"));
                return 1;
            }
            let cwd = std::path::PathBuf::from(std::ffi::OsStr::from_bytes(
                CStr::from_ptr(cwd).to_bytes(),
            ));
            if !cwd.is_absolute() || !cwd.is_dir() {
                output(true, format_args!("herdr: a-Shell session directory is unavailable\n"));
                return 1;
            }
            *STARTUP_CWD.lock().unwrap() = Some(cwd);
            if let Err(error) = terminal_start() {
                output(true, format_args!("herdr: {error}\n"));
                return 1;
            }
        }
        match crate::run_main(args) {
            Ok(()) => 0,
            Err(error) => {
                output(true, format_args!("herdr: {error}\n"));
                1
            }
        }
    });
    match result {
        Ok(status) => status,
        Err(payload) => payload
            .downcast_ref::<crate::host_io::ExitStatus>()
            .map_or(70, |status| status.0),
    }
}

// Preserve accessible directories and relocate this app's old container paths.
// Unavailable saved directories fall back to the normal home instead of a dead pane.
pub(crate) fn relocate_snapshot(snapshot: &mut crate::persist::SessionSnapshot) -> bool {
    use std::path::{Component, Path, PathBuf};
    fn accessible(path: &Path) -> bool {
        use std::os::unix::ffi::OsStrExt;
        let Ok(path_c) = std::ffi::CString::new(path.as_os_str().as_bytes()) else {
            return false;
        };
        path.is_dir() && unsafe { libc::access(path_c.as_ptr(), libc::R_OK | libc::X_OK) == 0 }
    }
    fn relocate(cwd: &Path, root: &Path) -> Option<PathBuf> {
        // Recover only the exact stock URL-launch root, not selected folders inside it.
        if let Some(group) = std::env::var_os("GROUP").and_then(|p| std::fs::canonicalize(p).ok()) {
            let documents = root.join("Documents");
            if cwd.canonicalize().is_ok_and(|p| p == group) && accessible(&documents) {
                return Some(documents);
            }
        }
        if accessible(cwd) {
            return Some(cwd.to_path_buf());
        }
        let parent = root.parent()?;
        let aliases = [
            parent.to_path_buf(),
            PathBuf::from(parent.to_string_lossy().trim_start_matches("/private")),
        ];
        for parent in aliases {
            let Ok(relative) = cwd.strip_prefix(&parent) else {
                continue;
            };
            let mut parts = relative.components();
            let Some(Component::Normal(old_id)) = parts.next() else {
                continue;
            };
            let id = old_id.to_string_lossy();
            if id.len() != 36
                || !id.bytes().enumerate().all(|(i, b)| {
                    if [8, 13, 18, 23].contains(&i) {
                        b == b'-'
                    } else {
                        b.is_ascii_hexdigit()
                    }
                })
            {
                continue;
            }
            let suffix = parts.as_path();
            if suffix
                .components()
                .any(|p| matches!(p, Component::ParentDir))
            {
                continue;
            }
            let candidate = root.join(suffix);
            if accessible(&candidate) && candidate.canonicalize().is_ok_and(|p| p.starts_with(root))
            {
                tracing::info!(old = %cwd.display(), new = %candidate.display(), "relocated saved app-container cwd");
                return Some(candidate);
            }
        }
        None
    }
    let Some(root) = std::env::var_os("HOME").and_then(|p| std::fs::canonicalize(p).ok()) else {
        return false;
    };
    if !root
        .parent()
        .is_some_and(|p| p.ends_with("Containers/Data/Application"))
    {
        return false;
    }
    let documents = root.join("Documents");
    let fallback = if accessible(&documents) {
        documents
    } else {
        root.clone()
    };
    let mut changed = false;
    for workspace in &mut snapshot.workspaces {
        let cwd = relocate(&workspace.identity_cwd, &root).unwrap_or_else(|| fallback.clone());
        changed |= cwd != workspace.identity_cwd;
        workspace.identity_cwd = cwd;
        if let Some(mut space) = workspace.worktree_space.take() {
            match (
                relocate(&space.repo_root, &root),
                relocate(&space.checkout_path, &root),
            ) {
                (Some(repo_root), Some(checkout_path)) => {
                    changed |= repo_root != space.repo_root || checkout_path != space.checkout_path;
                    space.repo_root = repo_root;
                    space.checkout_path = checkout_path;
                    workspace.worktree_space = Some(space);
                }
                _ => changed = true,
            }
        }
        for tab in &mut workspace.tabs {
            for pane in tab.panes.values_mut() {
                let cwd = relocate(&pane.cwd, &root).unwrap_or_else(|| fallback.clone());
                changed |= cwd != pane.cwd;
                pane.cwd = cwd;
            }
        }
    }
    changed
}
