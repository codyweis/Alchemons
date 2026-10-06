// THE CIRCLE (hub) — where each freed captive's blood runs, and the maxim.
(function (root) {
  const ORDER = ['Air', 'Fire', 'Earth', 'Water'];

  const has = (list, sector, turn) => list.includes((((sector - turn) % 8) + 8) % 8);

  // Where each freed stream goes for these ring turns: 'centre' or 'socket'.
  function flow(H, freed, turns) {
    const out = {};
    for (const el of ORDER) {
      if (!freed[el]) continue;
      const s = H.doors[el];
      out[el] = has(H.outer, s, turns[0]) && has(H.inner, s, turns[1]) ? 'centre' : 'socket';
    }
    return out;
  }

  // What the centre holds: nothing, one stream, a fusion, or the quintessence.
  function centre(H, f) {
    const ins = ORDER.filter((el) => f[el] === 'centre');
    if (ins.length === 4) return { kind: 'quintessence', ins };
    if (ins.length === 2) {
      const k = ins.slice().sort().join('+');
      return { kind: 'fusion', ins, result: H.fusions[k] };
    }
    if (ins.length === 3) return { kind: 'churn', ins };
    return { kind: ins.length ? 'one' : 'none', ins };
  }

  const api = { ORDER, flow, centre, has };
  if (typeof module !== 'undefined') module.exports = api; else root.HubEngine = api;
})(this);
