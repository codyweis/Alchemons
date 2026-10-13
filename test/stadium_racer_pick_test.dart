import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/providers/app_providers.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/stadium/race_screen.dart';
import 'package:alchemons/screens/stadium/racer_gate.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/screens/stadium/stadium_screen.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_specimens_page.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The stadium's gate: tap the racer, pick another in the usual slide-up
// picker, and it flies out of its case to the line.
//
//   RACER_OUT=/tmp/racer flutter test test/stadium_racer_pick_test.dart
// also writes frames of the flight (RACER_SIZE=475x751 for the Fold).

class _PlainFont extends ThemeNotifier {
  _PlainFont(super.db);

  @override
  TextTheme Function(TextTheme) get currentTextThemeFn =>
      (t) => t;
}

void main() {
  final out = Platform.environment['RACER_OUT'];
  final sizeArg = Platform.environment['RACER_SIZE'] ?? '390x844';
  final size = Size(
    double.parse(sizeArg.split('x')[0]),
    double.parse(sizeArg.split('x')[1]),
  );

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
    final home =
        Platform.environment['PUB_CACHE'] ??
        '${Platform.environment['HOME']}/.pub-cache';
    await loadFont(
      'packages/phosphoricons_flutter/PhosphorBold',
      '$home/hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts/Phosphor-Bold.ttf',
    );
  });

  const owned = ['MAN03', 'WNG05', 'PIP01', 'HOR01', 'LET02', 'KIN02'];

  testWidgets('a racer picked flies to the line and is kept', (tester) async {
    SharedPreferences.setMockInitialValues({});
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
      for (final id in owned.toSet()) {
        await db.creatureDao.addOrUpdateCreature(
          PlayerCreaturesCompanion(
            id: Value(id),
            discovered: const Value(true),
          ),
        );
      }
      for (var n = 0; n < owned.length; n++) {
        await db.creatureDao.insertInstance(
          instanceId: 'i$n',
          baseId: owned[n],
          level: 5 + n,
          staminaBars: 3,
          // The first is the fastest, so it starts at the line.
          statSpeed: 4.0 - n * .3,
          statIntelligence: 2.5,
          statStrength: 2.5,
          statBeauty: 2.5,
          statSpeedPotential: 4,
          statIntelligencePotential: 4,
          statStrengthPotential: 4,
          statBeautyPotential: 4,
        );
      }
      constellations = ConstellationEffectsService(db);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    final shot = GlobalKey();
    var frame = 0;
    Future<void> snap(String name) async {
      if (out == null) return;
      Directory(out).createSync(recursive: true);
      await tester.runAsync(() async {
        final b =
            shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/${(frame++).toString().padLeft(3, '0')}_$name.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
    }

    // Real time for the database's streams, then a frame.
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
              RepaintBoundary(key: shot, child: child!),
          home: const StadiumScreen(party: []),
        ),
      ),
    );
    await settle(12);
    // No party: the fastest stands at the line.
    final first = catalog.getCreatureById('MAN03')!.name;
    expect(find.text(first), findsOneWidget);
    await snap('gate');

    await tester.tap(find.byType(RacerGate));
    await settle(14);
    expect(find.byType(AllSpecimensPage), findsOneWidget);
    expect(find.text('CHOOSE A RACER'), findsOneWidget);
    await snap('picker');

    // Pick the Horn.
    final horn = catalog.getCreatureById('HOR01')!.name;
    await tester.tap(find.byKey(const ValueKey('i3')));
    // The pick is read before the picker closes.
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    // The flight and the landing.
    for (var t = 0; t < 1700; t += 40) {
      await tester.pump(const Duration(milliseconds: 40));
      if (t % 80 == 0) await snap('fly$t');
    }
    await settle(4);
    expect(find.byType(AllSpecimensPage), findsNothing);
    expect(find.text(horn), findsOneWidget);
    await snap('landed');

    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getString(kStadiumRacerKey), 'i3');

    // RACE: the lights go down, the phone turns, the race comes up; leaving
    // it turns the phone back under the lights to the Trials.
    final turns = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          final first = (call.arguments as List).first as String;
          turns.add(first);
          tester.view.physicalSize =
              (first.contains('landscape') ? size.flipped : size) * 2;
        }
        return null;
      },
    );
    const rotation = MethodChannel('alchemons/rotation');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      rotation,
      (call) async => null,
    );
    addTearDown(() {
      final m = tester.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, null);
      m.setMockMethodCallHandler(rotation, null);
    });
    await tester.tap(find.text('RACE'));
    // The six (and what they fuse into) load in real time, then the lights.
    for (var i = 0; i < 200 && turns.isEmpty; i++) {
      await settle(1);
    }
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(turns.first, contains('landscape'));
    expect(find.byType(RaceScreen), findsOneWidget);
    await snap('race');
    await tester.tap(find.byType(BracketIconButton).first);
    await settle(4);
    await tester.tap(find.text('LEAVE'));
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(turns.last, contains('portrait'));
    expect(find.byType(RaceScreen), findsNothing);
    expect(find.text('THE TRIALS'), findsOneWidget);
    await snap('back');
  });
}
