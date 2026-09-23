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
    Paint()
      ..shader = Gradient.radial(
        center,
        580,
        [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.035 * alpha),
          color.withValues(alpha: 0.23 * alpha * breath),
        ],
        const [0.2, 0.58, 1],
      ),
  );
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
  final pen = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
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

  void stroke(Path path, double opacity, double width, {bool glow = false}) {
    if (glow && !reducedDetail) {
      canvas.drawPath(
        path,
        pen
          ..strokeWidth = width * 4 + 3
          ..color = color.withValues(alpha: opacity * alpha * 0.12),
      );
    }
    canvas.drawPath(
      path,
      pen
        ..strokeWidth = width
        ..color = color.withValues(alpha: opacity * alpha),
    );
  }

  void oval(Offset p, double w, double h, double opacity, {bool fill = false}) {
    canvas.drawOval(
      Rect.fromCenter(center: p, width: w, height: h),
      Paint()
        ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: opacity * alpha),
    );
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
        final path = Path()
          ..moveTo(ember.dx, ember.dy + 13)
          ..quadraticBezierTo(
            ember.dx - 7,
            ember.dy + 4,
            ember.dx + sin(t * 2 + i) * 4,
            ember.dy - 8,
          );
        stroke(path, 0.48 * (1 - phase), 1.4, glow: true);
        oval(ember, 3, 4, 0.75 * (1 - phase), fill: true);
      case 'Lava':
        final path = Path()
          ..moveTo(p.dx - 38, p.dy + 18)
          ..lineTo(p.dx - 12, p.dy + 8)
          ..lineTo(p.dx + 2, p.dy + 13)
          ..lineTo(p.dx + 19, p.dy - 9)
          ..lineTo(p.dx + 43, p.dy - 13);
        stroke(path, 0.42 + 0.13 * sin(t * 0.7 + i), 2.1, glow: true);
        stroke(
          Path()
            ..moveTo(p.dx + 2, p.dy + 13)
            ..lineTo(p.dx + 10, p.dy + 31),
          0.3,
          1,
        );
      case 'Water':
        final drop = p.translate(phase * 25, phase * 80 - 40);
        stroke(
          Path()
            ..moveTo(drop.dx, drop.dy)
            ..lineTo(drop.dx + 9, drop.dy + 28),
          0.30,
          1,
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
          Path()
            ..moveTo(x - 95, p.dy + 12)
            ..quadraticBezierTo(
              x,
              p.dy - 28 - sin(t + i) * 10,
              x + 65,
              p.dy - 12,
            ),
          0.24 * sin(phase * pi),
          1.1,
        );
        stroke(
          Path()
            ..moveTo(x - 40, p.dy + 20)
            ..quadraticBezierTo(x + 20, p.dy - 1, x + 90, p.dy),
          0.12,
          0.7,
        );
      case 'Lightning':
        final pulse = pow(max(0.0, sin(t * 0.9 + i * 2.3)), 12).toDouble();
        final path = Path()
          ..moveTo(p.dx - 30, p.dy - 30)
          ..lineTo(p.dx - 6, p.dy - 8)
          ..lineTo(p.dx - 16, p.dy - 2)
          ..lineTo(p.dx + 17, p.dy + 17)
          ..lineTo(p.dx + 11, p.dy + 25);
        stroke(path, 0.06 + pulse * 0.52, 1.2, glow: true);
        stroke(
          Path()
            ..moveTo(p.dx - 6, p.dy - 8)
            ..lineTo(p.dx + 18, p.dy - 15),
          pulse * 0.28,
          0.7,
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
        final path = Path()
          ..moveTo(p.dx - 40, p.dy + 28)
          ..cubicTo(
            p.dx - 10,
            p.dy + 16,
            p.dx - 20,
            p.dy - 16,
            p.dx + 27,
            p.dy - 27,
          );
        stroke(path, 0.27, 2.4);
        for (var k = 0; k < 3; k++) {
          final x = p.dx - 20 + k * 13;
          stroke(
            Path()
              ..moveTo(x, p.dy + 10 - k * 10)
              ..quadraticBezierTo(
                x + 15,
                p.dy + 14 - k * 10,
                x + 19,
                p.dy + 4 - k * 10,
              ),
            0.25,
            1,
          );
        }
        oval(p.translate(22, -24), 2, 3, 0.35 + 0.15 * sin(t + i), fill: true);
      case 'Poison':
        oval(p, 75, 27, 0.055, fill: true);
        final bubble = p.translate(sin(t + i) * 5, -phase * 24);
        oval(bubble, 9 + phase * 12, 10 + phase * 14, 0.28 * sin(phase * pi));
        oval(p.translate(24, 9), 32, 8, 0.15);
      case 'Spirit':
        final head = p.translate(sin(t * 0.4 + i) * 14, -phase * 30);
        stroke(
          Path()
            ..moveTo(head.dx, head.dy)
            ..cubicTo(
              head.dx - 16,
              head.dy + 16,
              head.dx + 18,
              head.dy + 24,
              head.dx - 8,
              head.dy + 51,
            ),
          0.19,
          2.0,
          glow: true,
        );
        oval(head, 3, 8, 0.43, fill: true);
      case 'Dark':
        final toward = center - p;
        final dir = toward / toward.distance;
        final side = Offset(-dir.dy, dir.dx);
        stroke(
          Path()
            ..moveTo(p.dx, p.dy)
            ..quadraticBezierTo(
              p.dx + dir.dx * 50 + side.dx * 25,
              p.dy + dir.dy * 50 + side.dy * 25,
              p.dx + dir.dx * 85,
              p.dy + dir.dy * 85,
            ),
          0.18,
          1.2,
        );
        final mote = p + dir * phase * 75;
        oval(mote, 3, 3, 0.35 * sin(phase * pi), fill: true);
      case 'Blood':
        final pulse = 0.7 + 0.3 * pow(max(0.0, sin(t * 1.3)), 6);
        stroke(
          Path()
            ..moveTo(p.dx, p.dy - 33)
            ..lineTo(p.dx + 5, p.dy - 9)
            ..lineTo(p.dx - 3, p.dy + 8)
            ..lineTo(p.dx + 8, p.dy + 34),
          0.32 * pulse,
          1.4,
        );
        stroke(
          Path()
            ..moveTo(p.dx + 5, p.dy - 9)
            ..lineTo(p.dx + 22, p.dy - 18),
          0.22 * pulse,
          0.9,
        );
        oval(
          p.translate(3, phase * 48 - 15),
          2.5,
          5,
          0.35 * sin(phase * pi),
          fill: true,
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
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(width, height);
    canvas.drawCircle(
      Offset.zero,
      1,
      Paint()
        ..shader = Gradient.radial(Offset.zero, 1, [
          color.withValues(alpha: opacity * alpha),
          color.withValues(alpha: 0),
        ]),
    );
    canvas.restore();
  }

  void line(Path path, double opacity, double width) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width
        ..color = color.withValues(alpha: opacity * alpha),
    );
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
              Paint()..color = color.withValues(alpha: alpha * 0.3),
            );
          }
        }
      case 'Light':
        haze(Offset(drift, -24), span * 1.8, 135, 0.18);
        // A partly buried corona: uneven fragments, no clock ticks or circles.
        for (var j = 0; j < (reduced ? 2 : 4); j++) {
          final x = -span + j * span * 0.55;
          final y = 26 + noise(j + side * 11) * 22;
          line(
            Path()
              ..moveTo(x, y)
              ..quadraticBezierTo(
                x + 35,
                y + 13,
                x + 65 + noise(j + 80) * 35,
                y - 5,
              ),
            0.10 + 0.07 * sin(time * 0.35 + j),
            1.3,
          );
          haze(Offset(x + 30, y), 65, 14, 0.10);
        }
      case 'Ice':
        haze(const Offset(0, 0), span * 1.4, 95, 0.16);
        for (var j = 0; j < (reduced ? 5 : 9); j++) {
          final x = (noise(j + side * 17) - 0.5) * span * 2;
          final reach = 35 + noise(j + 42) * 85;
          final bend = x + (noise(j + 66) - 0.5) * 55;
          final tip = Offset(bend + noise(j + 81) * 28 - 14, reach);
          line(
            Path()
              ..moveTo(x, 0)
              ..lineTo(bend, reach * 0.54)
              ..lineTo(tip.dx, tip.dy),
            0.13 + noise(j + 15) * 0.13,
            0.8,
          );
          line(
            Path()
              ..moveTo(bend, reach * 0.54)
              ..lineTo(bend - 13 - noise(j + 31) * 20, reach * 0.73),
            0.12,
            0.6,
          );
          haze(tip, 18, 10, 0.035);
        }
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
          final face = Path()
            ..moveTo(x - w * 0.3, -25)
            ..lineTo(x + w, 3)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(x - w * 0.2, h * 0.57)
            ..close();
          canvas.drawPath(
            face,
            Paint()
              ..shader = Gradient.linear(Offset(x, -15), Offset(x, h), [
                color.withValues(alpha: alpha * (crystal ? 0.13 : 0.10)),
                color.withValues(alpha: alpha * 0.015),
              ]),
          );
          // Only one exposed seam catches light; the rest sinks into shadow.
          line(
            Path()
              ..moveTo(x + w, 3)
              ..lineTo(tip.dx, tip.dy)
              ..lineTo(tip.dx - w * 0.22, tip.dy - h * 0.12),
            crystal ? 0.17 + 0.09 * sin(time * 0.4 + j + side) : 0.12,
            0.8,
          );
          if (crystal) haze(tip, 25, 16, 0.045);
        }
    }
    canvas.restore();
  }
}
