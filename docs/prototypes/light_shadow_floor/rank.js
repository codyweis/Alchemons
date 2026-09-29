const E = require('./shadow-engine.js');
const fs = require('fs');
let all = [];
for (const f of fs.readdirSync('.').filter(f => f.startsWith('found2_'))) all.push(...JSON.parse(fs.readFileSync(f)));
all.sort((a, b) => b.steps - a.steps);
for (const c of all.slice(0, 6)) {
  const R = E.parseRoom(c.def);
  // Full reachable graph, then reverse BFS from solved states.
  const S0 = E.start(R); const k0 = E.enc(S0);
  const idx = new Map([[k0, 0]]); const states = [S0]; const rev = [[]];
  let goals = [];
  for (let h = 0; h < states.length && states.length < 1500000; h++) {
    const S = states[h];
    if (E.solved(R, S)) { goals.push(h); continue; }
    for (const [, T] of E.moves(R, S)) {
      const k = E.enc(T); let j = idx.get(k);
      if (j === undefined) { j = states.length; idx.set(k, j); states.push(T); rev.push([]); }
      rev[j].push(h);
    }
  }
  const good = new Uint8Array(states.length); const q = [...goals]; for (const g of goals) good[g] = 1;
  while (q.length) { const v = q.pop(); for (const u of rev[v]) if (!good[u]) { good[u] = 1; q.push(u); } }
  let bad = 0; for (let i = 0; i < states.length; i++) if (!good[i]) bad++;
  // How many of the moves out of states on a winning line lead to dead ends?
  console.log(`steps=${c.steps} cranks=${c.cranks} states=${states.length} dead=${(100*bad/states.length).toFixed(1)}%\n${c.def.map.join('\n')}\nstart=${JSON.stringify(c.def.start)} rail=${c.def.railStart}\n`);
}
