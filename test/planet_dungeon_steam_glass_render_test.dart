// VAPORIS, IN GLASS — the states Steam's glass is meant to show
// (docs/dungeons.md §7.11), asserted to be different pictures.
//
// The rooms whole are `planet_dungeon_whole_room_audit_test.dart
// --dart-define=AUDIT=Steam`; this is the STATES. Hidden Harmony is shot from
// a game where only the maxim's id is set — a found maxim's mark must stand on
// every later descent.
//
// `mkdir -p build/room_audit` and run this to get the PNGs (SteamGlass_*.png).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PlanetDungeonGame> _game(String roomId, {int stars = 0}) async {
  const els = ['Steam', 'Fire', 'Earth'];
  const fams = ['mane', 'horn', 'mask'];
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
    element: 'Steam',
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  await g.debugLoadFx();
  g.starMask = stars; // applied in onLoad, which a headless game never runs
  final b = kPlanetDungeonLayouts['Steam']!.rooms[roomId]!.bounds;
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

  testWidgets('every state the boiler house\'s glass shows', (tester) async {
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
            'build/room_audit/SteamGlass_$name.png',
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

      // The gate: the vent unturned, then the seal hissed open.
      await shoot(
        'gate',
        'boiler_gate',
        setup: (g) => g.entryDoorRevealed = false,
      );
      await shoot('gate_open', 'boiler_gate', seconds: 2.0);

      // A junction the main cannot pay for, then can.
      await shoot(
        'manifold_poor',
        'manifold_south',
        setup: (g) => g.boilerPressure = 0,
      );
      await shoot(
        'manifold_rich',
        'manifold_south',
        setup: (g) => g.boilerPressure = 99,
      );

      // The crucible: corners open, then two sealed.
      await shoot('crucible', 'crucible', stars: 0x3);
      await shoot(
        'crucible_two',
        'crucible',
        stars: 0x3,
        setup: (g) {
          final seals = g.layout.rooms['crucible']!.crucibleSeals;
          g.sealedCorners.addAll([seals[0].id, seals[1].id]);
        },
      );

      // The scald cellar: the maxim waiting; sinking into the stone as the
      // rite binds; and the inlay on a later descent (the id alone).
      await shoot('cellar', 'scald_cellar');
      await shoot(
        'cellar_setting',
        'scald_cellar',
        setup: (g) {
          final cache = g.layout.rooms['scald_cellar']!.maximCache!;
          g.beginMaximRite(kSteamHiddenHarmonyEggId, cache);
        },
        seconds: 1.2,
      );
      await shoot(
        'cellar_found',
        'scald_cellar',
        setup: (g) => g.discoveredClouds.add(kSteamHiddenHarmonyEggId),
      );

      await shoot('heart', 'boiler_heart');

      for (final (a, b) in const [
        ('gate', 'gate_open'),
        ('manifold_poor', 'manifold_rich'),
        ('crucible', 'crucible_two'),
        ('cellar', 'cellar_setting'),
        ('cellar_setting', 'cellar_found'),
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
