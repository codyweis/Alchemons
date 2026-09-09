# Reset progress

Profile's **Reset Progress** keeps the authenticated account and starts a fresh
game. It restores the server's lifetime verified purchased-gold total, including
previously spent gold, on top of normal starting gold. Every reset replaces that
balance; a reset is not an additional purchase. Guests can reset only their local
game; they must sign into the purchasing account first to restore purchased gold.

## Recovery and purchase delivery

The client persists `account.reset_pending.v1` before contacting the backend.
`beginProgressReset` uses the operation ID as an idempotency key, advances the
server-controlled `account_progress/{uid}.generation`, records the quoted gold
total, locks account writes/purchase delivery, and removes the old cloud backup
in one transaction. A stale quote or inactive device is refused before mutation.

The root reset host disposes game providers before changing the database.
`account.reset_applied` is written in the same database transaction as the fresh
save and restored wallet. Retrying resumes preference cleanup and upload without
granting gold again. The catalog is initialized before exporting the new backup.
`finishProgressReset` installs that backup and unlocks the account. A lost finish
response is safe to retry and cannot overwrite a subsequent gameplay backup.

Pending receipts and device identity are never exported or erased. Purchases
record their redemption generation. A retried receipt from an earlier generation
returns `includedInReset: true`; settlement records it without crediting it
again. New purchases after the reset grant normally. Receipt credit and its local
settlement marker now share one transaction.

If connectivity fails after commitment, the game stays on a retry screen until
the reset completes. If authentication needs renewal, that screen supports signing
back into the original account. It does not allow switching the reset to another
account. A definitive pre-commit refusal preserves the old save; Retry reopens it.

## Retired saves

Save payloads, cloud metadata, transfers, and sessions include their generation.
Imports check the current server generation before local mutation; cloud writes,
transfer redemption, and device activation reject retired generations. Legacy
saves without this field count as generation zero and remain usable until the
account's first reset. Account restore requires connectivity.

An offline device can retain an old local copy, but cannot reconnect it to account
services after a reset. These checks protect normal application flows; the game
remains offline-first and this is not a server-authoritative anti-cheat system.

## Validation and release

- `flutter test test/progress_reset_test.dart test/reset_progress_dialog_test.dart test/purchase_entitlement_test.dart test/save_transfer_potential_migration_test.dart test/cosmic_survival_unlock_persistence_test.dart`
- In `functions`, run `npm ci` and `npm run build`.
- From the repository root: `firebase emulators:exec --only firestore --project demo-alchemons-reset "node --test functions/test/reset_progress.test.cjs"`.
- On Windows, use Java 21 and a short Java temp directory if the emulator reports
  a Unix-domain socket path error. Both `java.io.tmpdir` and
  `jdk.net.unixdomain.tmpdir` can point to `C:/repos/alchemons/build/java_tmp`.
- Deploy the updated `redeemPurchase`, the three reset functions, and Firestore
  rules before distributing the updated client. Profile fetches a server quote
  before offering an authenticated reset; an unavailable backend cannot wipe a
  signed-in player's save.
- Verify on a test account/device: cancel the dialog, reset after spending gold,
  restart during recovery, complete onboarding, restore the fresh backup on a
  second device, and confirm an older backup is rejected.

No legacy real-player purchases need migration for this release. Never remove
purchase ledger/entitlement documents as part of resetting progress, and never
lower an account's generation to roll back a deployment. Old app versions should
be updated before using account services after their account has been reset.

Deployment was attempted on 2026-09-09 but stopped during preparation because
`APP_STORE_SHARED_SECRET` is missing. Even selecting only the reset functions
causes the CLI to resolve that codebase's secret parameters. No functions or
updated rules were released by those attempts. Configure the real secret via
`firebase functions:secrets:set APP_STORE_SHARED_SECRET --project alchemons-auth`
before deploying; never paste the secret into source control or chat.
