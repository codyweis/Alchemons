import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';

class CultivationDialogActionArea extends StatelessWidget {
  const CultivationDialogActionArea({
    super.key,
    required this.tokens,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  final ForgeTokens tokens;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surfaceFill(),
        border: Border(
          top: BorderSide(color: palette.lineSoft.withValues(alpha: 0.7)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class CultivationDialogButton extends StatelessWidget {
  const CultivationDialogButton({
    super.key,
    required this.tokens,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.emphasis = CultivationDialogButtonEmphasis.secondary,
    this.useSolidBackground = false,
    this.foregroundColor,
    this.large = false,
  });

  final ForgeTokens tokens;
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final CultivationDialogButtonEmphasis emphasis;
  final bool useSolidBackground;
  final Color? foregroundColor;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final highlighted = emphasis == CultivationDialogButtonEmphasis.primary;
    final destructive = emphasis == CultivationDialogButtonEmphasis.danger;
    final baseColor = destructive ? tokens.danger : accentColor;
    final filled = (useSolidBackground || highlighted) && !destructive;

    final frameColor = filled
        ? baseColor
        : baseColor.withValues(alpha: destructive ? 0.55 : 0.6);
    final fillColor = filled
        ? baseColor
        : (destructive
              ? palette.accentWash(baseColor)
              : palette.surfaceMutedFill());
    final resolvedForegroundColor = foregroundColor ??
        (filled ? Colors.white : (destructive ? tokens.danger : palette.ink));
    final accentColorOnFill = filled ? Colors.white : baseColor;

    final height = large ? 54.0 : 42.0;
    final iconSize = large ? 17.0 : 14.0;
    final fontSize = large ? 15.0 : 13.0;
    final bracketSize = large ? 11.0 : 8.0;
    final strokeWidth = large ? 1.5 : (filled ? 1.3 : 1.1);

    Widget button = CustomPaint(
      painter: BracketFramePainter(
        color: frameColor,
        bracketSize: bracketSize,
        strokeWidth: strokeWidth,
      ),
      child: Container(
        height: height,
        color: fillColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: accentColorOnFill),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bracketText(
                  context,
                  fontSize,
                  resolvedForegroundColor,
                  weight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (large && filled) {
      button = DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: baseColor.withValues(alpha: 0.30),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: button,
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: button,
    );
  }
}

enum CultivationDialogButtonEmphasis { primary, secondary, danger }
