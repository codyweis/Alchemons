// lib/services/battle_engine.dart
import 'dart:math';
import 'package:alchemons/models/boss/boss_model.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';

/// Represents a combatant (player creature or boss) in battle
class BattleCombatant {
  final String id;
  final String name;
  final List<String> types; // Element types
  final String family; // Let, Pip, Mane, etc.
  final List<BossMove> bossMoveset;

  /// Optional references used for rendering
  final CreatureInstance? instanceRef;
  final Creature? speciesRef;

  // Base stats
  final double statSpeed;
  final double statIntelligence;
  final double statStrength;
  final double statBeauty;
  final int level;

  // Combat stats (calculated)
  late int maxHp;
  late int physAtk;
  late int elemAtk;
  late int physDef;
  late int elemDef;
  late int speed;

  // Battle state
  late int currentHp;
  Map<String, StatusEffect> statusEffects = {};
  Map<String, StatModifier> statModifiers = {};
  bool isCharging = false;
  int specialCooldown = 0; // Turns until special can be used again
  int actionCooldown = 0; // Turns until this creature can act again
  String? tauntTargetId; // If set (on boss), must target this creature
  int? shieldHp;
  int totalDamageDealt = 0; // Runtime telemetry for tactical boss targeting
  bool kinReviveUsed = false; // One-time Kin sanctuary revive gate per battle

  /// Backward compat: true when special is on cooldown
  bool get needsRecharge => specialCooldown > 0;
  set needsRecharge(bool v) => specialCooldown = v ? 1 : 0;

  BattleCombatant({
    required this.id,
    required this.name,
    required this.types,
    required this.family,
    this.bossMoveset = const [],
    required this.statSpeed,
    required this.statIntelligence,
    required this.statStrength,
    required this.statBeauty,
    required this.level,
    this.instanceRef,
    this.speciesRef,
  }) {
    _calculateCombatStats();
    currentHp = maxHp;
  }

  // ── Visual helpers ───────────────────────────────────────

  /// Lazily compute the sprite sheet definition from the species, if available.
  SpriteSheetDef? get sheetDef {
    final species = speciesRef;
    if (species == null) return null;
    return sheetFromCreature(species);
  }

  /// Lazily compute the per-instance visuals (hue, scale, tint, etc.).
  /// Return type is dynamic to stay compatible with whatever your
  /// CreatureSpriteComponent expects from visualsFromInstance().
  dynamic get spriteVisuals {
    final species = speciesRef;
    final inst = instanceRef;
    if (species == null) return null;
    return visualsFromInstance(species, inst);
  }

  void _calculateCombatStats() {
    final sSpd = statSpeed * 10; // 0–50
    final sInt = statIntelligence * 10;
    final sStr = statStrength * 10;
    final sBea = statBeauty * 10;

    maxHp = (level * 10 + sStr * 0.5).round(); // STR strongly affects HP
    physAtk = (sStr * 0.4 + level * 2).round();
    elemAtk = (sInt * 0.4 + level * 2).round();
    physDef = ((sStr + sBea) * 0.2 + level).round();
    elemDef = (sBea * 0.4 + level * 2).round();
    speed = (sSpd * 0.4).round();
  }

  // --- factories ---

  factory BattleCombatant.fromInstance({
    required CreatureInstance instance,
    required Creature creature,
  }) {
    return BattleCombatant(
      id: instance.instanceId,
      name: instance.nickname ?? creature.name,
      types: creature.types,
      family: creature.mutationFamily!,
      bossMoveset: const [],
      statSpeed: instance.statSpeed,
      statIntelligence: instance.statIntelligence,
      statStrength: instance.statStrength,
      statBeauty: instance.statBeauty,
      level: instance.level,
      instanceRef: instance,
      speciesRef: creature,
    );
  }

  factory BattleCombatant.fromBoss(Boss boss, {Creature? mysticSpecies}) {
    // Bosses don’t use the same sprite pipeline, so instance/species refs are null.
    final bc = BattleCombatant(
      id: boss.id,
      name: mysticSpecies?.name ?? boss.name,
      types: mysticSpecies?.types ?? [boss.element],
      family: mysticSpecies?.mutationFamily ?? 'Mystic',
      bossMoveset: boss.moveset,
      statSpeed: boss.spd.toDouble(),
      statIntelligence: 50.0,
      statStrength: 50.0,
      statBeauty: 50.0,
      level: boss.recommendedLevel,
      instanceRef: null,
      speciesRef: mysticSpecies,
    );

    // Override calculated stats with boss-defined stats
    bc.maxHp = boss.hp;
    bc.currentHp = boss.hp;
    bc.physAtk = boss.atk;
    bc.elemAtk = boss.atk;
    bc.physDef = boss.def;
    bc.elemDef = boss.def;
    bc.speed = boss.spd;

    return bc;
  }

  bool get isAlive => currentHp > 0;
  bool get isDead => currentHp <= 0;
  double get hpPercent => currentHp / maxHp;

  int getEffectivePhysAtk() {
    var atk = physAtk;
    if (statModifiers.containsKey('attack_up')) {
      atk = (atk * 1.5).toInt();
    }
    if (statModifiers.containsKey('attack_down')) {
      atk = (atk * 0.75).toInt();
    }
    return atk;
  }

  int getEffectiveElemAtk() {
    var atk = elemAtk;
    if (statModifiers.containsKey('attack_up')) {
      atk = (atk * 1.5).toInt();
    }
    if (statModifiers.containsKey('attack_down')) {
      atk = (atk * 0.75).toInt();
    }
    return atk;
  }

  int getEffectivePhysDef() {
    var def = physDef;
    if (statModifiers.containsKey('defense_up')) {
      def = (def * 1.5).toInt();
    }
    if (statModifiers.containsKey('defense_down')) {
      def = (def * 0.75).toInt();
    }
    return def;
  }

  int getEffectiveElemDef() {
    var def = elemDef;
    if (statModifiers.containsKey('defense_up')) {
      def = (def * 1.5).toInt();
    }
    if (statModifiers.containsKey('defense_down')) {
      def = (def * 0.75).toInt();
    }
    return def;
  }

  int getEffectiveSpeed() {
    var spd = speed;
    if (statModifiers.containsKey('speed_up')) {
      spd = (spd * 1.5).toInt();
    }
    if (statModifiers.containsKey('speed_down')) {
      spd = (spd * 0.75).toInt();
    }
    return spd;
  }

  void takeDamage(int rawDamage) {
    var damage = rawDamage;

    // Shield absorbs first
    if (shieldHp != null && shieldHp! > 0) {
      if (shieldHp! >= damage) {
        shieldHp = shieldHp! - damage;
        damage = 0;
      } else {
        damage -= shieldHp!;
        shieldHp = 0;
      }
    }

    if (damage <= 0) return;
    currentHp = max(0, currentHp - damage);
  }

  void heal(int amount) {
    currentHp = min(maxHp, currentHp + amount);
  }

  void applyStatusEffect(StatusEffect effect) {
    statusEffects[effect.type] = effect;
  }

  void applyStatModifier(StatModifier modifier) {
    statModifiers[modifier.type] = modifier;
  }

  void tickStatusEffects() {
    final toRemove = <String>[];

    for (final entry in statusEffects.entries) {
      final effect = entry.value;
      effect.tickDuration();

      if (effect.isExpired) {
        toRemove.add(entry.key);
      }
    }

    for (final key in toRemove) {
      statusEffects.remove(key);
    }
  }

  void tickStatModifiers() {
    final toRemove = <String>[];

    for (final entry in statModifiers.entries) {
      final modifier = entry.value;
      modifier.tickDuration();

      if (modifier.isExpired) {
        toRemove.add(entry.key);
      }
    }

    for (final key in toRemove) {
      statModifiers.remove(key);
    }
  }

  /// Tick down action cooldown (called at start of each player turn phase).
  void tickActionCooldown() {
    if (actionCooldown > 0) actionCooldown--;
  }

  /// Tick down special cooldown (called at start of each player turn phase).
  void tickSpecialCooldown() {
    if (specialCooldown > 0) specialCooldown--;
  }

  /// Tick down taunt duration (called at end of each turn cycle).
  void tickTaunt() {
    if (tauntTargetId != null) {
      final taunt = statusEffects['taunt'];
      if (taunt == null || taunt.isExpired) {
        tauntTargetId = null;
      }
    }
  }

  bool get isBanished => statusEffects.containsKey('banished');
  bool get canBeTargeted => isAlive && !isBanished;

  /// Whether this creature can be selected to act this turn.
  bool get canAct => isAlive && !isBanished && actionCooldown <= 0;
}

class StatusEffect {
  final String type; // burn, poison, regen, etc.
  final int damagePerTurn; // or heal per turn if negative
  int duration;

  StatusEffect({
    required this.type,
    required this.damagePerTurn,
    required this.duration,
  });

  void tickDuration() => duration--;
  bool get isExpired => duration <= 0;
}

class StatModifier {
  final String type; // attack_up, defense_down, etc.
  int duration;

  StatModifier({required this.type, required this.duration});

  void tickDuration() => duration--;
  bool get isExpired => duration <= 0;
}

enum MoveType { physical, elemental }

class FamilyMoveStyle {
  final String family;
  final String survivalArchetype;
  final String battleSpecialName;
  final String summary;

  const FamilyMoveStyle({
    required this.family,
    required this.survivalArchetype,
    required this.battleSpecialName,
    required this.summary,
  });
}

class BattleMove {
  final String name;
  final MoveType type;
  final String scalingStat; // For display/tracking
  final bool isSpecial; // True if level 5+ ability
  final String? family; // Required family for special moves

  const BattleMove({
    required this.name,
    required this.type,
    required this.scalingStat,
    this.isSpecial = false,
    this.family,
  });

  static const Map<String, FamilyMoveStyle> _familyStyles = {
    'Let': FamilyMoveStyle(
      family: 'Let',
      survivalArchetype: 'Meteor',
      battleSpecialName: 'Meteor Strike',
      summary:
          'Heavy elemental meteor burst with a deterministic rider payload (debuff, DoT, defense, or sustain by element).',
    ),
    'Pip': FamilyMoveStyle(
      family: 'Pip',
      survivalArchetype: 'Frenzy',
      battleSpecialName: 'Frenzy',
      summary:
          'Relentless multi-hit assault with escalating critical strike chance.',
    ),
    'Mane': FamilyMoveStyle(
      family: 'Mane',
      survivalArchetype: 'Barrage Volley',
      battleSpecialName: 'Entangle',
      summary:
          'Ensnares the enemy, weakening them while nourishing allies with regen.',
    ),
    'Mask': FamilyMoveStyle(
      family: 'Mask',
      survivalArchetype: 'Hex Field',
      battleSpecialName: 'Hex Field',
      summary:
          'Curses and debilitates the enemy; detonates existing curses for burst damage.',
    ),
    'Horn': FamilyMoveStyle(
      family: 'Horn',
      survivalArchetype: 'Fortress',
      battleSpecialName: 'Fortress',
      summary:
          'Raises protective shields for the team and taunts the enemy to draw fire.',
    ),
    'Wing': FamilyMoveStyle(
      family: 'Wing',
      survivalArchetype: 'Piercing Beam',
      battleSpecialName: 'Piercing Beam',
      summary: 'Devastating focused beam that tears through defenses.',
    ),
    'Kin': FamilyMoveStyle(
      family: 'Kin',
      survivalArchetype: 'Sanctuary',
      battleSpecialName: 'Sanctuary',
      summary:
          'Restores health to all allies, cleanses ailments, and bolsters defenses.',
    ),
    'Mystic': FamilyMoveStyle(
      family: 'Mystic',
      survivalArchetype: 'Arcane Orbitals',
      battleSpecialName: 'Arcane Orbitals',
      summary:
          'Summons arcane projectiles that strike repeatedly, then trigger a deterministic element payload.',
    ),
  };

  /// Cooldown turns for each family's special ability.
  static int specialCooldownForFamily(String? family) {
    switch (family) {
      case 'Let':
        return 4;
      case 'Pip':
        return 4;
      case 'Mane':
        return 5;
      case 'Horn':
        return 5;
      case 'Mask':
        return 6;
      case 'Wing':
        return 6;
      case 'Kin':
        return 5;
      case 'Mystic':
        return 5;
      default:
        return 4;
    }
  }

  /// Specials recover when using basics.
  /// Player creatures gain extra recovery at SPD thresholds:
  /// 2.0, 3.0, 4.0, and 4.8.
  static int specialRecoveryPerBasicForCombatant(BattleCombatant combatant) {
    if (combatant.instanceRef == null) {
      // Keep boss cadence stable; threshold recovery is for player creatures.
      return 1;
    }
    return specialRecoveryPerBasicForSpeed(combatant.statSpeed);
  }

  static int specialRecoveryPerBasicForSpeed(double statSpeed) {
    var recovery = 1; // baseline recovery per basic
    if (statSpeed >= 2.0) recovery++;
    if (statSpeed >= 3.0) recovery++;
    if (statSpeed >= 4.0) recovery++;
    if (statSpeed >= 4.8) recovery++;
    return recovery;
  }

  static FamilyMoveStyle styleForFamily(String family) {
    return _familyStyles[family] ??
        const FamilyMoveStyle(
          family: 'Unknown',
          survivalArchetype: 'Special',
          battleSpecialName: 'Special Attack',
          summary: 'Family special move.',
        );
  }

  /// Human-readable boss-mode summary that matches implemented behavior.
  static String specialSummaryForCombatant(BattleCombatant combatant) {
    final family = combatant.family;
    final element = combatant.types.isNotEmpty
        ? combatant.types.first
        : 'Normal';

    switch (family) {
      case 'Let':
        return _letMeteorSummaryForElement(element);
      case 'Pip':
        return _pipFrenzySummaryForElement(element);
      case 'Mane':
        return 'Entangle: applies Speed/Defense debuffs to target and grants team regen for 2 turns.';
      case 'Horn':
        return _hornFortressSummaryForElement(element);
      case 'Mask':
        return _maskHexSummaryForElement(element);
      case 'Wing':
        return _wingBeamSummaryForElement(element);
      case 'Kin':
        return _kinSanctuarySummaryForElement(element);
      case 'Mystic':
        return _mysticOrbitalsSummaryForElement(element);
      default:
        return styleForFamily(family).summary;
    }
  }

  static String _letMeteorSummaryForElement(String element) {
    switch (element) {
      case 'Fire':
        return 'Inferno Meteor: heavy burst with an intensified burn payload.';
      case 'Water':
        return 'Riptide Meteor: heavy burst that suppresses enemy speed and attack.';
      case 'Earth':
        return 'Bastion Meteor: heavy burst that fortifies the caster with defense and shielding.';
      case 'Air':
        return 'Tempest Meteor: heavy burst that shreds enemy tempo with speed pressure.';
      case 'Plant':
        return 'Thorn Meteor: heavy burst that applies bleed pressure and self-regeneration.';
      case 'Ice':
        return 'Permafrost Meteor: heavy burst with freeze and speed lock.';
      case 'Lightning':
        return 'Storm Meteor: heavy burst with jolt and a chance for aftershock damage.';
      case 'Poison':
        return 'Venom Meteor: heavy burst with guaranteed high-pressure poison.';
      case 'Steam':
        return 'Scald Meteor: heavy burst with burn plus attack suppression.';
      case 'Lava':
        return 'Magma Meteor: heavy burst with burn and armor break.';
      case 'Mud':
        return 'Quagmire Meteor: heavy burst with dual defense/speed suppression.';
      case 'Dust':
        return 'Sandblast Meteor: heavy burst with blind-style attack and speed suppression.';
      case 'Crystal':
        return 'Prism Meteor: heavy burst that grants a crystal barrier and defense up.';
      case 'Spirit':
        return 'Wraith Meteor: heavy burst that curses the target over time.';
      case 'Blood':
        return 'Hemorrhage Meteor: heavy burst that inflicts bleed and takes recoil.';
      case 'Light':
        return 'Dawn Meteor: heavy burst that empowers the caster and clears stat drops.';
      case 'Dark':
        return 'Eclipse Meteor: heavy burst that curses and weakens enemy offense.';
      default:
        return 'Meteor Strike: heavy burst with an element-specific rider payload.';
    }
  }

  static String _pipFrenzySummaryForElement(String element) {
    switch (element) {
      case 'Fire':
        return 'Blaze Frenzy: rapid combo with ignition pressure after sustained hits and combo cooldown swing.';
      case 'Water':
        return 'Riptide Frenzy: rapid combo that drags enemy tempo down and disrupts boss special pacing.';
      case 'Earth':
        return 'Bastion Frenzy: rapid combo that hardens the user with defense and shield.';
      case 'Air':
        return 'Tempest Frenzy: rapid combo with evasive tempo disruption.';
      case 'Plant':
        return 'Bramble Frenzy: rapid combo that bleeds targets and sustains the user.';
      case 'Ice':
        return 'Frost Frenzy: rapid combo with freeze chance scaling by hit count.';
      case 'Lightning':
        return 'Storm Frenzy: rapid combo with jolt and overcharge burst after critical chains.';
      case 'Poison':
        return 'Venom Frenzy: rapid combo that applies escalating poison pressure with combo cooldown swing.';
      case 'Steam':
        return 'Scald Frenzy: rapid combo that burns while suppressing enemy attack.';
      case 'Lava':
        return 'Magma Frenzy: rapid combo that erodes armor with each surge.';
      case 'Mud':
        return 'Quagmire Frenzy: rapid combo that mud-locks speed and defense.';
      case 'Dust':
        return 'Sandveil Frenzy: rapid combo that blinds offense and tempo.';
      case 'Crystal':
        return 'Prism Frenzy: rapid combo that converts momentum into protective crystal shielding.';
      case 'Spirit':
        return 'Wraith Frenzy: rapid combo that curses over repeated impacts.';
      case 'Blood':
        return 'Hemorrhage Frenzy: rapid combo that trades recoil for bleed pressure.';
      case 'Light':
        return 'Dawn Frenzy: rapid combo that purifies debuffs and empowers offense.';
      case 'Dark':
        return 'Eclipse Frenzy: rapid combo that siphons life while weakening enemy offense.';
      default:
        return 'Frenzy combo: 2-4 rapid hits with escalating crits and combo-based cooldown swing.';
    }
  }

  static String _hornFortressSummaryForElement(String element) {
    if (element == 'Earth' || element == 'Crystal' || element == 'Light') {
      return 'Fortress Bastion: team shields + taunt with reflected damage and bulwark support riders.';
    }
    switch (element) {
      case 'Plant':
        return 'Fortress Bloom: team shields + taunt with regeneration support.';
      case 'Poison':
      case 'Dark':
      case 'Mud':
      case 'Dust':
      case 'Lava':
        return 'Fortress Lockdown: team shields + taunt with boss special-delay pressure.';
      case 'Lightning':
        return 'Fortress Surge: team shields + taunt plus team tempo acceleration.';
      default:
        return 'Fortress: team shields + taunt, with element-specific defensive riders.';
    }
  }

  static String _maskHexSummaryForElement(String element) {
    switch (element) {
      case 'Poison':
      case 'Dark':
      case 'Spirit':
        return 'Hex Field: curse control with special-cycle disruption and seal pressure.';
      case 'Light':
        return 'Hex Field: curse control with buff dispel and attack-break pressure.';
      case 'Lightning':
        return 'Hex Field: curse control with unstable surge detonations.';
      default:
        return 'Hex Field: curse setup, detonation burst, and element-shaped debuff seals.';
    }
  }

  static String _wingBeamSummaryForElement(String element) {
    switch (element) {
      case 'Ice':
        return 'Glacial Lance: precision beam with freeze/slow execution.';
      case 'Dust':
        return 'Sandstorm Beam: deep piercing beam with blind-style debuffs.';
      case 'Lightning':
        return 'Stormrail Beam: precision beam with overcharge critical windows.';
      case 'Crystal':
        return 'Prism Lance: precision beam that converts impact into barrier utility.';
      case 'Dark':
        return 'Eclipse Lance: precision beam with lifesteal and offensive suppression.';
      default:
        return 'Piercing Beam: high single-target damage that partially ignores defense with element-specific payload.';
    }
  }

  static String _mysticOrbitalsSummaryForElement(String element) {
    switch (element) {
      case 'Light':
        return 'Solar Orbitals: 3-hit arcane burst with team purge + cooldown recovery support.';
      case 'Dark':
        return 'Void Orbitals: 3-hit arcane burst with curse pressure and offensive drain.';
      case 'Crystal':
        return 'Prism Orbitals: 3-hit arcane burst with team shielding and stabilizing wards.';
      case 'Lightning':
        return 'Storm Orbitals: 3-hit arcane burst with overcharge detonation windows.';
      case 'Spirit':
        return 'Wraith Orbitals: 3-hit arcane burst with amplified curse pressure.';
      default:
        return 'Arcane Orbitals: 3-hit arcane burst with deterministic element-specific payload.';
    }
  }

  static String _kinSanctuarySummaryForElement(String element) {
    switch (element) {
      case 'Fire':
        return 'Phoenix Rite: 18% team heal, cleanses freeze/curse/bleed + speed-down, then accelerates ally action recovery.';
      case 'Water':
        return 'Tide Benediction: 22% team heal, clears burn/poison/bleed/freeze and all negative stat drops, then recovers team special cooldown.';
      case 'Earth':
        return 'Rootbound Renewal: 20% team heal, clears poison + defense/speed-down, grants stronger defense + shields, then accelerates focused ally recovery.';
      case 'Air':
        return 'Gale Purification: 17% team heal, clears burn/poison + speed-down, then accelerates focused ally recovery.';
      case 'Plant':
        return 'Verdant Renewal: 24% team heal, clears poison/bleed, grants regen, then recovers team special cooldown.';
      case 'Ice':
        return 'Cryo Purge: 18% team heal, clears burn/freeze + attack/speed-down, grants longer defense-up, then accelerates focused ally recovery.';
      case 'Lightning':
        return 'Overclock Pulse: 16% team heal, clears freeze and all negative stat drops, then accelerates focused ally recovery.';
      case 'Poison':
        return 'Antivenom Distill: 14% team heal, only cleanses poison (with bonus anti-poison healing), skips defense-up, then delays boss special cycle.';
      case 'Steam':
        return 'Sterile Vapor: 19% team heal, clears burn/poison/curse + attack-down, then recovers team special cooldown.';
      case 'Lava':
        return 'Cauterize: 15% team heal, clears bleed/poison/burn + defense-down, skips defense-up, then delays boss special cycle.';
      case 'Mud':
        return 'Detox Slurry: 18% team heal, clears poison + defense/speed-down, then delays boss special cycle.';
      case 'Dust':
        return 'Abrasive Purge: 16% team heal, clears curse + attack/speed-down, then delays boss special cycle.';
      case 'Crystal':
        return 'Prism Sanctum: 18% team heal, purges all DoTs + curse/defense-down, grants shields, then accelerates focused ally recovery.';
      case 'Spirit':
        return 'Soul Recall: 17% team heal, clears curse/freeze/banish + attack/speed-down, can revive one ally once per battle, then accelerates focused ally recovery.';
      case 'Blood':
        return 'Blood Covenant: 16% team heal, clears bleed/poison + attack-down, sacrifices user HP to boost the weakest ally, then delays boss special cycle.';
      case 'Light':
        return 'Radiant Resurrection: 20% team heal, full negative purge, can revive one ally once per battle, then recovers team special cooldown.';
      case 'Dark':
        return 'Umbral Exorcism: 15% team heal, clears curse/banish + attack/speed-down, then delays boss special cycle.';
      default:
        return 'Sanctuary: team healing, selective cleansing, and cooldown support.';
    }
  }

  /// Human-readable key mechanics with exact odds/scaling notes for UI.
  static List<String> mechanicNotesForCombatant(BattleCombatant combatant) {
    final notes = <String>[
      'Element rider trigger: 30% on damaging attacks.',
      'Crit chance: 5% base (25% when Lightning-aligned).',
      'DoT and regen effects scale from source stats plus target HP with caps.',
    ];

    final family = combatant.family;
    final element = combatant.types.isNotEmpty ? combatant.types.first : '';

    if (family == 'Let') {
      notes.addAll(_letMechanicNotesForElement(element));
    }

    if (family == 'Pip') {
      notes.addAll(_pipMechanicNotesForElement(element));
    }

    if (family == 'Horn') {
      notes.addAll(_hornMechanicNotesForElement(element));
    }

    if (family == 'Mask') {
      notes.addAll(_maskMechanicNotesForElement(element));
    }

    if (family == 'Wing') {
      notes.addAll(_wingMechanicNotesForElement(element));
    }

    if (family == 'Mystic') {
      notes.addAll(_mysticMechanicNotesForElement(element));
    }

    if (family == 'Kin') {
      notes.addAll(_kinMechanicNotesForElement(element));
    }

    return notes;
  }

  static List<String> _letMechanicNotesForElement(String element) {
    final notes = <String>[
      'Meteor Strike deals 1.4x base damage and always applies its element payload.',
    ];
    switch (element) {
      case 'Fire':
        notes.add(
          'Payload: stronger 3-turn burn (higher DoT cap than baseline).',
        );
        break;
      case 'Water':
        notes.add(
          'Payload: applies speed-down (3 turns) and attack-down (1 turn).',
        );
        break;
      case 'Earth':
        notes.add(
          'Payload: grants defense-up (3 turns) and a personal shield.',
        );
        break;
      case 'Air':
        notes.add('Payload: applies speed-down for 2 turns.');
        break;
      case 'Plant':
        notes.add('Payload: applies bleed and root-style speed suppression.');
        break;
      case 'Ice':
        notes.add(
          'Payload: applies freeze (2 turns) and speed-down (2 turns).',
        );
        break;
      case 'Lightning':
        notes.add(
          'Payload: applies jolt and always triggers bonus aftershock damage.',
        );
        break;
      case 'Poison':
        notes.add('Payload: guaranteed 4-turn poison with stronger scaling.');
        notes.add('Toxic Catalyst: basic strikes have a 30% chance to poison.');
        break;
      case 'Steam':
        notes.add('Payload: applies burn (2 turns) and attack-down (2 turns).');
        break;
      case 'Lava':
        notes.add(
          'Payload: applies burn (2 turns) and defense-down (3 turns).',
        );
        break;
      case 'Mud':
        notes.add('Payload: applies defense-down and speed-down for 2 turns.');
        break;
      case 'Dust':
        notes.add('Payload: applies attack-down and speed-down for 2 turns.');
        break;
      case 'Crystal':
        notes.add('Payload: grants barrier and defense-up (2 turns).');
        break;
      case 'Spirit':
        notes.add('Payload: applies a 3-turn curse.');
        break;
      case 'Blood':
        notes.add('Payload: applies bleed and inflicts self-recoil.');
        break;
      case 'Light':
        notes.add(
          'Payload: grants attack-up (2 turns) and purges stat-down debuffs.',
        );
        break;
      case 'Dark':
        notes.add('Payload: applies curse and attack-down.');
        break;
      default:
        notes.add('Payload: applies element-specific pressure.');
        break;
    }
    return notes;
  }

  static List<String> _pipMechanicNotesForElement(String element) {
    final notes = <String>[
      'Frenzy hits 2-4 times; each hit uses 0.35x base damage.',
      'Crit ladder per hit: 10%, 20%, 30%, 40%.',
      'Combo economy: 3+ hits refund 1 special cooldown, 2+ crits refund +1, and 4-hit combos delay enemy special by 1.',
    ];
    switch (element) {
      case 'Fire':
        notes.add('Payload: 3+ hits ignite burn for 2 turns.');
        break;
      case 'Water':
        notes.add(
          'Payload: applies speed-down (2 turns); 4 hits also apply attack-down.',
        );
        break;
      case 'Earth':
        notes.add('Payload: grants defense-up (2 turns) and personal shield.');
        break;
      case 'Air':
        notes.add('Payload: applies speed-down and grants speed-up to user.');
        break;
      case 'Plant':
        notes.add(
          'Payload: applies bleed and restores user HP from combo damage.',
        );
        break;
      case 'Ice':
        notes.add('Payload: freeze chance scales by hit count (up to 45%).');
        break;
      case 'Lightning':
        notes.add(
          'Payload: jolts target; 2+ crits trigger overcharge bonus damage.',
        );
        break;
      case 'Poison':
        notes.add(
          'Payload: applies poison; 4 hits strengthens poison duration/intensity.',
        );
        break;
      case 'Steam':
        notes.add('Payload: applies burn and attack-down.');
        break;
      case 'Lava':
        notes.add('Payload: applies burn and defense-down.');
        break;
      case 'Mud':
        notes.add('Payload: applies defense-down and speed-down.');
        break;
      case 'Dust':
        notes.add('Payload: applies attack-down and speed-down.');
        break;
      case 'Crystal':
        notes.add('Payload: grants shield; extra shield when crits land.');
        break;
      case 'Spirit':
        notes.add('Payload: applies a 2-turn curse.');
        break;
      case 'Blood':
        notes.add(
          'Payload: applies bleed and inflicts recoil based on combo damage.',
        );
        break;
      case 'Light':
        notes.add(
          'Payload: purges own stat-down effects and grants attack-up.',
        );
        break;
      case 'Dark':
        notes.add('Payload: lifesteals combo damage and applies attack-down.');
        break;
      default:
        notes.add('Payload: element-specific utility follows the combo.');
        break;
    }
    return notes;
  }

  static List<String> _hornMechanicNotesForElement(String element) {
    final notes = <String>[
      'Fortress grants team shields and forces taunt targeting for 2 turns.',
      'Fortress spikes: while taunting with shield, incoming hits have 28% poison retaliation.',
    ];
    if (element == 'Earth' || element == 'Crystal' || element == 'Light') {
      notes.add(
        'Reflect profile: returns 30% while shield holds (18% if shield breaks).',
      );
    } else {
      notes.add('This element uses non-reflect Fortress riders.');
    }
    return notes;
  }

  static List<String> _maskMechanicNotesForElement(String element) {
    final notes = <String>[
      'Hex Field applies curse pressure and detonates existing curse for burst.',
      'Seal profile branches by element for control effects (stats, cooldowns, dispels, or DoT).',
    ];
    switch (element) {
      case 'Poison':
      case 'Dark':
      case 'Spirit':
        notes.add(
          'Control focus: special-cycle disruption and sustained debuff pressure.',
        );
        break;
      case 'Light':
        notes.add(
          'Control focus: strips enemy buffs and stabilizes pressure windows.',
        );
        break;
      case 'Lightning':
        notes.add(
          'Control focus: volatile detonation spikes after curse setup.',
        );
        break;
      default:
        notes.add(
          'Control focus: layered stat suppression around curse uptime.',
        );
        break;
    }
    return notes;
  }

  static List<String> _wingMechanicNotesForElement(String element) {
    final notes = <String>[
      'Piercing Beam is high single-target damage with partial defense bypass.',
      'Beam profile branches by element (pierce ratio, multiplier, and payload).',
    ];
    switch (element) {
      case 'Lightning':
        notes.add('Stormrail: includes overcharge crit window on the beam.');
        break;
      case 'Dust':
        notes.add(
          'Sandstorm: deepest defense pierce with blind-style suppression.',
        );
        break;
      case 'Ice':
        notes.add(
          'Glacial: higher defense retention but stronger freeze/slow control.',
        );
        break;
      default:
        notes.add(
          'Element payload adds targeted control or sustain after beam impact.',
        );
        break;
    }
    return notes;
  }

  static List<String> _mysticMechanicNotesForElement(String element) {
    final notes = <String>[
      'Arcane Orbitals hit 3 times, then trigger a deterministic element payload.',
      'Mystic payloads are heavier than baseline riders and tuned as ultimate-style effects.',
    ];
    switch (element) {
      case 'Light':
        notes.add('Support focus: purge + team cooldown recovery.');
        break;
      case 'Crystal':
        notes.add('Stabilization focus: team shielding and ward utility.');
        break;
      case 'Dark':
      case 'Spirit':
        notes.add(
          'Control focus: amplified curse pressure with offensive suppression.',
        );
        break;
      default:
        notes.add(
          'Payload focus: decisive single-target conversion after orbital burst.',
        );
        break;
    }
    return notes;
  }

  static List<String> _kinMechanicNotesForElement(String element) {
    switch (element) {
      case 'Fire':
        return const [
          'Cleanses: freeze, curse, bleed, and speed-down.',
          'Rider: reduces ally action cooldowns by 1 turn.',
        ];
      case 'Water':
        return const [
          'Cleanses: burn, poison, bleed, freeze, and all negative stat drops.',
          'Rider: reduces special cooldown by 1 for all allies on cooldown.',
        ];
      case 'Earth':
        return const [
          'Cleanses: poison plus defense/speed-down; adds team shields.',
          'Rider: accelerates the most delayed ally (special/action cooldown).',
        ];
      case 'Air':
        return const [
          'Cleanses: burn, poison, and speed-down.',
          'Rider: accelerates the most delayed ally (special/action cooldown).',
        ];
      case 'Plant':
        return const [
          'Cleanses: poison and bleed; applies team regen.',
          'Rider: reduces special cooldown by 1 for all allies on cooldown.',
        ];
      case 'Ice':
        return const [
          'Cleanses: burn, freeze, attack-down, and speed-down.',
          'Rider: accelerates the most delayed ally (special/action cooldown).',
        ];
      case 'Lightning':
        return const [
          'Cleanses: freeze and all negative stat drops.',
          'Rider: accelerates the most delayed ally (special/action cooldown).',
        ];
      case 'Poison':
        return const [
          'Cleanses: poison only; extra healing when poison is removed.',
          'Rider: delays boss special cycle and applies brief attack-down.',
        ];
      case 'Steam':
        return const [
          'Cleanses: burn, poison, curse, and attack-down.',
          'Rider: reduces special cooldown by 1 for all allies on cooldown.',
        ];
      case 'Lava':
        return const [
          'Cleanses: bleed, poison, burn, and defense-down.',
          'Rider: delays boss special cycle and applies brief attack-down.',
        ];
      case 'Mud':
        return const [
          'Cleanses: poison plus defense/speed-down.',
          'Rider: delays boss special cycle and applies brief attack-down.',
        ];
      case 'Dust':
        return const [
          'Cleanses: curse, attack-down, and speed-down.',
          'Rider: delays boss special cycle and applies brief attack-down.',
        ];
      case 'Crystal':
        return const [
          'Cleanses: all DoTs plus curse and defense-down; adds team shields.',
          'Rider: accelerates the most delayed ally (special/action cooldown).',
        ];
      case 'Spirit':
        return const [
          'Cleanses: curse, freeze, banish, attack-down, and speed-down.',
          'Rider: one revival per battle and focused ally acceleration.',
        ];
      case 'Blood':
        return const [
          'Cleanses: bleed, poison, and attack-down; user pays HP to empower weakest ally.',
          'Rider: delays boss special cycle and applies brief attack-down.',
        ];
      case 'Light':
        return const [
          'Cleanses: full negative purge (DoTs, freeze/banish, and stat drops).',
          'Rider: one revival per battle and teamwide special cooldown recovery.',
        ];
      case 'Dark':
        return const [
          'Cleanses: curse, banish, attack-down, and speed-down.',
          'Rider: delays boss special cycle and applies brief attack-down.',
        ];
      default:
        return const [
          'Sanctuary applies healing, cleansing, and cooldown support.',
        ];
    }
  }

  /// Boss-only gimmick summary keyed to the current implemented mechanics.
  static String bossGimmickSummaryForCombatant(BattleCombatant combatant) {
    switch (combatant.id) {
      case 'boss_001':
        return 'Inferno Execution: attacks deal double damage to burned targets.';
      case 'boss_002':
        return 'Undertow Control: slows targets, then Aqua-jet punishes slowed enemies.';
      case 'boss_003':
        return 'Stone Bastion: repeatedly stacks defense and temporary shielding.';
      case 'boss_004':
        return 'Jetstream Evasion: speed buffs grant a dodge window against attacks.';
      case 'boss_005':
        return 'Overgrowth Sustain: regeneration pressure with teamwide slows.';
      case 'boss_006':
        return 'Shatter Pattern: frozen targets take bonus burst damage.';
      case 'boss_007':
        return 'Charge Engine: Charge-up stores a doubled next damaging strike.';
      case 'boss_008':
        return 'Toxic Execution: poisoned targets take heavy bonus damage.';
      case 'boss_009':
        return 'Scalding Tempo: steam attacks spread burns and keep offensive pace.';
      case 'boss_010':
        return 'Molten Armor: attackers are burned while lava debuffs shred defenses.';
      case 'boss_011':
        return 'Sink Cycle: submerges for a turn, then returns with a boosted ambush.';
      case 'boss_012':
        return 'Mirage Screen: creates copies that absorb incoming hits.';
      case 'boss_013':
        return 'Prism Retaliation: elemental hits are reflected while shielded.';
      case 'boss_014':
        return 'Ethereal Purge: curses enemies and periodically self-cleanses.';
      case 'boss_015':
        return 'Void Banish: Eclipse banishes the highest damage dealer for 5 turns.';
      case 'boss_016':
        return 'Radiant Aegis: on first drop below 50% HP, gains a holy barrier.';
      case 'boss_017':
        return 'Blood Frenzy: damage scales up as HP drops, with bleed pressure.';
      default:
        return 'No unique boss special configured.';
    }
  }

  static String _formatElementalSpecialName(
    String family,
    String element,
    String baseName,
  ) {
    switch (family) {
      case 'Wing':
        switch (element) {
          case 'Ice':
            return 'Glacial Lance';
          case 'Dust':
            return 'Sandstorm Beam';
          case 'Lightning':
            return 'Stormrail Beam';
          case 'Fire':
            return 'Flare Lance';
          default:
            return '$element $baseName';
        }
      case 'Mask':
        return '$element Hex Field';
      case 'Mystic':
        return '$element Orbitals';
      default:
        return '$element $baseName';
    }
  }

  /// Element-aware special move (used for both move labels and behavior routing).
  static BattleMove getSpecialMoveForCombatant(BattleCombatant combatant) {
    final base = getSpecialMove(combatant.family);
    final element = combatant.types.isNotEmpty ? combatant.types.first : '';
    if (element.isEmpty) return base;
    return BattleMove(
      name: _formatElementalSpecialName(combatant.family, element, base.name),
      type: base.type,
      scalingStat: base.scalingStat,
      isSpecial: base.isSpecial,
      family: base.family,
    );
  }

  // Basic moves from BasicAtks.csv
  static BattleMove getBasicMove(String family) {
    switch (family) {
      case 'Let':
        return const BattleMove(
          name: 'Catalyst Strike',
          type: MoveType.physical,
          scalingStat: 'statSpeed',
        );
      case 'Pip':
        return const BattleMove(
          name: 'Reagent Strike',
          type: MoveType.physical,
          scalingStat: 'statStrength',
        );
      case 'Mane':
        return const BattleMove(
          name: 'Aether Strike',
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
        );
      case 'Horn':
        return const BattleMove(
          name: 'Crucible Strike',
          type: MoveType.physical,
          scalingStat: 'statStrength',
        );
      case 'Mask':
        return const BattleMove(
          name: 'Sigil Strike',
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
        );
      case 'Wing':
        return const BattleMove(
          name: 'Flux Strike',
          type: MoveType.physical,
          scalingStat: 'statSpeed',
        );
      case 'Kin':
        return const BattleMove(
          name: 'Alloy Strike',
          type: MoveType.physical,
          scalingStat: 'statStrength',
        );
      case 'Mystic':
        return const BattleMove(
          name: 'Quintessence Strike',
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
        );
      default:
        return const BattleMove(
          name: 'Strike',
          type: MoveType.physical,
          scalingStat: 'statStrength',
        );
    }
  }

  // Special abilities from SpecialAbilities.csv
  static BattleMove getSpecialMove(String family) {
    final style = styleForFamily(family);
    switch (family) {
      case 'Let':
        return BattleMove(
          name: style.battleSpecialName,
          type: MoveType.physical,
          scalingStat: 'statSpeed',
          isSpecial: true,
          family: 'Let',
        );
      case 'Pip':
        return BattleMove(
          name: style.battleSpecialName,
          type: MoveType.physical,
          scalingStat: 'statStrength',
          isSpecial: true,
          family: 'Pip',
        );
      case 'Mane':
        return BattleMove(
          name: style.battleSpecialName,
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
          isSpecial: true,
          family: 'Mane',
        );
      case 'Horn':
        return BattleMove(
          name: style.battleSpecialName,
          type: MoveType.physical,
          scalingStat: 'statStrength',
          isSpecial: true,
          family: 'Horn',
        );
      case 'Mask':
        return BattleMove(
          name: style.battleSpecialName,
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
          isSpecial: true,
          family: 'Mask',
        );
      case 'Wing':
        return BattleMove(
          name: style.battleSpecialName,
          type: MoveType.physical,
          scalingStat: 'statSpeed',
          isSpecial: true,
          family: 'Wing',
        );
      case 'Kin':
        return BattleMove(
          name: style.battleSpecialName,
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
          isSpecial: true,
          family: 'Kin',
        );
      case 'Mystic':
        return BattleMove(
          name: style.battleSpecialName,
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
          isSpecial: true,
          family: 'Mystic',
        );
      default:
        return const BattleMove(
          name: 'Special Attack',
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
          isSpecial: true,
        );
    }
  }
}

class BattleAction {
  final BattleCombatant actor;
  final BattleMove move;
  final BattleCombatant target;

  const BattleAction({
    required this.actor,
    required this.move,
    required this.target,
  });
}

class BattleResult {
  final int damage;
  final bool isCritical;
  final double typeMultiplier;
  final List<String> messages;
  final bool targetDefeated;

  const BattleResult({
    required this.damage,
    required this.isCritical,
    required this.typeMultiplier,
    required this.messages,
    required this.targetDefeated,
  });
}

/// Main battle engine - handles all combat calculations
class BattleEngine {
  static bool isSurvivalMode = false;
  static final Random _random = Random();

  // Type effectiveness from AdvantagesLogic.csv
  static const Map<String, List<String>> typeChart = {
    'Fire': ['Plant', 'Ice'],
    'Water': ['Fire', 'Lava', 'Dust'],
    'Earth': ['Fire', 'Lightning', 'Poison'],
    'Air': ['Plant', 'Mud'],
    'Plant': ['Water', 'Earth', 'Mud'],
    'Ice': ['Plant', 'Earth', 'Air'],
    'Lightning': ['Water', 'Air'],
    'Poison': ['Plant', 'Water'],
    'Steam': ['Ice', 'Plant'],
    'Lava': ['Ice', 'Plant', 'Crystal'],
    'Mud': ['Fire', 'Lightning', 'Poison'],
    'Dust': ['Fire', 'Lightning'],
    'Crystal': ['Ice', 'Lightning'],
    'Spirit': ['Poison', 'Blood'],
    'Blood': ['Spirit', 'Earth'],
    'Light': ['Dark', 'Spirit', 'Poison'],
    'Dark': ['Light', 'Spirit'],
  };

  /// Calculate type effectiveness multiplier
  static double getTypeMultiplier(
    String attackType,
    List<String> defenderTypes,
  ) {
    for (final defenderType in defenderTypes) {
      // Super effective (x2)
      if (typeChart[attackType]?.contains(defenderType) ?? false) {
        return 2.0;
      }

      // Not very effective (x0.5) - reverse lookup
      if (typeChart[defenderType]?.contains(attackType) ?? false) {
        return 0.5;
      }
    }

    return 1.0; // Neutral
  }

  /// Calculate base damage using formulas from GameplayInfo.csv
  static int calculateBaseDamage({
    required BattleMove move,
    required BattleCombatant attacker,
    required BattleCombatant defender,
  }) {
    int attackStat;
    int defenseStat;

    if (move.type == MoveType.physical) {
      attackStat = attacker.getEffectivePhysAtk();
      defenseStat = defender.getEffectivePhysDef();
    } else {
      attackStat = attacker.getEffectiveElemAtk();
      defenseStat = defender.getEffectiveElemDef();
    }

    // Base_Damage = (Attacker_Atk_Stat * 2) - Defender_Def_Stat
    final baseDamage = (attackStat * 2) - defenseStat;

    // Minimum 1 damage
    return max(baseDamage, 1);
  }

  /// Poison DoT scales from target HP baseline plus source elemental attack.
  /// Capped by a max % of target HP for balance in boss fights.
  static int calculatePoisonDotDamage({
    required BattleCombatant source,
    required BattleCombatant target,
    required double basePct,
    double elemScale = 0.22,
    double statusScale = 1.0,
    double maxPct = 0.10,
  }) {
    final base = target.maxHp * basePct * statusScale;
    final stat = source.getEffectiveElemAtk() * elemScale * statusScale;
    final raw = (base + stat).round();
    final cap = max(1, (target.maxHp * maxPct * statusScale).round());
    return max(1, min(cap, raw));
  }

  /// Generic DoT scaler for non-poison ailments.
  static int calculateDotDamage({
    required BattleCombatant source,
    required BattleCombatant target,
    required double basePct,
    double statScale = 0.20,
    double statusScale = 1.0,
    double maxPct = 0.10,
    bool usePhysicalStat = false,
  }) {
    final base = target.maxHp * basePct * statusScale;
    final atkStat = usePhysicalStat
        ? source.getEffectivePhysAtk()
        : source.getEffectiveElemAtk();
    final stat = atkStat * statScale * statusScale;
    final raw = (base + stat).round();
    final cap = max(1, (target.maxHp * maxPct * statusScale).round());
    return max(1, min(cap, raw));
  }

  /// Regeneration tick scaler (returned as positive healing amount).
  static int calculateRegenHealingTick({
    required BattleCombatant source,
    required BattleCombatant target,
    required double basePct,
    double statScale = 0.18,
    double statusScale = 1.0,
    double maxPct = 0.10,
  }) {
    final base = target.maxHp * basePct * statusScale;
    final stat = source.getEffectiveElemAtk() * statScale * statusScale;
    final raw = (base + stat).round();
    final cap = max(1, (target.maxHp * maxPct * statusScale).round());
    return max(1, min(cap, raw));
  }

  /// Execute a battle action and return results
  static BattleResult executeAction(
    BattleAction action, {
    List<BattleCombatant>? allyTeam,
  }) {
    final attacker = action.actor;
    final defender = action.target;
    final move = action.move;

    final blocked = resolveTurnBlock(attacker, move);
    if (blocked != null) return blocked;

    if (!defender.canBeTargeted) {
      return BattleResult(
        damage: 0,
        isCritical: false,
        typeMultiplier: 1.0,
        messages: [
          '${attacker.name} used ${move.name}!',
          '${defender.name} cannot be targeted right now.',
        ],
        targetDefeated: false,
      );
    }

    final messages = <String>[];
    int damage = 0;
    bool isCritical = false;
    double typeMultiplier = 1.0;

    messages.add('${attacker.name} used ${move.name}!');

    // Special move mechanics
    if (move.isSpecial) {
      // Set cooldown for all specials
      attacker.specialCooldown = BattleMove.specialCooldownForFamily(
        move.family,
      );

      final specialResult = _handleSpecialMove(
        action,
        messages,
        allyTeam: allyTeam,
      );
      if (specialResult != null) return specialResult;
    }

    // Calculate base damage
    damage = calculateBaseDamage(
      move: move,
      attacker: attacker,
      defender: defender,
    );

    // Type effectiveness
    if (attacker.types.isNotEmpty) {
      typeMultiplier = getTypeMultiplier(attacker.types.first, defender.types);

      if (typeMultiplier == 2.0) {
        messages.add("It's super effective!");
      } else if (typeMultiplier == 0.5) {
        messages.add("It's not very effective...");
      }

      damage = (damage * typeMultiplier).toInt();
    }

    // Lightning element: 20% higher crit chance
    final isLightning = attacker.types.contains('Lightning');
    final critChance = isLightning ? 0.25 : 0.05;

    if (_random.nextDouble() < critChance) {
      isCritical = true;
      damage = (damage * 1.5).toInt();
      messages.add('A critical hit!');
    }

    // Randomization (±10%)
    final variance = 0.9 + (_random.nextDouble() * 0.2);
    damage = (damage * variance).toInt();

    // Apply elemental effects (30% chance)
    if (_random.nextDouble() < 0.3) {
      _applyElementalEffect(attacker, defender, messages);
    }

    // Poison Let identity: basic strikes can inflict extra poison pressure.
    if (attacker.family == 'Let' &&
        attacker.types.contains('Poison') &&
        !move.isSpecial &&
        _random.nextDouble() < 0.30) {
      defender.applyStatusEffect(
        StatusEffect(
          type: 'poison',
          damagePerTurn: calculatePoisonDotDamage(
            source: attacker,
            target: defender,
            basePct: 0.04,
            elemScale: 0.24,
            maxPct: 0.085,
          ),
          duration: 3,
        ),
      );
      messages.add('Toxic Catalyst poisoned ${defender.name}!');
    }

    // Dark element: Lifesteal
    if (attacker.types.contains('Dark')) {
      final heal = (damage * 0.2).toInt();
      attacker.heal(heal);
      messages.add('${attacker.name} drained $heal HP!');
    }

    // Blood element: Empower (recoil)
    if (attacker.types.contains('Blood')) {
      damage = (damage * 1.25).toInt();
      final recoil = (attacker.maxHp * 0.05).toInt();
      attacker.takeDamage(recoil);
      messages.add('${attacker.name} took $recoil recoil damage!');
    }

    // Deal damage
    defender.takeDamage(damage);
    messages.add('${defender.name} took $damage damage!');

    return BattleResult(
      damage: damage,
      isCritical: isCritical,
      typeMultiplier: typeMultiplier,
      messages: messages,
      targetDefeated: defender.isDead,
    );
  }

  /// Resolves effects that prevent taking a turn (for now: freeze).
  /// Returns a prebuilt result when action is blocked, else null.
  static BattleResult? resolveTurnBlock(
    BattleCombatant actor,
    BattleMove move,
  ) {
    if (actor.isBanished) {
      return BattleResult(
        damage: 0,
        isCritical: false,
        typeMultiplier: 1.0,
        messages: [
          '${actor.name} used ${move.name}!',
          '${actor.name} is trapped in the void and cannot act!',
        ],
        targetDefeated: false,
      );
    }

    // Frozen: 30% chance to lose turn
    if (actor.statusEffects.containsKey('freeze')) {
      if (_random.nextDouble() < 0.3) {
        return BattleResult(
          damage: 0,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: [
            '${actor.name} used ${move.name}!',
            '${actor.name} is frozen solid!',
          ],
          targetDefeated: false,
        );
      }
    }

    return null;
  }

  static BattleResult? _handleSpecialMove(
    BattleAction action,
    List<String> messages, {
    List<BattleCombatant>? allyTeam,
  }) {
    final family = action.move.family;
    final attacker = action.actor;
    final defender = action.target;

    switch (family) {
      case 'Let': // Meteor Strike — Heavy burst + element-flavored DOT
        final meteorDamage =
            (calculateBaseDamage(
                      move: action.move,
                      attacker: attacker,
                      defender: defender,
                    ) *
                    1.4)
                .round();
        var totalDamage = meteorDamage;
        defender.takeDamage(meteorDamage);
        messages.add('Meteor Strike!');
        messages.add('${defender.name} took $meteorDamage damage!');
        final payloadDamage = _applyLetMeteorPayload(
          attacker,
          defender,
          messages,
        );
        totalDamage += payloadDamage;
        return BattleResult(
          damage: totalDamage,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: defender.isDead,
        );

      case 'Pip': // Frenzy — Multi-hit 2-4 times with escalating crit chance
        final hits = 2 + _random.nextInt(3); // 2-4 hits
        int totalDamage = 0;
        bool anyCrit = false;
        int critHits = 0;

        for (int i = 0; i < hits; i++) {
          var hitDamage =
              (calculateBaseDamage(
                        move: action.move,
                        attacker: attacker,
                        defender: defender,
                      ) *
                      0.35)
                  .toInt();

          // Each subsequent hit has higher crit chance: 10%, 20%, 30%, 40%
          final critChance = 0.10 + (i * 0.10);
          if (_random.nextDouble() < critChance) {
            hitDamage = (hitDamage * 1.5).toInt();
            anyCrit = true;
            critHits++;
          }

          defender.takeDamage(hitDamage);
          totalDamage += hitDamage;
        }

        final payloadDamage = _applyPipFrenzyPayload(
          attacker,
          defender,
          messages,
          hits: hits,
          totalComboDamage: totalDamage,
          critHits: critHits,
        );
        totalDamage += payloadDamage;

        messages.add('Hit $hits time${hits > 1 ? 's' : ''}!');
        if (anyCrit) messages.add('Critical strikes landed!');
        messages.add('${defender.name} took $totalDamage total damage!');

        return BattleResult(
          damage: totalDamage,
          isCritical: anyCrit,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: defender.isDead,
        );

      case 'Mane': // Entangle — Debuff boss + give allies regen
        // Slow and weaken the boss
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 3),
        );
        defender.applyStatModifier(
          StatModifier(type: 'defense_down', duration: 2),
        );
        messages.add('${defender.name} is entangled!');
        messages.add("${defender.name}'s Speed and Defense fell!");

        // Give all alive allies regen
        final allies = allyTeam ?? [attacker];
        for (final ally in allies) {
          if (ally.isAlive) {
            final regenTick = calculateRegenHealingTick(
              source: attacker,
              target: ally,
              basePct: 0.045,
              statScale: 0.18,
              maxPct: 0.10,
            );
            ally.applyStatusEffect(
              StatusEffect(
                type: 'regen',
                damagePerTurn: -regenTick,
                duration: 2,
              ),
            );
          }
        }
        messages.add('Allies are nourished — HP will regenerate!');

        return BattleResult(
          damage: 0,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: false,
        );

      case 'Horn': // Fortress — Team shield + taunt
        // Shield all alive allies
        final allies = allyTeam ?? [attacker];
        final element = attacker.types.isNotEmpty ? attacker.types.first : '';
        final grantsReflect =
            element == 'Earth' || element == 'Crystal' || element == 'Light';
        final shieldAmount = (attacker.maxHp * 0.15).toInt();
        for (final ally in allies) {
          if (ally.isAlive) {
            ally.shieldHp = (ally.shieldHp ?? 0) + shieldAmount;
            if (grantsReflect) {
              ally.applyStatusEffect(
                StatusEffect(
                  type: 'fortress_reflect',
                  damagePerTurn: 0,
                  duration: 2,
                ),
              );
            }
          }
        }
        messages.add('${attacker.name} raised Fortress!');
        messages.add('All allies gained $shieldAmount shield!');
        if (grantsReflect) {
          messages.add('Fortress shields will reflect incoming damage.');
        }

        // Apply taunt: boss must target this creature
        defender.tauntTargetId = attacker.id;
        defender.applyStatusEffect(
          StatusEffect(type: 'taunt', damagePerTurn: 0, duration: 2),
        );
        messages.add('${attacker.name} taunted ${defender.name}!');
        _applyHornFortressPayload(
          attacker,
          defender,
          allies,
          messages,
          element: element,
        );

        return BattleResult(
          damage: 0,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: false,
        );

      case 'Mask': // Hex Field — curse control + element-shaped debuff seals
        final element = attacker.types.isNotEmpty ? attacker.types.first : '';
        final alreadyCursed = defender.statusEffects.containsKey('curse');
        var totalDamage = 0;

        if (alreadyCursed) {
          final curseEffect = defender.statusEffects['curse']!;
          final burstMultiplier = _maskDetonationMultiplierForElement(element);
          final burstDamage =
              (curseEffect.damagePerTurn *
                      curseEffect.duration *
                      burstMultiplier)
                  .toInt();
          defender.statusEffects.remove('curse');
          defender.takeDamage(burstDamage);
          totalDamage += burstDamage;
          messages.add('Hex Field detonated the curse!');
          messages.add('${defender.name} took $burstDamage burst damage!');
        }

        var curseBasePct = alreadyCursed ? 0.05 : 0.06;
        var curseStatScale = alreadyCursed ? 0.20 : 0.22;
        var curseMaxPct = alreadyCursed ? 0.10 : 0.11;
        var curseDuration = 3;

        switch (element) {
          case 'Poison':
            curseBasePct += 0.01;
            curseStatScale += 0.02;
            curseMaxPct += 0.01;
            break;
          case 'Spirit':
            curseDuration = 4;
            break;
          case 'Light':
            curseDuration = 2;
            curseBasePct -= 0.005;
            break;
          case 'Ice':
          case 'Water':
            curseBasePct -= 0.005;
            break;
          default:
            break;
        }

        defender.applyStatusEffect(
          StatusEffect(
            type: 'curse',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: curseBasePct,
              statScale: curseStatScale,
              maxPct: curseMaxPct,
            ),
            duration: curseDuration,
          ),
        );

        if (!alreadyCursed) {
          defender.applyStatModifier(
            StatModifier(type: 'attack_down', duration: 2),
          );
          defender.applyStatModifier(
            StatModifier(type: 'speed_down', duration: 2),
          );
          messages.add('Hex Field curses ${defender.name}!');
          messages.add("${defender.name}'s Attack and Speed fell!");
        } else {
          messages.add('A fresh seal grips ${defender.name}!');
        }

        totalDamage += _applyMaskHexPayload(
          attacker,
          defender,
          messages,
          element: element,
          detonated: alreadyCursed,
        );

        return BattleResult(
          damage: totalDamage,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: defender.isDead,
        );

      case 'Wing': // Piercing Beam — Massive damage, partially ignores defense
        final element = attacker.types.isNotEmpty ? attacker.types.first : '';
        var defenseRetained = 0.50;
        var beamMultiplier = 1.60;
        var bonusCritChance = 0.0;
        String? prefaceMessage;

        switch (element) {
          case 'Fire':
            defenseRetained = 0.48;
            beamMultiplier = 1.52;
            prefaceMessage = 'Flare lance superheats the impact corridor!';
            break;
          case 'Water':
            defenseRetained = 0.52;
            beamMultiplier = 1.50;
            prefaceMessage = 'Tide lance compresses into a crushing current!';
            break;
          case 'Earth':
            defenseRetained = 0.44;
            beamMultiplier = 1.52;
            prefaceMessage = 'Seismic lance fractures armor plating!';
            break;
          case 'Air':
            defenseRetained = 0.47;
            beamMultiplier = 1.48;
            prefaceMessage = 'Jetstream lance bends around defenses!';
            break;
          case 'Plant':
            defenseRetained = 0.50;
            beamMultiplier = 1.48;
            prefaceMessage = 'Briar lance pierces with thorned force!';
            break;
          case 'Ice':
            defenseRetained = 0.55;
            beamMultiplier = 1.45;
            prefaceMessage = 'Glacial lance pins the target in place!';
            break;
          case 'Poison':
            defenseRetained = 0.50;
            beamMultiplier = 1.46;
            prefaceMessage = 'Venom lance leaves a toxic contrail!';
            break;
          case 'Steam':
            defenseRetained = 0.50;
            beamMultiplier = 1.44;
            prefaceMessage = 'Scald lance flashes into pressurized vapor!';
            break;
          case 'Lava':
            defenseRetained = 0.46;
            beamMultiplier = 1.50;
            prefaceMessage = 'Magma lance bores through hardened armor!';
            break;
          case 'Mud':
            defenseRetained = 0.45;
            beamMultiplier = 1.42;
            prefaceMessage = 'Quagmire lance drags everything into the mire!';
            break;
          case 'Dust':
            defenseRetained = 0.42;
            beamMultiplier = 1.35;
            prefaceMessage = 'Sandstorm beam blots out vision!';
            break;
          case 'Crystal':
            defenseRetained = 0.52;
            beamMultiplier = 1.48;
            prefaceMessage = 'Prism lance refracts into stabilizing shards!';
            break;
          case 'Spirit':
            defenseRetained = 0.50;
            beamMultiplier = 1.48;
            prefaceMessage = 'Wraith lance phases through resistance!';
            break;
          case 'Blood':
            defenseRetained = 0.49;
            beamMultiplier = 1.56;
            prefaceMessage = 'Hemolance tears through with sacrificial force!';
            break;
          case 'Light':
            defenseRetained = 0.50;
            beamMultiplier = 1.48;
            prefaceMessage = 'Dawn lance burns away corruption!';
            break;
          case 'Dark':
            defenseRetained = 0.47;
            beamMultiplier = 1.54;
            prefaceMessage = 'Eclipse lance siphons vitality in transit!';
            break;
          case 'Lightning':
            defenseRetained = 0.50;
            beamMultiplier = 1.50;
            bonusCritChance = 0.22;
            prefaceMessage = 'Stormrail beam crackles with charged force!';
            break;
          default:
            break;
        }

        if (prefaceMessage != null) {
          messages.add(prefaceMessage);
        }

        // Calculate damage with element-specific defense piercing profile.
        final attackStat = action.move.type == MoveType.physical
            ? attacker.getEffectivePhysAtk()
            : attacker.getEffectiveElemAtk();
        final defStat = action.move.type == MoveType.physical
            ? defender.getEffectivePhysDef()
            : defender.getEffectiveElemDef();
        final reducedDef = (defStat * defenseRetained).toInt();
        var beamDamage = max(1, (attackStat * 2) - reducedDef);
        beamDamage = (beamDamage * beamMultiplier).toInt();

        // Variance
        final variance = 0.9 + (_random.nextDouble() * 0.2);
        beamDamage = (beamDamage * variance).toInt();

        if (bonusCritChance > 0 && _random.nextDouble() < bonusCritChance) {
          beamDamage = (beamDamage * 1.35).toInt();
          messages.add('Overcharge critical!');
        }

        defender.takeDamage(beamDamage);
        var totalDamage = beamDamage;
        messages.add('Piercing Beam tears through defenses!');
        messages.add('${defender.name} took $beamDamage damage!');
        totalDamage += _applyWingBeamPayload(
          attacker,
          defender,
          messages,
          element: element,
          beamDamage: beamDamage,
        );

        return BattleResult(
          damage: totalDamage,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: defender.isDead,
        );

      case 'Kin': // Sanctuary — Team heal + cleanse negative effects + defense up
        final allies = allyTeam ?? [attacker];
        final element = attacker.types.isNotEmpty ? attacker.types.first : '';
        var healPct = 0.20;
        var fullNegativePurge = false;
        var cleanseAllDots = false;
        var cleanseAllNegativeStats = false;
        final statusCleanseKeys = <String>{};
        final statCleanseKeys = <String>{};
        var grantDefenseUp = true;
        var defenseDuration = 2;
        var teamShieldPct = 0.0;
        var regenBasePct = 0.0;
        var regenDuration = 0;
        var poisonBonusHealPct = 0.0;
        var lowestAllyBonusHealPct = 0.0;
        var attackerSelfCostPct = 0.0;
        var allowRevive = false;
        var revivePct = 0.0;
        var sanctuaryLabel = 'Sanctuary';

        switch (element) {
          case 'Fire':
            sanctuaryLabel = 'Phoenix Rite';
            healPct = 0.18;
            statusCleanseKeys.addAll({'freeze', 'curse', 'bleed'});
            statCleanseKeys.add('speed_down');
            defenseDuration = 1;
            break;
          case 'Water':
            sanctuaryLabel = 'Tide Benediction';
            healPct = 0.22;
            statusCleanseKeys.addAll({'burn', 'poison', 'bleed', 'freeze'});
            cleanseAllNegativeStats = true;
            break;
          case 'Earth':
            sanctuaryLabel = 'Rootbound Renewal';
            healPct = 0.20;
            statusCleanseKeys.addAll({'poison'});
            statCleanseKeys.addAll({'defense_down', 'speed_down'});
            teamShieldPct = 0.10;
            defenseDuration = 3;
            break;
          case 'Air':
            sanctuaryLabel = 'Gale Purification';
            healPct = 0.17;
            statusCleanseKeys.addAll({'burn', 'poison'});
            statCleanseKeys.add('speed_down');
            break;
          case 'Plant':
            sanctuaryLabel = 'Verdant Renewal';
            healPct = 0.24;
            statusCleanseKeys.addAll({'poison', 'bleed'});
            regenBasePct = 0.04;
            regenDuration = 3;
            break;
          case 'Ice':
            sanctuaryLabel = 'Cryo Purge';
            healPct = 0.18;
            statusCleanseKeys.addAll({'burn', 'freeze'});
            statCleanseKeys.addAll({'speed_down', 'attack_down'});
            defenseDuration = 3;
            break;
          case 'Lightning':
            sanctuaryLabel = 'Overclock Pulse';
            healPct = 0.16;
            statusCleanseKeys.add('freeze');
            cleanseAllNegativeStats = true;
            break;
          case 'Poison':
            sanctuaryLabel = 'Antivenom Distill';
            healPct = 0.14;
            statusCleanseKeys.add('poison');
            grantDefenseUp = false;
            poisonBonusHealPct = 0.08;
            break;
          case 'Steam':
            sanctuaryLabel = 'Sterile Vapor';
            healPct = 0.19;
            statusCleanseKeys.addAll({'burn', 'poison', 'curse'});
            statCleanseKeys.add('attack_down');
            break;
          case 'Lava':
            sanctuaryLabel = 'Cauterize';
            healPct = 0.15;
            statusCleanseKeys.addAll({'bleed', 'poison', 'burn'});
            statCleanseKeys.add('defense_down');
            grantDefenseUp = false;
            break;
          case 'Mud':
            sanctuaryLabel = 'Detox Slurry';
            healPct = 0.18;
            statusCleanseKeys.addAll({'poison'});
            statCleanseKeys.addAll({'defense_down', 'speed_down'});
            break;
          case 'Dust':
            sanctuaryLabel = 'Abrasive Purge';
            healPct = 0.16;
            statusCleanseKeys.add('curse');
            statCleanseKeys.addAll({'attack_down', 'speed_down'});
            break;
          case 'Crystal':
            sanctuaryLabel = 'Prism Sanctum';
            healPct = 0.18;
            cleanseAllDots = true;
            statusCleanseKeys.add('curse');
            statCleanseKeys.add('defense_down');
            teamShieldPct = 0.12;
            defenseDuration = 2;
            break;
          case 'Spirit':
            sanctuaryLabel = 'Soul Recall';
            healPct = 0.17;
            statusCleanseKeys.addAll({'curse', 'freeze', 'banished'});
            statCleanseKeys.addAll({'attack_down', 'speed_down'});
            allowRevive = true;
            revivePct = 0.22;
            break;
          case 'Blood':
            sanctuaryLabel = 'Blood Covenant';
            healPct = 0.16;
            statusCleanseKeys.addAll({'bleed', 'poison'});
            statCleanseKeys.add('attack_down');
            lowestAllyBonusHealPct = 0.12;
            attackerSelfCostPct = 0.06;
            grantDefenseUp = false;
            break;
          case 'Light':
            sanctuaryLabel = 'Radiant Resurrection';
            healPct = 0.20;
            fullNegativePurge = true;
            cleanseAllNegativeStats = true;
            allowRevive = true;
            revivePct = 0.28;
            defenseDuration = 3;
            break;
          case 'Dark':
            sanctuaryLabel = 'Umbral Exorcism';
            healPct = 0.15;
            statusCleanseKeys.addAll({'curse', 'banished'});
            statCleanseKeys.addAll({'attack_down', 'speed_down'});
            break;
          default:
            cleanseAllDots = true;
            statusCleanseKeys.add('freeze');
            cleanseAllNegativeStats = true;
            break;
        }

        var totalCleansed = 0;
        for (final ally in allies) {
          if (!ally.isAlive) continue;

          final healAmount = max(1, (ally.maxHp * healPct).round());
          ally.heal(healAmount);

          final removedStatuses = <String>[];
          if (fullNegativePurge) {
            for (final e in ally.statusEffects.entries) {
              final isNegative =
                  e.value.damagePerTurn > 0 ||
                  e.key == 'freeze' ||
                  e.key == 'banished';
              if (isNegative) removedStatuses.add(e.key);
            }
          } else {
            for (final e in ally.statusEffects.entries) {
              final isDot = e.value.damagePerTurn > 0;
              final shouldRemove =
                  statusCleanseKeys.contains(e.key) ||
                  (cleanseAllDots && isDot);
              if (shouldRemove) removedStatuses.add(e.key);
            }
          }
          for (final key in removedStatuses) {
            ally.statusEffects.remove(key);
          }

          final removedModifiers = <String>[];
          for (final key in ally.statModifiers.keys) {
            final isNegativeStat =
                key == 'attack_down' ||
                key == 'defense_down' ||
                key == 'speed_down';
            if (!isNegativeStat) continue;
            if (cleanseAllNegativeStats || statCleanseKeys.contains(key)) {
              removedModifiers.add(key);
            }
          }
          for (final key in removedModifiers) {
            ally.statModifiers.remove(key);
          }

          final hadPoison = removedStatuses.contains('poison');
          if (hadPoison && poisonBonusHealPct > 0) {
            final bonusHeal = max(1, (ally.maxHp * poisonBonusHealPct).round());
            ally.heal(bonusHeal);
          }

          totalCleansed += removedStatuses.length + removedModifiers.length;

          if (grantDefenseUp) {
            ally.applyStatModifier(
              StatModifier(type: 'defense_up', duration: defenseDuration),
            );
          }

          if (teamShieldPct > 0) {
            ally.shieldHp =
                (ally.shieldHp ?? 0) +
                max(1, (ally.maxHp * teamShieldPct).round());
          }

          if (regenBasePct > 0 && regenDuration > 0) {
            final regenTick = calculateRegenHealingTick(
              source: attacker,
              target: ally,
              basePct: regenBasePct,
              statScale: 0.16,
              maxPct: 0.09,
            );
            ally.applyStatusEffect(
              StatusEffect(
                type: 'regen',
                damagePerTurn: -regenTick,
                duration: regenDuration,
              ),
            );
          }
        }

        if (lowestAllyBonusHealPct > 0) {
          final lowest = allies
              .where((a) => a.isAlive)
              .fold<BattleCombatant?>(
                null,
                (best, current) =>
                    best == null || current.hpPercent < best.hpPercent
                    ? current
                    : best,
              );
          if (lowest != null) {
            lowest.heal(
              max(1, (lowest.maxHp * lowestAllyBonusHealPct).round()),
            );
          }
        }

        if (attackerSelfCostPct > 0) {
          final cost = max(1, (attacker.maxHp * attackerSelfCostPct).round());
          attacker.takeDamage(cost);
          messages.add(
            '${attacker.name} paid $cost HP to stabilize the ritual.',
          );
        }

        if (allowRevive) {
          final fallen = allies.where((a) => a.isDead).toList();
          if (fallen.isNotEmpty && !attacker.kinReviveUsed) {
            fallen.sort((a, b) {
              final levelCompare = b.level.compareTo(a.level);
              if (levelCompare != 0) return levelCompare;
              return b.maxHp.compareTo(a.maxHp);
            });
            final revived = fallen.first;
            revived.heal(max(1, (revived.maxHp * revivePct).round()));
            revived.actionCooldown = max(revived.actionCooldown, 2);
            // Freshly revived allies stand up with a brief defensive cover.
            revived.statusEffects.remove('banished');
            revived.statusEffects.remove('freeze');
            revived.statModifiers.remove('attack_down');
            revived.statModifiers.remove('defense_down');
            revived.statModifiers.remove('speed_down');
            revived.applyStatModifier(
              StatModifier(type: 'defense_up', duration: 1),
            );
            attacker.kinReviveUsed = true;
            messages.add('${revived.name} was revived by $sanctuaryLabel!');
          } else if (fallen.isNotEmpty && attacker.kinReviveUsed) {
            messages.add('Revival spark already spent for this Kin.');
          }
        }

        messages.add('${attacker.name} invoked Sanctuary!');
        messages.add('$sanctuaryLabel rippled through the party.');
        if (totalCleansed > 0) {
          messages.add('Purification removed $totalCleansed negative effects.');
        }
        if (grantDefenseUp) {
          messages.add('Team defenses were reinforced.');
        }
        if (teamShieldPct > 0) {
          messages.add('Prismatic warding granted temporary shields.');
        }

        switch (element) {
          case 'Fire':
            var accelerated = 0;
            for (final ally in allies) {
              if (!ally.isAlive || ally.actionCooldown <= 0) continue;
              ally.tickActionCooldown();
              accelerated++;
            }
            if (accelerated > 0) {
              messages.add('Phoenix Tempo accelerated team action recovery.');
            }
            break;
          case 'Water':
          case 'Plant':
          case 'Light':
          case 'Steam':
            var recovered = 0;
            for (final ally in allies) {
              if (!ally.isAlive || ally.specialCooldown <= 0) continue;
              ally.tickSpecialCooldown();
              recovered++;
            }
            if (recovered > 0) {
              messages.add(
                'Tide Harmony reduced special cooldowns across the team.',
              );
            }
            break;
          case 'Ice':
          case 'Crystal':
          case 'Earth':
          case 'Air':
          case 'Lightning':
          case 'Spirit':
            final focusTarget = allies
                .where((a) => a.isAlive)
                .fold<BattleCombatant?>(
                  null,
                  (best, current) =>
                      best == null ||
                          (current.specialCooldown + current.actionCooldown) >
                              (best.specialCooldown + best.actionCooldown)
                      ? current
                      : best,
                );
            if (focusTarget != null) {
              if (focusTarget.specialCooldown > 0) {
                focusTarget.tickSpecialCooldown();
                if (focusTarget.specialCooldown > 0) {
                  focusTarget.tickSpecialCooldown();
                }
              }
              if (focusTarget.actionCooldown > 0) {
                focusTarget.tickActionCooldown();
              }
              messages.add(
                'Focused Blessing accelerated ${focusTarget.name}\'s recovery.',
              );
            }
            break;
          case 'Dark':
          case 'Blood':
          case 'Dust':
          case 'Poison':
          case 'Mud':
          case 'Lava':
            defender.specialCooldown += 1;
            defender.applyStatModifier(
              StatModifier(type: 'attack_down', duration: 1),
            );
            messages.add(
              'Hexed Seal delayed ${defender.name}\'s special cycle.',
            );
            break;
          default:
            break;
        }

        return BattleResult(
          damage: 0,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: false,
        );

      case 'Mystic': // Arcane Orbitals — 3-hit burst + deterministic element payload
        attacker.isCharging = false;
        final hits = 3;
        int totalDamage = 0;
        for (int i = 0; i < hits; i++) {
          final hit =
              (calculateBaseDamage(
                        move: action.move,
                        attacker: attacker,
                        defender: defender,
                      ) *
                      0.45)
                  .toInt();
          defender.takeDamage(hit);
          totalDamage += hit;
        }
        messages.add('Arcane Orbitals struck $hits times!');
        messages.add('${defender.name} took $totalDamage total damage!');
        final element = attacker.types.isNotEmpty ? attacker.types.first : '';
        totalDamage += _applyMysticOrbitalPayload(
          attacker,
          defender,
          messages,
          allies: allyTeam ?? [attacker],
          element: element,
          orbitalDamage: totalDamage,
        );

        return BattleResult(
          damage: totalDamage,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: defender.isDead,
        );
    }

    return null;
  }

  static int _applyLetMeteorPayload(
    BattleCombatant attacker,
    BattleCombatant defender,
    List<String> messages,
  ) {
    if (attacker.types.isEmpty) return 0;

    final element = attacker.types.first;
    final statusScale = isSurvivalMode ? 0.5 : 1.0; // 50% in survival
    var bonusDamage = 0;

    switch (element) {
      case 'Fire':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'burn',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.055,
              statScale: 0.24,
              statusScale: statusScale,
              maxPct: 0.11,
            ),
            duration: 3,
          ),
        );
        messages.add('Inferno payload ignited ${defender.name}!');
        break;

      case 'Water':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 3),
        );
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 1),
        );
        messages.add('${defender.name} was dragged into undertow!');
        break;

      case 'Earth':
        attacker.applyStatModifier(
          StatModifier(type: 'defense_up', duration: 3),
        );
        attacker.shieldHp =
            (attacker.shieldHp ?? 0) + (attacker.maxHp * 0.12).toInt();
        messages.add('${attacker.name} fortified with earthen plating!');
        break;

      case 'Air':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 2),
        );
        bonusDamage = max(1, (defender.maxHp * 0.03).round());
        defender.takeDamage(bonusDamage);
        messages.add('Tempest shrapnel battered ${defender.name}!');
        break;

      case 'Plant':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'bleed',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.04,
              statScale: 0.20,
              statusScale: statusScale,
              maxPct: 0.085,
              usePhysicalStat: true,
            ),
            duration: 3,
          ),
        );
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 2),
        );
        messages.add('Thorn payload rooted ${defender.name} in place!');
        break;

      case 'Ice':
        defender.applyStatusEffect(
          StatusEffect(type: 'freeze', damagePerTurn: 0, duration: 2),
        );
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 2),
        );
        messages.add('${defender.name} was frozen by permafrost impact!');
        break;

      case 'Lightning':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        bonusDamage = max(1, (attacker.getEffectiveElemAtk() * 0.45).round());
        defender.takeDamage(bonusDamage);
        messages.add('Aftershock detonated for $bonusDamage bonus damage!');
        break;

      case 'Poison':
        final hadPoison = defender.statusEffects.containsKey('poison');
        defender.applyStatusEffect(
          StatusEffect(
            type: 'poison',
            damagePerTurn: calculatePoisonDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.055,
              elemScale: 0.24,
              statusScale: statusScale,
              maxPct: 0.10,
            ),
            duration: 4,
          ),
        );
        messages.add('${defender.name} was drenched in volatile venom!');
        if (hadPoison) {
          bonusDamage = max(1, (defender.maxHp * 0.04).round());
          defender.takeDamage(bonusDamage);
          messages.add('Toxic rupture dealt $bonusDamage bonus damage!');
        }
        break;

      case 'Steam':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'burn',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.035,
              statScale: 0.19,
              statusScale: statusScale,
              maxPct: 0.08,
            ),
            duration: 2,
          ),
        );
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 2),
        );
        messages.add('${defender.name} was scalded and weakened!');
        break;

      case 'Lava':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'burn',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.03,
              statScale: 0.18,
              statusScale: statusScale,
              maxPct: 0.075,
            ),
            duration: 2,
          ),
        );
        defender.applyStatModifier(
          StatModifier(type: 'defense_down', duration: 3),
        );
        messages.add('${defender.name} armor was melted by magma impact!');
        break;

      case 'Mud':
        defender.applyStatModifier(
          StatModifier(type: 'defense_down', duration: 2),
        );
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 2),
        );
        messages.add('${defender.name} was dragged into quagmire!');
        break;

      case 'Dust':
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 2),
        );
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 2),
        );
        messages.add('${defender.name} was disoriented by sandblast!');
        break;

      case 'Crystal':
        attacker.shieldHp =
            (attacker.shieldHp ?? 0) + (attacker.maxHp * 0.18).toInt();
        attacker.applyStatModifier(
          StatModifier(type: 'defense_up', duration: 2),
        );
        messages.add('${attacker.name} formed a prism barrier!');
        break;

      case 'Spirit':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'curse',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.05,
              statScale: 0.21,
              statusScale: statusScale,
              maxPct: 0.10,
            ),
            duration: 3,
          ),
        );
        messages.add('${defender.name} was haunted by wraithfire!');
        break;

      case 'Blood':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'bleed',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.045,
              statScale: 0.21,
              statusScale: statusScale,
              maxPct: 0.09,
              usePhysicalStat: true,
            ),
            duration: 3,
          ),
        );
        final recoil = max(1, (attacker.maxHp * 0.04).round());
        attacker.takeDamage(recoil);
        messages.add(
          '${attacker.name} paid $recoil recoil to fuel blood payload!',
        );
        break;

      case 'Light':
        for (final key in ['attack_down', 'defense_down', 'speed_down']) {
          attacker.statModifiers.remove(key);
        }
        attacker.applyStatModifier(
          StatModifier(type: 'attack_up', duration: 2),
        );
        messages.add('${attacker.name} was empowered by radiant surge!');
        break;

      case 'Dark':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'curse',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.04,
              statScale: 0.20,
              statusScale: statusScale,
              maxPct: 0.09,
            ),
            duration: 2,
          ),
        );
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 2),
        );
        messages.add('${defender.name} was eclipsed and weakened!');
        break;

      default:
        _applyElementalEffect(attacker, defender, messages);
        break;
    }

    return bonusDamage;
  }

  static int _applyPipFrenzyPayload(
    BattleCombatant attacker,
    BattleCombatant defender,
    List<String> messages, {
    required int hits,
    required int totalComboDamage,
    required int critHits,
  }) {
    if (attacker.types.isEmpty) return 0;

    final element = attacker.types.first;
    final statusScale = isSurvivalMode ? 0.5 : 1.0; // 50% in survival
    var bonusDamage = 0;
    var refunded = 0;

    if (hits >= 3 && attacker.specialCooldown > 0) {
      attacker.tickSpecialCooldown();
      refunded++;
    }
    if (critHits >= 2 && attacker.specialCooldown > 0) {
      attacker.tickSpecialCooldown();
      refunded++;
    }
    if (refunded > 0) {
      messages.add(
        'Frenzy momentum refunded $refunded special cooldown turn${refunded == 1 ? '' : 's'}.',
      );
    }
    if (hits == 4) {
      defender.specialCooldown += 1;
      messages.add(
        '${defender.name} special cycle was delayed by combo pressure!',
      );
    }

    switch (element) {
      case 'Fire':
        if (hits >= 3) {
          defender.applyStatusEffect(
            StatusEffect(
              type: 'burn',
              damagePerTurn: calculateDotDamage(
                source: attacker,
                target: defender,
                basePct: 0.03,
                statScale: 0.18,
                statusScale: statusScale,
                maxPct: 0.075,
              ),
              duration: 2,
            ),
          );
          messages.add('Blaze combo ignited ${defender.name}!');
        }
        break;

      case 'Water':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 2),
        );
        if (hits == 4) {
          defender.applyStatModifier(
            StatModifier(type: 'attack_down', duration: 1),
          );
        }
        messages.add('${defender.name} was pulled by riptide pressure!');
        break;

      case 'Earth':
        if (hits >= 3) {
          attacker.applyStatModifier(
            StatModifier(type: 'defense_up', duration: 1),
          );
          var shieldGain = (attacker.maxHp * 0.06).toInt();
          if (hits == 4) shieldGain += (attacker.maxHp * 0.04).toInt();
          attacker.shieldHp = (attacker.shieldHp ?? 0) + shieldGain;
          messages.add('${attacker.name} formed earthen guard!');
        }
        break;

      case 'Air':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        attacker.applyStatModifier(StatModifier(type: 'speed_up', duration: 1));
        messages.add('${attacker.name} gained gust momentum!');
        break;

      case 'Plant':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'bleed',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.03,
              statScale: 0.17,
              statusScale: statusScale,
              maxPct: 0.07,
              usePhysicalStat: true,
            ),
            duration: 2,
          ),
        );
        final heal = max(1, (totalComboDamage * 0.15).round());
        attacker.heal(heal);
        messages.add('${attacker.name} siphoned $heal HP from bramble cuts!');
        break;

      case 'Ice':
        final freezeChance = min(0.45, 0.12 * hits);
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        if (_random.nextDouble() < freezeChance) {
          defender.applyStatusEffect(
            StatusEffect(type: 'freeze', damagePerTurn: 0, duration: 1),
          );
          messages.add('${defender.name} was frozen by frost combo!');
        } else {
          messages.add('${defender.name} was chilled by frost combo!');
        }
        break;

      case 'Lightning':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        if (critHits >= 2) {
          bonusDamage = max(1, (attacker.getEffectiveElemAtk() * 0.70).round());
          defender.takeDamage(bonusDamage);
          messages.add('Overcharge discharged for $bonusDamage bonus damage!');
        } else {
          messages.add('${defender.name} was jolted by storm combo!');
        }
        break;

      case 'Poison':
        final strengthened = hits == 4;
        defender.applyStatusEffect(
          StatusEffect(
            type: 'poison',
            damagePerTurn: calculatePoisonDotDamage(
              source: attacker,
              target: defender,
              basePct: strengthened ? 0.045 : 0.035,
              elemScale: strengthened ? 0.22 : 0.18,
              statusScale: statusScale,
              maxPct: strengthened ? 0.09 : 0.075,
            ),
            duration: strengthened ? 4 : 3,
          ),
        );
        messages.add(
          strengthened
              ? '${defender.name} suffered concentrated venom!'
              : '${defender.name} was poisoned by venom combo!',
        );
        break;

      case 'Steam':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'burn',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.028,
              statScale: 0.16,
              statusScale: statusScale,
              maxPct: 0.065,
            ),
            duration: 2,
          ),
        );
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 1),
        );
        messages.add('${defender.name} was scalded by steam flurry!');
        break;

      case 'Lava':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'burn',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.025,
              statScale: 0.16,
              statusScale: statusScale,
              maxPct: 0.06,
            ),
            duration: 2,
          ),
        );
        defender.applyStatModifier(
          StatModifier(type: 'defense_down', duration: 2),
        );
        messages.add('${defender.name} armor cracked from magma flurry!');
        break;

      case 'Mud':
        defender.applyStatModifier(
          StatModifier(type: 'defense_down', duration: 1),
        );
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        messages.add('${defender.name} was slowed in quagmire!');
        break;

      case 'Dust':
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 1),
        );
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        messages.add('${defender.name} was blinded by sandveil!');
        break;

      case 'Crystal':
        var shieldGain = (attacker.maxHp * 0.10).toInt();
        if (critHits > 0) {
          shieldGain += (attacker.maxHp * 0.06).toInt();
        }
        attacker.shieldHp = (attacker.shieldHp ?? 0) + shieldGain;
        messages.add('${attacker.name} crystallized $shieldGain shield!');
        break;

      case 'Spirit':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'curse',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.035,
              statScale: 0.18,
              statusScale: statusScale,
              maxPct: 0.075,
            ),
            duration: 2,
          ),
        );
        messages.add('${defender.name} was marked by wraith echoes!');
        break;

      case 'Blood':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'bleed',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.032,
              statScale: 0.18,
              statusScale: statusScale,
              maxPct: 0.072,
              usePhysicalStat: true,
            ),
            duration: 2,
          ),
        );
        final recoil = max(1, (totalComboDamage * 0.10).round());
        attacker.takeDamage(recoil);
        messages.add('${attacker.name} took $recoil recoil from blood frenzy!');
        break;

      case 'Light':
        for (final key in ['attack_down', 'defense_down', 'speed_down']) {
          attacker.statModifiers.remove(key);
        }
        attacker.applyStatModifier(
          StatModifier(type: 'attack_up', duration: 1),
        );
        messages.add('${attacker.name} was purified by dawn combo!');
        break;

      case 'Dark':
        final heal = max(1, (totalComboDamage * 0.12).round());
        attacker.heal(heal);
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 1),
        );
        messages.add('${attacker.name} siphoned $heal HP in eclipse flurry!');
        break;

      default:
        // Fallback to baseline elemental rider if no custom frenzy payload exists.
        _applyElementalEffect(attacker, defender, messages);
        break;
    }

    return bonusDamage;
  }

  static void _applyHornFortressPayload(
    BattleCombatant attacker,
    BattleCombatant defender,
    List<BattleCombatant> allies,
    List<String> messages, {
    required String element,
  }) {
    switch (element) {
      case 'Earth':
      case 'Crystal':
      case 'Light':
        for (final ally in allies) {
          if (!ally.isAlive) continue;
          ally.applyStatModifier(StatModifier(type: 'defense_up', duration: 1));
        }
        messages.add('Fortress bulwark reinforced team defenses.');
        break;
      case 'Plant':
        for (final ally in allies) {
          if (!ally.isAlive) continue;
          final regenTick = calculateRegenHealingTick(
            source: attacker,
            target: ally,
            basePct: 0.022,
            statScale: 0.14,
            maxPct: 0.06,
          );
          ally.applyStatusEffect(
            StatusEffect(type: 'regen', damagePerTurn: -regenTick, duration: 2),
          );
        }
        messages.add('Fortress bloom nourished the frontline.');
        break;
      case 'Lightning':
        var accelerated = 0;
        for (final ally in allies) {
          if (!ally.isAlive || ally.actionCooldown <= 0) continue;
          ally.tickActionCooldown();
          accelerated++;
        }
        if (accelerated > 0) {
          messages.add('Fortress surge accelerated allied action recovery.');
        }
        break;
      case 'Poison':
      case 'Dark':
      case 'Mud':
      case 'Dust':
      case 'Lava':
        defender.specialCooldown += 1;
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 1),
        );
        messages.add(
          'Fortress lockdown delayed ${defender.name}\'s special cycle.',
        );
        break;
      case 'Water':
      case 'Air':
      case 'Ice':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        messages.add('${defender.name} was slowed by Fortress pressure.');
        break;
      case 'Fire':
      case 'Steam':
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 1),
        );
        messages.add(
          '${defender.name}\'s offense was dampened by fortress heat.',
        );
        break;
      case 'Blood':
        final cost = max(1, (attacker.maxHp * 0.04).round());
        attacker.takeDamage(cost);
        for (final ally in allies) {
          if (!ally.isAlive) continue;
          ally.shieldHp =
              (ally.shieldHp ?? 0) + max(1, (ally.maxHp * 0.05).round());
        }
        messages.add(
          '${attacker.name} paid $cost HP to harden blood-forged shields.',
        );
        break;
      default:
        break;
    }
  }

  static double _maskDetonationMultiplierForElement(String element) {
    switch (element) {
      case 'Lightning':
        return 1.75;
      case 'Spirit':
        return 1.70;
      case 'Dark':
        return 1.65;
      case 'Poison':
        return 1.60;
      case 'Light':
        return 1.35;
      default:
        return 1.50;
    }
  }

  static int _applyMaskHexPayload(
    BattleCombatant attacker,
    BattleCombatant defender,
    List<String> messages, {
    required String element,
    required bool detonated,
  }) {
    final statusScale = isSurvivalMode ? 0.5 : 1.0;
    var bonusDamage = 0;

    switch (element) {
      case 'Fire':
      case 'Steam':
      case 'Lava':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'burn',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.028,
              statScale: 0.16,
              statusScale: statusScale,
              maxPct: 0.065,
            ),
            duration: 2,
          ),
        );
        if (element == 'Lava') {
          defender.applyStatModifier(
            StatModifier(type: 'defense_down', duration: 2),
          );
        } else {
          defender.applyStatModifier(
            StatModifier(type: 'attack_down', duration: 1),
          );
        }
        messages.add('Hexed flames scorched ${defender.name}.');
        break;
      case 'Water':
      case 'Air':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 2),
        );
        messages.add('${defender.name} was trapped in a dragging hex current.');
        break;
      case 'Ice':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 2),
        );
        if (detonated && _random.nextDouble() < 0.35) {
          defender.applyStatusEffect(
            StatusEffect(type: 'freeze', damagePerTurn: 0, duration: 1),
          );
          messages.add('${defender.name} was flash-frozen by the shatter hex!');
        }
        break;
      case 'Earth':
      case 'Plant':
      case 'Crystal':
        defender.applyStatModifier(
          StatModifier(type: 'defense_down', duration: 2),
        );
        messages.add('${defender.name} was sealed with fracture glyphs.');
        break;
      case 'Poison':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'poison',
            damagePerTurn: calculatePoisonDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.032,
              elemScale: 0.18,
              statusScale: statusScale,
              maxPct: 0.07,
            ),
            duration: 3,
          ),
        );
        if (detonated) {
          bonusDamage = max(1, (defender.maxHp * 0.03).round());
          defender.takeDamage(bonusDamage);
          messages.add('Toxic seal ruptured for $bonusDamage bonus damage!');
        }
        break;
      case 'Mud':
        defender.applyStatModifier(
          StatModifier(type: 'defense_down', duration: 1),
        );
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 2),
        );
        break;
      case 'Dust':
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 2),
        );
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        break;
      case 'Lightning':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        if (detonated) {
          bonusDamage = max(1, (attacker.getEffectiveElemAtk() * 0.60).round());
          defender.takeDamage(bonusDamage);
          messages.add('Storm sigil erupted for $bonusDamage bonus damage!');
        }
        break;
      case 'Light':
        for (final key in ['attack_up', 'defense_up', 'speed_up']) {
          defender.statModifiers.remove(key);
        }
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 1),
        );
        messages.add(
          'Radiant seal dispelled ${defender.name}\'s positive buffs.',
        );
        break;
      case 'Dark':
      case 'Spirit':
        defender.specialCooldown += 1;
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 1),
        );
        messages.add('A void seal delayed ${defender.name}\'s special cycle.');
        break;
      case 'Blood':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'bleed',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.03,
              statScale: 0.17,
              statusScale: statusScale,
              maxPct: 0.07,
              usePhysicalStat: true,
            ),
            duration: 2,
          ),
        );
        if (detonated) {
          final heal = max(1, (attacker.maxHp * 0.06).round());
          attacker.heal(heal);
          messages.add(
            '${attacker.name} siphoned $heal HP through blood sigils.',
          );
        }
        break;
      default:
        break;
    }

    return bonusDamage;
  }

  static int _applyWingBeamPayload(
    BattleCombatant attacker,
    BattleCombatant defender,
    List<String> messages, {
    required String element,
    required int beamDamage,
  }) {
    final statusScale = isSurvivalMode ? 0.5 : 1.0;
    var bonusDamage = 0;

    switch (element) {
      case 'Fire':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'burn',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.03,
              statScale: 0.17,
              statusScale: statusScale,
              maxPct: 0.07,
            ),
            duration: 2,
          ),
        );
        break;
      case 'Water':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 2),
        );
        break;
      case 'Earth':
        defender.applyStatModifier(
          StatModifier(type: 'defense_down', duration: 2),
        );
        break;
      case 'Air':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        attacker.applyStatModifier(StatModifier(type: 'speed_up', duration: 1));
        break;
      case 'Plant':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'bleed',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.028,
              statScale: 0.16,
              statusScale: statusScale,
              maxPct: 0.065,
              usePhysicalStat: true,
            ),
            duration: 2,
          ),
        );
        break;
      case 'Ice':
        defender.applyStatusEffect(
          StatusEffect(type: 'freeze', damagePerTurn: 0, duration: 1),
        );
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 2),
        );
        break;
      case 'Lightning':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        break;
      case 'Poison':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'poison',
            damagePerTurn: calculatePoisonDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.032,
              elemScale: 0.18,
              statusScale: statusScale,
              maxPct: 0.07,
            ),
            duration: 2,
          ),
        );
        break;
      case 'Steam':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'burn',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.025,
              statScale: 0.15,
              statusScale: statusScale,
              maxPct: 0.06,
            ),
            duration: 2,
          ),
        );
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 1),
        );
        break;
      case 'Lava':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'burn',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.024,
              statScale: 0.15,
              statusScale: statusScale,
              maxPct: 0.058,
            ),
            duration: 2,
          ),
        );
        defender.applyStatModifier(
          StatModifier(type: 'defense_down', duration: 2),
        );
        break;
      case 'Mud':
        defender.applyStatModifier(
          StatModifier(type: 'defense_down', duration: 1),
        );
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        break;
      case 'Dust':
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 2),
        );
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        break;
      case 'Crystal':
        attacker.shieldHp =
            (attacker.shieldHp ?? 0) + max(1, (attacker.maxHp * 0.08).round());
        attacker.applyStatModifier(
          StatModifier(type: 'defense_up', duration: 1),
        );
        break;
      case 'Spirit':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'curse',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.03,
              statScale: 0.17,
              statusScale: statusScale,
              maxPct: 0.07,
            ),
            duration: 2,
          ),
        );
        break;
      case 'Blood':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'bleed',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.03,
              statScale: 0.17,
              statusScale: statusScale,
              maxPct: 0.07,
              usePhysicalStat: true,
            ),
            duration: 2,
          ),
        );
        final recoil = max(1, (beamDamage * 0.10).round());
        attacker.takeDamage(recoil);
        messages.add('${attacker.name} took $recoil recoil from blood lance.');
        break;
      case 'Light':
        for (final key in ['attack_down', 'defense_down', 'speed_down']) {
          attacker.statModifiers.remove(key);
        }
        attacker.applyStatModifier(
          StatModifier(type: 'attack_up', duration: 1),
        );
        break;
      case 'Dark':
        final heal = max(1, (beamDamage * 0.18).round());
        attacker.heal(heal);
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 1),
        );
        messages.add('${attacker.name} siphoned $heal HP with eclipse lance.');
        break;
      default:
        _applyElementalEffect(attacker, defender, messages);
        break;
    }

    return bonusDamage;
  }

  static int _applyMysticOrbitalPayload(
    BattleCombatant attacker,
    BattleCombatant defender,
    List<String> messages, {
    required List<BattleCombatant> allies,
    required String element,
    required int orbitalDamage,
  }) {
    final statusScale = isSurvivalMode ? 0.5 : 1.0;
    var bonusDamage = 0;

    switch (element) {
      case 'Fire':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'burn',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.05,
              statScale: 0.22,
              statusScale: statusScale,
              maxPct: 0.10,
            ),
            duration: 3,
          ),
        );
        bonusDamage = max(1, (defender.maxHp * 0.04).round());
        defender.takeDamage(bonusDamage);
        messages.add('Solar collapse dealt $bonusDamage bonus damage!');
        break;
      case 'Water':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 2),
        );
        var recovered = 0;
        for (final ally in allies) {
          if (!ally.isAlive || ally.specialCooldown <= 0) continue;
          ally.tickSpecialCooldown();
          recovered++;
        }
        if (recovered > 0) {
          messages.add('Tide orbitals recovered team special cooldowns.');
        }
        break;
      case 'Earth':
        for (final ally in allies) {
          if (!ally.isAlive) continue;
          ally.applyStatModifier(StatModifier(type: 'defense_up', duration: 2));
          ally.shieldHp =
              (ally.shieldHp ?? 0) + max(1, (ally.maxHp * 0.10).round());
        }
        messages.add('Seismic orbitals raised a team bastion.');
        break;
      case 'Air':
        final focus = allies
            .where((a) => a.isAlive)
            .fold<BattleCombatant?>(
              null,
              (best, current) =>
                  best == null || current.actionCooldown > best.actionCooldown
                  ? current
                  : best,
            );
        if (focus != null && focus.actionCooldown > 0) {
          focus.tickActionCooldown();
          messages.add(
            'Jet orbitals accelerated ${focus.name}\'s action recovery.',
          );
        }
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        break;
      case 'Plant':
        for (final ally in allies) {
          if (!ally.isAlive) continue;
          final regenTick = calculateRegenHealingTick(
            source: attacker,
            target: ally,
            basePct: 0.03,
            statScale: 0.16,
            statusScale: statusScale,
            maxPct: 0.08,
          );
          ally.applyStatusEffect(
            StatusEffect(type: 'regen', damagePerTurn: -regenTick, duration: 2),
          );
        }
        messages.add('Verdant orbitals seeded team regeneration.');
        break;
      case 'Ice':
        defender.applyStatusEffect(
          StatusEffect(type: 'freeze', damagePerTurn: 0, duration: 2),
        );
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 2),
        );
        break;
      case 'Lightning':
        bonusDamage = max(1, (attacker.getEffectiveElemAtk() * 0.80).round());
        defender.takeDamage(bonusDamage);
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        messages.add('Overcharge orbitals detonated for $bonusDamage damage!');
        break;
      case 'Poison':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'poison',
            damagePerTurn: calculatePoisonDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.05,
              elemScale: 0.22,
              statusScale: statusScale,
              maxPct: 0.095,
            ),
            duration: 3,
          ),
        );
        defender.specialCooldown += 1;
        break;
      case 'Steam':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'burn',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.038,
              statScale: 0.19,
              statusScale: statusScale,
              maxPct: 0.08,
            ),
            duration: 2,
          ),
        );
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 2),
        );
        break;
      case 'Lava':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'burn',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.034,
              statScale: 0.18,
              statusScale: statusScale,
              maxPct: 0.075,
            ),
            duration: 2,
          ),
        );
        defender.applyStatModifier(
          StatModifier(type: 'defense_down', duration: 3),
        );
        break;
      case 'Mud':
        defender.applyStatModifier(
          StatModifier(type: 'defense_down', duration: 2),
        );
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 2),
        );
        break;
      case 'Dust':
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 2),
        );
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 2),
        );
        break;
      case 'Crystal':
        for (final ally in allies) {
          if (!ally.isAlive) continue;
          ally.shieldHp =
              (ally.shieldHp ?? 0) + max(1, (ally.maxHp * 0.12).round());
          ally.statModifiers.remove('defense_down');
        }
        messages.add('Prism orbitals stabilized the entire team.');
        break;
      case 'Spirit':
        final hadCurse = defender.statusEffects.containsKey('curse');
        defender.applyStatusEffect(
          StatusEffect(
            type: 'curse',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.05,
              statScale: 0.21,
              statusScale: statusScale,
              maxPct: 0.10,
            ),
            duration: 3,
          ),
        );
        if (hadCurse) {
          bonusDamage = max(1, (defender.maxHp * 0.03).round());
          defender.takeDamage(bonusDamage);
          messages.add('Wraith echo erupted for $bonusDamage bonus damage!');
        }
        break;
      case 'Blood':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'bleed',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.045,
              statScale: 0.20,
              statusScale: statusScale,
              maxPct: 0.09,
              usePhysicalStat: true,
            ),
            duration: 3,
          ),
        );
        final recoil = max(1, (attacker.maxHp * 0.05).round());
        attacker.takeDamage(recoil);
        final lowest = allies
            .where((a) => a.isAlive)
            .fold<BattleCombatant?>(
              null,
              (best, current) =>
                  best == null || current.hpPercent < best.hpPercent
                  ? current
                  : best,
            );
        if (lowest != null) {
          final heal = max(1, (lowest.maxHp * 0.08).round());
          lowest.heal(heal);
          messages.add(
            '${lowest.name} absorbed a $heal blood-orbital transfusion.',
          );
        }
        messages.add(
          '${attacker.name} paid $recoil HP to fuel blood orbitals.',
        );
        break;
      case 'Light':
        for (final ally in allies) {
          if (!ally.isAlive) continue;
          for (final key in ['attack_down', 'defense_down', 'speed_down']) {
            ally.statModifiers.remove(key);
          }
          if (ally.specialCooldown > 0) ally.tickSpecialCooldown();
        }
        attacker.applyStatModifier(
          StatModifier(type: 'attack_up', duration: 2),
        );
        messages.add('Radiant orbitals purified and recharged the team.');
        break;
      case 'Dark':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'curse',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.04,
              statScale: 0.20,
              statusScale: statusScale,
              maxPct: 0.09,
            ),
            duration: 2,
          ),
        );
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 2),
        );
        final heal = max(1, (orbitalDamage * 0.15).round());
        attacker.heal(heal);
        messages.add(
          '${attacker.name} siphoned $heal HP through void orbitals.',
        );
        break;
      default:
        _applyElementalEffect(attacker, defender, messages);
        break;
    }

    return bonusDamage;
  }

  static void _applyElementalEffect(
    BattleCombatant attacker,
    BattleCombatant defender,
    List<String> messages,
  ) {
    if (attacker.types.isEmpty) return;

    final element = attacker.types.first;
    final statusScale = isSurvivalMode ? 0.5 : 1.0; // 50% in survival

    switch (element) {
      case 'Fire':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'burn',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.04,
              statScale: 0.20,
              statusScale: statusScale,
              maxPct: 0.085,
            ),
            duration: 3,
          ),
        );
        messages.add('${defender.name} was burned!');
        break;

      case 'Poison':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'poison',
            damagePerTurn: calculatePoisonDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.045,
              elemScale: 0.22,
              statusScale: statusScale,
              maxPct: 0.09,
            ),
            duration: 3,
          ),
        );
        messages.add('${defender.name} was poisoned!');
        break;

      case 'Lava':
        defender.applyStatModifier(
          StatModifier(type: 'defense_down', duration: 3),
        );
        messages.add("${defender.name}'s Defense fell!");
        break;

      case 'Water':
      case 'Ice':
      case 'Mud':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 3),
        );
        messages.add("${defender.name}'s Speed fell!");

        if (element == 'Ice') {
          defender.applyStatusEffect(
            StatusEffect(type: 'freeze', damagePerTurn: 0, duration: 2),
          );
          messages.add('${defender.name} was frozen!');
        }
        break;

      case 'Earth':
        attacker.applyStatModifier(
          StatModifier(type: 'defense_up', duration: 3),
        );
        messages.add("${attacker.name}'s Defense rose!");
        break;

      case 'Crystal':
        attacker.shieldHp = (attacker.maxHp * 0.15).toInt();
        messages.add('${attacker.name} gained a barrier!');
        break;

      case 'Plant':
        final regenTick = calculateRegenHealingTick(
          source: attacker,
          target: attacker,
          basePct: 0.03,
          statScale: 0.16,
          statusScale: statusScale,
          maxPct: 0.08,
        );
        attacker.applyStatusEffect(
          StatusEffect(type: 'regen', damagePerTurn: -regenTick, duration: 3),
        );
        messages.add('${attacker.name} will regenerate HP!');
        break;

      case 'Light':
        attacker.applyStatModifier(
          StatModifier(type: 'attack_up', duration: 2),
        );
        messages.add("${attacker.name}'s Attack rose!");
        break;

      case 'Lightning':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        messages.add('${defender.name} was jolted!');
        break;

      case 'Air':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 2),
        );
        messages.add('${defender.name} was battered by gale force!');
        break;

      case 'Steam':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'burn',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.03,
              statScale: 0.18,
              statusScale: statusScale,
              maxPct: 0.075,
            ),
            duration: 2,
          ),
        );
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 1),
        );
        messages.add('${defender.name} was scalded by steam!');
        break;

      case 'Dust':
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 2),
        );
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        messages.add('${defender.name} was blinded by dust!');
        break;

      case 'Spirit':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'curse',
            damagePerTurn: calculateDotDamage(
              source: attacker,
              target: defender,
              basePct: 0.045,
              statScale: 0.20,
              statusScale: statusScale,
              maxPct: 0.095,
            ),
            duration: 2,
          ),
        );
        messages.add('${defender.name} was haunted!');
        break;
    }
  }

  /// Process end-of-turn effects (DoT, regen, etc.)
  static List<String> processEndOfTurnEffects(BattleCombatant combatant) {
    final messages = <String>[];

    // Banished units are out of phase: do not process incoming/outgoing
    // periodic damage while in the void, but timers still tick below.
    if (combatant.isBanished) {
      combatant.tickStatusEffects();
      combatant.tickStatModifiers();
      combatant.tickTaunt();
      return messages;
    }

    // Process status effects
    for (final effect in combatant.statusEffects.values) {
      if (effect.type == 'taunt') continue; // Taunt is not DoT
      if (effect.damagePerTurn > 0) {
        combatant.takeDamage(effect.damagePerTurn);
        messages.add(
          '${combatant.name} took ${effect.damagePerTurn} ${effect.type} damage!',
        );
      } else if (effect.damagePerTurn < 0) {
        final healing = -effect.damagePerTurn;
        combatant.heal(healing);
        messages.add('${combatant.name} recovered $healing HP!');
      }
    }

    combatant.tickStatusEffects();
    combatant.tickStatModifiers();
    combatant.tickTaunt();

    return messages;
  }

  /// Determine turn order based on speed
  static List<BattleCombatant> determineTurnOrder(
    List<BattleCombatant> combatants,
  ) {
    final sorted = List<BattleCombatant>.from(combatants);
    sorted.sort(
      (a, b) => b.getEffectiveSpeed().compareTo(a.getEffectiveSpeed()),
    );
    return sorted;
  }
}

extension BattleCombatantScaling on BattleCombatant {
  /// Returns a *copy* with scaled combat stats (HP, atk, def, speed).
  /// Visual refs (speciesRef / instanceRef) are preserved so sprites still work.
  BattleCombatant scaledCopy({
    required String newId,
    String? newName,
    double hpScale = 1.0,
    double atkScale = 1.0,
    double defScale = 1.0,
    double spdScale = 1.0,
  }) {
    final copy = BattleCombatant(
      id: newId,
      name: newName ?? name,
      types: types,
      family: family,
      statSpeed: statSpeed,
      statIntelligence: statIntelligence,
      statStrength: statStrength,
      statBeauty: statBeauty,
      level: level,
      instanceRef: instanceRef,
      speciesRef: speciesRef,
    );

    // Override the calculated combat stats
    copy.maxHp = (maxHp * hpScale).round();
    copy.currentHp = copy.maxHp;
    copy.physAtk = (physAtk * atkScale).round();
    copy.elemAtk = (elemAtk * atkScale).round();
    copy.physDef = (physDef * defScale).round();
    copy.elemDef = (elemDef * defScale).round();
    copy.speed = (speed * spdScale).round();

    return copy;
  }
}
