part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SOLANTHIS — the Light planet: a pearl of light
//
//  Where Pyrathis burns, Solanthis is serene: a smooth white-gold orb with
//  pale bands of pearl lustre and bright faculae drifting across it, sunk
//  in soft layered light that swells slowly.
//
//  Tried and cut (2026-09-28/29): rays of any kind — broad soft shafts
//  (blurry), then slender triangle beams ("cheesy").
// ─────────────────────────────────────────────────────────────────────────────

class LightPlanetArt extends PlanetArt {
  LightPlanetArt._(this._bands, this._faculae);

  factory LightPlanetArt(int seed) {
    final rng = Random(seed * 67 + 47);
    final unit = unitView(_spin);
    final bands = <(Path, Color)>[
      if (latitudeCap(unit, 0.3, wave: 0.03, waves: 3) case final a?)
        (a, const Color(0x22FFD6C8)),
      if (latitudeCap(unit, 0.75, wave: 0.03, waves: 4) case final b?)
        (b, const Color(0x1CFFF4D8)),
      if (latitudeCap(unit, -0.4, south: true, wave: 0.03, waves: 3)
          case final s?)
        (s, const Color(0x20F6C878)),
    ];
    return LightPlanetArt._(
      bands,
      _BlobField.scatter(
        rng,
        14,
        size: 0.05,
        spread: 2.2,
        stretch: 1.6,
        soft: 1,
      ),
    );
  }

  static const _spin = SphereSpin(period: 240);
  static const _gold = Color(0xFFFFE9A8);

  final List<(Path, Color)> _bands;
  final _BlobField _faculae;

  @override
  void paintBack(Canvas c, Offset p, double r, double t) {
    // Radiance as soft light, not beams: the glow every planet used to
    // wear, a brighter one close in as the original had, and a slow swell.
    final swell = 0.5 + 0.5 * sin(t * 0.4);
    _oldAura(c, p, r, _gold);
    _halo(c, p, r, _gold, alpha: 0.2 + 0.05 * swell, reach: 2.4);
    _softCircle(c, p, r * 1.2, _gold.withValues(alpha: 0.2), 15);
  }

  @override
  void paintBody(Canvas c, Offset p, double r, double t) {
    final view = SphereView(p, r, _spin.matrixAt(t));
    c.save();
    _clipDisc(c, p, r);
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          p,
          r,
          const [
            Color(0xFFFFFCEE),
            Color(0xFFFFF0C0),
            Color(0xFFF7D888),
            Color(0xFFE9BC62),
          ],
          const [0.0, 0.5, 0.85, 1.0],
        ),
    );
    for (final (path, col) in _bands) {
      _drawUnit(c, p, r, path, Paint()..color = col);
    }
    _faculae.paint(c, view, const Color(0xFFFFFFFF), 0.5, halo: 0);
    _shade(c, p, r, strength: 0.14, night: const Color(0xFF6A4A10));
    c.restore();
    _limb(
      c,
      p,
      r,
      const Color(0xFFFFF4CC),
      alpha: 0.45,
      inner: 0.95,
      outer: 1.05,
    );
  }

  @override
  Color get territoryTint => const Color(0xFFE8C060);

  @override
  double get territoryStrength => 0.06;

  /// Motes of light, drifting out and twinkling.
  @override
  TerritoryMotes get motes => const TerritoryMotes(
    born: Color(0xFFFFFFFF),
    mid: Color(0xFFFFF1C4),
    dying: Color(0xFFFFD27A),
    motion: MoteMotion.outward,
    speed: 0.03,
    travel: 200,
    size: 1.4,
    alpha: 0.7,
  );
}
