#import "AShellML.h"
#import <Foundation/Foundation.h>

int main(int argc, char **argv) {
    // Isolate framework diagnostics which bypass FILE streams on macOS.
    FILE *out = fdopen(dup(STDOUT_FILENO), "w");
    if (!out || dup2(STDERR_FILENO, STDOUT_FILENO) < 0) return 1;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            exit(asml_command(argc, argv, out, stderr));
        }
    });
    dispatch_main();
}
