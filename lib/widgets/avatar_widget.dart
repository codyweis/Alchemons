// ============================================================================
// HELPER WIDGETS (unchanged from previous version)
// ============================================================================

import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';

class AvatarButton extends StatefulWidget {
  final FactionTheme theme;
  final VoidCallback onTap;
  const AvatarButton({super.key, required this.theme, required this.onTap});

  @override
  State<AvatarButton> createState() => _AvatarButtonState();
}

class _AvatarButtonState extends State<AvatarButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: -5,
      end: 5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('assets/images/ui/profileicon.png'),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
