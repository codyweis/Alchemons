// lib/screens/stadium/stadium_passage.dart
//
// The way from home's cup into the Trials, and back (the author, 2026-10-12:
// "an awesome transition into the hud from the main menu"; then "the
// transition ... can be way better").
//
// In: the cup lifts off home into the middle as home sinks into the dark,
// light welling up in its bowl. It comes apart into the arena seen from
// above: its own grains, rim first, into an inner ring — the track — while
// its light pours out over the rim into a wider ring round it — the
// stands. The two turn slowly against each other. While the phone turns
// they hold still, and since they are laid in fours a quarter turn apart
// the turn cannot show: no dark, no jump. Then the arena opens out: the
// stands' ring sweeps up into the crowd along the top of the screen, the
// track's ring pours, foot first, into the same cup standing on the
// Trials' shelf, and the Trials come up round them — the passage ends as
// the screen's own cup, in its own place, under its own crowd.
//
// Back: the crowd comes down into its ring and the shelf's cup loosens
// into the track's as the Trials sink; they gather in the middle, hold
// still while the phone turns back, and pour into the cup on home.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/navigation/turning_passage.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/stadium/stadium_screen.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/stadium_trophy.dart';
import 'package:flutter/material.dart';

/// What the stadium and home's way into it share.
class StadiumPassage {
  StadiumPassage({
    required this.home,
    required this.homeLifted,
    required this.onReturn,
  });

  /// Home's cup, and whether it is away.
  final GlobalKey home;
  final ValueNotifier<bool> homeLifted;

  /// Home is shown the cup that is coming back to it, before it is laid
  /// out again under the passage.
  final ValueChanged<TrophyLook> onReturn;

  /// Cup [index]'s box on the shelf, in global coordinates, as it stands
  /// now (set by the shelf while it is built).
  Rect? Function(int index)? cupAt;

  /// The shelf leaves the carried cup to the passage while this is true.
  final ValueNotifier<bool> held = ValueNotifier(true);

  /// The stadium has read its progress and laid itself out.
  final ValueNotifier<bool> ready = ValueNotifier(false);

  /// The cup being carried (in: home's; back: the one racing for now).
  int carried = 0;

  bool _leaving = false;
  bool get leaving => _leaving;

  Rect? cupBox(int index) => cupAt?.call(index);

  /// Back to home the way it came. [cup] is the cup racing for now, and
  /// [look] how it shows.
  Future<void> leave(
    BuildContext context, {
    required int cup,
    required TrophyLook look,
  }) {
    if (_leaving) return Future.value();
    _leaving = true;
    carried = cup;
    held.value = true;
    return VoidPortal.leaveThroughTurn<void>(
      context,
      scene: StadiumTrophyScene(look: look, back: true),
      from: cupBox(cup),
      to: () => rectOf(home),
      onSwapped: () => onReturn(look),
      onLanded: () => homeLifted.value = false,
    );
  }

  /// [key]'s box on the screen.
  static Rect? rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

/// Into the Trials from home's cup ([from], showing [look]). [lifted]
/// hides home's cup while it is away; [onReturn] shows home the cup coming
/// back. The Trials are upright, like home, so nothing turns; what they open
/// on is read while the cup unfolds.
Future<void> openStadiumFromHome(
  BuildContext context, {
  required GlobalKey from,
  required ValueNotifier<bool> lifted,
  required TrophyLook look,
  required int cup,
  required ValueChanged<TrophyLook> onReturn,
  List<CosmicPartyMember> party = const [],
}) async {
  final passage = StadiumPassage(
    home: from,
    homeLifted: lifted,
    onReturn: onReturn,
  )..carried = cup;
  final start = StadiumPassage.rectOf(from);
  final preload = loadTrialsStart(context, party: party);
  lifted.value = true;
  try {
    await VoidPortal.pushThroughTurn<void>(
      context,
      page: StadiumScreen(party: party, passage: passage, preload: preload),
      scene: StadiumTrophyScene(look: look),
      from: start,
      to: () => passage.cupBox(passage.carried),
      ready: passage.ready,
      onLanded: () => passage.held.value = false,
    );
  } finally {
    // Left some other way than the passage back: the cup is home again.
    // (The passage back puts it there itself, as it lands.)
    if (!passage.leaving) lifted.value = false;
  }
}

/// The cup carried across the turn (see the file's header).
class StadiumTrophyScene extends TurningScene {
  const StadiumTrophyScene({required this.look, this.back = false});

  final TrophyLook look;

  /// Going back to home.
  final bool back;

  @override
  double get rise => back ? .8 : .85;

  @override
  double get settle => back ? .9 : 1.1;

  @override
  bool get holdsThroughTurn => true;

  /// The cup's own height in a box from [trophyBoxFor].
  static double heightIn(Rect box) => box.height / 1.3;

  /// How tall the cup is held in the middle of [screen].
  static double heldHeight(Size screen) =>
      math.min(screen.shortestSide * .34, 170);

  /// The track's ring and the stands' ring, by the screen's short side: the
  /// same either way up.
  static double trackRadius(Size screen) => screen.shortestSide * .2;
  static double standsRadius(Size screen) => screen.shortestSide * .33;

  double _smooth(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  @override
  void paint(Canvas canvas, TurningStage s) {
    final mid = s.screen.center(Offset.zero);
    final held = heldHeight(s.screen);
    final track = trackRadius(s.screen);
    if (s.settle <= 0) {
      final from = s.from;
      final c0 = from == null ? mid : trophyCentreIn(from);
      final h0 = from == null ? held : heightIn(from);
      if (!back) {
        // Lifts into the middle along a bow, growing, light welling up in
        // its bowl; then comes apart, rim first, into the track's ring.
        // Off at once: fast out of the tap, easing into the middle.
        final m = Curves.easeOutCubic.transform((s.rise / .5).clamp(0.0, 1.0));
        final bow = Offset(
          0,
          -s.screen.shortestSide * .12 * math.sin(math.pi * m),
        );
        final at = Offset.lerp(c0, mid, m)! + bow * (1 - m);
        final h = ui.lerpDouble(h0, held, m)!;
        _light(canvas, mid, held, _smooth(.3, .7, s.rise));
        _arena(canvas, s, cup: at, cupHeight: h);
        paintStadiumTrophy(
          canvas,
          at,
          h,
          TrophyLook(
            look.metal,
            fill: ui.lerpDouble(look.fill, 1, _smooth(.15, .45, s.rise))!,
          ),
          s.time,
          ring: TrophyRing(
            centre: mid,
            radius: track,
            loose: _smooth(.48, 1, s.rise),
            clock: s.motion,
            inner: .8,
          ),
        );
      } else {
        // Loosens where it stands; the ring drifts to the middle.
        final m = Curves.easeOutCubic.transform(
          ((s.rise - .1) / .8).clamp(0.0, 1.0),
        );
        _light(canvas, mid, held, _smooth(.4, 1, s.rise));
        _arena(canvas, s, cup: c0, cupHeight: h0);
        paintStadiumTrophy(
          canvas,
          c0,
          h0,
          look,
          s.time,
          ring: TrophyRing(
            centre: Offset.lerp(c0, mid, m)!,
            radius: ui.lerpDouble(h0 * .55, track, m)!,
            loose: _smooth(0, .75, s.rise),
            clock: s.motion,
            inner: .8,
          ),
        );
      }
      return;
    }
    // Pours into the cup where it stands, the ring drawn after it.
    final to = s.to;
    final c1 = to == null ? mid : trophyCentreIn(to);
    final h1 = to == null ? held : heightIn(to);
    // Opens out at once: fast away from the middle, easing into place.
    final m = Curves.easeOutCubic.transform((s.settle / .6).clamp(0.0, 1.0));
    _light(canvas, mid, held, 1 - _smooth(0, .6, s.settle));
    _arena(canvas, s, cup: c1, cupHeight: h1);
    paintStadiumTrophy(
      canvas,
      c1,
      h1,
      look,
      s.time,
      ring: TrophyRing(
        centre: Offset.lerp(mid, c1, m)!,
        radius: ui.lerpDouble(track, h1 * .55, m)!,
        loose: 1 - _smooth(.05, .95, s.settle),
        clock: s.motion,
        inner: .8,
      ),
    );
  }

  /// A soft pool of brass light on the arena's floor while it stands in
  /// the middle (round, so a turn under it cannot show).
  void _light(Canvas canvas, Offset at, double h, double a) {
    if (a <= .01) return;
    final r = h * 1.6;
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..shader = ui.Gradient.radial(at, r, [
          const Color(0xFFE2C98F).withValues(alpha: .1 * a),
          const Color(0xFFE2C98F).withValues(alpha: 0),
        ]),
    );
  }

  static const int _arenaSets = 300;
  static final GrainBatch _batch = GrainBatch(8);
  static const List<Color> _crowd = [
    Color(0xFFB8A27A),
    Color(0xFF9FA6B2),
    Color(0xFF9C8FB0),
  ];

  static double _h(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  /// The stands' ring and the crowd it comes from or becomes: grains in
  /// fours a quarter turn apart round the middle, turning slowly the other
  /// way to the track. In, they pour from the cup's mouth and, once the
  /// phone has turned, sweep up into the crowd along the top of the
  /// screen; back, they come down out of the crowd and pour into home's
  /// cup.
  void _arena(
    Canvas canvas,
    TurningStage s, {
    required Offset cup,
    required double cupHeight,
  }) {
    final w = s.screen.width, h = s.screen.height;
    final mid = s.screen.center(Offset.zero);
    final stands = standsRadius(s.screen);
    final k = (s.screen.shortestSide / 390).clamp(.7, 1.6);
    final b = _batch..clear();
    final mouth = cup - Offset(0, cupHeight * .5);
    // Where the crowd stands on the Trials' screen (the stands' band).
    // Where the crowd stands on the Trials' screen: in its band, in rows
    // that thin toward the back as the stands' do.
    final band = trialsStandsBand(s.screen, s.pad);
    Offset crowdAt(int g) => Offset(
      w * _h(g, 7),
      band.top + band.height * (.18 + .62 * math.pow(_h(g, 8), .8)),
    );
    var alpha = 1.0;
    for (var g = 0; g < _arenaSets * 4; g++) {
      final set = g ~/ 4, q = g % 4;
      // In four tiers, like rows of seats seen from above.
      final tier = (_h(set, 1) * 4).floor();
      final r = stands * (.84 + tier * .085 + (_h(set, 10) - .5) * .03);
      final a =
          _h(set, 2) * math.pi / 2 +
          q * math.pi / 2 -
          s.motion * (.18 + .14 * _h(set, 3));
      final ring = mid + Offset(math.cos(a), math.sin(a)) * r;
      Offset p;
      Offset? was;
      if (s.settle <= 0) {
        final st = (_h(set, 6) * .3);
        if (!back) {
          // Over the rim and out along an arc into the ring.
          final u = ((s.rise - .4 - st) / .35).clamp(0.0, 1.0);
          if (u <= 0) continue;
          final e = Curves.easeOutCubic.transform(u);
          final arc = Offset(0, -stands * .55 * math.sin(math.pi * e));
          p = Offset.lerp(mouth, ring, e)! + arc * (1 - e * .5);
          final e0 = Curves.easeOutCubic.transform((u - .06).clamp(0.0, 1.0));
          was = Offset.lerp(mouth, ring, e0)! + arc * (1 - e0 * .5);
        } else {
          // Down out of the crowd into the ring.
          final u = ((s.rise - .05 - st) / .6).clamp(0.0, 1.0);
          final e = Curves.easeOutCubic.transform(u);
          final from = crowdAt(g);
          p = Offset.lerp(from, ring, e)!;
          was = Offset.lerp(
            from,
            ring,
            Curves.easeOutCubic.transform((u - .05).clamp(0.0, 1.0)),
          );
        }
      } else if (!back) {
        // Up into the crowd, then gone under the real one.
        final u = ((s.settle - _h(g, 9) * .2) / .5).clamp(0.0, 1.0);
        final e = Curves.easeOutCubic.transform(u);
        final to = crowdAt(g);
        final lift = Offset(0, -h * .12 * math.sin(math.pi * e));
        p = Offset.lerp(ring, to, e)! + lift;
        final e0 = Curves.easeOutCubic.transform((u - .05).clamp(0.0, 1.0));
        was = Offset.lerp(ring, to, e0)! + lift;
        alpha = 1 - _smooth(.55, .95, s.settle);
      } else {
        // Into home's cup, and out.
        final u = ((s.settle - _h(g, 9) * .25) / .5).clamp(0.0, 1.0);
        final e = Curves.easeInCubic.transform(u);
        p = Offset.lerp(ring, mouth, e)!;
        alpha = 1 - _smooth(.35, .75, s.settle);
      }
      final bucket = (_h(set, 4) * 3).floor() * 2 + (_h(set, 5) < .3 ? 1 : 0);
      b.add(bucket, p.dx, p.dy);
      if (was != null && (was - p).distanceSquared > 2) {
        b.add(6, was.dx, was.dy);
      }
    }
    if (alpha <= .01) return;
    for (var t = 0; t < 3; t++) {
      b.draw(canvas, t * 2, 1.8 * k, _crowd[t].withValues(alpha: .7 * alpha));
      b.draw(
        canvas,
        t * 2 + 1,
        2.3 * k,
        Color.lerp(_crowd[t], Colors.white, .35)!.withValues(alpha: .9 * alpha),
      );
    }
    b.draw(canvas, 6, 1.3 * k, _crowd[0].withValues(alpha: .25 * alpha));
  }
}
