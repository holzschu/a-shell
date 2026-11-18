#pragma once
#import <Foundation/Foundation.h>

// Acquire while holding inference admission, before resolving the active record.
// Hold lease_id through the warm cache lifetime; release only after native completion.
// Poll check during verification; return its error without acquiring a lease on cancellation.
// Returns the immutable receipt with lease_id, path and manifest_sha256, or nil/error.
NSDictionary *ASMLAcquireVersion(NSString *modelID, NSError *(^check)(void), NSError **error);
void ASMLReleaseVersion(NSString *leaseID);
NSDictionary *ASMLInstalledVersion(NSString *modelID, NSError **error);
NSDictionary *ASMLInstallPackage(NSString *location, NSString *digest, NSError **error);
NSDictionary *ASMLRollback(NSString *modelID, NSError **error);
NSDictionary *ASMLRemove(NSString *modelID, NSError **error);
NSDictionary *ASMLInstallStatus(NSString *modelID, NSError **error);
NSDictionary *ASMLCancelInstall(NSString *modelID, NSString *generation, NSError **error);
// AppDelegate forwards background download events; this never compiles/activates.
int asml_background_events(const char *identifier, void (^completion)(void));

NSDictionary *ASMLInstallModelPackage(NSString *modelID, NSString *location, NSString *digest, NSError **error);
