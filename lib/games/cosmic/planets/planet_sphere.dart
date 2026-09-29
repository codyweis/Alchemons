// ─────────────────────────────────────────────────────────────────────────────
//  PLANETS AS REAL SPHERES
//
//  Surface features are points fixed to a unit sphere. Each frame the sphere
//  is turned about a tilted pole and projected straight onto the screen, so
//  features foreshorten toward the limb and slide round the far side the way
//  a turning world does. Everything expensive happens once, at build: the
//  per-frame cost is a 3×3 multiply per vertex.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

/// A pole leaning [roll] to the side and [lean] toward the viewer, turning
/// once every [period] seconds.
class SphereSpin {
  const SphereSpin({
    required this.period,
    this.roll = -0.35,
    this.lean = 0.32,
  });

  final double period;
  final double roll;
  final double lean;

  /// Row-major 3×3: spin about the pole, then lean, then roll.
  Float64List matrixAt(double t) {
    final a = t * 2 * pi / period;
    final ca = cos(a), sa = sin(a);
    final cl = cos(lean), sl = sin(lean);
    final cr = cos(roll), sr = sin(roll);
    // Ry(a)
    const m = 9;
    final ry = Float64List(m)
      ..[0] = ca
      ..[2] = sa
      ..[4] = 1
      ..[6] = -sa
      ..[8] = ca;
    // Rx(lean): tips the north pole toward the viewer.
    final rx = Float64List(m)
      ..[0] = 1
      ..[4] = cl
      ..[5] = -sl
      ..[7] = sl
      ..[8] = cl;
    // Rz(roll)
    final rz = Float64List(m)
      ..[0] = cr
      ..[1] = -sr
      ..[3] = sr
      ..[4] = cr
      ..[8] = 1;
    return _mul(rz, _mul(rx, ry));
  }

  static Float64List _mul(Float64List a, Float64List b) {
    final o = Float64List(9);
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        o[r * 3 + c] =
            a[r * 3] * b[c] + a[r * 3 + 1] * b[3 + c] + a[r * 3 + 2] * b[6 + c];
      }
    }
    return o;
  }
}

/// Where a sphere point lands: screen position and depth toward the viewer
/// (1 facing, 0 on the limb, negative round the back).
class SpherePoint {
  SpherePoint(this.offset, this.depth);
  final Offset offset;
  final double depth;
}

/// Projects sphere points for one frame.
class SphereView {
  SphereView(this.center, this.radius, this.m);

  final Offset center;
  final double radius;
  final Float64List m;

  double depthOf(double x, double y, double z) => m[6] * x + m[7] * y + m[8] * z;

  SpherePoint project(double x, double y, double z) {
    final sx = m[0] * x + m[1] * y + m[2] * z;
    final sy = m[3] * x + m[4] * y + m[5] * z;
    final sz = m[6] * x + m[7] * y + m[8] * z;
    // Screen y points down; the sphere's y is up.
    return SpherePoint(
      Offset(center.dx + sx * radius, center.dy - sy * radius),
      sz,
    );
  }

  /// Like [project], but a point round the back is pushed out to just past
  /// the limb. A shape that straddles the limb then wraps over it instead of
  /// folding back across the face; the caller clips to the disc.
  Offset projectClamped(double x, double y, double z) {
    final sx = m[0] * x + m[1] * y + m[2] * z;
    final sy = m[3] * x + m[4] * y + m[5] * z;
    final sz = m[6] * x + m[7] * y + m[8] * z;
    if (sz >= 0) {
      return Offset(center.dx + sx * radius, center.dy - sy * radius);
    }
    final l = sqrt(sx * sx + sy * sy);
    final k = l < 1e-6 ? 0.0 : 1.04 / l;
    return Offset(center.dx + sx * k * radius, center.dy - sy * k * radius);
  }
}

/// A sphere cut into plates — the cells of a spherical Voronoi diagram —
/// each stored as a ring of surface points at a chosen inset from its edge.
///
/// Built once: the cell edge along each of [sides] directions from the seed is
/// solved exactly (where a neighbour's seed becomes the nearer one), so there
/// is no marching and no mesh.
class SpherePlates {
  SpherePlates._(this.seeds, this.sides, this._edge, this.plateCount);

  /// Unit seed per plate, flattened xyz.
  final Float64List seeds;
  final int sides;
  final int plateCount;

  /// Per plate: for each side, the direction (xyz, tangent at the seed) and
  /// the arc distance to the cell edge. Flattened: 4 values per side.
  final List<Float64List> _edge;

  /// Seeds spread evenly over the sphere, then shaken by [jitter] (0 keeps
  /// the near-hexagonal tiling; ~1 is close to uniformly random).
  static Float64List spreadSeeds({
    required int count,
    required Random rng,
    double jitter = 0.35,
  }) {
    final seeds = Float64List(count * 3);
    final spacing = sqrt(4 * pi / count);
    const golden = 2.399963229728653;
    for (var i = 0; i < count; i++) {
      final y = 1 - 2 * (i + 0.5) / count;
      final rad = sqrt(max(0.0, 1 - y * y));
      final phi = i * golden;
      var x = cos(phi) * rad, yy = y, z = sin(phi) * rad;
      x += (rng.nextDouble() - 0.5) * spacing * jitter;
      yy += (rng.nextDouble() - 0.5) * spacing * jitter;
      z += (rng.nextDouble() - 0.5) * spacing * jitter;
      final l = sqrt(x * x + yy * yy + z * z);
      seeds[i * 3] = x / l;
      seeds[i * 3 + 1] = yy / l;
      seeds[i * 3 + 2] = z / l;
    }
    return seeds;
  }

  /// Cells around the given unit [seeds] (flattened xyz).
  factory SpherePlates.fromSeeds(Float64List seeds, {int sides = 20}) {
    final count = seeds.length ~/ 3;
    final edges = <Float64List>[];
    for (var i = 0; i < count; i++) {
      final ax = seeds[i * 3], ay = seeds[i * 3 + 1], az = seeds[i * 3 + 2];
      // Tangent basis at the seed.
      var hx = 0.0, hy = 1.0, hz = 0.0;
      if (ay.abs() > 0.9) {
        hx = 1;
        hy = 0;
      }
      // u = normalize(h × a)
      var ux = hy * az - hz * ay;
      var uy = hz * ax - hx * az;
      var uz = hx * ay - hy * ax;
      final ul = sqrt(ux * ux + uy * uy + uz * uz);
      ux /= ul;
      uy /= ul;
      uz /= ul;
      // v = a × u
      final vx = ay * uz - az * uy;
      final vy = az * ux - ax * uz;
      final vz = ax * uy - ay * ux;

      final e = Float64List(sides * 4);
      for (var k = 0; k < sides; k++) {
        final th = 2 * pi * k / sides;
        final dx = cos(th) * ux + sin(th) * vx;
        final dy = cos(th) * uy + sin(th) * vy;
        final dz = cos(th) * uz + sin(th) * vz;
        // Along p(s) = cos s·a + sin s·d, seed j wins once
        // tan s > (1 − a·b) / (d·b).
        var best = pi / 2;
        for (var j = 0; j < count; j++) {
          if (j == i) continue;
          final bx = seeds[j * 3], by = seeds[j * 3 + 1], bz = seeds[j * 3 + 2];
          final ed = dx * bx + dy * by + dz * bz;
          if (ed <= 1e-9) continue;
          final c = ax * bx + ay * by + az * bz;
          final s = atan2(1 - c, ed);
          if (s < best) best = s;
        }
        e[k * 4] = dx;
        e[k * 4 + 1] = dy;
        e[k * 4 + 2] = dz;
        e[k * 4 + 3] = best;
      }
      edges.add(e);
    }
    return SpherePlates._(seeds, sides, edges, count);
  }

  /// Arc distance from plate [i]'s seed to its edge along side [k].
  double edgeAt(int i, int k) => _edge[i][k * 4 + 3];

  /// Surface ring for plate [i], each side pulled in from the edge by
  /// [insetFor] (arc radians), which is told the side and where on the
  /// sphere the edge is — so a seam can be wide in one region and a hairline
  /// in another, and both plates either side of it agree. The ring never
  /// shrinks below [minFrac] of the cell. Flattened xyz, [sides] points.
  Float64List ring(
    int i,
    double Function(int side, double ex, double ey, double ez) insetFor, {
    double minFrac = 0.2,
  }) {
    final ax = seeds[i * 3], ay = seeds[i * 3 + 1], az = seeds[i * 3 + 2];
    final e = _edge[i];
    final out = Float64List(sides * 3);
    for (var k = 0; k < sides; k++) {
      final edge = e[k * 4 + 3];
      final ce = cos(edge), se = sin(edge);
      final inset = insetFor(
        k,
        ce * ax + se * e[k * 4],
        ce * ay + se * e[k * 4 + 1],
        ce * az + se * e[k * 4 + 2],
      );
      final s = max(edge * minFrac, edge - inset);
      final cs = cos(s), sn = sin(s);
      out[k * 3] = cs * ax + sn * e[k * 4];
      out[k * 3 + 1] = cs * ay + sn * e[k * 4 + 1];
      out[k * 3 + 2] = cs * az + sn * e[k * 4 + 2];
    }
    return out;
  }
}

/// Adds a closed ring of sphere points to [path], wrapping it over the limb
/// where it goes round the back.
void addSphereRing(Path path, SphereView view, Float64List ring) {
  final n = ring.length ~/ 3;
  for (var k = 0; k < n; k++) {
    final o = view.projectClamped(ring[k * 3], ring[k * 3 + 1], ring[k * 3 + 2]);
    if (k == 0) {
      path.moveTo(o.dx, o.dy);
    } else {
      path.lineTo(o.dx, o.dy);
    }
  }
  path.close();
}

/// A view with no position or size — the unit disc at the origin. Static
/// shapes (latitude bands, polar caps: anything symmetric about the pole,
/// which never moves on screen) are built once in it and drawn scaled.
SphereView unitView(SphereSpin spin) => SphereView(Offset.zero, 1, spin.matrixAt(0));

/// An irregular ring round the surface point ([cx], [cy], [cz]) at roughly
/// [radius] arc radians, for clouds, pools, continents. [rough] is how far
/// the outline strays (fraction of [radius]); the wander is two smooth
/// harmonics, so the outline is a lobed shape, never a jagged one.
/// [stretch] > 1 draws it out east–west (along the spin).
Float64List sphereBlob(
  double cx,
  double cy,
  double cz,
  double radius,
  Random rng, {
  int sides = 26,
  double rough = 0.28,
  double stretch = 1,
}) {
  // Tangent basis: u east (round the pole), v north.
  var ux = cz, uy = 0.0, uz = -cx;
  var ul = sqrt(ux * ux + uz * uz);
  if (ul < 1e-6) {
    ux = 1;
    uz = 0;
    ul = 1;
  }
  ux /= ul;
  uz /= ul;
  final vx = cy * uz - cz * uy;
  final vy = cz * ux - cx * uz;
  final vz = cx * uy - cy * ux;
  final p1 = rng.nextDouble() * 2 * pi, p2 = rng.nextDouble() * 2 * pi;
  final k1 = 2 + rng.nextInt(2), k2 = 4 + rng.nextInt(2);
  final out = Float64List(sides * 3);
  for (var k = 0; k < sides; k++) {
    final th = 2 * pi * k / sides;
    final wob = 1 + rough * (0.65 * sin(k1 * th + p1) + 0.35 * sin(k2 * th + p2));
    final s = radius * wob;
    final dx = cos(th) * stretch, dy = sin(th);
    final dl = sqrt(dx * dx + dy * dy);
    final ex = (dx * ux + dy * vx) / dl;
    final ey = (dx * uy + dy * vy) / dl;
    final ez = (dx * uz + dy * vz) / dl;
    final ang = s * dl;
    final cs = cos(ang), sn = sin(ang);
    out[k * 3] = cs * cx + sn * ex;
    out[k * 3 + 1] = cs * cy + sn * ey;
    out[k * 3 + 2] = cs * cz + sn * ez;
  }
  return out;
}

/// A point on the unit sphere from latitude/longitude (radians; y is north).
(double, double, double) sphereAt(double lat, double lon) =>
    (cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon));

/// The visible part of a region of the sphere — the side of the closed
/// [loop] (flattened xyz, densely sampled) that [inside] accepts — as a
/// screen path. Exact at the limb for regions of any size: where the
/// outline goes round the back, it is replaced by the stretch of limb that
/// lies inside the region. Null when none of it faces the viewer.
Path? visibleRegion(
  SphereView view,
  Float64List loop,
  bool Function(double x, double y, double z) inside,
) {
  final m = view.m;
  final n = loop.length ~/ 3;
  final vx = Float64List(n), vy = Float64List(n), vz = Float64List(n);
  var front = 0;
  for (var i = 0; i < n; i++) {
    final x = loop[i * 3], y = loop[i * 3 + 1], z = loop[i * 3 + 2];
    vx[i] = m[0] * x + m[1] * y + m[2] * z;
    vy[i] = m[3] * x + m[4] * y + m[5] * z;
    vz[i] = m[6] * x + m[7] * y + m[8] * z;
    if (vz[i] >= 0) front++;
  }
  final c = view.center, r = view.radius;
  Offset screen(double x, double y) => Offset(c.dx + x * r, c.dy - y * r);

  if (front == n) {
    final path = Path()..moveTo(screen(vx[0], vy[0]).dx, screen(vx[0], vy[0]).dy);
    for (var i = 1; i < n; i++) {
      final o = screen(vx[i], vy[i]);
      path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }
  // Is a view-space point, turned back into the sphere's own frame, inside?
  bool insideView(double x, double y, double z) => inside(
    m[0] * x + m[3] * y + m[6] * z,
    m[1] * x + m[4] * y + m[7] * z,
    m[2] * x + m[5] * y + m[8] * z,
  );
  if (front == 0) {
    return insideView(0, 0, 1)
        ? (Path()..addOval(Rect.fromCircle(center: c, radius: r)))
        : null;
  }

  // Start just after a back→front crossing.
  var start = 0;
  for (var i = 0; i < n; i++) {
    if (vz[(i - 1 + n) % n] < 0 && vz[i] >= 0) {
      start = i;
      break;
    }
  }
  double crossAngle(int a, int b) {
    final s = vz[a] / (vz[a] - vz[b]);
    final x = vx[a] + (vx[b] - vx[a]) * s;
    final y = vy[a] + (vy[b] - vy[a]) * s;
    return atan2(y, x);
  }

  final path = Path();
  final entry0 = crossAngle((start - 1 + n) % n, start);
  path.moveTo(screen(cos(entry0), sin(entry0)).dx, screen(cos(entry0), sin(entry0)).dy);
  var i = start;
  var walked = 0;
  while (walked < n) {
    // A front run.
    while (walked < n && vz[i] >= 0) {
      final o = screen(vx[i], vy[i]);
      path.lineTo(o.dx, o.dy);
      i = (i + 1) % n;
      walked++;
    }
    final exit = crossAngle((i - 1 + n) % n, i);
    // Skip the back run.
    while (walked < n && vz[i] < 0) {
      i = (i + 1) % n;
      walked++;
    }
    final entry = walked < n ? crossAngle((i - 1 + n) % n, i) : entry0;
    // Round the limb from exit to entry, whichever way lies inside.
    var ccw = entry - exit;
    while (ccw < 0) {
      ccw += 2 * pi;
    }
    final cw = ccw - 2 * pi;
    final midCcw = exit + ccw / 2, midCw = exit + cw / 2;
    final okCcw = insideView(cos(midCcw), sin(midCcw), 0);
    final okCw = insideView(cos(midCw), sin(midCw), 0);
    final sweep = okCcw == okCw
        ? (ccw.abs() < cw.abs() ? ccw : cw)
        : (okCcw ? ccw : cw);
    final steps = max(2, (sweep.abs() / 0.1).ceil());
    for (var k = 0; k <= steps; k++) {
      final a = exit + sweep * k / steps;
      final o = screen(cos(a), sin(a));
      path.lineTo(o.dx, o.dy);
    }
  }
  return path..close();
}

/// Everything north of [lat] (radians), as it shows on the unit disc; a
/// negative [lat] reaches past the equator. [wave] (radians) and [waves]
/// ripple the edge round the pole. Null if none of it shows.
Path? latitudeCap(
  SphereView unit,
  double lat, {
  bool south = false,
  double wave = 0,
  int waves = 5,
  double phase = 0,
}) {
  const n = 96;
  double edge(double lon) => lat + wave * sin(waves * lon + phase);
  final loop = Float64List(n * 3);
  for (var k = 0; k < n; k++) {
    final lon = 2 * pi * k / n;
    final (x, y, z) = sphereAt(edge(lon), lon);
    loop[k * 3] = x;
    loop[k * 3 + 1] = y;
    loop[k * 3 + 2] = z;
  }
  return visibleRegion(unit, loop, (x, y, z) {
    final la = asin(y.clamp(-1.0, 1.0));
    final e = edge(atan2(z, x));
    return south ? la < e : la > e;
  });
}
