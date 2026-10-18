// Capture ios_system TLS before entering Go, whose goroutines use other threads.
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <unistd.h>
#include "ios_system.h"

extern int ios_getWindowSize(int *, int *, const void *);
extern int ios_opentty(void);
extern void ios_closetty(void);
extern int fzf_embedded_run(int, char **, int, int, int, int, char **);
static pthread_mutex_t command_lock = PTHREAD_MUTEX_INITIALIZER;
static const void *terminal_session;
static int terminal_fd = -1;
static int terminal_raw;

int fzf_terminal_input(void) { return dup(terminal_fd); }
int fzf_terminal_raw(int enabled) {
    if (terminal_fd < 0) return ENOTTY;
    if (terminal_raw == (enabled != 0)) return 0;
    terminal_raw = enabled != 0;
    if (enabled) ios_startInteractive();
    else ios_stopInteractive();
    return 0;
}
int fzf_terminal_size(int *columns, int *rows) {
    return ios_getWindowSize(columns, rows, terminal_session);
}

int fzf_ios_main(int argc, char **argv) {
    if (pthread_mutex_trylock(&command_lock)) {
        fprintf(thread_stderr, "fzf is already running in this process\n");
        return 2;
    }
    // Keep cancellation inside the key parser; pthread cancellation cannot unwind Go.
    int cancellation;
    pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cancellation);
    terminal_session = ios_getContext();
    // Getting the descriptor alone does not route the app's key events to it.
    // Activate the stock tty route on this thread while its session TLS is valid.
    int previous_pager = ios_activePager();
    terminal_fd = ios_opentty();
    int opened_tty = terminal_fd >= 0;
    if (terminal_fd < 0) terminal_fd = ios_getstdin();
    int previous_mode = ios_storeInteractive();
    terminal_raw = previous_mode;
    int flags = terminal_fd >= 0 ? fcntl(terminal_fd, F_GETFL) : -1;
    int status = fzf_embedded_run(argc, argv, fileno(thread_stdin),
        fileno(thread_stdout), fileno(thread_stderr),
        ios_isatty(fileno(thread_stdin)), environmentVariables(ios_currentPid()));
    if (terminal_fd >= 0) fzf_terminal_raw(previous_mode);
    if (flags >= 0 && fcntl(terminal_fd, F_SETFL, flags) < 0) {
        fprintf(thread_stderr, "Cannot restore fzf terminal flags (errno %d)\n", errno);
        status = 2;
    }
    if (opened_tty && !previous_pager) ios_closetty();
    terminal_fd = -1;
    terminal_session = NULL;
    pthread_mutex_unlock(&command_lock);
    pthread_setcancelstate(cancellation, NULL);
    return status;
}
