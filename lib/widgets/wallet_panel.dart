// lib/widgets/wallet_panel.dart
//
// The one place the game shows everything the player can spend: gold and
// silver over the five element resources, in a bracket frame. The shop and
// the inventory both open with it.

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/element_resource_glyph.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// What the player holds, in one panel: gold and silver over the five
/// element resources. Every element is shown, held or not, so the row never
/// shifts and a price in an element you have none of still has its column.
class WalletPanel extends StatelessWidget {
  const WalletPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final t = ForgeTokens(theme);
    final db = context.read<AlchemonsDatabase>();
    return StreamBuilder<Map<String, int>>(
      stream: db.currencyDao.watchAllCurrencies(),
      builder: (context, coinSnap) {
        final coins = coinSnap.data ?? const <String, int>{};
        return StreamBuilder<Map<String, int>>(
          stream: db.currencyDao.watchResourceBalances(),
          builder: (context, resSnap) {
            final res = resSnap.data ?? const <String, int>{};
            return CustomPaint(
              foregroundPainter: BracketFramePainter(
                color: palette.line.withValues(alpha: 0.9),
                bracketSize: 9,
              ),
              child: Container(
                color: palette.surfaceFill(),
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: CoinAmount(
                              kind: CoinKind.gold,
                              amount: coins['gold'] ?? 0,
                              size: 15,
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 18,
                          color: palette.lineSoft,
                        ),
                        Expanded(
                          child: Center(
                            child: CoinAmount(
                              kind: CoinKind.silver,
                              amount: coins['silver'] ?? 0,
                              size: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Container(height: 1, color: palette.lineSoft),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final r in ElementResources.all)
                          Expanded(
                            child: _WalletElement(
                              resource: r,
                              amount: res[r.settingsKey] ?? 0,
                              color: t.readableAccent(r.color),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _WalletElement extends StatelessWidget {
  const _WalletElement({
    required this.resource,
    required this.amount,
    required this.color,
  });

  final ElementResource resource;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final held = amount > 0;
    return Opacity(
      opacity: held ? 1 : 0.38,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElementResourceGlyph.of(resource, size: 22, glow: 0.7),
            const SizedBox(width: 4),
            Text(
              formatCoins(amount),
              style: TextStyle(
                fontFamily: 'monospace',
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
