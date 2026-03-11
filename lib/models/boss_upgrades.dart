// lib/models/boss_upgrades.dart
//
// Persistent boss-battle upgrade data model.
// Five stat upgrades that buff the player's squad globally during boss fights.
// Persisted via Settings DAO key-value store; purchased with silver.
//
// BALANCE PHILOSOPHY
// ──────────────────
// The stat formulas in boss_battle_engine_service.dart are:
//   maxHp  = level × 10 + statStrength × 5
//   physAtk = statStrength × 4 + level × 2
//   elemAtk = statIntelligence × 4 + level × 2
//   physDef = (statStrength + statBeauty) × 2 + level
//   elemDef = statBeauty × 4 + level × 2
//   speed   = statSpeed × 4
//
// A creature with 5.0 stats (50 scaled) has ~300 HP, ~120 atk, ~51 def.
// Maxing all 5 upgrades should feel like gaining ~0.3-0.4 stat tiers across
// the board — helpful but nowhere near bridging 4.0 → 5.0.

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BOSS SQUAD UPGRADE DEFINITIONS
// ─────────────────────────────────────────────────────────────────────────────

enum BossSquadUpgrade {
  vitality, // +HP%
  physPower, // +physAtk%
  elemPower, // +elemAtk%
  resilience, // +physDef% / elemDef%
  swiftness, // +speed%
}

class BossSquadUpgradeDef {
  final BossSquadUpgrade upgrade;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int maxLevel;
  final List<int> costPerLevel;
  final List<double> valuePerLevel; // multiplier bonus per level

  const BossSquadUpgradeDef({
    required this.upgrade,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.maxLevel = 5,
    required this.costPerLevel,
    required this.valuePerLevel,
  });

  String bonusLabel(int level) {
    if (level == 0) return '—';
    final v = valuePerLevel[level - 1];
    return '+${(v * 100).toStringAsFixed(0)}%';
  }
}

const List<BossSquadUpgradeDef> kBossSquadUpgrades = [
  // ── VITALITY ───────────────────────────────────────────────────────────────
  // Max HP: base ~300 at 5.0 STR Lv50. Max +18% = +54 HP. Roughly +0.3 STR tier.
  BossSquadUpgradeDef(
    upgrade: BossSquadUpgrade.vitality,
    name: 'Ironblood Rite',
    description: 'Increases all squad members\' maximum HP for boss fights.',
    icon: Icons.favorite_rounded,
    color: Color(0xFFEF4444),
    costPerLevel: [1000, 5000, 10000, 20000, 50000],
    valuePerLevel: [0.04, 0.07, 0.10, 0.14, 0.18],
  ),

  // ── PHYSICAL POWER ─────────────────────────────────────────────────────────
  // physAtk: base ~120 at 5.0 STR Lv50. Max +15% = +18. ~0.35 STR tier.
  BossSquadUpgradeDef(
    upgrade: BossSquadUpgrade.physPower,
    name: 'Warhammer Rune',
    description: 'Boosts all squad members\' physical attack power.',
    icon: Icons.keyboard_double_arrow_up_rounded,
    color: Color(0xFFF97316),
    costPerLevel: [1000, 5000, 10000, 20000, 50000],
    valuePerLevel: [0.03, 0.06, 0.09, 0.12, 0.15],
  ),

  // ── ELEMENTAL POWER ────────────────────────────────────────────────────────
  // elemAtk: base ~120 at 5.0 INT Lv50. Max +15%.
  BossSquadUpgradeDef(
    upgrade: BossSquadUpgrade.elemPower,
    name: 'Arcane Infusion',
    description: 'Boosts all squad members\' elemental attack power.',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFF8B5CF6),
    costPerLevel: [1000, 5000, 10000, 20000, 50000],
    valuePerLevel: [0.03, 0.06, 0.09, 0.12, 0.15],
  ),

  // ── RESILIENCE ─────────────────────────────────────────────────────────────
  // physDef/elemDef: base ~51/~120 at 5.0. Max +20%.
  BossSquadUpgradeDef(
    upgrade: BossSquadUpgrade.resilience,
    name: 'Aegis Plating',
    description:
        'Increases all squad members\' physical and elemental defense.',
    icon: Icons.shield_rounded,
    color: Color(0xFF22C55E),
    costPerLevel: [1000, 5000, 10000, 20000, 50000],
    valuePerLevel: [0.04, 0.08, 0.12, 0.16, 0.20],
  ),

  // ── SWIFTNESS ──────────────────────────────────────────────────────────────
  // speed: affects turn order. base ~20 at 5.0 SPD. Max +12%.
  // Kept low because speed determines who acts first and compounds with crit/status.
  BossSquadUpgradeDef(
    upgrade: BossSquadUpgrade.swiftness,
    name: 'Quicksilver Shard',
    description: 'Increases all squad members\' speed, gaining earlier turns.',
    icon: Icons.speed_rounded,
    color: Color(0xFF0EA5E9),
    costPerLevel: [1000, 5000, 10000, 20000, 50000],
    valuePerLevel: [0.03, 0.05, 0.07, 0.10, 0.12],
  ),
];

BossSquadUpgradeDef getBossSquadUpgradeDef(BossSquadUpgrade u) {
  return kBossSquadUpgrades.firstWhere((d) => d.upgrade == u);
}

// ─────────────────────────────────────────────────────────────────────────────
// COMBINED UPGRADE STATE
// ─────────────────────────────────────────────────────────────────────────────

class BossUpgradeState {
  Map<BossSquadUpgrade, int> levels;

  BossUpgradeState({Map<BossSquadUpgrade, int>? levels})
    : levels = levels ?? {for (final u in BossSquadUpgrade.values) u: 0};

  int getLevel(BossSquadUpgrade u) => levels[u] ?? 0;

  // ── Computed bonus multipliers ────────────────────────────────────────────

  double get hpBonus {
    final level = getLevel(BossSquadUpgrade.vitality);
    if (level <= 0) return 0;
    return getBossSquadUpgradeDef(
      BossSquadUpgrade.vitality,
    ).valuePerLevel[level - 1];
  }

  double get physAtkBonus {
    final level = getLevel(BossSquadUpgrade.physPower);
    if (level <= 0) return 0;
    return getBossSquadUpgradeDef(
      BossSquadUpgrade.physPower,
    ).valuePerLevel[level - 1];
  }

  double get elemAtkBonus {
    final level = getLevel(BossSquadUpgrade.elemPower);
    if (level <= 0) return 0;
    return getBossSquadUpgradeDef(
      BossSquadUpgrade.elemPower,
    ).valuePerLevel[level - 1];
  }

  double get defenseBonus {
    final level = getLevel(BossSquadUpgrade.resilience);
    if (level <= 0) return 0;
    return getBossSquadUpgradeDef(
      BossSquadUpgrade.resilience,
    ).valuePerLevel[level - 1];
  }

  double get speedBonus {
    final level = getLevel(BossSquadUpgrade.swiftness);
    if (level <= 0) return 0;
    return getBossSquadUpgradeDef(
      BossSquadUpgrade.swiftness,
    ).valuePerLevel[level - 1];
  }

  /// Apply all bonuses to a BattleCombatant's computed stats.
  /// Call AFTER _calculateCombatStats() is done.
  void applyTo({
    required int Function() getMaxHp,
    required void Function(int) setMaxHp,
    required int Function() getPhysAtk,
    required void Function(int) setPhysAtk,
    required int Function() getElemAtk,
    required void Function(int) setElemAtk,
    required int Function() getPhysDef,
    required void Function(int) setPhysDef,
    required int Function() getElemDef,
    required void Function(int) setElemDef,
    required int Function() getSpeed,
    required void Function(int) setSpeed,
    required int Function() getCurrentHp,
    required void Function(int) setCurrentHp,
  }) {
    if (hpBonus > 0) {
      final oldMax = getMaxHp();
      final newMax = (oldMax * (1 + hpBonus)).round();
      setMaxHp(newMax);
      // Also top off current HP to new max
      setCurrentHp(newMax);
    }
    if (physAtkBonus > 0) {
      setPhysAtk((getPhysAtk() * (1 + physAtkBonus)).round());
    }
    if (elemAtkBonus > 0) {
      setElemAtk((getElemAtk() * (1 + elemAtkBonus)).round());
    }
    if (defenseBonus > 0) {
      setPhysDef((getPhysDef() * (1 + defenseBonus)).round());
      setElemDef((getElemDef() * (1 + defenseBonus)).round());
    }
    if (speedBonus > 0) {
      setSpeed((getSpeed() * (1 + speedBonus)).round());
    }
  }
}
