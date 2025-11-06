// lib/widgets/currency_display_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';

class CurrencyDisplayWidget extends StatelessWidget {
  final Color? accentColor;
  final bool compact;
  final VoidCallback? onTap;

  const CurrencyDisplayWidget({
    super.key,
    this.accentColor,
    this.compact = false,
    this.onTap,
  });

  String _formatCurrency(int amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1e9).toStringAsFixed(1)}B';
    }
    if (amount >= 1000000) {
      return '${(amount / 1e6).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1e3).toStringAsFixed(1)}K';
    }
    return '$amount';
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final accent = accentColor ?? Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
          border: Border.all(color: accent.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: StreamBuilder<Map<String, int>>(
          stream: db.currencyDao.watchAllCurrencies(),
          builder: (context, snapshot) {
            final currencies =
                snapshot.data ?? {'gold': 0, 'silver': 0, 'soft': 0};

            final gold = currencies['gold'] ?? 0;
            final silver = currencies['silver'] ?? 0;

            if (compact) {
              return _buildCompactView(gold, silver);
            } else {
              return _buildFullView(gold, silver);
            }
          },
        ),
      ),
    );
  }

  Widget _buildFullView(int gold, int silver) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Gold
        _CurrencyPill(
          icon: Icons.diamond_rounded,
          amount: gold,
          color: const Color(0xFFFFD700), // Gold color
          formatter: _formatCurrency,
        ),

        const SizedBox(width: 8),

        // Divider
        Container(width: 1, height: 20, color: Colors.white.withOpacity(0.2)),

        const SizedBox(width: 8),

        // Silver
        _CurrencyPill(
          icon: Icons.monetization_on_rounded,
          amount: silver,
          color: const Color(0xFFC0C0C0), // Silver color
          formatter: _formatCurrency,
        ),
      ],
    );
  }

  Widget _buildCompactView(int gold, int silver) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Gold icon + amount
        Icon(Icons.diamond_rounded, size: 14, color: const Color(0xFFFFD700)),
        const SizedBox(width: 4),
        Text(
          _formatCurrency(gold),
          style: const TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),

        const SizedBox(width: 10),

        // Silver icon + amount
        Icon(
          Icons.monetization_on_rounded,
          size: 14,
          color: const Color(0xFFC0C0C0),
        ),
        const SizedBox(width: 4),
        Text(
          _formatCurrency(silver),
          style: const TextStyle(
            color: Color(0xFFC0C0C0),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _CurrencyPill extends StatelessWidget {
  final IconData icon;
  final int amount;
  final Color color;
  final String Function(int) formatter;

  const _CurrencyPill({
    required this.icon,
    required this.amount,
    required this.color,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.15),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          formatter(amount),
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}
