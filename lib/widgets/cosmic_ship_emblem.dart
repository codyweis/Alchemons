// lib/widgets/cosmic_ship_emblem.dart
//
// The way into space from home: the player's own ship — the hull they have
// equipped — read into lit grains and flying a slow figure of eight, leaving
// a wake of grains that curves through each turn. No frame round it; a few
// stars drift behind it and fade out toward its edge.
//
// Touched, it is its own way in (navigation/emblem_passage.dart): the ship
// leaves the icon, swoops down and turns up into the middle of the screen,
// growing as the dark of space comes up round it, and cruises there with
// the stars streaming past while the cosmos is got ready. Then the camera
// pulls back — the ship shrinks onto the real one, in the same place, as
// space comes up round it — and gives way to it. Going back, it lifts off
// the real ship and flies home into the icon.
//
// The hull is read once per skin, from the hull's own painter
// (games/cosmic/ship_art.dart), so it is always the ship the player flies.
// Points in batches, gradients for light; no blur, no stroked outlines.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/ship_art.dart';
import 'package:alchemons/navigation/emblem_passage.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:alchemons/widgets/home_emblems.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

double _smooth(double e0, double e1, double x) {
  final t = _clamp01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
}

double _ease(double x) {
  final t = _clamp01(x);
  return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// [a] to [b] the short way round.
double _lerpAngle(double a, double b, double t) {
  var d = (b - a) % (math.pi * 2);
  if (d > math.pi) d -= math.pi * 2;
  if (d < -math.pi) d += math.pi * 2;
  return a + d * t;
}

double _h(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

/// The dark the cosmos stands on (the cosmic screen's own ground).
const Color _kSpace = Color(0xFF020010);

// ── the hull, in grains ─────────────────────────────────────────────────────

/// A hull read into grains, colored by its own light.
@immutable
class ShipGrains {
  const ShipGrains._(
    this.hx,
    this.hy,
    this.tone,
    this.colors,
    this.step,
    this.tail,
  );

  /// Each grain's place, in hull units (nose up, about 45 tall), and its
  /// color as an index into [colors].
  final Float32List hx, hy;
  final Uint8List tone;
  final List<Color> colors;

  /// Spacing between grains, in hull units.
  final double step;

  /// How far back the engines sit (hull units, +y).
  final double tail;

  int get length => hx.length;

  static final Map<String?, Future<ShipGrains>> _reads = {};
  static final Map<String?, ShipGrains> _done = {};

  /// The hull [skin] read into grains, once.
  static Future<ShipGrains> of(String? skin) =>
      _reads[skin] ??= _read(skin).then((g) => _done[skin] = g);

  /// [of], if it has finished.
  static ShipGrains? now(String? skin) => _done[skin];

  /// Hull units per grain of the read: fine enough to stand over a good
  /// part of the screen in the passage; the icon draws a share of them.
  static const double _unit = 0.5;

  static Future<ShipGrains> _read(String? skin) async {
    const box = 92.0; // hull units, round the whole hull and its halo
    const ratio = 3.0;
    const px = box / _unit * ratio;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.scale(ratio / _unit);
    canvas.translate(box / 2, box / 2);
    paintShipHull(canvas, skin, 0.7, glow: false, engines: 0.35);
    final image = rec.endRecording().toImageSync(px.round(), px.round());
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      final read = SpecimenGrains.fromRgba(
        data!.buffer.asUint8List(),
        image.width,
        image.height,
        pixelRatio: ratio,
        maxGrains: 2600,
        tones: 14,
      );
      final n = read.length;
      final hx = Float32List(n), hy = Float32List(n);
      var tail = 0.0;
      for (var i = 0; i < n; i++) {
        hx[i] = read.hx[i] * _unit;
        hy[i] = read.hy[i] * _unit;
        if (hx[i].abs() < 9 && hy[i] > tail) tail = hy[i];
      }
      return ShipGrains._(
        hx,
        hy,
        read.tone,
        _inked(read.tones, shipLight(skin)),
        read.step * _unit,
        tail == 0 ? 18 : tail,
      );
    } finally {
      image.dispose();
    }
  }

  /// The hull's own colors turned to its light: the obsidian, which is
  /// near black and would vanish on the dark, becomes a dim grain of its
  /// rim light; what was lit stays lit, up to white-hot.
  static List<Color> _inked(List<Color> tones, ShipLight l) {
    if (tones.isEmpty) return const [];
    final lum = [for (final c in tones) c.computeLuminance()];
    final lo = lum.reduce(math.min), hi = lum.reduce(math.max);
    final span = math.max(1e-4, hi - lo);
    final dim = Color.lerp(l.face, l.rim, 0.42)!;
    return [
      for (final v in lum)
        () {
          final k = math.pow((v - lo) / span, 0.55).toDouble();
          if (k < 0.45) {
            return Color.lerp(
              dim,
              l.rim,
              k / 0.45,
            )!.withValues(alpha: 0.72 + 0.28 * k / 0.45);
          }
          if (k < 0.8) return Color.lerp(l.rim, l.essence, (k - 0.45) / 0.35)!;
          return Color.lerp(l.grainHot, l.hot, (k - 0.8) / 0.2)!;
        }(),
    ];
  }
}

/// Where the ship is drawn and how: its centre, px per hull unit, heading
/// (radians, 0 nose up, clockwise) and lean into a turn (−1..1).
@immutable
class ShipPose {
  const ShipPose(this.at, this.scale, this.heading, [this.bank = 0]);

  final Offset at;
  final double scale;
  final double heading;
  final double bank;

  Offset get forward => Offset(math.sin(heading), -math.cos(heading));

  /// Hull point [x], [y] (units) on the screen.
  Offset place(double x, double y) {
    final lean = 1 - 0.3 * bank.abs();
    final px = x * scale * lean, py = y * scale;
    final c = math.cos(heading), s = math.sin(heading);
    return at + Offset(px * c - py * s, px * s + py * c);
  }

  static ShipPose lerp(ShipPose a, ShipPose b, double t) => ShipPose(
    Offset.lerp(a.at, b.at, t)!,
    _lerp(a.scale, b.scale, t),
    _lerpAngle(a.heading, b.heading, t),
    _lerp(a.bank, b.bank, t),
  );
}

final GrainBatch _hullBatch = GrainBatch(18);
final Paint _paint = Paint();

/// Paints [grains] at [pose]: the light it pools, the hull in grains, and
/// its engines. [alpha] fades all of it; [density] (0..1) is the share of
/// grains drawn, so a small ship is not a solid smear and a large one is
/// whole.
void paintShipGrains(
  Canvas canvas,
  ShipGrains grains,
  ShipLight light,
  ShipPose pose,
  double time, {
  double alpha = 1,
  double? density,
  double engines = 1,
}) {
  if (alpha <= 0.004 || grains.length == 0) return;
  final k = pose.scale;
  // About one grain per 0.75 px of hull, at most all of them.
  final share =
      density ?? _clamp01(math.pow(grains.step * k / 0.75, 2).toDouble());
  final dot = math.max(0.85, grains.step * k * math.sqrt(1 / share) * 0.95);

  // The light it pools round itself.
  final pr = 30 * k;
  canvas.save();
  canvas.translate(pose.at.dx, pose.at.dy);
  canvas.scale(pr);
  _paint
    ..shader = light.pool
    ..color = Color.fromRGBO(0, 0, 0, alpha * 0.9);
  canvas.drawCircle(Offset.zero, 1, _paint);
  canvas.restore();

  final b = _hullBatch..clear();
  final n = grains.length;
  final tones = grains.colors.length;
  for (var i = 0; i < n; i++) {
    if (share < 1 && _h(i, 7) > share) continue;
    final p = pose.place(grains.hx[i], grains.hy[i]);
    b.add(grains.tone[i] % tones, p.dx, p.dy);
  }
  for (var t = 0; t < tones && t < 16; t++) {
    final c = grains.colors[t];
    b.draw(canvas, t, dot, c.withValues(alpha: _clamp01(c.a * alpha)));
  }

  // The engines: a light at the tail that flickers.
  if (engines > 0.01) {
    final flick = 0.82 + 0.18 * math.sin(time * 23) * math.sin(time * 7.3);
    final at = pose.place(0, grains.tail * 0.96);
    final r = 3.6 * k * flick * (0.6 + 0.4 * engines);
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(r);
    _paint
      ..shader = light.spark
      ..color = Color.fromRGBO(0, 0, 0, alpha * engines);
    canvas.drawCircle(Offset.zero, 1, _paint);
    canvas.restore();
  }
  _paint
    ..shader = null
    ..color = const Color(0xFF000000);
}

// ── the icon ────────────────────────────────────────────────────────────────

/// The ship's flight in the icon at [t], in a box [s] across centred on
/// [c]: a slow figure of eight, nose along its way, leaning into each turn,
/// a little nearer on the right-hand loop.
ShipPose shipFlight(Offset c, double s, double t) {
  const period = 9.0;
  const w = math.pi * 2 / period;
  final phi = t * w;
  final ax = s * 0.17, ay = s * 0.22;
  final x = ax * math.sin(phi);
  final y = ay * math.sin(phi) * math.cos(phi);
  final vx = ax * math.cos(phi);
  final vy = ay * math.cos(2 * phi);
  final axx = -ax * math.sin(phi);
  final ayy = -2 * ay * math.sin(2 * phi);
  final speed = math.sqrt(vx * vx + vy * vy);
  final turn = (vx * ayy - vy * axx) / math.max(1e-3, speed * speed * speed);
  final hull = s * 0.38 / 45;
  return ShipPose(
    c + Offset(x, y),
    hull * (1 + 0.08 * math.sin(phi)),
    math.atan2(vx, -vy),
    (turn * s * 0.12).clamp(-1.0, 1.0),
  );
}

/// The wake the icon's ship leaves along [flight]: grains thrown back from
/// its engines at a steady rate, each placed where the ship was when it was
/// thrown — so the wake follows the ship's path through its turns with
/// nothing to remember between frames.
void _paintFlightWake(
  Canvas canvas,
  ShipPose Function(double t) flight,
  ShipGrains grains,
  ShipLight light,
  double t, {
  double alpha = 1,
}) {
  const rate = 90.0, life = 1.1;
  final b = _hullBatch..clear();
  final first = ((t - life) * rate).ceil();
  final last = (t * rate).floor();
  for (var k = first; k <= last; k++) {
    final te = k / rate;
    final age = t - te;
    if (age < 0 || age > life) continue;
    final pose = flight(te);
    final from = pose.place(0, grains.tail);
    final back = -pose.forward;
    final side = Offset(-back.dy, back.dx);
    final spread = (_h(k, 3) - 0.5) * 2;
    final drift = (1 - math.exp(-age * 2.6)) / 2.6;
    final p =
        from +
        back * (pose.scale * 34 * drift) +
        side * (pose.scale * spread * (2 + 9 * age));
    final f = age / life;
    b.add(f < 0.25 ? 0 : (f < 0.6 ? 1 : 2), p.dx, p.dy);
  }
  final d = math.max(0.8, flight(t).scale * 2.2);
  b.draw(canvas, 2, d * 0.8, light.grainDim.withValues(alpha: 0.4 * alpha));
  b.draw(canvas, 1, d, light.essence.withValues(alpha: 0.7 * alpha));
  b.draw(canvas, 0, d * 1.2, light.grainHot.withValues(alpha: 0.95 * alpha));
}

/// A few stars behind the icon's ship, drifting slowly and thinning out
/// toward its edge, since nothing frames it.
void _paintIconStars(Canvas canvas, Offset c, double s, double t) {
  final b = _hullBatch..clear();
  for (var i = 0; i < 22; i++) {
    final x = (_h(i, 41) - t * 0.012 * (0.5 + _h(i, 42))) % 1.0;
    final y = (_h(i, 43) + t * 0.02 * (0.5 + _h(i, 42))) % 1.0;
    final p = c + Offset((x - 0.5) * s, (y - 0.5) * s);
    final d = (p - c).distance / (s * 0.5);
    final fade = 1 - _smooth(0.45, 0.95, d);
    if (fade <= 0.05) continue;
    final tw = 0.5 + 0.5 * math.sin(t * (1.2 + _h(i, 44) * 2) + i);
    b.add(fade * tw > 0.55 ? 1 : 0, p.dx, p.dy);
  }
  b.draw(canvas, 0, 1.0, const Color(0x66B8C4E8));
  b.draw(canvas, 1, 1.3, const Color(0xCCE4ECFF));
}

/// The way into space on home: the equipped ship, in grains, flying.
class CosmicShipEmblem extends StatefulWidget {
  const CosmicShipEmblem({
    super.key,
    this.size = 75,
    this.animate = true,
    this.lifted,
  });

  final double size;
  final bool animate;

  /// True while the ship is away carrying the player into space: the icon
  /// leaves its place empty.
  final ValueListenable<bool>? lifted;

  /// The hull the player has equipped (null: the standard hull). Read from
  /// the cosmic save once; space sets it whenever the player changes hulls.
  static final ValueNotifier<String?> skin = ValueNotifier<String?>(null);

  static Future<void>? _loading;

  /// Reads the equipped hull from the cosmic save, once.
  static Future<void> loadSkin() => _loading ??= () async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kCosmicCustomizationPrefsKey);
      if (raw != null) {
        skin.value = HomeCustomizationState.deserialise(raw).activeShipSkin;
      }
    } catch (_) {
      // The standard hull, then.
    }
  }();

  @override
  State<CosmicShipEmblem> createState() => _CosmicShipEmblemState();
}

class _CosmicShipEmblemState extends State<CosmicShipEmblem>
    with GlyphClockLease {
  bool _visible = true;
  ShipGrains? _grains;

  @override
  bool get wantsClock => widget.animate && _visible;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
    CosmicShipEmblem.skin.addListener(_read);
    CosmicShipEmblem.loadSkin();
    _read();
  }

  void _read() {
    final skin = CosmicShipEmblem.skin.value;
    final ready = ShipGrains.now(skin);
    if (ready != null) {
      if (mounted) setState(() => _grains = ready);
      return;
    }
    ShipGrains.of(skin).then((g) {
      if (mounted && CosmicShipEmblem.skin.value == skin) {
        setState(() => _grains = g);
      }
    }, onError: (_) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      syncGlyphClock();
    }
  }

  @override
  void didUpdateWidget(covariant CosmicShipEmblem oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncGlyphClock();
  }

  @override
  void dispose() {
    CosmicShipEmblem.skin.removeListener(_read);
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paint = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        willChange: widget.animate,
        painter: CosmicShipEmblemPainter(
          grains: _grains,
          skin: CosmicShipEmblem.skin.value,
          clock: glyphClock,
        ),
      ),
    );
    final lifted = widget.lifted;
    if (lifted == null) return paint;
    return ValueListenableBuilder<bool>(
      valueListenable: lifted,
      builder: (_, away, child) => Opacity(opacity: away ? 0 : 1, child: child),
      child: paint,
    );
  }
}

class CosmicShipEmblemPainter extends CustomPainter {
  CosmicShipEmblemPainter({
    required this.grains,
    required this.skin,
    this.clock,
    this.time,
  }) : super(repaint: clock);

  final ShipGrains? grains;
  final String? skin;
  final ValueListenable<double>? clock;

  /// A fixed time, for a still frame (tests).
  final double? time;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final t = time ?? clock?.value ?? 0;
    paintCosmicShipIcon(canvas, Offset.zero & size, t, grains, skin);
  }

  @override
  bool shouldRepaint(covariant CosmicShipEmblemPainter old) =>
      old.grains != grains ||
      old.skin != skin ||
      old.clock != clock ||
      old.time != time;
}

/// The icon in [box] at [t]: stars, the wake, the ship. [alpha] fades it.
void paintCosmicShipIcon(
  Canvas canvas,
  Rect box,
  double t,
  ShipGrains? grains,
  String? skin, {
  double alpha = 1,
  bool stars = true,
}) {
  final c = box.center, s = box.shortestSide;
  if (stars && alpha > 0.5) _paintIconStars(canvas, c, s, t);
  if (grains == null) return;
  final light = shipLight(skin);
  ShipPose flight(double at) => shipFlight(c, s, at);
  _paintFlightWake(canvas, flight, grains, light, t, alpha: alpha);
  paintShipGrains(canvas, grains, light, flight(t), t, alpha: alpha);
}

// ── the passage ─────────────────────────────────────────────────────────────

/// Where the real ship stands once space is laid out: what the passage
/// lands on.
@immutable
class ShipPassageTarget {
  const ShipPassageTarget({
    required this.centre,
    required this.scale,
    required this.heading,
  });

  /// In global coordinates.
  final Offset centre;

  /// Screen px per hull unit (the camera's zoom).
  final double scale;

  /// Radians, 0 nose up, clockwise.
  final double heading;

  ShipPose get pose => ShipPose(centre, scale, heading);
}

class CosmicShipPassage extends PassageScene {
  CosmicShipPassage({required this.target});

  /// The hull being flown — read live, so a hull changed in space is the
  /// one that flies home.
  String? get skin => CosmicShipEmblem.skin.value;

  /// Set by space once it is laid out (and again as the player leaves).
  final ValueListenable<ShipPassageTarget?> target;

  @override
  Duration get inward => const Duration(milliseconds: 750);

  @override
  Duration get outward => const Duration(milliseconds: 1100);

  @override
  Duration get landing => const Duration(milliseconds: 800);

  /// Space starts building as the ship eases into the middle — nearly at
  /// rest there, so its first frame's cost does not show in the flight —
  /// and is often ready by the time it has.
  @override
  double get buildAt => 0.8;

  @override
  Listenable? get listenable => target;

  /// Space comes up round the ship as the camera pulls back from it.
  @override
  double pageShown(double land) => _smooth(0.1, 0.72, land);

  /// Going back, space clears quickly; the flight home has the rest.
  @override
  double get backSplit => 0.72;

  // The stars streaming past, and the wake: kept between frames.
  double? _last;
  double _travel = 0;
  final _Wake _wake = _Wake();

  static const int _starCount = 150;
  static final GrainBatch _b = GrainBatch(6);

  @override
  void paint(
    Canvas canvas,
    EmblemStage s, {
    required bool back,
    required bool front,
  }) {
    final grains = ShipGrains.now(skin);
    final light = shipLight(skin);
    final h = s.screen.height;
    final t = s.time;
    final closing = s.closing;
    final land = s.land;

    // How fast space streams past: up to speed as the ship comes out, still
    // again as the camera pulls back onto the real ship.
    final flow = closing
        ? 0.0
        : _smooth(0.2, 1, s.open) * (1 - _smooth(0.0, 0.6, land));

    if (back) {
      if (s.ground > 0) {
        canvas.drawRect(
          Offset.zero & s.screen,
          Paint()..color = _kSpace.withValues(alpha: s.ground),
        );
        _stars(canvas, s.screen, t, flow, s.ground * (1 - 0.6 * land));
      }
    }
    if (!front) return;

    final pose = _pose(s, grains);
    final dt = _step(t);
    _travel += dt * flow * h * 0.9;

    final alpha = closing
        ? 1 - _smooth(0.55, 1, land)
        : 1 - _smooth(0.62, 1, land);
    if (grains != null) {
      _wake.step(
        dt,
        pose.place(0, grains.tail),
        -pose.forward,
        pose.scale,
        emit: closing ? 1 - land : (1 - _smooth(0.3, 0.8, land)),
        flow: flow * h * 0.9,
      );
      _wake.paint(canvas, light, alpha);
      paintShipGrains(canvas, grains, light, pose, t, alpha: alpha);
    } else {
      // Not read yet (it always is by now): the hull as it flies.
      canvas.save();
      canvas.translate(pose.at.dx, pose.at.dy);
      canvas.rotate(pose.heading);
      canvas.scale(pose.scale);
      paintShipHull(canvas, skin, t);
      canvas.restore();
    }
  }

  /// Seconds since the last frame; a jump (the shared clock restarted)
  /// reads as one frame.
  double _step(double t) {
    final last = _last;
    _last = t;
    if (last == null || t < last || t - last > 0.25) return 1 / 60;
    return t - last;
  }

  /// Where the ship is at [s].
  @visibleForTesting
  ShipPose poseAt(EmblemStage s) => _pose(s, null);

  ShipPose _pose(EmblemStage s, ShipGrains? grains) {
    final w = s.screen.width, h = s.screen.height;
    final t = s.time;
    final icon = shipFlight(s.box.center, s.box.shortestSide, t);
    // Cruising in the middle of the screen while space is got ready: large,
    // nose up, swaying a little.
    final holdScale = math.min(w * 0.4, h * 0.26) / 45;
    final sway = math.sin(t * 0.9);
    final hold = ShipPose(
      Offset(w / 2 + sway * w * 0.015, h * 0.5),
      holdScale,
      math.sin(t * 0.9 + 0.7) * 0.05,
      math.cos(t * 0.9) * 0.15,
    );
    final tgt = target.value?.pose ?? ShipPose(Offset(w / 2, h / 2), 0.72, 0);

    if (!s.closing) {
      final g = s.grow;
      // Out of the icon, down past the middle and turning up into it, so it
      // arrives nose first.
      final p0 = icon.at, p3 = hold.at;
      final c1 = p0 + Offset(-w * 0.08, h * 0.22);
      final c2 = p3 + Offset(w * 0.05, h * 0.24);
      final at = _bezier(p0, c1, c2, p3, g);
      final along =
          _bezier(p0, c1, c2, p3, math.min(1.0, g + 0.02)) -
          _bezier(p0, c1, c2, p3, math.max(0.0, g - 0.02));
      final travel = math.atan2(along.dx, -along.dy);
      var heading = _lerpAngle(icon.heading, travel, _smooth(0, 0.22, g));
      heading = _lerpAngle(heading, hold.heading, _smooth(0.8, 1, g));
      var pose = ShipPose(
        at,
        _lerp(icon.scale, holdScale, _ease(g)),
        heading,
        _lerp(icon.bank, math.sin(math.pi * g) * -0.6, _smooth(0, 0.25, g)) +
            hold.bank * g,
      );
      if (g >= 1) pose = hold;
      if (s.land > 0) {
        // The camera pulls back onto the real ship.
        pose = ShipPose.lerp(pose, tgt, _ease(_clamp01(s.land / 0.85)));
      }
      return pose;
    }

    // Going back: lifted off the real ship, up and over into the icon.
    final g = s.grow;
    final p0 = tgt.at, p3 = icon.at;
    final c1 = p0 + Offset(0, -h * 0.2);
    final c2 = p3 + Offset(-w * 0.12, h * 0.1);
    final u = 1 - g;
    final at = _bezier(p0, c1, c2, p3, u);
    final along =
        _bezier(p0, c1, c2, p3, math.min(1.0, u + 0.02)) -
        _bezier(p0, c1, c2, p3, math.max(0.0, u - 0.02));
    final travel = math.atan2(along.dx, -along.dy);
    var heading = _lerpAngle(tgt.heading, travel, _smooth(0, 0.2, u));
    heading = _lerpAngle(heading, icon.heading, _smooth(0.75, 1, u));
    return ShipPose(
      at,
      _lerp(tgt.scale, icon.scale, _smooth(0, 1, u)),
      heading,
      _lerp(math.sin(math.pi * u) * 0.5, icon.bank, _smooth(0.75, 1, u)),
    );
  }

  static Offset _bezier(Offset a, Offset b, Offset c, Offset d, double t) {
    final u = 1 - t;
    return a * (u * u * u) +
        b * (3 * u * u * t) +
        c * (3 * u * t * t) +
        d * (t * t * t);
  }

  /// Space streaming past: three depths of grains moving down the screen
  /// as the ship flies up through them.
  void _stars(Canvas canvas, Size size, double t, double flow, double alpha) {
    if (alpha <= 0.01) return;
    final w = size.width, h = size.height + 40;
    final b = _b..clear();
    for (var i = 0; i < _starCount; i++) {
      final depth = i % 3;
      final speed = const [0.3, 0.6, 1.0][depth];
      final x = _h(i, 51) * w;
      final y = (_h(i, 52) * h + _travel * speed) % h - 20;
      b.add(depth, x, y);
      // Near ones at speed draw out into a short run of grains.
      if (depth == 2 && flow > 0.4) {
        b.add(3, x, y - 4 * flow);
        b.add(3, x, y - 8 * flow);
      }
    }
    b.draw(canvas, 0, 1.2, Color.fromRGBO(150, 160, 210, 0.55 * alpha));
    b.draw(canvas, 1, 1.6, Color.fromRGBO(190, 200, 240, 0.75 * alpha));
    b.draw(canvas, 3, 1.5, Color.fromRGBO(220, 228, 255, 0.4 * alpha));
    b.draw(canvas, 2, 2.1, Color.fromRGBO(235, 240, 255, 0.95 * alpha));
  }
}

/// The passage's wake: grains thrown back from the engines, carried down
/// the screen by the flow of space past the ship, thinning as they go.
class _Wake {
  static const int _cap = 420;
  final Float32List _x = Float32List(_cap), _y = Float32List(_cap);
  final Float32List _vx = Float32List(_cap), _vy = Float32List(_cap);
  final Float32List _age = Float32List(_cap), _life = Float32List(_cap);
  int _n = 0;
  double _carry = 0, _scale = 1;
  Offset? _lastFrom;
  int _seed = 0x1F2E3D4C;

  double _rand() {
    _seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF;
    return _seed / 0x7FFFFFFF;
  }

  void step(
    double dt,
    Offset from,
    Offset back,
    double scale, {
    required double emit,
    required double flow,
  }) {
    _scale = scale;
    var i = 0;
    while (i < _n) {
      _age[i] += dt;
      if (_age[i] >= _life[i]) {
        _n--;
        _x[i] = _x[_n];
        _y[i] = _y[_n];
        _vx[i] = _vx[_n];
        _vy[i] = _vy[_n];
        _age[i] = _age[_n];
        _life[i] = _life[_n];
        continue;
      }
      final drag = math.max(0.0, 1 - dt * 2.4);
      _vx[i] *= drag;
      _vy[i] *= drag;
      _x[i] += _vx[i] * dt;
      _y[i] += (_vy[i] + flow) * dt;
      i++;
    }
    // Thrown along the way the engines came this frame, not all from where
    // they are now, so a fast ship leaves a stream and not a row of dots.
    final was = _lastFrom ?? from;
    _lastFrom = from;
    final jump = (from - was).distance > scale * 120;
    _carry += dt * 300 * _clamp01(emit);
    final side = Offset(-back.dy, back.dx);
    final whole = _carry.floor();
    for (var k = 0; k < whole && _n < _cap; k++) {
      final f = (k + _rand()) / whole;
      final sp = scale * (50 + 45 * _rand());
      final jitter = (_rand() - 0.5) * scale * 30;
      final vx = back.dx * sp + side.dx * jitter;
      final vy = back.dy * sp + side.dy * jitter;
      final at =
          (jump ? from : Offset.lerp(was, from, f)!) +
          side * ((_rand() - 0.5) * scale * 6);
      final ahead = (1 - f) * dt;
      _x[_n] = at.dx + vx * ahead;
      _y[_n] = at.dy + (vy + flow) * ahead;
      _vx[_n] = vx;
      _vy[_n] = vy;
      _age[_n] = ahead;
      _life[_n] = 0.4 + 0.45 * _rand();
      _n++;
    }
    _carry -= whole;
  }

  static final GrainBatch _b = GrainBatch(3);

  void paint(Canvas canvas, ShipLight light, double alpha) {
    if (_n == 0 || alpha <= 0.01) return;
    final b = _b..clear();
    for (var i = 0; i < _n; i++) {
      final f = _age[i] / _life[i];
      b.add(f < 0.25 ? 0 : (f < 0.6 ? 1 : 2), _x[i], _y[i]);
    }
    final d = math.max(0.9, _scale * 1.0);
    b.draw(canvas, 2, d * 0.8, light.grainDim.withValues(alpha: 0.45 * alpha));
    b.draw(canvas, 1, d, light.essence.withValues(alpha: 0.75 * alpha));
    b.draw(canvas, 0, d * 1.25, light.grainHot.withValues(alpha: alpha));
  }
}
