import {ANDROID_PACKAGE_NAME} from "./catalog";
import {
  FailureKind,
  VerificationFailure,
  VerifiedPurchase,
} from "./types";

const PRODUCTION_URL = "https://buy.itunes.apple.com/verifyReceipt";
const SANDBOX_URL = "https://sandbox.itunes.apple.com/verifyReceipt";

/** iOS and Android share one application id. */
const IOS_BUNDLE_ID = ANDROID_PACKAGE_NAME;

/** Apple's "this is a sandbox receipt, ask the sandbox instead" status. */
const STATUS_SANDBOX_RECEIPT = 21007;

interface InAppEntry {
  product_id?: string;
  transaction_id?: string;
  original_transaction_id?: string;
  purchase_date_ms?: string;
}

interface VerifyReceiptResponse {
  status?: number;
  receipt?: {
    bundle_id?: string;
    in_app?: InAppEntry[];
  };
}

/**
 * Maps an Apple status code to how the client should treat it.
 *
 * The distinction that matters: a status caused by *our* misconfiguration must
 * never come back as `invalid`, because the client drops an invalid purchase
 * from its queue and the player silently loses gold they paid for. A wrong or
 * unset shared secret (21004) is the obvious way to get this wrong.
 */
function failureKindForStatus(status: number | undefined): FailureKind {
  switch (status) {
    case 21000: // We sent malformed JSON.
    case 21004: // Shared secret does not match the one on file.
      return "internal";
    case 21005: // Receipt server is temporarily unavailable.
    case 21009: // Internal data access error.
      return "retryable";
    default:
      // 21002 malformed receipt, 21003 not authenticated, 21008 production
      // receipt sent to sandbox, 21010 account not found, and anything new.
      return "invalid";
  }
}

async function postReceipt(
  url: string,
  receiptData: string,
  sharedSecret: string
): Promise<VerifyReceiptResponse> {
  let response: Response;
  try {
    response = await fetch(url, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({
        "receipt-data": receiptData,
        "password": sharedSecret,
        "exclude-old-transactions": false,
      }),
    });
  } catch (error) {
    throw new VerificationFailure(
      "retryable",
      `Could not reach the App Store: ${error}`
    );
  }

  if (!response.ok) {
    throw new VerificationFailure(
      "retryable",
      `App Store verifyReceipt returned ${response.status}.`
    );
  }
  return (await response.json()) as VerifyReceiptResponse;
}

/**
 * Verifies a StoreKit receipt and confirms it contains [transactionId] for
 * [productId].
 *
 * The client tells us which transaction it is claiming; we only accept it if
 * Apple's copy of the receipt actually contains that transaction. That keeps
 * the ledger key bound to something the store confirmed rather than to
 * whatever the client typed.
 */
export async function verifyAppStorePurchase(args: {
  productId: string;
  transactionId: string;
  receiptData: string;
  sharedSecret: string;
}): Promise<VerifiedPurchase> {
  let body = await postReceipt(
    PRODUCTION_URL,
    args.receiptData,
    args.sharedSecret
  );
  if (body.status === STATUS_SANDBOX_RECEIPT) {
    body = await postReceipt(SANDBOX_URL, args.receiptData, args.sharedSecret);
  }

  if (body.status !== 0) {
    throw new VerificationFailure(
      failureKindForStatus(body.status),
      `App Store rejected this receipt (status ${body.status ?? "unknown"}).`
    );
  }

  if (body.receipt?.bundle_id !== IOS_BUNDLE_ID) {
    throw new VerificationFailure(
      "invalid",
      "This receipt belongs to a different app."
    );
  }

  const entry = (body.receipt?.in_app ?? []).find(
    (candidate) =>
      candidate.product_id === args.productId &&
      candidate.transaction_id === args.transactionId
  );
  if (!entry?.transaction_id) {
    throw new VerificationFailure(
      "invalid",
      "This receipt does not contain the claimed transaction."
    );
  }

  return {
    platform: "ios",
    transactionId: entry.transaction_id,
    productId: args.productId,
    purchasedAtMs: Number(entry.purchase_date_ms ?? "0") || null,
    purchaseType: null,
  };
}
