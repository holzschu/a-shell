// ios_system owns the invoking pane's thread-local FILE streams.
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <unistd.h>
#include "ios_system.h"

extern int fd_embedded_run(int argc, const char *const *argv, int output, int errors);
static pthread_mutex_t command_lock = PTHREAD_MUTEX_INITIALIZER;

struct command_cleanup {
    int status;
    int cwd;
};

static void restore_command(void *context) {
    struct command_cleanup *state = context;
    if (state->cwd >= 0) {
        if (fchdir(state->cwd) < 0) {
            state->status = 1;
            fprintf(thread_stderr, "Cannot restore fd working directory; restart the app\n");
        }
        close(state->cwd);
    }
    pthread_mutex_unlock(&command_lock);
}

int fd_ios_main(int argc, char **argv) {
    if (pthread_mutex_trylock(&command_lock) != 0) {
        fprintf(thread_stderr, "fd is already running in this app\n");
        return 1;
    }
    struct command_cleanup state = {1, open(".", O_RDONLY)};
    // ios_system can terminate a command with pthread_exit or pthread_cancel.
    pthread_cleanup_push(restore_command, &state);
    if (state.cwd < 0) {
        fprintf(thread_stderr, "Cannot save fd working directory (errno %d)\n", errno);
        goto restore;
    }
    if (!thread_stdout || !thread_stderr) {
        goto restore;
    }
    // Rust duplicates these borrowed descriptors and passes owned Files to workers.
    // fd never reads stdin; no process-wide descriptor is changed.
    state.status = fd_embedded_run(argc, (const char *const *)argv,
                                  fileno(thread_stdout), fileno(thread_stderr));
restore:
    pthread_cleanup_pop(1);
    return state.status;
}
