import 'package:flutter/material.dart';

class AlchemyGlow extends StatefulWidget {
  final double size;
  const AlchemyGlow({super.key, required this.size});

  @override
  State<AlchemyGlow> createState() => _AlchemyGlowState();
}

class _AlchemyGlowState extends State<AlchemyGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubicEmphasized,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: widget.size * 2, // Make glow larger than sprite
            height: widget.size * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.cyan.withOpacity(0.3),
                  Colors.purple.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
