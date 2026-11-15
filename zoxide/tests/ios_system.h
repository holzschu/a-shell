// The host fixture substitutes only the external ios_system ABI.
#include <stdio.h>
FILE *ios_stdout(void);
FILE *ios_stderr(void);
char *ios_getenv(const char *);
int cd_main(int, char **);
