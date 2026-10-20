// Transfer command-local streams to Rust without changing process descriptors.
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include "ios_system.h"

extern int rg_embedded_run(int, const char *const *, int, int, int, int, int);

int rg_dup_stream(int fd) {
    int copy = dup(fd);
    if (copy >= 0 && fcntl(copy, F_SETNOSIGPIPE, 1) < 0) {
        int saved = errno;
        close(copy);
        errno = saved;
        return -1;
    }
    return copy;
}

int rg_ios_main(int argc, char **argv) {
    if (!thread_stdin || !thread_stdout || !thread_stderr) return 2;
    int input = fileno(thread_stdin);
    int output = fileno(thread_stdout);
    // ios_isatty recognizes virtual terminals only on the command's original streams.
    int input_is_terminal = ios_isatty(input);
    int output_is_terminal = ios_isatty(output);
    return rg_embedded_run(argc, (const char *const *)argv,
                           input, output, fileno(thread_stderr),
                           input_is_terminal, output_is_terminal);
}
