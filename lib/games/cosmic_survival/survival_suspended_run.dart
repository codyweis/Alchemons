// lib/games/cosmic_survival/survival_suspended_run.dart
//
// A survival run left to come back to. A run can last an hour, and its
// families' mastery is only paid when it ends, so leaving one has to keep it
// rather than end it: SAVE & EXIT in the pause menu, or the OS closing the
// app, leaves the run here and the lobby offers CONTINUE.
//
// What is kept is the run as it stood at the START of the wave in progress
// (a checkpoint taken as each wave begins). The wave itself is played again
// from its beginning, so anything that only lives inside a wave — enemies,
// projectiles, cooldowns, outbreaks, effects — is not kept; it all comes
// back from the wave. What is kept is what the run has built up: the picks,
// the meter, every hit point, who is out and who is down, the run's totals,
// and the party, guardian upgrades, orb, ship and mastery paths exactly as
// the run started with them.
//
// Leaving mid-wave never heals: each hit point is the lower of the wave's
// checkpoint and the moment of leaving ([SuspendedSurvivalRun.leftAt]).
//
// Saved as one JSON row in the settings table ([kSuspendedRunKey]), which
// cloud save already carries. One run at a time.

import 'dart:convert';
import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';

/// The settings key the suspended run is saved under.
const String kSuspendedRunKey = 'survival.suspended_run_v1';

/// Bumped whenever the shape below changes. A save of any other version is
/// dropped rather than read wrongly — except [kSuspendedRunLegacyVersion].
const int kSuspendedRunVersion = 2;

/// The version before [SuspendedSurvivalRun.deployedSlots] was kept. Still
/// read, with who was deployed worked out from what each slot had done.
const int kSuspendedRunLegacyVersion = 1;

/// Every pick the run can hold, by id, for replaying a saved history.
final Map<String, PowerUpDef> kSurvivalPowerUpsById = {
  for (final def in [...kAllPowerUps, ...kKeystonePowerUps]) def.id: def,
};

/// One pick, as the run's history holds it.
class SuspendedPick {
  const SuspendedPick({required this.id, this.targetSlot, this.targetName});

  final String id;
  final int? targetSlot;
  final String? targetName;

  Map<String, Object?> toJson() => {
    'id': id,
    if (targetSlot != null) 'slot': targetSlot,
    if (targetName != null) 'name': targetName,
  };

  static SuspendedPick fromJson(Map<String, dynamic> json) => SuspendedPick(
    id: json['id'] as String,
    targetSlot: (json['slot'] as num?)?.toInt(),
    targetName: json['name'] as String?,
  );
}

/// A party slot's health: a share of its maximum, and whether it is down.
class SuspendedSlotHealth {
  const SuspendedSlotHealth({
    required this.slot,
    required this.hp,
    required this.dead,
  });

  final int slot;

  /// 0..1 of the companion's max HP. Max HP is re-derived from the party,
  /// picks and paths, which are all kept, so a share restores it exactly.
  final double hp;
  final bool dead;

  Map<String, Object?> toJson() => {'slot': slot, 'hp': hp, 'dead': dead};

  static SuspendedSlotHealth fromJson(Map<String, dynamic> json) =>
      SuspendedSlotHealth(
        slot: (json['slot'] as num).toInt(),
        hp: (json['hp'] as num).toDouble(),
        dead: json['dead'] as bool,
      );
}

/// What one companion has done over the run, for the results.
class SuspendedSlotStats {
  const SuspendedSlotStats({
    required this.slot,
    required this.damageDealt,
    required this.kills,
    required this.damageTaken,
    required this.healingDone,
  });

  final int slot;
  final double damageDealt;
  final int kills;
  final double damageTaken;
  final double healingDone;

  Map<String, Object?> toJson() => {
    'slot': slot,
    'dealt': damageDealt,
    'kills': kills,
    'taken': damageTaken,
    'healed': healingDone,
  };

  static SuspendedSlotStats fromJson(Map<String, dynamic> json) =>
      SuspendedSlotStats(
        slot: (json['slot'] as num).toInt(),
        damageDealt: (json['dealt'] as num).toDouble(),
        kills: (json['kills'] as num).toInt(),
        damageTaken: (json['taken'] as num).toDouble(),
        healingDone: (json['healed'] as num).toDouble(),
      );
}

class SuspendedSurvivalRun {
  SuspendedSurvivalRun({
    this.version = kSuspendedRunVersion,
    required this.savedAtMs,
    required this.wave,
    required this.picks,
    required Set<int> phoenixUsed,
    required this.meter,
    required this.meterProgress,
    required this.orbMaxHp,
    required this.orbHp,
    required this.orbShield,
    required this.shipHp,
    required this.shipDead,
    required this.shipRespawnElapsed,
    required this.slots,
    required this.activeSlots,
    required this.tetheredSlot,
    required this.tetherMode,
    required this.kills,
    required this.score,
    required this.timeElapsed,
    required this.healingToMons,
    required this.healingToShip,
    required this.healingToOrb,
    required this.slotStats,
    Set<int> deployedSlots = const {},
    required this.party,
    required this.equippedOrb,
    required this.guardianLevels,
    required this.abilityLevels,
    required this.mastery,
    required this.shipSkin,
  }) : phoenixUsed = Set.unmodifiable(phoenixUsed),
       deployedSlots = Set.unmodifiable(deployedSlots);

  final int version;
  final int savedAtMs;

  /// The wave to play on continuing, from its beginning.
  final int wave;

  /// Every pick, in the order taken, so stacks, keystones, either-or
  /// choices and Mystic world levels rebuild exactly by replaying them.
  final List<SuspendedPick> picks;

  /// Slots whose one-time Phoenix Rebirth has been spent. (Revive picks
  /// are in [picks]; who they brought back is in [slots].)
  final Set<int> phoenixUsed;

  /// The alchemical meter, and the kill progress that paces how fast it
  /// fills from here.
  final double meter;
  final double meterProgress;

  final double orbMaxHp;
  final double orbHp;
  final int orbShield;

  final double shipHp;
  final bool shipDead;

  /// Seconds the ship has been down, toward its respawn.
  final double shipRespawnElapsed;

  /// Every party slot, in slot order.
  final List<SuspendedSlotHealth> slots;

  /// The slots that were out, in the order they were deployed.
  final List<int> activeSlots;
  final int? tetheredSlot;
  final bool tetherMode;

  final int kills;
  final int score;
  final double timeElapsed;
  final double healingToMons;
  final double healingToShip;
  final double healingToOrb;
  final List<SuspendedSlotStats> slotStats;

  /// Every slot summoned at some point in the run, for its mastery: a
  /// creature that went out earns more than one kept in reserve.
  final Set<int> deployedSlots;

  /// The party as it started: stats are frozen at the run's start, so the
  /// run plays on as it was, whatever has happened to the creatures since.
  final List<CosmicPartyMember> party;

  /// The guardian upgrades, orb and ship the run started with.
  final OrbBaseSkin equippedOrb;
  final Map<GuardianUpgrade, int> guardianLevels;
  final Map<BaseAbility, int> abilityLevels;
  final String? shipSkin;

  /// The mastery paths the run locked at its start.
  final SurvivalFamilyMasterySnapshot mastery;

  /// The upgrade state to build the run with: a copy, so Base Command
  /// cannot change a run that has been left.
  SurvivalUpgradeState get upgradeState => SurvivalUpgradeState(
    equippedSkin: equippedOrb,
    ownedSkins: {equippedOrb},
    guardianLevels: Map.of(guardianLevels),
    abilityLevels: Map.of(abilityLevels),
  );

  /// The run as left mid-wave: this run (the start of the wave in progress)
  /// with every hit point the lower of this and [atExit]. Leaving never
  /// heals. The picks, meter and totals stay at the wave's start, because the
  /// wave is played again and earns them again.
  SuspendedSurvivalRun leftAt(SuspendedSurvivalRun atExit, {int? savedAtMs}) {
    final exitSlots = {for (final s in atExit.slots) s.slot: s};
    final mergedSlots = [
      for (final s in slots)
        (() {
          final later = exitSlots[s.slot];
          if (later == null) return s;
          final dead = s.dead || later.dead;
          return SuspendedSlotHealth(
            slot: s.slot,
            hp: dead ? 0.0 : min(s.hp, later.hp),
            dead: dead,
          );
        })(),
    ];
    final down = {
      for (final s in mergedSlots)
        if (s.dead) s.slot,
    };

    // A Phoenix spent mid-wave stays spent, but only where the pick that
    // gave it is one this checkpoint holds; one picked mid-wave is picked
    // again in the replay, unspent.
    final phoenixHeld = {
      for (final p in picks)
        if (p.id == 'phoenix_rebirth' && p.targetSlot != null) p.targetSlot!,
    };
    final phoenix = {
      ...phoenixUsed,
      ...atExit.phoenixUsed.where(phoenixHeld.contains),
    };

    final shipHpLeft = min(shipHp, atExit.shipHp);
    final shipDown = shipDead || atExit.shipDead || shipHpLeft <= 0;
    // Down at both moments: the longer wait. Down at one: that one's.
    final respawn = !shipDown
        ? 0.0
        : shipDead && atExit.shipDead
        ? min(shipRespawnElapsed, atExit.shipRespawnElapsed)
        : atExit.shipDead
        ? atExit.shipRespawnElapsed
        : shipRespawnElapsed;

    return SuspendedSurvivalRun(
      savedAtMs: savedAtMs ?? atExit.savedAtMs,
      wave: wave,
      picks: picks,
      phoenixUsed: phoenix,
      meter: meter,
      meterProgress: meterProgress,
      orbMaxHp: orbMaxHp,
      orbHp: min(orbHp, atExit.orbHp).clamp(1.0, orbMaxHp).toDouble(),
      orbShield: min(orbShield, atExit.orbShield),
      shipHp: shipDown ? 0.0 : shipHpLeft,
      shipDead: shipDown,
      shipRespawnElapsed: respawn,
      slots: mergedSlots,
      // Who was out when the player left, less anyone now down.
      activeSlots: [
        for (final slot in atExit.activeSlots)
          if (!down.contains(slot)) slot,
      ],
      tetheredSlot: down.contains(atExit.tetheredSlot)
          ? null
          : atExit.tetheredSlot,
      tetherMode: atExit.tetherMode,
      kills: kills,
      score: score,
      timeElapsed: timeElapsed,
      healingToMons: healingToMons,
      healingToShip: healingToShip,
      healingToOrb: healingToOrb,
      slotStats: slotStats,
      // Deployed is for good: whoever went out before leaving went out.
      deployedSlots: {...deployedSlots, ...atExit.deployedSlots},
      party: party,
      equippedOrb: equippedOrb,
      guardianLevels: guardianLevels,
      abilityLevels: abilityLevels,
      mastery: mastery,
      shipSkin: shipSkin,
    );
  }

  // ── JSON ────────────────────────────────────────────────────────────

  Map<String, Object?> toJson() => {
    'v': version,
    'savedAt': savedAtMs,
    'wave': wave,
    'picks': [for (final p in picks) p.toJson()],
    'phoenixUsed': phoenixUsed.toList()..sort(),
    'meter': meter,
    'meterProgress': meterProgress,
    'orb': {'maxHp': orbMaxHp, 'hp': orbHp, 'shield': orbShield},
    'ship': {
      'hp': shipHp,
      'dead': shipDead,
      'respawnElapsed': shipRespawnElapsed,
    },
    'slots': [for (final s in slots) s.toJson()],
    'active': activeSlots,
    'tethered': tetheredSlot,
    'tetherMode': tetherMode,
    'stats': {
      'kills': kills,
      'score': score,
      'time': timeElapsed,
      'healToMons': healingToMons,
      'healToShip': healingToShip,
      'healToOrb': healingToOrb,
      'bySlot': [for (final s in slotStats) s.toJson()],
    },
    'deployed': deployedSlots.toList()..sort(),
    'party': [for (final m in party) _memberToJson(m)],
    'upgrades': {
      'orb': equippedOrb.name,
      'guardian': {
        for (final u in GuardianUpgrade.values) u.name: guardianLevels[u] ?? 0,
      },
      'abilities': {
        for (final a in BaseAbility.values) a.name: abilityLevels[a] ?? 0,
      },
    },
    'mastery': [
      for (final entry
          in mastery.bySlot.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key)))
        {
          'slot': entry.key,
          'instanceId': entry.value.instanceId,
          'family': entry.value.family.name,
          'path': entry.value.pathId,
          'nodes': entry.value.activeNodeIds.toList()..sort(),
        },
    ],
    'shipSkin': shipSkin,
  };

  String encode() => jsonEncode(toJson());

  /// Reads a saved run back, or null when it is not one this build can play
  /// (another version, or damaged) — the caller drops it.
  static SuspendedSurvivalRun? tryDecode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      if (json['v'] != kSuspendedRunVersion &&
          json['v'] != kSuspendedRunLegacyVersion) {
        return null;
      }
      return fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static SuspendedSurvivalRun fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> rows(Object? list) => [
      for (final row in list as List) row as Map<String, dynamic>,
    ];
    final orb = json['orb'] as Map<String, dynamic>;
    final ship = json['ship'] as Map<String, dynamic>;
    final stats = json['stats'] as Map<String, dynamic>;
    final upgrades = json['upgrades'] as Map<String, dynamic>;
    final guardian = upgrades['guardian'] as Map<String, dynamic>;
    final abilities = upgrades['abilities'] as Map<String, dynamic>;
    final party = [for (final row in rows(json['party'])) _memberFromJson(row)];
    final orbSkin = OrbBaseSkin.values.firstWhere(
      (s) => s.name == upgrades['orb'],
    );

    final mastery = <int, EquippedFamilyMastery>{};
    for (final row in rows(json['mastery'])) {
      final family = creatureFamilyFromStorage(row['family'] as String);
      if (family == null) throw const FormatException('mastery family');
      final slot = (row['slot'] as num).toInt();
      mastery[slot] = EquippedFamilyMastery(
        instanceId: row['instanceId'] as String,
        family: family,
        pathId: row['path'] as String,
        activeNodeIds: [for (final id in row['nodes'] as List) id as String],
      );
    }

    final picks = [
      for (final row in rows(json['picks'])) SuspendedPick.fromJson(row),
    ];
    // A pick this build no longer has cannot be replayed faithfully.
    for (final pick in picks) {
      if (!kSurvivalPowerUpsById.containsKey(pick.id)) {
        throw FormatException('unknown pick ${pick.id}');
      }
    }

    final slotStats = [
      for (final row in rows(stats['bySlot'])) SuspendedSlotStats.fromJson(row),
    ];
    final activeSlots = [
      for (final slot in json['active'] as List) (slot as num).toInt(),
    ];
    final deployed = json['deployed'];

    // Read back at this version: a legacy save gains its deployed slots
    // below, and is written at this version from then on.
    return SuspendedSurvivalRun(
      savedAtMs: (json['savedAt'] as num).toInt(),
      wave: (json['wave'] as num).toInt(),
      picks: picks,
      phoenixUsed: {
        for (final slot in json['phoenixUsed'] as List) (slot as num).toInt(),
      },
      meter: (json['meter'] as num).toDouble(),
      meterProgress: (json['meterProgress'] as num).toDouble(),
      orbMaxHp: (orb['maxHp'] as num).toDouble(),
      orbHp: (orb['hp'] as num).toDouble(),
      orbShield: (orb['shield'] as num).toInt(),
      shipHp: (ship['hp'] as num).toDouble(),
      shipDead: ship['dead'] as bool,
      shipRespawnElapsed: (ship['respawnElapsed'] as num).toDouble(),
      slots: [
        for (final row in rows(json['slots']))
          SuspendedSlotHealth.fromJson(row),
      ],
      activeSlots: activeSlots,
      tetheredSlot: (json['tethered'] as num?)?.toInt(),
      tetherMode: json['tetherMode'] as bool,
      kills: (stats['kills'] as num).toInt(),
      score: (stats['score'] as num).toInt(),
      timeElapsed: (stats['time'] as num).toDouble(),
      healingToMons: (stats['healToMons'] as num).toDouble(),
      healingToShip: (stats['healToShip'] as num).toDouble(),
      healingToOrb: (stats['healToOrb'] as num).toDouble(),
      slotStats: slotStats,
      // A legacy save never kept who went out: anyone out when it was
      // taken, or who had done anything by then, had been.
      deployedSlots: deployed is List
          ? {for (final slot in deployed) (slot as num).toInt()}
          : {
              ...activeSlots,
              for (final s in slotStats)
                if (s.damageDealt > 0 ||
                    s.kills > 0 ||
                    s.damageTaken > 0 ||
                    s.healingDone > 0)
                  s.slot,
            },
      party: party,
      equippedOrb: orbSkin,
      guardianLevels: {
        for (final u in GuardianUpgrade.values)
          u: (guardian[u.name] as num?)?.toInt() ?? 0,
      },
      abilityLevels: {
        for (final a in BaseAbility.values)
          a: (abilities[a.name] as num?)?.toInt() ?? 0,
      },
      mastery: SurvivalFamilyMasterySnapshot(mastery),
      shipSkin: json['shipSkin'] as String?,
    );
  }

  static Map<String, Object?> _memberToJson(CosmicPartyMember m) => {
    'instanceId': m.instanceId,
    'baseId': m.baseId,
    'name': m.displayName,
    'image': m.imagePath,
    'element': m.element,
    'family': m.family,
    'level': m.level,
    'speed': m.statSpeed,
    'intelligence': m.statIntelligence,
    'strength': m.statStrength,
    'beauty': m.statBeauty,
    'speedPotential': m.statSpeedPotential,
    'intelligencePotential': m.statIntelligencePotential,
    'strengthPotential': m.statStrengthPotential,
    'beautyPotential': m.statBeautyPotential,
    'slot': m.slotIndex,
    'staminaBars': m.staminaBars,
    'staminaMax': m.staminaMax,
  };

  /// The member as saved, without its sprite: the lobby shows still art, and
  /// a continued run puts the sprite back from the creature (see
  /// [withSprites]).
  static CosmicPartyMember _memberFromJson(Map<String, dynamic> json) =>
      CosmicPartyMember(
        instanceId: json['instanceId'] as String,
        baseId: json['baseId'] as String,
        displayName: json['name'] as String,
        imagePath: json['image'] as String?,
        element: json['element'] as String,
        family: json['family'] as String,
        level: (json['level'] as num).toInt(),
        statSpeed: (json['speed'] as num).toDouble(),
        statIntelligence: (json['intelligence'] as num).toDouble(),
        statStrength: (json['strength'] as num).toDouble(),
        statBeauty: (json['beauty'] as num).toDouble(),
        statSpeedPotential: (json['speedPotential'] as num).toDouble(),
        statIntelligencePotential: (json['intelligencePotential'] as num)
            .toDouble(),
        statStrengthPotential: (json['strengthPotential'] as num).toDouble(),
        statBeautyPotential: (json['beautyPotential'] as num).toDouble(),
        slotIndex: (json['slot'] as num).toInt(),
        staminaBars: (json['staminaBars'] as num).toInt(),
        staminaMax: (json['staminaMax'] as num).toInt(),
      );

  /// [member] with the sprite it is drawn with in a run. Everything else —
  /// its stats above all — stays as the run started with it.
  static CosmicPartyMember withSprite(
    CosmicPartyMember member, {
    required SpriteSheetDef? sheet,
    required SpriteVisuals? visuals,
  }) => CosmicPartyMember(
    instanceId: member.instanceId,
    baseId: member.baseId,
    displayName: member.displayName,
    imagePath: member.imagePath,
    element: member.element,
    family: member.family,
    level: member.level,
    statSpeed: member.statSpeed,
    statIntelligence: member.statIntelligence,
    statStrength: member.statStrength,
    statBeauty: member.statBeauty,
    statSpeedPotential: member.statSpeedPotential,
    statIntelligencePotential: member.statIntelligencePotential,
    statStrengthPotential: member.statStrengthPotential,
    statBeautyPotential: member.statBeautyPotential,
    slotIndex: member.slotIndex,
    staminaBars: member.staminaBars,
    staminaMax: member.staminaMax,
    spriteSheet: sheet,
    spriteVisuals: visuals,
  );

  @override
  bool operator ==(Object other) =>
      other is SuspendedSurvivalRun && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

/// Where the suspended run is kept: one settings row.
class SuspendedRunStore {
  SuspendedRunStore(this._db);

  final AlchemonsDatabase _db;

  /// The saved run, if there is one this build can play. A save it cannot
  /// read is dropped quietly.
  Future<SuspendedSurvivalRun?> load() async {
    final raw = await _db.settingsDao.getSetting(kSuspendedRunKey);
    if (raw == null || raw.isEmpty) return null;
    final run = SuspendedSurvivalRun.tryDecode(raw);
    if (run == null) await clear();
    return run;
  }

  Future<void> save(SuspendedSurvivalRun run) =>
      _db.settingsDao.setSetting(kSuspendedRunKey, run.encode());

  Future<void> clear() => _db.settingsDao.deleteSetting(kSuspendedRunKey);
}
