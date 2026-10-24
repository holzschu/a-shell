#import <Foundation/Foundation.h>
#import <ios_system/ios_system.h>
#include <dlfcn.h>
#include <poll.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>


// Keep each command alive at its public stdin boundary while the other slots start.
static int capacity_check(void) {
    int (*spawn)(const char *, const char *, unsigned, unsigned, const char *const *, int *, void **) = dlsym(RTLD_DEFAULT, "ashell_pane_spawn");
    int (*pollJob)(void *, int *) = dlsym(RTLD_DEFAULT, "ashell_pane_poll");
    void (*release)(void *) = dlsym(RTLD_DEFAULT, "ashell_pane_release");
    if (!spawn || !pollJob || !release) { fputs("worker pool unavailable: FAIL\n", thread_stdout); return 1; }
    NSString *root = [NSHomeDirectory() stringByAppendingPathComponent:[@"Documents/worker-pool-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    void *jobs[10] = {0};
    int descriptors[10];
    char output[10][2048] = {{0}};
    size_t used[10] = {0};
    int pids[10] = {0};
    BOOL passed = YES;
    for (int i = 0; i < 10; i++) descriptors[i] = -1;
    for (int i = 0; i < 10; i++) {
        NSString *directory = [root stringByAppendingPathComponent:[NSString stringWithFormat:@"slot-%d", i]];
        if (![[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil]) { passed = NO; break; }
        char value[32], command[256];
        snprintf(value, sizeof(value), "POOL_VALUE=slot-%d", i);
        const char *environment[] = {value, NULL};
        snprintf(command, sizeof(command), "dash -c 'printf \"READY=%%s,%%s\\n\" \"$ASHELL_WORKER_PID\" \"$POOL_VALUE\"; pwd; read value; printf \"END=%%s\\n\" \"$value\"; exit %d'", i);
        int error = spawn(command, directory.fileSystemRepresentation, 80, 24, environment, &descriptors[i], &jobs[i]);
        if (error) { fprintf(thread_stdout, "slot=%d startup error=%d: FAIL\n", i, error); passed = NO; break; }
        if (fcntl(descriptors[i], F_SETFL, O_NONBLOCK)) { passed = NO; break; }
    }
    NSTimeInterval deadline = NSProcessInfo.processInfo.systemUptime + 10;
    BOOL allReady = NO;
    while (passed && NSProcessInfo.processInfo.systemUptime < deadline) {
        allReady = YES;
        for (int i = 0; i < 10; i++) {
            ssize_t count = read(descriptors[i], output[i] + used[i], sizeof(output[i]) - used[i] - 1);
            if (count > 0) used[i] += count;
            if (!strchr(output[i], '\n') || !strchr(strchr(output[i], '\n') + 1, '\n')) allReady = NO;
            int status;
            if (pollJob(jobs[i], &status) != 0) { passed = NO; break; }
        }
        if (allReady) break;
        usleep(10000);
    }
    if (!allReady) passed = NO;
    for (int i = 0; passed && i < 10; i++) {
        char value[32];
        if (sscanf(output[i], "READY=%d,%31[^\n]", &pids[i], value) != 2 || pids[i] <= 0) { passed = NO; break; }
        char expectedValue[32];
        snprintf(expectedValue, sizeof(expectedValue), "slot-%d", i);
        NSString *expectedDirectory = [[root stringByAppendingPathComponent:[NSString stringWithFormat:@"slot-%d", i]] stringByAppendingString:@"\n"];
        if (strcmp(value, expectedValue) || strcmp(strchr(output[i], '\n') + 1, expectedDirectory.fileSystemRepresentation)) passed = NO;
        for (int j = 0; j < i; j++) if (pids[i] == pids[j]) passed = NO;
        fprintf(thread_stdout, "slot=%d real_pid=%d cwd/env=%s\n", i, pids[i], passed ? "PASS" : "FAIL");
    }
    if (passed) {
        int descriptor = -1;
        void *job = NULL;
        int error = spawn("dash -c 'exit 0'", root.fileSystemRepresentation, 80, 24, NULL, &descriptor, &job);
        BOOL full = error == ENOSPC && descriptor == -1 && job == NULL;
        fprintf(thread_stdout, "eleventh worker error=%d: %s\n", error, full ? "PASS" : "FAIL");
        if (job) release(job);
        if (descriptor >= 0) close(descriptor);
        passed = full;
    }
    // The same open sessions must still accept input after more than five seconds.
    if (passed) {
        sleep(6);
        for (int i = 0; i < 10; i++) if (write(descriptors[i], "continue\n", 9) != 9) passed = NO;
        for (int i = 0; i < 10; i++) {
            BOOL exited = NO, eof = NO;
            int status = -1;
            deadline = NSProcessInfo.processInfo.systemUptime + 10;
            while (NSProcessInfo.processInfo.systemUptime < deadline && (!exited || !eof)) {
                ssize_t count = read(descriptors[i], output[i] + used[i], sizeof(output[i]) - used[i] - 1);
                if (count > 0) used[i] += count;
                else if (count == 0) eof = YES;
                int result = pollJob(jobs[i], &status);
                if (result == 1) exited = YES;
                else if (result < 0) break;
                if (!exited || !eof) usleep(10000);
            }
            BOOL completed = exited && eof && status == i && strstr(output[i], "END=continue\n");
            fprintf(thread_stdout, "slot=%d delayed input/status=%d: %s\n", i, status, completed ? "PASS" : "FAIL");
            if (!completed) passed = NO;
        }
    }
    for (int i = 0; i < 10; i++) {
        if (jobs[i]) release(jobs[i]);
        if (descriptors[i] >= 0) close(descriptors[i]);
    }
    [[NSFileManager defaultManager] removeItemAtPath:root error:nil];
    fprintf(thread_stdout, "ten-worker capacity: %s\n", passed ? "PASS" : "FAIL");
    return passed ? 0 : 1;
}


static int lifecycle_check(BOOL busy, BOOL closeOnly) {
    int (*spawn)(const char *, const char *, unsigned, unsigned, const char *const *, int *, void **) = dlsym(RTLD_DEFAULT, "ashell_pane_spawn");
    int (*pollJob)(void *, int *) = dlsym(RTLD_DEFAULT, "ashell_pane_poll");
    int (*cancel)(void *) = dlsym(RTLD_DEFAULT, "ashell_pane_cancel");
    void (*release)(void *) = dlsym(RTLD_DEFAULT, "ashell_pane_release");
    if (!spawn || !pollJob || !cancel || !release) { fputs("worker pool unavailable: FAIL\n", thread_stdout); return 1; }
    NSString *directory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    void *jobs[3] = {0};
    int descriptors[3] = {-1, -1, -1}, pids[3] = {0};
    BOOL passed = YES;
    for (int i = 0; i < 3; i++) {
        const char *command = busy && i == 0 ? "dash -c 'printf \"READY=%s\\n\" \"$ASHELL_WORKER_PID\"; while :; do :; done'" : "dash -c 'printf \"READY=%s\\n\" \"$ASHELL_WORKER_PID\"; read value; printf \"DONE=%s\\n\" \"$value\"; exit 7'";
        int error = spawn(command, directory.fileSystemRepresentation, 80, 24, NULL, &descriptors[i], &jobs[i]);
        if (error) { fprintf(thread_stdout, "lifecycle slot=%d startup=%d: FAIL\n", i, error); passed = NO; break; }
        struct pollfd ready = {.fd = descriptors[i], .events = POLLIN};
        char output[128] = {0};
        size_t used = 0;
        NSTimeInterval deadline = NSProcessInfo.processInfo.systemUptime + 5;
        while (!strchr(output, '\n') && used < sizeof(output) - 1 && NSProcessInfo.processInfo.systemUptime < deadline) {
            if (poll(&ready, 1, 100) > 0) {
                ssize_t count = read(descriptors[i], output + used, sizeof(output) - used - 1);
                if (count > 0) used += count;
                else break;
            }
        }
        if (sscanf(output, "READY=%d", &pids[i]) != 1 || pids[i] <= 0 || pids[i] == getpid()) { passed = NO; break; }
        for (int j = 0; j < i; j++) if (pids[i] == pids[j]) passed = NO;
    }
    if (passed) {
        int status = -1;
        BOOL cancelled = YES;
        if (!closeOnly) cancelled = cancel(jobs[0]) == 0 && pollJob(jobs[0], &status) == 1 && status == 137;
        release(jobs[0]); jobs[0] = NULL;
        fprintf(thread_stdout, "%s one worker: %s\n", closeOnly ? "close" : "cancel", cancelled ? "PASS" : "FAIL");
        passed = cancelled;
        close(descriptors[0]); descriptors[0] = -1;
    }
    if (passed) {
        // Inject OS process loss only after that process identified itself through
        // its public output and was proved distinct from the consumer and peers.
        BOOL lost = kill(pids[1], SIGKILL) == 0;
        int status = -1, result = 0;
        NSTimeInterval deadline = NSProcessInfo.processInfo.systemUptime + 5;
        while (lost && NSProcessInfo.processInfo.systemUptime < deadline) {
            result = pollJob(jobs[1], &status);
            if (result) break;
            usleep(10000);
        }
        lost = lost && result == 1 && status == 137;
        fprintf(thread_stdout, "lost worker status=%d: %s\n", status, lost ? "PASS" : "FAIL");
        passed = lost;
        release(jobs[1]); jobs[1] = NULL;
        close(descriptors[1]); descriptors[1] = -1;
    }
    if (passed) {
        int status = -1;
        BOOL alive = pollJob(jobs[2], &status) == 0 && write(descriptors[2], "survivor\n", 9) == 9;
        char output[128] = {0}; size_t used = 0;
        BOOL exited = NO, eof = NO;
        fcntl(descriptors[2], F_SETFL, O_NONBLOCK);
        NSTimeInterval deadline = NSProcessInfo.processInfo.systemUptime + 5;
        while (alive && NSProcessInfo.processInfo.systemUptime < deadline && (!exited || !eof)) {
            ssize_t count = read(descriptors[2], output + used, sizeof(output) - used - 1);
            if (count > 0) used += count;
            else if (count == 0) eof = YES;
            int result = pollJob(jobs[2], &status);
            if (result == 1) exited = YES;
            else if (result < 0) break;
            if (!exited || !eof) usleep(10000);
        }
        alive = alive && exited && eof && status == 7 && !strcmp(output, "DONE=survivor\n");
        fprintf(thread_stdout, "peer input/output/status after loss: %s\n", alive ? "PASS" : "FAIL");
        passed = alive;
    }
    for (int i = 0; i < 3; i++) { if (jobs[i]) release(jobs[i]); if (descriptors[i] >= 0) close(descriptors[i]); }
    // Re-enter the full public capacity check after asynchronous teardown.
    if (passed) passed = capacity_check() == 0;
    if (!passed && busy && pids[0] > 0 && pids[0] != getpid()) kill(pids[0], SIGKILL);
    fprintf(thread_stdout, "worker lifecycle and full capacity reuse: %s\n", passed ? "PASS" : "FAIL");
    return passed ? 0 : 1;
}

// Run as a real app command. The same consumer must fail on the stock app.
int worker_pool_check_main(int argc, char **argv) {
    @autoreleasepool {
        if (argc == 2 && !strcmp(argv[1], "capacity")) return capacity_check();
        if (argc == 2 && !strcmp(argv[1], "lifecycle")) return lifecycle_check(NO, NO);
        if (argc == 2 && !strcmp(argv[1], "lifecycle-busy")) return lifecycle_check(YES, NO);
        if (argc == 2 && !strcmp(argv[1], "lifecycle-close")) return lifecycle_check(YES, YES);
        int (*spawn)(const char *, const char *, unsigned, unsigned, const char *const *, int *, void **) = dlsym(RTLD_DEFAULT, "ashell_pane_spawn");
        int (*pollJob)(void *, int *) = dlsym(RTLD_DEFAULT, "ashell_pane_poll");
        void (*release)(void *) = dlsym(RTLD_DEFAULT, "ashell_pane_release");
        if (!spawn || !pollJob || !release) {
            fputs("worker pool unavailable: FAIL\n", thread_stdout);
            return 1;
        }
        NSString *directory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
        const char *environment[] = {"POOL_VALUE=isolated", NULL};
        int descriptor = -1;
        void *job = NULL;
        int error = spawn("dash -c 'printf \"WORKER=%s\\n\" \"$POOL_VALUE\"'", directory.fileSystemRepresentation, 80, 24, environment, &descriptor, &job);
        if (error) { fprintf(thread_stdout, "worker startup error=%d: FAIL\n", error); return 1; }
        char output[256] = {0};
        size_t used = 0;
        BOOL completed = NO;
        int status = -1;
        NSTimeInterval deadline = NSProcessInfo.processInfo.systemUptime + 20;
        while (NSProcessInfo.processInfo.systemUptime < deadline) {
            struct pollfd ready = {.fd = descriptor, .events = POLLIN};
            if (poll(&ready, 1, 100) > 0 && used < sizeof(output) - 1) {
                ssize_t count = read(descriptor, output + used, sizeof(output) - used - 1);
                if (count > 0) used += count;
            }
            int result = pollJob(job, &status);
            if (result < 0) break;
            if (result == 1) { completed = YES; break; }
        }
        release(job);
        close(descriptor);
        BOOL passed = completed && status == 0 && !strcmp(output, "WORKER=isolated\n");
        fprintf(thread_stdout, "worker stdout=%zu status=%d: %s\n", used, status, passed ? "PASS" : "FAIL");
        return passed ? 0 : 1;
    }
}
