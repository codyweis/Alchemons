part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AN ACCRETION DISK — matter wheeling round something that is eating it
//
//  Nythralor's disk, made reusable (the home planet's Black Hole wears one
//  too): hundreds of motes in a flattened disk, the inner ones running fast
//  and burning white-violet, the outer slow and deep purple; streams
//  spiralling in and going out at the edge; a hot glow at the inner rim,
//  behind whatever the disk surrounds. The near half passes in front, the
//  far half behind. Motes part round the ship as it flies through. Batched:
//  positions once a frame for both halves, a few point draws for all of it.
// ─────────────────────────────────────────────────────────────────────────────

/// A sine table for the per-grain maths of the big particle systems, where
/// thousands of calls a frame to the real one add up; interpolated, it is
/// far closer than a grain's placement needs.
const int _kSinSteps = 4096;
const double _kSinScale = _kSinSteps / (2 * pi);
final Float64List _sinTable = () {
  final t = Float64List(_kSinSteps + 2);
  for (var i = 0; i < t.length; i++) {
    t[i] = sin(i / _kSinScale);
  }
  return t;
}();

double _fastSin(double x) {
  var u = x * _kSinScale;
  u -= (u / _kSinSteps).floorToDouble() * _kSinSteps;
  final i = u.toInt();
  final a = _sinTable[i];
  return a + (_sinTable[i + 1] - a) * (u - i);
}

double _fastCos(double x) => _fastSin(x + pi / 2);

/// What a disk burns in: its matter by heat (hottest first), the glow at
/// its inner rim, and the broad bands of its outer disk.
class DiskPalette {
  const DiskPalette({
    required this.heat,
    required this.rim,
    required this.mid,
    required this.edge,
    required this.bandA,
    required this.bandB,
  });

  final List<Color> heat;
  final Color rim, mid, edge;
  final Color bandA, bandB;

  /// Nythralor's.
  static const violet = DiskPalette(
    heat: [
      Color(0xFFF2E2FF),
      Color(0xFFC88CFA),
      Color(0xFF8E58E0),
      Color(0xFF5A2CA8),
    ],
    rim: Color(0xFFE8C8FF),
    mid: Color(0xFFA070F0),
    edge: Color(0xFF6A3AB8),
    bandA: Color(0xFF7A3AD0),
    bandB: Color(0xFF4A148C),
  );

  static const solar = DiskPalette(
    heat: [
      Color(0xFFFFFBEA),
      Color(0xFFFFD98A),
      Color(0xFFFFA43C),
      Color(0xFFB8561A),
    ],
    rim: Color(0xFFFFEBC0),
    mid: Color(0xFFFFB850),
    edge: Color(0xFFB8561A),
    bandA: Color(0xFFD08A2A),
    bandB: Color(0xFF7A3A10),
  );

  static const crimson = DiskPalette(
    heat: [
      Color(0xFFFFE6E0),
      Color(0xFFFF8C7E),
      Color(0xFFE0343E),
      Color(0xFF7E0E22),
    ],
    rim: Color(0xFFFFC8C0),
    mid: Color(0xFFF05A5A),
    edge: Color(0xFF8A1020),
    bandA: Color(0xFFC0283A),
    bandB: Color(0xFF5A0816),
  );

  static const azure = DiskPalette(
    heat: [
      Color(0xFFE8F8FF),
      Color(0xFF8CD4FF),
      Color(0xFF3C88F0),
      Color(0xFF1E3A9A),
    ],
    rim: Color(0xFFC8ECFF),
    mid: Color(0xFF60A8F8),
    edge: Color(0xFF2A4AB0),
    bandA: Color(0xFF2E6AD0),
    bandB: Color(0xFF14286E),
  );

  static const emerald = DiskPalette(
    heat: [
      Color(0xFFE8FFF2),
      Color(0xFF8CF5C4),
      Color(0xFF2EC88C),
      Color(0xFF0E6A4C),
    ],
    rim: Color(0xFFC8FFE4),
    mid: Color(0xFF50E0A8),
    edge: Color(0xFF12785A),
    bandA: Color(0xFF1EA070),
    bandB: Color(0xFF0A4A34),
  );

  /// [base] with every hue turned by [degrees] — for a disk that drifts
  /// slowly through the spectrum.
  static DiskPalette shifted(DiskPalette base, double degrees) {
    Color turn(Color c) {
      final h = HSVColor.fromColor(c);
      return h.withHue((h.hue + degrees) % 360).toColor();
    }

    return DiskPalette(
      heat: [for (final c in base.heat) turn(c)],
      rim: turn(base.rim),
      mid: turn(base.mid),
      edge: turn(base.edge),
      bandA: turn(base.bandA),
      bandB: turn(base.bandB),
    );
  }
}

class _AccretionDisk {
  _AccretionDisk(
    Random rng, {
    int motes = 700,
    int infall = 90,
    this.inner = 1.18,
    this.outer = 2.83,
    this.speed = 0.55,
    this.flat = 0.35,
    this.grain = 1.0,
    this.lensed = false,
  }) : _disk = [
         for (var i = 0; i < motes; i++)
           (
             inner + (outer - inner) * pow(rng.nextDouble(), 1.3),
             rng.nextDouble() * 2 * pi,
             0.5 + rng.nextDouble() * 0.9,
             rng.nextDouble() * 2 * pi,
           ),
       ],
       _infall = [
         for (var i = 0; i < infall; i++)
           (
             inner + (outer - inner) * (0.45 + rng.nextDouble() * 0.55),
             rng.nextDouble() * 2 * pi,
             4.0 + rng.nextDouble() * 4.0,
             rng.nextDouble(),
           ),
       ] {
    // Everything about a grain that does not change frame to frame, worked
    // out once: at the densest settings there are thousands of them.
    final n = _disk.length;
    _dRad = Float64List(n);
    _dA0 = Float64List(n);
    _dSize = Float64List(n);
    _dPh = Float64List(n);
    _dOrbit = Float64List(n);
    _dF = Float64List(n);
    _dHeat = Uint8List(n);
    for (var i = 0; i < n; i++) {
      final (rad, a0, size, ph) = _disk[i];
      _dRad[i] = rad;
      _dA0[i] = a0;
      _dSize[i] = size;
      _dPh[i] = ph;
      _dOrbit[i] = speed / (rad * sqrt(rad));
      _dF[i] = (rad - inner) / (outer - inner);
      _dHeat[i] = _heatOf(rad);
    }
  }

  late final Float64List _dRad, _dA0, _dSize, _dPh, _dOrbit, _dF;
  late final Uint8List _dHeat;

  /// Where the disk starts and ends, in radii of what it surrounds.
  final double inner, outer;

  /// Orbital speed at one radius.
  final double speed;

  /// How flat the disk is seen (1 is face-on).
  final double flat;

  /// Mote size, as a multiple of Nythralor's.
  final double grain;

  /// Whether the far half is also seen bent up over the top of what the
  /// disk surrounds (and faintly under the bottom), the way light from
  /// behind a black hole comes round it.
  final bool lensed;

  /// (radius, angle, size, twinkle phase).
  final List<(double, double, double, double)> _disk;

  /// Infalling streams: (start radius, angle, fall time, phase).
  final List<(double, double, double, double)> _infall;

  int _heatOf(double rad) {
    final f = (rad - inner) / (outer - inner);
    return f < 0.14 ? 0 : (f < 0.38 ? 1 : (f < 0.68 ? 2 : 3));
  }

  final _DotBatch _behind = _DotBatch(8);
  final _DotBatch _ahead = _DotBatch(8);
  final _DotBatch _bent = _DotBatch(8);
  double _preparedT = double.nan;
  Offset _preparedP = Offset.zero;
  double _preparedR = 0;
  Offset? _preparedWake;

  void _prepare(Offset p, double r, double t, Offset? wake) {
    if (t == _preparedT &&
        p == _preparedP &&
        r == _preparedR &&
        wake == _preparedWake) {
      return;
    }
    _preparedT = t;
    _preparedP = p;
    _preparedR = r;
    _preparedWake = wake;
    _behind.clear();
    _ahead.clear();
    _bent.clear();
    final reach = max(170.0, r * 0.7);
    // In orbit: inner matter much faster than outer.
    for (var i = 0; i < _dRad.length; i++) {
      final a = _dA0[i] + t * _dOrbit[i];
      final size = _dSize[i] * (0.75 + 0.25 * _fastSin(t * 2.4 + _dPh[i]));
      _place(
        p,
        r,
        _dRad[i],
        _dF[i],
        _dHeat[i],
        _fastSin(a),
        _fastCos(a),
        size,
        wake,
        reach,
      );
    }
    // Falling in: a spiral inward, gone at the edge.
    final edge = inner * 0.87;
    for (final (r0, a0, fall, ph) in _infall) {
      final life = (t / fall + ph) % 1.0;
      final fade = (life < 0.15 ? life / 0.15 : 1.0) * (1 - pow(life, 6));
      if (fade < 0.3) continue;
      final rad = r0 - (r0 - edge) * pow(life, 1.4);
      final a = a0 + life * 3.2;
      _place(
        p,
        r,
        rad,
        (rad - inner) / (outer - inner),
        _heatOf(rad),
        _fastSin(a),
        _fastCos(a),
        0.9 * fade,
        wake,
        reach,
      );
    }
  }

  /// One grain at [rad] radii, at the angle whose sine and cosine are [sy]
  /// and [cx], into the near or far half — and, lensed, its bent image.
  void _place(
    Offset p,
    double r,
    double rad,
    double f,
    int heat,
    double sy,
    double cx,
    double size,
    Offset? wake,
    double reach,
  ) {
    var x = p.dx + cx * rad * r;
    var y = p.dy + sy * rad * r * flat;
    // The ship flying through parts the matter round it.
    final push = _wakePush(x, y, wake, reach, reach * 0.45);
    x += push.dx;
    y += push.dy;
    final bucket = heat * 2 + (size > 0.95 ? 1 : 0);
    (sy > 0 ? _ahead : _behind).add(bucket, x, y);
    if (!lensed) return;
    // The bent image: the far half arched over the top, hugging the body at
    // the crown and opening out to meet the disk at the sides; the near
    // half, fainter and tighter, under the bottom.
    final c2 = cx * cx;
    final open = c2 * c2;
    final far = sy < 0;
    final hug = r * (far ? 1.07 + 0.34 * f : 1.03 + 0.14 * f);
    final bend = hug + (rad * r - hug) * open;
    final th = cx * pi / 2;
    _bent.add(
      bucket,
      p.dx + _fastSin(th) * bend,
      p.dy + (far ? -1 : 1) * _fastCos(th) * bend,
    );
  }

  /// The hot glow at the inner rim, in the disk's plane. Behind only.
  void paintGlow(
    Canvas c,
    Offset p,
    double r,
    double t, {
    double alpha = 0.3,
    DiskPalette palette = DiskPalette.violet,
  }) {
    final pulse = 0.85 + 0.15 * sin(t * 0.9);
    final reach = r * (inner + 0.72);
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(1.0, flat);
    c.drawCircle(
      Offset.zero,
      reach,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          reach,
          [
            palette.rim.withValues(alpha: 0),
            palette.rim.withValues(alpha: alpha * pulse),
            palette.mid.withValues(alpha: alpha * 0.45 * pulse),
            palette.edge.withValues(alpha: 0),
          ],
          [
            (inner - 0.25) / (inner + 0.72),
            (inner - 0.16) / (inner + 0.72),
            (inner + 0.17) / (inner + 0.72),
            1.0,
          ],
        ),
    );
    c.restore();
  }

  /// The matter on one side: the near half ([front]) or the far half.
  void paintMatter(
    Canvas c,
    Offset p,
    double r,
    double t, {
    required bool front,
    Offset? wake,
    DiskPalette palette = DiskPalette.violet,
  }) {
    _prepare(p, r, t, wake);
    final batch = front ? _ahead : _behind;
    final heat = palette.heat;
    for (var k = heat.length - 1; k >= 0; k--) {
      for (var sz = 0; sz < 2; sz++) {
        final b = k * 2 + sz;
        final d = r * 0.0055 * (sz == 0 ? 0.7 : 1.15) * 2 * grain;
        batch.draw(
          c,
          b,
          d * 2.2,
          heat[k].withValues(alpha: 0.06 + 0.02 * (3 - k)),
        );
        batch.draw(c, b, d, heat[k].withValues(alpha: 0.85 - k * 0.12));
      }
    }
  }

  /// The bent image of the disk round what it surrounds — only for a
  /// [lensed] disk, drawn after the body so it rims it.
  void paintLensed(
    Canvas c,
    Offset p,
    double r,
    double t, {
    Offset? wake,
    DiskPalette palette = DiskPalette.violet,
  }) {
    if (!lensed) return;
    _prepare(p, r, t, wake);
    final heat = palette.heat;
    // The light it is made of, a soft band round the body.
    final band = r * (inner + 0.2);
    c.drawCircle(
      p,
      band,
      Paint()
        ..shader = ui.Gradient.radial(
          p,
          band,
          [
            palette.rim.withValues(alpha: 0),
            palette.rim.withValues(alpha: 0.22),
            palette.mid.withValues(alpha: 0.08),
            palette.edge.withValues(alpha: 0),
          ],
          [0.9 / (inner + 0.2), 1.06 / (inner + 0.2), 1.2 / (inner + 0.2), 1.0],
        ),
    );
    for (var k = heat.length - 1; k >= 0; k--) {
      for (var sz = 0; sz < 2; sz++) {
        final b = k * 2 + sz;
        final d = r * 0.0055 * (sz == 0 ? 0.7 : 1.15) * 1.6 * grain;
        _bent.draw(
          c,
          b,
          d * 2.4,
          heat[k].withValues(alpha: 0.05 + 0.02 * (3 - k)),
        );
        _bent.draw(c, b, d, heat[k].withValues(alpha: 0.7 - k * 0.12));
      }
    }
  }
}

/// A small black hole for use outside the cosmic map — the Black Sun's
/// portals in Nythralor's dungeon, and the black holes its enemies come out
/// of. The SAME recipe as the Dark planet (the author: its particle black
/// hole "looks way better and less cheesy"): a soft aura, flattened layered
/// glow, the hot glow at the inner rim, and hundreds of motes on Keplerian
/// orbits — the far half behind the core, the near half in front of it.
/// Nothing drawn: no arms, no swept arcs, no rims.
///
/// Call [paintBack], fill the core yourself (black, or a window), then
/// [paintFront]. [tilt] turns the whole thing (π/2 stands the disk on end,
/// for a mouth in a wall that runs north–south).
class BlackHoleArt {
  BlackHoleArt({
    int seed = 1,
    int motes = 520,
    int infall = 70,
    double grain = 6.5,
    this.flat = 0.35,
    this.palette = DiskPalette.violet,
  }) : _disk = _AccretionDisk(
         Random(seed * 61 + 43),
         motes: motes,
         infall: infall,
         grain: grain,
         flat: flat,
       );

  final _AccretionDisk _disk;
  final double flat;
  final DiskPalette palette;

  /// Behind the core: the aura, the layered disk, the inner glow and the far
  /// half of the matter. [r] is the core's radius.
  void paintBack(
    Canvas c,
    Offset p,
    double r,
    double t, {
    double tilt = 0,
    double alpha = 1,
  }) {
    if (r <= 0.5) return;
    c.save();
    c.translate(p.dx, p.dy);
    if (tilt != 0) c.rotate(tilt);
    _softCircle(
      c,
      Offset.zero,
      r * 2.6,
      palette.bandB.withValues(alpha: 0.16 * alpha),
      r * 0.3,
    );
    c.save();
    c.scale(1.0, flat);
    for (var i = 3; i >= 0; i--) {
      c.drawCircle(
        Offset.zero,
        r * (1.8 + i * 0.3),
        Paint()
          ..color = Color.lerp(
            palette.bandB,
            palette.bandA,
            i * 0.2,
          )!.withValues(alpha: (0.08 + 0.03 * sin(t * 1.5 + i)) * alpha),
      );
    }
    c.restore();
    _disk.paintGlow(c, Offset.zero, r, t, palette: palette, alpha: 0.3 * alpha);
    _disk.paintMatter(c, Offset.zero, r, t, front: false, palette: palette);
    c.restore();
  }

  /// In front of the core: the near half of the matter.
  void paintFront(Canvas c, Offset p, double r, double t, {double tilt = 0}) {
    if (r <= 0.5) return;
    c.save();
    c.translate(p.dx, p.dy);
    if (tilt != 0) c.rotate(tilt);
    _disk.paintMatter(c, Offset.zero, r, t, front: true, palette: palette);
    c.restore();
  }
}
