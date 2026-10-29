@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/screens/cosmic/widgets/elements_captured_popup.dart';
import 'package:alchemons/screens/cosmic/widgets/planet_action_button.dart';
import 'package:alchemons/screens/cosmic/widgets/space_action_glyphs.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'survival_lobby_harness.dart' show loadLobbyFonts;

// Space's portal prompts as the planet's lenses: a rift, the Blood Ring and
// its portal, the Nexus, a pocket portal; then the gate's failed offering.
//
//   PORTAL_PROMPTS_OUT=/tmp/portals flutter test \
//     test/space_portal_prompts_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['PORTAL_PROMPTS_OUT'];

  Future<void> fonts(WidgetTester tester) async {
    HttpOverrides.global = null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.createTempSync('fonts').path,
    );
    await tester.runAsync(() async {
      await loadLobbyFonts();
      GoogleFonts.imFellEnglishTextTheme();
      await GoogleFonts.pendingFonts();
    });
  }

  Future<void> shoot(WidgetTester tester, GlobalKey key, String name) =>
      tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(out!).createSync(recursive: true);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });

  testWidgets('portal lenses', (tester) async {
    if (out == null) return;
    await fonts(tester);
    await tester.binding.setSurfaceSize(const Size(390, 520));
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    Widget lens(String label, String sub, Color light, {List<Color>? cargo}) =>
        PlanetActionButton(
          label: label,
          sublabel: sub,
          light: light,
          glyph: SpaceActionGlyph(
            SpaceAction.portal,
            size: PlanetActionButton.glyphSize,
            color: cargo?.first ?? light,
            cargo: cargo ?? const [],
          ),
          onTap: () {},
        );
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(textTheme: GoogleFonts.imFellEnglishTextTheme()),
        home: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFF020010),
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              runSpacing: 30,
              children: [
                const SizedBox(width: 390, height: 20),
                lens('ENTER', 'Arcane Rift', const Color(0xFF9B6BFF)),
                lens('ENTER', 'Volcanic Rift', const Color(0xFFFF6A2B)),
                lens('MAKE AN OFFERING', 'Blood Ring', const Color(0xFFC0392B)),
                lens(
                  'ENTER',
                  'Elemental Nexus · four guardian relics',
                  const Color(0xFF8B7BE8),
                  cargo: const [
                    Color(0xFFFF7043),
                    Color(0xFF4FA3FF),
                    Color(0xFF9CCC65),
                    Color(0xFFB3E5FC),
                  ],
                ),
                lens('ENTER', 'Water Portal', const Color(0xFF448AFF)),
              ],
            ),
          ),
        ),
      ),
    );
    for (final ms in [0, 700]) {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      await shoot(tester, key, 'lenses_$ms');
    }
  });

  testWidgets('failed offering', (tester) async {
    if (out == null) return;
    await fonts(tester);
    await tester.binding.setSurfaceSize(const Size(390, 700));
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      Provider<FactionTheme>.value(
        value: FactionTheme.scorchForge(),
        child: MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              backgroundColor: const Color(0xFF020010),
              body: ElementsCapturedPopup(
                breakdown: const {'Fire': 1240, 'Water': 380, 'Earth': 95},
                onDismiss: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await shoot(tester, key, 'failed_offering');
  });
}
