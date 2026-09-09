const {test, before, after, beforeEach} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {gzipSync} = require('node:zlib');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, setDoc, updateDoc, serverTimestamp} = require('firebase/firestore');
const {getFirestore} = require('firebase-admin/firestore');

if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Tests require a local Firestore emulator.');
process.env.GCLOUD_PROJECT = 'demo-alchemons-reset';
const {previewProgressReset, beginProgressReset, finishProgressReset, redeemPurchase} = require('../lib/index');
let env;
const db = getFirestore();
const uid = 'buyer';
const deviceId = 'device';
const operationId = 'reset_operation_0001';
const request = (data = {}, user = uid) => ({auth: {uid: user}, data: {deviceId, ...data}});
const begin = (data = {}) => beginProgressReset.run(request({operationId, generation: 0, goldAmount: 1000, ...data}));
const freshSave = (generation = 1, ownerAccountId = uid) => 'ALCHEMONS_SAVE_V2:' + gzipSync(JSON.stringify({
  ownerAccountId, generation, tables: {}, preferences: {},
})).toString('base64url');
const session = (generation = 0) => ({activeDeviceId: deviceId, generation, activeEmail: null,
  activeDisplayName: null, status: 'active', pendingTransferId: null, updatedAt: serverTimestamp()});

before(async () => {
  env = await initializeTestEnvironment({projectId: process.env.GCLOUD_PROJECT,
    firestore: {rules: readFileSync(require('node:path').join(__dirname, '../../firestore.rules'), 'utf8')}});
});
beforeEach(async () => {
  await env.clearFirestore();
  await db.doc(`account_sessions/${uid}`).set({activeDeviceId: deviceId, status: 'active'});
  await db.doc(`entitlements/${uid}`).set({purchasedGoldTotal: 1000});
  await db.doc(`account_cloud_saves/${uid}`).set({saveCode: 'old'});
});
after(async () => { await env.cleanup(); await db.terminate(); });

test('preview uses verified lifetime total; reset retires backup exactly once', async () => {
  assert.deepEqual(await previewProgressReset.run(request()), {generation: 0, goldAmount: 1000});
  const result = await begin();
  assert.equal(result.generation, 1);
  assert.equal(result.goldAmount, 1000);
  assert.equal((await db.doc(`account_cloud_saves/${uid}`).get()).exists, false);
  assert.deepEqual(await begin(), result);
  assert.equal((await db.doc(`account_progress/${uid}`).get()).get('generation'), 1);
  assert.equal((await db.doc(`entitlements/${uid}`).get()).get('purchasedGoldTotal'), 1000);
});

test('rejects inactive devices, pending transfers, stale quotes and missing auth', async () => {
  await assert.rejects(begin({deviceId: 'other'}), {code: 'failed-precondition'});
  await assert.rejects(begin({goldAmount: 999}), {code: 'failed-precondition'});
  await assert.rejects(beginProgressReset.run({data: {deviceId}}), {code: 'unauthenticated'});
  await db.doc(`account_sessions/${uid}`).update({status: 'transfer_pending'});
  await assert.rejects(begin(), {code: 'failed-precondition'});
  assert.equal((await db.doc(`account_cloud_saves/${uid}`).get()).get('saveCode'), 'old');
});

test('finish is retryable and never overwrites a later gameplay backup', async () => {
  await begin();
  await assert.rejects(finishProgressReset.run(request({operationId, saveCode: freshSave(0)})), {code: 'failed-precondition'});
  await assert.rejects(finishProgressReset.run(request({operationId, saveCode: freshSave(1, 'other')})), {code: 'failed-precondition'});
  const data = request({operationId, saveCode: freshSave()});
  await finishProgressReset.run(data);
  await db.doc(`account_cloud_saves/${uid}`).update({saveCode: 'later gameplay'});
  await finishProgressReset.run(data);
  assert.equal((await db.doc(`account_cloud_saves/${uid}`).get()).get('saveCode'), 'later gameplay');
  assert.equal((await db.doc(`account_progress/${uid}`).get()).get('resetPending'), false);
});

test('concurrent reset attempts permit one new generation', async () => {
  const results = await Promise.allSettled([begin(), begin({operationId: 'reset_operation_0002'})]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal((await db.doc(`account_progress/${uid}`).get()).get('generation'), 1);
});

test('another full reset restores the same total, not a cumulative grant', async () => {
  await begin();
  await finishProgressReset.run(request({operationId, saveCode: freshSave()}));
  const result = await begin({operationId: 'reset_operation_0002', generation: 1});
  assert.equal(result.goldAmount, 1000);
  assert.equal(result.generation, 2);
  await assert.rejects(begin(), {code: 'failed-precondition'});
});

test('rules block progress writes, stale backups, activations and transfer codes', async () => {
  const client = env.authenticatedContext(uid).firestore();
  await assertFails(setDoc(doc(client, `account_progress/${uid}`), {generation: 7, resetPending: false}));
  await begin();
  const backup = generation => ({uid, sourceDeviceId: deviceId, saveCode: freshSave(generation), generation, revision: 1, updatedAt: serverTimestamp()});
  // Even the new generation cannot be written by clients until reset finishes.
  await assertFails(setDoc(doc(client, `account_cloud_saves/${uid}`), backup(1)));
  await finishProgressReset.run(request({operationId, saveCode: freshSave()}));
  await assertFails(setDoc(doc(client, `account_cloud_saves/${uid}`), backup(0)));
  await assertSucceeds(setDoc(doc(client, `account_cloud_saves/${uid}`), backup(1)));
  await assertFails(setDoc(doc(client, `account_sessions/${uid}`), session(0)));
  await assertSucceeds(setDoc(doc(client, `account_sessions/${uid}`), session(1)));
  await db.doc('account_transfers/old').set({uid, generation: 0, sourceDeviceId: deviceId,
    status: 'open', targetDeviceId: null, consumedAt: null, cancelledAt: null, createdAt: new Date()});
  await assertFails(updateDoc(doc(client, 'account_transfers/old'), {
    status: 'consumed', targetDeviceId: 'new-device', consumedAt: serverTimestamp(),
  }));
  await assertSucceeds(setDoc(doc(client, 'account_transfers/current'), {
    uid, generation: 1, sourceDeviceId: deviceId, status: 'open',
    targetDeviceId: null, consumedAt: null, cancelledAt: null, createdAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(doc(client, 'account_transfers/current'), {
    status: 'consumed', targetDeviceId: 'new-device', consumedAt: serverTimestamp(),
  }));
  const other = env.authenticatedContext('other').firestore();
  await assertFails(setDoc(doc(other, `account_cloud_saves/${uid}`), backup(1)));
});

test('generation-zero legacy clients work until first reset', async () => {
  const client = env.authenticatedContext(uid).firestore();
  const legacy = session(); delete legacy.generation;
  await assertSucceeds(setDoc(doc(client, `account_sessions/${uid}`), legacy));
  await begin();
  await finishProgressReset.run(request({operationId, saveCode: freshSave()}));
  await assertFails(setDoc(doc(client, `account_sessions/${uid}`), legacy));
});

test('verified receipt replay after reset is included, while a new receipt grants once', async () => {
  const verifier = require('../lib/playVerifier');
  const original = verifier.verifyPlayPurchase;
  // Only the external store boundary is stubbed; the callable and ledger
  // transactions execute against the emulator exactly as deployed.
  verifier.verifyPlayPurchase = async ({productId, purchaseToken}) => ({
    platform: 'android', transactionId: purchaseToken, productId,
    purchasedAtMs: 1, purchaseType: 0,
  });
  const receipt = token => request({platform: 'android', productId: 'alchemons_gold_cache', verificationData: token});
  try {
    const first = await redeemPurchase.run(receipt('old-receipt'));
    assert.equal(first.firstRedeem, true);
    assert.equal(first.includedInReset, false);
    await begin({goldAmount: 1025});
    await assert.rejects(redeemPurchase.run(receipt('new-receipt')), {code: 'unavailable'});
    await finishProgressReset.run(request({operationId, saveCode: freshSave()}));
    const replay = await redeemPurchase.run(receipt('old-receipt'));
    assert.equal(replay.firstRedeem, false);
    assert.equal(replay.includedInReset, true);
    const next = await redeemPurchase.run(receipt('new-receipt'));
    assert.equal(next.firstRedeem, true);
    assert.equal(next.includedInReset, false);
    const duplicate = await redeemPurchase.run(receipt('new-receipt'));
    assert.equal(duplicate.firstRedeem, false);
    assert.equal(duplicate.includedInReset, false);
    assert.equal((await db.doc(`entitlements/${uid}`).get()).get('purchasedGoldTotal'), 1050);
    const wrongAccount = receipt('old-receipt'); wrongAccount.auth.uid = 'other';
    await assert.rejects(redeemPurchase.run(wrongAccount), {code: 'permission-denied'});
  } finally {
    verifier.verifyPlayPurchase = original;
  }
});
