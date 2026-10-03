// lib/widgets/nav_emblems.dart
//
// The dock's other four icons, drawn in the Fusion emblem's language
// (fusion_emblem.dart): one object of dark glass, stone or metal, lit from
// the upper left, made partly of grains, floating over a pool of its own
// light. They replaced illustrated stickers — mascots holding a folder and a
// dollar coin, a cottage — that belonged to another game.
//
//   inventory  a stoppered reagent jar, three strata of grains settled in it
//   creatures  a specimen under a bell jar: an ammonite coiled in grains
//   home       the A of the title, in the title's own grains
//   shop       a hoard of gold grains with a coin stood in it
//
// Each moves only while its tab is open; closed, it is drawn once at a
// resting frame. Filled shapes, gradients and point batches — nothing
// stroked, no blur.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:alchemons/widgets/particle_title.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum NavEmblemKind { inventory, creatures, home, shop }

class NavEmblem extends StatefulWidget {
  const NavEmblem({
    super.key,
    required this.kind,
    required this.size,
    this.animate = false,
  });

  final NavEmblemKind kind;
  final double size;

  /// Whether it moves — true only for the open tab.
  final bool animate;

  @override
  State<NavEmblem> createState() => _NavEmblemState();
}

class _NavEmblemState extends State<NavEmblem> with GlyphClockLease {
  bool _visible = true;
  TitleSamples? _title;

  @override
  bool get wantsClock => widget.animate && _visible;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
    if (widget.kind == NavEmblemKind.home) {
      TitleSamples.of(kTitleAsset).then((s) {
        if (mounted) setState(() => _title = s);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      syncGlyphClock();
    }
  }

  @override
  void didUpdateWidget(covariant NavEmblem oldWidget) {
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
    final clock = glyphClock;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        willChange: clock != null,
        painter: NavEmblemPainter(
          kind: widget.kind,
          clock: clock,
          title: _title,
        ),
      ),
    );
  }
}

class NavEmblemPainter extends CustomPainter {
  NavEmblemPainter({required this.kind, this.clock, this.time, this.title})
    : super(repaint: clock);

  final NavEmblemKind kind;

  /// Null leaves the painter at its resting frame.
  final ValueListenable<double>? clock;

  /// A fixed time, for a still frame (tests).
  final double? time;

  /// The title's grains, for the home emblem; until they are read it draws
  /// only its light.
  final TitleSamples? title;

  /// The frame a closed tab is drawn at.
  static const double restTime = 1.1;

  static const Color _ink = Color(0xFF0B0911);
  static const Color _obsidian = Color(0xFF120E0A);
  static const Color _teal = Color(0xFF5FD4C8);
  static const Color _amber = Color(0xFFF0B254);
  static const Color _violet = Color(0xFFC48CFF);
  static const Color _gold = Color(0xFFFFD358);
  static const Color _green = Color(0xFF8FD9A8);

  static final GrainBatch _b = GrainBatch(14);
  static final Paint _p = Paint();

  static double _h(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final t = time ?? clock?.value ?? restTime;
    _p
      ..shader = null
      ..color = const Color(0xFF000000);
    final r = s * 0.5;
    final bob = math.sin(t * 1.6);
    final c = size.center(Offset.zero) + Offset(0, -r * 0.06 + bob * r * 0.04);
    switch (kind) {
      case NavEmblemKind.inventory:
        _pool(canvas, size, r, _teal, bob);
        _jar(canvas, c, r, t);
      case NavEmblemKind.creatures:
        _pool(canvas, size, r, _green, bob);
        _bellJar(canvas, c, r, t);
      case NavEmblemKind.home:
        _pool(canvas, size, r, _amber, bob);
        _monogram(canvas, c, r, t);
      case NavEmblemKind.shop:
        _pool(canvas, size, r, _gold, bob);
        _hoard(canvas, c, r, t);
    }
  }

  /// The light it floats over: wider and fainter as it rises.
  void _pool(Canvas canvas, Size size, double r, Color col, double bob) {
    final rise = (bob + 1) / 2;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + r * 0.84);
    canvas.scale(1, 0.26);
    final pool = r * (0.62 - 0.1 * rise);
    canvas.drawCircle(
      Offset.zero,
      pool,
      _p
        ..shader = ui.Gradient.radial(Offset.zero, pool, [
          col.withValues(alpha: 0.42 * (1 - 0.3 * rise)),
          col.withValues(alpha: 0),
        ]),
    );
    _p.shader = null;
    canvas.restore();
  }

  /// A small bright reflection, tipped.
  void _catchlight(Canvas canvas, Offset at, double w, double a) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(-0.7);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.4),
      Paint()..color = Colors.white.withValues(alpha: a),
    );
    canvas.restore();
  }

  // ── Inventory: a reagent jar ────────────────────────────────────────────

  Path _jarBody(Offset c, double r, double inset) {
    final hw = r * 0.5 - inset;
    final top = c.dy - r * 0.2 + inset;
    final bottom = c.dy + r * 0.62 - inset;
    final neck = r * 0.25 - inset * 0.6;
    final shoulder = c.dy - r * 0.36 + inset;
    return Path()
      ..moveTo(c.dx - neck, shoulder)
      ..quadraticBezierTo(c.dx - hw, shoulder + r * 0.02, c.dx - hw, top)
      ..lineTo(c.dx - hw, bottom - r * 0.16)
      ..quadraticBezierTo(c.dx - hw, bottom, c.dx - hw + r * 0.16, bottom)
      ..lineTo(c.dx + hw - r * 0.16, bottom)
      ..quadraticBezierTo(c.dx + hw, bottom, c.dx + hw, bottom - r * 0.16)
      ..lineTo(c.dx + hw, top)
      ..quadraticBezierTo(c.dx + hw, shoulder + r * 0.02, c.dx + neck, shoulder)
      ..close();
  }

  void _jar(Canvas canvas, Offset c, double r, double t) {
    final body = _jarBody(c, r, 0);
    final bounds = body.getBounds();

    // The glass: dark, faintly teal, lit upper left.
    canvas.drawPath(
      body,
      _p
        ..shader = ui.Gradient.radial(
          bounds.topLeft + Offset(bounds.width * 0.3, bounds.height * 0.25),
          r * 1.3,
          [Color.lerp(_teal, _ink, 0.82)!, _obsidian],
        ),
    );
    _p.shader = null;

    // What it holds: three strata settled one on another, the top one
    // stirring a little while the tab is open.
    final inner = _jarBody(c, r, r * 0.07);
    final ib = inner.getBounds();
    canvas.save();
    canvas.clipPath(inner);
    final b = _b..clear();
    const strata = [_amber, _teal, _violet];
    final floor = ib.bottom;
    final fill = ib.height * 0.74;
    final bands = [0.0, 0.36, 0.68, 1.0];
    const n = 380;
    for (var i = 0; i < n; i++) {
      final u = _h(i, 1);
      final v = (i + 0.5) / n;
      final x = ib.left + u * ib.width;
      var y = floor - v * fill;
      final band = v < bands[1] ? 0 : (v < bands[2] ? 1 : 2);
      // A wavy surface on each stratum; the top one moves.
      final wave = math.sin(u * 7 + band * 1.9 + (band == 2 ? t * 0.9 : 0));
      y += wave * r * 0.025;
      // Darker toward the glass on either side.
      final edge = ((u - 0.5).abs() * 2);
      final depth = edge > 0.8 ? 0 : (edge > 0.3 ? 1 : 2);
      b.add(band * 3 + depth, x, y);
      if (band == 2 && v > 0.93 && (t * 0.5 + _h(i, 4) * 5) % 1.0 < 0.08) {
        b.add(9, x, y);
      }
    }
    // A few motes lifting off the top, only when it moves.
    if (clock != null || time != null) {
      for (var i = 0; i < 5; i++) {
        final ph = (t * 0.32 + _h(i, 7)) % 1.0;
        b.add(
          10,
          ib.left + (0.3 + 0.4 * _h(i, 8)) * ib.width,
          floor - fill - ph * ib.height * 0.22,
        );
      }
    }
    final d = math.max(0.9, r * 0.048);
    for (var band = 0; band < 3; band++) {
      final col = strata[band];
      b.draw(canvas, band * 3, d * 0.8, Color.lerp(col, _ink, 0.66)!);
      b.draw(canvas, band * 3 + 1, d, Color.lerp(col, _ink, 0.3)!);
      b.draw(canvas, band * 3 + 2, d * 1.1, col);
    }
    b.draw(canvas, 9, d * 1.5, const Color(0xFFFFF4E0));
    b.draw(canvas, 10, d * 0.9, _violet.withValues(alpha: 0.7));
    canvas.restore();

    // The glass over it, and its edge catching light.
    canvas.drawPath(
      body,
      _p
        ..shader = ui.Gradient.linear(
          bounds.topLeft,
          bounds.bottomRight,
          [
            Colors.white.withValues(alpha: 0.24),
            Colors.white.withValues(alpha: 0.0),
            _teal.withValues(alpha: 0.18),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
    _p.shader = null;
    // A tall reflection down its left side.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          bounds.left + r * 0.1,
          bounds.top + r * 0.24,
          r * 0.07,
          bounds.height * 0.52,
        ),
        Radius.circular(r * 0.04),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.2),
    );

    // The lip, and the stopper: dark wood, its top lit.
    final lip = Rect.fromCenter(
      center: Offset(c.dx, c.dy - r * 0.39),
      width: r * 0.62,
      height: r * 0.1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lip, Radius.circular(r * 0.05)),
      _p
        ..shader = ui.Gradient.linear(lip.topCenter, lip.bottomCenter, [
          Color.lerp(_teal, Colors.white, 0.1)!.withValues(alpha: 0.55),
          Color.lerp(_teal, _ink, 0.8)!,
        ]),
    );
    final cork = Rect.fromLTRB(
      c.dx - r * 0.22,
      c.dy - r * 0.66,
      c.dx + r * 0.22,
      c.dy - r * 0.42,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        cork,
        topLeft: Radius.circular(r * 0.09),
        topRight: Radius.circular(r * 0.09),
        bottomLeft: Radius.circular(r * 0.03),
        bottomRight: Radius.circular(r * 0.03),
      ),
      _p
        ..shader = ui.Gradient.linear(
          cork.topLeft,
          cork.bottomRight,
          [
            const Color(0xFF8A5A34),
            const Color(0xFF3A2414),
            const Color(0xFF1A0F08),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
    _p.shader = null;
    _catchlight(
      canvas,
      Offset(bounds.left + r * 0.3, bounds.top + r * 0.2),
      r * 0.2,
      0.45,
    );
  }

  // ── Creatures: a specimen under glass ───────────────────────────────────

  void _bellJar(Canvas canvas, Offset c, double r, double t) {
    final baseY = c.dy + r * 0.56;
    final hw = r * 0.46;

    // The plinth: obsidian, its top lit.
    final plinthTop = Rect.fromCenter(
      center: Offset(c.dx, baseY),
      width: r * 1.12,
      height: r * 0.2,
    );
    final plinthSide = Rect.fromLTRB(
      plinthTop.left,
      baseY,
      plinthTop.right,
      baseY + r * 0.16,
    );
    canvas.drawRect(
      plinthSide,
      _p
        ..shader = ui.Gradient.linear(
          plinthSide.centerLeft,
          plinthSide.centerRight,
          [const Color(0xFF2A2420), _obsidian, const Color(0xFF060508)],
          const [0.0, 0.45, 1.0],
        ),
    );
    canvas.drawOval(
      plinthSide.shift(Offset(0, plinthSide.height)).topLeft &
          Size(plinthTop.width, plinthTop.height),
      _p
        ..shader = null
        ..color = const Color(0xFF060508),
    );
    canvas.drawOval(
      plinthTop,
      _p
        ..shader = ui.Gradient.linear(
          plinthTop.topLeft,
          plinthTop.bottomRight,
          [const Color(0xFF4A3F36), const Color(0xFF15110E)],
        ),
    );
    _p.shader = null;

    // Light gathered under the specimen.
    canvas.save();
    canvas.translate(c.dx, baseY);
    canvas.scale(1, 0.3);
    canvas.drawCircle(
      Offset.zero,
      r * 0.36,
      _p
        ..shader = ui.Gradient.radial(Offset.zero, r * 0.36, [
          _green.withValues(alpha: 0.55),
          _green.withValues(alpha: 0),
        ]),
    );
    _p.shader = null;
    canvas.restore();

    // The specimen: an ammonite coiled in grains, turning slowly in its
    // own plane while the tab is open.
    final b = _b..clear();
    final centre = Offset(c.dx, c.dy + r * 0.12);
    final spin = t * 0.35;
    const n = 420;
    for (var i = 0; i < n; i++) {
      final u = math.sqrt(i / n);
      // A logarithmic coil, widest at its mouth, with a gap between whorls.
      final a = u * 4.4 * math.pi + spin;
      final rad = r * 0.035 * math.exp(u * 2.1);
      final across = (_h(i, 3) - 0.5) * rad * 0.48;
      final px = centre.dx + math.cos(a) * (rad + across);
      final py = centre.dy + math.sin(a) * (rad + across) * 0.92;
      // Chambered: bright at each septum, darker between.
      final septum = (u * 18) % 1.0 < 0.14;
      final lit = math.cos(a + 2.4) > 0.2;
      b.add(septum ? 2 : (lit ? 1 : 0), px, py);
      if (u > 0.4 && (t * 0.6 + _h(i, 5) * 7) % 1.0 < 0.035) b.add(3, px, py);
    }
    final d = math.max(0.8, r * 0.046);
    b.draw(canvas, 0, d * 0.9, Color.lerp(_amber, _ink, 0.55)!);
    b.draw(canvas, 1, d, Color.lerp(_amber, _green, 0.35)!);
    b.draw(canvas, 2, d * 1.15, Color.lerp(_green, Colors.white, 0.3)!);
    b.draw(canvas, 3, d * 1.6, const Color(0xFFFFF4E0));

    // The dome: nearly clear glass, its edges catching the light.
    final top = baseY - r * 0.98;
    final dome = Path()
      ..moveTo(c.dx - hw, baseY - r * 0.02)
      ..lineTo(c.dx - hw, top + hw)
      ..arcToPoint(Offset(c.dx + hw, top + hw), radius: Radius.circular(hw))
      ..lineTo(c.dx + hw, baseY - r * 0.02)
      ..close();
    final db = dome.getBounds();
    canvas.drawPath(
      dome,
      _p
        ..shader = ui.Gradient.linear(
          db.centerLeft,
          db.centerRight,
          [
            Colors.white.withValues(alpha: 0.2),
            Colors.white.withValues(alpha: 0.02),
            Colors.white.withValues(alpha: 0.0),
            _green.withValues(alpha: 0.14),
          ],
          const [0.0, 0.22, 0.6, 1.0],
        ),
    );
    _p.shader = null;
    // Its rim, where the glass is thickest: a filled band, not a line.
    final rim = Path.combine(
      PathOperation.difference,
      dome,
      Path()
        ..moveTo(c.dx - hw + r * 0.05, baseY)
        ..lineTo(c.dx - hw + r * 0.05, top + hw)
        ..arcToPoint(
          Offset(c.dx + hw - r * 0.05, top + hw),
          radius: Radius.circular(hw - r * 0.05),
        )
        ..lineTo(c.dx + hw - r * 0.05, baseY)
        ..close(),
    );
    canvas.drawPath(
      rim,
      _p
        ..shader = ui.Gradient.linear(
          db.topLeft,
          db.bottomRight,
          [
            Colors.white.withValues(alpha: 0.42),
            Colors.white.withValues(alpha: 0.08),
            _green.withValues(alpha: 0.3),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
    _p.shader = null;
    // The knob on top.
    canvas.drawCircle(
      Offset(c.dx, top - r * 0.03),
      r * 0.075,
      _p
        ..shader = ui.Gradient.radial(
          Offset(c.dx - r * 0.03, top - r * 0.06),
          r * 0.1,
          [Colors.white.withValues(alpha: 0.75), const Color(0xFF3C4A44)],
        ),
    );
    _p.shader = null;
    _catchlight(canvas, Offset(c.dx - hw * 0.5, top + hw * 0.42), r * 0.2, 0.5);
  }

  // ── Home: the title's A ─────────────────────────────────────────────────

  /// The A's grains, fitted to a unit box once: (x, y, tone) triples.
  static Float32List? _a;
  static TitleSamples? _aFrom;

  static Float32List _letterA(TitleSamples s) {
    if (_a != null && identical(_aFrom, s)) return _a!;
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    final idx = <int>[];
    // The first letter, cut at the gap before the L (its own letter band
    // takes in the L's stem).
    final cut = 213 * TitleSamples.box.width / 1024;
    for (var i = 0; i < s.length; i++) {
      if (s.letter[i] != 0 || s.hx[i] > cut) continue;
      idx.add(i);
      minX = math.min(minX, s.hx[i]);
      maxX = math.max(maxX, s.hx[i]);
      minY = math.min(minY, s.hy[i]);
      maxY = math.max(maxY, s.hy[i]);
    }
    final span = math.max(maxX - minX, maxY - minY);
    final out = Float32List(idx.length * 3);
    for (var k = 0; k < idx.length; k++) {
      final i = idx[k];
      out[k * 3] = (s.hx[i] - (minX + maxX) / 2) / span;
      out[k * 3 + 1] = (s.hy[i] - (minY + maxY) / 2) / span;
      out[k * 3 + 2] = s.tone[i].toDouble();
    }
    _aFrom = s;
    return _a = out;
  }

  void _monogram(Canvas canvas, Offset c, double r, double t) {
    // A warm light behind it, so it stands out of the dock.
    canvas.drawCircle(
      c,
      r * 0.62,
      _p
        ..shader = ui.Gradient.radial(c, r * 0.62, [
          _amber.withValues(alpha: 0.22),
          _amber.withValues(alpha: 0),
        ]),
    );
    _p.shader = null;
    final s = title;
    if (s == null) return;
    final a = _letterA(s);
    final b = _b..clear();
    final scale = r * 1.62;
    final grains = a.length ~/ 3;
    for (var k = 0; k < grains; k++) {
      final x = c.dx + a[k * 3] * scale;
      final y = c.dy + a[k * 3 + 1] * scale;
      final tone = a[k * 3 + 2].toInt().clamp(0, TitleSamples.toneCount - 1);
      b.add(tone, x, y);
      // A slow glint walking through the letter.
      if ((t * 0.4 + _h(k, 9) * 9) % 1.0 < 0.012) b.add(12, x, y);
    }
    final d = math.max(0.8, r * 0.05);
    for (var tone = 0; tone < TitleSamples.toneCount; tone++) {
      b.draw(canvas, tone, d, s.tones[tone]);
    }
    b.draw(canvas, 12, d * 1.7, const Color(0xFFFFF4E0));
  }

  // ── Shop: a hoard ───────────────────────────────────────────────────────

  void _hoard(Canvas canvas, Offset c, double r, double t) {
    final base = c.dy + r * 0.58;
    final hw = r * 0.66;
    final hh = r * 0.4;

    // The coin stood in it, behind the front of the heap.
    _coin(canvas, Offset(c.dx + r * 0.08, c.dy - r * 0.08), r * 0.36);

    final b = _b..clear();
    const n = 460;
    for (var i = 0; i < n; i++) {
      final u = _h(i, 1) * 2 - 1;
      final top = base - hh * math.pow(1 - u * u, 0.8).toDouble();
      // Filled to the surface; a little denser where the light falls.
      final v = math.pow(_h(i, 2), 0.8).toDouble();
      final x = c.dx + u * hw;
      final y = top + (base - top) * (1 - v);
      final silver = _h(i, 3) < 0.13;
      final lit = u < 0.2 && v > 0.62;
      final depth = v < 0.5 ? 0 : (lit ? 2 : 1);
      b.add((silver ? 3 : 0) + depth, x, y);
      if (v > 0.85 && (t * 0.5 + _h(i, 4) * 6) % 1.0 < 0.04) b.add(6, x, y);
    }
    final d = math.max(0.9, r * 0.05);
    b.draw(canvas, 0, d * 0.85, const Color(0xFF6B3A04));
    b.draw(canvas, 1, d, const Color(0xFFC8841C));
    b.draw(canvas, 2, d * 1.1, _gold);
    b.draw(canvas, 3, d * 0.85, const Color(0xFF3D454F));
    b.draw(canvas, 4, d, const Color(0xFF8A95A3));
    b.draw(canvas, 5, d * 1.1, const Color(0xFFD6DCE5));
    b.draw(canvas, 6, d * 1.6, const Color(0xFFFFF4E0));

    // A silver coin leaning on the gold one, half sunk in the heap.
    canvas.save();
    canvas.translate(c.dx - r * 0.28, base - r * 0.3);
    canvas.rotate(-0.42);
    canvas.scale(0.78, 1);
    _coin(canvas, Offset.zero, r * 0.22, silver: true);
    canvas.restore();
  }

  /// The game's coin, as gold_coin.svg / silver_coin.svg draw it: a rim, a
  /// face lit upper left, its sigil, a shine.
  void _coin(
    Canvas canvas,
    Offset at,
    double rad, {
    bool silver = false,
    bool sigil = true,
  }) {
    final rim = silver
        ? const [Color(0xFFEEF1F5), Color(0xFF6F7986), Color(0xFF2F353D)]
        : const [Color(0xFFFFE38A), Color(0xFF9F6611), Color(0xFF4C2A02)];
    final face = silver
        ? const [
            Color(0xFFFBFCFE),
            Color(0xFFD6DCE5),
            Color(0xFF8A95A3),
            Color(0xFF3D454F),
          ]
        : const [
            Color(0xFFFFF1B0),
            Color(0xFFFFD358),
            Color(0xFFC8841C),
            Color(0xFF6B3A04),
          ];
    final ink = silver ? const Color(0xFF1F242B) : const Color(0xFF3A2002);
    final box = Rect.fromCircle(center: at, radius: rad);
    canvas.drawCircle(
      at,
      rad,
      _p
        ..shader = ui.Gradient.linear(
          box.topCenter,
          box.bottomCenter,
          rim,
          const [0.0, 0.55, 1.0],
        ),
    );
    _p
      ..shader = null
      ..color = ink.withValues(alpha: 0.55);
    canvas.drawCircle(at, rad * 0.917, _p);
    final faceR = rad * 0.867;
    canvas.drawCircle(
      at,
      faceR,
      _p
        ..shader = ui.Gradient.radial(
          at + Offset(-faceR * 0.3, -faceR * 0.44),
          faceR * 1.9,
          face,
          const [0.0, 0.35, 0.75, 1.0],
        ),
    );
    _p.shader = null;
    if (sigil && silver) {
      // The alchemical moon: a crescent, filled.
      final k = rad / 30;
      _p.color = ink;
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addOval(
            Rect.fromCircle(center: at + Offset(-1.5 * k, 0), radius: 10.5 * k),
          ),
          Path()..addOval(
            Rect.fromCircle(center: at + Offset(2.5 * k, 0), radius: 8 * k),
          ),
        ),
        _p,
      );
    } else if (sigil) {
      // The alchemical sun: a ring and its dot, filled.
      final ring = Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: at, radius: rad * 0.32))
        ..addOval(Rect.fromCircle(center: at, radius: rad * 0.245));
      _p.color = ink;
      canvas.drawPath(ring, _p);
      canvas.drawCircle(at, rad * 0.075, _p);
    }
    canvas.drawCircle(
      at,
      faceR,
      _p
        ..shader = ui.Gradient.radial(
          at + Offset(-faceR * 0.36, -faceR * 0.56),
          faceR * 0.7,
          [
            Colors.white.withValues(alpha: 0.8),
            Colors.white.withValues(alpha: 0),
          ],
        ),
    );
    _p.shader = null;
  }

  @override
  bool shouldRepaint(covariant NavEmblemPainter old) =>
      old.kind != kind ||
      old.clock != clock ||
      old.time != time ||
      !identical(old.title, title);
}
