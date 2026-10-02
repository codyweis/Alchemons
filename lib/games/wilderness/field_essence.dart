import 'dart:ui';

import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
import 'package:flame/components.dart';

/// One of the player's own Alchemons coming apart into its element and back
/// where it stands — the essence its details screen plays when it is tapped
/// (see [ElementalEssence]), here in the field it lives in.
///
/// Added beside the creature (same parent, drawn over it). It reads the
/// creature's current frame into grains, fades the sprite out under them as
/// they let go, steps the same [EssenceField] the details screen does, and
/// takes itself away once the creature has gathered back. If the grains
/// cannot be read nothing happens.
class FieldEssence extends Component {
  FieldEssence(this.creature, {required this.element, this.mirror = false});

  /// The creature (a WildMonComponent) — centred on its position.
  final PositionComponent creature;

  final EssenceElement element;

  /// Whether its sprite is drawn facing the other way.
  final bool mirror;

  EssenceField? _field;
  bool _reading = false, _failed = false;
  double _t = 0, _waited = 0;

  CreatureSpriteComponent? get _sprite {
    for (final c in creature.children) {
      if (c is CreatureSpriteComponent) return c;
    }
    return null;
  }

  @override
  void update(double dt) {
    final sprite = _sprite;
    if (!creature.isMounted || sprite == null || !sprite.isLoaded) {
      _waited += dt;
      if (_waited > 1) _finish();
      return;
    }
    if (!_reading) {
      _reading = true;
      // As the details screen reads it: 2200 grains in 16 tones.
      sprite
          .readGrains(pixelRatio: 1.5, maxGrains: 2200, tones: 16)
          .then(
            (g) {
              if (g == null) {
                _failed = true;
              } else {
                _field = EssenceField(g, element);
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
    if (_field == null) return;
    _t += dt;
    sprite.spriteOpacity = EssenceField.spriteOpacity(_t);
    if (_t >= EssenceField.duration) _finish();
  }

  void _finish() {
    final sprite = _sprite;
    if (sprite != null && sprite.isLoaded) sprite.spriteOpacity = 1;
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final field = _field;
    if (field == null) return;
    final at = Offset(creature.position.x, creature.position.y);
    if (!mirror) {
      field.paint(canvas, at, _t);
      return;
    }
    // Read unturned: turned with the sprite, so its grains leave from the
    // creature as it is drawn.
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..scale(-1, 1);
    field.paint(canvas, Offset.zero, _t);
    canvas.restore();
  }
}
