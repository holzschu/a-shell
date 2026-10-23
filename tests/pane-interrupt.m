#import <Foundation/Foundation.h>
#import <ios_system/ios_system.h>
#include "../ShellWorkers/NativePane.h"
#include <errno.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

static int interactive;
void startInteractive(void) { interactive = 1; }
void stopInteractive(void) { interactive = 0; }
int storeInteractive(void) { return interactive; }

// A real terminal consumer, registered through the command catalogue API.
int pane_raw_reader_main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    int tty = ios_gettty();
    struct termios saved, raw;
    int has_tty = tty >= 0 && tcgetattr(tty, &saved) == 0;
    if (has_tty) {
        raw = saved;
        cfmakeraw(&raw);
        if (tcsetattr(tty, TCSANOW, &raw)) return 2;
    } else {
        tty = fileno(thread_stdin);
        ios_startInteractive();
    }
    fputs("RAW_READY\n", thread_stdout);
    fflush(thread_stdout);
    char bytes[2] = {0};
    int result = read(tty, bytes, 1) == 1 && bytes[0] == 3 &&
        read(tty, bytes + 1, 1) == 1 && bytes[1] == 'x' ? 0 : 3;
    if (has_tty) tcsetattr(tty, TCSANOW, &saved);
    return result;
}

static int send_line(int fd, const char *line) {
    size_t length = strlen(line);
    return write(fd, line, length) == (ssize_t)length ? 0 : 1;
}

static int read_marker(int fd, const char *marker) {
    char output[32768] = {0};
    size_t used = 0;
    for (int i = 0; i < 100; i++) {
        struct pollfd ready = {.fd = fd, .events = POLLIN};
        if (poll(&ready, 1, 50) <= 0) continue;
        ssize_t count = read(fd, output + used, sizeof(output) - used - 1);
        if (count <= 0) break;
        size_t start = used;
        for (ssize_t j = 0; j < count; j++)
            if (output[start + j] != '\r') output[used++] = output[start + j];
        output[used] = 0;
        if (strstr(output, marker)) return 0;
        if (used == sizeof(output) - 1) break;
    }
    dprintf(2, "Missing marker %s; output: %s\n", marker, output);
    return 1;
}

int main(int argc, char **argv) {
    @autoreleasepool {
        alarm(15);
        initializeEnvironment();
        BOOL raw = argc > 1 && (!strcmp(argv[1], "raw") || !strcmp(argv[1], "raw-socket"));
        BOOL pty = raw && strcmp(argv[1], "raw-socket");
        if (raw) replaceCommand(@"pane-raw-reader", @"pane_raw_reader_main", false);
        NSString *path = [@"PATH=" stringByAppendingString:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"bin"]];
        const char *env[] = {"ASHELL_IOS_SOCKET_INPUT=1", pty ? "ASHELL_IOS_PTY=1" : "ASHELL_IOS_PTY=0", "PS1=PANE_PROMPT>", path.UTF8String, NULL};
        ashell_pane_options options = {.size = sizeof(options), .tty = 1};
        int fd = -1;
        void *job = NULL;
        int error = ashell_pane_spawn_ex(raw ? "pane-raw-reader" : "dash -i",
            NSTemporaryDirectory().fileSystemRepresentation, 80, 24, env, &options, &fd, &job);
        if (error) { dprintf(2, "spawn=%d\n", error); return 2; }
        if (raw) {
            if (read_marker(fd, "RAW_READY")) return 1;
            error = ashell_pane_interrupt(job);
            if (error != ENOTSUP || send_line(fd, "\003x")) return 1;
        } else {
            if (read_marker(fd, "PANE_PROMPT>")) return 1;
            if (send_line(fd, "printf 'PANE_RUNNING\\n'; sleep 30\n") || read_marker(fd, "PANE_RUNNING\n")) return 1;
            // The marker precedes dispatch; allow the real sleep to enter its wait.
            usleep(200000);
            error = ashell_pane_interrupt(job);
            if (error || read_marker(fd, "PANE_PROMPT>")) return 1;
            if (send_line(fd, "printf 'PANE_STATUS_%s_END\\n' \"$?\"\n") || read_marker(fd, "PANE_STATUS_130_END\n")) return 1;
            if (send_line(fd, "printf 'PANE_NEXT_OK\\n'; exit 0\n") || read_marker(fd, "PANE_NEXT_OK\n")) return 1;
        }
        int status = -1, finished = 0;
        for (int i = 0; i < 100 && !(finished = ashell_pane_poll(job, &status)); i++) usleep(10000);
        BOOL passed = finished == 1 && status == 0;
        ashell_pane_release(job);
        close(fd);
        dprintf(1, "%s interrupt=%d completion=%d status=%d: %s\n", raw ? "raw" : "cooked", error, finished, status, passed ? "PASS" : "FAIL");
        return passed ? 0 : 1;
    }
}
