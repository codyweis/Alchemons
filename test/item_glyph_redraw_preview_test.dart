@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/widgets/alchemical_powerup_orb_sphere.dart';
import 'package:alchemons/widgets/cold_storage_glyph.dart';
import 'package:alchemons/widgets/instant_extractor_glyph.dart';
import 'package:alchemons/widgets/inventory_item_artwork.dart';
import 'package:alchemons/widgets/portal_key_glyph.dart';
import 'package:alchemons/widgets/potential_soul_sphere.dart';
import 'package:alchemons/widgets/raid_beacon_glyph.dart';
import 'package:alchemons/widgets/stamina_elixir_glyph.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The Stamina Elixir, the Raid Beacon and Alchemical Resonance beside the
// item art they sit with — stat orbs, a Potential Soul, a rift key and two
// of the shop's glass-sphere glyphs — at
// the sizes they are drawn at (32 reward rows, 52 shelves, 96 a subject),
// on the game's #09090B. One sheet still, as grids bake them, and two
// mid-animation, as a subject view runs them.
//
//   GLYPH_OUT=/tmp/glyphs flutter test \
//     test/item_glyph_redraw_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['GLYPH_OUT'];

  setUpAll(() async {
    final arial = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (!arial.existsSync()) return;
    await (FontLoader(
          'Roboto',
        )..addFont(Future.value(ByteData.view(arial.readAsBytesSync().buffer))))
        .load();
  });

  const sizes = [32.0, 52.0, 96.0];
  const names = [
    'Elixir',
    'Beacon',
    'Resonance',
    'Strength',
    'Intellect',
    'Soul',
    'Key',
    'Extractor',
    'Stasis',
  ];

  List<Widget> items(double size, bool animate) => [
    StaminaElixirGlyph(size: size, animate: animate),
    RaidBeaconGlyph(size: size, animate: animate),
    InventoryItemArtwork(
      inventoryKey: InvKeys.alchemyGlow,
      size: size,
      animate: animate,
    ),
    AlchemicalPowerupOrbSphere(
      type: AlchemicalPowerupType.strength,
      size: size,
      animate: animate,
    ),
    AlchemicalPowerupOrbSphere(
      type: AlchemicalPowerupType.intelligence,
      size: size,
      animate: animate,
    ),
    PotentialSoulSphere(size: size, animate: animate),
    PortalKeyGlyph(biomeId: 'volcanic', size: size, animate: animate),
    InstantExtractorGlyph(size: size, animate: animate),
    ColdStorageGlyph(size: size, animate: animate),
  ];

  Widget sheet(GlobalKey key, bool animate) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final n in names)
                        SizedBox(
                          width: 104,
                          child: Text(
                            n,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF8A8478),
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (final s in sizes)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final w in items(s, animate))
                          SizedBox(
                            width: 104,
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
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('item glyph redraw sheet', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view
      ..physicalSize = const Size(990 * 3, 420 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Still: what shelves and reward rows bake. Resonance's snapshot takes
    // its raster a frame after it first paints, so let it.
    final still = GlobalKey();
    await tester.pumpWidget(sheet(still, false));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await shoot(tester, still, 'still');

    // Running: the shared clock starts on the first frame, so a pump of t
    // lands the frame at t seconds in.
    for (final t in [0.9, 2.2]) {
      final live = GlobalKey();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(sheet(live, true));
      await tester.pump(Duration(milliseconds: (t * 1000).round()));
      await shoot(tester, live, 'anim_${t.toStringAsFixed(1)}');
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
