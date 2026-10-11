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
/// no blur. A beam always carries its material: the material is what tells
/// the elements apart, so no quality setting strips it (it once did, and
/// every beam on the default setting was the same coloured laser). A live
/// beam is painted once a frame, straight from the game's live beams (see
/// [emitWingBeamSegments], [wingBeamFade]). Rings take a `details` flag that
/// thins their pieces.

final ui.Paint _paint = ui.Paint();

void _dot(ui.Canvas canvas, ui.Offset c, double r, ui.Color color, double a) {
  if (a <= 0.004) return;
  _paint
    ..shader = null
    ..color = color.withValues(alpha: a.clamp(0.0, 1.0));
  canvas.drawCircle(c, r, _paint);
}

/// A conductor from x=0 to x=[len]: a lit core over a faint glow, both
/// filled ribbons that swell in the middle and taper to points, bent through
/// a few kinks so it writhes like an arc rather than reading as a zig-zag
/// wire. The kinks drift from one pose to the next — [phase]'s whole part
/// picks the two poses, its fraction eases between them — where they used to
/// snap to a fresh zig-zag twenty times a second. [width] is the core's.
void _boltAlong(
  ui.Canvas canvas,
  double len,
  double amp,
  double seed,
  VfxMaterial m,
  double a,
  double width,
  double phase,
) {
  final k = phase.floorToDouble();
  final f = phase - k;
  final e = f * f * (3 - 2 * f);
  const segs = 7;
  final corners = <ui.Offset>[ui.Offset.zero];
  for (var i = 1; i < segs; i++) {
    final t = i / segs;
    final h0 = vfxHash(seed + k * 3.1 + i * 3.7);
    final h1 = vfxHash(seed + (k + 1) * 3.1 + i * 3.7);
    corners.add(
      ui.Offset(len * t, (h0 + (h1 - h0) * e - 0.5) * 2 * amp * sin(t * pi)),
    );
  }
  corners.add(ui.Offset(len, 0));
  final spine = vfxCurveSpine(corners, perSegment: 3);
  vfxFillPath(
    canvas,
    vfxLensRibbon(spine, width * 3.0, taper: 0.3),
    m.light,
    0.2 * a,
  );
  vfxFillPath(
    canvas,
    vfxLensRibbon(spine, width, taper: 0.3),
    m.glint,
    0.85 * a,
  );
}

/// Elements whose beam body is the dark material itself rather than light.
const _denseBody = {'Lava', 'Earth', 'Mud', 'Dark', 'Blood'};

/// Elements whose material is pale light: they take more of their hue.
const _glowingElements = kVfxGlowingElements;

/// The light a Wing beam glows in: its material's light, tinted toward the
/// element colour (30% for the glowing elements, 22% for the rest).
ui.Color wingBeamTint(String element) => ui.Color.lerp(
  vfxMaterial(element).light,
  elementColor(element),
  _glowingElements.contains(element) ? 0.3 : 0.22,
)!;

/// Lightning's material with its light and glint pulled 30% toward its own
/// yellow (the glowing-element tint), so a beam's arcs read electric
/// yellow-white rather than pale lavender.
final VfxMaterial _wingLightning = () {
  final m = vfxMaterial('Lightning');
  final y = elementColor('Lightning');
  return VfxMaterial(
    m.ink,
    m.mid,
    ui.Color.lerp(m.glint, y, 0.3)!,
    ui.Color.lerp(m.light, y, 0.3)!,
  );
}();

/// One Wing beam from [start] to [end], [width] being the gameplay width.
void drawWingBeam({
  required ui.Canvas canvas,
  required ui.Offset start,
  required ui.Offset end,
  required String element,
  required double width,
  required double alpha,
  required double time,
}) {
  final len = (end - start).distance;
  if (len < 0.5 || alpha <= 0) return;
  final a = alpha.clamp(0.0, 1.0);
  final w = max(1.5, width);
  final m = element == 'Lightning' ? _wingLightning : vfxMaterial(element);
  final dense = _denseBody.contains(element);
  final isDark = element == 'Dark';
  final flicker = 0.9 + 0.1 * sin(time * 31 + len * 0.01);
  // The material's light, tinted toward the element's hue — about 30% for
  // the glowing elements so they don't go to pale wires, less for the rest.
  // (It was 70% raw Material accent colour: every beam went neon.)
  final tint = wingBeamTint(element);

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

  _drawMaterial(canvas, element, m, len, w, time, a);
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
      // Two conductors, each easing between poses about three times a
      // second, out of step with each other.
      for (var s = 0; s < 2; s++) {
        _boltAlong(
          canvas,
          len,
          w * (0.55 + s * 0.25),
          s * 11.0,
          m,
          a,
          max(1.2, w * (s == 0 ? 0.17 : 0.11)),
          time * 3.0 + s * 0.5,
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
      // Pressure fronts pushed down the jet, bowing forward: soft, deep
      // swells of moving air rather than thin bright ticks across it.
      for (var i = 0; i < 4; i++) {
        final t = flow(i, 4, 1.8);
        vfxFillPath(
          canvas,
          vfxCrescent(
            ui.Offset(len * t - w * 1.6, 0),
            w * 1.7,
            w * 0.9,
            0,
            1.25,
          ),
          m.glint,
          0.26 * sin(t * pi) * a,
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
      // Splinters of crystal carried down the beam: each a long shard at its
      // own place, size and slant (no row of matching diamonds), a body and
      // a lit facet that catches the light as it turns. Two fills for all.
      final n = max(3, (len / (w * 2.6)).floor()).clamp(3, 12);
      final body = ui.Path();
      final facet = ui.Path();
      var lit = 0.0;
      for (var i = 0; i < n; i++) {
        final t = flow(i, n, 0.35);
        final h1 = vfxHash(i * 3.3 + 0.5), h2 = vfxHash(i * 5.9 + 1.7);
        final c = ui.Offset(len * t, (h1 - 0.5) * w * 0.7);
        final slant = (h2 - 0.5) * 0.7;
        final l = w * (1.5 + 1.2 * h2) * sin(t * pi).clamp(0.35, 1.0);
        body.addPath(vfxShard(c, l, l * 0.3, slant), ui.Offset.zero);
        facet.addPath(
          vfxShard(c + vfxPolar(slant - pi / 2, l * 0.08), l * 0.8, l * 0.1, slant),
          ui.Offset.zero,
        );
        lit += 0.5 + 0.5 * sin(time * 3 + i * 1.3);
      }
      vfxFillPath(canvas, body, m.mid, 0.8 * a);
      vfxFillPath(canvas, facet, m.glint, (0.45 + 0.4 * lit / n) * a);
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
      // A stem with a body and a lit side, not a dark wire across the beam.
      vfxFillPath(canvas, vfxRibbon(spine, w * 0.36, w * 0.16), m.mid, 0.92 * a);
      vfxFillPath(
        canvas,
        vfxRibbon(
          [for (final p in spine) p + ui.Offset(0, -w * 0.06)],
          w * 0.14,
          w * 0.05,
        ),
        m.glint,
        0.45 * a,
      );
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

/// Fire's and Poison's field round the wing, drawn as ground over the whole
/// disc it hits ([radius]) — the hit is a filled disc, so the art is one too:
/// scorched ground with flames standing across it, or a bank of fog lying
/// over it. No dashed perimeter of drops and no radar sweep.
///
/// Every piece lies on a sunflower spiral (even cover, no ring, no rows),
/// and all of a tone go in one path: about six fills for the whole field.
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
  final cap = details ? 30 : 14;
  final n = (radius / band * (poison ? 2.2 : 3.0)).floor().clamp(8, cap);
  const golden = 2.399963;
  ui.Offset at(int i) {
    final f = sqrt((i + 0.5) / n);
    return center +
        vfxPolar(
          i * golden + (vfxHash(i * 1.7) - 0.5) * 0.5,
          radius * 0.9 * f,
        );
  }

  if (poison) {
    // A toxic bank: the ground stained under it, banks of fog rolling where
    // they lie, bubbles rising out of them.
    vfxSpill(canvas, center, radius, m.ink, 0.4 * a);
    vfxSpill(canvas, center, radius * 1.02, m.light, 0.12 * a);
    final fog = ui.Path();
    final lit = ui.Path();
    // Banks sized from the field, so they close over it at any radius.
    final bank = max(band, radius / sqrt(n) * 1.15);
    for (var i = 0; i < n; i++) {
      final roll = 0.5 + 0.5 * sin(time * 1.1 + i * 1.7);
      final c = at(i) + vfxPolar(i * 0.9 + time * 0.25, band * 0.15);
      fog.addPath(
        vfxBlob(c, bank * (0.85 + 0.25 * roll), i * 3.1, n: 12, wobble: 0.18),
        ui.Offset.zero,
      );
      if (i.isEven) {
        lit.addPath(
          vfxBlob(
            c + ui.Offset(-bank * 0.12, -bank * 0.14),
            bank * (0.36 + 0.16 * roll),
            i * 5.3,
            n: 8,
            wobble: 0.2,
          ),
          ui.Offset.zero,
        );
      }
    }
    vfxFillPath(canvas, fog, m.mid, 0.16 * a);
    vfxFillPath(canvas, lit, ui.Color.lerp(m.mid, m.glint, 0.3)!, 0.14 * a);
    if (details) {
      for (var i = 0; i < n; i += 2) {
        final ph = (time * 0.45 + vfxHash(i * 2.3)) % 1.0;
        final p = at(i) + ui.Offset(0, -ph * band * 1.2);
        vfxGrain(p.dx, p.dy);
      }
      vfxGrainsFlush(canvas, max(1.6, band * 0.12), m.glint, 0.55 * a);
    }
    return;
  }

  // Fire: the ground charred under the whole disc and lit warm from the
  // flames standing across it, rising (not leaning out from a rim).
  vfxSpill(canvas, center, radius, m.ink, 0.5 * a);
  vfxSpill(canvas, center, radius * 1.04, m.light, 0.2 * a);
  final char = ui.Path();
  final body = ui.Path();
  final hot = ui.Path();
  for (var i = 0; i < n; i++) {
    final lick = 0.7 + 0.3 * sin(time * 7 + i * 2.3);
    final base = at(i);
    if (i.isEven) {
      char.addPath(
        vfxBlob(
          base,
          max(band * 0.55, radius / sqrt(n) * 0.7),
          i * 2.7,
          n: 9,
          wobble: 0.25,
          squash: 0.6,
        ),
        ui.Offset.zero,
      );
    }
    final h = band * (0.75 + 0.55 * vfxHash(i * 1.3)) * lick;
    // A drop's round head is its base and its tail the flame's tip, so it
    // points down to stand up.
    final lean = pi / 2 + sin(time * 2.2 + i) * 0.18;
    body.addPath(vfxDrop(base, h * 0.45, lean), ui.Offset.zero);
    hot.addPath(
      vfxDrop(base + ui.Offset(0, -h * 0.06), h * 0.24, lean),
      ui.Offset.zero,
    );
  }
  vfxFillPath(canvas, char, m.ink, 0.55 * a);
  vfxFillPath(canvas, body, m.mid, 0.8 * a);
  vfxFillPath(canvas, hot, m.glint, 0.8 * a);
  if (details) {
    // Embers lifting off the field.
    for (var i = 0; i < n; i++) {
      final ph = (time * 0.7 + vfxHash(i * 3.9)) % 1.0;
      final p = at(i) + ui.Offset(sin(i + time) * 3, -band * (0.9 + ph * 1.8));
      vfxGrain(p.dx, p.dy);
    }
    vfxGrainsFlush(canvas, max(1.4, band * 0.09), m.glint, 0.7 * a);
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
//  Survival's, lifted verbatim so open space draws the same thing: the pieces
//  a live beam is painted as each frame, the particles it sheds into
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

/// The life a beam piece carries. A live beam's pieces are painted straight
/// from the game's live beams each frame, so this only matters for the
/// short-lived pieces that do go into a beam list (a charge's swell and
/// micro-arcs).
const double kWingBeamFxLife = 0.08;

/// Spirit's cable into the ship: a little narrower, and it lingers.
const double kWingTetherCableWidthScale = 0.85;
const double kWingTetherCableLife = 0.12;

/// The white-green core a healing beam carries (not Water's or Crystal's).
const double kWingHealCoreWidthScale = 0.45;
const ui.Color kWingHealCoreColor = ui.Color(0xFFEFFFF1);

/// Lightning's blast: the bolt's afterglow along the line, a little wider
/// than the beam and in its own material, fading in a quarter second. (It was
/// a 3.4× white flash: a snap, against the flowy-not-bursty rule.)
const double kWingLightningBlastWidthScale = 1.7;
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

/// A live line beam holds full strength and fades over its last 0.35 s.
/// Every game paints its live beams once a frame at this strength, straight
/// from its list of live beams.
double wingBeamFade(double life) =>
    life < 0.35 ? (life / 0.35).clamp(0.0, 1.0) : 1.0;

/// The pieces one live beam is painted as this frame, from [origin] to
/// [end]: each game's render pass calls this for every live, firing beam and
/// paints what [segment] receives once, at [wingBeamFade] strength. A ring
/// draws nothing here (its perimeter is painted in the render pass); a
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
      _healCoreTint,
      d.width * kWingHealCoreWidthScale,
      kWingBeamFxLife,
      null,
    );
  }
}

/// The heal core as a live beam lays it.
final ui.Color _healCoreTint = kWingHealCoreColor.withValues(alpha: 0.85);

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
    elementColor('Lightning'),
    descriptor.width * kWingLightningBlastWidthScale,
    kWingLightningBlastLife,
    'Lightning',
  );
}

/// A Wing+Plant flower waiting to be collected ([life] counts down from
/// 12 s): a flower of lit grains — five clumps of green grains for petals,
/// each its own length, round a few warm ones — over a soft pool of light,
/// breathing slowly, dimming in a pulse once it is close to wilting.
/// Survival's pickup art, which its Kin+Plant garden drops share. Three
/// draws.
void drawWingFlowerPickup({
  required ui.Canvas canvas,
  required ui.Offset position,
  required double life,
  required double bobPhase,
  required double time,
}) {
  final t = time;
  final m = vfxMaterial('Plant');
  final bob = sin(t * 2.4 + bobPhase) * 1.6;
  final pos = ui.Offset(position.dx, position.dy + bob);
  final fade = (life / 12.0).clamp(0.0, 1.0);
  final lifePulse = life < 3.0 ? 0.7 + 0.3 * sin(t * 8) : 1.0;
  final breathe = 1 + 0.08 * sin(t * 1.6 + bobPhase);
  vfxSpill(canvas, pos, 16, ui.Color.lerp(m.light, elementColor('Plant'), 0.3)!,
      0.3 * fade);
  for (var i = 0; i < 5; i++) {
    final a = i * (pi * 2 / 5) + t * 0.12 + bobPhase;
    final reach = (0.85 + 0.3 * vfxHash(i * 2.1 + bobPhase)) * breathe;
    // A petal is a small clump: two grains side by side, one beyond.
    for (final (da, d) in const [(-0.32, 4.4), (0.32, 4.4), (0.0, 6.6)]) {
      final p = pos + vfxPolar(a + da, d * reach);
      vfxGrain(p.dx, p.dy);
    }
  }
  vfxGrainsFlush(
    canvas,
    3.0,
    ui.Color.lerp(m.glint, elementColor('Plant'), 0.35)!,
    0.9 * fade * lifePulse,
  );
  final heart = vfxMaterial('Light');
  for (var k = 0; k < 3; k++) {
    final p = pos + vfxPolar(k * 2.1 + t * 0.3, 1.2);
    vfxGrain(p.dx, p.dy);
  }
  vfxGrainsFlush(canvas, 2.8, vfxFlare(heart), 0.9 * fade * lifePulse);
}
