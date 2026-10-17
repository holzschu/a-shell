#import "PaneWire.h"
#import "ios_system/ios_system.h"
#include "NativePane.h"
#include <unistd.h>
#include <stdlib.h>
#include <stdatomic.h>
#include <dirent.h>
#include <fcntl.h>
#include <locale.h>
#include <signal.h>

// ios_system discovers these stock host callbacks with dlsym. Each extension
// owns one shell; its socket already carries input directly to the command.
static atomic_bool interactive_input;
__attribute__((used)) void startInteractive(void) { atomic_store(&interactive_input, true); }
__attribute__((used)) void stopInteractive(void) { atomic_store(&interactive_input, false); }
__attribute__((used)) int storeInteractive(void) { return atomic_load(&interactive_input); }

// The stock host clear command calls its UIKit delegate. Workers clear through
// the terminal stream, just like an external terminal command.
__attribute__((used)) int clear(int argc, char **argv) {
    if (!thread_stdout) return 1;
    return fputs("\033[H\033[2J", thread_stdout) == EOF || fflush(thread_stdout) == EOF ? 1 : 0;
}

static int check_directory(NSURL *url) {
    DIR *directory = opendir(url.fileSystemRepresentation);
    if (!directory) return errno;
    return closedir(directory) == 0 ? 0 : errno;
}

static int check_documents_write(NSURL *documents, NSString *probe) {
    NSString *parent = probe.stringByDeletingLastPathComponent.stringByResolvingSymlinksInPath;
    if (![parent isEqualToString:documents.path.stringByResolvingSymlinksInPath] ||
        ![probe.lastPathComponent hasPrefix:@".ashell-worker-access."]) return EINVAL;
    int directory = open(probe.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (directory < 0) return errno;
    int fd = openat(directory, "capability", O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (fd < 0) { int code = errno; close(directory); return code; }
    const char expected = 'H';
    char observed = 0;
    int code = 0;
    if (write(fd, &expected, 1) != 1) code = errno ? errno : EIO;
    else if (lseek(fd, 0, SEEK_SET) < 0) code = errno;
    else if (read(fd, &observed, 1) != 1) code = errno ? errno : EIO;
    else if (observed != expected) code = EIO;
    if (close(fd) && !code) code = errno;
    if (unlinkat(directory, "capability", 0) && !code) code = errno;
    if (close(directory) && !code) code = errno;
    return code;
}

@interface PaneService : NSObject <AShellPaneWire>
@end

@implementation PaneService {
    void *_pane;
    NSMutableArray<NSURL *> *_directories;
}
- (void)spawn:(NSString *)command cwd:(NSData *)cwd home:(NSData *)home documents:(NSData *)documents probe:(NSString *)probe env:(NSArray<NSString *> *)env cols:(unsigned)cols rows:(unsigned)rows reply:(void (^)(int, NSFileHandle *, int))reply {
    if (_pane) { reply(EBUSY, nil, getpid()); return; }
    if (!cwd || !home || !documents || !probe) { reply(EINVAL, nil, getpid()); return; }
    // Resolve the host's ephemeral grants explicitly and retain them for this
    // pane, including HOME for shared command configuration and authentication.
    _directories = [NSMutableArray array];
    NSURL *directory = nil;
    NSURL *documentsURL = nil;
    NSMutableArray<NSURL *> *resolved = [NSMutableArray array];
    unsigned index = 0;
    NSLog(@"Shell worker sandbox: real_pid=%d own_home=%@", getpid(), NSHomeDirectory());
    for (NSData *bookmark in @[home, documents, cwd]) {
        NSError *failure = nil;
        BOOL stale = NO;
        NSURL *url = [NSURL URLByResolvingBookmarkData:bookmark
            options:NSURLBookmarkResolutionWithoutUI | NSURLBookmarkResolutionWithoutImplicitStartAccessing
            relativeToURL:nil bookmarkDataIsStale:&stale error:&failure];
        if (!url) {
            NSLog(@"Shell worker directory bookmark failed: %@", failure);
            [self releasePane];
            reply([failure.domain isEqualToString:NSPOSIXErrorDomain] ? (int)failure.code : EIO, nil, getpid());
            return;
        }
        BOOL scoped = [url startAccessingSecurityScopedResource];
        if (scoped) [_directories addObject:url];
        NSLog(@"Shell worker directory: index=%u url=%@ stale=%d scoped=%d", index, url.path, stale, scoped);
        [resolved addObject:url];
        if (index == 1) documentsURL = url;
        index++;
        directory = url;
    }
    int readError = 0;
    for (NSURL *url in resolved) {
        int code = check_directory(url);
        NSLog(@"Shell worker directory capability: url=%@ read_error=%d", url.path, code);
        if (code && !readError) readError = code;
    }
    if (readError) { [self releasePane]; reply(readError, nil, getpid()); return; }
    int capabilityError = check_documents_write(documentsURL, probe);
    NSLog(@"Shell worker Documents capability: real_pid=%d read_write_error=%d", getpid(), capabilityError);
    if (capabilityError) { [self releasePane]; reply(capabilityError, nil, getpid()); return; }
    // ios_system globals are private to this extension. The adapter keeps its
    // original dedicated pthread and stream ownership/cleanup barrier.
    NSString *temporaryDirectory = NSTemporaryDirectory();
    if (!temporaryDirectory.length) { [self releasePane]; reply(EIO, nil, getpid()); return; }
    // The host's directory bookmark does not grant its tmp directory. Keep the
    // extension's stock Foundation/libc temp domain in both environment views.
    NSMutableArray<NSString *> *environment = [NSMutableArray arrayWithCapacity:env.count + 1];
    for (NSString *value in env)
        if (![value hasPrefix:@"TMPDIR="]) [environment addObject:value];
    [environment addObject:[@"TMPDIR=" stringByAppendingString:temporaryDirectory]];
    env = environment;
    initializeEnvironment();
    replaceCommand(@"clear", @"clear", true);
    // This process owns exactly one shell. Native Rust clients enumerate libc's
    // environment as well as ios_system's forked command environment.
    for (NSString *value in env) {
        NSRange separator = [value rangeOfString:@"="];
        if (separator.location == NSNotFound || separator.location == 0) { [self releasePane]; reply(EINVAL, nil, getpid()); return; }
        if (setenv([value substringToIndex:separator.location].UTF8String,
                   [value substringFromIndex:separator.location + 1].UTF8String, 1)) { int error = errno; [self releasePane]; reply(error, nil, getpid()); return; }
    }
    // Match stock SceneDelegate before libedit decodes Unicode or measures it.
    if (setenv("LC_CTYPE", "UTF-8", 1)) { int error = errno; [self releasePane]; reply(error, nil, getpid()); return; }
    const char *locale = setlocale(LC_CTYPE, "UTF-8");
    if (!locale) { [self releasePane]; reply(EINVAL, nil, getpid()); return; }
    NSLog(@"Shell worker locale: real_pid=%d ctype=%s", getpid(), locale);
    // The physical device has no kernel tty. Use the same socket-backed route
    // on Simulator so its acceptance cannot pass through a desktop-only PTY.
    if (setenv("ASHELL_IOS_PTY", "0", 1)) { int error = errno; [self releasePane]; reply(error, nil, getpid()); return; }
    const char **values = calloc(env.count + 4, sizeof(char *));
    if (!values) { [self releasePane]; reply(ENOMEM, nil, getpid()); return; }
    for (NSUInteger i = 0; i < env.count; i++)
        values[i] = [env[i] hasPrefix:@"ASHELL_IOS_PTY="] ? "ASHELL_IOS_PTY=0" :
            [env[i] hasPrefix:@"LC_CTYPE="] ? "LC_CTYPE=UTF-8" : env[i].UTF8String;
    NSString *identity = [NSString stringWithFormat:@"ASHELL_WORKER_PID=%d", getpid()];
    values[env.count] = identity.UTF8String;
    values[env.count + 1] = "LC_CTYPE=UTF-8";
    values[env.count + 2] = "ASHELL_IOS_SOCKET_INPUT=1";
    int fd = -1;
    int error = ashell_pane_spawn(command.UTF8String, directory.path.UTF8String, cols, rows, values, &fd, &_pane);
    free(values);
    if (error) [self releasePane];
    NSFileHandle *handle = error ? nil : [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
    reply(error, handle, getpid());
}
- (void)poll:(void (^)(int, int))reply {
    int status = 0;
    int result = _pane ? ashell_pane_poll(_pane, &status) : -ESRCH;
    reply(result, status);
}
- (void)resize:(unsigned)cols rows:(unsigned)rows reply:(void (^)(int))reply {
    reply(_pane ? ashell_pane_resize(_pane, cols, rows) : ESRCH);
}
- (void)closeInput:(void (^)(int))reply { reply(_pane ? ashell_pane_close_stdin(_pane) : ESRCH); }
- (void)interrupt:(void (^)(int))reply {
    // Stream-backed TUIs have no kernel termios state. ENOTSUP sends the ETX
    // byte through the existing host input path instead of cancelling a thread.
    if (atomic_load(&interactive_input)) { reply(ENOTSUP); return; }
    reply(_pane ? ashell_pane_interrupt(_pane) : ESRCH);
}
- (void)releasePane {
    if (_pane) ashell_pane_release(_pane);
    _pane = NULL;
    for (NSURL *directory in _directories) [directory stopAccessingSecurityScopedResource];
    _directories = nil;
}
- (void)terminate:(void (^)(void))reply {
    // AppExtensionProcess.invalidate releases the host's assertion but permits
    // process reuse. End this dedicated worker even if its command ignores EOF.
    // ios_system interposes exit/_exit; SIGKILL reaches the OS process directly.
    // Do not acknowledge before death: the host's synchronous XPC call returns
    // through its error handler only after the old worker can no longer run.
    kill(getpid(), SIGKILL);
}
- (void)dealloc { [self releasePane]; }
@end

NSObject<AShellPaneWire> *ashell_worker_service(void) { return [PaneService new]; }
