import 'package:alchemons/utils/faction_util.dart';
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
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.bg2,
        border: Border(top: BorderSide(color: tokens.borderDim)),
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
  });

  final ForgeTokens tokens;
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final CultivationDialogButtonEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final highlighted = emphasis == CultivationDialogButtonEmphasis.primary;
    final destructive = emphasis == CultivationDialogButtonEmphasis.danger;
    final baseColor = destructive ? tokens.danger : accentColor;
    final backgroundColor = highlighted
        ? baseColor.withValues(alpha: tokens.isDark ? 0.14 : 0.10)
        : tokens.bg1;
    final borderColor = baseColor.withValues(alpha: highlighted ? 0.55 : 0.35);
    final foregroundColor = destructive
        ? tokens.danger
        : highlighted
        ? baseColor
        : accentColor;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(3),
      child: InkWell(
        borderRadius: BorderRadius.circular(3),
        onTap: onTap,
        splashColor: baseColor.withValues(alpha: 0.12),
        highlightColor: baseColor.withValues(alpha: 0.06),
        child: Ink(
          height: 46,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: borderColor),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: foregroundColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: foregroundColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum CultivationDialogButtonEmphasis { primary, secondary, danger }
