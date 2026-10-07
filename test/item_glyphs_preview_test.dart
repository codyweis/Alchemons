@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/chronal_catalyst_glyph.dart';
import 'package:alchemons/widgets/cold_storage_glyph.dart';
import 'package:alchemons/widgets/faction_essence_glyph.dart';
import 'package:alchemons/widgets/fusion_chamber_glyph.dart';
import 'package:alchemons/widgets/harvester_glyph.dart';
import 'package:alchemons/widgets/instant_extractor_glyph.dart';
import 'package:alchemons/widgets/wild_fusion_glyph.dart';
import 'package:alchemons/widgets/wildlife_lure_glyph.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// The shop's item glyphs: each running, shot at intervals through its loop,
// then still at the shelf's sizes (and the catalyst at the chip's).
//
//   GLYPHS_OUT=/tmp/glyphs flutter test \
//     test/item_glyphs_preview_test.dart --tags preview
//
// Writes run_<n>.png (all of them, running, at one moment) and still.png.
// GLYPHS_FRAMES / GLYPHS_STEP_MS change how many run shots, how far apart.
void main() {
  final out = Platform.environment['GLYPHS_OUT'];
  final frames = int.tryParse(Platform.environment['GLYPHS_FRAMES'] ?? '') ?? 8;
  final step =
      int.tryParse(Platform.environment['GLYPHS_STEP_MS'] ?? '') ?? 600;

  Widget sheet(
    List<Widget Function(double size, bool animate)> glyphs, {
    required bool animate,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF09090B),
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: animate
                ? Wrap(
                    children: [
                      for (final g in glyphs)
                        Padding(
                          padding: const EdgeInsets.all(30),
                          child: g(140, true),
                        ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final g in glyphs)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            g(118, false),
                            const SizedBox(width: 8),
                            g(64, false),
                            const SizedBox(width: 8),
                            g(58, false),
                            const SizedBox(width: 8),
                            g(22, false),
                            const SizedBox(width: 8),
                            g(13, false),
                          ],
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  final glyphs = <Widget Function(double, bool)>[
    (s, a) => ColdStorageGlyph(size: s, animate: a),
    (s, a) => FusionChamberGlyph(size: s, animate: a),
    (s, a) => InstantExtractorGlyph(size: s, animate: a),
    (s, a) => ChronalCatalystGlyph(size: s, animate: a),
    (s, a) => FactionEssenceGlyph(size: s, animate: a),
    (s, a) => WildFusionGlyph(size: s, animate: a),
    (s, a) => WildlifeLureGlyph(size: s, animate: a),
    for (final b in ['volcanic', 'oceanic', 'earthen', 'verdant', 'arcane'])
      (s, a) => HarvesterGlyph(biomeId: b, size: s, animate: a),
    (s, a) => HarvesterGlyph(biomeId: universalHarvester, size: s, animate: a),
  ];

  testWidgets('item glyphs preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(800 * 2, 1700 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Widget framed(Widget child) => RepaintBoundary(key: key, child: child);

    await tester.pumpWidget(framed(sheet(glyphs, animate: false)));
    await tester.pump();
    await shoot('still');

    await tester.pumpWidget(framed(sheet(glyphs, animate: true)));
    await tester.pump();
    for (var i = 0; i < frames; i++) {
      await shoot('run_$i');
      await tester.pump(Duration(milliseconds: step));
    }
    await tester.pumpWidget(const SizedBox());
  });
}
