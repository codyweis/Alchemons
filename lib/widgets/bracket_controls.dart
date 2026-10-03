// lib/widgets/bracket_controls.dart
//
// Buttons, tabs, coin amounts and a confirmation dialog in the bracket-frame
// language (see bracket_frame.dart): accent brackets, a faint wash, ink
// labels in monospace. Made for the screens where things change hands — the
// black market and the specimen exchange — so a price reads the same in both.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 12345 → "12,345".
String formatCoins(int amount) {
  final digits = amount.abs().toString();
  final out = StringBuffer(amount < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// The colour a coin's amount is written in. Pale gold and silver read on
/// the dark palette; on the light one's parchment they wash out, so there
/// it is a deep gold and plain ink.
Color coinColor(CoinKind kind, [BracketPalette? palette]) {
  if (palette != null && !palette.isDark) {
    return kind == CoinKind.gold ? const Color(0xFF9A6B00) : palette.ink;
  }
  return kind == CoinKind.gold
      ? const Color(0xFFFFD36A)
      : const Color(0xFFCBD2DA);
}

/// A coin and how many.
class CoinAmount extends StatelessWidget {
  const CoinAmount({
    super.key,
    required this.kind,
    required this.amount,
    this.size = 14,
    this.color,
    this.weight = FontWeight.w800,
  });

  final CoinKind kind;
  final int amount;

  /// The figure's size; the coin is drawn a little larger.
  final double size;
  final Color? color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoinIcon(kind: kind, size: size * 1.15),
        SizedBox(width: size * 0.35),
        Text(
          formatCoins(amount),
          style: TextStyle(
            fontFamily: 'monospace',
            color: color ?? coinColor(kind),
            fontSize: size,
            fontWeight: weight,
          ),
        ),
      ],
    );
  }
}

/// Gold over silver, exact, in a bracket frame: the one way the game shows
/// what the player holds. [CurrencyDisplayWidget] is the live version.
class CoinPurse extends StatelessWidget {
  const CoinPurse({
    super.key,
    required this.gold,
    required this.silver,
    required this.palette,
    this.fill,
  });

  final int gold;
  final int silver;
  final BracketPalette palette;

  /// Behind the figures; the palette's surface when left out.
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BracketFramePainter(
        color: palette.line.withValues(alpha: 0.9),
        bracketSize: 7,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: fill ?? palette.surfaceFill(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CoinAmount(
              kind: CoinKind.gold,
              amount: gold,
              color: coinColor(CoinKind.gold, palette),
            ),
            const SizedBox(height: 3),
            CoinAmount(
              kind: CoinKind.silver,
              amount: silver,
              color: coinColor(CoinKind.silver, palette),
            ),
          ],
        ),
      ),
    );
  }
}

/// A button: accent brackets round a wash, the label in ink.
///
/// [primary] is the thing to do; the other kind is a quieter frame in the
/// line colour for the ways around it (add more, cancel).
class BracketButton extends StatelessWidget {
  const BracketButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.palette,
    required this.accent,
    this.icon,
    this.enabled = true,
    this.primary = true,
    this.height = 46,
    this.trailing,
  });

  final String label;
  final VoidCallback? onTap;
  final BracketPalette palette;
  final Color accent;
  final IconData? icon;
  final bool enabled;
  final bool primary;
  final double height;

  /// After the label: a count, say.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final frame = primary ? accent : palette.line;
    final ink = primary ? palette.ink : palette.muted;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: context.soundAction(enabled ? onTap : null),
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: frame.withValues(alpha: primary ? 1 : 0.8),
            bracketSize: height > 40 ? 10 : 7,
            strokeWidth: primary ? 1.3 : 1,
          ),
          child: Container(
            height: height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: primary
                ? palette.accentWash(accent, darkAlpha: 0.2, lightAlpha: 0.12)
                : palette.surfaceMutedFill(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: primary ? accent : ink),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: ink,
                      fontSize: height > 40 ? 13 : 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of tabs, the chosen one framed in the accent.
class BracketTabs extends StatelessWidget {
  const BracketTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
    required this.palette,
    required this.accent,
    this.icons,
  });

  final List<String> labels;
  final List<IconData>? icons;
  final int selected;
  final ValueChanged<int> onSelect;
  final BracketPalette palette;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: context.soundAction(() {
                if (i == selected) return;
                HapticFeedback.selectionClick();
                onSelect(i);
              }),
              child: CustomPaint(
                foregroundPainter: BracketFramePainter(
                  color: i == selected
                      ? accent
                      : palette.line.withValues(alpha: 0.7),
                  bracketSize: 8,
                  strokeWidth: i == selected ? 1.3 : 1,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 40,
                  alignment: Alignment.center,
                  color: i == selected
                      ? palette.accentWash(
                          accent,
                          darkAlpha: 0.18,
                          lightAlpha: 0.1,
                        )
                      : palette.surfaceMutedFill(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icons != null) ...[
                        Icon(
                          icons![i],
                          size: 14,
                          color: i == selected ? accent : palette.muted,
                        ),
                        const SizedBox(width: 7),
                      ],
                      // Shrinks rather than overflowing on a phone set to
                      // large text.
                      Flexible(
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: i == selected ? palette.ink : palette.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A small square button in a frame (back, close, remove).
class BracketIconButton extends StatelessWidget {
  const BracketIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.palette,
    this.color,
    this.size = 38,
  });

  final IconData icon;
  final VoidCallback onTap;
  final BracketPalette palette;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? palette.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        painter: BracketFramePainter(
          color: (color ?? palette.line).withValues(alpha: 0.85),
          bracketSize: size > 30 ? 8 : 6,
        ),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          color: palette.chromeMutedFill(),
          child: Icon(icon, color: c, size: size * 0.46),
        ),
      ),
    );
  }
}

/// Asks before something that cannot be undone, in the same frame as the
/// screen asking. [amounts] are what changes hands, drawn as coins.
Future<bool> showBracketConfirm(
  BuildContext context, {
  required BracketPalette palette,
  required Color accent,
  required String title,
  required String message,
  List<(CoinKind, int)> amounts = const [],
  String amountsLabel = 'YOU RECEIVE',
  String? warning,
  String confirmLabel = 'CONFIRM',
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: accent.withValues(alpha: 0.9),
          bracketSize: 14,
          strokeWidth: 1.3,
        ),
        child: Container(
          color: palette.bg1,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: accent, size: 18),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: palette.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: bracketText(ctx, 14, palette.ink.withValues(alpha: 0.9)),
              ),
              if (amounts.isNotEmpty) ...[
                const SizedBox(height: 16),
                BracketSectionDivider(label: amountsLabel),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    for (final (kind, amount) in amounts)
                      CoinAmount(
                        kind: kind,
                        amount: amount,
                        size: 20,
                        color: coinColor(kind, palette),
                      ),
                  ],
                ),
              ],
              if (warning != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      AppIcons.warning_rounded,
                      size: 13,
                      color: const Color(0xFFE57373).withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        warning,
                        style: bracketText(
                          ctx,
                          12,
                          const Color(0xFFE57373),
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: BracketButton(
                      label: 'CANCEL',
                      primary: false,
                      height: 42,
                      palette: palette,
                      accent: accent,
                      onTap: () => Navigator.of(ctx).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BracketButton(
                      label: confirmLabel,
                      height: 42,
                      palette: palette,
                      accent: accent,
                      onTap: () => Navigator.of(ctx).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}
