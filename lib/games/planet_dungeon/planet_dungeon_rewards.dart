// lib/games/planet_dungeon/planet_dungeon_rewards.dart
//
// Dungeon star rewards (granted once per star, on End Run):
//   Star 1 → 10 gold.
//   Star 2 → 5 random alchemical powerups.
//   Star 3 → the planet's Guardian Relic (first time only) plus the player's
//            choice of: 25 gold, 10 random powerups, or
//            10 Instant Fusion Extractors.

import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/inventory.dart';

const List<String> kPowerupKeys = [
  InvKeys.powerupSpeed,
  InvKeys.powerupIntelligence,
  InvKeys.powerupStrength,
  InvKeys.powerupBeauty,
];

/// The three options offered for Star 3.
enum Star3Choice { gold, powerups, extractors }

String star3ChoiceTitle(Star3Choice c) => switch (c) {
  Star3Choice.gold => '25 Gold',
  Star3Choice.powerups => '10 Powerups',
  Star3Choice.extractors => '10 Fusion Extractors',
};

String star3ChoiceSubtitle(Star3Choice c) => switch (c) {
  Star3Choice.gold => 'Pure alchemical currency.',
  Star3Choice.powerups => '10 random stat powerups.',
  Star3Choice.extractors => 'Complete fusion vials instantly.',
};

String _powerupName(String key) => switch (key) {
  InvKeys.powerupSpeed => 'Speed Powerup',
  InvKeys.powerupIntelligence => 'Intelligence Powerup',
  InvKeys.powerupStrength => 'Strength Powerup',
  InvKeys.powerupBeauty => 'Beauty Powerup',
  _ => 'Powerup',
};

Map<String, int> _rollPowerups(int n, Random rng) {
  final counts = <String, int>{};
  for (var i = 0; i < n; i++) {
    final k = kPowerupKeys[rng.nextInt(kPowerupKeys.length)];
    counts[k] = (counts[k] ?? 0) + 1;
  }
  return counts;
}

List<String> _powerupLines(Map<String, int> counts) => [
  for (final e in counts.entries) '+${e.value} ${_powerupName(e.key)}',
];

/// Display name of the element's guardian relic.
String guardianRelicName(String element) =>
    BossLootKeys.elementRewards[element.toLowerCase()]?.traitName ??
    '$element Relic';

/// Grant a star's reward and return human-readable reward lines for the popup.
/// [choice] is required only for Star 3 (index 2).
Future<List<String>> grantStarReward({
  required AlchemonsDatabase db,
  required String element,
  required int starIndex,
  Star3Choice? choice,
  Random? rng,
}) async {
  final r = rng ?? Random();
  switch (starIndex) {
    case 0:
      await db.currencyDao.addGold(10);
      return ['+10 Gold'];
    case 1:
      final counts = _rollPowerups(5, r);
      for (final e in counts.entries) {
        await db.inventoryDao.addItemQty(e.key, e.value);
      }
      return _powerupLines(counts);
    case 2:
      // The guardian's relic — once per element, on top of the chosen reward.
      final relicLines = <String>[];
      final traitKey = BossLootKeys.traitKeyForElement(element);
      if (await db.inventoryDao.getItemQty(traitKey) == 0) {
        await db.inventoryDao.addItemQty(traitKey, 1);
        relicLines.add('+1 ${guardianRelicName(element)}, Guardian Relic');
      }
      switch (choice ?? Star3Choice.gold) {
        case Star3Choice.gold:
          await db.currencyDao.addGold(25);
          return [...relicLines, '+25 Gold'];
        case Star3Choice.powerups:
          final counts = _rollPowerups(10, r);
          for (final e in counts.entries) {
            await db.inventoryDao.addItemQty(e.key, e.value);
          }
          return [...relicLines, ..._powerupLines(counts)];
        case Star3Choice.extractors:
          await db.inventoryDao.addItemQty(InvKeys.instantHatch, 10);
          return [...relicLines, '+10 Instant Fusion Extractors'];
      }
    default:
      return const [];
  }
}
