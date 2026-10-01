import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'alchemy_simulation.dart';

const alchemyColors = <Color>[
  Color(0xFFF5B77A),
  Color(0xFF75BDCF),
  Color(0xFFB2A181),
  Color(0xFFB2D5CE),
  Color(0xFFD7E4DF),
  Color(0xFFF39565),
  Color(0xFFC9C2FF),
  Color(0xFF969775),
  Color(0xFFB2E0E6),
  Color(0xFFC8B894),
  Color(0xFFC0D8BB),
  Color(0xFF89B18B),
  Color(0xFFB9C882),
  Color(0xFFBBB3DA),
  Color(0xFF7D88B6),
  Color(0xFFF3E8BD),
  Color(0xFFC7798B),
];
Color alchemyColor(AlchemyElement e) => alchemyColors[e.index];

/// All visual decisions live here; the simulation knows no Flutter types.
/// Paths are batched by material so blur cost doesn't grow per particle.
class AlchemyPainter extends CustomPainter {
  AlchemyPainter({
    required this.simulation,
    required this.time,
    required Listenable repaint,
  }) : super(repaint: repaint);
  final AlchemySimulation simulation;
  final double Function() time;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.clipRect(rect);
    final t = time(),
        sx = size.width / AlchemySimulation.width,
        sy = size.height / AlchemySimulation.height;
    final scale = min(sx, sy);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * .5, size.height * .67),
          size.longestSide * .85,
          const [Color(0xFF142C32), Color(0xFF0A171E), Color(0xFF060D13)],
          [0, .55, 1],
        ),
    );

    // Light shafts in the smoked glass. These move slowly enough to feel still.
    final beams = Paint()..blendMode = BlendMode.screen;
    for (var i = 0; i < 3; i++) {
      final x = size.width * (.23 + i * .27) + sin(t * .12 + i) * 12;
      final beam = Path()
        ..moveTo(x, 0)
        ..lineTo(x + 8, 0)
        ..lineTo(x + 65, size.height)
        ..lineTo(x - 35, size.height)
        ..close();
      beams.shader = ui.Gradient.linear(Offset(x, 0), Offset(x, size.height), [
        const Color(0xFF91C9CE).withValues(alpha: .025),
        Colors.transparent,
      ]);
      canvas.drawPath(beam, beams);
    }
    final dust = Paint();
    for (var i = 0; i < 45; i++) {
      final x = ((i * .6180339 + sin(t * .08 + i) * .012) % 1) * size.width;
      final y =
          ((i * .381966 + t * .002 * (i.isEven ? 1 : -1)) % 1) * size.height;
      dust.color = const Color(
        0xFFBBD8D4,
      ).withValues(alpha: .08 + .07 * sin(t * .4 + i).abs());
      canvas.drawCircle(Offset(x, y), i % 4 == 0 ? 1 : .55, dust);
    }

    final paths = List.generate(17, (_) => Path());
    final edges = List.generate(17, (_) => Path());
    final gasPaths = List.generate(17, (_) => Path());
    final filaments = Path(), flame = Path(), flameCore = Path();
    var fireX = 0.0, fireY = 0.0, fireCount = 0;
    final cells = simulation.cells;
    // Reconstruct contiguous settled pools as smooth surfaces, not cell edges.
    const w = AlchemySimulation.width, bottom = AlchemySimulation.height - 4;
    final poolIds = List<int>.filled(w, 0),
        tops = List<int>.filled(w, bottom + 1);
    for (var x = 2; x < w - 2; x++) {
      final id = cells[bottom * w + x];
      if (id == 0 || AlchemyElement.values[id - 1].phase != MatterPhase.liquid) {
        continue;
      }
      var top = bottom;
      while (top > 2 && cells[(top - 1) * w + x] == id) {
        top--;
      }
      if (bottom - top < 2) continue;
      poolIds[x] = id;
      tops[x] = top;
    }
    for (var start = 2; start < w - 2;) {
      final id = poolIds[start];
      if (id == 0) {
        start++;
        continue;
      }
      var end = start;
      while (end + 1 < w - 2 && poolIds[end + 1] == id) {
        end++;
      }
      final surface = Path();
      final pool = Path()..moveTo(start * sx, (bottom + 1) * sy);
      for (var x = start; x <= end; x++) {
        var sum = 0.0, samples = 0;
        for (var n = max(start, x - 3); n <= min(end, x + 3); n++) {
          sum += tops[n];
          samples++;
        }
        final px = (x + .5) * sx;
        final py =
            (sum / samples +
                sin(x * .14 + t * 1.4) * .23 +
                sin(x * .31 - t) * .1) *
            sy;
        pool.lineTo(px, py);
        if (x == start) {
          surface.moveTo(px, py);
        } else {
          surface.lineTo(px, py);
        }
      }
      pool.lineTo((end + 1) * sx, (bottom + 1) * sy);
      pool.close();
      paths[id - 1].addPath(pool, Offset.zero);
      edges[id - 1].addPath(surface, Offset.zero);
      start = end + 1;
    }
    for (var i = 0; i < cells.length; i++) {
      final id = cells[i];
      if (id == 0) continue;
      final e = AlchemyElement.values[id - 1],
          x = (i % AlchemySimulation.width + .5) * sx,
          y = (i ~/ AlchemySimulation.width + .5) * sy;
      final p = Offset(x, y);
      if (e == AlchemyElement.fire || e == AlchemyElement.lava) {
        fireX += x;
        fireY += y;
        fireCount++;
      }
      if (e.phase == MatterPhase.gas) {
        if (i % 3 == 0) {
          final breath = 1 + sin(t * .7 + x * .04 + y * .02) * .2;
          gasPaths[e.index].addOval(
            Rect.fromCenter(center: p, width: sx * 9 * breath, height: sy * 7),
          );
        }
        if (e == AlchemyElement.fire && i % 7 == 0) {
          final sway = sin(t * 2.6 + x * .18 + y * .07) * sx * 2;
          flame.moveTo(x - sx * 1.6, y + sy * 2);
          flame.cubicTo(
            x - sx * 3,
            y - sy * 2,
            x + sway,
            y - sy * 3,
            x + sway * 1.4,
            y - sy * 9,
          );
          flame.cubicTo(
            x + sx * 3 + sway,
            y - sy * 3,
            x + sx * 3,
            y,
            x - sx * 1.6,
            y + sy * 2,
          );
          if (i % 3 == 0) {
            flameCore.moveTo(x, y + sy);
            flameCore.quadraticBezierTo(
              x + sway,
              y - sy * 2,
              x + sway * .7,
              y - sy * 5,
            );
          }
        } else if (i % 29 == 0) {
          final drift = sin(y * .02 + t * .6) * sx * 5;
          filaments.moveTo(x, y);
          filaments.cubicTo(
            x + drift,
            y - sy * 3,
            x - drift,
            y - sy * 8,
            x + drift,
            y - sy * 12,
          );
        }
      } else if (e.phase == MatterPhase.liquid) {
        final column = i % w;
        if (poolIds[column] == id && i ~/ w >= tops[column]) continue;
        paths[e.index].addOval(
          Rect.fromCenter(center: p, width: sx * 2.8, height: sy * 2.6),
        );
        if (i >= AlchemySimulation.width &&
            cells[i - AlchemySimulation.width] != id &&
            i % 5 == 0) {
          edges[e.index].moveTo(x - sx * .6, y - sy * .5);
          edges[e.index].quadraticBezierTo(
            x,
            y - sy * (.65 + .15 * sin(t + x * .06)),
            x + sx * .6,
            y - sy * .5,
          );
        }
      } else if (e.phase == MatterPhase.solid) {
        paths[e.index].moveTo(x, y - sy * 1.5);
        paths[e.index].lineTo(x + sx, y);
        paths[e.index].lineTo(x, y + sy * 1.3);
        paths[e.index].lineTo(x - sx, y);
        paths[e.index].close();
        if (i % 5 == 0) {
          edges[e.index].moveTo(x, y - sy);
          edges[e.index].lineTo(x - sx * .6, y);
        }
      } else {
        paths[e.index].addOval(
          Rect.fromCenter(center: p, width: sx * 1.6, height: sy * 1.4),
        );
      }
    }

    // Reactions illuminate the vessel and the water below them.
    if (fireCount > 0) {
      final center = Offset(fireX / fireCount, fireY / fireCount);
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = ui.Gradient.radial(center, size.width * .6, [
            const Color(0xFFEBA466).withValues(alpha: .14),
            Colors.transparent,
          ]),
      );
    }
    for (final e in AlchemyElement.values) {
      if (e.phase == MatterPhase.gas) continue;
      final color = alchemyColor(e);
      canvas.drawPath(
        paths[e.index],
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, size.height * .3),
            Offset(0, size.height),
            [
              color.withValues(alpha: .85),
              Color.lerp(color, const Color(0xFF071C2A), .78)!,
            ],
          )
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            e.phase == MatterPhase.liquid ? scale * .85 : .3,
          ),
      );
      canvas.drawPath(
        edges[e.index],
        Paint()
          ..color = color.withValues(alpha: .65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(.6, scale * .32)
          ..strokeCap = StrokeCap.round,
      );
    }

    // Steam is a diffuse density field with a separate, thin optical edge.
    for (final e in AlchemyElement.values.where(
      (e) => e.phase == MatterPhase.gas,
    )) {
      final warm = e == AlchemyElement.fire;
      final color = alchemyColor(e);
      canvas.drawPath(
        gasPaths[e.index],
        Paint()
          ..color = color.withValues(alpha: warm ? .16 : .085)
          ..blendMode = BlendMode.screen
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            scale * (warm ? 5 : 4),
          ),
      );
      if (!warm) {
        canvas.drawPath(
          gasPaths[e.index],
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, size.height),
              Offset(size.width, 0),
              [
                color.withValues(alpha: .02),
                color.withValues(alpha: .08),
                color.withValues(alpha: .025),
              ],
              [0, .5, 1],
            )
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 1.5)
            ..blendMode = BlendMode.screen,
        );
      }
    }
    canvas.drawPath(
      flame,
      Paint()
        ..color = const Color(0xFFE8A05F).withValues(alpha: .48)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 1.2)
        ..blendMode = BlendMode.screen,
    );
    canvas.drawPath(
      flameCore,
      Paint()
        ..color = const Color(0xFFFFD6A0).withValues(alpha: .42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * .7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1)
        ..blendMode = BlendMode.screen,
    );
    canvas.drawPath(
      filaments,
      Paint()
        ..color = const Color(0xFFCCE1E2).withValues(alpha: .12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6,
    );

    for (final f in simulation.flashes) {
      final center = Offset(f.x * sx, f.y * sy),
          radius = (3 + (1 - f.life) * 14) * scale;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = ui.Gradient.radial(center, radius, [
            alchemyColor(f.product).withValues(alpha: f.life * .3),
            Colors.transparent,
          ]),
      );
    }
    // Narrow, broken reflections rather than a full-screen bloom wash.
    if (fireCount > 0) {
      for (var i = 0; i < 9; i++) {
        final y = size.height * .89 + i * sy * 1.5,
            x = fireX / fireCount + sin(t * 1.3 + i * .8) * sx * 5;
        final gx = (x / sx).floor().clamp(0, AlchemySimulation.width - 1),
            gy = (y / sy).floor().clamp(0, AlchemySimulation.height - 1);
        if (cells[gy * AlchemySimulation.width + gx] !=
            AlchemyElement.water.id) {
          continue;
        }
        canvas.drawLine(
          Offset(x - sx * (10 - i), y),
          Offset(x + sx * (10 - i), y),
          Paint()
            ..color = const Color(0xFFFFCD90).withValues(alpha: .11)
            ..strokeWidth = 1
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
        );
      }
    }
    final glass = Paint()
      ..color = const Color(0xFFADC9BF).withValues(alpha: .17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    final inset = Rect.fromLTWH(9, 9, size.width - 18, size.height - 18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inset, const Radius.circular(14)),
      glass,
    );
    for (var i = 1; i < 12; i++) {
      final y = size.height * i / 12;
      canvas.drawLine(Offset(10, y), Offset(i % 3 == 0 ? 20 : 15, y), glass);
      canvas.drawLine(
        Offset(size.width - 10, y),
        Offset(size.width - (i % 3 == 0 ? 20 : 15), y),
        glass,
      );
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          size.center(Offset.zero),
          size.longestSide * .7,
          [Colors.transparent, Colors.black.withValues(alpha: .33)],
          [.5, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant AlchemyPainter oldDelegate) =>
      oldDelegate.simulation != simulation;
}
