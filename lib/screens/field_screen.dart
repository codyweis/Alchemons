// lib/screens/field_screen.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/harvest_screen.dart';
import 'package:alchemons/screens/map_screen.dart';
import 'package:flutter/material.dart';

class FieldScreen extends StatefulWidget {
  const FieldScreen({super.key, this.onOpenExpeditions, this.onOpenHarvest});

  /// If you already have screens wired, pass callbacks.
  /// Otherwise, this screen will fall back to Navigator.pushNamed.
  final VoidCallback? onOpenExpeditions;
  final VoidCallback? onOpenHarvest;

  @override
  State<FieldScreen> createState() => _FieldScreenState();
}

class _FieldScreenState extends State<FieldScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bgCtrl;
  late final AnimationController _enterCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  void _goExpeditions() {
    if (widget.onOpenExpeditions != null) {
      widget.onOpenExpeditions!();
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MapScreen()));
    }
  }

  void _goHarvest() {
    if (widget.onOpenHarvest != null) {
      widget.onOpenHarvest!();
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const HarvestScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Field Operations',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .6),
        ),
      ),
      body: Stack(
        children: [
          // Animated particle/line backdrop
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (context, _) {
                return CustomPaint(
                  painter: _FieldBackdropPainter(progress: _bgCtrl.value),
                );
              },
            ),
          ),

          // Glass content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final children = [
                    // Expeditions
                    FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _enterCtrl,
                        curve: const Interval(0.0, .7, curve: Curves.easeOut),
                      ),
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, .15),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _enterCtrl,
                                curve: const Interval(
                                  0.0,
                                  .7,
                                  curve: Curves.easeOut,
                                ),
                              ),
                            ),
                        child: _ActionCard(
                          title: 'Expeditions',
                          subtitle: 'Send a team on a mission',
                          icon: Icons.explore_rounded,
                          primary: const Color(0xFF5B8CFF), // blue
                          accent: const Color(0xFF9BB7FF),
                          onTap: _goExpeditions,
                        ),
                      ),
                    ),

                    // Resource Harvesting
                    FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _enterCtrl,
                        curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
                      ),
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, .18),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _enterCtrl,
                                curve: const Interval(
                                  0.25,
                                  1.0,
                                  curve: Curves.easeOut,
                                ),
                              ),
                            ),
                        child: _ActionCard(
                          title: 'Resource Harvesting',
                          subtitle: 'Gather field materials & samples',
                          icon: Icons.agriculture_rounded,
                          primary: const Color(0xFF2ED49A), // teal/green
                          accent: const Color(0xFF96F2C7),
                          onTap: _goHarvest,
                        ),
                      ),
                    ),
                  ];

                  return isWide
                      ? Row(
                          children: [
                            Expanded(child: children[0]),
                            const SizedBox(width: 14),
                            Expanded(child: children[1]),
                          ],
                        )
                      : Column(
                          children: [
                            children[0],
                            const SizedBox(height: 14),
                            children[1],
                          ],
                        );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A glassy, animated action card with subtle float, tilt on press,
/// and a sweeping gloss line that loops.
class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primary,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color primary;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard>
    with TickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final AnimationController _shineCtrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _shineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glass = _Glass(
      borderColor: widget.primary.withOpacity(.75),
      background: Colors.white.withOpacity(.05),
      child: Stack(
        children: [
          // Rotating “orbit” rings (subtle)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _floatCtrl,
              builder: (context, _) {
                return CustomPaint(
                  painter: _OrbitRingsPainter(
                    t: _floatCtrl.value,
                    color: widget.primary.withOpacity(.25),
                  ),
                );
              },
            ),
          ),

          // Shine sweep
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _shineCtrl,
              builder: (context, _) {
                final p = _shineCtrl.value;
                return Opacity(
                  opacity: .35,
                  child: ShaderMask(
                    blendMode: BlendMode.srcATop,
                    shaderCallback: (rect) {
                      final dx = rect.width * (p * 1.4 - .2); // -0.2..1.2
                      return LinearGradient(
                        begin: Alignment(-1 + p * 2, -1),
                        end: Alignment(1 + p * 2, 1),
                        colors: [
                          Colors.transparent,
                          widget.accent.withOpacity(.6),
                          Colors.transparent,
                        ],
                        stops: const [0.35, 0.5, 0.65],
                      ).createShader(
                        Rect.fromLTWH(dx, 0, rect.width * .25, rect.height),
                      );
                    },
                    child: Container(color: Colors.white),
                  ),
                );
              },
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _IconBadge(icon: widget.icon, color: widget.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Color(0xFFE8EAED),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.75),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(text: 'Open', color: widget.primary),
                          _Pill(text: 'Field Ops', color: widget.accent),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: widget.accent,
                  size: 22,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: _floatCtrl,
      builder: (_, __) {
        // gentle float & scale
        final dy = math.sin(_floatCtrl.value * 2 * math.pi) * 4.0;
        final scale = _pressed ? 0.98 : 1.0;

        return Transform.translate(
          offset: Offset(0, dy),
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) {
                setState(() => _pressed = false);
                widget.onTap();
              },
              child: glass,
            ),
          ),
        );
      },
    );
  }
}

/// Simple glass container with glow border
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    required this.borderColor,
    required this.background,
  });

  final Widget child;
  final Color borderColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor.withOpacity(.55), width: 2),
            boxShadow: [
              BoxShadow(
                color: borderColor.withOpacity(.35),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(.35), Colors.transparent],
          radius: .8,
        ),
        border: Border.all(color: color.withOpacity(.7), width: 2),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.5)),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFE8EAED),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
        ),
      ),
    );
  }
}

/// Background painter: subtle moving particles + faint curves
class _FieldBackdropPainter extends CustomPainter {
  _FieldBackdropPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0B0F14);
    canvas.drawRect(Offset.zero & size, bg);

    // Soft vignette
    final vignette =
        RadialGradient(
          colors: [Colors.white.withOpacity(.02), Colors.transparent],
        ).createShader(
          Rect.fromCircle(
            center: size.center(Offset.zero),
            radius: size.shortestSide,
          ),
        );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = vignette
        ..blendMode = BlendMode.plus,
    );

    // Curvy lines
    final pathPaint = Paint()
      ..color = Colors.white.withOpacity(.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 0; i < 3; i++) {
      final p = Path();
      final amp = 18.0 + i * 10;
      final speed = (progress + i * .15) * 2 * math.pi;
      for (double x = 0; x <= size.width; x += 12) {
        final y =
            size.height * (0.25 + i * .25) +
            math.sin((x / size.width * 3 * math.pi) + speed) * amp;
        if (x == 0) {
          p.moveTo(x, y);
        } else {
          p.lineTo(x, y);
        }
      }
      canvas.drawPath(p, pathPaint);
    }

    // Floating particles
    final dot = Paint()..color = Colors.white.withOpacity(.08);
    final n = 36;
    for (var i = 0; i < n; i++) {
      final t = (progress + i / n) % 1.0;
      final x = (size.width * (i / n) + t * size.width) % size.width;
      final y = (size.height * (0.2 + (i % 5) * 0.15)) % size.height; // rows
      final r = 1.2 + math.sin((t + i) * 2 * math.pi) * .8;
      canvas.drawCircle(Offset(x, y), r, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _FieldBackdropPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Decorative orbit rings inside each card
class _OrbitRingsPainter extends CustomPainter {
  _OrbitRingsPainter({required this.t, required this.color});
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide * .36;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color;

    // Two orbits slowly rotating with different radii
    for (int i = 0; i < 2; i++) {
      final angle = (t + i * .2) * 2 * math.pi;
      final path = Path();
      for (double a = 0; a <= 2 * math.pi; a += .06) {
        final rr = r * (1 + .06 * math.sin(3 * a + angle));
        final x = center.dx + rr * math.cos(a + angle);
        final y = center.dy + rr * math.sin(a + angle);
        if (a == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint..color = color.withOpacity(.18 + i * .08));
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitRingsPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}
