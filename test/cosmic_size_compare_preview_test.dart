@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// One Alchemon of every family at normal size genetics, drawn at the size
/// cosmic space draws it at the default (mid) zoom, beside the ship — the
/// old scale on the left, the current one on the right.
///
///   WILD_OUT=/tmp flutter test \
///     test/cosmic_size_compare_preview_test.dart --tags preview
void main() {
  final outDir = Platform.environment['WILD_OUT'];

  setUpAll(() async {
    for (final path in const ['/System/Library/Fonts/Supplemental/Arial.ttf']) {
      final file = File(path);
      if (!file.existsSync()) continue;
      await (FontLoader('Roboto')..addFont(
            Future.value(ByteData.view(file.readAsBytesSync().buffer)),
          ))
          .load();
    }
  });

  testWidgets('cosmic family size comparison', (tester) async {
    if (outDir == null) return;
    // Two phone-width panels side by side.
    const panel = Size(412, 760);
    tester.view.physicalSize = const Size(412 * 2 + 12, 760) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final catalog = CreatureCatalog();
    await tester.runAsync(catalog.load);
    const zoom = 0.72; // mid, the preset space opens at
    const box = 74.88; // the sprite box a companion is fitted to
    const families = [
      'Let',
      'Pip',
      'Mane',
      'Mask',
      'Kin',
      'Horn',
      'Wing',
      'Mystic',
    ];
    // What space actually draws at, read from the game itself.
    final now = {
      for (final f in families)
        f.toLowerCase(): CosmicGame.spaceSpeciesScale(f),
    };

    Widget sprite(String family, double scale) {
      final c = catalog.creatures.firstWhere(
        (c) => c.types.contains('Fire') && c.mutationFamily == family,
      );
      final sheet = sheetFromCreature(c);
      final px = box * scale * zoom;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: px,
            height: px,
            child: CreatureSprite(
              spritePath: sheet.path,
              totalFrames: sheet.totalFrames,
              rows: sheet.rows,
              frameSize: sheet.frameSize,
              stepTime: sheet.stepTime,
              scale: 1.0,
            ),
          ),
          Text(
            family.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFE8DCC8),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      );
    }

    Widget column(String title, Map<String, double> scales) => Container(
      width: panel.width,
      height: panel.height,
      color: const Color(0xFF05060B),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFE4C16A),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CustomPaint(painter: _ShipPainter(zoom)),
              ),
              const SizedBox(width: 8),
              const Text(
                'SHIP',
                style: TextStyle(color: Color(0xFFE8DCC8), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              for (final f in families)
                sprite(f, scales[f.toLowerCase()] ?? 1.0),
            ],
          ),
        ],
      ),
    );

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: Material(
            color: const Color(0xFF05060B),
            child: Row(
              children: [
                column('BEFORE (wing 2.0, horn 1.7)', kCompanionSpeciesScale),
                const SizedBox(width: 12),
                column('NOW (wing 3.0, horn 2.55, mystic 3.0)', now),
              ],
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '$outDir/cosmic_family_sizes.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}

class _ShipPainter extends CustomPainter {
  _ShipPainter(this.zoom);

  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(zoom);
    ShipComponent(pos: Offset.zero).render(canvas, 0, glow: false);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShipPainter old) => false;
}
