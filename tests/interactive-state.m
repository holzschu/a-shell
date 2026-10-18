// Run as an a-Shell command on a worker thread with the real host callbacks.
#include <stdio.h>
extern __thread FILE *thread_stdout;
extern void ios_startInteractive(void);
extern void ios_stopInteractive(void);
extern int ios_storeInteractive(void);

int interactive_state_main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    for (int run = 0; run < 2; run++) {
        ios_stopInteractive();
        int before = ios_storeInteractive();
        ios_startInteractive();
        int active = ios_storeInteractive();
        ios_stopInteractive();
        int after = ios_storeInteractive();
        fprintf(thread_stdout, "%d %d %d\n", before, active, after);
        if (before != 0 || active != 1 || after != 0) return 1;
    }
    return 0;
}
