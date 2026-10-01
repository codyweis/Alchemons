import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/widgets/fx/power_orb.dart';
import 'package:flutter/material.dart';

/// A power orb in a shop row or an inventory cell — the same glass sphere
/// of turning light the Enhance tray drops (see [PowerOrb]).
class AlchemicalPowerupOrbSphere extends StatelessWidget {
  final AlchemicalPowerupType type;
  final double size;

  /// Below 0.3 the orb is drawn dimmed (cannot be afforded or used).
  final double glowAlpha;

  /// Kept for older call sites; the orb draws its own light now.
  final double blurRadius;
  final double spreadRadius;

  final bool animate;

  const AlchemicalPowerupOrbSphere({
    super.key,
    required this.type,
    required this.size,
    this.glowAlpha = 0.55,
    this.blurRadius = 24,
    this.spreadRadius = 4,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) =>
      PowerOrb(type: type, size: size, lit: glowAlpha >= 0.3, animate: animate);
}
