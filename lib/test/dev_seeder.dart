// lib/dev/dev_seeder.dart
import 'package:uuid/uuid.dart';
import 'package:alchemons/database/alchemons_db.dart';

class DevSeeder {
  final AlchemonsDatabase db;
  final _uuid = const Uuid();

  DevSeeder(this.db);

  /// Creates 2 test eggs and places them into slot 0 and 1.
  /// Each will hatch in a few seconds.
  Future<void> createTwoTestEggs() async {
    // pick any two valid species ids from your catalog
    // (swap these to any you like, e.g. "CR001", "CR014", etc.)
    const s1 = 'WNG01'; // e.g., "CR001"
    const s2 = 'WNG02';

    // rarities are just labels for your UI; doesn’t gate hatching
    const r1 = 'Rare';
    const r2 = 'Rare';

    final nowUtc = DateTime.now().toUtc();

    // find two free slots (or just use 0/1 if you know they’re free)
    final slots = await db.watchSlots().first; // single snapshot
    final slot0 = slots.firstWhere((s) => s.id == 0);
    final slot1 = slots.firstWhere((s) => s.id == 1);

    // make sure they’re unlocked
    if (!slot0.unlocked) await db.unlockSlot(0);
    if (!slot1.unlocked) await db.unlockSlot(1);

    // clear any eggs that might be there already
    if (slot0.eggId != null) await db.clearEgg(0);
    if (slot1.eggId != null) await db.clearEgg(1);

    // create two unique egg ids
    final eggId0 = _uuid.v4();
    final eggId1 = _uuid.v4();

    // set hatch times a few seconds in the future
    final hatch0 = nowUtc.add(const Duration(seconds: 6));
    final hatch1 = nowUtc.add(const Duration(seconds: 10));

    // place eggs directly into incubators
    await db.placeEgg(
      slotId: 0,
      eggId: eggId0,
      resultCreatureId: s1,
      bonusVariantId: null, // or 'SomeVariantId' if you use them
      rarity: r1,
      hatchAtUtc: hatch0,
    );

    await db.placeEgg(
      slotId: 1,
      eggId: eggId1,
      resultCreatureId: s2,
      bonusVariantId: null,
      rarity: r2,
      hatchAtUtc: hatch1,
    );
  }

  /// Alternative: queue test eggs into inventory (not hatching until placed).
  Future<void> enqueueTwoInventoryEggs() async {
    final e0 = _uuid.v4();
    final e1 = _uuid.v4();
    await db.enqueueEgg(
      eggId: e0,
      resultCreatureId: 'CR003',
      rarity: 'Common',
      remaining: const Duration(minutes: 30),
    );
    await db.enqueueEgg(
      eggId: e1,
      resultCreatureId: 'CR004',
      rarity: 'Rare',
      remaining: const Duration(hours: 1),
    );
  }

  /// If you already have eggs in slots and want them to hatch immediately:
  Future<void> forceHatchBothNow() async {
    final nowUtc = DateTime.now().toUtc();
    // move hatchAt to “now” by speeding up a large delta
    await db.speedUpSlot(
      slotId: 0,
      delta: const Duration(hours: 999),
      safeNowUtc: nowUtc,
    );
    await db.speedUpSlot(
      slotId: 1,
      delta: const Duration(hours: 999),
      safeNowUtc: nowUtc,
    );
  }
}
