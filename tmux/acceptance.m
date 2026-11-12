// Register as tmux-acceptance in the app. Drive normal tmux commands through
// public ios_system sessions, with a socket standing in for terminal keystrokes.
#import <Foundation/Foundation.h>
#import "ios_system/ios_system.h"
#include <sys/socket.h>
#include <pthread.h>
#include <poll.h>
#include <fcntl.h>

@interface TmuxTerminal : NSObject
@property NSString *command;
@property NSString *key;
@property void *session_key;
@property void *registration;
@property int peer;
@property int command_fd;
@property int status;
@property BOOL done;
@property NSMutableData *output;
@end
@implementation TmuxTerminal
@end

static void *run_terminal(void *cookie) {
    TmuxTerminal *terminal = (__bridge_transfer TmuxTerminal *)cookie;
    @autoreleasepool {
        const void *key = terminal.session_key;
        ios_switchSession(key);
        ios_setContext(key);
        FILE *input = fdopen(dup(terminal.command_fd), "r");
        FILE *output = fdopen(dup(terminal.command_fd), "w");
        FILE *error = fdopen(dup(terminal.command_fd), "w");
        void *registration = NULL;
        terminal.status = ashell_register_owned_streams(input, output, error, &registration);
        if (!terminal.status) {
            terminal.registration = registration;
            ios_setStreams(input, output, error);
            ios_settty(input);
            ios_useNativeTTY(false);
            thread_stdin = input; thread_stdout = output; thread_stderr = error;
            ios_setWindowSize(95, 37, key);
            pid_t pid = ios_fork();
            ios_system(terminal.command.UTF8String);
            ios_waitpid(pid);
            ashell_wait_owned_streams(registration);
            terminal.status = ios_getCommandStatus();
            ios_releaseThreadId(pid);
            ashell_unregister_owned_streams(&registration);
            terminal.registration = NULL;
        }
        fclose(input); fclose(output); fclose(error);
        close(terminal.command_fd);
        ios_closeSession(key);
        terminal.done = YES;
    }
    return NULL;
}

static TmuxTerminal *start(NSString *command, pthread_t *thread) {
    int pair[2];
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, pair)) return nil;
    TmuxTerminal *terminal = [TmuxTerminal new];
    terminal.command = command;
    terminal.key = NSUUID.UUID.UUIDString;
    terminal.session_key = strdup(terminal.key.UTF8String);
    terminal.peer = pair[0]; terminal.command_fd = pair[1];
    terminal.output = [NSMutableData new];
    int one = 1;
    setsockopt(pair[0], SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof one);
    if (pthread_create(thread, NULL, run_terminal, (__bridge_retained void *)terminal)) {
        close(pair[0]); close(pair[1]); return nil;
    }
    return terminal;
}

static void drain(TmuxTerminal *terminal, unsigned milliseconds) {
    uint64_t deadline = clock_gettime_nsec_np(CLOCK_MONOTONIC) + (uint64_t)milliseconds * 1000000;
    while (clock_gettime_nsec_np(CLOCK_MONOTONIC) < deadline) {
        struct pollfd fd = {terminal.peer, POLLIN, 0};
        if (poll(&fd, 1, 20) > 0 && (fd.revents & POLLIN)) {
            char buffer[16384]; ssize_t n = read(terminal.peer, buffer, sizeof buffer);
            if (n > 0) [terminal.output appendBytes:buffer length:n];
        }
    }
}

static BOOL send_keys(TmuxTerminal *terminal, NSString *keys) {
    NSData *bytes = [keys dataUsingEncoding:NSUTF8StringEncoding];
    const char *p = bytes.bytes; size_t left = bytes.length;
    while (left) {
        ssize_t n = write(terminal.peer, p, left);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) return NO;
        p += n; left -= n;
    }
    drain(terminal, 400);
    return YES;
}

static int finish(TmuxTerminal *terminal, pthread_t thread) {
    for (unsigned i = 0; !terminal.done && i < 300; i++) drain(terminal, 100);
    if (!terminal.done) return ETIMEDOUT;
    pthread_join(thread, NULL);
    close(terminal.peer);
    free(terminal.session_key);
    return terminal.status;
}

static BOOL file_is(NSString *path, NSString *expected) {
    return [[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] isEqual:expected];
}

__attribute__((visibility("default"))) int tmux_acceptance(int argc, char **argv) {
    @autoreleasepool {
        if (argc != 2 || argv[1][0] != '/') return 64;
        NSString *directory = @(argv[1]);
        NSError *error;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error]) return 1;
        NSString *label = [@"a" stringByAppendingString:[NSUUID.UUID.UUIDString substringToIndex:4]];
        NSString *base = [NSString stringWithFormat:@"tmux -L %@", label];
        pthread_t thread;
        TmuxTerminal *terminal = start([base stringByAppendingString:@" new -s t"], &thread);
        if (!terminal) return 1;
        for (unsigned i = 0; !terminal.output.length && !terminal.done && i < 600; i++) drain(terminal, 100);
        fprintf(thread_stdout, "initial bytes=%lu done=%d\n", (unsigned long)terminal.output.length, terminal.done);
        [terminal.output writeToFile:[directory stringByAppendingPathComponent:@"initial.ansi"] atomically:YES];
        if (terminal.output.length < 100) fwrite(terminal.output.bytes, 1, terminal.output.length, thread_stdout);
        fflush(thread_stdout);
        for (unsigned pane = 0; pane < 3; pane++) {
            if (pane == 1) send_keys(terminal, @"\002%");
            if (pane == 2) send_keys(terminal, @"\002\"");
            NSString *path = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"pane%u.txt", pane]];
            NSString *command = [NSString stringWithFormat:@"echo ok > '%@'; printf 'hello\\n' | tr a-z A-Z >> '%@'\r", path, path];
            if (!send_keys(terminal, command)) return 2;
            for (unsigned i = 0; !file_is(path, @"ok\nHELLO\n") && i < 200; i++) drain(terminal, 100);
            fprintf(thread_stdout, "pane%u file=%d bytes=%lu\n", pane, file_is(path, @"ok\nHELLO\n"), (unsigned long)terminal.output.length);
            fflush(thread_stdout);
        }
        NSString *vim = [directory stringByAppendingPathComponent:@"vim.txt"];
        send_keys(terminal, [NSString stringWithFormat:@"vim '%@'\r", vim]);
        drain(terminal, 1000);
        send_keys(terminal, @":highlight Normal ctermfg=196 ctermbg=17\riTMUX_VIM_K\033[DO\033");
        ios_setWindowSize(111, 43, terminal.session_key);
        int cols = 0, rows = 0;
        int size_error = ios_getWindowSize(&cols, &rows, terminal.session_key);
        fprintf(thread_stdout, "window size=%dx%d error=%d\n", cols, rows, size_error);
        drain(terminal, 1000);
        send_keys(terminal, @"oAFTER_RESIZE_K\033[DO\033:wq\r");
        for (unsigned i = 0; !file_is(vim, @"TMUX_VIM_OK\nAFTER_RESIZE_OK\n") && i < 100; i++) drain(terminal, 100);
        send_keys(terminal, @"\002d");
        int status = finish(terminal, thread);
        [terminal.output writeToFile:[directory stringByAppendingPathComponent:@"first.ansi"] atomically:YES];
        fprintf(thread_stdout, "detach status=%d bytes=%lu\n", status, (unsigned long)terminal.output.length);
        if (status) return 3;
        for (unsigned pane = 0; pane < 3; pane++) {
            NSString *path = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"pane%u.txt", pane]];
            if (!file_is(path, @"ok\nHELLO\n")) { fprintf(thread_stdout, "FAIL pane%u output\n", pane); return 4; }
        }
        BOOL vim_ok = file_is(vim, @"TMUX_VIM_OK\nAFTER_RESIZE_OK\n");
        NSString *rendered = [[NSString alloc] initWithData:terminal.output encoding:NSUTF8StringEncoding];
        BOOL colors_ok = [rendered containsString:@"38;5;196"] || [rendered containsString:@"38;2;255;0;0"];
        fprintf(thread_stdout, "%s vim file\n", vim_ok ? "PASS" : "FAIL");
        fprintf(thread_stdout, "%s vim colors and arrow keys before/after resize\n", vim_ok && colors_ok ? "PASS" : "FAIL");
        fprintf(thread_stdout, "PASS three panes echo/pipeline\n");
        terminal = start([base stringByAppendingString:@" list-panes -t t -F '#{pane_id} #{window_width}x#{window_height}'"], &thread);
        if (!terminal) return 1;
        shutdown(terminal.peer, SHUT_WR);
        status = finish(terminal, thread);
        NSString *panes = [[NSString alloc] initWithData:terminal.output encoding:NSUTF8StringEncoding];
        fprintf(thread_stdout, "panes status=%d %s", status, panes.UTF8String);
        if (status || ![panes containsString:@"111x42"]) return 6;
        terminal = start([base stringByAppendingString:@" attach -t t"], &thread);
        if (!terminal) return 1;
        for (unsigned i = 0; !terminal.output.length && !terminal.done && i < 600; i++) drain(terminal, 100);
        send_keys(terminal, [NSString stringWithFormat:@"echo reattached > '%@/reattached.txt'\r", directory]);
        send_keys(terminal, @"\002d");
        status = finish(terminal, thread);
        [terminal.output writeToFile:[directory stringByAppendingPathComponent:@"reattach.ansi"] atomically:YES];
        if (status || !file_is([directory stringByAppendingPathComponent:@"reattached.txt"], @"reattached\n")) return 7;
        terminal = start([base stringByAppendingString:@" attach -t t"], &thread);
        if (!terminal) return 1;
        for (unsigned i = 0; !terminal.output.length && !terminal.done && i < 600; i++) drain(terminal, 100);
        if (terminal.done || !terminal.registration || ashell_cancel_owned_streams(terminal.registration)) return 9;
        status = finish(terminal, thread);
        if (status == ETIMEDOUT) return 10;
        fprintf(thread_stdout, "PASS interrupted client status=%d\n", status);
        terminal = start([base stringByAppendingString:@" kill-server"], &thread);
        if (!terminal) return 1;
        shutdown(terminal.peer, SHUT_WR);
        if (finish(terminal, thread)) return 8;
        fprintf(thread_stdout, "PASS resize, detach/reattach and kill-server\n");
        if (vim_ok && colors_ok) fprintf(thread_stdout, "TMUX_ACCEPTANCE_PASS\n");
        return vim_ok && colors_ok ? 0 : 5;
    }
}
