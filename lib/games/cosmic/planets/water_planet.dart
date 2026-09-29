part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AQUATHOS — the Water planet: a glossy ocean world with a moon
//
//  The original, restored and deepened: a deep blue sphere with bands of
//  lighter water rolling across it — bowed now, so they wrap round the
//  sphere instead of lying flat across it — caustic light shimmering on the
//  surface, the far side falling into night, a wet highlight on the lit
//  shoulder and a luminous rim of atmosphere, inside the glow every planet
//  wore. The soft shapes that were blur passes are gradients of the same
//  softness now.
//
//  The moon is the one the tide dungeon runs on; its orbit and phase are
//  unchanged from the original painter (test/cosmic_water_moon_test.dart
//  mirrors the numbers). It is drawn as a shaded sphere now — soft maria,
//  low craters, a soft terminator — where it was a flat disc with stamped
//  craters and an outline ("cartoony").
//
//  Tried and cut (2026-09-28/29): soft cloud streamers with a glint, a
//  spiral cyclone, islands under cumulus (all "cheesy"), and a net of
//  caustic light over the deep (read as cracked tiles, not water).
// ─────────────────────────────────────────────────────────────────────────────

/// Aquathos' moon: how big, how fast, and where its light comes from.
///
/// A third the size of the planet, which is the size a moon has to be to
/// read as a moon in a sky this busy rather than as a passing rock.
const double _kMoonScale = 0.30;
const double _kMoonSpeed = 0.22;
const double _kMoonLightAngle = -2.356; // upper left, as everything here is

class WaterPlanetArt extends PlanetArt {
  WaterPlanetArt._(this._caustics);

  factory WaterPlanetArt(int seed) {
    // The original seeded this from the planet's position every frame, so
    // the layout was constant; worked out once here.
    final rng = Random(seed);
    return WaterPlanetArt._([
      for (var i = 0; i < 8; i++)
        ((rng.nextDouble() - 0.5) * 1.4, (rng.nextDouble() - 0.5) * 1.4),
    ]);
  }

  static const _col = Color(0xFF448AFF);

  /// Caustic spots, as offsets in radii.
  final List<(double, double)> _caustics;

  @override
  void paintBack(Canvas c, Offset p, double r, double t) {
    _oldAura(c, p, r, _col);
    _moon(c, p, r, t, front: false);
  }

  @override
  void paintFront(Canvas c, Offset p, double r, double t) =>
      _moon(c, p, r, t, front: true);

  @override
  void paintBody(Canvas c, Offset p, double r, double t) {
    _oldSphere(c, p, r, const Color(0xFF0D47A1), highlight: 0.3, shadow: 0.5);

    c.save();
    _clipDisc(c, p, r);
    // Bands of lighter water rolling across.
    const waveLayers = 5;
    for (var w = 0; w < waveLayers; w++) {
      final waveY = p.dy - r + (2 * r) * (w + 0.5) / waveLayers;
      final waveColor = Color.lerp(
        const Color(0xFF1565C0),
        const Color(0xFF42A5F5),
        w / waveLayers,
      )!;
      final amplitude = r * (0.06 + 0.03 * sin(t * 0.7 + w));
      final freq = 3.0 + w * 0.5;
      final speed = 1.2 + w * 0.3;
      final wave = Path()..moveTo(p.dx - r - 10, waveY);
      for (var x = -r - 10; x <= r + 10; x += 4) {
        // Bowed like a latitude seen on a sphere whose pole leans toward
        // the viewer, so the bands wrap round the planet instead of lying
        // flat across it.
        final u = (x / r).clamp(-1.0, 1.0);
        final bow = r * 0.16 * sqrt(max(0.0, 1 - u * u));
        final wy =
            waveY +
            bow +
            sin(x / r * freq * pi + t * speed) * amplitude +
            cos(x / r * (freq + 1) * pi + t * speed * 0.7 + w) *
                amplitude *
                0.5;
        wave.lineTo(p.dx + x, wy);
      }
      wave
        ..lineTo(p.dx + r + 10, p.dy + r + 10)
        ..lineTo(p.dx - r - 10, p.dy + r + 10)
        ..close();
      c.drawPath(
        wave,
        Paint()..color = waveColor.withValues(alpha: 0.25 + 0.05 * w),
      );
    }
    // Caustics shimmering on the surface.
    for (var i = 0; i < _caustics.length; i++) {
      final (ox, oy) = _caustics[i];
      final phase = t * 1.5 + i * 0.9;
      final cr = r * (0.06 + 0.04 * sin(phase));
      final alpha = (0.15 + 0.1 * sin(phase + 1.0)).clamp(0.0, 1.0);
      _softCircle(
        c,
        Offset(
          p.dx + ox * r + sin(phase * 0.6) * r * 0.05,
          p.dy + oy * r + cos(phase * 0.8) * r * 0.05,
        ),
        cr,
        const Color(0xFFFFFFFF).withValues(alpha: alpha),
        cr,
      );
    }
    // The far side into night.
    _shade(c, p, r, strength: 0.7, night: const Color(0xFF01040E));
    c.restore();

    // The wet highlight: a soft flattened pool on the lit shoulder.
    final specR = r * 0.35;
    c.save();
    c.translate(p.dx - r * 0.3, p.dy - r * 0.3);
    c.scale(1, 0.5);
    _softCircle(
      c,
      Offset.zero,
      specR * 0.8,
      const Color(0xFFFFFFFF).withValues(alpha: 0.18 + 0.05 * sin(t * 0.8)),
      specR * 0.4,
    );
    c.restore();

    // Faint atmosphere, and a luminous rim of it on the limb.
    _softCircle(
      c,
      p,
      r * 1.25,
      const Color(0xFF1E88E5).withValues(alpha: 0.05 + 0.02 * sin(t * 0.6)),
      r * 0.4,
    );
    _limb(
      c,
      p,
      r,
      const Color(0xFF7ABDFF),
      alpha: 0.34,
      inner: 0.88,
      outer: 1.08,
    );
  }

  /// AQUATHOS HAS A MOON, and the tide dungeon down there runs on its
  /// phases. It orbits properly: the far half of the ellipse is drawn before
  /// the body and the near half after, so it goes behind and comes back
  /// round. The phase turns with the orbit, since the light in this sky
  /// comes from the upper left and the moon is lit by whatever side of it
  /// faces that way.
  void _moon(Canvas c, Offset p, double r, double t, {required bool front}) {
    final mr = r * _kMoonScale;
    final a = t * _kMoonSpeed;
    // Tilted ellipse, so it reads as an orbit rather than a circle drawn
    // flat on the screen.
    final at = p + Offset(cos(a) * r * 1.95, sin(a) * r * 0.62 - r * 0.28);
    // Coming toward the viewer on the bottom half of the sweep.
    if ((sin(a) > 0) != front) return;

    // The lit side faces the same corner every planet here is lit from.
    const lightDir = Offset(-0.707, -0.707);
    const dark = Color(0xFF151A22);

    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: at, radius: mr)));
    // A shaded sphere, not a flat disc.
    c.drawCircle(
      at,
      mr,
      Paint()
        ..shader = ui.Gradient.radial(
          at + lightDir * (mr * 0.45),
          mr * 1.7,
          const [Color(0xFFDDE2E9), Color(0xFFB6BEC9), Color(0xFF7C8592)],
          const [0.0, 0.5, 1.0],
        ),
    );
    // Maria: soft darker seas, not stamped circles. Fixed, so the face does
    // not boil between frames.
    const maria = [
      (-0.22, -0.18, 0.34),
      (0.18, 0.08, 0.26),
      (-0.05, 0.34, 0.2),
      (0.34, -0.3, 0.14),
    ];
    for (final (dx, dy, k) in maria) {
      _softCircle(
        c,
        at + Offset(dx * mr, dy * mr),
        mr * k,
        const Color(0xFF80838A).withValues(alpha: 0.45),
        mr * 0.08,
      );
    }
    // A few small craters, low contrast: a shaded bowl with its far rim lit.
    const craters = [(0.3, 0.32, 0.09), (-0.4, 0.2, 0.07), (0.05, -0.45, 0.06)];
    for (final (dx, dy, k) in craters) {
      final cc = at + Offset(dx * mr, dy * mr);
      c.drawCircle(
        cc,
        mr * k,
        Paint()..color = const Color(0xFF6E7784).withValues(alpha: 0.35),
      );
      c.drawCircle(
        cc - lightDir * (mr * k * 0.3),
        mr * k * 0.7,
        Paint()..color = const Color(0xFFE6EAF0).withValues(alpha: 0.18),
      );
    }

    // THE PHASE. A shadow disc slid along the light axis: centred on the
    // moon it covers the whole face (new), pushed a diameter down-shadow it
    // clears it entirely (full), and everything between is a crescent whose
    // lit limb faces the light. It is lit by how far round it is FROM the
    // light, not by the cosine of it. Its edge is soft, as a terminator is,
    // and the dark side keeps a faint earthshine.
    final illum = (1 - cos(a - _kMoonLightAngle)) / 2;
    _softCircle(
      c,
      at - lightDir * (illum * mr * 2.1),
      mr * 1.04,
      dark.withValues(alpha: 0.88),
      mr * 0.05,
    );
    c.restore();

    // A faint limb so it keeps its edge against the void.
    final outer = mr * 1.08;
    c.drawCircle(
      at,
      outer,
      Paint()
        ..shader = ui.Gradient.radial(
          at,
          outer,
          [
            const Color(0xFFB8C2CE).withValues(alpha: 0),
            const Color(0xFFB8C2CE).withValues(alpha: 0.28),
            const Color(0xFFB8C2CE).withValues(alpha: 0),
          ],
          [0.86, mr / outer, 1.0],
        ),
    );
  }

  @override
  double get cardReach => 2.26;

  @override
  Color get territoryTint => const Color(0xFF2A62D8);

  /// Bubbles, drifting.
  @override
  TerritoryMotes get motes => const TerritoryMotes(
    born: Color(0xFFBFE4FF),
    mid: Color(0xFF7ABDFF),
    dying: Color(0xFF3A7BFF),
    shape: MoteShape.bubble,
    speed: 0.035,
    travel: 150,
    size: 2.6,
    alpha: 0.9,
  );
}
