// The space stations' screens: what they offer and what a trade does.

import 'dart:convert';
import 'dart:io';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/cosmic/cosmic_sell_sheet.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('a scan that was paid for survives a restart', () {
    test('the locks round-trip through the saved world', () {
      const state = CosmicFogState(
        worldSeed: 7,
        discoveredIndices: {1, 2},
        starDustScanTarget: 14,
        planetScanTarget: 3,
      );
      final back = CosmicFogState.deserialise(state.serialise());
      expect(back.starDustScanTarget, 14);
      expect(back.planetScanTarget, 3);
      expect(back.discoveredIndices, {1, 2});
    });

    test('no lock saves as none', () {
      const state = CosmicFogState(worldSeed: 7, discoveredIndices: {});
      final back = CosmicFogState.deserialise(state.serialise());
      expect(back.starDustScanTarget, isNull);
      expect(back.planetScanTarget, isNull);
    });

    test('a save from before the locks still loads', () {
      final back = CosmicFogState.deserialise('7|1,2|10.0,20.0|3,1|4|');
      expect(back.discoveredIndices, {1, 2});
      expect(back.shipX, 10);
      expect(back.starDustScanTarget, isNull);
      expect(back.planetScanTarget, isNull);
    });
  });

  testWidgets(
    'the market leaves out the party and the garrison, and pays shards into '
    'the hold',
    (tester) async {
      tester.view.physicalSize = const Size(475 * 3, 751 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final db = AlchemonsDatabase(NativeDatabase.memory());
      late CreatureCatalog catalog;
      await tester.runAsync(() async {
        final json =
            jsonDecode(
                  File(
                    'assets/data/alchemons_creatures.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        catalog = CreatureCatalog.fromList([
          for (final c in json['creatures'] as List)
            Creature.fromJson(c as Map<String, dynamic>),
        ]);
        for (final id in const ['sell', 'party', 'home']) {
          await db.creatureDao.insertInstance(
            instanceId: id,
            baseId: 'HOR01',
            level: 5,
            source: 'planet_summon',
          );
        }
        await db.settingsDao.setCosmicPartySlotInstance(0, 'party');
        await db.settingsDao.setCosmicGarrisonSlotInstance(0, 'home');
      });

      var paidShards = 0;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AlchemonsDatabase>.value(value: db),
            Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
            Provider<CreatureCatalog>.value(value: catalog),
          ],
          child: MaterialApp(
            home: CosmicSellSheet(
              carriedShards: 0,
              shardCapacity: 100000,
              addShards: (n) => paidShards += n,
            ),
          ),
        ),
      );
      Future<void> settle([int frames = 10]) async {
        for (var i = 0; i < frames; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await settle();
      expect(find.text('1 OF 1'), findsOneWidget);

      await tester.tap(find.text('PAY IN SHARDS'));
      await settle(2);
      await tester.tap(find.byKey(const ValueKey('station.sell')));
      await settle(6);
      await tester.tap(find.text('SELL').last);
      await settle(10);

      expect(paidShards, greaterThan(0));
      final left = await tester.runAsync(
        () => db.creatureDao.getAllInstances(),
      );
      expect(left!.map((i) => i.instanceId).toSet(), {'party', 'home'});

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
      await tester.runAsync(db.close);
    },
  );
}
