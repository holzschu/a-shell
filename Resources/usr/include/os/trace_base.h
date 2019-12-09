/*
 * Copyright (c) 2016 Apple Inc. All rights reserved.
 */

#ifndef __OS_TRACE_BASE_H__
#define __OS_TRACE_BASE_H__

#include <mach-o/loader.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

#include <os/availability.h>
#include <os/base.h>
#include <os/object.h>

#define OS_LOG_FORMATLIKE(x, y)  __attribute__((format(os_log, x, y)))

#define __OS_LOG_OS_FEATURES_AT_LEAST(macos, ios, tvos, watchos) \
        (  (defined(__MAC_OS_X_VERSION_MIN_REQUIRED) && __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_##macos) \
        || (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_##ios) \
        || (defined(__TV_OS_VERSION_MIN_REQUIRED) && __TV_OS_VERSION_MIN_REQUIRED >= __TVOS_##tvos) \
        || (defined(__WATCH_OS_VERSION_MIN_REQUIRED) && __WATCH_OS_VERSION_MIN_REQUIRED >= __WATCHOS_##watchos) \
        )

#if __OS_LOG_OS_FEATURES_AT_LEAST(10_15, 13_0, 13_0, 6_0)
#define OS_LOG_TARGET_HAS_10_15_FEATURES 1
#else
#define OS_LOG_TARGET_HAS_10_15_FEATURES 0
#endif

#if __OS_LOG_OS_FEATURES_AT_LEAST(10_14, 12_0, 12_0, 5_0)
#define OS_LOG_TARGET_HAS_10_14_FEATURES 1
#else
#define OS_LOG_TARGET_HAS_10_14_FEATURES 0
#endif

#if __OS_LOG_OS_FEATURES_AT_LEAST(10_13, 11_0, 11_0, 4_0)
#define OS_LOG_TARGET_HAS_10_13_FEATURES 1
#else
#define OS_LOG_TARGET_HAS_10_13_FEATURES 0
#endif

#if __OS_LOG_OS_FEATURES_AT_LEAST(10_12, 10_0, 10_0, 3_0)
#define OS_LOG_TARGET_HAS_10_12_FEATURES 1
#else
#define OS_LOG_TARGET_HAS_10_12_FEATURES 0
#endif

#ifndef OS_COUNT_ARGS
#define OS_COUNT_ARGS(...) OS_COUNT_ARGS1(, ##__VA_ARGS__, _8, _7, _6, _5, _4, _3, _2, _1, _0)
#define OS_COUNT_ARGS1(z, a, b, c, d, e, f, g, h, cnt, ...) cnt
#endif

#ifdef OS_LOG_FORMAT_WARNINGS
#define OS_LOG_FORMAT_ERRORS _Pragma("clang diagnostic warning \"-Wformat\"")
#else
#define OS_LOG_FORMAT_ERRORS _Pragma("clang diagnostic error \"-Wformat\"")
#endif

#define OS_LOG_PRAGMA_PUSH \
        _Pragma("clang diagnostic push") \
        _Pragma("clang diagnostic ignored \"-Wvla\"") \
        OS_LOG_FORMAT_ERRORS

#define OS_LOG_PRAGMA_POP  _Pragma("clang diagnostic pop")

#if __has_attribute(uninitialized)
#define OS_LOG_UNINITIALIZED __attribute__((uninitialized))
#else
#define OS_LOG_UNINITIALIZED
#endif

#define OS_LOG_STRING(_ns, _var, _str) \
        _Static_assert(__builtin_constant_p(_str), \
                "format/label/description argument must be a string constant"); \
        __attribute__((section("__TEXT,__oslogstring,cstring_literals"),internal_linkage)) \
        static const char _var[] __asm(OS_STRINGIFY(OS_CONCAT(LOS_##_ns, __COUNTER__))) = _str


#define OS_LOG_REMOVE_PARENS(...) __VA_ARGS__

#define OS_LOG_CALL_WITH_FORMAT(fun, fun_args, fmt, ...) __extension__({ \
        OS_LOG_PRAGMA_PUSH OS_LOG_STRING(LOG, _os_fmt_str, fmt); \
        uint8_t _Alignas(16) OS_LOG_UNINITIALIZED _os_fmt_buf[__builtin_os_log_format_buffer_size(fmt, ##__VA_ARGS__)]; \
        fun(OS_LOG_REMOVE_PARENS fun_args, _os_fmt_str, \
                (uint8_t *)__builtin_os_log_format(_os_fmt_buf, fmt, ##__VA_ARGS__), \
                (uint32_t)sizeof(_os_fmt_buf)) OS_LOG_PRAGMA_POP; \
})

#define OS_LOG_CALL_WITH_FORMAT_NAME(fun, fun_args, name, fmt, ...) __extension__({ \
        OS_LOG_PRAGMA_PUSH OS_LOG_STRING(LOG, _os_fmt_str, fmt); \
        OS_LOG_STRING(LOG, _os_name_str, name); \
        uint8_t _Alignas(16) OS_LOG_UNINITIALIZED _os_fmt_buf[__builtin_os_log_format_buffer_size(fmt, ##__VA_ARGS__)]; \
        fun(OS_LOG_REMOVE_PARENS fun_args, _os_name_str, _os_fmt_str, \
                (uint8_t *)__builtin_os_log_format(_os_fmt_buf, fmt, ##__VA_ARGS__), \
                (uint32_t)sizeof(_os_fmt_buf)) OS_LOG_PRAGMA_POP; \
})

__BEGIN_DECLS

extern struct mach_header __dso_handle;

__END_DECLS

#endif // !__OS_TRACE_BASE_H__
