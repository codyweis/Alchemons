// --- Particle overlay you can call from anywhere ---
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

class ParticleBurstGame extends FlameGame {
  final Offset origin;
  final Color color;
  ParticleBurstGame({required this.origin, required this.color});
  @override
  Color backgroundColor() => Colors.transparent;
  @override
  Future<void> onLoad() async {
    final center = Vector2(origin.dx, origin.dy);
    add(
      ParticleSystemComponent(
        position: center,
        particle: Particle.generate(
          count: 140,
          lifespan: 0.9,
          generator: (i) => AcceleratedParticle(
            acceleration: Vector2(0, 700),
            speed: (Vector2.random()..scale(380))..rotate(i * 0.02),
            child: CircleParticle(radius: 2, paint: Paint()..color = color),
          ),
        ),
      ),
    );

    // Auto dispose after the burst finishes
    Future.delayed(const Duration(milliseconds: 950), () {
      overlays.remove('burst');
      pauseEngine();
    });
  }
}

class ParticleOverlay extends StatefulWidget {
  final Widget child;
  const ParticleOverlay({super.key, required this.child});

  // Expose a helper so children can trigger bursts via context.findAncestorStateOfType
  static void trigger(BuildContext context, TapUpDetails d, Color color) {
    context.findAncestorStateOfType<_ParticleOverlayState>()?.burstAtTap(
      d,
      color,
    );
  }

  @override
  State<ParticleOverlay> createState() => _ParticleOverlayState();
}

class _ParticleOverlayState extends State<ParticleOverlay> {
  FlameGame? _game;
  final _overlayKey = GlobalKey();

  void burstAtTap(TapUpDetails d, Color color) {
    final box = _overlayKey.currentContext!.findRenderObject() as RenderBox;
    final local = box.globalToLocal(d.globalPosition);
    setState(() {
      _game = ParticleBurstGame(origin: local, color: color);
    });
    // GameWidget cleans itself: we null it after a tick
    Future.delayed(
      const Duration(milliseconds: 1000),
      () => setState(() => _game = null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _overlayKey,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (d) {}, // keep gestures free for children
          child: widget.child,
        ),
        if (_game != null)
          Positioned.fill(
            child: IgnorePointer(child: GameWidget(game: _game!)),
          ),
      ],
    );
  }
}
