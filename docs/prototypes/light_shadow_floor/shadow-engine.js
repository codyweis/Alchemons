// The Shadow Floor — grid rules, shared by the prototype page and the solver.
//
// Map legend:  .  stone      ~  glass over the lightwell (floor only in shadow)
//              #  wall (blocks light too)
//              L  a starlight, every way   E N W S  one facing one way (a cone)
//              V  steam vent (stone; Steam may breathe a veil here)
//              G  goal stone
//              P  pillar   M  the door-shaped monolith   R  the relic's plinth
//                 (all three are solid and cast shadows)
//              B  blank wall: solid, until the MONOLITH's shadow is pinned on it
//              n  a notch on a starlight's rail (solid; the rail's order is def.rail)
//              C  the crank that walks the railed starlight to its next notch
//              d  the dais (stone)
const NAMES = ['Light', 'Dark', 'Steam'];
const BODY_R = 0.36, VEIL_R = 0.45, STONE_R = 0.5;

function parseRoom(def) {
  const rows = def.map.length, cols = def.map[0].length;
  const cell = [], lamps = [], vents = [], fixed = [];
  for (let y = 0; y < rows; y++) {
    cell.push([]);
    for (let x = 0; x < cols; x++) {
      const ch = def.map[y][x];
      cell[y].push(ch);
      if ('LENWS'.includes(ch)) {
        const face = { E: 0, S: Math.PI / 2, W: Math.PI, N: -Math.PI / 2 }[ch];
        lamps.push({ x, y, face: face ?? null, half: def.cone ?? 0.52 });
      }
      if (ch === 'V') vents.push({ x, y });
      if ('PMR'.includes(ch)) fixed.push({ id: ch + ':' + x + ',' + y, kind: ch, cx: x + .5, cy: y + .5, r: (ch === 'P' && def.pillarR) || STONE_R, x, y });
    }
  }
  return { ...def, rows, cols, cell, lamps, vents, fixed, goal: def.goal || 'all' };
}

const K = (x, y) => x + ',' + y;
const isGlass = (R, x, y) => R.cell[y] && R.cell[y][x] === '~';
const inside = (R, x, y) => x >= 0 && y >= 0 && x < R.cols && y < R.rows;

// Every starlight burning right now: the fixed ones, the one on the rail,
// and Solarin itself where it hangs on its orbit.
function lampsOf(R, S) {
  const out = R.lamps.slice();
  if (R.rail) { const n = R.rail[S.rail]; out.push({ x: n[0], y: n[1], face: null, half: 0, moving: 'rail' }); }
  if (R.orbit && S.hits < 3) { const o = R.orbit[S.orbit]; out.push({ x: o[0], y: o[1], face: null, half: 0, moving: 'solarin' }); }
  return out;
}

function solid(R, x, y, S) {
  if (!inside(R, x, y)) return true;
  const c = R.cell[y][x];
  if ('#LENWSnPMR'.includes(c)) return true;
  if (c === 'B') return !(S && S.pinned.has(K(x, y)));
  if (S && R.orbit && S.hits < 3) { const o = R.orbit[S.orbit]; if (o[0] === x && o[1] === y) return true; }
  return false;
}

// Does starlight L light cell (x,y)? Inside its cone, and no wall between.
function lights(R, L, x, y) {
  const lx = L.x + .5, ly = L.y + .5, px = x + .5, py = y + .5;
  if (L.face !== null) {
    let d = Math.atan2(py - ly, px - lx) - L.face;
    d = Math.atan2(Math.sin(d), Math.cos(d));
    if (Math.abs(d) > L.half) return false;
  }
  const n = Math.ceil(Math.hypot(px - lx, py - ly) * 6);
  for (let i = 1; i < n; i++) {
    const t = i / n, sx = Math.floor(lx + (px - lx) * t), sy = Math.floor(ly + (py - ly) * t);
    if ((sx === L.x && sy === L.y) || (sx === x && sy === y)) continue;
    if (R.cell[sy] && R.cell[sy][sx] === '#') return false;
  }
  return true;
}

// Is cell (x,y) in the shadow of a round caster at (cx,cy), radius r, from L?
function shadows(L, cx, cy, r, x, y) {
  const lx = L.x + .5, ly = L.y + .5, px = x + .5, py = y + .5;
  const dcx = cx - lx, dcy = cy - ly, dc = Math.hypot(dcx, dcy);
  const dx = px - lx, dy = py - ly, dp = Math.hypot(dx, dy);
  if (dp <= dc + .05) return false;
  if ((dcx * dx + dcy * dy) <= 0) return false;
  return Math.abs(dcx * dy - dcy * dx) / dp < r;
}

// Every caster in the room right now: bodies, the veil, and the stone things.
function casters(R, S, except) {
  const out = [];
  for (const n of NAMES) {
    if (n === except) continue;
    const c = S.pos[n];
    out.push({ id: n, cx: c.x + .5, cy: c.y + .5, r: BODY_R, x: c.x, y: c.y });
  }
  if (S.veil) out.push({ id: 'veil', cx: S.veil.x + .5, cy: S.veil.y + .5, r: VEIL_R, x: S.veil.x, y: S.veil.y });
  for (const f of R.fixed) out.push(f);
  return out;
}

function holdersFrom(R, S, L, x, y, except) {
  return casters(R, S, except).filter(c => !(c.x === x && c.y === y) && shadows(L, c.cx, c.cy, c.r, x, y));
}

// Is glass cell (x,y) floor for [who]? Pinned stone always is. Otherwise
// EVERY starlight reaching it must be blocked there by something not [who].
function glassHolds(R, S, x, y, who) {
  if (S.pinned.has(K(x, y))) return true;
  let lit = false;
  for (const L of lampsOf(R, S)) {
    if (!lights(R, L, x, y)) continue;
    lit = true;
    if (!holdersFrom(R, S, L, x, y, who).length) return false;
  }
  return lit; // glass no starlight reaches is still just glass: nothing.
}

function occupant(S, x, y, except) {
  return NAMES.find(n => n !== except && S.pos[n].x === x && S.pos[n].y === y);
}

function canStand(R, S, x, y, who) {
  if (solid(R, x, y, S)) return false;
  if (occupant(S, x, y, who)) return false;
  if (!isGlass(R, x, y)) return true;
  return glassHolds(R, S, x, y, who);
}

function othersHeld(R, S, who, x, y) {
  const T = { ...S, pos: { ...S.pos, [who]: { x, y } } };
  for (const n of NAMES) {
    if (n === who) continue;
    const p = T.pos[n];
    if (isGlass(R, p.x, p.y) && !glassHolds(R, T, p.x, p.y, n)) return n;
  }
  return null;
}

function stepCheck(R, S, who, x, y) {
  if (!canStand(R, S, x, y, who)) return 'floor';
  const fell = othersHeld(R, S, who, x, y);
  if (fell) return 'holds:' + fell;
  return null;
}

// Dark pins "the shadow it stands in": the casters that hold its cell, and
// every glass cell those casters alone hold, become stone. A blank wall
// takes the pin only from the MONOLITH: the shadow of a door is a door.
function pinCells(R, S) {
  const d = S.pos.Dark;
  if (!isGlass(R, d.x, d.y) || S.pinned.has(K(d.x, d.y))) return null;
  const lamps = lampsOf(R, S);
  const used = new Set();
  for (const L of lamps) {
    if (!lights(R, L, d.x, d.y)) continue;
    const h = holdersFrom(R, S, L, d.x, d.y, 'Dark');
    if (!h.length) return null;
    for (const c of h) used.add(c.id);
  }
  const monolith = [...used].some(id => id.startsWith('M:'));
  const out = [];
  for (let y = 0; y < R.rows; y++) for (let x = 0; x < R.cols; x++) {
    const c = R.cell[y][x];
    if (!(c === '~' || (c === 'B' && monolith)) || S.pinned.has(K(x, y))) continue;
    let ok = true, lit = false;
    for (const L of lamps) {
      if (!lights(R, L, x, y)) continue;
      lit = true;
      const h = holdersFrom(R, S, L, x, y, null).filter(c => used.has(c.id));
      if (!h.length) { ok = false; break; }
    }
    if (ok && lit) out.push(K(x, y));
  }
  return out;
}

// After the light moves (a crank, or Solarin struck), anyone left standing on
// glass that no longer holds falls back to where they came in.
function resolveFalls(R, S) {
  let pos = { ...S.pos };
  const fell = [];
  for (const n of NAMES) {
    const p = pos[n];
    if (!isGlass(R, p.x, p.y)) continue;
    if (glassHolds(R, { ...S, pos }, p.x, p.y, n)) continue;
    fell.push(n);
  }
  for (const n of fell) {
    const home = R.start[n];
    const free = [home, ...Object.values(R.start)].find(h => !NAMES.some(m => m !== n && pos[m].x === h.x && pos[m].y === h.y));
    pos = { ...pos, [n]: { x: free.x, y: free.y } };
  }
  return { S: { ...S, pos }, fell };
}

function solarinReach(R, S, n) {
  if (!R.orbit || S.hits >= 3) return false;
  const o = R.orbit[S.orbit], p = S.pos[n];
  // A blow needs you close: two squares in a straight line, no further.
  return Math.hypot(p.x - o[0], p.y - o[1]) <= 2.01;
}

function solved(R, S) {
  if (R.goal === 'hits') return S.hits >= 3;
  const on = (n) => R.cell[S.pos[n].y][S.pos[n].x] === 'G';
  return R.goal === 'any' ? NAMES.some(on) : NAMES.every(on);
}

// ── solver ─────────────────────────────────────────────────
function enc(S) {
  return NAMES.map(n => S.pos[n].x + '.' + S.pos[n].y).join('|') + '|' + S.pins + '|' +
    (S.veil ? S.veil.x + '.' + S.veil.y : '-') + '|' + S.rail + '|' + S.orbit + '|' + S.hits + '|' +
    [...S.pinned].sort().join(';');
}

function moves(R, S) {
  const out = [];
  for (const n of NAMES) {
    if (R.actors && !R.actors.includes(n)) continue;
    const p = S.pos[n];
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const x = p.x + dx, y = p.y + dy;
      if (stepCheck(R, S, n, x, y)) continue;
      out.push([`${n}→${x},${y}`, { ...S, pos: { ...S.pos, [n]: { x, y } } }]);
    }
  }
  if (S.pins > 0) {
    const cells = pinCells(R, S);
    if (cells && cells.length) {
      const pinned = new Set(S.pinned); for (const c of cells) pinned.add(c);
      out.push(['pin', { ...S, pinned, pins: S.pins - 1 }]);
    }
  }
  const st = S.pos.Steam;
  if (R.vents.some(v => v.x === st.x && v.y === st.y) && !(S.veil && S.veil.x === st.x && S.veil.y === st.y)) {
    out.push(['veil', { ...S, veil: { x: st.x, y: st.y } }]);
  }
  const li = S.pos.Light;
  if (R.rail && R.cell[li.y][li.x] === 'C') {
    out.push(['crank', resolveFalls(R, { ...S, rail: (S.rail + 1) % R.rail.length }).S]);
  }
  if (R.orbit) for (const n of NAMES) {
    if (R.actors && !R.actors.includes(n)) continue;
    if (!solarinReach(R, S, n)) continue;
    out.push([`strike(${n})`, resolveFalls(R, { ...S, hits: S.hits + 1, orbit: (S.orbit + 1) % R.orbit.length }).S]);
  }
  return out;
}

function start(R) {
  return { pos: JSON.parse(JSON.stringify(R.start)), pins: R.pins ?? 0, veil: null, pinned: new Set(),
    rail: R.railStart ?? 0, orbit: R.orbitStart ?? 0, hits: 0 };
}

function solve(R, limit = 3e6, from) {
  const S0 = from || start(R);
  const seen = new Map([[enc(S0), null]]);
  const q = [S0];
  let head = 0, goal = null;
  while (head < q.length && seen.size < limit) {
    const S = q[head++];
    if (solved(R, S)) { goal = S; break; }
    for (const [label, T] of moves(R, S)) {
      const e = enc(T);
      if (seen.has(e)) continue;
      seen.set(e, [enc(S), label, S]);
      q.push(T);
    }
  }
  if (!goal) return { solvable: false, states: seen.size };
  const plan = [];
  for (let e = enc(goal); seen.get(e); e = seen.get(e)[0]) plan.unshift(seen.get(e)[1]);
  return { solvable: true, states: seen.size, steps: plan.length, plan,
    pins: plan.filter(p => p === 'pin').length, veils: plan.filter(p => p === 'veil').length,
    cranks: plan.filter(p => p === 'crank').length, strikes: plan.filter(p => p.startsWith('strike')).length };
}

if (typeof module !== 'undefined') module.exports = { lampsOf, lights, NAMES, parseRoom, solve, start, moves, enc, pinCells, stepCheck, glassHolds, solved, isGlass, K, canStand, BODY_R, VEIL_R, STONE_R, shadows, resolveFalls, solarinReach, casters, solid, inside };
