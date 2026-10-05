// lib/games/wilderness/keepsake_component.dart
//
// A keepsake standing in the home biome (models/home_keepsakes.dart), drawn
// by its art (widgets/fx/keepsake_art.dart) at its point's feet: lit for
// the field's hour, stirred when it is tapped or when one of the residents
// comes to it or goes through it.

import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/audio/sound_cue.dart';
import 'package:alchemons/games/cosmic/obsidian_kit.dart' show PointBatch;
import 'package:alchemons/games/wilderness/creature_feet.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/keepsake_art.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';

class KeepsakeComponent extends PositionComponent
    with HasGameReference<SceneGame>, TapCallbacks
    implements FieldThing {
  KeepsakeComponent({
    required this.kind,
    required this.art,
    required double rowSize,
    bool flip = false,
    this.onTap,
    this.ghost = false,
  }) : super(priority: 20) {
    final k = rowSize / 100 * kKeepsakeScale;
    scale = Vector2(flip ? -k : k, k);
  }

  /// How big a keepsake stands against a creature of its row: a portal a
  /// little taller than what walks through it, a torch a head over it.
  static const double kKeepsakeScale = 0.62;

  final String kind;
  final KeepsakeArt art;
  final VoidCallback? onTap;

  /// Stood in only to be tried: drawn faint, and nobody visits it.
  @override
  final bool ghost;

  final KeepsakeTime _time = KeepsakeTime(
    t: math.Random().nextDouble() * 20,
  );

  @override
  String get thingKind => kind;

  @override
  void stir([double strength = 1]) {
    if (ghost) return;
    _time.stir = math.max(_time.stir, strength);
    _sound();
  }

  /// When it last sounded (its own clock), so a visitor stirring it every
  /// second or two is heard as one visit, not a stutter.
  double _soundedAt = -1e9;

  /// Its own sound, once per visit's worth of stirring, if it can be seen.
  void _sound() {
    final cue = SoundCue.forHomeThing(kind);
    final anchor = parent;
    if (cue == null || anchor is! PositionComponent) return;
    final gap = switch (cue) {
      // Rhythms: each landing, each beat.
      SoundCue.homeStep => 0.3,
      SoundCue.homeSpores => 0.5,
      SoundCue.homeHeart => 1.4,
      SoundCue.homePortal => 0.8,
      SoundCue.homeSteam => 3.0,
      SoundCue.homeOrrery => 2.4,
      // One a visit.
      SoundCue.homeSplash => 12.0,
      _ => 6.0,
    };
    if (_time.t - _soundedAt < gap) return;
    if (!game.isOnScreen(anchor)) return;
    _soundedAt = _time.t;
    game.onSound?.call(cue);
  }

  @override
  double? get seat {
    final s = art.seat;
    return s == null ? null : s * scale.y;
  }

  @override
  List<Offset> get seats => [
    for (final o in art.seats(_time)) Offset(o.dx * scale.x, o.dy * scale.y),
  ];

  /// How deep in the night [hour] is, 0 to 1, eased through dusk and dawn.
  static double nightOf(double hour) {
    double ramp(double a, double b, double x) =>
        ((x - a) / (b - a)).clamp(0.0, 1.0);
    final dusk = ramp(18.5, 21, hour), dawn = 1 - ramp(5, 7.2, hour);
    final n = hour >= 12 ? dusk : dawn;
    return n * n * (3 - 2 * n);
  }

  @override
  void update(double dt) {
    _time
      ..t += dt
      ..stir = math.max(0, _time.stir - dt / 2.2);
    final night = nightOf(game.fieldHour);
    _time
      ..night = night
      ..daylight = 1 - night;
  }

  /// How much of it the ground under it gives back (the Arcane's glass).
  double reflection = 0;

  _KeepsakeFront? _front;

  @override
  void onMount() {
    super.onMount();
    final layer = game.layerOf(this);
    reflection = layer == null ? 0 : game.reflectionOn(layer);
    // What it draws over its visitors goes in front of every creature on
    // its layer, following it about.
    final anchor = parent;
    final layerBox = anchor?.parent;
    if (art.hasFront && anchor is PositionComponent && layerBox != null) {
      layerBox.add(_front = _KeepsakeFront(this, anchor));
    }
  }

  static final Paint _ghostPaint = Paint()
    ..color = const Color(0x73FFFFFF);

  @override
  void render(Canvas canvas) {
    if (ghost) canvas.saveLayer(null, _ghostPaint);
    if (reflection > 0) art.paintReflection(canvas, reflection * 0.85);
    art.paint(canvas, _time);
    _mirrorVisitors(canvas);
    if (ghost) canvas.restore();
  }

  /// Still water gives back whoever stands at its edge (the Reflecting
  /// Pool): each one's frame drawn upside down about the surface, inside
  /// the water.
  void _mirrorVisitors(Canvas canvas) {
    final water = art.mirror;
    final anchor = parent;
    if (water == null || ghost || anchor is! PositionComponent) return;
    final kx = scale.x, ky = scale.y;
    final reach = water.width / 2 * kx.abs() + 40;
    final near = game.residentsBeside(anchor, reach);
    if (near.isEmpty) return;
    canvas
      ..save()
      ..scale(1 / kx, 1 / ky);
    final clip = Rect.fromLTRB(
      math.min(water.left * kx, water.right * kx),
      water.top * ky,
      math.max(water.left * kx, water.right * kx),
      water.bottom * ky,
    );
    canvas.clipPath(Path()..addOval(clip));
    // Given back about the far edge of the water, foreshortened as water
    // seen from a little above gives it — and drawn in from the end of the
    // pool it stands at, so one looking in from the rim sees itself.
    final surface = water.top * ky + 3;
    final half = clip.width / 2;
    for (final (at, creature) in near) {
      final sprite = creature.sprite;
      if (sprite == null) continue;
      final w = creature.size.x;
      final dx = at.dx.clamp(-half + w * 0.35, half - w * 0.35);
      canvas
        ..save()
        ..translate(0, surface)
        ..scale(1, -0.62)
        ..translate(
          dx - w / 2,
          -surface + at.dy - creature.size.y / 2,
        );
      sprite.renderImage(canvas, 0.5);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool containsLocalPoint(Vector2 point) =>
      art.box.contains(Offset(point.x, point.y));

  @override
  void onTapUp(TapUpEvent event) {
    stir();
    onTap?.call();
  }

  @override
  void onRemove() {
    _front?.removeFromParent();
    art.dispose();
    super.onRemove();
  }
}

/// What a keepsake draws over its visitors (the water round a bather, the
/// near half of a ride), in front of every creature on its layer.
class _KeepsakeFront extends PositionComponent {
  _KeepsakeFront(this.thing, this.point) : super(priority: 15);

  final KeepsakeComponent thing;

  /// The thing's point, which it follows.
  final PositionComponent point;

  @override
  void update(double dt) {
    position.setFrom(point.position);
    scale.setFrom(thing.scale);
  }

  @override
  void render(Canvas canvas) {
    if (thing.ghost) canvas.saveLayer(null, KeepsakeComponent._ghostPaint);
    thing.art.front(canvas, thing._time);
    if (thing.ghost) canvas.restore();
  }
}

/// A species' effigy: its plinth, and the creature standing on it in its
/// own grains — read once from its sprite, then held still, shimmering.
class EffigyComponent extends KeepsakeComponent {
  EffigyComponent({
    required super.kind,
    required this.creature,
    required super.rowSize,
    super.flip,
    super.onTap,
  }) : super(art: EffigyPlinth());

  final Creature creature;
  SpecimenGrains? _grains;
  List<PointBatch> _batches = const [];

  /// How big the creature stands on its plinth, in the keepsake's units.
  static const double _size = 100;

  bool _reading = false;

  @override
  void onMount() {
    super.onMount();
    if (_reading || creature.spriteData == null) return;
    _reading = true;
    _read();
  }

  /// Reads the species' sprite into grains: drawn once off to the side,
  /// read, and taken away.
  Future<void> _read() async {
    final reader = CreatureSpriteComponent<SceneGame>(
      sheet: sheetFromCreature(creature),
      visuals: visualsFromInstance(creature, null),
      desiredSize: Vector2.all(_size),
    )..position = Vector2(-10000, -10000);
    await add(reader);
    // Mounted with its frames before it can be read.
    for (var i = 0; i < 60 && !reader.isMounted; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    SpecimenGrains? grains;
    for (var i = 0; i < 30 && grains == null && isMounted; i++) {
      grains = await reader.readGrains(
        pixelRatio: 1.6,
        maxGrains: 1600,
        tones: 12,
      );
      if (grains == null) {
        await Future<void>.delayed(const Duration(milliseconds: 32));
      }
    }
    reader.removeFromParent();
    if (grains == null) return;
    _grains = grains;
    _batches = [
      for (var i = 0; i < grains.tones.length; i++) PointBatch(grains.length),
    ];
  }

  /// Whether its grains have been read, for previews.
  bool get ready => _grains != null;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final g = _grains;
    if (g == null) return;
    final feet = creatureFeetDrop(creature.id) * _size;
    paintEffigyGrains(
      canvas,
      hx: g.hx,
      hy: g.hy,
      tone: g.tone,
      tones: g.tones,
      scale: 1,
      middle: Offset(0, EffigyPlinth.top - feet),
      t: _time.t,
      size: g.step * 1.05,
      batches: _batches,
    );
  }
}
