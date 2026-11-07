#ifndef ASHELL_TMUX_ENGINE_H
#define ASHELL_TMUX_ENGINE_H
// Private engine result: no listener accepted the initial client connection.
#define ASHELL_TMUX_NO_SERVER 75
int tmux_ios_check_shared_container(void);
int tmux_ios_socket(int, const char *, int);
struct window_pane;
struct spawn_context;
struct environ;
struct winsize;
struct tmuxpeer;
struct client_files;
int tmux_ios_spawn_pane(struct spawn_context *, struct window_pane *, struct environ *, struct winsize *, char **);
void tmux_ios_release_pane(struct window_pane *);
void tmux_ios_resize_pane(struct window_pane *, unsigned, unsigned);
void tmux_ios_pane_exited(struct window_pane *, int);
void tmux_ios_send_resize(struct tmuxpeer *);
void tmux_ios_close_files(struct client_files *);
#endif
