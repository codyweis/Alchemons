import 'dart:math';

import 'package:flutter/foundation.dart';
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

  /// Knob offset, or null at rest. Drives the painter directly: a drag
  /// repaints the joystick's own layer and never rebuilds a widget.
  final ValueNotifier<Offset?> _knob = ValueNotifier(null);

  double get _baseRadius => _defaultBaseRadius * widget.sizeMultiplier;
  double get _knobRadius => _defaultKnobRadius * widget.sizeMultiplier;

  void _handlePointer(Offset localPos) {
    final center = Offset(_baseRadius, _baseRadius);
    var delta = localPos - center;
    final dist = delta.distance;
    if (dist > _baseRadius - _knobRadius) {
      delta = delta / dist * (_baseRadius - _knobRadius);
    }
    _knob.value = delta;
    // Normalise: magnitude 0 – 1
    final norm = delta / (_baseRadius - _knobRadius);
    widget.onDirectionChanged(norm);
  }

  void _handleRelease() {
    _knob.value = null;
    widget.onDirectionChanged(null);
  }

  @override
  void dispose() {
    _knob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) => _handlePointer(d.localPosition),
      onPanUpdate: (d) => _handlePointer(d.localPosition),
      onPanEnd: (_) => _handleRelease(),
      onPanCancel: _handleRelease,
      child: RepaintBoundary(
        child: SizedBox(
          width: _baseRadius * 2,
          height: _baseRadius * 2,
          child: CustomPaint(
            painter: _JoystickPainter(
              knob: _knob,
              baseRadius: _baseRadius,
              knobRadius: _knobRadius,
            ),
          ),
        ),
      ),
    );
  }
}

/// A dark glass lens with a glass bead in it. The lens's limb catches a
/// little light instead of being outlined; four short marks at the compass
/// points stand in for the old cross. The bead is pale glass at rest and
/// lit amber while it is held.
class _JoystickPainter extends CustomPainter {
  _JoystickPainter({
    required this.knob,
    required this.baseRadius,
    required this.knobRadius,
  }) : super(repaint: knob);

  final ValueListenable<Offset?> knob;
  final double baseRadius;
  final double knobRadius;

  static const _amber = Color(0xFFE4B356);
  static final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(baseRadius, baseRadius);
    final active = knob.value != null;
    final r = baseRadius;

    // The lens: dark glass, its limb lit.
    _p.shader = RadialGradient(
      colors: [
        const Color(0xFF0B0B10).withValues(alpha: active ? 0.62 : 0.48),
        const Color(0xFF0B0B10).withValues(alpha: active ? 0.55 : 0.4),
        const Color(0xFF3A3A48).withValues(alpha: active ? 0.5 : 0.32),
        const Color(0xFF3A3A48).withValues(alpha: 0),
      ],
      stops: const [0.0, 0.8, 0.95, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, _p);
    _p.shader = null;

    // Compass marks: short tapered slivers just inside the limb.
    _p.color = (active ? _amber : const Color(0xFF9A93A6)).withValues(
      alpha: active ? 0.55 : 0.3,
    );
    for (var k = 0; k < 4; k++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(k * pi / 2);
      final path = Path()
        ..moveTo(0, -r + 4)
        ..lineTo(2.2, -r + 11)
        ..lineTo(-2.2, -r + 11)
        ..close();
      canvas.drawPath(path, _p);
      canvas.restore();
    }

    // The bead.
    final at = center + (knob.value ?? Offset.zero);
    if (active) {
      _p.shader = RadialGradient(
        colors: [_amber.withValues(alpha: 0.22), _amber.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: at, radius: knobRadius * 1.9));
      canvas.drawCircle(at, knobRadius * 1.9, _p);
    }
    final lit = active ? _amber : const Color(0xFFB8B2C2);
    _p.shader = RadialGradient(
      center: const Alignment(-0.35, -0.45),
      colors: [
        Color.lerp(
          lit,
          Colors.white,
          0.45,
        )!.withValues(alpha: active ? 0.95 : 0.5),
        lit.withValues(alpha: active ? 0.75 : 0.28),
        const Color(0xFF14141B).withValues(alpha: active ? 0.9 : 0.6),
      ],
      stops: const [0.0, 0.4, 1.0],
    ).createShader(Rect.fromCircle(center: at, radius: knobRadius));
    canvas.drawCircle(at, knobRadius, _p);
    _p.shader = null;
  }

  @override
  bool shouldRepaint(_JoystickPainter old) =>
      old.knob != knob ||
      old.baseRadius != baseRadius ||
      old.knobRadius != knobRadius;
}
