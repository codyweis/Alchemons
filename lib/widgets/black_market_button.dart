import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/widgets/animations/floating_particle.dart';
import 'package:flutter/material.dart';

class AnimatedBlackMarketButton extends StatefulWidget {
  final bool isOpen;
  final Color accent;
  final VoidCallback onTap;

  /// The square the button takes up; the stall picture is drawn at 80% of it.
  final double size;

  const AnimatedBlackMarketButton({
    super.key,
    required this.isOpen,
    required this.accent,
    required this.onTap,
    this.size = 75,
  });

  @override
  State<AnimatedBlackMarketButton> createState() =>
      AnimatedBlackMarketButtonState();
}

class AnimatedBlackMarketButtonState extends State<AnimatedBlackMarketButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Use a smooth curve for seamless pulsing
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut, // Smooth in and out
      ),
    );

    if (widget.isOpen) {
      _pulseController.repeat(reverse: true); // Key change: reverse: true
    }
  }

  @override
  void didUpdateWidget(AnimatedBlackMarketButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: context.soundAction(widget.onTap),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final pulse = widget.isOpen ? _pulseAnimation.value : 1.0;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Glow effect when open
              if (widget.isOpen)
                Positioned.fill(
                  child: Transform.scale(
                    scale: pulse * 1.15,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B4789).withValues(
                              alpha:
                                  0.4 *
                                  (pulse - 1.0) /
                                  0.08, // Smooth opacity change
                            ),
                            blurRadius: widget.size * 0.4,
                            spreadRadius: widget.size * 0.13,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Main button
              Transform.scale(
                scale: pulse,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Button image
                      Center(
                        child: Image.asset(
                          widget.isOpen
                              ? 'assets/images/ui/blackmarketicon.png'
                              : 'assets/images/ui/blackmarketofficon.png',
                          width: widget.size * 0.8,
                          height: widget.size * 0.8,
                        ),
                      ),

                      // Particle effects when open
                      if (widget.isOpen) ...[
                        for (int i = 0; i < 3; i++)
                          FloatingParticle(
                            controller: _pulseController,
                            index: i,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
