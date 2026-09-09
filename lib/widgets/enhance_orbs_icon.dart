import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:flutter/material.dart';

/// The Enhance dock icon: the four Power Orbs, drawn in the same chunky
/// gold-outlined style as the painted icons around it.
///
/// Painted rather than shipped as another megabyte of PNG. The four orbs
/// already have canonical colours on [AlchemicalPowerupType] — the same ones
/// the tray, the shop and the inventory use — so drawing the icon from them
/// means it can never drift from the things it stands for, and it stays sharp
/// at whatever size the dock asks for.
class EnhanceOrbsIcon extends StatelessWidget {
  const EnhanceOrbsIcon({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: const _EnhanceOrbsPainter(),
      ),
    );
  }
}

class _EnhanceOrbsPainter extends CustomPainter {
  const _EnhanceOrbsPainter();

  // The gold the rest of the dock icons are outlined in, lit from the top
  // left the way they are.
  static const _goldLight = Color(0xFFF7D27A);
  static const _goldMid = Color(0xFFE0A231);
  static const _goldDeep = Color(0xFF9A5D12);

  /// The dark the illustrated icons bottom out in, used for the far side of
  /// each orb so they read as glass rather than flat discs.
  static const _deepShade = Color(0xFF2A1236);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;

    final c = Offset(size.width / 2, size.height / 2);
    final r = s * 0.187;
    // Tighter than the orbs are wide, so the cluster closes over the middle
    // instead of leaving a hole there. Scaled with the radius — pull them
    // apart independently and the hole comes back.
    final spread = s * 0.172;
    final stroke = s * 0.020;

    // Clockwise from the top, in enum order, so the cluster is laid out the
    // same way the tray lists them.
    final centres = <Offset>[
      c + Offset(0, -spread), // speed
      c + Offset(spread, 0), // intelligence
      c + Offset(0, spread), // strength
      c + Offset(-spread, 0), // beauty
    ];

    // Back to front, so the near orbs overlap the far ones the way a cluster
    // of spheres does. Every shadow goes down first — drawn per-orb they
    // would fall across the neighbour instead of the ground.
    const order = <int>[0, 3, 1, 2];

    final shadow = Paint()..color = const Color(0x4D000000);
    for (final i in order) {
      canvas.drawCircle(
        centres[i] + Offset(0, s * 0.024),
        r + stroke * 0.5,
        shadow,
      );
    }

    for (final i in order) {
      _orb(canvas, centres[i], r, stroke, AlchemicalPowerupType.values[i]);
    }
  }

  void _orb(
    Canvas canvas,
    Offset centre,
    double r,
    double stroke,
    AlchemicalPowerupType type,
  ) {
    final bounds = Rect.fromCircle(center: centre, radius: r);

    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.38, -0.42),
          radius: 1.0,
          colors: [
            Colors.white,
            type.color,
            Color.lerp(type.color, _deepShade, 0.62)!,
          ],
          stops: const [0.0, 0.44, 1.0],
        ).createShader(bounds),
    );

    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_goldLight, _goldMid, _goldDeep],
          stops: [0.0, 0.42, 1.0],
        ).createShader(bounds.inflate(stroke)),
    );

    // A single tilted catchlight. Two would read as a reflection of nothing.
    canvas.save();
    canvas.translate(centre.dx - r * 0.36, centre.dy - r * 0.42);
    canvas.rotate(-0.62);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: r * 0.66,
        height: r * 0.40,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.80),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EnhanceOrbsPainter oldDelegate) => false;
}
