// lib/widgets/coin_icon.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Which alchemical coin to draw.
enum CoinKind {
  gold,
  silver;

  /// Map common string tokens ('gold'/'silver') used across shop helpers
  /// to a [CoinKind]. Returns null for any other token (resources, shards,
  /// unknown), so callers can fall back to a regular [Icon].
  static CoinKind? tryFromToken(String token) {
    switch (token) {
      case 'gold':
        return CoinKind.gold;
      case 'silver':
        return CoinKind.silver;
      default:
        return null;
    }
  }
}

/// Renders the project's custom gold/silver coin SVG at a given size.
///
/// Use this anywhere a currency amount is displayed instead of the legacy
/// `Icon(AppIcons.hexagon_rounded)` (gold) or `Icon(AppIcons.monetization_on_rounded
/// | AppIcons.paid_rounded)` (silver). The SVG carries its own metallic
/// gradients, so callers no longer pass a tint color.
class CoinIcon extends StatelessWidget {
  final CoinKind kind;
  final double size;

  const CoinIcon({super.key, required this.kind, this.size = 16});

  const CoinIcon.gold({super.key, this.size = 16}) : kind = CoinKind.gold;
  const CoinIcon.silver({super.key, this.size = 16}) : kind = CoinKind.silver;

  @override
  Widget build(BuildContext context) {
    final asset = kind == CoinKind.gold
        ? 'assets/icons/gold_coin.svg'
        : 'assets/icons/silver_coin.svg';
    return SizedBox.square(
      dimension: size,
      child: SvgPicture.asset(
        asset,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const SizedBox.shrink(),
      ),
    );
  }
}
