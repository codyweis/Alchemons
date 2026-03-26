import 'package:flutter/material.dart';

class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({
    super.key,
    required this.onDirectionChanged,
    this.sizeMultiplier = 1.0,
  });

  /// Called with a normalised direction (magnitude 0-1), or null when released.
  final ValueChanged<Offset?> onDirectionChanged;
  final double sizeMultiplier;

  @override
  State<VirtualJoystick> createState() => VirtualJoystickState();
}

class VirtualJoystickState extends State<VirtualJoystick> {
  static const double _defaultBaseRadius = 52;
  static const double _defaultKnobRadius = 20;

  Offset _knobOffset = Offset.zero;
  bool _active = false;

  double get _baseRadius => _defaultBaseRadius * widget.sizeMultiplier;
  double get _knobRadius => _defaultKnobRadius * widget.sizeMultiplier;

  void _handlePointer(Offset localPos) {
    final center = Offset(_baseRadius, _baseRadius);
    var delta = localPos - center;
    final dist = delta.distance;
    if (dist > _baseRadius - _knobRadius) {
      delta = delta / dist * (_baseRadius - _knobRadius);
    }
    setState(() {
      _knobOffset = delta;
      _active = true;
    });
    // Normalise: magnitude 0 – 1
    final norm = delta / (_baseRadius - _knobRadius);
    widget.onDirectionChanged(norm);
  }

  void _handleRelease() {
    setState(() {
      _knobOffset = Offset.zero;
      _active = false;
    });
    widget.onDirectionChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) => _handlePointer(d.localPosition),
      onPanUpdate: (d) => _handlePointer(d.localPosition),
      onPanEnd: (_) => _handleRelease(),
      onPanCancel: _handleRelease,
      child: SizedBox(
        width: _baseRadius * 2,
        height: _baseRadius * 2,
        child: CustomPaint(
          painter: _JoystickPainter(
            knobOffset: _knobOffset,
            active: _active,
            baseRadius: _baseRadius,
            knobRadius: _knobRadius,
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({
    required this.knobOffset,
    required this.active,
    required this.baseRadius,
    required this.knobRadius,
  });

  final Offset knobOffset;
  final bool active;
  final double baseRadius;
  final double knobRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(baseRadius, baseRadius);

    // Outer ring
    canvas.drawCircle(
      center,
      baseRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: active ? 0.12 : 0.06)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      baseRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: active ? 0.25 : 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Direction guides (subtle cross)
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx, center.dy - baseRadius + 8),
      Offset(center.dx, center.dy + baseRadius - 8),
      guidePaint,
    );
    canvas.drawLine(
      Offset(center.dx - baseRadius + 8, center.dy),
      Offset(center.dx + baseRadius - 8, center.dy),
      guidePaint,
    );

    // Knob
    final knobCenter = center + knobOffset;
    // Glow
    if (active) {
      canvas.drawCircle(
        knobCenter,
        knobRadius + 6,
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    // Fill
    canvas.drawCircle(
      knobCenter,
      knobRadius,
      Paint()
        ..color = active
            ? const Color(0xFF00E5FF).withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.15),
    );
    // Border
    canvas.drawCircle(
      knobCenter,
      knobRadius,
      Paint()
        ..color = active
            ? const Color(0xFF00E5FF).withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_JoystickPainter old) =>
      old.knobOffset != knobOffset ||
      old.active != active ||
      old.baseRadius != baseRadius ||
      old.knobRadius != knobRadius;
}

// ─────────────────────────────────────────────────────────
// COSMIC PARTY PICKER OVERLAY
// ─────────────────────────────────────────────────────────
