// Public uv_spawn probe with a fake external iOS worker broker.
#include <dlfcn.h>
#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <uv.h>
#include <ios_spawn.h>

static int admissions;
static int callbacks;
static int fail_waiter;
static int reject_spawn;
static int hold_worker;
static int cancellations;
static uv_sem_t cancelled;

// Inject host thread exhaustion in this executable only.
int pthread_create(pthread_t *thread, const pthread_attr_t *attr,
                   void *(*start)(void *), void *arg) {
  if (fail_waiter) return EAGAIN;
  int (*create)(pthread_t *, const pthread_attr_t *, void *(*)(void *), void *) =
      dlsym(RTLD_NEXT, "pthread_create");
  return create(thread, attr, start, arg);
}

__thread FILE *thread_stdin, *thread_stdout, *thread_stderr;
FILE *nvim_port_stream(int index) { return index == 0 ? stdin : index == 1 ? stdout : stderr; }
int ios_posix_spawn_file_actions_init(ios_posix_spawn_file_actions_t *actions) { (void)actions; return 0; }
int ios_posix_spawn_file_actions_destroy(ios_posix_spawn_file_actions_t *actions) { (void)actions; return 0; }
int ios_posix_spawn_file_actions_adddup2(ios_posix_spawn_file_actions_t *actions, int fd, int target) {
  (void)actions; (void)fd; (void)target; return 0;
}
int ios_posix_spawn_file_actions_addchdir_np(ios_posix_spawn_file_actions_t *actions, const char *cwd) {
  (void)actions; (void)cwd; return 0;
}
int ios_posix_spawn(pid_t *pid, const char *file, const ios_posix_spawn_file_actions_t *actions,
                    const void *attributes, char *const argv[], char *const env[]) {
  (void)file; (void)actions; (void)attributes; (void)argv; (void)env;
  if (reject_spawn) return ENOENT;
  admissions++;
  *pid = 100;
  return 0;
}
pid_t ios_full_waitpid(pid_t pid, int *status, int options) {
  (void)options;
  if (hold_worker) uv_sem_wait(&cancelled);
  if (status) *status = 0;
  return pid;
}
int ios_killpid(pid_t pid, int signal) {
  if (!hold_worker || pid != 100 || signal != SIGKILL) return EINVAL;
  cancellations++;
  return 0;
}

static void exited(uv_process_t *process, int64_t status, int signal) {
  (void)status; (void)signal;
  callbacks++;
  uv_close((uv_handle_t *)process, NULL);
}

int main(int argc, char **argv) {
  const char *mode = argc > 1 ? argv[1] : "duplicate-stream";
  fail_waiter = strcmp(mode, "fail-waiter") == 0;
  reject_spawn = strcmp(mode, "reject-spawn") == 0;
  int detached = strcmp(mode, "detached") == 0;
  int duplicate_stream = strcmp(mode, "duplicate-stream") == 0;
  hold_worker = strcmp(mode, "close-live") == 0;
  if (!fail_waiter && !reject_spawn && !detached && !duplicate_stream && !hold_worker) return 2;
  if (hold_worker && uv_sem_init(&cancelled, 0)) return 2;
  uv_loop_t loop;
  uv_pipe_t pipe;
  uv_process_t process = {0};
  if (uv_loop_init(&loop) || uv_pipe_init(&loop, &pipe, 0)) return 2;
  char *args[] = {"fixture", NULL};
  uv_stdio_container_t streams[] = {
    {.flags = UV_IGNORE},
    {.flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE, .data.stream = (uv_stream_t *)&pipe},
    {.flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE, .data.stream = (uv_stream_t *)&pipe},
  };
  uv_process_options_t options = {.file = args[0], .args = args, .exit_cb = exited,
                                  .flags = detached ? UV_PROCESS_DETACHED : 0,
                                  .stdio_count = duplicate_stream ? 3 : 2, .stdio = streams};
  int result = uv_spawn(&loop, &process, &options);
  if (hold_worker) {
    if (result || !uv_is_active((uv_handle_t *)&process) || admissions != 1) return 1;
    uv_close((uv_handle_t *)&process, NULL);
    uv_close((uv_handle_t *)&pipe, NULL);
    if (cancellations != 1) return 1;
    // Hold broker completion while libuv drains the public close callbacks.
    uv_run(&loop, UV_RUN_NOWAIT);
    if (!uv_loop_alive(&loop)) {
      fputs("close-live: loop lost the pending waiter\n", stderr);
      return 1;
    }
    uv_sem_post(&cancelled);
    uv_run(&loop, UV_RUN_DEFAULT);
    int closed = uv_loop_close(&loop);
    uv_sem_destroy(&cancelled);
    printf("close-live: admissions=%d cancellations=%d callbacks=%d loop=%d\n",
           admissions, cancellations, callbacks, closed);
    return cancellations == 1 && callbacks == 0 && closed == 0 ? 0 : 1;
  }
  uv_os_fd_t fd;
  int pipe_state = uv_fileno((uv_handle_t *)&pipe, &fd);
  int expected = fail_waiter ? UV_EAGAIN : reject_spawn ? UV_ENOENT : detached ? UV_ENOTSUP : UV_EBUSY;
  uv_handle_t *handle = (uv_handle_t *)&process;
  if (result != expected || uv_handle_get_type(handle) != UV_PROCESS || uv_is_active(handle)) {
    fprintf(stderr, "%s: result=%s handle=%d admissions=%d\n", mode, uv_err_name(result),
            (int)uv_handle_get_type(handle), admissions);
    return 1;
  }
  uv_close(handle, NULL);
  uv_close((uv_handle_t *)&pipe, NULL);
  uv_run(&loop, UV_RUN_DEFAULT);
  int closed = uv_loop_close(&loop);
  printf("%s: spawn=%s admissions=%d callbacks=%d pipe=%s loop=%d\n",
         mode, uv_err_name(result), admissions, callbacks, uv_err_name(pipe_state), closed);
  return admissions == 0 && callbacks == 0 && pipe_state == UV_EBADF && closed == 0 ? 0 : 1;
}
