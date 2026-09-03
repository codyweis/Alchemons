// The harvest happens to the creature that is standing there.
//
// It used to push a full-screen route holding a freshly built COPY of the
// sprite: the animal you had been looking at blinked out and a duplicate
// appeared on a black card. These pin the two properties that make the
// difference — the effect drives the live component's own transform, and the
// caller always gets its answer.

import 'package:alchemons/games/wilderness/harvest_field.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parentage, not isMounted: a rig whose game never mounts would make every
/// `isMounted, isFalse` assertion pass for the wrong reason.
bool _inWorld(Component c) => c.parent != null;

class _Target extends PositionComponent {
  _Target() : super(size: Vector2.all(96), anchor: Anchor.center) {
    position = Vector2(120, 200);
  }
}

Future<(FlameGame, _Target, HarvestFieldEffect)> _rig(
  Future<bool> Function() task, {
  double minSeize = 0.4,
}) async {
  final game = FlameGame();
  // ignore: invalid_use_of_internal_member
  game.onGameResize(Vector2(400, 800));
  await game.ready();
  final target = _Target();
  await game.add(target);
  await game.ready();
  final fx = HarvestFieldEffect(
    target: target,
    accent: const Color(0xFF6FBF73),
    task: task,
    minSeize: minSeize,
  );
  await game.add(fx);
  await game.ready();
  return (game, target, fx);
}

void main() {
  test('it moves the LIVE component, not a copy', () async {
    final (game, target, _) = await _rig(() async => true, minSeize: 1.0);
    final home = target.position.clone();
    final homeScale = target.scale.clone();

    // Into the lock and the strain.
    for (var i = 0; i < 45; i++) {
      game.update(1 / 60);
    }
    expect(
      target.position == home && target.scale == homeScale,
      isFalse,
      reason: 'the creature standing in the scene has to be the thing acting',
    );
  });

  test('a success takes it out of the world', () async {
    final (game, target, fx) = await _rig(() async => true);
    for (var i = 0; i < 200; i++) {
      game.update(1 / 60);
    }
    expect(await fx.result, isTrue);
    expect(_inWorld(target), isFalse, reason: 'harvested');
  });

  test('a failure leaves it exactly where it was', () async {
    final (game, target, fx) = await _rig(() async => false);
    final home = target.position.clone();
    final homeScale = target.scale.clone();
    final homePriority = target.priority;
    for (var i = 0; i < 200; i++) {
      game.update(1 / 60);
    }
    expect(await fx.result, isFalse);
    expect(_inWorld(target), isTrue, reason: 'it broke the field and stayed');
    expect(target.position, home);
    expect(target.scale, homeScale);
    expect(
      target.priority,
      homePriority,
      reason: 'the lift over the dim must be handed back',
    );
  });

  test('the opening runs even when the roll answers instantly', () async {
    // The shared beat is the point: an instant answer must not skip the
    // seizure and jump-cut to the outcome.
    final (game, _, fx) = await _rig(() async => true, minSeize: 0.8);
    for (var i = 0; i < 24; i++) {
      game.update(1 / 60); // 0.4s — half the opening
    }
    expect(fx.result, isA<Future<bool>>());
    var settled = false;
    unawaited(fx.result.then((_) => settled = true));
    await Future<void>.delayed(Duration.zero);
    expect(settled, isFalse, reason: 'it cannot be over before it began');
  });

  test(
    'a thrown roll still answers, and does not strand the creature',
    () async {
      final (game, target, fx) = await _rig(
        () async => throw StateError('net'),
      );
      for (var i = 0; i < 200; i++) {
        game.update(1 / 60);
      }
      expect(await fx.result, isFalse);
      expect(_inWorld(target), isTrue);
    },
  );

  test('removing the effect early never strands the caller', () async {
    // A scene torn down mid-harvest (the player leaves) must not leave an
    // await hanging for ever.
    final (game, target, fx) = await _rig(() async {
      await Future<void>.delayed(const Duration(seconds: 5));
      return true;
    }, minSeize: 5);
    for (var i = 0; i < 10; i++) {
      game.update(1 / 60);
    }
    fx.onRemove();
    expect(await fx.result, isFalse);
    expect(_inWorld(target), isTrue);
    expect(target.scale, Vector2.all(1));
  });

  group('the fusion merges the two that are standing there', () {
    Future<(FlameGame, _Target, _Target, FusionFieldEffect)> rig() async {
      final game = FlameGame();
      // ignore: invalid_use_of_internal_member
      game.onGameResize(Vector2(400, 800));
      await game.ready();
      final a = _Target()..position = Vector2(80, 300);
      final b = _Target()..position = Vector2(300, 300);
      await game.addAll([a, b]);
      await game.ready();
      final fx = FusionFieldEffect(
        a: a,
        b: b,
        accentA: const Color(0xFF6FBF73),
        accentB: const Color(0xFF7AA7E8),
        seconds: 0.5,
      );
      await game.add(fx);
      await game.ready();
      return (game, a, b, fx);
    }

    test('both live components travel to meet', () async {
      final (game, a, b, _) = await rig();
      final gap = (a.position - b.position).length;
      for (var i = 0; i < 20; i++) {
        game.update(1 / 60);
      }
      expect(
        (a.position - b.position).length,
        lessThan(gap),
        reason: 'the pair have to actually close on each other',
      );
    });

    test('and both are consumed, so nothing is left to duplicate', () async {
      final (game, a, b, fx) = await rig();
      for (var i = 0; i < 120; i++) {
        game.update(1 / 60);
      }
      await fx.finished;
      expect(_inWorld(a), isFalse);
      expect(_inWorld(b), isFalse);
    });

    test('a teardown mid-merge hands both back intact', () async {
      final (game, a, b, fx) = await rig();
      final ha = a.position.clone();
      final hb = b.position.clone();
      for (var i = 0; i < 10; i++) {
        game.update(1 / 60);
      }
      fx.onRemove();
      await fx.finished;
      expect(_inWorld(a), isTrue);
      expect(_inWorld(b), isTrue);
      expect(a.position, ha);
      expect(b.position, hb);
      expect(a.scale, Vector2.all(1));
    });
  });

  test('a pair in different parents still meets in the middle', () async {
    // The wild creature hangs off its spawn point and the party one off an
    // anchor of its own, on a layer with its own offset — they do NOT share a
    // coordinate system. Averaging their local positions sent them lurching
    // near their own origins instead of towards each other.
    final game = FlameGame();
    // ignore: invalid_use_of_internal_member
    game.onGameResize(Vector2(400, 800));
    await game.ready();

    final leftAnchor = PositionComponent(position: Vector2(60, 300));
    final rightAnchor = PositionComponent(position: Vector2(340, 300));
    await game.addAll([leftAnchor, rightAnchor]);
    await game.ready();

    // Both sit at the ORIGIN of their own anchor: identical local positions,
    // 280 apart on screen.
    final a = _Target()..position = Vector2.zero();
    final b = _Target()..position = Vector2.zero();
    await leftAnchor.add(a);
    await rightAnchor.add(b);
    await game.ready();
    expect(a.position, b.position, reason: 'the trap this test exists for');

    final fx = FusionFieldEffect(
      a: a,
      b: b,
      accentA: const Color(0xFF6FBF73),
      accentB: const Color(0xFF7AA7E8),
      seconds: 0.5,
    );
    await rightAnchor.add(fx);
    await game.ready();

    final startGap = (a.absoluteCenter - b.absoluteCenter).length;
    for (var i = 0; i < 25; i++) {
      game.update(1 / 60);
    }
    final gap = (a.absoluteCenter - b.absoluteCenter).length;
    expect(
      gap,
      lessThan(startGap * 0.7),
      reason:
          'they have to close in SCREEN space, not local space: '
          '$startGap -> $gap',
    );
  });
}

void unawaited(Future<void> f) {}
