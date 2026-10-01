// node solve.js [room,room]  — prove every room: solvable, shortest plan, and
// what each room cannot be solved without.
const E = require('./portal-engine.js');
const { ROOMS } = require('./portal-rooms.js');
const only = process.argv[2];
for (const [id, def] of Object.entries(ROOMS)) {
  if (only && !only.split(',').includes(id)) continue;
  const R = E.parseRoom(def);
  const t = Date.now();
  const full = def.big ? E.search(R) : E.solve(R);
  const out = [`${id} (${def.name}) ${def.big ? '[guided search — a plan, not the shortest] ' : ''}solvable=${full.solvable} steps=${full.steps} states=${full.states} ${Date.now() - t}ms`];
  const without = (label, patch) => {
    const r = E.solve(E.parseRoom({ ...def, ...patch }));
    out.push(`  without ${label}: ${r.solvable === false ? 'IMPOSSIBLE' : r.solvable ? 'solvable in ' + r.steps : 'unknown'}`);
  };
  without('the purple portal', { cast: { purple: false, orange: true } });
  without('the orange portal', { cast: { purple: true, orange: false } });
  if (def.map.some((r) => r.includes('*'))) without('Light shining', { shine: false });
  if (full.solvable) {
    // Replay the plan from a fresh start: every step legal, and it ends solved.
    const D = { north: 0, east: 1, south: 2, west: 3 };
    let S = E.start(R), ok = true;
    for (const a of full.plan) {
      const w = a.replace(/ \(.*$| \[.*$/, '').split(' ');
      const r = w[1] === 'casts' ? E.cast(R, S, w[0], w[2] === 'II' ? 1 : 0, D[w[3]])
        : w[1] === 'shines' ? E.shine(R, S, D[w[2]])
        : w[1] === 'dims' ? E.shine(R, S, -1)
        : E.move(R, S, w[0], D[w[1]]);
      if (r.why) { ok = false; out.push('  REPLAY FAILED at "' + a + '": ' + r.why); break; }
      S = r.S;
    }
    if (ok && !E.solved(R, S)) { ok = false; out.push('  REPLAY FAILED: plan does not end solved'); }
    if (ok) out.push('  replayed from a fresh start: solved');
    const walk = /^(light|purple|orange) (north|south|east|west)/;
    out.push(`  decisions (casts/shines): ${full.plan.filter((a) => !walk.test(a)).length} · walks: ${full.plan.filter((a) => walk.test(a)).length}`);
    out.push('  plan: ' + full.plan.join(' · '));
  }
  console.log(out.join('\n'));
}
