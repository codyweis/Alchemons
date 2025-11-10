// lib/constants/black_market_constants.dart
class BlackMarketConstants {
  // Base silver values by rarity
  static const Map<String, int> baseValues = {
    'common': 10,
    'uncommon': 25,
    'rare': 50,
    'epic': 100,
    'legendary': 250,
    'mythic': 500,
  };

  // Level multiplier: each level adds 5% to base value
  static double levelMultiplier(int level) => 1.0 + (level - 1) * 0.05;

  // Prismatic bonus: +1000% value
  static const double prismaticBonus = 10;

  // Nature bonus: certain natures fetch higher prices
  static const Map<String, double> natureMultipliers = {
    'Elegant': 2.0,
    // Add more as desired
  };

  static const Map<String, double> tintMultipliers = {'vibrant': 1.5};

  // Calculate total sell price
  static int calculateSellPrice({
    required String rarity,
    required int level,
    required bool isPrismatic,
    String? natureId,
    String? tintId,
  }) {
    final base = baseValues[rarity.toLowerCase()] ?? baseValues['common']!;
    final levelMult = levelMultiplier(level);
    final prismaMult = isPrismatic ? prismaticBonus : 1.0;
    final natureMult = natureId != null
        ? (natureMultipliers[natureId] ?? 1.0)
        : 1.0;
    final tintMult = tintId != null ? (tintMultipliers[tintId] ?? 1.0) : 1.0;

    return (base * levelMult * prismaMult * natureMult * tintMult).round();
  }

  // Bulk sale bonus: 5% extra per creature after the first
  static int calculateBulkBonus(List<int> prices) {
    if (prices.length <= 1) return 0;

    int bonus = 0;
    for (int i = 1; i < prices.length; i++) {
      bonus += (prices[i] * 0.05 * i).round();
    }
    return bonus;
  }
}
