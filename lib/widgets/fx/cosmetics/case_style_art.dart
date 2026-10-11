// lib/widgets/fx/cosmetics/case_style_art.dart
//
// The Athanor's specimen-case styles: what a specimen stands in on the
// Creatures tab instead of the plain dark glass, one per batch. Each keeps
// the element's light, smaller, so the case still says what the creature
// is. Static: drawn in CaseLightPainter's place, it repaints only when its
// style or color changes, and its grains are one atlas draw.
//
// From the concept prototypes (docs/crucible/concepts/cases.png),
// with the two looks the renders found wanting redone as material: the
// Gold Case is one sheet of gold leaf (the leaves no longer read as cracked
// stone), and the Frost Case's corners are frost grown on glass — a milky
// haze thickening into the corner with feathered crystal at its edge —
// rather than scattered specks (which read as scratches and cobwebs).

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/obsidian_kit.dart'
    show StoneLight, hash01, paintFill, paintOrb, polyPath;
import 'package:alchemons/games/cosmic/vfx_shapes.dart' show vfxShard;
import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/widgets/fx/cosmetics/cosmetic_atlas.dart';
import 'package:flutter/rendering.dart';

/// The vials' dark glass (kVialGlass), under every case.
const Color _glass = Color(0xE60B0A10);

final Paint _fill = Paint()..isAntiAlias = true;

void _solid(Canvas c, Path p, Color color) {
  _fill
    ..shader = null
    ..color = color;
  c.drawPath(p, _fill);
}

/// A case of [style] lit in [color] (the specimen's element light,
/// `caseElementLight`).
class CaseStylePainter extends CustomPainter {
  const CaseStylePainter({required this.style, required this.color});

  final CaseStyle style;
  final Color color;

  static final CosmeticAtlas _atlas = CosmeticAtlas(1400);

  @override
  void paint(Canvas canvas, Size size) =>
      paintCaseStyle(canvas, style, size, color);

  @override
  bool shouldRepaint(CaseStylePainter old) =>
      old.style != style || old.color != color;
}

/// Cases already drawn, by style, size and light, newest last: a case is
/// still, so a second one like it (a grid of them, a tile drawn every frame
/// on the Athanor) replays the first instead of drawing it again.
final Map<(CaseStyle, int, int, int), ui.Picture> _drawn = {};

/// Paints a case of [style] filling [size], lit in [color].
void paintCaseStyle(Canvas c, CaseStyle style, Size size, Color color) {
  final w = size.width, h = size.height;
  if (w <= 0 || h <= 0) return;
  final key = (style, (w * 4).round(), (h * 4).round(), color.toARGB32());
  var picture = _drawn.remove(key);
  if (picture == null) {
    final rec = ui.PictureRecorder();
    _paintCase(Canvas(rec), style, w, h, color);
    picture = rec.endRecording();
    if (_drawn.length >= 32) _drawn.remove(_drawn.keys.first)?.dispose();
  }
  _drawn[key] = picture;
  c.drawPicture(picture);
}

void _paintCase(Canvas c, CaseStyle style, double w, double h, Color color) {
  final size = Size(w, h);
  c.drawRect(Offset.zero & size, Paint()..color = _glass);
  switch (style) {
    case CaseStyle.gilt:
      _gilt(c, w, h);
    case CaseStyle.obsidian:
      _obsidian(c, w, h);
    case CaseStyle.frost:
      _frost(c, w, h);
    case CaseStyle.garnet:
      _garnet(c, w, h);
    case CaseStyle.brass:
      _brass(c, w, h);
  }
  // The element's light behind the specimen and on its floor, as the plain
  // case has it but smaller, over whichever back it has.
  softPool(c, w / 2, h * 0.5, w * 0.42, h * 0.36, color, 0.16);
  softPool(c, w / 2, h * 0.88, w * 0.44, w * 0.1, color, 0.36);
}

/// A tall arch behind the specimen.
Path _arch(double w, double h, {double inset = 0.14, double top = 0.08}) {
  final l = w * inset, r = w * (1 - inset), t = h * top, foot = h * 0.9;
  final rad = (r - l) / 2;
  return Path()
    ..moveTo(l, foot)
    ..lineTo(l, t + rad)
    ..arcToPoint(Offset(r, t + rad), radius: Radius.circular(rad))
    ..lineTo(r, foot)
    ..close();
}

/// The arch's edge as a soft inset of shadow (never a drawn line).
void _archInset(Canvas c, double w, double h, double inset, Color shade) {
  final arch = _arch(w, h, inset: inset);
  c.save();
  c.clipPath(arch);
  final edge = Path()
    ..fillType = PathFillType.evenOdd
    ..addPath(arch, Offset.zero)
    ..addPath(
      _arch(w, h, inset: inset + 0.03).shift(Offset(0, h * 0.014)),
      Offset.zero,
    );
  _solid(c, edge, shade);
  c.restore();
}

// ── Gilt ────────────────────────────────────────────────────────────────────

void _gilt(Canvas c, double w, double h) {
  final arch = _arch(w, h);
  // One sheet of gold: lamp-lit at the top, deepening to old gold below.
  paintFill(
    c,
    arch,
    ui.Gradient.linear(
      Offset(0, h * 0.06),
      Offset(0, h * 0.9),
      const [
        Color(0xFFEACD8A),
        Color(0xFFCFA457),
        Color(0xFF9A7432),
        Color(0xFF5E461B),
      ],
      const [0.0, 0.3, 0.66, 1.0],
    ),
  );
  c.save();
  c.clipPath(arch);
  // The leaves, laid in rows as a gilder lays them: squares a shade off
  // their neighbours, each row overlapping the one below, the overlap's
  // lip just catching the lamp. Only just told apart — one sheet of metal,
  // not tiles with seams.
  final cell = w * 0.2;
  var i = 0;
  for (var row = 0; row * cell < h; row++) {
    final y = h * 0.04 + row * cell * 0.96;
    final shift = row.isOdd ? cell * 0.42 : 0.0;
    for (var x = w * 0.1 - shift; x < w * 0.92; x += cell * 0.97, i++) {
      final tone = hash01(i, 9) - 0.5;
      final leaf = Rect.fromLTWH(x, y, cell, cell);
      _fill
        ..shader = null
        ..color = tone > 0
            ? Color.fromRGBO(255, 240, 196, 0.1 * tone)
            : Color.fromRGBO(70, 44, 10, 0.12 * -tone);
      c.drawRect(leaf, _fill);
      // The lip of the leaf above lying over this one.
      _fill.color = Color.fromRGBO(
        255,
        246,
        220,
        0.025 + 0.025 * hash01(i, 10),
      );
      c.drawRect(Rect.fromLTWH(x, y, cell, cell * 0.035), _fill);
    }
  }
  // Leaf is metal: a broad sheen across it, as from the lamp, and a
  // second fainter one.
  c.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * 0.05, h * 0.18),
        Offset(w * 0.95, h * 0.66),
        const [
          Color(0x00FFF2CC),
          Color(0x48FFF2CC),
          Color(0x00FFF2CC),
          Color(0x00FFF2CC),
          Color(0x1EFFF2CC),
          Color(0x00FFF2CC),
        ],
        const [0.14, 0.3, 0.44, 0.6, 0.7, 0.82],
      ),
  );
  // A few fine creases catching the lamp, near it: thin bright slivers
  // lying across the leaf.
  for (var k = 0; k < 5; k++) {
    final cx = w * (0.26 + 0.48 * hash01(k, 31));
    final cy = h * (0.12 + 0.3 * hash01(k, 32));
    _solid(
      c,
      vfxShard(
        Offset(cx, cy),
        w * (0.05 + 0.05 * hash01(k, 33)),
        w * 0.006,
        (hash01(k, 34) - 0.5) * 0.7,
      ),
      Color.fromRGBO(255, 250, 230, 0.16 + 0.16 * (1 - cy / (h * 0.45))),
    );
  }
  // The lamp above it, and the panel falling into shadow below.
  softPool(c, w / 2, h * 0.04, w * 0.6, h * 0.3, const Color(0xFFFFE6AA), 0.55);
  c.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, h * 0.42),
        Offset(0, h * 0.95),
        const [Color(0x00000000), Color(0x8C090806)],
      ),
  );
  c.restore();
  _archInset(c, w, h, 0.14, const Color(0x99120C04));
  // The floor takes the gold's light.
  softPool(c, w / 2, h * 0.9, w * 0.5, w * 0.11, const Color(0xFFE0A84A), 0.34);
}

// ── Obsidian ────────────────────────────────────────────────────────────────

void _obsidian(Canvas c, double w, double h) {
  final arch = _arch(w, h, inset: 0.1);
  paintFill(
    c,
    arch,
    ui.Gradient.linear(
      Offset(w * 0.2, 0),
      Offset(w * 0.85, h),
      const [Color(0xFF1C1726), Color(0xFF0B0A10), Color(0xFF050407)],
      const [0.0, 0.5, 1.0],
    ),
  );
  c.save();
  c.clipPath(arch);
  // The oil-slick sheen: one soft diagonal band, its colors running into
  // each other — faint, as oil on black water is.
  const oil = [0x6A3AB8, 0x3A62D0, 0x22A8A4, 0xC8A044, 0xB8508E];
  const strips = 12;
  for (var i = 0; i < strips; i++) {
    final f = i / (strips - 1);
    final env = math.sin(math.pi * f);
    final x0 = w * (0.05 + 0.4 * f), x1 = x0 + w * 0.08;
    _solid(
      c,
      polyPath([
        Offset(x0 - w * 0.3, h),
        Offset(x1 - w * 0.3, h),
        Offset(x1 + w * 0.35, 0),
        Offset(x0 + w * 0.35, 0),
      ]),
      Color(0xFF000000 | oil[i % oil.length]).withValues(alpha: 0.075 * env),
    );
  }
  // Glass: the lit lip round the top of the arch.
  softPool(
    c,
    w * 0.34,
    h * 0.12,
    w * 0.3,
    h * 0.06,
    const Color(0xFFB9A6E8),
    0.22,
  );
  c.restore();
  _archInset(c, w, h, 0.1, const Color(0xB0000000));
  softPool(c, w / 2, h * 0.9, w * 0.5, w * 0.1, const Color(0xFFB48CFF), 0.22);
}

// ── Frost ───────────────────────────────────────────────────────────────────

void _frost(Canvas c, double w, double h) {
  // Cold light from above, falling on a faintly blue glass.
  c.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, h),
        const [Color(0x2A9CC8F0), Color(0x0A9CC8F0), Color(0x00000000)],
        const [0.0, 0.45, 1.0],
      ),
  );
  softPool(c, w / 2, 0, w * 0.78, h * 0.5, const Color(0xFFBFE4FF), 0.28);

  // Frost grown in from each corner, as on a window: milky where it is
  // thick, a fine frosted grain thinning out to a ragged edge, a few
  // crystals in it catching the light.
  final atlas = CaseStylePainter._atlas..clear();
  const ice = Color(0xFFE6F4FF);
  const rime = Color(0xFFCFE6FA);
  final corners = <(double, double, double)>[
    (0.0, 0.0, 0.38),
    (w, 0.0, 0.3),
    (0.0, h, 0.52),
    (w, h, 0.44),
  ];
  var k = 0;
  for (final (cx, cy, reach) in corners) {
    final sx = cx > 0 ? -1.0 : 1.0, sy = cy > 0 ? -1.0 : 1.0;
    final r = w * reach;
    // How far the frost reaches at angle [a] (0 along the top or bottom
    // edge, pi/2 down or up the side): ragged, never a quarter circle.
    double front(double a) =>
        r *
        (0.8 +
            0.16 * math.sin(a * 6 + reach * 23) +
            0.1 * math.sin(a * 15 + reach * 7) +
            0.06 * math.sin(a * 31 + 2.1));
    // The milk of it.
    softPool(c, cx, cy, r * 0.95, r * 0.95, rime, 0.36);
    softPool(c, cx, cy, r * 0.5, r * 0.5, ice, 0.5);
    // The frosted grain: many small soft grains overlapping into a crust,
    // densest in the corner.
    for (var g = 0; g < 600; g++, k++) {
      final a = hash01(k, 13) * math.pi / 2;
      final f = math.pow(hash01(k, 14), 1.25).toDouble();
      final d = f * front(a);
      atlas.add(
        AtlasCell.dot,
        cx + sx * math.cos(a) * d,
        cy + sy * math.sin(a) * d,
        w * (0.018 + 0.02 * hash01(k, 15)),
        atlasArgb(ice, 0.1 + 0.16 * (1 - f)),
      );
    }
    // Crystals in it catching the light: fine, firm grains, a few.
    for (var g = 0; g < 14; g++, k++) {
      final a = hash01(k, 16) * math.pi / 2;
      final d = math.pow(hash01(k, 17), 0.8).toDouble() * front(a) * 0.9;
      atlas.add(
        AtlasCell.bead,
        cx + sx * math.cos(a) * d,
        cy + sy * math.sin(a) * d,
        w * (0.008 + 0.008 * hash01(k, 18)),
        atlasArgb(const Color(0xFFFFFFFF), 0.5 + 0.3 * hash01(k, 19)),
      );
    }
    // Where the cold light catches it: a few soft glints, only above.
    if (cy == 0) {
      for (var g = 0; g < 3; g++, k++) {
        final a = hash01(k, 19) * math.pi / 2;
        final d = r * (0.2 + 0.4 * hash01(k, 20));
        atlas.add(
          AtlasCell.dot,
          cx + sx * math.cos(a) * d,
          cy + sy * math.sin(a) * d,
          w * 0.06,
          atlasArgb(const Color(0xFFFFFFFF), 0.5),
        );
      }
    }
  }
  atlas.draw(c);
  softPool(c, w / 2, h * 0.9, w * 0.5, w * 0.1, const Color(0xFF8FC4FF), 0.3);
}

// ── Garnet ──────────────────────────────────────────────────────────────────

void _garnet(Canvas c, double w, double h) {
  final arch = _arch(w, h, inset: 0.1);
  paintFill(
    c,
    arch,
    ui.Gradient.radial(
      Offset(w / 2, h * 0.95),
      h * 0.95,
      const [Color(0xFF62101C), Color(0xFF2C070D), Color(0xFF13030A)],
      const [0.0, 0.5, 1.0],
    ),
  );
  // Broad facets of the glass, each catching the light from below a
  // little differently.
  c.save();
  c.clipPath(arch);
  for (final (pts, a) in [
    (
      [
        Offset(0, h),
        Offset(w * 0.5, h * 0.62),
        Offset(w * 0.32, h * 0.2),
        Offset(0, h * 0.35),
      ],
      0.06,
    ),
    (
      [
        Offset(w * 0.5, h * 0.62),
        Offset(w, h),
        Offset(w, h * 0.3),
        Offset(w * 0.68, h * 0.15),
      ],
      0.04,
    ),
    (
      [
        Offset(w * 0.32, h * 0.2),
        Offset(w * 0.5, h * 0.62),
        Offset(w * 0.68, h * 0.15),
        Offset(w * 0.5, 0),
      ],
      0.08,
    ),
  ]) {
    _solid(c, polyPath(pts), Color.fromRGBO(255, 110, 120, a));
  }
  // The light from below, rising through the glass.
  softPool(c, w / 2, h * 0.86, w * 0.5, h * 0.4, const Color(0xFFFF3A50), 0.16);
  c.restore();
  _archInset(c, w, h, 0.1, const Color(0x99000000));
  softPool(
    c,
    w / 2,
    h * 0.92,
    w * 0.55,
    w * 0.12,
    const Color(0xFFFF4A5A),
    0.4,
  );
}

// ── Brass ───────────────────────────────────────────────────────────────────

final StoneLight _rivet = StoneLight(const Color(0xFFCDB07A));

void _brass(Canvas c, double w, double h) {
  final plate = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.12, h * 0.07, w * 0.88, h * 0.86),
        Radius.circular(w * 0.06),
      ),
    );
  paintFill(
    c,
    plate,
    ui.Gradient.linear(
      Offset(w * 0.1, h * 0.05),
      Offset(w * 0.9, h * 0.9),
      const [Color(0xFF6E5C37), Color(0xFF3B3121), Color(0xFF1D1810)],
      const [0.0, 0.45, 1.0],
    ),
  );
  // Brushed: fine bands of light across the metal, faint.
  c.save();
  c.clipPath(plate);
  for (var i = 0; i < 34; i++) {
    final y = h * (0.07 + 0.0235 * i);
    _solid(
      c,
      Path()..addRect(Rect.fromLTWH(0, y, w, h * 0.006)),
      Color.fromRGBO(242, 221, 166, 0.012 + 0.03 * hash01(i, 12)),
    );
  }
  c.restore();
  // Four rivets, as small lit domes.
  for (final (x, y) in const [
    (0.2, 0.135),
    (0.8, 0.135),
    (0.2, 0.79),
    (0.8, 0.79),
  ]) {
    paintOrb(c, _rivet, Offset(w * x, h * y), w * 0.022);
  }
  // The lamp over it.
  softPool(c, w / 2, h * 0.02, w * 0.5, h * 0.3, const Color(0xFFFFE2A0), 0.42);
  softPool(c, w / 2, h * 0.9, w * 0.5, w * 0.1, const Color(0xFFCDB07A), 0.34);
}
