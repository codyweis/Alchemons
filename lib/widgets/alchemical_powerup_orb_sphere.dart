import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:flutter/material.dart';

class AlchemicalPowerupOrbSphere extends StatelessWidget {
  final AlchemicalPowerupType type;
  final double size;
  final double glowAlpha;
  final double blurRadius;
  final double spreadRadius;

  const AlchemicalPowerupOrbSphere({
    super.key,
    required this.type,
    required this.size,
    this.glowAlpha = 0.55,
    this.blurRadius = 24,
    this.spreadRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.94),
              type.color.withValues(alpha: 0.88),
              type.glowColor.withValues(alpha: 0.36),
              Colors.transparent,
            ],
            stops: const [0.0, 0.30, 0.66, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: type.glowColor.withValues(alpha: glowAlpha),
              blurRadius: blurRadius,
              spreadRadius: spreadRadius,
            ),
          ],
        ),
      ),
    );
  }
}
