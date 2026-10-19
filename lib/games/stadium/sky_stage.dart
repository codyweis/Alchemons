// lib/games/stadium/sky_stage.dart
//
// The night sky as it is watched (the Sapphire Cup's bouts, sky_rules.dart):
// the three on a dark ridge, each one's figure hung faint above it in stars,
// and the casts one after another, round by round — the grains drawn off
// the caster's body, let loose up into the sky the way its family's special
// goes (a Wing's beam, a Pip's ricochet, a Horn's surge, a Mane's lob, a
// Let's meteors falling back, a Mask's seed that opens, a Kin's motes, a
// Mystic's orbit), and parting at the top: those that catch become stars in
// its figure, the rest drift on and go out. At the end the fullest figure
// burns brighter and the others dim.
//
// The nights look their own way:
//   · CLEAR NIGHT — a thin moon, the ridge, the sky.
//   · MIRROR LAKE — the three stand on a low bank over a still lake that
//     holds the whole sky turned over: the stars shimmering, a path of
//     moonlight, the three and their figures. Every cast goes down into the
//     water as it goes up into the sky; one that stands apart lights its
//     stars again in the water, one drowned out sinks there and goes dark.
//   · FUSION SKY — each round the sky holds an element: a veil of its
//     grains drawn across the sky between the three and their figures
//     (Lightning flickering in forks, Dark swallowing the stars behind it,
//     Light rising warm). A cast that fuses with it flares through as what
//     the two make and lights its stars in that colour; one with no recipe
//     goes through dim.
//
// SkyPainter draws it in grains on a dark sky, like everything else. The
// whole night is worked out before the first cast (SkyContest); the stage
// is only a clock — with friends ([BoutLive]), kept to the shared gun, the
// same stars lit on every phone, each with its own player in the middle.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:alchemons/games/stadium/bout_stage.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_painter.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/games/stadium/sky_rules.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';

/// How a family's special goes up into the sky.
enum SkyGesture {
  /// Wing: a beam, straight and quick.
  beam(0.45),

  /// Pip: an orb ricocheting up between walls no one sees.
  ricochet(0.85),

  /// Horn: a heavy surge, slow to start.
  surge(0.9),

  /// Mane: lobbed high and over.
  lob(0.85),

  /// Let: up past the top, then falling back as meteors.
  meteors(0.55),

  /// Mask: a seed that rises, holds, and opens.
  bloom(0.8),

  /// Kin: loose motes drifting up.
  motes(1.0),

  /// Mystic: grains orbiting as they rise.
  orbit(0.9);

  const SkyGesture(this.rise);

  /// Seconds from the caster to the top.
  final double rise;
}

SkyGesture skyGestureOf(String family) => switch (family.toLowerCase()) {
  'wing' => SkyGesture.beam,
  'pip' => SkyGesture.ricochet,
  'horn' => SkyGesture.surge,
  'mane' => SkyGesture.lob,
  'let' => SkyGesture.meteors,
  'mask' => SkyGesture.bloom,
  'mystic' => SkyGesture.orbit,
  _ => SkyGesture.motes,
};

final Map<String, Color> _skyColors = {};

/// An element's colour as the night shows it: the darkest (Dark, Mud)
/// lifted toward a pale violet so they are seen on a dark sky at all.
Color skyColorOf(String element) => _skyColors.putIfAbsent(element, () {
  final c = elementColor(element);
  return c.computeLuminance() < 0.07
      ? Color.lerp(c, const Color(0xFFE6E0F6), 0.34)!
      : c;
});

/// One's figure in the sky: its sprite read into grains, hung faint, and
/// [kSkyFigureStars] of those grains picked out as its stars — each next
/// one as far as it can be from those before, so the first lit are spread
/// over the whole of it. Every grain belongs to its nearest star, and wakes
/// (in the sprite's own colours) when that star lights. In world pixels
/// about its centre, facing right.
class SkyFigure {
  SkyFigure._(
    this.gx,
    this.gy,
    this.gTone,
    this.tones,
    this.owner,
    this.band,
    this.x,
    this.y,
    this.width,
    this.height,
    this.step,
  );

  /// Every grain, its colour (an index into [tones]) and its star.
  final Float32List gx, gy;
  final Uint8List gTone;
  final List<Color> tones;
  final Uint16List owner;

  /// How far each grain is from its star, in thirds of the way to the edge
  /// of the star's patch (0 nearest): its light falls off.
  final Uint8List band;

  /// The stars, in the order they light.
  final Float32List x, y;
  final double width, height;

  /// The space between grains.
  final double step;

  int get length => x.length;

  factory SkyFigure.of(SpecimenGrains? g) {
    if (g == null || g.length < kSkyFigureStars) return SkyFigure._disc();
    final n = g.length;
    final dist = Float64List(n)..fillRange(0, n, double.infinity);
    final owner = Uint16List(n);
    final order = <int>[];
    void take(int i) {
      final k = order.length;
      order.add(i);
      for (var j = 0; j < n; j++) {
        final dx = g.hx[j] - g.hx[i], dy = g.hy[j] - g.hy[i];
        final d = dx * dx + dy * dy;
        if (d < dist[j]) {
          dist[j] = d;
          owner[j] = k;
        }
      }
    }

    // Start at the top, then always the grain furthest from every star.
    var top = 0;
    for (var j = 1; j < n; j++) {
      if (g.hy[j] < g.hy[top]) top = j;
    }
    take(top);
    while (order.length < kSkyFigureStars) {
      var best = 0;
      for (var j = 1; j < n; j++) {
        if (dist[j] > dist[best]) best = j;
      }
      if (dist[best] <= 0) break;
      take(best);
    }

    final reach = Float64List(order.length);
    for (var j = 0; j < n; j++) {
      reach[owner[j]] = max(reach[owner[j]], dist[j]);
    }
    final band = Uint8List(n);
    for (var j = 0; j < n; j++) {
      final r = reach[owner[j]];
      final f = r <= 0 ? 0.0 : sqrt(dist[j] / r);
      band[j] = f < 0.45 ? 0 : (f < 0.78 ? 1 : 2);
    }

    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (var j = 0; j < n; j++) {
      minX = min(minX, g.hx[j]);
      maxX = max(maxX, g.hx[j]);
      minY = min(minY, g.hy[j]);
      maxY = max(maxY, g.hy[j]);
    }
    final mx = (minX + maxX) / 2, my = (minY + maxY) / 2;
    final gx = Float32List(n), gy = Float32List(n);
    for (var j = 0; j < n; j++) {
      gx[j] = g.hx[j] - mx;
      gy[j] = g.hy[j] - my;
    }
    return SkyFigure._(
      gx,
      gy,
      g.tone,
      g.tones,
      owner,
      band,
      Float32List.fromList([for (final i in order) gx[i]]),
      Float32List.fromList([for (final i in order) gy[i]]),
      max(1, maxX - minX),
      max(1, maxY - minY),
      g.step,
    );
  }

  /// No sprite to read: a round cluster of its own stars.
  factory SkyFigure._disc() {
    const n = kSkyFigureStars;
    final x = Float32List(n), y = Float32List(n);
    for (var i = 0; i < n; i++) {
      final r = 14 * sqrt((i + 0.5) / n);
      final a = i * 2.39996;
      x[i] = cos(a) * r;
      y[i] = sin(a) * r;
    }
    return SkyFigure._(
      x,
      y,
      Uint8List(n),
      const [Color(0xFFB8C4E0)],
      Uint16List.fromList([for (var i = 0; i < n; i++) i]),
      Uint8List(n),
      x,
      y,
      28,
      28,
      2,
    );
  }
}

/// When one cast happens: its start, when the grains leave the caster, and
/// the first figure slot its stars fill.
class SkyCastTime {
  SkyCastTime(this.index, this.cast, this.gesture, this.start, this.slot0);

  final int index;
  final SkyCast cast;
  final SkyGesture gesture;
  final double start;
  final int slot0;

  static const double gather = 0.45, spread = 0.65;

  double get release => start + gather;

  /// A grain's own lag behind the first out of the caster.
  double lag(int g) => switch (gesture) {
    SkyGesture.beam => g / kSkyCastGrains * 0.26,
    SkyGesture.motes => hash01(g, 951 + index) * 0.4,
    SkyGesture.orbit => g / kSkyCastGrains * 0.12,
    SkyGesture.surge => hash01(g, 951 + index) * 0.1,
    _ => hash01(g, 951 + index) * 0.06,
  };

  /// When grain [g] reaches the top of its flight, and when it settles.
  double arrive(int g) =>
      release + lag(g) + gesture.rise + (gesture == SkyGesture.bloom ? 0.2 : 0);

  double settleSeconds(int g) =>
      (gesture == SkyGesture.meteors ? 0.8 : spread) +
      hash01(g, 952 + index) * (gesture == SkyGesture.meteors ? 0.3 : 0.2);

  double land(int g) => arrive(g) + settleSeconds(g);

  /// The last of its grains settled.
  late final double done = () {
    var t = start;
    for (var g = 0; g < kSkyCastGrains; g++) {
      t = max(t, land(g) + 0.6);
    }
    return t;
  }();
}

enum SkyStagePhase { intro, casting, finale, done }

/// Each one's figure, read finely off its sprite (load the bodies first).
Future<List<SkyFigure>> loadSkyFigures(List<RaceBody> bodies) async => [
  for (final b in bodies) SkyFigure.of(await b.readFiner() ?? b.grains),
];

class SkyStage extends ChangeNotifier implements BoutStage {
  SkyStage({
    required this.bout,
    required this.fighters,
    required this.bodies,
    required this.player,
    List<SkyFigure>? figures,
    this.live,
  }) : contest = SkyContest(bout, fighters, last: player) {
    this.figures = figures ?? [for (final b in bodies) SkyFigure.of(b.grains)];
    gestures = [for (final b in bodies) skyGestureOf(b.member.family)];
    final n = fighters.length;
    final rounds = bout.rounds.length;
    final cursor = List.filled(n, 0);
    Float64List never() =>
        Float64List(kSkyFigureStars)..fillRange(0, kSkyFigureStars, 1e9);
    slotLand = [for (var i = 0; i < n; i++) never()];
    waterLand = [for (var i = 0; i < n; i++) never()];
    slotRound = [for (var i = 0; i < n; i++) Uint8List(kSkyFigureStars)];
    castOf = [for (var i = 0; i < n; i++) List.filled(rounds, 0)];
    final gap = bout.elements.isEmpty ? roundGap : skyRoundGap;
    for (var k = 0; k < contest.casts.length; k++) {
      final c = contest.casts[k];
      final start = introSeconds + k * castGap + (k ~/ n) * gap;
      final ct = SkyCastTime(
        k,
        c,
        gestures[c.fighter],
        start,
        cursor[c.fighter],
      );
      times.add(ct);
      castOf[c.fighter][c.round] = k;
      for (var g = 0; g < c.stars; g++) {
        final s = ct.slot0 + g;
        if (s >= kSkyFigureStars) break;
        slotLand[c.fighter][s] = ct.land(g);
        slotRound[c.fighter][s] = c.round;
        if (g < c.water) waterLand[c.fighter][s] = ct.land(g);
      }
      cursor[c.fighter] += c.stars;
    }
    ownColor = [for (final b in bodies) skyColorOf(b.member.element)];
    castColor = [
      for (final c in contest.casts)
        switch ((c.sky, c.made)) {
          (null, _) => ownColor[c.fighter],
          (_, final made?) => skyColorOf(made),
          _ => Color.lerp(ownColor[c.fighter], const Color(0xFF7C8294), 0.6)!,
        },
    ];
    apart = [for (var i = 0; i < n; i++) bout.lake && contest.apart(i)];
    finaleAt = times.fold(0.0, (t, c) => max(t, c.done)) - 0.3;
    _said = List.filled(times.length, 0);
  }

  final SkyBout bout;
  final List<Racer> fighters;
  final List<RaceBody> bodies;
  @override
  final int player;

  /// Set for a night with friends.
  final BoutLive? live;
  final SkyContest contest;
  late final List<SkyFigure> figures;
  late final List<SkyGesture> gestures;
  final List<SkyCastTime> times = [];

  /// When each figure slot lights in the sky, and in the lake, by stage
  /// clock (far off if it never does), and which round lit it.
  late final List<Float64List> slotLand, waterLand;
  late final List<Uint8List> slotRound;

  /// Each one's cast in each round (an index into [times]).
  late final List<List<int>> castOf;

  /// Each one's own colour, and each cast's once it is up (what a fusion
  /// made, or its own gone dim).
  late final List<Color> ownColor, castColor;

  /// Whether each one's colours stand apart (its casts light in the lake).
  late final List<bool> apart;

  static const double introSeconds = 2.2, castGap = 1.25, roundGap = 0.55;

  /// Between the Fusion Sky's rounds: long enough for the sky to change.
  static const double skyRoundGap = 0.95;

  /// How long the finale holds before the results.
  static const double finaleSeconds = 3.0;

  late final double finaleAt;
  @override
  double clock = 0;
  late final List<int> _said;
  bool _wonSaid = false;

  @override
  final List<BoutSound> sounds = [];

  SkyStagePhase get phase {
    if (clock < introSeconds) return SkyStagePhase.intro;
    if (clock < finaleAt) return SkyStagePhase.casting;
    if (clock < finaleAt + finaleSeconds) return SkyStagePhase.finale;
    return SkyStagePhase.done;
  }

  /// How far into the finale, 0..1.
  double get finaleT => ((clock - finaleAt) / 1.4).clamp(0.0, 1.0);

  /// When round [r]'s first cast starts.
  double roundStart(int r) => times[r * fighters.length].start;

  /// The round under way: from its first cast to the next round's.
  int? get round {
    if (clock < introSeconds - 0.4 || clock >= finaleAt) return null;
    final n = fighters.length;
    var r = 0;
    for (var k = 0; k < times.length; k += n) {
      if (clock >= times[k].start - 0.4) r = k ~/ n;
    }
    return r;
  }

  /// How fully the sky holds round [r]'s element now, 0..1 (the Fusion
  /// Sky): drawn in before the round's first cast, given over to the next
  /// round's before its first.
  double skyHolds(int r) {
    var a = _smooth((clock - (roundStart(r) - 1.15)) / 0.9);
    if (r + 1 < bout.rounds.length) {
      a *= 1 - _smooth((clock - (roundStart(r + 1) - 1.15)) / 0.9);
    } else if (phase.index >= SkyStagePhase.finale.index) {
      a *= 1 - 0.6 * finaleT;
    }
    return a;
  }

  /// Stars [i] has lit by now, in the sky and in the water.
  int litNow(int i) {
    var n = 0;
    for (final t in slotLand[i]) {
      if (t <= clock) n++;
    }
    for (final t in waterLand[i]) {
      if (t <= clock) n++;
    }
    return n;
  }

  // ── what the bout screen reads ──

  @override
  bool get done => phase == SkyStagePhase.done;
  @override
  List<int> get standings => contest.standings;
  @override
  bool get hasAction => false;
  @override
  bool get canAct => false;
  @override
  int get actsLeft => 0;
  @override
  bool act() => false;
  @override
  double? get actPour => null;
  @override
  String get actLabel => '';
  @override
  String? get caption {
    final r = round;
    if (r == null) return null;
    final word = switch (bout.rounds[r]) {
      CosmicContestTrait.speed => 'SPEED',
      CosmicContestTrait.strength => 'STRENGTH',
      CosmicContestTrait.intelligence => 'INTELLIGENCE',
      CosmicContestTrait.beauty => 'BEAUTY',
    };
    final sky = bout.skyOf(r);
    return 'ROUND ${r + 1} OF ${bout.rounds.length} · $word'
        '${sky != null ? ' · ${sky.toUpperCase()}' : ''}';
  }

  @override
  String? tagOf(int i) {
    final n = litNow(i);
    return n > 0 ? '$n' : null;
  }

  @override
  bool dimmed(int i) => false;
  @override
  String headline(int place) => place == 1 ? 'THE MOST STARS' : 'OUTSHONE';
  @override
  String? get note => null;

  /// The stars the player lit.
  @override
  double? get mark => contest.starsOf(player).toDouble();
  @override
  String? resultOf(int i) => '${contest.starsOf(i)} STARS';
  @override
  late final CustomPainter painter = SkyPainter(this);

  /// Nothing to tap under the night sky.
  @override
  List<int> get myTaps => const [];
  @override
  void mergeTaps(int i, List<int> ticks) {}

  @override
  void advance(double dt) {
    dt = min(dt, 0.1);
    clock += dt;
    // With friends, the first cast goes up on the gun.
    if (live case final live?) {
      clock = max(clock - dt, introSeconds - live.toGun);
      if (clock < 0) clock = 0;
    }
    for (final t in times) {
      final said = _said[t.index];
      if (said == 0 && clock >= t.release) {
        _said[t.index] = 1;
        sounds.add(BoutSound.cast);
      } else if (said == 1 &&
          clock >= t.land(0) &&
          t.cast.fighter == player &&
          t.cast.stars > 0) {
        _said[t.index] = 2;
        sounds.add(BoutSound.land);
      }
    }
    if (done && !_wonSaid) {
      _wonSaid = true;
      sounds.add(BoutSound.win);
    }
    notifyListeners();
  }
}

// ── the painter ─────────────────────────────────────────────────────────────

double _smooth(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _easeInOut(double x) {
  final t = x.clamp(0.0, 1.0);
  return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2;
}

double _easeOut(double x) {
  final t = 1 - x.clamp(0.0, 1.0);
  return 1 - t * t * t;
}

/// Where everything is on a screen of one size.
class _Layout {
  _Layout(Size size, SkyStage s)
    : w = size.width,
      h = size.height,
      lake = s.bout.lake {
    k0 = min(w / 475, h / 751);
    body = k0 * 1.85;
    ridgeBase = lake ? 0.655 : 0.835;
    water = h * 0.69;
    veilY = h * 0.605;
    veilBand = h * 0.028;
    final n = s.fighters.length;
    final cols = _cols(n);
    // The player in the first column (the middle), the rest in turn after.
    colX = [for (var i = 0; i < n; i++) w * cols[(i - s.player + n) % n]];
    feet = [for (final x in colX) Offset(x, ridgeY(x) + 3 * k0)];
    centre = [
      for (var i = 0; i < n; i++)
        feet[i].translate(0, -s.bodies[i].height * body * 0.5),
    ];
    head = [
      for (var i = 0; i < n; i++)
        feet[i].translate(0, -s.bodies[i].height * body * 1.05),
    ];
    final boxW = w * 0.29, boxH = h * (lake ? 0.19 : 0.22);
    fig = [for (final x in colX) Offset(x, h * (lake ? 0.315 : 0.4))];
    figScale = [
      for (final f in s.figures) min(boxW / f.width, boxH / f.height),
    ];
    figR = [
      for (var i = 0; i < n; i++)
        max(s.figures[i].width, s.figures[i].height) * figScale[i] * 0.5,
    ];
  }

  final double w, h;

  /// The Mirror Lake: the ridge a low bank over the water.
  final bool lake;
  late final double k0, body, ridgeBase;

  /// The lake's far edge, where the sky turns over (the Mirror Lake).
  late final double water;

  /// Where the Fusion Sky's element hangs, and how deep.
  late final double veilY, veilBand;
  late final List<double> colX, figScale, figR;
  late final List<Offset> feet, centre, head, fig;

  /// How much the lake squeezes what it shows (a shallow look down at it).
  static const double squash = 0.62;

  /// The player in the middle, the others either side.
  static List<double> _cols(int n) => n == 3
      ? const [0.5, 0.18, 0.82]
      : [for (var i = 0; i < n; i++) (i + 0.5) / n];

  /// The ridge's top at [x].
  double ridgeY(double x) =>
      h * ridgeBase +
      (7 * sin(x / w * 5.1 + 1.1) + 4 * sin(x / w * 13.3 + 2.4)) * k0;

  /// Where the lake shows a point in the sky at [y].
  double down(double y) => water + (water - y) * squash;

  /// How the water sways what it shows at [y] (in the lake), now: more the
  /// nearer it is.
  double sway(double y, double t, [double seed = 0]) {
    final depth = ((y - water) / (h - water)).clamp(0.0, 1.0);
    return sin(t * 1.15 + y * 0.11 + seed) * (0.5 + 3.2 * depth) * k0;
  }

  static const int _swayRows = 192;
  Float32List? _swayAt;
  double _swayT = double.nan;

  /// [sway] with no seed, looked up by row (a figure in the water has
  /// thousands of grains, and a row sways as one).
  double swayRow(double y, double t) {
    var rows = _swayAt;
    if (rows == null || _swayT != t) {
      rows = _swayAt ??= Float32List(_swayRows);
      _swayT = t;
      for (var r = 0; r < _swayRows; r++) {
        rows[r] = sway(water + (r + 0.5) / _swayRows * (h - water), t);
      }
    }
    final r = ((y - water) / (h - water) * _swayRows).floor();
    return rows[r.clamp(0, _swayRows - 1)];
  }

  Offset slot(SkyStage s, int i, int k) {
    final f = s.figures[i];
    return fig[i] + Offset(f.x[k], f.y[k]) * figScale[i];
  }
}

/// The grain buckets of one cast: three colour sets (its own, once through
/// the Fusion Sky's element, and in the element) of eight each — the
/// grain by brightness (0–2), its trail (3–5), the loose grains about it
/// (6–7) — then its reflection in the lake: the grain by brightness, its
/// trail, and the grains sinking.
const int _setSize = 8;
const int _reflHead = _setSize * 3, _reflTrail = _reflHead + 3;
const int _sinkNear = _reflTrail + 3, _sinkFar = _sinkNear + 1;
const int _castBuckets = _sinkFar + 1;

class SkyPainter extends CustomPainter {
  SkyPainter(this.stage) : super(repaint: stage);

  final SkyStage stage;
  static final GrainBatch _b = GrainBatch(8);
  static final GrainBatch _bCast = GrainBatch(_castBuckets);
  static final GrainBatch _bFig = GrainBatch(
    SpecimenGrains.toneCount * 3 + 4 + kSkyRoundCount * 3 + 2,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final s = stage;
    final L = _Layout(size, s);
    final t = s.clock;
    _sky(canvas, size, L, t);
    if (s.bout.elements.isNotEmpty) _veils(canvas, L, t);
    for (var i = 0; i < s.figures.length; i++) {
      _figure(canvas, L, i, t);
    }
    if (L.lake) {
      _lake(canvas, size, L, t);
      for (var i = 0; i < s.figures.length; i++) {
        _figure(canvas, L, i, t, inWater: true);
      }
      for (var i = 0; i < s.bodies.length; i++) {
        _caster(canvas, L, i, t, inWater: true);
      }
    }
    _ridge(canvas, size, L, t);
    for (var i = 0; i < s.bodies.length; i++) {
      _caster(canvas, L, i, t);
    }
    for (final ct in s.times) {
      if (t < ct.start || t > ct.done) continue;
      _cast(canvas, L, ct, t);
    }
  }

  // ── the sky ──

  /// One of the sky's own stars: where, and whether it is a bright one.
  static (double, double, bool) _star(_Layout L, int g) => (
    hash01(g, 971) * L.w,
    pow(hash01(g, 972), 1.25) * L.h * 0.82,
    hash01(g, 974) < 0.14,
  );

  static const int _starCount = 260;

  void _sky(Canvas c, Size size, _Layout L, double t) {
    final night = stage.bout.night;
    final w = L.w, h = L.h;
    final top = switch (night) {
      SkyNight.fusion => const Color(0xFF04050C),
      _ => const Color(0xFF05070F),
    };
    final low = switch (night) {
      SkyNight.fusion => const Color(0xFF0A0F22),
      SkyNight.mirror => const Color(0xFF101834),
      SkyNight.clear => const Color(0xFF0E1530),
    };
    c.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, L.lake ? L.water : h * 0.86),
          [top, Color.lerp(top, low, 0.45)!, low],
          const [0.0, 0.6, 1.0],
        ),
    );
    final fade = _smooth(t / 1.4);

    // A faint band of the far galaxy, corner to corner.
    final b = _b..clear();
    for (var g = 0; g < 620; g++) {
      final u = hash01(g, 961);
      final across = (hash01(g, 962) + hash01(g, 963) + hash01(g, 964) - 1.5);
      final x = -w * 0.1 + u * w * 1.2;
      final y = h * 0.62 - u * h * 0.5 + across * 70 * L.k0;
      b.add(hash01(g, 965) < 0.12 ? 1 : 0, x, y);
    }
    b.draw(
      c,
      0,
      1.1 * L.k0,
      const Color(0xFF9FB0D8).withValues(alpha: 0.16 * fade),
    );
    b.draw(
      c,
      1,
      1.5 * L.k0,
      const Color(0xFFD8E0F4).withValues(alpha: 0.3 * fade),
    );

    // The stars that are only the sky's.
    b.clear();
    for (var g = 0; g < _starCount; g++) {
      final (x, y, big) = _star(L, g);
      final tw = sin(t * (0.4 + 1.1 * hash01(g, 973)) + g * 1.7);
      b.add(big ? (tw > 0.2 ? 2 : 3) : (tw > -0.3 ? 0 : 3), x, y);
    }
    _drawStars(c, b, L, fade);

    if (night != SkyNight.fusion) _moon(c, L, fade);
  }

  void _drawStars(Canvas c, GrainBatch b, _Layout L, double a) {
    b.draw(
      c,
      3,
      0.9 * L.k0,
      const Color(0xFFDDE4F2).withValues(alpha: 0.18 * a),
    );
    b.draw(
      c,
      0,
      1.1 * L.k0,
      const Color(0xFFDDE4F2).withValues(alpha: 0.42 * a),
    );
    b.draw(
      c,
      2,
      1.7 * L.k0,
      const Color(0xFFF4F6FC).withValues(alpha: 0.8 * a),
    );
  }

  /// The moon: high in the corner, or on the lake's night between the
  /// middle and right figures, so its light on the water falls between
  /// theirs.
  Offset _moonAt(_Layout L) =>
      L.lake ? Offset(L.w * 0.665, L.h * 0.19) : Offset(L.w * 0.84, L.h * 0.16);

  /// A thin moon high in the corner: a pale crescent in a soft halo, with
  /// the rest of its disc only just there.
  void _moon(Canvas c, _Layout L, double fade) {
    final at = _moonAt(L);
    final r = 13 * L.k0;
    c.drawCircle(
      at,
      r * 6,
      Paint()
        ..shader = ui.Gradient.radial(
          at,
          r * 6,
          [
            const Color(0xFFBFCBE6).withValues(alpha: 0.09 * fade),
            const Color(0xFFBFCBE6).withValues(alpha: 0.025 * fade),
            const Color(0x00BFCBE6),
          ],
          const [0.0, 0.4, 1.0],
        ),
    );
    c.drawCircle(
      at,
      r,
      Paint()..color = const Color(0xFF1A2236).withValues(alpha: 0.55 * fade),
    );
    final lit = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: at, radius: r)),
      Path()..addOval(
        Rect.fromCircle(
          center: at.translate(-r * 0.38, -r * 0.16),
          radius: r * 0.9,
        ),
      ),
    );
    c.drawPath(
      lit,
      Paint()
        ..shader =
            ui.Gradient.linear(at.translate(-r, -r), at.translate(r, r), [
              const Color(0xFFF4F1E6).withValues(alpha: 0.95 * fade),
              const Color(0xFFC9D2E6).withValues(alpha: 0.8 * fade),
            ]),
    );
  }

  // ── the Fusion Sky's elements ──

  void _veils(Canvas c, _Layout L, double t) {
    final els = stage.bout.elements;
    for (var r = 0; r < els.length; r++) {
      final a = stage.skyHolds(r);
      if (a > 0.01) _veil(c, L, els[r], r, a, t);
    }
  }

  /// The element a round's sky holds: a cloud of its grains drawn across
  /// the sky, thicker in places, drifting, each element moving its own way
  /// (Lightning forking, Dark in slow eddies, Light rising), over soft
  /// glows of its colour — Dark's a shadow that swallows the stars behind.
  void _veil(Canvas c, _Layout L, String el, int r, double a, double t) {
    final col = skyColorOf(el);
    final dark = el == 'Dark';
    final hot = Color.lerp(col, Colors.white, dark ? 0.62 : 0.45)!;
    final w = L.w, k = L.k0, y0 = L.veilY, band = L.veilBand;
    final dir = r.isEven ? 1.0 : -1.0;
    // Its line wanders, and it swells and thins along it.
    double mid(double x) =>
        y0 +
        band * 0.75 * sin(x / w * 2.6 + r * 1.7 + t * 0.05 * dir) +
        band * 0.3 * sin(x / w * 6.1 + r);
    double thick(double x) =>
        band *
        (0.5 + 0.55 * (0.5 + 0.5 * sin(x / w * 4.3 + r * 2.1 - t * 0.09)));

    // The glows: a few soft clouds along it, drifting.
    void cloud(double cx, double rx, double ry, Color tint, double alpha) {
      c.save();
      c.translate(cx, mid(cx));
      c.scale(1, ry / rx);
      c.drawCircle(
        Offset.zero,
        rx,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            rx,
            [
              tint.withValues(alpha: alpha),
              tint.withValues(alpha: alpha * 0.4),
              tint.withValues(alpha: 0),
            ],
            const [0.0, 0.5, 1.0],
          ),
      );
      c.restore();
    }

    for (var q = 0; q < 5; q++) {
      final cx =
          ((hash01(q, 1121 + r) + q * 0.2 + t * 0.006 * dir) % 1.0) * w * 1.3 -
          w * 0.15;
      final rx = w * (0.15 + 0.1 * hash01(q, 1122 + r));
      final ry = band * (1.7 + 1.3 * hash01(q, 1123 + r));
      if (dark) {
        cloud(cx, rx * 1.2, ry * 1.6, const Color(0xFF010004), 0.88 * a);
        cloud(cx, rx * 1.3, ry * 2.1, col, 0.08 * a);
      } else {
        cloud(cx, rx, ry, col, (el == 'Light' ? 0.13 : 0.1) * a);
      }
    }

    final b = _b..clear();
    const n = 420;
    for (var g = 0; g < n; g++) {
      final h1 = hash01(g, 1101 + r * 7), h2 = hash01(g, 1102 + r * 7);
      final h3 = hash01(g, 1103 + r * 7), h4 = hash01(g, 1104 + r * 7);
      final x0 = h1 * (w + 40) + t * (4 + 7 * h3) * k * dir;
      final x = x0 % (w + 40) - 20;
      // Thick in its middle, thin at its edges.
      final across = (h2 + h3 + h4 - 1.5) / 1.5;
      var y = mid(x) + across * thick(x);
      var bright = 0;
      switch (el) {
        case 'Lightning':
          // Forks: it jags across the sky, slowly re-forking, and brightens
          // where the light runs along it.
          final u = x / w * 6 + t * 0.28 + (across > 0 ? 0.5 : 0);
          final tri = 2 * (u - u.floorToDouble()) - 1;
          y += (tri.abs() * 2 - 1) * thick(x) * 0.8;
          final run = sin(x / w * 9 - t * 1.6 + r);
          bright = run > 0.6 ? 2 : (run > -0.25 ? 1 : 0);
        case 'Dark':
          // Slow eddies at the edges of the shadow.
          final th = h1 * 2 * pi + t * (0.25 + 0.3 * h4) * dir;
          y += sin(th) * band * 0.5 + across.sign * band * 0.35;
          bright = h4 < 0.16 ? 2 : (h4 < 0.55 ? 1 : 0);
        case 'Light':
          // Warmth rising off it and fading as it goes.
          final rise = (t * (0.16 + 0.1 * h4) + h2) % 1.0;
          y -= rise * band * 2.2;
          bright = rise < 0.3 ? 2 : (rise < 0.65 ? 1 : 0);
        default:
          y += sin(x / w * 6 + t * 0.5 + h4) * band * 0.4;
          bright = h4 < 0.15 ? 2 : (h4 < 0.55 ? 1 : 0);
      }
      b.add(bright, x, y);
    }
    b.draw(c, 0, 1.3 * k, col.withValues(alpha: (dark ? 0.45 : 0.28) * a));
    b.draw(c, 1, 1.6 * k, col.withValues(alpha: (dark ? 0.8 : 0.5) * a));
    b.draw(c, 2, 1.9 * k, hot.withValues(alpha: (dark ? 0.85 : 0.75) * a));
  }

  // ── the lake ──

  /// The Mirror Lake: the water, the sky's stars in it, a path of moonlight
  /// and the bank turned over.
  void _lake(Canvas c, Size size, _Layout L, double t) {
    final w = L.w, h = L.h, k = L.k0, wy = L.water;
    final fade = _smooth(t / 1.4);
    // The sky turned over: lighter where it meets the far bank, as the low
    // sky is, darker nearer.
    c.drawRect(
      Rect.fromLTRB(0, wy, w, h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, wy),
          Offset(0, h),
          const [Color(0xFF0C1330), Color(0xFF070A18), Color(0xFF030409)],
          const [0.0, 0.45, 1.0],
        ),
    );
    // The bank turned over.
    final bank = Path()..moveTo(0, wy);
    for (var x = 0.0; x <= w + 6; x += 6) {
      bank.lineTo(x, L.down(L.ridgeY(x)) + L.sway(L.down(L.ridgeY(x)), t));
    }
    bank
      ..lineTo(w, wy)
      ..close();
    c.drawPath(bank, Paint()..color = const Color(0xFF04050A));

    // The sky's stars in it, swaying.
    final b = _b..clear();
    for (var g = 0; g < _starCount; g++) {
      final (x, y, big) = _star(L, g);
      if (y >= wy) continue;
      final ry = L.down(y);
      if (ry > h) continue;
      final tw = sin(t * (0.6 + 1.3 * hash01(g, 973)) + g * 2.3);
      b.add(
        big ? (tw > 0.1 ? 2 : 3) : (tw > -0.2 ? 0 : 3),
        x + L.sway(ry, t, g * 0.7),
        ry,
      );
    }
    _drawStars(c, b, L, 0.5 * fade);

    // Moonlight on the water: glints in a path under the moon, wider and
    // sparser nearer, each a few grains side by side, coming and going.
    b.clear();
    final mx = _moonAt(L).dx;
    for (var j = 0; j < 90; j++) {
      final u = pow(hash01(j, 1201), 0.85).toDouble();
      final y = wy + 6 * k + u * (h - wy - 10 * k);
      final x =
          mx +
          (hash01(j, 1202) - 0.5) * (6 + 30 * u) * k +
          sin(t * 0.7 + j * 1.3) * 2.2 * k;
      final on = sin(t * (0.9 + 1.4 * hash01(j, 1203)) + j * 2.1);
      if (on < -0.35) continue;
      final bucket = on > 0.45 ? 1 : 0;
      final run = 1 + (hash01(j, 1204) * 3).floor();
      final gap = (1.3 + 1.2 * hash01(j, 1205)) * k;
      for (var q = 0; q < run; q++) {
        b.add(
          bucket,
          x + (q - run / 2) * gap,
          y + (hash01(j * 3 + q, 1206) - 0.5) * 0.8 * k,
        );
      }
    }
    // And a few loose glints across the rest of the water.
    for (var j = 0; j < 70; j++) {
      final y = wy + 4 * k + pow(hash01(j, 1211), 1.2) * (h - wy - 6 * k);
      final x =
          (hash01(j, 1212) * (w + 30) + t * (hash01(j, 1213) - 0.5) * 6 * k) %
              (w + 30) -
          15;
      final on = sin(t * (0.5 + hash01(j, 1214)) + j * 1.9);
      if (on < 0.2) continue;
      b.add(2, x, y);
      b.add(2, x + 1.7 * k, y);
    }
    b.draw(
      c,
      0,
      1.2 * k,
      const Color(0xFFE8E4D4).withValues(alpha: 0.16 * fade),
    );
    b.draw(
      c,
      1,
      1.4 * k,
      const Color(0xFFF2EEDF).withValues(alpha: 0.42 * fade),
    );
    b.draw(
      c,
      2,
      1.1 * k,
      const Color(0xFF9FB2E0).withValues(alpha: 0.14 * fade),
    );
  }

  // ── the ridge ──

  void _ridge(Canvas c, Size size, _Layout L, double t) {
    final w = L.w, h = L.h;
    // The ground's foot: the bottom of the screen, or the lake's edge.
    final foot = L.lake ? L.water + 1 : h;
    // A far ridge, a little lighter, for depth.
    final farY = h * (L.ridgeBase - 0.045);
    final far = Path()..moveTo(0, foot);
    for (var x = 0.0; x <= w + 8; x += 8) {
      far.lineTo(
        x,
        farY + (10 * sin(x / w * 3.3 + 0.4) + 6 * sin(x / w * 9.1)) * L.k0,
      );
    }
    far
      ..lineTo(w, foot)
      ..close();
    c.drawPath(far, Paint()..color = const Color(0xFF080B16));
    final near = Path()..moveTo(0, foot);
    for (var x = 0.0; x <= w + 6; x += 6) {
      near.lineTo(x, L.ridgeY(x));
    }
    near
      ..lineTo(w, foot)
      ..close();
    c.drawPath(
      near,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * (L.ridgeBase - 0.015)),
          Offset(0, foot),
          const [Color(0xFF05060B), Color(0xFF020204)],
        ),
    );
    // Grass along its top, caught here and there by the sky's light: a few
    // tufts of grains, standing up from the edge.
    final b = _b..clear();
    for (var g = 0; g < 220; g++) {
      final tuft = (hash01(g, 1001) * 26).floor();
      if (hash01(tuft, 1002) < 0.45) continue;
      final x = (tuft + 0.5) / 26 * w + (hash01(g, 1003) - 0.5) * 16 * L.k0;
      final up = pow(hash01(g, 1004), 1.6) * 7 * L.k0;
      b.add(up > 4 * L.k0 ? 1 : 0, x, L.ridgeY(x) + 1.5 * L.k0 - up);
    }
    final fade = _smooth(t / 1.4);
    b.draw(
      c,
      0,
      1.2 * L.k0,
      const Color(0xFF55648A).withValues(alpha: 0.4 * fade),
    );
    b.draw(
      c,
      1,
      1.2 * L.k0,
      const Color(0xFF9AA8CC).withValues(alpha: 0.35 * fade),
    );
  }

  // ── the three ──

  /// Its light on the ground while it casts, and the little lift it gives.
  /// [inWater]: its reflection in the lake instead, dimmer, and dimmer
  /// still for one drowned out.
  void _caster(Canvas c, _Layout L, int i, double t, {bool inWater = false}) {
    final s = stage;
    final col = s.ownColor[i];
    // Up onto the ridge one after another.
    final enter = _smooth((t - 0.5 - i * 0.25) / 0.9);
    if (enter <= 0) return;
    var glow = 0.0, lift = 0.0;
    for (final ct in s.times) {
      if (ct.cast.fighter != i) continue;
      final q = (t - ct.start) / SkyCastTime.gather;
      if (q < 0 || q > 3.6) continue;
      glow = max(glow, _smooth(q) * (1 - _smooth((q - 1.2) / 2.2)));
      lift = max(lift, sin(pi * q.clamp(0.0, 1.0)) * (q < 1 ? 1 : 0));
    }
    final ft = s.phase.index >= SkyStagePhase.finale.index ? s.finaleT : 0.0;
    final win = s.standings.first == i;
    glow = max(glow, win ? ft * 0.8 : 0);
    final feet = L.feet[i];
    if (inWater) {
      c.save();
      c.clipRect(Rect.fromLTRB(0, L.water, L.w, L.h));
      c.translate(sin(t * 0.8 + i) * 1.2 * L.k0, L.water);
      c.scale(1, -_Layout.squash);
      c.translate(0, -L.water);
    }
    if (glow > 0.01 && !inWater) {
      final r = 46 * L.k0;
      c.save();
      c.translate(feet.dx, feet.dy);
      c.scale(1, 0.32);
      c.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            r,
            [
              col.withValues(alpha: 0.42 * glow),
              col.withValues(alpha: 0.12 * glow),
              col.withValues(alpha: 0),
            ],
            const [0.0, 0.45, 1.0],
          ),
      );
      c.restore();
    }
    final dim = win ? 1.0 : 1 - 0.35 * ft;
    final water = inWater ? (s.apart[i] ? 0.3 : 0.14) : 1.0;
    paintRaceBody(
      c,
      s.bodies[i],
      L.centre[i].translate(0, (1 - enter) * 26 * L.k0 - lift * 5 * L.k0),
      L.body,
      t,
      alpha: enter * dim * water,
      squash: 1 + 0.05 * lift,
      lean: i == 1 ? 0.03 : -0.03,
      faceRight: i != 2,
    );
    if (inWater) c.restore();
  }

  // ── the figures ──

  /// One's figure in the sky, or (the Mirror Lake, [inWater]) as the lake
  /// shows it: turned over, swaying, its stars those its casts lit again in
  /// the water — a drowned one's left dark.
  void _figure(Canvas c, _Layout L, int i, double t, {bool inWater = false}) {
    final s = stage;
    final f = s.figures[i];
    final land = inWater ? s.waterLand[i] : s.slotLand[i];
    final rounds = s.slotRound[i];
    final own = s.ownColor[i];
    final ownStar = Color.lerp(own, Colors.white, 0.62)!;
    final ft = s.phase.index >= SkyStagePhase.finale.index ? s.finaleT : 0.0;
    final win = s.standings.first == i;
    final k0 = L.k0;
    final scale = L.figScale[i];
    final o = L.fig[i];
    final sq = _Layout.squash;
    final wy = L.water;
    // In the water: every other grain (the lake squeezes it), each swayed
    // by its row.
    final every = inWater ? 2 : 1;
    if (win && ft > 0) {
      final r = L.figR[i] * 1.5;
      final at = inWater ? Offset(o.dx, L.down(o.dy)) : o;
      c.save();
      c.translate(at.dx, at.dy);
      if (inWater) c.scale(1, sq);
      c.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            r,
            [
              own.withValues(alpha: (inWater ? 0.07 : 0.12) * ft),
              own.withValues(alpha: (inWater ? 0.025 : 0.04) * ft),
              own.withValues(alpha: 0),
            ],
            const [0.0, 0.55, 1.0],
          ),
      );
      c.restore();
    }
    // Buckets: three per sprite colour for the woken grains (nearest their
    // star first; one in the water), then the faint unwoken, two for grains
    // just waking, three twinkle groups of stars for each round (each
    // round's in its cast's colour), stars just lit, and (in the water) the
    // ripple a new star sends out.
    final tn = f.tones.length;
    final ghost = tn * 3, wake0 = ghost + 1, wake1 = ghost + 2;
    final star0 = ghost + 3, fresh = star0 + kSkyRoundCount * 3;
    final ripple = fresh + 1;
    final b = _bFig..clear();
    final ghostIn = (t - 0.9) / 1.4;
    for (var j = 0; j < f.gx.length; j += every) {
      final at = land[f.owner[j]];
      // Unlit in the water, barely there: every other one is enough.
      if (inWater && at > t && j & 2 != 0) continue;
      var x = o.dx + f.gx[j] * scale, y = o.dy + f.gy[j] * scale;
      if (inWater) {
        y = wy + (wy - y) * sq;
        x += L.swayRow(y, t);
      }
      if (at > t) {
        // Drawn in from the bottom of the figure up.
        final rise = 0.5 - f.gy[j] / f.height;
        if (ghostIn - rise * 0.6 > 0) b.add(ghost, x, y);
        continue;
      }
      final age = t - at;
      b.add(
        age < 0.25
            ? wake0
            : (age < 0.55 ? wake1 : f.gTone[j] * 3 + (inWater ? 0 : f.band[j])),
        x,
        y,
      );
    }
    var lit = 0;
    for (var k = 0; k < f.length; k++) {
      final at = land[k];
      if (at > t) continue;
      lit++;
      var p = L.slot(s, i, k);
      if (inWater) {
        final y = wy + (wy - p.dy) * sq;
        p = Offset(p.dx + L.swayRow(y, t), y);
      }
      final age = t - at;
      if (age < 0.45) {
        b.add(fresh, p.dx, p.dy);
      } else {
        b.add(
          star0 + rounds[k] * 3 + (hash01(k, 1011 + i) * 3).floor().clamp(0, 2),
          p.dx,
          p.dy,
        );
      }
      if (inWater && age < 0.9) {
        // A ring of grains spreading out on the water from it.
        final r = (2 + 13 * _easeOut(age / 0.9)) * k0;
        b.add(ripple, p.dx - r, p.dy);
        b.add(ripple, p.dx + r, p.dy);
        b.add(ripple, p.dx - r * 0.7, p.dy + r * 0.22);
        b.add(ripple, p.dx + r * 0.7, p.dy + r * 0.22);
      }
    }
    final grain =
        (f.step * scale * 0.8).clamp(1.0 * k0, 1.9 * k0) * (inWater ? 1.1 : 1);
    final water = inWater ? 0.6 : 1.0;
    // A drowned one's figure in the water is barely there.
    final ghostA = inWater ? (s.apart[i] ? 0.07 : 0.045) : 0.07;
    b.draw(
      c,
      ghost,
      grain * 0.8,
      const Color(
        0xFFB8C4E0,
      ).withValues(alpha: ghostA * _smooth(ghostIn) * (1 - ft)),
    );
    if (lit == 0) return;
    final bright = win ? 1 + 0.3 * ft : 1 - 0.55 * ft;
    const falloff = [0.62, 0.36, 0.16];
    for (var g = 0; g < tn; g++) {
      for (var d = 0; d < (inWater ? 1 : 3); d++) {
        b.draw(
          c,
          g * 3 + d,
          grain,
          f.tones[g].withValues(
            alpha: (falloff[d] * bright * water * (inWater ? 0.8 : 1)).clamp(
              0.0,
              1.0,
            ),
          ),
        );
      }
    }
    b.draw(c, wake0, grain, ownStar.withValues(alpha: 0.2 * water));
    b.draw(c, wake1, grain, ownStar.withValues(alpha: 0.4 * water));
    for (var r = 0; r < kSkyRoundCount && r < s.castOf[i].length; r++) {
      final k = s.castOf[i][r];
      final dim = s.times[k].cast.sky != null && s.times[k].cast.made == null;
      final star = Color.lerp(s.castColor[k], Colors.white, dim ? 0.3 : 0.6)!;
      for (var g = 0; g < 3; g++) {
        final tw = inWater
            ? 0.6 + 0.4 * sin(t * (2.1 + g * 0.9) + g * 1.7 + i + r)
            : 0.78 + 0.22 * sin(t * (1.3 + g * 0.6) + g * 2.1 + i + r);
        b.draw(
          c,
          star0 + r * 3 + g,
          2.5 * k0 * (win ? 1 + 0.15 * ft : 1) * (dim ? 0.85 : 1),
          star.withValues(
            alpha: (0.95 * tw * bright * water * (dim ? 0.6 : 1)).clamp(
              0.0,
              1.0,
            ),
          ),
        );
      }
    }
    b.draw(c, fresh, 3.0 * k0, Colors.white.withValues(alpha: 0.9 * water));
    b.draw(c, ripple, 1.3 * k0, ownStar.withValues(alpha: 0.35));
  }

  // ── a cast ──

  /// Where grain [g] of [ct] is at [t], and how bright; null when it is not
  /// drawn (not yet out, already a star, or gone out).
  (Offset, double)? _grain(_Layout L, SkyCastTime ct, int g, double t) {
    final s = stage;
    final i = ct.cast.fighter;
    final tau = t - ct.start;
    if (tau < 0) return null;
    final k = L.k0;
    final h1 = hash01(g, 1021 + ct.index), h2 = hash01(g, 1022 + ct.index);
    final h3 = hash01(g, 1023 + ct.index);
    final a = L.head[i];
    final lit = g < ct.cast.stars;
    final slot = ct.slot0 + g;
    if (lit && slot >= kSkyFigureStars) return null;

    // Drawn off its body into a knot over its head.
    if (t < ct.release) {
      final q = tau / SkyCastTime.gather;
      final ang = h1 * 2 * pi;
      final r = 15 * k * sqrt(h2);
      final from = L.centre[i] + Offset(cos(ang) * r, sin(ang) * r * 0.9);
      return (
        Offset.lerp(
          from,
          a + _knot(ct.gesture, h1, h2, k) * 0.45,
          _easeOut(q),
        )!,
        _smooth(q / 0.4) * 0.8,
      );
    }

    // Up into the sky.
    final arrive = ct.arrive(g);
    final fly = t - ct.release - ct.lag(g);
    final top = _flight(L, ct, g, 1, h1, h2, h3);
    if (t < arrive) {
      if (fly < 0) return (a + _knot(ct.gesture, h1, h2, k) * 0.45, 0.8);
      final u = (fly / ct.gesture.rise).clamp(0.0, 1.0);
      return (_flight(L, ct, g, u, h1, h2, h3), 1);
    }

    // Parting at the top: to its star, or on and out.
    final v = (t - arrive) / ct.settleSeconds(g);
    final target = lit ? L.slot(s, i, slot) : _lost(L, i, g, ct.index);
    if (lit && v >= 1) return null;
    var from = top;
    if (ct.gesture == SkyGesture.meteors) {
      final drop = target.dy + (30 + 50 * h3) * k;
      from = Offset(target.dx - drop * 0.42, target.dy - drop);
    }
    var e = ct.gesture == SkyGesture.meteors ? _easeOut(v) : _easeInOut(v);
    if (!lit) e = _easeOut(v);
    var p = Offset.lerp(from, target, e)!;
    if (ct.gesture == SkyGesture.bloom) {
      // The seed opens with a turn.
      final turn = (1 - e) * 1.5 * (i == 2 ? -1 : 1);
      final d = p - L.fig[i];
      p =
          L.fig[i] +
          Offset(
            d.dx * cos(turn) - d.dy * sin(turn),
            d.dx * sin(turn) + d.dy * cos(turn),
          );
    }
    if (lit) return (p, 1);
    // Those that do not catch drift on and go out.
    final out = (t - arrive) / (ct.settleSeconds(g) + 0.7);
    if (out >= 1) return null;
    final drift = max(0.0, t - arrive - ct.settleSeconds(g));
    return (
      p.translate((h1 - 0.5) * 20 * k * drift, -26 * k * drift),
      1 - _smooth(out),
    );
  }

  /// Where a grain that does not catch goes: on up past the figure, fanned
  /// out to one side more than the other, to go out there.
  Offset _lost(_Layout L, int i, int g, int cast) {
    final h1 = hash01(g, 1031 + cast), h2 = hash01(g, 1032 + cast);
    final lean = hash01(cast, 1033) - 0.5;
    return L.fig[i] +
        Offset(
          ((h1 - 0.5) * 1.6 + lean) * L.figR[i],
          -L.figR[i] * (0.7 + 0.9 * h2),
        );
  }

  /// A grain's place in the knot, about the knot's middle.
  Offset _knot(SkyGesture g, double h1, double h2, double k) {
    final ang = h1 * 2 * pi;
    final r = switch (g) {
      SkyGesture.surge => 18 * k,
      SkyGesture.motes => 10 * k,
      SkyGesture.orbit => 7 * k,
      _ => 4 * k,
    };
    return Offset(cos(ang) * r * sqrt(h2), sin(ang) * r * sqrt(h2) * 0.8);
  }

  /// Where grain [g] of [ct] is [u] of the way up its flight.
  Offset _flight(
    _Layout L,
    SkyCastTime ct,
    int g,
    double u,
    double h1,
    double h2,
    double h3,
  ) {
    final i = ct.cast.fighter;
    final a = L.head[i], b = L.fig[i];
    final k = L.k0;
    final colW = L.w * 0.16;
    // A lob arcs in toward the middle (the middle one's to the right).
    final side = a.dx > L.w * 0.55 ? -1.0 : 1.0;
    // The knot it gathered into loosens as it goes.
    final knot =
        _knot(ct.gesture, h1, h2, k) * (0.45 + 0.55 * _smooth(u / 0.3));
    switch (ct.gesture) {
      case SkyGesture.beam:
        final e = 1 - (1 - u) * (1 - u);
        return Offset.lerp(a, b, e)! + Offset((h1 - 0.5) * 2.4 * k, 0);
      case SkyGesture.ricochet:
        final x = u * 3 + 0.25;
        final tri = 4 * ((x - x.floorToDouble()) - 0.5).abs() - 1;
        return Offset(
              a.dx + (b.dx - a.dx) * u + tri * colW * 0.55 * (1 - 0.35 * u),
              a.dy + (b.dy - a.dy) * u,
            ) +
            knot;
      case SkyGesture.surge:
        final e = _easeInOut(u);
        final wobble = sin(u * 9 + h1 * 6) * 2.5 * k;
        return Offset.lerp(a, b, e)! +
            Offset(knot.dx * (1.2 - 0.4 * u) + wobble, knot.dy);
      case SkyGesture.lob:
        final e = 1 - (1 - u) * (1 - u);
        return Offset(
              a.dx + (b.dx - a.dx) * u + side * sin(pi * u) * colW * 0.6,
              a.dy + (b.dy - L.figR[i] * 0.3 - a.dy) * e,
            ) +
            knot * 0.7;
      case SkyGesture.meteors:
        final e = u * u;
        return Offset(
          a.dx + (b.dx - a.dx) * e + (h1 - 0.5) * 6 * k,
          a.dy + (-30 * k - a.dy) * e,
        );
      case SkyGesture.bloom:
        final e = _easeInOut(u);
        return Offset.lerp(a, b, e)! + knot;
      case SkyGesture.motes:
        final e = _easeInOut(u);
        final sway = sin(u * pi * 2.2 + h3 * 6) * 12 * k * (1 - 0.4 * u);
        return Offset.lerp(a, b, e)! + knot * (1 + u) + Offset(sway, 0);
      case SkyGesture.orbit:
        final e = _easeInOut(u);
        final th = h1 * 2 * pi + u * 4 * pi;
        final r = 16 * k * (1 - 0.35 * u);
        return Offset.lerp(a, b, e)! + Offset(cos(th) * r, sin(th) * r * 0.4);
    }
  }

  void _cast(Canvas c, _Layout L, SkyCastTime ct, double t) {
    final s = stage;
    final i = ct.cast.fighter;
    final own = s.ownColor[i];
    final up = s.castColor[ct.index];
    final k = L.k0;
    final gesture = ct.gesture;
    // The Fusion Sky: through the round's element it turns into what the
    // two make (or goes dim).
    final fusing = ct.cast.sky != null;
    final fused = ct.cast.made != null;
    final veil = L.veilY, band = L.veilBand;
    // The Mirror Lake: its reflection goes down as it goes up; drowned out,
    // it sinks at the top.
    final lake = L.lake;
    final drowned = lake && !s.apart[i];
    final wy = L.water, sq = _Layout.squash;
    final b = _bCast..clear();
    // Each grain carries a few more about it, loose while it flies and
    // drawn in as it settles: a beam tight, a surge broad.
    final fuzz =
        switch (gesture) {
          SkyGesture.surge => 10.0,
          SkyGesture.motes || SkyGesture.orbit => 5.5,
          SkyGesture.beam => 2.2,
          _ => 4.5,
        } *
        k;
    final step = switch (gesture) {
      SkyGesture.beam => 0.032,
      SkyGesture.meteors => 0.05,
      _ => 0.024,
    };
    var sx = 0.0, sy = 0.0, sn = 0.0;
    for (var g = 0; g < kSkyCastGrains; g++) {
      final arrive = ct.arrive(g);
      // A grain now, and where it was a moment ago, fainter: its current.
      for (var j = 0; j < 5; j++) {
        final when = t - j * step;
        if (j > 0 && when < ct.release) break;
        final at = _grain(L, ct, g, when);
        if (at == null) continue;
        final (p, a) = at;
        // Which colour: its own below the element, in it, or through.
        final set = !fusing || when < ct.release
            ? 0
            : (p.dy > veil + band
                  ? 0
                  : (p.dy < veil - band ? _setSize : _setSize * 2));
        if (j == 0) {
          b.add(set + (a > 0.66 ? 0 : (a > 0.33 ? 1 : 2)), p.dx, p.dy);
          if (when >= ct.release && when < arrive + 0.2) {
            sx += p.dx;
            sy += p.dy;
            sn++;
          }
        } else {
          b.add(set + min(2 + j, 5), p.dx, p.dy);
        }
        if (lake && p.dy < wy) {
          // In the water.
          var ry = wy + (wy - p.dy) * sq;
          int bucket = j == 0
              ? _reflHead + (a > 0.66 ? 0 : (a > 0.33 ? 1 : 2))
              : _reflTrail + min(j - 1, 2);
          if (drowned && when > arrive) {
            // Drowned out: it lets go and sinks, going dark.
            if (j > 0) continue;
            final sink = ((when - arrive) / 0.9).clamp(0.0, 1.0);
            if (sink >= 1) continue;
            ry += 34 * k * sink * sink;
            bucket = sink < 0.45 ? _sinkNear : _sinkFar;
          }
          if (ry < L.h) b.add(bucket, p.dx + L.sway(ry, t, g * 0.3), ry);
        }
        if (j > 1) continue;
        final open = when < ct.release
            ? 0.6
            : (when < arrive || g >= ct.cast.stars
                  ? 1.0
                  : 1 - _smooth((when - arrive) / ct.settleSeconds(g)));
        if (open <= 0.02) continue;
        for (var m = 0; m < 3; m++) {
          final ang = hash01(g * 3 + m, 1041 + ct.index) * 2 * pi;
          final r = fuzz * open * (0.35 + 0.65 * hash01(g * 3 + m, 1042));
          b.add(set + 6 + j, p.dx + cos(ang) * r, p.dy + sin(ang) * r * 0.8);
        }
      }
    }
    final centroid = sn > 0 ? Offset(sx / sn, sy / sn) : null;
    // A Wing's beam: a soft shaft of light from the last of its grains to
    // the first.
    if (gesture == SkyGesture.beam && t >= ct.release) {
      final head = _grain(L, ct, 0, t),
          tail = _grain(L, ct, kSkyCastGrains - 1, t);
      if (head != null && tail != null) {
        final through = fusing && head.$1.dy < veil;
        _shaft(c, tail.$1, head.$1, through ? up : own, k);
      }
    }
    // The light it carries up: swelling at the caster as it gathers, then
    // riding with its grains (a beam's at its head) — through the Fusion
    // Sky's element in what the two make, flaring as it goes through, or
    // dimmed.
    final lead = gesture == SkyGesture.beam ? _grain(L, ct, 0, t) : null;
    final at = t < ct.release ? L.head[i] : (lead?.$1 ?? centroid);
    if (at != null) {
      var r = (gesture == SkyGesture.surge ? 52 : 34) * k;
      var env =
          _smooth((t - ct.start) / 0.45) *
          (1 - _smooth((t - ct.arrive(0) - 0.1) / 0.5));
      var col = own;
      if (fusing && t >= ct.release) {
        final through = 1 - _smooth((at.dy - (veil - band)) / (band * 2));
        final inIt = 1 - _smooth((at.dy - veil).abs() / (band * 2.5));
        col = Color.lerp(own, up, through)!;
        if (fused) {
          r *= 1 + 0.5 * inIt;
          env *= 1 + 0.7 * inIt;
        } else {
          env *= 1 - 0.65 * through;
        }
      }
      if (env > 0.01) {
        _glow(c, at, r, col, env);
        if (lake && !drowned && at.dy < wy) {
          final ry = wy + (wy - at.dy) * sq;
          c.save();
          c.translate(at.dx, ry);
          c.scale(1, sq);
          _glow(c, Offset.zero, r, col, env * 0.45);
          c.restore();
        }
      }
    }
    final hot = Color.lerp(own, Colors.white, 0.55)!;
    _drawSet(c, b, 0, own, hot, k, 1);
    if (fusing) {
      final upHot = Color.lerp(up, Colors.white, fused ? 0.55 : 0.2)!;
      _drawSet(c, b, _setSize, up, upHot, k, fused ? 1 : 0.5);
      final mid = Color.lerp(own, up, 0.5)!;
      final midHot = Color.lerp(mid, Colors.white, fused ? 0.75 : 0.25)!;
      _drawSet(c, b, _setSize * 2, mid, midHot, k, fused ? 1.15 : 0.7);
    }
    if (lake) {
      b.draw(c, _reflTrail + 2, 1.4 * k, own.withValues(alpha: 0.08));
      b.draw(c, _reflTrail + 1, 1.6 * k, own.withValues(alpha: 0.13));
      b.draw(c, _reflTrail, 1.8 * k, own.withValues(alpha: 0.2));
      b.draw(c, _reflHead + 2, 2.0 * k, hot.withValues(alpha: 0.16));
      b.draw(c, _reflHead + 1, 2.1 * k, hot.withValues(alpha: 0.32));
      b.draw(c, _reflHead, 2.3 * k, hot.withValues(alpha: 0.5));
      final murk = Color.lerp(own, const Color(0xFF1A2030), 0.55)!;
      b.draw(c, _sinkNear, 2.1 * k, murk.withValues(alpha: 0.4));
      b.draw(c, _sinkFar, 1.8 * k, murk.withValues(alpha: 0.16));
    }
  }

  /// One colour set's grains: trails faint, loose grains about, the grains
  /// themselves hot.
  void _drawSet(
    Canvas c,
    GrainBatch b,
    int set,
    Color col,
    Color hot,
    double k,
    double a,
  ) {
    double al(double x) => (x * a).clamp(0.0, 1.0);
    b.draw(c, set + 5, 1.4 * k, col.withValues(alpha: al(0.14)));
    b.draw(c, set + 4, 1.6 * k, col.withValues(alpha: al(0.24)));
    b.draw(c, set + 3, 1.8 * k, col.withValues(alpha: al(0.36)));
    b.draw(c, set + 7, 1.4 * k, col.withValues(alpha: al(0.32)));
    b.draw(c, set + 6, 1.6 * k, hot.withValues(alpha: al(0.5)));
    b.draw(c, set + 2, 2.0 * k, hot.withValues(alpha: al(0.3)));
    b.draw(c, set + 1, 2.1 * k, hot.withValues(alpha: al(0.62)));
    b.draw(c, set + 0, 2.4 * k, hot.withValues(alpha: al(0.95)));
  }

  void _glow(Canvas c, Offset at, double r, Color col, double env) {
    c.drawCircle(
      at,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          at,
          r,
          [
            col.withValues(alpha: (0.26 * env).clamp(0.0, 1.0)),
            col.withValues(alpha: (0.08 * env).clamp(0.0, 1.0)),
            col.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
  }

  /// A beam's shaft: wide and bright at its head, thin and gone at its
  /// tail, with a brighter core.
  void _shaft(Canvas c, Offset tail, Offset head, Color col, double k) {
    final d = head - tail;
    final len = d.distance;
    if (len < 4) return;
    final n = Offset(-d.dy / len, d.dx / len);
    for (final (w0, w1, a) in [(1.5, 7.0, 0.28), (0.4, 1.8, 0.6)]) {
      final path = Path()
        ..moveTo(tail.dx + n.dx * w0 * k, tail.dy + n.dy * w0 * k)
        ..lineTo(head.dx + n.dx * w1 * k, head.dy + n.dy * w1 * k)
        ..lineTo(head.dx - n.dx * w1 * k, head.dy - n.dy * w1 * k)
        ..lineTo(tail.dx - n.dx * w0 * k, tail.dy - n.dy * w0 * k)
        ..close();
      final hot = Color.lerp(col, Colors.white, a > 0.5 ? 0.7 : 0.3)!;
      c.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            tail,
            head,
            [
              hot.withValues(alpha: 0),
              hot.withValues(alpha: a * 0.5),
              hot.withValues(alpha: a),
            ],
            const [0.0, 0.6, 1.0],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(SkyPainter old) => old.stage != stage;
}
