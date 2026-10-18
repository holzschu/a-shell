// Transfer duplicated thread streams; never redirect process descriptors.
#include <stdio.h>
#include <unistd.h>
#include "ios_system.h"
extern int gitoxide_embedded_run(int, const char *const *, int, int, int);
int gix_ios_main(int argc, char **argv) {
    int input = dup(fileno(thread_stdin));
    int out = dup(fileno(thread_stdout));
    int err = dup(fileno(thread_stderr));
    if (input < 0 || out < 0 || err < 0) {
        if (input >= 0) close(input);
        if (out >= 0) close(out);
        if (err >= 0) close(err);
        fprintf(thread_stderr, "Cannot duplicate gitoxide command streams\n");
        return 1;
    }
    return gitoxide_embedded_run(argc, (const char *const *)argv, input, out, err);
}
