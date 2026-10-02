@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/wilderness/encounter_top_hud.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The wild encounter's top band on a phone, with real fonts, over a dark
// field: with and without the Potential readout, wilderness and space.
//
//   HUD_OUT=/tmp/hud flutter test \
//     test/encounter_top_hud_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['HUD_OUT'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
  });

  const readings = <WildPotentialReading>[
    (label: 'SPD', value: 76),
    (label: 'INT', value: 34),
    (label: 'STR', value: 45),
    (label: 'BEA', value: 67),
  ];

  Future<void> snap(
    WidgetTester tester,
    String name, {
    required Size surface,
    List<WildPotentialReading>? potentials = readings,
    bool dossier = false,
    int party = 4,
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            backgroundColor: const Color(0xFF1B2A22),
            body: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      kEncounterHudEdgePad,
                      kEncounterHudEdgePad + 24,
                      kEncounterHudEdgePad,
                      0,
                    ),
                    child: WildEncounterTopHud(
                      name: 'Airlet',
                      rarity: 'rare',
                      potentials: potentials,
                      // SPD 76 is the wild's best: the one a fusion passes.
                      passingPotential: potentials == null ? null : 0,
                      dossier: dossier,
                      leftGutter: dossier ? 0 : kEncounterHudLeftGutter,
                      partyStripWidth: partyStripWidthFor(party),
                      partyStrip: party == 0
                          ? null
                          : Container(
                              height: 62,
                              color: const Color(0x55FFFFFF),
                            ),
                      animateName: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('encounter top band preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    const portrait = Size(412, 420);
    const landscape = Size(915, 300);
    await snap(tester, 'portrait', surface: portrait);
    await snap(tester, 'portrait_locked', surface: portrait, potentials: null);
    await snap(tester, 'landscape', surface: landscape);
    await snap(tester, 'portrait_space', surface: portrait, dossier: true);
  });
}
