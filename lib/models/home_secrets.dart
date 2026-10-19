// lib/models/home_secrets.dart
//
// What the home biome keeps to itself until it is found. Nothing here is
// ever announced: the field only changes, and what has been found is kept.
//
//   HARMONIES  two residents whose elements fuse (the player's own recipe
//              table, assets/data/alchemons_element_recipes.json) sharing
//              ground through a night: by the morning a thread of grains
//              joins them at night, and what they would make lies on the
//              ground between them. Found ones are listed in the journal.
//   VISITORS   on nights when exactly the right things are true, someone
//              comes (home_visitors.dart).
//   BURIED     each realm hides a Core Shard under its ground, and shows
//              it only to those who read the place.
//   FORMS      a realm filled with Alchemons of one division's elements
//              (or all Dark, all Light, all Blood) takes that at once, and
//              after a week turns into its form —
//              each realm its own way; once it has, the form is one of the
//              realm's moods for good.
//
// Found is kept, not derived: a harmony seen once stays found when the pair
// is parted. One Settings row; it travels with the save.

import 'dart:convert';

import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/games/wilderness/field/grain_field.dart' show TidalField;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_blood_heart.dart'
    show heartRecipe, kHeartRecipes;
import 'package:alchemons/models/home_biome.dart';

/// Where what has been found is kept.
const String kHomeSecretsKey = 'home_secrets_v1';

/// Every harmony there is: each pair of elements that fuses into something
/// (sorted, 'Fire+Water'), and what it makes — the recipe table's own main
/// results, in its order.
Map<String, String> get kHarmonies => kHeartRecipes;

/// The harmony of [a] and [b] (sorted, 'Fire+Water').
String harmonyKey(String a, String b) => ([a, b]..sort()).join('+');

/// What [a] and [b] would make together, or null if nothing.
String? harmonyOf(String a, String b) => a == b ? null : heartRecipe(a, b);

/// Whether a night has passed between [since] and [now] (ms since the
/// epoch): the small hours (03:00, the phone's own time) have come round
/// at least once.
bool nightBetween(int since, int now) {
  final s = DateTime.fromMillisecondsSinceEpoch(since);
  var small = DateTime(s.year, s.month, s.day, 3);
  if (!small.isAfter(s)) small = DateTime(s.year, s.month, s.day + 1, 3);
  return !small.isAfter(DateTime.fromMillisecondsSinceEpoch(now));
}

/// Two residents sharing ground: one standing beside the other, or both
/// beside the same thing.
typedef HomePair = (HomeResident, HomeResident);

/// The pairs of [layout]'s current realm who share ground.
List<HomePair> sharingPairs(HomeBiomeLayout layout) {
  final standing = [
    for (final r in layout.residents)
      if (r.lift == null) r,
  ];
  final out = <HomePair>[];
  for (var i = 0; i < standing.length; i++) {
    for (var j = i + 1; j < standing.length; j++) {
      final a = standing[i], b = standing[j];
      if (a.depth != b.depth) continue;
      final shares =
          a.beside == b.spawnId ||
          b.beside == a.spawnId ||
          (a.beside != null && a.beside == b.beside);
      if (shares) out.add((a, b));
    }
  }
  return out;
}

/// A harmony formed between two residents: their spawn ids, and what they
/// make together.
typedef HomeHarmony = ({String a, String b, String makes, String key});

/// The harmonies formed in [layout]'s current realm at [now]: pairs sharing
/// ground whose elements ([elementOf], by instance id) fuse, and who have
/// both been where they stand through a night. [always] forms every pair
/// that fuses at once (the developer tools).
List<HomeHarmony> formedHarmonies(
  HomeBiomeLayout layout,
  int now,
  String? Function(String instanceId) elementOf, {
  bool always = false,
}) => [
  for (final (a, b) in sharingPairs(layout))
    if ((elementOf(a.instanceId), elementOf(b.instanceId)) case (
      final ea?,
      final eb?,
    ))
      if (harmonyOf(ea, eb) case final makes?)
        if (always ||
            (a.since != null &&
                b.since != null &&
                nightBetween(a.since! > b.since! ? a.since! : b.since!, now)))
          (a: a.spawnId, b: b.spawnId, makes: makes, key: harmonyKey(ea, eb)),
];

// ── Buried ─────────────────────────────────────────────────────────────────

/// The realms whose shards open the Core: the five every player can reach.
const List<HomeRealm> kCoreShardRealms = [
  HomeRealm.valley,
  HomeRealm.sky,
  HomeRealm.swamp,
  HomeRealm.volcano,
  HomeRealm.arcane,
];

/// Whether the Core is open: every shard under the five first realms found.
bool coreOpens(HomeSecrets s) =>
    kCoreShardRealms.every((r) => s.buried.contains(r.name));

/// Where under [realm]'s near row its shard lies, as a share of the row's
/// loop. The same in every home: it is the realm's, not the player's.
double buriedAt(HomeRealm realm) => switch (realm) {
  HomeRealm.valley => 0.37,
  HomeRealm.sky => 0.58,
  HomeRealm.swamp => 0.21,
  HomeRealm.volcano => 0.74,
  HomeRealm.arcane => 0.46,
  HomeRealm.dunes => 0.83,
  HomeRealm.geode => 0.29,
  HomeRealm.tidal => 0.65,
  HomeRealm.sand => 0.52,
  HomeRealm.core => 0,
};

/// Whether the place shows where its shard lies now: each realm only in
/// its own moment — the Valley's rainbow, the Sky's storm, the Swamp gone
/// dry, the Volcano erupting, the Arcane's aurora, the Dunes' sandstorm,
/// the Geode singing, the Tidal Shelf at its lowest water (the real tide),
/// and the sand of Living Sands whenever it lies still.
bool buriedShows(HomeRealm realm, String mood, DateTime now) => switch (realm) {
  HomeRealm.valley => mood == 'rainbow',
  HomeRealm.sky => mood == 'storm',
  HomeRealm.swamp => mood == 'dry',
  HomeRealm.volcano => mood == 'erupting',
  HomeRealm.arcane => mood == 'aurora',
  HomeRealm.dunes => mood == 'sandstorm',
  HomeRealm.geode => mood == 'singing',
  HomeRealm.tidal => TidalField.tideAt(now) < 0.15,
  HomeRealm.sand => true,
  HomeRealm.core => false,
};

/// What the home has given up of its secrets.
class HomeSecrets {
  const HomeSecrets({
    this.harmonies = const {},
    this.visitors = const {},
    this.buried = const {},
    this.forms = const {},
  });

  /// Harmonies found, by key ('Fire+Water').
  final Set<String> harmonies;

  /// Visitors met, by id.
  final Set<String> visitors;

  /// Buried things found, by realm name.
  final Set<String> buried;

  /// Forms realms have taken ('valley:Dark'): each is a mood of its realm
  /// from then on.
  final Set<String> forms;

  /// The forms [realm] has taken, as its moods.
  List<HomeMood> formsOf(HomeRealm realm) => [
    for (final e in kHomeForms)
      if (forms.contains('${realm.name}:$e')) HomeMood.formOf(e),
  ];

  HomeSecrets copyWith({
    Set<String>? harmonies,
    Set<String>? visitors,
    Set<String>? buried,
    Set<String>? forms,
  }) => HomeSecrets(
    harmonies: harmonies ?? this.harmonies,
    visitors: visitors ?? this.visitors,
    buried: buried ?? this.buried,
    forms: forms ?? this.forms,
  );

  Map<String, dynamic> toJson() => {
    if (harmonies.isNotEmpty) 'harmonies': harmonies.toList()..sort(),
    if (visitors.isNotEmpty) 'visitors': visitors.toList()..sort(),
    if (buried.isNotEmpty) 'buried': buried.toList()..sort(),
    if (forms.isNotEmpty) 'forms': forms.toList()..sort(),
  };

  static HomeSecrets fromJson(Object? json) {
    if (json is! Map) return const HomeSecrets();
    Set<String> set(Object? v) =>
        v is List ? {...v.whereType<String>()} : const {};
    return HomeSecrets(
      harmonies: {
        for (final k in set(json['harmonies']))
          if (kHarmonies.containsKey(k)) k,
      },
      visitors: set(json['visitors']),
      buried: set(json['buried']),
      forms: set(json['forms']),
    );
  }

  static Future<HomeSecrets> load(SettingsDao settings) async {
    try {
      final raw = await settings.getSetting(kHomeSecretsKey);
      if (raw == null || raw.isEmpty) return const HomeSecrets();
      return fromJson(jsonDecode(raw));
    } catch (_) {
      return const HomeSecrets();
    }
  }

  Future<void> save(SettingsDao settings) =>
      settings.setSetting(kHomeSecretsKey, jsonEncode(toJson()));
}
