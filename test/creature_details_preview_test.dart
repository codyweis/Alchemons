@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The full details dialog on a phone, every tab scrolled flat onto one tall
// page: a fused Lavahorn with no analyzers (a) and all of them (b), a wild
// founder (c), the species alone from the catalog (d), and a line through
// fifteen elements (e).
//
//   DETAILS_OUT=/tmp/details flutter test \
//     test/creature_details_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['DETAILS_OUT'];

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
    // The icons: stars, favourite and close come from Phosphor.
    final home = Platform.environment['HOME'];
    const phosphor = 'phosphoricons_flutter-1.0.0/lib/fonts';
    for (final (family, file) in const [
      ('PhosphorFill', 'Phosphor-Fill.ttf'),
      ('PhosphorBold', 'Phosphor-Bold.ttf'),
      ('Phosphor', 'Phosphor.ttf'),
    ]) {
      await loadFont(
        'packages/phosphoricons_flutter/$family',
        '$home/.pub-cache/hosted/pub.dev/$phosphor/$file',
      );
    }
  });

  Map<String, dynamic> snap(Creature c, String id) => {
    'instanceId': id,
    'baseId': c.id,
    'name': c.name,
    'types': c.types,
    'rarity': c.rarity,
    'image': c.image,
    'nativeFaction': 'volcanic',
    'elementLineage': {c.types.first: 1},
    'familyLineage': {'Horn': 1},
  };

  for (final (tag, analyzed, fused, species) in const [
    ('a', false, true, false),
    ('b', true, true, false),
    ('c', true, false, false),
    ('d', true, false, true),
    // A long line through fifteen elements and five families.
    ('e', true, true, false),
  ]) {
    testWidgets('details preview $tag', (tester) async {
      if (out == null) return;
      Directory(out).createSync(recursive: true);
      final db = AlchemonsDatabase(NativeDatabase.memory());
      final catalog = CreatureCatalog();
      await tester.runAsync(() async {
        await catalog.load();
        await loadNatures();
        await GeneticsCatalog.load();
        if (analyzed) {
          for (final s in const [
            'breeder_lineage_analyzer',
            'breeder_gene_analyzer',
            'breeder_potential_analyzer',
            'breeder_dominant_analyzer',
          ]) {
            await db.constellationDao.unlockSkill(s, 0);
          }
        }
        final fire = catalog.getCreatureById('HOR01')!;
        final earth = catalog.getCreatureById('HOR03')!;
        await db.creatureDao.insertInstance(
          instanceId: 'x',
          baseId: 'HOR06',
          level: 7,
          xp: 40,
          natureId: 'Metabolic',
          source: fused ? 'standard_fusion' : 'wild_capture',
          genetics: {'size': 'large', 'tinting': 'warm'},
          parentage: !fused
              ? null
              : {
                  'parentA': snap(fire, 'pa'),
                  'parentB': snap(earth, 'pb'),
                  'bredAt': '2026-10-01T12:00:00Z',
                },
          likelihoodAnalysisJson: !fused
              ? null
              : jsonEncode({
                  'breedingType': 'crossSpecies',
                  'summaryLine': 'Firehorn × Earthhorn: Lavahorn',
                  'inheritanceMechanics': [
                    {
                      'category': 'Elemental Type',
                      'result': 'Lava',
                      'mechanism': 'Fire + Earth combine into Lava by recipe.',
                      'percentage': 62.0,
                      'likelihood': 2,
                    },
                    {
                      'category': 'Family Lineage',
                      'result': 'Horn',
                      'mechanism': 'Both parents are Horns.',
                      'percentage': 100.0,
                      'likelihood': 3,
                    },
                    {
                      'category': 'Size',
                      'result': 'Large',
                      'mechanism':
                          'Blended from parent sizes with a small drift.',
                      'percentage': 21.0,
                      'likelihood': 1,
                    },
                  ],
                  'specialEvents': [],
                  'outcomeCategory': 'Expected',
                  'outcomeExplanation':
                      'Most traits followed the likeliest path.',
                  'overallLikelihood': 58.0,
                }),
          statSpeed: 3.1,
          statIntelligence: 2.4,
          statStrength: 4.2,
          statBeauty: 1.8,
          statSpeedPotential: 3.8,
          statIntelligencePotential: 3.0,
          statStrengthPotential: 4.6,
          statBeautyPotential: 2.6,
          generationDepth: fused ? 1 : 0,
          elementLineage: tag == 'e'
              ? const {
                  'Fire': 40,
                  'Earth': 22,
                  'Water': 14,
                  'Air': 9,
                  'Lava': 7,
                  'Steam': 5,
                  'Ice': 4,
                  'Mud': 3,
                  'Dust': 3,
                  'Crystal': 2,
                  'Plant': 2,
                  'Poison': 1,
                  'Spirit': 1,
                  'Dark': 1,
                  'Light': 1,
                }
              : fused
              ? {'Fire': 1, 'Earth': 1}
              : {'Lava': 1},
          familyLineage: tag == 'e'
              ? const {'Horn': 30, 'Wing': 9, 'Let': 4, 'Pip': 2, 'Kin': 1}
              : fused
              ? {'Horn': 2}
              : {'Horn': 1},
        );
      });
      final constellation = ConstellationEffectsService(db);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );

      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      final theme = FactionTheme.scorchForge();

      Future<void> settle([int n = 8]) async {
        for (var i = 0; i < n; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      // Shoot each screenful of the current tab until it stops scrolling.
      Future<void> shootTab(String name) async {
        final scrollables = find.byType(Scrollable).evaluate().where((e) {
          final s = (e as StatefulElement).state as ScrollableState;
          return s.axisDirection == AxisDirection.down &&
              (e.renderObject as RenderBox).hasSize &&
              (e.renderObject as RenderBox).localToGlobal(Offset.zero).dx >=
                  0 &&
              (e.renderObject as RenderBox).localToGlobal(Offset.zero).dx < 390;
        }).toList();
        final pos = scrollables.isEmpty
            ? null
            : ((scrollables.last as StatefulElement).state as ScrollableState)
                  .position;
        var page = 0;
        while (true) {
          await settle(3);
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1.5);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              '$out/${tag}_${name}_$page.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
          if (pos == null || pos.pixels >= pos.maxScrollExtent - 1) break;
          pos.jumpTo(
            (pos.pixels + pos.viewportDimension * 0.85).clamp(
              0,
              pos.maxScrollExtent,
            ),
          );
          page++;
          if (page > 8) break;
        }
      }

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AlchemonsDatabase>.value(value: db),
            Provider<FactionTheme>.value(value: theme),
            Provider<CreatureCatalog>.value(value: catalog),
            Provider<StaminaService>.value(value: StaminaService(db)),
            ChangeNotifierProvider<ConstellationEffectsService>.value(
              value: constellation,
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            builder: (context, child) =>
                RepaintBoundary(key: key, child: child!),
            home: Builder(
              builder: (context) => Scaffold(
                backgroundColor: const Color(0xFF0B0A10),
                body: Center(
                  child: TextButton(
                    onPressed: () => CreatureDetailsDialog.show(
                      context,
                      catalog.getCreatureById('HOR06')!,
                      true,
                      instanceId: species ? null : 'x',
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(30);
      await shootTab('overview');
      if (!species) {
        await tester.tap(find.text('Lineage'));
        await settle(10);
        await shootTab('lineage');
      }

      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.runAsync(db.close);
    });
  }
}
