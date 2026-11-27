// Keep Neovim's exit paths and stdio within its native command invocation.
#include <errno.h>
#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>

extern int nvim_main(int argc, char **argv);
extern int ios_isatty(int);
extern void ios_startInteractive(void);
extern char *ios_getenv(const char *);

static jmp_buf exit_target;
static int exit_status;
static FILE **command_streams;
static char *runtime_path;

pid_t nvim_port_fork(void) { errno = ENOSYS; return -1; }
FILE *nvim_port_stream(int index) { return command_streams[index]; }
char *nvim_port_runtime(void) { return runtime_path; }
int nvim_port_isatty(int index) { return ios_isatty(index); }
void nvim_port_start_terminal(void) { ios_startInteractive(); }
int nvim_port_dimensions(int *width, int *height) {
    const char *columns = ios_getenv("COLUMNS");
    const char *lines = ios_getenv("LINES");
    if (columns == NULL || lines == NULL) return 0;
    *width = atoi(columns);
    *height = atoi(lines);
    return *width > 0 && *height > 0;
}

_Noreturn void nvim_port_exit(int status) {
    exit_status = status;
    longjmp(exit_target, 1);
}

__attribute__((visibility("default")))
int nvim_port_run(int argc, char **argv, FILE **streams, char *runtime) {
    command_streams = streams;
    runtime_path = runtime;
    return setjmp(exit_target) ? exit_status : nvim_main(argc, argv);
}
