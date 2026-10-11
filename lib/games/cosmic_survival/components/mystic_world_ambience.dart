import 'package:alchemons/games/cosmic/vfx_shapes.dart';
import 'dart:math';
import 'dart:ui';

/// Atmospheric ink, kept separate from combat colors and hit indicators.
const mysticAtmosphereColors = <String, Color>{
  'Fire': Color(0xFFD69554),
  'Lava': Color(0xFFC45B36),
  'Water': Color(0xFF638E9F),
  'Ice': Color(0xFFA0BCC8),
  'Steam': Color(0xFF9CA9A5),
  'Air': Color(0xFF8EAAA9),
  'Lightning': Color(0xFF9B9DC6),
  'Earth': Color(0xFF9C8664),
  'Mud': Color(0xFF82715A),
  'Dust': Color(0xFFBAA17E),
  'Crystal': Color(0xFFB7AAC9),
  'Plant': Color(0xFF879B74),
  'Poison': Color(0xFFA5A569),
  'Spirit': Color(0xFFA3B2C5),
  'Dark': Color(0xFF827297),
  'Light': Color(0xFFD6B975),
  'Blood': Color(0xFFAE5862),
};

// One paint for the whole ambience, and its gradients built once per colour
// and drawn through a transform: nothing here allocates a Paint or a Gradient
// per frame. A shader's strength rides on the paint's alpha.
final Paint _ambPaint = Paint();
final Map<int, Shader> _ambWashShaders = {};
final Map<int, Shader> _ambHazeShaders = {};
final Map<int, Shader> _ambFaceShaders = {};

/// The edge wash in the 1000 x 650 frame, at full strength (scaled by the
/// paint's alpha).
Shader _ambWash(Color color) =>
    _ambWashShaders[color.toARGB32()] ??= Gradient.radial(
      const Offset(500, 325),
      580,
      [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0.035 / 0.23),
        color.withValues(alpha: 1),
      ],
      const [0.2, 0.58, 1],
    );

/// A unit soft spot: full colour at the centre, nothing at radius 1.
Shader _ambHaze(Color color) => _ambHazeShaders[color.toARGB32()] ??=
    Gradient.radial(Offset.zero, 1, [color, color.withValues(alpha: 0)]);

/// A unit top-to-bottom fade for a formation face, y 0 → 1.
Shader _ambFace(Color color, bool crystal) =>
    _ambFaceShaders[color.toARGB32() * 2 + (crystal ? 1 : 0)] ??=
        Gradient.linear(const Offset(0, 0), const Offset(0, 1), [
          color.withValues(alpha: crystal ? 0.13 : 0.10),
          color.withValues(alpha: 0.015),
        ]);

void _ambFill(Canvas canvas, Path path, Color color, double alpha) {
  if (alpha <= 0.004) return;
  canvas.drawPath(
    path,
    _ambPaint
      ..shader = null
      ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0)),
  );
}

/// Stateless and bounded: no particles, blurs or offscreen layers are allocated.
/// Drawn behind the arena. Detail stays near the edges; the center stays clear.
void drawMysticWorldAmbience({
  required Canvas canvas,
  required Rect viewport,
  required String element,
  required double time,
  required double strength,
  int seed = 0,
  bool reducedDetail = false,
}) {
  final color = mysticAtmosphereColors[element];
  if (color == null || strength <= 0 || viewport.isEmpty) return;
  final alpha = strength.clamp(0.0, 1.0);
  final t = time + seed * 1.73;
  final breath = 0.9 + 0.1 * sin(t * 0.6);
  canvas.save();
  canvas.clipRect(viewport);
  canvas.translate(viewport.left, viewport.top);
  canvas.scale(viewport.width / 1000, viewport.height / 650);
  const bounds = Rect.fromLTWH(0, 0, 1000, 650);
  const center = Offset(500, 325);
  canvas.drawRect(
    bounds,
    _ambPaint
      ..shader = _ambWash(color)
      ..color = Color.fromRGBO(255, 255, 255, 0.23 * alpha * breath),
  );
  _ambPaint.shader = null;
  // Broad material formations grow in from the boundary, rather than floating
  // repeated elemental symbols around the player.
  if (const {
    'Ice',
    'Earth',
    'Crystal',
    'Light',
    'Steam',
    'Dust',
  }.contains(element)) {
    _drawEdgeFormations(canvas, color, element, t, alpha, seed, reducedDetail);
    canvas.restore();
    return;
  }
  final count = switch (element) {
    'Steam' || 'Dust' => reducedDetail ? 4 : 8,
    _ => reducedDetail ? 10 : 20,
  };
  double noise(int i) => (sin(i * 127.1 + seed * 17.7) * 43758.5453) % 1;
  Offset edge(int i) {
    final along = noise(i + 3);
    final inset = 18 + noise(i + 41) * 90;
    return switch (i % 4) {
      0 => Offset(along * 1000, inset),
      1 => Offset(1000 - inset, along * 650),
      2 => Offset(along * 1000, 650 - inset),
      _ => Offset(inset, along * 650),
    };
  }

  // A flick, streak or arc along [spine]: a filled lens ribbon about twice
  // the old stroke width at its middle, tapering to points. [glow] lays a
  // wide faint ribbon under it.
  void stroke(
    List<Offset> spine,
    double opacity,
    double width, {
    bool glow = false,
    double taper = 0.5,
    double? taperEnd,
  }) {
    if (glow && !reducedDetail) {
      _ambFill(
        canvas,
        vfxLensRibbon(spine, width * 4 + 3, taper: taper, taperEnd: taperEnd),
        color,
        opacity * alpha * 0.12,
      );
    }
    _ambFill(
      canvas,
      vfxLensRibbon(spine, width * 2, taper: taper, taperEnd: taperEnd),
      color,
      opacity * alpha,
    );
  }

  // A filled oval, or — where an outline used to be — its rim as a lit
  // crescent along the near side and a thinner one along the far side: a
  // ripple or bubble edge, never a hoop.
  void oval(Offset p, double w, double h, double opacity, {bool fill = false}) {
    if (fill) {
      if (opacity * alpha <= 0.004) return;
      canvas.drawOval(
        Rect.fromCenter(center: p, width: w, height: h),
        _ambPaint
          ..shader = null
          ..color = color.withValues(alpha: opacity * alpha),
      );
      return;
    }
    final near = min(2.2, max(0.8, h * 0.35));
    final rim = vfxEllipseCrescent(p, w / 2, h / 2, near, pi / 2, 2.4);
    vfxEllipseCrescent(p, w / 2, h / 2, near * 0.55, -pi / 2, 1.7, into: rim);
    _ambFill(canvas, rim, color, opacity * alpha);
  }

  for (var i = 0; i < count; i++) {
    final p = edge(i);
    final n = noise(i + 12);
    final phase = (t * 0.12 + n) % 1;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    final variation = 0.75 + n * 0.5;
    canvas.scale(variation);
    if (const {
      'Lava',
      'Ice',
      'Earth',
      'Crystal',
      'Plant',
      'Blood',
      'Light',
    }.contains(element)) {
      canvas.rotate((n - 0.5) * 1.3);
    }
    canvas.translate(-p.dx, -p.dy);
    switch (element) {
      case 'Fire':
        final ember = p.translate(sin(t + i) * 9, -phase * 60);
        // A flame lick rising off the ember: broad below, a point on top.
        stroke(
          vfxQuadSpine(
            Offset(ember.dx, ember.dy + 13),
            Offset(ember.dx - 7, ember.dy + 4),
            Offset(ember.dx + sin(t * 2 + i) * 4, ember.dy - 8),
            n: 6,
          ),
          0.48 * (1 - phase),
          1.4,
          glow: true,
          taper: 0.3,
          taperEnd: 0.7,
        );
        oval(ember, 3, 4, 0.75 * (1 - phase), fill: true);
      case 'Lava':
        // A glowing seam in dark rock — filled and tapered, not a scribble.
        final seam = [
          for (var k = 0; k <= 6; k++)
            Offset(
              p.dx - 40 + 82 * k / 6,
              p.dy + 16 - 28 * k / 6 + sin(k / 6 * pi) * 5 * (n - 0.5),
            ),
        ];
        final heat = 0.6 + 0.25 * sin(t * 0.7 + i);
        vfxFillPath(
          canvas,
          vfxRibbon(seam, 7, 1),
          const Color(0xFF1A0804),
          0.7 * alpha,
        );
        vfxFillPath(
          canvas,
          vfxRibbon(seam, 2.4, 0.4),
          color,
          heat * 0.7 * alpha,
        );
      case 'Water':
        final drop = p.translate(phase * 25, phase * 80 - 40);
        // A falling streak, heavier at its leading end.
        stroke(
          vfxPolylineSpine([drop, drop.translate(9, 28)], perSegment: 5),
          0.30,
          1,
          taper: 0.7,
          taperEnd: 0.3,
        );
        if (i.isEven) {
          oval(
            p.translate(0, 28),
            12 + phase * 45,
            4 + phase * 13,
            0.24 * (1 - phase),
          );
        }
      case 'Air':
        final x = p.dx + phase * 75 - 35;
        stroke(
          vfxQuadSpine(
            Offset(x - 95, p.dy + 12),
            Offset(x, p.dy - 28 - sin(t + i) * 10),
            Offset(x + 65, p.dy - 12),
            n: 10,
          ),
          0.24 * sin(phase * pi),
          1.1,
        );
        stroke(
          vfxQuadSpine(
            Offset(x - 40, p.dy + 20),
            Offset(x + 20, p.dy - 1),
            Offset(x + 90, p.dy),
            n: 10,
          ),
          0.12,
          0.7,
        );
      case 'Lightning':
        final pulse = pow(max(0.0, sin(t * 0.9 + i * 2.3)), 12).toDouble();
        // A discharge writhing down through its corners, not a zig-zag glyph.
        stroke(
          vfxCurveSpine([
            Offset(p.dx - 30, p.dy - 30),
            Offset(p.dx - 6, p.dy - 8),
            Offset(p.dx - 16, p.dy - 2),
            Offset(p.dx + 17, p.dy + 17),
            Offset(p.dx + 11, p.dy + 25),
          ]),
          0.06 + pulse * 0.52,
          1.2,
          glow: true,
        );
        stroke(
          vfxPolylineSpine([
            Offset(p.dx - 6, p.dy - 8),
            Offset(p.dx + 18, p.dy - 15),
          ], perSegment: 4),
          pulse * 0.28,
          0.7,
          taper: 0.2,
          taperEnd: 0.8,
        );
      case 'Mud':
        oval(p, 70 + n * 30, 19, 0.08, fill: true);
        oval(p.translate(4, 1), 48 + sin(t * 0.5 + i) * 8, 11, 0.20);
        oval(
          p.translate(-10, -3),
          3 + phase * 10,
          2 + phase * 5,
          0.30 * (1 - phase),
        );
      case 'Plant':
        // A creeper: a tapered stem with leaves along it.
        final stem = [
          for (var k = 0; k <= 8; k++)
            Offset(
              p.dx - 40 + 67 * k / 8,
              p.dy + 28 - 55 * k / 8 + sin(k * 0.9 + i) * 6,
            ),
        ];
        vfxFillPath(canvas, vfxRibbon(stem, 4, 0.6), color, 0.3 * alpha);
        for (var k = 2; k <= 6; k += 2) {
          final side = k % 4 == 0 ? 1.0 : -1.0;
          vfxFillPath(
            canvas,
            vfxLeaf(stem[k], 11, -pi / 4 + side * 0.9 + sin(t + i + k) * 0.1),
            color,
            0.32 * alpha,
          );
        }
      case 'Poison':
        oval(p, 75, 27, 0.055, fill: true);
        final bubble = p.translate(sin(t + i) * 5, -phase * 24);
        oval(bubble, 9 + phase * 12, 10 + phase * 14, 0.28 * sin(phase * pi));
        oval(p.translate(24, 9), 32, 8, 0.15);
      case 'Spirit':
        // A soul drifting up with a veil trailing under it.
        final head = p.translate(sin(t * 0.4 + i) * 14, -phase * 30);
        final veil = [
          for (var k = 0; k <= 6; k++)
            head + Offset(sin(t * 2 + k * 0.9 + i) * 5 * k / 6, 48 * k / 6),
        ];
        final fade = sin(phase * pi).clamp(0.2, 1.0);
        vfxFillPath(
          canvas,
          vfxRibbon(veil, 9, 0.5),
          color,
          0.18 * fade * alpha,
        );
        vfxFillPath(
          canvas,
          vfxDrop(head, 3.5, pi / 2),
          color,
          0.5 * fade * alpha,
        );
      case 'Dark':
        // Shadow drawn in toward the middle, and a mote falling with it.
        final toward = center - p;
        final dir = toward / toward.distance;
        final side = Offset(-dir.dy, dir.dx);
        final wisp = [
          for (var k = 0; k <= 6; k++)
            p + dir * (85 * k / 6) + side * (sin(k / 6 * pi) * 22),
        ];
        vfxFillPath(canvas, vfxRibbon(wisp, 5, 0.5), color, 0.16 * alpha);
        final mote = p + dir * phase * 75;
        oval(mote, 3, 3, 0.35 * sin(phase * pi), fill: true);
      case 'Blood':
        // A vein pulsing, with a drop running down it.
        final pulse = 0.7 + 0.3 * pow(max(0.0, sin(t * 1.3)), 6);
        final vein = [
          Offset(p.dx, p.dy - 33),
          Offset(p.dx + 5, p.dy - 9),
          Offset(p.dx - 3, p.dy + 8),
          Offset(p.dx + 8, p.dy + 34),
        ];
        vfxFillPath(
          canvas,
          vfxRibbon(vein, 4.5, 0.8),
          color,
          0.3 * pulse * alpha,
        );
        vfxFillPath(
          canvas,
          vfxDrop(p.translate(3, phase * 48 - 15), 2.6, pi / 2),
          color,
          0.5 * sin(phase * pi) * alpha,
        );
    }
    canvas.restore();
  }
  canvas.restore();
}

/// Local x follows the boundary and local y points into the arena.
void _drawEdgeFormations(
  Canvas canvas,
  Color color,
  String element,
  double time,
  double alpha,
  int seed,
  bool reduced,
) {
  double noise(int i) => (sin(i * 127.1 + seed * 17.7) * 43758.5453) % 1;
  void haze(Offset at, double width, double height, double opacity) {
    if (opacity * alpha <= 0.004) return;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(width, height);
    canvas.drawCircle(
      Offset.zero,
      1,
      _ambPaint
        ..shader = _ambHaze(color)
        ..color = Color.fromRGBO(255, 255, 255, (opacity * alpha).clamp(0, 1)),
    );
    canvas.restore();
    _ambPaint.shader = null;
  }

  // Veins, seams and corona fragments: lens ribbons gathered into one path
  // per side and filled once, instead of a stroked hairline each.
  final seams = Path();
  final spine = <Offset>[];
  void seam(List<Offset> corners, double width, {bool curve = false}) {
    spine.clear();
    if (curve) {
      vfxQuadSpine(corners[0], corners[1], corners[2], n: 8, into: spine);
    } else {
      vfxPolylineSpine(corners, into: spine);
    }
    vfxLensRibbon(spine, width, taper: 0.4, into: seams);
  }

  void flushSeams(double opacity) {
    _ambFill(canvas, seams, color, opacity * alpha);
    seams.reset();
  }

  for (var side = 0; side < 4; side++) {
    canvas.save();
    switch (side) {
      case 1:
        canvas.translate(1000, 0);
        canvas.rotate(pi / 2);
      case 2:
        canvas.translate(1000, 650);
        canvas.rotate(pi);
      case 3:
        canvas.translate(0, 650);
        canvas.rotate(-pi / 2);
    }
    final length = side.isEven ? 1000.0 : 650.0;
    final origin = length * (0.25 + noise(side + 10) * 0.5);
    canvas.translate(origin, -12);
    final drift = sin(time * 0.18 + side) * 18;
    final span = 150 + noise(side + 30) * 110;
    switch (element) {
      case 'Steam':
      case 'Dust':
        for (var j = 0; j < (reduced ? 3 : 6); j++) {
          final n = noise(side * 19 + j + 70);
          haze(
            Offset((n - 0.5) * span * 2 + drift, 15 + noise(j + 90) * 48),
            span * (0.65 + n),
            element == 'Steam' ? 55 + n * 45 : 24 + n * 30,
            element == 'Steam' ? 0.10 : 0.08,
          );
          if (element == 'Dust') {
            canvas.drawCircle(
              Offset((n - 0.5) * span * 2 + drift * 2, 20 + noise(j + 21) * 65),
              0.7 + n,
              _ambPaint
                ..shader = null
                ..color = color.withValues(alpha: alpha * 0.3),
            );
          }
        }
      case 'Light':
        haze(Offset(drift, -24), span * 1.8, 135, 0.18);
        // A partly buried corona: uneven fragments, no clock ticks or circles.
        // Each fragment breathes by swelling, since they share one fill.
        for (var j = 0; j < (reduced ? 2 : 4); j++) {
          final x = -span + j * span * 0.55;
          final y = 26 + noise(j + side * 11) * 22;
          seam(
            [
              Offset(x, y),
              Offset(x + 35, y + 13),
              Offset(x + 65 + noise(j + 80) * 35, y - 5),
            ],
            3.2 * (0.75 + 0.35 * sin(time * 0.35 + j)),
            curve: true,
          );
          haze(Offset(x + 30, y), 65, 14, 0.10);
        }
        flushSeams(0.15);
      case 'Ice':
        haze(const Offset(0, 0), span * 1.4, 95, 0.16);
        for (var j = 0; j < (reduced ? 5 : 9); j++) {
          final x = (noise(j + side * 17) - 0.5) * span * 2;
          final reach = 35 + noise(j + 42) * 85;
          final bend = x + (noise(j + 66) - 0.5) * 55;
          final tip = Offset(bend + noise(j + 81) * 28 - 14, reach);
          // Frost veins: brighter ones are simply broader.
          seam(
            [Offset(x, 0), Offset(bend, reach * 0.54), tip],
            2.0 * (0.7 + noise(j + 15) * 0.8),
          );
          seam([
            Offset(bend, reach * 0.54),
            Offset(bend - 13 - noise(j + 31) * 20, reach * 0.73),
          ], 1.4);
          haze(tip, 18, 10, 0.035);
        }
        flushSeams(0.17);
      case 'Earth':
      case 'Crystal':
        final crystal = element == 'Crystal';
        haze(const Offset(0, 0), span * 1.4, 90, 0.09);
        for (var j = 0; j < (reduced ? 3 : 5); j++) {
          final x = (j / 4 - 0.5) * span * 1.7;
          final n = noise(j + side * 23 + 9);
          final w = 45 + n * 85;
          final h = 28 + noise(j + side * 13 + 40) * (crystal ? 88 : 52);
          final tip = Offset(x + w * (0.15 + n * 0.5), h);
          // The face's light fades from y = -15 down to the tip. It is drawn
          // in a frame where that span is 0 → 1, so one cached unit gradient
          // serves every face.
          final span01 = h + 15;
          double ny(double y) => (y + 15) / span01;
          final face = Path()
            ..moveTo(x - w * 0.3, ny(-25))
            ..lineTo(x + w, ny(3))
            ..lineTo(tip.dx, ny(tip.dy))
            ..lineTo(x - w * 0.2, ny(h * 0.57))
            ..close();
          canvas.save();
          canvas.translate(0, -15);
          canvas.scale(1, span01);
          canvas.drawPath(
            face,
            _ambPaint
              ..shader = _ambFace(color, crystal)
              ..color = Color.fromRGBO(255, 255, 255, alpha),
          );
          canvas.restore();
          _ambPaint.shader = null;
          // Only one exposed seam catches light; the rest sinks into shadow.
          seam(
            [
              Offset(x + w, 3),
              tip,
              Offset(tip.dx - w * 0.22, tip.dy - h * 0.12),
            ],
            crystal ? 2.0 * (0.8 + 0.4 * sin(time * 0.4 + j + side)) : 1.8,
          );
          if (crystal) haze(tip, 25, 16, 0.045);
        }
        flushSeams(crystal ? 0.19 : 0.13);
    }
    canvas.restore();
  }
}
