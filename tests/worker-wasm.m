#import <Foundation/Foundation.h>
#import <ios_system/ios_system.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>

// Register this consumer as an app command in a disposable host build.
int worker_wasm_check_main(int argc, char **argv) {
    if (argc != 3) return 64;
    int (*spawn)(const char *, const char *, unsigned, unsigned, const char *const *, int *, void **) = dlsym(RTLD_DEFAULT, "ashell_pane_spawn");
    int (*pollJob)(void *, int *) = dlsym(RTLD_DEFAULT, "ashell_pane_poll");
    void (*release)(void *) = dlsym(RTLD_DEFAULT, "ashell_pane_release");
    if (!spawn || !pollJob || !release) return 69;
    NSString *engine = [NSString stringWithUTF8String:argv[2]];
    if (![@[@"path", @"wasm3", @"wasmkit"] containsObject:engine]) return 64;
    NSString *root = [NSHomeDirectory() stringByAppendingPathComponent:[@"Documents/worker-wasm-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    NSFileManager *files = NSFileManager.defaultManager;
    if (![files createDirectoryAtPath:[root stringByAppendingPathComponent:@"opened"] withIntermediateDirectories:YES attributes:nil error:nil]) return 73;
    NSString *program = [root stringByAppendingPathComponent:@"worker-wasm-guest.wasm"];
    if (![files copyItemAtPath:[NSString stringWithUTF8String:argv[1]] toPath:program error:nil]) return 73;
    if (chmod(program.fileSystemRepresentation, 0755)) return 73;
    NSString *prefix = [engine isEqualToString:@"path"] ? @"" : [engine stringByAppendingString:@" "];
    BOOL preopen = ![engine isEqualToString:@"wasm3"];
    NSString *command = [NSString stringWithFormat:@"dash -c '%@worker-wasm-guest.wasm %@ first; a=$?; %@worker-wasm-guest.wasm %@ second; b=$?; %@worker-wasm-guest.wasm %@ status; c=$?; printf \"statuses=%%s,%%s,%%s\\n\" \"$a\" \"$b\" \"$c\"; %@'", prefix, root, prefix, root, prefix, root, preopen ? [NSString stringWithFormat:@"%@worker-wasm-guest.wasm %@ preopen", prefix, root] : @"exit 0"];
    NSString *path = [NSString stringWithFormat:@"PATH=%@:%s", root, getenv("PATH") ?: ""];
    const char *environment[] = {path.UTF8String, NULL};
    void *job = NULL;
    int fd = -1;
    int error = spawn(command.UTF8String, root.fileSystemRepresentation, 80, 24, environment, &fd, &job);
    if (error) { fprintf(thread_stdout, "spawn=%d: FAIL\n", error); return 1; }
    fcntl(fd, F_SETFL, O_NONBLOCK);
    NSMutableData *output = [NSMutableData data];
    int state = 0, status = 0;
    double deadline = NSDate.timeIntervalSinceReferenceDate + 30;
    while (NSDate.timeIntervalSinceReferenceDate < deadline) {
        char bytes[4096];
        ssize_t count = read(fd, bytes, sizeof(bytes));
        if (count > 0) [output appendBytes:bytes length:(NSUInteger)count];
        state = pollJob(job, &status);
        if (state) break;
        usleep(1000);
    }
    for (;;) {
        char bytes[4096];
        ssize_t count = read(fd, bytes, sizeof(bytes));
        if (count <= 0) break;
        [output appendBytes:bytes length:(NSUInteger)count];
    }
    close(fd);
    release(job);
    NSString *observed = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    NSString *expected = @"stdout-first\r\nstderr-first\r\nstdout-second\r\nstderr-second\r\nstdout-status\r\nstderr-status\r\nstatuses=0,0,17\r\n";
    // Socket output may be raw LF; normalize only terminal newline expansion.
    observed = [observed stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    expected = [expected stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    if (preopen) {
        for (int i = 0; i < 9; i++) expected = [expected stringByAppendingString:@"tty-output\n"];
        expected = [expected stringByAppendingString:@"stdout-preopen\nstderr-preopen\n"];
    }
    BOOL passed = state == 1 && status == 0 && [observed isEqualToString:expected];
    for (NSString *name in preopen ? @[@"first", @"second", @"status", @"preopen"] : @[@"first", @"second", @"status"]) {
        NSString *absolute = [root stringByAppendingPathComponent:[name stringByAppendingString:@"-absolute.txt"]];
        NSString *relative = [root stringByAppendingPathComponent:[name stringByAppendingString:@"-relative.txt"]];
        passed &= [[NSString stringWithContentsOfFile:absolute encoding:NSUTF8StringEncoding error:nil] isEqualToString:@"absolute\n"];
        passed &= [[NSString stringWithContentsOfFile:relative encoding:NSUTF8StringEncoding error:nil] isEqualToString:@"relative\n"];
    }
    if (preopen) {
        passed &= [[NSString stringWithContentsOfFile:[root stringByAppendingPathComponent:@"opened/child.txt"] encoding:NSUTF8StringEncoding error:nil] isEqualToString:@"directory\n"];
        passed &= ![files fileExistsAtPath:[root stringByAppendingPathComponent:@"child.txt"]];
    }
    fwrite(output.bytes, 1, output.length, thread_stdout);
    fprintf(thread_stdout, "worker-wasm engine=%s state=%d status=%d root=%s: %s\n", argv[2], state, status, root.UTF8String, passed ? "PASS" : "FAIL");
    fflush(thread_stdout);
    return passed ? 0 : 1;
}
