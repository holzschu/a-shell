#ifndef ASHELL_TMUX_BOUNDARY_H
#define ASHELL_TMUX_BOUNDARY_H
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <wchar.h>
#undef getopt
#undef getopt_long
#undef getopt_long_only
#undef optind
#undef opterr
#undef optopt
#undef optreset
#undef optarg
#include "ios_error.h"

// Each tmux engine runs in a dedicated extension process. Keep its event-loop
// signals local to that process; only its command streams and exit use ios_system.
#undef signal
#undef kill
#undef killpg
#undef iswprint
#undef optional_argument
#undef stdout
#undef stderr
#undef stdin
#define stdout thread_stdout
#define stderr thread_stderr
#define stdin thread_stdin
#undef STDIN_FILENO
#undef STDOUT_FILENO
#undef STDERR_FILENO
#define STDIN_FILENO fileno(thread_stdin)
#define STDOUT_FILENO fileno(thread_stdout)
#define STDERR_FILENO fileno(thread_stderr)
#define isatty ios_isatty
#define printf(...) fprintf(thread_stdout, __VA_ARGS__)
#endif
