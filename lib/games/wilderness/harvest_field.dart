// lib/games/wilderness/harvest_field.dart
//
// THE HARVEST, PLAYED ON THE CREATURE THAT IS ACTUALLY STANDING THERE.
//
// The previous two attempts at this were full-screen routes: push a page, draw
// a fresh copy of the sprite in the middle of it, animate the copy, pop. That
// is an overlay of the creature, not the creature — the thing you had been
// looking at for the last ten seconds blinked out and a duplicate appeared on
// a black card.
//
// This is a component in the scene. The field closes around the live
// WildMonComponent, and the animation drives THAT component's own transform:
// it flinches, it strains, and it is either taken out of the world or it
// breaks the field and is still standing where it was. Nothing is duplicated
// and nothing is pushed, so the scene, the camera and the parallax keep
// running underneath.
//
// The apparatus is particles ([HarvestParticleField], shared with the Flutter
// overlay): a shell of the device's grains round the creature, the far side
// behind it and the near side in front. On a take the creature is read into
// grains of itself, cut away behind a crest, folded into a sphere of its own
// inside the shell, and lifted away. No MaskFilter, per the house rule.

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/widgets/fx/harvest_particles.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
import 'package:alchemons/widgets/fx/harvester_profile.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Plays on [target] and completes with whatever [task] returned.
class HarvestFieldEffect extends PositionComponent {
  HarvestFieldEffect({
    required this.target,
    required this.accent,
    required this.task,
    HarvesterProfile? profile,
    this.minSeize = 1.5,
  }) : profile = profile ?? HarvesterProfile.forBiome(null),
       super(anchor: Anchor.center, priority: 900);

  /// Which harvester is doing this. Drives how the field closes, how it
  /// answers being pushed, and what it throws — see [HarvesterProfile].
  final HarvesterProfile profile;

  /// The creature in the scene. Its transform is what animates.
  final PositionComponent target;
  final Color accent;
  final Future<bool> Function() task;

  /// Seconds of shared opening before the outcome is allowed to land.
  final double minSeize;

  final Completer<bool> _done = Completer<bool>();
  Future<bool> get result => _done.future;

  /// How long the outcome plays: a take is longer than a break.
  double get _resolveSeconds => (_success ?? false)
      ? HarvestParticleField.takeSeconds
      : HarvestParticleField.breakSeconds;

  /// The apparatus, and on a take the creature, in particles.
  late final HarvestParticleField _field;

  /// The field's near side, drawn over the creature: a sibling a step above
  /// it, since this one sits a step below.
  late final _HarvestFieldFront _front = _HarvestFieldFront(this);

  /// On a take, the creature is read before the crest runs, and the take
  /// waits for it (not for long).
  bool _reading = false;
  double _readWait = 0;

  double _t = 0; // seconds since the field engaged
  double _r = 0; // seconds into the resolution
  bool? _success;
  bool _taskDone = false;
  bool _resolving = false;
  bool _finished = false;
  bool _announcedOutcome = false;

  /// Where the FIELD stands: the creature's absolute centre, mapped into
  /// whatever space this component was parented into.
  ///
  /// Taking the target's `position` instead put the rings off the animal
  /// whenever its anchor was not dead centre of its box — which is most
  /// creatures, since a sprite stands with its feet near the bottom.
  Vector2 _fieldCentre() {
    final centre = target.absoluteCenter;
    final p = parent;
    if (p is PositionComponent) return p.absoluteToLocal(centre);
    return centre;
  }

  late final Vector2 _home = target.position.clone();
  late final Vector2 _homeScale = target.scale.clone();
  late final int _homePriority = target.priority;

  /// The cage radius, from whichever of the creature's dimensions is larger.
  double get _cage {
    final s = target.absoluteScale;
    final w = target.size.x * s.x.abs();
    final h = target.size.y * s.y.abs();
    return math.max(w, h) * 0.62;
  }

  @override
  Future<void> onLoad() async {
    position = _fieldCentre();
    size = Vector2.all(_cage * 4);
    _field = HarvestParticleField(
      profile: profile,
      cage: _cage,
      specimenColor: accent,
    );
    // Lift the specimen over the dim so the field spotlights the real thing.
    target.priority = 910;
    _front
      ..position = position.clone()
      ..size = size.clone();
    parent?.add(_front);
    HarvestParticleField.announce(HarvestBeat.engage);
    unawaited(_runTask());
  }

  Future<void> _runTask() async {
    try {
      _success = await task();
    } catch (_) {
      _success = false;
    } finally {
      _taskDone = true;
    }
  }

  // ── The beat ───────────────────────────────────────────────────────────
  double get _closing => _norm(_t, 0.02, minSeize * 0.42);
  double get _lock => _norm(_t, minSeize * 0.38, minSeize * 0.55);
  double get _pressure => _norm(_t, minSeize * 0.55, minSeize);
  double get _take => (_success ?? false) ? _norm(_r, 0, _resolveSeconds) : 0.0;
  double get _shatter =>
      (_success ?? false) ? 0.0 : _norm(_r, 0, _resolveSeconds);

  /// 0..1 shove cycle — the creature leaning on the wall. A take holds it
  /// still at once, so it stands where its grains are read.
  double get _push {
    if (_resolving) {
      return (_success ?? false)
          ? 0.0
          : (1 - _norm(_r, 0, _resolveSeconds * 0.25));
    }
    return _pressure * (0.5 - 0.5 * math.cos(_t * math.pi * 2.4));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished) return;

    if (!_resolving) {
      _t += dt;
      // The specimen fights for as long as the roll takes. A slow answer
      // reads as a longer struggle, never as a frozen frame.
      if (_t >= minSeize && _taskDone) {
        _resolving = true;
        if (_success ?? false) _beginTake();
      }
    } else if (_reading) {
      // Held for the read, never for long: without grains the field still
      // takes, it just takes nothing you can see go.
      _readWait += dt;
      if (_readWait > 0.4) _reading = false;
    } else {
      if (!_announcedOutcome) {
        // The first frame of the take (its read done) or of the break.
        _announcedOutcome = true;
        HarvestParticleField.announce(
          (_success ?? false) ? HarvestBeat.take : HarvestBeat.shatter,
        );
      }
      _r += dt;
      if (_r >= _resolveSeconds + 0.25) {
        _finish();
        return;
      }
    }
    _driveSpecimen();
    final cut = _field.hasSpecimen
        ? _field.cutY(_take)
        : double.negativeInfinity;
    _spriteRef?.cutY = cut == double.negativeInfinity
        ? null
        : (cut == double.infinity ? 1e4 : cut);
  }

  /// THE POINT OF ALL THIS: the live component is what moves.
  void _driveSpecimen() {
    // TAKEN: it holds still where it stood and the take is the field's —
    // cut away behind the crest as its grains are drawn down. Without
    // grains (it could not be read) it thins out as the field takes it.
    if (_resolving && (_success ?? false)) {
      target
        ..position = _home.clone()
        ..scale = _homeScale.clone();
      if (!_field.hasSpecimen) {
        _setSpecimenOpacity(1.0 - 0.94 * Curves.easeIn.transform(_take));
      }
      return;
    }
    final flinch = math.sin(_lock * math.pi);
    final s = 1.0 - 0.09 * flinch + 0.07 * _push;
    final sh = Curves.easeOutCubic.transform(_shatter);
    final sx = s * (1 + 0.20 * sh);
    final sy = s * (1 + 0.08 * sh);
    target.scale = Vector2(
      _homeScale.x.sign * sx.abs() * _homeScale.x.abs(),
      _homeScale.y * sy,
    );
    final tremble = (_lock + _pressure) * (1 - _shatter).clamp(0, 1);
    target.position = Vector2(
      _home.x + math.sin(_t * 26) * 3.2 * tremble,
      _home.y + math.cos(_t * 21) * 1.8 * tremble,
    );
  }

  /// The roll held: stand it still and read it as it is showing.
  void _beginTake() {
    target
      ..position = _home.clone()
      ..scale = _homeScale.clone();
    _setSpecimenOpacity(1.0);
    final sprite = _spriteRef ?? _findSprite();
    if (sprite == null) return;
    _reading = true;
    _readWait = 0;
    sprite.readGrains(pixelRatio: 2).then((grains) {
      if (grains != null && isMounted) {
        final drawn = sprite.absoluteScale;
        final mine = absoluteScale.x.abs();
        final at = absoluteToLocal(sprite.absoluteCenter) - size / 2;
        _field.setSpecimen(
          drawn.x < 0 ? grains.mirrored() : grains,
          at: Offset(at.x, at.y),
          scale: drawn.x.abs() / (mine == 0 ? 1 : mine),
        );
      }
      _reading = false;
    });
  }

  CreatureSpriteComponent? _findSprite() {
    _setSpecimenOpacity(1.0);
    return _spriteRef;
  }

  /// Thins the live sprite. The specimen is a wrapper whose sprite is a
  /// child, so the sprite has to be found — but only once, not on every
  /// frame of the collapse.
  CreatureSpriteComponent? _spriteRef;
  bool _spriteResolved = false;

  void _setSpecimenOpacity(double value) {
    if (!_spriteResolved) {
      _spriteResolved = true;
      for (final child in target.children) {
        if (child is CreatureSpriteComponent) {
          _spriteRef = child;
          break;
        }
      }
    }
    _spriteRef?.spriteOpacity = value;
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    // Off the update pass: removing components (this one and, on a success,
    // the creature) from inside updateTree mutates the set being iterated.
    Future.microtask(_teardown);
  }

  void _teardown() {
    _front.removeFromParent();
    if (_success == true) {
      // Taken: it leaves the world with the field.
      target.removeFromParent();
    } else {
      // It broke out and is standing exactly where it was.
      _spriteRef?.cutY = null;
      _setSpecimenOpacity(1.0);
      target
        ..position = _home.clone()
        ..scale = _homeScale.clone()
        ..priority = _homePriority;
    }
    removeFromParent();
    if (!_done.isCompleted) _done.complete(_success ?? false);
  }

  @override
  void onRemove() {
    // Never strand the caller, and never leave the creature mid-squash.
    _front.removeFromParent();
    if (!_finished && target.isMounted) {
      _spriteRef?.cutY = null;
      _setSpecimenOpacity(1.0);
      target
        ..position = _home.clone()
        ..scale = _homeScale.clone()
        ..priority = _homePriority;
    }
    if (!_done.isCompleted) _done.complete(_success ?? false);
    super.onRemove();
  }

  // ── The apparatus ──────────────────────────────────────────────────────

  /// One side of the field — the far one here, under the creature; the near
  /// one from [_HarvestFieldFront], over it.
  void _paintLayer(Canvas canvas, {required bool back}) {
    if (!isLoaded) return;
    _field.paint(
      canvas,
      (size / 2).toOffset(),
      closing: _closing,
      lock: _lock,
      push: _push,
      strain: _t * 0.35,
      time: _t + _r,
      take: _take,
      shatter: _shatter,
      back: back,
    );
  }

  @override
  void render(Canvas canvas) => _paintLayer(canvas, back: true);
}

/// The near side of a [HarvestFieldEffect], drawn a step over the creature.
class _HarvestFieldFront extends PositionComponent {
  _HarvestFieldFront(this.owner) : super(anchor: Anchor.center, priority: 915);

  final HarvestFieldEffect owner;

  @override
  void render(Canvas canvas) => owner._paintLayer(canvas, back: false);
}

/// The rest of the scene, pulled down so the specimen is the lit thing.
///
/// Lives in the world under the specimen rather than over the whole game, so
/// the parallax and the camera keep running behind it.
class HarvestDim extends PositionComponent {
  HarvestDim({required this.fadeIn}) : super(priority: 890);

  final double fadeIn;
  double _t = 0;
  bool _out = false;

  void release() => _out = true;

  @override
  void update(double dt) {
    super.update(dt);
    _t += _out ? -dt * 2.4 : dt;
    if (_out && _t <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    // 0.38, not 0.62. This lies over a scene that is already dark, and the
    // point of it is to light the specimen, not to switch the lights off.
    final a = (_t / fadeIn).clamp(0.0, 1.0) * 0.38;
    if (a <= 0.005) return;
    // Big enough to cover any camera position in a scene this size.
    canvas.drawRect(
      const Rect.fromLTWH(-20000, -20000, 40000, 40000),
      Paint()..color = Colors.black.withValues(alpha: a),
    );
  }
}

/// 0 before [start], 1 after [end], clamped in between.
double _norm(double t, double start, double end) {
  if (end <= start) return t >= end ? 1.0 : 0.0;
  return ((t - start) / (end - start)).clamp(0.0, 1.0);
}
