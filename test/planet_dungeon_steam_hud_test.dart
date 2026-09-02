// THE PRESSURE GAUGE RAN OFF THE EDGE OF A PHONE, and no test could have told
// me: every number in it was right. The header was painted from a fixed left
// origin, so "HEAD 20 · 1 VENTING" simply walked past the right-hand edge of
// the screen, and the bleed was drawn as a red segment ON TOP of the amber and
// cyan ones so the bar read as one broken thing.
//
// It is right-aligned to the bar now, and the venting count has its own line.
// This renders the HUD and LOOKS at the pixels, because looking is the only
// thing that would have caught it.

import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter/material.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the pressure gauge stays inside the screen', (tester) async {
    await tester.runAsync(() async {
      const viewports = [Size(760, 420), Size(900, 500), Size(1280, 720)];
      const fields = [
        <String>[],
        ['r_hob_b'],
        ['r_hob_a', 'r_hob_b'],
      ];
      for (final vp in viewports) {
        for (final held in fields) {
          final game = PlanetDungeonGame(
            element: 'Steam',
            party: [
              _member(0, 'Steam', 'mask'),
              _member(1, 'Earth', 'horn'),
              _member(2, 'Fire', 'pip'),
            ],
            initialStarMask: 0,
            onStarEarned: (_) {},
            onPlayerDown: () {},
            onChanged: () {},
          );
          game.currentRoomId = 'cinder_forge';
          game.boilerPressure = 30;
          final room = game.layout.rooms['cinder_forge']!;
          for (final m in game.party) {
            game.creatures.add(
              DungeonCreature(member: m)
                ..position = const Offset(200, 180)
                ..lastSafe = const Offset(200, 180),
            );
          }
          for (var i = 0; i < 5; i++) {
            for (var k = 0; k < held.length; k++) {
              game.creatures[k].position = room.geysers
                  .firstWhere((g) => g.id == held[k])
                  .position;
            }
            game.update(1 / 60);
          }

          final rec = ui.PictureRecorder();
          game.drawSteamHudForDebug(Canvas(rec), vp);
          final img = await rec.endRecording().toImage(
            vp.width.toInt(),
            vp.height.toInt(),
          );
          final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
          final px = data!.buffer.asUint8List();
          final w = vp.width.toInt();
          var bled = 0;
          for (var y = 0; y < vp.height.toInt(); y++) {
            for (var x = w - 6; x < w; x++) {
              if (px[(y * w + x) * 4 + 3] != 0) bled++;
            }
          }
          expect(
            bled,
            0,
            reason:
                'the gauge paints into the right-hand margin at $vp with '
                '${held.length} mouth(s) held — the HEADER is what grows, so '
                'this is what a longer reading looks like',
          );
        }
      }
    });
  });
}
