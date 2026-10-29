import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Pale brass, the kit's accent on ink.
const Color kGrainLoaderBrass = Color(0xFFCDB07A);

/// The game's wait, in place of a spinner: a small sphere of grains that
/// gathers, runs and loosens again for as long as something is loading.
class GrainLoader extends StatelessWidget {
  const GrainLoader({super.key, this.size = 44, this.color});

  final double size;

  /// The grains' light; pale brass when null.
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: GrainGlyph(
      size: size,
      animate: true,
      painter: (clock) => _GrainLoaderPainter(clock, color ?? kGrainLoaderBrass),
    ),
  );
}

/// A whole screen that is still loading: ink, and the loader low of centre.
class GrainLoadingScreen extends StatelessWidget {
  const GrainLoadingScreen({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF09090B),
    child: Center(child: GrainLoader(size: 72, color: color)),
  );
}

class _GrainLoaderPainter extends CustomPainter {
  _GrainLoaderPainter(this.clock, this.color) : super(repaint: clock);

  final ValueListenable<double>? clock;
  final Color color;

  static const double _period = 3.2;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final t = clock?.value ?? 0;
    final beat = (t % _period) / _period;

    // Never fully gone: it draws in over the first half and loosens over
    // the second, so the wait reads as one breath rather than a blink.
    final hold =
        GrainGlass.smooth(beat / 0.5) *
        (1 - GrainGlass.smooth((beat - 0.62) / 0.38));
    // Small ones sit in a button's text line, where the glow may spill.
    final small = s < 28;
    GrainGlass.sphere(
      canvas,
      Offset(s / 2, s / 2),
      s * (small ? 0.36 : 0.27),
      t,
      a: color,
      spin: 1.3,
      gather: 0.4 + 0.6 * hold,
      glass: small ? 0.5 : 0.8,
      density: small ? 0.55 : 1,
      glow: 0.55 + 0.45 * hold,
    );
  }

  @override
  bool shouldRepaint(covariant _GrainLoaderPainter old) =>
      old.clock != clock || old.color != color;
}
