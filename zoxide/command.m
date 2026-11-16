// Borrow only the invoking command's streams and environment.
#include <errno.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include "ios_system.h"

extern int zoxide_embedded_run(int, const char *const *, int);
static pthread_mutex_t command_lock = PTHREAD_MUTEX_INITIALIZER;

size_t zoxide_host_write(int errors, const unsigned char *bytes, size_t length) {
    return fwrite(bytes, 1, length, errors ? ios_stderr() : ios_stdout());
}

int zoxide_host_flush(int errors) {
    return fflush(errors ? ios_stderr() : ios_stdout());
}

// cd_main reports failures on stderr but can still return zero.
static int stock_cd(int argc, char **argv, int *succeeded) {
    FILE *input = ios_stdin(), *output = ios_stdout(), *errors = ios_stderr();
    FILE *capture = tmpfile();
    *succeeded = 0;
    if (!capture) return cd_main(argc, argv);
    ios_setStreams(input, output, capture);
    int status = cd_main(argc, argv);
    ios_setStreams(input, output, errors);
    if (fflush(capture) == 0 && fseek(capture, 0, SEEK_END) == 0) {
        long length = ftell(capture);
        *succeeded = status == 0 && length == 0;
        rewind(capture);
        char buffer[1024];
        size_t count;
        while ((count = fread(buffer, 1, sizeof(buffer), capture)) > 0) {
            if (errors) fwrite(buffer, 1, count, errors);
        }
    }
    fclose(capture);
    return status;
}

int zoxide_host_cd(const char *path) {
    if (strcmp(path, "-") == 0) {
        char *arguments[] = {"cd", "-", NULL};
        int succeeded;
        int status = stock_cd(2, arguments, &succeeded);
        if (status == 0 && succeeded) return 0;
        errno = EIO;
        return -1;
    }
    struct stat target, current;
    if (stat(path, &target) < 0) return -1;
    if (!S_ISDIR(target.st_mode)) {
        errno = ENOTDIR;
        return -1;
    }
    char *arguments[] = {"cd", (char *)path, NULL};
    if (cd_main(2, arguments) != 0) {
        errno = EIO;
        return -1;
    }
    // cd_main returns zero even when __cd_to_dir fails. Verify the destination.
    if (stat(".", &current) < 0) return -1;
    if (current.st_dev != target.st_dev || current.st_ino != target.st_ino) {
        errno = EACCES;
        return -1;
    }
    return 0;
}

static int run(int argc, char **argv, int jump) {
    if (!ios_stdout() || !ios_stderr()) return 1;
    if (argc < 1 || !argv) return 2;
    // Rust unwinding must not meet pthread cancellation. Defer it until Rust
    // has returned and the database/command lock have been released.
    int cancellation;
    pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cancellation);
    if (pthread_mutex_trylock(&command_lock) != 0) {
        fputs("zoxide: another invocation is running\n", ios_stderr());
        pthread_setcancelstate(cancellation, NULL);
        return 1;
    }
    int status = zoxide_embedded_run(argc, (const char *const *)argv, jump);
    pthread_mutex_unlock(&command_lock);
    pthread_setcancelstate(cancellation, NULL);
    return status;
}

int zoxide_ios_main(int argc, char **argv) { return run(argc, argv, 0); }
int zoxide_z_main(int argc, char **argv) { return run(argc, argv, 1); }
