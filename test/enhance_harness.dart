import 'dart:convert';
import 'dart:io';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/providers/app_providers.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/feeding/feeding_screen.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The Enhance screen on a phone-sized view with an in-memory save:
//   six Firehorns — fh0 at level 4 (30 XP), the rest spare kin at 1–3 —
//   two Planthorns and a Waterlet; Power Orbs (3/4/5/6), one Potential Soul
//   and 25,000 Silver, unless [items] is false.

class EnhanceHarness {
  EnhanceHarness._(this.tester, this.db, this._app);

  final WidgetTester tester;
  final AlchemonsDatabase db;
  final Widget Function(String? open) _app;

  /// Wraps the app, for screenshots.
  static final GlobalKey shotKey = GlobalKey();

  static Future<EnhanceHarness> pump(
    WidgetTester tester, {
    String? open,
    bool items = true,
    AudioController? audio,
    WidgetBuilder? home,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = AlchemonsDatabase(NativeDatabase.memory());
    late CreatureCatalog catalog;
    late ConstellationEffectsService constellations;
    await tester.runAsync(() async {
      final json =
          jsonDecode(
                File('assets/data/alchemons_creatures.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      catalog = CreatureCatalog.fromList([
        for (final c in json['creatures'] as List)
          Creature.fromJson(c as Map<String, dynamic>),
      ]);
      await db.settingsDao.setFeedingTutorialSeen();
      await db.settingsDao.setPowerupDragHintSeen();
      await OnboardingTaskService(db).markVisited('enhance');
      // Stats as the game derives them, so what the screen previews is what
      // feeding writes back.
      final base = catalog.getCreatureById('HOR01')!.baseStats!;
      double stat(int b, int level, double p, int rank) =>
          AlchemonStatSystem.effectiveInternal(
            speciesBase: b,
            level: level,
            potential: p,
            enhancementRank: rank,
          );
      for (var i = 0; i < 6; i++) {
        final level = i == 0 ? 4 : 1 + i % 3;
        final sp = 40.0 + i * 9, ip = 72.0 - i * 5;
        final tp = 88.0 - i * 3, bp = 55.0 + i * 4;
        final sr = i == 0 ? 1 : 0, tr = i == 0 ? 3 : 0;
        await db.creatureDao.insertInstance(
          instanceId: 'fh$i',
          baseId: 'HOR01',
          level: level,
          xp: i == 0 ? 30 : 0,
          statSpeed: stat(base.speed, level, sp, sr),
          statIntelligence: stat(base.intelligence, level, ip, 0),
          statStrength: stat(base.strength, level, tp, tr),
          statBeauty: stat(base.beauty, level, bp, 0),
          statSpeedPotential: sp,
          statIntelligencePotential: ip,
          statStrengthPotential: tp,
          statBeautyPotential: bp,
          statSpeedEnhancement: sr,
          statStrengthEnhancement: tr,
        );
      }
      for (final (id, species) in [
        ('pl0', 'HOR12'),
        ('pl1', 'HOR12'),
        ('wl0', 'LET02'),
      ]) {
        await db.creatureDao.insertInstance(
          instanceId: id,
          baseId: species,
          level: 2,
        );
      }
      if (items) {
        for (final type in AlchemicalPowerupType.values) {
          await db.inventoryDao.addItemQty(type.inventoryKey, 3 + type.index);
        }
        await db.inventoryDao.addItemQty(InvKeys.potentialSoul, 1);
        await db.currencyDao.addSilver(25000);
      }
      constellations = ConstellationEffectsService(db);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });

    Widget app(String? open) => MultiProvider(
      providers: [
        Provider<AlchemonsDatabase>.value(value: db),
        Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
        Provider<CreatureCatalog>.value(value: catalog),
        Provider<StaminaService>.value(value: StaminaService(db)),
        ListenableProvider<AudioController?>.value(value: audio),
        ChangeNotifierProvider<ThemeNotifier>(create: (_) => _PlainFont(db)),
        ChangeNotifierProvider<FactionService>.value(value: FactionService(db)),
        Provider<CatalogData?>.value(
          value: CatalogData(
            elementRecipes: ElementRecipeConfig(recipes: const {}),
            familyRecipes: const FamilyRecipeConfig(recipes: {}),
            naturesLoaded: true,
            geneticsLoaded: true,
          ),
        ),
        Provider<List<CreatureEntry>?>.value(value: const []),
        ChangeNotifierProvider<ConstellationEffectsService>.value(
          value: constellations,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        builder: (context, child) =>
            RepaintBoundary(key: shotKey, child: child!),
        home: home != null
            ? Builder(builder: home)
            : FeedingScreen(initialInstanceId: open),
      ),
    );

    final h = EnhanceHarness._(tester, db, app);
    await tester.pumpWidget(app(open));
    await h.settle(40);
    return h;
  }

  /// Opens the screen again, on [open] or the picker.
  Future<void> reopen({String? open}) async {
    await tester.pumpWidget(const SizedBox());
    await settle(4);
    await tester.pumpWidget(_app(open));
    await settle(40);
  }

  /// Real time for the database, frames for the screen.
  Future<void> settle([int frames = 10]) async {
    for (var i = 0; i < frames; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 33));
    }
  }

  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox());
    await settle(4);
    await tester.runAsync(db.close);
  }
}

/// The app's font is fetched from Google at run time; a test has no network,
/// so the screen keeps the test's own.
class _PlainFont extends ThemeNotifier {
  _PlainFont(super.db);

  @override
  TextTheme Function(TextTheme) get currentTextThemeFn =>
      (t) => t;
}
