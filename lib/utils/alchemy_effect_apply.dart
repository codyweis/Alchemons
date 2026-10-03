import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/inventory.dart';

/// Puts the alchemy effect bought as [itemKey] on a creature. Whatever effect
/// it replaces goes back into the inventory instead of being lost, so
/// swapping is free. Returns false when [itemKey] is not an effect item.
Future<bool> applyAlchemyEffect(
  AlchemonsDatabase db, {
  required String instanceId,
  required String itemKey,
}) async {
  final effect = InvKeys.alchemyEffectFor(itemKey);
  if (effect == null) return false;
  final current = (await db.creatureDao.getInstance(instanceId))?.alchemyEffect;
  if (current == effect) return true; // already wearing it; keep the item
  await db.creatureDao.updateAlchemyEffect(
    instanceId: instanceId,
    effect: effect,
  );
  await db.inventoryDao.decrementItem(itemKey, by: 1);
  final replaced = InvKeys.alchemyItemFor(current);
  if (replaced != null) await db.inventoryDao.addItemQty(replaced, 1);
  return true;
}

/// Takes the effect off a creature and returns it to the inventory.
Future<void> removeAlchemyEffect(
  AlchemonsDatabase db, {
  required String instanceId,
}) async {
  final current = (await db.creatureDao.getInstance(instanceId))?.alchemyEffect;
  if (current == null) return;
  await db.creatureDao.updateAlchemyEffect(
    instanceId: instanceId,
    effect: null,
  );
  final item = InvKeys.alchemyItemFor(current);
  if (item != null) await db.inventoryDao.addItemQty(item, 1);
}
