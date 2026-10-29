// lib/services/vial_infusion_service.dart
//
// The vial stands in the Essence screen's chambers: one per group, each
// holding at most one vial while it is infused (models/vial_infusion.dart).
// What is on a stand is kept in settings, as the chambers' own jobs are.

import 'dart:math';

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/vial_infusion.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';

class VialInfusionService {
  VialInfusionService(this.db, {Random? rng}) : _rng = rng ?? Random();

  final AlchemonsDatabase db;
  final Random _rng;

  static String _key(ElementalGroup group) => 'vial_infusion.${group.name}';

  /// Set once a first infusion has been poured: the stands stop asking to
  /// be found.
  static const String taughtKey = 'vial_infusion_taught_v1';

  /// The stand's walkthrough has been shown.
  static const String tutorialKey = 'vial_infusion_tutorial_seen_v1';

  Future<VialInfusion?> load(ElementalGroup group) async =>
      VialInfusion.deserialise(await db.settingsDao.getSetting(_key(group)));

  Future<void> _save(VialInfusion v) =>
      db.settingsDao.setSetting(_key(v.group), v.serialise());

  Future<void> _clear(ElementalGroup group) =>
      db.settingsDao.setSetting(_key(group), '');

  /// The essence it pours with: its own group's.
  String essenceKey(ElementalGroup group) =>
      ElementResources.keyForBiome(groupIdFrom(group));

  Future<int> essence(ElementalGroup group) =>
      db.currencyDao.getResource(essenceKey(group));

  /// The vials in the inventory that fit [group]'s stand.
  Future<List<ExtractionVial>> vialsFor(ElementalGroup group) async {
    final items = await db.inventoryDao.watchItemInventory().first;
    final prefix = 'vial.${group.name}.';
    return [
      for (final item in items)
        if (item.qty > 0 &&
            item.key.startsWith(prefix) &&
            item.key.split('.').length == 4)
          ExtractionVial(
            id: item.key,
            name: item.key.split('.').last,
            group: group,
            rarity: VialRarity.values.firstWhere(
              (r) => r.name == item.key.split('.')[2],
              orElse: () => VialRarity.common,
            ),
            quantity: item.qty,
            price: null,
          ),
    ]..sort((a, b) => a.rarity.index.compareTo(b.rarity.index));
  }

  /// Takes [vial] from the inventory and sets it on its group's stand.
  Future<VialInfusion?> set(ExtractionVial vial) async {
    if (await load(vial.group) != null) return null;
    final taken = await db.inventoryDao.consumeVial(
      vial.name,
      vial.group,
      vial.rarity,
    );
    if (!taken) return null;
    final v = VialInfusion(
      group: vial.group,
      rarity: vial.rarity,
      name: vial.name,
    );
    await _save(v);
    return v;
  }

  /// Puts the vial back in the inventory. Whatever was poured into it is
  /// gone with what it chose.
  Future<void> takeBack(ElementalGroup group) async {
    final v = await load(group);
    if (v == null) return;
    await db.inventoryDao.addVial(v.name, v.group, v.rarity);
    await _clear(group);
  }

  /// Pours for the stand's step and saves what comes up. Null when there is
  /// not enough essence (nothing is spent).
  Future<VialInfusion?> pour(ElementalGroup group) async {
    final v = await load(group);
    if (v == null || v.step == InfusionStep.extract) return null;
    // Rolled before it is paid for, so a roll that fails costs nothing.
    final next = v.poured(_rng);
    final paid = await db.currencyDao.spendResources({
      essenceKey(group): v.stepCost,
    });
    if (!paid) return null;
    await _save(next);
    await db.settingsDao.setSetting(taughtKey, '1');
    return next;
  }

  /// Takes [id] from what the last pour brought up.
  Future<VialInfusion?> take(ElementalGroup group, String id) async {
    final v = await load(group);
    if (v == null || !v.offer.contains(id)) return null;
    final next = v.taken(id);
    await _save(next);
    return next;
  }

  /// Spends the extraction's essence, for EggHatching.extractInfusedVial.
  Future<bool> payExtraction(VialInfusion v) => db.currencyDao.spendResources({
    essenceKey(v.group): infusionCost(InfusionStep.extract, v.rarity),
  });

  /// The vial has been drawn out: the stand is empty.
  Future<void> extracted(ElementalGroup group) => _clear(group);
}
