// lib/screens/stadium/stadium_passage.dart
//
// The way from home's cup into the Trials, and back (the author, 2026-10-12:
// "an awesome transition into the hud from the main menu"; 2026-10-14: the
// ring-and-crowd version was "a bit cheesy and slow").
//
// In: the cup leaves home's corner and glides, growing, straight to its
// place on the Trials' shelf, as home sinks into the dark and the Trials
// come up round it; a glint runs over it as it lands. The hub is not built
// when it sets off, so it flies to where the shelf will put it, and the
// shelf's own word takes over once the hub has laid out.
//
// Back: the shelf's cup glides back to home's corner the same way.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/navigation/turning_passage.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/stadium/cup_shelf.dart';
import 'package:alchemons/screens/stadium/stadium_screen.dart';
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

  /// Home's cup's box as it was left: the way back flies for it until
  /// home has been laid out again to ask.
  Rect? homeAt;

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
      scene: StadiumTrophyScene(look: look, back: true, guess: homeAt),
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
/// on is read while the cup flies.
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
  final start = passage.homeAt = StadiumPassage.rectOf(from);
  final preload = loadTrialsStart(context, party: party);
  lifted.value = true;
  try {
    await VoidPortal.pushThroughTurn<void>(
      context,
      page: StadiumScreen(party: party, passage: passage, preload: preload),
      scene: StadiumTrophyScene(
        look: look,
        guess: trialsCupGuess(
          MediaQuery.sizeOf(context),
          MediaQuery.paddingOf(context),
          cup,
        ),
      ),
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

/// Home's cup flying to its place on the shelf, or back (see the file's
/// header).
class StadiumTrophyScene extends TurningScene {
  const StadiumTrophyScene({required this.look, this.guess, this.back = false});

  final TrophyLook look;

  /// Where it lands, worked out before the screen it lands on is there to
  /// ask (in: the shelf's cup, the hub not built yet; back: home's cup as
  /// it was left). The real place takes over as the settle begins.
  final Rect? guess;

  /// Going back to home.
  final bool back;

  @override
  double get rise => back ? .22 : .24;

  @override
  double get settle => back ? .44 : .5;

  /// The whole flight, on the passage's own clock: the page is swapped in
  /// between rise and settle, a few frames, and the cup keeps moving
  /// through them.
  double get _flight => rise + settle + .06;

  /// The cup's own height in a box from [trophyBoxFor].
  static double heightIn(Rect box) => box.height / 1.3;

  double _smooth(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// Home sinks as the cup leaves it; the Trials come up as it lands.
  @override
  double groundAt(TurningStage s) =>
      s.settle > 0 ? 1 - _smooth(0, .75, s.settle) : _smooth(0, 1, s.rise);

  @override
  void paint(Canvas canvas, TurningStage s) {
    final from = s.from;
    final c0 = from == null
        ? s.screen.center(Offset.zero)
        : trophyCentreIn(from);
    final h0 = from == null ? 60.0 : heightIn(from);
    var to = guess;
    final real = s.to;
    if (real != null) {
      to = to == null ? real : Rect.lerp(to, real, _smooth(0, .35, s.settle));
    }
    final c1 = to == null ? c0 : trophyCentreIn(to);
    final h1 = to == null ? h0 : heightIn(to);
    // One glide, off the tap at once and still moving as the page comes
    // up round it; it lands as the settle ends, however long the swap took.
    final u = math.max(s.motion / _flight, s.settle).clamp(0.0, 1.0);
    final m = Curves.ease.transform(u);
    // Sagging a little on the way, as something carried does.
    final sag = Offset(0, (c1 - c0).distance * .08 * math.sin(math.pi * m));
    paintStadiumTrophy(
      canvas,
      Offset.lerp(c0, c1, m)! + sag,
      ui.lerpDouble(h0, h1, m)!,
      look,
      s.time,
      still: true,
      // One glint runs over it as it comes into its place.
      glint: (u - .45) / .55,
    );
  }
}

/// Where the cup racing for now, [cup], will stand on the hub's shelf, for
/// a screen [size] with [pad] round it.
Rect trialsCupGuess(Size size, EdgeInsets pad, int cup) {
  final shelf = trialsShelfRect(size, pad);
  final geo = CupShelfGeo(shelf.size, [
    for (var i = 0; i < kRaceCups.length; i++) i == cup ? 1.0 : 0.0,
  ]);
  return geo.boxes[cup.clamp(0, geo.boxes.length - 1)].shift(shelf.topLeft);
}
