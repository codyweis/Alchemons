import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// An extra Alchemy Chamber, drawn as the chambers themselves.
///
/// A chamber is a sphere of its two parents' grains turning against each
/// other (the cultivation sphere). Two are running at the back; a third, in
/// front, gathers itself out of loose grains and starts to turn — you had
/// two chambers, here is the next one coming online.
class FusionChamberGlyph extends StatelessWidget {
  const FusionChamberGlyph({
    super.key,
    required this.size,
    this.animate = true,
  });

  final double size;

  /// Off for a still frame; a shop card scrolling past does not need to run.
  final bool animate;

  @override
  Widget build(BuildContext context) => GrainGlyph(
    size: size,
    animate: animate,
    painter: (clock) => _FusionChamberPainter(clock),
  );
}

class _FusionChamberPainter extends CustomPainter {
  _FusionChamberPainter(this.clock) : super(repaint: clock);

  final ValueListenable<double>? clock;

  /// The new chamber gathering, running, and letting go.
  static const double _period = 6.4;

  /// A still glyph shows all three running: three chambers is what is sold.
  static const double _still = 0.66 * _period;

  static Color _c(String id) => ElementResources.byBiomeId[id]!.color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final t = (clock?.value ?? 0) + _still;
    final beat = (t % _period) / _period;
    final o = Offset(size.width / 2, size.height / 2);

    // Gathers over the first half, runs, then loosens back into grains.
    final gather =
        GrainGlass.smooth(beat / 0.5) *
        (1 - GrainGlass.smooth((beat - 0.88) / 0.12));

    // The two running, further back and a little smaller.
    GrainGlass.sphere(
      canvas,
      o + Offset(-s * 0.21, -s * 0.15),
      s * 0.2,
      t,
      a: _c('volcanic'),
      b: _c('verdant'),
      spin: 0.9,
      fade: 0.88,
      glow: 0.8,
      salt: 1,
    );
    GrainGlass.sphere(
      canvas,
      o + Offset(s * 0.23, -s * 0.1),
      s * 0.17,
      t,
      a: _c('oceanic'),
      b: _c('arcane'),
      spin: 1.0,
      fade: 0.88,
      glow: 0.8,
      salt: 2,
    );
    // The new one, in front.
    GrainGlass.sphere(
      canvas,
      o + Offset(-s * 0.01, s * 0.18),
      s * 0.235,
      t,
      a: _c('arcane'),
      b: _c('volcanic'),
      spin: 0.8,
      gather: gather,
      glass: gather,
      salt: 3,
    );
  }

  @override
  bool shouldRepaint(covariant _FusionChamberPainter old) =>
      old.clock != clock;
}
