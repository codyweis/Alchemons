// The rules for live races with friends (race_rooms): READY, leaving and
// DECLINE, the host's computer lanes and taking a lane out, and rooms from
// the older game still working.
//
//   firebase emulators:exec --only firestore --project demo-alchemons-race \
//     "node --test functions/test/race_rooms_rules.test.cjs"
const {test, before, after, beforeEach} = require('node:test');
const {readFileSync} = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, setDoc, updateDoc, deleteField, arrayRemove, serverTimestamp} = require('firebase/firestore');

if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Tests require a local Firestore emulator.');

let env;
const id = 'room1';
const seat = (player, extra = {}) => ({player, id: 'inst', entrant: {name: 'Ember', el: 'Fire', fam: 'mane'},
  ratings: {spd: 4, str: 4, int: 4, bea: 4}, boosts: 3, look: {baseId: 'MAN03'}, ...extra});
const as = (uid) => doc(env.authenticatedContext(uid).firestore(), `race_rooms/${id}`);
const update = (uid, data) => updateDoc(as(uid), {...data, updatedAt: serverTimestamp()});

/// Ann hosts; Bo is in with a seat, Cy is asked.
async function seed(extra = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'players/b/friends/a'), {since: 1});
    await setDoc(doc(db, 'players/c/friends/a'), {since: 1});
    await setDoc(doc(db, `race_rooms/${id}`), {
      host: 'a', invited: ['a', 'b', 'c'], names: {a: 'Ann', b: 'Bo', c: 'Cy'},
      cup: 0, race: 0, state: 'lobby', run: 0,
      seats: {a: seat('Ann', {v: 2, at: new Date(0)}), b: seat('Bo', {v: 2, at: new Date(0)})},
      taps: {}, field: [], startAt: null, createdAt: new Date(0), updatedAt: new Date(0),
      ...extra,
    });
  });
}

before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-alchemons-race',
    firestore: {rules: readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8')}});
});
beforeEach(async () => { await env.clearFirestore(); });
after(async () => { await env.cleanup(); });

test('READY: your own, for this run, between races', async () => {
  await seed();
  await assertSucceeds(update('b', {'ready.b': 0}));
  await assertSucceeds(update('b', {'ready.b': deleteField()}));
  await assertFails(update('b', {'ready.b': 1}));
  await assertFails(update('b', {'ready.c': 0}));
  await seed({state: 'racing', run: 1, field: ['a', 'b']});
  await assertFails(update('b', {'ready.b': 1}));
});

test('a seat with the game version on it', async () => {
  await seed();
  await assertSucceeds(update('b', {'seats.b': {...seat('Bo'), v: 2, at: serverTimestamp()}}));
  await assertFails(update('b', {'seats.b': {...seat('Bo'), v: 'two', at: serverTimestamp()}}));
});

test('leaving: off the list, seat and READY gone; only yourself', async () => {
  await seed({ready: {b: 0}});
  await assertFails(update('b', {invited: arrayRemove('c')}));
  await assertFails(update('a', {invited: arrayRemove('a')}));
  await assertSucceeds(update('b', {invited: arrayRemove('b'), 'seats.b': deleteField(), 'ready.b': deleteField()}));
});

test('DECLINE: an asked friend takes themselves off', async () => {
  await seed();
  await assertSucceeds(update('c', {invited: arrayRemove('c')}));
});

test('leaving mid-race keeps the seat for the race', async () => {
  await seed({state: 'racing', run: 1, field: ['a', 'b']});
  await assertFails(update('b', {invited: arrayRemove('b'), 'seats.b': deleteField()}));
  await assertSucceeds(update('b', {invited: arrayRemove('b')}));
  // Back between races, the host clears the seat of the one gone.
  await assertFails(update('a', {'seats.b': deleteField()}));
  await assertSucceeds(update('a', {state: 'lobby', startAt: null, field: [], 'seats.b': deleteField()}));
});

test('the host: computer lanes, and taking a lane out', async () => {
  await seed({ready: {b: 0}});
  await assertSucceeds(update('a', {cpu: 2}));
  await assertSucceeds(update('a', {cpu: 0}));
  await assertFails(update('a', {cpu: 6}));
  await assertFails(update('b', {cpu: 1}));
  // Not the seat of someone still in.
  await assertFails(update('a', {'seats.b': deleteField()}));
  await assertFails(update('a', {'seats.b': seat('Bo', {v: 2, at: serverTimestamp()})}));
  await assertSucceeds(update('a', {invited: arrayRemove('b'), 'seats.b': deleteField(), 'ready.b': deleteField()}));
  await assertSucceeds(update('a', {invited: arrayRemove('c')}));
});

test('the older game: a room with no READY or computer count still runs', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'players/b/friends/a'), {since: 1});
  });
  const fresh = doc(env.authenticatedContext('a').firestore(), 'race_rooms/old');
  await assertSucceeds(setDoc(fresh, {host: 'a', invited: ['a', 'b'], names: {a: 'Ann', b: 'Bo'},
    cup: 0, race: 0, state: 'lobby', run: 0, seats: {}, taps: {}, field: [], startAt: null,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp()}));
  const bo = doc(env.authenticatedContext('b').firestore(), 'race_rooms/old');
  await assertSucceeds(updateDoc(bo, {'seats.b': {...seat('Bo'), at: serverTimestamp()}, updatedAt: serverTimestamp()}));
  // Their old LEAVE: the seat only.
  await assertSucceeds(updateDoc(bo, {'seats.b': deleteField(), updatedAt: serverTimestamp()}));
  await assertSucceeds(updateDoc(fresh, {state: 'racing', run: 1, startAt: 5, field: ['a'], taps: {},
    updatedAt: serverTimestamp()}));
});

test('gem bouts: the host turns the room; each plans only their own route', async () => {
  await seed();
  await assertSucceeds(update('a', {ev: 'gem', cup: 2, race: 0}));
  await assertFails(update('a', {ev: 'chess'}));
  await assertFails(update('b', {ev: 'race'}));
  const plan = (run, r, extra = {}) => ({run, at: 'gem:2:0', r, ...extra});
  await assertSucceeds(update('b', {'ready.b': 0, 'plans.b': plan(0, [1, 0, 1])}));
  await assertFails(update('b', {'plans.c': plan(0, [1])}));
  await assertFails(update('b', {'plans.b': plan(3, [1])}));
  await assertFails(update('b', {'plans.b': plan(0, [1], {x: 1})}));
  await assertFails(update('b', {'plans.b': plan(0, [1, 0, 1, 0, 1, 0, 1, 0, 1])}));
  // The host's own, before START.
  await assertSucceeds(update('a', {'plans.a': plan(0, [0, 0, 0])}));
  // Not mid-race.
  await seed({state: 'racing', run: 1, field: ['a', 'b'], ev: 'gem', cup: 2});
  await assertFails(update('b', {'plans.b': plan(1, [1])}));
  // Taken out between races: the plan goes too.
  await seed({ev: 'gem', cup: 2, ready: {b: 0}, plans: {b: plan(0, [1])}});
  await assertFails(update('a', {'plans.b': deleteField()}));
  await assertSucceeds(update('a', {invited: arrayRemove('b'), 'seats.b': deleteField(),
    'ready.b': deleteField(), 'plans.b': deleteField()}));
});
