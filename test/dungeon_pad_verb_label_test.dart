// THE PAD SAYS WHAT A PRESS WOULD DO (2026-11-02).
//
// The utility tile names the press — LIGHT, BURN, GUST, TURN — from a probe
// that runs the real dispatcher and stops each handler at the point it would
// act. Three things have to hold for that to be safe and true, on every
// planet that opts in:
//
//   • THE PROBE IS PURE. Run anywhere, by anyone, at any stage, it changes
//     nothing: no cue, no line, no burst, no discovery, no star, no state.
//     (The tripwire asserts in the engine fire on most effects; the state
//     fingerprint here catches a handler that mutates before its first one.)
//   • THE PROBE IS HONEST. Where it reports a handler, a real press is taken;
//     where it reports none, a real press is not.
//   • IT NEVER FINDS A SECRET. A maxim acts unnamed, so the pad stays UTILITY.

import 'dart:ui';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
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

/// Everyone who does something somewhere on Fire, and one who does not.
List<CosmicPartyMember> _fireParty() => [
  _member(0, 'Fire', 'mask'),
  _member(1, 'Air', 'wing'),
  _member(2, 'Plant', 'mane'),
  _member(3, 'Lightning', 'horn'),
];

/// A stage of the run worth probing: what has been earned and opened.
class _Stage {
  const _Stage(this.name, this.stars, {this.entry = false, this.epitaph = 0});
  final String name;
  final int stars;
  final bool entry;
  final int epitaph;
}

const _stages = [
  _Stage('a fresh run', 0),
  _Stage('the hearth lit', 0, entry: true),
  _Stage('two stars', 3, entry: true, epitaph: 1),
  _Stage('the epitaph planted', 3, entry: true, epitaph: 2),
  _Stage('the epitaph burning', 3, entry: true, epitaph: 3),
  _Stage('every star', 7, entry: true),
];

PlanetDungeonGame _game(
  String element,
  List<CosmicPartyMember> party,
  _Stage stage,
  String roomId, {
  void Function()? onChanged,
}) {
  final g = PlanetDungeonGame(
    element: element,
    party: party,
    initialStarMask: stage.stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: onChanged ?? () {},
  );
  g.currentRoomId = roomId;
  g.entryDoorRevealed = stage.entry;
  g.epitaphStage = stage.epitaph;
  g.epitaphWriteT = 999;
  // The garth's board is built from its authored art the first time anything
  // looks at it (the renderer, usually). Build it now, so the fingerprint
  // compares the board and not whether the cache had been filled yet.
  if (element == 'Fire') g.burnFieldFor(g.layout.rooms[roomId]!);
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = g.layout.entranceSpawn
        ..lastSafe = g.layout.entranceSpawn,
    );
  }
  return g;
}

/// Everything a Fire handler writes to that a tripwire would not see.
String _fingerprint(PlanetDungeonGame g) => [
  g.currentRoomId,
  g.hintText,
  g.hintHasAnswer,
  g.refusalFlash,
  g.debugCuesEmitted,
  g.discoveredClouds.toList()..sort(),
  g.entryDoorRevealed,
  g.litMuralTorches.toList()..sort(),
  g.ritualProgress,
  g.epitaphStage,
  g.epitaphFans,
  g.vesperRouteId,
  g.vesperCommitted,
  g.bellsRung.toList()..sort(),
  g.gardenBoard,
  [
    for (final e in g.burnFields.entries)
      '${e.key}:${e.value.wind}:${e.value.alight}',
  ],
  g.conduitEnergy.toString(),
  g.guardianHp,
  g.carriedCloudType,
  g.flightActive,
  g.combatEnemies.length,
  for (final c in g.creatures) c.position,
].join('|');

/// Every point on a grid over [b], [step] apart.
Iterable<Offset> _grid(Rect b, double step) sync* {
  for (var y = b.top + step / 2; y < b.bottom; y += step) {
    for (var x = b.left + step / 2; x < b.right; x += step) {
      yield Offset(x, y);
    }
  }
}

/// One of every element, the families turned through, so every handler on
/// every planet meets somebody it answers and somebody it refuses.
List<CosmicPartyMember> _everyone() {
  const els = [
    'Fire', 'Water', 'Earth', 'Air', 'Ice', 'Lightning', 'Plant', 'Poison',
    'Steam', 'Lava', 'Mud', 'Dust', 'Crystal', 'Spirit', 'Dark', 'Light',
    'Blood',
  ];
  const fams = ['mask', 'wing', 'mane', 'pip', 'horn', 'kin', 'let'];
  return [
    for (var i = 0; i < els.length; i++) _member(i, els[i], fams[i % 7]),
  ];
}

const _generic = [
  _Stage('a fresh run', 0),
  _Stage('the way in open', 0, entry: true),
  _Stage('two stars', 3, entry: true),
  _Stage('every star', 7, entry: true),
];

void main() {
  for (final element in PlanetDungeonGame.verbLabelPlanets) {
    group('$element', () {
      final layout = kPlanetDungeonLayouts[element]!;
      final party = _everyone();
      final stages = element == 'Fire' ? _stages : _generic;

      test('the probe is pure: it changes nothing, anywhere, for anyone', () {
        var probes = 0;
        for (final stage in stages) {
          for (final id in layout.rooms.keys) {
            var changed = 0;
            final g = _game(
              element,
              party,
              stage,
              id,
              onChanged: () => changed++,
            );
            for (var i = 0; i < party.length; i++) {
              g.activeIndex = i;
              for (final p in _grid(layout.rooms[id]!.bounds, 28)) {
                g.creatures[i].position = p;
                final before = _fingerprint(g);
                g.debugProbeVerb();
                probes++;
                expect(
                  _fingerprint(g),
                  before,
                  reason:
                      '${stage.name} · $id · ${party[i].displayName} at $p',
                );
              }
            }
            expect(changed, 0, reason: 'the probe redrew the HUD in $id');
          }
        }
        expect(probes, greaterThan(10000));
      });

      test('the probe is honest: a press is taken exactly where it reports',
          () {
        var hits = 0, misses = 0;
        for (final stage in stages) {
          for (final id in layout.rooms.keys) {
            for (var i = 0; i < party.length; i++) {
              for (final p in _grid(layout.rooms[id]!.bounds, 48)) {
                // One game for both: some planets roll their puzzle per
                // game, and the probe is pure (above), so pressing after
                // probing presses the very room the probe looked at.
                final g = _game(element, party, stage, id)..activeIndex = i;
                g.creatures[i].position = p;
                final found = g.debugProbeVerb();
                final cues = g.debugCuesEmitted;
                g.activateAbility();
                final taken = g.debugCuesEmitted > cues;
                expect(
                  taken,
                  found.hit,
                  reason:
                      '${stage.name} · $id · ${party[i].displayName} at $p: '
                      'probe ${found.hit ? 'found ${found.label}' : 'found '
                                'nothing'}, the press was '
                      '${taken ? '' : 'not '}taken',
                );
                found.hit ? hits++ : misses++;
              }
            }
          }
        }
        // Both sides were really exercised.
        expect(hits, greaterThan(20));
        expect(misses, greaterThan(1000));
      });
    });
  }

  group('Fire, the pilot', () {
    final party = _fireParty();
    final layout = kPlanetDungeonLayouts['Fire']!;

    test('the words, at the things', () {
      final fresh = _stages.first;
      final lit = _stages[1];
      String? at(_Stage s, String room, int who, Offset p) {
        final g = _game('Fire', party, s, room)..activeIndex = who;
        g.creatures[who].position = p;
        return g.debugProbeVerb().label;
      }

      // The hearth asks to be lit, and is quiet once it is — by anyone.
      final narthex = layout.rooms[layout.entranceRoomId]!;
      final hearth = narthex.braziers.first.position;
      expect(at(fresh, narthex.id, 0, hearth), 'LIGHT');
      expect(
        at(fresh, narthex.id, 2, hearth),
        'LIGHT',
        reason: 'the label names the object, never who can work it',
      );
      expect(at(lit, narthex.id, 0, hearth), isNull);

      // A Wing with nothing in reach glides.
      expect(at(lit, narthex.id, 1, narthex.bounds.bottomLeft), 'GLIDE');
      // Open floor, for a walker: the plain UTILITY.
      expect(
        at(lit, narthex.id, 0, narthex.bounds.bottomLeft + const Offset(40, -40)),
        isNull,
      );

      // Scriptorium torches.
      final scriptorium = layout.rooms.values.firstWhere(
        (r) => r.muralTorches.isNotEmpty,
      );
      expect(at(lit, scriptorium.id, 0, scriptorium.muralTorches.first), 'LIGHT');

      // An awake guardian is struck — in its lull or not, the word is the
      // same, and the refusal says the rest.
      final lair = layout.rooms.values.firstWhere((r) => r.guardian != null);
      for (final vulnerable in [false, true]) {
        final g = _game('Fire', party, _stages[2], lair.id)
          ..guardianAwake = true
          ..guardianVulnerable = vulnerable;
        g.creatures[0].position = lair.guardian!.position;
        expect(g.debugProbeVerb().label, 'STRIKE');
      }
    });

    test('it never finds the epitaph', () {
      for (final stage in _stages.where((s) => s.epitaph > 0)) {
        for (var i = 0; i < party.length; i++) {
          final g = _game('Fire', party, stage, 'scriptorium')..activeIndex = i;
          g.creatures[i].position = kEmberEpitaphPlanter;
          final found = g.debugProbeVerb();
          expect(
            found.label,
            isNot(isIn(['LIGHT', 'GROW', 'BURN', 'GUST', 'TURN', 'TEND'])),
            reason: '${stage.name} · ${party[i].displayName}',
          );
        }
      }
    });
  });

  test('planets not yet opted in keep the plain UTILITY', () {
    for (final element in kPlanetDungeonLayouts.keys.where(
      (e) => !PlanetDungeonGame.verbLabelPlanets.contains(e),
    )) {
      final layout = kPlanetDungeonLayouts[element]!;
      final els = kCosmicPlanetEntry[element]!;
      final party = [
        for (var i = 0; i < els.length; i++) _member(i, els[i], 'mane'),
      ];
      final g = _game(element, party, _stages.first, layout.entranceRoomId);
      g.creatures.first.position = layout.entranceSpawn;
      g.update(0.2);
      expect(g.utilityVerbLabel, isNull, reason: element);
    }
  });
}
