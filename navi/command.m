// Run navi and registered child commands on ios_system command threads.
#import <Foundation/Foundation.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "ios_system.h"

extern int navi_embedded_run(int, const char *const *);
static __thread char *temporary_directory;

void navi_host_write(int errors, const unsigned char *bytes, size_t length) {
    FILE *stream = errors ? thread_stderr : thread_stdout;
    fwrite(bytes, 1, length, stream);
    fflush(stream);
}

int navi_host_tmpfd(void) {
    if (!temporary_directory) { errno = EINVAL; return -1; }
    char path[PATH_MAX];
    int length = snprintf(path, sizeof(path), "%s/capture.XXXXXX", temporary_directory);
    if (length < 0 || (size_t)length >= sizeof(path)) {
        errno = ENAMETOOLONG;
        return -1;
    }
    return mkstemp(path);
}

int navi_host_input(void) {
    return dup(fileno(thread_stdin));
}

const char *navi_host_getenv(const char *name) {
    return ios_getenv(name);
}

int navi_host_size(unsigned short *columns, unsigned short *rows) {
    int width, height;
    int error = ios_getWindowSize(&width, &height, ios_getContext());
    if (!error) { *columns = width; *rows = height; }
    return error;
}

int navi_host_run(const char *command, int input, int output, int errors) {
    NSMutableString *line = [NSMutableString stringWithUTF8String:command];
    int descriptors[] = {input, output, errors};
    NSString *operators[] = {@"<", @">", @"2>"};
    for (int i = 0; i < 3; i++) {
        if (descriptors[i] < 0) continue;
        char path[PATH_MAX];
        if (fcntl(descriptors[i], F_GETPATH, path) < 0) return -1;
        NSString *quoted = [[NSString stringWithUTF8String:path] stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
        [line appendFormat:@" %@ '%@'", operators[i], quoted];
    }
    // ios_system owns the redirected FILEs; Rust retains independent capture fds.
    // fzf reads keys from the session tty and renders through inherited stderr.
    pid_t child = ios_fork();
    if (child < 0) return -1;
    ios_system(line.UTF8String);
    ios_waitpid(child);
    int status = ios_getCommandStatus();
    ios_releaseThreadId(child);
    return status;
}

int navi_ios_main(int argc, char **argv) {
    @autoreleasepool {
        // fzf handles key cancellation. A foreign unwind cannot cross Rust FFI.
        int cancellation;
        pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cancellation);
        NSString *template = [NSTemporaryDirectory() stringByAppendingPathComponent:@"navi.XXXXXX"];
        temporary_directory = strdup(template.fileSystemRepresentation);
        int status = 1;
        if (temporary_directory && mkdtemp(temporary_directory)) {
            status = navi_embedded_run(argc, (const char *const *)argv);
            NSError *error = nil;
            if (![[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithUTF8String:temporary_directory] error:&error]) {
                fprintf(thread_stderr, "navi: temporary file cleanup: %s\n", error.localizedDescription.UTF8String);
                if (status == 0) status = 1;
            }
        } else {
            fprintf(thread_stderr, "navi: temporary directory: %s\n", strerror(errno));
        }
        free(temporary_directory);
        temporary_directory = NULL;
        pthread_setcancelstate(cancellation, NULL);
        return status;
    }
}
