import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FamilyMasteryCatalog', () {
    test('defines eight valid trees, 24 paths, and 96 nodes', () {
      expect(FamilyMasteryCatalog.validate(), isEmpty);
      expect(kFamilyMasteryTrees, hasLength(8));
      expect(kFamilyMasteryTrees.expand((tree) => tree.paths), hasLength(24));
      expect(
        kFamilyMasteryTrees
            .expand((tree) => tree.paths)
            .expand((path) => path.nodes),
        hasLength(96),
      );
    });

    test('uses the agreed sequential silver and gold prices', () {
      for (final tree in kFamilyMasteryTrees) {
        for (final path in tree.paths) {
          expect(
            path.nodes.map((node) => node.cost),
            orderedEquals([1000, 5000, 10000, 10]),
          );
          expect(
            path.nodes.map((node) => node.currency),
            orderedEquals([
              FamilyMasteryCurrency.silver,
              FamilyMasteryCurrency.silver,
              FamilyMasteryCurrency.silver,
              FamilyMasteryCurrency.gold,
            ]),
          );
        }
      }
    });

    test('drops unknown and non-sequential saved nodes', () {
      final sanitized =
          FamilyMasteryCatalog.sanitizePurchases(CreatureFamily.mane, const {
            'mane.assault.honed_pair',
            'mane.assault.predator_step',
            'mane.control.rending_wake',
            'retired.node',
          });
      expect(sanitized, {'mane.assault.honed_pair'});
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
    });

    tearDown(() async {
      service.dispose();
      await db.close();
    });

    test('first purchase charges silver and equips that path', () async {
      final result = await service.purchaseNode(
        family: CreatureFamily.mane,
        nodeId: 'mane.assault.honed_pair',
      );

      expect(result, FamilyMasteryPurchaseResult.purchased);
      expect(await db.currencyDao.getSilverBalance(), 99000);
      expect(
        service.purchasedNodes(CreatureFamily.mane),
        contains('mane.assault.honed_pair'),
      );
      expect(
        service.selectedPathForFamily(CreatureFamily.mane),
        'mane.assault',
      );
    });

    test('rejects skipped prerequisites without charging currency', () async {
      final result = await service.purchaseNode(
        family: CreatureFamily.mane,
        nodeId: 'mane.assault.predator_step',
      );

      expect(result, FamilyMasteryPurchaseResult.prerequisiteMissing);
      expect(await db.currencyDao.getSilverBalance(), 100000);
      expect(service.purchasedNodes(CreatureFamily.mane), isEmpty);
    });

    test('insufficient silver leaves progress and balance untouched', () async {
      await db.settingsDao.setSetting('wallet_silver', '999');

      final result = await service.purchaseNode(
        family: CreatureFamily.mane,
        nodeId: 'mane.assault.honed_pair',
      );

      expect(result, FamilyMasteryPurchaseResult.insufficientSilver);
      expect(await db.currencyDao.getSilverBalance(), 999);
      expect(await db.familyMasteryDao.getFamilyMastery('mane'), isNull);
    });

    test('complete path costs 16000 silver and 10 gold', () async {
      await db.settingsDao.setSetting('wallet_silver', '16000');
      await db.settingsDao.setSetting('wallet_gold', '10');
      final path = FamilyMasteryCatalog.pathFor(
        CreatureFamily.mane,
        'mane.assault',
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

      expect(await db.currencyDao.getSilverBalance(), 0);
      expect(await db.currencyDao.getGoldBalance(), 0);
      expect(
        service.purchasedNodes(CreatureFamily.mane),
        containsAll(path.nodes.map((node) => node.id)),
      );
    });

    test('overlapping purchases grant and charge exactly once', () async {
      final results = await Future.wait([
        service.purchaseNode(
          family: CreatureFamily.mane,
          nodeId: 'mane.assault.honed_pair',
        ),
        service.purchaseNode(
          family: CreatureFamily.mane,
          nodeId: 'mane.assault.honed_pair',
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
      expect(await db.currencyDao.getSilverBalance(), 99000);
    });

    test('one family selection applies to every member in a run', () async {
      await service.purchaseNode(
        family: CreatureFamily.mane,
        nodeId: 'mane.assault.honed_pair',
      );
      await service.purchaseNode(
        family: CreatureFamily.mane,
        nodeId: 'mane.control.sweeping_claws',
      );

      expect(
        await service.selectPath(
          family: CreatureFamily.mane,
          pathId: 'mane.control',
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

      expect(snapshot.forSlot(0)?.pathId, 'mane.control');
      expect(snapshot.forSlot(1)?.pathId, 'mane.control');
      expect(snapshot.forSlot(0)?.activeNodeIds, {
        'mane.control.sweeping_claws',
      });
      expect(snapshot.forSlot(1)?.activeNodeIds, {
        'mane.control.sweeping_claws',
      });
    });

    test('rejects a node from the wrong family without charging', () async {
      final result = await service.purchaseNode(
        family: CreatureFamily.pip,
        nodeId: 'mane.assault.honed_pair',
      );

      expect(result, FamilyMasteryPurchaseResult.wrongFamily);
      expect(await db.currencyDao.getSilverBalance(), 100000);
    });

    test('selects and clears a family path without charging', () async {
      await service.purchaseNode(
        family: CreatureFamily.mane,
        nodeId: 'mane.assault.honed_pair',
      );
      final silverAfterPurchase = await db.currencyDao.getSilverBalance();

      expect(
        await service.selectPath(
          family: CreatureFamily.mane,
          pathId: 'mane.assault',
        ),
        FamilyMasteryEquipResult.equipped,
      );
      expect(
        service.selectedPathForFamily(CreatureFamily.mane),
        'mane.assault',
      );
      expect(
        await service.selectPath(family: CreatureFamily.mane, pathId: null),
        FamilyMasteryEquipResult.cleared,
      );
      expect(service.selectedPathForFamily(CreatureFamily.mane), isNull);
      expect(await db.currencyDao.getSilverBalance(), silverAfterPurchase);
    });

    test(
      'persists purchases and equipped paths across service reloads',
      () async {
        await service.purchaseNode(
          family: CreatureFamily.mane,
          nodeId: 'mane.assault.honed_pair',
        );
        final restored = FamilyMasteryService(db);
        addTearDown(restored.dispose);

        await restored.load();

        expect(restored.purchasedNodes(CreatureFamily.mane), {
          'mane.assault.honed_pair',
        });
        expect(
          restored.selectedPathForFamily(CreatureFamily.mane),
          'mane.assault',
        );
      },
    );
  });
}
