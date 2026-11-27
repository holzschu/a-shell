#import <Foundation/Foundation.h>
#include <assert.h>
#include <mach/mach.h>
#import <ios_system/ios_system.h>
#include <unistd.h>
#include <time.h>
#include <sys/resource.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <pthread.h>
#include <poll.h>
#include <stdatomic.h>
extern int openpty(int *, int *, char *, struct termios *, struct winsize *);
extern int nvim_ios_main(int argc, char **argv);

typedef struct { int fd; atomic_bool stopping; } PTYReader;
static void *drainPTY(void *context) {
    PTYReader *reader = context;
    struct pollfd descriptor = {reader->fd, POLLIN, 0};
    char bytes[4096];
    while (!atomic_load(&reader->stopping)) {
        if (poll(&descriptor, 1, 100) > 0 && read(reader->fd, bytes, sizeof bytes) <= 0) break;
    }
    return NULL;
}

static double now(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}

static unsigned threadCount(void) {
    thread_act_array_t threads;
    mach_msg_type_number_t count;
    assert(task_threads(mach_task_self(), &threads, &count) == KERN_SUCCESS);
    for (unsigned i = 0; i < count; i++) mach_port_deallocate(mach_task_self(), threads[i]);
    vm_deallocate(mach_task_self(), (vm_address_t)threads, count * sizeof(*threads));
    return count;
}

int main(int argc, char **argv) {
    @autoreleasepool {
    if (argc > 1 && !strcmp(argv[1], "--interactive-memory")) {
        int master, slave;
        struct winsize size = {24, 80, 0, 0};
        assert(openpty(&master, &slave, NULL, NULL, &size) == 0);
        thread_stdin = fdopen(slave, "r");
        thread_stdout = fdopen(dup(slave), "w");
        thread_stderr = fdopen(dup(slave), "w");
        assert(thread_stdin && thread_stdout && thread_stderr);
        unsigned before = threadCount();
        PTYReader reader = {.fd = master, .stopping = false};
        pthread_t consumer;
        assert(pthread_create(&consumer, NULL, drainPTY, &reader) == 0);
        char *args[] = {"nvim", "-u", "NONE", "+qa", NULL};
        char **command = argc > 2 ? argv + 1 : args;
        int count = argc > 2 ? argc - 1 : 4;
        command[0] = "nvim";
        int status = nvim_ios_main(count, command);
        atomic_store(&reader.stopping, true);
        assert(pthread_join(consumer, NULL) == 0);
        struct rusage usage;
        assert(getrusage(RUSAGE_SELF, &usage) == 0);
        dprintf(2, "NVIM_TUI_PEAK_RSS_BYTES=%ld status=%d threads=%u\n", usage.ru_maxrss, status, threadCount());
        assert(status == 0 && threadCount() == before);
        fclose(thread_stdin); fclose(thread_stdout); fclose(thread_stderr); close(master);
        return status;
    }
    if (argc > 1 && !strcmp(argv[1], "--headless")) {
        thread_stdin = stdin; thread_stdout = stdout; thread_stderr = stderr;
        unsigned before = threadCount();
        int status = nvim_ios_main(argc, argv);
        fprintf(stderr, "HOST_THREADS before=%u after=%u\n", before, threadCount());
        assert(threadCount() == before);
        if (status) return status;
        char *again[] = {"nvim", "--headless", "-u", "NONE", "+lua print('REENTERED_AFTER_ASYNC')", "+qa", NULL};
        status = nvim_ios_main(6, again);
        assert(threadCount() == before);
        return status;
    }
    BOOL legacy = argc > 1 && !strcmp(argv[1], "legacy");
    NSLog(@"BUNDLE=%@", NSBundle.mainBundle.bundlePath);
    FILE *input = tmpfile(), *output = tmpfile(), *errors = tmpfile();
    assert(input && output && errors);
    int saved = -1;
    // Negative control reproduces the old adapter in this isolated test host only.
    if (legacy) { saved = dup(1); assert(dup2(fileno(output), 1) >= 0); }
    dispatch_group_t group = dispatch_group_create();
    __block double aStart = 0, aEnd = 0, bStart = 0, bEnd = 0;
    __block int status = -1, observed = 0;
    dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        thread_stdin = input; thread_stdout = output; thread_stderr = errors;
        char *args[] = {"nvim", "--headless", "-u", "NONE", "+lua for i=1,40 do io.stdout:write('PANE_A\\n'); io.stdout:flush(); vim.loop.sleep(50) end", "+qa", NULL};
        aStart = now();
        status = nvim_ios_main(6, args);
        aEnd = now();
    });
    dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        char first[7];
        double deadline = now() + 10;
        while (now() < deadline) {
            if (pread(fileno(output), first, sizeof first, 0) == sizeof first && !memcmp(first, "PANE_A\n", 7)) { observed = 1; break; }
            usleep(10000);
        }
        bStart = now();
        for (int i = 0; i < 20; i++) { write(1, "PANE_B_FD1\n", 11); usleep(25000); }
        bEnd = now();
    });
    long timeout = dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC));
    if (legacy) { dup2(saved, 1); close(saved); }
    assert(timeout == 0);
    rewind(errors); char diagnostic[8192] = {0}; fread(diagnostic, 1, sizeof diagnostic - 1, errors); fprintf(stderr, "nvim status=%d stderr=%s\n", status, diagnostic);
    assert(status == 0);
    assert(observed == 1);
    assert(aStart < bStart);
    assert(bEnd < aEnd);
    fflush(output); rewind(output);
    char bytes[8192] = {0}; fread(bytes, 1, sizeof bytes - 1, output);
    NSString *text = [NSString stringWithUTF8String:bytes];
    assert([text componentsSeparatedByString:@"PANE_A\n"].count - 1 == 40);
    NSUInteger leaked = [text componentsSeparatedByString:@"PANE_B_FD1\n"].count - 1;
    assert(leaked == (legacy ? 20 : 0));
    NSLog(@"NVIM_OVERLAP legacy=%d A=[%.6f,%.6f] B=[%.6f,%.6f] B_in_A=%lu status=%d", legacy, aStart, aEnd, bStart, bEnd, (unsigned long)leaked, status);
    struct rusage usage;
    assert(getrusage(RUSAGE_SELF, &usage) == 0);
    fprintf(stderr, "NVIM_PEAK_RSS_BYTES=%ld\n", usage.ru_maxrss);
    fclose(input); fclose(output); fclose(errors);
    return 0;
    }
}
