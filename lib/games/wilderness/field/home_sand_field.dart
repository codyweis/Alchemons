// lib/games/wilderness/field/home_sand_field.dart
//
// LIVING SANDS. A home realm that is nothing but sand: a floor of particles
// on the dark in the one to five colors the player picks, lying as they
// choose (see SandFloor). A finger drawn through it stirs it and it springs
// back — or, as the player would rather, ploughs it and it stays, or swirls
// the colors through each other — until it is smoothed.
//
// The floor is one tile about a screen wide, seamless end to end, laid
// round the home's loop on the back layer — so it pans with the residents
// standing on it. Both rows move at the same speed: a flat floor has no
// parallax.
//
// Cheap at rest: the grains are one cached picture, drawn once per tile on
// screen (two, zoomed in), plus the glints. No blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:alchemons/games/wilderness/field/field_art.dart';
import 'package:alchemons/games/wilderness/field/sand_floor.dart';
import 'package:alchemons/models/home_sand.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';

/// The back layer, which the floor is laid on (under both rows).
const SceneLayer _floorLayer = SceneLayer.layer3;

class HomeSandField extends FieldArt {
  HomeSandField([HomeSandStyle style = const HomeSandStyle()])
    : _floor = SandFloor(style);

  final SandFloor _floor;
  Picture? _lastFrame;

  /// The tile's size (layer units) and how far the loop runs.
  Size _tile = Size.zero;
  double _period = 0;

  double _time = 0;
  double _lastTouch = -1;

  /// How it looks and how it moves.
  HomeSandStyle get style => _floor.style;

  /// Takes effect from the next frame, doing again only what changed: new
  /// colors dress every grain where it lies, cheap enough to follow a
  /// finger along a color strip.
  set style(HomeSandStyle style) => _floor.style = style;

  /// The floor itself, for previews and tests.
  SandFloor get floor => _floor;

  /// All of it back where it first lay, gliding there.
  void smooth() => _floor.smooth();

  @override
  List<FieldSheet> build(SceneLayer layer, Size size, Size screen) {
    if (layer != _floorLayer) return const [];
    // As many whole tiles round the loop as fit, each at least a screen
    // wide, so no more than two are ever on screen at full size.
    final k = math.max(1, (size.width / math.max(1, screen.width)).floor());
    final tile = Size(size.width / k, size.height);
    _period = size.width;
    if (tile != _tile) {
      _tile = tile;
      _floor.layout(tile);
    }
    return [FieldSheet.live(bounds: Offset.zero & size, live: _paintFloor)];
  }

  void _paintFloor(Canvas canvas, FieldView view) {
    final tw = _tile.width;
    if (_period <= 0 || tw <= 0) return;
    final dt = (view.time - _time).clamp(0.0, 0.05);

    // Fingers since the last frame, in the tile's own units. Each move gets
    // its share of the frame's time: a screen sampling fingers twice a
    // frame moves them half as far each time, at the same speed.
    var fresh = 0;
    for (final touch in view.touches) {
      if (touch.time > _lastTouch) fresh++;
    }
    final share = math.max(dt, 1 / 120) / math.max(1, fresh);
    for (final touch in view.touches) {
      if (touch.time <= _lastTouch) continue;
      final at = view.local(touch.x, touch.y);
      final x = at.dx - (at.dx / tw).floorToDouble() * tw;
      final moved = Offset(touch.dx, touch.dy) / view.zoom;
      if (moved.distanceSquared < 0.01) {
        _floor.ripple(Offset(x, at.dy));
      } else {
        _floor.stir(Offset(x, at.dy), moved, share);
      }
    }
    if (view.touches.isNotEmpty) _lastTouch = view.touches.last.time;
    _floor.step(dt);
    _time = view.time;

    // One frame of it, drawn on each tile on screen.
    final rec = PictureRecorder();
    _floor.paint(Canvas(rec));
    final frame = rec.endRecording();
    _lastFrame?.dispose();
    _lastFrame = frame;
    final k0 = (view.left / tw).floor(), k1 = (view.right / tw).floor();
    for (var k = k0; k <= k1; k++) {
      canvas
        ..save()
        ..translate(k * tw, 0)
        ..drawPicture(frame)
        ..restore();
    }

    // The light falls on the middle of the screen; its edges lie in the
    // dark. Under the residents, which stand out of it.
    final screen = Size(
      (view.right - view.left) * view.zoom,
      (view.bottom - view.top) * view.zoom,
    );
    canvas
      ..save()
      ..translate(view.left, view.top)
      ..scale(1 / view.zoom)
      ..drawRect(Offset.zero & screen, _vignette(screen))
      ..restore();
  }

  final Paint _shade = Paint();
  Size _shadeFor = Size.zero;

  Paint _vignette(Size screen) {
    if (screen == _shadeFor) return _shade;
    _shadeFor = screen;
    final c = screen.center(Offset.zero);
    final sx = screen.width / math.max(1, screen.height);
    _shade.shader = Gradient.radial(
      c,
      screen.height * 0.68,
      const [Color(0x00000000), Color(0x00000000), Color(0x99000000)],
      const [0, 0.5, 1],
      TileMode.clamp,
      Float64List.fromList([
        sx, 0, 0, 0, //
        0, 1, 0, 0, //
        0, 0, 1, 0, //
        c.dx * (1 - sx), 0, 0, 1,
      ]),
    );
    return _shade;
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
  void paintSky(Canvas canvas, Size screen, FieldView view) {
    canvas.drawRect(
      Offset.zero & screen,
      Paint()..color = const Color(0xFF0B090F),
    );
  }

  @override
  void dispose() {
    _floor.dispose();
    _lastFrame?.dispose();
    _lastFrame = null;
  }
}

/// Living Sands in [style]. Both rows on the one floor, at the same speed.
SceneDefinition homeSandScene([
  HomeSandStyle style = const HomeSandStyle(),
]) => SceneDefinition(
  worldWidth: 1400,
  worldHeight: 1000,
  loop: true,
  art: () => HomeSandField(style),
  layers: const [
    LayerDefinition(id: SceneLayer.layer3, imagePath: '', parallaxFactor: 1),
    LayerDefinition(id: SceneLayer.layer4, imagePath: '', parallaxFactor: 1),
  ],
);
