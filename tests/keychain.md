# Protected Keychain passwords

`keychain set <name>` reads up to 65536 bytes from stdin to EOF. When stdin is a terminal, it opens native secure text entry. Secret values are never command arguments. Replacing an item preserves its policy and requires fresh biometric authorization.

`keychain get <name>` explicitly exports the exact stored bytes, without a newline, after native disclosure and authorization. Use only disposable secrets when testing: terminal output, pipelines and transcripts can capture exported bytes.

`keychain ls` prints names and types only. Security may still require authentication to enumerate protected metadata. `keychain rm <name>` confirms deletion and requires fresh biometrics; deleting a missing name succeeds after the same confirmation and fresh biometric authorization. Deletion does not decrypt the old value, so an unreadable item can still be removed.

`keychain policy <name>` prints versioned JSON and the OS/app enforcement boundary. `keychain policy <name> --edit` opens a native JSON editor, rejects unsupported fields and shows changed settings before confirmation. Cancel or dismiss the review to leave the item unchanged. Continue requests fresh biometric authorization before updating the protected envelope and ACL together.

The default is private signed-app Keychain storage, passcode-set ThisDeviceOnly accessibility, no synchronization, current biometric enrollment and zero context reuse. The policy supports explicit user-presence, device-passcode and unlocked modes without automatic fallback. Nonzero reuse requires current-set biometry and is bounded to 300 seconds. A consumer override may only strengthen authentication and shorten its reuse limit. Only authentication contexts are retained; secret bytes are not cached.

Consumer operations, destination scopes and reuse limits are app-enforced restrictions. Native code with the same signed app identity can bypass them. Keychain ACLs and access groups provide the OS boundary; command names do not isolate native code.

Names contain 1-255 ASCII letters/digits or `. _ - : /`, without a leading `-` or `..`. A reserved Git name such as `git:https://example.invalid/team/project.git` binds policy to that exact canonical HTTPS destination and denies CLI export by default. This command does not add a Git credential helper or Shortcuts consumer.

## Host checks

Run from the repository checkout:

```sh
sh tests/keychain-host.sh
sh tests/keychain-scene-revert.sh
```

The host executable runs the production command and policy parser with substitutes for the external Keychain database, authentication and native UI. It checks binary round-trip, names/size/policy rejection, missing/duplicate handling, failure preservation, policy review and scene decisions. The second command compiles each historical active-only scene decision into a temporary source copy and verifies that the corresponding foreground-inactive regression fails. These checks do not exercise UIKit presentation, Security ACLs or the native stream bridge.

## Interactive device checks

Use a foreground terminal in a local build and a new disposable name. Keep exported bytes in a pipe oracle, never in a terminal capture or a file. Verify native secure entry, names-only listing, a seven-byte binary value containing NUL and non-UTF-8 bytes, repeated replacement/export, policy rejection and preservation, authorized removal and repeated missing removal. Stop on a failed check and preserve the disposable item until preservation checks finish.

Observe disclosure cancellation and actual system Face ID permit/cancel separately. Interrupt pending authentication, secure entry and the policy editor by backgrounding and locking; record dismissal, nonzero status and zero exported bytes. After returning/unlocking, submit a separate fresh export and verify the original bytes and policy. Do not treat a cancellation status alone as proof that a system biometric sheet appeared.

For reuse tests, verify the effective CLI authentication policy, including any override. Record actual prompt behavior and monotonic timing inside the original reuse bound; distinguish original expiry from a bound extended by a later read. Check cancellation, background, lock and policy revision independently. Do not change device enrollment or remove its passcode for testing.
