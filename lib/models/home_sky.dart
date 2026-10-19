// lib/models/home_sky.dart
//
// The sky over the home biome is the sky of the player's own planet. From
// the ground it shows what the planet is in space — its color, and what it
// wears (its rings arch overhead, its moons cross the night, a blood moon is
// the moon gone red) — the player's constellations at night, and the season
// the year is in. All of it is planet-wide: every realm is under the same
// sky, and each can be turned off.
//
// [HomeSky] is what the player chose; [HomeSkyLook] is what the field is
// given to draw.

import 'dart:ui';

/// The moon's age through its cycle at [now], 0 new → 0.5 full → 1 new:
/// the real moon, as every field draws it.
double lunarPhase(DateTime now) {
  final known = DateTime.utc(2000, 1, 6, 18, 14);
  final days = now.toUtc().difference(known).inMinutes / 1440;
  final p = (days / 29.530588853) % 1;
  return p < 0 ? p + 1 : p;
}

/// A season of the year.
enum HomeSeason { spring, summer, autumn, winter }

/// The season [date] is in, by its month (the northern year: a player
/// elsewhere can hold the one they want).
HomeSeason seasonOf(DateTime date) => switch (date.month) {
  3 || 4 || 5 => HomeSeason.spring,
  6 || 7 || 8 => HomeSeason.summer,
  9 || 10 || 11 => HomeSeason.autumn,
  _ => HomeSeason.winter,
};

/// Which season the home is in: the calendar's, one held, or none shown.
enum HomeSeasonPick {
  live('LIVE'),
  spring('SPRING'),
  summer('SUMMER'),
  autumn('AUTUMN'),
  winter('WINTER'),
  off('OFF');

  const HomeSeasonPick(this.label);
  final String label;

  static HomeSeasonPick byName(Object? name) =>
      values.where((p) => p.name == name).firstOrNull ?? live;
}

/// What the player has chosen of the sky.
class HomeSky {
  const HomeSky({
    this.season = HomeSeasonPick.live,
    this.planet = true,
    this.constellations = true,
    this.idleCamera = true,
  });

  final HomeSeasonPick season;

  /// The planet's color and what it wears, seen in the sky.
  final bool planet;

  /// The player's constellations, at night.
  final bool constellations;

  /// Left alone a while, the camera drifts from one resident to another.
  final bool idleCamera;

  /// The season shown at [now], or null for none.
  HomeSeason? seasonAt(DateTime now) => switch (season) {
    HomeSeasonPick.live => seasonOf(now),
    HomeSeasonPick.spring => HomeSeason.spring,
    HomeSeasonPick.summer => HomeSeason.summer,
    HomeSeasonPick.autumn => HomeSeason.autumn,
    HomeSeasonPick.winter => HomeSeason.winter,
    HomeSeasonPick.off => null,
  };

  HomeSky copyWith({
    HomeSeasonPick? season,
    bool? planet,
    bool? constellations,
    bool? idleCamera,
  }) => HomeSky(
    season: season ?? this.season,
    planet: planet ?? this.planet,
    constellations: constellations ?? this.constellations,
    idleCamera: idleCamera ?? this.idleCamera,
  );

  bool get isDefault =>
      season == HomeSeasonPick.live && planet && constellations && idleCamera;

  /// Only what differs from the default is kept.
  Map<String, dynamic> toJson() => {
    if (season != HomeSeasonPick.live) 'season': season.name,
    if (!planet) 'planet': false,
    if (!constellations) 'constellations': false,
    if (!idleCamera) 'idleCamera': false,
  };

  static HomeSky fromJson(Object? json) {
    if (json is! Map) return const HomeSky();
    return HomeSky(
      season: HomeSeasonPick.byName(json['season']),
      planet: json['planet'] != false,
      constellations: json['constellations'] != false,
      idleCamera: json['idleCamera'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HomeSky &&
      other.season == season &&
      other.planet == planet &&
      other.constellations == constellations &&
      other.idleCamera == idleCamera;

  @override
  int get hashCode => Object.hash(season, planet, constellations, idleCamera);
}

/// One star of a constellation: where it stands in its tree's figure
/// (-1…1 each way, y down), which tree it is (0 Alchemy, 1 Combat,
/// 2 Explorer — the chart's order) and whether it is the tree's root.
class SkyStar {
  const SkyStar(this.x, this.y, this.tree, {this.root = false});
  final double x, y;
  final int tree;
  final bool root;
}

/// What the field draws of the planet over the home: the planet's color
/// and the effects it wears (with their options, 'recipeId.paramKey' →
/// value), and the constellation figures — stars and the links between
/// them, by index into [stars].
class HomeSkyLook {
  const HomeSkyLook({
    this.color,
    this.tint,
    this.wearing = const {},
    this.options = const {},
    this.stars = const [],
    this.links = const [],
  });

  /// The planet's color id (an element, 'Void' or 'Radiant'), and its
  /// swatch; null when the planet is shown plain or not at all.
  final String? color;
  final Color? tint;

  final Set<String> wearing;
  final Map<String, String> options;

  final List<SkyStar> stars;
  final List<(int, int)> links;

  bool wears(String id) => wearing.contains(id);

  /// [id]'s option [key], or [fallback] when it is not set.
  String option(String id, String key, String fallback) =>
      options['$id.$key'] ?? fallback;

  bool get isEmpty => tint == null && wearing.isEmpty && stars.isEmpty;

  static const none = HomeSkyLook();
}
