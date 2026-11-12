#import "PaneWire.h"
#import "HostPane.h"
#include "NativePane.h"
#include <errno.h>
#include <dirent.h>
#include <fcntl.h>
#include <poll.h>
#include <stdatomic.h>
#include <unistd.h>

extern void ashell_extension_connect(void (^)(NSXPCConnection *, NSError *));
extern void ashell_extension_disconnect(NSXPCConnection *);
extern void ashell_extension_observe(NSXPCConnection *, pid_t);
extern int ashell_extension_capacity(void);

static void log_host_library(const char *phase) {
    int saved = errno;
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library"];
    DIR *directory = opendir(path.fileSystemRepresentation);
    int error = directory ? 0 : errno;
    if (directory && closedir(directory)) error = errno;
    NSLog(@"Shell host Library capability: phase=%s path=%@ read_error=%d", phase, path, error);
    errno = saved;
}

@interface RemotePane : NSObject
@property(nonatomic, strong) NSXPCConnection *connection;
@property(nonatomic, strong) id<AShellPaneWire> proxy;
@property(nonatomic, strong) NSFileHandle *output;
@property(nonatomic, strong) NSFileHandle *errorOutput;
@property(atomic) BOOL interrupted;
@property(atomic) BOOL cancelled;
@property(nonatomic, strong) NSMutableArray<NSURL *> *directories;
@property(nonatomic, copy) NSString *probeDirectory;
@end
@implementation RemotePane
- (void)dealloc {
    [_output closeAndReturnError:NULL];
    [_errorOutput closeAndReturnError:NULL];
    // Only remove our empty disposable directory, never a project tree.
    if (_probeDirectory) rmdir(_probeDirectory.fileSystemRepresentation);
    log_host_library("before_scope_release");
    for (NSURL *url in _directories) {
        [url stopAccessingSecurityScopedResource];
        NSLog(@"Shell host directory scope: phase=release url=%@", url.path);
    }
    log_host_library("after_scope_release");
}
@end

// A connection owns its descendants; invalidation releases the whole subtree.
@interface BrokerChild : NSObject
@property(nonatomic) void *job;
@property(nonatomic) BOOL host;
@end
@implementation BrokerChild
- (void)dealloc { if (_job) { if (_host) ashell_host_pane_release(_job); else ashell_pane_release(_job); } }
@end

@interface SpawnBroker : NSObject <AShellSpawnBrokerWire>
@property(nonatomic, strong) NSMutableDictionary<NSString *, BrokerChild *> *children;
@end
@implementation SpawnBroker
- (instancetype)init {
    if ((self = [super init])) _children = [NSMutableDictionary new];
    return self;
}
- (void)spawnChild:(NSString *)command cwd:(NSString *)cwd env:(NSArray<NSString *> *)env cols:(unsigned)cols rows:(unsigned)rows tty:(BOOL)tty separateStderr:(BOOL)separate reply:(void (^)(int, NSString *, NSFileHandle *, NSFileHandle *))reply {
    [self spawn:command cwd:cwd env:env cols:cols rows:rows tty:tty separateStderr:separate host:NO reply:reply];
}
- (void)spawnHostChild:(NSString *)command cwd:(NSString *)cwd env:(NSArray<NSString *> *)env cols:(unsigned)cols rows:(unsigned)rows tty:(BOOL)tty separateStderr:(BOOL)separate reply:(void (^)(int, NSString *, NSFileHandle *, NSFileHandle *))reply {
    [self spawn:command cwd:cwd env:env cols:cols rows:rows tty:tty separateStderr:separate host:YES reply:reply];
}
- (void)spawn:(NSString *)command cwd:(NSString *)cwd env:(NSArray<NSString *> *)env cols:(unsigned)cols rows:(unsigned)rows tty:(BOOL)tty separateStderr:(BOOL)separate host:(BOOL)host reply:(void (^)(int, NSString *, NSFileHandle *, NSFileHandle *))reply {
    const char **values = calloc(env.count + 2, sizeof(*values));
    if (!values) { reply(ENOMEM, nil, nil, nil); return; }
    NSUInteger count = 0;
    for (NSString *value in env) {
        if (host && ([value hasPrefix:@"ASHELL_WORKER_PID="] || [value hasPrefix:@"ASHELL_WORKER_ROOT_PID="] || [value hasPrefix:@"TMPDIR="])) continue;
        values[count++] = value.UTF8String;
    }
    NSString *temporary = host ? [@"TMPDIR=" stringByAppendingString:NSTemporaryDirectory()] : nil;
    if (temporary) values[count++] = temporary.UTF8String;
    int fd = -1;
    BrokerChild *child = [BrokerChild new];
    child.host = host;
    ashell_pane_options options = { .size = sizeof(options), .tty = tty, .separate_stderr = separate };
    void *job = NULL;
    int error = (host ? ashell_host_pane_spawn_ex : ashell_pane_spawn_ex)(command.UTF8String, cwd.fileSystemRepresentation, cols, rows, values, &options, &fd, &job);
    free(values);
    if (error) { reply(error, nil, nil, nil); return; }
    child.job = job;
    NSString *token = NSUUID.UUID.UUIDString;
    @synchronized (self) { self.children[token] = child; }
    NSFileHandle *output = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
    NSFileHandle *errors = options.stderr_fd >= 0 ? [[NSFileHandle alloc] initWithFileDescriptor:options.stderr_fd closeOnDealloc:YES] : nil;
    reply(0, token, output, errors);
}
- (BrokerChild *)child:(NSString *)token { @synchronized (self) { return self.children[token]; } }
- (void)pollChild:(NSString *)token reply:(void (^)(int, int))reply {
    [self pollChildUsage:token reply:^(int result, int status, NSData *usage) { reply(result, status); }];
}
- (void)pollChildUsage:(NSString *)token reply:(void (^)(int, int, NSData *))reply {
    BrokerChild *child = [self child:token];
    int status = 0;
    int available = 0;
    struct rusage usage;
    int result = child ? (child.host ? ashell_host_pane_poll_usage : ashell_pane_poll_usage)(child.job, &status, &usage, &available) : -ESRCH;
    reply(result, status, result == 1 && available ? [NSData dataWithBytes:&usage length:sizeof(usage)] : nil);
}
- (void)closeChildInput:(NSString *)token reply:(void (^)(int))reply {
    BrokerChild *child = [self child:token];
    reply(child ? (child.host ? ashell_host_pane_close_stdin : ashell_pane_close_stdin)(child.job) : ESRCH);
}
- (void)cancelChild:(NSString *)token reply:(void (^)(int))reply {
    BrokerChild *child = [self child:token];
    reply(child ? (child.host ? ashell_host_pane_cancel : ashell_pane_cancel)(child.job) : ESRCH);
}
- (void)resizeChild:(NSString *)token cols:(unsigned)cols rows:(unsigned)rows reply:(void (^)(int))reply {
    BrokerChild *child = [self child:token];
    reply(child ? (child.host ? ashell_host_pane_resize : ashell_pane_resize)(child.job, cols, rows) : ESRCH);
}
- (void)interruptChild:(NSString *)token reply:(void (^)(int))reply {
    BrokerChild *child = [self child:token];
    reply(child ? (child.host ? ashell_host_pane_interrupt : ashell_pane_interrupt)(child.job) : ESRCH);
}
- (void)releaseChild:(NSString *)token { @synchronized (self) { [self.children removeObjectForKey:token]; } }
@end



int ashell_pane_capacity(void) { return ashell_extension_capacity(); }

int ashell_pane_spawn(const char *command, const char *cwd, unsigned cols, unsigned rows, const char *const *envp, int *fd_out, void **job_out) {
    ashell_pane_options options = {.size = sizeof(options), .tty = 1};
    return ashell_pane_spawn_ex(command, cwd, cols, rows, envp, &options, fd_out, job_out);
}
int ashell_pane_spawn_ex(const char *command, const char *cwd, unsigned cols, unsigned rows, const char *const *envp, ashell_pane_options *options, int *fd_out, void **job_out) {
    if (fd_out) *fd_out = -1;
    if (job_out) *job_out = NULL;
    if (!options || options->size < sizeof(*options)) return EINVAL;
    options->stderr_fd = -1;
    if (!command || !cwd || !fd_out || !job_out || !cols || !rows) return EINVAL;
    if (NSThread.isMainThread) return EDEADLK;
    @autoreleasepool {
        NSString *home = NSHomeDirectory();
        for (size_t i = 0; envp && envp[i]; i++)
            if (!strncmp(envp[i], "HOME=", 5)) home = @(envp[i] + 5);
        RemotePane *pane = [RemotePane new];
        pane.directories = [NSMutableArray array];
        NSURL *homeURL = [NSURL fileURLWithPath:home isDirectory:YES];
        NSURL *documentsURL = [homeURL URLByAppendingPathComponent:@"Documents" isDirectory:YES];
        NSURL *cwdURL = [NSURL fileURLWithPath:@(cwd) isDirectory:YES];
        log_host_library("before_scope_acquire");
        NSString *container = NSHomeDirectory().stringByResolvingSymlinksInPath;
        NSString *containerPrefix = [container stringByAppendingString:@"/"];
        for (NSURL *url in @[homeURL, documentsURL, cwdURL]) {
            NSString *path = url.path.stringByResolvingSymlinksInPath;
            // The host's own container needs no dynamic grant. Only external
            // bookmarked folders belong to this pane's scope lifetime.
            BOOL owned = [path isEqualToString:container] || [path hasPrefix:containerPrefix];
            BOOL acquired = !owned && [url startAccessingSecurityScopedResource];
            if (acquired) [pane.directories addObject:url];
            NSLog(@"Shell host directory scope: phase=acquire url=%@ own_container=%d acquired=%d", path, owned, acquired);
        }
        log_host_library("after_scope_acquire");
        NSError *bookmarkFailure = nil;
        // Default bookmarks carry Foundation's implicit ephemeral sandbox scope.
        // A pathname alone grants no access to the containing app's private files.
        NSData *cwdBookmark = [cwdURL
            bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:&bookmarkFailure];
        NSData *homeBookmark = cwdBookmark ? [homeURL
            bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:&bookmarkFailure] : nil;
        NSData *documentsBookmark = homeBookmark ? [documentsURL
            bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:&bookmarkFailure] : nil;
        if (!cwdBookmark || !homeBookmark || !documentsBookmark) {
            NSLog(@"Shell pane directory bookmark failed: %@", bookmarkFailure);
            return [bookmarkFailure.domain isEqualToString:NSPOSIXErrorDomain] ? (int)bookmarkFailure.code : EIO;
        }
        // A real create/read/unlink in this host-owned disposable directory proves
        // the worker capability; bookmark resolution or access(W_OK) alone does not.
        NSString *template = [documentsURL.path stringByAppendingPathComponent:@".ashell-worker-access.XXXXXX"];
        char *probe = strdup(template.fileSystemRepresentation);
        if (!probe) return ENOMEM;
        if (!mkdtemp(probe)) { int code = errno; free(probe); return code; }
        pane.probeDirectory = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:probe length:strlen(probe)];
        free(probe);
        NSTimeInterval started = NSProcessInfo.processInfo.systemUptime;
        dispatch_semaphore_t ready = dispatch_semaphore_create(0);
        __block int error = 0;
        ashell_extension_connect(^(NSXPCConnection *connection, NSError *failure) {
            pane.connection = connection;
            // ExtensionFoundation and Cocoa error numbers are not POSIX errno.
            // In particular, framework code 1 must not masquerade as EPERM.
            error = failure ? ([failure.domain isEqualToString:NSPOSIXErrorDomain] ? (int)failure.code : EIO) : 0;
            if (failure) NSLog(@"Shell extension launch failed: %@", failure);
            dispatch_semaphore_signal(ready);
        });
        dispatch_semaphore_wait(ready, DISPATCH_TIME_FOREVER);
        if (error) return error;
        __weak RemotePane *weak = pane;
        pane.connection.interruptionHandler = ^{ weak.interrupted = YES; };
        pane.connection.invalidationHandler = ^{ weak.interrupted = YES; };
        pane.connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(AShellPaneWire)];
        [pane.connection resume];
        pane.proxy = [pane.connection synchronousRemoteObjectProxyWithErrorHandler:^(NSError *failure) { error = EPIPE; }];
        NSMutableArray *env = [NSMutableArray array];
        for (size_t i = 0; envp && envp[i]; i++) [env addObject:@(envp[i])];
        __block int fd = -1, err_fd = -1;
        BOOL separate = options->separate_stderr != 0;
        [pane.proxy spawn:@(command) cwd:cwdBookmark home:homeBookmark documents:documentsBookmark probe:pane.probeDirectory env:env cols:cols rows:rows tty:options->tty != 0 separateStderr:separate reply:^(int code, NSFileHandle *handle, NSFileHandle *errorHandle, int pid) {
            ashell_extension_observe(pane.connection, pid);
            error = code;
            if (!code && (!handle || (separate && !errorHandle))) error = EPROTO;
            if (!error) {
                fd = dup(handle.fileDescriptor);
                if (fd < 0) error = errno;
                else if (fcntl(fd, F_SETFD, FD_CLOEXEC)) { error = errno; close(fd); fd = -1; }
                else pane.output = handle;
            }
            if (!error && separate) {
                err_fd = dup(errorHandle.fileDescriptor);
                if (err_fd < 0) error = errno;
                else if (fcntl(err_fd, F_SETFD, FD_CLOEXEC)) { error = errno; close(err_fd); err_fd = -1; }
                else pane.errorOutput = errorHandle;
                if (error && fd >= 0) { close(fd); fd = -1; }
            }
            NSLog(@"Shell extension spawn: real_pid=%d error=%d startup_ms=%.3f", pid, error, (NSProcessInfo.processInfo.systemUptime - started) * 1000);
        }];
        if (rmdir(pane.probeDirectory.fileSystemRepresentation) == 0) pane.probeDirectory = nil;
        if (!error && fd < 0) error = EPROTO;
        if (error) {
            int spawnError = error;
            [pane.proxy terminate:^{}];
            ashell_extension_disconnect(pane.connection);
            return spawnError;
        }
        *fd_out = fd;
        options->stderr_fd = err_fd;
        *job_out = (__bridge_retained void *)pane;
        return 0;
    }
}
int ashell_pane_poll(void *job, int *status_out) {
    return ashell_pane_poll_usage(job, status_out, NULL, NULL);
}
int ashell_pane_poll_usage(void *job, int *status_out, struct rusage *usage_out, int *usage_available) {
    if (usage_available) *usage_available = 0;
    RemotePane *pane = (__bridge RemotePane *)job;
    if (!pane || !status_out) return -EINVAL;
    if (pane.cancelled) { *status_out = 137; return 1; }
    if (pane.interrupted) return -EPIPE;
    // The worker closes its socket streams before publishing completion. A
    // hangup is observable even with unread output; keep polling local until
    // then instead of waking the worker with an XPC request on every poll.
    struct pollfd output = {.fd = pane.output.fileDescriptor, .events = POLLIN};
    int ready = poll(&output, 1, 0);
    if (ready < 0) return errno == EINTR ? 0 : -errno;
    if (output.revents & POLLNVAL) return -EBADF;
    if (!(output.revents & (POLLHUP | POLLERR))) return 0;
    __block int result = -EPIPE;
    [pane.proxy pollUsage:^(int value, int status, NSData *usage) {
        result = value;
        *status_out = status;
        if (value == 1 && usage.length == sizeof(struct rusage)) {
            if (usage_out) memcpy(usage_out, usage.bytes, sizeof(struct rusage));
            if (usage_available) *usage_available = 1;
        }
    }];
    if (result == -EPIPE) pane.interrupted = YES;
    return result;
}
int ashell_pane_resize(void *job, unsigned cols, unsigned rows) {
    RemotePane *pane = (__bridge RemotePane *)job;
    if (!pane || pane.interrupted) return ESRCH;
    __block int result = EPIPE;
    [pane.proxy resize:cols rows:rows reply:^(int error) { result = error; }];
    return result;
}
int ashell_pane_close_stdin(void *job) {
    RemotePane *pane = (__bridge RemotePane *)job;
    if (!pane || pane.interrupted) return ESRCH;
    __block int result = EPIPE;
    [pane.proxy closeInput:^(int error) { result = error; }];
    return result;
}
int ashell_pane_interrupt(void *job) {
    RemotePane *pane = (__bridge RemotePane *)job;
    if (!pane || pane.interrupted) return ESRCH;
    __block int result = EPIPE;
    [pane.proxy interrupt:^(int error) { result = error; }];
    return result;
}
int ashell_pane_cancel(void *job) {
    RemotePane *pane = (__bridge RemotePane *)job;
    if (!pane) return EINVAL;
    pane.cancelled = YES;
    pane.interrupted = YES;
    [pane.proxy terminate:^{}];
    ashell_extension_disconnect(pane.connection);
    return 0;
}
void ashell_pane_release(void *job) {
    if (!job) return;
    RemotePane *pane = (__bridge_transfer RemotePane *)job;
    [pane.proxy releasePane];
    [pane.proxy terminate:^{}];
    ashell_extension_disconnect(pane.connection);
}

NSObject<AShellSpawnBrokerWire> *ashell_spawn_broker(void) { return [SpawnBroker new]; }
