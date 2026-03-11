// lib/games/wilderness/rift_portal_component.dart
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

// ── Faction definitions ───────────────────────────────────────────────────────

enum RiftFaction { volcanic, oceanic, verdant, earthen, arcane }

extension RiftFactionExt on RiftFaction {
  String get displayName {
    final n = name;
    return n[0].toUpperCase() + n.substring(1);
  }

  /// Primary accent color (particles, glow, border)
  Color get primaryColor => switch (this) {
    RiftFaction.volcanic => const Color(0xFFFF5722),
    RiftFaction.oceanic => const Color(0xFF2196F3),
    RiftFaction.verdant => const Color(0xFF4CAF50),
    RiftFaction.earthen => const Color(0xFFFF8F00),
    RiftFaction.arcane => const Color(0xFFCE93D8),
  };

  /// Very dark core color
  Color get coreColor => switch (this) {
    RiftFaction.volcanic => const Color(0xFF1A0500),
    RiftFaction.oceanic => const Color(0xFF000D1A),
    RiftFaction.verdant => const Color(0xFF001A08),
    RiftFaction.earthen => const Color(0xFF1A0A00),
    RiftFaction.arcane => const Color(0xFF0D0015),
  };

  /// The faction string as stored on CreatureInstance.variantFaction
  String get factionKey => switch (this) {
    RiftFaction.volcanic => 'Volcanic',
    RiftFaction.oceanic => 'Oceanic',
    RiftFaction.verdant => 'Verdant',
    RiftFaction.earthen => 'Earthen',
    RiftFaction.arcane => 'Arcane',
  };

  /// Creature base types that count as compatible with this rift.
  Set<String> get matchingTypes => switch (this) {
    RiftFaction.volcanic => {'Fire', 'Lava', 'Steam', 'Blood'},
    RiftFaction.oceanic => {'Water', 'Ice'},
    RiftFaction.verdant => {'Air', 'Plant', 'Light'},
    RiftFaction.earthen => {'Earth', 'Mud', 'Crystal', 'Dust'},
    RiftFaction.arcane => {'Dark', 'Spirit', 'Lightning', 'Poison'},
  };

  /// Factions that may spawn in a given scene.
  /// Each faction is locked to its matching biome.
  /// Arcane rift only appears in the arcane biome.
  /// No rift portals spawn in the arcane biome.
  static List<RiftFaction> allowedForScene(String sceneId) {
    return switch (sceneId) {
      'valley' => [RiftFaction.earthen],
      'swamp' => [RiftFaction.oceanic],
      'volcano' => [RiftFaction.volcanic],
      'sky' => [RiftFaction.verdant],
      'arcane' => [RiftFaction.arcane],
      _ => <RiftFaction>[],
    };
  }

  /// Pick a random faction valid for [sceneId]. Returns null if none allowed.
  static RiftFaction? randomForScene(String sceneId, [Random? rng]) {
    final pool = allowedForScene(sceneId);
    if (pool.isEmpty) return null;
    final r = rng ?? Random();
    return pool[r.nextInt(pool.length)];
  }

  static RiftFaction random([Random? rng]) {
    final r = rng ?? Random();
    return RiftFaction.values[r.nextInt(RiftFaction.values.length)];
  }
}

// ── Orbiting particle data ─────────────────────────────────────────────────────

class _Particle {
  double angle;
  double radius;
  final double speed; // radians/sec
  final double size;
  final double opacity;

  _Particle({
    required this.angle,
    required this.radius,
    required this.speed,
    required this.size,
    required this.opacity,
  });
}

// ── Flame component ───────────────────────────────────────────────────────────

class RiftPortalComponent extends PositionComponent with TapCallbacks {
  final RiftFaction faction;
  final VoidCallback onTap;

  /// Optional world-position callback.
  ///
  /// If provided, the portal will follow this position each frame.
  /// If null, the portal remains at its spawn world position.
  final Vector2 Function()? positionProvider;

  double _time = 0;
  late final List<_Particle> _particles;
  final Random _rng = Random();
  final double _coreRadius;

  static const int _particleCount = 24;

  RiftPortalComponent({
    required Vector2 position,
    required this.faction,
    required this.onTap,
    this.positionProvider,
    double radius = 36,
  }) : _coreRadius = radius,
       super(
         position: position,
         size: Vector2.all(radius * 5.0),
         anchor: Anchor.center,
         priority: 200,
       ) {
    _particles = List.generate(_particleCount, (i) {
      final baseR = (_coreRadius * 0.9) + _rng.nextDouble() * _coreRadius * 0.8;
      return _Particle(
        angle: (i / _particleCount) * pi * 2,
        radius: baseR,
        speed: 0.3 + _rng.nextDouble() * 0.9,
        size: 1.2 + _rng.nextDouble() * 2.8,
        opacity: 0.45 + _rng.nextDouble() * 0.55,
      );
    });
  }

  @override
  void update(double dt) {
    _time += dt;
    for (final p in _particles) {
      p.angle += p.speed * dt;
    }
    // Only follow an external provider when explicitly configured.
    final provider = positionProvider;
    if (provider != null) {
      position = provider();
    }
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final r = _coreRadius;
    final pulse = 0.88 + 0.12 * sin(_time * 2.5);
    final color = faction.primaryColor;

    // ── Outer ambient glow ───────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      r * 2.6,
      Paint()
        ..color = color.withValues(alpha: 0.07 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32),
    );

    // ── Mid glow ────────────────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      r * 1.7,
      Paint()
        ..color = color.withValues(alpha: 0.14 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // ── Accretion disk (flat ellipse, save/restore for squash)  ─────────────
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(1.0, 0.28);
    final diskRect = Rect.fromCenter(
      center: Offset.zero,
      width: r * 3.0,
      height: r * 3.0,
    );
    canvas.drawOval(
      diskRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.55 * pulse),
            color.withValues(alpha: 0),
          ],
          stops: const [0.45, 0.68, 1.0],
        ).createShader(diskRect),
    );
    canvas.restore();

    // ── Event horizon ────────────────────────────────────────────────────────
    final coreRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: r * 2,
      height: r * 2,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r * pulse,
      Paint()
        ..shader = RadialGradient(
          colors: [faction.coreColor, faction.coreColor, Colors.black],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(coreRect),
    );

    // ── Orbiting spark particles ─────────────────────────────────────────────
    for (final p in _particles) {
      final px = cx + cos(p.angle) * p.radius;
      final py = cy + sin(p.angle) * p.radius * 0.42;
      canvas.drawCircle(
        Offset(px, py),
        p.size * pulse,
        Paint()
          ..color = color.withValues(alpha: p.opacity * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
      );
    }

    // ── Inward spiral arms ────────────────────────────────────────────────────
    final spiralPaint = Paint()
      ..color = color.withValues(alpha: 0.28 * pulse)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    for (int arm = 0; arm < 3; arm++) {
      final startA = _time * 1.6 + (arm * pi * 2 / 3);
      final path = Path();
      bool first = true;
      for (double t = 0.05; t <= 1.0; t += 0.04) {
        final sr = r * t * 0.95;
        final sa = startA - t * pi * 3.0;
        final px = cx + cos(sa) * sr;
        final py = cy + sin(sa) * sr * 0.42;
        if (first) {
          path.moveTo(px, py);
          first = false;
        } else {
          path.lineTo(px, py);
        }
      }
      canvas.drawPath(path, spiralPaint);
    }

    // ── Rim highlight arc ─────────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      r * pulse,
      Paint()
        ..color = color.withValues(alpha: 0.22 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  void onTapDown(TapDownEvent event) => onTap();
}
