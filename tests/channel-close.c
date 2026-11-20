#include <libssh/libssh.h>
#include <libssh/callbacks.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

static int closed, status = -1;
static void remote_close(ssh_session session, ssh_channel channel, void *data) {
    (void)session; (void)channel; (void)data;
    closed = 1;
}
static void remote_status(ssh_session session, ssh_channel channel, int value, void *data) {
    (void)session; (void)channel; (void)data;
    status = value;
}
static double now(void) {
    struct timespec value;
    clock_gettime(CLOCK_MONOTONIC, &value);
    return value.tv_sec + value.tv_nsec / 1e9;
}
int main(int argc, char **argv) {
    if (argc != 6) return 2;
    alarm(12);
    ssh_session session = ssh_new();
    ssh_key key = NULL;
    int port = atoi(argv[2]), result = 1;
    if (!session) return 2;
    ssh_options_set(session, SSH_OPTIONS_HOST, argv[1]);
    ssh_options_set(session, SSH_OPTIONS_PORT, &port);
    ssh_options_set(session, SSH_OPTIONS_USER, argv[3]);
    ssh_options_set(session, SSH_OPTIONS_KNOWNHOSTS, argv[5]);
    if (ssh_connect(session) != SSH_OK || ssh_session_is_known_server(session) != SSH_KNOWN_HOSTS_OK ||
        ssh_pki_import_privkey_file(argv[4], NULL, NULL, NULL, &key) != SSH_OK ||
        ssh_userauth_publickey(session, NULL, key) != SSH_AUTH_SUCCESS) goto done;
    ssh_channel channel = ssh_channel_new(session);
    ssh_event event = ssh_event_new();
    if (!channel || !event) goto done;
    struct ssh_channel_callbacks_struct callbacks = {
        .channel_close_function = remote_close,
        .channel_exit_status_function = remote_status
    };
    ssh_callbacks_init(&callbacks);
    ssh_set_channel_callbacks(channel, &callbacks);
    ssh_event_add_session(event, session);
    if (ssh_channel_open_session(channel) != SSH_OK || ssh_channel_request_exec(channel, "exit 7") != SSH_OK) goto release;
    double deadline = now() + 3;
    while (!closed && now() < deadline && ssh_event_dopoll(event, 50) != SSH_ERROR) {}
    if (!closed || status != 7) goto release;
    // Leave CLOSE unacknowledged while unrelated packets keep the event loop busy.
    double started = now();
    int packets = 0;
    while (now() - started < 1.0 && ssh_is_connected(session)) {
        if (ssh_send_ignore(session, "close deadline consumer") != SSH_OK || ssh_event_dopoll(event, 0) == SSH_ERROR) break;
        packets++;
        usleep(5000);
    }
    int survived = ssh_is_connected(session) && now() - started >= 1.0 && packets > 50;
    int acknowledged = survived && ssh_channel_close(channel) == SSH_OK;
    printf("close status=%d packets=%d survived=%d acknowledged=%d %s\n", status, packets, survived, acknowledged, acknowledged ? "PASS" : "FAIL");
    result = acknowledged ? 0 : 1;
release:
    ssh_event_remove_session(event, session);
    ssh_event_free(event);
    ssh_channel_free(channel);
done:
    ssh_key_free(key);
    ssh_disconnect(session);
    ssh_free(session);
    return result;
}
