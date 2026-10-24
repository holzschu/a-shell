#ifndef ASHELL_HOST_PANE_H
#define ASHELL_HOST_PANE_H

#include "NativePane.h"

#ifdef __cplusplus
extern "C" {
#endif
#pragma GCC visibility push(default)

// Explicit app-process runner for commands that exceed the extension memory limit.
// Uses the same streams, options and handle lifetime as NativePane.h. One live host
// pane is admitted (EBUSY for another); it shares the app's process cwd and memory.
// No extension allocation or automatic routing is performed. Do not forward worker
// identity environment overrides. Cancellation returns ENOTSUP while running.
// Interrupt requires a Dash foreground command with ASHELL_IOS_SOCKET_INPUT=1
// in envp; otherwise it can return ESRCH. Its PID hook is process-wide: unrelated
// Dash sessions must not enable that variable concurrently. Release retains live cleanup.
// poll_usage returns the app process RUSAGE_SELF at exit, not per-command usage.
int ashell_host_pane_spawn(const char *, const char *, unsigned, unsigned, const char *const *, int *, void **);
int ashell_host_pane_spawn_ex(const char *, const char *, unsigned, unsigned, const char *const *, ashell_pane_options *, int *, void **);
int ashell_host_pane_poll(void *, int *);
int ashell_host_pane_poll_usage(void *, int *, struct rusage *, int *);
int ashell_host_pane_resize(void *, unsigned, unsigned);
int ashell_host_pane_close_stdin(void *);
int ashell_host_pane_interrupt(void *);
int ashell_host_pane_cancel(void *);
void ashell_host_pane_release(void *);

// Explicit worker-to-host broker route. Handles remain in the calling worker;
// poll reports -EPIPE if the host connection is lost. No admission policy here.
int ashell_worker_host_spawn_ex(const char *, const char *, unsigned, unsigned, const char *const *, ashell_pane_options *, int *, void **);
int ashell_worker_host_poll(void *, int *);
int ashell_worker_host_poll_usage(void *, int *, struct rusage *, int *);
int ashell_worker_host_resize(void *, unsigned, unsigned);
int ashell_worker_host_close_stdin(void *);
int ashell_worker_host_interrupt(void *);
int ashell_worker_host_cancel(void *);
void ashell_worker_host_release(void *);

#pragma GCC visibility pop
#ifdef __cplusplus
}
#endif
#endif
