// lib/games/stadium/bout_stage.dart
//
// What a gem cup's bout shows its screen (bout_screen.dart), whatever the
// event: the island (island_stage.dart), the night sky (sky_stage.dart),
// the space course (flight_stage.dart). The screen ticks it, puts the
// player's taps in, plays what it asks to hear, and lays the same HUD over
// each: the three by name, what is under way, the action with a pip per
// stamina bar (when there is one), and the places when it is over.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// What a bout asks to be heard (the race's own sounds serve).
enum BoutSound { countTick, gun, act, hit, out, win, cast, land }

abstract class BoutStage implements Listenable {
  /// The player's place in the three.
  int get player;

  /// Over, and the places are in.
  bool get done;

  /// The three, the winner first.
  List<int> get standings;

  /// Whether the player has anything to do (the night sky is only
  /// watched).
  bool get hasAction;

  /// The player's action now: whether it can be taken, how many stamina
  /// bars are left for it, and taking it.
  bool get canAct;
  int get actsLeft;
  bool act();

  /// How far the bar being spent has poured out, 0..1, while one is; null
  /// otherwise.
  double? get actPour;

  /// Seconds since the bout began.
  double get clock;

  /// What the action is called (CHARGE, DASH).
  String get actLabel;

  /// Sounds asked for since the screen last took them.
  List<BoutSound> get sounds;

  /// What is under way, under the names (a round), if anything.
  String? get caption;

  /// A word after one's name now (OUT, a time, stars lit), and whether it
  /// is shown dimmed (out of it).
  String? tagOf(int i);
  bool dimmed(int i);

  /// What the results say at the top, for the player's [place].
  String headline(int place);

  /// What the results say beside each one (a time, stars), if anything.
  String? resultOf(int i);

  /// A line under the results for the player (how its ways went), if any.
  String? get note;

  /// The player's mark for its record once it is over (seconds, or stars),
  /// or null when it has none (an island lost).
  double? get mark;

  /// Draws it.
  CustomPainter get painter;

  void advance(double dt);
  void dispose();
}
