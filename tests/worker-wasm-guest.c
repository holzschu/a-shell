#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int put_file(const char *path, const char *text) {
    FILE *file = fopen(path, "w");
    if (!file) { perror(path); return 1; }
    int failed = fputs(text, file) < 0;
    if (fclose(file)) failed = 1;
    return failed;
}

int main(int argc, char **argv) {
    if (argc != 3) return 64;
    char path[4096];
    snprintf(path, sizeof(path), "%s/%s-absolute.txt", argv[1], argv[2]);
    if (put_file(path, "absolute\n")) return 73;
    snprintf(path, sizeof(path), "%s-relative.txt", argv[2]);
    if (put_file(path, "relative\n")) return 74;
    if (put_file("/dev/null", "discard\n")) return 75;
    if (!strcmp(argv[2], "preopen")) {
        snprintf(path, sizeof(path), "%s/opened", argv[1]);
        int directory = open(path, O_RDONLY | O_DIRECTORY);
        if (directory < 0) return 76;
        int file = openat(directory, "child.txt", O_WRONLY | O_CREAT | O_EXCL, 0600);
        if (file < 0) { close(directory); return 77; }
        int failed = write(file, "directory\n", 10) != 10;
        if (close(file)) failed = 1;
        if (close(directory)) failed = 1;
        if (failed) return 78;
        // The worker must not need to open the /dev directory to use its tty.
        for (int i = 0; i < 9; i++) {
            int tty = open("/dev/tty", O_WRONLY);
            if (tty < 0) { perror("tty-open"); return 81; }
            if (write(tty, "tty-output\n", 11) != 11) { close(tty); return 82; }
            if (close(tty)) return 83;
        }
    }
    printf("stdout-%s\n", argv[2]);
    fflush(stdout);
    fprintf(stderr, "stderr-%s\n", argv[2]);
    return !strcmp(argv[2], "status") ? 17 : 0;
}
