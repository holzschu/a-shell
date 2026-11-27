// Pass owned copies of ios_system's streams; never redirect process fds 0-2.
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <unistd.h>
#include "ios_system.h"
#include "port-entry.h"

static pthread_mutex_t command_lock = PTHREAD_MUTEX_INITIALIZER;

int nvim_ios_main(int argc, char **argv) {
    if (pthread_mutex_trylock(&command_lock) != 0) {
        fprintf(thread_stderr, "Neovim is already running in this app\n");
        return 1;
    }
    FILE *host[] = {thread_stdin, thread_stdout, thread_stderr};
    int was_interactive = ios_storeInteractive();
    FILE *streams[] = {NULL, NULL, NULL};
    int status = 1;
    void *library = NULL;
    for (int i = 0; i < 3; i++) {
        int fd = host[i] ? fcntl(fileno(host[i]), F_DUPFD_CLOEXEC, 3) : -1;
        if (fd < 0) goto cleanup;
        streams[i] = fdopen(fd, i == 0 ? "r" : "w");
        if (!streams[i]) { close(fd); goto cleanup; }
    }
    NSString *bundle = NSBundle.mainBundle.bundlePath;
    if ([bundle.pathExtension isEqualToString:@"appex"]) {
        bundle = bundle.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent;
    }
    NSString *framework = [bundle stringByAppendingPathComponent:@"Frameworks/Nvim.framework"];
    NSString *runtime = [framework stringByAppendingPathComponent:@"runtime"];
    NSString *path = [framework stringByAppendingPathComponent:@"Nvim"];
    library = dlopen(path.UTF8String, RTLD_LOCAL | RTLD_NOW);
    if (!library) {
        fprintf(thread_stderr, "Cannot load Neovim: %s\n", dlerror());
        goto cleanup;
    }
    nvim_port_run_fn run = dlsym(library, "nvim_port_run");
    if (!run) {
        fprintf(thread_stderr, "Cannot resolve Neovim entry: %s\n", dlerror());
        goto cleanup;
    }
    status = run(argc, argv, streams, runtime.UTF8String);
cleanup:
    if (!was_interactive && ios_storeInteractive()) ios_stopInteractive();
    if (library) dlclose(library);
    for (int i = 0; i < 3; i++) {
        if (streams[i]) fclose(streams[i]);
    }
    pthread_mutex_unlock(&command_lock);
    return status;
}
