// planet_dungeon_portal.dart
//
// The descent intro, second generation: a black void of hand-drawn alchemical
// glyphs that gather into rings SPELLING THE DUNGEON'S NAME in a cipher
// alphabet, then rush past the camera as a tunnel. Every element adds one
// small twist on top of the shared portal — fire sheds embers, ice frosts in
// letter by letter and shatters as you pass, plant winds into a single vine,
// dark runs the tunnel backwards into a black core.
//
// The atmospheric dive this replaced is STASHED, not deleted:
// planet_dungeon_descent.dart still holds DescentPainter (swap it back in
// PlanetDungeonScreen._descentIntroFrame), and its per-element palettes
// (kDescentStyles) are what tint the glyphs here.
//
// Performance: the 26 cipher glyphs plus a mote and a spark are stroked ONCE
// into a 448×256 atlas (toImageSync) and every sprite on screen — rings, dust,
// embers, drips — goes out in a single drawRawAtlas call through preallocated
// buffers. The only other draws are cached fullscreen gradients and (lightning
// only) one arc path. No MaskFilter, no saveLayer, no text layout per frame.
// The old rule still holds: the dungeon behind this stays frozen until the
// fade (PlanetDungeonScreen._thawDungeon).

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/planet_dungeon/planet_dungeon_descent.dart'
    show kDescentStyles;
import 'package:flutter/material.dart';

/// How long the portal's authored intro runs before the dungeon may fade in.
/// If the dungeon is still loading after this, the tunnel keeps rushing.
const double kPortalSeconds = 1.7;

// ---------------------------------------------------------------------------
// Cipher alphabet
// ---------------------------------------------------------------------------

/// One stroke of a glyph in a unit cell (0..1, y down). Arcs are flattened
/// into wobbly polylines at bake time.
class _Stroke {
  const _Stroke.line(this.pts)
    : cx = 0,
      cy = 0,
      r = 0,
      start = 0,
      sweep = 0,
      dot = false;

  const _Stroke.arc(
    this.cx,
    this.cy,
    this.r, [
    this.start = 0,
    this.sweep = 2 * pi,
  ]) : pts = const [],
       dot = false;

  const _Stroke.dot(this.cx, this.cy)
    : pts = const [],
      r = 0,
      start = 0,
      sweep = 0,
      dot = true;

  final List<double> pts;
  final double cx, cy, r, start, sweep;
  final bool dot;
}

/// A–Z, one alchemical-ish sigil per letter. Borrowed from the real symbol
/// set where one fits (elements, planetary metals, salt, sulfur), invented
/// where it doesn't. Only needs to read as a WRITTEN SCRIPT, not be decoded.
const List<List<_Stroke>> _kCipher = [
  // A — fire
  [
    _Stroke.line([0.5, 0.1, 0.9, 0.84, 0.1, 0.84, 0.5, 0.1]),
  ],
  // B — sun
  [_Stroke.arc(0.5, 0.5, 0.38), _Stroke.dot(0.5, 0.5)],
  // C — moon
  [
    _Stroke.arc(0.5, 0.5, 0.38, 0.3 * pi, 1.4 * pi),
    _Stroke.arc(0.62, 0.5, 0.24, 0.45 * pi, 1.1 * pi),
  ],
  // D — water
  [
    _Stroke.line([0.1, 0.16, 0.9, 0.16, 0.5, 0.9, 0.1, 0.16]),
  ],
  // E — air
  [
    _Stroke.line([0.5, 0.1, 0.9, 0.84, 0.1, 0.84, 0.5, 0.1]),
    _Stroke.line([0.14, 0.56, 0.86, 0.56]),
  ],
  // F — earth
  [
    _Stroke.line([0.1, 0.16, 0.9, 0.16, 0.5, 0.9, 0.1, 0.16]),
    _Stroke.line([0.14, 0.44, 0.86, 0.44]),
  ],
  // G — mercury
  [
    _Stroke.arc(0.5, 0.06, 0.2, 0, pi),
    _Stroke.arc(0.5, 0.44, 0.17),
    _Stroke.line([0.5, 0.61, 0.5, 0.95]),
    _Stroke.line([0.34, 0.8, 0.66, 0.8]),
  ],
  // H — copper
  [
    _Stroke.arc(0.5, 0.34, 0.24),
    _Stroke.line([0.5, 0.58, 0.5, 0.95]),
    _Stroke.line([0.3, 0.78, 0.7, 0.78]),
  ],
  // I — iron
  [
    _Stroke.arc(0.4, 0.6, 0.26),
    _Stroke.line([0.59, 0.41, 0.88, 0.12]),
    _Stroke.line([0.62, 0.12, 0.88, 0.12, 0.88, 0.38]),
  ],
  // J — lead
  [
    _Stroke.line([0.36, 0.08, 0.36, 0.62]),
    _Stroke.line([0.16, 0.26, 0.58, 0.26]),
    _Stroke.line([0.36, 0.5, 0.56, 0.42, 0.74, 0.56, 0.62, 0.76, 0.82, 0.92]),
  ],
  // K — tin
  [
    _Stroke.line([0.14, 0.36, 0.32, 0.14, 0.5, 0.28, 0.22, 0.68, 0.86, 0.68]),
    _Stroke.line([0.66, 0.34, 0.66, 0.94]),
  ],
  // L — salt
  [
    _Stroke.arc(0.5, 0.5, 0.38),
    _Stroke.line([0.12, 0.5, 0.88, 0.5]),
  ],
  // M — sulfur
  [
    _Stroke.line([0.5, 0.08, 0.78, 0.48, 0.22, 0.48, 0.5, 0.08]),
    _Stroke.line([0.5, 0.48, 0.5, 0.94]),
    _Stroke.line([0.28, 0.72, 0.72, 0.72]),
  ],
  // N — globe
  [
    _Stroke.arc(0.5, 0.5, 0.38),
    _Stroke.line([0.5, 0.12, 0.5, 0.88]),
    _Stroke.line([0.12, 0.5, 0.88, 0.5]),
  ],
  // O — spiral
  [
    _Stroke.arc(0.5, 0.5, 0.38, -0.5 * pi, 1.6 * pi),
    _Stroke.arc(0.5, 0.5, 0.17, 0.5 * pi, 1.3 * pi),
  ],
  // P — stalk and seeds
  [
    _Stroke.line([0.5, 0.08, 0.5, 0.92]),
    _Stroke.dot(0.24, 0.36),
    _Stroke.dot(0.76, 0.64),
  ],
  // Q — hourglass
  [
    _Stroke.line([0.18, 0.1, 0.82, 0.1, 0.18, 0.9, 0.82, 0.9, 0.18, 0.1]),
  ],
  // R — sealed square
  [
    _Stroke.line([0.16, 0.16, 0.84, 0.16, 0.84, 0.84, 0.16, 0.84, 0.16, 0.16]),
    _Stroke.line([0.16, 0.84, 0.84, 0.16]),
  ],
  // S — twin waves
  [
    _Stroke.line([0.08, 0.4, 0.29, 0.24, 0.5, 0.4, 0.71, 0.24, 0.92, 0.4]),
    _Stroke.line([0.08, 0.76, 0.29, 0.6, 0.5, 0.76, 0.71, 0.6, 0.92, 0.76]),
  ],
  // T — trident
  [
    _Stroke.arc(0.5, 0.18, 0.3, 0, pi),
    _Stroke.line([0.5, 0.08, 0.5, 0.94]),
    _Stroke.line([0.3, 0.78, 0.7, 0.78]),
  ],
  // U — facing crescents
  [
    _Stroke.arc(0.18, 0.5, 0.3, -0.4 * pi, 0.8 * pi),
    _Stroke.arc(0.82, 0.5, 0.3, 0.6 * pi, 0.8 * pi),
  ],
  // V — rising arrow
  [
    _Stroke.line([0.5, 0.94, 0.5, 0.1]),
    _Stroke.line([0.24, 0.36, 0.5, 0.1, 0.76, 0.36]),
    _Stroke.line([0.3, 0.7, 0.7, 0.7]),
  ],
  // W — three stars in a ring
  [
    _Stroke.arc(0.5, 0.5, 0.4),
    _Stroke.dot(0.5, 0.32),
    _Stroke.dot(0.33, 0.62),
    _Stroke.dot(0.67, 0.62),
  ],
  // X — twin loops
  [_Stroke.arc(0.29, 0.5, 0.2), _Stroke.arc(0.71, 0.5, 0.2)],
  // Y — gate
  [
    _Stroke.line([0.2, 0.14, 0.8, 0.14]),
    _Stroke.line([0.4, 0.14, 0.16, 0.88]),
    _Stroke.line([0.6, 0.14, 0.84, 0.88]),
  ],
  // Z — bolt
  [
    _Stroke.line([0.62, 0.06, 0.3, 0.5, 0.66, 0.5, 0.36, 0.94]),
  ],
];

const int _kCell = 64;
const int _kCols = 7;
const int _kRows = 4;

/// Atlas cell of a soft round mote (dust, embers, drips, glow).
const int _kMote = 26;

/// Atlas cell of a small diamond (ice shards, crystal glints).
const int _kSpark = 27;

double _h(int n) {
  final v = sin(n * 127.1) * 43758.5453;
  return v - v.floorToDouble();
}

double _wrap(double v, double m) => v % m;

double _easeOutCubic(double x) => 1 - pow(1 - x, 3).toDouble();

int _lerpRgb(int a, int b, double f) {
  int ch(int s) {
    final from = (a >> s) & 0xFF;
    final to = (b >> s) & 0xFF;
    return (from + (to - from) * f).round() << s;
  }

  return ch(16) | ch(8) | ch(0);
}

/// Double-thump, 0..~1.
double _heartbeat(double t) {
  final p = t % 0.9;
  final lub = exp(-p * 14);
  final dub = p < 0.2 ? 0.0 : 0.6 * exp(-(p - 0.2) * 16);
  return lub + dub;
}

/// Strokes the cipher into a white-on-transparent atlas, once per app run.
/// Every point gets a small deterministic wobble so the script reads as
/// hand-written rather than typeset.
ui.Image _bakeAtlas() {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  final pen = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFFFFFFFF);
  final fill = Paint()..color = const Color(0xFFFFFFFF);
  final path = Path();
  const pad = 8.0;
  const inner = _kCell - pad * 2;

  for (var g = 0; g < _kCipher.length; g++) {
    final ox = (g % _kCols) * _kCell + pad;
    final oy = (g ~/ _kCols) * _kCell + pad;
    pen.strokeWidth = 5.8 + _h(g * 31 + 5) * 1.6;
    var k = 0;
    Offset p(double x, double y) {
      k++;
      final jx = (_h(g * 97 + k * 13) - 0.5) * 0.06;
      final jy = (_h(g * 89 + k * 17) - 0.5) * 0.06;
      return Offset(ox + (x + jx) * inner, oy + (y + jy) * inner);
    }

    for (final s in _kCipher[g]) {
      if (s.dot) {
        canvas.drawCircle(p(s.cx, s.cy), pen.strokeWidth, fill);
        continue;
      }
      path.reset();
      if (s.pts.isNotEmpty) {
        final a = p(s.pts[0], s.pts[1]);
        path.moveTo(a.dx, a.dy);
        for (var i = 2; i + 1 < s.pts.length; i += 2) {
          final b = p(s.pts[i], s.pts[i + 1]);
          path.lineTo(b.dx, b.dy);
        }
      } else {
        final n = max(4, (18 * s.sweep / (2 * pi)).ceil());
        for (var i = 0; i <= n; i++) {
          final a = s.start + s.sweep * i / n;
          final q = p(s.cx + cos(a) * s.r, s.cy + sin(a) * s.r);
          if (i == 0) {
            path.moveTo(q.dx, q.dy);
          } else {
            path.lineTo(q.dx, q.dy);
          }
        }
      }
      canvas.drawPath(path, pen);
    }
  }

  Offset cellCenter(int cell) => Offset(
    (cell % _kCols) * _kCell + _kCell / 2,
    (cell ~/ _kCols) * _kCell + _kCell / 2,
  );

  final mc = cellCenter(_kMote);
  canvas.drawCircle(
    mc,
    _kCell * 0.3,
    Paint()
      ..shader = ui.Gradient.radial(mc, _kCell * 0.3, const [
        Color(0xFFFFFFFF),
        Color(0x00FFFFFF),
      ]),
  );

  final sc = cellCenter(_kSpark);
  path
    ..reset()
    ..moveTo(sc.dx, sc.dy - 26)
    ..lineTo(sc.dx + 9, sc.dy)
    ..lineTo(sc.dx, sc.dy + 26)
    ..lineTo(sc.dx - 9, sc.dy)
    ..close();
  canvas.drawPath(path, fill);

  final picture = rec.endRecording();
  final image = picture.toImageSync(_kCols * _kCell, _kRows * _kCell);
  picture.dispose();
  return image;
}

/// Glyph cells for [title]: letters map to the cipher, anything else is a gap,
/// and a three-slot gap separates repeats around the ring.
List<int> _codesFor(String title) => [
  for (final u in title.toUpperCase().codeUnits)
    u >= 65 && u <= 90 ? u - 65 : -1,
  -1,
  -1,
  -1,
];

/// Preallocated drawRawAtlas buffers — no per-sprite allocation.
class _Sprites {
  static const int cap = 1400;
  final Float32List xf = Float32List(cap * 4);
  final Float32List rects = Float32List(cap * 4);
  final Int32List colors = Int32List(cap);
  int n = 0;

  void add(
    int cell,
    double x,
    double y,
    double size,
    double rot,
    int rgb,
    double alpha,
  ) {
    if (n >= cap || alpha <= 0.01 || size < 0.8) return;
    final scale = size / _kCell;
    final sc = cos(rot) * scale;
    final ss = sin(rot) * scale;
    const anchor = _kCell / 2;
    final i = n * 4;
    xf[i] = sc;
    xf[i + 1] = ss;
    xf[i + 2] = x - sc * anchor + ss * anchor;
    xf[i + 3] = y - ss * anchor - sc * anchor;
    final l = ((cell % _kCols) * _kCell).toDouble();
    final t = ((cell ~/ _kCols) * _kCell).toDouble();
    rects[i] = l;
    rects[i + 1] = t;
    rects[i + 2] = l + _kCell;
    rects[i + 3] = t + _kCell;
    colors[n] = ((alpha.clamp(0.0, 1.0) * 255).round() << 24) | rgb;
    n++;
  }

  void draw(Canvas canvas, ui.Image atlas, Paint paint) {
    canvas.drawRawAtlas(
      atlas,
      Float32List.sublistView(xf, 0, n * 4),
      Float32List.sublistView(rects, 0, n * 4),
      Int32List.sublistView(colors, 0, n),
      BlendMode.modulate,
      null,
      paint,
    );
  }
}

/// Fullscreen gradients, rebuilt only when the size or tint changes.
class _PortalBg {
  Size? size;
  Color? tint;
  ui.Shader? wash;
  ui.Shader? glow;
  ui.Shader? core;
  ui.Shader? vignette;

  void ensure(Size s, Offset c, Color t, double baseR, double maxR) {
    if (size == s && tint == t) return;
    size = s;
    tint = t;
    wash = ui.Gradient.radial(c, maxR, [
      t.withValues(alpha: 0.10),
      const Color(0x00000000),
    ]);
    glow = ui.Gradient.radial(Offset.zero, baseR * 0.45, [
      Color.lerp(t, const Color(0xFFFFFFFF), 0.45)!.withValues(alpha: 0.22),
      const Color(0x00000000),
    ]);
    core = ui.Gradient.radial(
      c,
      baseR * 0.3,
      const [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
      const [0.0, 0.45, 1.0],
    );
    vignette = ui.Gradient.radial(
      c,
      maxR * 1.15,
      const [Color(0x00000000), Color(0xCC000000)],
      const [0.55, 1.0],
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class PortalPainter extends CustomPainter {
  PortalPainter({
    required this.elapsed,
    required this.element,
    required this.title,
    required this.accent,
    this.palette,
    this.tint,
  });

  final double elapsed;

  /// Picks the palette and the per-element twist. Anything that is not one of
  /// the 17 elements (e.g. '' for the trip into cosmic space) gets the plain
  /// portal with no twist.
  final String element;

  /// The name written around the rings. Falls back to [element].
  final String title;
  final Color accent;

  /// Glyph accent colours, overriding the element's. For portals that are not
  /// a planet.
  final List<Color>? palette;

  /// Void wash colour, overriding the element's sky tint.
  final Color? tint;

  static const int _rings = 6;
  static const int _slots = 44;
  static const double _near = 0.5;
  static const double _far = 6.0;
  static const double _span = _far - _near;
  static const double _gatherSeconds = 0.6;
  static const int _dustCount = 220;
  static const int _parchment = 0xE8DFC8;

  static ui.Image? _atlas;
  static final _Sprites _sprites = _Sprites();
  static final _PortalBg _bg = _PortalBg();
  static String? _codesKey;
  static List<int> _codes = const [-1];

  static final Paint _voidPaint = Paint()..color = const Color(0xFF050507);
  // Shader paint: its color is never touched (a Paint's alpha modulates its
  // shader — see the same note in DescentPainter).
  static final Paint _bgPaint = Paint();
  static final Paint _atlasPaint = Paint()
    ..blendMode = BlendMode.plus
    ..filterQuality = FilterQuality.low;
  static final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Path _path = Path();

  /// Camera distance travelled: eases from a drift into a rush over the
  /// authored intro, then holds the rush for as long as loading takes.
  static double _travel(double t) {
    const v0 = 0.9;
    const v1 = 3.2;
    if (t <= kPortalSeconds) {
      return v0 * t + (v1 - v0) * t * t / (2 * kPortalSeconds);
    }
    return v0 * kPortalSeconds +
        (v1 - v0) * kPortalSeconds / 2 +
        v1 * (t - kPortalSeconds);
  }

  /// The tunnel's slow sway, in screen px at depth 1 (scaled by 1/z).
  static Offset _drift(double t, double shortest) =>
      Offset(sin(t * 0.7) * 0.05, cos(t * 0.55) * 0.035) * shortest;

  static double _ringRotation(
    String el,
    double t,
    double dir,
    double spin,
    int i,
  ) {
    if (el == 'earth') {
      // Stone dials: a heavy turn, then a hold — never a smooth spin.
      final steps = t * 1.8 + i * 0.37;
      final whole = steps.floorToDouble();
      final f = steps - whole;
      final eased = f < 0.35 ? _easeOutCubic(f / 0.35) : 1.0;
      return dir * (whole + eased) * (2 * pi / _slots) * 3 + i;
    }
    return dir * t * spin + i * 0.9;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final atlas = _atlas ??= _bakeAtlas();
    final key = title.isEmpty ? element : title;
    if (_codesKey != key) {
      _codesKey = key;
      _codes = _codesFor(key);
    }
    final el = element.toLowerCase();
    final style = kDescentStyles[el];
    final palette = [
      for (final c in this.palette ?? style?.colors ?? [accent])
        c.toARGB32() & 0xFFFFFF,
    ];
    final tint = this.tint ?? style?.skyTint ?? accent;
    final t = elapsed;
    final c = Offset(size.width / 2, size.height * 0.46);
    final shortest = size.shortestSide;
    final baseR = shortest * 0.42;
    final maxR = size.longestSide * 0.75;
    final travel = _travel(t) * (el == 'dark' ? -1.0 : 1.0);

    _bg.ensure(size, c, tint, baseR, maxR);
    canvas.drawRect(Offset.zero & size, _voidPaint);
    _bgPaint.shader = _bg.wash;
    canvas.drawRect(Offset.zero & size, _bgPaint);

    if (el != 'dark') {
      final grow = 0.7 + 0.6 * min(1.0, t / kPortalSeconds);
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..scale(grow);
      _bgPaint.shader = _bg.glow;
      canvas.drawCircle(Offset.zero, baseR * 0.45, _bgPaint);
      canvas.restore();
    }

    final sp = _sprites..n = 0;
    _addDust(sp, c, maxR, palette, t, travel);
    _addTunnel(sp, el, c, shortest, baseR, maxR, palette, t, travel);
    if (sp.n > 0) sp.draw(canvas, atlas, _atlasPaint);

    if (el == 'lightning') {
      _drawArc(canvas, c, shortest, baseR, palette, t, travel);
    }
    if (el == 'dark') {
      _bgPaint.shader = _bg.core;
      canvas.drawCircle(c, baseR * 0.3, _bgPaint);
    }

    _bgPaint.shader = _bg.vignette;
    canvas.drawRect(Offset.zero & size, _bgPaint);
  }

  /// The starfield: loose glyphs and motes streaming out of the vanishing
  /// point (into it, for dark).
  void _addDust(
    _Sprites sp,
    Offset c,
    double maxR,
    List<int> palette,
    double t,
    double travel,
  ) {
    final codes = _codes;
    for (var d = 0; d < _dustCount; d++) {
      final speed = 0.08 + _h(d * 7 + 1) * 0.16;
      final phase = _wrap(travel * speed + _h(d * 7 + 2), 1);
      final a = _h(d * 7 + 4) * 2 * pi + t * 0.04;
      final rad = pow(phase, 2.2) * maxR * 1.15 + 8;
      final alpha =
          (phase * 6).clamp(0.0, 1.0) *
          (0.3 + 0.5 * _h(d * 7 + 5)) *
          (1 - phase * 0.4);
      final code = codes[d % codes.length];
      final mote = code < 0 || _h(d * 7 + 6) < 0.3;
      final gsize =
          (mote ? 3.0 : 5.0) + phase * (mote ? 4 : 12) * _h(d * 7 + 3);
      final rgb = _h(d * 7 + 8) < 0.14
          ? palette[d % palette.length]
          : _parchment;
      sp.add(
        mote ? _kMote : code,
        c.dx + cos(a) * rad,
        c.dy + sin(a) * rad,
        gsize,
        (_h(d * 7 + 9) - 0.5) * 0.8,
        rgb,
        alpha,
      );
    }
  }

  /// The rings: the dungeon's name written around each, receding in depth,
  /// gathered out of the void in the first [_gatherSeconds], then each
  /// element's twist applied per glyph.
  void _addTunnel(
    _Sprites sp,
    String el,
    Offset c,
    double shortest,
    double baseR,
    double maxR,
    List<int> palette,
    double t,
    double travel,
  ) {
    const gap = _span / _rings;
    final spin = switch (el) {
      'air' => 0.8,
      'mud' => 0.16,
      _ => 0.34,
    };
    final drift = _drift(t, shortest);
    final gather = t / _gatherSeconds;
    final beat = el == 'blood' ? _heartbeat(t) : 0.0;
    final codes = _codes;
    final last = palette.length - 1;

    for (var i = 0; i < _rings; i++) {
      final dir = i.isEven ? 1.0 : -1.0;
      final k = _easeOutCubic(
        ((gather - _h(i * 53 + 7) * 0.3) / 0.7).clamp(0.0, 1.0),
      );
      final accentShare = i.isOdd ? 0.34 : 0.1;
      final ringRot = _ringRotation(el, t, dir, spin, i);

      for (var j = 0; j < _slots; j++) {
        var cell = codes[(j + i * 7) % codes.length];
        if (cell < 0) continue;
        final u = j / _slots;
        final hg = _h(i * 131 + j * 17 + 3);
        // Plant: each glyph sits a little deeper than the last, so the rings
        // become one continuous vine winding away from the camera.
        final depth = el == 'plant' ? i + u : i.toDouble();
        final z = _near + _wrap(depth * gap - travel + gap * 0.5, _span);
        var alpha =
            ((_far - z) / 1.3).clamp(0.0, 1.0) *
            ((z - _near) / 0.45).clamp(0.0, 1.0) *
            (0.72 + 0.28 * _h(i * 71 + j * 5));
        if (alpha <= 0.01) continue;
        final persp = 1.0 / z;
        final age = (_far - z) / _span; // 0 just appeared … 1 at the camera

        var r = baseR * persp * (1 + beat * 0.07);
        var ang = u * 2 * pi + ringRot;
        if (el == 'dark') ang += dir * z * 0.35; // swirl harder near the core
        var rot = ang + pi / 2;
        if (el == 'water') r *= 1 + 0.05 * sin(ang * 5 + t * 4 + i);
        if (el == 'crystal') {
          const sector = pi / 3;
          final local = _wrap(ang - ringRot, sector) - sector / 2;
          r *= cos(sector / 2) / cos(local);
          rot = ang - local + pi / 2;
        }
        final center = c + drift * persp;
        var px = center.dx + cos(ang) * r;
        var py = center.dy + sin(ang) * r;
        var gsize = 2 * pi * r / _slots * 1.08;
        var rgb = hg < accentShare
            ? palette[(hg * 97).floor() % palette.length]
            : _parchment;

        switch (el) {
          case 'fire':
            if (hg < 0.12) {
              final rise = _wrap(t * 0.9 + hg * 13, 1);
              sp.add(
                _kMote,
                px + sin(t * 3 + j) * 3,
                py - rise * r * 0.35,
                gsize * 0.5 * (1 - rise),
                0,
                palette[last],
                alpha * (1 - rise) * k,
              );
            }
          case 'water':
            if (hg < 0.14) {
              final d = _wrap(t * 0.7 + hg * 11, 1);
              sp.add(
                _kMote,
                px,
                py + d * d * gsize * 2.4,
                gsize * 0.32,
                0,
                palette[0],
                alpha * (1 - d) * 0.8 * k,
              );
            }
          case 'air':
            if (hg < 0.22) {
              final flutter = sin(t * 2.4 + hg * 40) * gsize * 0.9;
              px += cos(ang) * flutter;
              py += sin(ang) * flutter;
              rot += t * (hg * 40 - 4);
            }
          case 'lightning':
            final chase = pow(
              max(0.0, cos(u * 6 * pi - t * 9 + i)),
              8,
            ).toDouble();
            alpha = (alpha * (0.4 + 0.9 * chase)).clamp(0.0, 1.0);
            if (chase > 0.6) rgb = palette[1];
          case 'steam':
            alpha *= ((age - 0.08) / 0.25).clamp(0.0, 1.0);
            final e = ((1.4 - z) / 0.9).clamp(0.0, 1.0);
            gsize *= 1 + e * 0.8;
            alpha *= 1 - e;
            py -= e * gsize * 1.5;
            px += sin(j * 1.7 + t * 2) * e * gsize;
          case 'lava':
            if (hg < 0.6) {
              rgb = _lerpRgb(0x991B1B, 0xFFD27A, ((z - _near) / _span));
            }
            final sn = sin(ang);
            if (sn > 0) {
              py += sn * sn * gsize * 0.5 * (0.6 + 0.4 * sin(t * 1.2 + j));
            }
          case 'mud':
            py +=
                (center.dy - py) * 0.1 +
                r * 0.05 +
                sin(t * 1.1 + j * 0.6) * gsize * 0.15;
          case 'ice':
            alpha *= ((age * 2.6 - u) * 8).clamp(0.0, 1.0);
            final shatter = ((1.25 - z) / 0.75).clamp(0.0, 1.0);
            if (shatter > 0) {
              final out = shatter * shatter * r * 0.5 * (0.4 + hg);
              px += cos(ang) * out;
              py += sin(ang) * out;
              rot += shatter * 6 * (hg - 0.5);
              if (shatter > 0.4) {
                cell = _kSpark;
                gsize *= 0.55;
              }
            }
          case 'dust':
            final e = _wrap(u + t * 0.15 * dir, 1);
            if (e > 0.62) {
              final er = (e - 0.62) / 0.38;
              sp.add(
                _kMote,
                px + sin(ang) * dir * er * gsize * 1.6,
                py - cos(ang) * dir * er * gsize * 1.6,
                gsize * 0.22,
                0,
                palette[0],
                alpha * er * 0.7 * k,
              );
              alpha *= 1 - er;
            }
          case 'crystal':
            final glint = pow(
              max(0.0, cos(u * 2 * pi - t * 2.2 - i)),
              24,
            ).toDouble();
            if (glint > 0.3) {
              sp.add(
                _kSpark,
                px,
                py,
                gsize * 1.5 * glint,
                t * 2,
                palette[1],
                glint * alpha * k,
              );
            }
            alpha = (alpha + glint * 0.5).clamp(0.0, 1.0);
          case 'plant':
            rot += sin(t * 2 + j * 0.5) * 0.35;
          case 'poison':
            final b = sin(t * 4 + hg * 20);
            gsize *= 1 + 0.22 * b * b;
            final off = sin(t * 1.6 + hg * 30) * gsize * 0.7;
            px += cos(ang) * off;
            py += sin(ang) * off;
            if (hg < 0.08) {
              final rise = _wrap(t * 0.6 + hg * 17, 1);
              sp.add(
                _kMote,
                px,
                py - rise * gsize * 3,
                gsize * 0.4,
                0,
                palette[0],
                alpha * (1 - rise) * k,
              );
            }
          case 'spirit':
            final ga = ang - dir * 0.22;
            final gr = r * 1.06;
            sp.add(
              cell,
              center.dx + cos(ga) * gr,
              center.dy + sin(ga) * gr,
              gsize,
              ga + pi / 2,
              palette[last],
              alpha * 0.3 * k,
            );
          case 'light':
            final beam = pow(max(0.0, cos(ang - t * 3.0)), 10).toDouble();
            alpha = (alpha * (0.35 + 1.1 * beam)).clamp(0.0, 1.0);
            if (beam > 0.5) {
              rgb = palette[last];
              sp.add(
                _kMote,
                px,
                py,
                gsize * 2.2 * beam,
                0,
                palette[0],
                0.35 * beam * alpha * k,
              );
            }
          case 'blood':
            alpha = (alpha * (0.7 + 0.45 * beat)).clamp(0.0, 1.0);
            if (hg < 0.5) rgb = palette[(hg * 7).floor() % palette.length];
        }

        // Gathering: every glyph starts scattered through the void and is
        // drawn into its slot on the ring.
        if (k < 1) {
          final sa = _h(i * 1009 + j * 7 + 1) * 2 * pi;
          final sr = (0.15 + _h(i * 1013 + j * 7 + 2)) * maxR;
          final sx = c.dx + cos(sa) * sr;
          final sy = c.dy + sin(sa) * sr;
          px = sx + (px - sx) * k;
          py = sy + (py - sy) * k;
          rot = sa * 3 + (rot - sa * 3) * k;
          gsize *= 0.6 + 0.4 * k;
          alpha *= 0.5 + 0.5 * k;
        }

        sp.add(cell, px, py, gsize, rot, rgb, alpha);
      }
    }
  }

  /// Lightning: a short arc jumps between two neighbouring rings a few times
  /// a second.
  void _drawArc(
    Canvas canvas,
    Offset c,
    double shortest,
    double baseR,
    List<int> palette,
    double t,
    double travel,
  ) {
    final cycle = t * 3.2;
    final f = cycle - cycle.floorToDouble();
    if (f > 0.35) return;
    final seed = cycle.floor();
    const gap = _span / _rings;
    final ring = (_h(seed * 17 + 1) * _rings).floor();
    final za = _near + _wrap(ring * gap - travel + gap * 0.5, _span);
    final zb = za + gap;
    if (za < 0.8 || zb > _far - 0.5) return;
    final ang = _h(seed * 17 + 2) * 2 * pi;
    final drift = _drift(t, shortest);
    final dirv = Offset(cos(ang), sin(ang));
    final pa = c + drift / za + dirv * (baseR / za);
    final pb = c + drift / zb + dirv * (baseR / zb);
    final perp = Offset(-dirv.dy, dirv.dx);
    final len = (pa - pb).distance;
    final path = _path
      ..reset()
      ..moveTo(pa.dx, pa.dy);
    const segs = 5;
    for (var s = 1; s < segs; s++) {
      final q =
          Offset.lerp(pa, pb, s / segs)! +
          perp * ((_h(seed * 17 + s + 3) - 0.5) * len * 0.35);
      path.lineTo(q.dx, q.dy);
    }
    path.lineTo(pb.dx, pb.dy);
    final fade = 1 - f / 0.35;
    _stroke
      ..strokeWidth = 1.6
      ..color = Color(0xFF000000 | palette[1]).withValues(alpha: 0.9 * fade);
    canvas.drawPath(path, _stroke);
  }

  @override
  bool shouldRepaint(covariant PortalPainter old) =>
      elapsed != old.elapsed || element != old.element || title != old.title;
}
