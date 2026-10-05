@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/components/cosmic_survival_game_over_panel.dart';
import 'package:alchemons/games/cosmic_survival/components/powerup_selection_overlay.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/widgets/animations/loot_open_popup.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'survival_lobby_harness.dart';

// Survival's two full-screen panels on the phone, with real fonts: the
// surge draft and the results.
//
//   PANELS_OUT=/tmp/panels flutter test \
//     test/survival_panels_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['PANELS_OUT'];
  setUpAll(loadLobbyFonts);

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
        staminaBars: 3,
        staminaMax: 3,
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

  Future<void> show(WidgetTester tester, GlobalKey key, Widget child) async {
    tester.view
      ..physicalSize = kLobbyPhysical
      ..devicePixelRatio = kLobbyDpr;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            backgroundColor: const Color(0xFF020010),
            body: child,
          ),
        ),
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  testWidgets('surge draft', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final key = GlobalKey();
    debugDisableShadows = false;
    try {
      await show(
        tester,
        key,
        PowerUpSelectionOverlay(
          choices: [
            OfferedPowerUpChoice(
              def: kMysticWorldPowerUps.firstWhere(
                (d) => d.id == 'world_plant',
              ),
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
              def: kAllPowerUps.firstWhere(
                (d) => d.category == PowerUpCategory.shipWeapon,
              ),
              currentLevel: 0,
            ),
          ],
          currentWave: 12,
          party: [
            member('Mystic', 'Plant', 'Verdant'),
            member('Horn', 'Fire', 'Bulwark'),
          ],
          powerUps: PowerUpState(),
          onSelect: (def, {targetSlot, targetName}) {},
        ),
      );
      await shoot(tester, key, 'surge_draft');
    } finally {
      debugDisableShadows = true;
    }
  });

  testWidgets('results', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final key = GlobalKey();
    debugDisableShadows = false;
    try {
      await show(
        tester,
        key,
        CosmicSurvivalGameOverPanel(
          wave: 23,
          kills: 1840,
          score: 48210,
          time: '14:32',
          rewards: [
            for (final (i, name, label) in const [
              (0, 'Silver', 'x 1,240'),
              (1, 'Fire Essence', 'x 18'),
              (2, 'Survival Shard', 'x 3'),
            ])
              LootOpeningEntry(
                icon: AppIcons.inventory_2_rounded,
                name: name,
                label: label,
                color: [
                  const Color(0xFFC4A35A),
                  const Color(0xFFE0703A),
                  const Color(0xFF9B7FE0),
                ][i],
              ),
          ],
          onQuit: () {},
          onNewTeam: () {},
          onReplay: () {},
        ),
      );
      await shoot(tester, key, 'results');
    } finally {
      debugDisableShadows = true;
    }
  });
}
