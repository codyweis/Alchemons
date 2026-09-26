// REQUIA, RENDERED — both worlds, not just the living one.
//
// The whole-room audit draws every barrow ALIVE. Everything this planet is
// about is the second world and the dead in it, so this draws the barrows in
// both inks, a revenant restless and at rest, the drowned cut and the undug
// grave, and asserts every state is a different picture.


import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_spirit.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlanetDungeonGame _game() {
  final els = kCosmicPlanetEntry['Spirit']!;
  const fams = ['mask', 'pip', 'mane'];
  final party = [
    for (var i = 0; i < els.length; i++)
      CosmicPartyMember(
        instanceId: 'i$i',
        baseId: 'b$i',
        displayName: els[i],
        element: els[i],
        family: fams[i % 3],
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
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.onGameResize(Vector2(900, 600));
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = const Offset(200, 300)
        ..lastSafe = const Offset(200, 300),
    );
  }
  return g;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every state of the echo grave draws its own picture', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final out = Directory('build/room_audit');
      final shots = <String, int>{};

      Future<void> shoot(
        String name,
        String roomId,
        Offset stand,
        void Function(PlanetDungeonGame g) setup, {
        void Function(PlanetDungeonGame g)? then,
        int thenFrames = 0,
      }) async {
        final g = _game();
        g.currentRoomId = roomId;
        g.entryDoorRevealed = true;
        setup(g);
        for (final c in g.creatures) {
          c
            ..position = stand
            ..lastSafe = stand;
        }
        for (var i = 0; i < 24; i++) {
          g.update(1 / 60);
        }
        if (then != null) {
          then(g);
          for (var i = 0; i < thenFrames; i++) {
            g.update(1 / 60);
          }
        }
        final rec = ui.PictureRecorder();
        g.render(Canvas(rec));
        final img = await rec.endRecording().toImage(900, 600);
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

      final layout = kPlanetDungeonLayouts['Spirit']!;
      void ghost(PlanetDungeonGame g) => g.wake.field.world = GraveWorld.ghost;

      await shoot('lych_living', 'lych_gate', const Offset(300, 300), (g) {});
      await shoot('lych_ghost', 'lych_gate', const Offset(300, 300), ghost);
      final urnDead = graveRevenantById('r_bellman')!;
      await shoot('urn_living', 'barrow_urn', const Offset(300, 300), (g) {});
      await shoot('urn_ghost', 'barrow_urn', const Offset(300, 300), ghost);
      await shoot('urn_ghost_at_bellman', 'barrow_urn', urnDead.seat, ghost);
      await shoot('urn_bellman_rested', 'barrow_urn', const Offset(300, 300), (
        g,
      ) {
        ghost(g);
        g.wake.field.tell('r_bellman');
      });
      await shoot('veil_ghost', 'barrow_veil', const Offset(300, 300), ghost);
      await shoot('veil_frozen', 'barrow_veil', const Offset(300, 300), (g) {
        g.wake.field.cutFrozen = true;
      });
      await shoot('mere_living', 'barrow_mere', const Offset(300, 300), (g) {});
      await shoot('mere_ghost', 'barrow_mere', const Offset(300, 300), ghost);
      await shoot('walk_living', 'mourners_walk', const Offset(300, 300), (g) {});
      await shoot('walk_ghost', 'mourners_walk', const Offset(300, 300), ghost);
      await shoot('arena_ghost', 'wraithord_grave', const Offset(300, 300), ghost);
      expect(layout.rooms.containsKey('barrow_urn'), isTrue);

      const groups = [
        ['lych_living', 'lych_ghost'],
        ['urn_living', 'urn_ghost', 'urn_ghost_at_bellman', 'urn_bellman_rested'],
        ['veil_ghost', 'veil_frozen'],
        ['mere_living', 'mere_ghost'],
        ['walk_living', 'walk_ghost'],
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
