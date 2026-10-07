@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic_survival/components/cosmic_survival_game_over_panel.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/screens/inventory_screen.dart'
    show InventoryImageHelper;
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/loot_open_popup.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'survival_lobby_harness.dart';

// What a finished survival run pays out, as the player sees it: the results
// with the rewards gathering into them (frames through it), the same reveal
// in the inventory's loot-box popup, and a sheet of every reward survival can
// drop drawn the way both of those draw it.
//
//   REWARDS_OUT=/tmp/rewards flutter test \
//     test/survival_rewards_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['REWARDS_OUT'];
  setUpAll(loadLobbyFonts);

  // Built the way CosmicSurvivalScreen._rollAndShowRewards builds them.
  const accent = Color(0xFFD9B368);
  LootOpeningEntry item(Map<String, InventoryItemDef> registry, String key) {
    final def = registry[key];
    final imagePath = InventoryImageHelper.getImage(key);
    return LootOpeningEntry(
      icon: def?.icon ?? AppIcons.inventory_2_rounded,
      name: def?.name ?? key,
      label: 'x1',
      color: accent,
      imagePath: imagePath,
      visualBuilder: (size) => InventoryImageHelper.getVisualWidget(
        key: key,
        assetName: imagePath,
        icon: def?.icon,
        size: size,
      ),
    );
  }

  LootOpeningEntry orb(AlchemicalPowerupType type) {
    final imagePath = InventoryImageHelper.getImage(type.inventoryKey);
    return LootOpeningEntry(
      icon: type.icon,
      name: type.name,
      label: 'x1',
      color: type.color,
      imagePath: imagePath,
      visualBuilder: (size) => InventoryImageHelper.getVisualWidget(
        key: type.inventoryKey,
        assetName: imagePath,
        icon: type.icon,
        size: size,
      ),
    );
  }

  LootOpeningEntry soul(Map<String, InventoryItemDef> registry) {
    final def = registry[InvKeys.potentialSoul];
    return LootOpeningEntry(
      icon: def?.icon ?? AppIcons.diamond_rounded,
      name: def?.name ?? 'Potential Soul',
      label: 'x1',
      color: const Color(0xFFB66CFF),
      visualBuilder: (size) => InventoryImageHelper.getVisualWidget(
        key: InvKeys.potentialSoul,
        icon: def?.icon,
        size: size,
      ),
    );
  }

  const silver = LootOpeningEntry(
    icon: AppIcons.monetization_on_rounded,
    coin: CoinKind.silver,
    name: 'Silver',
    label: '+1240',
    color: Color(0xFFB0BEC5),
  );
  const gold = LootOpeningEntry(
    icon: AppIcons.stars_rounded,
    coin: CoinKind.gold,
    name: 'Gold',
    label: '+6',
    color: accent,
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

  Widget app(GlobalKey key, Widget home) => Provider<FactionTheme>.value(
    value: FactionTheme.scorchForge(),
    child: MaterialApp(
      // A fresh app per scene, so the popup's route does not outlive it.
      key: ObjectKey(key),
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      // Above the navigator, so the shot holds the dialog over the page.
      builder: (_, child) => RepaintBoundary(key: key, child: child),
      home: home,
    ),
  );

  testWidgets('survival rewards', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view
      ..physicalSize = kLobbyPhysical
      ..devicePixelRatio = kLobbyDpr;
    addTearDown(tester.view.reset);
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final registry = buildInventoryRegistry(db);

    // A good run at wave 23: a box opened into two things, an orb, a soul,
    // and the currency every run pays.
    final run = [
      item(registry, InvKeys.harvesterStdVolcanic),
      item(registry, InvKeys.portalKeyOceanic),
      orb(AlchemicalPowerupType.strength),
      soul(registry),
      silver,
      gold,
    ];

    debugDisableShadows = false;
    try {
      final shot = GlobalKey();
      await tester.pumpWidget(
        app(
          shot,
          Builder(
            builder: (context) => Scaffold(
              backgroundColor: const Color(0xFF05050A),
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      showLootOpeningDialog(context: context, entries: run),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      // Through the reveal: the frames a player sees after the orb dies.
      var t = 0;
      for (final at in const [150, 500, 900, 1300, 1900, 2600, 4200]) {
        while (t < at) {
          await tester.pump(const Duration(milliseconds: 25));
          t += 25;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
        await shoot(tester, shot, 'popup_${at}ms');
      }
      tester.takeException();

      // The results panel the reveal closes onto.
      final panel = GlobalKey();
      await tester.pumpWidget(
        app(
          panel,
          // In the game it sits over the stilled, dimmed arena.
          ColoredBox(
            color: const Color(0xFF06060A),
            child: CosmicSurvivalGameOverPanel(
              wave: 23,
              kills: 1840,
              score: 48210,
              time: '14:32',
              rewards: run,
              onQuit: () {},
              onNewTeam: () {},
              onReplay: () {},
            ),
          ),
        ),
      );
      var ms = 0;
      // REWARDS_FRAMES=1: every 50 ms through it, for a moving preview.
      final every = Platform.environment['REWARDS_FRAMES'] == '1';
      final times = every
          ? [for (var t = 0; t <= 4800; t += 50) t]
          : const [300, 900, 1500, 2200, 3200, 4800];
      for (final at in times) {
        while (ms < at) {
          await tester.pump(const Duration(milliseconds: 25));
          ms += 25;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
        await shoot(
          tester,
          panel,
          every ? 'frame_${at.toString().padLeft(5, '0')}' : 'results_${at}ms',
        );
      }

      // Every reward survival can pay, at the two sizes it is drawn.
      final keys = {
        for (final d in LootBoxConfig.bossLootBoxPool) d.itemKey,
      }.toList();
      final all = [
        for (final k in keys) item(registry, k),
        for (final t in AlchemicalPowerupType.values) orb(t),
        soul(registry),
        silver,
        gold,
      ];
      final sheet = GlobalKey();
      await tester.pumpWidget(
        app(
          sheet,
          Scaffold(
            backgroundColor: const Color(0xFF09090B),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  for (final e in all)
                    SizedBox(
                      width: 92,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: Center(
                              child: e.visualBuilder != null
                                  ? e.visualBuilder!(52)
                                  : e.coin != null
                                  ? CoinIcon(kind: e.coin!, size: 34)
                                  : Icon(e.icon, color: e.color),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (e.name ?? '').toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Color(0xFFE6E2DA),
                              fontSize: 8.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump();
      await shoot(tester, sheet, 'reward_sheet');
      tester.takeException();
    } finally {
      debugDisableShadows = true;
    }
  });
}
