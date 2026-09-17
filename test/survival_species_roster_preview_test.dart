@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic_survival/cosmic_survival_screen.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the survival lobby's species roster cards with real fonts.
///
///   ROSTER_OUT=/tmp flutter test \
///     test/survival_species_roster_preview_test.dart --tags preview
void main() {
  final outDir = Platform.environment['ROSTER_OUT'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
    final home = '${Platform.environment['HOME']}/.pub-cache';
    for (final (family, file) in const [
      ('PhosphorBold', 'Phosphor-Bold.ttf'),
      ('PhosphorFill', 'Phosphor-Fill.ttf'),
    ]) {
      await loadFont(
        'packages/phosphoricons_flutter/$family',
        '$home/hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts/$file',
      );
    }
  });

  Set<String> ownedThrough(CreatureFamily family, String pathId, int tiers) =>
      FamilyMasteryCatalog.pathFor(
        family,
        pathId,
      )!.nodes.take(tiers).map((n) => n.id).toSet();

  testWidgets('species roster preview', (tester) async {
    if (outDir == null) return;
    tester.view.physicalSize = const Size(412 * 2, 1700 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: boundary,
          child: Scaffold(
            backgroundColor: const Color(0xFF050507),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SurvivalSpeciesCardPreview(
                  familyId: 'Let',
                  owned: ownedThrough(CreatureFamily.let, 'let.bombardment', 3),
                  selectedPathId: 'let.bombardment',
                ),
                const SizedBox(height: 16),
                SurvivalSpeciesCardPreview(
                  familyId: 'Mane',
                  owned: ownedThrough(CreatureFamily.mane, 'mane.limitless', 4),
                  selectedPathId: 'mane.limitless',
                  expanded: true,
                ),
                const SizedBox(height: 16),
                const SurvivalSpeciesCardPreview(
                  familyId: 'Pip',
                  owned: {},
                  selectedPathId: null,
                  expanded: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final image = element.widget as Image;
        await precacheImage(image.image, element, onError: (_, _) {});
      }
    });
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '$outDir/species_roster.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
