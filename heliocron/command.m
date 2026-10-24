// ios_system owns the invoking pane's thread-local FILE streams.
#include <stdio.h>
#include "ios_system.h"

extern int heliocron_embedded_run(int, const char *const *, int, int);

int heliocron_ios_main(int argc, char **argv) {
    if (!thread_stdout || !thread_stderr) return 2;
    return heliocron_embedded_run(argc, (const char *const *)argv,
                                  fileno(thread_stdout), fileno(thread_stderr));
}
