// lib/screens/mystic_altar/altar_rite_field.dart
//
// ONE ALTAR: a Mystic waiting to be given a body.
//
//   The Mystic stands in the middle as grains of itself, most of them ash —
//   a pattern no one holds yet. Round it, a circle of seats, one for each of
//   its element's kinds. Each offering given flies into it as grains, and
//   its share of the Mystic fills in with colour: by the last, the whole
//   creature is there, only made of grains.
//
//   The rite (summon, in seconds) pours every offering and the relic into
//   the middle, crushes them into a knot, and the knot bursts. Out of the
//   burst the Mystic comes as its element — a flame, a wave, a heap — and
//   gathers into itself (EssenceField's reveal): it is awake. Sealed, it
//   folds into a cultivation and drops away.
//
// Plain Dart, time-driven, every grain a point in a batch and every light a
// gradient: no blur, nothing per grain but arithmetic.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/mystic_altar/altar_grains.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// One seat of the circle: a kind the rite asks for.
class RiteOffering {
  RiteOffering(this.species);

  final Creature species;

  /// The kind, read small.
  SpecimenGrains? grains;

  /// Given to the altar.
  bool given = false;

  /// How many unlocked specimens of it the player holds.
  int available = 0;

  /// 0..1 while one is being given: it flies in, and its share of the
  /// Mystic lights.
  double giving = 1;
}

class AltarRiteField {
  AltarRiteField({required this.element, required this.offerings})
    : ramp = altarRamp(element),
      accent = altarAccent(element),
      essence = EssenceElement.of(element) {
    _seedCircle();
    _seedKnot();
  }

  final String element;
  final List<Color> ramp;
  final Color accent;
  final EssenceElement essence;
  final List<RiteOffering> offerings;

  /// The Mystic, read at [mysticWidth] px across.
  SpecimenGrains? get mystic => _mystic;
  SpecimenGrains? _mystic;
  EssenceField? _essence;
  Float32List? _share;
  set mystic(SpecimenGrains? g) {
    _mystic = g;
    _essence = null;
    _share = null;
    if (g == null) return;
    final n = offerings.length;
    // Which offering each grain belongs to: dealt evenly, scattered through
    // the body, so each offering fills in a little of everywhere.
    _share = Float32List.fromList([
      for (var j = 0; j < g.length; j++)
        ((j * 0.6180339887 + 0.13) % 1.0 * math.max(1, n)).floorToDouble(),
    ]);
    _essence = EssenceField(g, essence)..reveal = true;
  }

  static const double mysticWidth = 240;

  /// The relic on this altar, small.
  SpecimenGrains? relic;

  /// Whether the relic is on the altar (or in hand, for the heart's rite).
  bool relicSet = true;

  double time = 0;

  /// 0..1 while the rite is held: the circle spins up, the Mystic stirs.
  double charge = 0;

  /// Seconds into the rite, or below 0 while it is not being performed.
  double summon = -1;

  /// 0..1 as the awakened Mystic is sealed into its cultivation.
  double seal = 0;

  // ── the rite's beats, in seconds ──────────────────────────────────────────

  static const double pourEnd = 1.7;
  static const double knotEnd = 2.7;
  static const double formStart = 2.8;

  /// The element's form is held longer here than on a details screen: this
  /// is the moment the whole altar was for.
  static const double _formRate = 0.7;

  /// When the Mystic stands whole, and its sprite takes over.
  static double get formEnd =>
      formStart +
      (EssenceField.duration - EssenceField.revealStart) / _formRate;

  /// The essence's own time at rite time [s].
  static double essenceTime(double s) =>
      EssenceField.revealStart + (s - formStart) * _formRate;

  /// How opaque the Mystic's sprite is at rite time [s].
  static double spriteOpacity(double s) {
    if (s < formStart) return 0;
    final t = essenceTime(s);
    if (t >= EssenceField.duration) return 1;
    return EssenceField.spriteOpacity(t) * _smooth(2.0, 2.4, t);
  }

  // ── layout ────────────────────────────────────────────────────────────────

  Offset _c = Offset.zero;
  double _rx = 1, _ry = 1;
  Rect _stage = Rect.zero;

  void layout(Rect stage) {
    _stage = stage;
    _c = Offset(stage.center.dx, stage.top + stage.height * 0.48);
    _rx = math.min(stage.width * 0.4, stage.height * 0.4);
    // An upright oval, the shape of what stands in it.
    _ry = math.min(_rx * 1.14, stage.height * 0.4);
  }

  /// The middle of the Mystic.
  Offset get centre => _c;

  /// How the Mystic is scaled to fit inside the circle.
  double get mysticScale =>
      math.min(1.15, (_ry * 1.55) / mysticWidth).clamp(0.4, 1.15);

  /// The Mystic's box on screen, for its sprite.
  Rect get mysticRect => Rect.fromCenter(
    center: _c,
    width: mysticWidth * mysticScale,
    height: mysticWidth * mysticScale,
  );

  double _seatAngle(int i) {
    final n = math.max(1, offerings.length);
    // With an even count, half a step round, so no seat stands where the
    // relic hangs at the foot of the circle.
    final start = -math.pi / 2 + (n.isEven ? math.pi / n : 0);
    return start + i * math.pi * 2 / n;
  }

  Offset seatCentre(int i) {
    final a = _seatAngle(i);
    return _c + Offset(math.cos(a) * _rx, math.sin(a) * _ry);
  }

  /// The seat under [p], or null.
  int? seatAt(Offset p) {
    for (var i = 0; i < offerings.length; i++) {
      if ((p - seatCentre(i)).distance < 34) return i;
    }
    return null;
  }

  Offset get relicAt => _c + Offset(0, _ry * 1.02);

  // ── the circle's dust ─────────────────────────────────────────────────────

  static const int _circleCount = 760;
  late final Float32List _cr, _ca, _cph;

  void _seedCircle() {
    final rng = math.Random(29);
    _cr = Float32List(_circleCount);
    _ca = Float32List(_circleCount);
    _cph = Float32List(_circleCount);
    for (var i = 0; i < _circleCount; i++) {
      _cr[i] = 1 + (rng.nextDouble() + rng.nextDouble() - 1) * 0.11;
      _ca[i] = rng.nextDouble() * math.pi * 2;
      _cph[i] = rng.nextDouble();
    }
  }

  // ── the knot ──────────────────────────────────────────────────────────────

  static const int _knotCount = 1100;
  late final Float32List _klat, _klon, _kr, _kw, _kph, _kdx, _kdy, _kv;

  void _seedKnot() {
    final rng = math.Random(53);
    _klat = Float32List(_knotCount);
    _klon = Float32List(_knotCount);
    _kr = Float32List(_knotCount);
    _kw = Float32List(_knotCount);
    _kph = Float32List(_knotCount);
    _kdx = Float32List(_knotCount);
    _kdy = Float32List(_knotCount);
    _kv = Float32List(_knotCount);
    // The burst is lopsided: three lobes of uneven reach, at uneven angles,
    // so it is a spray and never a ring.
    const lobes = [(0.3, 1.25), (2.35, 0.85), (4.2, 1.05)];
    for (var i = 0; i < _knotCount; i++) {
      _klat[i] = math.asin(rng.nextDouble() * 2 - 1);
      _klon[i] = rng.nextDouble() * math.pi * 2;
      _kr[i] = 0.55 + 0.45 * math.pow(rng.nextDouble(), 0.4).toDouble();
      _kw[i] = (i.isEven ? 1.0 : -1.0) * (0.8 + 0.6 * rng.nextDouble());
      _kph[i] = rng.nextDouble();
      final a = rng.nextDouble() * math.pi * 2;
      var reach = 0.6;
      for (final (at, k) in lobes) {
        final d = math.cos(a - at);
        if (d > 0) reach += k * math.pow(d, 6) * 0.9;
      }
      _kdx[i] = math.cos(a);
      _kdy[i] = math.sin(a);
      // Filled: every distance out to the lobe's reach, not one radius.
      _kv[i] = reach * math.sqrt(rng.nextDouble()) * (i % 5 == 0 ? 1.8 : 1);
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  static double _smooth(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static double _easeIn(double x) => x * x * x;

  static double _hash(int i, int salt) {
    var x = (i * 0x27d4eb2d) ^ (salt * 0x165667b1);
    x &= 0xffffffff;
    x = ((x ^ (x >> 15)) * 0x85ebca6b) & 0xffffffff;
    x ^= x >> 13;
    return (x & 0xffffff) / 0x1000000;
  }

  bool get _performing => summon >= 0;

  /// 0..1: the offerings and relic pouring into the middle.
  double get _pour => _performing ? _smooth(0.0, pourEnd, summon) : 0;

  /// 0..1: everything crushed into the knot.
  double get _crush => _performing ? _smooth(0.9, knotEnd, summon) : 0;

  /// Seconds since the knot burst, or below 0.
  double get _sinceBurst => _performing ? summon - knotEnd : -1;

  int get givenCount => offerings.where((o) => o.given).length;

  // ── painting ──────────────────────────────────────────────────────────────

  // Buckets: the Mystic's tones (14), its ghost (3), the hot (3), glints;
  // the circle's ash (3) and lit (2); offerings get their own batch.
  static const int _ghostB = 14, _hotB = 17, _glintB = 20;
  static const int _ashB = 21, _litB = 24, _moteB = 26;
  static const int _knotB = 27; // 6 heat steps
  final GrainBatch _b = GrainBatch(_knotB + 6);
  final GrainBatch _ob = GrainBatch(16);

  void paint(Canvas canvas, Size size, Rect stage) {
    layout(stage);
    _backdrop(canvas, size);
    _paintCircle(canvas);
    if (_sinceBurst < 0.05) {
      _paintRelic(canvas);
      for (var i = 0; i < offerings.length; i++) {
        _paintSeat(canvas, i);
      }
      _paintMystic(canvas);
    } else {
      // After the burst only the empty seats remain, dim.
      for (var i = 0; i < offerings.length; i++) {
        _paintSeat(canvas, i);
      }
    }
    _paintKnot(canvas, size);
    if (_performing && summon >= formStart) _paintForm(canvas);
    if (seal > 0) _paintSeal(canvas);
  }

  void _backdrop(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AltarTone.void0);
    final ready = givenCount / math.max(1, offerings.length);
    final burst = _sinceBurst;
    final flare = burst >= 0 ? math.exp(-burst * 2.2) : 0.0;
    final reach = size.longestSide * 0.7;
    canvas.drawCircle(
      _c,
      reach,
      Paint()
        ..shader = ui.Gradient.radial(
          _c,
          reach,
          [
            accent.withValues(
              alpha: (0.06 + 0.1 * ready + 0.1 * charge + 0.4 * flare).clamp(
                0.0,
                1.0,
              ),
            ),
            AltarTone.violetDeep.withValues(alpha: 0.08),
            const Color(0x00000000),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
    final b = _b..clear();
    for (var i = 0; i < 120; i++) {
      final s1 = (i * 0.6180339887) % 1.0;
      final s2 = (i * 0.7548776662 + 0.3) % 1.0;
      final y = (s2 - time * (0.008 + 0.012 * s1)) % 1.0;
      final x = (s1 + 0.02 * math.sin(time * 0.3 + i)) % 1.0;
      b.add(_moteB, x * size.width, y * size.height);
    }
    b.draw(canvas, _moteB, 1.3, const Color(0xFF8F86A8).withValues(alpha: 0.3));
    b.clear();

    // The rite darkens the room round the knot, and it lifts after.
    final dark = _performing
        ? _smooth(0.4, 1.8, summon) * (1 - 0.55 * _smooth(0.0, 1.2, burst))
        : 0.0;
    if (dark > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.55 * dark),
      );
    }
  }

  void _paintCircle(Canvas canvas) {
    final b = _b..clear();
    final n = math.max(1, offerings.length);
    final span = math.pi * 2 / n;
    final pour = _pour;
    final after = _sinceBurst >= 0;
    final spin = 0.06 + 0.5 * charge + 2.4 * pour * (after ? 0 : 1);
    for (var i = 0; i < _circleCount; i++) {
      final r0 = _cr[i];
      final a = _ca[i] + time * spin / r0;
      // The rite draws the circle in after its offerings; it comes back
      // after, burning, under the Mystic.
      var r = r0;
      if (_performing && !after) {
        // Each grain is drawn in on its own beat, so the circle pours into
        // the knot rather than shrinking round it as a hoop.
        final e = _smooth(0, 1, _crush * 1.5 - _cph[i] * 0.5);
        if (e > 0.97) continue;
        r *= 1 - _easeIn(e) * 0.97;
      }
      final x = _c.dx + math.cos(a) * _rx * r;
      final y = _c.dy + math.sin(a) * _ry * r;
      if ((time * 0.33 + _cph[i] * 9.7) % 1.0 < 0.004 + 0.02 * charge) {
        b.add(_glintB, x, y);
        continue;
      }
      // Lit where an offering has been given: its stretch of the circle.
      final rel = ((a - _seatAngle(0)) % (math.pi * 2)) / span;
      final k = rel.round() % n;
      final off = (rel - rel.roundToDouble()).abs() * 2;
      final o = offerings[k];
      final lit = after ? 1.0 : (o.given ? _smooth(0.6, 1.0, o.giving) : 0.0);
      if (lit > 0 && (1 - off) * lit > 0.25 + 0.4 * _cph[i] * (1 - charge)) {
        b.add(_litB + (off < 0.5 ? 1 : 0), x, y);
      } else {
        b.add(_ashB + (_cph[i] * 3).floor().clamp(0, 2), x, y);
      }
    }
    final fade = _performing && !after
        ? 1 - _smooth(knotEnd - 0.5, knotEnd, summon)
        : after
        ? _smooth(0.3, 1.4, _sinceBurst)
        : 1.0;
    final d = math.max(1.1, _rx * 0.009);
    for (var s = 0; s < 3; s++) {
      b.draw(
        canvas,
        _ashB + s,
        d,
        Color.lerp(
          const Color(0xFF2A2536),
          const Color(0xFF8A8098),
          s / 2,
        )!.withValues(alpha: (0.4 + 0.16 * s + 0.2 * charge) * fade),
      );
    }
    b.draw(canvas, _litB, d, ramp[1].withValues(alpha: fade));
    b.draw(canvas, _litB + 1, d * 1.1, ramp[2].withValues(alpha: fade));
    b.draw(canvas, _glintB, d * 1.5, ramp[3].withValues(alpha: fade));
    b.clear();
  }

  // ── the relic ─────────────────────────────────────────────────────────────

  void _paintRelic(Canvas canvas) {
    final g = relic;
    if (g == null || !relicSet) return;
    final b = _ob..clear();
    final pour = _smooth(0.25, 1.35, summon < 0 ? 0 : summon);
    final from = relicAt + Offset(0, math.sin(time * 1.2) * 3);
    final s = 1.0 - 0.5 * pour;
    for (var j = 0; j < g.length; j++) {
      var x = from.dx + g.hx[j] * s, y = from.dy + g.hy[j] * s;
      if (pour > 0) {
        // Up into the middle, each grain on its own bow.
        final e = _smooth(0.0, 1.0, (pour * 1.3 - _hash(j, 3) * 0.3));
        final bow = math.sin(math.pi * e) * (_hash(j, 5) - 0.5) * 70;
        x += (_c.dx - x) * e + bow;
        y += (_c.dy - y) * e;
        if (e >= 0.98) continue;
      }
      b.add(math.min(g.tone[j], 7), x, y);
    }
    final pc = relicAt + const Offset(0, 22);
    canvas.drawOval(
      Rect.fromCenter(center: pc, width: 84, height: 22),
      Paint()
        ..shader = ui.Gradient.radial(pc, 42, [
          accent.withValues(alpha: 0.22 * (1 - pour)),
          accent.withValues(alpha: 0),
        ]),
    );
    final d = math.max(0.95, g.step * s);
    for (var k = 0; k < math.min(8, g.tones.length); k++) {
      b.draw(canvas, k, d, g.tones[k]);
    }
  }

  // ── a seat ────────────────────────────────────────────────────────────────

  void _paintSeat(Canvas canvas, int i) {
    final o = offerings[i];
    final g = o.grains;
    final at = seatCentre(i);
    final b = _ob..clear();
    final after = _sinceBurst >= 0;

    // Its pool on the floor.
    final poolA =
        (o.given ? 0.2 : (o.available > 0 ? 0.06 : 0.025)) *
        (_performing && !after ? 1 - _pour : 1);
    final pr = 30.0;
    canvas.drawOval(
      Rect.fromCenter(
        center: at + const Offset(0, 22),
        width: pr * 2.4,
        height: pr * 0.7,
      ),
      Paint()
        ..shader = ui.Gradient.radial(at + const Offset(0, 22), pr * 1.2, [
          (o.given ? accent : AltarTone.ash).withValues(
            alpha: after ? poolA * 0.4 : poolA,
          ),
          const Color(0x00000000),
        ]),
    );
    if (g == null) return;

    // Giving: the specimen arrives at its seat in full colour, then pours
    // into the Mystic.
    final giving = o.given ? o.giving : 1.0;
    final arrive = o.given ? _smooth(0.0, 0.22, giving) : 0.0;
    final fly = o.given && giving < 1 ? _smooth(0.22, 0.78, giving) : 0.0;
    // The rite pours the given ones in again, all together.
    final pour = o.given && _performing
        ? _smooth(0.0 + i * 0.06, 1.1 + i * 0.06, summon)
        : 0.0;
    final ghost = !o.given || after;
    final n = g.length;
    final tones = math.min(12, g.tones.length);
    for (var j = 0; j < n; j++) {
      var x = at.dx + g.hx[j], y = at.dy + g.hy[j];
      final h = _hash(j, 11);
      if (ghost) {
        if (o.available == 0 && j % 2 == 1) continue;
        x += math.sin(time * 0.9 + j * 1.3) * 0.8;
        y += math.cos(time * 0.8 + j * 2.1) * 0.8;
        final k = (g.tone[j] * 3 ~/ math.max(1, g.tones.length)).clamp(0, 2);
        b.add(12 + k, x, y);
        continue;
      }
      final e = math.max(fly, pour);
      if (e > 0) {
        final tx = _c.dx + (h - 0.5) * 40,
            ty = _c.dy + (_hash(j, 13) - 0.5) * 60;
        final ee = _smooth(0, 1, e * 1.25 - h * 0.25);
        if (ee >= 0.995) continue;
        final dx = tx - x, dy = ty - y;
        final bow = math.sin(math.pi * ee) * (h - 0.5) * 0.5;
        x += dx * ee - dy * bow;
        y += dy * ee + dx * bow;
        b.add(15, x, y); // hot in flight
        continue;
      }
      b.add(math.min(g.tone[j], tones - 1), x, y);
    }
    final d = math.max(0.95, g.step * 1.02);
    final given = o.given && !after;
    // Given and resting: an echo of it, so the circle shows what it holds.
    final restA = given ? (giving >= 1 ? 0.72 : arrive) : 1.0;
    for (var k = 0; k < tones; k++) {
      b.draw(canvas, k, d, g.tones[k].withValues(alpha: restA));
    }
    final dim = o.available > 0 ? 1.0 : 0.55;
    for (var k = 0; k < 3; k++) {
      b.draw(
        canvas,
        12 + k,
        d,
        Color.lerp(
          const Color(0xFF2B2636),
          const Color(0xFF8A8098),
          k / 2,
        )!.withValues(alpha: (0.34 + 0.14 * k) * dim * (after ? 0.5 : 1)),
      );
    }
    b.draw(canvas, 15, d * 1.1, Color.lerp(ramp[2], ramp[3], 0.4)!);

    // Given: a slow drift of its grains toward the Mystic.
    if (given && giving >= 1 && !_performing) {
      b.clear();
      for (var q = 0; q < 6; q++) {
        final p = (time * 0.16 + q / 6 + i * 0.29) % 1.0;
        final fade = _smooth(0, 0.15, p) * (1 - _smooth(0.75, 1, p));
        if (fade < 0.3) continue;
        final w = math.sin(time * 1.3 + q * 2.2) * 6 * (1 - p);
        b.add(
          0,
          at.dx + (_c.dx - at.dx) * p * 0.8 + w,
          at.dy + (_c.dy - at.dy) * p * 0.8 - math.sin(math.pi * p) * 12,
        );
      }
      b.draw(canvas, 0, d * 1.2, ramp[2].withValues(alpha: 0.7));
    }
  }

  // ── the Mystic, waiting ───────────────────────────────────────────────────

  void _paintMystic(Canvas canvas) {
    final g = _mystic;
    final share = _share;
    if (g == null || share == null) return;
    final b = _b..clear();
    final s = mysticScale;
    final n = g.length;
    final tones = math.min(14, g.tones.length);
    final crush = _crush;
    final pour = _pour;
    final breath = math.sin(time * 0.8) * 2.2;
    for (var j = 0; j < n; j++) {
      final k = share[j].toInt();
      final o = k < offerings.length ? offerings[k] : null;
      // Lit once its offering has landed in it; flaring as it does.
      final lit = o != null && o.given && o.giving >= 0.72;
      final flare = o != null && o.given && o.giving < 1
          ? _smooth(0.72, 0.8, o.giving) * (1 - _smooth(0.8, 1.0, o.giving))
          : 0.0;
      var x = _c.dx + g.hx[j] * s;
      var y = _c.dy + g.hy[j] * s + breath;
      final h = _hash(j, 7);
      if (!lit) {
        final stir = 1.4 + 2.5 * charge;
        x += math.sin(time * (0.9 + charge * 4) + j * 1.7) * stir;
        y += math.cos(time * (0.7 + charge * 4) + j * 2.3) * stir;
      } else if (charge > 0) {
        x += math.sin(time * 9 + j * 1.7) * 0.9 * charge;
      }
      if (crush > 0) {
        // Into the knot, wound round as it goes.
        final e = _smooth(0, 1, crush * 1.2 - h * 0.2);
        final dx = x - _c.dx, dy = y - _c.dy;
        final a = e * (2.2 + 2 * h) * (j.isEven ? 1 : -1);
        final cs = math.cos(a), sn = math.sin(a);
        final keep = 1 - e * 0.94;
        x = _c.dx + (dx * cs - dy * sn) * keep;
        y = _c.dy + (dx * sn + dy * cs) * keep;
        if (e > 0.96) continue;
      }
      if (flare > 0.5 || (crush > 0.25 && h < crush)) {
        b.add(_hotB + (h * 3).floor().clamp(0, 2), x, y);
      } else if (lit) {
        if ((time * 0.45 + h * 17.3) % 1.0 < 0.0025) {
          b.add(_glintB, x, y);
        } else {
          b.add(math.min(g.tone[j], tones - 1), x, y);
        }
      } else {
        b.add(
          _ghostB + (g.tone[j] * 3 ~/ math.max(1, g.tones.length)).clamp(0, 2),
          x,
          y,
        );
      }
    }

    // Its light: as much as it has been given.
    final ready = givenCount / math.max(1, offerings.length);
    final glowR = mysticWidth * s * 0.8;
    canvas.drawCircle(
      _c,
      glowR,
      Paint()
        ..shader = ui.Gradient.radial(_c, glowR, [
          accent.withValues(
            alpha: 0.05 + 0.13 * ready + 0.12 * charge + 0.2 * pour,
          ),
          accent.withValues(alpha: 0),
        ]),
    );

    final d = math.max(0.9, g.step * s * 0.98);
    for (var k = 0; k < tones; k++) {
      b.draw(canvas, k, d, g.tones[k]);
    }
    for (var k = 0; k < 3; k++) {
      b.draw(
        canvas,
        _ghostB + k,
        d,
        Color.lerp(
          const Color(0xFF231E2E),
          Color.lerp(AltarTone.ash, ramp[1], 0.4)!,
          0.35 + 0.32 * k,
        )!.withValues(alpha: 0.3 + 0.13 * k + 0.15 * charge),
      );
    }
    for (var k = 0; k < 3; k++) {
      b.draw(canvas, _hotB + k, d * 1.05, ramp[1 + k]);
    }
    b.draw(canvas, _glintB, d * 1.3, ramp[3].withValues(alpha: 0.85));
  }

  // ── the knot, and its bursting ────────────────────────────────────────────

  void _paintKnot(Canvas canvas, Size size) {
    if (!_performing) return;
    final grow = _smooth(0.7, 1.5, summon);
    final burst = _sinceBurst;
    if (grow <= 0) return;
    if (burst > 1.6) return;
    final b = _b..clear();
    final squeeze = _smooth(1.2, knotEnd, summon);
    final radius =
        (66 - 44 * squeeze) * (1 + 0.06 * math.sin(summon * 26) * squeeze);
    final spin = summon * (2 + 9 * squeeze);
    const tip = 0.32;
    final ct = math.cos(tip), st = math.sin(tip);
    final heat = _smooth(1.0, knotEnd, summon);
    for (var i = 0; i < _knotCount; i++) {
      double x, y;
      int tone;
      if (burst < 0) {
        final lon = _klon[i] + spin * _kw[i];
        final lat = _klat[i];
        final cl = math.cos(lat);
        final px = cl * math.cos(lon),
            py = math.sin(lat),
            pz = cl * math.sin(lon);
        final yy = py * ct - pz * st, zz = py * st + pz * ct;
        final r = radius * _kr[i] * grow;
        x = _c.dx + px * r;
        y = _c.dy + yy * r;
        tone = ((zz + 1) * 1.6 + heat * 1.9).floor().clamp(0, 5);
      } else {
        // Out along the spray, slowing; embers run on and cool.
        final ember = i % 5 == 0;
        final travel = 1 - math.exp(-burst * (ember ? 2.2 : 4.6));
        final reach = _kv[i] * size.shortestSide * 0.62;
        x = _c.dx + _kdx[i] * (radius * 0.5 + reach * travel);
        y =
            _c.dy +
            _kdy[i] * (radius * 0.5 + reach * travel) +
            20 * burst * burst;
        final cool = burst / (ember ? 1.5 : 0.7);
        if (cool >= 1) continue;
        // White only for a breath, then the element's own shades.
        tone = (3.6 - cool * 4.2 + (burst < 0.08 ? 1.6 : 0)).floor().clamp(
          0,
          5,
        );
      }
      if (burst < 0 &&
          (summon * 3 + _kph[i] * 11) % 1.0 < 0.008 + 0.02 * heat) {
        b.add(_glintB, x, y);
      } else {
        b.add(_knotB + tone, x, y);
      }
    }
    // The knot's light, and the burst's flash: soft, never a hoop.
    final flash = burst >= 0 ? math.exp(-burst * 3.2) : 0.0;
    final lightR =
        radius * (2.4 + 1.2 * heat) + flash * size.shortestSide * 0.9;
    canvas.drawCircle(
      _c,
      lightR,
      Paint()
        ..shader = ui.Gradient.radial(
          _c,
          lightR,
          [
            Color.lerp(
              accent,
              const Color(0xFFFFF6E8),
              0.35 + 0.4 * flash,
            )!.withValues(
              alpha: (0.25 * grow + 0.3 * heat + 0.55 * flash).clamp(0.0, 0.95),
            ),
            accent.withValues(alpha: 0.12 * grow + 0.2 * flash),
            accent.withValues(alpha: 0),
          ],
          const [0.0, 0.35, 1.0],
        ),
    );
    final fade = burst < 0 ? grow : 1.0;
    final shades = [
      ramp[0],
      ramp[1],
      ramp[2],
      ramp[3],
      Color.lerp(ramp[3], const Color(0xFFFFFFFF), 0.5)!,
      const Color(0xFFFFFBF2),
    ];
    for (var k = 0; k < 6; k++) {
      b.draw(
        canvas,
        _knotB + k,
        1.7 + 0.25 * k,
        shades[k].withValues(alpha: fade),
      );
    }
    b.draw(
      canvas,
      _glintB,
      2.6,
      const Color(0xFFFFFFFF).withValues(alpha: fade),
    );
  }

  // ── the Mystic, coming as its element ─────────────────────────────────────

  void _paintForm(Canvas canvas) {
    final e = _essence;
    if (e == null) return;
    final t = essenceTime(summon);
    if (t >= EssenceField.duration) return;
    final s = mysticScale;
    canvas.save();
    canvas.translate(_c.dx, _c.dy);
    canvas.scale(s);
    e.paint(canvas, Offset.zero, t);
    canvas.restore();
  }

  // ── sealed into a cultivation ─────────────────────────────────────────────

  /// Where the sealed cultivation falls to.
  Offset sealTo = Offset.zero;

  void _paintSeal(Canvas canvas) {
    final g = _mystic;
    if (g == null) return;
    final b = _b..clear();
    final s = mysticScale;
    final fold = _smooth(0.0, 0.55, seal);
    final drop = _smooth(0.55, 1.0, seal);
    final sphereR = 46 * (1 - 0.7 * drop);
    final at = Offset.lerp(_c, sealTo, Curves.easeInCubic.transform(drop))!;
    final spin = time * 3 + seal * 8;
    const tip = 0.32;
    final ct = math.cos(tip), st = math.sin(tip);
    final tones = math.min(14, g.tones.length);
    for (var j = 0; j < g.length; j++) {
      final h = _hash(j, 17);
      final lat = math.asin(_hash(j, 19) * 2 - 1);
      final lon = h * math.pi * 2 + spin * (j.isEven ? 1 : -0.8);
      final cl = math.cos(lat);
      final px = cl * math.cos(lon),
          py = math.sin(lat),
          pz = cl * math.sin(lon);
      final yy = py * ct - pz * st;
      final rr = sphereR * (0.6 + 0.4 * math.sqrt(_hash(j, 23)));
      final sx = at.dx + px * rr, sy = at.dy + yy * rr;
      final hx = _c.dx + g.hx[j] * s, hy = _c.dy + g.hy[j] * s;
      final e = _smooth(0, 1, fold * 1.3 - h * 0.3);
      final x = hx + (sx - hx) * e, y = hy + (sy - hy) * e;
      if (pz * st + py * ct > 0.5 && (time * 2 + h * 9) % 1.0 < 0.02) {
        b.add(_glintB, x, y);
      } else {
        b.add(math.min(g.tone[j], tones - 1), x, y);
      }
    }
    final gl = sphereR * 2.4;
    canvas.drawCircle(
      at,
      gl,
      Paint()
        ..shader = ui.Gradient.radial(
          at,
          gl,
          [
            AltarTone.gold.withValues(alpha: 0.3 * fold * (1 - drop)),
            accent.withValues(alpha: 0.12 * fold),
            accent.withValues(alpha: 0),
          ],
          const [0.0, 0.4, 1.0],
        ),
    );
    final fade = 1 - _smooth(0.85, 1.0, seal);
    final d = math.max(0.9, g.step * s * (0.98 - 0.3 * drop));
    for (var k = 0; k < tones; k++) {
      b.draw(canvas, k, d, g.tones[k].withValues(alpha: fade));
    }
    b.draw(canvas, _glintB, d * 1.4, AltarTone.gold.withValues(alpha: fade));
  }

  /// The stage's bounds, for hosts.
  Rect get stage => _stage;
}
