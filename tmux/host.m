#import <Foundation/Foundation.h>
#include <TargetConditionals.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <poll.h>
#include <fcntl.h>
#include <dlfcn.h>
#include "NativePane.h"
#include "ios_error.h"
#include "ios-engine.h"
#undef write

typedef int (*spawn_fn)(const char *, const char *, unsigned, unsigned,
    const char *const *, ashell_pane_options *, int *, void **);
typedef int (*poll_fn)(void *, int *);
typedef int (*resize_fn)(void *, unsigned, unsigned);
typedef int (*close_fn)(void *);
typedef void (*release_fn)(void *);

static NSString *quote(NSString *text) {
    return [NSString stringWithFormat:@"'%@'", [text stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"]];
}

@interface TmuxServer : NSObject
@property void *job;
@property int fd;
@property BOOL exited;
@property BOOL cancel;
@property BOOL ready;
@property NSMutableData *diagnostic;
@end
@implementation TmuxServer
@end

static NSMutableDictionary<NSString *, TmuxServer *> *servers;

// Only the app owns server handles. A client extension may disappear on detach.
static int start_server(NSString *socket, NSString *cwd, NSArray<NSString *> *options,
    const char *const *env, TmuxServer **created) {
    spawn_fn spawn = (spawn_fn)dlsym(RTLD_DEFAULT, "ashell_pane_spawn_ex");
    if (!spawn) return ENOTSUP;
    TmuxServer *server;
    BOOL launched = NO;
    @synchronized (servers) {
        server = servers[socket];
        if (!server || server.exited) {
        NSMutableString *command = [NSMutableString stringWithString:@"tmux-native -D -S "];
        [command appendString:quote(socket)];
        for (NSString *option in options) [command appendFormat:@" %@", quote(option)];
        server = [TmuxServer new];
        server.diagnostic = [NSMutableData new];
        ashell_pane_options config = {.size = sizeof(config), .tty = 0};
        int fd;
        void *job;
        int error = spawn(command.UTF8String, cwd.UTF8String, 80, 24, env,
            &config, &fd, &job);
        if (error) return error;
        server.fd = fd;
        server.job = job;
        servers[socket] = server;
        *created = server;
        launched = YES;
        }
    }
    // Drain and reap independently of any foreground invocation, including detach.
    if (launched) dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        poll_fn poll_child = (poll_fn)dlsym(RTLD_DEFAULT, "ashell_pane_poll");
        close_fn cancel = (close_fn)dlsym(RTLD_DEFAULT, "ashell_pane_cancel");
        release_fn release = (release_fn)dlsym(RTLD_DEFAULT, "ashell_pane_release");
        for (;;) {
            if (server.cancel) { cancel(server.job); break; }
            struct pollfd fd = {server.fd, POLLIN, 0};
            poll(&fd, 1, 100);
            if (fd.revents & POLLIN) {
                char buffer[4096];
                ssize_t count = read(server.fd, buffer, sizeof buffer);
                if (count > 0) @synchronized (server) {
                    if (server.diagnostic.length < 8192)
                        [server.diagnostic appendBytes:buffer length:count];
                    NSData *marker = [@"ASHELL_TMUX_READY\n" dataUsingEncoding:NSUTF8StringEncoding];
                    if ([server.diagnostic rangeOfData:marker options:0 range:NSMakeRange(0, server.diagnostic.length)].location != NSNotFound)
                        server.ready = YES;
                }
            }
            int status;
            if (poll_child(server.job, &status) != 0) break;
        }
        release(server.job);
        close(server.fd);
        @synchronized (servers) {
            server.exited = YES;
            if (servers[socket] == server) [servers removeObjectForKey:socket];
        }
    });
    for (unsigned retry = 0; retry != 200; retry++) {
        if (server.ready) return 0;
        if (server.exited) break;
        usleep(25000);
    }
    @synchronized (server) {
        if (server.diagnostic.length)
            fwrite(server.diagnostic.bytes, 1, server.diagnostic.length, thread_stderr);
    }
    server.cancel = YES;
    return server.exited ? ECHILD : ETIMEDOUT;
}

static unsigned dimension(const char *name, unsigned fallback) {
    const char *value = ios_getenv(name);
    if (!value) return fallback;
    char *end;
    unsigned long n = strtoul(value, &end, 10);
    return *end || n < 1 || n > 9999 ? fallback : (unsigned)n;
}

static int write_all(int fd, const char *data, size_t size) {
    while (size) {
        ssize_t count = write(fd, data, size);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) return errno ? errno : EIO;
        data += count;
        size -= count;
    }
    return 0;
}

typedef struct client_cleanup {
    void *job;
    int fd;
    release_fn release;
    int previous_interactive;
} client_cleanup;

static void finish_client(void *cookie) {
    client_cleanup *client = cookie;
    client->release(client->job);
    close(client->fd);
    if (!client->previous_interactive) ios_stopInteractive();
}

__attribute__((visibility("default"))) int tmux_main(int argc, char **argv) {
    @autoreleasepool {
        static dispatch_once_t once;
        dispatch_once(&once, ^{ servers = [NSMutableDictionary new]; });
        BOOL nested = dlsym(RTLD_DEFAULT, "ashell_worker_spawn_ex") != NULL;
        NSBundle *app = nested ? [NSBundle bundleWithURL:NSBundle.mainBundle.bundleURL.URLByDeletingLastPathComponent.URLByDeletingLastPathComponent] : NSBundle.mainBundle;
        NSString *group = [app objectForInfoDictionaryKey:@"AppGroupIdentifier"];
        if (!group.length) { fprintf(thread_stderr, "tmux: shared App Group identifier unavailable\n"); return 1; }
        const char *prefix = nested ? "ashell_worker_" : "ashell_pane_";
        spawn_fn spawn = (spawn_fn)dlsym(RTLD_DEFAULT, [[NSString stringWithFormat:@"%sspawn_ex", prefix] UTF8String]);
        poll_fn poll_child = (poll_fn)dlsym(RTLD_DEFAULT, [[NSString stringWithFormat:@"%spoll", prefix] UTF8String]);
        resize_fn resize = (resize_fn)dlsym(RTLD_DEFAULT, [[NSString stringWithFormat:@"%sresize", prefix] UTF8String]);
        close_fn close_input = (close_fn)dlsym(RTLD_DEFAULT, [[NSString stringWithFormat:@"%sclose_stdin", prefix] UTF8String]);
        release_fn release = (release_fn)dlsym(RTLD_DEFAULT, [[NSString stringWithFormat:@"%srelease", prefix] UTF8String]);
        if (!spawn || !poll_child || !resize || !close_input || !release) {
            fprintf(thread_stderr, "tmux: interactive worker broker unavailable\n");
            return 1;
        }
        NSMutableArray<NSString *> *args = [NSMutableArray new], *server_options = [NSMutableArray new];
        NSString *socket = nil, *label = nil;
        BOOL no_start = NO, version = NO;
        int opt;
        optind = 1; optreset = 1; opterr = 0;
        while ((opt = getopt(argc, argv, "2c:CDdf:hlL:NqS:T:uUvV")) != -1) {
            const char *option_argument = optarg;
            NSString *argument = option_argument ? @(option_argument) : nil;
            if (!argument && strchr("cfLST", opt)) { fprintf(thread_stderr, "tmux: option -%c requires an argument\n", opt); return 1; }
            if (opt == 'D') { fprintf(thread_stderr, "tmux: the app owns server lifetime; -D is internal\n"); return 1; }
            if (opt == '?' || opt == ':') { fprintf(thread_stderr, "usage: tmux [-2CDNquvV] [-c shell-command] [-f file] [-L socket-name] [-S socket-path] [command [flags]]\n"); return 1; }
            if (opt == 'S') { socket = argument; continue; }
            if (opt == 'L') { label = argument; continue; }
            if (opt == 'N') { no_start = YES; continue; }
            version |= opt == 'V' || opt == 'h';
            NSString *flag = [NSString stringWithFormat:@"-%c", opt];
            [args addObject:flag];
            if (opt == 'f' || opt == 'T' || opt == 'c') [args addObject:argument];
            if (opt == 'f' || opt == 'v') {
                [server_options addObject:flag];
                if (opt == 'f') [server_options addObject:argument];
            }
        }
        // ios_system can reset getopt globals while sockets and environment are resolved.
        int command_start = optind;
        if (command_start < 1 || command_start > argc) { fprintf(thread_stderr, "tmux: argument parsing failed\n"); return 1; }
        for (int i = command_start; i < argc; i++) [args addObject:@(argv[i])];
        // Version/help are handled by the stock engine without resolving a socket.
        if (!version) {
            if (!socket && !label) {
                const char *inherited_socket = ios_getenv("TMUX");
                if (inherited_socket && *inherited_socket && *inherited_socket != ',')
                    socket = [@(inherited_socket) componentsSeparatedByString:@","][0];
            }
            if (!socket) {
                if (!label) label = @"default";
                if ([label containsString:@"/"] || [label isEqual:@"."] || [label isEqual:@".."]) return 1;
                const char *temporary = ios_getenv("TMUX_TMPDIR");
                NSString *root = temporary && *temporary ? @(temporary) : nil;
                if (!root) {
                    NSURL *container = group ? [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:group] : nil;
                    if (!container) {
                        fprintf(thread_stderr, "tmux: shared app group container unavailable\n"); return 1;
                    }
                    root = container.path;
                }
                NSString *directory = [root stringByAppendingPathComponent:@"tmux-ios"];
                NSError *error;
                if (![[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0700} error:&error]) {
                    fprintf(thread_stderr, "tmux: socket directory: %s\n", error.localizedDescription.UTF8String); return 1;
                }
                socket = [directory stringByAppendingPathComponent:label];
            }
            if (![socket isAbsolutePath]) {
                fprintf(thread_stderr, "tmux: socket requires an absolute path\n"); return 1;
            }
            if ([server_options containsObject:@"-v"])
                fprintf(thread_stderr, "tmux: socket path=%s bytes=%zu\n", socket.fileSystemRepresentation, strlen(socket.fileSystemRepresentation));
        }
        NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
        char **inherited = environmentVariables(ios_currentPid());
        NSMutableArray<NSString *> *values = [NSMutableArray new];
        for (size_t i = 0; inherited && inherited[i]; i++)
            if (strncmp(inherited[i], "TERM=", 5) && strncmp(inherited[i], "TERMINFO_DIRS=", 14) && strncmp(inherited[i], "ASHELL_REQUIRED_APP_GROUP=", 26) && strncmp(inherited[i], "ASHELL_TMUX_START=", 18)) [values addObject:@(inherited[i])];
        [values addObject:[@"ASHELL_REQUIRED_APP_GROUP=" stringByAppendingString:group]];
        [values addObject:@"TERM=xterm-256color"];
        Dl_info image;
        if (!dladdr((const void *)tmux_main, &image) || !image.dli_fname) return 1;
        NSString *terminfo = [[@(image.dli_fname) stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"terminfo"];
        const char *directories = ios_getenv("TERMINFO_DIRS");
        [values addObject:[NSString stringWithFormat:@"TERMINFO_DIRS=%@:%s", terminfo, directories ? directories : ""]];
        BOOL starts = !no_start && !version;
        TmuxServer *created = nil, *previous;
        @synchronized (servers) { previous = servers[socket]; }
        NSMutableString *command = version ? [NSMutableString stringWithString:@"tmux-native"] :
            [NSMutableString stringWithFormat:@"tmux-native -N -S %@", quote(socket)];
        for (NSString *arg in args) [command appendFormat:@" %@", quote(arg)];
        unsigned cols = dimension("COLUMNS", 80), rows = dimension("LINES", 24);
        for (unsigned attempt = 0; attempt < 2; attempt++) {
        const char **environment = calloc(values.count + 2, sizeof(*environment));
        if (!environment) return 1;
        for (NSUInteger i = 0; i < values.count; i++) environment[i] = values[i].UTF8String;
        if (starts) environment[values.count] = "ASHELL_TMUX_START=1";
        if (attempt) {
            if (nested) {
                fprintf(thread_stderr, "tmux: start a new server from the app terminal; workers may attach to existing servers\n");
                free(environment);
                return 1;
            }
            for (unsigned retry = 0; previous && !previous.exited && retry < 200; retry++) usleep(25000);
            if (previous && !previous.exited) { fprintf(thread_stderr, "tmux: previous server has not exited\n"); free(environment); return 1; }
            int error = start_server(socket, cwd, server_options, environment, &created);
            if (error) { fprintf(thread_stderr, "tmux: start server: %s\n", strerror(error)); free(environment); return 1; }
        }
        ashell_pane_options config = {.size = sizeof(config), .tty = ios_isatty(0)};
        void *job = NULL;
        int fd = -1;
        int error = spawn(command.UTF8String, cwd.UTF8String, cols, rows, environment, &config, &fd, &job);
        free(environment);
        if (error) {
            if (created) {
                created.cancel = YES;
                for (unsigned retry = 0; !created.exited && retry < 200; retry++) usleep(25000);
            }
            fprintf(thread_stderr, "tmux: client worker: %s%s\n", strerror(error), error == EACCES ? "; shared App Group membership required" : error == ENOSPC ? "; all shell workers are in use; close a pane or session first" : "");
            return 1;
        }
        int old_interactive = ios_storeInteractive();
        if (config.tty) ios_startInteractive();
        client_cleanup cleanup = {job, fd, release, old_interactive};
        BOOL eof = NO, output_eof = NO;
        int status = 1, result = 0;
        pthread_cleanup_push(finish_client, &cleanup);
        while (!output_eof || result == 0) {
            struct pollfd fds[] = {{output_eof ? -1 : fd, POLLIN, 0}, {eof ? -1 : fileno(thread_stdin), POLLIN, 0}};
            int ready = poll(fds, 2, 20);
            if (ready < 0 && errno != EINTR) break;
            char buffer[16384];
            if (fds[0].revents & (POLLIN|POLLHUP)) {
                ssize_t n = read(fd, buffer, sizeof buffer);
                if (n <= 0) output_eof = YES;
                else if (write_all(fileno(thread_stdout), buffer, n)) break;
            }
            if (fds[1].revents & (POLLIN|POLLHUP)) {
                ssize_t n = read(fileno(thread_stdin), buffer, sizeof buffer);
                if (n <= 0) { eof = YES; close_input(job); }
                else if (write_all(fd, buffer, n)) break;
            }
            unsigned x = dimension("COLUMNS", cols), y = dimension("LINES", rows);
            if (x != cols || y != rows) {
                int resize_error = resize(job, x, y);
                if (resize_error && (resize_error != ESRCH || poll_child(job, &status) != 1)) {
                    fprintf(thread_stderr, "tmux: resize: %s\n", strerror(resize_error)); break;
                }
                cols = x; rows = y;
            }
            result = poll_child(job, &status);
            if (result < 0) break;
        }
        pthread_cleanup_pop(1);
        if (result == 1 && status == ASHELL_TMUX_NO_SERVER && starts && attempt == 0) continue;
        return result == 1 ? (status == ASHELL_TMUX_NO_SERVER ? 1 : status) : 1;
        }
        return 1;
    }
}
