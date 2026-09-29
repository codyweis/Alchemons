// Leaner search: 9x6, a starlight on a north rail + a fixed one, one pin, one
// vent. Keep rooms where crank, pin and veil are each necessary.
const E = require('./shadow-engine.js');
const fs = require('fs');
let seed = +(process.argv[2] || 1);
const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
const pick = (a) => a[Math.floor(rnd() * a.length)];
const LIMIT = 1200000;
const fail = {};
const F = (k) => { fail[k] = (fail[k] || 0) + 1; };

function candidate() {
  const rows = 6, cols = 9;
  const m = [];
  for (let y = 0; y < rows; y++) {
    const r = [];
    for (let x = 0; x < cols; x++) r.push(x <= 1 ? '.' : x <= 6 ? '~' : 'G');
    m.push(r);
  }
  // The rail across the top of the glass: the railed starlight shines down.
  const railXs = [2, 3, 4, 5, 6];
  for (const x of railXs) m[0][x] = 'n';
  m[rows - 1][0] = 'C';
  // A fixed starlight on the near wall or the far corner.
  const fixed = pick([[0, 2, 'E'], [0, 3, 'E'], [8, 5, 'L'], [8, 0, 'L'], [0, 1, 'L']]);
  m[fixed[1]][fixed[0]] = fixed[2];
  const np = Math.floor(rnd() * 3);
  for (let i = 0; i < np; i++) { const x = 2 + Math.floor(rnd() * 5), y = 1 + Math.floor(rnd() * 5); if (m[y][x] === '~') m[y][x] = 'P'; }
  const nw = Math.floor(rnd() * 3);
  for (let i = 0; i < nw; i++) { const x = 2 + Math.floor(rnd() * 5), y = 1 + Math.floor(rnd() * 5); if (m[y][x] === '~') m[y][x] = '#'; }
  const free = () => { for (let t = 0; t < 40; t++) { const x = pick([0, 1]), y = Math.floor(rnd() * rows); if (m[y][x] === '.') return [x, y]; } return null; };
  const v = free(); if (!v) return null; m[v[1]][v[0]] = 'V';
  const starts = [];
  for (let t = 0; t < 60 && starts.length < 3; t++) { const s = free(); if (s && !starts.some(q => q.x === s[0] && q.y === s[1])) starts.push({ x: s[0], y: s[1] }); }
  if (starts.length < 3) return null;
  return { name: 'gen2', map: m.map(r => r.join('')), rail: railXs.map(x => [x, 0]),
    railStart: Math.floor(rnd() * railXs.length), pins: 1, cone: 0.8,
    start: { Light: starts[0], Dark: starts[1], Steam: starts[2] } };
}

const out = [];
const t0 = Date.now(), budget = +(process.argv[3] || 600) * 1000;
let tried = 0;
while (Date.now() - t0 < budget) {
  const def = candidate(); if (!def) continue;
  tried++;
  const R = E.parseRoom(def);
  let dead = false;
  for (let y = 0; y < R.rows && !dead; y++) for (let x = 0; x < R.cols; x++) {
    if (R.cell[y][x] !== '~') continue;
    if (!R.rail.some((_, i) => E.lampsOf(R, { ...E.start(R), rail: i }).some(L => E.lights(R, L, x, y)))) { dead = true; break; }
  }
  if (dead) { F('dead'); continue; }
  const full = E.solve(R, LIMIT);
  if (!full.solvable) { F(full.states >= LIMIT ? 'limit' : 'unsolvable'); continue; }
  if (full.steps < 30) { F('short'); continue; }
  const p = full.plan;
  if (!p.includes('pin') || !p.includes('veil') || !p.includes('crank')) { F('toolUnused'); continue; }
  const np = E.solve({ ...R, pins: 0 }, LIMIT); if (np.solvable || np.states >= LIMIT) { F('pinNot'); continue; }
  const nv = E.solve({ ...R, vents: [] }, LIMIT); if (nv.solvable || nv.states >= LIMIT) { F('veilNot'); continue; }
  const nc = E.solve({ ...R, rail: [R.rail[R.railStart]], railStart: 0 }, LIMIT); if (nc.solvable || nc.states >= LIMIT) { F('crankNot'); continue; }
  out.push({ steps: full.steps, cranks: full.cranks, def, plan: full.plan });
  console.log(`FOUND steps=${full.steps} cranks=${full.cranks} after ${tried}\n${def.map.join('\n')}\nstart ${JSON.stringify(def.start)} rail ${def.railStart}`);
  fs.writeFileSync(`found2_${process.argv[2]}.json`, JSON.stringify(out));
}
console.log('done tried', tried, 'found', out.length, JSON.stringify(fail));
