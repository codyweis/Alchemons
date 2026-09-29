part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AN EMBER CORONA — fire made the way fire is
//
//  Pyrathis' corona, made reusable (the home planet's Flame Ring wears one):
//  a warm glow hugging the limb, and hundreds of embers boiling up off it
//  from flickering sources, spreading and curling as they climb, cooling
//  from gold to red and going out in the dark. Drawn behind a body so they
//  seem to rise from over its edge. Batched by stage and size: a few point
//  draws for all of them.
// ─────────────────────────────────────────────────────────────────────────────

class _EmberCorona {
  _EmberCorona(
    Random rng, {
    int sources = 38,
    int embers = 580,
    double reachMin = 0.35,
    double reachSpan = 0.9,
  }) : _sources = [
         // Where the fire rises from round the limb: (angle, strength,
         // reach, flicker phase). Uneven, so it has tongues and lulls.
         for (var i = 0; i < sources; i++)
           (
             rng.nextDouble() * 2 * pi,
             0.5 + rng.nextDouble() * 0.5,
             reachMin + pow(rng.nextDouble(), 1.5) * reachSpan,
             rng.nextDouble() * 2 * pi,
           ),
       ],
       _embers = [
         // (source, angle jitter, life period, life phase, size, curl).
         for (var i = 0; i < embers; i++)
           (
             i % sources,
             (rng.nextDouble() - 0.5) * 0.07,
             1.4 + rng.nextDouble() * 1.6,
             rng.nextDouble(),
             0.6 + rng.nextDouble() * 0.8,
             (rng.nextDouble() - 0.5) * 0.12,
           ),
       ];

  /// An ember's colour as it cools, newest first, and how strongly it
  /// shows at each stage.
  static const _stages = [
    (Color(0xFFFFE6A0), 0.95),
    (Color(0xFFFFA23A), 0.85),
    (Color(0xFFEE5A1A), 0.6),
    (Color(0xFFA8260A), 0.3),
  ];

  final List<(double, double, double, double)> _sources;
  final List<(int, double, double, double, double, double)> _embers;
  final _DotBatch _out = _DotBatch(8);

  /// [pace] scales how fast the embers climb; [alpha] how strongly it all
  /// shows.
  void paint(
    Canvas c,
    Offset p,
    double r,
    double t, {
    double alpha = 1,
    double pace = 1,
  }) {
    // The body of the corona the embers rise through.
    final corona = r * 1.55;
    c.drawCircle(
      p,
      corona,
      Paint()
        ..shader = ui.Gradient.radial(
          p,
          corona,
          [
            const Color(0xFFFF8A2A).withValues(alpha: 0.5 * alpha),
            const Color(0xFFE8521A).withValues(alpha: 0.22 * alpha),
            const Color(0xFFB8260A).withValues(alpha: 0),
          ],
          [r / corona, (r / corona + 1) / 2, 1.0],
        ),
    );

    final tt = t * pace;
    _out.clear();
    for (final (src, jitter, period, phase, size, curl) in _embers) {
      final (a0, strength, reach, fph) = _sources[src];
      final flare = 0.6 + 0.4 * sin(t * 1.7 + fph) * sin(t * 0.9 + fph * 2);
      final life = (tt / period + phase) % 1.0;
      // Spreading as they climb, and curling.
      final a =
          a0 + t * 0.015 + jitter * (0.4 + 1.6 * life) + curl * life * life * 4;
      final rise = r * reach * strength * flare * pow(life, 0.8);
      final dist = r * 0.95 + rise;
      final er = size * (0.6 + 0.4 * strength) * (1 - life * 0.7);
      if (er < 0.25) continue;
      final stage = min(_stages.length - 1, (life * _stages.length).floor());
      _out.add(
        stage * 2 + (er > 0.7 ? 1 : 0),
        p.dx + cos(a) * dist,
        p.dy + sin(a) * dist,
      );
    }
    // Embers keep a readable size on a small world.
    final unit = max(r * 0.02, 1.4);
    for (var k = _stages.length - 1; k >= 0; k--) {
      final (col, a) = _stages[k];
      for (var sz = 0; sz < 2; sz++) {
        final d = unit * (sz == 0 ? 0.5 : 0.95) * 2;
        _out.draw(
          c,
          k * 2 + sz,
          d * 2.0,
          col.withValues(alpha: a * 0.1 * alpha),
        );
        _out.draw(c, k * 2 + sz, d, col.withValues(alpha: a * alpha));
      }
    }
  }
}
