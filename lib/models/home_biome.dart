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
import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/games/wilderness/field/field_art.dart';
import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/games/wilderness/field/home_core_field.dart';
import 'package:alchemons/games/wilderness/field/home_sand_field.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/home_decor.dart';
import 'package:alchemons/models/home_sand.dart';
import 'package:alchemons/models/home_secrets.dart';
import 'package:alchemons/models/home_sky.dart';
import 'package:alchemons/models/scenes/arcane/arcane_scene.dart';
import 'package:alchemons/models/scenes/dunes/dunes_scene.dart';
import 'package:alchemons/models/scenes/geode/geode_scene.dart';
import 'package:alchemons/models/scenes/tidal/tidal_scene.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/shop_scenes.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:flame/components.dart';

/// Whether the developer tools are on, which open everything in the home
/// biome; false where there are no preferences to read (a test harness).
Future<bool> homeDebugOn() async {
  try {
    return await DebugSettingsService().isEnabled();
  } catch (_) {
    return false;
  }
}

/// How many Alchemons can live in the home biome at once.
const int kHomeBiomeMaxResidents = 12;

/// How many can stand beside one thing, on each side of it.
const int kHomeBesidePerSide = 3;

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
    this.form,
  });

  final String id;
  final String label;
  final WeatherKind? weather;

  /// The element the realm's land has taken, fully: a form earned by
  /// filling it with one element for a week (see [HomeHold]).
  final String? form;

  /// The mood that is [element]'s form, earned.
  static HomeMood formOf(String element) =>
      HomeMood('form:$element', element.toUpperCase(), form: element);

  /// What the weather leaves behind is showing (the Valley's rainbow).
  final bool aftermath;

  /// The field's own cycle (the Volcano still, smoking or erupting).
  final int stage;
}

/// One row of a realm for residents: the near ground, the far one, or the
/// ground between them.
class HomeRow {
  const HomeRow(this.layer, this.height, this.size);

  final SceneLayer layer;

  /// Where a standing resident's middle is, as a share of the height —
  /// where the realm's own wild creatures stand on this row.
  final double height;

  /// How big a resident is drawn on this row.
  final double size;

  /// Where feet stand on this row, as a share of the height (at the
  /// fields' reference height, as their own sizes are).
  double get feet => height + 0.42 * size / 475;
}

/// How far back something stands in the home biome: on the near row, the
/// far one, or the one between. The middle row shares the far row's layer
/// (it pans with it) and stands lower down it, nearer, and bigger.
enum HomeDepth {
  front('FRONT'),
  mid('MIDDLE'),
  back('BACK');

  const HomeDepth(this.label);

  final String label;

  /// Every depth, nearest to this one first: itself, then the row next to
  /// it, then the far side.
  List<HomeDepth> get byNearness => switch (this) {
    HomeDepth.front => const [HomeDepth.front, HomeDepth.mid, HomeDepth.back],
    HomeDepth.mid => const [HomeDepth.mid, HomeDepth.front, HomeDepth.back],
    HomeDepth.back => const [HomeDepth.back, HomeDepth.mid, HomeDepth.front],
  };

  /// As saved: absent for the front.
  static HomeDepth fromJson(Map json) => json['mid'] == true
      ? HomeDepth.mid
      : json['back'] == true
      ? HomeDepth.back
      : HomeDepth.front;

  Map<String, bool> toJson() => switch (this) {
    HomeDepth.front => const {},
    HomeDepth.mid => const {'mid': true},
    // As every build has saved the far row.
    HomeDepth.back => const {'back': true},
  };
}

enum HomeRealm {
  valley(
    'Verdant Valley',
    'plant',
    near: HomeRow(SceneLayer.layer4, 0.80, 100),
    far: HomeRow(SceneLayer.layer3, 0.65, 70),
    mid: HomeRow(SceneLayer.layer3, 0.726, 84),
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
    mid: HomeRow(SceneLayer.layer3, 0.52, 77),
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
    mid: HomeRow(SceneLayer.layer3, 0.631, 78),
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
    mid: HomeRow(SceneLayer.layer3, 0.635, 76),
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
    mid: HomeRow(SceneLayer.layer3, 0.637, 73),
    moods: [
      HomeMood('clear', 'CLEAR'),
      HomeMood('meteors', 'METEORS', weather: WeatherKind.meteors),
      HomeMood('aurora', 'AURORA', weather: WeatherKind.aurora),
    ],
  ),
  // Bought in the shop (models/shop_scenes.dart).
  dunes(
    'Glass Dunes',
    'dust',
    near: HomeRow(SceneLayer.layer4, 0.80, 100),
    far: HomeRow(SceneLayer.layer3, 0.63, 70),
    mid: HomeRow(SceneLayer.layer3, 0.715, 85),
    moods: [
      HomeMood('clear', 'CLEAR'),
      HomeMood('sandstorm', 'SANDSTORM', weather: WeatherKind.sandstorm),
      HomeMood('glass', 'GLASS', aftermath: true),
    ],
  ),
  // Bought in the shop (models/shop_scenes.dart).
  geode(
    'Geode Hollow',
    'crystal',
    near: HomeRow(SceneLayer.layer4, 0.80, 100),
    far: HomeRow(SceneLayer.layer3, 0.63, 70),
    mid: HomeRow(SceneLayer.layer3, 0.715, 85),
    moods: [
      HomeMood('clear', 'CLEAR'),
      HomeMood('frostfall', 'FROSTFALL', weather: WeatherKind.frostfall),
      HomeMood('singing', 'SINGING', weather: WeatherKind.singing),
      HomeMood('rime', 'RIME', aftermath: true),
    ],
  ),
  // Bought in the shop (models/shop_scenes.dart).
  tidal(
    'Tidal Shelf',
    'water',
    near: HomeRow(SceneLayer.layer4, 0.80, 100),
    far: HomeRow(SceneLayer.layer3, 0.62, 70),
    mid: HomeRow(SceneLayer.layer3, 0.71, 85),
    moods: [
      HomeMood('clear', 'CLEAR'),
      HomeMood('fog', 'FOG', weather: WeatherKind.fog),
      HomeMood('swell', 'SWELL', weather: WeatherKind.swell),
      HomeMood('shells', 'SHELLS', aftermath: true),
    ],
  ),
  // Bought in the shop, for a home only — never in the wild
  // (models/shop_scenes.dart). A floor of sand in colors the player picks
  // (games/wilderness/field/home_sand_field.dart): no weather, no hour.
  sand(
    'Living Sands',
    'dust',
    near: HomeRow(SceneLayer.layer4, 0.80, 100),
    far: HomeRow(SceneLayer.layer3, 0.55, 70),
    mid: HomeRow(SceneLayer.layer3, 0.675, 85),
    moods: [HomeMood('clear', 'CLEAR')],
  ),

  // Found, never bought: the inside of the player's own planet, opened by
  // the Core Shards buried under the five first realms
  // (models/home_secrets.dart; games/wilderness/field/home_core_field.dart).
  // Particles on the dark; no weather and no hour, only its heart, still or
  // beating.
  core(
    'Core',
    'dark',
    near: HomeRow(SceneLayer.layer4, 0.80, 100),
    far: HomeRow(SceneLayer.layer3, 0.58, 70),
    mid: HomeRow(SceneLayer.layer3, 0.69, 85),
    moods: [
      HomeMood('still', 'STILL', stage: kCoreStill),
      HomeMood('beating', 'BEATING', stage: kCoreBeating),
    ],
  );

  const HomeRealm(
    this.title,
    this.portalElement, {
    required this.near,
    required this.mid,
    required this.far,
    required this.moods,
  });

  final String title;

  /// The element whose portal twist the descent borrows — the same one the
  /// wild map's entry into this realm uses.
  final String portalElement;

  final HomeRow near, mid, far;
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
    HomeRealm.dunes => dunesScene,
    HomeRealm.geode => geodeScene,
    HomeRealm.tidal => tidalScene,
    HomeRealm.sand => homeSandScene(),
    HomeRealm.core => homeCoreScene(),
  };

  /// Whether a Core Shard is buried under this realm (all but the Core).
  bool get buries => this != HomeRealm.core;

  /// Realms with no weather and no hour of their own.
  bool get timeless => this == HomeRealm.sand || this == HomeRealm.core;

  HomeRow row(HomeDepth depth) => switch (depth) {
    HomeDepth.front => near,
    HomeDepth.mid => mid,
    HomeDepth.back => far,
  };

  HomeMood mood(String? id) {
    if (id != null && id.startsWith('form:')) {
      final e = id.substring(5);
      if (kHomeForms.contains(e)) return HomeMood.formOf(e);
    }
    return moods.where((m) => m.id == id).firstOrNull ?? moods.first;
  }

  /// How far [layer] runs before it repeats, in its own units.
  double period(SceneLayer layer) {
    final scene = wildScene;
    final pf = scene.layers
        .firstWhere((l) => l.id == layer, orElse: () => scene.layers.first)
        .parallaxFactor;
    return scene.worldWidth * (1 + pf);
  }

  /// The pieces of this realm's own scenery the player can place.
  List<HomeScenery> get scenery => switch (this) {
    HomeRealm.sand || HomeRealm.core => const [],
    HomeRealm.valley => const [
      HomeScenery(FieldPiece.tree, 'GREAT TREE', w: 100, h: 100, half: 120),
      HomeScenery(
        FieldPiece.boulder,
        'BOULDER',
        w: 84,
        h: 48,
        half: 52,
        solid: true,
      ),
    ],
    HomeRealm.sky => const [
      HomeScenery(
        FieldPiece.isle,
        'ISLE',
        w: 56,
        h: 56,
        half: 1.08,
        solid: true,
        rises: true,
        farW: 36,
        y: 0.40,
        farY: 0.32,
      ),
      HomeScenery(
        FieldPiece.grove,
        'GROVE ISLE',
        w: 80,
        h: 80,
        half: 1.08,
        solid: true,
        rises: true,
        farW: 38,
        y: 0.47,
        farY: 0.33,
      ),
      HomeScenery(
        FieldPiece.falls,
        'FALLS ISLE',
        w: 64,
        h: 64,
        half: 1.08,
        solid: true,
        rises: true,
        farW: 34,
        y: 0.62,
        farY: 0.5,
      ),
    ],
    HomeRealm.swamp => const [
      HomeScenery(FieldPiece.cypress, 'CYPRESS', w: 100, h: 100, half: 90),
      HomeScenery(
        FieldPiece.stone,
        'STONE',
        w: 50,
        h: 50,
        half: 1.15,
        solid: true,
        farW: 30,
        y: 0.775,
        farY: 0.65,
      ),
      HomeScenery(
        FieldPiece.peat,
        'PEAT BANK',
        w: 56,
        h: 56,
        half: 1.1,
        solid: true,
        farW: 34,
        y: 0.775,
        farY: 0.655,
      ),
    ],
    HomeRealm.volcano => const [
      HomeScenery(
        FieldPiece.snag,
        'DEAD TREE',
        w: 42,
        h: 54,
        half: 1.1,
        solid: true,
        y: 0.796,
        far: false,
      ),
      HomeScenery(
        FieldPiece.spire,
        'SPIRE',
        w: 17,
        h: 46,
        half: 1.6,
        solid: true,
        farW: 13,
        farH: 38,
        y: 0.88,
        farY: 0.702,
      ),
    ],
    HomeRealm.arcane => const [
      HomeScenery(
        FieldPiece.monolith,
        'STANDING STONE',
        w: 30,
        h: 150,
        half: 0.6,
        farW: 12,
        farH: 64,
        y: 0.86,
        farY: 0.62,
      ),
    ],
    HomeRealm.dunes => const [
      HomeScenery(
        FieldPiece.pillar,
        'PILLAR',
        w: 30,
        h: 128,
        half: 1.2,
        solid: true,
        farW: 17,
        farH: 76,
      ),
      HomeScenery(
        FieldPiece.arch,
        'ARCH',
        w: 150,
        h: 128,
        half: 0.52,
        solid: true,
        farW: 120,
        farH: 104,
      ),
      HomeScenery(
        FieldPiece.outcrop,
        'ROCK',
        w: 70,
        h: 40,
        half: 0.55,
        solid: true,
        far: false,
      ),
    ],
    HomeRealm.geode => const [
      HomeScenery(
        FieldPiece.cluster,
        'CRYSTALS',
        w: 90,
        h: 110,
        half: 0.6,
        farW: 50,
        farH: 55,
      ),
      HomeScenery(
        FieldPiece.column,
        'ICE COLUMN',
        w: 26,
        h: 150,
        half: 1.3,
        solid: true,
        far: false,
      ),
      HomeScenery(
        FieldPiece.tarn,
        'POOL',
        w: 150,
        h: 30,
        half: 1.08,
        solid: true,
        far: false,
      ),
      HomeScenery(
        FieldPiece.geode,
        'SPLIT GEODE',
        w: 90,
        h: 56,
        half: 0.55,
        solid: true,
        far: false,
      ),
    ],
    HomeRealm.tidal => const [
      HomeScenery(
        FieldPiece.basalt,
        'ROCK',
        w: 50,
        h: 60,
        half: 2.4,
        solid: true,
        farW: 30,
        farH: 44,
      ),
    ],
  };

  HomeScenery? sceneryOf(String piece) =>
      scenery.where((s) => s.piece == piece).firstOrNull;

  /// The realm's own scenery where its wild field has it: what a home
  /// biome starts with, before the player has moved any of it.
  List<HomePiece> get defaultPieces {
    final nearP = period(near.layer);
    var n = 0;
    HomePiece piece(
      String kind,
      double x, {
      bool back = false,
      double? y,
      double scale = 1,
    }) => HomePiece(
      id: '${name}_${kind}_${n++}',
      kind: kind,
      depth: back ? HomeDepth.back : HomeDepth.front,
      x: x % 1.0,
      y: y,
      scale: double.parse(scale.toStringAsFixed(3)),
    );

    final s = sceneryOf;
    return switch (this) {
      HomeRealm.sand || HomeRealm.core => [],
      HomeRealm.valley => [
        for (final (x, k) in ValleyField.homeTrees(nearP))
          piece(FieldPiece.tree, x, scale: k),
      ],
      HomeRealm.sky => [
        for (final (fx, fy, hw, tree, fall) in SkyField.nearScenery)
          piece(
            tree
                ? FieldPiece.grove
                : (fall != 0 ? FieldPiece.falls : FieldPiece.isle),
            fx,
            y: fy,
            scale:
                hw /
                s(
                  tree
                      ? FieldPiece.grove
                      : (fall != 0 ? FieldPiece.falls : FieldPiece.isle),
                )!.w,
          ),
        for (final (fx, fy, hw, tree, _) in SkyField.midScenery)
          piece(
            tree ? FieldPiece.grove : FieldPiece.isle,
            fx,
            back: true,
            y: fy,
            scale: hw / s(tree ? FieldPiece.grove : FieldPiece.isle)!.farW!,
          ),
      ],
      HomeRealm.swamp => [
        for (final (x, k) in SwampField.homeCypresses(nearP))
          piece(FieldPiece.cypress, x, scale: k),
        for (final (fx, fy, hw, stone) in SwampField.midScenery)
          piece(
            stone ? FieldPiece.stone : FieldPiece.peat,
            fx,
            back: true,
            y: fy,
            scale: hw / s(stone ? FieldPiece.stone : FieldPiece.peat)!.farW!,
          ),
      ],
      HomeRealm.volcano => [
        for (final (fx, fy, hw) in VolcanoField.treeRocks)
          piece(FieldPiece.snag, fx, y: fy, scale: hw / 42),
        for (final (fx, _, h, seed) in VolcanoField.nearSpires)
          piece(FieldPiece.spire, fx, y: 0.86 + 0.006 * seed, scale: h / 46),
        for (final (fx, _, h, seed) in VolcanoField.midSpires)
          piece(
            FieldPiece.spire,
            fx,
            back: true,
            y: 0.69 + 0.004 * seed,
            scale: h / 38,
          ),
      ],
      HomeRealm.arcane => [
        for (final (fx, fy, _, h) in ArcaneField.nearStones)
          piece(FieldPiece.monolith, fx, y: fy, scale: h / 150),
        for (final (fx, fy, _, h) in ArcaneField.midStones)
          piece(FieldPiece.monolith, fx, back: true, y: fy, scale: h / 64),
      ],
      HomeRealm.dunes => [
        for (final (back, kind, fx, w, _) in DunesField.homeRuins)
          piece(
            kind,
            fx,
            back: back,
            scale: w / s(kind)!.width(back: back),
          ),
        for (final (fx, w, _) in DunesField.homeRocks)
          piece(FieldPiece.outcrop, fx, scale: w / s(FieldPiece.outcrop)!.w),
      ],
      HomeRealm.geode => [
        for (final (back, kind, fx, w, h) in GeodeField.homeScenery)
          piece(
            kind,
            fx,
            back: back,
            scale: kind == FieldPiece.tarn
                ? w / s(kind)!.w
                : h / s(kind)!.height(back: back),
          ),
      ],
      HomeRealm.tidal => [
        for (final (back, fx, _, h) in TidalField.homeBasalt)
          piece(
            FieldPiece.basalt,
            fx,
            back: back,
            scale: h / s(FieldPiece.basalt)!.height(back: back),
          ),
      ],
    };
  }

  static HomeRealm byName(String? name) =>
      HomeRealm.values.where((r) => r.name == name).firstOrNull ??
      HomeRealm.valley;

  /// The realms a home can be made in: the Arcane only once its portal has
  /// been opened in the wild ([arcane]), as the wild map shows it.
  /// Whether the Arcane may be a home: its portal opened in the wild, or
  /// the developer tools on (which open everything here).
  static Future<bool> arcaneOpen(SettingsDao settings) async =>
      await homeDebugOn() || await settings.isArcanePortalUnlocked();

  /// The realms a home can be made in: the Arcane only once its portal is
  /// open ([arcane]), a realm the shop sells only once [bought], and the
  /// Core only once it is found ([core]).
  static List<HomeRealm> open({
    required bool arcane,
    Set<String> bought = const {},
    bool core = false,
  }) => [
    for (final r in values)
      if ((r != HomeRealm.arcane || arcane) &&
          (r != HomeRealm.core || core) &&
          (shopSceneOf(r.sceneId) == null || bought.contains(r.sceneId)))
        r,
  ];

  /// The realms a home can be made in now, read from [settings] (the
  /// developer tools open everything here).
  static Future<List<HomeRealm>> openNow(SettingsDao settings) async {
    final debug = await homeDebugOn();
    return open(
      arcane: await arcaneOpen(settings),
      bought: debug
          ? {for (final s in kShopScenes) s.sceneId}
          : await ownedShopScenes(settings),
      core: debug || coreOpens(await HomeSecrets.load(settings)),
    );
  }
}

/// One of the player's Alchemons living in the home biome, and where.
class HomeResident {
  const HomeResident({
    required this.instanceId,
    this.depth = HomeDepth.front,
    this.x = 0,
    this.lift,
    this.flip = false,
    this.beside,
    this.since,
  });

  final String instanceId;

  /// When it settled where it stands (ms since the epoch): the ground there
  /// takes on its element the longer it stays (see [homeMarkStrength]).
  /// Null until the home first sees it.
  final int? since;

  /// The point it stands beside, sharing that one's ground (see
  /// [SpawnPoint.beside]); null for its own.
  final String? beside;

  /// Which row it stands on: the near one, the far one (the Valley's
  /// hills), or the one between.
  final HomeDepth depth;

  /// Where along its row, as a share of the row's loop.
  final double x;

  /// For one that can float, held in the air: its middle's height as a
  /// share of the field's height. Null when it stands.
  final double? lift;

  /// Facing the other way.
  final bool flip;

  String get spawnId => 'HOME_$instanceId';

  HomeResident copyWith({
    HomeDepth? depth,
    double? x,
    double? Function()? lift,
    bool? flip,
    String? Function()? beside,
    int? Function()? since,
  }) => HomeResident(
    instanceId: instanceId,
    depth: depth ?? this.depth,
    x: x ?? this.x,
    lift: lift != null ? lift() : this.lift,
    flip: flip ?? this.flip,
    beside: beside != null ? beside() : this.beside,
    since: since != null ? since() : this.since,
  );

  Map<String, dynamic> toJson() => {
    'id': instanceId,
    ...depth.toJson(),
    'x': double.parse(x.toStringAsFixed(4)),
    if (lift != null) 'lift': double.parse(lift!.toStringAsFixed(4)),
    if (flip) 'flip': true,
    if (beside != null) 'beside': beside,
    if (since != null) 'since': since,
  };

  static HomeResident? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final x = json['x'];
    final lift = json['lift'];
    return HomeResident(
      instanceId: id,
      depth: HomeDepth.fromJson(json),
      x: x is num ? (x.toDouble() % 1.0) : 0,
      lift: lift is num ? lift.toDouble().clamp(0.1, 0.92) : null,
      flip: json['flip'] == true,
      beside: json['beside'] is String ? json['beside'] as String : null,
      since: json['since'] is num ? (json['since'] as num).toInt() : null,
    );
  }
}

// ── Marks ──────────────────────────────────────────────────────────────────

const int _dayMs = 86400000;

/// How far the ground where a resident has lived since [since] has taken
/// on its element at [now] (both ms since the epoch): nothing the first
/// hours, full after about a week.
double homeMarkStrength(int since, int now) {
  final days = (now - since) / _dayMs;
  if (days <= 0.1) return 0;
  if (days >= 6) return 1;
  final t = (days - 0.1) / 5.9;
  return t * t * (3 - 2 * t);
}

// ── Forms ──────────────────────────────────────────────────────────────────

/// The forms the realms can take, each realm its own way: one for each
/// division's elements (as the harvest biomes group them), and Dark, Light
/// and Blood on their own.
const List<String> kHomeForms = [
  'Volcanic',
  'Oceanic',
  'Earthen',
  'Verdant',
  'Dark',
  'Light',
  'Blood',
];

/// The form an Alchemon of [element] brings a realm toward, or null
/// (Spirit has none).
String? homeFormOfElement(String? element) => switch (element) {
  'Fire' || 'Lava' || 'Lightning' => 'Volcanic',
  'Water' || 'Ice' || 'Steam' => 'Oceanic',
  'Earth' || 'Mud' || 'Dust' || 'Crystal' => 'Earthen',
  'Air' || 'Plant' || 'Poison' => 'Verdant',
  'Dark' => 'Dark',
  'Light' => 'Light',
  'Blood' => 'Blood',
  _ => null,
};

/// A realm filled with Alchemons of one form's elements — every place
/// taken by one — since [since] (ms since the epoch). [element] is the
/// form ('Volcanic', 'Dark'…). The land takes it at once, and after a week
/// turns into its form.
class HomeHold {
  const HomeHold(this.element, this.since);
  final String element;
  final int since;

  List<Object> toJson() => [element, since];

  static HomeHold? fromJson(Object? json) {
    if (json is! List || json.length != 2) return null;
    final e = json[0], t = json[1];
    if (e is! String || t is! num) return null;
    return HomeHold(e, t.toInt());
  }
}

/// How far a realm held since [since] has turned into its form at [now]:
/// nothing for six days, then over the seventh.
double homeFormDeep(int since, int now) {
  final days = (now - since) / _dayMs;
  if (days <= 6) return 0;
  if (days >= 7) return 1;
  final t = days - 6;
  return t * t * (3 - 2 * t);
}

/// The element [layout]'s realm has taken and how far into its form it is
/// at [now]: a form chosen as its mood (earned), fully; else the element
/// it is held by, turning over its week — or at once with [full] (the
/// developer tools). Nothing when neither.
(String?, double) homeFormOf(
  HomeBiomeLayout layout,
  int now, {
  bool full = false,
}) {
  final chosen = layout.mood.form;
  if (chosen != null) return (chosen, 1);
  final h = layout.hold;
  if (h == null) return (null, 0);
  return (h.element, full ? 1 : homeFormDeep(h.since, now));
}

/// How many arrangements of each realm can be kept.
const int kHomeArrangementSlots = 3;

/// One arrangement of a realm, kept to come back to: who lives there and
/// where, what stands there, and its mood.
class HomeArrangement {
  const HomeArrangement({
    this.residents = const [],
    this.pieces = const [],
    this.mood,
  });

  final List<HomeResident> residents;
  final List<HomePiece> pieces;
  final String? mood;

  Map<String, dynamic> toJson() => {
    'residents': [for (final r in residents) r.toJson()],
    'pieces': [for (final p in pieces) p.toJson()],
    if (mood != null) 'mood': mood,
  };

  static HomeArrangement? fromJson(Object? json) {
    if (json is! Map) return null;
    final rs = json['residents'], ps = json['pieces'];
    return HomeArrangement(
      residents: rs is List
          ? [
              for (final r in rs.map(HomeResident.fromJson))
                if (r != null) r,
            ].take(kHomeBiomeMaxResidents).toList()
          : const [],
      pieces: ps is List
          ? [
              for (final p in ps.map(HomePiece.fromJson))
                if (p != null) p,
            ]
          : const [],
      mood: json['mood'] is String ? json['mood'] as String : null,
    );
  }
}

/// A view of a realm the player framed: where along the field the camera
/// is (a share of its width) and how far it is zoomed. Friends and the
/// home screen's window open on it.
class HomeFrame {
  const HomeFrame(this.x, this.zoom);
  final double x, zoom;

  List<double> toJson() => [
    double.parse(x.toStringAsFixed(4)),
    double.parse(zoom.toStringAsFixed(3)),
  ];

  static HomeFrame? fromJson(Object? json) {
    if (json is! List || json.length != 2) return null;
    final x = json[0], z = json[1];
    if (x is! num || z is! num) return null;
    return HomeFrame(x.toDouble() % 1.0, z.toDouble().clamp(0.4, 2.0));
  }
}

/// How long a mark takes to fade once its resident has gone.
const int kHomeMarkFadeMs = 2 * _dayMs;

/// What a resident left on the ground where it lived, fading since it
/// moved or left.
class HomeMark {
  const HomeMark({
    required this.realm,
    required this.depth,
    required this.x,
    required this.element,
    required this.strength,
    required this.left,
  });

  /// The realm (by name), row and place along it (a share of its loop).
  final String realm;
  final HomeDepth depth;
  final double x;

  /// The element it took on (Title case, as a species' type).
  final String element;

  /// How strong it was when it was left, and when (ms since the epoch).
  final double strength;
  final int left;

  /// How much of it shows at [now].
  double strengthAt(int now) {
    final f = (now - left) / kHomeMarkFadeMs;
    if (f >= 1) return 0;
    return strength * (1 - f.clamp(0.0, 1.0));
  }

  Map<String, dynamic> toJson() => {
    'realm': realm,
    ...depth.toJson(),
    'x': double.parse(x.toStringAsFixed(4)),
    'element': element,
    's': double.parse(strength.toStringAsFixed(3)),
    'left': left,
  };

  static HomeMark? fromJson(Object? json) {
    if (json is! Map) return null;
    final realm = json['realm'], element = json['element'];
    final x = json['x'], st = json['s'], left = json['left'];
    if (realm is! String || element is! String) return null;
    if (x is! num || st is! num || left is! num) return null;
    return HomeMark(
      realm: realm,
      depth: HomeDepth.fromJson(json),
      x: x.toDouble() % 1.0,
      element: element,
      strength: st.toDouble().clamp(0.0, 1.0),
      left: left.toInt(),
    );
  }
}

/// A piece of a realm's own scenery the player can place (see
/// [FieldPiece]), as the realm draws it at scale 1.
class HomeScenery {
  const HomeScenery(
    this.piece,
    this.label, {
    required this.w,
    required this.h,
    required this.half,
    this.solid = false,
    this.rises = false,
    this.far = true,
    this.farW,
    this.farH,
    this.y,
    this.farY,
  });

  /// The field's name for it ([FieldPiece]).
  final String piece;
  final String label;

  /// Its size on the near row at scale 1, in the field's reference units —
  /// what its point's size means is the piece's own (see [FieldPiece]).
  final double w, h;

  /// How far to either side of its point it reaches along its row: in
  /// units when over 2, else as a multiple of its width.
  final double half;

  /// Whether it is ground in its own right (an isle, a bank, a rock), which
  /// must not overlap anything else that stands — a tree's crown may hang
  /// over anyone.
  final bool solid;

  /// Whether it can be set at any height (the Sky's isles).
  final bool rises;

  /// Whether it can stand on the far row, and its size there.
  final bool far;
  final double? farW, farH;

  /// Where its point sits on each row, as a share of the height: its top,
  /// its foot, where feet stand on it (see [FieldPiece]); null for a piece
  /// that is seated by the ground under it.
  final double? y, farY;

  double width({required bool back}) => back ? (farW ?? w * 0.62) : w;
  double height({required bool back}) => back ? (farH ?? h * 0.62) : h;

  /// Its reach to either side of its point at [scale], in layer units.
  double reach({required bool back, double scale = 1}) =>
      (half > 2 ? half * (back ? 0.62 : 1) : half * width(back: back)) * scale;

  /// The sizes the player can choose between.
  static const scales = [0.7, 0.85, 1.0, 1.2, 1.45];
}

/// A piece the player has placed: one of the realm's own pieces of
/// scenery, or a keepsake ([Keepsake]).
class HomePiece {
  const HomePiece({
    required this.id,
    required this.kind,
    this.depth = HomeDepth.front,
    this.x = 0,
    this.y,
    this.scale = 1,
    this.flip = false,
    this.beside,
    this.style = 0,
  });

  /// The point it stands beside, sharing that one's ground (a keepsake
  /// put down by a resident); null for its own.
  final String? beside;

  /// Which of its looks it has (see [HomeDecor.styles]).
  final int style;

  /// The decor it is, if it is bought decor rather than a keepsake.
  HomeDecor? get decor => HomeDecor.byId(kind);

  /// Stood in to be tried before it is bought: never saved.
  bool get trial => id.startsWith('try:');

  /// Hanging in the air (the sky lanterns) rather than on the ground.
  bool get hangs => decor?.aloft ?? false;

  /// Its own name in the layout, which also seeds its shape.
  final String id;

  /// The scenery's [FieldPiece], or the keepsake's id.
  final String kind;

  /// Which row it stands on. Scenery stands only on the near row or the
  /// far one: the fields draw it at those two sizes.
  final HomeDepth depth;

  /// On the far row.
  bool get back => depth == HomeDepth.back;

  /// Where along its row, as a share of the row's loop.
  final double x;

  /// For a piece that can be set at any height, where (see
  /// [HomeScenery.y]); null for where its kind sits.
  final double? y;

  /// How big, against its kind's own size.
  final double scale;

  /// Facing the other way (a keepsake).
  final bool flip;

  String get spawnId => 'PIECE_$id';

  bool get isKeepsake => !_sceneryKinds.contains(kind);

  static const _sceneryKinds = {
    FieldPiece.tree,
    FieldPiece.boulder,
    FieldPiece.isle,
    FieldPiece.grove,
    FieldPiece.falls,
    FieldPiece.cypress,
    FieldPiece.stone,
    FieldPiece.peat,
    FieldPiece.snag,
    FieldPiece.spire,
    FieldPiece.monolith,
    FieldPiece.pillar,
    FieldPiece.arch,
    FieldPiece.outcrop,
    FieldPiece.cluster,
    FieldPiece.column,
    FieldPiece.geode,
    FieldPiece.tarn,
    FieldPiece.basalt,
  };

  HomePiece copyWith({
    HomeDepth? depth,
    double? x,
    double? Function()? y,
    double? scale,
    bool? flip,
    String? Function()? beside,
    int? style,
    String? id,
  }) => HomePiece(
    id: id ?? this.id,
    kind: kind,
    style: style ?? this.style,
    depth: depth ?? this.depth,
    x: x ?? this.x,
    y: y != null ? y() : this.y,
    scale: scale ?? this.scale,
    flip: flip ?? this.flip,
    beside: beside != null ? beside() : this.beside,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    ...depth.toJson(),
    'x': double.parse(x.toStringAsFixed(4)),
    if (y != null) 'y': double.parse(y!.toStringAsFixed(4)),
    if (scale != 1) 'scale': scale,
    if (flip) 'flip': true,
    if (beside != null) 'beside': beside,
    if (style != 0) 'style': style,
  };

  static HomePiece? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], kind = json['kind'];
    if (id is! String || id.isEmpty || kind is! String || kind.isEmpty) {
      return null;
    }
    final x = json['x'], y = json['y'], scale = json['scale'];
    var depth = HomeDepth.fromJson(json);
    // Scenery has no middle row.
    if (depth == HomeDepth.mid && _sceneryKinds.contains(kind)) {
      depth = HomeDepth.front;
    }
    return HomePiece(
      id: id,
      kind: kind,
      depth: depth,
      x: x is num ? x.toDouble() % 1.0 : 0,
      y: y is num ? y.toDouble().clamp(0.1, 0.95) : null,
      scale: scale is num ? scale.toDouble().clamp(0.5, 1.6) : 1,
      flip: json['flip'] == true,
      beside: json['beside'] is String ? json['beside'] as String : null,
      style: json['style'] is int ? json['style'] as int : 0,
    );
  }
}

/// How something let go came to stand where it does (see
/// [HomeBiomeLayout.dropResident]).
enum HomeLanding {
  /// Where it was let go, or as near as makes no difference.
  asked,

  /// Beside what it was let go by, sharing its ground.
  beside,

  /// Further along its row: there was no room where it was let go.
  along,

  /// On another row: there was no room near there on its own.
  otherRow,
}

/// Where something let go stands — its row, and where along it — and the
/// layout with it there.
class HomeDrop {
  const HomeDrop(this.layout, this.depth, this.x, this.how);

  final HomeBiomeLayout layout;
  final HomeDepth depth;
  final double x;
  final HomeLanding how;
}

/// How many pieces of scenery one realm can hold.
const int kHomeBiomeMaxScenery = 18;

/// The whole home biome as the player has made it.
class HomeBiomeLayout {
  const HomeBiomeLayout({
    this.realm = HomeRealm.valley,
    this.sandStyle = const HomeSandStyle(),
    this.moods = const {},
    this.hour,
    this.residents = const [],
    Map<String, List<HomeResident>> households = const {},
    this.pieces = const {},
    this.seen = const {},
    this.sky = const HomeSky(),
    this.marks = const [],
    this.arrangements = const {},
    this.frames = const {},
    this.holds = const {},
  }) : _households = households;

  final HomeRealm realm;
  final HomeSandStyle sandStyle;

  /// What the sky shows — the season, the planet, the constellations — and
  /// whether the camera drifts when left alone. The same over every realm.
  final HomeSky sky;

  /// The marks residents left where they lived, fading (see [HomeMark]).
  final List<HomeMark> marks;

  /// Arrangements kept of each realm, by realm name: [kHomeArrangementSlots]
  /// places, null where none is kept.
  final Map<String, List<HomeArrangement?>> arrangements;

  /// The view framed of each realm, by realm name.
  final Map<String, HomeFrame> frames;

  /// The realms filled with one element, by realm name (see [HomeHold]).
  final Map<String, HomeHold> holds;

  /// The current realm's hold, if it is held.
  HomeHold? get hold => holds[realm.name];

  /// The current realm's kept arrangements, one per place.
  List<HomeArrangement?> get arrangementsHere {
    final kept = arrangements[realm.name] ?? const [];
    return [
      for (var i = 0; i < kHomeArrangementSlots; i++)
        i < kept.length ? kept[i] : null,
    ];
  }

  /// The current realm as it stands, kept in place [slot].
  HomeBiomeLayout keepArrangement(int slot) {
    final here = [...arrangementsHere];
    here[slot] = HomeArrangement(
      residents: [for (final r in residents) r.copyWith(since: () => null)],
      pieces: [
        for (final p in placed)
          if (!p.trial) p,
      ],
      mood: moods[realm.name],
    );
    return copyWith(arrangements: {...arrangements, realm.name: here});
  }

  /// The current realm as it was kept in place [slot] (unchanged if none
  /// is kept there).
  HomeBiomeLayout takeArrangement(int slot) {
    final a = arrangementsHere[slot];
    if (a == null) return this;
    return copyWith(
      residents: a.residents,
      moods: {
        ...moods,
        if (a.mood != null) realm.name: a.mood!,
      },
    ).withPlaced(a.pieces);
  }

  /// The view framed of the current realm, if one is.
  HomeFrame? get frame => frames[realm.name];

  /// The mood picked for each realm, by realm name — each keeps its own, so
  /// going back to the Valley finds its rain still falling.
  final Map<String, String> moods;

  /// The hour the field is held at, 0–24; null follows the phone's clock.
  final double? hour;

  /// Who lives in the current realm. Each realm keeps its own household,
  /// as it keeps its own scenery: they used to be one list that every realm
  /// shared, so arranging the Swamp rearranged the Valley.
  final List<HomeResident> residents;

  /// The other realms' households, by realm name. Its entry for the
  /// current realm, if any, is stale: [residents] is that one.
  final Map<String, List<HomeResident>> _households;

  /// Who lives in each realm, by realm name, the current one included.
  Map<String, List<HomeResident>> get households => {
    for (final e in _households.entries)
      if (e.key != realm.name && e.value.isNotEmpty) e.key: e.value,
    if (residents.isNotEmpty) realm.name: residents,
  };

  /// What the player has placed in each realm, by realm name: its own
  /// scenery and their keepsakes. A realm with no entry stands as its wild
  /// field has it ([HomeRealm.defaultPieces]).
  final Map<String, List<HomePiece>> pieces;

  /// The keepsakes the player has already been shown, by id — anything
  /// owned and not in here is new.
  final Set<String> seen;

  HomeMood get mood => realm.mood(moods[realm.name]);

  /// What stands in the current realm.
  List<HomePiece> get placed => pieces[realm.name] ?? realm.defaultPieces;

  /// The scenery of the current realm, and its keepsakes.
  Iterable<HomePiece> get scenery => placed.where((p) => !p.isKeepsake);
  Iterable<HomePiece> get keepsakes =>
      placed.where((p) => p.isKeepsake && p.decor == null);

  /// The bought decor standing in the current realm.
  Iterable<HomePiece> get decor => placed.where((p) => p.decor != null);

  /// How many of [kind] stand in the current realm, tried ones included.
  int placedOf(String kind) => placed.where((p) => p.kind == kind).length;

  /// A changed layout. A new [realm] brings its own household with it;
  /// [residents] are those of the realm the result is in.
  HomeBiomeLayout copyWith({
    HomeRealm? realm,
    HomeSandStyle? sandStyle,
    Map<String, String>? moods,
    double? Function()? hour,
    List<HomeResident>? residents,
    Map<String, List<HomePiece>>? pieces,
    Set<String>? seen,
    HomeSky? sky,
    List<HomeMark>? marks,
    Map<String, List<HomeArrangement?>>? arrangements,
    Map<String, HomeFrame>? frames,
    Map<String, HomeHold>? holds,
  }) {
    final to = realm ?? this.realm;
    final all = households;
    return HomeBiomeLayout(
      realm: to,
      sandStyle: sandStyle ?? this.sandStyle,
      moods: moods ?? this.moods,
      hour: hour != null ? hour() : this.hour,
      residents: residents ?? all[to.name] ?? const [],
      households: all,
      pieces: pieces ?? this.pieces,
      seen: seen ?? this.seen,
      sky: sky ?? this.sky,
      marks: marks ?? this.marks,
      arrangements: arrangements ?? this.arrangements,
      frames: frames ?? this.frames,
      holds: holds ?? this.holds,
    );
  }

  /// [this] after [before], with the ground's memory kept: whoever newly
  /// came to a spot (arrived, moved, or took off) settles there from [now],
  /// and the spot each one left keeps its mark, fading — [elementOf] says
  /// which element each one's is. Faded marks are let go.
  HomeBiomeLayout markedSince(
    HomeBiomeLayout before,
    int now,
    String? Function(String instanceId) elementOf,
  ) {
    // Each realm keeps its own household, and one Alchemon may live in
    // more than one: who is who is by realm and instance.
    final was = {
      for (final e in before.households.entries)
        for (final r in e.value) '${e.key}|${r.instanceId}': (e.key, r),
    };
    final left = <HomeMark>[];
    void leave(String realm, HomeResident r) {
      final since = r.since;
      final element = elementOf(r.instanceId);
      if (since == null || element == null || r.lift != null) return;
      final st = homeMarkStrength(since, now);
      if (st < 0.02) return;
      left.add(
        HomeMark(
          realm: realm,
          depth: r.depth,
          x: r.x,
          element: element,
          strength: st,
          left: now,
        ),
      );
    }

    final seenNow = <String>{};
    final houses = <String, List<HomeResident>>{};
    for (final e in households.entries) {
      houses[e.key] = [
        for (final r in e.value)
          () {
            final key = '${e.key}|${r.instanceId}';
            seenNow.add(key);
            final old = was[key]?.$2;
            if (old == null) return r.copyWith(since: () => r.since ?? now);
            var d = (r.x - old.x).abs();
            d = math.min(d, 1 - d);
            final moved =
                old.depth != r.depth ||
                d > 0.02 ||
                (old.lift == null) != (r.lift == null);
            if (!moved) return r.copyWith(since: () => old.since ?? now);
            leave(e.key, old);
            return r.copyWith(since: () => now);
          }(),
      ];
    }
    for (final e in was.entries) {
      if (!seenNow.contains(e.key)) leave(e.value.$1, e.value.$2);
    }
    final kept = [
      for (final m in [...marks, ...left])
        if (m.strengthAt(now) > 0.01) m,
    ];
    // A realm whose every place is one form's elements is held from when
    // it first was; a realm whose residents' elements are not all known here
    // is left as it was.
    final held = <String, HomeHold>{};
    for (final r in HomeRealm.values) {
      final house = houses[r.name] ?? const [];
      final elements = [for (final h in house) elementOf(h.instanceId)];
      if (elements.any((e) => e == null) && house.isNotEmpty) {
        if (holds[r.name] case final h?) held[r.name] = h;
        continue;
      }
      final full = house.length >= kHomeBiomeMaxResidents;
      final one = {for (final e in elements) homeFormOfElement(e)};
      if (!full || one.length != 1 || one.first == null) continue;
      final e = one.first!;
      final was = holds[r.name] ?? before.holds[r.name];
      held[r.name] = was != null && was.element == e ? was : HomeHold(e, now);
    }
    return HomeBiomeLayout(
      realm: realm,
      sandStyle: sandStyle,
      moods: moods,
      hour: hour,
      residents: houses[realm.name] ?? const [],
      households: houses,
      pieces: pieces,
      seen: seen,
      sky: sky,
      marks: kept.length > 24 ? kept.sublist(kept.length - 24) : kept,
      arrangements: arrangements,
      frames: frames,
      holds: held,
    );
  }

  /// The marks fading in the current realm.
  Iterable<HomeMark> get marksHere => marks.where((m) => m.realm == realm.name);

  HomeBiomeLayout withMood(String id) =>
      copyWith(moods: {...moods, realm.name: id});

  /// The current realm with [list] standing in it.
  HomeBiomeLayout withPlaced(List<HomePiece> list) =>
      copyWith(pieces: {...pieces, realm.name: list});

  /// Shelves earned keepsakes while preserving scenery and owned decor.
  HomeBiomeLayout putKeepsakesAway() {
    var out = withPlaced([
      for (final p in placed)
        if (!p.isKeepsake || p.decor != null) p,
    ]);
    for (final p in keepsakes) {
      out = out.freeBeside(p.spawnId);
    }
    return out;
  }

  /// Restores only the realm's scenery; furnishings stay in place.
  HomeBiomeLayout resetScenery() => withPlaced([
    ...realm.defaultPieces,
    for (final p in placed)
      if (p.isKeepsake) p,
  ]);

  /// Changes a piece's identity without detaching anything sharing its ground.
  HomeBiomeLayout renamePiece(HomePiece piece, String id) {
    final renamed = piece.copyWith(id: id);
    return copyWith(
      residents: [
        for (final r in residents)
          r.beside == piece.spawnId
              ? r.copyWith(beside: () => renamed.spawnId)
              : r,
      ],
    ).withPlaced([
      for (final p in placed)
        if (p.id == piece.id)
          renamed
        else if (p.beside == piece.spawnId)
          p.copyWith(beside: () => renamed.spawnId)
        else
          p,
    ]);
  }

  /// This layout in a realm that is [open] — the first of them when its own
  /// is not (an Arcane home before the Arcane is unlocked).
  HomeBiomeLayout within(List<HomeRealm> open) =>
      open.contains(realm) ? this : copyWith(realm: open.first);

  /// The layout as the player may have it now, whether the Arcane is
  /// unlocked read from [settings].
  static Future<HomeBiomeLayout> loadOpen(SettingsDao settings) async =>
      (await load(settings)).within(await HomeRealm.openNow(settings));

  HomeResident? resident(String spawnId) =>
      residents.where((r) => r.spawnId == spawnId).firstOrNull;

  HomePiece? piece(String spawnId) =>
      placed.where((p) => p.spawnId == spawnId).firstOrNull;

  HomeBiomeLayout replace(HomeResident r) => copyWith(
    residents: [
      for (final o in residents) o.instanceId == r.instanceId ? r : o,
    ],
  );

  HomeBiomeLayout replacePiece(HomePiece p) =>
      withPlaced([for (final o in placed) o.id == p.id ? p : o]);

  /// The scene the home biome shows: the realm's own field, its points the
  /// residents and what is placed. [floats] says which residents can be
  /// held in the air.
  SceneDefinition scene(bool Function(String instanceId) floats) =>
      (realm == HomeRealm.sand ? homeSandScene(sandStyle) : realm.wildScene)
          .copyWith(spawnPoints: spawnPoints(floats));

  List<SpawnPoint> spawnPoints(bool Function(String instanceId) floats) => [
    for (final r in residents) spawnPointFor(r, floats: floats(r.instanceId)),
    for (final p in placed)
      if (pieceSpawnPoint(p) case final sp?) sp,
  ];

  SpawnPoint spawnPointFor(HomeResident r, {required bool floats}) {
    final row = realm.row(r.depth);
    final aloft = floats && r.lift != null;
    return SpawnPoint(
      id: r.spawnId,
      normalizedPos: Offset(r.x, aloft ? r.lift! : row.height),
      anchor: row.layer,
      size: Vector2.all(row.size),
      perch: aloft ? SpawnPerch.air : SpawnPerch.ground,
      beside: aloft ? null : hostOf(r.spawnId, r.beside, depth: r.depth),
      depth: r.depth.index,
    );
  }

  /// [p]'s point: a keepsake stands where a creature would, given the same
  /// ground; scenery is the field's own piece, as big as it is. Null for
  /// scenery this realm does not have.
  SpawnPoint? pieceSpawnPoint(HomePiece p) {
    final row = realm.row(p.depth);
    if (p.isKeepsake) {
      final d = p.decor;
      // What hangs in the air is held there, on nothing.
      if (d != null && d.aloft) {
        return SpawnPoint(
          id: p.spawnId,
          normalizedPos: Offset(p.x, p.y ?? row.height - 0.3),
          anchor: row.layer,
          size: Vector2.all(row.size),
          perch: SpawnPerch.air,
          depth: p.depth.index,
        );
      }
      // A Wonder stands on ground as wide as it is — wide only: the fields
      // seat a point by its height, and its ground must be at everyone
      // else's level, so those who share it or bathe in it are on it.
      final wide = d?.wide ?? 1;
      return SpawnPoint(
        id: p.spawnId,
        normalizedPos: Offset(p.x, row.height),
        anchor: row.layer,
        size: Vector2(row.size * wide, row.size),
        beside: hostOf(p.spawnId, p.beside, depth: p.depth),
        depth: p.depth.index,
      );
    }
    final kind = realm.sceneryOf(p.kind);
    if (kind == null || !sceneryCanStand(kind, p.depth)) return null;
    return SpawnPoint(
      id: p.spawnId,
      normalizedPos: Offset(
        p.x,
        p.y ?? (p.back ? kind.farY : kind.y) ?? row.height,
      ),
      anchor: row.layer,
      size: Vector2(
        kind.width(back: p.back) * p.scale,
        kind.height(back: p.back) * p.scale,
      ),
      piece: p.kind,
      depth: p.depth.index,
    );
  }

  /// Whether scenery of [kind] can stand on [depth]'s row: the near one,
  /// or the far one where it has a far size. The fields draw it at only
  /// those two.
  static bool sceneryCanStand(HomeScenery kind, HomeDepth depth) =>
      switch (depth) {
        HomeDepth.front => true,
        HomeDepth.mid => false,
        HomeDepth.back => kind.far,
      };

  /// The rows [spawnId] can stand on: every one for a resident or a
  /// keepsake, the near and far for scenery.
  List<HomeDepth> depthsFor(String spawnId) {
    final p = piece(spawnId);
    final kind = p == null || p.isKeepsake ? null : realm.sceneryOf(p.kind);
    if (kind == null) return HomeDepth.values;
    return [
      for (final d in HomeDepth.values)
        if (sceneryCanStand(kind, d)) d,
    ];
  }

  // ── Room ─────────────────────────────────────────────────────────────────

  /// [host] if it is something that stands on its own ground on [depth]'s
  /// row (a resident not in the air, a keepsake) and does not itself stand
  /// beside another — what [id] may stand beside; null otherwise.
  String? hostOf(String id, String? host, {required HomeDepth depth}) {
    if (host == null || host == id) return null;
    final r = resident(host);
    if (r != null) {
      return r.depth == depth && r.lift == null && r.beside == null
          ? host
          : null;
    }
    final p = piece(host);
    if (p != null &&
        p.isKeepsake &&
        !p.hangs &&
        p.depth == depth &&
        p.beside == null) {
      return host;
    }
    return null;
  }

  /// Whether the scenery [p] of [kind] takes room on [depth]'s row. Only
  /// what is ground in its own right does, and only on its own row — but an
  /// isle set at a height takes room on whichever row of its layer has feet
  /// about that high, and on none if it is up in the sky: what stands below
  /// it is not in its way.
  bool _solidOn(HomePiece p, HomeScenery kind, HomeDepth depth) {
    if (!kind.solid) return false;
    if (!kind.rises) return p.depth == depth;
    final own = realm.row(p.depth), row = realm.row(depth);
    if (own.layer != row.layer) return false;
    final stand = p.y ?? (p.back ? kind.farY : kind.y) ?? own.height;
    return (stand - row.feet).abs() < 0.08;
  }

  /// Everything standing on [depth]'s row as (point id, place, reach either
  /// side, what it stands beside), in shares of the loop.
  List<(String, double, double, String?)> _standing(HomeDepth depth) {
    final row = realm.row(depth);
    final period = realm.period(row.layer);
    final creature = row.size * 0.95 / period;
    return [
      for (final o in residents)
        if (o.depth == depth && o.lift == null)
          (
            o.spawnId,
            o.x,
            creature,
            hostOf(o.spawnId, o.beside, depth: depth),
          ),
      for (final p in placed)
        if (p.isKeepsake) ...[
          if (p.depth == depth && !p.hangs)
            (
              p.spawnId,
              p.x,
              creature * (p.decor?.wide ?? 1),
              hostOf(p.spawnId, p.beside, depth: depth),
            ),
        ] else if (realm.sceneryOf(p.kind) case final k?
            when _solidOn(p, k, depth))
          (
            p.spawnId,
            p.x,
            k.reach(back: p.back, scale: p.scale) /
                realm.period(realm.row(p.depth).layer),
            null,
          ),
    ];
  }

  /// What takes up room along [depth]'s row, other than [except] and what
  /// stands beside it: each thing's middle and how far to either side it
  /// reaches, as shares of the loop — a pair sharing ground one stretch.
  /// What stands keeps clear of what stands; what flies of what flies
  /// ([aloft]) — a creature can hover over another's head, or over an
  /// isle. Scenery that is not ground (a tree's crown) takes no room, nor
  /// does anything on another row.
  List<(double, double)> _taken(
    HomeDepth depth, {
    required bool aloft,
    String? except,
    Set<String> also = const {},
  }) {
    if (aloft) {
      final reach = _reachOf(depth, aloft: true);
      return [
        for (final o in residents)
          if (o.spawnId != except && o.depth == depth && o.lift != null)
            (o.x, reach),
      ];
    }
    final all = _standing(depth);
    final out = <(double, double)>[];
    bool excluded(String id) => id == except || also.contains(id);
    for (final (id, x, reach, host) in all) {
      if (excluded(id) || host != null) continue;
      // The ground it shares with what stands beside it.
      var lo = -reach, hi = reach;
      for (final (sid, sx, sreach, shost) in all) {
        if (shost != id || excluded(sid)) continue;
        final d = _wrap(sx - x);
        lo = math.min(lo, d - sreach);
        hi = math.max(hi, d + sreach);
      }
      out.add((x + (lo + hi) / 2, (hi - lo) / 2));
    }
    return out;
  }

  static double _wrap(double d) => d - (d + 0.5).floorToDouble();

  /// How far to either side of it a resident on [depth]'s row reaches, as
  /// a share of the loop.
  double _reachOf(HomeDepth depth, {bool aloft = false}) {
    final row = realm.row(depth);
    return row.size * (aloft ? 0.6 : 0.95) / realm.period(row.layer);
  }

  /// How far apart two residents on one row must stand, as a share of the
  /// row's loop: room for each one's isle, bank or shelf — or, for two in
  /// the air ([aloft]), room for each one's wings.
  double gap(HomeDepth depth, {bool aloft = false}) =>
      2 * _reachOf(depth, aloft: aloft);

  bool _freeAt(double at, double reach, List<(double, double)> taken) =>
      taken.every((o) {
        final d = _wrap(at - o.$1).abs();
        return d >= reach + o.$2 - 1e-9;
      });

  /// The free place nearest [x] on [depth]'s row for something reaching
  /// [reach] to either side (a share of the loop), no further than
  /// [within] from it, or null if there is none.
  double? _freeNear(
    double x, {
    required HomeDepth depth,
    required bool aloft,
    required double reach,
    String? except,
    double? groupOrigin,
    double within = 0.5,
  }) {
    var lo = -reach, hi = reach;
    if (groupOrigin != null && !aloft) {
      for (final (_, x, memberReach, host) in _standing(depth)) {
        if (host != except || host == null) continue;
        final offset = _wrap(x - groupOrigin);
        lo = math.min(lo, offset - memberReach);
        hi = math.max(hi, offset + memberReach);
      }
    }
    final center = (lo + hi) / 2;
    final groupReach = (hi - lo) / 2;
    final taken = _taken(depth, aloft: aloft, except: except);
    final step = reach / 3;
    final tries = (math.min(within, 0.5) / step).ceil();
    for (var i = 0; i <= tries; i++) {
      for (final s in i == 0 ? const [1] : const [1, -1]) {
        final at = (x + s * i * step) % 1.0;
        if (_freeAt(at + center, groupReach, taken)) return at;
      }
    }
    return null;
  }

  /// Where [r] can stand nearest [x] on its row without crowding anything
  /// else there — no further than [within] from it — or null if there is
  /// no room.
  double? freeSpotNear(
    HomeResident r,
    double x, {
    bool movingGroup = false,
    double within = 0.5,
  }) {
    final aloft = r.lift != null;
    return _freeNear(
      x,
      depth: r.depth,
      aloft: aloft,
      reach: _reachOf(r.depth, aloft: aloft),
      except: r.spawnId,
      groupOrigin: movingGroup ? resident(r.spawnId)?.x : null,
      within: within,
    );
  }

  /// Where [p] can stand nearest [x] on its row — no further than [within]
  /// from it — or null if there is no room. Scenery that is not ground can
  /// stand anywhere it can stand at all.
  double? freeSpotForPiece(
    HomePiece p,
    double x, {
    bool movingGroup = false,
    double within = 0.5,
  }) {
    // What hangs in the air can hang anywhere.
    if (p.hangs) return x % 1.0;
    if (p.isKeepsake) {
      return _freeNear(
        x,
        depth: p.depth,
        aloft: false,
        reach: _reachOf(p.depth) * (p.decor?.wide ?? 1),
        except: p.spawnId,
        groupOrigin: movingGroup ? piece(p.spawnId)?.x : null,
        within: within,
      );
    }
    final k = realm.sceneryOf(p.kind);
    if (k == null || !sceneryCanStand(k, p.depth)) return null;
    // Scenery that takes room on no row (a tree, an isle up in the sky)
    // can stand anywhere.
    if (!HomeDepth.values.any((d) => _solidOn(p, k, d))) return x % 1.0;
    final period = realm.period(realm.row(p.depth).layer);
    final reach = k.reach(back: p.back, scale: p.scale) / period;
    // An isle at a height keeps clear of what stands on whichever row it
    // is in the way of.
    final rows = [
      for (final d in HomeDepth.values)
        if (_solidOn(p, k, d)) d,
    ];
    final step = reach / 3;
    final tries = (math.min(within, 0.5) / step).ceil();
    for (var i = 0; i <= tries; i++) {
      for (final s in i == 0 ? const [1] : const [1, -1]) {
        final at = (x + s * i * step) % 1.0;
        if (rows.every(
          (d) => _freeAt(
            at,
            reach,
            _taken(d, aloft: false, except: p.spawnId),
          ),
        )) {
          return at;
        }
      }
    }
    return null;
  }

  /// Something standing [id] put down at [x] on [depth]'s row close to
  /// what already stands there — something on its own ground (a resident
  /// on the ground, a keepsake) and whatever stands beside it — joins that
  /// group at its end on the side it was let go (or the other side, if
  /// that one is full or has no room), sharing its ground: what it would
  /// stand beside and where, or null to stand on its own.
  (String, double)? nestBeside(
    String id,
    double x, {
    required HomeDepth depth,
  }) {
    final row = realm.row(depth);
    final period = realm.period(row.layer);
    final size = row.size / period;
    final all = _standing(depth);
    // What already stands beside it moves with it; it cannot be put
    // beside one of its own.
    if (all.any((o) => o.$4 == id)) return null;
    final self = _besideWidth(id);
    final selfReach = size * 0.95 * (piece(id)?.decor?.wide ?? 1);
    (String, double)? best;
    var bestD = double.infinity;
    for (final (hid, hx, _, hhost) in all) {
      if (hid == id || hhost != null) continue;
      if (hostOf(id, hid, depth: depth) == null) continue;
      // The group: the host where it stands, what stands beside it either
      // side of it.
      final beside = [
        for (final (sid, sx, sreach, shost) in all)
          if (shost == hid && sid != id) (sid, _wrap(sx - hx), sreach),
      ];
      final d = _wrap(x - hx);
      // Let go within a size of one of them.
      var near = d.abs();
      for (final (_, off, _) in beside) {
        near = math.min(near, (d - off).abs());
      }
      if (near > size * 1.1 || near >= bestD) continue;
      final preferred = d >= 0 ? 1.0 : -1.0;
      for (final side in [preferred, -preferred]) {
        final onSide = [
          for (final m in beside)
            if (m.$2.sign == side) m,
        ];
        if (onSide.length >= kHomeBesidePerSide) continue;
        // Next to the one at that end, by both their widths.
        var end = (hid, 0.0);
        for (final (sid, off, _) in onSide) {
          if (off.abs() > end.$2.abs()) end = (sid, off);
        }
        final step = 0.39 * (_besideWidth(end.$1) + self) * size;
        final dn = end.$2 + side * step;
        // The group's ground, grown by it, must not run into anything else.
        var lo = -selfReach + dn, hi = selfReach + dn;
        final group = {id, hid};
        for (final (sid, sx, sreach, shost) in all) {
          if (sid != hid && shost != hid) continue;
          group.add(sid);
          if (sid == id) continue;
          final o = _wrap(sx - hx);
          lo = math.min(lo, o - sreach);
          hi = math.max(hi, o + sreach);
        }
        final rest = _taken(depth, aloft: false, also: group);
        if (!_freeAt((hx + (lo + hi) / 2) % 1.0, (hi - lo) / 2, rest)) {
          continue;
        }
        best = (hid, (hx + dn) % 1.0);
        bestD = near;
        break;
      }
    }
    return best;
  }

  /// [layout] with what stands beside [hostId] closed up to it on each
  /// side, in the order it stood — one gone from the middle of a group
  /// leaves no gap.
  HomeBiomeLayout packBeside(String hostId) {
    final hr = resident(hostId);
    final hp = hr == null ? piece(hostId) : null;
    final hx = hr?.x ?? hp?.x;
    if (hx == null) return this;
    final depth = hr?.depth ?? hp!.depth;
    final row = realm.row(depth);
    final size = row.size / realm.period(row.layer);
    final to = <String, double>{};
    for (final side in const [1.0, -1.0]) {
      final members = [
        for (final (sid, sx, _, shost) in _standing(depth))
          if (shost == hostId && _wrap(sx - hx).sign == side)
            (sid, _wrap(sx - hx).abs()),
      ]..sort((a, b) => a.$2.compareTo(b.$2));
      var end = hostId, at = 0.0;
      for (final (sid, _) in members) {
        at += 0.39 * (_besideWidth(end) + _besideWidth(sid)) * size;
        to[sid] = (hx + side * at) % 1.0;
        end = sid;
      }
    }
    if (to.isEmpty) return this;
    return copyWith(
      residents: [
        for (final r in residents)
          if (to[r.spawnId] case final x?) r.copyWith(x: x) else r,
      ],
    ).withPlaced([
      for (final p in placed)
        if (to[p.spawnId] case final x?) p.copyWith(x: x) else p,
    ]);
  }

  /// How wide [id] stands beside others, in creatures: a creature or a
  /// small keepsake one, a Wonder its own width and more (out at its edge,
  /// not in it).
  double _besideWidth(String id) {
    final wide = piece(id)?.decor?.wide ?? 1;
    return wide > 1 ? wide * 1.4 : 1;
  }

  /// [layout] with whatever stood beside [hostId] moved along by [by] (a
  /// share of the loop) — it goes where its host goes.
  HomeBiomeLayout carryBeside(String hostId, double by) =>
      copyWith(
        residents: [
          for (final r in residents)
            r.beside == hostId ? r.copyWith(x: (r.x + by) % 1.0) : r,
        ],
      ).withPlaced([
        for (final p in placed)
          p.beside == hostId ? p.copyWith(x: (p.x + by) % 1.0) : p,
      ]);

  /// [layout] with nothing standing beside [hostId] any more — it went to
  /// another row, or away.
  HomeBiomeLayout freeBeside(String hostId) =>
      copyWith(
        residents: [
          for (final r in residents)
            r.beside == hostId ? r.copyWith(beside: () => null) : r,
        ],
      ).withPlaced([
        for (final p in placed)
          p.beside == hostId ? p.copyWith(beside: () => null) : p,
      ]);

  // ── Letting go ───────────────────────────────────────────────────────────

  /// How near where it was let go something must stand to be where it was
  /// put, as a share of [depth]'s loop: within about a creature.
  double _nearby(HomeDepth depth) => _reachOf(depth) * 1.1;

  /// Where [r] stands when it is let go on [depth]'s row, [xAt] saying
  /// where along each row (a share of its loop) the finger let it go —
  /// rows on different layers pan at different speeds. In the air ([lift])
  /// it hovers there; on the ground, close by something it stands beside
  /// that ([nestBeside]), else as near as there is room. With no room near
  /// there, it goes to the same place on the nearest row that has room
  /// (unless it must [stay] on that row), and only then further along.
  /// Null when no row has room for it.
  HomeDrop? dropResident(
    HomeResident r,
    HomeDepth depth,
    double Function(HomeDepth depth) xAt, {
    double? lift,
    bool stay = false,
  }) {
    final aloft = lift != null;
    HomeBiomeLayout put(HomeDepth d, double x, String? host) {
      final moved = r.copyWith(
        depth: d,
        x: x,
        lift: () => lift,
        beside: () => host,
      );
      var out = replace(moved);
      // What stood beside it goes with it — or stays where it was, now on
      // its own, if it took to the air or went to another row.
      out = aloft || d != r.depth || r.lift != null
          ? out.freeBeside(r.spawnId)
          : out.carryBeside(r.spawnId, x - r.x);
      // The group it left closes up behind it.
      final left = r.beside;
      if (left != null && left != host) out = out.packBeside(left);
      return out;
    }

    // Its own group moves with it along its row, not to another.
    bool group(HomeDepth d) => !aloft && r.lift == null && d == r.depth;
    double? spot(HomeDepth d, double within) => freeSpotNear(
      r.copyWith(depth: d, lift: () => lift),
      xAt(d),
      movingGroup: group(d),
      within: within,
    );
    return _land(
      depth,
      stay ? [depth] : depth.byNearness,
      nest: aloft ? null : (d) => nestBeside(r.spawnId, xAt(d), depth: d),
      spot: spot,
      put: put,
      asked: xAt,
    );
  }

  /// Where [p] stands when it is let go on [depth]'s row (see
  /// [dropResident]): a keepsake or decor as a resident does, scenery as
  /// near as there is room on the near or far row. [y] is the height an
  /// isle, or what hangs, is set at. With [nest] off, it does not join
  /// what stands near (a piece just taken from a tray).
  HomeDrop? dropPiece(
    HomePiece p,
    HomeDepth depth,
    double Function(HomeDepth depth) xAt, {
    double? Function()? y,
    bool stay = false,
    bool nest = true,
  }) {
    final allowed = depthsFor(p.spawnId).toSet();
    // A piece new to the field is not in it yet: as it is.
    if (piece(p.spawnId) == null && !p.isKeepsake) {
      final k = realm.sceneryOf(p.kind);
      allowed
        ..clear()
        ..addAll([
          for (final d in HomeDepth.values)
            if (k != null && sceneryCanStand(k, d)) d,
        ]);
    }
    final rows = [
      for (final d in stay ? [depth] : depth.byNearness)
        if (allowed.contains(d)) d,
    ];
    if (rows.isEmpty) return null;
    final known = piece(p.spawnId) != null;
    HomeBiomeLayout put(HomeDepth d, double x, String? host) {
      final moved = p.copyWith(depth: d, x: x, y: y, beside: () => host);
      var out = known ? replacePiece(moved) : withPlaced([...placed, moved]);
      if (known) {
        out = d != p.depth
            ? out.freeBeside(p.spawnId)
            : out.carryBeside(p.spawnId, x - p.x);
      }
      final left = p.beside;
      if (left != null && left != host) out = out.packBeside(left);
      return out;
    }

    double? spot(HomeDepth d, double within) => freeSpotForPiece(
      p.copyWith(depth: d, y: y),
      xAt(d),
      movingGroup: known && d == p.depth,
      within: within,
    );
    return _land(
      rows.first,
      rows,
      nest: nest && p.isKeepsake && !p.hangs
          ? (d) => nestBeside(p.spawnId, xAt(d), depth: d)
          : null,
      spot: spot,
      put: put,
      asked: xAt,
    );
  }

  /// Finds where something let go on [asked]'s first row stands: close by
  /// on that row (beside something, or on its own), then close by on the
  /// other [rows] nearest first, then anywhere on that row, then anywhere
  /// on the others.
  HomeDrop? _land(
    HomeDepth depth,
    List<HomeDepth> rows, {
    required (String, double)? Function(HomeDepth depth)? nest,
    required double? Function(HomeDepth depth, double within) spot,
    required HomeBiomeLayout Function(HomeDepth d, double x, String? host)
    put,
    required double Function(HomeDepth depth) asked,
  }) {
    for (final far in const [false, true]) {
      for (final d in rows) {
        if (!far && nest != null) {
          final n = nest(d);
          if (n != null) {
            return HomeDrop(
              put(d, n.$2, n.$1),
              d,
              n.$2,
              d == depth ? HomeLanding.beside : HomeLanding.otherRow,
            );
          }
        }
        final x = spot(d, far ? 0.5 : _nearby(d));
        if (x == null) continue;
        final moved = _wrap(x - asked(d)).abs() > _reachOf(d) * 1.2;
        return HomeDrop(
          put(d, x, null),
          d,
          x,
          d != depth
              ? HomeLanding.otherRow
              : (moved ? HomeLanding.along : HomeLanding.asked),
        );
      }
    }
    return null;
  }

  // ── Saving ───────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'realm': realm.name,
    'sandStyle': sandStyle.toJson(),
    if (moods.isNotEmpty) 'moods': moods,
    if (hour != null) 'hour': hour,
    // The current realm's, as before each realm kept its own, so an older
    // build still finds someone at home.
    'residents': [for (final r in residents) r.toJson()],
    'households': {
      for (final e in households.entries)
        e.key: [for (final r in e.value) r.toJson()],
    },
    if (pieces.isNotEmpty)
      'pieces': {
        for (final e in pieces.entries)
          e.key: [
            // What is being tried is not kept.
            for (final p in e.value)
              if (!p.trial) p.toJson(),
          ],
      },
    if (seen.isNotEmpty) 'seen': seen.toList()..sort(),
    if (!sky.isDefault) 'sky': sky.toJson(),
    if (marks.isNotEmpty) 'marks': [for (final m in marks) m.toJson()],
    if (arrangements.isNotEmpty)
      'arrangements': {
        for (final e in arrangements.entries)
          e.key: [for (final a in e.value) a?.toJson()],
      },
    if (frames.isNotEmpty)
      'frames': {for (final e in frames.entries) e.key: e.value.toJson()},
    if (holds.isNotEmpty)
      'holds': {for (final e in holds.entries) e.key: e.value.toJson()},
  };

  static HomeBiomeLayout fromJson(Object? json) {
    if (json is! Map) return const HomeBiomeLayout();
    final realm = HomeRealm.byName(json['realm'] as String?);
    final moods = json['moods'];
    final hour = json['hour'];
    final householdsRaw = json['households'];
    final pieces = json['pieces'];
    final seenRaw = json['seen'];

    List<HomeResident> household(Object? list) {
      if (list is! List) return const [];
      final ids = <String>{};
      return [
        for (final r in list.map(HomeResident.fromJson))
          if (r != null && ids.add(r.instanceId)) r,
      ].take(kHomeBiomeMaxResidents).toList();
    }

    final households = <String, List<HomeResident>>{
      if (householdsRaw is Map)
        for (final e in householdsRaw.entries)
          if (e.key is String && HomeRealm.values.any((r) => r.name == e.key))
            e.key as String: household(e.value),
    };
    return HomeBiomeLayout(
      realm: realm,
      sandStyle: HomeSandStyle.fromJson(json['sandStyle']),
      moods: moods is Map
          ? {
              for (final e in moods.entries)
                if (e.key is String && e.value is String)
                  e.key as String: e.value as String,
            }
          : const {},
      hour: hour is num ? hour.toDouble() % 24 : null,
      // A save from before each realm kept its own household had one, that
      // all of them shared: it stays with the realm the player had chosen.
      residents: householdsRaw is Map
          ? households[realm.name] ?? const []
          : household(json['residents']),
      households: households,
      pieces: pieces is Map
          ? {
              for (final e in pieces.entries)
                if (e.key is String &&
                    HomeRealm.values.any((r) => r.name == e.key) &&
                    e.value is List)
                  e.key as String: () {
                    final ids = <String>{};
                    return [
                      for (final p in (e.value as List).map(HomePiece.fromJson))
                        if (p != null && ids.add(p.id)) p,
                    ];
                  }(),
            }
          : const {},
      seen: seenRaw is List ? {...seenRaw.whereType<String>()} : const {},
      sky: HomeSky.fromJson(json['sky']),
      marks: json['marks'] is List
          ? [
              for (final m in (json['marks'] as List).map(HomeMark.fromJson))
                if (m != null) m,
            ]
          : const [],
      arrangements: json['arrangements'] is Map
          ? {
              for (final e in (json['arrangements'] as Map).entries)
                if (e.key is String &&
                    HomeRealm.values.any((r) => r.name == e.key) &&
                    e.value is List)
                  e.key as String: [
                    for (final a in (e.value as List).take(
                      kHomeArrangementSlots,
                    ))
                      HomeArrangement.fromJson(a),
                  ],
            }
          : const {},
      frames: json['frames'] is Map
          ? {
              for (final e in (json['frames'] as Map).entries)
                if (e.key is String)
                  if (HomeFrame.fromJson(e.value) case final f?)
                    e.key as String: f,
            }
          : const {},
      holds: json['holds'] is Map
          ? {
              for (final e in (json['holds'] as Map).entries)
                if (e.key is String)
                  if (HomeHold.fromJson(e.value) case final h?)
                    e.key as String: h,
            }
          : const {},
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
