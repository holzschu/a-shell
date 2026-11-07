#import <Foundation/Foundation.h>
#import <ios_system/ios_system.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/resource.h>
#include <unistd.h>
#include "../ShellWorkers/NativePane.h"

// Run in a disposable process: resource limits apply to every thread.
int main(void) {
    @autoreleasepool {
        thread_stdin = stdin;
        thread_stdout = stdout;
        thread_stderr = stderr;
        (void)NSUUID.UUID.UUIDString;
        struct rlimit original;
        if (getrlimit(RLIMIT_NOFILE, &original) || original.rlim_cur < 64) return 64;
        for (int budget = 0; budget <= 6; budget++) {
            struct rlimit limited = original;
            limited.rlim_cur = 64;
            if (setrlimit(RLIMIT_NOFILE, &limited)) return 64;
            int fillers[64], count = 0, fd;
            while (count < 64 && (fd = open("/dev/null", O_RDONLY)) >= 0) fillers[count++] = fd;
            if (count < budget) return 64;
            for (int i = 0; i < budget; i++) close(fillers[--count]);
            int before = 0;
            for (int i = 0; i < 64; i++) if (fcntl(i, F_GETFD) >= 0) before++;
            ashell_pane_options options = { .size = sizeof(options), .tty = 0, .separate_stderr = 1 };
            int output = -1;
            void *job = NULL;
            int error = ashell_pane_spawn_ex("true", "/tmp", 80, 24, NULL, &options, &output, &job);
            int after = 0;
            for (int i = 0; i < 64; i++) if (fcntl(i, F_GETFD) >= 0) after++;
            int restored = setrlimit(RLIMIT_NOFILE, &original);
            for (int i = 0; i < count; i++) close(fillers[i]);
            BOOL passed = !restored && error == EMFILE && output == -1 && job == NULL && options.stderr_fd == -1 && before == after;
            printf("descriptor budget=%d error=%d delta=%d: %s\n", budget, error, after - before, passed ? "PASS" : "FAIL");
            if (!passed) return 1;
        }
        return 0;
    }
}
