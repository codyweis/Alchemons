import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FamilyMasteryCatalog', () {
    test('defines eight valid trees, 16 paths, and 64 nodes', () {
      // Every family has two paths (2026-10-29): two where every node changes
      // how the attack behaves beat three where one is filler.
      expect(FamilyMasteryCatalog.validate(), isEmpty);
      expect(kFamilyMasteryTrees, hasLength(8));
      expect(kFamilyMasteryTrees.expand((tree) => tree.paths), hasLength(16));
      expect(
        kFamilyMasteryTrees
            .expand((tree) => tree.paths)
            .expand((path) => path.nodes),
        hasLength(64),
      );
      expect(
        FamilyMasteryCatalog.treeFor(CreatureFamily.mystic).paths,
        hasLength(2),
      );
    });

    test('prices every path 25 / 75 / 150 / 300 mastery', () {
      for (final tree in kFamilyMasteryTrees) {
        for (final path in tree.paths) {
          expect(
            path.nodes.map((node) => node.cost),
            orderedEquals([25, 75, 150, 300]),
            reason: path.id,
          );
          expect(path.nodes.fold<int>(0, (sum, node) => sum + node.cost), 550);
        }
      }
    });

    test('the validator holds every tier to its mastery price', () {
      FamilyMasteryTreeDef repriced(int tierIndex, int cost) {
        final tree = FamilyMasteryCatalog.treeFor(CreatureFamily.mane);
        return FamilyMasteryTreeDef(
          family: tree.family,
          chassis: tree.chassis,
          paths: [
            for (final path in tree.paths)
              FamilyMasteryPathDef(
                id: path.id,
                name: path.name,
                role: path.role,
                nodes: [
                  for (var i = 0; i < path.nodes.length; i++)
                    i == tierIndex && path.id == 'mane.resonance'
                        ? FamilyMasteryNodeDef(
                            id: path.nodes[i].id,
                            name: path.nodes[i].name,
                            description: path.nodes[i].description,
                            tier: path.nodes[i].tier,
                            cost: cost,
                            effectId: path.nodes[i].effectId,
                          )
                        : path.nodes[i],
                ],
              ),
          ],
        );
      }

      List<String> costErrors(FamilyMasteryTreeDef tree) =>
          FamilyMasteryCatalog.validate([
            tree,
          ]).where((error) => error.contains('must cost')).toList();

      expect(costErrors(repriced(0, 25)), isEmpty);
      // The old silver price, and the old 10 gold capstone, are both wrong
      // now.
      expect(costErrors(repriced(0, 1000)), [
        'mane.resonance.measured_cuts must cost 25 mastery',
      ]);
      expect(costErrors(repriced(3, 10)), [
        'mane.resonance.encore must cost 300 mastery',
      ]);
    });

    test('drops unknown and non-sequential saved nodes', () {
      final sanitized =
          FamilyMasteryCatalog.sanitizePurchases(CreatureFamily.mane, const {
            'mane.resonance.measured_cuts',
            'mane.resonance.tempest_ring',
            'mane.limitless.hunters_arc',
            'retired.node',
          });
      expect(sanitized, {'mane.resonance.measured_cuts'});
    });
  });

  group('mastery points for a run', () {
    test('each cleared wave is worth one more for every ten waves in', () {
      expect(familyMasteryPointsForWave(0), 0);
      expect(familyMasteryPointsForWave(1), 1);
      expect(familyMasteryPointsForWave(9), 1);
      expect(familyMasteryPointsForWave(10), 2);
      expect(familyMasteryPointsForWave(41), 5);
    });

    test('a run earns every cleared wave added up', () {
      expect(familyMasteryPointsForRun(0), 0);
      expect(familyMasteryPointsForRun(-3), 0);
      expect(familyMasteryPointsForRun(1), 1);
      expect(familyMasteryPointsForRun(10), 11);
      expect(familyMasteryPointsForRun(19), 29);
      expect(familyMasteryPointsForRun(39), 99);
      expect(familyMasteryPointsForRun(59), 209);
      expect(familyMasteryPointsForRun(79), 359);
    });

    test('the wave a run is lost on is not cleared', () {
      expect(survivalWavesCleared(currentWave: 41, intermission: false), 40);
      // Lost in the pause after a wave, that wave was cleared.
      expect(survivalWavesCleared(currentWave: 41, intermission: true), 41);
      expect(survivalWavesCleared(currentWave: 1, intermission: false), 0);
      expect(survivalWavesCleared(currentWave: 0, intermission: false), 0);
    });
  });

  group('what each creature earns its family', () {
    // 39 waves cleared: a base of 99, paid at half — 49.5.
    const waves = 39;
    FamilyMasteryRunCreature out(
      CreatureFamily family, {
      double damage = 0,
      int kills = 0,
      double healing = 0,
    }) => FamilyMasteryRunCreature(
      family: family,
      deployed: true,
      damageDealt: damage,
      kills: kills,
      healingDone: healing,
    );
    FamilyMasteryRunCreature reserve(CreatureFamily family) =>
        FamilyMasteryRunCreature(family: family, deployed: false);

    test('an average deployed creature earns half a base, and so does one '
        'alone', () {
      final team = [
        for (final f in const [
          CreatureFamily.horn,
          CreatureFamily.pip,
          CreatureFamily.mane,
          CreatureFamily.let,
        ])
          out(f, damage: 1000, kills: 40),
      ];
      expect(familyMasteryCreatureAwards(team, waves), [50, 50, 50, 50]);
      expect(familyMasteryCreatureAwards([out(CreatureFamily.horn)], waves), [
        (familyMasteryPointsForRun(waves) * kFamilyMasteryRate + 1e-9).round(),
      ]);
      expect(
        familyMasteryCreatureAwards([
          out(CreatureFamily.horn, damage: 5000, kills: 300),
        ], waves),
        [50],
      );
    });

    test('a family is paid what its creatures earned between them', () {
      final team = [
        out(CreatureFamily.horn, damage: 500, kills: 20),
        out(CreatureFamily.pip, damage: 500, kills: 20),
        out(CreatureFamily.horn, damage: 500, kills: 20),
      ];
      final awards = familyMasteryCreatureAwards(team, waves);
      expect(awards, [50, 50, 50]);
      final sums = familyMasteryFamilySums(team, awards);
      expect(sums, {CreatureFamily.horn: 100, CreatureFamily.pip: 50});
      // In the order the party first fields each, for the results.
      expect(sums.keys, [CreatureFamily.horn, CreatureFamily.pip]);
    });

    test('a creature kept in reserve all run earns an eighth of a base, and '
        'takes nothing from the rest', () {
      final team = [
        out(CreatureFamily.horn, damage: 300, kills: 12),
        out(CreatureFamily.pip, damage: 100, kills: 4),
        reserve(CreatureFamily.kin),
      ];
      final awards = familyMasteryCreatureAwards(team, waves);
      // 0.125 x 49.5 = 6.1875.
      expect(awards[2], 6);
      // The two that went out share as a team of two: 0.75 and 0.25.
      expect(awards[0], (24.75 + 24.75 * 2 * 0.75).round());
      expect(awards[1], (24.75 + 24.75 * 2 * 0.25).round());
      expect(
        familyMasteryCreatureAwards([reserve(CreatureFamily.kin)], waves),
        [6],
      );
    });

    test('healing is its own axis, so a healer is paid for healing', () {
      final team = [
        out(CreatureFamily.horn, damage: 900, kills: 90),
        out(CreatureFamily.kin, damage: 100, kills: 10, healing: 500),
      ];
      // Horn: (0.9 + 0.9 + 0) / 3 = 0.6 of the team; Kin: (0.1 + 0.1 + 1)
      // / 3 = 0.4. Without the healing axis the Kin would hold 0.1.
      expect(familyMasteryCreatureAwards(team, waves), [
        (24.75 + 49.5 * 0.6 + 1e-9).round(), // 54.45 -> 54
        (24.75 + 49.5 * 0.4 + 1e-9).round(), // 44.55 -> 45
      ]);
      expect(
        familyMasteryCreatureAwards([
          out(CreatureFamily.horn, damage: 900, kills: 90),
          out(CreatureFamily.kin, damage: 100, kills: 10),
        ], waves)[1],
        (24.75 + 49.5 * 0.1).round(),
      );
    });

    test('a carry is capped at one and a half bases', () {
      final team = [
        out(CreatureFamily.mane, damage: 10000, kills: 500),
        for (var i = 0; i < 4; i++) out(CreatureFamily.pip),
      ];
      final awards = familyMasteryCreatureAwards(team, waves);
      // Uncapped it would be 24.75 + 24.75 x 5 = 148.5; the cap is 74.25.
      expect(awards.first, 74);
      expect(awards.skip(1), everyElement(25));
    });

    test('points round to whole numbers; a deployed creature earns at least '
        'one, and a run that cleared nothing pays nothing', () {
      // 19 waves: a base of 29, paid 14.5. A reserve's 1.8125 rounds up.
      expect(
        familyMasteryCreatureAwards([
          out(CreatureFamily.horn),
          out(CreatureFamily.pip),
          out(CreatureFamily.let),
          reserve(CreatureFamily.kin),
        ], 19),
        [15, 15, 15, 2],
      );
      // One wave: a base of 1, paid a half. A reserve's eighth is nothing;
      // anyone who went out has at least the point.
      expect(
        familyMasteryCreatureAwards([
          out(CreatureFamily.horn, damage: 10, kills: 1),
          out(CreatureFamily.pip),
          out(CreatureFamily.let),
          reserve(CreatureFamily.kin),
        ], 1),
        [1, 1, 1, 0],
      );
      final none = [out(CreatureFamily.horn), reserve(CreatureFamily.pip)];
      expect(familyMasteryCreatureAwards(none, 0), [0, 0]);
      expect(
        familyMasteryFamilySums(none, familyMasteryCreatureAwards(none, 0)),
        isEmpty,
      );
    });

    test('the same run always pays the same', () {
      final team = [
        out(CreatureFamily.horn, damage: 731.4, kills: 17, healing: 3),
        out(CreatureFamily.kin, damage: 12.2, kills: 1, healing: 411.9),
        reserve(CreatureFamily.pip),
      ];
      final first = familyMasteryCreatureAwards(team, 47);
      for (var i = 0; i < 5; i++) {
        expect(familyMasteryCreatureAwards(team, 47), first);
      }
    });

    test('the next node is the equipped path\'s first unowned, then any', () {
      final horn = FamilyMasteryCatalog.treeFor(CreatureFamily.horn);
      expect(
        familyMasteryNextNode(CreatureFamily.horn, owned: const {}),
        horn.paths.first.nodes.first,
      );
      final path = horn.paths[1];
      expect(
        familyMasteryNextNode(
          CreatureFamily.horn,
          owned: {path.nodes.first.id},
          selectedPathId: path.id,
        ),
        path.nodes[1],
      );
      expect(
        familyMasteryNextNode(
          CreatureFamily.horn,
          owned: {
            for (final p in horn.paths)
              for (final n in p.nodes) n.id,
          },
        ),
        isNull,
      );
    });
  });

  group('FamilyMasteryService', () {
    late AlchemonsDatabase db;
    late FamilyMasteryService service;

    setUp(() async {
      db = AlchemonsDatabase(NativeDatabase.memory());
      service = FamilyMasteryService(db);
      await db
          .into(db.creatureInstances)
          .insert(
            CreatureInstancesCompanion.insert(
              instanceId: 'mane-a',
              baseId: 'MAN01',
            ),
          );
      await db
          .into(db.creatureInstances)
          .insert(
            CreatureInstancesCompanion.insert(
              instanceId: 'mane-b',
              baseId: 'MAN02',
            ),
          );
      await db
          .into(db.creatureInstances)
          .insert(
            CreatureInstancesCompanion.insert(
              instanceId: 'pip-a',
              baseId: 'PIP01',
            ),
          );
      await db.settingsDao.setSetting('wallet_silver', '100000');
      await db.settingsDao.setSetting('wallet_gold', '100');
      await service.load();
      await service.addPoints(const {
        CreatureFamily.mane: 1000,
        CreatureFamily.pip: 1000,
      });
    });

    tearDown(() async {
      service.dispose();
      await db.close();
    });

    test(
      'first purchase spends the family\'s points and equips that path',
      () async {
        final result = await service.purchaseNode(
          family: CreatureFamily.mane,
          nodeId: 'mane.resonance.measured_cuts',
        );

        expect(result, FamilyMasteryPurchaseResult.purchased);
        expect(service.pointsFor(CreatureFamily.mane), 975);
        // Nothing else pays: not another family, not the wallet.
        expect(service.pointsFor(CreatureFamily.pip), 1000);
        expect(service.lifetimePointsFor(CreatureFamily.mane), 1000);
        expect(await db.currencyDao.getSilverBalance(), 100000);
        expect(await db.currencyDao.getGoldBalance(), 100);
        expect(
          service.purchasedNodes(CreatureFamily.mane),
          contains('mane.resonance.measured_cuts'),
        );
        expect(
          service.selectedPathForFamily(CreatureFamily.mane),
          'mane.resonance',
        );
      },
    );

    test('rejects skipped prerequisites without spending points', () async {
      final result = await service.purchaseNode(
        family: CreatureFamily.mane,
        nodeId: 'mane.resonance.tempest_ring',
      );

      expect(result, FamilyMasteryPurchaseResult.prerequisiteMissing);
      expect(service.pointsFor(CreatureFamily.mane), 1000);
      expect(service.purchasedNodes(CreatureFamily.mane), isEmpty);
    });

    test('too few points leaves progress and balance untouched', () async {
      // Plenty of silver and gold, and points in another family, buy
      // nothing: only Kin's own points buy Kin's tree.
      await service.addPoints(const {CreatureFamily.kin: 24});

      final result = await service.purchaseNode(
        family: CreatureFamily.kin,
        nodeId: 'kin.conduction.live_current',
      );

      expect(result, FamilyMasteryPurchaseResult.insufficientPoints);
      expect(service.pointsFor(CreatureFamily.kin), 24);
      expect(await db.familyMasteryDao.getFamilyMastery('kin'), isNull);
      expect(await db.currencyDao.getSilverBalance(), 100000);
    });

    test('complete path costs 550 of the family\'s points', () async {
      await db.settingsDao.deleteSetting(FamilyMasteryService.pointsKey);
      await service.load();
      await service.addPoints(const {CreatureFamily.mane: 550});
      final path = FamilyMasteryCatalog.pathFor(
        CreatureFamily.mane,
        'mane.resonance',
      )!;

      for (final node in path.nodes) {
        expect(
          await service.purchaseNode(
            family: CreatureFamily.mane,
            nodeId: node.id,
          ),
          FamilyMasteryPurchaseResult.purchased,
        );
      }

      expect(service.pointsFor(CreatureFamily.mane), 0);
      expect(service.lifetimePointsFor(CreatureFamily.mane), 550);
      expect(
        service.purchasedNodes(CreatureFamily.mane),
        containsAll(path.nodes.map((node) => node.id)),
      );
    });

    test('overlapping purchases grant and charge exactly once', () async {
      final results = await Future.wait([
        service.purchaseNode(
          family: CreatureFamily.mane,
          nodeId: 'mane.resonance.measured_cuts',
        ),
        service.purchaseNode(
          family: CreatureFamily.mane,
          nodeId: 'mane.resonance.measured_cuts',
        ),
      ]);

      expect(
        results.where(
          (result) => result == FamilyMasteryPurchaseResult.purchased,
        ),
        hasLength(1),
      );
      expect(
        results.where(
          (result) => result == FamilyMasteryPurchaseResult.alreadyOwned,
        ),
        hasLength(1),
      );
      expect(service.pointsFor(CreatureFamily.mane), 975);
    });

    test('one family selection applies to every member in a run', () async {
      await service.purchaseNode(
        family: CreatureFamily.mane,
        nodeId: 'mane.resonance.measured_cuts',
      );
      await service.purchaseNode(
        family: CreatureFamily.mane,
        nodeId: 'mane.limitless.far_throw',
      );

      expect(
        await service.selectPath(
          family: CreatureFamily.mane,
          pathId: 'mane.limitless',
        ),
        FamilyMasteryEquipResult.equipped,
      );

      final snapshot = await service.buildSnapshot(const [
        FamilyMasteryPartyMemberRef(
          slotIndex: 0,
          instanceId: 'mane-a',
          family: CreatureFamily.mane,
        ),
        FamilyMasteryPartyMemberRef(
          slotIndex: 1,
          instanceId: 'mane-b',
          family: CreatureFamily.mane,
        ),
      ]);

      expect(snapshot.forSlot(0)?.pathId, 'mane.limitless');
      expect(snapshot.forSlot(1)?.pathId, 'mane.limitless');
      expect(snapshot.forSlot(0)?.activeNodeIds, {'mane.limitless.far_throw'});
      expect(snapshot.forSlot(1)?.activeNodeIds, {'mane.limitless.far_throw'});
    });

    test('rejects a node from the wrong family without charging', () async {
      final result = await service.purchaseNode(
        family: CreatureFamily.pip,
        nodeId: 'mane.resonance.measured_cuts',
      );

      expect(result, FamilyMasteryPurchaseResult.wrongFamily);
      expect(service.pointsFor(CreatureFamily.mane), 1000);
      expect(service.pointsFor(CreatureFamily.pip), 1000);
    });

    test('selects and clears a family path without charging', () async {
      await service.purchaseNode(
        family: CreatureFamily.mane,
        nodeId: 'mane.resonance.measured_cuts',
      );
      final pointsAfterPurchase = service.pointsFor(CreatureFamily.mane);

      expect(
        await service.selectPath(
          family: CreatureFamily.mane,
          pathId: 'mane.resonance',
        ),
        FamilyMasteryEquipResult.equipped,
      );
      expect(
        service.selectedPathForFamily(CreatureFamily.mane),
        'mane.resonance',
      );
      expect(
        await service.selectPath(family: CreatureFamily.mane, pathId: null),
        FamilyMasteryEquipResult.cleared,
      );
      expect(service.selectedPathForFamily(CreatureFamily.mane), isNull);
      expect(service.pointsFor(CreatureFamily.mane), pointsAfterPurchase);
    });

    test(
      'persists purchases and equipped paths across service reloads',
      () async {
        await service.purchaseNode(
          family: CreatureFamily.mane,
          nodeId: 'mane.resonance.measured_cuts',
        );
        final restored = FamilyMasteryService(db);
        addTearDown(restored.dispose);

        await restored.load();

        expect(restored.purchasedNodes(CreatureFamily.mane), {
          'mane.resonance.measured_cuts',
        });
        expect(
          restored.selectedPathForFamily(CreatureFamily.mane),
          'mane.resonance',
        );
        expect(restored.pointsFor(CreatureFamily.mane), 975);
        expect(restored.lifetimePointsFor(CreatureFamily.mane), 1000);
      },
    );

    test('a run pays each family its creatures\' sum, and keeps it', () async {
      // Two Horns and a Mane, all out and level: each earns 50.
      const team = [
        FamilyMasteryRunCreature(
          family: CreatureFamily.horn,
          deployed: true,
          damageDealt: 400,
          kills: 10,
        ),
        FamilyMasteryRunCreature(
          family: CreatureFamily.horn,
          deployed: true,
          damageDealt: 400,
          kills: 10,
        ),
        FamilyMasteryRunCreature(
          family: CreatureFamily.mane,
          deployed: true,
          damageDealt: 400,
          kills: 10,
        ),
      ];
      final earned = await service.awardRun(
        familyMasteryFamilySums(team, familyMasteryCreatureAwards(team, 39)),
      );

      expect(earned, {CreatureFamily.horn: 100, CreatureFamily.mane: 50});
      expect(service.pointsFor(CreatureFamily.horn), 100);
      expect(service.lifetimePointsFor(CreatureFamily.horn), 100);
      expect(service.pointsFor(CreatureFamily.mane), 1050);
      // A family that was not fielded earns nothing.
      expect(service.pointsFor(CreatureFamily.kin), 0);

      // Spending lowers the balance, never what was earned.
      await service.purchaseNode(
        family: CreatureFamily.horn,
        nodeId: 'horn.bulwark.ironhead',
      );
      expect(service.pointsFor(CreatureFamily.horn), 75);
      expect(service.lifetimePointsFor(CreatureFamily.horn), 100);

      final stored = jsonDecode(
        (await db.settingsDao.getSetting(FamilyMasteryService.pointsKey))!,
      );
      expect(stored['horn'], {'balance': 75, 'earned': 100});
    });

    test('a run that cleared nothing pays nothing', () async {
      final earned = await service.awardRun(const {
        CreatureFamily.horn: 0,
        CreatureFamily.kin: -3,
      });
      expect(earned, isEmpty);
      expect(service.pointsFor(CreatureFamily.horn), 0);
      expect(service.pointsFor(CreatureFamily.kin), 0);
    });

    test('nodes bought with silver and gold stay owned, at 0 points', () async {
      // A save from before points: a whole Horn path paid for in coin, and
      // no points key at all.
      await db.settingsDao.deleteSetting(FamilyMasteryService.pointsKey);
      final path = FamilyMasteryCatalog.pathFor(
        CreatureFamily.horn,
        'horn.bastion',
      )!;
      await db.familyMasteryDao.saveFamilyMastery(
        familyId: 'horn',
        purchasedNodeIdsJson: jsonEncode([
          for (final node in path.nodes) node.id,
        ]),
        selectedPathId: path.id,
        updatedAtUtcMs: 1,
      );

      final restored = FamilyMasteryService(db);
      addTearDown(restored.dispose);
      await restored.load();

      expect(
        restored.purchasedNodes(CreatureFamily.horn),
        path.nodes.map((node) => node.id).toSet(),
      );
      expect(restored.selectedPathForFamily(CreatureFamily.horn), path.id);
      expect(restored.pointsFor(CreatureFamily.horn), 0);
      // Nothing was refunded and nothing charged.
      expect(await db.currencyDao.getSilverBalance(), 100000);
      expect(await db.currencyDao.getGoldBalance(), 100);
    });

    test('an unreadable points setting counts as nothing earned', () {
      expect(decodeFamilyMasteryPoints(null), isEmpty);
      expect(decodeFamilyMasteryPoints('not json'), isEmpty);
      expect(decodeFamilyMasteryPoints('[1, 2]'), isEmpty);
      expect(
        decodeFamilyMasteryPoints(
          '{"horn": {"balance": 40, "earned": -5}, "dragon": {"balance": 9}}',
        ),
        {
          CreatureFamily.horn: const FamilyMasteryPoints(
            balance: 40,
            earned: 0,
          ),
        },
      );
    });
  });
}
