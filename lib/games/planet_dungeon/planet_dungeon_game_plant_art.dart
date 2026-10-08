// lib/games/planet_dungeon/planet_dungeon_game_plant_art.dart
//
// VERDANTHOS, IN GLASS (docs/dungeons.md §7.11, §9.20) — the Conservatory's
// pictures, as a part of planet_dungeon_game.dart.
//
// Stone is the world and glass is the signal. The glasshouse's rooms are
// carved and baked once; leaded glass is kept for what the party works: the
// tending circles, the planters' collars, the lamps, the buds and the seed's
// channels. Every fix is a CLIMATE WASH that spreads out from its ring —
// water darkening the earth, frost crawling across the floor, a shaft of
// light coming down through the roof — and a living thing answering it. No
// hoops or hairlines: filled, tapered shapes and pools of light
// ([[feedback-vfx-material-not-lines]]), and no MaskFilter blur anywhere.

part of 'planet_dungeon_game.dart';

const GlassPalette _kVerdantGlass = kVerdantGlass;

/// Baked stone and ground, per room and state.
final Map<String, ui.Picture> _greenCache = {};

// ── Materials ───────────────────────────────────────────────
const Color _gSoilDry = Color(0xFF6B5638);
const Color _gSoilCrack = Color(0xFF2A1F14);
const Color _gSoilWet = Color(0xFF2B2117);
const Color _gSoilWetLit = Color(0xFF4A3A28);
const Color _gMoss = Color(0xFF4F7C3C);
const Color _gMossLit = Color(0xFF93BE62);
const Color _gLeaf = Color(0xFF3F6B34);
const Color _gLeafLit = Color(0xFF8DBB5E);
const Color _gLeafDead = Color(0xFF7A6644);
const Color _gStem = Color(0xFF3A5A2C);
// Bark is near-black, lit only along an edge (2026-10-08): the roots were a
// flat mid-brown with a broad pale stripe down each, which drew them.
const Color _gBark = Color(0xFF1F1913);
const Color _gBarkLit = Color(0xFF6E5A42);
const Color _gFrost = Color(0xFFDCEAF0);
const Color _gIce = Color(0xFF8EB6C8);
const Color _gHeat = Color(0xFFE0964A);
const Color _gSun = Color(0xFFF4E2A8);
const Color _gWaterLit = Color(0xFF6FAABB);
const Color _gGrey = Color(0xFF8A8A84);

// ── GROWTH IN GRAINS (2026-10-08) ───────────────────────────
// The specimens' stems, leaves and cushions, the great plant's crown, the
// hothouse's heat, the dust in the shaft and the motes round a thriving
// bloom are lit grains now, in the Conservatory's greens — they were flat
// clip-art seedlings, leaf stickers, squiggles and sprite dots. The glass
// (flowers, buds, collars, rings) is untouched: glass is the signal, grains
// are the living thing. Worked out from time alone and drawn in one batch.

final RiteGrainBatch _greenGrains = RiteGrainBatch();

double _greenHash(int n) {
  final s = sin(n * 127.1 + 311.7) * 43758.5453;
  return s - s.floorToDouble();
}

/// Living leaf, dead leaf: four steps each, from shadow to lit edge.
const List<Color> _kGreenLiveRamp = [
  Color(0xFF243F1E),
  _gMoss,
  Color(0xFF6E9A4A),
  Color(0xFFB4D884),
];
const List<Color> _kGreenDeadRamp = [
  Color(0xFF3A2E1C),
  Color(0xFF65543A),
  _gLeafDead,
  Color(0xFFB09A70),
];

/// The great plant's crown: its shaded heart and its sunlit rim.
const List<Color> _kGreenShadeRamp = [
  Color(0xFF16261A),
  Color(0xFF2A4628),
  _gLeaf,
  Color(0xFF7FA25A),
];
const List<Color> _kGreenSunlitRamp = [
  Color(0xFF2E4A22),
  Color(0xFF5E8A3E),
  Color(0xFF93BE62),
  Color(0xFFDDF0B0),
];

/// The standing crown, one ramp from its shaded heart to its sunlit rim.
const List<Color> _kGreenCrownRamp = [
  Color(0xFF1C3018),
  Color(0xFF3F6B34),
  Color(0xFF8AB65A),
  Color(0xFFD6ECA6),
];

/// The great plant's crown at full rise, as one shape about its top: the
/// same three rings of leaves the rise draws, each leaf a dense midrib and a
/// blade, the inner ring in shade and the outer in the light.
GrainShape? _greenCrown;
GrainShape _buildGreenCrown() {
  final pts = <Offset>[];
  final shades = <double>[];
  var k = 0;
  for (var ring = 0; ring < 3; ring++) {
    final n = 10 + ring * 4;
    final rad = 40.0 + ring * 34;
    final len = 26.0 + ring * 6;
    final lo = const [0.0, 0.18, 0.36][ring];
    final span = const [0.34, 0.36, 0.42][ring];
    for (var i = 0; i < n; i++) {
      final a = i * 2 * pi / n + ring * 0.4;
      final p = Offset(cos(a) * rad, sin(a) * rad * 0.62);
      final ca = cos(a), sa = sin(a);
      for (var j = 0; j < 90; j++, k++) {
        final h0 = _greenHash(k * 3 + 11), h1 = _greenHash(k * 5 + 17);
        final rib = j < 16;
        final sAlong = rib ? (j + 0.5) / 16 * 0.92 : 0.05 + 0.9 * h0;
        final half = 1.1 * len * sAlong * (1 - sAlong);
        final x = h1 * 2 - 1;
        final v = rib ? 0.0 : x * x.abs() * 0.35 * half + x * 0.65 * half;
        final lx = sAlong * len;
        pts.add(p + Offset(lx * ca - v * sa, lx * sa + v * ca));
        shades.add(lo + span * (rib ? 1.0 : 0.25 + 0.6 * (1 - x.abs())));
      }
    }
  }
  return GrainShape.points(pts, shades, seed: 19);
}

/// The opposite flower's petals: night-violet outside, rose within.
const List<Color> _kGreenNightRamp = [
  Color(0xFF1E1528),
  Color(0xFF3B2A4E),
  Color(0xFF5E4678),
  Color(0xFF9A82B8),
];
const List<Color> _kGreenRoseRamp = [
  Color(0xFF3A2030),
  Color(0xFF6A3E5A),
  Color(0xFF94607E),
  Color(0xFFD0A0B8),
];

/// Heat off the hothouse vents.
const List<Color> _kGreenHeatRamp = [
  Color(0xFF5A2A10),
  Color(0xFFA85A22),
  Color(0xFFE0964A),
  Color(0xFFF6CF8E),
];

/// The ramp [k] of the way from dead to living.
List<Color> _greenRamp(double k) => [
  for (var i = 0; i < 4; i++)
    Color.lerp(_kGreenDeadRamp[i], _kGreenLiveRamp[i], k.clamp(0.0, 1.0))!,
];

/// A leaf of grains lying from [base] along [a], [len] long — the lens of
/// [vfxLeaf], filled: a dense bright midrib and a sparser blade that darkens
/// to its edge, each grain stirring a little in place.
void _greenLeaf(
  Offset base,
  double len,
  double a,
  double t, {
  required List<Color> ramp,
  int n = 44,
  double alpha = 1,
  double stir = 0.6,
  int seed = 1,
}) {
  if (alpha <= 0.02 || len < 2) return;
  final ca = cos(a), sa = sin(a);
  final rib = (n * 0.2).round();
  for (var i = 0; i < n; i++) {
    final h0 = _greenHash(seed * 769 + i);
    final h1 = _greenHash(seed * 541 + i * 3 + 1);
    final h2 = _greenHash(seed * 233 + i * 7 + 2) * 6.3;
    final double s, v, shade;
    if (i < rib) {
      s = (i + 0.5) / rib * 0.92;
      v = 0;
      shade = 0.95;
    } else {
      // The blade fills the lens, a little thicker toward the rib, so the
      // leaf has a body and a soft edge rather than a hard outline.
      s = 0.05 + 0.9 * h0;
      final half = 0.9 * len * s * (1 - s);
      final x = h1 * 2 - 1;
      v = x * x.abs() * 0.35 * half + x * 0.65 * half;
      shade = 0.2 + 0.55 * (1 - x.abs());
    }
    Offset at(double tt) {
      final x = s * len + stir * sin(tt * 1.3 + h2);
      final y = v + stir * cos(tt * 1.1 + h2);
      return Offset(base.dx + x * ca - y * sa, base.dy + x * sa + y * ca);
    }

    final p = at(t), q = at(t - 0.08);
    _greenGrains.add(
      q.dx,
      q.dy,
      p.dx,
      p.dy,
      ramp[(shade * (ramp.length - 1)).round()],
      alpha: alpha * (0.75 + 0.25 * h1),
    );
  }
}

/// A stem of grains along [spine], [w0] wide at its foot and [w1] at its
/// head, lit down one side. [flow] sends the grains up it (sap rising) at
/// that many lengths a second; at 0 they only stir.
void _greenStem(
  List<Offset> spine,
  double w0,
  double w1,
  double t, {
  required List<Color> ramp,
  int n = 120,
  double alpha = 1,
  double flow = 0,
  int seed = 1,
}) {
  if (alpha <= 0.02 || spine.length < 2) return;
  final segs = spine.length - 1;
  Offset point(double u, double v) {
    final f = (u.clamp(0.0, 1.0)) * segs;
    final i = min(segs - 1, f.floor());
    final a = spine[i], b = spine[i + 1];
    var d = b - a;
    final len = d.distance;
    d = len < 1e-4 ? const Offset(0, -1) : d / len;
    final w = (w0 + (w1 - w0) * u) / 2;
    return Offset.lerp(a, b, f - i)! + Offset(-d.dy, d.dx) * (v * w);
  }

  for (var i = 0; i < n; i++) {
    final h0 = _greenHash(seed * 887 + i);
    final h1 = _greenHash(seed * 431 + i * 5 + 1) * 2 - 1;
    final h2 = _greenHash(seed * 197 + i * 9 + 2) * 6.3;
    final u = flow > 0 ? (h0 + t * flow * (0.7 + 0.3 * h1.abs())) % 1.0 : h0;
    final u0 = flow > 0 ? u - 0.06 * flow : u;
    final stir = flow > 0 ? 0.0 : 0.5;
    final p =
        point(u, h1) + Offset(stir * sin(t * 1.4 + h2), stir * cos(t + h2));
    final q = u0 < 0
        ? p
        : point(u0, h1) +
              Offset(
                stir * sin((t - 0.08) * 1.4 + h2),
                stir * cos(t - 0.08 + h2),
              );
    final fade = flow > 0 ? min(1.0, min(u, 1 - u) * 8) : 1.0;
    final shade = (0.62 - 0.4 * h1).clamp(0.0, 1.0);
    _greenGrains.add(
      q.dx,
      q.dy,
      p.dx,
      p.dy,
      ramp[(shade * (ramp.length - 1)).round()],
      alpha: alpha * fade,
    );
  }
}

/// A cushion of grains — moss, a crust — as a dome over [c]: dense and lit
/// on its crown, sparse and dark at its skirt.
void _greenCushion(
  Offset c,
  double rx,
  double ry,
  double t, {
  required List<Color> ramp,
  int n = 160,
  double alpha = 1,
  int seed = 1,
}) {
  if (alpha <= 0.02) return;
  for (var i = 0; i < n; i++) {
    final h0 = _greenHash(seed * 659 + i);
    final h1 = _greenHash(seed * 383 + i * 3 + 1) * 2 * pi;
    final h2 = _greenHash(seed * 101 + i * 11 + 2) * 6.3;
    final r = pow(h0, 0.7).toDouble();
    final x = cos(h1) * r * rx, y = sin(h1) * r * ry - (1 - r) * ry * 0.5;
    Offset at(double tt) => c + Offset(x + 0.5 * sin(tt * 1.2 + h2), y);
    final p = at(t), q = at(t - 0.08);
    final shade = ((1 - r) * 0.7 + 0.3 * (0.5 - 0.5 * sin(h1))).clamp(0.0, 1.0);
    _greenGrains.add(
      q.dx,
      q.dy,
      p.dx,
      p.dy,
      ramp[(shade * (ramp.length - 1)).round()],
      alpha: alpha * (0.55 + 0.45 * (1 - r)),
    );
  }
}

/// Grains climbing off [base] — heat off a vent — rising [rise], fanning
/// from [half] to [spread], swaying, faded in and out.
void _greenRise(
  Offset base,
  double t, {
  required int n,
  required double rise,
  required List<Color> ramp,
  double half = 5,
  double spread = 18,
  double rate = 0.22,
  double sway = 4,
  double alpha = 1,
  double trail = 0.08,
  int seed = 1,
}) {
  if (alpha <= 0.02) return;
  final last = ramp.length - 1;
  for (var i = 0; i < n; i++) {
    final h0 = _greenHash(seed * 977 + i);
    final h1 = _greenHash(seed * 613 + i * 7 + 1);
    final h2 = _greenHash(seed * 331 + i * 13 + 2) * 2 - 1;
    final r = rate * (0.7 + 0.6 * h1);
    final u = (t * r + h0) % 1.0;
    final u0 = u - trail * r;
    if (u0 < 0) continue;
    Offset at(double tt, double uu) => Offset(
      base.dx +
          h2 * (half + (spread - half) * uu) +
          sway * uu * sin(tt * 1.1 + h1 * 6.3 + uu * 3.0),
      base.dy - rise * uu,
    );
    final p = at(t, u), q = at(t - trail, u0);
    final a = alpha * min(1.0, u / 0.12) * (u < 0.5 ? 1.0 : 2 - 2 * u);
    final shade = ((1 - u) * 0.75 + 0.25 * h1).clamp(0.0, 1.0);
    _greenGrains.add(
      q.dx,
      q.dy,
      p.dx,
      p.dy,
      ramp[(shade * last).round()],
      alpha: a,
    );
  }
}

/// Grains that never move, baked into a room's picture: moss, fern, weed,
/// a lily's flower. Gathered by shade and drawn once per shade.
class _GreenBake {
  _GreenBake(this.ramp);
  final List<Color> ramp;
  final List<List<Offset>> _at = [[], [], [], []];

  void add(Offset p, double shade) =>
      _at[(shade.clamp(0.0, 1.0) * (ramp.length - 1)).round()].add(p);

  /// A clump: dense and lit at its heart, thinning to its edge.
  void clump(Offset c, double r, int n, double Function() rnd) {
    for (var i = 0; i < n; i++) {
      final d = pow(rnd(), 0.8).toDouble();
      final a = rnd() * 2 * pi;
      add(
        c + Offset(cos(a) * d * r, sin(a) * d * r * 0.72),
        (1 - d) * 0.75 + 0.25 * rnd() - (sin(a) > 0 ? 0.15 : 0),
      );
    }
  }

  /// A leaf or frond: the lens of [vfxLeaf], a dense midrib and its blade.
  void leaf(Offset base, double len, double a, int n, double Function() rnd) {
    final ca = cos(a), sa = sin(a);
    for (var i = 0; i < n; i++) {
      final rib = i < n * 0.3;
      final s = rib ? (i + 0.5) / (n * 0.3) * 0.92 : 0.06 + 0.9 * rnd();
      final v = rib ? 0.0 : (rnd() * 2 - 1) * 0.76 * len * s * (1 - s);
      final x = s * len, y = v;
      add(
        Offset(base.dx + x * ca - y * sa, base.dy + x * sa + y * ca),
        rib ? 0.9 : 0.25 + 0.5 * rnd(),
      );
    }
  }

  void paint(Canvas c, {double alpha = 1, double width = 1.7}) {
    for (var i = 0; i < _at.length; i++) {
      if (_at[i].isEmpty) continue;
      c.drawPoints(
        ui.PointMode.points,
        _at[i],
        Paint()
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..color = ramp[i].withValues(alpha: alpha * (0.55 + 0.15 * i)),
      );
    }
  }
}

/// A creature element's pane colour: its own colour, a third of the way into
/// the glass so it reads as stained, not as a UI chip.
Color _paneTint(String element) =>
    Color.lerp(elementColor(element), _kVerdantGlass.liveCore, 0.18)!;

double _ease(double t) => Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));
double _easeOut(double t) => Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));

/// A little sin that never repeats in step across instances.
double _sway(double time, double seed, [double speed = 1]) =>
    sin(time * speed + seed * 12.9898);

/// The trellis beds as one shape: the root approach, the west bed to its
/// stone end, and the east bed to the pond's edge. The island is its own.
Path _trellisBedPath({double inset = 14}) {
  Rect run(TrellisCell a, TrellisCell b) => Rect.fromPoints(
    trellisCellCentre(a),
    trellisCellCentre(b),
  ).inflate(kTrellisTile / 2 - inset);
  final r = Radius.circular(kTrellisTile / 2 - inset);
  return Path()
    ..addRRect(RRect.fromRectAndRadius(run(kTrellisRoot, kTrellisFork), r))
    ..addRRect(
      RRect.fromRectAndRadius(run(kTrellisWestBed.last, kTrellisFork), r),
    )
    ..addRRect(RRect.fromRectAndRadius(run(kTrellisFork, (5, 3)), r));
}

// ─────────────────────────────────────────────────────────
// SHOWN STATE
// ─────────────────────────────────────────────────────────

class ConservatoryRingFx {
  ConservatoryRingFx(this.at, this.color, {this.refused = false});
  final Offset at;
  final Color color;
  final bool refused;
  double t = 0;
}

/// One bud of the door's roots turning from [from] to [to] once [delay] has
/// passed — the climb reaches buds one after another.
class ConservatoryRootFx {
  ConservatoryRootFx(this.from, this.to, this.delay);
  final RootState from;
  final RootState to;
  final double delay;
  double t = 0;
}

/// A climate travelling the roots from a tip through [nodes].
class ConservatoryRootRun {
  ConservatoryRootRun(this.tip, this.product, this.nodes);
  final String tip;
  final String product;
  final List<String> nodes;
  double t = 0;
}

/// Everything the Conservatory's pictures ease toward. The module
/// (planet_dungeon_game_plant.dart) writes the rules; this holds how far each
/// picture has got, so nothing snaps.
class ConservatoryShown {
  // Star 1 and its cutscene.
  final Map<Climate, double> heal = {}; // seconds since healed (absent = not)
  double cutPending = 0;
  double cutT = -1;

  // The rings' own answers.
  final List<ConservatoryRingFx> rings = [];

  // Star 2.
  double waterT = -1;
  double freezeT = -1;
  double lampW = 0; // shown glow of the west lamp
  double lampE = 1;
  List<TrellisCell> tendrilPath = const [];
  TendrilStop tendrilStop = TendrilStop.dry;
  double tendrilShown = 0;
  double tendrilTarget = 0;
  bool tendrilLanded = true;
  double budBurstT = -1;
  double seedDropT = -1;
  double hatchT = -1;

  bool get tendrilMoving => (tendrilShown - tendrilTarget).abs() > 1e-6;

  // The rite.
  /// The door's roots as DRAWN: each bud's shown state, and the climb or
  /// crawl that is changing it (a bud waits out its delay, then turns).
  final Map<String, RootState> rootShown = {};
  final Map<String, ConservatoryRootFx> rootFx = {};

  /// The climate travelling up a root right now (a bead of water or light
  /// climbing, frost crawling), for the eye to follow.
  final List<ConservatoryRootRun> rootRuns = [];

  /// The roots letting go (< -50 = not yet; negative = the last climate
  /// still landing).
  double unwindT = -99;

  /// The great plant's crown flowering into the door's key (-1 = not
  /// started; the cut after the Bud Star runs it).
  double crownBloomT = -1;

  // Botanica.
  double lull = 0;
  double strikeT = -1;
  Climate strikeClimate = Climate.dry;
  double restoreT = -1;
  Climate restoredClimate = Climate.dry;
  final Map<Climate, double> wash = {}; // the arena's climate as shown

  Climate? get strikeClimateIfLanding => strikeT >= 0 ? strikeClimate : null;

  // The maxim.
  final Map<SeedChannel, double> drawn = {}; // seconds since drawn back
  double seedBloom = -1;

  void reset() {
    heal.clear();
    cutPending = 0;
    cutT = -1;
    rings.clear();
    waterT = -1;
    freezeT = -1;
    lampW = 0;
    lampE = 1;
    tendrilPath = const [];
    tendrilStop = TendrilStop.dry;
    tendrilShown = 0;
    tendrilTarget = 0;
    tendrilLanded = true;
    budBurstT = -1;
    seedDropT = -1;
    hatchT = -1;
    rootShown.clear();
    rootFx.clear();
    rootRuns.clear();
    unwindT = -99;
    crownBloomT = -1;
    lull = 0;
    strikeT = -1;
    restoreT = -1;
    wash.clear();
    drawn.clear();
    seedBloom = -1;
  }

  void settleWings() {
    for (final c in Climate.values) {
      heal[c] = 99;
    }
  }

  void settleTrellis(TrellisState t, int len) {
    waterT = 99;
    freezeT = 99;
    lampW = t.lit == TrellisLamp.west ? 1 : 0;
    lampE = t.lit == TrellisLamp.east ? 1 : 0;
    tendrilPath = growTendril(t).path;
    tendrilStop = growTendril(t).stop;
    tendrilShown = len.toDouble();
    tendrilTarget = len.toDouble();
    tendrilLanded = true;
    budBurstT = 99;
    seedDropT = 99;
  }

  void settleRoots() {
    rootShown.addAll(kRootTarget);
    unwindT = 99;
  }

  /// A press changed [changed] (in the order the climate reached them).
  void rootsChanged(
    String tip,
    String product,
    List<(String, RootState)> changed,
  ) {
    const step = 0.2;
    for (final (i, (n, to)) in changed.indexed) {
      rootFx[n] = ConservatoryRootFx(
        rootShown[n] ?? RootState.dry,
        to,
        0.25 + i * step,
      );
      rootShown[n] = to;
    }
    rootRuns.add(
      ConservatoryRootRun(tip, product, [for (final (n, _) in changed) n]),
    );
  }

  void rootsPruned(Map<String, RootState> was) {
    var i = 0;
    for (final n in kRootNodes) {
      if (was[n] == RootState.dry) continue;
      rootFx[n] = ConservatoryRootFx(was[n]!, RootState.dry, 0.05 * i++);
      rootShown[n] = RootState.dry;
    }
  }

  void settleSeed() {
    for (final c in SeedChannel.values) {
      drawn[c] = 99;
    }
    seedBloom = 99;
  }

  void healWing(Climate c) => heal[c] = 0;

  void ringFired(Offset at, String product) =>
      rings.add(ConservatoryRingFx(at, _paneTint(product)));

  void ringRefused(Offset at) =>
      rings.add(ConservatoryRingFx(at, const Color(0xFF8A7A66), refused: true));

  void drawChannel(SeedChannel c) => drawn[c] = 0;
}

extension ConservatoryArt on PlanetDungeonGame {
  // ── Frame ─────────────────────────────────────────────────

  void _updatePlantGlass(double dt) {
    final s = _green;
    for (final c in s.heal.keys.toList()) {
      s.heal[c] = s.heal[c]! + dt;
    }
    for (final r in s.rings) {
      r.t += dt;
    }
    s.rings.removeWhere((r) => r.t > 1.4);
    if (s.waterT >= 0) s.waterT += dt;
    if (s.freezeT >= 0) s.freezeT += dt;
    final lit = greenhouse.trellis.lit;
    double toward(double v, double to, double rate) =>
        v < to ? min(to, v + dt * rate) : max(to, v - dt * rate);
    s.lampW = toward(s.lampW, lit == TrellisLamp.west ? 1 : 0, 1.4);
    s.lampE = toward(s.lampE, lit == TrellisLamp.east ? 1 : 0, 1.4);
    if (s.seedDropT >= 0) s.seedDropT += dt;
    if (s.hatchT >= 0) s.hatchT += dt;
    for (final f in s.rootFx.values) {
      f.t += dt;
    }
    s.rootFx.removeWhere((_, f) => f.t > f.delay + 0.9);
    for (final r in s.rootRuns) {
      r.t += dt;
    }
    s.rootRuns.removeWhere((r) => r.t > 0.25 + r.nodes.length * 0.2 + 0.6);
    if (s.unwindT > -50 && s.unwindT < 50) s.unwindT += dt;
    if (s.crownBloomT >= 0 && s.crownBloomT < 50) s.crownBloomT += dt;
    for (final c in Climate.values) {
      final want = greenhouse.arena == c ? 1.0 : 0.0;
      s.wash[c] = toward(s.wash[c] ?? 0, want, want > 0 ? 0.9 : 1.1);
    }
    if (s.restoreT >= 0) {
      // the module advances it; nothing to ease here
    }
    for (final c in s.drawn.keys.toList()) {
      s.drawn[c] = s.drawn[c]! + dt;
    }
    final blooming =
        discoveredClouds.contains(kPlantOppositeSeedEggId) ||
        _ritePendingEgg == kPlantOppositeSeedEggId;
    if (blooming && s.seedBloom < 0) s.seedBloom = 0;
    if (s.seedBloom >= 0) s.seedBloom += dt;
  }

  // ── The room ──────────────────────────────────────────────

  void _renderConservatory(Canvas canvas, DungeonRoom room) {
    final g = room.grove;
    _renderGreenShell(canvas, room);
    _renderGlassDoorPlugs(canvas, room);
    if (g == null) return;
    if (g.wing != null) {
      _renderWing(canvas, room, g.wing!);
    } else if (g.greatPlanter != null) {
      _renderHub(canvas, room, g);
    } else if (g.trellis) {
      _renderTrellis(canvas, room);
    } else if (g.rite) {
      _renderRite(canvas, room);
    } else if (g.arenaRings.isNotEmpty) {
      _renderArena(canvas, room, g);
    } else if (room.vaultCache != null) {
      _renderCellar(canvas, room);
    }
    _renderRingFx(canvas);
  }

  /// The glasshouse's stone, baked. Every room is a carved shell with a pale
  /// flag floor; the planet's own ground is painted over it room by room.
  void _renderGreenShell(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    canvas.drawPicture(
      _greenCache.putIfAbsent('shell|${room.id}', () {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        paintCarvedRoomShell(
          c,
          b,
          _kVerdantGlass,
          GlassRng(glassSeed(room.id, b)),
          doors: [
            for (final d in room.doors)
              if (_doorOnWall(room, d)) d.rect,
          ],
          faceDepth: 48,
          arcade: false,
          flagCourse: 96,
          jointOpacity: 0.32,
        );
        // Glasshouse mullions: the shadow of the roof's iron falls across
        // the floor in long bars — the one thing that says GLASSHOUSE from
        // above, and it is shadow, not glass.
        final inner = Rect.fromLTRB(b.left, b.top + 48, b.right, b.bottom);
        c.save();
        c.clipRect(inner);
        final bar = Paint()
          ..color = const Color(0xFF000000).withValues(alpha: 0.10);
        for (var x = b.left - b.height * 0.3; x < b.right; x += 132) {
          c.drawPath(
            Path()
              ..moveTo(x, inner.top)
              ..lineTo(x + 14, inner.top)
              ..lineTo(x + 14 + b.height * 0.3, inner.bottom)
              ..lineTo(x + b.height * 0.3, inner.bottom)
              ..close(),
            bar,
          );
        }
        c.restore();
        return rec.endRecording();
      }),
    );
  }

  // ─────────────────────────────────────────────────────────
  // THE TENDING CIRCLE
  // ─────────────────────────────────────────────────────────

  /// A leaded-glass ring set in the floor. Every ring has the same three
  /// panes — Water, Spirit, Crystal — each lit as a creature of that element
  /// stands in it, so the glass shows WHO is in the ring and never which
  /// bodies the recipe wants (the user, 2026-09-27: no recipe giveaways).
  /// Only the heart is tinted with what the ring wants. A ring whose work is
  /// done goes to silver.
  void _drawTendRing(
    Canvas canvas,
    Offset c,
    String? product, {
    bool done = false,
    double scale = 1,
  }) {
    final r = kTendRingDrawn * scale;
    final here = _ringElements(c).toSet();
    const els = ['Water', 'Spirit', 'Crystal'];
    paintContactShadow(canvas, c + const Offset(0, 4), r * 2.2, r * 0.9);
    // The carved stone collar the glass sits in.
    canvas.drawCircle(
      c,
      r + 9,
      Paint()..color = _kVerdantGlass.stoneFoot.withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      c,
      r + 6,
      Paint()
        ..shader = ui.Gradient.linear(
          c - Offset(0, r + 6),
          c + Offset(0, r + 6),
          [_kVerdantGlass.stoneTop, _kVerdantGlass.stoneFace],
        ),
    );
    // The panes.
    final n = els.length;
    final gap = n == 1 ? 0.0 : 0.08;
    for (var i = 0; i < n; i++) {
      final a0 = -pi / 2 + i * 2 * pi / n + gap / 2;
      final a1 = a0 + 2 * pi / n - gap;
      final e = els[i];
      final on = here.contains(e) || here.contains(product);
      final base = _kVerdantGlass.frostAt(i + c.dx.round());
      final lit = done
          ? Color.lerp(_kVerdantGlass.silver, _paneTint(e), 0.25)!
          : on
          ? _paneTint(e)
          : Color.lerp(base, _paneTint(e), 0.28)!;
      final pane = n == 1
          ? (Path()
              ..addOval(Rect.fromCircle(center: c, radius: r))
              ..addOval(Rect.fromCircle(center: c, radius: r * 0.52))
              ..fillType = PathFillType.evenOdd)
          : sectorPath(c, r * 0.52, r, a0, a1);
      paintPane(canvas, pane, lit, _kVerdantGlass, lead: 3);
      if (on || done) {
        paintStreak(
          canvas,
          Rect.fromCircle(
            center:
                c + Offset(cos((a0 + a1) / 2), sin((a0 + a1) / 2)) * r * 0.76,
            radius: r * 0.2,
          ),
          opacity: 0.5,
        );
      }
    }
    // The heart: a carved boss with the product's glyph-colour in it.
    paintRondel(
      canvas,
      c,
      r * 0.42,
      _kVerdantGlass,
      fill: product == null
          ? _kVerdantGlass.smoke
          : Color.lerp(
              _kVerdantGlass.smoke,
              _paneTint(product),
              done ? 0.7 : 0.35,
            ),
      rim: done ? 1 : 0.7,
    );
    // Leaves of carved stone round the rim, so a ring is a garden thing.
    for (var k = 0; k < 8; k++) {
      final a = k * pi / 4 + pi / 8;
      canvas.drawPath(
        vfxLeaf(c + Offset(cos(a), sin(a)) * (r + 4), 11, a),
        Paint()..color = _kVerdantGlass.stoneTop.withValues(alpha: 0.8),
      );
    }
    final lit = here.isNotEmpty && !done;
    if (lit && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        r * 1.5,
        _paneTint(
          product ?? here.first,
        ).withValues(alpha: 0.10 + 0.04 * sin(_time * 2.4)),
      );
    }
  }

  /// A ring's answer: the climate it made rolls out across the floor as a
  /// pool of light and petals of its colour; a refusal only shudders the
  /// stone.
  void _renderRingFx(Canvas canvas) {
    for (final f in _green.rings) {
      final t = f.t;
      if (f.refused) {
        final k = (1 - t / 0.5).clamp(0.0, 1.0);
        if (k <= 0) continue;
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3 + t * 3;
          canvas.drawPath(
            vfxShard(
              f.at + Offset(cos(a), sin(a)) * (kTendRingDrawn * (0.9 + t)),
              9,
              3,
              a,
            ),
            Paint()..color = f.color.withValues(alpha: 0.6 * k),
          );
        }
        continue;
      }
      final k = (t / 1.4).clamp(0.0, 1.0);
      final fade = 1 - k;
      final rad = kTendRingDrawn * (1 + 2.2 * _easeOut(k));
      canvas.drawCircle(
        f.at,
        rad,
        Paint()
          ..shader = ui.Gradient.radial(
            f.at,
            rad,
            [
              f.color.withValues(alpha: 0.0),
              f.color.withValues(alpha: 0.26 * fade),
              f.color.withValues(alpha: 0.0),
            ],
            const [0.55, 0.85, 1.0],
          ),
      );
      // Petals of its colour going out with it — in grains, loosening as
      // they go (they were flat leaf shapes).
      final ramp = grainRampFrom(f.color);
      for (var i = 0; i < 10; i++) {
        final a = i * pi / 5 + k * 0.8;
        _greenLeaf(
          f.at + Offset(cos(a), sin(a)) * (kTendRingDrawn * 0.6 + rad * 0.3),
          16 * (1 - k * 0.4),
          a,
          _time,
          ramp: ramp,
          n: 30,
          alpha: min(1.0, 0.9 * fade),
          stir: 0.5 + 3 * k,
          seed: 500 + i,
        );
      }
      _greenGrains.paint(canvas);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          f.at,
          kTendRingDrawn * 2,
          f.color.withValues(alpha: 0.35 * fade),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // STAR 1 — THE WINGS
  // ─────────────────────────────────────────────────────────

  void _renderWing(Canvas canvas, DungeonRoom room, ClimateWing wing) {
    final healed = _green.heal[wing.climate];
    final h = healed ?? 0.0;
    switch (wing.climate) {
      case Climate.dry:
        _renderDryBed(canvas, room, wing, h, healed != null);
      case Climate.warm:
        _renderHothouse(canvas, room, wing, h, healed != null);
      case Climate.dark:
        _renderShadehouse(canvas, room, wing, h, healed != null);
    }
    _drawTendRing(
      canvas,
      wing.ring,
      climateFix(wing.climate),
      done: healed != null,
    );
  }

  /// How far a wash has spread from its ring: seconds since the fix → the
  /// radius of the soaked, frosted or lit ground.
  double _washRadius(DungeonRoom room, Offset from, double t) {
    final far = [
      room.bounds.topLeft,
      room.bounds.topRight,
      room.bounds.bottomLeft,
      room.bounds.bottomRight,
    ].map((p) => (p - from).distance).reduce(max);
    return far * _ease(t / 2.4);
  }

  /// Draw [under] everywhere, and [over] inside an irregular blob spreading
  /// from [from] — one clip and one picture, however large the room.
  void _spreadPictures(
    Canvas canvas,
    DungeonRoom room,
    ui.Picture under,
    ui.Picture over,
    Offset from,
    double t,
    bool done,
  ) {
    if (!done || t <= 0) {
      canvas.drawPicture(under);
      return;
    }
    final r = _washRadius(room, from, t);
    if (t >= 2.4) {
      canvas.drawPicture(over);
      return;
    }
    canvas.drawPicture(under);
    canvas.save();
    canvas.clipPath(vfxBlob(from, max(1.0, r), from.dx, n: 18, wobble: 0.12));
    canvas.drawPicture(over);
    canvas.restore();
  }

  // ── The Dry Bed ─────────────────────────────────────────

  ui.Picture _dryGround(DungeonRoom room, bool wet) =>
      _greenCache.putIfAbsent('dry|${room.id}|$wet', () {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        final b = room.bounds;
        final bed = Rect.fromLTRB(
          b.left + 70,
          b.top + 110,
          b.right - 70,
          b.bottom - 50,
        );
        final rr = RRect.fromRectAndRadius(bed, const Radius.circular(30));
        // The kerb: a low course of carved stone round the whole bed.
        paintCarvedBlock(
          c,
          bed.inflate(10),
          8,
          _kVerdantGlass,
          radius: 30,
          topColor: _kVerdantGlass.stoneFace,
        );
        c.drawRRect(rr, Paint()..color = wet ? _gSoilWet : _gSoilCrack);
        var seed = 7;
        double rnd() {
          seed = (seed * 1103515245 + 12345) & 0x3FFFFFFF;
          return (seed >> 8) / 0x3FFFFF;
        }

        c.save();
        c.clipRRect(rr);
        if (!wet) {
          // Cracked earth: parched plates packed edge to edge, the dark
          // ground showing only in the gaps between them — each plate a
          // lit top over a darker lip, so the crust reads as curled.
          //
          // DARKER AND CLOSER IN TONE (2026-10-08): bright sandy plates on
          // black read as cartoon cobbles. A crust in a dim glasshouse is
          // dust-dull, only its curled edge catching the light — still the
          // palest ground on the planet, so dry still reads as dry.
          for (var row = 0; bed.top + row * 38 < bed.bottom + 20; row++) {
            final y = bed.top + row * 38;
            for (
              var x = bed.left - 10 + (row.isOdd ? 22 : 0);
              x < bed.right + 20;
              x += 44
            ) {
              final p = Offset(x + rnd() * 8, y + rnd() * 8);
              // Packed close, so what shows between them is a crack and not
              // a gap — cracked earth, not cobbles.
              final r = 25.5 + rnd() * 4;
              // A plate is a sharp-cornered polygon, not a pebble: dried mud
              // splits along straight-ish lines.
              final n = 5 + (rnd() * 3).floor();
              final a0 = rnd() * pi;
              Path plate(double shrink, Offset at) {
                final path = Path();
                for (var k = 0; k < n; k++) {
                  final a = a0 + k * 2 * pi / n + (rnd() - 0.5) * 0.5;
                  final rr = (r - shrink) * (0.82 + rnd() * 0.3);
                  final q = at + Offset(cos(a) * rr, sin(a) * rr * 0.86);
                  k == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
                }
                return path..close();
              }

              final shade = rnd() * 0.55;
              c.drawPath(
                plate(0, p + const Offset(0, 2.5)),
                Paint()..color = const Color(0xFF2A2016),
              );
              // The curled lip catching the light along its upper edge:
              // the plate once a pixel up in a paler dust, then itself.
              final top = plate(2.5, p);
              c.drawPath(
                top.shift(const Offset(0, -1.2)),
                Paint()..color = const Color(0xFF7A6646),
              );
              c.drawPath(
                top,
                Paint()
                  ..color = Color.lerp(
                    const Color(0xFF433626),
                    const Color(0xFF5A4A33),
                    shade,
                  )!,
              );
            }
          }
        } else {
          // Moist earth: soft darker loam with a sheen and a scatter of
          // moss cushions.
          for (var i = 0; i < 90; i++) {
            final p = Offset(
              bed.left + rnd() * bed.width,
              bed.top + rnd() * bed.height,
            );
            c.drawPath(
              vfxBlob(p, 6 + rnd() * 16, rnd() * 99, n: 8, wobble: 0.2),
              Paint()..color = _gSoilWetLit.withValues(alpha: 0.35),
            );
          }
          // Moss coming back, in clumps of grains (they were flat green
          // blobs laid on the loam).
          final moss = _GreenBake(_kGreenLiveRamp);
          for (var i = 0; i < 40; i++) {
            final p = Offset(
              bed.left + rnd() * bed.width,
              bed.top + rnd() * bed.height,
            );
            final r = 5 + rnd() * 9;
            moss.clump(p, r * 1.6, (r * 16).round(), rnd);
          }
          moss.paint(c, alpha: 0.95);
        }
        c.restore();
        return rec.endRecording();
      });

  void _renderDryBed(
    Canvas canvas,
    DungeonRoom room,
    ClimateWing wing,
    double t,
    bool healed,
  ) {
    _spreadPictures(
      canvas,
      room,
      _dryGround(room, false),
      _dryGround(room, true),
      wing.ring,
      t,
      healed,
    );
    // The wet front glints as it goes.
    if (healed && t < 2.4) {
      final r = _washRadius(room, wing.ring, t);
      canvas.drawCircle(
        wing.ring,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            wing.ring,
            max(1.0, r),
            [
              _gWaterLit.withValues(alpha: 0),
              _gWaterLit.withValues(alpha: 0.22),
              _gWaterLit.withValues(alpha: 0),
            ],
            const [0.8, 0.96, 1.0],
          ),
      );
    }
    _drawPlanter(canvas, wing.plant, _paneTint('Water'), healed);
    _drawMossBloom(canvas, wing.plant, healed ? _ease((t - 0.9) / 2.0) : 0);
  }

  /// A raised planter: a carved stone drum with a leaded-glass collar, lit in
  /// its climate's colour once the plant in it is thriving.
  void _drawPlanter(
    Canvas canvas,
    Offset at,
    Color tint,
    bool lit, {
    double r = 46,
  }) {
    paintContactShadow(canvas, at + Offset(0, r * 0.5), r * 2.6, r * 0.8);
    paintCarvedDisc(canvas, at, r, r * 0.55, 18, _kVerdantGlass);
    // The collar: a ring of small panes round the drum's lip.
    const n = 10;
    for (var i = 0; i < n; i++) {
      final a0 = i * 2 * pi / n + 0.05;
      final a1 = a0 + 2 * pi / n - 0.1;
      final pane = ellipseSectorPath(
        at,
        r * 0.78,
        r * 0.43,
        r,
        r * 0.55,
        a0,
        a1,
      );
      paintPane(
        canvas,
        pane,
        lit
            ? Color.lerp(tint, _kVerdantGlass.liveCore, i.isEven ? 0.1 : 0.3)!
            : _kVerdantGlass.frostAt(i),
        _kVerdantGlass,
        lead: 2,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: at, width: r * 1.56, height: r * 0.86),
      Paint()..color = lit ? _gSoilWet : const Color(0xFF4A3B28),
    );
  }

  /// THE QUICKSILVER ROSE. A cushion of moss, and out of it a rosette of
  /// leaded water-glass cradling a floating bead of living water, under the
  /// ▽ of Water in a gold nimbus. Unhealed: a brown crust and a shut bud of
  /// smoked glass.
  void _drawMossBloom(Canvas canvas, Offset at, double k) {
    final ramp = _greenRamp(k);
    // The cushion: a dome of grains, a brown crust while the bed is dry and
    // moss once it is wet (it was eleven flat blobs).
    _greenCushion(
      at - const Offset(0, 2),
      22 + 14 * k,
      9 + 6 * k,
      _time,
      ramp: ramp,
      n: 320 + (120 * k).round(),
      seed: 11,
    );
    final head = at + Offset(0, -46 - 34 * k + 2 * _sway(_time, 1.3, 1.1));
    // The stem, a short twist of grains — sap running up it once it lives.
    final mid = Offset.lerp(at, head, 0.5)! + const Offset(4, 0);
    _greenStem(
      [
        for (var i = 0; i <= 8; i++)
          () {
            final u = i / 8;
            return Offset.lerp(
              Offset.lerp(at - const Offset(0, 4), mid, u)!,
              Offset.lerp(mid, head, u)!,
              u,
            )!;
          }(),
      ],
      6,
      3,
      _time,
      ramp: ramp,
      n: 200,
      flow: k > 0.5 ? 0.3 : 0,
      seed: 12,
    );
    _greenGrains.paint(canvas);
    _sigilNimbus(canvas, head, 54, k, _paneTint('Water'), glyph: 'water');
    const water = Color(0xFF4FA3D8);
    const waterCore = Color(0xFFBFE6F6);
    if (k < 0.12) {
      _shutBud(canvas, head, 15, const Color(0xFF5E5040));
      return;
    }
    final open = _ease((k - 0.12) / 0.88);
    // Two tiers of glass petals: the outer deep, the inner pale.
    for (var tier = 0; tier < 2; tier++) {
      final n = tier == 0 ? 8 : 6;
      for (var i = 0; i < n; i++) {
        final a = -pi / 2 + i * 2 * pi / n + tier * 0.4 + _time * 0.05;
        final len = (tier == 0 ? 40 : 26) * (0.35 + 0.65 * open);
        final spread = 0.55 + 0.45 * open;
        _glassPetal(
          canvas,
          head,
          len,
          a,
          len * 0.34 * spread,
          tier == 0 ? water : Color.lerp(water, waterCore, 0.55)!,
          tier == 0 ? const Color(0xFF1F5A86) : water,
          squash: 0.62,
        );
      }
    }
    // The bead: a sphere of living water, bobbing over the rosette, with a
    // droplet now and then falling back into it.
    final bead = head + Offset(0, -8 - 5 * sin(_time * 1.8)) * open;
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        bead,
        46,
        water.withValues(alpha: 0.45 * open),
      );
    }
    canvas.drawCircle(
      bead,
      11 * open,
      Paint()
        ..shader = ui.Gradient.radial(
          bead - const Offset(2.5, 3),
          9 * open + 0.1,
          [Colors.white, waterCore, water],
          const [0.0, 0.35, 1.0],
        ),
    );
    for (var i = 0; i < 3; i++) {
      final u = ((_time * 0.55 + i / 3) % 1.0);
      final p = bead + Offset(10 * sin(i * 2.1), -10 - 30 * u);
      canvas.drawPath(
        vfxDrop(p, 2.4, u < 0.5 ? -pi / 2 : pi / 2),
        Paint()..color = waterCore.withValues(alpha: 0.8 * sin(u * pi) * open),
      );
    }
    _orbitMotes(canvas, head, 38, 3, waterCore, open, 0.9);
  }

  // ── The Hothouse ────────────────────────────────────────

  ui.Picture _hotGround(DungeonRoom room, bool frost) =>
      _greenCache.putIfAbsent('hot|${room.id}|$frost', () {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        final b = room.bounds;
        final floor = Rect.fromLTRB(b.left, b.top + 48, b.right, b.bottom);
        var seed = 11;
        double rnd() {
          seed = (seed * 1103515245 + 12345) & 0x3FFFFFFF;
          return (seed >> 8) / 0x3FFFFF;
        }

        if (!frost) {
          // Heat: warm amber pools over the flags where the vents breathe.
          for (final v in _hotVents(room)) {
            c.drawCircle(
              v,
              160,
              Paint()
                ..shader = ui.Gradient.radial(v, 160, [
                  _gHeat.withValues(alpha: 0.22),
                  _gHeat.withValues(alpha: 0),
                ]),
            );
          }
        } else {
          // Frost: a pale crust across the flags, in overlapping flakes, and
          // feathered ferns of rime.
          c.save();
          c.clipRect(floor);
          c.drawRect(floor, Paint()..color = _gFrost.withValues(alpha: 0.16));
          for (var i = 0; i < 70; i++) {
            final p = Offset(
              floor.left + rnd() * floor.width,
              floor.top + rnd() * floor.height,
            );
            c.drawPath(
              vfxBlob(p, 10 + rnd() * 26, rnd() * 99, n: 7, wobble: 0.3),
              Paint()..color = _gFrost.withValues(alpha: 0.10 + rnd() * 0.12),
            );
          }
          for (var i = 0; i < 26; i++) {
            final p = Offset(
              floor.left + rnd() * floor.width,
              floor.top + rnd() * floor.height,
            );
            final a = rnd() * pi * 2;
            for (var k = 0; k < 6; k++) {
              final q = p + Offset(cos(a), sin(a)) * (k * 7.0);
              c.drawPath(
                vfxLeaf(q, 9 - k * 1.0, a + 0.9),
                Paint()..color = _gFrost.withValues(alpha: 0.35),
              );
              c.drawPath(
                vfxLeaf(q, 9 - k * 1.0, a - 0.9),
                Paint()..color = _gFrost.withValues(alpha: 0.35),
              );
            }
          }
          c.restore();
        }
        // The vents themselves: iron grates set in the floor — a dark
        // carved kerb, near-black bars lit only along their tops, and the
        // state in what lies between them: the fire's glow coming up while
        // the room is hot, rime on the iron once it is cold (2026-10-08; a
        // pale stone box with brown or white bars, a vent icon).
        for (final v in _hotVents(room)) {
          final grate = Rect.fromCenter(center: v, width: 86, height: 34);
          paintCarvedBlock(
            c,
            grate.inflate(6),
            5,
            _kVerdantGlass,
            radius: 4,
            topColor: Color.lerp(
              _kVerdantGlass.stoneFace,
              _kVerdantGlass.stoneFoot,
              0.45,
            ),
          );
          c.drawRRect(
            RRect.fromRectAndRadius(grate, const Radius.circular(3)),
            Paint()..color = const Color(0xFF0C0A08),
          );
          if (!frost) {
            // The fire below, seen between the bars: hottest at the middle.
            c.drawRect(
              grate.deflate(3),
              Paint()
                ..shader = ui.Gradient.radial(v, grate.width * 0.5, [
                  _gHeat.withValues(alpha: 0.55),
                  const Color(0xFF8A3A14).withValues(alpha: 0.25),
                ]),
            );
          }
          if (frost) {
            // Cold through: a pale bloom of frost in the slots.
            c.drawRect(
              grate.deflate(3),
              Paint()..color = _gFrost.withValues(alpha: 0.2),
            );
          }
          for (var x = grate.left + 8; x < grate.right - 4; x += 12) {
            final bar = Rect.fromLTWH(x, grate.top + 3, 4, grate.height - 6);
            c.drawRect(
              bar,
              Paint()
                ..color = frost
                    ? Color.lerp(const Color(0xFF15130F), _gIce, 0.4)!
                    : const Color(0xFF15130F),
            );
            c.drawRect(
              Rect.fromLTWH(bar.left, bar.top, bar.width, frost ? 2.4 : 1),
              Paint()
                ..color = (frost ? _gFrost : _gHeat).withValues(
                  alpha: frost ? 0.95 : 0.35,
                ),
            );
            if (frost) {
              c.drawRect(
                Rect.fromLTWH(bar.left, bar.top + 2, 1.4, bar.height - 4),
                Paint()..color = _gFrost.withValues(alpha: 0.7),
              );
            }
          }
          if (frost) {
            // Rime grains furred over the iron.
            final rime = _GreenBake(const [
              Color(0xFF8EB6C8),
              Color(0xFFB8D4E0),
              Color(0xFFDCEAF0),
              Color(0xFFFFFFFF),
            ]);
            for (var i = 0; i < 70; i++) {
              rime.add(
                Offset(
                  grate.left + 2 + rnd() * (grate.width - 4),
                  grate.top + 2 + rnd() * (grate.height - 4),
                ),
                rnd(),
              );
            }
            rime.paint(c, width: 1.4);
          }
        }
        return rec.endRecording();
      });

  List<Offset> _hotVents(DungeonRoom room) {
    final b = room.bounds;
    return [
      Offset(b.left + 120, b.top + 130),
      Offset(b.right - 150, b.top + 130),
      Offset(b.left + 120, b.bottom - 90),
      Offset(b.right - 150, b.bottom - 90),
    ];
  }

  void _renderHothouse(
    Canvas canvas,
    DungeonRoom room,
    ClimateWing wing,
    double t,
    bool healed,
  ) {
    _spreadPictures(
      canvas,
      room,
      _hotGround(room, false),
      _hotGround(room, true),
      wing.ring,
      t,
      healed,
    );
    // Heat over each vent while the room is hot: grains of it rising off
    // the grate and wavering as they thin — the only moving thing in a room
    // that has given up (they were stroked squiggles).
    final hot = healed ? (1 - _ease(t / 1.6)) : 1.0;
    if (hot > 0.02) {
      for (final (i, v) in _hotVents(room).indexed) {
        _greenRise(
          v - const Offset(0, 6),
          _time,
          n: 230,
          rise: 100,
          half: 34,
          spread: 46,
          rate: 0.18,
          sway: 10,
          ramp: _kGreenHeatRamp,
          alpha: 0.32 * hot,
          trail: 0.1,
          seed: 40 + i,
        );
      }
      _greenGrains.paint(canvas);
    }
    // The frost front: a crisp pale edge on the spreading blob.
    if (healed && t < 2.4) {
      final r = _washRadius(room, wing.ring, t);
      for (var i = 0; i < 28; i++) {
        final a = i * 2 * pi / 28;
        final p =
            wing.ring +
            Offset(cos(a), sin(a)) * r * (0.9 + 0.1 * _sway(0, i.toDouble()));
        canvas.drawPath(
          vfxShard(p, 14, 4, a),
          Paint()..color = _gFrost.withValues(alpha: 0.7),
        );
      }
    }
    _drawPlanter(canvas, wing.plant, _paneTint('Ice'), healed);
    _drawFrostLily(canvas, wing.plant, healed ? _ease((t - 1.0) / 2.0) : 0);
  }

  /// THE RIME LILY. A tall stem that droops in the heat, its bud shut and
  /// browned. When the frost comes it straightens, needles of ice grow along
  /// it, and six faceted petals of ice-glass open round a hexagonal crystal
  /// heart, in front of a slow-turning six-armed frost sigil.
  void _drawFrostLily(Canvas canvas, Offset at, double k) {
    final droop = 1 - k;
    final sway = _sway(_time, at.dx, 0.9) * 0.04;
    final top = at + Offset(52 * droop + 30 * sway, -110 + 56 * droop);
    final ctrl = at + Offset(6, -88);
    final spine = [
      for (var i = 0; i <= 10; i++)
        () {
          final u = i / 10;
          return Offset.lerp(
            Offset.lerp(at, ctrl, u)!,
            Offset.lerp(ctrl, top, u)!,
            u,
          )!;
        }(),
    ];
    // Stem and leaves in grains, wilted ochre in the heat and a cold
    // blue-green once the frost has it (they were flat ribbon and leaf
    // shapes).
    final ramp = [
      for (var i = 0; i < 4; i++)
        Color.lerp(
          _kGreenDeadRamp[i],
          Color.lerp(_kGreenLiveRamp[i], const Color(0xFF7FB8B0), 0.35)!,
          k,
        )!,
    ];
    _greenStem(
      spine,
      7,
      3,
      _time,
      ramp: ramp,
      n: 260,
      flow: k > 0.5 ? 0.25 : 0,
      seed: 21,
    );
    for (final (i, (u, side)) in const [(0.3, -1.0), (0.45, 1.0)].indexed) {
      final p = spine[(u * 10).round()];
      _greenLeaf(
        p,
        40,
        -pi / 2 + side * (1.1 + 0.5 * droop),
        _time,
        ramp: ramp,
        n: 150,
        seed: 22 + i,
      );
    }
    _greenGrains.paint(canvas);
    // Ice needles along the stem.
    if (k > 0.05) {
      for (var i = 2; i < 9; i += 2) {
        final p = spine[i];
        for (final side in const [-1.0, 1.0]) {
          canvas.drawPath(
            vfxShard(p + Offset(side * 4, 0), 9 * k, 2.2, -pi / 2 + side * 0.9),
            Paint()..color = _gFrost.withValues(alpha: 0.85 * k),
          );
        }
      }
    }
    _sigilNimbus(canvas, top, 50, k, _gFrost, glyph: 'frost');
    if (k < 0.2) {
      _shutBud(canvas, top, 13, const Color(0xFF7A6E58), droop: droop);
      return;
    }
    final open = _ease((k - 0.2) / 0.8);
    const ice = Color(0xFF9CCBE0);
    const iceDeep = Color(0xFF3E7896);
    for (var i = 0; i < 6; i++) {
      final a = -pi / 2 + i * pi / 3 + pi / 6;
      _glassPetal(
        canvas,
        top,
        (22 + 20 * open),
        a,
        9 + 3 * open,
        Color.lerp(ice, Colors.white, 0.35)!,
        iceDeep,
        faceted: true,
        squash: 0.75,
      );
    }
    // The crystal heart: a hexagon of glass with a white-hot core.
    final hex = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3 + _time * 0.2;
      final q = top + Offset(cos(a), sin(a) * 0.8) * 8 * open;
      i == 0 ? hex.moveTo(q.dx, q.dy) : hex.lineTo(q.dx, q.dy);
    }
    hex.close();
    paintPane(
      canvas,
      hex,
      Color.lerp(ice, Colors.white, 0.7)!,
      _kVerdantGlass,
      lead: 2,
    );
    if (_fx.ready) {
      drawGlow(canvas, _fx.glow!, top, 70, ice.withValues(alpha: 0.4 * open));
      drawGlow(
        canvas,
        _fx.glow!,
        top,
        18,
        Colors.white.withValues(alpha: 0.7 * open),
      );
    }
    _orbitMotes(canvas, top, 44, 4, _gFrost, open, -0.6);
  }

  // ── The Shadehouse ──────────────────────────────────────

  void _renderShadehouse(
    Canvas canvas,
    DungeonRoom room,
    ClimateWing wing,
    double t,
    bool healed,
  ) {
    final b = room.bounds;
    final k = healed ? _ease(t / 2.2) : 0.0;
    // The glass roof overhead, drawn as the shade its iron throws: it is the
    // shadehouse's whole look, and the light will come through it.
    // The dark: most of the room under a heavy veil that lifts as the shaft
    // comes down.
    canvas.drawRect(
      b,
      Paint()
        ..color = const Color(
          0xFF05070A,
        ).withValues(alpha: 0.42 * (1 - k * 0.8)),
    );
    // THE SHAFT: a tapered wedge of warm light from the roof to the flower,
    // with dust hanging in it.
    if (k > 0) {
      final top = Offset(wing.plant.dx - 60, b.top + 40);
      final shaft = Path()
        ..moveTo(top.dx - 40, b.top + 48)
        ..lineTo(top.dx + 60, b.top + 48)
        ..lineTo(wing.ring.dx + 120, wing.ring.dy + 70)
        ..lineTo(wing.ring.dx - 130, wing.ring.dy + 70)
        ..close();
      canvas.drawPath(
        shaft,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(top.dx, b.top + 48),
            Offset(wing.ring.dx, wing.ring.dy + 70),
            [
              _gSun.withValues(alpha: 0.30 * k),
              _gSun.withValues(alpha: 0.12 * k),
            ],
          ),
      );
      final pool = wing.ring + const Offset(0, 20);
      canvas.drawOval(
        Rect.fromCenter(center: pool, width: 300, height: 150),
        Paint()
          ..shader = ui.Gradient.radial(pool, 150, [
            _gSun.withValues(alpha: 0.22 * k),
            _gSun.withValues(alpha: 0),
          ]),
      );
      // Dust hanging in it, as grains drifting down the light (it was
      // fourteen sprite motes).
      final from = Offset(top.dx + 10, b.top + 60);
      final to = wing.ring + const Offset(0, 40);
      for (var i = 0; i < 180; i++) {
        final h0 = _greenHash(i * 13 + 1), h1 = _greenHash(i * 7 + 2);
        Offset where(double tt) {
          final u = (tt * (0.02 + 0.02 * h1) + h0) % 1.0;
          final w = 20 + 110 * u;
          return Offset.lerp(from, to, u)! +
              Offset(
                (h1 * 2 - 1) * w + 6 * sin(tt * 0.4 + i),
                3 * cos(tt * 0.5 + i * 1.3),
              );
        }

        final u = (_time * (0.02 + 0.02 * h1) + h0) % 1.0;
        final p = where(_time), q = where(_time - 0.2);
        if ((p - q).distance > 20) continue;
        _greenGrains.add(
          q.dx,
          q.dy,
          p.dx,
          p.dy,
          i % 9 == 0 ? Colors.white : _gSun,
          alpha: 0.42 * k * min(1.0, min(u, 1 - u) * 6),
        );
      }
      _greenGrains.paint(canvas);
    }
    _drawPlanter(canvas, wing.plant, _paneTint('Light'), healed);
    _drawSunflower(canvas, wing.plant, healed ? _ease((t - 0.8) / 2.2) : 0);
  }

  /// THE SOL BLOOM. Bowed to the floor in the dark, its glass smoked. When
  /// the light comes it lifts into the shaft and opens as the alchemist's
  /// sun: a gold disc with its point (☉), two rings of flame-glass petals
  /// turning against each other, and a nimbus of rays.
  void _drawSunflower(Canvas canvas, Offset at, double k) {
    final bow = 1 - k;
    final top = at + Offset(-10 * k + 40 * bow, -96 + 56 * bow);
    final ctrl = at + Offset(-4, -76);
    final spine = [
      for (var i = 0; i <= 10; i++)
        () {
          final u = i / 10;
          return Offset.lerp(
            Offset.lerp(at, ctrl, u)!,
            Offset.lerp(ctrl, top, u)!,
            u,
          )!;
        }(),
    ];
    // Stem and leaves in grains: bowed and ochre in the dark, green and
    // lifted in the light (they were flat ribbon and leaf shapes).
    final ramp = _greenRamp(k);
    _greenStem(
      spine,
      7,
      4,
      _time,
      ramp: ramp,
      n: 240,
      flow: k > 0.5 ? 0.25 : 0,
      seed: 31,
    );
    for (final (i, (u, side)) in const [
      (0.35, -1.0),
      (0.55, 1.0),
      (0.2, 1.0),
    ].indexed) {
      final p = spine[(u * 10).round()];
      _greenLeaf(
        p,
        34,
        -pi / 2 + side * (1.2 + 0.6 * bow),
        _time,
        ramp: ramp,
        n: 130,
        seed: 32 + i,
      );
    }
    _greenGrains.paint(canvas);
    _sigilNimbus(canvas, top, 62, k, _gSun, glyph: 'sun');
    const gold = Color(0xFFF0B83A);
    const ember = Color(0xFFC8561E);
    // Bowed, the petals hang smoked and close; lifted, they open out.
    final face = 0.45 + 0.55 * k;
    final open = 0.3 + 0.7 * k;
    for (var ring = 0; ring < 2; ring++) {
      final n = ring == 0 ? 16 : 12;
      final spin = (ring == 0 ? 1 : -1) * _time * 0.12 * k;
      for (var i = 0; i < n; i++) {
        final a = i * 2 * pi / n + spin + ring * 0.13;
        final hang = bow * 0.8;
        final dir = Offset(cos(a), sin(a) * face + hang);
        final ang = atan2(dir.dy, dir.dx);
        final len = (ring == 0 ? (i.isEven ? 36.0 : 28.0) : 20.0) * open;
        _glassPetal(
          canvas,
          top + Offset(cos(a), sin(a) * face) * 10,
          len,
          ang,
          len * 0.22,
          Color.lerp(
            const Color(0xFF5A4A2A),
            ring == 0 ? gold : const Color(0xFFFFE08A),
            k,
          )!,
          Color.lerp(const Color(0xFF3A2E1A), ember, k)!,
          flame: ring == 0 && i.isEven,
        );
      }
    }
    // The disc: the sun's sign, gold with its point.
    paintRondel(
      canvas,
      top,
      13,
      _kVerdantGlass,
      fill: Color.lerp(const Color(0xFF3A2614), gold, k),
      rim: 0.4 + 0.6 * k,
    );
    canvas.drawCircle(
      top,
      4.5,
      Paint()..color = Color.lerp(const Color(0xFF1E140A), Colors.white, k)!,
    );
    if (_fx.ready && k > 0) {
      drawGlow(canvas, _fx.glow!, top, 110, gold.withValues(alpha: 0.32 * k));
      drawGlow(
        canvas,
        _fx.glow!,
        top,
        26,
        Colors.white.withValues(alpha: 0.6 * k),
      );
    }
    _orbitMotes(canvas, top, 58, 5, const Color(0xFFFFE9A8), k, 0.5);
  }

  // ── The specimens' shared glass ─────────────────────────

  /// A petal of leaded glass in two facets — its lit half and its shadow
  /// half — held in a came with a lead midrib. [faceted] cuts it as a
  /// straight-edged shard (ice); [flame] gives it a flicking, waved edge.
  void _glassPetal(
    Canvas canvas,
    Offset base,
    double len,
    double a,
    double wide,
    Color lit,
    Color dark, {
    bool faceted = false,
    bool flame = false,
    double squash = 1,
  }) {
    if (len < 2) return;
    final d = Offset(cos(a), sin(a) * squash);
    final n = Offset(-sin(a), cos(a) * squash);
    final flick = flame ? 0.18 * sin(_time * 5 + a * 7) : 0.0;
    final tip = base + d * len + n * (len * flick);
    final mid = base + d * (len * (faceted ? 0.38 : 0.45));
    final left = mid + n * wide;
    final right = mid - n * wide;
    Path half(Offset side) {
      final p = Path()..moveTo(base.dx, base.dy);
      if (faceted) {
        p
          ..lineTo(side.dx, side.dy)
          ..lineTo(tip.dx, tip.dy);
      } else {
        p.quadraticBezierTo(side.dx, side.dy, tip.dx, tip.dy);
      }
      return p..close();
    }

    paintPaneFill(canvas, half(left), lit);
    paintPaneFill(canvas, half(right), dark);
    final whole = Path()..moveTo(base.dx, base.dy);
    if (faceted) {
      whole
        ..lineTo(left.dx, left.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(right.dx, right.dy);
    } else {
      whole
        ..quadraticBezierTo(left.dx, left.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(right.dx, right.dy, base.dx, base.dy);
    }
    whole.close();
    paintLead(canvas, whole, _kVerdantGlass, width: 1.8);
    paintLead(
      canvas,
      Path()
        ..moveTo(base.dx, base.dy)
        ..lineTo(tip.dx, tip.dy),
      _kVerdantGlass,
      width: 1.1,
    );
  }

  /// A shut bud of smoked glass: what a specimen is while its room is wrong.
  void _shutBud(
    Canvas canvas,
    Offset at,
    double r,
    Color tint, {
    double droop = 0,
  }) {
    for (var i = 0; i < 3; i++) {
      final a = -pi / 2 + (i - 1) * 0.42 + droop * 0.9;
      _glassPetal(
        canvas,
        at + Offset(cos(a + pi), sin(a + pi)) * r * 0.5,
        r * 1.9,
        a,
        r * 0.45,
        Color.lerp(_kVerdantGlass.smoke, tint, 0.55)!,
        Color.lerp(_kVerdantGlass.smoke, tint, 0.25)!,
      );
    }
  }

  /// The gold nimbus behind a specimen: a ring of filled, tapered filigree
  /// segments with studs between, and the element's sign at its heart. Dark
  /// carved gilt while the room is wrong; lit and slowly turning once healed.
  void _sigilNimbus(
    Canvas canvas,
    Offset c,
    double r,
    double k,
    Color tint, {
    required String glyph,
  }) {
    final gilt = Color.lerp(const Color(0xFF4A3E26), _kVerdantGlass.gold, k)!;
    final alpha = 0.35 + 0.6 * k;
    if (k > 0.05 && _fx.ready) {
      drawGlow(canvas, _fx.glow!, c, r * 1.5, tint.withValues(alpha: 0.18 * k));
    }
    final spin = _time * 0.15 * k;
    const segs = 12;
    for (var i = 0; i < segs; i++) {
      final a = spin + i * 2 * pi / segs;
      canvas.drawPath(
        vfxCrescent(c, r, 2.6 + 1.2 * k, a, 2 * pi / segs * 0.62),
        Paint()..color = gilt.withValues(alpha: alpha),
      );
      final g = a + pi / segs;
      canvas.drawPath(
        vfxShard(c + Offset(cos(g), sin(g)) * r, 4.5, 2.2, g),
        Paint()..color = gilt.withValues(alpha: alpha),
      );
      // Every third gap throws a ray outward.
      if (i % 3 == 0) {
        canvas.drawPath(
          vfxShard(c + Offset(cos(g), sin(g)) * (r + 10), 9 + 5 * k, 2.4, g),
          Paint()
            ..color = Color.lerp(gilt, tint, 0.4 * k)!.withValues(alpha: alpha),
        );
      }
    }
    // The sign, drawn in filled bands of gilt within the ring.
    final ink = Paint()..color = gilt.withValues(alpha: 0.55 + 0.35 * k);
    final gr = r * 0.62;
    switch (glyph) {
      case 'water':
        // ▽ — one point down, the sign of Water.
        final pts = [
          for (var i = 0; i < 3; i++)
            c +
                Offset(
                      cos(pi / 2 + i * 2 * pi / 3),
                      sin(pi / 2 + i * 2 * pi / 3),
                    ) *
                    gr,
        ];
        for (var i = 0; i < 3; i++) {
          canvas.drawPath(vfxRibbon([pts[i], pts[(i + 1) % 3]], 2.4, 2.4), ink);
        }
      case 'frost':
        // A six-armed star of frost, turning against the ring.
        for (var i = 0; i < 6; i++) {
          final a = -spin * 1.6 + i * pi / 3;
          canvas.drawPath(
            vfxShard(c + Offset(cos(a), sin(a)) * gr * 0.55, gr * 0.62, 2.6, a),
            ink,
          );
          final bud = c + Offset(cos(a), sin(a)) * gr * 0.62;
          for (final side in const [-1.0, 1.0]) {
            canvas.drawPath(vfxShard(bud, 7, 1.6, a + side * 0.8), ink);
          }
        }
      default:
        // ☉ is drawn by the bloom itself; the ring carries its rays.
        break;
    }
  }

  /// Small bright motes circling a specimen once it thrives.
  void _orbitMotes(
    Canvas canvas,
    Offset c,
    double r,
    int n,
    Color col,
    double k,
    double speed,
  ) {
    if (k <= 0.05) return;
    // Each mote a short comet of grains on its orbit, bright at the head
    // (2026-10-08; they were sprite dots with a white disc in each).
    for (var i = 0; i < n; i++) {
      final a = _time * speed + i * 2 * pi / n;
      final p = c + Offset(cos(a) * r, sin(a) * r * 0.45 - 4);
      final front = sin(a) > 0;
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.mote!,
          p,
          front ? 7 : 5,
          col.withValues(alpha: 0.6 * k),
        );
      }
      for (var j = 0; j < 14; j++) {
        final b = a - j * 0.035 * speed.sign;
        final b0 = b - 0.03 * speed.sign;
        final q = c + Offset(cos(b) * r, sin(b) * r * 0.45 - 4);
        final q0 = c + Offset(cos(b0) * r, sin(b0) * r * 0.45 - 4);
        final h = _greenHash(i * 41 + j);
        _greenGrains.add(
          q0.dx,
          q0.dy + (h - 0.5) * 2,
          q.dx,
          q.dy + (h - 0.5) * 2,
          j < 3 ? Colors.white : col,
          alpha: k * (1 - j / 14) * (front ? 1 : 0.7),
        );
      }
    }
    _greenGrains.paint(canvas);
  }

  // ─────────────────────────────────────────────────────────
  // THE HUB — THE GREAT PLANTER, THE CUTSCENE, THE GREY SEED
  // ─────────────────────────────────────────────────────────

  void _renderHub(Canvas canvas, DungeonRoom room, ConservatoryPlot g) {
    final c = g.greatPlanter!;
    final s = _green;
    // How far the great plant has risen: a banked star is a standing plant;
    // otherwise the cutscene's clock drives it.
    final rise = hasStar(0) && s.cutT < 0
        ? 1.0
        : s.cutT < 0
        ? 0.0
        : _ease((s.cutT - _kCutBind) / (_kCutRise - _kCutBind));
    final roots = hasStar(0) && s.cutT < 0
        ? 1.0
        : s.cutT < 0
        ? 0.0
        : _ease((s.cutT - (_kCutRise - 0.3)) / (_kCutPry - _kCutRise + 0.3));

    // The great planter: a wide carved basin with a three-pane collar — one
    // pane per wing, lit as that wing is healed. It is the hub's progress,
    // drawn where the result will stand.
    // The roots run UNDER the planter's rim and out across the floor.
    if (roots > 0) _drawPryRoots(canvas, room, c, roots);
    paintContactShadow(canvas, c + const Offset(0, 40), 260, 70);
    paintCarvedDisc(canvas, c, 118, 64, 24, _kVerdantGlass);
    for (final (i, cl) in Climate.values.indexed) {
      final a0 = -pi / 2 + i * 2 * pi / 3 + 0.06;
      final a1 = a0 + 2 * pi / 3 - 0.12;
      final on = greenhouse.healed.contains(cl);
      final tint = _paneTint(climateFix(cl));
      paintPane(
        canvas,
        ellipseSectorPath(c, 92, 50, 116, 63, a0, a1),
        on ? tint : Color.lerp(_kVerdantGlass.frostAt(i), tint, 0.25)!,
        _kVerdantGlass,
        lead: 3,
      );
      if (on) {
        paintStreak(
          canvas,
          Rect.fromCircle(
            center:
                c + Offset(cos((a0 + a1) / 2) * 104, sin((a0 + a1) / 2) * 56),
            radius: 10,
          ),
          opacity: 0.6,
        );
      }
    }
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 184, height: 100),
      Paint()..color = rise > 0 ? _gSoilWet : const Color(0xFF3E3224),
    );

    // The three channels to the seed planter (always carved; filled once the
    // great plant stands, drawn back one by one for the maxim).
    final seedAt = g.seedPlanter;
    if (seedAt != null) _renderSeedChannels(canvas, c, seedAt, rise);

    // The cutscene's motes and bind.
    if (s.cutT >= 0 && s.cutT < _kCutBind + 0.6) _renderMotes(canvas, room, c);

    if (rise > 0) _drawGreatPlant(canvas, c, rise);

    if (seedAt != null) _renderSeedPlanter(canvas, seedAt);
  }

  /// Three motes, one per wing's colour, fly in through the wing doors, then
  /// wind round each other over the planter and bind (the Rite-of-Three's
  /// thread-and-bind, re-aimed at the planter).
  void _renderMotes(Canvas canvas, DungeonRoom room, Offset c) {
    final t = _green.cutT;
    final wings = <ClimateWing>[
      for (final id in kConservatoryWingRooms.keys)
        if (layout.rooms[id]?.grove?.wing != null)
          layout.rooms[id]!.grove!.wing!,
    ];
    final heads = <Offset>[];
    final cols = <Color>[];
    for (final (i, w) in wings.indexed) {
      final col = _paneTint(climateFix(w.climate));
      final fly = _ease(t / _kCutMotes);
      final spin = t > _kCutMotes ? (t - _kCutMotes) * 5 : 0.0;
      final orbit =
          70 * (1 - _ease((t - _kCutMotes) / (_kCutBind - _kCutMotes)));
      final home =
          c +
          Offset(
                cos(i * 2 * pi / 3 + spin),
                sin(i * 2 * pi / 3 + spin) * 0.55,
              ) *
              orbit -
          const Offset(0, 30);
      // A curve in from the door, bowing toward the room's middle.
      final ctrl = Offset.lerp(w.hubDoor, c, 0.5)! + const Offset(0, -140);
      final p = Offset.lerp(
        Offset.lerp(w.hubDoor, ctrl, fly)!,
        Offset.lerp(ctrl, home, fly)!,
        fly,
      )!;
      heads.add(p);
      cols.add(col);
      // Its trail: a tapered ribbon of its colour back along the curve.
      final trail = [
        for (var k = 0; k <= 8; k++)
          () {
            final u = max(0.0, fly - k * 0.03);
            return Offset.lerp(
              Offset.lerp(w.hubDoor, ctrl, u)!,
              Offset.lerp(ctrl, home, u)!,
              u,
            )!;
          }(),
      ];
      if (t < _kCutMotes + 0.2) {
        canvas.drawPath(
          vfxRibbon(trail, 7, 0.5),
          Paint()..color = col.withValues(alpha: 0.55),
        );
      }
    }
    // The bind: tapered threads between the heads, thickening as they meet.
    if (t > _kCutMotes - 0.3) {
      final k = _ease(
        (t - (_kCutMotes - 0.3)) / (_kCutBind - _kCutMotes + 0.3),
      );
      for (var i = 0; i < heads.length; i++) {
        final a = heads[i], b = heads[(i + 1) % heads.length];
        final mid = Offset.lerp(a, b, 0.5)! + Offset(0, -12 * sin(t * 6 + i));
        canvas.drawPath(
          vfxRibbon([a, mid, b], 1 + 5 * k, 1 + 5 * k),
          Paint()
            ..color = Color.lerp(
              cols[i],
              cols[(i + 1) % cols.length],
              0.5,
            )!.withValues(alpha: 0.35 + 0.4 * k),
        );
      }
    }
    for (final (i, p) in heads.indexed) {
      canvas.drawPath(
        vfxBlob(p, 9, i * 4.0 + t, n: 9, wobble: 0.14),
        Paint()..color = cols[i],
      );
      canvas.drawCircle(p, 4, Paint()..color = _kVerdantGlass.liveCore);
      if (_fx.ready) {
        drawGlow(canvas, _fx.glow!, p, 46, cols[i].withValues(alpha: 0.55));
      }
    }
    // The flash on the bind.
    if (t > _kCutBind - 0.15 && _fx.ready) {
      final f = 1 - ((t - (_kCutBind - 0.15)) / 0.75).clamp(0.0, 1.0);
      drawGlow(
        canvas,
        _fx.glow!,
        c - const Offset(0, 30),
        200,
        _kVerdantGlass.liveCore.withValues(alpha: 0.7 * f),
      );
    }
  }

  /// THE GREAT PLANT: three strands — one of each wing's growth — braided
  /// into one trunk that rises out of the planter, opens a crown of leaves
  /// over it, and keeps a slow green heart-light in the braid.
  void _drawGreatPlant(Canvas canvas, Offset c, double rise) {
    final height = 190 * rise;
    final base = c + const Offset(0, -6);
    final tints = [_gMossLit, _gIce, _gSun];
    // The braid.
    for (var s = 0; s < 3; s++) {
      final spine = <Offset>[
        for (var k = 0; k <= 14; k++)
          () {
            final u = k / 14;
            final twist = u * pi * 3 + s * 2 * pi / 3;
            final w = 22 * (1 - u * 0.6);
            return base + Offset(sin(twist) * w, -u * height);
          }(),
      ];
      // Dark wood, each strand lit only along one edge in its wing's
      // colour (2026-10-08; a flat brown ribbon with a broad pale stripe).
      canvas.drawPath(
        vfxRibbon(spine, 13, 5),
        Paint()..color = Color.lerp(const Color(0xFF1E1812), tints[s], 0.12)!,
      );
      canvas.drawPath(
        vfxRibbon(
          [for (final p in spine) p + const Offset(-3.5, -1)],
          1.6,
          0.8,
        ),
        Paint()
          ..color = Color.lerp(
            _gBarkLit,
            tints[s],
            0.5,
          )!.withValues(alpha: 0.75),
      );
    }
    // The crown: leaf clusters opening outward from the top as it rises.
    final crownK = _ease((rise - 0.45) / 0.55);
    if (crownK > 0) {
      final top = base - Offset(0, height);
      // The canopy's body: a faint soft green the leaf grains sit in.
      canvas.drawOval(
        Rect.fromCenter(center: top, width: 300 * crownK, height: 190 * crownK),
        Paint()
          ..shader = ui.Gradient.radial(top, 150 * crownK + 1, [
            _gMossLit.withValues(alpha: 0.10 * crownK),
            _gMossLit.withValues(alpha: 0),
          ]),
      );
      if (crownK >= 0.999) {
        // Standing: the whole crown is one built shape of ~3,800 grains,
        // stirring in place — no per-frame building (grain_cloud.dart).
        paintGrainShape(
          canvas,
          _greenCrown ??= _buildGreenCrown(),
          _time,
          origin: top,
          drift: 1.1,
          ramp: _kGreenCrownRamp,
          glint: 0.006,
          width: 1.7,
          trail: 0.035,
        );
      }
      for (var ring = 0; ring < 3 && crownK < 0.999; ring++) {
        final n = 10 + ring * 4;
        final rad = (40 + ring * 34) * crownK;
        for (var i = 0; i < n; i++) {
          final a =
              i * 2 * pi / n +
              ring * 0.4 +
              _sway(_time, i + ring * 7.0, 0.6) * 0.03;
          final p = top + Offset(cos(a) * rad, sin(a) * rad * 0.62);
          final len = (26 + ring * 6) * crownK;
          // Leaves of grains (2026-10-08; they were flat leaf shapes): the
          // inner ring in shade, the outer catching the light.
          _greenLeaf(
            p,
            len,
            a + 0.2 * _sway(_time, i.toDouble(), 0.9),
            _time,
            ramp: ring == 0
                ? _kGreenShadeRamp
                : (ring == 1 ? _kGreenLiveRamp : _kGreenSunlitRamp),
            n: 70,
            stir: 0.8,
            seed: 300 + ring * 40 + i,
          );
        }
      }
      _greenGrains.paint(canvas);
      // THE KEY. Twigs in the shape of the door's roots, and on them seven
      // buds — shut until the Bud Star, then flowering, knot first, into the
      // very states the door wants, drawn with the door's own buds.
      _drawCrownKey(canvas, top, crownK);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          top,
          150,
          _kVerdantGlass.live.withValues(
            alpha: (0.10 + 0.04 * sin(_time * 1.3)) * crownK,
          ),
        );
        drawGlow(
          canvas,
          _fx.glow!,
          base - Offset(0, height * 0.5),
          60,
          _gMossLit.withValues(alpha: 0.18 * rise),
        );
      }
    }
  }

  /// Where the door's bud [n] sits in the great plant's crown.
  Offset _crownPos(Offset top, String n) {
    final p = kRootAt[n]!;
    return top + Offset((p.dx - 450) * 0.44, -74 + (p.dy - 118) * 0.62);
  }

  void _drawCrownKey(Canvas canvas, Offset top, double crownK) {
    for (final e in kRootParent.entries) {
      final a = _crownPos(top, e.value), b = _crownPos(top, e.key);
      canvas.drawPath(
        vfxRibbon([a, Offset.lerp(a, b, 0.5)! + const Offset(0, 4), b], 8, 5),
        Paint()..color = _gBark.withValues(alpha: crownK),
      );
      canvas.drawPath(
        vfxRibbon([a, b], 1.3, 0.8).shift(const Offset(-2.5, -2.5)),
        Paint()..color = _gBarkLit.withValues(alpha: 0.7 * crownK),
      );
    }
    final flowered = hasStar(1);
    final t = _green.crownBloomT < 0 ? 99.0 : _green.crownBloomT;
    for (final (i, n) in kRootNodes.indexed) {
      final at = _crownPos(top, n);
      final k = flowered ? ((t - 0.3 - i * 0.28) / 0.55).clamp(0.0, 1.0) : 0.0;
      if (k <= 0) {
        _drawRootBud(canvas, at, RootState.dry, 0.8 * crownK);
        continue;
      }
      // Each is SET in the crown like a jewel: a dark leaded cup behind it,
      // so its colour reads against the leaves from across the hub.
      paintRondel(
        canvas,
        at,
        (n == 'K' ? 21 : 17) * crownK * Curves.easeOut.transform(k),
        _kVerdantGlass,
        fill: const Color(0xFF0C120C),
        rim: 0.9,
      );

      final pop = Curves.easeOutBack.transform(k);
      _drawRootBud(canvas, at, kRootTarget[n]!, (n == 'K' ? 1.15 : 0.95) * pop);
      if (k < 1 && _fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          at,
          40,
          _rootColour(kRootTarget[n]!).withValues(alpha: 0.6 * (1 - k)),
        );
      }
    }
  }

  /// The great plant's roots running over the floor to the north door, and
  /// prising it.
  void _drawPryRoots(Canvas canvas, DungeonRoom room, Offset c, double k) {
    DungeonDoor? north;
    for (final d in room.doors) {
      if (d.targetRoomId == 'trellis_garden') north = d;
    }
    if (north == null) return;
    final door = north.rect;
    for (var i = 0; i < 3; i++) {
      final to = Offset(door.left + 18 + i * 37, door.bottom + 8);
      final from = c + Offset(-70 + i * 70, -46 + (i == 1 ? -12 : 0));
      final ctrl = Offset.lerp(from, to, 0.5)! + Offset(-70 + i * 70, 0);
      final n = 16;
      final upto = (k * n).floor();
      final spine = <Offset>[
        for (var j = 0; j <= upto; j++)
          () {
            final u = j / n;
            // A root wanders: a slow sideways wave along its run.
            return Offset.lerp(
                  Offset.lerp(from, ctrl, u)!,
                  Offset.lerp(ctrl, to, u)!,
                  u,
                )! +
                Offset(9 * sin(u * pi * 3 + i * 1.7), 0);
          }(),
      ];
      if (spine.length < 2) continue;
      canvas.drawPath(
        vfxRibbon(spine, 18, 7).shift(const Offset(3, 6)),
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.28),
      );
      canvas.drawPath(vfxRibbon(spine, 18, 7), Paint()..color = _gBark);
      canvas.drawPath(
        vfxRibbon([for (final p in spine) p + const Offset(-5.5, -3)], 2, 1),
        Paint()..color = _gBarkLit.withValues(alpha: 0.75),
      );
      // Rootlets gripping the floor along it.
      for (var j = 4; j < spine.length - 1; j += 4) {
        final d = spine[j + 1] - spine[j - 1];
        final a = atan2(d.dy, d.dx) + (j.isEven ? 1.3 : -1.3);
        canvas.drawPath(
          vfxRibbon([spine[j], spine[j] + Offset(cos(a), sin(a)) * 16], 4, 0.5),
          Paint()..color = _gBark,
        );
      }
    }
  }

  // ── The grey seed ───────────────────────────────────────

  /// Three glass-lined channels from the great planter to the seed's:
  /// moisture (Water's blue), light (Crystal's), frost (Spirit's). Filled once
  /// the great plant stands; each drawn back runs dry, the colour flowing
  /// AWAY from the seed.
  void _renderSeedChannels(Canvas canvas, Offset from, Offset to, double rise) {
    final showSeed = _greySeedPlanted;
    final a = _activeCreature;
    final found = discoveredClouds.contains(kPlantOppositeSeedEggId);
    // The carved channel all three lanes run in, laid first.
    {
      final start = from + const Offset(96, 36);
      final end = to + const Offset(-44, 0);
      final ctrl = Offset.lerp(start, end, 0.5)! + const Offset(0, 44);
      final bed = [
        for (var k = 0; k <= 16; k++)
          () {
            final u = k / 16;
            return Offset.lerp(
              Offset.lerp(start, ctrl, u)!,
              Offset.lerp(ctrl, end, u)!,
              u,
            )!;
          }(),
      ];
      canvas.drawPath(
        vfxRibbon(bed, 34, 30).shift(const Offset(0, 3)),
        Paint()..color = _kVerdantGlass.stoneTop.withValues(alpha: 0.5),
      );
      canvas.drawPath(
        vfxRibbon(bed, 30, 26),
        Paint()..color = _kVerdantGlass.stoneFoot.withValues(alpha: 0.95),
      );
    }
    for (final (i, ch) in SeedChannel.values.indexed) {
      final off = (i - 1) * 8.5;
      final start = from + Offset(96, 36 + off);
      final end = to + Offset(-44, off);
      final ctrl = Offset.lerp(start, end, 0.5)! + Offset(0, 44 + off * 0.2);
      final spine = [
        for (var k = 0; k <= 16; k++)
          () {
            final u = k / 16;
            return Offset.lerp(
              Offset.lerp(start, ctrl, u)!,
              Offset.lerp(ctrl, end, u)!,
              u,
            )!;
          }(),
      ];
      final tint = Color.lerp(
        _paneTint(seedChannelElement(ch)),
        _kVerdantGlass.frostAt(i),
        0.35,
      )!;
      final drawnT = _green.drawn[ch];
      // How much is still in it: full when the plant stands, draining from
      // the seed's end back toward the great plant once drawn.
      final fill = found
          ? 0.0
          : rise * (drawnT == null ? 1.0 : 1 - _ease(drawnT / 1.4));
      if (fill > 0.01) {
        final keep = (spine.length * fill).ceil().clamp(2, spine.length);
        final run = spine.sublist(0, keep);
        canvas.drawPath(
          vfxRibbon(run, 6, 6),
          Paint()..color = tint.withValues(alpha: 0.85),
        );
        // The flow: small bright beads travelling toward the seed.
        for (var k = 0; k < 3; k++) {
          final u = ((_time * 0.35 + k / 3 + i * 0.2) % 1.0) * fill;
          final idx = (u * (spine.length - 1)).floor();
          canvas.drawCircle(
            spine[idx],
            2.2,
            Paint()..color = _kVerdantGlass.liveCore.withValues(alpha: 0.8),
          );
        }
      }
      // PREVIEW: the matching creature beside the seed sees its channel
      // begin to flow the other way — a ghost of drawing it back.
      if (showSeed &&
          drawnT == null &&
          a != null &&
          a.member.element == seedChannelElement(ch) &&
          (a.position - to).distance <= 100 &&
          !discoveredClouds.contains(kPlantOppositeSeedEggId)) {
        for (var k = 0; k < 5; k++) {
          final u = 1 - ((_time * 0.6 + k / 5) % 1.0);
          final idx = (u * (spine.length - 1)).floor();
          canvas.drawPath(
            vfxDrop(
              spine[idx],
              4,
              atan2(
                spine[max(0, idx - 1)].dy - spine[idx].dy,
                spine[max(0, idx - 1)].dx - spine[idx].dx,
              ),
            ),
            Paint()..color = _kVerdantGlass.liveCore.withValues(alpha: 0.7),
          );
        }
      }
      // Each channel's return bears its creature's pane at the seed end.
      final paneAt = spine[spine.length - 3];
      paintRondel(
        canvas,
        paneAt,
        7,
        _kVerdantGlass,
        fill: drawnT != null || found ? _kVerdantGlass.smoke : tint,
        rim: 0.8,
        lead: 2,
      );
    }
  }

  DungeonCreature? get _activeCreature => active;

  void _renderSeedPlanter(Canvas canvas, Offset at) {
    final s = _green;
    final planted = _greySeedPlanted;
    _drawPlanter(canvas, at, _kVerdantGlass.goldDeep, false, r: 40);
    if (!planted) return;
    // The seed falls in from above on the frame the bud opens.
    final drop = s.seedDropT < 0 ? 1.0 : _easeOut(s.seedDropT / 1.2);
    final p = at + Offset(0, -6 - 220 * (1 - drop));
    final bloom = s.seedBloom < 0 ? 0.0 : _ease(s.seedBloom / 3.2);
    final leaves = s.drawn.length;
    // Its curled leaves relax one per channel drawn back.
    for (var i = 0; i < 3; i++) {
      final relaxed = i < leaves
          ? _ease((s.drawn.values.elementAt(i)) / 1.6)
          : 0.0;
      final a = -pi / 2 + (i - 1) * 0.9;
      final len = 12 + 16 * relaxed;
      final curl = (1 - relaxed) * 1.4;
      // Leaves of grains, ash-grey curled and slate as they relax (they
      // were flat grey leaf shapes).
      final col = Color.lerp(_gGrey, const Color(0xFF5E5A6E), relaxed)!;
      _greenLeaf(
        p,
        len,
        a + curl * (i - 1 == 0 ? 0.6 : (i - 1).toDouble()),
        _time,
        ramp: grainRampFrom(col),
        n: 44,
        stir: 0.4,
        seed: 800 + i,
      );
    }
    _greenGrains.paint(canvas);
    canvas.drawPath(
      vfxBlob(p, 9, 2.2, n: 9, wobble: 0.1, squash: 0.8),
      Paint()..color = Color.lerp(_gGrey, const Color(0xFF3A2E48), bloom)!,
    );
    if (bloom > 0) {
      // THE OPPOSITE FLOWER: dark-petalled, amber-hearted, thriving in the
      // dry, the warm and the shade. It stands on every later descent.
      // Its petals are grains too, dark violet and rose (2026-10-08; they
      // were flat leaf shapes).
      for (var ring = 0; ring < 2; ring++) {
        for (var i = 0; i < 7; i++) {
          final a =
              i * 2 * pi / 7 +
              ring * 0.45 +
              _sway(_time, i.toDouble(), 0.5) * 0.04;
          _greenLeaf(
            p,
            (34 - ring * 11) * bloom,
            a,
            _time,
            ramp: ring == 0 ? _kGreenNightRamp : _kGreenRoseRamp,
            n: ring == 0 ? 60 : 40,
            stir: 0.5,
            seed: 820 + ring * 10 + i,
          );
        }
      }
      _greenGrains.paint(canvas);
      canvas.drawCircle(p, 7 * bloom, Paint()..color = _gHeat);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          p,
          60,
          const Color(0xFFB07A4A).withValues(alpha: 0.2 * bloom),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // STAR 2 — THE TRELLIS GARDEN
  // ─────────────────────────────────────────────────────────

  /// THE PARTERRE, baked: a garden sunk a step into the walkway, its kerb laid
  /// stone by stone; tilled beds in furrows behind brick edging; loam and moss
  /// between them; and a real pond — a rock rim, lily pads, reeds, a mossy
  /// island — where the rule's water is.
  ui.Picture _trellisBase(
    DungeonRoom room,
  ) => _greenCache.putIfAbsent('trellis|${room.id}', () {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final board = kTrellisBoard;
    var seed = 23;
    double rnd() {
      seed = (seed * 1103515245 + 12345) & 0x3FFFFFFF;
      return (seed >> 8) / 0x3FFFFF;
    }

    // The ground: dark loam, cool at the edges where the kerb shades it.
    c.drawRect(board, Paint()..color = const Color(0xFF23271C));
    c.drawRect(
      board,
      Paint()
        ..shader = ui.Gradient.radial(board.center, board.longestSide * 0.62, [
          const Color(0xFF363A2A).withValues(alpha: 0.9),
          const Color(0xFF15180F).withValues(alpha: 0.0),
        ]),
    );
    c.save();
    c.clipRect(board);
    // GRAINS AND DARK STONE (2026-10-08). The ground's moss was flat green
    // blobs and its gravel seventy pale pebbles — a cartoon garden bed. The
    // moss is clumps of grains now, and the gravel half as much, dark, each
    // stone lit only along its top.
    final moss = _GreenBake(const [
      Color(0xFF1F2E19),
      Color(0xFF2F4226),
      Color(0xFF465C30),
      Color(0xFF6A8448),
    ]);
    for (var i = 0; i < 46; i++) {
      final p = Offset(
        board.left + rnd() * board.width,
        board.top + rnd() * board.height,
      );
      final r = 10 + rnd() * 22;
      moss.clump(p, r, (r * 13).round(), rnd);
    }
    moss.paint(c, alpha: 0.85);
    for (var i = 0; i < 70; i++) {
      final p = Offset(
        board.left + rnd() * board.width,
        board.top + rnd() * board.height,
      );
      final r = 2 + rnd() * 3.5;
      final sd = rnd() * 99;
      final tone = rnd();
      if (i.isOdd) continue;
      c.drawPath(
        vfxBlob(p + const Offset(0, 1), r, sd, n: 6),
        Paint()..color = const Color(0xFF0A0C08).withValues(alpha: 0.6),
      );
      c.drawPath(
        vfxBlob(p, r, sd, n: 6),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF22241C),
            const Color(0xFF34362A),
            tone,
          )!,
      );
      c.drawArc(
        Rect.fromCircle(center: p, radius: r * 0.8),
        pi + 0.5,
        pi - 1.0,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = _kVerdantGlass.leadLight.withValues(alpha: 0.18),
      );
    }
    // The kerb's shadow falling inward along the north and west: the
    // board is SUNK a step.
    c.drawRect(
      Rect.fromLTWH(board.left, board.top, board.width, 28),
      Paint()
        ..shader = ui.Gradient.linear(
          board.topLeft,
          board.topLeft + const Offset(0, 28),
          [
            const Color(0xFF000000).withValues(alpha: 0.5),
            const Color(0xFF000000).withValues(alpha: 0),
          ],
        ),
    );
    c.drawRect(
      Rect.fromLTWH(board.left, board.top, 28, board.height),
      Paint()
        ..shader = ui.Gradient.linear(
          board.topLeft,
          board.topLeft + const Offset(28, 0),
          [
            const Color(0xFF000000).withValues(alpha: 0.45),
            const Color(0xFF000000).withValues(alpha: 0),
          ],
        ),
    );
    // Fern tufts in the plain ground, as fronds of grains (they were flat
    // green leaf shapes).
    final fern = _GreenBake(const [
      Color(0xFF1E3019),
      Color(0xFF2E4A26),
      Color(0xFF4A6A34),
      Color(0xFF7A9A54),
    ]);
    for (final cell in const [
      (0, 0),
      (1, 1),
      (2, 0),
      (3, 1),
      (0, 4),
      (4, 4),
      (6, 4),
      (2, 2),
    ]) {
      final at =
          trellisCellCentre(cell) + Offset(rnd() * 24 - 12, rnd() * 20 - 10);
      for (var k = 0; k < 7; k++) {
        final a = -pi / 2 + (k - 3) * 0.42 + (rnd() - 0.5) * 0.2;
        final len = 16 + rnd() * 10;
        rnd();
        fern.leaf(at, len, a, (len * 2.2).round(), rnd);
      }
    }
    fern.paint(c);
    c.restore();

    // The kerb, stone by stone.
    void kerbRun(Offset from, Offset to, bool horizontal) {
      final len = (to - from).distance;
      var x = 0.0;
      while (x < len) {
        final w = min(len - x, 40 + rnd() * 18);
        final r = horizontal
            ? Rect.fromLTWH(from.dx + x, from.dy - 7, w - 3, 14)
            : Rect.fromLTWH(from.dx - 7, from.dy + x, 14, w - 3);
        paintCarvedBlock(
          c,
          r,
          5,
          _kVerdantGlass,
          radius: 3,
          topColor: Color.lerp(
            _kVerdantGlass.stoneFace,
            _kVerdantGlass.stoneTop,
            0.3 + rnd() * 0.3,
          ),
        );
        x += w;
      }
    }

    kerbRun(board.topLeft, board.topRight, true);
    kerbRun(board.bottomLeft, board.bottomRight, true);
    kerbRun(board.topLeft, board.bottomLeft, false);
    kerbRun(board.topRight, board.bottomRight, false);

    // THE BEDS: a band of brick edging, then tilled soil in furrows.
    final edge = _trellisBedPath(inset: 5);
    final beds = _trellisBedPath();
    c.drawPath(
      edge.shift(const Offset(0, 3)),
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.4),
    );
    c.drawPath(edge, Paint()..color = const Color(0xFF6A4A34));
    c.save();
    c.clipPath(edge);
    // Brick joints: short dark gaps across the band.
    for (var x = board.left; x < board.right; x += 19) {
      c.drawRect(
        Rect.fromLTWH(x, board.top, 2.2, board.height),
        Paint()..color = const Color(0xFF2A1C12).withValues(alpha: 0.8),
      );
    }
    for (var y = board.top; y < board.bottom; y += 19) {
      c.drawRect(
        Rect.fromLTWH(board.left, y, board.width, 2.2),
        Paint()..color = const Color(0xFF2A1C12).withValues(alpha: 0.8),
      );
    }
    c.restore();
    c.drawPath(beds, Paint()..color = const Color(0xFF5E4830));
    c.save();
    c.clipPath(beds);
    // Furrows along each run: a dark trough and a lit ridge, repeated.
    final fork = trellisCellCentre(kTrellisFork);
    for (var k = -3; k <= 3; k++) {
      final y = fork.dy + k * 11.0;
      c.drawRect(
        Rect.fromLTRB(board.left, y - 2.5, board.right, y + 2.5),
        Paint()..color = const Color(0xFF3A2A1A).withValues(alpha: 0.75),
      );
      c.drawRect(
        Rect.fromLTRB(board.left, y + 2.5, board.right, y + 5),
        Paint()..color = const Color(0xFF8A6E48).withValues(alpha: 0.45),
      );
    }
    c.restore();
    // The root approach runs north-south, so its furrows do too.
    c.save();
    c.clipPath(
      Path()..addRect(
        Rect.fromPoints(
          trellisCellCentre(kTrellisRoot),
          trellisCellCentre(kTrellisFork),
        ).inflate(kTrellisTile / 2 - 14).translate(0, 22),
      ),
    );
    c.clipPath(beds);
    c.drawRect(
      Rect.fromCenter(
        center: trellisCellCentre(kTrellisRoot),
        width: 80,
        height: 130,
      ),
      Paint()..color = const Color(0xFF5E4830),
    );
    final rx = trellisCellCentre(kTrellisRoot).dx;
    for (var k = -3; k <= 3; k++) {
      final x = rx + k * 11.0;
      c.drawRect(
        Rect.fromLTRB(x - 2.5, board.top, x + 2.5, board.bottom),
        Paint()..color = const Color(0xFF3A2A1A).withValues(alpha: 0.75),
      );
      c.drawRect(
        Rect.fromLTRB(x + 2.5, board.top, x + 5, board.bottom),
        Paint()..color = const Color(0xFF8A6E48).withValues(alpha: 0.45),
      );
    }
    c.restore();

    // The west bed's stone end: a carved lid.
    final lid = kTrellisHatch;
    paintCarvedBlock(c, lid.deflate(4), 6, _kVerdantGlass, radius: 5);

    // THE POND.
    final pc = trellisCellCentre(kTrellisIsland);
    final pond = _trellisPondPath();
    c.drawPath(
      pond,
      Paint()
        ..shader = ui.Gradient.radial(
          pc,
          150,
          [
            const Color(0xFF0B1F28),
            const Color(0xFF143440),
            const Color(0xFF2A5A62),
          ],
          const [0.0, 0.72, 1.0],
        ),
    );
    // Weed in the shallows.
    c.save();
    c.clipPath(pond);
    for (var i = 0; i < 26; i++) {
      final a = rnd() * 2 * pi;
      final p = pc + Offset(cos(a), sin(a)) * (108 + rnd() * 24);
      c.drawPath(
        vfxBlob(p, 8 + rnd() * 10, rnd() * 99, n: 8, wobble: 0.3),
        Paint()..color = const Color(0xFF2E4A30).withValues(alpha: 0.45),
      );
    }
    c.restore();
    // The rim: a ring of rounded stones, and boulders filling the
    // basin's corners.
    for (var i = 0; i < 30; i++) {
      final a = i * 2 * pi / 30 + rnd() * 0.08;
      final p = pc + Offset(cos(a), sin(a)) * (134 + rnd() * 6);
      // Leave the east bed's crossing lane open to the water.
      if (p.dy > 370 && (p.dx - pc.dx).abs() < 40) continue;
      final r = 9 + rnd() * 6;
      final sd = rnd() * 99;
      c.drawPath(
        vfxBlob(p + const Offset(0, 3), r, sd, n: 8, wobble: 0.18),
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.4),
      );
      // Dark stone, lit only across its crown (it was a pale gradient
      // pebble, a cartoon cobble).
      c.drawPath(
        vfxBlob(p, r, sd, n: 8, wobble: 0.18),
        Paint()
          ..shader = ui.Gradient.linear(p - Offset(0, r), p + Offset(0, r), [
            Color.lerp(_kVerdantGlass.stoneFace, _kVerdantGlass.stoneTop, 0.3)!,
            _kVerdantGlass.stoneFoot,
          ]),
      );
      c.drawArc(
        Rect.fromCircle(center: p, radius: r * 0.82),
        pi + 0.55,
        pi - 1.1,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round
          ..color = _kVerdantGlass.leadLight.withValues(alpha: 0.22),
      );
    }
    // Moss on the boulders' crowns, in grains.
    final caps = _GreenBake(const [
      Color(0xFF243A1E),
      Color(0xFF3A5428),
      Color(0xFF4E6A34),
      Color(0xFF7A9450),
    ]);
    for (final corner in const [
      Offset(534, 136),
      Offset(778, 136),
      Offset(778, 380),
      Offset(532, 382),
    ]) {
      for (var k = 0; k < 3; k++) {
        final p = corner + Offset(rnd() * 16 - 8, rnd() * 16 - 8);
        final r = 12 + rnd() * 8;
        final sd = rnd() * 99;
        c.drawPath(
          vfxBlob(p + const Offset(0, 4), r, sd, n: 8, wobble: 0.2),
          Paint()..color = const Color(0xFF000000).withValues(alpha: 0.45),
        );
        c.drawPath(
          vfxBlob(p, r, sd, n: 8, wobble: 0.2),
          Paint()
            ..shader = ui.Gradient.linear(p - Offset(0, r), p + Offset(0, r), [
              Color.lerp(
                _kVerdantGlass.stoneFace,
                _kVerdantGlass.stoneTop,
                0.3,
              )!,
              _kVerdantGlass.stoneFoot,
            ]),
        );
        c.drawArc(
          Rect.fromCircle(center: p, radius: r * 0.84),
          pi + 0.5,
          pi - 1.0,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..strokeCap = StrokeCap.round
            ..color = _kVerdantGlass.leadLight.withValues(alpha: 0.2),
        );
        caps.clump(p - Offset(0, r * 0.35), r * 0.62, (r * 4).round(), rnd);
      }
    }
    caps.paint(c);
    // Reeds.
    for (final at in const [
      Offset(548, 330),
      Offset(768, 170),
      Offset(560, 160),
    ]) {
      // Blades of grains standing out of the water (they were flat leaves).
      final reeds = _GreenBake(const [
        Color(0xFF223619),
        Color(0xFF34502A),
        Color(0xFF55703A),
        Color(0xFF8A9E58),
      ]);
      for (var k = 0; k < 9; k++) {
        final a = -pi / 2 + (k - 4) * 0.13 + (rnd() - 0.5) * 0.1;
        final len = 34 + rnd() * 16;
        rnd();
        reeds.leaf(
          at + Offset(k * 3.0 - 12, 0),
          len,
          a,
          (len * 1.6).round(),
          rnd,
        );
      }
      reeds.paint(c);
    }
    // Lily pads, clear of the crossing lane and the island.
    for (final (at, r, flower) in const [
      (Offset(572, 196), 15.0, true),
      (Offset(742, 206), 13.0, false),
      (Offset(586, 320), 12.0, false),
      (Offset(746, 318), 16.0, true),
      (Offset(706, 150), 11.0, false),
    ]) {
      final notch = at.dx * 0.1;
      final pad = Path()
        ..moveTo(at.dx, at.dy)
        ..arcTo(
          Rect.fromCircle(center: at, radius: r),
          notch + 0.3,
          2 * pi - 0.6,
          false,
        )
        ..close();
      // DARK ON DARK WATER (2026-10-08): the pad near-black green, its
      // rim catching the light, and the flower a small knot of pale grains
      // round a warm heart. They were bright green discs with white
      // asterisk flowers — a sticker on a pond.
      c.drawPath(
        pad.shift(const Offset(0, 2)),
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.35),
      );
      c.drawPath(pad, Paint()..color = const Color(0xFF1C3018));
      c.drawArc(
        Rect.fromCircle(center: at, radius: r - 0.8),
        notch + 0.35,
        2 * pi - 0.7,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF6A9448).withValues(alpha: 0.45),
      );
      if (flower) {
        final bloom = _GreenBake(const [
          Color(0xFF8A7A84),
          Color(0xFFC8B8C2),
          Color(0xFFF2E6EC),
          Color(0xFFFFFFFF),
        ]);
        final fc = at + const Offset(3, -2);
        for (var k = 0; k < 6; k++) {
          bloom.leaf(fc, 7, k * pi / 3 + 0.2, 10, rnd);
        }
        bloom.paint(c, width: 1.5);
        c.drawCircle(fc, 1.6, Paint()..color = _gSun);
      }
    }
    // The island: a mossy rock with its roots trailing into the water.
    for (var k = 0; k < 5; k++) {
      final a = k * 2 * pi / 5 + 0.4;
      final from = pc + Offset(cos(a) * 30, sin(a) * 22);
      final to = pc + Offset(cos(a) * 56, sin(a) * 44);
      c.drawPath(
        vfxRibbon(
          [from, Offset.lerp(from, to, 0.5)! + const Offset(4, 3), to],
          5,
          1,
        ),
        Paint()..color = _gBark.withValues(alpha: 0.8),
      );
    }
    c.drawPath(
      vfxBlob(pc + const Offset(0, 6), 44, 3.3, n: 12, wobble: 0.1),
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.45),
    );
    c.drawPath(
      vfxBlob(pc, 42, 3.3, n: 12, wobble: 0.1),
      Paint()
        ..shader = ui.Gradient.linear(
          pc - const Offset(0, 42),
          pc + const Offset(0, 42),
          [
            Color.lerp(
              _kVerdantGlass.stoneFace,
              _kVerdantGlass.stoneTop,
              0.35,
            )!,
            _kVerdantGlass.stoneFoot,
          ],
        ),
    );
    // Its moss: a dark mat, and grains thickening on the crown (it was a
    // flat green disc with ten paler blobs on it).
    c.drawPath(
      vfxBlob(pc - const Offset(0, 6), 34, 4.1, n: 12, wobble: 0.16),
      Paint()..color = const Color(0xFF1E2E18),
    );
    final crown = _GreenBake(const [
      Color(0xFF243A1E),
      Color(0xFF3F5E2E),
      Color(0xFF5E7E3E),
      Color(0xFF8AAE5E),
    ]);
    crown.clump(pc - const Offset(0, 8), 32, 260, rnd);
    for (var k = 0; k < 10; k++) {
      final a = k * 2.4;
      crown.clump(pc + Offset(cos(a) * 20, sin(a) * 14 - 6), 7, 24, rnd);
    }
    crown.paint(c);
    return rec.endRecording();
  });

  /// The pond's water: an organic basin inside the 3×3 cells around the
  /// island (the collision is the square; its corners are boulders).
  Path _trellisPondPath() =>
      vfxBlob(trellisCellCentre(kTrellisIsland), 132, 7.7, n: 18, wobble: 0.05);

  void _renderTrellis(Canvas canvas, DungeonRoom room) {
    final s = _green;
    final t = greenhouse.trellis;
    canvas.drawPicture(_trellisBase(room));

    // Moist soil, spreading tile by tile in the order the water runs.
    if (t.watered || s.waterT >= 0) {
      final wt = t.watered ? (s.waterT < 0 ? 99.0 : s.waterT) : 0.0;
      canvas.save();
      canvas.clipPath(_trellisBedPath());
      for (final (i, cell) in kTrellisIrrigated.indexed) {
        final k = _ease((wt - i * 0.18) / 0.5);
        if (k <= 0) continue;
        final r = trellisCellRect(cell).inflate(1);
        // Darkened and cooled, not painted over: the furrows still show.
        canvas.drawRect(
          r,
          Paint()
            ..color = const Color(0xFF7A8290).withValues(alpha: 0.9 * k)
            ..blendMode = BlendMode.multiply,
        );
        // Water standing in the troughs catches the light.
        for (var j = 0; j < 4; j++) {
          final p =
              r.topLeft +
              Offset(
                18 + (j * 23 + cell.$1 * 11) % 56,
                20 + (j * 17 + cell.$2 * 7) % 52,
              );
          canvas.drawPath(
            vfxCrescent(p, 5, 1.4, -pi / 2, 1.4),
            Paint()..color = _gWaterLit.withValues(alpha: 0.45 * k),
          );
        }
      }
      canvas.restore();
    }

    // The pond's surface: light drifting on it, and a slow ripple now and
    // then — clipped to the water.
    final pc = trellisCellCentre(kTrellisIsland);
    canvas.save();
    canvas.clipPath(_trellisPondPath());
    if (_fx.ready) {
      for (var i = 0; i < 5; i++) {
        final a = _time * 0.07 + i * 1.3;
        final p =
            pc + Offset(cos(a) * (70 + i * 9), sin(a * 1.3) * (60 + i * 6));
        drawGlow(canvas, _fx.glow!, p, 40, _gWaterLit.withValues(alpha: 0.10));
      }
    }
    for (var i = 0; i < 3; i++) {
      final u = ((_time * 0.18 + i / 3) % 1.0);
      final at = pc + Offset(cos(i * 2.1) * 90, sin(i * 2.1) * 80);
      canvas.drawPath(
        vfxCrescent(at, 6 + 22 * u, 1.6, -pi / 2 + i, 2.4),
        Paint()..color = _gWaterLit.withValues(alpha: 0.22 * (1 - u)),
      );
    }
    canvas.restore();

    // The frozen crossing: a floe of faceted ice across the east bed's
    // lane, crawling out from the bank toward the island, with rime on the
    // water round it.
    final ft = t.frozen ? (s.freezeT < 0 ? 99.0 : s.freezeT) : -1.0;
    if (ft >= 0) {
      final k = _ease(ft / 1.2);
      final floe = [
        const Offset(618, 404),
        const Offset(612, 360),
        const Offset(626, 318),
        const Offset(648, 296),
        const Offset(672, 298),
        const Offset(690, 322),
        const Offset(698, 366),
        const Offset(692, 404),
      ];
      final front = 404 - 110 * k;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(560, front, 760, 420));
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          const Offset(655, 350),
          90,
          _gFrost.withValues(alpha: 0.22 * k),
        );
      }
      final outline = Path()..addPolygon(floe, true);
      canvas.drawPath(
        outline.shift(const Offset(0, 3)),
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.3),
      );
      // Facets: fan the floe from an off-centre point into panes.
      const hub = Offset(650, 356);
      for (var i = 0; i < floe.length; i++) {
        final pane = Path()
          ..moveTo(hub.dx, hub.dy)
          ..lineTo(floe[i].dx, floe[i].dy)
          ..lineTo(
            floe[(i + 1) % floe.length].dx,
            floe[(i + 1) % floe.length].dy,
          )
          ..close();
        paintPane(
          canvas,
          pane,
          Color.lerp(const Color(0xFF9CC6D8), Colors.white, (i % 3) * 0.25)!,
          _kVerdantGlass,
          lead: 1.6,
        );
      }
      paintStreak(canvas, const Rect.fromLTWH(630, 320, 30, 30), opacity: 0.6);
      canvas.restore();
      if (k < 1) {
        for (var i = 0; i < 5; i++) {
          canvas.drawPath(
            vfxShard(Offset(622 + i * 17.0, front), 10, 3, -pi / 2),
            Paint()..color = Colors.white.withValues(alpha: 0.8),
          );
        }
      }
    }

    // The lamps: iron standards with leaded lanterns; the lit one throws a
    // warm pool over its end of the board, and the glow visibly crosses from
    // one to the other as the choice changes.
    _drawTrellisLamp(canvas, trellisCellCentre(kTrellisWestLamp), s.lampW);
    _drawTrellisLamp(canvas, trellisCellCentre(kTrellisEastLamp), s.lampE);
    final moving = (s.lampW - (t.lit == TrellisLamp.west ? 1 : 0)).abs() > 0.02;
    if (moving && _fx.ready) {
      final from = trellisCellCentre(
        t.lit == TrellisLamp.west ? kTrellisEastLamp : kTrellisWestLamp,
      );
      final to = trellisCellCentre(
        t.lit == TrellisLamp.west ? kTrellisWestLamp : kTrellisEastLamp,
      );
      final u = t.lit == TrellisLamp.west ? s.lampW : s.lampE;
      for (var i = 0; i < 5; i++) {
        final v = (u - i * 0.06).clamp(0.0, 1.0);
        final p = Offset.lerp(from, to, v)! + Offset(0, -30 - 50 * sin(v * pi));
        drawGlow(
          canvas,
          _fx.glow!,
          p,
          14 - i * 2,
          _gSun.withValues(alpha: 0.7 - i * 0.12),
        );
      }
    }

    // The ghost: exactly where the tendril would go, breathing, until it
    // is grown. Brighter at the root, where the choice is made.
    if (!greenhouse.grown && !s.tendrilMoving) {
      final ghost = growTendril(t);
      final near =
          active != null &&
          (active!.position - kTrellisRootKnuckle).distance < 160;
      final o = (near ? 0.62 : 0.4) + 0.1 * sin(_time * 2.2);
      _drawTendril(canvas, ghost.path, ghost.path.length.toDouble(), ghost: o);
      _drawStopMark(canvas, ghost.path, ghost.stop, o);
    }

    // The real tendril.
    if (s.tendrilShown > 0) {
      _drawTendril(canvas, s.tendrilPath, s.tendrilShown);
      if (!s.tendrilMoving && greenhouse.grown) {
        _drawStopMark(canvas, s.tendrilPath, s.tendrilStop, 1);
      }
    }

    // The bud on the island.
    _drawIslandBud(canvas);

    // The hatch.
    _drawHatch(canvas);

    // The rings, and the root's GROW / PULL knuckle.
    for (final r in kTrellisRings) {
      final lamp = r.id == kTrellisWestLightRing.id
          ? TrellisLamp.west
          : r.id == kTrellisEastLightRing.id
          ? TrellisLamp.east
          : null;
      final done = switch (r.product) {
        'Water' => t.watered,
        'Ice' => t.frozen,
        _ => t.lit == lamp,
      };
      _drawTendRing(canvas, r.at, r.product, done: done, scale: 0.86);
    }
    _drawRootKnuckle(canvas);
  }

  /// An iron lamp standard: a carved plinth, a tapering post with a
  /// crossbar, and a six-sided lantern of leaded glass under a peaked cap.
  void _drawTrellisLamp(Canvas canvas, Offset at, double glow) {
    const iron = Color(0xFF1A1714);
    const ironLit = Color(0xFF4A3E30);
    if (glow > 0.01) {
      canvas.drawOval(
        Rect.fromCenter(
          center: at + const Offset(0, 6),
          width: 320,
          height: 220,
        ),
        Paint()
          ..shader = ui.Gradient.radial(at + const Offset(0, 6), 160, [
            _gSun.withValues(alpha: 0.24 * glow),
            _gSun.withValues(alpha: 0),
          ]),
      );
    }
    paintContactShadow(canvas, at + const Offset(0, 10), 46, 16);
    paintCarvedBlock(
      canvas,
      Rect.fromCenter(center: at + const Offset(0, 4), width: 26, height: 14),
      6,
      _kVerdantGlass,
      radius: 3,
    );
    final top = at + const Offset(0, -58);
    canvas.drawPath(
      vfxRibbon([at, top + const Offset(0, 14)], 7, 4),
      Paint()..color = iron,
    );
    canvas.drawPath(
      vfxRibbon(
        [at + const Offset(-1.5, 0), top + const Offset(-1.5, 14)],
        1.6,
        1,
      ),
      Paint()..color = ironLit,
    );
    // The crossbar with its scrolls.
    for (final side in const [-1.0, 1.0]) {
      canvas.drawPath(
        vfxCrescent(top + Offset(side * 8, 20), 7, 2.2, side < 0 ? pi : 0, 2.6),
        Paint()..color = iron,
      );
    }
    // The lantern.
    final hex = <Offset>[
      for (var i = 0; i < 6; i++)
        top + Offset(cos(i * pi / 3) * 13, sin(i * pi / 3) * 16),
    ];
    for (var i = 0; i < 6; i++) {
      final pane = Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(hex[i].dx, hex[i].dy)
        ..lineTo(hex[(i + 1) % 6].dx, hex[(i + 1) % 6].dy)
        ..close();
      paintPane(
        canvas,
        pane,
        Color.lerp(
          _kVerdantGlass.smoke,
          i.isEven ? _gSun : const Color(0xFFFFE9B0),
          0.12 + 0.88 * glow,
        )!,
        _kVerdantGlass,
        lead: 1.8,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(top.dx - 16, top.dy - 14)
        ..lineTo(top.dx, top.dy - 30)
        ..lineTo(top.dx + 16, top.dy - 14)
        ..close(),
      Paint()..color = iron,
    );
    canvas.drawCircle(top + const Offset(0, -33), 3, Paint()..color = ironLit);
    if (glow > 0.01 && _fx.ready) {
      drawGlow(canvas, _fx.glow!, top, 50, _gSun.withValues(alpha: 0.6 * glow));
    }
  }

  /// The tendril, unrolled [shown] tiles along [path]: a living green ribbon
  /// with leaves at every tile and a curled tip. [ghost] > 0 draws it as the
  /// faint preview instead.
  void _drawTendril(
    Canvas canvas,
    List<TrellisCell> path,
    double shown, {
    double ghost = 0,
  }) {
    if (path.isEmpty || shown <= 0) return;
    // The spine starts at the root knuckle and runs through tile centres.
    final pts = <Offset>[
      kTrellisRootKnuckle,
      for (final c in path) trellisCellCentre(c),
    ];
    // Sample it finely, up to the shown length.
    final spine = <Offset>[];
    final whole = min(shown, path.length.toDouble());
    for (var i = 0; i < pts.length - 1; i++) {
      if (i > whole) break;
      final a = pts[i], b = pts[i + 1];
      final segEnd = min(1.0, whole - i);
      for (var k = 0; k <= 6; k++) {
        final u = k / 6 * segEnd;
        final wob =
            Offset(-(b - a).dy, (b - a).dx) /
            max(1.0, (b - a).distance) *
            (6 * sin(u * pi * 2 + i * 1.3));
        spine.add(Offset.lerp(a, b, u)! + wob);
      }
    }
    if (spine.length < 2) return;
    final alpha = ghost > 0 ? ghost : 1.0;
    final col = ghost > 0 ? _kVerdantGlass.liveCore : _gStem;
    if (ghost <= 0) {
      canvas.drawPath(
        vfxRibbon(spine, 10, 5).shift(const Offset(2, 4)),
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.25),
      );
    }
    canvas.drawPath(
      vfxRibbon(spine, ghost > 0 ? 12 : 10, ghost > 0 ? 6 : 4),
      Paint()..color = col.withValues(alpha: alpha * (ghost > 0 ? 0.55 : 1)),
    );
    if (ghost <= 0) {
      canvas.drawPath(
        vfxRibbon([for (final p in spine) p + const Offset(-1.5, -1.5)], 3, 1),
        Paint()..color = _gLeafLit.withValues(alpha: 0.7),
      );
    }
    // Leaves, in pairs, along it.
    for (var i = 4; i < spine.length - 2; i += 5) {
      final p = spine[i];
      final d = spine[i + 1] - spine[i - 1];
      final a = atan2(d.dy, d.dx);
      for (final side in const [-1.0, 1.0]) {
        final la = a + side * 1.1 + 0.15 * _sway(_time, i.toDouble());
        if (ghost > 0) {
          canvas.drawPath(
            vfxLeaf(p, 12, la),
            Paint()
              ..color = _kVerdantGlass.liveCore.withValues(alpha: alpha * 0.45),
          );
          continue;
        }
        // The grown vine's leaves are grains (2026-10-08; flat leaf shapes)
        // — the vine itself stays a solid stem, because it is the route.
        _greenLeaf(
          p,
          16,
          la,
          _time,
          ramp: i.isEven ? _kGreenLiveRamp : _kGreenSunlitRamp,
          n: 40,
          stir: 0.5,
          seed: 700 + i * 2 + (side > 0 ? 1 : 0),
        );
      }
    }
    _greenGrains.paint(canvas);
    // The tip: a tight curl.
    final tip = spine.last;
    final d = spine.last - spine[spine.length - 2];
    final a = atan2(d.dy, d.dx);
    canvas.drawPath(
      vfxCrescent(tip + Offset(cos(a), sin(a)) * 6, 7, 3, a + pi / 2, 3.6),
      Paint()..color = col.withValues(alpha: alpha * (ghost > 0 ? 0.5 : 1)),
    );
  }

  /// Why the tip stops, drawn where it stops: a puff of dust at dry earth,
  /// ripples at open water, the stone at the bed's end, a question of light
  /// at the fork.
  void _drawStopMark(
    Canvas canvas,
    List<TrellisCell> path,
    TendrilStop stop,
    double o,
  ) {
    if (stop == TendrilStop.bud) return;
    final at = path.isEmpty
        ? kTrellisRootKnuckle
        : trellisCellCentre(path.last);
    Offset next;
    if (path.isEmpty) {
      next = trellisCellCentre(kTrellisRoot);
    } else if (stop == TendrilStop.water) {
      next = trellisCellCentre(kTrellisPondCrossing);
    } else {
      final i = path.length;
      final branch = [
        kTrellisRoot,
        kTrellisFork,
        ...(greenhouse.trellis.lit == TrellisLamp.east
            ? kTrellisEastBed
            : kTrellisWestBed),
      ];
      next = i < branch.length ? trellisCellCentre(branch[i]) : at;
    }
    final mid = Offset.lerp(at, next, 0.55)!;
    switch (stop) {
      case TendrilStop.dry:
        for (var i = 0; i < 5; i++) {
          final a = i * 1.26 + _time * 0.4;
          canvas.drawPath(
            vfxBlob(mid + Offset(cos(a), sin(a)) * 10, 5, i.toDouble(), n: 6),
            Paint()..color = const Color(0xFFB09A70).withValues(alpha: 0.5 * o),
          );
        }
      case TendrilStop.water:
        for (var i = 0; i < 2; i++) {
          final u = ((_time * 0.7 + i * 0.5) % 1.0);
          canvas.drawPath(
            vfxCrescent(mid, 8 + 18 * u, 2.5, pi / 2, 2.2),
            Paint()..color = _gWaterLit.withValues(alpha: 0.6 * (1 - u) * o),
          );
        }
      case TendrilStop.bedEnd:
      case TendrilStop.noLight:
      case TendrilStop.bud:
        break;
    }
  }

  /// THE BUD STAR. The sealed bud on the island is a great closed bulb of
  /// leaded glass. When the tendril reaches it: the tip coils round it, the
  /// bulb swells with light breaking through its seams, and it bursts — a
  /// shockwave rolls across the pond, pollen spirals out, a star rises from
  /// the heart — and then the pollen streams north to the way on. Open, it
  /// breathes.
  void _drawIslandBud(Canvas canvas) {
    final at = trellisCellCentre(kTrellisIsland) + const Offset(0, -4);
    final t = _green.budBurstT;
    final live = t >= 0 && t < 50;
    final opened = hasStar(1) && !live;
    final coil = !live ? (opened ? 1.0 : 0.0) : _ease(t / kBudCoil);
    final swell = live && t < kBudBurst
        ? _ease((t - 0.35) / (kBudBurst - 0.35))
        : 0.0;
    final since = live ? t - kBudBurst : 99.0;
    final open = opened || (live && since >= 0)
        ? Curves.easeOutBack.transform((since / 1.1).clamp(0.0, 1.0))
        : 0.0;
    const gold = Color(0xFFF0C64A);
    final core = Color.lerp(_kVerdantGlass.live, Colors.white, 0.35)!;

    paintContactShadow(canvas, at + const Offset(0, 18), 70, 18);

    // THE SHOCKWAVE, and the pond answering it.
    if (live && since >= 0 && since < 1.6) {
      final u = since / 1.6;
      final r = 30 + 250 * _easeOut(u);
      canvas.drawCircle(
        at,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            at,
            r,
            [
              core.withValues(alpha: 0),
              core.withValues(alpha: 0.35 * (1 - u)),
              core.withValues(alpha: 0),
            ],
            const [0.7, 0.92, 1.0],
          ),
      );
      for (var k = 0; k < 3; k++) {
        final rr = r * (0.55 + k * 0.18);
        for (var i = 0; i < 10; i++) {
          final a = i * 2 * pi / 10 + k * 0.3;
          canvas.drawPath(
            vfxCrescent(at, rr, 2.2, a, 0.32),
            Paint()..color = _gWaterLit.withValues(alpha: 0.45 * (1 - u)),
          );
        }
      }
    }

    // The tendril's tip coiling round the bulb before it opens.
    if (coil > 0 && open < 0.6) {
      final turns = 1.6 * coil;
      final pts = <Offset>[
        for (var i = 0; i <= 30; i++)
          () {
            final u = i / 30 * turns;
            final a = pi / 2 + u * 2 * pi;
            final rr = 26 - 7 * (u / 1.6);
            return at + Offset(cos(a) * rr, sin(a) * rr * 0.62 + 8 - u * 8);
          }(),
      ];
      canvas.drawPath(
        vfxRibbon(pts, 6, 3),
        Paint()..color = _gStem.withValues(alpha: 1 - open),
      );
      for (var i = 6; i < pts.length; i += 8) {
        canvas.drawPath(
          vfxLeaf(pts[i], 10, i * 0.9),
          Paint()..color = _gLeafLit.withValues(alpha: 1 - open),
        );
      }
    }

    if (open <= 0) {
      // Shut, swelling: the bulb grows, its glass warms from within, and
      // light splits out through the seams between its petals.
      final pulse = swell * (0.06 * sin(t * 18));
      final r = 20 * (1 + 0.28 * swell + pulse);
      for (var i = 0; i < 6; i++) {
        final a = -pi / 2 + i * pi / 3;
        _glassPetal(
          canvas,
          at + Offset(cos(a + pi), sin(a + pi)) * r * 0.2,
          r * 1.35,
          a,
          r * 0.5,
          Color.lerp(_kVerdantGlass.frostAt(i), _kVerdantGlass.live, swell)!,
          Color.lerp(
            _kVerdantGlass.liveDeep,
            _kVerdantGlass.frostAt(i + 1),
            0.3,
          )!,
          squash: 0.8,
        );
      }
      paintPane(
        canvas,
        vfxBlob(at, r * 0.72, 1.7, n: 12, wobble: 0.05, squash: 1.1),
        Color.lerp(_kVerdantGlass.liveDeep, core, swell)!,
        _kVerdantGlass,
        lead: 3,
      );
      if (swell > 0) {
        for (var i = 0; i < 6; i++) {
          final a = -pi / 2 + i * pi / 3 + pi / 6;
          canvas.drawPath(
            vfxShard(
              at + Offset(cos(a), sin(a) * 0.8) * r * 0.9,
              10 + 22 * swell,
              2.4,
              a,
            ),
            Paint()..color = Colors.white.withValues(alpha: 0.75 * swell),
          );
        }
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            at,
            40 + 60 * swell,
            core.withValues(alpha: 0.55 * swell),
          );
        }
      }
      return;
    }

    // OPEN: three tiers of glass petals, the outer wide and green-gold, the
    // inner pale, and a crown of gold stamens; the whole bloom breathes.
    final breathe = 1 + 0.03 * sin(_time * 1.6);
    for (var tier = 0; tier < 3; tier++) {
      final n = [10, 8, 6][tier];
      final len = [60.0, 42.0, 25.0][tier] * open * breathe;
      for (var i = 0; i < n; i++) {
        final a =
            -pi / 2 +
            i * 2 * pi / n +
            tier * 0.33 +
            _sway(_time, i + tier * 5.0, 0.7) * 0.03;
        _glassPetal(
          canvas,
          at,
          len,
          a,
          len * 0.3,
          [
            Color.lerp(_kVerdantGlass.live, gold, 0.25)!,
            Color.lerp(_kVerdantGlass.live, Colors.white, 0.45)!,
            const Color(0xFFFFF4D0),
          ][tier],
          [
            _kVerdantGlass.liveDeep,
            _kVerdantGlass.live,
            Color.lerp(gold, Colors.white, 0.3)!,
          ][tier],
          squash: 0.72,
        );
      }
    }
    for (var i = 0; i < 9; i++) {
      final a = i * 2 * pi / 9 + _time * 0.3;
      final p = at + Offset(cos(a), sin(a) * 0.7) * 9 * open;
      canvas.drawCircle(p, 2.2, Paint()..color = gold);
    }
    paintRondel(
      canvas,
      at,
      7 * open.clamp(0.0, 1.0),
      _kVerdantGlass,
      fill: gold,
    );
    if (_fx.ready) {
      final flash = since < 0.9 ? 1 - since / 0.9 : 0.0;
      drawGlow(
        canvas,
        _fx.glow!,
        at,
        90 + 170 * flash,
        core.withValues(alpha: 0.22 + 0.04 * sin(_time * 2) + 0.55 * flash),
      );
    }
    _orbitMotes(
      canvas,
      at,
      52,
      5,
      const Color(0xFFFFF0B8),
      open.clamp(0.0, 1.0),
      0.45,
    );

    if (!live) return;

    // POLLEN: a spiral burst outward on the opening.
    if (since < 1.8) {
      final u = since / 1.8;
      for (var i = 0; i < 36; i++) {
        final a = i * 2 * pi / 36 + u * 1.6 + (i.isEven ? 0.1 : 0);
        final rr = 20 + (120 + (i * 37) % 70) * _easeOut(u);
        final p = at + Offset(cos(a), sin(a) * 0.7) * rr - Offset(0, 30 * u);
        final o = (1 - u) * (i.isEven ? 1 : 0.7);
        if (_fx.ready) {
          drawGlow(canvas, _fx.mote!, p, 6, gold.withValues(alpha: 0.8 * o));
        }
        canvas.drawCircle(
          p,
          1.6,
          Paint()..color = Colors.white.withValues(alpha: o),
        );
      }
    }

    // THE STAR, rising out of the heart and flaring.
    if (since >= 0 && since < 1.4) {
      final u = since / 1.4;
      final p = at - Offset(0, 70 * _easeOut(u));
      final sz = 22 * (u < 0.7 ? _easeOut(u / 0.7) : 1 + (u - 0.7) * 1.2);
      final o = u < 0.75 ? 1.0 : (1 - (u - 0.75) / 0.25);
      final star = Path();
      for (var i = 0; i < 16; i++) {
        final a = -pi / 2 + i * pi / 8 + u * 0.8;
        final rr = i.isEven ? (i % 4 == 0 ? sz : sz * 0.62) : sz * 0.22;
        final q = p + Offset(cos(a), sin(a)) * rr;
        i == 0 ? star.moveTo(q.dx, q.dy) : star.lineTo(q.dx, q.dy);
      }
      star.close();
      if (_fx.ready) {
        drawGlow(canvas, _fx.glow!, p, sz * 3, gold.withValues(alpha: 0.6 * o));
      }
      canvas.drawPath(star, Paint()..color = gold.withValues(alpha: o));
      canvas.drawCircle(
        p,
        sz * 0.2,
        Paint()..color = Colors.white.withValues(alpha: o),
      );
    }

    // THE STREAM: the pollen flows north across the board to the way on,
    // and the doorway flares as it arrives.
    const door = Offset(435, 24);
    final ctrl = Offset.lerp(at, door, 0.5)! + const Offset(60, -40);
    final stream = t - (kBudBurst + 0.5);
    final span = kBudDoor - (kBudBurst + 0.5);
    if (stream > 0 && t < kBudDoor + 0.6) {
      for (var i = 0; i < 18; i++) {
        final u = (stream / span) * 1.3 - i * 0.05;
        if (u <= 0 || u >= 1) continue;
        final p =
            Offset.lerp(
              Offset.lerp(at, ctrl, u)!,
              Offset.lerp(ctrl, door, u)!,
              u,
            )! +
            Offset(8 * sin(i * 1.7 + t * 4), 0);
        if (_fx.ready) {
          drawGlow(canvas, _fx.mote!, p, 8, gold.withValues(alpha: 0.85));
        }
        canvas.drawCircle(
          p,
          2,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
      }
    }
    if (t > kBudDoor - 0.2 && _fx.ready) {
      final u = ((t - (kBudDoor - 0.2)) / 1.0).clamp(0.0, 1.0);
      drawGlow(
        canvas,
        _fx.glow!,
        door + const Offset(0, 20),
        90,
        gold.withValues(alpha: 0.6 * (1 - u)),
      );
    }
  }

  void _drawHatch(Canvas canvas) {
    final s = _green;
    final lid = kTrellisHatch;
    if (!greenhouse.hatchOpen) return;
    final k = s.hatchT < 0 ? 1.0 : _ease(s.hatchT / 1.1);
    // The hole: steps down into the dark.
    canvas.drawRRect(
      RRect.fromRectAndRadius(lid.deflate(3), const Radius.circular(5)),
      Paint()..color = const Color(0xFF070806).withValues(alpha: k),
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(lid.left + 8, lid.top + 10 + i * 12, lid.width - 16, 5),
        Paint()
          ..color = _kVerdantGlass.stoneFace.withValues(
            alpha: 0.7 * k * (1 - i * 0.25),
          ),
      );
    }
    // The lid, tipped aside onto the next tile.
    final aside = lid.shift(Offset(-12 * k, 46 * k));
    canvas.save();
    canvas.translate(aside.center.dx, aside.center.dy);
    canvas.rotate(0.5 * k);
    paintCarvedBlock(
      canvas,
      Rect.fromCenter(
        center: Offset.zero,
        width: lid.width - 8,
        height: lid.height - 8,
      ),
      6,
      _kVerdantGlass,
      radius: 5,
    );
    canvas.restore();
  }

  /// The great plant's root, come in under the south wall: three strands of
  /// gnarled bark twisting together, rootlets gripping the walkway, and at its
  /// head a shut bud of green glass — GROW and PULL are pressed here.
  void _drawRootKnuckle(Canvas canvas) {
    final k = kTrellisRootKnuckle;
    const foot = Offset(472, 800);
    for (var strand = 0; strand < 3; strand++) {
      final spine = <Offset>[
        for (var i = 0; i <= 12; i++)
          () {
            final u = i / 12;
            final tw = u * pi * 2.2 + strand * 2 * pi / 3;
            return Offset.lerp(foot, k + const Offset(0, 14), u)! +
                Offset(sin(tw) * (13 - u * 7), 0);
          }(),
      ];
      canvas.drawPath(
        vfxRibbon(spine, 13, 7).shift(const Offset(3, 5)),
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.25),
      );
      canvas.drawPath(vfxRibbon(spine, 13, 7), Paint()..color = _gBark);
      canvas.drawPath(
        vfxRibbon([for (final p in spine) p + const Offset(-4, -1)], 1.6, 0.8),
        Paint()..color = _gBarkLit.withValues(alpha: 0.7),
      );
    }
    for (final (dy, side) in const [
      (40.0, -1.0),
      (70.0, 1.0),
      (100.0, -1.0),
      (120.0, 1.0),
    ]) {
      final from = k + Offset(0, dy);
      final to = from + Offset(side * 34, 10);
      canvas.drawPath(
        vfxRibbon(
          [from, Offset.lerp(from, to, 0.5)! + Offset(0, -6), to],
          4.5,
          0.6,
        ),
        Paint()..color = _gBark,
      );
    }
    final near =
        active != null && (active!.position - k).distance < _kGreenReach + 30;
    final lit = greenhouse.grown
        ? 1.0
        : (near ? 0.75 : 0.4 + 0.15 * sin(_time * 2));
    for (var i = 0; i < 3; i++) {
      final a = -pi / 2 + (i - 1) * 0.45;
      _glassPetal(
        canvas,
        k + Offset(cos(a + pi), sin(a + pi)) * 4,
        22,
        a,
        8,
        Color.lerp(_kVerdantGlass.liveDeep, _kVerdantGlass.live, lit)!,
        _kVerdantGlass.liveDeep,
      );
    }
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        k - const Offset(0, 8),
        34,
        _kVerdantGlass.live.withValues(alpha: 0.35 * lit),
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // THE RITE — THE ROOTBOUND DOOR
  // ─────────────────────────────────────────────────────────

  /// The door's roots: bark from the knot down through every bud to each
  /// tip, and on down into its ring. They lift away as they let go.
  List<(String?, String, double, double)> get _rootSegments => [
    // (from, to, width at from, width at to); from == null is a tip's run
    // down into its ring.
    ('K', 'A', 26, 17),
    ('K', 'B', 26, 17),
    ('A', 'C', 16, 10),
    ('A', 'D', 16, 10),
    ('B', 'E', 16, 10),
    ('B', 'F', 16, 10),
    for (final t in kRootTips) (null, t, 9, 5),
  ];

  Offset _rootPos(String n, double lift) {
    final p = kRootAt[n]!;
    if (lift <= 0) return p;
    // Letting go: the roots draw up and apart, back into the wall.
    final depth = kRootNodes.indexOf(n) == 0
        ? 0.3
        : (kRootParent[n] == 'K' ? 0.6 : 1.0);
    return p + Offset((p.dx - 450) * 0.25 * lift, -220 * lift * depth);
  }

  void _renderRite(Canvas canvas, DungeonRoom room) {
    final s = _green;
    final g = greenhouse;
    final lift = s.unwindT < 0 ? 0.0 : _ease(s.unwindT / 2.2);

    // THE BARK.
    for (final (from, to, w0, w1) in _rootSegments) {
      final b = _rootPos(to, lift);
      final a = from == null
          ? kRootRings[to]!.at - const Offset(0, kTendRingDrawn * 0.6)
          : _rootPos(from, lift);
      final mid =
          Offset.lerp(a, b, 0.5)! +
          Offset(10 * sin(a.dx * 0.05 + b.dy * 0.03), 8);
      final spine = _smoothSpine([a, mid, b], 8);
      final fade = from == null ? (1 - lift) : 1 - lift * 0.4;
      canvas.drawPath(
        vfxRibbon(spine, w0, w1).shift(const Offset(3, 6)),
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.3 * fade),
      );
      canvas.drawPath(
        vfxRibbon(spine, w0, w1),
        Paint()..color = _gBark.withValues(alpha: fade),
      );
      canvas.drawPath(
        vfxRibbon(
          [for (final p in spine) p + Offset(-w0 * 0.32, -w0 * 0.22)],
          max(1.2, w0 * 0.12),
          0.8,
        ),
        Paint()..color = _gBarkLit.withValues(alpha: 0.6 * fade),
      );
    }
    // The knot's own anchoring roots, up into the wall either side of the
    // door.
    for (final side in const [-1.0, 1.0]) {
      final k = _rootPos('K', lift);
      final spine = _smoothSpine([
        k,
        k + Offset(side * 90, -40),
        Offset(450 + side * 230, 40),
      ], 8);
      canvas.drawPath(
        vfxRibbon(spine, 22, 10),
        Paint()..color = _gBark.withValues(alpha: 1 - lift * 0.5),
      );
    }

    // THE CLIMB: a bead of the climate travelling up the root it was fed to.
    for (final r in s.rootRuns) {
      final pts = [kRootRings[r.tip]!.at, for (final n in r.nodes) kRootAt[n]!];
      if (r.product == 'Ice') {
        // Frost does not climb, it CRAWLS: shards run out along the bark
        // from each bud as it takes.
        for (final (i, n) in r.nodes.indexed) {
          final u = ((r.t - 0.25 - i * 0.2) / 0.5).clamp(0.0, 1.0);
          if (u <= 0 || u >= 1) continue;
          final at = kRootAt[n]!;
          for (var k = 0; k < 6; k++) {
            final a = k * pi / 3 + i;
            canvas.drawPath(
              vfxShard(at + Offset(cos(a), sin(a)) * (18 + 20 * u), 9, 2.4, a),
              Paint()..color = _gFrost.withValues(alpha: 0.85 * (1 - u)),
            );
          }
        }
        continue;
      }
      final seg = (r.t - 0.05) / 0.2;
      if (seg < 0 || seg >= pts.length - 1) continue;
      Offset along(double sg) {
        final c = sg.clamp(0.0, pts.length - 1.0001);
        final i = c.floor();
        return Offset.lerp(pts[i], pts[i + 1], c - i)!;
      }

      final p = along(seg);
      final col = r.product == 'Water' ? _gWaterLit : _gSun;
      if (_fx.ready) {
        drawGlow(canvas, _fx.glow!, p, 26, col.withValues(alpha: 0.7));
      }
      // The climate climbing as a run of its grains, bright at the head and
      // strung out behind it up the bark (it was a white disc).
      final ramp = grainRampFrom(col);
      for (var j = 0; j < 46; j++) {
        final h = _greenHash(j * 31 + 7);
        final back = j / 46 * 0.55;
        final at =
            along(seg - back) +
            Offset(
              sin(_time * 3 + h * 9) * (1.5 + 5 * back),
              cos(_time * 2.6 + h * 7) * (1.5 + 5 * back),
            );
        final prev = along(seg - back - 0.03);
        _greenGrains.add(
          prev.dx + (at.dx - along(seg - back).dx),
          prev.dy + (at.dy - along(seg - back).dy),
          at.dx,
          at.dy,
          ramp[j < 8 ? 3 : (j < 24 ? 2 : 1)],
          alpha: 1 - back * 1.4,
        );
      }
      _greenGrains.paint(canvas);
    }

    // THE BUDS, each as it is — or turning, once the climb reaches it.
    for (final n in kRootNodes) {
      final at = _rootPos(n, lift);
      final fx = s.rootFx[n];
      final state = fx == null
          ? (s.rootShown[n] ?? g.roots.state[n]!)
          : (fx.t < fx.delay ? fx.from : fx.to);
      final pop = fx == null || fx.t < fx.delay
          ? 1.0
          : 1 + 0.35 * (1 - _easeOut((fx.t - fx.delay) / 0.45));
      _drawRootBud(canvas, at, state, n == 'K' ? 1.35 * pop : pop);
      if (fx != null &&
          fx.t >= fx.delay &&
          fx.t < fx.delay + 0.6 &&
          _fx.ready) {
        final u = (fx.t - fx.delay) / 0.6;
        drawGlow(
          canvas,
          _fx.glow!,
          at,
          30 + 40 * u,
          _rootColour(fx.to).withValues(alpha: 0.6 * (1 - u)),
        );
      }
      if (lift > 0 && _fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          at,
          50,
          _kVerdantGlass.liveCore.withValues(alpha: 0.5 * lift * (1 - lift)),
        );
      }
    }

    // THE GHOST: standing a pair in a ring shows what that press WOULD do,
    // on the buds it would change — never what the door wants.
    final a = active;
    if (!g.rootsOpen && a != null && s.rootFx.isEmpty && s.rootRuns.isEmpty) {
      for (final e in kRootRings.entries) {
        if (!_standingIn(a, e.value.at)) continue;
        final made = ringProduct(_ringElements(e.value.at));
        if (made.product == null) break;
        final pulse = 0.5 + 0.5 * sin(_time * 3);
        for (final (n, to) in g.roots.preview(e.key, made.product!)) {
          final at = kRootAt[n]!;
          final col = _rootColour(to);
          if (_fx.ready) {
            drawGlow(
              canvas,
              _fx.glow!,
              at,
              34,
              col.withValues(alpha: 0.35 + 0.25 * pulse),
            );
          }
          canvas.drawPath(
            vfxBlob(at, 22, n.codeUnitAt(0).toDouble(), n: 10, wobble: 0.1),
            Paint()..color = col.withValues(alpha: 0.18 + 0.14 * pulse),
          );
        }
        break;
      }
    }

    for (final r in kRootRings.values) {
      _drawTendRing(canvas, r.at, null, done: g.rootsOpen);
    }
    _drawRootStump(canvas, kRootStump);
  }

  Color _rootColour(RootState s) => switch (s) {
    RootState.dry => const Color(0xFF8A7652),
    RootState.wet => const Color(0xFF4FA3D8),
    RootState.frozen => _gFrost,
    RootState.lit => const Color(0xFFF0C64A),
  };

  /// A root bud in one of its four states — the SAME drawing the great
  /// plant's crown flowers in, so the key and the lock are one picture:
  /// dry is a shut bud of dull glass; wet a blue bud beaded with water;
  /// frozen a white star of ice; lit an open gold bloom.
  void _drawRootBud(Canvas canvas, Offset at, RootState state, double scale) {
    final r = 20 * scale;
    switch (state) {
      case RootState.dry:
        _shutBud(canvas, at, r * 0.8, const Color(0xFF9A8460));
      case RootState.wet:
        for (var i = 0; i < 5; i++) {
          final a = -pi / 2 + (i - 2) * 0.5;
          _glassPetal(
            canvas,
            at + Offset(cos(a + pi), sin(a + pi)) * r * 0.3,
            r * 1.5,
            a,
            r * 0.45,
            const Color(0xFF7CC0E8),
            const Color(0xFF2A6A9A),
          );
        }
        canvas.drawCircle(
          at - Offset(0, r * 0.1),
          r * 0.32,
          Paint()
            ..shader = ui.Gradient.radial(
              at - Offset(r * 0.1, r * 0.25),
              r * 0.35,
              [Colors.white, const Color(0xFF4FA3D8)],
            ),
        );
        final u = (_time * 0.7 + at.dx * 0.01) % 1.0;
        canvas.drawPath(
          vfxDrop(at + Offset(0, r * 0.6 + u * r * 1.4), r * 0.16, pi / 2),
          Paint()..color = _gWaterLit.withValues(alpha: 0.8 * (1 - u)),
        );
      case RootState.frozen:
        for (var i = 0; i < 6; i++) {
          final a = -pi / 2 + i * pi / 3;
          _glassPetal(
            canvas,
            at,
            r * 1.25,
            a,
            r * 0.36,
            Color.lerp(_gFrost, Colors.white, 0.4)!,
            const Color(0xFF6A9CB6),
            faceted: true,
          );
        }
        final hex = Path();
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3;
          final q = at + Offset(cos(a), sin(a)) * r * 0.32;
          i == 0 ? hex.moveTo(q.dx, q.dy) : hex.lineTo(q.dx, q.dy);
        }
        paintPane(
          canvas,
          hex..close(),
          Colors.white,
          _kVerdantGlass,
          lead: 1.5,
        );
      case RootState.lit:
        for (var ring = 0; ring < 2; ring++) {
          final n = ring == 0 ? 10 : 7;
          for (var i = 0; i < n; i++) {
            final a =
                i * 2 * pi / n +
                ring * 0.3 +
                _time * 0.1 * (ring == 0 ? 1 : -1);
            _glassPetal(
              canvas,
              at,
              r * (ring == 0 ? 1.45 : 0.95),
              a,
              r * 0.3,
              ring == 0 ? const Color(0xFFF0C64A) : const Color(0xFFFFE9A0),
              const Color(0xFFC0702A),
              flame: ring == 0,
            );
          }
        }
        paintRondel(
          canvas,
          at,
          r * 0.28,
          _kVerdantGlass,
          fill: Colors.white,
          lead: 1.5,
        );
    }
    if (_fx.ready && state != RootState.dry) {
      drawGlow(
        canvas,
        _fx.glow!,
        at,
        r * 2.4,
        _rootColour(
          state,
        ).withValues(alpha: state == RootState.lit ? 0.35 : 0.2),
      );
    }
  }

  /// The stump by the door: PRUNE, and the roots shed everything.
  void _drawRootStump(Canvas canvas, Offset at) {
    paintContactShadow(canvas, at + const Offset(0, 16), 90, 24);
    // Cut wood, dark, its rings showing as faint lit grooves (2026-10-08;
    // it was a pale brown disc with dark rings drawn on, a stump icon).
    paintCarvedDisc(
      canvas,
      at,
      38,
      20,
      16,
      _kVerdantGlass,
      topColor: const Color(0xFF2A2219),
    );
    for (var i = 1; i <= 3; i++) {
      canvas.drawPath(
        vfxCrescent(at, 9.0 * i, 1.4, -pi / 2 + i, pi * 1.4),
        Paint()..color = _gBarkLit.withValues(alpha: 0.35),
      );
    }
    final near =
        active != null && (active!.position - at).distance < _kGreenReach + 30;
    paintRondel(
      canvas,
      at,
      6,
      _kVerdantGlass,
      fill: greenhouse.roots.bare ? _kVerdantGlass.smoke : _kVerdantGlass.gold,
      rim: near ? 1 : 0.5,
    );
  }

  List<Offset> _smoothSpine(List<Offset> pts, int per) {
    final out = <Offset>[];
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[max(0, i - 1)],
          b = pts[i],
          c = pts[i + 1],
          d = pts[min(pts.length - 1, i + 2)];
      for (var k = 0; k < per; k++) {
        final t = k / per;
        final t2 = t * t, t3 = t2 * t;
        out.add(
          Offset(
            0.5 *
                (2 * b.dx +
                    (-a.dx + c.dx) * t +
                    (2 * a.dx - 5 * b.dx + 4 * c.dx - d.dx) * t2 +
                    (-a.dx + 3 * b.dx - 3 * c.dx + d.dx) * t3),
            0.5 *
                (2 * b.dy +
                    (-a.dy + c.dy) * t +
                    (2 * a.dy - 5 * b.dy + 4 * c.dy - d.dy) * t2 +
                    (-a.dy + 3 * b.dy - 3 * c.dy + d.dy) * t3),
          ),
        );
      }
    }
    out.add(pts.last);
    return out;
  }

  /// Over the doors: the roots holding the heart's door shut until the
  /// rite unwinds them (the engine's bars would be a lock with no key).
  void _renderConservatoryOverDoors(Canvas canvas, DungeonRoom room) {
    if (room.grove?.rite != true) return;
    final unwind = _green.unwindT < 0 ? 0.0 : _ease(_green.unwindT / 2.0);
    if (unwind >= 1) return;
    DungeonDoor? heart;
    for (final d in room.doors) {
      if (d.targetRoomId == 'botanica_heart') heart = d;
    }
    if (heart == null) return;
    final r = heart.rect;
    for (var i = 0; i < 4; i++) {
      final x = r.left + 10 + i * 30;
      final spine = [
        Offset(x - 20 + i * 4, r.top - 6),
        Offset(x + 10 * sin(i + 1.0), r.center.dy + 12),
        Offset(x + 16 - i * 6, r.bottom + 40),
      ];
      final pulled = [for (final p in spine) p + Offset(0, -80 * unwind)];
      canvas.drawPath(
        vfxRibbon(_smoothSpine(pulled, 6), 13, 6),
        Paint()..color = _gBark.withValues(alpha: 1 - unwind),
      );
      canvas.drawPath(
        vfxRibbon(
          _smoothSpine([for (final p in pulled) p + const Offset(-2, -2)], 6),
          4,
          1.5,
        ),
        Paint()..color = _gBarkLit.withValues(alpha: 0.6 * (1 - unwind)),
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // STAR 3 — BOTANICA'S HEART
  // ─────────────────────────────────────────────────────────

  void _renderArena(Canvas canvas, DungeonRoom room, ConservatoryPlot g) {
    final s = _green;
    final b = room.bounds;
    final centre = room.guardian?.position ?? b.center;
    // A great living floor: a rosette of carved leaves round the flower.
    canvas.drawPicture(
      _greenCache.putIfAbsent('arena|${room.id}', () {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        for (var ring = 0; ring < 3; ring++) {
          final n = 12 + ring * 6;
          for (var i = 0; i < n; i++) {
            final a = i * 2 * pi / n + ring * 0.3;
            final p = centre + Offset(cos(a), sin(a) * 0.7) * (90 + ring * 80);
            c.drawPath(
              vfxLeaf(p, 60 + ring * 16, a),
              Paint()
                ..color = Color.lerp(
                  const Color(0xFF26301E),
                  const Color(0xFF34442A),
                  ring / 2,
                )!.withValues(alpha: 0.8),
            );
          }
        }
        return rec.endRecording();
      }),
    );
    // The climate as it is: each wash rolls out from Botanica on its strike
    // and rolls back into the circle that fixed it.
    final landing = s.strikeT >= 0 ? _ease(s.strikeT / _kBotanicaStrike) : 0.0;
    for (final cl in Climate.values) {
      var w = s.wash[cl] ?? 0;
      if (s.strikeT >= 0 && s.strikeClimate == cl) w = max(w, landing);
      if (w <= 0.01) continue;
      _drawArenaWash(canvas, room, centre, cl, w);
    }
    // While the arena holds a climate, each ring's heart takes the colour of
    // what it needs — water, ice or light — and a bead of it hangs over the
    // ring, readable mid-fight. The climate, never the recipe.
    final c = greenhouse.arena;
    for (final at in g.arenaRings) {
      _drawTendRing(canvas, at, c == null ? null : climateFix(c), scale: 1.15);
      if (c != null) {
        final p =
            at + Offset(0, -kTendRingDrawn * 1.15 - 22 + 3 * sin(_time * 2));
        paintRondel(
          canvas,
          p,
          11,
          _kVerdantGlass,
          fill: _paneTint(climateFix(c)),
        );
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            p,
            30,
            _paneTint(climateFix(c)).withValues(alpha: 0.4),
          );
        }
      }
    }
    if (s.lull > 0 && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        centre,
        140,
        _kVerdantGlass.live.withValues(alpha: 0.12 + 0.05 * sin(_time * 3)),
      );
    }
  }

  void _drawArenaWash(
    Canvas canvas,
    DungeonRoom room,
    Offset centre,
    Climate c,
    double w,
  ) {
    final b = room.bounds;
    final r = 620 * w;
    switch (c) {
      case Climate.dry:
        // The floor parches outward from the flower: a tan crust, and the
        // cracks run out through it in short forked runs, never past the
        // wash's own front.
        canvas.save();
        canvas.clipRect(b);
        canvas.drawCircle(
          centre,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
              centre,
              max(1.0, r),
              [
                _gSoilDry.withValues(alpha: 0.30 * w),
                _gSoilDry.withValues(alpha: 0.18 * w),
                _gSoilDry.withValues(alpha: 0),
              ],
              const [0.0, 0.8, 1.0],
            ),
        );
        for (var i = 0; i < 18; i++) {
          final a = i * 2 * pi / 18 + (i.isEven ? 0.07 : -0.05);
          var p = centre + Offset(cos(a), sin(a) * 0.72) * 70;
          var dir = a;
          for (var seg = 0; seg < 4; seg++) {
            final reach = 70 + 90 * seg;
            if (reach > r) break;
            final len = 34.0 + (i * 13 + seg * 7) % 20;
            final q = p + Offset(cos(dir), sin(dir) * 0.72) * len;
            canvas.drawPath(
              vfxShard(
                Offset.lerp(p, q, 0.5)!,
                len * 0.62,
                3.2 - seg * 0.5,
                dir,
              ),
              Paint()..color = _gSoilCrack.withValues(alpha: 0.7 * w),
            );
            if (seg == 1) {
              final fork = dir + (i.isEven ? 0.7 : -0.7);
              canvas.drawPath(
                vfxShard(
                  q + Offset(cos(fork), sin(fork) * 0.72) * 14,
                  16,
                  2,
                  fork,
                ),
                Paint()..color = _gSoilCrack.withValues(alpha: 0.6 * w),
              );
            }
            p = q;
            dir += (i.isEven ? 0.18 : -0.2) * (seg.isEven ? 1 : -1);
          }
        }
        canvas.restore();
      case Climate.warm:
        canvas.drawCircle(
          centre,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
              centre,
              max(1.0, r),
              [
                _gHeat.withValues(alpha: 0.30 * w),
                _gHeat.withValues(alpha: 0.10 * w),
                _gHeat.withValues(alpha: 0),
              ],
              const [0.0, 0.7, 1.0],
            ),
        );
        for (var i = 0; i < 12; i++) {
          final ph = ((_time * 0.5 + i / 12) % 1.0);
          final base =
              centre + Offset(cos(i * 0.52) * r * 0.6, sin(i * 0.52) * r * 0.4);
          final spine = [
            for (var k = 0; k <= 5; k++)
              base + Offset(5 * sin(_time * 2 + k + i), -k * 14 - ph * 40),
          ];
          canvas.drawPath(
            vfxRibbon(spine, 5, 0.5),
            Paint()..color = _gHeat.withValues(alpha: 0.2 * w * sin(ph * pi)),
          );
        }
      case Climate.dark:
        // The dark closes in from the walls toward the flower.
        final inner = max(40.0, 700 * (1 - w) + 160);
        canvas.drawRect(
          b,
          Paint()
            ..shader = ui.Gradient.radial(
              centre,
              inner + 420,
              [
                const Color(0xFF05070A).withValues(alpha: 0),
                const Color(0xFF05070A).withValues(alpha: 0.7 * w),
              ],
              [inner / (inner + 420), 1.0],
            ),
        );
    }
  }

  // ─────────────────────────────────────────────────────────
  // THE ROOT CELLAR (the vault)
  // ─────────────────────────────────────────────────────────

  void _renderCellar(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    canvas.drawPicture(
      _greenCache.putIfAbsent('cellar|${room.id}', () {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.drawRect(
          b,
          Paint()..color = const Color(0xFF0A0C08).withValues(alpha: 0.45),
        );
        // Roots hanging from the ceiling course.
        for (var i = 0; i < 9; i++) {
          final x = b.left + 40 + i * 58.0;
          final spine = [
            Offset(x, b.top + 40),
            Offset(x + 10 * sin(i * 1.7), b.top + 90),
            Offset(x - 6 * sin(i * 2.3), b.top + 120 + (i % 3) * 20),
          ];
          c.drawPath(vfxRibbon(spine, 8, 1), Paint()..color = _gBark);
          c.drawPath(
            vfxRibbon(
              [for (final p in spine) p + const Offset(-2.6, 0)],
              1.4,
              0.4,
            ),
            Paint()..color = _gBarkLit.withValues(alpha: 0.45),
          );
        }
        // Shelves of old seed jars along the south wall.
        for (var i = 0; i < 6; i++) {
          final p = Offset(b.left + 180 + i * 56.0, b.bottom - 60);
          paintCarvedBlock(
            c,
            Rect.fromCenter(
              center: p + const Offset(0, 16),
              width: 50,
              height: 10,
            ),
            4,
            _kVerdantGlass,
          );
          paintPane(
            c,
            Path()..addRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: p, width: 26, height: 34),
                const Radius.circular(8),
              ),
            ),
            // Dark, old glass: a shelf of jars, not a row of tablets.
            Color.lerp(_kVerdantGlass.frostAt(i), Colors.black, 0.22)!,
            _kVerdantGlass,
            lead: 2,
          );
        }
        // The stair up.
        final stair = room.doors.first.rect;
        c.drawRect(stair, Paint()..color = const Color(0xFF050604));
        for (var i = 0; i < 4; i++) {
          c.drawRect(
            Rect.fromLTWH(
              stair.left + 4,
              stair.top + 6 + i * 12,
              stair.width - 8,
              6,
            ),
            Paint()
              ..color = _kVerdantGlass.stoneTop.withValues(
                alpha: 0.8 - i * 0.15,
              ),
          );
        }
        return rec.endRecording();
      }),
    );
  }
}
