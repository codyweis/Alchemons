// lib/battle/floating_overlay_arena_adapter.dart
// Fixed version with better throw velocity application

import 'dart:collection';
import 'dart:math' as math;
import 'package:alchemons/battle/battle_game_core.dart';
import 'package:flutter/material.dart';

import 'arena_bridge.dart';

// -------------------------------------------------------------
// Basic in-memory BubbleHandle implementation
// -------------------------------------------------------------

class _Handle implements BubbleHandle {
  _Handle({
    required this.id,
    required Offset pos,
    required Offset vel,
    required this.radius,
    required this.element,
    required this.team,
    required this.ownerInstanceId,
    required this.seed,
  }) : _pos = pos,
       _vel = vel;

  final String id;
  Offset _pos;
  Offset _vel;
  double life = 0;
  final double seed;

  @override
  Offset get pos => _pos;
  set pos(Offset v) => _pos = v;

  @override
  Offset get vel => _vel;
  @override
  set vel(Offset v) {
    _vel = v;
    print(
      '      Handle ${element} velocity set to $v (speed: ${v.distance.toStringAsFixed(1)})',
    );
  }

  @override
  final double radius;
  @override
  final String element;
  @override
  final int team;
  final String ownerInstanceId;

  bool _touchedWall = false;
  @override
  bool get touchedWall => _touchedWall;
  @override
  set touchedWall(bool v) => _touchedWall = v;
}

// -------------------------------------------------------------
// Minimal PhysicsArena over a Canvas/CustomPainter update loop
// -------------------------------------------------------------

typedef CollisionCallback = void Function(BubbleHandle a, BubbleHandle b);
typedef NodeTouchCallback = void Function(BubbleHandle b, ElementNode node);
typedef WallBounceCallback = void Function(BubbleHandle b);

class FloatingOverlayArenaAdapter extends ChangeNotifier
    implements PhysicsArena {
  FloatingOverlayArenaAdapter({required this.size});

  final _rng = math.Random();

  @override
  final Size size;

  final Map<String, _Handle> _handles = LinkedHashMap();
  List<ElementNode> _nodes = [];

  // Physics params
  final double _wallDamping = 0.98;
  final double _dragDecayTau = 0.8;

  bool _planningEnabled = false;

  // Callbacks
  @override
  void Function(BubbleHandle b)? onWallBounce;
  @override
  CollisionCallback? onEnemyCollision;
  @override
  NodeTouchCallback? onElementNodeTouch;
  @override
  void Function()? onSettle;

  @override
  BubbleHandle spawnBubble({
    required Offset pos,
    required Offset vel,
    required double radius,
    required String element,
    required int team,
    required String ownerInstanceId,
  }) {
    final id = '${DateTime.now().microsecondsSinceEpoch}_${_handles.length}';
    final h = _Handle(
      id: id,
      pos: pos,
      vel: vel,
      radius: radius,
      element: element,
      team: team,
      ownerInstanceId: ownerInstanceId,
      seed: _rng.nextDouble() * math.pi * 2,
    );
    _handles[id] = h;
    print('   ✨ Spawned bubble: $element (team $team) at $pos');
    return h;
  }

  @override
  void despawnBubble(BubbleHandle handle) {
    _handles.remove((handle as _Handle).id);
  }

  @override
  void setElementNodes(List<ElementNode> nodes) {
    _nodes = nodes;
  }

  @override
  void consumeElementNode(ElementNode node) {
    node.consumed = true;
  }

  @override
  void setPlanningEnabled(bool playerEnabled) {
    _planningEnabled = playerEnabled;
  }

  @override
  void applyThrow(
    BubbleHandle b,
    Offset aimOrVel,
    double power,
    double maxSpeed,
  ) {
    print('    🎯 applyThrow called:');
    print('       Bubble: ${b.element} (team ${b.team})');
    print('       Current vel: ${b.vel}');
    print(
      '       Input aimOrVel: $aimOrVel (length: ${aimOrVel.distance.toStringAsFixed(1)})',
    );
    print('       Power: $power, MaxSpeed: $maxSpeed');

    // The velocity is already computed in TurnController.commitIfReadyAndResolve
    // Just apply it directly
    (b as _Handle).vel = aimOrVel;

    print(
      '       ✅ New vel: ${b.vel} (speed: ${b.vel.distance.toStringAsFixed(1)})',
    );
  }

  @override
  List<BubbleHandle> allBubbles() => _handles.values.toList(growable: false);

  void step(double dt) {
    // Integrate movement
    for (final h in _handles.values) {
      // Basic Euler integration
      h.pos = h.pos + h.vel * dt;

      // Subtle wobble effect (visual only)
      h.life += dt;
      final wob = Offset(
        math.sin(h.seed + h.life * 0.7) * 8.0,
        math.cos(h.seed + h.life * 0.9) * 8.0,
      );
      h.pos = h.pos + wob * (0.004 * dt * 60);

      // Wall bounces
      final r = h.radius;
      final maxX = size.width - r;
      final maxY = size.height - r;

      bool hitWall = false;

      if (h.pos.dx < r) {
        h.pos = Offset(r, h.pos.dy);
        h.vel = Offset(h.vel.dx.abs(), h.vel.dy) * _wallDamping;
        hitWall = true;
      } else if (h.pos.dx > maxX) {
        h.pos = Offset(maxX, h.pos.dy);
        h.vel = Offset(-h.vel.dx.abs(), h.vel.dy) * _wallDamping;
        hitWall = true;
      }

      if (h.pos.dy < r) {
        h.pos = Offset(h.pos.dx, r);
        h.vel = Offset(h.vel.dx, h.vel.dy.abs()) * _wallDamping;
        hitWall = true;
      } else if (h.pos.dy > maxY) {
        h.pos = Offset(h.pos.dx, maxY);
        h.vel = Offset(h.vel.dx, -h.vel.dy.abs()) * _wallDamping;
        hitWall = true;
      }

      if (hitWall) {
        h.touchedWall = true;
        onWallBounce?.call(h);
      }

      // Apply drag/damping
      final decay = math.pow(0.5, dt / _dragDecayTau) as double;
      h.vel = h.vel * decay;

      // Deadzone to stop tiny movements
      if (h.vel.distance < 2.0) {
        h.vel = Offset.zero;
      }
    }

    // Pairwise collisions
    final handles = _handles.values.toList(growable: false);
    for (int i = 0; i < handles.length; i++) {
      for (int j = i + 1; j < handles.length; j++) {
        final a = handles[i];
        final b = handles[j];
        final delta = b.pos - a.pos;
        final dist = delta.distance;
        final minDist = a.radius + b.radius - 2;

        if (dist > 0 && dist < minDist) {
          // Separate bubbles
          final n = delta / dist;
          final push = (minDist - dist) * 0.6;
          (a as _Handle).pos = a.pos - n * push * 0.5;
          (b as _Handle).pos = b.pos + n * push * 0.5;

          // Elastic collision response
          final va = a.vel.dx * n.dx + a.vel.dy * n.dy;
          final vb = b.vel.dx * n.dx + b.vel.dy * n.dy;
          final impulse = (vb - va) * 0.75;
          a.vel = a.vel + n * impulse;
          b.vel = b.vel - n * impulse;

          // Callback for enemy collisions
          if (a.team != b.team) {
            onEnemyCollision?.call(a, b);
          }
        }
      }
    }

    // Node touches
    for (final h in _handles.values) {
      for (final node in _nodes) {
        if (node.consumed) continue;
        final d = (h.pos - node.pos).distance;
        if (d <= h.radius + 12) {
          onElementNodeTouch?.call(h, node);
        }
      }
    }

    // Settle detection
    final eps = 20.0;
    final moving = _handles.values.any((h) => h.vel.distance > eps);
    if (!moving && _handles.isNotEmpty) {
      onSettle?.call();
    }

    notifyListeners();
  }
}
