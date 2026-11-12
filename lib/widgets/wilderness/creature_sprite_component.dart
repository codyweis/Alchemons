import 'dart:ui';
import 'dart:math' as math;

import 'package:alchemons/games/sprite_effects/alchemy_effect_component.dart';
import 'package:alchemons/utils/color_util.dart';
import 'package:alchemons/utils/effect_size.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_actions.dart';
import 'package:alchemons/widgets/fx/albino_look.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart';
import 'package:alchemons/widgets/fx/costume_paint.dart';
import 'package:alchemons/widgets/fx/darklet_ring.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:alchemons/widgets/fx/variant_look.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';

class CreatureSpriteComponent<G extends FlameGame> extends PositionComponent
    with HasGameReference<G> {
  final SpriteSheetDef sheet;
  final SpriteVisuals visuals;

  /// The sheet drawn: [sheet], or its baked mutation or albino copy (given
  /// either, the same).
  late final SpriteSheetDef _drawn = sheetForVisuals(sheet, visuals)!;
  final Vector2 desiredSize;
  final String? alchemyEffect;
  final String? variantFaction;
  final double effectScale;

  late final SpriteAnimationComponent _anim;
  _CostumeLayer? _costume;
  double _prismaticHue = 0;

  /// How solid the creature is drawn, so an effect can thin it out rather
  /// than only shrinking it — a body scaled to nothing reads as being
  /// switched off, where one that thins reads as coming apart.
  double get spriteOpacity => _anim.isMounted ? _anim.opacity : 1.0;
  set spriteOpacity(double value) {
    if (_anim.isMounted) _anim.opacity = value.clamp(0.0, 1.0);
    _costume?.opacity = value.clamp(0.0, 1.0);
  }

  bool get _isAlbino => visuals.brightness == 1.45;

  /// Whether its frames are running; a creature asleep holds still.
  bool get animating => !_anim.isMounted || _anim.playing;
  set animating(bool value) {
    // Held still (arranged, frozen): whatever it was doing is over.
    if (!value) {
      _asleep = false;
      _endAction();
    }
    if (_anim.isMounted) _anim.playing = value;
  }

  // An action being played over the idle (a hop), and the idle to go back to.
  SpriteAnimation? _idle;
  String? _actionPath;
  ActionSheet? _actionDef;
  bool _actionLoading = false;

  /// Whether it is playing an action now.
  bool get acting => _actionPath != null;

  bool _asleep = false;

  /// Whether it has been put to sleep (see [sleep]).
  bool get sleeping => _asleep;

  /// Puts it to sleep: slumped, eyes shut, breathing, until [wake]. False
  /// when it has no sleep sheet it can play (see [playAction]) — the caller
  /// then holds it still some other way.
  bool sleep() {
    if (_asleep) return true;
    if (!isLoaded || !_anim.isMounted) return false;
    if (DarkletRing.matches(_drawn.frameSize.x, _drawn.frameSize.y)) {
      return false;
    }
    final def = _actionFor(CreatureAction.sleep);
    if (def == null || _actionLoading) return false;
    _endAction();
    _asleep = true;
    _anim.playing = true;
    _actionLoading = true;
    _startAction(def);
    return true;
  }

  /// Awake again, on its idle.
  void wake() {
    if (!_asleep) return;
    _asleep = false;
    _endAction();
  }

  /// Plays [action] once over the idle, then goes back to it. False when it
  /// cannot: not loaded, held still, already playing one, or no sheet for it.
  bool playAction(CreatureAction action) {
    if (!isLoaded || !_anim.isMounted || !_anim.playing) return false;
    if (_asleep || action == CreatureAction.sleep) return false;
    if (_actionPath != null || _actionLoading) return false;
    // (Darklet's ring and its costumes follow the action.)
    final def = _actionFor(action);
    if (def == null) return false;
    _actionLoading = true;
    _startAction(def);
    return true;
  }

  /// [action]'s sheet for this species, or null. [sheet] is its own sheet,
  /// or already its baked copy: then the action's is found from the plain
  /// one it was baked from.
  ActionSheet? _actionFor(CreatureAction action) => actionSheetFor(
    sheet.path.split('#').first,
    action,
    idleFrame: _plainFrame,
  );

  /// The plain idle's frame side. A baked idle is drawn at no more than 512,
  /// so a 1200 px species is told from its sheet's name.
  double get _plainFrame {
    if (!isMutatedSheetPath(_drawn.path)) return _drawn.frameSize.x;
    final species = speciesOfSheet(_drawn.path) ?? '';
    return species.startsWith('LET') ? _drawn.frameSize.x : 1200;
  }

  Future<void> _startAction(ActionSheet def) async {
    // Held here: it may be gone from the game by the time the sheet arrives.
    final images = game.images;
    // The sheet it wears: plain, or its albino, mutation or variant bake.
    final path = sheetForVisuals(def.def, visuals)!.path;
    ActionSheetCache.retain(images, path);
    try {
      final image = await loadCreatureSheet(images, path);
      // Gone, held still, or woken (or put to sleep) while it was on its way.
      if (!isMounted ||
          !_anim.isMounted ||
          !_anim.playing ||
          def.loop != _asleep) {
        ActionSheetCache.release(images, path);
        return;
      }
      final side = image.width / def.cols;
      _idle = _anim.animation;
      _actionPath = path;
      _actionDef = def;
      _anim.animation = SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.variable(
          amount: def.frames,
          amountPerRow: def.cols,
          textureSize: Vector2.all(side),
          stepTimes: def.stepTimes,
          loop: def.loop,
        ),
      );
      // Its box is the idle's frame: an action's is drawn to fill it.
      if (!def.loop) _anim.animationTicker?.onComplete = _endAction;
    } catch (_) {
      // No sheet, or it would not load: it stays on its idle.
      ActionSheetCache.release(images, path);
    } finally {
      _actionLoading = false;
    }
  }

  /// Back to the idle, from its first frame (where every action ends).
  void _endAction() {
    final path = _actionPath;
    if (path == null) return;
    _actionPath = null;
    _actionDef = null;
    if (_anim.isMounted && _idle != null) _anim.animation = _idle;
    _idle = null;
    ActionSheetCache.release(game.images, path);
  }

  @override
  void onRemove() {
    final path = _actionPath;
    _actionPath = null;
    _actionDef = null;
    if (path != null) ActionSheetCache.release(game.images, path);
    super.onRemove();
  }

  /// Everything above this line (from the centre, in local units) is cut
  /// away: a fusion's crest, behind which the creature is grains instead.
  double? cutY;

  @override
  void render(Canvas canvas) {
    final cut = cutY;
    // Clipped here, before the children draw, so the sprite and any aura
    // behind it are cut together.
    if (cut != null) {
      canvas.clipRect(
        Rect.fromLTRB(
          -size.x,
          size.y / 2 + cut.clamp(-1e4, 1e4),
          size.x * 2,
          size.y * 2,
        ),
      );
    }
    super.render(canvas);
  }

  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.medium;

  /// Draws this frame of the creature in its parent's units at [alpha] of
  /// itself — its genetics coloring and any cut kept, its aura not — for
  /// an image of it, such as its reflection in still glass. One draw;
  /// nothing until it has loaded.
  void renderImage(Canvas canvas, double alpha) {
    if (!isLoaded || !_anim.isMounted) return;
    final frame = _anim.animationTicker?.getSprite();
    if (frame == null) return;
    canvas
      ..save()
      ..transform32(transformMatrix.storage);
    final cut = cutY;
    if (cut != null) {
      canvas.clipRect(
        Rect.fromLTRB(
          -size.x,
          size.y / 2 + cut.clamp(-1e4, 1e4),
          size.x * 2,
          size.y * 2,
        ),
      );
    }
    canvas.transform32(_anim.transformMatrix.storage);
    frame.render(
      canvas,
      size: _anim.size,
      overridePaint: _imagePaint
        ..colorFilter = _anim.paint.colorFilter
        ..color = Color.fromRGBO(
          255,
          255,
          255,
          (alpha * _anim.opacity).clamp(0.0, 1.0),
        ),
    );
    _costume?.paintOn(canvas, alpha);
    canvas.restore();
  }

  /// This frame of the creature, exactly as it is being drawn — its genetics
  /// coloring and size included — read into grains centred on this
  /// component's centre, in its local units. Null if it has not loaded.
  Future<SpecimenGrains?> readGrains({
    required double pixelRatio,
    int maxGrains = SpecimenGrains.maxGrains,
    int tones = SpecimenGrains.toneCount,
  }) async {
    if (!isLoaded || !_anim.isMounted) return null;
    final sprite = _anim.animationTicker?.getSprite();
    if (sprite == null) return null;
    // Room for a size gene over 1, which draws past this component's box.
    final box = size * 1.4;
    final w = (box.x * pixelRatio).ceil(), h = (box.y * pixelRatio).ceil();
    if (w <= 0 || h <= 0) return null;
    final rec = PictureRecorder();
    final c = Canvas(rec)
      ..scale(pixelRatio)
      ..translate(box.x / 2, box.y / 2)
      ..scale(_anim.scale.x, _anim.scale.y);
    sprite.render(
      c,
      size: _drawn.frameSize,
      anchor: Anchor.center,
      overridePaint: Paint()
        ..colorFilter = _anim.paint.colorFilter
        ..color = const Color(0xFFFFFFFF)
        ..filterQuality = FilterQuality.medium,
    );
    final image = rec.endRecording().toImageSync(w, h);
    try {
      final data = await image.toByteData(
        format: ImageByteFormat.rawStraightRgba,
      );
      if (data == null) return null;
      final grains = SpecimenGrains.fromRgba(
        data.buffer.asUint8List(),
        w,
        h,
        pixelRatio: pixelRatio,
        maxGrains: maxGrains,
        tones: tones,
      );
      return grains.length < 60 ? null : grains;
    } finally {
      image.dispose();
    }
  }

  CreatureSpriteComponent({
    required this.sheet,
    required this.visuals,
    required this.desiredSize,
    this.alchemyEffect,
    this.variantFaction,
    this.effectScale = 1.0,
  });

  @override
  Future<void> onLoad() async {
    size = desiredSize;

    // Effect layer FIRST so it renders behind the sprite
    if (alchemyEffect != null) {
      final effectComponent = _buildEffectComponent(alchemyEffect!);
      if (effectComponent != null) {
        effectComponent.position = size / 2;
        effectComponent.priority = -1; // Behind sprite
        add(effectComponent);
        // An effect with a near side also draws over the sprite, in step.
        if (AlchemyEffectPaint.hasFront(alchemyEffect)) {
          add(
            AlchemyEffectComponent(
                effectKey: effectComponent.effectKey,
                radius: effectComponent.radius,
                element: effectComponent.element,
                front: true,
                seed: effectComponent.seed,
              )
              ..position = size / 2
              ..priority = 1,
          );
        }
      }
    }

    Image image;
    try {
      image = await loadCreatureSheet(game.images, _drawn.path);
    } catch (e) {
      image = await _loadFallbackImage();
    }

    final cols = (_drawn.totalFrames + _drawn.rows - 1) ~/ _drawn.rows;

    final anim = SpriteAnimation.fromFrameData(
      image,
      SpriteAnimationData.sequenced(
        amount: _drawn.totalFrames,
        amountPerRow: cols,
        textureSize: _drawn.frameSize,
        stepTime: _drawn.stepTime,
        loop: true,
      ),
    );

    final fit = _fitScale(_drawn.frameSize, desiredSize);
    final finalScale = fit * visuals.scale;

    _anim =
        SpriteAnimationComponent(
            animation: anim,
            size: _drawn.frameSize,
            anchor: Anchor.center,
            position: size / 2,
            priority: 0, // Sprite on top
          )
          ..paint.filterQuality = FilterQuality.high
          ..scale = Vector2.all(finalScale);

    _applyColorFilters();
    add(_anim);
    // Darklet's galaxy ring, in the sprite's own space: far side behind it,
    // near side over it.
    if (DarkletRing.matches(_drawn.frameSize.x, _drawn.frameSize.y)) {
      for (final front in [false, true]) {
        add(
          _RingLayer(
              _anim,
              front: front,
              hopping: () => _actionPath != null && !_asleep,
            )
            ..size = _drawn.frameSize
            ..anchor = Anchor.center
            ..position = size / 2
            ..scale = Vector2.all(finalScale)
            ..priority = front ? 1 : -1,
        );
      }
    }
    // Worn costumes are part of the sprite: drawn after each frame, in it.
    final costumes = visuals.costumes;
    if (WornCostumes.parse(costumes) != null) {
      _anim.add(
        _costume = _CostumeLayer(
          costumes!,
          _anim,
          // In an action, the frame of it: the costume rides the head.
          () {
            final i = _anim.animationTicker?.currentIndex ?? 0;
            final def = _actionDef;
            return _actionPath != null && def != null
                ? def.costumeFrame(i)
                : i;
          },
        ),
      );
    }
  }

  // A sheet that fails to load leaves the creature blank rather than
  // standing in some other picture.
  Future<Image> _loadFallbackImage() {
    final recorder = PictureRecorder();
    Canvas(recorder);
    return recorder.endRecording().toImage(1, 1);
  }

  AlchemyEffectComponent? _buildEffectComponent(String effect) {
    if (!AlchemyEffectPaint.has(effect)) return null;
    final displayBase = displayBaseFromVisuals(
      baseBox: desiredSize.x,
      visualsScale: visuals.scale,
    );
    return AlchemyEffectComponent(
      effectKey: effect,
      radius: (displayBase * effectScale / 2).clamp(12.0, 80.0),
      element: variantFaction ?? visuals.auraElement,
    );
  }

  double _fitScale(Vector2 frame, Vector2 box) {
    final sx = box.x / frame.x;
    final sy = box.y / frame.y;
    return sx < sy ? sx : sy;
  }

  /// Apply all color effects (SV, hue, tint, albino) as a single color matrix.
  void _applyColorFilters() {
    final paint = _anim.paint;

    // Albino (non-prismatic): its look is in its sheet, but a mutated one's.
    if (_isAlbino && !visuals.isPrismatic) {
      paint.colorFilter = albinoFilter(visuals);
      paint.color = const Color(0xFFFFFFFF);
      return;
    }

    // Start from identity
    List<double> m = _identityMatrix();

    // 1) Brightness / saturation
    if (visuals.saturation != 1.0 || visuals.brightness != 1.0) {
      final sv = brightnessSaturationMatrix(
        visuals.brightness,
        visuals.saturation,
      );
      // Apply SV first
      m = _multiplyColorMatrices(sv, m);
    }

    // 2) Hue rotation (or prismatic)
    final currentHue = visuals.isPrismatic
        ? (visuals.hueShiftDeg + _prismaticHue)
        : visuals.hueShiftDeg;

    final normalizedHue = ((currentHue % 360) + 360) % 360;

    if (normalizedHue != 0) {
      final hue = hueRotationMatrix(normalizedHue);
      // Hue after SV
      m = _multiplyColorMatrices(hue, m);
    }

    // 3) Variant tint — equivalent to ColorFiltered.mode(tint, BlendMode.modulate)
    final tintColor = visuals.tint ?? _deriveVariantTint();

    // None over an albino, or a variant whose palette swap is in its sheet.
    if (tintColor != null &&
        !(_isAlbino && !visuals.isPrismatic) &&
        !variantBaked(visuals)) {
      final tr = tintColor.r;
      final tg = tintColor.g;
      final tb = tintColor.b;

      // Modulate RGB channels by tint; keep alpha.
      final tintMatrix = <double>[
        tr,
        0,
        0,
        0,
        0,
        0,
        tg,
        0,
        0,
        0,
        0,
        0,
        tb,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ];

      // Tint after hue + SV
      m = _multiplyColorMatrices(tintMatrix, m);
    }

    paint.colorFilter = ColorFilter.matrix(m);
    // Keep base color neutral so matrix does all the work
    paint.color = const Color(0xFFFFFFFF);
  }

  /// Derives tint color from variantFaction (matches deriveLineageTint logic).
  Color? _deriveVariantTint() {
    if (variantFaction == null || variantFaction!.isEmpty) return null;
    if (variantFaction!.trim().toLowerCase() == 'bloodborn') return null;
    return FactionColors.of(variantFaction!);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (visuals.isPrismatic) {
      _prismaticHue = (_prismaticHue + 360 * dt / 8.0) % 360;
      _applyColorFilters();
    }
  }

  // ── color matrix helpers ─────────────────────────────────────

  List<double> _identityMatrix() {
    // 4x5 identity color matrix: leaves color unchanged.
    return <double>[
      1, 0, 0, 0, 0, // R'
      0, 1, 0, 0, 0, // G'
      0, 0, 1, 0, 0, // B'
      0, 0, 0, 1, 0, // A'
    ];
  }

  /// Matrix multiplication for 4x5 color matrices:
  /// result = a ∘ b (apply b first, then a).
  List<double> _multiplyColorMatrices(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0.0);

    for (int row = 0; row < 4; row++) {
      // RGB/A columns
      for (int col = 0; col < 4; col++) {
        double sum = 0.0;
        for (int k = 0; k < 4; k++) {
          sum += a[row * 5 + k] * b[k * 5 + col];
        }
        out[row * 5 + col] = sum;
      }

      // Translation column (index 4)
      double t = a[row * 5 + 4];
      for (int k = 0; k < 4; k++) {
        t += a[row * 5 + k] * b[k * 5 + 4];
      }
      out[row * 5 + 4] = t;
    }

    return out;
  }
}

// ── color math functions (same as widget version) ─────────────

List<double> brightnessSaturationMatrix(double brightness, double saturation) =>
    tintGeneMatrix(brightness, saturation);

List<double> hueRotationMatrix(double degrees) => hueShiftMatrix(degrees);

/// Worn costumes, a child of the sprite: drawn in the frame's own space
/// after it, at the fit of the frame that is up, so they move with whatever
/// the sprite does.
class _CostumeLayer extends Component {
  _CostumeLayer(this.costumes, this.sprite, this.frame);

  final String costumes;
  final SpriteAnimationComponent sprite;

  /// The frame it is fitted to now.
  final int Function() frame;

  /// Two creatures in the same costume are not in step.
  double _t = math.Random().nextDouble() * 10;
  double opacity = 1;

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) => paintOn(canvas, 1);

  /// Draws it at [alpha] of itself, in the sprite's local units.
  void paintOn(Canvas canvas, double alpha) => CostumePaint.paintWorn(
    canvas,
    costumes,
    Offset.zero & sprite.size.toSize(),
    frame(),
    _t,
    opacity: (alpha * opacity).clamp(0.0, 1.0),
  );
}

/// One side of Darklet's ring, laid over the sprite's frame.
class _RingLayer extends PositionComponent {
  _RingLayer(this.sprite, {required this.front, required this.hopping});

  final SpriteAnimationComponent sprite;
  final bool front;

  /// Whether the sprite is on its hop sheet now, not its idle.
  final bool Function() hopping;
  double _t = math.Random().nextDouble() * 10;

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) => DarkletRing.paint(
    canvas,
    Offset.zero & size.toSize(),
    (hopping() ? DarkletRing.hopBase : 0) +
        (sprite.animationTicker?.currentIndex ?? 0),
    _t,
    front: front,
    opacity: sprite.opacity,
  );
}
