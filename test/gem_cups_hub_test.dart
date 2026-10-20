import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/stadium/bout_screen.dart';
import 'package:alchemons/screens/stadium/stadium_screen.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The gem cups from the Trials, each one's event played to its end — an
// island bout (Ruby), a planned flight (Sapphire) — and back to the Trials.
// (The Emerald Cup's battle ladder: gem_battle_ladder_test.dart.)
//
//   GEM_HUB_OUT=/tmp/gh flutter test test/gem_cups_hub_test.dart
// also writes frames.

class _PlainFont extends ThemeNotifier {
  _PlainFont(super.db);

  @override
  TextTheme Function(TextTheme) get currentTextThemeFn =>
      (t) => t;
}

void main() {
  final out = Platform.environment['GEM_HUB_OUT'];
  const size = Size(475, 751);
  var frame = 0;

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    if (out == null) return;
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
  });

  Future<void> play(
    WidgetTester tester, {
    required String progress,
    required String bout,
    required String tag,
    String? shows,
    List<String> ways = const ['ASTEROIDS', 'NEBULA'],
  }) async {
    SharedPreferences.setMockInitialValues({RaceProgress.prefsKey: progress});
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
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
      await db.creatureDao.addOrUpdateCreature(
        const PlayerCreaturesCompanion(
          id: Value('PIP02'),
          discovered: Value(true),
        ),
      );
      await db.creatureDao.insertInstance(
        instanceId: 'mine',
        baseId: 'PIP02',
        level: 10,
        staminaBars: 3,
        statSpeed: 5.4,
        statIntelligence: 5.4,
        statStrength: 5.6,
        statBeauty: 5.2,
        statSpeedPotential: 90,
        statIntelligencePotential: 90,
        statStrengthPotential: 90,
        statBeautyPotential: 90,
      );
      constellations = ConstellationEffectsService(db);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    final shot = GlobalKey();
    Future<void> snap(String name) async {
      if (out == null) return;
      Directory(out).createSync(recursive: true);
      await tester.runAsync(() async {
        final b =
            shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/${(frame++).toString().padLeft(3, '0')}_${tag}_$name.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
    }

    Future<void> settle([int frames = 8]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    final theme = factionThemeFor(null, brightness: Brightness.dark);
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
          ChangeNotifierProvider<ThemeNotifier>(create: (_) => _PlainFont(db)),
          ChangeNotifierProvider<ConstellationEffectsService>.value(
            value: constellations,
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) =>
              RepaintBoundary(key: shot, child: child!),
          home: const StadiumScreen(),
        ),
      ),
    );
    await settle(12);
    // Cups won before their rewards were shown: their cards first.
    for (var i = 0; i < 4 && find.text('CONTINUE').evaluate().isNotEmpty; i++) {
      await tester.tap(find.text('CONTINUE'));
      await settle(6);
    }
    await tester.tap(find.text('GEMS'));
    await settle(12);
    expect(find.text(bout), findsWidgets);
    expect(find.text('START'), findsOneWidget);
    if (shows != null) expect(find.textContaining(shows), findsOneWidget);
    await snap('gems');

    await tester.tap(find.text('START'));
    for (
      var i = 0;
      i < 200 &&
          find.text('PICK EVERY FORK').evaluate().isEmpty &&
          find.byType(BoutScreen).evaluate().isEmpty;
      i++
    ) {
      await settle(1);
    }
    // The space course asks for a route first.
    if (find.text('PICK EVERY FORK').evaluate().isNotEmpty) {
      await snap('plan');
      for (final kind in ways) {
        await tester.tap(find.text(kind).first);
        await settle(2);
      }
      await snap('planned');
      await tester.tap(find.text('FLY'));
      for (
        var i = 0;
        i < 60 && find.byType(BoutScreen).evaluate().isEmpty;
        i++
      ) {
        await settle(1);
      }
    }
    expect(find.byType(BoutScreen), findsOneWidget);

    var shots = 0;
    for (var i = 0; i < 1600 && find.text('AGAIN').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (i % 30 == 0 && shots < 8) {
        shots++;
        await snap('play');
      }
      if (i % 40 == 20) {
        for (final act in ['CHARGE', 'DASH', 'BOOST']) {
          final f = find.text(act);
          if (f.evaluate().isNotEmpty) await tester.tap(f);
        }
      }
    }
    expect(find.text('AGAIN'), findsOneWidget);
    await snap('results');
    await tester.tap(find.text('LEAVE'));
    await settle(16);
    expect(find.byType(BoutScreen), findsNothing);
    expect(find.text('THE TRIALS'), findsOneWidget);
  }

  testWidgets('Ruby: an island bout fought to the end', (tester) async {
    await play(
      tester,
      progress: '{"copper":3,"silver":3}',
      bout: 'SAND ISLAND',
      tag: 'ruby',
    );
  });

  testWidgets('Ruby: the Molten Heart fought to the end', (tester) async {
    await play(
      tester,
      progress: '{"copper":3,"silver":3,"ruby":1}',
      bout: 'MOLTEN HEART',
      tag: 'molten',
      shows: 'The island melts from its middle.',
    );
  });

  testWidgets('Sapphire: the Element Gates planned and flown', (tester) async {
    await play(
      tester,
      progress: '{"copper":3,"silver":3,"ruby":5,"sapphire_course":2}',
      bout: 'ELEMENT GATES',
      tag: 'gates',
      ways: const ['FIRE', 'SPIRIT', 'MUD', 'PLANT'],
    );
  });

  testWidgets('Sapphire: a route planned, then flown to the gate', (
    tester,
  ) async {
    await play(
      tester,
      progress: '{"copper":3,"silver":3,"ruby":5}',
      bout: 'ASTEROID RUN',
      tag: 'sapphire',
    );
  });
}
