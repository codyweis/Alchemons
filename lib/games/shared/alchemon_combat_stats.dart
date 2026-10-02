import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/kin_support_runtime.dart'
    show kKinSpecialCooldownStretch;
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/models/survival_upgrades.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ALCHEMON POWER — the one place a creature's stats become combat numbers
//
//  Survival, the planet dungeons, open Cosmic Space (party and wilds) and the
//  creature Battle tab all build an Alchemon here. A mode may tune its WORLD
//  to these numbers — Space scales its enemies and its ship to them, see
//  CosmicBalance.spaceWorldScale — but no mode derives a creature its own way.
//
//  What each stat buys, the promise the Battle tab prints:
//    Strength      HP, P-ATK (auto-attack damage), P-DEF; a share of SPECIAL
//                  for families whose special is physical.
//    Intelligence  HP, both defences, auto and special range; most families'
//                  special recharge; a share of SPECIAL.
//    Beauty        E-ATK (elemental effects), E-DEF; a share of SPECIAL.
//    Speed         how often auto attacks fire; a share of special recharge.
//    SPECIAL       the family's blend of Strength/Intelligence/Beauty
//                  ([cosmicFamilyAbilityStatWeights]): how hard the special
//                  hits and how soon it comes back.
//    Family frame  each family's shape (a Horn's bulk, a Wing's reach),
//                  [alchemonFamilyFrame].
// ─────────────────────────────────────────────────────────────────────────────

typedef GuardianUpgradeValue = double Function(GuardianUpgrade upgrade);

/// A creature's combat numbers, before anything a run or a fight adds.
class AlchemonCombatStats {
  const AlchemonCombatStats({
    required this.maxHp,
    required this.physAtk,
    required this.elemAtk,
    required this.abilityAtk,
    required this.physDef,
    required this.elemDef,
    required this.cooldownReduction,
    required this.specialCooldownReduction,
    required this.attackRange,
    required this.specialAbilityRange,
  });

  final int maxHp;

  /// Auto-attack damage per hit.
  final int physAtk;

  /// Elemental effect potency: the payloads an element adds to hits.
  final int elemAtk;

  /// What this family's special hits for, from the family's own blend of
  /// stats — a Mane's catapult is paid for out of Strength, not Beauty.
  final int abilityAtk;
  final int physDef;
  final int elemDef;

  /// Auto-attack cadence, from Speed alone.
  final double cooldownReduction;

  /// Special cadence, from the family's own blend of Speed, Intelligence and
  /// Strength — see [cosmicFamilySpecialCooldownWeights].
  final double specialCooldownReduction;
  final double attackRange;
  final double specialAbilityRange;
}

/// A family's shape: what it multiplies the shared curves by. A Horn trades
/// reach for bulk, a Wing buys reach and elemental force, a Pip is fragile.
class AlchemonFamilyFrame {
  const AlchemonFamilyFrame({
    this.hp = 1.0,
    this.physAtk = 1.0,
    this.elemAtk = 1.0,
    this.physDef = 1.0,
    this.elemDef = 1.0,
    this.autoRange = 1.0,
    this.specialRange = 1.25,
    this.basicCooldown = 1.0,
    this.specialCooldown = 1.0,
  });

  final double hp;
  final double physAtk;

  /// Multiplies E-ATK and SPECIAL alike, so a family that pays for its
  /// special out of another stat keeps the same magnitude.
  final double elemAtk;
  final double physDef;
  final double elemDef;
  final double autoRange;
  final double specialRange;

  /// Multiplies the time between auto attacks (above 1 is slower).
  final double basicCooldown;

  /// Multiplies the time between specials. Cadence is the lever that says
  /// what a family is FOR against a horde (docs/horde_stress/role_scorecard.md):
  /// a Mane clears waves, so its line comes round often; a Wing can answer
  /// anything, so it should not answer everything at once.
  final double specialCooldown;
}

const Map<String, AlchemonFamilyFrame> kAlchemonFamilyFrames = {
  'horn': AlchemonFamilyFrame(
    hp: 1.40,
    physAtk: 1.10,
    elemAtk: 0.80,
    physDef: 1.30,
    elemDef: 1.20,
    autoRange: 0.58,
    specialRange: 0.90,
    basicCooldown: 1.12,
    specialCooldown: 0.85,
  ),
  'mane': AlchemonFamilyFrame(
    hp: 1.05,
    physAtk: 1.15,
    elemAtk: 1.00,
    physDef: 1.10,
    elemDef: 1.00,
    autoRange: 0.95,
    specialRange: 1.10,
    specialCooldown: 0.70,
  ),
  'wing': AlchemonFamilyFrame(
    hp: 1.05,
    physAtk: 0.90,
    elemAtk: 1.30,
    physDef: 0.85,
    elemDef: 0.90,
    autoRange: 1.30,
    // Reach is Let's and Wing's identity, and it is what siege artillery is
    // built to test: a gun parked past everyone else's range.
    specialRange: 1.95,
    basicCooldown: 0.90,
    specialCooldown: 1.22,
  ),
  'let': AlchemonFamilyFrame(
    hp: 1.05,
    physAtk: 1.25,
    elemAtk: 1.10,
    physDef: 1.15,
    elemDef: 1.10,
    autoRange: 1.10,
    specialRange: 2.05,
    basicCooldown: 1.12,
    specialCooldown: 1.05,
  ),
  'pip': AlchemonFamilyFrame(
    hp: 0.80,
    physAtk: 1.00,
    elemAtk: 0.95,
    physDef: 0.80,
    elemDef: 0.85,
    autoRange: 0.90,
    specialRange: 1.05,
    basicCooldown: 0.90,
    specialCooldown: 0.95,
  ),
  'mask': AlchemonFamilyFrame(
    hp: 1.05,
    physAtk: 1.10,
    elemAtk: 1.10,
    physDef: 1.00,
    elemDef: 1.05,
    autoRange: 1.00,
    specialRange: 1.15,
    basicCooldown: 1.10,
  ),
  'kin': AlchemonFamilyFrame(
    hp: 1.35,
    physAtk: 0.90,
    elemAtk: 0.90,
    physDef: 1.10,
    elemDef: 1.15,
    autoRange: 1.15,
    specialRange: 1.20,
    // Every Kin is a build-defining support and the cast is what sets it
    // running, so its special waits longer than the table says.
    specialCooldown: kKinSpecialCooldownStretch,
  ),
  'mystic': AlchemonFamilyFrame(
    hp: 1.05,
    physAtk: 0.85,
    elemAtk: 1.45,
    physDef: 0.85,
    elemDef: 0.90,
    autoRange: 1.10,
    specialRange: 1.45,
  ),
};

AlchemonFamilyFrame alchemonFamilyFrame(String family) =>
    kAlchemonFamilyFrames[family.toLowerCase()] ?? const AlchemonFamilyFrame();

/// Auto and special reach before the family frame, from Intelligence.
double alchemonBaseRange(double intelligence) =>
    100.0 + AlchemonStatSystem.legacyGameplayRating(intelligence) * 28.0;

/// The creature's combat numbers. [strengthBonus] and the like are a run's
/// stat pickups; [guardianUpgradeValue] is Survival's permanent Guardian
/// upgrades. Everything else about the creature is already in [member].
AlchemonCombatStats deriveAlchemonCombatStats({
  required CosmicPartyMember member,
  double strengthBonus = 0,
  double intelligenceBonus = 0,
  double beautyBonus = 0,
  double speedBonus = 0,
  GuardianUpgradeValue? guardianUpgradeValue,
}) {
  final level = CosmicBalance.clampCompanionLevel(member.level);
  final family = member.family.toLowerCase();
  final frame = alchemonFamilyFrame(family);
  final str = max(0.5, member.statStrength + strengthBonus);
  final intel = max(0.5, member.statIntelligence + intelligenceBonus);
  final beauty = max(0.5, member.statBeauty + beautyBonus);
  final speed = max(0.5, member.statSpeed + speedBonus);

  final strPow = CosmicSurvivalBalance.survivalStatPower(str);
  final intPow = CosmicSurvivalBalance.survivalStatPower(intel);
  final beautyPow = CosmicSurvivalBalance.survivalStatPower(beauty);

  final abilityWeights = cosmicFamilyAbilityStatWeights(family);
  final abilityPow =
      strPow * abilityWeights.strength +
      intPow * abilityWeights.intelligence +
      beautyPow * abilityWeights.beauty;

  final maxHp = ((110 + level * 18 + 320 * strPow + 150 * intPow) * frame.hp)
      .round();

  final levelFactor = 1.04 + (level - 1) * 0.065;
  final physAtk = max(
    1,
    ((5.0 + 24.0 * strPow) * levelFactor * frame.physAtk).round(),
  );
  final elemAtk = max(
    1,
    ((5.5 + 25.0 * beautyPow) * levelFactor * frame.elemAtk).round(),
  );
  // Same curve as elemental attack so a family that switches stats keeps the
  // same magnitude; only which stats feed it changes.
  final abilityAtk = max(
    1,
    ((5.5 + 25.0 * abilityPow) * levelFactor * frame.elemAtk).round(),
  );

  final physDef =
      ((15 + level * 2.8 + 58 * strPow + 34 * intPow) * frame.physDef).round();
  final elemDef =
      ((15 + level * 2.8 + 58 * beautyPow + 34 * intPow) * frame.elemDef)
          .round();

  // Cadence is continuous, so it reads the raw stat: a 100 is faster than a
  // 95. The final-step milestone applies to countable things, not to this.
  var cooldownReduction = CosmicBalance.companionCooldownReduction(speed);
  // A special comes back on whatever the family actually uses to bring it
  // back, which is rarely pure reflex.
  var specialCooldownReduction = CosmicBalance.companionCooldownReduction(
    cosmicFamilySpecialCooldownStat(
      family: family,
      speed: speed,
      intelligence: intel,
      strength: str,
    ),
  );
  var baseRange = alchemonBaseRange(intel);

  double upgrade(GuardianUpgrade u) => guardianUpgradeValue?.call(u) ?? 0.0;

  cooldownReduction *= (1 + upgrade(GuardianUpgrade.cooldown));
  specialCooldownReduction *= (1 + upgrade(GuardianUpgrade.cooldown));
  final guardDefMult = 1 + upgrade(GuardianUpgrade.defense);
  final guardAtkMult = 1 + upgrade(GuardianUpgrade.attack);
  baseRange *= (1 + upgrade(GuardianUpgrade.range));

  return AlchemonCombatStats(
    maxHp: maxHp,
    physAtk: (physAtk * guardAtkMult).round(),
    elemAtk: (elemAtk * guardAtkMult).round(),
    abilityAtk: (abilityAtk * guardAtkMult).round(),
    physDef: (physDef * guardDefMult).round(),
    elemDef: (elemDef * guardDefMult).round(),
    cooldownReduction: cooldownReduction,
    specialCooldownReduction: specialCooldownReduction,
    attackRange: baseRange * frame.autoRange,
    specialAbilityRange: baseRange * frame.specialRange,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CADENCE — how often a creature attacks and casts, in every mode
// ─────────────────────────────────────────────────────────────────────────────

const double kAlchemonBaseBasicCooldown = 1.5;
const double kAlchemonBaseSpecialCooldown = 12.5;

/// A Mask lays traps that persist for a long time, so the placement is the
/// rare action; it runs on its own base rather than the shared one.
const double kMaskBaseSpecialCooldown = 22.5;

/// A Mystic's special is its world, which only Survival runs. Everywhere
/// else — open space, the planet dungeons — a Mystic fights with its auto
/// attack and has no special to cast (user ruling, 2026-10-02).
bool castsSpecialOutsideSurvival(String family) =>
    family.toLowerCase() != 'mystic';

/// Wing+Dark pulses twice as fast — its auto attacks and its laser both,
/// per the design board.
bool isDarkWing(String family, String element) =>
    family.toLowerCase() == 'wing' && element == 'Dark';

/// How much harder hits speed up auto attacks: P-ATK shortens the wait until
/// it saturates (×3 at P-ATK 41).
double alchemonBasicAttackPowerFactor(int physAtk) =>
    (1.0 + (physAtk - 1) * 0.05).clamp(0.5, 3.0).toDouble();

/// How much a stronger special speeds its own return: SPECIAL shortens the
/// wait until it saturates (×6 at SPECIAL 150).
double alchemonSpecialPowerFactor(int abilityAtk) =>
    (1.0 + (abilityAtk / 6.0) * 0.2).clamp(0.5, 6.0).toDouble();

/// Seconds between auto attacks, before any timed haste.
///
/// Speed sets the rhythm ([cooldownReduction]); harder hits come out faster
/// ([alchemonBasicAttackPowerFactor]); the family frame and Wing+Dark adjust
/// it. [elementPassive] is a Pip element passive that drives attack speed
/// directly (Spirit's empower window, Steam's ramp); while one is active the
/// shared haste is ignored, so the passive reaches its design extreme instead
/// of overshooting it by stacking.
double alchemonBasicAttackInterval({
  required String family,
  required String element,
  required double cooldownReduction,
  required int physAtk,
  double haste = 1.0,
  double? elementPassive,
}) {
  final frame = alchemonFamilyFrame(family);
  final base = kAlchemonBaseBasicCooldown / cooldownReduction;
  final speedUp = elementPassive ?? haste.clamp(0.45, 1.0);
  return base /
      alchemonBasicAttackPowerFactor(physAtk) *
      frame.basicCooldown *
      speedUp *
      (isDarkWing(family, element) ? 0.5 : 1.0);
}

/// The Pip element passive that drives attack speed at this moment, or null.
double? pipElementBasicPassive({
  required String family,
  required String element,
  required double spiritEmpowerTimer,
  required double steamWindowTimer,
  required double steamWindowDuration,
}) {
  if (family.toLowerCase() != 'pip') return null;
  if (element == 'Spirit' && spiritEmpowerTimer > 0) {
    // Empower window: ~10× attack speed.
    return 0.10;
  }
  if (element == 'Steam') {
    // Steam window ramps attack speed from +50% to +300%.
    final progress = (steamWindowTimer / steamWindowDuration).clamp(0.0, 1.0);
    return 0.667 + (0.25 - 0.667) * progress;
  }
  return null;
}

/// Seconds between specials.
///
/// The family's recharge stats set the rhythm ([specialCooldownReduction]);
/// a stronger special comes back sooner ([alchemonSpecialPowerFactor]); the
/// family frame and the element table shape it. Mystics run their own rule:
/// every one descends toward 60s as its power grows.
double alchemonSpecialInterval({
  required String family,
  required String element,
  required double specialCooldownReduction,
  required int abilityAtk,
}) {
  final f = family.toLowerCase();
  final elementMultiplier = elementalSpecialCooldownMultiplierSurvival(
    family,
    element,
  );
  if (f == 'mask') {
    return kMaskBaseSpecialCooldown /
        specialCooldownReduction *
        elementMultiplier;
  }
  if (f == 'mystic') {
    // 0 at baseline, 1 once SPECIAL saturates (36) or recharge upgrades
    // stack a full 100%.
    final atkProgress = (abilityAtk / 36.0).clamp(0.0, 1.0);
    final cdrProgress = (specialCooldownReduction - 1.0).clamp(0.0, 1.0);
    final statProgress = (atkProgress + cdrProgress).clamp(0.0, 1.0);
    // Per-element "starting gap" above the 60s target. Bigger gap = slower at
    // low stats. All elements meet at 60s when statProgress reaches 1.
    final lowStatBonus = switch (element) {
      'Air' || 'Dust' => 20.0,
      'Poison' || 'Mud' || 'Water' => 35.0,
      'Lightning' || 'Ice' || 'Steam' => 50.0,
      'Blood' || 'Plant' || 'Fire' => 65.0,
      'Lava' || 'Crystal' || 'Earth' => 80.0,
      'Dark' || 'Light' || 'Spirit' => 100.0,
      _ => 50.0,
    };
    return 60.0 + lowStatBonus * (1.0 - statProgress);
  }
  // Wing+Dark's doubled rate applies to the LASER as well as the basic, per
  // the design board: "both the laser and the dark wing's auto-attacks fire
  // twice as fast". Measured, it is the strongest wing by a distance; what it
  // pays with is carrying no beam rider at all, which the conformance test
  // pins — add one and Dark is silently the strongest wing twice over.
  return kAlchemonBaseSpecialCooldown /
      specialCooldownReduction /
      alchemonSpecialPowerFactor(abilityAtk) *
      alchemonFamilyFrame(family).specialCooldown *
      elementMultiplier *
      (isDarkWing(family, element) ? 0.5 : 1.0);
}

// ─────────────────────────────────────────────────────────────────────────────
//  WHAT EACH STAT FEEDS — the contract the Battle tab prints
//
//  Written out from the formulas above. alchemon_stat_feeds_test.dart raises
//  each stat through [deriveAlchemonCombatStats] and the cadence rules and
//  checks this table against what actually moves, so the two cannot drift.
// ─────────────────────────────────────────────────────────────────────────────

enum AlchemonStat { strength, intelligence, beauty, speed }

enum AlchemonCombatOutput {
  hp,
  physAtk,
  elemAtk,
  special,
  physDef,
  elemDef,
  range,
  attackInterval,
  specialInterval,
}

/// Which stats move each combat number for [family], with each stat's share
/// where the formula blends them. Strength's share of auto-attack speed is
/// null: it works through P-ATK and stops at P-ATK 41
/// ([alchemonBasicAttackPowerFactor]). The special's power stats likewise
/// speed its recharge through SPECIAL, except a Mask's, which reads only its
/// recharge stats.
Map<AlchemonCombatOutput, Map<AlchemonStat, double?>> alchemonStatFeeds(
  String family,
) {
  final f = family.toLowerCase();
  final power = cosmicFamilyAbilityStatWeights(f);
  final recharge = cosmicFamilySpecialCooldownWeights(f);
  Map<AlchemonStat, double?> blend(Map<AlchemonStat, double> parts) => {
    for (final e in parts.entries)
      if (e.value > 0) e.key: e.value,
  };
  final specialPower = blend({
    AlchemonStat.strength: power.strength,
    AlchemonStat.intelligence: power.intelligence,
    AlchemonStat.beauty: power.beauty,
  });
  final specialRecharge = blend({
    AlchemonStat.speed: recharge.speed,
    AlchemonStat.intelligence: recharge.intelligence,
    AlchemonStat.strength: recharge.strength,
  });
  return {
    AlchemonCombatOutput.hp: {
      AlchemonStat.strength: 320 / 470,
      AlchemonStat.intelligence: 150 / 470,
    },
    AlchemonCombatOutput.physAtk: {AlchemonStat.strength: 1.0},
    AlchemonCombatOutput.elemAtk: {AlchemonStat.beauty: 1.0},
    AlchemonCombatOutput.special: specialPower,
    AlchemonCombatOutput.physDef: {
      AlchemonStat.strength: 58 / 92,
      AlchemonStat.intelligence: 34 / 92,
    },
    AlchemonCombatOutput.elemDef: {
      AlchemonStat.beauty: 58 / 92,
      AlchemonStat.intelligence: 34 / 92,
    },
    AlchemonCombatOutput.range: {AlchemonStat.intelligence: 1.0},
    AlchemonCombatOutput.attackInterval: {
      AlchemonStat.speed: 1.0,
      AlchemonStat.strength: null,
    },
    AlchemonCombatOutput.specialInterval: {
      ...specialRecharge,
      if (f != 'mask')
        for (final stat in specialPower.keys)
          if (!specialRecharge.containsKey(stat)) stat: null,
    },
  };
}
