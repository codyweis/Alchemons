import 'package:alchemons/utils/faction_util.dart';
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
  final double selectedFillOpacity;
  final double labelFontSize;
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
    this.selectedFillOpacity = 0.08,
    this.labelFontSize = 12,
  });
  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final tokens = ForgeTokens(theme);
    final displayColor = tokens.readableAccent(color);
    final resolvedSelectedTextColor = selectedTextColor ?? displayColor;
    final resolvedUnselectedTextColor = unselectedTextColor ?? theme.text;
    final resolvedUnselectedBorderColor = unselectedBorderColor ?? theme.border;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: padding,
        decoration: BoxDecoration(
          color: selected
              ? displayColor.withValues(alpha: selectedFillOpacity)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: selected ? displayColor : resolvedUnselectedBorderColor,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 5)],
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? resolvedSelectedTextColor
                    : resolvedUnselectedTextColor,
                fontWeight: FontWeight.w700,
                fontSize: labelFontSize,
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 4), trailing!],
          ],
        ),
      ),
    );
  }
}
