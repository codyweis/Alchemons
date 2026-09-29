const E = require('./shadow-engine.js');
const { ROOMS } = require('./shadow-rooms.js');
const R = E.parseRoom(ROOMS.solarin);
const all = E.solve(R);
console.log('party', all.solvable, all.steps, all.plan && all.plan.join(' '));
for (const n of E.NAMES) console.log('  alone:', n, E.solve({ ...R, actors: [n] }).solvable);
