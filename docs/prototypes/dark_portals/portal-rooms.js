// Room data for the Black Sun prototype — THE GAME'S ROOMS, doorways and
// all (D = a doorway to another room, S = the island's stair). Every room is
// proved by solve.js before it is played. Coordinates are [x, y], y down.
// planet_dungeon_layout_dark.dart embeds these same maps.
(function (root) {
  const ROOMS = {
    one: {
      label: 'I · The porch',
      name: 'The porch',
      teaches: 'A Dark casts both ends of its portal. Anyone can walk through. (Proof goal: all three on the far side, under the Hall door.)',
      map: [
        '#######D###',
        '#...~~~EEE#',
        'O...~~~...O',
        '#...~~~...#',
        '###########',
      ],
      start: { light: [2, 1], purple: [1, 2], orange: [2, 3] },
    },
    two: {
      label: 'II · Through the dark',
      name: 'Through the dark',
      teaches: 'A beam goes through a portal and comes out still white.',
      map: [
        '##D##w#######',
        '#.........#E#',
        '#.........#E#',
        '#*........OE#',
        '#.........|E#',
        '#####O#######',
      ],
      start: { light: [2, 1], purple: [3, 1], orange: [1, 1] },
      latch: true,
    },
    three: {
      label: 'III · Two darks make blood',
      name: 'Two darks make blood',
      teaches: 'Through both portals, the beam comes out as blood.',
      map: [
        '#O#r#D##',
        '#......#',
        '#*.....O',
        '#......#',
        '#O#O##|#',
        '####EEE#',
        '########',
      ],
      start: { light: [5, 1], purple: [4, 1], orange: [6, 1] },
      latch: true,
    },
    hall2: {
      label: 'Hall · the island',
      name: 'The Hall: the island',
      teaches: 'Once Star 1 lights its two stars: two crossings, one blood-light. The second is cast from the island. (Proof goal: all three on the far ledge.)',
      hub: true,
      big: true,
      map: [
        '##O##O##D##',
        '#~~~~~~#EE#',
        '#~~~~~~#E.D',
        '#~~~...~~~O',
        '#~~~.S.~~~#',
        'OV~~~~~~~~#',
        '##........<',
        '>.........O',
        '#DO##D##D##',
      ],
      start: { light: [5, 7], purple: [4, 7], orange: [6, 7] },
    },
    four: {
      label: 'IV · Walk into the light',
      name: 'Walk into the light',
      teaches: 'Blood-light is a bridge. A Dark drinks light, so it walks towards the source.',
      map: [
        '##v##########',
        '#...~~~~~EEE#',
        '#...~~~~~...#',
        '#...~~~~~~~~O',
        'O...~~~~~~~~O',
        '#...~~~~~~~~#',
        '#DO##########',
      ],
      start: { light: [1, 5], purple: [3, 5], orange: [1, 4] },
    },
    five: {
      label: 'V · Hold the light',
      name: 'Hold the light',
      teaches: 'The door is open only while the seal burns. The last one out leaves by the dark.',
      map: [
        '#O##r#######',
        '#.......#EE#',
        '#*......O.E#',
        '#.......#..#',
        'D.......|..#',
        '#O##O#######',
      ],
      start: { light: [1, 4], purple: [2, 4], orange: [1, 3] },
    },
    rite: {
      label: 'Rite · the Great Work',
      name: 'The Great Work',
      teaches: 'The one who holds the door comes down last, through the dark.',
      big: true,
      map: [
        '##D######',
        '>..p..~~O',
        '#.....~~#',
        '###O|####',
        '#.......#',
        'O.......O',
        '#.......#',
        '###r|####',
        '###EEE###',
        '####D####',
      ],
      circuits: [
        { triggers: [[3, 1]], doors: [[4, 3]] },
        { triggers: [[3, 7]], doors: [[4, 7]], latch: true },
      ],
      start: { light: [2, 1], purple: [1, 2], orange: [2, 2] },
    },
    vault: {
      label: 'Vault · leap of faith',
      name: 'The vault (Hall)',
      teaches: 'Cast from the bridge, even though you will fall — the portal stays.',
      goal: 'vault',
      map: [
        '##O##O##D##',
        '#~~~~~~#..#',
        '#~~~~~~#..D',
        '#~~~...~~~O',
        '#~~~.S.~~~#',
        'OV~~~~~~~~#',
        '##........<',
        '>.........O',
        '#DO##D##D##',
      ],
      start: { light: [5, 7], purple: [4, 7], orange: [6, 7] },
    },
  };

  if (typeof module !== 'undefined') module.exports = { ROOMS };
  else root.PortalRooms = { ROOMS };
})(typeof window !== 'undefined' ? window : globalThis);
