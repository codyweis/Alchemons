import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {gunzipSync} from "node:zlib";

function identity(request: {auth?: {uid: string}; data: any}) {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const {deviceId, operationId} = request.data ?? {};
  if (typeof deviceId !== "string" || !deviceId.length) {
    throw new HttpsError("invalid-argument", "Missing device identity.");
  }
  return {uid: request.auth.uid, deviceId, operationId};
}

export const previewProgressReset = onCall(async (request) => {
  const {uid, deviceId} = identity(request);
  const db = getFirestore();
  return db.runTransaction(async (tx) => {
    const session = await tx.get(db.doc(`account_sessions/${uid}`));
    const progress = await tx.get(db.doc(`account_progress/${uid}`));
    const entitlement = await tx.get(db.doc(`entitlements/${uid}`));
    if (session.get("activeDeviceId") !== deviceId || session.get("status") !== "active") {
      throw new HttpsError("failed-precondition", "Use the active device and finish any pending transfer first.");
    }
    if (progress.get("resetPending")) {
      throw new HttpsError("failed-precondition", "Finish the pending reset first.");
    }
    return {generation: progress.get("generation") ?? 0,
      goldAmount: entitlement.get("purchasedGoldTotal") ?? 0};
  });
});

export const beginProgressReset = onCall(async (request) => {
  const {uid, deviceId, operationId} = identity(request);
  if (typeof operationId !== "string" || !/^[a-zA-Z0-9_-]{16,100}$/.test(operationId)) {
    throw new HttpsError("invalid-argument", "Invalid reset operation.");
  }
  const db = getFirestore();
  const ref = db.doc(`account_progress/${uid}`);
  const opRef = ref.collection("resets").doc(operationId);
  return db.runTransaction(async (tx) => {
    const op = await tx.get(opRef);
    const progress = await tx.get(ref);
    const session = await tx.get(db.doc(`account_sessions/${uid}`));
    const entitlement = await tx.get(db.doc(`entitlements/${uid}`));
    if (op.exists) {
      if (op.get("deviceId") !== deviceId || progress.get("operationId") !== operationId) {
        throw new HttpsError("failed-precondition", "This reset has been superseded. Restore the latest account backup.");
      }
      return op.data();
    }
    if (session.get("activeDeviceId") !== deviceId || session.get("status") !== "active" || progress.get("resetPending")) {
      throw new HttpsError("failed-precondition", "Use the active device and finish any pending transfer or reset first.");
    }
    const generation = progress.get("generation") ?? 0;
    const goldAmount = entitlement.get("purchasedGoldTotal") ?? 0;
    if (generation !== request.data.generation || goldAmount !== request.data.goldAmount) {
      throw new HttpsError("failed-precondition", "Your save or purchases changed. Review the reset amount again.");
    }
    const result = {operationId, deviceId, generation: generation + 1, goldAmount};
    tx.create(opRef, result);
    tx.set(ref, {...result, resetPending: true, updatedAt: FieldValue.serverTimestamp()});
    tx.delete(db.doc(`account_cloud_saves/${uid}`));
    tx.set(db.doc(`account_sessions/${uid}`), {generation: generation + 1}, {merge: true});
    return result;
  });
});

export const finishProgressReset = onCall(async (request) => {
  const {uid, deviceId, operationId} = identity(request);
  const saveCode = request.data?.saveCode;
  let payload;
  try {
    if (typeof saveCode !== "string" || !saveCode.startsWith("ALCHEMONS_SAVE_V2:") || Buffer.byteLength(saveCode) > 900 * 1024) throw Error();
    payload = JSON.parse(gunzipSync(Buffer.from(saveCode.slice("ALCHEMONS_SAVE_V2:".length), "base64url"), {maxOutputLength: 16 * 1024 * 1024}).toString("utf8"));
  } catch (_) {
    throw new HttpsError("invalid-argument", "Invalid fresh save.");
  }
  const db = getFirestore();
  return db.runTransaction(async (tx) => {
    const ref = db.doc(`account_progress/${uid}`);
    const progress = await tx.get(ref);
    if (progress.get("operationId") !== operationId || progress.get("deviceId") !== deviceId) {
      throw new HttpsError("failed-precondition", "This reset is no longer current.");
    }
    if (payload.ownerAccountId !== uid || payload.generation !== progress.get("generation")) {
      throw new HttpsError("failed-precondition", "The fresh save does not match this reset.");
    }
    // A lost success response must never overwrite subsequent gameplay backups.
    if (!progress.get("resetPending")) return {complete: true};
    tx.set(db.doc(`account_cloud_saves/${uid}`), {
      uid, sourceDeviceId: deviceId, saveCode, generation: payload.generation,
      revision: 1, updatedAt: FieldValue.serverTimestamp(),
    });
    tx.update(ref, {resetPending: false, updatedAt: FieldValue.serverTimestamp()});
    return {complete: true};
  });
});
