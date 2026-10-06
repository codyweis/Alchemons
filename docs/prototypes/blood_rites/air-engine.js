// THE WEIGHTLESS ROOM (Air) — rules shared by the page and the solver.
//
// There is no floor to push against. Blood pushes off in a direction and
// drifts in a straight line until something stops it. Blood up against a
// block of ice that pushes towards it sends the ice drifting the same way
// instead; Blood stays where it is.
//
// Ice + Light → Air: shafts of sunlight fall through the roof. Ice that
// drifts into the light turns to air and is gone. The captive is sealed in a
// glass bell; air made in a shaft beside the bell goes into it. Fill the
// bell. Air made anywhere else is lost.
//
// The ice is the only thing to stop against besides the walls, and it is
// also the only fuel: the order it is spent in is the puzzle.
//
// Map legend (y down):
//   #  wall     .  floor (open air)     @  Blood
//   I  ice      *  a shaft of sunlight  C  the glass bell (a wall)
//   def.need — how much air the bell needs
(function (root) {
  const DX = [0, 1, 0, -1], DY = [-1, 0, 1, 0];

  function parseRoom(def) {
    const H = def.map.length, W = def.map[0].length;
    const cells = def.map.map((r) => r.split(''));
    let b = null;
    const ice = [];
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      if (cells[y][x] === '@') { b = [x, y]; cells[y][x] = '.'; }
      if (cells[y][x] === 'I') { ice.push(x + ',' + y); cells[y][x] = '.'; }
    }
    return { def, W, H, cells, b0: b, ice0: ice.sort(), need: def.need || 1 };
  }

  function start(R) { return { b: R.b0.slice(), ice: R.ice0.slice(), air: 0 }; }

  const solid = (R, x, y) => { const ch = R.cells[y] && R.cells[y][x]; return ch == null || ch === '#' || ch === 'C'; };
  const hasIce = (S, x, y) => S.ice.includes(x + ',' + y);
  const bellBeside = (R, x, y) => [0, 1, 2, 3].some((d) => R.cells[y + DY[d]] && R.cells[y + DY[d]][x + DX[d]] === 'C');

  // One push. Returns the new state and a path for the page to animate.
  function push(R, S, d) {
    const [bx, by] = S.b;
    const nx = bx + DX[d], ny = by + DY[d];
    if (hasIce(S, nx, ny)) {
      // shove the ice: it drifts until it is stopped or melts into the light
      let x = nx, y = ny;
      const path = [[x, y]];
      const others = S.ice.filter((k) => k !== nx + ',' + ny);
      let gone = null;
      while (true) {
        if (R.cells[y][x] === '*' && !(x === nx && y === ny)) { gone = [x, y]; break; }
        const tx = x + DX[d], ty = y + DY[d];
        if (solid(R, tx, ty) || others.includes(tx + ',' + ty) || (tx === bx && ty === by)) break;
        x = tx; y = ty; path.push([x, y]);
      }
      if (path.length === 1 && !gone) return { why: 'The ice is up against something.' };
      let ice = others, air = S.air, ev = null;
      if (gone) {
        if (bellBeside(R, gone[0], gone[1])) { air++; ev = 'bell'; } else ev = 'lost';
      } else ice = others.concat([x + ',' + y]).sort();
      return { S: { b: S.b, ice, air }, ice: path, ev, at: gone };
    }
    let x = bx, y = by;
    const path = [[x, y]];
    while (true) {
      const tx = x + DX[d], ty = y + DY[d];
      if (solid(R, tx, ty) || hasIce(S, tx, ty)) break;
      x = tx; y = ty; path.push([x, y]);
    }
    if (path.length === 1) return { why: 'blocked' };
    return { S: { b: [x, y], ice: S.ice, air: S.air }, blood: path };
  }

  const solved = (R, S) => S.air >= R.need;
  const key = (S) => S.b + '|' + S.ice.join(';') + '|' + S.air;

  // The whole state graph: fewest pushes, the share of dead ends, and the
  // set of states that can still finish (for the page).
  function graph(R, max) {
    const S0 = start(R);
    const idx = new Map([[key(S0), 0]]), states = [S0], edges = [[]], goals = [];
    for (let i = 0; i < states.length; i++) {
      if (states.length > (max || 3e5)) return null;
      const S = states[i];
      if (solved(R, S)) { goals.push(i); continue; }
      for (let d = 0; d < 4; d++) {
        const r = push(R, S, d);
        if (r.why) continue;
        const k = key(r.S);
        let j = idx.get(k);
        if (j == null) { j = states.length; idx.set(k, j); states.push(r.S); edges.push([]); }
        edges[i].push([j, d, !!r.ice]);
      }
    }
    const rev = states.map(() => []);
    edges.forEach((es, i) => es.forEach(([j]) => rev[j].push(i)));
    const live = new Uint8Array(states.length);
    const q = goals.slice();
    goals.forEach((g) => (live[g] = 1));
    while (q.length) { const j = q.pop(); for (const i of rev[j]) if (!live[i]) { live[i] = 1; q.push(i); } }
    const dist = new Array(states.length).fill(-1), prev = new Array(states.length).fill(null);
    dist[0] = 0;
    const bq = [0];
    let goal = null;
    while (bq.length) {
      const i = bq.shift();
      if (solved(R, states[i])) { goal = i; break; }
      for (const [j, d, shove] of edges[i]) if (dist[j] < 0) { dist[j] = dist[i] + 1; prev[j] = [i, d, shove]; bq.push(j); }
    }
    const plan = [];
    let shoves = 0;
    for (let j = goal; j != null && prev[j]; j = prev[j][0]) { plan.unshift('NESW'[prev[j][1]]); if (prev[j][2]) shoves++; }
    return {
      states: states.length, solvable: live[0] === 1, pushes: plan.length, shoves, plan,
      dead: states.filter((_, i) => !live[i]).length / states.length,
      live: new Set(states.filter((_, i) => live[i]).map(key)),
    };
  }

  const api = { DX, DY, parseRoom, start, push, solved, graph, key, bellBeside };
  if (typeof module !== 'undefined') module.exports = api; else root.AirEngine = api;
})(this);
