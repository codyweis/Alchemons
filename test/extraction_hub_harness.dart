import 'dart:convert';
import 'dart:io';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/providers/app_providers.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/extraction_hub_screen.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/harvest_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/element_resource_totals_bar.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The harvest screen on a phone-sized view with an in-memory save:
//   Volcanic — a Firehorn extracting, 2 h 20 m into a 4 h run;
//   Oceanic — open and empty;
//   Verdant — a Planthorn's run, finished;
//   Earthen, Arcane — locked.

/// Notifications are a platform plugin; here they go nowhere. Call from
/// setUp, and [unmuteNotifications] before the test body ends.
void muteNotifications() {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  for (final name in [
    'dexterous.com/flutter/local_notifications',
    'flutter_timezone',
  ]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          MethodChannel(name),
          (call) async => switch (call.method) {
            'initialize' => true,
            'getActiveNotifications' ||
            'pendingNotificationRequests' => <Object?>[],
            _ => null,
          },
        );
  }
}

void unmuteNotifications() => debugDefaultTargetPlatformOverride = null;

class HubHarness {
  HubHarness._(this.tester, this.db, this.svc);

  final WidgetTester tester;
  final AlchemonsDatabase db;
  final HarvestService svc;

  /// Wraps the app, for screenshots.
  final GlobalKey shotKey = GlobalKey();

  static Future<HubHarness> pump(
    WidgetTester tester, {
    bool tutorialSeen = true,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = AlchemonsDatabase(NativeDatabase.memory());
    late CreatureCatalog catalog;
    late HarvestService svc;
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
      if (tutorialSeen) await db.settingsDao.setBiomeHarvestTutorialSeen();
      await db.creatureDao.insertInstance(
        instanceId: 'fire',
        baseId: 'HOR01',
        level: 12,
      );
      await db.creatureDao.insertInstance(
        instanceId: 'plant',
        baseId: 'HOR12',
        level: 9,
      );
      svc = HarvestService(db);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      for (final id in ['volcanic', 'oceanic', 'verdant']) {
        await db.biomeDao.unlockBiome(biomeId: id, cost: const {});
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final volcanic = svc.biomes.firstWhere((f) => f.biome.id == 'volcanic');
      await svc.setActiveElement(volcanic.biome, 'Fire');
      await svc.startJob(
        biome: volcanic.biome,
        creatureInstanceId: 'fire',
        duration: const Duration(hours: 4),
        ratePerMinute: 12,
      );
      await db.biomeDao.nudgeBiomeJob(
        'volcanic',
        -(const Duration(hours: 2, minutes: 20)).inMilliseconds,
      );
      final verdant = svc.biomes.firstWhere((f) => f.biome.id == 'verdant');
      await svc.setActiveElement(verdant.biome, 'Plant');
      await svc.startJob(
        biome: verdant.biome,
        creatureInstanceId: 'plant',
        duration: const Duration(hours: 4),
        ratePerMinute: 9,
      );
      await db.biomeDao.nudgeBiomeJob(
        'verdant',
        -(const Duration(hours: 5)).inMilliseconds,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // The DAO's nudge goes round the service; this reads the jobs back.
      await svc.setActiveElement(volcanic.biome, 'Fire');
      await svc.setActiveElement(verdant.biome, 'Plant');
      constellations = ConstellationEffectsService(db);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });

    final h = HubHarness._(tester, db, svc);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
          Provider<CreatureCatalog>.value(value: catalog),
          ChangeNotifierProvider<ThemeNotifier>(create: (_) => _PlainFont(db)),
          ChangeNotifierProvider<FactionService>.value(
            value: FactionService(db),
          ),
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
              RepaintBoundary(key: h.shotKey, child: child!),
          home: ExtractionHubScreen(service: svc),
        ),
      ),
    );
    await h.settle(30);
    return h;
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

  /// Shows chamber [i] (0 Volcanic … 4 Arcane) from the totals strip.
  Future<void> select(int i) async {
    final bar = tester.getRect(find.byType(ElementResourceTotalsBar));
    await tester.tapAt(
      Offset(bar.left + 18 + (bar.width - 36) * (i + 0.5) / 5, bar.center.dy),
    );
    await settle(30);
  }

  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox());
    svc.dispose();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
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
