// Nythralor — the Black Sun. Grid rules for Dark's portal level, shared by the
// prototype page and the solver. Nothing here draws.
//
// THE PARTY is two Darks and a Light, and they do not travel together: every
// body stays where you leave it.
//   · LIGHT shines a beam in one direction and holds it until told to stop —
//     but only from a BURNING-GLASS, a lens set in the floor. Step off it and
//     the beam goes out. Its body lets light straight through.
//   · Each DARK owns ONE PORTAL — two ends, I and II — the purple Dark's in
//     black with purple motes, the orange Dark's in black with orange. A Dark
//     casts an end straight ahead onto the first wall it sees; only OBSIDIAN
//     takes it. Casting an end onto the face it already holds closes it.
//     A Dark's body DRINKS light: a beam stops dead at it.
//
// WHAT GOES THROUGH A PORTAL: bodies (all three) and beams. Whatever enters
// one end leaves the other end's face, heading straight out of it.
//
// DARK + LIGHT = BLOOD. A beam that has passed through ONE Dark's portal is
// still white light, only moved. A beam that has passed through BOTH Darks'
// portals, in either order, comes out as BLOOD-LIGHT. Blood-light is solid:
// over the void it is a bridge. (Through the same portal twice is still one.)
//
// Map legend:
//   .  floor              #  stone wall            O  obsidian (takes portals)
//   *  a burning-glass (floor; Light shines only from one)
//   ~  the void (you stand on it only where blood-light crosses it)
//   p  a plate (held down by any body)            E  the exit (all three on it)
//   |  a door: open while its circuit is live, or while a body stands in it
//      (a LATCHING circuit — `latch: true` — keeps its doors open for good once
//      it has been live)
//   w  a white socket (lit by white light)        r  a red socket (blood-light)
//   > < ^ v  a fixed emitter of white light, set in the wall
//   V  the vault cache (floor)
//   D  a doorway to another room (floor)      S  the island's stair (floor)
//
// (Noctryos is not a puzzle: the author's call is ordinary combat, with the
// enemies coming out of black holes.)

(function (root) {
  const DX = [0, 1, 0, -1];
  const DY = [-1, 0, 1, 0];
  const DNAME = ['north', 'east', 'south', 'west'];
  const ARROW = ['▲', '▶', '▼', '◀'];
  const OPP = (d) => (d + 2) % 4;
  const BODIES = ['light', 'purple', 'orange'];
  const DARKS = ['purple', 'orange'];
  const BIT = { purple: 1, orange: 2 };
  const WHITE = 1, BLOOD = 2;
  const EMIT = { '^': 0, '>': 1, 'v': 2, '<': 3 };

  // Cells a body can never enter (a closed door is decided at runtime).
  const SOLID = '#Owr><^v';

  function parseRoom(def) {
    const rows = def.map.length, cols = def.map[0].length;
    const cell = def.map.map((r) => r.split(''));
    for (const r of cell) if (r.length !== cols) throw new Error(def.name + ': ragged map');
    const at = (x, y) => (x < 0 || y < 0 || x >= cols || y >= rows ? '#' : cell[y][x]);
    const faces = [], faceAt = new Map();
    const emitters = [], plates = [], sockets = [], doors = [], exits = [];
    for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {
      const c = cell[y][x];
      if (c === 'O') {
        for (let d = 0; d < 4; d++) {
          const n = at(x + DX[d], y + DY[d]);
          if (!SOLID.includes(n)) { faceAt.set(x + ',' + y + ',' + d, faces.length); faces.push({ x, y, d }); }
        }
      }
      if (c in EMIT) emitters.push({ x, y, d: EMIT[c] });
      if (c === 'p') plates.push({ x, y });
      if (c === 'w' || c === 'r') sockets.push({ x, y, kind: c });
      if (c === '|') doors.push({ x, y });
      if (c === 'E') exits.push({ x, y });
    }
    // One circuit per room unless the room says otherwise: every plate and
    // every socket together hold every door.
    const circuits = def.circuits
      ? def.circuits.map((c) => ({ triggers: c.triggers.map(([x, y]) => x + ',' + y), doors: c.doors.map(([x, y]) => x + ',' + y), latch: !!c.latch }))
      : [{ triggers: [...plates, ...sockets].map((t) => t.x + ',' + t.y), doors: doors.map((t) => t.x + ',' + t.y), latch: !!def.latch }];
    return {
      ...def, rows, cols, cell, at, faces, faceAt, emitters, plates, sockets, doors, exits, circuits,
      goal: def.goal || 'all', cast: def.cast || { purple: true, orange: true }, shine: def.shine !== false,
    };
  }

  const key = (x, y) => x + ',' + y;

  function start(R) {
    const pos = {};
    for (const b of BODIES) pos[b] = R.start[b].slice();
    return { pos, shine: R.startShine ?? -1, ends: { purple: [-1, -1], orange: [-1, -1] }, latched: 0, facing: { light: 1, purple: 1, orange: 1 } };
  }

  function clone(S) {
    return {
      pos: { light: S.pos.light.slice(), purple: S.pos.purple.slice(), orange: S.pos.orange.slice() },
      shine: S.shine,
      ends: { purple: S.ends.purple.slice(), orange: S.ends.orange.slice() },
      latched: S.latched,
      facing: { ...S.facing },
    };
  }

  function bodyAt(S, x, y, except) {
    for (const b of BODIES) if (b !== except && S.pos[b][0] === x && S.pos[b][1] === y) return b;
    return null;
  }

  // The mouth on face index f: { owner, end } or null.
  function mouthOn(S, f) {
    if (f < 0) return null;
    for (const o of DARKS) for (let e = 0; e < 2; e++) if (S.ends[o][e] === f) return { owner: o, end: e };
    return null;
  }

  // Where a portal end leads: the partner's face, or -1 when the pair is not whole.
  function partnerOf(S, m) { return S.ends[m.owner][1 - m.end]; }

  // ── The beams, and everything that hangs off them ──────────────────────
  //
  // Doors depend on sockets, sockets on beams and beams on doors. Opening a
  // door only ever LENGTHENS a beam (nothing here is dimmed by more light),
  // so starting with every door shut and opening what the circuits allow
  // until nothing changes lands on one answer every time.
  function evaluate(R, S) {
    const occupied = new Set(BODIES.map((b) => key(S.pos[b][0], S.pos[b][1])));
    let open = new Set(R.doors.map((d) => key(d.x, d.y)).filter((k) => occupied.has(k)));
    R.circuits.forEach((c, i) => { if (S.latched & (1 << i)) for (const d of c.doors) open.add(d); });
    let out;
    for (let round = 0; round < 8; round++) {
      out = traceAll(R, S, open);
      const live = new Set();
      for (const p of R.plates) if (occupied.has(key(p.x, p.y))) live.add(key(p.x, p.y));
      for (const s of out.socketsLit) live.add(s);
      const next = new Set(open);
      out.nowLatched = 0;
      R.circuits.forEach((c, i) => {
        if (!c.triggers.every((t) => live.has(t))) return;
        for (const d of c.doors) next.add(d);
        if (c.latch) out.nowLatched |= 1 << i;
      });
      out.live = live;
      if (next.size === open.size) break;
      open = next;
    }
    out.open = open;
    return out;
  }

  function isSolid(R, open, x, y) {
    const c = R.at(x, y);
    if (SOLID.includes(c)) return true;
    if (c === '|') return !open.has(key(x, y));
    return false;
  }

  function traceAll(R, S, open) {
    const lit = new Map();       // "x,y" -> WHITE|BLOOD bits
    const socketsLit = new Set();
    const beams = [];            // for drawing: [{ pts:[[x,y,color]...], from }]
    const sources = [];
    if (S.shine >= 0) sources.push({ x: S.pos.light[0], y: S.pos.light[1], d: S.shine, from: 'light' });
    for (const e of R.emitters) sources.push({ x: e.x, y: e.y, d: e.d, from: 'emitter' });
    for (const s of sources) beams.push(trace(R, S, open, s, lit, socketsLit));
    return { lit, socketsLit, beams };
  }

  function trace(R, S, open, src, lit, socketsLit) {
    let x = src.x, y = src.y, d = src.d, via = 0;
    const path = [{ x, y, via, jump: false }];
    const seen = new Set();
    let end = 'wall';
    for (let step = 0; step < 600; step++) {
      const nx = x + DX[d], ny = y + DY[d];
      const c = R.at(nx, ny);
      if (isSolid(R, open, nx, ny)) {
        if (c === 'O') {
          const f = R.faceAt.get(nx + ',' + ny + ',' + OPP(d));
          const m = f === undefined ? null : mouthOn(S, f);
          const p = m ? partnerOf(S, m) : -1;
          if (m && p >= 0) {
            path.push({ x: x + DX[d] * .5, y: y + DY[d] * .5, via, jump: false, mouth: f });
            via |= BIT[m.owner];
            const pf = R.faces[p];
            x = pf.x; y = pf.y; d = pf.d;
            path.push({ x: x + DX[d] * .5, y: y + DY[d] * .5, via, jump: true, mouth: p });
            const k = x + ',' + y + ',' + d + ',' + via;
            if (seen.has(k)) { end = 'loop'; break; }
            seen.add(k);
            continue;
          }
          end = m ? 'lone mouth' : 'obsidian';
        } else if (c === 'w' || c === 'r') {
          const blood = via === 3;
          if ((c === 'w' && !blood) || (c === 'r' && blood)) socketsLit.add(key(nx, ny));
          end = 'socket';
        }
        path.push({ x: x + DX[d] * .5, y: y + DY[d] * .5, via, jump: false });
        break;
      }
      x = nx; y = ny;
      lit.set(key(x, y), (lit.get(key(x, y)) || 0) | (via === 3 ? BLOOD : WHITE));
      const b = bodyAt(S, x, y);
      if (b === 'purple' || b === 'orange') { path.push({ x, y, via, jump: false }); end = 'drunk:' + b; break; }
      const k = x + ',' + y + ',' + d + ',' + via;
      if (seen.has(k)) { path.push({ x, y, via, jump: false }); end = 'loop'; break; }
      seen.add(k);
      path.push({ x, y, via, jump: false });
    }
    return { path, end, from: src.from };
  }

  // Can a body stand on (x,y) with the world as [E] has it?
  function holds(R, E, x, y) {
    const c = R.at(x, y);
    if ('.pE*VDS'.includes(c)) return true;
    if (c === '|') return E.open.has(key(x, y));
    if (c === '~') return ((E.lit.get(key(x, y)) || 0) & BLOOD) !== 0;
    return false;
  }

  // Where [who] would land stepping [d] — through a portal if it walks into
  // one — or a reason it can't.
  function stepTarget(R, S, E, who, d) {
    const [x, y] = S.pos[who];
    const nx = x + DX[d], ny = y + DY[d];
    const c = R.at(nx, ny);
    if (c === 'O') {
      const f = R.faceAt.get(nx + ',' + ny + ',' + OPP(d));
      const m = f === undefined ? null : mouthOn(S, f);
      if (!m) return { why: 'obsidian' };
      const p = partnerOf(S, m);
      if (p < 0) return { why: 'lone mouth' };
      const pf = R.faces[p];
      const tx = pf.x + DX[pf.d], ty = pf.y + DY[pf.d];
      if (bodyAt(S, tx, ty, who)) return { why: 'blocked exit' };
      if (!holds(R, E, tx, ty)) return { why: 'exit over void' };
      return { x: tx, y: ty, face: pf.d, through: m };
    }
    if (isSolid(R, E.open, nx, ny)) return { why: c === '|' ? 'door' : 'wall' };
    if (bodyAt(S, nx, ny, who)) return { why: 'body' };
    if (!holds(R, E, nx, ny)) return { why: c === '~' ? 'void' : 'wall' };
    return { x: nx, y: ny, face: d };
  }

  // Anyone left over the void falls back to where the room let them in (or
  // the nearest free floor to it). Repeats, since a fall can move a beam.
  function settle(R, S, E0) {
    let E = E0 || evaluate(R, S);
    S.latched |= E.nowLatched;
    const fell = [];
    for (let round = 0; round < 4; round++) {
      const down = BODIES.filter((b) => !holds(R, E, S.pos[b][0], S.pos[b][1]));
      if (!down.length) break;
      for (const b of down) {
        fell.push(b);
        S.pos[b] = [-9, -9];
      }
      for (const b of down) S.pos[b] = landing(R, S, b);
      E = evaluate(R, S);
      S.latched |= E.nowLatched;
    }
    return { E, fell };
  }

  function landing(R, S, who) {
    const [sx, sy] = R.start[who];
    const q = [[sx, sy]], seen = new Set([key(sx, sy)]);
    while (q.length) {
      const [x, y] = q.shift();
      const c = R.at(x, y);
      if ('.pE*VDS'.includes(c) && !bodyAt(S, x, y, who)) return [x, y];
      for (let d = 0; d < 4; d++) {
        const nx = x + DX[d], ny = y + DY[d];
        if (seen.has(key(nx, ny)) || '#Owr><^v'.includes(R.at(nx, ny))) continue;
        seen.add(key(nx, ny)); q.push([nx, ny]);
      }
    }
    return [sx, sy];
  }

  // ── Actions. Each returns { S, E, fell } or { why }. ─────────────────────

  function move(R, S, who, d, E0) {
    const E = E0 || evaluate(R, S);
    const t = stepTarget(R, S, E, who, d);
    if (t.why) return t;
    const N = clone(S);
    N.pos[who] = [t.x, t.y];
    N.facing[who] = t.face;
    // Off the burning-glass, the beam goes out.
    if (who === 'light' && N.shine >= 0 && R.at(t.x, t.y) !== '*') N.shine = -1;
    const after = evaluate(R, N);
    if (!holds(R, after, t.x, t.y)) return { why: who === 'light' ? 'own light' : 'would fall' };
    const r = settle(R, N, after);
    return { S: N, E: r.E, fell: r.fell, through: t.through };
  }

  function shine(R, S, d) {
    if (!R.shine) return { why: 'no shine' };
    if (d >= 0 && R.at(S.pos.light[0], S.pos.light[1]) !== '*') return { why: 'no lens' };
    const N = clone(S);
    N.shine = S.shine === d || d < 0 ? -1 : d;
    if (d >= 0) N.facing.light = d;
    const r = settle(R, N);
    return { S: N, E: r.E, fell: r.fell };
  }

  // The face a Dark would hit casting [d]: the first solid thing straight
  // ahead, if it is obsidian. Bodies and shut doors stop the cast.
  function castFace(R, S, E, who, d) {
    let [x, y] = S.pos[who];
    for (let i = 0; i < 64; i++) {
      x += DX[d]; y += DY[d];
      if (bodyAt(S, x, y)) return { why: 'body' };
      if (isSolid(R, E.open, x, y)) {
        if (R.at(x, y) !== 'O') return { why: 'stone' };
        const f = R.faceAt.get(x + ',' + y + ',' + OPP(d));
        return f === undefined ? { why: 'stone' } : { f };
      }
    }
    return { why: 'stone' };
  }

  function cast(R, S, who, end, d, E0) {
    if (!R.cast[who]) return { why: 'no cast' };
    const E = E0 || evaluate(R, S);
    const c = castFace(R, S, E, who, d);
    if (c.why) return c;
    const m = mouthOn(S, c.f);
    const N = clone(S);
    N.facing[who] = d;
    if (m && m.owner === who && m.end === end) N.ends[who][end] = -1; // close it
    else if (m) return { why: 'taken' };
    else N.ends[who][end] = c.f;
    const r = settle(R, N);
    return { S: N, E: r.E, fell: r.fell };
  }

  function solved(R, S) {
    if (R.goal === 'vault') return BODIES.some((b) => R.at(S.pos[b][0], S.pos[b][1]) === 'V');
    const on = (b) => R.exits.some((e) => e.x === S.pos[b][0] && e.y === S.pos[b][1]);
    if (R.goal === 'light') return on('light');
    return BODIES.every(on);
  }

  // ── The solver: breadth first over every legal action ───────────────────
  // Two states that differ only by swapping the Darks — bodies and portals
  // together — are the same puzzle (blood wants both, white either), so the
  // search keeps whichever code is smaller.
  function enc1(R, S, order) {
    let a = S.pos.light[1] * R.cols + S.pos.light[0];
    for (const b of order) a = a * 256 + S.pos[b][1] * R.cols + S.pos[b][0];
    a = a * 5 + (S.shine + 1);
    a = a * 8 + S.latched;
    let e = 0;
    for (const o of order) {
      let [i, j] = S.ends[o].map((v) => (v < 0 ? 31 : v));
      if (i > j) [i, j] = [j, i]; // I and II are the same physics
      e = e * 1024 + i * 32 + j;
    }
    return a * 1048576 + e;
  }
  function enc(R, S) {
    const a = enc1(R, S, DARKS);
    return R.asymmetric ? a : Math.min(a, enc1(R, S, [DARKS[1], DARKS[0]]));
  }

  function actions(R, S) {
    const E = evaluate(R, S);
    const out = [];
    for (const b of BODIES) for (let d = 0; d < 4; d++) {
      const r = move(R, S, b, d, E);
      if (!r.why) out.push([b + ' ' + DNAME[d] + (r.through ? ' (through ' + r.through.owner + ')' : '') + (r.fell.length ? ' [' + r.fell.join('+') + ' fell]' : ''), r.S]);
    }
    if (R.shine && (S.shine >= 0 || R.at(S.pos.light[0], S.pos.light[1]) === '*')) for (let d = -1; d < 4; d++) {
      if (d === S.shine || (d < 0 && S.shine < 0)) continue;
      const r = shine(R, S, d);
      if (!r.why) out.push([(d < 0 ? 'light dims' : 'light shines ' + DNAME[d]) + (r.fell.length ? ' [' + r.fell.join('+') + ' fell]' : ''), r.S]);
    }
    for (const o of DARKS) for (let d = 0; d < 4; d++) {
      const c = castFace(R, S, E, o, d);
      if (c.why) continue;
      for (let end = 0; end < 2; end++) {
        const r = cast(R, S, o, end, d, E);
        if (!r.why) out.push([o + ' casts ' + (end ? 'II' : 'I') + ' ' + DNAME[d] + (r.fell.length ? ' [' + r.fell.join('+') + ' fell]' : ''), r.S]);
      }
    }
    return out;
  }

  function solve(R, limit = 4e6) {
    const S0 = start(R);
    const k0 = enc(R, S0);
    const prev = new Map([[k0, null]]);
    let frontier = [S0], depth = 0;
    while (frontier.length) {
      const next = [];
      for (const S of frontier) {
        const k = enc(R, S);
        if (solved(R, S)) {
          const plan = [];
          for (let c = k; prev.get(c); c = prev.get(c)[0]) plan.unshift(prev.get(c)[1]);
          return { solvable: true, steps: depth, plan, states: prev.size };
        }
        for (const [label, N] of actions(R, S)) {
          const nk = enc(R, N);
          if (prev.has(nk)) continue;
          prev.set(nk, [k, label]);
          next.push(N);
        }
        if (prev.size > limit) return { solvable: null, steps: depth, states: prev.size };
      }
      frontier = next; depth++;
    }
    return { solvable: false, states: prev.size };
  }

  // Guided search for rooms too big to search exhaustively: best-first on
  // decisions + walking + how far the goal still is. It FINDS a plan (which
  // is replayed exactly); it proves nothing about shortness, and "impossible"
  // claims stay with solve() on the smaller, restricted rooms.
  function goalDistance(R, S, Ev) {
    let h = 0;
    for (const b of BODIES) {
      const [x, y] = S.pos[b];
      let best = 99;
      for (const e of R.exits) best = Math.min(best, Math.abs(e.x - x) + Math.abs(e.y - y));
      h += best;
    }
    for (const c of R.circuits) if (!c.triggers.every((t) => Ev.live.has(t))) h += 6;
    return h;
  }

  function search(R, { limit = 3e6, weight = 2 } = {}) {
    const S0 = start(R);
    const k0 = enc(R, S0);
    const prev = new Map([[k0, null]]);
    const heap = [];
    const push = (p, item) => { heap.push([p, item]); let i = heap.length - 1; while (i > 0) { const j = (i - 1) >> 1; if (heap[j][0] <= heap[i][0]) break; [heap[i], heap[j]] = [heap[j], heap[i]]; i = j; } };
    const pop = () => { const top = heap[0]; const last = heap.pop(); if (heap.length) { heap[0] = last; let i = 0; for (;;) { const l = 2 * i + 1, r = l + 1; let m = i; if (l < heap.length && heap[l][0] < heap[m][0]) m = l; if (r < heap.length && heap[r][0] < heap[m][0]) m = r; if (m === i) break; [heap[i], heap[m]] = [heap[m], heap[i]]; i = m; } } return top[1]; };
    const walk = /^(light|purple|orange) (north|south|east|west)/;
    push(0, { S: S0, g: 0 });
    while (heap.length) {
      const { S, g } = pop();
      const k = enc(R, S);
      if (solved(R, S)) {
        const plan = [];
        for (let c = k; prev.get(c); c = prev.get(c)[0]) plan.unshift(prev.get(c)[1]);
        return { solvable: true, steps: plan.length, plan, states: prev.size };
      }
      for (const [label, N] of actions(R, S)) {
        const nk = enc(R, N);
        if (prev.has(nk)) continue;
        prev.set(nk, [k, label]);
        const ng = g + (walk.test(label) ? 0.25 : 1);
        push(ng + weight * goalDistance(R, N, evaluate(R, N)) * 0.25, { S: N, g: ng });
      }
      if (prev.size > limit) return { solvable: null, states: prev.size };
    }
    return { solvable: false, states: prev.size };
  }

  const api = { DX, DY, DNAME, ARROW, OPP, BODIES, DARKS, WHITE, BLOOD, parseRoom, start, clone, evaluate, holds, stepTarget, move, shine, cast, castFace, solved, solve, search, actions, enc, mouthOn, partnerOf, bodyAt, key };
  if (typeof module !== 'undefined') module.exports = api;
  else root.PortalEngine = api;
})(typeof window !== 'undefined' ? window : globalThis);
