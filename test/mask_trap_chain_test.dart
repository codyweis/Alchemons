// A trap must not lay another trap.
//
// THE HITCH: one frame of the Simurgh fight cost 720ms of update, 155ms just
// to RECORD its draw calls, and 2.2 seconds to rasterise. It was reproducible
// by walking the boss onto a mask mine.
//
// The mechanism: a mask Fire trap that is hit spawns a fire POOL, and the
// pool it spawns is itself `abilityFamily: 'mask'`, `element: 'Fire'`,
// stationary and piercing. Contact is re-tested every frame with no
// per-enemy hit registry, so every pool standing on an enemy lays another
// pool, every frame — 2^n after n frames. Crystal is worse: its shards come
// in threes, so 3^n.
//
// These pin the fix at the level that matters: park an enemy on a trap, let
// it run, and count.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _m(String element, String family) => CosmicPartyMember(
  instanceId: '$element$family',
  baseId: 'b',
  displayName: '$element $family',
  imagePath: null,
  element: element,
  family: family,
  level: 10,
  statSpeed: 4,
  statIntelligence: 4,
  statStrength: 4,
  statBeauty: 4,
  slotIndex: -1,
  staminaBars: 9,
  staminaMax: 9,
);

PlanetDungeonGame _game() {
  final els = kCosmicPlanetEntry['Fire']!;
  final fams = kDungeonIdealFamilies['Fire']!;
  final party = [
    for (var i = 0; i < els.length; i++) _m(els[i], fams[i].toLowerCase()),
  ];
  final g = PlanetDungeonGame(
    element: 'Fire',
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.currentRoomId = g.layout.entranceRoomId;
  final at = g.currentRoom.bounds.center;
  for (final m in party) {
    g.creatures.add(DungeonCreature(member: m)..position = at..lastSafe = at);
  }
  g.onGameResize(Vector2(412, 915));
  return g;
}

/// A mask trap of [element], laid at [at] — stationary, piercing, the way
/// every mask placement is.
Projectile _trap(String element, Offset at) => Projectile(
  position: at,
  angle: 0,
  element: element,
  damage: 1,
  life: 8.0,
  speedMultiplier: 0,
  stationary: true,
  piercing: true,
  radiusMultiplier: 1.4,
  visualScale: 1.6,
  visualStyle: ProjectileVisualStyle.sigil,
  sourceSlotIndex: 0,
  abilityFamily: 'mask',
  hitEffect: AbilityEffectKind.splash,
  effectPower: 4,
  effectRadius: 80,
  effectDuration: 4,
);

/// Park a wisp on top of [at] and hold it there for [frames].
void _standOnIt(PlanetDungeonGame g, Offset at, int frames) {
  g.spawnWispWave(
    element: 'Fire',
    center: at,
    count: 1,
    announce: false,
  );
  for (var i = 0; i < frames; i++) {
    for (final e in g.combatEnemies) {
      e.position = at; // it is standing IN the trap, and stays there
    }
    g.update(1 / 60);
  }
}

void main() {
  group('a mask trap does not breed', () {
    test('Fire: one pool, not a doubling every frame', () {
      final g = _game();
      final at = g.currentRoom.bounds.center;
      g.combatProjectiles.add(_trap('Fire', at));

      _standOnIt(g, at, 60); // one second of contact

      expect(
        g.combatProjectiles.length,
        lessThan(12),
        reason:
            'a trap stood on for a second laid '
            '${g.combatProjectiles.length} placements — that is the 720ms '
            'frame',
      );
    });

    test('Crystal: shards do not shard', () {
      final g = _game();
      final at = g.currentRoom.bounds.center;
      g.combatProjectiles.add(_trap('Crystal', at));

      _standOnIt(g, at, 60);

      expect(
        g.combatProjectiles.length,
        lessThan(12),
        reason: '${g.combatProjectiles.length} shards after one second',
      );
    });

    test('and the pool has a ceiling whatever happens', () {
      // The net, independent of the bug that found it: survival caps its
      // companion projectiles and trims every tick, and the dungeon's port
      // kept the raw `.add` and dropped the cap.
      final g = _game();
      final at = g.currentRoom.bounds.center;
      for (var i = 0; i < 900; i++) {
        g.combatProjectiles.add(_trap('Air', at));
      }
      g.update(1 / 60);
      expect(
        g.combatProjectiles.length,
        lessThanOrEqualTo(PlanetDungeonGame.kMaxCombatProjectiles),
      );
    });

    test('the trap still DOES its job on the first contact', () {
      // The fix must not be "traps stop working": the first hit still lays
      // its pool, which is the whole point of the Fire mask.
      final g = _game();
      final at = g.currentRoom.bounds.center;
      g.combatProjectiles.add(_trap('Fire', at));
      _standOnIt(g, at, 6);
      expect(
        g.combatProjectiles.length,
        greaterThan(1),
        reason: 'the trap must still lay its fire pool',
      );
    });
  });
}
