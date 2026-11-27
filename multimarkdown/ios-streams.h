#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#define MULTIMARKDOWN_IOS 1
extern __thread FILE *thread_stdin;
extern __thread FILE *thread_stdout;
extern __thread FILE *thread_stderr;
extern void ios_exit(int) __attribute__((noreturn));
#undef stdin
#undef stdout
#undef stderr
#define stdin thread_stdin
#define stdout thread_stdout
#define stderr thread_stderr
#define exit ios_exit
#define abort() ios_exit(1)
#define printf(...) fprintf(thread_stdout, __VA_ARGS__)
static inline void multimarkdown_perror(const char *message) {
	int saved_errno = errno;
	fprintf(thread_stderr, "%s%s%s\n", message ? message : "",
		message && *message ? ": " : "", strerror(saved_errno));
	errno = saved_errno;
}
#define perror multimarkdown_perror
