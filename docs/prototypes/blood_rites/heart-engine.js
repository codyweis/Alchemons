// THE HEART (the fifth rite) — rules shared by the page and the solver.
//
// The author's design (2026-10-06). Once all four captives are freed, the
// seal in the Circle opens on the Heart. Blood goes in, comes apart and is
// bound across the room; the four it freed pour in and stand on the stage.
// Fire, Water, Earth and Air can make everything between them, so the room
// is the game's own recipe table, played out — all the way up to Blood.
//
//   · Two standing together on an ALTAR fuse: the pair is gone, and a
//     creature of what they make (a random species of that element) stands
//     on the altar's front stone. The game's recipes, main result only — a
//     right answer always works (no chance in puzzles). A pair with no
//     recipe doesn't fuse.
//   · As it forms, its POWER shoots down the altar's lane and hits the first
//     thing in the way. Each element has its own power (Steam melts ice,
//     Lightning shatters crystal, Mud fills a chasm, …); against anything
//     else it only splashes.
//   · Everything in the way is HOLDING an element. Break it and what was
//     inside steps out and joins you (a Crystal out of the crystal wall, the
//     Lava frozen in the ice, the Spirit down the chasm).
//   · The SPLIT STAGE takes a fused creature apart into the two that made
//     it — so nothing is used up for good, and fusing again fires a power
//     again.
//   · LIGHT + DARK make BLOOD, and Blood made here frees the Blood that was
//     taken. (Light is Crystal + Spirit; Dark is Poison + Spirit.)
//
// Map legend (y down):
//   #  wall     .  floor     S  the split stage     B  Blood, bound
//   f w e a  where Fire, Water, Earth and Air start
//   in the way:  I ice wall   T blood-thorn   K crystal wall   _ a chasm
//                ^ blood-fire   ~ a pool
// What each thing holds is in the room data (`holds`, 'x,y' → element).
// Altars are in the room data too: {back:[x,y], front:[x,y]}; the power
// leaves the front stone in the direction back → front.
(function (root) {
  const DX = [0, 1, 0, -1], DY = [-1, 0, 1, 0];
  const BASE = ['Fire', 'Water', 'Earth', 'Air'];
  const START = { f: 'Fire', w: 'Water', e: 'Earth', a: 'Air' };

  // assets/data/alchemons_element_recipes.json, each pair's main result
  // (solve.js checks this copy against the file).
  const RECIPES = {
    'Fire+Water': 'Steam', 'Earth+Fire': 'Lava', 'Earth+Water': 'Mud',
    'Air+Water': 'Ice', 'Air+Earth': 'Dust', 'Air+Fire': 'Lightning',
    'Fire+Ice': 'Water', 'Crystal+Spirit': 'Light', 'Poison+Spirit': 'Dark',
    'Dark+Light': 'Blood', 'Lava+Mud': 'Poison', 'Crystal+Lightning': 'Spirit',
    'Dark+Plant': 'Poison', 'Fire+Plant': 'Dust', 'Earth+Lightning': 'Crystal',
    'Spirit+Water': 'Ice', 'Air+Spirit': 'Lightning', 'Earth+Spirit': 'Crystal',
    'Fire+Spirit': 'Steam', 'Air+Lava': 'Fire', 'Lightning+Plant': 'Fire',
    'Earth+Light': 'Plant', 'Light+Spirit': 'Air', 'Dust+Water': 'Earth',
    'Crystal+Lava': 'Earth', 'Light+Poison': 'Fire', 'Air+Ice': 'Water',
    'Dust+Steam': 'Water', 'Dust+Mud': 'Earth', 'Ice+Light': 'Air',
    'Ice+Lava': 'Steam', 'Fire+Mud': 'Lava', 'Ice+Water': 'Steam',
    'Earth+Poison': 'Lava', 'Plant+Water': 'Mud', 'Air+Crystal': 'Ice',
    'Air+Mud': 'Dust', 'Ice+Poison': 'Crystal', 'Light+Mud': 'Plant',
    'Mud+Plant': 'Poison', 'Dark+Water': 'Spirit',
  };
  const recipe = (a, b) => RECIPES[[a, b].sort().join('+')] || null;

  // What each element's power breaks. Against anything else it splashes.
  const POWERS = {
    Steam: 'I', // scalds the ice away
    Fire: 'IT', // melts ice, burns the thorn
    Lava: 'IT', // melts ice, burns the thorn
    Mud: '_', // fills a chasm
    Earth: '_', // fills a chasm
    Ice: '~', // freezes a pool solid
    Dust: '^', // smothers blood-fire
    Water: '^', // puts blood-fire out
    Lightning: 'K', // shatters crystal
    Poison: 'T', // withers the thorn
  };
  const breaks = (el, ch) => (POWERS[el] || '').includes(ch);
  const WALK = new Set(['.', 'S']);
  const OBSTACLE = new Set(['I', 'T', 'K', '_', '^', '~']);

  function parseRoom(def) {
    const cells = def.map.map((r) => r.split(''));
    const H = cells.length, W = cells[0].length;
    const starts = [];
    let blood = null;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const ch = cells[y][x];
      if (START[ch]) { starts.push({ el: START[ch], at: [x, y] }); cells[y][x] = '.'; }
      if (ch === 'B') blood = [x, y];
    }
    const altars = def.altars.map((a) => ({
      back: a.back, front: a.front,
      d: DX.findIndex((dx, i) => dx === a.front[0] - a.back[0] && DY[i] === a.front[1] - a.back[1]),
    }));
    starts.sort((p, q) => BASE.indexOf(p.el) - BASE.indexOf(q.el));
    return { cells, W, H, starts, blood, altars, holds: Object.assign({}, def.holds || {}) };
  }

  /// A creature: its element and, if it was made, the two it was made of.
  const mk = (el, parts, at) => ({ el, parts: parts || null, at: at.slice() });
  const sig = (c) => (c.parts ? `${c.el}(${sig(c.parts[0])},${sig(c.parts[1])})` : c.el);

  function start(R) {
    return { cells: R.cells.map((r) => r.slice()), holds: Object.assign({}, R.holds), cs: R.starts.map((s) => mk(s.el, null, s.at)) };
  }
  const copy = (S) => ({ cells: S.cells.map((r) => r.slice()), holds: Object.assign({}, S.holds), cs: S.cs.slice() });

  function walkable(R, cells, x, y) {
    return x >= 0 && y >= 0 && x < R.W && y < R.H && WALK.has(cells[y][x]);
  }

  function reach(R, cells, x, y) {
    const seen = new Set([x + ',' + y]), q = [[x, y]];
    while (q.length) {
      const [cx, cy] = q.pop();
      for (let d = 0; d < 4; d++) {
        const nx = cx + DX[d], ny = cy + DY[d], k = nx + ',' + ny;
        if (!seen.has(k) && walkable(R, cells, nx, ny)) { seen.add(k); q.push([nx, ny]); }
      }
    }
    return seen;
  }

  /// A shortest walk from a to b (array of [x,y], a first), or null.
  function path(R, cells, a, b) {
    const prev = new Map([[a.join(','), null]]), q = [a];
    for (let i = 0; i < q.length; i++) {
      const [cx, cy] = q[i];
      if (cx === b[0] && cy === b[1]) {
        const out = [];
        for (let k = cx + ',' + cy; k; k = prev.get(k)) out.unshift(k.split(',').map(Number));
        return out;
      }
      for (let d = 0; d < 4; d++) {
        const nx = cx + DX[d], ny = cy + DY[d], k = nx + ',' + ny;
        if (!prev.has(k) && walkable(R, cells, nx, ny)) { prev.set(k, cx + ',' + cy); q.push([nx, ny]); }
      }
    }
    return null;
  }

  /// The connected run of one obstacle at (x, y) — a whole wall goes at once.
  function group(R, cells, x, y) {
    const ch = cells[y][x], out = [[x, y]], seen = new Set([x + ',' + y]);
    for (let i = 0; i < out.length; i++) {
      for (let d = 0; d < 4; d++) {
        const nx = out[i][0] + DX[d], ny = out[i][1] + DY[d], k = nx + ',' + ny;
        if (nx < 0 || ny < 0 || nx >= R.W || ny >= R.H || seen.has(k)) continue;
        if (cells[ny][nx] === ch) { seen.add(k); out.push([nx, ny]); }
      }
    }
    return out;
  }

  /// Where a power runs from altar [A]: the squares it crosses, then the
  /// first thing in the way — {path, hit, ch, broke}.
  function power(R, cells, A, el) {
    const d = A.d, run = [];
    let x = A.front[0] + DX[d], y = A.front[1] + DY[d];
    while (x >= 0 && y >= 0 && x < R.W && y < R.H) {
      const ch = cells[y][x];
      if (OBSTACLE.has(ch)) return { path: run, hit: [x, y], ch, broke: breaks(el, ch) };
      if (!WALK.has(ch)) return { path: run, hit: [x, y], ch, broke: false };
      run.push([x, y]);
      x += DX[d]; y += DY[d];
    }
    return { path: run, hit: null, ch: null, broke: false };
  }

  /// Fuse creatures i (on the back stone) and j (on the front stone) of
  /// altar [ai]. Returns {S, made, run, freed:[creature], blood} or {why}.
  function fuse(R, S, ai, i, j) {
    const A = R.altars[ai], a = S.cs[i], b = S.cs[j];
    const el = recipe(a.el, b.el);
    if (!el) return { why: `${a.el} and ${b.el} don't fuse` };
    const n = copy(S);
    const made = mk(el, [a, b], A.front);
    n.cs = n.cs.filter((_, k) => k !== i && k !== j).concat([made]);
    if (el === 'Blood') return { S: n, made, run: { path: [], hit: null, ch: null, broke: false, changed: [] }, freed: [], blood: true };
    const run = power(R, n.cells, A, el);
    run.changed = [];
    const freed = [];
    if (run.broke) {
      for (const [x, y] of group(R, n.cells, run.hit[0], run.hit[1])) {
        n.cells[y][x] = '.';
        run.changed.push([x, y]);
        const held = n.holds[x + ',' + y];
        if (held) { delete n.holds[x + ',' + y]; const c = mk(held, null, [x, y]); c.freedFrom = run.ch; freed.push(c); }
      }
      n.cs = n.cs.concat(freed);
    }
    return { S: n, made, run, freed, blood: false };
  }

  /// Take creature i apart on the split stage at (x, y).
  function split(R, S, i, x, y) {
    const c = S.cs[i];
    if (!c.parts) return { why: `${c.el} isn't made of anything` };
    const n = copy(S);
    let other = [x, y];
    for (let d = 0; d < 4; d++) if (walkable(R, n.cells, x + DX[d], y + DY[d])) { other = [x + DX[d], y + DY[d]]; break; }
    const [p, q] = c.parts;
    n.cs = n.cs.filter((_, k) => k !== i).concat([mk(p.el, p.parts, [x, y]), mk(q.el, q.parts, other)]);
    return { S: n, parts: [p, q] };
  }

  // ── THE PROOF ────────────────────────────────────────────
  // Walking is free, so a creature is only ever WHERE it can get to: its
  // region. A state is what is still in the way plus each creature's
  // make-up and region. A move is a fusion on an altar (both stones
  // reachable by the two) or a split on the stage. Blood made is the goal.
  function regions(R, cells) {
    const id = R.cells.map((r) => r.map(() => -1));
    let n = 0;
    for (let y = 0; y < R.H; y++) for (let x = 0; x < R.W; x++) {
      if (id[y][x] >= 0 || !walkable(R, cells, x, y)) continue;
      for (const k of reach(R, cells, x, y)) { const [cx, cy] = k.split(',').map(Number); id[cy][cx] = n; }
      n++;
    }
    return id;
  }

  /// Breadth-first by moves. opts.ban: elements that may not be made;
  /// opts.max: state cap; opts.all: explore everything (no early stop).
  function solve(R, opts = {}) {
    const ban = new Set(opts.ban || []), max = opts.max || 2e6;
    const s0 = start(R);
    const splitAt = [];
    for (let y = 0; y < R.H; y++) for (let x = 0; x < R.W; x++) if (R.cells[y][x] === 'S') splitAt.push([x, y]);
    const keyOf = (S, reg) => S.cells.map((r) => r.join('')).join('') + '|' +
      S.cs.map((c) => sig(c) + '@' + reg[c.at[1]][c.at[0]]).sort().join(';');
    const seen = new Map(), q = [];
    const k0 = keyOf(s0, regions(R, s0.cells));
    seen.set(k0, null); q.push({ S: s0, k: k0 });
    const made = new Set();
    let goal = null, fewest = null;
    for (let i = 0; i < q.length && seen.size < max; i++) {
      const { S, k } = q[i];
      if (S.cs.some((c) => c.el === 'Blood')) {
        if (!goal) goal = k;
        if (!opts.all) break;
        continue;
      }
      const reg = regions(R, S.cells);
      const rOf = (c) => reg[c.at[1]][c.at[0]];
      const nexts = [];
      R.altars.forEach((A, ai) => {
        const rb = reg[A.back[1]][A.back[0]], rf = reg[A.front[1]][A.front[0]];
        if (rb < 0 || rf < 0) return;
        for (let a = 0; a < S.cs.length; a++) for (let b = 0; b < S.cs.length; b++) {
          if (a === b || rOf(S.cs[a]) !== rb || rOf(S.cs[b]) !== rf) continue;
          if (a > b && rb === rf) continue;
          const el = recipe(S.cs[a].el, S.cs[b].el);
          if (!el || ban.has(el)) continue;
          const T = { cells: S.cells, holds: S.holds, cs: S.cs.map((c, kk) => (kk === a ? mk(c.el, c.parts, A.back) : kk === b ? mk(c.el, c.parts, A.front) : c)) };
          const r = fuse(R, T, ai, a, b);
          made.add(el);
          const freed = r.freed.map((c) => c.el).join('+');
          nexts.push({ S: r.S, how: `${S.cs[a].el}+${S.cs[b].el}→${el} on altar ${ai + 1}${r.run.broke ? ` (breaks ${r.run.ch}${freed ? `, frees ${freed}` : ''})` : ''}` });
        }
      });
      for (const [sx, sy] of splitAt) {
        const rs = reg[sy][sx];
        S.cs.forEach((c, ci) => {
          if (!c.parts || rOf(c) !== rs) return;
          nexts.push({ S: split(R, S, ci, sx, sy).S, how: `split ${c.el}` });
        });
      }
      for (const nx of nexts) {
        const kk = keyOf(nx.S, regions(R, nx.S.cells));
        if (seen.has(kk)) continue;
        seen.set(kk, { from: k, how: nx.how });
        q.push({ S: nx.S, k: kk });
      }
    }
    if (!goal) return { solvable: false, states: seen.size, made: [...made].sort(), capped: seen.size >= max };
    const plan = [];
    for (let k = goal; seen.get(k); k = seen.get(k).from) plan.unshift(seen.get(k).how);
    return {
      solvable: true, states: seen.size, steps: plan.length,
      fusions: plan.filter((p) => !p.startsWith('split')).length,
      splits: plan.filter((p) => p.startsWith('split')).length,
      plan, made: [...made].sort(),
    };
  }

  const api = {
    DX, DY, BASE, RECIPES, POWERS, WALK, OBSTACLE, recipe, breaks, parseRoom, start, walkable, reach,
    path, power, group, fuse, split, solve, sig,
  };
  if (typeof module !== 'undefined') module.exports = api; else root.HeartEngine = api;
})(this);
