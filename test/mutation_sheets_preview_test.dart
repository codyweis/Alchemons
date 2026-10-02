@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Real sheets through the real bake: each species plain, Transmuted,
// Alchemized and prismatic Alchemized, every frame, as PNG sheets.
//
//   MUTATION_OUT=/tmp/mutations flutter test \
//     test/mutation_sheets_preview_test.dart --tags preview
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final outDir = Platform.environment['MUTATION_OUT'];

  testWidgets('mutation sheets preview', (tester) async {
    if (outDir == null) return;
    Directory(outDir).createSync(recursive: true);

    final ids = (Platform.environment['MUTATION_IDS'] ??
            'HOR01,WNG02,KIN12,KIN15,KIN16,LET14,PIP01,MAN05')
        .split(',');

    await tester.runAsync(() async {
      // Real async: a large asset string decodes on an isolate.
      final raw = await rootBundle.loadString(
        'assets/data/alchemons_creatures.json',
      );
      final all = [
        for (final j in (jsonDecode(raw) as Map<String, dynamic>)['creatures']
            as List<dynamic>)
          Creature.fromJson(j as Map<String, dynamic>),
      ];
      final images = Images();
      for (final id in ids) {
        final c = all.firstWhere((c) => c.id == id);
        final sheet = sheetFromCreature(c);
        Future<void> save(String name, ui.Image image) async {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$outDir/${id}_$name.png')
              .writeAsBytesSync(png!.buffer.asUint8List());
        }

        for (final (name, mutation, prismatic) in [
          ('transmuted', 'transmuted', false),
          ('alchemized', 'alchemized', false),
          ('alchemized_prismatic', 'alchemized', true),
        ]) {
          final def = mutatedSheet(
            sheet,
            mutation: mutation,
            prismatic: prismatic,
          );
          final sw = Stopwatch()..start();
          final image = await loadCreatureSheet(images, def.path);
          // ignore: avoid_print
          print('$id $name ${image.width}x${image.height} '
              'frame ${def.frameSize.x.toInt()} in ${sw.elapsedMilliseconds}ms');
          await save(name, image);
        }
        await save('plain', await images.load(sheet.path));
      }
    });
  });

  // Through the real widget, as a grid tile and the details screen draw it:
  // plain, Transmuted, Alchemized, prismatic Alchemized, at two sizes.
  testWidgets('mutation sprites through CreatureSprite', (tester) async {
    if (outDir == null) return;
    Directory(outDir).createSync(recursive: true);
    late List<Creature> all;
    await tester.runAsync(() async {
      final raw = await rootBundle.loadString(
        'assets/data/alchemons_creatures.json',
      );
      all = [
        for (final j in (jsonDecode(raw) as Map<String, dynamic>)['creatures']
            as List<dynamic>)
          Creature.fromJson(j as Map<String, dynamic>),
      ];
    });
    final c = all.firstWhere((c) => c.id == 'HOR01');
    final sheet = sheetFromCreature(c);
    final key = GlobalKey();
    tester.view.physicalSize = const Size(1000, 520) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    Widget sprite(String? mutation, bool prismatic, double size) => SizedBox(
      width: size,
      height: size,
      child: CreatureSprite(
        spritePath: sheet.path,
        totalFrames: sheet.totalFrames,
        rows: sheet.rows,
        frameSize: sheet.frameSize,
        stepTime: sheet.stepTime,
        isPrismatic: prismatic,
        mutation: mutation,
      ),
    );
    const looks = [
      (null, false),
      ('transmuted', false),
      ('alchemized', false),
      ('alchemized', true),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFF0E1015),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [for (final (m, p) in looks) sprite(m, p, 220)],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [for (final (m, p) in looks) sprite(m, p, 80)],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // Real time for the loads and bakes, then frames for the widgets.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$outDir/widget_row.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}