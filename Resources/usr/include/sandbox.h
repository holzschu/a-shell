/*
 * Copyright (c) 2006-2011,2018 Apple Inc. All rights reserved.
 */


/*
 * This header is deprecated and may be removed in a future release.
 * Developers who wish to sandbox an app should instead adopt the App Sandbox
 * feature described in the App Sandbox Design Guide.
 */


#ifndef _SANDBOX_H_
#define _SANDBOX_H_

#include <os/availability.h>
#include <sys/cdefs.h>
#include <stdint.h>

__BEGIN_DECLS

/*
 * @function sandbox_init
 * Places the current process in a sandbox with a profile as
 * specified.  If the process is already in a sandbox, the new profile
 * is ignored and sandbox_init() returns an error.
 *
 * @param profile (input)   The Sandbox profile to be used.  The format
 * and meaning of this parameter is modified by the `flags' parameter.
 *
 * @param flags (input)   Must be SANDBOX_NAMED.  All other
 * values are reserved.
 *
 * @param errorbuf (output)   In the event of an error, sandbox_init
 * will set `*errorbuf' to a pointer to a NUL-terminated string
 * describing the error. This string may contain embedded newlines.
 * This error information is suitable for developers and is not
 * intended for end users.
 *
 * If there are no errors, `*errorbuf' will be set to NULL.  The
 * buffer `*errorbuf' should be deallocated with `sandbox_free_error'.
 *
 * @result 0 on success, -1 otherwise.
 */
API_DEPRECATED("No longer supported", macos(10.5, 10.8), ios(2.0, 6.0), tvos(4.0, 4.0), watchos(1.0, 1.0))
/* API_UNAVAILABLE(macCatalyst) */
__result_use_check
int sandbox_init(const char *profile, uint64_t flags, char **errorbuf);

/*
 * @define SANDBOX_NAMED  The `profile' argument specifies a Sandbox
 * profile named by one of the kSBXProfile* string constants.
 */
#define SANDBOX_NAMED		0x0001

/*
 * Available Sandbox profiles.
 */

/* TCP/IP networking is prohibited. */
API_DEPRECATED("No longer supported", macos(10.5, 10.8), ios(2.0, 6.0), tvos(4.0, 4.0), watchos(1.0, 1.0))
/* API_UNAVAILABLE(macCatalyst) */
extern const char kSBXProfileNoInternet[];

/* All sockets-based networking is prohibited. */
API_DEPRECATED("No longer supported", macos(10.5, 10.8), ios(2.0, 6.0), tvos(4.0, 4.0), watchos(1.0, 1.0))
/* API_UNAVAILABLE(macCatalyst) */
extern const char kSBXProfileNoNetwork[];

/* File system writes are prohibited. */
API_DEPRECATED("No longer supported", macos(10.5, 10.8), ios(2.0, 6.0), tvos(4.0, 4.0), watchos(1.0, 1.0))
/* API_UNAVAILABLE(macCatalyst) */
extern const char kSBXProfileNoWrite[];

/* File system writes are restricted to temporary folders /var/tmp and
 * confstr(_CS_DARWIN_USER_DIR, ...).
 */
API_DEPRECATED("No longer supported", macos(10.5, 10.8), ios(2.0, 6.0), tvos(4.0, 4.0), watchos(1.0, 1.0))
/* API_UNAVAILABLE(macCatalyst) */
extern const char kSBXProfileNoWriteExceptTemporary[];

/* All operating system services are prohibited. */
API_DEPRECATED("No longer supported", macos(10.5, 10.8), ios(2.0, 6.0), tvos(4.0, 4.0), watchos(1.0, 1.0))
/* API_UNAVAILABLE(macCatalyst) */
extern const char kSBXProfilePureComputation[];

/*
 * @function sandbox_free_error
 * Deallocates an error string previously allocated by sandbox_init.
 *
 * @param errorbuf (input)   The buffer to be freed.  Must be a pointer
 * previously returned by sandbox_init in the `errorbuf' argument, or NULL.
 *
 * @result void
 */
API_DEPRECATED("No longer supported", macos(10.5, 10.8), ios(2.0, 6.0), tvos(4.0, 4.0), watchos(1.0, 1.0))
/* API_UNAVAILABLE(macCatalyst) */
void sandbox_free_error(char *errorbuf);

__END_DECLS

#endif /* _SANDBOX_H_ */
