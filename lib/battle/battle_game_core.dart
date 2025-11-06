// lib/battle/vs_ai_battle_core.dart
// ---------------------------------
// Simultaneous-turn VS-AI core scaffolding for your bubble-toss battler.
// Drop-in, engine-agnostic. Wire it to FloatingBubblesOverlay by calling
// - battle.turn.onPlayerPlannedThrow(...)
// - battle.turn.commitIfReadyAndResolve(...)
// - battle.turn.tick(dt, bubbles)
// - battle.combat.onEnemyCollision(a,b)
// - battle.combat.onTouchNode(b,node)
// and by reading battle.state to drive HUD.
//
// This file intentionally avoids UI/Flutter widgets. It only models rules
// and timing. You can place it anywhere in lib/ (e.g., lib/battle/...).

import 'dart:math' as math;
import 'package:alchemons/battle/battle_stats.dart';
import 'package:alchemons/battle/fusion_system.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class Bubble {
  Offset pos;
  Offset vel;
  double radius;
  String element; // 'Fire', 'Water', ...
  int team; // 0 = player, 1 = AI
  String ownerInstanceId; // link to BattleCreature

  // Per-resolve bookkeeping
  bool thrownThisResolve = false;
  bool touchedWall = false;
  double summonLockout = 0; // seconds lockout for ally-combo summons

  Bubble({
    required this.pos,
    required this.vel,
    required this.radius,
    required this.element,
    required this.team,
    required this.ownerInstanceId,
  });
}

// ---------------------------------------------------------------------------
// Core enums & data models
// ---------------------------------------------------------------------------

enum Phase { planning, resolving, gameOver }

enum Side { player, ai }

class PlannedThrow {
  final Bubble bubble;
  final Offset aim; // normalized direction
  final double power; // 0..1 → map to speed
  PlannedThrow(this.bubble, this.aim, this.power);
}

class PlannedAction {
  final PlannedThrow? throw_;
  final BattleCreature? summon;

  PlannedAction.throw_(this.throw_) : summon = null;
  PlannedAction.summon(this.summon) : throw_ = null;

  bool get isThrow => throw_ != null;
  bool get isSummon => summon != null;

  @override
  String toString() {
    if (isThrow) return 'THROW(${throw_!.bubble.element})';
    if (isSummon) return 'SUMMON(${summon!.element})';
    return 'NONE';
  }
}

class BattleCreature {
  final CreatureInstance instance;
  final String element; // e.g., 'Fire'
  final String rarity; // 'Common'|'Uncommon'|'Rare'|'Legendary'
  final int team; // 0 or 1

  int hp;
  bool onField;
  bool summonable; // becomes false once summoned this battle
  Bubble? bubble; // present only when onField

  BattleCreature({
    required this.instance,
    required this.element,
    required this.rarity,
    required this.team,
    required this.hp,
    this.onField = false,
    this.summonable = true,
    this.bubble,
  });

  BattleCreature copyWith({
    CreatureInstance? instance,
    String? element,
    String? rarity,
    int? team,
    int? hp,
    bool? onField,
    bool? summonable,
    Bubble? bubble,
  }) {
    return BattleCreature(
      instance: instance ?? this.instance,
      element: element ?? this.element,
      rarity: rarity ?? this.rarity,
      team: team ?? this.team,
      hp: hp ?? this.hp,
      onField: onField ?? this.onField,
      summonable: summonable ?? this.summonable,
      bubble: bubble,
    );
  }
}

class TargetZone {
  final Offset center;
  final double rOuter, rMid, rInner; // radii
  const TargetZone(this.center, this.rOuter, this.rMid, this.rInner);
}

class ElementNode {
  final String element; // e.g., 'Steam', 'Crystal'
  Offset pos;
  bool consumed = false;
  ElementNode({required this.element, required this.pos});
}

// ---------------------------------------------------------------------------
// Battle config (tweakable knobs)
// ---------------------------------------------------------------------------

class BattleConfig {
  // Timing
  final double settleEps; // speed threshold
  final double settleHold; // seconds staying under eps
  final double maxResolveTime; // hard cap per resolve

  // Throwing
  final double maxThrowSpeed; // maps from power 0..1

  const BattleConfig({
    this.settleEps = 20.0,
    this.settleHold = 0.32,
    this.maxResolveTime = 2.6,
    this.maxThrowSpeed = 700.0,
  });
}

// ---------------------------------------------------------------------------
// Battle state container
// ---------------------------------------------------------------------------

class BattleState {
  Phase phase = Phase.planning;
  Side sideWithUI =
      Side.player; // who we show cues for; both plan simultaneously

  PlannedAction? actionPlayer;
  PlannedAction? actionAI;

  int scoreP = 0, scoreA = 0;

  final List<BattleCreature> playerBench;
  final List<BattleCreature> aiBench;
  final List<BattleCreature> playerField; // max 4
  final List<BattleCreature> aiField; // max 4

  TargetZone zoneP; // player's scoring zone
  TargetZone zoneA; // AI's scoring zone

  List<ElementNode> nodes = <ElementNode>[];

  // Resolve bookkeeping
  double _underEpsFor = 0;
  double _resolveTimer = 0;
  Bubble? thrownP; // who the player threw this resolve
  Bubble? thrownA; // who the AI threw this resolve

  BattleState({
    required this.playerBench,
    required this.aiBench,
    required this.playerField,
    required this.aiField,
    required this.zoneP,
    required this.zoneA,
  });

  Iterable<BattleCreature> get allCreatures => playerBench
      .followedBy(aiBench)
      .followedBy(playerField)
      .followedBy(aiField);

  bool get anyPlayerAlive =>
      playerField.any((c) => c.hp > 0) || playerBench.any((c) => c.summonable);
  bool get anyAIAlive =>
      aiField.any((c) => c.hp > 0) || aiBench.any((c) => c.summonable);
}

// ---------------------------------------------------------------------------
// Turn controller: planning → resolving → planning
// ---------------------------------------------------------------------------

class TurnController {
  final BattleState s;
  final BattleConfig cfg;

  // Base elements that can be manually summoned
  static const baseElements = {'Fire', 'Water', 'Earth', 'Air'};

  TurnController(this.s, {this.cfg = const BattleConfig()});

  void startPlanningPhase() {
    s.phase = Phase.planning;
    s.actionPlayer = null;
    s.actionAI = null;
    s.nodes = _spawnElementNodes(s);

    // Reset per-resolve flags
    for (final c in s.playerField.followedBy(s.aiField)) {
      c.bubble?.thrownThisResolve = false;
      c.bubble?.touchedWall = false;
      if ((c.bubble?.summonLockout ?? 0) > 0) {
        c.bubble!.summonLockout = math.max(0, c.bubble!.summonLockout - 1.0);
      }
    }
  }

  // NEW: Set player action (throw OR summon)
  void onPlayerPlannedAction(PlannedAction action) {
    if (s.phase != Phase.planning) return;
    s.actionPlayer = action;
    print('✅ Player planned: $action');
  }

  // NEW: Set AI action (throw OR summon)
  void onAIPlannedAction(PlannedAction action) {
    if (s.phase != Phase.planning) return;
    s.actionAI = action;
    print('✅ AI planned: $action');
  }

  // LEGACY: Keep for backward compatibility
  void onPlayerPlannedThrow(Bubble b, Offset aim, double power) {
    onPlayerPlannedAction(PlannedAction.throw_(PlannedThrow(b, aim, power)));
  }

  void onAIPlannedThrow(Bubble b, Offset aim, double power) {
    onAIPlannedAction(PlannedAction.throw_(PlannedThrow(b, aim, power)));
  }

  // UPDATED: Commit and resolve both actions
  void commitIfReadyAndResolve() {
    if (s.phase != Phase.planning) return;
    if (s.actionPlayer == null || s.actionAI == null) return;

    s.phase = Phase.resolving;
    s._resolveTimer = 0;

    print('⚡ Committing actions:');
    _applyAction(s.actionPlayer!, Side.player);
    _applyAction(s.actionAI!, Side.ai);

    s.actionPlayer = s.actionAI = null;
  }

  void _applyAction(PlannedAction action, Side side) {
    if (action.isThrow) {
      _applyThrow(action.throw_!, side);
    } else if (action.isSummon) {
      _applySummon(action.summon!, side);
    }
  }

  void _applyThrow(PlannedThrow pt, Side side) {
    // Find owner for stat-based speed
    BattleCreature? owner;
    final field = side == Side.player ? s.playerField : s.aiField;
    for (final c in field) {
      if (identical(c.bubble, pt.bubble)) {
        owner = c;
        break;
      }
    }

    final double speed;
    if (owner != null) {
      speed = BattleStats.calculateThrowSpeed(
        owner,
        pt.power,
        cfg.maxThrowSpeed,
      );
      final mult = BattleStats.throwSpeedMultiplier(owner);
      print(
        '   ${owner.element} throw: ${speed.toStringAsFixed(0)} speed (${(mult * 100).toInt()}%)',
      );
    } else {
      speed = pt.power * cfg.maxThrowSpeed;
      print('   ⚠️ Owner not found, base speed: ${speed.toStringAsFixed(0)}');
    }

    pt.bubble.vel = pt.aim * speed;
    pt.bubble.thrownThisResolve = true;

    if (side == Side.player) {
      s.thrownP = pt.bubble;
    } else {
      s.thrownA = pt.bubble;
    }
  }

  void _applySummon(BattleCreature creature, Side side) {
    print('   📦 Summoning ${creature.element}');

    final field = side == Side.player ? s.playerField : s.aiField;
    final zone = side == Side.player ? s.zoneP : s.zoneA;

    // Check field limit
    if (field.length >= 4) {
      print('   ⚠️ Field full! Cannot summon');
      return;
    }

    // RESTRICTION: Only base elements can be manually summoned
    if (!baseElements.contains(creature.element)) {
      print(
        '   ❌ ${creature.element} is not a base element! Must be fused or summoned via node',
      );
      return;
    }

    // Mark as summoned
    creature.summonable = false;
    creature.onField = true;

    // Create bubble at home zone with random offset
    final spawnOffset = Offset(
      (math.Random().nextDouble() - 0.5) * 50,
      (math.Random().nextDouble() - 0.5) * 50,
    );

    creature.bubble = Bubble(
      pos: zone.center + spawnOffset,
      vel: Offset.zero,
      radius: 28,
      element: creature.element,
      team: side == Side.player ? 0 : 1,
      ownerInstanceId: creature.instance.instanceId,
    );

    field.add(creature);

    // Small summon score bonus
    if (side == Side.player) {
      s.scoreP += 15;
    } else {
      s.scoreA += 15;
    }

    print('   ✨ ${creature.element} spawned at ${zone.center}');
  }

  // Rest of TurnController methods stay the same (tick, _zoneScoreFor, etc.)
  void tick(double dt, List<Bubble> allBubbles) {
    if (s.phase != Phase.resolving) return;

    s._resolveTimer += dt;

    final anyFast = allBubbles.any((b) => b.vel.distance > cfg.settleEps);
    if (anyFast) {
      s._underEpsFor = 0;
    } else {
      s._underEpsFor += dt;
    }

    final settled =
        s._underEpsFor >= cfg.settleHold ||
        s._resolveTimer >= cfg.maxResolveTime;

    if (settled) {
      _scoreZonesAtSettle();
      _cleanupNodes();
      if (!_checkGameOver()) {
        startPlanningPhase();
      } else {
        s.phase = Phase.gameOver;
      }
    }
  }

  void _scoreZonesAtSettle() {
    if (s.thrownP != null) {
      s.scoreP += _zoneScoreFor(s.thrownP!.pos, s.zoneP);
      if (s.thrownP!.touchedWall) s.scoreP += 10;
    }
    if (s.thrownA != null) {
      s.scoreA += _zoneScoreFor(s.thrownA!.pos, s.zoneA);
      if (s.thrownA!.touchedWall) s.scoreA += 10;
    }
    s.thrownP = s.thrownA = null;
  }

  void _cleanupNodes() {
    s.nodes.removeWhere((n) => n.consumed);
  }

  bool _checkGameOver() {
    final playerHas = s.playerField.any((c) => c.hp > 0);
    final aiHas = s.aiField.any((c) => c.hp > 0);
    return !(playerHas && aiHas);
  }

  int _zoneScoreFor(Offset p, TargetZone z) {
    final d = (p - z.center).distance;
    if (d <= z.rInner) return 150;
    if (d <= z.rMid) return 100;
    if (d <= z.rOuter) return 50;
    return 0;
  }

  List<ElementNode> _spawnElementNodes(BattleState s) {
    final rng = math.Random();
    final nodes = <ElementNode>[];

    print('🎲 Spawning element nodes...');

    List<String> getAvailableElements(List<BattleCreature> bench) {
      return bench
          .where((c) => c.summonable && !c.onField)
          .map((c) => c.element)
          .toSet()
          .toList();
    }

    const neutralElements = ['Fire', 'Water', 'Earth', 'Air'];

    final nodeCount = 2 + rng.nextInt(2); // 2-3 nodes
    print('   Spawning $nodeCount nodes');

    for (int i = 0; i < nodeCount; i++) {
      final roll = rng.nextDouble();
      String element;

      if (roll < 0.5) {
        // 50%: Player's bench
        final available = getAvailableElements(s.playerBench);
        if (available.isEmpty) {
          element = neutralElements[rng.nextInt(4)];
          print('   Node $i: $element (neutral - player bench empty)');
        } else {
          element = available[rng.nextInt(available.length)];
          print('   Node $i: $element (from player bench)');
        }
      } else if (roll < 0.8) {
        // 30%: AI's bench
        final available = getAvailableElements(s.aiBench);
        if (available.isEmpty) {
          element = neutralElements[rng.nextInt(4)];
          print('   Node $i: $element (neutral - AI bench empty)');
        } else {
          element = available[rng.nextInt(available.length)];
          print('   Node $i: $element (from AI bench)');
        }
      } else {
        // 20%: Neutral
        element = neutralElements[rng.nextInt(4)];
        print('   Node $i: $element (neutral random)');
      }

      nodes.add(
        ElementNode(
          element: element,
          pos: Offset(
            150 + rng.nextDouble() * 250,
            250 + rng.nextDouble() * 200,
          ),
        ),
      );
    }

    return nodes;
  }
}

Offset _norm(Offset v) {
  final d = v.distance;
  return d == 0 ? const Offset(1, 0) : v / d;
}

// ---------------------------------------------------------------------------
// Combat & summoning hooks
// ---------------------------------------------------------------------------

// UPDATED CombatResolver for battle_game_core.dart
// Replace your existing CombatResolver class with this version

class CombatResolver {
  final BattleState s;
  final math.Random _rng = math.Random();

  CombatResolver(this.s);

  // Call when ANY wall bounce occurs for style points
  void onWallBounce(Bubble b) {
    b.touchedWall = true;
  }

  // Enemy collision: apply damage based on attacker/defender elements + stats
  void onEnemyCollision(Bubble a, Bubble b) {
    final atk = _ownerOf(a);
    final def = _ownerOf(b);
    if (atk == null || def == null) return;
    if (atk.team == def.team) {
      // Ally collision - check for fusion!
      _handleAllyCollision(atk, def, a, b);
      return;
    }

    print('💥 Enemy collision: ${atk.element} vs ${def.element}');

    // Attacker: higher speed wins
    final attacker = a.vel.distance >= b.vel.distance ? a : b;
    final defender = identical(attacker, a) ? b : a;
    final atkOwner = _ownerOf(attacker)!;
    final defOwner = _ownerOf(defender)!;

    // Use new stat-based damage calculation
    final dmg = BattleStats.calculateDamage(atkOwner, defOwner);
    final effectiveness = BattleStats.elementalEffectiveness(
      atkOwner.element,
      defOwner.element,
    );

    String effectMsg = '';
    if (effectiveness > 1.0) {
      effectMsg = ' (Super effective!)';
    } else if (effectiveness < 1.0) {
      effectMsg = ' (Not very effective)';
    }

    print(
      '   ${atkOwner.element} deals $dmg damage to ${defOwner.element}$effectMsg',
    );

    _dealDamage(defOwner, dmg);

    // Score: +1 per damage dealt
    if (atkOwner.team == 0) {
      s.scoreP += dmg;
    } else {
      s.scoreA += dmg;
    }
  }

  // Handle ally bubble collisions for fusion
  void _handleAllyCollision(
    BattleCreature creature1,
    BattleCreature creature2,
    Bubble bubble1,
    Bubble bubble2,
  ) {
    print('🤝 Ally collision: ${creature1.element} + ${creature2.element}');

    // Check if both bubbles have low velocity (gentle collision)
    final speed1 = bubble1.vel.distance;
    final speed2 = bubble2.vel.distance;
    final avgSpeed = (speed1 + speed2) / 2;

    // Only attempt fusion if collision is gentle (< 300 speed)
    if (avgSpeed > 300) {
      print(
        '   ⚠️ Collision too fast for fusion (${avgSpeed.toStringAsFixed(0)})',
      );
      return;
    }

    // Attempt fusion
    final midpoint = (bubble1.pos + bubble2.pos) / 2;
    final fusionCreature = FusionSystem.attemptFusion(
      creature1,
      creature2,
      s,
      spawnPosition: midpoint,
    );

    if (fusionCreature != null) {
      print('   ✨ Fusion successful! ${fusionCreature.element} created');

      // Award fusion score bonus
      if (creature1.team == 0) {
        s.scoreP += 50;
      } else {
        s.scoreA += 50;
      }

      // Add to field
      final field = _fieldOf(creature1.team);

      // Check field limit (max 4)
      if (field.length >= 4) {
        print('   ⚠️ Field full! Replacing lowest HP creature');
        field.sort((a, b) => a.hp.compareTo(b.hp));
        _despawn(field.first);
      }

      field.add(fusionCreature);

      // Note: The bridge will spawn the actual bubble
      // Parents stay on field (Option A from design)
    }
  }

  // Element node touch: summon from bench if available
  void onTouchNode(Bubble b, ElementNode node) {
    if (node.consumed) return;
    final owner = _ownerOf(b);
    if (owner == null) return;
    final team = owner.team;

    print('💎 ${owner.element} touched ${node.element} node');

    final bench = _benchOf(team);
    BattleCreature? candidate;
    try {
      candidate = bench.firstWhere(
        (c) => c.element == node.element && c.summonable && !c.onField,
      );
    } catch (e) {
      candidate = null;
    }

    if (candidate == null) {
      print('   ⚠️ No ${node.element} available in bench');
      node.consumed = true;
      return;
    }

    print('   ✅ Summoning ${candidate.element} from bench');

    // Field cap 4: replace lowest HP if needed
    final field = _fieldOf(team);
    if (field.length >= 4) {
      print('   ⚠️ Field full! Replacing lowest HP creature');
      field.sort((a, b) => a.hp.compareTo(b.hp));
      _despawn(field.first);
    }

    _summon(candidate, at: node.pos);
    node.consumed = true;

    // Summon score bonus
    if (team == 0) {
      s.scoreP += 30;
    } else {
      s.scoreA += 30;
    }
  }

  // --- helpers ---
  BattleCreature? _ownerOf(Bubble b) {
    for (final c in s.playerField.followedBy(s.aiField)) {
      if (identical(c.bubble, b)) return c;
    }
    return null;
  }

  List<BattleCreature> _benchOf(int team) =>
      team == 0 ? s.playerBench : s.aiBench;

  List<BattleCreature> _fieldOf(int team) =>
      team == 0 ? s.playerField : s.aiField;

  void _summon(BattleCreature bc, {required Offset at}) {
    final b = Bubble(
      pos: at,
      vel: const Offset(0, -120),
      radius: 28,
      element: bc.element,
      team: bc.team,
      ownerInstanceId: bc.instance.instanceId,
    );
    bc.onField = true;
    bc.summonable = false;
    bc.bubble = b;

    final field = _fieldOf(bc.team);
    field.add(bc);

    print('   ✨ ${bc.element} spawned at $at');
  }

  void _despawn(BattleCreature bc) {
    print('   💀 Despawning ${bc.element}');
    bc.onField = false;
    bc.bubble = null;
    final field = _fieldOf(bc.team);
    field.remove(bc);
  }

  void _dealDamage(BattleCreature target, int amount) {
    final oldHp = target.hp;
    target.hp = math.max(0, target.hp - amount);

    print('   ${target.element}: $oldHp → ${target.hp} HP');

    if (target.hp == 0) {
      print('   💀 ${target.element} knocked out!');
      // KO bonus
      if (target.team == 0) {
        s.scoreA += 100;
      } else {
        s.scoreP += 100;
      }
      _despawn(target);
    }
  }
}

// IMPROVED SimpleAIPlanner
// Add this to your battle_game_core.dart, replacing the existing SimpleAIPlanner class

class SimpleAIPlanner {
  final math.Random _rng = math.Random();

  PlannedAction? plan(BattleState s, BattleConfig cfg) {
    print('  🤖 AI planning started...');

    final aiBubbles = s.aiField
        .where((c) => c.bubble != null && c.hp > 0)
        .map((c) => c.bubble!)
        .toList();

    // Decision: Should we summon or throw?
    final shouldSummon = _shouldSummon(s);

    if (shouldSummon) {
      // Try to summon a base element
      final summonCandidate = _chooseSummon(s);
      if (summonCandidate != null) {
        print('  🤖 AI choosing to SUMMON ${summonCandidate.element}');
        return PlannedAction.summon(summonCandidate);
      }
      // Fallback to throw if summon not possible
    }

    // Default: throw
    if (aiBubbles.isEmpty) {
      print('  ❌ AI has no bubbles to throw');
      return null;
    }

    final me = aiBubbles.first;
    print('  🤖 AI selected: ${me.element} at ${me.pos}');

    // Priority 1: Element nodes
    final usableNodes = s.nodes
        .where((n) => !n.consumed)
        .where((n) => _benchHas(s.aiBench, n.element))
        .toList();

    if (usableNodes.isNotEmpty) {
      final node = usableNodes.first;
      print('  🤖 AI targeting node: ${node.element}');
      return PlannedAction.throw_(
        _aimAt(me, node.pos, cfg, preferSoftAngle: true),
      );
    }

    // Priority 2: Score in zone
    if (_rng.nextDouble() < 0.6) {
      final zoneAim =
          s.zoneA.center +
          Offset(
            (_rng.nextDouble() - 0.5) * 30,
            (_rng.nextDouble() - 0.5) * 30,
          );
      print('  🤖 AI targeting zone');
      return PlannedAction.throw_(
        _aimAt(me, zoneAim, cfg, preferSoftAngle: true),
      );
    }

    // Priority 3: Attack enemy
    final enemies = s.playerField
        .where((c) => c.bubble != null && c.hp > 0)
        .toList();
    if (enemies.isNotEmpty) {
      enemies.sort((a, b) => a.hp.compareTo(b.hp));
      print('  🤖 AI targeting enemy ${enemies.first.element}');
      return PlannedAction.throw_(
        _aimAt(me, enemies.first.bubble!.pos, cfg, preferHardHit: true),
      );
    }

    // Fallback
    print('  🤖 AI using fallback throw');
    return PlannedAction.throw_(
      _aimAt(me, s.zoneA.center, cfg, preferSoftAngle: true),
    );
  }

  bool _shouldSummon(BattleState s) {
    // AI logic: Summon if we have fewer creatures on field than enemy
    final aiFieldCount = s.aiField.length;
    final playerFieldCount = s.playerField.length;

    if (aiFieldCount < 2) return true; // Always summon if < 2 on field
    if (aiFieldCount < playerFieldCount)
      return _rng.nextDouble() < 0.7; // 70% if behind
    if (aiFieldCount < 4) return _rng.nextDouble() < 0.3; // 30% if not at max

    return false;
  }

  BattleCreature? _chooseSummon(BattleState s) {
    // Only summon base elements
    final baseCandidates = s.aiBench
        .where(
          (c) =>
              c.summonable &&
              !c.onField &&
              TurnController.baseElements.contains(c.element),
        )
        .toList();

    if (baseCandidates.isEmpty) return null;

    // Prefer elements we don't have on field yet
    final onField = s.aiField.map((c) => c.element).toSet();
    final newElements = baseCandidates
        .where((c) => !onField.contains(c.element))
        .toList();

    if (newElements.isNotEmpty) {
      return newElements[_rng.nextInt(newElements.length)];
    }

    return baseCandidates[_rng.nextInt(baseCandidates.length)];
  }

  bool _benchHas(List<BattleCreature> bench, String element) =>
      bench.any((c) => c.element == element && c.summonable);

  PlannedThrow _aimAt(
    Bubble me,
    Offset target,
    BattleConfig cfg, {
    bool preferSoftAngle = false,
    bool preferHardHit = false,
  }) {
    var dir = target - me.pos;
    final d = dir.distance;

    var aim = d == 0 ? const Offset(1, 0) : dir / d;

    // Add jitter
    final jitter = (_rng.nextDouble() - 0.5) * 0.15;
    final s = math.sin(jitter), c = math.cos(jitter);
    aim = Offset(aim.dx * c - aim.dy * s, aim.dx * s + aim.dy * c);

    double power = preferHardHit ? 0.85 : 0.65;
    if (preferSoftAngle) power = 0.55;
    power = (power + (_rng.nextDouble() - 0.5) * 0.1).clamp(0.4, 0.95);

    print('  🤖 AI plan: aim=$aim, power=${power.toStringAsFixed(2)}');
    return PlannedThrow(me, aim, power);
  }
}
