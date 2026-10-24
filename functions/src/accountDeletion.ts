import {getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import * as functionsV1 from "firebase-functions/v1";

/**
 * When a Firebase Auth account is deleted (Profile → DELETE ACCOUNT in the
 * game, or from the console), removes the account documents the client is
 * not allowed to delete itself: its cloud save, its session, its reset
 * bookkeeping and its device transfers. The game clears friends and trades
 * before it deletes the account, since those rules let the owner do it.
 *
 * Purchase records stay. The ledger and the entitlement are what stop one
 * receipt being redeemed twice, and the privacy policy keeps them as long as
 * needed to honor purchases.
 *
 * Auth deletion triggers exist only in the v1 API.
 */
export const deleteAccountData = functionsV1
  .region("us-central1")
  .auth.user()
  .onDelete(async (user) => {
    const db = getFirestore();
    const uid = user.uid;
    const transfers = await db
      .collection("account_transfers")
      .where("uid", "==", uid)
      .get();

    const writer = db.bulkWriter();
    writer.delete(db.doc(`account_cloud_saves/${uid}`));
    writer.delete(db.doc(`account_sessions/${uid}`));
    for (const transfer of transfers.docs) writer.delete(transfer.ref);
    // account_progress keeps its resets in a subcollection.
    await db.recursiveDelete(db.doc(`account_progress/${uid}`), writer);
    await writer.close();

    logger.info("Deleted account data", {uid, transfers: transfers.size});
  });
