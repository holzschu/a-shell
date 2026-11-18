#import "AShellMLInstall.h"
#import "AShellML.h"
#import "AShellEmbedding.h"
#import <CommonCrypto/CommonDigest.h>
#import <CoreML/CoreML.h>
#import <CoreVideo/CoreVideo.h>
#import <TargetConditionals.h>
#import <sys/file.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <errno.h>
#import <unistd.h>
#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

static NSError *problem(int code, NSString *text) {
    return [NSError errorWithDomain:@"AShellML" code:code userInfo:@{NSLocalizedDescriptionKey:text}];
}
static NSError *operationError(void) {
    NSError *(^check)(void) = NSThread.currentThread.threadDictionary[@"ASMLInstallCheck"];
    return check ? check() : asml_command_interrupted() ? problem(130, @"Core ML operation cancelled") : nil;
}
static BOOL reject(NSError **error, int code, NSString *text) { if (error) *error = operationError() ?: problem(code, text); return NO; }
static BOOL operationAllowed(NSError **error) {
    NSError *stop = operationError(); if (stop && error) *error = stop; return stop == nil;
}
static BOOL digestOK(id value) {
    return [value isKindOfClass:NSString.class] && [value length] == 64 && [value rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet]].location == NSNotFound;
}
static NSString *hashData(NSData *data) {
    CC_SHA256_CTX context; CC_SHA256_Init(&context);
    const uint8_t *bytes = data.bytes;
    for (NSUInteger offset = 0; offset < data.length;) {
        CC_LONG count = (CC_LONG)MIN(data.length - offset, 1024 * 1024);
        CC_SHA256_Update(&context, bytes + offset, count); offset += count;
    }
    unsigned char result[CC_SHA256_DIGEST_LENGTH]; CC_SHA256_Final(result, &context);
    NSMutableString *hex = [NSMutableString string];
    for (NSUInteger i = 0; i < sizeof(result); i++) [hex appendFormat:@"%02x", result[i]];
    return hex;
}
static NSString *hashFile(NSURL *file, NSError **error) {
    NSInputStream *stream = [NSInputStream inputStreamWithURL:file]; [stream open];
    CC_SHA256_CTX context; CC_SHA256_Init(&context); uint8_t buffer[65536]; NSInteger count;
    // Hashing large archives must not delay terminal/request cancellation until EOF.
    while ((count = [stream read:buffer maxLength:sizeof(buffer)]) > 0) {
        if (!operationAllowed(error)) { [stream close]; return nil; }
        CC_SHA256_Update(&context, buffer, (CC_LONG)count);
    }
    [stream close];
    if (count < 0) { if (error) *error = stream.streamError; return nil; }
    unsigned char result[CC_SHA256_DIGEST_LENGTH]; CC_SHA256_Final(result, &context);
    NSMutableString *hex = [NSMutableString string];
    for (NSUInteger i = 0; i < sizeof(result); i++) [hex appendFormat:@"%02x", result[i]];
    return hex;
}
static NSString *selectedModel(void) { return NSThread.currentThread.threadDictionary[@"ASMLInstallModel"] ?: @"mnist"; }
static NSURL *rootURL(void) {
    NSURL *support = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    // Foundation may shorten /private/var or /private/tmp back to their system
    // aliases. Resolve the existing support ancestor with realpath instead.
    NSMutableArray *tail = [NSMutableArray array];
    char resolved[PATH_MAX];
    while (!realpath(support.fileSystemRepresentation, resolved) && support.path.length > 1) {
        [tail addObject:support.lastPathComponent]; support = support.URLByDeletingLastPathComponent;
    }
    if (realpath(support.fileSystemRepresentation, resolved)) support = [NSURL fileURLWithPath:@(resolved) isDirectory:YES];
    for (NSString *part in tail.reverseObjectEnumerator) support = [support URLByAppendingPathComponent:part isDirectory:YES];
    return [[support URLByAppendingPathComponent:@"a-Shell/Models" isDirectory:YES] URLByAppendingPathComponent:selectedModel() isDirectory:YES];
}
static BOOL plainPath(NSURL *url, NSError **error) {
    // Reject symlinks at every existing ancestor, including user-controlled parents.
    NSURL *item = url;
    while (item.path.length > 1) {
        struct stat info;
        if (lstat(item.fileSystemRepresentation, &info) == 0 && S_ISLNK(info.st_mode)) return reject(error, 2, [@"Model storage must not contain symlinks: " stringByAppendingString:item.path]);
        item = item.URLByDeletingLastPathComponent;
    }
    return YES;
}
static BOOL exclude(NSURL *url, NSError **error) {
    if (![url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:error]) return NO;
    [url removeCachedResourceValueForKey:NSURLIsExcludedFromBackupKey];
    NSNumber *flag;
    if (![url getResourceValue:&flag forKey:NSURLIsExcludedFromBackupKey error:error]) return NO;
#if TARGET_OS_IPHONE
    return flag.boolValue || reject(error, 1, @"Backup exclusion was not retained");
#else
    // Time Machine's macOS getter can remain false even with the exclusion xattr.
    // Report that observed flag; only device acceptance qualifies iCloud exclusion.
    return YES;
#endif
}
static BOOL directory(NSURL *url, NSError **error) {
    return plainPath(url, error) && [[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:error] && exclude(url, error);
}
static BOOL atomicData(NSData *data, NSURL *url, NSError **error) {
    if (!plainPath(url, error)) return NO;
    NSURL *temp = [url.URLByDeletingLastPathComponent URLByAppendingPathComponent:[@".record-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    int fd = open(temp.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
    if (fd < 0) return reject(error, 1, @"Cannot create transaction record");
    const uint8_t *bytes = data.bytes; NSUInteger remaining = data.length;
    BOOL ok = YES;
    while (remaining) { ssize_t n = write(fd, bytes, remaining); if (n <= 0) { ok = NO; break; } bytes += n; remaining -= n; }
    if (ok) ok = fsync(fd) == 0;
    close(fd);
    if (ok) ok = exclude(temp, error);
    if (ok) ok = rename(temp.fileSystemRepresentation, url.fileSystemRepresentation) == 0;
    if (!ok) { unlink(temp.fileSystemRepresentation); if (!error || !*error) reject(error, 1, @"Cannot publish transaction record"); return NO; }
    int parent = open(url.URLByDeletingLastPathComponent.fileSystemRepresentation, O_RDONLY);
    if (parent >= 0) { fsync(parent); close(parent); }
    return YES;
}
static BOOL writeJSON(id object, NSURL *url, NSError **error) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingSortedKeys error:error];
    return data && atomicData(data, url, error);
}
static NSDictionary *readJSON(NSURL *url) {
    if (!plainPath(url, nil)) return nil;
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data || data.length > 16 * 1024 * 1024) return nil;
    id result = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [result isKindOfClass:NSDictionary.class] ? result : nil;
}
static int lockFile(NSString *name, int operation, BOOL wait, NSError **error) {
    if (!directory(rootURL(), error)) return -1;
    NSURL *url = [rootURL() URLByAppendingPathComponent:name];
    int fd = open(url.fileSystemRepresentation, O_RDWR | O_CREAT | O_NOFOLLOW, 0600);
    if (fd < 0) { reject(error, 75, @"Cannot open model store lock"); return -1; }
    double deadline = NSProcessInfo.processInfo.systemUptime + 0.5;
    while (flock(fd, operation | LOCK_NB)) {
        if (errno != EWOULDBLOCK || !wait || ![name isEqual:@".install-lock"] || NSProcessInfo.processInfo.systemUptime >= deadline) {
            close(fd); reject(error, 75, @"Model store is busy; retry after the active operation completes"); return -1;
        }
        if (asml_command_interrupted()) { close(fd); reject(error, 130, @"Installation cancelled while waiting for the model store"); return -1; }
        usleep(10000);
    }
    return fd;
}
static BOOL supported(NSString *model, NSError **error) { return [model isEqual:@"mnist"] || ASMLEmbeddingID(model) || reject(error, 2, @"Unsupported model id"); }
static NSURL *version(NSString *digest) { return [rootURL() URLByAppendingPathComponent:digest isDirectory:YES]; }
static BOOL verifiedFile(NSURL *file, NSNumber *bytes, NSString *digest) {
    struct stat info;
    return plainPath(file, nil) && lstat(file.fileSystemRepresentation, &info) == 0 && S_ISREG(info.st_mode) && (unsigned long long)info.st_size == bytes.unsignedLongLongValue && [hashFile(file, nil) isEqual:digest];
}
static NSDictionary *treeReceipt(NSURL *url, BOOL sync, NSError **error) {
    NSMutableDictionary *files = [NSMutableDictionary dictionary];
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm fileExistsAtPath:url.path] || !plainPath(url, error)) return nil;
    for (NSURL *child in [fm enumeratorAtURL:url includingPropertiesForKeys:nil options:0 errorHandler:nil]) {
        if (!operationAllowed(error)) return nil;
        struct stat info;
        if (lstat(child.fileSystemRepresentation, &info) || (!S_ISDIR(info.st_mode) && !S_ISREG(info.st_mode))) { reject(error, 2, @"Compiled model contains an unsafe entry"); return nil; }
        if (sync && !exclude(child, error)) return nil;
        if (S_ISREG(info.st_mode)) {
            NSString *digest = hashFile(child, error); if (!digest) return nil;
            NSString *path = [child.path substringFromIndex:url.path.length + 1];
            files[path] = @{@"bytes":@((unsigned long long)info.st_size), @"sha256":digest};
        }
        if (sync) { int fd = open(child.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW); if (fd < 0 || fsync(fd)) { if (fd >= 0) close(fd); reject(error, 1, @"Cannot make model durable"); return nil; } close(fd); }
    }
    if (!files.count) { reject(error, 2, @"Compiled model is empty"); return nil; }
    return files;
}
static BOOL planOK(NSDictionary *plan, NSError **error);
static BOOL packageFiles(NSURL *directory, NSDictionary *plan, NSError **error);
static NSDictionary *checkedReceipt(NSString *digest, NSError **error) {
    if (!digestOK(digest)) { reject(error, 2, @"Invalid installed manifest digest"); return nil; }
    NSURL *dir = version(digest);
    NSDictionary *receipt = readJSON([dir URLByAppendingPathComponent:@"receipt.json"]);
    NSData *manifest = [NSData dataWithContentsOfURL:[dir URLByAppendingPathComponent:@"manifest.json"]];
    id plan = manifest ? [NSJSONSerialization JSONObjectWithData:manifest options:0 error:nil] : nil;
    if (![plan isKindOfClass:NSDictionary.class] || !planOK(plan, nil)) { reject(error, 2, @"Installed manifest is invalid; download again with coreml install"); return nil; }
    for (NSString *key in plan) {
        if (![receipt[key] isEqual:plan[key]]) { reject(error, 2, @"Installed receipt differs from its pinned manifest; download again with coreml install"); return nil; }
    }
    if (![receipt[@"manifest_sha256"] isEqual:digest] || ![hashData(manifest ?: NSData.data) isEqual:digest] ||
        !packageFiles([dir URLByAppendingPathComponent:@"package" isDirectory:YES], plan, nil) ||
        ![treeReceipt([dir URLByAppendingPathComponent:@"model.mlmodelc"], NO, nil) isEqual:receipt[@"compiled_files"]]) {
        reject(error, 2, @"Installed model files are missing or changed; download again with coreml install"); return nil;
    }
    NSMutableDictionary *result = [receipt mutableCopy]; result[@"path"] = dir.path;
    NSNumber *flag; [dir getResourceValue:&flag forKey:NSURLIsExcludedFromBackupKey error:error];
    result[@"excluded_from_backup"] = flag ?: @NO;
    return result;
}
static NSDictionary *scopedASMLInstalledVersion(NSString *modelID, NSError **error) {
    if (!supported(modelID, error)) return nil;
    NSDictionary *active = readJSON([rootURL() URLByAppendingPathComponent:@"active.json"]);
    if (!active) { reject(error, 2, @"Model is not installed; reinstall with coreml install"); return nil; }
    NSString *digest = active[@"active"];
    return checkedReceipt(digest, error);
}
static void collect(NSDictionary *record);
static NSMutableDictionary *leases(void) {
    static NSMutableDictionary *value; static dispatch_once_t once;
    dispatch_once(&once, ^{ value = [NSMutableDictionary dictionary]; }); return value;
}
static NSDictionary *versionIdentity(NSURL *directory) {
    if (!plainPath(directory, nil)) return nil;
    NSMutableDictionary *identity = [NSMutableDictionary dictionary];
    __block BOOL failed = NO;
    NSDirectoryEnumerator *entries = [NSFileManager.defaultManager enumeratorAtURL:directory includingPropertiesForKeys:nil options:0 errorHandler:^BOOL(NSURL *url, NSError *error) {
        (void)url; (void)error; failed = YES; return NO;
    }];
    if (!entries) return nil;
    // Root-only mtimes miss in-place leaf edits. ctime also detects restored mtimes.
    NSURL *entry = directory;
    do {
        if (operationError()) return nil;
        struct stat info;
        if (lstat(entry.fileSystemRepresentation, &info) || (!S_ISDIR(info.st_mode) && !S_ISREG(info.st_mode))) return nil;
        identity[entry.path] = @[@(info.st_dev), @(info.st_ino), @(info.st_mode), @(info.st_size), @(info.st_uid), @(info.st_gid), @(info.st_nlink),
            @(info.st_mtimespec.tv_sec), @(info.st_mtimespec.tv_nsec), @(info.st_ctimespec.tv_sec), @(info.st_ctimespec.tv_nsec)];
    } while ((entry = entries.nextObject));
    return failed ? nil : identity;
}
static NSDictionary *scopedASMLAcquireVersion(NSString *modelID, NSError **error) {
    if (!supported(modelID, error)) return nil;
    // Serialize pointer resolution with activation, then pin only the chosen immutable version.
    int guard = lockFile(@".install-lock", LOCK_EX, YES, error); if (guard < 0) return nil;
    NSDictionary *active = readJSON([rootURL() URLByAppendingPathComponent:@"active.json"]);
    NSString *digest = active[@"active"] ?: active[@"manifest_sha256"];
    NSDictionary *identity = digestOK(digest) ? versionIdentity(version(digest)) : nil;
    NSDictionary *receipt; BOOL reused = NO;
    @synchronized (leases()) {
        for (NSDictionary *lease in leases().allValues) {
            if (identity && [lease[@"model_id"] isEqual:selectedModel()] && [lease[@"receipt"][@"manifest_sha256"] isEqual:digest] && [lease[@"identity"] isEqual:identity]) {
                receipt = lease[@"receipt"]; reused = YES; break;
            }
        }
    }
    if (!receipt) {
        receipt = ASMLInstalledVersion(modelID, error);
        if (receipt && (!identity || ![identity isEqual:versionIdentity(version(digest))])) {
            reject(error, 2, @"Installed model changed during verification"); receipt = nil;
        }
    }
    int fd = receipt ? lockFile([@".lease-" stringByAppendingString:receipt[@"manifest_sha256"]], LOCK_SH, YES, error) : -1;
    close(guard);
    if (fd < 0) return nil;
    NSString *token = NSUUID.UUID.UUIDString;
    @synchronized (leases()) { leases()[token] = @{@"fd":@(fd), @"model_id":selectedModel(), @"receipt":receipt, @"identity":identity}; }
    NSMutableDictionary *result = [receipt mutableCopy]; result[@"lease_id"] = token; result[@"verification_cached"] = @(reused); return result;
}
void ASMLReleaseVersion(NSString *leaseID) {
    if (![leaseID isKindOfClass:NSString.class]) return;
    NSDictionary *lease;
    @synchronized (leases()) { lease = leases()[leaseID]; if (lease) { close([lease[@"fd"] intValue]); [leases() removeObjectForKey:leaseID]; } }
    if (!lease) return;
    NSMutableDictionary *context = NSThread.currentThread.threadDictionary; id previous = context[@"ASMLInstallModel"]; context[@"ASMLInstallModel"] = lease[@"model_id"];
    @try {
        int guard = lockFile(@".install-lock", LOCK_EX, NO, nil);
        if (guard >= 0) {
            NSDictionary *record = readJSON([rootURL() URLByAppendingPathComponent:@"active.json"]);
            if (!record[@"active"] && digestOK(record[@"manifest_sha256"])) record = @{@"active":record[@"manifest_sha256"]};
            if (record) collect(record);
            close(guard);
        }
    } @finally { if (previous) context[@"ASMLInstallModel"] = previous; else [context removeObjectForKey:@"ASMLInstallModel"]; }
}

static BOOL webURL(NSURL *url) {
    return [url.scheme isEqual:@"https"] || ([url.scheme isEqual:@"http"] && ([url.host isEqual:@"127.0.0.1"] || [url.host isEqual:@"::1"]));
}
static BOOL compilationAllowed(NSError **error) {
#if TARGET_OS_IPHONE
    if ([NSThread isMainThread] || [NSBundle.mainBundle.bundlePath containsString:@".appex"]) return reject(error, 75, @"Installation requires an off-main caller in the main application");
    __block BOOL active;
    dispatch_sync(dispatch_get_main_queue(), ^{ active = UIApplication.sharedApplication.applicationState == UIApplicationStateActive; });
    if (!active) return reject(error, 75, @"Download staged; reopen the application and rerun install to compile and activate");
#else
    (void)error;
#endif
    return YES;
}
static BOOL cancelled(NSURL *stage, NSString *generation) {
    return asml_command_interrupted() || [[NSFileManager defaultManager] fileExistsAtPath:[[stage URLByAppendingPathComponent:[@"cancel-" stringByAppendingString:generation]] path]];
}

// Each transfer owns one generation and one destination. Callbacks only publish
// downloaded bytes into staging; only ASMLInstall may compile and activate them.
@interface ASMLTransfer : NSObject <NSURLSessionDownloadDelegate>
@property NSURL *destination;
@property NSURL *stage;
@property NSString *generation;
@property unsigned long long limit;
@property NSError *error;
@property dispatch_semaphore_t finished;
@end
@implementation ASMLTransfer
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completion {
    (void)session; (void)task; (void)response;
    if (!webURL(request.URL)) { self.error = problem(2, @"Download redirect must use HTTPS or literal loopback HTTP"); completion(nil); } else completion(request);
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task didWriteData:(int64_t)bytes totalBytesWritten:(int64_t)total totalBytesExpectedToWrite:(int64_t)expected {
    (void)session; (void)bytes;
    if (cancelled(self.stage, self.generation)) { self.error = problem(130, @"Installation cancelled"); [task cancel]; }
    else if ((unsigned long long)total > self.limit || (expected > 0 && (unsigned long long)expected > self.limit)) { self.error = problem(2, @"Download exceeds declared size"); [task cancel]; }
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task didFinishDownloadingToURL:(NSURL *)location {
    (void)session;
    if (self.error) return;
    if (cancelled(self.stage, self.generation)) { self.error = problem(130, @"Installation cancelled"); return; }
    if ([(NSHTTPURLResponse *)task.response statusCode] != 200) { self.error = problem(1, @"Download returned an HTTP error"); return; }
    struct stat info;
    if (stat(location.fileSystemRepresentation, &info) || (unsigned long long)info.st_size > self.limit) { self.error = problem(2, @"Download exceeds declared size"); return; }
    NSFileManager *fm = NSFileManager.defaultManager;
    NSError *error = nil;
    if (!plainPath(self.destination, &error) || !exclude(location, &error)) { self.error = error; return; }
    // A destination is generation-specific and never an installed file.
    if (![fm moveItemAtURL:location toURL:self.destination error:&error]) { self.error = error; return; }
    exclude(self.destination, &error); self.error = error;
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    (void)session; (void)task;
    if (!self.error) self.error = error;
    dispatch_semaphore_signal(self.finished);
}
@end

#if TARGET_OS_IPHONE
@interface ASMLBackground : NSObject <NSURLSessionDownloadDelegate>
@property NSURLSession *session;
@property NSMutableDictionary<NSNumber *, ASMLTransfer *> *owners;
@property (copy) void (^completion)(void);
@end
static NSString *sessionID(void) { return [NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".models.v1"]; }
static ASMLBackground *background(void);
@implementation ASMLBackground
- (ASMLTransfer *)owner:(NSURLSessionTask *)task {
    @synchronized (self) {
        ASMLTransfer *owner = self.owners[@(task.taskIdentifier)];
        if (owner) return owner;
        NSData *data = [task.taskDescription dataUsingEncoding:NSUTF8StringEncoding];
        id meta = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (![meta isKindOfClass:NSDictionary.class] || !digestOK(meta[@"manifest_sha256"]) || ![meta[@"generation"] isKindOfClass:NSString.class] || ![meta[@"name"] isKindOfClass:NSString.class] || [meta[@"name"] containsString:@"/"] || [meta[@"name"] containsString:@".."] || ![meta[@"limit"] isKindOfClass:NSNumber.class]) { [task cancel]; return nil; }
        NSString *modelID = meta[@"model_id"] ?: @"mnist";
        if (!supported(modelID, nil)) { [task cancel]; return nil; }
        NSDictionary *state = ASMLInstallStatus(modelID, nil);
        if (![state[@"generation"] isEqual:meta[@"generation"]] || ![state[@"manifest_sha256"] isEqual:meta[@"manifest_sha256"]]) { [task cancel]; return nil; }
        NSURL *modelRoot = [[rootURL() URLByDeletingLastPathComponent] URLByAppendingPathComponent:modelID isDirectory:YES];
        NSURL *stage = [modelRoot URLByAppendingPathComponent:[@".staging-" stringByAppendingString:meta[@"manifest_sha256"]]];
        if (!plainPath(stage, nil) || ![NSFileManager.defaultManager fileExistsAtPath:stage.path]) { [task cancel]; return nil; }
        owner = [ASMLTransfer new]; owner.stage = stage; owner.destination = [stage URLByAppendingPathComponent:meta[@"name"]]; owner.generation = meta[@"generation"]; owner.limit = [meta[@"limit"] unsignedLongLongValue]; owner.finished = dispatch_semaphore_create(0);
        self.owners[@(task.taskIdentifier)] = owner; return owner;
    }
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completion {
    ASMLTransfer *owner = [self owner:task];
    if (owner) [owner URLSession:session task:task willPerformHTTPRedirection:response newRequest:request completionHandler:completion]; else completion(nil);
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task didWriteData:(int64_t)bytes totalBytesWritten:(int64_t)total totalBytesExpectedToWrite:(int64_t)expected {
    [[self owner:task] URLSession:session downloadTask:task didWriteData:bytes totalBytesWritten:total totalBytesExpectedToWrite:expected];
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task didFinishDownloadingToURL:(NSURL *)location {
    ASMLTransfer *owner = [self owner:task];
    // Recheck generation even for an in-process owner: a restarted install must
    // never receive a prior task's completion in its new staging generation.
    // Preserve the selected model when a background download completes.
    NSDictionary *state = owner ? ASMLInstallStatus(owner.stage.URLByDeletingLastPathComponent.lastPathComponent, nil) : nil;
    if (![state[@"generation"] isEqual:owner.generation]) { owner.error = problem(130, @"Download belongs to a superseded installation"); return; }
    [owner URLSession:session downloadTask:task didFinishDownloadingToURL:location];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    ASMLTransfer *owner = [self owner:task];
    [owner URLSession:session task:task didCompleteWithError:error];
    @synchronized (self) { [self.owners removeObjectForKey:@(task.taskIdentifier)]; }
}
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    (void)session;
    dispatch_async(dispatch_get_main_queue(), ^{
        void (^completion)(void) = self.completion; self.completion = nil;
        if (completion) completion();
    });
}
@end
static ASMLBackground *background(void) {
    static ASMLBackground *value; static dispatch_once_t once;
    dispatch_once(&once, ^{
        value = [ASMLBackground new]; value.owners = [NSMutableDictionary dictionary];
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:sessionID()];
        config.sessionSendsLaunchEvents = YES; config.discretionary = NO;
        config.timeoutIntervalForResource = 24 * 60 * 60;
        value.session = [NSURLSession sessionWithConfiguration:config delegate:value delegateQueue:nil];
    });
    return value;
}
#endif

int asml_background_events(const char *identifier, void (^completion)(void)) {
#if TARGET_OS_IPHONE
    if (identifier && [[NSString stringWithUTF8String:identifier] isEqual:sessionID()]) { background().completion = completion; return 1; }
#else
    (void)identifier; (void)completion;
#endif
    return 0;
}

static BOOL fetchFile(NSString *location, NSURL *target, unsigned long long limit, NSURL *stage, NSString *generation, NSError **error) {
    if (![location isKindOfClass:NSString.class]) return reject(error, 2, @"Download URL must be a string");
    NSURL *url = [NSURL URLWithString:location];
    if (!webURL(url)) return reject(error, 2, @"Downloads require HTTPS (literal loopback HTTP is allowed for local catalogs)");
    ASMLTransfer *delegate = [ASMLTransfer new];
    delegate.destination = target; delegate.stage = stage; delegate.generation = generation; delegate.limit = limit;
    delegate.finished = dispatch_semaphore_create(0);
    NSURLSession *session;
    NSURLSessionDownloadTask *task;
#if TARGET_OS_IPHONE
    ASMLBackground *manager = background(); session = manager.session;
    task = [session downloadTaskWithURL:url];
    NSString *digest = [stage.lastPathComponent substringFromIndex:@".staging-".length];
    NSDictionary *meta = @{@"model_id":selectedModel(), @"manifest_sha256":digest, @"generation":generation, @"name":target.lastPathComponent, @"limit":@(limit)};
    task.taskDescription = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:meta options:0 error:nil] encoding:NSUTF8StringEncoding];
    @synchronized (manager) { manager.owners[@(task.taskIdentifier)] = delegate; }
#else
    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    configuration.timeoutIntervalForResource = 120;
    configuration.timeoutIntervalForRequest = 30;
    session = [NSURLSession sessionWithConfiguration:configuration delegate:delegate delegateQueue:nil];
    task = [session downloadTaskWithURL:url];
    task.taskDescription = generation;
#endif
    [task resume];
    while (dispatch_semaphore_wait(delegate.finished, dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC))) {
        if (cancelled(stage, generation)) [task cancel];
    }
#if !TARGET_OS_IPHONE
    [session finishTasksAndInvalidate];
#endif
    if (cancelled(stage, generation)) return reject(error, 130, @"Installation cancelled");
    if (delegate.error) { if (error) *error = delegate.error; return NO; }
    return YES;
}
static const unsigned long long packageCeiling = 2ULL * 1024 * 1024 * 1024;
static BOOL boundedNumber(id value, unsigned long long ceiling) {
    return [value isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID() && [value doubleValue] >= 1 && [value doubleValue] <= ceiling && [value doubleValue] == [value unsignedLongLongValue];
}
static BOOL memberPath(id value) {
    if (![value isKindOfClass:NSString.class] || ![value length] || [value hasPrefix:@"/"] || [value containsString:@"\\"]) return NO;
    for (NSUInteger i = 0; i < [value length]; i++) if ([value characterAtIndex:i] < 32 || [value characterAtIndex:i] > 126) return NO;
    for (NSString *part in [value componentsSeparatedByString:@"/"]) if (!part.length || [part isEqual:@"."] || [part isEqual:@".."]) return NO;
    return YES;
}
static BOOL packagePlan(NSDictionary *plan, NSError **error) {
    NSDictionary *members = plan[@"members"], *limits = plan[@"limits"];
    if (![plan[@"package_format"] isEqual:@"ashell-model-ustar-v1"] || ![members isKindOfClass:NSDictionary.class] || !members.count || members.count > 100000 || ![limits isKindOfClass:NSDictionary.class] ||
        !boundedNumber(limits[@"archive_bytes"], packageCeiling) || !boundedNumber(limits[@"member_bytes"], packageCeiling)) return reject(error, 2, @"Invalid package format, member map or byte limits");
    NSString *model = plan[@"model"], *license = plan[@"license_file"], *recipe = plan[@"recipe"], *input = plan[@"validation"][@"input"];
    if (!memberPath(model) || !memberPath(license) || !memberPath(recipe) || !memberPath(input) || members[@"manifest.json"]) return reject(error, 2, @"Invalid package member paths");
    if (![members[model] isKindOfClass:NSDictionary.class]) return reject(error, 2, @"Package model is undeclared");
    BOOL tree = [model.pathExtension isEqual:@"mlpackage"] && [members[model][@"type"] isEqual:@"directory"];
    if (!tree && (![model.pathExtension isEqual:@"mlmodel"] || ![members[model][@"type"] isEqual:@"file"])) return reject(error, 2, @"Package model must be a portable mlmodel or mlpackage");
    unsigned long long total = 0, sourceBytes = 0;
    NSMutableString *identity = [NSMutableString string];
    for (NSString *name in [members.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSDictionary *entry = members[name];
        if (!memberPath(name) || ![entry isKindOfClass:NSDictionary.class] || !digestOK(entry[@"sha256"])) return reject(error, 2, @"Invalid package member declaration");
        BOOL directoryEntry = [entry[@"type"] isEqual:@"directory"];
        BOOL belowModel = [name hasPrefix:[model stringByAppendingString:@"/"]];
        if (directoryEntry) {
            if (!tree || (![name isEqual:model] && !belowModel) || ![entry[@"bytes"] isEqual:@0] || ![entry[@"sha256"] isEqual:hashData(NSData.data)]) return reject(error, 2, @"Package directories are restricted to the model tree");
        } else {
            if (![entry[@"type"] isEqual:@"file"] || !boundedNumber(entry[@"bytes"], [limits[@"member_bytes"] unsignedLongLongValue])) return reject(error, 2, @"Package member exceeds its declared bound");
            unsigned long long bytes = [entry[@"bytes"] unsignedLongLongValue];
            if (bytes > packageCeiling - total) return reject(error, 2, @"Package content exceeds archive ceiling");
            total += bytes;
            if (tree && belowModel) {
                sourceBytes += bytes;
                [identity appendFormat:@"%@  %@\n", entry[@"sha256"], [name substringFromIndex:model.length + 1]];
            }
        }
        NSString *parent = name.stringByDeletingLastPathComponent;
        if (parent.length && ![members[parent][@"type"] isEqual:@"directory"]) return reject(error, 2, @"Package parent directory is undeclared");
    }
    for (NSString *name in @[license, recipe, input]) if (![members[name][@"type"] isEqual:@"file"]) return reject(error, 2, @"Package license, recipe and fixture must be regular members");
    if (total > [limits[@"archive_bytes"] unsignedLongLongValue] || [members[license][@"bytes"] unsignedLongLongValue] > 1024 * 1024 || [members[recipe][@"bytes"] unsignedLongLongValue] > 16 * 1024 * 1024 ||
        ![members[license][@"bytes"] isEqual:plan[@"license_bytes"]] || ![members[license][@"sha256"] isEqual:plan[@"license_sha256"]] ||
        ([plan[@"model_id"] isEqual:@"mnist"] && (![members[input][@"bytes"] isEqual:@784] || ![members[input][@"sha256"] isEqual:@"8f6a418c9a639f9e14e96feca47a97df2a35a0a68ae2875431c5c80e05536941"]))) return reject(error, 2, @"Invalid package license, recipe or known-answer fixture receipt");
    NSString *sourceSHA = tree ? hashData([identity dataUsingEncoding:NSUTF8StringEncoding]) : members[model][@"sha256"];
    NSNumber *sourceSize = tree ? @(sourceBytes) : members[model][@"bytes"];
    return ([sourceSHA isEqual:plan[@"source_sha256"]] && [sourceSize isEqual:plan[@"source_bytes"]]) || reject(error, 2, @"Package model identity differs from member receipts");
}
static BOOL packageFiles(NSURL *directoryURL, NSDictionary *plan, NSError **error) {
    NSDictionary *members = plan[@"members"];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSURL *file in [NSFileManager.defaultManager enumeratorAtURL:directoryURL includingPropertiesForKeys:nil options:0 errorHandler:nil]) {
        if (!operationAllowed(error)) return NO;
        NSString *name = [file.path substringFromIndex:directoryURL.path.length + 1];
        NSDictionary *entry = members[name]; struct stat info;
        if (!entry || !plainPath(file, error) || lstat(file.fileSystemRepresentation, &info)) return reject(error, 2, @"Package contains an unknown or missing entry");
        BOOL valid = [entry[@"type"] isEqual:@"directory"] ? S_ISDIR(info.st_mode) : verifiedFile(file, entry[@"bytes"], entry[@"sha256"]);
        if (!valid) return reject(error, 2, @"Package member size, type or SHA256 mismatch");
        [seen addObject:name];
    }
    return seen.count == members.count || reject(error, 2, @"Package members are missing");
}
static BOOL planOK(NSDictionary *plan, NSError **error) {
    if (![plan[@"package_format"] isEqual:@"ashell-model-ustar-v1"]) return reject(error, 2, @"Only portable model packages are supported; reinstall with coreml install");
    if (![plan[@"memory_profile"] isKindOfClass:NSDictionary.class] || ![plan[@"validation"] isKindOfClass:NSDictionary.class]) return reject(error, 2, @"Manifest memory profile and validation must be objects");
    if (![plan[@"source_url"] isKindOfClass:NSString.class] || ![plan[@"license_url"] isKindOfClass:NSString.class]) return reject(error, 2, @"Manifest URLs must be strings");
    if (ASMLEmbeddingID(selectedModel())) {
        if (![plan[@"schema"] isEqual:@1] || ![plan[@"model_id"] isEqual:selectedModel()] || ![plan[@"runtime"] isEqual:@"CoreML"] || ![plan[@"runtime_abi"] isEqual:@1] ||
            !digestOK(plan[@"source_sha256"]) || !boundedNumber(plan[@"source_bytes"], packageCeiling) || !digestOK(plan[@"license_sha256"]) || !boundedNumber(plan[@"license_bytes"], 1024*1024) ||
            ![plan[@"version"] isKindOfClass:NSString.class] || ![plan[@"version"] length] || ![plan[@"license"] isEqual:@"Apache-2.0"] || ![plan[@"disk_estimate_bytes"] isKindOfClass:NSNumber.class] || [plan[@"disk_estimate_bytes"] unsignedLongLongValue] < 2ULL*1024*1024*1024 || !ASMLEmbeddingPlan(plan, error) || !packagePlan(plan, error)) return reject(error, 2, @"Invalid embedding package contract");
#if TARGET_OS_IPHONE
        if (![NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){18,0,0}]) return reject(error, 75, @"Embedding packages require iOS 18 or newer");
#endif
        return YES;
    }
    if (![plan[@"schema"] isEqual:@1] || ![plan[@"model_id"] isEqual:@"mnist"] || ![plan[@"runtime"] isEqual:@"CoreML"] || ![plan[@"runtime_abi"] isEqual:@1] ||
        !digestOK(plan[@"source_sha256"]) || !boundedNumber(plan[@"source_bytes"], packageCeiling) ||
        !digestOK(plan[@"license_sha256"]) || !boundedNumber(plan[@"license_bytes"], 1024 * 1024) ||
        ![plan[@"adapter_version"] isEqual:@1] || ![plan[@"version"] isKindOfClass:NSString.class] || ![plan[@"version"] length] ||
        ![plan[@"source_revision"] isKindOfClass:NSString.class] || ![plan[@"license"] isKindOfClass:NSString.class] || ![plan[@"license"] length] ||
        ![plan[@"features"] isEqual:@{@"image":@{@"type":@"image", @"dtype":@"uint8", @"shape":@[@28,@28]}}] ||
        ![plan[@"memory_profile"][@"kind"] isEqual:@"bounded-skeleton-estimate"] ||
        ![plan[@"disk_estimate_bytes"] isKindOfClass:NSNumber.class] || [plan[@"disk_estimate_bytes"] longLongValue] < 8 * 1024 * 1024 ||
        ![plan[@"minimum_ios"] isKindOfClass:NSString.class] || ![plan[@"preprocessing"] isKindOfClass:NSString.class] || ![plan[@"decoder"] isKindOfClass:NSString.class] ||
        plan[@"archive"] || plan[@"files"] || plan[@"source_path"] || plan[@"archive_url"]) return reject(error, 2, @"Unsupported or unsafe manifest for the drawing-classification adapter");
    if (![plan[@"task"] isEqual:@"drawing-classification"] || ![plan[@"adapter_version"] isEqual:@1]) return reject(error, 2, @"Unsupported task/adapter; only drawing-classification/1 is registered");
    if (!packagePlan(plan, error) || ![plan[@"outputs"] isEqual:@{@"classLabel":@{@"type":@"int64"}, @"labelProbabilities":@{@"type":@"dictionary", @"key_type":@"int64", @"count":@10}}]) return reject(error, 2, @"Invalid package members or output feature declarations");
    NSString *minimum = plan[@"minimum_ios"];
    NSScanner *scanner = [NSScanner scannerWithString:minimum]; NSInteger major, minor = 0;
    if (![scanner scanInteger:&major] || major < 14 || major > 100 || (![scanner isAtEnd] && (![scanner scanString:@"." intoString:nil] || ![scanner scanInteger:&minor] || !scanner.isAtEnd))) return reject(error, 2, @"Invalid minimum OS version");
#if TARGET_OS_IPHONE
    if (![NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){major,minor,0}]) return reject(error, 75, @"Model requires a newer iOS version");
#endif
    NSString *hex = plan[@"validation"][@"input_hex"];
    if (![hex isKindOfClass:NSString.class] || hex.length != 1568 || ![plan[@"validation"][@"label"] isEqual:@"7"]) return reject(error, 2, @"Manifest must include the bounded known-answer digit 7 fixture");
    NSMutableData *pixels = [NSMutableData dataWithLength:784];
    for (NSUInteger i = 0; i < 784; i++) {
        NSString *pair = [hex substringWithRange:NSMakeRange(i * 2, 2)];
        if ([pair rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet]].location != NSNotFound) return reject(error, 2, @"Invalid validation fixture encoding");
        ((uint8_t *)pixels.mutableBytes)[i] = (uint8_t)strtoul(pair.UTF8String, NULL, 16);
    }
    return [hashData(pixels) isEqual:@"8f6a418c9a639f9e14e96feca47a97df2a35a0a68ae2875431c5c80e05536941"] || reject(error, 2, @"Known-answer fixture SHA256 mismatch");
}
static BOOL readBytes(int fd, void *buffer, size_t count) {
    uint8_t *bytes = buffer;
    while (count) { ssize_t n = read(fd, bytes, count); if (n < 0 && errno == EINTR) continue; if (n <= 0) return NO; bytes += n; count -= n; }
    return YES;
}
static BOOL zeros(const uint8_t *bytes, size_t count) {
    for (size_t i = 0; i < count; i++) if (bytes[i]) return NO;
    return YES;
}
static BOOL octal(const uint8_t *bytes, size_t count, unsigned long long *value) {
    *value = 0; BOOL digit = NO, end = NO;
    for (size_t i = 0; i < count; i++) {
        uint8_t c = bytes[i];
        if (c == 0 || c == ' ') { if (digit) end = YES; continue; }
        if (end || c < '0' || c > '7' || *value > (packageCeiling - (c - '0')) / 8) return NO;
        digit = YES; *value = *value * 8 + c - '0';
    }
    return digit;
}
static NSString *tarString(const uint8_t *bytes, size_t count) {
    size_t length = strnlen((const char *)bytes, count);
    if (length < count && !zeros(bytes + length, count - length)) return nil;
    return [[NSString alloc] initWithBytes:bytes length:length encoding:NSASCIIStringEncoding];
}
static BOOL spaceForPlan(NSDictionary *plan, NSError **error) {
    NSNumber *capacity;
    if (![rootURL() getResourceValue:&capacity forKey:NSURLVolumeAvailableCapacityKey error:error]) return NO;
    return capacity.unsignedLongLongValue >= [plan[@"disk_estimate_bytes"] unsignedLongLongValue] || reject(error, 75, @"Insufficient disk space for source, compile peak and retained version");
}
static NSDictionary *extractPackage(NSURL *archive, NSURL *stage, NSString *generation, NSData **manifest, NSError **error) {
    if (!plainPath(archive, error)) return nil;
    int fd = open(archive.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW | O_NONBLOCK); struct stat info;
    if (fd < 0 || fstat(fd, &info) || !S_ISREG(info.st_mode) || info.st_size < 1536 || (unsigned long long)info.st_size > packageCeiling || info.st_size % 512) {
        if (fd >= 0) close(fd); reject(error, 2, @"Invalid or oversized ustar package"); return nil;
    }
    @try {
        NSURL *contents = [stage URLByAppendingPathComponent:@"package" isDirectory:YES];
        NSFileManager *fm = NSFileManager.defaultManager;
        if ([fm fileExistsAtPath:contents.path] && (!plainPath(contents, error) || ![fm removeItemAtURL:contents error:error])) return nil;
        if (!directory(contents, error)) return nil;
        NSDictionary *plan = nil; NSMutableSet *seen = [NSMutableSet set];
        unsigned long long offset = 0;
        while (offset < (unsigned long long)info.st_size) {
            if (cancelled(stage, generation)) { reject(error, 130, @"Installation cancelled during package extraction"); return nil; }
            uint8_t header[512];
            if (!readBytes(fd, header, sizeof(header))) break;
            offset += sizeof(header);
            if (zeros(header, sizeof(header))) {
                if (!readBytes(fd, header, sizeof(header)) || !zeros(header, sizeof(header))) break;
                offset += sizeof(header);
                while (offset < (unsigned long long)info.st_size) {
                    if (!readBytes(fd, header, sizeof(header)) || !zeros(header, sizeof(header))) { reject(error, 2, @"Nonzero content after ustar terminator"); return nil; }
                    offset += sizeof(header);
                }
                if (plan && seen.count == [plan[@"members"] count] && packageFiles(contents, plan, error)) return plan;
                reject(error, 2, @"Package members are missing"); return nil;
            }
            unsigned long long checksum, size, actual = 0;
            for (size_t i = 0; i < 512; i++) actual += i >= 148 && i < 156 ? ' ' : header[i];
            if (memcmp(header + 257, "ustar\0", 6) || memcmp(header + 263, "00", 2) || !octal(header + 148, 8, &checksum) || actual != checksum || !octal(header + 124, 12, &size) || !zeros(header + 157, 100)) break;
            NSString *name = tarString(header, 100), *prefix = tarString(header + 345, 155);
            if (!name || !prefix) break;
            if (prefix.length) name = [NSString stringWithFormat:@"%@/%@", prefix, name];
            BOOL isDirectory = header[156] == '5';
            if (isDirectory && [name hasSuffix:@"/"]) name = [name substringToIndex:name.length - 1];
            if (!memberPath(name) || (!isDirectory && header[156] != '0' && header[156] != 0) || (isDirectory && size) || size > (unsigned long long)info.st_size - offset) break;
            if (!plan) {
                if (isDirectory || ![name isEqual:@"manifest.json"] || !size || size > 1024 * 1024) break;
                NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)size];
                if (!readBytes(fd, data.mutableBytes, data.length)) break;
                id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if (![parsed isKindOfClass:NSDictionary.class] || !parsed[@"package_format"] || !planOK(parsed, error)) { if (!error || !*error) reject(error, 2, @"Invalid package manifest"); return nil; }
                plan = parsed;
                if ((unsigned long long)info.st_size > [plan[@"limits"][@"archive_bytes"] unsignedLongLongValue]) { reject(error, 2, @"Archive exceeds manifest limit"); return nil; }
                if (!spaceForPlan(plan, error)) return nil;
                *manifest = data;
            } else {
                NSDictionary *entry = plan[@"members"][name];
                if (!entry || [seen containsObject:name] || [seen count] >= 100000 || ![entry[@"type"] isEqual:isDirectory ? @"directory" : @"file"] || size != [entry[@"bytes"] unsignedLongLongValue]) break;
                NSString *parent = name.stringByDeletingLastPathComponent;
                if (parent.length && ![seen containsObject:parent]) break;
                NSURL *destination = [contents URLByAppendingPathComponent:name isDirectory:isDirectory];
                if (isDirectory) { if (!directory(destination, error)) return nil; }
                else {
                    if (!plainPath(destination, error)) return nil;
                    int output = open(destination.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
                    if (output < 0) { reject(error, 2, @"Cannot create package member"); return nil; }
                    BOOL copied = YES; unsigned long long remaining = size; uint8_t buffer[65536];
                    while (remaining) {
                        size_t count = (size_t)MIN(remaining, sizeof(buffer));
                        if (cancelled(stage, generation)) { reject(error, 130, @"Installation cancelled during package extraction"); copied = NO; break; }
                        if (!readBytes(fd, buffer, count)) { copied = NO; break; }
                        size_t written = 0;
                        while (written < count) { ssize_t n = write(output, buffer + written, count - written); if (n < 0 && errno == EINTR) continue; if (n <= 0) { copied = NO; break; } written += n; }
                        if (!copied) break;
                        remaining -= count;
                    }
                    close(output);
                    if (!copied || !exclude(destination, error) || !verifiedFile(destination, entry[@"bytes"], entry[@"sha256"])) { if (!error || !*error) reject(error, 2, @"Package member size or SHA256 mismatch"); return nil; }
                }
                [seen addObject:name];
            }
            offset += size;
            size_t padding = (512 - size % 512) % 512; uint8_t pad[512];
            if (!readBytes(fd, pad, padding) || !zeros(pad, padding)) break;
            offset += padding;
        }
        reject(error, 2, @"Invalid ustar header, path, entry, padding or terminator"); return nil;
    } @finally { close(fd); }
}
static BOOL validate(NSURL *compiled, NSDictionary *plan, NSError **error) {
    MLModelConfiguration *config = [MLModelConfiguration new]; config.computeUnits = MLComputeUnitsCPUOnly;
    MLModel *model = [MLModel modelWithContentsOfURL:compiled configuration:config error:error];
    MLFeatureDescription *image = model.modelDescription.inputDescriptionsByName[@"image"];
    if (!model) return NO;
    if (model.modelDescription.inputDescriptionsByName.count != 1 || image.type != MLFeatureTypeImage || image.imageConstraint.pixelsWide != 28 || image.imageConstraint.pixelsHigh != 28 || image.imageConstraint.pixelFormatType != kCVPixelFormatType_OneComponent8) return reject(error, 2, @"Compiled features do not match MNIST uint8[28,28]");
    NSDictionary<NSString *, MLFeatureDescription *> *outputs = model.modelDescription.outputDescriptionsByName;
    if (outputs.count != 2 || outputs[@"classLabel"].type != MLFeatureTypeInt64 || outputs[@"labelProbabilities"].type != MLFeatureTypeDictionary || outputs[@"labelProbabilities"].dictionaryConstraint.keyType != MLFeatureTypeInt64) return reject(error, 2, @"Compiled output types do not match the declared drawing-classification adapter");
    CVPixelBufferRef buffer = NULL;
    if (CVPixelBufferCreate(kCFAllocatorDefault, 28, 28, kCVPixelFormatType_OneComponent8, NULL, &buffer) != kCVReturnSuccess) return reject(error, 1, @"Cannot allocate validation image");
    if (CVPixelBufferLockBaseAddress(buffer, 0) != kCVReturnSuccess) { CVPixelBufferRelease(buffer); return reject(error, 1, @"Cannot lock validation image"); }
    NSString *hex = plan[@"validation"][@"input_hex"];
    for (NSUInteger row = 0; row < 28; row++) {
        uint8_t *base = (uint8_t *)CVPixelBufferGetBaseAddress(buffer) + row * CVPixelBufferGetBytesPerRow(buffer);
        for (NSUInteger col = 0; col < 28; col++) base[col] = (uint8_t)strtoul([hex substringWithRange:NSMakeRange((row * 28 + col) * 2, 2)].UTF8String, NULL, 16);
    }
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    MLDictionaryFeatureProvider *input = [[MLDictionaryFeatureProvider alloc] initWithDictionary:@{@"image":[MLFeatureValue featureValueWithPixelBuffer:buffer]} error:error];
    id<MLFeatureProvider> output = input ? [model predictionFromFeatures:input error:error] : nil;
    CVPixelBufferRelease(buffer);
    if (!output) return NO;
    NSDictionary *scores = [output featureValueForName:@"labelProbabilities"].dictionaryValue;
    double sum = 0; BOOL valid = scores.count == 10 && [output featureValueForName:@"classLabel"].int64Value == 7;
    for (int i = 0; i < 10; i++) { NSNumber *score = scores[@(i)]; valid = valid && score && isfinite(score.doubleValue) && score.doubleValue >= 0 && score.doubleValue <= 1; sum += score.doubleValue; }
    return (valid && fabs(sum - 1) < 1e-4) || reject(error, 2, @"Known-answer validation failed");
}
static void collect(NSDictionary *record) {
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSURL *child in [fm contentsOfDirectoryAtURL:rootURL() includingPropertiesForKeys:nil options:0 error:nil]) {
        NSString *name = child.lastPathComponent;
        if (!digestOK(name) || [name isEqual:record[@"active"]] || [name isEqual:record[@"rollback"]]) continue;
        int fd = lockFile([@".lease-" stringByAppendingString:name], LOCK_EX, YES, nil);
        if (fd >= 0) { if (plainPath(child, nil)) [fm removeItemAtURL:child error:nil]; close(fd); }
    }
}
static BOOL phase(NSURL *stage, NSString *digest, NSString *generation, NSString *name, NSError **error) {
    return writeJSON(@{@"model_id":selectedModel(), @"manifest_sha256":digest, @"generation":generation, @"phase":name, @"stage":stage.lastPathComponent}, [rootURL() URLByAppendingPathComponent:@"install.json"], error);
}
static BOOL copyPackage(NSURL *source, NSURL *target, NSURL *stage, NSString *generation, NSError **error) {
    if (!plainPath(source, error) || !plainPath(target, error)) return NO;
    int input = open(source.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW | O_NONBLOCK); struct stat info;
    if (input < 0 || fstat(input, &info) || !S_ISREG(info.st_mode) || info.st_size <= 0 || (unsigned long long)info.st_size > packageCeiling) {
        if (input >= 0) close(input); return reject(error, 2, @"Invalid local package or archive size");
    }
    if (!spaceForPlan(@{@"disk_estimate_bytes":@((unsigned long long)info.st_size + 8 * 1024 * 1024)}, error)) { close(input); return NO; }
    int output = open(target.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
    if (output < 0) { close(input); return reject(error, 2, @"Cannot stage package"); }
    BOOL ok = YES; unsigned long long remaining = info.st_size; uint8_t buffer[65536];
    while (remaining) {
        if (cancelled(stage, generation)) { reject(error, 130, @"Installation cancelled while copying package"); ok = NO; break; }
        ssize_t count = read(input, buffer, (size_t)MIN(remaining, sizeof(buffer)));
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) { ok = NO; break; }
        ssize_t offset = 0;
        while (offset < count) { ssize_t n = write(output, buffer + offset, count - offset); if (n < 0 && errno == EINTR) continue; if (n <= 0) { ok = NO; break; } offset += n; }
        if (!ok) break;
        remaining -= count;
    }
    if (ok && (fstat(input, &info) || read(input, buffer, 1) != 0)) ok = NO;
    close(input); close(output);
    if (!ok) { if (!error || !*error) reject(error, 2, @"Package changed or could not be copied"); return NO; }
    return exclude(target, error);
}
static NSDictionary *install(NSString *location, NSString *digest, NSError **error) {
#if TARGET_OS_IPHONE
    if ([NSThread isMainThread] || [NSBundle.mainBundle.bundlePath containsString:@".appex"]) { reject(error, 75, @"Installation requires an off-main caller in the main application"); return nil; }
#endif
    if (digest && !digestOK(digest)) { reject(error, 2, @"Invalid SHA256 pin"); return nil; }
    int guard = lockFile(@".install-lock", LOCK_EX, YES, error); if (guard < 0) return nil;
    NSURL *archiveFile;
    NSMutableDictionary *context = NSThread.currentThread.threadDictionary; id previousCheck = context[@"ASMLInstallCheck"];
    @try {
        NSFileManager *fm = NSFileManager.defaultManager;
        NSString *transferID = digest ?: hashData([location dataUsingEncoding:NSUTF8StringEncoding]);
        NSURL *stage = [rootURL() URLByAppendingPathComponent:[@".staging-" stringByAppendingString:transferID] isDirectory:YES];
        NSString *generation = NSUUID.UUID.UUIDString;
        context[@"ASMLInstallCheck"] = [^NSError *{ return cancelled(stage, generation) ? problem(130, @"Installation cancelled") : nil; } copy];
        if (!directory(stage, error) || !phase(stage, transferID, generation, @"manifest", error)) return nil;
        // A failed archive retry reuses this stage; do not retain its large download.
        for (NSURL *stale in [fm contentsOfDirectoryAtURL:stage includingPropertiesForKeys:nil options:0 error:nil]) {
            NSString *name = stale.lastPathComponent;
            if ([name hasPrefix:@"archive-"] || [name hasPrefix:@"manifest-"] || ([name hasPrefix:@"cancel-"] && ![name isEqual:[@"cancel-" stringByAppendingString:generation]])) {
                if (!plainPath(stale, error) || ![fm removeItemAtURL:stale error:error]) return nil;
            }
        }
        for (NSURL *stale in [fm contentsOfDirectoryAtURL:rootURL() includingPropertiesForKeys:nil options:0 error:nil]) {
            NSString *name = stale.lastPathComponent;
            if ([name hasPrefix:@".staging-"] && digestOK([name substringFromIndex:@".staging-".length]) && ![name isEqual:stage.lastPathComponent]) {
                if (!plainPath(stale, error) || ![fm removeItemAtURL:stale error:error]) return nil;
            }
        }
        NSURL *url = [NSURL URLWithString:location];
        NSData *data; NSDictionary *plan; NSString *archiveSHA;
        if (!spaceForPlan(@{@"disk_estimate_bytes":@(8 * 1024 * 1024)}, error)) return nil;
        NSURL *package = [stage URLByAppendingPathComponent:[NSString stringWithFormat:@"archive-%@.download", generation]];
        archiveFile = package;
        if (!phase(stage, transferID, generation, @"downloading", error)) return nil;
        if (!url.scheme || url.isFileURL) {
            if (!copyPackage(url.isFileURL ? url : [NSURL fileURLWithPath:location], package, stage, generation, error)) return nil;
        } else if (!fetchFile(location, package, packageCeiling, stage, generation, error)) return nil;
        archiveSHA = hashFile(package, error);
        if (!archiveSHA || (digest && ![archiveSHA isEqual:digest])) { reject(error, 2, @"Archive SHA256 mismatch"); return nil; }
        plan = extractPackage(package, stage, generation, &data, error);
        if (!plan) return nil;
        digest = hashData(data);
        if (![fm removeItemAtURL:package error:error]) return nil;
        NSDictionary *active = readJSON([rootURL() URLByAppendingPathComponent:@"active.json"]);
        NSString *old = active[@"active"];
        if (old && !checkedReceipt(old, nil)) old = nil;
        NSDictionary *existing = checkedReceipt(digest, nil);
        if (existing) {
            int commitGuard = lockFile(@".commit-lock", LOCK_EX, YES, error); if (commitGuard < 0) return nil;
            @try {
                if (cancelled(stage, generation)) { reject(error, 130, @"Installation cancelled before activation"); return nil; }
                if (![old isEqual:digest]) {
                    NSMutableDictionary *record = [@{@"active":digest} mutableCopy];
                    if (old) record[@"rollback"] = old;
                    if (!writeJSON(record, [rootURL() URLByAppendingPathComponent:@"active.json"], error)) return nil;
                    collect(record);
                }
                phase(stage, digest, generation, @"active", nil); [fm removeItemAtURL:stage error:nil]; return existing;
            } @finally { close(commitGuard); }
        }
        if (!spaceForPlan(plan, error)) return nil;
        if (!phase(stage, digest, generation, @"downloading", error) || !writeJSON(plan, [stage URLByAppendingPathComponent:@"plan.json"], error)) return nil;
        if (cancelled(stage, generation)) { reject(error, 130, @"Installation cancelled before compilation"); return nil; }
        if (!phase(stage, digest, generation, @"downloaded", error)) return nil;
        // Download completion never authorizes compilation in a callback/background event.
        if (!compilationAllowed(error) || !phase(stage, digest, generation, @"compiling", error)) return nil;
        NSURL *contents = [stage URLByAppendingPathComponent:@"package" isDirectory:YES];
        NSURL *compiled = [stage URLByAppendingPathComponent:@"model.mlmodelc"];
        NSURL *temporary = [MLModel compileModelAtURL:[contents URLByAppendingPathComponent:plan[@"model"]] error:error];
        if (!temporary) { NSString *detail = (error && *error) ? (*error).localizedDescription : @"Unknown compiler error"; reject(error, 2, [@"Portable model compilation rejected: " stringByAppendingString:detail]); return nil; }
        if ([fm fileExistsAtPath:compiled.path] && (!plainPath(compiled, error) || ![fm removeItemAtURL:compiled error:error])) { [fm removeItemAtURL:temporary error:nil]; return nil; }
        if (![fm moveItemAtURL:temporary toURL:compiled error:error]) { [fm removeItemAtURL:temporary error:nil]; return nil; }
        if (!exclude(compiled, error) || !compilationAllowed(error)) return nil;
        int admission = asml_maintenance_begin();
        if (admission) { reject(error, admission, @"Inference is busy; retry installation after the active job completes"); return nil; }
        BOOL validated = NO;
        NSError *validationError = nil;
        @try {
            @autoreleasepool { validated = ASMLEmbeddingID(plan[@"model_id"]) ? ASMLEmbeddingValidate(compiled, contents, plan, ^NSError *{ return operationError(); }, &validationError) : validate(compiled, plan, &validationError); }
        }
        @finally { asml_maintenance_end(); }
        if (!validated) { if (error) *error = validationError; return nil; }
        if (cancelled(stage, generation)) { reject(error, 130, @"Installation cancelled after compilation"); return nil; }
        NSDictionary *compiledFiles = treeReceipt(compiled, YES, error); if (!compiledFiles) return nil;
        NSMutableDictionary *receipt = [plan mutableCopy];
        receipt[@"manifest_sha256"] = digest; receipt[@"compiled_files"] = compiledFiles;
        if (archiveSHA) receipt[@"archive_sha256"] = archiveSHA;
        struct stat licenseInfo; stat([[contents URLByAppendingPathComponent:plan[@"license_file"]] fileSystemRepresentation], &licenseInfo);
        receipt[@"license_bytes"] = @((unsigned long long)licenseInfo.st_size);
        unsigned long long compiledBytes = 0; for (NSDictionary *file in compiledFiles.allValues) compiledBytes += [file[@"bytes"] unsignedLongLongValue];
        receipt[@"compiled_bytes"] = @(compiledBytes);
        unsigned long long portableBytes = 0; for (NSDictionary *member in [plan[@"members"] allValues]) portableBytes += [member[@"bytes"] unsignedLongLongValue];
        receipt[@"installed_bytes"] = @(compiledBytes + portableBytes);
        receipt[@"validation_label"] = ASMLEmbeddingID(plan[@"model_id"]) ? @"embedding-cosine>=0.99" : @"7"; receipt[@"compiled_os"] = NSProcessInfo.processInfo.operatingSystemVersionString;
        if (!atomicData(data, [stage URLByAppendingPathComponent:@"manifest.json"], error) || !writeJSON(receipt, [stage URLByAppendingPathComponent:@"receipt.json"], error)) return nil;
        if (!phase(stage, digest, generation, @"activating", error)) return nil;
        if (cancelled(stage, generation)) { reject(error, 130, @"Installation cancelled before activation"); return nil; }
        if (!treeReceipt(stage, YES, error)) return nil;
        // Cancellation acknowledgement and publication share a fence. The sync
        // above can be slow; a token acknowledged during it must prevent activation.
        int commitGuard = lockFile(@".commit-lock", LOCK_EX, YES, error); if (commitGuard < 0) return nil;
        @try {
            if (cancelled(stage, generation)) { reject(error, 130, @"Installation cancelled before activation"); return nil; }
            // The commit fence excludes new cancel markers while transfer scratch
            // is removed. Only package content belongs in an immutable version.
            NSSet *published = [NSSet setWithArray:@[@"package", @"model.mlmodelc", @"manifest.json", @"receipt.json", @"plan.json"]];
            NSArray *entries = [fm contentsOfDirectoryAtURL:stage includingPropertiesForKeys:nil options:0 error:error];
            if (!entries) return nil;
            for (NSURL *scratch in entries) {
                if (![published containsObject:scratch.lastPathComponent] && (!plainPath(scratch, error) || ![fm removeItemAtURL:scratch error:error])) return nil;
            }
            NSURL *destination = version(digest);
            if ([fm fileExistsAtPath:destination.path]) {
                int fd = lockFile([@".lease-" stringByAppendingString:digest], LOCK_EX, YES, error); if (fd < 0) return nil;
                BOOL removed = plainPath(destination, error) && [fm removeItemAtURL:destination error:error]; close(fd); if (!removed) return nil;
            }
            if (![fm moveItemAtURL:stage toURL:destination error:error]) return nil;
            NSMutableDictionary *record = [@{@"active":digest} mutableCopy];
            if (old && ![old isEqual:digest]) record[@"rollback"] = old;
            else if (checkedReceipt(active[@"rollback"], nil)) record[@"rollback"] = active[@"rollback"];
            if (!writeJSON(record, [rootURL() URLByAppendingPathComponent:@"active.json"], error)) return nil;
            phase(destination, digest, generation, @"active", nil); collect(record);
            return checkedReceipt(digest, error);
        } @finally { close(commitGuard); }
    } @finally { if (previousCheck) context[@"ASMLInstallCheck"] = previousCheck; else [context removeObjectForKey:@"ASMLInstallCheck"]; if (archiveFile) [NSFileManager.defaultManager removeItemAtURL:archiveFile error:nil]; close(guard); }
}
NSDictionary *ASMLInstallPackage(NSString *location, NSString *digest, NSError **error) { return install(location, digest, error); }
static NSDictionary *scopedASMLRollback(NSString *modelID, NSError **error) {
    if (!supported(modelID, error)) return nil;
    int guard = lockFile(@".install-lock", LOCK_EX, YES, error); if (guard < 0) return nil;
    @try {
        NSDictionary *record = readJSON([rootURL() URLByAppendingPathComponent:@"active.json"]);
        NSDictionary *receipt = checkedReceipt(record[@"rollback"], error); if (!receipt) return nil;
        NSDictionary *next = @{@"active":record[@"rollback"], @"rollback":record[@"active"]};
        if (!writeJSON(next, [rootURL() URLByAppendingPathComponent:@"active.json"], error)) return nil;
        collect(next); return receipt;
    } @finally { close(guard); }
}
static NSDictionary *scopedASMLRemove(NSString *modelID, NSError **error) {
    if (!supported(modelID, error)) return nil;
    int guard = lockFile(@".install-lock", LOCK_EX, YES, error); if (guard < 0) return nil;
    NSMutableArray *fds = [NSMutableArray array];
    @try {
        NSFileManager *fm = NSFileManager.defaultManager;
        NSArray *children = [fm contentsOfDirectoryAtURL:rootURL() includingPropertiesForKeys:nil options:0 error:error];
        if (!children) return nil;
        for (NSURL *child in children) if (digestOK(child.lastPathComponent)) {
            int fd = lockFile([@".lease-" stringByAppendingString:child.lastPathComponent], LOCK_EX, YES, error);
            if (fd < 0) return nil; [fds addObject:@(fd)];
        }
        // Removing the pointer first cannot leave a pointer to deleted content after a crash.
        NSURL *active = [rootURL() URLByAppendingPathComponent:@"active.json"];
        if ([fm fileExistsAtPath:active.path] && ![fm removeItemAtURL:active error:error]) return nil;
        for (NSURL *child in children) {
            NSString *name = child.lastPathComponent;
            if ((digestOK(name) || [name hasPrefix:@".staging-"] || [name isEqual:@"install.json"]) && (!plainPath(child, error) || ![fm removeItemAtURL:child error:error])) return nil;
        }
        return @{@"removed":modelID};
    } @finally { for (NSNumber *fd in fds) close(fd.intValue); close(guard); }
}
static NSDictionary *scopedASMLInstallStatus(NSString *modelID, NSError **error) {
    if (!supported(modelID, error)) return nil;
    // The journal survives failure/crash for recovery; its phase is not liveness.
    // Probe the actual command lock without creating storage on a status read.
    NSURL *file = [rootURL() URLByAppendingPathComponent:@".install-lock"];
    int fd = open(file.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW);
    if (fd < 0 && errno != ENOENT) { reject(error, 2, @"Cannot inspect installation command lock"); return nil; }
    BOOL running = NO;
    if (fd >= 0 && flock(fd, LOCK_SH | LOCK_NB)) {
        if (errno != EWOULDBLOCK) { close(fd); reject(error, 2, @"Cannot inspect installation command lock"); return nil; }
        running = YES;
    }
    NSMutableDictionary *state = [(readJSON([rootURL() URLByAppendingPathComponent:@"install.json"]) ?: @{@"model_id":modelID, @"phase":@"idle"}) mutableCopy];
    state[@"command_running"] = @(running);
    if (fd >= 0) close(fd);
    return state;
}
static NSDictionary *scopedASMLCancelInstall(NSString *modelID, NSString *generation, NSError **error) {
    if (!supported(modelID, error)) return nil;
    int guard = lockFile(@".commit-lock", LOCK_EX, YES, error); if (guard < 0) return nil;
    @try {
        NSDictionary *state = ASMLInstallStatus(modelID, error);
        if (![state[@"generation"] isEqual:generation] || [state[@"phase"] isEqual:@"active"]) { reject(error, 2, @"No cancellable installation with that generation"); return nil; }
        NSString *name = state[@"stage"];
        if (![name isKindOfClass:NSString.class] || ![name hasPrefix:@".staging-"] || [name containsString:@"/"]) { reject(error, 2, @"Invalid installation stage"); return nil; }
        NSURL *file = [[rootURL() URLByAppendingPathComponent:name] URLByAppendingPathComponent:[@"cancel-" stringByAppendingString:generation]];
        if (!atomicData(NSData.data, file, error)) return nil;
        return @{@"cancel_requested":generation};
    } @finally { close(guard); }
}

NSDictionary *ASMLInstalledVersion(NSString *modelID, NSError **error) {
    if (!supported(modelID, error)) return nil;
    NSMutableDictionary *context = NSThread.currentThread.threadDictionary; id previous = context[@"ASMLInstallModel"]; context[@"ASMLInstallModel"] = modelID;
    @try { return scopedASMLInstalledVersion(modelID, error); } @finally { if (previous) context[@"ASMLInstallModel"] = previous; else [context removeObjectForKey:@"ASMLInstallModel"]; }
}

NSDictionary *ASMLAcquireVersion(NSString *modelID, NSError *(^check)(void), NSError **error) {
    if (!supported(modelID, error)) return nil;
    NSMutableDictionary *context = NSThread.currentThread.threadDictionary; id previous = context[@"ASMLInstallModel"], previousCheck = context[@"ASMLInstallCheck"]; context[@"ASMLInstallModel"] = modelID;
    if (check) context[@"ASMLInstallCheck"] = [check copy]; else [context removeObjectForKey:@"ASMLInstallCheck"];
    @try { return operationAllowed(error) ? scopedASMLAcquireVersion(modelID, error) : nil; } @finally {
        if (previousCheck) context[@"ASMLInstallCheck"] = previousCheck; else [context removeObjectForKey:@"ASMLInstallCheck"];
        if (previous) context[@"ASMLInstallModel"] = previous; else [context removeObjectForKey:@"ASMLInstallModel"];
    }
}

NSDictionary *ASMLRollback(NSString *modelID, NSError **error) {
    if (!supported(modelID, error)) return nil;
    NSMutableDictionary *context = NSThread.currentThread.threadDictionary; id previous = context[@"ASMLInstallModel"]; context[@"ASMLInstallModel"] = modelID;
    @try { return scopedASMLRollback(modelID, error); } @finally { if (previous) context[@"ASMLInstallModel"] = previous; else [context removeObjectForKey:@"ASMLInstallModel"]; }
}

NSDictionary *ASMLRemove(NSString *modelID, NSError **error) {
    if (!supported(modelID, error)) return nil;
    NSMutableDictionary *context = NSThread.currentThread.threadDictionary; id previous = context[@"ASMLInstallModel"]; context[@"ASMLInstallModel"] = modelID;
    @try { return scopedASMLRemove(modelID, error); } @finally { if (previous) context[@"ASMLInstallModel"] = previous; else [context removeObjectForKey:@"ASMLInstallModel"]; }
}

NSDictionary *ASMLInstallStatus(NSString *modelID, NSError **error) {
    if (!supported(modelID, error)) return nil;
    NSMutableDictionary *context = NSThread.currentThread.threadDictionary; id previous = context[@"ASMLInstallModel"]; context[@"ASMLInstallModel"] = modelID;
    @try { return scopedASMLInstallStatus(modelID, error); } @finally { if (previous) context[@"ASMLInstallModel"] = previous; else [context removeObjectForKey:@"ASMLInstallModel"]; }
}

NSDictionary *ASMLCancelInstall(NSString *modelID, NSString *generation, NSError **error) {
    if (!supported(modelID, error)) return nil;
    NSMutableDictionary *context = NSThread.currentThread.threadDictionary; id previous = context[@"ASMLInstallModel"]; context[@"ASMLInstallModel"] = modelID;
    @try { return scopedASMLCancelInstall(modelID, generation, error); } @finally { if (previous) context[@"ASMLInstallModel"] = previous; else [context removeObjectForKey:@"ASMLInstallModel"]; }
}

NSDictionary *ASMLInstallModelPackage(NSString *modelID, NSString *location, NSString *digest, NSError **error) {
    if (!supported(modelID, error)) return nil;
    NSMutableDictionary *context = NSThread.currentThread.threadDictionary; id previous = context[@"ASMLInstallModel"]; context[@"ASMLInstallModel"] = modelID;
    @try { return install(location, digest, error); } @finally { if (previous) context[@"ASMLInstallModel"] = previous; else [context removeObjectForKey:@"ASMLInstallModel"]; }
}
