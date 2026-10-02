// lib/screens/mystic_altar/altar_hub_field.dart
//
// THE ALTAR, seen whole: sixteen relic seats riding a tipped ring of dust
// around a well, and Blood's seat in the well itself — the heart, which
// wakes only once the sixteen have.
//
//   * A seat whose relic is not yet earned is a ghost of it, in ash.
//   * A relic in the satchel hovers over its seat, loose, wanting setting.
//   * A set relic rests, its pool lit, its offerings beading round it.
//   * An awakened seat burns: it lights its stretch of the ring in its
//     element and pours a stream of grains into the heart.
//
// So the whole altar fills with colour as the Mystics wake, and the heart
// turns from arcane violet to blood once every stream is running.
//
// Plain Dart and time-driven, like every grain field in the game: the screen
// steps [time] and paints. Points in batches, gradients for light, no blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/data/mystic_altar_data.dart';
import 'package:alchemons/screens/mystic_altar/altar_grains.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Where a seat's relic and Mystic stand.
enum SeatState {
  /// The relic is not earned yet.
  unearned,

  /// The relic is in the satchel, not on the altar.
  held,

  /// The relic is set; offerings are being given.
  placed,

  /// The Mystic has been summoned at least once.
  awakened,
}

/// One seat of the altar, as the field draws it.
class AltarSeat {
  AltarSeat(this.entry)
    : ramp = altarRamp(entry.element),
      accent = altarAccent(entry.element);

  final AltarEntry entry;
  final List<Color> ramp;
  final Color accent;

  SpecimenGrains? relic;

  /// The Mystic this seat calls, read from its sprite.
  SpecimenGrains? mystic;

  SeatState state = SeatState.unearned;
  int offerings = 0, required = 0;

  /// 0..1 while the relic is being held down onto the seat.
  double setting = 0;

  /// 0..1 after the relic lands: the seat takes it.
  double landing = 0;

  /// 0..1 as the Mystic wakes: the seat ignites and its stream begins. A
  /// seat that was already awake when the altar opened is simply 1.
  double waking = 1;

  /// Awake and done waking.
  bool get lit => state == SeatState.awakened && waking >= 1;

  /// How far it burns: 0 dark, 1 awake.
  double get wake => state == SeatState.awakened ? waking : 0;
}

class AltarHubField {
  AltarHubField(List<AltarSeat> ring, this.heart) : seats = ring {
    assert(seats.length == 16);
    _seedRing();
    _seedHeart();
  }

  /// The sixteen seats round the ring, in altar order.
  final List<AltarSeat> seats;

  /// Blood's seat: the well at the middle.
  final AltarSeat heart;

  double time = 0;

  /// The ring's turn, in radians; the seat at 0 stands at the front.
  double rotation = 0;

  /// The chosen seat (0..15), or -1 for the heart.
  int selected = 0;

  /// 0..1 while the arcane rift is found: the heart tears open.
  double arcane = 0;

  // ── layout ────────────────────────────────────────────────────────────────

  Offset _c = Offset.zero;
  double _r = 1;
  static const double _flat = 0.44;
  static const double _seatSpan = math.pi * 2 / 16;

  /// The ring's centre and radius for the [stage] it stands in.
  void layout(Rect stage) {
    _stage = stage;
    _c = Offset(stage.center.dx, stage.top + stage.height * 0.66);
    _r = math.min(stage.width * 0.42, stage.height * 0.52);
  }

  Rect _stage = Rect.zero;

  Offset get centre => _c;
  double get radius => _r;

  double seatAngle(int i) => rotation + i * _seatSpan;

  /// 0 at the back of the ring, 1 at the front.
  double seatDepth(int i) => (math.cos(seatAngle(i)) + 1) / 2;

  /// Where seat [i] stands on the floor.
  Offset seatFloor(int i) {
    final a = seatAngle(i);
    return _c + Offset(_r * math.sin(a), _r * _flat * math.cos(a));
  }

  double seatScale(int i) {
    final d = seatDepth(i);
    return (0.5 + 0.5 * d) * (i == selected ? 1.22 : 1.0);
  }

  /// Where seat [i]'s relic hangs.
  Offset seatRelic(int i) {
    final s = seatScale(i);
    return seatFloor(i) - Offset(0, 17 * s + _hover(seats[i], i) * s);
  }

  Offset get heartRelic => _c - Offset(0, _r * 0.13 + 22 + _hover(heart, 99));

  double _hover(AltarSeat s, int salt) {
    final rest = s.state == SeatState.held
        ? 9 + 3 * math.sin(time * 1.3 + salt)
        : 0.0;
    // Held down, it lowers; landing, it settles with a small give.
    return rest * (1 - s.setting) * (1 - s.landing);
  }

  /// The seat under [p], front seats first, or null.
  int? seatAt(Offset p) {
    int? best;
    var bestDepth = -1.0;
    for (var i = 0; i < 16; i++) {
      final s = seatScale(i);
      final at = seatRelic(i);
      final reach = 30 * s;
      if ((p - at).distanceSquared > reach * reach &&
          (p - seatFloor(i)).distanceSquared > reach * reach) {
        continue;
      }
      final d = seatDepth(i);
      if (d > bestDepth) {
        bestDepth = d;
        best = i;
      }
    }
    return best;
  }

  bool heartAt(Offset p) {
    final hr = _r * 0.3;
    return (p - _c).distance < hr || (p - heartRelic).distance < 34;
  }

  // ── the ring's dust ───────────────────────────────────────────────────────

  static const int _ringCount = 1500;
  late final Float32List _rr, _ra, _rph;

  void _seedRing() {
    final rng = math.Random(41);
    // (centre, half-width, weight) in ring radii: one bright lane through
    // the seats, a thin inner one and a fainter outer one.
    const lanes = [(1.0, 0.12, 1.0), (0.8, 0.035, 0.3), (1.18, 0.05, 0.28)];
    final total = lanes.fold(0.0, (s, l) => s + l.$3);
    _rr = Float32List(_ringCount);
    _ra = Float32List(_ringCount);
    _rph = Float32List(_ringCount);
    for (var i = 0; i < _ringCount; i++) {
      var pick = rng.nextDouble() * total;
      var r = 1.0;
      for (final (c, w, weight) in lanes) {
        pick -= weight;
        if (pick <= 0) {
          r = c + (rng.nextDouble() + rng.nextDouble() - 1) * w;
          break;
        }
      }
      _rr[i] = r;
      _ra[i] = rng.nextDouble() * math.pi * 2;
      _rph[i] = rng.nextDouble();
    }
  }

  // ── the heart's disk ──────────────────────────────────────────────────────

  static const int _heartCount = 760;
  late final Float32List _hr, _ha, _hph;

  void _seedHeart() {
    final rng = math.Random(17);
    _hr = Float32List(_heartCount);
    _ha = Float32List(_heartCount);
    _hph = Float32List(_heartCount);
    for (var i = 0; i < _heartCount; i++) {
      // Denser toward the core, as a disk feeding a well is.
      _hr[i] = 0.3 + 0.7 * math.pow(rng.nextDouble(), 0.8).toDouble();
      _ha[i] = rng.nextDouble() * math.pi * 2;
      _hph[i] = rng.nextDouble();
    }
  }

  int get awakenedCount => seats.where((s) => s.lit).length;

  /// The heart's state: 0 asleep, 1 witnessed by all sixteen, 2 awake.
  int get _heartMode => heart.lit ? 2 : (awakenedCount >= 16 ? 1 : 0);

  // ── painting ──────────────────────────────────────────────────────────────

  // Buckets. Ring: 4 ash steps and 2 lit steps per seat, far and near.
  static const int _ash = 4;
  static const int _ringHalf = _ash + 32;
  static const int _streamB = _ringHalf * 2; // 16, a seat each
  static const int _heartB = _streamB + 16; // 6 heat steps
  static const int _heartRingB = _heartB + 6; // 2
  static const int _moteB = _heartRingB + 2;
  static const int _glintB = _moteB + 1;
  final GrainBatch _b = GrainBatch(_glintB + 1);

  // A seat's own batch, drawn and cleared seat by seat (back to front), so
  // it never touches the ring's buckets: its tones (8), ash (2), embers,
  // and beads and glints.
  static const int _ashB = 8, _emberB = 10, _beadB = 11;
  final GrainBatch _sb = GrainBatch(12);

  static double _smooth(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// The heart's beat: two quick swells every 2.6 s (0..1).
  double get _beat {
    final p = (time / 2.6) % 1.0;
    double bump(double at) => math.exp(-math.pow((p - at) / 0.045, 2));
    return bump(0.1) + 0.6 * bump(0.24);
  }

  /// Paints the void over all of [size] and the altar in [stage].
  void paint(Canvas canvas, Size size, Rect stage) {
    layout(stage);
    final b = _b..clear();
    _backdrop(canvas, size);
    _paintApparition(canvas);
    _gatherRing(b);
    _gatherStreams(b);

    final dot = math.max(1.1, _r * 0.0085);
    _drawRing(canvas, b, far: true, dot: dot);

    // Seats behind the heart, the heart, then the ring's near half and the
    // seats in front of it.
    final order = List.generate(16, (i) => i)
      ..sort((a, c) => seatDepth(a).compareTo(seatDepth(c)));
    for (final i in order) {
      if (seatDepth(i) < 0.5) _paintSeat(canvas, i);
    }
    _paintHeart(canvas, dot);
    _drawRing(canvas, b, far: false, dot: dot);
    for (var k = 0; k < 16; k++) {
      b.draw(
        canvas,
        _streamB + k,
        dot * 1.15,
        Color.lerp(
          seats[k].ramp[2],
          seats[k].ramp[3],
          0.3,
        )!.withValues(alpha: 0.85),
      );
    }
    for (final i in order) {
      if (seatDepth(i) >= 0.5) _paintSeat(canvas, i);
    }
    b.draw(canvas, _glintB, dot * 2.6, const Color(0x30FFFFFF));
    b.draw(canvas, _glintB, dot * 1.4, const Color(0xFFFFFBEA));

    // The rift tearing open: a violet flash over everything.
    final flash = _smooth(0.8, 0.9, arcane) * (1 - _smooth(0.9, 1.0, arcane));
    if (flash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = const Color(0xFFD9C6FF).withValues(alpha: 0.75 * flash),
      );
    }
  }

  void _backdrop(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = AltarTone.void0);
    // The chosen element breathes faintly through the void.
    final chosen = selected < 0 ? heart : seats[selected];
    final tint = chosen.state == SeatState.unearned
        ? AltarTone.violetDeep
        : chosen.accent;
    final reach = size.longestSide * 0.75;
    canvas.drawCircle(
      _c,
      reach,
      Paint()
        ..shader = ui.Gradient.radial(
          _c,
          reach,
          [
            tint.withValues(alpha: 0.13),
            AltarTone.violetDeep.withValues(alpha: 0.1),
            const Color(0x00000000),
          ],
          const [0.0, 0.42, 1.0],
        ),
    );
    // Dust drifting up through the dark.
    final b = _b;
    for (var i = 0; i < 150; i++) {
      final s1 = (i * 0.6180339887) % 1.0;
      final s2 = (i * 0.7548776662 + 0.3) % 1.0;
      final y = (s2 - time * (0.006 + 0.01 * s1)) % 1.0;
      final x = (s1 + 0.02 * math.sin(time * 0.3 + i)) % 1.0;
      b.add(_moteB, x * size.width, y * size.height);
    }
    b.draw(
      canvas,
      _moteB,
      math.max(1.0, _r * 0.007),
      const Color(0xFF8F86A8).withValues(alpha: 0.32),
    );
    b.clear();
  }

  void _gatherRing(GrainBatch b) {
    final t = time;
    for (var i = 0; i < _ringCount; i++) {
      final r = _rr[i];
      // Kepler: the inner lanes turn faster than the outer, so clumps shear
      // into arcs. In the ring's own frame, so the dust turns with a drag.
      final local = _ra[i] + t * 0.16 / (r * math.sqrt(r));
      final a = local + rotation;
      final cs = math.cos(a);
      final x = _c.dx + _r * r * math.sin(a);
      final y = _c.dy + _r * _flat * r * cs;
      final half = cs >= 0 ? _ringHalf : 0;
      if ((t * 0.31 + _rph[i] * 9.1) % 1.0 < 0.005) {
        b.add(_glintB, x, y);
        continue;
      }
      // Which seat's stretch it is passing through, and how near.
      final rel = (local % (math.pi * 2)) / _seatSpan;
      final k = rel.round() % 16;
      final off = (rel - rel.roundToDouble()).abs() * 2; // 0 at the seat
      final seat = seats[k];
      final wake = seat.wake;
      final near = (1 - off) * (1 - ((r - 1).abs() * 3).clamp(0.0, 1.0));
      if (wake > 0 && near * wake > 0.12 + 0.5 * _rph[i] * (1 - wake)) {
        b.add(half + _ash + k * 2 + (near > 0.55 ? 1 : 0), x, y);
      } else {
        // Ash: a little brighter on the side toward you.
        final step = ((cs + 1) * 1.2 + _rph[i] * 1.4).floor().clamp(0, 3);
        b.add(half + step, x, y);
      }
    }
  }

  void _drawRing(
    Canvas canvas,
    GrainBatch b, {
    required bool far,
    required double dot,
  }) {
    final half = far ? 0 : _ringHalf;
    final dim = far ? 0.62 : 1.0;
    for (var s = 0; s < _ash; s++) {
      b.draw(
        canvas,
        half + s,
        dot,
        Color.lerp(
          const Color(0xFF2A2536),
          const Color(0xFF8A8098),
          s / (_ash - 1),
        )!.withValues(alpha: (0.46 + 0.17 * s) * dim),
      );
    }
    for (var k = 0; k < 16; k++) {
      final ramp = seats[k].ramp;
      b.draw(canvas, half + _ash + k * 2, dot, ramp[1].withValues(alpha: dim));
      b.draw(
        canvas,
        half + _ash + k * 2 + 1,
        dot * 1.1,
        ramp[2].withValues(alpha: dim),
      );
    }
  }

  void _gatherStreams(GrainBatch b) {
    for (var k = 0; k < 16; k++) {
      final seat = seats[k];
      if (seat.wake <= 0) continue;
      final local = k * _seatSpan;
      for (var j = 0; j < 9; j++) {
        // Each grain on its own pace and its own lane, so the stream is a
        // drift of material and never a dotted line.
        final h1 = ((k * 9 + j) * 0.6180339887) % 1.0;
        final h2 = ((k * 9 + j) * 0.7548776662) % 1.0;
        final p = (time * (0.08 + 0.07 * h1) + h2) % 1.0;
        // Waking: the stream runs out from the seat for the first time.
        if (!seat.lit && p > seat.wake * 1.4) continue;
        final fade = _smooth(0.0, 0.1, p) * (1 - _smooth(0.8, 1.0, p));
        if (fade < 0.3) continue;
        final rr = 1 - 0.84 * math.pow(p, 0.8) + (h1 - 0.5) * 0.1 * (1 - p);
        final a = local + rotation + p * (1.0 + 0.6 * h2) + (h2 - 0.5) * 0.12;
        b.add(
          _streamB + k,
          _c.dx + _r * rr * math.sin(a),
          _c.dy + _r * _flat * rr * math.cos(a) - 12 * (1 - p),
        );
      }
    }
  }

  // ── the heart ─────────────────────────────────────────────────────────────

  void _paintHeart(Canvas canvas, double dot) {
    final b = _b;
    final mode = _heartMode;
    final woke = awakenedCount / 16;
    final beat = mode >= 1 ? _beat : 0.0;
    final surge = arcane;
    final hr = _r * 0.34 * (1 + 0.05 * beat + 0.25 * surge);
    final chosen = selected < 0;

    // Its colours: arcane violet asleep, warming toward blood as the
    // sixteen wake, blood once they all have.
    final asleep = [
      const Color(0xFF1D1530),
      const Color(0xFF3B2A63),
      const Color(0xFF6A4FB0),
      const Color(0xFF9C82E0),
      const Color(0xFFCDBCFF),
      const Color(0xFFF4EEFF),
    ];
    final blood = [
      const Color(0xFF2A0508),
      const Color(0xFF6E0E16),
      const Color(0xFFB0202C),
      const Color(0xFFE2414B),
      const Color(0xFFFF9C9C),
      const Color(0xFFFFEDE0),
    ];
    final toBlood = mode >= 1 ? 1.0 : 0.0;
    final pal = [
      for (var k = 0; k < 6; k++) Color.lerp(asleep[k], blood[k], toBlood)!,
    ];
    final glow = mode == 2
        ? AltarTone.gold
        : Color.lerp(AltarTone.violet, AltarTone.blood, toBlood)!;

    // The light it gives off, behind it.
    final glowR = hr * (2.6 + 0.5 * beat + 1.4 * surge);
    canvas.drawCircle(
      _c,
      glowR,
      Paint()
        ..shader = ui.Gradient.radial(
          _c,
          glowR,
          [
            glow.withValues(
              alpha:
                  (0.1 + 0.18 * woke + 0.14 * beat + 0.5 * surge) *
                  (chosen ? 1.35 : 1),
            ),
            glow.withValues(alpha: 0.04 + 0.05 * woke),
            glow.withValues(alpha: 0),
          ],
          const [0.0, 0.4, 1.0],
        ),
    );

    // The disk, falling inward and turning faster as it falls.
    final spin = 1 + 0.8 * woke + 9 * surge * surge;
    for (var i = 0; i < _heartCount; i++) {
      final r = _hr[i];
      final a = _ha[i] + time * spin * 0.55 / (r * math.sqrt(r));
      final x = _c.dx + hr * r * math.cos(a);
      final y = _c.dy + hr * _flat * r * math.sin(a);
      final heat = ((1 - r) / 0.7).clamp(0.0, 1.0);
      final near = math.sin(a) > 0 ? 1 : 0;
      final lift = 0.6 * woke + 0.9 * beat + 2 * surge;
      final tone = (math.pow(heat, 1.2) * 5 + lift + near * 0.6)
          .clamp(0.0, 5.0)
          .floor();
      if ((time * 0.4 + _hph[i] * 7.7) % 1.0 < 0.004 + 0.02 * woke) {
        b.add(_glintB, x, y);
      } else {
        b.add(_heartB + tone, x, y);
      }
    }
    final hd = dot * (0.95 + 0.3 * surge);
    for (var k = 0; k < 6; k++) {
      b.draw(canvas, _heartB + k, hd, pal[k]);
    }

    // The well itself: black, soft at the edge, with bent light hugging it.
    final core = hr * (0.21 + 0.12 * surge);
    canvas.drawCircle(
      _c,
      core * 1.12,
      Paint()
        ..shader = ui.Gradient.radial(
          _c,
          core * 1.12,
          const [Color(0xFF010102), Color(0xFF010102), Color(0x00010102)],
          const [0.0, 0.84, 1.0],
        ),
    );
    for (var i = 0; i < 150; i++) {
      final seed = (i * 0.7548776) % 1.0;
      final a = seed * math.pi * 2 + time * (1.2 + seed) * spin;
      final d = core * (1.02 + 0.12 * ((i * 0.5698) % 1.0));
      final sa = math.sin(a);
      b.add(
        sa.abs() > 0.7 ? _heartRingB + 1 : _heartRingB,
        _c.dx + math.cos(a) * d,
        _c.dy + sa * d,
      );
    }
    b.draw(
      canvas,
      _heartRingB,
      dot * 0.75,
      pal[4].withValues(alpha: 0.45 + 0.3 * woke),
    );
    b.draw(canvas, _heartRingB + 1, dot * 0.85, pal[5]);

    // Blood's relic, over its well, once it has been earned.
    if (heart.state != SeatState.unearned || heart.landing > 0) {
      final at = heartRelic;
      _paintRelic(
        canvas,
        heart,
        at,
        at + Offset(0, 18 + _hover(heart, 99)),
        1.0,
        1.0,
        chosen,
        99,
      );
    }
  }

  // ── the apparition ────────────────────────────────────────────────────────
  //
  // The chosen seat's Mystic, standing beyond the ring as grains of itself:
  // a ghost in ash while its relic is unearned, filling in with colour as
  // its offerings are given, whole once it is awake. Turning to another seat
  // pours the grains from one Mystic into the next.

  AltarSeat? _shown, _from;
  double _morph = 1;
  Float32List? _rank;

  /// Seconds a turn from one Mystic to the next takes.
  static const double _morphSeconds = 0.75;

  /// Advances the pour between Mystics; the screen calls this each frame.
  void stepApparition(double dt) {
    final want = selected < 0 ? heart : seats[selected];
    if (!identical(want, _shown)) {
      if (want.mystic == null) return;
      // Mid-pour, the one half-formed is where the next pours from.
      _from = _morph < 0.5 ? _from : _shown;
      _shown = want;
      _morph = _from == null ? 1 : 0;
    }
    if (_morph < 1) _morph = math.min(1, _morph + dt / _morphSeconds);
  }

  /// How much of a seat's Mystic is filled in, 0..1.
  double _filled(AltarSeat s) => switch (s.state) {
    SeatState.unearned || SeatState.held => 0,
    SeatState.placed => s.required == 0 ? 0 : 0.85 * s.offerings / s.required,
    SeatState.awakened => 0.85 + 0.15 * s.waking,
  };

  // Its own batch: tones (12), ghost (3), glints.
  final GrainBatch _ab = GrainBatch(16);

  void _paintApparition(Canvas canvas) {
    final to = _shown;
    final g = to?.mystic;
    if (to == null || g == null) return;
    final from = _morph < 1 ? _from?.mystic : null;
    final b = _ab..clear();
    final n = g.length;
    // Grain dice, the same for every Mystic so a grain lit in one stays lit
    // as it pours into the next.
    final rank = _rank ??= Float32List.fromList([
      for (var i = 0; i < 4096; i++) (i * 0.6180339887 + 0.21) % 1.0,
    ]);
    final top = _stage.top + 6;
    final bottom = _c.dy - _r * _flat * 0.55;
    final room = math.max(40.0, bottom - top);
    // Read 220 across; fit the height it has.
    final scale = math.min(1.15, room / 230);
    final cx = _c.dx;
    final cy = top + room * 0.5 + math.sin(time * 0.7) * 3;
    final e = _morph < 1 ? Curves.easeInOutCubic.transform(_morph) : 1.0;
    final fill = _filled(to);
    final ghostOnly = to.state == SeatState.unearned;
    final tones = math.min(12, g.tones.length);
    final fn = from?.length ?? 0;
    for (var i = 0; i < n; i++) {
      var x = g.hx[i] * scale, y = g.hy[i] * scale;
      final h = rank[i % rank.length];
      if (from != null && fn > 0) {
        final j = (i * fn) ~/ n;
        final fx = from.hx[j] * scale, fy = from.hy[j] * scale;
        // Poured along a bow, each grain to its own side.
        final bow = math.sin(math.pi * e) * (h - 0.5) * 60 * scale;
        x = fx + (x - fx) * e + bow;
        y = fy + (y - fy) * e - math.sin(math.pi * e) * 24 * h * scale;
      }
      final lit = h < fill;
      if (!lit) {
        // Not yet held: it stirs where it would stand.
        x += math.sin(time * 0.9 + i * 1.7) * 1.6 * scale;
        y += math.cos(time * 0.7 + i * 2.3) * 1.6 * scale;
        final k = (g.tone[i] * 3 ~/ math.max(1, g.tones.length)).clamp(0, 2);
        if (ghostOnly && i % 3 == 0) continue;
        b.add(12 + k, cx + x, cy + y);
      } else if ((time * 0.4 + h * 13.1) % 1.0 < 0.002) {
        b.add(15, cx + x, cy + y);
      } else {
        b.add(math.min(g.tone[i], tones - 1), cx + x, cy + y);
      }
    }

    // A pool of the element's light under it, if anything of it is held.
    final glowA = 0.05 + 0.14 * fill;
    final pc = Offset(cx, cy + 40 * scale);
    final pr = 150 * scale;
    canvas.drawCircle(
      pc,
      pr,
      Paint()
        ..shader = ui.Gradient.radial(pc, pr, [
          (ghostOnly ? AltarTone.violetDeep : to.accent).withValues(
            alpha: glowA,
          ),
          const Color(0x00000000),
        ]),
    );

    final d = math.max(0.9, g.step * scale * 0.98);
    // Lit grains: its own colours, a little sunk toward the void so the
    // apparition never outshines the altar in front of it.
    for (var k = 0; k < tones; k++) {
      b.draw(
        canvas,
        k,
        d,
        Color.lerp(g.tones[k], AltarTone.void1, 0.18)!.withValues(alpha: 0.92),
      );
    }
    final ghostTint = ghostOnly ? AltarTone.ash : to.ramp[1];
    for (var k = 0; k < 3; k++) {
      b.draw(
        canvas,
        12 + k,
        d,
        Color.lerp(
          const Color(0xFF231E2E),
          ghostTint,
          0.35 + 0.3 * k,
        )!.withValues(alpha: ghostOnly ? 0.28 + 0.1 * k : 0.3 + 0.12 * k),
      );
    }
    b.draw(canvas, 15, d * 1.3, to.ramp[3].withValues(alpha: 0.8));
  }

  // ── a seat ────────────────────────────────────────────────────────────────

  void _paintSeat(Canvas canvas, int i) {
    final seat = seats[i];
    final s = seatScale(i);
    final depth = seatDepth(i);
    _paintRelic(
      canvas,
      seat,
      seatRelic(i),
      seatFloor(i),
      s,
      0.42 + 0.58 * depth,
      i == selected,
      i,
    );
  }

  void _paintRelic(
    Canvas canvas,
    AltarSeat seat,
    Offset at,
    Offset floor,
    double s,
    double fade,
    bool chosen,
    int salt,
  ) {
    final b = _sb;
    final g = seat.relic;
    final state = seat.state;
    final wake = seat.wake;
    final lit = wake > 0.5;
    final pulse = 0.5 + 0.5 * math.sin(time * 1.6 + salt * 0.9);

    // The pool it stands in.
    final poolA =
        switch (state) {
          SeatState.unearned => 0.05,
          SeatState.held => 0.1 + 0.18 * seat.setting,
          SeatState.placed => 0.2,
          SeatState.awakened => 0.2 + (0.16 + 0.08 * pulse) * wake,
        } +
        0.35 * seat.landing * (1 - seat.landing) * 4 +
        0.5 * (1 - seat.waking) * seat.waking * 4;
    final poolColor = state == SeatState.unearned ? AltarTone.ash : seat.accent;
    canvas.save();
    canvas.translate(floor.dx, floor.dy);
    canvas.scale(1, _flat * 1.1);
    final pr = 30 * s * (chosen ? 1.25 : 1);
    canvas.drawCircle(
      Offset.zero,
      pr,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          pr,
          [
            poolColor.withValues(alpha: (poolA * fade).clamp(0.0, 1.0)),
            poolColor.withValues(alpha: poolA * 0.3 * fade),
            poolColor.withValues(alpha: 0),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
    canvas.restore();

    if (g == null) return;
    b.clear();
    final n = g.length;
    final tones = math.min(g.tones.length, 8);
    // Held, the relic is loose — its grains drift a little off their
    // places — and tightens as it is pressed down.
    final loose = state == SeatState.held ? 1.4 * (1 - seat.setting) : 0.0;
    // Landing, the relic's grains are thrown out across the floor and
    // gather back: a filled spray, not a ring.
    final land = seat.landing;
    final spray = land > 0 && land < 1 ? math.sin(land * math.pi) : 0.0;
    final ghost = state == SeatState.unearned;
    // A far seat is small: half its grains, drawn a little larger, look the
    // same and cost half.
    final stride = s < 0.74 ? 2 : 1;
    for (var j = 0; j < n; j += stride) {
      var x = g.hx[j] * s, y = g.hy[j] * s;
      final ph = (j * 0.6180339887) % 1.0;
      if (loose > 0) {
        x += math.sin(time * 1.7 + j * 2.3) * loose * s;
        y += math.cos(time * 1.3 + j * 1.1) * loose * s;
      }
      if (spray > 0) {
        final a = ph * math.pi * 2 * 7.3;
        final d = spray * (6 + 18 * ((j * 0.7548776662) % 1.0)) * s;
        x += math.cos(a) * d;
        y += math.sin(a) * d * 0.6;
      }
      final px = at.dx + x, py = at.dy + y;
      if (ghost) {
        // A ghost of it in ash: every other grain, by brightness.
        if (stride == 1 && j.isOdd) continue;
        final k = (g.tone[j] * 2 ~/ math.max(1, g.tones.length)).clamp(0, 1);
        b.add(_ashB + k, px, py);
        continue;
      }
      if (lit && (time * 0.5 + ph * 11.3) % 1.0 < 0.012) {
        b.add(_beadB, px, py);
        continue;
      }
      b.add(math.min(g.tone[j], tones - 1), px, py);
    }

    // Offerings given, as beads on a small orbit round a set relic.
    if (state == SeatState.placed && seat.required > 0) {
      final m = seat.required;
      for (var q = 0; q < m; q++) {
        final a = time * 0.5 + q * math.pi * 2 / m + salt;
        final ox = math.cos(a) * 21 * s;
        final oy = math.sin(a) * 21 * s * 0.38 + 6 * s;
        b.add(q < seat.offerings ? _beadB : _ashB, at.dx + ox, at.dy + oy);
      }
    }

    // Awake, it sheds embers of its element upward.
    if (wake > 0) {
      for (var q = 0; q < 7; q++) {
        final p = (time * 0.35 + q / 7 + salt * 0.13) % 1.0;
        if (p > wake * 1.2) continue;
        final ex = math.sin(time * 1.4 + q * 2.1) * 8 * s * (0.4 + p);
        final ey = -p * 40 * s - 8 * s;
        b.add(_emberB, at.dx + ex, at.dy + ey);
      }
    }

    final d = math.max(0.95, g.step * s * (stride == 2 ? 1.3 : 1.02));
    final glow = (0.12 + 0.08 * pulse) * wake;
    if (glow > 0) {
      // A soft body of light behind the relic: its grains, large and faint.
      for (var k = 0; k < tones; k++) {
        b.draw(
          canvas,
          k,
          d * 3.2,
          seat.accent.withValues(alpha: glow * 0.35 * fade),
        );
      }
    }
    final bright = lit ? 1.0 : (state == SeatState.placed ? 0.92 : 0.82);
    for (var k = 0; k < tones; k++) {
      final c = g.tones[k];
      final lifted = Color.lerp(c, seat.ramp[3], 0.12 * wake)!;
      b.draw(
        canvas,
        k,
        d,
        lifted.withValues(alpha: (bright * fade).clamp(0.0, 1.0)),
      );
    }
    for (var k = 0; k < 2; k++) {
      b.draw(
        canvas,
        _ashB + k,
        d,
        Color.lerp(
          const Color(0xFF3A3446),
          const Color(0xFF8C8399),
          k.toDouble(),
        )!.withValues(alpha: (0.34 + 0.12 * k) * fade),
      );
    }
    b.draw(
      canvas,
      _emberB,
      d * 1.3,
      seat.ramp[3].withValues(alpha: 0.9 * fade),
    );
    // Bead or glint: bright, a little larger.
    b.draw(canvas, _beadB, d * 1.5, seat.ramp[3].withValues(alpha: fade));
    b.clear();
  }
}
