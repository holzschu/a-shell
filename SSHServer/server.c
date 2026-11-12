#include <libssh/libssh.h>
#include <libssh/server.h>
#include <libssh/callbacks.h>
#include <arpa/inet.h>
#include <dlfcn.h>
#include <dispatch/dispatch.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <netdb.h>
#include <net/if.h>
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
#include <uuid/uuid.h>
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
    void (*state)(int, int, const char *, const char *, const char *, int, const char *const *, const char *const *, const long long *, const int *, const char *const *, const char *const *, const char *const *, void (*)(void));
    void (*event)(const char *, const char *, const char *, const char *, const char *, const char *, long long, const char *, int);
} host;

enum { MAX_CLIENTS = 4, BUFFER_SIZE = 16384, PORT = 2222 };
typedef struct {
    pthread_t thread;
    int used, finished, fd;
    atomic_int active;
    ssh_session session;
    ssh_channel channel;
    struct ssh_channel_callbacks_struct callbacks;
    int authenticated, attempts, tty, cols, rows, pane_fd, error_fd, channel_closed;
    char term[128];
    char peer[INET6_ADDRSTRLEN + 8], user[64], command[256];
    char key_comment[65], key_fingerprint[128], identifier[37];
    int exit_status;
    time_t since;
    int kind;
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
static int listen_port = PORT;
static char listen_address[INET6_ADDRSTRLEN] = "0.0.0.0", config_path[PATH_MAX];
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

static void initialize_library(void) {
    library_error = ssh_init();
}

static void indicator_locked(void) {
    int count = 0;
    const char *peers[MAX_CLIENTS], *users[MAX_CLIENTS], *commands[MAX_CLIENTS], *key_names[MAX_CLIENTS], *key_fingerprints[MAX_CLIENTS];
    long long since[MAX_CLIENTS];
    int kinds[MAX_CLIENTS];
    for (int i = 0; i < MAX_CLIENTS; i++) {
        Client *c = &clients[i];
        if (!c->used || c->finished || !c->authenticated) continue;
        peers[count] = c->peer; users[count] = c->user; commands[count] = c->command;
        key_names[count] = c->key_comment; key_fingerprints[count] = c->key_fingerprint;
        since[count] = (long long)c->since; kinds[count] = c->kind; count++;
    }
    if (host.state) host.state(atomic_load(&running), listen_port, listen_address, fingerprint, account, count, peers, users, since, kinds, commands, key_names, key_fingerprints, stop_from_indicator);
}

static void client_event(Client *c, const char *phase, const char *text) {
    if (host.event) host.event(c->identifier, phase, c->key_comment, c->key_fingerprint, c->user, c->peer, (long long)time(NULL), text, c->exit_status);
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

static int allowed_key(ssh_key offered, char *comment, size_t size) {
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
            if (found) {
                char *rest = strtok_r(NULL, "\r\n", &save);
                size_t length = 0;
                if (rest) {
                    while (*rest == ' ' || *rest == '\t') rest++;
                    for (; *rest && length + 1 < size; rest++)
                        if ((unsigned char)*rest >= 32 && (unsigned char)*rest != 127) comment[length++] = *rest;
                }
                while (length && comment[length - 1] == ' ') length--;
                comment[length] = 0;
                break;
            }
        }
    }
    fclose(file);
    return found;
}

static int authenticate(ssh_session session, const char *user, ssh_key key, char state, void *data) {
    (void)session;
    Client *c = data;
    c->attempts++;
    char comment[65] = {0};
    if (strcmp(user, account) || (state != SSH_PUBLICKEY_STATE_NONE && state != SSH_PUBLICKEY_STATE_VALID) || !allowed_key(key, comment, sizeof(comment))) return SSH_AUTH_DENIED;
    if (state == SSH_PUBLICKEY_STATE_VALID) {
        unsigned char *hash = NULL;
        size_t length = 0;
        char *formatted = NULL;
        if (ssh_get_publickey_hash(key, SSH_PUBLICKEY_HASH_SHA256, &hash, &length) == SSH_OK)
            formatted = ssh_get_fingerprint_hash(SSH_PUBLICKEY_HASH_SHA256, hash, length);
        ssh_clean_pubkey_hash(&hash);
        if (!formatted || strlen(formatted) >= sizeof(c->key_fingerprint)) {
            ssh_string_free_char(formatted);
            return SSH_AUTH_DENIED;
        }
        pthread_mutex_lock(&clients_lock);
        c->authenticated = 1;
        snprintf(c->user, sizeof(c->user), "%s", user);
        snprintf(c->key_comment, sizeof(c->key_comment), "%s", comment);
        snprintf(c->key_fingerprint, sizeof(c->key_fingerprint), "%s", formatted);
        ssh_string_free_char(formatted);
        client_event(c, "auth", "");
        indicator_locked();
        pthread_mutex_unlock(&clients_lock);
    }
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
    char home_env[PATH_MAX + 6], term_env[sizeof(c->term) + 6], cols_env[32], rows_env[32];
    snprintf(home_env, sizeof(home_env), "HOME=%s", home);
    snprintf(term_env, sizeof(term_env), "TERM=%s", c->term);
    snprintf(cols_env, sizeof(cols_env), "COLUMNS=%u", c->cols);
    snprintf(rows_env, sizeof(rows_env), "LINES=%u", c->rows);
    size_t count = 0, used = 0;
    while (server_environment[count]) count++;
    const char **env = calloc(count + 6, sizeof(*env));
    if (!env) return 1;
    const char *host_commands = "";
    for (size_t i = 0; i < count; i++) {
        if (!strncmp(server_environment[i], "ASHELL_HOST_COMMANDS=", 21)) host_commands = server_environment[i] + 21;
        else if (strncmp(server_environment[i], "HOME=", 5) && strncmp(server_environment[i], "TERM=", 5) &&
            strncmp(server_environment[i], "COLUMNS=", 8) && strncmp(server_environment[i], "LINES=", 6) &&
            strncmp(server_environment[i], "PWD=", 4) && strncmp(server_environment[i], "OLDPWD=", 7)) env[used++] = server_environment[i];
    }
    char *host_env = NULL;
    if (asprintf(&host_env, "ASHELL_HOST_COMMANDS=%s codex", host_commands) < 0) { free(env); return 1; }
    env[used++] = home_env; env[used++] = term_env;
    env[used++] = cols_env; env[used++] = rows_env; env[used] = host_env;
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
    pthread_mutex_lock(&clients_lock);
    Client *c = data;
    if (c->kind) { pthread_mutex_unlock(&clients_lock); return 1; }
    c->kind = 1;
    pthread_mutex_unlock(&clients_lock);
    client_event(c, "shell", "");
    return start_pane(data, "dash -i");
}

static int exec_request(ssh_session s, ssh_channel ch, const char *command, void *data) {
    (void)s; (void)ch;
    if (strlen(command) > 65536) return 1;
    Client *c = data;
    pthread_mutex_lock(&clients_lock);
    if (c->kind) { pthread_mutex_unlock(&clients_lock); return 1; }
    c->kind = 2;
    snprintf(c->command, sizeof(c->command), "%s", command);
    for (char *p = c->command; *p; p++) if ((unsigned char)*p < 32 || *p == 127) *p = ' ';
    pthread_mutex_unlock(&clients_lock);
    client_event(c, "exec", c->command);
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

static void channel_closed(ssh_session s, ssh_channel ch, void *data) {
    (void)s; (void)ch;
    ((Client *)data)->channel_closed = 1;
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
    c->callbacks = (struct ssh_channel_callbacks_struct){.userdata = c, .channel_pty_request_function = pty_request, .channel_pty_window_change_function = resize, .channel_shell_request_function = shell_request, .channel_exec_request_function = exec_request, .channel_signal_function = signal_request, .channel_close_function = channel_closed};
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
            size_t length = input.length;
            unsigned char *etx = c->tty ? memchr(input.bytes + input.offset, 3, length) : NULL;
            if (etx) {
                length = (size_t)(etx - (input.bytes + input.offset));
                if (!length) {
                    int error = host.interrupt(c->pane);
                    if (error != ENOTSUP) { input.offset++; input.length--; continue; }
                    length = 1;
                }
            }
            ssize_t n = write(c->pane_fd, input.bytes + input.offset, length);
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
            c->exit_status = status;
            ssh_channel_request_send_exit_status(c->channel, status);
            ssh_channel_send_eof(c->channel);
            ssh_channel_close(c->channel);
            // Let the peer acknowledge close before disconnecting the transport.
            // Closing a socket with unread channel replies can reset the connection.
            struct timespec close_deadline, now;
            if (clock_gettime(CLOCK_MONOTONIC, &close_deadline) == 0) {
                close_deadline.tv_sec += 5;
                while (!c->channel_closed && atomic_load(&running) && ssh_is_connected(session)) {
                    if (clock_gettime(CLOCK_MONOTONIC, &now)) break;
                    long remaining = (close_deadline.tv_sec - now.tv_sec) * 1000 +
                        (close_deadline.tv_nsec - now.tv_nsec) / 1000000;
                    if (remaining <= 0) break;
                    if (ssh_event_dopoll(event, remaining < 100 ? (int)remaining : 100) == SSH_ERROR) break;
                }
            }
            break;
        }
    }
done:
    client_event(c, "end", "");
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
        struct sockaddr_storage address;
        socklen_t length = sizeof(address);
        int fd = accept(socket, (struct sockaddr *)&address, &length);
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
        *c = (Client){.fd = fd, .pane_fd = -1, .error_fd = -1, .cols = 80, .rows = 24, .exit_status = -1};
        uuid_t identifier;
        uuid_generate_random(identifier);
        uuid_unparse_lower(identifier, c->identifier);
        char peer[INET6_ADDRSTRLEN], port[6];
        if (!getnameinfo((struct sockaddr *)&address, length, peer, sizeof(peer), port, sizeof(port), NI_NUMERICHOST | NI_NUMERICSERV))
            snprintf(c->peer, sizeof(c->peer), address.ss_family == AF_INET6 ? "[%s]:%s" : "%s:%s", peer, port);
        c->since = time(NULL);
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

static int startup_failure(const char *stage, void *object, int error) {
    const char *detail = object ? ssh_get_error(object) : NULL;
    char message[1024];
    snprintf(message, sizeof(message), "sshd: %s failed%s%s (errno %d: %s)", stage,
            detail && *detail ? ": " : "", detail && *detail ? detail : "",
            error, error ? strerror(error) : "not set");
    fprintf(thread_stderr, "%s\n", message);
    void (*report)(const char *) = dlsym(RTLD_DEFAULT, "ashell_sshd_error");
    if (report) report(message);
    return 255;
}

static int startup_private_file(const char *path, mode_t type, mode_t mode) {
    struct stat st;
    if (lstat(path, &st)) return startup_failure(path, NULL, errno);
    if ((st.st_mode & S_IFMT) != type || st.st_uid != getuid())
        return startup_failure("check SSH file type and owner", NULL, EACCES);
    if (!(st.st_mode & 0077)) return 0;
    const char *display = path;
    char relative[PATH_MAX];
    if (!strncmp(path, home, strlen(home)) && path[strlen(home)] == '/') {
        snprintf(relative, sizeof(relative), "~%s", path + strlen(home));
        display = relative;
    }
    // Quote arbitrary user config paths without allowing shell substitution.
    char quoted[PATH_MAX * 4 + 4];
    size_t n = 0;
    const char *tail = display;
    if (tail[0] == '~' && tail[1] == '/') { quoted[n++] = *tail++; quoted[n++] = *tail++; }
    quoted[n++] = '\'';
    for (; *tail && n + 5 < sizeof(quoted); tail++) {
        if (*tail == '\'') { memcpy(quoted + n, "'\\''", 4); n += 4; }
        else quoted[n++] = *tail;
    }
    quoted[n++] = '\''; quoted[n] = 0;
    // a-Shell's command parser keeps quotes embedded after ~/ literally.
    // Simple paths need no quoting in either a-Shell or a POSIX shell.
    const char *plain = display;
    if (plain[0] == '~' && plain[1] == '/') plain += 2;
    if (strspn(plain, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./-") == strlen(plain))
        snprintf(quoted, sizeof(quoted), "%s", display);
    char message[PATH_MAX * 5 + 256];
    snprintf(message, sizeof(message), "sshd: %s has mode %03o; expected %03o. Run: chmod %03o %s",
        display, (unsigned)(st.st_mode & 0777), (unsigned)mode, (unsigned)mode, quoted);
    fprintf(thread_stderr, "%s\n", message);
    void (*report)(const char *) = dlsym(RTLD_DEFAULT, "ashell_sshd_error");
    if (report) report(message);
    return 255;
}

static int start_server(const char *configuration, int override_port) {
    pthread_once(&library_once, initialize_library);
    if (library_error != SSH_OK) return startup_failure("initialize libssh", NULL, 0);
#define LOAD(field, suffix) do { \
    *(void **)(&host.field) = dlsym(RTLD_DEFAULT, "ashell_pane_" suffix); \
    if (!host.field) return startup_failure("load pane " suffix, NULL, ENOTSUP); \
} while (0)
    LOAD(spawn, "spawn_ex"); LOAD(poll, "poll");
    LOAD(resize, "resize"); LOAD(close_stdin, "close_stdin");
    LOAD(interrupt, "interrupt"); LOAD(release, "release");
    *(void **)(&host.state) = dlsym(RTLD_DEFAULT, "ashell_sshd_state_v2");
    *(void **)(&host.event) = dlsym(RTLD_DEFAULT, "ashell_sshd_event");
#undef LOAD
    const char *value = ios_getenv("HOME");
    if (!value || strlen(value) + 48 >= sizeof(home)) return startup_failure("read HOME", NULL, EINVAL);
    strcpy(home, value);
    snprintf(documents, sizeof(documents), "%s/Documents", home);
    snprintf(authorized, sizeof(authorized), "%s/.ssh/authorized_keys", documents);
    if (configuration && strlen(configuration) >= sizeof(config_path)) return startup_failure("configuration path too long", NULL, ENAMETOOLONG);
    if (configuration) strcpy(config_path, configuration);
    else snprintf(config_path, sizeof(config_path), "%s/.ssh/sshd_config", documents);
    value = ios_getenv("USER");
    if (!value || !*value) value = "mobile";
    if (strlen(value) >= sizeof(account)) return startup_failure("user name too long", NULL, EINVAL);
    strcpy(account, value);
    char directory[PATH_MAX], host_key_path[PATH_MAX];
    snprintf(directory, sizeof(directory), "%s/.ssh", documents);
    int created_directory = mkdir(directory, 0700);
    if (created_directory && errno != EEXIST) return startup_failure("create .ssh directory", NULL, errno);
    if (!created_directory && chmod(directory, 0700)) return startup_failure("set new .ssh directory permissions", NULL, errno);
    if (startup_private_file(directory, S_IFDIR, 0700)) return 255;
    int authorized_fd = open(authorized, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
    if (authorized_fd >= 0) {
        int error = fchmod(authorized_fd, 0600) ? errno : 0;
        close(authorized_fd);
        if (error) return startup_failure("set new authorized_keys permissions", NULL, error);
    }
    else if (errno != EEXIST) return startup_failure("create authorized_keys", NULL, errno);
    if (startup_private_file(authorized, S_IFREG, 0600)) return 255;
    struct stat config_stat;
    if (lstat(config_path, &config_stat) == 0) {
        if (startup_private_file(config_path, S_IFREG, 0600)) return 255;
    } else if (errno != ENOENT || configuration) return startup_failure("stat configuration", NULL, errno);
    snprintf(host_key_path, sizeof(host_key_path), "%s/ssh_host_ed25519_key", directory);
    ssh_key key = NULL;
    if (access(host_key_path, F_OK)) {
        if (errno != ENOENT) return startup_failure("access host key", NULL, errno);
        errno = 0;
        if (ssh_pki_generate_key(SSH_KEYTYPE_ED25519, NULL, &key) != SSH_OK) return startup_failure("generate host key", NULL, errno);
        char *pem = NULL;
        errno = 0;
        if (ssh_pki_export_privkey_base64(key, NULL, NULL, NULL, &pem) != SSH_OK) { int error = errno; ssh_key_free(key); return startup_failure("export host key", NULL, error); }
        int fd = open(host_key_path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
        size_t length = strlen(pem), written = 0;
        if (fd >= 0) while (written < length) { ssize_t n = write(fd, pem + written, length - written); if (n <= 0) break; written += n; }
        int error = fd < 0 ? errno : written != length ? EIO : 0;
        if (fd >= 0) { if (fchmod(fd, 0600) && !error) error = errno; if (fsync(fd) && !error) error = errno; close(fd); if (error) unlink(host_key_path); }
        ssh_string_free_char(pem);
        if (error) { ssh_key_free(key); return startup_failure("write host key", NULL, error); }
    } else {
        if (startup_private_file(host_key_path, S_IFREG, 0600)) return 255;
        errno = 0;
        if (ssh_pki_import_privkey_file(host_key_path, NULL, NULL, NULL, &key) != SSH_OK) return startup_failure("import host key", NULL, errno);
    }
    unsigned char *hash = NULL;
    size_t hash_length = 0;
    char *formatted = NULL;
    errno = 0;
    if (ssh_get_publickey_hash(key, SSH_PUBLICKEY_HASH_SHA256, &hash, &hash_length) == SSH_OK)
        formatted = ssh_get_fingerprint_hash(SSH_PUBLICKEY_HASH_SHA256, hash, hash_length);
    ssh_clean_pubkey_hash(&hash);
    if (!formatted || strlen(formatted) >= sizeof(fingerprint)) {
        int error = errno;
        ssh_string_free_char(formatted); ssh_key_free(key); return startup_failure("fingerprint host key", NULL, error);
    }
    strcpy(fingerprint, formatted);
    ssh_string_free_char(formatted);
    errno = 0;
    listener = ssh_bind_new();
    int port = PORT, no = 0;
#define BIND_STEP(stage, operation) do { \
    errno = 0; \
    if ((operation) != SSH_OK) { \
        startup_failure(stage, listener, errno); \
        ssh_key_free(key); if (listener) ssh_bind_free(listener); listener = NULL; return 255; \
    } \
} while (0)
    if (!listener) { int error = errno; ssh_key_free(key); return startup_failure("allocate listener", NULL, error); }
    BIND_STEP("disable system configuration", ssh_bind_options_set(listener, SSH_BIND_OPTIONS_PROCESS_CONFIG, &no));
    BIND_STEP("set bind address", ssh_bind_options_set(listener, SSH_BIND_OPTIONS_BINDADDR, "0.0.0.0"));
    BIND_STEP("set default port", ssh_bind_options_set(listener, SSH_BIND_OPTIONS_BINDPORT, &port));
    FILE *config = fopen(config_path, "r");
    if (config) {
        char line[1024];
        int bad = 0;
        unsigned line_number = 0;
        while (fgets(line, sizeof(line), config)) {
            line_number++;
            if (!strchr(line, '\n') && !feof(config)) { bad = 1; break; }
            char *save, *name = strtok_r(line, " \t\r\n", &save);
            if (!name || *name == '#') continue;
            char *value = strtok_r(NULL, " \t\r\n", &save);
            char *extra = strtok_r(NULL, " \t\r\n", &save);
            if (!value || (extra && *extra != '#')) { bad = 1; break; }
            if (!strcasecmp(name, "Port")) {
                char *end;
                long parsed = strtol(value, &end, 10);
                if (end == value || *end || parsed < 1 || parsed > 65535) { bad = 1; break; }
                port = (int)parsed;
                if (ssh_bind_options_set(listener, SSH_BIND_OPTIONS_BINDPORT, &port) != SSH_OK) { bad = 1; break; }
            } else if (!strcasecmp(name, "ListenAddress")) {
                struct in_addr v4; struct in6_addr v6;
                if (inet_pton(AF_INET, value, &v4) != 1 && inet_pton(AF_INET6, value, &v6) != 1) { bad = 1; break; }
                if (ssh_bind_options_set(listener, SSH_BIND_OPTIONS_BINDADDR, value) != SSH_OK) { bad = 1; break; }
            } else { bad = 1; break; }
        }
        if (ferror(config)) bad = 1;
        fclose(config);
        if (bad) {
            ssh_key_free(key); ssh_bind_free(listener); listener = NULL;
            char stage[160];
            snprintf(stage, sizeof(stage), "parse configuration at line %u (expected Port or numeric ListenAddress)", line_number);
            return startup_failure(stage, NULL, EINVAL);
        }
    } else if (errno != ENOENT || configuration) {
        int error = errno;
        ssh_key_free(key); ssh_bind_free(listener); listener = NULL;
        return startup_failure("open configuration", NULL, error);
    }
    if (override_port) BIND_STEP("set port", ssh_bind_options_set(listener, SSH_BIND_OPTIONS_BINDPORT, &override_port));
    BIND_STEP("install host key", ssh_bind_options_set(listener, SSH_BIND_OPTIONS_IMPORT_KEY, key));
    key = NULL;
    BIND_STEP("listen", ssh_bind_listen(listener));
#undef BIND_STEP
    struct sockaddr_storage address;
    socklen_t address_length = sizeof(address);
    if (getsockname(ssh_bind_get_fd(listener), (struct sockaddr *)&address, &address_length)) {
        int error = errno;
        ssh_bind_free(listener); listener = NULL; return startup_failure("read listener address", NULL, error);
    }
    int address_error = getnameinfo((struct sockaddr *)&address, address_length, listen_address, sizeof(listen_address), NULL, 0, NI_NUMERICHOST);
    if (address_error) {
        ssh_bind_free(listener); listener = NULL;
        return startup_failure(gai_strerror(address_error), NULL, address_error == EAI_SYSTEM ? errno : EINVAL);
    }
    listen_port = ntohs(address.ss_family == AF_INET6 ? ((struct sockaddr_in6 *)&address)->sin6_port : ((struct sockaddr_in *)&address)->sin_port);
    int error = capture_environment();
    if (error) { ssh_bind_free(listener); listener = NULL; return startup_failure("capture environment", NULL, error); }
    atomic_store(&running, 1);
    error = pthread_create(&listener_thread, NULL, accept_clients, NULL);
    if (error) { atomic_store(&running, 0); ssh_bind_free(listener); listener = NULL; free_environment(); return startup_failure("start listener thread", NULL, error); }
    indicator();
    return 0;
}

int ashell_sshd_main(int argc, char **argv) {
    if (ios_getenv("ASHELL_WORKER_PID")) {
        fprintf(thread_stderr, "sshd: control the service from the application terminal\n");
        return 1;
    }
    pthread_mutex_lock(&control);
    extern int optreset;
    optreset = 1; optind = 1; opterr = 0;
    const char *configuration = NULL;
    int option, override_port = 0, invalid = 0;
    while ((option = getopt(argc, argv, "f:p:")) != -1) {
        if (option == 'f') configuration = optarg;
        else if (option == 'p') {
            char *end;
            errno = 0;
            long parsed = strtol(optarg, &end, 10);
            if (errno || end == optarg || *end || parsed < 1 || parsed > 65535) invalid = 1;
            else override_port = (int)parsed;
        } else invalid = 1;
    }
    const char *command = !invalid && optind + 1 == argc ? argv[optind] : "help";
    int error = 0;
    int was_running = atomic_load(&running);
    if (!strcmp(command, "off")) { stop_server(); if (was_running) fprintf(thread_stdout, "sshd: off\n"); }
    else if (!strcmp(command, "on") || !strcmp(command, "status")) {
        if (!strcmp(command, "on") && !atomic_load(&running)) error = start_server(configuration, override_port);
        if (error) {
            if (error != 255) fprintf(thread_stderr, "sshd: %s\n", strerror(error));
        }
        else {
            if (atomic_load(&running)) {
                fprintf(thread_stdout, "sshd: on port %d\n", listen_port);
                if (!strcmp(command, "status")) {
                    void (*addresses)(void) = dlsym(RTLD_DEFAULT, "ashell_sshd_print_addresses");
                    if (addresses) addresses();
                }
            }
            else fprintf(thread_stdout, "sshd: off\n");
        }
    } else { fprintf(thread_stdout, "usage: sshd [-f config_file] [-p port] on|off|status\nOff by default. Port from sshd_config (default 2222); -p overrides it. Changes apply at the next sshd on.\n"); error = 64; }
    pthread_mutex_unlock(&control);
    return error == 255 ? 255 : error ? 1 : 0;
}
