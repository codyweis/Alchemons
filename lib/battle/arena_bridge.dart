// lib/battle/arena_bridge.dart
// Fixed version that maintains bubble references across multiple rounds

import 'dart:math' as math;
import 'package:alchemons/battle/battle_game_core.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// 1) View-agnostic arena interface
// ---------------------------------------------------------------------------

abstract class BubbleHandle {
  Offset get pos;
  Offset get vel;
  set vel(Offset v);
  double get radius;
  String get element;
  int get team;
  bool get touchedWall;
  set touchedWall(bool v);
}

abstract class PhysicsArena {
  Size get size;
  BubbleHandle spawnBubble({
    required Offset pos,
    required Offset vel,
    required double radius,
    required String element,
    required int team,
    required String ownerInstanceId,
  });
  void despawnBubble(BubbleHandle handle);
  void setElementNodes(List<ElementNode> nodes);
  void consumeElementNode(ElementNode node);
  void setPlanningEnabled(bool playerEnabled);
  set onWallBounce(void Function(BubbleHandle b)? cb);
  set onEnemyCollision(void Function(BubbleHandle a, BubbleHandle b)? cb);
  set onElementNodeTouch(void Function(BubbleHandle b, ElementNode node)? cb);
  set onSettle(void Function()? cb);
  void applyThrow(BubbleHandle b, Offset aim, double power, double maxSpeed);
  List<BubbleHandle> allBubbles();
}

// ---------------------------------------------------------------------------
// 2) ArenaBridge — glue code between battle core and physics arena
// ---------------------------------------------------------------------------

class ArenaBridge {
  final PhysicsArena arena;
  final BattleState state;
  final TurnController turn;
  final CombatResolver combat;
  final SimpleAIPlanner ai;
  final BattleConfig cfg;

  // Keep a mapping of bubble identities so we can reliably find them
  final Map<String, BubbleHandle> _handlesByOwner = {};

  ArenaBridge({
    required this.arena,
    required this.state,
    required this.turn,
    required this.combat,
    required this.ai,
    this.cfg = const BattleConfig(),
  }) {
    _wireArenaCallbacks();
  }

  void setPlayerSummon(BattleCreature creature) {
    print('📦 Player summon set: ${creature.element}');
    if (state.phase != Phase.planning) {
      print('❌ Not in planning phase! Current: ${state.phase}');
      return;
    }

    // Create PlannedAction for summon
    turn.onPlayerPlannedAction(PlannedAction.summon(creature));
    print('✅ Player summon recorded');
  }

  void _wireArenaCallbacks() {
    arena.onWallBounce = (b) => combat.onWallBounce(_toCore(b));

    arena.onEnemyCollision = (a, b) {
      if (a.team != b.team) {
        combat.onEnemyCollision(_toCore(a), _toCore(b));
      }
    };

    arena.onElementNodeTouch = (b, node) {
      combat.onTouchNode(_toCore(b), node);
      arena.consumeElementNode(node);
    };

    arena.onSettle = () {
      turn.tick(0.0, _coreBubbles());
    };
  }

  void startMatch() {
    print('🌉 ArenaBridge.startMatch() - Arena size: ${arena.size}');
    _syncFieldFromState();
    _enterPlanning();
    print('🌉 Phase after start: ${state.phase}');
  }

  void setPlayerPlan(BubbleHandle handle, Offset aim, double power) {
    print('🎯 Player plan set: ${handle.element} aim=$aim power=$power');
    if (state.phase != Phase.planning) {
      print('❌ Not in planning phase! Current: ${state.phase}');
      return;
    }

    // Normalize aim to unit vector
    final normAim = aim.distance > 0 ? aim / aim.distance : const Offset(1, 0);
    turn.onPlayerPlannedThrow(_toCore(handle), normAim, power);
    print('✅ Player plan recorded (normalized aim: $normAim)');
  }

  void maybeResolve() {
    if (state.phase != Phase.planning) return;

    print('🤖 AI planning...');

    // Re-sync bubble references before AI plans
    _updateBubbleReferences();

    // AI decides: throw or summon
    final aiAction = ai.plan(state, cfg);
    if (aiAction != null) {
      if (aiAction.isThrow) {
        print(
          '🤖 AI planned: THROW ${aiAction.throw_!.bubble.element} with power ${aiAction.throw_!.power}',
        );
      } else if (aiAction.isSummon) {
        print('🤖 AI planned: SUMMON ${aiAction.summon!.element}');
      }
      turn.onAIPlannedAction(aiAction);
    } else {
      print('⚠️ AI returned null plan - forcing a default');
      // Fallback: try to summon, else throw
      final aiBubbles = arena.allBubbles().where((b) => b.team == 1).toList();
      if (aiBubbles.isNotEmpty) {
        final defaultBubble = _toCore(aiBubbles.first);
        final aimToPlayer = state.zoneP.center - defaultBubble.pos;
        final normAim = aimToPlayer.distance > 0
            ? aimToPlayer / aimToPlayer.distance
            : const Offset(-1, 0);
        turn.onAIPlannedAction(
          PlannedAction.throw_(PlannedThrow(defaultBubble, normAim, 0.6)),
        );
        print('🤖 AI using fallback throw');
      }
    }

    // Check if both sides have actions
    if (state.actionPlayer == null) {
      print('⚠️ Player action is null, cannot resolve yet');
      return;
    }
    if (state.actionAI == null) {
      print('⚠️ AI action is null, cannot resolve yet');
      return;
    }

    print('✅ Both actions ready, committing...');
    print('   Player: ${state.actionPlayer}');
    print('   AI: ${state.actionAI}');

    // Commit both and fire
    turn.commitIfReadyAndResolve();

    if (state.phase == Phase.resolving) {
      print('⚡ RESOLVING - Applying actions');

      // Only apply throws to arena (summons are handled by TurnController)
      if (state.thrownP != null) {
        final h = _findHandleForBubble(state.thrownP!);
        if (h != null) {
          final vel = state.thrownP!.vel;
          print(
            '  Player throw: vel=$vel (speed=${vel.distance.toStringAsFixed(1)})',
          );
          arena.applyThrow(h, vel, 1.0, cfg.maxThrowSpeed);
        } else {
          print('  ❌ Could not find player bubble handle!');
        }
      }

      if (state.thrownA != null) {
        final h = _findHandleForBubble(state.thrownA!);
        if (h != null) {
          final vel = state.thrownA!.vel;
          print(
            '  AI throw: vel=$vel (speed=${vel.distance.toStringAsFixed(1)})',
          );
          arena.applyThrow(h, vel, 1.0, cfg.maxThrowSpeed);
        } else {
          print('  ❌ Could not find AI bubble handle!');
        }
      }
    }
  }

  void tick(double dt) {
    if (state.phase == Phase.resolving) {
      turn.tick(dt, _coreBubbles());
      if (state.phase == Phase.planning) {
        print('🔄 New planning phase started');
        _enterPlanning();
      } else if (state.phase == Phase.gameOver) {
        print('🏁 Game over! Player: ${state.scoreP}, AI: ${state.scoreA}');
        arena.setPlanningEnabled(false);
      }
    }
  }

  void _enterPlanning() {
    print('📝 Entering planning phase');

    // Update bubble references
    _updateBubbleReferences();

    // NEW: Spawn bubbles for any newly fused creatures
    _spawnNewCreatureBubbles();

    arena.setPlanningEnabled(true);
    arena.setElementNodes(state.nodes);
    print('📝 ${state.nodes.length} element nodes spawned');

    // Debug: Show current state
    print('📝 Player field: ${state.playerField.length} creatures');
    for (final c in state.playerField) {
      print(
        '   - ${c.element}: HP=${c.hp}, onField=${c.onField}, hasBubble=${c.bubble != null}',
      );
    }
    print('📝 AI field: ${state.aiField.length} creatures');
    for (final c in state.aiField) {
      print(
        '   - ${c.element}: HP=${c.hp}, onField=${c.onField}, hasBubble=${c.bubble != null}',
      );
    }
  }

  void _spawnNewCreatureBubbles() {
    print('🔄 Checking for new creatures needing bubbles...');

    // Check player field
    for (final c in state.playerField) {
      if (c.onField && c.bubble != null) {
        // Check if bubble exists in arena
        final bubblePos = c.bubble!.pos;
        final existsInArena = arena.allBubbles().any(
          (h) => (h.pos - bubblePos).distance < 10 && h.team == c.team,
        );

        if (!existsInArena &&
            !_handlesByOwner.containsKey(c.instance.instanceId)) {
          // Need to spawn this bubble!
          print('   ✨ Spawning bubble for newly created ${c.element}');
          final h = arena.spawnBubble(
            pos: c.bubble!.pos,
            vel: Offset.zero,
            radius: c.bubble!.radius,
            element: c.element,
            team: c.team,
            ownerInstanceId: c.instance.instanceId,
          );
          _handlesByOwner[c.instance.instanceId] = h;
        }
      }
    }

    // Check AI field
    for (final c in state.aiField) {
      if (c.onField && c.bubble != null) {
        final bubblePos = c.bubble!.pos;
        final existsInArena = arena.allBubbles().any(
          (h) => (h.pos - bubblePos).distance < 10 && h.team == c.team,
        );

        if (!existsInArena &&
            !_handlesByOwner.containsKey(c.instance.instanceId)) {
          print('   ✨ Spawning bubble for newly created ${c.element}');
          final h = arena.spawnBubble(
            pos: c.bubble!.pos,
            vel: Offset.zero,
            radius: c.bubble!.radius,
            element: c.element,
            team: c.team,
            ownerInstanceId: c.instance.instanceId,
          );
          _handlesByOwner[c.instance.instanceId] = h;
        }
      }
    }

    print('🔄 Spawn check complete');
  }

  void _syncFieldFromState() {
    print('🔄 Syncing field from state...');
    final centerX = arena.size.width / 2;
    final centerY = arena.size.height / 2;

    // Clear old mapping
    _handlesByOwner.clear();

    for (final c in state.playerField) {
      if (c.onField && c.bubble == null) {
        final pos = Offset(centerX - 100, centerY);
        print('  Spawning player ${c.element} at $pos');
        final h = arena.spawnBubble(
          pos: pos,
          vel: Offset.zero,
          radius: 28,
          element: c.element,
          team: c.team,
          ownerInstanceId: c.instance.instanceId,
        );
        c.bubble = _toCore(h);
        _handlesByOwner[c.instance.instanceId] = h;
      }
    }

    for (final c in state.aiField) {
      if (c.onField && c.bubble == null) {
        final pos = Offset(centerX + 100, centerY);
        print('  Spawning AI ${c.element} at $pos');
        final h = arena.spawnBubble(
          pos: pos,
          vel: Offset.zero,
          radius: 28,
          element: c.element,
          team: c.team,
          ownerInstanceId: c.instance.instanceId,
        );
        c.bubble = _toCore(h);
        _handlesByOwner[c.instance.instanceId] = h;
      }
    }

    print('🔄 Sync complete - ${arena.allBubbles().length} bubbles in arena');
  }

  // NEW: Update bubble references from arena handles
  void _updateBubbleReferences() {
    print('🔄 Updating bubble references...');

    // Get all current bubbles from arena
    final allHandles = arena.allBubbles();

    // Update player field
    for (final c in state.playerField) {
      if (!c.onField) continue;

      // Find matching handle by owner ID or position
      BubbleHandle? handle;

      // Try owner ID first
      if (_handlesByOwner.containsKey(c.instance.instanceId)) {
        handle = _handlesByOwner[c.instance.instanceId];
      } else {
        // Fall back to finding by team and closest position
        final candidates = allHandles.where((h) => h.team == c.team).toList();
        if (candidates.isNotEmpty) {
          handle = candidates.first;
        }
      }

      if (handle != null) {
        c.bubble = _toCore(handle);
        print('   Updated player ${c.element} bubble');
      } else {
        print('   ⚠️ Could not find handle for player ${c.element}');
      }
    }

    // Update AI field
    for (final c in state.aiField) {
      if (!c.onField) continue;

      BubbleHandle? handle;

      if (_handlesByOwner.containsKey(c.instance.instanceId)) {
        handle = _handlesByOwner[c.instance.instanceId];
      } else {
        final candidates = allHandles.where((h) => h.team == c.team).toList();
        if (candidates.isNotEmpty) {
          handle = candidates.first;
        }
      }

      if (handle != null) {
        c.bubble = _toCore(handle);
        print('   Updated AI ${c.element} bubble');
      } else {
        print('   ⚠️ Could not find handle for AI ${c.element}');
      }
    }

    print('🔄 Update complete');
  }

  Bubble _toCore(BubbleHandle h) {
    return Bubble(
      pos: h.pos,
      vel: h.vel,
      radius: h.radius,
      element: h.element,
      team: h.team,
      ownerInstanceId: 'view',
    )..touchedWall = h.touchedWall;
  }

  List<Bubble> _coreBubbles() => arena.allBubbles().map(_toCore).toList();

  BubbleHandle? _findHandleForBubble(Bubble b) {
    // Try to find by owner ID first
    for (final entry in _handlesByOwner.entries) {
      final h = entry.value;
      if ((h.pos - b.pos).distance < 5.0 && h.team == b.team) {
        return h;
      }
    }

    // Fallback: position matching
    final all = arena.allBubbles();
    BubbleHandle? best;
    double bestDist = double.infinity;
    for (final h in all) {
      if (h.team != b.team) continue;
      final d = (h.pos - b.pos).distance;
      if (d < bestDist) {
        bestDist = d;
        best = h;
      }
    }

    if (best != null && bestDist < 100) {
      return best;
    }

    print('⚠️ Could not find handle for bubble at ${b.pos} team ${b.team}');
    return null;
  }
}
