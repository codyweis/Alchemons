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
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/home_decor.dart';
import 'package:alchemons/models/scenes/arcane/arcane_scene.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
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

  /// The pieces of this realm's own scenery the player can place.
  List<HomeScenery> get scenery => switch (this) {
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
      back: back,
      x: x % 1.0,
      y: y,
      scale: double.parse(scale.toStringAsFixed(3)),
    );

    final s = sceneryOf;
    return switch (this) {
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
          piece(
            FieldPiece.spire,
            fx,
            y: 0.86 + 0.006 * seed,
            scale: h / 46,
          ),
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
    this.beside,
  });

  final String instanceId;

  /// The point it stands beside, sharing that one's ground (see
  /// [SpawnPoint.beside]); null for its own.
  final String? beside;

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
    String? Function()? beside,
  }) => HomeResident(
    instanceId: instanceId,
    back: back ?? this.back,
    x: x ?? this.x,
    lift: lift != null ? lift() : this.lift,
    flip: flip ?? this.flip,
    beside: beside != null ? beside() : this.beside,
  );

  Map<String, dynamic> toJson() => {
    'id': instanceId,
    if (back) 'back': true,
    'x': double.parse(x.toStringAsFixed(4)),
    if (lift != null) 'lift': double.parse(lift!.toStringAsFixed(4)),
    if (flip) 'flip': true,
    if (beside != null) 'beside': beside,
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
      beside: json['beside'] is String ? json['beside'] as String : null,
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
      (half > 2 ? half * (back ? 0.62 : 1) : half * width(back: back)) *
      scale;

  /// The sizes the player can choose between.
  static const scales = [0.7, 0.85, 1.0, 1.2, 1.45];
}

/// A piece the player has placed: one of the realm's own pieces of
/// scenery, or a keepsake ([Keepsake]).
class HomePiece {
  const HomePiece({
    required this.id,
    required this.kind,
    this.back = false,
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

  /// On the far row rather than the near one.
  final bool back;

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
  };

  HomePiece copyWith({
    bool? back,
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
    back: back ?? this.back,
    x: x ?? this.x,
    y: y != null ? y() : this.y,
    scale: scale ?? this.scale,
    flip: flip ?? this.flip,
    beside: beside != null ? beside() : this.beside,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    if (back) 'back': true,
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
    return HomePiece(
      id: id,
      kind: kind,
      back: json['back'] == true,
      x: x is num ? x.toDouble() % 1.0 : 0,
      y: y is num ? y.toDouble().clamp(0.1, 0.95) : null,
      scale: scale is num ? scale.toDouble().clamp(0.5, 1.6) : 1,
      flip: json['flip'] == true,
      beside: json['beside'] is String ? json['beside'] as String : null,
      style: json['style'] is int ? json['style'] as int : 0,
    );
  }
}

/// How many pieces of scenery one realm can hold.
const int kHomeBiomeMaxScenery = 18;

/// The whole home biome as the player has made it.
class HomeBiomeLayout {
  const HomeBiomeLayout({
    this.realm = HomeRealm.valley,
    this.moods = const {},
    this.hour,
    this.residents = const [],
    this.pieces = const {},
    this.seen = const {},
  });

  final HomeRealm realm;

  /// The mood picked for each realm, by realm name — each keeps its own, so
  /// going back to the Valley finds its rain still falling.
  final Map<String, String> moods;

  /// The hour the field is held at, 0–24; null follows the phone's clock.
  final double? hour;

  final List<HomeResident> residents;

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

  HomeBiomeLayout copyWith({
    HomeRealm? realm,
    Map<String, String>? moods,
    double? Function()? hour,
    List<HomeResident>? residents,
    Map<String, List<HomePiece>>? pieces,
    Set<String>? seen,
  }) => HomeBiomeLayout(
    realm: realm ?? this.realm,
    moods: moods ?? this.moods,
    hour: hour != null ? hour() : this.hour,
    residents: residents ?? this.residents,
    pieces: pieces ?? this.pieces,
    seen: seen ?? this.seen,
  );

  HomeBiomeLayout withMood(String id) =>
      copyWith(moods: {...moods, realm.name: id});

  /// The current realm with [list] standing in it.
  HomeBiomeLayout withPlaced(List<HomePiece> list) =>
      copyWith(pieces: {...pieces, realm.name: list});

  /// This layout in a realm that is [open] — the first of them when its own
  /// is not (an Arcane home before the Arcane is unlocked).
  HomeBiomeLayout within(List<HomeRealm> open) =>
      open.contains(realm) ? this : copyWith(realm: open.first);

  /// The layout as the player may have it now, whether the Arcane is
  /// unlocked read from [settings].
  static Future<HomeBiomeLayout> loadOpen(SettingsDao settings) async {
    final arcane = await HomeRealm.arcaneOpen(settings);
    return (await load(settings)).within(HomeRealm.open(arcane: arcane));
  }

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
      realm.wildScene.copyWith(spawnPoints: spawnPoints(floats));

  List<SpawnPoint> spawnPoints(bool Function(String instanceId) floats) => [
    for (final r in residents) spawnPointFor(r, floats: floats(r.instanceId)),
    for (final p in placed)
      if (pieceSpawnPoint(p) case final sp?) sp,
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
      beside: aloft ? null : hostOf(r.spawnId, r.beside, back: r.back),
    );
  }

  /// [p]'s point: a keepsake stands where a creature would, given the same
  /// ground; scenery is the field's own piece, as big as it is. Null for
  /// scenery this realm does not have.
  SpawnPoint? pieceSpawnPoint(HomePiece p) {
    final row = realm.row(back: p.back);
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
        beside: hostOf(p.spawnId, p.beside, back: p.back),
      );
    }
    final kind = realm.sceneryOf(p.kind);
    if (kind == null || (p.back && !kind.far)) return null;
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
    );
  }

  // ── Room ─────────────────────────────────────────────────────────────────

  /// [host] if it is something that stands on its own ground on [back]'s
  /// row (a resident not in the air, a keepsake) and does not itself stand
  /// beside another — what [id] may stand beside; null otherwise.
  String? hostOf(String id, String? host, {required bool back}) {
    if (host == null || host == id) return null;
    final r = resident(host);
    if (r != null) {
      return r.back == back && r.lift == null && r.beside == null ? host : null;
    }
    final p = piece(host);
    if (p != null &&
        p.isKeepsake &&
        !p.hangs &&
        p.back == back &&
        p.beside == null) {
      return host;
    }
    return null;
  }

  /// Everything standing on [back]'s row as (point id, place, reach either
  /// side, what it stands beside), in shares of the loop.
  List<(String, double, double, String?)> _standing({required bool back}) {
    final row = realm.row(back: back);
    final period = realm.period(row.layer);
    final creature = row.size * 0.95 / period;
    return [
      for (final o in residents)
        if (o.back == back && o.lift == null)
          (o.spawnId, o.x, creature, hostOf(o.spawnId, o.beside, back: back)),
      for (final p in placed)
        if (p.back == back && !p.hangs)
          if (p.isKeepsake)
            (
              p.spawnId,
              p.x,
              creature * (p.decor?.wide ?? 1),
              hostOf(p.spawnId, p.beside, back: back),
            )
          else if (realm.sceneryOf(p.kind) case final k? when k.solid)
            (p.spawnId, p.x, k.reach(back: back, scale: p.scale) / period, null),
    ];
  }

  /// What takes up room along [back]'s row, other than [except] and what
  /// stands beside it: each thing's middle and how far to either side it
  /// reaches, as shares of the loop — a pair sharing ground one stretch.
  /// What stands keeps clear of what stands; what flies of what flies
  /// ([aloft]) — a creature can hover over another's head, or over an
  /// isle. Scenery that is not ground (a tree's crown) takes no room.
  List<(double, double)> _taken({
    required bool back,
    required bool aloft,
    String? except,
    Set<String> also = const {},
  }) {
    if (aloft) {
      final row = realm.row(back: back);
      final reach = row.size * 0.6 / realm.period(row.layer);
      return [
        for (final o in residents)
          if (o.spawnId != except && o.back == back && o.lift != null)
            (o.x, reach),
      ];
    }
    final all = _standing(back: back);
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

  /// How far to either side of it a resident on [back]'s row reaches, as a
  /// share of the loop.
  double _reachOf({required bool back, bool aloft = false}) {
    final row = realm.row(back: back);
    return row.size * (aloft ? 0.6 : 0.95) / realm.period(row.layer);
  }

  /// How far apart two residents on one row must stand, as a share of the
  /// row's loop: room for each one's isle, bank or shelf — or, for two in
  /// the air ([aloft]), room for each one's wings.
  double gap({required bool back, bool aloft = false}) =>
      2 * _reachOf(back: back, aloft: aloft);

  bool _freeAt(
    double at,
    double reach,
    List<(double, double)> taken,
  ) => taken.every((o) {
    final d = _wrap(at - o.$1).abs();
    return d >= reach + o.$2 - 1e-9;
  });

  /// The free place nearest [x] on [back]'s row for something reaching
  /// [reach] to either side (a share of the loop), or null if the row has
  /// no room.
  double? _freeNear(
    double x, {
    required bool back,
    required bool aloft,
    required double reach,
    String? except,
  }) {
    final taken = _taken(back: back, aloft: aloft, except: except);
    final step = reach / 3;
    final tries = (1 / step).ceil();
    for (var i = 0; i <= tries; i++) {
      for (final s in i == 0 ? const [1] : const [1, -1]) {
        final at = (x + s * i * step) % 1.0;
        if (_freeAt(at, reach, taken)) return at;
      }
    }
    return null;
  }

  /// Where [r] can stand nearest [x] on its row without crowding anything
  /// else there, or null if the row has no room.
  double? freeSpotNear(HomeResident r, double x) {
    final aloft = r.lift != null;
    return _freeNear(
      x,
      back: r.back,
      aloft: aloft,
      reach: _reachOf(back: r.back, aloft: aloft),
      except: r.spawnId,
    );
  }

  /// Where [p] can stand nearest [x] on its row, or null if there is no
  /// room. Scenery that is not ground can stand anywhere.
  double? freeSpotForPiece(HomePiece p, double x) {
    // What hangs in the air can hang anywhere.
    if (p.hangs) return x % 1.0;
    if (p.isKeepsake) {
      return _freeNear(
        x,
        back: p.back,
        aloft: false,
        reach: _reachOf(back: p.back) * (p.decor?.wide ?? 1),
        except: p.spawnId,
      );
    }
    final k = realm.sceneryOf(p.kind);
    if (k == null) return null;
    if (!k.solid) return x % 1.0;
    final period = realm.period(realm.row(back: p.back).layer);
    return _freeNear(
      x,
      back: p.back,
      aloft: false,
      reach: k.reach(back: p.back, scale: p.scale) / period,
      except: p.spawnId,
    );
  }

  /// Something standing [id] put down at [x] on [back]'s row close beside
  /// something else standing there (a resident on the ground, a keepsake),
  /// on a side of it that is free: what it would stand beside and where,
  /// sharing its ground — or null to stand on its own.
  (String, double)? nestBeside(String id, double x, {required bool back}) {
    final row = realm.row(back: back);
    final period = realm.period(row.layer);
    final size = row.size / period;
    final all = _standing(back: back);
    // What already stands beside it moves with it; it cannot be put
    // beside one of its own.
    if (all.any((o) => o.$4 == id)) return null;
    (String, double)? best;
    var bestD = double.infinity;
    for (final (hid, hx, _, hhost) in all) {
      if (hid == id || hhost != null) continue;
      if (hostOf(id, hid, back: back) == null) continue;
      final d = _wrap(x - hx);
      if (d.abs() > size * 1.1 || d.abs() >= bestD) continue;
      final side = d >= 0 ? 1.0 : -1.0;
      // One on each side of it at most.
      final taken = all.any(
        (o) =>
            o.$4 == hid && o.$1 != id && _wrap(o.$2 - hx).sign == side,
      );
      if (taken) continue;
      final keepsake = piece(hid)?.isKeepsake ?? false;
      // Beside a wide piece (a Wonder), out at its edge, not in it.
      final wide = piece(hid)?.decor?.wide ?? 1;
      final offset = keepsake ? 0.62 * math.max(1.0, wide * 1.25) : 0.78;
      final at = (hx + side * size * offset) % 1.0;
      // The pair's ground — with whatever already stands beside the host —
      // must not run into anything else.
      final reach = size * 0.95;
      var lo = -reach, hi = reach;
      final pair = {id, hid};
      for (final (sid, sx, sreach, shost) in all) {
        if (shost != hid || sid == id) continue;
        pair.add(sid);
        final d = _wrap(sx - hx);
        lo = math.min(lo, d - sreach);
        hi = math.max(hi, d + sreach);
      }
      final dn = _wrap(at - hx);
      lo = math.min(lo, dn - reach);
      hi = math.max(hi, dn + reach);
      final rest = _taken(back: back, aloft: false, also: pair);
      if (!_freeAt((hx + (lo + hi) / 2) % 1.0, (hi - lo) / 2, rest)) continue;
      best = (hid, at);
      bestD = d.abs();
    }
    return best;
  }

  /// [layout] with whatever stood beside [hostId] moved along by [by] (a
  /// share of the loop) — it goes where its host goes.
  HomeBiomeLayout carryBeside(String hostId, double by) => copyWith(
    residents: [
      for (final r in residents)
        r.beside == hostId ? r.copyWith(x: (r.x + by) % 1.0) : r,
    ],
  ).withPlaced([
    for (final p in placed)
      p.beside == hostId ? p.copyWith(x: (p.x + by) % 1.0) : p,
  ]);

  /// [layout] with nothing standing beside [hostId] any more — it went to
  /// the other row, or away.
  HomeBiomeLayout freeBeside(String hostId) => copyWith(
    residents: [
      for (final r in residents)
        r.beside == hostId ? r.copyWith(beside: () => null) : r,
    ],
  ).withPlaced([
    for (final p in placed)
      p.beside == hostId ? p.copyWith(beside: () => null) : p,
  ]);

  // ── Saving ───────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'realm': realm.name,
    if (moods.isNotEmpty) 'moods': moods,
    if (hour != null) 'hour': hour,
    'residents': [for (final r in residents) r.toJson()],
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
  };

  static HomeBiomeLayout fromJson(Object? json) {
    if (json is! Map) return const HomeBiomeLayout();
    final moods = json['moods'];
    final hour = json['hour'];
    final residents = json['residents'];
    final pieces = json['pieces'];
    final seenRaw = json['seen'];
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
      pieces: pieces is Map
          ? {
              for (final e in pieces.entries)
                if (e.key is String &&
                    HomeRealm.values.any((r) => r.name == e.key) &&
                    e.value is List)
                  e.key as String: () {
                    final ids = <String>{};
                    return [
                      for (final p in (e.value as List).map(
                        HomePiece.fromJson,
                      ))
                        if (p != null && ids.add(p.id)) p,
                    ];
                  }(),
            }
          : const {},
      seen: seenRaw is List ? {...seenRaw.whereType<String>()} : const {},
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
