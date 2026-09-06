import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/utils/faction_util.dart';

/// Corner-bracket frame painter shared by the bracket-style UI surfaces
/// (inventory, battle tab, …). Draws four L-shaped marks at each corner
/// instead of a continuous border.
class BracketFramePainter extends CustomPainter {
  const BracketFramePainter({
    required this.color,
    this.bracketSize = 10,
    this.strokeWidth = 1,
  });

  final Color color;
  final double bracketSize;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final s = bracketSize;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, s)
      ..lineTo(0, 0)
      ..lineTo(s, 0)
      ..moveTo(w - s, 0)
      ..lineTo(w, 0)
      ..lineTo(w, s)
      ..moveTo(0, h - s)
      ..lineTo(0, h)
      ..lineTo(s, h)
      ..moveTo(w - s, h)
      ..lineTo(w, h)
      ..lineTo(w, h - s);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BracketFramePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.bracketSize != bracketSize ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Brightness-aware palette for the bracket-frame UI style.
///
/// Use [BracketPalette.of] inside widget build methods to resolve from the
/// ambient [FactionTheme], or [BracketPalette.fromTheme] when you already
/// have a theme in hand.
class BracketPalette {
  final bool isDark;
  final Color bg0;
  final Color bg1;
  final Color ink;
  final Color muted;
  final Color line;
  final Color lineSoft;

  const BracketPalette({
    required this.isDark,
    required this.bg0,
    required this.bg1,
    required this.ink,
    required this.muted,
    required this.line,
    required this.lineSoft,
  });

  static const dark = BracketPalette(
    isDark: true,
    bg0: Color(0xFF080A0E),
    bg1: Color(0xFF0E1117),
    ink: Color(0xFFE8DCC8),
    muted: Color(0xFF9A8D7C),
    line: Color(0xFF384150),
    lineSoft: Color(0xFF252D3A),
  );

  static const light = BracketPalette(
    isDark: false,
    bg0: Color(0xFFF2EBDD),
    bg1: Color(0xFFFFFBF4),
    ink: Color(0xFF201910),
    muted: Color(0xFF665946),
    line: Color(0xFF8A7961),
    lineSoft: Color(0xFFD9CDB8),
  );

  static BracketPalette of(BuildContext context) =>
      fromTheme(context.read<FactionTheme>());

  static BracketPalette fromTheme(FactionTheme theme) =>
      theme.brightness == Brightness.dark ? dark : light;

  Color surfaceFill({double darkAlpha = 0.72, double lightAlpha = 0.94}) =>
      bg1.withValues(alpha: isDark ? darkAlpha : lightAlpha);

  Color surfaceMutedFill({double darkAlpha = 0.55, double lightAlpha = 0.90}) =>
      bg1.withValues(alpha: isDark ? darkAlpha : lightAlpha);

  Color chromeFill({double darkAlpha = 0.88, double lightAlpha = 0.97}) =>
      bg0.withValues(alpha: isDark ? darkAlpha : lightAlpha);

  Color chromeMutedFill({double darkAlpha = 0.55, double lightAlpha = 0.92}) =>
      bg0.withValues(alpha: isDark ? darkAlpha : lightAlpha);

  Color accentWash(
    Color accent, {
    double darkAlpha = 0.14,
    double lightAlpha = 0.08,
  }) => accent.withValues(alpha: isDark ? darkAlpha : lightAlpha);
}

Color bracketReadableAccent(FactionTheme theme, {Color? color}) {
  return ForgeTokens(theme).readableAccent(color ?? theme.accentSoft);
}

/// Text style helper that pairs with the bracket-frame palette. Uses the
/// ambient text theme's [bodyMedium] as a base so the look stays consistent
/// across screens.
TextStyle bracketText(
  BuildContext context,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w500,
  double letterSpacing = 0,
  FontStyle fontStyle = FontStyle.normal,
}) {
  final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
  return base.copyWith(
    color: color,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
  );
}

/// Section divider used between content blocks in the bracket-frame style:
/// two thin rules with a centered label between them.
class BracketSectionDivider extends StatelessWidget {
  const BracketSectionDivider({
    super.key,
    required this.label,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  final String label;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: palette.lineSoft)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: bracketText(
                context,
                12,
                palette.muted,
                weight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: palette.lineSoft)),
        ],
      ),
    );
  }
}

/// A bracket-framed container that handles the painter + background fill
/// pattern in one place.
class BracketCard extends StatelessWidget {
  const BracketCard({
    super.key,
    required this.child,
    this.frameColor,
    this.fillColor,
    this.padding,
    this.bracketSize = 10,
    this.strokeWidth = 1.05,
    this.alpha = 0.72,
  });

  final Widget child;
  final Color? frameColor;
  final Color? fillColor;
  final EdgeInsetsGeometry? padding;
  final double bracketSize;
  final double strokeWidth;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return CustomPaint(
      painter: BracketFramePainter(
        color: (frameColor ?? palette.line).withValues(alpha: 0.9),
        bracketSize: bracketSize,
        strokeWidth: strokeWidth,
      ),
      child: Container(
        color: fillColor ?? palette.surfaceFill(lightAlpha: alpha),
        padding: padding,
        child: child,
      ),
    );
  }
}
