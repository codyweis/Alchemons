@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/providers/app_providers.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/party_picker/party_picker.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The squad picker survival (and the wild, and cosmic) opens: empty, with a
// team already chosen, on a narrow phone, and with larger text.
//
//   PARTY_OUT=/tmp/party flutter test \
//     test/party_picker_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['PARTY_OUT'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
    final home =
        Platform.environment['PUB_CACHE'] ??
        '${Platform.environment['HOME']}/.pub-cache';
    await loadFont(
      'packages/phosphoricons_flutter/PhosphorBold',
      '$home/hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts/Phosphor-Bold.ttf',
    );
  });

  // (species, level, prismatic, favourite, stamina)
  const owned = <(String, int, bool, bool, int)>[
    ('LET01', 14, false, true, 3),
    ('LET01', 6, false, false, 2),
    ('LET02', 9, false, false, 3),
    ('LET03', 11, false, false, 0),
    ('LET04', 3, false, false, 3),
    ('PIP01', 18, true, true, 3),
    ('PIP02', 7, false, false, 1),
    ('PIP04', 12, false, false, 3),
    ('HOR01', 22, false, true, 3),
    ('HOR07', 10, false, false, 0),
    ('MAN03', 8, false, false, 3),
    ('MAN09', 16, false, false, 2),
    ('MSK04', 5, false, false, 3),
    ('WNG05', 25, false, true, 3),
    ('KIN02', 4, false, false, 3),
    ('LET07', 2, false, false, 3),
    ('PIP10', 6, false, false, 3),
  ];

  testWidgets('party picker preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);

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
      for (final id in {for (final o in owned) o.$1}) {
        await db.creatureDao.addOrUpdateCreature(
          PlayerCreaturesCompanion(
            id: Value(id),
            discovered: const Value(true),
          ),
        );
      }
      var n = 0;
      for (final (base, level, prismatic, fav, bars) in owned) {
        final id = 'i${n++}';
        await db.creatureDao.insertInstance(
          instanceId: id,
          baseId: base,
          level: level,
          isPrismaticSkin: prismatic,
          staminaBars: bars,
          statSpeed: 1.5 + (n % 5) * 0.7,
          statIntelligence: 2.0 + (n % 3) * 0.9,
          statStrength: 1.0 + (n % 4) * 0.8,
          statBeauty: 2.5 + (n % 2) * 1.1,
          statSpeedPotential: 2.0 + (n % 3),
          statIntelligencePotential: 3.0 + (n % 2),
          statStrengthPotential: 2.5 + (n % 4) * 0.5,
          statBeautyPotential: 3.5,
        );
        if (fav) await db.creatureDao.setFavorite(id, true);
      }
      constellations = ConstellationEffectsService(db);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    final key = GlobalKey();
    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> settle([int frames = 8]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    final overflows = <String>[];
    final theme = factionThemeFor(null, brightness: Brightness.dark);
    Future<void> show(String name, Size size, Widget page) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      // A fresh app each time, so no dialog is left open from the last.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AlchemonsDatabase>.value(value: db),
            Provider<FactionTheme>.value(value: theme),
            Provider<CreatureCatalog>.value(value: catalog),
            Provider<StaminaService>.value(value: StaminaService(db)),
            ChangeNotifierProvider<SelectedPartyNotifier>(
              create: (_) => SelectedPartyNotifier(),
            ),
            ChangeNotifierProvider<ThemeNotifier>(
              create: (_) => _PlainFont(db),
            ),
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
            ChangeNotifierProvider<ConstellationEffectsService>.value(
              value: constellations,
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            builder: (context, child) =>
                RepaintBoundary(key: key, child: child!),
            home: page,
          ),
        ),
      );
      await settle(30);
      final e = tester.takeException();
      if (e != null) overflows.add('$name: $e');
      await shoot(name);
    }

    const survivalEmpty = PartyPickerScreen(
      key: ValueKey('a'),
      showDeployConfirm: false,
      enforceUniqueSpecies: false,
      maxSelections: 5,
      confirmLabel: 'Choose Team',
    );
    const survivalTeam = PartyPickerScreen(
      key: ValueKey('b'),
      showDeployConfirm: false,
      enforceUniqueSpecies: false,
      maxSelections: 5,
      initialSelection: ['i5', 'i8', 'i13', 'i11', 'i0'],
      confirmLabel: 'Choose Team',
    );

    await show('1_survival_empty', const Size(390, 844), survivalEmpty);
    await show('2_survival_team', const Size(390, 844), survivalTeam);
    await show('3_narrow_344', const Size(344, 882), survivalTeam);

    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await show('4_large_text', const Size(344, 882), survivalTeam);
    tester.platformDispatcher.clearTextScaleFactorTestValue();

    // Saved teams, over the survival picker, with one saved.
    await tester.runAsync(
      () => db.settingsDao.setSetting(
        'saved_teams_party_picker',
        '[{"members":["i5","i8","i13"]},{"members":["i0","i2","i9","i11","i14"]}]',
      ),
    );
    await show('6_survival_team_again', const Size(390, 844), survivalTeam);
    await tester.tap(find.text('SAVED'));
    await settle(12);
    await shoot('7_saved_teams');

    // The same at the Fold's width with large text.
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    await show('8_saved_narrow', const Size(344, 882), survivalTeam);
    await tester.tap(find.text('SAVED'));
    await settle(12);
    if (tester.takeException() case final e?) overflows.add('8: $e');
    await shoot('8_saved_narrow');
    tester.platformDispatcher.clearTextScaleFactorTestValue();

    // The wild's picker: four, on the shared selection, then its question.
    await show(
      '5_wild',
      const Size(390, 844),
      const PartyPickerScreen(key: ValueKey('c')),
    );
    for (final name in ['WATERKIN', 'LIGHTNINGLET', 'DUSTPIP']) {
      await tester.tap(find.text(name).first);
      await settle(2);
    }
    await tester.tap(find.text('DEPLOY TEAM'));
    await settle(12);
    if (tester.takeException() case final e?) overflows.add('9: $e');
    await shoot('9_wild_deploy');

    await tester.pumpWidget(const SizedBox());
    await settle(4);
    tester.view.reset();
    await tester.runAsync(db.close);
    File('$out/overflows.txt').writeAsStringSync(overflows.join('\n\n'));
  });
}

/// The app's font is fetched from Google at run time; a test has no network.
class _PlainFont extends ThemeNotifier {
  _PlainFont(super.db);

  @override
  TextTheme Function(TextTheme) get currentTextThemeFn =>
      (t) => t;
}
