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

// ─────────────────────────────────────────────────────────────────────────────
//  WHAT A LIVE BEAM PUTS ON SCREEN EACH FRAME
//
//  Survival's, lifted verbatim so open space draws the same thing: the beam
//  segments a beam lays into its game's beam list, the particles it sheds into
//  the ability pool, Lightning's brewing storm while it charges, and the blast
//  that ends it. Each game passes its own sinks; nothing here knows a game.
//  The draws behind the random numbers are in survival's order, so a seeded
//  survival run is unchanged.
// ─────────────────────────────────────────────────────────────────────────────

/// A particle for a game's ability pool (survival's `_VfxParticle`, open
/// space's `AbilityVfxPool.add`).
typedef WingParticleEmit =
    void Function(
      double x,
      double y,
      double vx,
      double vy,
      double size,
      double life,
      ui.Color color,
    );

/// A segment for a game's beam list. [wingElement] null is the plain
/// element-less line (a micro-arc, the heal core).
typedef WingSegmentEmit =
    void Function(
      ui.Offset start,
      ui.Offset end,
      ui.Color color,
      double width,
      double life,
      String? wingElement,
    );

/// How long every per-frame segment of a live beam lasts.
const double kWingBeamFxLife = 0.08;

/// Spirit's cable into the ship: a little narrower, and it lingers.
const double kWingTetherCableWidthScale = 0.85;
const double kWingTetherCableLife = 0.12;

/// The white-green core a healing beam carries (not Water's or Crystal's).
const double kWingHealCoreWidthScale = 0.45;
const ui.Color kWingHealCoreColor = ui.Color(0xFFEFFFF1);

/// Lightning's blast: one wide, bright flash along the line.
const double kWingLightningBlastWidthScale = 3.4;
const double kWingLightningBlastLife = 0.28;

/// A ring is drawn out to its radius plus this before it is culled.
const double kWingRingCullPad = 24;

/// Pool sizes past which a beam sheds nothing more this frame.
const int kWingBeamParticleBudget = 135;
const int kWingChargeParticleBudget = 130;

/// A healing beam's light is tinted toward life-green.
ui.Color wingBeamColor(WingBeamEffect d) => d.healPerTick > 0
    ? ui.Color.lerp(elementColor(d.element), const ui.Color(0xFFCFFFD8), 0.55)!
    : elementColor(d.element);

/// Rings hold full strength and fade over their last 0.45 s.
double wingRingFade(double life) =>
    life < 0.45 ? (life / 0.45).clamp(0.0, 1.0) : 1.0;

/// The segments one live beam draws this frame, from [origin] to [end]. A
/// ring draws nothing here (its perimeter is painted in the render pass); a
/// Spirit tether runs a cable into [tetherTo] and a beam on from there.
void emitWingBeamSegments({
  required WingBeamEffect descriptor,
  required ui.Offset origin,
  required ui.Offset end,
  required ui.Offset tetherTo,
  required WingSegmentEmit segment,
}) {
  final d = descriptor;
  if (d.targetPolicy == WingBeamTargetPolicy.ring) return;
  if (d.targetPolicy == WingBeamTargetPolicy.shipTether) {
    // One spectral cable carries energy into the ship; a second runs from
    // the ship to its target. No generic white beams over the material,
    // which would hide its translucent strands.
    final tetherColor = elementColor(d.element);
    segment(
      origin,
      tetherTo,
      tetherColor,
      d.width * kWingTetherCableWidthScale,
      kWingTetherCableLife,
      d.element,
    );
    segment(tetherTo, end, tetherColor, d.width, kWingBeamFxLife, d.element);
    return;
  }
  segment(origin, end, wingBeamColor(d), d.width, kWingBeamFxLife, d.element);
  if (d.healPerTick > 0 && d.element != 'Water' && d.element != 'Crystal') {
    // Inner white-green core for healing beams.
    segment(
      origin,
      end,
      kWingHealCoreColor.withValues(alpha: 0.85),
      d.width * kWingHealCoreWidthScale,
      kWingBeamFxLife,
      null,
    );
  }
}

/// The particles a live beam sheds this frame, so it reads as a living
/// stream rather than a flat line. The caller checks its pool against
/// [kWingBeamParticleBudget] first.
void emitWingBeamParticles({
  required WingBeamEffect descriptor,
  required ui.Offset origin,
  required ui.Offset end,
  required ui.Offset tetherTo,
  required double beamLife,
  required Random rng,
  required WingParticleEmit emit,
}) {
  final element = descriptor.element;
  final base = elementColor(element);
  final white = ui.Color.lerp(base, const ui.Color(0xFFFFFFFF), 0.55)!;
  if (descriptor.targetPolicy == WingBeamTargetPolicy.ring) {
    // Along the perimeter, drifting round it and a little outward.
    final r = descriptor.radius;
    if (r <= 0) return;
    for (var i = 0; i < 3; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.92 + rng.nextDouble() * 0.18);
      final tang = ui.Offset(-sin(a), cos(a));
      final out = ui.Offset(cos(a), sin(a));
      emit(
        origin.dx + cos(a) * spawnR,
        origin.dy + sin(a) * spawnR,
        tang.dx * 30 + out.dx * 12,
        tang.dy * 30 + out.dy * 12,
        1.3 + rng.nextDouble() * 1.2,
        0.35 + rng.nextDouble() * 0.3,
        i.isEven ? base : white,
      );
    }
    return;
  }
  if (descriptor.targetPolicy == WingBeamTargetPolicy.shipTether) {
    // Sparkles flowing along the cable from the caster toward the ship.
    final flow = (beamLife * 2.4) % 1.0;
    final mid = ui.Offset.lerp(origin, tetherTo, flow)!;
    emit(
      mid.dx,
      mid.dy,
      (rng.nextDouble() - 0.5) * 30,
      (rng.nextDouble() - 0.5) * 30,
      1.5 + rng.nextDouble() * 1.0,
      0.3,
      white,
    );
    return;
  }
  final dir = end - origin;
  final dist = dir.distance;
  if (dist < 1) return;
  final unit = ui.Offset(dir.dx / dist, dir.dy / dist);
  final perp = ui.Offset(-unit.dy, unit.dx);
  // Sparks bursting from the hit point.
  for (var i = 0; i < 2; i++) {
    final a = rng.nextDouble() * 2 * pi;
    final spd = 30 + rng.nextDouble() * 50;
    emit(
      end.dx,
      end.dy,
      cos(a) * spd,
      sin(a) * spd,
      1.4 + rng.nextDouble() * 1.2,
      0.30 + rng.nextDouble() * 0.25,
      i.isEven ? base : white,
    );
  }
  // One drifter somewhere along the beam, fanning off it.
  final t = 0.2 + rng.nextDouble() * 0.6;
  final midPos = origin + unit * dist * t;
  final side = rng.nextBool() ? 1.0 : -1.0;
  emit(
    midPos.dx,
    midPos.dy,
    perp.dx * side * 18 + unit.dx * 12,
    perp.dy * side * 18 + unit.dy * 12,
    1.1 + rng.nextDouble() * 0.9,
    0.30 + rng.nextDouble() * 0.20,
    white.withValues(alpha: 0.75),
  );
}

/// A beam still charging, at [center]. Lightning brews a storm there — an
/// orb of inward-spiralling sparks and crackling micro-arcs that grows and
/// crackles harder with [progress] — and fires no line yet. Any other
/// element (none today) gets a small swelling point. [particleRoom] is the
/// caller's pool check against [kWingChargeParticleBudget].
void emitWingChargeVisual({
  required WingBeamEffect descriptor,
  required ui.Offset center,
  required double progress,
  required bool particleRoom,
  required Random rng,
  required WingParticleEmit emit,
  required WingSegmentEmit segment,
}) {
  if (descriptor.element != 'Lightning') {
    segment(
      center,
      center,
      elementColor(
        descriptor.element,
      ).withValues(alpha: (0.35 + 0.55 * progress).clamp(0.0, 1.0)),
      descriptor.width * (0.35 + 1.65 * progress),
      kWingBeamFxLife,
      null,
    );
    return;
  }
  if (!particleRoom) return;
  final color = elementColor('Lightning');
  final white = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.55)!;
  // From a tight 10 px to a stormy 34 px as it builds.
  final orbRadius = 10.0 + 24.0 * progress;
  // One inward spark always, one more in the back half of the charge.
  final sparkCount = 1 + (progress > 0.5 ? 1 : 0);
  for (var i = 0; i < sparkCount; i++) {
    final a = rng.nextDouble() * 2 * pi;
    final r = orbRadius * (1.1 + rng.nextDouble() * 0.7);
    final speed = 35 + 70 * progress;
    emit(
      center.dx + cos(a) * r,
      center.dy + sin(a) * r,
      -cos(a) * speed,
      -sin(a) * speed,
      1.0 + rng.nextDouble() * 1.6,
      0.35 + rng.nextDouble() * 0.35,
      i.isEven ? color : white,
    );
  }
  // Now and then a micro-arc inside the orb, more often as it builds.
  if (rng.nextDouble() < 0.30 + progress * 0.45) {
    final a1 = rng.nextDouble() * 2 * pi;
    final a2 = a1 + (rng.nextDouble() - 0.5) * 2.6;
    final r1 = orbRadius * (0.35 + rng.nextDouble() * 0.65);
    final r2 = orbRadius * (0.35 + rng.nextDouble() * 0.65);
    segment(
      ui.Offset(center.dx + cos(a1) * r1, center.dy + sin(a1) * r1),
      ui.Offset(center.dx + cos(a2) * r2, center.dy + sin(a2) * r2),
      white.withValues(alpha: 0.65 + 0.25 * progress),
      1.1 + progress * 1.2,
      kWingBeamFxLife,
      null,
    );
  }
}

/// The flash of Lightning's blast, from [origin] along to [end].
void emitWingLightningBlastFlash({
  required WingBeamEffect descriptor,
  required ui.Offset origin,
  required ui.Offset end,
  required WingSegmentEmit segment,
}) {
  segment(
    origin,
    end,
    ui.Color.lerp(elementColor('Lightning'), const ui.Color(0xFFFFFFFF), 0.55)!,
    descriptor.width * kWingLightningBlastWidthScale,
    kWingLightningBlastLife,
    'Lightning',
  );
}

/// A Wing+Plant flower waiting to be collected ([life] counts down from
/// 12 s): a soft halo, five turning petals round a bright core, pulsing
/// once it is close to wilting. Survival's pickup art, which its Kin+Plant
/// garden drops share.
void drawWingFlowerPickup({
  required ui.Canvas canvas,
  required ui.Offset position,
  required double life,
  required double bobPhase,
  required double time,
}) {
  final t = time;
  final petal = elementColor('Plant');
  final core = elementColor('Light');
  final bob = sin(t * 2.4 + bobPhase) * 1.6;
  final pos = ui.Offset(position.dx, position.dy + bob);
  final fade = (life / 12.0).clamp(0.0, 1.0);
  final lifePulse = life < 3.0 ? 0.7 + 0.3 * sin(t * 8) : 1.0;
  _paint.shader = null;
  _paint.color = petal.withValues(alpha: 0.18 * fade);
  canvas.drawCircle(pos, 14.0, _paint);
  _paint.color = petal.withValues(alpha: 0.28 * fade);
  canvas.drawCircle(pos, 9.5, _paint);
  for (var i = 0; i < 5; i++) {
    final a = i * (pi * 2 / 5) + t * 0.35;
    final petalPos = pos + ui.Offset(cos(a), sin(a)) * 5.5;
    _paint.color = petal.withValues(alpha: 0.92 * fade * lifePulse);
    canvas.drawCircle(petalPos, 4.0, _paint);
  }
  _paint.color = core.withValues(alpha: 0.95 * fade * lifePulse);
  canvas.drawCircle(pos, 3.2, _paint);
  _paint.color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.85 * fade);
  canvas.drawCircle(pos, 1.4, _paint);
}
