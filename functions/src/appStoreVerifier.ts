import {X509Certificate, verify as verifySignature} from "node:crypto";
import {APPLE_ROOT_CA_G3_PEM} from "./appleRootCA";
import {ANDROID_PACKAGE_NAME} from "./catalog";
import {VerificationFailure, VerifiedPurchase} from "./types";

/** iOS and Android share one application id. */
const IOS_BUNDLE_ID = ANDROID_PACKAGE_NAME;

/**
 * Marker extensions Apple puts on the certificates that sign App Store data.
 * Checking them is what stops any other Apple-issued certificate (a
 * developer's own, say) from signing a "transaction" that chains to the same
 * root.
 */
const LEAF_MARKER_OID = "1.2.840.113635.100.6.11.1";
const INTERMEDIATE_MARKER_OID = "1.2.840.113635.100.6.2.1";

/** The fields of a StoreKit 2 JWSTransaction this function relies on. */
interface SignedTransactionPayload {
  transactionId?: string;
  originalTransactionId?: string;
  bundleId?: string;
  productId?: string;
  purchaseDate?: number;
  signedDate?: number;
  revocationDate?: number;
  environment?: string;
}

/** DER encoding of an object identifier, tag and length included. */
function oidDer(oid: string): Buffer {
  const arcs = oid.split(".").map(Number);
  const body: number[] = [arcs[0] * 40 + arcs[1]];
  for (const arc of arcs.slice(2)) {
    const digits = [arc & 0x7f];
    let rest = Math.floor(arc / 128);
    while (rest > 0) {
      digits.unshift((rest & 0x7f) | 0x80);
      rest = Math.floor(rest / 128);
    }
    body.push(...digits);
  }
  return Buffer.from([0x06, body.length, ...body]);
}

function hasExtension(cert: X509Certificate, oid: string): boolean {
  return cert.raw.includes(oidDer(oid));
}

function validAt(cert: X509Certificate, atMs: number): boolean {
  return Date.parse(cert.validFrom) <= atMs && atMs <= Date.parse(cert.validTo);
}

/**
 * A check of Apple's signature failed. Reported as `internal`, not `invalid`:
 * the client keeps an internal failure queued and retries, so a mistake here
 * can never make a player lose gold they paid for. A forged transaction just
 * retries forever and is never credited.
 */
function untrusted(message: string): VerificationFailure {
  return new VerificationFailure("internal", message);
}

/**
 * Verifies a StoreKit 2 signed transaction (JWS) and confirms it is a real
 * App Store purchase of [productId] for this app.
 *
 * With StoreKit 2, which the in_app_purchase plugin uses on every device the
 * app supports (iOS 15+), the purchase's `serverVerificationData` is this JWS,
 * not a legacy app receipt, so Apple's old verifyReceipt endpoint cannot read
 * it. The JWS carries its own certificate chain; it is trusted only if that
 * chain ends at Apple Root CA - G3, each certificate carries Apple's App Store
 * marker, and the signature over the payload checks out.
 *
 * [roots] is for tests; production always uses Apple's root.
 */
export function verifyAppStoreTransaction(args: {
  productId: string;
  transactionId: string | null;
  signedTransaction: string;
  roots?: string[];
}): VerifiedPurchase {
  const parts = args.signedTransaction.split(".");
  if (parts.length !== 3) {
    throw untrusted("The App Store transaction is not a signed JWS.");
  }
  const [headerPart, payloadPart, signaturePart] = parts;

  let header: {alg?: string; x5c?: string[]};
  let payload: SignedTransactionPayload;
  try {
    header = JSON.parse(Buffer.from(headerPart, "base64url").toString("utf8"));
    payload = JSON.parse(Buffer.from(payloadPart, "base64url").toString("utf8"));
  } catch (_) {
    throw untrusted("The App Store transaction could not be decoded.");
  }

  if (header.alg !== "ES256" || !Array.isArray(header.x5c) || header.x5c.length !== 3) {
    throw untrusted("The App Store transaction has an unexpected signature header.");
  }

  let leaf: X509Certificate;
  let intermediate: X509Certificate;
  let presentedRoot: X509Certificate;
  try {
    [leaf, intermediate, presentedRoot] = header.x5c.map(
      (der) => new X509Certificate(Buffer.from(der, "base64"))
    );
  } catch (_) {
    throw untrusted("The App Store transaction's certificates could not be read.");
  }

  const trusted = (args.roots ?? [APPLE_ROOT_CA_G3_PEM]).map(
    (pem) => new X509Certificate(pem)
  );
  const root = trusted.find((candidate) => candidate.fingerprint256 === presentedRoot.fingerprint256);
  if (!root) {
    throw untrusted("The App Store transaction does not chain to Apple's root.");
  }

  // Certificates are checked as of when Apple signed the transaction, so an
  // old purchase still verifies after its signing certificate has expired.
  const at = typeof payload.signedDate === "number" ? payload.signedDate : Date.now();
  const chainOk =
    intermediate.checkIssued(root) && intermediate.verify(root.publicKey) &&
    leaf.checkIssued(intermediate) && leaf.verify(intermediate.publicKey) &&
    validAt(intermediate, at) && validAt(leaf, at) &&
    hasExtension(intermediate, INTERMEDIATE_MARKER_OID) &&
    hasExtension(leaf, LEAF_MARKER_OID);
  if (!chainOk) {
    throw untrusted("The App Store transaction's certificate chain is not Apple's.");
  }

  const signatureOk = verifySignature(
    "sha256",
    Buffer.from(`${headerPart}.${payloadPart}`),
    {key: leaf.publicKey, dsaEncoding: "ieee-p1363"},
    Buffer.from(signaturePart, "base64url")
  );
  if (!signatureOk) {
    throw untrusted("The App Store transaction's signature does not match.");
  }

  // From here the payload is Apple's word; a mismatch is a definite no.
  if (payload.bundleId !== IOS_BUNDLE_ID) {
    throw new VerificationFailure("invalid", "This transaction belongs to a different app.");
  }
  if (payload.productId !== args.productId) {
    throw new VerificationFailure("invalid", "This transaction is for a different product.");
  }
  const transactionId = payload.transactionId?.trim();
  if (!transactionId) {
    throw new VerificationFailure("invalid", "This transaction has no transaction id.");
  }
  if (args.transactionId && args.transactionId !== transactionId) {
    throw new VerificationFailure("invalid", "This transaction does not match the claimed purchase.");
  }
  if (payload.revocationDate) {
    throw new VerificationFailure("invalid", "This purchase was refunded or revoked.");
  }

  return {
    platform: "ios",
    transactionId,
    productId: args.productId,
    purchasedAtMs: typeof payload.purchaseDate === "number" ? payload.purchaseDate : null,
    purchaseType: null,
    environment: payload.environment ?? null,
  };
}
