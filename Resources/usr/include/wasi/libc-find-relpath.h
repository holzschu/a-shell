#ifndef __wasi_libc_find_relpath_h
#define __wasi_libc_find_relpath_h

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Look up the given path in the preopened directory map. If a suitable
 * entry is found, return its directory file descriptor, and store the
 * computed relative path in *relative_path.
 *
 * Returns -1 if no directories were suitable.
 */
int __wasilibc_find_relpath(const char *path, const char **relative_path);

#ifdef __cplusplus
}
#endif

#endif
