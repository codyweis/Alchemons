// THE TENDRIL ROOM (Earth) — rules shared by the page and the solver.
//
// Blood tendrils grow out of the walls in pairs. Blood leads each one across
// the floor to its partner. Two tendrils never share a square, so they never
// cross. The floor is laid in TURNING PLATES: a plate turns a quarter round
// its axle, and everything standing on it turns with it (the stone on it,
// the stump on it, the captive's hearth). A plate will not turn while a
// tendril lies on it.
//
// The fusion: the last two tendrils are not a pair. One runs with Dust and
// one with Water, and both must be led to the captive. Dust + Water → Earth.
//
// Map legend (one char per square, y down):
//   #  wall            .  floor             X  stone standing on a plate
//   a..k  a blood root (two of each letter make a pair)
//   d  the Dust root   w  the Water root    C  the captive (needs d and w)
//   o  a plate's axle (the centre of a 3×3 plate; solid)
(function (root) {
  const DX = [0, 1, 0, -1], DY = [-1, 0, 1, 0]; // north east south west

  function parseRoom(def) {
    const H = def.map.length, W = def.map[0].length;
    const base = def.map.map((r) => r.split(''));
    const plates = [];
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      if (base[y][x] === 'o') plates.push({ cx: x, cy: y });
    }
    return { def, W, H, base, plates };
  }

  // The squares as they stand with each plate turned `turns[i]` quarters
  // clockwise.
  function grid(R, turns) {
    const g = R.base.map((r) => r.slice());
    R.plates.forEach((p, i) => {
      const t = ((turns[i] || 0) % 4 + 4) % 4;
      if (!t) return;
      const src = [];
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        src.push([dx, dy, R.base[p.cy + dy][p.cx + dx]]);
      }
      for (const [dx, dy, ch] of src) {
        let x = dx, y = dy;
        for (let k = 0; k < t; k++) { const nx = -y, ny = x; x = nx; y = ny; }
        g[p.cy + y][p.cx + x] = ch;
      }
    });
    return g;
  }

  const isTerminal = (ch) => /[a-kdwC]/.test(ch);
  const isOpen = (ch) => ch === '.';

  function plateOf(R, x, y) {
    for (let i = 0; i < R.plates.length; i++) {
      const p = R.plates[i];
      if (Math.abs(x - p.cx) <= 1 && Math.abs(y - p.cy) <= 1) return i;
    }
    return -1;
  }

  // The jobs: every pair joined; d and w each led to C.
  function jobs(g) {
    const at = {};
    g.forEach((row, y) => row.forEach((ch, x) => {
      if (isTerminal(ch)) (at[ch] = at[ch] || []).push([x, y]);
    }));
    const list = [];
    for (const k of Object.keys(at).sort()) {
      if (k === 'C' || k === 'd' || k === 'w') continue;
      if (at[k].length === 2) list.push({ id: k, a: at[k][0], b: at[k][1] });
    }
    if (at.C) {
      if (at.d) list.push({ id: 'd', a: at.d[0], b: at.C[0] });
      if (at.w) list.push({ id: 'w', a: at.w[0], b: at.C[0] });
    }
    return list;
  }

  // ── Play state ─────────────────────────────────────────
  // lines: { id: [[x,y], ...] } — each from its root, through floor squares.
  function start(R) {
    return { turns: R.plates.map(() => 0), lines: {} };
  }

  function occupied(S, except) {
    const o = new Map();
    for (const [id, pts] of Object.entries(S.lines)) {
      if (id === except) continue;
      for (const [x, y] of pts) o.set(x + ',' + y, id);
    }
    return o;
  }

  function lineOnPlate(R, S, i) {
    for (const pts of Object.values(S.lines)) {
      for (const [x, y] of pts) if (plateOf(R, x, y) === i) return true;
    }
    return false;
  }

  function turn(R, S, i) {
    if (lineOnPlate(R, S, i)) return { why: 'A tendril lies across that plate.' };
    const turns = S.turns.slice();
    turns[i] = (turns[i] + 1) % 4;
    return { S: { turns, lines: S.lines } };
  }

  // Extend (or retract) line `id` to square (x,y). The first point of a line
  // is its root; the target of a d/w line is the captive.
  // A pair can be led from EITHER root (Dust and Water only from their own
  // root — the captive is not a root); `from` is the root it was taken from.
  function extend(R, S, id, x, y, from) {
    const g = grid(R, S.turns);
    const J = jobs(g).find((j) => j.id === id);
    if (!J) return { why: 'No such tendril.' };
    const start = from || J.a;
    const isB = start[0] === J.b[0] && start[1] === J.b[1];
    if (!S.lines[id] && !(start[0] === J.a[0] && start[1] === J.a[1]) && (!isB || id === 'd' || id === 'w')) return { why: 'No such tendril.' };
    const pts = (S.lines[id] || [start]).slice();
    const [tx, ty] = pts[pts.length - 1];
    if (Math.abs(tx - x) + Math.abs(ty - y) !== 1) return { why: 'One square at a time.' };
    const back = pts.length > 1 && pts[pts.length - 2][0] === x && pts[pts.length - 2][1] === y;
    if (back) { pts.pop(); return { S: withLine(S, id, pts) }; }
    if (done(g, J, pts)) return { why: 'That tendril is already joined.' };
    const ch = g[y][x];
    const far = pts[0][0] === J.b[0] && pts[0][1] === J.b[1] ? J.a : J.b;
    const goal = x === far[0] && y === far[1];
    if (!goal && !isOpen(ch)) return { why: 'blocked' };
    if (pts.some(([px, py]) => px === x && py === y)) return { why: 'A tendril cannot cross itself.' };
    if (!goal && occupied(S, id).has(x + ',' + y)) return { why: 'Tendrils never cross.' };
    pts.push([x, y]);
    return { S: withLine(S, id, pts) };
  }

  function withLine(S, id, pts) {
    const lines = { ...S.lines };
    if (pts.length <= 1) delete lines[id]; else lines[id] = pts;
    return { turns: S.turns, lines };
  }

  function clear(S, id) { return withLine(S, id, []); }

  function done(g, J, pts) {
    if (!pts || pts.length < 2) return false;
    const [x, y] = pts[pts.length - 1];
    const [sx, sy] = pts[0];
    const fromA = sx === J.a[0] && sy === J.a[1];
    const far = fromA ? J.b : J.a;
    return x === far[0] && y === far[1];
  }

  function solved(R, S) {
    const g = grid(R, S.turns);
    return jobs(g).every((J) => done(g, J, S.lines[J.id]));
  }

  // ── The solver ─────────────────────────────────────────
  // For one set of plate turns: find vertex-disjoint paths for every job
  // (backtracking with a connectivity prune). Returns the paths or null.
  function route(R, turns, limit) {
    const g = grid(R, turns);
    const J = jobs(g);
    const { W, H } = R;
    const used = new Uint8Array(W * H);
    const open = (x, y) => x >= 0 && y >= 0 && x < W && y < H && isOpen(g[y][x]) && !used[y * W + x];
    let budget = limit || 2e6;
    const paths = [];

    // Can every unfinished job still reach its goal through free squares?
    function viable(from, tip) {
      for (let j = from; j < J.length; j++) if (!reach(j === from && tip ? tip : J[j].a, J[j].b)) return false;
      return true;
    }
    function reach(a, b) {
      const seen = new Uint8Array(W * H);
      const q = [a];
      seen[a[1] * W + a[0]] = 1;
      while (q.length) {
        const [x, y] = q.pop();
        for (let d = 0; d < 4; d++) {
          const nx = x + DX[d], ny = y + DY[d];
          if (nx === b[0] && ny === b[1]) return true;
          if (open(nx, ny) && !seen[ny * W + nx]) { seen[ny * W + nx] = 1; q.push([nx, ny]); }
        }
      }
      return false;
    }
    function touchesSelf(path, nx, ny) {
      for (let i = 0; i < path.length - 1; i++) {
        if (Math.abs(path[i][0] - nx) + Math.abs(path[i][1] - ny) === 1) return true;
      }
      return false;
    }
    function go(j, path) {
      if (--budget < 0) throw new Error('budget');
      const job = J[j];
      const [x, y] = path[path.length - 1];
      for (let d = 0; d < 4; d++) {
        const nx = x + DX[d], ny = y + DY[d];
        if (nx === job.b[0] && ny === job.b[1]) {
          paths[j] = path.concat([[nx, ny]]);
          if (j + 1 === J.length) return true;
          if (viable(j + 1) && go(j + 1, [J[j + 1].a])) return true;
          continue;
        }
        if (!open(nx, ny)) continue;
        // A path never needs to touch itself: any solution can be shortcut
        // to one that doesn't, and shortcutting only frees squares.
        if (touchesSelf(path, nx, ny)) continue;
        used[ny * W + nx] = 1;
        path.push([nx, ny]);
        if (viable(j, [nx, ny]) && go(j, path)) return true;
        path.pop();
        used[ny * W + nx] = 0;
      }
      return false;
    }
    try {
      if (!J.length || !viable(0)) return null;
      return go(0, [J[0].a]) ? Object.fromEntries(J.map((job, i) => [job.id, paths[i]])) : null;
    } catch (e) { return undefined; }
  }

  // Every combination of plate turns; which ones can be routed.
  function solve(R, fixed) {
    const n = R.plates.length, out = [];
    for (let k = 0; k < 4 ** n; k++) {
      const turns = [];
      let v = k;
      for (let i = 0; i < n; i++) { turns.push(v % 4); v = Math.floor(v / 4); }
      if (fixed && turns.some((t, i) => fixed[i] != null && t !== fixed[i])) continue;
      const p = route(R, turns);
      out.push({ turns, solvable: p === undefined ? 'unknown' : !!p, paths: p });
    }
    return out;
  }

  const api = { DX, DY, parseRoom, grid, jobs, plateOf, start, turn, extend, clear, solved, route, solve, isTerminal };
  if (typeof module !== 'undefined') module.exports = api; else root.EarthEngine = api;
})(this);
