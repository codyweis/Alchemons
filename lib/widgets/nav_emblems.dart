// lib/widgets/nav_emblems.dart
//
// The dock's drawn icons beside the Fusion emblem (fusion_emblem.dart): one
// solid object, lit from the upper left, floating over a pool of its own
// light. Bold silhouettes first — at 55 dp a dense grain drawing turned to
// mush, so grains are only an accent here. Creatures, home and shop are the
// player's own art (PNGs in nav_bar.dart).
//
//   inventory  a brass-strapped coffer, its lid lifted on a seam of light
//
// Each moves only while its tab is open; closed, it is drawn once at a
// resting frame. Filled shapes and gradients — nothing stroked, no blur.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum NavEmblemKind { inventory }

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

  @override
  bool get wantsClock => widget.animate && _visible;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
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
        painter: NavEmblemPainter(kind: widget.kind, clock: clock),
      ),
    );
  }
}

class NavEmblemPainter extends CustomPainter {
  NavEmblemPainter({required this.kind, this.clock, this.time})
    : super(repaint: clock);

  final NavEmblemKind kind;

  /// Null leaves the painter at its resting frame.
  final ValueListenable<double>? clock;

  /// A fixed time, for a still frame (tests).
  final double? time;

  /// The frame a closed tab is drawn at.
  static const double restTime = 1.1;

  static const Color _teal = Color(0xFF5FD4C8);
  static const Color _amber = Color(0xFFF0B254);
  static const Color _violet = Color(0xFFC48CFF);
  static const Color _flare = Color(0xFFFFF4E0);

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
    final c = size.center(Offset.zero) + Offset(0, -r * 0.04 + bob * r * 0.03);
    switch (kind) {
      case NavEmblemKind.inventory:
        _pool(canvas, size, r, _teal, bob);
        _coffer(canvas, c, r * 0.98, t);
    }
  }

  /// The light it floats over: wider and fainter as it rises.
  void _pool(Canvas canvas, Size size, double r, Color col, double bob) {
    final rise = (bob + 1) / 2;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + r * 0.86);
    canvas.scale(1, 0.24);
    final pool = r * (0.7 - 0.1 * rise);
    canvas.drawCircle(
      Offset.zero,
      pool,
      _p
        ..shader = ui.Gradient.radial(Offset.zero, pool, [
          col.withValues(alpha: 0.4 * (1 - 0.3 * rise)),
          col.withValues(alpha: 0),
        ]),
    );
    _p.shader = null;
    canvas.restore();
  }

  /// [inner] minus a copy of itself shifted by [by]: the rim on the side
  /// facing away from [by]. Used for a bevel's lit and shaded edges.
  static Path _rim(Path inner, Offset by) =>
      Path.combine(PathOperation.difference, inner, inner.shift(by));

  // ── Inventory: a coffer ─────────────────────────────────────────────────

  void _coffer(Canvas canvas, Offset c, double r, double t) {
    Offset q(double x, double y) => Offset(c.dx + x * r, c.dy + y * r);
    final breathe = 0.5 + 0.5 * math.sin(t * 1.7);
    final gap = 0.1 + 0.05 * breathe;
    const hw = 0.8;
    const top = -0.02; // the body's top edge
    const bottom = 0.7;

    // The body: dark wood, lit from the left.
    final body = RRect.fromRectAndCorners(
      Rect.fromPoints(q(-hw, top), q(hw, bottom)),
      topLeft: Radius.circular(r * 0.03),
      topRight: Radius.circular(r * 0.03),
      bottomLeft: Radius.circular(r * 0.1),
      bottomRight: Radius.circular(r * 0.1),
    );
    final bb = body.outerRect;
    canvas.drawRRect(
      body,
      _p
        ..shader = ui.Gradient.linear(
          bb.centerLeft,
          bb.centerRight,
          const [Color(0xFF5A402B), Color(0xFF2C1E14), Color(0xFF110B07)],
          const [0.0, 0.42, 1.0],
        ),
    );
    // Light from the seam spilling down its front.
    canvas.drawRect(
      Rect.fromPoints(q(-hw, top), q(hw, top + 0.3)),
      _p
        ..shader = ui.Gradient.linear(q(0, top), q(0, top + 0.3), [
          _amber.withValues(alpha: 0.32 + 0.14 * breathe),
          _amber.withValues(alpha: 0),
        ]),
    );
    _p.shader = null;
    // One plank seam.
    canvas.drawRect(
      Rect.fromPoints(q(-hw, 0.33), q(hw, 0.355)),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    // The seam itself: the light inside, between body and lid.
    final seam = Rect.fromPoints(q(-hw + 0.06, -gap - 0.02), q(hw - 0.06, top));
    canvas.drawRect(
      seam,
      _p
        ..shader = ui.Gradient.linear(
          seam.centerLeft,
          seam.centerRight,
          [
            const Color(0xFFF0B254),
            Color.lerp(_flare, _amber, 0.2 - 0.2 * breathe)!,
            const Color(0xFFF0B254),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
    _p.shader = null;

    // The lid: a shallow barrel, raised on the seam.
    final lidBase = -gap + top;
    final lid = Path()
      ..moveTo(q(-hw, lidBase).dx, q(-hw, lidBase).dy)
      ..lineTo(q(-hw, lidBase - 0.14).dx, q(-hw, lidBase - 0.14).dy)
      ..cubicTo(
        q(-hw, lidBase - 0.62).dx,
        q(-hw, lidBase - 0.62).dy,
        q(hw, lidBase - 0.62).dx,
        q(hw, lidBase - 0.62).dy,
        q(hw, lidBase - 0.14).dx,
        q(hw, lidBase - 0.14).dy,
      )
      ..lineTo(q(hw, lidBase).dx, q(hw, lidBase).dy)
      ..close();
    final lb = lid.getBounds();
    canvas.drawPath(
      lid,
      _p
        ..shader = ui.Gradient.linear(
          lb.topLeft,
          lb.bottomRight,
          const [Color(0xFF6A4D35), Color(0xFF34241A), Color(0xFF150E09)],
          const [0.0, 0.5, 1.0],
        ),
    );
    _p.shader = null;
    // Its crown catching the light.
    canvas.drawPath(
      _rim(lid, Offset(r * 0.03, r * 0.06)),
      Paint()..color = const Color(0xFFFFE2B0).withValues(alpha: 0.28),
    );

    // Brass straps over lid and body, and a band along the foot.
    const brass = [Color(0xFFFFE08A), Color(0xFFC8841C), Color(0xFF5E3404)];
    void strap(Rect rect, {Path? clip}) {
      if (clip != null) {
        canvas.save();
        canvas.clipPath(clip);
      }
      canvas.drawRect(
        rect,
        _p
          ..shader = ui.Gradient.linear(
            rect.centerLeft,
            rect.centerRight,
            brass,
            const [0.0, 0.45, 1.0],
          ),
      );
      _p.shader = null;
      if (clip != null) canvas.restore();
    }

    for (final x in const [-0.5, 0.34]) {
      strap(
        Rect.fromPoints(q(x, lidBase - 0.7), q(x + 0.16, lidBase)),
        clip: lid,
      );
      strap(Rect.fromPoints(q(x, top), q(x + 0.16, bottom - 0.02)));
    }
    final foot = Rect.fromPoints(q(-hw, bottom - 0.12), q(hw, bottom));
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(
      foot,
      _p
        ..shader = ui.Gradient.linear(foot.topCenter, foot.bottomCenter, const [
          Color(0xFFD9A040),
          Color(0xFF4C2A02),
        ]),
    );
    _p.shader = null;
    canvas.restore();

    // The lock plate, its keyhole dark.
    final plate = RRect.fromRectAndRadius(
      Rect.fromPoints(q(-0.12, top + 0.04), q(0.12, top + 0.3)),
      Radius.circular(r * 0.05),
    );
    canvas.drawRRect(
      plate,
      _p
        ..shader = ui.Gradient.linear(
          plate.outerRect.topLeft,
          plate.outerRect.bottomRight,
          brass,
          const [0.0, 0.5, 1.0],
        ),
    );
    _p.shader = null;
    final ink = Paint()..color = const Color(0xFF1A0F05);
    canvas.drawCircle(q(0, top + 0.14), r * 0.04, ink);
    canvas.drawRect(
      Rect.fromPoints(q(-0.018, top + 0.15), q(0.018, top + 0.24)),
      ink,
    );

    // The light leaking out at both ends of the seam, and what it holds
    // drifting out with it.
    final seamY = top - gap / 2;
    for (final side in const [-1.0, 1.0]) {
      final end = q(side * (hw - 0.04), seamY);
      canvas.drawCircle(
        end,
        r * 0.3,
        _p
          ..shader = ui.Gradient.radial(end, r * 0.3, [
            _amber.withValues(alpha: 0.5 + 0.2 * breathe),
            _amber.withValues(alpha: 0),
          ]),
      );
    }
    _p.shader = null;
    const tones = [_amber, _teal, _violet];
    for (var i = 0; i < 10; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final ph = (t * 0.32 + _h(i, 1)) % 1.0;
      final at = q(
        side * (hw - 0.06 + ph * (0.12 + 0.12 * _h(i, 2))),
        seamY - ph * (0.3 + 0.35 * _h(i, 3)) + math.sin(ph * 5 + i) * 0.03,
      );
      canvas.drawCircle(
        at,
        r * (0.026 + 0.022 * _h(i, 4)) * (1 - ph * 0.4),
        Paint()
          ..color = tones[i % 3].withValues(
            alpha: math.sin(ph * math.pi) * (0.6 + 0.4 * _h(i, 5)),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant NavEmblemPainter old) =>
      old.kind != kind || old.clock != clock || old.time != time;
}
