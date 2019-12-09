/*
 *  cache_callbacks.h
 *
 *  Copyright 2008 Apple. All rights reserved.
 *
 */

#ifndef _CACHE_CALLBACKS_H_
#define _CACHE_CALLBACKS_H_

#include <cache.h>

__BEGIN_DECLS

/*
 * Pre-defined callback functions.
 */

CACHE_PUBLIC_API uintptr_t cache_key_hash_cb_cstring(void *key, void *unused) API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));
CACHE_PUBLIC_API uintptr_t cache_key_hash_cb_integer(void *key, void *unused) API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));

CACHE_PUBLIC_API bool cache_key_is_equal_cb_cstring(void *key1, void *key2, void *unused) API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));
CACHE_PUBLIC_API bool cache_key_is_equal_cb_integer(void *key1, void *key2, void *unused) API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));

CACHE_PUBLIC_API void cache_release_cb_free(void *key_or_value, void *unused) API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));

CACHE_PUBLIC_API void cache_value_make_purgeable_cb(void *value, void *unused) API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));
CACHE_PUBLIC_API bool cache_value_make_nonpurgeable_cb(void *value, void *unused) API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));

/* Default hash function for byte strings.  */
CACHE_PUBLIC_API uintptr_t cache_hash_byte_string(const char *data, size_t bytes) API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));

 __END_DECLS

#endif /* _CACHE_CALLBACKS_H_ */
