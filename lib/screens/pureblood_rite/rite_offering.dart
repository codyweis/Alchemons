// lib/screens/pureblood_rite/rite_offering.dart
//
// THE OFFERING: what the rite does with what it is given. The specimen
// stands over the pool in its own grains; from its feet up they loosen and
// fall into the blood, darkening as they go, and the pool takes them —
// brightening, then settling — while souls rise off it thicker than before.
// Then the gold, and the rite's words, set down whole.
//
// It replaced a shaking screen, cracks, and glowing rectangles (each with a
// blurred shadow) that flew up off a fading sprite.

import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/mystic_altar/altar_chrome.dart';
import 'package:alchemons/screens/mystic_altar/altar_grains.dart';
import 'package:alchemons/screens/pureblood_rite/rite_pool.dart';
import 'package:alchemons/screens/pureblood_rite/rite_stage.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Plays [species] ([instance]) being given to the pool, then [gold] and
/// [lines]. [grains] is the specimen read into grains (see
/// [AltarGrains.creature]); without them the sprite simply fades into the
/// pool.
Future<void> showRiteOffering(
  BuildContext context, {
  required Creature species,
  required CreatureInstance instance,
  required Future<SpecimenGrains?> grains,
  required int gold,
  required List<String> lines,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (_, _, _) => _RiteOffering(
        species: species,
        instance: instance,
        grains: grains,
        gold: gold,
        lines: lines,
      ),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      ),
    ),
  );
}

class _RiteOffering extends StatefulWidget {
  const _RiteOffering({
    required this.species,
    required this.instance,
    required this.grains,
    required this.gold,
    required this.lines,
  });

  final Creature species;
  final CreatureInstance instance;
  final Future<SpecimenGrains?> grains;
  final int gold;
  final List<String> lines;

  @override
  State<_RiteOffering> createState() => _RiteOfferingState();
}

/// When each part plays, in seconds.
const double _kRelease = 0.55; // the first grains (its feet) let go
const double _kReleaseSpan = 1.5; // its crown, last
const double _kFall = 0.8;
const double _kWords = 2.5;
const double _kCount = 2.8; // the gold counts up
const double _kCountSpan = 1.0;
const double _kContinue = 3.8;

class _RiteOfferingState extends State<_RiteOffering>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier(0);
  SpecimenGrains? _g;
  bool _read = false;

  /// The ticker's time when the offering began (once its grains were read).
  Duration? _from;
  bool _continueShown = false;

  @override
  void initState() {
    super.initState();
    widget.grains.then(
      (g) {
        if (!mounted) return;
        setState(() {
          _g = g;
          _read = true;
        });
      },
      onError: (_) {
        if (mounted) setState(() => _read = true);
      },
    );
    _ticker = createTicker((elapsed) {
      // It waits for its grains (a moment at most) before it starts.
      if (!_read) return;
      _from ??= elapsed;
      _t.value = (elapsed - _from!).inMicroseconds / 1e6;
      if (_t.value > _kContinue && !_continueShown) {
        setState(() => _continueShown = true);
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  static double _smooth(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: kRiteVoid,
      body: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          final pool = ritePoolFor(size, pad);
          final stageTop = pad.top + kRiteHeaderHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _OfferingPainter(
                      t: _t,
                      grains: _g,
                      read: _read,
                      centre: pool.centre,
                      radius: pool.radius,
                      top: stageTop,
                    ),
                  ),
                ),
              ),
              // No grains to give: the sprite itself sinks into the pool.
              if (_read && _g == null)
                ValueListenableBuilder<double>(
                  valueListenable: _t,
                  builder: (_, t, child) {
                    final gone = _smooth(_kRelease, _kRelease + 1.6, t);
                    final feet = riteStageLayout(size.width).feet + stageTop;
                    return Positioned(
                      left: (size.width - kRiteVesselSize) / 2,
                      top: feet - kRiteVesselSize + gone * 30,
                      width: kRiteVesselSize,
                      height: kRiteVesselSize,
                      child: Opacity(opacity: 1 - gone, child: child),
                    );
                  },
                  child: RiteVessel(
                    species: widget.species,
                    instance: widget.instance,
                    size: kRiteVesselSize,
                  ),
                ),
              Positioned(
                left: 28,
                right: 28,
                top: pool.centre.dy + pool.radius * RitePool.flat + 40,
                bottom: pad.bottom + 24,
                child: ValueListenableBuilder<double>(
                  valueListenable: _t,
                  builder: (context, t, _) => _words(context, t),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _words(BuildContext context, double t) {
    final shown = _smooth(_kWords, _kWords + 0.6, t);
    final counted = (widget.gold * _smooth(_kCount, _kCount + _kCountSpan, t))
        .round();
    return Opacity(
      opacity: shown,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GOLD RECEIVED',
            style: altarMono(10.5, AltarTone.gold.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 4),
          Text(
            '+$counted',
            style: altarName(
              context,
              44,
            ).copyWith(color: AltarTone.gold, letterSpacing: 1.5),
          ),
          const SizedBox(height: 18),
          for (final (i, line) in widget.lines.indexed)
            Opacity(
              opacity: _smooth(
                _kWords + 0.3 + i * 0.35,
                _kWords + 0.9 + i * 0.35,
                t,
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line, style: altarBody(context, size: 14)),
              ),
            ),
          const Spacer(),
          AnimatedOpacity(
            opacity: _continueShown ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            child: IgnorePointer(
              ignoring: !_continueShown,
              child: BracketButton(
                label: 'CONTINUE',
                palette: altarPalette,
                accent: RitePool.blood[3],
                height: 50,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferingPainter extends CustomPainter {
  _OfferingPainter({
    required this.t,
    required this.grains,
    required this.read,
    required this.centre,
    required this.radius,
    required this.top,
  }) : super(repaint: t);

  final ValueNotifier<double> t;
  final SpecimenGrains? grains;
  final bool read;
  final Offset centre;
  final double radius, top;

  static final GrainBatch _b = GrainBatch(40);

  static double _h(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  static double _smooth(double e0, double e1, double x) {
    final v = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return v * v * (3 - 2 * v);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final now = t.value;
    // The pool brightens as it takes the specimen, then settles.
    final lit = _smooth(0.8, 2.0, now) * (1 - _smooth(3.4, 5.0, now)) * 0.9;
    RitePool.paintGlow(canvas, centre, radius, lit: lit);
    RitePool.paintGrains(canvas, centre, radius, now + 40, lit: lit);
    final souls = 40 + 60 * _smooth(1.3, 2.8, now) * (1 - _smooth(5, 8, now));
    RitePool.paintSouls(
      canvas,
      centre,
      radius,
      top,
      now + 40,
      souls: souls.round(),
    );

    final g = grains;
    if (g == null || !read) return;
    final b = _b..clear();
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (var i = 0; i < g.length; i++) {
      minY = math.min(minY, g.hy[i]);
      maxY = math.max(maxY, g.hy[i]);
    }
    final span = math.max(1.0, maxY - minY);
    final feet = centre.dy - radius * RitePool.flat * 0.12;
    // The grains were read at the vessel's width: one to one, its middle
    // half a vessel above its feet.
    final mid = Offset(centre.dx, feet - kRiteVesselSize / 2);
    final tones = math.min(g.tones.length, 32);
    for (var i = 0; i < g.length; i++) {
      final yN = (g.hy[i] - minY) / span; // 0 crown .. 1 feet
      final release = _kRelease + (1 - yN) * _kReleaseSpan + _h(i, 3) * 0.25;
      final start = mid + Offset(g.hx[i], g.hy[i]);
      if (now < release) {
        // Loosening just before it goes.
        final loose = _smooth(release - 0.35, release, now);
        final p =
            start +
            Offset(
              math.sin(now * 9 + i) * 1.2 * loose,
              math.cos(now * 7 + i) * 1.2 * loose,
            );
        b.add(math.min(g.tone[i], tones - 1), p.dx, p.dy);
        continue;
      }
      final f = ((now - release) / _kFall).clamp(0.0, 1.0);
      if (f >= 1) continue; // taken by the pool
      // Down into the pool, quickening, drifting a little as it goes, to a
      // place among the pool's own grains.
      final target = RitePool.grainAt(
        (i * 7) % RitePool.count,
        centre,
        radius * 0.8,
        now + 40,
      );
      final e = f * f;
      final p =
          Offset.lerp(start, target, e)! +
          Offset(math.sin(f * 3 + i) * 6 * (1 - f), 0);
      // Darkening into blood as it falls.
      b.add(32 + (f < 0.35 ? 0 : (f < 0.7 ? 1 : 2)), p.dx, p.dy);
    }
    final d = math.max(1.1, g.step * 1.1);
    for (var k = 0; k < tones; k++) {
      b.draw(canvas, k, d, g.tones[k]);
    }
    b.draw(canvas, 32, d, RitePool.blood[4]);
    b.draw(canvas, 33, d, RitePool.blood[3]);
    b.draw(canvas, 34, d * 0.9, RitePool.blood[2]);
  }

  @override
  bool shouldRepaint(covariant _OfferingPainter old) =>
      old.grains != grains ||
      old.read != read ||
      old.centre != centre ||
      old.radius != radius ||
      old.top != top;
}
