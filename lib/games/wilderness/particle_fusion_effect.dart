import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
import 'package:flame/components.dart';

/// THE FUSION, IN THE SCENE, IN PARTICLES — the breed chamber's merge played
/// on the two creatures standing in the encounter.
///
/// Each is read into grains of itself where it stands and cut away behind a
/// crest as they take its place; the grains pour into one cloud between them
/// and it falls in on itself. Like the chamber it is a [FusionParticleField];
/// this component only reads the pair, runs the field's time and paints it.
///
/// The time is steered, because a wild fusion has a verdict to wait on:
/// [calibrate] turns them to grains and holds there, [fuse] runs on to the
/// end, [recoil] runs back so the grains go back into the pair.
///
/// A plain [Component], so it draws in its parent's own space: add it to the
/// parent of one of the pair.
class ParticleFusionEffect extends Component {
  ParticleFusionEffect({
    required this.a,
    required this.b,
    required this.accentA,
    required this.accentB,
  }) : super(priority: 905);

  /// The party creature and the wild one.
  final PositionComponent a;
  final PositionComponent b;
  final Color accentA;
  final Color accentB;

  FusionParticleField? _field;
  CreatureSpriteComponent? _spriteA, _spriteB;

  /// The field's time, where it is headed, and how fast (field seconds per
  /// second).
  double _t = 0, _target = 0, _rate = 1;
  double _clock = 0;
  Completer<void>? _arrived;

  /// The pair as they were read, once they have been.
  List<SpecimenGrains>? get specimens => _field?.specimens;

  /// Where the two became one, in absolute coordinates — or null before the
  /// pair has been read.
  Vector2? get meetingPoint {
    final f = _field;
    if (f == null) return null;
    final local = Vector2(f.core.dx, f.core.dy);
    final p = parent;
    return p is PositionComponent ? p.absolutePositionOf(local) : local;
  }

  static CreatureSpriteComponent? _spriteOf(PositionComponent c) {
    for (final child in c.children) {
      if (child is CreatureSpriteComponent) return child;
    }
    return null;
  }

  @override
  Future<void> onLoad() async {
    _spriteA = _spriteOf(a);
    _spriteB = _spriteOf(b);
    final p = parent;
    final parentScale = p is PositionComponent ? p.absoluteScale.x.abs() : 1.0;

    Offset local(Vector2 abs) {
      final v = p is PositionComponent ? p.absoluteToLocal(abs) : abs;
      return Offset(v.x, v.y);
    }

    Future<(SpecimenGrains, Offset, double)> read(
      PositionComponent body,
      CreatureSpriteComponent? sprite,
      Color accent,
    ) async {
      final at = local((sprite ?? body).absoluteCenter);
      final drawn = (sprite ?? body).absoluteScale;
      final scale = drawn.x.abs() / parentScale;
      // ~2 pixels per unit is as fine as a grain needs.
      final grains = await sprite?.readGrains(pixelRatio: 2);
      final box = (sprite ?? body).size.x;
      final read = grains ?? SpecimenGrains.disc(accent, radius: box * 0.3);
      // Read the right way round; drawn mirrored if it faces the other way.
      return (drawn.x < 0 ? read.mirrored() : read, at, scale);
    }

    final ra = await read(a, _spriteA, accentA);
    final rb = await read(b, _spriteB, accentB);
    final size = math.max(
      (_spriteA?.size.x ?? a.size.x) * ra.$3,
      (_spriteB?.size.x ?? b.size.x) * rb.$3,
    );
    _field = FusionParticleField(
      specimens: [ra.$1, rb.$1],
      centres: [ra.$2, rb.$2],
      scales: [ra.$3, rb.$3],
      core: Offset.lerp(ra.$2, rb.$2, 0.5)!,
      coreRadius: size * 0.32,
      colors: [accentA, accentB],
    );
  }

  Future<void> _runTo(double target, double seconds) {
    _arrived?.complete();
    final done = Completer<void>();
    _arrived = done;
    _target = target;
    _rate = seconds <= 0 ? double.infinity : (target - _t).abs() / seconds;
    if (_rate == 0) _rate = 1;
    return done.future;
  }

  /// SKIP: jumps to wherever it is running, and the run lands on the next
  /// frame (once the pair have been read, if that is still going on).
  void finishNow() => _t = _target;

  /// Both turn to grains where they stand, and hold there.
  Future<void> calibrate() => _runTo(FusionParticleField.standTime, 0.6);

  /// On to the end: they pour together and are gone. The pair are removed
  /// from the scene when it lands.
  Future<void> fuse() async {
    await _runTo(
      FusionParticleField.duration,
      FusionParticleField.duration - _t,
    );
    a.removeFromParent();
    b.removeFromParent();
  }

  /// Back into the pair, and this goes.
  Future<void> recoil() async {
    await _runTo(0, 0.52);
    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _clock += dt;
    // Nothing moves until the pair have been read: the crest and the grains
    // have to start together.
    if (_field == null) return;
    if (_t != _target) {
      final step = _rate * dt;
      _t = _t < _target
          ? math.min(_target, _t + step)
          : math.max(_target, _t - step);
    }
    final f = _field!;
    _spriteA?.cutY = _t <= 0 ? null : _finite(f.cutY(0, _t));
    _spriteB?.cutY = _t <= 0 ? null : _finite(f.cutY(1, _t));
    if (_t == _target && _arrived != null) {
      final done = _arrived!;
      _arrived = null;
      done.complete();
    }
  }

  static double? _finite(double v) =>
      v == double.negativeInfinity ? null : (v == double.infinity ? 1e4 : v);

  @override
  void render(Canvas canvas) {
    final f = _field;
    if (f == null) return;
    f.paint(canvas, _t, back: true, clock: _clock);
    f.paint(canvas, _t, back: false, clock: _clock);
  }

  @override
  void onRemove() {
    // Torn down mid-fusion, or recoiled: hand both creatures back whole.
    _spriteA?.cutY = null;
    _spriteB?.cutY = null;
    _arrived?.complete();
    _arrived = null;
    super.onRemove();
  }
}
