import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:flutter/painting.dart' show Color;

/// Puts the alchemy effect bought as [itemKey] on a creature, using up one.
/// Whatever effect it replaces goes back into the inventory instead of being
/// lost, so swapping is free. A family costume goes on only its own family,
/// fitted to the species, in [color]. Returns false when [itemKey] is
/// not an effect item for this creature, or none is owned.
Future<bool> applyAlchemyEffect(
  AlchemonsDatabase db, {
  required String instanceId,
  required String itemKey,
  Color? color,
}) => db.transaction(() async {
  final instance = await db.creatureDao.getInstance(instanceId);
  if (instance == null) return false;
  final costume = FamilyCostume.ofItem(itemKey);
  final effect = costume != null
      ? costume.effectOn(instance.baseId, color: color)
      : InvKeys.alchemyEffectFor(itemKey);
  if (effect == null) return false;
  final current = instance.alchemyEffect;
  if (current == effect) return true; // already wearing it; keep the item
  // The same costume in another colour: only the colour changes.
  if (costume != null && costume == FamilyCostume.ofEffect(current)) {
    await db.creatureDao.updateAlchemyEffect(
      instanceId: instanceId,
      effect: effect,
    );
    return true;
  }
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

/// Gives the costume a creature is wearing a new [color], free. False if
/// it is not wearing one.
Future<bool> recolorCostume(
  AlchemonsDatabase db, {
  required String instanceId,
  required Color color,
}) => db.transaction(() async {
  final instance = await db.creatureDao.getInstance(instanceId);
  final costume = FamilyCostume.ofEffect(instance?.alchemyEffect);
  if (costume == null) return false;
  await db.creatureDao.updateAlchemyEffect(
    instanceId: instanceId,
    effect: costume.effectOn(instance!.baseId, color: color),
  );
  return true;
});
