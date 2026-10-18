//! In-process CLI boundary. Each invocation owns duplicated a-Shell stream fds.
use gix::error::ResultExt;
use std::{
    cell::RefCell,
    ffi::{CStr, OsString},
    fs::File,
    io::Write,
    os::{
        fd::FromRawFd,
        raw::{c_char, c_int},
        unix::ffi::OsStringExt,
    },
    sync::Once,
};

thread_local! {
    static CONTEXT: RefCell<Option<Context>> = const { RefCell::new(None) };
}
struct Context {
    args: Vec<OsString>,
    input: File,
    out: File,
    err: File,
    parse_status: Option<i32>,
}

pub fn args_os() -> Vec<OsString> {
    CONTEXT.with(|c| {
        c.borrow()
            .as_ref()
            .expect("embedded invocation")
            .args
            .clone()
    })
}
pub fn parse<T: clap::Parser>() -> gix::Result<T> {
    T::try_parse_from(args_os()).map_err(|error| {
        CONTEXT.with(|c| {
            let mut c = c.borrow_mut();
            let c = c.as_mut().expect("embedded invocation");
            c.parse_status = Some(error.exit_code());
            let stream = if error.use_stderr() {
                &mut c.err
            } else {
                &mut c.out
            };
            let _ = write!(stream, "{error}");
        });
        gix::error::message("argument parsing returned").into()
    })
}
pub fn stdin() -> File {
    CONTEXT.with(|c| {
        c.borrow()
            .as_ref()
            .expect("embedded invocation")
            .input
            .try_clone()
            .expect("duplicate input")
    })
}

pub fn run<T>(
    run: impl FnOnce(&mut dyn Write, &mut dyn Write) -> gix::Result<T>,
) -> gix::Result<T> {
    let (mut out, mut err) = CONTEXT
        .with(|c| {
            let c = c.borrow();
            let c = c.as_ref().expect("embedded invocation");
            Ok::<_, std::io::Error>((c.out.try_clone()?, c.err.try_clone()?))
        })
        .or_error()?;
    run(&mut out, &mut err)
}

/// The caller transfers ownership of input/output/error fds, and keeps argv alive until return.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn gitoxide_embedded_run(
    argc: c_int,
    argv: *const *const c_char,
    input: c_int,
    out: c_int,
    err: c_int,
) -> c_int {
    static PANIC_HOOK: Once = Once::new();
    PANIC_HOOK.call_once(|| {
        let previous = std::panic::take_hook();
        std::panic::set_hook(Box::new(move |info| {
            // catch_unwind reports our failures to the owned stderr below. Preserve host panics.
            let ours = CONTEXT
                .try_with(|c| c.try_borrow().map_or(true, |c| c.is_some()))
                .unwrap_or(false);
            if !ours {
                previous(info);
            }
        }));
    });
    let args = unsafe { std::slice::from_raw_parts(argv, argc as usize) }
        .iter()
        .map(|p| OsString::from_vec(unsafe { CStr::from_ptr(*p) }.to_bytes().to_vec()))
        .collect::<Vec<_>>();
    let input = unsafe { File::from_raw_fd(input) };
    let out = unsafe { File::from_raw_fd(out) };
    let err = unsafe { File::from_raw_fd(err) };
    // A dedicated stack accommodates checkout/revision algorithms without changing host threads.
    match std::thread::Builder::new()
        .name("gitoxide-command".into())
        .stack_size(16 * 1024 * 1024)
        .spawn(move || {
            let porcelain = args.first().is_some_and(|a| a == "ein");
            CONTEXT.with(|c| {
                *c.borrow_mut() = Some(Context {
                    args,
                    input,
                    out,
                    err,
                    parse_status: None,
                })
            });
            let result = std::panic::catch_unwind(|| {
                if porcelain {
                    crate::porcelain::main()
                } else {
                    crate::plumbing::main()
                }
            });
            CONTEXT.with(|c| {
                let mut c = c.borrow_mut().take().expect("embedded invocation");
                if let Some(status) = c.parse_status {
                    return status;
                }
                match result {
                    Ok(Ok(())) => 0,
                    Ok(Err(error)) => {
                        let _ = writeln!(c.err, "Error: {error}");
                        1
                    }
                    Err(_) => {
                        let _ = writeln!(c.err, "gitoxide panicked; command failed");
                        1
                    }
                }
            })
        }) {
        Ok(handle) => handle.join().unwrap_or(1),
        Err(_) => 1,
    }
}
