// The host fixture substitutes only the external ios_system ABI.
#include <stdio.h>
#include <sys/types.h>
FILE *ios_stdin(void);
FILE *ios_stdout(void);
FILE *ios_stderr(void);
void ios_setStreams(FILE *, FILE *, FILE *);
char *ios_getenv(const char *);
int cd_main(int, char **);
pid_t ios_fork(void);
void ios_waitpid(pid_t);
int ios_getCommandStatus(void);
void ios_releaseThreadId(pid_t);
int ios_setenv(const char *, const char *, int);
int ios_system(const char *);
