//! Borrow ios_system's calling-thread streams; never redirect app descriptors.
use std::ffi::c_void;
use std::io::{self, Read, Write};

unsafe extern "C" {
    fn ios_stdin() -> *mut c_void;
    fn ios_stdout() -> *mut c_void;
    fn ios_stderr() -> *mut c_void;
    fn fread(buffer: *mut u8, size: usize, count: usize, stream: *mut c_void) -> usize;
    fn fwrite(buffer: *const u8, size: usize, count: usize, stream: *mut c_void) -> usize;
    fn fflush(stream: *mut c_void) -> i32;
    fn ferror(stream: *mut c_void) -> i32;
}

pub struct Input;
pub struct Output(i32);

pub fn stdin() -> Input {
    Input
}
pub fn stdout() -> Output {
    Output(1)
}
pub fn stderr() -> Output {
    Output(2)
}

impl Read for Input {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        let stream = unsafe { ios_stdin() };
        if stream.is_null() {
            return Err(io::Error::other("Missing command stdin"));
        }
        let count = unsafe { fread(buffer.as_mut_ptr(), 1, buffer.len(), stream) };
        if count == 0 && unsafe { ferror(stream) } != 0 {
            Err(io::Error::last_os_error())
        } else {
            Ok(count)
        }
    }
}
impl Write for Output {
    fn write(&mut self, buffer: &[u8]) -> io::Result<usize> {
        let stream = self.stream()?;
        let count = unsafe { fwrite(buffer.as_ptr(), 1, buffer.len(), stream) };
        if count == 0 && unsafe { ferror(stream) } != 0 {
            Err(io::Error::last_os_error())
        } else {
            Ok(count)
        }
    }
    fn flush(&mut self) -> io::Result<()> {
        if unsafe { fflush(self.stream()?) } == 0 {
            Ok(())
        } else {
            Err(io::Error::last_os_error())
        }
    }
}
impl Output {
    fn stream(&self) -> io::Result<*mut c_void> {
        let stream = unsafe {
            if self.0 == 1 {
                ios_stdout()
            } else {
                ios_stderr()
            }
        };
        if stream.is_null() {
            Err(io::Error::other("Missing command output"))
        } else {
            Ok(stream)
        }
    }
}
