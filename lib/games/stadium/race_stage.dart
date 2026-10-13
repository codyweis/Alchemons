// lib/games/stadium/race_stage.dart
//
// A race as it is watched: the simulation stepped at its own rate under a
// real-time clock, the six eased between steps, the camera, the announcer,
// and the theatre round it — the count, a photo finish in slow time when the
// leaders meet the line together, the podium. RacePainter draws it; the race
// screen ticks it, puts the player's taps in and plays what it asks to hear.
//
// None of the theatre touches the simulation: slow time only slows how fast
// it is watched, so a live race stays the same race on every phone.
//
// A live race ([RaceLive]) keeps to the wall clock instead — the gun at the
// same moment on every phone, no hurrying it, no slow photo finish — and
// takes the other phones' taps as they arrive ([mergeTaps]).

import 'dart:math';

import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_layout.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

enum RaceStagePhase { intro, countdown, running, podium, done }

/// A live race's timing: the gun at [gunAt] on [wall]'s clock (seconds),
/// and the race kept to that clock, tick for tick.
class RaceLive {
  const RaceLive({required this.gunAt, required this.wall});

  final double gunAt;
  final double Function() wall;
}

/// What the stage asks to be heard.
enum RaceSound {
  countTick,
  gun,
  boost,
  wall,
  fuseIn,
  fuseOut,
  crowdSwell,
  photoHush,
  finish,
  podium,
}

class RaceStage extends ChangeNotifier {
  RaceStage({
    required this.course,
    required this.racers,
    required this.bodies,
    required this.player,
    this.numerals = const {},
    this.forms,
    this.live,
  }) : sim = RaceSim(course, racers),
       layout = RaceLayout(course) {
    final n = racers.length;
    _prev = List.filled(n, 0);
    distance = List.filled(n, 0);
    finishedAtClock = List.filled(n, null);
    _runOn = List.filled(n, 0);
    _lastLeg = List.filled(n, 0);
    _lastBoosts = List.filled(n, 0);
    _fusing = List.filled(n, false);
    boostAtClock = List.filled(n, null);
    elements = [
      for (final r in racers) raceElements(r.entrant.element, course),
    ];
    fusionMade = [
      for (var i = 0; i < racers.length; i++)
        [
          for (var j = 0; j < course.legs.length; j++)
            course.legs[j].element == null
                ? null
                : raceFusion(elements[i][j], course.legs[j].element!),
        ],
    ];
  }

  /// What each racer is entering each leg, and once over the line (see
  /// [raceElements]).
  late final List<List<String>> elements;

  /// Each racer's forms by element (lower case), from [raceForms]; without
  /// them a racer keeps its own body whatever it fuses into.
  final List<Map<String, RaceBody>>? forms;

  /// Racer [lane]'s body as [element].
  RaceBody bodyFor(int lane, String element) =>
      forms?[lane][element.toLowerCase()] ?? bodies[lane];

  /// What racer [lane] is once over the line.
  String finalElement(int lane) => elements[lane].last;

  final RaceCourse course;
  final List<Racer> racers;
  final List<RaceBody> bodies;

  /// The player's lane.
  final int player;

  /// The count's numerals as grains (3, 2, 1), read off type once.
  final Map<int, SpecimenGrains> numerals;

  /// The race (a fresh one, replayed, when a late tap comes in).
  RaceSim sim;
  final RaceLayout layout;

  /// Set for a race run live with other phones.
  final RaceLive? live;

  /// The intro (lanes fill, names), then the count.
  static const double introSeconds = 2.6, countdownSeconds = 3.0;

  /// Held on the line before the podium, and the podium itself.
  static const double podiumDelay = 1.3, podiumSeconds = 4.6;

  /// How slow a photo finish is watched.
  static const double photoRate = 0.28;

  RaceStagePhase phase = RaceStagePhase.intro;

  /// Seconds since the stage opened, since the gun (as watched), and since
  /// the podium began.
  double clock = 0, raceClock = 0, podiumClock = 0;

  /// The watched speed (1, or faster to hurry a solo race).
  double speed = 1;

  /// The screen the race is drawn on, for the camera's framing.
  Size viewport = const Size(844, 390);

  /// Each racer's distance as drawn, eased between simulation steps.
  late final List<double> distance;
  late final List<double> _prev;
  late final List<double> _runOn;
  late final List<int> _lastLeg, _lastBoosts;
  late final List<bool> _fusing;
  double _acc = 0;

  /// The clock when each crossed the line, and when each last boosted.
  late final List<double?> finishedAtClock;
  late final List<double?> boostAtClock;

  /// What each racer makes at each fusion station (null: no recipe, or not
  /// a station).
  late final List<List<String?>> fusionMade;

  /// The camera: its centre in track pixels, the ground's height it holds
  /// level (it rises over a hill), and its zoom over the base.
  double camX = -60, camY = 0, zoom = 1.25;

  /// A photo finish: when it began (null if none), and the margin it was
  /// won by once it is known.
  double? photoAt;
  double? photoMargin;

  /// The announcer's line and when it was said.
  String caption = '';
  double captionAt = -10;
  int _leader = -1;
  double _leadSaidAt = -10, _swellAt = -10;
  double? _overAt;
  int _countSaid = 4;

  /// Sounds asked for since the screen last took them.
  final List<RaceSound> sounds = [];

  bool get running => phase == RaceStagePhase.running;

  /// Seconds left in the count (3, 2, 1), or 0 once off.
  double get countdownLeft => phase == RaceStagePhase.countdown
      ? max(0, introSeconds + countdownSeconds - clock)
      : 0;

  /// The intro's progress, 0..1.
  double get introT => min(1, clock / introSeconds);

  /// Seconds since the results came up.
  double resultsClock = 0;

  /// How far the results have come up (and the podium stood aside for
  /// them), 0..1.
  double get resultsT =>
      phase == RaceStagePhase.done ? min(1, resultsClock / 0.7) : 0;

  /// How far the podium has risen, 0..1.
  double get podiumT => phase == RaceStagePhase.podium
      ? min(1, podiumClock / 0.7)
      : (phase == RaceStagePhase.done ? 1 : 0);

  bool get canBoost => running && sim.canBoost(player);

  int get boostsLeft => sim.states[player].boostsLeft;

  /// Slowed for a photo finish, until just after the line (not live: the
  /// race keeps to the clock there).
  double get _rate {
    if (live != null) return 1;
    final at = photoAt;
    if (at == null) return 1;
    final first = finishedAtClock.whereType<double>().fold<double?>(
      null,
      (a, b) => a == null ? b : min(a, b),
    );
    if (first == null) return photoRate;
    final since = clock - first;
    return since < 0.6
        ? photoRate
        : photoRate + (1 - photoRate) * min(1, (since - 0.6) / 0.6);
  }

  /// The player taps a boost.
  bool tapBoost() {
    if (!canBoost) return false;
    sim.tap(player);
    sounds.add(RaceSound.boost);
    return true;
  }

  /// Another phone's taps for racer [lane], all of them so far. One for a
  /// tick already run replays the race to now with it, as if it had come
  /// in time; the rest wait for their tick.
  void mergeTaps(int lane, List<int> ticks) {
    if (lane < 0 || lane >= racers.length) return;
    final have = sim.taps[lane] ?? const <int>[];
    final fresh = [
      for (final t in ticks)
        if (!have.contains(t)) t,
    ];
    if (fresh.isEmpty) return;
    if (fresh.every((t) => t >= sim.tick)) {
      for (final t in fresh) {
        sim.tap(lane, t);
      }
      return;
    }
    // The players' taps (a computer racer taps again by itself).
    final all = <int, List<int>>{
      for (final e in sim.taps.entries)
        if (racers[e.key].autoBoostLegs.isEmpty) e.key: [...e.value],
    };
    (all[lane] ??= []).addAll(fresh);
    sim = RaceSim.replay(course, racers, all, sim.tick);
    for (var i = 0; i < racers.length; i++) {
      _prev[i] = sim.states[i].distance;
    }
  }

  /// Hurries the podium on to the results.
  void skipPodium() {
    if (phase == RaceStagePhase.podium && podiumClock > 0.8) {
      phase = RaceStagePhase.done;
    }
  }

  void advance(double dt) {
    dt = min(dt, 0.1);
    clock += dt;
    final live = this.live;
    if (live != null && phase.index <= RaceStagePhase.countdown.index) {
      // The count ends on the gun, whenever this phone came to the line.
      final toGun = live.gunAt - live.wall();
      clock = max(clock - dt, introSeconds + countdownSeconds - toGun);
      if (clock < 0) clock = 0;
    }
    switch (phase) {
      case RaceStagePhase.intro:
        if (clock >= introSeconds) phase = RaceStagePhase.countdown;
      case RaceStagePhase.countdown:
        final n = countdownLeft.ceil();
        if (n < _countSaid && n > 0) {
          _countSaid = n;
          sounds.add(RaceSound.countTick);
        }
        if (clock >= introSeconds + countdownSeconds) {
          phase = RaceStagePhase.running;
          sounds.add(RaceSound.gun);
          _say('Off they go');
        }
      case RaceStagePhase.running:
        if (live != null) {
          _runLive(live, dt);
        } else {
          _run(dt * speed * _rate);
        }
        if (sim.over) {
          _overAt ??= clock;
          // Live, a moment more for a last tap from far away.
          final hold = live == null ? podiumDelay : podiumDelay + 0.9;
          if (clock - _overAt! >= hold) {
            phase = RaceStagePhase.podium;
            sounds.add(RaceSound.podium);
          }
        }
      case RaceStagePhase.podium:
        podiumClock += dt;
        _run(dt);
        if (podiumClock >= podiumSeconds) phase = RaceStagePhase.done;
      case RaceStagePhase.done:
        podiumClock += dt;
        resultsClock += dt;
        _run(dt);
    }
    _camera(dt);
    notifyListeners();
  }

  void _run(double dt) {
    raceClock += dt;
    const step = 1 / kRaceTickRate;
    if (!sim.over) {
      _acc += dt;
      while (_acc >= step && !sim.over) {
        for (var i = 0; i < racers.length; i++) {
          _prev[i] = sim.states[i].distance;
        }
        sim.step();
        _acc -= step;
        _events();
      }
      final a = sim.over ? 1.0 : _acc / step;
      for (var i = 0; i < racers.length; i++) {
        final s = sim.states[i];
        distance[i] = _prev[i] + (s.distance - _prev[i]) * a;
        _runOn[i] = s.velocity;
      }
      _watchPhoto();
      return;
    }
    // Over the line, each runs on and slows to a walk.
    for (var i = 0; i < racers.length; i++) {
      _runOn[i] *= pow(0.25, dt).toDouble();
      distance[i] += _runOn[i] * dt;
    }
  }

  /// A live race: stepped to where the wall clock says it is, so every
  /// phone is at the same tick at the same moment.
  void _runLive(RaceLive live, double dt) {
    final since = max(0.0, live.wall() - live.gunAt);
    raceClock = since;
    final at = since * kRaceTickRate;
    final target = at.floor();
    if (!sim.over) {
      // Far behind (the game was away): catch up without drawing each step.
      final many = target - sim.tick > 2;
      while (sim.tick < target && !sim.over) {
        for (var i = 0; i < racers.length; i++) {
          _prev[i] = sim.states[i].distance;
        }
        sim.step();
        if (!many || sim.tick >= target - 1) _events();
      }
      final a = sim.over ? 1.0 : (at - target).clamp(0.0, 1.0);
      for (var i = 0; i < racers.length; i++) {
        final s = sim.states[i];
        distance[i] = _prev[i] + (s.distance - _prev[i]) * a;
        _runOn[i] = s.velocity;
      }
      _watchPhoto();
      return;
    }
    for (var i = 0; i < racers.length; i++) {
      _runOn[i] *= pow(0.25, dt).toDouble();
      distance[i] += _runOn[i] * dt;
    }
  }

  /// The two leaders come to the line within a breath of each other: watch
  /// it slowly.
  void _watchPhoto() {
    if (photoAt != null || finishedAtClock.any((f) => f != null)) return;
    final order = sim.standings;
    final a = sim.states[order[0]], b = sim.states[order[1]];
    final length = course.length;
    if (a.distance < length - 170) return;
    final ta = (length - a.distance) / max(1.0, a.velocity);
    final tb = (length - b.distance) / max(1.0, b.velocity);
    if ((ta - tb).abs() < 0.22) {
      photoAt = clock;
      sounds.add(RaceSound.photoHush);
    }
  }

  void _events() {
    for (var i = 0; i < racers.length; i++) {
      final s = sim.states[i];
      final name = bodies[i].member.displayName;
      if (s.boostsAt.length != _lastBoosts[i]) {
        _lastBoosts[i] = s.boostsAt.length;
        boostAtClock[i] = clock;
      }
      // Into and out of a fusion (the player's are heard). The gathering
      // home is called a little after it begins, so the sound comes whole
      // when the racer does.
      final fp = layout.fusionAt(s.distance);
      final fusing = fp != null && fp < 0.76;
      if (fusing != _fusing[i]) {
        _fusing[i] = fusing;
        if (i == player) {
          sounds.add(fusing ? RaceSound.fuseIn : RaceSound.fuseOut);
        }
      }
      if (s.leg != _lastLeg[i]) {
        final from = _lastLeg[i];
        final left = course.legs[from];
        final into = course.legs[s.leg];
        _lastLeg[i] = s.leg;
        if (i == player && into.kind == RaceLegKind.hill) {
          sounds.add(RaceSound.wall);
        }
        if (i == player && into.kind == RaceLegKind.crowd) _swell();
        final watched = i == player || i == _leader;
        if (left.kind == RaceLegKind.fuse && watched) {
          final made = fusionMade[i][from];
          final a = elements[i][from], b = left.element!;
          _say(
            made == null
                ? '$name has no recipe for $a + $b'
                : '$name fuses $a + $b into $made',
          );
        }
      }
      if (s.finishTime != null && finishedAtClock[i] == null) {
        finishedAtClock[i] = clock;
        final place = finishedAtClock.whereType<double>().length;
        if (place == 1) {
          sounds.add(RaceSound.finish);
          if (photoAt != null) {
            final second = sim.standings.firstWhere((j) => j != i);
            final s2 = sim.states[second];
            final gap = (course.length - s2.distance) / max(1.0, s2.velocity);
            photoMargin = gap;
            _say('Photo finish: $name by ${gap.toStringAsFixed(2)}s');
          } else {
            _say('$name wins');
          }
        } else if (i == player) {
          _say('$name finishes ${ordinal(place)}');
        }
      }
    }
    final lead = sim.standings.first;
    if (lead != _leader) {
      final first = _leader < 0;
      _leader = lead;
      if (!first && sim.states[lead].finishTime == null) {
        if (clock - _leadSaidAt > 2.5) {
          _say('${bodies[lead].member.displayName} takes the lead');
          _leadSaidAt = clock;
          _swell();
        }
      }
    }
  }

  void _swell() {
    if (clock - _swellAt < 3) return;
    _swellAt = clock;
    sounds.add(RaceSound.crowdSwell);
  }

  void _say(String line) {
    caption = line;
    captionAt = clock;
  }

  /// The camera frames the pack — closer when it runs together, wider as it
  /// strings out — and always keeps the player in. It closes on the line
  /// for a photo finish.
  void _camera(double dt) {
    final k0 = (viewport.height / 360).clamp(0.6, 1.6);
    final xs = [for (final d in distance) layout.xAt(d)];
    final me = xs[player];
    double target, targetZoom;
    switch (phase) {
      case RaceStagePhase.intro:
      case RaceStagePhase.countdown:
        target = -30 + 60 * introT;
        targetZoom = 1.3;
      case RaceStagePhase.running:
      case RaceStagePhase.podium:
      case RaceStagePhase.done:
        final lo = xs.reduce(min), hi = xs.reduce(max);
        final mid = (lo + hi) / 2;
        target = mid * 0.55 + me * 0.45 + 40;
        final span = max(hi - lo, (me - target).abs() * 2) + 240;
        targetZoom = (viewport.width / (k0 * span)).clamp(1.0, 1.35);
        if (photoAt != null && finishedAtClock.every((f) => f == null)) {
          target = layout.finishX - 40;
          targetZoom = 1.6;
        }
    }
    final ease = 1 - pow(0.03, dt).toDouble();
    camX += (target - camX) * ease;
    // Up with the ground, most of the way, and more slowly than along it.
    camY +=
        (layout.groundAt(camX) * 0.8 - camY) * (1 - pow(0.08, dt).toDouble());
    zoom += (targetZoom - zoom) * (1 - pow(0.12, dt).toDouble());
  }

  /// Leader first.
  List<int> get standings => sim.standings;
}

String ordinal(int n) => switch (n % 100) {
  11 || 12 || 13 => '${n}th',
  _ => switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  },
};
