// Compile the same native runner in the app under a distinct public ABI.
#define ASHELL_HOST_PANE 1
#define ashell_pane_spawn ashell_host_pane_spawn
#define ashell_pane_spawn_ex ashell_host_pane_spawn_ex
#define ashell_pane_poll ashell_host_pane_poll
#define ashell_pane_poll_usage ashell_host_pane_poll_usage
#define ashell_pane_resize ashell_host_pane_resize
#define ashell_pane_close_stdin ashell_host_pane_close_stdin
#define ashell_pane_interrupt ashell_host_pane_interrupt
#define ashell_pane_cancel ashell_host_pane_cancel
#define ashell_pane_release ashell_host_pane_release
#include "NativePane.m"
