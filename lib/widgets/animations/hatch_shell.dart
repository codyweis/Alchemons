library;

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Helical streamline shell for the extraction hatching cinematic.
///
/// Tuned in `docs/prototypes/hatch_shell_proto.html` — that prototype is the
/// authority for every constant in this file. Change numbers there first.
///
/// Three independent layers compose, so authoring is 8 + 17 + 3 rather than
/// 8 x 17 x 3:
///   * species -> the shell's ARCHITECTURE  (mutationFamily)
///   * element -> MATERIAL: palette + strand behavior  (parent A/B + result)
///   * rarity  -> TREATMENT layered over any of the above
///
/// The whole shell renders in ONE `drawVertices` call. Per-species `drawPath`
/// counts ran 140-680 per frame in the prototype, which would have meant
/// tuning every species against a frame budget forever; vertices also give a
/// lit ribbon face, which round strokes cannot.

// ===========================================================================
// LAYER 1 — SPECIES
// ===========================================================================

enum HatchShellSpecies { pip, wing, horn, mane, meteor, mask, kin, mystic }

/// Structural flags. Every field is optional; zero means "not this species".
@immutable
class _Form {
  final double cyl, cap; // pip: mix toward a straight column
  final double rib, ribDepth; // mane: plate ridges
  final double spire, sweep; // horn: crest + falling tips
  final double bulbs, neck, neckW; // kin: hourglass
  final double hole, wrap, coil, aspect; // mask: torus aperture
  final double wingFrac, wingW, wingH, wingTilt, wingOut, wingY;
  final double ringFrac, haloFrac, haloR, haloTilt, haloWob; // mystic

  const _Form({
    this.cyl = 0,
    this.cap = 0.12,
    this.rib = 0,
    this.ribDepth = 0,
    this.spire = 0,
    this.sweep = 0,
    this.bulbs = 0,
    this.neck = 0,
    this.neckW = 0.16,
    this.hole = 0,
    this.wrap = 1,
    this.coil = 3,
    this.aspect = 1.1,
    this.wingFrac = 0,
    this.wingW = 0.42,
    this.wingH = 1.8,
    this.wingTilt = 0.52,
    this.wingOut = 0.98,
    this.wingY = -0.03,
    this.ringFrac = 0,
    this.haloFrac = 0,
    this.haloR = 1.62,
    this.haloTilt = 1.09,
    this.haloWob = 0.05,
  });
}

/// Per-species motion. Null fields fall back to [_Motion.base] — a species
/// without an override always lands on the baseline, so the order species are
/// selected in can never change the result.
@immutable
class _Motion {
  final double weave, twAmp, twFreq, twSpd, brAmp, brSpd, waist;
  const _Motion({
    this.weave = 0,
    this.twAmp = 0.72,
    this.twFreq = 1,
    this.twSpd = 0.81,
    this.brAmp = 0.05,
    this.brSpd = 0.44,
    this.waist = 0.1,
  });
  static const base = _Motion();
}

@immutable
class _Species {
  final int strands;
  final double turns, radius, height, pointTop, pointBase, shellThick, coverage;
  final _Form f;
  final _Motion m;
  const _Species({
    required this.strands,
    required this.turns,
    required this.radius,
    required this.height,
    required this.pointTop,
    required this.pointBase,
    required this.shellThick,
    required this.coverage,
    this.f = const _Form(),
    this.m = _Motion.base,
  });
}

const Map<HatchShellSpecies, _Species> _kSpecies = {
  // Ricochet: a slender tapered column, not a literal pipe.
  HatchShellSpecies.pip: _Species(
    strands: 92,
    turns: 1.60,
    radius: 0.105,
    height: 0.464,
    pointTop: 0.55,
    pointBase: 0.68,
    shellThick: 0.11,
    coverage: 0.05,
    f: _Form(cyl: 0.5, cap: 0.18),
  ),
  // Beams: a core shell flanked by two swept lobes.
  HatchShellSpecies.wing: _Species(
    strands: 108,
    turns: 1.05,
    radius: 0.150,
    height: 0.54,
    pointTop: 0.60,
    pointBase: 0.60,
    shellThick: 0.13,
    coverage: 0.10,
    f: _Form(
      wingFrac: 0.58,
      wingW: 0.42,
      wingH: 1.80,
      wingTilt: 0.52,
      wingOut: 0.98,
      wingY: -0.03,
    ),
    m: _Motion(
      weave: 0,
      twAmp: 2.5,
      twFreq: 0.5,
      twSpd: 0.34,
      brAmp: 0,
      brSpd: 0,
      waist: 0,
    ),
  ),
  // A tall sweeping crest whose strands curl outward and fall at the tips.
  HatchShellSpecies.horn: _Species(
    strands: 84,
    turns: 1.00,
    radius: 0.170,
    height: 0.80,
    pointTop: 1.70,
    pointBase: 0.50,
    shellThick: 0.16,
    coverage: 0.08,
    f: _Form(spire: 0.50, sweep: 0.55),
    m: _Motion(
      weave: 0,
      twAmp: 0.42,
      twFreq: 0.2,
      twSpd: 0.2,
      brAmp: 0,
      brSpd: 0,
      waist: 0,
    ),
  ),
  // Broad, heavy, visibly ribbed like plate armour.
  HatchShellSpecies.mane: _Species(
    strands: 68,
    turns: 0.55,
    radius: 0.220,
    height: 0.52,
    pointTop: 0.55,
    pointBase: 0.50,
    shellThick: 0.24,
    coverage: 0.10,
    f: _Form(rib: 9, ribDepth: 0.11),
    m: _Motion(twAmp: 1),
  ),
  // Skyfall: heavy base, blunt crown.
  HatchShellSpecies.meteor: _Species(
    strands: 90,
    turns: 1.10,
    radius: 0.190,
    height: 0.60,
    pointTop: 0.45,
    pointBase: 0.95,
    shellThick: 0.18,
    coverage: 0.14,
  ),
  // Traps: a torus with a real aperture. hole > 0.5 or the tube is wider than
  // the ring and strands pass straight through the middle.
  HatchShellSpecies.mask: _Species(
    strands: 96,
    turns: 1.00,
    radius: 0.215,
    height: 0.60,
    pointTop: 0.60,
    pointBase: 0.60,
    shellThick: 0.10,
    coverage: 0.04,
    f: _Form(hole: 0.64, wrap: 1, coil: 3.0, aspect: 1.10),
    m: _Motion(
      weave: 0,
      twAmp: 0.2,
      twFreq: 2.3,
      twSpd: 1,
      brAmp: 0.05,
      brSpd: 0.44,
      waist: 0.1,
    ),
  ),
  // Support companion: ONE hourglass. Two bulbs joined through a real neck,
  // so strands wind continuously through the waist rather than stacking.
  HatchShellSpecies.kin: _Species(
    strands: 92,
    turns: 1.60,
    radius: 0.170,
    height: 0.72,
    pointTop: 0.70,
    pointBase: 0.70,
    shellThick: 0.13,
    coverage: 0.03,
    f: _Form(bulbs: 2, neck: 0.30, neckW: 0.16),
    m: _Motion(
      weave: 0,
      twAmp: 1.5,
      twFreq: 4,
      twSpd: 1,
      brAmp: 0.05,
      brSpd: 0.44,
      waist: 0.1,
    ),
  ),
  // The rarest. The family brief is WORLDS, so this is not an egg: a sphere of
  // meridians and parallels wearing a tilted orbital halo. The only species
  // allowed to break the shell's own rules.
  HatchShellSpecies.mystic: _Species(
    strands: 128,
    turns: 1.00,
    radius: 0.215,
    height: 0.43,
    pointTop: 0.50,
    pointBase: 0.50,
    shellThick: 0.05,
    coverage: 0.02,
    f: _Form(
      ringFrac: 0.40,
      haloFrac: 0.16,
      haloR: 1.62,
      haloTilt: 1.09,
      haloWob: 0.05,
    ),
  ),
};

/// Maps `offspring.mutationFamily` onto a species. Unknown families fall back
/// to the plain shell rather than throwing mid-cinematic.
HatchShellSpecies hatchShellSpeciesFor(String? mutationFamily) {
  switch (mutationFamily?.trim().toLowerCase()) {
    case 'pip':
      return HatchShellSpecies.pip;
    case 'wing':
      return HatchShellSpecies.wing;
    case 'horn':
      return HatchShellSpecies.horn;
    case 'mane':
      return HatchShellSpecies.mane;
    case 'let':
      return HatchShellSpecies.meteor;
    case 'mask':
      return HatchShellSpecies.mask;
    case 'kin':
      return HatchShellSpecies.kin;
    case 'mystic':
      return HatchShellSpecies.mystic;
    default:
      return HatchShellSpecies.meteor;
  }
}

// ===========================================================================
// LAYER 2 — ELEMENT BEHAVIOR
// ===========================================================================

/// Per-element strand behavior. Every field is a scalar, which is what lets
/// two parents blend into their child by plain lerp with no special cases.
@immutable
class ShellElementBehavior {
  final double turns, taper, flick, wave, waveF, rise, wMul, aMul;
  final double sag, kink, facet, planes, tendril, breathe, pulse;

  const ShellElementBehavior({
    this.turns = 1,
    this.taper = 0,
    this.flick = 0,
    this.wave = 0,
    this.waveF = 0,
    this.rise = 0,
    this.wMul = 1,
    this.aMul = 1,
    this.sag = 0,
    this.kink = 0,
    this.facet = 0,
    this.planes = 0,
    this.tendril = 0,
    this.breathe = 0,
    this.pulse = 0,
  });

  static ShellElementBehavior lerpB(
    ShellElementBehavior a,
    ShellElementBehavior b,
    double t,
  ) {
    double l(double x, double y) => x + (y - x) * t;
    return ShellElementBehavior(
      turns: l(a.turns, b.turns),
      taper: l(a.taper, b.taper),
      flick: l(a.flick, b.flick),
      wave: l(a.wave, b.wave),
      waveF: l(a.waveF, b.waveF),
      rise: l(a.rise, b.rise),
      wMul: l(a.wMul, b.wMul),
      aMul: l(a.aMul, b.aMul),
      sag: l(a.sag, b.sag),
      kink: l(a.kink, b.kink),
      facet: l(a.facet, b.facet),
      planes: l(a.planes, b.planes),
      tendril: l(a.tendril, b.tendril),
      breathe: l(a.breathe, b.breathe),
      pulse: l(a.pulse, b.pulse),
    );
  }

  /// Keyed by the element type id used by `ElementalConfigs`.
  static const Map<String, ShellElementBehavior> byTypeId = {
    'T001': ShellElementBehavior(
      turns: 1.15,
      taper: 0.38,
      flick: 0.55,
      wave: 0.05,
      waveF: 5,
      rise: -0.05,
    ), // fire
    'T002': ShellElementBehavior(
      turns: 1.30,
      taper: 0.05,
      wave: 0.10,
      waveF: 2,
      wMul: 1.1,
    ), // water
    'T003': ShellElementBehavior(
      turns: 0.75,
      taper: 0.10,
      rise: 0.04,
      wMul: 1.7,
      aMul: 0.95,
    ), // earth
    'T004': ShellElementBehavior(
      turns: 2.10,
      taper: 0.20,
      flick: 0.10,
      wave: 0.13,
      waveF: 3,
      rise: -0.03,
      wMul: 0.75,
      aMul: 0.8,
    ), // air
    'T005': ShellElementBehavior(
      turns: 1.70,
      taper: 0.45,
      flick: 0.25,
      wave: 0.11,
      waveF: 2,
      rise: -0.07,
      wMul: 0.8,
      aMul: 0.65,
    ), // steam
    'T006': ShellElementBehavior(
      turns: 0.85,
      taper: 0.12,
      flick: 0.30,
      wave: 0.06,
      waveF: 2,
      rise: 0.06,
      wMul: 1.8,
      sag: 0.10,
    ), // lava
    'T007': ShellElementBehavior(
      turns: 1.40,
      taper: 0.15,
      flick: 0.70,
      wMul: 0.9,
      kink: 9,
    ), // lightning
    'T008': ShellElementBehavior(
      turns: 0.70,
      taper: 0.15,
      wave: 0.04,
      waveF: 2,
      rise: 0.05,
      wMul: 1.9,
      aMul: 0.8,
      sag: 0.14,
    ), // mud
    'T009': ShellElementBehavior(turns: 1.00, taper: 0.05, facet: 6), // ice
    'T010': ShellElementBehavior(
      turns: 1.60,
      taper: 0.50,
      flick: 0.35,
      wave: 0.09,
      waveF: 4,
      rise: -0.02,
      wMul: 0.6,
      aMul: 0.6,
    ), // dust
    'T011': ShellElementBehavior(
      turns: 1.05,
      taper: 0.05,
      wMul: 1.1,
      planes: 7,
    ), // crystal
    'T012': ShellElementBehavior(
      turns: 1.35,
      taper: 0.10,
      wave: 0.07,
      waveF: 2,
      wMul: 1.05,
      tendril: 0.5,
    ), // plant
    'T013': ShellElementBehavior(
      turns: 1.25,
      taper: 0.18,
      flick: 0.15,
      wave: 0.14,
      waveF: 6,
      rise: -0.03,
      aMul: 0.9,
    ), // poison
    'T014': ShellElementBehavior(
      turns: 1.45,
      taper: 0.30,
      flick: 0.20,
      wave: 0.16,
      waveF: 1,
      rise: -0.04,
      wMul: 0.7,
      aMul: 0.55,
      breathe: 0.16,
    ), // spirit
    'T015': ShellElementBehavior(
      turns: 1.20,
      taper: 0.12,
      wave: 0.05,
      waveF: 2,
      wMul: 1.2,
      aMul: 0.7,
    ), // dark
    'T016': ShellElementBehavior(
      turns: 1.10,
      taper: 0.08,
      flick: 0.10,
      wave: 0.03,
      waveF: 2,
      rise: -0.02,
      aMul: 1.15,
    ), // light
    'T017': ShellElementBehavior(
      turns: 1.15,
      taper: 0.14,
      wave: 0.05,
      waveF: 2,
      rise: 0.02,
      wMul: 1.3,
      pulse: 0.09,
    ), // blood
  };

  static ShellElementBehavior of(String? typeId) =>
      byTypeId[typeId] ?? const ShellElementBehavior();
}

// ===========================================================================
// LAYER 3 — RARITY
// ===========================================================================

enum ShellRarity { normal, variant, prismatic }

// ===========================================================================
// Timeline + tuned constants (mirror of the prototype's export block)
// ===========================================================================

class HatchShellTuning {
  HatchShellTuning._();

  /// Pose samples per strand. The prototype drew 30 points but smoothed them
  /// with quadratic curves through the midpoints; straight ribbon segments
  /// need more points for the same smoothness, and 18 — the old reduced tier
  /// every phone was landing on — rendered each strand as a chain of sticks.
  static const int samples = 48;
  static const int samplesReduced = 30;
  // The prototype bucketed depth into 2 buckets, so its effective depth
  // topped out near 0.75 — a front ribbon was ~5px at ~0.76 alpha. Continuous
  // per-vertex depth reaches 1.0, which made front ribbons 22% wider and 32%
  // more opaque than the prototype ever drew them, and they merged into a
  // solid mass instead of staying separate filaments. These cap the
  // continuous range at what the prototype actually produced.
  static const double alphaBack = 0.17;
  static const double alphaFront = 0.82;
  static const double widthMin = 0.9;
  static const double widthMax = 3.2;
  static const double accentMix = 0.14;
  static const double yawSpeed = 0.45;

  static const double convergeEnd = 0.69;
  static const double unravelAt = 0.85;
  static const double stagger = 0.33;
  static const double overshoot = 0.18;
  static const double burstReach = 0.34;

  static const double split = 0.26;
  static const double braid = 1.5;
  static const double fuseAt = 0.82;
  static const double fuseSpan = 0.10;

  static const double moteHold = 0.17;
  static const double stringBy = 0.33;
  static const double moteWidth = 3.0;
  static const double moteWander = 0.034;
  static const double moteTwinkle = 0.34;

  /// A mote is a strand whose samples have all collapsed onto its head. The
  /// prototype got a dot for free from a round line cap, but a vertex ribbon
  /// of zero length is degenerate triangles and draws nothing — so the samples
  /// are spread along a SHORT STRAIGHT SEGMENT instead. Tracing a tiny circle
  /// (the first attempt) made a 10px ribbon wrap a 5px ring: the lit core band
  /// ended up around the outside with the far rim covering the middle, which
  /// is a blob. A straight spread gives a clean capsule with the bright core
  /// running down its centre — a crisp point of light.
  static const double moteLength = 0.009;
  static const double sproutStagger = 0.56;
  static const double flow = 0.016;
  static const double flowWaves = 1.6;

  static const double swirl = 1.1;
  static const double radiusLag = 0.4;
  static const double counterSpin = 0.4;
  static const double clusterDrift = 0.018;
  static const double clusterChurn = 0.26;

  static const double prismRate = 0.16;

  /// Ambient motes that drift around the shell for the whole ceremony.
  // Spread over the whole screen rather than a ring around the shell, these
  // cover roughly 1.7x the area, so the counts go up to keep the field at the
  // density it read at before. Cost is the per-mote trig in the loop; the
  // draw itself is two drawRawPoints calls whatever the count.
  static const int ambientCount = 132;
  static const int ambientCountReduced = 68;
}

// ===========================================================================
// Strand definitions
// ===========================================================================

double _h(int i, int salt) {
  final v = sin(i * 127.1 + salt * 311.7) * 43758.5453;
  return v - v.floorToDouble();
}

class _Strand {
  final double th0, tMul, rOff, accent, vJitA, vJitB, t0;
  final double bAng, bCurl, bLen, bR0, wob, spin, hue;
  final double role, roleV, weav, wPh, wSp, tw, gLead;
  final int grp;

  _Strand(int k)
    : th0 = (k * 2.399963229728653) % (pi * 2),
      tMul = 0.82 + _h(k, 1) * 0.40,
      rOff = 1 + (_h(k, 2) - 0.5),
      accent = _h(k, 3),
      vJitA = _h(k, 4),
      vJitB = _h(k, 5),
      t0 = _h(k, 6),
      bAng = _h(k, 7) * pi * 2,
      bCurl = (_h(k, 8) - 0.5) * 2.2,
      bLen = 0.35 + _h(k, 9) * 0.85,
      bR0 = 0.10 + _h(k, 10) * 0.30,
      wob = _h(k, 11) * pi * 2,
      spin = (_h(k, 12) - 0.5) * 2,
      hue = _h(k, 13),
      grp = _h(k, 14) < 0.5 ? 0 : 1,
      role = _h(k, 19),
      roleV = 0.10 + _h(k, 20) * 0.80,
      weav = _h(k, 21),
      wPh = _h(k, 15) * pi * 2,
      wSp = 0.6 + _h(k, 16) * 1.6,
      tw = _h(k, 17),
      gLead = _h(k, 18);
}

/// Preallocated, reused across frames. Rebuilding these per frame would
/// allocate megabytes a second.
class HatchShellModel {
  final HatchShellSpecies species;
  final int strandCount;
  final int sampleCount;
  final List<_Strand> _strands;
  List<_Strand> get _s => _strands;

  // 6 rails per sample, in DUPLICATED pairs at the same offset so the colour
  // steps are hard edges rather than gradients:
  //     -1.0 dark | -0.33 dark : -0.33 lit | +0.33 lit : +0.33 dark | +1.0 dark
  // That reproduces the prototype exactly — a solid dark ribbon body with a
  // crisp bright filament down its centre at 33% of the width. Interpolating
  // the colour across the ribbon instead made every strand a soft mass, which
  // is what read as blurry; widening the lit band only made it worse.
  late final Float32List positions;
  late final Int32List colors;
  late final Uint16List indices;
  late final Float32List _px; // scratch: per-sample screen x
  late final Float32List _py;
  late final Float32List _pd; // scratch: per-sample depth
  late final Float32List _segDepth;
  late final Int32List _segOrder;
  late final Int32List _bucketCount;
  late final Int32List _bucketOffset;

  static const int _depthBuckets = 14;

  HatchShellModel({required this.species, required bool reduced})
    : strandCount = reduced
          ? (_kSpecies[species]!.strands * 0.78).round()
          : _kSpecies[species]!.strands,
      sampleCount = reduced
          ? HatchShellTuning.samplesReduced
          : HatchShellTuning.samples,
      _strands = List<_Strand>.generate(
        reduced
            ? (_kSpecies[species]!.strands * 0.78).round()
            : _kSpecies[species]!.strands,
        (k) => _Strand(k),
        growable: false,
      ) {
    final verts = strandCount * sampleCount * 6;
    final segs = strandCount * (sampleCount - 1);
    positions = Float32List(verts * 2);
    colors = Int32List(verts);
    indices = Uint16List(segs * 18);
    _px = Float32List(sampleCount);
    _py = Float32List(sampleCount);
    _pd = Float32List(sampleCount);
    _segDepth = Float32List(segs);
    _segOrder = Int32List(segs);
    _bucketCount = Int32List(_depthBuckets);
    _bucketOffset = Int32List(_depthBuckets);

    assert(
      verts <= 65535,
      'Vertex index overflows Uint16: $verts verts for $species. '
      'Lower the strand or sample count for this species.',
    );
  }
}

// ===========================================================================
// Painter
// ===========================================================================

class HatchShellPainter extends CustomPainter {
  /// Cinematic timeline position, 0..1.
  final double t;

  /// Wall-clock seconds. Motion is driven by this rather than [t] so the
  /// shell stays alive even while the timeline holds.
  final double clock;

  final HatchShellModel model;

  /// Each element's FULL three-colour palette, exactly as the prototype used
  /// them: a strand's colour is mixed between entries [0] and [1], and entry
  /// [2] is the bright accent. Collapsing these to one colour per element is
  /// what made the shell look washed out — all the vivid variation lived in
  /// the spread between [0] and [1].
  final List<Color> paletteA;
  final List<Color> paletteB;
  final List<Color> paletteResult;
  final ShellElementBehavior behaviorA;
  final ShellElementBehavior behaviorB;
  final ShellElementBehavior behaviorResult;
  final ShellRarity rarity;
  final Color? variantColor;
  final bool reduced;

  /// Fades the whole shell out (used by the cinematic's whiteout).
  final double opacity;

  HatchShellPainter({
    required this.t,
    required this.clock,
    required this.model,
    required this.paletteA,
    required this.paletteB,
    required this.paletteResult,
    required this.behaviorA,
    required this.behaviorB,
    required this.behaviorResult,
    this.rarity = ShellRarity.normal,
    this.variantColor,
    this.reduced = false,
    this.opacity = 1.0,
  });

  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
  static double _lerp(double a, double b, double t) => a + (b - a) * t;
  static double _easeOutCubic(double x) => 1 - pow(1 - x, 3).toDouble();
  static double _easeInCubic(double x) => x * x * x;
  static double _easeInOutCubic(double x) =>
      x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.01) return;

    final sp = _kSpecies[model.species]!;
    final f = sp.f;
    final mo = sp.m;
    final span = size.shortestSide;
    final cx = size.width / 2;
    final cy = size.height * 0.47;

    // ---- fusion: how far the two parents have resolved into the child -----
    final fuse = _easeInOutCubic(
      _clamp01((t - HatchShellTuning.fuseAt) / HatchShellTuning.fuseSpan),
    );
    final bA = ShellElementBehavior.lerpB(behaviorA, behaviorResult, fuse);
    final bB = ShellElementBehavior.lerpB(behaviorB, behaviorResult, fuse);
    final pA0 = Color.lerp(paletteA[0], paletteResult[0], fuse)!;
    final pA1 = Color.lerp(paletteA[1], paletteResult[1], fuse)!;
    final pB0 = Color.lerp(paletteB[0], paletteResult[0], fuse)!;
    final pB1 = Color.lerp(paletteB[1], paletteResult[1], fuse)!;

    final accent = rarity == ShellRarity.variant && variantColor != null
        ? variantColor!
        : paletteResult[2];
    final accMix = rarity == ShellRarity.variant
        ? max(HatchShellTuning.accentMix, 0.32)
        : HatchShellTuning.accentMix;

    // ---- the two clusters HOLD their separation --------------------------
    // Nothing walks them together: an approach drift is a rigid-body
    // translation, which reads as sliding. The coming-together IS converge.
    final sep = HatchShellTuning.split * span;
    const axis = -0.34;
    final dr = HatchShellTuning.clusterDrift * span;
    final oAx = cx + cos(axis) * sep + sin(clock * 0.61) * dr;
    final oAy = cy + sin(axis) * sep * 0.75 + cos(clock * 0.43 + 1.9) * dr;
    final oBx = cx + cos(axis + pi) * sep + sin(clock * 0.47 + 2.7) * dr;
    final oBy = cy + sin(axis + pi) * sep * 0.75 + cos(clock * 0.55 + 0.6) * dr;
    final spinA = HatchShellTuning.clusterChurn * clock * 0.30;
    final spinB = -HatchShellTuning.clusterChurn * clock * 0.26;

    // ---- shared motion, resolved before the structural branches ----------
    final br = 1 + mo.brAmp * sin(clock * mo.brSpd * pi * 2);
    final wob = mo.waist * sin(clock * 0.61 + 0.7);
    final yaw = clock * HatchShellTuning.yawSpeed;

    final m = model;
    final M = m.sampleCount;
    int segCursor = 0;
    int vertCursor = 0;

    for (int k = 0; k < m._s.length; k++) {
      final st = m._s[k];
      final isB = st.grp == 1;
      final b = isB ? bB : bA;
      final pal0 = isB ? pB0 : pA0;
      final pal1 = isB ? pB1 : pA1;
      final ox = isB ? oBx : oAx;
      final oy = isB ? oBy : oAy;
      final spin = isB ? spinB : spinA;
      final braid = (isB ? 1.0 : -1.0) * HatchShellTuning.braid * (1 - fuse);

      // ---- genesis: mote -> string ---------------------------------------
      // The stagger delays each strand's START and holds its duration, so
      // they finish at different times. Shortening the span instead made
      // every strand complete on the same frame and the field froze.
      final gTotal = max(
        0.02,
        HatchShellTuning.stringBy - HatchShellTuning.moteHold,
      );
      final gDur = max(0.02, gTotal * (1 - HatchShellTuning.sproutStagger));
      final gStart =
          HatchShellTuning.moteHold +
          st.gLead * gTotal * HatchShellTuning.sproutStagger;
      final gEnd = gStart + gDur;
      final grow = _easeOutCubic(_clamp01((t - gStart) / gDur));

      // Converge begins when THIS strand finishes sprouting, not when the
      // whole field does; that overlap removes the frozen gap between beats.
      final window = max(0.02, HatchShellTuning.convergeEnd - gEnd);
      final lead = gEnd + st.t0 * HatchShellTuning.stagger * window;
      final cSpan = window * (1 - st.t0 * HatchShellTuning.stagger);
      final form = _easeInOutCubic(_clamp01((t - lead) / cSpan));

      final cinch =
          (t > HatchShellTuning.convergeEnd &&
              t < HatchShellTuning.convergeEnd + 0.12)
          ? sin((t - HatchShellTuning.convergeEnd) / 0.12 * pi) *
                HatchShellTuning.overshoot
          : 0.0;

      double unrav = 0;
      if (t > HatchShellTuning.unravelAt) {
        unrav = _easeInCubic(
          _clamp01(
            (t - HatchShellTuning.unravelAt) /
                    (1 - HatchShellTuning.unravelAt) -
                st.t0 * 0.25,
          ),
        );
      }
      // Cull once a strand is almost transparent. At unrav 0.88 it is down to
      // ~2% alpha but still smeared over 3.3x its area, so the tail of the
      // unravel was paying full rasterisation cost for nothing visible.
      if (unrav >= 0.88) {
        // Still has to consume its vertex range or the buffers desync.
        vertCursor += M * 6;
        segCursor += M - 1;
        continue;
      }

      final flowAmp = HatchShellTuning.flow * grow * (1 - form);

      // ---- build the polyline --------------------------------------------
      for (int j = 0; j < M; j++) {
        final s = M == 1 ? 0.0 : j / (M - 1);
        final hp = _helix(
          st,
          s,
          yaw,
          b,
          cx,
          cy,
          span,
          clock,
          braid,
          f,
          sp,
          mo,
          br,
          wob,
        );
        double x, y, d;
        if (form < 1) {
          final sc = _scatter(st, s, ox, oy, span, grow, clock, flowAmp, spin);
          // Converge in POLAR space about the shell centre. A Cartesian lerp
          // is a straight line, so strands read as sliding to their slots.
          final sx = sc.dx - cx, sy = sc.dy - cy;
          final hx = hp.dx - cx, hy = hp.dy - cy;
          final rS = sqrt(sx * sx + sy * sy);
          final rH = sqrt(hx * hx + hy * hy);
          final aS = atan2(sy, sx);
          double da = atan2(hy, hx) - aS;
          while (da > pi) {
            da -= pi * 2;
          }
          while (da < -pi) {
            da += pi * 2;
          }
          final dirMul = isB ? _lerp(1, -1, HatchShellTuning.counterSpin) : 1.0;
          final extra = HatchShellTuning.swirl * (rS / (span * 0.5)) * dirMul;
          // The sin() envelope is zero at both ends, so however hard a strand
          // swirls it still lands exactly on its slot.
          final a = aS + da * form + extra * sin(pi * form);
          final r = _lerp(
            rS,
            rH,
            pow(form, 1 + HatchShellTuning.radiusLag * 2).toDouble(),
          );
          x = cx + cos(a) * r;
          y = cy + sin(a) * r;
          d = _lerp(0.5, hp.depth, form);
        } else {
          x = hp.dx;
          y = hp.dy;
          d = hp.depth;
        }

        if (cinch != 0) {
          x += (x - cx) * cinch * 0.10;
          y += (y - cy) * cinch * 0.10;
        }
        if (unrav > 0) {
          final ddx = x - cx, ddy = y - cy;
          final push = 1 + unrav * 2.6;
          final sp2 = st.spin * unrav * 0.9;
          final cs = cos(sp2), sn = sin(sp2);
          x = cx + (ddx * cs - ddy * sn) * push;
          y = cy + (ddx * sn + ddy * cs) * push;
          d = _lerp(d, 1, unrav * 0.6);
        }
        m._px[j] = x;
        m._py[j] = y;
        m._pd[j] = d;
      }

      // ---- colour ---------------------------------------------------------
      final isAcc = st.accent < accMix;
      Color c = isAcc ? accent : Color.lerp(pal0, pal1, st.hue)!;
      if (rarity == ShellRarity.prismatic) {
        c = _hueRotate(c, st.hue + clock * HatchShellTuning.prismRate);
      }

      final flick = b.flick > 0
          ? 1 - b.flick * 0.5 * (0.5 + 0.5 * sin(clock * 7 + st.wob * 3))
          : 1.0;
      final twinkle = grow >= 1
          ? 1.0
          : 1 -
                HatchShellTuning.moteTwinkle *
                    (1 - grow) *
                    (0.5 + 0.5 * sin(clock * 5.5 + st.tw * pi * 2));
      // A mote is the subject of the opening beat, so it is drawn at full
      // brightness rather than inheriting the dim "unformed" level.
      final bright = max(_lerp(0.28, 1, form), 1.0 * (1 - grow));
      final fade = (1 - unrav) * b.aMul * flick * twinkle * bright * opacity;
      // A dot needs weight to read as a particle; a string does not.
      final widthMul = _lerp(HatchShellTuning.moteWidth, 1, grow) * b.wMul;

      final coreR = (c.r * 255.0).round().clamp(0, 255);
      final coreG = (c.g * 255.0).round().clamp(0, 255);
      final coreB = (c.b * 255.0).round().clamp(0, 255);
      final edgeR = (coreR * 0.45).round();
      final edgeG = (coreG * 0.45).round();
      final edgeB = (coreB * 0.45).round();
      final litR = coreR + ((255 - coreR) * (isAcc ? 0.18 : 0.34)).round();
      final litG = coreG + ((255 - coreG) * (isAcc ? 0.18 : 0.34)).round();
      final litB = coreB + ((255 - coreB) * (isAcc ? 0.18 : 0.34)).round();

      // ---- emit ribbon rails ---------------------------------------------
      for (int j = 0; j < M; j++) {
        // Tangent from neighbours so the ribbon stays smooth at the joins.
        final jp = j > 0 ? j - 1 : 0;
        final jn = j < M - 1 ? j + 1 : M - 1;
        double tx = m._px[jn] - m._px[jp];
        double ty = m._py[jn] - m._py[jp];
        final tl = sqrt(tx * tx + ty * ty);
        if (tl > 1e-5) {
          tx /= tl;
          ty /= tl;
        } else {
          tx = 1;
          ty = 0;
        }
        // Perpendicular, scaled by depth: nearer ribbons are wider.
        final d = m._pd[j];
        // Half-width. The prototype's edge stroke was w * 1.9, but only ever
        // evaluated at a bucketed depth of ~0.75; 0.72 makes a d=1.0 ribbon
        // land on the same ~5px the prototype topped out at.
        final w =
            _lerp(HatchShellTuning.widthMin, HatchShellTuning.widthMax, d) *
            widthMul *
            0.72;
        final nx = -ty * w, ny = tx * w;

        final alpha =
            (_lerp(HatchShellTuning.alphaBack, HatchShellTuning.alphaFront, d) *
                    fade *
                    255)
                .clamp(0, 255)
                .toInt();
        final edge =
            (alpha * 0.85).toInt() << 24 | edgeR << 16 | edgeG << 8 | edgeB;
        final core = alpha << 24 | litR << 16 | litG << 8 | litB;

        // 0.33 = the prototype's core/edge stroke-width ratio (0.62 / 1.9).
        const inner = 0.33;
        final px = m._px[j], py = m._py[j];
        final v0 = vertCursor;
        void put(int i, double o, int c) {
          m.positions[(v0 + i) * 2] = px + nx * o;
          m.positions[(v0 + i) * 2 + 1] = py + ny * o;
          m.colors[v0 + i] = c;
        }

        put(0, -1.0, edge);
        put(1, -inner, edge); // hard step: same offset, different colour
        put(2, -inner, core);
        put(3, inner, core);
        put(4, inner, edge);
        put(5, 1.0, edge);
        vertCursor += 6;

        if (j < M - 1) {
          m._segDepth[segCursor] = (m._pd[j] + m._pd[j + 1]) * 0.5;
          segCursor++;
        }
      }
    }

    if (segCursor == 0) return;

    // ---- depth sort, back to front ---------------------------------------
    // Bucket sort rather than a comparison sort: O(n) with no allocation, and
    // 14 buckets is far finer than the eye resolves through alpha falloff.
    _bucketSortSegments(m, segCursor);

    // ---- write indices in sorted order -----------------------------------
    int ic = 0;
    for (int o = 0; o < segCursor; o++) {
      final seg = m._segOrder[o];
      final strand = seg ~/ (M - 1);
      final j = seg % (M - 1);
      final base = (strand * M + j) * 6;
      final nextB = base + 6;
      // Only the three REAL bands are spanned (0-1 dark, 2-3 lit, 4-5 dark);
      // the 1-2 and 3-4 pairs share an offset and would be degenerate.
      for (final q in const [0, 2, 4]) {
        m.indices[ic++] = base + q;
        m.indices[ic++] = base + q + 1;
        m.indices[ic++] = nextB + q;
        m.indices[ic++] = nextB + q;
        m.indices[ic++] = base + q + 1;
        m.indices[ic++] = nextB + q + 1;
      }
    }

    final verts = ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.sublistView(m.positions, 0, vertCursor * 2),
      colors: Int32List.sublistView(m.colors, 0, vertCursor),
      indices: Uint16List.sublistView(m.indices, 0, ic),
    );
    // The paint must stay SHADER-LESS: with no shader the per-vertex colours
    // are what gets drawn, carrying both the depth shading and the lit ribbon
    // core. Verified in test/hatch_shell_vertices_test.dart, which also pins
    // that per-vertex alpha blends rather than rendering opaque.
    canvas.drawVertices(verts, BlendMode.srcOver, Paint());
    verts.dispose();
  }

  static void _bucketSortSegments(HatchShellModel m, int count) {
    const nb = HatchShellModel._depthBuckets;
    final counts = m._bucketCount;
    for (int i = 0; i < nb; i++) {
      counts[i] = 0;
    }
    for (int i = 0; i < count; i++) {
      var bIdx = (m._segDepth[i] * nb).floor();
      if (bIdx < 0) bIdx = 0;
      if (bIdx >= nb) bIdx = nb - 1;
      counts[bIdx]++;
    }
    // Prefix sum -> write offsets. Reuses a preallocated buffer: a
    // List.filled here allocated on every single frame.
    int running = 0;
    final offsets = m._bucketOffset;
    for (int i = 0; i < nb; i++) {
      offsets[i] = running;
      running += counts[i];
    }
    for (int i = 0; i < count; i++) {
      var bIdx = (m._segDepth[i] * nb).floor();
      if (bIdx < 0) bIdx = 0;
      if (bIdx >= nb) bIdx = nb - 1;
      m._segOrder[offsets[bIdx]++] = i;
    }
  }

  // -------------------------------------------------------------------------
  // Poses
  // -------------------------------------------------------------------------

  /// `grow` is the mote->string draw: at 0 every sample collapses onto the
  /// head, so the strand renders as a single dot with no special case.
  ShellPoint _scatter(
    _Strand st,
    double s,
    double ox,
    double oy,
    double span,
    double grow,
    double clock,
    double flowAmp,
    double spin,
  ) {
    final sg = s * grow;
    final a = st.bAng + sg * st.bCurl + spin;
    final rad = (st.bR0 + sg * st.bLen) * HatchShellTuning.burstReach;
    final moteSpread = (1 - grow) * HatchShellTuning.moteLength * span;
    // Motes drift hardest, but the drift never fully dies — a strand frozen
    // between sprouting and converging was the static-looking gap.
    final w = HatchShellTuning.moteWander * (1 - 0.65 * grow) * span;
    final wx = cos(clock * st.wSp + st.wPh) * w;
    final wy = sin(clock * st.wSp * 0.83 + st.wPh * 1.7) * w;
    // Travelling wave down the length: a drawn string behaves like a filament
    // in a current instead of a dead line.
    final fa =
        sin(s * pi * 2 * HatchShellTuning.flowWaves + clock * 2.4 + st.wPh) *
        flowAmp *
        span;
    // Spread along the strand's own burst direction, so a mote already points
    // the way its string will be drawn.
    final along = (s - 0.5) * moteSpread;
    return ShellPoint(
      ox + cos(a) * rad * span + wx - sin(a) * fa + cos(st.bAng) * along,
      oy + sin(a) * rad * span + wy + cos(a) * fa + sin(st.bAng) * along,
      0.5,
    );
  }

  ShellPoint _helix(
    _Strand st,
    double s,
    double yaw,
    ShellElementBehavior b,
    double cx,
    double cy,
    double span,
    double clock,
    double braid,
    _Form f,
    _Species sp,
    _Motion mo,
    double br,
    double wob,
  ) {
    double twist(double x) =>
        mo.twAmp * sin(pi * 2 * (x * mo.twFreq - clock * mo.twSpd));

    final R = sp.radius, H = sp.height;

    // HALO (mystic): a tilted orbital band. Its own parameterisation — it does
    // not live on the shell surface, it orbits it.
    if (f.haloFrac > 0 && st.role < f.haloFrac) {
      final a = st.th0 + s * pi * 2 + yaw + twist(s) * 0.5;
      final rr =
          R * f.haloR * (1 + f.haloWob * sin(s * pi * 4 + clock * 0.8)) / br;
      final px = cos(a) * rr, pz = sin(a) * rr;
      final y2 = -pz * sin(f.haloTilt), z2 = pz * cos(f.haloTilt);
      return ShellPoint(
        cx + px * span,
        cy + y2 * span,
        _clamp01(z2 / (rr == 0 ? 1 : rr) * 0.5 + 0.5),
      );
    }
    // PARALLEL (mystic): a latitude ring rather than a pole-to-pole meridian.
    if (f.ringFrac > 0 && st.role < f.haloFrac + f.ringFrac) {
      final vR = st.roleV;
      final p0 = _lerp(sp.pointTop, sp.pointBase, _clamp01(vR + wob));
      final rr =
          pow(max(sin(pi * vR), 1e-4), p0).toDouble() *
          R *
          (1 + sp.shellThick * st.rOff * 0.5) /
          br;
      final a = st.th0 + s * pi * 2 + yaw + braid + twist(vR);
      return ShellPoint(
        cx + cos(a) * rr * span,
        cy + (vR - 0.5) * H * br * span,
        (sin(a) + 1) * 0.5,
      );
    }
    // HOLE (mask): a torus facing the camera, so the aperture is visible.
    if (f.hole > 0) {
      final rt = R * (1 - f.hole);
      final rm = R * f.hole;
      final ang = st.th0 + s * pi * 2 * f.wrap + yaw + braid + twist(s);
      final tub = st.th0 * 2.7 + s * pi * 2 * f.coil + twist(s * 1.6) * 0.8;
      final rr = (rm + rt * cos(tub) * (1 + sp.shellThick * st.rOff)) / br;
      return ShellPoint(
        cx + cos(ang) * rr * span,
        cy + sin(ang) * rr * f.aspect * br * span,
        _clamp01(sin(tub) * 0.5 + 0.5),
      );
    }

    final vA = sp.coverage * st.vJitA, vB = 1 - sp.coverage * st.vJitB;
    double v = _lerp(vA, vB, s);
    if (b.facet >= 1.5) v = (v * b.facet).roundToDouble() / b.facet;
    if (b.taper != 0) v = _lerp(v, v * (1 - b.taper * 0.5), s * s);

    final p = _lerp(sp.pointTop, sp.pointBase, _clamp01(v + wob));
    double r;
    if (f.bulbs > 0) {
      // Two lobes from one profile, plus a neck floor near the waist so the
      // halves are joined by material rather than stacked with a gap.
      final lobe = pow(sin(pi * v * f.bulbs).abs(), p).toDouble();
      final neck = f.neck * exp(-pow((v - 0.5) / f.neckW, 2).toDouble());
      r = R * max(lobe, neck);
    } else {
      r = pow(max(sin(pi * v), 1e-4), p).toDouble() * R;
    }
    if (f.cyl > 0) {
      // A MIX toward a straight column, not a switch. At 1.0 it was a pipe.
      final e = min(v, 1 - v) / max(f.cap, 1e-4);
      final col = R * (e < 1 ? sqrt(max(e, 0)) : 1);
      r = _lerp(r, col, f.cyl);
    }

    r *= (1 + sp.shellThick * st.rOff) / br;

    // Angle is resolved BEFORE the shaping terms that depend on it. Pinching
    // by st.th0 only ever scaled whole strands and produced no pinch at all.
    //
    // Counter-wound family: strands winding opposite ways cross into a
    // lattice. Currently off for every species (weave = 0) but kept because
    // it is the mechanism behind the reference's weave.
    final dirW = st.weav < mo.weave ? -1.0 : 1.0;
    double th =
        st.th0 + (sp.turns * b.turns) * st.tMul * pi * 2 * v * dirW + yaw;
    if (b.kink > 0.1) th += sin(s * b.kink * pi) * 0.09;
    if (b.planes >= 2) {
      final stp = pi * 2 / b.planes;
      th = (th / stp).roundToDouble() * stp;
    }
    th += braid;
    // Travelling torsional wave: the band direction reverses as it passes,
    // which is what makes the shell look like it is spinning through itself.
    th += twist(v);

    if (f.ribDepth > 0) r *= 1 + f.ribDepth * sin(v * pi * 2 * f.rib);
    if (f.spire > 0) r *= 1 - f.spire * pow(1 - v, 3).toDouble();
    if (f.sweep > 0 && s > 0.66) {
      final e = (s - 0.66) / 0.34;
      r *= 1 + f.sweep * e * e;
    }
    if (b.wave != 0) {
      r *= 1 + b.wave * sin(s * pi * 2 * b.waveF + st.wob + clock * 1.6);
    }
    if (b.breathe != 0) r *= 1 + b.breathe * sin(clock * 0.9 + st.wob);
    if (b.pulse != 0) {
      r *= 1 + b.pulse * pow(max(0, sin(clock * 2.6)), 3).toDouble();
    }

    double y = (v - 0.5) * H * br;
    if (b.rise != 0) y += b.rise * (1 - v) * 0.35;
    if (b.sag != 0) y += b.sag * sin(pi * v) * 0.5;
    if (b.tendril != 0 && s > 0.82) {
      final e = (s - 0.82) / 0.18;
      r *= 1 + b.tendril * e * e;
      th += e * e * 1.1;
    }
    if (f.sweep > 0 && s > 0.66) {
      final e = (s - 0.66) / 0.34;
      y += f.sweep * e * e * 0.10;
    }

    // WING: some strands wrap a core shell, the rest wrap two narrow lobes
    // squashed, tilted and pushed out to either side. Same wrapped-strand
    // maths as every other species — a feather fan read as a different family.
    if (f.wingFrac > 0 && st.role > 1 - f.wingFrac) {
      final side = st.vJitA >= 0.5 ? 1.0 : -1.0;
      final bx = cos(th) * r * f.wingW;
      final by = y * f.wingH;
      final a = side * f.wingTilt, ca = cos(a), sa = sin(a);
      return ShellPoint(
        cx + (bx * ca - by * sa + side * f.wingOut * R) * span,
        cy + (bx * sa + by * ca + f.wingY * H) * span,
        (sin(th) + 1) * 0.5,
      );
    }

    return ShellPoint(
      cx + cos(th) * r * span,
      cy + y * span,
      (sin(th) + 1) * 0.5,
    );
  }

  static Color _hueRotate(Color c, double turn) {
    final hsl = HSLColor.fromColor(c);
    var h = (hsl.hue / 360.0 + turn) % 1.0;
    if (h < 0) h += 1.0;
    return hsl.withHue(h * 360.0).toColor();
  }

  @override
  bool shouldRepaint(covariant HatchShellPainter old) =>
      old.t != t ||
      old.clock != clock ||
      old.opacity != opacity ||
      old.rarity != rarity ||
      old.paletteResult != paletteResult;
}

@immutable
class ShellPoint {
  final double dx, dy, depth;
  const ShellPoint(this.dx, this.dy, this.depth);
}

// ===========================================================================
// Ambient motes
// ===========================================================================

/// Motes drifting around the shell for the whole ceremony. Drawn in two
/// batches (behind / in front) with `drawRawPoints`, so it is two draw calls
/// regardless of count.
class HatchShellAmbientPainter extends CustomPainter {
  final double t;
  final double clock;
  final Color tint;
  final Color accent;
  final bool reduced;
  final double opacity;

  final Float32List _back;
  final Float32List _front;

  HatchShellAmbientPainter({
    required this.t,
    required this.clock,
    required this.tint,
    required this.accent,
    this.reduced = false,
    this.opacity = 1.0,
  }) : _back = Float32List(
         (reduced
                 ? HatchShellTuning.ambientCountReduced
                 : HatchShellTuning.ambientCount) *
             2,
       ),
       _front = Float32List(
         (reduced
                 ? HatchShellTuning.ambientCountReduced
                 : HatchShellTuning.ambientCount) *
             2,
       );

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.01) return;
    final n = reduced
        ? HatchShellTuning.ambientCountReduced
        : HatchShellTuning.ambientCount;
    final span = size.shortestSide;

    // Fade in with the ceremony, never fully out — these are the field the
    // shell lives in, so they outlast the shell itself.
    final env = _HatchEase.interval(t, 0.02, 0.20) * opacity;
    if (env <= 0.01) return;

    int nb = 0, nf = 0;
    for (int i = 0; i < n; i++) {
      // Each mote keeps its own home anywhere on screen and drifts on a small
      // local ellipse around it.
      //
      // Every mote used to orbit one shared centre at 0.22-0.68 of the short
      // side, which is a ring, not a field: a hole through the middle and
      // nothing at all near the top and bottom edges of a tall phone screen.
      // Scattering the homes and shrinking the orbits fills the screen while
      // keeping the per-mote cost and the two drawRawPoints calls identical.
      //
      // Homes are inset 2% so a mote at the edge of its orbit still lands on
      // screen rather than drifting off it.
      final hx = (0.02 + _h(i, 31) * 0.96) * size.width;
      final hy = (0.02 + _h(i, 37) * 0.96) * size.height;
      final rad = (0.02 + _h(i, 38) * 0.07) * span;
      final speed = 0.10 + _h(i, 32) * 0.26;
      final phase = _h(i, 33) * pi * 2;
      final tilt = 0.45 + _h(i, 34) * 0.55;
      final bobA = (0.01 + _h(i, 35) * 0.05) * span;

      final a = phase + clock * speed;
      final x = hx + cos(a) * rad;
      final y =
          hy +
          sin(a) * rad * tilt +
          sin(clock * (0.3 + _h(i, 36) * 0.5) + phase) * bobA;

      // sin(a) doubles as the depth cue: behind the shell or in front of it.
      if (sin(a) < 0) {
        _back[nb * 2] = x;
        _back[nb * 2 + 1] = y;
        nb++;
      } else {
        _front[nf * 2] = x;
        _front[nf * 2 + 1] = y;
        nf++;
      }
    }

    final p = Paint()
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // A 2px antialiased round point is almost entirely soft edge, which reads
    // as fuzz rather than as a mote. Each one is drawn as a coloured body with
    // a small, fully opaque near-white core on top — the hard centre is what
    // makes it look like a point of light instead of a smudge.
    if (nb > 0) {
      final back = Float32List.sublistView(_back, 0, nb * 2);
      p
        ..strokeWidth = 2.16
        ..color = tint.withValues(alpha: env * 0.5);
      canvas.drawRawPoints(ui.PointMode.points, back, p);
      p
        ..strokeWidth = 0.9
        ..color = Color.lerp(
          tint,
          const Color(0xFFFFFFFF),
          0.55,
        )!.withValues(alpha: env * 0.8);
      canvas.drawRawPoints(ui.PointMode.points, back, p);
    }
    if (nf > 0) {
      final front = Float32List.sublistView(_front, 0, nf * 2);
      p
        ..strokeWidth = 3.42
        ..color = accent.withValues(alpha: env * 0.85);
      canvas.drawRawPoints(ui.PointMode.points, front, p);
      p
        ..strokeWidth = 1.44
        ..color = Color.lerp(
          accent,
          const Color(0xFFFFFFFF),
          0.7,
        )!.withValues(alpha: env);
      canvas.drawRawPoints(ui.PointMode.points, front, p);
    }
  }

  @override
  bool shouldRepaint(covariant HatchShellAmbientPainter old) =>
      old.clock != clock || old.t != t || old.opacity != opacity;
}

class _HatchEase {
  static double interval(double t, double begin, double end) {
    if (t <= begin) return 0;
    if (t >= end) return 1;
    final x = (t - begin) / (end - begin);
    return Curves.easeOut.transform(x.clamp(0.0, 1.0));
  }
}
