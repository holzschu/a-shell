#import "../AShellML.h"
#import <Foundation/Foundation.h>
#include <unistd.h>
#include <math.h>
#include <fcntl.h>
#include <sys/stat.h>

static NSDictionary *decode(char *json) {
    NSDictionary *value = [NSJSONSerialization JSONObjectWithData:[@(json) dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    asml_free(json); return value;
}
int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc != 4) return 2;
        // Like the stock host consumer, isolate Core ML's process-level diagnostics.
        FILE *report = fdopen(dup(STDOUT_FILENO), "w");
        if (!report || dup2(STDERR_FILENO, STDOUT_FILENO) < 0) return 1;
        int code; NSDictionary *request = decode(asml_request(&code)); if (code) return 1;
        NSString *token = request[@"request"];
        FILE *out = tmpfile(), *err = tmpfile(); if (!out || !err) return 1;
        char *command[] = {"coreml", "embed", argv[1], argv[2], "--units", "cpu", "--request", (char *)token.UTF8String};
        char **arguments = command;
        dispatch_semaphore_t finished = dispatch_semaphore_create(0); __block int status = -1;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            status = asml_command(8, arguments, out, err); dispatch_semaphore_signal(finished);
        });
        BOOL active = NO; double deadline = NSProcessInfo.processInfo.systemUptime + 120;
        while (NSProcessInfo.processInfo.systemUptime < deadline) {
            NSDictionary *progress = decode(asml_request_status(token.UTF8String, &code));
            if (!code && [progress[@"completed_chunks"] unsignedIntegerValue] > 0) { active = YES; break; }
            if (!dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 10000000))) { rewind(err); int byte; while ((byte = fgetc(err)) != EOF) fputc(byte, stderr); fprintf(stderr, "Work ended with %d before cancellation could be observed\n", status); return 1; }
        }
        if (!active) { fprintf(stderr, "No active embedding progress before timeout\n"); return 1; }
        decode(asml_cancel(token.UTF8String, &code)); if (code) return 1;
        if (dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 120*NSEC_PER_SEC))) return 1;
        fflush(out); fflush(err);
        if (status != 130 || ftell(out) != 0 || ftell(err) == 0) { fprintf(stderr, "Cancel status=%d stdout=%ld stderr=%ld\n", status, ftell(out), ftell(err)); return 1; }
        fclose(out); fclose(err);
        NSDictionary *idle = decode(asml_status(&code));
        if (code || [idle[@"active"] intValue] || [idle[@"queued"] intValue]) return 1;
        // A cancelled operation evicts its cache; the next two public commands must be cold then warm.
        NSString *coldID;
        for (int i = 0; i < 4; i++) {
            FILE *next = tmpfile(), *diagnostics = tmpfile();
            char *recovery[] = {"coreml", "embed", argv[1], argv[3], "--units", "cpu"};
            int result = asml_command(6, recovery, next, diagnostics);
            if (result) { fprintf(stderr, "Recovery failed: %d\n", result); return 1; }
            fflush(next); long count = ftell(next); rewind(next);
            NSMutableData *data = [NSMutableData dataWithLength:count]; fread(data.mutableBytes, 1, count, next);
            NSDictionary *value = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (!value || [value[@"cache_hit"] boolValue] != (i % 2 == 1) || ![value[@"verification_cached"] isKindOfClass:NSNumber.class] || [value[@"verification_cached"] boolValue] != (i % 2 == 1)) return 1;
            NSNumber *verification = value[@"verification_ms"], *native = value[@"model_load_ms"];
            if (![verification isKindOfClass:NSNumber.class] || ![native isKindOfClass:NSNumber.class] ||
                !isfinite(verification.doubleValue) || !isfinite(native.doubleValue) || verification.doubleValue < 0 || native.doubleValue < 0 ||
                [value[@"load_ms"] doubleValue] + 0.1 < verification.doubleValue + native.doubleValue ||
                (i % 2 == 0 ? native.doubleValue <= 0 : native.doubleValue != 0)) {
                fprintf(stderr, "Missing or inconsistent verification/model-load timings on %s recovery\n", i ? "warm" : "cold"); return 1;
            }
            if (i % 2 == 0) coldID = value[@"cache_id"];
            else if (![value[@"cache_id"] isEqual:coldID]) return 1;
            fprintf(report, "recovery=%d verification_ms=%.3f model_load_ms=%.3f cached=%d\n", i, verification.doubleValue, native.doubleValue, [value[@"verification_cached"] boolValue]);
            fclose(next); fclose(diagnostics);
            if (i == 1) {
                // Exercise the same public begin boundary used by the Python consumer.
                NSDictionary *loaded = decode(asml_begin_request(argv[1], "cpu", NULL, &code));
                if (code || !loaded) return 1;
                decode(asml_end([loaded[@"request"] UTF8String], &code)); if (code) return 1;
                NSDictionary *receipt = loaded[@"receipt"], *files = receipt[@"compiled_files"];
                NSString *directory = [receipt[@"path"] stringByAppendingPathComponent:@"model.mlmodelc"];
                NSString *smallest; unsigned long long size = ULLONG_MAX;
                for (NSString *name in files) {
                    NSString *candidate = [directory stringByAppendingPathComponent:name]; struct stat info;
                    if (!lstat(candidate.fileSystemRepresentation, &info) && S_ISREG(info.st_mode) && info.st_size > 0 && (unsigned long long)info.st_size < size) { smallest = candidate; size = info.st_size; }
                }
                if (!smallest) { fprintf(stderr, "No compiled leaf for tamper regression\n"); return 1; }
                struct stat rootBefore, rootAfter, leaf;
                int fd = open(smallest.fileSystemRepresentation, O_RDWR | O_NOFOLLOW); unsigned char original;
                if (fd < 0 || fstat(fd, &leaf) || lstat(directory.fileSystemRepresentation, &rootBefore) || pread(fd, &original, 1, 0) != 1) return 1;
                struct timespec times[] = {leaf.st_atimespec, leaf.st_mtimespec}; unsigned char changed = original ^ 1;
                BOOL edited = pwrite(fd, &changed, 1, 0) == 1 && fsync(fd) == 0 && futimens(fd, times) == 0;
                BOOL rootUnchanged = !lstat(directory.fileSystemRepresentation, &rootAfter) && rootBefore.st_mtimespec.tv_sec == rootAfter.st_mtimespec.tv_sec && rootBefore.st_mtimespec.tv_nsec == rootAfter.st_mtimespec.tv_nsec;
                NSDictionary *rejected = edited ? decode(asml_begin_request(argv[1], "cpu", NULL, &code)) : nil;
                int rejectedCode = code;
                if (rejectedCode == 0) decode(asml_end([rejected[@"request"] UTF8String], &code));
                BOOL restored = pwrite(fd, &original, 1, 0) == 1 && fsync(fd) == 0 && futimens(fd, times) == 0; close(fd);
                if (!edited || !restored || !rootUnchanged || rejectedCode != 2 || !rejected[@"error"]) { fprintf(stderr, "Restored-mtime compiled tamper was not rejected: %d\n", rejectedCode); return 1; }
            }
        }
        if (!strcmp(argv[1], "qwen3-embedding-0.6b")) {
            // Exercise cancellation while processing near-limit unbroken text,
            // through the command boundary with the already warm real model.
            uint32_t state = 7; NSMutableString *text = [NSMutableString string];
            for (NSUInteger i = 0; i < 65536; i++) { state = state * 1664525U + 1013904223U; [text appendFormat:@"%c", 'a' + state % 26]; }
            NSMutableArray *texts = [NSMutableArray array]; for (int i = 0; i < 15; i++) [texts addObject:text];
            NSString *path = [@(argv[3]).stringByDeletingLastPathComponent stringByAppendingPathComponent:@"tokenizer-cancel.json"];
            NSData *input = [NSJSONSerialization dataWithJSONObject:@{@"texts":texts, @"truncate":@YES} options:0 error:nil];
            if (!input || ![input writeToFile:path atomically:YES]) return 1;
            NSString *request = decode(asml_request(&code))[@"request"]; if (code) return 1;
            FILE *output = tmpfile(), *diagnostics = tmpfile(); if (!output || !diagnostics) return 1;
            char *args[] = {"coreml", "embed", argv[1], (char *)path.UTF8String, "--request", (char *)request.UTF8String};
            char **arguments = args;
            dispatch_semaphore_t done = dispatch_semaphore_create(0); __block int result = -1;
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                result = asml_command(6, arguments, output, diagnostics); dispatch_semaphore_signal(done);
            });
            usleep(200000);
            decode(asml_cancel(request.UTF8String, &code)); if (code) return 1;
            if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_SEC))) { fprintf(stderr, "Long-text cancellation exceeded 5 seconds\n"); return 1; }
            fflush(output); fflush(diagnostics);
            if (result != 130 || ftell(output) != 0 || ftell(diagnostics) == 0) { fprintf(stderr, "Long-text cancel status=%d\n", result); return 1; }
            fclose(output); fclose(diagnostics);
            NSDictionary *idle = decode(asml_status(&code));
            if (code || [idle[@"active"] intValue] || [idle[@"queued"] intValue]) return 1;
            fprintf(report, "EMBEDDING_LONG_TEXT_CANCEL_PASS status=130 stdout=0 idle=true deadline=5s\n");
        }
        fprintf(report, "EMBEDDING_SESSION_PASS cancellation=130 stdout=0 idle=true recovery=cold,warm tamper=2 restored=cold,warm\n"); fclose(report);
        return 0;
    }
}
