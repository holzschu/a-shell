// Prepare shared Codex state before starting the command runtime.
#import <Foundation/Foundation.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>

static NSString *home_env(const char *const env[], const char *name) {
    size_t length = strlen(name);
    for (size_t i = 0; env[i]; i++) {
        if (!strncmp(env[i], name, length) && env[i][length] == '=') {
            return [NSString stringWithUTF8String:env[i] + length + 1];
        }
    }
    return nil;
}

static int home_error(NSError *error) {
    if ([error.domain isEqualToString:NSPOSIXErrorDomain] && error.code > 0) return (int)error.code;
    NSError *underlying = error.userInfo[NSUnderlyingErrorKey];
    return underlying ? home_error(underlying) : EIO;
}

static int writable_home(NSString *path) {
    struct stat info;
    if (stat(path.fileSystemRepresentation, &info)) return errno;
    if (!S_ISDIR(info.st_mode)) return ENOTDIR;
    char *probe = strdup([path stringByAppendingPathComponent:@".prepare-XXXXXX"].fileSystemRepresentation);
    if (!probe) return ENOMEM;
    int fd = mkstemp(probe);
    int error = fd < 0 ? errno : 0;
    if (fd >= 0) {
        if (unlink(probe)) error = errno;
        if (close(fd) && !error) error = errno;
    }
    free(probe);
    return error;
}

static void close_home_lock(void *context) {
    close(*(int *)context);
}

// 0 on success; positive POSIX errno otherwise. Never alter env or process state.
int codex_ios_prepare_home(const char *const env[]) {
    if (!env) return EINVAL;
    @autoreleasepool {
        NSString *explicitHome = home_env(env, "CODEX_HOME");
        if (explicitHome.length) return writable_home(explicitHome);
        NSString *group = home_env(env, "GROUP");
        if (!group.length) return ENOENT;
        struct stat info;
        if (stat(group.fileSystemRepresentation, &info)) return errno;
        if (!S_ISDIR(info.st_mode)) return ENOTDIR;
        NSString *library = [group stringByAppendingPathComponent:@"Library"];
        NSString *shared = [library stringByAppendingPathComponent:@"codex"];
        // Extension workers must never inspect the host's private login directory.
        if ([NSBundle.mainBundle.bundlePath.pathExtension isEqualToString:@"appex"]) {
            if (stat(shared.fileSystemRepresentation, &info)) return errno == ENOENT ? ENXIO : errno;
            return writable_home(shared);
        }
        NSFileManager *fm = NSFileManager.defaultManager;
        NSError *error = nil;
        if (![fm createDirectoryAtPath:library withIntermediateDirectories:YES attributes:nil error:&error]) return home_error(error);
        NSString *lockPath = [library stringByAppendingPathComponent:@".codex-migration.lock"];
        int lock = open(lockPath.fileSystemRepresentation, O_CREAT | O_RDWR | O_CLOEXEC, 0600);
        if (lock < 0) return errno;
        int result = 0;
        pthread_cleanup_push(close_home_lock, &lock);
        while (flock(lock, LOCK_EX)) {
            if (errno == EINTR) continue;
            result = errno;
            break;
        }
        if (!result && stat(shared.fileSystemRepresentation, &info)) {
            result = errno;
            if (result == ENOENT) {
                NSString *host = home_env(env, "HOME");
                if (!host.length) result = ENOENT;
                else {
                    NSString *legacy = [host stringByAppendingPathComponent:@"Library/codex"];
                    NSString *stage = [library stringByAppendingPathComponent:[@".codex-stage-" stringByAppendingString:NSUUID.UUID.UUIDString]];
                    if (!stat(legacy.fileSystemRepresentation, &info)) {
                        result = S_ISDIR(info.st_mode) ? 0 : ENOTDIR;
                        if (!result && ![fm copyItemAtPath:legacy toPath:stage error:&error]) result = home_error(error);
                    } else if (errno == ENOENT) {
                        result = [fm createDirectoryAtPath:stage withIntermediateDirectories:NO attributes:nil error:&error] ? 0 : home_error(error);
                    } else result = errno;
                    if (!result && rename(stage.fileSystemRepresentation, shared.fileSystemRepresentation)) result = errno;
                    if (result) [fm removeItemAtPath:stage error:NULL];
                }
            }
        }
        if (!result) result = writable_home(shared);
        // close releases flock before any model or tool execution begins.
        pthread_cleanup_pop(0);
        if (close(lock) && !result) result = errno;
        return result;
    }
}
