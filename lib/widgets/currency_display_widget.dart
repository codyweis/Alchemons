// lib/widgets/currency_display_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/constants/design_tokens.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/widgets/coin_icon.dart';

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
                        kind: CoinKind.gold,
                        label: 'GOLD',
                        amount: gold,
                        isDark: isDark,
                        t: _progress.value,
                        formatter: _format,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: _CurrencyChip(
                        kind: CoinKind.silver,
                        label: 'SILVER',
                        amount: silver,
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

typedef _CurrencyKind = CoinKind;

class _ChipPalette {
  final Color tint;
  final Color textPrimary;
  final Color labelMuted;
  final List<Color> fillGradient;
  final Color topHighlight;
  final Color bottomShadow;
  final Color border;

  const _ChipPalette({
    required this.tint,
    required this.textPrimary,
    required this.labelMuted,
    required this.fillGradient,
    required this.topHighlight,
    required this.bottomShadow,
    required this.border,
  });
}

_ChipPalette _paletteFor(_CurrencyKind kind, bool isDark) {
  if (kind == CoinKind.gold) {
    return isDark
        ? const _ChipPalette(
            tint: Color(0xFFFFD66B),
            textPrimary: Color(0xFFFFE69A),
            labelMuted: Color(0xB3FFE69A),
            fillGradient: [Color(0xFF2A1F08), Color(0xFF120B02)],
            topHighlight: Color(0x66FFE69A),
            bottomShadow: Color(0x99000000),
            border: Color(0x66B07A1A),
          )
        : const _ChipPalette(
            tint: Color(0xFF8A5A00),
            textPrimary: Color(0xFF5A3A00),
            labelMuted: Color(0xB35A3A00),
            fillGradient: [Color(0xFFFFF5DA), Color(0xFFF0D7A2)],
            topHighlight: Color(0xCCFFFFFF),
            bottomShadow: Color(0x33000000),
            border: Color(0x88B07A1A),
          );
  }
  return isDark
      ? const _ChipPalette(
          tint: Color(0xFFDDE3EC),
          textPrimary: Color(0xFFEEF1F6),
          labelMuted: Color(0xB3EEF1F6),
          fillGradient: [Color(0xFF1B1F25), Color(0xFF0A0C0F)],
          topHighlight: Color(0x66EEF1F6),
          bottomShadow: Color(0x99000000),
          border: Color(0x66747C88),
        )
      : const _ChipPalette(
          tint: Color(0xFF566270),
          textPrimary: Color(0xFF323A45),
          labelMuted: Color(0xB3323A45),
          fillGradient: [Color(0xFFF6F8FB), Color(0xFFD8DDE5)],
          topHighlight: Color(0xCCFFFFFF),
          bottomShadow: Color(0x22000000),
          border: Color(0x88747C88),
        );
}

class _CurrencyChip extends StatelessWidget {
  final _CurrencyKind kind;
  final String label;
  final int amount;
  final bool isDark;

  /// 0 = expanded, 1 = condensed
  final double t;
  final String Function(int) formatter;

  const _CurrencyChip({
    required this.kind,
    required this.label,
    required this.amount,
    required this.isDark,
    required this.t,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final p = _paletteFor(kind, isDark);

    final hPad = _lerp(12, 9, t);
    final vPad = _lerp(7, 5, t);
    final radius = _lerp(12, 9, t);
    final coinSize = _lerp(AppIcon.lg, AppIcon.md, t);
    final minHeight = _lerp(44, 34, t);

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.fromLTRB(
        hPad - 4, // tighter left because the coin "leads"
        vPad,
        hPad,
        vPad,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: p.fillGradient,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: p.border, width: 0.8),
        boxShadow: [
          // outer drop
          BoxShadow(
            color: p.bottomShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          // top inner highlight (fakes a bevel)
          BoxShadow(
            color: p.topHighlight,
            blurRadius: 0,
            spreadRadius: -1,
            offset: const Offset(0, 1),
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoinIcon(kind: kind, size: coinSize),
          SizedBox(width: _lerp(AppSpace.sm, 6, t)),
          Flexible(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
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
                                    color: p.labelMuted,
                                    fontSize: 9.5,
                                    fontWeight: AppWeight.bold,
                                    letterSpacing: 1.4,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  formatter(amount),
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: p.textPrimary,
                                    fontSize: AppType.bodyLg,
                                    fontWeight: AppWeight.bold,
                                    letterSpacing: 0.1,
                                    height: 1.0,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
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
                                color: p.textPrimary,
                                fontSize: AppType.body,
                                fontWeight: AppWeight.bold,
                                letterSpacing: 0.1,
                                height: 1.0,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
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

