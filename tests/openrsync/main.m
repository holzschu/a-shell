#import <Foundation/Foundation.h>
#import <ios_system/ios_system.h>
#include <errno.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <poll.h>
#include <pthread.h>
#include <signal.h>
#include <stdatomic.h>
#include <sys/stat.h>
#include <unistd.h>

static char session[] = "openrsync-acceptance";
static FILE *input, *output;
static NSString *cancel_command;
static int cancel_status;
static volatile sig_atomic_t other_interrupts;

static void
other_interrupt(int sig)
{
	(void)sig;
	other_interrupts++;
}
static atomic_bool transfer_finished;
static char other_session[] = "openrsync-other-session";
static NSString *other_command;
static int daemon_listener;
static atomic_bool daemon_accepted, daemon_closed;

static void *
daemon_peer(void *unused)
{
	(void)unused;
	int fd = accept(daemon_listener, NULL, NULL);
	close(daemon_listener);
	if (fd < 0) return NULL;
	atomic_store(&daemon_accepted, true);
	char bytes[256];
	struct pollfd peer = { .fd = fd, .events = POLLIN };
	while (poll(&peer, 1, 3000) > 0) {
		ssize_t count = read(fd, bytes, sizeof(bytes));
		if (count == 0) { atomic_store(&daemon_closed, true); break; }
		if (count < 0) break;
	}
	close(fd);
	return NULL;
}

static int
command(NSString *text)
{
	ios_switchSession(session);
	ios_setContext(session);
	joinMainThread = true;
	ios_setStreams(input, output, stderr);
	thread_stdin = input;
	thread_stdout = output;
	thread_stderr = stderr;
	return ios_system(text.UTF8String);
}

static int
fd_count(void)
{
	int count = 0;
	for (int fd = 0; fd < getdtablesize(); fd++)
		if (fcntl(fd, F_GETFD) != -1) count++;
	return count;
}

static void *
transfer(void *unused)
{
	(void)unused;
	@autoreleasepool {
		cancel_status = command(cancel_command);
		atomic_store(&transfer_finished, true);
	}
	return NULL;
}

static void *
other_transfer(void *unused)
{
	(void)unused;
	@autoreleasepool {
		ios_switchSession(other_session);
		ios_setContext(other_session);
		joinMainThread = true;
		ios_setStreams(input, output, stderr);
		thread_stdin = input;
		thread_stdout = output;
		thread_stderr = stderr;
		ios_system(other_command.UTF8String);
	}
	return NULL;
}

int
main(int argc, char **argv)
{
	@autoreleasepool {
		if (argc != 2) return 2;
		alarm(180);
		/* Consumers may retain command images across invocations. */
		for (NSString *name in @[@"openrsync", @"openrsyncA"]) {
			NSString *path = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.framework/%@", name, name]];
			if (!dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_GLOBAL)) return 22;
		}
		NSString *root = [NSString stringWithUTF8String:argv[1]];
		NSFileManager *files = NSFileManager.defaultManager;
		NSString *source = [root stringByAppendingPathComponent:@"source with spaces"];
		NSString *destination = [root stringByAppendingPathComponent:@"destination"];
		NSString *large = [root stringByAppendingPathComponent:@"cancel-source"];
		for (NSString *path in @[source, destination, large])
			if (![files createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil]) return 3;
		input = tmpfile();
		output = tmpfile();
		if (!input || !output) return 4;
		if (command(@"openrsync --version") != 0) return 5;
		/* Warm the runtime's first-dispatch logging connection before the census. */
		NSTimeInterval started = NSProcessInfo.processInfo.systemUptime;
		NSString *peer = [NSString stringWithFormat:@"openrsync -e protocol-peer invalid:/source \"%@/\"", destination];
		int rejected = command(peer);
		NSTimeInterval elapsed = NSProcessInfo.processInfo.systemUptime - started;
		fprintf(stderr, "OPENRSYNC_COMPATIBILITY status=%d elapsed=%.3f\n", rejected, elapsed);
		if (rejected != 2 || elapsed >= 2.0) return 20;
		if (command(@"openrsync --bwlimit=bogus a b") == 0) return 21;
		int before = fd_count();
		struct sigaction prior = { .sa_handler = other_interrupt }, original, after;
		sigemptyset(&prior.sa_mask);
		if (sigaction(SIGINT, &prior, &original) != 0) return 6;
		NSString *large_file = [large stringByAppendingPathComponent:@"large"];
		int fd = open(large_file.fileSystemRepresentation, O_CREAT | O_TRUNC | O_WRONLY, 0600);
		if (fd < 0) return 7;
		int truncated = ftruncate(fd, 64 * 1024 * 1024);
		close(fd);
		if (truncated != 0) return 7;
		daemon_listener = socket(AF_INET, SOCK_STREAM, 0);
		struct sockaddr_in address = { .sin_len = sizeof(address), .sin_family = AF_INET,
		    .sin_addr.s_addr = htonl(INADDR_LOOPBACK) };
		socklen_t address_size = sizeof(address);
		if (daemon_listener < 0 || bind(daemon_listener, (void *)&address, sizeof(address)) != 0 ||
		    listen(daemon_listener, 1) != 0 || getsockname(daemon_listener, (void *)&address, &address_size) != 0) return 31;
		pthread_t daemon, daemon_transfer;
		if (pthread_create(&daemon, NULL, daemon_peer, NULL) != 0) return 31;
		cancel_command = [NSString stringWithFormat:@"openrsync -r rsync://127.0.0.1:%u/module/ \"%@/\"", ntohs(address.sin_port), destination];
		if (pthread_create(&daemon_transfer, NULL, transfer, NULL) != 0) return 31;
		for (int attempt = 0; attempt < 500 && !atomic_load(&daemon_accepted); attempt++) usleep(10000);
		if (!atomic_load(&daemon_accepted)) return 31;
		ios_switchSession(session);
		ios_setContext(session);
		ios_kill();
		if (pthread_join(daemon_transfer, NULL) != 0 || cancel_status != 130) return 32;
		for (int attempt = 0; attempt < 100 && !atomic_load(&daemon_closed); attempt++) usleep(10000);
		if (!atomic_load(&daemon_closed) || pthread_join(daemon, NULL) != 0 || fd_count() != before) return 32;
		fprintf(stderr, "OPENRSYNC_DAEMON_CANCEL status=130 peer_closed=1\n");
		for (int pass = 0; pass < 20; pass++) {
			FILE *next_output = tmpfile();
			if (!next_output) return 23;
			fclose(output);
			output = next_output;
			NSData *expected = [[NSString stringWithFormat:@"transfer %d Привет 世界\n", pass] dataUsingEncoding:NSUTF8StringEncoding];
			NSString *name = @"payload 世界.txt";
			if (![expected writeToFile:[source stringByAppendingPathComponent:name] atomically:YES]) return 8;
			NSString *copy = [NSString stringWithFormat:@"openrsync -rc \"%@/\" \"%@/\"", source, destination];
			if (pass == 0) {
				NSString *filtered = [NSString stringWithFormat:@"openrsync -rc --exclude=*.txt \"%@/\" \"%@/\"", source, destination];
				if (command(filtered) != 0 || [files fileExistsAtPath:[destination stringByAppendingPathComponent:name]]) return 30;
			}
			int status = command(copy);
			if (status != 0 || ![expected isEqualToData:[NSData dataWithContentsOfFile:[destination stringByAppendingPathComponent:name]]]) return 9;
			NSString *pulled = [root stringByAppendingPathComponent:[NSString stringWithFormat:@"pulled-%d", pass]];
			if (![files createDirectoryAtPath:pulled withIntermediateDirectories:YES attributes:nil error:nil]) return 28;
			NSString *pull = [NSString stringWithFormat:@"openrsync -rc -e local-transport \"localhost:%@/\" \"%@/\"", source, pulled];
			if (command(pull) != 0 || ![expected isEqualToData:[NSData dataWithContentsOfFile:[pulled stringByAppendingPathComponent:name]]]) return 28;
			NSString *missing = [NSString stringWithFormat:@"openrsync -rc \"%@/missing\" \"%@/\"", root, destination];
			if (command(missing) != 23) return 10;
			NSString *cancel_destination = [root stringByAppendingPathComponent:[NSString stringWithFormat:@"cancel-%d", pass]];
			if (![files createDirectoryAtPath:cancel_destination withIntermediateDirectories:YES attributes:nil error:nil]) return 11;
			cancel_command = [NSString stringWithFormat:@"openrsync -r --bwlimit=64 \"%@/\" \"%@/\"", large, cancel_destination];
			atomic_store(&transfer_finished, false);
			pthread_t worker;
			if (pthread_create(&worker, NULL, transfer, NULL) != 0) return 12;
			BOOL started = NO;
			for (int attempt = 0; attempt < 500 && !started; attempt++) {
				for (NSString *name in [files contentsOfDirectoryAtPath:cancel_destination error:nil]) {
					struct stat st;
					NSString *path = [cancel_destination stringByAppendingPathComponent:name];
					if (stat(path.fileSystemRepresentation, &st) == 0 && S_ISREG(st.st_mode)) started = YES;
				}
				if (!started) usleep(10000);
			}
			if (!started) return 13;
			if (pass == 0) {
				NSString *marker = [root stringByAppendingPathComponent:@"other-ready"];
				other_command = [NSString stringWithFormat:@"waiting-command \"%@\"", marker];
				pthread_t other;
				if (pthread_create(&other, NULL, other_transfer, NULL) != 0) return 24;
				for (int attempt = 0; attempt < 500 && ![files fileExistsAtPath:marker]; attempt++) usleep(10000);
				if (![files fileExistsAtPath:marker]) return 25;
				ios_switchSession(other_session);
				ios_setContext(other_session);
				ios_kill();
				if (pthread_join(other, NULL) != 0) return 26;
				if (other_interrupts != 1) return 29;
				usleep(1000000);
				if (atomic_load(&transfer_finished)) return 27;
				ios_closeSession(other_session);
				fprintf(stderr, "OPENRSYNC_OTHER_SESSION preserved=1\n");
			}
			ios_switchSession(session);
			ios_setContext(session);
			int interrupted = ios_kill();
			if (pthread_join(worker, NULL) != 0) return 14;
			/* v3.0.5 returns ESRCH after calling a custom SIGINT handler. */
			if ((interrupted != 0 && interrupted != ESRCH) || cancel_status != 130) return 15;
			if (sigaction(SIGINT, NULL, &after) != 0 || prior.sa_handler != after.sa_handler) return 16;
			expected = [[NSString stringWithFormat:@"recovery %d Привет 世界\n", pass] dataUsingEncoding:NSUTF8StringEncoding];
			if (![expected writeToFile:[source stringByAppendingPathComponent:name] atomically:YES]) return 17;
			if (command(copy) != 0 || ![expected isEqualToData:[NSData dataWithContentsOfFile:[destination stringByAppendingPathComponent:name]]]) return 17;
			if (fcntl(fileno(input), F_GETFD) == -1 || fcntl(fileno(output), F_GETFD) == -1) return 18;
			fprintf(stderr, "OPENRSYNC_PASS iteration=%d copy=0 missing=23 cancel=130 recovery=0 signal_restored=1\n", pass + 1);
		}
		int remaining = fd_count();
		fprintf(stderr, "OPENRSYNC_FDS before=%d after=%d\n", before, remaining);
		if (remaining != before) return 19;
		ios_closeSession(session);
		sigaction(SIGINT, &original, NULL);
		fclose(input);
		fclose(output);
		alarm(0);
		fprintf(stderr, "OPENRSYNC_ACCEPTANCE_PASSED\n");
		return 0;
	}
}
