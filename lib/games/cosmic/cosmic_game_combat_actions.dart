part of 'cosmic_game.dart';

/// What a fighting Alchemon does on its own turn — a blessing's heal, a basic
/// attack, a special — pulled out of the party's update so the wild Alchemon
/// it duels runs the very same code. (A Horn's ram, wind-up and brew are in
/// cosmic_game_horn.dart.) Where a cast lands, and who counts as friend or
/// foe, is decided by the side it resolves on (see cosmic_game_duel.dart),
/// not here.
extension CosmicCombatActions on CosmicGame {
  /// A blessing heals over time, in whole points.
  void _tickCompanionBlessing(CosmicCompanion comp, double dt) {
    if (comp.isBlessing) {
      comp.blessingTimer -= dt;
      comp.currentHp = min(
        comp.maxHp,
        comp.currentHp + comp.takeBlessingHeal(dt),
      );
    } else {
      comp.blessingCarry = 0;
    }
  }

  /// The family's basic attack, fired along [CosmicCompanion.angle].
  void _fireCompanionBasic(CosmicCompanion comp) {
    comp.basicCooldown = comp.effectiveBasicCooldown;
    final basics = createFamilyBasicAttack(
      origin: comp.position,
      angle: comp.angle,
      element: comp.member.element,
      family: comp.member.family,
      damage: comp.physAtk.toDouble() * comp.damageAmp,
    );
    _tagSource(basics, comp.member.slotIndex);
    if (_openKinLightningActive) {
      for (final projectile in basics) {
        projectile.chainLightningCharges = max(
          projectile.chainLightningCharges,
          3,
        );
      }
    }
    companionProjectiles.addAll(basics);
    if (comp.member.family.toLowerCase() == 'pip' &&
        comp.member.element == 'Earth') {
      comp.specialCooldown = max(0, comp.specialCooldown - 0.4);
    }
  }

  /// Whether the special is ready and is one that is cast at all (some are
  /// passives only, and a Mystic's world is a Survival ability).
  bool _companionSpecialReady(CosmicCompanion comp) =>
      comp.specialCooldown <= 0 &&
      castsSpecialOutsideSurvival(comp.member.family) &&
      !isPassiveOnlyCosmicAbility(comp.member.family, comp.member.element);

  /// Casts the family+element special at [targetPos] and starts whatever
  /// the cast leaves running on the caster (a charge, a shield, a blessing,
  /// a Kin support).
  void _castCompanionSpecial(CosmicCompanion comp, Offset targetPos) {
    comp.specialCooldown = comp.effectiveSpecialCooldown;
    _clearPipPoisonWeb(comp.member);
    // Generate family+element special ability
    final result = createCosmicSpecialAbility(
      origin: comp.position,
      baseAngle: comp.angle,
      family: comp.member.family,
      element: comp.member.element,
      damage: comp.abilityAtk * 0.8 * comp.damageAmp,
      maxHp: comp.maxHp,
      casterPower: comp.member.statIntelligence.toDouble(),
      casterBeauty: comp.member.statBeauty.toDouble(),
      casterIntelligence: comp.member.statIntelligence.toDouble(),
      casterStrength: comp.member.statStrength.toDouble(),
      casterBeautyPotential: comp.member.statBeautyPotential,
      targetPos: targetPos,
    );
    _tagSource(result.projectiles, comp.member.slotIndex);
    if (comp.member.family.toLowerCase() == 'horn') {
      // Survival's Horn cast: the ram, its wind-up and its burst.
      _castOpenHorn(comp, result, targetPos);
      _spawnHitSpark(comp.position, elementColor(comp.member.element));
      return;
    }
    _applyOpenManeSpecialRuntime(
      member: comp.member,
      projectiles: result.projectiles,
      origin: comp.position,
      angle: comp.angle,
      currentStack: comp.abilityKillStacks,
      setStack: (stack) => comp.abilityKillStacks = stack,
    );
    final isHornCharge =
        comp.member.family.toLowerCase() == 'horn' && result.chargeTimer > 0;
    if (isHornCharge) {
      comp.pendingChargeBurst = result.projectiles;
      comp.pendingChargeOrigin = comp.position;
      comp.pendingChargeAngle = comp.angle;
    } else if (!activateMaskPlacements(
      result.projectiles,
      caster: comp.position,
      target: targetPos,
    )) {
      companionProjectiles.addAll(result.projectiles);
    }
    _activateWingBeamEffects(
      result.beams,
      caster: _WingCaster.companion(comp),
      angle: comp.angle,
    );
    // Apply companion state changes from ability
    if (result.shieldHp > 0) comp.shieldHp = result.shieldHp;
    if (result.chargeTimer > 0) {
      comp.chargeDamage = result.chargeDamage;
      comp.chargeSpeedMultiplier = result.chargeSpeedMultiplier;
      comp.chargeSweepRadius = result.chargeSweepRadius;
      comp.chargeOvershootDistance = result.chargeOvershootDistance;
      comp.chargeFinalSweepRadius = result.chargeFinalSweepRadius;
      if (!isHornCharge) {
        comp.pendingChargeBurst = null;
        comp.pendingChargeOrigin = null;
      }
      comp.chargeHitIds = <int>{};
      // Overshoot varies per element so Horn charges read differently.
      final dir = targetPos - comp.position;
      final dist = dir.distance;
      if (dist > 1) {
        final overshootTarget =
            targetPos + (dir / dist) * comp.chargeOvershootDistance;
        comp.chargeTarget = overshootTarget;
        // Timer = time to reach overshoot + small buffer.
        final travelDist = (overshootTarget - comp.position).distance;
        final travelTime =
            travelDist /
            (CosmicCompanion.chargeSpeed * comp.chargeSpeedMultiplier);
        comp.chargeTimer = (travelTime + 0.15).clamp(0.3, 3.0);
      } else {
        comp.chargeTarget = targetPos;
        comp.chargeTimer = result.chargeTimer;
      }
    }
    if (result.selfHeal > 0) {
      comp.currentHp = min(comp.maxHp, comp.currentHp + result.selfHeal);
    }
    if (result.shipHeal > 0) {
      shipHealth = min(CosmicGame.shipMaxHealth, shipHealth + result.shipHeal);
    }
    if (result.blessingTimer > 0) {
      // A fresh blessing never cuts a stronger one short.
      comp.blessingTimer = max(comp.blessingTimer, result.blessingTimer);
      comp.blessingHealPerTick = max(
        comp.blessingHealPerTick,
        result.blessingHealPerTick,
      );
    }
    if (result.basicHasteTimer > 0) {
      comp.basicHasteTimer = result.basicHasteTimer;
      comp.basicHasteMultiplier = result.basicHasteMultiplier;
    }
    if (comp.member.family.toLowerCase() == 'kin') {
      _activateOpenKinSupport(comp, targetPos);
    }
    // VFX burst
    _spawnHitSpark(comp.position, elementColor(comp.member.element));
  }
}
