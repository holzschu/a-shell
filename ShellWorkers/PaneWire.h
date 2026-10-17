#import <Foundation/Foundation.h>

// One connection owns one real process and one existing native pane handle.
@protocol AShellPaneWire
- (void)spawn:(NSString *)command cwd:(NSData *)cwd home:(NSData *)home documents:(NSData *)documents probe:(NSString *)probe env:(NSArray<NSString *> *)env cols:(unsigned)cols rows:(unsigned)rows reply:(void (^)(int, NSFileHandle *, int))reply;
- (void)poll:(void (^)(int, int))reply;
- (void)resize:(unsigned)cols rows:(unsigned)rows reply:(void (^)(int))reply;
- (void)closeInput:(void (^)(int))reply;
- (void)interrupt:(void (^)(int))reply;
- (void)releasePane;
// The worker exits instead of replying; synchronous callers observe XPC loss.
- (void)terminate:(void (^)(void))reply;
@end

NSObject<AShellPaneWire> *ashell_worker_service(void);
