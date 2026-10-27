@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_screen_styles.dart';
import 'package:alchemons/screens/cosmic/widgets/planet_action_button.dart';
import 'package:alchemons/screens/cosmic/widgets/space_action_glyphs.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'survival_lobby_harness.dart' show loadLobbyFonts;

// The descent placard's actions as they sit in space, over the planet and
// under its name and stars, in the app's own serif: DESCEND with SUMMON
// beside it on four planets (Nythralor's dark among them, where a planet's
// own colour is nearly black), a raid's ENTER RAID with its level, and the
// gate's UNSEAL GATE.
//
//   PLANET_ACTION_OUT=/tmp/actions flutter test \
//     test/planet_action_button_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['PLANET_ACTION_OUT'];

  testWidgets('planet action buttons', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    HttpOverrides.global = null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.createTempSync('fonts').path,
    );
    await tester.runAsync(() async {
      await loadLobbyFonts();
      // The stars are Material icons.
      final icons = File(
        '${Platform.environment['HOME']}/Documents/flutter'
        '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (icons.existsSync()) {
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(ByteData.view(icons.readAsBytesSync().buffer)),
            ))
            .load();
      }
      GoogleFonts.imFellEnglishTextTheme();
      await GoogleFonts.pendingFonts();
    });

    const cell = Size(457, 412);
    await tester.binding.setSurfaceSize(Size(cell.width * 3, cell.height * 2));
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    CosmicPlanet planetOf(String el) => CosmicPlanet(
      element: el,
      position: Offset.zero,
      radius: kPlanetRadius[el]!,
      discovered: true,
    );

    Widget scene(CosmicPlanet planet, List<Widget> actions) => SizedBox(
      width: cell.width,
      height: cell.height,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _Space(planet))),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 18),
                decoration: placardVignette,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (kPlanetDisplayName[planet.element] ?? '').toUpperCase(),
                      style: TextStyle(
                        color: planet.color,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.0,
                        shadows: [
                          const Shadow(color: Colors.black, blurRadius: 8),
                          Shadow(
                            color: planet.color.withValues(alpha: 0.6),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Icon(
                            i < 2
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 16,
                            color: i < 2
                                ? const Color(0xFFE4C16A)
                                : Colors.white.withValues(alpha: 0.35),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...actions,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    List<Widget> descend(CosmicPlanet planet, {bool summon = true}) => [
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          PlanetActionButton(
            label: 'DESCEND',
            light: elementInk(planet.element),
            glyph: SpaceActionGlyph(
              SpaceAction.descend,
              size: PlanetActionButton.glyphSize,
              color: planet.color,
            ),
            onTap: () {},
          ),
          if (summon) ...[
            const SizedBox(width: 26),
            PlanetActionButton(
              label: 'SUMMON  ·  2',
              light: const Color(0xFFE25544),
              glyph: const SpaceActionGlyph(
                SpaceAction.summon,
                size: PlanetActionButton.compactGlyphSize,
              ),
              compact: true,
              onTap: () {},
            ),
          ],
        ],
      ),
    ];

    final fire = planetOf('Fire');
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          textTheme: GoogleFonts.imFellEnglishTextTheme(
            ThemeData.dark().textTheme,
          ),
        ),
        home: Material(
          color: Colors.black,
          child: RepaintBoundary(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    scene(fire, descend(fire)),
                    scene(planetOf('Dark'), descend(planetOf('Dark'))),
                    scene(
                      planetOf('Water'),
                      descend(planetOf('Water'), summon: false),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    scene(planetOf('Plant'), descend(planetOf('Plant'))),
                    scene(fire, [
                      PlanetActionButton(
                        label: 'ENTER RAID',
                        sublabel: 'LEVEL 2  ·  ECHO',
                        light: const Color(0xFFE25544),
                        glyph: SpaceActionGlyph(
                          SpaceAction.raid,
                          size: PlanetActionButton.glyphSize,
                          color: fire.color,
                        ),
                        onTap: () {},
                      ),
                    ]),
                    scene(planetOf('Crystal'), [
                      PlanetActionButton(
                        label: 'UNSEAL GATE',
                        light: elementInk('Crystal'),
                        icon: AppIcons.lock_open_rounded,
                        onTap: () {},
                      ),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // A moment into the glyphs' motion.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '$out/planet_actions.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}

/// Space, with the planet the placard floats over.
class _Space extends CustomPainter {
  _Space(this.planet);
  final CosmicPlanet planet;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF020010),
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height * 0.40);
    canvas.scale(0.66 * 157 / planet.radius);
    PlanetComponent(planet: planet).render(canvas, 4, drawLabel: false);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
