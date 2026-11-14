#include <unistd.h>

int main(void) {
    if (write(STDOUT_FILENO, "out-1\n", 6) != 6) return 1;
    if (write(STDERR_FILENO, "err-1\n", 6) != 6) return 2;
    if (write(STDOUT_FILENO, "out-2\n", 6) != 6) return 3;
    if (write(STDERR_FILENO, "err-2\n", 6) != 6) return 4;
    return 0;
}
