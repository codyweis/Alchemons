// lib/models/home_biome.dart
//
// The home biome: the player's own field under their home planet, reached
// by descending from the home base. They choose which of the five wild
// realms it is, the realm's own weather or mood, the hour it is held at,
// and which of their Alchemons live there and where each one stands.
//
// A realm keeps what is its own: rain and snow only fall in the Valley, the
// storm is the Sky's, and so on. The field is the realm's own field drawn in
// code (lib/games/wilderness/field/), with the residents standing in for its
// wild spawns — so the Sky builds an isle under each, the Swamp a bank, the
// Volcano a shelf, exactly as it does for a wild creature.

import 'dart:convert';
import 'dart:ui';

import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/scenes/arcane/arcane_scene.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:flame/components.dart';

/// How many Alchemons can live in the home biome at once.
const int kHomeBiomeMaxResidents = 12;

/// Where the layout is kept (a Settings row: it travels with the save).
const String kHomeBiomeSettingsKey = 'home_biome_v1';

/// A realm's own weather, or the mood its land is in, as the player picks
/// it: what the field is given while the home biome is open.
class HomeMood {
  const HomeMood(
    this.id,
    this.label, {
    this.weather,
    this.aftermath = false,
    this.stage = 0,
  });

  final String id;
  final String label;
  final WeatherKind? weather;

  /// What the weather leaves behind is showing (the Valley's rainbow).
  final bool aftermath;

  /// The field's own cycle (the Volcano still, smoking or erupting).
  final int stage;
}

/// One row of a realm for residents: the near ground or the far one.
class HomeRow {
  const HomeRow(this.layer, this.height, this.size);

  final SceneLayer layer;

  /// Where a standing resident's middle is, as a share of the height —
  /// where the realm's own wild creatures stand on this row.
  final double height;

  /// How big a resident is drawn on this row.
  final double size;
}

enum HomeRealm {
  valley(
    'Verdant Valley',
    'plant',
    near: HomeRow(SceneLayer.layer4, 0.80, 100),
    far: HomeRow(SceneLayer.layer3, 0.65, 70),
    moods: [
      HomeMood('clear', 'CLEAR'),
      HomeMood('rain', 'RAIN', weather: WeatherKind.rain),
      HomeMood('snow', 'SNOW', weather: WeatherKind.snow),
      HomeMood('rainbow', 'RAINBOW', aftermath: true),
    ],
  ),
  sky(
    'Skyward Reach',
    'air',
    near: HomeRow(SceneLayer.layer4, 0.60, 90),
    far: HomeRow(SceneLayer.layer3, 0.44, 65),
    moods: [
      HomeMood('clear', 'CLEAR'),
      HomeMood('storm', 'STORM', weather: WeatherKind.storm),
    ],
  ),
  swamp(
    'Sunken Swamp',
    'mud',
    near: HomeRow(SceneLayer.layer4, 0.69, 92),
    far: HomeRow(SceneLayer.layer3, 0.57, 66),
    moods: [
      HomeMood('wet', 'WET'),
      HomeMood('dry', 'DRY', weather: WeatherKind.dry),
    ],
  ),
  volcano(
    'Ashen Volcano',
    'fire',
    near: HomeRow(SceneLayer.layer4, 0.70, 86),
    far: HomeRow(SceneLayer.layer3, 0.57, 66),
    moods: [
      HomeMood('still', 'STILL', stage: VolcanoField.still),
      HomeMood('smoking', 'SMOKING', stage: VolcanoField.smoking),
      HomeMood('erupting', 'ERUPTING', stage: VolcanoField.erupting),
    ],
  ),
  arcane(
    'Arcane Expanse',
    'spirit',
    near: HomeRow(SceneLayer.layer4, 0.70, 80),
    far: HomeRow(SceneLayer.layer3, 0.575, 66),
    moods: [
      HomeMood('clear', 'CLEAR'),
      HomeMood('meteors', 'METEORS', weather: WeatherKind.meteors),
      HomeMood('aurora', 'AURORA', weather: WeatherKind.aurora),
    ],
  );

  const HomeRealm(
    this.title,
    this.portalElement, {
    required this.near,
    required this.far,
    required this.moods,
  });

  final String title;

  /// The element whose portal twist the descent borrows — the same one the
  /// wild map's entry into this realm uses.
  final String portalElement;

  final HomeRow near, far;
  final List<HomeMood> moods;

  /// The scene id the wild uses for this realm (its music, its map).
  String get sceneId => name;

  /// The realm's wild scene, whose field the home biome draws.
  SceneDefinition get wildScene => switch (this) {
    HomeRealm.valley => valleySceneCorrected,
    HomeRealm.sky => skyScene,
    HomeRealm.swamp => swampScene,
    HomeRealm.volcano => volcanoScene,
    HomeRealm.arcane => arcaneScene,
  };

  HomeRow row({required bool back}) => back ? far : near;

  HomeMood mood(String? id) =>
      moods.where((m) => m.id == id).firstOrNull ?? moods.first;

  /// How far [layer] runs before it repeats, in its own units.
  double period(SceneLayer layer) {
    final scene = wildScene;
    final pf = scene.layers
        .firstWhere((l) => l.id == layer, orElse: () => scene.layers.first)
        .parallaxFactor;
    return scene.worldWidth * (1 + pf);
  }

  static HomeRealm byName(String? name) =>
      HomeRealm.values.where((r) => r.name == name).firstOrNull ??
      HomeRealm.valley;

  /// The realms a home can be made in: the Arcane only once its portal has
  /// been opened in the wild ([arcane]), as the wild map shows it.
  static List<HomeRealm> open({required bool arcane}) => [
    for (final r in values)
      if (r != HomeRealm.arcane || arcane) r,
  ];
}

/// One of the player's Alchemons living in the home biome, and where.
class HomeResident {
  const HomeResident({
    required this.instanceId,
    this.back = false,
    this.x = 0,
    this.lift,
    this.flip = false,
  });

  final String instanceId;

  /// On the far row (the Valley's hills) rather than the near one.
  final bool back;

  /// Where along its row, as a share of the row's loop.
  final double x;

  /// For one that can float, held in the air: its middle's height as a
  /// share of the field's height. Null when it stands.
  final double? lift;

  /// Facing the other way.
  final bool flip;

  String get spawnId => 'HOME_$instanceId';

  HomeResident copyWith({
    bool? back,
    double? x,
    double? Function()? lift,
    bool? flip,
  }) => HomeResident(
    instanceId: instanceId,
    back: back ?? this.back,
    x: x ?? this.x,
    lift: lift != null ? lift() : this.lift,
    flip: flip ?? this.flip,
  );

  Map<String, dynamic> toJson() => {
    'id': instanceId,
    if (back) 'back': true,
    'x': double.parse(x.toStringAsFixed(4)),
    if (lift != null) 'lift': double.parse(lift!.toStringAsFixed(4)),
    if (flip) 'flip': true,
  };

  static HomeResident? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final x = json['x'];
    final lift = json['lift'];
    return HomeResident(
      instanceId: id,
      back: json['back'] == true,
      x: x is num ? (x.toDouble() % 1.0) : 0,
      lift: lift is num ? lift.toDouble().clamp(0.1, 0.92) : null,
      flip: json['flip'] == true,
    );
  }
}

/// The whole home biome as the player has made it.
class HomeBiomeLayout {
  const HomeBiomeLayout({
    this.realm = HomeRealm.valley,
    this.moods = const {},
    this.hour,
    this.residents = const [],
  });

  final HomeRealm realm;

  /// The mood picked for each realm, by realm name — each keeps its own, so
  /// going back to the Valley finds its rain still falling.
  final Map<String, String> moods;

  /// The hour the field is held at, 0–24; null follows the phone's clock.
  final double? hour;

  final List<HomeResident> residents;

  HomeMood get mood => realm.mood(moods[realm.name]);

  HomeBiomeLayout copyWith({
    HomeRealm? realm,
    Map<String, String>? moods,
    double? Function()? hour,
    List<HomeResident>? residents,
  }) => HomeBiomeLayout(
    realm: realm ?? this.realm,
    moods: moods ?? this.moods,
    hour: hour != null ? hour() : this.hour,
    residents: residents ?? this.residents,
  );

  HomeBiomeLayout withMood(String id) =>
      copyWith(moods: {...moods, realm.name: id});

  /// This layout in a realm that is [open] — the first of them when its own
  /// is not (an Arcane home before the Arcane is unlocked).
  HomeBiomeLayout within(List<HomeRealm> open) =>
      open.contains(realm) ? this : copyWith(realm: open.first);

  /// The layout as the player may have it now, whether the Arcane is
  /// unlocked read from [settings].
  static Future<HomeBiomeLayout> loadOpen(SettingsDao settings) async {
    final arcane = await settings.isArcanePortalUnlocked();
    return (await load(settings)).within(HomeRealm.open(arcane: arcane));
  }

  HomeResident? resident(String spawnId) =>
      residents.where((r) => r.spawnId == spawnId).firstOrNull;

  HomeBiomeLayout replace(HomeResident r) => copyWith(
    residents: [
      for (final o in residents) o.instanceId == r.instanceId ? r : o,
    ],
  );

  /// The scene the home biome shows: the realm's own field, its points the
  /// residents. [floats] says which of them can be held in the air.
  SceneDefinition scene(bool Function(String instanceId) floats) =>
      realm.wildScene.copyWith(spawnPoints: spawnPoints(floats));

  List<SpawnPoint> spawnPoints(bool Function(String instanceId) floats) => [
    for (final r in residents) spawnPointFor(r, floats: floats(r.instanceId)),
  ];

  SpawnPoint spawnPointFor(HomeResident r, {required bool floats}) {
    final row = realm.row(back: r.back);
    final aloft = floats && r.lift != null;
    return SpawnPoint(
      id: r.spawnId,
      normalizedPos: Offset(r.x, aloft ? r.lift! : row.height),
      anchor: row.layer,
      size: Vector2.all(row.size),
      perch: aloft ? SpawnPerch.air : SpawnPerch.ground,
    );
  }

  /// How far apart two residents on one row must stand, as a share of the
  /// row's loop: room for each one's isle, bank or shelf — or, for two in
  /// the air ([aloft]), room for each one's wings.
  double gap({required bool back, bool aloft = false}) {
    final row = realm.row(back: back);
    return row.size * (aloft ? 1.2 : 1.9) / realm.period(row.layer);
  }

  /// Where [r] can stand nearest [x] on its row without crowding anyone
  /// else there, or null if the row has no room. What stands keeps clear
  /// of what stands, what flies of what flies: a creature can hover over
  /// another's head.
  double? freeSpotNear(HomeResident r, double x) {
    final aloft = r.lift != null;
    final g = gap(back: r.back, aloft: aloft);
    final others = [
      for (final o in residents)
        if (o.instanceId != r.instanceId &&
            o.back == r.back &&
            (o.lift != null) == aloft)
          o.x,
    ];
    bool free(double at) => others.every((o) {
      final d = (at - o).abs() % 1.0;
      return (d > 0.5 ? 1 - d : d) >= g - 1e-9;
    });
    final step = g / 6;
    final tries = (1 / step).ceil();
    for (var i = 0; i <= tries; i++) {
      for (final s in i == 0 ? const [1] : const [1, -1]) {
        final at = (x + s * i * step) % 1.0;
        if (free(at)) return at;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'realm': realm.name,
    if (moods.isNotEmpty) 'moods': moods,
    if (hour != null) 'hour': hour,
    'residents': [for (final r in residents) r.toJson()],
  };

  static HomeBiomeLayout fromJson(Object? json) {
    if (json is! Map) return const HomeBiomeLayout();
    final moods = json['moods'];
    final hour = json['hour'];
    final residents = json['residents'];
    final seen = <String>{};
    return HomeBiomeLayout(
      realm: HomeRealm.byName(json['realm'] as String?),
      moods: moods is Map
          ? {
              for (final e in moods.entries)
                if (e.key is String && e.value is String)
                  e.key as String: e.value as String,
            }
          : const {},
      hour: hour is num ? hour.toDouble() % 24 : null,
      residents: residents is List
          ? [
              for (final r in residents.map(HomeResident.fromJson))
                if (r != null && seen.add(r.instanceId)) r,
            ].take(kHomeBiomeMaxResidents).toList()
          : const [],
    );
  }

  static Future<HomeBiomeLayout> load(SettingsDao settings) async {
    final raw = await settings.getSetting(kHomeBiomeSettingsKey);
    if (raw == null || raw.isEmpty) return const HomeBiomeLayout();
    try {
      return fromJson(jsonDecode(raw));
    } catch (_) {
      return const HomeBiomeLayout();
    }
  }

  Future<void> save(SettingsDao settings) =>
      settings.setSetting(kHomeBiomeSettingsKey, jsonEncode(toJson()));
}
