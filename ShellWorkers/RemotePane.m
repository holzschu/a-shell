#import "PaneWire.h"
#include "NativePane.h"
#include <errno.h>
#include <dirent.h>
#include <fcntl.h>
#include <stdatomic.h>
#include <unistd.h>

extern void ashell_extension_connect(void (^)(NSXPCConnection *, NSError *));
extern void ashell_extension_disconnect(NSXPCConnection *);

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
@property(atomic) BOOL interrupted;
@property(nonatomic, strong) NSMutableArray<NSURL *> *directories;
@property(nonatomic, copy) NSString *probeDirectory;
@end
@implementation RemotePane
- (void)dealloc {
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

int ashell_pane_spawn(const char *command, const char *cwd, unsigned cols, unsigned rows, const char *const *envp, int *fd_out, void **job_out) {
    if (fd_out) *fd_out = -1;
    if (job_out) *job_out = NULL;
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
        __block int fd = -1;
        [pane.proxy spawn:@(command) cwd:cwdBookmark home:homeBookmark documents:documentsBookmark probe:pane.probeDirectory env:env cols:cols rows:rows reply:^(int code, NSFileHandle *handle, int pid) {
            error = code;
            if (!code && !handle) error = EPROTO;
            if (!error) {
                fd = dup(handle.fileDescriptor);
                if (fd < 0) error = errno;
                else if (fcntl(fd, F_SETFD, FD_CLOEXEC)) { error = errno; close(fd); fd = -1; }
            }
            NSLog(@"Shell extension spawn: real_pid=%d error=%d startup_ms=%.3f", pid, error, (NSProcessInfo.processInfo.systemUptime - started) * 1000);
        }];
        if (rmdir(pane.probeDirectory.fileSystemRepresentation) == 0) pane.probeDirectory = nil;
        if (!error && fd < 0) error = EPROTO;
        if (error) { ashell_extension_disconnect(pane.connection); return error; }
        *fd_out = fd;
        *job_out = (__bridge_retained void *)pane;
        return 0;
    }
}
int ashell_pane_poll(void *job, int *status_out) {
    RemotePane *pane = (__bridge RemotePane *)job;
    if (!pane || !status_out) return -EINVAL;
    // 137 is this backend's lost-worker status, not a recovered waitpid status.
    if (pane.interrupted) { *status_out = 137; return 1; }
    __block int result = -EPIPE;
    [pane.proxy poll:^(int value, int status) { result = value; *status_out = status; }];
    if (result == -EPIPE) { pane.interrupted = YES; *status_out = 137; return 1; }
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
