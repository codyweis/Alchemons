// lib/models/home_visitors.dart
//
// Visitors to the home biome (models/home_secrets.dart). Each is a Mystic,
// one of an element, and comes when exactly the right things are true —
// always, never by chance:
//
//   · two residents in harmony there whose fusion makes its element (the
//     player's own recipe table: Fire and Ice sharing ground make Water,
//     and Water's Mystic answers);
//   · its own realm, if it keeps to one;
//   · its own hour (night, or for the Light, dawn);
//   · and its own sky: a full or new moon (the real one, which no switch
//     can hold), a season, or the realm's own weather.
//
// It stands among the residents for as long as all of that stays true.
// The first time, it leaves its likeness behind as a keepsake.

import 'dart:math' as math;

import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/models/home_secrets.dart';
import 'package:alchemons/models/home_sky.dart';

/// Whether the moon at [phase] is full, or new (within a day or so).
bool moonFull(double phase) => (phase - 0.5).abs() < 0.04;
bool moonNew(double phase) => math.min(phase, 1 - phase) < 0.04;

/// What is true over the home at a moment, as a visitor asks it.
class HomeMoment {
  const HomeMoment({
    required this.realm,
    required this.mood,
    required this.hour,
    required this.season,
    required this.moon,
    required this.makes,
  });

  final HomeRealm realm;

  /// The realm's mood (its weather) by id.
  final String mood;

  /// The hour the field is lit at, 0–24.
  final double hour;

  /// The season shown, if any.
  final HomeSeason? season;

  /// The real moon's phase.
  final double moon;

  /// What the harmonies formed there make.
  final Set<String> makes;

  bool get night => hour >= 21 || hour < 4.5;
  bool get dawn => hour >= 5 && hour < 7.5;
}

class HomeVisitor {
  const HomeVisitor({
    required this.id,
    required this.speciesId,
    required this.element,
    required this.line,
    required this.comes,
    this.realm,
  });

  final String id;

  /// The Mystic that comes.
  final String speciesId;

  /// What a harmony at home must make.
  final String element;

  /// The realm it keeps to; null for any.
  final HomeRealm? realm;

  /// The rest of what must be true: its hour and its sky.
  final bool Function(HomeMoment m) comes;

  /// The keepsake's line: what it is, plainly.
  final String line;

  /// Whether it comes at [m].
  bool comesAt(HomeMoment m) =>
      m.makes.contains(element) &&
      (realm == null || realm == m.realm) &&
      comes(m);
}

final List<HomeVisitor> kHomeVisitors = [
  HomeVisitor(
    id: 'wraithord',
    speciesId: 'MYS14',
    element: 'Spirit',
    realm: HomeRealm.arcane,
    comes: (m) => m.night && moonFull(m.moon),
    line: 'It came to your home under a full moon.',
  ),
  HomeVisitor(
    id: 'magmara',
    speciesId: 'MYS06',
    element: 'Lava',
    realm: HomeRealm.volcano,
    comes: (m) => m.night && m.season == HomeSeason.winter,
    line: 'It came to your home on a winter night.',
  ),
  HomeVisitor(
    id: 'leviathan',
    speciesId: 'MYS02',
    element: 'Water',
    realm: HomeRealm.tidal,
    comes: (m) => m.night && moonNew(m.moon),
    line: 'It came to your home with the new moon.',
  ),
  HomeVisitor(
    id: 'botanica',
    speciesId: 'MYS12',
    element: 'Plant',
    realm: HomeRealm.valley,
    comes: (m) => m.night && m.season == HomeSeason.spring,
    line: 'It came to your home on a spring night.',
  ),
  HomeVisitor(
    id: 'frowyrm',
    speciesId: 'MYS09',
    element: 'Ice',
    realm: HomeRealm.geode,
    comes: (m) => m.night && m.mood == 'frostfall',
    line: 'It came to your home in the frostfall.',
  ),
  HomeVisitor(
    id: 'raikuma',
    speciesId: 'MYS07',
    element: 'Lightning',
    realm: HomeRealm.sky,
    comes: (m) => m.night && m.mood == 'storm',
    line: 'It came to your home in the storm.',
  ),
  HomeVisitor(
    id: 'solarin',
    speciesId: 'MYS16',
    element: 'Light',
    comes: (m) => m.dawn,
    line: 'It came to your home at dawn.',
  ),
  HomeVisitor(
    id: 'sanguorath',
    speciesId: 'MYS17',
    element: 'Blood',
    comes: (m) => m.night && moonFull(m.moon),
    line: 'It came to your home under a full moon.',
  ),
];

/// The visitor at [m], if one comes (the first of them that does).
/// [anyway] asks only for the harmony (the developer tools).
HomeVisitor? visitorAt(HomeMoment m, {bool anyway = false}) {
  for (final v in kHomeVisitors) {
    if (anyway ? m.makes.contains(v.element) : v.comesAt(m)) return v;
  }
  return null;
}

HomeVisitor? visitorById(String id) =>
    kHomeVisitors.where((v) => v.id == id).firstOrNull;

/// What is true over [layout]'s realm at [now], the field lit at [hour],
/// with [formed] the harmonies there.
HomeMoment momentOf(
  HomeBiomeLayout layout,
  DateTime now,
  double hour,
  List<HomeHarmony> formed,
) => HomeMoment(
  realm: layout.realm,
  mood: layout.mood.id,
  hour: hour,
  season: layout.sky.seasonAt(now),
  moon: lunarPhase(now),
  makes: {for (final h in formed) h.makes},
);
