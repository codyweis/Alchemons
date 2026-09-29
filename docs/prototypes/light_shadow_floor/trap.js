const E = require('./shadow-engine.js');
const { ROOMS } = require('./shadow-rooms.js');
const R = E.parseRoom(ROOMS.four);
const full = E.solve(R);
console.log('four solvable', full.solvable, 'steps', full.steps, 'pins', full.pins, 'veils', full.veils);
console.log('  no pin', E.solve({ ...R, pins: 0 }).solvable, '| no veil', E.solve({ ...R, vents: [] }).solvable);
// The Room I habit: Light holds the first gap, Dark stands on it and pins it.
let S = E.start(R);
const go = (n, x, y) => { const r = E.stepCheck(R, S, n, x, y); if (r) throw new Error(n + ' ' + x + ',' + y + ' ' + r); S = { ...S, pos: { ...S.pos, [n]: { x, y } } }; };
go('Light', 1, 5); go('Light', 1, 6);
go('Dark', 1, 7); go('Dark', 2, 7); go('Dark', 3, 7); go('Dark', 3, 6); go('Dark', 4, 6);
const cells = E.pinCells(R, S);
console.log('habit pin covers', cells && cells.length, 'cells');
const pinned = new Set(cells); S = { ...S, pinned, pins: 0 };
// Solve on from here.
const R2 = { ...R, start: S.pos };
const rest = (() => {
  const seen = new Set([E.enc(S)]); const q = [S]; let h = 0;
  while (h < q.length) { const T = q[h++]; if (E.solved(R, T)) return true; for (const [, U] of E.moves(R, T)) { const e = E.enc(U); if (!seen.has(e)) { seen.add(e); q.push(U); } } }
  return false;
})();
console.log('after pinning the first gap, still solvable?', rest);
