/*!
 @header cache.h
 
 @abstract UNIX-level caching API.  
 
 @discussion
 Provides a dictionary associating keys with values.
 The cache determines its size and may remove keys at any time.
 Cache keeps reference counts for cache values and preserves values until
 unreferenced.  Unreferenced values may be removed at any time.
 
 All API functions return 0 for success, non-zero for failure.  Most
 functions can return EINVAL for malformed arguments and ENOMEM for
 allocation failures.  See function descriptions for other return values.
 
 Cache functions rely upon a per-cache lock to provide thread safety.  
 Calling cache functions from cache callbacks should be avoided to 
 prevent deadlock.
 
 @copyright Copyright (c) 2007-2008 Apple Inc. All rights reserved.
 
 @updated 03-10-2008 
 */

#ifndef _CACHE_H_
#define _CACHE_H_

#include <TargetConditionals.h>
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <os/availability.h>



#include <sys/cdefs.h> 
#ifndef CACHE_PUBLIC_API
#ifdef __GNUC__
/*! @parseOnly */
#define CACHE_PUBLIC_API __attribute__((__visibility__("default")))
#else
/*! @parseOnly */
#error __GNUC__ not defined
#define CACHE_PUBLIC_API
#endif /* __GNUC__ */
#endif /* CACHE_PUBLIC_API */



#ifndef __BEGIN_DECLS
#define __BEGIN_DECLS extern "C" {
#endif
#ifndef __END_DECLS 
#define __END_DECLS }
#endif

__BEGIN_DECLS

/*!
 * @typedef cache_t
 *
 * @abstract 
 * Opaque cache object.
 *
 * @discussion
 * Dictionary associating keys with values.
 */
typedef struct cache_s cache_t;

/*!
 * @typedef cache_attributes_t
 *
 * @abstract 
 * Cache attributes
 *
 * @discussion
 * Collection of callbacks used by cache_create() to customize cache behavior.
 */
typedef struct cache_attributes_s cache_attributes_t;

/*!
 * @typedef cache_cost_t
 * 
 * @abstract
 * Cost of maintaining a value in the cache.  
 *
 * @discussion
 * Cache uses cost when deciding
 * which value to evict.  Usually related to a value's memory size in bytes.
 * Zero is a valid cost.
 */
typedef size_t cache_cost_t;

/*!
 * @function cache_create
 *
 * @abstract 
 * Creates a cache object.
 *
 * @param name 
 * Cache name used for debugging and performance tools.  Name
 * should be in reverse-DNS form, e.g. "com.mycompany.myproject.mycache" 
 * and must not be NULL.  Name is copied.
 *
 * @param attrs 
 * Cache attributes used to customize cache behavior.  Attributes
 * are defined below and must not be NULL.
 *
 * @param cache_out 
 * Cache object is stored here if cache is successfully 
 * created.  Must not be NULL.
 * 
 *@result Returns 0 for success, non-zero for failure.
 */
CACHE_PUBLIC_API int cache_create(const char *name, const cache_attributes_t *attrs, cache_t **cache_out) API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));

/*!
 * @function cache_set_and_retain
 * 
 * @abstract 
 * Sets value for key.
 *
 * @param cache 
 * Pointer to cache.  Must not be NULL.
 * 
 * @param key 
 * Key to add.  Must not be NULL.
 *
 * @param value 
 * Value to add.  If value is NULL, key is associated with the value NULL.
 * 
 * @param cost 
 * Cost of maintaining value in cache.
 * 
 * @result Returns 0 for success, non-zero for failure.
 * 
 * @discussion
 * Sets value for key.  Value is retained until released using 
 * cache_release_value().  The key retain callback (if provided) is
 * invoked on key.
 * 
 * Replaces previous key and value if present.  Invokes the key release
 * callback immediately for the previous key.  Invokes the value release
 * callback once the previous value's retain count is zero.
 * 
 * Cost indicates the relative cost of maintaining value in the cache 
 * (e.g., size of value in bytes) and may be used by the cache under 
 * memory pressure to select which cache values to evict.  Zero is a 
 * valid cost. 
 */
CACHE_PUBLIC_API int cache_set_and_retain(cache_t *cache, void *key, void *value, cache_cost_t cost) API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));

/*!
 * @function cache_get_and_retain
 * 
 * @abstract 
 * Fetches value for key.
 *
 * @param cache 
 * Pointer to cache.  Must not be NULL.
 * 
 * @param key 
 * Key used to lookup value.  Must not be NULL.
 *
 * @param value_out 
 * Value is stored here if found.  Must not be NULL.
 *
 * @result Returns 0 for success, ENOENT if not found, other non-zero for failure.
 * 
 * @discussion
 * Fetches value for key, retains value, and stores value in value_out.
 * Caller should release value using cache_release_value(). 
 */
CACHE_PUBLIC_API int cache_get_and_retain(cache_t *cache, void *key, void **value_out) API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));

/*!
 * @function cache_release_value
 *
 * @abstract 
 * Releases a previously retained cache value.
 *
 * @param cache 
 * Pointer to cache.  Must not be NULL.
 * 
 * @param value 
 * Value to release.  Must not be NULL.
 *
 * @result Returns 0 for success, non-zero for failure.
 * 
 * @discussion 
 * Releases a previously retained cache value. When the reference count 
 * reaches zero the cache may make the value purgeable or destroy it. 
 */
CACHE_PUBLIC_API int cache_release_value(cache_t *cache, void *value) API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));

/*!
 * @function cache_remove
 *
 * @abstract 
 * Removes a key and its value.
 * 
 * @param cache 
 * Pointer to cache.  Must not be NULL.
 *
 * @param key 
 * Key to remove.  Must not be NULL.
 *
 * @result Returns 0 for success, non-zero for failure.
 * 
 * @discussion
 * Removes a key and its value from the cache such that cache_get_and_retain()
 * will fail.  Invokes the key release callback immediately.  Invokes the 
 * value release callback once value's retain count is zero. 
 */
CACHE_PUBLIC_API int cache_remove(cache_t *cache, void *key) API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));

/*!
 *@function cache_remove_all
 *
 * @abstract 
 * Invokes cache_remove on all keys. 
 * 
 * @param cache 
 * Pointer to cache.  Must not be NULL.
 *
 * @result Returns 0 for success, non-zero for failure.
 */
CACHE_PUBLIC_API int cache_remove_all(cache_t *cache) API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));

/*! 
 * @function cache_destroy
 *
 * @abstract 
 * Destroys cache
 *
 * @param cache 
 * Pointer to cache.  Must not be NULL.
 * 
 * @result Returns 0 for success, non-zero for failure.  Returns EAGAIN if 
 * the cache was not destroyed because retained cache values exist.
 *
 * @discussion
 * Invokes cache_remove_all().  If there are no retained cache values then
 * the cache object is freed.  If retained cache values exist then 
 * returns EAGAIN. 
 */
CACHE_PUBLIC_API int cache_destroy(cache_t *cache) API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));

/*!
 * @group Cache Callbacks
 */

/*!
 * @typedef cache_key_hash_cb_t
 *
 * @abstract 
 * Calculates a hash value using key.
 * 
 * @param key 
 * Key to user to calculate hash.
 *
 * @param user_data 
 * User-provided value passed during cache creation.
 *
 * @discussion 
 * Calculates and returns a key hash.  If the callback is NULL then a key
 * will be converted from a pointer to an integer to compute the hash code. 
 */
typedef uintptr_t (*cache_key_hash_cb_t)(void *key, void *user_data);

/*! 
 * @typedef cache_key_is_equal_cb_t
 *
 * @abstract 
 * Determines if two keys are equal.
 *
 * @param key1 
 * First key
 *
 * @param key2 
 * Second key
 * 
 * @param user_data 
 * User-provided value passed during cache creation.
 *
 * @result 
 * Returns true if equal, false if not equal.
 * 
 * @discussion 
 * Determines if two keys are equal.  If the callback is NULL then 
 * the cache uses pointer equality to test equality for keys. 
 */
typedef bool (*cache_key_is_equal_cb_t)(void *key1, void *key2, void *user_data);

/*! 
 * @typedef cache_key_retain_cb_t
 *
 * @abstract 
 * Retains a key.
 *
 * @param key_in
 * Key provided in cache_set_and_retain()
 *
 * @param key_out
 * Set key to add here.  If NULL, cache_set_and_retain() will fail.
 *
 * @param user_data 
 * User-provided value passed during cache creation.
 *
 * @discussion 
 * Called when it is added to the cache through
 * cache_set_and_retain.  The cache will add the key stored in key_out
 * and may release it at any time by calling the key release callback.
 * If key_out is NULL then no key will be added.  If callback is NULL then
 * the cache adds key_in. 
 */
typedef void (*cache_key_retain_cb_t)(void *key_in, void **key_out, void *user_data);

/*! 
 * @typedef cache_value_retain_cb_t
 *
 * @abstract 
 * Retains a value.
 *
 * @param value_in
 * Value provided in cache_set_and_retain()
 *
 * @param user_data 
 * User-provided value passed during cache creation.
 *
 * @discussion 
 * Called when a unique value is added to the cache through cache_set_and_retain().
 * Allows the client to retain value_in before it is added to the cache.  The cache
 * will call any value_release_cb after removing a cache value.
 */
typedef void (*cache_value_retain_cb_t)(void *value_in, void *user_data);

/*! 
 * @typedef cache_release_cb_t
 * 
 * @abstract 
 * Releases or deallocates a cache value.
 *
 * @param key_or_value
 * Key or value to release
 *
 * @param user_data 
 * User-provided value passed during cache creation.
 *
 * @discussion
 * Called when a key or value is removed from the cache, ie. when the
 * cache no longer references it.  In the common case the key or value
 * should be deallocated, or released if reference counted.
 * If the callback is NULL then it is not called.
 */
typedef void (*cache_release_cb_t)(void *key_or_value, void *user_data);

/*!
 * @typedef cache_value_make_nonpurgeable_cb_t
 *
 * @abstract
 * Makes a cache value nonpurgeable and tests to see if value is still valid.
 *
 * @param value
 * Cache value to make nonpurgeable.
 *
 * @param user_data User-provided value passed during cache creation.
 *
 * @result Should return true if value is valid, or false if it was purged.
 *
 * @discussion
 * Purged cache values will be removed.  If the callback is
 * NULL then the cache does not make value nonpurgeable.  
 */
typedef bool (*cache_value_make_nonpurgeable_cb_t)(void *value, void *user_data);

/*! 
 * @typedef cache_value_make_purgeable_cb_t
 *
 * @abstract
 * Makes a cache value purgeable.  
 *
 * @param value
 * Cache value to make purgeable.
 *
 * @param user_data 
 * User-provided value passed during cache creation.
 *
 * @discussion
 * Called when the cache determines that no cache clients reference the value.  
 * If the callback is NULL then the cache does not make value purgeable. 
 */
typedef void (*cache_value_make_purgeable_cb_t)(void *value, void *user_data);

/*! @group */

/*!
 * @struct cache_attributes_s
 * 
 * @abstract Callbacks passed to cache_create() to customize cache behavior.
 *
 * @field key_hash_cb Key hash callback.
 * @field key_is_equal_cb Key is equal callback.
 * @field key_retain_cb Key retain callback.
 * @field key_release_cb Key release callback.
 * @field value_retain_cb Value retain callback.
 * @field value_release_cb Value release callback.
 * @field value_make_nonpurgeable_cb Value make nonpurgeable callback.
 * @field value_make_purgeable_cb Value make purgeable callback.
 * @field version Attributes version number used for binary compatibility.
 * @field user_data Passed to all callbacks.  May be NULL.
 */
struct CACHE_PUBLIC_API cache_attributes_s {
    uint32_t version;
    cache_key_hash_cb_t key_hash_cb;                               
    cache_key_is_equal_cb_t key_is_equal_cb;                        
    
    cache_key_retain_cb_t  key_retain_cb;
    cache_release_cb_t key_release_cb;
    cache_release_cb_t value_release_cb;                           
    
    cache_value_make_nonpurgeable_cb_t value_make_nonpurgeable_cb; 
    cache_value_make_purgeable_cb_t value_make_purgeable_cb;       
    
    void *user_data;

	// Added in CACHE_ATTRIBUTES_VERSION_2
	cache_value_retain_cb_t value_retain_cb;
};
#define CACHE_ATTRIBUTES_VERSION_1 1 
#define CACHE_ATTRIBUTES_VERSION_2 2 

__END_DECLS

#endif /* _CACHE_H_ */

