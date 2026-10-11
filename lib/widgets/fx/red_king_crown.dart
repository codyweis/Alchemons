// lib/widgets/fx/red_king_crown.dart
//
// The Crown of the Red King (the Athanor, the Red Work's capstone): a
// crown of dark gold set with garnets round a cap of garnet velvet. It is
// worn on the party hat's fits (FamilyCostume.crown), so where a hat sits
// on any fitted species, the crown sits; it is drawn at 0.8 of the hat.
//
// Its points are fleurons of uneven height, the front one tallest, lit
// from the upper left; gold grains glitter along the band now and then.
// Everything but the color is fixed, so the paths and the gold's shaders
// are made once; a frame is a score of fills and two grain passes. No
// outline strokes, no blur.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/obsidian_kit.dart'
    show StoneLight, hash01, paintDisc;
import 'package:alchemons/widgets/fx/celebration_particles.dart';
import 'package:flutter/painting.dart';

abstract final class RedKingCrown {
  /// Garnet: the gems' and the velvet's color when none is picked.
  static const Color defaultColor = Color(0xFF9A1C2E);

  // The crown's own space: 100 across is the hat's brim, the band's foot
  // at the origin, up is −y.
  static const double _rx = 43, _ry = 9.5, _band = 22;

  static final Paint _paint = Paint()..isAntiAlias = true;
  static final CelebrationParticles _grains = CelebrationParticles();

  /// Per color: the gems' light, and the velvet's shading. Bounded, like
  /// the hat's: a screen of crowns is a handful of colors.
  static final Map<int, StoneLight> _gems = {};
  static final Map<int, ui.Shader> _velvets = {};

  /// Gold, as metal: dark in the fold, lit at the left shoulder.
  static final ui.Shader _goldAcross = ui.Gradient.linear(
    const Offset(-_rx, 0),
    const Offset(_rx, 0),
    const [
      Color(0xFFE8C877),
      Color(0xFFB8862E),
      Color(0xFF6E4A12),
      Color(0xFF3A260A),
      Color(0xFF7A5418),
    ],
    const [0.0, 0.22, 0.55, 0.85, 1.0],
  );

  static final ui.Shader _goldUp = ui.Gradient.linear(
    Offset.zero,
    const Offset(0, -60),
    const [Color(0xFF6E4A12), Color(0xFFC9963A), Color(0xFFFFE6A8)],
    const [0.0, 0.55, 1.0],
  );

  /// The points round the rim: (angle on the rim, height, width). Near
  /// ones have sin(angle) > 0.
  static const List<(double, double, double)> _points = [
    (math.pi * 0.5, 46, 16),
    (math.pi * 0.5 + 0.85, 34, 14),
    (math.pi * 0.5 - 0.9, 36, 14),
    (math.pi * 0.5 + 1.75, 27, 12),
    (math.pi * 0.5 - 1.7, 28, 12),
    (-math.pi * 0.5 + 0.75, 24, 10),
    (-math.pi * 0.5 - 0.8, 23, 10),
    (-math.pi * 0.5, 26, 10),
  ];

  static Offset _rim(double a) =>
      Offset(math.cos(a) * (_rx + 1), -_band + math.sin(a) * _ry);

  /// A point, placed: its spike of cast metal (its sides drawn in, so it
  /// rises to a fine point where its garnet sits), lit by its own gradient;
  /// its garnet's place and size; and whether it is behind the cap.
  static final List<(Path, ui.Shader, Offset, double, bool)> _spikes = [
    for (final (a, h0, w) in _points)
      () {
        final far = math.sin(a) < 0;
        final h = far ? h0 * 0.92 : h0;
        final light = far ? 0.55 : 1.0;
        final foot = _rim(a);
        final path = Path()
          ..moveTo(foot.dx - w / 2, foot.dy)
          ..quadraticBezierTo(
            foot.dx - w * 0.08,
            foot.dy - h * 0.45,
            foot.dx,
            foot.dy - h,
          )
          ..quadraticBezierTo(
            foot.dx + w * 0.08,
            foot.dy - h * 0.45,
            foot.dx + w / 2,
            foot.dy,
          )
          ..close();
        final shader = ui.Gradient.linear(
          foot + Offset(-w, 0),
          foot + Offset(w, -h),
          [
            Color.lerp(
              const Color(0xFF3A260A),
              const Color(0xFFE8C877),
              0.85 * light,
            )!,
            Color.lerp(
              const Color(0xFF241806),
              const Color(0xFFB8862E),
              light,
            )!,
            const Color(0xFF3A260A),
          ],
          const [0.0, 0.45, 1.0],
        );
        final tip = foot + Offset(0, -h0 * (far ? 0.9 : 0.97));
        final gem = far ? 2.2 + h0 * 0.05 : 2.6 + h0 * 0.06;
        return (path, shader, tip, gem, far);
      }(),
  ];

  /// The far points as one shape, in one dim gold lit from the left: they
  /// are mostly hidden by the cap, and one fill keeps a frame's draws few.
  static final Path _farSpikes = () {
    final p = Path();
    for (final (path, _, _, _, far) in _spikes) {
      if (far) p.addPath(path, Offset.zero);
    }
    return p;
  }();

  static final ui.Shader _farGold = ui.Gradient.linear(
    const Offset(-_rx, 0),
    const Offset(_rx, -30),
    [
      Color.lerp(const Color(0xFF3A260A), const Color(0xFFE8C877), 0.47)!,
      Color.lerp(const Color(0xFF241806), const Color(0xFFB8862E), 0.55)!,
      const Color(0xFF3A260A),
    ],
    const [0.0, 0.45, 1.0],
  );

  /// The velvet cap: a low dome inside the band.
  static final Path _cap = Path()
    ..moveTo(-_rx + 2, -_band + 2)
    ..cubicTo(-_rx + 4, -_band - 30, _rx - 4, -_band - 30, _rx - 2, -_band + 2)
    ..close();

  /// The back of the band, seen inside over the cap's foot.
  static final Path _back = Path()
    ..addArc(
      Rect.fromCenter(
        center: const Offset(0, -_band),
        width: _rx * 2,
        height: _ry * 2,
      ),
      math.pi,
      math.pi,
    )
    ..lineTo(_rx - 3, -_band + 4)
    ..arcTo(
      Rect.fromCenter(
        center: const Offset(0, -_band + 4),
        width: _rx * 2 - 6,
        height: _ry * 2 - 4,
      ),
      0,
      -math.pi,
      false,
    )
    ..close();

  /// The near band: a strip between two half-ellipses.
  static final Path _bandPath = Path()
    ..moveTo(-_rx, 0)
    ..arcTo(
      Rect.fromCenter(center: Offset.zero, width: _rx * 2, height: _ry * 2),
      math.pi,
      -math.pi,
      false,
    )
    ..lineTo(_rx + 1, -_band)
    ..arcTo(
      Rect.fromCenter(
        center: const Offset(0, -_band),
        width: _rx * 2 + 2,
        height: _ry * 2,
      ),
      0,
      math.pi,
      false,
    )
    ..close();

  /// Its lit upper lip and its shadowed foot.
  static final Path _lip = _nearArc(-_band, _rx + 1, _ry, 3.4);
  static final Path _foot = _nearArc(0, _rx, _ry, -3.0);

  /// A sliver along the near half of the ellipse round (0, [y]): [w] thick
  /// at its middle, down into the band if [w] > 0, up out of it if not,
  /// tapering to nothing at both ends.
  static Path _nearArc(double y, double rx, double ry, double w) {
    const n = 16;
    final p = Path();
    for (var i = 0; i <= n; i++) {
      final a = math.pi * i / n;
      final q = Offset(math.cos(a) * rx, y + math.sin(a) * ry);
      i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
    }
    for (var i = n; i >= 0; i--) {
      final a = math.pi * i / n;
      p.lineTo(
        math.cos(a) * rx,
        y + math.sin(a) * ry + w * math.sin(a),
      );
    }
    return p..close();
  }

  /// The garnets set in the band: the front one large, the side ones
  /// turned away and narrower. (angle, size)
  static const List<(double, double)> _set = [
    (math.pi * 0.5, 1.0),
    (math.pi * 0.5 + 0.9, 0.62),
    (math.pi * 0.5 - 0.9, 0.66),
  ];

  static StoneLight _gem(Color color) {
    final key = color.toARGB32();
    final kept = _gems[key];
    if (kept != null) return kept;
    if (_gems.length >= 32) _gems.clear();
    // The gems' light a little lighter than the velvet, so they shine.
    return _gems[key] = StoneLight(
      Color.lerp(color, const Color(0xFFFF6A7A), 0.35)!,
      warm: 0.05,
    );
  }

  static ui.Shader _velvet(Color color) {
    final key = color.toARGB32();
    final kept = _velvets[key];
    if (kept != null) return kept;
    if (_velvets.length >= 32) _velvets.clear();
    return _velvets[key] = ui.Gradient.linear(
      const Offset(-_rx, -_band - 22),
      const Offset(_rx * 0.6, -_band + 4),
      [
        Color.lerp(color, const Color(0xFFFFFFFF), 0.18)!,
        color,
        Color.lerp(color, const Color(0xFF000000), 0.7)!,
      ],
      const [0.0, 0.4, 1.0],
    );
  }

  /// Paints the crown over the head at [base] (the party hat's fit), the
  /// hat [width] wide, tilted with the head by [tilt]. [time] in seconds.
  static void paint(
    Canvas canvas,
    Offset base,
    double width,
    double time, {
    double opacity = 1,
    double tilt = 0,
    Color color = defaultColor,
  }) {
    if (width <= 0 || opacity <= 0) return;
    final gem = _gem(color);
    final gemColor = gem.essence;
    final o = opacity.clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(base.dx, base.dy);
    // 100 hat units across the fit's width.
    canvas.scale(width / 100);
    canvas.rotate(-0.10 + tilt);

    void fill(Path path, ui.Shader? shader, Color color) {
      _paint
        ..shader = shader
        ..color = color;
      canvas.drawPath(path, _paint);
    }

    // The garnets on the points' tips, as grains: a gem and its glint.
    void gems(bool far, double a) {
      for (final (_, _, tip, size, behind) in _spikes) {
        if (behind != far) continue;
        _grains.add(tip, size * 0.62, gemColor, a);
        _grains.add(
          tip + Offset(-size * 0.3, -size * 0.35),
          size * 0.18,
          const Color(0xFFFFF0F0),
          0.75 * a,
        );
      }
    }

    // The far points, behind the cap.
    fill(_farSpikes, _farGold, Color.fromRGBO(0, 0, 0, o));
    _grains.clear();
    gems(true, 0.75 * o);
    _grains.draw(canvas);
    fill(_cap, _velvet(color), Color.fromRGBO(0, 0, 0, o));
    fill(_back, _goldUp, Color.fromRGBO(0, 0, 0, 0.75 * o));
    fill(_bandPath, _goldAcross, Color.fromRGBO(0, 0, 0, o));
    fill(_lip, null, Color.fromRGBO(255, 236, 180, 0.5 * o));
    fill(_foot, null, Color.fromRGBO(20, 12, 2, 0.55 * o));
    // The garnets in the band, glass with light in it (their glints go
    // with the grains below).
    for (final (a, s) in _set) {
      canvas.save();
      canvas.translate(
        math.cos(a) * _rx * 0.98,
        -_band / 2 + math.sin(a) * _ry,
      );
      canvas.scale(math.sin(a).abs().clamp(0.4, 1.0), 1);
      paintDisc(canvas, gem.orb, Offset.zero, 7.5 * s, o);
      canvas.restore();
    }
    // The near points, over the band.
    for (final (path, shader, _, _, far) in _spikes) {
      if (!far) fill(path, shader, Color.fromRGBO(0, 0, 0, o));
    }
    // Their garnets, then gold grains glinting along the band, a few at a
    // time.
    _grains.clear();
    gems(false, o);
    for (final (a, s) in _set) {
      final squash = math.sin(a).abs().clamp(0.4, 1.0);
      _grains.add(
        Offset(
          math.cos(a) * _rx * 0.98 - 7.5 * s * 0.38 * squash,
          -_band / 2 + math.sin(a) * _ry - 7.5 * s * 0.44,
        ),
        7.5 * s * 0.22,
        const Color(0xFFFFF4F0),
        0.7 * o,
      );
    }
    for (var i = 0; i < 14; i++) {
      final a = math.pi * (0.08 + 0.84 * hash01(i, 71));
      final g = math.sin(time * (1.3 + hash01(i, 72)) + i * 2.4);
      if (g < 0.6) continue;
      _grains.add(
        Offset(
          math.cos(a) * _rx,
          -_band * hash01(i, 73) + math.sin(a) * _ry,
        ),
        0.85,
        const Color(0xFFFFE6B0),
        (g - 0.6) / 0.4 * 0.9 * o,
      );
    }
    _grains.draw(canvas);
    canvas.restore();
  }

  /// On its own, for a card: centred on [center] in a box of half-side
  /// [r].
  static void paintPreview(
    Canvas canvas,
    Offset center,
    double r,
    double t, {
    double opacity = 1,
    Color color = defaultColor,
  }) => paint(
    canvas,
    center + Offset(0, r * 0.42),
    r * 1.5,
    t,
    opacity: opacity,
    color: color,
  );
}
