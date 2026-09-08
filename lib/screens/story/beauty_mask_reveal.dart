import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A finite, deterministic dissolve of the familiar valley over the live planet.
/// The underlying game stays paused until both story cards are acknowledged.
class BeautyMaskReveal extends StatefulWidget {
  const BeautyMaskReveal({super.key, required this.onComplete});
  final Future<void> Function() onComplete;
  @override
  State<BeautyMaskReveal> createState() => _BeautyMaskRevealState();
}

class _BeautyMaskRevealState extends State<BeautyMaskReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dissolve;
  int _page = 0;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _dissolve = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
  }

  @override
  void dispose() {
    _dissolve.dispose();
    super.dispose();
  }

  Future<void> advance() async {
    if (_saving || _dissolve.isAnimating) return;
    if (_page == 0) {
      setState(() => _page = 1);
      if (MediaQuery.of(context).disableAnimations) {
        _dissolve.value = 1;
      } else {
        await _dissolve.forward();
      }
      if (mounted) setState(() {});
    } else if (_page == 1) {
      setState(() => _page = 2);
    } else {
      setState(() {
        _saving = true;
        _error = null;
      });
      try {
        await widget.onComplete();
      } catch (_) {
        if (mounted) {
          setState(() {
            _saving = false;
            _error = 'Could not save this memory. Tap to retry.';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: _dissolve,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            if (_dissolve.value < 1)
              ClipPath(
                clipper: _ValleyDissolve(_dissolve.value),
                child: RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Color(0xFF9AAED0)),
                      for (final layer in [
                        'sky',
                        'clouds',
                        'backhills',
                        'hills',
                        'foreground',
                      ])
                        Image.asset(
                          'assets/images/backgrounds/scenes/valley/$layer.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stack) =>
                              const SizedBox.shrink(),
                        ),
                    ],
                  ),
                ),
              ),
            if (_dissolve.isAnimating)
              IgnorePointer(
                child: CustomPaint(painter: _MaskDust(_dissolve.value)),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      color: const Color(0xED080B10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _page == 0
                                ? 'Beauty Obstructs Reality'
                                : _page == 1
                                ? 'AM I DREAMING?'
                                : 'A memory speaks',
                            style: const TextStyle(
                              color: Color(0xFFE4C16A),
                              fontSize: 22,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _page == 0
                                ? 'The valley is here, where it cannot be.'
                                : _page == 1
                                ? 'No, I am finally awake.'
                                : 'You did not make the valley to hide the world from danger. You made it to hide your work from yourself.',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_error != null)
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                              ),
                            ),
                          const SizedBox(height: 12),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFE4C16A),
                              disabledForegroundColor: Colors.white54,
                            ),
                            onPressed: _dissolve.isAnimating || _saving
                                ? null
                                : advance,
                            child: Text(
                              _page == 0
                                  ? 'Look closer'
                                  : _saving
                                  ? 'Remembering…'
                                  : 'Continue',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

double _threshold(int x, int y) =>
    ((x * 73 + y * 151 + x * y * 19) % 997) / 997;

class _ValleyDissolve extends CustomClipper<Path> {
  _ValleyDissolve(this.t);
  final double t;
  @override
  Path getClip(Size size) {
    final path = Path();
    for (var y = 0; y < 18; y++) {
      for (var x = 0; x < 32; x++) {
        final threshold = _threshold(x, y) * 0.7;
        final fraction = (1 - (t - threshold) / 0.3).clamp(0.0, 1.0);
        if (fraction <= 0) continue;
        path.addRect(
          Rect.fromCenter(
            center: Offset(
              (x + .5) * size.width / 32,
              (y + .5) * size.height / 18,
            ),
            width: (size.width / 32 + 1) * fraction,
            height: (size.height / 18 + 1) * fraction,
          ),
        );
      }
    }
    return path;
  }

  @override
  bool shouldReclip(_ValleyDissolve old) => old.t != t;
}

class _MaskDust extends CustomPainter {
  _MaskDust(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var y = 0; y < 18; y++) {
      for (var x = 0; x < 32; x++) {
        final age = t - _threshold(x, y) * .7;
        if (age < 0 || age > .3) continue;
        paint.color = const Color(
          0xFFBFC8A0,
        ).withValues(alpha: (1 - age / .3) * .75);
        canvas.drawCircle(
          Offset(
            (x + .5) * size.width / 32 + math.sin(x + y.toDouble()) * age * 160,
            (y + .5) * size.height / 18 - age * 120,
          ),
          1 + age * 9,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MaskDust old) => old.t != t;
}
