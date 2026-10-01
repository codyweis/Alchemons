// lib/games/wilderness/rift_portal_component.dart
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:alchemons/widgets/fx/rift_vortex.dart';
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

// ── Flame component ───────────────────────────────────────────────────────────

/// A rift out in the wilderness: the same grain vortex its threshold opens
/// on ([RiftVortexField]), small, over a dark tear in the sky.
///
/// It used to be blurred glows, blurred sparks and stroked spiral arms —
/// some 27 blur passes a frame for as long as a rift was on screen.
class RiftPortalComponent extends PositionComponent with TapCallbacks {
  final RiftFaction faction;
  final VoidCallback onTap;

  /// Optional world-position callback.
  ///
  /// If provided, the portal will follow this position each frame.
  /// If null, the portal remains at its spawn world position.
  final Vector2 Function()? positionProvider;

  final double _coreRadius;

  /// Fewer grains than the threshold's: it is a corner of a busy scene.
  final RiftVortexField _field = RiftVortexField(
    grains: 460,
    ringGrains: 110,
    motes: 26,
    core: 0.27,
  );
  late final RiftPalette _palette = RiftPalette(faction.primaryColor);

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
       );

  @override
  void update(double dt) {
    // Tears open when it appears, as the threshold does.
    _field.open = min(1.0, _field.open + dt / 1.4);
    _field.step(dt);
    // Only follow an external provider when explicitly configured.
    final provider = positionProvider;
    if (provider != null) {
      position = provider();
    }
  }

  @override
  void render(Canvas canvas) {
    _field.paint(
      canvas,
      Size(size.x, size.y),
      Offset(size.x / 2, size.y / 2),
      _coreRadius * 2.4,
      _palette,
      backdrop: false,
    );
  }

  @override
  void onTapDown(TapDownEvent event) => onTap();
}
