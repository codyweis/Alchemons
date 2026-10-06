// THE BLOOD RITES' MOMENTS, FILMED — a captive's release, an ally's
// sacrifice, the Water room turning over, the Circle's cups filling — each
// laid out as a strip of frames through its time, with real creatures. With
// `build/room_audit` present it writes BloodMoments_<name>.png. A camera,
// not a judge: it asserts only that each moment moves.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/planet_dungeon/dungeon_debug_party.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_blood_rites.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_blood.dart';
import 'package:alchemons/models/creature.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Creature _creature(String id) {
  final json =
      jsonDecode(File('assets/data/alchemons_creatures.json').readAsStringSync())
          as Map<String, dynamic>;
  return Creature.fromJson(
    (json['creatures'] as List).cast<Map<String, dynamic>>().firstWhere(
      (c) => c['id'] == id,
    ),
  );
}

Future<PlanetDungeonGame> _game(
  String room, {
  int stars = 0,
  Set<String> freed = const {},
  Size view = const Size(760, 640),
}) async {
  final blood = debugMemberFromCreature(_creature('KIN17'));
  final g = PlanetDungeonGame(
    element: 'Blood',
    party: [blood],
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
    riteCaptives: [
      for (final id in const ['KIN04', 'KIN01', 'KIN03', 'KIN02'])
        debugMemberFromCreature(_creature(id)),
    ],
  );
  await g.debugLoadFx();
  await g.debugLoadSky();
  await g.debugLoadRiteAllies();
  g.starMask = stars;
  for (final el in freed) {
    g.discoveredClouds.add(riteFreedId(el));
  }
  g.onGameResize(Vector2(view.width, view.height));
  g.currentRoomId = room;
  final c = DungeonCreature(member: blood);
  g.creatures.add(c);
  await g.debugLoadSprite(c);
  return g;
}

void _place(PlanetDungeonGame g, RiteCell at) {
  g.creatures.first
    ..position = riteCentreOf(at.x, at.y)
    ..lastSafe = riteCentreOf(at.x, at.y);
}

/// Run [g] to each of [times] (seconds from now), snapping a frame at each,
/// and lay the frames out in a strip.
Future<int> _film(
  PlanetDungeonGame g,
  String name,
  List<double> times, {
  double scale = .42,
  Offset? focus,
  double radius = 220,
}) async {
  final frames = <ui.Image>[];
  var t = 0.0;
  var tick = 0;
  for (final want in times) {
    while (t < want) {
      g.update(1 / 60);
      t += 1 / 60;
      // Let the grain reads (off the game loop) land.
      if (++tick % 6 == 0) await Future<void>.delayed(const Duration(milliseconds: 4));
    }
    final rec = ui.PictureRecorder();
    final cv = Canvas(rec);
    var w = g.size.x, h = g.size.y;
    if (focus != null) {
      // A close-up: the square of [radius] world units round [focus].
      final a = g.worldToScreen(focus - Offset(radius, radius));
      final b = g.worldToScreen(focus + Offset(radius, radius));
      w = (b.dx - a.dx);
      h = (b.dy - a.dy);
      cv.translate(-a.dx, -a.dy);
    }
    g.render(cv);
    frames.add(await rec.endRecording().toImage(w.round(), h.round()));
  }
  final fw = frames.first.width * scale, fh = frames.first.height * scale;
  const cols = 5;
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
    File('build/room_audit/BloodMoments_$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }
  // How different the first and last frames are: the moment moved.
  final a = (await frames.first.toByteData())!.buffer.asUint8List();
  final b = (await frames.last.toByteData())!.buffer.asUint8List();
  var diff = 0;
  for (var i = 0; i < a.length; i += 4 * 53) {
    if ((a[i] - b[i]).abs() > 8) diff++;
  }
  return diff;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the release: Earth\'s captive freed', (tester) async {
    await tester.runAsync(() async {
      final g = await _game('rite_earth');
      final f = g.rites.earthFloor;
      g.rites.earth = TendrilState(const [2, 1], tendrilRoute(f, const [2, 1])!);
      g.rites.plateAng = [3.14159, 1.5708];
      _place(g, kRiteArrival['Earth']!);
      g.update(1 / 60);
      g.debugFreeCaptive('Earth');
      final d = await _film(g, 'release_earth', [0, .35, .7, 1.05, 1.4, 1.7, 2.0, 2.4, 2.8, 3.2, 3.6, 4.0, 4.4, 4.8, 5.4], scale: .7, focus: const Offset(330, 300), radius: 280);
      expect(d, greaterThan(0));
    });
  });

  testWidgets('the release: Air\'s captive in its bell', (tester) async {
    await tester.runAsync(() async {
      final g = await _game('rite_air');
      _place(g, kRiteArrival['Air']!);
      g.update(1 / 60);
      g.debugFreeCaptive('Air');
      final d = await _film(g, 'release_air', [0, .5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.8], scale: .7, focus: const Offset(380, 420), radius: 200);
      expect(d, greaterThan(0));
    });
  });

  testWidgets('the Water room turns over', (tester) async {
    await tester.runAsync(() async {
      final g = await _game('rite_water');
      _place(g, kRiteArrival['Water']!);
      g.update(1 / 60);
      g.activateAbility(); // FLIP
      final d = await _film(g, 'water_flip', [0, .3, .55, .75, .9, 1.05, 1.2, 1.35, 1.5, 1.7, 1.95, 2.25, 2.6, 3.0, 3.6], scale: .55, focus: const Offset(288, 256), radius: 300);
      expect(d, greaterThan(0));
    });
  });

  testWidgets('the Water room turns over, close: a melt and a fire put out',
      (tester) async {
    await tester.runAsync(() async {
      final g = await _game('rite_water');
      _place(g, kRiteArrival['Water']!);
      g.update(1 / 60);
      g.activateAbility(); // FLIP
      final d = await _film(g, 'water_flip_close', [0, .6, .8, 1.3, 1.6, 1.8, 1.95, 2.1, 2.3, 2.5, 2.7, 2.9, 3.1, 3.4, 3.8], scale: .8, focus: const Offset(390, 140), radius: 130);
      expect(d, greaterThan(0));
    });
  });

  testWidgets('the Circle: four cups fill and the seal opens', (tester) async {
    await tester.runAsync(() async {
      final g = await _game('rite_circle', stars: 3, view: const Size(960, 960));
      _place(g, (x: 7, y: 11));
      final d = await _film(g, 'circle_pour', [0, .3, .6, .9, 1.2, 1.6, 2.0, 2.5, 3.0, 3.6], scale: .34);
      expect(d, greaterThan(0));
    });
  });

  testWidgets('the sacrifice', (tester) async {
    await tester.runAsync(() async {
      final g = await _game('rite_circle', stars: 3, view: const Size(960, 700));
      await g.debugLoadGuardianArt();
      _place(g, (x: 7, y: 11));
      g.update(1 / 60);
      g.guardianAwake = true;
      // Blood freed in the Heart before: down through it to Sanguorath.
      g.discoveredClouds.add(kRiteHeartFreedId);
      g.passThroughDoor(g.currentRoom.doors.firstWhere((d) => d.targetRoomId == 'rite_heart'));
      g.update(1 / 60);
      g.passThroughDoor(g.currentRoom.doors.firstWhere((d) => d.targetRoomId == 'sanguorath_heart'));
      for (var i = 0; i < 400 && g.debugGuardianBody == null; i++) {
        g.update(1 / 60);
      }
      final b = g.debugGuardianBody!;
      b.hp = b.maxHp * kRiteShellAt[0];
      for (var i = 0; i < 50; i++) {
        g.update(1 / 60);
      }
      final want = kRiteOpposite[g.rites.shellElement]!;
      final ally = g.creatures.firstWhere((c) => c.member.element == want);
      ally.position = b.position + const Offset(60, 20);
      g.update(1 / 60);
      final d = await _film(g, 'sacrifice', [0, .25, .5, .75, 1.0, 1.3, 1.6, 1.9, 2.2, 2.5, 2.8, 3.1, 3.4, 3.7, 4.0], scale: .7, focus: b.position + const Offset(30, 0), radius: 170);
      expect(d, greaterThan(0));
    });
  });
}
