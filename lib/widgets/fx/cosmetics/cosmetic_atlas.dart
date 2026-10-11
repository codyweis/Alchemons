// lib/widgets/fx/cosmetics/cosmetic_atlas.dart
//
// The kit the Athanor's case styles, trails and home ambiences draw with:
// a few soft white shapes baked once into one image, laid down by the
// hundred, each tinted and scaled, in a single drawRawAtlas. A frame of a
// trail or an ambience is one draw, however many grains are in it; nothing
// is blurred and nothing is stroked.
//
//   dot      a soft round grain (light, dust, snow, a glint)
//   bead     a firmer round grain, for grains that must read as grains
//   pool     a flat soft ellipse, 3.2 : 1 — light or mist lying on ground
//   frond0…5 a spray of frost fronds lying on the ground, lopsided, six
//            seeds (Hoarfrost Steps)
//   plume    a soft teardrop, round end down — a puff of mist, an ember's
//            glow with its tail

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/obsidian_kit.dart' show hash01;
import 'package:alchemons/games/cosmic/vfx_shapes.dart'
    show vfxRibbon, vfxShard;
import 'package:flutter/painting.dart';

/// The shapes in the atlas.
enum AtlasCell {
  dot,
  bead,
  pool,
  frond0,
  frond1,
  frond2,
  frond3,
  frond4,
  frond5,
  plume,
}

/// One of the six frost fronds, by [seed].
AtlasCell frondCell(int seed) =>
    AtlasCell.values[AtlasCell.frond0.index + seed % 6];

/// An ARGB int from a color and an alpha (0–1) over its own.
int atlasArgb(Color c, double alpha) {
  final a = (c.a * alpha).clamp(0.0, 1.0);
  return ((a * 255).round() << 24) | (c.toARGB32() & 0xFFFFFF);
}

/// Shapes gathered over a frame and drawn in one call.
class CosmeticAtlas {
  CosmeticAtlas(this.capacity)
    : _xf = Float32List(capacity * 4),
      _rects = Float32List(capacity * 4),
      _colors = Int32List(capacity);

  final int capacity;
  final Float32List _xf, _rects;
  final Int32List _colors;
  int _n = 0;

  static final Paint _paint = Paint()..filterQuality = FilterQuality.medium;

  int get length => _n;
  void clear() => _n = 0;

  /// A [cell] centred on ([x], [y]), [width] across (its height follows its
  /// own shape), turned by [rot], in [argb].
  void add(
    AtlasCell cell,
    double x,
    double y,
    double width,
    int argb, {
    double rot = 0,
  }) {
    if (_n >= capacity || width <= 0 || (argb >>> 24) == 0) return;
    final r = _cellRects[cell.index];
    final s = width / r.width;
    final sc = s * math.cos(rot), ss = s * math.sin(rot);
    final ax = r.width / 2, ay = r.height / 2;
    final i = _n * 4;
    _xf[i] = sc;
    _xf[i + 1] = ss;
    _xf[i + 2] = x - sc * ax + ss * ay;
    _xf[i + 3] = y - ss * ax - sc * ay;
    _rects[i] = r.left;
    _rects[i + 1] = r.top;
    _rects[i + 2] = r.right;
    _rects[i + 3] = r.bottom;
    _colors[_n] = argb;
    _n++;
  }

  /// Draws what was added and clears: laid over ([BlendMode.srcOver]) or
  /// light adding up on the dark ([BlendMode.plus]).
  void draw(Canvas c, {BlendMode blend = BlendMode.srcOver}) {
    if (_n == 0) return;
    _paint.blendMode = blend;
    c.drawRawAtlas(
      image,
      Float32List.sublistView(_xf, 0, _n * 4),
      Float32List.sublistView(_rects, 0, _n * 4),
      Int32List.sublistView(_colors, 0, _n),
      BlendMode.modulate,
      null,
      _paint,
    );
    _n = 0;
  }

  // ── the baked shapes ──────────────────────────────────────────────────

  static const double _u = 64;
  static final List<Rect> _cellRects = [
    const Rect.fromLTWH(0, 0, _u, _u), // dot
    const Rect.fromLTWH(_u, 0, _u, _u), // bead
    const Rect.fromLTWH(_u * 2, 0, _u * 4, _u * 1.25), // pool
    for (var s = 0; s < 6; s++)
      Rect.fromLTWH(
        (s % 3) * _u * 3,
        _u * 1.5 + (s ~/ 3) * _u * 1.25,
        _u * 3,
        _u * 1.1,
      ),
    const Rect.fromLTWH(_u * 9, 0, _u, _u * 2), // plume
  ];

  static ui.Image? _image;

  /// The atlas image, baked the first time it is needed.
  static ui.Image get image => _image ??= _bake();

  static ui.Image _bake() {
    const w = _u * 10, h = _u * 4;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const white = Color(0xFFFFFFFF);
    Color wa(double a) => white.withValues(alpha: a);

    // dot: light with no edge.
    var r = _cellRects[AtlasCell.dot.index];
    c.drawCircle(
      r.center,
      _u / 2,
      Paint()
        ..shader = ui.Gradient.radial(
          r.center,
          _u / 2,
          [white, wa(0.85), wa(0.32), wa(0.08), wa(0)],
          const [0.0, 0.14, 0.32, 0.62, 1.0],
        ),
    );
    // bead: a firmer body with a short soft rim.
    r = _cellRects[AtlasCell.bead.index];
    c.drawCircle(
      r.center,
      _u / 2,
      Paint()
        ..shader = ui.Gradient.radial(
          r.center,
          _u / 2,
          [white, white, wa(0.55), wa(0)],
          const [0.0, 0.42, 0.66, 1.0],
        ),
    );
    // pool: a flat soft ellipse.
    r = _cellRects[AtlasCell.pool.index];
    c
      ..save()
      ..translate(r.center.dx, r.center.dy)
      ..scale(r.width / 2, r.height / 2);
    c.drawCircle(
      Offset.zero,
      1,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          1,
          [white, wa(0.62), wa(0.22), wa(0.05), wa(0)],
          const [0.0, 0.3, 0.6, 0.85, 1.0],
        ),
    );
    c.restore();
    // fronds: the frost blooms, lying flat.
    for (var s = 0; s < 6; s++) {
      r = _cellRects[AtlasCell.frond0.index + s];
      c
        ..save()
        ..translate(r.center.dx, r.center.dy)
        ..scale(r.width / 2 * 0.96, r.height / 2 * 0.96);
      c.drawPath(_frond(s), Paint()..color = white);
      c.restore();
    }
    // plume: a soft teardrop, its round end at the bottom.
    r = _cellRects[AtlasCell.plume.index];
    final cx = r.center.dx;
    final body = Path()
      ..moveTo(cx, r.top + 2)
      ..quadraticBezierTo(
        cx + _u * 0.42,
        r.bottom - _u * 0.7,
        cx + _u * 0.36,
        r.bottom - _u * 0.36,
      )
      ..arcToPoint(
        Offset(cx - _u * 0.36, r.bottom - _u * 0.36),
        radius: const Radius.circular(_u * 0.37),
      )
      ..quadraticBezierTo(cx - _u * 0.42, r.bottom - _u * 0.7, cx, r.top + 2)
      ..close();
    c.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, r.bottom - _u * 0.4),
          _u * 1.4,
          [white, wa(0.45), wa(0.12), wa(0)],
          const [0.0, 0.18, 0.5, 1.0],
        ),
    );
    final pic = rec.endRecording();
    final img = pic.toImageSync(w.toInt(), h.toInt());
    pic.dispose();
    return img;
  }

  /// A lopsided spray of frost fronds, unit size, lying flat (its cell is
  /// already squashed): five to seven fronds bunched toward one side, each
  /// a tapering spine with short barbs, shorter toward the tip.
  static Path _frond(int seed) {
    final path = Path();
    final fronds = 5 + seed % 3;
    final lean = (hash01(seed, 3) - 0.5) * 1.6;
    for (var f = 0; f < fronds; f++) {
      final a =
          lean +
          (f / fronds) * math.pi * 2 * 0.86 +
          (hash01(seed * 7 + f, 4) - 0.5) * 0.7;
      final len = 0.5 + 0.45 * hash01(seed * 7 + f, 5);
      final bend = (hash01(seed * 7 + f, 6) - 0.5) * 0.6;
      final spine = <Offset>[
        for (var k = 0; k <= 6; k++)
          Offset(math.cos(a + bend * k / 6), math.sin(a + bend * k / 6)) *
              (0.1 + len * k / 6),
      ];
      path.addPath(vfxRibbon(spine, 0.11, 0.025), Offset.zero);
      for (var k = 1; k < 6; k++) {
        final g = k / 6;
        final side = k.isEven ? 1.0 : -1.0;
        final ba = a + bend * g + side * (0.8 + 0.2 * hash01(seed + k, 7));
        path.addPath(
          vfxShard(
            spine[k] + Offset(math.cos(ba), math.sin(ba)) * 0.05,
            0.16 * (1 - g * 0.6),
            0.045,
            ba,
          ),
          Offset.zero,
        );
      }
    }
    return path;
  }
}

// ── soft light, for painters that draw it once ───────────────────────────────

final Paint _poolPaint = Paint();
final Map<int, ui.Shader> _poolShaders = {};

/// Light lying soft round ([x], [y]): an ellipse [rx] by [ry] with no edge,
/// in [color] at [alpha]. One cached unit gradient per color.
void softPool(
  Canvas c,
  double x,
  double y,
  double rx,
  double ry,
  Color color,
  double alpha,
) {
  if (alpha <= 0.004 || rx <= 0 || ry <= 0) return;
  final key = color.toARGB32() | 0xFF000000;
  final shader = _poolShaders[key] ??= ui.Gradient.radial(
    Offset.zero,
    1,
    [
      color.withValues(alpha: 1),
      color.withValues(alpha: 0.45),
      color.withValues(alpha: 0.12),
      color.withValues(alpha: 0),
    ],
    const [0.0, 0.38, 0.72, 1.0],
  );
  c
    ..save()
    ..translate(x, y)
    ..scale(rx, ry);
  _poolPaint
    ..shader = shader
    ..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0));
  c.drawCircle(Offset.zero, 1, _poolPaint);
  c.restore();
}

double smoothstep(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}
