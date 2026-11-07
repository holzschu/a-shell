//! Embed the upstream Codex CLI in an a-Shell command thread.
#![recursion_limit = "256"]

#[cfg(target_os = "ios")]
#[macro_use]
extern crate codex_utils_cli;

use codex_arg0::Arg0DispatchPaths;
use std::ffi::{CStr, c_char, c_int};
use std::io::Write;

unsafe fn host_args(argc: c_int, argv: *const *const c_char) -> Vec<String> {
    (0..argc as usize)
        .map(|i| {
            unsafe { CStr::from_ptr(*argv.add(i)) }
                .to_string_lossy()
                .into_owned()
        })
        .collect()
}

/// The command host uses the same parser to decide whether it requires interactive host streams.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn codex_embedded_uses_tui(argc: c_int, argv: *const *const c_char) -> c_int {
    std::panic::catch_unwind(|| {
        codex_cli::embedded_uses_tui(unsafe { host_args(argc, argv) }) as c_int
    })
    .unwrap_or(0)
}

/// The host serializes calls and supplies valid NUL-terminated argv entries.
/// cancel_fd is a nonblocking pipe reader, retained until this call returns.
/// Cancellation leaves it readable until all runtime workers have finished.
/// Runtime-owned workers must finish before the host restores descriptors.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn codex_embedded_run(
    argc: c_int,
    argv: *const *const c_char,
    cancel_fd: c_int,
) -> c_int {
    #[cfg(target_os = "ios")]
    let _stderr_guard = {
        use std::os::fd::BorrowedFd;
        unsafe extern "C" {
            fn codex_ios_command_stderr() -> c_int;
            fn codex_ios_stderr_capture_error(error: c_int);
        }
        let fd = unsafe { codex_ios_command_stderr() };
        if fd < 0 {
            return 1;
        }
        match codex_utils_cli::stdio::capture_stderr(unsafe { BorrowedFd::borrow_raw(fd) }) {
            Ok(guard) => guard,
            Err(error) => {
                // Capture failed, so the owned diagnostic writer is unavailable.
                unsafe { codex_ios_stderr_capture_error(error.raw_os_error().unwrap_or(0)) };
                return 1;
            }
        }
    };
    let panic_hook = std::panic::take_hook();
    #[cfg(target_os = "ios")]
    std::panic::set_hook(Box::new(|info| eprintln!("{info}")));
    let result = std::panic::catch_unwind(|| {
        let args = unsafe { host_args(argc, argv) };
        // The C host supplies a joined 16 MiB thread, never pthread-cancelled.
        run_args(args, cancel_fd)
    });
    // Every EventStream has joined its polling thread before this boundary.
    // The next invocation can supply a different captured terminal descriptor.
    #[cfg(target_os = "ios")]
    crossterm::event::reset_event_reader();
    let _ = std::io::stdout().flush();
    #[cfg(target_os = "ios")]
    let _ = codex_utils_cli::stdio::stderr().flush();
    #[cfg(not(target_os = "ios"))]
    let _ = std::io::stderr().flush();
    // TUI panic handlers belong to this invocation, not the surrounding app.
    std::panic::set_hook(panic_hook);
    match result {
        Ok(status) => status,
        Err(payload) => {
            // The iOS patch unwinds upstream CLI exits instead of killing a-Shell.
            if let Some(status) = payload.downcast_ref::<c_int>() {
                *status
            } else {
                eprintln!("Codex panicked; restart the owned app before another command");
                1
            }
        }
    }
}

fn run_args(args: Vec<String>, cancel_fd: c_int) -> c_int {
    let runtime = match tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .worker_threads(2)
        .thread_stack_size(16 * 1024 * 1024)
        .build()
    {
        Ok(runtime) => runtime,
        Err(error) => {
            eprintln!("Cannot start Codex runtime: {error}");
            return 1;
        }
    };
    let paths = Arg0DispatchPaths {
        codex_self_exe: std::env::current_exe().ok(),
        ..Default::default()
    };
    match runtime.block_on(async {
        use std::os::fd::BorrowedFd;
        // The host retains both pipe ends until this thread has joined.
        let cancel = tokio::io::unix::AsyncFd::new(unsafe { BorrowedFd::borrow_raw(cancel_fd) })?;
        tokio::select! {
            ready = cancel.async_io(tokio::io::Interest::READABLE, |_| {
                unsafe extern "C" {
                    fn codex_ios_cancellation_ready() -> c_int;
                }
                match unsafe { codex_ios_cancellation_ready() } {
                    0 => Err(std::io::ErrorKind::WouldBlock.into()),
                    error if error < 0 => Err(std::io::Error::from_raw_os_error(-error)),
                    _ => Ok(()),
                }
            }) => {
                ready?;
                Ok(130)
            }
            result = codex_cli::run_embedded(args, paths) => result,
        }
    }) {
        Ok(status) => status,
        Err(error) => {
            eprintln!("Codex: {error:#}");
            1
        }
    }
}
