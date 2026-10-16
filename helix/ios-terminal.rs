//! a-Shell owns input mode and dimensions; its streams are pipes or sockets.
use crate::terminal::WindowSize;
use std::io;
use std::sync::atomic::{AtomicBool, Ordering};

unsafe extern "C" {
    fn codex_ios_terminal_set_raw(enabled: i32) -> i32;
    fn codex_ios_terminal_size(columns: *mut u16, rows: *mut u16) -> i32;
}

static RAW: AtomicBool = AtomicBool::new(false);

pub(crate) fn is_raw_mode_enabled() -> bool {
    RAW.load(Ordering::SeqCst)
}

pub(crate) fn enable_raw_mode() -> io::Result<()> {
    let error = unsafe { codex_ios_terminal_set_raw(1) };
    if error != 0 { return Err(io::Error::from_raw_os_error(error)); }
    RAW.store(true, Ordering::SeqCst);
    Ok(())
}

pub(crate) fn disable_raw_mode() -> io::Result<()> {
    let error = unsafe { codex_ios_terminal_set_raw(0) };
    if error != 0 { return Err(io::Error::from_raw_os_error(error)); }
    RAW.store(false, Ordering::SeqCst);
    Ok(())
}

pub(crate) fn window_size() -> io::Result<WindowSize> {
    let (mut columns, mut rows) = (0, 0);
    let error = unsafe { codex_ios_terminal_size(&mut columns, &mut rows) };
    if error != 0 { return Err(io::Error::from_raw_os_error(error)); }
    Ok(WindowSize { columns, rows, width: 0, height: 0 })
}

pub(crate) fn size() -> io::Result<(u16, u16)> {
    window_size().map(|size| (size.columns, size.rows))
}
