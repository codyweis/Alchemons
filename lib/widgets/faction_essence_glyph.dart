import 'dart:math' as math;

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Changing faction, drawn as the thing it actually is: four essences circling
/// one core, taking it in turns to be the one it answers to.
///
/// A flag or a swap arrow would say "setting"; this says allegiance. Each
/// essence dives into the core when its turn comes round, the core takes that
/// element's colour, and the loop hands on to the next — so the icon is never
/// showing one faction, which is the whole point of the offer.
class FactionEssenceGlyph extends StatefulWidget {
  const FactionEssenceGlyph({
    super.key,
    required this.size,
    this.animate = true,
  });

  final double size;

  /// Off for a still frame; a shop card scrolling past does not need to run.
  final bool animate;

  @override
  State<FactionEssenceGlyph> createState() => _FactionEssenceGlyphState();
}

class _FactionEssenceGlyphState extends State<FactionEssenceGlyph>
    with GlyphClockLease {
  @override
  bool get wantsClock => widget.animate;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
  }

  @override
  void didUpdateWidget(covariant FactionEssenceGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncGlyphClock();
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        willChange: widget.animate,
        isComplex: false,
        painter: _FactionEssencePainter(clock: glyphClock),
      ),
    );
  }
}

class _FactionEssencePainter extends CustomPainter {
  _FactionEssencePainter({required this.clock}) : super(repaint: clock);

  final ValueListenable<double>? clock;

  /// Reused across every frame and every glyph on screen.
  static final Paint _p = Paint();

  /// One full handover of all four allegiances.
  static const double _period = 7.2;

  /// Where the loop starts. A still glyph sits at t = 0 and the shop grid
  /// bakes that frame, so it starts just after a handover has landed: core
  /// fully in one faction's colour, all four essences out on the ring.
  static const double _stillPhase = 0.2125;

  /// The four playable factions, in their own colours — the same ones the
  /// harvest strip and the exchange use, so the icon is made of essences the
  /// player already recognises.
  static final List<Color> _colors = [
    for (final f in Factions.all)
      ElementResources.byBiomeId[f.id.name]?.color ?? const Color(0xFFE4C16A),
  ];

  static const _gold = Color(0xFFE0A231);

  double get _t => clock?.value ?? 0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);

    // 0..4, one unit per faction's turn.
    final u = (((_t / _period) + _stillPhase) % 1.0) * 4;
    final active = u.floor() % 4;
    final within = u - u.floor();

    final orbit = s * 0.315;
    final coreR = s * 0.115;
    // The ring turns slowly on its own so the glyph is alive even mid-hold.
    final spin = _t * 0.34;

    _band(canvas, c, orbit, s, spin, active);

    // The core takes the incoming colour once that essence has reached it.
    final coreColor = Color.lerp(
      _colors[(active + 3) % 4],
      _colors[active],
      _smoothstep(within, 0.30, 0.58),
    )!;

    for (var i = 0; i < 4; i++) {
      // How far this essence is into its own dive, 0..1 across one turn.
      final d = (u - i) % 4;
      final dive = d < 1.0 ? _dive(d) : 0.0;
      final angle = spin + i * math.pi / 2;
      final r = orbit + (coreR * 1.05 - orbit) * dive;
      _essence(canvas, c, angle, r, s, _colors[i], dive);
    }

    _core(canvas, c, coreR, coreColor, within);
  }

  /// In hard, out soft — an essence is pulled in and then released.
  double _dive(double d) => d < 0.5
      ? Curves.easeInCubic.transform(d / 0.5)
      : 1 - Curves.easeOutCubic.transform((d - 0.5) / 0.5);

  static double _smoothstep(double x, double a, double b) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// The allegiance band: a faint gold ring with a seat marked for each
  /// faction, the current seat lit.
  void _band(
    Canvas canvas,
    Offset c,
    double orbit,
    double s,
    double spin,
    int active,
  ) {
    canvas.drawCircle(
      c,
      orbit,
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012
        ..color = _gold.withValues(alpha: 0.30),
    );
    for (var i = 0; i < 4; i++) {
      final a = spin + i * math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + dir * (orbit - s * 0.035),
        c + dir * (orbit + s * 0.035),
        _p
          ..strokeWidth = s * 0.018
          ..color = _gold.withValues(alpha: i == active ? 0.85 : 0.28),
      );
    }
    _p.style = PaintingStyle.fill;
  }

  /// One essence: a head with a short tail behind it on the orbit, brightening
  /// as it is drawn in.
  void _essence(
    Canvas canvas,
    Offset c,
    double angle,
    double r,
    double s,
    Color color,
    double dive,
  ) {
    final bright = Color.lerp(color, Colors.white, 0.35 + 0.35 * dive)!;
    // Tail sweeps back along the orbit, and tightens as the essence dives.
    for (var k = 3; k >= 1; k--) {
      final a = angle - k * 0.20 * (1 - dive * 0.55);
      final pos = c + Offset(math.cos(a) * r, math.sin(a) * r);
      canvas.drawCircle(
        pos,
        s * (0.030 - k * 0.005),
        _p..color = color.withValues(alpha: 0.16 * (4 - k)),
      );
    }
    final head = c + Offset(math.cos(angle) * r, math.sin(angle) * r);
    canvas.drawCircle(
      head,
      s * (0.052 + 0.016 * dive),
      _p..color = color.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      head,
      s * (0.024 + 0.010 * dive),
      _p..color = bright,
    );
  }

  /// The allegiance itself. Flat discs rather than a blur — this draws in
  /// scrolling lists.
  void _core(Canvas canvas, Offset c, double r, Color color, double within) {
    // Swells as an essence lands, settles while it holds.
    final swell = 1 + 0.13 * (1 - _smoothstep(within, 0.30, 0.70));
    for (var i = 3; i >= 1; i--) {
      canvas.drawCircle(
        c,
        r * swell * (0.7 + 0.42 * i),
        _p..color = color.withValues(alpha: 0.13 / i),
      );
    }
    canvas.drawCircle(c, r * swell, _p..color = color.withValues(alpha: 0.95));
    canvas.drawCircle(
      c,
      r * swell * 0.46,
      _p..color = Color.lerp(color, Colors.white, 0.85)!,
    );
  }

  @override
  bool shouldRepaint(covariant _FactionEssencePainter old) =>
      old.clock != clock;
}
