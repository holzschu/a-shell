#import <Foundation/Foundation.h>

// One connection owns one real process and one existing native pane handle.
@protocol AShellPaneWire
- (void)spawn:(NSString *)command cwd:(NSData *)cwd home:(NSData *)home documents:(NSData *)documents probe:(NSString *)probe env:(NSArray<NSString *> *)env cols:(unsigned)cols rows:(unsigned)rows tty:(BOOL)tty separateStderr:(BOOL)separateStderr reply:(void (^)(int, NSFileHandle *, NSFileHandle *, int))reply;
- (void)poll:(void (^)(int, int))reply;
- (void)pollUsage:(void (^)(int, int, NSData *))reply;
- (void)resize:(unsigned)cols rows:(unsigned)rows reply:(void (^)(int))reply;
- (void)closeInput:(void (^)(int))reply;
- (void)interrupt:(void (^)(int))reply;
- (void)releasePane;
// The worker exits instead of replying; synchronous callers observe XPC loss.
- (void)terminate:(void (^)(void))reply;
@end

NSObject<AShellPaneWire> *ashell_worker_service(void);

// A worker asks its owning host to allocate another isolated process.
@protocol AShellSpawnBrokerWire
- (void)spawnChild:(NSString *)command cwd:(NSString *)cwd env:(NSArray<NSString *> *)env cols:(unsigned)cols rows:(unsigned)rows tty:(BOOL)tty separateStderr:(BOOL)separate reply:(void (^)(int, NSString *, NSFileHandle *, NSFileHandle *))reply;
- (void)spawnHostChild:(NSString *)command cwd:(NSString *)cwd env:(NSArray<NSString *> *)env cols:(unsigned)cols rows:(unsigned)rows tty:(BOOL)tty separateStderr:(BOOL)separate reply:(void (^)(int, NSString *, NSFileHandle *, NSFileHandle *))reply;
- (void)pollChild:(NSString *)token reply:(void (^)(int, int))reply;
- (void)pollChildUsage:(NSString *)token reply:(void (^)(int, int, NSData *))reply;
- (void)closeChildInput:(NSString *)token reply:(void (^)(int))reply;
- (void)cancelChild:(NSString *)token reply:(void (^)(int))reply;
- (void)resizeChild:(NSString *)token cols:(unsigned)cols rows:(unsigned)rows reply:(void (^)(int))reply;
- (void)interruptChild:(NSString *)token reply:(void (^)(int))reply;
- (void)releaseChild:(NSString *)token;
@end

NSObject<AShellSpawnBrokerWire> *ashell_spawn_broker(void);
