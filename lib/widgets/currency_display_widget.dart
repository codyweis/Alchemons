// lib/widgets/currency_display_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/constants/design_tokens.dart';
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

  late final AnimationController _ctrl;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1.0,
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _format(int amount) {
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

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final isDark = _isDark(context);

    final goldColor = isDark ? const Color(0xFFFFCF4D) : const Color(0xFF8A5A00);
    final silverColor = isDark ? const Color(0xFFD8DCE3) : const Color(0xFF5F6772);

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: StreamBuilder<Map<String, int>>(
        stream: db.currencyDao.watchAllCurrencies(),
        builder: (context, snapshot) {
          final currencies =
              snapshot.data ?? const {'gold': 0, 'silver': 0, 'soft': 0};
          final gold = currencies['gold'] ?? 0;
          final silver = currencies['silver'] ?? 0;

          return AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment.centerLeft,
            child: AnimatedBuilder(
              animation: _progress,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: _CurrencyChip(
                        icon: Icons.hexagon_rounded,
                        label: 'GOLD',
                        amount: gold,
                        color: goldColor,
                        isDark: isDark,
                        t: _progress.value,
                        formatter: _format,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: _CurrencyChip(
                        icon: Icons.circle,
                        label: 'SILVER',
                        amount: silver,
                        color: silverColor,
                        isDark: isDark,
                        t: _progress.value,
                        formatter: _format,
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

class _CurrencyChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int amount;
  final Color color;
  final bool isDark;

  /// 0 = expanded, 1 = condensed
  final double t;
  final String Function(int) formatter;

  const _CurrencyChip({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
    required this.isDark,
    required this.t,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? color.withValues(alpha: 0.10)
        : color.withValues(alpha: 0.08);
    final border = isDark
        ? color.withValues(alpha: 0.28)
        : color.withValues(alpha: 0.22);

    final hPad = _lerp(12, 10, t);
    final vPad = _lerp(8, 6, t);
    final radius = _lerp(12, 999, t);
    final iconSize = _lerp(AppIcon.md, AppIcon.sm, t);

    return Container(
      constraints: BoxConstraints(minHeight: _lerp(AppTap.min, 32, t)),
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          SizedBox(width: _lerp(AppSpace.sm, AppSpace.xs, t)),
          Flexible(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Expanded label+value column
                Opacity(
                  opacity: (1.0 - t).clamp(0.0, 1.0),
                  child: IgnorePointer(
                    ignoring: t > 0.5,
                    child: t < 0.99
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.65)
                                        : Colors.black.withValues(alpha: 0.5),
                                    fontSize: 10,
                                    fontWeight: AppWeight.bold,
                                    letterSpacing: 1.1,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  formatter(amount),
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: AppType.bodyLg,
                                    fontWeight: AppWeight.bold,
                                    letterSpacing: 0.2,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                // Condensed value only
                Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: IgnorePointer(
                    ignoring: t < 0.5,
                    child: t > 0.01
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatter(amount),
                              maxLines: 1,
                              style: TextStyle(
                                color: color,
                                fontSize: AppType.body,
                                fontWeight: AppWeight.bold,
                                letterSpacing: 0.2,
                                height: 1.0,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
