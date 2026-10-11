// Shared setup for the survival lobby's preview and budget tests: the real
// CosmicSurvivalScreen on its pre-run phase, on a mid-game save, at the
// phone's size.
//
// Not a test itself (no `_test` suffix); imported by
//   test/survival_lobby_preview_test.dart
//   test/survival_lobby_budget_probe_test.dart
//   test/survival_lobby_team_test.dart
//   test/survival_entrance_preview_test.dart
//   test/survival_run_preview_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_screen.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/services/survival_upgrade_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The phone: 475 x 751 logical at 3x.
const Size kLobbyPhysical = Size(1425, 2253);
const double kLobbyDpr = 3;

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  await (FontLoader(family)
        ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
      .load();
}

/// Real glyphs instead of the test font's boxes: Arial for the body text,
/// Andale Mono for `monospace`, and the Phosphor icon fonts AppIcons uses.
Future<void> loadLobbyFonts() async {
  await _loadFont(
    'monospace',
    '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
  );
  await _loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
  final home = '${Platform.environment['HOME']}/.pub-cache';
  for (final (family, file) in const [
    ('PhosphorBold', 'Phosphor-Bold.ttf'),
    ('PhosphorFill', 'Phosphor-Fill.ttf'),
    ('Phosphor', 'Phosphor.ttf'),
  ]) {
    await _loadFont(
      'packages/phosphoricons_flutter/$family',
      '$home/hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts/$file',
    );
  }
}

class LobbySave {
  LobbySave._(
    this.db,
    this.catalog,
    this.constellations,
    this.mastery,
    this.upgrades,
    this.shop,
  );

  final AlchemonsDatabase db;
  final CreatureCatalog catalog;
  final ConstellationEffectsService constellations;
  final FamilyMasteryService mastery;
  final SurvivalUpgradeService upgrades;
  final ShopService shop;

  /// A save some way in: a few Alchemons, a best run, silver and gold, a
  /// mastery path on the first two families, three guardian axes bought and a
  /// non-default orb equipped. [fresh] skips all of that except the intro
  /// flags, so the lobby opens with nothing chosen. [team] is saved as the
  /// lobby's last team (instance ids, as the lobby saves them); [orb] is
  /// the orb equipped on a save that is not [fresh].
  static Future<LobbySave> create(
    WidgetTester tester, {
    bool fresh = false,
    List<String>? team,
    String orb = 'celestialOrb',
  }) {
    SharedPreferences.setMockInitialValues({});
    late LobbySave save;
    return tester
        .runAsync(() async {
          final db = AlchemonsDatabase(NativeDatabase.memory());
          final json =
              jsonDecode(
                    File(
                      'assets/data/alchemons_creatures.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>;
          final catalog = CreatureCatalog.fromList([
            for (final c in json['creatures'] as List)
              Creature.fromJson(c as Map<String, dynamic>),
          ]);
          // No first-visit story dialog: straight to the lobby.
          await db.settingsDao.setSurvivalMenuStoryIntroSeen();
          await db.settingsDao.setCosmicSurvivalIntroSeen();
          if (team != null) {
            await db.settingsDao.setSetting(kLobbyTeamKey, jsonEncode(team));
          }

          if (!fresh) {
            for (final (id, base, level) in const [
              ('own-1', 'LET02', 14),
              ('own-2', 'PIP06', 11),
              ('own-3', 'HOR13', 9),
              ('own-4', 'MAN03', 12),
              ('own-5', 'MSK01', 7),
            ]) {
              if (catalog.getCreatureById(base) == null) continue;
              await db.creatureDao.insertInstance(
                instanceId: id,
                baseId: base,
                level: level,
              );
            }
            await db.currencyDao.addSilver(60000);
            await db.currencyDao.addGold(37);
            await db.saveSurvivalHighScore(
              wave: 23,
              score: 48210,
              timeMs: 14 * 60 * 1000 + 32 * 1000,
            );
            for (final (key, value) in [
              ('survival.guardian.attack', '3'),
              ('survival.guardian.defense', '2'),
              ('survival.guardian.cooldown', '1'),
              ('survival.owned_skins', 'celestialOrb'),
              ('survival.equipped_skin', orb),
            ]) {
              await db.settingsDao.setSetting(key, value);
            }
          }

          final constellations = ConstellationEffectsService(db);
          final mastery = FamilyMasteryService(db);
          await mastery.load();
          if (!fresh) {
            // Enough of each family's mastery for the tiers bought below.
            await mastery.addPoints(const {
              CreatureFamily.let: 260,
              CreatureFamily.pip: 120,
            });
            for (final (family, path, tiers) in const [
              (CreatureFamily.let, 'let.bombardment', 3),
              (CreatureFamily.pip, 'pip.salvo', 2),
            ]) {
              final nodes = FamilyMasteryCatalog.pathFor(
                family,
                path,
              )!.nodes.take(tiers);
              for (final node in nodes) {
                await mastery.purchaseNode(family: family, nodeId: node.id);
              }
              await mastery.selectPath(family: family, pathId: path);
            }
            // Spend down to a believable balance.
            final silver =
                (await db.currencyDao.getAllCurrencies())['silver'] ?? 0;
            if (silver > 4280) await db.currencyDao.spendSilver(silver - 4280);
          }
          final upgrades = SurvivalUpgradeService(db);
          await upgrades.load();
          final shop = ShopService(
            db,
            constellations,
            FactionService(db),
            TimedBoostService(db.settingsDao),
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
          save = LobbySave._(
            db,
            catalog,
            constellations,
            mastery,
            upgrades,
            shop,
          );
        })
        .then((_) => save);
  }

  /// The screen inside the providers it reads. [shot] wraps the whole app so
  /// a PNG of it can be taken. No AudioController: the screen reads it as
  /// nullable and the lobby never plays anything.
  Widget app({
    GlobalKey? shot,
    ValueNotifier<bool>? revealReady,
    Widget? home,
  }) => MultiProvider(
    providers: [
      Provider<AlchemonsDatabase>.value(value: db),
      Provider<CreatureCatalog>.value(value: catalog),
      ChangeNotifierProvider<ConstellationEffectsService>.value(
        value: constellations,
      ),
      ChangeNotifierProvider<FamilyMasteryService>.value(value: mastery),
      ChangeNotifierProvider<SurvivalUpgradeService>.value(value: upgrades),
      ChangeNotifierProvider<ShopService>.value(value: shop),
      // What the party picker reads, for the tests that open it.
      Provider<FactionTheme>.value(value: factionThemeFor(null)),
      Provider<StaminaService>(create: (_) => StaminaService(db)),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      builder: shot == null
          ? null
          : (context, child) => RepaintBoundary(key: shot, child: child!),
      home: home ?? CosmicSurvivalScreen(revealReady: revealReady),
    ),
  );

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    shop.dispose();
    upgrades.dispose();
    mastery.dispose();
    constellations.dispose();
    await tester.runAsync(db.close);
  }
}

/// The settings key the lobby saves its team under.
const String kLobbyTeamKey = 'survival.team_v1';

/// The mid-game save's five Alchemons, as a saved team.
const List<String> kLobbyTeam = ['own-1', 'own-2', 'own-3', 'own-4', 'own-5'];

/// Reads the lobby's saved team back.
Future<List<String>?> savedLobbyTeam(WidgetTester tester, LobbySave save) =>
    tester.runAsync<List<String>?>(() async {
      final raw = await save.db.settingsDao.getSetting(kLobbyTeamKey);
      if (raw == null) return null;
      return [for (final id in jsonDecode(raw) as List) id as String];
    });

/// Lets the database's futures and the portraits' decodes run on the real
/// clock between fake frames.
Future<void> settleLobby(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 33));
  }
}

/// Decodes every portrait the lobby has built, so a picture shows them.
Future<void> precacheLobbyImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element, onError: (_, _) {});
    }
  });
}

/// The lobby's own vertical scroll.
ScrollableState lobbyScroll(WidgetTester tester) => tester
    .stateList<ScrollableState>(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
        matchRoot: true,
      ),
    )
    .firstWhere((s) => s.position.axis == Axis.vertical);

/// True while the lobby is on screen (its dock: START, or CONTINUE and NEW
/// RUN while a run is kept).
bool lobbyShown() =>
    find.byKey(const ValueKey('survival.dock')).evaluate().isNotEmpty;

/// The screen starts the run's music; under test there is nothing to play it
/// on, and the real controller opens audio players as it is built.
class SilentAudio extends ChangeNotifier implements AudioController {
  @override
  Future<void> playSurvivalMusic() async {}

  @override
  Future<void> playHomeMusic() async {}

  @override
  int soundEventSerial = 0;

  @override
  Future<void> playSound(
    SoundCue cue, {
    Object? owner,
    double speed = 1,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
