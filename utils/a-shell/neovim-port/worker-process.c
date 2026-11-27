// Included by libuv's unix/process.c on iOS; worker handles are not kernel PIDs.
#include <ios_spawn.h>
#include <pthread.h>
extern pid_t ios_full_waitpid(pid_t, int *, int);
extern int ios_killpid(pid_t, int);
extern __thread FILE *thread_stdin, *thread_stdout, *thread_stderr;

typedef struct {
  uv_async_t completed;
  uv_process_t *process;
  pthread_t waiter;
  pid_t pid;
  int status;
} uv__ios_worker;

static void uv__ios_free(uv_handle_t *handle) {
  uv__free(handle->data);
}

static void uv__ios_completed(uv_async_t *async) {
  uv__ios_worker *worker = async->data;
  uv_process_t *process = worker->process;
  pthread_join(worker->waiter, NULL);
  if (process != NULL) {
    process->ios_worker = NULL;
    uv__handle_stop(process);
  }
  uv_close((uv_handle_t *)async, uv__ios_free);
  if (process != NULL && process->exit_cb != NULL)
    process->exit_cb(process, WIFEXITED(worker->status) ? WEXITSTATUS(worker->status) : 0,
                     WIFSIGNALED(worker->status) ? WTERMSIG(worker->status) : 0);
}

static void *uv__ios_wait(void *argument) {
  uv__ios_worker *worker = argument;
  ios_full_waitpid(worker->pid, &worker->status, 0);
  uv_async_send(&worker->completed);
  return NULL;
}

static int uv__ios_spawn(uv_loop_t *loop, uv_process_t *process,
                         const uv_process_options_t *options) {
  ios_posix_spawn_file_actions_t actions;
  uv__ios_worker *worker;
  int pipes[3][2] = {{-1, -1}, {-1, -1}, {-1, -1}};
  int nullfd = -1, err = 0;
  uv__handle_init(loop, (uv_handle_t *)process, UV_PROCESS);
  uv__queue_init(&process->queue);
  process->status = 0;
  process->ios_worker = NULL;
  // A worker already has an independent process/session; DETACHED needs no setsid.
  // Extension workers inherit three streams; credentials and sessions stay with the host.
  if (options->stdio_count > 3 ||
      (options->flags & (UV_PROCESS_SETUID | UV_PROCESS_SETGID)))
    return UV_ENOTSUP;
  worker = uv__calloc(1, sizeof(*worker));
  if (worker == NULL) return UV_ENOMEM;
  ios_posix_spawn_file_actions_init(&actions);
  for (int i = 0; i < 3; i++) {
    int fd;
    if (i < options->stdio_count && options->stdio[i].flags != UV_IGNORE) {
      err = uv__process_init_stdio(&options->stdio[i], pipes[i]);
      if (err) goto cleanup;
      fd = pipes[i][1];
    } else {
      if (nullfd < 0) nullfd = open("/dev/null", O_RDWR | O_CLOEXEC);
      if (nullfd < 0) { err = UV__ERR(errno); goto cleanup; }
      fd = nullfd;
    }
    err = ios_posix_spawn_file_actions_adddup2(&actions, fd, i);
    if (err) { err = UV__ERR(err); goto cleanup; }
  }
  if (options->cwd != NULL) {
    err = ios_posix_spawn_file_actions_addchdir_np(&actions, options->cwd);
    if (err) { err = UV__ERR(err); goto cleanup; }
  }
  err = uv_async_init(loop, &worker->completed, uv__ios_completed);
  if (err) goto cleanup;
  worker->completed.data = worker;
  FILE *saved[] = {thread_stdin, thread_stdout, thread_stderr};
  thread_stdin = nvim_port_stream(0);
  thread_stdout = nvim_port_stream(1);
  thread_stderr = nvim_port_stream(2);
  err = ios_posix_spawn(&worker->pid, options->file, &actions, NULL,
                         options->args, options->env ? options->env : environ);
  thread_stdin = saved[0];
  thread_stdout = saved[1];
  thread_stderr = saved[2];
  if (err) {
    err = UV__ERR(err);
    uv_close((uv_handle_t *)&worker->completed, uv__ios_free);
    worker = NULL;
    goto cleanup;
  }
  err = pthread_create(&worker->waiter, NULL, uv__ios_wait, worker);
  if (err) {
    ios_killpid(worker->pid, SIGTERM);
    ios_full_waitpid(worker->pid, NULL, 0);
    uv_close((uv_handle_t *)&worker->completed, uv__ios_free);
    worker = NULL;
    err = UV__ERR(err);
    goto cleanup;
  }
  worker->process = process;
  process->ios_worker = worker;
  process->pid = worker->pid;
  process->exit_cb = options->exit_cb;
  uv__handle_start(process);
  uv_unref((uv_handle_t *)&worker->completed);
  worker = NULL; // Completion owns the allocation and waiter.
  for (int i = 0; i < options->stdio_count; i++) {
    err = uv__process_open_stream(&options->stdio[i], pipes[i]);
    if (err) break;
    if (options->stdio[i].flags & UV_CREATE_PIPE) pipes[i][0] = -1;
  }
cleanup:
  ios_posix_spawn_file_actions_destroy(&actions);
  if (nullfd >= 0) close(nullfd);
  for (int i = 0; i < options->stdio_count && i < 3; i++) {
    if (!(options->stdio[i].flags & UV_CREATE_PIPE)) continue;
    for (int j = 0; j < 2; j++) if (pipes[i][j] >= 0) close(pipes[i][j]);
  }
  uv__free(worker);
  return err;
}
