// lib/widgets/athanor_emblem.dart
//
// THE ATHANOR on home: the furnace in little, in the bottom-centre slot the
// daily chest had. Its mouth glows while the day's free pour is waiting and
// is banked low once it is taken; it reads the day again whenever the app
// comes back and at the UTC day's turn, so it is never stale after
// midnight.
//
// The way in (a PassageScene): home sinks into the furnace's dark while the
// furnace grows and rises to where it stands on the Athanor's screen
// ([AthanorLayout.rest]), the same painter at the same place, so the way in
// ends as the screen's first thing. The screen is built and first painted
// (unseen, under the grown furnace at rest) only once the furnace has
// arrived; then the hand-off is a cut between two identical furnaces — the
// screen opaque underneath, the passage's own furnace gone — and the
// screen's chrome comes up on its own. Cross-fading the two furnaces would
// dim the furnace by a quarter halfway through (both half-transparent), and
// building the screen mid-flight stalled the grow.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/navigation/emblem_passage.dart';
import 'package:alchemons/screens/athanor/athanor_furnace.dart';
import 'package:alchemons/screens/athanor/athanor_screen.dart';
import 'package:alchemons/screens/athanor/athanor_tone.dart';
import 'package:alchemons/services/athanor_service.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:alchemons/widgets/home_emblems.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Paints the emblem at [s]: the icon in its box, or the way in over the
/// screen.
void paintAthanorEmblem(
  Canvas canvas,
  EmblemStage s, {
  required bool ready,
  bool teach = false,
  bool back = true,
  bool front = true,
}) {
  final k = s.grow;
  // Until the Athanor is first opened it breathes on home: a warm light
  // swells under it and the furnace with it, so a new player finds it. It
  // has no label to say what it is. Opened, the breath eases out over the
  // start of the way in rather than stopping on the tap.
  final teachK = teach ? 1 - _smooth(0, 0.3, k) : 0.0;
  final pulse = teachK > 0
      ? (0.5 - 0.5 * math.cos(s.time * 2 * math.pi / _kTeachPeriod)) * teachK
      : 0.0;
  final home = AthanorFurnaceGeo.inBox(
    pulse > 0 ? _swell(s.box, 1 + 0.035 * pulse) : s.box,
  );
  final g = k <= 0
      ? home
      : AthanorFurnaceGeo.lerp(home, AthanorLayout(s.screen, s.pad).rest, k);
  if (back && s.ground > 0) {
    // The screen's own dark, coming up under the furnace.
    canvas.drawRect(
      Offset.zero & s.screen,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.screen.height), [
          AthanorTone.void1.withValues(alpha: s.ground),
          AthanorTone.void0.withValues(alpha: s.ground),
        ]),
    );
  }
  if (!front) return;
  // Once the screen is given way to, its own furnace stands exactly here;
  // this one steps out of the way rather than fading over it.
  if (s.land > 0) return;
  // On home it stands in a pool of its own dark, so a busy realm behind it
  // does not run into its grains; the passage's ground takes over as it
  // grows.
  final dark = 1 - k;
  if (dark > 0.01) {
    final c = Offset(g.base.dx, g.base.dy - g.s * 0.42);
    final r = g.s * 0.86;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r,
          [
            AthanorTone.void0.withValues(alpha: 0.82 * dark),
            AthanorTone.void0.withValues(alpha: 0.55 * dark),
            AthanorTone.void0.withValues(alpha: 0),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
  }
  if (pulse > 0.01) {
    final c = Offset(g.base.dx, g.base.dy - g.s * 0.3);
    final r = g.s * (0.85 + 0.2 * pulse);
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..scale(r);
    canvas.drawCircle(
      Offset.zero,
      1,
      _teachPool..color = Color.fromRGBO(255, 255, 255, 0.95 * pulse),
    );
    canvas.restore();
  }
  paintAthanorFurnace(
    canvas,
    g,
    s.time,
    AthanorBurn(
      // Banked until there is a free pour; while it teaches, the fire
      // breathes with it.
      fire: ready ? 1 : 0.3 + (0.25 + 0.45 * pulse) * teachK,
    ),
    // Its shadow side comes in as the passage's dark does.
    shadow: s.ground,
  );
}

double _smooth(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Seconds for one breath of the teaching pulse: slow, so it reads as the
/// furnace drawing air rather than a blinking button.
const double _kTeachPeriod = 2.6;

/// [box] grown by [k] about its bottom centre, where the furnace stands.
Rect _swell(Rect box, double k) => Rect.fromLTRB(
  box.bottomCenter.dx - box.width * k / 2,
  box.bottom - box.height * k,
  box.bottomCenter.dx + box.width * k / 2,
  box.bottom,
);

/// The teaching pulse's light, at unit size; strength rides the paint's
/// alpha, so nothing is built per frame.
final Paint _teachPool = Paint()
  ..shader = ui.Gradient.radial(
    Offset.zero,
    1,
    [
      AthanorTone.tinctureBright.withValues(alpha: 0.62),
      AthanorTone.tinctureBright.withValues(alpha: 0.3),
      AthanorTone.tinctureBright.withValues(alpha: 0.08),
      AthanorTone.tinctureBright.withValues(alpha: 0),
    ],
    const [0.0, 0.38, 0.72, 1.0],
  );

/// The way in through the emblem. [ready] is read as it plays, so coming
/// back after the free pour the furnace is banked as the screen left it.
class AthanorPassageScene extends PassageScene {
  const AthanorPassageScene({
    required this.ready,
    this.teach = false,
    this.listenable,
  });

  final bool Function() ready;

  /// The emblem was breathing to be found when it was tapped.
  final bool teach;

  @override
  final Listenable? listenable;

  @override
  Duration get inward => const Duration(milliseconds: 1050);
  @override
  Duration get outward => const Duration(milliseconds: 950);

  /// The hand-off is a cut; the landing only paces the screen's chrome
  /// coming up (it starts at half of it).
  @override
  Duration get landing => const Duration(milliseconds: 300);

  /// Built once the furnace has arrived and stands at rest, so the screen's
  /// first build and paint stall nothing that moves.
  @override
  double get buildAt => 1;

  /// Unseen but painted while the furnace covers it (a page at opacity 0 is
  /// never painted, which would leave its whole first paint for the
  /// hand-off), then wholly there from the first frame of the landing.
  @override
  double pageShown(double land) => land > 0 ? 1 : 0.004;

  @override
  void paint(
    Canvas canvas,
    EmblemStage s, {
    required bool back,
    required bool front,
  }) => paintAthanorEmblem(
    canvas,
    s,
    ready: ready(),
    teach: teach,
    back: back,
    front: front,
  );
}

/// The emblem on home, filling its box. Reads the free pour from the
/// [AthanorService] above it (banked when there is none).
class AthanorEmblem extends StatefulWidget {
  const AthanorEmblem({
    super.key,
    this.animate = true,
    this.lifted,
    this.teach = true,
  });

  final bool animate;

  /// Whether it may pulse to be found before its first opening. The host
  /// holds it off while something else is teaching (the field tutorial).
  final bool teach;

  /// True while the emblem is away carrying the player in.
  final ValueListenable<bool>? lifted;

  @override
  State<AthanorEmblem> createState() => _AthanorEmblemState();
}

class _AthanorEmblemState extends State<AthanorEmblem>
    with GlyphClockLease, WidgetsBindingObserver {
  bool _visible = true;
  double _stilled = 0;
  Timer? _midnight;

  @override
  bool get wantsClock => widget.animate && _visible;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync();
    _scheduleMidnight();
  }

  void _sync() {
    if (!wantsClock) _stilled = GlyphClock.instance.seconds.value;
    syncGlyphClock();
  }

  /// The day turns: read it again.
  void _scheduleMidnight() {
    _midnight?.cancel();
    _midnight = Timer(athanorUntilNextDay(DateTime.now()), () {
      if (!mounted) return;
      setState(() {});
      _scheduleMidnight();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    // Away overnight: the free pour may be back, and the timer may have
    // slept through its moment.
    setState(() {});
    _scheduleMidnight();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      _sync();
    }
  }

  @override
  void didUpdateWidget(covariant AthanorEmblem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AthanorService?>();
    final ready = svc?.dailyPourReady ?? false;
    final teach = widget.teach && svc != null && svc.loaded && !svc.opened;
    Widget paint(bool away) => CustomPaint(
      size: Size.infinite,
      willChange: widget.animate && !away,
      painter: away
          ? null
          : _AthanorEmblemPainter(
              ready: ready,
              teach: teach,
              clock: glyphClock,
              time: glyphClock == null ? _stilled : null,
            ),
    );
    final lifted = widget.lifted;
    return Semantics(
      button: true,
      label: ready ? 'The Athanor, free pour ready' : 'The Athanor',
      child: RepaintBoundary(
        child: lifted == null
            ? paint(false)
            : ValueListenableBuilder<bool>(
                valueListenable: lifted,
                builder: (_, away, _) => paint(away),
              ),
      ),
    );
  }
}

class _AthanorEmblemPainter extends CustomPainter {
  _AthanorEmblemPainter({
    required this.ready,
    this.teach = false,
    this.clock,
    this.time,
  }) : super(repaint: clock);

  final bool ready;
  final bool teach;
  final ValueListenable<double>? clock;
  final double? time;

  @override
  void paint(Canvas canvas, Size size) {
    paintAthanorEmblem(
      canvas,
      EmblemStage(
        box: Offset.zero & size,
        screen: size,
        time: time ?? clock?.value ?? 0,
      ),
      ready: ready,
      teach: teach,
    );
  }

  @override
  bool shouldRepaint(covariant _AthanorEmblemPainter old) =>
      old.ready != ready ||
      old.teach != teach ||
      old.clock != clock ||
      old.time != time;
}

/// Opens the Athanor through the emblem under [from].
Future<void> openAthanor(
  BuildContext context, {
  required GlobalKey from,
  ValueNotifier<bool>? lifted,
}) {
  HapticFeedback.heavyImpact();
  final svc = context.read<AthanorService>();
  final ready = ValueNotifier<bool>(false);
  final revealed = ValueNotifier<bool>(false);
  // The passage lifts the icon the moment it is pushed, but the route's
  // first frame is laid out offstage (for heroes) and not painted, so home
  // showed neither the icon nor the furnace for that frame: a blink on the
  // tap. The icon is lifted a frame later, when the passage's furnace is
  // standing over it; it comes back as soon as the passage lets it go.
  final away = ValueNotifier<bool>(false);
  if (lifted != null) {
    away.addListener(() {
      if (!away.value) {
        lifted.value = false;
        return;
      }
      SchedulerBinding.instance
        ..addPostFrameCallback((_) {
          if (away.value) lifted.value = true;
        })
        ..ensureVisualUpdate();
    });
  }
  return EmblemPassage.pushScene<void>(
    context,
    scene: AthanorPassageScene(
      ready: () => svc.dailyPourReady,
      teach: svc.loaded && !svc.opened,
      listenable: svc,
    ),
    from: from,
    page: AthanorScreen(revealReady: ready, revealed: revealed),
    ready: ready,
    revealed: revealed,
    lifted: away,
  );
}

/// Home's bottom-centre slot: the emblem alone, unlabelled, in the box the
/// daily chest had (128 across at full scale, [scale] smaller on a short
/// screen). Until it is first opened it pulses to be found ([teach]).
class AthanorHomeSlot extends StatelessWidget {
  const AthanorHomeSlot({
    super.key,
    required this.emblemKey,
    required this.onTap,
    this.scale = 1,
    this.animate = true,
    this.teach = true,
    this.lifted,
  });

  final GlobalKey emblemKey;
  final VoidCallback onTap;
  final double scale;
  final bool animate;
  final bool teach;
  final ValueListenable<bool>? lifted;

  @override
  Widget build(BuildContext context) {
    final side = 128 * scale;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: side,
        height: side,
        child: AthanorEmblem(
          key: emblemKey,
          animate: animate,
          teach: teach,
          lifted: lifted,
        ),
      ),
    );
  }
}
