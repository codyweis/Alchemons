// Paths were cut from the mastery trees and nodes rewritten (2026-10-29).
// A save that bought into one gets its points back on load, the purchase is
// dropped, and a path that is no longer there is no longer worn.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AlchemonsDatabase db;

  setUp(() => db = AlchemonsDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seed({
    required String family,
    required List<String> nodes,
    required String? path,
    required int balance,
    required int earned,
  }) async {
    await db.familyMasteryDao.saveFamilyMastery(
      familyId: family,
      purchasedNodeIdsJson: '[${nodes.map((n) => '"$n"').join(',')}]',
      selectedPathId: path,
      updatedAtUtcMs: 1,
    );
    final points = decodeFamilyMasteryPoints(
      await db.settingsDao.getSetting(FamilyMasteryService.pointsKey),
    );
    await db.settingsDao.setSetting(
      FamilyMasteryService.pointsKey,
      encodeFamilyMasteryPoints({
        ...points,
        creatureFamilyFromStorage(family)!: FamilyMasteryPoints(
          balance: balance,
          earned: earned,
        ),
      }),
    );
  }

  test('a cut path is paid back and no longer worn', () async {
    final farThrow = FamilyMasteryCatalog.pathFor(
      CreatureFamily.mane,
      'mane.limitless',
    )!.nodes.first;
    // 25 + 75 spent on the cut Twin Fang, 25 on Limitless.
    await seed(
      family: 'mane',
      nodes: ['mane.assault.honed_pair', 'mane.assault.crosscut', farThrow.id],
      path: 'mane.assault',
      balance: 0,
      earned: 125,
    );

    final service = FamilyMasteryService(db);
    await service.load();

    expect(service.purchasedNodes(CreatureFamily.mane), {farThrow.id});
    expect(service.pointsFor(CreatureFamily.mane), 100);
    expect(service.lifetimePointsFor(CreatureFamily.mane), 125);
    expect(service.selectedPathForFamily(CreatureFamily.mane), isNull);

    // Settled once: a second load finds nothing to pay back.
    final again = FamilyMasteryService(db);
    await again.load();
    expect(again.pointsFor(CreatureFamily.mane), 100);
    final row = await db.familyMasteryDao.getFamilyMastery('mane');
    expect(row?.purchasedNodeIdsJson, contains(farThrow.id));
    expect(row?.purchasedNodeIdsJson, isNot(contains('mane.assault')));
    expect(row?.selectedPathId, isNull);
  });

  test('a tier whose node beneath it went is paid back too', () async {
    final rhythm = FamilyMasteryCatalog.pathFor(
      CreatureFamily.mane,
      'mane.resonance',
    )!;
    // Bought Measured Cuts and the old tier-2 Tempest Ring; Tempest Ring
    // now sits at tier 3, above a Crosscut not yet bought.
    await seed(
      family: 'mane',
      nodes: [rhythm.nodes[0].id, 'mane.resonance.tempest_ring'],
      path: rhythm.id,
      balance: 0,
      earned: 100,
    );

    final service = FamilyMasteryService(db);
    await service.load();

    expect(service.purchasedNodes(CreatureFamily.mane), {rhythm.nodes[0].id});
    expect(service.pointsFor(CreatureFamily.mane), 75);
    expect(service.selectedPathForFamily(CreatureFamily.mane), rhythm.id);
  });

  test('a save with nothing dropped is left alone', () async {
    final bulwark = FamilyMasteryCatalog.pathFor(
      CreatureFamily.horn,
      'horn.bulwark',
    )!;
    // Balance below earned − held (debug grants, say): not touched, because
    // nothing was dropped.
    await seed(
      family: 'horn',
      nodes: [bulwark.nodes.first.id],
      path: bulwark.id,
      balance: 10,
      earned: 500,
    );

    final service = FamilyMasteryService(db);
    await service.load();

    expect(service.purchasedNodes(CreatureFamily.horn), {
      bulwark.nodes.first.id,
    });
    expect(service.pointsFor(CreatureFamily.horn), 10);
    expect(service.selectedPathForFamily(CreatureFamily.horn), bulwark.id);
  });
}
