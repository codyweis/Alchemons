// The Shadow Floor — the page: the hall, the rooms, drawing and input.
(() => {
  const cv = document.getElementById('cv');
  const ctx = cv.getContext('2d');
  const statusEl = document.getElementById('status');
  const partyEl = document.getElementById('party');
  const actBtn = document.getElementById('act');
  const act2Btn = document.getElementById('act2');
  const act3Btn = document.getElementById('act3');
  const resetBtn = document.getElementById('reset');
  const nextBtn = document.getElementById('back');
  const noteEl = document.getElementById('note');
  const navEl = document.getElementById('nav');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;

  const EL = {
    Light: { fill: '#f2c95c', rim: '#8a6420', verb: 'turns cranks' },
    Dark:  { fill: '#4a3f6e', rim: '#15111f', verb: 'pins a shadow into stone' },
    Steam: { fill: '#d9e8ea', rim: '#6e8a8e', verb: 'breathes a veil at a vent' },
  };

  // The four rooms the hall's bridge is built from, in order.
  const ORDER = [
    { id: 'one',   title: 'I · Nothing stands on its own shadow', kind: 'grid' },
    { id: 'key',   title: 'II · The key', kind: 'key' },
    { id: 'three', title: 'III · Two suns', kind: 'grid' },
    { id: 'four',  title: 'IV · Two gaps, one pin', kind: 'grid' },
  ];
  const EXTRA = [
    { id: 'rite', title: 'The Door of Shadow' },
    { id: 'solarin', title: 'Solarin' },
    { id: 'vault', title: 'The Sunless Reliquary' },
  ];
  const NOTES = {
    hall: '<strong>The great hall.</strong> A bright lightwell with the Door of Shadow on the far ledge and nothing to cross on. Each room you solve sets one span of shadow-stone across the hall. Tap a door on the north wall, or pick a room above.',
    one: '<strong>Room I.</strong> Get all three onto the gold stone by the far door. Pick a creature, then tap a square to walk there. The starlight never moves in this room. You have one pin.',
    key: '<strong>Room II.</strong> Open the arch. Tap the floor to walk, tap the arch to walk up to it, and with Light chosen tap a brass stud to move the starlight. The top panel is the arch face-on; the bottom is the floor from above.',
    three: '<strong>Room III.</strong> Two starlights. Glass holds only where every starlight is blocked. Get all three onto the gold stone. You have one pin.',
    four: '<strong>Room IV.</strong> Two gaps, two starlights that each shine one way. Get all three onto the gold stone at the top. One pin, and a vent on the first ledge.',
    rite: '<strong>The Door of Shadow.</strong> A blank wall, and the stair to Solarin behind it. Light turns the crank to walk the starlight along its rail. You have one pin.',
    solarin: '<strong>Solarin.</strong> The star the starlights fell from. It hangs where it hangs, and everything near it throws a shadow away from it. Strike it three times from two squares away. Each blow sends it round its orbit, and anyone left standing on bare light falls back to the ledge.',
    vault: '<strong>The Sunless Reliquary.</strong> The relic sits across the light behind a narrow doorway. Light turns the crank. Reach the gold step beside the relic.',
  };

  let mode = 'hall', sel = 'Light', W = 0, H = 0, U = 1, dpr = 1, time = 0;
  const done = new Set();
  const spanAt = new Map();
  let pendingSpan = null;
  let maxim = null; // time the lost maxim was found

  const say = (m) => { statusEl.textContent = m || ''; };

  // ═══════════════════════════ GRID ROOMS ═══════════════════════════════
  const grids = {};
  function newGrid(id) {
    const R = parseRoom(ROOMS[id]);
    const S = start(R);
    const disp = {};
    for (const n of NAMES) disp[n] = { px: S.pos[n].x, py: S.pos[n].y, path: [], fallT: -9 };
    return { id, R, S, disp, stone: new Map(), seen: new Map(), solved: false, solvedT: 0, veilT: 0,
      railShown: S.rail, railPos: null, hitT: -9, orbitShown: null };
  }

  const busy = (g) => NAMES.some(n => g.disp[n].path.length);

  function pathTo(g, who, tx, ty) {
    const { R, S } = g;
    const s = S.pos[who], startK = K(s.x, s.y), goalK = K(tx, ty);
    const prev = new Map([[startK, null]]);
    const q = [[s.x, s.y]];
    let firstHold = null;
    while (q.length) {
      const [x, y] = q.shift();
      if (K(x, y) === goalK) break;
      const at = { ...S, pos: { ...S.pos, [who]: { x, y } } };
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const nx = x + dx, ny = y + dy, nk = K(nx, ny);
        if (prev.has(nk)) continue;
        const why = stepCheck(R, at, who, nx, ny);
        if (why) { if (why.startsWith('holds') && x === s.x && y === s.y) firstHold = why.slice(6); continue; }
        prev.set(nk, K(x, y));
        q.push([nx, ny]);
      }
    }
    if (!prev.has(goalK)) return { path: null, firstHold };
    const path = [];
    for (let c = goalK; c && c !== startK; c = prev.get(c)) path.unshift(c.split(',').map(Number));
    return { path };
  }

  const litCount = (R, S, x, y) => lampsOf(R, S).filter(L => lights(R, L, x, y)).length;

  function tapGrid(g, ux, uy) {
    if (g.solved || busy(g)) return;
    const x = Math.floor(ux), y = Math.floor(uy);
    const { R, S } = g;
    if (!inside(R, x, y)) return;
    const on = NAMES.find(n => S.pos[n].x === x && S.pos[n].y === y);
    if (on) { choose(on); return; }
    if (solid(R, x, y, S)) {
      const c = R.cell[y][x];
      say({ '#': 'That is a wall.', B: 'A blank wall. There is no door in it.', P: 'A pillar.', M: 'A statue of a door, standing in front of nothing.', R: 'The relic, on its plinth.', n: 'The starlight’s rail.' }[c] || 'That is a starlight.');
      return;
    }
    if (isGlass(R, x, y) && !glassHolds(R, S, x, y, sel)) {
      const forOthers = glassHolds(R, S, x, y, null);
      say(forOthers ? 'Nothing stands on its own shadow.' : 'That is only light. There is nothing to stand on.');
      return;
    }
    const { path, firstHold } = pathTo(g, sel, x, y);
    if (!path) { say(firstHold ? `${firstHold} is standing on ${sel}'s shadow.` : 'No floor leads there.'); return; }
    say('');
    g.disp[sel].path = path;
  }

  function pinGrid(g) {
    const { R, S } = g;
    if (sel !== 'Dark' || g.solved || busy(g)) return;
    if (S.pins === 0) {
      for (const n of NAMES) {
        const p = S.pos[n];
        if (!S.pinned.has(K(p.x, p.y))) continue;
        const T = { ...S, pinned: new Set() };
        if (R.cell[p.y][p.x] === 'B' || !glassHolds(R, T, p.x, p.y, n)) { say(`${n} is standing on the stone.`); return; }
      }
      g.S = { ...S, pinned: new Set(), pins: R.pins };
      say('The stone lets go and is shadow again.');
      sync(); return;
    }
    const cells = pinCells(R, S);
    if (!cells || !cells.length) { say('There is no shadow here to pin.'); return; }
    const pinned = new Set(S.pinned);
    for (const c of cells) { pinned.add(c); g.stone.set(c, time); }
    g.S = { ...S, pinned, pins: S.pins - 1 };
    const wall = cells.some(c => { const [x, y] = c.split(',').map(Number); return R.cell[y][x] === 'B'; });
    say(wall ? 'The shadow sets into stone, and where it lay on the wall there is a door.' : 'The shadow sets into stone.');
    sync();
  }

  function veilGrid(g) {
    const { R, S } = g;
    if (sel !== 'Steam' || g.solved || busy(g)) return;
    const st = S.pos.Steam;
    if (!R.vents.some(v => v.x === st.x && v.y === st.y)) {
      say(R.vents.length ? 'Steam needs to stand on a vent.' : 'There is no vent in this room.');
      return;
    }
    if (S.veil && S.veil.x === st.x && S.veil.y === st.y) { say('The veil is already hanging here.'); return; }
    g.S = { ...S, veil: { x: st.x, y: st.y } };
    g.veilT = time;
    say('A veil of steam rises from the vent and hangs there.');
    sync();
  }

  function applyFalls(g, next, what) {
    const { S, fell } = resolveFalls(g.R, next);
    g.S = S;
    for (const n of NAMES) {
      if (!fell.includes(n)) continue;
      g.disp[n].px = S.pos[n].x; g.disp[n].py = S.pos[n].y; g.disp[n].path = []; g.disp[n].fallT = time;
    }
    const f = fell.length ? ` ${fell.join(' and ')} ${fell.length > 1 ? 'fall' : 'falls'} through the light and ${fell.length > 1 ? 'land' : 'lands'} back on the ledge.` : '';
    say(what + f);
  }

  function crankGrid(g) {
    const { R, S } = g;
    if (sel !== 'Light' || g.solved || busy(g) || !R.rail) return;
    const li = S.pos.Light;
    if (R.cell[li.y][li.x] !== 'C') { say('Light needs to stand at the crank.'); return; }
    g.railPos = { from: S.rail, t: time };
    applyFalls(g, { ...S, rail: (S.rail + 1) % R.rail.length }, 'The crank turns, and the starlight walks one notch along its rail.');
    sync();
  }

  function strikeGrid(g) {
    const { R, S } = g;
    if (g.solved || busy(g) || !R.orbit) return;
    if (!solarinReach(R, S, sel)) { say(`${sel} is too far from Solarin. Two squares, no more.`); return; }
    g.orbitShown = { from: S.orbit, t: time };
    g.hitT = time;
    const hits = S.hits + 1;
    applyFalls(g, { ...S, hits, orbit: (S.orbit + 1) % R.orbit.length },
      hits >= 3 ? 'The third blow. Solarin breaks into light.' : `A blow. Solarin swings round its orbit. ${3 - hits} to go.`);
    if (solved(R, g.S)) win(g.id, g);
    sync();
  }

  function stepGrid(g, dt) {
    for (const n of NAMES) {
      const d = g.disp[n];
      if (!d.path.length) continue;
      const [tx, ty] = d.path[0];
      const sp = 7 * dt, dx = tx - d.px, dy = ty - d.py, dist = Math.hypot(dx, dy);
      if (dist <= sp) {
        d.px = tx; d.py = ty; d.path.shift();
        g.S = { ...g.S, pos: { ...g.S.pos, [n]: { x: tx, y: ty } } };
        if (!d.path.length && solved(g.R, g.S) && g.R.goal !== 'hits') win(g.id, g);
      } else { d.px += dx / dist * sp; d.py += dy / dist * sp; }
    }
  }

  // ═══════════════════════════ ROOM II · THE KEY ════════════════════════
  const KEY = { x: 6.5, y: 3.6, z: 0.55 };
  const LAMP_Z = 0.5;
  const ARCH = { l: 3, r: 7, spring: 1.6, apex: 2.4 };
  const PANEL = 2.7, GAP = 0.35, FLOOR = 6;
  const NOTCH_X = [3, 4, 5, 6, 7, 8, 9], NOTCH_Y = [4.0, 4.8, 5.6];
  const ANSWER = { x: 7, y: 4.8 };
  const KPARTS = [
    { circle: [KEY.x - 0.16, KEY.z, 0.1], hole: 0.045 },
    { rect: [KEY.x - 0.07, KEY.z - 0.025, KEY.x + 0.25, KEY.z + 0.025] },
    { rect: [KEY.x + 0.14, KEY.z - 0.1, KEY.x + 0.18, KEY.z - 0.025] },
    { rect: [KEY.x + 0.2, KEY.z - 0.08, KEY.x + 0.25, KEY.z - 0.025] },
  ];
  let KR = null;
  function newKey() {
    return {
      lamp: { x: 4, y: 5.6, px: 4, py: 5.6 },
      crs: { Light: { x: 4.6, y: 5.3 }, Dark: { x: 1.6, y: 4.4 }, Steam: { x: 9.0, y: 3.2 } },
      move: {}, veilOn: false, veil: 0, pinned: false, pinT: 0, pinLamp: null, shake: 0,
      solved: false, solvedT: 0,
    };
  }
  const mag = (ly) => ly / (ly - KEY.y);
  function proj(L, x, z) { const m = mag(L.y); return [L.x + (x - L.x) * m, LAMP_Z + (z - LAMP_Z) * m]; }
  const matches = (l) => Math.abs(l.x - ANSWER.x) < .01 && Math.abs(l.y - ANSWER.y) < .01;
  const nearArch = (c) => c.y < 1.5 && c.x > ARCH.l - .6 && c.x < ARCH.r + .6;

  function tapKey(ux, uy) {
    const r = KR;
    if (r.solved) return;
    const fy = uy - PANEL - GAP;
    if (fy < 0) { walkKey(sel, Math.min(Math.max(ux, ARCH.l + .3), ARCH.r - .3), 0.8); return; }
    for (const n of NAMES) { const c = r.crs[n]; if (Math.hypot(c.x - ux, c.y - fy) < 0.4) { choose(n); return; } }
    for (const nx of NOTCH_X) for (const ny of NOTCH_Y) {
      if (Math.hypot(nx - ux, ny - fy) < 0.34) {
        if (sel !== 'Light') { walkKey(sel, nx, ny + 0.45); say('Only Light moves the starlight.'); return; }
        if (r.pinned) { say('The key is set. The starlight can rest.'); return; }
        r.lamp.x = nx; r.lamp.y = ny; walkKey('Light', nx + 0.5, ny + 0.4); say(''); return;
      }
    }
    walkKey(sel, ux, fy);
  }
  function walkKey(n, x, y) {
    x = Math.min(Math.max(x, .5), 9.5); y = Math.min(Math.max(y, .5), FLOOR - .35);
    const d = Math.hypot(x - KEY.x, y - KEY.y);
    if (d < .5) { x = KEY.x + (x - KEY.x) / (d || 1) * .5; y = KEY.y + (y - KEY.y) / (d || 1) * .5; }
    KR.move[n] = { x, y };
  }
  function actKey(which) {
    const r = KR, c = r.crs[sel];
    if (r.solved) return;
    if (which === 'veil') {
      if (sel !== 'Steam') return;
      if (!nearArch(c)) { say('Steam is too far from the arch.'); return; }
      if (r.veilOn) { say('The veil is already hanging.'); return; }
      r.veilOn = true; say('A veil of steam hangs in the arch.'); sync(); return;
    }
    if (sel !== 'Dark') return;
    if (!nearArch(c)) { say('Dark is too far from the arch.'); return; }
    if (!r.veilOn) { say('There is no shadow on the arch to pin.'); return; }
    if (!matches(r.lamp)) { r.shake = 0.5; say('It does not fit the lock.'); return; }
    r.pinned = true; r.pinT = time; r.pinLamp = { ...r.lamp };
    say('The shadow sets. The key turns.'); sync();
  }
  function stepKey(dt) {
    const r = KR;
    for (const n of Object.keys(r.move)) {
      const c = r.crs[n], t = r.move[n];
      const sp = 4 * dt, dx = t.x - c.x, dy = t.y - c.y, d = Math.hypot(dx, dy);
      if (d <= sp) { c.x = t.x; c.y = t.y; delete r.move[n]; } else { c.x += dx / d * sp; c.y += dy / d * sp; }
    }
    const L = r.lamp, e = 1 - Math.pow(0.001, dt);
    L.px += (L.x - L.px) * e; L.py += (L.y - L.py) * e;
    if (r.veilOn) r.veil = Math.min(1, r.veil + dt / 1.1);
    if (r.shake > 0) r.shake = Math.max(0, r.shake - dt);
    if (r.pinned && !r.solved && time - r.pinT > 2.2) win('key', r);
  }

  // ═══════════════════════════ WINNING ══════════════════════════════════
  const WIN_LINE = {
    one: 'All three across. The door opens.',
    key: 'The arch opens. The light was the door all along.',
    three: 'All three across. Two suns, and not a lit square under you.',
    four: 'All three at the top. The veil held one gap and the stone the other.',
    rite: 'Through the door that was only a shadow. The stair goes down to Solarin.',
    solarin: 'Solarin breaks into light, and the light has nowhere left to fall.',
    vault: 'The relic’s own shadow was the road to it.',
  };
  function win(id, state) {
    if (state.solved) return;
    state.solved = true; state.solvedT = time;
    if (!done.has(id) && ORDER.some(o => o.id === id)) pendingSpan = id;
    done.add(id);
    say(WIN_LINE[id]);
    sync();
  }

  // ═══════════════════════════ DRAWING: SHARED ══════════════════════════
  const flag = (i, j, light) => {
    const h = Math.sin(i * 12.9898 + j * 78.233) * 43758.5453, t = h - Math.floor(h);
    return `hsl(42, ${light ? 34 : 18}%, ${(light ? 86 : 80) + t * 5}%)`;
  };

  // A STARLIGHT: a shard of Solarin's star. A white core, a corona, and rays
  // as filled tapered blades (never strokes), turning slowly and twinkling.
  // One that shines one way fans its long rays into its cone.
  function drawStar(x, y, s, face, half, big) {
    const tw = reduced ? 1 : 0.92 + 0.08 * Math.sin(time * 5.3 + x * .01);
    const R0 = U * (big ? 2.6 : 1.5) * s;
    const g = ctx.createRadialGradient(x, y, 0, x, y, R0);
    g.addColorStop(0, 'rgba(255,252,236,.95)');
    g.addColorStop(.18, 'rgba(255,234,160,.65)');
    g.addColorStop(.5, 'rgba(255,220,130,.18)');
    g.addColorStop(1, 'rgba(255,220,130,0)');
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(x, y, R0, 0, Math.PI * 2); ctx.fill();
    const spin = reduced ? 0 : time * (big ? .25 : .4);
    const n = big ? 12 : 8;
    for (let i = 0; i < n; i++) {
      const a = spin + (i / n) * Math.PI * 2;
      let long = i % 2 === 0 ? 1 : .55;
      if (face !== null && face !== undefined) {
        let d = a - face; d = Math.atan2(Math.sin(d), Math.cos(d));
        long *= Math.abs(d) <= (half ?? .5) ? 1.5 : .35;
      }
      const len = U * (big ? 1.25 : .72) * long * s * tw;
      const w = U * (big ? .16 : .09) * s;
      const ca = Math.cos(a), sa = Math.sin(a);
      ctx.fillStyle = `rgba(255,240,190,${.75 * Math.min(1, long)})`;
      ctx.beginPath();
      ctx.moveTo(x - sa * w, y + ca * w);
      ctx.lineTo(x + ca * len, y + sa * len);
      ctx.lineTo(x + sa * w, y - ca * w);
      ctx.closePath(); ctx.fill();
    }
    const core = U * (big ? .42 : .2) * s;
    const cg = ctx.createRadialGradient(x, y, 0, x, y, core);
    cg.addColorStop(0, '#ffffff'); cg.addColorStop(.6, '#fff4c8'); cg.addColorStop(1, 'rgba(255,226,140,.0)');
    ctx.fillStyle = cg; ctx.beginPath(); ctx.arc(x, y, core, 0, Math.PI * 2); ctx.fill();
  }

  function drawBody(x, y, n, rad, fallT) {
    const e = EL[n];
    const f = fallT !== undefined ? Math.max(0, 1 - (time - fallT) / .6) : 0;
    if (f > 0) { // landing back on the ledge: a ring of dust
      ctx.fillStyle = `rgba(255,246,214,${.5 * f})`;
      ctx.beginPath(); ctx.arc(x, y, rad * (1.2 + 1.2 * (1 - f)), 0, Math.PI * 2); ctx.fill();
    }
    if (n === sel) {
      ctx.fillStyle = 'rgba(210,171,88,.38)';
      ctx.beginPath(); ctx.arc(x, y, rad * 1.45, 0, Math.PI * 2); ctx.fill();
    }
    ctx.fillStyle = 'rgba(20,16,28,.28)';
    ctx.beginPath(); ctx.ellipse(x, y + rad * .7, rad * .95, rad * .4, 0, 0, Math.PI * 2); ctx.fill();
    const g = ctx.createRadialGradient(x - rad * .35, y - rad * .4, rad * .1, x, y, rad);
    g.addColorStop(0, n === 'Dark' ? '#8a7cc0' : '#ffffff'); g.addColorStop(.35, e.fill); g.addColorStop(1, e.rim);
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(x, y, rad, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = n === 'Dark' ? '#efe7d4' : '#1c1a22';
    ctx.font = `600 ${Math.max(10, rad * .62)}px Spectral, Georgia, serif`;
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText(n[0], x, y + 1);
  }

  function drawVeil(x, y, a) {
    for (let i = 0; i < 5; i++) {
      const t = time * .6 + i * 1.3;
      ctx.fillStyle = `rgba(245,248,250,${.42 * a})`;
      ctx.beginPath();
      ctx.ellipse(x + Math.sin(t) * U * .12, y - U * (.1 + i * .08) + Math.cos(t) * U * .05, U * (.42 - i * .04), U * .26, 0, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  function wedge(L, cx, cy, r, alpha) {
    const lx = L.x + .5, ly = L.y + .5, dx = cx - lx, dy = cy - ly, d = Math.hypot(dx, dy);
    if (d <= r) return;
    const base = Math.atan2(dy, dx), half = Math.asin(r / d), tl = Math.sqrt(d * d - r * r), far = 40;
    const p = [];
    for (const s of [-1, 1]) { const a = base + s * half; p.push([lx + Math.cos(a) * tl, ly + Math.sin(a) * tl, lx + Math.cos(a) * far, ly + Math.sin(a) * far]); }
    ctx.beginPath();
    ctx.moveTo(p[0][0] * U, p[0][1] * U); ctx.lineTo(p[0][2] * U, p[0][3] * U);
    ctx.lineTo(p[1][2] * U, p[1][3] * U); ctx.lineTo(p[1][0] * U, p[1][1] * U); ctx.closePath();
    ctx.fillStyle = `rgba(34,30,44,${alpha})`;
    ctx.fill();
  }

  // ═══════════════════════════ DRAWING: GRID ROOMS ══════════════════════
  // Where each starlight is DRAWN: a railed one glides between notches, and
  // Solarin swings round its orbit, so the shadows sweep with them.
  function drawnLamps(g) {
    const { R, S } = g;
    const out = R.lamps.map(L => ({ ...L }));
    if (R.rail) {
      const to = R.rail[S.rail];
      let x = to[0], y = to[1];
      if (g.railPos) {
        const t = Math.min(1, (time - g.railPos.t) / .5), e = t * t * (3 - 2 * t);
        const fr = R.rail[g.railPos.from];
        x = fr[0] + (to[0] - fr[0]) * e; y = fr[1] + (to[1] - fr[1]) * e;
      }
      out.push({ x, y, face: null, half: 0, kind: 'rail' });
    }
    if (R.orbit && S.hits < 3) {
      const to = R.orbit[S.orbit];
      let x = to[0], y = to[1];
      if (g.orbitShown) {
        const t = Math.min(1, (time - g.orbitShown.t) / .8), e = t * t * (3 - 2 * t);
        const fr = R.orbit[g.orbitShown.from];
        // Round the room's middle, not straight across it.
        const cx = 5, cy = 4;
        const a0 = Math.atan2(fr[1] - cy, fr[0] - cx), a1 = Math.atan2(to[1] - cy, to[0] - cx);
        let da = a1 - a0; da = Math.atan2(Math.sin(da), Math.cos(da));
        const r0 = Math.hypot(fr[0] - cx, fr[1] - cy), r1 = Math.hypot(to[0] - cx, to[1] - cy);
        const a = a0 + da * e, rr = r0 + (r1 - r0) * e;
        x = cx + Math.cos(a) * rr; y = cy + Math.sin(a) * rr;
      }
      out.push({ x, y, face: null, half: 0, kind: 'solarin' });
    }
    return out;
  }

  function drawGrid(g) {
    const { R, S } = g;
    const lamps = lampsOf(R, S);
    const shown = drawnLamps(g);
    // Glass: bright where a starlight reaches it.
    for (let y = 0; y < R.rows; y++) for (let x = 0; x < R.cols; x++) {
      if (R.cell[y][x] !== '~') continue;
      ctx.fillStyle = lamps.some(L => lights(R, L, x, y)) ? '#fff6dc' : '#dcd6c6';
      ctx.fillRect(x * U, y * U, U, U);
    }
    for (const L of shown) {
      const lx = (L.x + .5) * U, ly = (L.y + .5) * U;
      ctx.save();
      ctx.beginPath();
      if (L.face !== null) { ctx.moveTo(lx, ly); ctx.arc(lx, ly, W * 2, L.face - L.half, L.face + L.half); ctx.closePath(); }
      else ctx.rect(0, 0, W, H);
      ctx.clip();
      const gr = ctx.createRadialGradient(lx, ly, U * .2, lx, ly, W * .95);
      gr.addColorStop(0, 'rgba(255,230,150,.55)'); gr.addColorStop(.5, 'rgba(255,240,200,.22)'); gr.addColorStop(1, 'rgba(255,248,230,0)');
      ctx.fillStyle = gr;
      for (let y = 0; y < R.rows; y++) for (let x = 0; x < R.cols; x++) if (R.cell[y][x] === '~') ctx.fillRect(x * U, y * U, U, U);
      ctx.restore();
    }
    if (!reduced) {
      ctx.save(); ctx.beginPath();
      for (let y = 0; y < R.rows; y++) for (let x = 0; x < R.cols; x++) if (R.cell[y][x] === '~') ctx.rect(x * U, y * U, U, U);
      ctx.clip();
      for (let i = 0; i < 9; i++) {
        const x = ((i * 97 + time * 18) % (W + 80)) - 40;
        ctx.fillStyle = 'rgba(255,255,255,.2)';
        ctx.beginPath(); ctx.ellipse(x, H * (.1 + (i % 5) * .2) + Math.sin(time + i) * 8, 26, 7, .6, 0, Math.PI * 2); ctx.fill();
      }
      ctx.restore();
    }
    ctx.fillStyle = 'rgba(210,171,88,.22)';
    for (let y = 0; y < R.rows; y++) for (let x = 0; x < R.cols; x++) {
      if (R.cell[y][x] !== '~') continue;
      ctx.fillRect(x * U, y * U - 1, U, 2); ctx.fillRect(x * U - 1, y * U, 2, U);
    }
    // Stone and its furniture.
    for (let y = 0; y < R.rows; y++) for (let x = 0; x < R.cols; x++) {
      const c = R.cell[y][x];
      if (c === '~') continue;
      if (c === '#' || (c === 'B' && !S.pinned.has(K(x, y)))) {
        ctx.fillStyle = c === 'B' ? '#d9ceb4' : '#3b3446';
        ctx.fillRect(x * U, y * U, U, U);
        ctx.fillStyle = c === 'B' ? '#e8dfca' : '#4a4258';
        ctx.fillRect(x * U + 2, y * U + 2, U - 4, U * .3);
        continue;
      }
      ctx.fillStyle = flag(x, y, c === 'G' || c === 'd');
      ctx.fillRect(x * U, y * U, U, U);
      ctx.fillStyle = 'rgba(122,93,40,.22)';
      ctx.fillRect(x * U, y * U, U, 1.5); ctx.fillRect(x * U, y * U, 1.5, U);
      if (c === 'B') { // a doorway cut by a pinned shadow
        const a = Math.min(1, (time - (g.stone.get(K(x, y)) ?? 0)) / .8);
        ctx.fillStyle = `rgba(24,21,30,${.95 * a})`;
        ctx.fillRect(x * U + 3, y * U, U - 6, U);
        ctx.fillStyle = `rgba(210,171,88,${a})`;
        ctx.fillRect(x * U + 3, y * U, 2.5, U); ctx.fillRect((x + 1) * U - 5.5, y * U, 2.5, U);
      }
      if (c === 'G') { ctx.fillStyle = 'rgba(210,171,88,.28)'; ctx.fillRect(x * U + U * .18, y * U + U * .18, U * .64, U * .64); }
      if (c === 'd') {
        ctx.fillStyle = 'rgba(210,171,88,.4)';
        ctx.beginPath(); ctx.arc((x + .5) * U, (y + .5) * U, U * .4, 0, Math.PI * 2); ctx.fill();
      }
      if (c === 'V') {
        ctx.fillStyle = '#6a5230'; ctx.beginPath(); ctx.arc((x + .5) * U, (y + .5) * U, U * .34, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = '#c9a24e';
        for (let k = -2; k <= 2; k++) ctx.fillRect((x + .5) * U + k * U * .12 - 1.2, (y + .5) * U - U * .24, 2.4, U * .48);
      }
      if (c === 'n') {
        ctx.fillStyle = '#5a4424'; ctx.fillRect(x * U + U * .38, y * U, U * .24, U);
        ctx.fillStyle = '#c9a24e'; ctx.beginPath(); ctx.arc((x + .5) * U, (y + .5) * U, U * .12, 0, Math.PI * 2); ctx.fill();
      }
      if (c === 'C') {
        const a = g.railPos ? Math.min(1, (time - g.railPos.t) / .5) * Math.PI * 2 : 0;
        ctx.fillStyle = '#6a5230'; ctx.beginPath(); ctx.arc((x + .5) * U, (y + .5) * U, U * .32, 0, Math.PI * 2); ctx.fill();
        ctx.save(); ctx.translate((x + .5) * U, (y + .5) * U); ctx.rotate(a);
        ctx.fillStyle = '#d2ab58'; ctx.fillRect(-U * .05, -U * .3, U * .1, U * .3);
        ctx.beginPath(); ctx.arc(0, -U * .3, U * .08, 0, Math.PI * 2); ctx.fill();
        ctx.restore();
      }
    }
    // SHADOWS: bodies where they are, the veil, and the stone things.
    const cs = NAMES.map(n => ({ cx: g.disp[n].px + .5, cy: g.disp[n].py + .5, r: BODY_R }));
    if (S.veil) cs.push({ cx: S.veil.x + .5, cy: S.veil.y + .5, r: VEIL_R });
    for (const f of R.fixed) cs.push(f);
    for (const L of shown) {
      ctx.save();
      if (L.face !== null) {
        const lx = (L.x + .5) * U, ly = (L.y + .5) * U;
        ctx.beginPath(); ctx.moveTo(lx, ly); ctx.arc(lx, ly, W * 2, L.face - L.half, L.face + L.half); ctx.closePath(); ctx.clip();
      }
      for (const c of cs) wedge(L, c.cx, c.cy, c.r, shown.length > 1 ? .22 : .38);
      ctx.restore();
    }
    // Glass that holds becomes black stone, cell by cell as it lands.
    for (let y = 0; y < R.rows; y++) for (let x = 0; x < R.cols; x++) {
      if (R.cell[y][x] !== '~') continue;
      const key = K(x, y);
      if (!glassHolds(R, S, x, y, null)) { g.seen.delete(key); continue; }
      if (!g.seen.has(key)) g.seen.set(key, time);
      const a = reduced ? 1 : Math.min(1, (time - g.seen.get(key)) / .25);
      const inset = (1 - a) * U * .4;
      const pin = S.pinned.has(key);
      ctx.fillStyle = pin ? `rgba(24,21,30,${.95 * a})` : `rgba(38,34,48,${.82 * a})`;
      ctx.fillRect(x * U + inset + 2, y * U + inset + 2, U - inset * 2 - 4, U - inset * 2 - 4);
      if (pin) {
        const pa = Math.min(1, (time - (g.stone.get(key) ?? 0)) / .5);
        ctx.fillStyle = `rgba(210,171,88,${.85 * pa})`;
        ctx.fillRect(x * U + 4, (y + .5) * U - 1.2, U - 8, 2.4);
        ctx.fillRect((x + .5) * U - 1.2, y * U + 4, 2.4, U - 8);
      }
    }
    // The stone things themselves.
    for (const f of R.fixed) {
      const x = f.cx * U, y = f.cy * U, r = f.r * U;
      ctx.fillStyle = 'rgba(20,16,28,.3)';
      ctx.beginPath(); ctx.ellipse(x, y + r * .6, r * 1.05, r * .45, 0, 0, Math.PI * 2); ctx.fill();
      if (f.kind === 'M') {
        // A door carved in the round, standing in front of nothing.
        ctx.fillStyle = '#c9bea2';
        ctx.beginPath(); ctx.moveTo(x - r * .8, y + r * .8); ctx.lineTo(x - r * .8, y - r * .2);
        ctx.quadraticCurveTo(x - r * .8, y - r * 1.1, x, y - r * 1.15); ctx.quadraticCurveTo(x + r * .8, y - r * 1.1, x + r * .8, y - r * .2);
        ctx.lineTo(x + r * .8, y + r * .8); ctx.closePath(); ctx.fill();
        ctx.fillStyle = '#6e644e'; ctx.fillRect(x - r * .45, y - r * .3, r * .9, r * 1.1);
      } else if (f.kind === 'R') {
        ctx.fillStyle = '#e8dfca'; ctx.fillRect(x - r * .7, y - r * .4, r * 1.4, r * 1.1);
        ctx.fillStyle = '#c9a24e'; ctx.beginPath(); ctx.arc(x, y - r * .55, r * .38, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = '#fff4c8'; ctx.beginPath(); ctx.arc(x - r * .1, y - r * .65, r * .12, 0, Math.PI * 2); ctx.fill();
      } else {
        const pg = ctx.createRadialGradient(x - r * .3, y - r * .3, r * .1, x, y, r);
        pg.addColorStop(0, '#f2ecdc'); pg.addColorStop(1, '#a89c80');
        ctx.fillStyle = pg; ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
      }
    }
    for (const L of shown) {
      const big = L.kind === 'solarin';
      const flash = big && time - g.hitT < .5 ? 1 + (1 - (time - g.hitT) / .5) * .5 : 1;
      drawStar((L.x + .5) * U, (L.y + .5) * U, flash, L.face, L.half, big);
    }
    if (R.orbit) {
      // Solarin's remaining blows, as three stars along the top.
      for (let i = 0; i < 3; i++) {
        ctx.fillStyle = i < S.hits ? 'rgba(40,34,52,.5)' : '#d2ab58';
        ctx.beginPath(); ctx.arc(W - U * (.5 + i * .5), U * .45, U * .15, 0, Math.PI * 2); ctx.fill();
      }
    }
    if (S.veil) drawVeil((S.veil.x + .5) * U, (S.veil.y + .5) * U, Math.min(1, (time - g.veilT) / 1));
    for (const n of NAMES) drawBody((g.disp[n].px + .5) * U, (g.disp[n].py + .5) * U, n, U * .34, g.disp[n].fallT);
    if (g.solved) {
      const t = Math.min(1, (time - g.solvedT) / 1.2);
      ctx.fillStyle = `rgba(255,246,214,${.35 * t})`;
      ctx.fillRect(0, 0, W, H);
    }
  }

  // ═══════════════════════════ DRAWING: THE KEY ═════════════════════════
  function keyPath(L, X, Y, grow) {
    const p = new Path2D();
    const P = (x, z) => { const [sx, sz] = proj(L, x, z); return [X(sx), Y(sz)]; };
    const sc = (x, z) => [KEY.x + (x - KEY.x) * grow, KEY.z + (z - KEY.z) * grow];
    for (const part of KPARTS) {
      if (part.circle) {
        const [x, z, rr] = part.circle;
        for (const rad of [rr, part.hole]) {
          for (let i = 0; i <= 24; i++) {
            const a = (i / 24) * Math.PI * 2;
            const [sx, sy] = P(...sc(x + Math.cos(a) * rad, z + Math.sin(a) * rad));
            if (i === 0) p.moveTo(sx, sy); else p.lineTo(sx, sy);
          }
          p.closePath();
        }
      } else {
        const [x0, z0, x1, z1] = part.rect;
        const pts = [[x0, z0], [x1, z0], [x1, z1], [x0, z1]].map(([x, z]) => P(...sc(x, z)));
        p.moveTo(...pts[0]); for (const q of pts.slice(1)) p.lineTo(...q); p.closePath();
      }
    }
    return p;
  }

  function drawKey() {
    const r = KR;
    const Y = (z) => (PANEL - z) * U, F = (y) => (PANEL + GAP + y) * U, X = (x) => x * U;
    const lamp = { x: r.lamp.px, y: r.lamp.py };
    ctx.fillStyle = '#e4dac4'; ctx.fillRect(0, 0, W, PANEL * U);
    for (let row = 0; row < 6; row++) for (let x = (row % 2) * .6 - .6; x < 10; x += 1.2) {
      ctx.fillStyle = flag(Math.round(x * 3), row, true);
      ctx.fillRect(X(x) + 1, row * .45 * U + 1, 1.2 * U - 2, .45 * U - 2);
    }
    const arch = new Path2D();
    arch.moveTo(X(ARCH.l), Y(0)); arch.lineTo(X(ARCH.l), Y(ARCH.spring));
    arch.quadraticCurveTo(X(ARCH.l), Y(ARCH.apex), X(5), Y(ARCH.apex + .12));
    arch.quadraticCurveTo(X(ARCH.r), Y(ARCH.apex), X(ARCH.r), Y(ARCH.spring));
    arch.lineTo(X(ARCH.r), Y(0)); arch.closePath();
    ctx.save(); ctx.clip(arch);
    const open = r.solved ? Math.min(1, (time - r.solvedT) / 1.4) : 0;
    const gl = ctx.createLinearGradient(0, Y(ARCH.apex), 0, Y(0));
    gl.addColorStop(0, '#fffdf4'); gl.addColorStop(1, '#ffe9ad');
    ctx.fillStyle = gl; ctx.fillRect(0, 0, W, PANEL * U);
    if (!reduced) for (let i = 0; i < 5; i++) {
      ctx.fillStyle = 'rgba(255,255,255,.35)';
      ctx.fillRect(X(ARCH.l) + ((i * 57 + time * 22) % (4 * U + 40)) - 20, 0, 6, PANEL * U);
    }
    const hole = keyPath(ANSWER, X, Y, 1.08);
    ctx.fillStyle = 'rgba(210,171,88,.22)'; ctx.fill(hole, 'evenodd');
    ctx.strokeStyle = 'rgba(122,93,40,.85)'; ctx.lineWidth = 3; ctx.stroke(hole);
    if (r.veil > 0) {
      for (let i = 0; i < 9; i++) {
        const t = time * .25 + i * 1.7;
        ctx.fillStyle = `rgba(240,244,246,${.34 * r.veil})`;
        ctx.beginPath();
        ctx.ellipse(X(ARCH.l + ((i * .53 + Math.sin(t) * .2) % 4)), Y(.2 + (i % 5) * .45 + Math.cos(t * 1.3) * .05), U * 1.1, U * .4, 0, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.fillStyle = `rgba(230,236,240,${.35 * r.veil})`; ctx.fill(arch);
      const L = r.pinned ? r.pinLamp : lamp;
      ctx.save();
      ctx.translate(r.shake > 0 ? Math.sin(time * 60) * r.shake * 6 : 0, 0);
      if (r.pinned) {
        const t = Math.min(1, (time - r.pinT) / 1.1), e = 1 - Math.pow(1 - t, 3);
        const [bx, bz] = proj(L, KEY.x - 0.16, KEY.z);
        ctx.translate(X(bx), Y(bz)); ctx.rotate(-e * Math.PI / 2); ctx.translate(-X(bx), -Y(bz));
        const kp = keyPath(L, X, Y, 1);
        ctx.fillStyle = '#17141e'; ctx.fill(kp, 'evenodd');
        ctx.strokeStyle = 'rgba(210,171,88,.95)'; ctx.lineWidth = 2.5; ctx.stroke(kp);
      } else {
        ctx.fillStyle = `rgba(28,24,36,${.72 * r.veil})`; ctx.fill(keyPath(L, X, Y, 1), 'evenodd');
      }
      ctx.restore();
    }
    ctx.restore();
    if (open > 0) {
      ctx.save(); ctx.clip(arch); ctx.fillStyle = `rgba(255,252,238,${.9 * open})`; ctx.fillRect(0, 0, W, PANEL * U); ctx.restore();
      ctx.fillStyle = `rgba(255,240,196,${.4 * open})`;
      ctx.beginPath(); ctx.ellipse(X(5), Y(1), U * 3.2 * open, U * 1.6 * open, 0, 0, Math.PI * 2); ctx.fill();
    }
    ctx.strokeStyle = '#b9a67e'; ctx.lineWidth = U * .16; ctx.stroke(arch);
    ctx.fillStyle = '#2a2433'; ctx.fillRect(0, PANEL * U, W, GAP * U);
    ctx.fillStyle = 'rgba(210,171,88,.5)'; ctx.fillRect(X(ARCH.l), PANEL * U, (ARCH.r - ARCH.l) * U, 3);
    for (let i = 0; i < 10; i++) for (let j = 0; j < FLOOR; j++) {
      ctx.fillStyle = flag(i + 40, j, true); ctx.fillRect(X(i), F(j), U, U);
      ctx.fillStyle = 'rgba(122,93,40,.18)'; ctx.fillRect(X(i), F(j), U, 1.5); ctx.fillRect(X(i), F(j), 1.5, U);
    }
    const ag = ctx.createLinearGradient(0, F(0), 0, F(2));
    ag.addColorStop(0, 'rgba(255,240,196,.55)'); ag.addColorStop(1, 'rgba(255,240,196,0)');
    ctx.fillStyle = ag; ctx.fillRect(X(ARCH.l - .5), F(0), (ARCH.r - ARCH.l + 1) * U, 2 * U);
    {
      const L = r.pinned ? r.pinLamp : lamp;
      const a = [KEY.x - .25, KEY.y], b = [KEY.x + .25, KEY.y];
      const toWall = (p) => { const m = L.y / (L.y - p[1]); return L.x + (p[0] - L.x) * m; };
      ctx.fillStyle = 'rgba(34,30,44,.38)';
      ctx.beginPath(); ctx.moveTo(X(a[0]), F(a[1])); ctx.lineTo(X(toWall(a)), F(0));
      ctx.lineTo(X(toWall(b)), F(0)); ctx.lineTo(X(b[0]), F(b[1])); ctx.closePath(); ctx.fill();
    }
    ctx.fillStyle = 'rgba(122,93,40,.28)';
    for (const ny of NOTCH_Y) ctx.fillRect(X(NOTCH_X[0] - .3), F(ny) - 3, (NOTCH_X.at(-1) - NOTCH_X[0] + .6) * U, 6);
    for (const nx of NOTCH_X) for (const ny of NOTCH_Y) {
      ctx.fillStyle = '#7a5d28'; ctx.beginPath(); ctx.arc(X(nx), F(ny), U * .12, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#d2ab58'; ctx.beginPath(); ctx.arc(X(nx) - 1, F(ny) - 1, U * .07, 0, Math.PI * 2); ctx.fill();
    }
    ctx.fillStyle = 'rgba(40,32,24,.3)';
    ctx.beginPath(); ctx.ellipse(X(KEY.x), F(KEY.y) + U * .22, U * .42, U * .16, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#c9bea2'; ctx.fillRect(X(KEY.x) - U * .32, F(KEY.y) - U * .08, U * .64, U * .28);
    ctx.fillStyle = '#f2ecdc'; ctx.fillRect(X(KEY.x) - U * .32, F(KEY.y) - U * .2, U * .64, U * .14);
    ctx.fillStyle = '#c9a24e';
    ctx.beginPath(); ctx.arc(X(KEY.x - .16), F(KEY.y) - U * .13, U * .06, 0, Math.PI * 2); ctx.fill();
    ctx.fillRect(X(KEY.x - .1), F(KEY.y) - U * .145, U * .34, U * .03);
    ctx.fillRect(X(KEY.x + .16), F(KEY.y) - U * .145, U * .04, U * .07);
    drawStar(X(lamp.x), F(lamp.y), .8, null);
    for (const n of NAMES) drawBody(X(r.crs[n].x), F(r.crs[n].y), n, U * .3);
  }

  // ═══════════════════════════ THE HALL ═════════════════════════════════
  // The near ledge (you), a lightwell, and the far ledge with the Door of
  // Shadow. Four spans, one per room, set across the well as you solve them.
  // A dim door in the south wall; and, floating in the well where nobody
  // would think to stand, a sun inlaid in gold.
  const HALL = { cols: 11, rows: 8.4 };
  const DOORS = [1.1, 3.6, 6.4, 8.9];
  const SUN = { x: 5.5, y: 6.7 };
  const VAULT_DOOR = { x: 1.5, y: 8.1 };
  const spanRect = (i) => ({ x0: 3 + i * 1.25, x1: 3 + (i + 1) * 1.25 });
  const bridgeWhole = () => ORDER.every(o => spanAt.has(o.id));

  function tapHall(ux, uy) {
    if (uy < 1.6) {
      let best = -1, bd = 1.2;
      DOORS.forEach((dx, i) => { const d = Math.abs(ux - dx); if (d < bd) { bd = d; best = i; } });
      if (best >= 0) enter(ORDER[best].id);
      return;
    }
    if (Math.hypot(ux - 9.5, uy - 4.95) < 1.1) {
      if (!bridgeWhole()) { say('The Door of Shadow is across the light, and there is no bridge yet.'); return; }
      enter('rite'); return;
    }
    if (Math.hypot(ux - VAULT_DOOR.x, uy - VAULT_DOOR.y) < .8) {
      if (!done.has('key')) { say('A dim door, and a lock with no key.'); return; }
      enter('vault'); return;
    }
    if (Math.hypot(ux - SUN.x, uy - SUN.y) < .8) {
      if (!bridgeWhole()) { say('A gold sun inlaid in the light, far out across the well.'); return; }
      if (sel !== 'Light') { say('That is only light. There is nothing to stand on.'); return; }
      if (!maxim) { maxim = time; say('Light steps off the bridge onto the light, and the light holds it.'); sync(); }
      return;
    }
  }

  function drawHall() {
    ctx.fillStyle = '#fff6dc'; ctx.fillRect(3 * U, 1.4 * U, 5 * U, H - 1.4 * U);
    const g = ctx.createRadialGradient(W / 2, H * .7, U, W / 2, H * .7, W * .7);
    g.addColorStop(0, 'rgba(255,236,170,.7)'); g.addColorStop(1, 'rgba(255,248,230,.1)');
    ctx.fillStyle = g; ctx.fillRect(3 * U, 1.4 * U, 5 * U, H - 1.4 * U);
    if (!reduced) {
      ctx.save(); ctx.beginPath(); ctx.rect(3 * U, 1.4 * U, 5 * U, H); ctx.clip();
      for (let i = 0; i < 8; i++) {
        ctx.fillStyle = 'rgba(255,255,255,.22)';
        const x = 3 * U + ((i * 71 + time * 16) % (5 * U + 60)) - 30;
        ctx.beginPath(); ctx.ellipse(x, H * (.3 + (i % 4) * .17), 30, 8, .5, 0, Math.PI * 2); ctx.fill();
      }
      ctx.restore();
    }
    // The gold sun floating in the well.
    {
      const x = SUN.x * U, y = SUN.y * U;
      const found = maxim !== null;
      const pulse = reduced ? 0 : Math.sin(time * 2) * .05;
      ctx.fillStyle = `rgba(210,171,88,${found ? .9 : .45})`;
      for (let i = 0; i < 12; i++) {
        const a = i * Math.PI / 6 + time * .1, L = U * (i % 2 ? .38 : .55) * (1 + pulse);
        ctx.beginPath();
        ctx.moveTo(x + Math.cos(a + .18) * U * .22, y + Math.sin(a + .18) * U * .22);
        ctx.lineTo(x + Math.cos(a) * L, y + Math.sin(a) * L);
        ctx.lineTo(x + Math.cos(a - .18) * U * .22, y + Math.sin(a - .18) * U * .22);
        ctx.closePath(); ctx.fill();
      }
      ctx.beginPath(); ctx.arc(x, y, U * .24, 0, Math.PI * 2); ctx.fill();
    }
    for (const [a, b] of [[0, 3], [8, 11]]) for (let i = a; i < b; i++) for (let j = 1; j < 8; j++) {
      ctx.fillStyle = flag(i + 90, j, true); ctx.fillRect(i * U, j * U + .4 * U, U, U);
      ctx.fillStyle = 'rgba(122,93,40,.2)'; ctx.fillRect(i * U, j * U + .4 * U, U, 1.5); ctx.fillRect(i * U, j * U + .4 * U, 1.5, U);
    }
    ctx.fillStyle = '#e4dac4'; ctx.fillRect(0, 0, W, 1.4 * U);
    ctx.fillStyle = 'rgba(122,93,40,.35)'; ctx.fillRect(0, 1.4 * U - 3, W, 3);
    const next = ORDER.findIndex(o => !done.has(o.id));
    DOORS.forEach((dx, i) => {
      const x = dx * U, w = U * .9, top = U * .25, bot = 1.4 * U;
      const solvedDoor = done.has(ORDER[i].id), isNext = i === next;
      ctx.fillStyle = solvedDoor ? '#d2ab58' : isNext ? '#fff3cf' : '#b8ad96';
      ctx.beginPath(); ctx.moveTo(x - w / 2, bot); ctx.lineTo(x - w / 2, top + w * .4);
      ctx.quadraticCurveTo(x - w / 2, top, x, top - 4); ctx.quadraticCurveTo(x + w / 2, top, x + w / 2, top + w * .4);
      ctx.lineTo(x + w / 2, bot); ctx.closePath(); ctx.fill();
      if (isNext && !reduced) {
        ctx.fillStyle = `rgba(255,236,170,${.25 + .15 * Math.sin(time * 3)})`;
        ctx.beginPath(); ctx.ellipse(x, bot, w, w * .45, 0, 0, Math.PI * 2); ctx.fill();
      }
      ctx.fillStyle = '#1c1a22';
      ctx.font = `600 ${U * .34}px Marcellus, Georgia, serif`;
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillText(['I', 'II', 'III', 'IV'][i], x, top + w * .55);
    });
    // The vault's dim door, in the south-west corner.
    {
      const x = VAULT_DOOR.x * U, y = VAULT_DOOR.y * U, w = U * .8;
      ctx.fillStyle = done.has('vault') ? '#d2ab58' : done.has('key') ? '#6e644e' : '#9c927c';
      ctx.fillRect(x - w / 2, y - U * .3, w, U * .5);
    }
    ORDER.forEach((o, i) => {
      if (!spanAt.has(o.id)) return;
      const { x0, x1 } = spanRect(i);
      const t = reduced ? 1 : Math.max(0, Math.min(1, (time - spanAt.get(o.id)) / 1.1));
      const e = 1 - Math.pow(1 - t, 3);
      const y = 4.4 * U, h = U * 1.1;
      ctx.fillStyle = `rgba(34,30,44,${.4 * (1 - e)})`;
      ctx.fillRect(x0 * U - U * .4 * (1 - e), y - U * .6 * (1 - e), (x1 - x0) * U + U * .8 * (1 - e), h + U * 1.2 * (1 - e));
      ctx.fillStyle = `rgba(24,21,30,${.95 * e})`;
      ctx.fillRect(x0 * U + 1, y, (x1 - x0) * U - 2, h);
      ctx.fillStyle = `rgba(210,171,88,${.9 * e})`;
      ctx.fillRect(x0 * U + 4, y + h / 2 - 1.2, ((x1 - x0) * U - 8) * e, 2.4);
      ctx.fillRect(x1 * U - 2, y + 3, 2, h - 6);
    });
    const whole = bridgeWhole();
    const dx = 9.5 * U, dy = 4.95 * U;
    ctx.fillStyle = whole ? '#17141e' : 'rgba(23,20,30,.35)';
    ctx.beginPath(); ctx.moveTo(dx - U * .55, dy + U * 1.1); ctx.lineTo(dx - U * .55, dy - U * .3);
    ctx.quadraticCurveTo(dx - U * .55, dy - U * .9, dx, dy - U * 1.05); ctx.quadraticCurveTo(dx + U * .55, dy - U * .9, dx + U * .55, dy - U * .3);
    ctx.lineTo(dx + U * .55, dy + U * 1.1); ctx.closePath(); ctx.fill();
    if (whole) {
      ctx.fillStyle = `rgba(210,171,88,${.35 + .25 * Math.sin(time * 2)})`;
      ctx.beginPath(); ctx.ellipse(dx, dy + U * 1.1, U * .8, U * .25, 0, 0, Math.PI * 2); ctx.fill();
    }
    // The hall's own starlight, high under the oculus.
    drawStar(W / 2, U * 2.2, .9, null);
    // The party: waiting on the near ledge, or Light out on the sun.
    const party = [['Light', 1, 3.9], ['Dark', 1.6, 5.2], ['Steam', 0.9, 6.3]];
    for (const [n, x, y] of party) {
      if (n === 'Light' && maxim !== null) {
        const t = Math.min(1, (time - maxim) / 1.6), e = t * t * (3 - 2 * t);
        const px = x + (SUN.x - x) * e, py = y + (SUN.y - y) * e;
        drawBody(px * U, py * U, n, U * .3);
        continue;
      }
      drawBody(x * U, y * U, n, U * .3);
    }
    if (maxim !== null && time - maxim > 1.6) {
      const t = Math.min(1, (time - maxim - 1.6) / .8);
      ctx.fillStyle = `rgba(20,17,26,${.82 * t})`;
      const bw = U * 7.2, bh = U * 1.9, bx = (W - bw) / 2, by = U * 1.7;
      ctx.fillRect(bx, by, bw, bh);
      ctx.fillStyle = `rgba(210,171,88,${t})`;
      ctx.fillRect(bx, by, bw, 2); ctx.fillRect(bx, by + bh - 2, bw, 2);
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.font = `${U * .26}px Marcellus, Georgia, serif`;
      ctx.fillText('THE LOST MAXIM', W / 2, by + bh * .3);
      ctx.fillStyle = `rgba(239,231,212,${t})`;
      ctx.font = `italic ${U * .36}px Spectral, Georgia, serif`;
      ctx.fillText('Light walks on light.', W / 2, by + bh * .66);
    }
  }

  // ═══════════════════════════ FRAME / INPUT ════════════════════════════
  function dims() {
    if (mode === 'hall') return [HALL.cols, HALL.rows];
    if (mode === 'key') return [10, PANEL + GAP + FLOOR];
    const R = grids[mode].R; return [R.cols, R.rows];
  }
  function size() {
    const [cols, rows] = dims();
    const w = cv.parentElement.clientWidth;
    dpr = Math.min(2, window.devicePixelRatio || 1);
    W = w; U = W / cols; H = U * rows;
    cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr);
    cv.style.height = H + 'px';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  let last = performance.now();
  function frame(now) {
    const dt = Math.min(.05, (now - last) / 1000); last = now; time += dt;
    if (mode === 'key') stepKey(dt); else if (mode !== 'hall') stepGrid(grids[mode], dt);
    ctx.fillStyle = '#0e0d13'; ctx.fillRect(0, 0, W, H);
    if (mode === 'hall') drawHall(); else if (mode === 'key') drawKey(); else drawGrid(grids[mode]);
    requestAnimationFrame(frame);
  }

  cv.addEventListener('pointerdown', (e) => {
    const b = cv.getBoundingClientRect();
    const ux = (e.clientX - b.left) / b.width * W / U, uy = (e.clientY - b.top) / b.height * H / U;
    if (mode === 'hall') tapHall(ux, uy); else if (mode === 'key') tapKey(ux, uy); else tapGrid(grids[mode], ux, uy);
  });

  function choose(n) { sel = n; sync(); }

  function roomButton(id, title, locked) {
    const b = document.createElement('button');
    b.type = 'button'; b.id = 'go-' + id;
    b.textContent = (done.has(id) ? '✓ ' : '') + title;
    b.setAttribute('aria-pressed', String(mode === id));
    b.onclick = () => enter(id);
    return b;
  }

  function sync() {
    navEl.innerHTML = '';
    navEl.appendChild(roomButton('hall', 'The hall'));
    for (const o of ORDER) navEl.appendChild(roomButton(o.id, o.title));
    for (const o of EXTRA) navEl.appendChild(roomButton(o.id, o.title));
    partyEl.innerHTML = '';
    for (const n of NAMES) {
      const b = document.createElement('button');
      b.type = 'button'; b.id = 'pick-' + n.toLowerCase();
      b.setAttribute('aria-pressed', String(n === sel));
      b.innerHTML = `<span class="dot" style="background:${EL[n].fill}"></span><span>${n}</span><span class="verb">${EL[n].verb}</span>`;
      b.onclick = () => choose(n);
      partyEl.appendChild(b);
    }
    const inRoom = mode !== 'hall';
    const g = inRoom && mode !== 'key' ? grids[mode] : null;
    const solvedNow = mode === 'key' ? KR?.solved : g ? g.solved : false;
    actBtn.hidden = act2Btn.hidden = act3Btn.hidden = resetBtn.hidden = !inRoom;
    if (inRoom) {
      const pins = g ? g.S.pins : 1;
      const hasPins = mode === 'key' || (g && g.R.pins > 0);
      actBtn.hidden = !hasPins;
      actBtn.textContent = pins ? 'Pin the shadow' : 'Release the stone';
      actBtn.disabled = sel !== 'Dark' || !!solvedNow;
      act2Btn.hidden = !(mode === 'key' || (g && g.R.vents.length));
      act2Btn.disabled = sel !== 'Steam' || !!solvedNow;
      if (g && g.R.rail) { act3Btn.hidden = false; act3Btn.textContent = 'Turn the crank'; act3Btn.disabled = sel !== 'Light' || !!solvedNow; }
      else if (g && g.R.orbit) { act3Btn.hidden = false; act3Btn.textContent = `Strike Solarin (${sel})`; act3Btn.disabled = !!solvedNow; }
      else act3Btn.hidden = true;
    }
    // After a room: where next.
    nextBtn.hidden = !solvedNow;
    nextBtn.textContent = mode === 'rite' ? 'Down the stair to Solarin' : 'Back to the hall';
    noteEl.innerHTML = mode === 'hall'
      ? NOTES.hall + (bridgeWhole() ? ' <strong>The bridge is whole.</strong> Tap the Door of Shadow on the far ledge.' : '')
      : solvedNow ? (mode === 'solarin' ? '<strong>Solarin is calmed.</strong> That is the whole prototype.' : mode === 'rite' ? '<strong>The door is open.</strong>' : '<strong>Solved.</strong> Go back to the hall.') : NOTES[mode];
  }

  function enter(m) {
    mode = m;
    if (m !== 'hall' && m !== 'key' && !grids[m]) grids[m] = newGrid(m);
    if (m === 'key' && !KR) KR = newKey();
    if (m === 'hall' && pendingSpan) { spanAt.set(pendingSpan, time + .35); pendingSpan = null; }
    say('');
    size(); sync();
  }

  actBtn.onclick = () => { if (mode === 'hall') return; if (mode === 'key') actKey('pin'); else pinGrid(grids[mode]); };
  act2Btn.onclick = () => { if (mode === 'hall') return; if (mode === 'key') actKey('veil'); else veilGrid(grids[mode]); };
  act3Btn.onclick = () => { const g = grids[mode]; if (!g) return; if (g.R.rail) crankGrid(g); else strikeGrid(g); };
  resetBtn.onclick = () => {
    if (mode === 'hall') return;
    if (mode === 'key') KR = newKey(); else grids[mode] = newGrid(mode);
    say('The room is as it was.'); sync();
  };
  nextBtn.onclick = () => enter(mode === 'rite' ? 'solarin' : 'hall');
  window.addEventListener('resize', size);

  enter('hall');
  requestAnimationFrame(frame);
})();
