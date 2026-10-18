//! Reentrant native command boundary; the host owns argv and serializes calls.
use clap::Parser;
use std::ffi::{CStr, OsString, c_char, c_int};
use std::io::Write;
use std::os::unix::ffi::OsStringExt;

#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruff_embedded_run(argc: c_int, argv: *const *const c_char) -> c_int {
    let args = (0..argc as usize)
        .map(|index| {
            OsString::from_vec(
                unsafe { CStr::from_ptr(*argv.add(index)) }
                    .to_bytes()
                    .to_vec(),
            )
        })
        .collect::<Vec<_>>();
    let result = std::thread::Builder::new()
        .name("ruff-main".into())
        .stack_size(16 * 1024 * 1024)
        .spawn(move || std::panic::catch_unwind(|| run_args(args)))
        .map_err(|error| format!("Cannot start Ruff: {error}"))
        .and_then(|thread| {
            thread
                .join()
                .map_err(|_| "Ruff command thread panicked".into())
        });
    let status = match result {
        Ok(Ok(status)) => status,
        Ok(Err(_)) => {
            eprintln!("Ruff panicked");
            2
        }
        Err(error) => {
            eprintln!("{error}");
            2
        }
    };
    let _ = std::io::stdout().flush();
    let _ = std::io::stderr().flush();
    status
}

fn run_args(args: Vec<OsString>) -> c_int {
    let result = (|| -> anyhow::Result<crate::ExitStatus> {
        let args = ruff_command_line::expand_args(args.into_iter())?;
        let args = match crate::args::Args::try_parse_from(args) {
            Ok(args) => args,
            Err(error) => {
                let status = error.exit_code();
                let _ = error.print();
                return Ok(match status {
                    0 => crate::ExitStatus::Success,
                    _ => crate::ExitStatus::Error,
                });
            }
        };
        // The scoped pool joins all workers before the host closes stream copies.
        rayon::ThreadPoolBuilder::new()
            .num_threads(2)
            .stack_size(16 * 1024 * 1024)
            .build_scoped(
                |thread| thread.run(),
                |pool| pool.install(|| crate::run(args)),
            )?
    })();
    match result {
        Ok(crate::ExitStatus::Success) => 0,
        Ok(crate::ExitStatus::Failure) => 1,
        Ok(crate::ExitStatus::Error) => 2,
        Err(error) => {
            eprintln!("ruff failed: {error:#}");
            2
        }
    }
}
