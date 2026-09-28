// REQUIA, RENDERED — both worlds and every state the funeral shows.
//
// The whole-room audit draws each room once, in the present. This planet is
// read by comparing the past with the present and by watching reactions, so
// this draws each room in both worlds, the loop's states (ready, made,
// carried, fitted, pulsed) and each star's finished scene, and asserts they
// are different pictures.
//
// `mkdir -p build/room_audit` and run this to get the PNGs (SpiritState_*).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_spirit.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PlanetDungeonGame> _game(String roomId, int stars) async {
  final els = kCosmicPlanetEntry['Spirit']!;
  const fams = ['mask', 'pip', 'wing'];
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
    element: 'Spirit',
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  await g.debugLoadFx();
  g.starMask = stars;
  g.debugResetPuzzleState();
  final b = kPlanetDungeonLayouts['Spirit']!.rooms[roomId]!.bounds;
  g.onGameResize(Vector2(b.width + 60, b.height + 60));
  g.entryDoorRevealed = true;
  g.currentRoomId = roomId;
  g.funeral.lastRoom = roomId;
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = Offset(b.left + 90, b.bottom - 60)
        ..lastSafe = Offset(b.left + 90, b.bottom - 60),
    );
  }
  return g;
}

FuneralRoom _fr(String room) =>
    kPlanetDungeonLayouts['Spirit']!.rooms[room]!.funeral!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every state of the unfinished funeral draws its own picture', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final out = Directory('build/room_audit');
      final shots = <String, int>{};

      Future<void> shoot(
        String name,
        String roomId, {
        int stars = 0,
        void Function(PlanetDungeonGame g)? setup,
        void Function(PlanetDungeonGame g)? then,
        Offset? stand,
      }) async {
        final g = await _game(roomId, stars);
        if (stand != null) {
          for (final c in g.creatures) {
            c
              ..position = stand
              ..lastSafe = stand;
          }
        }
        setup?.call(g);
        for (var i = 0; i < 12; i++) {
          g.update(1 / 60);
        }
        then?.call(g);
        final rec = ui.PictureRecorder();
        g.render(Canvas(rec));
        final img = await rec.endRecording().toImage(
          g.size.x.round(),
          g.size.y.round(),
        );
        if (out.existsSync()) {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File(
            'build/room_audit/SpiritState_$name.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        }
        final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        final b = raw!.buffer.asUint8List();
        var h = 17;
        for (var i = 0; i < b.length; i += 97) {
          h = (h * 31 + b[i]) & 0x3FFFFFFF;
        }
        shots[name] = h;
      }

      void ghost(PlanetDungeonGame g) =>
          g.funeral.run.world = FuneralWorld.ghost;
      void at(PlanetDungeonGame g, double clock) => g.funeral.clock = clock;

      // The memorial.
      await shoot(
        'memorial_sealed',
        'memorial',
        setup: (g) {
          g.entryDoorRevealed = false;
        },
      );
      await shoot('memorial_living', 'memorial');
      await shoot('memorial_ghost', 'memorial', setup: ghost);

      // STAR 1 — the bell court, through the loop.
      final bell = _fr('bell_court');
      await shoot('bell_living', 'bell_court');
      await shoot(
        'bell_ghost',
        'bell_court',
        setup: ghost,
        then: (g) => at(g, 3.9),
      );
      await shoot(
        'bell_ghost_walk',
        'bell_court',
        setup: ghost,
        then: (g) => at(g, 2.4),
      );
      for (final phase in {
        'combine': 2.0,
        'form': 3.7,
        'carry': 6.0,
        'fit': 7.9,
        'ring': 9.8,
      }.entries) {
        await shoot(
          'bell_lesson_${phase.key}',
          'bell_court',
          setup: ghost,
          then: (g) => at(g, phase.value),
        );
      }
      await shoot('bell_ready', 'bell_court', stand: bell.urn);
      await shoot(
        'bell_made',
        'bell_court',
        setup: (g) {
          g.funeral.run.crystals.add('urn_keeper');
        },
      );
      await shoot(
        'bell_carried',
        'bell_court',
        stand: bell.socket!.at,
        setup: (g) {
          g.funeral.run
            ..crystals.add('urn_keeper')
            ..held = 'urn_keeper';
        },
      );
      await shoot(
        'bell_fitted',
        'bell_court',
        setup: (g) {
          g.funeral.run
            ..crystals.add('urn_keeper')
            ..fitted.add('sk_treadle');
        },
      );
      await shoot(
        'bell_ringing',
        'bell_court',
        setup: (g) {
          g.funeral.run
            ..crystals.add('urn_keeper')
            ..fitted.add('sk_treadle');
        },
        then: (g) => g.funeral.bellT = 2.6,
      );
      await shoot('bell_rung', 'bell_court', stars: 0x1);
      await shoot(
        'bell_niche_cleared',
        'bell_court',
        stars: 0x1,
        setup: (g) {
          g.funeral.run.nicheCleared = true;
        },
      );

      // STAR 2 — the bearers' court.
      await shoot('bearers_living', 'bearers_court', stars: 0x1);
      await shoot(
        'bearers_ghost',
        'bearers_court',
        stars: 0x1,
        setup: ghost,
        then: (g) => at(g, 3.2),
      );
      // Standing on a flag: it and every flag its beams flip light warm.
      await shoot(
        'bearers_flip_preview',
        'bearers_court',
        stars: 0x1,
        stand: _fr('bearers_court').flagCentre(0),
      );
      // The bier at the chapel door: the whole route lit, the door opening.
      await shoot(
        'bearers_ghost_arrive',
        'bearers_court',
        stars: 0x1,
        setup: ghost,
        then: (g) => at(g, 6.7),
      );
      await shoot(
        'bearers_stopped',
        'bearers_court',
        stars: 0x1,
        setup: (g) {
          g.funeral.run
            ..crystals.add('urn_bearers')
            ..fitted.add('sk_doorstep');
          g.funeral
            ..walkDist = 150
            ..walkStop = 150;
        },
      );
      await shoot('bearers_done', 'bearers_court', stars: 0x3);

      // THE RITE — the chapel.
      final chapel = _fr('vigil_chapel');
      await shoot('chapel_living', 'vigil_chapel', stars: 0x3);
      await shoot('chapel_ghost', 'vigil_chapel', stars: 0x3, setup: ghost);
      await shoot(
        'chapel_rite',
        'vigil_chapel',
        stars: 0x3,
        setup: (g) {
          g.funeral.run
            ..crystals.add('urn_mourners')
            ..fitted.add('sk_bier');
          for (final c in g.creatures) {
            final at = kMournerAt.entries
                .firstWhere((e) => e.value == c.member.element)
                .key;
            c.position = chapel.stones[at];
          }
        },
        then: (g) => g.funeral.riteT = 2.4,
      );

      // THE MAXIM — the quiet alcove.
      await shoot('alcove_living', 'quiet_alcove');
      await shoot(
        'alcove_echoes',
        'quiet_alcove',
        setup: (g) {
          g.funeral.run.world = FuneralWorld.ghost;
          g.funeral.run.echoes.addAll([
            (kAlcoveKneelers[3], 'Spirit'),
            (kAlcoveKneelers[0], 'Blood'),
            (kAlcoveKneelers[1], 'Dust'),
          ]);
        },
      );
      await shoot(
        'alcove_named',
        'quiet_alcove',
        setup: (g) {
          g.discoveredClouds.add(kSpiritEmptyUrnEggId);
          g.debugResetPuzzleState();
        },
      );

      // STAR 3 — the vigil chime.
      await shoot('vigil_cold', 'wraithord_vigil', stars: 0x3);
      await shoot(
        'vigil_warm',
        'wraithord_vigil',
        stars: 0x3,
        then: (g) => g.funeral.chimeWarm = true,
      );

      const groups = [
        ['memorial_sealed', 'memorial_living', 'memorial_ghost'],
        [
          'bell_living',
          'bell_ghost',
          'bell_ghost_walk',
          'bell_ready',
          'bell_made',
          'bell_carried',
          'bell_fitted',
          'bell_ringing',
          'bell_rung',
          'bell_niche_cleared',
        ],
        ['bearers_living', 'bearers_flip_preview', 'bearers_ghost', 'bearers_ghost_arrive', 'bearers_stopped', 'bearers_done'],
        ['chapel_living', 'chapel_ghost', 'chapel_rite'],
        ['alcove_living', 'alcove_echoes', 'alcove_named'],
        ['vigil_cold', 'vigil_warm'],
      ];
      for (final g in groups) {
        for (var i = 0; i < g.length; i++) {
          for (var j = i + 1; j < g.length; j++) {
            expect(
              shots[g[i]],
              isNot(shots[g[j]]),
              reason: '${g[i]} and ${g[j]} draw the same room',
            );
          }
        }
      }
    });
  });
}
