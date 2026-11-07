//! Host streams are captured once on the command thread and shared by owned descriptors.
#[cfg(target_os = "ios")]
pub(crate) use embedded::*;
#[cfg(not(target_os = "ios"))]
pub(crate) use std::io::{stderr, stdin, stdout};
#[cfg(not(target_os = "ios"))]
pub(crate) use std::process::exit;

#[cfg(target_os = "ios")]
mod embedded {
    use std::fs::File;
    use std::io::{self, BufRead, BufReader, Read, Write};
    use std::os::fd::{AsRawFd, FromRawFd};
    use std::sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    };
    unsafe extern "C" {
        fn ios_stdin() -> *mut libc::FILE;
        fn ios_stdout() -> *mut libc::FILE;
        fn ios_stderr() -> *mut libc::FILE;
        fn ios_isatty(fd: i32) -> i32;
    }
    static FILES: Mutex<Option<[(Arc<File>, bool); 3]>> = Mutex::new(None);
    pub(crate) static INPUT_STOP: AtomicBool = AtomicBool::new(false);
    #[derive(Debug)]
    pub(crate) struct ExitStatus(pub i32);
    pub(crate) fn exit(code: i32) -> ! {
        std::panic::resume_unwind(Box::new(ExitStatus(code)))
    }
    pub(crate) fn capture() -> io::Result<()> {
        let mut captured = Vec::new();
        for ptr in unsafe { [ios_stdin(), ios_stdout(), ios_stderr()] } {
            if ptr.is_null() {
                return Err(io::Error::other("a-Shell stream is missing"));
            }
            let fd = unsafe { libc::fileno(ptr) };
            let terminal = unsafe { ios_isatty(fd) } != 0;
            let fd = crate::pty::fd::duplicate_cloexec_fd(fd)?;
            captured.push((Arc::new(unsafe { File::from_raw_fd(fd) }), terminal));
        }
        *FILES.lock().unwrap() = Some(captured.try_into().unwrap());
        INPUT_STOP.store(false, Ordering::Release);
        Ok(())
    }
    pub(crate) fn release() {
        INPUT_STOP.store(true, Ordering::Release);
        *FILES.lock().unwrap() = None;
    }
    struct Reader {
        file: Arc<File>,
        input: bool,
    }
    impl Read for Reader {
        fn read(&mut self, b: &mut [u8]) -> io::Result<usize> {
            if self.input {
                loop {
                    if INPUT_STOP.load(Ordering::Acquire) {
                        return Ok(0);
                    }
                    if crate::platform::poll_fd_readable(self.file.as_raw_fd(), 100)? {
                        break;
                    }
                }
            }
            (&*self.file).read(b)
        }
    }
    pub(crate) struct Stream {
        reader: BufReader<Reader>,
        terminal: bool,
    }
    impl Stream {
        pub(crate) fn lock(self) -> Self {
            self
        }
        pub(crate) fn read_line(&mut self, line: &mut String) -> io::Result<usize> {
            self.reader.read_line(line)
        }
        pub(crate) fn is_terminal(&self) -> bool {
            self.terminal
        }
    }
    impl AsRawFd for Stream {
        fn as_raw_fd(&self) -> i32 {
            self.reader.get_ref().file.as_raw_fd()
        }
    }
    impl Read for Stream {
        fn read(&mut self, b: &mut [u8]) -> io::Result<usize> {
            self.reader.read(b)
        }
    }
    impl BufRead for Stream {
        fn fill_buf(&mut self) -> io::Result<&[u8]> {
            self.reader.fill_buf()
        }
        fn consume(&mut self, n: usize) {
            self.reader.consume(n)
        }
    }
    impl Write for Stream {
        fn write(&mut self, b: &[u8]) -> io::Result<usize> {
            (&*self.reader.get_ref().file).write(b)
        }
        fn flush(&mut self) -> io::Result<()> {
            Ok(())
        }
    }
    fn stream(index: usize) -> Stream {
        let (file, terminal) = FILES
            .lock()
            .unwrap()
            .as_ref()
            .expect("host streams captured before runtime")[index]
            .clone();
        Stream {
            reader: BufReader::with_capacity(
                4096,
                Reader {
                    file,
                    input: index == 0,
                },
            ),
            terminal,
        }
    }
    pub(crate) fn stdin() -> Stream {
        stream(0)
    }
    pub(crate) fn stdout() -> Stream {
        stream(1)
    }
    pub(crate) fn stderr() -> Stream {
        stream(2)
    }
}
