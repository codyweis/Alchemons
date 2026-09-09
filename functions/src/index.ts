import {initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {logger} from "firebase-functions";

import {goldPackFor} from "./catalog";
import {verifyAppStorePurchase} from "./appStoreVerifier";
import {verifyPlayPurchase} from "./playVerifier";
import {VerificationFailure, VerifiedPurchase} from "./types";

initializeApp();

export {previewProgressReset, beginProgressReset, finishProgressReset} from "./resetProgress";

const appStoreSharedSecret = defineSecret("APP_STORE_SHARED_SECRET");

interface RedeemRequest {
  platform?: unknown;
  productId?: unknown;
  transactionId?: unknown;
  verificationData?: unknown;
}

function requireString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `Missing "${field}".`);
  }
  return value.trim();
}

function toHttpsError(error: unknown): HttpsError {
  if (error instanceof HttpsError) return error;
  if (error instanceof VerificationFailure) {
    switch (error.kind) {
      case "invalid":
        return new HttpsError("failed-precondition", error.message);
      case "retryable":
        return new HttpsError("unavailable", error.message);
      case "internal":
        return new HttpsError("internal", error.message);
    }
  }
  logger.error("Unexpected redeemPurchase failure", error);
  return new HttpsError("internal", "Purchase verification failed.");
}

/**
 * Verifies a store receipt and records it in the purchase ledger.
 *
 * The ledger document id is the store's own transaction id, and the write is a
 * create rather than a set, so a given receipt can be redeemed exactly once, by
 * exactly one account, forever. That is what stops the same purchase from being
 * credited to a pile of accounts.
 *
 * The gold amount comes from the server catalog. The client only ever names a
 * product; it never names a price.
 */
export const redeemPurchase = onCall(
  {secrets: [appStoreSharedSecret], region: "us-central1"},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in before redeeming.");
    }

    const data = (request.data ?? {}) as RedeemRequest;
    const platform = requireString(data.platform, "platform");
    const productId = requireString(data.productId, "productId");
    const verificationData = requireString(
      data.verificationData,
      "verificationData"
    );

    const pack = goldPackFor(productId);
    if (!pack) {
      throw new HttpsError("invalid-argument", `Unknown product ${productId}.`);
    }

    let verified: VerifiedPurchase;
    try {
      if (platform === "android") {
        verified = await verifyPlayPurchase({
          productId,
          purchaseToken: verificationData,
        });
      } else if (platform === "ios") {
        const secret = appStoreSharedSecret.value();
        if (!secret) {
          throw new VerificationFailure(
            "internal",
            "APP_STORE_SHARED_SECRET is not configured."
          );
        }
        verified = await verifyAppStorePurchase({
          productId,
          transactionId: requireString(data.transactionId, "transactionId"),
          receiptData: verificationData,
          sharedSecret: secret,
        });
      } else {
        throw new HttpsError(
          "invalid-argument",
          `Unsupported platform ${platform}.`
        );
      }
    } catch (error) {
      throw toHttpsError(error);
    }

    const db = getFirestore();
    const ledgerId = `${verified.platform}_${verified.transactionId}`;
    const purchaseRef = db.collection("purchases").doc(ledgerId);
    const entitlementRef = db.collection("entitlements").doc(uid);

    const redemption = await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(purchaseRef);
      const progress = await transaction.get(db.doc(`account_progress/${uid}`));
      const generation = progress.get("generation") ?? 0;
      if (progress.get("resetPending")) {
        throw new HttpsError("unavailable", "Finish the account reset before delivering purchases.");
      }

      if (existing.exists) {
        const ownerUid = existing.get("uid");
        if (ownerUid !== uid) {
          logger.warn("Rejected cross-account redeem", {
            ledgerId,
            ownerUid,
            attemptedBy: uid,
          });
          throw new HttpsError(
            "permission-denied",
            "This purchase has already been redeemed on another account."
          );
        }
        // Same account retrying, most likely because our response to the first
        // attempt never made it back. The entitlement is already recorded.
        return {firstRedeem: false, includedInReset: (existing.get("generation") ?? 0) < generation};
      }

      transaction.create(purchaseRef, {
        uid,
        generation,
        platform: verified.platform,
        productId: verified.productId,
        transactionId: verified.transactionId,
        goldAmount: pack.goldAmount,
        purchaseType: verified.purchaseType,
        purchasedAtMs: verified.purchasedAtMs,
        redeemedAt: FieldValue.serverTimestamp(),
      });

      transaction.set(
        entitlementRef,
        {
          uid,
          purchasedGoldTotal: FieldValue.increment(pack.goldAmount),
          purchasedGoldOutstanding: FieldValue.increment(pack.goldAmount),
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true}
      );

      return {firstRedeem: true, includedInReset: false};
    });

    logger.info("Redeemed purchase", {uid, ledgerId, ...redemption});

    return {
      goldAmount: pack.goldAmount,
      transactionId: verified.transactionId,
      ledgerId,
      ...redemption,
    };
  }
);
