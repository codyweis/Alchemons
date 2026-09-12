@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/components/powerup_selection_overlay.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the alchemical-surge panel as the player sees it.
///
///   POWERUP_OUT=/tmp flutter test test/powerup_overlay_preview_test.dart \
///     --tags preview
void main() {
  final outDir = Platform.environment['POWERUP_OUT'];

  CosmicPartyMember member(String family, String element, String name) =>
      CosmicPartyMember(
        instanceId: name,
        baseId: 'PRV01',
        displayName: name,
        family: family,
        element: element,
        level: 10,
        slotIndex: 0,
        statSpeed: 4,
        statIntelligence: 4,
        statStrength: 4,
        statBeauty: 4,
        statSpeedPotential: 80,
        statIntelligencePotential: 80,
        statStrengthPotential: 80,
        statBeautyPotential: 80,
        staminaBars: 3,
        staminaMax: 3,
      );

  testWidgets('surge panel preview', (tester) async {
    tester.view
      ..physicalSize = const ui.Size(900, 1400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final choices = [
      OfferedPowerUpChoice(
        def: kMysticWorldPowerUps.firstWhere((d) => d.id == 'world_plant'),
        targetSlot: 0,
        targetName: 'Verdant',
        currentLevel: 1,
      ),
      OfferedPowerUpChoice(
        def: kAllPowerUps.firstWhere((d) => d.id == 'strength_up'),
        targetSlot: 1,
        targetName: 'Bulwark',
        currentLevel: 2,
      ),
      OfferedPowerUpChoice(
        def: kAllPowerUps.firstWhere((d) => d.category == PowerUpCategory.shipWeapon),
        currentLevel: 0,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF101018),
          body: RepaintBoundary(
            child: PowerUpSelectionOverlay(
              choices: choices,
              currentWave: 12,
              party: [
                member('Mystic', 'Plant', 'Verdant'),
                member('Horn', 'Fire', 'Bulwark'),
              ],
              powerUps: PowerUpState(),
              onSelect: (def, {targetSlot, targetName}) {},
            ),
          ),
        ),
      ),
    );
    // The panel pulses forever, so pumpAndSettle would never return. Step the
    // entry animation frame by frame instead until it has fully opened.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    final boundary =
        tester.firstRenderObject(find.byType(RepaintBoundary)) as dynamic;
    // Encoding has to happen in real async, not in the fake-async zone
    // testWidgets runs in: toImage resolves either way, but the zone is left
    // with work outstanding and the test then sits until its timeout.
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(png, isNotNull);
      if (outDir != null && outDir.isNotEmpty) {
        File('$outDir/surge_panel.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
        // ignore: avoid_print
        print('POWERUP_PREVIEW $outDir/surge_panel.png');
      }
      image.dispose();
    });
    // Tear the panel down before the test ends: its pulse ticker never stops,
    // and a live ticker holds the test open for its whole timeout.
    await tester.pumpWidget(const SizedBox.shrink());
  }, timeout: const Timeout(Duration(minutes: 2)));
}
