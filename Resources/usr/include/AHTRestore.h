//
//  AHTRestore.h
//  AppleInputDeviceSupport
//
//  Created by Lorenzo Soto on 04/12/16.
//
//

#pragma once

#include <CoreFoundation/CoreFoundation.h>

#ifdef __cplusplus
extern "C" {
#endif

#define AHTRESTORE_LIBNAME "libAHTRestore.dylib"
#define AHTRESTORE_LIST_DEVICES_CALLNAME "AHTRestoreCreateDeviceList"
#define AHTRESTORE_UPDATE_DEVICE_CALLNAME "AHTRestoreUpdateDevice" // DEPRECATED
#define AHTRESTORE_UPDATE_DEVICE_WITH_OVERRIDES_CALLNAME "AHTRestoreUpdateDeviceWithOverrides"

// AHTRestoreCreateDeviceList dictionaries keys
#define AHTRESTORE_DEVICE_NAME_KEY "DeviceName"
#define AHTRESTORE_IMAGE_TAG_KEY "ImageTag"
#define AHTRESTORE_NEEDS_UPDATE_KEY "NeedsUpdate"

// AHTRestoreUpdateDeviceWithOverrides dictionary keys
#define AHTRESTORE_LOCK_CHIP_KEY "LockChip"
#define AHTRESTORE_IGNORE_FAILURES_KEY "IgnoreFailures"
#define AHTRESTORE_SKIP_UPDATE_KEY "SkipUpdate"

#define EXPORT __attribute__((visibility("default")))

typedef enum AHTRestoreReturn {
    kAHTRestoreReturnSuccess = 0,
    kAHTRestoreReturnNoDevice = -1,
    kAHTRestoreReturnNoFirmware = -2,
    kAHTRestoreReturnWriteFail = -3,
    kAHTRestoreReturnReadFail = -4,
    kAHTRestoreReturnVerifyFail = -5,
    kAHTRestoreReturnWrongDevice = -6,
} AHTRestoreReturn;

// DEPRECATED
typedef enum AHTRestoreOption {
    kAHTRestoreOptionLock = 1 << 0,
} AHTRestoreOption;

// Returns an array of dictionaries describing the devices available in the system
// Note that we are changing name from AHTRestoreListDevices to AHTRestoreCreateDeviceList
// because the function name has to include keyword 'create' otherwise returning
// a retained variable will throw a static analysis warning.
EXPORT CFArrayRef AHTRestoreCreateDeviceList(void);

EXPORT AHTRestoreReturn AHTRestoreUpdateDevice(const char* deviceName,
                                               CFDataRef image,
                                               uint32_t options);

EXPORT AHTRestoreReturn AHTRestoreUpdateDeviceWithOverrides(const char* deviceName,
                                                            CFDataRef image,
                                                            CFDictionaryRef overrides);

typedef __typeof(AHTRestoreCreateDeviceList) * AHTRestoreListDevicesFuncPtr;
typedef __typeof(AHTRestoreUpdateDevice) * AHTRestoreUpdateDeviceFuncPtr;
typedef __typeof(AHTRestoreUpdateDeviceWithOverrides) * AHTRestoreUpdateDeviceWithOverridesFuncPtr;

#ifdef __cplusplus
}
#endif
