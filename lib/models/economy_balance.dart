/// Canonical exchange anchors shared by every storefront.
///
/// Gold remains premium: converting Gold back to Silver pays 5,000 per Gold,
/// while buying Gold normally costs 10,000 Silver. The Black Market's daily
/// exchange is the limited 50%-off exception.
abstract final class EconomyBalance {
  static const int silverPerGoldPayout = 5000;
  static const int silverPerGoldPurchase = 10000;
  static const int dailySilverPerGoldPurchase = 5000;

  static const int standardGoldBundle = 5;
  static const int standardGoldBundleSilverCost =
      standardGoldBundle * silverPerGoldPurchase;
}
