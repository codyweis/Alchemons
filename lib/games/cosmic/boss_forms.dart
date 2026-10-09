part of 'enemy_body_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THE SIX BOSSES
//
//  A boss used to be one body — a sphere with a crown — varied by counts:
//  blades for its discipline, moons for its archetype. Counts do not make a
//  boss memorable. Now each archetype is its own thing, built round one
//  idea and nothing else:
//
//    charger     the Comet        a blazing nucleus trailing a river of
//                                 embers, debris tumbling round it
//    gunner      the Singularity  a black hole in an accretion disk, the far
//                                 side lensed up over the top
//    skirmisher  the Ouroboros    a serpent of faceted vertebrae swimming a
//                                 circle round an egg of light, head chasing
//                                 tail
//    bulwark     the Spire        a broken spire of black obsidian with fire
//                                 in its veins, debris wheeling round it;
//                                 shielded, a glass barrier turns round it
//    carrier     the Hive         a murmuration of hundreds of motes on
//                                 shifting orbits round a dark core
//    warden      the Armillary    brass rings turning on three axes round a
//                                 sun, runes of light set in them
//
//  The element colors the light; the form is the archetype's. All in unit
//  space: the caller translates to the boss and scales by its radius.
// ─────────────────────────────────────────────────────────────────────────────

enum BossForm { comet, singularity, ouroboros, spire, hive, armillary }

BossForm bossFormFor(BossType t) => switch (t) {
  BossType.charger => BossForm.comet,
  BossType.gunner => BossForm.singularity,
  BossType.skirmisher => BossForm.ouroboros,
  BossType.bulwark => BossForm.spire,
  BossType.carrier => BossForm.hive,
  BossType.warden => BossForm.armillary,
};

/// How far above its centre a form reaches, in radii — where its health bar
/// can sit clear of it.
double bossFormReach(BossForm f) => switch (f) {
  BossForm.comet => 1.1,
  BossForm.singularity => 1.5,
  BossForm.ouroboros => 1.35,
  BossForm.spire => 1.6,
  BossForm.hive => 1.7,
  BossForm.armillary => 1.8,
};

void paintBossForm(
  Canvas c,
  EnemyPalette pal,
  BossForm form, {
  required double time,
  double seed = 0,
  double heading = 0,
  double charge = 0,
  bool enraged = false,
  bool shield = false,
  bool reduceGlows = false,
  double flash = 0,
}) {
  final spin = enraged ? 1.8 : 1.0;
  switch (form) {
    case BossForm.comet:
      _paintComet(c, pal, time, seed, heading, charge, spin, reduceGlows);
    case BossForm.singularity:
      _paintSingularity(c, pal, time, seed, spin, reduceGlows);
    case BossForm.ouroboros:
      _paintOuroboros(c, pal, time, seed, spin, reduceGlows);
    case BossForm.spire:
      _paintSpire(c, pal, time, seed, spin, shield, reduceGlows);
    case BossForm.hive:
      _paintHive(c, pal, time, seed, spin, reduceGlows);
    case BossForm.armillary:
      _paintArmillary(c, pal, time, seed, spin, reduceGlows);
  }
  _hitFlash(c, flash, 0.9);
}

// ── the Comet ───────────────────────────────────────────────────────────────

/// Tail embers: (rate, phase, lateral, wobble).
final List<(double, double, double, double)> _cometTail = () {
  final rng = Random(51);
  return [
    for (var i = 0; i < 380; i++)
      (
        0.2 + rng.nextDouble() * 0.32,
        rng.nextDouble(),
        rng.nextDouble() + rng.nextDouble() - 1,
        rng.nextDouble() * 2 * pi,
      ),
  ];
}();

final List<FacetMesh> _debris = [
  for (var k = 0; k < 3; k++)
    FacetMesh.rock(jitter: 0.3, seed: 40 + k * 3.1, sx: 1.2),
];

void _paintComet(
  Canvas c,
  EnemyPalette pal,
  double time,
  double seed,
  double heading,
  double charge,
  double spin,
  bool reduceGlows,
) {
  if (!reduceGlows) _circle(c, pal.glow, 2.4);
  c.save();
  c.rotate(heading);
  // The coma, drawn out behind.
  c.save();
  c.translate(-1.3 - 0.8 * charge, 0);
  c.scale(2.4 + 1.4 * charge, 0.95);
  _circle(c, pal.glow, 1, 0.9);
  c.restore();

  // The tail: embers loosed from the nucleus, spreading and cooling as they
  // fall behind. Charging, it streams longer and faster.
  final len = 4.4 + 3.4 * charge;
  final rate = (1 + 1.2 * charge) * spin;
  _grainReset();
  for (final (r, ph, lat, wob) in _cometTail) {
    final u = _frac(time * r * rate + ph + seed);
    final x = 0.25 - u * len;
    final y = lat * (0.2 + 1.2 * pow(u, 0.85)) + 0.16 * u * sin(time * 1.9 + wob);
    _grainAdd(u < 0.14 ? 0 : (u < 0.4 ? 1 : (u < 0.72 ? 2 : 3)), x, y);
  }
  _grainDraw(c, 3, 0.035, Color.lerp(pal.essence, pal.ink, 0.4)!.withValues(
    alpha: 0.45,
  ));
  _grainDraw(c, 2, 0.045, pal.essence.withValues(alpha: 0.65));
  _grainDraw(c, 1, 0.06, pal.essence);
  _grainDraw(c, 0, 0.075, pal.hot);

  // Debris tumbling round the nucleus, through the coma.
  final near = <int>[];
  void debris(int k) {
    final a = time * 1.2 * spin + k * 2.1 + seed;
    _rot.euler(time * 1.1 + k, time * 0.7 + k * 2, k * 1.3);
    meshBatch.add(
      _debris[k],
      _rot,
      pal,
      scale: 0.22 + 0.04 * k,
      ox: cos(a) * 1.0,
      oy: sin(a) * 0.42,
      oz: sin(a) * 0.9,
      inset: 0,
      seamAlpha: 0,
      lit: 0.16,
      rimGlow: 0.6,
      fire: 2.4,
    );
  }

  for (var k = 0; k < 3; k++) {
    final a = time * 1.2 * spin + k * 2.1 + seed;
    if (sin(a) > 0) {
      near.add(k);
    } else {
      debris(k);
    }
  }
  meshBatch.flush(c);
  // The nucleus: white at the heart.
  _sparkAt(c, pal, Offset.zero, 0.85 + 0.25 * charge);
  _sparkAt(c, pal, Offset.zero, 0.45);
  for (final k in near) {
    debris(k);
  }
  meshBatch.flush(c);
  c.restore();
}

// ── the Singularity ─────────────────────────────────────────────────────────

const double _kDiskFlat = 0.3;
const double _kDiskInner = 1.3, _kDiskOuter = 3.0;

/// Disk motes: (radius, angle, twinkle phase, size).
final List<(double, double, double, double)> _diskMotes = () {
  final rng = Random(61);
  return [
    for (var i = 0; i < 560; i++)
      (
        _kDiskInner +
            (_kDiskOuter - _kDiskInner) * pow(rng.nextDouble(), 1.4),
        rng.nextDouble() * 2 * pi,
        rng.nextDouble() * 2 * pi,
        rng.nextDouble(),
      ),
  ];
}();

/// Streams falling in: (start radius, angle, fall time, phase).
final List<(double, double, double, double)> _diskInfall = () {
  final rng = Random(62);
  return [
    for (var i = 0; i < 40; i++)
      (
        2.0 + rng.nextDouble(),
        rng.nextDouble() * 2 * pi,
        3.0 + rng.nextDouble() * 3.0,
        rng.nextDouble(),
      ),
  ];
}();

final Paint _void = Paint()..color = const Color(0xFF000000);

void _paintSingularity(
  Canvas c,
  EnemyPalette pal,
  double time,
  double seed,
  double spin,
  bool reduceGlows,
) {
  c.save();
  c.rotate(-0.22);
  // The hot inner rim, in the disk's plane.
  if (!reduceGlows) {
    c.save();
    c.scale(1, _kDiskFlat);
    _circle(c, pal.accretion, 3.3, 1);
    _circle(c, pal.accretion, 3.3, 0.5 + 0.3 * sin(time * 0.9));
    c.restore();
  }

  // Buckets: heat 0–3; far +0, near +4, lensed +8.
  _grainReset();
  void add(double rad, double a) {
    final f = (rad - _kDiskInner) / (_kDiskOuter - _kDiskInner);
    final heat = f < 0.12 ? 0 : (f < 0.34 ? 1 : (f < 0.64 ? 2 : 3));
    final s = sin(a), co = cos(a);
    final far = s < 0;
    _grainAdd(heat + (far ? 0 : 4), co * rad, s * rad * _kDiskFlat);
    if (!far) return;
    // The far half, bent up over the top of the hole.
    final open = pow(co.abs(), 4).toDouble();
    final hug = 1.07 + 0.32 * f;
    final bend = hug + (rad - hug) * open;
    final th = co * pi / 2;
    _grainAdd(heat + 8, sin(th) * bend, -cos(th) * bend);
  }

  for (final (rad, a0, _, _) in _diskMotes) {
    add(rad, a0 + time * 0.9 * spin / (rad * sqrt(rad)));
  }
  for (final (r0, a0, fall, ph) in _diskInfall) {
    final life = (time / fall + ph) % 1.0;
    if (life > 0.92) continue;
    add(r0 - (r0 - _kDiskInner * 0.9) * pow(life, 1.4), a0 + life * 3.2);
  }

  final heat = [
    pal.hot,
    Color.lerp(pal.hot, pal.essence, 0.5)!,
    pal.essence,
    Color.lerp(pal.essence, pal.ink, 0.45)!,
  ];
  void matter(int offset, double alpha) {
    for (var k = 3; k >= 0; k--) {
      _grainDraw(
        c,
        k + offset,
        0.035 + 0.008 * (3 - k),
        heat[k].withValues(alpha: alpha * (0.95 - k * 0.14)),
      );
    }
  }

  matter(0, 1);
  // The hole. Nothing rings it but the light bent round it.
  c.drawCircle(Offset.zero, 1, _void);
  matter(8, 0.9);
  matter(4, 1);
  c.restore();
}

// ── the Ouroboros ───────────────────────────────────────────────────────────

const int _kVertebrae = 22;
final FacetMesh _vertebra = FacetMesh.crystal(
  sides: 6,
  height: 1.5,
  radius: 0.42,
  jitter: 0.08,
  seed: 71,
);
final FacetMesh _serpentHead = FacetMesh.crystal(
  sides: 5,
  height: 1.6,
  radius: 0.5,
  shoulder: 0.4,
  jitter: 0.1,
  seed: 73,
);
final Rot3 _coilTilt = Rot3().setX(0.8);
final Rot3 _alongZ = Rot3();
final List<(double, int, double, double, double)> _coilOrder = [];

void _paintOuroboros(
  Canvas c,
  EnemyPalette pal,
  double time,
  double seed,
  double spin,
  bool reduceGlows,
) {
  if (!reduceGlows) _circle(c, pal.glow, 2.3);
  final t = _coilTilt.m;
  const span = 2 * pi - 0.6;
  final swim = time * 0.8 * spin + seed;
  _coilOrder.clear();
  for (var k = 0; k < _kVertebrae; k++) {
    final th = swim - k * span / (_kVertebrae - 1);
    final rr = 1.08 + 0.07 * sin(time * 4.0 - k * 0.8);
    final h = 0.1 * sin(time * 3.0 - k * 0.55);
    final lx = cos(th) * rr, ly = sin(th) * rr, lz = h;
    _coilOrder.add((
      t[6] * lx + t[7] * ly + t[8] * lz,
      k,
      t[0] * lx + t[1] * ly + t[2] * lz,
      t[3] * lx + t[4] * ly + t[5] * lz,
      th,
    ));
  }
  _coilOrder.sort((a, b) => a.$1.compareTo(b.$1));

  void coil(bool near) {
    for (final (z, k, x, y, th) in _coilOrder) {
      if ((z > 0) != near) continue;
      // Long axis along the body, rolling as it swims.
      _alongZ.setZ(th);
      _rot.mul(_coilTilt, _alongZ);
      _spinY.setY(time * 2.2 + k * 0.7);
      _rot.mul(_rot, _spinY);
      final head = k == 0;
      meshBatch.add(
        head ? _serpentHead : _vertebra,
        _rot,
        pal,
        scale: head ? 0.6 : 0.44 * (1 - 0.62 * k / (_kVertebrae - 1)),
        ox: x,
        oy: y,
        oz: z,
        inset: 0.05,
        seamAlpha: 0.45,
        lit: 0.5,
        fire: 2.0,
      );
    }
    meshBatch.flush(c);
  }

  coil(false);
  // The egg it guards.
  c.save();
  c.scale(0.5);
  _circle(c, pal.orb, 1);
  c.restore();
  _sparkAt(c, pal, Offset.zero, 0.4 + 0.04 * sin(time * 2));
  coil(true);
}

// ── the Spire ───────────────────────────────────────────────────────────────

final FacetMesh _spire = FacetMesh.crystal(
  sides: 7,
  height: 3.3,
  radius: 0.66,
  shoulder: 0.28,
  jitter: 0.24,
  seed: 83,
  tipLean: 0.18,
);
final FacetMesh _barrier = FacetMesh.crystal(
  sides: 4,
  height: 4.1,
  radius: 1.75,
);
final Rot3 _lean = Rot3().setX(-0.28);
final Rot3 _rock = Rot3();
final Rot3 _ringTiltBoss = Rot3().setX(1.2);
final List<(double, int, double, double)> _debrisOrder = [];

void _paintSpire(
  Canvas c,
  EnemyPalette pal,
  double time,
  double seed,
  double spin,
  bool shield,
  bool reduceGlows,
) {
  if (!reduceGlows) _circle(c, pal.glow, 2.5);
  final bob = 0.06 * sin(time * 0.9 + seed);
  final pulse = 0.5 + 0.5 * sin(time * 1.3 + seed);

  // Debris on a tilted ring, split round the spire by depth.
  final t = _ringTiltBoss.m;
  _debrisOrder.clear();
  for (var k = 0; k < 6; k++) {
    final a = time * 0.5 * spin + k * pi / 3 + seed;
    final rr = 1.45 + 0.12 * sin(k * 2.1);
    final lx = cos(a) * rr, ly = sin(a) * rr, lz = 0.0;
    _debrisOrder.add((
      t[6] * lx + t[7] * ly + t[8] * lz,
      k,
      t[0] * lx + t[1] * ly + t[2] * lz,
      t[3] * lx + t[4] * ly + t[5] * lz + bob,
    ));
  }
  _debrisOrder.sort((a, b) => a.$1.compareTo(b.$1));
  void debris(bool near) {
    for (final (z, k, x, y) in _debrisOrder) {
      if ((z > 0) != near) continue;
      _alongZ.euler(time * 0.8 + k, time * 0.6 + k * 2, k * 1.1);
      meshBatch.add(
        _debris[k % _debris.length],
        _alongZ,
        pal,
        scale: 0.16 + 0.04 * (k % 3),
        ox: x,
        oy: y,
        oz: z,
        inset: 0,
        seamAlpha: 0,
        lit: 0.3,
        rimGlow: 0.8,
        dark: 0.7,
        fire: 1.6,
        gy: bob,
      );
    }
    meshBatch.flush(c);
  }

  debris(false);
  _rock.setZ(0.07 * sin(time * 0.37 + seed));
  _spinY.setY(time * 0.28 * spin + seed);
  _rot
    ..mul(_rock, _lean)
    ..mul(_rot, _spinY);
  meshBatch
    ..add(
      _spire,
      _rot,
      pal,
      oy: bob,
      inset: 0.03,
      seamAlpha: 0.45 + 0.55 * pulse,
      lit: 0.35,
      rimGlow: 0.8,
      dark: 0.75,
    )
    ..flush(c);
  debris(true);

  if (shield) {
    _spinY.setY(-time * 0.45 + seed);
    _rot
      ..mul(_rock, _lean)
      ..mul(_rot, _spinY);
    meshBatch
      ..add(
        _barrier,
        _rot,
        pal,
        tint: const Color(0xFF9FE8F4),
        oy: bob,
        seamAlpha: 0,
        heat: 0.3,
        alpha: 0.16,
      )
      ..edges(
        _barrier,
        _rot,
        const Color(0xFFB8F2FA),
        oy: bob,
        width: 0.035,
        alpha: 0.55,
      )
      ..flush(c);
  }
}

// ── the Hive ────────────────────────────────────────────────────────────────

/// Swarm motes: (radius, inclination, node, phase). They fly in flocks —
/// each flock one orbit, its motes strung out along it and a little either
/// side — so the swarm is streams of motes, not a cloud of noise.
final List<(double, double, double, double)> _swarm = () {
  final rng = Random(91);
  final out = <(double, double, double, double)>[];
  for (var f = 0; f < 6; f++) {
    final rho = 1.35 + rng.nextDouble() * 0.8;
    final incl = rng.nextDouble() * pi;
    final node = rng.nextDouble() * 2 * pi;
    final head = rng.nextDouble() * 2 * pi;
    for (var i = 0; i < 52; i++) {
      final along = pow(rng.nextDouble(), 1.6).toDouble();
      out.add((
        rho + (rng.nextDouble() - 0.5) * 0.18 * (1 + along),
        incl + (rng.nextDouble() - 0.5) * 0.14 * (1 + along),
        node + (rng.nextDouble() - 0.5) * 0.1,
        head - along * 2.2,
      ));
    }
  }
  return out;
}();

void _paintHive(
  Canvas c,
  EnemyPalette pal,
  double time,
  double seed,
  double spin,
  bool reduceGlows,
) {
  if (!reduceGlows) _circle(c, pal.glow, 2.6);
  // Each mote keeps its own orbit, but the orbits breathe and lean, so the
  // swarm folds and unfolds like a murmuration.
  _grainReset();
  for (final (rho, incl0, node, ph) in _swarm) {
    final r = rho * (1 + 0.13 * sin(time * 0.37 + ph * 3));
    final a = ph + time * 1.3 * spin / (rho * sqrt(rho));
    final incl = incl0 + 0.45 * sin(time * 0.23 + node * 2);
    final x0 = cos(a) * r, y0 = sin(a) * r;
    final y1 = y0 * cos(incl), z1 = y0 * sin(incl);
    final cn = cos(node), sn = sin(node);
    final lit = sin(time * 3 + ph * 7) > 0.55;
    _grainAdd(
      (z1 > 0 ? 2 : 0) + (lit ? 1 : 0),
      x0 * cn - y1 * sn,
      x0 * sn + y1 * cn,
    );
  }
  final dim = Color.lerp(pal.essence, pal.ink, 0.25)!;
  _grainDraw(c, 0, 0.05, dim.withValues(alpha: 0.55));
  _grainDraw(c, 1, 0.07, pal.essence.withValues(alpha: 0.8));
  c.save();
  c.scale(0.82);
  _circle(c, pal.orb, 1);
  c.restore();
  _sparkAt(c, pal, Offset.zero, 0.36 + 0.05 * sin(time * 2.6));
  _grainDraw(c, 2, 0.065, dim.withValues(alpha: 0.9));
  _grainDraw(c, 3, 0.09, pal.hot);
}

// ── the Armillary ───────────────────────────────────────────────────────────

const Color _brass = Color(0xFFC4A35A);
const int _kBandSegments = 40;

/// (radius, width, spin rate, fixed lean about z, fixed lean about x).
const List<(double, double, double, double, double)> _bands = [
  (1.08, 0.22, 0.55, 0.0, 0.3),
  (1.42, 0.2, -0.38, 0.9, 1.1),
  (1.76, 0.18, 0.27, -0.7, 2.0),
];

final Rot3 _bandA = Rot3(), _bandB = Rot3();
final List<(double, int, Float32List)> _bandQuads = [];

void _paintArmillary(
  Canvas c,
  EnemyPalette pal,
  double time,
  double seed,
  double spin,
  bool reduceGlows,
) {
  if (!reduceGlows) _circle(c, pal.glow, 2.6);
  _bandQuads.clear();
  _grainReset();
  for (var b = 0; b < _bands.length; b++) {
    final (rho, w, rate, leanZ, leanX) = _bands[b];
    // Each ring turns on its own axis, and that axis is itself leant.
    _bandA.setZ(leanZ);
    _bandB.setX(leanX + time * rate * spin + seed);
    _rot.mul(_bandA, _bandB);
    final m = _rot.m;
    for (var j = 0; j < _kBandSegments; j++) {
      final a0 = j * 2 * pi / _kBandSegments;
      final a1 = (j + 1) * 2 * pi / _kBandSegments;
      final am = (a0 + a1) / 2;
      final q = Float32List(8);
      var i = 0;
      for (final (a, h) in [(a0, -w), (a1, -w), (a1, w), (a0, w)]) {
        final x = cos(a) * rho, y = sin(a) * rho, z = h / 2;
        q[i++] = m[0] * x + m[1] * y + m[2] * z;
        q[i++] = m[3] * x + m[4] * y + m[5] * z;
      }
      // The band's surface faces out from its centre; seen from behind, its
      // inner face is what shows — and the inner face is lit by the sun.
      final nx0 = cos(am), ny0 = sin(am);
      var nx = m[0] * nx0 + m[1] * ny0;
      var ny = m[3] * nx0 + m[4] * ny0;
      var nz = m[6] * nx0 + m[7] * ny0;
      final px = nx * rho, py = ny * rho, pz = nz * rho;
      if (nz < 0) {
        nx = -nx;
        ny = -ny;
        nz = -nz;
      }
      final cz = pz;
      final color = shadeFacet(
        pal,
        nx,
        ny,
        nz,
        tint: _brass,
        lit: 0.7,
        fire: 1.5,
        px: px,
        py: py,
        pz: pz,
      );
      _bandQuads.add((cz, color, q));
      // Runes of light set into the band.
      if (j % 4 == b % 4) {
        final rx = (m[0] * cos(am) + m[1] * sin(am)) * rho;
        final ry = (m[3] * cos(am) + m[4] * sin(am)) * rho;
        _grainAdd(cz > 0 ? 1 : 0, rx, ry);
      }
    }
  }
  _bandQuads.sort((a, b) => a.$1.compareTo(b.$1));

  void bands(bool near) {
    for (final (z, color, q) in _bandQuads) {
      if ((z > 0) != near) continue;
      meshBatch.quad(q[0], q[1], q[2], q[3], q[4], q[5], q[6], q[7], color);
    }
    meshBatch.flush(c);
  }

  bands(false);
  _grainDraw(c, 0, 0.08, pal.essence.withValues(alpha: 0.7));
  // The sun at the centre.
  c.save();
  c.scale(0.5);
  _circle(c, pal.inner, 1);
  c.restore();
  _sparkAt(c, pal, Offset.zero, 0.85 + 0.08 * sin(time * 1.7));
  bands(true);
  _grainDraw(c, 1, 0.11, pal.hot);
}
