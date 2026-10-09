// lib/games/cosmic/enemy_mesh.dart
//
// Small faceted solids for the heavy enemies and the bosses, drawn in real
// 3D: turned by a rotation, projected straight onto the screen, and
// flat-shaded face by face under one fixed light, the way the Crystal
// planet's facets are. Flat vector shapes with gradients read as clip art
// however they are shaded; a solid that turns, catches the light on one
// face after another and glows at its seams reads as a thing.
//
// Seams: every visible face is laid down twice — first whole, in the light
// inside the solid, then inset toward its own centre, in the shell's
// material. The gaps between the inset faces are where the light shows.
//
// Everything a frame asks for goes into one vertex buffer and out in a
// single drawVertices call per [MeshBatch.flush], so a solid costs one draw
// however many faces it has. The paint stays shader-less, so the per-vertex
// colors are what is drawn (as in hatch_shell.dart).

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/enemy_body_art.dart';
import 'package:flutter/painting.dart';

// ── rotations ───────────────────────────────────────────────────────────────

/// A 3×3 rotation, row-major. Screen x right, y down, z toward the viewer.
class Rot3 {
  Rot3() {
    m[0] = 1;
    m[4] = 1;
    m[8] = 1;
  }

  final Float64List m = Float64List(9);

  /// About the x axis — a body rolling along its length.
  Rot3 setX(double a) => _set(1, 0, 0, 0, cos(a), -sin(a), 0, sin(a), cos(a));

  /// About the y axis — turning like a top whose axis is screen-vertical.
  Rot3 setY(double a) => _set(cos(a), 0, sin(a), 0, 1, 0, -sin(a), 0, cos(a));

  /// About the z axis — turning in the screen's own plane, as a heading does.
  Rot3 setZ(double a) => _set(cos(a), -sin(a), 0, sin(a), cos(a), 0, 0, 0, 1);

  Rot3 _set(
    double a,
    double b,
    double c,
    double d,
    double e,
    double f,
    double g,
    double h,
    double i,
  ) {
    m
      ..[0] = a
      ..[1] = b
      ..[2] = c
      ..[3] = d
      ..[4] = e
      ..[5] = f
      ..[6] = g
      ..[7] = h
      ..[8] = i;
    return this;
  }

  /// this = a · b. Safe when this is a or b.
  Rot3 mul(Rot3 a, Rot3 b) {
    final x = a.m, y = b.m;
    return _set(
      x[0] * y[0] + x[1] * y[3] + x[2] * y[6],
      x[0] * y[1] + x[1] * y[4] + x[2] * y[7],
      x[0] * y[2] + x[1] * y[5] + x[2] * y[8],
      x[3] * y[0] + x[4] * y[3] + x[5] * y[6],
      x[3] * y[1] + x[4] * y[4] + x[5] * y[7],
      x[3] * y[2] + x[4] * y[5] + x[5] * y[8],
      x[6] * y[0] + x[7] * y[3] + x[8] * y[6],
      x[6] * y[1] + x[7] * y[4] + x[8] * y[7],
      x[6] * y[2] + x[7] * y[5] + x[8] * y[8],
    );
  }

  /// Rz(z) · Ry(y) · Rx(x): rolled about its length first, then pitched,
  /// then turned to its heading in the screen plane.
  Rot3 euler(double x, double y, double z) {
    final cx = cos(x), sx = sin(x);
    final cy = cos(y), sy = sin(y);
    final cz = cos(z), sz = sin(z);
    return _set(
      cz * cy,
      cz * sy * sx - sz * cx,
      cz * sy * cx + sz * sx,
      sz * cy,
      sz * sy * sx + cz * cx,
      sz * sy * cx - cz * sx,
      -sy,
      cy * sx,
      cy * cx,
    );
  }
}

// ── solids ──────────────────────────────────────────────────────────────────

/// A convex solid of flat faces, built once.
class FacetMesh {
  FacetMesh(List<double> xyz, List<List<int>> faces)
    : v = Float64List.fromList(xyz),
      faces = [for (final f in faces) Int32List.fromList(f)],
      normals = Float64List(faces.length * 3) {
    for (var i = 0; i < this.faces.length; i++) {
      final f = this.faces[i];
      double cx = 0, cy = 0, cz = 0;
      for (final k in f) {
        cx += v[k * 3];
        cy += v[k * 3 + 1];
        cz += v[k * 3 + 2];
      }
      final a = f[0] * 3, b = f[1] * 3, c = f[2] * 3;
      final ux = v[b] - v[a], uy = v[b + 1] - v[a + 1], uz = v[b + 2] - v[a + 2];
      final wx = v[c] - v[a], wy = v[c + 1] - v[a + 1], wz = v[c + 2] - v[a + 2];
      var nx = uy * wz - uz * wy;
      var ny = uz * wx - ux * wz;
      var nz = ux * wy - uy * wx;
      // Outward, whatever order the face was listed in.
      if (nx * cx + ny * cy + nz * cz < 0) {
        nx = -nx;
        ny = -ny;
        nz = -nz;
      }
      final l = sqrt(nx * nx + ny * ny + nz * nz);
      normals[i * 3] = nx / l;
      normals[i * 3 + 1] = ny / l;
      normals[i * 3 + 2] = nz / l;
    }
  }

  final Float64List v;
  final List<Int32List> faces;
  final Float64List normals;

  int get vertexCount => v.length ~/ 3;

  /// Heat for each vertex, for veins of light bleeding through a shell:
  /// [hot] vertices chosen by [seed] burn, the rest are cold. The glow runs
  /// from a hot vertex across the faces round it and fades to nothing at
  /// their far edges.
  Float64List veins({int hot = 4, double seed = 0}) {
    final heat = Float64List(vertexCount);
    final n = vertexCount;
    for (var i = 0; i < hot; i++) {
      final at = (_hash(seed + i * 4.7) * n).floor() % n;
      heat[at] = 1;
    }
    return heat;
  }

  static double _hash(double x) {
    final s = sin(x * 12.9898) * 43758.5453;
    return s - s.floorToDouble();
  }

  /// An icosahedron, stretched to ([sx], [sy], [sz]) and roughened: each
  /// vertex pushed in or out by up to [jitter]. A rock.
  factory FacetMesh.rock({
    double sx = 1,
    double sy = 1,
    double sz = 1,
    double jitter = 0.18,
    double seed = 0,
    bool subdivide = false,
  }) {
    const p = 1.618033988749895;
    const raw = [
      -1.0, p, 0.0, 1.0, p, 0.0, -1.0, -p, 0.0, 1.0, -p, 0.0, //
      0.0, -1.0, p, 0.0, 1.0, p, 0.0, -1.0, -p, 0.0, 1.0, -p,
      p, 0.0, -1.0, p, 0.0, 1.0, -p, 0.0, -1.0, -p, 0.0, 1.0,
    ];
    final n = sqrt(1 + p * p);
    final xyz = <double>[];
    for (var i = 0; i < 12; i++) {
      final k = 1 + jitter * (2 * _hash(seed + i * 3.7) - 1);
      xyz
        ..add(raw[i * 3] / n * k * sx)
        ..add(raw[i * 3 + 1] / n * k * sy)
        ..add(raw[i * 3 + 2] / n * k * sz);
    }
    const ico = [
      [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], //
      [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
      [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
      [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
    ];
    if (!subdivide) return FacetMesh(xyz, ico);
    // Each face split in four; the new points pushed out to the surface
    // (and roughened), so the rock has finer facets and a lumpier outline.
    final mids = <int, int>{};
    int mid(int a, int b) {
      final key = min<int>(a, b) * 1000 + max<int>(a, b);
      return mids.putIfAbsent(key, () {
        final i = xyz.length ~/ 3;
        final mx = (xyz[a * 3] + xyz[b * 3]) / 2;
        final my = (xyz[a * 3 + 1] + xyz[b * 3 + 1]) / 2;
        final mz = (xyz[a * 3 + 2] + xyz[b * 3 + 2]) / 2;
        final ra = sqrt(
          xyz[a * 3] * xyz[a * 3] / (sx * sx) +
              xyz[a * 3 + 1] * xyz[a * 3 + 1] / (sy * sy) +
              xyz[a * 3 + 2] * xyz[a * 3 + 2] / (sz * sz),
        );
        final rm = sqrt(mx * mx / (sx * sx) + my * my / (sy * sy) + mz * mz / (sz * sz));
        final k = ra / rm * (1 + jitter * 0.6 * (2 * _hash(seed + i * 2.9) - 1));
        xyz
          ..add(mx * k)
          ..add(my * k)
          ..add(mz * k);
        return i;
      });
    }

    final faces = <List<int>>[];
    for (final f in ico) {
      final a = mid(f[0], f[1]), b = mid(f[1], f[2]), c = mid(f[2], f[0]);
      faces
        ..add([f[0], a, c])
        ..add([a, f[1], b])
        ..add([c, b, f[2]])
        ..add([a, b, c]);
    }
    return FacetMesh(xyz, faces);
  }

  /// An obelisk standing along +y: a tapering [sides]-sided shaft [height]
  /// tall, [base] across at its foot, under a short pyramid cap.
  factory FacetMesh.obelisk({
    int sides = 4,
    double height = 1.5,
    double base = 0.26,
    double taper = 0.72,
    double cap = 0.2,
    double seed = 0,
  }) {
    // Its point toward +y: the way "up" comes out once a ring tilts it.
    final xyz = <double>[];
    final top = height / 2 - cap, foot = -height / 2;
    for (var i = 0; i < sides; i++) {
      final a = i * 2 * pi / sides + 0.2 * (_hash(seed) - 0.5);
      xyz
        ..add(cos(a) * base)
        ..add(foot)
        ..add(sin(a) * base);
    }
    for (var i = 0; i < sides; i++) {
      final a = i * 2 * pi / sides + 0.2 * (_hash(seed) - 0.5);
      xyz
        ..add(cos(a) * base * taper)
        ..add(top)
        ..add(sin(a) * base * taper);
    }
    xyz.addAll([0, height / 2, 0]);
    final apex = sides * 2;
    final faces = <List<int>>[
      [for (var i = 0; i < sides; i++) i],
    ];
    for (var i = 0; i < sides; i++) {
      final j = (i + 1) % sides;
      faces
        ..add([i, j, sides + j, sides + i])
        ..add([sides + i, sides + j, apex]);
    }
    return FacetMesh(xyz, faces);
  }

  /// A crystal: a [sides]-sided bipyramid along the y axis, [height] from
  /// tip to tip, [radius] at its girdle. [shoulder] lifts the girdle toward
  /// the top tip (0 is the middle), so it can stand like a monolith.
  factory FacetMesh.crystal({
    int sides = 6,
    double height = 2,
    double radius = 0.6,
    double shoulder = 0,
    double jitter = 0,
    double seed = 0,
    double tipLean = 0,
  }) {
    final xyz = <double>[tipLean, -height / 2, 0, 0, height / 2, 0];
    final gy = -shoulder * height / 2;
    for (var i = 0; i < sides; i++) {
      final a = i * 2 * pi / sides;
      final k = 1 + jitter * (2 * _hash(seed + i * 5.3) - 1);
      xyz
        ..add(cos(a) * radius * k)
        ..add(gy + jitter * 0.3 * (2 * _hash(seed + i * 7.1) - 1))
        ..add(sin(a) * radius * k);
    }
    final faces = <List<int>>[];
    for (var i = 0; i < sides; i++) {
      final a = 2 + i, b = 2 + (i + 1) % sides;
      faces
        ..add([0, a, b])
        ..add([1, b, a]);
    }
    return FacetMesh(xyz, faces);
  }
}

// ── the light ───────────────────────────────────────────────────────────────

// From the upper left, toward the viewer. H is halfway to the eye.
const double _lx = -0.5, _ly = -0.62, _lz = 0.6;
final double _ll = sqrt(_lx * _lx + _ly * _ly + _lz * _lz);
final double _hx = _lx / _ll, _hy = _ly / _ll, _hz0 = _lz / _ll + 1;
final double _hl = sqrt(_hx * _hx + _hy * _hy + _hz0 * _hz0);

int _argb(Color c) => c.toARGB32();

int _mix(int a, int b, double t) {
  if (t <= 0) return a;
  if (t >= 1) return b;
  final k = (t * 256).toInt();
  final aa = (a >> 24) & 0xFF, ar = (a >> 16) & 0xFF;
  final ag = (a >> 8) & 0xFF, ab = a & 0xFF;
  final ba = (b >> 24) & 0xFF, br = (b >> 16) & 0xFF;
  final bg = (b >> 8) & 0xFF, bb = b & 0xFF;
  return ((aa + (((ba - aa) * k) >> 8)) << 24) |
      ((ar + (((br - ar) * k) >> 8)) << 16) |
      ((ag + (((bg - ag) * k) >> 8)) << 8) |
      (ab + (((bb - ab) * k) >> 8));
}

/// x^28 by squaring (x^4 · x^8 · x^16).
double _pow28(double x) {
  final x2 = x * x, x4 = x2 * x2, x8 = x4 * x4, x16 = x8 * x8;
  return x4 * x8 * x16;
}

int _withAlpha(int c, double a) =>
    ((((c >> 24) & 0xFF) * a.clamp(0.0, 1.0)).round() << 24) |
    (c & 0x00FFFFFF);

// ── batching ────────────────────────────────────────────────────────────────

/// Collects faces from any number of solids, in the order they should be
/// seen, and draws them in one call.
class MeshBatch {
  Float32List _pos = Float32List(1536);
  Int32List _col = Int32List(768);
  int _n = 0;
  Float64List _tv = Float64List(96);
  final ui.Paint _paint = ui.Paint();

  bool get isEmpty => _n == 0;

  void _grow() {
    _pos = Float32List(_pos.length * 2)..setAll(0, _pos);
    _col = Int32List(_col.length * 2)..setAll(0, _col);
  }

  void _vert(double x, double y, int c) {
    if (_n * 2 + 2 > _pos.length) _grow();
    _pos[_n * 2] = x;
    _pos[_n * 2 + 1] = y;
    _col[_n] = c;
    _n++;
  }

  /// Lays [mesh] into the batch: turned by [rot], scaled by [scale], moved
  /// to ([ox], [oy], [oz]) in the caller's space.
  ///
  /// [inset] is how much of each face gives way to the seam light;
  /// [explode] pushes faces out along their normals, as a solid cracking
  /// open; [heat] brings the light into the faces themselves.
  /// [seamAlpha] 0 draws no seams (a solid shell, or a glass one).
  /// [lit] is how much the one light can brighten a face — lower for
  /// obsidian. [fire] lights faces from a point ([gx], [gy], [gz]) in the
  /// caller's space, in the essence's color: a solid lit by the fire it
  /// stands round.
  void add(
    FacetMesh mesh,
    Rot3 rot,
    EnemyPalette pal, {
    double scale = 1,
    double ox = 0,
    double oy = 0,
    double oz = 0,
    double inset = 0.08,
    double explode = 0,
    double heat = 0,
    double seamAlpha = 1,
    double alpha = 1,
    double lit = 0.9,
    double fire = 0,
    double gx = 0,
    double gy = 0,
    double gz = 0,
    Color? tint,
    Float64List? vertexHeat,
    double heatGlow = 0,
    double rimGlow = 0,
    double dark = 0,
  }) {
    final m = rot.m;
    final nv = mesh.vertexCount;
    if (_tv.length < nv * 3) _tv = Float64List(nv * 3);
    for (var i = 0; i < nv; i++) {
      final x = mesh.v[i * 3], y = mesh.v[i * 3 + 1], z = mesh.v[i * 3 + 2];
      _tv[i * 3] = (m[0] * x + m[1] * y + m[2] * z) * scale;
      _tv[i * 3 + 1] = (m[3] * x + m[4] * y + m[5] * z) * scale;
      _tv[i * 3 + 2] = (m[6] * x + m[7] * y + m[8] * z) * scale;
    }
    const black = 0xFF050508;
    final ink = _mix(_argb(pal.ink), black, dark);
    final face = _mix(
      _argb(tint == null ? pal.face : Color.lerp(pal.face, tint, 0.4)!),
      black,
      dark * 0.8,
    );
    final rim = _mix(_argb(pal.rim), black, dark);
    final hot = _argb(pal.hot);
    final essence = _argb(pal.essence);
    final seamOuter = _withAlpha(essence, 0.9 * seamAlpha * alpha);
    final seamInner = _withAlpha(hot, seamAlpha * alpha);
    final radius = scale;
    final n = mesh.normals;

    // Two passes: the seam light under every visible face, then the faces.
    for (var pass = seamAlpha > 0 ? 0 : 1; pass < 2; pass++) {
      for (var f = 0; f < mesh.faces.length; f++) {
        final nx0 = n[f * 3], ny0 = n[f * 3 + 1], nz0 = n[f * 3 + 2];
        final nz = m[6] * nx0 + m[7] * ny0 + m[8] * nz0;
        if (nz <= 0) continue;
        final idx = mesh.faces[f];
        final i0 = idx[0];
        if (pass == 0) {
          for (var k = 1; k + 1 < idx.length; k++) {
            for (var q = 0; q < 3; q++) {
              final j = q == 0 ? i0 : idx[k + q - 1];
              final x = _tv[j * 3], y = _tv[j * 3 + 1];
              _vert(
                ox + x,
                oy + y,
                _mix(seamInner, seamOuter, sqrt(x * x + y * y) / radius),
              );
            }
          }
          continue;
        }
        final nx = m[0] * nx0 + m[1] * ny0 + m[2] * nz0;
        final ny = m[3] * nx0 + m[4] * ny0 + m[5] * nz0;
        double cx = 0, cy = 0, cz = 0;
        for (final j in idx) {
          cx += _tv[j * 3];
          cy += _tv[j * 3 + 1];
          cz += _tv[j * 3 + 2];
        }
        cx /= idx.length;
        cy /= idx.length;
        cz /= idx.length;
        // Flat shade: lambert, a fresnel rim, a specular glint.
        final lam = max(0.0, (nx * _lx + ny * _ly + nz * _lz) / _ll);
        final fres = (1 - nz) * (1 - nz);
        final spec = _pow28(
          max(0.0, (nx * _hx + ny * _hy + nz * _hz0) / _hl),
        );
        var c = _mix(ink, face, 0.08 + lit * lam);
        c = _mix(c, rim, fres * 0.5);
        // Obsidian: its own light catching the edge as the face turns away.
        if (rimGlow > 0) {
          c = _mix(c, essence, min(0.9, fres * fres * rimGlow * 2));
        }
        c = _mix(c, hot, dark > 0 ? spec * spec * 0.9 : spec * 0.85);
        if (fire > 0) {
          final dx = gx - (ox + cx), dy = gy - (oy + cy), dz = gz - (oz + cz);
          final d = sqrt(dx * dx + dy * dy + dz * dz);
          if (d > 1e-6) {
            final facing = (nx * dx + ny * dy + nz * dz) / d;
            if (facing > 0) {
              final k = fire * facing / (1 + d * d * 0.6);
              c = _mix(c, essence, min(0.85, k));
              if (k > 0.55) c = _mix(c, hot, (k - 0.55) * 0.8);
            }
          }
        }
        if (heat > 0) c = _mix(c, essence, heat);
        c = _withAlpha(c, alpha);
        final keep = 1 - inset;
        final ex = ox + nx * explode * radius + cx * inset;
        final ey = oy + ny * explode * radius + cy * inset;
        // Heat that bleeds through the shell from inside, vertex by vertex,
        // so it runs smoothly across faces instead of stopping at edges.
        final heated = vertexHeat != null && heatGlow > 0;
        for (var k = 1; k + 1 < idx.length; k++) {
          for (var q = 0; q < 3; q++) {
            final j = q == 0 ? i0 : idx[k + q - 1];
            var vc = c;
            if (heated) {
              final h = vertexHeat[j] * heatGlow;
              if (h > 0.01) {
                vc = _mix(
                  c,
                  _withAlpha(_mix(essence, hot, h * 0.7), alpha),
                  min(1.0, h),
                );
              }
            }
            _vert(ex + _tv[j * 3] * keep, ey + _tv[j * 3 + 1] * keep, vc);
          }
        }
      }
    }
  }

  /// Lays light along the edges of [mesh]'s visible faces, [width] in from
  /// each edge — a glass solid's lit edges.
  void edges(
    FacetMesh mesh,
    Rot3 rot,
    Color color, {
    double scale = 1,
    double ox = 0,
    double oy = 0,
    double width = 0.03,
    double alpha = 1,
  }) {
    final m = rot.m;
    final nv = mesh.vertexCount;
    if (_tv.length < nv * 3) _tv = Float64List(nv * 3);
    for (var i = 0; i < nv; i++) {
      final x = mesh.v[i * 3], y = mesh.v[i * 3 + 1], z = mesh.v[i * 3 + 2];
      _tv[i * 3] = (m[0] * x + m[1] * y + m[2] * z) * scale + ox;
      _tv[i * 3 + 1] = (m[3] * x + m[4] * y + m[5] * z) * scale + oy;
    }
    final c = _withAlpha(_argb(color), alpha);
    for (var f = 0; f < mesh.faces.length; f++) {
      final n = mesh.normals;
      final nz = m[6] * n[f * 3] + m[7] * n[f * 3 + 1] + m[8] * n[f * 3 + 2];
      if (nz <= 0) continue;
      final idx = mesh.faces[f];
      double cx = 0, cy = 0;
      for (final j in idx) {
        cx += _tv[j * 3];
        cy += _tv[j * 3 + 1];
      }
      cx /= idx.length;
      cy /= idx.length;
      (double, double) inward(int j) {
        final dx = cx - _tv[j * 3], dy = cy - _tv[j * 3 + 1];
        final d = sqrt(dx * dx + dy * dy);
        final k = d < 1e-6 ? 0.0 : min(1.0, width / d);
        return (_tv[j * 3] + dx * k, _tv[j * 3 + 1] + dy * k);
      }

      for (var e = 0; e < idx.length; e++) {
        final a = idx[e], b = idx[(e + 1) % idx.length];
        final (ax, ay) = inward(a);
        final (bx, by) = inward(b);
        quad(
          _tv[a * 3],
          _tv[a * 3 + 1],
          _tv[b * 3],
          _tv[b * 3 + 1],
          bx,
          by,
          ax,
          ay,
          c,
        );
      }
    }
  }

  /// Adds one flat-colored quad, for bands and ribbons.
  void quad(
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
    int color,
  ) {
    _vert(x0, y0, color);
    _vert(x1, y1, color);
    _vert(x2, y2, color);
    _vert(x0, y0, color);
    _vert(x2, y2, color);
    _vert(x3, y3, color);
  }

  void flush(Canvas c) {
    if (_n == 0) return;
    final verts = ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.sublistView(_pos, 0, _n * 2),
      colors: Int32List.sublistView(_col, 0, _n),
    );
    c.drawVertices(verts, BlendMode.srcOver, _paint);
    verts.dispose();
    _n = 0;
  }
}

/// Shades a surface of normal (nx, ny, nz) — already turned — in [pal]'s
/// shell, for callers that build their own quads. [fire] lights it from the
/// origin, as seen from where the surface is, ([px], [py], [pz]).
int shadeFacet(
  EnemyPalette pal,
  double nx,
  double ny,
  double nz, {
  Color? tint,
  double alpha = 1,
  double lit = 0.88,
  double fire = 0,
  double px = 0,
  double py = 0,
  double pz = 0,
}) {
  final lam = max(0.0, (nx * _lx + ny * _ly + nz * _lz) / _ll);
  final fres = (1 - nz.abs()) * (1 - nz.abs());
  final spec = pow(
    max(0.0, (nx * _hx + ny * _hy + nz * _hz0) / _hl),
    28,
  ).toDouble();
  final face = _argb(tint == null ? pal.face : Color.lerp(pal.face, tint, 0.7)!);
  var c = _mix(_argb(pal.ink), face, 0.1 + lit * lam);
  c = _mix(c, _argb(pal.rim), fres * 0.5);
  c = _mix(c, _argb(pal.hot), spec * 0.8);
  if (fire > 0) {
    final d = sqrt(px * px + py * py + pz * pz);
    if (d > 1e-6) {
      final facing = -(nx * px + ny * py + nz * pz) / d;
      if (facing > 0) {
        final k = fire * facing / (1 + d * d * 0.6);
        c = _mix(c, _argb(pal.essence), min(0.8, k));
      }
    }
  }
  return _withAlpha(c, alpha);
}

/// One shared batch: painting is single-threaded and each caller flushes
/// before anyone else adds.
final MeshBatch meshBatch = MeshBatch();
