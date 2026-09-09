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
// Strokes only — no MaskFilter, per the house rule.

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/games/wilderness/disintegration.dart';
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

  static const _amber = Color(0xFFE4C16A);
  static const _ember = Color(0xFFD07A4A);
  static const _resolveSeconds = 0.9;

  // Scratch drawing objects. render() runs every frame inside the game loop,
  // where building eleven Paints and twenty-one Paths per frame is real
  // garbage for something that never changes shape — only colour and width.
  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Path _arc = Path();

  double _t = 0; // seconds since the field engaged
  double _r = 0; // seconds into the resolution
  bool? _success;
  bool _taskDone = false;
  bool _resolving = false;
  bool _finished = false;

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
    // Lift the specimen over the dim so the field spotlights the real thing.
    target.priority = 910;
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
  double get _collapse =>
      (_success ?? false) ? _norm(_r, 0, _resolveSeconds) : 0.0;
  double get _shatter =>
      (_success ?? false) ? 0.0 : _norm(_r, 0, _resolveSeconds);

  /// 0..1 shove cycle — the creature leaning on the wall.
  double get _push {
    if (_resolving) return (1 - _norm(_r, 0, _resolveSeconds * 0.25));
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
      if (_t >= minSeize && _taskDone) _resolving = true;
    } else {
      _r += dt;
      if (_r >= _resolveSeconds + 0.25) {
        _finish();
        return;
      }
    }
    _driveSpecimen();
  }

  /// THE POINT OF ALL THIS: the live component is what moves.
  void _driveSpecimen() {
    final flinch = math.sin(_lock * math.pi);
    var s = 1.0 - 0.09 * flinch + 0.07 * _push;

    // TAKEN. It used to squash to nothing, which reads as the sprite being
    // switched off rather than as a specimen being taken apart. It now swells
    // and thins while the motes carry it off, the same way the breeding
    // chamber does it.
    final c = Curves.easeOutCubic.transform(_collapse);
    final sh = Curves.easeOutCubic.transform(_shatter);
    _setSpecimenOpacity(1.0 - 0.94 * c);

    final sx = s * (1 + 0.26 * c) * (1 + 0.20 * sh);
    final sy = s * (1 + 0.20 * c) * (1 + 0.08 * sh);
    target.scale = Vector2(
      _homeScale.x.sign * sx.abs() * _homeScale.x.abs(),
      _homeScale.y * sy,
    );

    // The shake now peaks as it comes apart and eases off once there is
    // little left to shake, instead of stopping the moment the field wins.
    final breakShudder = _collapse * (1 - _collapse) * 4.0;
    final tremble =
        (_lock + _pressure) * (1 - _collapse - _shatter).clamp(0, 1) +
        breakShudder;
    target.position = Vector2(
      _home.x + math.sin(_t * 26) * 3.2 * tremble,
      _home.y + math.cos(_t * 21) * 1.8 * tremble - 10 * c,
    );
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
    if (_success == true) {
      // Taken: it leaves the world with the field.
      target.removeFromParent();
    } else {
      // It broke out and is standing exactly where it was.
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
    if (!_finished && target.isMounted) {
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
  @override
  void render(Canvas canvas) {
    final c = (size / 2).toOffset();
    final cage = _cage;
    final collapse = Curves.easeInOutCubic.transform(_collapse);
    final shatter = Curves.easeOutCubic.transform(_shatter);
    final push = _push;

    // The pool of light it stands the specimen in — layered discs, no blur.
    // A real pool, warm and under the creature — at 0.05 it may as well not
    // have been there, which is half of why the shot read as unlit.
    final lit = (0.35 + 0.65 * _closing) * (1 - collapse);
    for (var i = 4; i >= 1; i--) {
      canvas.drawCircle(
        c,
        cage * (0.5 + i * 0.32),
        _fill
          ..color = Color.lerp(
            accent,
            _amber,
            0.5,
          )!.withValues(alpha: (0.14 * lit) / i),
      );
    }

    // Everything about the apparatus below comes from the harvester in hand:
    // a Crusher arrives as two heavy jaws in stages, a Drown as a continuous
    // sheet rippling round itself, a Snare as thin tendrils that cinch.
    final shaped = profile.closingCurve(_closing);
    final strainPhase = _t * 0.35;
    for (var ring = 0; ring < profile.ringCount; ring++) {
      final rest = cage * (1.0 + ring * 0.2);
      final start = rest * (3.6 - ring * 0.4);
      var radius = start + (rest - start) * shaped;
      radius *= 1 - 0.92 * collapse;
      radius *= 1 + 1.6 * shatter;
      if (radius <= 1) continue;

      final spin =
          _t *
          (ring.isEven ? 1.0 : -1.0) *
          profile.spinRate *
          (0.9 + ring * 0.4);
      final segs = profile.segsBase + ring * profile.segsPerRing;
      final alpha =
          (0.22 + 0.6 * shaped) * (1 - collapse * 0.4) * (1 - shatter);
      if (alpha <= 0.01) continue;

      final ringTint = profile.ringColor(ring);
      final paint = _stroke
        ..strokeWidth =
            (ring == 0 ? profile.strokeBase : profile.strokeBase * 0.6) +
            1.4 * push
        ..color = ringTint.withValues(alpha: alpha);

      for (var s = 0; s < segs; s++) {
        final a0 = spin + s * math.pi * 2 / segs;
        final a1 = a0 + math.pi * 2 / segs * 0.62;
        final fly =
            shatter * cage * profile.shatterSpread * (0.6 + 0.4 * (s % 3));
        final off = shatter == 0
            ? Offset.zero
            : Offset(math.cos(a0), math.sin(a0)) * fly;
        final path = _arc..reset();
        const steps = 10;
        for (var k = 0; k <= steps; k++) {
          final a = a0 + (a1 - a0) * k / steps;
          final rr =
              radius +
              profile.radialFlex(a, strainPhase, push, cage) * (1 - collapse);
          final p = c + Offset(math.cos(a), math.sin(a)) * rr + off;
          k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    // The bound sigil, for the units that write a specimen into place rather
    // than clamping it.
    if (profile.sigil && shaped > 0.2 && shatter < 0.9) {
      final r = cage * 1.05 * (1 - 0.92 * collapse);
      final spin = -_t * profile.spinRate * 0.5;
      final p = _stroke
        ..strokeWidth = 1.4
        ..color = profile.accent.withValues(
          alpha: 0.42 * shaped * (1 - shatter) * (1 - collapse),
        );
      final path = _arc..reset();
      for (var i = 0; i <= 6; i++) {
        // Step by two points round a hexagon to draw the star in one stroke.
        final a = spin + (i * 2 % 6) * math.pi / 3;
        final pt = c + Offset(math.cos(a), math.sin(a)) * r;
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, p);
    }

    // Anchors biting in.
    final bite = Curves.easeOutBack.transform(
      _norm(_t, minSeize * 0.36, minSeize * 0.58),
    );
    if (bite > 0.01 && collapse < 0.9 && shatter < 0.9) {
      final r = cage * (1.45 - 0.1 * bite) * (1 - 0.92 * collapse);
      final p = _stroke
        ..strokeWidth = 2.2
        ..color = profile.accent.withValues(
          alpha: 0.55 * bite * (1 - shatter) * (1 - collapse),
        );
      for (var i = 0; i < 4; i++) {
        final a = i * math.pi / 2 + math.pi / 4;
        final u = Offset(math.cos(a), math.sin(a));
        final across = Offset(-u.dy, u.dx);
        canvas.drawLine(c + u * r, c + u * (r + 15), p);
        canvas.drawLine(
          c + u * (r + 15) - across * 8,
          c + u * (r + 15) + across * 8,
          p,
        );
      }
    }

    // SUCCESS — the specimen comes apart and the field takes what is left.
    if (_collapse > 0.01) {
      Disintegration.paint(
        canvas,
        centre: c,
        unit: cage * 1.15,
        breakUp: _collapse,
        gather: collapse,
        color: Color.lerp(accent, _amber, 0.35)!,
      );
    }

    // SUCCESS — the field falls in and takes what it held.
    if (collapse > 0.01) {
      canvas.drawCircle(
        c,
        cage * (1 - collapse) + 5,
        _stroke
          ..strokeWidth = 2 + 9 * collapse
          ..color = _amber.withValues(alpha: 0.8 * (1 - collapse)),
      );
      final draw = _stroke..strokeWidth = 1.8;
      for (var i = 0; i < 14; i++) {
        final a = i * math.pi * 2 / 14 + collapse * 1.4;
        final u = Offset(math.cos(a), math.sin(a));
        final lead = ((collapse * 1.6) - (i % 5) * 0.12).clamp(0.0, 1.0);
        if (lead <= 0) continue;
        final outer = cage * (1.3 - lead);
        canvas.drawLine(
          c + u * outer,
          c + u * (outer - cage * 0.24 * (1 - lead)),
          draw
            ..color = Color.lerp(
              accent,
              _amber,
              0.6,
            )!.withValues(alpha: 0.8 * (1 - lead)),
        );
      }
    }

    // FAILURE — the wall cracks outward and it is still standing.
    if (shatter > 0.01) {
      final crack = _stroke
        ..strokeWidth = 2.4 * (1 - shatter)
        ..color = _ember.withValues(alpha: 0.75 * (1 - shatter));
      for (var i = 0; i < 9; i++) {
        final a = i * math.pi * 2 / 9 + 0.3;
        final u = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(
          c + u * (cage * (0.9 + 0.7 * shatter)),
          c + u * (cage * (1.1 + 2.1 * shatter)),
          crack,
        );
      }
    }
  }
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

/// THE FUSION, PLAYED ON THE TWO CREATURES STANDING IN THE SCENE.
///
/// Same problem as the harvest and the same answer: the encounter's breed used
/// to push a route holding freshly built copies of the party creature and the
/// wild one, so the pair you were looking at blinked out and two duplicates
/// did the fusing on a black card. Here the live components are hauled into
/// each other, overlap, and are consumed — and the route that follows draws
/// the burst and the reveal with no specimens in it at all.
class FusionFieldEffect extends PositionComponent {
  FusionFieldEffect({
    required this.a,
    required this.b,
    required this.accentA,
    required this.accentB,
    this.seconds = 1.35,
  }) : super(anchor: Anchor.center, priority: 900);

  final PositionComponent a;
  final PositionComponent b;
  final Color accentA;
  final Color accentB;

  /// How long the pair take to meet.
  final double seconds;

  final Completer<void> _done = Completer<void>();
  Future<void> get finished => _done.future;

  /// Where the two actually met, in the world's own coordinates. The caller
  /// needs it to put what happens next in the same place.
  Vector2 get meetingPoint => _absMid;

  static const _amber = Color(0xFFE4C16A);

  // Same reason as the harvest field: this renders every frame, and the
  // shapes never change — only their colour and width do.
  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  double _t = 0;
  bool _over = false;

  late final Vector2 _homeA = a.position.clone();
  late final Vector2 _homeB = b.position.clone();
  late final Vector2 _scaleA = a.scale.clone();
  late final Vector2 _scaleB = b.scale.clone();
  late final int _prioA = a.priority;
  late final int _prioB = b.priority;

  /// THE MEETING POINT, IN ABSOLUTE SPACE.
  ///
  /// The two creatures do NOT share a parent — the wild one hangs off its
  /// spawn point and the party one off an anchor of its own, on a layer with
  /// its own parallax and scale. Averaging their local `position`s treated
  /// two different coordinate systems as one, so they lurched somewhere near
  /// their own origins instead of towards each other.
  late final Vector2 _absMid = (a.absoluteCenter + b.absoluteCenter) / 2;

  static Vector2 _localFor(Component c, Vector2 absolute) {
    final p = c.parent;
    return p is PositionComponent ? p.absoluteToLocal(absolute) : absolute;
  }

  /// Where each of them has to end up, expressed in its OWN parent's space.
  late final Vector2 _metA = _localFor(a, _absMid);
  late final Vector2 _metB = _localFor(b, _absMid);

  // TWO BEATS, IN THIS ORDER: come apart, then come together. Travel used to
  // run 0.10..0.88 with the consume only starting at 0.82, so the pair crossed
  // the gap intact and winked out on arrival — a collision, not a fusion. The
  // windows now match the breeding chamber exactly, because this is the same
  // event in a different renderer.
  double get _breakUp =>
      Curves.easeOutCubic.transform(_norm(_t, seconds * 0.04, seconds * 0.46));
  double get _travel =>
      Curves.easeInCubic.transform(_norm(_t, seconds * 0.46, seconds * 0.90));
  double get _consume => _norm(_t, seconds * 0.74, seconds * 0.98);

  @override
  Future<void> onLoad() async {
    position = _localFor(this, _absMid);
    size = Vector2.all((a.absoluteCenter - b.absoluteCenter).length + 160);
    a.priority = 910;
    b.priority = 910;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_over) return;
    _t += dt;

    // The shake belongs to the break-up, hardest as each comes apart.
    final breakUp = _breakUp;
    final shudder = breakUp * (1 - breakUp) * 4.0;
    final jitter = math.sin(_t * 46) * 4.0 * shudder;

    // Swells as it comes apart, and only the remnant is carried across.
    final grow = 1 + 0.34 * breakUp - 0.92 * Curves.easeIn.transform(_consume);

    a.position = (_homeA + (_metA - _homeA) * _travel)..x += jitter;
    b.position = (_homeB + (_metB - _homeB) * _travel)..x -= jitter;
    a.scale = Vector2(_scaleA.x.sign * grow.abs(), _scaleA.y * grow);
    b.scale = Vector2(_scaleB.x.sign * grow.abs(), _scaleB.y * grow);

    // Thin hard during the break-up, so what crosses the gap is the mote
    // cloud rather than a sprite with sparkle over it.
    final solidity = (1.0 - 0.78 * breakUp) * (1.0 - _consume);
    _setOpacity(a, solidity);
    _setOpacity(b, solidity);

    if (_t >= seconds) _finish();
  }

  /// A creature's live centre, in this component's own space.
  Offset _localCentreOf(PositionComponent target) {
    final abs = target.absoluteCenter;
    final p = parent;
    final local = p is PositionComponent ? p.absoluteToLocal(abs) : abs;
    return (local - position + size / 2).toOffset();
  }

  /// Resolved once each, rather than walking two child lists every frame.
  CreatureSpriteComponent? _spriteA;
  CreatureSpriteComponent? _spriteB;
  bool _spritesResolved = false;

  void _resolveSprites() {
    if (_spritesResolved) return;
    _spritesResolved = true;
    for (final child in a.children) {
      if (child is CreatureSpriteComponent) {
        _spriteA = child;
        break;
      }
    }
    for (final child in b.children) {
      if (child is CreatureSpriteComponent) {
        _spriteB = child;
        break;
      }
    }
  }

  void _setOpacity(PositionComponent target, double value) {
    _resolveSprites();
    final sprite = identical(target, a) ? _spriteA : _spriteB;
    sprite?.spriteOpacity = value;
  }

  void _finish() {
    if (_over) return;
    _over = true;
    // Off the update pass — removing here mutates the set being iterated.
    Future.microtask(() {
      a.removeFromParent();
      b.removeFromParent();
      removeFromParent();
      if (!_done.isCompleted) _done.complete();
    });
  }

  @override
  void onRemove() {
    if (!_over) {
      // Torn down mid-fusion: hand both creatures back intact.
      _setOpacity(a, 1.0);
      _setOpacity(b, 1.0);
      a
        ..position = _homeA.clone()
        ..scale = _scaleA.clone()
        ..priority = _prioA;
      b
        ..position = _homeB.clone()
        ..scale = _scaleB.clone()
        ..priority = _prioB;
    }
    if (!_done.isCompleted) _done.complete();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    final c = (size / 2).toOffset();
    final r =
        ((a.absoluteCenter - b.absoluteCenter).length / 2 + 40) *
        (1 - 0.7 * _travel);
    final mix = Color.lerp(accentA, accentB, 0.5)!;

    // Each comes apart over its own body, wherever that body currently is —
    // the cloud has to sit on the creature, not at the meeting point, or the
    // two beats stop being connected.
    final breakUp = _breakUp;
    if (breakUp > 0.01) {
      final unit = math.max(24.0, r * 0.42);
      Disintegration.paint(
        canvas,
        centre: _localCentreOf(a),
        unit: unit,
        breakUp: breakUp,
        gather: _travel,
        color: accentA,
      );
      Disintegration.paint(
        canvas,
        centre: _localCentreOf(b),
        unit: unit,
        breakUp: breakUp,
        gather: _travel,
        color: accentB,
      );
    }

    // The seam between them, brightening as they close.
    for (var i = 4; i >= 1; i--) {
      canvas.drawCircle(
        c,
        r * (0.35 + i * 0.22) * (1 - 0.5 * _consume),
        _fill
          ..color = Color.lerp(
            mix,
            _amber,
            0.4,
          )!.withValues(alpha: (0.10 * (0.25 + 0.75 * _travel)) / i),
      );
    }

    // A ring drawing tight around the pair.
    canvas.drawCircle(
      c,
      r,
      _stroke
        ..strokeWidth = 1.6 + 2.4 * _travel
        ..color = _amber.withValues(alpha: 0.22 + 0.6 * _travel),
    );

    // The strands that pull them in.
    final strand = _stroke
      ..strokeWidth = 1.4
      ..color = _amber.withValues(alpha: 0.5 * _travel);
    for (var i = 0; i < 10; i++) {
      final ang = i * math.pi * 2 / 10 + _t * 1.6;
      final u = Offset(math.cos(ang), math.sin(ang));
      canvas.drawLine(c + u * (r * 1.35), c + u * (r * 0.9), strand);
    }
  }
}
