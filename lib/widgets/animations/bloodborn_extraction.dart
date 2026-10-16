// lib/widgets/animations/bloodborn_extraction.dart
//
// THE BLOODBORN EXTRACTION: the Bloodborn Vial (see bloodborn_vial.dart)
// opened. It starts as every extraction does -- the family's shell braiding
// in the dark, here in blood, red sand banked at the edges -- and where any
// other shell would unravel, this one melts: it slumps and runs down into a
// pool. Three heartbeats go through the pool and the sand. Then the reborn
// rises out of the blood, its own grains coming up from its feet, blood
// running off it, and stands whole in a red light with embers rising before
// the result card. Grains and light only, as the finale is.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/providers/audio_provider.dart' show AudioController;
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/animations/hatch_sand.dart';
import 'package:alchemons/widgets/animations/hatch_shell.dart';
import 'package:alchemons/widgets/fx/bloodborn_vial.dart';
import 'package:alchemons/widgets/fx/cultivation_sphere.dart'
    show CultivationHandoff;
import 'package:alchemons/widgets/fx/fusion_particles.dart' show SpecimenGrains;
import 'package:alchemons/widgets/nursery/hatch_curtain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The ceremony's seconds: the shell braids (paced as every extraction's,
/// so the extraction cue lands on the melt), melts, beats three times, and
/// the reborn rises and stands.
const double _kMelt = 5.24, _kMeltSpan = 1.8;
const _kBeats = [7.3, 8.05, 8.8];
const double _kRise = 9.4, _kRiseSpan = 2.5;
const double _kReady = 11.6, _kReadySpan = 1.0;
const double _kDissolve = 13.3, _kEnd = 13.9;

/// The shell's arc, as every extraction runs it, held just short of its
/// unravel: this one never unravels.
const double _kShellPace = 6.16, _kShellHold = 0.845;

/// Its motion clock runs 6.6 s over those 6.16 s, as every extraction's
/// shell's does (see hatching_cinematic.dart).
const double _kShellClock = 6.6 / _kShellPace;

/// Blood in three palettes for the shell: the two sides it braids from and
/// what they fuse into.
const _kBloodA = [Color(0xFF240007), Color(0xFF5E0816), Color(0xFFC21A35)];
const _kBloodB = [Color(0xFF34040D), Color(0xFF7A0C20), Color(0xFFE0283F)];
const _kBloodR = [Color(0xFF3E0610), Color(0xFF8E1028), Color(0xFFFF4D5E)];

/// Plays the Bloodborn extraction over everything, for the vial's
/// [payload] (its species and genes are what rise).
Future<void> playBloodbornExtraction({
  required BuildContext context,
  required Map<String, dynamic> payload,
  String? mutationFamily,
  CinematicQuality quality = CinematicQuality.cinematic,
}) async {
  await Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (_, __, ___) => BloodbornExtractionView(
        payload: payload,
        mutationFamily: mutationFamily,
        quality: quality,
      ),
    ),
  );
}

class BloodbornExtractionView extends StatefulWidget {
  const BloodbornExtractionView({
    super.key,
    required this.payload,
    this.mutationFamily,
    this.quality = CinematicQuality.cinematic,
    this.onComplete,
    this.showSkip = true,
    this.body,
  });

  final Map<String, dynamic> payload;

  /// Its grains already read (a preview, a test); read from [payload]
  /// otherwise.
  final SpecimenGrains? body;
  final String? mutationFamily;
  final CinematicQuality quality;

  /// Called at the end instead of popping the route (a preview, a test).
  final VoidCallback? onComplete;
  final bool showSkip;

  @override
  State<BloodbornExtractionView> createState() =>
      _BloodbornExtractionViewState();
}

class _BloodbornExtractionViewState extends State<BloodbornExtractionView>
    with TickerProviderStateMixin {
  late final AnimationController _timeline;
  late final HatchShellModel _shell;
  BloodbornVialField? _field;
  HatchSandField? _sand;
  Ticker? _sandTicker;
  final _Frame _sandFrame = _Frame();
  Duration _sandLast = Duration.zero;
  AudioController? _audio;
  bool _done = false, _skipped = false;
  int _beatsFired = 0;

  late final _Melt _melt;

  bool get _reduced => widget.quality == CinematicQuality.performance;

  double get _seconds => _timeline.value * _kEnd;

  @override
  void initState() {
    super.initState();
    _timeline = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_kEnd * 1000).round()),
    )..addListener(_onTime);
    _shell = HatchShellModel(
      species: hatchShellSpeciesFor(widget.mutationFamily),
      reduced: _reduced,
    );
    _melt = _Melt(_reduced ? 640 : 1150);
    _sand = HatchSandField(
      paletteA: const [kBloodDeep, kBloodGrain, Color(0xFFFF4D5E)],
      paletteB: const [Color(0xFF4A0712), kBloodLight, Color(0xFFE0283F)],
      reduced: _reduced,
    );
    if (widget.onComplete == null) {
      // Nothing is carried in: the vial's chamber hands nothing on.
      CultivationHandoff.take();
      _lowerCurtainWhenVisible();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    CreatureCatalog? catalog;
    try {
      catalog = context.read<CreatureCatalog>();
    } catch (_) {}
    // Read before the clock starts, as every extraction reads its newborn.
    final body =
        widget.body ??
        await BloodbornVialGrains.forPayload(
          widget.payload,
          catalog,
          height: 300,
          maxGrains: _reduced ? 1000 : 1800,
        );
    if (!mounted) return;
    setState(
      () => _field = BloodbornVialField(body, pool: _reduced ? 420 : 720),
    );
    context.sound(SoundCue.extractionCeremony, owner: this);
    _timeline.forward(from: 0);
    _sandTicker = createTicker(_tickSand)..start();
  }

  void _lowerCurtainWhenVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.isCompleted) {
        HatchCurtain.lower(fade: false);
        return;
      }
      void onStatus(AnimationStatus status) {
        if (status != AnimationStatus.completed) return;
        animation.removeStatusListener(onStatus);
        HatchCurtain.lower(fade: false);
      }

      animation.addStatusListener(onStatus);
    });
  }

  void _tickSand(Duration elapsed) {
    final sand = _sand;
    if (sand == null) return;
    final dt = ((elapsed - _sandLast).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _sandLast = elapsed;
    sand.step(dt);
    _sandFrame.tick();
  }

  void _onTime() {
    final sec = _seconds;
    // Each beat goes through the sand and the hand.
    while (_beatsFired < _kBeats.length && sec >= _kBeats[_beatsFired]) {
      _beatsFired++;
      if (_skipped) continue;
      _sand?.burst();
      HapticFeedback.heavyImpact();
      context.sound(SoundCue.elementBlood);
    }
    if (_timeline.value >= 1 && !_done) {
      _done = true;
      if (_skipped) {
        _audio?.stopSoundOwner(this);
      } else {
        _audio?.releaseSoundOwner(this);
      }
      final done = widget.onComplete;
      if (done != null) {
        done();
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audio = context.audio;
  }

  @override
  void dispose() {
    _audio?.stopSoundOwner(this);
    _timeline.dispose();
    _sandTicker?.dispose();
    _sandFrame.dispose();
    _sand?.dispose();
    super.dispose();
  }

  /// The three beats, as one 0..1 swell each (lub, then dub).
  static double _beat(double sec) {
    var v = 0.0;
    for (final at in _kBeats) {
      double pulse(double d) {
        if (d < 0) return 0;
        return d < 0.05 ? bloodSmooth(0, 0.05, d) : math.exp(-(d - 0.05) * 6);
      }

      v = math.max(
        v,
        math.min(1.0, pulse(sec - at) + 0.6 * pulse(sec - at - 0.2)),
      );
    }
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final sand = _sand;
    final content = Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (sand != null)
          RepaintBoundary(
            child: IgnorePointer(
              child: CustomPaint(
                size: Size.infinite,
                isComplex: true,
                willChange: true,
                painter: HatchSandPainter(sand, repaint: _sandFrame),
              ),
            ),
          ),
        RepaintBoundary(
          child: IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _ExtractionPainter(this, repaint: _timeline),
            ),
          ),
        ),
        if (widget.showSkip)
          Positioned(
            bottom: 24,
            right: 24,
            child: GestureDetector(
              onTap: context.soundAction(() {
                _skipped = true;
                _timeline.animateTo(
                  1.0,
                  duration: const Duration(milliseconds: 150),
                );
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(color: const Color(0x2EFFFFFF)),
                ),
                child: const Text(
                  'SKIP',
                  style: TextStyle(
                    color: Color(0xFFE8EAED),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    final ground = sand == null
        ? content
        : HatchSandStir(field: sand, child: content);
    return Scaffold(backgroundColor: Colors.transparent, body: ground);
  }
}

/// The shell's grains as it melts: where each sat on the shell (a point in
/// a unit ellipse, most of them near its rim -- a shell is its surface),
/// when it lets go, and its share of red.
class _Melt {
  _Melt(this.n)
    : u = Float32List(n),
      v = Float32List(n),
      rel = Float32List(n),
      red = Float32List(n) {
    final rng = math.Random(17);
    for (var i = 0; i < n; i++) {
      final a = rng.nextDouble() * 2 * math.pi;
      final r = math.pow(rng.nextDouble(), 0.3).toDouble();
      u[i] = math.cos(a) * r;
      v[i] = math.sin(a) * r;
      // The top lets go last: everything below has to run first.
      rel[i] = 0.08 + 0.45 * rng.nextDouble() + 0.2 * (1 - (v[i] + 1) / 2);
      red[i] = rng.nextDouble();
    }
    batch = BloodGrainBatch(n * 3 + 4);
  }

  final int n;
  final Float32List u, v, rel, red;
  late final BloodGrainBatch batch;
}

class _ExtractionPainter extends CustomPainter {
  _ExtractionPainter(this.state, {super.repaint});
  final _BloodbornExtractionViewState state;

  static final Paint _bloodTint = Paint()
    ..colorFilter = const ColorFilter.mode(
      Color(0xFFFF3048),
      BlendMode.modulate,
    );

  @override
  void paint(Canvas canvas, Size size) {
    final field = state._field;
    if (field == null) return;
    final sec = state._seconds;
    final span = size.shortestSide;
    final cx = size.width / 2, cy = size.height * 0.47;
    final floor = cy + span * 0.3;
    final fade = 1 - bloodSmooth(_kDissolve, _kEnd, sec);
    final m = ((sec - _kMelt) / _kMeltSpan).clamp(0.0, 1.0);

    // The shell, braiding as every extraction's does; then slumping down
    // onto the floor as it melts, and gone into its grains.
    final shellOn = 1 - bloodSmooth(0.1, 0.8, m);
    if (shellOn > 0.01) {
      final sag = 1 - 0.7 * m * m;
      final shellT = math.min(sec / _kShellPace, _kShellHold);
      // Every shell's tubes are lit toward white at their cores; through
      // blood that light is red, and the dark edges stay dark.
      canvas
        ..saveLayer(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: span * 1.1,
            height: span * 1.3,
          ),
          _bloodTint,
        )
        ..translate(cx, floor)
        ..scale(1, sag)
        ..translate(-cx, -floor);
      HatchShellPainter(
        t: shellT,
        clock: sec * _kShellClock,
        model: state._shell,
        paletteA: _kBloodA,
        paletteB: _kBloodB,
        paletteResult: _kBloodR,
        behaviorA: ShellElementBehavior.of('T017'),
        behaviorB: ShellElementBehavior.of('T017'),
        behaviorResult: ShellElementBehavior.of('T017'),
        reduced: state._reduced,
        opacity: shellOn * fade,
      ).paint(canvas, size);
      canvas.restore();
    }

    // Its grains running down into the pool.
    if (m > 0 && m < 1 + 0.6 / _kMeltSpan) {
      _paintMelt(canvas, span, cx, cy, floor, sec, m);
    }

    // The pool it ran into, beating; and the reborn rising out of it.
    final poolOn = bloodSmooth(_kMelt + 0.3, _kMelt + 1.4, sec);
    if (poolOn <= 0.01) return;
    final grow = 0.35 + 0.65 * bloodSmooth(_kMelt + 0.2, _kMelt + 1.9, sec);
    final rising = sec >= _kRise;
    field.paintOpen(
      canvas,
      Offset(cx, floor),
      span * 0.58,
      progress: bloodSmooth(0, 1, (sec - _kRise) / _kRiseSpan),
      ready: bloodSmooth(_kReady, _kReady + _kReadySpan, sec),
      time: sec,
      poolWidth: span * 0.72 * grow,
      opacity: poolOn * fade,
      beat: rising ? null : _BloodbornExtractionViewState._beat(sec),
    );
  }

  void _paintMelt(
    Canvas canvas,
    double span,
    double cx,
    double cy,
    double floor,
    double sec,
    double m,
  ) {
    final melt = state._melt;
    final rx = span * 0.2, ry = span * 0.38;
    final sag = 1 - 0.7 * m * m;
    final gravity = span * 2.4;
    final half = span * 0.36;
    final b = melt.batch..begin(math.max(1.6, span * 0.0075));
    for (var i = 0; i < melt.n; i++) {
      final x0 = cx + melt.u[i] * rx;
      final y0 = floor + (cy + melt.v[i] * ry - floor) * sag;
      final appear = bloodSmooth(0, 0.25, m);
      final blood = Color.lerp(
        kBloodGrain,
        const Color(0xFFFF4D5E),
        melt.red[i] * 0.5,
      )!;
      final a = (sec - _kMelt) - melt.rel[i] * _kMeltSpan;
      if (a <= 0) {
        // Still on the shell, creeping down with it.
        b.put(Offset(x0, y0 + span * 0.02 * m), blood, appear * 0.9);
        continue;
      }
      final y = y0 + 0.5 * gravity * a * a;
      final px = cx + (x0 - cx).clamp(-half, half) * 0.85;
      if (y >= floor) {
        // In the pool: thinning into it.
        final landed = a - math.sqrt(2 * math.max(1.0, floor - y0) / gravity);
        final alpha = 1 - bloodSmooth(0, 0.3, landed);
        b.put(Offset(px, floor), kBloodDeep, alpha * 0.8);
        continue;
      }
      final e = ((y - y0) / math.max(1.0, floor - y0)).clamp(0.0, 1.0);
      final x = x0 + (px - x0) * bloodSmooth(0, 1, e);
      final v = gravity * a;
      final c = Color.lerp(blood, const Color(0xFFFF4D5E), 0.25)!;
      for (var k = 0; k < 3; k++) {
        b.put(Offset(x, y - k * v * 0.012), c, 0.9 - 0.28 * k);
      }
    }
    b.flush(canvas);
  }

  @override
  bool shouldRepaint(_ExtractionPainter old) => old.state != state;
}

class _Frame extends ChangeNotifier {
  void tick() => notifyListeners();
}
