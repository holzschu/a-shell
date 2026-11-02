// Run on an arm64 Simulator against the app's actual command frameworks.
#import <Foundation/Foundation.h>
#include "ios_system.h"
#include <pthread.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const char session[] = "node-interrupt-test";
static FILE *output;
static atomic_bool finished;

static void *send_interrupt(void *unused) {
    (void)unused;
    // Wait for the actual server's listen callback, not a fixed startup delay.
    for (int i = 0; i < 1000 && !atomic_load(&finished); i++) {
        char data[4096] = {0};
        pread(fileno(output), data, sizeof(data) - 1, 0);
        if (strstr(data, "READY\n")) {
            ios_switchSession(session);
            ios_setContext(session);
            fprintf(stderr, "READY: sending interrupt through ios_kill.\n");
            ios_kill();
            return NULL;
        }
        usleep(10000);
    }
    fprintf(stderr, "Server did not become ready.\n");
    _exit(2);
}

int main(int argc, char **argv) {
    if (argc != 4) {
        fprintf(stderr, "Usage: interrupt <command> <expected-status> <app>\n");
        return 2;
    }
    @autoreleasepool {
        alarm(20);
        NSString *root = NSBundle.mainBundle.resourcePath;
        NSString *app = [NSString stringWithUTF8String:argv[3]];
        if (![NSFileManager.defaultManager changeCurrentDirectoryPath:root]) return 2;
        NSMutableDictionary *commands = [NSMutableDictionary dictionary];
        NSDictionary *bundled = [NSDictionary dictionaryWithContentsOfFile:
            [app stringByAppendingPathComponent:@"commandDictionary.plist"]];
        for (NSString *name in @[@"node", @"npm", @"npx", @"dash", @"dirname", @"sed", @"uname"]) {
            NSMutableArray *definition = [bundled[name] mutableCopy];
            if (definition.count != 4) return 2;
            definition[0] = [[app stringByAppendingPathComponent:@"Frameworks"]
                stringByAppendingPathComponent:definition[0]];
            commands[name] = definition;
        }
        if (![commands writeToFile:[root stringByAppendingPathComponent:@"commandDictionary.plist"] atomically:YES]) return 2;
        setenv("HOME", root.UTF8String, 1);
        NSString *searchPath = [NSString stringWithFormat:@"%@/node_modules/.bin:%@/bin", root, root];
        setenv("PATH", searchPath.UTF8String, 1);
        initializeEnvironment();
        ios_switchSession(session);
        ios_setContext(session);
        output = tmpfile();
        FILE *input = fopen("/dev/null", "r");
        if (!output || !input) return 2;
        ios_setStreams(input, output, stderr);
        joinMainThread = true;
        // A completed command must not disable the next command's interrupt.
        if (ios_system("node -e 'console.log(42)'") != 0) return 2;
        // Use the bundled npm's actual shim generator, including its exit status.
        if (ios_system("node -e 'require(\"./npm/node_modules/cmd-shim\")(\"node_modules/interrupt-server/server.cjs\",\"node_modules/.bin/interrupt-server\")'") != 0) return 2;
        fflush(output);
        ftruncate(fileno(output), 0);
        rewind(output);
        pthread_t sender;
        if (pthread_create(&sender, NULL, send_interrupt, NULL)) return 2;
        int status = ios_system(argv[1]);
        atomic_store(&finished, true);
        pthread_join(sender, NULL);
        if (status != atoi(argv[2])) {
            fprintf(stderr, "Expected status %s, got %d.\n", argv[2], status);
            char data[4096] = {0};
            ssize_t size = pread(fileno(output), data, sizeof(data) - 1, 0);
            if (size > 0) fwrite(data, 1, size, stderr);
            return 1;
        }
        // Rebind the server's port: returning while a child still listens fails.
        int next = ios_system("node -e 'const s=require(\"http\").createServer(); s.listen(18099,()=>{console.log(\"NEXT\");s.close()})'");
        char data[4096] = {0};
        pread(fileno(output), data, sizeof(data) - 1, 0);
        if (next != 0 || !strstr(data, "NEXT\n")) {
            fprintf(stderr, "The next Node command could not reuse the server port.\n");
            return 1;
        }
        fclose(input);
        fclose(output);
        printf("PASS: interrupt status %d; next command reused the port.\n", status);
        return 0;
    }
}
