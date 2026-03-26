// lib/widgets/currency_display_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';

class CurrencyDisplayWidget extends StatefulWidget {
  final Color? accentColor;
  final bool compact;
  final VoidCallback? onTap;

  const CurrencyDisplayWidget({
    super.key,
    this.accentColor,
    this.compact = false,
    this.onTap,
  });

  @override
  State<CurrencyDisplayWidget> createState() => _CurrencyDisplayWidgetState();
}

class _CurrencyDisplayWidgetState extends State<CurrencyDisplayWidget>
    with SingleTickerProviderStateMixin {
  bool _condensed = true;

  /// 0 = fully expanded, 1 = fully condensed.
  late final AnimationController _ctrl;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 1.0,
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _formatCurrency(int amount) {
    if (amount >= 1000000000) return '${(amount / 1e9).toStringAsFixed(1)}B';
    if (amount >= 1000000) return '${(amount / 1e6).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1e3).toStringAsFixed(1)}K';
    return '$amount';
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    setState(() => _condensed = !_condensed);
    if (_condensed) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
    widget.onTap?.call();
  }

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _goldColor(BuildContext context) =>
      _isDark(context) ? const Color(0xFFFFD700) : const Color(0xFF8A5A00);

  Color _silverColor(BuildContext context) =>
      _isDark(context) ? const Color(0xFFC0C0C0) : const Color(0xFF5F6772);

  Color _backgroundColor(BuildContext context) => _isDark(context)
      ? Colors.black.withValues(alpha: 0.25)
      : Colors.white.withValues(alpha: 0.78);

  Color _borderColor(BuildContext context, Color accent) => _isDark(context)
      ? accent.withValues(alpha: 0.3)
      : accent.withValues(alpha: 0.45);

  Color _dividerColor(BuildContext context) => _isDark(context)
      ? Colors.white.withValues(alpha: 0.2)
      : Colors.black.withValues(alpha: 0.16);

  List<BoxShadow> _shadow(BuildContext context, Color accent) =>
      _isDark(context)
      ? [
          BoxShadow(
            color: accent.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ]
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ];

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final accent = widget.accentColor ?? Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          final t = _progress.value;
          // Interpolate padding so the container shrinks smoothly.
          final hPad = lerpDouble(12, 10, t)!;
          final vPad = lerpDouble(8, 6, t)!;
          final radius = lerpDouble(12, 8, t)!;

          return Container(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            decoration: BoxDecoration(
              color: _backgroundColor(context),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: _borderColor(context, accent),
                width: 1,
              ),
              boxShadow: _shadow(context, accent),
            ),
            child: StreamBuilder<Map<String, int>>(
              stream: db.currencyDao.watchAllCurrencies(),
              builder: (context, snapshot) {
                final currencies =
                    snapshot.data ?? {'gold': 0, 'silver': 0, 'soft': 0};
                final gold = currencies['gold'] ?? 0;
                final silver = currencies['silver'] ?? 0;

                return AnimatedSize(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.centerLeft,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // ── Full view (fades out when condensing) ──────────────
                      IgnorePointer(
                        child: Opacity(
                          opacity: (1.0 - t).clamp(0.0, 1.0),
                          child: t < 0.99
                              ? _buildFullView(gold, silver)
                              : const SizedBox.shrink(),
                        ),
                      ),
                      // ── Condensed view (fades in when condensing) ──────────
                      IgnorePointer(
                        child: Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: t > 0.01
                              ? _buildCondensedView(gold, silver)
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFullView(int gold, int silver) {
    final dividerColor = _dividerColor(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CurrencyPill(
          icon: Icons.hexagon_rounded,
          amount: gold,
          color: _goldColor(context),
          formatter: _formatCurrency,
        ),
        const SizedBox(width: 8),
        Container(width: 1, height: 20, color: dividerColor),
        const SizedBox(width: 8),
        _CurrencyPill(
          icon: Icons.monetization_on_rounded,
          amount: silver,
          color: _silverColor(context),
          formatter: _formatCurrency,
        ),
      ],
    );
  }

  /// Condensed view — numbers only, no icon circles.
  Widget _buildCondensedView(int gold, int silver) {
    final goldColor = _goldColor(context);
    final silverColor = _silverColor(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.hexagon_rounded, size: 11, color: goldColor),
        const SizedBox(width: 3),
        Text(
          _formatCurrency(gold),
          style: TextStyle(
            color: goldColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 8),
        Container(width: 1, height: 14, color: _dividerColor(context)),
        const SizedBox(width: 8),
        Icon(Icons.monetization_on_rounded, size: 11, color: silverColor),
        const SizedBox(width: 3),
        Text(
          _formatCurrency(silver),
          style: TextStyle(
            color: silverColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

double? lerpDouble(double a, double b, double t) => a + (b - a) * t;

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
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
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
            shadows: [
              Shadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
            ],
          ),
        ),
      ],
    );
  }
}
