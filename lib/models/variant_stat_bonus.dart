/// What a faction variant is worth in combat.
///
/// A variant is bred out of its own faction toward a partner's, and takes on
/// that faction's strength — one stat each, the four factions to the four
/// stats; Arcane, a little of everything:
///
/// * **Volcanic**: +8% Strength.
/// * **Oceanic**: +8% Intelligence.
/// * **Verdant**: +8% Speed.
/// * **Earthen**: +8% Beauty.
/// * **Arcane**: +3% to all four.
/// * A variant of **the faction you joined**: +12% instead of +8%. (Arcane
///   cannot be joined.)
///
/// Bloodborn, the Blood rebirth's mark, is no faction and adds nothing. The
/// joined faction is the player's, not the creature's, so the bonus follows
/// whoever holds it: stats are rewritten when the player joins another
/// faction, and when a creature changes hands.
library;

import 'package:alchemons/models/purity_stat_bonus.dart';

const double kVariantStatBonus = 0.08;
const double kJoinedFactionVariantStatBonus = 0.12;
const double kArcaneVariantStatBonus = 0.03;

/// The stat each joinable faction's variants are strong in.
const Map<String, String> kVariantFactionStat = {
  'volcanic': kStatStrength,
  'oceanic': kStatIntelligence,
  'verdant': kStatSpeed,
  'earthen': kStatBeauty,
};

class VariantStatBonus {
  const VariantStatBonus._(
    this.faction,
    this.statKeys,
    this.bonus,
    this.joined,
  );

  static const none = VariantStatBonus._(null, [], 0, false);

  /// The variant's faction, capitalized ('Volcanic'); null for none.
  final String? faction;

  /// The stats it lifts: one, or all four for Arcane.
  final List<String> statKeys;

  /// What each of [statKeys] is lifted by (0.08 is +8%).
  final double bonus;

  /// The variant is of the faction the player joined.
  final bool joined;

  bool get isNone => statKeys.isEmpty;

  double multiplierFor(String statKey) =>
      statKeys.contains(statKey) ? 1.0 + bonus : 1.0;

  @override
  String toString() =>
      'VariantStatBonus($faction ${statKeys.join('/')} +${(bonus * 100).round()}%)';
}

/// The bonus for a creature of [variantFaction] held by a player who joined
/// [joinedFaction] (a faction id, 'volcanic'…, or null for none yet).
VariantStatBonus resolveVariantStatBonus({
  required String? variantFaction,
  required String? joinedFaction,
}) {
  final faction = (variantFaction ?? '').trim().toLowerCase();
  if (faction.isEmpty) return VariantStatBonus.none;
  final name = faction[0].toUpperCase() + faction.substring(1);
  if (faction == 'arcane') {
    return VariantStatBonus._(
      name,
      const [kStatSpeed, kStatIntelligence, kStatStrength, kStatBeauty],
      kArcaneVariantStatBonus,
      false,
    );
  }
  final stat = kVariantFactionStat[faction];
  if (stat == null) return VariantStatBonus.none;
  final joined = faction == (joinedFaction ?? '').trim().toLowerCase();
  return VariantStatBonus._(
    name,
    [stat],
    joined ? kJoinedFactionVariantStatBonus : kVariantStatBonus,
    joined,
  );
}
