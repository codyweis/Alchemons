// lib/games/cosmic/cosmic_data.dart
//
// Data model for the Cosmic Alchemy Explorer — planets, fog-of-war, element
// collection and summon resolution.

import 'dart:math';
import 'dart:ui';
import 'package:alchemons/games/shared/enemy_movement.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/systems/effects/has_effects.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/shared/enemy_flight_steering.dart';

// ─────────────────────────────────────────────────────────
// ELEMENT COLORS  (mirrors SurvivalAttackManager.getElementColor)
// ─────────────────────────────────────────────────────────
const Map<String, Color> kElementColors = {
  'Fire': Color(0xFFFF5722),
  'Lava': Color(0xFFEF6C00),
  'Lightning': Color(0xFFFFEB3B),
  'Water': Color(0xFF448AFF),
  'Ice': Color(0xFF00E5FF),
  'Steam': Color(0xFF90A4AE),
  'Earth': Color(0xFF795548),
  'Mud': Color(0xFF5D4037),
  'Dust': Color(0xFFFFCC80),
  'Crystal': Color(0xFF1DE9B6),
  'Air': Color(0xFF81D4FA),
  'Plant': Color(0xFF4CAF50),
  'Poison': Color(0xFF9C27B0),
  'Spirit': Color(0xFF3F51B5),
  'Dark': Color(0xFF4A148C),
  'Light': Color(0xFFFFE082),
  'Blood': Color(0xFFD32F2F),
};

Color elementColor(String element) =>
    kElementColors[element] ?? const Color(0xFF9E9E9E);

/// Canonical element order for authored family x element ability matrices.
const List<String> kCosmicAbilityElements = [
  'Plant',
  'Air',
  'Dust',
  'Lava',
  'Poison',
  'Blood',
  'Earth',
  'Light',
  'Spirit',
  'Crystal',
  'Fire',
  'Lightning',
  'Steam',
  'Dark',
  'Ice',
  'Mud',
  'Water',
];

/// Families with explicit authored cosmic special behavior.
const List<String> kCosmicAuthoredAbilityFamilies = [
  'horn',
  'wing',
  'let',
  'pip',
  'mane',
  'mask',
  'kin',
  'mystic',
];

/// Families covered by the design transcription in docs.
const List<String> kCosmicTranscribedAbilityFamilies = [
  'mane',
  'wing',
  'mask',
  'let',
  'pip',
];

const Map<String, List<String>> kCosmicAbilityContractElementsByFamily = {
  'horn': kCosmicAbilityElements,
  'wing': kCosmicAbilityElements,
  'let': kCosmicAbilityElements,
  'pip': kCosmicAbilityElements,
  'mane': kCosmicAbilityElements,
  'mask': kCosmicAbilityElements,
  'kin': kCosmicAbilityElements,
  'mystic': kCosmicAbilityElements,
};

bool isCosmicAuthoredAbilityFamily(String family) =>
    kCosmicAuthoredAbilityFamilies.contains(family.toLowerCase());

bool isPassiveOnlyCosmicAbility(String family, String element) {
  final f = family.toLowerCase();
  if (f == 'pip' && element == 'Dark') return true;
  // Horn passives per design board: Air (blow-back), Mud (sludge
  // trail), Poison (toxic aura) emit their effects continuously while
  // the horn is alive — no active cast.
  // Poison was originally passive-only, but the design has evolved
  // so it ALSO has an active charge attack. Only Air and Mud remain
  // pure passives.
  if (f == 'horn' && (element == 'Air' || element == 'Mud')) {
    return true;
  }
  // Kin+Fire is a pure passive: by being deployed, if the orb dies
  // the phoenix guard triggers and the post-revive orbital flame
  // activates automatically. No active cast.
  if (f == 'kin' && element == 'Fire') return true;
  return false;
}

bool isCosmicTranscribedAbilityFamily(String family) =>
    kCosmicTranscribedAbilityFamilies.contains(family.toLowerCase());

bool isCosmicAbilityElement(String element) =>
    kCosmicAbilityElements.contains(element);

// Global damage multiplier to tune basic attacks and ship projectiles.
const double kDamageScale = 1.5;

class CosmicBalance {
  static const int maxCombatLevel = 5;
  static const int maxCompanionLevel = 10;
  static const double minCombatStat = 1.0;
  // Arena enemies retain the proven 1-5 authored band. Player Alchemons can
  // exceed it through species Base, Potential, and Enhancement.
  static const double maxCombatStat = AlchemonStatSystem.legacyCombatCeiling;
  static const double maxEffectiveStat = double.infinity;
  static const double shipMaxHealth = 100.0;

  static int clampLevel(int level) => level.clamp(1, maxCombatLevel);
  static int clampCompanionLevel(int level) =>
      level.clamp(1, maxCompanionLevel);

  static double clampStat(double stat) =>
      stat.clamp(minCombatStat, maxEffectiveStat).toDouble();

  static double legacyStat(double stat) =>
      stat.clamp(minCombatStat, maxCombatStat).toDouble();

  static double _levelT(int level) => (clampLevel(level) - 1) / 4.0;
  static double _companionLevelT(int level) =>
      (clampCompanionLevel(level) - 1) / 9.0;

  // Exponent softened from 1.8 so mid-range genetic stats (the 2.0–3.0
  // "average" band) land as a competent middle rather than bottom-quartile.
  // Only affects raw attack/HP/def magnitudes — ability effect tiers
  // (_guardianStatTier breakpoints) and cooldowns are independent of this.
  static double statPower(double stat, {double exponent = 1.3}) {
    final normalized =
        (legacyStat(stat) - minCombatStat) / (maxCombatStat - minCombatStat);
    final legacyPower = pow(normalized, exponent).toDouble();
    final overcap = AlchemonStatSystem.combatOvercapProgress(stat);
    return legacyPower * (1.0 + overcap * 0.30);
  }

  static double arenaMinStat(int level) {
    final t = _levelT(level);
    return 2.0 + pow(t, 1.1).toDouble() * 2.0;
  }

  static double arenaMaxStat(int level) {
    final t = _levelT(level);
    return min(maxCombatStat, arenaMinStat(level) + 0.7 + 0.3 * t);
  }

  static double rollArenaStat(int level, Random rng) {
    final minStat = arenaMinStat(level);
    final maxStat = arenaMaxStat(level);
    return minStat + rng.nextDouble() * (maxStat - minStat);
  }

  static int companionMaxHp({
    required int level,
    required double strength,
    required double intelligence,
  }) {
    final strengthPower = statPower(strength);
    final intelligencePower = statPower(intelligence, exponent: 1.5);
    // Weight shifted off the flat base into the stat-driven terms so a
    // high-stat creature is meaningfully tougher, not just punchier.
    return (40 +
            clampCompanionLevel(level) * 10 +
            230 * strengthPower +
            95 * intelligencePower)
        .round();
  }

  static double _offenseLevelFactor(int level) {
    final t = _companionLevelT(level);
    return 0.92 + pow(t, 0.9).toDouble() * 0.78;
  }

  static int companionPhysAtk({required int level, required double strength}) {
    final strengthPower = statPower(strength);
    return max(
      1,
      ((1.0 + 5.8 * strengthPower) * _offenseLevelFactor(level)).round(),
    );
  }

  static int companionElemAtk({required int level, required double beauty}) {
    final beautyPower = statPower(beauty);
    return max(
      1,
      ((1.1 + 6.7 * beautyPower) * _offenseLevelFactor(level)).round(),
    );
  }

  static int companionPhysDef({
    required int level,
    required double strength,
    required double intelligence,
  }) {
    final strengthPower = statPower(strength);
    final intelligencePower = statPower(intelligence, exponent: 1.5);
    return (5 +
            clampCompanionLevel(level) * 1.5 +
            42 * strengthPower +
            22 * intelligencePower)
        .round();
  }

  static int companionElemDef({
    required int level,
    required double beauty,
    required double intelligence,
  }) {
    final beautyPower = statPower(beauty);
    final intelligencePower = statPower(intelligence, exponent: 1.5);
    return (5 +
            clampCompanionLevel(level) * 1.5 +
            42 * beautyPower +
            22 * intelligencePower)
        .round();
  }

  static double companionCooldownReduction(double speed) {
    final legacy = 0.72 + legacyStat(speed) * 0.08;
    final overcap = AlchemonStatSystem.combatOvercapProgress(speed) * 0.08;
    return (legacy + overcap).clamp(0.78, 1.20).toDouble();
  }

  static double companionCritChance(double strength) {
    return (0.04 + statPower(strength) * 0.24).clamp(0.04, 0.36).toDouble();
  }

  static double companionBaseRange(double intelligence) {
    return 95.0 + AlchemonStatSystem.legacyGameplayRating(intelligence) * 30.0;
  }

  static double shipDamageMultiplier(int level) {
    final safeLevel = level.clamp(0, HomeCustomizationState.maxUpgradeLevel);
    return 1.0 + safeLevel * 0.08;
  }

  static double missileDamageMultiplier(int level) {
    final safeLevel = level.clamp(0, HomeCustomizationState.maxUpgradeLevel);
    return 1.0 + safeLevel * 0.04;
  }

  static double missileHitDamage({required int level, required bool vsBoss}) {
    // Rescaled ×3 to match the rescaled enemy/boss HP (see enemyBaseHealth).
    final baseDamage = vsBoss ? 3.6 : 6.6;
    return baseDamage * missileDamageMultiplier(level);
  }

  static double shipProjectileHitDamage({
    required int level,
    required bool machineGun,
  }) {
    // Rescaled ×3 to match the rescaled enemy/boss HP (see enemyBaseHealth).
    final baseDamage = machineGun ? 0.42 : 1.2;
    return baseDamage * shipDamageMultiplier(level) * kDamageScale;
  }

  static double shipProjectileAsteroidDamage({
    required int level,
    required bool machineGun,
  }) {
    final baseDamage = machineGun ? 0.06 : 0.14;
    return baseDamage * shipDamageMultiplier(level);
  }

  // Canonical open-world enemy HP. Rescaled ×3 from the original
  // ship-weapon-tuned values so companion attack-stat differences are
  // felt across all tiers (ship weapon damage is rescaled ×3 to match,
  // see shipProjectileHitDamage / missileHitDamage).
  static double enemyBaseHealth(EnemyTier tier) => switch (tier) {
    EnemyTier.drone => 2.25,
    EnemyTier.wisp => 3.6,
    EnemyTier.sentinel => 11.4,
    EnemyTier.phantom => 15.0,
    EnemyTier.brute => 30.0,
    EnemyTier.colossus => 54.0,
  };

  // Authored against the legacy 6 HP ship pool. _damageShip rescales to
  // the current pool, so these stay the canonical relative-threat values.
  static double enemyShipContactDamage(EnemyTier tier) => switch (tier) {
    EnemyTier.wisp => 0.6,
    EnemyTier.drone => 0.9,
    EnemyTier.sentinel => 1.3,
    EnemyTier.phantom => 1.7,
    EnemyTier.brute => 2.2,
    EnemyTier.colossus => 3.2,
  };

  static double enemyCompanionContactDamage(EnemyTier tier) => switch (tier) {
    EnemyTier.wisp => 4.0,
    EnemyTier.drone => 5.5,
    EnemyTier.sentinel => 8.5,
    EnemyTier.phantom => 11.0,
    EnemyTier.brute => 16.0,
    EnemyTier.colossus => 26.0,
  };

  // ── Open-space boss difficulty curve ─────────────────────
  // Levels 1-5 map onto the stat range so each level is beatable by the
  // matching genetic band (statPower is harsh below 2.5, so the early
  // curve must stay LOW and catch up steeply):
  //   Lv1 ↔ stats ~1.0-1.5 (intro)   Lv2 ↔ ~1.5-2.0   Lv3 ↔ ~2.0-2.5
  //   Lv4 ↔ ~3.0-3.5                 Lv5 ↔ ~4.0+ (endgame, unchanged)
  // All Lv5 values are preserved from the previous tuning; only the
  // low/mid levels were flattened (Lv3 HP was previously mid-curve at
  // 11.1× — a stats-3 fight wearing a Lv3 badge).

  /// Eases [t]∈[0,1] so early levels sit low and the curve catches up at 5.
  static double _bossT(int level, double exponent) =>
      pow(_levelT(level), exponent).toDouble();

  static double bossHealthScale(int level) {
    // ×3 keeps open-world bosses in step with the rescaled enemy HP table
    // and ship weapon damage (see enemyBaseHealth).
    // Lv: 1→3.0, 2→4.3, 3→7.8, 4→13.4, 5→21.0 (was 3.0/6.2/11.1/16.4/21.0).
    return (1.0 + _bossT(level, 1.9) * 6.0) * 3.0;
  }

  static double bossSpeedScale(int level) {
    final t = _levelT(level);
    return 1.0 + pow(t, 0.9).toDouble() * 0.32;
  }

  static double bossRadiusBonus(int level) {
    return _levelT(level) * 10.0;
  }

  static double bossShieldHealth(int level) {
    // Lv: 1→4.5, 2→7.8, 3→14.4, 4→23.4, 5→34.5 (was 17.7…34.5 linear).
    // At Lv3 a ~8 DPS (stats ~2.0) loadout strips a shield cycle in ~2s.
    return (1.5 + _bossT(level, 1.6) * 10.0) * 3.0;
  }

  /// Per-type damage eased from a gentle low-level floor to the SAME Lv5
  /// ceiling as before. Legacy 6-HP-pool units (see _damageShip rescale):
  /// 0.6 legacy ≈ 10% of the ship per hit.
  static double _bossDamageCurve(int level, double low, double high) =>
      low + (high - low) * _bossT(level, 1.5);

  static double bossProjectileDamage({
    required int level,
    required BossType type,
    bool enraged = false,
  }) {
    return switch (type) {
      BossType.charger => 0.0,
      // Gunner Lv3: 0.89 (≈15% ship per hit, ~7 hits to die) — was 1.18
      // (≈20% per hit, 5 hits to die).
      BossType.gunner => _bossDamageCurve(level, 0.55, 1.5),
      BossType.skirmisher => _bossDamageCurve(level, 0.50, 1.42),
      BossType.bulwark => _bossDamageCurve(level, 0.40, 1.08),
      BossType.carrier => _bossDamageCurve(level, 0.45, 1.25),
      BossType.warden =>
        _bossDamageCurve(level, 0.65, 1.75) * (enraged ? 1.15 : 1.0),
    };
  }

  static double bossCollisionDamage({
    required int level,
    required BossType type,
    bool charging = false,
  }) {
    final base = switch (type) {
      BossType.charger => _bossDamageCurve(level, 0.85, 2.2),
      BossType.gunner => _bossDamageCurve(level, 0.70, 1.8),
      BossType.skirmisher => _bossDamageCurve(level, 0.72, 1.85),
      BossType.bulwark => _bossDamageCurve(level, 0.90, 2.25),
      BossType.carrier => _bossDamageCurve(level, 0.65, 1.65),
      BossType.warden => _bossDamageCurve(level, 0.85, 2.2),
    };
    return charging ? base * 1.2 : base;
  }

  /// Global post-kill escalation, CAPPED. The previous uncapped
  /// `1 + kills × 0.05` compounded forever and silently re-broke the early
  /// curve once a player had a few kills banked.
  static double bossEscalationScale(int bossesDefeated) =>
      1.0 + min(bossesDefeated, 10) * 0.05;
}

// ─────────────────────────────────────────────────────────
// PLANET DISPLAY NAMES
// ─────────────────────────────────────────────────────────
const Map<String, String> kPlanetDisplayName = {
  'Fire': 'Pyrathis',
  'Lava': 'Magmora',
  'Lightning': 'Voltara',
  'Water': 'Aquathos',
  'Ice': 'Glaceron',
  'Steam': 'Vaporis',
  'Earth': 'Terragrim',
  'Mud': 'Mireholm',
  'Dust': 'Cindrath',
  'Crystal': 'Lumishara',
  'Air': 'Zephyria',
  'Plant': 'Verdanthos',
  'Poison': 'Toxivyre',
  'Spirit': 'Etherion',
  'Dark': 'Nythralor',
  'Light': 'Solanthis',
  'Blood': 'Hemavorn',
};

String planetName(String element) => kPlanetDisplayName[element] ?? element;

// ─────────────────────────────────────────────────────────
// COSMIC PLANET
// ─────────────────────────────────────────────────────────

/// Per-element planet size & gravity mass.
// Size passes: ×1.2, then another ×1.2 — except the tiny/small tier
// (Air, Lightning, Spirit, Ice, Poison), which got ×1.5 in the second pass
// so the smallest worlds stop reading as specks. Derived values (particle
// field, patrol/lair orbits, approach detection) key off these radii and
// scale with them.
const Map<String, double> kPlanetRadius = {
  'Fire': 131,
  'Lava': 159,
  'Lightning': 100,
  'Water': 217,
  'Ice': 127,
  'Steam': 145,
  'Earth': 174,
  'Mud': 123,
  'Dust': 290,
  'Crystal': 145,
  'Air': 82,
  'Plant': 116,
  'Poison': 136,
  'Spirit': 100,
  'Dark': 138,
  'Light': 289,
  'Blood': 152,
};

/// Gravity strength multiplier per element (bigger / denser = stronger pull).
const Map<String, double> kPlanetGravity = {
  'Fire': 1.0,
  'Lava': 1.4,
  'Lightning': 0.5,
  'Water': 1.1,
  'Ice': 0.8,
  'Steam': 0.3,
  'Earth': 1.6,
  'Mud': 1.2,
  'Dust': 0.4,
  'Crystal': 0.9,
  'Air': 0.2,
  'Plant': 0.7,
  'Poison': 0.8,
  'Spirit': 0.3,
  'Dark': 1.5,
  'Light': 0.4,
  'Blood': 1.3,
};

/// A planet that emits elemental particles of a single element type.
class CosmicPlanet {
  CosmicPlanet({
    required this.element,
    required this.position,
    required this.radius,
    this.discovered = false,
  });

  final String element; // e.g. 'Fire'
  Offset position; // world-space position (mutable for orbital mechanics)
  final double radius; // visual radius
  bool discovered; // fog-of-war state

  Color get color => elementColor(element);

  /// Gravity pull strength.
  double get gravityStrength => (kPlanetGravity[element] ?? 1.0) * 8000;

  /// Ring of influence where particles spawn.
  double get particleFieldRadius => radius * 12.0;
}

// ─────────────────────────────────────────────────────────
// PRISMATIC FIELD (aurora easter-egg)
// ─────────────────────────────────────────────────────────

/// A giant shimmering prismatic aurora field floating in space.
/// If the player summons a prismatic companion inside the field,
/// the companion sprints in a circle and awards 50 gold.
/// This reward can only be claimed once, but the field is always visible.
class PrismaticField {
  PrismaticField({required this.position, this.radius = 1200});

  final Offset position;
  final double radius;
  bool discovered = false;
  bool rewardClaimed = false;
  double life = 0; // visual animation timer

  /// Prismatic hue-cycling colors for the aurora bands.
  static const List<Color> auroraColors = [
    Color(0xFFFF0066), // magenta-pink
    Color(0xFFFF6600), // orange
    Color(0xFFFFDD00), // gold
    Color(0xFF00FF88), // green
    Color(0xFF00DDFF), // cyan
    Color(0xFF4466FF), // blue
    Color(0xFF9933FF), // violet
    Color(0xFFFF00CC), // hot pink
  ];
}

// ─────────────────────────────────────────────────────────
// ELEMENTAL NEXUS (easter-egg black portal)
// ─────────────────────────────────────────────────────────

/// A massive black portal hidden in deep space.
/// Requires the alchemeal meter to have exactly 25% Fire, 25% Water,
/// 25% Air, 25% Earth to enter.
///
/// Inside: player gets a guaranteed harvester, then picks one of four
/// elemental portals (Fire/Water/Earth/Air).  Going through one triggers
/// an encounter with a Prismatic Kin of that element.
///
/// The encounter creature has stats: all 3.0 starting, 4.5 potential.
///
/// State is persisted so if the app crashes mid-nexus the player can resume.
enum NexusPhase {
  /// Not yet entered the nexus.
  outside,

  /// Inside the nexus chamber — choosing a portal.
  choosingPortal,

  /// Went through a portal — encounter in progress.
  inEncounter,
}

class ElementalNexus {
  Offset position;
  bool discovered;
  NexusPhase phase;

  /// Which element portal the player chose (null until they pick one).
  String? chosenElement;

  /// Whether the guaranteed harvester was already awarded this visit.
  bool harvesterAwarded;

  /// Whether the ship is currently inside the pocket wormhole dimension.
  bool inPocket;

  /// Ship position before entering the pocket (for returning).
  Offset? prePocketShipPos;

  ElementalNexus({
    required this.position,
    this.discovered = false,
    this.phase = NexusPhase.outside,
    this.chosenElement,
    this.harvesterAwarded = false,
    this.inPocket = false,
    this.prePocketShipPos,
  });

  static const double interactRadius = 350.0;
  static const double exitRadius = 450.0;
  static const double visualRadius = 300.0;

  // Pocket dimension layout
  static const double pocketRadius = 1200.0;
  static const double portalOrbitR = 250.0;
  static const double portalInteractR = 120.0;

  static const List<String> pocketElements = ['Fire', 'Water', 'Earth', 'Air'];

  /// Returns world-space positions of the 4 pocket portals relative to
  /// [pocketCenter].
  static List<Offset> pocketPortalPositions(Offset pocketCenter) {
    return [
      pocketCenter + const Offset(0, -portalOrbitR), // Fire (top)
      pocketCenter + const Offset(portalOrbitR, 0), // Water (right)
      pocketCenter + const Offset(0, portalOrbitR), // Earth (bottom)
      pocketCenter + const Offset(-portalOrbitR, 0), // Air (left)
    ];
  }

  /// The four required elements and their percentages.
  static const Map<String, double> requiredRecipe = {
    'Fire': 25.0,
    'Water': 25.0,
    'Air': 25.0,
    'Earth': 25.0,
  };

  /// Check if the meter matches the nexus recipe (each element ≥ 20%).
  bool meetsRequirement(Map<String, double> meterBreakdown, double meterTotal) {
    if (meterTotal <= 0) return false;
    for (final entry in requiredRecipe.entries) {
      final actual = ((meterBreakdown[entry.key] ?? 0) / meterTotal) * 100;
      if (actual < 20.0) return false; // allow 5% tolerance
    }
    return true;
  }

  String serialise() {
    return '${position.dx.toStringAsFixed(1)},'
        '${position.dy.toStringAsFixed(1)}|'
        '${discovered ? 1 : 0}|'
        '${phase.index}|'
        '${chosenElement ?? ""}|'
        '${harvesterAwarded ? 1 : 0}|'
        '${inPocket ? 1 : 0}|'
        '${prePocketShipPos != null ? '${prePocketShipPos!.dx.toStringAsFixed(1)},${prePocketShipPos!.dy.toStringAsFixed(1)}' : ''}';
  }

  factory ElementalNexus.deserialise(String raw) {
    final parts = raw.split('|');
    if (parts.length < 5) {
      return ElementalNexus(position: const Offset(0, 0));
    }
    final posParts = parts[0].split(',');
    final pos = Offset(
      double.tryParse(posParts[0]) ?? 0,
      double.tryParse(posParts[1]) ?? 0,
    );

    // Parse pocket fields (added in v2)
    final pocketFlag = parts.length > 5 ? parts[5] == '1' : false;
    Offset? prePocketPos;
    if (parts.length > 6 && parts[6].isNotEmpty) {
      final pp = parts[6].split(',');
      if (pp.length == 2) {
        prePocketPos = Offset(
          double.tryParse(pp[0]) ?? 0,
          double.tryParse(pp[1]) ?? 0,
        );
      }
    }

    return ElementalNexus(
      position: pos,
      discovered: parts[1] == '1',
      phase: NexusPhase.values[(int.tryParse(parts[2]) ?? 0).clamp(0, 2)],
      chosenElement: parts[3].isNotEmpty ? parts[3] : null,
      harvesterAwarded: parts[4] == '1',
      inPocket: pocketFlag,
      prePocketShipPos: prePocketPos,
    );
  }
}

// ─────────────────────────────────────────────────────────
// BATTLE RING (10-level arena with 1v1 encounters)
// ─────────────────────────────────────────────────────────

class BattleRing {
  Offset position;
  bool discovered;

  /// Current level (0-based). 0–9 = levels 1–10. 10 = all beaten, practice mode.
  int currentLevel;

  /// True while a 1v1 battle is actively in progress.
  bool inBattle;

  BattleRing({
    required this.position,
    this.discovered = false,
    this.currentLevel = 0,
    this.inBattle = false,
  });

  /// Visual outer radius of the octagon ring.
  static const double visualRadius = 300.0;

  /// Interaction radius (proximity to trigger popup).
  static const double interactRadius = 400.0;

  /// Exit radius (hysteresis band so popup doesn't flicker).
  static const double exitRadius = 500.0;

  /// If the ship leaves this far from the arena center, the active battle ends.
  static const double cancelRadius = 900.0;

  /// Number of levels in total.
  static const int maxLevels = 10;

  /// Whether all 10 levels are beaten → practice arena.
  bool get isCompleted => currentLevel >= maxLevels;

  /// Gold reward is limited to first clears only.
  /// Practice matches grant no gold once the arena is complete.
  int get goldReward {
    if (isCompleted) return 0;
    if (currentLevel >= 9) return 5;
    if (currentLevel >= 6) return 2;
    return 1;
  }

  /// Opponent rarity for the current level.
  /// Levels 1–3 = common, 4–6 = uncommon, 7–8 = rare, 9–10 = legendary.
  String get opponentRarity {
    if (currentLevel >= 8) return 'legendary';
    if (currentLevel >= 6) return 'rare';
    if (currentLevel >= 3) return 'uncommon';
    return 'common';
  }

  /// Opponent stat cap for the current level.
  /// Linear scale: level 1 = 1.5, level 10 = 4.5.
  double get opponentStatMax => 1.5 + (currentLevel * (3.0 / 9.0));

  /// Display name for the current level.
  String get levelLabel =>
      isCompleted ? 'PRACTICE ARENA' : 'LEVEL ${currentLevel + 1} / $maxLevels';

  String serialise() {
    return '${position.dx.toStringAsFixed(1)},'
        '${position.dy.toStringAsFixed(1)}|'
        '${discovered ? 1 : 0}|'
        '$currentLevel|'
        '${inBattle ? 1 : 0}';
  }

  factory BattleRing.deserialise(String raw) {
    final parts = raw.split('|');
    if (parts.length < 3) {
      return BattleRing(position: const Offset(0, 0));
    }
    final posParts = parts[0].split(',');
    final pos = Offset(
      double.tryParse(posParts[0]) ?? 0,
      double.tryParse(posParts[1]) ?? 0,
    );
    return BattleRing(
      position: pos,
      discovered: parts[1] == '1',
      currentLevel: (int.tryParse(parts[2]) ?? 0).clamp(0, maxLevels),
      inBattle: parts.length > 3 ? parts[3] == '1' : false,
    );
  }
}

// ─────────────────────────────────────────────────────────
// BLOOD RING (ending ritual portal)
// ─────────────────────────────────────────────────────────

class BloodRing {
  Offset position;
  bool discovered;

  /// True once the ending ritual has been completed at least once.
  bool ritualCompleted;

  /// Last Alchemon offered to the ring, used to replay the true finale text.
  String? lastOfferingInstanceId;
  String? lastOfferingName;
  String? lastOfferingImagePath;
  String? lastOfferingElement;
  String? lastOfferingFamily;
  double? lastOfferingIntelligence;
  double? lastOfferingStrength;
  double? lastOfferingBeauty;

  BloodRing({
    required this.position,
    this.discovered = false,
    this.ritualCompleted = false,
    this.lastOfferingInstanceId,
    this.lastOfferingName,
    this.lastOfferingImagePath,
    this.lastOfferingElement,
    this.lastOfferingFamily,
    this.lastOfferingIntelligence,
    this.lastOfferingStrength,
    this.lastOfferingBeauty,
  });

  /// Visual outer radius.
  static const double visualRadius = 320.0;

  /// Interaction radius (proximity to show interaction button).
  static const double interactRadius = 420.0;

  /// Exit radius (hysteresis so the prompt does not flicker).
  static const double exitRadius = 520.0;

  String serialise() {
    return '${position.dx.toStringAsFixed(1)},'
        '${position.dy.toStringAsFixed(1)}|'
        '${discovered ? 1 : 0}|'
        '${ritualCompleted ? 1 : 0}|'
        '${Uri.encodeComponent(lastOfferingInstanceId ?? '')}|'
        '${Uri.encodeComponent(lastOfferingName ?? '')}|'
        '${Uri.encodeComponent(lastOfferingImagePath ?? '')}|'
        '${Uri.encodeComponent(lastOfferingElement ?? '')}|'
        '${Uri.encodeComponent(lastOfferingFamily ?? '')}|'
        '${lastOfferingIntelligence?.toString() ?? ''}|'
        '${lastOfferingStrength?.toString() ?? ''}|'
        '${lastOfferingBeauty?.toString() ?? ''}';
  }

  factory BloodRing.deserialise(String raw) {
    final parts = raw.split('|');
    if (parts.length < 2) {
      return BloodRing(position: const Offset(0, 0));
    }
    final posParts = parts[0].split(',');
    final pos = Offset(
      double.tryParse(posParts[0]) ?? 0,
      double.tryParse(posParts[1]) ?? 0,
    );
    return BloodRing(
      position: pos,
      discovered: parts[1] == '1',
      ritualCompleted: parts.length > 2 ? parts[2] == '1' : false,
      lastOfferingInstanceId: parts.length > 3
          ? Uri.decodeComponent(parts[3]).trim().isEmpty
                ? null
                : Uri.decodeComponent(parts[3])
          : null,
      lastOfferingName: parts.length > 4
          ? Uri.decodeComponent(parts[4]).trim().isEmpty
                ? null
                : Uri.decodeComponent(parts[4])
          : null,
      lastOfferingImagePath: parts.length > 5
          ? Uri.decodeComponent(parts[5]).trim().isEmpty
                ? null
                : Uri.decodeComponent(parts[5])
          : null,
      lastOfferingElement: parts.length > 6
          ? Uri.decodeComponent(parts[6]).trim().isEmpty
                ? null
                : Uri.decodeComponent(parts[6])
          : null,
      lastOfferingFamily: parts.length > 7
          ? Uri.decodeComponent(parts[7]).trim().isEmpty
                ? null
                : Uri.decodeComponent(parts[7])
          : null,
      lastOfferingIntelligence: parts.length > 8
          ? double.tryParse(parts[8])
          : null,
      lastOfferingStrength: parts.length > 9 ? double.tryParse(parts[9]) : null,
      lastOfferingBeauty: parts.length > 10 ? double.tryParse(parts[10]) : null,
    );
  }
}

// ─────────────────────────────────────────────────────────
// RIFT PORTAL (one per faction, permanent)
// ─────────────────────────────────────────────────────────

class RiftPortal {
  final String faction; // 'volcanic','oceanic','verdant','earthen','arcane'
  Offset position;
  bool entered; // true once the player has entered this session

  RiftPortal({
    required this.faction,
    required this.position,
    this.entered = false,
  });

  static const double interactRadius = 120.0;
  static const double exitRadius = 150.0;

  /// Faction display color for rendering.
  Color get color => switch (faction) {
    'volcanic' => const Color(0xFFFF5722),
    'oceanic' => const Color(0xFF2196F3),
    'verdant' => const Color(0xFF4CAF50),
    'earthen' => const Color(0xFFFF8F00),
    'arcane' => const Color(0xFFCE93D8),
    _ => const Color(0xFFCE93D8),
  };

  Color get coreColor => switch (faction) {
    'volcanic' => const Color(0xFF1A0500),
    'oceanic' => const Color(0xFF000D1A),
    'verdant' => const Color(0xFF001A08),
    'earthen' => const Color(0xFF1A0A00),
    'arcane' => const Color(0xFF0D0015),
    _ => const Color(0xFF0D0015),
  };

  String get displayName => switch (faction) {
    'volcanic' => 'Volcanic Rift',
    'oceanic' => 'Oceanic Rift',
    'verdant' => 'Verdant Rift',
    'earthen' => 'Earthen Rift',
    'arcane' => 'Arcane Rift',
    _ => 'Rift Portal',
  };
}

// ─────────────────────────────────────────────────────────
// PARTICLE SWARM (wandering elemental cloud)
// ─────────────────────────────────────────────────────────

/// A drifting cloud of elemental motes that the player can fly through
/// and collect. Each swarm has 80-120 individual particles that orbit
/// the swarm centre with gentle cohesion.
class ParticleSwarm {
  ParticleSwarm({
    required this.element,
    required this.center,
    required this.motes,
    required this.driftAngle,
  });

  String element;
  Offset center; // swarm centre drifts slowly
  double driftAngle; // direction of drift (radians)
  double driftTimer = 0; // time until drift angle changes
  final List<SwarmMote> motes;
  double pulse = 0; // visual pulse timer

  /// How many motes remain uncollected.
  int get remaining => motes.where((m) => !m.collected).length;
  bool get depleted => remaining < motes.length * 0.25;

  static const double driftSpeed = 12.0; // units/sec
  static const double cloudRadius = 350.0; // mote scatter radius
  static const double collectRadius = 35.0; // ship pickup radius per mote
  static const double magnetRadius = 80.0; // magnetic pull range

  /// Generate swarms scattered across the world.
  static List<ParticleSwarm> generate({
    required int seed,
    required Size worldSize,
    required List<Offset> obstacles, // planet + rift positions
    int count = 20,
  }) {
    final rng = Random(seed ^ 0xBEEFCAFE);
    const margin = 2500.0;
    const minDist = 2000.0;
    const elements = [
      'Fire',
      'Water',
      'Earth',
      'Air',
      'Steam',
      'Lava',
      'Lightning',
      'Mud',
      'Ice',
      'Dust',
      'Crystal',
      'Plant',
      'Poison',
      'Spirit',
      'Dark',
      'Light',
      'Blood',
    ];

    final placed = <Offset>[];
    final swarms = <ParticleSwarm>[];

    for (var i = 0; i < count; i++) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
        tries++;
      } while (tries < 300 &&
          (obstacles.any((o) => (o - pos).distance < minDist) ||
              placed.any((p) => (p - pos).distance < minDist)));

      placed.add(pos);
      final elem = elements[rng.nextInt(elements.length)];
      final moteCount = 80 + rng.nextInt(41); // 80–120

      final motes = <SwarmMote>[];
      for (var m = 0; m < moteCount; m++) {
        final angle = rng.nextDouble() * pi * 2;
        final dist = rng.nextDouble() * cloudRadius;
        motes.add(
          SwarmMote(
            offsetX: cos(angle) * dist,
            offsetY: sin(angle) * dist,
            orbitSpeed: 0.15 + rng.nextDouble() * 0.35,
            orbitPhase: rng.nextDouble() * pi * 2,
            size: 1.5 + rng.nextDouble() * 2.5,
          ),
        );
      }

      swarms.add(
        ParticleSwarm(
          element: elem,
          center: pos,
          motes: motes,
          driftAngle: rng.nextDouble() * pi * 2,
        ),
      );
    }
    return swarms;
  }
}

/// A single mote within a particle swarm.
class SwarmMote {
  SwarmMote({
    required this.offsetX,
    required this.offsetY,
    required this.orbitSpeed,
    required this.orbitPhase,
    required this.size,
  });

  double offsetX, offsetY; // offset from swarm centre
  final double orbitSpeed; // radians/sec of gentle orbit
  double orbitPhase; // current phase
  final double size; // visual radius
  bool collected = false;
}

// ─────────────────────────────────────────────────────────
// COSMIC WORLD DEFINITION
// ─────────────────────────────────────────────────────────

/// The entire cosmos layout.
class CosmicWorld {
  CosmicWorld({
    required this.planets,
    required this.worldSize,
    required this.riftPortals,
    required this.particleSwarms,
    required this.prismaticField,
    required this.elementalNexus,
    required this.battleRing,
    required this.bloodRing,
    required this.contestArenas,
    required this.contestHintNotes,
  });

  final List<CosmicPlanet> planets;
  final Size worldSize; // total explorable area
  final List<RiftPortal> riftPortals;
  final List<ParticleSwarm> particleSwarms;
  final PrismaticField prismaticField;
  final ElementalNexus elementalNexus;
  final BattleRing battleRing;
  final BloodRing bloodRing;
  final List<CosmicContestArena> contestArenas;
  final List<CosmicContestHintNote> contestHintNotes;

  /// Generate a standard cosmos: one planet per element scattered across a
  /// huge field. Deliberately large so it takes ~10 minutes to traverse.
  factory CosmicWorld.generate({int? seed}) {
    final rng = Random(seed ?? DateTime.now().millisecondsSinceEpoch);
    const elements = [
      'Fire',
      'Water',
      'Earth',
      'Air',
      'Steam',
      'Lava',
      'Lightning',
      'Mud',
      'Ice',
      'Dust',
      'Crystal',
      'Plant',
      'Poison',
      'Spirit',
      'Dark',
      'Light',
      'Blood',
    ];

    // World is 38 400 × 38 400 logical units.
    const double worldW = 38400;
    const double worldH = 38400;
    const double margin = 1920;
    const double minDist = 3840; // planets don't crowd each other

    final planets = <CosmicPlanet>[];
    for (final elem in elements) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldW - margin * 2),
          margin + rng.nextDouble() * (worldH - margin * 2),
        );
        tries++;
      } while (tries < 300 &&
          planets.any((p) => (p.position - pos).distance < minDist));

      final baseR = kPlanetRadius[elem] ?? 70;
      // ±15% random variation
      final r = baseR * (0.85 + rng.nextDouble() * 0.30);

      planets.add(CosmicPlanet(element: elem, position: pos, radius: r));
    }

    // ── Rift portals (one per faction, scattered like planets) ──
    const factions = ['volcanic', 'oceanic', 'verdant', 'earthen', 'arcane'];
    final allPositions = planets.map((p) => p.position).toList();
    final rifts = <RiftPortal>[];
    for (final f in factions) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldW - margin * 2),
          margin + rng.nextDouble() * (worldH - margin * 2),
        );
        tries++;
      } while (tries < 300 &&
          (allPositions.any((p) => (p - pos).distance < minDist) ||
              rifts.any((r) => (r.position - pos).distance < minDist)));
      rifts.add(RiftPortal(faction: f, position: pos));
      allPositions.add(pos);
    }

    // ── Particle swarms (drifting elemental clouds) ──
    final swarmObstacles = <Offset>[
      ...allPositions,
      ...rifts.map((r) => r.position),
    ];
    final swarms = ParticleSwarm.generate(
      seed: rng.nextInt(1 << 30),
      worldSize: const Size(worldW, worldH),
      obstacles: swarmObstacles,
    );

    // ── Prismatic Field (aurora easter-egg) ──
    // Place it far from planets / rifts so it feels like a hidden anomaly.
    Offset prisPos;
    int ppTries = 0;
    do {
      prisPos = Offset(
        margin + rng.nextDouble() * (worldW - margin * 2),
        margin + rng.nextDouble() * (worldH - margin * 2),
      );
      ppTries++;
    } while (ppTries < 300 &&
        (allPositions.any((p) => (p - prisPos).distance < 4000) ||
            rifts.any((r) => (r.position - prisPos).distance < 4000)));

    final prismaticField = PrismaticField(position: prisPos, radius: 600);

    // ── Elemental Nexus (black portal easter-egg) ──
    // Place as far as possible from all planets.
    Offset nexusPos = Offset(margin, margin);
    double bestMinDist = 0;
    for (int attempt = 0; attempt < 2000; attempt++) {
      final candidate = Offset(
        margin + rng.nextDouble() * (worldW - margin * 2),
        margin + rng.nextDouble() * (worldH - margin * 2),
      );
      // Must be far from rifts & prismatic field
      if (rifts.any((r) => (r.position - candidate).distance < 5000)) continue;
      if ((prisPos - candidate).distance < 5000) continue;
      // Find the minimum distance to any planet
      double minPlanetDist = double.infinity;
      for (final p in allPositions) {
        final d = (p - candidate).distance;
        if (d < minPlanetDist) minPlanetDist = d;
      }
      // Keep the candidate that maximises the minimum planet distance
      if (minPlanetDist > bestMinDist) {
        bestMinDist = minPlanetDist;
        nexusPos = candidate;
      }
    }

    final elementalNexus = ElementalNexus(position: nexusPos);

    // ── Battle Ring (octagonal arena) ──
    // Place far from everything — same strategy as nexus.
    Offset ringPos = Offset(margin, margin);
    double bestRingDist = 0;
    for (int attempt = 0; attempt < 2000; attempt++) {
      final candidate = Offset(
        margin + rng.nextDouble() * (worldW - margin * 2),
        margin + rng.nextDouble() * (worldH - margin * 2),
      );
      if (rifts.any((r) => (r.position - candidate).distance < 5000)) continue;
      if ((prisPos - candidate).distance < 5000) continue;
      if ((nexusPos - candidate).distance < 5000) continue;
      double minD = double.infinity;
      for (final p in allPositions) {
        final d = (p - candidate).distance;
        if (d < minD) minD = d;
      }
      if (minD > bestRingDist) {
        bestRingDist = minD;
        ringPos = candidate;
      }
    }
    final battleRing = BattleRing(position: ringPos);

    // ── Blood Ring (ending ritual portal) ──
    // Place far from all landmarks so it feels like a hidden final destination.
    Offset bloodPos = Offset(margin, margin);
    double bestBloodDist = 0;
    for (int attempt = 0; attempt < 2000; attempt++) {
      final candidate = Offset(
        margin + rng.nextDouble() * (worldW - margin * 2),
        margin + rng.nextDouble() * (worldH - margin * 2),
      );
      if (rifts.any((r) => (r.position - candidate).distance < 5000)) continue;
      if ((prisPos - candidate).distance < 5000) continue;
      if ((nexusPos - candidate).distance < 5000) continue;
      if ((ringPos - candidate).distance < 5000) continue;
      double minD = double.infinity;
      for (final p in allPositions) {
        final d = (p - candidate).distance;
        if (d < minD) minD = d;
      }
      if (minD > bestBloodDist) {
        bestBloodDist = minD;
        bloodPos = candidate;
      }
    }
    final bloodRing = BloodRing(position: bloodPos);

    final contestObstacles = <Offset>[
      ...allPositions,
      ...rifts.map((r) => r.position),
      prisPos,
      nexusPos,
      ringPos,
      bloodPos,
    ];
    final contestArenas = generateCosmicContestArenas(
      seed: rng.nextInt(1 << 30),
      worldSize: const Size(worldW, worldH),
      obstacles: contestObstacles,
    );
    final contestHintNotes = generateCosmicContestHintNotes(
      seed: rng.nextInt(1 << 30),
      worldSize: const Size(worldW, worldH),
      obstacles: [...contestObstacles, ...contestArenas.map((a) => a.position)],
    );

    return CosmicWorld(
      planets: planets,
      worldSize: const Size(worldW, worldH),
      riftPortals: rifts,
      particleSwarms: swarms,
      prismaticField: prismaticField,
      elementalNexus: elementalNexus,
      battleRing: battleRing,
      bloodRing: bloodRing,
      contestArenas: contestArenas,
      contestHintNotes: contestHintNotes,
    );
  }

  int get discoveredCount => planets.where((p) => p.discovered).length;
  int get totalCount => planets.length;
}

// ─────────────────────────────────────────────────────────
// ELEMENT COLLECTION METER
// ─────────────────────────────────────────────────────────

/// Tracks collected elemental particles and resolves them into a resulting
/// element type using the recipe system.
class ElementMeter {
  final Map<String, double> _collected = {};

  /// Max capacity — once total reaches this, the meter is full.
  static const double maxCapacity = 100.0;

  double get total => _collected.values.fold(0.0, (s, v) => s + v);
  bool get isFull => total >= maxCapacity;
  double get fillPct => (total / maxCapacity).clamp(0.0, 1.0);

  Map<String, double> get breakdown => Map.unmodifiable(_collected);

  void add(String element, double amount) {
    _collected[element] = (_collected[element] ?? 0) + amount;
    // Clamp total
    final t = total;
    if (t > maxCapacity) {
      final scale = maxCapacity / t;
      for (final k in _collected.keys.toList()) {
        _collected[k] = _collected[k]! * scale;
      }
    }
  }

  /// Remove all of a specific element from the meter.
  void removeElement(String element) {
    _collected.remove(element);
  }

  void reset() => _collected.clear();

  /// Resolve the dominant element. If a single element dominates (>50%), use
  /// it directly. Otherwise combine the top two elements to look up a recipe.
  /// Returns the element name.
  String resolveElement(Map<String, Map<String, int>>? recipes) {
    if (_collected.isEmpty) return 'Fire'; // fallback

    // Sort by amount descending
    final sorted = _collected.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = sorted.first;

    // If one element is >60% of total, it wins outright
    if (top.value / total > 0.6) return top.key;

    // Otherwise combine top two via recipe
    if (sorted.length >= 2 && recipes != null) {
      final a = sorted[0].key;
      final b = sorted[1].key;
      final key = _recipeKey(a, b);
      final recipe = recipes[key];
      if (recipe != null && recipe.isNotEmpty) {
        // Weighted roll from recipe outcomes
        return _weightedPick(recipe);
      }
    }

    return top.key;
  }

  /// Get the biome scene-key for a resolved element.
  static String sceneKeyForElement(String element) {
    final group = elementalGroupFromElementType(element);
    return switch (group) {
      ElementalGroup.volcanic => 'volcano',
      ElementalGroup.oceanic => 'swamp',
      ElementalGroup.earthen => 'valley',
      ElementalGroup.verdant => 'sky',
      ElementalGroup.arcane => 'arcane',
    };
  }

  static String _recipeKey(String a, String b) {
    final x = a.trim(), y = b.trim();
    return (x.compareTo(y) <= 0) ? '$x+$y' : '$y+$x';
  }

  static String _weightedPick(Map<String, int> dist) {
    final rng = Random();
    final totalW = dist.values.fold(0, (s, v) => s + v);
    var roll = rng.nextInt(totalW);
    for (final e in dist.entries) {
      roll -= e.value;
      if (roll < 0) return e.key;
    }
    return dist.keys.first;
  }
}

/// Map an element type string to its faction name (for portal keys / harvesters).
String factionForElement(String element) {
  final group = elementalGroupFromElementType(element);
  return switch (group) {
    ElementalGroup.volcanic => 'volcanic',
    ElementalGroup.oceanic => 'oceanic',
    ElementalGroup.earthen => 'earthen',
    ElementalGroup.verdant => 'verdant',
    ElementalGroup.arcane => 'arcane',
  };
}

// ─────────────────────────────────────────────────────────
// FOG-OF-WAR PERSISTENCE
// ─────────────────────────────────────────────────────────

/// Serialise / deserialise fog state to a compact string for SharedPreferences.
/// Now persists:
///   - worldSeed
///   - discovered planet indices
///   - ALL revealed fog-grid cells
///   - ship position
class CosmicFogState {
  final int worldSeed;
  final Set<int> discoveredIndices;
  final Set<int> discoveredPoiIndices;
  final Set<int> discoveredContestArenaIndices;
  final Set<int> revealedCells;
  final double shipX;
  final double shipY;

  const CosmicFogState({
    required this.worldSeed,
    required this.discoveredIndices,
    this.discoveredPoiIndices = const {},
    this.discoveredContestArenaIndices = const {},
    this.revealedCells = const {},
    this.shipX = -1,
    this.shipY = -1,
  });

  /// Format:
  /// seed|planetIndices|shipX,shipY|revealedCells|poiIndices|contestArenaIndices
  String serialise() {
    final pIndices = (discoveredIndices.toList()..sort()).join(',');
    final poiIndices = (discoveredPoiIndices.toList()..sort()).join(',');
    final contestIndices = (discoveredContestArenaIndices.toList()..sort())
        .join(',');
    final ship = '${shipX.toStringAsFixed(1)},${shipY.toStringAsFixed(1)}';
    // Encode revealedCells as sorted, delta-encoded ints for compactness
    final sorted = revealedCells.toList()..sort();
    final buf = StringBuffer();
    int prev = 0;
    for (var i = 0; i < sorted.length; i++) {
      if (i > 0) buf.write(',');
      buf.write(sorted[i] - prev);
      prev = sorted[i];
    }
    return '$worldSeed|$pIndices|$ship|$buf|$poiIndices|$contestIndices';
  }

  factory CosmicFogState.deserialise(String raw) {
    final parts = raw.split('|');
    final seed = int.tryParse(parts[0]) ?? 0;
    final pIndices = parts.length > 1 && parts[1].isNotEmpty
        ? parts[1].split(',').map(int.parse).toSet()
        : <int>{};

    double sx = -1, sy = -1;
    if (parts.length > 2 && parts[2].isNotEmpty) {
      final sp = parts[2].split(',');
      if (sp.length == 2) {
        sx = double.tryParse(sp[0]) ?? -1;
        sy = double.tryParse(sp[1]) ?? -1;
      }
    }

    final cells = <int>{};
    if (parts.length > 3 && parts[3].isNotEmpty) {
      int running = 0;
      for (final d in parts[3].split(',')) {
        running += int.tryParse(d) ?? 0;
        cells.add(running);
      }
    }

    final poiIndices = parts.length > 4 && parts[4].isNotEmpty
        ? parts[4].split(',').map(int.parse).toSet()
        : <int>{};
    final contestIndices = parts.length > 5 && parts[5].isNotEmpty
        ? parts[5].split(',').map(int.parse).toSet()
        : <int>{};

    return CosmicFogState(
      worldSeed: seed,
      discoveredIndices: pIndices,
      discoveredPoiIndices: poiIndices,
      discoveredContestArenaIndices: contestIndices,
      revealedCells: cells,
      shipX: sx,
      shipY: sy,
    );
  }

  factory CosmicFogState.fresh(int seed) =>
      CosmicFogState(worldSeed: seed, discoveredIndices: {});
}

// ─────────────────────────────────────────────────────────
// PLANET RECIPE
// ─────────────────────────────────────────────────────────

/// A recipe specifying the element composition needed to summon a creature
/// at a particular planet. The player must collect the right mix of particles.
class PlanetRecipe {
  final String planetElement;
  final int level; // 1..3
  final Map<String, double> components; // element -> target %
  final double randomPct; // % that can be any element

  const PlanetRecipe({
    required this.planetElement,
    required this.level,
    required this.components,
    required this.randomPct,
  });

  /// Generate a deterministic recipe for [element] at [level] (1..3).
  factory PlanetRecipe.generate({
    required String element,
    required int seed,
    required int level,
  }) {
    final recipeLevel = level.clamp(1, 3);
    final rng = Random(seed ^ (element.hashCode * 31 + recipeLevel * 997));
    final others = kElementColors.keys.where((e) => e != element).toList()
      ..shuffle(rng);

    // Difficulty curve:
    // L1: 1-2 total ingredients, L2: 2-3, L3: 3-4.
    final nSec = switch (recipeLevel) {
      1 => rng.nextBool() ? 0 : 1,
      2 => rng.nextBool() ? 1 : 2,
      _ => rng.nextBool() ? 2 : 3,
    };

    // Raw weights → normalised later
    final weights = <String, int>{};
    weights[element] = nSec == 0 ? 88 + rng.nextInt(13) : 36 + rng.nextInt(18);
    for (var i = 0; i < nSec; i++) {
      final maxW = switch (recipeLevel) {
        1 => i == 0 ? 24 : 14,
        2 => i == 0 ? 28 : 20,
        _ => i == 0 ? 30 : 22,
      };
      weights[others[i]] = 5 + rng.nextInt(maxW);
    }
    final randomW = switch (recipeLevel) {
      1 => 4 + rng.nextInt(8),
      2 => 3 + rng.nextInt(7),
      _ => 2 + rng.nextInt(6),
    };
    final totalW = weights.values.fold(0, (s, v) => s + v) + randomW;

    final components = <String, double>{};
    for (final e in weights.entries) {
      components[e.key] = (e.value / totalW * 100).roundToDouble();
    }
    final assignedPct = components.values.fold(0.0, (s, v) => s + v);

    return PlanetRecipe(
      planetElement: element,
      level: recipeLevel,
      components: components,
      randomPct: max(0, 100.0 - assignedPct),
    );
  }

  /// Build a recipe whose composition reflects an authored entry trio (the
  /// element multiset of creatures required to enter the planet). The planet's
  /// home element is weighted slightly higher; higher [level] tightens the
  /// random-tolerance band. Used for dungeon-gated planets in place of
  /// [PlanetRecipe.generate].
  factory PlanetRecipe.fromEntryRequirement({
    required String element,
    required List<String> slots,
    required int level,
  }) {
    final recipeLevel = level.clamp(1, 3);

    // Count element occurrences in the required trio.
    final counts = <String, double>{};
    for (final e in slots) {
      counts[e] = (counts[e] ?? 0) + 1.0;
    }

    // Weight by count, nudging the planet's home element up.
    final weights = <String, double>{};
    counts.forEach((e, c) {
      weights[e] = c * (e == element ? 1.4 : 1.0);
    });

    final randomPct = switch (recipeLevel) {
      1 => 10.0,
      2 => 7.0,
      _ => 5.0,
    };
    final assignable = 100.0 - randomPct;
    final totalW = weights.values.fold(0.0, (s, v) => s + v);

    final components = <String, double>{};
    for (final e in weights.entries) {
      components[e.key] = (e.value / totalW * assignable).roundToDouble();
    }
    final assigned = components.values.fold(0.0, (s, v) => s + v);

    return PlanetRecipe(
      planetElement: element,
      level: recipeLevel,
      components: components,
      randomPct: max(0.0, 100.0 - assigned),
    );
  }

  /// Match score 0.0 – 1.0. 1.0 = perfect match.
  double matchScore(Map<String, double> meterBreakdown, double meterTotal) {
    if (meterTotal <= 0) return 0;

    final pcts = <String, double>{};
    for (final e in meterBreakdown.entries) {
      pcts[e.key] = (e.value / meterTotal) * 100;
    }

    double diff = 0;
    for (final e in components.entries) {
      diff += ((pcts[e.key] ?? 0) - e.value).abs();
    }

    double nonRecipe = 0;
    for (final e in pcts.entries) {
      if (!components.containsKey(e.key)) nonRecipe += e.value;
    }
    diff += max(0.0, nonRecipe - randomPct);

    return (1.0 - diff / 100).clamp(0.0, 1.0);
  }

  /// Whether the meter matches closely enough to summon (≥ 70 %).
  bool matches(Map<String, double> meterBreakdown, double meterTotal) =>
      matchScore(meterBreakdown, meterTotal) >= 0.70;
}

// ─────────────────────────────────────────────────────────
// PLANET DUNGEON ENTRY GATING
// ─────────────────────────────────────────────────────────

/// Authored dungeon-entry requirements, keyed by planet element. The value is
/// the multiset of creature *elements* the player must be carrying (orbiting
/// the ship) for the planet's recipe to reveal and the dungeon to be enterable.
/// Only listed planets are gated; planets absent from this map behave as before.
const Map<String, List<String>> kCosmicPlanetEntry = {
  // Air pilot: 2 verbs need Air (Wing flight) + Lightning (storm runes / Horn
  // channel) + Fire (air+fire→electricity combo). See `project-planet-dungeons`.
  'Air': ['Air', 'Lightning', 'Fire'],
  // Cinder Cathedral: Fire (braziers / censers / hearth) + Air (gusts carry
  // the vesper flame) + Plant (vines for the ash garden; Plant+Fire→Dust).
  'Fire': ['Fire', 'Air', 'Plant'],
  // Mirror-Tide Temple: Water (valves / fountain / tide) + Spirit (ghost
  // currents, moon-truth; Spirit+Water→Ice) + Ice (freeze the moon-pools).
  'Water': ['Water', 'Spirit', 'Ice'],
  // Buried Giant: Earth (rib shoves / the lintel) + Lightning (arc the
  // buried sockets; Earth+Lightning→Crystal) + Crystal (locks direct, reads
  // the eye).
  'Earth': ['Earth', 'Lightning', 'Crystal'],
  // Storm Circuit (Voltara): Lightning (Horn charges the dead pylons + holds
  // the channel) + Air (Wing herds the high storm-cells) + Fire (heats the
  // anvil; Air+Fire→Lightning births the Thundercloud source).
  'Lightning': ['Lightning', 'Air', 'Fire'],
  // Molten Labyrinth (Vaporis): Steam (Pip cools running lava to standing rock
  // and halts its creep) + Earth (Horn dams the flood with raised walls) + Fire
  // (Earth+Fire→Lava melts rock to molten). Each room is a spreading-lava grid.
  'Steam': ['Steam', 'Earth', 'Fire'],
  // Venom Monastery (Toxica): Poison (the wax seals, the pot, the physic) +
  // Plant (a horn roots the charnel's brick apart) + Mud (a mane's trail
  // carries a live brew clean through a ward). These three are also the
  // CAULDRON'S ENTIRE LARDER — the three plagues want Poison+Plant,
  // Plant+Mud and Poison+Mud — so the trio is not flavour here: bring a hand
  // the pot cannot drink and a brew becomes impossible.
  'Poison': ['Poison', 'Plant', 'Mud'],
  // Frozen Observatory (Glacius): Ice (freezes flues into stairs, glazes the
  // orrery floor, silvers the mirrors) + Light (melts the mouth's ice cap,
  // thaws a glaze, and its Mask strikes the lodestone) + Air (sweeps the
  // gallery's thaw back and turns the rite's last breath down the throat).
  'Ice': ['Ice', 'Light', 'Air'],
  // Molten Reliquary (Magmora): Lava (the crucible tap, and melting a bad
  // casting back out) + Earth (the points levers, and the works' manifest) +
  // Ice (a mane sets a running pour where it stands). Ice+Lava→Steam drives
  // the mill's dead die.
  'Lava': ['Lava', 'Earth', 'Ice'],
  // The Sinking Altar (Palusia): Mud (drags a ford to sod, wallows down to
  // the fane, frees the sough) + Plant (roots; Plant+Mud→Poison eats the
  // socket's resin cap) + Water (sluices the gate's weed, fills the moor
  // basins, and its Mask finds the one under black water). Plant+Water→Mud
  // is the braid that drags a ford when no Mud hand is free.
  'Mud': ['Mud', 'Plant', 'Water'],
  // Ruins of Time (Sablis): Dust (parts the silted arch, turns the great
  // glass, and its own spade digs the city) + Air (the tower's vanes call the
  // levelling sirocco, gusts scour the drift yard, and its Wing crosses the
  // observatory's roofless span) + Earth (the other spade, and its Horn puts
  // a shoulder through the court's false wall). Air+Earth->Dust stands in as
  // a braid when the Dust hand is down.
  'Dust': ['Dust', 'Air', 'Earth'],
  // Prism Labyrinth (Vitrea): Crystal (the shunt — the planet's only verb —
  // the tuning bosses, and the facet font) + Lightning (a horn strikes the
  // hearth's cold shard warm) + Spirit (a pip slips the crack behind the
  // keep). **Crystal+Spirit→Light** is the planet's own braid and kindles the
  // west lamp; **Lightning+Crystal→Spirit** stands in for a Spirit hand that
  // is down.
  'Crystal': ['Crystal', 'Lightning', 'Spirit'],
  // Verdant Crypt (Verdanthos): Plant (unknots the lich-gate briar, quickens
  // the boles that change your size, and sets every seed) + Light (relights
  // the grave-lamps, and its Mask shows the heart-seed a sun the crypt has
  // not had in an age) + Mud (loams the growth altar, cracks the sepulchre's
  // clay, and turns the mulch pits that call the withering). Mud+Light→Plant
  // is the braid that plants when no Plant hand is free.
  'Plant': ['Plant', 'Light', 'Mud'],
  // Echo Grave (Requia): Spirit (the lych-stones that pass the party over, and
  // the telling that finishes a death) + Water (draws the black water off the
  // gate arch, and its Pip sets the sigil's mark) + Crystal (the grave-lamp,
  // element-only). **Spirit+Water→Ice** settles the drowned cut into a road
  // the living can take; **Crystal+Spirit→Light** is what makes a light in a
  // place that has never had one.
  'Spirit': ['Spirit', 'Water', 'Crystal'],
  // Eclipse Vault (Nythralor): Dark (draws the pall, turns every gnomon —
  // the planet's whole verb — seats two of the analemma's stones, and its
  // Mask reads the nave's black reredos) + Poison (seats the ossuary stone,
  // and its Pip eats the rust out of the shadow-anchors) + Spirit (seats the
  // gallery stone and reads where an anchor's far end comes out).
  // Poison+Spirit→Dark is the braid that snuffs the nave's lamps when no
  // Dark hand is free.
  'Dark': ['Dark', 'Poison', 'Spirit'],
  // Beacon Archive (Solarin): Light (kindles, aims and pitches every beacon —
  // the planet's whole verb — reads two of the court's effigies, and works the
  // reading floor's shutter-ring) + Crystal (reads the scholar effigy, and its
  // Mask splits the prism oriel's one beam into the two the rite needs) +
  // Spirit (reads the warden effigy, and its Pip goes behind the shelves for
  // the slips). **Crystal+Spirit→Light** is the planet's own braid and works
  // the shutter-ring when no Light hand is free.
  'Light': ['Light', 'Crystal', 'Spirit'],
  // Sanguine Orrery (Hemavorn): Blood (the pericardium, two of the four
  // mouths, the rite's balance — and its Kin steadies the cannula in a wall
  // that will not hold still) + Dark (the arch mouth, and its Mask is the
  // only sight that can graft a dead vessel's unlit lumen) + Light (the weave
  // mouth, and it flags which collaterals are thrombosed before you open
  // one). **Dark+Light→Blood** is the planet's own braid and balances the
  // heart when no Blood hand is free.
  'Blood': ['Blood', 'Dark', 'Light'],
};

/// The IDEAL family for each of a planet's entry slots — index-aligned with
/// [kCosmicPlanetEntry], i.e. the §6 "ideal team" from docs/dungeons.md
/// (Air = Airwing/Lightninghorn/Firemask, and so on).
///
/// Element gets you in; the right family clears the hard gates (§4). This is
/// the trio a developer descent fabricates so every gate in the planet can be
/// exercised — it is NOT used by normal play, where the player brings whatever
/// they have bred.
const Map<String, List<String>> kDungeonIdealFamilies = {
  'Air': ['Wing', 'Horn', 'Mask'], // Airwing · Lightninghorn · Firemask
  'Fire': ['Mask', 'Wing', 'Mane'], // Firemask · Airwing · Plantmane
  'Water': ['Pip', 'Mask', 'Mane'], // Waterpip · Spiritmask · Icemane
  'Earth': ['Horn', 'Pip', 'Mask'], // Earthhorn · Lightningpip · Crystalmask
  'Lightning': ['Horn', 'Wing', 'Mask'], // Lightninghorn · Airwing · Firemask
  'Steam': ['Pip', 'Horn', 'Mask'], // Steampip · Earthhorn · Firemask
  'Poison': ['Mask', 'Horn', 'Mane'], // Poisonmask · Planthorn · Mudmane
  'Ice': ['Mane', 'Mask', 'Wing'], // Icemane · Lightmask · Airwing
  'Lava': ['Horn', 'Mask', 'Mane'], // Lavahorn · Earthmask · Icemane
  'Mud': ['Mane', 'Pip', 'Mask'], // Mudmane · Plantpip · Watermask
  'Dust': ['Mask', 'Wing', 'Horn'], // Dustmask · Airwing · Earthhorn
  'Crystal': ['Mask', 'Horn', 'Pip'], // Crystalmask · Lightninghorn · Spiritpip
  'Plant': ['Mane', 'Mask', 'Pip'], // Plantmane · Lightmask · Mudpip
  'Spirit': ['Mask', 'Pip', 'Wing'], // Spiritmask · Waterpip · Crystalwing
  'Dark': ['Mask', 'Pip', 'Mane'], // Darkmask · Poisonpip · Spiritmane
  'Light': ['Mask', 'Mask', 'Pip'], // Lightmask · Crystalmask · Spiritpip
  'Blood': ['Mane', 'Mask', 'Mask'], // Bloodmane · Darkmask · Lightmask
};

/// Planets whose descent is planned but whose dungeon isn't built yet. They
/// still carry the gate ritual — the player can complete the offering and
/// unseal them — but instead of a DESCEND action they show a "descent coming
/// soon" placard. Move an element OUT of here and into [kCosmicPlanetEntry] +
/// [kPlanetDungeonLayouts] once its dungeon is authored.
///
/// **EMPTY since 2026-08-25.** Blood was the seventeenth and last dungeon;
/// every planet is now built. The set stays as the mechanism (it is what
/// [isDungeonGatePlanet] and the placard branch read), and the roster tests
/// keep pinning `built + coming-soon == 17` — which now holds with nothing on
/// this side of the sum.
const Set<String> kComingSoonDungeons = <String>{};

/// True if [element]'s planet uses the gate ritual at all — whether its dungeon
/// is built ([kCosmicPlanetEntry]) or merely coming soon ([kComingSoonDungeons]).
/// Gate planets replace the normal summon/pathway flow with an unseal offering.
bool isDungeonGatePlanet(String element) =>
    kCosmicPlanetEntry.containsKey(element) ||
    kComingSoonDungeons.contains(element);

/// The campaign's terminal planet (Hemavorn). Its gate is the FINAL one: it
/// only opens once every other planet's guardian has fallen, and entering its
/// dungeon is the sole path to the Blood Mystic (Sanguorath) → the Blood Ring.
const String kBloodPlanetElement = 'Blood';

/// How many planets are NOT the Blood planet — i.e. how many guardians must
/// fall before Hemavorn answers. Derived so it tracks the planet roster.
final int kNonBloodPlanetCount =
    kCosmicPlanetEntry.length + kComingSoonDungeons.length - 1;

/// One thing a planet demands of the descent party that the raw element
/// multiset cannot express: a specific family, sometimes pinned to a specific
/// element as well.
class DungeonEntryDemand {
  const DungeonEntryDemand({
    required this.family,
    this.element,
    required this.label,
  });

  /// Family name as the roster spells it ('Horn', 'Wing', ...).
  final String family;

  /// Element the family must also be, or null when any element will do.
  final String? element;

  /// Descent-panel text: 'Lightning HORN' or 'any HORN'.
  final String label;

  bool satisfiedBy(Iterable<CosmicPartyMember?> party) {
    final want = family.toLowerCase();
    for (final m in party) {
      if (m == null) continue;
      if (m.family.toLowerCase() != want) continue;
      if (element != null && m.element != element) continue;
      return true;
    }
    return false;
  }
}

/// True if [party] (the orbiting roster) contains at least the multiset of
/// elements in [required]. Extra creatures are fine; duplicates in [required]
/// must each be matched by a distinct party member of that element.
bool cosmicPartySatisfiesEntry(
  Iterable<CosmicPartyMember?> party,
  List<String> required,
) {
  final have = <String, int>{};
  for (final m in party) {
    if (m == null) continue;
    have[m.element] = (have[m.element] ?? 0) + 1;
  }
  final need = <String, int>{};
  for (final e in required) {
    need[e] = (need[e] ?? 0) + 1;
  }
  for (final e in need.entries) {
    if ((have[e.key] ?? 0) < e.value) return false;
  }
  return true;
}

// ─────────────────────────────────────────────────────────
// PLANET STAR STATE PERSISTENCE
// ─────────────────────────────────────────────────────────

/// Tracks dungeon stars per planet. Each planet has up to 3 stars as a 3-bit
/// mask (bit0=Star1…bit2=Star3). [starMasks] = stars EARNED; [claimedMasks] =
/// stars whose end-of-run REWARD has been granted (so rewards grant once even
/// across multiple runs). See `project-planet-dungeons`.
class PlanetStarState {
  final Map<String, int> starMasks; // element -> earned mask (0..7)
  final Map<String, int> claimedMasks; // element -> reward-claimed mask (0..7)
  final Map<String, Set<String>>
  discoveredCloudIds; // element -> discovered dungeon cloud ids

  const PlanetStarState({
    required this.starMasks,
    this.claimedMasks = const {},
    this.discoveredCloudIds = const {},
  });

  factory PlanetStarState.fresh() => const PlanetStarState(
    starMasks: {},
    claimedMasks: {},
    discoveredCloudIds: {},
  );

  int starMaskFor(String element) => (starMasks[element] ?? 0) & 0x7;
  int claimedMaskFor(String element) => (claimedMasks[element] ?? 0) & 0x7;
  Set<String> discoveredCloudsFor(String element) =>
      Set.unmodifiable(discoveredCloudIds[element] ?? const <String>{});

  int starsEarned(String element) {
    final mask = starMaskFor(element);
    return ((mask & 1) >> 0) + ((mask & 2) >> 1) + ((mask & 4) >> 2);
  }

  bool hasStar(String element, int index) {
    if (index < 0 || index > 2) return false;
    return (starMaskFor(element) & (1 << index)) != 0;
  }

  bool hasClaimed(String element, int index) {
    if (index < 0 || index > 2) return false;
    return (claimedMaskFor(element) & (1 << index)) != 0;
  }

  /// How many planets' guardians (Star 3) have fallen — the campaign's
  /// difficulty clock. [excluding] leaves out one element (pass the planet
  /// being entered so its own past clear doesn't double-count itself).
  int guardiansDefeated({String? excluding}) {
    var n = 0;
    for (final el in starMasks.keys) {
      if (el == excluding) continue;
      if (hasStar(el, 2)) n++;
    }
    return n;
  }

  /// Earned but not-yet-claimed star indices for [element].
  List<int> pendingRewards(String element) => [
    for (var i = 0; i < 3; i++)
      if (hasStar(element, i) && !hasClaimed(element, i)) i,
  ];

  /// Returns a new state with star [index] (0..2) set for [element].
  PlanetStarState withStar(String element, int index) {
    if (index < 0 || index > 2) return this;
    final updated = Map<String, int>.from(starMasks);
    updated[element] = (starMaskFor(element) | (1 << index)) & 0x7;
    return PlanetStarState(
      starMasks: updated,
      claimedMasks: claimedMasks,
      discoveredCloudIds: discoveredCloudIds,
    );
  }

  /// Returns a new state marking star [index]'s reward as claimed for [element].
  PlanetStarState withClaimed(String element, int index) {
    if (index < 0 || index > 2) return this;
    final updated = Map<String, int>.from(claimedMasks);
    updated[element] = (claimedMaskFor(element) | (1 << index)) & 0x7;
    return PlanetStarState(
      starMasks: starMasks,
      claimedMasks: updated,
      discoveredCloudIds: discoveredCloudIds,
    );
  }

  /// Returns a new state with [cloudId] marked discovered for [element].
  PlanetStarState withDiscoveredCloud(String element, String cloudId) {
    if (cloudId.isEmpty) return this;
    final updated = <String, Set<String>>{
      for (final entry in discoveredCloudIds.entries)
        entry.key: Set<String>.from(entry.value),
    };
    updated.putIfAbsent(element, () => <String>{}).add(cloudId);
    return PlanetStarState(
      starMasks: starMasks,
      claimedMasks: claimedMasks,
      discoveredCloudIds: updated,
    );
  }

  String serialise() {
    final keys = <String>{
      ...starMasks.keys,
      ...claimedMasks.keys,
      ...discoveredCloudIds.keys,
    }.toList()..sort();
    return keys
        .where(
          (k) =>
              starMaskFor(k) != 0 ||
              claimedMaskFor(k) != 0 ||
              discoveredCloudsFor(k).isNotEmpty,
        )
        .map((k) {
          final clouds = discoveredCloudsFor(k).toList()..sort();
          final suffix = clouds.isEmpty ? '' : '.${clouds.join('|')}';
          return '$k=${starMaskFor(k)}.${claimedMaskFor(k)}$suffix';
        })
        .join(',');
  }

  factory PlanetStarState.deserialise(String raw) {
    if (raw.isEmpty) return PlanetStarState.fresh();
    final masks = <String, int>{};
    final claimed = <String, int>{};
    final clouds = <String, Set<String>>{};
    for (final part in raw.split(',')) {
      final kv = part.split('=');
      if (kv.length != 2) continue;
      // New format "earned.claimed.cloud|ids"; old formats are "earned" and
      // "earned.claimed".
      final segs = kv[1].split('.');
      final mask = (int.tryParse(segs[0]) ?? 0) & 0x7;
      final claim = segs.length > 1 ? (int.tryParse(segs[1]) ?? 0) & 0x7 : 0;
      final discovered = segs.length > 2
          ? segs[2]
                .split('|')
                .where((id) => id.trim().isNotEmpty)
                .map((id) => id.trim())
                .toSet()
          : <String>{};
      if (mask != 0) masks[kv[0]] = mask;
      if (claim != 0) claimed[kv[0]] = claim;
      if (discovered.isNotEmpty) clouds[kv[0]] = discovered;
    }
    return PlanetStarState(
      starMasks: masks,
      claimedMasks: claimed,
      discoveredCloudIds: clouds,
    );
  }
}

// ─────────────────────────────────────────────────────────
// ELEMENT PARTICLE STORAGE
// ─────────────────────────────────────────────────────────

/// Banked elemental particles for later use. Requires the Element Container.
class ElementStorage {
  final Map<String, double> stored;

  ElementStorage({Map<String, double>? stored}) : stored = stored ?? {};

  double get total => stored.values.fold(0.0, (s, v) => s + v);

  void addAll(Map<String, double> particles) {
    for (final e in particles.entries) {
      stored[e.key] = (stored[e.key] ?? 0) + e.value;
    }
  }

  String serialise() => stored.entries
      .where((e) => e.value > 0)
      .map((e) => '${e.key}:${e.value.toStringAsFixed(1)}')
      .join(',');

  factory ElementStorage.deserialise(String raw) {
    if (raw.isEmpty) return ElementStorage();
    final map = <String, double>{};
    for (final part in raw.split(',')) {
      final kv = part.split(':');
      if (kv.length == 2) map[kv[0]] = double.tryParse(kv[1]) ?? 0;
    }
    return ElementStorage(stored: map);
  }
}

// ─────────────────────────────────────────────────────────
// HOME PLANET
// ─────────────────────────────────────────────────────────

/// Data model for the player's personal home planet.
/// Built at the ship's current position — only one per world.
class HomePlanet {
  Offset position;
  double radius;
  Map<String, double> colorMix; // element -> amount (determines color)
  int astralBank; // banked Astral Shards
  int sizeTierLevel; // max unlocked tier: 0=Tiny,1=Small,2=Medium,3=Big,4=Huge
  int activeSizeTier; // currently selected tier (≤ sizeTierLevel)
  String? activeColor; // selected element color (null = default gray)
  Set<String> unlockedColors; // element names whose colors have been purchased

  /// Cost in elements to unlock a color.
  static const int colorUnlockCost = 100;

  /// Shard cost to upgrade TO each tier index.
  static const List<int> tierUpgradeCosts = [0, 50, 150, 400, 1000];
  static const List<String> tierNames = [
    'Tiny',
    'Small',
    'Medium',
    'Big',
    'Huge',
  ];

  HomePlanet({
    required this.position,
    this.radius = 80,
    Map<String, double>? colorMix,
    this.astralBank = 0,
    this.sizeTierLevel = 0,
    int? activeSizeTier,
    this.activeColor,
    Set<String>? unlockedColors,
  }) : colorMix = colorMix ?? {},
       activeSizeTier = activeSizeTier ?? 0,
       unlockedColors = unlockedColors ?? {};

  /// Planet color — uses selected element color, or default gray.
  Color get blendedColor {
    if (activeColor != null && kElementColors.containsKey(activeColor)) {
      return kElementColors[activeColor]!;
    }
    return const Color(0xFF607D8B); // default gray
  }

  /// Visual growth: radius based on the *active* (selected) tier.
  /// Tiny→40, Small→80, Medium→130, Big→185, Huge→250.
  double get visualRadius {
    return switch (activeSizeTier.clamp(0, 4)) {
      0 => 40.0,
      1 => 80.0,
      2 => 130.0,
      3 => 185.0,
      _ => 250.0,
    };
  }

  /// Current (active) size tier name.
  String get sizeTier => tierNames[activeSizeTier.clamp(0, 4)];

  /// The index (0-4) of the active size tier.
  int get sizeTierIndex => activeSizeTier.clamp(0, 4);

  /// Cost in shards to upgrade to the next tier, or null if already max.
  int? get nextTierCost {
    if (sizeTierLevel >= 4) return null;
    return tierUpgradeCosts[sizeTierLevel + 1];
  }

  String serialise() {
    final parts = <String>[];
    parts.add(
      '${position.dx.toStringAsFixed(1)},${position.dy.toStringAsFixed(1)}',
    );
    parts.add(radius.toStringAsFixed(1));
    parts.add(
      colorMix.entries
          .where((e) => e.value > 0)
          .map((e) => '${e.key}=${e.value.toStringAsFixed(1)}')
          .join(';'),
    );
    parts.add(astralBank.toString());
    parts.add(sizeTierLevel.toString());
    parts.add(activeSizeTier.toString());
    parts.add(activeColor ?? '');
    parts.add(unlockedColors.join(','));
    return parts.join('|');
  }

  factory HomePlanet.deserialise(String raw) {
    final parts = raw.split('|');
    if (parts.length < 3) {
      return HomePlanet(position: const Offset(12000, 12000));
    }
    final posParts = parts[0].split(',');
    final pos = Offset(
      double.tryParse(posParts[0]) ?? 12000,
      double.tryParse(posParts[1]) ?? 12000,
    );
    final radius = double.tryParse(parts[1]) ?? 80;
    final colorMix = <String, double>{};
    if (parts[2].isNotEmpty) {
      for (final kv in parts[2].split(';')) {
        final pair = kv.split('=');
        if (pair.length == 2) {
          colorMix[pair[0]] = double.tryParse(pair[1]) ?? 0;
        }
      }
    }
    final bank = parts.length > 3 ? (int.tryParse(parts[3]) ?? 0) : 0;
    final tier = parts.length > 4 ? (int.tryParse(parts[4]) ?? 0) : 0;
    final active = parts.length > 5 ? (int.tryParse(parts[5]) ?? tier) : tier;
    final colorStr = parts.length > 6 ? parts[6] : '';
    final unlockedStr = parts.length > 7 ? parts[7] : '';
    final unlocked = unlockedStr.isNotEmpty
        ? unlockedStr.split(',').toSet()
        : <String>{};
    return HomePlanet(
      position: pos,
      radius: radius,
      colorMix: colorMix,
      astralBank: bank,
      sizeTierLevel: tier,
      activeSizeTier: active,
      activeColor: colorStr.isNotEmpty ? colorStr : null,
      unlockedColors: unlocked,
    );
  }
}

const int kHomeGarrisonMaxSlots = 9;
const List<int> kHomeGarrisonSlotsByTier = [1, 3, 4, 7, 9];
const List<double> _kHomeGarrisonBaseAngles = [-pi / 2, pi / 6, 5 * pi / 6];

int homeGarrisonSlotsForTier(int activeSizeTier) {
  final tier = activeSizeTier.clamp(0, kHomeGarrisonSlotsByTier.length - 1);
  return kHomeGarrisonSlotsByTier[tier];
}

int homeGarrisonLayerForSlot(int slotIndex) {
  final clamped = slotIndex.clamp(0, kHomeGarrisonMaxSlots - 1);
  return clamped ~/ 3;
}

double homeGarrisonOrbitAngleForSlot(int slotIndex) {
  final clamped = slotIndex.clamp(0, kHomeGarrisonMaxSlots - 1);
  return _kHomeGarrisonBaseAngles[clamped % 3];
}

double homeGarrisonOrbitRadiusForSlot({
  required HomePlanet homePlanet,
  required int slotIndex,
}) {
  final vr = homePlanet.visualRadius;
  final innerRing = vr + 34.0;
  final effectEdge = vr + (vr * 3.5);

  return switch (homeGarrisonLayerForSlot(slotIndex)) {
    0 => innerRing,
    1 => lerpDouble(innerRing, effectEdge, 0.4)!,
    _ => lerpDouble(innerRing, effectEdge, 0.8)!,
  };
}

// ─────────────────────────────────────────────────────────
// HOME CUSTOMIZATION RECIPES
// ─────────────────────────────────────────────────────────

/// Category of a home customization recipe.
enum HomeRecipeCategory { visual, ammo, upgrade, equipment }

/// A single tuneable parameter for a visual customization.
class CustomizationParam {
  final String key;
  final String label;
  final List<String> options;
  final String defaultValue;

  const CustomizationParam({
    required this.key,
    required this.label,
    required this.options,
    required this.defaultValue,
  });
}

/// Per-recipe sub-customization options. Only visual recipes with
/// tuneable parameters appear here.
const Map<String, List<CustomizationParam>> kRecipeParams = {
  'flame_ring': [
    CustomizationParam(
      key: 'intensity',
      label: 'Intensity',
      options: ['Dim', 'Normal', 'Bright'],
      defaultValue: 'Normal',
    ),
    CustomizationParam(
      key: 'speed',
      label: 'Speed',
      options: ['Slow', 'Normal', 'Fast'],
      defaultValue: 'Normal',
    ),
  ],
  'vine_tendrils': [
    CustomizationParam(
      key: 'length',
      label: 'Length',
      options: ['Short', 'Medium', 'Long'],
      defaultValue: 'Medium',
    ),
    CustomizationParam(
      key: 'count',
      label: 'Count',
      options: ['Few', 'Some', 'Many'],
      defaultValue: 'Some',
    ),
  ],
  'crystal_spires': [
    CustomizationParam(
      key: 'height',
      label: 'Height',
      options: ['Short', 'Medium', 'Tall'],
      defaultValue: 'Medium',
    ),
    CustomizationParam(
      key: 'density',
      label: 'Density',
      options: ['Sparse', 'Normal', 'Dense'],
      defaultValue: 'Normal',
    ),
  ],
  'dark_void': [
    CustomizationParam(
      key: 'layers',
      label: 'Layers',
      options: ['Thin', 'Normal', 'Deep'],
      defaultValue: 'Normal',
    ),
  ],
  'radiant_halo': [
    CustomizationParam(
      key: 'glow',
      label: 'Glow',
      options: ['Subtle', 'Normal', 'Blinding'],
      defaultValue: 'Normal',
    ),
    CustomizationParam(
      key: 'position',
      label: 'Position',
      options: ['Close', 'Mid', 'Outer'],
      defaultValue: 'Mid',
    ),
  ],
  'ocean_mist': [
    CustomizationParam(
      key: 'density',
      label: 'Density',
      options: ['Light', 'Normal', 'Heavy'],
      defaultValue: 'Normal',
    ),
    CustomizationParam(
      key: 'position',
      label: 'Position',
      options: ['Close', 'Mid', 'Outer'],
      defaultValue: 'Mid',
    ),
  ],
  'blood_moon': [
    CustomizationParam(
      key: 'pulse',
      label: 'Pulse',
      options: ['Gentle', 'Normal', 'Intense'],
      defaultValue: 'Normal',
    ),
    CustomizationParam(
      key: 'size',
      label: 'Moon Size',
      options: ['Small', 'Medium', 'Large'],
      defaultValue: 'Medium',
    ),
    CustomizationParam(
      key: 'distance',
      label: 'Orbit Distance',
      options: ['Close', 'Mid', 'Far'],
      defaultValue: 'Mid',
    ),
  ],
  'frozen_shell': [
    CustomizationParam(
      key: 'thickness',
      label: 'Thickness',
      options: ['Thin', 'Medium', 'Thick'],
      defaultValue: 'Medium',
    ),
  ],
  'poison_cloud': [
    CustomizationParam(
      key: 'spread',
      label: 'Spread',
      options: ['Tight', 'Normal', 'Wide'],
      defaultValue: 'Normal',
    ),
    CustomizationParam(
      key: 'position',
      label: 'Position',
      options: ['Close', 'Mid', 'Outer'],
      defaultValue: 'Mid',
    ),
  ],
  'dust_storm': [
    CustomizationParam(
      key: 'particles',
      label: 'Particles',
      options: ['Few', 'Normal', 'Swarm'],
      defaultValue: 'Normal',
    ),
    CustomizationParam(
      key: 'position',
      label: 'Position',
      options: ['Close', 'Mid', 'Outer'],
      defaultValue: 'Mid',
    ),
  ],
  'steam_vents': [
    CustomizationParam(
      key: 'jets',
      label: 'Jets',
      options: ['2', '4', '6'],
      defaultValue: '4',
    ),
  ],
  'lightning_rod': [
    CustomizationParam(
      key: 'frequency',
      label: 'Frequency',
      options: ['Rare', 'Normal', 'Frequent'],
      defaultValue: 'Normal',
    ),
  ],
  'spirit_wisps': [
    CustomizationParam(
      key: 'count',
      label: 'Count',
      options: ['Few', 'Some', 'Many'],
      defaultValue: 'Some',
    ),
    CustomizationParam(
      key: 'position',
      label: 'Position',
      options: ['Close', 'Mid', 'Outer'],
      defaultValue: 'Mid',
    ),
  ],
  'lava_moat': [
    CustomizationParam(
      key: 'width',
      label: 'Width',
      options: ['Thin', 'Normal', 'Wide'],
      defaultValue: 'Normal',
    ),
  ],
  'mud_fortress': [
    CustomizationParam(
      key: 'thickness',
      label: 'Thickness',
      options: ['Thin', 'Normal', 'Thick'],
      defaultValue: 'Normal',
    ),
  ],
  'natures_blessing': [
    CustomizationParam(
      key: 'brightness',
      label: 'Brightness',
      options: ['Dim', 'Normal', 'Bright'],
      defaultValue: 'Normal',
    ),
    CustomizationParam(
      key: 'position',
      label: 'Position',
      options: ['Close', 'Mid', 'Outer'],
      defaultValue: 'Mid',
    ),
  ],
  'orbiting_moon': [
    CustomizationParam(
      key: 'size',
      label: 'Moon Size',
      options: ['Small', 'Medium', 'Large'],
      defaultValue: 'Medium',
    ),
    CustomizationParam(
      key: 'speed',
      label: 'Orbit Speed',
      options: ['Slow', 'Normal', 'Fast'],
      defaultValue: 'Normal',
    ),
    CustomizationParam(
      key: 'distance',
      label: 'Orbit Distance',
      options: ['Close', 'Mid', 'Far'],
      defaultValue: 'Mid',
    ),
  ],
  'phantom_phase': [
    CustomizationParam(
      key: 'intensity',
      label: 'Fade Depth',
      options: ['Subtle', 'Normal', 'Deep'],
      defaultValue: 'Normal',
    ),
  ],
  'electric_field': [
    CustomizationParam(
      key: 'bolts',
      label: 'Bolt Count',
      options: ['Few', 'Normal', 'Many'],
      defaultValue: 'Normal',
    ),
    CustomizationParam(
      key: 'intensity',
      label: 'Intensity',
      options: ['Dim', 'Normal', 'Bright'],
      defaultValue: 'Normal',
    ),
  ],
  'planetary_rings': [
    CustomizationParam(
      key: 'count',
      label: 'Ring Count',
      options: ['1', '2', '3'],
      defaultValue: '2',
    ),
    CustomizationParam(
      key: 'style',
      label: 'Style',
      options: ['Icy', 'Rocky', 'Prismatic'],
      defaultValue: 'Icy',
    ),
  ],
};

/// A hidden recipe that unlocks a cosmetic/functional upgrade for the home
/// planet or ship. Ingredients come from [ElementStorage].
class HomeRecipe {
  final String id;
  final String name;
  final String description;
  final HomeRecipeCategory category;
  final Map<String, int> ingredients; // element -> amount required
  final String iconName; // material icon name hint (resolved in UI)

  const HomeRecipe({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.ingredients,
    this.iconName = 'auto_awesome',
  });
}

/// The 20 built-in home customization recipes.
const List<HomeRecipe> kHomeRecipes = [
  // ── Visual (planet decorations) ──
  HomeRecipe(
    id: 'flame_ring',
    name: 'Flame Ring',
    description: 'A blazing ring of fire orbits your home planet.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Fire': 500},
    iconName: 'local_fire_department',
  ),
  HomeRecipe(
    id: 'vine_tendrils',
    name: 'Vine Tendrils',
    description: 'Living vines reach out from your planet\'s surface.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Plant': 100},
    iconName: 'eco',
  ),
  HomeRecipe(
    id: 'crystal_spires',
    name: 'Crystal Spires',
    description: 'Towering crystal formations erupt from the crust.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Crystal': 200, 'Earth': 100},
    iconName: 'diamond',
  ),
  HomeRecipe(
    id: 'dark_void',
    name: 'Dark Void',
    description: 'An ominous dark-matter aura warps space around your planet.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Dark': 300, 'Spirit': 100},
    iconName: 'brightness_3',
  ),
  HomeRecipe(
    id: 'radiant_halo',
    name: 'Radiant Halo',
    description: 'A golden halo of light crowns your world.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Light': 300, 'Air': 100},
    iconName: 'wb_sunny',
  ),
  HomeRecipe(
    id: 'ocean_mist',
    name: 'Ocean Mist',
    description: 'A fine water vapour shimmers around the planet.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Water': 200, 'Steam': 100},
    iconName: 'water',
  ),
  HomeRecipe(
    id: 'blood_moon',
    name: 'Blood Moon',
    description: 'The planet pulses with a deep crimson heartbeat.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Blood': 400},
    iconName: 'nightlight',
  ),
  HomeRecipe(
    id: 'frozen_shell',
    name: 'Frozen Shell',
    description: 'An icy crystalline shell encases the planet.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Ice': 200, 'Crystal': 50},
    iconName: 'ac_unit',
  ),
  HomeRecipe(
    id: 'poison_cloud',
    name: 'Poison Cloud',
    description: 'A toxic green miasma drifts around your world.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Poison': 150, 'Plant': 50},
    iconName: 'science',
  ),
  HomeRecipe(
    id: 'dust_storm',
    name: 'Dust Storm',
    description: 'Orbiting dust particles form a swirling storm.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Dust': 300, 'Air': 100},
    iconName: 'grain',
  ),
  HomeRecipe(
    id: 'steam_vents',
    name: 'Steam Vents',
    description: 'Erupting geysers blast jets of steam skyward.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Steam': 150, 'Fire': 100},
    iconName: 'hot_tub',
  ),
  HomeRecipe(
    id: 'lightning_rod',
    name: 'Lightning Rod',
    description: 'Bolts of electricity arc down to the surface.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Lightning': 200, 'Crystal': 100},
    iconName: 'flash_on',
  ),
  HomeRecipe(
    id: 'lava_moat',
    name: 'Lava Moat',
    description: 'A molten ring of lava guards your planet.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Lava': 300, 'Fire': 100},
    iconName: 'whatshot',
  ),
  HomeRecipe(
    id: 'spirit_wisps',
    name: 'Spirit Wisps',
    description: 'Ethereal ghost-lights float around your world.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Spirit': 200, 'Light': 100},
    iconName: 'blur_on',
  ),
  HomeRecipe(
    id: 'mud_fortress',
    name: 'Mud Fortress',
    description: 'A thick protective shell of hardened mud.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Mud': 200, 'Earth': 200},
    iconName: 'fort',
  ),
  HomeRecipe(
    id: 'natures_blessing',
    name: 'Nature\'s Blessing',
    description:
        'All 17 elements harmonize — your planet radiates every color.',
    category: HomeRecipeCategory.visual,
    ingredients: {
      'Fire': 30,
      'Water': 30,
      'Earth': 30,
      'Air': 30,
      'Steam': 30,
      'Lava': 30,
      'Lightning': 30,
      'Mud': 30,
      'Ice': 30,
      'Dust': 30,
      'Crystal': 30,
      'Plant': 30,
      'Poison': 30,
      'Spirit': 30,
      'Dark': 30,
      'Light': 30,
      'Blood': 30,
    },
    iconName: 'all_inclusive',
  ),
  HomeRecipe(
    id: 'orbiting_moon',
    name: 'Orbiting Moon',
    description: 'A small moon orbits your planet. Requires Big size tier.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Earth': 300, 'Crystal': 200, 'Dark': 100},
    iconName: 'nightlight_round',
  ),
  HomeRecipe(
    id: 'phantom_phase',
    name: 'Phantom Phase',
    description:
        'Your planet periodically fades into the spirit realm and back.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Spirit': 500, 'Light': 150},
    iconName: 'blur_on',
  ),
  HomeRecipe(
    id: 'electric_field',
    name: 'Electric Field',
    description:
        'Crackling bolts and sparks orbit your planet in a volatile electric field.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Lightning': 500, 'Fire': 100, 'Air': 100},
    iconName: 'bolt',
  ),
  HomeRecipe(
    id: 'planetary_rings',
    name: 'Planetary Rings',
    description: 'Majestic rings orbit your home planet in a tilted disc.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Air': 100, 'Dust': 100, 'Crystal': 100, 'Spirit': 200},
    iconName: 'trip_origin',
  ),

  // Cargo Hold is handled specially as a leveled upgrade (see CargoUpgrade).

  // ── Base stations ──
  HomeRecipe(
    id: 'refuel_station',
    name: 'Refuel Station',
    description:
        'Constructs a fuel depot at your home base. Refuel for free when docked at home.',
    category: HomeRecipeCategory.upgrade,
    ingredients: {'Fire': 200, 'Crystal': 150, 'Lava': 100},
    iconName: 'local_gas_station',
  ),
  HomeRecipe(
    id: 'missile_station',
    name: 'Missile Station',
    description:
        'Constructs a missile fabricator at your home base. Reload missiles for free when docked at home.',
    category: HomeRecipeCategory.upgrade,
    ingredients: {'Dark': 200, 'Fire': 150, 'Crystal': 100},
    iconName: 'rocket',
  ),
  HomeRecipe(
    id: 'sentinel_station',
    name: 'Sentinel Station',
    description:
        'Constructs a sentinel bay at your home base. Replenish orbital sentinels for free when docked at home.',
    category: HomeRecipeCategory.upgrade,
    ingredients: {'Crystal': 250, 'Earth': 200, 'Dust': 150},
    iconName: 'shield',
  ),

  // ── Ammo upgrades ──
  HomeRecipe(
    id: 'storm_bolts',
    name: 'Storm Bolts',
    description: 'Electrified ammo that crackles with lightning.',
    category: HomeRecipeCategory.ammo,
    ingredients: {'Fire': 50, 'Lightning': 50},
    iconName: 'bolt',
  ),
  HomeRecipe(
    id: 'plasma_bolts',
    name: 'Plasma Bolts',
    description: 'Superheated plasma projectiles that glow white-hot.',
    category: HomeRecipeCategory.ammo,
    ingredients: {'Lightning': 100, 'Fire': 100},
    iconName: 'offline_bolt',
  ),
  HomeRecipe(
    id: 'ice_shards',
    name: 'Ice Shards',
    description: 'Frozen crystalline shards that shatter on impact.',
    category: HomeRecipeCategory.ammo,
    ingredients: {'Ice': 100, 'Crystal': 50},
    iconName: 'ac_unit',
  ),
  HomeRecipe(
    id: 'void_cannon',
    name: 'Void Cannon',
    description: 'Dark-energy projectiles that consume light.',
    category: HomeRecipeCategory.ammo,
    ingredients: {'Dark': 200, 'Blood': 100},
    iconName: 'remove_circle',
  ),

  // ── Equipment (ship systems) ──
  HomeRecipe(
    id: 'equip_booster',
    name: 'Ion Booster',
    description:
        'Enables afterburner boost. Consumes fuel from elemental particles.',
    category: HomeRecipeCategory.equipment,
    ingredients: {'Fire': 300, 'Crystal': 100},
    iconName: 'rocket_launch',
  ),
  HomeRecipe(
    id: 'equip_machinegun',
    name: 'Pulse Repeater',
    description:
        'Rapid-fire energy bolts. High fire rate, low damage per shot.',
    category: HomeRecipeCategory.equipment,
    ingredients: {'Fire': 150, 'Lava': 100},
    iconName: 'flash_on',
  ),
  HomeRecipe(
    id: 'equip_missiles',
    name: 'Seeker Missiles',
    description:
        'Homing projectiles that track the nearest enemy. Slower fire rate, devastating damage.',
    category: HomeRecipeCategory.equipment,
    ingredients: {'Dark': 150, 'Fire': 100, 'Crystal': 50},
    iconName: 'gps_fixed',
  ),
  HomeRecipe(
    id: 'equip_orbitals',
    name: 'Orbital Sentinels',
    description:
        'Shield drones orbit your ship and block enemies on contact. Up to 3 active; auto-replenish from stockpile of 50+.',
    category: HomeRecipeCategory.equipment,
    ingredients: {'Crystal': 200, 'Earth': 150, 'Lava': 100},
    iconName: 'shield',
  ),

  // ── Ship designs (skins) ──
  HomeRecipe(
    id: 'skin_phantom',
    name: 'Phantom Viper',
    description:
        'A stealth-plated hull with a dark-matter exhaust trail. The ship becomes a slender, angular silhouette with violet engine glow.',
    category: HomeRecipeCategory.equipment,
    ingredients: {'Dark': 250, 'Spirit': 150, 'Poison': 100},
    iconName: 'visibility_off',
  ),
  HomeRecipe(
    id: 'skin_solar',
    name: 'Solar Dragoon',
    description:
        'A blazing golden hull forged from concentrated light and fire. Trailing solar flares and a radiant amber cockpit.',
    category: HomeRecipeCategory.equipment,
    ingredients: {'Fire': 200, 'Light': 300, 'Steam': 100},
    iconName: 'wb_sunny',
  ),
  HomeRecipe(
    id: 'skin_inferno',
    name: 'Inferno Raptor',
    description:
        'An aggressive flame-carved striker with ember exhaust, molten plating, and wingtip fire tongues.',
    category: HomeRecipeCategory.equipment,
    ingredients: {'Fire': 260, 'Lava': 180, 'Earth': 80},
    iconName: 'local_fire_department',
  ),
  HomeRecipe(
    id: 'skin_crystal',
    name: 'Crystal Bastion',
    description:
        'A faceted shard frigate with icy prism engines, floating crystal motes, and a luminous crystalline core.',
    category: HomeRecipeCategory.equipment,
    ingredients: {'Crystal': 260, 'Ice': 140, 'Water': 120},
    iconName: 'diamond',
  ),
];

/// Persisted state of which home recipes are unlocked and which are active.
/// Also stores per-recipe sub-customization option values.
class HomeCustomizationState {
  final Set<String> unlockedIds;
  final Set<String> activeIds;

  /// Per-recipe sub-customization values.
  /// Key = 'recipeId.paramKey', Value = chosen option string.
  final Map<String, String> options;

  /// Power-up levels for ship ammo and missiles (0-5).
  int ammoUpgradeLevel;
  int missileUpgradeLevel;

  /// Fuel tank upgrade level (0-3). Level 3 = double capacity.
  int fuelUpgradeLevel;

  /// Shard costs for each upgrade stage (index 0 = cost for level 1, etc.).
  static const List<int> upgradeCosts = [100, 500, 1500, 3000, 5000];

  /// Fuel tank upgrade costs (3 levels). Level 3 = double capacity.
  static const List<int> fuelUpgradeCosts = [200, 800, 2000];

  /// Maximum fuel upgrade level.
  static const int maxFuelUpgradeLevel = 3;

  /// Maximum upgrade level.
  static const int maxUpgradeLevel = 5;

  /// Damage multiplier for a given upgrade level (40% at max).
  static double damageMultiplier(int level) =>
      CosmicBalance.shipDamageMultiplier(level);

  /// Missile damage multiplier uses a softer early curve than regular ammo.
  static double missileDamageMultiplier(int level) =>
      CosmicBalance.missileDamageMultiplier(level);

  static double missileHitDamage({required int level, required bool vsBoss}) =>
      CosmicBalance.missileHitDamage(level: level, vsBoss: vsBoss);

  static double shipProjectileHitDamage({
    required int level,
    required bool machineGun,
  }) => CosmicBalance.shipProjectileHitDamage(
    level: level,
    machineGun: machineGun,
  );

  static double shipProjectileAsteroidDamage({
    required int level,
    required bool machineGun,
  }) => CosmicBalance.shipProjectileAsteroidDamage(
    level: level,
    machineGun: machineGun,
  );

  HomeCustomizationState({
    Set<String>? unlockedIds,
    Set<String>? activeIds,
    Map<String, String>? options,
    this.ammoUpgradeLevel = 0,
    this.missileUpgradeLevel = 0,
    this.fuelUpgradeLevel = 0,
  }) : unlockedIds = unlockedIds ?? {},
       activeIds = activeIds ?? {},
       options = options ?? {};

  /// Get a sub-customization value, falling back to default.
  String getOption(String recipeId, String paramKey) {
    final stored = options['$recipeId.$paramKey'];
    if (stored != null) return stored;
    final params = kRecipeParams[recipeId];
    if (params != null) {
      for (final p in params) {
        if (p.key == paramKey) return p.defaultValue;
      }
    }
    return '';
  }

  /// Set a sub-customization value.
  void setOption(String recipeId, String paramKey, String value) {
    options['$recipeId.$paramKey'] = value;
  }

  bool isUnlocked(String id) => unlockedIds.contains(id);
  bool isActive(String id) => activeIds.contains(id);

  /// Try to unlock a recipe by spending from [storage].
  /// Returns true if successful.
  bool tryUnlock(String recipeId, ElementStorage storage) {
    if (unlockedIds.contains(recipeId)) return false;
    final recipe = kHomeRecipes.cast<HomeRecipe?>().firstWhere(
      (r) => r!.id == recipeId,
      orElse: () => null,
    );
    if (recipe == null) return false;

    // Check if all ingredients are available
    for (final e in recipe.ingredients.entries) {
      if ((storage.stored[e.key] ?? 0) < e.value) return false;
    }

    // Spend ingredients
    for (final e in recipe.ingredients.entries) {
      storage.stored[e.key] = (storage.stored[e.key] ?? 0) - e.value;
    }
    unlockedIds.add(recipeId);
    // Auto-activate on unlock, but respect mutual-exclusion groups
    if (_weaponIds.contains(recipeId)) {
      activeIds.removeAll(_weaponIds);
    }
    if (_ammoIds.contains(recipeId)) {
      activeIds.removeAll(_ammoIds);
    }
    if (_skinIds.contains(recipeId)) {
      activeIds.removeAll(_skinIds);
    }
    activeIds.add(recipeId);
    return true;
  }

  /// Weapon IDs that are mutually exclusive — only one active at a time.
  static const _weaponIds = {'equip_machinegun', 'equip_missiles'};

  /// Ammo IDs that are mutually exclusive — only one active at a time.
  static const _ammoIds = {
    'storm_bolts',
    'plasma_bolts',
    'ice_shards',
    'void_cannon',
  };

  /// Ship skin IDs that are mutually exclusive — only one active at a time.
  static const _skinIds = {
    'skin_phantom',
    'skin_solar',
    'skin_inferno',
    'skin_crystal',
  };

  void toggle(String id) {
    if (!unlockedIds.contains(id)) return;
    if (activeIds.contains(id)) {
      activeIds.remove(id);
    } else {
      // If this is a weapon, deactivate other weapons first
      if (_weaponIds.contains(id)) {
        activeIds.removeAll(_weaponIds);
      }
      // If this is ammo, deactivate other ammo first
      if (_ammoIds.contains(id)) {
        activeIds.removeAll(_ammoIds);
      }
      // If this is a ship skin, deactivate other skins first
      if (_skinIds.contains(id)) {
        activeIds.removeAll(_skinIds);
      }
      activeIds.add(id);
    }
  }

  /// Get the currently active ammo recipe (only one at a time, last wins).
  HomeRecipe? get activeAmmo {
    for (final r in kHomeRecipes.reversed) {
      if (r.category == HomeRecipeCategory.ammo && activeIds.contains(r.id)) {
        return r;
      }
    }
    return null;
  }

  String serialise() {
    final u = unlockedIds.toList()..sort();
    final a = activeIds.toList()..sort();
    // Third segment: sub-customization options as key~value pairs
    final o = options.entries.map((e) => '${e.key}~${e.value}').toList()
      ..sort();
    // Fourth segment: power-up levels
    return '${u.join(",")}|${a.join(",")}|${o.join(",")}|$ammoUpgradeLevel,$missileUpgradeLevel,$fuelUpgradeLevel';
  }

  factory HomeCustomizationState.deserialise(String raw) {
    if (raw.isEmpty) return HomeCustomizationState();
    final parts = raw.split('|');
    final u = parts[0].isNotEmpty ? parts[0].split(',').toSet() : <String>{};
    final a = parts.length > 1 && parts[1].isNotEmpty
        ? parts[1].split(',').toSet()
        : <String>{};
    final opts = <String, String>{};
    if (parts.length > 2 && parts[2].isNotEmpty) {
      for (final kv in parts[2].split(',')) {
        final pair = kv.split('~');
        if (pair.length == 2) opts[pair[0]] = pair[1];
      }
    }
    // Fourth segment: power-up levels
    int ammoLvl = 0;
    int missileLvl = 0;
    int fuelLvl = 0;
    if (parts.length > 3 && parts[3].isNotEmpty) {
      final lvls = parts[3].split(',');
      if (lvls.isNotEmpty) ammoLvl = int.tryParse(lvls[0]) ?? 0;
      if (lvls.length > 1) missileLvl = int.tryParse(lvls[1]) ?? 0;
      if (lvls.length > 2) fuelLvl = int.tryParse(lvls[2]) ?? 0;
    }
    return HomeCustomizationState(
      unlockedIds: u,
      activeIds: a,
      options: opts,
      ammoUpgradeLevel: ammoLvl,
      missileUpgradeLevel: missileLvl,
      fuelUpgradeLevel: fuelLvl,
    );
  }

  /// Get the currently active primary weapon type (gun).
  String? get activeWeapon {
    const weapons = ['equip_machinegun'];
    for (final id in weapons.reversed) {
      if (activeIds.contains(id)) return id;
    }
    return null; // default gun
  }

  bool get hasBooster => activeIds.contains('equip_booster');
  bool get hasMissiles =>
      unlockedIds.contains('equip_missiles') &&
      activeIds.contains('equip_missiles');
  bool get hasOrbitals =>
      unlockedIds.contains('equip_orbitals') &&
      activeIds.contains('equip_orbitals');
  bool get hasRefuelStation => unlockedIds.contains('refuel_station');
  bool get hasMissileStation => unlockedIds.contains('missile_station');
  bool get hasSentinelStation => unlockedIds.contains('sentinel_station');

  /// Currently active ship skin ID (null = default look).
  String? get activeShipSkin {
    for (final id in _skinIds) {
      if (activeIds.contains(id)) return id;
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────
// SHIP FUEL
// ─────────────────────────────────────────────────────────

/// Fuel for the ship booster. Crafted from elemental particles at home.
class ShipFuel {
  double fuel;
  double capacity;

  ShipFuel({this.fuel = 0.0, this.capacity = 100.0});

  /// Compute capacity based on fuel upgrade level.
  /// Level 0 = 100, Level 1 = 125, Level 2 = 150, Level 3 = 200 (double).
  static double capacityForLevel(int level) {
    switch (level) {
      case 1:
        return 125.0;
      case 2:
        return 150.0;
      case 3:
        return 200.0;
      default:
        return 100.0;
    }
  }

  bool get isEmpty => fuel <= 0;
  bool get isFull => fuel >= capacity;
  double get fraction => capacity > 0 ? (fuel / capacity).clamp(0.0, 1.0) : 0;

  /// Consume fuel. Returns actual amount consumed.
  double consume(double amount) {
    final used = amount.clamp(0.0, fuel);
    fuel -= used;
    return used;
  }

  /// Add fuel (capped at capacity). Returns amount actually added.
  double add(double amount) {
    final space = capacity - fuel;
    final added = amount.clamp(0.0, space);
    fuel += added;
    return added;
  }

  /// Cost per fuel unit: specific elements.
  static const Map<String, int> fuelCost = {'Fire': 8, 'Crystal': 2};

  /// Cost per missile: specific elements.
  static const Map<String, int> missileCost = {'Dark': 3, 'Fire': 2};

  /// Max missiles that can be carried.
  static const int maxMissileAmmo = 50;

  String serialise() =>
      '${fuel.toStringAsFixed(2)}|${capacity.toStringAsFixed(2)}';

  factory ShipFuel.deserialise(String raw) {
    if (raw.isEmpty) return ShipFuel();
    final parts = raw.split('|');
    return ShipFuel(
      fuel: double.tryParse(parts[0]) ?? 0,
      capacity: parts.length > 1 ? (double.tryParse(parts[1]) ?? 100) : 100,
    );
  }
}

// ─────────────────────────────────────────────────────────
// ORBITAL SENTINEL
// ─────────────────────────────────────────────────────────

/// A defensive drone orbiting the ship.
class OrbitalSentinel {
  double angle; // current orbital angle
  double health; // dies at 0
  double spawnOpacity; // 0→1 fade-in on spawn
  static const double maxHealth = 1.0;
  static const double orbitRadius = 50.0;
  static const double orbitSpeed = 2.5; // radians/sec
  static const double hitboxRadius = 16.0;
  static const int maxActive = 3;
  static const int autoReplenishThreshold = 50;

  /// Seconds before a destroyed sentinel respawns.
  static const double respawnCooldown = 7.0;

  /// Seconds for the fade-in animation.
  static const double fadeInDuration = 0.8;

  /// Cost per sentinel: specific elements.
  static const Map<String, int> sentinelCost = {
    'Crystal': 4,
    'Earth': 3,
    'Lava': 1,
  };

  OrbitalSentinel({
    required this.angle,
    this.health = maxHealth,
    this.spawnOpacity = 0.0,
  });

  bool get dead => health <= 0;
  bool get fullyVisible => spawnOpacity >= 1.0;

  /// While fading in, the sentinel is invulnerable so it doesn't die instantly.
  bool get invulnerable => spawnOpacity < 1.0;

  Offset positionAround(Offset center) {
    return Offset(
      center.dx + cos(angle) * orbitRadius,
      center.dy + sin(angle) * orbitRadius,
    );
  }

  void update(double dt) {
    angle += orbitSpeed * dt;
    if (spawnOpacity < 1.0) {
      spawnOpacity = (spawnOpacity + dt / fadeInDuration).clamp(0.0, 1.0);
    }
  }
}

// ─────────────────────────────────────────────────────────
// CARGO UPGRADE (leveled)
// ─────────────────────────────────────────────────────────

/// Single upgradeable cargo system. Each level increases teleport capacity
/// and costs more particles. Max level 3.
class CargoUpgrade {
  static const int maxLevel = 3;

  /// Teleport capacity per level (fraction of meter you can carry home).
  static double capacityForLevel(int level) => switch (level) {
    0 => 0.20,
    1 => 0.50,
    2 => 0.80,
    _ => 1.00, // level 3 = infinite
  };

  /// Name shown in UI per level.
  static String nameForLevel(int level) => switch (level) {
    0 => 'Basic Hull',
    1 => 'Cargo Hold',
    2 => 'Void Hold',
    _ => 'Infinite Hold',
  };

  /// Description per level.
  static String nextDescription(int level) => switch (level) {
    0 => 'Reinforce hull to carry 50% meter when teleporting home.',
    1 => 'Warp-fold bay — carry up to 80% meter home.',
    2 => 'Master space-time — teleport at any meter level.',
    _ => 'Fully upgraded.',
  };

  /// Cost to upgrade TO the next level. Returns ingredient map.
  static Map<String, int> costForNextLevel(int currentLevel) =>
      switch (currentLevel) {
        0 => {'Earth': 200, 'Crystal': 150, 'Mud': 100},
        1 => {'Dark': 300, 'Spirit': 200, 'Crystal': 150},
        2 => {'Spirit': 400, 'Light': 400, 'Dark': 300, 'Blood': 200},
        _ => {}, // already maxed
      };
}

// ─────────────────────────────────────────────────────────
// SHIP WALLET
// ─────────────────────────────────────────────────────────

/// Astral Shards the ship is carrying. Must be deposited at home to bank them.
class ShipWallet {
  int shards;

  /// Default capacity — can be upgraded via home recipes.
  int shardCapacity;

  ShipWallet({this.shards = 0, this.shardCapacity = 50});

  bool get shardsFull => shards >= shardCapacity;

  /// Try to add shards. Returns amount actually added (capped at capacity).
  int addShards(int amount) {
    final space = shardCapacity - shards;
    final added = amount.clamp(0, space);
    shards += added;
    return added;
  }

  /// Empty the wallet, returning shards that were stored.
  int depositAll() {
    final s = shards;
    shards = 0;
    return s;
  }
}

// ─────────────────────────────────────────────────────────
// LOOT DROPS
// ─────────────────────────────────────────────────────────

/// Type of loot that can drop from enemies/bosses.
enum LootType { astralShard, elementParticle, item, healthOrb }

/// A collectible loot drop that sits in world space until the ship picks it up.
class LootDrop {
  Offset position;
  Offset velocity;
  final LootType type;
  final int amount; // silver/gold quantity, or element particle amount
  final String? element; // only for elementParticle type
  final String? itemKey; // only for item type (inventory key)
  final Color color;
  double life; // seconds alive
  bool collected;

  /// Loot drops expire after 15 seconds.
  static const double maxLifetime = 15.0;

  /// Pickup radius — ship must be within this distance.
  static const double pickupRadius = 40.0;

  /// Magnetic pull radius — loot gets sucked toward ship.
  static const double magnetRadius = 100.0;

  LootDrop({
    required this.position,
    required this.velocity,
    required this.type,
    required this.amount,
    this.element,
    this.itemKey,
    required this.color,
    this.life = 0,
    this.collected = false,
  });

  /// Whether this drop has expired.
  bool get expired => life >= maxLifetime;

  /// Update position and life.
  void update(double dt) {
    life += dt;
    // Friction to slow down after burst
    velocity *= 0.96;
    position += velocity * dt;
  }
}

// ─────────────────────────────────────────────────────────
// COSMIC ENEMIES
// ─────────────────────────────────────────────────────────

/// Tier of cosmic enemy.
enum EnemyTier {
  /// Tiny flickering orb — fast, fragile.
  wisp,

  /// Round body with orbiting satellites — mid-tier.
  sentinel,

  /// Heavy armored sphere with elemental cracks — tanky.
  brute,

  /// Small geometric diamond shape — very fast glass-cannon.
  drone,

  /// Ghostly semi-transparent enemy with pulsing cloak.
  phantom,

  /// Massive slow creature with tentacle appendages — HP tank.
  colossus,
}

/// Behavior archetype — determines how the enemy acts.
enum EnemyBehavior {
  /// Actively hunts the player on sight.
  aggressive,

  /// Drifts aimlessly; harmless unless cornered.
  drifting,

  /// Clusters near asteroid belts, "feeding" on rocks.
  /// Passive until the player attacks one — then the whole pack aggros.
  feeding,

  /// Patrols a territory near a planet; attacks if player enters zone.
  territorial,

  /// Follows the player from afar; strikes only when ship HP is low.
  stalking,

  /// Tiny fast enemies that cluster and swarm together.
  swarming,
}

enum CosmicEnemyVariant { standard, crusher, pouncer }

/// A floating alchemical enemy in the cosmos.
class CosmicEnemy {
  Offset position;
  final String element;
  final EnemyTier tier;
  final double radius;
  double health; // ≤ 0 = dead
  double speed;
  double angle; // current facing direction
  double driftTimer; // for AI direction changes
  bool dead;

  /// Current behavior archetype.
  EnemyBehavior behavior;

  /// Converged taxonomy: the single movement authority.
  /// See docs/enemy_taxonomy.md.
  final EnemyConduct conduct;

  /// Whether this enemy has been provoked (feeding/territorial → aggressive).
  bool provoked;

  /// Pack identifier — enemies in the same pack provoke together.
  /// -1 = solo (no pack).
  int packId;

  /// Home position for territorial / feeding enemies.
  Offset? homePos;

  /// Radius within which territorial enemies detect intruders.
  double aggroRadius;

  /// For stalkers: how close they keep to the player.
  double stalkDistance;

  /// Galaxy whirl index this enemy belongs to (-1 = none).
  int whirlIndex;

  CosmicEnemyVariant variant;

  int? maneRootSlot;
  double maneRootTimer;
  bool pipMudTrail;
  double pipMudTrailTimer;

  /// Shared hover/dive steering state (lazily created when this enemy
  /// commits to an attack). See games/shared/enemy_flight_steering.dart.
  FlightSteeringState? flightSteering;

  CosmicEnemy({
    required this.position,
    required this.element,
    required this.tier,
    required this.radius,
    required this.health,
    required this.speed,
    this.angle = 0,
    this.driftTimer = 0,
    this.dead = false,
    EnemyBehavior behavior = EnemyBehavior.aggressive,
    this.provoked = false,
    this.packId = -1,
    this.homePos,
    this.aggroRadius = 300,
    this.stalkDistance = 500,
    this.whirlIndex = -1,
    this.variant = CosmicEnemyVariant.standard,
    this.maneRootSlot,
    this.maneRootTimer = 0,
    this.pipMudTrail = false,
    this.pipMudTrailTimer = 0,
  }) : // Not an initializing formal: behavior must be in scope so conduct can
       // be derived from it below.
       // ignore: prefer_initializing_formals
       behavior = behavior,
       // Converged taxonomy, derived during migration. See
       // docs/enemy_taxonomy.md.
       conduct = conductFromOpenWorld(behavior, variant);

  Color get color => elementColor(element);

  /// Spawn HP — derived from the canonical enemyBaseHealth table and the
  /// variant modifier (matching the spawn formula) so the health-bar
  /// fraction is always accurate.
  double get maxHealth =>
      CosmicBalance.enemyBaseHealth(tier) *
      switch (variant) {
        CosmicEnemyVariant.crusher => 1.45,
        CosmicEnemyVariant.pouncer => 0.84,
        CosmicEnemyVariant.standard => 1.0,
      };

  /// Astral Shards dropped on kill.
  int get shardDrop => switch (tier) {
    EnemyTier.wisp => 1,
    EnemyTier.drone => 1,
    EnemyTier.sentinel => 3,
    EnemyTier.phantom => 4,
    EnemyTier.brute => 6,
    EnemyTier.colossus => 12,
  };

  /// Element particles dropped on kill (sometimes).
  double get particleDrop => switch (tier) {
    EnemyTier.wisp => 1.0,
    EnemyTier.drone => 0.5,
    EnemyTier.sentinel => 3.0,
    EnemyTier.phantom => 3.5,
    EnemyTier.brute => 5.0,
    EnemyTier.colossus => 10.0,
  };
}

/// Boss archetype — determines AI behaviour & attack patterns.
/// Assigned based on level: 1-3 Charger, 4-7 Gunner, 8-10 Warden.
enum BossType {
  /// Lv 1-3: Charges at the player in straight dashes with brief pauses.
  charger,

  /// Lv 4-7: Orbits at range and fires projectiles; periodically raises a shield.
  gunner,

  /// Highly mobile ranged hunter with darting movement and escort pressure.
  skirmisher,

  /// Slow armored anchor with recurring shields and heavy support packs.
  bulwark,

  /// Spawns escort packs and screens itself with supporting enemies.
  carrier,

  /// Lv 4-5: Multi-phase — projectile fans, summons minions, enrages at low HP.
  warden,
}

enum ColossalTrait { gravityWell, riftStorm, novaPulse }

/// Derive the [BossType] from a boss level.
BossType bossTypeForLevel(int level) {
  if (level <= 2) return BossType.charger;
  if (level <= 3) return BossType.gunner;
  return BossType.warden;
}

/// A powerful boss enemy that drops significant rewards.
class CosmicBoss {
  Offset position;
  final String name;
  final String element;
  final int level; // 1-5
  final BossType type;
  final bool isTitanic;
  final ColossalTrait? colossalTrait;
  final double radius;
  double health;
  final double maxHealth;
  double speed;
  final double baseSpeed;
  double angle;
  double phaseTimer; // for attack patterns
  bool dead;

  // ── Charger state ──
  bool charging; // true while dashing
  double chargeTimer; // cooldown between charges
  double chargeDashTimer; // remaining time in current dash
  double chargeAngle; // locked angle during dash
  static const double chargeCooldown = 3.0;
  static const double chargeDashDuration = 0.6;
  static const double chargeSpeedMultiplier = 3.5;

  // ── Gunner state ──
  double shootTimer; // cooldown between shots
  bool shieldUp;
  double shieldTimer; // time until shield drops / next shield
  double shieldHealth; // absorbs hits while up
  static const double shootCooldown = 1.8;
  static const double shieldDuration = 3.0;
  static const double shieldCooldown = 8.0;
  static const double shieldMaxHealth = 6.0;

  // ── Warden state ──
  int wardenPhase; // 0 = normal, 1 = summon, 2 = enraged
  double spreadTimer; // cooldown between projectile fans
  double summonTimer; // cooldown between minion summons
  bool enraged;
  static const double spreadCooldown = 2.5;
  static const double summonCooldown = 8.0;
  static const double enrageThreshold = 0.3; // 30% HP

  // ── Carrier state ──
  double escortTimer; // cooldown between escort packages
  static const double escortCooldown = 6.5;

  // ── Titanic trait state ──
  double colossalTraitTimer;
  double colossalTraitAuxTimer;

  CosmicBoss({
    required this.position,
    required this.name,
    required this.element,
    required this.level,
    required this.radius,
    required this.maxHealth,
    required this.speed,
    this.angle = 0,
    this.phaseTimer = 0,
    this.dead = false,
    // Charger
    this.charging = false,
    this.chargeTimer = 2.0,
    this.chargeDashTimer = 0,
    this.chargeAngle = 0,
    // Gunner
    this.shootTimer = 1.0,
    this.shieldUp = false,
    this.shieldTimer = 5.0,
    this.shieldHealth = 0,
    // Warden
    this.wardenPhase = 0,
    this.spreadTimer = 2.0,
    this.summonTimer = 5.0,
    this.enraged = false,
    this.escortTimer = 3.0,
    this.colossalTraitTimer = 0,
    this.colossalTraitAuxTimer = 0,
    this.isTitanic = false,
    this.colossalTrait,
    BossType? forcedType,
  }) : health = maxHealth,
       baseSpeed = speed,
       type = forcedType ?? bossTypeForLevel(level);

  Color get color => elementColor(element);
  double get healthPct => (health / maxHealth).clamp(0.0, 1.0);

  /// Rewards for defeating this boss — scale with level.
  // maxHealth coefficients divided by 3 so the ×3 boss-HP rescale
  // (see bossHealthScale) leaves reward payouts unchanged.
  int get shardReward => (8 + level * 4 + (maxHealth * 0.5)).round();
  double get particleReward => 3.0 + level * 2.0 + maxHealth * 0.067;
}

/// A projectile fired by a boss.
class BossProjectile {
  Offset position;
  final double angle;
  double life;
  final String element;
  final double damage;
  final double speed;
  final double radius;

  BossProjectile({
    required this.position,
    required this.angle,
    required this.element,
    this.life = 3.0,
    this.damage = 1.0,
    this.speed = 250.0,
    this.radius = 4.0,
  });
}

/// Named boss templates that can spawn.
class BossTemplate {
  final String name;
  final String element;
  final double radius;
  final double health;
  final double speed;
  final BossType? preferredType;
  final bool isTitanic;
  final ColossalTrait? colossalTrait;

  const BossTemplate({
    required this.name,
    required this.element,
    required this.radius,
    required this.health,
    required this.speed,
    this.preferredType,
    this.isTitanic = false,
    this.colossalTrait,
  });
}

const List<BossTemplate> kBossTemplates = [
  // ── Volcanic ──
  BossTemplate(
    name: 'Infernal Wyrm',
    element: 'Fire',
    radius: 38,
    health: 35,
    speed: 55,
  ),
  BossTemplate(
    name: 'Molten Seraph',
    element: 'Lava',
    radius: 42,
    health: 45,
    speed: 38,
    preferredType: BossType.bulwark,
  ),
  BossTemplate(
    name: 'Storm Herald',
    element: 'Lightning',
    radius: 32,
    health: 28,
    speed: 80,
    preferredType: BossType.skirmisher,
  ),
  // ── Oceanic ──
  BossTemplate(
    name: 'Abyssal Colossus',
    element: 'Water',
    radius: 44,
    health: 42,
    speed: 40,
    preferredType: BossType.carrier,
  ),
  BossTemplate(
    name: 'Glacial Phantom',
    element: 'Ice',
    radius: 36,
    health: 36,
    speed: 50,
    preferredType: BossType.skirmisher,
  ),
  BossTemplate(
    name: 'Mist Revenant',
    element: 'Steam',
    radius: 30,
    health: 28,
    speed: 72,
    preferredType: BossType.skirmisher,
  ),
  // ── Earthen ──
  BossTemplate(
    name: 'Terravore',
    element: 'Earth',
    radius: 50,
    health: 65,
    speed: 22,
    preferredType: BossType.bulwark,
  ),
  BossTemplate(
    name: 'Mire Golem',
    element: 'Mud',
    radius: 46,
    health: 55,
    speed: 28,
    preferredType: BossType.bulwark,
  ),
  BossTemplate(
    name: 'Ashfall Djinn',
    element: 'Dust',
    radius: 28,
    health: 28,
    speed: 85,
    preferredType: BossType.skirmisher,
  ),
  BossTemplate(
    name: 'Crystal Titan',
    element: 'Crystal',
    radius: 40,
    health: 50,
    speed: 35,
    preferredType: BossType.bulwark,
  ),
  // ── Verdant ──
  BossTemplate(
    name: 'Zephyr Sovereign',
    element: 'Air',
    radius: 26,
    health: 28,
    speed: 95,
    preferredType: BossType.skirmisher,
  ),
  BossTemplate(
    name: 'Thornmother',
    element: 'Plant',
    radius: 44,
    health: 52,
    speed: 30,
    preferredType: BossType.carrier,
  ),
  BossTemplate(
    name: 'Plague Wyrm',
    element: 'Poison',
    radius: 42,
    health: 48,
    speed: 34,
    preferredType: BossType.carrier,
  ),
  // ── Arcane ──
  BossTemplate(
    name: 'Ethereal Oracle',
    element: 'Spirit',
    radius: 34,
    health: 32,
    speed: 62,
    preferredType: BossType.skirmisher,
  ),
  BossTemplate(
    name: 'Shadow Wraith',
    element: 'Dark',
    radius: 38,
    health: 38,
    speed: 65,
    preferredType: BossType.skirmisher,
  ),
  BossTemplate(
    name: 'Solaris Sentinel',
    element: 'Light',
    radius: 36,
    health: 35,
    speed: 58,
  ),
  BossTemplate(
    name: 'Starforge Ballista',
    element: 'Light',
    radius: 40,
    health: 40,
    speed: 44,
    preferredType: BossType.gunner,
  ),
  BossTemplate(
    name: 'Mirror Harlequin',
    element: 'Spirit',
    radius: 30,
    health: 30,
    speed: 82,
    preferredType: BossType.skirmisher,
  ),
  BossTemplate(
    name: 'Blood Colossus',
    element: 'Blood',
    radius: 48,
    health: 60,
    speed: 25,
  ),
  // ── Titanic ──
  BossTemplate(
    name: 'Void Leviathan',
    element: 'Dark',
    radius: 150,
    health: 150,
    speed: 20,
    preferredType: BossType.bulwark,
    isTitanic: true,
    colossalTrait: ColossalTrait.gravityWell,
  ),
  BossTemplate(
    name: 'Prism Devourer',
    element: 'Crystal',
    radius: 150,
    health: 136,
    speed: 24,
    preferredType: BossType.warden,
    isTitanic: true,
    colossalTrait: ColossalTrait.riftStorm,
  ),
  BossTemplate(
    name: 'Solar Behemoth',
    element: 'Light',
    radius: 150,
    health: 162,
    speed: 18,
    preferredType: BossType.carrier,
    isTitanic: true,
    colossalTrait: ColossalTrait.novaPulse,
  ),
];

BossTemplate pickBossTemplate(
  Random rng, {
  String? preferredElement,
  double titanicChance = 0.05,
}) {
  final titanic = kBossTemplates.where((t) => t.isTitanic).toList();
  if (titanic.isNotEmpty && rng.nextDouble() < titanicChance) {
    return titanic[rng.nextInt(titanic.length)];
  }

  final pool = kBossTemplates.where((t) => !t.isTitanic).toList();
  if (preferredElement != null) {
    final matching = pool.where((t) => t.element == preferredElement).toList();
    if (matching.isNotEmpty) {
      return matching[rng.nextInt(matching.length)];
    }
  }
  return pool[rng.nextInt(pool.length)];
}

// ─────────────────────────────────────────────────────────
// BOSS LAIR (MAP POI)
// ─────────────────────────────────────────────────────────

/// State of a boss lair on the map.
enum BossLairState { waiting, fighting, defeated }

/// A discoverable point on the map where a boss awaits.
/// Always visible on the star map so the player can navigate to it.
class BossLair {
  Offset position;
  final BossTemplate template;
  final int level; // 1-5
  BossLairState state;
  double respawnTimer; // seconds until a new lair can spawn after defeat

  /// How close the player must be to trigger the boss fight.
  static const double activationRadius = 300.0;

  /// Delay before a new lair spawns after clearing one.
  static const double respawnDelay = 60.0;

  BossLair({
    required this.position,
    required this.template,
    required this.level,
    this.state = BossLairState.waiting,
    this.respawnTimer = 0,
  });

  /// Generate a single boss lair at a random position in deep space.
  static BossLair generate({
    required Random rng,
    required Size worldSize,
    required List<CosmicPlanet> planets,
    required List<GalaxyWhirl> whirls,
    List<BossLair> existing = const [],
  }) {
    const margin = 3000.0;
    const minPlanetDist = 2000.0;
    const minWhirlDist = 2500.0;
    const minLairDist = 4000.0;

    final template = pickBossTemplate(rng, titanicChance: 0.04);

    // Prefer a position near the matching element's planet
    final matchPlanet = planets.cast<CosmicPlanet?>().firstWhere(
      (p) => p!.element == template.element,
      orElse: () => null,
    );

    Offset pos;
    int tries = 0;
    do {
      if (matchPlanet != null && tries < 100) {
        // Place near the matching planet at a good orbit distance
        final angle = rng.nextDouble() * pi * 2;
        final dist = matchPlanet.radius * 5.0 + 300 + rng.nextDouble() * 800;
        pos = Offset(
          matchPlanet.position.dx + cos(angle) * dist,
          matchPlanet.position.dy + sin(angle) * dist,
        );
      } else {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
      }
      tries++;
    } while (tries < 200 &&
        (planets.any((p) => (p.position - pos).distance < minPlanetDist) ||
            whirls.any((w) => (w.position - pos).distance < minWhirlDist) ||
            existing.any((l) => (l.position - pos).distance < minLairDist)));

    // Level: 1-5, weighted toward the provided level hint
    final level = (rng.nextInt(3) - 1 + (rng.nextInt(5) + 1)).clamp(1, 5);

    return BossLair(position: pos, template: template, level: level);
  }

  /// Generate a lair with a specific level.
  static BossLair generateAtLevel({
    required Random rng,
    required int level,
    required Size worldSize,
    required List<CosmicPlanet> planets,
    required List<GalaxyWhirl> whirls,
    List<BossLair> existing = const [],
  }) {
    const margin = 3000.0;
    const minPlanetDist = 2000.0;
    const minWhirlDist = 2500.0;
    const minLairDist = 4000.0;

    final template = pickBossTemplate(rng, titanicChance: 0.04);

    final matchPlanet = planets.cast<CosmicPlanet?>().firstWhere(
      (p) => p!.element == template.element,
      orElse: () => null,
    );

    Offset pos;
    int tries = 0;
    do {
      if (matchPlanet != null && tries < 100) {
        final angle = rng.nextDouble() * pi * 2;
        final dist = matchPlanet.radius * 5.0 + 300 + rng.nextDouble() * 800;
        pos = Offset(
          matchPlanet.position.dx + cos(angle) * dist,
          matchPlanet.position.dy + sin(angle) * dist,
        );
      } else {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
      }
      tries++;
    } while (tries < 200 &&
        (planets.any((p) => (p.position - pos).distance < minPlanetDist) ||
            whirls.any((w) => (w.position - pos).distance < minWhirlDist) ||
            existing.any((l) => (l.position - pos).distance < minLairDist)));

    return BossLair(
      position: pos,
      template: template,
      level: level.clamp(1, 5),
    );
  }
}

// ─────────────────────────────────────────────────────────
// ASTEROID BELT
// ─────────────────────────────────────────────────────────

/// A ring of asteroids at a fixed location in the cosmos.
/// Deterministically generated from the world seed.
class Asteroid {
  Offset position;
  final double radius; // 4–18
  final double rotation; // initial rotation
  final double rotSpeed; // rad/s
  final int shape; // 0-2 for variety
  double health; // 1.0 = full, ≤ 0 = destroyed
  double orbitAngle; // current angle around belt center
  final double orbitDist; // distance from belt center
  final double orbitSpeed; // rad/s — slow drift

  Asteroid({
    required this.position,
    required this.radius,
    required this.rotation,
    required this.rotSpeed,
    required this.shape,
    this.health = 1.0,
    this.orbitAngle = 0,
    this.orbitDist = 0,
    this.orbitSpeed = 0,
  });

  bool get destroyed => health <= 0;
}

/// Generates an asteroid belt — a thick torus around a center point.
class AsteroidBelt {
  final Offset center;
  final double innerRadius;
  final double outerRadius;
  final List<Asteroid> asteroids;

  const AsteroidBelt({
    required this.center,
    required this.innerRadius,
    required this.outerRadius,
    required this.asteroids,
  });

  /// Generate a belt of 200–300 asteroids from seed.
  static AsteroidBelt generate({required int seed, required Size worldSize}) {
    final rng = Random(seed ^ 0xA57E01D);
    // Belt centered at ~1/3 of the world, offset from center
    final cx = worldSize.width * (0.25 + rng.nextDouble() * 0.50);
    final cy = worldSize.height * (0.25 + rng.nextDouble() * 0.50);
    final center = Offset(cx, cy);
    const innerR = 2000.0;
    const outerR = 3800.0;
    final count = 200 + rng.nextInt(100);

    final rocks = <Asteroid>[];
    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * pi * 2;
      final dist = innerR + rng.nextDouble() * (outerR - innerR);
      // Add some wobble so it's not a perfect ring
      final wobble = (rng.nextDouble() - 0.5) * 400;
      final actualDist = dist + wobble;
      final pos = Offset(
        cx + cos(angle) * actualDist,
        cy + sin(angle) * actualDist,
      );
      // Slow orbital drift — smaller rocks move a bit faster
      final orbSpeed =
          (0.003 + rng.nextDouble() * 0.006) * (rng.nextBool() ? 1 : -1);
      rocks.add(
        Asteroid(
          position: pos,
          radius: 4 + rng.nextDouble() * 14,
          rotation: rng.nextDouble() * pi * 2,
          rotSpeed: (rng.nextDouble() - 0.5) * 1.5,
          shape: rng.nextInt(3),
          orbitAngle: angle,
          orbitDist: actualDist,
          orbitSpeed: orbSpeed,
        ),
      );
    }

    return AsteroidBelt(
      center: center,
      innerRadius: innerR,
      outerRadius: outerR,
      asteroids: rocks,
    );
  }
}

// ─────────────────────────────────────────────────────────
// SHIP PROJECTILE
// ─────────────────────────────────────────────────────────

/// A laser bolt fired from the ship or a companion/garrison creature.
class Projectile {
  Offset position;
  double angle; // direction in radians (mutable for homing)
  double life; // seconds remaining
  final String? element; // element type (for companion projectiles)
  // Non-final so persistent-effect updaters can grow projectile damage
  // (e.g. Mane+Light per-pierce empower).
  double damage; // damage dealt on hit
  static const double speed = 600.0;
  static const double maxLife = 2.0;
  static const double radius = 3.0;

  /// This projectile will not lay a trap placement: either it IS one (a mask
  /// fire pool, a crystal shard) or it is a trap that has already gone off.
  ///
  /// Contact is re-tested every frame and nothing records who has already
  /// been hit, so without this a trap detonates on every frame an enemy
  /// stands in it, and each pool it lays is itself a trap that does the same:
  /// 8192 placements after one second of contact, in a frame that cost 720ms
  /// of update and 2.2 seconds of raster.
  bool trapSpent;

  /// Speed multiplier (1.0 = normal). Lava/Mud are slower, Lightning is faster.
  /// Non-final so per-frame updaters can decelerate (e.g. Pip ricochet
  /// speed bleed per bounce).
  double speedMultiplier;

  /// Radius multiplier for collision (e.g. 2.0 = bigger AoE hit).
  // Non-final so persistent-effect updaters can grow the radius
  // (e.g. Mane+Light pierce growth).
  double radiusMultiplier;

  /// If true, projectile passes through enemies instead of being consumed.
  final bool piercing;

  /// Number of enemies already hit (for piercing damage falloff).
  int pierceCount = 0;

  /// Whether this projectile already hit the active boss (prevents multi-hit).
  bool hitBoss = false;

  /// If true, projectile homes toward the nearest enemy each frame.
  final bool homing;

  /// Homing turn rate in radians per second.
  final double homingStrength;

  /// Visual scale multiplier for rendering (distinct from collision radius).
  // Non-final so persistent-effect updaters can grow the visual.
  double visualScale;

  /// Rendering hint so projectile families read differently in combat.
  final ProjectileVisualStyle visualStyle;

  /// If true, projectile does not move — acts as a mine/trap.
  final bool stationary;

  /// Orbital state: if set, projectile orbits around this center point.
  Offset? orbitCenter;

  /// Current orbit angle (radians).
  double orbitAngle;

  /// Orbit radius.
  double orbitRadius;

  /// Orbit angular speed (radians/sec). When 0, orbit is disabled.
  double orbitSpeed;

  /// If > 0, projectile stays in orbit for this many seconds before launching.
  double orbitTime;

  /// If true, the orbital center follows the player's ship each frame.
  bool followShipOrbit;

  /// If true, the orbital center re-anchors to the source companion's
  /// position each frame. Used by Horn+Crystal so the shards orbit
  /// the moving horn (not the cast-point) all the way through dash
  /// and after impact.
  bool followSourceCompanion;

  /// If true, this stationary fixture reflects enemy projectiles back
  /// at their source instead of just absorbing the hit (used by
  /// Horn+Ice walls and Horn+Light barriers).
  bool reflectsProjectiles;

  /// If true, this orbital migrates from the caster to the ship after a delay.
  final bool transferToShipOrbit;

  /// Delay before the ship-transfer begins.
  double shipOrbitDelay;

  /// Optional orbit center to transfer to after a spin-up phase.
  Offset? transferOrbitCenter;

  /// If true, remain in orbit for the projectile lifetime instead of launching.
  final bool holdOrbit;

  /// Movement speed multiplier while attaching to ship orbit.
  final double shipOrbitTransferSpeed;

  // ── Decoy fields (Mask totem/turret) ──

  /// If true, this is a decoy — enemies target it instead of the ship.
  final bool decoy;

  /// HP the decoy has. Enemies deal contact damage to it. When ≤ 0 → explode.
  double decoyHp;

  /// Number of explosion projectiles to spawn when this decoy dies.
  final int deathExplosionCount;

  /// Damage multiplier for each death-explosion projectile.
  final double deathExplosionDamage;

  /// Radius of death-explosion scatter.
  final double deathExplosionRadius;

  // ── Taunt fields (Mask trap lures) ──

  /// If > 0, enemies inside this radius prioritize this projectile as a lure.
  /// Non-final so survival-side clamps can right-size oversized aggro pulls.
  double tauntRadius;

  /// Turn/move aggression multiplier while enemies are taunted by this lure.
  /// Non-final so persistent-effect updaters (e.g. Kin+Spirit wisp tier-up)
  /// can grant/grow the taunt over time.
  double tauntStrength;

  // ── Ricochet fields (Pip bounce) ──

  /// Number of remaining bounces to other enemies on hit.
  int bounceCount;

  // ── Trail fields (Wing residue) ──

  /// If > 0, drop a stationary residue projectile every N seconds.
  final double trailInterval;

  /// Damage of each trail residue projectile.
  final double trailDamage;

  /// Life of each trail residue projectile.
  final double trailLife;

  /// Internal timer for trail dropping.
  double trailTimer = 0;

  // ── Escort/turret fields (Kin ship wards) ──

  /// If > 0, orbiting projectile fires a turret shot every N seconds.
  final double turretInterval;

  /// Damage of each turret shot.
  final double turretDamage;

  /// Homing turn rate of turret shots. If 0, the shot is straight.
  final double turretHomingStrength;

  /// Speed multiplier for turret shots.
  final double turretSpeedMultiplier;

  /// Internal timer for turret fire.
  double turretTimer = 0;

  /// Internal timer for the aura/zone tick (tickEffect application).
  double tickTimer = 0;

  /// If > 0, this projectile can intercept hostile shots within this radius.
  final double interceptRadius;

  /// Number of hostile shots this projectile can intercept before expiring.
  int interceptCharges;

  /// If > 0, enemies inside this radius are slowed or held by the projectile.
  /// Non-final so persistent-effect updaters (e.g. Mask+Plant vine growth)
  /// can expand the snare over time.
  double snareRadius;

  /// Movement multiplier applied while the snare is active (0-1).
  /// Non-final for the same reason as [snareRadius].
  double snareMoveMultiplier;

  // ── Cluster fields (Let meteor fragmentation) ──

  /// If > 0, this projectile splits into N sub-projectiles at half-life.
  final int clusterCount;

  /// Damage of each cluster sub-projectile.
  final double clusterDamage;

  /// Whether the cluster split has already happened.
  bool clustered = false;

  /// Per-projectile growth timer (Mask+Plant vine, etc.). Counts seconds
  /// since spawn; consumed by family-specific persistent-effect updaters.
  double abilityGrowthTimer = 0;

  /// Companion slot that created this projectile, if any.
  int? sourceSlotIndex;

  /// Survival-side attachment marker: -2 = none, -1 = follow the ship,
  /// >= 0 = follow the active companion in that slot each frame. Used
  /// by Mask+Dust shields so each alchemon gets its own travelling
  /// dust cloud aura.
  int attachedToSlot;

  /// If true, this projectile spawns a delayed Let elemental follow-up on
  /// first impact instead of casting all secondary effects immediately.

  /// Base damage seed used to generate delayed Let elemental follow-ups.

  /// Caster Beauty used for delayed Let follow-up tier scaling.

  /// Caster Intelligence carried into delayed Let follow-up generation.
  final double letCasterIntelligence;

  /// Extra chain hits granted by cosmic survival perks.
  int chainLightningCharges;

  /// Shared family ability metadata resolved by combat runtimes.
  final String abilityFamily;
  final AbilityEffectKind hitEffect;
  final AbilityEffectKind killEffect;
  final AbilityEffectKind pierceEffect;
  final AbilityEffectKind tickEffect;
  // Non-final so post-spawn ability boosts (e.g. Horn+Lightning chain
  // shockwave pumping absorbed damage into the chain tick's power)
  // can rewrite the per-tick magnitude.
  double effectPower;
  // Non-final so persistent-effect updaters (e.g. Plant vine growth)
  // can expand the active radius over time.
  double effectRadius;
  final double effectDuration;
  final double effectChance;
  // Non-final so persistent-effect updaters (e.g. Kin+Spirit wisp tier-up
  // bumps tier as a numeric marker) can update it.
  int effectCount;
  // Non-final so persistent-effect updaters (e.g. Mask+Plant vine
  // feeding) can bump the counter on recasts.
  int effectStacks;
  final bool effectRequiresKill;
  final bool effectOnBoss;
  final Set<int> effectHitIds;

  /// Cached homing target position — refreshed periodically to avoid
  /// scanning the full enemy list every frame.
  Offset? cachedHomingTarget;

  /// Countdown until the next homing target rescan (seconds).
  double homingRescanTimer = 0;

  Projectile({
    required this.position,
    required this.angle,
    this.life = maxLife,
    this.element,
    this.damage = 1.0,
    this.speedMultiplier = 1.0,
    this.radiusMultiplier = 1.0,
    this.piercing = false,
    this.homing = false,
    this.homingStrength = 3.0,
    this.visualScale = 1.0,
    this.visualStyle = ProjectileVisualStyle.standard,
    this.stationary = false,
    this.orbitCenter,
    this.orbitAngle = 0,
    this.orbitRadius = 0,
    this.orbitSpeed = 0,
    this.orbitTime = 0,
    this.followShipOrbit = false,
    this.followSourceCompanion = false,
    this.reflectsProjectiles = false,
    this.transferToShipOrbit = false,
    this.shipOrbitDelay = 0,
    this.transferOrbitCenter,
    this.holdOrbit = false,
    this.shipOrbitTransferSpeed = 0.9,
    this.decoy = false,
    this.decoyHp = 0,
    this.deathExplosionCount = 0,
    this.deathExplosionDamage = 0,
    this.deathExplosionRadius = 1.5,
    this.tauntRadius = 0,
    this.tauntStrength = 0,
    this.bounceCount = 0,
    this.trailInterval = 0,
    this.trailDamage = 0,
    this.trailLife = 0,
    this.turretInterval = 0,
    this.turretDamage = 0,
    this.turretHomingStrength = 0,
    this.turretSpeedMultiplier = 1.0,
    this.interceptRadius = 0,
    this.interceptCharges = 0,
    this.snareRadius = 0,
    this.snareMoveMultiplier = 1.0,
    this.clusterCount = 0,
    this.clusterDamage = 0,
    this.sourceSlotIndex,
    this.attachedToSlot = -2,
    this.letCasterIntelligence = 4.0,
    this.chainLightningCharges = 0,
    this.abilityFamily = '',
    this.trapSpent = false,
    this.hitEffect = AbilityEffectKind.none,
    this.killEffect = AbilityEffectKind.none,
    this.pierceEffect = AbilityEffectKind.none,
    this.tickEffect = AbilityEffectKind.none,
    this.effectPower = 0,
    this.effectRadius = 0,
    this.effectDuration = 0,
    this.effectChance = 1,
    this.effectCount = 0,
    this.effectStacks = 0,
    this.effectRequiresKill = false,
    this.effectOnBoss = true,
    Set<int>? effectHitIds,
  }) : effectHitIds = effectHitIds ?? <int>{};
}

enum ProjectileVisualStyle {
  standard,
  meteor,
  letShard,
  dart,
  slash,
  hornImpact,
  sigil,
  kinOrbital,
  mysticOrbital,
}

enum AbilityEffectKind {
  none,
  knockback,
  slow,
  stun,
  freeze,
  root,
  burn,
  poison,
  zoneDamage,
  zoneHeal,
  pull,
  execute,
  splash,
  split,
  chain,
  leech,
  buff,
  taunt,
  suppressShooting,
  carry,
  alchemyBonus,
  cooldownRefund,
  flower,
  blackHole,
  geyser,
  refraction,
  chargeBlast,
}

bool preservesAuthoredCosmicAbilityVisualIdentity(Projectile projectile) {
  final family = projectile.abilityFamily.toLowerCase();
  if (isCosmicAuthoredAbilityFamily(family)) return true;

  return switch (projectile.visualStyle) {
    ProjectileVisualStyle.meteor ||
    ProjectileVisualStyle.letShard ||
    ProjectileVisualStyle.dart ||
    ProjectileVisualStyle.slash ||
    ProjectileVisualStyle.hornImpact ||
    ProjectileVisualStyle.sigil ||
    ProjectileVisualStyle.kinOrbital ||
    ProjectileVisualStyle.mysticOrbital => true,
    ProjectileVisualStyle.standard => false,
  };
}

enum WingBeamTargetPolicy {
  forward,
  nearestEnemy,
  lowestHealthEnemy,
  lowestHealthAllyOrShip,
  ring,
  shipTether,
}

class WingBeamEffect {
  final String element;
  final WingBeamTargetPolicy targetPolicy;
  final double duration;
  final double tickInterval;
  final double damagePerTick;
  final double healPerTick;
  final double width;
  final double range;
  final double radius;
  final int refractionCount;
  final double chargeTime;
  final double executeThreshold;
  final AbilityEffectKind tickEffect;
  final double effectPower;
  final double effectDuration;
  final int splitCount;

  const WingBeamEffect({
    required this.element,
    required this.targetPolicy,
    required this.duration,
    required this.tickInterval,
    required this.damagePerTick,
    this.healPerTick = 0,
    this.width = 8,
    this.range = 420,
    this.radius = 0,
    this.refractionCount = 0,
    this.chargeTime = 0,
    this.executeThreshold = 0,
    this.tickEffect = AbilityEffectKind.none,
    this.effectPower = 0,
    this.effectDuration = 0,
    this.splitCount = 0,
  });

  WingBeamEffect scaled({
    double damageMultiplier = 1,
    double durationMultiplier = 1,
    double widthMultiplier = 1,
  }) {
    return WingBeamEffect(
      element: element,
      targetPolicy: targetPolicy,
      duration: duration * durationMultiplier,
      tickInterval: tickInterval,
      damagePerTick: damagePerTick * damageMultiplier,
      healPerTick: healPerTick * damageMultiplier,
      width: width * widthMultiplier,
      range: range,
      radius: radius * widthMultiplier,
      refractionCount: refractionCount,
      chargeTime: chargeTime,
      executeThreshold: executeThreshold,
      tickEffect: tickEffect,
      effectPower: effectPower * damageMultiplier,
      effectDuration: effectDuration * durationMultiplier,
      splitCount: splitCount,
    );
  }
}
// ═══════════════════════════════════════════════════════════
// PATCHED SECTION — drop this in to replace the old specials
// Covers: createCosmicSpecialAbility + all _horn/_wing/_let/
//         _pip/_mane/_mask/_kin/_mystic helpers + name tables
// ═══════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────
// COSMIC SPECIAL ABILITIES (Family × Element)  — OVERHAULED
// ─────────────────────────────────────────────────────────

/// Result of a cosmic special ability activation.
class CosmicSpecialResult {
  final List<Projectile> projectiles;
  final List<WingBeamEffect> beams;
  final int shieldHp;
  final double chargeTimer;
  final double chargeDamage;
  final double chargeSpeedMultiplier;
  final double chargeSweepRadius;
  final double chargeOvershootDistance;
  final double chargeFinalSweepRadius;
  final int selfHeal;
  final int shipHeal;
  final double blessingTimer;
  final double blessingHealPerTick;
  final double basicHasteTimer;
  final double basicHasteMultiplier;
  // Horn-only: a "wind-up" phase that plays BEFORE the dash starts.
  // The caster is locked in place during wind-up, the element-specific
  // wind-up visual (Dark void, Crystal orbit, Spirit phantoms) plays
  // around it, then the normal charge kicks off when this hits 0.
  // Survival-side handling lives in Phase 3.
  final double windUpTime;
  final String windUpElement;

  const CosmicSpecialResult({
    this.projectiles = const [],
    this.beams = const [],
    this.shieldHp = 0,
    this.chargeTimer = 0,
    this.chargeDamage = 0,
    this.chargeSpeedMultiplier = 1.0,
    this.chargeSweepRadius = 48.0,
    this.chargeOvershootDistance = 80.0,
    this.chargeFinalSweepRadius = 68.0,
    this.selfHeal = 0,
    this.shipHeal = 0,
    this.blessingTimer = 0,
    this.blessingHealPerTick = 0,
    this.basicHasteTimer = 0,
    this.basicHasteMultiplier = 1.0,
    this.windUpTime = 0,
    this.windUpElement = '',
  });
}

CosmicSpecialResult createCosmicSpecialAbility({
  required Offset origin,
  required double baseAngle,
  required String family,
  required String element,
  required double damage,
  required int maxHp,
  double casterPower = 2.5,
  double casterBeauty = 4.0,
  double casterIntelligence = 4.0,
  double casterStrength = 4.0,
  Offset? targetPos,
}) {
  final normalizedFamily = family.toLowerCase();
  CosmicSpecialResult rawResult;
  switch (family.toLowerCase()) {
    case 'horn':
      rawResult = _hornSpecial(
        origin,
        baseAngle,
        element,
        damage,
        maxHp,
        casterBeauty,
        casterIntelligence,
        targetPos,
      );
      break;
    case 'wing':
      rawResult = _wingSpecial(
        origin,
        baseAngle,
        element,
        damage,
        casterBeauty,
        casterIntelligence,
      );
      break;
    case 'let':
      rawResult = _letSpecial(
        origin,
        baseAngle,
        element,
        damage,
        targetPos,
        casterBeauty,
        casterIntelligence,
      );
      break;
    case 'pip':
      rawResult = _pipSpecial(
        origin,
        baseAngle,
        element,
        damage,
        casterBeauty,
        casterIntelligence,
      );
      break;
    case 'mane':
      rawResult = _maneSpecial(
        origin,
        baseAngle,
        element,
        damage,
        maxHp,
        casterBeauty,
        casterIntelligence,
        casterStrength,
      );
      break;
    case 'mask':
      rawResult = _maskSpecial(
        origin,
        baseAngle,
        element,
        damage,
        casterBeauty,
        casterIntelligence,
        targetPos,
      );
      break;
    case 'kin':
      rawResult = _kinSpecial(
        origin,
        baseAngle,
        element,
        damage,
        maxHp,
        casterPower,
        casterBeauty,
        casterIntelligence,
        targetPos,
      );
      break;
    case 'mystic':
      rawResult = _mysticSpecial(
        origin,
        baseAngle,
        element,
        damage,
        casterBeauty,
        casterIntelligence,
        casterStrength,
      );
      break;
    default:
      rawResult = CosmicSpecialResult(
        projectiles: List.generate(3, (i) {
          final a = baseAngle + (i - 1) * 0.18;
          return Projectile(
            position: Offset(origin.dx + cos(a) * 18, origin.dy + sin(a) * 18),
            angle: a,
            element: element,
            damage: damage * 2.0,
          );
        }),
      );
      break;
  }

  return _applyGuardianFamilyThresholds(
    rawResult,
    family: normalizedFamily,
    casterPower: casterPower,
    casterBeauty: casterBeauty,
    casterIntelligence: casterIntelligence,
    casterStrength: casterStrength,
  );
}

int _guardianStatTier(double stat) {
  final s = max(0.5, stat);
  if (s < 1.0) return 0;
  if (s < 2.0) return 1;
  if (s < 3.0) return 2;
  if (s < 4.0) return 3;
  if (s < 4.6) return 4;
  return 5;
}

int _dualGuardianTier(
  double a,
  double b, {
  double aWeight = 0.5,
  bool hardMin = false,
}) {
  final bWeight = (1.0 - aWeight).clamp(0.0, 1.0);
  final weighted = (max(0.5, a) * aWeight) + (max(0.5, b) * bWeight);
  final weightedTier = _guardianStatTier(weighted);
  final aTier = _guardianStatTier(a);
  final bTier = _guardianStatTier(b);
  if (hardMin) return min(weightedTier, min(aTier, bTier));
  return min(weightedTier, min(aTier, bTier) + 1);
}

double _guardianFamilySignal({
  required String family,
  required double casterPower,
  required double casterBeauty,
  required double casterIntelligence,
  required double casterStrength,
}) {
  final beauty = max(0.5, casterBeauty);
  final intelligence = max(0.5, casterIntelligence);
  final strength = max(0.5, casterStrength);

  return switch (family) {
    'horn' => strength * 0.62 + intelligence * 0.38,
    'wing' => intelligence * 0.60 + beauty * 0.40,
    'let' => beauty * 0.62 + intelligence * 0.38,
    'pip' => intelligence * 0.55 + beauty * 0.45,
    'mane' => strength * 0.62 + beauty * 0.38,
    'mask' => intelligence * 0.58 + beauty * 0.42,
    'kin' => beauty * 0.50 + intelligence * 0.50,
    'mystic' => beauty * 0.46 + intelligence * 0.40 + strength * 0.14,
    _ => max(beauty, intelligence),
  };
}

int _guardianFamilyTier({
  required String family,
  required double casterPower,
  required double casterBeauty,
  required double casterIntelligence,
  required double casterStrength,
}) {
  return switch (family) {
    'horn' => _dualGuardianTier(
      casterStrength,
      casterIntelligence,
      aWeight: 0.62,
    ),
    'wing' => _dualGuardianTier(
      casterIntelligence,
      casterBeauty,
      aWeight: 0.60,
    ),
    'let' => _dualGuardianTier(
      casterBeauty,
      casterIntelligence,
      aWeight: 0.62,
      hardMin: true,
    ),
    // Pip/Mask prefer speed in design, but speed is not passed into this
    // factory, so we use Int/Beauty as the tactical scaling proxy.
    'pip' => _dualGuardianTier(casterIntelligence, casterBeauty, aWeight: 0.55),
    'mane' => _dualGuardianTier(casterStrength, casterBeauty, aWeight: 0.62),
    'mask' => _dualGuardianTier(
      casterIntelligence,
      casterBeauty,
      aWeight: 0.58,
    ),
    // Kin is a hard dual gate: both Beauty and Intelligence must be present.
    'kin' => _dualGuardianTier(
      casterBeauty,
      casterIntelligence,
      aWeight: 0.50,
      hardMin: true,
    ),
    'mystic' => (() {
      final core = min(
        _guardianStatTier(casterBeauty),
        _guardianStatTier(casterIntelligence),
      );
      final strengthTier = _guardianStatTier(casterStrength);
      final burstBias = strengthTier >= 4
          ? 1
          : strengthTier <= 1
          ? -1
          : 0;
      return (core + burstBias).clamp(0, 5);
    })(),
    _ => _guardianStatTier(max(casterBeauty, casterIntelligence)),
  };
}

CosmicSpecialResult _applyGuardianFamilyThresholds(
  CosmicSpecialResult result, {
  required String family,
  required double casterPower,
  required double casterBeauty,
  required double casterIntelligence,
  required double casterStrength,
}) {
  final tier = _guardianFamilyTier(
    family: family,
    casterPower: casterPower,
    casterBeauty: casterBeauty,
    casterIntelligence: casterIntelligence,
    casterStrength: casterStrength,
  );
  final familySignal = _guardianFamilySignal(
    family: family,
    casterPower: casterPower,
    casterBeauty: casterBeauty,
    casterIntelligence: casterIntelligence,
    casterStrength: casterStrength,
  );
  final overcap = max(0.0, familySignal - 5.0);
  // Uncapped over-5 scaling so perfect 5.0 bases still gain from run buffs.
  final overcapMul = 1.0 + overcap * 0.08;

  final dmgMul = switch (tier) {
    0 => 0.52,
    1 => 0.66,
    2 => 0.80,
    3 => 0.92,
    4 => 1.00,
    _ => 1.18,
  };
  final lifeMul = switch (tier) {
    0 => 0.72,
    1 => 0.80,
    2 => 0.90,
    3 => 0.98,
    4 => 1.04,
    _ => 1.12,
  };
  final visualMul = switch (tier) {
    0 => 0.82,
    1 => 0.88,
    2 => 0.94,
    3 => 1.00,
    4 => 1.06,
    _ => 1.14,
  };
  final preservesAuthoredProjectileCount =
      family == 'mane' &&
      result.projectiles.isNotEmpty &&
      result.projectiles.every((p) => p.element == 'Light');
  final maxProjectiles = preservesAuthoredProjectileCount
      ? 999
      : switch (tier) {
          0 => 1,
          1 => 2,
          2 => 4,
          _ => 999,
        };

  final scaledProjectiles = result.projectiles
      .take(maxProjectiles)
      .map(
        (p) => _copyProjectile(
          p,
          damage: p.damage * dmgMul * overcapMul,
          life: family == 'pip'
              ? min(
                  p.life * lifeMul * (1.0 + overcap * 0.03),
                  kPipSpecialMaxProjectileLife,
                )
              : p.life * lifeMul * (1.0 + overcap * 0.03),
          visualScale: p.visualScale * visualMul * (1.0 + overcap * 0.04),
        ),
      )
      .toList(growable: false);
  final scaledBeams = result.beams
      .map(
        (b) => b.scaled(
          damageMultiplier: dmgMul * overcapMul,
          durationMultiplier: lifeMul * (1.0 + overcap * 0.03),
          widthMultiplier: visualMul * (1.0 + overcap * 0.04),
        ),
      )
      .toList(growable: false);

  final enableDefensiveRiders = tier >= 2;
  final enableHealingRiders = tier >= 3;
  final enableTempoRiders = tier >= 4;

  return CosmicSpecialResult(
    projectiles: scaledProjectiles,
    beams: scaledBeams,
    shieldHp: enableDefensiveRiders
        ? (result.shieldHp * dmgMul * overcapMul).round()
        : 0,
    chargeTimer: enableDefensiveRiders ? result.chargeTimer : 0,
    chargeDamage: enableDefensiveRiders
        ? result.chargeDamage * dmgMul * overcapMul
        : 0,
    chargeSpeedMultiplier: enableDefensiveRiders
        ? result.chargeSpeedMultiplier
        : 1.0,
    chargeSweepRadius: enableDefensiveRiders ? result.chargeSweepRadius : 48.0,
    chargeOvershootDistance: enableDefensiveRiders
        ? result.chargeOvershootDistance
        : 80.0,
    chargeFinalSweepRadius: enableDefensiveRiders
        ? result.chargeFinalSweepRadius
        : 68.0,
    selfHeal: enableHealingRiders
        ? (result.selfHeal * dmgMul * overcapMul).round()
        : 0,
    shipHeal: enableHealingRiders
        ? (result.shipHeal * dmgMul * overcapMul).round()
        : 0,
    blessingTimer: enableHealingRiders
        ? result.blessingTimer * lifeMul * (1.0 + overcap * 0.03)
        : 0,
    blessingHealPerTick: enableHealingRiders
        ? result.blessingHealPerTick * dmgMul * overcapMul
        : 0,
    basicHasteTimer: enableTempoRiders ? result.basicHasteTimer : 0,
    basicHasteMultiplier: enableTempoRiders ? result.basicHasteMultiplier : 1.0,
    // Wind-up phase passes straight through — gated by chargeTimer
    // (defensive rider), since wind-up only makes sense for horn
    // dashes which already require defensive-rider tier to fire.
    windUpTime: enableDefensiveRiders ? result.windUpTime : 0,
    windUpElement: enableDefensiveRiders ? result.windUpElement : '',
  );
}

// Effective stat range for ability scaling. The ceiling matches the canonical
// Power 180 internal limit, so Potential, Enhancement, and in-run boosts are
// handled consistently instead of being cut off at the legacy 5.0 band.
const double _abilityStatFloor = 0.5;
const double _abilityStatCeiling = double.infinity;

double _specialStatScaleFromBaseline(
  double stat, {
  double baseline = 4.0,
  double perPoint = 0.10,
  double min = 0.8,
  double max = 1.2,
}) {
  final clamped = stat > AlchemonStatSystem.legacyCombatCeiling
      ? AlchemonStatSystem.legacyGameplayRating(stat)
      : stat
            .clamp(_abilityStatFloor, AlchemonStatSystem.legacyCombatCeiling)
            .toDouble();
  return (1.0 + (clamped - baseline) * perPoint).clamp(min, max).toDouble();
}

double _specialCountScaleFromBaseline(
  double beauty,
  double intelligence, {
  double baseline = 4.0,
  double beautyPerPoint = 0.10,
  double intelligencePerPoint = 0.14,
  double min = 0.72,
  double max = 1.34,
}) {
  final clampedBeauty = beauty > AlchemonStatSystem.legacyCombatCeiling
      ? AlchemonStatSystem.legacyGameplayRating(beauty)
      : beauty
            .clamp(_abilityStatFloor, AlchemonStatSystem.legacyCombatCeiling)
            .toDouble();
  final clampedIntelligence =
      intelligence > AlchemonStatSystem.legacyCombatCeiling
      ? AlchemonStatSystem.legacyGameplayRating(intelligence)
      : intelligence
            .clamp(_abilityStatFloor, AlchemonStatSystem.legacyCombatCeiling)
            .toDouble();
  return (1.0 +
          (clampedBeauty - baseline) * beautyPerPoint +
          (clampedIntelligence - baseline) * intelligencePerPoint)
      .clamp(min, max)
      .toDouble();
}

Projectile _copyProjectile(
  Projectile p, {
  Offset? position,
  double? angle,
  double? life,
  String? element,
  double? damage,
  double? speedMultiplier,
  double? radiusMultiplier,
  bool? piercing,
  bool? homing,
  double? homingStrength,
  double? visualScale,
  ProjectileVisualStyle? visualStyle,
  bool? stationary,
  Offset? orbitCenter,
  double? orbitAngle,
  double? orbitRadius,
  double? orbitSpeed,
  double? orbitTime,
  bool? followShipOrbit,
  bool? followSourceCompanion,
  bool? reflectsProjectiles,
  bool? transferToShipOrbit,
  double? shipOrbitDelay,
  Offset? transferOrbitCenter,
  bool? holdOrbit,
  double? shipOrbitTransferSpeed,
  bool? decoy,
  double? decoyHp,
  int? deathExplosionCount,
  double? deathExplosionDamage,
  double? deathExplosionRadius,
  double? tauntRadius,
  double? tauntStrength,
  int? bounceCount,
  double? trailInterval,
  double? trailDamage,
  double? trailLife,
  double? turretInterval,
  double? turretDamage,
  double? turretHomingStrength,
  double? turretSpeedMultiplier,
  double? interceptRadius,
  int? interceptCharges,
  double? snareRadius,
  double? snareMoveMultiplier,
  int? clusterCount,
  double? clusterDamage,
  double? letCasterIntelligence,
  int? sourceSlotIndex,
  int? attachedToSlot,
  int? chainLightningCharges,
  String? abilityFamily,
  AbilityEffectKind? hitEffect,
  AbilityEffectKind? killEffect,
  AbilityEffectKind? pierceEffect,
  AbilityEffectKind? tickEffect,
  double? effectPower,
  double? effectRadius,
  double? effectDuration,
  double? effectChance,
  int? effectCount,
  int? effectStacks,
  bool? effectRequiresKill,
  bool? effectOnBoss,
  Set<int>? effectHitIds,
}) {
  final clone = Projectile(
    position: position ?? p.position,
    angle: angle ?? p.angle,
    life: life ?? p.life,
    element: element ?? p.element,
    damage: damage ?? p.damage,
    speedMultiplier: speedMultiplier ?? p.speedMultiplier,
    radiusMultiplier: radiusMultiplier ?? p.radiusMultiplier,
    piercing: piercing ?? p.piercing,
    homing: homing ?? p.homing,
    homingStrength: homingStrength ?? p.homingStrength,
    visualScale: visualScale ?? p.visualScale,
    visualStyle: visualStyle ?? p.visualStyle,
    stationary: stationary ?? p.stationary,
    orbitCenter: orbitCenter ?? p.orbitCenter,
    orbitAngle: orbitAngle ?? p.orbitAngle,
    orbitRadius: orbitRadius ?? p.orbitRadius,
    orbitSpeed: orbitSpeed ?? p.orbitSpeed,
    orbitTime: orbitTime ?? p.orbitTime,
    followShipOrbit: followShipOrbit ?? p.followShipOrbit,
    followSourceCompanion: followSourceCompanion ?? p.followSourceCompanion,
    reflectsProjectiles: reflectsProjectiles ?? p.reflectsProjectiles,
    transferToShipOrbit: transferToShipOrbit ?? p.transferToShipOrbit,
    shipOrbitDelay: shipOrbitDelay ?? p.shipOrbitDelay,
    transferOrbitCenter: transferOrbitCenter ?? p.transferOrbitCenter,
    holdOrbit: holdOrbit ?? p.holdOrbit,
    shipOrbitTransferSpeed: shipOrbitTransferSpeed ?? p.shipOrbitTransferSpeed,
    decoy: decoy ?? p.decoy,
    decoyHp: decoyHp ?? p.decoyHp,
    deathExplosionCount: deathExplosionCount ?? p.deathExplosionCount,
    deathExplosionDamage: deathExplosionDamage ?? p.deathExplosionDamage,
    deathExplosionRadius: deathExplosionRadius ?? p.deathExplosionRadius,
    tauntRadius: tauntRadius ?? p.tauntRadius,
    tauntStrength: tauntStrength ?? p.tauntStrength,
    bounceCount: bounceCount ?? p.bounceCount,
    trailInterval: trailInterval ?? p.trailInterval,
    trailDamage: trailDamage ?? p.trailDamage,
    trailLife: trailLife ?? p.trailLife,
    turretInterval: turretInterval ?? p.turretInterval,
    turretDamage: turretDamage ?? p.turretDamage,
    turretHomingStrength: turretHomingStrength ?? p.turretHomingStrength,
    turretSpeedMultiplier: turretSpeedMultiplier ?? p.turretSpeedMultiplier,
    interceptRadius: interceptRadius ?? p.interceptRadius,
    interceptCharges: interceptCharges ?? p.interceptCharges,
    snareRadius: snareRadius ?? p.snareRadius,
    snareMoveMultiplier: snareMoveMultiplier ?? p.snareMoveMultiplier,
    clusterCount: clusterCount ?? p.clusterCount,
    clusterDamage: clusterDamage ?? p.clusterDamage,
    letCasterIntelligence: letCasterIntelligence ?? p.letCasterIntelligence,
    sourceSlotIndex: sourceSlotIndex ?? p.sourceSlotIndex,
    attachedToSlot: attachedToSlot ?? p.attachedToSlot,
    chainLightningCharges: chainLightningCharges ?? p.chainLightningCharges,
    abilityFamily: abilityFamily ?? p.abilityFamily,
    hitEffect: hitEffect ?? p.hitEffect,
    killEffect: killEffect ?? p.killEffect,
    pierceEffect: pierceEffect ?? p.pierceEffect,
    tickEffect: tickEffect ?? p.tickEffect,
    effectPower: effectPower ?? p.effectPower,
    effectRadius: effectRadius ?? p.effectRadius,
    effectDuration: effectDuration ?? p.effectDuration,
    effectChance: effectChance ?? p.effectChance,
    effectCount: effectCount ?? p.effectCount,
    effectStacks: effectStacks ?? p.effectStacks,
    effectRequiresKill: effectRequiresKill ?? p.effectRequiresKill,
    effectOnBoss: effectOnBoss ?? p.effectOnBoss,
    effectHitIds: effectHitIds ?? Set<int>.of(p.effectHitIds),
  );
  clone.pierceCount = p.pierceCount;
  clone.trailTimer = p.trailTimer;
  clone.turretTimer = p.turretTimer;
  clone.clustered = p.clustered;
  return clone;
}

// Cooldown multipliers tuned for Cosmic Survival's bullet-hell pacing.
// Mask multipliers are high because survival masks are long-lived trap
// commitments. Lets are nudged up to reduce on-screen meteor spam; Pip/Mane/Wing
// get small bumps to stop them from dominating ability-cast windows.
double elementalSpecialCooldownMultiplierSurvival(
  String family,
  String element,
) {
  final f = family.toLowerCase();
  return switch (f) {
    'mask' => switch (element) {
      // Heavy commitment cadence — traps persist 30+s with the boosted
      // persistence floor, so the *placement* is the rare action, not
      // the upkeep. Each cast should feel earned.
      'Light' => 3.60,
      'Dark' => 3.20,
      'Spirit' => 2.95,
      'Blood' => 2.65,
      'Ice' => 2.40,
      'Lightning' => 2.20,
      'Plant' || 'Earth' => 2.05,
      'Lava' || 'Crystal' => 1.90,
      'Poison' || 'Steam' => 1.75,
      'Fire' => 1.65,
      'Dust' => 1.55,
      'Water' => 1.50,
      'Mud' => 1.45,
      'Air' => 1.40,
      _ => 1.70,
    },
    'let' => switch (element) {
      'Dark' => 2.10,
      'Spirit' => 1.95,
      'Blood' || 'Light' || 'Ice' => 1.85,
      // Crystal Let per design has its CD halved (weaker dmg in
      // exchange) — see _scaleLetProjectile crystalDamageMul = 0.58.
      'Crystal' => 0.55,
      'Plant' || 'Lightning' => 1.55,
      'Lava' || 'Earth' || 'Mud' || 'Steam' => 1.42,
      'Water' || 'Poison' => 1.25,
      'Fire' || 'Dust' || 'Air' => 1.15,
      _ => 1.30,
    },
    'pip' => switch (element) {
      'Dark' => 1.75,
      'Blood' || 'Light' || 'Spirit' || 'Crystal' => 1.48,
      'Fire' || 'Ice' || 'Mud' || 'Water' || 'Poison' || 'Steam' => 1.22,
      'Air' || 'Dust' || 'Lightning' || 'Earth' || 'Plant' => 1.05,
      _ => 1.10,
    },
    'mane' => switch (element) {
      'Dark' || 'Light' || 'Spirit' || 'Crystal' => 1.62,
      'Lava' ||
      'Blood' ||
      'Earth' ||
      'Plant' ||
      'Steam' ||
      'Water' ||
      'Mud' ||
      'Ice' => 1.30,
      _ => 1.10,
    },
    'wing' => switch (element) {
      'Blood' || 'Light' || 'Lightning' => 1.62,
      'Dark' => 1.42,
      'Fire' ||
      'Lava' ||
      'Steam' ||
      'Water' ||
      'Plant' ||
      'Crystal' ||
      'Spirit' => 1.30,
      _ => 1.10,
    },
    // Mystics are environment-changing ultimates. Big rare casts that
    // last 15–30s. Variety within the long-cadence band — heaviest
    // ultimates run 1.4–1.7×, lighter ones 1.0–1.15×. Combined with
    // family multiplier 6.0 + 60s floor, naturals land 60s–180s.
    'mystic' => switch (element) {
      'Dark' || 'Light' || 'Spirit' => 1.65,
      'Lava' || 'Crystal' || 'Earth' => 1.50,
      'Blood' || 'Plant' || 'Fire' => 1.35,
      'Lightning' || 'Ice' || 'Steam' => 1.20,
      'Poison' || 'Mud' || 'Water' => 1.10,
      'Air' || 'Dust' => 1.00,
      _ => 1.20,
    },
    _ => 1.0,
  };
}

double elementalSpecialCooldownMultiplier(String family, String element) {
  final f = family.toLowerCase();
  return switch (f) {
    'mask' => switch (element) {
      'Light' => 2.60,
      'Dark' => 2.25,
      'Spirit' => 2.10,
      'Blood' => 1.85,
      'Ice' => 1.65,
      'Lightning' => 1.45,
      'Plant' || 'Earth' => 1.40,
      'Lava' || 'Crystal' => 1.35,
      'Poison' || 'Steam' => 1.25,
      'Fire' => 1.20,
      'Dust' => 1.15,
      'Water' => 1.10,
      'Mud' => 1.05,
      'Air' => 0.95,
      _ => 1.20,
    },
    'let' => switch (element) {
      'Dark' => 1.90,
      'Spirit' => 1.75,
      'Blood' || 'Light' || 'Ice' => 1.65,
      'Crystal' || 'Plant' || 'Lightning' => 1.35,
      'Lava' || 'Earth' || 'Mud' || 'Steam' => 1.25,
      'Water' || 'Poison' => 1.10,
      'Fire' || 'Dust' || 'Air' => 1.00,
      _ => 1.15,
    },
    'pip' => switch (element) {
      'Dark' => 1.60,
      'Blood' || 'Light' || 'Spirit' || 'Crystal' => 1.35,
      'Fire' || 'Ice' || 'Mud' || 'Water' || 'Poison' || 'Steam' => 1.12,
      'Air' || 'Dust' || 'Lightning' || 'Earth' || 'Plant' => 0.95,
      _ => 1.00,
    },
    'mane' => switch (element) {
      'Dark' || 'Light' || 'Spirit' || 'Crystal' => 1.55,
      'Lava' ||
      'Blood' ||
      'Earth' ||
      'Plant' ||
      'Steam' ||
      'Water' ||
      'Mud' ||
      'Ice' => 1.25,
      _ => 1.05,
    },
    'wing' => switch (element) {
      'Blood' || 'Light' || 'Lightning' => 1.55,
      'Dark' => 1.35,
      'Fire' ||
      'Lava' ||
      'Steam' ||
      'Water' ||
      'Plant' ||
      'Crystal' ||
      'Spirit' => 1.25,
      _ => 1.05,
    },
    _ => 1.0,
  };
}

AbilityEffectKind _pipHitEffect(String element) => switch (element) {
  'Air' => AbilityEffectKind.knockback,
  'Lava' => AbilityEffectKind.burn,
  'Poison' => AbilityEffectKind.poison,
  'Ice' => AbilityEffectKind.freeze,
  'Mud' => AbilityEffectKind.slow,
  _ => AbilityEffectKind.none,
};

AbilityEffectKind _pipKillEffect(String element) => switch (element) {
  'Dust' => AbilityEffectKind.slow,
  'Plant' => AbilityEffectKind.alchemyBonus,
  'Blood' || 'Light' => AbilityEffectKind.leech,
  'Spirit' => AbilityEffectKind.buff,
  'Crystal' => AbilityEffectKind.taunt,
  'Fire' => AbilityEffectKind.burn,
  'Steam' => AbilityEffectKind.buff,
  'Water' => AbilityEffectKind.splash,
  'Dark' => AbilityEffectKind.blackHole,
  'Earth' => AbilityEffectKind.cooldownRefund,
  _ => AbilityEffectKind.none,
};

AbilityEffectKind _manePierceEffect(String element) => switch (element) {
  'Air' => AbilityEffectKind.knockback,
  'Dust' => AbilityEffectKind.suppressShooting,
  'Lava' => AbilityEffectKind.burn,
  'Poison' => AbilityEffectKind.poison,
  'Plant' => AbilityEffectKind.root,
  'Blood' => AbilityEffectKind.leech,
  'Earth' => AbilityEffectKind.split,
  'Light' => AbilityEffectKind.buff,
  'Crystal' => AbilityEffectKind.splash,
  'Fire' => AbilityEffectKind.burn,
  'Lightning' => AbilityEffectKind.chain,
  'Steam' => AbilityEffectKind.geyser,
  'Dark' => AbilityEffectKind.blackHole,
  'Ice' => AbilityEffectKind.freeze,
  'Mud' => AbilityEffectKind.split,
  'Water' => AbilityEffectKind.carry,
  _ => AbilityEffectKind.none,
};

double _specialTrapPersistenceScale(
  Projectile p, {
  required double intelligence,
}) {
  final isTrapLike =
      p.stationary ||
      p.holdOrbit ||
      p.decoy ||
      p.snareRadius > 0 ||
      p.tauntRadius > 0 ||
      p.turretInterval > 0 ||
      p.followShipOrbit ||
      p.transferToShipOrbit;
  if (!isTrapLike) return 1.0;
  // Waves spawn every ~0.5s; raise the floor so traps outlast multiple
  // waves and feel like commitments rather than flickers.
  return _specialStatScaleFromBaseline(
    intelligence,
    perPoint: 0.26,
    min: 3.0,
    max: 5.0,
  );
}

Projectile _scaleLetProjectile(
  Projectile p, {
  required double beauty,
  required double intelligence,
  required bool isMeteorCore,
}) {
  final impactScale = _specialStatScaleFromBaseline(
    beauty,
    perPoint: 0.12,
    min: 0.78,
    max: 1.28,
  );
  final visualScaleMul = _specialStatScaleFromBaseline(
    beauty,
    perPoint: 0.18,
    min: 0.76,
    max: 1.36,
  );
  final radiusScaleMul = _specialStatScaleFromBaseline(
    beauty,
    perPoint: 0.16,
    min: 0.78,
    max: 1.32,
  );
  final guidanceScale = _specialStatScaleFromBaseline(
    intelligence,
    perPoint: 0.14,
    min: 0.78,
    max: 1.30,
  );
  final durationScale = _specialStatScaleFromBaseline(
    intelligence,
    perPoint: 0.13,
    min: 0.78,
    max: 1.32,
  );
  final falloutScale = _specialStatScaleFromBaseline(
    intelligence,
    perPoint: 0.10,
    min: 0.86,
    max: 1.24,
  );
  final trapPersistenceScale = _specialTrapPersistenceScale(
    p,
    intelligence: intelligence,
  );
  final countScale = _specialCountScaleFromBaseline(beauty, intelligence);
  final scaledClusterCount = p.clusterCount > 0
      ? max(0, (p.clusterCount * countScale).round())
      : 0;

  return _copyProjectile(
    p,
    damage: p.damage * impactScale * (isMeteorCore ? 1.05 : 1.0),
    life: p.life * durationScale * trapPersistenceScale,
    speedMultiplier: p.speedMultiplier * (p.stationary ? 1.0 : guidanceScale),
    radiusMultiplier: p.radiusMultiplier * radiusScaleMul,
    homingStrength: p.homing
        ? p.homingStrength * guidanceScale
        : p.homingStrength,
    visualScale: p.visualScale * visualScaleMul * (isMeteorCore ? 1.08 : 1.0),
    orbitRadius: p.orbitRadius * radiusScaleMul,
    orbitSpeed: p.orbitSpeed * guidanceScale,
    orbitTime: p.orbitTime * durationScale * trapPersistenceScale,
    trailInterval: p.trailInterval > 0
        ? (p.trailInterval / guidanceScale).clamp(0.05, 0.35)
        : p.trailInterval,
    trailDamage: p.trailDamage * impactScale,
    trailLife: p.trailLife > 0
        ? p.trailLife * durationScale * falloutScale
        : p.trailLife,
    snareRadius: p.snareRadius * radiusScaleMul,
    clusterCount: scaledClusterCount,
    clusterDamage: p.clusterDamage * impactScale,
    abilityFamily: 'let',
    hitEffect: p.hitEffect,
    killEffect: p.killEffect,
    effectPower: p.effectPower > 0
        ? p.effectPower * impactScale
        : p.damage * impactScale * 0.32,
    effectRadius: p.effectRadius > 0
        ? p.effectRadius * radiusScaleMul
        : 104.0 * radiusScaleMul,
    effectDuration: p.effectDuration > 0
        ? p.effectDuration * durationScale
        : 2.2 * durationScale,
    effectCount: p.effectCount > 0 ? p.effectCount : 3,
  );
}

// ─────────────────────────────────────────────────────────
// HORN — Shield Charge + Nova
// Design: Big meaty damage, meaningful shields, satisfying nova
// ─────────────────────────────────────────────────────────
CosmicSpecialResult _hornSpecial(
  Offset origin,
  double baseAngle,
  String element,
  double damage,
  int maxHp,
  double casterBeauty,
  double casterIntelligence,
  Offset? targetPos,
) {
  int scaledCount(int base, {int min = 3, int max = 18}) {
    final scale = _specialCountScaleFromBaseline(
      casterBeauty,
      casterIntelligence,
      beautyPerPoint: 0.06,
      intelligencePerPoint: 0.08,
      min: 0.78,
      max: 1.22,
    );
    return (base * scale).round().clamp(min, max);
  }

  Projectile scaleHornProjectile(Projectile p) {
    final impactScale = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.10,
      min: 0.84,
      max: 1.20,
    );
    final shieldVisualScale = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.12,
      min: 0.82,
      max: 1.22,
    );
    final controlScale = _specialStatScaleFromBaseline(
      casterIntelligence,
      perPoint: 0.10,
      min: 0.84,
      max: 1.20,
    );
    final durationScale = _specialStatScaleFromBaseline(
      casterIntelligence,
      perPoint: 0.08,
      min: 0.88,
      max: 1.16,
    );
    final countScale = _specialCountScaleFromBaseline(
      casterBeauty,
      casterIntelligence,
      beautyPerPoint: 0.04,
      intelligencePerPoint: 0.05,
      min: 0.85,
      max: 1.22,
    );
    return _copyProjectile(
      p,
      damage: p.damage * impactScale * 0.88,
      life: p.life * durationScale,
      speedMultiplier: p.speedMultiplier * controlScale,
      radiusMultiplier: p.radiusMultiplier * shieldVisualScale,
      homingStrength: p.homing
          ? p.homingStrength * controlScale
          : p.homingStrength,
      visualScale: p.visualScale * shieldVisualScale,
      snareRadius: p.snareRadius * shieldVisualScale,
      tauntRadius: p.tauntRadius * shieldVisualScale,
      interceptRadius: p.interceptRadius * shieldVisualScale,
      trailInterval: p.trailInterval > 0
          ? (p.trailInterval / controlScale).clamp(0.07, 0.35).toDouble()
          : p.trailInterval,
      trailDamage: p.trailDamage * impactScale,
      trailLife: p.trailLife > 0 ? p.trailLife * durationScale : p.trailLife,
      turretInterval: p.turretInterval > 0
          ? (p.turretInterval / controlScale).clamp(0.45, 1.8).toDouble()
          : p.turretInterval,
      turretDamage: p.turretDamage * impactScale,
      turretHomingStrength: p.turretHomingStrength > 0
          ? p.turretHomingStrength * controlScale
          : p.turretHomingStrength,
      decoyHp: p.decoyHp * shieldVisualScale,
      deathExplosionCount: p.deathExplosionCount > 0
          ? (p.deathExplosionCount * countScale).round().clamp(1, 12)
          : p.deathExplosionCount,
      deathExplosionDamage: p.deathExplosionDamage * impactScale,
      deathExplosionRadius: p.deathExplosionRadius * shieldVisualScale,
      clusterCount: p.clusterCount > 0
          ? (p.clusterCount * countScale).round().clamp(1, 8)
          : p.clusterCount,
      clusterDamage: p.clusterDamage * impactScale,
    );
  }

  CosmicSpecialResult finalize(CosmicSpecialResult result) {
    final impactScale = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.11,
      min: 0.84,
      max: 1.22,
    );
    final guardScale = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.10,
      min: 0.84,
      max: 1.20,
    );
    final controlScale = _specialStatScaleFromBaseline(
      casterIntelligence,
      perPoint: 0.08,
      min: 0.88,
      max: 1.16,
    );
    final sustainScale = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.08,
      min: 0.86,
      max: 1.18,
    );
    return CosmicSpecialResult(
      projectiles: result.projectiles.map(scaleHornProjectile).toList(),
      shieldHp: (result.shieldHp * guardScale).round(),
      // Standard horn charge clamps to 0.2–1.6s. Skip the clamp when
      // chargeTimer is 0 (Light's no-ram channel) so the channel
      // doesn't get a phantom 0.2s pre-charge.
      chargeTimer: result.chargeTimer == 0
          ? 0
          : (result.chargeTimer / controlScale).clamp(0.2, 1.6).toDouble(),
      chargeDamage: result.chargeDamage * impactScale,
      chargeSpeedMultiplier: (result.chargeSpeedMultiplier * controlScale)
          .clamp(0.45, 2.10)
          .toDouble(),
      chargeSweepRadius: result.chargeSweepRadius * guardScale,
      chargeOvershootDistance: result.chargeOvershootDistance,
      chargeFinalSweepRadius: result.chargeFinalSweepRadius * guardScale,
      selfHeal: (result.selfHeal * sustainScale).round(),
      shipHeal: (result.shipHeal * sustainScale).round(),
      blessingTimer: result.blessingTimer,
      blessingHealPerTick: result.blessingHealPerTick,
      basicHasteTimer: result.basicHasteTimer,
      basicHasteMultiplier: result.basicHasteMultiplier,
      // Per-design wind-up time is stat-invariant (like wing-Lightning's
      // charge). Pass through unscaled.
      windUpTime: result.windUpTime,
      windUpElement: result.windUpElement,
    );
  }

  // Helper: full 360° ring
  List<Projectile> ring(
    int n,
    double dmgMul, {
    double life = 2.0,
    double speed = 1.0,
    double radius = 1.5,
    double vs = 1.4,
    bool pierce = false,
    bool home = false,
    double homeStr = 0,
    double snareRadius = 0,
    double snareMoveMultiplier = 1.0,
    double tauntRadius = 0,
    double tauntStrength = 0,
    double interceptRadius = 0,
    int interceptCharges = 0,
    bool stationary = false,
    int bounceCount = 0,
    double trailInterval = 0,
    double trailDamage = 0,
    double trailLife = 0,
    int clusterCount = 0,
    double clusterDamage = 0,
    double turretInterval = 0,
    double turretDamage = 0,
    double turretHomingStrength = 0,
    double turretSpeedMultiplier = 1.0,
    double decoyHp = 0,
    int deathExplosionCount = 0,
    double deathExplosionDamage = 0,
    double deathExplosionRadius = 1.5,
  }) {
    final scaledN = scaledCount(n, min: 3, max: 18);
    return List.generate(scaledN, (i) {
      final a = i * (pi * 2 / scaledN);
      return Projectile(
        position: Offset(origin.dx + cos(a) * 14, origin.dy + sin(a) * 14),
        angle: a,
        element: element,
        damage: damage * dmgMul,
        life: life,
        speedMultiplier: speed,
        radiusMultiplier: radius,
        visualScale: vs,
        visualStyle: ProjectileVisualStyle.hornImpact,
        piercing: pierce,
        homing: home,
        homingStrength: homeStr,
        snareRadius: snareRadius,
        snareMoveMultiplier: snareMoveMultiplier,
        tauntRadius: tauntRadius,
        tauntStrength: tauntStrength,
        interceptRadius: interceptRadius,
        interceptCharges: interceptCharges,
        stationary: stationary,
        bounceCount: bounceCount,
        trailInterval: trailInterval,
        trailDamage: trailDamage,
        trailLife: trailLife,
        clusterCount: clusterCount,
        clusterDamage: clusterDamage,
        turretInterval: turretInterval,
        turretDamage: turretDamage,
        turretHomingStrength: turretHomingStrength,
        turretSpeedMultiplier: turretSpeedMultiplier,
        decoy: decoyHp > 0,
        decoyHp: decoyHp,
        deathExplosionCount: deathExplosionCount,
        deathExplosionDamage: deathExplosionDamage,
        deathExplosionRadius: deathExplosionRadius,
      );
    });
  }

  // (Legacy `cone`/`brace` helpers removed — the bulky-tank rewrite
  // no longer fires multi-projectile fans/braces; the new `zone`
  // helper inside the switch below covers all element impact spawns.)

  // ─────────────────────────────────────────────────────────
  // HORN — Bulky Defense Tank (Charge + Guard + Impact)
  // Theme: heavy slow ram, big shield, taunts, burst impact damage.
  // Per-element layer = ONE clear control twist. Passives (Air, Mud,
  // Poison) bypass this switch entirely via isPassiveOnlyCosmicAbility.
  // ─────────────────────────────────────────────────────────

  // Stationary impact-zone factory — every horn special drops one or
  // more of these at impact. Keeps per-element code tight.
  Projectile zone({
    required Offset position,
    required double angleArg,
    required double life,
    required double visualScale,
    required double radiusMultiplier,
    double tauntRadius = 0,
    double tauntStrength = 0,
    AbilityEffectKind tickEffect = AbilityEffectKind.none,
    double effectPower = 0,
    double effectRadius = 0,
    double effectDuration = 0,
    double snareRadius = 0,
    double snareMoveMultiplier = 1.0,
    double interceptRadius = 0,
    int interceptCharges = 0,
    double decoyHp = 0,
    int deathExplosionCount = 0,
    double deathExplosionDamage = 0,
    double deathExplosionRadius = 1.5,
    double turretInterval = 0,
    double turretDamage = 0,
    double turretSpeedMultiplier = 1.0,
    Offset? orbitCenter,
    double orbitRadius = 0,
    double orbitSpeed = 0,
    double orbitAngle = 0,
  }) {
    return Projectile(
      position: position,
      angle: angleArg,
      element: element,
      damage: 0,
      life: life,
      speedMultiplier: 0,
      stationary: true,
      piercing: true,
      radiusMultiplier: radiusMultiplier,
      visualScale: visualScale,
      visualStyle: ProjectileVisualStyle.hornImpact,
      // Tag every horn impact zone so survival-side lookups
      // (Light barrier channel/protect/bounce, Spirit phantom
      // particles, Crystal orbital sparkles) can find them.
      abilityFamily: 'horn',
      tauntRadius: tauntRadius,
      tauntStrength: tauntStrength,
      tickEffect: tickEffect,
      effectPower: effectPower,
      effectRadius: effectRadius,
      effectDuration: effectDuration,
      snareRadius: snareRadius,
      snareMoveMultiplier: snareMoveMultiplier,
      interceptRadius: interceptRadius,
      interceptCharges: interceptCharges,
      decoy: decoyHp > 0,
      decoyHp: decoyHp,
      deathExplosionCount: deathExplosionCount,
      deathExplosionDamage: deathExplosionDamage,
      deathExplosionRadius: deathExplosionRadius,
      turretInterval: turretInterval,
      turretDamage: turretDamage,
      turretSpeedMultiplier: turretSpeedMultiplier,
      orbitCenter: orbitCenter,
      orbitRadius: orbitRadius,
      orbitSpeed: orbitSpeed,
      orbitAngle: orbitAngle,
      orbitTime: orbitRadius > 0 ? life : 0,
      holdOrbit: orbitRadius > 0,
    );
  }

  switch (element) {
    case 'Fire':
      // Impact ignites the lane in a burning trail. Five fire patches
      // anchored BEHIND the wing's impact point — the deferred-burst
      // shift makes them land along the charge path, painting the
      // lane the wing rode through. Taunts + DoT inside the flames.
      return finalize(
        CosmicSpecialResult(
          shieldHp: (maxHp * 0.55).round(),
          chargeTimer: 0.9,
          chargeDamage: damage * 2.0,
          chargeSpeedMultiplier: 0.78,
          chargeSweepRadius: 70.0,
          chargeOvershootDistance: 30.0,
          chargeFinalSweepRadius: 100.0,
          projectiles: List.generate(5, (i) {
            final back = i * 32.0;
            return zone(
              position: Offset(
                origin.dx - cos(baseAngle) * back,
                origin.dy - sin(baseAngle) * back,
              ),
              angleArg: baseAngle,
              life: 4.5,
              visualScale: 1.5,
              radiusMultiplier: 1.5,
              tauntRadius: 130.0,
              tauntStrength: 1.4,
              tickEffect: AbilityEffectKind.burn,
              effectPower: damage * 0.32,
              effectRadius: 60.0,
              effectDuration: 4.5,
            );
          }),
        ),
      );

    case 'Lava':
      // Fire-powered tank. Long charge with a glowing build-up
      // (survival-side telegraph), then heavy slam. No persistent
      // pool — kills detonate into a one-shot fire explosion VFX +
      // homing flames (survival on-kill hook).
      return finalize(
        CosmicSpecialResult(
          shieldHp: (maxHp * 0.70).round(),
          chargeTimer: 1.2,
          chargeDamage: damage * 3.6,
          chargeSpeedMultiplier: 0.55,
          chargeSweepRadius: 88.0,
          chargeOvershootDistance: 30.0,
          chargeFinalSweepRadius: 140.0,
          projectiles: const [],
        ),
      );

    case 'Lightning':
      // Reactive guard — damage absorbed by the shield during charge
      // is released as a chain-lightning shockwave on impact. The
      // absorb-and-discharge logic is wired in survival (Phase 3);
      // here we set up the impact shockwave with a base magnitude.
      return finalize(
        CosmicSpecialResult(
          shieldHp: (maxHp * 0.45).round(),
          chargeTimer: 0.6,
          chargeDamage: damage * 2.0,
          chargeSpeedMultiplier: 1.10,
          chargeSweepRadius: 56.0,
          chargeOvershootDistance: 70.0,
          chargeFinalSweepRadius: 100.0,
          projectiles: [
            zone(
              position: origin,
              angleArg: baseAngle,
              life: 0.6,
              visualScale: 2.4,
              radiusMultiplier: 2.0,
              tickEffect: AbilityEffectKind.chain,
              effectPower: damage * 1.4,
              effectRadius: 140.0,
              effectDuration: 0.6,
            ),
          ],
        ),
      );

    case 'Water':
      // Charges in a full circular sweep around the cast point (path
      // logic in survival), then drops a whirlpool at center that
      // pulls enemies in and pulses damage. chargeOvershootDistance
      // here doubles as the circle radius (survival clamps 90–200).
      return finalize(
        CosmicSpecialResult(
          shieldHp: (maxHp * 0.55).round(),
          chargeTimer: 0.9,
          chargeDamage: damage * 1.6,
          chargeSpeedMultiplier: 0.95,
          chargeSweepRadius: 56.0,
          chargeOvershootDistance: 140.0,
          chargeFinalSweepRadius: 130.0,
          projectiles: [
            zone(
              position: origin,
              angleArg: baseAngle,
              life: 4.5,
              visualScale: 2.4,
              radiusMultiplier: 2.5,
              tickEffect: AbilityEffectKind.pull,
              effectPower: damage * 0.40,
              effectRadius: 140.0,
              effectDuration: 4.5,
              snareRadius: 140.0,
              snareMoveMultiplier: 0.18,
            ),
          ],
          shipHeal: max(1, (CosmicBalance.shipMaxHealth * 0.025).round()),
        ),
      );

    case 'Ice':
      // Dashes SIDEWAYS (perpendicular to enemy direction) creating
      // an ice wall segment-by-segment along its path. The custom
      // dash + segment spawning is wired survival-side; no
      // deferred-burst projectiles here — the wall is built live
      // during the charge.
      return finalize(
        CosmicSpecialResult(
          shieldHp: (maxHp * 0.60).round(),
          chargeTimer: 0.8,
          chargeDamage: damage * 1.8,
          chargeSpeedMultiplier: 1.30,
          chargeSweepRadius: 50.0,
          chargeOvershootDistance: 0,
          chargeFinalSweepRadius: 80.0,
          projectiles: const [],
        ),
      );

    case 'Steam':
      // Pressurized geyser at impact — launches enemies up briefly
      // and burns. Phase 5: if the slam KILLS an enemy, the special
      // cooldown is instantly reset AND a second geyser spawns at
      // the kill site (chainable on a streak).
      return finalize(
        CosmicSpecialResult(
          shieldHp: (maxHp * 0.50).round(),
          chargeTimer: 0.8,
          chargeDamage: damage * 1.9,
          chargeSpeedMultiplier: 0.95,
          chargeSweepRadius: 64.0,
          chargeOvershootDistance: 60.0,
          chargeFinalSweepRadius: 95.0,
          projectiles: [
            zone(
              position: origin,
              angleArg: baseAngle,
              life: 3.0,
              visualScale: 2.4,
              radiusMultiplier: 2.2,
              tauntRadius: 130.0,
              tauntStrength: 1.2,
              tickEffect: AbilityEffectKind.geyser,
              effectPower: damage * 0.65,
              effectRadius: 120.0,
              effectDuration: 3.0,
            ),
          ],
        ),
      );

    case 'Earth':
      // Heaviest tank. Impact leaves a substitute clone (high-HP
      // decoy that taunts) plus periodic mini-earthquakes that damage
      // nearby enemies. zoneDamage tick handles the earthquake pulses.
      return finalize(
        CosmicSpecialResult(
          shieldHp: (maxHp * 0.78).round(),
          chargeTimer: 1.4,
          chargeDamage: damage * 2.8,
          chargeSpeedMultiplier: 0.55,
          chargeSweepRadius: 88.0,
          chargeOvershootDistance: 25.0,
          chargeFinalSweepRadius: 125.0,
          projectiles: [
            zone(
              position: origin,
              angleArg: baseAngle,
              life: 8.0,
              visualScale: 3.0,
              radiusMultiplier: 3.2,
              tauntRadius: 260.0,
              tauntStrength: 2.4,
              decoyHp: maxHp * 0.55,
              tickEffect: AbilityEffectKind.zoneDamage,
              effectPower: damage * 0.40,
              effectRadius: 120.0,
              effectDuration: 8.0,
              deathExplosionCount: 4,
              deathExplosionDamage: damage * 0.55,
              deathExplosionRadius: 2.4,
            ),
          ],
        ),
      );

    case 'Mud':
    case 'Air':
      // PASSIVE — no active cast. Effect runs continuously in the
      // survival update loop. Returning empty here is a safety
      // fallback; isPassiveOnlyCosmicAbility should block the cast
      // before this branch is reached.
      return CosmicSpecialResult();

    case 'Poison':
      // The toxic aura is still passive (always-on), but Poison ALSO
      // gets a charge attack: dash into enemies, contact deals heavy
      // poison damage, the survival on-hit hook applies a long poison
      // DoT to each enemy the dash sweeps through.
      return finalize(
        CosmicSpecialResult(
          shieldHp: (maxHp * 0.42).round(),
          chargeTimer: 0.80,
          chargeDamage: damage * 1.9,
          chargeSpeedMultiplier: 0.90,
          chargeSweepRadius: 60.0,
          chargeOvershootDistance: 70.0,
          chargeFinalSweepRadius: 100.0,
          projectiles: const [],
        ),
      );

    case 'Dust':
      // Dust cyclone at impact — pulls nearby enemies inward and
      // disorients shooter-enemies so they fire at each other.
      return finalize(
        CosmicSpecialResult(
          shieldHp: (maxHp * 0.40).round(),
          chargeTimer: 0.75,
          chargeDamage: damage * 1.5,
          chargeSpeedMultiplier: 1.10,
          chargeSweepRadius: 56.0,
          chargeOvershootDistance: 70.0,
          chargeFinalSweepRadius: 90.0,
          projectiles: [
            zone(
              position: origin,
              angleArg: baseAngle,
              life: 3.6,
              visualScale: 2.1,
              radiusMultiplier: 2.2,
              tauntRadius: 150.0,
              tauntStrength: 1.4,
              tickEffect: AbilityEffectKind.pull,
              effectPower: damage * 0.28,
              effectRadius: 130.0,
              effectDuration: 3.6,
            ),
          ],
        ),
      );

    case 'Crystal':
      // Wind-up phase: 6 shards orbit the horn for ~1.2s (Phase 3
      // anchors them to the live companion). Then the wing dashes
      // with the shards still orbiting; on impact they shatter into
      // a shrapnel burst.
      final shardCount = scaledCount(6, min: 5, max: 8);
      return finalize(
        CosmicSpecialResult(
          windUpTime: 1.2,
          windUpElement: 'Crystal',
          shieldHp: (maxHp * 0.55).round(),
          chargeTimer: 0.9,
          chargeDamage: damage * 1.7,
          chargeSpeedMultiplier: 0.95,
          chargeSweepRadius: 62.0,
          chargeOvershootDistance: 60.0,
          chargeFinalSweepRadius: 90.0,
          projectiles: List.generate(shardCount, (i) {
            final a = i * (pi * 2 / shardCount);
            final shard = zone(
              position: Offset(
                origin.dx + cos(a) * 48,
                origin.dy + sin(a) * 48,
              ),
              angleArg: a,
              life: 5.0,
              visualScale: 1.5,
              radiusMultiplier: 1.6,
              interceptRadius: 52.0,
              interceptCharges: 2,
              orbitCenter: origin,
              orbitAngle: a,
              orbitRadius: 48.0,
              orbitSpeed: 1.25,
              deathExplosionCount: 4,
              deathExplosionDamage: damage * 0.30,
              deathExplosionRadius: 1.6,
            );
            // Re-anchor the orbit to the live horn each frame so the
            // shards travel WITH it during the dash and stay orbiting
            // afterward — not pinned to the original cast point.
            return _copyProjectile(shard, followSourceCompanion: true);
          }),
        ),
      );

    case 'Plant':
      // Per-enemy root on charge contact: each enemy the dash sweeps
      // through gets a personal rooted status (survival-side hook
      // adds a vine visual + immobilizes them). No AoE zone — root
      // only triggers on direct hits.
      return finalize(
        CosmicSpecialResult(
          shieldHp: (maxHp * 0.62).round(),
          chargeTimer: 0.95,
          chargeDamage: damage * 2.0,
          chargeSpeedMultiplier: 0.88,
          chargeSweepRadius: 70.0,
          chargeOvershootDistance: 35.0,
          chargeFinalSweepRadius: 105.0,
          projectiles: const [],
        ),
      );

    case 'Spirit':
      // Wind-up: phantoms swarm the horn (visual). On dash, the
      // phantoms RELEASE — six big ghostly wisps drift outward in a
      // ring, taunting enemies for the duration. They look like the
      // wind-up particles but bigger and persistent. Also takes 60%
      // reduced damage during the wind-up + charge (Phase 3).
      // Phantom count scales with caster stats — high-stat Spirit
      // horns release a denser swarm.
      final spiritPhantomCount = scaledCount(6, min: 4, max: 9);
      return finalize(
        CosmicSpecialResult(
          windUpTime: 2.0,
          windUpElement: 'Spirit',
          shieldHp: (maxHp * 0.40).round(),
          chargeTimer: 0.7,
          chargeDamage: damage * 1.8,
          chargeSpeedMultiplier: 1.20,
          chargeSweepRadius: 50.0,
          chargeOvershootDistance: 85.0,
          chargeFinalSweepRadius: 85.0,
          projectiles: List.generate(spiritPhantomCount, (i) {
            // Spawn in a ring around the impact, each flying outward
            // in its own direction at a slow drift speed. They're
            // mobile decoys with strong taunt — enemies chase the
            // wisps instead of the horn.
            final a = i * (pi * 2 / spiritPhantomCount);
            final spawnR = 26.0;
            return Projectile(
              position: Offset(
                origin.dx + cos(a) * spawnR,
                origin.dy + sin(a) * spawnR,
              ),
              angle: a,
              element: element,
              damage: 0,
              life: 6.0,
              // Slow drift outward — flies around the impact area
              // taunting enemies as it travels.
              speedMultiplier: 0.32,
              piercing: true,
              radiusMultiplier: 2.0,
              visualScale: 2.0,
              visualStyle: ProjectileVisualStyle.hornImpact,
              tauntRadius: 180.0,
              tauntStrength: 2.4,
              decoy: true,
              decoyHp: maxHp * 0.18,
              abilityFamily: 'horn',
            );
          }),
        ),
      );

    case 'Dark':
      // Wind-up phase (5s): a void aura wraps the horn and sucks
      // nearby enemies inward (Phase 3 wires the per-frame pull).
      // Then a long fast dash carries the trapped enemies along to
      // the map edge (Phase 5 teleports the captured cluster to the
      // dash destination), where they take heavy impact damage.
      return finalize(
        CosmicSpecialResult(
          windUpTime: 5.0,
          windUpElement: 'Dark',
          shieldHp: (maxHp * 0.55).round(),
          // Quick dash phase — the wind-up is the long beat. The
          // dash is short and very fast, covering map-edge distance
          // via the high speed multiplier + long overshoot.
          chargeTimer: 0.55,
          chargeDamage: damage * 2.4,
          chargeSpeedMultiplier: 2.10,
          chargeSweepRadius: 60.0,
          chargeOvershootDistance: 380.0,
          chargeFinalSweepRadius: 140.0,
          projectiles: [
            zone(
              position: origin,
              angleArg: baseAngle,
              life: 2.0,
              visualScale: 2.6,
              radiusMultiplier: 2.4,
              tauntRadius: 200.0,
              tauntStrength: 1.6,
              tickEffect: AbilityEffectKind.blackHole,
              effectPower: damage * 0.55,
              effectRadius: 180.0,
              effectDuration: 2.0,
            ),
          ],
        ),
      );

    case 'Light':
      // Stops moving and channels a light barrier. NO ram — chargeTimer
      // is 0 so the barrier spawns immediately. The barrier reflects
      // enemy projectiles and bounces enemies; the horn's movement
      // lock and the ally-protection pulse are wired survival-side.
      // shipHeal is the cast-time blessing.
      // Per design: stops moving and channels a barrier for ~5s
      // base (scales with intelligence via finalize sustain scale).
      // Size 20% smaller than previous pass + intelligence-driven
      // size scaling layered on top via the finalize visual scaler.
      final lightBarrier = zone(
        position: origin,
        angleArg: baseAngle,
        life: 5.0,
        visualScale: 4.8,
        radiusMultiplier: 5.2,
        tauntRadius: 0.0,
        tauntStrength: 0.0,
        interceptRadius: 0.0,
        interceptCharges: 0,
        decoyHp: maxHp * 1.10,
      );
      return finalize(
        CosmicSpecialResult(
          shieldHp: (maxHp * 0.50).round(),
          chargeTimer: 0,
          chargeDamage: 0,
          chargeSpeedMultiplier: 0,
          chargeSweepRadius: 0,
          chargeOvershootDistance: 0,
          chargeFinalSweepRadius: 0,
          projectiles: [
            _copyProjectile(lightBarrier, reflectsProjectiles: true),
          ],
          shipHeal: max(1, (CosmicBalance.shipMaxHealth * 0.035).round()),
        ),
      );

    case 'Blood':
      // No taunt. Sacrifices % current HP for amplified impact
      // damage. Heals back on every kill in a short post-impact
      // window. Phase 3 wires the HP sacrifice and heal-on-kill;
      // here we set up the heavy impact + brief vampire blessing.
      return finalize(
        CosmicSpecialResult(
          shieldHp: (maxHp * 0.45).round(),
          chargeTimer: 0.85,
          chargeDamage: damage * 2.6,
          chargeSpeedMultiplier: 0.85,
          chargeSweepRadius: 70.0,
          chargeOvershootDistance: 50.0,
          chargeFinalSweepRadius: 100.0,
          selfHeal: 0,
          blessingTimer: 2.5,
          blessingHealPerTick: damage * 0.06,
          projectiles: const [],
        ),
      );

    default:
      return finalize(
        CosmicSpecialResult(
          shieldHp: (maxHp * 0.45).round(),
          chargeTimer: 0.70,
          chargeDamage: damage * 1.8,
          chargeSpeedMultiplier: 1.0,
          chargeSweepRadius: 58.0,
          chargeOvershootDistance: 80.0,
          chargeFinalSweepRadius: 80.0,
          projectiles: ring(
            8,
            1.8,
            life: 2.0,
            speed: 0.8,
            radius: 1.5,
            vs: 1.3,
          ),
        ),
      );
  }
}

// ─────────────────────────────────────────────────────────
// WING — Piercing Beam
// Design: Powerful beams that actually pierce and hurt
// ─────────────────────────────────────────────────────────
CosmicSpecialResult _wingSpecial(
  Offset origin,
  double baseAngle,
  String element,
  double damage,
  double casterBeauty,
  double casterIntelligence,
) {
  int scaledCount(int base, {int min = 2, int max = 12}) {
    final scale = _specialCountScaleFromBaseline(
      casterBeauty,
      casterIntelligence,
      beautyPerPoint: 0.05,
      intelligencePerPoint: 0.08,
      min: 0.78,
      max: 1.22,
    );
    return (base * scale).round().clamp(min, max);
  }

  Projectile scaleWingProjectile(Projectile p, {bool isPrimaryBeam = false}) {
    final impactScale = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.10,
      min: 0.84,
      max: 1.20,
    );
    final visualScaleMul = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.14,
      min: 0.82,
      max: 1.24,
    );
    final controlScale = _specialStatScaleFromBaseline(
      casterIntelligence,
      perPoint: 0.12,
      min: 0.82,
      max: 1.24,
    );
    final durationScale = _specialStatScaleFromBaseline(
      casterIntelligence,
      perPoint: 0.09,
      min: 0.86,
      max: 1.18,
    );
    return _copyProjectile(
      p,
      damage: p.damage * impactScale * (isPrimaryBeam ? 1.05 : 1.0),
      life: p.life * durationScale,
      speedMultiplier: p.stationary
          ? p.speedMultiplier
          : p.speedMultiplier * controlScale,
      radiusMultiplier: p.radiusMultiplier * visualScaleMul,
      homingStrength: p.homing
          ? p.homingStrength * controlScale
          : p.homingStrength,
      visualScale:
          p.visualScale * visualScaleMul * (isPrimaryBeam ? 1.08 : 1.0),
      trailInterval: p.trailInterval > 0
          ? (p.trailInterval / controlScale).clamp(0.05, 0.35)
          : p.trailInterval,
      trailDamage: p.trailDamage * impactScale,
      trailLife: p.trailLife > 0 ? p.trailLife * durationScale : p.trailLife,
      abilityFamily: 'wing',
      hitEffect: p.hitEffect == AbilityEffectKind.none
          ? _wingTickEffect(element)
          : p.hitEffect,
      tickEffect: p.tickEffect == AbilityEffectKind.none
          ? _wingTickEffect(element)
          : p.tickEffect,
      killEffect: p.killEffect,
      effectPower: p.effectPower > 0
          ? p.effectPower * impactScale
          : p.damage * impactScale * 0.22,
      effectRadius: p.effectRadius > 0 ? p.effectRadius : 82.0,
      effectDuration: p.effectDuration > 0
          ? p.effectDuration * durationScale
          : 1.7 * durationScale,
    );
  }

  final beamDmg = damage * _wingElementDamageMultiplier(element);
  final beamSpeed = _wingElementSpeed(element);
  final beamLife = _wingElementLife(element);
  final trail = _wingElementTrail(element);

  final projs = <Projectile>[
    // Primary beam — always large, always piercing
    Projectile(
      position: Offset(
        origin.dx + cos(baseAngle) * 20,
        origin.dy + sin(baseAngle) * 20,
      ),
      angle: baseAngle,
      element: element,
      damage: beamDmg,
      life: beamLife,
      speedMultiplier: beamSpeed,
      piercing: true,
      radiusMultiplier: _wingElementRadius(element),
      visualScale: 2.5,
      trailInterval: trail.$1,
      trailDamage: trail.$2,
      trailLife: trail.$3,
    ),
  ];

  // Element secondaries — all significantly buffed
  switch (element) {
    case 'Lightning':
      // Chain web: main beam + 6 branching piercing bolts
      final localCount = scaledCount(6, min: 4, max: 8);
      for (var i = 0; i < localCount; i++) {
        final a = baseAngle + (i - (localCount - 1) / 2) * 0.28;
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 16, origin.dy + sin(a) * 16),
            angle: a,
            element: element,
            damage: damage * 1.35,
            life: 1.0,
            speedMultiplier: 2.5,
            piercing: true,
            visualScale: 1.1,
          ),
        );
      }
      break;

    case 'Crystal':
      // Prism refraction: 7 homing shards from beam tip
      final localCount = scaledCount(7, min: 5, max: 9);
      for (var i = 0; i < localCount; i++) {
        final a = baseAngle + (i - (localCount - 1) / 2) * 0.22;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(baseAngle) * 90,
              origin.dy + sin(baseAngle) * 90,
            ),
            angle: a,
            element: element,
            damage: damage * 1.32,
            life: 2.0,
            speedMultiplier: 1.3,
            homing: true,
            homingStrength: 3.9,
            visualScale: 1.08,
            radiusMultiplier: 1.15,
            interceptRadius: 22.0,
            interceptCharges: 1,
          ),
        );
      }
      break;

    case 'Fire':
      // Sweeping inferno: 5 fire projectiles spreading sideways
      final localCount = scaledCount(5, min: 4, max: 7);
      for (var i = 0; i < localCount; i++) {
        final a = baseAngle + (i - (localCount - 1) / 2) * 0.12;
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 14, origin.dy + sin(a) * 14),
            angle: a,
            element: element,
            damage: damage * 1.15,
            life: 2.1,
            speedMultiplier: 0.8,
            visualScale: 1.5,
          ),
        );
      }
      break;

    case 'Ice':
      // Cryo wake: the beam leaves behind 3 freezing anchor shards that throw back-fanning splinters.
      final wakeTip = Offset(
        origin.dx + cos(baseAngle) * 72,
        origin.dy + sin(baseAngle) * 72,
      );
      for (var i = 0; i < scaledCount(3, min: 2, max: 4); i++) {
        final dist = 18.0 + i * 20.0;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(baseAngle) * dist,
              origin.dy + sin(baseAngle) * dist,
            ),
            angle: baseAngle,
            element: element,
            damage: damage * 1.35,
            life: 3.1,
            speedMultiplier: 0.3,
            radiusMultiplier: 2.1,
            piercing: true,
            visualScale: 1.7,
          ),
        );
      }
      final shardCount = scaledCount(6, min: 4, max: 8);
      for (var i = 0; i < shardCount; i++) {
        final a = baseAngle + pi + (i - (shardCount - 1) / 2) * 0.22;
        projs.add(
          Projectile(
            position: wakeTip,
            angle: a,
            element: element,
            damage: damage * 0.8,
            life: 2.2,
            speedMultiplier: 0.95,
            homing: true,
            homingStrength: 2.8,
            visualScale: 0.95,
          ),
        );
      }
      break;

    case 'Dark':
      // Void rake: rupture lances ride the beam lane, then peel into
      // execution seekers instead of stalling as void zones.
      final lanceCount = scaledCount(5, min: 4, max: 7);
      for (var i = 0; i < lanceCount; i++) {
        final dist = 18.0 + i * 22.0;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(baseAngle) * dist,
              origin.dy + sin(baseAngle) * dist,
            ),
            angle: baseAngle,
            element: element,
            damage: damage * 1.35,
            life: 2.0,
            speedMultiplier: 1.25,
            radiusMultiplier: 1.8,
            visualScale: 1.6,
            piercing: true,
          ),
        );
      }
      final seekerCount = scaledCount(4, min: 3, max: 6);
      final tip = Offset(
        origin.dx + cos(baseAngle) * 92,
        origin.dy + sin(baseAngle) * 92,
      );
      for (var i = 0; i < seekerCount; i++) {
        final a = baseAngle + (i - (seekerCount - 1) / 2) * 0.20;
        projs.add(
          Projectile(
            position: tip,
            angle: a,
            element: element,
            damage: damage * 1.1,
            life: 2.8,
            speedMultiplier: 1.0,
            homing: true,
            homingStrength: 3.8,
            visualScale: 1.1,
            piercing: true,
          ),
        );
      }
      break;

    case 'Blood':
      // Crimson lance: main beam + 3 strong homing blood bolts
      final localCount = scaledCount(3, min: 2, max: 4);
      for (var i = 0; i < localCount; i++) {
        final a = baseAngle + (i - (localCount - 1) / 2) * 0.28;
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 16, origin.dy + sin(a) * 16),
            angle: a,
            element: element,
            damage: damage * 1.55,
            life: 2.8,
            speedMultiplier: 0.8,
            homing: true,
            homingStrength: 3.5,
            visualScale: 1.6,
          ),
        );
      }
      break;

    case 'Water':
      // Undertow ribbon: two fluid ribbons peel off the beam and hook back inward.
      final ribbonTip = Offset(
        origin.dx + cos(baseAngle) * 84,
        origin.dy + sin(baseAngle) * 84,
      );
      for (var i = 0; i < scaledCount(8, min: 6, max: 10); i++) {
        final side = i.isEven ? -1.0 : 1.0;
        final tier = (i ~/ 2) - 1.5;
        final a = baseAngle + side * (0.20 + tier * 0.08);
        projs.add(
          Projectile(
            position: Offset(
              ribbonTip.dx + cos(baseAngle + pi / 2) * side * 22,
              ribbonTip.dy + sin(baseAngle + pi / 2) * side * 22,
            ),
            angle: a + pi,
            element: element,
            damage: damage * 0.9,
            life: 2.1,
            speedMultiplier: 1.0,
            homing: true,
            homingStrength: 2.2,
            visualScale: 1.15,
          ),
        );
      }
      break;

    case 'Lava':
      // Eruption trench: 4 massive slow piercing magma chunks
      for (var i = 0; i < scaledCount(4, min: 3, max: 5); i++) {
        final dist = 18.0 + i * 32.0;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(baseAngle) * dist,
              origin.dy + sin(baseAngle) * dist,
            ),
            angle: baseAngle + (i - 1.5) * 0.18,
            element: element,
            damage: damage * 2.2,
            life: 2.6,
            speedMultiplier: 0.25,
            radiusMultiplier: 2.6,
            piercing: true,
            visualScale: 2.2,
          ),
        );
      }
      break;

    case 'Steam':
      // Boiler shear: steam shells pulse down the beam lane and then roll
      // outward as drifting cutters instead of parking as vent pockets.
      final shellCount = scaledCount(6, min: 4, max: 8);
      for (var i = 0; i < shellCount; i++) {
        final dist = 22.0 + i * 22.0;
        final offset = i.isEven ? 18.0 : -18.0;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx +
                  cos(baseAngle) * dist +
                  cos(baseAngle + pi / 2) * offset,
              origin.dy +
                  sin(baseAngle) * dist +
                  sin(baseAngle + pi / 2) * offset,
            ),
            angle: baseAngle,
            element: element,
            damage: damage * 1.08,
            life: 2.7,
            speedMultiplier: 0.8,
            radiusMultiplier: 1.9,
            piercing: true,
            visualScale: 1.9,
          ),
        );
      }
      final cutterCount = scaledCount(4, min: 3, max: 6);
      final tip = Offset(
        origin.dx + cos(baseAngle) * 86,
        origin.dy + sin(baseAngle) * 86,
      );
      for (var i = 0; i < cutterCount; i++) {
        final side = i.isEven ? -1.0 : 1.0;
        final a = baseAngle + side * (0.18 + (i ~/ 2) * 0.08);
        projs.add(
          Projectile(
            position: Offset(
              tip.dx + cos(baseAngle + pi / 2) * side * 18,
              tip.dy + sin(baseAngle + pi / 2) * side * 18,
            ),
            angle: a,
            element: element,
            damage: damage * 0.72,
            life: 2.4,
            speedMultiplier: 1.0,
            homing: true,
            homingStrength: 2.6,
            visualScale: 1.0,
          ),
        );
      }
      break;

    case 'Earth':
      // Boulder beam: 2 enormous slow rocks + wide radius
      final localCount = scaledCount(2, min: 2, max: 3);
      for (var i = 0; i < localCount; i++) {
        final a = baseAngle + (i == 0 ? -0.22 : 0.22);
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 16, origin.dy + sin(a) * 16),
            angle: a,
            element: element,
            damage: damage * 2.8,
            life: 2.3,
            speedMultiplier: 0.55,
            radiusMultiplier: 3.0,
            visualScale: 2.5,
            piercing: true,
          ),
        );
      }
      final fissureCount = scaledCount(2, min: 2, max: 3);
      for (var i = 0; i < fissureCount; i++) {
        final side = i == 0 ? -1.0 : 1.0;
        final a = baseAngle + side * 0.14;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx +
                  cos(baseAngle) * 76 +
                  cos(baseAngle + pi / 2) * side * 20,
              origin.dy +
                  sin(baseAngle) * 76 +
                  sin(baseAngle + pi / 2) * side * 20,
            ),
            angle: a,
            element: element,
            damage: damage * 1.05,
            life: 3.2,
            speedMultiplier: 0.52,
            radiusMultiplier: 2.35,
            visualScale: 2.0,
            piercing: true,
            snareRadius: 88.0,
            snareMoveMultiplier: 0.62,
          ),
        );
      }
      break;

    case 'Mud':
      // Mire rake: heavy bog slugs ride the beam lane, then slough off
      // sticky chasers behind them instead of anchoring in place.
      final rakeTip = Offset(
        origin.dx + cos(baseAngle) * 78,
        origin.dy + sin(baseAngle) * 78,
      );
      for (var i = 0; i < scaledCount(3, min: 2, max: 4); i++) {
        final offset = (i - 1) * 18.0;
        projs.add(
          Projectile(
            position: Offset(
              rakeTip.dx + cos(baseAngle + pi / 2) * offset,
              rakeTip.dy + sin(baseAngle + pi / 2) * offset,
            ),
            angle: baseAngle,
            element: element,
            damage: damage * 1.35,
            life: 2.8,
            speedMultiplier: 0.55,
            radiusMultiplier: 2.2,
            piercing: true,
            visualScale: 2.0,
          ),
        );
      }
      final globCount = scaledCount(4, min: 3, max: 5);
      for (var i = 0; i < globCount; i++) {
        final a = baseAngle + pi + (i - (globCount - 1) / 2) * 0.18;
        projs.add(
          Projectile(
            position: rakeTip,
            angle: a,
            element: element,
            damage: damage * 0.9,
            life: 3.0,
            speedMultiplier: 0.55,
            radiusMultiplier: 1.75,
            homing: true,
            homingStrength: 2.4,
            visualScale: 1.05,
          ),
        );
      }
      break;

    case 'Dust':
      // Sandblast: 9 fast scattered shards
      final rng = Random();
      for (var i = 0; i < scaledCount(9, min: 6, max: 11); i++) {
        final a = baseAngle + (rng.nextDouble() - 0.5) * 1.1;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(baseAngle) * 45,
              origin.dy + sin(baseAngle) * 45,
            ),
            angle: a,
            element: element,
            damage: damage * 0.8,
            life: 0.9,
            speedMultiplier: 2.0,
            visualScale: 0.7,
          ),
        );
      }
      break;

    case 'Air':
      // Tornado drill: 4 fast spiraling bolts
      final localCount = scaledCount(4, min: 3, max: 6);
      for (var i = 0; i < localCount; i++) {
        final a = baseAngle + (i * pi * 2 / localCount);
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 22, origin.dy + sin(a) * 22),
            angle: baseAngle,
            element: element,
            damage: damage * 0.95,
            life: 1.5,
            speedMultiplier: 1.8,
            visualScale: 1.1,
          ),
        );
      }
      break;

    case 'Plant':
      // Vine beam: 5 homing vine tendrils
      final localCount = scaledCount(5, min: 4, max: 7);
      for (var i = 0; i < localCount; i++) {
        final a = baseAngle + (i - (localCount - 1) / 2) * 0.38;
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 16, origin.dy + sin(a) * 16),
            angle: a,
            element: element,
            damage: damage * 1.15,
            life: 2.6,
            speedMultiplier: 0.7,
            homing: true,
            homingStrength: 2.8,
            visualScale: 1.2,
          ),
        );
      }
      break;

    case 'Poison':
      // Venom spine: toxic lances ride the beam line, then spit guided
      // feeders instead of pinning targets with stationary nodules.
      final spineTip = Offset(
        origin.dx + cos(baseAngle) * 76,
        origin.dy + sin(baseAngle) * 76,
      );
      for (var i = 0; i < scaledCount(3, min: 2, max: 4); i++) {
        final dist = 24.0 + i * 20.0;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(baseAngle) * dist,
              origin.dy + sin(baseAngle) * dist,
            ),
            angle: baseAngle,
            element: element,
            damage: damage * 1.25,
            life: 3.0,
            speedMultiplier: 0.7,
            radiusMultiplier: 2.0,
            piercing: true,
            visualScale: 2.0,
          ),
        );
      }
      final feederCount = scaledCount(5, min: 4, max: 7);
      for (var i = 0; i < feederCount; i++) {
        final a = baseAngle + (i - (feederCount - 1) / 2) * 0.26;
        projs.add(
          Projectile(
            position: spineTip,
            angle: a,
            element: element,
            damage: damage * 0.75,
            life: 3.0,
            speedMultiplier: 0.72,
            radiusMultiplier: 1.5,
            homing: true,
            homingStrength: 2.4,
            visualScale: 1.0,
          ),
        );
      }
      break;

    case 'Spirit':
      // Reaper beam: 3 strong homing piercing spirits
      final localCount = scaledCount(3, min: 2, max: 4);
      for (var i = 0; i < localCount; i++) {
        final a = baseAngle + (i - (localCount - 1) / 2) * 0.45;
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 16, origin.dy + sin(a) * 16),
            angle: a,
            element: element,
            damage: damage * 1.7,
            life: 3.6,
            speedMultiplier: 0.7,
            homing: true,
            homingStrength: 5.0,
            piercing: true,
            visualScale: 1.4,
          ),
        );
      }
      break;

    case 'Light':
      // Radiant burst: 6 light orbs scattering from tip
      final localCount = scaledCount(6, min: 4, max: 8);
      for (var i = 0; i < localCount; i++) {
        final a = i * (pi * 2 / localCount);
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(baseAngle) * 65,
              origin.dy + sin(baseAngle) * 65,
            ),
            angle: a,
            element: element,
            damage: damage * 0.9,
            life: 1.8,
            speedMultiplier: 1.2,
            homing: true,
            homingStrength: 2.5,
            visualScale: 0.9,
          ),
        );
      }
      break;

    default:
      break;
  }

  final scaledProjectiles = List.generate(projs.length, (i) {
    return scaleWingProjectile(projs[i], isPrimaryBeam: i == 0);
  });

  return CosmicSpecialResult(
    projectiles: scaledProjectiles,
    beams: _wingBeamEffects(
      element: element,
      damage: damage,
      casterBeauty: casterBeauty,
      casterIntelligence: casterIntelligence,
    ),
  );
}

AbilityEffectKind _wingTickEffect(String element) => switch (element) {
  'Air' => AbilityEffectKind.knockback,
  'Dust' => AbilityEffectKind.suppressShooting,
  'Lava' || 'Fire' => AbilityEffectKind.burn,
  'Poison' => AbilityEffectKind.poison,
  'Blood' => AbilityEffectKind.execute,
  'Light' => AbilityEffectKind.refraction,
  'Spirit' => AbilityEffectKind.buff,
  'Crystal' || 'Water' => AbilityEffectKind.leech,
  'Lightning' => AbilityEffectKind.chargeBlast,
  'Steam' => AbilityEffectKind.geyser,
  'Dark' => AbilityEffectKind.none,
  // Ice no longer hard-freezes per tick — the wing beam ramps a frost
  // buildup that snaps into a freeze once full (see _resolveBeamTick).
  'Ice' => AbilityEffectKind.slow,
  'Mud' => AbilityEffectKind.slow,
  'Plant' => AbilityEffectKind.flower,
  _ => AbilityEffectKind.none,
};

List<WingBeamEffect> _wingBeamEffects({
  required String element,
  required double damage,
  required double casterBeauty,
  required double casterIntelligence,
}) {
  final effectiveIntelligence = AlchemonStatSystem.legacyGameplayRating(
    casterIntelligence,
  );
  final powerScale = _specialStatScaleFromBaseline(
    casterBeauty,
    perPoint: 0.13,
    min: 0.82,
    max: 1.26,
  );
  final targetingScale = _specialStatScaleFromBaseline(
    casterIntelligence,
    perPoint: 0.12,
    min: 0.84,
    max: 1.24,
  );
  // Lightning: fixed 3s charge (per design — stat-invariant) + small
  // buffer so the post-charge blast tick lands before the beam expires.
  final duration = element == 'Lightning'
      ? 3.2
      : (1.8 + effectiveIntelligence * 0.10).clamp(1.6, 3.4);
  final tick = (0.22 / targetingScale).clamp(0.12, 0.28).toDouble();
  final beamDamage = damage * 0.46 * powerScale;
  // A single slightly wider beam reads better than 2–3 thrashing
  // refracted beams that block enemy/bullet visibility.
  final width = 9.5 * powerScale;
  final base = WingBeamEffect(
    element: element,
    targetPolicy: switch (element) {
      'Blood' => WingBeamTargetPolicy.lowestHealthEnemy,
      'Water' => WingBeamTargetPolicy.lowestHealthAllyOrShip,
      'Poison' || 'Fire' => WingBeamTargetPolicy.ring,
      'Spirit' => WingBeamTargetPolicy.shipTether,
      _ => WingBeamTargetPolicy.nearestEnemy,
    },
    duration: duration,
    tickInterval: tick,
    damagePerTick: beamDamage,
    healPerTick: switch (element) {
      'Water' || 'Crystal' => beamDamage * 0.70,
      'Light' => beamDamage * 0.35,
      _ => 0,
    },
    width: width,
    range: 430 + effectiveIntelligence * 18,
    radius: switch (element) {
      'Poison' || 'Fire' => 140 + effectiveIntelligence * 12,
      _ => 0,
    },
    refractionCount: element == 'Light' ? 1 : 0,
    // Per design: Lightning charges for 3s (stat-invariant), then
    // unleashes one big blast (handled in the survival update loop).
    chargeTime: element == 'Lightning' ? 3.0 : 0,
    executeThreshold: element == 'Blood' ? 0.18 : 0,
    tickEffect: _wingTickEffect(element),
    effectPower: beamDamage * 0.5,
    effectDuration: switch (element) {
      // Wing+Mud: permanent slow per design — long duration so the
      // slow effectively never expires for hit enemies.
      'Mud' => 60.0,
      'Ice' || 'Dust' => 2.8,
      'Poison' || 'Lava' || 'Fire' || 'Steam' => 2.0,
      _ => 1.2,
    },
    splitCount: switch (element) {
      'Light' => 1,
      'Steam' => 3,
      _ => 0,
    },
  );
  // Dark's "double up" identity is delivered by its passive (the wing
  // pulses its beam and basic attacks at twice the normal rate — see
  // the isDarkWing cooldown handling), so its beam itself stays normal.
  return [base];
}

double _wingElementDamageMultiplier(String e) => switch (e) {
  'Dark' => 4.2,
  'Earth' => 4.0,
  'Lava' => 4.0,
  'Crystal' => 3.5,
  'Blood' => 3.6,
  'Spirit' => 3.4,
  'Lightning' => 2.8,
  'Ice' => 3.0,
  'Fire' => 3.1,
  'Water' => 2.8,
  'Mud' => 3.0,
  'Steam' => 2.7,
  'Plant' => 2.7,
  'Poison' => 2.5,
  'Air' => 2.5,
  'Dust' => 2.2,
  'Light' => 2.9,
  _ => 3.5,
};

double _wingElementSpeed(String e) => switch (e) {
  'Lightning' => 2.8,
  'Dark' => 2.2,
  'Air' => 2.2,
  'Fire' => 2.0,
  'Dust' => 2.0,
  'Light' => 1.8,
  'Crystal' => 1.6,
  'Ice' => 1.4,
  'Spirit' => 1.3,
  'Water' => 1.4,
  'Blood' => 1.1,
  'Steam' => 1.1,
  'Plant' => 1.1,
  'Poison' => 0.9,
  'Mud' => 0.8,
  'Earth' => 0.9,
  'Lava' => 0.7,
  _ => 1.6,
};

double _wingElementLife(String e) => switch (e) {
  'Poison' => 3.5,
  'Blood' => 3.0,
  'Mud' => 3.2,
  'Plant' => 3.0,
  'Steam' => 3.0,
  'Spirit' => 3.0,
  'Water' => 2.5,
  'Lava' => 3.0,
  'Ice' => 2.8,
  'Earth' => 2.5,
  'Crystal' => 2.2,
  'Fire' => 2.2,
  'Dark' => 2.0,
  'Lightning' => 1.4,
  'Air' => 1.8,
  'Dust' => 1.5,
  'Light' => 2.5,
  _ => 2.5,
};

double _wingElementRadius(String e) => switch (e) {
  'Earth' => 3.0,
  'Lava' => 2.8,
  'Mud' => 2.5,
  'Steam' => 2.5,
  'Plant' => 2.2,
  'Ice' => 2.2,
  'Water' => 2.0,
  'Blood' => 2.0,
  'Crystal' => 1.6,
  'Fire' => 1.8,
  'Dark' => 1.6,
  'Spirit' => 1.8,
  'Lightning' => 1.2,
  'Air' => 1.2,
  'Dust' => 1.1,
  'Poison' => 2.0,
  'Light' => 1.5,
  _ => 1.8,
};

(double, double, double) _wingElementTrail(String element) => switch (element) {
  'Poison' => (0.16, 4.5, 4.0),
  'Lava' => (0.22, 5.5, 3.0),
  'Fire' => (0.18, 4.0, 2.0),
  'Mud' => (0.22, 3.0, 4.5),
  'Steam' => (0.24, 2.8, 3.0),
  'Plant' => (0.24, 3.5, 4.0),
  _ => (0, 0, 0),
};

// ─────────────────────────────────────────────────────────
// LET — Meteor Strike
// Design: Impactful meteors, big AoE, element flavours matter
// ─────────────────────────────────────────────────────────
CosmicSpecialResult _letSpecial(
  Offset origin,
  double baseAngle,
  String element,
  double damage,
  Offset? targetPos,
  double casterBeauty,
  double casterIntelligence,
) {
  final target =
      targetPos ??
      Offset(
        origin.dx + cos(baseAngle) * 150,
        origin.dy + sin(baseAngle) * 150,
      );
  final toTarget = target - origin;
  final angle = atan2(toTarget.dy, toTarget.dx);

  final sustainScale = _specialStatScaleFromBaseline(
    casterBeauty,
    perPoint: 0.10,
    min: 0.82,
    max: 1.20,
  );

  // Earth = "moon drop": same meteor visual, but heavier and slower so the
  // landing hits like a hammer. Every other element uses the standard core.
  final isEarth = element == 'Earth';
  final meteor = Projectile(
    position: Offset(origin.dx + cos(angle) * 22, origin.dy + sin(angle) * 22),
    angle: angle,
    element: element,
    damage: damage * (isEarth ? 12.0 : 6.0),
    life: isEarth ? 2.0 : 1.8,
    speedMultiplier: isEarth ? 0.38 : 0.55,
    radiusMultiplier: isEarth ? 10.0 : 7.0,
    visualScale: isEarth ? 8.0 : 6.0,
    visualStyle: ProjectileVisualStyle.meteor,
  );

  // Cast-time heal / blessing for Water, Blood, Light — applied to the
  // caster (or ship) when the special fires, independent of impact.
  var selfHeal = 0;
  var shipHeal = 0;
  var blessingTimer = 0.0;
  var blessingHealPerTick = 0.0;
  switch (element) {
    case 'Water':
      shipHeal = (CosmicBalance.shipMaxHealth * 0.025 * sustainScale).round();
      break;
    case 'Blood':
      selfHeal = (damage * 2.2 * sustainScale).round();
      blessingTimer = 2.2;
      blessingHealPerTick = damage * 0.045 * sustainScale;
      break;
    case 'Light':
      shipHeal = (CosmicBalance.shipMaxHealth * 0.035 * sustainScale).round();
      blessingTimer = 2.8;
      blessingHealPerTick = damage * 0.08 * sustainScale;
      break;
  }

  var scaledMeteor = _scaleLetProjectile(
    meteor,
    beauty: casterBeauty,
    intelligence: casterIntelligence,
    isMeteorCore: true,
  );

  // Per-element meteor-core modifiers:
  //  - Crystal trades damage for a halved cooldown (see _specialCooldown).
  //  - Spirit carries the one-shot proc chance, scaled by intelligence so
  //    booster-stacked builds can actually reach the 0.50 cap instead of
  //    capping out at ~0.245 from the 5.0 genetic ceiling alone.
  final crystalDamageMul = element == 'Crystal' ? 0.58 : 1.0;
  final spiritChance = element == 'Spirit'
      ? (0.27 +
                (casterIntelligence.clamp(
                          _abilityStatFloor,
                          _abilityStatCeiling,
                        ) -
                        3.0) *
                    0.05)
            .clamp(0.22, 0.50)
            .toDouble()
      : 1.0;
  scaledMeteor = _copyProjectile(
    scaledMeteor,
    damage: scaledMeteor.damage * crystalDamageMul,
    letCasterIntelligence: casterIntelligence,
    effectChance: spiritChance,
  );

  return CosmicSpecialResult(
    projectiles: [scaledMeteor],
    selfHeal: selfHeal,
    shipHeal: shipHeal,
    blessingTimer: blessingTimer,
    blessingHealPerTick: blessingHealPerTick,
  );
}

// ─────────────────────────────────────────────────────────
// PIP — Ricochet Salvo
// Design: Fast homing chains, bouncy, fun to watch
// ─────────────────────────────────────────────────────────
const double kPipSpecialMaxProjectileLife = 2.65;
const double kPipRicochetPostHitLife = 0.42;
const int kPipMaxPierceHits = 2;

CosmicSpecialResult _pipSpecial(
  Offset origin,
  double baseAngle,
  String element,
  double damage,
  double casterBeauty,
  double casterIntelligence,
) {
  Projectile dart({
    required Offset position,
    required double angle,
    required double damageMultiplier,
    required double life,
    required double speed,
    required double homingStrength,
    double visualScale = 0.9,
    int bounceCount = 0,
    bool piercing = false,
    bool homing = true,
    double radiusMultiplier = 1.0,
    double trailInterval = 0,
    double trailDamageMultiplier = 0,
    double trailLife = 0,
    double snareRadius = 0,
    double snareMoveMultiplier = 1,
    double interceptRadius = 0,
    int interceptCharges = 0,
  }) {
    return Projectile(
      position: position,
      angle: angle,
      element: element,
      damage: damage * damageMultiplier,
      life: life,
      speedMultiplier: speed,
      homing: homing,
      homingStrength: homingStrength,
      piercing: piercing,
      bounceCount: bounceCount,
      radiusMultiplier: radiusMultiplier,
      visualScale: visualScale,
      trailInterval: trailInterval,
      trailDamage: damage * trailDamageMultiplier,
      trailLife: trailLife,
      snareRadius: snareRadius,
      snareMoveMultiplier: snareMoveMultiplier,
      interceptRadius: interceptRadius,
      interceptCharges: interceptCharges,
      visualStyle: ProjectileVisualStyle.dart,
    );
  }

  int scaledCount(int base, {int min = 3, int max = 18}) {
    final scale = _specialCountScaleFromBaseline(
      casterBeauty,
      casterIntelligence,
      beautyPerPoint: 0.06,
      intelligencePerPoint: 0.10,
      min: 0.76,
      max: 1.24,
    );
    return (base * scale).round().clamp(min, max);
  }

  int scaledBounce(int base, {int max = 6}) {
    final scaled =
        (base *
                _specialStatScaleFromBaseline(
                  casterIntelligence,
                  perPoint: 0.14,
                  min: 0.74,
                  max: 1.26,
                ))
            .round();
    return scaled.clamp(0, max);
  }

  Projectile scalePipProjectile(Projectile p) {
    final impactScale = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.09,
      min: 0.82,
      max: 1.18,
    );
    final visualScaleMul = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.12,
      min: 0.82,
      max: 1.22,
    );
    final guidanceScale = _specialStatScaleFromBaseline(
      casterIntelligence,
      perPoint: 0.13,
      min: 0.80,
      max: 1.24,
    );
    final durationScale = _specialStatScaleFromBaseline(
      casterIntelligence,
      perPoint: 0.09,
      min: 0.84,
      max: 1.18,
    );
    return _copyProjectile(
      p,
      damage: p.damage * impactScale * 0.86,
      life: min(p.life * durationScale, kPipSpecialMaxProjectileLife),
      speedMultiplier: p.speedMultiplier * guidanceScale,
      radiusMultiplier: p.radiusMultiplier * visualScaleMul,
      homingStrength: p.homingStrength * guidanceScale,
      visualScale: p.visualScale * visualScaleMul,
      bounceCount: scaledBounce(p.bounceCount),
      abilityFamily: 'pip',
      hitEffect: p.hitEffect == AbilityEffectKind.none
          ? _pipHitEffect(p.element ?? '')
          : p.hitEffect,
      killEffect: p.killEffect == AbilityEffectKind.none
          ? _pipKillEffect(p.element ?? '')
          : p.killEffect,
      effectPower: p.effectPower > 0
          ? p.effectPower * impactScale
          : p.damage * impactScale * 0.24,
      effectRadius: p.effectRadius > 0
          ? p.effectRadius * visualScaleMul
          : 72.0 * visualScaleMul,
      effectDuration: p.effectDuration > 0
          ? p.effectDuration * durationScale
          : 1.8 * durationScale,
      effectCount: p.effectCount > 0
          ? p.effectCount
          : max(1, scaledBounce(p.bounceCount)),
    );
  }

  final count = scaledCount(_pipElementCount(element));
  final bounces = scaledBounce(_pipElementBounce(element));
  List<Projectile> genericVolley() => List.generate(count, (i) {
    final offset = (i - (count - 1) / 2) * 0.20;
    final a = baseAngle + offset;
    return scalePipProjectile(
      dart(
        position: Offset(
          origin.dx + cos(a) * (12 + i * 4),
          origin.dy + sin(a) * (12 + i * 4),
        ),
        angle: a,
        damageMultiplier: _pipElementDamageMultiplier(element),
        life: _pipElementLife(element),
        speed: _pipElementSpeed(element),
        homingStrength: _pipElementHoming(element),
        piercing: element == 'Lightning' || element == 'Crystal',
        bounceCount: bounces,
      ),
    );
  });

  switch (element) {
    case 'Fire':
      final center = Offset(
        origin.dx + cos(baseAngle) * 30,
        origin.dy + sin(baseAngle) * 30,
      );
      final localCount = scaledCount(3, min: 2, max: 5);
      return CosmicSpecialResult(
        basicHasteTimer: 1.2,
        basicHasteMultiplier: 0.88,
        projectiles: List.generate(localCount, (i) {
          final t = i - (localCount - 1) / 2;
          final a = baseAngle + t * 0.13;
          return scalePipProjectile(
            dart(
              position: Offset(
                center.dx + cos(a + pi / 2) * t * 5,
                center.dy + sin(a + pi / 2) * t * 5,
              ),
              angle: a,
              damageMultiplier: 1.45,
              life: 1.65,
              speed: 2.15,
              // Lower homing — these are ricochets, not guided missiles.
              homingStrength: 2.0,
              visualScale: 1.20,
              bounceCount: 1,
            ),
          );
        }),
      );
    case 'Lightning':
      // Lightning per design = "double the ricochet" — keep dart count
      // higher than other elements but not screen-filling.
      final localCount = scaledCount(6, min: 5, max: 8);
      return CosmicSpecialResult(
        projectiles: List.generate(localCount, (i) {
          final t = i - (localCount - 1) / 2;
          final a = baseAngle + t * 0.10;
          return scalePipProjectile(
            dart(
              position: Offset(
                origin.dx + cos(baseAngle) * (18 + i * 3),
                origin.dy + sin(baseAngle) * (18 + i * 3),
              ),
              angle: a,
              damageMultiplier: 1.22,
              life: 1.35,
              speed: 2.65,
              homingStrength: 1.8,
              visualScale: 1.05,
              radiusMultiplier: 0.9,
              piercing: true,
              bounceCount: 5,
            ),
          );
        }),
      );
    case 'Ice':
      final center = Offset(
        origin.dx + cos(baseAngle) * 28,
        origin.dy + sin(baseAngle) * 28,
      );
      final localCount = scaledCount(3, min: 2, max: 4);
      return CosmicSpecialResult(
        projectiles: List.generate(localCount, (i) {
          final t = i - (localCount - 1) / 2;
          final a = baseAngle + t * 0.14;
          return scalePipProjectile(
            dart(
              position: Offset(
                center.dx + cos(a + pi / 2) * t * 9,
                center.dy + sin(a + pi / 2) * t * 9,
              ),
              angle: a,
              damageMultiplier: 1.85,
              life: 2.9,
              speed: 1.16,
              homingStrength: 2.2,
              visualScale: 1.25,
              radiusMultiplier: 1.15,
              bounceCount: 2,
              snareRadius: 64.0,
              snareMoveMultiplier: 0.66,
            ),
          );
        }),
      );
    case 'Crystal':
      final center = Offset(
        origin.dx + cos(baseAngle) * 32,
        origin.dy + sin(baseAngle) * 32,
      );
      final localCount = scaledCount(3, min: 3, max: 5);
      return CosmicSpecialResult(
        projectiles: List.generate(localCount, (i) {
          final a = baseAngle + (i - (localCount - 1) / 2) * 0.22;
          return scalePipProjectile(
            dart(
              position: Offset(
                center.dx + cos(a) * 10,
                center.dy + sin(a) * 10,
              ),
              angle: a,
              damageMultiplier: 1.75,
              life: 2.6,
              speed: 1.55,
              homingStrength: 2.4,
              visualScale: 1.22,
              piercing: true,
              bounceCount: 2,
            ),
          );
        }),
      );
    case 'Lava':
      final localCount = scaledCount(2, min: 2, max: 3);
      return CosmicSpecialResult(
        projectiles: List.generate(localCount, (i) {
          final t = i - (localCount - 1) / 2;
          final a = baseAngle + t * 0.26;
          return scalePipProjectile(
            dart(
              position: Offset(
                origin.dx + cos(baseAngle) * 26 + cos(a + pi / 2) * t * 11,
                origin.dy + sin(baseAngle) * 26 + sin(a + pi / 2) * t * 11,
              ),
              angle: a,
              // Fewer Lava darts → each one hits harder for the same
              // overall payload, matching Lava's "heavy slow" identity.
              damageMultiplier: 3.25,
              life: 2.75,
              speed: 0.92,
              homingStrength: 2.0,
              visualScale: 1.65,
              radiusMultiplier: 1.75,
              piercing: true,
            ),
          );
        }),
      );
    case 'Mud':
      final center = Offset(
        origin.dx + cos(baseAngle) * 26,
        origin.dy + sin(baseAngle) * 26,
      );
      final localCount = scaledCount(3, min: 2, max: 4);
      return CosmicSpecialResult(
        projectiles: List.generate(localCount, (i) {
          final t = i - (localCount - 1) / 2;
          final a = baseAngle + t * 0.18;
          return scalePipProjectile(
            dart(
              position: Offset(
                center.dx + cos(a + pi / 2) * t * 8,
                center.dy + sin(a + pi / 2) * t * 8,
              ),
              angle: a,
              damageMultiplier: 1.85,
              life: 3.0,
              speed: 0.98,
              homingStrength: 2.2,
              visualScale: 1.28,
              radiusMultiplier: 1.35,
              bounceCount: 1,
              snareRadius: 72.0,
              snareMoveMultiplier: 0.70,
            ),
          );
        }),
      );
    case 'Plant':
      final center = Offset(
        origin.dx + cos(baseAngle) * 30,
        origin.dy + sin(baseAngle) * 30,
      );
      final localCount = scaledCount(3, min: 2, max: 5);
      return CosmicSpecialResult(
        projectiles: List.generate(localCount, (i) {
          final t = i - (localCount - 1) / 2;
          final a = baseAngle + t * 0.16;
          return scalePipProjectile(
            dart(
              position: Offset(
                center.dx + cos(a + pi / 2) * t * 7,
                center.dy + sin(a + pi / 2) * t * 7,
              ),
              angle: a,
              damageMultiplier: 1.85,
              life: 3.25,
              speed: 1.22,
              homingStrength: 2.4,
              visualScale: 1.22,
              piercing: true,
              bounceCount: 1,
              snareRadius: 58.0,
              snareMoveMultiplier: 0.76,
            ),
          );
        }),
      );
    case 'Spirit':
      final localCount = scaledCount(3, min: 2, max: 4);
      return CosmicSpecialResult(
        projectiles: List.generate(localCount, (i) {
          final a = baseAngle + (i - (localCount - 1) / 2) * 0.22;
          return scalePipProjectile(
            dart(
              position: Offset(
                origin.dx + cos(baseAngle) * 24 + cos(a + pi / 2) * i * 5,
                origin.dy + sin(baseAngle) * 24 + sin(a + pi / 2) * i * 5,
              ),
              angle: a,
              damageMultiplier: 2.60,
              life: 3.7,
              speed: 1.18,
              // Spirit darts are still the family's "tracker" identity,
              // but not 6.0 homing-missile guidance.
              homingStrength: 3.2,
              visualScale: 1.30,
              piercing: true,
              bounceCount: 2,
            ),
          );
        }),
      );
    case 'Dust':
      final center = Offset(
        origin.dx + cos(baseAngle) * 26,
        origin.dy + sin(baseAngle) * 26,
      );
      // Dust was the worst offender at 12 baseline (8–16). Trim hard:
      // dust is a swarm of *small* darts, not a screen-fill.
      final localCount = scaledCount(5, min: 4, max: 7);
      return CosmicSpecialResult(
        projectiles: List.generate(localCount, (i) {
          final side = i.isEven ? -1.0 : 1.0;
          final tier = (i ~/ 2) - ((localCount / 4).ceil() - 1.0);
          final a = baseAngle + side * (0.10 + tier.abs() * 0.08);
          return scalePipProjectile(
            dart(
              position: Offset(
                center.dx +
                    cos(baseAngle + pi / 2) * side * (10 + tier.abs() * 5),
                center.dy +
                    sin(baseAngle + pi / 2) * side * (10 + tier.abs() * 5),
              ),
              angle: a,
              damageMultiplier: 1.35,
              life: 1.9,
              speed: 1.9,
              homingStrength: 1.8,
              visualScale: 1.00,
              bounceCount: 2,
            ),
          );
        }),
      );
    case 'Air':
      final center = Offset(
        origin.dx + cos(baseAngle) * 30,
        origin.dy + sin(baseAngle) * 30,
      );
      final localCount = scaledCount(4, min: 3, max: 6);
      return CosmicSpecialResult(
        projectiles: List.generate(localCount, (i) {
          final a = i * (pi * 2 / localCount);
          return scalePipProjectile(
            dart(
              position: Offset(
                center.dx + cos(a) * 16,
                center.dy + sin(a) * 16,
              ),
              angle: a + pi / 2,
              damageMultiplier: 1.60,
              life: 1.9,
              speed: 2.05,
              homing: false,
              homingStrength: 1.0,
              visualScale: 1.18,
              bounceCount: 2,
            ),
          );
        }),
      );
    case 'Dark':
      return CosmicSpecialResult();
    case 'Blood':
      final center = Offset(
        origin.dx + cos(baseAngle) * 24,
        origin.dy + sin(baseAngle) * 24,
      );
      final localCount = scaledCount(3, min: 2, max: 4);
      return CosmicSpecialResult(
        projectiles: List.generate(localCount, (i) {
          final offset = i - (localCount - 1) / 2;
          final a = baseAngle + offset * 0.16;
          return scalePipProjectile(
            dart(
              position: Offset(
                center.dx + cos(a + pi / 2) * offset * 10,
                center.dy + sin(a + pi / 2) * offset * 10,
              ),
              angle: a,
              damageMultiplier: 3.85,
              life: 3.2,
              speed: 1.0,
              homingStrength: 3.0,
              visualScale: 1.32,
              piercing: true,
            ),
          );
        }),
      );
    case 'Water':
      final center = Offset(
        origin.dx + cos(baseAngle) * 34,
        origin.dy + sin(baseAngle) * 34,
      );
      final localCount = scaledCount(3, min: 2, max: 5);
      return CosmicSpecialResult(
        projectiles: List.generate(localCount, (i) {
          final side = i.isEven ? -1.0 : 1.0;
          final tier = (i ~/ 2) - ((localCount / 4).ceil() - 1.0);
          final lane = baseAngle + pi / 2;
          final a = baseAngle + side * (0.18 + tier * 0.08);
          return scalePipProjectile(
            dart(
              position: Offset(
                center.dx + cos(lane) * side * 20 + cos(baseAngle) * tier * 8,
                center.dy + sin(lane) * side * 20 + sin(baseAngle) * tier * 8,
              ),
              angle: a + pi,
              damageMultiplier: 1.80,
              life: 2.6,
              speed: 1.25,
              homingStrength: 2.4,
              visualScale: 1.22,
              bounceCount: 2,
            ),
          );
        }),
      );
    case 'Steam':
      final localCount = scaledCount(3, min: 3, max: 5);
      return CosmicSpecialResult(
        projectiles: List.generate(localCount, (i) {
          final side = i.isEven ? -1.0 : 1.0;
          final dist = 18.0 + (i ~/ 2) * 12.0;
          return scalePipProjectile(
            dart(
              position: Offset(
                origin.dx +
                    cos(baseAngle) * dist +
                    cos(baseAngle + pi / 2) * side * 14,
                origin.dy +
                    sin(baseAngle) * dist +
                    sin(baseAngle + pi / 2) * side * 14,
              ),
              angle: baseAngle + side * 0.10,
              damageMultiplier: 1.85,
              life: 2.0,
              speed: 1.55,
              homing: false,
              homingStrength: 0.8,
              visualScale: 1.20,
              piercing: true,
              bounceCount: 1,
            ),
          );
        }),
      );
    case 'Earth':
      final localCount = scaledCount(3, min: 2, max: 4);
      return CosmicSpecialResult(
        projectiles: List.generate(localCount, (i) {
          final lane = (i - (localCount - 1) / 2) * 14.0;
          return scalePipProjectile(
            dart(
              position: Offset(
                origin.dx +
                    cos(baseAngle) * 20 +
                    cos(baseAngle + pi / 2) * lane,
                origin.dy +
                    sin(baseAngle) * 20 +
                    sin(baseAngle + pi / 2) * lane,
              ),
              angle: baseAngle + (i - (localCount - 1) / 2) * 0.08,
              damageMultiplier: 2.95,
              life: 2.4,
              speed: 1.05,
              homingStrength: 2.0,
              visualScale: 1.30,
            ),
          );
        }),
      );
    case 'Poison':
      final center = Offset(
        origin.dx + cos(baseAngle) * 28,
        origin.dy + sin(baseAngle) * 28,
      );
      final localCount = scaledCount(3, min: 2, max: 4);
      return CosmicSpecialResult(
        projectiles: List.generate(localCount, (i) {
          final offset = i - (localCount - 1) / 2;
          final a = baseAngle + offset * 0.16;
          return scalePipProjectile(
            dart(
              position: Offset(
                center.dx + cos(a + pi / 2) * offset * 6,
                center.dy + sin(a + pi / 2) * offset * 6,
              ),
              angle: a,
              damageMultiplier: 2.00,
              life: 3.0,
              speed: 1.0,
              homingStrength: 2.4,
              visualScale: 1.22,
              piercing: true,
              bounceCount: 1,
              snareRadius: 50.0,
              snareMoveMultiplier: 0.78,
            ),
          );
        }),
      );
    case 'Light':
      final halo = Offset(
        origin.dx + cos(baseAngle) * 40,
        origin.dy + sin(baseAngle) * 40,
      );
      final localCount = scaledCount(4, min: 3, max: 6);
      return CosmicSpecialResult(
        projectiles: List.generate(localCount, (i) {
          final a = i * (pi * 2 / localCount);
          return scalePipProjectile(
            dart(
              position: Offset(halo.dx + cos(a) * 18, halo.dy + sin(a) * 18),
              angle: a + pi / 2,
              damageMultiplier: 1.65,
              life: 2.4,
              speed: 1.7,
              homingStrength: 1.6,
              visualScale: 1.20,
              bounceCount: 2,
              piercing: true,
              interceptRadius: 24.0,
              interceptCharges: 1,
            ),
          );
        }),
      );
    default:
      return CosmicSpecialResult(projectiles: genericVolley());
  }
}

int _pipElementBounce(String e) => switch (e) {
  'Crystal' => 5,
  'Lightning' => 4,
  'Air' => 4,
  'Light' => 3,
  'Fire' => 3,
  'Water' => 3,
  'Ice' => 3,
  'Dust' => 2,
  _ => 0,
};

int _pipElementCount(String e) => switch (e) {
  // Counts tuned for the "ricochet salvo" identity — pips are fast
  // bouncing darts, not screen-fill swarms. Lightning gets the most
  // (its design is "double the ricochet"). Heavy elements (Lava,
  // Blood, Dark, Earth) compensate with higher per-dart damage.
  'Lightning' => 6,
  'Dust' => 5,
  'Crystal' => 4,
  'Air' => 4,
  'Fire' => 3,
  'Water' => 3,
  'Ice' => 3,
  'Steam' => 3,
  'Light' => 4,
  'Blood' => 3,
  'Lava' => 2,
  'Earth' => 3,
  'Mud' => 5,
  'Plant' => 6,
  'Poison' => 5,
  'Spirit' => 4,
  'Dark' => 5,
  _ => 6,
};

double _pipElementDamageMultiplier(String e) => switch (e) {
  'Blood' => 3.0,
  'Dark' => 2.8,
  'Lava' => 2.5,
  'Earth' => 2.5,
  'Spirit' => 2.2,
  'Crystal' => 1.8,
  'Fire' => 1.8,
  'Ice' => 1.8,
  'Water' => 1.6,
  'Mud' => 1.6,
  'Plant' => 1.6,
  'Poison' => 1.4,
  'Steam' => 1.4,
  'Lightning' => 1.4,
  'Air' => 1.2,
  'Light' => 1.4,
  'Dust' => 0.9,
  _ => 1.8,
};

double _pipElementLife(String e) => switch (e) {
  'Blood' => 3.5,
  'Spirit' => 4.0,
  'Poison' => 3.5,
  'Plant' => 3.0,
  'Mud' => 3.0,
  'Water' => 3.0,
  'Lava' => 2.5,
  'Ice' => 2.8,
  'Steam' => 2.5,
  'Earth' => 2.5,
  'Crystal' => 2.5,
  'Dark' => 2.5,
  'Fire' => 2.2,
  'Lightning' => 1.8,
  'Dust' => 1.8,
  'Air' => 1.8,
  'Light' => 3.0,
  _ => 2.5,
};

double _pipElementSpeed(String e) => switch (e) {
  'Lightning' => 2.3,
  'Air' => 2.0,
  'Dust' => 1.8,
  'Fire' => 1.6,
  'Light' => 1.5,
  'Crystal' => 1.4,
  'Dark' => 1.5,
  'Water' => 1.2,
  'Steam' => 1.2,
  'Ice' => 1.1,
  'Plant' => 1.1,
  'Earth' => 1.0,
  'Lava' => 0.9,
  'Mud' => 0.9,
  'Poison' => 1.0,
  'Spirit' => 0.9,
  'Blood' => 0.8,
  _ => 1.4,
};

double _pipElementHoming(String e) => switch (e) {
  // Pips are ricochet shots — they bounce. Homing was too strong
  // (5–6 felt like guided missiles tracking enemies across the
  // whole field). Pulled the whole table down so darts now ricochet
  // toward enemies but don't *hunt* them around obstacles.
  'Spirit' => 3.2,
  'Blood' => 3.0,
  'Dark' => 2.8,
  'Plant' => 2.6,
  'Poison' => 2.6,
  'Crystal' => 2.4,
  'Mud' => 2.2,
  'Lava' => 2.0,
  'Ice' => 2.2,
  'Water' => 2.4,
  'Earth' => 2.0,
  'Fire' => 2.0,
  'Lightning' => 1.8,
  'Air' => 1.0,
  'Steam' => 1.0,
  'Light' => 1.6,
  'Dust' => 1.4,
  _ => 2.2,
};

// ─────────────────────────────────────────────────────────
// MANE — Barrage Volley
// Design: Dense, satisfying sprays — was way too weak before
// ─────────────────────────────────────────────────────────
CosmicSpecialResult _maneSpecial(
  Offset origin,
  double baseAngle,
  String element,
  double damage,
  int maxHp,
  double casterBeauty,
  double casterIntelligence,
  double casterStrength,
) {
  Projectile slash({
    required Offset position,
    required double angle,
    required double damageMultiplier,
    required double life,
    required double speed,
    required double visualScale,
    bool piercing = false,
    bool homing = false,
    double homingStrength = 3.0,
    bool stationary = false,
    int bounceCount = 0,
    double radiusMultiplier = 1.0,
    double trailInterval = 0,
    double trailDamage = 0,
    double trailLife = 0,
    double snareRadius = 0,
    double snareMoveMultiplier = 1,
    double interceptRadius = 0,
    int interceptCharges = 0,
  }) {
    return Projectile(
      position: position,
      angle: angle,
      element: element,
      damage: damage * damageMultiplier,
      life: life,
      speedMultiplier: speed,
      piercing: piercing,
      homing: homing,
      homingStrength: homingStrength,
      stationary: stationary,
      bounceCount: bounceCount,
      radiusMultiplier: radiusMultiplier,
      visualScale: visualScale,
      trailInterval: trailInterval,
      trailDamage: trailDamage,
      trailLife: trailLife,
      snareRadius: snareRadius,
      snareMoveMultiplier: snareMoveMultiplier,
      interceptRadius: interceptRadius,
      interceptCharges: interceptCharges,
      visualStyle: ProjectileVisualStyle.slash,
    );
  }

  int scaledCount(int base, {int min = 2, int max = 10}) {
    final scale = _specialCountScaleFromBaseline(
      casterBeauty,
      casterIntelligence,
      beautyPerPoint: 0.08,
      intelligencePerPoint: 0.10,
      min: 0.74,
      max: 1.28,
    );
    return (base * scale * 0.58).round().clamp(min, max);
  }

  int scaledManePowerCount({int min = 4, int max = 10}) {
    final weightedStat = casterStrength * 0.62 + casterBeauty * 0.38;
    final t = AlchemonStatSystem.combatProgress(weightedStat);
    return (min + (max - min) * t).round().clamp(min, max);
  }

  double scaledSpread(double base) {
    final beautySpread = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.05,
      min: 0.90,
      max: 1.10,
    );
    final focusScale = _specialStatScaleFromBaseline(
      casterIntelligence,
      perPoint: -0.04,
      min: 0.90,
      max: 1.08,
    );
    return base * beautySpread * focusScale;
  }

  Projectile scaleManeProjectile(Projectile p) {
    final impactScale = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.10,
      min: 0.82,
      max: 1.20,
    );
    final earthForceScale = p.element == 'Earth'
        ? _specialStatScaleFromBaseline(
            casterStrength,
            perPoint: 0.08,
            min: 0.86,
            max: 1.18,
          )
        : 1.0;
    final visualScaleMul = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.14,
      min: 0.80,
      max: 1.24,
    );
    final controlScale = _specialStatScaleFromBaseline(
      casterIntelligence,
      perPoint: 0.12,
      min: 0.80,
      max: 1.24,
    );
    final durationScale = _specialStatScaleFromBaseline(
      casterIntelligence,
      perPoint: 0.09,
      min: 0.84,
      max: 1.18,
    );
    final rawSpeed = p.speedMultiplier * controlScale;
    // Manes are slow piercing catapults, except the authored speed outliers:
    // Air's identity is a 2× gale that shoves enemies along the shot path,
    // and Fire is "(3–8) fireballs shot out and travel FAST" per the design
    // board — both are exempt from the catapult crawl.
    final catapultSpeed = p.stationary
        ? 0.0
        : p.element == 'Air'
        ? rawSpeed.clamp(1.5, 2.8).toDouble()
        : p.element == 'Fire'
        ? rawSpeed.clamp(1.0, 1.6).toDouble()
        : rawSpeed.clamp(0.24, 0.58).toDouble();
    return _copyProjectile(
      p,
      damage: p.damage * impactScale * earthForceScale * 1.65,
      life: p.life * durationScale * (p.stationary ? 1.0 : 1.55),
      speedMultiplier: catapultSpeed,
      radiusMultiplier: p.radiusMultiplier * visualScaleMul * 1.18,
      piercing: true,
      homing: false,
      homingStrength: p.homingStrength * controlScale,
      visualScale: p.visualScale * visualScaleMul,
      trailDamage: p.trailDamage * impactScale,
      trailLife: p.trailLife * durationScale,
      turretInterval: p.turretInterval > 0
          ? (p.turretInterval / controlScale).clamp(0.48, 1.25).toDouble()
          : p.turretInterval,
      turretDamage: p.turretDamage * impactScale * earthForceScale,
      snareRadius: p.snareRadius * visualScaleMul,
      abilityFamily: 'mane',
      pierceEffect: p.pierceEffect == AbilityEffectKind.none
          ? _manePierceEffect(p.element ?? '')
          : p.pierceEffect,
      hitEffect: p.hitEffect == AbilityEffectKind.none
          ? _manePierceEffect(p.element ?? '')
          : p.hitEffect,
      killEffect:
          p.killEffect == AbilityEffectKind.none &&
              (p.element == 'Plant' || p.element == 'Dark')
          ? _manePierceEffect(p.element ?? '')
          : p.killEffect,
      effectPower: p.effectPower > 0
          ? p.effectPower * impactScale * earthForceScale
          : p.damage * impactScale * earthForceScale * 0.34,
      effectRadius: p.effectRadius > 0
          ? p.effectRadius * visualScaleMul
          : 92.0 * visualScaleMul,
      effectDuration: p.effectDuration > 0
          ? p.effectDuration * durationScale
          : 2.4 * durationScale,
      effectCount: p.effectCount > 0 ? p.effectCount : 3,
    );
  }

  CosmicSpecialResult finalize(CosmicSpecialResult result) {
    final tempoScale = _specialStatScaleFromBaseline(
      casterIntelligence,
      perPoint: 0.10,
      min: 0.86,
      max: 1.18,
    );
    final sustainScale = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.08,
      min: 0.84,
      max: 1.18,
    );
    final hasteDelta = (1.0 - result.basicHasteMultiplier) * tempoScale;
    return CosmicSpecialResult(
      projectiles: result.projectiles.map(scaleManeProjectile).toList(),
      beams: result.beams,
      shieldHp: result.shieldHp,
      chargeTimer: result.chargeTimer,
      chargeDamage: result.chargeDamage,
      chargeSpeedMultiplier: result.chargeSpeedMultiplier,
      chargeSweepRadius: result.chargeSweepRadius,
      chargeOvershootDistance: result.chargeOvershootDistance,
      chargeFinalSweepRadius: result.chargeFinalSweepRadius,
      selfHeal: (result.selfHeal * sustainScale).round(),
      shipHeal: (result.shipHeal * sustainScale).round(),
      blessingTimer: result.blessingTimer,
      blessingHealPerTick: result.blessingHealPerTick,
      basicHasteTimer: result.basicHasteTimer * tempoScale,
      basicHasteMultiplier: result.basicHasteTimer > 0
          ? (1.0 - hasteDelta).clamp(0.60, 1.0).toDouble()
          : result.basicHasteMultiplier,
    );
  }

  final count = scaledCount(_maneElementCount(element));
  final spread = scaledSpread(_maneElementSpread(element));

  List<Projectile> forwardFan({
    required int lanes,
    required double arc,
    required double damageMultiplier,
    required double life,
    required double speed,
    required double visualScale,
    bool piercing = false,
    bool homingCenter = false,
    double snareRadius = 0,
    double snareMoveMultiplier = 1,
    double radiusMultiplier = 1.0,
    double trailInterval = 0,
    double trailDamage = 0,
    double trailLife = 0,
  }) {
    final localLanes = lanes.clamp(1, 18);
    return List.generate(localLanes, (i) {
      final t = localLanes > 1 ? (i / (localLanes - 1)) - 0.5 : 0.0;
      final a = baseAngle + t * arc;
      final dist = 14.0 + t.abs() * 10.0;
      return slash(
        position: Offset(origin.dx + cos(a) * dist, origin.dy + sin(a) * dist),
        angle: a,
        damageMultiplier: damageMultiplier,
        life: life,
        speed: speed,
        visualScale: visualScale,
        piercing: piercing,
        homing: homingCenter && i == localLanes ~/ 2,
        homingStrength: 2.4,
        snareRadius: snareRadius,
        snareMoveMultiplier: snareMoveMultiplier,
        radiusMultiplier: radiusMultiplier,
        trailInterval: trailInterval,
        trailDamage: trailDamage,
        trailLife: trailLife,
      );
    });
  }

  CosmicSpecialResult fanResult({
    required int lanes,
    required double arc,
    required double damageMultiplier,
    required double life,
    required double speed,
    required double visualScale,
    bool piercing = false,
    bool homingCenter = false,
    double snareRadius = 0,
    double snareMoveMultiplier = 1,
    double radiusMultiplier = 1.0,
    double basicHasteTimer = 0,
    double basicHasteMultiplier = 1.0,
    int selfHeal = 0,
    int interceptCharges = 0,
    double interceptRadius = 0,
    double trailInterval = 0,
    double trailDamage = 0,
    double trailLife = 0,
  }) {
    final wave = forwardFan(
      lanes: lanes,
      arc: arc,
      damageMultiplier: damageMultiplier,
      life: life,
      speed: speed,
      visualScale: visualScale,
      piercing: piercing,
      homingCenter: homingCenter,
      snareRadius: snareRadius,
      snareMoveMultiplier: snareMoveMultiplier,
      radiusMultiplier: radiusMultiplier,
      trailInterval: trailInterval,
      trailDamage: trailDamage,
      trailLife: trailLife,
    );
    final withDefense = interceptCharges > 0
        ? wave
              .asMap()
              .entries
              .map(
                (e) => e.key == wave.length ~/ 2
                    ? _copyProjectile(
                        e.value,
                        interceptCharges: interceptCharges,
                        interceptRadius: interceptRadius,
                      )
                    : e.value,
              )
              .toList()
        : wave;
    return CosmicSpecialResult(
      projectiles: withDefense,
      basicHasteTimer: basicHasteTimer,
      basicHasteMultiplier: basicHasteMultiplier,
      selfHeal: selfHeal,
    );
  }

  switch (element) {
    case 'Earth':
      // One massive fault slab that slowly grinds forward. It breaks down
      // into quake bursts along its path instead of firing cute auto-shots.
      return finalize(
        CosmicSpecialResult(
          basicHasteTimer: 1.4,
          basicHasteMultiplier: 0.86,
          projectiles: [
            Projectile(
              position: origin,
              angle: baseAngle,
              element: 'Earth',
              damage: damage * 3.15,
              life: 4.8,
              speedMultiplier: 0.38,
              radiusMultiplier: 4.9,
              visualScale: 4.0,
              piercing: true,
              visualStyle: ProjectileVisualStyle.slash,
              abilityFamily: 'mane',
              pierceEffect: _manePierceEffect('Earth'),
              effectPower: damage * 0.86,
              effectRadius: 138,
              effectDuration: 2.2,
              snareRadius: 118,
              snareMoveMultiplier: 0.58,
              // Reused by the runtimes as path quake-pulse cadence/damage.
              turretInterval: 0.72,
              turretDamage: damage * 1.05,
            ),
          ],
        ),
      );
    case 'Lava':
      return finalize(
        fanResult(
          lanes: scaledCount(5, min: 4, max: 7),
          arc: pi * 0.34,
          damageMultiplier: 2.05,
          life: 2.25,
          speed: 1.08,
          visualScale: 1.7,
          piercing: true,
          snareRadius: 72,
          snareMoveMultiplier: 0.82,
          radiusMultiplier: 1.5,
        ),
      );
    case 'Mud':
      // Design board: "First enemy hit, ball breaks apart and goes in 10
      // different ways." One heavy aimed ball; the ten-way shatter is wired
      // on collision in both survival and the dungeon, and consumes it.
      //
      // This was a six-lane 90-degree fan, which never fired at the target at
      // all — aimed at a boss it sprayed +-45 degrees either side, so most
      // lanes missed and the shatter went off nowhere near what you aimed at.
      //
      // The family forces piercing on every mane projectile, but it is moot
      // here: the shatter marks the ball consumed on its first enemy hit.
      return finalize(
        fanResult(
          lanes: 1,
          arc: 0,
          damageMultiplier: 2.10,
          life: 3.1,
          speed: 0.90,
          visualScale: 1.60,
          snareRadius: 124,
          snareMoveMultiplier: 0.56,
          radiusMultiplier: 1.55,
          basicHasteTimer: 1.2,
          basicHasteMultiplier: 0.90,
        ),
      );
    case 'Fire':
      // Design board: "(3–8) fireballs shot out and travel fast."
      final fireballCount = scaledCount(6, min: 3, max: 8);
      return finalize(
        fanResult(
          lanes: fireballCount,
          arc: pi * 0.92,
          damageMultiplier: 1.12,
          life: 2.55,
          speed: 0.96,
          visualScale: 1.10,
          piercing: true,
          basicHasteTimer: 1.8,
          basicHasteMultiplier: 0.80,
        ),
      );
    case 'Lightning':
      // Survival rebuilds this into a stationary lightning-rod field
      // (see cosmic_survival_game.dart); open-world keeps the fan.
      return finalize(
        fanResult(
          lanes: scaledCount(7, min: 5, max: 10),
          arc: pi * 0.42,
          damageMultiplier: 1.30,
          life: 2.7,
          speed: 0.92,
          visualScale: 1.10,
          piercing: true,
          basicHasteTimer: 1.6,
          basicHasteMultiplier: 0.78,
        ),
      );
    case 'Air':
      // Air is the fast Mane outlier: a wide piercing gale that travels at
      // roughly 2x speed and shoves enemies along its path on pierce.
      return finalize(
        fanResult(
          lanes: scaledCount(8, min: 5, max: 10),
          arc: pi * 0.94,
          damageMultiplier: 0.98,
          life: 1.8,
          speed: 2.0,
          visualScale: 1.02,
          piercing: true,
          basicHasteTimer: 2.0,
          basicHasteMultiplier: 0.74,
        ),
      );
    case 'Water':
      // One massive wall of water that carries enemies along with it via
      // the existing carry pierceEffect. Wide hitbox, slow, piercing —
      // sweeps through a lane.
      return finalize(
        CosmicSpecialResult(
          basicHasteTimer: 1.5,
          basicHasteMultiplier: 0.84,
          projectiles: [
            Projectile(
              position: origin,
              angle: baseAngle,
              element: 'Water',
              damage: damage * 1.9,
              life: 3.8,
              speedMultiplier: 0.64,
              radiusMultiplier: 5.5,
              visualScale: 4.4,
              piercing: true,
              visualStyle: ProjectileVisualStyle.slash,
              abilityFamily: 'mane',
              pierceEffect: AbilityEffectKind.carry,
              effectPower: damage * 0.4,
              effectRadius: 110,
              effectDuration: 1.4,
              snareRadius: 130,
              snareMoveMultiplier: 0.55,
            ),
          ],
        ),
      );
    case 'Steam':
      // One big geyser projectile that travels and periodically releases
      // AOE steam puffs along its path.
      return finalize(
        CosmicSpecialResult(
          basicHasteTimer: 2.0,
          basicHasteMultiplier: 0.78,
          projectiles: [
            Projectile(
              position: origin,
              angle: baseAngle,
              element: 'Steam',
              damage: damage * 1.4,
              life: 3.8,
              speedMultiplier: 0.68,
              radiusMultiplier: 2.4,
              visualScale: 2.2,
              piercing: true,
              visualStyle: ProjectileVisualStyle.slash,
              abilityFamily: 'mane',
              pierceEffect: _manePierceEffect('Steam'),
              effectPower: damage * 0.32,
              effectRadius: 90,
              effectDuration: 1.6,
              // Drop a steam pulse every 0.35s along its path.
              turretInterval: 0.35,
              turretDamage: damage * 0.42,
            ),
          ],
        ),
      );
    case 'Plant':
      return finalize(
        CosmicSpecialResult(
          basicHasteTimer: 1.5,
          basicHasteMultiplier: 0.84,
          projectiles: [
            ...forwardFan(
              lanes: scaledCount(5, min: 4, max: 7),
              arc: pi * 0.28,
              damageMultiplier: 1.42,
              life: 2.9,
              speed: 1.02,
              visualScale: 1.08,
              piercing: true,
              snareRadius: 112,
              snareMoveMultiplier: 0.62,
            ),
            ...forwardFan(
              lanes: scaledCount(2, min: 2, max: 3),
              arc: pi * 0.76,
              damageMultiplier: 1.02,
              life: 3.2,
              speed: 0.94,
              visualScale: 1.02,
              piercing: true,
              snareRadius: 122,
              snareMoveMultiplier: 0.56,
            ),
          ],
        ),
      );
    case 'Poison':
      return finalize(
        fanResult(
          lanes: scaledCount(6, min: 4, max: 8),
          arc: pi * 0.70,
          damageMultiplier: 1.12,
          life: 4.3,
          speed: 0.82,
          visualScale: 1.20,
          piercing: true,
          snareRadius: 116,
          snareMoveMultiplier: 0.58,
          basicHasteTimer: 1.6,
          basicHasteMultiplier: 0.82,
          radiusMultiplier: 1.18,
        ),
      );
    case 'Ice':
      return finalize(
        fanResult(
          lanes: scaledCount(6, min: 4, max: 8),
          arc: pi * 0.40,
          damageMultiplier: 1.46,
          life: 3.0,
          speed: 0.88,
          visualScale: 1.12,
          piercing: true,
          snareRadius: 90,
          snareMoveMultiplier: 0.58,
          radiusMultiplier: 1.12,
        ),
      );
    case 'Crystal':
      return finalize(
        CosmicSpecialResult(
          basicHasteTimer: 1.0,
          basicHasteMultiplier: 0.90,
          projectiles: [
            ...forwardFan(
              lanes: 3,
              arc: pi * 0.16,
              damageMultiplier: 1.92,
              life: 3.1,
              speed: 0.82,
              visualScale: 1.20,
              piercing: true,
              radiusMultiplier: 1.22,
            ),
            ...forwardFan(
              lanes: 2,
              arc: pi * 0.66,
              damageMultiplier: 0.88,
              life: 2.8,
              speed: 0.80,
              visualScale: 0.92,
              piercing: true,
            ),
          ],
        ),
      );
    case 'Spirit':
      // Survival ramps the lane count 1→10 across successive casts
      // (see cosmic_survival_game.dart); open-world keeps the fan.
      return finalize(
        fanResult(
          lanes: scaledCount(6, min: 4, max: 8),
          arc: pi * 0.34,
          damageMultiplier: 1.66,
          life: 3.1,
          speed: 0.82,
          visualScale: 1.04,
          piercing: true,
          basicHasteTimer: 2.0,
          basicHasteMultiplier: 0.76,
        ),
      );
    case 'Dark':
      // Per design: ONE slow void bolt that travels through the field,
      // constantly pulling nearby enemies toward it. Low-HP enemies
      // caught in the pull are executed on pierce (survival hook).
      return finalize(
        CosmicSpecialResult(
          basicHasteTimer: 1.4,
          basicHasteMultiplier: 0.78,
          projectiles: [
            Projectile(
              position: origin,
              angle: baseAngle,
              element: 'Dark',
              damage: damage * 2.4,
              life: 5.5,
              speedMultiplier: 0.42,
              radiusMultiplier: 2.6,
              visualScale: 2.4,
              piercing: true,
              visualStyle: ProjectileVisualStyle.slash,
              abilityFamily: 'mane',
              pierceEffect: AbilityEffectKind.blackHole,
              effectPower: damage * 0.55,
              effectRadius: 180,
              effectDuration: 1.5,
              // Survival per-frame hook reads snareRadius as the pull
              // radius for the traveling void bolt.
              snareRadius: 180,
              snareMoveMultiplier: 0.55,
            ),
          ],
        ),
      );
    case 'Blood':
      // Per design: restore HP per pierce instead of a fixed cast-
      // time heal. The per-pierce heal is wired survival-side in
      // resolveAbilityPierce.
      return finalize(
        CosmicSpecialResult(
          basicHasteTimer: 1.5,
          basicHasteMultiplier: 0.82,
          projectiles: [
            ...forwardFan(
              lanes: scaledCount(2, min: 2, max: 3),
              arc: pi * 0.24,
              damageMultiplier: 1.70,
              life: 2.8,
              speed: 1.05,
              visualScale: 1.28,
              piercing: true,
              snareRadius: 78,
              snareMoveMultiplier: 0.72,
              radiusMultiplier: 1.24,
            ),
            ...forwardFan(
              lanes: 1,
              arc: 0,
              damageMultiplier: 2.35,
              life: 3.0,
              speed: 0.76,
              visualScale: 1.34,
              piercing: true,
              radiusMultiplier: 1.30,
            ),
          ],
        ),
      );
    case 'Dust':
      return finalize(
        fanResult(
          lanes: scaledCount(12, min: 9, max: 16),
          arc: pi * 1.02,
          damageMultiplier: 0.84,
          life: 2.6,
          speed: 0.92,
          visualScale: 0.94,
          piercing: true,
          trailInterval: 0.24,
          trailDamage: damage * 0.18,
          trailLife: 2.4,
          basicHasteTimer: 2.2,
          basicHasteMultiplier: 0.70,
        ),
      );
    case 'Light':
      final orbCount = scaledManePowerCount();
      return finalize(
        CosmicSpecialResult(
          basicHasteTimer: 1.4,
          basicHasteMultiplier: 0.84,
          projectiles: List.generate(orbCount, (i) {
            final t = orbCount > 1 ? (i / (orbCount - 1)) - 0.5 : 0.0;
            final a = baseAngle + t * pi * 0.34;
            final stagger = (i - orbCount / 2) * 5.0;
            return Projectile(
              position:
                  origin +
                  Offset(cos(a), sin(a)) * (12.0 + t.abs() * 8.0) -
                  Offset(cos(baseAngle), sin(baseAngle)) * stagger,
              angle: a,
              element: 'Light',
              damage: damage * 1.35,
              life: 5.2,
              speedMultiplier: 0.30,
              radiusMultiplier: 0.74,
              visualScale: 0.76,
              piercing: true,
              visualStyle: ProjectileVisualStyle.slash,
              abilityFamily: 'mane',
              pierceEffect: _manePierceEffect('Light'),
              effectPower: damage * 0.34,
              effectRadius: 76,
              effectDuration: 1.2,
            );
          }),
        ),
      );
    default:
      return finalize(
        CosmicSpecialResult(
          projectiles: forwardFan(
            lanes: count,
            arc: spread,
            damageMultiplier: _maneElementDamageMultiplier(element),
            life: _maneElementLife(element),
            speed: _maneElementSpeed(element),
            visualScale: _maneElementVisualScale(element),
            piercing:
                element == 'Spirit' ||
                element == 'Light' ||
                element == 'Crystal',
          ),
        ),
      );
  }
}

int _maneElementCount(String e) => switch (e) {
  'Fire' => 9,
  'Lightning' => 7,
  'Ice' => 8,
  'Dust' => 10,
  'Light' => 8,
  'Crystal' => 6,
  'Water' => 7,
  'Lava' => 5,
  'Steam' => 7,
  'Earth' => 4,
  'Mud' => 5,
  'Air' => 8,
  'Plant' => 6,
  'Poison' => 5,
  'Spirit' => 5,
  'Dark' => 5,
  'Blood' => 4,
  _ => 7,
};

double _maneElementSpread(String e) => switch (e) {
  'Fire' => pi * 0.95,
  'Ice' => pi * 0.85,
  'Light' => pi * 1.0,
  'Dust' => pi * 0.9,
  'Air' => pi * 0.8,
  'Water' => pi * 0.65,
  'Steam' => pi * 0.7,
  'Poison' => pi * 0.55,
  'Lightning' => pi * 0.42,
  'Crystal' => pi * 0.35,
  'Plant' => pi * 0.38,
  'Mud' => pi * 0.34,
  'Lava' => pi * 0.32,
  'Earth' => pi * 0.28,
  'Spirit' => pi * 0.40,
  'Dark' => pi * 0.36,
  'Blood' => pi * 0.24,
  _ => pi * 0.55,
};

// HUGE uplift here — was 0.3-0.5, now 1.2-2.5
double _maneElementDamageMultiplier(String e) => switch (e) {
  'Earth' => 2.4,
  'Dark' => 2.2,
  'Blood' => 2.2,
  'Lava' => 2.0,
  'Crystal' => 2.0,
  'Spirit' => 1.8,
  'Ice' => 1.8,
  'Mud' => 1.8,
  'Plant' => 1.6,
  'Lightning' => 1.6,
  'Water' => 1.5,
  'Poison' => 1.5,
  'Steam' => 1.4,
  'Fire' => 1.4,
  'Air' => 1.2,
  'Light' => 1.2,
  'Dust' => 1.0,
  _ => 1.5,
};

double _maneElementLife(String e) => switch (e) {
  'Poison' => 3.0,
  'Mud' => 2.5,
  'Plant' => 2.5,
  'Lava' => 2.5,
  'Earth' => 2.2,
  'Steam' => 2.5,
  'Spirit' => 2.5,
  'Blood' => 2.2,
  'Water' => 2.0,
  'Ice' => 2.0,
  'Crystal' => 2.0,
  'Dark' => 2.0,
  'Fire' => 1.6,
  'Lightning' => 1.3,
  'Dust' => 1.3,
  'Air' => 1.5,
  'Light' => 2.0,
  _ => 2.0,
};

double _maneElementSpeed(String e) => switch (e) {
  'Lightning' => 0.56,
  'Air' => 0.58,
  'Dust' => 0.54,
  'Fire' => 0.56,
  'Light' => 0.54,
  'Water' => 0.50,
  'Crystal' => 0.50,
  'Dark' => 0.44,
  'Spirit' => 0.50,
  'Ice' => 0.52,
  'Steam' => 0.48,
  'Plant' => 0.48,
  'Blood' => 0.46,
  'Poison' => 0.48,
  'Earth' => 0.36,
  'Mud' => 0.40,
  'Lava' => 0.38,
  _ => 0.52,
};

double _maneElementVisualScale(String e) => switch (e) {
  'Earth' => 1.8,
  'Lava' => 1.7,
  'Mud' => 1.6,
  'Blood' => 1.3,
  'Steam' => 1.2,
  'Crystal' => 0.9,
  'Ice' => 1.1,
  'Water' => 1.0,
  'Plant' => 1.0,
  'Poison' => 1.1,
  'Spirit' => 1.0,
  'Dark' => 1.1,
  'Fire' => 0.9,
  'Lightning' => 0.8,
  'Air' => 0.8,
  'Dust' => 0.7,
  'Light' => 0.9,
  _ => 1.0,
};

// ─────────────────────────────────────────────────────────
// MASK — Mine Field / Decoy Assault
// COMPLETE REWORK: Decoys now ACTIVELY SEEK enemies on spawn.
// Mine elements fire a burst of seeking/homing projectiles instead of
// sitting still hoping something walks into them.
// ─────────────────────────────────────────────────────────
CosmicSpecialResult _maskSpecial(
  Offset origin,
  double baseAngle,
  String element,
  double damage,
  double casterBeauty,
  double casterIntelligence,
  Offset? targetPos,
) {
  // MASK — Traps theme (per design board). Each special scatters
  // element-specific trap placements across the field. NO homing
  // seekers, NO decoy missiles — just placed traps that activate
  // on contact, persist as DoT zones, or buff allies. Several
  // elements (Spirit collectible-wisps, Plant growing-vine, etc.)
  // require survival-side custom hooks; those are spawned here
  // with the right shape and consumed by the survival update loop.
  final rng = Random();
  final projs = <Projectile>[];

  int scaledCount(int base, {int min = 2, int max = 25}) {
    final scale = _specialCountScaleFromBaseline(
      casterBeauty,
      casterIntelligence,
      beautyPerPoint: 0.06,
      intelligencePerPoint: 0.10,
      min: 0.50,
      max: 1.80,
    );
    return (base * scale).round().clamp(min, max);
  }

  // Generic scaling pass — applied uniformly to all mask traps.
  Projectile scaleMaskProjectile(Projectile p) {
    final impactScale = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.10,
      min: 0.85,
      max: 1.25,
    );
    final visualScaleMul = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.12,
      min: 0.85,
      max: 1.25,
    );
    final durationScale = _specialStatScaleFromBaseline(
      casterIntelligence,
      perPoint: 0.10,
      min: 0.88,
      max: 1.30,
    );
    final radScale = _specialStatScaleFromBaseline(
      casterIntelligence,
      perPoint: 0.10,
      min: 0.88,
      max: 1.25,
    );
    return _copyProjectile(
      p,
      damage: p.damage * impactScale,
      life: p.life * durationScale,
      radiusMultiplier: p.radiusMultiplier * visualScaleMul,
      visualScale: p.visualScale * visualScaleMul,
      decoyHp: p.decoy ? p.decoyHp * impactScale : p.decoyHp,
      deathExplosionDamage: p.deathExplosionDamage * impactScale,
      deathExplosionRadius: p.deathExplosionRadius * visualScaleMul,
      effectPower: p.effectPower * impactScale,
      effectRadius: p.effectRadius * radScale,
      effectDuration: p.effectDuration * durationScale,
      abilityFamily: 'mask',
    );
  }

  CosmicSpecialResult finalize(CosmicSpecialResult result) {
    return CosmicSpecialResult(
      projectiles: result.projectiles.map(scaleMaskProjectile).toList(),
      beams: result.beams,
      shieldHp: result.shieldHp,
      chargeTimer: result.chargeTimer,
      chargeDamage: result.chargeDamage,
      chargeSpeedMultiplier: result.chargeSpeedMultiplier,
      chargeSweepRadius: result.chargeSweepRadius,
      chargeOvershootDistance: result.chargeOvershootDistance,
      chargeFinalSweepRadius: result.chargeFinalSweepRadius,
      selfHeal: result.selfHeal,
      shipHeal: result.shipHeal,
      blessingTimer: result.blessingTimer,
      blessingHealPerTick: result.blessingHealPerTick,
      basicHasteTimer: result.basicHasteTimer,
      basicHasteMultiplier: result.basicHasteMultiplier,
    );
  }

  // Generic stationary trap-placement projectile. Element-specific
  // mechanics are layered via hitEffect/tickEffect markers that the
  // survival update loop consumes. Stationary + sigil-visual by default
  // so traps read as placed fixtures, not lures or missiles.
  Projectile trap({
    required Offset pos,
    required double dmgMul,
    required double life,
    AbilityEffectKind hitEffect = AbilityEffectKind.none,
    AbilityEffectKind tickEffect = AbilityEffectKind.none,
    AbilityEffectKind killEffect = AbilityEffectKind.none,
    double effectPower = 0,
    double effectRadius = 0,
    double effectDuration = 0,
    int effectCount = 0,
    double radius = 1.8,
    double vs = 1.8,
    bool piercing = true,
    bool reflectsProjectiles = false,
    double snareRadius = 0,
    double snareMoveMultiplier = 1.0,
  }) {
    return Projectile(
      position: pos,
      angle: 0,
      element: element,
      damage: damage * dmgMul,
      life: life,
      speedMultiplier: 0,
      stationary: true,
      piercing: piercing,
      radiusMultiplier: radius,
      visualScale: vs,
      visualStyle: ProjectileVisualStyle.sigil,
      reflectsProjectiles: reflectsProjectiles,
      snareRadius: snareRadius,
      snareMoveMultiplier: snareMoveMultiplier,
      abilityFamily: 'mask',
      hitEffect: hitEffect,
      tickEffect: tickEffect,
      killEffect: killEffect,
      effectPower: effectPower,
      effectRadius: effectRadius,
      effectDuration: effectDuration,
      effectCount: effectCount,
    );
  }

  // Low-discrepancy disc scatter around the trap anchor.
  // Higher Intelligence → traps spread wider across the field;
  // higher counts also fan wider so dense scatters don't stack up.
  final intelSpreadScale = _specialStatScaleFromBaseline(
    casterIntelligence,
    perPoint: 0.16,
    min: 0.85,
    max: 2.2,
  );
  List<Offset> scatterPositions(
    Offset anchor,
    int count, {
    double baseSpread = 200.0,
    double startRing = 0.10,
  }) {
    final maxSpread =
        baseSpread *
        intelSpreadScale *
        (count > 4 ? 1.0 + (count - 4) * 0.10 : 1.0);
    return List.generate(count, (i) {
      final ringFraction = (i + 0.5) / count;
      final r = (startRing + (1 - startRing) * sqrt(ringFraction)) * maxSpread;
      final a =
          baseAngle +
          ringFraction * pi * 2 * 1.618 +
          (rng.nextDouble() - 0.5) * 0.5;
      return Offset(anchor.dx + cos(a) * r, anchor.dy + sin(a) * r);
    });
  }

  final trapAnchor =
      targetPos ??
      Offset(
        origin.dx + cos(baseAngle) * 120,
        origin.dy + sin(baseAngle) * 120,
      );

  switch (element) {
    case 'Air':
      // 3–25 air pads; blow back enemies on contact. Long-lived so
      // the field stays littered with pads — they're meant to be a
      // persistent maze the player can rely on.
      final count = scaledCount(12, min: 3, max: 25);
      for (final p in scatterPositions(trapAnchor, count, baseSpread: 240)) {
        projs.add(
          trap(
            pos: p,
            dmgMul: 0.45,
            life: 22.0,
            hitEffect: AbilityEffectKind.knockback,
            effectPower: 360,
            effectRadius: 86,
            radius: 1.5,
            vs: 1.6,
          ),
        );
      }
      break;

    case 'Dust':
      // Each alchemon is wrapped in a dust cloud that shields them and
      // damages enemies who collide. Per-alchemon attachment is wired
      // survival-side; this seed projectile carries the contact damage
      // and shield-radius parameters.
      projs.add(
        trap(
          pos: origin,
          dmgMul: 0.0,
          life: 9.0,
          tickEffect: AbilityEffectKind.alchemyBonus,
          effectPower: damage * 0.7,
          effectRadius: 70,
          effectDuration: 9.0,
          radius: 1.4,
          vs: 1.5,
        ),
      );
      break;

    case 'Lava':
      // 5–15 lava pools; DoT enemies in them.
      final count = scaledCount(9, min: 5, max: 15);
      for (final p in scatterPositions(trapAnchor, count, baseSpread: 220)) {
        projs.add(
          trap(
            pos: p,
            dmgMul: 0.0,
            life: 8.0,
            tickEffect: AbilityEffectKind.burn,
            effectPower: damage * 0.35,
            effectRadius: 92,
            effectDuration: 8.0,
            radius: 1.9,
            vs: 2.0,
          ),
        );
      }
      break;

    case 'Poison':
      // Scattered poison clouds; DoT in them.
      final count = scaledCount(7, min: 3, max: 12);
      for (final p in scatterPositions(trapAnchor, count, baseSpread: 210)) {
        projs.add(
          trap(
            pos: p,
            dmgMul: 0.0,
            life: 9.0,
            tickEffect: AbilityEffectKind.poison,
            effectPower: damage * 0.28,
            effectRadius: 110,
            effectDuration: 9.0,
            radius: 2.2,
            vs: 2.2,
          ),
        );
      }
      break;

    case 'Plant':
      // ONE vine. Each cast feeds the existing vine (it grows bigger);
      // survival-side detects an active Plant-mask vine and grows it
      // instead of letting new ones stack.
      projs.add(
        trap(
          pos: trapAnchor,
          dmgMul: 0.0,
          life: 30.0,
          tickEffect: AbilityEffectKind.root,
          effectPower: damage * 0.5,
          effectRadius: 90,
          effectDuration: 30.0,
          snareRadius: 90,
          snareMoveMultiplier: 0.5,
          radius: 2.4,
          vs: 2.4,
        ),
      );
      break;

    case 'Blood':
      // ONE blob; enemies passing through it are permanently drained
      // (HP leached to all alchemons until that enemy dies). Survival
      // hooks key off abilityFamily=='mask' && element=='Blood'.
      projs.add(
        trap(
          pos: trapAnchor,
          dmgMul: 0.0,
          life: 14.0,
          hitEffect: AbilityEffectKind.leech,
          effectPower: damage * 0.55,
          effectRadius: 96,
          effectDuration: 14.0,
          radius: 2.3,
          vs: 2.4,
        ),
      );
      break;

    case 'Earth':
      // 2–5 earth heal pools; heal ship/alchemons standing in them.
      final count = scaledCount(3, min: 2, max: 5);
      for (final p in scatterPositions(trapAnchor, count, baseSpread: 180)) {
        projs.add(
          trap(
            pos: p,
            dmgMul: 0.0,
            life: 12.0,
            tickEffect: AbilityEffectKind.zoneHeal,
            effectPower: damage * 0.30,
            effectRadius: 110,
            effectDuration: 12.0,
            radius: 2.4,
            vs: 2.4,
          ),
        );
      }
      break;

    case 'Light':
      // ONE light void. Persists until enemy collision → instant kill.
      projs.add(
        trap(
          pos: trapAnchor,
          dmgMul: 0.0,
          life: 18.0,
          hitEffect: AbilityEffectKind.execute,
          effectPower: 1.0,
          effectRadius: 70,
          effectDuration: 18.0,
          radius: 2.0,
          vs: 2.2,
        ),
      );
      break;

    case 'Spirit':
      // Scattered wisps. Ship collects them; threshold reached → nuke
      // all non-boss enemies. Collection + threshold are wired survival
      // side, keyed off hitEffect=flower.
      final count = scaledCount(8, min: 4, max: 14);
      for (final p in scatterPositions(trapAnchor, count, baseSpread: 230)) {
        projs.add(
          trap(
            pos: p,
            dmgMul: 0.0,
            life: 18.0,
            hitEffect: AbilityEffectKind.flower,
            effectPower: damage * 1.2,
            effectRadius: 70,
            effectDuration: 18.0,
            radius: 1.2,
            vs: 1.3,
          ),
        );
      }
      break;

    case 'Crystal':
      // 3–7 large crystals. On enemy contact each breaks into 3 smaller
      // crystals (handled survival-side via hitEffect=split + count=3).
      final count = scaledCount(5, min: 3, max: 7);
      for (final p in scatterPositions(trapAnchor, count, baseSpread: 200)) {
        projs.add(
          trap(
            pos: p,
            dmgMul: 1.0,
            life: 12.0,
            hitEffect: AbilityEffectKind.split,
            effectCount: 3,
            effectPower: damage * 0.6,
            effectRadius: 110,
            effectDuration: 4.0,
            radius: 2.4,
            vs: 2.4,
          ),
        );
      }
      break;

    case 'Fire':
      // 5–15 fire balls. On enemy collision → spawn a fire pool that
      // DoTs. Pool spawn is wired survival-side off hitEffect=burn.
      final count = scaledCount(9, min: 5, max: 15);
      for (final p in scatterPositions(trapAnchor, count, baseSpread: 220)) {
        projs.add(
          trap(
            pos: p,
            dmgMul: 0.5,
            life: 10.0,
            hitEffect: AbilityEffectKind.burn,
            effectPower: damage * 0.32,
            effectRadius: 95,
            effectDuration: 6.0,
            radius: 1.6,
            vs: 1.7,
          ),
        );
      }
      break;

    case 'Lightning':
      // ONE field that grows for each enemy that hits it. DoT.
      projs.add(
        trap(
          pos: trapAnchor,
          dmgMul: 0.0,
          life: 12.0,
          tickEffect: AbilityEffectKind.chain,
          effectPower: damage * 0.40,
          effectRadius: 110,
          effectDuration: 12.0,
          radius: 2.6,
          vs: 2.6,
        ),
      );
      break;

    case 'Steam':
      // Mini geysers around the field. Two layers of pressure:
      //   • Geyser tickEffect → on enemies in 240px radius, lifts +
      //     DoTs (the rising puff effect from the painter).
      //   • Turret shots → fires a steam bolt at the nearest enemy
      //     every ~0.95s. _maybeFireProjectileTurret is already wired
      //     into the per-frame loop; we just have to populate the
      //     turret* fields on the trap so it emits projectiles.
      final count = scaledCount(5, min: 3, max: 8);
      for (final p in scatterPositions(trapAnchor, count, baseSpread: 220)) {
        final geyser = trap(
          pos: p,
          dmgMul: 0.0,
          life: 12.0,
          tickEffect: AbilityEffectKind.geyser,
          effectPower: damage * 0.55,
          effectRadius: 240,
          effectDuration: 12.0,
          radius: 1.8,
          vs: 1.9,
        );
        // Layer turret behavior on top via _copyProjectile so the
        // turret fields propagate without losing trap markers.
        projs.add(
          _copyProjectile(
            geyser,
            turretInterval: 0.95,
            turretDamage: damage * 0.75,
            turretSpeedMultiplier: 1.15,
            turretHomingStrength: 1.6,
          ),
        );
      }
      break;

    case 'Dark':
      // ONE void hole. Enemies that enter are yeeted out of the area.
      // Suction radius scales with stats (mask scaler + here).
      projs.add(
        trap(
          pos: trapAnchor,
          dmgMul: 0.0,
          life: 9.0,
          tickEffect: AbilityEffectKind.blackHole,
          effectPower: 1.0,
          effectRadius: 240,
          effectDuration: 9.0,
          radius: 2.6,
          vs: 2.8,
        ),
      );
      break;

    case 'Ice':
      // ONE giant ice pillar. Ship/alchemons near it get a strength
      // buff (~2–5×). Ally-buff aura is wired survival-side.
      projs.add(
        trap(
          pos: trapAnchor,
          dmgMul: 0.0,
          life: 14.0,
          tickEffect: AbilityEffectKind.buff,
          effectPower: 2.0,
          effectRadius: 180,
          effectDuration: 14.0,
          radius: 2.4,
          vs: 2.6,
        ),
      );
      break;

    case 'Mud':
      // Mud pool(s) that slow enemies.
      final count = scaledCount(3, min: 1, max: 5);
      for (final p in scatterPositions(trapAnchor, count, baseSpread: 180)) {
        projs.add(
          trap(
            pos: p,
            dmgMul: 0.0,
            life: 11.0,
            tickEffect: AbilityEffectKind.slow,
            effectPower: 0.40,
            effectRadius: 120,
            effectDuration: 11.0,
            snareRadius: 120,
            snareMoveMultiplier: 0.40,
            radius: 2.6,
            vs: 2.6,
          ),
        );
      }
      break;

    case 'Water':
      // Traps; on enemy contact → splash damage to surrounding enemies.
      final count = scaledCount(6, min: 3, max: 10);
      for (final p in scatterPositions(trapAnchor, count, baseSpread: 210)) {
        projs.add(
          trap(
            pos: p,
            dmgMul: 0.5,
            life: 10.0,
            hitEffect: AbilityEffectKind.splash,
            effectPower: damage * 0.9,
            effectRadius: 110,
            effectDuration: 0.0,
            radius: 1.8,
            vs: 1.9,
          ),
        );
      }
      break;

    default:
      // Fallback: scattered generic snare traps.
      final count = scaledCount(5, min: 3, max: 8);
      for (final p in scatterPositions(trapAnchor, count, baseSpread: 200)) {
        projs.add(
          trap(
            pos: p,
            dmgMul: 0.6,
            life: 8.0,
            snareRadius: 90,
            snareMoveMultiplier: 0.6,
          ),
        );
      }
  }

  return finalize(CosmicSpecialResult(projectiles: projs));
}

// ─────────────────────────────────────────────────────────
// KIN — Blessing Pulse
// Design: Meaningful heals + orbiting orbs that actually hurt
// ─────────────────────────────────────────────────────────
CosmicSpecialResult _kinSpecial(
  Offset origin,
  double baseAngle,
  String element,
  double damage,
  int maxHp,
  double casterPower,
  double casterBeauty,
  double casterIntelligence,
  Offset? targetPos,
) {
  Projectile scaleKinProjectile(Projectile p) {
    final supportScale = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.10,
      min: 0.84,
      max: 1.20,
    );
    final visualScaleMul = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.12,
      min: 0.82,
      max: 1.22,
    );
    final controlScale = _specialStatScaleFromBaseline(
      casterIntelligence,
      perPoint: 0.12,
      min: 0.82,
      max: 1.24,
    );
    final durationScale = _specialStatScaleFromBaseline(
      casterIntelligence,
      perPoint: 0.10,
      min: 0.86,
      max: 1.18,
    );
    final trapPersistenceScale = _specialTrapPersistenceScale(
      p,
      intelligence: casterIntelligence,
    );
    return _copyProjectile(
      p,
      damage: p.damage * supportScale,
      life: p.life * durationScale * trapPersistenceScale,
      speedMultiplier: p.speedMultiplier * controlScale,
      radiusMultiplier: p.radiusMultiplier * visualScaleMul,
      homingStrength: p.homing
          ? p.homingStrength * controlScale
          : p.homingStrength,
      visualScale: p.visualScale * visualScaleMul,
      orbitSpeed: p.orbitSpeed * controlScale,
      orbitTime: p.orbitTime * durationScale * trapPersistenceScale,
      shipOrbitDelay: p.shipOrbitDelay * durationScale * trapPersistenceScale,
      shipOrbitTransferSpeed: p.shipOrbitTransferSpeed * controlScale,
      decoyHp: p.decoy ? p.decoyHp * supportScale : p.decoyHp,
      tauntRadius: p.tauntRadius * controlScale,
      tauntStrength: p.tauntStrength * controlScale,
      turretInterval: p.turretInterval > 0
          ? (p.turretInterval / controlScale).clamp(0.35, 2.0)
          : p.turretInterval,
      turretDamage: p.turretDamage * supportScale,
      turretHomingStrength: p.turretHomingStrength > 0
          ? p.turretHomingStrength * controlScale
          : p.turretHomingStrength,
      turretSpeedMultiplier: p.turretSpeedMultiplier * controlScale,
      interceptRadius: p.interceptRadius * visualScaleMul,
      snareRadius: p.snareRadius * visualScaleMul,
    );
  }

  final healScale = _specialStatScaleFromBaseline(
    casterBeauty,
    perPoint: 0.11,
    min: 0.84,
    max: 1.20,
  );
  final blessingScale = _specialStatScaleFromBaseline(
    casterBeauty,
    perPoint: 0.08,
    min: 0.86,
    max: 1.18,
  );
  final controlScale = _specialStatScaleFromBaseline(
    casterIntelligence,
    perPoint: 0.10,
    min: 0.86,
    max: 1.18,
  );

  final healAmount = (maxHp * _kinElementHealPercent(element) * healScale)
      .round();
  final shipHealAmount = switch (element) {
    'Light' => (CosmicBalance.shipMaxHealth * 0.08 * healScale).round(),
    'Water' => (CosmicBalance.shipMaxHealth * 0.05 * healScale).round(),
    'Crystal' => (CosmicBalance.shipMaxHealth * 0.03 * healScale).round(),
    'Steam' => max(1, (CosmicBalance.shipMaxHealth * 0.02 * healScale).round()),
    _ => 0,
  };
  final power = casterPower.clamp(
    CosmicBalance.minCombatStat,
    CosmicBalance.maxEffectiveStat,
  );

  final projs = _kinElementExtraProjectiles(
    origin,
    baseAngle,
    element,
    damage,
    power,
    targetPos,
  );

  return CosmicSpecialResult(
    projectiles: projs.map(scaleKinProjectile).toList(),
    selfHeal: healAmount,
    shipHeal: shipHealAmount,
    blessingTimer: _kinElementBlessingDuration(element) * controlScale,
    blessingHealPerTick:
        maxHp * _kinElementBlessingTick(element) * blessingScale,
  );
}

double _kinElementHealPercent(String e) => switch (e) {
  'Light' => 0.50,
  'Water' => 0.42,
  'Plant' => 0.38,
  'Blood' => 0.35,
  'Spirit' => 0.30,
  'Ice' => 0.28,
  'Steam' => 0.30,
  'Earth' => 0.25,
  'Crystal' => 0.25,
  'Air' => 0.22,
  'Mud' => 0.22,
  'Poison' => 0.21,
  'Fire' => 0.18,
  'Lightning' => 0.18,
  'Lava' => 0.15,
  'Dark' => 0.12,
  'Dust' => 0.18,
  _ => 0.25,
};

double _kinElementBlessingDuration(String e) => switch (e) {
  'Light' => 8.0,
  'Water' => 6.5,
  'Plant' => 6.5,
  'Spirit' => 5.5,
  'Blood' => 5.0,
  'Ice' => 5.0,
  'Earth' => 5.0,
  'Crystal' => 4.5,
  'Steam' => 4.5,
  'Mud' => 4.5,
  'Poison' => 4.0,
  'Fire' => 3.5,
  'Lightning' => 3.5,
  'Air' => 4.0,
  'Lava' => 3.5,
  'Dark' => 3.0,
  'Dust' => 4.0,
  _ => 4.0,
};

double _kinElementBlessingTick(String e) => switch (e) {
  'Light' => 0.035,
  'Water' => 0.032,
  'Plant' => 0.031,
  'Blood' => 0.028,
  'Dark' => 0.018,
  _ => 0.025,
};

int _kinEscortOrbCount(String element, double power) {
  if (element == 'Crystal') {
    if (power >= 4.5) return 4;
    if (power >= 3.0) return 3;
    return 2;
  }
  if (power >= 4.75) return 5;
  if (power >= 4.0) return 4;
  if (power >= 3.0) return 3;
  return 2;
}

double _kinEscortSpinUpDuration(double power) {
  final normalized = AlchemonStatSystem.combatProgress(power);
  return 1.2 + normalized * 0.6;
}

double _kinEscortShipDuration(double power) {
  final normalized = AlchemonStatSystem.combatProgress(power);
  return 4.5 + normalized * 3.5;
}

Offset _kinFocusPoint(
  Offset origin,
  double baseAngle,
  Offset? targetPos, {
  double distance = 150,
}) {
  return targetPos ??
      Offset(
        origin.dx + cos(baseAngle) * distance,
        origin.dy + sin(baseAngle) * distance,
      );
}

List<Projectile> _kinStagedOrbitals({
  required int count,
  required Offset origin,
  required String element,
  required double damage,
  required double orbitRadius,
  required double orbitSpeed,
  required double spinUp,
  required double activeDuration,
  bool transferToShipOrbit = false,
  Offset? transferOrbitCenter,
  double transferSpeed = 1.0,
  bool homing = false,
  double homingStrength = 0,
  double speedMultiplier = 1.0,
  double radiusMultiplier = 1.4,
  double visualScale = 1.2,
  bool piercing = false,
  bool decoy = false,
  double decoyHp = 0,
  double tauntRadius = 0,
  double tauntStrength = 0,
  double snareRadius = 0,
  double snareMoveMultiplier = 1.0,
  double turretInterval = 0,
  double turretDamage = 0,
  double turretHomingStrength = 0,
  double turretSpeedMultiplier = 1.0,
  double interceptRadius = 0,
  int interceptCharges = 0,
  // Tick-effect aura: while the orb orbits, it ticks the given effect
  // on enemies in effectRadius. Used by per-element signatures
  // (Dark = pull, Spirit = execute, Blood = leech, etc.) to give
  // each kin a distinctive niche.
  AbilityEffectKind tickEffect = AbilityEffectKind.none,
  double effectPower = 0,
  double effectRadius = 0,
  double effectDuration = 0,
  int effectCount = 0,
}) {
  return List.generate(count, (i) {
    final a = i * (pi * 2 / count);
    return Projectile(
      position: Offset(
        origin.dx + cos(a) * orbitRadius,
        origin.dy + sin(a) * orbitRadius,
      ),
      angle: a,
      element: element,
      damage: damage,
      life: spinUp + activeDuration + 1.25,
      orbitCenter: origin,
      orbitAngle: a,
      orbitRadius: orbitRadius,
      orbitSpeed: orbitSpeed,
      orbitTime: spinUp + activeDuration,
      transferToShipOrbit: transferToShipOrbit,
      shipOrbitDelay: spinUp,
      transferOrbitCenter: transferOrbitCenter,
      holdOrbit: true,
      shipOrbitTransferSpeed: transferSpeed,
      homing: homing,
      homingStrength: homingStrength,
      speedMultiplier: speedMultiplier,
      radiusMultiplier: radiusMultiplier,
      visualScale: visualScale,
      piercing: piercing,
      decoy: decoy,
      decoyHp: decoyHp,
      tauntRadius: tauntRadius,
      tauntStrength: tauntStrength,
      snareRadius: snareRadius,
      snareMoveMultiplier: snareMoveMultiplier,
      turretInterval: turretInterval,
      turretDamage: turretDamage,
      turretHomingStrength: turretHomingStrength,
      turretSpeedMultiplier: turretSpeedMultiplier,
      interceptRadius: interceptRadius,
      interceptCharges: interceptCharges,
      tickEffect: tickEffect,
      effectPower: effectPower,
      effectRadius: effectRadius,
      effectDuration: effectDuration,
      effectCount: effectCount,
      abilityFamily: 'kin',
      visualStyle: ProjectileVisualStyle.kinOrbital,
    );
  });
}

// A stationary kin "ward": a placed construct that emanates its
// tickEffect (heal / leech / CC / DoT) over allies or enemies in radius
// through the aura-tick system. Distinct from mystic orbs and mask
// decoys — a ward holds ground rather than chasing.
Projectile _kinGroundWard({
  required Offset position,
  required String element,
  required AbilityEffectKind tickEffect,
  required double effectRadius,
  required double effectPower,
  required double duration,
  double effectDuration = 1.0,
  int effectCount = 0,
  double contactDamage = 0,
  double visualScale = 1.6,
  // sigil routes the ward through the rich per-element ground-zone
  // renderer (poison pool, ice field, dark void, etc.).
  ProjectileVisualStyle visualStyle = ProjectileVisualStyle.sigil,
  // -2 = none, -1 = follow ship, >=0 = follow companion slot.
  // Used by ship-attached kin auras (Water rain cloud, Air updraft)
  // so the ward moves with the ship every frame.
  int attachedToSlot = -2,
}) {
  return Projectile(
    position: position,
    angle: 0,
    element: element,
    damage: contactDamage,
    life: duration,
    speedMultiplier: 0,
    stationary: true,
    piercing: true,
    // Collision radius stays tiny: a ward's reach is its aura
    // (effectRadius), not a contact hitbox. This keeps a damage-0 zone
    // from spamming per-frame hit sparks on every enemy standing in it.
    radiusMultiplier: 1.0,
    visualScale: visualScale,
    visualStyle: visualStyle,
    abilityFamily: 'kin',
    tickEffect: tickEffect,
    effectPower: effectPower,
    effectRadius: effectRadius,
    effectDuration: effectDuration,
    effectCount: effectCount,
    attachedToSlot: attachedToSlot,
  );
}

List<Projectile> _kinElementExtraProjectiles(
  Offset origin,
  double baseAngle,
  String element,
  double damage,
  double power,
  Offset? targetPos,
) {
  // _kinFocusPoint helper retained for future per-element placements;
  // all current support paths spawn at origin (ship-attached or
  // caster-footed) or are wired survival-side.
  final longSpin = _kinEscortSpinUpDuration(power);
  final longEscort = _kinEscortShipDuration(power);
  // mediumDuration kept for the remaining ward-style cases.
  // ignore: unused_local_variable
  final mediumDuration = 3.8 + AlchemonStatSystem.combatProgress(power) * 2.6;
  // ignore: unused_local_variable
  final target = _kinFocusPoint(origin, baseAngle, targetPos);
  switch (element) {
    case 'Light':
      // Signature: cleansing aura. Light orbs ship-escort with
      // intercept shields AND continuously heal the ship/orb in
      // their path — pure support identity.
      return _kinStagedOrbitals(
        count: _kinEscortOrbCount(element, power),
        origin: origin,
        element: element,
        damage: damage * 0.9,
        orbitRadius: 82.0,
        orbitSpeed: 2.2,
        spinUp: longSpin,
        activeDuration: longEscort,
        transferToShipOrbit: true,
        transferSpeed: 0.85,
        radiusMultiplier: 1.9,
        visualScale: 1.2,
        interceptRadius: 18.0,
        interceptCharges: 1,
        tickEffect: AbilityEffectKind.zoneHeal,
        effectPower: damage * 0.22,
        effectRadius: 70,
        effectDuration: 0.6,
      );
    case 'Dark':
      // Signature: Void Cloak — companions become untargetable.
      // No projectiles; the buff timer is set survival-side at cast.
      return const [];
    case 'Crystal':
      // Signature: Prismatic Refractors. Spawns N orbital shards that
      // orbit the ship, each loaded with intercept charges. When a
      // shard intercepts an enemy projectile it also fires a
      // refracted damaging beam back at the sender (reflect-on-hit).
      // No turrets, no splash — pure defensive counter.
      return _kinStagedOrbitals(
        count: _kinEscortOrbCount(element, power),
        origin: origin,
        element: element,
        damage: damage * 0.5,
        orbitRadius: 78.0,
        orbitSpeed: 2.6,
        spinUp: longSpin - 0.15,
        activeDuration: longEscort,
        transferToShipOrbit: true,
        transferSpeed: 1.0,
        radiusMultiplier: 1.6,
        visualScale: 1.25,
        piercing: true,
        interceptRadius: 32.0,
        interceptCharges: 4,
      );
    case 'Air':
      // Signature: Updraft Column — a moving cyclone attached to the
      // SHIP. Enemies that try to close on the ship are lifted up and
      // flung outward by the rising winds. Anti-melee bubble that
      // travels with the player.
      return [
        _kinGroundWard(
          position: origin,
          element: element,
          tickEffect: AbilityEffectKind.knockback,
          effectRadius: 110.0,
          effectPower: damage * 0.26,
          duration: mediumDuration + 1.0,
          effectDuration: 0.18,
          visualScale: 2.0,
          attachedToSlot: -1, // follow the ship
        ),
      ];
    case 'Fire':
      // Signature: Phoenix Guard. If the orb dies during the buff
      // window, it's saved at ~25% HP and the fire kin gains an
      // orbiting flame that damages nearby enemies. No projectiles
      // here — guard timer is set survival-side at cast.
      return const [];
    case 'Water':
      // Signature: Rain Cloud — moving healing cloud attached to the
      // SHIP. Nerfed: smaller heal-per-tick and shorter duration so
      // the cloud is a meaningful support window, not permanent
      // background regen.
      return [
        _kinGroundWard(
          position: origin,
          element: element,
          tickEffect: AbilityEffectKind.zoneHeal,
          effectRadius: 100.0,
          effectPower: damage * 0.14,
          duration: longEscort - 1.5,
          visualScale: 1.8,
          attachedToSlot: -1, // follow the ship
        ),
      ];
    case 'Ice':
      // Signature: Charged Frost. Kin enters a charge windup; on
      // release, a 360° frost burst applies a 90% slow to every
      // enemy in range. Range scales to global at max stats. No
      // projectiles here — charge is started survival-side at cast.
      return const [];
    case 'Steam':
      // Signature: Boiler. Damage taken by ship/allies converts into
      // stacking companion attack-speed (max 10 stacks). No projectiles
      // here — buff window timer is set survival-side at cast.
      return const [];
    case 'Earth':
      // Signature: Stone Barrier — a curved arc of indestructible
      // wall segments around the ORB (handled survival-side so the
      // arc can center on the live orb position). Returns empty
      // here; spawn is wired in _activateKinSupportPath.
      return const [];
    case 'Mud':
      // Signature: Mud-Splattered Ship. Slings mud onto the ship,
      // granting it a temporary buff that leaves a slowing mud trail
      // as it moves. Ship enchant timer set survival-side at cast.
      return const [];
    case 'Dust':
      // Signature: Field-placed Dust Clouds. First cast plants one
      // cloud at the target; subsequent casts add more (additive,
      // persistent). Projectiles passing through any cloud have a
      // chance to miss. Spawn is handled survival-side at cast.
      return const [];
    case 'Lightning':
      // Signature: Tesla Charge. While the kin actively channels, all
      // companions' auto-attacks chain to nearby enemies. Charge
      // duration equals buff duration (1:1). Charge phase started
      // survival-side at cast.
      return const [];
    case 'Plant':
      // Signature: Healing Garden. Nerfed: smaller radius, weaker
      // per-tick heal, shorter duration. Flower drop cadence is
      // tuned down survival-side too so harvest pace is gated.
      return [
        _kinGroundWard(
          position: origin,
          element: element,
          tickEffect: AbilityEffectKind.zoneHeal,
          effectRadius: 100.0,
          effectPower: damage * 0.12,
          duration: longEscort - 2.0,
          visualScale: 1.7,
          // Marker for periodic flower spawn survival-side.
          effectCount: 1,
        ),
      ];
    case 'Poison':
      // Signature: Venom Swirl — a radial burst of homing poison darts
      // fired in all directions from the caster. Each dart seeks a
      // nearby enemy and applies stacking poison on hit.
      final dartCount =
          8 + (AlchemonStatSystem.combatProgress(power) * 8).round();
      return List.generate(dartCount, (i) {
        final a = i * (pi * 2 / dartCount);
        return Projectile(
          position: Offset(origin.dx + cos(a) * 18, origin.dy + sin(a) * 18),
          angle: a,
          element: element,
          damage: damage * 0.55,
          life: 2.6,
          speedMultiplier: 0.95,
          radiusMultiplier: 1.4,
          visualScale: 1.1,
          piercing: true,
          homing: true,
          homingStrength: 3.6,
          visualStyle: ProjectileVisualStyle.sigil,
          abilityFamily: 'kin',
          hitEffect: AbilityEffectKind.poison,
          effectPower: damage * 0.30,
          effectRadius: 1, // direct apply, no aoe
          effectDuration: 4.0,
        );
      });
    case 'Spirit':
      // Signature: Wisp Companion. Releases a growing wisp that
      // tiers up off enemies the Spirit kin's auto-attacks kill.
      // Wisp + tier progression handled survival-side at cast +
      // per-frame.
      return const [];
    case 'Lava':
      // Signature: Molten Plate. Ship + companions gain reactive
      // armor — when hit, splash burning lava back at attacker.
      // Timer set survival-side at cast.
      return const [];
    case 'Blood':
      // Signature: Blood Pact. While active, % of damage taken by any
      // alchemon is converted into healing distributed across the
      // other living alchemons. Timer set survival-side at cast.
      return const [];
    default:
      return const [];
  }
}

// ─────────────────────────────────────────────────────────
// MYSTIC — Orbital Storm
// Design: Spiraling orbs that hurt AND seek enemies
// ─────────────────────────────────────────────────────────
CosmicSpecialResult _mysticSpecial(
  Offset origin,
  double baseAngle,
  String element,
  double damage,
  double casterBeauty,
  double casterIntelligence,
  double casterStrength,
) {
  Projectile orb({
    required double angle,
    required double orbitRadius,
    required double damageMultiplier,
    required double life,
    required double orbitSpeed,
    required double orbitTime,
    required double homingStrength,
    required double speedMultiplier,
    required double radiusMultiplier,
    required double visualScale,
    bool piercing = false,
    int bounceCount = 0,
    double trailInterval = 0,
    double trailDamageMultiplier = 0,
    double trailLife = 0,
    int clusterCount = 0,
    double clusterDamageMultiplier = 0,
    double snareRadius = 0,
    double snareMoveMultiplier = 1.0,
    ProjectileVisualStyle visualStyle = ProjectileVisualStyle.mysticOrbital,
  }) {
    return Projectile(
      position: Offset(
        origin.dx + cos(angle) * orbitRadius,
        origin.dy + sin(angle) * orbitRadius,
      ),
      angle: angle,
      element: element,
      damage: damage * damageMultiplier,
      life: life,
      orbitCenter: origin,
      orbitAngle: angle,
      orbitRadius: orbitRadius,
      orbitSpeed: orbitSpeed,
      orbitTime: orbitTime,
      homing: true,
      homingStrength: homingStrength,
      piercing: piercing,
      bounceCount: bounceCount,
      speedMultiplier: speedMultiplier,
      radiusMultiplier: radiusMultiplier,
      visualScale: visualScale,
      visualStyle: visualStyle,
      trailInterval: trailInterval,
      trailDamage: damage * trailDamageMultiplier,
      trailLife: trailLife,
      clusterCount: clusterCount,
      clusterDamage: damage * clusterDamageMultiplier,
      snareRadius: snareRadius,
      snareMoveMultiplier: snareMoveMultiplier,
    );
  }

  List<Projectile> sequence(
    List<double> radii, {
    double startAngle = 0,
    double? phaseStep,
    required double damageMultiplier,
    required double life,
    required double orbitSpeed,
    required double orbitTime,
    required double homingStrength,
    required double speedMultiplier,
    required double radiusMultiplier,
    required double visualScale,
    bool piercing = false,
    int bounceCount = 0,
    double trailInterval = 0,
    double trailDamageMultiplier = 0,
    double trailLife = 0,
    int clusterCount = 0,
    double clusterDamageMultiplier = 0,
    double snareRadius = 0,
    double snareMoveMultiplier = 1.0,
    ProjectileVisualStyle visualStyle = ProjectileVisualStyle.mysticOrbital,
  }) {
    final step =
        phaseStep ?? (radii.isEmpty ? 0.0 : (pi * 2) / max(1, radii.length));
    return List.generate(radii.length, (i) {
      return orb(
        angle: startAngle + i * step,
        orbitRadius: radii[i],
        damageMultiplier: damageMultiplier,
        life: life,
        orbitSpeed: orbitSpeed,
        orbitTime: orbitTime,
        homingStrength: homingStrength,
        speedMultiplier: speedMultiplier,
        radiusMultiplier: radiusMultiplier,
        visualScale: visualScale,
        piercing: piercing,
        bounceCount: bounceCount,
        trailInterval: trailInterval,
        trailDamageMultiplier: trailDamageMultiplier,
        trailLife: trailLife,
        clusterCount: clusterCount,
        clusterDamageMultiplier: clusterDamageMultiplier,
        snareRadius: snareRadius,
        snareMoveMultiplier: snareMoveMultiplier,
        visualStyle: visualStyle,
      );
    });
  }

  Projectile scaleMysticProjectile(Projectile p, {bool isCore = false}) {
    const mysticVisualBoost = 1.265;
    final impactScale = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.12,
      min: 0.84,
      max: 1.24,
    );
    final visualScaleMul = _specialStatScaleFromBaseline(
      casterBeauty,
      perPoint: 0.16,
      min: 0.82,
      max: 1.28,
    );
    final controlScale = _specialStatScaleFromBaseline(
      casterIntelligence,
      perPoint: 0.14,
      min: 0.82,
      max: 1.28,
    );
    final durationScale = _specialStatScaleFromBaseline(
      casterIntelligence,
      perPoint: 0.10,
      min: 0.86,
      max: 1.20,
    );
    final clusterScale = _specialCountScaleFromBaseline(
      casterBeauty,
      casterIntelligence,
      beautyPerPoint: 0.05,
      intelligencePerPoint: 0.08,
      min: 0.80,
      max: 1.24,
    );
    final trapPersistenceScale = _specialTrapPersistenceScale(
      p,
      intelligence: casterIntelligence,
    );
    // Mystics are environment-changing ultimates with long cooldowns.
    // Their effects should LAST — stretch lifetimes so a single cast
    // paints the field for 15–30s instead of 5–10s.
    final lifetimeStretch = _specialStatScaleFromBaseline(
      casterIntelligence,
      perPoint: 0.18,
      min: 2.4,
      max: 4.2,
    );
    // Cap lifetimes at 30s for environment-changing effects. min(...)
    // avoids the clamp-bounds ordering issue when stat scaling already
    // pushes the base above 30s.
    final stretchedLife = min(
      30.0,
      p.life * durationScale * trapPersistenceScale * lifetimeStretch,
    );
    final stretchedOrbitTime = min(
      30.0,
      p.orbitTime * durationScale * trapPersistenceScale * lifetimeStretch,
    );
    final stretchedTrailLife = p.trailLife > 0
        ? min(12.0, p.trailLife * durationScale * lifetimeStretch)
        : p.trailLife;
    return _copyProjectile(
      p,
      damage: p.damage * impactScale * (isCore ? 1.08 : 1.0),
      life: stretchedLife,
      speedMultiplier: p.speedMultiplier * controlScale,
      radiusMultiplier: p.radiusMultiplier * visualScaleMul * 1.08,
      homingStrength: p.homingStrength * controlScale,
      visualScale:
          (p.visualScale *
                  visualScaleMul *
                  1.14 *
                  mysticVisualBoost *
                  (isCore ? 1.08 : 1.0))
              .clamp(0.95, 5.1),
      orbitSpeed: p.orbitSpeed * controlScale,
      orbitTime: stretchedOrbitTime,
      bounceCount: p.bounceCount > 0
          ? (p.bounceCount * clusterScale).round().clamp(0, 5)
          : p.bounceCount,
      trailInterval: p.trailInterval > 0
          ? (p.trailInterval / controlScale).clamp(0.05, 0.30)
          : p.trailInterval,
      trailDamage: p.trailDamage * impactScale,
      trailLife: stretchedTrailLife,
      clusterCount: p.clusterCount > 0
          ? (p.clusterCount * clusterScale).round().clamp(0, 8)
          : p.clusterCount,
      clusterDamage: p.clusterDamage * impactScale,
      snareRadius: p.snareRadius * visualScaleMul,
    );
  }

  // Stat-driven projectile count scaling. Each element uses the stat that
  // best fits its fantasy (beauty → spectacle, intelligence → precision,
  // strength → brute force). Baseline 4.0 — below = fewer, above = more.
  int scaledCount(
    double stat,
    int base, {
    int min = 2,
    int max = 20,
    double perPoint = 1.0,
  }) {
    final clamped = AlchemonStatSystem.legacyGameplayRating(stat);
    return (base + (clamped - 4.0) * perPoint).round().clamp(min, max);
  }

  final projs = <Projectile>[];
  var selfHeal = 0;
  var shipHeal = 0;
  var blessingTimer = 0.0;
  var blessingHealPerTick = 0.0;
  switch (element) {
    // ── FIRE: Sacred Pyre ──
    // Persistent fire field — a ring of stationary fire pillars
    // burning around the cast point, plus the original blast orbs
    // that charge and home back. The pillars are the environment
    // commitment; the orbs are the spectacle layer.
    // Beauty drives spectacle (orb count); Intelligence drives field
    // size (pillar count).
    case 'Fire':
      // Stationary fire pillars — the persistent environment.
      final pillarCount = scaledCount(casterIntelligence, 6, min: 5, max: 9);
      for (var i = 0; i < pillarCount; i++) {
        final a = i * (pi * 2 / pillarCount);
        final pos = Offset(origin.dx + cos(a) * 95, origin.dy + sin(a) * 95);
        projs.add(
          Projectile(
            position: pos,
            angle: a,
            element: element,
            damage: damage * 0.95,
            life: 11.0,
            stationary: true,
            radiusMultiplier: 2.1,
            visualScale: 2.0,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            piercing: true,
            snareRadius: 80.0,
            snareMoveMultiplier: 0.55,
            tickEffect: AbilityEffectKind.burn,
            effectPower: damage * 0.42,
            effectRadius: 90,
            effectDuration: 1.5,
          ),
        );
      }
      // Ring blast orbs — opening salvo that charges then homes.
      final ringCount = scaledCount(casterBeauty, 6, min: 4, max: 9);
      for (var i = 0; i < ringCount; i++) {
        final a = baseAngle + i * (pi * 2 / ringCount);
        projs.add(
          orb(
            angle: a,
            orbitRadius: 22,
            damageMultiplier: 1.8,
            life: 6.2,
            orbitSpeed: 8.0,
            orbitTime: 1.0,
            homingStrength: 5.8,
            speedMultiplier: 1.7,
            radiusMultiplier: 1.8,
            visualScale: 1.4,
            trailInterval: 0.10,
            trailDamageMultiplier: 0.7,
            trailLife: 0.8,
          ),
        );
      }
      // Core detonation orb — pulses at center, fires after the ring.
      projs.add(
        orb(
          angle: baseAngle,
          orbitRadius: 0,
          damageMultiplier: 3.5,
          life: 6.5,
          orbitSpeed: 0,
          orbitTime: 4.0,
          homingStrength: 2.0,
          speedMultiplier: 0.3,
          radiusMultiplier: 3.2,
          visualScale: 2.8,
          clusterCount: 6,
          clusterDamageMultiplier: 0.8,
        ),
      );
      break;

    // ── LAVA: Cataclysm Moons ──
    // Massive slow-moving piercing boulders that drop persistent magma
    // pools along their path (turret-spawned every 0.45s). Each
    // boulder paints a long lava furrow across the field that lasts
    // ~30s after the boulders are gone.
    // Strength drives boulder count (brute force).
    case 'Lava':
      final boulderCount = scaledCount(casterStrength, 3, min: 2, max: 4);
      for (var i = 0; i < boulderCount; i++) {
        final a = baseAngle + (i - (boulderCount - 1) / 2) * 0.4;
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 20, origin.dy + sin(a) * 20),
            angle: a,
            element: element,
            damage: damage * 3.2,
            life: 8.0,
            speedMultiplier: 0.35,
            radiusMultiplier: 3.5,
            visualScale: 3.0,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            piercing: true,
            // Drop persistent magma pools along the boulder's path
            // every 0.75s (slowed from 0.45s so the field isn't
            // drowned in dozens of overlapping pools).
            turretInterval: 0.75,
            turretDamage: damage * 1.05,
            // Cluster on impact so the boulder also explodes when it
            // finally hits a wall of enemies.
            clusterCount: 4,
            clusterDamage: damage * 1.0,
            // Heavy trail for visual continuity between drops.
            trailInterval: 0.10,
            trailDamage: damage * 0.8,
            trailLife: 2.0,
          ),
        );
      }
      break;

    // ── LIGHTNING: Storm Lattice ──
    // Persistent thunderstorm. Stationary lightning rods planted in a
    // ring around the target — each rod periodically fires chain
    // lightning at the nearest enemy. The whole lattice arcs together
    // for the storm's duration. Plus initial salvo of bouncing bolts.
    // Intelligence drives rod count (storm pattern).
    case 'Lightning':
      final stormCenter = Offset(
        origin.dx + cos(baseAngle) * 100,
        origin.dy + sin(baseAngle) * 100,
      );
      final rodCount = scaledCount(casterIntelligence, 6, min: 4, max: 9);
      for (var i = 0; i < rodCount; i++) {
        final a = i * (pi * 2 / rodCount);
        final pos = Offset(
          stormCenter.dx + cos(a) * 120,
          stormCenter.dy + sin(a) * 120,
        );
        projs.add(
          Projectile(
            position: pos,
            angle: a,
            element: element,
            damage: damage * 1.0,
            life: 11.0,
            stationary: true,
            radiusMultiplier: 1.7,
            visualScale: 1.7,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            piercing: true,
            // Each rod fires a chain-lightning shot every ~0.8s.
            turretInterval: 0.80,
            turretDamage: damage * 1.55,
            turretHomingStrength: 5.0,
            turretSpeedMultiplier: 1.55,
            tickEffect: AbilityEffectKind.chain,
            effectPower: damage * 0.45,
            effectRadius: 120,
            effectDuration: 0.6,
            effectCount: 3,
          ),
        );
      }
      // Initial bounce salvo — opens the storm with a flash of bolts.
      final boltCount = scaledCount(casterIntelligence, 6, min: 4, max: 9);
      for (var i = 0; i < boltCount; i++) {
        final a = baseAngle + (i - (boltCount - 1) / 2) * 0.16;
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 14, origin.dy + sin(a) * 14),
            angle: a,
            element: element,
            damage: damage * 1.25,
            life: 3.0,
            speedMultiplier: 2.8,
            radiusMultiplier: 1.1,
            visualScale: 1.08,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            homing: true,
            homingStrength: 3.2,
            bounceCount: 5,
          ),
        );
      }
      break;

    // ── WATER: Tidal Crescent Rite ──
    // Two crescent waves converge on target, leaving a persistent
    // tidepool at the meeting point that heals allies, slows enemies,
    // and ticks splash damage across its full life. The waves are
    // the spectacle; the tidepool is the environment commitment.
    // Beauty drives wave density (elegant spectacle).
    case 'Water':
      final waveTarget = Offset(
        origin.dx + cos(baseAngle) * 110,
        origin.dy + sin(baseAngle) * 110,
      );
      // Persistent tidepool at convergence point.
      projs.add(
        Projectile(
          position: waveTarget,
          angle: 0,
          element: element,
          damage: damage * 1.05,
          life: 11.0,
          stationary: true,
          radiusMultiplier: 3.2,
          visualScale: 2.8,
          visualStyle: ProjectileVisualStyle.mysticOrbital,
          piercing: true,
          snareRadius: 145.0,
          snareMoveMultiplier: 0.45,
          tickEffect: AbilityEffectKind.splash,
          effectPower: damage * 0.42,
          effectRadius: 145,
          effectDuration: 1.2,
        ),
      );
      // Crescent wave sets — homing arcs that converge on target.
      final waveCount = scaledCount(casterBeauty, 4, min: 3, max: 6);
      for (var side = -1; side <= 1; side += 2) {
        for (var i = 0; i < waveCount; i++) {
          final sweep = side * (0.6 + i * 0.12);
          final a = baseAngle + sweep;
          projs.add(
            Projectile(
              position: Offset(
                origin.dx + cos(a) * (20 + i * 8),
                origin.dy + sin(a) * (20 + i * 8),
              ),
              angle: a - side * 0.3,
              element: element,
              damage: damage * 1.6,
              life: 6.0,
              speedMultiplier: 1.15,
              radiusMultiplier: 1.9,
              visualScale: 1.4,
              visualStyle: ProjectileVisualStyle.mysticOrbital,
              homing: true,
              homingStrength: 3.8,
              trailInterval: 0.16,
              trailDamage: damage * 0.6,
              trailLife: 2.0,
            ),
          );
        }
      }
      // Tidepool heals allies via small ship-blessing.
      shipHeal = max(
        shipHeal,
        max(1, (CosmicBalance.shipMaxHealth * 0.025).round()),
      );
      blessingTimer = max(blessingTimer, 5.0);
      blessingHealPerTick = max(blessingHealPerTick, damage * 0.04);
      break;

    // ── ICE: Glacier Crown ──
    // Persistent glacier formation. Inner pillars stay planted as a
    // permanent ice fortification (snare + freeze tick). Outer
    // pillars launch outward as piercing lances after a brief hold.
    // The fortification is the environment commitment; the lances
    // are the spectacle.
    // Intelligence drives pillar count (crystalline geometry).
    case 'Ice':
      final innerPillarCount = scaledCount(
        casterIntelligence,
        5,
        min: 4,
        max: 7,
      );
      // Inner permanent pillars — stationary frost field.
      for (var i = 0; i < innerPillarCount; i++) {
        final a = i * (pi * 2 / innerPillarCount);
        final pos = Offset(origin.dx + cos(a) * 60, origin.dy + sin(a) * 60);
        projs.add(
          Projectile(
            position: pos,
            angle: a,
            element: element,
            damage: damage * 1.2,
            life: 11.0,
            stationary: true,
            radiusMultiplier: 2.6,
            visualScale: 2.4,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            piercing: true,
            snareRadius: 100.0,
            snareMoveMultiplier: 0.18,
            tickEffect: AbilityEffectKind.freeze,
            effectPower: damage * 0.30,
            effectRadius: 100,
            effectDuration: 1.2,
          ),
        );
      }
      // Outer launching lances — the spectacle layer.
      final lanceCount = scaledCount(casterIntelligence, 4, min: 3, max: 6);
      for (var i = 0; i < lanceCount; i++) {
        final a = baseAngle + i * (pi * 2 / lanceCount);
        projs.add(
          orb(
            angle: a,
            orbitRadius: 44,
            damageMultiplier: 2.2,
            life: 7.0,
            orbitSpeed: 1.2,
            orbitTime: 2.8,
            homingStrength: 4.5,
            speedMultiplier: 1.8,
            radiusMultiplier: 2.0,
            visualScale: 1.8,
            piercing: true,
            clusterCount: 3,
            clusterDamageMultiplier: 0.7,
          ),
        );
      }
      break;

    // ── STEAM: Whiteout Veil ──
    // Dense fog zone: stationary snare cloud at target + turret orbs that
    // fire from within the fog. Area denial + sustained damage.
    // Intelligence drives fog node + turret count (control mastery).
    case 'Steam':
      final fogCenter = Offset(
        origin.dx + cos(baseAngle) * 100,
        origin.dy + sin(baseAngle) * 100,
      );
      // Fog cloud nodes — stationary snare zones
      final fogNodeCount = scaledCount(casterIntelligence, 3, min: 2, max: 5);
      for (var i = 0; i < fogNodeCount; i++) {
        final a = i * (pi * 2 / fogNodeCount);
        projs.add(
          Projectile(
            position: Offset(
              fogCenter.dx + cos(a) * 30,
              fogCenter.dy + sin(a) * 30,
            ),
            angle: a,
            element: element,
            damage: damage * 0.95,
            life: 9.0,
            stationary: true,
            radiusMultiplier: 2.8,
            visualScale: 2.35,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            snareRadius: 152.0,
            snareMoveMultiplier: 0.18,
          ),
        );
      }
      // Turret orbs — orbit inside the fog, firing at enemies
      final turretCount = scaledCount(casterIntelligence, 2, min: 1, max: 4);
      for (var i = 0; i < turretCount; i++) {
        final a = baseAngle + i * (pi * 2 / turretCount);
        projs.add(
          Projectile(
            position: fogCenter,
            angle: a,
            element: element,
            damage: damage * 1.35,
            life: 9.0,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            visualScale: 1.2,
            radiusMultiplier: 1.4,
            orbitCenter: fogCenter,
            orbitAngle: a,
            orbitRadius: 36,
            orbitSpeed: 3.5,
            holdOrbit: true,
            turretInterval: 0.65,
            turretDamage: damage * 1.75,
            turretHomingStrength: 4.0,
            turretSpeedMultiplier: 1.4,
          ),
        );
      }
      shipHeal = max(1, (CosmicBalance.shipMaxHealth * 0.03).round());
      blessingTimer = 2.8;
      blessingHealPerTick = 0.08;
      break;

    // ── EARTH: Monolith Constellation ──
    // 4 massive orbiting decoy pillars that taunt enemies. When destroyed
    // they explode into shrapnel. Defensive powerhouse.
    // Strength drives pillar count (massive stone constructs).
    case 'Earth':
      final monolithCount = scaledCount(casterStrength, 3, min: 2, max: 5);
      for (var i = 0; i < monolithCount; i++) {
        final a = baseAngle + i * (pi * 2 / monolithCount);
        projs.add(
          orb(
            angle: a,
            orbitRadius: 55,
            damageMultiplier: 1.5,
            life: 11.0,
            orbitSpeed: 2.2,
            orbitTime: 99, // permanent orbit (holdOrbit)
            homingStrength: 0,
            speedMultiplier: 0,
            radiusMultiplier: 3.0,
            visualScale: 2.5,
          ),
        );
        // Override with decoy properties (can't use orb helper for these)
        final last = projs.removeLast();
        projs.add(
          Projectile(
            position: last.position,
            angle: last.angle,
            element: element,
            damage: last.damage,
            life: 11.0,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            visualScale: 2.5,
            radiusMultiplier: 3.0,
            orbitCenter: origin,
            orbitAngle: a,
            orbitRadius: 55,
            orbitSpeed: 2.2,
            holdOrbit: true,
            // Monoliths follow the ship as it moves so they protect
            // the player's live position, not the cast point.
            followShipOrbit: true,
            decoy: true,
            decoyHp: 26,
            deathExplosionCount: 8,
            deathExplosionDamage: damage * 2.0,
            deathExplosionRadius: 2.0,
            tauntRadius: 440.0,
            tauntStrength: 4.3,
          ),
        );
      }
      break;

    // ── MUD: Mire Eclipse ──
    // Sticky snare zone at target + aggressive homing chasers that leave
    // persistent slowing trails behind them. Locks down an area.
    // Strength drives slug count (brute force chasers).
    case 'Mud':
      final mireCenter = Offset(
        origin.dx + cos(baseAngle) * 90,
        origin.dy + sin(baseAngle) * 90,
      );
      // Central mire — massive stationary snare
      projs.add(
        Projectile(
          position: mireCenter,
          angle: 0,
          element: element,
          damage: damage * 0.9,
          life: 9.0,
          stationary: true,
          radiusMultiplier: 3.5,
          visualScale: 3.0,
          visualStyle: ProjectileVisualStyle.mysticOrbital,
          snareRadius: 160.0,
          snareMoveMultiplier: 0.12,
        ),
      );
      // Pursuing mud slugs — heavy homing with snare trails. Life
      // shortened so they detonate close instead of leashing off the
      // map. Speed bumped + bounce cap so they zig back into combat.
      final slugCount = scaledCount(casterStrength, 4, min: 2, max: 6);
      for (var i = 0; i < slugCount; i++) {
        final a = baseAngle + (i - (slugCount - 1) / 2) * 0.35;
        projs.add(
          Projectile(
            position: Offset(
              mireCenter.dx + cos(a) * 20,
              mireCenter.dy + sin(a) * 20,
            ),
            angle: a,
            element: element,
            damage: damage * 1.7,
            life: 3.8,
            speedMultiplier: 0.80,
            radiusMultiplier: 2.0,
            visualScale: 1.6,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            homing: true,
            homingStrength: 5.5,
            piercing: true,
            bounceCount: 2,
            trailInterval: 0.20,
            trailDamage: damage * 0.5,
            trailLife: 4.0,
            snareRadius: 90.0,
            snareMoveMultiplier: 0.30,
          ),
        );
      }
      break;

    // ── DUST: Sirocco Halo ──
    // A wide sandstorm zone — central vortex that pulls enemies and
    // disorients shooters, plus golden-spiral swarm of stinging dust
    // motes. The storm zone IS the environment change; the swarm is
    // the spectacle layer that cleans up survivors.
    // Beauty drives swarm density, Intelligence drives storm radius.
    case 'Dust':
      final stormCenter = Offset(
        origin.dx + cos(baseAngle) * 80,
        origin.dy + sin(baseAngle) * 80,
      );
      // Central sandstorm zone — disorient + slow, persistent.
      projs.add(
        Projectile(
          position: stormCenter,
          angle: 0,
          element: element,
          damage: damage * 0.85,
          life: 11.0,
          stationary: true,
          radiusMultiplier: 4.0,
          visualScale: 3.4,
          visualStyle: ProjectileVisualStyle.mysticOrbital,
          piercing: true,
          snareRadius: 175.0,
          snareMoveMultiplier: 0.45,
          tickEffect: AbilityEffectKind.suppressShooting,
          effectPower: damage * 0.30,
          effectRadius: 175,
          effectDuration: 1.4,
        ),
      );
      // Golden-spiral mote swarm sweeping outward across the storm.
      final swarmCount = scaledCount(
        casterBeauty,
        14,
        min: 10,
        max: 22,
        perPoint: 2.0,
      );
      for (var i = 0; i < swarmCount; i++) {
        final a = baseAngle + i * (pi * 2 / swarmCount) * 1.618;
        final r = 12.0 + i * 3.0;
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * r, origin.dy + sin(a) * r),
            angle: a,
            element: element,
            damage: damage * 0.75,
            life: 4.0,
            speedMultiplier: 2.2,
            radiusMultiplier: 1.0,
            visualScale: 0.9,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            homing: true,
            homingStrength: 2.5,
            bounceCount: 2,
          ),
        );
      }
      break;

    // ── CRYSTAL: Prism Cathedral ──
    // A crystalline cathedral grows from the field. 5–8 stationary
    // prism towers form a ring; each tower fires homing crystal
    // shards that split on impact (cluster). Splash damage radiates
    // between towers. The whole formation is the environment change.
    // Beauty drives tower count (prismatic architecture).
    case 'Crystal':
      final cathedralCenter = Offset(
        origin.dx + cos(baseAngle) * 90,
        origin.dy + sin(baseAngle) * 90,
      );
      final towerCount = scaledCount(casterBeauty, 6, min: 5, max: 8);
      for (var i = 0; i < towerCount; i++) {
        final a = i * (pi * 2 / towerCount);
        final pos = Offset(
          cathedralCenter.dx + cos(a) * 110,
          cathedralCenter.dy + sin(a) * 110,
        );
        projs.add(
          Projectile(
            position: pos,
            angle: a,
            element: element,
            damage: damage * 1.1,
            life: 11.0,
            stationary: true,
            radiusMultiplier: 2.4,
            visualScale: 2.2,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            piercing: true,
            // Towers fire a splitting prism shard every ~0.95s.
            turretInterval: 0.95,
            turretDamage: damage * 1.65,
            turretHomingStrength: 4.5,
            turretSpeedMultiplier: 1.45,
            // Per-tower splash radiates between towers when an enemy
            // is within range — the cathedral "rings" together.
            tickEffect: AbilityEffectKind.splash,
            effectPower: damage * 0.55,
            effectRadius: 130,
            effectDuration: 0.8,
            // Towers are INDESTRUCTIBLE — they time out only. At
            // ultimate cost they shouldn't be killable mid-cast.
          ),
        );
      }
      break;

    // ── AIR: Cyclone Halo ──
    // Ship-following orbital shield ring that intercepts enemy
    // projectiles, deals high damage on contact, AND auto-fires wind
    // gusts at nearby enemies. The cyclone protects + attacks.
    // Intelligence drives interceptor count (precision defense).
    case 'Air':
      final ringCount = scaledCount(casterIntelligence, 6, min: 4, max: 9);
      for (var i = 0; i < ringCount; i++) {
        final a = baseAngle + i * (pi * 2 / ringCount);
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 38, origin.dy + sin(a) * 38),
            angle: a,
            element: element,
            damage: damage * 1.45,
            life: 9.0,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            visualScale: 1.35,
            radiusMultiplier: 1.7,
            orbitCenter: origin,
            orbitAngle: a,
            orbitRadius: 38,
            orbitSpeed: 6.5,
            holdOrbit: true,
            followShipOrbit: true,
            interceptRadius: 55.0,
            interceptCharges: 5,
            snareRadius: 72.0,
            snareMoveMultiplier: 0.62,
            // Auto-fire wind gusts at nearby enemies — turns the ring
            // from a passive shield into active defense.
            turretInterval: 0.85,
            turretDamage: damage * 1.10,
            turretHomingStrength: 3.5,
            turretSpeedMultiplier: 1.4,
            // Knockback aura ticks on enemies that close inside the
            // ring radius — keeps them pushed back.
            tickEffect: AbilityEffectKind.knockback,
            effectPower: damage * 0.30,
            effectRadius: 90,
            effectDuration: 0.20,
          ),
        );
      }
      break;

    // ── PLANT: Verdant Procession ──
    // Line of vine turrets planted toward target. Each fires homing
    // thorns for the duration, AND on cast each turret hurls a heavy
    // thorn salvo in a forward fan as the opening spectacle.
    // Strength drives turret count (vine growth force).
    case 'Plant':
      final vineCount = scaledCount(casterStrength, 4, min: 2, max: 6);
      for (var i = 0; i < vineCount; i++) {
        final dist = 40.0 + i * 35.0;
        final pos = Offset(
          origin.dx + cos(baseAngle) * dist,
          origin.dy + sin(baseAngle) * dist,
        );
        projs.add(
          Projectile(
            position: pos,
            angle: baseAngle,
            element: element,
            damage: damage * 1.1,
            life: 9.0,
            stationary: true,
            radiusMultiplier: 1.8,
            visualScale: 1.75,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            turretInterval: 0.56,
            turretDamage: damage * 1.9,
            turretHomingStrength: 4.5,
            turretSpeedMultiplier: 1.3,
          ),
        );
        // Opening salvo: each turret hurls 3 heavy homing thorns in a
        // forward fan — gives the cast a satisfying spectacle layer
        // beyond just "static turrets planted".
        for (var j = -1; j <= 1; j++) {
          final a = baseAngle + j * 0.35;
          projs.add(
            Projectile(
              position: pos,
              angle: a,
              element: element,
              damage: damage * 2.2,
              life: 3.5,
              speedMultiplier: 1.55,
              radiusMultiplier: 1.4,
              visualScale: 1.2,
              visualStyle: ProjectileVisualStyle.mysticOrbital,
              homing: true,
              homingStrength: 4.0,
              piercing: true,
              trailInterval: 0.15,
              trailDamage: damage * 0.4,
              trailLife: 1.4,
            ),
          );
        }
      }
      shipHeal = max(
        shipHeal,
        max(1, (CosmicBalance.shipMaxHealth * 0.035).round()),
      );
      blessingTimer = max(blessingTimer, 4.5);
      blessingHealPerTick = max(blessingHealPerTick, damage * 0.10);
      break;

    // ── POISON: Venom Bloom ──
    // Stationary toxic crater at TARGET position with multiple
    // poison clouds anchored around it. Permanent area denial that
    // distinguishes Poison from the ship-following Air/Light/Dust
    // orbital rings — Poison commits to a chokepoint.
    case 'Poison':
      final venomTarget = Offset(
        origin.dx + cos(baseAngle) * 110,
        origin.dy + sin(baseAngle) * 110,
      );
      final cloudCount = scaledCount(casterIntelligence, 5, min: 4, max: 8);
      // Central super-cloud — heavy snare + DoT
      projs.add(
        Projectile(
          position: venomTarget,
          angle: 0,
          element: element,
          damage: damage * 1.1,
          life: 9.5,
          stationary: true,
          radiusMultiplier: 3.3,
          visualScale: 2.7,
          visualStyle: ProjectileVisualStyle.mysticOrbital,
          snareRadius: 150.0,
          snareMoveMultiplier: 0.30,
          tickEffect: AbilityEffectKind.poison,
          effectPower: damage * 0.45,
          effectRadius: 150,
          effectDuration: 2.0,
        ),
      );
      // Surrounding satellite clouds
      for (var i = 0; i < cloudCount; i++) {
        final a = i * (pi * 2 / cloudCount);
        final pos = Offset(
          venomTarget.dx + cos(a) * 78,
          venomTarget.dy + sin(a) * 78,
        );
        projs.add(
          Projectile(
            position: pos,
            angle: a,
            element: element,
            damage: damage * 0.9,
            life: 9.0,
            stationary: true,
            radiusMultiplier: 1.9,
            visualScale: 1.7,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            snareRadius: 95.0,
            snareMoveMultiplier: 0.45,
            tickEffect: AbilityEffectKind.poison,
            effectPower: damage * 0.32,
            effectRadius: 95,
            effectDuration: 1.6,
          ),
        );
      }
      break;

    // ── SPIRIT: Wraith Chorus ──
    // Slow ghost bolts that hunt the WEAKEST enemy on the field (via
    // execute hit-effect). They phase through everything else,
    // executing low-HP targets one by one. This is the reaper
    // identity — vs Lightning's chain bolts and Crystal's prismatic
    // explosions, Spirit picks off survivors from the wave.
    // Intelligence drives wraith count (spiritual attunement).
    case 'Spirit':
      final wraithCount = scaledCount(casterIntelligence, 5, min: 3, max: 7);
      for (var i = 0; i < wraithCount; i++) {
        final a = baseAngle + (i - (wraithCount - 1) / 2) * 0.22;
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 16, origin.dy + sin(a) * 16),
            angle: a,
            element: element,
            // Cleanup damage bumped — wraiths still hit hard even
            // when no low-HP target is in range to execute.
            damage: damage * 2.4,
            life: 8.5,
            speedMultiplier: 0.85,
            radiusMultiplier: 1.3,
            visualScale: 1.2,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            orbitCenter: origin,
            orbitAngle: a,
            orbitRadius: 30,
            orbitSpeed: 3.4,
            orbitTime: 1.2,
            homing: true,
            homingStrength: 7.0,
            piercing: true,
            // Reaper identity — execute low-HP enemies on contact.
            hitEffect: AbilityEffectKind.execute,
            effectPower: damage * 0.6,
            effectRadius: 30,
            effectChance: 1.0,
            trailInterval: 0.14,
            trailDamage: damage * 0.45,
            trailLife: 2.0,
          ),
        );
      }
      break;

    // ── DARK: Eclipse Procession ──
    // Void wells that actively *pull* enemies inward (vs Earth's
    // stationary taunt-decoys), then execute low-HP enemies caught in
    // their gravity. The pull tick is what makes Dark distinct.
    // Strength drives void well count (dark force).
    case 'Dark':
      final wellCount = scaledCount(casterStrength, 3, min: 2, max: 4);
      for (var i = 0; i < wellCount; i++) {
        final a = baseAngle + (i - (wellCount - 1) / 2) * 0.55;
        final dist = 70.0 + i * 25.0;
        final pos = Offset(
          origin.dx + cos(a) * dist,
          origin.dy + sin(a) * dist,
        );
        projs.add(
          Projectile(
            position: pos,
            angle: a,
            element: element,
            damage: damage * 1.6,
            life: 8.0,
            stationary: true,
            radiusMultiplier: 2.6,
            visualScale: 2.2,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            piercing: true,
            // Smaller taunt + active pull tick = enemies dragged in
            // and consumed, not just "lured". This is the gravity-well
            // identity vs Earth's monoliths.
            tauntRadius: 220.0,
            tauntStrength: 2.5,
            snareRadius: 130.0,
            snareMoveMultiplier: 0.18,
            tickEffect: AbilityEffectKind.blackHole,
            effectPower: damage * 0.55,
            effectRadius: 180,
            effectDuration: 1.2,
            clusterCount: 6,
            clusterDamage: damage * 0.9,
          ),
        );
      }
      break;

    // ── LIGHT: Radiant Crown ──
    // Ship-orbiting turret sentinels that auto-fire homing bolts AND
    // intercept incoming projectiles. Ultimate defense + offense.
    // Beauty drives sentinel count (radiant spectacle).
    case 'Light':
      final sentinelCount = scaledCount(casterBeauty, 5, min: 3, max: 7);
      for (var i = 0; i < sentinelCount; i++) {
        final a = baseAngle + i * (pi * 2 / sentinelCount);
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 42, origin.dy + sin(a) * 42),
            angle: a,
            element: element,
            damage: damage * 1.15,
            life: 10.0,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            visualScale: 1.35,
            radiusMultiplier: 1.5,
            orbitCenter: origin,
            orbitAngle: a,
            orbitRadius: 42,
            orbitSpeed: 4.0,
            holdOrbit: true,
            followShipOrbit: true,
            turretInterval: 0.65,
            turretDamage: damage * 1.4,
            turretHomingStrength: 4.5,
            turretSpeedMultiplier: 1.5,
            interceptRadius: 50.0,
            interceptCharges: 3,
          ),
        );
      }
      shipHeal = max(
        shipHeal,
        max(1, (CosmicBalance.shipMaxHealth * 0.05).round()),
      );
      blessingTimer = max(blessingTimer, 3.8);
      blessingHealPerTick = max(blessingHealPerTick, damage * 0.07);
      break;

    // ── BLOOD: Crimson Coronation ──
    // Orbs materialize AT the target and orbit it briefly before hunting —
    // a "marking" effect. Trails leave persistent blood pools.
    // ── BLOOD: Crimson Sanguine ──
    // Environment-rewriting summon ultimate. A central crimson font
    // erupts at the target, surrounded by satellite blood pools.
    // Each pool persistently summons a Blood Thrall — a fast homing
    // summon that hunts enemies and explodes on contact. Pools also
    // leech-heal allies and the orb when standing in them.
    // Strength drives pool count (vital force); pools last 12s, which
    // the survival lifetime stretch pushes to a sustained 25–30s of
    // field commitment.
    case 'Blood':
      final bloodTarget = Offset(
        origin.dx + cos(baseAngle) * 90,
        origin.dy + sin(baseAngle) * 90,
      );
      final poolCount = scaledCount(casterStrength, 5, min: 4, max: 7);
      // Central crimson font — bigger pool that summons thralls faster.
      projs.add(
        Projectile(
          position: bloodTarget,
          angle: 0,
          element: element,
          damage: damage * 1.6,
          life: 13.0,
          stationary: true,
          radiusMultiplier: 3.4,
          visualScale: 3.0,
          visualStyle: ProjectileVisualStyle.mysticOrbital,
          piercing: true,
          snareRadius: 130.0,
          snareMoveMultiplier: 0.45,
          // Periodically spawns a Blood Thrall summon that hunts.
          turretInterval: 1.10,
          turretDamage: damage * 1.85,
          turretHomingStrength: 5.5,
          turretSpeedMultiplier: 1.35,
          // Standing in the pool drains enemy HP -> heals orb/allies.
          tickEffect: AbilityEffectKind.leech,
          effectPower: damage * 0.55,
          effectRadius: 110,
          effectDuration: 1.4,
        ),
      );
      // Surrounding blood pools — same identity, smaller scale,
      // each contributes its own thrall summon.
      for (var i = 0; i < poolCount; i++) {
        final a = i * (pi * 2 / poolCount);
        final pos = Offset(
          bloodTarget.dx + cos(a) * 105,
          bloodTarget.dy + sin(a) * 105,
        );
        projs.add(
          Projectile(
            position: pos,
            angle: a,
            element: element,
            damage: damage * 1.1,
            life: 12.0,
            stationary: true,
            radiusMultiplier: 2.2,
            visualScale: 2.0,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            piercing: true,
            snareRadius: 95.0,
            snareMoveMultiplier: 0.55,
            // Each pool spawns its own thrall summon.
            turretInterval: 1.55,
            turretDamage: damage * 1.45,
            turretHomingStrength: 4.8,
            turretSpeedMultiplier: 1.20,
            tickEffect: AbilityEffectKind.leech,
            effectPower: damage * 0.40,
            effectRadius: 95,
            effectDuration: 1.4,
          ),
        );
      }
      // Cast-time burst heal — the ritual draws blood from the field.
      selfHeal = max(selfHeal, (damage * 4.0).round());
      shipHeal = max(
        shipHeal,
        max(1, (CosmicBalance.shipMaxHealth * 0.05).round()),
      );
      blessingTimer = max(blessingTimer, 6.0);
      blessingHealPerTick = max(blessingHealPerTick, damage * 0.06);
      break;

    default:
      projs.addAll(
        sequence(
          [28, 40, 52, 64],
          startAngle: baseAngle,
          damageMultiplier: 2.4,
          life: 3.8,
          orbitSpeed: 5.2,
          orbitTime: 1.8,
          homingStrength: 4.0,
          speedMultiplier: 1.2,
          radiusMultiplier: 1.55,
          visualScale: 1.2,
        ),
      );
      break;
  }
  final scaledProjectiles = List.generate(projs.length, (i) {
    final p = projs[i];
    final isCore =
        p.radiusMultiplier >= 1.9 ||
        p.visualScale >= 1.5 ||
        p.clusterCount >= 3;
    return scaleMysticProjectile(p, isCore: isCore);
  });
  return CosmicSpecialResult(
    projectiles: scaledProjectiles,
    selfHeal: selfHeal,
    shipHeal: shipHeal,
    blessingTimer: blessingTimer,
    blessingHealPerTick: blessingHealPerTick,
  );
}

// ─────────────────────────────────────────────────────────
// ABILITY NAMES (unchanged from original)
// ─────────────────────────────────────────────────────────
String cosmicSpecialAbilityName(String family, String element) {
  switch (family.toLowerCase()) {
    case 'horn':
      return switch (element) {
        'Fire' => 'Blazing Charge',
        'Lava' => 'Magma Ram',
        'Lightning' => 'Thunder Crash',
        'Water' => 'Tidal Guard',
        'Ice' => 'Glacier Slam',
        'Steam' => 'Pressure Crash',
        'Earth' => 'Cataclysmic Fortress',
        'Mud' => 'Quagmire Crash',
        'Dust' => 'Sandstorm Ram',
        'Crystal' => 'Crystal Bulwark',
        'Air' => 'Gale Crash',
        'Plant' => 'Thornguard Charge',
        'Poison' => 'Toxic Ram',
        'Spirit' => 'Spirit Bastion',
        'Dark' => 'Shadow Crash',
        'Light' => 'Radiant Guard',
        'Blood' => 'Crimson Fortress',
        _ => 'Shield Charge',
      };
    case 'wing':
      return switch (element) {
        'Fire' => 'Sweeping Flamebeam',
        'Lava' => 'Eruption Trench',
        'Lightning' => 'Chain Lightning Web',
        'Water' => 'Tidal Beam',
        'Ice' => 'Ice Lance Burst',
        'Steam' => 'Boiler Shear',
        'Earth' => 'Boulder Beam',
        'Mud' => 'Mire Rake',
        'Dust' => 'Sandstorm Beam',
        'Crystal' => 'Prism Refraction',
        'Air' => 'Tornado Drill',
        'Plant' => 'Vine Beam',
        'Poison' => 'Venom Spine',
        'Spirit' => 'Reaper Beam',
        'Dark' => 'Void Rake',
        'Light' => 'Radiant Beam',
        'Blood' => 'Crimson Lance',
        _ => 'Piercing Beam',
      };
    case 'let':
      return switch (element) {
        'Fire' => 'Flame Meteor',
        'Lava' => 'Volcanic Bombardment',
        'Lightning' => 'Orbital Strike',
        'Water' => 'Tidal Meteor',
        'Ice' => 'Comet Cluster',
        'Steam' => 'Geyser Strike',
        'Earth' => 'Moon Drop',
        'Mud' => 'Quagmire Meteor',
        'Dust' => 'Sandstorm Meteor',
        'Crystal' => 'Starfall',
        'Air' => 'Atmospheric Bomb',
        'Plant' => 'Seed Bombardment',
        'Poison' => 'Toxic Storm',
        'Spirit' => 'Soul Harvest',
        'Dark' => 'Void Meteor',
        'Light' => 'Celestial Rain',
        'Blood' => 'Transfusion Meteor',
        _ => 'Meteor Strike',
      };
    case 'pip':
      return switch (element) {
        'Fire' => 'Flame Ricochet',
        'Lava' => 'Magma Chain',
        'Lightning' => 'Thunder Chain',
        'Water' => 'Tidal Ricochet',
        'Ice' => 'Frost Chain',
        'Steam' => 'Steam Ricochet',
        'Earth' => 'Tremor Chain',
        'Mud' => 'Mire Ricochet',
        'Dust' => 'Sand Chain',
        'Crystal' => 'Crystal Shatter',
        'Air' => 'Cyclone Chain',
        'Plant' => 'Thorn Ricochet',
        'Poison' => 'Pandemic Chain',
        'Spirit' => 'Haunt Chain',
        'Dark' => 'Black Hole Passive',
        'Light' => 'Blessing Chain',
        'Blood' => 'Hemorrhage Chain',
        _ => 'Ricochet Salvo',
      };
    case 'mane':
      return switch (element) {
        'Fire' => 'Flameblade Combo',
        'Lava' => 'Molten Cleave',
        'Lightning' => 'Storm Rod Field',
        'Water' => 'Tidecross Volley',
        'Ice' => 'Frostguard Cleave',
        'Steam' => 'Pressure Vent Cuts',
        'Earth' => 'Faultline Guardbreak',
        'Mud' => 'Bogbreaker Combo',
        'Dust' => 'Sandblade Fan',
        'Crystal' => 'Prism Edge',
        'Air' => 'Windblade Sweep',
        'Plant' => 'Vine Lariat',
        'Poison' => 'Venom Edge',
        'Spirit' => 'Phaseblade Rush',
        'Dark' => 'Voidcut Drive',
        'Light' => 'Radiant Parry',
        'Blood' => 'Bloodedge Rush',
        _ => 'Barrage Volley',
      };
    case 'mask':
      return switch (element) {
        'Fire' => 'Inferno Lure Grid',
        'Lava' => 'Volcanic Taunt Idol',
        'Lightning' => 'Tesla Snare Grid',
        'Water' => 'Tidal Lure Net',
        'Ice' => 'Frost Snare Totem',
        'Steam' => 'Steam Pressure Lure',
        'Earth' => 'Monolith Taunt Field',
        'Mud' => 'Bog Snare Pit',
        'Dust' => 'Caltrop Lure Field',
        'Crystal' => 'Prism Snare Totem',
        'Air' => 'Cyclone Lure Field',
        'Plant' => 'Vine Snare Construct',
        'Poison' => 'Plague Snare Grid',
        'Spirit' => 'Phantom Lure Totem',
        'Dark' => 'Void Taunt Well',
        'Light' => 'Beacon Snare Field',
        'Blood' => 'Blood Lure Obelisk',
        _ => 'Taunt Trap Field',
      };
    case 'kin':
      return switch (element) {
        'Fire' => 'Inferno Blessing',
        'Lava' => 'Volcanic Blessing',
        'Lightning' => 'Tempest Blessing',
        'Water' => 'Divine Fountain',
        'Ice' => 'Glacier Blessing',
        'Steam' => 'Scalding Veil',
        'Earth' => 'Fortress Blessing',
        'Mud' => 'Quagmire Blessing',
        'Dust' => 'Sandstorm Blessing',
        'Crystal' => 'Prism Shelter',
        'Air' => 'Hurricane Blessing',
        'Plant' => 'Divine Bloom',
        'Poison' => 'Plague Blessing',
        'Spirit' => 'Divine Ascension',
        'Dark' => 'Eclipse Blessing',
        'Light' => 'Divinity',
        'Blood' => 'Blood Well',
        _ => 'Blessing Pulse',
      };
    case 'mystic':
      return switch (element) {
        'Fire' => 'Solar Flare Procession',
        'Lava' => 'Cataclysm Moons',
        'Lightning' => 'Storm Lattice',
        'Water' => 'Tidal Crescent Rite',
        'Ice' => 'Glacier Crown',
        'Steam' => 'Whiteout Veil',
        'Earth' => 'Monolith Constellation',
        'Mud' => 'Mire Eclipse',
        'Dust' => 'Sirocco Halo',
        'Crystal' => 'Prism Cathedral',
        'Air' => 'Cyclone Halo',
        'Plant' => 'Verdant Procession',
        'Poison' => 'Venom Halo',
        'Spirit' => 'Wraith Chorus',
        'Dark' => 'Eclipse Procession',
        'Light' => 'Radiant Crown',
        'Blood' => 'Crimson Coronation',
        _ => 'Guardian Ultimate',
      };
    default:
      return 'Special Attack';
  }
}

/// Family basic attacks — unchanged from original
List<Projectile> createFamilyBasicAttack({
  required Offset origin,
  required double angle,
  required String element,
  required String family,
  required double damage,
}) {
  switch (family.toLowerCase()) {
    case 'mane':
      return [
        Projectile(
          position: Offset(
            origin.dx + cos(angle - 0.08) * 15,
            origin.dy + sin(angle - 0.08) * 15,
          ),
          angle: angle - 0.08,
          element: element,
          damage: damage * 0.65 * kDamageScale,
          visualStyle: ProjectileVisualStyle.slash,
        ),
        Projectile(
          position: Offset(
            origin.dx + cos(angle + 0.08) * 15,
            origin.dy + sin(angle + 0.08) * 15,
          ),
          angle: angle + 0.08,
          element: element,
          damage: damage * 0.65 * kDamageScale,
          visualStyle: ProjectileVisualStyle.slash,
        ),
      ];
    case 'let':
      return [
        Projectile(
          position: Offset(
            origin.dx + cos(angle) * 18,
            origin.dy + sin(angle) * 18,
          ),
          angle: angle,
          element: element,
          damage: damage * 1.15 * kDamageScale,
          speedMultiplier: 0.82,
          radiusMultiplier: 1.55,
          visualScale: 1.7,
          life: 1.6,
          visualStyle: ProjectileVisualStyle.meteor,
        ),
      ];
    case 'pip':
      return List.generate(3, (i) {
        final a = angle + (i - 1) * 0.12;
        return Projectile(
          position: Offset(origin.dx + cos(a) * 14, origin.dy + sin(a) * 14),
          angle: a,
          element: element,
          damage: damage * 0.30 * kDamageScale,
          speedMultiplier: 1.75,
          life: 1.25,
          homing: false,
          homingStrength: 0,
          visualScale: 0.78,
          visualStyle: ProjectileVisualStyle.dart,
        );
      });
    case 'horn':
      return [
        Projectile(
          position: Offset(
            origin.dx + cos(angle) * 18,
            origin.dy + sin(angle) * 18,
          ),
          angle: angle,
          element: element,
          damage: damage * 1.6 * kDamageScale,
          speedMultiplier: 0.65,
          radiusMultiplier: 1.8,
          visualScale: 1.5,
        ),
      ];
    case 'mask':
      return [
        Projectile(
          position: Offset(
            origin.dx + cos(angle) * 15,
            origin.dy + sin(angle) * 15,
          ),
          angle: angle,
          element: element,
          damage: damage * 0.9 * kDamageScale,
          speedMultiplier: 1.3,
          piercing: true,
          life: 1.2,
          visualStyle: ProjectileVisualStyle.dart,
        ),
      ];
    case 'wing':
      return [
        Projectile(
          position: Offset(
            origin.dx + cos(angle) * 12,
            origin.dy + sin(angle) * 12,
          ),
          angle: angle,
          element: element,
          damage: damage * 0.5 * kDamageScale,
          speedMultiplier: 1.5,
          visualScale: 0.75,
        ),
        Projectile(
          position: Offset(
            origin.dx + cos(angle) * 8,
            origin.dy + sin(angle) * 8,
          ),
          angle: angle,
          element: element,
          damage: damage * 0.5 * kDamageScale,
          speedMultiplier: 1.4,
          visualScale: 0.75,
          life: 1.9,
        ),
      ];
    case 'kin':
      return [
        Projectile(
          position: Offset(
            origin.dx + cos(angle) * 15,
            origin.dy + sin(angle) * 15,
          ),
          angle: angle,
          element: element,
          damage: damage * 1.1 * kDamageScale,
          speedMultiplier: 0.7,
          homing: true,
          homingStrength: 2.5,
          life: 2.5,
          visualScale: 1.1,
        ),
      ];
    case 'mystic':
      return List.generate(3, (i) {
        final a = angle + (i - 1) * 0.12;
        return Projectile(
          position: Offset(origin.dx + cos(a) * 15, origin.dy + sin(a) * 15),
          angle: a,
          element: element,
          damage: damage * 0.4 * kDamageScale,
          visualScale: 0.7,
        );
      });
    default:
      return [
        Projectile(
          position: Offset(
            origin.dx + cos(angle) * 15,
            origin.dy + sin(angle) * 15,
          ),
          angle: angle,
          element: element,
          damage: damage * kDamageScale,
        ),
      ];
  }
}

// ─────────────────────────────────────────────────────────
// STAR DUST
// ─────────────────────────────────────────────────────────

/// 50 fixed star-dust collectibles scattered across the cosmos.
/// Positions are deterministic from the world seed so all players share them.
class StarDust {
  final Offset position;
  final int index;
  bool collected;

  StarDust({
    required this.position,
    required this.index,
    this.collected = false,
  });

  /// Generate the 50 star-dust positions for a given seed.
  /// Avoids spawning too close to any planet.
  static List<StarDust> generate({
    required int seed,
    required Size worldSize,
    required List<CosmicPlanet> planets,
  }) {
    final rng = Random(seed ^ 0xDEADBEEF);
    const count = 50;
    const margin = 2000.0;
    const minPlanetDist = 2000.0;

    final dusts = <StarDust>[];
    for (var i = 0; i < count; i++) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
        tries++;
      } while (tries < 200 &&
          planets.any((p) => (p.position - pos).distance < minPlanetDist));

      dusts.add(StarDust(position: pos, index: i));
    }
    return dusts;
  }

  /// Speed multiplier: 1.0 at 0 collected, 2.0 at 50 collected (linear).
  static double speedMultiplier(int collectedCount) =>
      1.0 + (collectedCount.clamp(0, 50) / 50.0);

  /// Serialise collected indices to a compact string.
  static String serialiseCollected(Set<int> collected) =>
      (collected.toList()..sort()).join(',');

  /// Deserialise collected indices from a string.
  static Set<int> deserialiseCollected(String raw) {
    if (raw.isEmpty) return {};
    return raw
        .split(',')
        .map((s) => int.tryParse(s) ?? -1)
        .where((i) => i >= 0)
        .toSet();
  }
}

// ─────────────────────────────────────────────────────────
// VFX PARTICLES (kill effects, death explosion, etc.)
// ─────────────────────────────────────────────────────────

class VfxParticle {
  double x, y;
  double vx, vy;
  double size;
  double life;
  final double maxLife;
  final Color color;
  final double drag;

  VfxParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.life,
    required this.color,
    this.drag = 0.92,
  }) : maxLife = life;

  double get alpha => (life / maxLife * 2).clamp(0.0, 1.0);
  bool get dead => life <= 0;

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vx *= drag;
    vy *= drag;
    life -= dt;
  }
}

class VfxShockRing {
  double x, y;
  double radius;
  final double maxRadius;
  final double expandSpeed;
  final Color color;

  VfxShockRing({
    required this.x,
    required this.y,
    required this.maxRadius,
    required this.color,
    this.expandSpeed = 400.0,
  }) : radius = 0;

  double get progress => (radius / maxRadius).clamp(0.0, 1.0);
  double get alpha => (1.0 - progress).clamp(0.0, 1.0);
  bool get dead => radius >= maxRadius;

  void update(double dt) {
    radius += expandSpeed * dt;
  }
}

// ─────────────────────────────────────────────────────────
// ORBITAL ALCHEMY CHAMBER
// ─────────────────────────────────────────────────────────

/// A floating creature bubble that orbits the home planet.
/// Physics: gravitational pull toward home planet centre, elastic
/// collisions with other chambers & projectiles, always settles
/// back into orbit.
class OrbitalChamber {
  /// World-space position.
  Offset position;

  /// World-space velocity (px/s).
  Offset velocity;

  /// Visual / collision radius.
  double radius;

  /// Element-based color for the orb glow.
  Color color;

  /// Unique seed for per-bubble animation phase.
  double seed;

  /// Elapsed life (for wobble / animations).
  double life;

  /// Associated creature instance ID (may be null for empty slot).
  String? instanceId;

  /// Base creature ID for sprite display.
  String? baseCreatureId;

  /// Display name shown under the orb.
  String? displayName;

  /// Static image path for the creature (e.g. 'creatures/rare/HOR01_firehorn.png').
  String? imagePath;

  /// Full sprite visuals so chamber rendering can reuse alchemy effects/tints.
  SpriteVisuals? spriteVisuals;

  /// Desired orbital distance from home planet centre.
  double orbitDistance;

  /// Whether this chamber is currently "knocked" (recently hit).
  bool knocked;

  /// Knockback recovery timer — seconds until gravity fully returns.
  double knockTimer;

  OrbitalChamber({
    required this.position,
    required this.velocity,
    this.radius = 18,
    required this.color,
    required this.seed,
    this.life = 0,
    this.instanceId,
    this.baseCreatureId,
    this.displayName,
    this.imagePath,
    this.spriteVisuals,
    this.orbitDistance = 200,
    this.knocked = false,
    this.knockTimer = 0,
  });

  /// Gravity constant — strength of pull toward home planet.
  static const double gravityStrength = 4000.0;

  /// Damping: velocity decays to settle into orbit smoothly.
  /// High damping = less bouncing, smoother convergence.
  static const double damping = 0.94;

  /// Max speed clamp to keep orbits gentle.
  static const double maxSpeed = 80.0;

  /// After being hit, how long before gravity fully kicks back in.
  static const double knockRecoveryTime = 2.5;

  /// Update physics: maintain orbit at [orbitDistance], never fall into planet.
  void update(double dt, Offset homeCentre) {
    life += dt;

    // ── Radial spring toward orbitDistance ──
    final toHome = homeCentre - position;
    final dist = toHome.distance;

    if (dist > 1.0) {
      final dir = toHome / dist;

      // Radial error: positive = too far out, negative = too close
      final error = dist - orbitDistance;

      // Critically-damped spring toward orbit ring.
      // Gentle outward / inward — low stiffness to avoid oscillation.
      final springK = error > 0 ? 40.0 : 90.0;
      final radialForce = error * springK;
      velocity += dir * radialForce * dt;

      // Gentle tangential drift to keep them circling slowly.
      final tangent = Offset(-dir.dy, dir.dx);
      final orbitDriftStrength = 14.0 + 5.0 * sin(seed);
      velocity += tangent * orbitDriftStrength * dt;
    }

    // ── Knockback recovery ──
    if (knocked) {
      knockTimer -= dt;
      if (knockTimer <= 0) {
        knocked = false;
        knockTimer = 0;
      }
    }

    // ── Damping — stronger when not knocked, so they settle ──
    final d = knocked ? 0.995 : damping;
    velocity *= d;

    // ── Speed clamp ──
    final speed = velocity.distance;
    if (speed > maxSpeed) {
      velocity = velocity / speed * maxSpeed;
    }

    // ── Integrate ──
    position += velocity * dt;
  }

  /// Apply an impulse (e.g. from projectile hit or fling).
  void applyImpulse(Offset impulse) {
    velocity += impulse;
    knocked = true;
    knockTimer = knockRecoveryTime;
  }
}

// ─────────────────────────────────────────────────────────
// GALAXY WHIRL (HORDE ENCOUNTER)
// ─────────────────────────────────────────────────────────

/// State of a galaxy whirl encounter.
enum WhirlState { dormant, active, completed }

/// Horde archetype — determines wave composition & enemy behaviour.
/// Assigned based on level: 1-3 Skirmish, 4-7 Siege, 8-10 Onslaught.
enum HordeType {
  /// Lv 1-3: Simple waves, mostly wisps/sentinels, moderate pacing.
  skirmish,

  /// Lv 4-7: Formation bursts spawn all at once, brute tanks, mini-boss on final wave.
  siege,

  /// Lv 8-10: Fast spawns, mixed tiers from wave 1, swarm-dominant, mini-boss brute finale.
  onslaught,
}

/// Derive the [HordeType] from a whirl level.
HordeType hordeTypeForLevel(int level) {
  if (level <= 3) return HordeType.skirmish;
  if (level <= 7) return HordeType.siege;
  return HordeType.onslaught;
}

/// A swirling galaxy vortex that spawns waves of enemies when the player
/// enters its activation radius. Survive all waves to earn rewards.
class GalaxyWhirl {
  Offset position;
  final String element;
  final int level; // 1-5
  final HordeType hordeType;
  final double radius;
  WhirlState state;
  int currentWave;
  final int totalWaves;
  double waveTimer;
  double spawnTimer;
  int enemiesSpawnedInWave;
  int enemiesAlive;
  double rotation;
  double pulse;
  bool miniBossSpawned; // for siege/onslaught final wave mini-boss

  static const double activationRadius = 200.0;

  /// Spawn interval varies by horde type.
  double get waveSpawnInterval => switch (hordeType) {
    HordeType.skirmish => 1.5,
    HordeType.siege => 0.3, // burst — nearly simultaneous
    HordeType.onslaught => 0.8, // fast but not instant
  };

  GalaxyWhirl({
    required this.position,
    required this.element,
    required this.level,
    this.radius = 60,
    this.state = WhirlState.dormant,
    this.currentWave = 0,
    this.totalWaves = 5,
    this.waveTimer = 0,
    this.spawnTimer = 0,
    this.enemiesSpawnedInWave = 0,
    this.enemiesAlive = 0,
    this.rotation = 0,
    this.pulse = 0,
    this.miniBossSpawned = false,
  }) : hordeType = hordeTypeForLevel(level);

  /// Number of enemies per wave — varies by horde type & level.
  int enemiesForWave(int wave) {
    switch (hordeType) {
      case HordeType.skirmish:
        // Gentle ramp: 2-3 base + 1 per wave
        return 2 + (level / 3).ceil() + wave;
      case HordeType.siege:
        // Burst formation: 4-6 base + 2 per wave, fewer total waves
        return 4 + (level / 2).ceil() + wave * 2;
      case HordeType.onslaught:
        // Relentless: 5-8 base + 2-3 per wave
        return 5 + (level / 2).ceil() + wave * (1 + (level / 4).ceil());
    }
  }

  /// Time limit per wave in seconds.
  double timeForWave(int wave) => switch (hordeType) {
    HordeType.skirmish => 30.0 + wave * 10.0,
    HordeType.siege => 40.0 + wave * 8.0, // more time for formation
    HordeType.onslaught => 25.0 + wave * 6.0, // tight timer
  };

  /// Shard reward for clearing all waves — scales with level & type.
  int get shardReward {
    final typeBonus = switch (hordeType) {
      HordeType.skirmish => 0,
      HordeType.siege => 8,
      HordeType.onslaught => 18,
    };
    return (10 + level * 5) + totalWaves * 3 + typeBonus;
  }

  /// Element particle reward for clearing all waves — scales with level.
  double get particleReward {
    final typeBonus = switch (hordeType) {
      HordeType.skirmish => 0.0,
      HordeType.siege => 5.0,
      HordeType.onslaught => 12.0,
    };
    return 5.0 + level * 3.0 + totalWaves * 2.0 + typeBonus;
  }

  /// Enemy health multiplier based on whirl level.
  /// Lv1=1.0x  Lv5=2.0x  Lv10=4.0x
  double get enemyHealthScale => 1.0 + (level - 1) * 0.33;

  /// Enemy speed multiplier based on whirl level.
  /// Lv1=1.0x  Lv5=1.3x  Lv10=1.6x
  double get enemySpeedScale => 1.0 + (level - 1) * 0.067;

  /// Display name for the horde type.
  String get hordeTypeName => switch (hordeType) {
    HordeType.skirmish => 'SKIRMISH',
    HordeType.siege => 'SIEGE',
    HordeType.onslaught => 'ONSLAUGHT',
  };

  /// Generate 5 galaxy whirls scattered across the world.
  static List<GalaxyWhirl> generate({
    required int seed,
    required Size worldSize,
    required List<CosmicPlanet> planets,
  }) {
    final rng = Random(seed ^ 0x6A1A);
    const count = 5;
    const margin = 3000.0;
    const minPlanetDist = 2500.0;
    const minWhirlDist = 4000.0;

    final elements = kElementColors.keys.toList();
    final whirls = <GalaxyWhirl>[];
    for (var i = 0; i < count; i++) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
        tries++;
      } while (tries < 200 &&
          (planets.any((p) => (p.position - pos).distance < minPlanetDist) ||
              whirls.any((w) => (w.position - pos).distance < minWhirlDist)));

      whirls.add(
        GalaxyWhirl(
          position: pos,
          element: elements[rng.nextInt(elements.length)],
          level: rng.nextInt(10) + 1, // 1-10
          radius: 50 + rng.nextDouble() * 30,
          totalWaves: 3 + rng.nextInt(3),
        ),
      );
    }
    return whirls;
  }
}

// ─────────────────────────────────────────────────────────
// SPACE POINTS OF INTEREST
// ─────────────────────────────────────────────────────────

/// Type of space point of interest.
enum POIType {
  nebula,
  derelict,
  comet,
  warpAnomaly,
  harvesterMarket,
  riftKeyMarket,
  cosmicMarket,
  stardustScanner,
  planetScanner,
  goldConversion,
  survivalPortal,
}

/// A discoverable point of interest in the cosmos.
class SpacePOI {
  Offset position;
  final POIType type;
  final String element;
  final double radius;
  bool discovered;
  bool interacted;
  double life;
  double angle;
  double speed;

  SpacePOI({
    required this.position,
    required this.type,
    required this.element,
    this.radius = 40,
    this.discovered = false,
    this.interacted = false,
    this.life = 0,
    this.angle = 0,
    this.speed = 0,
  });

  /// Generate space POIs across the cosmos.
  static List<SpacePOI> generate({
    required int seed,
    required Size worldSize,
    required List<CosmicPlanet> planets,
  }) {
    final rng = Random(seed ^ 0xBB22);
    const margin = 2500.0;
    const minPlanetDist = 2000.0;
    final elements = kElementColors.keys.toList();

    final pois = <SpacePOI>[];

    // 6 nebulae
    for (var i = 0; i < 6; i++) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
        tries++;
      } while (tries < 150 &&
          planets.any((p) => (p.position - pos).distance < minPlanetDist));
      pois.add(
        SpacePOI(
          position: pos,
          type: POIType.nebula,
          element: elements[rng.nextInt(elements.length)],
          radius: 80 + rng.nextDouble() * 60,
        ),
      );
    }

    // 1 derelict
    for (var i = 0; i < 1; i++) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
        tries++;
      } while (tries < 150 &&
          planets.any((p) => (p.position - pos).distance < minPlanetDist));
      pois.add(
        SpacePOI(
          position: pos,
          type: POIType.derelict,
          element: elements[rng.nextInt(elements.length)],
          radius: 25,
        ),
      );
    }

    // 1 meteor shower zone (hidden on the map; encountered in-world)
    for (var i = 0; i < 1; i++) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
        tries++;
      } while (tries < 150 &&
          planets.any((p) => (p.position - pos).distance < minPlanetDist));
      pois.add(
        SpacePOI(
          position: pos,
          type: POIType.comet,
          element: elements[rng.nextInt(elements.length)],
          radius: 620,
          angle: rng.nextDouble() * pi * 2,
          speed: 0,
        ),
      );
    }

    // 3 warp anomalies
    for (var i = 0; i < 3; i++) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
        tries++;
      } while (tries < 150 &&
          planets.any((p) => (p.position - pos).distance < minPlanetDist));
      pois.add(
        SpacePOI(
          position: pos,
          type: POIType.warpAnomaly,
          element: 'Spirit',
          radius: 35 + rng.nextDouble() * 15,
        ),
      );
    }

    // 5 stations (harvester + rift key + cosmic + stardust scanner + gold conversion)
    for (final mType in [
      POIType.harvesterMarket,
      POIType.riftKeyMarket,
      POIType.cosmicMarket,
      POIType.stardustScanner,
      POIType.goldConversion,
    ]) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
        tries++;
      } while (tries < 150 &&
          (planets.any((p) => (p.position - pos).distance < minPlanetDist) ||
              pois.any((p) => (p.position - pos).distance < minPlanetDist)));
      pois.add(
        SpacePOI(
          position: pos,
          type: mType,
          element: mType == POIType.stardustScanner ? 'Light' : 'Crystal',
          radius: mType == POIType.stardustScanner ? 120 : 60,
          discovered: false, // discovered when ship gets close
        ),
      );
    }

    // 1 survival portal — fixed distant position
    {
      // Place far from origin (center of world) at a consistent angle
      final cx = worldSize.width / 2;
      final cy = worldSize.height / 2;
      final portalAngle = (seed * 0.618033) % (pi * 2); // golden ratio spread
      const portalDist = 9000.0;
      final portalPos = Offset(
        (cx + cos(portalAngle) * portalDist).clamp(
          margin,
          worldSize.width - margin,
        ),
        (cy + sin(portalAngle) * portalDist).clamp(
          margin,
          worldSize.height - margin,
        ),
      );
      pois.add(
        SpacePOI(
          position: portalPos,
          type: POIType.survivalPortal,
          element: 'Spirit',
          radius: 50,
        ),
      );
    }

    return pois;
  }
}

// ─────────────────────────────────────────────────────────
// SPACE MARKET
// Discoverable trading posts — one sells harvesters, one sells rift keys.
// ─────────────────────────────────────────────────────────

/// A rotating elemental discount recipe for a space-market item.
/// If the player's alchemical meter has ≥ [threshold]% of [requiredElement],
/// they receive a 50% discount on that item.
class MarketDiscountRecipe {
  final String requiredElement;
  final double threshold; // fraction 0..1 (0.5 = 50%)

  const MarketDiscountRecipe({
    required this.requiredElement,
    this.threshold = 0.50,
  });

  /// Check if the player's meter qualifies for the discount.
  bool qualifies(Map<String, double> meterBreakdown, double meterTotal) {
    if (meterTotal <= 0) return false;
    final amt = meterBreakdown[requiredElement] ?? 0;
    return (amt / meterTotal) >= threshold;
  }
}

/// Generates a set of rotating discount recipes keyed by inventory item key.
/// Recipes change daily and use elements thematically tied to each item's faction.
class MarketRecipeTable {
  /// Elements grouped by faction — discounts use elements from the SAME family.
  static const _factionElements = <String, List<String>>{
    'volcanic': ['Fire', 'Lava', 'Steam', 'Lightning'],
    'oceanic': ['Water', 'Ice', 'Steam', 'Mud'],
    'verdant': ['Plant', 'Earth', 'Mud', 'Dust'],
    'earthen': ['Earth', 'Dust', 'Crystal', 'Lava'],
    'arcane': ['Spirit', 'Dark', 'Light', 'Blood'],
    'neutral': ['Crystal', 'Spirit', 'Light', 'Blood'],
  };

  /// Generates recipes for a list of items using a daily rotating seed.
  /// Each item's recipe picks from its own faction's element pool.
  static Map<String, MarketDiscountRecipe> generate({
    required List<MarketItemEntry> items,
  }) {
    // Seed rotates every day (UTC midnight)
    final epochDay =
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ (24 * 3600 * 1000);
    final rng = Random(epochDay ^ 0xDEAD0042);

    final recipes = <String, MarketDiscountRecipe>{};
    for (final item in items) {
      final pool =
          _factionElements[item.faction] ?? _factionElements['neutral']!;
      recipes[item.key] = MarketDiscountRecipe(
        requiredElement: pool[rng.nextInt(pool.length)],
      );
    }
    return recipes;
  }
}

/// Lightweight entry passed to [MarketRecipeTable.generate] so it knows
/// each item's key and faction.
class MarketItemEntry {
  final String key;
  final String faction;
  const MarketItemEntry({required this.key, required this.faction});
}

// ─────────────────────────────────────────────────────────
// COSMIC PARTY MEMBER
// An alchemon that patrols space with your ship.
// ─────────────────────────────────────────────────────────

class CosmicPartyMember {
  /// Associated creature instance ID.
  final String instanceId;

  /// Base creature ID for sprite / type lookup.
  final String baseId;

  /// Display name (nickname or species name).
  final String displayName;

  /// Creature image asset path.
  final String? imagePath;

  /// Primary element type.
  final String element;

  /// Family archetype (horn, wing, let, pip, mane, kin, mystic, mask).
  final String family;

  /// Creature level.
  final int level;

  /// Base stats from the CreatureInstance.
  final double statSpeed;
  final double statIntelligence;
  final double statStrength;
  final double statBeauty;

  /// Immutable 1-100 genetic Potential, retained with the lightweight combat
  /// member so practice encounters and stat readouts never fabricate it.
  final double statSpeedPotential;
  final double statIntelligencePotential;
  final double statStrengthPotential;
  final double statBeautyPotential;

  /// Slot index in the owning formation or garrison.
  final int slotIndex;

  /// Current effective stamina bars (after regen).
  final int staminaBars;

  /// Maximum stamina bars.
  final int staminaMax;

  /// Sprite sheet definition for animated rendering.
  final SpriteSheetDef? spriteSheet;

  /// Visual modifiers (genetics, effects).
  final SpriteVisuals? spriteVisuals;

  final String? visualVariant;
  final Offset? spawnPosition;

  CosmicPartyMember({
    required this.instanceId,
    required this.baseId,
    required this.displayName,
    this.imagePath,
    required this.element,
    required this.family,
    required this.level,
    required this.statSpeed,
    required this.statIntelligence,
    required this.statStrength,
    required this.statBeauty,
    this.statSpeedPotential = 50,
    this.statIntelligencePotential = 50,
    this.statStrengthPotential = 50,
    this.statBeautyPotential = 50,
    required this.slotIndex,
    required this.staminaBars,
    required this.staminaMax,
    this.spriteSheet,
    this.spriteVisuals,
    this.visualVariant,
    this.spawnPosition,
  });
}

double normalizedCompanionSpecialCooldown({
  required double effectiveCooldown,
  double? savedCooldown,
  double cooldownMultiplier = 1.0,
}) {
  final effective = (effectiveCooldown * cooldownMultiplier)
      .clamp(0.0, 100.0)
      .toDouble();
  final saved = savedCooldown?.clamp(0.0, 100.0).toDouble();
  return saved == null ? effective : min(saved, effective);
}

/// Runtime state for a summoned (active) party alchemon in cosmic space.
class CosmicCompanion with HasEffects {
  final CosmicPartyMember member;

  /// World-space position (current, moves around anchor).
  Offset position;

  /// Anchor position — where the companion was placed.
  Offset anchorPosition;

  /// Current angle (radians) — faces enemies / movement direction.
  double angle;

  /// HP derived from cosmic companion combat stats.
  int maxHp;
  int currentHp;

  /// Derived cosmic companion combat stats.
  final int _basePhysAtk;
  final int _baseElemAtk;
  final int _basePhysDef;
  final int _baseElemDef;
  final double _baseCooldownReduction;
  final double _baseCritChance;
  final double _baseAttackRange;
  final double _baseSpecialAbilityRange;

  // Effects mixin provides dynamic modifiers (powered by systems/effects/has_effects.dart).
  // Use getters below to return modified values.

  /// Cooldown tracking.
  double basicCooldown;
  double specialCooldown;
  static const double baseSpecialCooldown = 15.0; // 15s base
  static const double baseBasicCooldown = 1.5;

  /// Wander state — meanders near anchor.
  static const double wanderRadius = 80.0;
  double wanderAngle;
  double wanderTimer;

  /// Time alive (for animation).
  double life;

  /// Whether the companion is returning (fading out).
  bool returning;
  double returnTimer;

  /// Invincibility after being summoned.
  double invincibleTimer;

  /// Species-based sprite scale factor.
  double speciesScale;

  /// Shield absorption HP (Horn special). Absorbs damage before HP.
  int shieldHp;

  /// Charging state (Horn special). When > 0, companion rushes toward target.
  double chargeTimer;

  /// Charge target position.
  Offset? chargeTarget;

  /// Charge speed multiplier.
  static const double chargeSpeed = 400.0;
  double chargeSpeedMultiplier;
  double chargeSweepRadius;
  double chargeOvershootDistance;
  double chargeFinalSweepRadius;

  /// Charge damage dealt on impact.
  double chargeDamage;

  /// Enemies already hit during this charge (prevents double-damage).
  Set<int>? chargeHitIds;

  /// Blessing heal timer (Kin special). When > 0, companion heals over time.
  double blessingTimer;

  /// Blessing heal amount per tick.
  double blessingHealPerTick;

  /// Temporary basic-attack haste window granted by some specials.
  double basicHasteTimer;
  double basicHasteMultiplier;
  double damageAmpTimer;
  double damageAmpMultiplier;

  // Shared combat identity counters/timers used by open cosmic and survival.
  int abilityKillStacks;
  double pipSpiritEmpowerTimer;
  double pipSteamWindowTimer;
  Offset? lastPipPoisonHitPos;
  List<Projectile>? pendingChargeBurst;
  Offset? pendingChargeOrigin;
  double pendingChargeAngle;
  static const double pipSteamWindowDuration = 9.0;

  final String? visualVariant;

  CosmicCompanion({
    required this.member,
    required this.position,
    Offset? anchor,
    this.angle = 0,
    required this.maxHp,
    required this.currentHp,
    required int physAtk,
    required int elemAtk,
    required int physDef,
    required int elemDef,
    required double cooldownReduction,
    required double critChance,
    required double attackRange,
    required double specialAbilityRange,
    this.basicCooldown = 0,
    this.specialCooldown = baseSpecialCooldown,
    this.wanderAngle = 0,
    this.wanderTimer = 0,
    this.life = 0,
    this.returning = false,
    this.returnTimer = 0,
    this.invincibleTimer = 2.0,
    this.speciesScale = 1.0,
    this.shieldHp = 0,
    this.chargeTimer = 0,
    this.chargeTarget,
    this.chargeDamage = 0,
    this.chargeSpeedMultiplier = 1.0,
    this.chargeSweepRadius = 48.0,
    this.chargeOvershootDistance = 80.0,
    this.chargeFinalSweepRadius = 68.0,
    this.blessingTimer = 0,
    this.blessingHealPerTick = 0,
    this.basicHasteTimer = 0,
    this.basicHasteMultiplier = 1.0,
    this.damageAmpTimer = 0,
    this.damageAmpMultiplier = 1.0,
    this.abilityKillStacks = 0,
    this.pipSpiritEmpowerTimer = 0,
    this.pipSteamWindowTimer = 0,
    this.lastPipPoisonHitPos,
    this.pendingChargeBurst,
    this.pendingChargeOrigin,
    this.pendingChargeAngle = 0,
    this.visualVariant,
  }) : _basePhysAtk = physAtk,
       _baseElemAtk = elemAtk,
       _basePhysDef = physDef,
       _baseElemDef = elemDef,
       _baseCooldownReduction = cooldownReduction,
       _baseCritChance = critChance,
       _baseAttackRange = attackRange,
       _baseSpecialAbilityRange = specialAbilityRange,
       anchorPosition = anchor ?? position;

  int get physAtk => _maybeModifyStat('physAtk', _basePhysAtk).round();
  int get elemAtk => _maybeModifyStat('elemAtk', _baseElemAtk).round();
  int get physDef => _maybeModifyStat('physDef', _basePhysDef).round();
  int get elemDef => _maybeModifyStat('elemDef', _baseElemDef).round();
  double get cooldownReduction =>
      _maybeModifyStat('cooldownReduction', _baseCooldownReduction);
  double get critChance => _maybeModifyStat('critChance', _baseCritChance);
  double get attackRange => _maybeModifyStat('attackRange', _baseAttackRange);
  double get specialAbilityRange =>
      _maybeModifyStat('specialAbilityRange', _baseSpecialAbilityRange);

  /// Effective cooldowns that factor in stats (speed via `cooldownReduction`,
  /// and damage/strength so stronger alchemons get different timings).
  double get effectiveBasicCooldown {
    final base = CosmicCompanion.baseBasicCooldown / cooldownReduction;
    final factor = (1.0 + (physAtk - 1) * 0.05).clamp(0.5, 3.0);
    final familyMultiplier = switch (member.family.toLowerCase()) {
      'let' => 1.12,
      'pip' => 0.90,
      'horn' => 1.12,
      'mask' => 1.10,
      'wing' => 0.90,
      'mane' => 0.92,
      _ => 1.0,
    };
    final familyL = member.family.toLowerCase();
    var pipPassiveMul = 1.0;
    var pipPassiveDrivesSpeed = false;
    if (familyL == 'pip') {
      if (member.element == 'Spirit' && pipSpiritEmpowerTimer > 0) {
        pipPassiveMul = 0.10;
        pipPassiveDrivesSpeed = true;
      } else if (member.element == 'Steam') {
        final progress = (pipSteamWindowTimer / pipSteamWindowDuration).clamp(
          0.0,
          1.0,
        );
        pipPassiveMul = 0.667 + (0.25 - 0.667) * progress;
        pipPassiveDrivesSpeed = true;
      }
    }
    final hasteMultiplier = (basicHasteTimer > 0 && !pipPassiveDrivesSpeed)
        ? basicHasteMultiplier.clamp(0.45, 1.0)
        : 1.0;
    return (base / factor) * familyMultiplier * hasteMultiplier * pipPassiveMul;
  }

  double get damageAmp =>
      damageAmpTimer > 0 ? damageAmpMultiplier.clamp(1.0, 4.0) : 1.0;

  double get effectiveSpecialCooldown {
    final base = CosmicCompanion.baseSpecialCooldown / cooldownReduction;
    final factor = (1.0 + (elemAtk / 6.0) * 0.2).clamp(0.5, 6.0);
    final familyMultiplier = switch (member.family.toLowerCase()) {
      'let' => 1.18,
      'pip' => 0.92,
      'mane' => 0.88,
      'mask' => 1.05,
      'mystic' => 1.90,
      _ => 1.0,
    };
    final elementMultiplier = elementalSpecialCooldownMultiplier(
      member.family,
      member.element,
    );
    return (base / factor) * familyMultiplier * elementMultiplier;
  }

  void primeSpecialCooldown({
    double? savedCooldown,
    double cooldownMultiplier = 1.0,
  }) {
    specialCooldown = normalizedCompanionSpecialCooldown(
      effectiveCooldown: effectiveSpecialCooldown,
      savedCooldown: savedCooldown,
      cooldownMultiplier: cooldownMultiplier,
    );
  }

  double _maybeModifyStat(String name, num base) {
    try {
      // Lazy import to avoid circular import at file top-level.
      // If the HasEffects mixin is applied and provides `modifyStat`, call it.
      final self = this;
      if ((self as dynamic).modifyStat is Function) {
        return (self as dynamic).modifyStat(name, base.toDouble());
      }
    } catch (_) {}
    return base.toDouble();
  }

  bool get isAlive => currentHp > 0 && !returning;
  double get hpPercent => currentHp / maxHp;
  bool get hasShield => shieldHp > 0;
  bool get isCharging => chargeTimer > 0;
  bool get isBlessing => blessingTimer > 0;

  void takeDamage(int dmg) {
    if (invincibleTimer > 0) return;
    // Shield absorbs damage first
    if (shieldHp > 0) {
      final absorbed = min(dmg, shieldHp);
      shieldHp -= absorbed;
      final remaining = dmg - absorbed;
      if (remaining > 0) {
        currentHp = (currentHp - remaining).clamp(0, maxHp);
      }
    } else {
      currentHp = (currentHp - dmg).clamp(0, maxHp);
    }
    // Brief grace window so a single overlap does not delete companions.
    invincibleTimer = 0.45;
  }
}
