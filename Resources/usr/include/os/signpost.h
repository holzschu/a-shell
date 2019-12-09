/*
 * Copyright (c) 2017-2018 Apple Inc. All rights reserved.
 */

#ifndef __OS_SIGNPOST_H__
#define __OS_SIGNPOST_H__

#include <os/log.h>

__BEGIN_DECLS

OS_ASSUME_NONNULL_BEGIN

/*!
 * @header os_signpost
 *
 * The os_signpost APIs let clients add lightweight instrumentation to
 * code for collection and visualization by performance analysis tooling.
 *
 * Clients of os_signpost can instrument interesting periods of time
 * ('intervals') and single points in time ('events'). Intervals can span
 * processes, be specific to one process, or be specific to a single thread.
 *
 * Intervals and events include an os_log-style format string and arguments
 * which can be used to convey contextual information.
 */

#pragma mark - Interval Matching Scope

/*!
 * The matching scope for signpost intervals logged with a given os_log_t is
 * specified in that log handles's configuration plist using the
 * 'Signpost-Scope' key and defaults to process-wide scope (i.e. 'Process'
 * value) if unspecified.
 *
 * Signpost interval begin and end matching can have 3 different scopes:
 *
 * - Thread-wide: The search scope for matching begins and ends is restricted to
 *   single threads. To set this as the search scope for an os_log_t, set
 *   'Thread' as the string value for the 'Signpost-Scope' key in the
 *   os_log_t's configuration plist.
 *
 * - Process-wide (Default value): The search scope for matching begins and ends
 *   is restricted to a single process. (i.e. no cross-process intervals)
 *   To set this as the search scope for an os_log_t, set
 *   'Process' as the string value for the 'Signpost-Scope' key in the
 *   os_log_t's configuration plist or do not specify any 'Signpost-Scope' key-
 *   value pair.
 *
 * - System-wide: The search scope for matching begins and ends is not
 *   restricted. (i.e. cross-process intervals are possible)
 *   To set this as the search scope for an os_log_t, set
 *   'System' as the string value for the 'Signpost-Scope' key in the
 *   os_log_t's configuration plist.
 *
 */


#pragma mark - Signpost IDs

/*!
 * Disambiguating intervals with signpost IDs
 *
 * Intervals with matching log handles and interval names can be in-flight
 * simultaneously. In order for data processing tools to correctly the matching
 * begin/end pairs, it is necessary to identify each interval with an
 * os_signpost_id_t.
 *
 * If there will only ever be one interval with a given os_log_t and interval
 * name will be in-flight at a time, use the os_signpost_t convenience value
 * OS_SIGNPOST_ID_EXCLUSIVE.  This can avoid having to share state between
 * begin and end callsites.
 *
 * If there exists some non-pointer uint64_t value which can uniquely identify
 * begin/end pairs, that value can be cast directly to an os_signpost_id_t.
 * Note that the values 'OS_SIGNPOST_ID_NULL' and 'OS_SIGNPOST_ID_INVALID' are
 * reserved and identical values may not be used in this manner.
 *
 * If there exists a pointer which can identify begin/end pairs, an
 * os_signpost_id_t can be generated from that pointer with
 * os_signpost_id_make_with_pointer() This approach is not applicable to
 * signposts that span process boundaries.
 *
 * If no existing pointer or value is applicable, a new unique value can be
 * generated using the os_signpost_id_generate() function.  The returned value
 * is guaranteed to be unique within the matching scope specified on the log
 * handle.
 */

/*!
 * @typedef os_signpost_id_t
 *
 * @brief
 * The type to represent a signpost ID.
 *
 * @discussion.
 * Any 64-bit value can be cast to an os_signpost_id_t except for the
 * OS_SIGNPOST_ID_NULL and OS_SIGNPOST_ID_INVALID reserved values.
 *
 * @const OS_SIGNPOST_ID_NULL
 * Represents the null (absent) signpost ID. It is used by the signpost
 * subsystem when a given signpost is disabled.
 *
 * @const OS_SIGNPOST_ID_INVALID
 * Represents an invalid signpost ID, which signals that an error has occurred.
 *
 * @const OS_SIGNPOST_ID_EXCLUSIVE
 * A convenience value for signpost intervals that will never occur
 * concurrently.
 */
typedef uint64_t os_signpost_id_t;
#ifndef __swift__
#define OS_SIGNPOST_ID_NULL      ((os_signpost_id_t)0)
#define OS_SIGNPOST_ID_INVALID   ((os_signpost_id_t)~0)
#define OS_SIGNPOST_ID_EXCLUSIVE ((os_signpost_id_t)0xEEEEB0B5B2B2EEEE)
#endif

/*!
 * @function os_signpost_id_make_with_pointer
 *
 * @abstract
 * Make an os_signpost_id from a pointer value.
 *
 * @discussion
 * Mangles the pointer to create a valid os_signpost_id, including removing
 * address randomization. Checks that the signpost matching scope is not
 * system-wide.
 *
 * @param log
 * Log handle previously created with os_log_create.
 *
 * @param ptr
 * Any pointer that disambiguates among concurrent intervals with the same
 * os_log_t and interval names.
 *
 * @result
 * Returns a valid os_signpost_id_t. Returns OS_SIGNPOST_ID_NULL if signposts
 * are turned off. Returns OS_SIGNPOST_ID_INVALID if the log handle is
 * system-scoped.
 */
API_AVAILABLE(macos(10.14), ios(12.0), tvos(12.0), watchos(5.0))
OS_EXPORT OS_NOTHROW
os_signpost_id_t
os_signpost_id_make_with_pointer(os_log_t log, const void *_Nullable ptr);

#if __OBJC__
/*!
 * @function os_signpost_id_make_with_id
 *
 * @abstract
 * Make an os_signpost_id from an Objective-C id, as in
 * os_signpost_id_make_with_pointer.
 */
#define os_signpost_id_make_with_id(log, ptr) \
        os_signpost_id_make_with_pointer(log, (__bridge const void *_Nullable)(ptr))
#endif /* __OBJC__ */

/*!
 * @function os_signpost_id_generate
 *
 * @abstract
 * Generates an ID guaranteed to be unique within the matching scope of the
 * provided log handle.
 *
 * @discussion
 * Each call to os_signpost_id_generate() with a given log handle and its
 * matching scope will return a different os_signpost_id_t.
 *
 * @param log
 * Log handle previously created with os_log_create.
 *
 * @result
 * Returns a valid os_signpost_id_t. Returns OS_SIGNPOST_ID_NULL if signposts
 * are disabled.
 */
API_AVAILABLE(macos(10.14), ios(12.0), tvos(12.0), watchos(5.0))
OS_EXPORT OS_NOTHROW OS_WARN_RESULT
os_signpost_id_t
os_signpost_id_generate(os_log_t log);

#pragma mark - Signpost Enablement

/*!
 * @function os_signpost_enabled
 *
 * @abstract
 * Returns true if signpost log messages are enabled for a particular log
 * handle.
 *
 * @discussion
 * Returns true if signpost log messages are enabled for a particular log.
 * Use this to avoid doing expensive argument marshalling leading into a call
 * to os_signpost_*
 *
 * @param log
 * Log handle previously created with os_log_create.
 *
 * @result
 * Returns ‘true’ if signpost log messages are enabled.
 */
API_AVAILABLE(macos(10.14), ios(12.0), tvos(12.0), watchos(5.0))
OS_EXPORT OS_NOTHROW OS_PURE OS_WARN_RESULT
bool
os_signpost_enabled(os_log_t log);
#pragma mark - Interval begin/end

/*!
 * @function os_signpost_interval_begin
 *
 * @abstract
 * Begins a signposted interval.
 *
 * @param log
 * Log handle previously created with os_log_create.
 *
 * @param interval_id
 * An ID for the event, see Signpost IDs above.
 *
 * @param name
 * The name of this event. This must be a string literal.
 *
 * @param ... (format + arguments)
 * Additional information to include with this signpost.  This format string
 * must be a string literal, as with the os_log family of functions.
 */
#define os_signpost_interval_begin(log, interval_id, name, ...) \
        os_signpost_emit_with_type(log, OS_SIGNPOST_INTERVAL_BEGIN, \
                interval_id, name, ##__VA_ARGS__)

/*!
 * @function os_signpost_interval_end
 *
 * @abstract
 * Ends a signposted interval.
 *
 * @param log
 * The log handle which was provided to os_signpost_interval_begin,
 *
 * @param interval_id
 * The ID for the event which was provided to os_signpost_interval_begin.  See
 * Signpost IDs above.
 *
 * @param name
 * The name of the event provided to os_signost_interval_begin. This must be a
 * string literal.
 *
 * @param ... (format + arguments)
 * Additional information to include with this signpost.  This format string
 * must be a string literal, as with the os_log family of functions.
 */
#define os_signpost_interval_end(log, interval_id, name, ...) \
        os_signpost_emit_with_type(log, OS_SIGNPOST_INTERVAL_END, \
                interval_id, name, ##__VA_ARGS__)

#pragma mark - Signpost event marking

/*!
 * @function os_signpost_event_emit
 *
 * @abstract
 * os_signpost_event_emit marks a point of interest in time with no duration.
 *
 * @param log
 * Log handle previously created with os_log_create.
 *
 * @param event_id
 * An ID for the event, see Signpost IDs above. If an event is emitted with the
 * same log handle, event_id, and name as an in-flight interval in the relevant
 * scope, it will be associated with the interval.  If there's no associated
 * interval, use an arbitrary valid number, like OS_SIGNPOST_ID_EXCLUSIVE.
 *
 * @param name
 * The name of this event. This must be a string literal.
 *
 * @param ... (format + arguments)
 * Additional information to include with this signpost.  This format string
 * must be a string literal, as with the os_log family of functions.
 */
#define os_signpost_event_emit(log, event_id, name, ...) \
        os_signpost_emit_with_type(log, OS_SIGNPOST_EVENT, \
                event_id, name, ##__VA_ARGS__)

#pragma mark - Points of Interest

/*!
 * @const OS_LOG_CATEGORY_POINTS_OF_INTEREST
 *
 * Provide this value as the category to os_log_create to indicate that
 * signposts on the resulting log handle provide high-level events that can be
 * used to orient a developer looking at performance data.  These will be
 * displayed by default by performance tools like Instruments.app.
 */
#ifndef __swift__
#define OS_LOG_CATEGORY_POINTS_OF_INTEREST "PointsOfInterest"
#endif

#pragma mark - Dynamic Tracing

/*!
 * @const OS_LOG_CATEGORY_DYNAMIC_TRACING
 *
 * Provide this value as the category to os_log_create to indicate that
 * signposts emitted to the resulting log handle should be disabled by
 * default, reducing the runtime overhead. os_signpost_enabled calls on
 * the resulting log handle will only return 'true' when a performance
 * tool like Instruments.app is recording.
 */
#if OS_LOG_TARGET_HAS_10_15_FEATURES
#ifndef __swift__
#define OS_LOG_CATEGORY_DYNAMIC_TRACING "DynamicTracing"
#endif
#endif

/*!
 * @const OS_LOG_CATEGORY_DYNAMIC_STACK_TRACING
 *
 * Provide this value as the category to os_log_create to indicate that
 * signposts emitted to the resulting log handle should capture user
 * backtraces. This behavior is more expensive, so os_signpost_enabled
 * will only return 'true' when a performance tool like Instruments.app
 * is recording.
 */
#if OS_LOG_TARGET_HAS_10_15_FEATURES
#ifndef __swift__
#define OS_LOG_CATEGORY_DYNAMIC_STACK_TRACING "DynamicStackTracing"
#endif
#endif

#pragma mark - Signpost Internals

/*!
 * @typedef os_signpost_type_t
 *
 * @brief
 * The type of a signpost tracepoint, do not use directly.
 */
OS_ENUM(os_signpost_type, uint8_t,
    OS_SIGNPOST_EVENT           = 0x00,
    OS_SIGNPOST_INTERVAL_BEGIN  = 0x01,
    OS_SIGNPOST_INTERVAL_END    = 0x02,
);
#ifndef __swift__
#define OS_SIGNPOST_TYPE_MASK     0x03
#endif

API_AVAILABLE(macos(10.14), ios(12.0), tvos(12.0), watchos(5.0))
OS_EXPORT OS_NOTHROW OS_NOT_TAIL_CALLED
void
_os_signpost_emit_with_name_impl(void *dso, os_log_t log,
        os_signpost_type_t type, os_signpost_id_t spid, const char *name,
        const char *format, uint8_t *buf, uint32_t size);

#define _os_signpost_emit_with_type(emitfn, log, type, spid, name, ...) \
    __extension__({ \
        os_log_t _log_tmp = (log); \
        os_signpost_type_t _type_tmp = (type); \
        os_signpost_id_t _spid_tmp = (spid); \
        if (_spid_tmp != OS_SIGNPOST_ID_NULL && \
                _spid_tmp != OS_SIGNPOST_ID_INVALID && \
                os_signpost_enabled(_log_tmp)) { \
            OS_LOG_CALL_WITH_FORMAT_NAME((emitfn), \
                    (&__dso_handle, _log_tmp, _type_tmp, _spid_tmp), \
                    name, "" __VA_ARGS__); \
        } \
    })

#if OS_LOG_TARGET_HAS_10_14_FEATURES
#define os_signpost_emit_with_type(log, type, spid, name, ...) \
        _os_signpost_emit_with_type(_os_signpost_emit_with_name_impl, log, \
                type, spid, name, ##__VA_ARGS__)
#else
#define os_signpost_emit_with_type(log, type, spid, name, ...) \
    __extension__({ \
        if (_os_signpost_emit_with_name_impl != NULL) { \
            _os_signpost_emit_with_type(_os_signpost_emit_with_name_impl, log, \
                    type, spid, name, ##__VA_ARGS__); \
        } \
    })
#endif

OS_ASSUME_NONNULL_END

__END_DECLS

#endif // __OS_SIGNPOST_H__
