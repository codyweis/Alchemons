export type Platform = "android" | "ios";

/**
 * Why a verification attempt failed.
 *
 * - `invalid`    the store says this receipt is not a real, completed purchase.
 *                Telling the client to stop retrying is safe.
 * - `retryable`  we could not reach the store, or the store had a problem. The
 *                client should keep the purchase queued and try again.
 * - `internal`   our own misconfiguration. Also retryable from the client's
 *                point of view, but worth alerting on.
 */
export type FailureKind = "invalid" | "retryable" | "internal";

export class VerificationFailure extends Error {
  constructor(readonly kind: FailureKind, message: string) {
    super(message);
    this.name = "VerificationFailure";
  }
}

/** A purchase the store has confirmed to us as real and paid for. */
export interface VerifiedPurchase {
  readonly platform: Platform;
  /** Globally unique store transaction id. This is the ledger key. */
  readonly transactionId: string;
  readonly productId: string;
  readonly purchasedAtMs: number | null;
  /** Play-only marker for tester / promo / rewarded orders. */
  readonly purchaseType: number | null;
}
