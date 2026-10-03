import 'dart:convert';
import 'dart:io';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/breed/breed_tab.dart';
import 'package:alchemons/services/breeding_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The fusion tab on a phone-sized view, under the breed screen's own tabs,
// with an in-memory save:
//   fh  Firehorn  L9      wh  Waterhorn L7      tired  Firehorn L4, no stamina
//   wl  Waterlet  L3      ww  Waterwing L5          my     Simurgh (Mystic) L6
// and four chambers, [busy] of them cultivating.

class FusionHarness {
  FusionHarness._(this.tester, this.db, this.catalog);

  final WidgetTester tester;
  final AlchemonsDatabase db;
  final CreatureCatalog catalog;

  /// Wraps the app, for screenshots.
  static final GlobalKey shotKey = GlobalKey();

  static Future<FusionHarness> pump(
    WidgetTester tester, {
    String? p1,
    String? p2,
    (String, String)? lastPair,
    int busy = 1,
    bool storageFull = false,
    bool crossSpecies = false,
    Brightness brightness = Brightness.dark,
    Size view = const Size(390, 844),
  }) async {
    tester.view.physicalSize = view * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = AlchemonsDatabase(NativeDatabase.memory());
    late CreatureCatalog catalog;
    late ConstellationEffectsService constellations;
    CreatureInstance? a, b;
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
      for (final (id, species, level, genes, bars) in [
        ('fh', 'HOR01', 9, const {'tinting': 'warm'}, 3),
        ('wh', 'HOR02', 7, const {'tinting': 'cool'}, 2),
        ('tired', 'HOR01', 4, const <String, String>{}, 0),
        ('wl', 'LET02', 3, const <String, String>{}, 3),
        ('ww', 'WNG02', 5, const <String, String>{}, 3),
        ('my', 'MYS01', 6, const <String, String>{}, 3),
      ]) {
        await db.creatureDao.insertInstance(
          instanceId: id,
          baseId: species,
          level: level,
          genetics: genes,
          staminaBars: bars,
        );
      }
      // Four chambers: two seeded open, a locked one opened, one bought.
      await db.incubatorDao.purchaseFusionSlot();
      await db.incubatorDao.purchaseFusionSlot();
      for (var i = 0; i < busy; i++) {
        await db.incubatorDao.placeEgg(
          slotId: i,
          eggId: 'egg$i',
          resultCreatureId: 'HOR01',
          rarity: 'rare',
          hatchAtUtc: DateTime.now().toUtc().add(const Duration(hours: 3)),
        );
      }
      if (storageFull) {
        for (var i = 0; i < 5; i++) {
          await db.incubatorDao.enqueueEgg(
            eggId: 'stored$i',
            resultCreatureId: 'LET01',
            rarity: 'common',
            remaining: const Duration(hours: 1),
          );
        }
      }
      if (crossSpecies) {
        await db.constellationDao.unlockSkill('breeder_cross_species', 1);
      }
      constellations = ConstellationEffectsService(db);
      a = p1 == null ? null : await db.creatureDao.getInstance(p1);
      b = p2 == null ? null : await db.creatureDao.getInstance(p2);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });

    final theme = factionThemeFor(FactionId.volcanic, brightness: brightness);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<FactionTheme>.value(value: theme),
          Provider<CreatureCatalog>.value(value: catalog),
          Provider<StaminaService>.value(value: StaminaService(db)),
          ListenableProvider<AudioController?>.value(value: null),
          ChangeNotifierProvider<ThemeNotifier>(create: (_) => _PlainFont(db)),
          ChangeNotifierProvider<FactionService>.value(
            value: FactionService(db),
          ),
          ChangeNotifierProvider<ConstellationEffectsService>.value(
            value: constellations,
          ),
          Provider<BreedingServiceV2>.value(value: _NoRoomCheck()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.dark
              ? ThemeData.dark()
              : ThemeData.light(),
          builder: (context, child) =>
              RepaintBoundary(key: shotKey, child: child!),
          home: _BreedChrome(
            theme: theme,
            child: BreedingTab(
              discoveredCreatures: const [],
              onBreedingComplete: () {},
              debugParent1: a,
              debugParent2: b,
              debugLastPair: lastPair,
            ),
          ),
        ),
      ),
    );
    final h = FusionHarness._(tester, db, catalog);
    await h.settle(30);
    return h;
  }

  /// Real time for the database and the sprite sheets, frames for the screen.
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

/// The breed screen around the tab: its particle background, its tabs, and
/// the dock's height kept clear at the bottom.
class _BreedChrome extends StatelessWidget {
  const _BreedChrome({required this.theme, required this.child});

  final FactionTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.fromTheme(theme);
    return ParticleBackgroundScaffold(
      whiteBackground: theme.brightness == Brightness.light,
      body: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 76),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: BracketTabs(
                    labels: const ['CULTIVATIONS', 'FUSION'],
                    selected: 1,
                    onSelect: (_) {},
                    palette: palette,
                    accent: fusionGold(palette),
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
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

/// Enough of the breeding service for the merge to start: there is always
/// room. The fusion itself is not run here.
class _NoRoomCheck implements BreedingServiceV2 {
  @override
  Future<String?> getEggPlacementFailureMessage({
    bool requireStorageCapacity = true,
  }) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not faked');
}
