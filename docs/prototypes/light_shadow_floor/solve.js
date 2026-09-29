const E = require('./shadow-engine.js');
const { ROOMS } = require('./shadow-rooms.js');
const only = process.argv[2];
for (const [id, def] of Object.entries(ROOMS)) {
  if (only && !only.split(',').includes(id)) continue;
  const R = E.parseRoom(def);
  const t = Date.now();
  const full = E.solve(R);
  const line = [`${id} (${def.name}) solvable=${full.solvable} steps=${full.steps} pins=${full.pins} veils=${full.veils} cranks=${full.cranks} strikes=${full.strikes} states=${full.states} ${Date.now() - t}ms`];
  if (R.pins) line.push(`  without the pin: ${E.solve({ ...R, pins: 0 }).solvable}`);
  if (R.vents.length) line.push(`  without the veil: ${E.solve({ ...R, vents: [] }).solvable}`);
  const dark = [];
  for (let y = 0; y < R.rows; y++) for (let x = 0; x < R.cols; x++)
    if (R.cell[y][x] === '~' && ![0, 1, 2, 3, 4, 5].some(i => { const S = { ...E.start(R), rail: i % (R.rail?.length || 1), orbit: i % (R.orbit?.length || 1) }; return E.lampsOf(R, S).some(L => E.lights(R, L, x, y)); })) dark.push(x + ',' + y);
  line.push('  never-lit glass: ' + (dark.length ? dark.join(' ') : 'none'));
  if (full.solvable) line.push('  plan: ' + full.plan.join(' '));
  console.log(line.join('\n'));
}
