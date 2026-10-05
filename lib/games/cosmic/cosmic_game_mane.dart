part of 'cosmic_game.dart';

/// Mane in open space: what a cast becomes beyond the shared table — Light's
/// ward, Spirit's stream, Lightning's scatter — and what its catapults shed,
/// on Cosmic Survival's rules (mane_runtime.dart). What each element does to
/// the bodies it pierces is in the ability pass (cosmic_game_ability_pass.dart).
extension CosmicMane on CosmicGame {
  /// Reshapes a Mane cast in place. [currentStack] is the caster's counter:
  /// Light's growth, Spirit's stream length.
  void _applyOpenManeSpecialRuntime({
    required CosmicPartyMember member,
    required List<Projectile> projectiles,
    required Offset origin,
    required double angle,
    required int currentStack,
    required void Function(int stack) setStack,
  }) {
    if (member.family.toLowerCase() != 'mane' || projectiles.isEmpty) return;
    switch (member.element) {
      case 'Light':
        // Nothing is thrown: the cast hangs the next ring of the ward, or
        // feeds one once all are turning.
        final template = projectiles.first;
        projectiles.clear();
        final result = ManeLightWard.cast(
          rings: ManeLightWard.rings(companionProjectiles, member.slotIndex),
          ringCap: maneLightRingCount(
            max(0.5, member.statBeauty.toDouble()),
            potential: member.statBeautyPotential,
          ),
          growth: currentStack,
          casterPos: origin,
          casterAngle: angle,
          template: template,
          slot: member.slotIndex,
        );
        setStack(result.growth);
        final hung = result.hung;
        final fed = result.fed;
        if (hung != null) {
          companionProjectiles.add(hung);
          _spawnHitSpark(origin, elementColor('Light'));
        } else if (fed != null) {
          emitDetonationBurst(
            center: fed.position,
            color: elementColor('Light'),
            radius: result.burstRadius,
            rng: _rng,
            hasRoom: _kinVfxHasRoom,
            emit: _abilityVfx.add,
          );
        }
      case 'Spirit':
        final (stream, next) = ManeRuntime.spiritStream(
          projectiles.first,
          angle,
          currentStack,
          member.slotIndex,
        );
        projectiles
          ..clear()
          ..addAll(stream);
        setStack(next);
      case 'Lightning':
        final orbs = ManeRuntime.lightningOrbs(
          projectiles.first,
          casterPos: origin,
          angle: angle,
          // Round what the cast protects: the ship (the wild one itself on
          // its side of a duel).
          scatterCenter: ship.pos,
          scatterRadius: max(
            220.0,
            min(520.0, max(size.x, size.y) / max(0.7, _currentZoom) * 0.42),
          ),
          rng: _rng,
          clamp: (p) => Offset(
            p.dx.clamp(64.0, world_.worldSize.width - 64.0).toDouble(),
            p.dy.clamp(64.0, world_.worldSize.height - 64.0).toDouble(),
          ),
          slot: member.slotIndex,
        );
        projectiles
          ..clear()
          ..addAll(orbs);
    }
  }

  /// A Lightning orb flying to its landing point, where it blooms into a
  /// shock field. True while it is one (it takes no other movement).
  bool _updateOpenManeLightningOrbTransfer(Projectile p, double dt) {
    final step = ManeRuntime.lightningOrbStep(p, dt);
    if (step == null) return false;
    final landed = step.landedAt;
    if (landed != null) {
      onSound?.call(SoundCue.specialManeOrbLand);
      companionProjectiles.add(ManeRuntime.lightningShockField(p, landed));
      _spawnHitSpark(landed, elementColor('Lightning'));
    }
    return true;
  }

  /// Earth's fault slab leaves a quake burst as it breaks.
  void _spawnOpenManeEarthQuakePulse(Projectile source) {
    final pulse = ManeRuntime.earthQuakePulse(source, _rng);
    onSound?.call(SoundCue.specialManeQuake);
    companionProjectiles.add(pulse);
    _spawnHitSpark(pulse.position, elementColor('Earth'));
  }

  /// Dark's void bolt drags every body within its snare toward itself, every
  /// frame it flies.
  void _pullOpenManeDark(Projectile bolt, double dt) {
    final radius = bolt.snareRadius;
    for (final enemy in enemies) {
      if (enemy.dead) continue;
      final step = ManeRuntime.darkPullStep(
        bolt.position,
        enemy.position,
        radius,
        dt,
      );
      if (step != null) enemy.position = enemy.position + step;
    }
  }
}
