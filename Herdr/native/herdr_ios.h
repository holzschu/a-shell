#ifndef HERDR_IOS_H
#define HERDR_IOS_H

#ifdef __cplusplus
extern "C" {
#endif

/* Call on an ios_system command thread with streams already installed.
 * argv is borrowed. The command owns duplicated descriptors, not host FILEs.
 * Supports original local UI and informational flags. Other CLI paths return 78.
 * Status: 0 success, 1 I/O error, 2 invalid arguments, 16 singleton busy,
 * 70 caught Rust panic, 78 unsupported embedded operation.
 * Server and socketpair endpoints live only during this embedded command.
 * The host supplies the seven-argument ashell_pane_spawn ABI and related functions.
 */
int herdr_ios_main(int argc, const char **argv);
/* Call when host terminal dimensions change. Zero dimensions are ignored. */
void herdr_ios_resize(unsigned short cols, unsigned short rows);

#ifdef __cplusplus
}
#endif
#endif
