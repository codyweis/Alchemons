import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FilterChipSolid extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;
  final Color? unselectedBorderColor;
  final Color? unselectedFillColor;
  final double selectedFillOpacity;
  final double labelFontSize;
  final bool showUnselectedBracket;
  const FilterChipSolid({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    this.selectedTextColor,
    this.unselectedTextColor,
    this.unselectedBorderColor,
    this.unselectedFillColor,
    this.selectedFillOpacity = 0.18,
    this.labelFontSize = 12,
    this.showUnselectedBracket = true,
  });
  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final tokens = ForgeTokens(theme);
    final displayColor = tokens.readableAccent(color);
    final resolvedSelectedTextColor = selectedTextColor ?? displayColor;
    final resolvedUnselectedTextColor = unselectedTextColor ?? palette.muted;
    final frameColor = selected
        ? displayColor
        : (unselectedBorderColor ?? palette.line.withValues(alpha: 0.55));
    final fillColor = selected
        ? palette.accentWash(
            displayColor,
            darkAlpha: selectedFillOpacity,
            lightAlpha: selectedFillOpacity * 0.6,
          )
        : (unselectedFillColor ??
              (palette.isDark
                  ? Colors.transparent
                  : palette.surfaceMutedFill()));
    final content = Container(
      padding: padding,
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
              selected
                  ? resolvedSelectedTextColor
                  : resolvedUnselectedTextColor,
              weight: selected ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: selected || showUnselectedBracket
          ? CustomPaint(
              painter: BracketFramePainter(
                color: frameColor,
                bracketSize: 7,
                strokeWidth: selected ? 1.2 : 1.0,
              ),
              child: content,
            )
          : content,
    );
  }
}
