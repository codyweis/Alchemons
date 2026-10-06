// THE HEART, FILMED — Blood taken up into the open space, a fusion and its
// element rising up its column, fusing with what hangs there and what they
// make pouring down (or, making nothing, gathering back), and Blood made
// and freed — with real species, on a phone-shaped screen so the
// close camera and its cut up to the elements show. With `build/room_audit`
// present it writes HeartMoments_<name>.png strips. A camera, not a judge:
// it asserts only that each moment moves.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_debug_party.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_blood_heart.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_blood_rites.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_blood.dart';
import 'package:alchemons/models/creature.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final List<Creature> _all = [
  for (final c in ((jsonDecode(File('assets/data/alchemons_creatures.json').readAsStringSync())
          as Map<String, dynamic>)['creatures'] as List)
      .cast<Map<String, dynamic>>())
    Creature.fromJson(c),
];

Creature _creature(String id) => _all.firstWhere((c) => c.id == id);

Map<String, List<CosmicPartyMember>> _species() {
  final out = <String, List<CosmicPartyMember>>{};
  for (final c in _all) {
    if (c.spriteData == null || (c.mutationFamily ?? '').toLowerCase() == 'mystic') continue;
    (out[c.types.first] ??= []).add(debugMemberFromCreature(c, statTier: 3));
  }
  return out;
}

Future<PlanetDungeonGame> _game() async {
  final blood = debugMemberFromCreature(_creature('KIN17'));
  final g = PlanetDungeonGame(
    element: 'Blood',
    party: [blood],
    initialStarMask: 1,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
    riteCaptives: [
      for (final id in const ['KIN04', 'KIN01', 'KIN03', 'KIN02']) debugMemberFromCreature(_creature(id)),
    ],
    riteSpecies: _species(),
  );
  await g.debugLoadFx();
  await g.debugLoadSky();
  await g.debugLoadRiteAllies();
  g.starMask = 1;
  for (final el in kRiteElements) {
    g.discoveredClouds.add(riteFreedId(el));
  }
  g.onGameResize(Vector2(916, 265));
  g.currentRoomId = 'rite_circle';
  final c = DungeonCreature(member: blood)
    ..position = const Offset(450, 520)
    ..lastSafe = const Offset(450, 520);
  g.creatures.add(c);
  await g.debugLoadSprite(c);
  g.update(1 / 60);
  return g;
}

Future<void> _run(PlanetDungeonGame g, double secs) async {
  var tick = 0;
  for (var t = 0.0; t < secs; t += 1 / 60) {
    g.update(1 / 60);
    if (++tick % 6 == 0) await Future<void>.delayed(const Duration(milliseconds: 4));
  }
}

Future<int> _film(PlanetDungeonGame g, String name, List<double> times, {double scale = .5}) async {
  final frames = <ui.Image>[];
  var t = 0.0, tick = 0;
  for (final want in times) {
    while (t < want) {
      g.update(1 / 60);
      t += 1 / 60;
      if (++tick % 6 == 0) await Future<void>.delayed(const Duration(milliseconds: 4));
    }
    final rec = ui.PictureRecorder();
    g.render(Canvas(rec));
    frames.add(await rec.endRecording().toImage(g.size.x.round(), g.size.y.round()));
  }
  final fw = frames.first.width * scale, fh = frames.first.height * scale;
  const cols = 3;
  final rows = (frames.length / cols).ceil();
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(Rect.fromLTWH(0, 0, fw * cols, fh * rows), Paint()..color = Colors.black);
  for (var i = 0; i < frames.length; i++) {
    final dst = Rect.fromLTWH((i % cols) * fw, (i ~/ cols) * fh, fw - 2, fh - 2);
    c.drawImageRect(
      frames[i],
      Rect.fromLTWH(0, 0, frames[i].width.toDouble(), frames[i].height.toDouble()),
      dst,
      Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final tp = TextPainter(
      text: TextSpan(text: '${times[i].toStringAsFixed(2)}s', style: const TextStyle(color: Colors.white70, fontSize: 12)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, dst.topLeft + const Offset(4, 4));
  }
  final strip = await rec.endRecording().toImage((fw * cols).round(), (fh * rows).round());
  if (Directory('build/room_audit').existsSync()) {
    final png = await strip.toByteData(format: ui.ImageByteFormat.png);
    File('build/room_audit/HeartMoments_$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }
  final a = (await frames.first.toByteData())!.buffer.asUint8List();
  final b = (await frames.last.toByteData())!.buffer.asUint8List();
  var diff = 0;
  for (var i = 0; i < a.length; i += 4 * 53) {
    if ((a[i] - b[i]).abs() > 8) diff++;
  }
  return diff;
}

/// Put the creature of [el] (on [from], if two share it) on [cell] and make
/// it the one being steered.
void _put(PlanetDungeonGame g, String el, RiteCell cell, {RiteCell? from}) {
  final i = g.creatures.indexWhere(
    (c) => c.member.element == el && (from == null || riteSquareAt(c.position) == from),
  );
  if (i < 0) {
    throw StateError('no $el${from == null ? '' : ' at $from'} among '
        '${g.creatures.map((c) => '${c.member.element}@${riteSquareAt(c.position)}').join(' ')}');
  }
  final c = g.creatures[i];
  c
    ..position = riteCentreOf(cell.x, cell.y)
    ..lastSafe = riteCentreOf(cell.x, cell.y);
  g.setActive(i);
}

/// [a] walks onto [ab] while [b] waits on [bf] (the one arriving is the one
/// that stands still and fuses).
Future<void> _fuse(PlanetDungeonGame g, String a, RiteCell ab, String b, RiteCell bf, {RiteCell? aFrom}) async {
  _put(g, b, bf);
  _put(g, a, ab, from: aFrom);
  await _run(g, .6);
}

Future<void> _settle(PlanetDungeonGame g) async {
  for (var i = 0; i < 40; i++) {
    final h = g.rites.heart;
    if (h.morphs.isEmpty && h.powers.isEmpty && h.captureT < 0 && h.finaleT < 0) break;
    await _run(g, .25);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the Heart, from the capture to Blood freed', (tester) async {
    await tester.runAsync(() async {
      final g = await _game();
      g.passThroughDoor(g.currentRoom.doors.firstWhere((d) => d.targetRoomId == 'rite_heart'));
      await g.debugHeartPrepare();
      expect(await _film(g, 'capture', [0, .6, 1.1, 1.6, 2.1, 2.6, 3.1, 3.5, 4.0, 4.4, 4.9, 5.8]), greaterThan(0));
      await _settle(g);
      const a1b = (x: 2, y: 7), a1f = (x: 2, y: 6);
      const a2b = (x: 5, y: 7), a2f = (x: 5, y: 6);
      const a3b = (x: 8, y: 7), a3f = (x: 8, y: 6);
      const a4b = (x: 11, y: 7), a4f = (x: 11, y: 6);
      const split = (x: 1, y: 7);
      const fused = [0.0, 1.0, 1.8, 2.2, 2.5, 2.8, 3.1, 3.5, 3.9, 4.3, 4.8, 5.6];

      // Mud rises into the Spirit over altar 2: they make nothing, and it
      // gathers back.
      _put(g, 'Water', a2f);
      _put(g, 'Earth', a2b);
      expect(await _film(g, 'nothing', [0, 1.0, 2.0, 2.4, 2.8, 3.2, 3.6, 4.0, 4.4, 4.8, 5.2, 5.8]), greaterThan(0));
      await _settle(g);
      _put(g, 'Mud', split);
      await _run(g, .6);
      await _settle(g);
      // 1. Air + Fire on altar 4: Lightning rises into the Earth; the Crystal
      //    they make pours down.
      _put(g, 'Fire', a4f);
      _put(g, 'Air', a4b);
      expect(await _film(g, 'crystal_down', fused), greaterThan(0));
      await _settle(g);
      // 2. Split it: Lightning, and the Earth from up there.
      _put(g, 'Crystal', split);
      await _run(g, .6);
      await _settle(g);
      // 3. Earth + Lightning on altar 3: Crystal rises into the Spirit → Light.
      _put(g, 'Earth', a3f);
      _put(g, 'Lightning', a3b);
      expect(await _film(g, 'light', fused), greaterThan(0));
      await _settle(g);
      _put(g, 'Light', (x: 7, y: 7));
      // 4. Earth + Water on altar 3: Mud rises past where the Spirit was into
      //    the Lava → Poison.
      _put(g, 'Water', a3f);
      _put(g, 'Earth', a3b);
      expect(await _film(g, 'poison', [0, 1.0, 2.0, 2.4, 2.8, 3.2, 3.6, 4.0, 4.4, 4.8, 5.4, 6.4]), greaterThan(0));
      await _settle(g);
      // 5. Split the Poison: Lava and Mud.
      _put(g, 'Poison', split);
      await _run(g, .6);
      await _settle(g);
      // 6. Lava + Mud on altar 2: Poison rises into the Spirit → Dark.
      _put(g, 'Mud', a2f);
      _put(g, 'Lava', a2b);
      expect(await _film(g, 'dark', fused), greaterThan(0));
      await _settle(g);
      // 7. Light + Dark: Blood, poured into the Blood that was taken; the
      //    bands let go and the four re-form.
      _put(g, 'Light', a1f);
      _put(g, 'Dark', a1b);
      expect(
        await _film(g, 'finale', [0, .9, 1.6, 2.2, 2.8, 3.4, 4.0, 4.6, 5.2, 5.8, 6.4, 7.6]),
        greaterThan(0),
      );
      await _settle(g);
      expect(g.rites.heart.freed, isTrue);
    });
  });

  testWidgets('tapping what hangs there shows its name in grains', (tester) async {
    await tester.runAsync(() async {
      // Real letters for the film (the test font draws boxes).
      final sdk = Platform.environment['FLUTTER_ROOT'];
      final ttf = File('$sdk/bin/cache/artifacts/material_fonts/Roboto-Black.ttf');
      if (sdk != null && ttf.existsSync()) {
        await (FontLoader('Roboto')..addFont(ttf.readAsBytes().then(ByteData.sublistView))).load();
      }
      final g = await _game();
      g.passThroughDoor(g.currentRoom.doors.firstWhere((d) => d.targetRoomId == 'rite_heart'));
      await g.debugHeartPrepare();
      await _settle(g);
      await _run(g, 1);
      // Empty air answers nothing; the Spirit over altar 2 shows its name.
      expect(g.tapWorld(g.worldToScreen(riteCentreOf(3, 2))), isFalse);
      expect(g.tapWorld(g.worldToScreen(riteCentreOf(5, 4))), isTrue);
      for (var i = 0; i < 20 && g.rites.heart.words.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        g.update(1 / 60);
      }
      expect(g.rites.heart.words, hasLength(1));
      expect(g.rites.heart.words.values.single.word.text, 'SPIRIT');
      expect(g.rites.heart.words.values.single.word.length, greaterThan(80));
      expect(await _film(g, 'name', [0, .25, .5, .8, 1.3, 2.0, 2.5, 2.9, 3.3], scale: 1), greaterThan(0));
      await _run(g, 1.5);
      expect(g.rites.heart.words, isEmpty, reason: 'and it is gone');
    });
  });

  testWidgets('stills: the stage played close, and the whole theatre', (tester) async {
    await tester.runAsync(() async {
      final g = await _game();
      g.passThroughDoor(g.currentRoom.doors.firstWhere((d) => d.targetRoomId == 'rite_heart'));
      await g.debugHeartPrepare();
      // Blood bound, the camera held up on it.
      expect(await _film(g, 'still_bound', [3.4], scale: 1), greaterThanOrEqualTo(0));
      await _settle(g);
      await _run(g, 1);
      expect(await _film(g, 'still_phone', [0], scale: 1), greaterThanOrEqualTo(0));
      g.onGameResize(Vector2(1100, 660));
      await _run(g, 1.5);
      expect(await _film(g, 'still_whole', [0], scale: 1), greaterThanOrEqualTo(0));
    });
  });

}
