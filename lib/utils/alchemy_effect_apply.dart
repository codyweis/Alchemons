import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:flutter/painting.dart' show Color;

/// Puts the alchemy effect bought as [itemKey] on a creature, using up one.
/// Whatever effect it replaces goes back into the inventory instead of being
/// lost, so swapping is free. Returns false when [itemKey] is not an effect
/// item (a costume is worn with [wearCostume]), or none is owned.
Future<bool> applyAlchemyEffect(
  AlchemonsDatabase db, {
  required String instanceId,
  required String itemKey,
}) => db.transaction(() async {
  final instance = await db.creatureDao.getInstance(instanceId);
  if (instance == null) return false;
  if (FamilyCostume.ofItem(itemKey) != null) return false;
  final effect = InvKeys.alchemyEffectFor(itemKey);
  if (effect == null) return false;
  final current = instance.alchemyEffect;
  if (current == effect) return true; // already wearing it; keep the item
  if (await db.inventoryDao.getItemQty(itemKey) < 1) return false;
  await db.creatureDao.updateAlchemyEffect(
    instanceId: instanceId,
    effect: effect,
  );
  await db.inventoryDao.decrementItem(itemKey, by: 1);
  final replaced = InvKeys.alchemyItemFor(current);
  if (replaced != null) await db.inventoryDao.addItemQty(replaced, 1);
  return true;
});

/// Takes the effect off a creature and returns it to the inventory.
Future<void> removeAlchemyEffect(
  AlchemonsDatabase db, {
  required String instanceId,
}) => db.transaction(() async {
  final current = (await db.creatureDao.getInstance(instanceId))?.alchemyEffect;
  if (current == null) return;
  await db.creatureDao.updateAlchemyEffect(
    instanceId: instanceId,
    effect: null,
  );
  final item = InvKeys.alchemyItemFor(current);
  if (item != null) await db.inventoryDao.addItemQty(item, 1);
});

/// Puts [costume] on a creature in [color] (its own if null), using up
/// one; it is worn beside its effect and any other costumes. If it already
/// wears one, only the colour changes, free. False if it does not fit the
/// species, or none is owned.
Future<bool> wearCostume(
  AlchemonsDatabase db, {
  required String instanceId,
  required FamilyCostume costume,
  Color? color,
}) => db.transaction(() async {
  final instance = await db.creatureDao.getInstance(instanceId);
  if (instance == null || !costume.fits(instance.baseId)) return false;
  final worn = WornCostumes.on(instance.baseId, instance.costumes);
  if (!worn.wears(costume)) {
    if (await db.inventoryDao.getItemQty(costume.itemKey) < 1) return false;
    await db.inventoryDao.decrementItem(costume.itemKey, by: 1);
  }
  await db.creatureDao.updateCostumes(
    instanceId: instanceId,
    costumes: worn.wear(costume, color: color).encode(),
  );
  return true;
});

/// Takes [costume] off a creature and returns it to the inventory. False
/// if it was not wearing one.
Future<bool> takeOffCostume(
  AlchemonsDatabase db, {
  required String instanceId,
  required FamilyCostume costume,
}) => db.transaction(() async {
  final instance = await db.creatureDao.getInstance(instanceId);
  if (instance == null) return false;
  final worn = WornCostumes.on(instance.baseId, instance.costumes);
  if (!worn.wears(costume)) return false;
  await db.creatureDao.updateCostumes(
    instanceId: instanceId,
    costumes: worn.without(costume).encode(),
  );
  await db.inventoryDao.addItemQty(costume.itemKey, 1);
  return true;
});

/// Gives the [costume] a creature is wearing a new [color], free. False if
/// it is not wearing one.
Future<bool> recolorCostume(
  AlchemonsDatabase db, {
  required String instanceId,
  required FamilyCostume costume,
  required Color color,
}) => db.transaction(() async {
  final instance = await db.creatureDao.getInstance(instanceId);
  if (instance == null) return false;
  final worn = WornCostumes.on(instance.baseId, instance.costumes);
  if (!worn.wears(costume)) return false;
  await db.creatureDao.updateCostumes(
    instanceId: instanceId,
    costumes: worn.wear(costume, color: color).encode(),
  );
  return true;
});
