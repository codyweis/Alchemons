// THE TWIN (Fire) — rules shared by the page and the solver.
//
// A pool of blood runs down the middle of the room. Blood stands on one side
// and its twin on the other, as its mirror image. Every step Blood takes, the
// twin takes the mirrored step: north is north, but east is west. Each is
// stopped by its own side's walls, so walking into a wall moves only the
// other one — the only way to change where the two of you stand.
//
// A plate opens the gate of its letter (on either side) for as long as
// somebody stands on it. A gate won't close on anybody standing in it. A pit
// swallows whoever steps in, and both of you rise again where you started.
//
// Air + Lava → Fire: the bellows (B) on Blood's side and the lava sluice (L)
// on the twin's side. When Blood stands on the bellows and the twin on the
// sluice after the same step, air meets lava at the captive's hearth.
//
// Map legend (y down):
//   #  wall     .  floor     |  the pool (nobody crosses it)
//   @  Blood's start (the twin starts mirrored)
//   B  bellows (Blood's side)     L  lava sluice (the twin's side)
//   1 2 3  plates      a b c  the gates they open (1 opens a, 2 b, 3 c)
//   O  pit           H  the captive's hearth (a wall, drawn on the pool)
(function (root) {
  const DX = [0, 1, 0, -1], DY = [-1, 0, 1, 0];
  const MIRROR = [0, 3, 2, 1]; // the twin's step for each of Blood's

  function parseRoom(def) {
    const H = def.map.length, W = def.map[0].length;
    const cells = def.map.map((r) => r.split(''));
    let b = null;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      if (cells[y][x] === '@') { b = [x, y]; cells[y][x] = '.'; }
    }
    return { def, W, H, cells, b0: b, t0: [W - 1 - b[0], b[1]] };
  }

  function start(R) { return { b: R.b0.slice(), t: R.t0.slice() }; }

  const gateOf = { a: '1', b: '2', c: '3' };

  function pressed(R, S) {
    const on = new Set();
    for (const [x, y] of [S.b, S.t]) {
      const ch = R.cells[y][x];
      if (/[123]/.test(ch)) on.add(ch);
    }
    return on;
  }

  function open(R, S, x, y, on) {
    const ch = R.cells[y] && R.cells[y][x];
    if (ch == null) return false;
    if (ch === '#' || ch === '|' || ch === 'H') return false;
    if (/[abc]/.test(ch)) return on.has(gateOf[ch]);
    return true;
  }

  // One step: both try to move; a gate is judged by the plates pressed
  // before the step (and stays open on anybody standing in it).
  function step(R, S, d) {
    const on = pressed(R, S);
    const nb = [S.b[0] + DX[d], S.b[1] + DY[d]];
    const md = MIRROR[d];
    const nt = [S.t[0] + DX[md], S.t[1] + DY[md]];
    const bm = open(R, S, nb[0], nb[1], on);
    const tm = open(R, S, nt[0], nt[1], on);
    if (!bm && !tm) return { why: 'blocked' };
    let N = { b: bm ? nb : S.b.slice(), t: tm ? nt : S.t.slice() };
    const ev = { b: bm, t: tm };
    if (R.cells[N.b[1]][N.b[0]] === 'O' || R.cells[N.t[1]][N.t[0]] === 'O') {
      ev.pit = R.cells[N.b[1]][N.b[0]] === 'O' ? 'b' : 't';
      ev.from = N;
      N = start(R);
    }
    return { S: N, ev };
  }

  function solved(R, S) {
    return R.cells[S.b[1]][S.b[0]] === 'B' && R.cells[S.t[1]][S.t[0]] === 'L';
  }

  const key = (S) => S.b + '|' + S.t;

  // Breadth-first: the shortest plan, how many of its steps moved only ONE
  // of the two (the room's skill), and how many states can reach the goal.
  function solve(R) {
    const S0 = start(R);
    const seen = new Map([[key(S0), null]]);
    let q = [S0], goal = null;
    while (q.length && !goal) {
      const n = [];
      for (const S of q) {
        for (let d = 0; d < 4; d++) {
          const r = step(R, S, d);
          if (r.why) continue;
          const k = key(r.S);
          if (seen.has(k)) continue;
          seen.set(k, { from: key(S), d, one: r.ev.b !== r.ev.t, pit: !!r.ev.pit });
          if (solved(R, r.S)) { goal = k; break; }
          n.push(r.S);
        }
        if (goal) break;
      }
      q = n;
    }
    if (!goal) return { solvable: false, states: seen.size };
    const plan = [];
    let single = 0;
    for (let k = goal; seen.get(k); k = seen.get(k).from) { const e = seen.get(k); plan.unshift('NESW'[e.d]); if (e.one) single++; }
    return { solvable: true, states: seen.size, steps: plan.length, single, plan };
  }

  const api = { DX, DY, MIRROR, parseRoom, start, step, solved, solve, pressed, open, key };
  if (typeof module !== 'undefined') module.exports = api; else root.FireEngine = api;
})(this);
