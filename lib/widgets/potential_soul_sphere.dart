import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter/material.dart';

/// Shared code-native artwork for Potential Souls in inventory and rewards.
class PotentialSoulSphere extends StatelessWidget {
  const PotentialSoulSphere({super.key, this.size = 48, this.tint});

  final double size;

  /// Recolours the mid-gradient so a soul can be shown per-stat (the Stat
  /// Infusion soul tray). Null keeps the canonical violet used everywhere
  /// else, so existing call sites are untouched.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.82,
            height: size * 0.82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.28, -0.34),
                colors: [
                  const Color(0xFFFFFFFF),
                  const Color(0xFFFFE59A),
                  tint ?? const Color(0xFFB66CFF),
                  const Color(0xFF3C176B),
                ],
                stops: const [0.0, 0.18, 0.58, 1.0],
              ),
              border: Border.all(
                color: const Color(0xFFFFE9A8),
                width: size * 0.035,
              ),
              boxShadow: [
                BoxShadow(
                  color: (tint ?? const Color(0xFFB66CFF))
                      .withValues(alpha: 0.65),
                  blurRadius: size * 0.26,
                  spreadRadius: size * 0.03,
                ),
              ],
            ),
          ),
          Icon(
            AppIcons.diamond_rounded,
            size: size * 0.38,
            color: const Color(0xFFFFF6D2),
            shadows: const [Shadow(color: Color(0xFF50207A), blurRadius: 5)],
          ),
          Positioned(
            top: size * 0.04,
            right: size * 0.10,
            child: Icon(
              AppIcons.auto_awesome_rounded,
              size: size * 0.22,
              color: const Color(0xFFFFF1AC),
            ),
          ),
        ],
      ),
    );
  }
}
