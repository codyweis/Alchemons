// node solve.js — prove every Blood room. Writes proofs.txt.
const fs = require('fs');
const EE = require('./earth-engine.js');
const WE = require('./water-engine.js');
const HE = require('./hub-engine.js');
const FE = require('./fire-engine.js');
const AE = require('./air-engine.js');
const { HUB, ROOMS } = require('./rites-rooms.js');
const out = [];
const say = (s) => { out.push(s); console.log(s); };

// ── Earth ──
{
  const def = ROOMS.earth, R = EE.parseRoom(def);
  const res = EE.solve(R);
  const good = res.filter((r) => r.solvable === true);
  say(`earth (${def.label}) plates=${R.plates.length} settings=${res.length} solvable-at=${good.map((g) => g.turns.join('')).join(',') || 'none'}`);
  say(`  as it starts: ${res[0].solvable ? 'SOLVABLE (bad)' : 'impossible'}`);
  R.plates.forEach((p, i) => {
    const fixed = R.plates.map((_, j) => (j === i ? 0 : null));
    const any = EE.solve(R, fixed).some((r) => r.solvable === true);
    say(`  without turning plate ${i} (axle ${p.cx},${p.cy}): ${any ? 'solvable' : 'IMPOSSIBLE'}`);
  });
  if (good.length) {
    // Replay: turn the plates, then draw every path square by square.
    let S = EE.start(R), ok = true;
    good[0].turns.forEach((t, i) => { for (let k = 0; k < t; k++) { const r = EE.turn(R, S, i); if (r.why) ok = false; else S = r.S; } });
    for (const [id, pts] of Object.entries(good[0].paths)) {
      for (const [x, y] of pts.slice(1)) { const r = EE.extend(R, S, id, x, y); if (r.why) { ok = false; say(`  REPLAY FAILED ${id} at ${x},${y}: ${r.why}`); break; } S = r.S; }
    }
    say(`  replayed from a fresh start: ${ok && EE.solved(R, S) ? 'solved' : 'FAILED'}`);
    const g = EE.grid(R, good[0].turns);
    for (const [id, pts] of Object.entries(good[0].paths)) for (const [x, y] of pts.slice(1, -1)) g[y][x] = id === 'd' ? '1' : id === 'w' ? '2' : id.toUpperCase();
    say(g.map((r) => '    ' + r.join('')).join('\n'));
  }
}

// ── Water ──
{
  const def = ROOMS.water, R = WE.parseRoom(def);
  const S0 = WE.start(R);
  const still = ![...S0.loose.values()].includes('~') && !S0.cells.flat().includes('f');
  const g = WE.graph(R, 5e5);
  say(`water (${def.label}) start-still=${still} states=${g.states} solvable=${g.solvable} fewest-flips=${g.flips} dead-ends=${(g.dead * 100).toFixed(0)}% blood-holds=${g.held}`);
  let S = S0, ok = true;
  for (const a of g.plan) { const r = a === 'flip' ? WE.flip(R, S) : WE.step(R, S, 'NESW'.indexOf(a)); if (r.why) { ok = false; break; } S = r.S; }
  say(`  replayed from a fresh start: ${ok && WE.solved(R, S) ? 'solved' : 'FAILED'}`);
  say(`  plan: ${g.plan.join(' ')}`);
  const naive = WE.flip(R, S0).S;
  say(`  flip first without thinking: ${WE.solved(R, naive) ? 'solved' : 'not solved'}`);
  // The vault: the shortest way to stand beside a flooded pit (then dive).
  {
    const seen = new Map([[WE.key(S0), null]]);
    let q = [S0], found = null;
    while (q.length && !found) {
      const n = [];
      for (const S of q) {
        for (const m of ['flip', 0, 1, 2, 3]) {
          const r = m === 'flip' ? WE.flip(R, S) : WE.step(R, S, m);
          if (r.why) continue;
          const k = WE.key(r.S);
          if (seen.has(k)) continue;
          seen.set(k, { from: WE.key(S), m });
          if (WE.diveFrom(r.S) >= 0) { found = k; break; }
          n.push(r.S);
        }
        if (found) break;
      }
      q = n;
    }
    const plan = [];
    for (let k = found; k && seen.get(k); k = seen.get(k).from) plan.unshift(seen.get(k).m === 'flip' ? 'flip' : 'NESW'[seen.get(k).m]);
    say(`  the vault (dive into a flooded pit): ${found ? 'reachable in ' + plan.length + ' moves, ' + plan.filter((m) => m === 'flip').length + ' flips: ' + plan.join(' ') : 'UNREACHABLE'}`);
  }
}

// ── Fire ──
{
  const def = ROOMS.fire, R = FE.parseRoom(def);
  const r = FE.solve(R);
  say(`fire (${def.label}) solvable=${r.solvable} states=${r.states} fewest-steps=${r.steps} steps-moving-only-one=${r.single}`);
  const shut = FE.solve(FE.parseRoom({ map: def.map.map((row) => row.replace(/[abc]/g, '#')) }));
  say(`  with every gate shut for good: ${shut.solvable ? 'solvable' : 'IMPOSSIBLE'} (the plates are needed)`);
  const sym = FE.solve(FE.parseRoom({ map: def.map.map((row) => row.replace(/[abc123]/g, '.')) }));
  say(`  with no plates or gates: ${sym.solvable ? 'solvable in ' + sym.steps : 'IMPOSSIBLE'}`);
  let S = FE.start(R), ok = true;
  for (const a of r.plan) { const q = FE.step(R, S, 'NESW'.indexOf(a)); if (q.why) { ok = false; break; } S = q.S; }
  say(`  replayed from a fresh start: ${ok && FE.solved(R, S) ? 'solved' : 'FAILED'}`);
  say(`  plan: ${r.plan.join(' ')}`);
}

// ── Air ──
{
  const def = ROOMS.air, R = AE.parseRoom(def);
  const g = AE.graph(R, 5e5);
  say(`air (${def.label}) needs=${R.need} ice=${R.ice0.length} states=${g.states} solvable=${g.solvable} fewest-pushes=${g.pushes} ice-shoves=${g.shoves} dead-ends=${(g.dead * 100).toFixed(0)}%`);
  let S = AE.start(R), ok = true;
  for (const a of g.plan) { const q = AE.push(R, S, 'NESW'.indexOf(a)); if (q.why) { ok = false; break; } S = q.S; }
  say(`  replayed from a fresh start: ${ok && AE.solved(R, S) ? 'solved' : 'FAILED'}`);
  say(`  plan: ${g.plan.join(' ')}`);
}

// ── Hub ──
{
  const all = { Air: 1, Fire: 1, Earth: 1, Water: 1 };
  const hist = {}, pairs = new Set();
  let quint = [];
  for (let a = 0; a < 8; a++) for (let b = 0; b < 8; b++) {
    const c = HE.centre(HUB, HE.flow(HUB, all, [a, b]));
    hist[c.kind] = (hist[c.kind] || 0) + 1;
    if (c.kind === 'fusion') pairs.add(c.ins.join('+') + '→' + c.result);
    if (c.kind === 'quintessence') quint.push(a + '/' + b);
  }
  const home = HE.centre(HUB, HE.flow(HUB, all, [0, 0]));
  say(`hub: home setting → ${home.kind} (every stream to its socket) · of 64 settings ${JSON.stringify(hist)}`);
  say(`  fusions you can find: ${[...pairs].join(', ')}`);
  say(`  quintessence at (outer/inner): ${quint.join(' ')}`);
}
fs.writeFileSync(__dirname + '/proofs.txt', out.join('\n') + '\n');
