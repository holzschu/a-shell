#import "AShellML.h"
#import <Foundation/Foundation.h>
#import <fcntl.h>
#import <sys/file.h>
#import <sys/stat.h>
#import <unistd.h>

// Job-relative I/O uses a retained directory descriptor and rejects symlinks.
static int directory(NSString *path, BOOL create) {
    if (!path.isAbsolutePath || path.length < 2) return -1;
    // Start inside the app sandbox when possible: iOS need not grant directory
    // read access to the filesystem root merely to reach the app's own files.
    NSArray *parts = path.pathComponents;
    for (NSString *part in parts) if ([part isEqual:@".."] || [part isEqual:@"."]) return -1;
    int fd = open(NSHomeDirectory().fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
    struct stat home, candidate;
    NSUInteger start = 1;
    BOOL matched = NO;
    if (fd >= 0 && !fstat(fd, &home)) {
        NSString *prefix = @"/";
        for (NSUInteger i = 1; i < parts.count; i++) {
            prefix = [prefix stringByAppendingPathComponent:parts[i]];
            // Foundation can hide /private in its home spelling. The phone
            // rejected the physical $HOME path when string-prefix matching fell
            // back to reading /. Match only the trusted home's OS identity.
            if (!stat(prefix.fileSystemRepresentation, &candidate) && candidate.st_dev == home.st_dev && candidate.st_ino == home.st_ino) {
                matched = YES; start = i + 1; break;
            }
        }
    }
    if (matched && start == parts.count) { close(fd); return -1; }
    if (!matched) { if (fd >= 0) close(fd); fd = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW); }
    for (NSUInteger i = start; fd >= 0 && i < parts.count; i++) {
        NSString *part = parts[i];
        if ([part isEqual:@".."] || [part isEqual:@"."] || [part isEqual:@"/"]) { close(fd); return -1; }
        if (create && i + 1 == parts.count && mkdirat(fd, part.fileSystemRepresentation, 0700)) { close(fd); return -1; }
        int next = openat(fd, part.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
        close(fd); fd = next;
    }
    return fd;
}
static int regular(int dir, const char *name, int flags) {
    int fd = openat(dir, name, flags | O_NOFOLLOW | O_NONBLOCK, 0600);
    struct stat st;
    if (fd >= 0 && (fstat(fd, &st) || !S_ISREG(st.st_mode) || st.st_nlink != 1)) { close(fd); return -1; }
    return fd;
}
static NSDictionary *readResult(int dir) {
    int fd = regular(dir, "result.json", O_RDONLY);
    if (fd < 0) return nil;
    struct stat st; NSMutableData *data = [NSMutableData dataWithLength:65536];
    ssize_t count = read(fd, data.mutableBytes, data.length);
    BOOL valid = !fstat(fd, &st) && count > 0 && count == st.st_size;
    close(fd);
    if (!valid) return nil;
    data.length = count;
    id value = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [value isKindOfClass:NSDictionary.class] ? value : nil;
}
static BOOL save(int dir, NSDictionary *value) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingSortedKeys error:nil];
    NSString *temp = [@".result-" stringByAppendingString:NSUUID.UUID.UUIDString];
    int fd = regular(dir, temp.UTF8String, O_WRONLY | O_CREAT | O_EXCL);
    if (fd < 0 || !data) { if (fd >= 0) close(fd); return NO; }
    BOOL ok = write(fd, data.bytes, data.length) == (ssize_t)data.length && fsync(fd) == 0;
    close(fd);
    if (ok) ok = renameat(dir, temp.UTF8String, dir, "result.json") == 0 && fsync(dir) == 0;
    if (!ok) unlinkat(dir, temp.UTF8String, 0);
    return ok;
}
static int emit(NSDictionary *value, int code, FILE *out, FILE *err) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingSortedKeys error:nil];
    FILE *stream = code ? err : out;
    if (!data || fwrite(data.bytes, 1, data.length, stream) != data.length || fputc('\n', stream) == EOF || fflush(stream)) return 1;
    return code;
}
static int fail(int code, NSString *message, FILE *out, FILE *err) {
    return emit(@{@"error":message, @"status":@(code)}, code, out, err);
}

int asml_job(int argc, char **argv, FILE *out, FILE *err) {
    @autoreleasepool {
        if (argc < 4) return fail(2, @"Usage: coreml job create|status DIRECTORY | job run DIRECTORY coreml run mnist IMAGE [OPTIONS]", out, err);
        NSString *action = @(argv[2]), *path = @(argv[3]);
        BOOL create = [action isEqual:@"create"], run = [action isEqual:@"run"];
        if ((!create && !run && ![action isEqual:@"status"]) || (run ? argc < 6 : argc != 4)) return fail(2, @"Invalid job arguments", out, err);
        int dir = directory(path, create);
        if (dir < 0) return fail(2, @"Job requires a new (create) or existing canonical absolute directory without symlinks or traversal", out, err);
        int lock = regular(dir, "lock", O_RDWR | O_CREAT);
        if (lock < 0) { close(dir); return fail(2, @"Unsafe job lock", out, err); }
        BOOL acquired = flock(lock, LOCK_EX | LOCK_NB) == 0;
        NSMutableDictionary *receipt = [readResult(dir) mutableCopy];
        int result = 0;
        if (create && acquired) {
            receipt = [@{@"schema":@1, @"job":NSUUID.UUID.UUIDString, @"state":@"prepared", @"directory":path, @"stdout":@"stdout", @"stderr":@"stderr", @"cancel":@"cancel"} mutableCopy];
            if (!save(dir, receipt)) result = 1;
        } else if (![receipt[@"job"] isKindOfClass:NSString.class] || ![[NSUUID alloc] initWithUUIDString:receipt[@"job"]] || ![receipt[@"state"] isKindOfClass:NSString.class]) result = 2;
        else if (!run) {
            // A dead process releases flock. Preserve its files, but never report
            // success from an unfinished checkpoint after restart.
            if (acquired && [receipt[@"state"] isEqual:@"running"]) {
                receipt[@"state"] = @"interrupted"; receipt[@"exit_code"] = @75;
                if (!save(dir, receipt)) result = 1;
            }
        } else if (!acquired || ![receipt[@"state"] isEqual:@"prepared"]) result = 75;
        else {
            BOOL coreml = !strcmp(argv[4], "coreml");
            BOOL valid = (coreml && argc >= 8 && !strcmp(argv[5], "run") && !strcmp(argv[6], "mnist"));
            for (int i = 5; i < argc; i++) if (!strcmp(argv[i], "--request")) valid = NO;
            if (!valid) result = 2;
            else {
                int output = regular(dir, ".stdout.pending", O_WRONLY | O_CREAT | O_EXCL);
                int error = regular(dir, ".stderr.pending", O_WRONLY | O_CREAT | O_EXCL);
                FILE *jobOut = output < 0 ? NULL : fdopen(output, "w");
                FILE *jobErr = error < 0 ? NULL : fdopen(error, "w");
                if (!jobOut || !jobErr) result = 1;
                else {
                    int status; char *raw = asml_request_file(dir, [receipt[@"job"] UTF8String], &status);
                    NSDictionary *request = raw ? [NSJSONSerialization JSONObjectWithData:[@(raw) dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
                    asml_free(raw);
                    if (status) result = status;
                    else {
                        receipt[@"request"] = request[@"request"]; receipt[@"state"] = @"running";
                        NSMutableArray *arguments = [NSMutableArray array];
                        for (int i = 4; i < argc; i++) [arguments addObject:@(argv[i])];
                        [arguments addObjectsFromArray:@[@"--request", request[@"request"]]];
                        char *nested[arguments.count];
                        for (NSUInteger i = 0; i < arguments.count; i++) nested[i] = (char *)[arguments[i] UTF8String];
                        if (!save(dir, receipt)) result = 1;
                        else {
                            dispatch_queue_t checkpoints = dispatch_queue_create("org.ashell.ml.job-checkpoint", DISPATCH_QUEUE_SERIAL);
                            dispatch_source_t monitor = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, checkpoints);
                            dispatch_source_set_timer(monitor, DISPATCH_TIME_NOW, NSEC_PER_SEC / 10, NSEC_PER_SEC / 100);
                            dispatch_source_set_event_handler(monitor, ^{ @autoreleasepool {
                                int code; char *rawStatus = asml_request_status([request[@"request"] UTF8String], &code);
                                NSDictionary *state = rawStatus ? [NSJSONSerialization JSONObjectWithData:[@(rawStatus) dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
                                asml_free(rawStatus);
                                if (!code && ![state[@"completed_chunks"] isEqual:receipt[@"completed_chunks"]]) {
                                    receipt[@"completed_chunks"] = state[@"completed_chunks"];
                                    save(dir, receipt);
                                }
                            } });
                            dispatch_resume(monitor);
                            result = asml_command((int)arguments.count, nested, jobOut, jobErr);
                            dispatch_source_cancel(monitor);
                            dispatch_sync(checkpoints, ^{});
                        }
                        // Input/usage failure may occur before admission. Retire the
                        // prepared request too, so malformed submissions cannot fill it.
                        int cleanup; asml_free(asml_cancel([request[@"request"] UTF8String], &cleanup));
                        asml_free(asml_end([request[@"request"] UTF8String], &cleanup));
                    }
                    if (fflush(jobOut) || fflush(jobErr) || fsync(fileno(jobOut)) || fsync(fileno(jobErr))) result = 1;
                    if (fclose(jobOut)) result = 1;
                    if (fclose(jobErr)) result = 1;
                    jobOut = NULL; jobErr = NULL; output = -1; error = -1;
                    // linkat publishes without replacing a preexisting file. The
                    // terminal receipt follows both streams and their directory sync.
                    if (linkat(dir, ".stdout.pending", dir, "stdout", 0) || unlinkat(dir, ".stdout.pending", 0)) result = 1;
                    if (linkat(dir, ".stderr.pending", dir, "stderr", 0) || unlinkat(dir, ".stderr.pending", 0)) result = 1;
                    receipt[@"state"] = @"done"; receipt[@"exit_code"] = @(result);
                    if (!save(dir, receipt)) result = 1;
                }
                if (jobOut) fclose(jobOut); else if (output >= 0) close(output);
                if (jobErr) fclose(jobErr); else if (error >= 0) close(error);
            }
        }
        if (acquired) flock(lock, LOCK_UN);
        close(lock); close(dir);
        if (receipt && (!result || (run && [receipt[@"state"] isEqual:@"done"]))) return emit(receipt, result, out, err);
        return fail(result ?: 1, @"Job rejected or result could not be persisted; inspect existing files before retrying", out, err);
    }
}
