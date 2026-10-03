import 'dart:convert';
import 'dart:io';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/progress_overview_screen.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Tapping a "milestone reached" notice opens the milestones list on that
// species' row. The species has just passed a milestone, so it is far from
// its next one and sorts low — below the fold of a lazy list, where its row
// was never built and the old scroll silently did nothing.
void main() {
  testWidgets('milestone notice scrolls to a row below the fold', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = AlchemonsDatabase(NativeDatabase.memory());
    late CreatureCatalog catalog;
    late String target;
    await tester.runAsync(() async {
      final json =
          jsonDecode(
                File('assets/data/alchemons_creatures.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final creatures = [
        for (final c in json['creatures'] as List)
          Creature.fromJson(c as Map<String, dynamic>),
      ];
      catalog = CreatureCatalog.fromList(creatures);
      // Forty species one short of their first milestone sort first…
      for (final c in creatures.take(40)) {
        for (var i = 0; i < 4; i++) {
          await db.constellationDao.incrementBreedCount(c.id);
        }
      }
      // …and the one that just reached 75 (25 to its next) sorts last.
      target = creatures[40].id;
      for (var i = 0; i < 75; i++) {
        await db.constellationDao.incrementBreedCount(target);
      }
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
          Provider<CreatureCatalog>.value(value: catalog),
          ChangeNotifierProvider<ConstellationService>(
            create: (_) => ConstellationService(db),
          ),
        ],
        child: MaterialApp(
          home: ConstellationProgressOverviewScreen(highlightSpeciesId: target),
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 33));
    }

    final name = find.text(catalog.getCreatureById(target)!.name.toUpperCase());
    expect(name, findsOneWidget);
    final y = tester.getCenter(name).dy;
    expect(y, inInclusiveRange(0, 844), reason: 'row is on screen');

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
