#import <Foundation/Foundation.h>
#include <stdatomic.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <pthread.h>
#include <poll.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/event.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <util.h>
#include <unistd.h>
#import "ios_system/ios_system.h"
#include "NativePane.h"

// Each extension process owns one active native pane.
static _Atomic int pane_in_flight;
// Stock explicit-PID setter avoids the libc setenv fallback for the parent PID.
extern int ios_setenv_pid(const char *, const char *, int, int);

typedef struct {
    pthread_mutex_t mutex;
    pthread_cond_t ready;
    unsigned refs;
    int initialized, startup_error, done, status, completion_error;
    int peer_control, input_closed, is_pty;
    unsigned char eof_key;
    FILE *streams[3];
    void *registration;
    char key[64];
    char *command, *cwd, *previous_cwd;
    char **env;
    unsigned cols, rows;
    struct pane_input_relay *input_relay;
} pane_job;

// One pane owns this process. Dash's optional evaluation hook borrows a fresh
// stdin pipe, while the relay keeps the editor pipe and socket alive.
static _Atomic(pane_job *) foreground_pane;
// Dash publishes the synthetic child PID before dispatch and restores its
// parent's PID after waiting. lastThreadId instead names the first descendant,
// which can be a shell blocked in ios_waitpid rather than the running command.
static _Atomic int foreground_command_pid;

__attribute__((used)) int ashell_pane_exchange_foreground_pid(int pid) {
    return atomic_exchange(&foreground_command_pid, pid);
}

typedef struct {
    unsigned char bytes[262144];
    size_t length;
} input_queue;

typedef struct command_input {
    FILE *reader;
    pane_job *job;
    int writer;
    void *registration;
    struct pane_input_relay *relay;
} command_input;

typedef struct pane_input_relay {
    pthread_mutex_t mutex;
    pthread_cond_t changed;
    pthread_t thread;
    int socket, editor_reader, editor_writer, wake[2], editor_events;
    int running, stop, error, input_eof, command_eof;
    int request, request_done, request_error;
    command_input *command, *requested_command;
    input_queue editor_queue, command_queue;
    int (*interactive)(void);
} pane_input_relay;

enum { INPUT_BEGIN = 1, INPUT_END, INPUT_RETIRE };

static int append_input(input_queue *queue, const void *bytes, size_t length) {
    if (length > sizeof(queue->bytes) - queue->length) return EOVERFLOW;
    memcpy(queue->bytes + queue->length, bytes, length);
    queue->length += length;
    return 0;
}

static int drain_input(int fd, input_queue *queue) {
    unsigned char bytes[4096];
    struct pollfd available = {.fd = fd, .events = POLLIN};
    for (;;) {
        int count = poll(&available, 1, 0);
        if (count < 0) { if (errno == EINTR) continue; return errno; }
        if (!count) return 0;
        ssize_t length = read(fd, bytes, sizeof(bytes));
        if (length < 0) { if (errno == EINTR) continue; return errno; }
        if (!length) return 0;
        int error = append_input(queue, bytes, (size_t)length);
        if (error) return error;
    }
}

static void close_input_writer(int *writer) {
    if (*writer >= 0) close(*writer);
    *writer = -1;
}

static int flush_input(int fd, input_queue *queue) {
    ssize_t count = write(fd, queue->bytes, queue->length);
    if (count < 0) return errno == EINTR || errno == EAGAIN ? 0 : errno;
    if (count) {
        queue->length -= (size_t)count;
        memmove(queue->bytes, queue->bytes + count, queue->length);
    }
    return 0;
}

static int route_input(pane_input_relay *relay, const unsigned char *bytes, size_t length) {
    for (size_t i = 0; i < length; i++) {
        unsigned char byte = bytes[i];
        int foreground = relay->command && !relay->command_eof;
        int raw = foreground && relay->interactive && relay->interactive();
        if (foreground && !raw && byte == 4) {
            relay->command_eof = 1;
            continue;
        }
        if (foreground && !raw && byte == '\r') byte = '\n';
        int error = append_input(foreground ? &relay->command_queue :
            &relay->editor_queue, &byte, 1);
        if (error) return error;
    }
    return 0;
}

static int change_input(pane_input_relay *relay) {
    command_input *command = relay->requested_command;
    if (relay->request == INPUT_BEGIN) {
        if (relay->command) return EBUSY;
        // Bytes already forwarded to libedit belong to the next foreground
        // reader once its command line has been consumed. Preserve their order.
        input_queue *typeahead = calloc(1, sizeof(*typeahead));
        if (!typeahead) return ENOMEM;
        int error = drain_input(relay->editor_reader, typeahead);
        if (!error) error = append_input(typeahead,
            relay->editor_queue.bytes, relay->editor_queue.length);
        if (!error) {
            relay->editor_queue.length = 0;
            relay->command = command;
            relay->command_eof = 0;
            error = route_input(relay, typeahead->bytes, typeahead->length);
        }
        free(typeahead);
        if (error) return error;
    } else if (relay->request == INPUT_END) {
        if (relay->command != command) return EINVAL;
        close_input_writer(&command->writer);
        relay->command_eof = 1;
    } else if (relay->request == INPUT_RETIRE) {
        if (relay->command != command) return EINVAL;
        input_queue *remaining = calloc(1, sizeof(*remaining));
        if (!remaining) return ENOMEM;
        // No borrower remains at this point. Unconsumed typeahead goes back to
        // the editor before bytes typed after Ctrl-D; it must not be discarded.
        int error = drain_input(fileno(command->reader), remaining);
        if (!error) error = append_input(remaining,
            relay->command_queue.bytes, relay->command_queue.length);
        if (!error) error = append_input(remaining,
            relay->editor_queue.bytes, relay->editor_queue.length);
        if (!error) relay->editor_queue = *remaining;
        free(remaining);
        if (error) return error;
        relay->command_queue.length = 0;
        relay->command = NULL;
    }
    return 0;
}

static void *relay_input(void *cookie) {
    pane_input_relay *relay = cookie;
    pthread_mutex_lock(&relay->mutex);
    while (!relay->stop && !relay->error) {
        if (relay->request) {
            relay->request_error = change_input(relay);
            relay->request = 0;
            relay->request_done = 1;
            pthread_cond_broadcast(&relay->changed);
            if (relay->request_error) { relay->error = relay->request_error; break; }
        }
        if (relay->command && (relay->command_eof || relay->input_eof) &&
            !relay->command_queue.length)
            close_input_writer(&relay->command->writer);
        if (relay->input_eof && !relay->editor_queue.length)
            close_input_writer(&relay->editor_writer);
        // Backpressure bounds queued input. Each pipe also has its kernel
        // buffer; transition queues have room to drain that existing typeahead.
        int can_read = !relay->input_eof && relay->editor_queue.length < 61440 &&
            relay->command_queue.length < 61440;
        struct pollfd fds[4] = {
            {.fd = can_read ? relay->socket : -1, .events = POLLIN},
            {.fd = relay->wake[0], .events = POLLIN},
            {.fd = !relay->command && relay->editor_queue.length ? relay->editor_writer : -1, .events = POLLOUT},
            {.fd = relay->command && relay->command_queue.length ? relay->command->writer : -1,
             .events = POLLOUT}
        };
        pthread_mutex_unlock(&relay->mutex);
        int result = poll(fds, 4, -1);
        int poll_error = errno;
        pthread_mutex_lock(&relay->mutex);
        if (result < 0) {
            if (poll_error == EINTR) continue;
            relay->error = poll_error;
            break;
        }
        if (fds[1].revents) {
            unsigned char wake;
            (void)read(relay->wake[0], &wake, 1);
            continue; // Apply the requested boundary before consuming more input.
        }
        if (fds[2].revents && relay->editor_queue.length)
            relay->error = flush_input(relay->editor_writer, &relay->editor_queue);
        if (!relay->error && fds[3].revents && relay->command_queue.length)
            relay->error = flush_input(relay->command->writer, &relay->command_queue);
        if (!relay->error && fds[0].revents) {
            unsigned char bytes[4096];
            ssize_t length = read(relay->socket, bytes, sizeof(bytes));
            if (length < 0) {
                if (errno != EINTR && errno != EAGAIN) relay->error = errno;
            } else if (!length) {
                relay->input_eof = 1;
            } else {
                relay->error = route_input(relay, bytes, (size_t)length);
            }
        }
    }
    close_input_writer(&relay->editor_writer);
    if (relay->command) close_input_writer(&relay->command->writer);
    relay->running = 0;
    pthread_cond_broadcast(&relay->changed);
    pthread_mutex_unlock(&relay->mutex);
    return NULL;
}

static int request_input(pane_input_relay *relay, int request, command_input *command) {
    pthread_mutex_lock(&relay->mutex);
    int error = relay->running ? 0 : relay->error ? relay->error : EPIPE;
    if (!error) {
        relay->request = request;
        relay->requested_command = command;
        relay->request_done = 0;
        unsigned char wake = 1;
        ssize_t count;
        do { count = write(relay->wake[1], &wake, 1); } while (count < 0 && errno == EINTR);
        if (count != 1) error = errno ? errno : EIO;
        while (!error && !relay->request_done && relay->running)
            pthread_cond_wait(&relay->changed, &relay->mutex);
        if (!error) error = relay->request_done ? relay->request_error : relay->error ? relay->error : EPIPE;
    }
    pthread_mutex_unlock(&relay->mutex);
    return error;
}

static int stop_input_relay(pane_job *job) {
    pane_input_relay *relay = job->input_relay;
    if (!relay) return 0;
    pthread_mutex_lock(&relay->mutex);
    relay->stop = 1;
    unsigned char wake = 1;
    (void)write(relay->wake[1], &wake, 1);
    pthread_mutex_unlock(&relay->mutex);
    pthread_join(relay->thread, NULL);
    int error = relay->error;
    // pthread_cancel can bypass Dash's shell-exception handler. The outer
    // runner has already waited for the root tree; retire any abandoned lease
    // only after every registered stdin borrower has completed cleanup.
    if (relay->command) {
        command_input *command = relay->command;
        ashell_wait_owned_streams(command->registration);
        ios_setStreams(job->streams[0], job->streams[1], job->streams[2]);
        ios_settty(job->streams[0]);
        ashell_unregister_owned_streams(&command->registration);
        if (fclose(command->reader) && !error) error = errno;
        free(command);
        relay->command = NULL;
    }
    close(relay->socket);
    close(relay->editor_reader);
    close(relay->wake[0]);
    close(relay->wake[1]);
    close(relay->editor_events);
    pthread_cond_destroy(&relay->changed);
    pthread_mutex_destroy(&relay->mutex);
    free(relay);
    job->input_relay = NULL;
    return error;
}

static int prepare_input_relay(pane_job *job) {
    int input[2], wake[2];
    if (pipe(input)) return errno;
    if (pipe(wake)) { int error = errno; close(input[0]); close(input[1]); return error; }
    FILE *reader = fdopen(input[0], "r");
    if (!reader) { int error = errno; close(input[0]); close(input[1]); close(wake[0]); close(wake[1]); return error; }
    pane_input_relay *relay = calloc(1, sizeof(*relay));
    if (!relay) { fclose(reader); close(input[1]); close(wake[0]); close(wake[1]); return ENOMEM; }
    relay->socket = dup(fileno(job->streams[0]));
    relay->editor_reader = dup(input[0]);
    relay->editor_writer = input[1];
    relay->wake[0] = wake[0]; relay->wake[1] = wake[1];
    relay->editor_events = kqueue();
    relay->interactive = dlsym(RTLD_DEFAULT, "storeInteractive");
    int error = relay->socket < 0 || relay->editor_reader < 0 || relay->editor_events < 0 ? errno : 0;
    if (!error && setvbuf(reader, NULL, _IONBF, 0)) error = EIO;
    int descriptors[] = {relay->socket, input[0], input[1], relay->editor_reader, wake[0], wake[1], relay->editor_events};
    for (unsigned i = 0; !error && i < sizeof(descriptors) / sizeof(descriptors[0]); i++)
        if (fcntl(descriptors[i], F_SETFD, FD_CLOEXEC)) error = errno;
    if (!error && (fcntl(input[1], F_SETFL, O_NONBLOCK) ||
        fcntl(input[1], F_SETNOSIGPIPE, 1))) error = errno;
    if (!error) {
        struct kevent events[2];
        EV_SET(&events[0], input[0], EVFILT_READ, EV_ADD, 0, 0, NULL);
        EV_SET(&events[1], 1, EVFILT_USER, EV_ADD | EV_CLEAR, 0, 0, NULL);
        if (kevent(relay->editor_events, events, 2, NULL, 0, NULL)) error = errno;
    }
    int mutex_ready = 0, condition_ready = 0;
    if (!error) { error = pthread_mutex_init(&relay->mutex, NULL); mutex_ready = !error; }
    if (!error) { error = pthread_cond_init(&relay->changed, NULL); condition_ready = !error; }
    if (!error) {
        relay->running = 1;
        error = pthread_create(&relay->thread, NULL, relay_input, relay);
    }
    if (error) {
        if (condition_ready) pthread_cond_destroy(&relay->changed);
        if (mutex_ready) pthread_mutex_destroy(&relay->mutex);
        if (relay->socket >= 0) close(relay->socket);
        if (relay->editor_reader >= 0) close(relay->editor_reader);
        if (relay->editor_events >= 0) close(relay->editor_events);
        fclose(reader); close(input[1]); close(wake[0]); close(wake[1]); free(relay);
        return error;
    }
    fclose(job->streams[0]);
    job->streams[0] = reader;
    job->input_relay = relay;
    return 0;
}

// Wait on the editor's real input and resize event without changing process
// signal handlers or inserting synthetic keys into the command stream.
// Return 0 for an unrelated reader, 1 for input, 2 for resize, or -errno.
__attribute__((used)) int ashell_pane_wait_editor_input(FILE *input) {
    pane_job *job = atomic_load(&foreground_pane);
    if (!job || !job->input_relay || input != job->streams[0]) return 0;
    struct kevent event;
    int count;
    do {
        count = kevent(job->input_relay->editor_events, NULL, 0, &event, 1, NULL);
    } while (count < 0 && errno == EINTR);
    if (count < 0) return -errno;
    if (event.flags & EV_ERROR) return -(int)event.data;
    return event.filter == EVFILT_USER ? 2 : 1;
}

__attribute__((used)) int ashell_pane_begin_foreground_input(FILE **input, void **token) {
    if (!input || !token || *token) return EINVAL;
    pane_job *job = atomic_load(&foreground_pane);
    if (!job || !job->input_relay || *input != job->streams[0]) return 0;
    // Neither a condition wait nor cancellation during allocation may strand
    // the relay mutex or an unregistered pipe. The relay owns the lease before
    // cancellation is restored, so outer cleanup can recover it.
    int cancellation;
    int error = pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cancellation);
    if (error) return error;
    int descriptors[2];
    if (pipe(descriptors)) {
        error = errno;
        pthread_setcancelstate(cancellation, NULL);
        return error;
    }
    command_input *command = calloc(1, sizeof(*command));
    if (!command) {
        close(descriptors[0]); close(descriptors[1]);
        pthread_setcancelstate(cancellation, NULL);
        return ENOMEM;
    }
    command->writer = descriptors[1];
    command->reader = fdopen(descriptors[0], "r");
    command->job = job;
    command->relay = job->input_relay;
    error = command->reader ? 0 : errno;
    if (!error && (fcntl(descriptors[0], F_SETFD, FD_CLOEXEC) ||
        fcntl(descriptors[1], F_SETFD, FD_CLOEXEC) ||
        fcntl(descriptors[1], F_SETFL, O_NONBLOCK) ||
        fcntl(descriptors[1], F_SETNOSIGPIPE, 1))) error = errno;
    if (!error && setvbuf(command->reader, NULL, _IONBF, 0)) error = EIO;
    if (!error) error = ashell_register_command_input(command->reader, &command->registration);
    if (!error) error = request_input(command->relay, INPUT_BEGIN, command);
    if (error) {
        pthread_mutex_lock(&command->relay->mutex);
        if (!command->relay->running && command->relay->command == command)
            command->relay->command = NULL;
        pthread_mutex_unlock(&command->relay->mutex);
        ashell_unregister_owned_streams(&command->registration);
        if (command->reader) fclose(command->reader); else close(descriptors[0]);
        close(command->writer); free(command);
        pthread_setcancelstate(cancellation, NULL);
        return error;
    }
    *input = command->reader;
    *token = command;
    // Stock tty detection compares command streams against the session streams.
    // Keep baseline outputs so explicit redirects remain non-terminal streams.
    ios_setStreams(command->reader, job->streams[1], job->streams[2]);
    // Stock ios_opentty borrowers must receive this command's input as well.
    ios_settty(command->reader);
    pthread_setcancelstate(cancellation, NULL);
    return 0;
}

__attribute__((used)) int ashell_pane_end_foreground_input(void *token) {
    command_input *command = token;
    if (!command) return EINVAL;
    int cancellation;
    int error = pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cancellation);
    if (error) return error;
    error = request_input(command->relay, INPUT_END, command);
    // Closing this command's writer unblocks cooked readers without touching
    // Dash. Borrow counts include asynchronous children through their cleanup.
    ashell_wait_owned_streams(command->registration);
    pane_job *job = command->job;
    ios_setStreams(job->streams[0], job->streams[1], job->streams[2]);
    ios_settty(job->streams[0]);
    int retired = request_input(command->relay, INPUT_RETIRE, command);
    if (!error) error = retired;
    pthread_mutex_lock(&command->relay->mutex);
    if (!command->relay->running && command->relay->command == command)
        command->relay->command = NULL;
    pthread_mutex_unlock(&command->relay->mutex);
    ashell_unregister_owned_streams(&command->registration);
    if (fclose(command->reader) && !error) error = errno;
    free(command);
    pthread_setcancelstate(cancellation, NULL);
    return error;
}

static void drop_reference(pane_job *job) {
    pthread_mutex_lock(&job->mutex);
    int destroy = --job->refs == 0;
    pthread_mutex_unlock(&job->mutex);
    if (!destroy) return;
    if (job->peer_control >= 0) close(job->peer_control);
    if (job->env) {
        for (size_t i = 0; job->env[i]; i++) free(job->env[i]);
        free(job->env);
    }
    free(job->command);
    free(job->cwd);
    free(job->previous_cwd);
    pthread_cond_destroy(&job->ready);
    pthread_mutex_destroy(&job->mutex);
    free(job);
}

static int close_streams(pane_job *job) {
    int error = stop_input_relay(job);
    ashell_unregister_owned_streams(&job->registration);
    for (int i = 0; i < 3; i++) {
        if (job->streams[i] && fclose(job->streams[i]) && !error) error = errno;
        job->streams[i] = NULL;
    }
    return error;
}

static int socket_options(int fd) {
    int one = 1;
    if (setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one))) return errno;
    if (fcntl(fd, F_SETFD, FD_CLOEXEC)) return errno;
    return 0;
}

static void *run_pane(void *cookie) {
    pane_job *job = cookie;
    @autoreleasepool {
        NSLog(@"Shell pane lifecycle: start key=%s cols=%u rows=%u", job->key, job->cols, job->rows);
        // This runner is new: no parent session or TLS streams are switched or overwritten.
        ios_switchSession(job->key);
        ios_setContext(job->key);
        ios_setStreams(job->streams[0], job->streams[1], job->streams[2]);
        ios_settty(job->streams[0]);
        thread_stdin = job->streams[0];
        thread_stdout = job->streams[1];
        thread_stderr = job->streams[2];
        thread_context = job->key;
        ios_setDirectoryURL([NSURL fileURLWithPath:@(job->cwd) isDirectory:YES]);
        // The stock setter has no error return; confirm its actual process directory.
        char observed[PATH_MAX];
        int error = 0;
        struct stat wanted, actual;
        if (!getcwd(observed, sizeof(observed))) error = errno;
        else if (stat(job->cwd, &wanted) || stat(observed, &actual)) error = errno;
        else if (wanted.st_dev != actual.st_dev || wanted.st_ino != actual.st_ino) error = EACCES;
        if (!error) {
            ios_setWindowSize((int)job->cols, (int)job->rows, job->key);
            pid_t pid = ios_fork();
            // ios_fork allocates a private environment and holds stock pid_mtx until
            // command registration. Do not abort between allocation and ios_system.
            for (size_t i = 0; job->env && job->env[i]; i++) {
                char *equals = strchr(job->env[i], '=');
                *equals = 0;
                if (ios_setenv_pid(job->env[i], equals + 1, 1, pid)) error = EINVAL;
                *equals = '=';
            }
            pthread_mutex_lock(&job->mutex);
            job->initialized = 1;
            pthread_cond_signal(&job->ready);
            pthread_mutex_unlock(&job->mutex);
            NSLog(@"Shell pane lifecycle: ready key=%s pid=%d pty=%d", job->key, pid, job->is_pty);
            atomic_store(&foreground_pane, job);
            ios_system(job->command);
            // ios_system may return before detached children finish when the app sets
            // joinMainThread=false. Stock wait understands allocated-but-not-started IDs.
            ios_waitpid(pid);
            ashell_wait_owned_streams(job->registration);
            atomic_store(&foreground_pane, NULL);
            job->status = ios_getCommandStatus();
            ios_releaseThreadId(pid);
        }
        pthread_mutex_lock(&job->mutex);
        int stream_error = close_streams(job);
        if (!error) error = stream_error;
        // Restore the extension process cwd before publishing completion.
        ios_setDirectoryURL([NSURL fileURLWithPath:@(job->previous_cwd) isDirectory:YES]);
        struct stat before, restored;
        if (!getcwd(observed, sizeof(observed))) {
            if (!error) error = errno;
        } else if (stat(job->previous_cwd, &before) || stat(observed, &restored)) {
            if (!error) error = errno;
        } else if (before.st_dev != restored.st_dev || before.st_ino != restored.st_ino) {
            if (!error) error = EIO;
        }
        // Stock ios_closeSession removes its dictionary entry, but does not free stock
        // session allocations. Do not invent a private layout/free across the framework ABI.
        ios_closeSession(job->key);
        job->startup_error = job->initialized ? 0 : error;
        job->completion_error = error;
        job->initialized = 1;
        job->done = 1;
        NSLog(@"Shell pane lifecycle: exit key=%s status=%d error=%d", job->key, job->status, error);
        // Close the retained peer before announcing exit so output EOF is observable.
        if (job->peer_control >= 0) close(job->peer_control);
        job->peer_control = -1;
        atomic_store(&pane_in_flight, 0);
        pthread_cond_signal(&job->ready);
        pthread_mutex_unlock(&job->mutex);
    }
    drop_reference(job);
    return NULL;
}

int ashell_pane_spawn(const char *command, const char *cwd, unsigned cols,
                     unsigned rows, const char *const *envp, int *fd_out, void **job_out) {
    if (fd_out) *fd_out = -1;
    if (job_out) *job_out = NULL;
    if (!fd_out || !job_out || !command || !*command || !cwd || cwd[0] != '/' ||
        !cols || cols > 9999 || !rows || rows > 9999) return EINVAL;
    @autoreleasepool {
        if (![@(command) length] || ![@(cwd) length]) return EILSEQ;
        if (strlen(cwd) >= PATH_MAX) return ENAMETOOLONG;
        struct stat directory;
        if (stat(cwd, &directory)) return errno;
        if (!S_ISDIR(directory.st_mode)) return ENOTDIR;
        if (access(cwd, R_OK | X_OK)) return errno;
        size_t env_count = 0;
        if (envp) for (; envp[env_count]; env_count++) {
            const char *equals = strchr(envp[env_count], '=');
            if (!equals || equals == envp[env_count]) return EINVAL;
            if (![@(envp[env_count]) length]) return EILSEQ;
        }
        int expected = 0;
        if (!atomic_compare_exchange_strong(&pane_in_flight, &expected, 1)) return EBUSY;
        int error = ENOMEM, peer = -1;
        pane_job *job = calloc(1, sizeof(*job));
        if (!job) { atomic_store(&pane_in_flight, 0); return ENOMEM; }
        job->peer_control = -1;
        error = pthread_mutex_init(&job->mutex, NULL);
        if (error) { free(job); atomic_store(&pane_in_flight, 0); return error; }
        error = pthread_cond_init(&job->ready, NULL);
        if (error) {
            pthread_mutex_destroy(&job->mutex);
            free(job);
            atomic_store(&pane_in_flight, 0);
            return error;
        }
        job->refs = 1;
        job->cols = cols;
        job->rows = rows;
        snprintf(job->key, sizeof(job->key), "shell-pane-%s", NSUUID.UUID.UUIDString.UTF8String);
        job->command = strdup(command);
        job->cwd = strdup(cwd);
        job->previous_cwd = getcwd(NULL, 0);
        job->env = calloc(env_count + 1, sizeof(char *));
        error = ENOMEM;
        if (!job->command || !job->cwd || !job->env) goto failed;
        if (!job->previous_cwd) { error = errno; goto failed; }
        for (size_t i = 0; i < env_count; i++) {
            job->env[i] = strdup(envp[i]);
            if (!job->env[i]) goto failed;
        }
        int fds[2];
        int wants_pty = 0;
        for (size_t i = 0; i < env_count; i++)
            if (!strcmp(envp[i], "ASHELL_IOS_PTY=1")) wants_pty = 1;
        if (wants_pty) {
            struct winsize size = {.ws_col = (unsigned short)cols, .ws_row = (unsigned short)rows};
            if (openpty(&fds[0], &fds[1], NULL, NULL, &size)) {
                error = errno;
                NSLog(@"Shell pane: openpty failed errno=%d (%s)", error, strerror(error));
                if (error != EPERM) goto failed;
                // Sandboxed devices may deny PTYs. Keep the existing socket transport
                // explicit and let Dash print its non-TTY prompt; never claim PTY semantics.
                wants_pty = 0;
                for (size_t i = 0; i < env_count; i++)
                    if (!strcmp(job->env[i], "ASHELL_IOS_PTY=1"))
                        memcpy(job->env[i], "ASHELL_IOS_PTY=0", sizeof("ASHELL_IOS_PTY=0"));
                NSLog(@"Shell pane: using socket transport; kernel PTY signals and ioctls unavailable");
            } else job->is_pty = 1;
        }
        if (!wants_pty && socketpair(AF_UNIX, SOCK_STREAM, 0, fds)) { error = errno; goto failed; }
        peer = fds[0];
        int child = fds[1];
        if (job->is_pty) {
            struct termios settings;
            if (tcgetattr(child, &settings)) { error = errno; close(child); goto failed; }
            if (settings.c_cc[VEOF] == _POSIX_VDISABLE) { error = ENOTSUP; close(child); goto failed; }
            job->eof_key = settings.c_cc[VEOF];
            // Commands share an application process: never enable kernel process-group signals.
            settings.c_lflag &= ~ISIG;
            settings.c_iflag |= ICRNL;
            settings.c_oflag |= OPOST | ONLCR;
            error = tcsetattr(child, TCSANOW, &settings) ? errno : 0;
        } else {
            error = socket_options(peer);
            if (!error) error = socket_options(child);
        }
        if (error) { close(child); goto failed; }
        job->peer_control = dup(peer);
        if (job->peer_control < 0) { error = errno; close(child); goto failed; }
        error = job->is_pty ? (fcntl(job->peer_control, F_SETFD, FD_CLOEXEC) ? errno : 0) : socket_options(job->peer_control);
        if (!error && job->is_pty && fcntl(peer, F_SETFD, FD_CLOEXEC)) error = errno;
        if (error) { close(child); goto failed; }
        for (int i = 0; i < 3; i++) {
            int fd = i == 0 ? child : dup(child);
            if (fd < 0) { error = errno; goto failed; }
            job->streams[i] = fdopen(fd, i == 0 ? "r" : "w");
            if (!job->streams[i]) { error = errno; close(fd); goto failed; }
            if (fcntl(fd, F_SETFD, FD_CLOEXEC)) { error = errno; goto failed; }
            /* Match terminal stdout: libedit flushes each completed redraw. */
            int buffering = !job->is_pty && i == 1 ? _IOLBF : _IONBF;
            if (setvbuf(job->streams[i], NULL, buffering, 0)) { error = EIO; goto failed; }
        }
        if (!job->is_pty) error = prepare_input_relay(job);
        if (!error) error = ashell_register_owned_streams(job->streams[0], job->streams[1], job->streams[2], &job->registration);
        if (error) goto failed;
        pthread_attr_t attributes;
        error = pthread_attr_init(&attributes);
        if (error) goto failed;
        error = pthread_attr_setdetachstate(&attributes, PTHREAD_CREATE_DETACHED);
        pthread_t thread;
        job->refs = 2;
        if (!error) error = pthread_create(&thread, &attributes, run_pane, job);
        pthread_attr_destroy(&attributes);
        if (error) { job->refs = 1; goto failed; }
        pthread_mutex_lock(&job->mutex);
        while (!job->initialized) pthread_cond_wait(&job->ready, &job->mutex);
        error = job->startup_error;
        pthread_mutex_unlock(&job->mutex);
        if (error) { close(peer); drop_reference(job); return error; }
        *fd_out = peer;
        *job_out = job;
        return 0;
failed:
        close_streams(job);
        if (peer >= 0) close(peer);
        drop_reference(job);
        atomic_store(&pane_in_flight, 0);
        return error;
    }
}

int ashell_pane_poll(void *handle, int *status_out) {
    if (!handle || !status_out) return -EINVAL;
    pane_job *job = handle;
    pthread_mutex_lock(&job->mutex);
    int result = job->completion_error ? -job->completion_error : job->done;
    if (job->done) *status_out = job->status;
    pthread_mutex_unlock(&job->mutex);
    return result;
}

int ashell_pane_resize(void *handle, unsigned cols, unsigned rows) {
    if (!handle || !cols || cols > 9999 || !rows || rows > 9999) return EINVAL;
    pane_job *job = handle;
    pthread_mutex_lock(&job->mutex);
    int error = job->done ? ESRCH : 0;
    NSLog(@"Shell pane lifecycle: resize key=%s cols=%u rows=%u error=%d", job->key, cols, rows, error);
    if (!error && job->is_pty) {
        struct winsize size = {.ws_col = (unsigned short)cols, .ws_row = (unsigned short)rows};
        if (ioctl(job->peer_control, TIOCSWINSZ, &size)) error = errno;
    }
    if (!error) {
        job->cols = cols;
        job->rows = rows;
        ios_setWindowSize((int)cols, (int)rows, job->key);
        if (job->input_relay) {
            struct kevent event;
            EV_SET(&event, 1, EVFILT_USER, 0, NOTE_TRIGGER, 0, NULL);
            if (kevent(job->input_relay->editor_events, &event, 1, NULL, 0, NULL)) error = errno;
        }
    }
    pthread_mutex_unlock(&job->mutex);
    return error;
}

int ashell_pane_close_stdin(void *handle) {
    if (!handle) return EINVAL;
    pane_job *job = handle;
    pthread_mutex_lock(&job->mutex);
    int error = 0;
    if (!job->done && !job->input_closed) {
        if (job->is_pty) {
            // PTYs have no half-close. Request EOF through the terminal's configured key;
            // canonical readers and libedit handle it, arbitrary raw readers may not.
            // libedit temporarily disables VEOF in raw mode; retain the initial key
            // that its line editor binds, rather than injecting _POSIX_VDISABLE.
            unsigned char eof[2] = {job->eof_key, job->eof_key};
            size_t sent = 0;
            while (sent < sizeof(eof)) {
                ssize_t n = write(job->peer_control, eof + sent, sizeof(eof) - sent);
                if (n < 0 && errno == EINTR) continue;
                if (n <= 0) { error = n < 0 ? errno : EIO; break; }
                sent += (size_t)n;
            }
        } else if (shutdown(job->peer_control, SHUT_WR)) error = errno;
        if (!error) job->input_closed = 1;
    }
    pthread_mutex_unlock(&job->mutex);
    return error;
}

int ashell_pane_interrupt(void *handle) {
    if (!handle) return EINVAL;
    pane_job *job = handle;
    pthread_mutex_lock(&job->mutex);
    int error = job->done ? ESRCH : 0;
    pthread_t foreground = 0;
    struct termios settings;
    if (!error && job->is_pty) {
        if (tcgetattr(job->peer_control, &settings)) error = errno;
        // Raw readers (libedit, Codex, Helix) own their Ctrl-C binding.
        else if (!(settings.c_lflag & ICANON)) error = ENOTSUP;
    }
    if (!error) {
        ios_switchSession(job->key);
        const char *name = ios_progname();
        if (!name || !strcmp(name, "dash") || !strcmp(name, "sh")) error = ENOTSUP;
        else {
            int pid = atomic_load(&foreground_command_pid);
            foreground = pid > 0 ? ios_getThreadId(pid) : NULL;
            if (!foreground || foreground == (pthread_t)-1) error = ESRCH;
        }
    }
    pthread_mutex_unlock(&job->mutex);
    if (error) return error;
    // Never cancel a shell waiter: cancellation of pthread_cond_wait can leave
    // the stock completion mutex locked. Raw TUIs already use the ETX path.
    return pthread_equal(foreground, pthread_self()) ? ESRCH : pthread_cancel(foreground);
}

int ashell_pane_cancel(void *handle) {
    if (!handle) return EINVAL;
    pane_job *job = handle;
    pthread_mutex_lock(&job->mutex);
    int error = job->done ? ESRCH : ENOTSUP;
    pthread_mutex_unlock(&job->mutex);
    return error;
}

void ashell_pane_release(void *handle) {
    if (!handle) return;
    ashell_pane_close_stdin(handle);
    pane_job *job = handle;
    pthread_mutex_lock(&job->mutex);
    NSLog(@"Shell pane lifecycle: release key=%s done=%d", job->key, job->done);
    // Do not keep a hidden reader alive after the consumer closes its own fd:
    // abandoned output must reach EPIPE, rather than filling an unread socket forever.
    if (job->peer_control >= 0) close(job->peer_control);
    job->peer_control = -1;
    pthread_mutex_unlock(&job->mutex);
    drop_reference(handle);
}
