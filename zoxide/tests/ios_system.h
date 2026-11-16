// The host fixture substitutes only the external ios_system ABI.
#include <stdio.h>
FILE *ios_stdin(void);
FILE *ios_stdout(void);
FILE *ios_stderr(void);
void ios_setStreams(FILE *, FILE *, FILE *);
char *ios_getenv(const char *);
int cd_main(int, char **);
