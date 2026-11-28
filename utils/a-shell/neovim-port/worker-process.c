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
  uv_sem_t ready;
  pid_t pid;
  int status;
} uv__ios_worker;

static void uv__ios_free(uv_handle_t *handle) {
  uv__ios_worker *worker = handle->data;
  uv_sem_destroy(&worker->ready);
  uv__free(worker);
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
  uv_sem_wait(&worker->ready);
  if (worker->pid <= 0) return NULL;
  if (ios_full_waitpid(worker->pid, &worker->status, 0) != worker->pid)
    worker->status = 125 << 8;
  uv_async_send(&worker->completed);
  return NULL;
}

static int uv__ios_spawn(uv_loop_t *loop, uv_process_t *process,
                         const uv_process_options_t *options) {
  ios_posix_spawn_file_actions_t actions;
  uv__ios_worker *worker;
  int pipes[3][2] = {{-1, -1}, {-1, -1}, {-1, -1}};
  bool attached[3] = {false, false, false};
  int nullfd = -1, err = 0;
  // Callers close even a failed process handle. Activate only after admission.
  uv__handle_init(loop, (uv_handle_t *)process, UV_PROCESS);
  uv__queue_init(&process->queue);
  process->status = 0;
  process->pid = 0;
  process->exit_cb = NULL;
  process->ios_worker = NULL;
  // Worker waiters cannot outlive the editor invocation.
  if (options->stdio_count > 3 ||
      (options->flags & (UV_PROCESS_SETUID | UV_PROCESS_SETGID | UV_PROCESS_DETACHED)))
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
  // Attach parent ends before admission. Unlike uv__process_open_stream,
  // leave the child ends open until ios_posix_spawn has copied them.
  for (int i = 0; i < options->stdio_count; i++) {
    const uv_stdio_container_t *stdio = &options->stdio[i];
    if (!(stdio->flags & UV_CREATE_PIPE) || pipes[i][0] < 0) continue;
    int flags = 0;
    if (stdio->flags & UV_WRITABLE_PIPE) flags |= UV_HANDLE_READABLE;
    if (stdio->flags & UV_READABLE_PIPE) flags |= UV_HANDLE_WRITABLE;
    err = uv__nonblock(pipes[i][0], 1);
    if (err) goto cleanup;
    err = uv__stream_open(stdio->data.stream, pipes[i][0], flags);
    if (err) goto cleanup;
    attached[i] = true;
    pipes[i][0] = -1;
  }
  err = uv_sem_init(&worker->ready, 0);
  if (err) goto cleanup;
  err = uv_async_init(loop, &worker->completed, uv__ios_completed);
  if (err) {
    uv_sem_destroy(&worker->ready);
    goto cleanup;
  }
  worker->completed.data = worker;
  // Reserve the waiter before spawn; failure must not leave a child to reap.
  err = pthread_create(&worker->waiter, NULL, uv__ios_wait, worker);
  if (err) {
    err = UV__ERR(err);
    goto close_completion;
  }
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
    worker->pid = 0;
    uv_sem_post(&worker->ready);
    pthread_join(worker->waiter, NULL);
    goto close_completion;
  }
  worker->process = process;
  process->ios_worker = worker;
  process->pid = worker->pid;
  process->exit_cb = options->exit_cb;
  uv__handle_start(process);
  uv_unref((uv_handle_t *)&worker->completed);
  uv_sem_post(&worker->ready);
  worker = NULL; // Completion owns the allocation and waiter.
  goto cleanup;
close_completion:
  uv_close((uv_handle_t *)&worker->completed, uv__ios_free);
  worker = NULL;
cleanup:
  if (err) {
    for (int i = 0; i < options->stdio_count; i++) {
      if (attached[i]) uv__stream_close(options->stdio[i].data.stream);
    }
  }
  ios_posix_spawn_file_actions_destroy(&actions);
  if (nullfd >= 0) close(nullfd);
  for (int i = 0; i < options->stdio_count && i < 3; i++) {
    if (!(options->stdio[i].flags & UV_CREATE_PIPE)) continue;
    for (int j = 0; j < 2; j++) if (pipes[i][j] >= 0) close(pipes[i][j]);
  }
  uv__free(worker);
  return err;
}
