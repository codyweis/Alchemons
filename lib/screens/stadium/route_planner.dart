// lib/screens/stadium/route_planner.dart
//
// Before an Emerald Cup flight (flight_rules.dart; the author, 2026-10-12:
// routes picked "before the start"): the course from the start to the
// gate, and at each fork its two ways side by side — each only by its name
// and what fills it, moving; a gate only by its element and its veil. What
// a way asks of a flyer is never said, nor what a gate makes (the author:
// "the user should eventually figure out the tricks"); the flight's
// results tell how long each way took. Pick one at every fork, then FLY.

import 'package:alchemons/games/stadium/flight_rules.dart';
import 'package:alchemons/games/stadium/flight_stage.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

const Color _ink = Color(0xFFE6E2DA);
const Color _muted = Color(0xFF8E8C88);
const Color _brass = Color(0xFFCDB07A);
const Color _brassHot = Color(0xFFE2C98F);
const Color _bg = Color(0xFF09090B);
const Color _bg1 = Color(0xFF131316);

/// Each kind of way's colour (as the flight draws it).
Color flightTint(FlightKind k) => switch (k) {
  FlightKind.open => const Color(0xFFCDB07A),
  FlightKind.asteroids => const Color(0xFFD9A066),
  FlightKind.gravity => const Color(0xFFA48CFF),
  FlightKind.comets => const Color(0xFF9FDCFF),
  FlightKind.nebula => const Color(0xFFF08CC8),
  FlightKind.gate => const Color(0xFFCDB07A),
};

/// A way's colour: its kind's, or a gate's element's own light.
Color flightWayTint(FlightRoute r) => switch (r.element) {
  final e? => essenceRamp(EssenceElement.of(e))[2],
  null => flightTint(r.kind),
};

/// Asks for a route through [course] for [racer]; null if the player backs
/// out.
Future<List<int>?> planFlightRoute(
  BuildContext context, {
  required String title,
  required String subtitle,
  required FlightCourse course,
  required Racer racer,
}) => Navigator.of(context).push<List<int>>(
  PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => _Planner(
      title: title,
      subtitle: subtitle,
      course: course,
      racer: racer,
    ),
    transitionsBuilder: (_, a, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
      child: child,
    ),
  ),
);

class _Planner extends StatefulWidget {
  const _Planner({
    required this.title,
    required this.subtitle,
    required this.course,
    required this.racer,
  });

  final String title, subtitle;
  final FlightCourse course;
  final Racer racer;

  @override
  State<_Planner> createState() => _PlannerState();
}

class _PlannerState extends State<_Planner>
    with SingleTickerProviderStateMixin {
  late final List<int?> _picks = List.filled(widget.course.forks.length, null);

  /// Seconds since the planner opened: the ways' pictures move by it.
  final ValueNotifier<double> _clock = ValueNotifier(0);
  late final Ticker _ticker = createTicker(
    (e) => _clock.value = e.inMicroseconds / 1e6,
  )..start();

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  bool get _ready => _picks.every((p) => p != null);

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    var fork = 0;
    final rows = <Widget>[];
    for (var i = 0; i < course.stretches.length; i++) {
      final st = course.stretches[i];
      if (st.length == 1) {
        rows.add(_open(context, st.single));
      } else {
        final f = fork++;
        rows.add(_fork(context, f, st));
      }
    }
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 46,
                child: Row(
                  children: [
                    BracketIconButton(
                      icon: AppIcons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                      palette: BracketPalette.dark,
                      size: 34,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.title.toUpperCase(),
                              style: bracketText(
                                context,
                                15,
                                _brassHot,
                                weight: FontWeight.w800,
                                letterSpacing: 2.4,
                              ),
                            ),
                            Text(
                              widget.subtitle,
                              style: bracketText(
                                context,
                                9.5,
                                _muted,
                                weight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pick a way at every fork.',
                style: bracketText(context, 12, _ink.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _marker(context, 'START'),
                    ...rows,
                    _marker(context, 'THE GATE'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              BracketButton(
                label: _ready ? 'FLY' : 'PICK EVERY FORK',
                palette: BracketPalette.dark,
                accent: _brass,
                height: 44,
                enabled: _ready,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop([for (final p in _picks) p!]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _marker(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: bracketText(
        context,
        10,
        _brass,
        weight: FontWeight.w800,
        letterSpacing: 2.2,
      ),
    ),
  );

  Widget _open(BuildContext context, FlightRoute r) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(
      r.kind.title,
      textAlign: TextAlign.center,
      style: bracketText(
        context,
        9.5,
        _muted,
        weight: FontWeight.w700,
        letterSpacing: 1.6,
      ),
    ),
  );

  Widget _fork(BuildContext context, int f, List<FlightRoute> st) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var k = 0; k < st.length; k++) ...[
            if (k > 0) const SizedBox(width: 8),
            Expanded(child: _option(context, f, k, st[k])),
          ],
        ],
      ),
    );
  }

  /// One way: its name in its colour over what fills it (a gate: its
  /// element's name over its veil, nothing more).
  Widget _option(BuildContext context, int f, int k, FlightRoute r) {
    final picked = _picks[f] == k;
    final tint = flightWayTint(r);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _picks[f] = k);
      },
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: picked ? tint : BracketPalette.dark.lineSoft,
          strokeWidth: picked ? 1.5 : 1.1,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color: picked ? tint.withValues(alpha: 0.08) : _bg1,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.title,
                style: bracketText(
                  context,
                  11.5,
                  tint,
                  weight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              ClipRect(
                child: SizedBox(
                  height: 74,
                  width: double.infinity,
                  child: _WayPicture(
                    kind: r.kind,
                    element: r.element,
                    seed: f * 7 + k,
                    clock: _clock,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What fills a way, as the flight draws it, small and moving.
class _WayPicture extends StatelessWidget {
  const _WayPicture({
    required this.kind,
    required this.seed,
    required this.clock,
    this.element,
  });

  final FlightKind kind;
  final String? element;
  final int seed;
  final ValueListenable<double> clock;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _WayPainter(kind, element, seed, clock)),
  );
}

class _WayPainter extends CustomPainter {
  _WayPainter(this.kind, this.element, this.seed, this.clock)
    : super(repaint: clock);

  final FlightKind kind;
  final String? element;
  final int seed;
  final ValueListenable<double> clock;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF06070C),
    );
    paintFlightWay(
      canvas,
      (Offset.zero & size).deflate(4),
      kind,
      clock.value,
      seed,
      k: 0.6,
      element: element,
    );
  }

  @override
  bool shouldRepaint(_WayPainter old) =>
      old.kind != kind || old.element != element || old.seed != seed;
}
