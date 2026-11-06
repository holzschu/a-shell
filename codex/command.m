// Rust stdin/stdout use process descriptors; diagnostics own a separate stream.
// Embedded Codex requires exclusive app command ownership for the whole invocation.
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <termios.h>
#include <unistd.h>
#import <UIKit/UIKit.h>
#include "ios_system.h"

extern int codex_embedded_run(int argc, const char *const *argv);
extern int codex_embedded_uses_tui(int argc, const char *const *argv);
extern int codex_ios_prepare_home(const char *const env[]);
extern int ios_opentty(void);
extern void ios_closetty(void);
static pthread_mutex_t command_lock = PTHREAD_MUTEX_INITIALIZER;
static char **command_environment;
static int command_error = -1;
static char **copy_tool_strings(const char *const *values);
static void free_tool_strings(char **values);

// Only this invocation's immutable snapshot changes; HOME and global env stay intact.
static int default_codex_home(char ***environment) {
    char **values = *environment;
    size_t count = 0, home_index = SIZE_MAX;
    const char *group = NULL;
    while (values[count]) {
        if (!strncmp(values[count], "CODEX_HOME=", 11)) {
            if (values[count][11]) return 0;
            home_index = count;
        }
        if (!strncmp(values[count], "GROUP=", 6)) group = values[count] + 6;
        count++;
    }
    if (!group || !*group) return ENOENT;
    char *entry = NULL;
    if (asprintf(&entry, "CODEX_HOME=%s/Library/codex", group) < 0) return ENOMEM;
    if (home_index != SIZE_MAX) {
        free(values[home_index]);
        values[home_index] = entry;
    } else {
        char **extended = realloc(values, (count + 2) * sizeof(*values));
        if (!extended) { free(entry); return ENOMEM; }
        extended[count] = entry;
        extended[count + 1] = NULL;
        *environment = extended;
    }
    return 0;
}

// The command lock and runtime join keep this immutable snapshot alive for workers.
const char *const *codex_ios_command_environment(void) {
    return (const char *const *)command_environment;
}

// Rust duplicates this command-thread stream before starting any runtime workers.
int codex_ios_command_stderr(void) {
    return command_error;
}

// Capture errors occur on this command thread, before Rust has an owned writer.
void codex_ios_stderr_capture_error(int error) {
    fprintf(thread_stderr, "Cannot capture Codex stderr (errno %d)\n", error);
}

const char *codex_ios_command_getenv(const char *name) {
    if (!command_environment) return getenv(name);
    size_t length = strlen(name);
    for (size_t i = 0; command_environment[i]; i++) {
        const char *entry = command_environment[i];
        if (!strncmp(entry, name, length) && entry[length] == '=') return entry + length + 1;
    }
    return NULL;
}

// arboard's desktop backends cannot build on iOS. Keep clipboard ownership in UIKit.
int codex_ios_clipboard_set(const unsigned char *text, size_t length,
                            const unsigned char *html, size_t html_length) {
    __block int status = 1;
    void (^copy)(void) = ^{
        @autoreleasepool {
            NSMutableDictionary *item = [NSMutableDictionary dictionary];
            item[@"public.utf8-plain-text"] = [NSData dataWithBytes:text length:length];
            if (html_length) {
                // HTML consumers otherwise guess a legacy encoding for UTF-8 fragments.
                NSMutableData *document = [NSMutableData dataWithData:[@"<meta charset=\"utf-8\">" dataUsingEncoding:NSUTF8StringEncoding]];
                [document appendBytes:html length:html_length];
                item[@"public.html"] = document;
            }
            UIPasteboard.generalPasteboard.items = @[item];
            status = 0;
        }
    };
    if (NSThread.isMainThread) copy();
    else dispatch_sync(dispatch_get_main_queue(), copy);
    return status;
}

int codex_ios_clipboard_text(unsigned char **bytes, size_t *length, size_t limit) {
    __block unsigned char *result = NULL;
    __block size_t count = 0;
    __block int status = 0;
    void (^read_text)(void) = ^{
        @autoreleasepool {
            NSData *data = [UIPasteboard.generalPasteboard.string dataUsingEncoding:NSUTF8StringEncoding];
            if (data.length > limit) { status = 2; return; }
            if (data.length) {
                result = malloc(data.length);
                if (!result) { status = 1; return; }
                count = data.length;
                memcpy(result, data.bytes, count);
            }
        }
    };
    if (NSThread.isMainThread) read_text();
    else dispatch_sync(dispatch_get_main_queue(), read_text);
    *bytes = result;
    *length = count;
    return status;
}

unsigned char *codex_ios_clipboard_png(size_t *length) {
    __block unsigned char *result = NULL;
    __block size_t count = 0;
    void (^read_image)(void) = ^{
        @autoreleasepool {
            UIImage *image = UIPasteboard.generalPasteboard.image;
            NSData *data = image ? UIImagePNGRepresentation(image) : nil;
            if (data.length) {
                result = malloc(data.length);
                if (result) {
                    count = data.length;
                    memcpy(result, data.bytes, count);
                }
            }
        }
    };
    if (NSThread.isMainThread) read_image();
    else dispatch_sync(dispatch_get_main_queue(), read_image);
    *length = count;
    return result;
}

struct command_cleanup {
    int saved[2];
    char **environment;
    int status;
    int opened_tty;
    int prior_pager;
    sigset_t signal_mask;
    int signal_mask_saved;
    struct sigaction resize_handler;
    int resize_handler_saved;
};

// signal-hook retains its registration across embedded invocations, but
// ios_system resets SIGWINCH when the native command thread finishes.
static struct sigaction codex_resize_handler;
static int codex_resize_handler_saved;

// Captured on the ios_system command thread; Rust workers have no session TLS.
static int terminal_streams[3];
static const void *terminal_session;
static atomic_bool terminal_raw;
static int terminal_prior_interactive;
static struct termios terminal_mode;
static int terminal_has_mode;
static int terminal_input = -1;

// Borrowed until the Rust runtime and its event reader have stopped.
int codex_ios_terminal_input(void) {
    return terminal_streams[0] ? terminal_input : -1;
}

int codex_ios_terminal_isatty(int fd) {
    return fd >= 0 && fd < 3 && terminal_streams[fd];
}

int codex_ios_terminal_set_raw(int enabled) {
    if (!terminal_streams[0] || !terminal_streams[1]) return ENOTTY;
    if (atomic_load(&terminal_raw) == (enabled != 0)) return 0;
    if (terminal_has_mode) {
        struct termios mode = terminal_mode;
        if (enabled) cfmakeraw(&mode);
        if (tcsetattr(terminal_input, TCSANOW, &mode)) return errno;
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

static void restore_command(void *context) {
    struct command_cleanup *state = context;
    if (state->signal_mask_saved && pthread_sigmask(SIG_SETMASK, &state->signal_mask, NULL)) {
        state->status = 1;
        fprintf(thread_stderr, "Cannot restore Codex signal mask; restart the app\n");
    }
    if (state->resize_handler_saved && sigaction(SIGWINCH, &state->resize_handler, NULL)) {
        state->status = 1;
        fprintf(thread_stderr, "Cannot restore Codex resize handler; restart the app\n");
    }
    if (atomic_load(&terminal_raw) && codex_ios_terminal_set_raw(0)) {
        state->status = 1;
        fprintf(thread_stderr, "Cannot restore Codex terminal input mode; restart the app\n");
    }
    if (state->opened_tty && !state->prior_pager) ios_closetty();
    for (int fd = 0; fd < 2; fd++) {
        if (state->saved[fd] >= 0) {
            if (dup2(state->saved[fd], fd) < 0) {
                state->status = 1;
                fprintf(thread_stderr, "Cannot restore descriptor %d; restart the app\n", fd);
            }
            close(state->saved[fd]);
        }
    }
    memset(terminal_streams, 0, sizeof(terminal_streams));
    terminal_session = NULL;
    terminal_has_mode = 0;
    terminal_input = -1;
    command_environment = NULL;
    command_error = -1;
    free_tool_strings(state->environment);
    pthread_mutex_unlock(&command_lock);
}

int codex_ios_main(int argc, char **argv) {
    if (pthread_mutex_trylock(&command_lock) != 0) {
        fprintf(thread_stderr, "Codex is already running in this app\n");
        return 1;
    }
    FILE *streams[] = {thread_stdin, thread_stdout, thread_stderr};
    struct command_cleanup state = {.saved = {-1, -1}, .status = 1};
    // ios_system can terminate a command with pthread_exit or pthread_cancel.
    // Register before the first descriptor change; pop also covers normal returns.
    pthread_cleanup_push(restore_command, &state);
    state.environment = copy_tool_strings((const char *const *)environmentVariables(ios_currentPid()));
    if (!state.environment) {
        fprintf(thread_stderr, "Cannot capture Codex command environment\n");
        goto restore;
    }
    int home_error = codex_ios_prepare_home((const char *const *)state.environment);
    if (!home_error) home_error = default_codex_home(&state.environment);
    if (home_error) {
        fprintf(thread_stderr, "Cannot prepare Codex home (errno %d)\n", home_error);
        goto restore;
    }
    command_environment = state.environment;
    if (!streams[2] || (command_error = fileno(streams[2])) < 0) {
        fprintf(thread_stderr, "Cannot capture Codex stderr\n");
        goto restore;
    }
    for (int fd = 0; fd < 2; fd++) {
        if (!streams[fd] || (state.saved[fd] = dup(fd)) < 0) {
            fprintf(thread_stderr, "Cannot save Codex descriptor %d (errno %d)\n", fd, errno);
            goto restore;
        }
    }
    // Never redirect process stderr: Foundation and the app keep their own logs.
    for (int fd = 0; fd < 2; fd++) {
        if (dup2(fileno(streams[fd]), fd) < 0) {
            fprintf(thread_stderr, "Cannot redirect Codex descriptor %d (errno %d)\n", fd, errno);
            goto restore;
        }
    }
    terminal_session = ios_getContext();
    terminal_prior_interactive = ios_storeInteractive();
    for (int fd = 0; fd < 3; fd++) terminal_streams[fd] = ios_isatty(fd);
    terminal_input = fileno(streams[0]);
    if (codex_embedded_uses_tui(argc, (const char *const *)argv)) {
        if (!terminal_streams[0] || !terminal_streams[1]) {
            fprintf(thread_stderr, "Codex TUI requires interactive a-Shell input and output\n");
            goto restore;
        }
        if (sigaction(SIGWINCH, NULL, &state.resize_handler)) {
            fprintf(thread_stderr, "Cannot capture Codex resize handler (errno %d)\n", errno);
            goto restore;
        }
        state.resize_handler_saved = 1;
        if (codex_resize_handler_saved && sigaction(SIGWINCH, &codex_resize_handler, NULL)) {
            fprintf(thread_stderr, "Cannot activate Codex resize handler (errno %d)\n", errno);
            goto restore;
        }
        // Dash can launch the native thread with SIGWINCH blocked. The host
        // targets this command thread, rather than the Rust runtime workers.
        sigset_t resize_signal;
        sigemptyset(&resize_signal);
        sigaddset(&resize_signal, SIGWINCH);
        int signal_error = pthread_sigmask(SIG_UNBLOCK, &resize_signal, &state.signal_mask);
        if (signal_error) {
            fprintf(thread_stderr, "Cannot enable Codex resize signal (errno %d)\n", signal_error);
            goto restore;
        }
        state.signal_mask_saved = 1;
        // Activate the host key route while session TLS is available. Rust workers
        // borrow this captured tty directly instead of replacing process fd 0.
        state.prior_pager = ios_activePager();
        terminal_input = ios_opentty();
        state.opened_tty = terminal_input >= 0;
        if (terminal_input < 0) {
            fprintf(thread_stderr, "Cannot open Codex terminal input (errno %d)\n", ENOTTY);
            goto restore;
        }
    }
    terminal_has_mode = tcgetattr(terminal_input, &terminal_mode) == 0;
    state.status = codex_embedded_run(argc, (const char *const *)argv);
    if (state.resize_handler_saved) {
        struct sigaction handler;
        if (sigaction(SIGWINCH, NULL, &handler)) {
            state.status = 1;
            fprintf(thread_stderr, "Cannot retain Codex resize handler (errno %d)\n", errno);
        } else if (handler.sa_handler != SIG_DFL && handler.sa_handler != SIG_IGN &&
                   (codex_resize_handler_saved || handler.sa_handler != state.resize_handler.sa_handler)) {
            codex_resize_handler = handler;
            codex_resize_handler_saved = 1;
        }
    }
restore:
    pthread_cleanup_pop(1);
    return state.status;
}

// Tool calls own a fresh ios_system session. They must not reuse the caller's terminal session.
extern int ios_execve(const char *, char *const [], char *[]);
extern int ashell_register_owned_streams(FILE *, FILE *, FILE *, void **);
extern void ashell_wait_owned_streams(void *);
extern int ashell_cancel_owned_streams(void *);
extern void ashell_unregister_owned_streams(void **);
static pthread_mutex_t tool_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t tool_idle = PTHREAD_COND_INITIALIZER;
static int tool_active;

struct tool_call {
    char *cwd;
    char **argv, **env;
    int descriptors[3];
    int status, error, joining, joined;
    _Atomic int cancelled;
    pthread_t thread;
    pthread_mutex_t lock;
    void *registration;
};

static void *execute_tool(void *context) {
    struct tool_call *call = context;
    sigset_t blocked;
    sigemptyset(&blocked);
    sigaddset(&blocked, SIGPIPE);
    call->error = pthread_sigmask(SIG_BLOCK, &blocked, NULL);
    if (call->error) return NULL;
    @autoreleasepool {
        // ios_system sessions and native commands change the process cwd and handlers.
        // Serialize only tool calls; Codex itself already owns the app command boundary.
        pthread_mutex_lock(&tool_lock);
        while (tool_active && !atomic_load(&call->cancelled))
            pthread_cond_wait(&tool_idle, &tool_lock);
        int acquired = !atomic_load(&call->cancelled);
        if (acquired) tool_active = 1;
        pthread_mutex_unlock(&tool_lock);
        int previous_directory = acquired ? open(".", O_RDONLY) : -1;
        FILE *streams[3] = {NULL, NULL, NULL};
        void *registration = NULL;
        char key[64];
        snprintf(key, sizeof(key), "codex-tool-%s", NSUUID.UUID.UUIDString.UTF8String);
        struct sigaction handlers[NSIG];
        unsigned char saved_handlers[NSIG] = {0};
        int session_started = 0;
        if (!acquired) { call->status = 130; goto finished; }
        if (previous_directory < 0) { call->error = errno; goto finished; }
        for (int i = 0; i < 3; i++) {
            streams[i] = fdopen(call->descriptors[i], i == 0 ? "rb" : "wb");
            if (!streams[i]) { call->error = errno; goto finished; }
            call->descriptors[i] = -1; // FILE now owns this duplicated descriptor.
        }
        call->error = ashell_register_owned_streams(streams[0], streams[1], streams[2], &registration);
        if (call->error) goto finished;
        pthread_mutex_lock(&call->lock);
        call->registration = registration;
        if (atomic_load(&call->cancelled))
            call->error = ashell_cancel_owned_streams(registration);
        pthread_mutex_unlock(&call->lock);
        if (call->error) goto finished;
        for (int number = 1; number < NSIG; number++) {
            if (number == SIGKILL || number == SIGSTOP) continue;
            saved_handlers[number] = sigaction(number, NULL, &handlers[number]) == 0;
        }
        ios_switchSession(key);
        session_started = 1;
        ios_setContext(key);
        ios_setStreams(streams[0], streams[1], streams[2]);
        ios_settty(isatty(fileno(streams[0])) ? streams[0] : NULL);
        ios_useNativeTTY(true);
        thread_stdin = streams[0];
        thread_stdout = streams[1];
        thread_stderr = streams[2];
        thread_context = key;
        ios_setDirectoryURL([NSURL fileURLWithPath:@(call->cwd) isDirectory:YES]);
        struct stat wanted, actual;
        if (stat(call->cwd, &wanted) || stat(".", &actual)) {
            call->error = errno;
            goto finished;
        }
        if (!S_ISDIR(wanted.st_mode) || wanted.st_dev != actual.st_dev || wanted.st_ino != actual.st_ino) {
            call->error = EACCES;
            goto finished;
        }
        // ios_fork allocates the child's private environment and holds pid_mtx until
        // command registration. Never return between allocation and ios_execve.
        pid_t pid = ios_fork();
        ios_execve(call->argv[0], call->argv, call->env);
        ios_waitpid(pid);
        ashell_wait_owned_streams(registration);
        call->status = atomic_load(&call->cancelled) ? 130 : ios_getCommandStatus();
        ios_releaseThreadId(pid);
finished:
        pthread_mutex_lock(&call->lock);
        call->registration = NULL;
        pthread_mutex_unlock(&call->lock);
        ashell_unregister_owned_streams(&registration);
        for (int i = 0; i < 3; i++) {
            if (streams[i] && fclose(streams[i]) && !call->error) call->error = errno;
            if (call->descriptors[i] >= 0) {
                close(call->descriptors[i]);
                call->descriptors[i] = -1;
            }
        }
        if (previous_directory >= 0) {
            if (fchdir(previous_directory) && !call->error) call->error = errno;
            close(previous_directory);
        }
        if (session_started) ios_closeSession(key);
        for (int number = 1; number < NSIG; number++) {
            if (saved_handlers[number] && sigaction(number, &handlers[number], NULL) && !call->error)
                call->error = errno;
        }
        if (acquired) {
            pthread_mutex_lock(&tool_lock);
            tool_active = 0;
            pthread_cond_broadcast(&tool_idle);
            pthread_mutex_unlock(&tool_lock);
        }
    }
    return NULL;
}

static void free_tool_strings(char **values) {
    if (!values) return;
    for (size_t i = 0; values[i]; i++) free(values[i]);
    free(values);
}

static char **copy_tool_strings(const char *const *values) {
    size_t count = 0;
    while (values[count]) count++;
    char **copy = calloc(count + 1, sizeof(*copy));
    if (!copy) return NULL;
    for (size_t i = 0; i < count; i++) {
        copy[i] = strdup(values[i]);
        if (!copy[i]) { free_tool_strings(copy); return NULL; }
    }
    return copy;
}

static void free_tool(struct tool_call *call) {
    for (int i = 0; i < 3; i++) if (call->descriptors[i] >= 0) close(call->descriptors[i]);
    free(call->cwd);
    free_tool_strings(call->argv);
    free_tool_strings(call->env);
    pthread_mutex_destroy(&call->lock);
    free(call);
}

// The caller owns one live handle. Start copies all inputs and duplicates descriptors.
// Cancel and wait may overlap; release requires all accessors to have returned.
int codex_ios_tool_start(const char *cwd, const char *const argv[], const char *const env[],
                         int input, int output, int diagnostic, void **handle) {
    if (!cwd || !argv || !argv[0] || !*argv[0] || !env || !handle || *handle) return EINVAL;
    struct tool_call *call = calloc(1, sizeof(*call));
    if (!call) return ENOMEM;
    for (int i = 0; i < 3; i++) call->descriptors[i] = -1;
    atomic_init(&call->cancelled, 0);
    call->status = 1;
    int error = pthread_mutex_init(&call->lock, NULL);
    if (error) { free(call); return error; }
    call->cwd = strdup(cwd);
    call->argv = copy_tool_strings(argv);
    call->env = copy_tool_strings(env);
    if (!call->cwd || !call->argv || !call->env) { free_tool(call); return ENOMEM; }
    int descriptors[] = {input, output, diagnostic};
    for (int i = 0; i < 3; i++) {
        call->descriptors[i] = dup(descriptors[i]);
        if (call->descriptors[i] < 0) { error = errno; free_tool(call); return error; }
    }
    error = pthread_create(&call->thread, NULL, execute_tool, call);
    if (error) { free_tool(call); return error; }
    *handle = call;
    return 0;
}

int codex_ios_tool_cancel(void *handle) {
    if (!handle) return EINVAL;
    struct tool_call *call = handle;
    pthread_mutex_lock(&call->lock);
    atomic_store(&call->cancelled, 1);
    int error = call->registration ? ashell_cancel_owned_streams(call->registration) : 0;
    pthread_mutex_unlock(&call->lock);
    // Wake a queued job without cancelling the runner or another job's command tree.
    pthread_mutex_lock(&tool_lock);
    pthread_cond_broadcast(&tool_idle);
    pthread_mutex_unlock(&tool_lock);
    return error;
}

int codex_ios_tool_wait(void *handle, int *status) {
    if (!handle || !status) return EINVAL;
    struct tool_call *call = handle;
    pthread_mutex_lock(&call->lock);
    if (call->joining || call->joined) { pthread_mutex_unlock(&call->lock); return EALREADY; }
    call->joining = 1;
    pthread_mutex_unlock(&call->lock);
    int error = pthread_join(call->thread, NULL);
    pthread_mutex_lock(&call->lock);
    call->joining = 0;
    call->joined = !error;
    pthread_mutex_unlock(&call->lock);
    if (error) return error;
    *status = call->status;
    return call->error;
}

int codex_ios_tool_release(void **handle) {
    if (!handle || !*handle) return EINVAL;
    struct tool_call *call = *handle;
    pthread_mutex_lock(&call->lock);
    int joined = call->joined;
    pthread_mutex_unlock(&call->lock);
    if (!joined) return EBUSY;
    free_tool(call);
    *handle = NULL;
    return 0;
}
