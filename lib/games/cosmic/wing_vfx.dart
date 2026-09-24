import 'dart:math';
import 'dart:ui' as ui;

import 'cosmic_data.dart';
import 'vfx_shapes.dart';

/// Wing's beams, the Fire and Poison perimeter rings, and the beam charge.
/// Shared by survival, open space and dungeons.
///
/// The old beams were one rod for every element — three stacked round-capped
/// strokes — with the element threaded on as glyphs: chevrons, beads,
/// brackets, plus signs, an arrowhead. They told the elements apart the way a
/// diagram does. Here a beam is light: a lit core that tapers at both ends,
/// glow falling off across its width through a gradient, a flare where it
/// leaves the wing and light pooling where it lands. The element is the
/// material moving through that light, drawn as filled pieces (see
/// vfx_shapes.dart), never as symbols.
///
/// Budget: two gradient fills per beam, a bounded number of filled pieces,
/// no blur. [details] false drops the pieces and keeps the beam.

final ui.Paint _paint = ui.Paint();
final ui.Paint _stroke = ui.Paint()
  ..style = ui.PaintingStyle.stroke
  ..strokeCap = ui.StrokeCap.round
  ..strokeJoin = ui.StrokeJoin.round;

void _dot(ui.Canvas canvas, ui.Offset c, double r, ui.Color color, double a) {
  if (a <= 0.004) return;
  _paint
    ..shader = null
    ..color = color.withValues(alpha: a.clamp(0.0, 1.0));
  canvas.drawCircle(c, r, _paint);
}

/// A jagged conductor from x=0 to x=[len], lit core over a faint glow.
void _boltAlong(
  ui.Canvas canvas,
  double len,
  double amp,
  double seed,
  VfxMaterial m,
  double a,
  double width,
) {
  final path = ui.Path()..moveTo(0, 0);
  const segs = 14;
  for (var i = 1; i < segs; i++) {
    final t = i / segs;
    path.lineTo(
      len * t,
      (vfxHash(seed + i * 3.7) - 0.5) * 2 * amp * sin(t * pi),
    );
  }
  path.lineTo(len, 0);
  _stroke
    ..color = m.light.withValues(alpha: 0.22 * a)
    ..strokeWidth = width * 3.2;
  canvas.drawPath(path, _stroke);
  _stroke
    ..color = m.glint.withValues(alpha: 0.9 * a)
    ..strokeWidth = width;
  canvas.drawPath(path, _stroke);
}

/// Elements whose beam body is the dark material itself rather than light.
const _denseBody = {'Lava', 'Earth', 'Mud', 'Dark', 'Blood'};

/// One Wing beam from [start] to [end], [width] being the gameplay width.
void drawWingBeam({
  required ui.Canvas canvas,
  required ui.Offset start,
  required ui.Offset end,
  required String element,
  required double width,
  required double alpha,
  required double time,
  bool details = true,
}) {
  final len = (end - start).distance;
  if (len < 0.5 || alpha <= 0) return;
  final a = alpha.clamp(0.0, 1.0);
  final w = max(1.5, width);
  final m = vfxMaterial(element);
  final dense = _denseBody.contains(element);
  final isDark = element == 'Dark';
  final flicker = 0.9 + 0.1 * sin(time * 31 + len * 0.01);
  // The element's own hue, taken down toward its material so it glows
  // without going neon.
  final tint = ui.Color.lerp(elementColor(element), m.mid, 0.3)!;

  // Light where it lands and where it leaves — drawn in world space so the
  // pools stay round whatever the angle.
  vfxSpill(canvas, end, w * 3.0, isDark ? m.light : tint, 0.4 * a * flicker);
  vfxSpill(canvas, start, w * 2.2, isDark ? m.light : tint, 0.45 * a);

  canvas.save();
  canvas.translate(start.dx, start.dy);
  canvas.rotate(atan2(end.dy - start.dy, end.dx - start.dx));

  // Glow, body, core — each a tapered lens lit across its width.
  final glowH = w * 3.0;
  vfxCrossLit(
    canvas,
    vfxLens(len, glowH, w * 2.5, w * 1.6),
    glowH / 2,
    isDark ? m.light : tint,
    isDark ? m.light : tint,
    (isDark ? 0.5 : 0.36) * a,
    plateau: 0.15,
  );
  final bodyH = w * 1.1;
  vfxCrossLit(
    canvas,
    vfxLens(len, bodyH, w * 1.8, w * 1.2),
    bodyH / 2,
    dense && !isDark && element != 'Lava' ? m.ink : tint,
    element == 'Lava' || !dense
        ? ui.Color.lerp(tint, m.glint, 0.3)!
        : element == 'Earth' || element == 'Mud'
        ? ui.Color.lerp(tint, m.glint, 0.15)!
        : ui.Color.lerp(tint, m.mid, 0.5)!,
    (dense ? 0.95 : 0.85) * a,
    plateau: 0.45,
  );
  if (isDark) {
    // A genuinely black interior with light only at its rim.
    vfxFillPath(canvas, vfxLens(len, w * 0.72, w * 1.4, w), m.ink, 0.97 * a);
  } else {
    vfxFillPath(
      canvas,
      vfxLens(
        len,
        max(
          1.4,
          w * (dense && element != 'Earth' && element != 'Mud' ? 0.24 : 0.34),
        ),
        w * 1.2,
        w * 0.8,
      ),
      m.glint,
      0.92 * a * flicker,
    );
  }

  if (details) {
    _drawMaterial(canvas, element, m, len, w, time, a);
  } else if (element == 'Lightning') {
    _boltAlong(canvas, len, w * 0.6, (time * 20).floorToDouble(), m, a, 1.2);
  }
  canvas.restore();

  // Where it leaves the wing: a small hot bead of the material's light.
  _dot(canvas, start, w * 0.45, m.glint, 0.7 * a);
}

void _drawMaterial(
  ui.Canvas canvas,
  String element,
  VfxMaterial m,
  double len,
  double w,
  double time,
  double a,
) {
  // Pieces flow from the wing to the target.
  double flow(int i, int n, double speed) =>
      ((time * speed * 200 / max(len, 60)) + i / n) % 1.0;

  switch (element) {
    case 'Lightning':
      final step = (time * 20).floorToDouble();
      for (var s = 0; s < 3; s++) {
        _boltAlong(
          canvas,
          len,
          w * (0.55 + s * 0.2),
          step * 3 + s * 11,
          m,
          a,
          s == 0 ? 1.4 : 0.9,
        );
      }
    case 'Ice':
      // Frost growing out of the lance, longest where it has been longest.
      final n = max(4, (len / (w * 2.4)).floor()).clamp(4, 16);
      for (var i = 0; i < n; i++) {
        final x = len * (i + 0.5) / n;
        final side = i.isEven ? 1.0 : -1.0;
        final grow = 0.8 + 0.2 * sin(time * 2 + i);
        final h = w * (1.0 + 0.7 * vfxHash(i * 1.7)) * grow;
        final base = ui.Offset(x, side * w * 0.25);
        final ang = side * (pi / 2 - 0.5) + (vfxHash(i * 3.1) - 0.5) * 0.4;
        vfxFillPath(canvas, vfxShard(base, h, w * 0.26, ang), m.mid, 0.85 * a);
        vfxFillPath(
          canvas,
          vfxShard(base, h * 0.7, w * 0.07, ang),
          m.glint,
          0.7 * a,
        );
      }
    case 'Water':
      // Two ribbons braiding around the column, and spray it carries.
      for (var s = 0; s < 2; s++) {
        final spine = [
          for (var i = 0; i <= 24; i++)
            ui.Offset(
              len * i / 24,
              sin(i / 24 * pi * 5 - time * 5 + s * pi) *
                  w *
                  0.45 *
                  sin(i / 24 * pi),
            ),
        ];
        vfxFillPath(
          canvas,
          vfxRibbon(spine, w * 0.24, w * 0.08),
          s == 0 ? m.glint : m.mid,
          (s == 0 ? 0.55 : 0.7) * a,
        );
      }
      for (var i = 0; i < 5; i++) {
        final t = flow(i, 5, 1.3);
        vfxFillPath(
          canvas,
          vfxDrop(ui.Offset(len * t, sin(t * 17 + i) * w * 0.5), w * 0.16, 0),
          m.glint,
          0.6 * sin(t * pi) * a,
        );
      }
    case 'Dark':
      // Violet light licking at the black core's rim; shadow carried along.
      for (final side in const [-1.0, 1.0]) {
        final spine = [
          for (var i = 0; i <= 20; i++)
            ui.Offset(
              len * i / 20,
              side * w * (0.36 + 0.06 * sin(i * 1.3 - time * 9)),
            ),
        ];
        vfxFillPath(
          canvas,
          vfxRibbon(spine, w * 0.18, w * 0.07),
          m.glint,
          0.75 * a,
        );
      }
      for (var i = 0; i < 5; i++) {
        final t = flow(i, 5, 1.1);
        vfxFillPath(
          canvas,
          vfxBlob(
            ui.Offset(len * t, sin(i * 4.1) * w * 0.9),
            w * 0.22,
            i.toDouble(),
            n: 7,
            wobble: 0.3,
          ),
          m.ink,
          0.7 * sin(t * pi) * a,
        );
      }
    case 'Air':
      // Pressure fronts pushed down the jet, bowing forward.
      for (var i = 0; i < 5; i++) {
        final t = flow(i, 5, 1.8);
        vfxFillPath(
          canvas,
          vfxCrescent(
            ui.Offset(len * t - w * 1.3, 0),
            w * 1.4,
            w * 0.4,
            0,
            1.7,
          ),
          m.glint,
          0.5 * sin(t * pi) * a,
        );
      }
    case 'Dust':
      // Grit blown along it, tumbling and spreading.
      for (var i = 0; i < 16; i++) {
        final t = flow(i, 16, 0.9 + vfxHash(i.toDouble()) * 0.5);
        final y = (vfxHash(i * 2.3) - 0.5) * w * 1.8 * (0.4 + t * 0.6);
        vfxFillPath(
          canvas,
          vfxBlob(
            ui.Offset(len * t, y),
            w * (0.13 + 0.1 * vfxHash(i * 5.1)),
            i.toDouble(),
            n: 5,
            wobble: 0.3,
          ),
          i.isEven ? m.glint : m.ink,
          0.85 * sin(t * pi) * a,
        );
      }
    case 'Lava':
      // Crust plates riding a molten seam; drops of it falling away.
      final n = max(3, (len / (w * 3)).floor()).clamp(3, 12);
      for (var i = 0; i < n; i++) {
        final x = len * (i + 0.5) / n + sin(time * 2 + i) * w * 0.2;
        final side = i.isEven ? 1.0 : -1.0;
        vfxFillPath(
          canvas,
          vfxBlob(
            ui.Offset(x, side * w * 0.3),
            w * 0.5,
            i * 2.0,
            n: 6,
            wobble: 0.25,
            squash: 0.5,
          ),
          const ui.Color(0xFF2A120A),
          0.92 * a,
        );
      }
      for (var i = 0; i < 6; i++) {
        final t = flow(i, 6, 0.7);
        final side = i.isEven ? 1.0 : -1.0;
        vfxFillPath(
          canvas,
          vfxDrop(
            ui.Offset(len * t, side * w * (0.55 + t * 0.6)),
            w * 0.13,
            side * pi / 2,
          ),
          m.glint,
          0.85 * sin(t * pi) * a,
        );
      }
    case 'Blood':
      // A vein: twisted strands, and a pulse running toward what it feeds on.
      for (var s = 0; s < 2; s++) {
        final spine = [
          for (var i = 0; i <= 20; i++)
            ui.Offset(
              len * i / 20,
              sin(i / 20 * pi * 3 + s * pi) * w * 0.3 * sin(i / 20 * pi),
            ),
        ];
        vfxFillPath(
          canvas,
          vfxRibbon(spine, w * 0.14, w * 0.05),
          const ui.Color(0xFF4A0F1C),
          0.8 * a,
        );
      }
      for (var i = 0; i < 3; i++) {
        final t = flow(i, 3, 1.4);
        canvas.save();
        canvas.translate(len * t, 0);
        canvas.scale(2.2, 1);
        vfxSpill(
          canvas,
          ui.Offset.zero,
          w * 0.55,
          m.glint,
          0.55 * sin(t * pi) * a,
        );
        canvas.restore();
      }
    case 'Earth':
      // Stone ground along it, chips of it tumbling toward the target.
      for (var i = 0; i < 7; i++) {
        final t = flow(i, 7, 0.8);
        final c = ui.Offset(len * t, (vfxHash(i * 1.9) - 0.5) * w * 0.9);
        final r = w * (0.34 + 0.16 * vfxHash(i * 4.3));
        vfxFillPath(
          canvas,
          vfxBlob(c, r, i + time * 3, n: 6, wobble: 0.3),
          m.ink,
          0.95 * sin(t * pi) * a,
        );
        vfxFillPath(
          canvas,
          vfxBlob(
            c + ui.Offset(-r * 0.2, -r * 0.3),
            r * 0.5,
            i * 3.0,
            n: 5,
            wobble: 0.2,
          ),
          m.glint,
          0.4 * sin(t * pi) * a,
        );
      }
    case 'Light':
      // A clean lance: the only decoration is light itself, sliding along.
      for (var i = 0; i < 3; i++) {
        final t = flow(i, 3, 0.9);
        canvas.save();
        canvas.translate(len * t, 0);
        canvas.scale(3, 1);
        vfxSpill(
          canvas,
          ui.Offset.zero,
          w * 0.7,
          m.glint,
          0.45 * sin(t * pi) * a,
        );
        canvas.restore();
      }
    case 'Spirit':
      // Wisps winding round the beam, and souls drifting down it.
      for (var s = 0; s < 3; s++) {
        final spine = [
          for (var i = 0; i <= 24; i++)
            ui.Offset(
              len * i / 24,
              sin(i / 24 * pi * 3 - time * 2.4 + s * 2.1) *
                  w *
                  0.7 *
                  sin(i / 24 * pi),
            ),
        ];
        vfxFillPath(
          canvas,
          vfxRibbon(spine, w * (s == 0 ? 0.14 : 0.24), w * 0.03),
          s == 0 ? m.glint : m.mid,
          (s == 0 ? 0.5 : 0.3) * a,
        );
      }
      for (var i = 0; i < 3; i++) {
        final t = flow(i, 3, 0.6);
        vfxSpill(
          canvas,
          ui.Offset(len * t, 0),
          w * 0.6,
          m.glint,
          0.6 * sin(t * pi) * a,
        );
      }
    case 'Crystal':
      // Light caught in facets inside the beam: two-tone prisms, no outline.
      final n = max(3, (len / (w * 3.2)).floor()).clamp(3, 10);
      for (var i = 0; i < n; i++) {
        final x = len * (i + 0.5) / n;
        final h = w * 0.62;
        final d = w * 0.9;
        final top = ui.Path()
          ..addPolygon([
            ui.Offset(x - d, 0),
            ui.Offset(x, -h),
            ui.Offset(x + d, 0),
          ], true);
        final bottom = ui.Path()
          ..addPolygon([
            ui.Offset(x - d, 0),
            ui.Offset(x, h),
            ui.Offset(x + d, 0),
          ], true);
        final catchLight = 0.5 + 0.5 * sin(time * 3 + i * 1.3);
        vfxFillPath(canvas, top, m.glint, (0.3 + 0.35 * catchLight) * a);
        vfxFillPath(canvas, bottom, m.mid, 0.7 * a);
      }
    case 'Steam':
      // A pressure jet venting plumes that swell as they go.
      for (var i = 0; i < 7; i++) {
        final t = flow(i, 7, 1.0);
        final side = i.isEven ? 1.0 : -1.0;
        vfxSpill(
          canvas,
          ui.Offset(len * t, side * w * (0.3 + t * 0.9)),
          w * (0.6 + t * 1.2),
          m.glint,
          0.4 * sin(t * pi) * a,
        );
      }
    case 'Mud':
      // Slurry: clots dragging along it and drips hanging off it.
      for (var i = 0; i < 8; i++) {
        final t = flow(i, 8, 0.45);
        final side = i.isEven ? 1.0 : -1.0;
        final c = ui.Offset(len * t, side * w * 0.42);
        vfxFillPath(
          canvas,
          vfxBlob(
            c,
            w * (0.36 + 0.1 * vfxHash(i * 2.2)),
            i.toDouble(),
            n: 7,
            wobble: 0.25,
          ),
          m.mid,
          0.9 * a,
        );
        if (i % 3 == 0) {
          vfxFillPath(
            canvas,
            vfxDrop(c + ui.Offset(0, side * w * 0.3), w * 0.12, side * pi / 2),
            m.mid,
            0.85 * a,
          );
        }
      }
    case 'Plant':
      // A vine: a stem twisting round the beam, leaves along it.
      final spine = [
        for (var i = 0; i <= 24; i++)
          ui.Offset(len * i / 24, sin(i / 24 * pi * 4 + time * 1.2) * w * 0.28),
      ];
      vfxFillPath(canvas, vfxRibbon(spine, w * 0.22, w * 0.1), m.ink, 0.9 * a);
      final n = max(3, (len / (w * 2.6)).floor()).clamp(3, 12);
      for (var i = 0; i < n; i++) {
        final x = len * (i + 0.5) / n;
        final side = i.isEven ? 1.0 : -1.0;
        final reach = w * (0.95 + 0.12 * sin(time * 3 + i));
        final ang = side * (pi / 2 - 0.6);
        vfxFillPath(
          canvas,
          vfxLeaf(ui.Offset(x, 0), reach, ang),
          m.mid,
          0.9 * a,
        );
        vfxFillPath(
          canvas,
          vfxLeaf(ui.Offset(x, 0), reach * 0.55, ang),
          m.glint,
          0.3 * a,
        );
      }
    case 'Fire':
      // Flames licking off both sides; embers thrown ahead.
      for (var i = 0; i < 8; i++) {
        final t = flow(i, 8, 1.2);
        final side = i.isEven ? 1.0 : -1.0;
        final c = ui.Offset(len * t, side * w * 0.35);
        final h = w * (0.35 + 0.25 * sin(time * 9 + i)) * sin(t * pi);
        vfxFillPath(
          canvas,
          vfxDrop(c, h, side * (pi / 2 - 0.4)),
          m.mid,
          0.75 * a,
        );
        vfxFillPath(
          canvas,
          vfxDrop(c, h * 0.5, side * (pi / 2 - 0.4)),
          m.glint,
          0.8 * a,
        );
      }
    case 'Poison':
      for (var i = 0; i < 7; i++) {
        final t = flow(i, 7, 0.8);
        final c = ui.Offset(len * t, (vfxHash(i * 2.9) - 0.5) * w * 1.3);
        _dot(canvas, c, w * (0.14 + 0.1 * t), m.mid, 0.8 * sin(t * pi) * a);
        _dot(
          canvas,
          c + ui.Offset(-w * 0.05, -w * 0.05),
          w * 0.05,
          m.glint,
          0.6 * sin(t * pi) * a,
        );
      }
    default:
      break;
  }
}

/// Fire's sweeping circle and Poison's perimeter, drawn as ground: a band of
/// char and flame, or a bank of fog, at [radius] — not a neon hoop.
void drawWingRing({
  required ui.Canvas canvas,
  required ui.Offset center,
  required double radius,
  required double width,
  required String element,
  required double alpha,
  required double time,
  bool details = true,
}) {
  final a = alpha.clamp(0.0, 1.0);
  if (a <= 0 || radius <= 1) return;
  final m = vfxMaterial(element);
  final band = max(10.0, width * 2.4);
  final poison = element == 'Poison';

  vfxSoftRing(
    canvas,
    center,
    radius,
    band * 1.8,
    m.light,
    (poison ? 0.12 : 0.18) * a,
  );
  vfxSoftRing(canvas, center, radius, band * 0.9, m.ink, 0.5 * a);

  // Pieces around the circumference, spaced by arc length so a huge ring and
  // a small one look equally dense.
  final circumference = pi * 2 * radius;
  final cap = details ? 72 : 28;
  final n = (circumference / (poison ? band * 2.0 : band * 0.9)).floor().clamp(
    12,
    cap,
  );

  if (poison) {
    for (var i = 0; i < n; i++) {
      final ang = i * pi * 2 / n + time * 0.08;
      final roll = 0.5 + 0.5 * sin(time * 1.2 + i * 1.7);
      final c =
          center + vfxPolar(ang, radius + sin(i * 2.3 + time) * band * 0.3);
      vfxFillPath(
        canvas,
        vfxBlob(
          c,
          band * (0.55 + 0.25 * roll),
          i + time * 0.2,
          n: 8,
          wobble: 0.16,
        ),
        m.ink,
        0.5 * a,
      );
      vfxFillPath(
        canvas,
        vfxBlob(
          c + vfxPolar(ang + pi, band * 0.1),
          band * (0.38 + 0.2 * roll),
          i * 3 + time * 0.2,
          n: 8,
          wobble: 0.18,
        ),
        ui.Color.lerp(m.mid, m.glint, 0.25)!,
        0.45 * a,
      );
      if (details && i.isEven) {
        final ph = (time * 0.5 + i * 0.37) % 1.0;
        _dot(
          canvas,
          c + vfxPolar(ang, -band * 0.3 + ph * band * 0.9),
          max(1.0, band * 0.07),
          m.glint,
          0.6 * sin(ph * pi) * a,
        );
      }
    }
    return;
  }

  // Fire: flame tongues standing out of the char, leaning outward.
  for (var i = 0; i < n; i++) {
    final ang = i * pi * 2 / n + (vfxHash(i.toDouble()) - 0.5) * 0.05;
    final lick = 0.65 + 0.35 * sin(time * 8 + i * 2.3);
    final base = center + vfxPolar(ang, radius);
    final h = band * (0.35 + 0.3 * vfxHash(i * 1.3)) * lick;
    vfxFillPath(
      canvas,
      vfxDrop(base + vfxPolar(ang, h * 0.4), h, ang),
      m.mid,
      0.75 * a,
    );
    vfxFillPath(
      canvas,
      vfxDrop(base + vfxPolar(ang, h * 0.3), h * 0.5, ang),
      m.glint,
      0.8 * a,
    );
  }
  // The sweep itself: the hot part of the circle travelling round it.
  final sweep = (time * 3.4) % (pi * 2);
  for (var k = 0; k < 3; k++) {
    final t = k / 3;
    vfxFillPath(
      canvas,
      vfxCrescent(
        center,
        radius + band * 0.35,
        band * (0.8 - 0.25 * k),
        sweep - t * 0.5,
        0.9 - t * 0.2,
      ),
      k == 0 ? m.glint : m.mid,
      (0.55 - 0.15 * k) * a,
    );
  }
}

/// The wing gathering itself before it fires: light drawing in and a core
/// brightening. [progress] runs 0 → 1 over the charge.
void drawWingBeamCharge({
  required ui.Canvas canvas,
  required ui.Offset origin,
  required ui.Color color,
  required double progress,
  required double time,
}) {
  final t = progress.clamp(0.0, 1.0);
  final glint = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.6)!;
  final mid = ui.Color.lerp(color, const ui.Color(0xFF000000), 0.25)!;
  vfxSpill(canvas, origin, 30 - 10 * t, color, 0.18 + 0.2 * t);
  // Motes pulled in from all round, faster as the charge fills.
  for (var i = 0; i < 7; i++) {
    final ph = (time * (0.9 + t * 1.6) + i / 7) % 1.0;
    final ang = i * 2.399 + time * 0.8;
    final r = (40 - 26 * t) * (1 - ph) + 4;
    vfxFillPath(
      canvas,
      vfxDrop(origin + vfxPolar(ang, r), 1.6 + 1.4 * t, ang + pi),
      mid,
      0.7 * sin(ph * pi),
    );
  }
  vfxSpill(canvas, origin, 6 + 9 * t, glint, 0.35 + 0.5 * t);
}
