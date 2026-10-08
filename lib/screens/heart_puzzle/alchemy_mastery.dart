// lib/screens/heart_puzzle/alchemy_mastery.dart
//
// ALCHEMY MASTERED (the author, 2026-10-08: "after getting every star, the
// orb should come down, animate and explode and grant 500 gold that they
// can collect"). Played once, over the level picker, the first time it is
// shown with every star won:
//
//   · 0.0 – 1.3  the orb leaves its place in the header and comes down to
//                the middle of the screen, growing, as the page dims;
//   · 1.3 – 2.9  it gathers itself — turns faster and faster, swells, its
//                light rising;
//   · 2.9 –      it comes apart: every grain thrown out on its own curling
//                way, slowing, turning gold as it goes (a wave of light
//                spreads under them — no flash);
//   · 3.9 – 5.1  the gold draws back in and settles into 500, with GOLD
//                under it, and COLLECT comes up;
//   · collect:   the 500 is paid, its grains lift away to the corner, the
//                page comes back up, and the orb is in its place again.
//
// Points in batches and radial gradients; no blur.

import 'dart:math' as math;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/games/planet_dungeon/blood_heart_fx.dart';
import 'package:alchemons/games/planet_dungeon/blood_rite_fx.dart';
import 'package:alchemons/widgets/alchemy_emblem.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// The beats, in seconds (see the top of the file).
const double descend = 1.3, charge = 2.9, gatherAt = 3.9;
const double settled = 5.15, away = 1.1;

const Color _kGold = Color(0xFFE4C16A);
const Color _kGoldHot = Color(0xFFF7E6A8);
const Color _kGoldDeep = Color(0xFF9A6B12);

double _h(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

double _c01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);
double _smooth(double e0, double e1, double x) {
  final t = _c01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
}

double _out3(double x) {
  final t = _c01(x);
  return 1 - (1 - t) * (1 - t) * (1 - t);
}

class AlchemyMastery extends StatefulWidget {
  const AlchemyMastery({
    super.key,
    required this.from,
    required this.headerRadius,
    this.clockAt = 0,
    required this.onCollect,
    required this.onDone,
  });

  /// Where the orb floats in the header (screen), and how big.
  final Offset from;
  final double headerRadius;

  /// The shared clock when it starts, so the orb it takes over is at the
  /// same turn as the header's.
  final double clockAt;

  /// Pays the 500 (called once, on COLLECT).
  final Future<void> Function() onCollect;

  /// The page is back and the orb in its place.
  final VoidCallback onDone;

  static const int gold = 500;

  @override
  State<AlchemyMastery> createState() => AlchemyMasteryState();
}

class AlchemyMasteryState extends State<AlchemyMastery>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier(0);
  Duration _last = Duration.zero;
  final RiteGrainBatch _batch = RiteGrainBatch();

  HeartWord? _word;
  List<(Offset, Color, double)>? _burst;
  double? _collectedAt;
  final Set<String> _cued = {};

  @visibleForTesting
  double get debugT => _t.value;
  @visibleForTesting
  bool get debugCollectable => _t.value >= settled && _collectedAt == null;

  @override
  void initState() {
    super.initState();
    heartWordOf('${AlchemyMastery.gold}', size: 58).then((w) {
      if (mounted) _word = w;
    });
    _ticker = createTicker((now) {
      final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, .05);
      _last = now;
      _t.value += dt;
      _cues();
      final c = _collectedAt;
      if (c != null && _t.value >= c + away + .55) {
        _ticker.stop();
        widget.onDone();
      }
    })..start();
  }

  void _cue(String key, double at, void Function() play) {
    if (_t.value >= at && _cued.add(key)) play();
  }

  void _cues() {
    _cue('charge', descend, () => context.sound(SoundCue.fusionCalibrate));
    _cue('burst', charge, () {
      HapticFeedback.mediumImpact();
      context.sound(SoundCue.fusionEruption);
    });
    _cue('gold', gatherAt + .9, () => context.sound(SoundCue.currencyGain));
    if (_t.value >= settled - .3 && _cued.add('button')) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  Future<void> _collect() async {
    if (_collectedAt != null) return;
    HapticFeedback.heavyImpact();
    setState(() => _collectedAt = _t.value);
    context.sound(SoundCue.rewardCollect);
    await widget.onCollect();
    if (mounted) context.sound(SoundCue.rewardFlight);
  }

  @override
  Widget build(BuildContext context) {
    final showButton = _cued.contains('button') && _collectedAt == null;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: CustomPaint(
            painter: _MasteryPainter(this, MediaQuery.paddingOf(context).top),
          ),
        ),
        Align(
          alignment: const Alignment(0, .42),
          child: AnimatedOpacity(
            opacity: showButton ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            child: AnimatedSlide(
              offset: showButton ? Offset.zero : const Offset(0, .3),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              child: IgnorePointer(
                ignoring: !showButton,
                child: TextButton(
                  onPressed: _collect,
                  style: TextButton.styleFrom(
                    foregroundColor: _kGoldHot,
                    backgroundColor: _kGold.withValues(alpha: .16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 14,
                    ),
                  ),
                  child: const Text(
                    'COLLECT',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w700,
                      color: _kGoldHot,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MasteryPainter extends CustomPainter {
  _MasteryPainter(this.s, this.top) : super(repaint: s._t);
  final AlchemyMasteryState s;
  final double top;

  @override
  void paint(Canvas canvas, Size size) {
    final t = s._t.value;
    final batch = s._batch;
    final w = s.widget;
    final ca = s._collectedAt;
    final leaving = ca == null ? 0.0 : _smooth(0, away + .5, t - ca);
    // The page dims under it, and comes back up once it is paid.
    final dim =
        .8 *
        _smooth(0, .7, t) *
        (1 - _smooth(away * .6, away + .5, ca == null ? -1 : t - ca));
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: dim),
    );

    final mid = Offset(size.width / 2, size.height * .4);
    final down = _out3(t / descend);
    final centre = Offset.lerp(
      w.from,
      mid,
      Curves.easeInOutCubic.transform(_c01(t / descend)),
    )!;
    final ch = _smooth(descend, charge, t);
    final r =
        (w.headerRadius + (58 - w.headerRadius) * down) *
        (1 + .14 * ch * ch + .025 * ch * math.sin(t * 22));
    // Turning faster and faster as it gathers itself.
    final turn = w.clockAt + t + 3.2 * ch * ch * (t - descend).clamp(0.0, 9.0);

    if (t < charge) {
      paintAlchemyOrb(canvas, batch, centre, r, turn);
      // Its light rising.
      _glow(canvas, centre, r * (2.2 + 1.2 * ch), _kGold, .05 + .16 * ch);
      return;
    }

    // ── it comes apart ──
    final burst = s._burst ??= [
      for (final g in alchemyOrbGrainsAt(centre, r, turn)) ...[g, g],
    ];
    final tau = t - charge;
    // A wave of light under the grains, spreading and thinning.
    final wave = _smooth(0, 1.4, tau);
    if (wave < 1) {
      _glow(canvas, mid, 40 + wave * size.width * .7, _kGold, .22 * (1 - wave));
    }
    final word = s._word;
    final gather = _smooth(gatherAt - charge, settled - charge - .15, tau);
    final glowWord =
        _smooth(settled - charge - .6, settled - charge, tau) * (1 - leaving);
    if (glowWord > 0) _glow(canvas, mid, 120, _kGold, .14 * glowWord);
    for (var i = 0; i < burst.length; i++) {
      final (p0, col0, near) = burst[i];
      final h = _h(i, 3);
      // Out along its own curling way, slowing.
      var dir = p0 - mid;
      final len = dir.distance;
      dir = len < .01
          ? Offset(math.cos(h * 6.28), math.sin(h * 6.28))
          : dir / len;
      final turnK = (h - .5) * 1.4;
      dir = Offset(
        dir.dx * math.cos(turnK) - dir.dy * math.sin(turnK),
        dir.dx * math.sin(turnK) + dir.dy * math.cos(turnK),
      );
      final speed = 220 + 420 * _h(i, 4) * (i.isEven ? 1 : .6);
      const drag = 2.6;
      double flown(double x) => speed * (1 - math.exp(-drag * x)) / drag;
      final curl =
          Offset(math.sin(tau * 2 + h * 9), math.cos(tau * 1.7 + h * 7)) *
          10 *
          _c01(tau);
      var p = p0 + dir * flown(tau) + curl;
      // Into the gold.
      final gold = _smooth(.1, .8, tau);
      var col = Color.lerp(
        col0,
        h > .85 ? _kGoldHot : (h < .2 ? _kGoldDeep : _kGold),
        gold,
      )!;
      var a = (.55 + .45 * near) * (1 - .25 * _smooth(.6, 1.0, tau));
      // Back in, onto the 500.
      if (word != null && gather > 0) {
        final k = word.length;
        final j = (i * 7919) % k;
        final home =
            mid +
            Offset(word.x[j], word.y[j]) +
            Offset((_h(i, 6) - .5) * 1.6, (_h(i, 7) - .5) * 1.6);
        final stagger = _c01((gather - .25 * _h(i, 8)) / .75);
        final e = Curves.easeInOutCubic.transform(stagger);
        final bow = Offset(0, -26 * math.sin(math.pi * e) * (h - .5));
        p = Offset.lerp(p, home, e)! + bow;
        a = a + (1 - a) * e;
        col = Color.lerp(col, h > .8 ? _kGoldHot : _kGold, e)!;
      }
      // Paid: lifting away to the corner where the purse is.
      if (ca != null) {
        final u = _c01((t - ca - .35 * _h(i, 9)) / (away - .35));
        if (u > 0) {
          final e = u * u;
          final to = Offset(size.width - 34, top + 22);
          final mid2 = Offset.lerp(p, to, .5)! + Offset(-40 * (h - .3), -60);
          p = Offset(
            (1 - e) * (1 - e) * p.dx +
                2 * (1 - e) * e * mid2.dx +
                e * e * to.dx,
            (1 - e) * (1 - e) * p.dy +
                2 * (1 - e) * e * mid2.dy +
                e * e * to.dy,
          );
          a *= 1 - _smooth(.7, 1, u);
        }
      }
      final q = p + const Offset(0, 1.2);
      batch.add(
        q.dx,
        q.dy,
        p.dx,
        p.dy,
        col,
        alpha: a.clamp(0.0, 1.0),
        width: h > .85 ? 2.8 : 2.2,
      );
    }
    batch.paint(canvas);
    // GOLD, under it.
    final label =
        _smooth(settled - charge - .4, settled - charge + .2, tau) *
        (1 - leaving);
    if (label > .01 && word != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'GOLD',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            letterSpacing: 4,
            fontWeight: FontWeight.w700,
            color: _kGold.withValues(alpha: label),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, mid + Offset(-tp.width / 2, 44));
    }
  }

  void _glow(Canvas canvas, Offset c, double r, Color color, double a) {
    if (a <= .003) return;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: a.clamp(0.0, 1.0)),
            color.withValues(alpha: (a * .35).clamp(0.0, 1.0)),
            color.withValues(alpha: 0),
          ],
          stops: const [0, .45, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant _MasteryPainter old) => true;
}
