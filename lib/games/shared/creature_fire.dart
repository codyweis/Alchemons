// lib/games/shared/creature_fire.dart
//
// A creature firing its special, for the games that draw their party from
// tickers of their own (survival, the dungeons, open space): the fire sheet
// played once over the idle, from the moment of the cast.
//
//   final fire = CreatureFire(() => images);
//   fire.warm(member.spriteSheet, member.spriteVisuals);     // with its idle
//   fire.play(slot, member.spriteSheet, member.spriteVisuals); // at the cast
//   fire.tick(slot, dt);                                     // each frame
//   final f = fire.of(slot);                                 // when drawing
//   final sprite = (f?.ticker ?? idleTicker).getSprite();
//   final scale = idleScale * (f?.sizeRatio ?? 1);

import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_actions.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

/// One creature's fire, under way.
class FirePlayback {
  FirePlayback(this.ticker, this.sizeRatio);

  final SpriteAnimationTicker ticker;

  /// How much bigger an idle frame is than a fire frame: scale the sprite by
  /// this as well, and it is drawn the size it always is.
  final double sizeRatio;

  /// The frame index its costumes are drawn at, so they ride its head
  /// through the cast (`costumeActionFrame`).
  int get costumeFrame =>
      costumeActionFrame(CreatureAction.fire.index, ticker.currentIndex);
}

class CreatureFire {
  CreatureFire(this._images);

  final Images Function() _images;
  final Map<Object, FirePlayback> _playing = {};
  final Map<String, (SpriteAnimation, double)> _ready = {};
  final Set<String> _loading = {};

  /// The fire sheet for a creature drawn from [own] with [visuals], or null
  /// when its species has none.
  ActionSheet? _sheetFor(SpriteSheetDef? own, SpriteVisuals? visuals) {
    if (own == null) return null;
    return actionSheetFor(
      own.path,
      CreatureAction.fire,
      idleFrame: own.frameSize.x,
    );
  }

  /// Fetches the sheet ahead of the first cast.
  void warm(SpriteSheetDef? own, SpriteVisuals? visuals) {
    final def = _sheetFor(own, visuals);
    if (def != null) _load(def, own!, visuals, null);
  }

  /// [who] (a slot, a creature: any key) fires now.
  void play(Object who, SpriteSheetDef? own, SpriteVisuals? visuals) {
    final def = _sheetFor(own, visuals);
    if (def == null) return;
    // The copy it wears: plain, or its albino, mutation or variant bake.
    final ready = _ready[sheetForVisuals(def.def, visuals)!.path];
    if (ready != null) {
      _playing[who] = FirePlayback(ready.$1.createTicker(), ready.$2);
      return;
    }
    _load(def, own!, visuals, who);
  }

  Future<void> _load(
    ActionSheet def,
    SpriteSheetDef own,
    SpriteVisuals? visuals,
    Object? who,
  ) async {
    final path = sheetForVisuals(def.def, visuals)!.path;
    if (!_loading.add(path)) return;
    try {
      final image = await loadCreatureSheet(_images(), path);
      final side = image.width / def.cols;
      final anim = SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.variable(
          amount: def.frames,
          amountPerRow: def.cols,
          textureSize: Vector2.all(side),
          stepTimes: def.stepTimes,
          loop: false,
        ),
      );
      // Against the idle as it is drawn: a baked one is a smaller sheet.
      final ratio = sheetForVisuals(own, visuals)!.frameSize.x / side;
      _ready[path] = (anim, ratio);
      // The cast that asked for it: a moment late, this once.
      if (who != null) _playing[who] = FirePlayback(anim.createTicker(), ratio);
    } catch (_) {
      // No sheet, or it would not load: it stays on its idle.
    } finally {
      _loading.remove(path);
    }
  }

  /// [who]'s fire, while it is playing.
  FirePlayback? of(Object who) => _playing[who];

  /// Advances [who]'s fire; it is gone once it has played through.
  void tick(Object who, double dt) {
    final p = _playing[who];
    if (p == null) return;
    p.ticker.update(dt);
    if (p.ticker.done()) _playing.remove(who);
  }

  void remove(Object who) => _playing.remove(who);

  void clear() => _playing.clear();
}
