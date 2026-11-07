#include <errno.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <fcntl.h>
#include "tmux.h"
#include "ios-engine.h"
#include "NativePane.h"
#include <dlfcn.h>

int
tmux_ios_check_shared_container(void)
{
    int (*available)(void) = (int (*)(void))dlsym(RTLD_DEFAULT, "ashell_worker_has_shared_container");
    if (available && available()) return 0;
    fprintf(thread_stderr, "tmux: shared App Group membership required for native engines\n");
    return 1;
}

// The engine owns an isolated worker process. Change its native cwd only for
// bind/connect, then restore it before servicing commands or spawning panes.
// Keep the full socket_path for tmux discovery, locks, cleanup and $TMUX.
#undef fchdir
int
tmux_ios_socket(int fd, const char *path, int binding)
{
    const char *name = strrchr(path, '/');
    struct sockaddr_un address = {.sun_family = AF_UNIX};
    if (name == NULL || name[1] == '\0') { errno = EINVAL; return -1; }
    if (strlen(++name) >= sizeof address.sun_path) { errno = ENAMETOOLONG; return -1; }
    char *directory = strndup(path, name - path);
    if (directory == NULL) return -1;
    int previous = open(".", O_RDONLY | O_DIRECTORY);
    if (previous == -1) { free(directory); return -1; }
    int result = chdir(directory);
    free(directory);
    if (result == 0) {
        strlcpy(address.sun_path, name, sizeof address.sun_path);
        result = binding ? bind(fd, (struct sockaddr *)&address, sizeof address) :
            connect(fd, (struct sockaddr *)&address, sizeof address);
    }
    int saved = errno;
    if (fchdir(previous) == -1) { result = -1; saved = errno; }
    close(previous);
    errno = saved;
    return result;
}

typedef int (*spawn_fn)(const char *, const char *, unsigned, unsigned,
    const char *const *, ashell_pane_options *, int *, void **);
typedef int (*poll_fn)(void *, int *);
typedef int (*resize_fn)(void *, unsigned, unsigned);
typedef void (*release_fn)(void *);

void
tmux_ios_send_resize(struct tmuxpeer *peer)
{
    const char *cols = ios_getenv("COLUMNS"), *rows = ios_getenv("LINES");
    unsigned size[2] = {
        cols ? strtonum(cols, 1, 9999, NULL) : 80,
        rows ? strtonum(rows, 1, 9999, NULL) : 24
    };
    static unsigned previous[2];
    if (size[0] && size[1] && memcmp(previous, size, sizeof size)) {
        proc_send(peer, MSG_RESIZE, -1, size, sizeof size);
        memcpy(previous, size, sizeof size);
    }
}

static void
pane_poll(int fd, short events, void *data)
{
    struct window_pane *wp = data;
    poll_fn poll_child = (poll_fn)dlsym(RTLD_DEFAULT, "ashell_worker_poll");
    int status = 0, result = poll_child(wp->ios_job, &status);
    struct timeval interval = {.tv_usec = 20000};
    if (result == 0) {
        evtimer_add(&wp->ios_poll, &interval);
        return;
    }
    if (result < 0) {
        log_debug("pane worker poll failed: %s", strerror(-result));
        status = 255;
    }
    tmux_ios_pane_exited(wp, status << 8);
}

int
tmux_ios_spawn_pane(struct spawn_context *sc, struct window_pane *wp,
    struct environ *environment, struct winsize *size, char **cause)
{
    spawn_fn spawn = (spawn_fn)dlsym(RTLD_DEFAULT, "ashell_worker_spawn_ex");
    if (!spawn || !dlsym(RTLD_DEFAULT, "ashell_worker_resize") ||
        !dlsym(RTLD_DEFAULT, "ashell_worker_poll") ||
        !dlsym(RTLD_DEFAULT, "ashell_worker_release")) {
        xasprintf(cause, "interactive worker broker unavailable");
        return ENOTSUP;
    }
    tmux_ios_release_pane(wp);
    struct environ_entry *entry;
    size_t count = 0;
    for (entry = environ_first(environment); entry; entry = environ_next(entry))
        if (entry->value && !(entry->flags & ENVIRON_HIDDEN)) count++;
    char **env = xcalloc(count + 1, sizeof(*env));
    count = 0;
    for (entry = environ_first(environment); entry; entry = environ_next(entry))
        if (entry->value && !(entry->flags & ENVIRON_HIDDEN))
            xasprintf(&env[count++], "%s=%s", entry->name, entry->value);
    char *command;
    const char *shell = strrchr(wp->shell, '/');
    shell = shell ? shell + 1 : wp->shell;
    // a-Shell's interactive shell is Dash; its "sh" entry is not interactive.
    if (!strcmp(shell, "sh")) shell = "dash";
    // cmd_stringify_argv quotes arguments for the shell, including embedded quotes.
    if (wp->argc == 1) {
        char *args[] = {(char *)shell, "-c", wp->argv[0]};
        command = cmd_stringify_argv(3, args);
    } else if (wp->argc > 1)
        command = cmd_stringify_argv(wp->argc, wp->argv);
    else {
        char *args[] = {(char *)shell, "-i", "-E"};
        command = cmd_stringify_argv(!strcmp(shell, "dash") ? 3 : 2, args);
    }
    ashell_pane_options options = {.size = sizeof(options), .tty = 1};
    int error = spawn(command, wp->cwd, size->ws_col, size->ws_row,
        (const char *const *)env, &options, &wp->fd, &wp->ios_job);
    free(command);
    for (size_t i = 0; env[i]; i++) free(env[i]);
    free(env);
    if (error) {
        xasprintf(cause, "pane worker: %s%s", strerror(error), error == ENOSPC ? "; all shell workers are in use; close a pane or session first" : "");
        return error;
    }
    wp->pid = -1; // The opaque worker handle is not a kernel child PID.
    wp->tty[0] = '\0';
    evtimer_set(&wp->ios_poll, pane_poll, wp);
    struct timeval interval = {.tv_usec = 20000};
    evtimer_add(&wp->ios_poll, &interval);
    return 0;
}

void
tmux_ios_release_pane(struct window_pane *wp)
{
    if (!wp->ios_job) return;
    evtimer_del(&wp->ios_poll);
    release_fn release = (release_fn)dlsym(RTLD_DEFAULT, "ashell_worker_release");
    release(wp->ios_job);
    wp->ios_job = NULL;
}

void
tmux_ios_resize_pane(struct window_pane *wp, unsigned cols, unsigned rows)
{
    if (!wp->ios_job) return;
    resize_fn resize = (resize_fn)dlsym(RTLD_DEFAULT, "ashell_worker_resize");
    int error = resize(wp->ios_job, cols, rows);
    if (error && error != ESRCH) log_debug("pane worker resize failed: %s", strerror(error));
}
