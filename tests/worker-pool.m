#import <Foundation/Foundation.h>
#import <ios_system/ios_system.h>
#include <dlfcn.h>
#include <poll.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include "../ShellWorkers/NativePane.h"


#define MAX_WORKERS 64

// Dash fixture commands must not source the user's login profile.
static const char *const nonlogin_environment[] = {"_DASH_LOGIN_SHELL=1", NULL};

// Host bookmarks can resolve /var and /private/var to the same HOME directory.
static BOOL same_directory(const char *left, const char *right) {
    struct stat a, b;
    return left && right && stat(left, &a) == 0 && stat(right, &b) == 0 &&
        S_ISDIR(a.st_mode) && S_ISDIR(b.st_mode) && a.st_dev == b.st_dev && a.st_ino == b.st_ino;
}

// Keep each command alive at its public stdin boundary while the other slots start.
static int capacity_check(void) {
    int (*spawn)(const char *, const char *, unsigned, unsigned, const char *const *, int *, void **) = dlsym(RTLD_DEFAULT, "ashell_pane_spawn");
    int (*pollJob)(void *, int *) = dlsym(RTLD_DEFAULT, "ashell_pane_poll");
    void (*release)(void *) = dlsym(RTLD_DEFAULT, "ashell_pane_release");
    if (!spawn || !pollJob || !release) { fputs("worker pool unavailable: FAIL\n", thread_stdout); return 1; }
    NSString *root = [NSHomeDirectory() stringByAppendingPathComponent:[@"Documents/worker-pool-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    // The cap in force now: the setting or the core count, limited to the bundled extensions.
    int (*capacityOf)(void) = dlsym(RTLD_DEFAULT, "ashell_pane_capacity");
    const int capacity = capacityOf ? capacityOf() : [[NSBundle.mainBundle objectForInfoDictionaryKey:@"ShellWorkerCount"] intValue];
    if (capacity < 1 || capacity > MAX_WORKERS) return 64;
    void *jobs[MAX_WORKERS] = {0};
    int descriptors[MAX_WORKERS];
    static char output[MAX_WORKERS][2048];
    memset(output, 0, sizeof(output));
    size_t used[MAX_WORKERS] = {0};
    int pids[MAX_WORKERS] = {0};
    BOOL passed = YES;
    for (int i = 0; i < capacity; i++) descriptors[i] = -1;
    for (int i = 0; i < capacity; i++) {
        NSString *directory = [root stringByAppendingPathComponent:[NSString stringWithFormat:@"slot-%d", i]];
        if (![[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil]) { passed = NO; break; }
        char value[32], command[256];
        snprintf(value, sizeof(value), "POOL_VALUE=slot-%d", i);
        const char *environment[] = {value, "_DASH_LOGIN_SHELL=1", NULL};
        snprintf(command, sizeof(command), "dash -c 'printf \"READY=%%s,%%s\\n\" \"$ASHELL_WORKER_PID\" \"$POOL_VALUE\"; pwd; read value; printf \"END=%%s\\n\" \"$value\"; exit %d'", i);
        int error = spawn(command, directory.fileSystemRepresentation, 80, 24, environment, &descriptors[i], &jobs[i]);
        if (error) { fprintf(thread_stdout, "slot=%d startup error=%d: FAIL\n", i, error); passed = NO; break; }
        if (fcntl(descriptors[i], F_SETFL, O_NONBLOCK)) { passed = NO; break; }
    }
    NSTimeInterval deadline = NSProcessInfo.processInfo.systemUptime + 10;
    BOOL allReady = NO;
    while (passed && NSProcessInfo.processInfo.systemUptime < deadline) {
        allReady = YES;
        for (int i = 0; i < capacity; i++) {
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
    for (int i = 0; passed && i < capacity; i++) {
        char value[32];
        if (sscanf(output[i], "READY=%d,%31[^\n]", &pids[i], value) != 2 || pids[i] <= 0) { passed = NO; break; }
        char expectedValue[32];
        snprintf(expectedValue, sizeof(expectedValue), "slot-%d", i);
        NSString *expectedDirectory = [root stringByAppendingPathComponent:[NSString stringWithFormat:@"slot-%d", i]];
        NSString *observedDirectory = [[NSString stringWithUTF8String:strchr(output[i], '\n') + 1] stringByTrimmingCharactersInSet:NSCharacterSet.newlineCharacterSet];
        struct stat expectedStat, observedStat;
        BOOL sameDirectory = stat(expectedDirectory.fileSystemRepresentation, &expectedStat) == 0 && stat(observedDirectory.fileSystemRepresentation, &observedStat) == 0 && expectedStat.st_dev == observedStat.st_dev && expectedStat.st_ino == observedStat.st_ino;
        if (strcmp(value, expectedValue) || !sameDirectory) {
            fprintf(thread_stdout, "expected cwd=%s\nactual=%s", expectedDirectory.fileSystemRepresentation, output[i]);
            passed = NO;
        }
        for (int j = 0; j < i; j++) if (pids[i] == pids[j]) passed = NO;
        fprintf(thread_stdout, "slot=%d real_pid=%d cwd/env=%s\n", i, pids[i], passed ? "PASS" : "FAIL");
    }
    if (passed) {
        int descriptor = -1;
        void *job = NULL;
        int error = spawn("dash -c 'exit 0'", root.fileSystemRepresentation, 80, 24, nonlogin_environment, &descriptor, &job);
        BOOL full = error == ENOSPC && descriptor == -1 && job == NULL;
        fprintf(thread_stdout, "worker=%d error=%d: %s\n", capacity + 1, error, full ? "PASS" : "FAIL");
        if (job) release(job);
        if (descriptor >= 0) close(descriptor);
        passed = full;
    }
    // The same open sessions must still accept input after more than five seconds.
    if (passed) {
        sleep(6);
        for (int i = 0; i < capacity; i++) if (write(descriptors[i], "continue\n", 9) != 9) passed = NO;
        for (int i = 0; i < capacity; i++) {
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
    for (int i = 0; i < capacity; i++) {
        if (jobs[i]) release(jobs[i]);
        if (descriptors[i] >= 0) close(descriptors[i]);
    }
    [[NSFileManager defaultManager] removeItemAtPath:root error:nil];
    fprintf(thread_stdout, "workers=%d capacity: %s\n", capacity, passed ? "PASS" : "FAIL");
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
        const char *command = i == 1 ? "dash -c 'printf \"READY=%s\\n\" \"$ASHELL_WORKER_PID\"; read value; worker-pool-crash'" : busy && i == 0 ? "dash -c 'printf \"READY=%s\\n\" \"$ASHELL_WORKER_PID\"; while :; do :; done'" : "dash -c 'printf \"READY=%s\\n\" \"$ASHELL_WORKER_PID\"; read value; printf \"DONE=%s\\n\" \"$value\"; exit 7'";
        int error = spawn(command, directory.fileSystemRepresentation, 80, 24, nonlogin_environment, &descriptors[i], &jobs[i]);
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
        // Ask the disposable crash command to terminate its own worker process.
        // iOS denies a host process permission to signal an extension directly.
        BOOL lost = write(descriptors[1], "crash\n", 6) == 6;
        int status = -1, result = 0;
        NSTimeInterval deadline = NSProcessInfo.processInfo.systemUptime + 5;
        while (lost && NSProcessInfo.processInfo.systemUptime < deadline) {
            result = pollJob(jobs[1], &status);
            if (result) break;
            usleep(10000);
        }
        lost = lost && result == -EPIPE && status == -1;
        fprintf(thread_stdout, "lost worker result=%d status=%d: %s\n", result, status, lost ? "PASS" : "FAIL");
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
    fprintf(thread_stdout, "worker lifecycle and full capacity reuse: %s\n", passed ? "PASS" : "FAIL");
    return passed ? 0 : 1;
}

// Exit status must not depend on the consumer draining pending output first.
static int completion_check(BOOL identity) {
    int (*spawn)(const char *, const char *, unsigned, unsigned, const char *const *, int *, void **) = dlsym(RTLD_DEFAULT, "ashell_pane_spawn");
    int (*pollJob)(void *, int *) = dlsym(RTLD_DEFAULT, "ashell_pane_poll");
    void (*release)(void *) = dlsym(RTLD_DEFAULT, "ashell_pane_release");
    if (!spawn || !pollJob || !release) return 1;
    NSString *directory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    int descriptor = -1, status = -1, result = 0;
    void *job = NULL;
    const char *environment[] = {"ASHELL_WORKER_PID=-1", "ASHELL_WORKER_ROOT_PID=-1", "_DASH_LOGIN_SHELL=1", NULL};
    const char *command = identity ? "dash -c 'test \"$ASHELL_WORKER_PID\" -gt 0 && test \"$ASHELL_WORKER_ROOT_PID\" -gt 0 && dash -c \"test \\\"\\$ASHELL_WORKER_PID\\\" -gt 0 && test \\\"\\$ASHELL_WORKER_ROOT_PID\\\" -gt 0\" && printf pending-output; exit 7'" : "dash -c 'printf pending-output; exit 7'";
    int error = spawn(command, directory.fileSystemRepresentation, 80, 24, identity ? environment : nonlogin_environment, &descriptor, &job);
    if (error) { fprintf(thread_stdout, "completion startup=%d: FAIL\n", error); return 1; }
    NSTimeInterval deadline = NSProcessInfo.processInfo.systemUptime + 10;
    while (!result && NSProcessInfo.processInfo.systemUptime < deadline) {
        result = pollJob(job, &status);
        if (!result) usleep(10000);
    }
    int first_status = status, repeated_result = 0, repeated_status = -1;
    BOOL passed = result == 1 && status == 7;
    status = -1;
    if (passed) {
        repeated_result = pollJob(job, &status);
        repeated_status = status;
        passed = repeated_result == 1 && status == 7;
    }
    char output[64] = {0};
    ssize_t count = passed ? read(descriptor, output, sizeof(output) - 1) : -1;
    int read_error = passed && count < 0 ? errno : 0;
    BOOL output_matches = count == 14 && !strcmp(output, "pending-output");
    passed = passed && output_matches;
    ssize_t eof = -1;
    if (passed) {
        eof = read(descriptor, output, 1);
        if (eof < 0) read_error = errno;
        passed = eof == 0;
    }
    if (!passed) {
        struct pollfd ready = {.fd = descriptor, .events = POLLIN};
        int ready_result = poll(&ready, 1, 0);
        fprintf(thread_stdout, "completion result=%d status=%d repeated_result=%d repeated_status=%d bytes=%zd output_matches=%d eof=%zd read_errno=%d readiness=%d revents=%#x\n", result, first_status, repeated_result, repeated_status, count, output_matches, eof, read_error, ready_result, ready.revents);
    }
    release(job);
    close(descriptor);
    fprintf(thread_stdout, "%s: %s\n", identity ? "Dash identity and nested command lookup" : "status before output drain and repeated status", passed ? "PASS" : "FAIL");
    return passed ? 0 : 1;
}

// The cap follows the setting: default is the physical core count, a larger setting allows more
// concurrent workers up to the bundled count, a smaller one fewer, and ENOSPC comes right after it.
static int limit_check(void) {
    int (*capacityOf)(void) = dlsym(RTLD_DEFAULT, "ashell_pane_capacity");
    if (!capacityOf) { fputs("worker pool capacity unavailable: FAIL\n", thread_stdout); return 1; }
    int bundled = [[NSBundle.mainBundle objectForInfoDictionaryKey:@"ShellWorkerCount"] intValue];
    int cores = 0;
    size_t size = sizeof(cores);
    if (sysctlbyname("hw.physicalcpu", &cores, &size, NULL, 0) || cores < 1) return 64;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    id previous = [defaults objectForKey:@"worker_limit"];
    BOOL passed = YES;
    [defaults removeObjectForKey:@"worker_limit"];
    int expected = cores < bundled ? cores : bundled;
    fprintf(thread_stdout, "default capacity=%d expected=%d (cores=%d bundled=%d): %s\n", capacityOf(), expected, cores, bundled, capacityOf() == expected ? "PASS" : "FAIL");
    passed = capacityOf() == expected;
    if (passed) passed = capacity_check() == 0;
    // A setting of 2, the bundled count and more than the bundled count.
    int settings[] = {2, bundled, bundled + 5};
    for (int i = 0; passed && i < 3; i++) {
        [defaults setInteger:settings[i] forKey:@"worker_limit"];
        expected = settings[i] < bundled ? settings[i] : bundled;
        passed = capacityOf() == expected;
        fprintf(thread_stdout, "worker_limit=%d capacity=%d expected=%d: %s\n", settings[i], capacityOf(), expected, passed ? "PASS" : "FAIL");
        if (passed) passed = capacity_check() == 0;
    }
    if (previous) [defaults setObject:previous forKey:@"worker_limit"]; else [defaults removeObjectForKey:@"worker_limit"];
    fprintf(thread_stdout, "worker limit setting: %s\n", passed ? "PASS" : "FAIL");
    return passed ? 0 : 1;
}

// Exercise the same public ABI from a host command and from its real worker child.
static int spawn_contract(BOOL nested, BOOL host) {
    int (*spawn)(const char *, const char *, unsigned, unsigned, const char *const *, ashell_pane_options *, int *, void **) = dlsym(RTLD_DEFAULT, nested ? (host ? "ashell_worker_host_spawn_ex" : "ashell_worker_spawn_ex") : "ashell_pane_spawn_ex");
    int (*pollJob)(void *, int *, struct rusage *, int *) = dlsym(RTLD_DEFAULT, nested ? (host ? "ashell_worker_host_poll_usage" : "ashell_worker_poll_usage") : "ashell_pane_poll_usage");
    void (*release)(void *) = dlsym(RTLD_DEFAULT, nested ? (host ? "ashell_worker_host_release" : "ashell_worker_release") : "ashell_pane_release");
    if (!spawn || !pollJob || !release) { fputs("spawn contract unavailable: FAIL\n", thread_stdout); return 1; }
    // Exercise a caller HOME spelling that the worker bookmark may normalize.
    NSString *home = nested ? @(getenv("HOME")) : [NSHomeDirectory() stringByAppendingString:@"/."];
    NSString *directory = [home stringByAppendingPathComponent:@"Documents"];
    NSString *homeValue = [@"HOME=" stringByAppendingString:home];
    NSString *expected = [@"POOL_EXPECTED_HOME=" stringByAppendingString:home];
    NSString *parent = [NSString stringWithFormat:@"POOL_PARENT_PID=%d", getpid()];
    NSString *hostPID = nested ? @(getenv("POOL_HOST_PID") ?: "") : [NSString stringWithFormat:@"%d", getpid()];
    NSString *hostValue = [@"POOL_HOST_PID=" stringByAppendingString:hostPID];
    const char *environment[] = {homeValue.UTF8String, expected.UTF8String, parent.UTF8String, hostValue.UTF8String, NULL};
    ashell_pane_options options = {.size = sizeof(options), .tty = 0, .separate_stderr = 1};
    int fd = -1, status = -1;
    void *job = NULL;
    const char *command = nested ? (host ? "worker-pool-host-payload" : "worker-pool-payload") : (host ? "worker-pool-nested-host" : "worker-pool-nested");
    int error = spawn(command, directory.fileSystemRepresentation, 80, 24, environment, &options, &fd, &job);
    if (error) { fprintf(thread_stdout, "spawn contract startup=%d: FAIL\n", error); return 1; }
    int descriptors[] = {fd, options.stderr_fd};
    char bytes[2][256] = {{0}};
    size_t used[2] = {0};
    BOOL eof[2] = {NO, NO}, completed = NO, valid = YES;
    for (int i = 0; i < 2; i++)
        if (fcntl(descriptors[i], F_SETFL, O_NONBLOCK) || !(fcntl(descriptors[i], F_GETFD) & FD_CLOEXEC)) valid = NO;
    NSTimeInterval deadline = NSProcessInfo.processInfo.systemUptime + 20;
    struct rusage usage;
    int available = 0;
    while (valid && NSProcessInfo.processInfo.systemUptime < deadline && (!completed || !eof[0] || !eof[1])) {
        for (int i = 0; i < 2; i++) {
            ssize_t count = read(descriptors[i], bytes[i] + used[i], sizeof(bytes[i]) - used[i] - 1);
            if (count > 0) used[i] += count;
            else if (!count) eof[i] = YES;
            else if (errno != EAGAIN && errno != EINTR) valid = NO;
        }
        int result = pollJob(job, &status, &usage, &available);
        if (result < 0) valid = NO;
        if (result == 1) completed = YES;
        if (!completed || !eof[0] || !eof[1]) usleep(10000);
    }
    BOOL passed = valid && completed && eof[0] && eof[1] && available && status == 7 &&
        !strcmp(bytes[0], "PAYLOAD\n") && !strcmp(bytes[1], "ERROR\n");
    if (!passed) fprintf(thread_stderr, "spawn contract nested=%d valid=%d completed=%d eof=%d,%d usage=%d status=%d stdout=[%s] stderr=[%s]\n", nested, valid, completed, eof[0], eof[1], available, status, bytes[0], bytes[1]);
    release(job);
    close(fd);
    close(options.stderr_fd);
    if (!nested) fprintf(thread_stdout, "nested %s streams/tty/home/tmpdir/status/usage: %s\n", host ? "host" : "worker", passed ? "PASS" : "FAIL");
    return passed ? 0 : 1;
}

int worker_pool_nested_main(int argc, char **argv) {
    const char *home = getenv("HOME"), *expected = getenv("POOL_EXPECTED_HOME");
    const char *root = ios_getenv("ASHELL_WORKER_ROOT_PID");
    if (!root || atoi(root) != ios_currentPid() || !same_directory(home, expected)) {
        fprintf(thread_stderr, "nested context root=%s pid=%d home_same=%d home=%s expected=%s\n", root ?: "missing", ios_currentPid(), same_directory(home, expected), home ?: "missing", expected ?: "missing");
        return 1;
    }
    if (spawn_contract(YES, NO)) return 1;
    fputs("PAYLOAD\n", thread_stdout);
    fputs("ERROR\n", thread_stderr);
    return 7;
}

int worker_pool_nested_host_main(int argc, char **argv) {
    if (spawn_contract(YES, YES)) return 1;
    fputs("PAYLOAD\n", thread_stdout);
    fputs("ERROR\n", thread_stderr);
    return 7;
}

int worker_pool_host_payload_main(int argc, char **argv) {
    const char *host = ios_getenv("POOL_HOST_PID");
    if (!host || atoi(host) != getpid() || ios_getenv("ASHELL_WORKER_PID") || ios_getenv("ASHELL_WORKER_ROOT_PID") || ios_isatty(1)) return 1;
    int (*spawn)(const char *, const char *, unsigned, unsigned, const char *const *, int *, void **) = dlsym(RTLD_DEFAULT, "ashell_host_pane_spawn");
    int fd = -1;
    void *job = NULL;
    NSString *directory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    if (!spawn || spawn("worker-pool-host-payload", directory.fileSystemRepresentation, 80, 24, NULL, &fd, &job) != EBUSY || fd != -1 || job) return 1;
    fputs("PAYLOAD\n", thread_stdout);
    fputs("ERROR\n", thread_stderr);
    return 7;
}

static int loss_check(void) {
    int (*spawn)(const char *, const char *, unsigned, unsigned, const char *const *, int *, void **) = dlsym(RTLD_DEFAULT, "ashell_pane_spawn");
    int (*pollJob)(void *, int *) = dlsym(RTLD_DEFAULT, "ashell_pane_poll");
    void (*release)(void *) = dlsym(RTLD_DEFAULT, "ashell_pane_release");
    if (!spawn || !pollJob || !release) return 1;
    int fd = -1, status = -1, result = 0;
    void *job = NULL;
    NSString *directory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    int error = spawn("worker-pool-crash", directory.fileSystemRepresentation, 80, 24, NULL, &fd, &job);
    if (error) return 1;
    NSTimeInterval deadline = NSProcessInfo.processInfo.systemUptime + 5;
    while (!result && NSProcessInfo.processInfo.systemUptime < deadline) {
        result = pollJob(job, &status);
        if (!result) usleep(10000);
    }
    BOOL passed = result == -EPIPE && status == -1;
    fprintf(thread_stdout, "lost worker result=%d status=%d: %s\n", result, status, passed ? "PASS" : "FAIL");
    release(job);
    close(fd);
    return passed ? 0 : 1;
}

int worker_pool_payload_main(int argc, char **argv) {
    const char *home = getenv("HOME"), *expected = getenv("POOL_EXPECTED_HOME");
    const char *temporary = getenv("TMPDIR");
    const char *parent = getenv("POOL_PARENT_PID");
    const char *root = ios_getenv("ASHELL_WORKER_ROOT_PID");
    if (!root || atoi(root) != ios_currentPid() || !home || !expected || !same_directory(home, expected) || !temporary ||
        strcmp(temporary, NSTemporaryDirectory().fileSystemRepresentation) || !parent || getpid() == atoi(parent) || ios_isatty(1)) {
        fprintf(thread_stderr, "payload root=%s pid=%d home=%d tmp_domain=%d process_distinct=%d tty=%d\n", root ?: "missing", ios_currentPid(), home && expected && same_directory(home, expected), temporary && !strcmp(temporary, NSTemporaryDirectory().fileSystemRepresentation), parent && getpid() != atoi(parent), ios_isatty(1));
        return 1;
    }
    NSString *file = [@(temporary) stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    int fd = open(file.fileSystemRepresentation, O_CREAT | O_EXCL | O_RDWR, 0600);
    if (fd < 0) return 1;
    BOOL passed = write(fd, "x", 1) == 1;
    if (close(fd) || unlink(file.fileSystemRepresentation)) passed = NO;
    if (!passed) return 1;
    fputs("PAYLOAD\n", thread_stdout);
    fputs("ERROR\n", thread_stderr);
    return 7;
}

// Run as a real app command. The same consumer must fail on the stock app.
int worker_pool_check_main(int argc, char **argv) {
    @autoreleasepool {
        if (argc == 2 && !strcmp(argv[1], "nested")) return spawn_contract(NO, NO);
        if (argc == 2 && !strcmp(argv[1], "host")) return spawn_contract(NO, YES);
        if (argc == 2 && !strcmp(argv[1], "loss")) return loss_check();
        if (argc == 2 && !strcmp(argv[1], "completion")) return completion_check(NO);
        if (argc == 2 && !strcmp(argv[1], "identity")) return completion_check(YES);
        if (argc == 2 && !strcmp(argv[1], "capacity")) return capacity_check();
        if (argc == 2 && !strcmp(argv[1], "limit")) return limit_check();
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
        const char *environment[] = {"POOL_VALUE=isolated", "_DASH_LOGIN_SHELL=1", NULL};
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

// Register only in disposable worker command catalogues for loss acceptance.
int worker_pool_crash_main(int argc, char **argv) {
    kill(getpid(), SIGKILL);
    return 1;
}
