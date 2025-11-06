import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';

class FloatingCloseButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  final Color? accentColor;
  final Color? iconColor;
  final FactionTheme theme;

  const FloatingCloseButton({
    Key? key,
    required this.onTap,
    this.size = 60,
    this.accentColor,
    this.iconColor,
    required this.theme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.text,
          border: Border.all(color: theme.text, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        width: size,
        height: size,
        child: Icon(Icons.close, color: theme.surface, size: size * 0.8),
      ),
    );
  }
}
