// All editor threads share only this invocation's owned stream copies.
#pragma once
#ifndef __ASSEMBLER__
#include <stdio.h>
#include <unistd.h>
FILE *nvim_port_stream(int index);
char *nvim_port_runtime(void);
int nvim_port_isatty(int index);
void nvim_port_start_terminal(void);
int nvim_port_dimensions(int *width, int *height);
#undef stdin
#undef stdout
#undef stderr
#undef STDIN_FILENO
#undef STDOUT_FILENO
#undef STDERR_FILENO
#define stdin nvim_port_stream(0)
#define stdout nvim_port_stream(1)
#define stderr nvim_port_stream(2)
#define STDIN_FILENO fileno(stdin)
#define STDOUT_FILENO fileno(stdout)
#define STDERR_FILENO fileno(stderr)
#define printf(...) fprintf(stdout, __VA_ARGS__)
#define vprintf(format, args) vfprintf(stdout, format, args)
#define putchar(character) fputc(character, stdout)
#define getchar() fgetc(stdin)
#define puts(text) (fputs((text), stdout) == EOF ? EOF : fputc('\n', stdout))
#endif
