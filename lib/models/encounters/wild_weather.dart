import 'package:alchemons/models/encounters/encounter_pool.dart';

/// What a weather is, for the field that draws it.
enum WeatherKind {
  storm,
  rain,
  snow,

  /// The Swamp gone dry: the water drawn down to its last pools, the bog
  /// floor cracked and dusty.
  dry;

  /// A state the land is in rather than weather passing over it: already
  /// there when the scene opens, never rolling in or clearing in front of
  /// anyone.
  bool get settled => this == dry;
}

/// Weather that sometimes comes with a scene's spawns and brings creatures
/// of its own — the Sky's lightning storm, the Valley's rain and snow, the
/// Swamp gone dry. When
/// a batch spawns, a scene's weathers roll in turn, each with its own
/// [chance] (at most one comes); a batch that comes with one has at least
/// [guaranteed] of its creatures drawn from [pool] (each of the rest with
/// chance [extra]), and the weather lasts as long as the batch does —
/// through the visit it is found on, gone once that batch is.
class WildWeather {
  const WildWeather({
    required this.kind,
    required this.label,
    required this.chance,
    required this.pool,
    this.guaranteed = 1,
    this.extra = 0.5,
    this.aftermath = false,
    this.perSpawn = const {},
  });

  final WeatherKind kind;

  /// What the map calls it while it waits: `STORM`, `RAIN`, `SNOW`, `DRY`.
  final String label;

  final double chance;
  final EncounterPool pool;

  /// What some points take instead of [pool] while it lasts (the Swamp's
  /// pools when it has gone dry), by spawn point id.
  final Map<String, EncounterPool> perSpawn;

  /// The weather's creatures for the point [spawnId].
  EncounterPool poolFor(String spawnId) => perSpawn[spawnId] ?? pool;
  final int guaranteed;
  final double extra;

  /// Whether the first clear visit after a visit in it finds something it
  /// left behind (the Valley's rainbow, after rain).
  final bool aftermath;

  /// For each of [points] that can take one of the weather's creatures,
  /// in order, whether it does.
  List<bool> pick(int points, double Function() rand) => [
    for (var i = 0; i < points; i++) i < guaranteed || rand() < extra,
  ];
}
