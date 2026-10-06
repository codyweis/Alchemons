// Room data for the Blood prototype (Hemavorn, rebuilt 2026-10-05). Every
// room is proved by solve.js before it is played. Coordinates [x, y], y down.
(function (root) {
  // THE CIRCLE — the hub. Four doors (Air north, Fire east, Earth south,
  // Water west); a freed captive's blood runs from its door to its socket at
  // the boss door in the middle. Two turning rings of eight sectors lie
  // across the streams. A stream reaches the CENTRE only where BOTH rings
  // have a groove at its angle; anywhere else the ring turns it aside to its
  // socket. Two streams in the centre fuse (the game's own recipes); all
  // four make the quintessence — the Lost Maxim.
  const HUB = {
    doors: { Air: 0, Fire: 2, Earth: 4, Water: 6 }, // sector of each door (45° steps, clockwise from north)
    outer: [0, 1, 2, 3, 5, 7], // sectors with a groove to the inner ring (at turn 0)
    inner: [1, 3, 5, 7], // sectors with a groove to the centre (at turn 0)
    fusions: {
      'Fire+Water': 'Steam', 'Earth+Fire': 'Lava', 'Earth+Water': 'Mud',
      'Air+Water': 'Ice', 'Air+Earth': 'Dust', 'Air+Fire': 'Lightning',
    },
  };

  const EARTH = {
    id: 'earth',
    label: 'Earth · The tendril floor',
    element: 'Earth',
    recipe: 'Dust + Water',
    teaches: 'Lead every tendril to its partner. Tendrils never cross. Plates turn, and whatever stands on a plate turns with it. Lead the Dust and the Water to the captive.',
    map: [
      '###########',
      'a.........#',
      '#.......b.#',
      'b.......o.#',
      '#.......aX#',
      'c.....#...#',
      'd...o.....c',
      '#..XC.....w',
      '###########',
    ],
  };

  const WATER = {
    id: 'water',
    label: 'Water · The turning room',
    element: 'Water',
    recipe: 'Fire + Ice',
    teaches: 'FLIP turns the room over. Ice slides downhill; water runs downhill, then along the floor. Ice that comes to rest against fire melts. Water puts fire out. Blood stops anything that slides into it.',
    map: [
      '#########',
      '#CCC..F##',
      '#..F....#',
      '#.......#',
      '#.......#',
      '#.F.._..#',
      '#I..I.IB#',
      '#########',
    ],
  };


  const FIRE = {
    id: 'fire',
    label: 'Fire · The twin',
    element: 'Fire',
    recipe: 'Air + Lava',
    teaches: 'Your twin takes the mirror of every step: north is north, east is west. Walk into a wall and only the other one moves. A plate holds its gate open on the far side while someone stands on it. Stand on the bellows while the twin stands on the sluice.',
    map: [
      '###########',
      '#@b..|....#',
      '##...|....#',
      '#..1.|L...#',
      '#....|...a#',
      '#....H.2..#',
      '#...B|....#',
      '###########',
    ],
  };

  const AIR = {
    id: 'air',
    label: 'Air · The weightless room',
    element: 'Air',
    recipe: 'Ice + Light',
    need: 2,
    teaches: 'Push off and you drift until something stops you. Drift up against ice and push again to send the ice drifting instead. Ice that drifts into sunlight turns to air. Beside the bell, the air goes in. Anywhere else, it is lost.',
    map: [
      '#########',
      '#.......#',
      '#...I...#',
      '#.I.....#',
      '#.I.....#',
      '#......*#',
      '#....I.C#',
      '#.*.@..*#',
      '#########',
    ],
  };

  // THE HEART — the fifth rite (the author's design, 2026-10-06). Blood is
  // taken and bound across the room; the four it freed stand on the stage.
  // Two on an altar fuse, and what they make shoots its power down that
  // altar's lane at the first thing in the way. Everything in the way holds an
  // element, and breaking it frees that element to join you. The split stage
  // takes a fused creature apart again. Light + Dark make Blood, and Blood
  // made here frees the Blood that was taken.
  const HEART = {
    id: 'heart',
    label: 'The Heart',
    teaches: 'Stand two together on an altar and they fuse. What they make shoots its power down that altar\'s lane. Break what is in the way and what it holds joins you. The split stage takes a fused creature apart. Make Blood.',
    map: [
      '################',
      '#Sa......I######',
      '#.....##########',
      '#f......._######',
      '#.....########B#',
      '#w.......K.K####',
      '#.....##########',
      '#e.......T######',
      '################',
    ],
    altars: [
      { back: [4, 1], front: [5, 1] },
      { back: [4, 3], front: [5, 3] },
      { back: [4, 5], front: [5, 5] },
      { back: [4, 7], front: [5, 7] },
    ],
    holds: { '9,1': 'Lava', '9,3': 'Spirit', '9,5': 'Crystal', '11,5': 'Crystal', '9,7': 'Plant' },
  };

  const ROOMS = { earth: EARTH, water: WATER, fire: FIRE, air: AIR, heart: HEART };
  const api = { HUB, ROOMS };
  if (typeof module !== 'undefined') module.exports = api; else root.RitesRooms = api;
})(this);
