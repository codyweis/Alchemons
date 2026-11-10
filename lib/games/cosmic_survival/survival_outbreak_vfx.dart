import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'survival_outbreak.dart';

final Path _sourceArrow = Path()
  ..moveTo(8, 0)
  ..lineTo(-6, -5)
  ..lineTo(-3, 0)
  ..lineTo(-6, 5)
  ..close();

/// Grains for one tone of the outbreak's marks.
class _Grains {
  Float32List d = Float32List(1024);
  int n = 0;

  void add(double x, double y) {
    if (n + 2 > d.length) d = Float32List(d.length * 2)..setAll(0, d);
    d[n] = x;
    d[n + 1] = y;
    n += 2;
  }

  void line(Offset a, Offset b, int count) {
    for (var i = 0; i <= count; i++) {
      final f = i / count;
      add(a.dx + (b.dx - a.dx) * f, a.dy + (b.dy - a.dy) * f);
    }
  }

  void arc(Offset c, double r, double start, double sweep, int count) {
    for (var i = 0; i <= count; i++) {
      final a = start + sweep * i / count;
      add(c.dx + cos(a) * r, c.dy + sin(a) * r);
    }
  }

  void oval(Offset c, double rx, double ry, int count, [double turn = 0]) {
    final ct = cos(turn), st = sin(turn);
    for (var i = 0; i < count; i++) {
      final a = i / count * 2 * pi;
      final x = cos(a) * rx, y = sin(a) * ry;
      add(c.dx + x * ct - y * st, c.dy + x * st + y * ct);
    }
  }
}

final _Grains _dim = _Grains(), _lit = _Grains(), _hot = _Grains();
final Paint _grainPaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round;

double _h(int i, int salt) {
  final x = sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

/// A stream of grains running from [a] to [b], [rows] wide.
void _stream(_Grains g, Offset a, Offset b, double t, int rows) {
  final d = (b - a).distance;
  if (d < 1) return;
  final ux = (b.dx - a.dx) / d, uy = (b.dy - a.dy) / d;
  final n = (d / 6).clamp(8, 260).round();
  for (var row = 0; row < rows; row++) {
    final side = (row - (rows - 1) / 2) * 3.5;
    for (var i = 0; i < n; i++) {
      final s = (i / n + t * 0.4 + row * 0.13) % 1.0;
      final wob = (_h(i + row * 300, 31) - 0.5) * 2.4;
      g.add(
        a.dx + (b.dx - a.dx) * s - uy * (side + wob),
        a.dy + (b.dy - a.dy) * s + ux * (side + wob),
      );
    }
  }
}

/// The outbreak's marks on the arena, in grains like the bodies round them:
/// each source's field as a ring of drifting grains (the countdown to a
/// surge fills it bright from the top, the surge itself runs out across
/// it), a mark of its kind written round it in grains so the kinds are told
/// apart by shape and not colour alone, the streams that bind its sources,
/// and an arrow at the screen's edge toward a source out of view. At most
/// three fields and three streams, a few thousand grains in four draws.
void drawSurvivalOutbreak(
  Canvas canvas,
  SurvivalOutbreak event,
  Offset orb, {
  Rect? viewport,
}) {
  if (event.cleared) return;
  final color = event.color;
  final t = event.elapsed;
  final fill = Paint()
    ..color = color.withValues(alpha: event.surging ? 0.12 : 0.035);
  for (final core in event.cores) {
    if (core.isDead) continue;
    final hasField = switch (event.kind) {
      SurvivalOutbreakKind.nigredo ||
      SurvivalOutbreakKind.mirror ||
      SurvivalOutbreakKind.cinder ||
      SurvivalOutbreakKind.voltaic => false,
      _ => true,
    };
    final c = core.position;
    final radius = hasField ? event.fieldRadius : core.radius * 2.3;
    canvas.drawCircle(c, radius, fill);

    // The field's edge: a ring of grains drifting round it.
    final ringN = (2 * pi * radius / 7).clamp(60, 420).round();
    final drift = t * 0.05;
    final progress = event.warning ? event.warningProgress : 0.0;
    for (var i = 0; i < ringN; i++) {
      final f = (i + _h(i, 11) * 0.6) / ringN;
      final a = -pi / 2 + f * 2 * pi + drift;
      final rr = radius + (_h(i, 12) - 0.5) * 5;
      final g = event.warning ? (f <= progress ? _hot : _lit) : _dim;
      g.add(c.dx + cos(a) * rr, c.dy + sin(a) * rr);
    }
    if (event.surging) {
      _lit.arc(
        c,
        radius * (0.3 + 0.7 * event.cycle / 1.5),
        t * 0.2,
        2 * pi,
        ringN ~/ 2,
      );
    }

    // Its kind's mark.
    final gr = core.radius * 1.65;
    switch (event.kind) {
      case SurvivalOutbreakKind.verdigris:
        for (var i = 0; i < 3; i++) {
          final a = i * 2 * pi / 3;
          _lit.oval(c + Offset(cos(a), sin(a)) * gr, 8, 8, 18);
        }
      case SurvivalOutbreakKind.sanguine:
        _lit
          ..line(c + Offset(-gr, 0), c + Offset(gr, 0), 30)
          ..line(c + Offset(0, -gr), c + Offset(0, gr), 30);
      case SurvivalOutbreakKind.quicksilver:
        for (var i = 0; i < 3; i++) {
          _lit.arc(c, gr + i * 9, t * 0.5 + i, pi * 0.8, 26);
        }
      case SurvivalOutbreakKind.nigredo:
        _lit.oval(c, gr, gr / 2, 44);
      case SurvivalOutbreakKind.crystal:
        final h = gr * 0.8 * sqrt2;
        final pts = [
          c + Offset(0, -h),
          c + Offset(h, 0),
          c + Offset(0, h),
          c + Offset(-h, 0),
        ];
        for (var i = 0; i < 4; i++) {
          _lit.line(pts[i], pts[(i + 1) % 4], 16);
        }
      case SurvivalOutbreakKind.cinder:
        for (var i = 0; i < 3; i++) {
          final a = i * 2 * pi / 3 + t * 0.12;
          _lit.oval(c + Offset(cos(a), sin(a)) * gr, 6, 10, 18);
        }
      case SurvivalOutbreakKind.frost:
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3;
          _lit.line(
            c + Offset(cos(a), sin(a)) * gr,
            c + Offset(cos(a), sin(a)) * (gr + 18),
            6,
          );
        }
      case SurvivalOutbreakKind.voltaic:
        _lit
          ..line(c + Offset(-gr, -12), c + const Offset(0, 12), 16)
          ..line(c + const Offset(0, 12), c + Offset(gr, -12), 16);
      case SurvivalOutbreakKind.calcified:
        final rr = gr + (event.surging ? 12 : 0);
        for (var i = 0; i < 4; i++) {
          for (final w in const [-2.0, 0.0, 2.0]) {
            _lit.arc(c, rr + w, i * pi / 2, pi * 0.38, 12);
          }
        }
      case SurvivalOutbreakKind.mirror:
        _lit
          ..oval(c + Offset(-gr, 0), 11, 11, 20)
          ..oval(c + Offset(gr, 0), 11, 11, 20);
    }
    if (event.kind == SurvivalOutbreakKind.nigredo) {
      _stream(event.warning ? _lit : _dim, c, orb, t, 1);
    }
    if (viewport != null && !viewport.deflate(24).contains(c)) {
      final safe = viewport.deflate(24);
      final edge = Offset(
        c.dx.clamp(safe.left, safe.right),
        c.dy.clamp(safe.top, safe.bottom),
      );
      canvas.save();
      canvas.translate(edge.dx, edge.dy);
      canvas.rotate(atan2(c.dy - edge.dy, c.dx - edge.dx));
      canvas.drawPath(_sourceArrow, Paint()..color = color);
      canvas.restore();
    }
  }
  for (final (a, b) in event.links) {
    _stream(
      event.surging ? _hot : (event.warning ? _lit : _dim),
      a,
      b,
      t,
      event.surging ? 3 : (event.warning ? 2 : 1),
    );
  }

  final hot = Color.lerp(color, Colors.white, 0.35)!;
  for (final (g, w, col) in [
    (_dim, 2.2, color.withValues(alpha: 0.45)),
    (_lit, 2.6, color.withValues(alpha: 0.85)),
    (_hot, 3.2, hot),
  ]) {
    if (g.n == 0) continue;
    canvas.drawRawPoints(
      PointMode.points,
      Float32List.sublistView(g.d, 0, g.n),
      _grainPaint
        ..strokeWidth = w
        ..color = col,
    );
    g.n = 0;
  }
}
