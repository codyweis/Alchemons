// VERDANTHOS, IN GLASS — the states the Conservatory's glass is meant to
// show (docs/dungeons.md §7.11, §9.20), asserted to be different pictures.
//
// The rooms whole are `planet_dungeon_whole_room_audit_test.dart
// --dart-define=AUDIT=Plant`; this is the STATES, each reached by playing the
// verb and letting its animation run. The opposite flower is shot from a game
// where only the maxim's id is set — a found maxim's mark must stand on every
// later descent.
//
// `mkdir -p build/room_audit` and run this to get the PNGs (PlantGlass_*.png).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_plant.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PlanetDungeonGame> _game(String roomId, {int stars = 0}) async {
  const els = ['Crystal', 'Spirit', 'Water'];
  const fams = ['mask', 'kin', 'mane'];
  final party = [
    for (var i = 0; i < els.length; i++)
      CosmicPartyMember(
        instanceId: 'i$i',
        baseId: 'b$i',
        displayName: els[i],
        element: els[i],
        family: fams[i],
        level: 10,
        statSpeed: 3,
        statIntelligence: 3,
        statStrength: 3,
        statBeauty: 3,
        slotIndex: i,
        staminaBars: 3,
        staminaMax: 3,
      ),
  ];
  final g = PlanetDungeonGame(
    element: 'Plant',
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  await g.debugLoadFx();
  g.starMask = stars; // applied in onLoad, which a headless game never runs
  final b = kPlanetDungeonLayouts['Plant']!.rooms[roomId]!.bounds;
  g.onGameResize(Vector2(b.width + 60, b.height + 60));
  g.entryDoorRevealed = true;
  g.currentRoomId = roomId;
  final stand = Offset(b.left + 60, b.bottom - 40);
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = stand
        ..lastSafe = stand,
    );
  }
  return g;
}

/// Stand [els] in the ring at [at] and press with the first.
void _tend(PlanetDungeonGame g, Offset at, List<String> els) {
  final park = g.currentRoom.bounds.bottomRight - const Offset(40, 40);
  for (final c in g.creatures) {
    final i = els.indexOf(c.member.element);
    c.position = i < 0 ? park : at + Offset(-14.0 + 14 * i, 0);
  }
  g.activeIndex = g.creatures.indexWhere((c) => c.member.element == els.first);
  g.activateAbility();
}

void _park(PlanetDungeonGame g) {
  final park = g.currentRoom.bounds.bottomRight - const Offset(40, 40);
  for (final c in g.creatures) {
    c.position = park;
  }
}

Offset _wing(String room) =>
    kPlanetDungeonLayouts['Plant']!.rooms[room]!.grove!.wing!.ring;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every state the Conservatory\'s glass shows', (tester) async {
    await tester.runAsync(() async {
      final out = Directory('build/room_audit');
      final shots = <String, int>{};

      Future<void> shoot(
        String name,
        String roomId, {
        int stars = 0,
        void Function(PlanetDungeonGame g)? setup,
        double seconds = 0.4,
        bool park = true,
      }) async {
        final g = await _game(roomId, stars: stars);
        g.debugResetPuzzleState();
        g.currentRoomId = roomId;
        if (park) _park(g);
        setup?.call(g);
        for (var i = 0; i < (seconds * 60).round(); i++) {
          g.update(1 / 60);
        }
        final rec = ui.PictureRecorder();
        g.render(Canvas(rec));
        final img = await rec.endRecording().toImage(
          g.size.x.round(),
          g.size.y.round(),
        );
        if (out.existsSync()) {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File(
            'build/room_audit/PlantGlass_$name.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        }
        final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bytes = raw!.buffer.asUint8List();
        var hash = 17;
        for (var i = 0; i < bytes.length; i += 97) {
          hash = (hash * 31 + bytes[i]) & 0x3FFFFFFF;
        }
        shots[name] = hash;
      }

      // The three wings, sick, mid-wash and healed.
      for (final (room, els) in [
        ('dry_bed', ['Water']),
        ('hothouse', ['Water', 'Spirit']),
        ('shadehouse', ['Spirit', 'Crystal']),
      ]) {
        await shoot('${room}_sick', room);
        await shoot(
          '${room}_wash',
          room,
          setup: (g) => _tend(g, _wing(room), els),
          seconds: 1.1,
        );
        await shoot(
          '${room}_healed',
          room,
          setup: (g) => _tend(g, _wing(room), els),
          seconds: 4.0,
        );
      }

      // The hub: bare, two wings healed, the cutscene's bind and rise, and
      // the great plant standing.
      await shoot('hub_bare', 'conservatory');
      await shoot(
        'hub_two',
        'conservatory',
        setup: (g) => g.greenhouse.healed.addAll([Climate.dry, Climate.warm]),
      );
      await shoot('hub_standing', 'conservatory', stars: 1);
      await shoot('hub_seed', 'conservatory', stars: 3);
      await shoot(
        'hub_seed_drawn',
        'conservatory',
        stars: 3,
        setup: (g) {
          final at = g.currentRoom.grove!.seedPlanter!;
          _tend(g, at, ['Water']);
          _tend(g, at, ['Crystal']);
        },
        seconds: 2.0,
      );
      await shoot(
        'hub_flower',
        'conservatory',
        stars: 3,
        setup: (g) => g.discoveredClouds.add(kPlantOppositeSeedEggId),
        seconds: 3.6,
      );

      // The trellis: bare, the ghost once wet (stopping at the water), set up east,
      // grown to the bud, and the hatch open.
      await shoot('trellis_bare', 'trellis_garden', stars: 1);
      await shoot(
        'trellis_wet_ghost',
        'trellis_garden',
        stars: 1,
        setup: (g) => _tend(g, kTrellisWaterRing.at, ['Water']),
        seconds: 2.0,
      );
      await shoot(
        'trellis_set_east',
        'trellis_garden',
        stars: 1,
        setup: (g) {
          _tend(g, kTrellisWaterRing.at, ['Water']);
          _tend(g, kTrellisIceRing.at, ['Spirit', 'Water']);
          _tend(g, kTrellisEastLightRing.at, ['Crystal', 'Spirit']);
          _park(g);
        },
        seconds: 2.5,
      );
      // The Bud Star, beat by beat: the coil and swell, the burst with its
      // star, the pollen streaming north, and the bloom settled.
      for (final (name, secs) in [
        ('trellis_bud_swell', 2.6),
        ('trellis_bud_burst', 3.3),
        ('trellis_bud_stream', 4.5),
        ('trellis_grown', 5.6),
        ('trellis_then_crown', 8.0),
      ]) {
        await shoot(
          name,
          'trellis_garden',
          stars: 1,
          setup: (g) {
            _tend(g, kTrellisWaterRing.at, ['Water']);
            _tend(g, kTrellisIceRing.at, ['Spirit', 'Water']);
            _tend(g, kTrellisEastLightRing.at, ['Crystal', 'Spirit']);
            _tend(g, kTrellisRootKnuckle, ['Water']);
            _park(g);
          },
          seconds: secs,
        );
      }
      await shoot(
        'trellis_hatch',
        'trellis_garden',
        stars: 1,
        setup: (g) {
          _tend(g, kTrellisWaterRing.at, ['Water']);
          _tend(g, kTrellisWestLightRing.at, ['Crystal', 'Spirit']);
          _tend(g, kTrellisRootKnuckle, ['Water']);
          _park(g);
        },
        seconds: 2.6,
      );
      await shoot('cellar', 'root_cellar', stars: 1);

      // The rite: bare, mid-solve, a ghost preview, and the roots let go.
      Offset ring(String tip) => kRootRings[tip]!.at;
      await shoot('rite_bare', 'rootbound_door', stars: 3);
      await shoot(
        'rite_mid',
        'rootbound_door',
        stars: 3,
        setup: (g) {
          _tend(g, ring('C'), ['Water']);
          _tend(g, ring('E'), ['Spirit', 'Crystal']);
          _tend(g, ring('F'), ['Spirit', 'Crystal']);
          _tend(g, ring('C'), ['Water', 'Spirit']);
          _park(g);
        },
        seconds: 2.4,
      );
      await shoot(
        'rite_climbing',
        'rootbound_door',
        stars: 3,
        setup: (g) {
          _tend(g, ring('C'), ['Water']);
          _park(g);
        },
        seconds: 0.45,
      );
      await shoot(
        'rite_ghost',
        'rootbound_door',
        stars: 3,
        park: false,
        setup: (g) {
          _tend(g, ring('C'), ['Water']);
          // Stand the ice pair in C's ring without pressing.
          for (final c in g.creatures) {
            c.position = c.member.element == 'Crystal'
                ? g.currentRoom.bounds.bottomRight - const Offset(40, 40)
                : ring('C');
          }
          g.activeIndex = g.creatures.indexWhere(
            (c) => c.member.element == 'Water',
          );
        },
        seconds: 2.0,
      );
      await shoot(
        'rite_open',
        'rootbound_door',
        stars: 3,
        setup: (g) {
          _tend(g, ring('C'), ['Water']);
          _tend(g, ring('E'), ['Spirit', 'Crystal']);
          _tend(g, ring('F'), ['Spirit', 'Crystal']);
          _tend(g, ring('C'), ['Water', 'Spirit']);
          _tend(g, ring('C'), ['Spirit', 'Crystal']);
          _tend(g, ring('D'), ['Spirit', 'Crystal']);
          _tend(g, ring('D'), ['Water']);
          _park(g);
        },
        seconds: 1.4,
      );
      // The crown: the key, flowering on the Bud Star's cut.
      await shoot(
        'hub_crown_blooming',
        'conservatory',
        stars: 3,
        setup: (g) => g.debugStartCrownBloom(),
        seconds: 1.2,
      );

      // Botanica's arena, calm and wrecked.
      await shoot('arena', 'botanica_heart', stars: 3);
      await shoot(
        'arena_wrecked',
        'botanica_heart',
        stars: 3,
        setup: (g) {
          g.greenhouse.roots.setAll(kRootTarget);
          g.greenhouse.rootsOpen = true;
          g.conduitEnergy['A'] = double.infinity;
          g.conduitEnergy['B'] = double.infinity;
        },
        seconds: 6.0,
      );

      // Every state is its own picture.
      final seen = <int, String>{};
      for (final e in shots.entries) {
        expect(
          seen[e.value],
          isNull,
          reason: '${e.key} draws the same picture as ${seen[e.value]}',
        );
        seen[e.value] = e.key;
      }
    });
  });
}
