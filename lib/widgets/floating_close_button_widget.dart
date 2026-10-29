import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';

/// The close button that floats at the foot of a screen: the kit's bare
/// bracket button, so it reads as the same control as every other close.
class FloatingCloseButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  final Color? accentColor;
  final Color? iconColor;
  final FactionTheme theme;

  const FloatingCloseButton({
    super.key,
    required this.onTap,
    this.size = 48,
    this.accentColor,
    this.iconColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return BracketIconButton(
      icon: AppIcons.close,
      onTap: onTap,
      palette: BracketPalette.dark,
      color: iconColor ?? accentColor,
      size: size,
    );
  }
}
