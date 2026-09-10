/// Canonical exchange anchors shared by every storefront.
///
/// Gold remains premium: buying Gold normally costs 10,000 Silver, and
/// cashing it back out pays 1,000 — a deliberately poor round trip, so Gold
/// is spent on Gold things rather than melted down. The Black Market's daily
/// exchange is the limited 50%-off exception.
abstract final class EconomyBalance {
  /// What one Gold buys at the counter.
  static const int silverPerGoldExchange = 1000;

  /// How much Silver of value is worth one Gold when something is SOLD.
  ///
  /// Not the same number as the exchange, and deliberately not: this one
  /// prices vials and specimens in the exchange and the black market, so
  /// moving it changes what everything in the game sells for. It used to be
  /// the exchange rate as well, which meant the counter's rate could not be
  /// touched without repricing every sale by the same factor.
  static const int silverPerGoldPayout = 5000;
  static const int silverPerGoldPurchase = 10000;
  static const int dailySilverPerGoldPurchase = 5000;

  static const int standardGoldBundle = 5;
  static const int standardGoldBundleSilverCost =
      standardGoldBundle * silverPerGoldPurchase;
}
