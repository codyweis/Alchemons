import 'package:flutter/material.dart';

/// Wrap your GameWidget (or any subtree) to apply a night tint.
/// intensity: 0.0 (day) → 1.0 (full night)
/// tint: the color bias at night (cool blue works great).
class DayNightFilter extends StatelessWidget {
  const DayNightFilter({
    super.key,
    required this.child,
    required this.intensity,
    this.tint = const Color(0xFF0C1740), // deep cool blue
    this.minLuma = 0.70, // percentage brightness when fully night
  });

  final Widget child;
  final double intensity; // 0..1
  final Color tint;
  final double minLuma;

  @override
  Widget build(BuildContext context) {
    // Clamp
    final t = intensity.clamp(0.0, 1.0);

    // 1) Darken: luma multiplier from 1.0 → minLuma
    final luma = (1.0 - t) + (t * minLuma);

    // 2) Colorize: overlay a tint with Multiply that ramps with t
    // We apply Multiply via ShaderMask. It’s cheap and works on the child.
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_brightnessMatrix(luma)),
      child: ShaderMask(
        shaderCallback: (rect) {
          final c = tint.withOpacity(0.35 * t); // feel free to tweak
          return LinearGradient(colors: [c, c]).createShader(rect);
        },
        blendMode: BlendMode.multiply,
        child: child,
      ),
    );
  }

  /// Simple brightness matrix (scale RGB by `luma`, keep alpha).
  List<double> _brightnessMatrix(double luma) => <double>[
    luma,
    0,
    0,
    0,
    0,
    0,
    luma,
    0,
    0,
    0,
    0,
    0,
    luma,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}
