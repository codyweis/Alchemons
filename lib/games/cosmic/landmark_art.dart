// lib/games/cosmic/landmark_art.dart
//
// The great landmarks of open space, in the particle language the planets
// and the black holes already speak — matter as grains, light as gradient,
// nothing stroked:
//
//   galaxy whirl      a small spiral galaxy of one element; woken, it spins
//                     up and throws its arms out while its waves come; spent,
//                     it settles to a faint smudge
//
// (The Blood Ring, the prismatic aurora and the Elemental Nexus follow.)

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:alchemons/games/cosmic/planets/planet_art.dart'
    show BlackHoleArt;
import 'package:flutter/painting.dart';

final Map<Color, StoneLight> _lights = {};
StoneLight _light(Color c) => _lights[c] ??= StoneLight(c, warm: 0.02);

// ── galaxy whirl ────────────────────────────────────────────────────────────

/// Grains of a spiral galaxy, unit radius: (radius along the arm, arm,
/// scatter, brightness class).
final List<(double, int, double, int)> _galaxy = () {
  final r = Random(73);
  return [
    for (var i = 0; i < 640; i++)
      (
        pow(r.nextDouble(), 0.8).toDouble(),
        r.nextInt(2),
        (r.nextDouble() - 0.5) * 0.5,
        r.nextDouble() < 0.1 ? 2 : (r.nextDouble() < 0.45 ? 1 : 0),
      ),
  ];
}();

final PointBatch _galSoft = PointBatch(640);
final PointBatch _galMid = PointBatch(640);
final PointBatch _galHot = PointBatch(120);
final PointBatch _galWake = PointBatch(80);

/// How awake a whirl is.
enum WhirlLook { dormant, active, spent }

/// A galaxy whirl of [color] at [at]. [radius] is its gameplay radius; the
/// galaxy reaches about twice that. [spin] is its turned angle so far.
void paintGalaxyWhirl(
  Canvas c, {
  required Offset at,
  required double radius,
  required Color color,
  required double spin,
  required double t,
  WhirlLook look = WhirlLook.dormant,
  double? wake,
}) {
  final m = _light(color);
  if (wake != null) {
    _galWake.clear();
    for (var i = 0; i < 80; i++) {
      final a = i * 2 * pi / 80 + t * 0.03 + hash01(i, 71) * 0.06;
      final r = wake * (0.98 + 0.04 * hash01(i, 72));
      _galWake.add(at.dx + cos(a) * r, at.dy + sin(a) * r);
    }
    _galWake.draw(c, 1.6, m.grainDim.withValues(alpha: 0.3));
  }
  final reach = radius * (look == WhirlLook.active ? 2.6 : 2.1);
  final alpha = look == WhirlLook.spent ? 0.35 : 1.0;
  paintDisc(
    c,
    m.pool,
    at,
    reach * 1.3,
    look == WhirlLook.active ? 2.2 + 0.5 * sin(t * 4) : 1.1 * alpha,
  );
  _galSoft.clear();
  _galMid.clear();
  _galHot.clear();
  // Two logarithmic arms, wound tighter toward the core; the disk tipped a
  // little so it reads as a disc seen at a slant.
  const wind = 2.6;
  const flat = 0.62;
  final keep = look == WhirlLook.spent ? 260 : _galaxy.length;
  for (var i = 0; i < keep; i++) {
    final (u, arm, scatter, cls) = _galaxy[i];
    final a = spin + arm * pi + u * wind * pi + scatter * (0.4 + u);
    final rr = reach * (0.08 + 0.92 * u);
    final p = at + Offset(cos(a) * rr, sin(a) * rr * flat);
    (cls == 2
            ? _galHot
            : cls == 1
            ? _galMid
            : _galSoft)
        .add(p.dx, p.dy);
  }
  _galSoft.draw(c, 2.6, m.essence.withValues(alpha: 0.2 * alpha));
  _galMid.draw(c, 1.6, m.grainDim.withValues(alpha: 0.7 * alpha));
  _galHot.draw(c, 1.6, m.grainHot.withValues(alpha: alpha));
  // The bulge at its heart.
  paintDisc(c, m.leak, at, reach * 0.35, 1.6 * alpha);
  paintDisc(
    c,
    m.spark,
    at,
    (look == WhirlLook.active ? 10 : 6) + 2 * sin(t * 2),
    alpha,
  );
}

// ── Elemental Nexus ─────────────────────────────────────────────────────────

const List<Color> _nexusElements = [
  Color(0xFFFF7043), // fire
  Color(0xFF4FC3F7), // water
  Color(0xFFC8A06A), // earth
  Color(0xFFE0F7FA), // air
];

BlackHoleArt? _nexusHole;
final List<PointBatch> _nexusStreams = [
  for (var i = 0; i < 4; i++) PointBatch(160),
];
final List<PointBatch> _nexusHeads = [
  for (var i = 0; i < 4; i++) PointBatch(40),
];
final PointBatch _nexusDust = PointBatch(240);

/// The Elemental Nexus at [at]: a black hole the four elements pour into,
/// each in its own stream. [radius] is how far it reaches.
void paintElementalNexus(
  Canvas c, {
  required Offset at,
  required double radius,
  required double t,
  double near = 0,
}) {
  final hole = _nexusHole ??= BlackHoleArt(
    seed: 17,
    motes: 900,
    infall: 120,
    grain: 2.4,
    flat: 0.42,
  );
  final core = radius * 0.15;
  // Dust drawn in from far out.
  _nexusDust.clear();
  for (var i = 0; i < 220; i++) {
    final ph = (t * 0.03 * (1 + hash01(i, 81)) + hash01(i, 82)) % 1.0;
    final r = radius * (0.95 - 0.55 * ph);
    final a = hash01(i, 83) * 2 * pi + ph * 2.2;
    _nexusDust.add(at.dx + cos(a) * r, at.dy + sin(a) * r * 0.62);
  }
  _nexusDust.draw(c, 1.6, const Color(0x55C6B8FF));

  hole.paintBack(c, at, core, t);
  // The four elements, each spiralling in from its own quarter.
  for (var e = 0; e < 4; e++) {
    final s = _nexusStreams[e]..clear();
    final h = _nexusHeads[e]..clear();
    for (var i = 0; i < 150; i++) {
      final ph = (t * 0.08 + i / 150) % 1.0;
      final r = core * 1.05 + (radius - core) * (1 - ph);
      final a =
          e * pi / 2 + 0.6 + ph * 3.4 + (hash01(e * 200 + i, 84) - 0.5) * 0.18;
      final p = at + Offset(cos(a) * r, sin(a) * r * 0.62);
      (i % 9 == 0 ? h : s).add(p.dx, p.dy);
    }
    s.draw(c, 1.8, _nexusElements[e].withValues(alpha: 0.55));
    h.draw(c, 2.6, _nexusElements[e]);
  }
  stonePaint
    ..shader = null
    ..color = const Color(0xFF000000);
  c.drawCircle(at, core, stonePaint);
  hole.paintFront(c, at, core, t);
}

// ── Blood Ring ──────────────────────────────────────────────────────────────
//
// The end of the game. A crown of blood-glass thorns, tall and low in two
// tiers, round a whirlpool of blood fed by four rivers, all falling toward
// an eclipsed heart ringed in a crimson corona, inside a vast slow halo of
// dust that reads from far away. It answers to what the player brings:
//
//   quiet    imposing and slow; the thorns dark
//   armed    a Mystic Blood companion is out: the thorns' tips kindle, embers
//            lift off the well, the heart beats harder
//   ritual   (0..1) the thorns ignite one by one round the crown, the well
//            races and draws in, the heart flares, a crimson flood rises
//   opened   after the ending: the heart is clear light and the blood runs
//            outward from it, the whole crown softly lit

class _BloodRing {
  /// The thorns' stone: a deep blood glass, near black until lit.
  final StoneLight stone = StoneLight(const Color(0xFF9A0F24));

  /// The blood itself, and the light it gives.
  final StoneLight m = StoneLight(const Color(0xFFD8283A), warm: 0.03);
  final StoneLight light = StoneLight(const Color(0xFFB2EBF2));

  static const int _turns = 12;

  /// A thorn: a long curved blade, its point toward the heart (−x), baked
  /// once per twelfth of a turn so the key light stays put in the world as
  /// the crown goes round.
  late final List<BakedArt> _thorns = [
    for (var k = 0; k < _turns; k++)
      BakedArt(const Rect.fromLTRB(-96, -14, 10, 14), (c) {
        CutStone.gem(stone, const [
          Offset(-92, 2),
          Offset(-72, -4),
          Offset(-44, -9),
          Offset(-14, -12),
          Offset(6, -5),
          Offset(6, 5),
          Offset(-14, 12),
          Offset(-44, 10),
          Offset(-72, 5),
        ], const Offset(-40, 1)).paint(
          c,
          k * 2 * pi / _turns,
          glow: 0.5,
          reach: 40,
        );
      }),
  ];

  /// Draws a thorn on a canvas turned by [rot].
  void thorn(Canvas c, double rot) {
    final k = (rot / (2 * pi) * _turns).round() % _turns;
    _thorns[k < 0 ? k + _turns : k].draw(c);
  }

  /// The eclipse: a hot rim just outside the black heart (at a quarter of
  /// the disc), falling off into crimson. Unit radius.
  late final ui.Shader corona = ui.Gradient.radial(
    Offset.zero,
    1,
    [
      m.hot,
      m.hot,
      m.essence.withValues(alpha: 0.85),
      m.essence.withValues(alpha: 0.28),
      m.essence.withValues(alpha: 0.08),
      m.essence.withValues(alpha: 0),
    ],
    const [0.0, 0.25, 0.31, 0.5, 0.75, 1.0],
  );

  /// The same eclipse once the ring is opened: the heart is clear light.
  late final ui.Shader clearHeart = ui.Gradient.radial(
    Offset.zero,
    1,
    [
      const Color(0xFFFFFFFF),
      light.hot,
      light.essence.withValues(alpha: 0.6),
      light.essence.withValues(alpha: 0.14),
      light.essence.withValues(alpha: 0),
    ],
    const [0.0, 0.18, 0.32, 0.6, 1.0],
  );

  /// The flood: a wide crimson light. Unit radius.
  late final ui.Shader flood = ui.Gradient.radial(
    Offset.zero,
    1,
    [
      m.essence.withValues(alpha: 0.7),
      m.essence.withValues(alpha: 0.4),
      const Color(0xFF5A0010).withValues(alpha: 0),
    ],
    const [0.0, 0.5, 1.0],
  );
}

_BloodRing? _blood;
final PointBatch _bloodHalo = PointBatch(460);
final PointBatch _bloodFar = PointBatch(900);
final PointBatch _bloodNear = PointBatch(900);
final PointBatch _bloodRivers = PointBatch(840);
final PointBatch _bloodCoronaHot = PointBatch(240);
final PointBatch _bloodCoronaDim = PointBatch(240);
final PointBatch _bloodEmbers = PointBatch(140);

/// The Blood Ring at [at], [radius] across (see the note above). [armed]
/// (0..1) is a Mystic Blood companion being out; [ritual] (0..1) the
/// ritual's progress; [opened] the ending done. [flow] is the well's clock
/// (defaults to [t]).
void paintBloodRing(
  Canvas c, {
  required Offset at,
  required double radius,
  required double t,
  bool opened = false,
  double armed = 0,
  double ritual = 0,
  double? flow,
}) {
  // The well's own clock. The game runs it faster through the ritual; a
  // rate changed here instead would jump every grain as it changed.
  final f = flow ?? t;
  final b = _blood ??= _BloodRing();
  final m = b.m;
  final stir = max(armed * 0.6, ritual);
  final beat = pow(0.5 + 0.5 * sin(f * 1.6), 5).toDouble();
  // The flood that rises at the end of the ritual.
  final flood = ((ritual - 0.68) / 0.32).clamp(0.0, 1.0);

  // A vast slow halo, and the arena's light pooled under it.
  paintDisc(c, m.pool, at, radius * 1.9, 0.9 + 0.3 * beat * (1 + stir));
  if (flood > 0) {
    paintDisc(c, b.flood, at, radius * (0.8 + 2.6 * flood), flood);
  }
  _bloodHalo.clear();
  for (var i = 0; i < 440; i++) {
    final a = hash01(i, 91) * 2 * pi + t * (0.012 + 0.006 * hash01(i, 98));
    final r = radius * (1.22 + 0.55 * pow(hash01(i, 92), 1.4));
    _bloodHalo.add(at.dx + cos(a) * r, at.dy + sin(a) * r);
  }
  _bloodHalo.draw(c, 1.8, m.grainDim.withValues(alpha: 0.32));

  // The whirlpool. In a ritual it draws in; once opened the blood runs
  // outward from the heart instead.
  final pull = 1 - 0.3 * ritual;
  _bloodFar.clear();
  _bloodNear.clear();
  for (var i = 0; i < 880; i++) {
    final ph0 = (f * (0.035 + 0.03 * hash01(i, 93)) + hash01(i, 94)) % 1.0;
    final ph = opened ? 1 - ph0 : ph0;
    final r = radius * pull * (0.1 + 0.72 * pow(1 - ph, 1.7));
    final a = hash01(i, 95) * 2 * pi + ph * 3.4 + f * 0.05;
    (ph > 0.72 ? _bloodNear : _bloodFar).add(
      at.dx + cos(a) * r,
      at.dy + sin(a) * r,
    );
  }
  // Four rivers of blood, ribbons of grain curling in.
  _bloodRivers.clear();
  for (var arm = 0; arm < 4; arm++) {
    for (var i = 0; i < 210; i++) {
      final ph0 = (f * 0.05 + hash01(arm * 300 + i, 105)) % 1.0;
      final ph = opened ? 1 - ph0 : ph0;
      final u = 1 - ph;
      final r =
          radius * pull * (0.12 + 0.75 * u) +
          (hash01(arm * 300 + i, 106) - 0.5) * radius * 0.07 * u;
      final a = arm * pi / 2 + f * 0.04 + (1 - u) * 3.6;
      _bloodRivers.add(at.dx + cos(a) * r, at.dy + sin(a) * r);
    }
  }
  _bloodFar.draw(c, 2.2, m.grainDim.withValues(alpha: 0.6));
  _bloodRivers.draw(c, 2.4, Color.lerp(m.grainHot, m.essence, 0.35)!);
  _bloodNear.draw(c, 2.8, m.grainHot);

  // The heart: an eclipse — a black disc in a crimson corona — or, once
  // opened, clear light.
  final heartR = radius * 0.11 * (1 + 0.05 * beat) * (1 + 0.5 * flood);
  _bloodCoronaHot.clear();
  _bloodCoronaDim.clear();
  for (var i = 0; i < 240; i++) {
    final a = i * 2 * pi / 240 + hash01(i, 100) * 0.03;
    final flick = 0.7 + 0.3 * sin(f * 2.4 + i * 0.7);
    for (var k = 0; k < 2; k++) {
      final reach = pow(hash01(i * 2 + k, 101), 1.6) * flick * (1 + stir);
      final r = heartR * (1.08 + 1.4 * reach);
      (reach < 0.35 ? _bloodCoronaHot : _bloodCoronaDim).add(
        at.dx + cos(a) * r,
        at.dy + sin(a) * r,
      );
    }
  }
  final heartLight = opened ? b.light : m;
  if (opened) {
    paintDisc(c, b.clearHeart, at, heartR * 4.4);
  } else {
    paintDisc(c, m.leak, at, radius * 0.36, 0.7 + 0.3 * beat + 0.3 * ritual);
    paintDisc(c, b.corona, at, heartR * 4, 0.75 + 0.25 * max(beat, ritual));
  }
  _bloodCoronaDim.draw(c, 2, heartLight.grainDim);
  _bloodCoronaHot.draw(c, 2.4, heartLight.grainHot);
  if (!opened) {
    stonePaint
      ..shader = null
      ..color = const Color(0xFF050002);
    c.drawCircle(at, heartR, stonePaint);
    // Near the end the heart itself takes light.
    final flare = ((ritual - 0.55) / 0.45).clamp(0.0, 1.0);
    if (flare > 0) {
      paintDisc(c, m.spark, at, heartR * (0.4 + 1.4 * flare), flare);
    }
  }

  // Embers lifting off the well while it is stirred.
  if (stir > 0 || opened) {
    _bloodEmbers.clear();
    final n = (40 + 100 * stir).round();
    for (var i = 0; i < n; i++) {
      final ph = (t * (0.12 + 0.08 * hash01(i, 102)) + hash01(i, 103)) % 1.0;
      final a = hash01(i, 104) * 2 * pi;
      final r = radius * (0.2 + 0.85 * ph);
      _bloodEmbers.add(at.dx + cos(a) * r, at.dy + sin(a) * r - ph * 40);
    }
    _bloodEmbers.draw(c, 2, heartLight.hot.withValues(alpha: 0.7));
  }

  // The crown: two tiers of thorns leaning round with the well, long ones
  // inside, shorter ones out. The long ones' points kindle when the ring is
  // armed, ignite one by one round the crown in the ritual, and stay softly
  // lit once it is done.
  c.save();
  c.translate(at.dx, at.dy);
  const tall = 14;
  const lean = 0.34;
  for (var tier = 1; tier >= 0; tier--) {
    for (var i = 0; i < tall; i++) {
      final a = (i + 0.5 * tier) * 2 * pi / tall + t * 0.006;
      final r = radius * (tier == 1 ? 1.16 : 0.97 + 0.04 * hash01(i, 97));
      final sc = tier == 1
          ? 1.05 + 0.2 * hash01(i, 107)
          : 1.55 + 0.45 * hash01(i, 96);
      final turn = a + (tier == 1 ? lean * 1.4 : lean);
      c.save();
      c.rotate(a);
      c.translate(r, 0);
      c.rotate(turn - a);
      c.scale(sc);
      b.thorn(c, turn);
      c.restore();
      if (tier == 1) continue;
      final lit = opened
          ? 0.55
          : max(armed * 0.5, ((ritual * 1.3 - i / tall) * 5).clamp(0.0, 1.0));
      if (lit > 0) {
        final tip = polar(r, a) + polar(-90 * sc, turn);
        paintDisc(c, heartLight.pool, tip, 46 * lit, 1);
        paintDisc(c, heartLight.spark, tip, 5 + 6 * lit, lit);
      }
    }
  }
  c.restore();
}

// ── Prismatic aurora ────────────────────────────────────────────────────────

const List<Color> _auroraHues = [
  Color(0xFFFF2E7E),
  Color(0xFFFF7A2E),
  Color(0xFFFFD84A),
  Color(0xFF3CF29A),
  Color(0xFF2EDBFF),
  Color(0xFF5A73FF),
  Color(0xFFA14BFF),
  Color(0xFFFF3DD6),
];

final List<PointBatch> _veilCrest = [
  for (var i = 0; i < 7; i++) PointBatch(260),
];
final PointBatch _summon = PointBatch(16);
final Paint _veilPaint = Paint()..color = const Color(0xFFFFFFFF);

/// The prismatic aurora centred on [at], [radius] across: curtains of light
/// in every hue, each a sheet bright along its lower hem and fading as it
/// rises, rippling and drifting through the colors. Until its reward is
/// [claimed], a small turning ring of the eight hues marks its heart.
void paintPrismaticAurora(
  Canvas c, {
  required Offset at,
  required double radius,
  required double t,
  bool claimed = false,
}) {
  final fade = claimed ? 0.6 : 1.0;
  const samples = 120;
  const veils = 6;
  for (var v = 0; v < veils; v++) {
    final crest = _veilCrest[v]..clear();
    final hue = _auroraHues[(v + (t * 0.08).floor()) % _auroraHues.length];
    // Staggered: each curtain hangs over its own stretch of the field.
    final y0 = (v / (veils - 1) - 0.5) * radius * 1.2;
    final span = 0.55 + 0.4 * hash01(v, 103);
    final shift = (hash01(v, 104) - 0.5) * (1 - span);
    final amp = radius * (0.05 + 0.04 * hash01(v, 105));
    final k = 2.0 + v * 0.45;
    final upper = Float32List(samples * 4);
    final lower = Float32List(samples * 4);
    final upperC = Int32List(samples * 2);
    final lowerC = Int32List(samples * 2);
    for (var i = 0; i < samples; i++) {
      final u = i / (samples - 1) * 2 - 1;
      final x = (shift + u * span) * radius;
      // It thins to nothing at its ends and at the field's edge.
      final ends = sin((u + 1) / 2 * pi);
      final edge = sqrt(max(0.0, 1 - (x * x + y0 * y0) / (radius * radius)));
      final w = ends * edge;
      final y =
          y0 +
          amp * sin(u * k + t * (0.3 + v * 0.04)) +
          amp * 0.4 * sin(u * k * 2.3 - t * 0.5);
      final rise =
          radius *
          (0.1 + 0.1 * hash01(v, 106)) *
          (0.7 + 0.3 * sin(u * 7 + t * 0.6 + v)) *
          w;
      // Rays: the light runs up the curtain in faint stripes.
      final ray = 0.55 + 0.45 * sin(u * 46 + t * 0.4 + v * 3);
      final hem = (0.5 * w * ray * fade).clamp(0.0, 1.0);
      final hx = at.dx + x, hy = at.dy + y;
      upper[i * 4] = hx;
      upper[i * 4 + 1] = hy - rise;
      upper[i * 4 + 2] = hx;
      upper[i * 4 + 3] = hy;
      lower[i * 4] = hx;
      lower[i * 4 + 1] = hy;
      lower[i * 4 + 2] = hx;
      lower[i * 4 + 3] = hy + rise * 0.18;
      upperC[i * 2] = hue.withValues(alpha: 0).toARGB32();
      upperC[i * 2 + 1] = hue.withValues(alpha: hem).toARGB32();
      lowerC[i * 2] = hue.withValues(alpha: hem).toARGB32();
      lowerC[i * 2 + 1] = hue.withValues(alpha: 0).toARGB32();
      if (w > 0.15 && i.isEven) {
        crest.add(hx, hy - rise * 0.5 * hash01(v * 300 + i, 102));
      }
    }
    for (final (pos, col) in [(upper, upperC), (lower, lowerC)]) {
      c.drawVertices(
        ui.Vertices.raw(ui.VertexMode.triangleStrip, pos, colors: col),
        BlendMode.dst,
        _veilPaint,
      );
    }
    crest.draw(
      c,
      2,
      Color.lerp(
        hue,
        const Color(0xFFFFFFFF),
        0.4,
      )!.withValues(alpha: 0.5 * fade),
    );
  }
  if (!claimed) {
    _summon.clear();
    final r = radius * 0.12;
    for (var i = 0; i < 8; i++) {
      final a = t * 0.5 + i * pi / 4;
      final p = at + Offset(cos(a) * r, sin(a) * r);
      paintDisc(c, _light(_auroraHues[i]).pool, p, 22, 1.4);
      _summon.add(p.dx, p.dy);
    }
    _summon.draw(c, 4, const Color(0xFFFFFFFF).withValues(alpha: 0.85));
  }
}
