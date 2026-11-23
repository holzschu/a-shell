#import <Foundation/Foundation.h>
#import "AShellML.h"
#include <stdatomic.h>
#include <unistd.h>

static void require(BOOL valid, NSString *message) {
    if (!valid) { fprintf(stderr, "FAIL: %s\n", message.UTF8String); exit(1); }
}
static NSDictionary *json(NSString *path) {
    NSData *bytes = [NSData dataWithContentsOfFile:path];
    return bytes ? [NSJSONSerialization JSONObjectWithData:bytes options:0 error:nil] : nil;
}
static int command(NSArray<NSString *> *args, NSString *output) {
    char *argv[args.count];
    for (NSUInteger i = 0; i < args.count; i++) argv[i] = (char *)args[i].UTF8String;
    FILE *out = fopen([output stringByAppendingString:@".stdout"].fileSystemRepresentation, "w");
    FILE *err = fopen([output stringByAppendingString:@".stderr"].fileSystemRepresentation, "w");
    require(out && err, @"Cannot open consumer streams");
    int code = asml_command((int)args.count, argv, out, err);
    fclose(out); fclose(err); return code;
}
static NSDictionary *status(void) {
    int code; char *raw = asml_status(&code);
    require(!code && raw, @"Status failed");
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:[@(raw) dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    asml_free(raw); return result;
}
static void waitFor(BOOL (^condition)(void), NSString *message) {
    double limit = NSProcessInfo.processInfo.systemUptime + 30;
    while (!condition() && NSProcessInfo.processInfo.systemUptime < limit) [NSThread sleepForTimeInterval:0.005];
    require(condition(), message);
}
static void upload(NSString *job, NSString *nonce) {
    // Write cancellation through the public job-directory contract.
    require([[nonce dataUsingEncoding:NSUTF8StringEncoding] writeToFile:[job stringByAppendingPathComponent:@"cancel"] atomically:NO], @"Upload failed");
}
int main(int argc, char **argv) {
    require(argc == 3, @"Usage: job-session OWNED_ROOT GRAYSCALE_FIXTURE");
    @autoreleasepool {
        NSString *root = @(argv[1]), *fixture = @(argv[2]);
        FILE *report = fdopen(dup(STDOUT_FILENO), "w"); dup2(STDERR_FILENO, STDOUT_FILENO);
        __block atomic_bool finished = false;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ @autoreleasepool {
            NSString *active = [root stringByAppendingPathComponent:@"active"], *queued = [root stringByAppendingPathComponent:@"queued"];
            for (NSString *job in @[active, queued]) require(command(@[@"coreml", @"job", @"create", job], job) == 0, @"Create failed");
            NSString *activeNonce = json([active stringByAppendingPathComponent:@"result.json"])[@"job"];
            NSString *queuedNonce = json([queued stringByAppendingPathComponent:@"result.json"])[@"job"];
            dispatch_group_t jobs = dispatch_group_create();
            dispatch_group_async(jobs, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                require(command(@[@"coreml", @"job", @"run", active, @"coreml", @"run", @"mnist", fixture, @"--iterations", @"10000000"], active) == 130, @"Active cancellation did not return 130");
            });
            waitFor(^BOOL { return [status()[@"completed_chunks"] intValue] >= 3; }, @"No native progress");
            require(command(@[@"coreml", @"job", @"run", active, @"coreml", @"run", @"mnist", fixture], [root stringByAppendingPathComponent:@"duplicate"]) == 75, @"Duplicate active submission was accepted");
            dispatch_group_async(jobs, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                require(command(@[@"coreml", @"job", @"run", queued, @"coreml", @"run", @"mnist", fixture], queued) == 130, @"Queued cancellation did not return 130");
            });
            waitFor(^BOOL { return [status()[@"queued"] intValue] == 1; }, @"Second request never queued");
            upload(active, queuedNonce);
            unsigned long long before = [status()[@"completed_chunks"] unsignedLongLongValue];
            waitFor(^BOOL { return [status()[@"completed_chunks"] unsignedLongLongValue] > before + 3; }, @"Another job's nonce stopped the active request");
            upload(queued, queuedNonce);
            waitFor(^BOOL { return [json([queued stringByAppendingPathComponent:@"result.json"])[@"exit_code"] intValue] == 130; }, @"Queued job did not stop before loading");
            require([status()[@"active"] intValue] == 1, @"Cancelling queued work stopped the active job");
            waitFor(^BOOL { return [json([active stringByAppendingPathComponent:@"result.json"])[@"completed_chunks"] intValue] > 0; }, @"No durable chunk checkpoint");
            upload(active, activeNonce);
            require(dispatch_group_wait(jobs, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC)) == 0, @"Native jobs failed to finish");
            NSDictionary *idle = status();
            require([idle[@"active"] intValue] == 0 && [idle[@"queued"] intValue] == 0 && [idle[@"requests"] intValue] == 0, @"Permit or requests leaked");
            for (NSString *job in @[active, queued]) require([[NSData dataWithContentsOfFile:[job stringByAppendingPathComponent:@"stdout"]] length] == 0, @"Cancelled work published partial output");
            NSString *recovery = [root stringByAppendingPathComponent:@"recovery"];
            require(command(@[@"coreml", @"run", @"mnist", fixture], recovery) == 0, @"Next command failed");
            require([json([recovery stringByAppendingString:@".stdout"])[@"runs"][0][@"label"] isEqual:@"7"], @"Next command returned wrong label");
            fprintf(report, "COREML_JOB_SESSION_PASS active=130 queued=130 wrong_nonce_ignored=true native_cleanup=true next_label=7\n"); fflush(report);
            atomic_store(&finished, true);
        } });
        while (!atomic_load(&finished)) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        fclose(report);
    }
    return 0;
}
