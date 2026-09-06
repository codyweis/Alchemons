// lib/games/cosmic/cosmic_cache_data.dart
//
// SEALED ELEMENTAL CACHES
//
// Abstract alchemical constructs drifting in open space. Each one is bound to a
// single element and sits inert until the player summons a party Alchemon of
// that element next to it — the cache reads the companion's signature, the seal
// gives, and it pays out.
//
// One cache per element is alive at a time (17 total). Cracking one starts a
// respawn timer for that element; when it fires the cache re-rolls to a fresh
// position elsewhere in the cosmos.

import 'dart:math';
import 'dart:ui';

import 'cosmic_data.dart';

// ─────────────────────────────────────────────────────────
// HINTS
// ─────────────────────────────────────────────────────────

/// The riddle each seal whispers — "this needs a burning flame".
const Map<String, String> kCacheHints = {
  'Fire': 'a burning flame',
  'Lava': 'molten stone',
  'Lightning': 'a living spark',
  'Water': 'a flowing tide',
  'Ice': 'an unmelting frost',
  'Steam': 'a scalding breath',
  'Earth': 'steady ground',
  'Mud': 'a churning mire',
  'Dust': 'a drifting grain',
  'Crystal': 'a singing lattice',
  'Air': 'a restless wind',
  'Plant': 'a stubborn root',
  'Poison': 'a patient venom',
  'Spirit': 'a wandering soul',
  'Dark': 'an unlit hour',
  'Light': 'a first dawn',
  'Blood': 'a beating heart',
};

String cacheHintFor(String element) =>
    kCacheHints[element] ?? 'an ${element.toLowerCase()} signature';

// ─────────────────────────────────────────────────────────
// CACHE
// ─────────────────────────────────────────────────────────

/// A single sealed cache bound to one element.
class ElementalCache {
  ElementalCache({
    required this.element,
    required this.position,
    this.discovered = false,
    this.respawnTimer = 0,
    this.openedAtMs = 0,
    this.life = 0,
  });

  final String element;

  /// World-space position. Re-rolled when the cache respawns.
  Offset position;

  /// Once the ship has been right next to it, the cache is pinned on the
  /// full map for good. The radar ring shows it whenever it is in range.
  bool discovered;

  /// Seconds remaining until this element's cache returns. `<= 0` means the
  /// cache is present and openable.
  ///
  /// Legacy: kept so old saves still parse, but nothing counts it down any
  /// more. Availability is decided by [openedAtMs] against the wall clock.
  double respawnTimer;

  /// Wall-clock time this cache was last emptied, epoch milliseconds, or 0 if
  /// it has never been opened.
  ///
  /// The old countdown only advanced while the cosmic game was actually
  /// updating, so a cache came back after ten minutes of *play* and froze
  /// while the app was closed. Caches are a daily pickup, so the clock has to
  /// be the device's, not the game loop's.
  int openedAtMs;

  /// Free-running animation clock.
  double life;

  /// `-1` when idle; otherwise seconds elapsed in the 3s unsealing sequence.
  double openTimer = -1;

  Color get color => elementColor(element);

  /// A cache is back once the calendar day has rolled over since it was
  /// emptied — matching how the rest of the game's dailies read to a player
  /// ("tomorrow"), rather than a floating 24h from whenever they happened to
  /// crack it.
  bool get isPresent => isPresentAt(DateTime.now());

  bool isPresentAt(DateTime now) {
    if (openedAtMs <= 0) return true;
    final opened = DateTime.fromMillisecondsSinceEpoch(openedAtMs);
    final openedDay = DateTime(opened.year, opened.month, opened.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.isAfter(openedDay);
  }

  /// When this cache next becomes available, for UI that wants to say so.
  DateTime? get availableAt {
    if (openedAtMs <= 0) return null;
    final opened = DateTime.fromMillisecondsSinceEpoch(openedAtMs);
    return DateTime(opened.year, opened.month, opened.day + 1);
  }

  bool get isOpening => openTimer >= 0;

  /// Hard interaction gate — how close the ship must be for the prompt.
  static const double interactRadius = 300.0;

  /// Slightly wider so the prompt does not flicker at the boundary.
  static const double exitRadius = 380.0;

  /// How close the ship must come before the cache is pinned to the full map.
  static const double discoverRadius = 260.0;

  /// How close the summoned companion must be to break the seal. Generous on
  /// purpose: a companion summoned at the ship while the prompt is up must
  /// always count, and companions wander ~80 units off their anchor.
  static const double attuneRadius = 460.0;

  /// Visual radius of the seal itself.
  static const double visualRadius = 54.0;

  /// Length of the unsealing animation.
  static const double openDuration = 3.0;

  /// Legacy play-time respawn delay. No longer used: caches now return on the
  /// next calendar day. Retained only so old saves deserialise.
  static const double respawnDelay = 600.0;

  String serialise() =>
      '$element,'
      '${position.dx.toStringAsFixed(1)},'
      '${position.dy.toStringAsFixed(1)},'
      '${discovered ? 1 : 0},'
      '${respawnTimer.toStringAsFixed(1)},'
      '$openedAtMs';

  static ElementalCache? deserialise(String raw) {
    final p = raw.split(',');
    if (p.length < 5) return null;
    if (!kElementColors.containsKey(p[0])) return null;
    return ElementalCache(
      element: p[0],
      position: Offset(double.tryParse(p[1]) ?? 0, double.tryParse(p[2]) ?? 0),
      discovered: p[3] == '1',
      respawnTimer: max(0.0, double.tryParse(p[4]) ?? 0),
      // Saves written before the daily reset have no timestamp. Treat those
      // caches as available rather than stranding them behind a countdown
      // nothing decrements any more.
      openedAtMs: p.length > 5 ? (int.tryParse(p[5]) ?? 0) : 0,
    );
  }
}

// ─────────────────────────────────────────────────────────
// FIELD (the 17 live caches)
// ─────────────────────────────────────────────────────────

/// Owns exactly one cache per element and handles respawn placement.
class ElementalCacheField {
  ElementalCacheField({
    required this.caches,
    required this.worldSize,
    this.landmarks = const [],
  });

  final List<ElementalCache> caches;
  final Size worldSize;

  /// Other interactables whose HUD prompt would collide with a cache's.
  final List<Offset> landmarks;

  static const double _margin = 2200.0;
  static const double _minPlanetDist = 1600.0;
  static const double _minCacheDist = 2600.0;
  static const double _minLandmarkDist = 2000.0;

  /// Lay out one cache per element, kept clear of planets, of each other, and
  /// of [landmarks] — the nexus, the rings, the rift portals. A cache sharing
  /// a spot with one of those puts two prompts in the same HUD slot.
  factory ElementalCacheField.generate({
    required int seed,
    required Size worldSize,
    required List<CosmicPlanet> planets,
    List<Offset> landmarks = const [],
  }) {
    final rng = Random(seed ^ 0x5EA1ED);
    final caches = <ElementalCache>[];
    for (final element in kElementColors.keys) {
      caches.add(
        ElementalCache(
          element: element,
          position: _rollPosition(rng, worldSize, planets, caches, landmarks),
        ),
      );
    }
    return ElementalCacheField(
      caches: caches,
      worldSize: worldSize,
      landmarks: landmarks,
    );
  }

  static Offset _rollPosition(
    Random rng,
    Size worldSize,
    List<CosmicPlanet> planets,
    List<ElementalCache> existing,
    List<Offset> landmarks, {
    ElementalCache? ignore,
  }) {
    Offset pos = Offset.zero;
    for (var tries = 0; tries < 200; tries++) {
      pos = Offset(
        _margin + rng.nextDouble() * (worldSize.width - _margin * 2),
        _margin + rng.nextDouble() * (worldSize.height - _margin * 2),
      );
      final crowdedByPlanet = planets.any(
        (p) => (p.position - pos).distance < _minPlanetDist,
      );
      if (crowdedByPlanet) continue;
      final crowdedByCache = existing.any(
        (c) =>
            !identical(c, ignore) &&
            (c.position - pos).distance < _minCacheDist,
      );
      if (crowdedByCache) continue;
      final crowdedByLandmark = landmarks.any(
        (l) => (l - pos).distance < _minLandmarkDist,
      );
      if (crowdedByLandmark) continue;
      return pos;
    }
    return pos;
  }

  /// Move [cache] to a fresh spot and forget that the player ever saw it.
  void relocate(ElementalCache cache, Random rng, List<CosmicPlanet> planets) {
    cache.position = _rollPosition(
      rng,
      worldSize,
      planets,
      caches,
      landmarks,
      ignore: cache,
    );
    cache.discovered = false;
    cache.life = 0;
    cache.openTimer = -1;
  }

  String serialise() => caches.map((c) => c.serialise()).join('|');

  /// Restore saved state onto the generated layout. Unknown or malformed
  /// entries are ignored so a schema change never wipes the field.
  void restore(String raw) {
    if (raw.isEmpty) return;
    for (final chunk in raw.split('|')) {
      final parsed = ElementalCache.deserialise(chunk);
      if (parsed == null) continue;
      final target = caches.where((c) => c.element == parsed.element);
      if (target.isEmpty) continue;
      final cache = target.first;
      cache.position = parsed.position;
      cache.discovered = parsed.discovered;
      cache.respawnTimer = parsed.respawnTimer;
      cache.openedAtMs = parsed.openedAtMs;
      cache.openTimer = -1;
    }
  }
}
