@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/widgets/instant_extractor_glyph.dart';
import 'package:alchemons/widgets/inventory_item_artwork.dart';
import 'package:alchemons/widgets/stamina_elixir_glyph.dart';
import 'package:alchemons/widgets/tincture_glyph.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// Tincture beside the item glyphs it sits with in reward rows and the
// inventory, at the sizes it is drawn at (24 raid rows, 32 reward rows, 52
// shelves, 96 a subject), on the game's #09090B: one sheet still and one
// mid-drop. The last column is the inventory key's own artwork, to show the
// key reaches the glyph.
//
//   GLYPH_OUT=/tmp/glyphs flutter test \
//     test/tincture_glyph_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['GLYPH_OUT'];

  const sizes = [24.0, 32.0, 52.0, 96.0];

  List<Widget> items(double size, bool animate) => [
    StaminaElixirGlyph(size: size, animate: animate),
    TinctureGlyph(size: size, animate: animate),
    InstantExtractorGlyph(size: size, animate: animate),
    InventoryItemArtwork(
      inventoryKey: InvKeys.athanorTincture,
      size: size,
      animate: animate,
    ),
  ];

  Widget sheet(GlobalKey key, bool animate) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFF09090B),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final s in sizes)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final w in items(s, animate))
                          SizedBox(
                            width: 112,
                            height: 112,
                            child: Center(child: w),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> shoot(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('tincture glyph sheet', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view
      ..physicalSize = const Size(480 * 2, 480 * 2)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final still = GlobalKey();
    await tester.pumpWidget(sheet(still, false));
    await tester.pump(const Duration(milliseconds: 16));
    await shoot(tester, still, 'tincture_still');

    final live = GlobalKey();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(sheet(live, true));
    await tester.pump(const Duration(milliseconds: 1000));
    await shoot(tester, live, 'tincture_falling');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
