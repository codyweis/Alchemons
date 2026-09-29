@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/screens/cosmic/wild_space_encounter_screen.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/wild_breed_randomizer.dart';
import 'package:alchemons/services/wilderness_catch_service.dart';
import 'package:alchemons/services/wildlife_generator.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Renders the whole space encounter — HUD included — at landscape phone
/// sizes, before and after an ally is picked, so the spacing can be judged
/// as a picture.
///
///   WILD_OUT=/tmp flutter test \
///     test/wild_space_encounter_hud_preview_test.dart --tags preview
void main() {
  final outDir = Platform.environment['WILD_OUT'];

  Future<void> loadFont(String family, List<String> paths) async {
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      await (FontLoader(family)..addFont(
            Future.value(ByteData.view(file.readAsBytesSync().buffer)),
          ))
          .load();
      return;
    }
  }

  setUpAll(() async {
    await loadNatures();
    await loadFont('Roboto', [
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ]);
    await loadFont('monospace', [
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    ]);
    final home =
        Platform.environment['PUB_CACHE'] ??
        '${Platform.environment['HOME']}/.pub-cache';
    for (final (family, file) in const [
      ('PhosphorBold', 'Phosphor-Bold.ttf'),
      ('PhosphorFill', 'Phosphor-Fill.ttf'),
    ]) {
      await loadFont('packages/phosphoricons_flutter/$family', [
        '$home/hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts/$file',
      ]);
    }
  });

  for (final (label, size) in const [
    ('phone', Size(844, 390)),
    ('fold', Size(790, 500)),
  ]) {
    testWidgets('space encounter HUD preview ($label)', (tester) async {
      if (outDir == null) return;
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      late AlchemonsDatabase db;
      late ConstellationEffectsService constellation;
      final catalog = CreatureCatalog();
      late Creature wild;
      late CosmicEncounterBackdrop backdrop;
      await tester.runAsync(() async {
        await catalog.load();
        db = AlchemonsDatabase(NativeDatabase.memory());
        await db.constellationDao.unlockSkill(
          'breeder_wild_potential_analyzer',
          0,
        );
        final ally = catalog.creatures.firstWhere(
          (c) => c.types.contains('Lightning') && c.mutationFamily == 'Let',
        );
        await db.creatureDao.insertInstance(
          instanceId: 'ally-1',
          baseId: ally.id,
          level: 5,
        );
        constellation = ConstellationEffectsService(db);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final base = catalog.creatures.firstWhere(
          (c) => c.types.contains('Poison') && c.mutationFamily == 'Mane',
        );
        wild = WildCreatureRandomizer().randomizeWildCreature(
          WildlifeGenerator(catalog).generate(base.id, rarity: 'uncommon')!,
          seed: 4,
        );
      });
      final planet = CosmicPlanet(
        element: 'Poison',
        position: const Offset(4000, 4000),
        radius: 120,
        discovered: true,
      );
      backdrop = CosmicEncounterBackdrop(
        image: renderPlanetBackdropImage(planet, elapsed: 2),
        planetColor: planet.color,
        label: 'POISON PLANET',
        direction: const Offset(-0.7, 0.7),
      );

      final key = GlobalKey();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AlchemonsDatabase>.value(value: db),
            Provider<CreatureCatalog>.value(value: catalog),
            ChangeNotifierProvider<ConstellationEffectsService>.value(
              value: constellation,
            ),
            Provider<CatchService>.value(
              value: CatchService(db, constellation),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: RepaintBoundary(
              key: key,
              child: WildSpaceEncounterScreen(
                creature: wild,
                rarity: EncounterRarity.uncommon,
                party: const [PartyMember(instanceId: 'ally-1')],
                backdrop: backdrop,
              ),
            ),
          ),
        ),
      );

      Future<void> settle(int frames) async {
        for (var i = 0; i < frames; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      Future<void> shoot(String name) async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$outDir/wild_hud_${label}_$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }

      await settle(30);
      await shoot('arrived');

      // Pick the ally from the party strip.
      final allyCard = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onTap != null,
        description: 'party card',
      );
      final cards = allyCard.evaluate().toList();
      for (final e in cards) {
        final box = e.renderObject as RenderBox?;
        if (box == null || !box.hasSize) continue;
        final at = box.localToGlobal(box.size.center(Offset.zero));
        if (at.dx > size.width * 0.75 && at.dy < size.height * 0.3) {
          await tester.tapAt(at);
          break;
        }
      }
      await settle(12);
      await shoot('ally');
      // Not closed: drift's in-memory streams are still being fed by the
      // torn-down screen, and closing mid-feed hangs the test.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
