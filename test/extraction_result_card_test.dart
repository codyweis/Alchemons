import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/nursery/extraction_result_card.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// The extraction result card: the reading waits for the specimen to stand
// whole, the gated figures stay gated, and the button closes it.
//
// With EXTRACT_OUT set, it also draws the card on a phone with real fonts and
// sprites: mid-reveal, mid-pour (its rim of sand running round) and at rest:
//
//   EXTRACT_OUT=/tmp/extract flutter test test/extraction_result_card_test.dart

Creature _species(
  String id,
  String name,
  String type,
  String rarity,
  String sheet,
  int frame,
) => Creature(
  id: id,
  name: name,
  types: [type],
  rarity: rarity,
  description:
      'Thin and half-returned, it stands like a memory forced to keep '
      'watch after death should have taken it.',
  image: 'test.png',
  mutationFamily: 'Horn',
  spriteData: SpriteData(
    frameWidth: frame,
    frameHeight: frame,
    totalFrames: 4,
    frameDurationMs: 110,
    rows: 1,
    spriteSheetPath: sheet,
  ),
);

void main() {
  late AlchemonsDatabase db;
  final firehorn = _species(
    'HOR01',
    'Firehorn',
    'Fire',
    'Rare',
    'creatures/rare/HOR01_firehorn_spritesheet.png',
    1200,
  );
  final wraithord = _species(
    'MYS14',
    'Wraithord',
    'Spirit',
    'Mystic',
    'creatures/mystic/MYS14_spiritmystic_spritesheet.png',
    512,
  );

  Future<CreatureInstance> insert(
    String id,
    String baseId, {
    bool prismatic = false,
    String? mutation,
    String? variant,
  }) async {
    await db.creatureDao.insertInstance(
      instanceId: id,
      baseId: baseId,
      isPrismaticSkin: prismatic,
      mutation: mutation,
      variantFaction: variant,
      statSpeed: 1.12,
      statIntelligence: 0.74,
      statStrength: 1.86,
      statBeauty: 0.51,
      statSpeedPotential: 64,
      statIntelligencePotential: 38,
      statStrengthPotential: 91,
      statBeautyPotential: 22,
    );
    return (await db.creatureDao.getInstance(id))!;
  }

  Widget host(
    FactionTheme theme,
    Creature species,
    CreatureInstance instance, {
    bool isNewDiscovery = false,
    Key? shotKey,
    ConstellationEffectsService? effects,
    TextTheme? textTheme,
  }) {
    return MultiProvider(
      providers: [
        Provider<AlchemonsDatabase>.value(value: db),
        Provider<FactionTheme>.value(value: theme),
        Provider<CreatureCatalog>.value(
          value: CreatureCatalog.fromList([firehorn, wraithord]),
        ),
        ChangeNotifierProvider<ConstellationEffectsService>.value(
          value: effects ?? ConstellationEffectsService(db),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: textTheme != null
            ? theme.toMaterialTheme(textTheme)
            : theme.isDark
            ? ThemeData.dark()
            : ThemeData.light(),
        builder: shotKey == null
            ? null
            : (context, child) => RepaintBoundary(key: shotKey, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: theme.isDark
                ? const Color(0xFF0B0A10)
                : const Color(0xFFE9E1D2),
            body: Center(
              child: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  barrierColor: Colors.black.withValues(alpha: 0.78),
                  builder: (_) => ExtractionResultCard(
                    species: species,
                    instance: instance,
                    isNewDiscovery: isNewDiscovery,
                    cinematicQuality: CinematicQuality.cinematic,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Queries started on the test clock only finish when it moves, and closing
  // the database waits on them.
  Future<void> drain(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
  }

  setUp(() => db = AlchemonsDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('the reading waits for the specimen, then the button closes it', (
    tester,
  ) async {
    late CreatureInstance inst;
    await tester.runAsync(() async => inst = await insert('a', 'HOR01'));
    try {
      await tester.pumpWidget(host(FactionTheme.scorchForge(), firehorn, inst));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ExtractionResultCard), findsOneWidget);
      expect(find.text('Firehorn'), findsOneWidget);

      // Still revealing: the button is there but cannot be pressed yet.
      await tester.tap(find.text('CONTINUE'), warnIfMissed: false);
      await tester.pump();
      expect(find.byType(ExtractionResultCard), findsOneWidget);

      // The sprite never loads on the test clock, so the essence shows it
      // plainly and reports the reveal done; the reading comes in.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final reading = tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.text('CLASSIFICATION'),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(reading.opacity, 1);

      await tester.tap(find.text('CONTINUE'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(ExtractionResultCard), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await drain(tester);
    }
  });

  testWidgets('marks show; Potential and Dominants stay behind analyzers', (
    tester,
  ) async {
    late CreatureInstance inst;
    await tester.runAsync(
      () async => inst = await insert(
        'b',
        'MYS14',
        prismatic: true,
        mutation: 'transmuted',
        variant: 'bloodborn',
      ),
    );
    try {
      await tester.pumpWidget(
        host(FactionTheme.scorchForge(), wraithord, inst, isNewDiscovery: true),
      );
      await tester.tap(find.text('open'));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // The marks are engraved at the foot of the stage, one line.
      for (final mark in const [
        'NEW DISCOVERY',
        'TRANSMUTED',
        'PRISMATIC',
        'BLOODBORN',
      ]) {
        expect(find.text(mark), findsOneWidget, reason: mark);
      }
      expect(find.text('Mystic'), findsOneWidget);
      // No analyzers unlocked in a fresh save: no Potential, no Dominants.
      expect(_potentials(), findsNothing);
      await tester.tap(find.text('GENETICS'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('DOMINANT'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await drain(tester);
    }
  });

  testWidgets('with the analyzers, Potential reads as numbers', (tester) async {
    late CreatureInstance inst;
    late ConstellationEffectsService effects;
    await tester.runAsync(() async {
      inst = await insert('c', 'HOR01');
      await db.constellationDao.unlockSkill('breeder_potential_analyzer', 0);
      await db.constellationDao.unlockSkill('breeder_dominant_analyzer', 0);
      effects = ConstellationEffectsService(db);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    try {
      await tester.pumpWidget(
        host(FactionTheme.scorchForge(), firehorn, inst, effects: effects),
      );
      await tester.tap(find.text('open'));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_potentials(), findsNWidgets(4));
      expect(find.textContaining('P 91', findRichText: true), findsOneWidget);
      await tester.tap(find.text('GENETICS'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('DOMINANT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await drain(tester);
    }
  });

  testWidgets('extraction card preview', (tester) async {
    final out = Platform.environment['EXTRACT_OUT'];
    if (out == null) return;
    Directory(out).createSync(recursive: true);

    Future<void> loadFont(String family, String path) async {
      final file = File(path);
      if (!file.existsSync()) return;
      await (FontLoader(family)..addFont(
            Future.value(ByteData.view(file.readAsBytesSync().buffer)),
          ))
          .load();
    }

    await tester.runAsync(() async {
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
    // The game's book hand, fetched before the first frame.
    HttpOverrides.global = null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.createTempSync('fonts').path,
    );
    late TextTheme book;
    await tester.runAsync(() async {
      book = GoogleFonts.imFellEnglishTextTheme(ThemeData.dark().textTheme);
      GoogleFonts.imFellEnglish(fontStyle: FontStyle.italic);
      await GoogleFonts.pendingFonts();
    });

    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    late CreatureInstance plain, fancy, prism, loose;
    await tester.runAsync(() async {
      plain = await insert('p', 'HOR01');
      prism = await insert('q', 'HOR01', prismatic: true, variant: 'volcanic');
      loose = await insert('l', 'MYS14', mutation: 'alchemized');
      fancy = await insert(
        'f',
        'MYS14',
        prismatic: true,
        mutation: 'transmuted',
        variant: 'bloodborn',
      );
    });

    final key = GlobalKey();
    bool revealed() {
      final label = find.text('CLASSIFICATION');
      if (label.evaluate().isEmpty) return false;
      return tester
              .widget<AnimatedOpacity>(
                find
                    .ancestor(of: label, matching: find.byType(AnimatedOpacity))
                    .first,
              )
              .opacity ==
          1;
    }

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

    // Real time for the sprite to load and be read, then test-clock frames.
    Future<void> run(int realMs, int frames) async {
      for (var i = 0; i < realMs ~/ 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    // Read with both analyzers, so the Potential figures and the Dominant
    // labels are in the shot. (Without them is the second test above.)
    late ConstellationEffectsService analyzed;
    await tester.runAsync(() async {
      await db.constellationDao.unlockSkill('breeder_potential_analyzer', 0);
      await db.constellationDao.unlockSkill('breeder_dominant_analyzer', 0);
      analyzed = ConstellationEffectsService(db);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    // Dark only: the game has no light mode.
    for (final (name, species, inst, discovery) in [
      ('rare', firehorn, plain, false),
      ('mystic', wraithord, fancy, true),
      ('prismatic', firehorn, prism, false),
      ('alchemized', wraithord, loose, false),
    ]) {
      await tester.pumpWidget(
        host(
          FactionTheme.scorchForge(),
          species,
          inst,
          isNewDiscovery: discovery,
          shotKey: key,
          effects: analyzed,
          textTheme: book,
        ),
      );
      await tester.tap(find.text('open'));
      await run(900, 22);
      await shoot('${name}_0_revealing');
      // On to the moment it lands: the reading comes in and the sand pours.
      for (var i = 0; i < 120 && !revealed(); i++) {
        await run(100, 1);
      }
      // The pour, a few frames apart (the plain one in full).
      final pours = name == 'rare' ? const [9, 15, 15, 21] : const [21];
      for (var k = 0; k < pours.length; k++) {
        await run(0, pours[k]);
        await shoot('${name}_1_pouring_$k');
      }
      await run(0, 120);
      await shoot('${name}_2_rest');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
    await drain(tester);
  });
}

Finder _potentials() =>
    find.textContaining(RegExp(r'^P \d+$'), findRichText: true);
