// widgets/particle_background_scaffold.dart
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';

class ParticleBackgroundScaffold extends StatelessWidget {
  /// The main content of your screen.
  final Widget body;

  /// Set to true if your body is a Column/ListView that needs
  /// to avoid the bottom system navigation area.
  final bool avoidBottomInset;

  /// Show/hide the particle layer entirely.
  final bool showParticles;

  /// Optional solid background behind particles (or behind content if particles are off).
  /// If null, defaults to black unless [whiteBackground] is true.
  final Color? backgroundColor;

  /// Convenience toggle for a white background.
  /// If [backgroundColor] is set, it takes precedence.
  final bool whiteBackground;

  /// Particle layer opacity (0..1).
  final double particleOpacity;

  /// Optional override palette for particles.
  final List<Color>? particleColors;

  const ParticleBackgroundScaffold({
    super.key,
    required this.body,
    this.avoidBottomInset = true,
    this.showParticles = true,
    this.backgroundColor,
    this.whiteBackground = false,
    this.particleOpacity = 1.0,
    this.particleColors,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor =
        backgroundColor ?? (whiteBackground ? Colors.white : Colors.black);

    return Stack(
      children: [
        // The solid base (defaults to black)
        Container(color: baseColor),

        // The animated particles (optional, route-aware)
        if (showParticles)
          AlchemicalParticleBackground(
            opacity: particleOpacity,
            colors: particleColors,
            backgroundColor: null, // keep transparent over the base color
            whiteBackground: false, // base handles this
          ),

        // Your actual screen content
        Scaffold(backgroundColor: Colors.transparent, body: body),
      ],
    );
  }
}
