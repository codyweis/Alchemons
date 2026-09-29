// Search for a hard final room: every tool necessary, long, with traps.
const E = require('./shadow-engine.js');
const fs = require('fs');
let seed = +(process.argv[2] || 1);
const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
const pick = (a) => a[Math.floor(rnd() * a.length)];
const LIMIT = 500000;

function candidate() {
  const rows = 7, cols = 11;
  const m = [];
  for (let y = 0; y < rows; y++) {
    const r = [];
    for (let x = 0; x < cols; x++) r.push(x <= 2 ? '.' : x <= 7 ? '~' : x === 8 ? '.' : 'G');
    m.push(r);
  }
  for (let y = 0; y < 6; y++) m[y][0] = 'n';
  m[6][0] = 'C';
  // A fixed starlight on the far wall.
  const fy = Math.floor(rnd() * rows);
  m[fy][10] = pick(['L', 'W', 'W']);
  // Pillars in the glass.
  const np = Math.floor(rnd() * 3);
  for (let i = 0; i < np; i++) m[1 + Math.floor(rnd() * 5)][3 + Math.floor(rnd() * 5)] = 'P';
  // Walls: a few, anywhere but the rail, crank and goal.
  const nw = Math.floor(rnd() * 4);
  for (let i = 0; i < nw; i++) {
    const x = 1 + Math.floor(rnd() * 8), y = Math.floor(rnd() * rows);
    if (m[y][x] === '.' || m[y][x] === '~') m[y][x] = '#';
  }
  // A vent on the near ledge; a one-way pipe from the near ledge to the far.
  const free = (xs) => { for (let t = 0; t < 40; t++) { const x = pick(xs), y = Math.floor(rnd() * rows); if (m[y][x] === '.') return [x, y]; } return null; };
  const v = free([1, 2]); if (!v) return null; m[v[1]][v[0]] = 'V';
  const pa = free([1, 2]); const pb = free([8]); if (!pa || !pb) return null;
  m[pa[1]][pa[0]] = 'p'; m[pb[1]][pb[0]] = 'p';
  // Start squares on the near ledge.
  const starts = [];
  for (let t = 0; t < 60 && starts.length < 3; t++) {
    const x = pick([1, 2]), y = Math.floor(rnd() * rows);
    if (m[y][x] === '.' && !starts.some(s => s.x === x && s.y === y)) starts.push({ x, y });
  }
  if (starts.length < 3) return null;
  return {
    name: 'gen', map: m.map(r => r.join('')),
    rail: [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4], [0, 5]], railStart: Math.floor(rnd() * 6),
    pipes: [[pa, pb]], pins: 1, cone: 0.7,
    start: { Light: starts[0], Dark: starts[1], Steam: starts[2] },
  };
}

const out = [];
const fail = {};
const F = (k) => { fail[k] = (fail[k] || 0) + 1; };
const t0 = Date.now();
const budget = +(process.argv[3] || 600) * 1000;
let tried = 0;
while (Date.now() - t0 < budget) {
  const def = candidate(); if (!def) continue;
  tried++;
  const R = E.parseRoom(def);
  // No never-lit glass.
  let dead = false;
  for (let y = 0; y < R.rows && !dead; y++) for (let x = 0; x < R.cols; x++) {
    if (R.cell[y][x] !== '~') continue;
    const any = [0, 1, 2, 3, 4, 5].some(i => E.lampsOf(R, { ...E.start(R), rail: i }).some(L => E.lights(R, L, x, y)));
    if (!any) { dead = true; break; }
  }
  if (dead) { F('deadglass'); continue; }
  const full = E.solve(R, LIMIT);
  if (!full.solvable) { F(full.states >= LIMIT ? 'limit' : 'unsolvable'); continue; }
  if (full.steps < 40) { F('short'); continue; }
  const tools = full.plan;
  if (!tools.includes('pin')) { F('nopin'); continue; } if (!tools.includes('veil')) { F('noveil'); continue; } if (!tools.includes('crank')) { F('nocrank'); continue; } if (!tools.includes('pipe')) { F('nopipe'); continue; }
  const np = E.solve({ ...R, pins: 0 }, LIMIT); if (np.solvable || np.states >= LIMIT) { F('pinNotNeeded'); continue; }
  const nv = E.solve({ ...R, vents: [] }, LIMIT); if (nv.solvable || nv.states >= LIMIT) { F('veilNotNeeded'); continue; }
  const nc = E.solve({ ...R, rail: [R.rail[R.railStart]], railStart: 0 }, LIMIT); if (nc.solvable || nc.states >= LIMIT) { F('crankNotNeeded'); continue; }
  const npp = E.solve({ ...R, pipes: [] }, LIMIT); if (npp.solvable || npp.states >= LIMIT) { F('pipeNotNeeded'); continue; }
  const rec = { steps: full.steps, cranks: full.cranks, map: def.map, def, plan: full.plan };
  out.push(rec);
  console.log(`FOUND steps=${full.steps} cranks=${full.cranks} after ${tried} tries\n${def.map.join('\n')}`);
  fs.writeFileSync(`found_${process.argv[2]}.json`, JSON.stringify(out));
}
console.log('done tried', tried, 'found', out.length, JSON.stringify(fail));
