import 'package:flutter/material.dart';

/// Lightweight startup surface used while the app finishes expensive work.
///
/// Keep this deliberately simple: it must remain cheap to paint while catalog
/// parsing and the first builds of the main navigation screens are happening.
class AlchemonsSplash extends StatelessWidget {
  const AlchemonsSplash({super.key, required this.status, this.progress});

  final String status;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE7C56A);
    final normalizedProgress = progress?.clamp(0.0, 1.0);

    // MaterialApp's `home:` supplies no Material ancestor -- only Scaffold
    // does -- so Text here fell back to the debug style and drew itself with
    // yellow underlines. Transparency paints nothing, so the splash stays as
    // cheap as it needs to be.
    return Material(
      type: MaterialType.transparency,
      child: AbsorbPointer(
        child: ColoredBox(
          color: const Color(0xFF05080D),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.12),
                radius: 0.9,
                colors: [
                  Color(0xFF17313A),
                  Color(0xFF090E14),
                  Color(0xFF030507),
                ],
                stops: [0, 0.58, 1],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/ui/alchemonstitle.png',
                          width: 360,
                          filterQuality: FilterQuality.medium,
                        ),
                        const SizedBox(height: 34),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: normalizedProgress,
                            minHeight: 3,
                            backgroundColor: Colors.white12,
                            color: gold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            status,
                            key: ValueKey(status),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
