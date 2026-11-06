//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "KBWebViewBase.h"

// Existing ios_system status setter; pthread cancellation skips a command return.
void set_session_errno(int status);
