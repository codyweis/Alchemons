// lib/constants/black_market_constants.dart
import 'package:alchemons/utils/nature_utils.dart';

class BlackMarketConstants {
  // Level-1 Silver values. Both ordinary Alchemon sale screens use this same
  // table so a specimen never becomes less valuable merely by changing shops.
  static const Map<String, int> baseValues = {
    'common': 125,
    'uncommon': 200,
    'rare': 350,
    'epic': 500,
    'legendary': 700,
    'mystic': 1500,
    'mythic': 1500, // Legacy spelling used by older saves and vial systems.
    'variant': 2000,
  };

  // Level multiplier: each level adds 5% to base value
  static double levelMultiplier(int level) => 1.0 + (level - 1) * 0.05;

  // Prismatic bonus: +1000% value
  static const double prismaticBonus = 10;

  static const Map<String, double> tintMultipliers = {'vibrant': 1.5};
  // Calculate total sell price
  static int calculateSellPrice({
    required String rarity,
    required int level,
    required bool isPrismatic,
    String? natureId,
    String? natureId2,
    String? tintId,
    num? averagePotential,
  }) {
    final base = baseValues[rarity.toLowerCase()] ?? baseValues['common']!;
    final levelMult = levelMultiplier(level);
    final prismaMult = isPrismatic ? prismaticBonus : 1.0;
    final tintMult = tintId != null ? (tintMultipliers[tintId] ?? 1.0) : 1.0;
    final natureMult = natureValueMultiplier(natureId, natureId2);
    final potentialMult = potentialValueMultiplier(averagePotential);

    return (base *
            levelMult *
            prismaMult *
            tintMult *
            natureMult *
            potentialMult)
        .round();
  }

  /// Potential adds value without making low-potential breeding stock worth
  /// less than the rarity baseline. The +50% ceiling is deliberately below
  /// the cost of manufacturing that quality with Potential Souls.
  static double potentialValueMultiplier(num? averagePotential) {
    if (averagePotential == null) return 1.0;
    final potential = averagePotential.clamp(1, 100).toDouble();
    if (potential >= 90) return 1.50;
    if (potential >= 80) return 1.35;
    if (potential >= 60) return 1.20;
    if (potential >= 40) return 1.10;
    return 1.0;
  }

  static double natureValueMultiplier(String? natureId, String? natureId2) =>
      saleValueMultiplierForNatures(natureId, natureId2);

  static double averagePotential({
    required num speed,
    required num intelligence,
    required num strength,
    required num beauty,
  }) => (speed + intelligence + strength + beauty) / 4.0;
}
