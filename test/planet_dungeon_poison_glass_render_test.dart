// THE VENOM MONASTERY, IN GLASS — the states Poison's glass is meant to show
// (docs/dungeons.md §7.11), asserted to be different pictures.
//
// The rooms whole are `planet_dungeon_whole_room_audit_test.dart
// --dart-define=AUDIT=Poison`; this is the STATES. The Dose is shot from a
// game where only the maxim's id is set — a found maxim's mark must stand on
// every later descent.
//
// `mkdir -p build/room_audit` and run this to get the PNGs (PoisonGlass_*.png).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_poison.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PlanetDungeonGame> _game(String roomId, {int stars = 0}) async {
  const els = ['Poison', 'Plant', 'Mud'];
  const fams = ['mask', 'mane', 'horn'];
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
    element: 'Poison',
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  await g.debugLoadFx();
  g.starMask = stars; // applied in onLoad, which a headless game never runs
  final b = kPlanetDungeonLayouts['Poison']!.rooms[roomId]!.bounds;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every state the monastery\'s glass shows', (tester) async {
    await tester.runAsync(() async {
      final out = Directory('build/room_audit');
      final shots = <String, int>{};

      Future<void> shoot(
        String name,
        String roomId, {
        int stars = 0,
        void Function(PlanetDungeonGame g)? setup,
        double seconds = 0.4,
      }) async {
        final g = await _game(roomId, stars: stars);
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
            'build/room_audit/PoisonGlass_$name.png',
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

      // The ambulatory's cross: the Dose unscored, two colours home, the
      // heart blooming as the rite binds, and kept on a later descent.
      // The entrance pot: two of three have given.
      await shoot(
        'gate_pot',
        'lazar_gate',
        setup: (g) {
          g.entryDoorRevealed = false;
          g.monastery.entryGiven.addAll([
            for (final c in g.creatures.take(2)) c.member.instanceId,
          ]);
        },
      );
      // The boil-over, just as the bottles burst.
      await shoot(
        'boil_over',
        'apothecary',
        setup: (g) {
          g.monastery
            ..bottled.addAll(['bloomvenom', 'mirebane'])
            ..boilOver = 0
            ..boilBottles = 2;
        },
        seconds: 1.05,
      );
      await shoot('cross', 'ambulatory');
      await shoot(
        'cross_two_home',
        'ambulatory',
        setup: (g) => g.monastery.wispStage = 2,
      );
      await shoot(
        'cross_blooming',
        'ambulatory',
        setup: (g) {
          // The third colour home: the wisp is gone, as it is in play.
          g.monastery
            ..wispStage = 3
            ..wisp = null;
          final at = g.layout.rooms['ambulatory']!.priorsSeal!.position;
          g.beginMaximRite(kPoisonDoseEggId, at);
        },
        seconds: 0.9,
      );
      await shoot(
        'cross_dose',
        'ambulatory',
        setup: (g) => g.discoveredClouds.add(kPoisonDoseEggId),
      );

      await shoot('gate', 'lazar_gate');
      await shoot('apothecary', 'apothecary');

      for (final (a, b) in const [
        ('cross', 'cross_two_home'),
        ('cross_two_home', 'cross_blooming'),
        ('cross', 'cross_dose'),
      ]) {
        expect(
          shots[a] != shots[b],
          isTrue,
          reason: '$a and $b draw the same picture',
        );
      }
    });
  });
}
