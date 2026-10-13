// lib/games/stadium/race_layout.dart
//
// Where a race's distance falls in the world. The track runs left to right
// in world pixels: a sprint, a pond, ice, mud and the crowd's stretch take
// ground in proportion to their length; a hill, a gap and a fusion station
// are pieces of country of a fixed size that take as long as the racer
// needs. Distance maps to x leg by leg (held in a station while it fuses).
//
// The ground has a shape: the rolling country of the course's scene along
// its sprints, a hill up and over, a pond's banks, a gap's lips. All six
// lanes share it. How a racer carries itself over it — up a slope, half
// under water, gliding a gap or climbing down and out of it, sliding,
// wading — is its [RacePose]. None of it touches the simulation.

import 'dart:math';

import 'package:alchemons/games/stadium/race_rules.dart';

/// World pixels per unit of a stretch's length, and the width of each fixed
/// piece.
const double kRaceSprintPx = 0.9;
const double kRacePondPx = 0.8;
const double kRaceIcePx = 1.0;
const double kRaceMudPx = 0.7;
const double kRaceCrowdPx = 0.8;
const double kRaceHillPx = 300;
const double kRaceGapPx = 240;
const double kRaceStationPx = 130;

/// How deep a pond's bed lies under its surface, and how far a racer that
/// cannot glide climbs down into a gap.
const double kRacePondDepth = 30;
const double kRaceGapDepth = 110;

/// The share of a pond's leg each bank takes, and a gap's leg each lip.
const double kRacePondBank = 0.12, kRaceGapLip = 0.14;

/// Where a racer stands in a fusion station: walking in up to [_fuseIn] of
/// the leg, fused in place until [_fuseOut], out again after.
const double _fuseIn = 0.14, _fuseOut = 0.86;

/// How the stadium hands over to a course's own country, in world pixels:
/// all stadium up to [kRaceStadiumOut] from the start, the country by
/// [kRaceStadiumOut] + [kRaceSceneBlend]; and back again over the same
/// stretch before the line.
const double kRaceStadiumOut = 260, kRaceSceneBlend = 260;

/// A hill's height, by its level.
double raceHillHeight(int level) => switch (level) {
  3 || 5 => 100,
  4 => 90,
  _ => 76,
};

/// How a racer moves at some point of the course.
enum RaceMotion { run, climb, swim, glide, clamber, slide, wade, fuse }

/// How a racer carries itself at a point of the course: off the ground
/// ([lift], world px; negative is down in a gap), sunk into it ([sink], the
/// share of its height under water or mud), leaning ([tilt], radians,
/// nose-up positive), and how it moves.
class RacePose {
  const RacePose({
    this.lift = 0,
    this.sink = 0,
    this.tilt = 0,
    this.motion = RaceMotion.run,
  });

  final double lift, sink, tilt;
  final RaceMotion motion;
}

/// Whether a racer glides a gap rather than climbing down and out of it
/// (among the stars everyone floats over a gap; the gap's judging still
/// favours the winged).
bool raceFlyer(String element, String family, {RaceScene? scene}) {
  if (scene == RaceScene.space) return true;
  final e = element.toLowerCase(), f = family.toLowerCase();
  return f == 'wing' || e == 'air' || e == 'spirit';
}

/// How much the ground rolls along a sprint in each scene, in world px.
double _rollOf(RaceScene scene) => switch (scene) {
  RaceScene.stadium || RaceScene.space => 0,
  RaceScene.hills => 30,
  RaceScene.volcano => 18,
  RaceScene.meadow => 14,
  RaceScene.cliffs || RaceScene.caves => 12,
  RaceScene.forest => 10,
};

class RaceLayout {
  RaceLayout(this.course) {
    var x = 0.0;
    for (final leg in course.legs) {
      starts.add(x);
      final w = switch (leg.kind) {
        RaceLegKind.sprint => leg.length * kRaceSprintPx,
        RaceLegKind.pond => leg.length * kRacePondPx,
        RaceLegKind.ice => leg.length * kRaceIcePx,
        RaceLegKind.mud => leg.length * kRaceMudPx,
        RaceLegKind.crowd => leg.length * kRaceCrowdPx,
        RaceLegKind.hill => kRaceHillPx,
        RaceLegKind.gap => kRaceGapPx,
        RaceLegKind.fuse => kRaceStationPx,
      };
      widths.add(w);
      x += w;
    }
    finishX = x;
    _legStarts = course.legStarts;
    _roll = _rollOf(course.scene);
  }

  final RaceCourse course;

  /// Each leg's left edge and width on the track.
  final List<double> starts = [], widths = [];
  late final double finishX;
  late final List<double> _legStarts;
  late final double _roll;

  /// The leg [distance] is in (the last past the line), and how far through
  /// it (0..1).
  (int, double) legAt(double distance) {
    if (distance <= 0) return (0, 0);
    for (var i = course.legs.length - 1; i >= 0; i--) {
      if (distance >= _legStarts[i]) {
        final f = (distance - _legStarts[i]) / course.legs[i].length;
        return (i, f);
      }
    }
    return (0, 0);
  }

  /// The leg the track x [x] is in, and how far through it (0..1); null
  /// before the start or past the finish.
  (int, double)? legAtX(double x) {
    if (x < 0 || x >= finishX) return null;
    for (var i = course.legs.length - 1; i >= 0; i--) {
      if (x >= starts[i]) return (i, (x - starts[i]) / widths[i]);
    }
    return null;
  }

  /// The track x of [distance]; behind the line and past the finish, the
  /// pace of a sprint.
  double xAt(double distance) {
    if (distance <= 0) return distance * kRaceSprintPx;
    if (distance >= course.length) {
      return finishX + (distance - course.length) * kRaceSprintPx;
    }
    final (i, f) = legAt(distance);
    final w = widths[i];
    if (course.legs[i].kind == RaceLegKind.fuse) {
      final g = f < _fuseIn
          ? f / _fuseIn * 0.5
          : f > _fuseOut
          ? 0.5 + (f - _fuseOut) / (1 - _fuseOut) * 0.5
          : 0.5;
      return starts[i] + g * w;
    }
    return starts[i] + f * w;
  }

  /// The ground's height at track x [x], in world px: rolling along a
  /// sprint, up and over a hill, flat elsewhere (a pond's surface, a gap's
  /// lips — [solidAt] and [pondBedAt] say what lies under them).
  double groundAt(double x) {
    final at = legAtX(x);
    if (at == null) return 0;
    final (i, f) = at;
    final leg = course.legs[i];
    switch (leg.kind) {
      case RaceLegKind.hill:
        final h = raceHillHeight(leg.level);
        // Up the near side over most of it, steeper down the far side.
        return f < 0.58 ? h * _smooth(f / 0.58) : h * _smooth((1 - f) / 0.42);
      case RaceLegKind.sprint:
        if (_roll == 0) return 0;
        final waves = max(1, (widths[i] / 380).round());
        final env = sin(pi * f);
        return _roll * env * env * sin(2 * pi * waves * f + i * 1.7);
      default:
        return 0;
    }
  }

  /// Whether there is ground under track x [x] (not over a gap).
  bool solidAt(double x) {
    final at = legAtX(x);
    if (at == null) return true;
    final (i, f) = at;
    return course.legs[i].kind != RaceLegKind.gap ||
        f < kRaceGapLip ||
        f > 1 - kRaceGapLip;
  }

  /// How deep a pond's bed lies under its surface at track x [x] (0 off a
  /// pond): sloping in from each bank.
  double pondBedAt(double x) {
    final at = legAtX(x);
    if (at == null) return 0;
    final (i, f) = at;
    if (course.legs[i].kind != RaceLegKind.pond) return 0;
    final e = min(f, 1 - f) / kRacePondBank;
    return kRacePondDepth * _smooth(e);
  }

  /// The slope of the ground at track x [x] (rise over run).
  double slopeAt(double x) => (groundAt(x + 4) - groundAt(x - 4)) / 8;

  /// How a racer at [distance] carries itself; [flyer] glides a gap.
  RacePose poseAt(double distance, {required bool flyer}) {
    if (distance <= 0 || distance >= course.length) return const RacePose();
    final (i, f) = legAt(distance);
    final leg = course.legs[i];
    final x = xAt(distance);
    switch (leg.kind) {
      case RaceLegKind.hill:
        final slope = slopeAt(x);
        return RacePose(
          tilt: atan(slope) * 0.55,
          motion: slope > 0.25 ? RaceMotion.climb : RaceMotion.run,
        );
      case RaceLegKind.pond:
        final e = min(f, 1 - f) / kRacePondBank;
        final under = _smooth(e);
        return RacePose(
          sink: 0.45 * under,
          motion: under > 0.5 ? RaceMotion.swim : RaceMotion.run,
        );
      case RaceLegKind.gap:
        const a = kRaceGapLip, b = 1 - kRaceGapLip;
        if (f <= a || f >= b) return const RacePose();
        final g = (f - a) / (b - a);
        if (flyer) {
          // Off the lip, a long glide that sinks a little and comes in.
          return RacePose(
            lift: 16 * sin(pi * g) - 10 * sin(pi * g) * g,
            tilt: 0.12 * cos(pi * g),
            motion: RaceMotion.glide,
          );
        }
        // Down the near wall, across the floor, up the far wall.
        final down = g < 0.28
            ? _smooth(g / 0.28)
            : g > 0.72
            ? _smooth((1 - g) / 0.28)
            : 1.0;
        return RacePose(
          lift: -kRaceGapDepth * down,
          tilt: g < 0.28 ? -0.5 : (g > 0.72 ? 0.6 : 0),
          motion: g < 0.28 || g > 0.72 ? RaceMotion.clamber : RaceMotion.run,
        );
      case RaceLegKind.ice:
        return const RacePose(motion: RaceMotion.slide);
      case RaceLegKind.mud:
        final e = _smooth(min(f, 1 - f) / 0.1);
        return RacePose(sink: 0.16 * e, motion: RaceMotion.wade);
      case RaceLegKind.fuse:
        return const RacePose(motion: RaceMotion.fuse);
      case RaceLegKind.sprint:
        return RacePose(tilt: atan(slopeAt(x)) * 0.4);
      case RaceLegKind.crowd:
        return const RacePose();
    }
  }

  /// How much of the stadium shows at track x [x] (1 all stadium, 0 the
  /// course's own country): at the start, before the line, and along the
  /// crowd's stretches, which run past the stands.
  double stadiumAt(double x) {
    if (course.scene == RaceScene.stadium) return 1;
    var s = max(
      1 - _smooth((x - kRaceStadiumOut) / kRaceSceneBlend),
      _smooth(
        (x - (finishX - kRaceStadiumOut - kRaceSceneBlend)) / kRaceSceneBlend,
      ),
    );
    for (var j = 0; j < course.legs.length; j++) {
      if (course.legs[j].kind != RaceLegKind.crowd) continue;
      final a = starts[j], b = a + widths[j];
      const fade = 140.0;
      final inside = min(
        _smooth((x - a + fade) / fade),
        _smooth((b - x + fade) / fade),
      );
      s = max(s, inside);
    }
    return s;
  }

  /// Whether a racer at [distance] is fusing: how far through (0..1), or
  /// null.
  double? fusionAt(double distance) {
    if (distance <= 0 || distance >= course.length) return null;
    final (i, f) = legAt(distance);
    if (course.legs[i].kind != RaceLegKind.fuse) return null;
    if (f < _fuseIn || f > _fuseOut) return null;
    return (f - _fuseIn) / (_fuseOut - _fuseIn);
  }

  static double _smooth(double x) {
    final t = max(0.0, min(1.0, x));
    return t * t * (3 - 2 * t);
  }
}
