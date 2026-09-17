import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Developer tools hand over the whole tree, as a read-time override. The
/// point of the override being read-time is that turning the switch off gives
/// the account back exactly what it paid for — so these tests care as much
/// about what is *not* written as about what is unlocked.
void main() {
  late AlchemonsDatabase db;
  late FamilyMasteryService mastery;

  setUp(() async {
    DebugSettingsService.enabledNotifier.value = false;
    db = AlchemonsDatabase(NativeDatabase.memory());
    mastery = FamilyMasteryService(db);
    await mastery.load();
  });

  tearDown(() async {
    DebugSettingsService.enabledNotifier.value = false;
    await db.close();
  });

  int nodesIn(CreatureFamily family) => FamilyMasteryCatalog.treeFor(
    family,
  ).paths.expand((path) => path.nodes).length;

  test('with the switch off, nothing is owned', () {
    expect(mastery.purchasedNodes(CreatureFamily.mane), isEmpty);
    expect(mastery.isNodePurchased('mane.assault.honed_pair'), isFalse);
  });

  test('with the switch on, every node of every family is owned', () {
    DebugSettingsService.enabledNotifier.value = true;
    for (final tree in kFamilyMasteryTrees) {
      expect(
        mastery.purchasedNodes(tree.family),
        hasLength(nodesIn(tree.family)),
        reason: '${tree.family.name} did not unlock',
      );
      for (final path in tree.paths) {
        for (final node in path.nodes) {
          expect(mastery.isNodePurchased(node.id), isTrue);
        }
      }
    }
  });

  test('a path can be equipped without buying into it', () async {
    DebugSettingsService.enabledNotifier.value = true;
    expect(
      await mastery.selectPath(
        family: CreatureFamily.mane,
        pathId: 'mane.limitless',
      ),
      FamilyMasteryEquipResult.equipped,
    );
    expect(
      mastery.selectedPathForFamily(CreatureFamily.mane),
      'mane.limitless',
    );
  });

  test('a run gets the whole selected path, not an empty one', () async {
    DebugSettingsService.enabledNotifier.value = true;
    await mastery.selectPath(
      family: CreatureFamily.mane,
      pathId: 'mane.limitless',
    );
    final snapshot = mastery.snapshotForParty(const [
      FamilyMasteryPartyMemberRef(
        slotIndex: 0,
        instanceId: 'a',
        family: CreatureFamily.mane,
      ),
    ]);
    final equipped = snapshot.forSlot(0)!;
    expect(equipped.pathId, 'mane.limitless');
    expect(
      equipped.activeNodeIds,
      hasLength(4),
      reason: 'An unlocked path should arrive in a run complete.',
    );
  });

  test('choosing is still required — unlocking is not equipping', () {
    DebugSettingsService.enabledNotifier.value = true;
    final snapshot = mastery.snapshotForParty(const [
      FamilyMasteryPartyMemberRef(
        slotIndex: 0,
        instanceId: 'a',
        family: CreatureFamily.mane,
      ),
    ]);
    expect(
      snapshot.forSlot(0),
      isNull,
      reason: 'One path at a time is the design; the override does not pick.',
    );
  });

  test(
    'the override writes nothing, so switching off gives back the truth',
    () async {
      DebugSettingsService.enabledNotifier.value = true;
      expect(mastery.purchasedNodes(CreatureFamily.mane), isNotEmpty);
      await mastery.selectPath(
        family: CreatureFamily.mane,
        pathId: 'mane.limitless',
      );

      DebugSettingsService.enabledNotifier.value = false;
      expect(
        mastery.purchasedNodes(CreatureFamily.mane),
        isEmpty,
        reason: 'Developer tools must not leave an account permanently rich.',
      );

      // And a fresh service reading the same database agrees.
      final reopened = FamilyMasteryService(db);
      await reopened.load();
      expect(reopened.purchasedNodes(CreatureFamily.mane), isEmpty);
    },
  );
}
