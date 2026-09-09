import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:flutter/material.dart';

/// The two currency-exchange offers, drawn with the actual coins.
///
/// Both rows used the same generic `currency_exchange` glyph, so the only way
/// to tell silver→gold from gold→silver was to read the label. The coins are
/// already the game's own art and the player reads them everywhere else; the
/// one thing they cannot say on their own is direction, which is what the
/// arrow and the front-to-back order are for.
class CoinExchangeIcon extends StatelessWidget {
  const CoinExchangeIcon({
    super.key,
    required this.from,
    required this.to,
    required this.size,
  });

  /// What you spend. Sits behind, dimmed.
  final CoinKind from;

  /// What you get. Sits in front, full size — it is what the row is selling.
  final CoinKind to;

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: size * 0.10,
            child: Opacity(
              opacity: 0.62,
              child: CoinIcon(kind: from, size: size * 0.50),
            ),
          ),
          Positioned(
            right: 0,
            top: size * 0.24,
            child: CoinIcon(kind: to, size: size * 0.62),
          ),
          Positioned(
            left: size * 0.10,
            right: size * 0.10,
            bottom: size * 0.02,
            child: Icon(
              AppIcons.arrow_forward_rounded,
              size: size * 0.24,
              color: const Color(0xFFE0A231),
            ),
          ),
        ],
      ),
    );
  }
}
