#import "AShellML.h"
#import "AShellMLInstall.h"
#import "AShellEmbedding.h"
#import <Foundation/Foundation.h>
#import <CoreML/CoreML.h>
#import <mach/mach.h>
#import <os/proc.h>
#import <TargetConditionals.h>
#import <fcntl.h>
#import <sys/stat.h>
#import <unistd.h>
#import <pthread.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
extern __thread FILE *thread_stdout;
extern __thread FILE *thread_stderr;
extern const void *ios_getContext(void);
extern void set_session_errno(int status);
#endif

static dispatch_queue_t worker;
static dispatch_semaphore_t permit;
static MLModel *warmModel;
static NSDictionary *warmGraphs;
static NSString *warmKey, *cacheID, *jobToken, *generation;
static NSDictionary *modelReceipt, *memoryBefore;
static NSCondition *admission;
static NSMutableDictionary<NSString *, NSMutableDictionary *> *requests;
static NSMutableArray<NSString *> *waiting;
static NSMutableArray<NSMutableDictionary *> *commandSessions;
static NSString *owner;
static BOOL maintenance;
static dispatch_source_t idleTimer;
static BOOL cacheHit;
static void evict(void);
static void finish(NSString *token);
static void observeLifecycle(void);
static double loadMS, verificationMS, modelLoadMS;
static BOOL verificationCached;
static int embeddingCommand(int argc, char **argv, FILE *out, FILE *err);

static void initialize(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        worker = dispatch_queue_create("org.ashell.coreml", dispatch_queue_attr_make_with_autorelease_frequency(DISPATCH_QUEUE_SERIAL, DISPATCH_AUTORELEASE_FREQUENCY_WORK_ITEM));
        permit = dispatch_semaphore_create(1);
        generation = [NSUUID UUID].UUIDString;
        admission = [NSCondition new];
        requests = [NSMutableDictionary dictionary];
        waiting = [NSMutableArray array];
        commandSessions = [NSMutableArray array];
        idleTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, worker);
        dispatch_source_set_timer(idleTimer, DISPATCH_TIME_FOREVER, DISPATCH_TIME_FOREVER, 0);
        dispatch_source_set_event_handler(idleTimer, ^{ if (!jobToken) evict(); });
        dispatch_resume(idleTimer);
        observeLifecycle();
    });
}

static NSError *failure(int code, NSString *message) {
    return [NSError errorWithDomain:@"AShellML" code:code userInfo:@{NSLocalizedDescriptionKey:message}];
}

static char *encode(id value) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingSortedKeys error:nil];
    return strdup([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding].UTF8String);
}

static char *respond(id value, NSError *error, int *status) {
    if (!value && !error) error = failure(1, @"Core ML operation returned no result");
    *status = error ? ([error.domain isEqual:@"AShellML"] ? (int)error.code : 1) : 0;
    return encode(error ? @{ @"error":error.localizedDescription, @"status":@(*status) } : value);
}

static BOOL mainCaller(int *status, char **result) {
    (void)status; (void)result;
#if TARGET_OS_IPHONE
    if ([NSThread isMainThread]) {
        *result = respond(nil, failure(75, @"Core ML operations must run off the main thread"), status);
        return YES;
    }
#endif
    return NO;
}

static void evict(void) {
    warmModel = nil; warmGraphs = nil; warmKey = nil; cacheID = nil;
    if (modelReceipt[@"lease_id"]) ASMLReleaseVersion(modelReceipt[@"lease_id"]);
    modelReceipt = nil;
}

static void finish(NSString *token) {
    if (![jobToken isEqual:token]) return;
    jobToken = nil;
    [admission lock];
    BOOL cancelled = [requests[token][@"stop"] intValue] != 0;
    if (cancelled) requests[token][@"state"] = @"finished"; else [requests removeObjectForKey:token]; owner = nil;
    [admission broadcast]; [admission unlock];
    if (cancelled) evict();
    dispatch_source_set_timer(idleTimer, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, NSEC_PER_SEC);
    dispatch_semaphore_signal(permit);
}

// Read only the job's fixed file through its retained directory. Never follow a
// replacement symlink or accept another job's nonce as a cancellation request.
static int pollStop(NSMutableDictionary *job) {
    if (!job[@"stop"] || [job[@"stop"] intValue] || !job[@"cancel_directory"]) return [job[@"stop"] intValue];
    int fd = openat([job[@"cancel_directory"] fileDescriptor], "cancel", O_RDONLY | O_NOFOLLOW | O_NONBLOCK);
    if (fd < 0) { if (errno != ENOENT) job[@"stop"] = @2; return [job[@"stop"] intValue]; }
    struct stat st; char bytes[37];
    if (fstat(fd, &st) || !S_ISREG(st.st_mode) || st.st_nlink != 1) job[@"stop"] = @2;
    else if (st.st_size == 36 && read(fd, bytes, sizeof(bytes)) == 36 && !memcmp(bytes, [job[@"cancel_nonce"] UTF8String], 36)) job[@"stop"] = @130;
    close(fd);
    return [job[@"stop"] intValue];
}

static NSError *stopped(NSString *token) {
    if (!token) return failure(2, @"Invalid inference request token");
    [admission lock]; int code = pollStop(requests[token]); [admission unlock];
    return code ? failure(code, code == 130 ? @"Inference cancelled" : @"Inference stopped by lifecycle or memory pressure") : nil;
}

char *asml_request_file(int directory, const char *nonce, int *status) {
    @autoreleasepool {
        if (!nonce || strlen(nonce) != 36) return respond(nil, failure(2, @"Invalid job nonce"), status);
        int fd = dup(directory);
        if (fd < 0) return respond(nil, failure(1, @"Cannot retain job directory"), status);
        char *raw = asml_request(status);
        if (*status) { close(fd); return raw; }
        NSDictionary *value = [NSJSONSerialization JSONObjectWithData:[@(raw) dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        [admission lock];
        requests[value[@"request"]][@"cancel_directory"] = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
        requests[value[@"request"]][@"cancel_nonce"] = @(nonce);
        [admission unlock];
        return raw;
    }
}

char *asml_request(int *status) {
    @autoreleasepool {
        initialize();
        [admission lock];
        if (requests.count >= 16) { [admission unlock]; return respond(nil, failure(75, @"Inference request queue is full (16)"), status); }
        NSString *token = [NSUUID UUID].UUIDString;
        requests[token] = [@{@"stop":@0, @"state":@"prepared"} mutableCopy];
        [admission unlock];
        return respond(@{@"request":token}, nil, status);
    }
}

char *asml_request_status(const char *request, int *status) {
    @autoreleasepool {
        initialize(); [admission lock];
        NSDictionary *job = request ? requests[@(request)] : nil;
        NSDictionary *value = job ? @{@"state":job[@"state"], @"completed_chunks":job[@"completed_chunks"] ?: @0} : nil;
        [admission unlock];
        return respond(value, value ? nil : failure(2, @"Unknown or completed inference request"), status);
    }
}

int asml_maintenance_begin(void) {
    initialize();
#if TARGET_OS_IPHONE
    if ([NSThread isMainThread]) return 75;
#endif
    if (dispatch_semaphore_wait(permit, DISPATCH_TIME_NOW)) return 75;
    [admission lock]; maintenance = YES; [admission unlock];
    dispatch_sync(worker, ^{ @autoreleasepool { evict(); } });
    return 0;
}

void asml_maintenance_end(void) {
    initialize(); [admission lock];
    if (maintenance) { maintenance = NO; dispatch_semaphore_signal(permit); [admission broadcast]; }
    [admission unlock];
}

char *asml_status(int *status) {
    @autoreleasepool {
        initialize(); [admission lock];
        NSDictionary *value = @{@"queued":@(waiting.count), @"active":@(owner != nil), @"completed_chunks":owner ? (requests[owner][@"completed_chunks"] ?: @0) : @0, @"maintenance":@(maintenance), @"requests":@(requests.count), @"generation":generation};
        [admission unlock]; return respond(value, nil, status);
    }
}

char *asml_cancel(const char *request, int *status) {
    @autoreleasepool {
        initialize(); NSString *token = request ? [NSString stringWithUTF8String:request] : nil;
        [admission lock];
        NSMutableDictionary *job = token ? requests[token] : nil;
        if (!job) { [admission unlock]; return respond(nil, failure(2, @"Unknown or completed inference request"), status); }
        job[@"stop"] = @130;
        if ([job[@"state"] isEqual:@"prepared"]) [requests removeObjectForKey:token];
        [admission broadcast]; [admission unlock];
        // Serial cleanup runs after the native prediction, never while its buffers are live.
        dispatch_async(worker, ^{ finish(token); });
        return respond(@{@"cancel_requested":token}, nil, status);
    }
}

void asml_stop(int status) {
    initialize();
    [admission lock];
    for (NSMutableDictionary *job in requests.allValues) if (![job[@"stop"] intValue]) job[@"stop"] = @(status == 130 ? 130 : 75);
    NSArray *prepared = [requests keysOfEntriesPassingTest:^BOOL(NSString *key, NSDictionary *job, BOOL *stop) {
        (void)key; (void)stop; return [job[@"state"] isEqual:@"prepared"];
    }].allObjects;
    [requests removeObjectsForKeys:prepared];
    [admission broadcast]; [admission unlock];
    dispatch_async(worker, ^{
        if (jobToken && stopped(jobToken)) finish(jobToken);
        if (!jobToken) evict();
    });
}

int asml_interrupt_session(const char *session) {
    @autoreleasepool {
        if (!session) return 0;
        initialize(); NSString *name = [NSString stringWithUTF8String:session];
        [admission lock];
        NSUInteger commands = 0;
        for (NSMutableDictionary *command in commandSessions) if ([command[@"session"] isEqual:name]) { command[@"stop"] = @YES; commands++; }
        NSArray *tokens = [requests keysOfEntriesPassingTest:^BOOL(NSString *key, NSDictionary *job, BOOL *stop) {
            (void)key; (void)stop; return [job[@"session"] isEqual:name] && ![job[@"state"] isEqual:@"finished"];
        }].allObjects;
        [admission unlock];
        for (NSString *token in tokens) { int status; asml_free(asml_cancel(token.UTF8String, &status)); }
        return commands != 0 || tokens.count != 0;
    }
}

int asml_command_interrupted(void) {
    initialize();
    [admission lock]; BOOL stop = [NSThread.currentThread.threadDictionary[@"ASMLCommand"][@"stop"] boolValue]; [admission unlock];
    return stop;
}

static void observeLifecycle(void) {
#if TARGET_OS_IPHONE
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(NSNotification *note) { (void)note; asml_stop(75); }];
    [center addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil queue:nil usingBlock:^(NSNotification *note) { (void)note; asml_stop(75); }];
    [center addObserverForName:UIApplicationProtectedDataWillBecomeUnavailable object:nil queue:nil usingBlock:^(NSNotification *note) { (void)note; asml_stop(75); }];
    [center addObserverForName:UISceneWillDeactivateNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene != note.object && scene.activationState == UISceneActivationStateForegroundActive) return;
        }
        asml_stop(75);
    }];
#endif
}


static NSDictionary *memory(void) {
    task_vm_info_data_t info = {0};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t result = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count);
    NSMutableDictionary *value = [@{@"physical_ram":@([NSProcessInfo processInfo].physicalMemory), @"pid":@(getpid())} mutableCopy];
    if (result == KERN_SUCCESS) {
        value[@"footprint"] = @(info.phys_footprint);
        if (count >= TASK_VM_INFO_REV1_COUNT) value[@"lifetime_peak"] = @(info.ledger_phys_footprint_peak);
    }
#if TARGET_OS_IPHONE
    value[@"available"] = @(os_proc_available_memory());
#endif
    return value;
}

static BOOL allowed(NSError **error) {
    (void)error;
#if TARGET_OS_IPHONE
    if ([[NSBundle mainBundle].bundlePath containsString:@".appex"]) {
        *error = failure(75, @"Core ML requires the main application process"); return NO;
    }
    __block BOOL active;
    void (^readState)(void) = ^{ active = [UIApplication sharedApplication].applicationState == UIApplicationStateActive && [UIApplication sharedApplication].protectedDataAvailable; };
    if ([NSThread isMainThread]) readState(); else dispatch_sync(dispatch_get_main_queue(), readState);
    if (!active) { *error = failure(75, @"Core ML skeleton requires an active application scene"); return NO; }
#endif
    return YES;
}

static BOOL validateModel(MLModel *model, NSError **error) {
    NSDictionary *inputs = model.modelDescription.inputDescriptionsByName;
    MLFeatureDescription *image = inputs[@"image"];
    NSDictionary<NSString *, MLFeatureDescription *> *outputs = model.modelDescription.outputDescriptionsByName;
    if (inputs.count != 1 || image.type != MLFeatureTypeImage || image.imageConstraint.pixelsWide != 28 || image.imageConstraint.pixelsHigh != 28 || image.imageConstraint.pixelFormatType != kCVPixelFormatType_OneComponent8 || outputs[@"classLabel"].type != MLFeatureTypeInt64 || outputs[@"labelProbabilities"].type != MLFeatureTypeDictionary) {
        *error = failure(2, @"Unsupported model features; this adapter requires MNIST image uint8[28,28]"); return NO;
    }
    return YES;
}

static NSDictionary *describe(void) {
    NSMutableDictionary *profile = [(warmGraphs ? modelReceipt[@"memory_profile"] : @{@"kind":@"bounded-skeleton-estimate", @"additional_peak_bytes":@(64 * 1024 * 1024)}) mutableCopy];
    profile[@"reserve_min_bytes"] = @(128 * 1024 * 1024); profile[@"reserve_fraction"] = @0.2;
    return @{ @"model_id":modelReceipt[@"model_id"], @"runtime_abi":@1, @"backend":@"CoreML", @"cache_id":cacheID,
        @"cache_hit":@(cacheHit), @"cache_key":warmKey, @"load_ms":@(loadMS), @"verification_ms":@(verificationMS), @"model_load_ms":@(modelLoadMS), @"verification_cached":@(verificationCached), @"receipt":modelReceipt,
        @"inputs":warmGraphs ? modelReceipt[@"features"] : @{@"image":@{@"type":@"image", @"dtype":@"uint8", @"shape":@[@28,@28], @"contiguous":@YES}},
        @"outputs":warmGraphs ? modelReceipt[@"outputs"] : @{@"classLabel":@"int64", @"labelProbabilities":@"dictionary<int64,double>"}, @"memory":memory(), @"memory_before_load":memoryBefore, @"request":jobToken, @"memory_profile":profile, @"os":[NSProcessInfo processInfo].operatingSystemVersionString };
}

char *asml_begin(const char *model, const char *units, int *status) {
    return asml_begin_request(model, units, NULL, status);
}

static NSString *admit(NSString *request, NSError **error) {
    NSString *token;
    if (request) token = request;
    else {
        int code; char *json = asml_request(&code);
        NSDictionary *value = [NSJSONSerialization JSONObjectWithData:[[NSString stringWithUTF8String:json] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        asml_free(json);
        if (code) { *error = failure(code, @"Inference request queue is full"); return nil; }
        token = value[@"request"];
    }
    if (!token) { *error = failure(2, @"Invalid inference request token"); return nil; }
    [admission lock];
    NSMutableDictionary *job = requests[token];
    if (!job || ![job[@"state"] isEqual:@"prepared"]) { [admission unlock]; *error = failure(2, @"Request is unknown or already submitted"); return nil; }
    NSValue *caller = [NSValue valueWithPointer:(void *)pthread_self()];
    if (owner && [requests[owner][@"thread"] isEqual:caller]) {
        if (!request) [requests removeObjectForKey:token];
        [admission unlock];
        *error = failure(75, @"This thread already owns an inference context; close it before loading again"); return nil;
    }
    job[@"thread"] = caller;
    job[@"state"] = @"queued";
    if ([NSThread.currentThread.threadDictionary[@"ASMLCommand"][@"stop"] boolValue]) job[@"stop"] = @130;
#if TARGET_OS_IPHONE
    // The host passes NUL-terminated session names through ios_setContext.
    const char *session = ios_getContext();
    if (session) job[@"session"] = [NSString stringWithUTF8String:session];
#endif
    [waiting addObject:token];
    while (!pollStop(job)) {
        if ([waiting.firstObject isEqual:token] && !dispatch_semaphore_wait(permit, DISPATCH_TIME_NOW)) break;
        [admission waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    [waiting removeObject:token];
    int stop = [job[@"stop"] intValue];
    if (stop) { [requests removeObjectForKey:token]; [admission broadcast]; [admission unlock]; *error = failure(stop, stop == 130 ? @"Queued inference cancelled before load" : @"Queued inference unavailable"); return nil; }
    owner = token; job[@"state"] = @"running";
    [admission unlock];
    return token;
}

char *asml_begin_request(const char *model, const char *units, const char *request, int *status) {
    @autoreleasepool {
        initialize();
        NSError *error = nil;
        if (!model || (strcmp(model, "mnist") && !ASMLEmbeddingID(@(model))) || !units) return respond(nil, failure(2, @"Unsupported model id"), status);
#if TARGET_OS_IPHONE
        if ([NSThread isMainThread]) return respond(nil, failure(75, @"Core ML must run off the main thread"), status);
#endif
        if (!allowed(&error)) return respond(nil, error, status);
        MLComputeUnits compute;
        if (!strcmp(units, "all")) compute = MLComputeUnitsAll;
        else if (!strcmp(units, "cpu")) compute = MLComputeUnitsCPUOnly;
        else if (!strcmp(units, "cpu-gpu")) compute = MLComputeUnitsCPUAndGPU;
        else if (!strcmp(units, "cpu-ane")) {
            if (@available(iOS 16.0, macOS 13.0, *)) compute = MLComputeUnitsCPUAndNeuralEngine;
            else return respond(nil, failure(75, @"cpu-ane requires iOS 16 or macOS 13"), status);
        } else return respond(nil, failure(2, @"units must be all, cpu, cpu-gpu or cpu-ane"), status);
        NSString *token = admit(request ? [NSString stringWithUTF8String:request] : nil, &error);
        if (!token) return respond(nil, error, status);
        __block NSDictionary *value;
        __block NSError *workError;
        dispatch_sync(worker, ^{ @autoreleasepool {
            double started = [NSProcessInfo processInfo].systemUptime;
            modelLoadMS = 0; verificationCached = NO;
            workError = stopped(token);
            if (workError || !allowed(&workError)) return;
            NSDictionary *record = ASMLAcquireVersion([NSString stringWithUTF8String:model], ^NSError *{ return stopped(token); }, &workError);
            verificationMS = ([NSProcessInfo processInfo].systemUptime - started) * 1000;
            if (!record) { evict(); return; }
            verificationCached = [record[@"verification_cached"] boolValue];
            BOOL adopted = NO;
            @try {
            NSString *key = [NSString stringWithFormat:@"%@/%@/CoreML/%s/%s-v1/%@", record[@"manifest_sha256"], record[@"path"], units, model, generation];
            cacheHit = (warmModel || warmGraphs) && [key isEqual:warmKey];
            if (!cacheHit) {
                evict();
                memoryBefore = memory();
#if TARGET_OS_IPHONE
                size_t available = os_proc_available_memory();
                size_t reserve = MAX(128 * 1024 * 1024, available / 5);
                unsigned long long peak = strcmp(model, "mnist") ? [record[@"memory_profile"][@"additional_peak_bytes"] unsignedLongLongValue] : 64ULL * 1024 * 1024;
                if (available < reserve + peak) { workError = failure(75, [NSString stringWithFormat:@"Insufficient process headroom for model qualification (available=%zu reserve=%zu additional_peak=%llu)", available, reserve, peak]); return; }
#endif
                double modelStarted = NSProcessInfo.processInfo.systemUptime;
                NSURL *directory = [NSURL fileURLWithPath:record[@"path"] isDirectory:YES];
                // The installer authenticates portable members and compiled receipts.
                if (ASMLEmbeddingID(@(model))) {
                    warmGraphs = ASMLEmbeddingLoad([directory URLByAppendingPathComponent:@"model.mlmodelc"], [directory URLByAppendingPathComponent:@"package"], record, compute, &workError);
                    if (!warmGraphs) return;
                } else {
                MLModelConfiguration *configuration = [MLModelConfiguration new]; configuration.computeUnits = compute;
                MLModel *loaded = [MLModel modelWithContentsOfURL:[directory URLByAppendingPathComponent:@"model.mlmodelc"] configuration:configuration error:&workError];
                if (!loaded || !validateModel(loaded, &workError)) return;
                warmModel = loaded;
                }
                warmKey = key; cacheID = NSUUID.UUID.UUIDString; modelReceipt = record; adopted = YES;
                modelLoadMS = (NSProcessInfo.processInfo.systemUptime - modelStarted) * 1000;
            }
            loadMS = ([NSProcessInfo processInfo].systemUptime - started) * 1000;
            workError = stopped(token);
            if (workError) { evict(); return; }
            jobToken = token;
            NSMutableDictionary *result = [describe() mutableCopy]; result[@"token"] = jobToken; value = result;
            } @finally { if (!adopted) ASMLReleaseVersion(record[@"lease_id"]); }
        } });
        if (!value) {
            [admission lock]; [requests removeObjectForKey:token]; owner = nil; [admission broadcast]; [admission unlock];
            dispatch_semaphore_signal(permit);
        }
        return respond(value, workError, status);
    }
}

static BOOL validToken(const char *token, NSError **error) {
    if (token) {
        NSError *cancel = stopped([NSString stringWithUTF8String:token]);
        if (cancel) { *error = cancel; return NO; }
    }
    if (!token || !jobToken || ![jobToken isEqual:[NSString stringWithUTF8String:token]]) {
        *error = failure(2, @"Model context is closed or belongs to another job"); return NO;
    }
    return YES;
}

char *asml_describe(const char *token, int *status) {
    @autoreleasepool {
        initialize(); char *rejected; if (mainCaller(status, &rejected)) return rejected; __block NSDictionary *value; __block NSError *error;
        dispatch_sync(worker, ^{ @autoreleasepool { if (validToken(token, &error)) value = describe(); } });
        return respond(value, error, status);
    }
}

char *asml_predict(const char *token, const uint8_t *pixels, size_t length, int *status) {
    @autoreleasepool {
        initialize(); char *rejected; if (mainCaller(status, &rejected)) return rejected;
        if (length != 784 || !pixels) return respond(nil, failure(2, @"image must contain exactly 784 uint8 pixels in row-major 28x28 shape"), status);
        // Begin checks foreground eligibility; lifecycle notifications stop the active token.
        __block NSDictionary *value; __block NSError *error;
        dispatch_sync(worker, ^{ @autoreleasepool {
            if (!validToken(token, &error)) return;
            if (!warmModel) { error = failure(2, @"The grayscale prediction API requires the MNIST adapter"); return; }
            double started = [NSProcessInfo processInfo].systemUptime;
            CVPixelBufferRef buffer = NULL;
            CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault, 28, 28, kCVPixelFormatType_OneComponent8, NULL, &buffer);
            if (result != kCVReturnSuccess) { error = failure(1, @"Cannot allocate MNIST pixel buffer"); return; }
            result = CVPixelBufferLockBaseAddress(buffer, 0);
            if (result != kCVReturnSuccess) { CVPixelBufferRelease(buffer); error = failure(1, @"Cannot lock MNIST pixel buffer"); return; }
            uint8_t *base = CVPixelBufferGetBaseAddress(buffer);
            size_t stride = CVPixelBufferGetBytesPerRow(buffer);
            for (size_t row = 0; row < 28; row++) memcpy(base + row * stride, pixels + row * 28, 28);
            CVPixelBufferUnlockBaseAddress(buffer, 0);
            MLFeatureValue *image = [MLFeatureValue featureValueWithPixelBuffer:buffer];
            MLDictionaryFeatureProvider *input = [[MLDictionaryFeatureProvider alloc] initWithDictionary:@{@"image":image} error:&error];
            id<MLFeatureProvider> output = input ? [warmModel predictionFromFeatures:input error:&error] : nil;
            CVPixelBufferRelease(buffer);
            error = stopped([NSString stringWithUTF8String:token]) ?: error;
            if (error || !output) return;
            NSDictionary *rawScores = [output featureValueForName:@"labelProbabilities"].dictionaryValue;
            NSMutableDictionary *scores = [NSMutableDictionary dictionary];
            for (NSNumber *key in rawScores) scores[key.stringValue] = rawScores[key];
            NSString *label = [@([output featureValueForName:@"classLabel"].int64Value) stringValue];
            double sum = 0; BOOL valid = scores.count == 10 && label != nil;
            for (int i = 0; i < 10; i++) {
                NSNumber *score = scores[[@(i) stringValue]];
                valid = valid && score && isfinite(score.doubleValue) && score.doubleValue >= 0 && score.doubleValue <= 1;
                sum += score.doubleValue;
            }
            if (!valid || fabs(sum - 1) > 1e-4 || !scores[label]) { error = failure(1, @"Model produced invalid probabilities"); return; }
            [admission lock];
            NSMutableDictionary *job = requests[[NSString stringWithUTF8String:token]];
            job[@"completed_chunks"] = @([job[@"completed_chunks"] unsignedLongLongValue] + 1);
            [admission unlock];
            value = @{ @"label":label, @"scores":scores, @"cache_id":cacheID, @"cache_hit":@(cacheHit), @"cache_key":warmKey,
                @"load_ms":@(loadMS), @"predict_ms":@(([NSProcessInfo processInfo].systemUptime - started) * 1000), @"memory":memory() };
        } });
        return respond(value, error, status);
    }
}

char *asml_end(const char *token, int *status) {
    @autoreleasepool {
        initialize(); char *rejected; if (mainCaller(status, &rejected)) return rejected; __block NSError *error;
        dispatch_sync(worker, ^{ @autoreleasepool {
            if (token && [jobToken isEqual:[NSString stringWithUTF8String:token]]) finish(jobToken);
            // Cancellation may already have completed cleanup. Closing is idempotent.
            if (token) {
                NSString *name = [NSString stringWithUTF8String:token];
                [admission lock];
                if ([requests[name][@"state"] isEqual:@"finished"]) [requests removeObjectForKey:name];
                else if (requests[name]) error = failure(2, @"Request has not completed admission");
                [admission unlock];
            }
        } });
        return respond(@{@"closed":@YES}, error, status);
    }
}

char *asml_unload(int *status) {
    @autoreleasepool {
        initialize(); char *rejected; if (mainCaller(status, &rejected)) return rejected;
        if (dispatch_semaphore_wait(permit, DISPATCH_TIME_NOW)) return respond(nil, failure(75, @"Core ML is busy"), status);
        dispatch_sync(worker, ^{ @autoreleasepool { evict(); } });
        dispatch_semaphore_signal(permit);
        return respond(@{@"unloaded":@YES, @"memory":memory()}, nil, status);
    }
}

void asml_free(void *value) { free(value); }

int coreml_main(int argc, char **argv) {
    // ios_system uses pthread cancellation; defer it until locks, leases and native
    // buffers are released. Ctrl-C also requests cooperative session cancellation.
    int previous; pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &previous);
    int result;
    @autoreleasepool {
    initialize(); NSMutableDictionary *command = [NSMutableDictionary dictionary];
#if TARGET_OS_IPHONE
    // Capture ios_system TLS on the calling thread, before dispatching any work.
    FILE *out = thread_stdout ?: stdout, *err = thread_stderr ?: stderr;
    const char *session = ios_getContext();
    if (session) command[@"session"] = @(session);
#else
    FILE *out = stdout, *err = stderr;
#endif
    NSThread.currentThread.threadDictionary[@"ASMLCommand"] = command;
    [admission lock]; [commandSessions addObject:command]; [admission unlock];
    @try { result = asml_command(argc, argv, out, err); }
    @finally {
        [admission lock]; [commandSessions removeObjectIdenticalTo:command]; [admission unlock];
        [NSThread.currentThread.threadDictionary removeObjectForKey:@"ASMLCommand"];
    }
    }
#if TARGET_OS_IPHONE
    // Publish status before delivering pending cancellation inside ios_system's cleanup frame.
    set_session_errno(result);
#endif
    pthread_setcancelstate(previous, NULL);
    pthread_testcancel();
    return result;
}

int asml_command(int argc, char **argv, FILE *out, FILE *err) {
    @autoreleasepool {
        int status = 0; char *response = NULL;
        const char *usage = "Usage: coreml install MODEL PACKAGE [--sha256 DIGEST] | ls [MODEL] | remove MODEL | rollback MODEL | install-status MODEL | cancel-install MODEL GENERATION | info mnist | predict mnist IMAGE.gray [--repeat 1|2] [--iterations N] [--request UUID] | embed MODEL INPUT.json [--units cpu|all|cpu-gpu|cpu-ane] [--request UUID] | request | cancel UUID | status | unload | job create|status DIRECTORY | job run DIRECTORY coreml run mnist IMAGE.gray [OPTIONS]";
        if (argc == 2 && !strcmp(argv[1], "--help")) { fprintf(out, "%s\n", usage); return fflush(out) ? 1 : 0; }
        if (mainCaller(&status, &response)) { fprintf(err, "%s\n", response); asml_free(response); return status; }
        if (argc >= 2 && !strcmp(argv[1], "job")) return asml_job(argc, argv, out, err);
        if (argc >= 2 && !strcmp(argv[1], "embed")) return embeddingCommand(argc, argv, out, err);
        if (argc == 2 && !strcmp(argv[1], "request")) response = asml_request(&status);
        else if (argc == 2 && !strcmp(argv[1], "status")) response = asml_status(&status);
        else if (argc == 3 && !strcmp(argv[1], "cancel")) response = asml_cancel(argv[2], &status);
        else if (argc == 2 && !strcmp(argv[1], "unload")) response = asml_unload(&status);
        else if ((argc == 2 && !strcmp(argv[1], "ls")) || (argc == 3 && (!strcmp(argv[1], "rollback") || !strcmp(argv[1], "install-status"))) || (argc == 4 && !strcmp(argv[1], "cancel-install"))) {
            NSError *error = nil; NSDictionary *value = nil;
            if (!strcmp(argv[1], "ls")) value = ASMLInstalledVersion(@"mnist", &error);
            else if (!strcmp(argv[1], "rollback")) value = ASMLRollback([NSString stringWithUTF8String:argv[2]], &error);
            else if (!strcmp(argv[1], "install-status")) value = ASMLInstallStatus([NSString stringWithUTF8String:argv[2]], &error);
            else value = ASMLCancelInstall([NSString stringWithUTF8String:argv[2]], [NSString stringWithUTF8String:argv[3]], &error);
            response = respond(value, error, &status);
        }
        else if (argc == 3 && !strcmp(argv[1], "remove")) {
            NSError *error = nil;
            char *unloaded = asml_unload(&status); asml_free(unloaded);
            NSDictionary *value = status ? nil : ASMLRemove([NSString stringWithUTF8String:argv[2]], &error);
            if (status) error = failure(status, @"Core ML is busy");
            response = respond(value, error, &status);
        } else if (argc == 3 && !strcmp(argv[1], "ls")) {
            NSError *error = nil; NSDictionary *value = ASMLInstalledVersion([NSString stringWithUTF8String:argv[2]], &error); response = respond(value, error, &status);
        } else if ((argc == 4 || (argc == 6 && !strcmp(argv[4], "--sha256"))) && !strcmp(argv[1], "install") && strcmp(argv[2], "--manifest")) {
            NSError *error = nil; NSDictionary *value = ASMLInstallModelPackage([NSString stringWithUTF8String:argv[2]], [NSString stringWithUTF8String:argv[3]], argc == 6 ? [NSString stringWithUTF8String:argv[5]] : nil, &error);
            response = respond(value, error, &status);
        } else if ((argc == 3 || (argc == 5 && !strcmp(argv[3], "--sha256"))) && !strcmp(argv[1], "install") && strcmp(argv[2], "--manifest")) {
            NSError *error = nil; NSDictionary *value = ASMLInstallPackage([NSString stringWithUTF8String:argv[2]], argc == 5 ? [NSString stringWithUTF8String:argv[4]] : nil, &error);
            response = respond(value, error, &status);
        } else if (argc == 3 && !strcmp(argv[1], "info")) {
            response = asml_begin(argv[2], "cpu", &status);
            if (!status) {
                NSDictionary *value = [NSJSONSerialization JSONObjectWithData:[[NSString stringWithUTF8String:response] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                int closeStatus; asml_free(asml_end([value[@"token"] UTF8String], &closeStatus));
            }
        } else if (argc >= 4 && (!strcmp(argv[1], "run") || !strcmp(argv[1], "predict"))) {
            if (strcmp(argv[2], "mnist")) { fprintf(err, "predict/run accepts only mnist\n"); return 2; }
            unsigned long count = 1, iterations = 1;
            const char *request = NULL;
            BOOL valid = YES;
            for (int i = 4; i < argc; i += 2) {
                if (i + 1 >= argc) { valid = NO; break; }
                if (!strcmp(argv[i], "--request") && !request) request = argv[i + 1];
                else {
                    char *tail = NULL; unsigned long n = strtoul(argv[i + 1], &tail, 10);
                    if (!*argv[i + 1] || *tail || n < 1) { valid = NO; break; }
                    if (!strcmp(argv[i], "--repeat") && n <= 2) count = n;
                    else if (!strcmp(argv[i], "--iterations") && n <= 10000000) iterations = n;
                    else { valid = NO; break; }
                }
            }
            // Inspect without decoding/allocating the queued request's input.
            int fd = valid ? open(argv[3], O_RDONLY | O_NOFOLLOW | O_NONBLOCK) : -1;
            struct stat st;
            if (!valid || (request && count != 1) || fd < 0 || fstat(fd, &st) || !S_ISREG(st.st_mode) || st.st_size != 784) {
                response = respond(nil, failure(2, @"Input must be a regular 784-byte grayscale file; repeat 1..2, iterations 1..10000000, request requires repeat 1"), &status);
            } else {
                NSMutableArray *runs = [NSMutableArray array];
                for (unsigned long i = 0; i < count; i++) {
                    char *opened = asml_begin_request(argv[2], "cpu", request, &status);
                    NSDictionary *context = [NSJSONSerialization JSONObjectWithData:[[NSString stringWithUTF8String:opened] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                    if (status) { response = opened; break; }
                    NSString *token = context[@"token"]; asml_free(opened);
                    uint8_t pixels[784];
                    // Read only the bounded fixture after admission, retaining the inspected fd.
                    if (pread(fd, pixels, sizeof(pixels), 0) != sizeof(pixels) || fstat(fd, &st) || st.st_size != 784) {
                        response = respond(nil, failure(2, @"Input changed or could not be read"), &status);
                    } else {
                        for (unsigned long chunk = 0; chunk < iterations; chunk++) {
                            char *predicted = asml_predict(token.UTF8String, pixels, sizeof(pixels), &status);
                            if (status) { response = predicted; break; }
                            if (chunk + 1 == iterations) {
                                NSMutableDictionary *value = [[NSJSONSerialization JSONObjectWithData:[[NSString stringWithUTF8String:predicted] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] mutableCopy];
                                value[@"completed_chunks"] = @(iterations); [runs addObject:value];
                            }
                            asml_free(predicted);
                        }
                    }
                    int closeStatus; asml_free(asml_end(token.UTF8String, &closeStatus));
                    if (response) break;
                }
                if (!response) response = encode(@{@"runs":runs});
            }
            if (fd >= 0) close(fd);
        } else response = respond(nil, failure(2, @(usage)), &status);
        FILE *stream = status ? err : out;
        if (fprintf(stream, "%s\n", response) < 0 || fflush(stream) != 0) status = 1;
        asml_free(response);
        return status;
    }
}

static int embeddingCommand(int argc, char **argv, FILE *out, FILE *err) {
    if (argc < 4 || !ASMLEmbeddingID(@(argv[2]))) { fprintf(err, "Usage: coreml embed minilm-l6|qwen3-embedding-0.6b INPUT.json [--units all|cpu|cpu-gpu|cpu-ane] [--request UUID]\n"); return 2; }
    const char *units = "cpu", *request = NULL;
    BOOL hasUnits = NO;
    for (int i = 4; i < argc; i += 2) {
        if (i+1 >= argc) { fprintf(err, "Missing embedding option value\n"); return 2; }
        if (!strcmp(argv[i], "--units") && !hasUnits) { units = argv[i+1]; hasUnits = YES; }
        else if (!strcmp(argv[i], "--request") && !request) request = argv[i+1];
        else { fprintf(err, "Unknown or duplicate embedding option\n"); return 2; }
    }
    NSString *path = @(argv[3]); struct stat info;
    if (stat(path.fileSystemRepresentation, &info) || !S_ISREG(info.st_mode) || info.st_size < 1 || info.st_size > 1048576) { fprintf(err, "Embedding input must be a regular JSON file of 1..1048576 bytes\n"); return 2; }
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSDictionary *input = data && data.length <= 1048576 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if (![input isKindOfClass:NSDictionary.class]) { fprintf(err, "Invalid embedding JSON object\n"); return 2; }
    int status; char *begun = asml_begin_request(argv[2], units, request, &status);
    if (status) { fprintf(err, "%s\n", begun); asml_free(begun); return status; }
    NSDictionary *context = [NSJSONSerialization JSONObjectWithData:[@(begun) dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil]; asml_free(begun);
    NSString *token = context[@"token"]; __block NSDictionary *result; __block NSError *error;
    double started = NSProcessInfo.processInfo.systemUptime;
    dispatch_sync(worker, ^{ @autoreleasepool {
        if (!validToken(token.UTF8String, &error)) return;
        if (!warmGraphs) { error = failure(2, @"Embedding model is not loaded"); return; }
        result = ASMLEmbeddingPredict(warmGraphs, input, ^NSError *{ return stopped(token); }, ^(NSUInteger count) {
            [admission lock]; requests[token][@"completed_chunks"] = @(count); [admission unlock];
        }, &error);
        if (result) {
            NSMutableDictionary *receipt = [result mutableCopy];
            receipt[@"model_id"] = modelReceipt[@"model_id"]; receipt[@"model_sha256"] = modelReceipt[@"source_sha256"]; receipt[@"manifest_sha256"] = modelReceipt[@"manifest_sha256"];
            receipt[@"units"] = @(units); receipt[@"cache_hit"] = @(cacheHit); receipt[@"cache_id"] = cacheID; receipt[@"request"] = token;
            receipt[@"load_ms"] = @(loadMS); receipt[@"verification_ms"] = @(verificationMS); receipt[@"model_load_ms"] = @(modelLoadMS); receipt[@"verification_cached"] = @(verificationCached);
            receipt[@"processing_ms"] = @((NSProcessInfo.processInfo.systemUptime - started)*1000); receipt[@"memory"] = memory(); result = receipt;
        }
    } });
    int closeStatus; asml_free(asml_end(token.UTF8String, &closeStatus));
    if (!result) { status = [error.domain isEqual:@"AShellML"] ? (int)error.code : 1; fprintf(err, "%s\n", (error.localizedDescription ?: @"Embedding failed").UTF8String); return status; }
    char *json = encode(result); BOOL written = fprintf(out, "%s\n", json) >= 0 && fflush(out) == 0; asml_free(json); return written ? 0 : 1;
}
