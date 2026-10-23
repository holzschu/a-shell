// Adapt libuv's process boundary to ios_system command threads, never OS forks.
#include "uv.h"
#import <UIKit/UIKit.h>
extern "C" {
#include "ios_system.h"
// Stream-ownership barrier supplied by ios-system-streams.patch.
int ashell_register_owned_streams(FILE*, FILE*, FILE*, void**);
void ashell_wait_owned_streams(void*);
void ashell_unregister_owned_streams(void**);
void AShellUVExit(uv_process_t*, int);
}
#include <atomic>
#include <cerrno>
#include <fcntl.h>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <system_error>
#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>
#include <vector>

namespace {
// ios_system's PID and cwd bookkeeping is global. Reject overlapping children
// rather than let their environments or working directories silently cross.
std::atomic<bool> child_active{false};
std::atomic<int> next_id{1000000};
struct Child {
  uv_async_t completion{};
  uv_process_t* process;
  std::thread worker;
  FILE* streams[3]{};
  void* registration = nullptr;
  std::string command;
  std::string context;
  std::string cwd;
  std::vector<std::string> env;
  int status = 1;
  int id = 0;
  ~Child() {
    ashell_unregister_owned_streams(&registration);
    for (auto* stream : streams) if (stream) fclose(stream);
  }
};
std::mutex children_mutex;
std::vector<Child*> children;

std::string quote(const std::string& value) {
  std::string result = "'";
  for (char c : value) result += c == '\'' ? "'\\''" : std::string(1, c);
  return result + "'";
}

void completed(uv_async_t* handle) {
  auto* child = static_cast<Child*>(handle->data);
  child->worker.join();
  {
    std::lock_guard<std::mutex> lock(children_mutex);
    for (auto it = children.begin(); it != children.end(); ++it)
      if (*it == child) { children.erase(it); break; }
  }
  // Keep the original Node exit callback and stream-EOF/close machinery.
  if (child->process) AShellUVExit(child->process, child->status);
  uv_close(reinterpret_cast<uv_handle_t*>(handle), [](uv_handle_t* h) {
    delete static_cast<Child*>(h->data);
  });
}
}

extern "C" int AShellUVSpawn(uv_loop_t* loop, uv_process_t* process,
                             const uv_process_options_t* options) {
  if (options->flags & (UV_PROCESS_DETACHED | UV_PROCESS_SETUID | UV_PROCESS_SETGID))
    return UV_ENOSYS;
  if (options->stdio_count > 3) return UV_ENOSYS; // fork/IPC is not a command.
  std::string file = options->file;
  std::string name = file.substr(file.find_last_of('/') + 1);
  const bool shell = name == "sh" || name == "dash";
  std::string interpreter;
  if (!shell && !ios_executable(name.c_str())) {
    FILE* script = fopen(file.c_str(), "r");
    if (!script) return -errno;
    char line[256] = {};
    fgets(line, sizeof(line), script);
    fclose(script);
    const std::string shebang(line);
    if (shebang.starts_with("#!/usr/bin/env node") || shebang.starts_with("#!/bin/node"))
      interpreter = "node";
    else if (shebang.starts_with("#!/bin/sh") || shebang.starts_with("#!/bin/dash"))
      interpreter = "dash";
    else return UV_ENOSYS;
  }
  if (options->cwd) {
    struct stat info;
    if (stat(options->cwd, &info)) return -errno;
    if (!S_ISDIR(info.st_mode)) return UV_ENOTDIR;
  }
  if (child_active.exchange(true)) return UV_EBUSY;
  auto child = std::make_unique<Child>();
  child->process = process;
  if (const auto* context = static_cast<const char*>(ios_getContext()))
    child->context = context;
  child->cwd = options->cwd ? options->cwd : "";
  if (options->env) for (char** p = options->env; *p; ++p) child->env.emplace_back(*p);
  // Shell=true arrives as /bin/sh -c. Use the app's actual Dash command.
  child->command = !interpreter.empty() ? interpreter + " " + quote(file) : (shell ? "dash" : name);
  for (char** p = options->args + 1; *p; ++p) child->command += " " + quote(*p);
  int error = 0;
  for (int i = 0; i < 3 && !error; ++i) {
    int fd = -1;
    uv_stdio_container_t stdio{};
    if (i < options->stdio_count) stdio = options->stdio[i];
    if (stdio.flags & UV_CREATE_PIPE) {
      int pair[2];
      if (socketpair(AF_UNIX, SOCK_STREAM, 0, pair)) { error = -errno; break; }
      fcntl(pair[0], F_SETNOSIGPIPE, 1);
      fcntl(pair[1], F_SETNOSIGPIPE, 1);
      error = uv_pipe_open(reinterpret_cast<uv_pipe_t*>(stdio.data.stream), pair[0]);
      if (error) { close(pair[0]); close(pair[1]); break; }
      fd = pair[1];
    } else if (stdio.flags & (UV_INHERIT_FD | UV_INHERIT_STREAM)) {
      int inherited = stdio.data.fd;
      if (stdio.flags & UV_INHERIT_STREAM) {
        uv_os_fd_t value;
        error = uv_fileno(reinterpret_cast<uv_handle_t*>(stdio.data.stream), &value);
        if (error) break;
        inherited = value;
      } else if (inherited >= 0 && inherited < 3) {
        FILE* streams[] = {thread_stdin, thread_stdout, thread_stderr};
        inherited = fileno(streams[inherited]);
      }
      fd = dup(inherited);
    } else {
      fd = open("/dev/null", i == 0 ? O_RDONLY : O_WRONLY);
    }
    if (fd < 0) { error = -errno; break; }
    child->streams[i] = fdopen(fd, i == 0 ? "r" : "w");
    if (!child->streams[i]) { error = -errno; close(fd); break; }
  }
  if (error) { child_active = false; return error; }
  error = ashell_register_owned_streams(child->streams[0], child->streams[1],
                                       child->streams[2], &child->registration);
  if (error) { child_active = false; return -error; }
  error = uv_async_init(loop, &child->completion, completed);
  if (error) { child_active = false; return error; }
  child->completion.data = child.get();
  process->pid = next_id++;
  child->id = process->pid;
  process->exit_cb = options->exit_cb;
  auto* owned = child.release();
  {
    std::lock_guard<std::mutex> lock(children_mutex);
    children.push_back(owned);
  }
  try {
    owned->worker = std::thread([owned] {
      @autoreleasepool {
        int cancellation;
        pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cancellation);
        NSString* previous = [NSFileManager.defaultManager currentDirectoryPath];
        std::string session = "node-child-" + std::to_string(owned->id);
        ios_switchSession(session.c_str());
        // Keep separate command streams/environments but share the terminal's
        // interrupt group with npm/npx and their Node children.
        if (!owned->context.empty()) ios_setContext(owned->context.c_str());
        ios_setStreams(owned->streams[0], owned->streams[1], owned->streams[2]);
        thread_stdin = owned->streams[0];
        thread_stdout = owned->streams[1];
        thread_stderr = owned->streams[2];
        if (!owned->cwd.empty() && ![NSFileManager.defaultManager changeCurrentDirectoryPath:
              [NSString stringWithUTF8String:owned->cwd.c_str()]]) {
          fprintf(thread_stderr, "Cannot enter child working directory: %s\n", owned->cwd.c_str());
          owned->status = 1;
        } else {
          pid_t pid = ios_fork();
          std::vector<char*> env;
          for (auto& item : owned->env) env.push_back(item.data());
          env.push_back(nullptr);
          storeEnvironment(env.data());
          ios_system(owned->command.c_str());
          ios_waitpid(pid);
          ashell_wait_owned_streams(owned->registration);
          owned->status = ios_getCommandStatus();
          ios_releaseThreadId(pid);
        }
        ios_closeSession(session.c_str());
        [NSFileManager.defaultManager changeCurrentDirectoryPath:previous];
        ashell_unregister_owned_streams(&owned->registration);
        for (auto*& stream : owned->streams) { fclose(stream); stream = nullptr; }
        child_active = false;
        uv_async_send(&owned->completion);
        // Do not restore pthread cancellation until the command lifetime ends.
      }
    });
  } catch (const std::system_error&) {
    {
      std::lock_guard<std::mutex> lock(children_mutex);
      for (auto it = children.begin(); it != children.end(); ++it)
        if (*it == owned) { children.erase(it); break; }
    }
    child_active = false;
    uv_close(reinterpret_cast<uv_handle_t*>(&owned->completion), [](uv_handle_t* h) {
      delete static_cast<Child*>(h->data);
    });
    return UV_EAGAIN;
  }
  return 0;
}

extern "C" void AShellUVClose(uv_process_t* process) {
  std::lock_guard<std::mutex> lock(children_mutex);
  for (auto* child : children) if (child->process == process) child->process = nullptr;
}

extern "C" int AShellUVKill(uv_process_t*, int) {
  // pthread_cancel is unsafe for embedded interpreters; never kill the app PID.
  return UV_ENOSYS;
}
