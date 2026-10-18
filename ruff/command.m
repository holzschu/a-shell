// Only this framework binds these libc names; they are hidden from the app.
// Other panes keep their own fd 0/1/2 and never enter these wrappers.
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/uio.h>
#include <unistd.h>
#include "ios_system.h"

extern int ruff_embedded_run(int argc, const char *const *argv);
static pthread_mutex_t command_lock = PTHREAD_MUTEX_INITIALIZER;
static int streams[3] = {-1, -1, -1};
static pthread_once_t libc_once = PTHREAD_ONCE_INIT;
static ssize_t (*libc_read)(int, void *, size_t);
static ssize_t (*libc_write)(int, const void *, size_t);
static ssize_t (*libc_readv)(int, const struct iovec *, int);
static ssize_t (*libc_writev)(int, const struct iovec *, int);
static int (*libc_isatty)(int);
static int (*libc_fstat)(int, struct stat *);
static int libc_ready;

static void load_libc(void) {
    // An explicit handle avoids RTLD_NEXT depending on framework load order.
    void *handle = dlopen("/usr/lib/libSystem.B.dylib", RTLD_NOW | RTLD_LOCAL);
    if (!handle) return;
    libc_read = dlsym(handle, "read");
    libc_write = dlsym(handle, "write");
    libc_readv = dlsym(handle, "readv");
    libc_writev = dlsym(handle, "writev");
    libc_isatty = dlsym(handle, "isatty");
    libc_fstat = dlsym(handle, "fstat");
    libc_ready = libc_read && libc_write && libc_readv && libc_writev && libc_isatty && libc_fstat;
    // Keep the system-library handle alive for these function pointers.
}

static int stream_fd(int fd) {
    return fd >= 0 && fd < 3 && streams[fd] >= 0 ? streams[fd] : fd;
}

// The linker resolves Rust std's references here, then the export list hides
// these names. This is framework-local binding, not dyld interposition.
ssize_t read(int fd, void *buffer, size_t length) {
    return libc_read(stream_fd(fd), buffer, length);
}
ssize_t write(int fd, const void *buffer, size_t length) {
    return libc_write(stream_fd(fd), buffer, length);
}
ssize_t readv(int fd, const struct iovec *vectors, int count) {
    return libc_readv(stream_fd(fd), vectors, count);
}
ssize_t writev(int fd, const struct iovec *vectors, int count) {
    return libc_writev(stream_fd(fd), vectors, count);
}
int isatty(int fd) {
    return libc_isatty(stream_fd(fd));
}
int fstat(int fd, struct stat *status) {
    return libc_fstat(stream_fd(fd), status);
}

static void release_streams(void *unused) {
    (void)unused;
    for (int index = 0; index < 3; index++) {
        if (streams[index] >= 0) close(streams[index]);
        streams[index] = -1;
    }
    pthread_mutex_unlock(&command_lock);
}

int ruff_ios_main(int argc, char **argv) {
    pthread_once(&libc_once, load_libc);
    if (!libc_ready) {
        fprintf(thread_stderr, "Cannot load Ruff's system I/O functions\n");
        return 2;
    }
    if (pthread_mutex_trylock(&command_lock) != 0) {
        fprintf(thread_stderr, "Ruff is already running in this app\n");
        return 2;
    }
    FILE *owned[] = {thread_stdin, thread_stdout, thread_stderr};
    int status = 2;
    pthread_cleanup_push(release_streams, NULL);
    for (int index = 0; index < 3; index++) {
        if (!owned[index] || (streams[index] = fcntl(fileno(owned[index]), F_DUPFD_CLOEXEC, 3)) < 0) {
            fprintf(thread_stderr, "Cannot duplicate Ruff stream %d (errno %d)\n", index, errno);
            goto cleanup;
        }
    }
    status = ruff_embedded_run(argc, (const char *const *)argv);
cleanup:
    pthread_cleanup_pop(1);
    return status;
}
