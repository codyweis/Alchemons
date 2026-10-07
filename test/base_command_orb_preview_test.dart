@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart'
    show HomeCustomizationState;
import 'package:alchemons/games/cosmic_survival/cosmic_survival_base_command_screen.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_ship_loadout.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/survival_upgrade_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Base Command on the Fold (475 wide): every orb core as the run draws it,
// the hulls, the guardian upgrades and a purchase confirm. Then the same
// screen at 1.3× text and on a narrow phone with all five tabs.
//
//   BC_OUT=/tmp/bc flutter test test/base_command_orb_preview_test.dart \
//     --tags preview
void main() {
  final out = Platform.environment['BC_OUT'];
  final home =
      Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
    for (final (family, file) in const [
      ('PhosphorBold', 'Phosphor-Bold.ttf'),
      ('PhosphorFill', 'Phosphor-Fill.ttf'),
    ]) {
      await loadFont(
        'packages/phosphoricons_flutter/$family',
        '$home/hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts/$file',
      );
    }
  });

  /// Pumps Base Command on [tab] and writes each of [shots] (file name →
  /// what to do first) as a PNG. [seeded] spends a stocked purse first, so
  /// the cards show bought, maxed, affordable and unaffordable states.
  Future<void> shoot(
    WidgetTester tester, {
    required String tab,
    required Map<String, Future<void> Function()?> shots,
    double width = 475,
    double height = 1400,
    double textScale = 1,
    bool hideAbilities = true,
    bool seeded = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (seeded) ...{
        SurvivalShipLoadout.cosmicCustomizationPrefsKey: HomeCustomizationState(
          unlockedIds: {'skin_solar', 'skin_inferno'},
        ).serialise(),
        SurvivalShipLoadout.selectedSkinPrefsKey: 'skin_solar',
      },
    });
    final db = AlchemonsDatabase(NativeDatabase.memory());
    final mastery = FamilyMasteryService(db);
    final upgrades = SurvivalUpgradeService(db);
    await tester.runAsync(() async {
      await mastery.load();
      if (!seeded) return;
      await db.currencyDao.addSilver(200000);
      await db.currencyDao.addGold(55);
      for (var i = 0; i < 5; i++) {
        await upgrades.upgradeGuardianStat(GuardianUpgrade.attack);
        await upgrades.upgradeBaseAbility(BaseAbility.health);
      }
      for (var i = 0; i < 2; i++) {
        await upgrades.upgradeGuardianStat(GuardianUpgrade.defense);
        await upgrades.upgradeBaseAbility(BaseAbility.turret);
      }
    });
    // The Mastery tab is built first whatever tab is shot, and its tree
    // (family_mastery_panel.dart, not this screen) overflows at large text.
    // Note those and carry on; an overflow in this screen still fails.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.toString();
      final overflow =
          text.contains('overflowed') || text.contains('_reportOverflow');
      if (overflow && text.contains('family_mastery_panel.dart')) {
        debugPrint(
          'note: Mastery tree overflow at ${textScale}x (not this '
          'screen): ${details.exceptionAsString().split('\n').first}',
        );
        return;
      }
      if (overflow &&
          !text.contains('cosmic_survival_base_command_screen.dart')) {
        // The inspector re-reporting the same overflow on a defunct element.
        return;
      }
      previousOnError?.call(details);
    };
    tester.view.physicalSize = Size(width * 3, height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          // The app provides one above every route; the confirm reads it.
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
          ChangeNotifierProvider<FamilyMasteryService>.value(value: mastery),
          ChangeNotifierProvider<SurvivalUpgradeService>.value(value: upgrades),
          ChangeNotifierProvider(
            create: (_) => ShopService(
              db,
              ConstellationEffectsService(db),
              FactionService(db),
              TimedBoostService(db.settingsDao),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: RepaintBoundary(key: key, child: child!),
          ),
          home: CosmicSurvivalBaseCommandScreen(hideAbilities: hideAbilities),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await settle();
    await tester.tap(find.text(tab).first);
    await settle();
    for (final MapEntry(key: name, value: before) in shots.entries) {
      if (before != null) {
        await before();
        await settle();
      }
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
    FlutterError.onError = previousOnError;
    mastery.dispose();
    await tester.runAsync(db.close);
  }

  testWidgets('base command orbs', (tester) async {
    if (out == null) return;
    await shoot(tester, tab: 'ORB', shots: {'base_command_orbs': null});
  });

  testWidgets('base command orbs, some affordable', (tester) async {
    if (out == null) return;
    await shoot(
      tester,
      tab: 'ORB',
      seeded: true,
      shots: {
        'base_command_orbs_seeded': null,
        'base_command_orb_confirm': () => tester.tap(find.text('25G').first),
      },
    );
  });

  testWidgets('base command ship', (tester) async {
    if (out == null) return;
    await shoot(
      tester,
      tab: 'SHIP',
      height: 900,
      seeded: true,
      shots: {'base_command_ship': null},
    );
  });

  testWidgets('base command guardians', (tester) async {
    if (out == null) return;
    await shoot(
      tester,
      tab: 'GUARDIANS',
      height: 900,
      seeded: true,
      shots: {
        'base_command_guardians': null,
        'base_command_guardian_confirm': () => tester.tap(
          find
              .descendant(
                of: find.byType(TabBarView),
                matching: find.text('10,000'),
              )
              .first,
        ),
      },
    );
  });

  testWidgets('base command at 1.3x text', (tester) async {
    if (out == null) return;
    await shoot(
      tester,
      tab: 'GUARDIANS',
      width: 412,
      height: 1100,
      textScale: 1.3,
      seeded: true,
      shots: {'base_command_guardians_1.3x': null},
    );
    await shoot(
      tester,
      tab: 'ORB',
      width: 412,
      height: 1800,
      textScale: 1.3,
      seeded: true,
      shots: {'base_command_orbs_1.3x': null},
    );
  });

  testWidgets('base command on a narrow phone, five tabs', (tester) async {
    if (out == null) return;
    await shoot(
      tester,
      tab: 'ABILITIES',
      width: 360,
      height: 1300,
      hideAbilities: false,
      seeded: true,
      shots: {'base_command_abilities_360': null},
    );
  });
}
