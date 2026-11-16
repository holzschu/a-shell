// Borrow only the invoking command's streams and environment.
#import <Foundation/Foundation.h>
#include <errno.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include "ios_system.h"

extern int zoxide_embedded_run(int, const char *const *, int);
static pthread_mutex_t command_lock = PTHREAD_MUTEX_INITIALIZER;

// a-Shell decomposes native input (#995); upstream query matching is literal.
// Keep engine text in NFC, including paths learned from Darwin's NFD cwd.
char *zoxide_host_canonical(const char *bytes) {
    @autoreleasepool {
        NSString *text = [NSString stringWithUTF8String:bytes];
        const char *composed = text.precomposedStringWithCanonicalMapping.UTF8String;
        // UTF8String can borrow storage released on return under ARC.
        return strdup(composed ? composed : bytes);
    }
}

int zoxide_host_fzf(const unsigned char *bytes, size_t length, const char *options, char **selection) {
    @autoreleasepool {
        *selection = NULL;
        NSString *template = [NSTemporaryDirectory() stringByAppendingPathComponent:@"zoxide.XXXXXX"];
        char *directory = strdup(template.fileSystemRepresentation);
        if (!directory) return -1;
        if (!mkdtemp(directory)) { free(directory); return -1; }
        NSString *root = [NSString stringWithUTF8String:directory];
        free(directory);
        NSString *input = [root stringByAppendingPathComponent:@"input"];
        NSString *output = [root stringByAppendingPathComponent:@"output"];
        int status = -1;
        FILE *file = fopen(input.fileSystemRepresentation, "wb");
        if (file) {
            int written = fwrite(bytes, 1, length, file) == length;
            if (fclose(file) == 0 && written) {
                NSMutableString *line = [NSMutableString stringWithString:@"fzf '--delimiter=\t' --nth=2 --read0"];
                if (!options) {
                    [line appendString:@" --exact --no-sort --bind=ctrl-z:ignore,btab:up,tab:down --cycle --keep-right --border=sharp --height=45% --info=inline --layout=reverse --tabstop=1 --exit-0"];
                }
                // Only owned file paths enter the command string. User options
                // stay in the child's environment, as in upstream zoxide.
                NSString *quotedInput = [input stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
                NSString *quotedOutput = [output stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
                [line appendFormat:@" < '%@' > '%@'", quotedInput, quotedOutput];
                pid_t child = ios_fork();
                if (child >= 0) {
                    // ios_fork clones the calling command's scoped environment.
                    if (options) ios_setenv("FZF_DEFAULT_OPTS", options, 1);
                    ios_system(line.UTF8String);
                    ios_waitpid(child);
                    status = ios_getCommandStatus();
                    ios_releaseThreadId(child);
                    if (status == 0) {
                        NSData *data = [NSData dataWithContentsOfFile:output];
                        if (data && data.length < SIZE_MAX) {
                            *selection = malloc(data.length + 1);
                            if (*selection) {
                                memcpy(*selection, data.bytes, data.length);
                                (*selection)[data.length] = '\0';
                            } else status = -1;
                        } else status = -1;
                    }
                }
            }
        }
        if (![[NSFileManager defaultManager] removeItemAtPath:root error:NULL]) status = -1;
        return status;
    }
}

void zoxide_host_free(char *selection) { free(selection); }

size_t zoxide_host_write(int errors, const unsigned char *bytes, size_t length) {
    return fwrite(bytes, 1, length, errors ? ios_stderr() : ios_stdout());
}

int zoxide_host_flush(int errors) {
    return fflush(errors ? ios_stderr() : ios_stdout());
}

// cd_main reports failures on stderr but can still return zero.
// ios_setStreams configures the session, not these borrowed command streams.
static int stock_cd(int argc, char **argv, int *succeeded) {
    FILE *errors = thread_stderr;
    FILE *capture = tmpfile();
    *succeeded = 0;
    if (!capture) return cd_main(argc, argv);
    thread_stderr = capture;
    int status = cd_main(argc, argv);
    thread_stderr = errors;
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
int zoxide_zi_main(int argc, char **argv) { return run(argc, argv, 2); }
int zoxide_zi_complete_main(int argc, char **argv) { return run(argc, argv, 3); }

static int change_directory(int argc, char **argv) {
    const char *fallback = ios_getenv("_ZO_CD");
    if (argc > 1 && argv && argv[1] && fallback && strcmp(fallback, "1") == 0 &&
        argv[1][0] != '/' && argv[1][0] != '~' && strcmp(argv[1], "-") != 0) {
        struct stat target;
        // lstat preserves dangling symlinks, existing files and access errors.
        if (lstat(argv[1], &target) < 0 && errno == ENOENT) return run(argc, argv, 1);
    }
    int succeeded;
    int status = stock_cd(argc, argv, &succeeded);
    if (!succeeded) return status;

    // A shell pwd hook is best effort. A database error must not fail cd or
    // change its output, including when a picker has no command streams.
    FILE *input = thread_stdin, *output = thread_stdout, *errors = thread_stderr;
    FILE *sink = tmpfile();
    if (!sink) return status;
    const char *pwd = ios_getenv("PWD");
    char *physical = NULL;
    if (!pwd || pwd[0] != '/') pwd = physical = getcwd(NULL, 0);
    if (pwd) {
        char *arguments[] = {"zoxide", "add", (char *)pwd, NULL};
        thread_stdin = input ? input : sink;
        thread_stdout = thread_stderr = sink;
        run(3, arguments, 0);
        thread_stdin = input;
        thread_stdout = output;
        thread_stderr = errors;
    }
    free(physical);
    fclose(sink);
    return status;
}

int zoxide_cd_main(int argc, char **argv) {
    // Keep owned temporary streams alive until their caller streams are restored.
    int cancellation;
    pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cancellation);
    int status = change_directory(argc, argv);
    pthread_setcancelstate(cancellation, NULL);
    return status;
}
