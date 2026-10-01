import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/games/cosmic/planets/planet_art.dart'
    show paintSoftCircle;
import 'package:alchemons/widgets/fx/grain_assembly.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
import 'package:flame/components.dart';

/// A creature that can be kept from drawing — while its grains are read, so
/// nothing of it shows before it gathers. Hidden by not drawing rather than
/// by scale: a creature's own scale effects measure from its scale when they
/// start, and one started at nothing would swing it to double its size.
mixin Veiled on PositionComponent {
  bool veiled = false;

  @override
  void renderTree(Canvas canvas) {
    if (!veiled) super.renderTree(canvas);
  }
}

/// A party Alchemon gathering out of grains of itself where it will stand —
/// the space summoning, in the field — or coming apart into them and
/// drifting off when it is sent home.
///
/// Added beside the creature (same parent, drawn over it). It reads the
/// creature's sprite into grains as soon as the sprite is drawn, keeps the
/// creature hidden until then, plays, and takes itself away. If the grains
/// cannot be read the creature simply appears (or goes).
class WildSummon extends Component {
  WildSummon.gather(this.creature, {required this.accent, this.mirror = false})
    : scattering = false,
      onDone = null;

  WildSummon.scatter(
    this.creature, {
    required this.accent,
    this.mirror = false,
    this.onDone,
  }) : scattering = true;

  /// The creature (a WildMonComponent) — centred on its position.
  final Veiled creature;

  /// Its element: the heat its grains fly with.
  final Color accent;

  /// Whether its sprite is drawn facing the other way.
  final bool mirror;

  final bool scattering;
  final void Function()? onDone;

  static const double gatherTime = 0.95, scatterTime = 0.75;

  GrainAssembly? _assembly;
  bool _reading = false, _failed = false;
  double _waited = 0, _clock = 0;

  CreatureSpriteComponent? get _sprite {
    for (final c in creature.children) {
      if (c is CreatureSpriteComponent) return c;
    }
    return null;
  }

  @override
  void onMount() {
    super.onMount();
    // Nothing of it shows until its grains are in hand.
    if (!scattering) creature.veiled = true;
  }

  @override
  void update(double dt) {
    final sprite = _sprite;
    if (sprite == null || !sprite.isLoaded) {
      _waited += dt;
      if (_waited > 1.5) _finish();
      return;
    }
    if (!_reading) {
      _reading = true;
      sprite
          .readGrains(pixelRatio: 1.5)
          .then(
            (g) {
              if (g == null) {
                _failed = true;
              } else {
                _assembly = GrainAssembly(g, accent: accent);
              }
            },
            onError: (Object _) {
              _failed = true;
            },
          );
    }
    if (_failed) {
      _finish();
      return;
    }
    if (_assembly == null) return;
    creature.veiled = false;
    _clock += dt;
    final u = (_clock / (scattering ? scatterTime : gatherTime)).clamp(
      0.0,
      1.0,
    );
    sprite.spriteOpacity = scattering
        ? GrainAssembly.spriteOpacityScattering(u)
        : GrainAssembly.spriteOpacityGathering(u);
    if (u >= 1) _finish();
  }

  void _finish() {
    creature.veiled = false;
    final sprite = _sprite;
    if (sprite != null && sprite.isLoaded) {
      sprite.spriteOpacity = scattering ? 0 : 1;
    }
    removeFromParent();
    onDone?.call();
  }

  @override
  void render(Canvas canvas) {
    final a = _assembly;
    if (a == null) return;
    final at = Offset(creature.position.x, creature.position.y);
    final u = (_clock / (scattering ? scatterTime : gatherTime)).clamp(
      0.0,
      1.0,
    );
    // Its element's light where it gathers or comes apart.
    final k = math.sin(math.pi * u);
    if (k > 0) {
      paintSoftCircle(
        canvas,
        at,
        a.reach * 1.6,
        accent.withValues(alpha: 0.26 * k),
        14,
      );
    }
    if (scattering) {
      a.paintScatter(
        canvas,
        at,
        u,
        to: Offset(0, -a.reach * 2.4),
        mirror: mirror,
      );
    } else {
      a.paintGather(canvas, at, u, mirror: mirror);
    }
  }
}
