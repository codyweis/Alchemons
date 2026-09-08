import {GoogleAuth} from "google-auth-library";
import {ANDROID_PACKAGE_NAME} from "./catalog";
import {VerificationFailure, VerifiedPurchase} from "./types";

const auth = new GoogleAuth({
  scopes: ["https://www.googleapis.com/auth/androidpublisher"],
});

/** Play `purchaseState` value meaning the order completed and was paid for. */
const PURCHASE_STATE_PURCHASED = 0;

interface ProductPurchaseResponse {
  orderId?: string;
  purchaseState?: number;
  purchaseTimeMillis?: string;
  purchaseType?: number;
  regionCode?: string;
}

/**
 * Verifies an Android purchase token against the Play Developer API.
 *
 * The token stays queryable for a while after the client consumes the product,
 * which is what lets the client retry a redeem that failed to reach us.
 */
export async function verifyPlayPurchase(args: {
  productId: string;
  purchaseToken: string;
}): Promise<VerifiedPurchase> {
  const url =
    "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/" +
    `${encodeURIComponent(ANDROID_PACKAGE_NAME)}/purchases/products/` +
    `${encodeURIComponent(args.productId)}/tokens/` +
    `${encodeURIComponent(args.purchaseToken)}`;

  const client = await auth.getClient();
  const token = await client.getAccessToken();
  if (!token.token) {
    throw new VerificationFailure(
      "internal",
      "Could not obtain a Play Developer API access token."
    );
  }

  const response = await fetch(url, {
    headers: {Authorization: `Bearer ${token.token}`},
  });

  if (response.status === 404 || response.status === 400) {
    throw new VerificationFailure(
      "invalid",
      "Google Play does not recognise this purchase."
    );
  }
  if (!response.ok) {
    // 401/403/5xx are our problem or a transient Google problem. Signal the
    // client to retry rather than telling the player their purchase is bad.
    throw new VerificationFailure(
      "retryable",
      `Play Developer API returned ${response.status}.`
    );
  }

  const body = (await response.json()) as ProductPurchaseResponse;

  if (body.purchaseState !== PURCHASE_STATE_PURCHASED) {
    throw new VerificationFailure(
      "invalid",
      "This Google Play purchase is not in a completed state."
    );
  }

  const orderId = body.orderId?.trim();
  if (!orderId) {
    throw new VerificationFailure(
      "invalid",
      "This Google Play purchase has no order id."
    );
  }

  return {
    platform: "android",
    transactionId: orderId,
    productId: args.productId,
    purchasedAtMs: Number(body.purchaseTimeMillis ?? "0") || null,
    // purchaseType is absent for ordinary paid orders, 0 for a license tester,
    // 1 for a promo code and 2 for a rewarded ad. Recorded, not rejected, so
    // that test accounts still work.
    purchaseType: body.purchaseType ?? null,
  };
}
