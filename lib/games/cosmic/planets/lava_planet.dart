part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MAGMORA — the Lava planet in open space
//
//  A crust of basalt plates riding a magma sea, turning slowly. Most of the
//  crust is quiet — big dark plates, hairline seams glowing dull red — but
//  two rift belts cross the world where it is being pulled apart: plates
//  broken small, seams opened wide and running gold, and surges of heat
//  travelling along under them. Light comes from the upper left like
//  everything else in space; the crust darkens into night on the far side but
//  the magma does not, so the dark limb is drawn in glowing veins.
//
//  Material, not lines: every seam is the gap between two filled plates, a
//  hot rim is a second, larger fill under each plate, and light is gradient
//  pools. The only strokes are the belts' glow, and those lie UNDER the crust
//  where only the seams let them show. No blur — the old art paid ~24
//  gaussian passes a frame; this is ~12 plain and gradient fills.
//
//  Tried and cut (2026-09-28): ember plumes off the limb, as dots and as
//  tapered trails. Both read as noise — a swarm, then a fan of shards — on a
//  planet whose appeal is how calm it is.
// ─────────────────────────────────────────────────────────────────────────────

// Palette. Muted where it is rock, luminous only where it is molten.
const _magmaCore = Color(0xFFFFC66A);
const _magmaHot = Color(0xFFFF9A36);
const _magmaMid = Color(0xFFD8461A);
const _magmaDeep = Color(0xFFA82C0E);
const _magmaLimb = Color(0xFF6E1606);

const _rimLit = Color(0xFF7C3219);
const _rimMid = Color(0xFF571B0D);
const _rimDark = Color(0xFF3E1108);

const _basaltLit = Color(0xFF5E463C);
const _basaltMid = Color(0xFF2F201B);
const _basaltDark = Color(0xFF130C0A);
const _basaltNight = Color(0xFF0A0606);

const _heat = Color(0xFFFF6A1E);

const _emberFresh = Color(0xFFFFE2A0);
const _emberWarm = Color(0xFFFF8C2E);
const _emberCool = Color(0xFFA8290C);

class LavaPlanetArt extends PlanetArt {
  LavaPlanetArt._(this._plates, this._rims, this._cores, this._rifts);

  static const _quietPlates = 44;
  static const _riftPlates = 18; // per rift
  static const _spin = SphereSpin(period: 200);

  final SpherePlates _plates;

  /// Per plate: the ring its hot rim fills to, and the ring its cool basalt
  /// fills to.
  final List<Float64List> _rims;
  final List<Float64List> _cores;

  /// Each rift is a great circle: its pole, then two axes spanning it.
  /// Flattened, 9 values per rift.
  final Float64List _rifts;

  factory LavaPlanetArt(int seed) {
    final rng = Random(seed * 31 + 7);

    // Two rift belts, not too near parallel, so they cross.
    final rifts = Float64List(18);
    Float64List unit() {
      while (true) {
        final x = rng.nextDouble() * 2 - 1;
        final y = rng.nextDouble() * 2 - 1;
        final z = rng.nextDouble() * 2 - 1;
        final l = sqrt(x * x + y * y + z * z);
        if (l > 0.2 && l <= 1) return Float64List.fromList([x / l, y / l, z / l]);
      }
    }

    for (var r = 0; r < 2; r++) {
      Float64List n;
      do {
        n = unit();
        // Poles near the planet's own pole give belts that run round the
        // equator and show side-on as the planet turns.
      } while (n[1].abs() < 0.45 ||
          (r == 1 &&
              (n[0] * rifts[0] + n[1] * rifts[1] + n[2] * rifts[2]).abs() >
                  0.75));
      // Axes in the belt's plane.
      final hx = n[1].abs() > 0.9 ? 1.0 : 0.0;
      final hy = n[1].abs() > 0.9 ? 0.0 : 1.0;
      var bx = hy * n[2], by = -hx * n[2], bz = hx * n[1] - hy * n[0];
      final bl = sqrt(bx * bx + by * by + bz * bz);
      bx /= bl;
      by /= bl;
      bz /= bl;
      final cx = n[1] * bz - n[2] * by;
      final cy = n[2] * bx - n[0] * bz;
      final cz = n[0] * by - n[1] * bx;
      rifts.setAll(r * 9, [n[0], n[1], n[2], bx, by, bz, cx, cy, cz]);
    }

    // How rifted a surface point is: 1 on a belt at its widest, 0 in quiet
    // crust. Belts pinch and swell along their length.
    final swellPh = [rng.nextDouble() * 2 * pi, rng.nextDouble() * 2 * pi];
    double rift(double x, double y, double z) {
      var f = 0.0;
      for (var r = 0; r < 2; r++) {
        final o = r * 9;
        final across = x * rifts[o] + y * rifts[o + 1] + z * rifts[o + 2];
        final along = atan2(
          x * rifts[o + 6] + y * rifts[o + 7] + z * rifts[o + 8],
          x * rifts[o + 3] + y * rifts[o + 4] + z * rifts[o + 5],
        );
        final swell = 0.55 + 0.45 * sin(2 * along + swellPh[r]);
        final w = 0.10 + 0.07 * swell;
        f = max(f, exp(-(across * across) / (w * w)) * (0.45 + 0.55 * swell));
      }
      return f;
    }

    // Quiet crust: big, uneven plates. Along each belt: many small ones —
    // crust broken up where it is being pulled apart.
    final quiet = SpherePlates.spreadSeeds(
      count: _quietPlates,
      rng: rng,
      jitter: 0.95,
    );
    final all = Float64List((_quietPlates + _riftPlates * 2) * 3)
      ..setAll(0, quiet);
    var at = _quietPlates * 3;
    for (var r = 0; r < 2; r++) {
      final o = r * 9;
      for (var k = 0; k < _riftPlates; k++) {
        final a = (k + rng.nextDouble() * 0.8) / _riftPlates * 2 * pi;
        final off = (rng.nextDouble() - 0.5) * 0.26;
        final ca = cos(a), sa = sin(a), co = cos(off), so = sin(off);
        for (var c = 0; c < 3; c++) {
          all[at + c] =
              co * (ca * rifts[o + 3 + c] + sa * rifts[o + 6 + c]) +
              so * rifts[o + c];
        }
        at += 3;
      }
    }
    final plates = SpherePlates.fromSeeds(all, sides: 20);

    // Smooth variation so seams taper along their length and the hot rim
    // is thick in places and gone in others.
    final p1 = rng.nextDouble() * 6, p2 = rng.nextDouble() * 6;
    double taper(double x, double y, double z) =>
        0.5 + 0.5 * sin(9 * x + 4 * y + p1) * sin(7 * z - 5 * x + p2);
    double heatVar(double x, double y, double z) =>
        0.5 + 0.5 * sin(6 * y - 8 * z + p2) * sin(8 * x + 3 * z + p1);

    double gap(double x, double y, double z) {
      final f = rift(x, y, z);
      return (0.0045 + 0.042 * pow(f, 1.3)) * (0.55 + 0.9 * taper(x, y, z));
    }

    final rims = <Float64List>[];
    final cores = <Float64List>[];
    for (var i = 0; i < plates.plateCount; i++) {
      rims.add(plates.ring(i, (k, x, y, z) => gap(x, y, z)));
      cores.add(
        plates.ring(
          i,
          (k, x, y, z) =>
              gap(x, y, z) +
              (0.004 + 0.05 * rift(x, y, z)) * (0.3 + 1.2 * heatVar(x, y, z)),
          minFrac: 0.3,
        ),
      );
    }

    return LavaPlanetArt._(plates, rims, cores, rifts);
  }

  // ── behind the body ─────────────────────────────────────────────────────

  /// Heat thrown off into space. One gradient fill.
  @override
  void paintBack(Canvas c, Offset p, double r, double t) {
    final breathe = 0.5 + 0.5 * sin(t * 0.35);
    final outer = r * 2.4;
    c.drawCircle(
      p,
      outer,
      Paint()
        ..shader = ui.Gradient.radial(
          p,
          outer,
          [
            _heat.withValues(alpha: 0.18 + 0.04 * breathe),
            _heat.withValues(alpha: 0.05 + 0.015 * breathe),
            _heat.withValues(alpha: 0.0),
          ],
          [r / outer, 0.6, 1.0],
        ),
    );
  }

  // ── the body ────────────────────────────────────────────────────────────

  @override
  void paintBody(Canvas c, Offset p, double r, double t) {
    final view = SphereView(p, r, _spin.matrixAt(t));
    final disc = Rect.fromCircle(center: p, radius: r);

    c.save();
    c.clipPath(Path()..addOval(disc));

    // Magma sea. Deep red where the crust is quiet; the belts below heat it.
    // Emissive, so it dims toward the limb only, never into night.
    final breathe = 0.5 + 0.5 * sin(t * 0.5);
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          p,
          r,
          [_magmaMid, _magmaDeep, _magmaLimb],
          const [0.0, 0.7, 1.0],
        ),
    );

    // The belts' heat, under the crust: visible only through the seams, so
    // the seams warm to gold along a belt and cool to red away from it.
    final glowWide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = r * 0.42
      ..color = _magmaHot.withValues(alpha: 0.55 + 0.1 * breathe);
    final glowCore = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = r * 0.16
      ..color = _magmaCore.withValues(alpha: 0.45 + 0.15 * breathe);
    for (var b = 0; b < 2; b++) {
      final path = _riftPath(view, b);
      if (path == null) continue;
      c.drawPath(path, glowWide);
      c.drawPath(path, glowCore);
    }

    // Surges travelling along each belt: a seam flares as one passes under.
    for (var b = 0; b < 2; b++) {
      final o = b * 9;
      for (var k = 0; k < 3; k++) {
        final a = t * 0.05 * (b == 0 ? 1 : -1) + k * 2 * pi / 3 + b;
        final ca = cos(a), sa = sin(a);
        final sp = view.project(
          ca * _rifts[o + 3] + sa * _rifts[o + 6],
          ca * _rifts[o + 4] + sa * _rifts[o + 7],
          ca * _rifts[o + 5] + sa * _rifts[o + 8],
        );
        if (sp.depth < -0.1) continue;
        final pulse = 0.5 + 0.5 * sin(t * 0.9 + k * 2.3 + b);
        final rr = r * 0.3 * (0.5 + 0.5 * sp.depth.abs());
        c.drawCircle(
          sp.offset,
          rr,
          Paint()
            ..shader = ui.Gradient.radial(sp.offset, rr, [
              _magmaCore.withValues(alpha: 0.35 + 0.45 * pulse),
              _magmaCore.withValues(alpha: 0.0),
            ]),
        );
      }
    }

    // Crust. Plates wholly round the back are skipped; the rest are gathered
    // into one path per material, so the whole crust is two fills.
    final rimPath = Path();
    final corePath = Path();
    final seeds = _plates.seeds;
    for (var i = 0; i < _plates.plateCount; i++) {
      final d = view.depthOf(seeds[i * 3], seeds[i * 3 + 1], seeds[i * 3 + 2]);
      if (d < -0.3) continue;
      addSphereRing(rimPath, view, _rims[i]);
      addSphereRing(corePath, view, _cores[i]);
    }

    // Lit from the upper left; the light pool sits off the disc so the lit
    // side is a broad shoulder, not a hotspot.
    final lightAt = Offset(p.dx - r * 0.55, p.dy - r * 0.62);
    c.drawPath(
      rimPath,
      Paint()
        ..shader = ui.Gradient.radial(
          lightAt,
          r * 2.2,
          [_rimLit, _rimMid, _rimDark],
          const [0.0, 0.55, 1.0],
        ),
    );
    c.drawPath(
      corePath,
      Paint()
        ..shader = ui.Gradient.radial(
          lightAt,
          r * 2.2,
          [_basaltLit, _basaltMid, _basaltDark, _basaltNight],
          const [0.0, 0.38, 0.72, 1.0],
        ),
    );

    c.restore();

    // Heat haze on the limb, both sides of it.
    final outer = r * 1.12;
    c.drawCircle(
      p,
      outer,
      Paint()
        ..shader = ui.Gradient.radial(
          p,
          outer,
          [
            _heat.withValues(alpha: 0.0),
            _heat.withValues(alpha: 0.26 + 0.05 * breathe),
            _heat.withValues(alpha: 0.08),
            _heat.withValues(alpha: 0.0),
          ],
          [0.8, r / outer, 0.95, 1.0],
        ),
    );
  }

  /// The near half of rift [b] as a screen path, or null if it is all round
  /// the back.
  Path? _riftPath(SphereView view, int b) {
    final o = b * 9;
    const steps = 48;
    Path? path;
    var open = false;
    for (var k = 0; k <= steps; k++) {
      final a = k / steps * 2 * pi;
      final ca = cos(a), sa = sin(a);
      final sp = view.project(
        ca * _rifts[o + 3] + sa * _rifts[o + 6],
        ca * _rifts[o + 4] + sa * _rifts[o + 7],
        ca * _rifts[o + 5] + sa * _rifts[o + 8],
      );
      if (sp.depth < -0.15) {
        open = false;
        continue;
      }
      path ??= Path();
      if (!open) {
        path.moveTo(sp.offset.dx, sp.offset.dy);
        open = true;
      } else {
        path.lineTo(sp.offset.dx, sp.offset.dy);
      }
    }
    return path;
  }

  // ── the territory ──────────────────────────────────────────────────────

  /// Magmora's space smoulders rather than glows: a deep ember red reads as
  /// heat in the dark, where its own orange at this strength reads as brown.
  @override
  Color get territoryTint => const Color(0xFFC0300C);

  /// Embers loose in its space, each carried away from the planet, cooling
  /// from gold to a dull red and going out.
  @override
  TerritoryMotes get motes => const TerritoryMotes(
    born: _emberFresh,
    mid: _emberWarm,
    dying: _emberCool,
    motion: MoteMotion.outward,
    speed: 0.05,
    travel: 190,
    size: 1.5,
  );
}
