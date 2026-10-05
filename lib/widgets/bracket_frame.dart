import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/audio/audio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/utils/faction_util.dart';

/// The frame the panels, buttons, tabs and cards share. An ordinary thing
/// wears no frame — its fill is enough — and a chosen one is lit from below:
/// a sill of light along its bottom edge, fading at both ends, and a glow
/// rising off it. (It drew four corner brackets until 2026-10.)
///
/// Whether a frame is chosen is read from the colour its caller passes. One
/// of the palettes' own greys is an ordinary frame and draws nothing. A
/// colour of its own lights up as it nears full strength, so a frame faded
/// to say "not this one" stays dark, and one whose strength is animated
/// brightens smoothly rather than switching on.
class BracketFramePainter extends CustomPainter {
  const BracketFramePainter({
    required this.color,
    this.bracketSize = 10,
    this.strokeWidth = 1,
  });

  final Color color;

  /// The length the corner brackets were; unused since they went, kept so
  /// the callers still read as they did.
  final double bracketSize;

  /// A heavier frame gets a thicker sill.
  final double strokeWidth;

  /// The greys callers pass for an ordinary frame.
  static final _plain = {
    for (final p in const [BracketPalette.dark, BracketPalette.light])
      for (final c in [p.line, p.lineSoft, p.muted]) c.toARGB32(),
    0xFF3A3A48, // the survival HUD's line (HudInk.line)
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (_plain.contains(color.toARGB32() | 0xFF000000)) return;
    final t = ((color.a - 0.55) / 0.25).clamp(0.0, 1.0);
    final lit = color.a * t * t * (3 - 2 * t);
    if (lit < 0.01) return;

    final w = size.width, h = size.height;
    final tone = color.withValues(alpha: 1);
    final hot = Color.lerp(tone, Colors.white, 0.4)!;
    final sill = 1.4 + 0.6 * ((strokeWidth - 1) / 0.6).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(0, h - sill * 0.5, w, sill),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(w, 0), [
          tone.withValues(alpha: 0),
          hot.withValues(alpha: lit),
          hot.withValues(alpha: lit),
          tone.withValues(alpha: 0),
        ], const [0, 0.3, 0.7, 1]),
    );
    final rise = math.min(h * 0.75, 40.0);
    canvas.drawRect(
      Rect.fromLTWH(0, h - rise, w, rise),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, h), Offset(0, h - rise), [
          tone.withValues(alpha: 0.2 * lit),
          tone.withValues(alpha: 0),
        ]),
    );
  }

  @override
  bool shouldRepaint(covariant BracketFramePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.bracketSize != bracketSize ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Brightness-aware palette for the bracket-frame UI style: warm obsidian
/// in the dark (it was a cool navy until 2026-10).
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
    bg0: Color(0xFF0A0806),
    bg1: Color(0xFF15110D),
    ink: Color(0xFFE8DCC8),
    muted: Color(0xFF9A8D7C),
    line: Color(0xFF6E5B40),
    lineSoft: Color(0xFF2C241A),
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

/// A framed container that handles the painter + background fill pattern in
/// one place.
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

/// Top-of-list control chip in the bracket-frame language: a soft
/// accent-washed pill, lit from below when it is the active control.
///
/// Lives here rather than in a single screen because the specimens grid and
/// the per-species specimens sheet both present the same row of controls, and
/// when each kept its own copy the two drifted apart -- the sheet was still
/// wearing rounded borders and a hard-coded teal while the grid had moved to
/// brackets.
class BracketControlChip extends StatelessWidget {
  const BracketControlChip({
    super.key,
    required this.label,
    required this.accentColor,
    required this.selected,
    required this.onTap,
    required this.theme,
    this.labelFontSize = 10.5,
    this.leading,
    this.trailing,
    this.showBracketWhenSelected = false,
  });

  final String label;
  final Color accentColor;
  final bool selected;
  final VoidCallback onTap;
  final FactionTheme theme;
  final double labelFontSize;
  final Widget? leading;
  final Widget? trailing;
  final bool showBracketWhenSelected;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.fromTheme(theme);
    final tokens = ForgeTokens(theme);
    final displayColor = tokens.readableAccent(accentColor);

    final fillColor = selected
        ? displayColor.withValues(alpha: palette.isDark ? 0.13 : 0.10)
        : Colors.transparent;
    final textColor = selected ? displayColor : palette.muted;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      color: fillColor,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 5)],
          Text(
            label,
            style: bracketText(
              context,
              labelFontSize,
              textColor,
              weight: selected ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );

    return GestureDetector(
      onTap: context.soundAction(onTap),
      behavior: HitTestBehavior.opaque,
      child: showBracketWhenSelected && selected
          ? CustomPaint(
              painter: BracketFramePainter(
                color: displayColor,
                bracketSize: 6,
                strokeWidth: 1.1,
              ),
              child: content,
            )
          : content,
    );
  }
}
