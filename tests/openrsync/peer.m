#import <ios_system/ios_system.h>
#include <poll.h>
#include <stdint.h>
#include <sys/wait.h>
#include <unistd.h>
#include "ios_error.h"

/* An incompatible external protocol peer; wait for the client to close. */
int
openrsync_peer_main(int argc, char **argv)
{
	(void)argc;
	(void)argv;
	uint32_t handshake[] = { 1, 0 };
	if (write(fileno(thread_stdout), handshake, sizeof(handshake)) != sizeof(handshake)) return 20;
	char bytes[64];
	for (;;) {
		struct pollfd input = { .fd = fileno(thread_stdin), .events = POLLIN };
		if (poll(&input, 1, 3000) <= 0) return 21;
		ssize_t count = read(input.fd, bytes, sizeof(bytes));
		if (count == 0) return 0;
		if (count < 0) return 22;
	}
}

/* A separate session's cancellable command. */
int
openrsync_wait_main(int argc, char **argv)
{
	if (argc != 2) return 2;
	FILE *marker = fopen(argv[1], "w");
	if (!marker) return 3;
	fputs("ready", marker);
	if (fclose(marker) != 0) return 4;
	for (;;) usleep(10000);
}

/* Forward the external transport's server argv to the real rsync command. */
int
openrsync_transport_main(int argc, char **argv)
{
	if (argc < 3) return 2;
	pid_t child = ios_fork();
	if (child < 0) return 3;
	if (ios_execv(argv[2], argv + 2) != 0) return 4;
	int result;
	if (ios_full_waitpid(child, &result, 0) < 0) return 5;
	return WIFEXITED(result) ? WEXITSTATUS(result) : 6;
}
