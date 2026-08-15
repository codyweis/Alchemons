// Teleport placement is not a hole in the map.
//
// PLAYTEST BUG (2026-08-14): "I seem to be able to glitch my mons to the stars
// by blocking them in and regrouping." `regroup()` snapped the idle party onto
// a 36px ring around the active creature, checking only the room bounds and
// open sky — never walls. A regroup with your back to a wall therefore posted
// the others INSIDE the stone, and since movement only ever forbids ENTERING
// something solid (never leaving it), they walked straight out the far side:
// a free teleport through walls, tide ledges, fossil ribs, powered barriers
// and pistons — every gate in the game, a star behind it or not.
//
// These tests hold the line for every built planet, against the real verb.

import 'dart:ui' show Offset, Rect;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member(int slot, String element, String family) =>
    CosmicPartyMember(
      instanceId: 'inst_$slot',
      baseId: 'base_$slot',
      displayName: '$element $family',
      element: element,
      family: family,
      level: 10,
      statSpeed: 3,
      statIntelligence: 3,
      statStrength: 3,
      statBeauty: 3,
      slotIndex: slot,
      staminaBars: 3,
      staminaMax: 3,
    );

PlanetDungeonGame _game(String element) {
  final party = [
    _member(0, element, 'wing'),
    _member(1, element, 'mask'),
    _member(2, element, 'horn'),
  ];
  final game = PlanetDungeonGame(
    element: element,
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  game.currentRoomId = game.layout.entranceRoomId;
  for (final m in party) {
    final c = DungeonCreature(member: m)
      ..position = game.layout.entranceSpawn
      ..lastSafe = game.layout.entranceSpawn;
    game.creatures.add(c);
    final stats = deriveCosmicSurvivalCompanionStats(member: m);
    game.combatCompanions.add(
      CosmicSurvivalCompanion(
        member: m,
        slotIndex: m.slotIndex,
        position: c.position,
        anchor: c.position,
        maxHp: stats.maxHp,
        currentHp: stats.maxHp,
        physAtk: stats.physAtk,
        elemAtk: stats.elemAtk,
        physDef: stats.physDef,
        elemDef: stats.elemDef,
        cooldownReduction: stats.cooldownReduction,
        critChance: stats.critChance,
        attackRange: stats.attackRange,
        specialAbilityRange: stats.specialAbilityRange,
        tethered: false,
        invincibleTimer: 0,
      ),
    );
  }
  return game;
}

/// The body radius the engine collides with, as a test-side constant: a
/// creature whose centre sits this close inside a solid rect is in the stone.
const double _radius = 12;

bool _inside(Offset p, Rect r, [double pad = _radius]) =>
    p.dx > r.left - pad &&
    p.dx < r.right + pad &&
    p.dy > r.top - pad &&
    p.dy < r.bottom + pad;

/// Every rect that is SOLID to a walker in this room right now, whatever the
/// planet calls it: authored wall rects, and Water's un-flooded tide ledges
/// (stone until the swell tops them — the temple's real walls). These are the
/// gates a regroup must never post a body through.
List<Rect> _solids(PlanetDungeonGame game, DungeonRoom room) => [
  ...room.walls,
  // At the low stand nothing is flooded, so every authored ledge is stone.
  for (final z in room.tideZones)
    if (z.ledge) z.rect,
];

int _totalProbed = 0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(() {
    expect(
      _totalProbed,
      greaterThan(0),
      reason: 'the suite probed no solid anywhere — the test has gone blind',
    );
  });

  for (final element in kPlanetDungeonLayouts.keys) {
    group('$element · regroup cannot post a body into stone', () {
      test('nothing solid in any room can be regrouped through', () {
        final game = _game(element);
        game.tideLevel = 0; // the low stand: every authored ledge is stone
        var probed = 0;

        for (final room in game.layout.rooms.values) {
          for (final wall in _solids(game, room)) {
            // Stand the active creature as close to the wall as the engine
            // would ever let it stand — the exact spot a player uses when
            // they "block themselves in" against it.
            for (final hug in [
              Offset(wall.left - _radius - 1, wall.center.dy),
              Offset(wall.right + _radius + 1, wall.center.dy),
              Offset(wall.center.dx, wall.top - _radius - 1),
              Offset(wall.center.dx, wall.bottom + _radius + 1),
            ]) {
              if (!room.bounds.deflate(_radius).contains(hug)) continue;
              if (_solids(game, room).any((r) => _inside(hug, r))) continue;
              probed++;

              game.currentRoomId = room.id;
              for (final c in game.creatures) {
                c
                  ..position = hug
                  ..lastSafe = hug;
              }
              game.setActive(0);
              game.creatures[0]
                ..position = hug
                ..lastSafe = hug;

              game.regroup();

              for (final c in game.creatures) {
                expect(
                  _solids(game, room).any((r) => _inside(c.position, r)),
                  isFalse,
                  reason:
                      '$element/${room.id}: regroup at $hug put ${c.member.displayName} '
                      'inside solid $wall — from there it walks out the far side, '
                      'which is a teleport through every gate in the game',
                );
                expect(
                  room.bounds.contains(c.position),
                  isTrue,
                  reason: '$element/${room.id}: regroup left the room',
                );
              }
            }
          }
        }
        // Not every planet gates with rects (several use open sky, pistons or
        // powered barriers instead), so a planet with nothing to probe is
        // legitimate — but the suite as a whole must be probing something.
        _totalProbed += probed;
      });

      test('regroup keeps the party together when it is honest', () {
        // The guard must not break the feature: in open floor the idle party
        // still lands on its ring, not stacked on the active creature.
        final game = _game(element);
        final room = game.layout.rooms[game.layout.entranceRoomId]!;
        final at = game.layout.entranceSpawn;
        game.currentRoomId = room.id;
        for (final c in game.creatures) {
          c
            ..position = at
            ..lastSafe = at;
        }
        game.creatures[1].position = at + const Offset(300, 0);
        game.creatures[2].position = at + const Offset(-300, 0);
        game.setActive(0);
        game.regroup();

        for (var i = 1; i < game.creatures.length; i++) {
          expect(
            (game.creatures[i].position - at).distance,
            lessThanOrEqualTo(40),
            reason: '$element: regroup must still gather the party',
          );
        }
      });
    });
  }
}
