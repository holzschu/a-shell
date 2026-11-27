#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>

__thread FILE *thread_stdin, *thread_stdout, *thread_stderr;
void ios_exit(int status) { fprintf(stderr, "UNEXPECTED ios_exit(%d)\n", status); _exit(6); }
int multimarkdown_main(int argc, char **argv);

static int descriptors(void) {
	int count = 0;
	for (int fd = 0; fd < getdtablesize(); fd++) count += fcntl(fd, F_GETFD) != -1;
	return count;
}

int main(void) {
	const char *expected = "<h1 id=\"Привет世界\">Привет 世界</h1>\n\n<p>A <strong>bold</strong> line.</p>\n";
	const char *input = "# Привет 世界\n\nA **bold** line.\n";
	char directory[] = "/tmp/multimarkdown-XXXXXX", missing[1024];
	if (!mkdtemp(directory)) return 2;
	snprintf(missing, sizeof(missing), "%s/missing/output", directory);
	int before = descriptors();
	for (int iteration = 0; iteration < 20; iteration++) {
		thread_stdin = tmpfile(); thread_stdout = tmpfile(); thread_stderr = tmpfile();
		if (!thread_stdin || !thread_stdout || !thread_stderr) return 2;
		int input_fd = fileno(thread_stdin);
		fputs(input, thread_stdin); rewind(thread_stdin);
		char *bad[] = {"multimarkdown", "-o", missing, NULL};
		int status = multimarkdown_main(3, bad);
		fflush(thread_stderr); rewind(thread_stderr);
		char error[1024] = {0}; fread(error, 1, sizeof(error) - 1, thread_stderr);
		fprintf(stderr, "ERROR iteration=%d status=%d captured=%d\n", iteration, status, strstr(error, bad[2]) != NULL);
		if (status != 1 || !strstr(error, bad[2]) || fcntl(input_fd, F_GETFD) == -1) return 3;
		rewind(thread_stdin);
		char *good[] = {"multimarkdown", NULL};
		status = multimarkdown_main(1, good);
		fflush(thread_stdout); rewind(thread_stdout);
		char output[1024] = {0}; fread(output, 1, sizeof(output) - 1, thread_stdout);
		int open = fcntl(input_fd, F_GETFD) != -1;
		fprintf(stderr, "RECOVERY iteration=%d status=%d exact=%d input_open=%d\n", iteration, status, strcmp(output, expected) == 0, open);
		if (status || strcmp(output, expected) || !open) return 4;
		fclose(thread_stdin); fclose(thread_stdout); fclose(thread_stderr);
	}
	int after = descriptors();
	rmdir(directory);
	fprintf(stderr, "DESCRIPTORS before=%d after=%d\n", before, after);
	return after == before ? 0 : 5;
}
