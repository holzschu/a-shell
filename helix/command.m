// Duplicate only command-owned streams; process descriptors 0-2 are never changed.
#include <errno.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <limits.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <stdatomic.h>
// ios_system.h ABI: these streams belong to the invoking command thread.
extern __thread FILE *thread_stdin;
extern __thread FILE *thread_stdout;
extern __thread FILE *thread_stderr;

extern int hx_embedded_run(int argc, const char *const *argv);
static pthread_mutex_t command_lock = PTHREAD_MUTEX_INITIALIZER;
static int command_fds[3] = {-1, -1, -1};
int hx_io_fd(int index) { return index >= 0 && index < 3 ? command_fds[index] : -1; }

extern int ios_isatty(int fd);
extern const void *ios_getContext(void);
extern int ios_getWindowSize(int *, int *, const void *);
extern int ios_storeInteractive(void);
extern void ios_startInteractive(void);
extern void ios_stopInteractive(void);
static const void *terminal_session;
static int terminal_streams[3], terminal_has_mode;
static int terminal_prior_interactive;
static struct termios terminal_mode;
static atomic_bool terminal_raw;

// The shared terminal ABI is private to this framework, including its legacy Codex prefix.
int codex_ios_terminal_isatty(int fd) {
    for (int i = 0; i < 3; i++) if (fd == command_fds[i]) return terminal_streams[i];
    return 0;
}

int codex_ios_terminal_set_raw(int enabled) {
    if (!terminal_streams[0] || !terminal_streams[1]) return ENOTTY;
    if (atomic_load(&terminal_raw) == (enabled != 0)) return 0;
    if (terminal_has_mode) {
        struct termios mode = terminal_mode;
        if (enabled) cfmakeraw(&mode);
        if (tcsetattr(command_fds[0], TCSANOW, &mode)) return errno;
    }
    if (enabled || terminal_prior_interactive) ios_startInteractive();
    else ios_stopInteractive();
    atomic_store(&terminal_raw, enabled != 0);
    return 0;
}

int codex_ios_terminal_size(unsigned short *columns, unsigned short *rows) {
    int width, height;
    int error = ios_getWindowSize(&width, &height, terminal_session);
    if (error) return error;
    *columns = (unsigned short)width;
    *rows = (unsigned short)height;
    return 0;
}

struct command_cleanup { int status; };

static void restore_command(void *context) {
    struct command_cleanup *state = context;
    if (atomic_load(&terminal_raw) && codex_ios_terminal_set_raw(0)) {
        state->status = 1;
        fprintf(thread_stderr, "Cannot restore Helix terminal input mode; restart the app\n");
    }
    for (int fd = 0; fd < 3; fd++) {
        if (command_fds[fd] >= 0) close(command_fds[fd]);
        command_fds[fd] = -1;
    }
    terminal_session = NULL;
    terminal_has_mode = 0;
    memset(terminal_streams, 0, sizeof(terminal_streams));
    pthread_mutex_unlock(&command_lock);
}

int hx_ios_main(int argc, char **argv) {
    if (pthread_mutex_trylock(&command_lock) != 0) {
        fprintf(thread_stderr, "Helix is already running in this app\n");
        return 1;
    }
    Dl_info location;
    if (!dladdr((const void *)hx_ios_main, &location)) { pthread_mutex_unlock(&command_lock); return 1; }
    char runtime[PATH_MAX];
    if (snprintf(runtime, sizeof(runtime), "%s", location.dli_fname) >= (int)sizeof(runtime)) { pthread_mutex_unlock(&command_lock); return 1; }
    char *slash = strrchr(runtime, '/');
    if (!slash || (size_t)(slash - runtime) + sizeof("/runtime") > sizeof(runtime)) { pthread_mutex_unlock(&command_lock); return 1; }
    strcpy(slash, "/runtime");
    setenv("HELIX_RUNTIME", runtime, 1);
    FILE *streams[] = {thread_stdin, thread_stdout, thread_stderr};
    struct command_cleanup state = {1};
    pthread_cleanup_push(restore_command, &state);
    for (int fd = 0; fd < 3; fd++) {
        if (!streams[fd] || (command_fds[fd] = dup(fileno(streams[fd]))) < 0) goto restore;
    }
    terminal_session = ios_getContext();
    terminal_prior_interactive = ios_storeInteractive();
    for (int i = 0; i < 3; i++) terminal_streams[i] = ios_isatty(i);
    terminal_has_mode = tcgetattr(command_fds[0], &terminal_mode) == 0;
    state.status = hx_embedded_run(argc, (const char *const *)argv);
restore:
    pthread_cleanup_pop(1);
    return state.status;
}

// Invoke the existing clipboard command on this worker thread with owned input.
int hx_pbcopy(const unsigned char *data, size_t length) {
    FILE *input = tmpfile();
    if (!input) return 1;
    if (fwrite(data, 1, length, input) != length) { fclose(input); return 1; }
    rewind(input);
    FILE *saved = thread_stdin;
    thread_stdin = input;
    extern int pbcopy(int, char **);
    char *argv[] = {"pbcopy", NULL};
    int status = pbcopy(1, argv);
    thread_stdin = saved;
    fclose(input);
    return status;
}

#define GRAMMAR(name) extern void *tree_sitter_##name(void);
GRAMMAR(markdown)
GRAMMAR(markdown_inline)
GRAMMAR(rust)
GRAMMAR(python)
GRAMMAR(toml)
GRAMMAR(json)
GRAMMAR(bash)

void *hx_static_grammar(const char *name) {
#define MATCH(grammar) if (!strcmp(name, #grammar)) return tree_sitter_##grammar();
    MATCH(markdown)
    MATCH(markdown_inline)
    MATCH(rust)
    MATCH(python)
    MATCH(toml)
    MATCH(json)
    MATCH(bash)
    return NULL;
}
