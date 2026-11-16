// Host fixture for the public command ABI; only ios_system services are substituted.
#include <stdio.h>
#include <dirent.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int zoxide_ios_main(int, char **);
int zoxide_z_main(int, char **);
int zoxide_cd_main(int, char **);

static FILE *input, *output, *errors;
static char *logical_directory, *previous_directory;
static int output_error, errors_error;
static int failed_write(void *cookie, const char *bytes, int length) {
    (void)bytes;
    (void)length;
    errno = *(int *)cookie;
    return -1;
}
FILE *ios_stdin(void) { return input ? input : stdin; }
FILE *ios_stdout(void) { return output ? output : stdout; }
FILE *ios_stderr(void) { return errors ? errors : stderr; }
void ios_setStreams(FILE *in, FILE *out, FILE *err) { input = in; output = out; errors = err; }
char *ios_getenv(const char *name) {
    // A session variable deliberately differs from the process environment.
    if (strcmp(name, "_ZO_DATA_DIR") == 0 && getenv("HOST_DATA_DIR")) return getenv("HOST_DATA_DIR");
    if (strcmp(name, "PWD") == 0) return logical_directory;
    return getenv(name);
}
int cd_main(int argc, char **argv) {
    // The real cd_main returns zero even when changing directory fails.
    const char *path = argc == 2 ? argv[1] : getenv("HOME");
    if (path && strcmp(path, "-") == 0) path = previous_directory;
    if (path && !getenv("HOST_DENY_CD") && chdir(path) == 0) {
        char *next = path[0] == '/' ? strdup(path) : getcwd(NULL, 0);
        free(previous_directory);
        previous_directory = logical_directory;
        logical_directory = next;
    } else {
        fprintf(ios_stderr(), "cd: could not change directory\n");
    }
    return 0;
}

int main(int argc, char **argv) {
    int status = 0;
    logical_directory = getcwd(NULL, 0);
    if (!logical_directory) return 2;
    if (getenv("HOST_OUTPUT") && !(output = fopen(getenv("HOST_OUTPUT"), "w"))) return 2;
    if (getenv("HOST_ERRORS") && !(errors = fopen(getenv("HOST_ERRORS"), "w"))) return 2;
    if (getenv("HOST_OUTPUT_ERROR")) {
        output_error = strcmp(getenv("HOST_OUTPUT_ERROR"), "EPIPE") == 0 ? EPIPE : EIO;
        output = funopen(&output_error, NULL, failed_write, NULL, NULL);
        if (!output) return 2;
    }
    if (getenv("HOST_ERRORS_ERROR")) {
        errors_error = EIO;
        errors = funopen(&errors_error, NULL, failed_write, NULL, NULL);
        if (!errors) return 2;
    }
    // :: separates successive commands in the same process.
    for (int start = 1; start < argc;) {
        int end = start + 1;
        while (end < argc && strcmp(argv[end], "::") != 0) end++;
        char *separator = argv[end];
        argv[end] = NULL;
        if (strcmp(argv[start], "pwd") == 0) {
            char *path = getcwd(NULL, 0);
            if (!path) return 2;
            puts(path);
            free(path);
            status = 0;
        } else if (strcmp(argv[start], "fds") == 0) {
            DIR *directory = opendir("/dev/fd");
            if (!directory) return 2;
            int count = 0;
            struct dirent *entry;
            while ((entry = readdir(directory))) {
                if (entry->d_name[0] != '.') count++;
            }
            closedir(directory);
            printf("%d\n", count);
            status = 0;
        } else if (strcmp(argv[start], "setenv") == 0 && end - start == 3) {
            status = setenv(argv[start + 1], argv[start + 2], 1) != 0;
        } else if (strcmp(argv[start], "rmdir") == 0 && end - start == 2) {
            status = rmdir(argv[start + 1]) != 0;
        } else if (strcmp(argv[start], "cd") == 0 && end - start == 2) {
            status = zoxide_cd_main(2, argv + start);
        } else if (strcmp(argv[start], "z") == 0) {
            status = zoxide_z_main(end - start, argv + start);
        } else {
            status = zoxide_ios_main(end - start, argv + start);
        }
        argv[end] = separator;
        if (end < argc) fprintf(stderr, "status=%d\n", status);
        start = end + 1;
    }
    if (output) fclose(output);
    if (errors) fclose(errors);
    free(logical_directory);
    free(previous_directory);
    return status;
}
