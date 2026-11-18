#pragma once
#import <Foundation/Foundation.h>

// The host lease test acquires the immutable receipt and holds its lease until release.
// A cancellation returned by check prevents acquisition.
NSDictionary *ASMLAcquireVersion(NSString *modelID, NSError *(^check)(void), NSError **error);
void ASMLReleaseVersion(NSString *leaseID);

// AppDelegate forwards background download events without compiling or activating.
int asml_background_events(const char *identifier, void (^completion)(void));
