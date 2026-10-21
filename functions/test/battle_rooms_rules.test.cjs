// The rules for live battles with a friend (battle_rooms): making a room
// for a friend only, seats and READY between fights, the guest's inputs
// during one, leaving, the host starting and ending fights, and the stream
// written by the host alone while a fight is on.
//
//   firebase emulators:exec --only firestore --project demo-alchemons-battle \
//     "node --test functions/test/battle_rooms_rules.test.cjs"
const {test, before, after, beforeEach} = require('node:test');
const {readFileSync} = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, updateDoc, deleteDoc, deleteField, serverTimestamp} = require('firebase/firestore');

if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Tests require a local Firestore emulator.');

let env;
const id = 'room1';
const member = {id: 'inst', name: 'Ember', el: 'Fire', fam: 'mane', lv: 10, s: [4, 4, 4, 4], p: [50, 50, 50, 50], look: {b: 'MAN03'}};
const seat = (player, extra = {}) => ({player, team: [member, member, member, member], v: 1, ...extra});
const db = (uid) => env.authenticatedContext(uid).firestore();
const room = (uid) => doc(db(uid), `battle_rooms/${id}`);
const slot = (uid, n) => doc(db(uid), `battle_rooms/${id}/stream/${n}`);
const update = (uid, data) => updateDoc(room(uid), {...data, updatedAt: serverTimestamp()});

/// Ann hosts; Bo is asked (and a friend of hers), with both sat.
async function seed(extra = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const fs = ctx.firestore();
    await setDoc(doc(fs, 'players/b/friends/a'), {since: 1});
    await setDoc(doc(fs, `battle_rooms/${id}`), {
      host: 'a', guest: 'b', players: ['a', 'b'], names: {a: 'Ann', b: 'Bo'},
      arena: 'obsidian', state: 'lobby', run: 0,
      seats: {a: seat('Ann', {at: new Date(0)}), b: seat('Bo', {at: new Date(0)})},
      ready: {}, startAt: null, createdAt: new Date(0), updatedAt: new Date(0),
      ...extra,
    });
  });
}

before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-alchemons-battle',
    firestore: {rules: readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8')}});
});
beforeEach(async () => { await env.clearFirestore(); });
after(async () => { await env.cleanup(); });

const fresh = (guest) => ({
  host: 'a', guest, players: guest ? ['a', guest] : ['a'], names: {a: 'Ann'},
  arena: 'obsidian', state: 'lobby', run: 0, seats: {}, ready: {}, startAt: null,
  createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
});

test('a room: by its host, for a friend only, or nobody yet', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'players/b/friends/a'), {since: 1});
  });
  await assertSucceeds(setDoc(doc(db('a'), 'battle_rooms/r1'), fresh('b')));
  await assertSucceeds(setDoc(doc(db('a'), 'battle_rooms/r2'), fresh(null)));
  // Cy is not Ann's friend.
  await assertFails(setDoc(doc(db('a'), 'battle_rooms/r3'), fresh('c')));
  // Not as someone else.
  await assertFails(setDoc(doc(db('b'), 'battle_rooms/r4'), fresh('b')));
  // Read by the two in it, not by others.
  await assertSucceeds(getDoc(doc(db('b'), 'battle_rooms/r1')));
  await assertFails(getDoc(doc(db('c'), 'battle_rooms/r1')));
});

test('the guest: own seat and READY between fights, for this run', async () => {
  await seed();
  await assertSucceeds(update('b', {'seats.b': {...seat('Bo'), at: serverTimestamp()}}));
  await assertFails(update('b', {'seats.a': {...seat('Bo'), at: serverTimestamp()}}));
  await assertFails(update('b', {'seats.b': {...seat('Bo'), team: [], at: serverTimestamp()}}));
  await assertSucceeds(update('b', {'ready.b': 0}));
  await assertFails(update('b', {'ready.b': 1}));
  await assertFails(update('b', {state: 'fighting', run: 1}));
  await seed({state: 'fighting', run: 1});
  await assertFails(update('b', {'ready.b': 1}));
  await assertFails(update('b', {'seats.b': {...seat('Bo'), at: serverTimestamp()}}));
});

test('the guest\'s inputs: during a fight, for that fight', async () => {
  await seed({state: 'fighting', run: 1});
  await assertSucceeds(update('b', {inputs: {run: 1, b: 1, l: [0, 2, -1]}}));
  await assertFails(update('b', {inputs: {run: 0, b: 2, l: [0, 2, -1]}}));
  await assertFails(update('b', {inputs: {run: 1, b: 2, l: Array(181).fill(0)}}));
  await assertFails(update('a', {inputs: {run: 1, b: 2, l: [0, 1, -1]}}));
  await seed();
  await assertFails(update('b', {inputs: {run: 0, b: 1, l: []}}));
});

test('leaving: the guest goes; mid-fight their seat stays for the host', async () => {
  await seed({ready: {b: 0}});
  await assertSucceeds(update('b', {guest: null, players: ['a'], 'seats.b': deleteField(), 'ready.b': deleteField()}));
  await seed({state: 'fighting', run: 1});
  await assertFails(update('b', {guest: null, players: ['a'], 'seats.b': deleteField()}));
  await assertSucceeds(update('b', {guest: null, players: ['a']}));
  // Back between fights, the host clears the seat of the one gone.
  await assertSucceeds(update('a', {state: 'lobby', startAt: null, result: {run: 1, w: 'a', end: 2}, 'seats.b': deleteField()}));
});

test('the host: start, end, the arena; not the guest\'s seat', async () => {
  await seed({ready: {b: 0}});
  await assertSucceeds(update('a', {arena: 'orrery'}));
  await assertFails(update('a', {'seats.b': {...seat('Mallory'), at: serverTimestamp()}}));
  await assertFails(update('a', {'ready.b': 0}));
  await assertFails(update('a', {state: 'fighting', run: 5, startAt: 1}));
  await assertSucceeds(update('a', {state: 'fighting', run: 1, startAt: 12345, inputs: deleteField()}));
  await seed({state: 'fighting', run: 1});
  await assertFails(update('a', {state: 'lobby', run: 2}));
  await assertSucceeds(update('a', {state: 'lobby', startAt: null, result: {run: 1, w: 'b', end: 0}}));
});

test('the host: asking a friend in while nobody is, taking them out', async () => {
  await seed();
  await assertSucceeds(update('a', {guest: null, players: ['a'], 'seats.b': deleteField()}));
  await assertSucceeds(update('a', {guest: 'b', players: ['a', 'b'], 'names.b': 'Bo'}));
  await seed({guest: null, players: ['a'], seats: {a: seat('Ann', {at: new Date(0)})}});
  await assertFails(update('a', {guest: 'c', players: ['a', 'c']}));
});

test('the stream: the host, while a fight is on, for that fight', async () => {
  await seed({state: 'fighting', run: 1});
  await assertSucceeds(setDoc(slot('a', 0), {run: 1, seq: 0, p: [1, 0, 0]}));
  await assertSucceeds(setDoc(slot('a', 7), {run: 1, seq: 7, p: [1, 0, 0]}));
  await assertFails(setDoc(slot('a', 8), {run: 1, seq: 8, p: [1, 0, 0]}));
  await assertFails(setDoc(slot('a', 1), {run: 2, seq: 1, p: [1, 0, 0]}));
  await assertFails(setDoc(slot('a', 1), {run: 1, seq: 1, p: [1], extra: true}));
  await assertFails(setDoc(slot('b', 1), {run: 1, seq: 1, p: [1, 0, 0]}));
  await assertSucceeds(getDoc(slot('b', 0)));
  await assertFails(getDoc(slot('c', 0)));
  await assertSucceeds(deleteDoc(slot('a', 0)));
  await seed();
  await assertFails(setDoc(slot('a', 2), {run: 0, seq: 2, p: [1, 0, 0]}));
});
