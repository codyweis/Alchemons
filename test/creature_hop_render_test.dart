import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/widgets/creature_actions.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// A sprite asked to hop plays its hop sheet once over its idle, then is back
/// on the idle and has let the hop sheet go. Writes what it drew (idle, the
/// top of the hop, after) to build/hop_preview.png.
void main() {
  for (final id in const ['MAN01', 'LET15']) {
    _hopTest(id);
  }
  // In every costume: they ride its head through the hop.
  _hopTest('HOR01', costumed: true);
}

void _hopTest(String id, {bool costumed = false}) {
  testWidgets('$id${costumed ? ' in costume' : ''}: a hop plays once over '
      'the idle and is let go', (tester) async {
    final entries =
        (jsonDecode(
                  File(
                    'assets/data/alchemons_creatures.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>)['creatures']
            as List;
    final creature = Creature.fromJson(
      entries.cast<Map<String, dynamic>>().singleWhere((e) => e['id'] == id),
    );
    final sd = creature.spriteData!;
    final hop = actionSheetFor(sd.spriteSheetPath, CreatureAction.hop)!;
    await tester.runAsync(() async {
      for (final path in [sd.spriteSheetPath, hop.path]) {
        final codec = await ui.instantiateImageCodec(
          File('assets/images/$path').readAsBytesSync(),
        );
        Flame.images.add(path, (await codec.getNextFrame()).image);
        codec.dispose();
      }
    });

    tester.view.physicalSize = const Size(300, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final actions = CreatureActionController();
    addTearDown(actions.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFF0E0E12),
            child: Center(
              child: SizedBox.square(
                dimension: 280,
                child: CreatureSprite(
                  spritePath: sd.spriteSheetPath,
                  totalFrames: sd.totalFrames,
                  rows: sd.rows,
                  frameSize: Vector2(
                    sd.frameWidth.toDouble(),
                    sd.frameHeight.toDouble(),
                  ),
                  stepTime: sd.frameDurationMs / 1000.0,
                  actions: actions,
                  costumes: costumed
                      ? WornCostumes(id, {
                          for (final c in FamilyCostume.values)
                            c: c.defaultColor,
                        }).encode()
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final shots = <ui.Image>[];
    Future<void> shoot() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async => shots.add(await boundary.toImage()));
    }

    await shoot();

    actions.play(CreatureAction.hop);
    await tester.pump(); // the sheet arrives
    await tester.pump(); // and is drawn
    expect(Flame.images.containsKey(hop.path), isTrue);
    // Flame's widget plays by the wall clock, so wait in real time.
    Future<void> wait(int ms) async {
      await tester.runAsync(
        () => Future<void>.delayed(Duration(milliseconds: ms)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Six frames in: the top of the jump.
    await wait(400);
    await shoot();

    // A second ask while one plays is ignored.
    actions.play(CreatureAction.hop);
    await wait(1100);
    await tester.pump();
    expect(
      Flame.images.containsKey(hop.path),
      isFalse,
      reason: 'the hop sheet is dropped once the hop is over',
    );
    await shoot();

    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (var i = 0; i < shots.length; i++) {
        canvas.drawImage(shots[i], Offset(300.0 * i, 0), Paint());
      }
      final strip = await recorder.endRecording().toImage(
        300 * shots.length,
        300,
      );
      final bytes = await strip.toByteData(format: ui.ImageByteFormat.png);
      File('build/hop_preview_$id${costumed ? '_costumed' : ''}.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
