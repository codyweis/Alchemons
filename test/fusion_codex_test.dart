import 'dart:convert';
import 'dart:io';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/alchemical_encyclopedia_screen.dart';
import 'package:alchemons/services/alchemical_encyclopedia_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/fx/codex_stage.dart';
import 'package:alchemons/widgets/fx/element_orb.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

CreatureCatalog _catalog() {
  final json =
      jsonDecode(
            File('assets/data/alchemons_creatures.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  return CreatureCatalog.fromList([
    for (final c in json['creatures'] as List)
      Creature.fromJson(c as Map<String, dynamic>),
  ]);
}

Future<void> _seed(AlchemonsDatabase db) async {
  for (final id in const ['LET01', 'PIP02']) {
    await db.creatureDao.addOrUpdateCreature(
      PlayerCreaturesCompanion(id: Value(id), discovered: const Value(true)),
    );
  }
  await db.creatureDao.insertInstance(
    instanceId: 'a',
    baseId: 'LET01',
    level: 3,
  );
  await db.creatureDao.insertInstance(
    instanceId: 'b',
    baseId: 'HOR09',
    level: 3,
  );
  await db.settingsDao.setSetting(
    'enc.element.outcomes.v2',
    jsonEncode(['Air+Water::Ice']),
  );
  await db.settingsDao.setSetting(
    'enc.family.outcomes.v2',
    jsonEncode(['Let+Pip::Mask']),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadNatures);

  group('what the Codex knows', () {
    test('elements and species come from finds, keeps and formulas', () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);

      final data = await AlchemicalEncyclopediaService.loadSnapshot(
        db: db,
        catalog: _catalog(),
      );

      // Found Firelet and Waterpip; keeps an Icehorn; made Ice of Air and
      // Water — so both of its makers are known too.
      expect(
        data.knownElements,
        containsAll(<String>['Fire', 'Water', 'Ice', 'Air']),
      );
      expect(data.knownElements, isNot(contains('Blood')));
      expect(
        data.knownFamilies,
        containsAll(<String>['Let', 'Pip', 'Horn', 'Mask']),
      );
      expect(data.knownFamilies, isNot(contains('Wing')));
      // A family's face is one the player found, when there is one.
      expect(data.familyFaces['Pip']!.id, 'PIP02');
      expect(data.familyFaces['Wing'], isNotNull);
    });

    test('without a catalog only formulas make things known', () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);

      final data = await AlchemicalEncyclopediaService.loadSnapshot(db: db);

      expect(data.knownElements, {'Air', 'Water', 'Ice'});
      expect(data.knownFamilies, {'Let', 'Pip', 'Mask'});
      expect(data.familyFaces, isEmpty);
    });

    test('an element\'s formulas: what makes it, what it fuses into', () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final data = await AlchemicalEncyclopediaService.loadSnapshot(db: db);

      final makesIce = data.elementMadeFrom('Ice').map((r) => r.pairKey);
      expect(makesIce, contains('Air+Water'));
      expect(makesIce, isNot(contains('Fire+Ice')));
      final iceMakes = data.elementFusesInto('Ice').map((r) => r.pairKey);
      expect(iceMakes, containsAll(<String>['Fire+Ice', 'Ice+Lava']));
      // Every element has a formula that makes it.
      for (final e in EssenceElement.values) {
        final name = e.name[0].toUpperCase() + e.name.substring(1);
        expect(data.elementMadeFrom(name), isNotEmpty, reason: name);
      }
      // A Let is only ever found.
      expect(data.familyMadeFrom('Let'), isEmpty);
    });
  });

  group('the orb', () {
    test(
      'hands its grains over where they stand, and a locked one has none',
      () {
        final orb = ElementOrb(EssenceElement.ice, radius: 50);
        final g = orb.grainsAt(1.0);
        expect(g.length, orb.length);
        expect(g.tones.length, 11);
        for (var i = 0; i < g.length; i++) {
          expect(g.hx[i] * g.hx[i] + g.hy[i] * g.hy[i], lessThan(52.0 * 52));
        }
        expect(
          ElementOrb(EssenceElement.ice, radius: 50, locked: true).length,
          0,
        );
      },
    );
  });

  group('the stage', () {
    Future<CodexStageController> pumpStage(WidgetTester tester) async {
      final controller = CodexStageController();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 360,
              height: 220,
              child: CodexStage(controller: controller),
            ),
          ),
        ),
      );
      return controller;
    }

    testWidgets('a formula plays through and leaves what it made', (
      tester,
    ) async {
      final c = await pumpStage(tester);
      c.show(OrbBody('Fire', radius: 55));
      await tester.pump(const Duration(milliseconds: 16));
      final ice = OrbBody('Ice', radius: 55);
      c.combine(
        OrbBody('Air', radius: 55),
        OrbBody('Water', radius: 55),
        ice,
        tag: 'air-water',
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(c.busy, isTrue);
      expect(c.playing, 'air-water');
      for (var i = 0; i < 300 && c.busy; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(c.busy, isFalse);
      expect(c.playing, isNull);
      expect(c.subject, same(ice));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a tap comes apart and back; a locked one does not', (
      tester,
    ) async {
      final c = await pumpStage(tester);
      c.show(OrbBody('Crystal', radius: 55));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(find.byType(CodexStage));
      await tester.pump(const Duration(milliseconds: 16));
      expect(c.busy, isTrue);
      // In frames: the stage takes at most 50 ms a step, so a hitch never
      // jumps it.
      for (var i = 0; i < 200 && c.busy; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(c.busy, isFalse);

      c.show(OrbBody('Blood', radius: 55, locked: true));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(find.byType(CodexStage));
      await tester.pump(const Duration(milliseconds: 16));
      expect(c.busy, isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('the Codex opens an element and plays its formula', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = AlchemonsDatabase(NativeDatabase.memory());
    late ConstellationEffectsService constellations;
    final catalog = _catalog();
    await tester.runAsync(() async {
      await _seed(db);
      constellations = ConstellationEffectsService(db);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    Future<void> settle([int frames = 8]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    try {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AlchemonsDatabase>.value(value: db),
            Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
            Provider<CreatureCatalog>.value(value: catalog),
            ChangeNotifierProvider<FactionService>.value(
              value: FactionService(db),
            ),
            ChangeNotifierProvider<ConstellationEffectsService>.value(
              value: constellations,
            ),
          ],
          child: const MaterialApp(home: AlchemicalEncyclopediaScreen()),
        ),
      );
      await settle(10);
      expect(find.text('FUSION CODEX'), findsOneWidget);
      expect(find.text('BLOOD'), findsOneWidget);

      await tester.tap(find.text('ICE'));
      await settle(20);
      expect(find.text('MADE FROM'), findsOneWidget);
      expect(find.text('2 MORE NOT YET FOUND'), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.play_arrow_rounded).first);
      await settle(4);
      expect(find.textContaining('WATER'), findsWidgets);
      await settle(130);
      expect(tester.takeException(), isNull);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await settle(16);
      expect(find.text('MADE FROM'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.runAsync(db.close);
    }
  });
}
