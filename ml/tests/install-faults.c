// Fault only the external filesystem boundary, never the installer implementation.
#include <fcntl.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>

static int fixture_rename(const char *from, const char *to) {
    int result = rename(from, to);
    const char *phase = getenv("ASML_FIXTURE_STOP");
    if (result || !phase) return result;
    int stop = 0;
    if (!strcmp(phase, "published") && strstr(to, "/active.json")) stop = 1;
    if (strstr(to, "/install.json")) {
        int fd = open(to, O_RDONLY); char buffer[2048] = {0};
        if (fd >= 0) { read(fd, buffer, sizeof(buffer) - 1); close(fd); }
        char match[128]; snprintf(match, sizeof(match), "\"phase\":\"%s\"", phase);
        stop = strstr(buffer, match) != NULL;
    }
    if (stop) { write(STDERR_FILENO, "ASML_FIXTURE_STOP\n", 18); kill(getpid(), SIGSTOP); }
    return result;
}
static int fixture_fsync(int fd) {
    int result = fsync(fd);
    const char *phase = getenv("ASML_FIXTURE_STOP");
    char path[4096] = {0};
    if (!result && phase && !strcmp(phase, "before-commit") && !fcntl(fd, F_GETPATH, path) && strstr(path, "/.staging-") && strstr(path, "/receipt.json")) {
        write(STDERR_FILENO, "ASML_FIXTURE_STOP\n", 18); kill(getpid(), SIGSTOP);
    }
    return result;
}
__attribute__((used)) static struct { const void *replacement; const void *original; } interpose_rename
__attribute__((section("__DATA,__interpose"))) = { (const void *)fixture_rename, (const void *)rename };
__attribute__((used)) static struct { const void *replacement; const void *original; } interpose_fsync
__attribute__((section("__DATA,__interpose"))) = { (const void *)fixture_fsync, (const void *)fsync };
