@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A guardian's death in grains of itself, rendered by the real game frame:
// raid guardians with their Mystic sprites, a dungeon guardian whose relic
// rises out of the last of it, and the procedural stand-in. One sheet per
// guardian, two rows of moments (times below, left to right).
//
//   RAID_DEATH_OUT=/tmp/raid_death.png flutter test \
//     test/guardian_grain_death_preview_test.dart --tags preview
//
// writes /tmp/raid_death_<name>.png for each.
void main() {
  final out = Platform.environment['RAID_DEATH_OUT'];

  testWidgets('guardian grain death preview', (tester) async {
    if (out == null) return;
    const cases = [
      ('air_raid', 'Air', true, true),
      ('fire_dungeon', 'Fire', false, true),
      ('dark_raid', 'Dark', true, true),
      ('procedural', 'Earth', true, false),
    ];
    const times = [
      0.0, 0.18, 0.3, 0.5, 0.8, 1.1, 1.35, 1.6, //
      1.85, 2.02, 2.1, 2.22, 2.45, 2.75, 3.1, 3.45,
    ];
    const cell = 340.0, gap = 4.0, cols = 8;

    await tester.runAsync(() async {
      for (final (name, element, raid, art) in cases) {
        final (g, at) = await _killedGuardian(element, raid: raid, art: art);
        final c = g.worldToScreen(at - const Offset(0, 16));
        final frames = <ui.Image>[];
        for (final t in times) {
          g.debugSeekGuardianDeath(t);
          final rec = ui.PictureRecorder();
          g.render(Canvas(rec));
          frames.add(
            rec.endRecording().toImageSync(g.size.x.round(), g.size.y.round()),
          );
        }
        // The whole death, and a closer look at the seize and the implosion.
        await _sheet(frames, c, 340, cell, gap, cols, out, name);
        await _sheet(
          frames.sublist(0, 8),
          c,
          190,
          cell,
          gap,
          cols,
          out,
          '${name}_close',
        );
        for (final f in frames) {
          f.dispose();
        }
      }
    });
  });
}

Future<void> _sheet(
  List<ui.Image> frames,
  Offset c,
  double crop,
  double cell,
  double gap,
  int cols,
  String out,
  String name,
) async {
  final rows = (frames.length / cols).ceil();
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  final w = cols * (cell + gap), h = rows * (cell + gap);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()..color = const Color(0xFF0B0A10),
  );
  for (var k = 0; k < frames.length; k++) {
    final x = (k % cols) * (cell + gap), y = (k ~/ cols) * (cell + gap);
    canvas.drawImageRect(
      frames[k],
      Rect.fromCenter(center: c, width: crop, height: crop),
      Rect.fromLTWH(x, y, cell, cell),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
  final img = rec.endRecording().toImageSync(w.round(), h.round());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  final path = out.replaceFirst(RegExp(r'\.png$'), '_$name.png');
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
}

/// A run with its guardian down this frame: the death begun, its body read.
Future<(PlanetDungeonGame, Offset)> _killedGuardian(
  String element, {
  required bool raid,
  required bool art,
}) async {
  const fams = ['horn', 'wing', 'pip'];
  final party = [
    for (var i = 0; i < 3; i++)
      CosmicPartyMember(
        instanceId: 'i$i',
        baseId: 'b$i',
        displayName: '$element $i',
        element: element,
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
    element: element,
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
    raid: raid ? const RaidConfig() : null,
    layoutOverride: raid ? buildRaidArenaLayout(element) : null,
  );
  await g.debugLoadFx();
  try {
    await g.debugLoadSky();
  } catch (_) {}
  if (art) await g.debugLoadGuardianArt();
  g.onGameResize(Vector2(760, 760));
  g.entryDoorRevealed = true;
  final spawn = g.layout.entranceSpawn;
  for (var i = 0; i < party.length; i++) {
    g.creatures.add(
      DungeonCreature(member: party[i])
        ..position = spawn + Offset(i * 50.0, 0)
        ..lastSafe = spawn + Offset(i * 50.0, 0),
    );
  }
  if (!raid) g.debugSpawnGuardian();
  for (var i = 0; i < 200; i++) {
    g.update(1 / 60);
  }
  final guardian = g.combatEnemies.firstWhere((e) => e.isElite);
  final at = guardian.position;
  guardian
    ..hp = 0
    ..isDead = true;
  g.update(1 / 60);
  await g.debugGuardianDeathRead();
  // Let the camera settle on the shot.
  for (var i = 0; i < 40; i++) {
    g.update(1 / 60);
  }
  return (g, at);
}
