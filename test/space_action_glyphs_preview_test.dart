@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/screens/cosmic/widgets/space_action_glyphs.dart';
import 'package:alchemons/widgets/cosmic_ship_emblem.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// Space's action marks — the home rail and a planet's actions — beside the
// stock icons they replaced, on the HUD's dark plates, at the phone's
// density, at a few moments of their motion.
//
//   SPACEGLYPHS_OUT=/tmp/glyphs flutter test \
//     test/space_action_glyphs_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['SPACEGLYPHS_OUT'];

  testWidgets('space action glyphs', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    await tester.runAsync(() => ShipGrains.of(null));
    const home = Color(0xFF4FA3E8);
    const fire = Color(0xFFFF6B35);
    const cargo = [Color(0xFFFF6B35), Color(0xFF4ECDC4), Color(0xFFB388FF)];
    Widget plate(
      Widget child, {
      bool lit = false,
      Color accent = home,
      double size = 44,
    }) => Container(
      width: size,
      height: size,
      margin: const EdgeInsets.all(6),
      alignment: Alignment.center,
      color: lit
          ? accent.withValues(alpha: 0.16)
          : const Color(0xFF0B0A0E).withValues(alpha: 0.76),
      child: child,
    );
    final key = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(420, 330));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: Container(
            color: const Color(0xFF020010),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    plate(
                      Icon(
                        AppIcons.file_upload_rounded,
                        color: const Color(0xFFE4C16A),
                        size: 20,
                      ),
                      lit: true,
                    ),
                    plate(
                      const Icon(
                        Icons.south_rounded,
                        color: Color(0xFFE4C16A),
                        size: 20,
                      ),
                    ),
                    plate(
                      Container(
                        width: 19,
                        height: 19,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: home,
                        ),
                      ),
                    ),
                    plate(
                      Icon(
                        AppIcons.rocket_launch_rounded,
                        color: Colors.white54,
                        size: 20,
                      ),
                    ),
                    plate(
                      const Icon(Icons.whatshot_rounded, color: fire, size: 18),
                    ),
                    plate(
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: fire,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    plate(
                      const SpaceActionGlyph(
                        SpaceAction.deposit,
                        color: home,
                        cargo: cargo,
                      ),
                      lit: true,
                    ),
                    plate(
                      const SpaceActionGlyph(SpaceAction.descend, color: home),
                    ),
                    plate(
                      const SpaceActionGlyph(SpaceAction.home, color: home),
                    ),
                    plate(const SpaceActionGlyph(SpaceAction.ship)),
                    plate(
                      const SpaceActionGlyph(SpaceAction.raid, color: fire),
                    ),
                    plate(const SpaceActionGlyph(SpaceAction.summon)),
                  ],
                ),
                Row(
                  children: [
                    for (final lit in [false, true]) ...[
                      plate(
                        SpaceActionGlyph(
                          SpaceAction.boost,
                          size: 44,
                          color: const Color(0xFFFF6F00),
                          lit: lit,
                        ),
                        lit: lit,
                        accent: const Color(0xFFFF6F00),
                        size: 50,
                      ),
                      plate(
                        SpaceActionGlyph(
                          SpaceAction.missile,
                          size: 44,
                          color: const Color(0xFFE53935),
                          lit: lit,
                        ),
                        lit: lit,
                        accent: const Color(0xFFE53935),
                        size: 50,
                      ),
                      plate(
                        SpaceActionGlyph(
                          SpaceAction.gun,
                          size: 44,
                          color: const Color(0xFF00E5FF),
                          lit: lit,
                        ),
                        lit: lit,
                        accent: const Color(0xFF00E5FF),
                        size: 50,
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    plate(
                      const SpaceActionGlyph(
                        SpaceAction.deposit,
                        color: home,
                        lit: false,
                      ),
                    ),
                    plate(
                      const SpaceActionGlyph(SpaceAction.descend, color: fire),
                    ),
                    plate(
                      const SpaceActionGlyph(
                        SpaceAction.descend,
                        color: Color(0xFF6BCF7F),
                      ),
                    ),
                    plate(
                      const SpaceActionGlyph(
                        SpaceAction.ship,
                        skin: 'skin_solar',
                      ),
                    ),
                    plate(
                      const SpaceActionGlyph(
                        SpaceAction.tether,
                        color: Color(0xFF42A5F5),
                        lit: false,
                      ),
                    ),
                    plate(
                      const SpaceActionGlyph(
                        SpaceAction.tether,
                        color: Color(0xFF42A5F5),
                      ),
                      lit: true,
                      accent: const Color(0xFF42A5F5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    for (var f = 0; f < 3; f++) {
      await tester.pump(const Duration(milliseconds: 420));
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final img = await b.toImage(pixelRatio: 3);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/glyphs_$f.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });
}
