@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/nursery/storage_section_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Every way a vial is shown, on the dark and the light theme's grounds: the
// inventory's grid cards at each rarity, a priced shop card, the faction
// picker's orb, and cold storage's stasis cells (in progress and ready).
//
//   VIALS_OUT=/tmp/vials flutter test \
//     test/vial_look_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['VIALS_OUT'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)..addFont(
          Future.value(ByteData.view(file.readAsBytesSync().buffer)),
        ))
        .load();
  }

  setUpAll(() async {
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
  });

  ExtractionVial vial(ElementalGroup g, VialRarity r, {int? price}) =>
      ExtractionVial(
        id: '${g.name}_${r.name}',
        name: '${g.displayName} Vial',
        group: g,
        rarity: r,
        quantity: 1,
        price: price,
      );

  Egg stored(String id, String faction, {required bool ready}) => Egg(
    eggId: id,
    resultCreatureId: 'HOR01',
    rarity: 'Rare',
    remainingMs: ready ? 0 : 3 * 3600 * 1000,
    payloadJson: jsonEncode({
      'lineage': {'nativeFaction': faction},
    }),
  );

  testWidgets('vial looks', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(400 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();

    Widget sheet(bool dark) {
      final ground = dark ? const Color(0xFF080A0E) : const Color(0xFFF2EBDD);
      const groups = ElementalGroup.values;
      return Container(
        color: ground,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The inventory's grid, one of each rarity.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < VialRarity.values.length; i++)
                  SizedBox(
                    width: 118,
                    height: 128,
                    child: ExtractionVialCard(
                      vial: vial(
                        groups[i % groups.length],
                        VialRarity.values[i],
                      ),
                      compact: true,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // A shop card, priced, with its buy button.
                SizedBox(
                  width: 200,
                  height: 140,
                  child: ExtractionVialCard(
                    vial: vial(
                      ElementalGroup.oceanic,
                      VialRarity.rare,
                      price: 650,
                    ),
                    onAddToInventory: () {},
                  ),
                ),
                const SizedBox(width: 12),
                // The faction picker's.
                SizedBox.square(
                  dimension: 140,
                  child: ExtractionVialCard(
                    vial: vial(ElementalGroup.verdant, VialRarity.uncommon),
                    showTags: false,
                    circular: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Cold storage.
            Row(
              children: [
                for (final (id, faction, ready) in const [
                  ('s1', 'volcanic', false),
                  ('s2', 'oceanic', false),
                  ('s3', 'verdant', true),
                ]) ...[
                  SizedBox(
                    width: 84,
                    height: 72.7,
                    child: StasisCell(
                      egg: stored(id, faction, ready: ready),
                      quality: CinematicQuality.cinematic,
                      nowUtc: DateTime.now().toUtc(),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      );
    }

    for (final dark in [true, false]) {
      final theme = dark
          ? FactionTheme.scorchForge()
          : factionThemeFor(null, brightness: Brightness.light);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        Provider<FactionTheme>.value(
          value: theme,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: RepaintBoundary(key: key, child: sheet(dark)),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/${dark ? 'dark' : 'light'}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
  });
}
