// Persistent battlefield ground-zone layer for boss battles.
//
// Mirrors the visual vocabulary of cosmic survival's
// `_drawMaskGroundZone` (poison pools, ice pillars, dark void spirals,
// crystal clusters, fire pools, vine brambles), translated to turn-based
// rules: each zone has a side (boss/player), a `turnsRemaining` counter,
// and a per-turn tick that applies an element-specific effect to the
// combatants on its side. Visuals are owned by `BattlefieldZoneLayer`
// (a Flame component); this file holds the data + tick semantics so the
// engine can stay UI-agnostic.

import 'dart:math';

import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';

/// Which side of the battlefield a zone occupies.
enum ZoneSide { boss, player }

/// One persistent ground hazard.
///
/// `family` + `element` drive the painter dispatch; `tickPctOfMax` is the
/// per-turn fraction of max HP applied to affected combatants. Statuses
/// applied on tick are described by `applyStatus` (a closure run against
/// each affected combatant) — keeping the closure off the model means
/// the registry doesn't have to know every status formula.
class BattlefieldZone {
  final String id;
  final String family; // e.g. 'mask', 'mane', 'let', 'mystic'
  final String element; // e.g. 'Poison', 'Fire', 'Ice', 'Dark'
  final ZoneSide side;
  int turnsRemaining;
  final double tickPctOfMax; // 0 for purely-cosmetic / status-only zones
  final String label; // human-readable, e.g. 'poison pool'
  final int spawnedAtTurn;

  BattlefieldZone({
    required this.id,
    required this.family,
    required this.element,
    required this.side,
    required this.turnsRemaining,
    required this.tickPctOfMax,
    required this.label,
    required this.spawnedAtTurn,
  });
}

/// Registry + tick driver for ground zones.
///
/// Constructed by the game layer (battle_game.dart) and assigned to
/// `BattleEngine.zoneRegistry` so payload helpers can call `spawnAt`
/// without knowing about the player/boss split.
class BattlefieldZoneRegistry {
  final BattleCombatant boss;
  final List<BattleCombatant> playerTeam;
  final List<BattlefieldZone> zones = [];

  int _turnCounter = 0;
  int _idCounter = 0;
  final List<String> _pendingSpawnMessages = [];

  BattlefieldZoneRegistry({required this.boss, required this.playerTeam});

  ZoneSide _sideOf(BattleCombatant c) =>
      c.id == boss.id ? ZoneSide.boss : ZoneSide.player;

  /// Spawn a zone on the side of `on`. Idempotent-ish: if a same
  /// family+element zone already exists on that side, its duration is
  /// refreshed instead of stacking — matches survival's "trap refresh"
  /// semantics and avoids painter pile-ups.
  ///
  /// Fresh spawns queue a player-facing announcement on
  /// `_pendingSpawnMessages`; refreshes stay silent. The engine drains
  /// the queue once per resolved action via [drainSpawnMessages] so
  /// new zones get a feed line instead of relying on the player
  /// spotting the painter in the post-cast rush.
  BattlefieldZone spawnAt(
    BattleCombatant on, {
    required String family,
    required String element,
    required int turns,
    required String label,
    double tickPctOfMax = 0.0,
  }) {
    final side = _sideOf(on);
    for (final existing in zones) {
      if (existing.side == side &&
          existing.family == family &&
          existing.element == element) {
        existing.turnsRemaining = max(existing.turnsRemaining, turns);
        return existing;
      }
    }
    final z = BattlefieldZone(
      id: 'z${_idCounter++}',
      family: family,
      element: element,
      side: side,
      turnsRemaining: turns,
      tickPctOfMax: tickPctOfMax,
      label: label,
      spawnedAtTurn: _turnCounter,
    );
    zones.add(z);
    final article = _startsWithVowel(label) ? 'An' : 'A';
    _pendingSpawnMessages.add(
      '$article $label takes hold at ${on.name}\'s feet.',
    );
    return z;
  }

  /// Pull and clear any pending fresh-spawn announcements queued by
  /// [spawnAt]. Safe to call when empty.
  List<String> drainSpawnMessages() {
    if (_pendingSpawnMessages.isEmpty) return const [];
    final out = List<String>.from(_pendingSpawnMessages);
    _pendingSpawnMessages.clear();
    return out;
  }

  static bool _startsWithVowel(String s) {
    if (s.isEmpty) return false;
    final c = s.codeUnitAt(0);
    return c == 0x61 ||
        c == 0x65 ||
        c == 0x69 ||
        c == 0x6F ||
        c == 0x75; // a/e/i/o/u
  }

  /// Apply per-turn zone effects and decrement durations.
  ///
  /// Returns user-facing messages so the caller can pipe them into the
  /// existing battle feed. Banished/dead combatants are skipped (the
  /// zone is geographic but they're not on the field).
  List<String> tick() {
    _turnCounter++;
    final messages = <String>[];
    final expired = <BattlefieldZone>[];

    for (final z in zones) {
      final affected = z.side == ZoneSide.boss
          ? [boss]
          : playerTeam.where((c) => c.isAlive && !c.isBanished).toList();
      for (final c in affected) {
        if (!c.isAlive || c.isBanished) continue;
        if (z.tickPctOfMax > 0) {
          final dmg = max(1, (c.maxHp * z.tickPctOfMax).round());
          c.takeDamage(dmg);
          messages.add('${c.name} took $dmg from the ${z.label}.');
        }
      }
      z.turnsRemaining--;
      if (z.turnsRemaining <= 0) expired.add(z);
    }

    if (expired.isNotEmpty) {
      zones.removeWhere(expired.contains);
    }
    return messages;
  }

  void clear() {
    zones.clear();
    _pendingSpawnMessages.clear();
    _turnCounter = 0;
    _idCounter = 0;
  }
}
