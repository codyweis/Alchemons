# Purchase verification

Gold packs used to be credited entirely on the device: the game asked the store
to bill the player, and then wrote the gold straight into the local save. Nobody
ever checked that a purchase had happened. That made three things free for an
attacker — a patched billing library, replaying one receipt onto many accounts,
and handing a backup containing purchased gold to a friend.

This is phase 0 of the fix: **the server decides whether a purchase is real and
what it is worth.** Phase 1 (reconciling purchased gold on restore) builds on the
ledger this phase creates.

## How it works

1. The player buys a pack. `MobileStoreService` receives the purchase from
   `in_app_purchase` and writes it to a device-local queue
   (`iap.pending_redeems.v1` in `SharedPreferences`) *before* trying to redeem
   it. Nothing is credited yet.
2. `PurchaseVerificationService` calls the `redeemPurchase` Cloud Function with
   the platform, the product id and the store receipt. It never sends an amount.
3. The function verifies the receipt with Google Play or the App Store, looks
   the gold amount up in its own catalog, and **creates** (not sets)
   `purchases/{platform}_{transactionId}`. Because the document id is the
   store's own transaction id and the write is a create, a given receipt can be
   redeemed exactly once, by exactly one account, forever.
4. It increments `entitlements/{uid}` — `purchasedGoldTotal` and
   `purchasedGoldOutstanding` — and returns the amount.
5. The client credits the gold via `CurrencyDao.creditPurchasedGold`, marks the
   purchase settled, and drops it from the queue.

The queue is drained on launch, after every purchase, and whenever the signed-in
account changes. A purchase made on a dead connection is retried until the server
gives a definite answer, so a player who buys on a plane still gets their gold.

### Why the queue is not in the save

`iap.pending_redeems.v1` is listed in `SaveTransferService._protectedPreferenceKeys`.
It is left out of an export and preserved across an import. A queued purchase
belongs to the device that paid for it, not to the save, and restoring a backup
must not throw it away. `test/purchase_entitlement_test.dart` covers both halves.

### Why gold packs now require an account

A receipt is credited to a uid. Signed out, there is nothing to credit and no way
to verify. The shop disables the buy button and explains why. If a purchase does
somehow arrive while signed out it stays queued and redeems on the next sign-in
rather than being lost.

If you would rather players never see a sign-in wall, the alternative is
anonymous auth at first launch plus `linkWithCredential` when they create a real
account. That preserves the uid and its entitlements, but it is a change to the
account model, not to this code.

## Failure handling

`redeemPurchase` distinguishes two kinds of "no", and the client treats them
differently:

| Server response | Meaning | Client |
| --- | --- | --- |
| `permission-denied` | already redeemed on another account | drop, show the error |
| `failed-precondition` | the store says the receipt is not valid | drop, show the error |
| `invalid-argument` | unknown product | drop, show the error |
| `unavailable`, `internal`, anything else | we could not get an answer | keep queued, retry |

A retry that finds the transaction already recorded **for the same account**
returns `firstRedeem: false`. The client still credits the gold if this device
has not already done so — that case means an earlier attempt reached the server
but its reply did not, and the player is still owed it. The entitlement is not
incremented twice.

## Setup

None of this works until the project is configured. The code deploys fine and
then fails every redeem with `internal` if you skip these.

### 1. Blaze plan

Cloud Functions requires it. Firestore usage here is negligible; the cost is
essentially the function invocations.

### 2. Google Play

The function authenticates to the Play Developer API with the Cloud Functions
runtime service account (application default credentials) — there is no key file
to manage.

1. Google Cloud console → enable **Google Play Android Developer API** on
   `alchemons-auth`.
2. Note the runtime service account, normally
   `alchemons-auth@appspot.gserviceaccount.com`.
3. Play Console → **Users and permissions** → invite that address, granting
   **View financial data** and **Manage orders and subscriptions** for the app.

Permission changes can take a few hours to propagate. Until they do, redeems
fail as `unavailable` and stay queued, which is the correct behaviour.

### 3. App Store (only if shipping iOS)

App Store Connect → your app → **App-Specific Shared Secret**, then:

```bash
firebase functions:secrets:set APP_STORE_SHARED_SECRET
```

Verification uses the legacy `verifyReceipt` endpoint with the standard
production-then-sandbox fallback, which matches the StoreKit 1 receipts that
`in_app_purchase` 3.2.0 produces.

### 4. Deploy

```bash
firebase deploy --only functions,firestore:rules
```

### 5. Keep the two catalogs in step

`functions/src/catalog.ts` is the only thing that decides how much gold a product
grants. `_catalog` in `lib/services/mobile_store_service.dart` is display copy.
If they disagree, the server wins and the player sees a different number than the
shop advertised, so change both together.

## What this does not fix

- **A patched client can still call `addGold` directly.** Earned gold is not
  defended and cannot be while the game is offline-first. There is no PvP and no
  shared leaderboard, so a cheater only affects their own save.
- **A shared backup still carries purchased gold** until phase 1 reconciles the
  outstanding counter against the account's entitlement on restore. The counter
  is already being tracked and exported, so the data is there when that lands.
- **App Check is not enabled.** It would stop a script calling `redeemPurchase`
  from outside the app, though such a script still needs a genuine unredeemed
  receipt to get anything.
