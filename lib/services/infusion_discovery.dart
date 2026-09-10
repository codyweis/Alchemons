import 'package:alchemons/database/daos/inventory_dao.dart';
import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/inventory.dart';

/// Whether the player has ever held the means to infuse a stat.
///
/// Stat Infusion is offered in two places — the Enhance entry card and the
/// tray inside the screen itself — and they must agree, or the door leads to
/// an empty room or the room hides behind a door that is not there.
///
/// Discovery is one-way. Spending your last orb should not retract a feature
/// you have already learned to want; that reads as the game breaking rather
/// than as the game tidying up. So the flags only ever turn on.
class InfusionDiscovery {
  const InfusionDiscovery._();

  static const orbSeenKey = 'enhance_orb_tray_seen_v1';
  static const soulSeenKey = 'enhance_soul_tray_seen_v1';

  /// Every power orb the player is holding, of any stat.
  static int orbCount(Map<String, int> inventory) =>
      AlchemicalPowerupType.values.fold<int>(
        0,
        (sum, type) => sum + (inventory[type.inventoryKey] ?? 0),
      );

  static int soulCount(Map<String, int> inventory) =>
      inventory[InvKeys.potentialSoul] ?? 0;

  static Future<bool> orbsDiscovered(SettingsDao settings) async =>
      await settings.getSetting(orbSeenKey) == '1';

  static Future<bool> soulsDiscovered(SettingsDao settings) async =>
      await settings.getSetting(soulSeenKey) == '1';

  /// True once either kind has ever been held — the condition for Stat
  /// Infusion existing at all.
  static Future<bool> anyDiscovered(SettingsDao settings) async =>
      await orbsDiscovered(settings) || await soulsDiscovered(settings);

  /// How many infusion items the player holds, read one key at a time —
  /// the inventory dao exposes a stream for the whole table and a getter per
  /// key, and this wants a handful of keys once.
  static Future<Map<String, int>> readHoldings(InventoryDao inventory) async {
    final keys = [
      for (final type in AlchemicalPowerupType.values) type.inventoryKey,
      InvKeys.potentialSoul,
    ];
    final counts = await Future.wait(keys.map(inventory.getItemQty));
    return {for (var i = 0; i < keys.length; i++) keys[i]: counts[i]};
  }

  /// Records what the player is holding right now. Safe to call on every
  /// build: it writes only on the transition from never-held to held.
  static Future<void> observe(
    SettingsDao settings,
    Map<String, int> inventory,
  ) async {
    if (orbCount(inventory) > 0 && !await orbsDiscovered(settings)) {
      await settings.setSetting(orbSeenKey, '1');
    }
    if (soulCount(inventory) > 0 && !await soulsDiscovered(settings)) {
      await settings.setSetting(soulSeenKey, '1');
    }
  }
}
