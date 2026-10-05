import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';

// A wilderness field drawn in code instead of from parallax pictures.
//
// The scene keeps its layers, parallax factors and spawn anchors exactly as
// an image scene has them; only what each layer shows comes from here. Each
// layer is two kinds of thing: still sheets (hills, trees, ground), baked
// into images once per screen height so they cost one draw a frame, and live
// parts (grass, motes), drawn every frame in the layer's own units. The sky
// sits behind every layer, fixed to the screen like anything at infinity.
//
// The light changes with the hour, so a still sheet is not baked in colour.
// A body sheet is baked as maps — how hazed, how lit, how shaded each pixel
// is — and a colour matrix for the hour turns those into colour as it is
// drawn. A light sheet is baked white, and coloured column by column with
// the light falling at that x, so a rim can blaze under a low sun and go
// dark away from it. Relighting the whole field is a uniform per draw.

/// How far an encounter's partner stands from the wild creature in a field
/// that loops, in the layer's own units, on the side its spawn point's
/// [SpawnPoint.partnerSide] names. A field that builds ground for partners
/// builds it here.
const double kFieldPairGap = 260;

/// A finger on the field: where it is (screen px), how far it moved since
/// the last sample (screen px), and when (field seconds).
class FieldTouch {
  const FieldTouch(this.x, this.y, this.dx, this.dy, this.time);
  final double x, y, dx, dy, time;
}

/// What a layer can see this frame, in the layer's own units.
class FieldView {
  const FieldView({
    required this.time,
    required this.hour,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.zoom,
    required this.height,
    this.touches = const [],
  });

  /// Seconds since the field was built. Drives every living thing in it.
  final double time;

  /// The hour of the day, 0–24, that lights the field.
  final double hour;

  /// The visible window, in layer-local units.
  final double left, right, top, bottom;

  /// Screen pixels per layer unit.
  final double zoom;

  /// The layer's height (the screen height at zoom 1).
  final double height;

  /// Recent fingers on the field, newest last, in screen px.
  final List<FieldTouch> touches;

  /// Where a layer-local [y] lands on the screen.
  double screenY(double y) => (y - top) * zoom;

  /// A screen point in this layer's units.
  Offset local(double sx, double sy) =>
      Offset(left + sx / zoom, top + sy / zoom);
}

/// A still part of a layer, baked into an image when the layer is built.
class FieldSheet {
  const FieldSheet({
    required this.bounds,
    required this.paint,
    this.drift = 0,
    this.resolution = 1,
    this.grade = 0,
    this.light = false,
    this.opacity,
  }) : live = null;

  /// A sheet that is not baked but drawn every frame by [live], in its
  /// place among the baked ones — for something that moves but must lie
  /// under what is baked over it (the Volcano's lava flow, under its
  /// rocks). [live] draws every repeat of itself it needs; it is called
  /// once a frame with the layer's view.
  const FieldSheet.live({required this.bounds, required this.live})
    : paint = _paintNothing,
      drift = 0,
      resolution = 1,
      grade = 0,
      light = false,
      opacity = null;

  static void _paintNothing(Canvas canvas) {}

  /// Draws a live sheet (see [FieldSheet.live]); null for a baked one.
  final void Function(Canvas canvas, FieldView view)? live;

  /// The area that holds content, in layer-local units. Only this is baked.
  final Rect bounds;

  /// Paints the sheet in layer-local units.
  final void Function(Canvas canvas) paint;

  /// Horizontal drift in units per second. A drifting sheet wraps every
  /// [bounds] width, so it must be painted seamless across its edges.
  final double drift;

  /// Bake resolution against the screen's pixel ratio. Soft far things can
  /// be baked coarser than crisp near ones.
  final double resolution;

  /// Which of the field's colour grades turns this body sheet's maps into
  /// colour (see [FieldArt.grade]).
  final int grade;

  /// A light sheet: baked white, coloured per column by [FieldArt.lightAt].
  final bool light;

  /// How much of it shows this frame (1 when null); at 0 it is not drawn at
  /// all. For a field with two states, each baked once — the Swamp wet and
  /// gone dry.
  final double Function()? opacity;
}

/// A field's art. One instance per game: it keeps what it prepares for the
/// current screen height.
abstract class FieldArt {
  /// The scene's spawn points, before anything is built, so the field can
  /// give every creature standing on something something to stand on.
  /// Spawn x is `normalizedPos.dx * worldWidth`, in its layer's units.
  /// With [loop], each layer's sheets are built one loop wide and must join
  /// seamlessly end to end, and a spawn's x is `normalizedPos.dx` of its
  /// layer's loop instead. Without [partners], nothing is built for an
  /// encounter partner beside each point (the home biome, where there are
  /// no encounters — only the player's own creatures, standing for show).
  ///
  /// With [placed], the field's own movable scenery (its great trees, its
  /// isles, its standing stones — see [FieldPiece]) stands only where the
  /// points with a [SpawnPoint.piece] put it, instead of where the field
  /// would: the home biome, which the player lays out.
  void layout(
    List<SpawnPoint> spawns,
    double worldWidth, {
    bool loop = false,
    bool partners = true,
    bool placed = false,
  }) {}

  /// Where the feet of a creature at [spawnId] go, when the field built it
  /// a perch (a rock, a branch) — layer-local y — or null to leave the
  /// creature where its spawn point puts it.
  double? perchFor(String spawnId) => null;

  /// The ground on [layer] at local [x], for a creature that cannot float:
  /// feet higher than [top] are in the air; [rest] is where to stand one.
  ({double top, double rest})? groundAt(SceneLayer layer, double x) => null;

  /// How much of a creature standing on [layer] its ground gives back, as
  /// an image upside down under its feet — 0 for none, as on most ground.
  double reflectionAt(SceneLayer layer) => 0;

  /// Paints what the ground on [layer] does under a creature standing on
  /// it, with the canvas at its feet, [halfWidth] the half of its body's
  /// width, at the field's clock [time] — the Arcane's glass holding a
  /// little light under whatever stands on it. Most ground does nothing.
  void paintUnderfoot(
    Canvas canvas,
    SceneLayer layer,
    double halfWidth,
    double time,
  ) {}

  /// The still sheets of [layer] at [size] (layer-local units), for a
  /// [screen] of that height. Called on every rebuild, so a field prepares
  /// its live parts for that size here.
  List<FieldSheet> build(SceneLayer layer, Size size, Size screen);

  /// The weather over the field, if any, and how deep in it the field is,
  /// from 0 (clear) to 1. The game eases it in and out; a field draws only
  /// the weathers it has.
  WeatherKind? weatherKind;
  double weather = 0;

  /// How much of what the weather leaves behind is showing (the Valley's
  /// rainbow), 0 to 1, eased in by the game.
  double aftermath = 0;

  /// Which stage of its own cycle the field is in this visit (see
  /// [SceneDefinition.stages]) — the Volcano still, smoking or erupting.
  /// Set before the first frame and held for the visit.
  int stage = 0;

  /// Called once a frame before anything is drawn, with the hour and the
  /// field's clock (seconds).
  void prepare(double hour, {double time = 0}) {}

  /// The colour matrix for body sheets of [grade] this frame, or null to
  /// draw them as baked.
  ColorFilter? grade(int grade);

  /// The light falling on [layer] at local [x] this frame: its colour, with
  /// strength in the alpha.
  Color lightAt(SceneLayer layer, double x, FieldView view);

  /// Whether [layer] draws anything live in that pass, so the game can skip
  /// mounting an empty component.
  bool hasLive(SceneLayer layer, {required bool front});

  /// The live parts of [layer]. The front pass draws over the creatures
  /// standing on the layer; the back pass under them.
  void paintLive(
    SceneLayer layer,
    Canvas canvas,
    FieldView view, {
    required bool front,
  });

  /// The sky, in screen pixels. [view] is the world camera's window, so a
  /// horizon can stay level with the layers when the camera zooms.
  void paintSky(Canvas canvas, Size screen, FieldView view);
}

/// The pieces of a field's own scenery that can be placed by hand (see
/// [SpawnPoint.piece]). What a piece's point means is the piece's own:
///
///   tree     Valley great tree — size.x is its scale ×100
///   boulder  Valley boulder in the grass — size is its width and height
///   isle, grove, falls
///            Sky isle bare, with a tree, with water running off it — the
///            point is where feet would stand on it, size.x its half width
///   cypress  Swamp great cypress — size.x is its scale ×100
///   stone, peat
///            Swamp bank of stone or peat — the point is its top, size.x its
///            half width
///   snag     Volcano dead tree on its basalt rock — the point is the rock's
///            top, size.x its half width, size.y the tree's height ×100
///   spire    Volcano spire of rock — size is its half width and height
///   monolith Arcane standing stone — the point is its foot, size its width
///            and height
///   pillar, arch
///            Dunes ruin half buried in the sand, seated on the ground under
///            it — size is its width and height
///   outcrop  Dunes rock of wind-cut sandstone — size is its width and height
///   cluster  Geode Hollow cluster of crystals, seated on the ground under
///            it — size.y is its tallest crystal's height
///   column   Geode Hollow column of ice — size is its width and height
///   geode    Geode Hollow split geode, a stone to stand on — size is its
///            width and height
///   tarn     Geode Hollow black pool on the floor — size.x is its half
///            width
///
/// Sizes are at the reference height (475 units), as the fields' own are.
abstract final class FieldPiece {
  static const tree = 'tree', boulder = 'boulder';
  static const isle = 'isle', grove = 'grove', falls = 'falls';
  static const cypress = 'cypress', stone = 'stone', peat = 'peat';
  static const snag = 'snag', spire = 'spire';
  static const monolith = 'monolith';
  static const pillar = 'pillar', arch = 'arch', outcrop = 'outcrop';
  static const cluster = 'cluster', column = 'column', geode = 'geode';
  static const tarn = 'tarn';
}

/// A seed for the piece at [id] that stays its own whatever else moves —
/// a placed tree keeps its shape when another is added before it.
int fieldSeedOf(String id) {
  var h = 0x811C9DC5;
  for (final c in id.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7FFFFFFF;
  }
  return h % 100000;
}

// ── Shared tools ───────────────────────────────────────────────────────────

/// Deterministic hash of an integer lattice point to [0, 1).
double fieldHash(int i, int seed) {
  var h = (i * 374761393 + seed * 668265263) & 0x7FFFFFFF;
  h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF;
  h ^= h >> 16;
  return (h & 0xFFFFFF) / 0x1000000;
}

/// Smooth value noise in [-1, 1].
double fieldNoise(double x, int seed) {
  final i = x.floor();
  final f = x - i;
  final s = f * f * (3 - 2 * f);
  final a = fieldHash(i, seed), b = fieldHash(i + 1, seed);
  return (a + (b - a) * s) * 2 - 1;
}

/// Smooth value noise in [-1, 1] that repeats exactly every [period]
/// (rounded to a whole number of [wave]s), so a looping layer joins
/// without a seam. A [period] of 0 is ordinary noise.
double fieldLoopNoise(double x, double wave, int seed, double period) {
  if (period <= 0) return fieldNoise(x / wave, seed);
  final n = math.max(1, (period / wave).round());
  final u = x / period * n;
  final i = u.floor();
  final f = u - i;
  final s = f * f * (3 - 2 * f);
  final a = fieldHash(i % n, seed), b = fieldHash((i + 1) % n, seed);
  return (a + (b - a) * s) * 2 - 1;
}

/// A seeded generator for laying a field out the same way every time.
class FieldRandom {
  FieldRandom(int seed) : _r = math.Random(seed);
  final math.Random _r;
  double next() => _r.nextDouble();
  double range(double a, double b) => a + (b - a) * _r.nextDouble();
}

/// A colour of maps for baking a body sheet: [r], [g], [b] in 0–1 are
/// whatever the sheet's grade reads them as.
Color fieldMap(double r, double g, double b, [double a = 1]) => Color.from(
  alpha: a.clamp(0.0, 1.0),
  red: r.clamp(0.0, 1.0),
  green: g.clamp(0.0, 1.0),
  blue: b.clamp(0.0, 1.0),
);

/// The colour matrix that reads a body sheet's maps as
/// `base + r·rCol + g·gCol + b·bCol` (each a colour offset, may be negative),
/// keeping the sheet's own alpha.
ColorFilter fieldGrade({
  required Color base,
  required (double, double, double) r,
  required (double, double, double) g,
  required (double, double, double) b,
}) => ColorFilter.matrix(<double>[
  r.$1, g.$1, b.$1, 0, base.r * 255, //
  r.$2, g.$2, b.$2, 0, base.g * 255,
  r.$3, g.$3, b.$3, 0, base.b * 255,
  0, 0, 0, 1, 0,
]);

/// [a] − [b] as a colour offset.
(double, double, double) fieldDiff(Color a, Color b) =>
    (a.r - b.r, a.g - b.g, a.b - b.b);

/// [c] scaled by [k] as a colour offset.
(double, double, double) fieldScale(Color c, double k) =>
    (c.r * k, c.g * k, c.b * k);
