// Embed one process runtime and a fresh Node environment per concurrent command.
#include "node.h"
#include "node_version.h"
#import <UIKit/UIKit.h>
extern "C" {
const char* ios_progname(void);
const void* ios_getContext(void);
#include "ios_system.h"
}

#include <cstdio>
#include <atomic>
#include <csignal>
#include <cstring>
#include <fcntl.h>
#include <map>
#include <memory>
#include <mutex>
#include <pthread.h>
#include <string>
#include <unistd.h>
#include <vector>
#include "uv.h"

namespace node {
void AShellSetErrorStream(FILE*);
}

namespace {
struct CancellationScope {
  int previous;
  bool interrupted = false;
  CancellationScope() { pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &previous); }
  ~CancellationScope() {
    // ios_kill queues pthread_cancel even after calling our handler. Leave it
    // disabled on this disposable command thread so ios_system stores our status.
    if (!interrupted) pthread_setcancelstate(previous, nullptr);
  }
};
struct InterruptState {
  node::Environment* env;
  v8::Isolate* isolate;
  uv_async_t* notification;
  int input;
  v8::Global<v8::Object> process;
  std::atomic<bool> listening{false};
  std::atomic<bool> interrupted{false};
  std::atomic<bool> terminated{false};
  std::atomic<unsigned int> pending{0};
};
std::mutex interrupt_mutex;
std::multimap<std::string, InterruptState*> command_interrupts;

// ios_system calls sa_handler directly from the UI thread, not a POSIX signal
// frame. Never execute JS here, and hold the lifetime barrier through Stop().
void InterruptCommand(int) {
  std::lock_guard<std::mutex> lock(interrupt_mutex);
  const char* program = ios_progname();
  if (std::strcmp(program, "node") != 0 && std::strcmp(program, "npm") != 0 &&
      std::strcmp(program, "npx") != 0) return;
  const auto* session = static_cast<const char*>(ios_getContext());
  if (!session) return;
  const auto targets = command_interrupts.equal_range(session);
  // A pipeline's Node commands share the selected terminal session.
  for (auto target = targets.first; target != targets.second; ++target) {
    auto* state = target->second;
    state->interrupted = true;
    if (state->listening) {
      ++state->pending;
      uv_async_send(state->notification);
    } else {
      state->terminated = true;
      state->isolate->TerminateExecution();
      node::Stop(state->env);
    }
  }
}

void UpdateSignalListener(const v8::FunctionCallbackInfo<v8::Value>& info) {
  auto* state = static_cast<InterruptState*>(info.Data().As<v8::External>()->Value());
  state->listening = info[0]->BooleanValue(info.GetIsolate());
}

void DuplicateInput(const v8::FunctionCallbackInfo<v8::Value>& info) {
  auto* state = static_cast<InterruptState*>(info.Data().As<v8::External>()->Value());
  // A Node stream owns this duplicate; the adapter retains its own descriptor.
  info.GetReturnValue().Set(dup(state->input));
}

void EmitInterrupt(uv_async_t* handle) {
  auto* state = static_cast<InterruptState*>(handle->data);
  if (state->terminated) return;
  auto* isolate = state->isolate;
  v8::HandleScope scope(isolate);
  auto context = node::GetMainContext(state->env);
  v8::Context::Scope context_scope(context);
  v8::Local<v8::Value> args[] = {
      v8::String::NewFromUtf8Literal(isolate, "SIGINT"),
      v8::String::NewFromUtf8Literal(isolate, "SIGINT")};
  const auto count = state->pending.exchange(0);
  for (unsigned int i = 0; i < count; ++i) {
    if (!state->listening) {
      state->terminated = true;
      node::Stop(state->env);
      return;
    }
    node::MakeCallback(isolate, state->process.Get(isolate), "emit", 2, args,
                       node::async_context{0, 0});
    if (isolate->IsExecutionTerminating()) break;
  }
}
struct Runtime {
  std::unique_ptr<node::MultiIsolatePlatform> platform;
  Runtime() {
    auto result = node::InitializeOncePerProcess({"node"}, {
        node::ProcessInitializationFlags::kNoInitializeV8,
        node::ProcessInitializationFlags::kNoInitializeNodeV8Platform,
        node::ProcessInitializationFlags::kNoDefaultSignalHandling,
        node::ProcessInitializationFlags::kNoStdioInitialization,
        node::ProcessInitializationFlags::kNoAdjustResourceLimits,
        node::ProcessInitializationFlags::kDisableNodeOptionsEnv,
    });
    if (result->early_return()) return;
    platform = node::MultiIsolatePlatform::Create(2);
    v8::V8::InitializePlatform(platform.get());
    v8::V8::Initialize();
  }
};
}

extern "C" int node_ios_main(int argc, char** argv) {
  // V8 must unwind itself, never through pthread_cancel.
  CancellationScope cancellation;
  if (argc == 2 && (std::string(argv[1]) == "-v" ||
                    std::string(argv[1]) == "--version")) {
    fprintf(thread_stdout, "%s\n", NODE_VERSION);
    return 0;
  }
  // Process-global switches can terminate or mutate the hosting app. Expose only
  // command-local CLI switches until the remaining Node options are qualified.
  for (int i = 1; i < argc; ++i) {
    std::string arg(argv[i]);
    if (arg == "--") break;
    if (arg.empty() || arg[0] != '-') break;
    if (arg == "-e" || arg == "--eval" || arg == "-p" || arg == "--print" ||
        arg == "--import" || arg == "-r" || arg == "--require") {
      if (++i == argc) {
        fprintf(thread_stderr, "Missing argument for %s.\n", arg.c_str());
        return 9;
      }
    } else if (arg != "--no-warnings" && arg != "--input-type=module" &&
               arg != "--input-type=commonjs") {
      fprintf(thread_stderr, "Unsupported embedded Node option: %s\n", arg.c_str());
      return 9;
    }
  }
  // Runtime intentionally lives until app exit: V8 cannot be reinitialized.
  static Runtime& runtime = *new Runtime();
  if (!runtime.platform) return 1;
  std::vector<std::string> args(argv, argv + argc);
  // a-Shell commands receive pipes rather than a kernel TTY. Select Node's
  // existing REPL explicitly for the no-argument command.
  if (argc == 1) args.emplace_back("-i");


  FILE* streams[] = {thread_stdin, thread_stdout, thread_stderr};
  int fds[] = {-1, -1, -1};
  for (int i = 0; i < 3; ++i) {
    if (!streams[i] || (fds[i] = dup(fileno(streams[i]))) < 0) {
      fprintf(thread_stderr, "Cannot duplicate Node command streams.\n");
      for (int fd : fds) if (fd >= 0) close(fd);
      return 1;
    }
  }
  node::AShellSetErrorStream(thread_stderr);
  // uv_pipe_open changes O_NONBLOCK on the shared open-file description.
  // Preserve the caller's input flags when releasing the command stream.
  const int input_flags = fcntl(fds[0], F_GETFL);
  int rc = 1;
  {
    std::vector<std::string> errors;
    auto setup = node::CommonEnvironmentSetup::CreateForCommand(
        runtime.platform.get(), &errors, args,
        static_cast<node::EnvironmentFlags::Flags>(
            node::EnvironmentFlags::kTrackUnmanagedFds |
            node::EnvironmentFlags::kNoNativeAddons |
            node::EnvironmentFlags::kNoCreateInspector |
            node::EnvironmentFlags::kNoStartDebugSignalHandler), &rc);
    if (!setup) {
      for (const auto& error : errors)
        fprintf(thread_stderr, "%s\n", error.c_str());
    } else {
      auto* isolate = setup->isolate();
      v8::Locker locker(isolate);
      v8::Isolate::Scope isolate_scope(isolate);
      v8::HandleScope handle_scope(isolate);
      v8::Context::Scope context_scope(setup->context());
      bool requested_exit = false;
      node::SetProcessExitHandler(setup->env(), [&](node::Environment* env, int code) {
        requested_exit = true;
        rc = code;
        node::Stop(env);
      });
      InterruptState interrupt{setup->env(), isolate, new uv_async_t, fds[0], {}};
      uv_async_init(setup->event_loop(), interrupt.notification, EmitInterrupt);
      interrupt.notification->data = &interrupt;
      uv_unref(reinterpret_cast<uv_handle_t*>(interrupt.notification));
      const auto* context = static_cast<const char*>(ios_getContext());
      std::multimap<std::string, InterruptState*>::iterator registration;
      {
        std::lock_guard<std::mutex> lock(interrupt_mutex);
        // ios_system restores a command's signal handlers on completion. V8's
        // process runtime survives, so each command must reinstall its dispatcher.
        struct sigaction action{};
        action.sa_handler = InterruptCommand;
        sigemptyset(&action.sa_mask);
        sigaction(SIGINT, &action, nullptr);
        registration = command_interrupts.emplace(context ? context : "", &interrupt);
      }
      auto loaded = node::LoadEnvironment(
          setup->env(), node::StartExecutionCallback{},
          [command_env = setup->env(), output_fd = fds[1],
           error_fd = fds[2], command_interrupt = &interrupt,
           interactive = argc == 1](node::Environment* env, v8::Local<v8::Value> process,
              v8::Local<v8::Value> require) {
            // Workers inherit this callback but keep their stock message-port
            // streams and signal handling; never enter a parent's V8 context.
            if (env != command_env) return;
            auto* isolate = v8::Isolate::GetCurrent();
            auto context = isolate->GetCurrentContext();
            // Use owned command descriptors, never process-wide fd 0/1/2.
            command_interrupt->process.Reset(isolate, process.As<v8::Object>());
            std::string source =
                "(function(process, require, environment, appdir, updateSignal, inputDescriptor) {"
                "const fs = require('fs');"
                "for (const key of Object.keys(process.env)) delete process.env[key];"
                "Object.assign(process.env, environment);"
                "require('module')._initPaths();"
                "Object.defineProperty(process, 'execPath', {value: appdir + '/bin/node'});"
                "const SyncWriteStream = require('internal/fs/sync_write_stream');"
                "const signal = require('internal/process/signal');"
                "process.removeListener('newListener', signal.startListeningIfSignal);"
                "process.removeListener('removeListener', signal.stopListeningIfSignal);"
                "process.on('newListener', (name) => {"
                "if (name === 'SIGINT') updateSignal(true);"
                "else signal.startListeningIfSignal(name); });"
                "process.on('removeListener', (name) => {"
                "if (name === 'SIGINT') updateSignal(process.listenerCount(name) > 0);"
                "else signal.stopListeningIfSignal(name); });"
                "Object.defineProperties(process, {"
                "stdout: {value: new SyncWriteStream(" + std::to_string(output_fd) +
                ", {autoClose:false}), configurable:true},"
                "stderr: {value: new SyncWriteStream(" + std::to_string(error_fd) +
                ", {autoClose:false}), configurable:true},"
                "stdin: {configurable:true, get() {"
                "const fd = inputDescriptor();"
                "const type = require('internal/util').guessHandleType(fd);"
                "const stream = type === 'PIPE' || type === 'TCP' ?"
                "new (require('net').Socket)({fd, readable:true, writable:false}) :"
                "fs.createReadStream(null, {fd, autoClose:true});"
                "Object.defineProperty(process, 'stdin', {value:stream, configurable:true});"
                "return stream; }} });";
            if (interactive) {
              source +=
                  "const cliRepl = require('internal/repl');"
                  "const createRepl = cliRepl.createInternalRepl;"
                  "cliRepl.createInternalRepl = (env, cb) => createRepl(env,"
                  "{terminal:false, breakEvalOnSigint:false}, (err, repl) => {"
                  "if (!err) process.on('SIGINT', () => repl.emit('SIGINT'));"
                  "cb(err, repl); });";
            }
            source += "})";
            auto code = v8::String::NewFromUtf8(isolate, source.c_str()).ToLocalChecked();
            v8::Local<v8::Script> script;
            v8::Local<v8::Value> fn;
            if (v8::Script::Compile(context, code).ToLocal(&script) &&
                script->Run(context).ToLocal(&fn)) {
              auto environment = v8::Object::New(isolate);
              // The POSIX snapshot also supports embedders without a shell session.
              for (char** entry = environmentVariables(ios_currentPid()); *entry; ++entry) {
                std::string item(*entry);
                auto separator = item.find('=');
                if (separator == std::string::npos) continue;
                auto key = v8::String::NewFromUtf8(isolate, item.substr(0, separator).c_str()).ToLocalChecked();
                auto value = v8::String::NewFromUtf8(isolate, item.c_str() + separator + 1).ToLocalChecked();
                environment->CreateDataProperty(context, key, value).Check();
              }
              auto appdir = v8::String::NewFromUtf8(isolate, NSBundle.mainBundle.bundlePath.UTF8String).ToLocalChecked();
              auto update_signal = v8::Function::New(context,
                  UpdateSignalListener, v8::External::New(isolate, command_interrupt)).ToLocalChecked();
              auto input_descriptor = v8::Function::New(context,
                  DuplicateInput, v8::External::New(isolate, command_interrupt)).ToLocalChecked();
              v8::Local<v8::Value> values[] = {process, require, environment, appdir, update_signal, input_descriptor};
              v8::Local<v8::Value> ignored;
              if (!fn.As<v8::Function>()->Call(context, v8::Undefined(isolate),
                                               6, values).ToLocal(&ignored)) return;
            }
          });
      if (!loaded.IsEmpty()) {
        int loop_rc = node::SpinEventLoop(setup->env()).FromMaybe(1);
        if (!requested_exit) rc = loop_rc;
      }
      {
        std::lock_guard<std::mutex> lock(interrupt_mutex);
        command_interrupts.erase(registration);
      }
      cancellation.interrupted = interrupt.interrupted;
      if (interrupt.terminated) rc = 130;
      node::Stop(setup->env());
      interrupt.process.Reset();
      uv_close(reinterpret_cast<uv_handle_t*>(interrupt.notification),
               [](uv_handle_t* handle) { delete reinterpret_cast<uv_async_t*>(handle); });
      uv_run(setup->event_loop(), UV_RUN_NOWAIT);
    }
  }
  node::AShellSetErrorStream(nullptr);
  if (input_flags >= 0) fcntl(fds[0], F_SETFL, input_flags);
  for (int fd : fds) close(fd);
  return rc;
}

namespace {
int npm_command(int argc, char** argv, const char* entry) {
  const char* appdir = NSBundle.mainBundle.bundlePath.UTF8String;
  if (!appdir) {
    fprintf(thread_stderr, "Cannot locate the application bundle for npm.\n");
    return 1;
  }
  std::vector<std::string> args = {"node", std::string(appdir) +
      "/npm/bin/" + entry};
  for (int i = 1; i < argc; ++i) args.emplace_back(argv[i]);
  std::vector<char*> pointers;
  for (auto& arg : args) pointers.push_back(arg.data());
  pointers.push_back(nullptr);
  return node_ios_main(static_cast<int>(args.size()), pointers.data());
}
}

extern "C" int npm_ios_main(int argc, char** argv) {
  return npm_command(argc, argv, "npm-cli.js");
}

extern "C" int npx_ios_main(int argc, char** argv) {
  return npm_command(argc, argv, "npx-cli.js");
}
