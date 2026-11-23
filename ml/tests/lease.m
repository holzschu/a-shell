#import "AShellMLInstall.h"
#include <stdio.h>
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
int main(void) { @autoreleasepool {
    NSError *error = nil;
    for (NSUInteger limit = 1; limit <= 3; limit += 2) {
        __block NSUInteger polls = 0;
        NSDictionary *cancelled = ASMLAcquireVersion(@"mnist", ^NSError *{
            return ++polls >= limit ? [NSError errorWithDomain:@"AShellML" code:130 userInfo:nil] : nil;
        }, &error);
        if (cancelled || error.code != 130 || polls < limit) { fprintf(stderr, "Lease verification cancellation lost\n"); return 1; }
        error = nil;
    }
    NSDictionary *receipt = ASMLAcquireVersion(@"mnist", nil, &error);
    if (!receipt) { fprintf(stderr, "%s\n", error.localizedDescription.UTF8String); return 1; }
    NSData *data = [NSJSONSerialization dataWithJSONObject:receipt options:0 error:nil];
    puts([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding].UTF8String); fflush(stdout);
    while (getchar() != EOF) {}
    NSString *lock = [[receipt[@"path"] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@".install-lock"];
    int fd = open(lock.fileSystemRepresentation, O_RDONLY); if (fd < 0 || flock(fd, LOCK_SH | LOCK_NB)) return 1;
    double started = NSProcessInfo.processInfo.systemUptime;
    ASMLReleaseVersion(receipt[@"lease_id"]);
    double elapsed = NSProcessInfo.processInfo.systemUptime - started;
    close(fd);
    if (elapsed > 0.25) { fprintf(stderr, "Best-effort lease collection blocked for %.3f seconds\n", elapsed); return 1; }
    // A later uncontended release collects any version deferred by the lock.
    NSDictionary *next = ASMLAcquireVersion(@"mnist", nil, &error); if (!next) return 1;
    ASMLReleaseVersion(next[@"lease_id"]);
    return 0;
} }
