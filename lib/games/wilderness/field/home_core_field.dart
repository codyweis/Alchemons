// lib/games/wilderness/field/home_core_field.dart
//
// THE CORE. The inside of the player's own planet, a home realm opened only
// by finding every Core Shard buried under the five first realms
// (models/home_secrets.dart). Nothing in it is drawn as a thing: it is
// particles on the dark, as Living Sands is.
//
//   · overhead, the inside of the planet's shell: strata of faint grains
//     arching across, far up, turning very slowly;
//   · in the middle distance, the heart: a knot of grains in the planet's
//     own color (its color in space; a pale gold for a planet never
//     colored), turning, breathing — and in the BEATING mood, beating,
//     each beat sending a ring of light out across the floor;
//   · underfoot, a floor of grains in layers of the heart's color (the
//     Living Sands floor, SandFloor), lit toward the heart, that a finger
//     stirs and that springs back.
//
// No sky, no hour: the planet's inside has neither.

import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/games/cosmic/obsidian_kit.dart' show hash01;
import 'package:alchemons/games/wilderness/field/field_art.dart';
import 'package:alchemons/games/wilderness/field/sand_floor.dart';
import 'package:alchemons/models/home_sand.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/widgets/fx/cosmetics/cosmetic_atlas.dart';

/// The back layer, which the floor is laid on (under both rows).
const SceneLayer _floorLayer = SceneLayer.layer3;

/// The heart of a planet never colored.
const Color _plainHeart = Color(0xFFE8C88A);

/// The Core's moods: the heart turning still, or beating.
const int kCoreStill = 0, kCoreBeating = 1;

/// The floor's sands, in layers of [heart]: the deep dark of it up to its
/// own color, glinting in it.
HomeSandStyle coreFloorStyle(Color heart) {
  Color dark(double k) => Color.lerp(const Color(0xFF07060A), heart, k)!;
  return HomeSandStyle(
    colors: [dark(0.16), dark(0.3), dark(0.46), dark(0.22), dark(0.62)],
    count: 4,
    shimmer: Color.lerp(heart, const Color(0xFFFFFFFF), 0.35)!,
    pattern: SandPattern.layered,
    density: 0.55,
    grain: 0.3,
    sparkle: 0.3,
  );
}

class HomeCoreField extends FieldArt {
  HomeCoreField() : _floor = SandFloor(coreFloorStyle(_plainHeart));

  final SandFloor _floor;
  Color _heart = _plainHeart;
  Picture? _lastFrame;

  Size _tile = Size.zero;
  double _period = 0;
  double _time = 0;
  double _lastTouch = -1;

  final CosmeticAtlas _over = CosmeticAtlas(900);
  final CosmeticAtlas _light = CosmeticAtlas(2600);

  /// The heart's color, from the planet's own (the home's sky carries it).
  Color get heart => _heart;

  void _followPlanet() {
    var tint = homeSky?.tint ?? _plainHeart;
    // A planet colored nearly black (the Void) still has a heart that
    // shows: its own violet limb.
    if (tint.computeLuminance() < 0.04) {
      tint = Color.lerp(tint, const Color(0xFF9A6AE0), 0.75)!;
    }
    if (tint == _heart) return;
    _heart = tint;
    _floor.style = coreFloorStyle(tint);
  }

  /// Where the floor begins, as a share of the height: the lower half; the
  /// dark and the heart above it.
  static const double _floorTop = 0.5;

  /// Where the heart is on the screen, and its radius.
  (Offset, double) _heartAt(Size screen) =>
      (Offset(screen.width * 0.5, screen.height * 0.27), screen.height * 0.17);

  /// How strongly the heart beats now (0 at rest, 1 at the beat's peak):
  /// slow and even when still, a double beat when beating.
  double _beat(double t) {
    if (stage != kCoreBeating) return 0.25 + 0.25 * math.sin(t * 0.6);
    final p = (t / 1.6) % 1;
    double pulse(double at) => math.exp(-math.pow((p - at) / 0.05, 2));
    return pulse(0.1) + 0.6 * pulse(0.3);
  }

  @override
  List<FieldSheet> build(SceneLayer layer, Size size, Size screen) {
    if (layer != _floorLayer) return const [];
    final k = math.max(1, (size.width / math.max(1, screen.width)).floor());
    final tile = Size(size.width / k, size.height * (1 - _floorTop));
    _period = size.width;
    _top = size.height * _floorTop;
    if (tile != _tile) {
      _tile = tile;
      _floor.layout(tile);
    }
    return [FieldSheet.live(bounds: Offset.zero & size, live: _paintFloor)];
  }

  /// Where the floor's top lies on the layer.
  double _top = 0;
  final Paint _edge = Paint();

  void _paintFloor(Canvas canvas, FieldView view) {
    _followPlanet();
    final tw = _tile.width;
    if (_period <= 0 || tw <= 0) return;
    final dt = (view.time - _time).clamp(0.0, 0.05);
    var fresh = 0;
    for (final touch in view.touches) {
      if (touch.time > _lastTouch) fresh++;
    }
    final share = math.max(dt, 1 / 120) / math.max(1, fresh);
    for (final touch in view.touches) {
      if (touch.time <= _lastTouch) continue;
      final at = view.local(touch.x, touch.y);
      final x = at.dx - (at.dx / tw).floorToDouble() * tw;
      final y = at.dy - _top;
      if (y < 0) continue;
      final moved = Offset(touch.dx, touch.dy) / view.zoom;
      if (moved.distanceSquared < 0.01) {
        _floor.ripple(Offset(x, y));
      } else {
        _floor.stir(Offset(x, y), moved, share);
      }
    }
    if (view.touches.isNotEmpty) _lastTouch = view.touches.last.time;
    // Each beat sends a ring out across the floor from under the heart.
    if (stage == kCoreBeating) {
      final p0 = (_time / 1.6) % 1, p1 = (view.time / 1.6) % 1;
      if (p1 < p0 || (p0 < 0.1 && p1 >= 0.1)) {
        final mid = (view.left + view.right) / 2;
        final x = mid - (mid / tw).floorToDouble() * tw;
        _floor.ripple(Offset(x, _tile.height * 0.3));
      }
    }
    _floor.step(dt);
    _time = view.time;

    final rec = PictureRecorder();
    _floor.paint(Canvas(rec));
    final frame = rec.endRecording();
    _lastFrame?.dispose();
    _lastFrame = frame;
    final k0 = (view.left / tw).floor(), k1 = (view.right / tw).floor();
    for (var k = k0; k <= k1; k++) {
      canvas
        ..save()
        ..translate(k * tw, _top)
        ..drawPicture(frame)
        ..restore();
    }
    // Its far edge goes into the dark, not to a line.
    final edge = _tile.height * 0.22;
    _edge.shader = Gradient.linear(
      Offset(0, _top - 1),
      Offset(0, _top + edge),
      const [Color(0xFF05040A), Color(0x0005040A)],
    );
    canvas.drawRect(
      Rect.fromLTRB(view.left, _top - 1, view.right, _top + edge),
      _edge,
    );
    // The heart's light lying on the floor toward it.
    final screen = Size(
      (view.right - view.left) * view.zoom,
      (view.bottom - view.top) * view.zoom,
    );
    final b = _beat(view.time);
    canvas
      ..save()
      ..translate(view.left, view.top)
      ..scale(1 / view.zoom);
    _light.add(
      AtlasCell.pool,
      screen.width * 0.5,
      screen.height * 0.62,
      screen.width * 1.3,
      atlasArgb(_heart, 0.12 + 0.08 * b),
    );
    _light.draw(canvas, blend: BlendMode.plus);
    canvas.restore();
  }

  @override
  void paintSky(Canvas canvas, Size screen, FieldView view) {
    _followPlanet();
    final t = view.time;
    canvas.drawRect(
      Offset.zero & screen,
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          Offset(0, screen.height),
          [
            const Color(0xFF040307),
            Color.lerp(const Color(0xFF07060B), _heart, 0.08)!,
            const Color(0xFF05040A),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
    final (at, r) = _heartAt(screen);
    final b = _beat(t);

    // The shell overhead: arcs of faint grains, far up, turning slowly.
    for (var band = 0; band < 5; band++) {
      final radius = screen.width * (0.9 + band * 0.22);
      final centre = Offset(
        screen.width * 0.5,
        screen.height * (1.3 + band * 0.18),
      );
      final n = 110 + band * 20;
      final turn = t * (0.002 + band * 0.0006) * (band.isEven ? 1 : -1);
      for (var i = 0; i < n; i++) {
        final a = math.pi * (1.15 + 0.7 * hash01(i, 300 + band)) + turn;
        final rr =
            radius + (hash01(i, 310 + band) - 0.5) * screen.height * 0.03;
        final p = centre + Offset(math.cos(a), math.sin(a)) * rr;
        if (p.dy < -4 || p.dy > screen.height * 0.6) continue;
        final tw = 0.6 + 0.4 * math.sin(t * (0.4 + hash01(i, 320)) + i);
        _light.add(
          AtlasCell.dot,
          p.dx,
          p.dy,
          2.6 + 1.6 * hash01(i, 330 + band),
          atlasArgb(
            Color.lerp(const Color(0xFF8E86A8), _heart, 0.3)!,
            (0.16 - band * 0.022) * tw,
          ),
        );
      }
    }

    // The heart: its glow, then a knot of grains turning in it.
    _light
      ..add(
        AtlasCell.dot,
        at.dx,
        at.dy,
        r * (5.2 + 1.2 * b),
        atlasArgb(_heart, 0.16 + 0.12 * b),
      )
      ..add(
        AtlasCell.dot,
        at.dx,
        at.dy,
        r * (2.2 + 0.6 * b),
        atlasArgb(_heart, 0.32 + 0.2 * b),
      );
    const grains = 900;
    final swell = 1 + 0.12 * b;
    for (var i = 0; i < grains; i++) {
      // Each grain on its own ring, tilted its own way, round the middle.
      final ring = 0.35 + 0.65 * math.sqrt(hash01(i, 340));
      final tilt = hash01(i, 341) * math.pi;
      final speed = (0.25 + 0.5 * hash01(i, 342)) * (i.isEven ? 1 : -1);
      final a = hash01(i, 343) * math.pi * 2 + t * speed * (1 + 0.6 * b);
      final x = math.cos(a) * ring, y = math.sin(a) * ring * 0.42;
      final ct = math.cos(tilt), st = math.sin(tilt);
      final px = at.dx + (x * ct - y * st) * r * swell;
      final py = at.dy + (x * st + y * ct) * r * swell;
      final near = 0.5 + 0.5 * math.sin(a);
      final hot = Color.lerp(
        _heart,
        const Color(0xFFFFFFFF),
        0.55 * (1 - ring),
      )!;
      _light.add(
        AtlasCell.bead,
        px,
        py,
        2 + 2 * near,
        atlasArgb(hot, (0.4 + 0.55 * near) * (0.8 + 0.2 * b)),
      );
    }
    // Its middle, white-hot.
    _light.add(
      AtlasCell.dot,
      at.dx,
      at.dy,
      r * (0.7 + 0.25 * b),
      atlasArgb(
        Color.lerp(_heart, const Color(0xFFFFFFFF), 0.7)!,
        0.5 + 0.3 * b,
      ),
    );
    // A few motes drifting up past it from the floor.
    for (var i = 0; i < 40; i++) {
      final life = (hash01(i, 350) + t / (14 + 6 * hash01(i, 351))) % 1;
      final x = screen.width * hash01(i, 352) + math.sin(t * 0.3 + i) * 12;
      final y = screen.height * (0.85 - 0.8 * life);
      _over.add(
        AtlasCell.bead,
        x,
        y,
        2.2,
        atlasArgb(_heart, 0.5 * math.sin(math.pi * life)),
      );
    }
    _over.draw(canvas);
    _light.draw(canvas, blend: BlendMode.plus);
  }

  @override
  ColorFilter? grade(int grade) => null;

  @override
  Color lightAt(SceneLayer layer, double x, FieldView view) =>
      const Color(0x00000000);

  @override
  bool hasLive(SceneLayer layer, {required bool front}) => false;

  @override
  void paintLive(
    SceneLayer layer,
    Canvas canvas,
    FieldView view, {
    required bool front,
  }) {}

  @override
  void dispose() {
    _floor.dispose();
    _lastFrame?.dispose();
    _lastFrame = null;
  }
}

/// The Core: both rows on the one floor, at the same speed.
SceneDefinition homeCoreScene() => SceneDefinition(
  worldWidth: 1400,
  worldHeight: 1000,
  loop: true,
  art: HomeCoreField.new,
  layers: const [
    LayerDefinition(id: SceneLayer.layer3, imagePath: '', parallaxFactor: 1),
    LayerDefinition(id: SceneLayer.layer4, imagePath: '', parallaxFactor: 1),
  ],
);
