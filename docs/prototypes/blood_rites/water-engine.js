// THE TURNING ROOM (Water) — rules shared by the page and the solver.
//
// The room has a DOWNHILL. Blood turns the room over (FLIP) and downhill
// becomes uphill. Everything loose slides downhill one square at a time
// until something stops it: ice straight down its line, and water too — but
// water that lands runs along the floor to the nearest place it can drop
// (west wins a tie). Blood stops things too: anything that
// slides into Blood rests against it, and when Blood steps aside it carries
// on falling.
//
// Fire + Ice → Water. An ice block that comes to rest touching a lit brazier
// melts into water where it stands. Water touching fire puts it out — so the
// meltwater puts out the brazier that made it, and any water that runs past
// a brazier puts that one out too. Every brazier melts at most one block.
//
// Water runs through grates; ice and Blood do not. Anything loose that slides
// over a pit drops in and fills it, and a filled pit is floor. The captive
// lies in a dry basin; fill every basin square with water and the rite is
// done. Ice never goes into the basin: its rim stops ice like a step.
//
// THE VAULT: ice that drops into a pit fills it as floor. Water that drops
// into a pit makes it a deep POOL instead — the room's commonest mistake
// (that water is lost, and the room can't be finished) — and Blood can step
// into the pool and dive down to the vault.
//
// There is no water in the room at the start.
//
// Map legend (y down; downhill starts SOUTH):
//   #  wall     .  floor     B  Blood (start)
//   I  ice      ~  water     F  lit brazier     f  spent brazier
//   =  grate    _  pit       C  the captive's basin (dry)
//   p  a pit flooded with water: a deep pool, the way down to the vault
(function (root) {
  const DX = [0, 1, 0, -1], DY = [-1, 0, 1, 0]; // N E S W

  function parseRoom(def) {
    const H = def.map.length, W = def.map[0].length;
    const fixed = [], loose = [];
    let blood = null;
    for (let y = 0; y < H; y++) {
      fixed.push([]);
      for (let x = 0; x < W; x++) {
        let ch = def.map[y][x];
        if (ch === 'B') { blood = [x, y]; ch = '.'; }
        if (ch === 'I' || ch === '~') { loose.push([x, y, ch]); ch = '.'; }
        fixed[y].push(ch);
      }
    }
    return { def, W, H, fixed, loose0: loose, blood0: blood };
  }

  // State: { down: 2 (S) or 0 (N), b: [x,y], cells: string grid of fixed
  // squares that change (F→f, _→. , C→c full), loose: Map 'x,y' → 'I'|'~' }
  function start(R) {
    const S = {
      down: 2,
      b: R.blood0.slice(),
      cells: R.fixed.map((r) => r.slice()),
      loose: new Map(R.loose0.map(([x, y, ch]) => [x + ',' + y, ch])),
    };
    settle(R, S, []);
    return S;
  }

  function clone(S) {
    return { down: S.down, b: S.b.slice(), cells: S.cells.map((r) => r.slice()), loose: new Map(S.loose) };
  }

  // Can a loose thing of kind k move into (x,y)?
  function canEnter(S, k, x, y) {
    const ch = S.cells[y][x];
    if (S.b[0] === x && S.b[1] === y) return false;
    if (S.loose.has(x + ',' + y)) return false;
    if (ch === '.' || ch === '_' || ch === 'c' || ch === 'p') return true; // 'c' = a full basin square, floor now
    if (ch === '=') return k === '~';
    if (ch === 'C') return k === '~';
    return false;
  }

  // Slide everything downhill until nothing moves; then melt and douse;
  // repeat until the room is still. `log` collects events for the page.
  function settle(R, S, log, frames) {
    for (let guard = 0; guard < 200; guard++) {
      let moved = slideAll(R, S, log, frames);
      const changed = react(R, S, log);
      if (changed && frames) frames.push(snap(S));
      if (!moved && !changed) return;
    }
  }

  // A picture of the loose things and changing squares, for the page to
  // play back one pass at a time.
  function snap(S) {
    return { cells: S.cells.map((r) => r.slice()), loose: new Map(S.loose) };
  }

  function slideAll(R, S, log, frames) {
    const dy = DY[S.down];
    let any = false;
    for (let pass = 0; pass < 100; pass++) {
      let moved = false;
      // Downhill-most first, so a column falls together.
      const keys = [...S.loose.keys()].map((k) => k.split(',').map(Number));
      keys.sort((a, b) => (b[1] - a[1]) * dy);
      for (const [x, y] of keys) {
        const k = S.loose.get(x + ',' + y);
        if (!k) continue;
        let nx = x, ny = y + dy;
        if (ny < 0 || ny >= R.H || !canEnter(S, k, x, ny)) {
          // Ice stays put. Water runs sideways along the floor towards the
          // nearest place it can drop (west wins a tie).
          if (k !== '~') continue;
          const side = runTo(R, S, x, y, dy);
          if (!side) continue;
          nx = x + side; ny = y;
        }
        S.loose.delete(x + ',' + y);
        const ch = S.cells[ny][nx];
        if (ch === '_') { S.cells[ny][nx] = k === '~' ? 'p' : '.'; log.push({ t: 'pit', x: nx, y: ny, k }); }
        else if (ch === 'C') { S.cells[ny][nx] = 'c'; log.push({ t: 'basin', x: nx, y: ny }); }
        else S.loose.set(nx + ',' + ny, k);
        moved = any = true;
      }
      if (!moved) break;
      if (frames) frames.push(snap(S));
    }
    return any;
  }

  // Which way (−1 west, +1 east, 0 stay) a landed water unit runs: towards
  // the nearest square along its row that it can reach and drop from (or a
  // pit/basin it can run straight into).
  function runTo(R, S, x, y, dy) {
    let best = 0, bestD = Infinity;
    for (const s of [-1, 1]) {
      for (let d = 1; d < R.W; d++) {
        const cx = x + s * d;
        if (!canEnter(S, '~', cx, y)) break;
        const ch = S.cells[y][cx];
        const sink = ch === '_' || ch === 'C';
        const ny = y + dy;
        const drop = sink || (ny >= 0 && ny < R.H && canEnter(S, '~', cx, ny));
        if (drop) { if (d < bestD) { bestD = d; best = s; } break; }
      }
    }
    return best;
  }

  function react(R, S, log) {
    let changed = false;
    // Ice touching a lit brazier melts.
    for (const [key, k] of [...S.loose]) {
      if (k !== 'I') continue;
      const [x, y] = key.split(',').map(Number);
      if (touches(S, x, y, 'F')) { S.loose.set(key, '~'); log.push({ t: 'melt', x, y }); changed = true; }
    }
    // Water touching a lit brazier puts it out.
    for (const [key, k] of S.loose) {
      if (k !== '~') continue;
      const [x, y] = key.split(',').map(Number);
      for (let d = 0; d < 4; d++) {
        const nx = x + DX[d], ny = y + DY[d];
        if (S.cells[ny] && S.cells[ny][nx] === 'F') { S.cells[ny][nx] = 'f'; log.push({ t: 'douse', x: nx, y: ny }); changed = true; }
      }
    }
    return changed;
  }

  function touches(S, x, y, ch) {
    for (let d = 0; d < 4; d++) if (S.cells[y + DY[d]] && S.cells[y + DY[d]][x + DX[d]] === ch) return true;
    return false;
  }

  function walkable(S, x, y) {
    const ch = S.cells[y] && S.cells[y][x];
    return (ch === '.' || ch === 'c') && !S.loose.has(x + ',' + y);
  }

  // Blood steps one square. Afterwards everything settles (something resting
  // on Blood may now fall).
  function step(R, S, d, frames) {
    const x = S.b[0] + DX[d], y = S.b[1] + DY[d];
    if (!walkable(S, x, y)) return { why: 'blocked' };
    const N = clone(S);
    N.b = [x, y];
    const log = [];
    settle(R, N, log, frames);
    return { S: N, log };
  }

  function flip(R, S, frames) {
    const N = clone(S);
    N.down = S.down === 2 ? 0 : 2;
    const log = [];
    settle(R, N, log, frames);
    return { S: N, log };
  }

  function solved(R, S) {
    return !S.cells.some((r) => r.includes('C'));
  }

  function key(S) {
    return S.down + '|' + S.b + '|' + S.cells.map((r) => r.join('')).join('') + '|' + [...S.loose].sort().join(';');
  }

  // Breadth-first search over Blood's steps and flips. A plan is a list of
  // 'N','E','S','W','flip'.
  function solve(R, opts) {
    opts = opts || {};
    const S0 = start(R);
    const seen = new Map([[key(S0), null]]);
    let frontier = [S0];
    const parent = new Map();
    let states = 0;
    const max = opts.max || 3e6;
    let goal = null;
    while (frontier.length && !goal) {
      const next = [];
      for (const S of frontier) {
        const ks = key(S);
        const moves = ['flip', 0, 1, 2, 3];
        for (const m of moves) {
          const r = m === 'flip' ? flip(R, S) : step(R, S, m);
          if (r.why) continue;
          const k = key(r.S);
          if (seen.has(k)) continue;
          seen.set(k, { from: ks, m });
          if (++states > max) return { solvable: 'unknown', states };
          if (solved(R, r.S)) { goal = k; break; }
          next.push(r.S);
        }
        if (goal) break;
      }
      frontier = next;
    }
    if (!goal) return { solvable: false, states };
    const plan = [];
    for (let k = goal; seen.get(k); k = seen.get(k).from) plan.unshift(seen.get(k).m);
    const names = ['N', 'E', 'S', 'W'];
    return { solvable: true, states, plan: plan.map((m) => (m === 'flip' ? 'flip' : names[m])), steps: plan.length, flips: plan.filter((m) => m === 'flip').length };
  }


  // The whole state graph: is the room solvable, the fewest FLIPS it takes
  // (walking is free), the share of reachable states that can no longer
  // finish (dead ends), and whether the plan needs Blood to hold something
  // (an event fires when Blood steps aside).
  function graph(R, max) {
    const S0 = start(R);
    const idx = new Map([[key(S0), 0]]), states = [S0], edges = [[]], goals = [];
    for (let i = 0; i < states.length; i++) {
      if (states.length > (max || 2e5)) return null;
      const S = states[i];
      if (solved(R, S)) { goals.push(i); continue; }
      for (const m of ['flip', 0, 1, 2, 3]) {
        const r = m === 'flip' ? flip(R, S) : step(R, S, m);
        if (r.why) continue;
        const k = key(r.S);
        let j = idx.get(k);
        if (j == null) { j = states.length; idx.set(k, j); states.push(r.S); edges.push([]); }
        edges[i].push([j, m, r.log.length > 0]);
      }
    }
    const rev = states.map(() => []);
    edges.forEach((es, i) => es.forEach(([j]) => rev[j].push(i)));
    const live = new Uint8Array(states.length);
    const q = goals.slice();
    goals.forEach((g) => (live[g] = 1));
    while (q.length) { const j = q.pop(); for (const i of rev[j]) if (!live[i]) { live[i] = 1; q.push(i); } }
    // Fewest flips first, then fewest steps (lexicographic 0-1 BFS).
    const cost = (c) => c[0] * 1e4 + c[1];
    const dist = states.map(() => [Infinity, Infinity]), prev = states.map(() => null);
    dist[0] = [0, 0];
    const dq = [0];
    while (dq.length) {
      dq.sort((a, b) => cost(dist[a]) - cost(dist[b]));
      const i = dq.shift();
      for (const [j, m, ev] of edges[i]) {
        const c = [dist[i][0] + (m === 'flip' ? 1 : 0), dist[i][1] + 1];
        if (cost(c) < cost(dist[j])) { dist[j] = c; prev[j] = [i, m, ev]; dq.push(j); }
      }
    }
    const g = goals.reduce((b, x) => (b == null || cost(dist[x]) < cost(dist[b]) ? x : b), null);
    const plan = [];
    let held = false;
    for (let j = g; j != null && prev[j]; j = prev[j][0]) {
      const [, m, ev] = prev[j];
      plan.unshift(m === 'flip' ? 'flip' : 'NESW'[m]);
      if (m !== 'flip' && ev) held = true;
    }
    return {
      states: states.length, solvable: live[0] === 1, flips: g == null ? 0 : dist[g][0],
      plan, held, dead: states.filter((_, i) => !live[i]).length / states.length,
      live: new Set(states.filter((_, i) => live[i]).map(key)),
    };
  }

  // Can Blood dive into a flooded pit from where it stands?
  function diveFrom(S) {
    for (let d = 0; d < 4; d++) {
      const x = S.b[0] + DX[d], y = S.b[1] + DY[d];
      if (S.cells[y] && S.cells[y][x] === 'p' && !S.loose.has(x + ',' + y)) return d;
    }
    return -1;
  }

  const api = { DX, DY, parseRoom, start, step, flip, solved, solve, graph, key, walkable, canEnter, diveFrom };
  if (typeof module !== 'undefined') module.exports = api; else root.WaterEngine = api;
})(this);
