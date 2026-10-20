#ifndef ASHELL_NATIVE_PANE_H
#define ASHELL_NATIVE_PANE_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Keep the public C ABI discoverable in Release builds with hidden visibility.
#pragma GCC visibility push(default)

// Host only: how many panes can run at once, so ashell_pane_spawn returns ENOSPC for the next one.
// The "worker_limit" setting (0 = automatic) or else the device's physical core count,
// limited to the bundled worker extensions. Read on every spawn, so a change applies at once.
int ashell_pane_capacity(void);

// command/cwd must be nonempty UTF-8; cwd must be an absolute accessible directory.
// envp is NULL or a NULL-terminated list of UTF-8 key=value overrides, copied before return.
// Dimensions are 1..9999. Returns 0 or positive errno; failure sets outputs to -1/NULL.
// Success transfers the full-duplex fd to the caller; stderr shares stdout.
// Host handles use independent extension processes and socket streams. Each worker
// accepts one native pane. Stock ios_system globals stay private to that process.
// The caller may set O_NONBLOCK on its returned descriptor.
int ashell_pane_spawn(const char *command, const char *cwd, unsigned cols,
                     unsigned rows, const char *const *envp, int *fd_out, void **job_out);

// Options for ashell_pane_spawn_ex. The caller sets size to sizeof(ashell_pane_options).
typedef struct ashell_pane_options {
    size_t size;
    // Nonzero: the command sees a terminal on stdin, stdout and stderr (isatty is true).
    // Zero: it sees plain streams, as when the caller redirects them to a file or a pipe.
    int tty;
    // Nonzero: stderr is a separate stream; its read side is written to stderr_fd.
    int separate_stderr;
    // Output, -1 unless separate_stderr succeeded. The caller owns and closes it. Drain it
    // as well as the main fd; a full unread stderr blocks the command like a full stdout.
    int stderr_fd;
} ashell_pane_options;

// ashell_pane_spawn with options. ashell_pane_spawn is this call with tty = 1 and
// separate_stderr = 0, so its behaviour is unchanged. Returns 0 or positive errno.
int ashell_pane_spawn_ex(const char *command, const char *cwd, unsigned cols, unsigned rows,
                         const char *const *envp, ashell_pane_options *options,
                         int *fd_out, void **job_out);

// Returns 0 running, 1 exited (writes final command status), or -errno.
// Repeated polling after exit preserves status. Drain the returned fd to EOF independently.
// A cleanup/restore error returns -errno after completion instead of hiding the failure.
int ashell_pane_poll(void *job, int *status_out);

// These operations return 0 or POSITIVE errno, unlike poll.
// Resize updates the worker command dimensions through ios_setWindowSize.
int ashell_pane_resize(void *job, unsigned cols, unsigned rows);
// Half-close socket stdin while keeping output open. Repeated calls are harmless.
int ashell_pane_close_stdin(void *job);
// Host cancellation terminates the entire worker process. The worker-local
// adapter returns ENOTSUP while running; interrupt targets only its foreground command.
int ashell_pane_cancel(void *job);
// Interrupt a cooked foreground command; ENOTSUP means forward ETX to the TUI/editor.
int ashell_pane_interrupt(void *job);

// Release the host connection and worker process, then drop the caller reference.
// The worker-local adapter retains live runners and their streams through cleanup.
// Caller must invalidate its pointer and release exactly once. No concurrent release
// with another call: serialize calls on each handle.
// Close the returned fd separately.
// The handle is opaque and is NOT an OS pid: never pass it to kill/waitpid/process APIs.
void ashell_pane_release(void *job);

#pragma GCC visibility pop

#ifdef __cplusplus
}
#endif
#endif
