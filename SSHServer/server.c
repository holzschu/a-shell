#include <libssh/libssh.h>
#include <libssh/server.h>
#include <libssh/callbacks.h>
#include <arpa/inet.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <ifaddrs.h>
#include <limits.h>
#include <poll.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include "NativePane.h"

extern __thread FILE *thread_stdout, *thread_stderr;
extern char *ios_getenv(const char *);
extern pid_t ios_currentPid(void);
extern char **environmentVariables(pid_t);

// All pane operations for a connection belong to its one session thread.
static struct {
    int (*spawn)(const char *, const char *, unsigned, unsigned, const char *const *, ashell_pane_options *, int *, void **);
    int (*poll)(void *, int *);
    int (*resize)(void *, unsigned, unsigned);
    int (*close_stdin)(void *);
    int (*interrupt)(void *);
    void (*release)(void *);
    void (*status)(int, int, const char *, void (*)(void));
} host;

enum { MAX_CLIENTS = 4, BUFFER_SIZE = 16384, PORT = 2222 };
typedef struct {
    pthread_t thread;
    int used, finished, fd;
    atomic_int active;
    ssh_session session;
    ssh_channel channel;
    struct ssh_channel_callbacks_struct callbacks;
    int authenticated, attempts, tty, cols, rows, pane_fd, error_fd;
    char term[128];
    void *pane;
} Client;

static pthread_mutex_t control = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t clients_lock = PTHREAD_MUTEX_INITIALIZER;
static atomic_int running;
static pthread_t listener_thread;
static pthread_once_t library_once = PTHREAD_ONCE_INIT;
static int library_error;
static ssh_bind listener;
static Client clients[MAX_CLIENTS];
static char home[PATH_MAX], documents[PATH_MAX], authorized[PATH_MAX], account[128];
static char **server_environment;
static char fingerprint[128];
static void stop_from_indicator(void);

static void free_environment(void) {
    if (!server_environment) return;
    for (size_t i = 0; server_environment[i]; i++) free(server_environment[i]);
    free(server_environment);
    server_environment = NULL;
}

static int capture_environment(void) {
    char **source = environmentVariables(ios_currentPid());
    if (!source) return EINVAL;
    size_t count = 0;
    while (source[count]) count++;
    server_environment = calloc(count + 1, sizeof(*server_environment));
    if (!server_environment) return ENOMEM;
    for (size_t i = 0; i < count; i++) {
        server_environment[i] = strdup(source[i]);
        if (!server_environment[i]) { free_environment(); return ENOMEM; }
    }
    return 0;
}

static void initialize_library(void) { library_error = ssh_init(); }

static void indicator_locked(void) {
    int count = 0;
    for (int i = 0; i < MAX_CLIENTS; i++) count += clients[i].used && !clients[i].finished && atomic_load(&clients[i].active);
    if (host.status) host.status(atomic_load(&running) ? count : -1, PORT, fingerprint, stop_from_indicator);
}

static void indicator(void) {
    pthread_mutex_lock(&clients_lock);
    indicator_locked();
    pthread_mutex_unlock(&clients_lock);
}

static int private_file(const char *path, mode_t type, mode_t mask) {
    struct stat st;
    return lstat(path, &st) == 0 && (st.st_mode & S_IFMT) == type &&
        st.st_uid == getuid() && !(st.st_mode & mask);
}

static int allowed_key(ssh_key offered) {
    // Options and certificates need their own enforcement; reject them rather than ignore them.
    char directory[PATH_MAX];
    snprintf(directory, sizeof(directory), "%s/.ssh", documents);
    if (!private_file(directory, S_IFDIR, 0077)) return 0;
    int fd = open(authorized, O_RDONLY | O_NOFOLLOW | O_NONBLOCK);
    if (fd < 0) return 0;
    struct stat st;
    if (fstat(fd, &st) || !S_ISREG(st.st_mode) || st.st_uid != getuid() ||
        (st.st_mode & 0077) || st.st_size > 65536) { close(fd); return 0; }
    FILE *file = fdopen(fd, "r");
    if (!file) { close(fd); return 0; }
    char line[8192];
    int found = 0;
    while (fgets(line, sizeof(line), file)) {
        if (!strchr(line, '\n') && !feof(file)) break;
        char *save = NULL, *type = strtok_r(line, " \t\r\n", &save);
        if (!type || *type == '#') continue;
        enum ssh_keytypes_e kind = ssh_key_type_from_name(type);
        if (kind != SSH_KEYTYPE_ED25519 && kind != SSH_KEYTYPE_RSA &&
            kind != SSH_KEYTYPE_ECDSA_P256 && kind != SSH_KEYTYPE_ECDSA_P384 &&
            kind != SSH_KEYTYPE_ECDSA_P521) continue;
        char *data = strtok_r(NULL, " \t\r\n", &save);
        ssh_key key = NULL;
        if (data && ssh_pki_import_pubkey_base64(data, kind, &key) == SSH_OK) {
            found = ssh_key_cmp(key, offered, SSH_KEY_CMP_PUBLIC) == 0;
            ssh_key_free(key);
            if (found) break;
        }
    }
    fclose(file);
    return found;
}

static int authenticate(ssh_session session, const char *user, ssh_key key, char state, void *data) {
    (void)session;
    Client *c = data;
    c->attempts++;
    if (strcmp(user, account) || (state != SSH_PUBLICKEY_STATE_NONE && state != SSH_PUBLICKEY_STATE_VALID) || !allowed_key(key)) return SSH_AUTH_DENIED;
    if (state == SSH_PUBLICKEY_STATE_VALID) c->authenticated = 1;
    return SSH_AUTH_SUCCESS;
}

static int dimensions(int cols, int rows) { return cols > 0 && cols <= 9999 && rows > 0 && rows <= 9999; }

static int pty_request(ssh_session s, ssh_channel ch, const char *term, int cols, int rows, int x, int y, void *data) {
    (void)s; (void)ch; (void)x; (void)y;
    Client *c = data;
    if (!cols) cols = 80;
    if (!rows) rows = 24;
    if (c->pane || !dimensions(cols, rows) || !term || strlen(term) >= sizeof(c->term)) return -1;
    for (const char *p = term; *p; p++) if ((unsigned char)*p < 32 || (unsigned char)*p >= 127) return -1;
    c->tty = 1; c->cols = cols; c->rows = rows;
    strcpy(c->term, term);
    return 0;
}

static int resize(ssh_session s, ssh_channel ch, int cols, int rows, int x, int y, void *data) {
    (void)s; (void)ch; (void)x; (void)y;
    Client *c = data;
    if (!dimensions(cols, rows)) return -1;
    c->cols = cols; c->rows = rows;
    return c->pane ? (host.resize(c->pane, cols, rows) ? -1 : 0) : 0;
}

static int start_pane(Client *c, const char *command) {
    if (c->pane) return 1;
    char home_env[PATH_MAX + 6], term_env[sizeof(c->term) + 6];
    snprintf(home_env, sizeof(home_env), "HOME=%s", home);
    snprintf(term_env, sizeof(term_env), "TERM=%s", c->term);
    size_t count = 0, used = 0;
    while (server_environment[count]) count++;
    const char **env = calloc(count + 4, sizeof(*env));
    if (!env) return 1;
    const char *host_commands = "";
    for (size_t i = 0; i < count; i++) {
        if (!strncmp(server_environment[i], "ASHELL_HOST_COMMANDS=", 21)) host_commands = server_environment[i] + 21;
        else if (strncmp(server_environment[i], "HOME=", 5) && strncmp(server_environment[i], "TERM=", 5)) env[used++] = server_environment[i];
    }
    char *host_env = NULL;
    if (asprintf(&host_env, "ASHELL_HOST_COMMANDS=%s codex", host_commands) < 0) { free(env); return 1; }
    env[used++] = home_env; env[used++] = term_env; env[used] = host_env;
    ashell_pane_options options = {.size = sizeof(options), .tty = c->tty, .separate_stderr = !c->tty};
    int error = host.spawn(command, documents, c->cols, c->rows, env, &options, &c->pane_fd, &c->pane);
    free(host_env);
    free(env);
    if (error) return 1;
    c->error_fd = options.stderr_fd;
    atomic_store(&c->active, 1);
    indicator();
    fcntl(c->pane_fd, F_SETFL, fcntl(c->pane_fd, F_GETFL) | O_NONBLOCK);
    if (c->error_fd >= 0) fcntl(c->error_fd, F_SETFL, fcntl(c->error_fd, F_GETFL) | O_NONBLOCK);
    return 0;
}

static int shell_request(ssh_session s, ssh_channel ch, void *data) {
    (void)s; (void)ch;
    return start_pane(data, "dash -i");
}

static int exec_request(ssh_session s, ssh_channel ch, const char *command, void *data) {
    (void)s; (void)ch;
    if (strlen(command) > 65536) return 1;
    char *quoted = malloc(strlen(command) * 4 + 12);
    if (!quoted) return 1;
    char *p = stpcpy(quoted, "dash -c '");
    for (; *command; command++) {
        if (*command == '\'') p = stpcpy(p, "'\\''");
        else *p++ = *command;
    }
    *p++ = '\''; *p = 0;
    int result = start_pane(data, quoted);
    free(quoted);
    return result;
}

static void signal_request(ssh_session s, ssh_channel ch, const char *name, void *data) {
    (void)s; (void)ch;
    Client *c = data;
    if (c->pane && !strcmp(name, "INT")) {
        int result = host.interrupt(c->pane);
        if (result == ENOTSUP) { char etx = 3; (void)write(c->pane_fd, &etx, 1); }
    }
}

static ssh_channel open_channel(ssh_session session, void *data) {
    Client *c = data;
    if (!c->authenticated || c->channel) return NULL;
    c->channel = ssh_channel_new(session);
    if (c->channel) ssh_set_channel_callbacks(c->channel, &c->callbacks);
    return c->channel;
}

typedef struct { unsigned char bytes[BUFFER_SIZE]; size_t offset, length; int eof; } Buffer;

static int send_output(Client *c, int fd, int error_stream, Buffer *b) {
    if (!b->length && !b->eof) {
        ssize_t n = read(fd, b->bytes, sizeof(b->bytes));
        if (!n) b->eof = 1;
        else if (n > 0) { b->offset = 0; b->length = n; }
        else if (errno != EAGAIN && errno != EINTR) return -1;
    }
    if (b->length) {
        int n = error_stream ? ssh_channel_write_stderr(c->channel, b->bytes + b->offset, (uint32_t)b->length) : ssh_channel_write(c->channel, b->bytes + b->offset, (uint32_t)b->length);
        if (n == SSH_ERROR) return -1;
        if (n > 0) { b->offset += n; b->length -= n; }
    }
    return 0;
}

static void *serve_client(void *data) {
    Client *c = data;
    ssh_session session = c->session;
    struct ssh_server_callbacks_struct callbacks = {.userdata = c, .auth_pubkey_function = authenticate, .channel_open_request_session_function = open_channel};
    c->callbacks = (struct ssh_channel_callbacks_struct){.userdata = c, .channel_pty_request_function = pty_request, .channel_pty_window_change_function = resize, .channel_shell_request_function = shell_request, .channel_exec_request_function = exec_request, .channel_signal_function = signal_request};
    ssh_callbacks_init(&callbacks);
    ssh_callbacks_init(&c->callbacks);
    ssh_set_server_callbacks(session, &callbacks);
    ssh_set_auth_methods(session, SSH_AUTH_METHOD_PUBLICKEY);
    ssh_event event = ssh_event_new();
    if (!event || ssh_handle_key_exchange(session) != SSH_OK) goto done;
    ssh_set_blocking(session, 0);
    ssh_event_add_session(event, session);
    time_t deadline = time(NULL) + 15;
    Buffer input = {0}, output = {0}, errors = {0};
    int input_closed = 0, status = 0, exited = 0, transport_error = 0;
    while (atomic_load(&running) && ssh_is_connected(session)) {
        if (ssh_event_dopoll(event, 20) == SSH_ERROR) break;
        if (!c->pane) { if (time(NULL) >= deadline || c->attempts > 12) break; continue; }
        if (!ssh_channel_is_open(c->channel)) break;
        if (!input.length && !input.eof) {
            int n = ssh_channel_read_nonblocking(c->channel, input.bytes, sizeof(input.bytes), 0);
            if (n == SSH_ERROR) break;
            if (n > 0) { input.offset = 0; input.length = n; }
            if (ssh_channel_is_eof(c->channel)) input.eof = 1;
        }
        if (input.length) {
            ssize_t n = write(c->pane_fd, input.bytes + input.offset, input.length);
            if (n > 0) { input.offset += n; input.length -= n; }
            else if (n < 0 && errno != EAGAIN && errno != EINTR) break;
        }
        if (input.eof && !input.length && !input_closed) { host.close_stdin(c->pane); input_closed = 1; }
        if (send_output(c, c->pane_fd, 0, &output)) break;
        if (c->error_fd >= 0 || errors.length) {
            if (send_output(c, c->error_fd, 1, &errors)) break;
        } else errors.eof = 1;
        if (!exited) {
            int result = host.poll(c->pane, &status);
            if (result < 0) { transport_error = -result; status = 125; exited = 1; }
            else exited = result;
        }
        if (exited && output.eof && errors.eof && !output.length && !errors.length) {
            if (transport_error) {
                snprintf((char *)errors.bytes, sizeof(errors.bytes), "sshd: shell worker connection lost: %s\n", strerror(transport_error));
                errors.offset = 0; errors.length = strlen((char *)errors.bytes);
                transport_error = 0;
                continue;
            }
            ssh_channel_request_send_exit_status(c->channel, status);
            ssh_channel_send_eof(c->channel);
            ssh_channel_close(c->channel);
            break;
        }
    }
done:
    if (c->pane) host.release(c->pane);
    if (c->pane_fd >= 0) close(c->pane_fd);
    if (c->error_fd >= 0) close(c->error_fd);
    if (c->channel) ssh_channel_free(c->channel);
    if (event) ssh_event_free(event);
    // stop only shuts down descriptors while holding this lock; this thread closes them.
    pthread_mutex_lock(&clients_lock);
    c->fd = -1;
    ssh_disconnect(session);
    ssh_free(session);
    c->finished = 1;
    indicator_locked();
    pthread_mutex_unlock(&clients_lock);
    return NULL;
}

static void *accept_clients(void *unused) {
    (void)unused;
    int socket = ssh_bind_get_fd(listener);
    while (atomic_load(&running)) {
        struct pollfd p = {.fd = socket, .events = POLLIN};
        if (poll(&p, 1, 100) <= 0 || !(p.revents & POLLIN)) continue;
        int fd = accept(socket, NULL, NULL);
        if (fd < 0) continue;
        int one = 1;
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
        pthread_mutex_lock(&clients_lock);
        Client *c = NULL;
        for (int i = 0; i < MAX_CLIENTS; i++) {
            if (clients[i].used && clients[i].finished) { pthread_join(clients[i].thread, NULL); clients[i].used = 0; }
            if (!clients[i].used && !c) c = &clients[i];
        }
        if (!c) { close(fd); pthread_mutex_unlock(&clients_lock); continue; }
        *c = (Client){.fd = fd, .pane_fd = -1, .error_fd = -1, .cols = 80, .rows = 24};
        strcpy(c->term, "xterm-256color");
        c->session = ssh_new();
        long timeout = 5;
        if (!c->session || ssh_options_set(c->session, SSH_OPTIONS_TIMEOUT, &timeout) != SSH_OK || ssh_bind_accept_fd(listener, c->session, fd) != SSH_OK) {
            if (c->session) ssh_free(c->session); else close(fd);
            pthread_mutex_unlock(&clients_lock); continue;
        }
        c->used = 1;
        if (pthread_create(&c->thread, NULL, serve_client, c)) { ssh_free(c->session); c->used = 0; }
        pthread_mutex_unlock(&clients_lock);
        indicator();
    }
    return NULL;
}

static void stop_server(void) {
    if (!atomic_exchange(&running, 0)) return;
    pthread_join(listener_thread, NULL);
    ssh_bind_free(listener); listener = NULL;
    pthread_mutex_lock(&clients_lock);
    for (int i = 0; i < MAX_CLIENTS; i++) if (clients[i].used && clients[i].fd >= 0) shutdown(clients[i].fd, SHUT_RDWR);
    pthread_mutex_unlock(&clients_lock);
    for (int i = 0; i < MAX_CLIENTS; i++) if (clients[i].used) { pthread_join(clients[i].thread, NULL); clients[i].used = 0; }
    free_environment();
    indicator();
}

static void stop_from_indicator(void) {
    pthread_mutex_lock(&control);
    stop_server();
    pthread_mutex_unlock(&control);
}

static int start_server(void) {
    pthread_once(&library_once, initialize_library);
    if (library_error != SSH_OK) return EIO;
#define LOAD(field, suffix) do { \
    *(void **)(&host.field) = dlsym(RTLD_DEFAULT, "ashell_pane_" suffix); \
    if (!host.field) return ENOTSUP; \
} while (0)
    LOAD(spawn, "spawn_ex"); LOAD(poll, "poll");
    LOAD(resize, "resize"); LOAD(close_stdin, "close_stdin");
    LOAD(interrupt, "interrupt"); LOAD(release, "release");
    *(void **)(&host.status) = dlsym(RTLD_DEFAULT, "ashell_sshd_status");
#undef LOAD
    const char *value = ios_getenv("HOME");
    if (!value || strlen(value) + 48 >= sizeof(home)) return EINVAL;
    strcpy(home, value);
    snprintf(documents, sizeof(documents), "%s/Documents", home);
    snprintf(authorized, sizeof(authorized), "%s/.ssh/authorized_keys", documents);
    value = ios_getenv("USER");
    if (!value || !*value) value = "mobile";
    if (strlen(value) >= sizeof(account)) return EINVAL;
    strcpy(account, value);
    char directory[PATH_MAX], host_key_path[PATH_MAX];
    snprintf(directory, sizeof(directory), "%s/.ssh", documents);
    if (mkdir(directory, 0700) && errno != EEXIST) return errno;
    if (!private_file(directory, S_IFDIR, 0077) || !private_file(authorized, S_IFREG, 0077)) return EACCES;
    snprintf(host_key_path, sizeof(host_key_path), "%s/ssh_host_ed25519_key", directory);
    ssh_key key = NULL;
    if (access(host_key_path, F_OK)) {
        if (errno != ENOENT || ssh_pki_generate_key(SSH_KEYTYPE_ED25519, NULL, &key) != SSH_OK) return EIO;
        char *pem = NULL;
        if (ssh_pki_export_privkey_base64(key, NULL, NULL, NULL, &pem) != SSH_OK) { ssh_key_free(key); return EIO; }
        int fd = open(host_key_path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
        size_t length = strlen(pem), written = 0;
        if (fd >= 0) while (written < length) { ssize_t n = write(fd, pem + written, length - written); if (n <= 0) break; written += n; }
        int error = fd < 0 ? errno : written != length ? EIO : 0;
        if (fd >= 0) { if (fsync(fd) && !error) error = errno; close(fd); if (error) unlink(host_key_path); }
        ssh_string_free_char(pem);
        if (error) { ssh_key_free(key); return error; }
    } else {
        if (!private_file(host_key_path, S_IFREG, 0077) || ssh_pki_import_privkey_file(host_key_path, NULL, NULL, NULL, &key) != SSH_OK) return EACCES;
    }
    unsigned char *hash = NULL;
    size_t hash_length = 0;
    char *formatted = NULL;
    if (ssh_get_publickey_hash(key, SSH_PUBLICKEY_HASH_SHA256, &hash, &hash_length) == SSH_OK)
        formatted = ssh_get_fingerprint_hash(SSH_PUBLICKEY_HASH_SHA256, hash, hash_length);
    ssh_clean_pubkey_hash(&hash);
    if (!formatted || strlen(formatted) >= sizeof(fingerprint)) {
        ssh_string_free_char(formatted); ssh_key_free(key); return EIO;
    }
    strcpy(fingerprint, formatted);
    ssh_string_free_char(formatted);
    listener = ssh_bind_new();
    int port = PORT, no = 0;
    int ok = listener && ssh_bind_options_set(listener, SSH_BIND_OPTIONS_PROCESS_CONFIG, &no) == SSH_OK &&
        ssh_bind_options_set(listener, SSH_BIND_OPTIONS_BINDADDR, "0.0.0.0") == SSH_OK &&
        ssh_bind_options_set(listener, SSH_BIND_OPTIONS_BINDPORT, &port) == SSH_OK;
    if (ok) {
        ok = ssh_bind_options_set(listener, SSH_BIND_OPTIONS_IMPORT_KEY, key) == SSH_OK;
        if (ok) { key = NULL; ok = ssh_bind_listen(listener) == SSH_OK; }
    }
    ssh_key_free(key);
    if (!ok) { if (listener) ssh_bind_free(listener); listener = NULL; return EIO; }
    int error = capture_environment();
    if (error) { ssh_bind_free(listener); listener = NULL; return error; }
    atomic_store(&running, 1);
    error = pthread_create(&listener_thread, NULL, accept_clients, NULL);
    if (error) { atomic_store(&running, 0); ssh_bind_free(listener); listener = NULL; free_environment(); return error; }
    indicator();
    return 0;
}

int ashell_sshd_main(int argc, char **argv) {
    pthread_mutex_lock(&control);
    const char *command = argc == 2 ? argv[1] : "help";
    int error = 0;
    if (!strcmp(command, "off")) { stop_server(); fprintf(thread_stdout, "sshd: stopped\n"); }
    else if (!strcmp(command, "on") || !strcmp(command, "status")) {
        if (!strcmp(command, "on") && !atomic_load(&running)) error = start_server();
        if (error) fprintf(thread_stderr, "sshd: %s%s\n", strerror(error),
            error == EACCES ? " (require Documents/.ssh mode 700 and authorized_keys mode 600)" : "");
        else if (!atomic_load(&running)) fprintf(thread_stdout, "sshd: stopped (default)\n");
        else {
            fprintf(thread_stdout, "sshd: listening; key-only; user %s; port %d\n", account, PORT);
            struct ifaddrs *interfaces = NULL;
            if (!getifaddrs(&interfaces)) {
                for (struct ifaddrs *p = interfaces; p; p = p->ifa_next) if (p->ifa_addr && p->ifa_addr->sa_family == AF_INET) {
                    char address[INET_ADDRSTRLEN];
                    if (inet_ntop(AF_INET, &((struct sockaddr_in *)p->ifa_addr)->sin_addr, address, sizeof(address))) fprintf(thread_stdout, "ssh -p %d %s@%s\n", PORT, account, address);
                }
                freeifaddrs(interfaces);
            }
        }
    } else { fprintf(thread_stdout, "usage: sshd on|off|status\nOff by default. Uses Documents/.ssh/authorized_keys (plain public keys only).\n"); error = 64; }
    pthread_mutex_unlock(&control);
    return error ? 1 : 0;
}
