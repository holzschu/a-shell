#pragma once
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

// Returned UTF-8 JSON is owned by the caller; release it with asml_free.
// A successful begin owns the process-wide permit until end, even between calls.
// Requests are bounded process-local capabilities; create before queueing to allow cancellation.
char *asml_request(int *status);
// Bind an owned directory's fixed "cancel" file to a prepared request; duplicates fd.
char *asml_request_file(int directory, const char *nonce, int *status);
// Capability-scoped progress; do not expose another job's request via global status.
char *asml_request_status(const char *request, int *status);
int asml_job(int argc, char **argv, FILE *out, FILE *err);
char *asml_begin_request(const char *model, const char *units, const char *request, int *status);
char *asml_cancel(const char *request, int *status);
char *asml_status(int *status);
// Nonblocking lifecycle/pressure stop; status 75 means unavailable, 130 means user cancel.
void asml_stop(int status);
// Terminal interrupt targets commands and requests submitted by this ios_system session.
int asml_interrupt_session(const char *session);
// Installer polling on the command thread shares cooperative terminal cancellation.
int asml_command_interrupted(void);
// Installer validation shares inference admission. End only after a successful begin
// and after all temporary validation models and native buffers have been released.
int asml_maintenance_begin(void);
void asml_maintenance_end(void);
char *asml_begin(const char *model, const char *units, int *status);
char *asml_describe(const char *token, int *status);
char *asml_predict(const char *token, const uint8_t *pixels, size_t length, int *status);
char *asml_end(const char *token, int *status);
char *asml_unload(int *status);
void asml_free(void *value);
// App targets hide C symbols by default; ios_system resolves SELF commands with dlsym.
__attribute__((used, visibility("default"))) int coreml_main(int argc, char **argv);
// Execute the same command with caller-owned streams; no shell or interpreter dispatch.
int asml_command(int argc, char **argv, FILE *out, FILE *err);
