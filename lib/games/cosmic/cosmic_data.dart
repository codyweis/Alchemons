// lib/games/cosmic/cosmic_data.dart
//
// Data model for the Cosmic Alchemy Explorer — planets, fog-of-war, element
// collection and summon resolution.

import 'dart:math';
import 'dart:ui';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/systems/effects/has_effects.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';

// ─────────────────────────────────────────────────────────
// ELEMENT COLOURS  (mirrors SurvivalAttackManager.getElementColor)
// ─────────────────────────────────────────────────────────
const Map<String, Color> kElementColors = {
  'Fire': Color(0xFFFF5722),
  'Lava': Color(0xFFEF6C00),
  'Lightning': Color(0xFFFFEB3B),
  'Water': Color(0xFF448AFF),
  'Ice': Color(0xFF00E5FF),
  'Steam': Color(0xFF90A4AE),
  'Earth': Color(0xFF795548),
  'Mud': Color(0xFF5D4037),
  'Dust': Color(0xFFFFCC80),
  'Crystal': Color(0xFF1DE9B6),
  'Air': Color(0xFF81D4FA),
  'Plant': Color(0xFF4CAF50),
  'Poison': Color(0xFF9C27B0),
  'Spirit': Color(0xFF3F51B5),
  'Dark': Color(0xFF4A148C),
  'Light': Color(0xFFFFE082),
  'Blood': Color(0xFFD32F2F),
};

Color elementColor(String element) =>
    kElementColors[element] ?? const Color(0xFF9E9E9E);

// Global damage multiplier to tune basic attacks and ship projectiles.
const double kDamageScale = 1.5;

// ─────────────────────────────────────────────────────────
// PLANET DISPLAY NAMES
// ─────────────────────────────────────────────────────────
const Map<String, String> kPlanetDisplayName = {
  'Fire': 'Pyrathis',
  'Lava': 'Magmora',
  'Lightning': 'Voltara',
  'Water': 'Aquathos',
  'Ice': 'Glaceron',
  'Steam': 'Vaporis',
  'Earth': 'Terragrim',
  'Mud': 'Mireholm',
  'Dust': 'Cindrath',
  'Crystal': 'Lumishara',
  'Air': 'Zephyria',
  'Plant': 'Verdanthos',
  'Poison': 'Toxivyre',
  'Spirit': 'Etherion',
  'Dark': 'Nythralor',
  'Light': 'Solanthis',
  'Blood': 'Hemavorn',
};

String planetName(String element) => kPlanetDisplayName[element] ?? element;

// ─────────────────────────────────────────────────────────
// COSMIC PLANET
// ─────────────────────────────────────────────────────────

/// Per-element planet size & gravity mass.
const Map<String, double> kPlanetRadius = {
  'Fire': 90,
  'Lava': 110,
  'Lightning': 55,
  'Water': 150,
  'Ice': 70,
  'Steam': 100,
  'Earth': 120,
  'Mud': 85,
  'Dust': 50,
  'Crystal': 100,
  'Air': 45,
  'Plant': 80,
  'Poison': 75,
  'Spirit': 55,
  'Dark': 95,
  'Light': 200,
  'Blood': 105,
};

/// Gravity strength multiplier per element (bigger / denser = stronger pull).
const Map<String, double> kPlanetGravity = {
  'Fire': 1.0,
  'Lava': 1.4,
  'Lightning': 0.5,
  'Water': 1.1,
  'Ice': 0.8,
  'Steam': 0.3,
  'Earth': 1.6,
  'Mud': 1.2,
  'Dust': 0.4,
  'Crystal': 0.9,
  'Air': 0.2,
  'Plant': 0.7,
  'Poison': 0.8,
  'Spirit': 0.3,
  'Dark': 1.5,
  'Light': 0.4,
  'Blood': 1.3,
};

/// A planet that emits elemental particles of a single element type.
class CosmicPlanet {
  CosmicPlanet({
    required this.element,
    required this.position,
    required this.radius,
    this.discovered = false,
  });

  final String element; // e.g. 'Fire'
  Offset position; // world-space position (mutable for orbital mechanics)
  final double radius; // visual radius
  bool discovered; // fog-of-war state

  Color get color => elementColor(element);

  /// Gravity pull strength.
  double get gravityStrength => (kPlanetGravity[element] ?? 1.0) * 8000;

  /// Ring of influence where particles spawn.
  double get particleFieldRadius => radius * 12.0;
}

// ─────────────────────────────────────────────────────────
// PRISMATIC FIELD (aurora easter-egg)
// ─────────────────────────────────────────────────────────

/// A giant shimmering prismatic aurora field floating in space.
/// If the player summons a prismatic companion inside the field,
/// the companion sprints in a circle and awards 50 gold.
/// This reward can only be claimed once, but the field is always visible.
class PrismaticField {
  PrismaticField({required this.position, this.radius = 1200});

  final Offset position;
  final double radius;
  bool discovered = false;
  bool rewardClaimed = false;
  double life = 0; // visual animation timer

  /// Prismatic hue-cycling colours for the aurora bands.
  static const List<Color> auroraColors = [
    Color(0xFFFF0066), // magenta-pink
    Color(0xFFFF6600), // orange
    Color(0xFFFFDD00), // gold
    Color(0xFF00FF88), // green
    Color(0xFF00DDFF), // cyan
    Color(0xFF4466FF), // blue
    Color(0xFF9933FF), // violet
    Color(0xFFFF00CC), // hot pink
  ];
}

// ─────────────────────────────────────────────────────────
// ELEMENTAL NEXUS (easter-egg black portal)
// ─────────────────────────────────────────────────────────

/// A massive black portal hidden in deep space.
/// Requires the alchemeal meter to have exactly 25% Fire, 25% Water,
/// 25% Air, 25% Earth to enter.
///
/// Inside: player gets a guaranteed harvester, then picks one of four
/// elemental portals (Fire/Water/Earth/Air).  Going through one triggers
/// an encounter with a Prismatic Kin of that element.
///
/// The encounter creature has stats: all 3.0 starting, 4.5 potential.
///
/// State is persisted so if the app crashes mid-nexus the player can resume.
enum NexusPhase {
  /// Not yet entered the nexus.
  outside,

  /// Inside the nexus chamber — choosing a portal.
  choosingPortal,

  /// Went through a portal — encounter in progress.
  inEncounter,
}

class ElementalNexus {
  Offset position;
  bool discovered;
  NexusPhase phase;

  /// Which element portal the player chose (null until they pick one).
  String? chosenElement;

  /// Whether the guaranteed harvester was already awarded this visit.
  bool harvesterAwarded;

  /// Whether the ship is currently inside the pocket wormhole dimension.
  bool inPocket;

  /// Ship position before entering the pocket (for returning).
  Offset? prePocketShipPos;

  ElementalNexus({
    required this.position,
    this.discovered = false,
    this.phase = NexusPhase.outside,
    this.chosenElement,
    this.harvesterAwarded = false,
    this.inPocket = false,
    this.prePocketShipPos,
  });

  static const double interactRadius = 350.0;
  static const double exitRadius = 450.0;
  static const double visualRadius = 300.0;

  // Pocket dimension layout
  static const double pocketRadius = 1200.0;
  static const double portalOrbitR = 250.0;
  static const double portalInteractR = 120.0;

  static const List<String> pocketElements = ['Fire', 'Water', 'Earth', 'Air'];

  /// Returns world-space positions of the 4 pocket portals relative to
  /// [pocketCenter].
  static List<Offset> pocketPortalPositions(Offset pocketCenter) {
    return [
      pocketCenter + const Offset(0, -portalOrbitR), // Fire (top)
      pocketCenter + const Offset(portalOrbitR, 0), // Water (right)
      pocketCenter + const Offset(0, portalOrbitR), // Earth (bottom)
      pocketCenter + const Offset(-portalOrbitR, 0), // Air (left)
    ];
  }

  /// The four required elements and their percentages.
  static const Map<String, double> requiredRecipe = {
    'Fire': 25.0,
    'Water': 25.0,
    'Air': 25.0,
    'Earth': 25.0,
  };

  /// Check if the meter matches the nexus recipe (each element ≥ 20%).
  bool meetsRequirement(Map<String, double> meterBreakdown, double meterTotal) {
    if (meterTotal <= 0) return false;
    for (final entry in requiredRecipe.entries) {
      final actual = ((meterBreakdown[entry.key] ?? 0) / meterTotal) * 100;
      if (actual < 20.0) return false; // allow 5% tolerance
    }
    return true;
  }

  String serialise() {
    return '${position.dx.toStringAsFixed(1)},'
        '${position.dy.toStringAsFixed(1)}|'
        '${discovered ? 1 : 0}|'
        '${phase.index}|'
        '${chosenElement ?? ""}|'
        '${harvesterAwarded ? 1 : 0}|'
        '${inPocket ? 1 : 0}|'
        '${prePocketShipPos != null ? '${prePocketShipPos!.dx.toStringAsFixed(1)},${prePocketShipPos!.dy.toStringAsFixed(1)}' : ''}';
  }

  factory ElementalNexus.deserialise(String raw) {
    final parts = raw.split('|');
    if (parts.length < 5) {
      return ElementalNexus(position: const Offset(0, 0));
    }
    final posParts = parts[0].split(',');
    final pos = Offset(
      double.tryParse(posParts[0]) ?? 0,
      double.tryParse(posParts[1]) ?? 0,
    );

    // Parse pocket fields (added in v2)
    final pocketFlag = parts.length > 5 ? parts[5] == '1' : false;
    Offset? prePocketPos;
    if (parts.length > 6 && parts[6].isNotEmpty) {
      final pp = parts[6].split(',');
      if (pp.length == 2) {
        prePocketPos = Offset(
          double.tryParse(pp[0]) ?? 0,
          double.tryParse(pp[1]) ?? 0,
        );
      }
    }

    return ElementalNexus(
      position: pos,
      discovered: parts[1] == '1',
      phase: NexusPhase.values[(int.tryParse(parts[2]) ?? 0).clamp(0, 2)],
      chosenElement: parts[3].isNotEmpty ? parts[3] : null,
      harvesterAwarded: parts[4] == '1',
      inPocket: pocketFlag,
      prePocketShipPos: prePocketPos,
    );
  }
}

// ─────────────────────────────────────────────────────────
// BATTLE RING (10-level arena with 1v1 encounters)
// ─────────────────────────────────────────────────────────

class BattleRing {
  Offset position;
  bool discovered;

  /// Current level (0-based). 0–9 = levels 1–10. 10 = all beaten, practice mode.
  int currentLevel;

  /// True while a 1v1 battle is actively in progress.
  bool inBattle;

  BattleRing({
    required this.position,
    this.discovered = false,
    this.currentLevel = 0,
    this.inBattle = false,
  });

  /// Visual outer radius of the octagon ring.
  static const double visualRadius = 300.0;

  /// Interaction radius (proximity to trigger popup).
  static const double interactRadius = 400.0;

  /// Exit radius (hysteresis band so popup doesn't flicker).
  static const double exitRadius = 500.0;

  /// Number of levels in total.
  static const int maxLevels = 10;

  /// Whether all 10 levels are beaten → practice arena.
  bool get isCompleted => currentLevel >= maxLevels;

  /// Gold reward per level (10 gold × level number, 1-based).
  /// Gold reward per level: fixed 10 gold for completing a level.
  int get goldReward => isCompleted ? 1000 : 10;

  /// Opponent rarity for the current level.
  /// Levels 1–3 = common, 4–6 = uncommon, 7–8 = rare, 9–10 = legendary.
  String get opponentRarity {
    if (currentLevel >= 8) return 'legendary';
    if (currentLevel >= 6) return 'rare';
    if (currentLevel >= 3) return 'uncommon';
    return 'common';
  }

  /// Opponent stat cap for the current level.
  /// Linear scale: level 1 = 1.5, level 10 = 4.5.
  double get opponentStatMax => 1.5 + (currentLevel * (3.0 / 9.0));

  /// Display name for the current level.
  String get levelLabel =>
      isCompleted ? 'PRACTICE ARENA' : 'LEVEL ${currentLevel + 1} / $maxLevels';

  String serialise() {
    return '${position.dx.toStringAsFixed(1)},'
        '${position.dy.toStringAsFixed(1)}|'
        '${discovered ? 1 : 0}|'
        '$currentLevel|'
        '${inBattle ? 1 : 0}';
  }

  factory BattleRing.deserialise(String raw) {
    final parts = raw.split('|');
    if (parts.length < 3) {
      return BattleRing(position: const Offset(0, 0));
    }
    final posParts = parts[0].split(',');
    final pos = Offset(
      double.tryParse(posParts[0]) ?? 0,
      double.tryParse(posParts[1]) ?? 0,
    );
    return BattleRing(
      position: pos,
      discovered: parts[1] == '1',
      currentLevel: (int.tryParse(parts[2]) ?? 0).clamp(0, maxLevels),
      inBattle: parts.length > 3 ? parts[3] == '1' : false,
    );
  }
}

// ─────────────────────────────────────────────────────────
// BLOOD RING (ending ritual portal)
// ─────────────────────────────────────────────────────────

class BloodRing {
  Offset position;
  bool discovered;

  /// True once the ending ritual has been completed at least once.
  bool ritualCompleted;

  BloodRing({
    required this.position,
    this.discovered = false,
    this.ritualCompleted = false,
  });

  /// Visual outer radius.
  static const double visualRadius = 320.0;

  /// Interaction radius (proximity to show interaction button).
  static const double interactRadius = 420.0;

  /// Exit radius (hysteresis so the prompt does not flicker).
  static const double exitRadius = 520.0;

  String serialise() {
    return '${position.dx.toStringAsFixed(1)},'
        '${position.dy.toStringAsFixed(1)}|'
        '${discovered ? 1 : 0}|'
        '${ritualCompleted ? 1 : 0}';
  }

  factory BloodRing.deserialise(String raw) {
    final parts = raw.split('|');
    if (parts.length < 2) {
      return BloodRing(position: const Offset(0, 0));
    }
    final posParts = parts[0].split(',');
    final pos = Offset(
      double.tryParse(posParts[0]) ?? 0,
      double.tryParse(posParts[1]) ?? 0,
    );
    return BloodRing(
      position: pos,
      discovered: parts[1] == '1',
      ritualCompleted: parts.length > 2 ? parts[2] == '1' : false,
    );
  }
}

// ─────────────────────────────────────────────────────────
// RIFT PORTAL (one per faction, permanent)
// ─────────────────────────────────────────────────────────

class RiftPortal {
  final String faction; // 'volcanic','oceanic','verdant','earthen','arcane'
  Offset position;
  bool entered; // true once the player has entered this session

  RiftPortal({
    required this.faction,
    required this.position,
    this.entered = false,
  });

  static const double interactRadius = 120.0;
  static const double exitRadius = 150.0;

  /// Faction display colour for rendering.
  Color get color => switch (faction) {
    'volcanic' => const Color(0xFFFF5722),
    'oceanic' => const Color(0xFF2196F3),
    'verdant' => const Color(0xFF4CAF50),
    'earthen' => const Color(0xFFFF8F00),
    'arcane' => const Color(0xFFCE93D8),
    _ => const Color(0xFFCE93D8),
  };

  Color get coreColor => switch (faction) {
    'volcanic' => const Color(0xFF1A0500),
    'oceanic' => const Color(0xFF000D1A),
    'verdant' => const Color(0xFF001A08),
    'earthen' => const Color(0xFF1A0A00),
    'arcane' => const Color(0xFF0D0015),
    _ => const Color(0xFF0D0015),
  };

  String get displayName => switch (faction) {
    'volcanic' => 'Volcanic Rift',
    'oceanic' => 'Oceanic Rift',
    'verdant' => 'Verdant Rift',
    'earthen' => 'Earthen Rift',
    'arcane' => 'Arcane Rift',
    _ => 'Rift Portal',
  };
}

// ─────────────────────────────────────────────────────────
// PARTICLE SWARM (wandering elemental cloud)
// ─────────────────────────────────────────────────────────

/// A drifting cloud of elemental motes that the player can fly through
/// and collect. Each swarm has 80-120 individual particles that orbit
/// the swarm centre with gentle cohesion.
class ParticleSwarm {
  ParticleSwarm({
    required this.element,
    required this.center,
    required this.motes,
    required this.driftAngle,
  });

  String element;
  Offset center; // swarm centre drifts slowly
  double driftAngle; // direction of drift (radians)
  double driftTimer = 0; // time until drift angle changes
  final List<SwarmMote> motes;
  double pulse = 0; // visual pulse timer

  /// How many motes remain uncollected.
  int get remaining => motes.where((m) => !m.collected).length;
  bool get depleted => remaining < motes.length * 0.25;

  static const double driftSpeed = 12.0; // units/sec
  static const double cloudRadius = 350.0; // mote scatter radius
  static const double collectRadius = 35.0; // ship pickup radius per mote
  static const double magnetRadius = 80.0; // magnetic pull range

  /// Generate swarms scattered across the world.
  static List<ParticleSwarm> generate({
    required int seed,
    required Size worldSize,
    required List<Offset> obstacles, // planet + rift positions
    int count = 20,
  }) {
    final rng = Random(seed ^ 0xBEEFCAFE);
    const margin = 2500.0;
    const minDist = 2000.0;
    const elements = [
      'Fire',
      'Water',
      'Earth',
      'Air',
      'Steam',
      'Lava',
      'Lightning',
      'Mud',
      'Ice',
      'Dust',
      'Crystal',
      'Plant',
      'Poison',
      'Spirit',
      'Dark',
      'Light',
      'Blood',
    ];

    final placed = <Offset>[];
    final swarms = <ParticleSwarm>[];

    for (var i = 0; i < count; i++) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
        tries++;
      } while (tries < 300 &&
          (obstacles.any((o) => (o - pos).distance < minDist) ||
              placed.any((p) => (p - pos).distance < minDist)));

      placed.add(pos);
      final elem = elements[rng.nextInt(elements.length)];
      final moteCount = 80 + rng.nextInt(41); // 80–120

      final motes = <SwarmMote>[];
      for (var m = 0; m < moteCount; m++) {
        final angle = rng.nextDouble() * pi * 2;
        final dist = rng.nextDouble() * cloudRadius;
        motes.add(
          SwarmMote(
            offsetX: cos(angle) * dist,
            offsetY: sin(angle) * dist,
            orbitSpeed: 0.15 + rng.nextDouble() * 0.35,
            orbitPhase: rng.nextDouble() * pi * 2,
            size: 1.5 + rng.nextDouble() * 2.5,
          ),
        );
      }

      swarms.add(
        ParticleSwarm(
          element: elem,
          center: pos,
          motes: motes,
          driftAngle: rng.nextDouble() * pi * 2,
        ),
      );
    }
    return swarms;
  }
}

/// A single mote within a particle swarm.
class SwarmMote {
  SwarmMote({
    required this.offsetX,
    required this.offsetY,
    required this.orbitSpeed,
    required this.orbitPhase,
    required this.size,
  });

  double offsetX, offsetY; // offset from swarm centre
  final double orbitSpeed; // radians/sec of gentle orbit
  double orbitPhase; // current phase
  final double size; // visual radius
  bool collected = false;
}

// ─────────────────────────────────────────────────────────
// COSMIC WORLD DEFINITION
// ─────────────────────────────────────────────────────────

/// The entire cosmos layout.
class CosmicWorld {
  CosmicWorld({
    required this.planets,
    required this.worldSize,
    required this.riftPortals,
    required this.particleSwarms,
    required this.prismaticField,
    required this.elementalNexus,
    required this.battleRing,
    required this.bloodRing,
    required this.contestArenas,
    required this.contestHintNotes,
  });

  final List<CosmicPlanet> planets;
  final Size worldSize; // total explorable area
  final List<RiftPortal> riftPortals;
  final List<ParticleSwarm> particleSwarms;
  final PrismaticField prismaticField;
  final ElementalNexus elementalNexus;
  final BattleRing battleRing;
  final BloodRing bloodRing;
  final List<CosmicContestArena> contestArenas;
  final List<CosmicContestHintNote> contestHintNotes;

  /// Generate a standard cosmos: one planet per element scattered across a
  /// huge field. Deliberately large so it takes ~10 minutes to traverse.
  factory CosmicWorld.generate({int? seed}) {
    final rng = Random(seed ?? DateTime.now().millisecondsSinceEpoch);
    const elements = [
      'Fire',
      'Water',
      'Earth',
      'Air',
      'Steam',
      'Lava',
      'Lightning',
      'Mud',
      'Ice',
      'Dust',
      'Crystal',
      'Plant',
      'Poison',
      'Spirit',
      'Dark',
      'Light',
      'Blood',
    ];

    // World is 38 400 × 38 400 logical units.
    const double worldW = 38400;
    const double worldH = 38400;
    const double margin = 1920;
    const double minDist = 3840; // planets don't crowd each other

    final planets = <CosmicPlanet>[];
    for (final elem in elements) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldW - margin * 2),
          margin + rng.nextDouble() * (worldH - margin * 2),
        );
        tries++;
      } while (tries < 300 &&
          planets.any((p) => (p.position - pos).distance < minDist));

      final baseR = kPlanetRadius[elem] ?? 70;
      // ±15% random variation
      final r = baseR * (0.85 + rng.nextDouble() * 0.30);

      planets.add(CosmicPlanet(element: elem, position: pos, radius: r));
    }

    // ── Rift portals (one per faction, scattered like planets) ──
    const factions = ['volcanic', 'oceanic', 'verdant', 'earthen', 'arcane'];
    final allPositions = planets.map((p) => p.position).toList();
    final rifts = <RiftPortal>[];
    for (final f in factions) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldW - margin * 2),
          margin + rng.nextDouble() * (worldH - margin * 2),
        );
        tries++;
      } while (tries < 300 &&
          (allPositions.any((p) => (p - pos).distance < minDist) ||
              rifts.any((r) => (r.position - pos).distance < minDist)));
      rifts.add(RiftPortal(faction: f, position: pos));
      allPositions.add(pos);
    }

    // ── Particle swarms (drifting elemental clouds) ──
    final swarmObstacles = <Offset>[
      ...allPositions,
      ...rifts.map((r) => r.position),
    ];
    final swarms = ParticleSwarm.generate(
      seed: rng.nextInt(1 << 30),
      worldSize: const Size(worldW, worldH),
      obstacles: swarmObstacles,
    );

    // ── Prismatic Field (aurora easter-egg) ──
    // Place it far from planets / rifts so it feels like a hidden anomaly.
    Offset prisPos;
    int ppTries = 0;
    do {
      prisPos = Offset(
        margin + rng.nextDouble() * (worldW - margin * 2),
        margin + rng.nextDouble() * (worldH - margin * 2),
      );
      ppTries++;
    } while (ppTries < 300 &&
        (allPositions.any((p) => (p - prisPos).distance < 4000) ||
            rifts.any((r) => (r.position - prisPos).distance < 4000)));

    final prismaticField = PrismaticField(position: prisPos, radius: 600);

    // ── Elemental Nexus (black portal easter-egg) ──
    // Place as far as possible from all planets.
    Offset nexusPos = Offset(margin, margin);
    double bestMinDist = 0;
    for (int attempt = 0; attempt < 2000; attempt++) {
      final candidate = Offset(
        margin + rng.nextDouble() * (worldW - margin * 2),
        margin + rng.nextDouble() * (worldH - margin * 2),
      );
      // Must be far from rifts & prismatic field
      if (rifts.any((r) => (r.position - candidate).distance < 5000)) continue;
      if ((prisPos - candidate).distance < 5000) continue;
      // Find the minimum distance to any planet
      double minPlanetDist = double.infinity;
      for (final p in allPositions) {
        final d = (p - candidate).distance;
        if (d < minPlanetDist) minPlanetDist = d;
      }
      // Keep the candidate that maximises the minimum planet distance
      if (minPlanetDist > bestMinDist) {
        bestMinDist = minPlanetDist;
        nexusPos = candidate;
      }
    }

    final elementalNexus = ElementalNexus(position: nexusPos);

    // ── Battle Ring (octagonal arena) ──
    // Place far from everything — same strategy as nexus.
    Offset ringPos = Offset(margin, margin);
    double bestRingDist = 0;
    for (int attempt = 0; attempt < 2000; attempt++) {
      final candidate = Offset(
        margin + rng.nextDouble() * (worldW - margin * 2),
        margin + rng.nextDouble() * (worldH - margin * 2),
      );
      if (rifts.any((r) => (r.position - candidate).distance < 5000)) continue;
      if ((prisPos - candidate).distance < 5000) continue;
      if ((nexusPos - candidate).distance < 5000) continue;
      double minD = double.infinity;
      for (final p in allPositions) {
        final d = (p - candidate).distance;
        if (d < minD) minD = d;
      }
      if (minD > bestRingDist) {
        bestRingDist = minD;
        ringPos = candidate;
      }
    }
    final battleRing = BattleRing(position: ringPos);

    // ── Blood Ring (ending ritual portal) ──
    // Place far from all landmarks so it feels like a hidden final destination.
    Offset bloodPos = Offset(margin, margin);
    double bestBloodDist = 0;
    for (int attempt = 0; attempt < 2000; attempt++) {
      final candidate = Offset(
        margin + rng.nextDouble() * (worldW - margin * 2),
        margin + rng.nextDouble() * (worldH - margin * 2),
      );
      if (rifts.any((r) => (r.position - candidate).distance < 5000)) continue;
      if ((prisPos - candidate).distance < 5000) continue;
      if ((nexusPos - candidate).distance < 5000) continue;
      if ((ringPos - candidate).distance < 5000) continue;
      double minD = double.infinity;
      for (final p in allPositions) {
        final d = (p - candidate).distance;
        if (d < minD) minD = d;
      }
      if (minD > bestBloodDist) {
        bestBloodDist = minD;
        bloodPos = candidate;
      }
    }
    final bloodRing = BloodRing(position: bloodPos);

    final contestObstacles = <Offset>[
      ...allPositions,
      ...rifts.map((r) => r.position),
      prisPos,
      nexusPos,
      ringPos,
      bloodPos,
    ];
    final contestArenas = generateCosmicContestArenas(
      seed: rng.nextInt(1 << 30),
      worldSize: const Size(worldW, worldH),
      obstacles: contestObstacles,
    );
    final contestHintNotes = generateCosmicContestHintNotes(
      seed: rng.nextInt(1 << 30),
      worldSize: const Size(worldW, worldH),
      obstacles: [...contestObstacles, ...contestArenas.map((a) => a.position)],
    );

    return CosmicWorld(
      planets: planets,
      worldSize: const Size(worldW, worldH),
      riftPortals: rifts,
      particleSwarms: swarms,
      prismaticField: prismaticField,
      elementalNexus: elementalNexus,
      battleRing: battleRing,
      bloodRing: bloodRing,
      contestArenas: contestArenas,
      contestHintNotes: contestHintNotes,
    );
  }

  int get discoveredCount => planets.where((p) => p.discovered).length;
  int get totalCount => planets.length;
}

// ─────────────────────────────────────────────────────────
// ELEMENT COLLECTION METER
// ─────────────────────────────────────────────────────────

/// Tracks collected elemental particles and resolves them into a resulting
/// element type using the recipe system.
class ElementMeter {
  final Map<String, double> _collected = {};

  /// Max capacity — once total reaches this, the meter is full.
  static const double maxCapacity = 100.0;

  double get total => _collected.values.fold(0.0, (s, v) => s + v);
  bool get isFull => total >= maxCapacity;
  double get fillPct => (total / maxCapacity).clamp(0.0, 1.0);

  Map<String, double> get breakdown => Map.unmodifiable(_collected);

  void add(String element, double amount) {
    _collected[element] = (_collected[element] ?? 0) + amount;
    // Clamp total
    final t = total;
    if (t > maxCapacity) {
      final scale = maxCapacity / t;
      for (final k in _collected.keys.toList()) {
        _collected[k] = _collected[k]! * scale;
      }
    }
  }

  /// Remove all of a specific element from the meter.
  void removeElement(String element) {
    _collected.remove(element);
  }

  void reset() => _collected.clear();

  /// Resolve the dominant element. If a single element dominates (>50%), use
  /// it directly. Otherwise combine the top two elements to look up a recipe.
  /// Returns the element name.
  String resolveElement(Map<String, Map<String, int>>? recipes) {
    if (_collected.isEmpty) return 'Fire'; // fallback

    // Sort by amount descending
    final sorted = _collected.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = sorted.first;

    // If one element is >60% of total, it wins outright
    if (top.value / total > 0.6) return top.key;

    // Otherwise combine top two via recipe
    if (sorted.length >= 2 && recipes != null) {
      final a = sorted[0].key;
      final b = sorted[1].key;
      final key = _recipeKey(a, b);
      final recipe = recipes[key];
      if (recipe != null && recipe.isNotEmpty) {
        // Weighted roll from recipe outcomes
        return _weightedPick(recipe);
      }
    }

    return top.key;
  }

  /// Get the biome scene-key for a resolved element.
  static String sceneKeyForElement(String element) {
    final group = elementalGroupFromElementType(element);
    return switch (group) {
      ElementalGroup.volcanic => 'volcano',
      ElementalGroup.oceanic => 'swamp',
      ElementalGroup.earthen => 'valley',
      ElementalGroup.verdant => 'sky',
      ElementalGroup.arcane => 'arcane',
    };
  }

  static String _recipeKey(String a, String b) {
    final x = a.trim(), y = b.trim();
    return (x.compareTo(y) <= 0) ? '$x+$y' : '$y+$x';
  }

  static String _weightedPick(Map<String, int> dist) {
    final rng = Random();
    final totalW = dist.values.fold(0, (s, v) => s + v);
    var roll = rng.nextInt(totalW);
    for (final e in dist.entries) {
      roll -= e.value;
      if (roll < 0) return e.key;
    }
    return dist.keys.first;
  }
}

/// Map an element type string to its faction name (for portal keys / harvesters).
String factionForElement(String element) {
  final group = elementalGroupFromElementType(element);
  return switch (group) {
    ElementalGroup.volcanic => 'volcanic',
    ElementalGroup.oceanic => 'oceanic',
    ElementalGroup.earthen => 'earthen',
    ElementalGroup.verdant => 'verdant',
    ElementalGroup.arcane => 'arcane',
  };
}

// ─────────────────────────────────────────────────────────
// FOG-OF-WAR PERSISTENCE
// ─────────────────────────────────────────────────────────

/// Serialise / deserialise fog state to a compact string for SharedPreferences.
/// Now persists:
///   - worldSeed
///   - discovered planet indices
///   - ALL revealed fog-grid cells
///   - ship position
class CosmicFogState {
  final int worldSeed;
  final Set<int> discoveredIndices;
  final Set<int> discoveredPoiIndices;
  final Set<int> discoveredContestArenaIndices;
  final Set<int> revealedCells;
  final double shipX;
  final double shipY;

  const CosmicFogState({
    required this.worldSeed,
    required this.discoveredIndices,
    this.discoveredPoiIndices = const {},
    this.discoveredContestArenaIndices = const {},
    this.revealedCells = const {},
    this.shipX = -1,
    this.shipY = -1,
  });

  /// Format:
  /// seed|planetIndices|shipX,shipY|revealedCells|poiIndices|contestArenaIndices
  String serialise() {
    final pIndices = (discoveredIndices.toList()..sort()).join(',');
    final poiIndices = (discoveredPoiIndices.toList()..sort()).join(',');
    final contestIndices = (discoveredContestArenaIndices.toList()..sort())
        .join(',');
    final ship = '${shipX.toStringAsFixed(1)},${shipY.toStringAsFixed(1)}';
    // Encode revealedCells as sorted, delta-encoded ints for compactness
    final sorted = revealedCells.toList()..sort();
    final buf = StringBuffer();
    int prev = 0;
    for (var i = 0; i < sorted.length; i++) {
      if (i > 0) buf.write(',');
      buf.write(sorted[i] - prev);
      prev = sorted[i];
    }
    return '$worldSeed|$pIndices|$ship|$buf|$poiIndices|$contestIndices';
  }

  factory CosmicFogState.deserialise(String raw) {
    final parts = raw.split('|');
    final seed = int.tryParse(parts[0]) ?? 0;
    final pIndices = parts.length > 1 && parts[1].isNotEmpty
        ? parts[1].split(',').map(int.parse).toSet()
        : <int>{};

    double sx = -1, sy = -1;
    if (parts.length > 2 && parts[2].isNotEmpty) {
      final sp = parts[2].split(',');
      if (sp.length == 2) {
        sx = double.tryParse(sp[0]) ?? -1;
        sy = double.tryParse(sp[1]) ?? -1;
      }
    }

    final cells = <int>{};
    if (parts.length > 3 && parts[3].isNotEmpty) {
      int running = 0;
      for (final d in parts[3].split(',')) {
        running += int.tryParse(d) ?? 0;
        cells.add(running);
      }
    }

    final poiIndices = parts.length > 4 && parts[4].isNotEmpty
        ? parts[4].split(',').map(int.parse).toSet()
        : <int>{};
    final contestIndices = parts.length > 5 && parts[5].isNotEmpty
        ? parts[5].split(',').map(int.parse).toSet()
        : <int>{};

    return CosmicFogState(
      worldSeed: seed,
      discoveredIndices: pIndices,
      discoveredPoiIndices: poiIndices,
      discoveredContestArenaIndices: contestIndices,
      revealedCells: cells,
      shipX: sx,
      shipY: sy,
    );
  }

  factory CosmicFogState.fresh(int seed) =>
      CosmicFogState(worldSeed: seed, discoveredIndices: {});
}

// ─────────────────────────────────────────────────────────
// PLANET RECIPE
// ─────────────────────────────────────────────────────────

/// A recipe specifying the element composition needed to summon a creature
/// at a particular planet. The player must collect the right mix of particles.
class PlanetRecipe {
  final String planetElement;
  final int level; // 1..3
  final Map<String, double> components; // element -> target %
  final double randomPct; // % that can be any element

  const PlanetRecipe({
    required this.planetElement,
    required this.level,
    required this.components,
    required this.randomPct,
  });

  /// Generate a deterministic recipe for [element] at [level] (1..3).
  factory PlanetRecipe.generate({
    required String element,
    required int seed,
    required int level,
  }) {
    final recipeLevel = level.clamp(1, 3);
    final rng = Random(seed ^ (element.hashCode * 31 + recipeLevel * 997));
    final others = kElementColors.keys.where((e) => e != element).toList()
      ..shuffle(rng);

    // Difficulty curve:
    // L1: 1-2 total ingredients, L2: 2-3, L3: 3-4.
    final nSec = switch (recipeLevel) {
      1 => rng.nextBool() ? 0 : 1,
      2 => rng.nextBool() ? 1 : 2,
      _ => rng.nextBool() ? 2 : 3,
    };

    // Raw weights → normalised later
    final weights = <String, int>{};
    weights[element] = nSec == 0 ? 88 + rng.nextInt(13) : 36 + rng.nextInt(18);
    for (var i = 0; i < nSec; i++) {
      final maxW = switch (recipeLevel) {
        1 => i == 0 ? 24 : 14,
        2 => i == 0 ? 28 : 20,
        _ => i == 0 ? 30 : 22,
      };
      weights[others[i]] = 5 + rng.nextInt(maxW);
    }
    final randomW = switch (recipeLevel) {
      1 => 4 + rng.nextInt(8),
      2 => 3 + rng.nextInt(7),
      _ => 2 + rng.nextInt(6),
    };
    final totalW = weights.values.fold(0, (s, v) => s + v) + randomW;

    final components = <String, double>{};
    for (final e in weights.entries) {
      components[e.key] = (e.value / totalW * 100).roundToDouble();
    }
    final assignedPct = components.values.fold(0.0, (s, v) => s + v);

    return PlanetRecipe(
      planetElement: element,
      level: recipeLevel,
      components: components,
      randomPct: max(0, 100.0 - assignedPct),
    );
  }

  /// Match score 0.0 – 1.0. 1.0 = perfect match.
  double matchScore(Map<String, double> meterBreakdown, double meterTotal) {
    if (meterTotal <= 0) return 0;

    final pcts = <String, double>{};
    for (final e in meterBreakdown.entries) {
      pcts[e.key] = (e.value / meterTotal) * 100;
    }

    double diff = 0;
    for (final e in components.entries) {
      diff += ((pcts[e.key] ?? 0) - e.value).abs();
    }

    double nonRecipe = 0;
    for (final e in pcts.entries) {
      if (!components.containsKey(e.key)) nonRecipe += e.value;
    }
    diff += max(0.0, nonRecipe - randomPct);

    return (1.0 - diff / 100).clamp(0.0, 1.0);
  }

  /// Whether the meter matches closely enough to summon (≥ 70 %).
  bool matches(Map<String, double> meterBreakdown, double meterTotal) =>
      matchScore(meterBreakdown, meterTotal) >= 0.70;
}

// ─────────────────────────────────────────────────────────
// RECIPE STATE PERSISTENCE
// ─────────────────────────────────────────────────────────

/// Tracks per-element recipe progression across 3 levels.
class CosmicRecipeState {
  final Map<String, int> unlockedLevels; // element -> max unlocked level (1..3)
  final Map<String, int> completedMasks; // bit0=L1, bit1=L2, bit2=L3
  final Map<String, int>
  postMaxRollLevels; // element -> active random level 1..3

  const CosmicRecipeState({
    required this.unlockedLevels,
    required this.completedMasks,
    required this.postMaxRollLevels,
  });

  int unlockedLevelFor(String element) =>
      (unlockedLevels[element] ?? 1).clamp(1, 3);

  int completedMaskFor(String element) => completedMasks[element] ?? 0;

  bool isLevelCompleted(String element, int level) {
    final bit = 1 << (level.clamp(1, 3) - 1);
    return (completedMaskFor(element) & bit) != 0;
  }

  bool isMaxMastered(String element) =>
      (completedMaskFor(element) & 0x7) == 0x7;

  int activeLevelFor(String element, {required int seed}) {
    if (!isMaxMastered(element)) return unlockedLevelFor(element);
    final rolled = postMaxRollLevels[element];
    if (rolled != null && rolled >= 1 && rolled <= 3) return rolled;
    final rng = Random(seed ^ element.hashCode ^ 0xA11CE);
    return 1 + rng.nextInt(3);
  }

  CosmicRecipeState onRecipeSuccess(
    String element,
    int level, {
    required Random rng,
  }) {
    final targetLevel = level.clamp(1, 3);
    final updatedUnlocked = Map<String, int>.from(unlockedLevels);
    final updatedMasks = Map<String, int>.from(completedMasks);
    final updatedPostMax = Map<String, int>.from(postMaxRollLevels);

    final bit = 1 << (targetLevel - 1);
    final newMask = (updatedMasks[element] ?? 0) | bit;
    updatedMasks[element] = newMask;

    final currentUnlocked = (updatedUnlocked[element] ?? 1).clamp(1, 3);
    if (targetLevel == currentUnlocked && currentUnlocked < 3) {
      updatedUnlocked[element] = currentUnlocked + 1;
    }

    if ((newMask & 0x7) == 0x7) {
      updatedPostMax[element] = 1 + rng.nextInt(3);
    } else {
      updatedPostMax.remove(element);
    }

    return CosmicRecipeState(
      unlockedLevels: updatedUnlocked,
      completedMasks: updatedMasks,
      postMaxRollLevels: updatedPostMax,
    );
  }

  String serialise() {
    final keys = <String>{
      ...unlockedLevels.keys,
      ...completedMasks.keys,
      ...postMaxRollLevels.keys,
    }.toList()..sort();
    return keys
        .map((k) {
          final unlocked = unlockedLevelFor(k);
          final mask = completedMaskFor(k);
          final roll = postMaxRollLevels[k] ?? 0;
          return '$k=$unlocked|$mask|$roll';
        })
        .join(',');
  }

  factory CosmicRecipeState.deserialise(String raw) {
    if (raw.isEmpty) {
      return const CosmicRecipeState(
        unlockedLevels: {},
        completedMasks: {},
        postMaxRollLevels: {},
      );
    }
    final unlocked = <String, int>{};
    final masks = <String, int>{};
    final rolls = <String, int>{};
    for (final part in raw.split(',')) {
      if (part.contains('=')) {
        final kv = part.split('=');
        if (kv.length != 2) continue;
        final key = kv[0];
        final segs = kv[1].split('|');
        final unlockedLevel = (int.tryParse(segs[0]) ?? 1).clamp(1, 3);
        final mask = segs.length > 1 ? (int.tryParse(segs[1]) ?? 0) : 0;
        final roll = segs.length > 2 ? (int.tryParse(segs[2]) ?? 0) : 0;
        unlocked[key] = unlockedLevel;
        masks[key] = mask & 0x7;
        if (roll >= 1 && roll <= 3) rolls[key] = roll;
      } else {
        // Backward compatibility with old format: "element:version".
        final kv = part.split(':');
        if (kv.length != 2) continue;
        final key = kv[0];
        final version = int.tryParse(kv[1]) ?? 0;
        final completed = version.clamp(0, 3);
        final mask = completed <= 0 ? 0 : ((1 << completed) - 1);
        unlocked[key] = (completed + 1).clamp(1, 3);
        masks[key] = mask;
      }
    }
    return CosmicRecipeState(
      unlockedLevels: unlocked,
      completedMasks: masks,
      postMaxRollLevels: rolls,
    );
  }

  factory CosmicRecipeState.fresh() => const CosmicRecipeState(
    unlockedLevels: {},
    completedMasks: {},
    postMaxRollLevels: {},
  );
}

// ─────────────────────────────────────────────────────────
// ELEMENT PARTICLE STORAGE
// ─────────────────────────────────────────────────────────

/// Banked elemental particles for later use. Requires the Element Container.
class ElementStorage {
  final Map<String, double> stored;

  ElementStorage({Map<String, double>? stored}) : stored = stored ?? {};

  double get total => stored.values.fold(0.0, (s, v) => s + v);

  void addAll(Map<String, double> particles) {
    for (final e in particles.entries) {
      stored[e.key] = (stored[e.key] ?? 0) + e.value;
    }
  }

  String serialise() => stored.entries
      .where((e) => e.value > 0)
      .map((e) => '${e.key}:${e.value.toStringAsFixed(1)}')
      .join(',');

  factory ElementStorage.deserialise(String raw) {
    if (raw.isEmpty) return ElementStorage();
    final map = <String, double>{};
    for (final part in raw.split(',')) {
      final kv = part.split(':');
      if (kv.length == 2) map[kv[0]] = double.tryParse(kv[1]) ?? 0;
    }
    return ElementStorage(stored: map);
  }
}

// ─────────────────────────────────────────────────────────
// HOME PLANET
// ─────────────────────────────────────────────────────────

/// Data model for the player's personal home planet.
/// Built at the ship's current position — only one per world.
class HomePlanet {
  Offset position;
  double radius;
  Map<String, double> colorMix; // element -> amount (determines color)
  int astralBank; // banked Astral Shards
  int sizeTierLevel; // max unlocked tier: 0=Tiny,1=Small,2=Medium,3=Big,4=Huge
  int activeSizeTier; // currently selected tier (≤ sizeTierLevel)
  String? activeColor; // selected element colour (null = default gray)
  Set<String> unlockedColors; // element names whose colours have been purchased

  /// Cost in elements to unlock a colour.
  static const int colorUnlockCost = 500;

  /// Shard cost to upgrade TO each tier index.
  static const List<int> tierUpgradeCosts = [0, 50, 150, 400, 1000];
  static const List<String> tierNames = [
    'Tiny',
    'Small',
    'Medium',
    'Big',
    'Huge',
  ];

  HomePlanet({
    required this.position,
    this.radius = 80,
    Map<String, double>? colorMix,
    this.astralBank = 0,
    this.sizeTierLevel = 0,
    int? activeSizeTier,
    this.activeColor,
    Set<String>? unlockedColors,
  }) : colorMix = colorMix ?? {},
       activeSizeTier = activeSizeTier ?? 0,
       unlockedColors = unlockedColors ?? {};

  /// Planet colour — uses selected element colour, or default gray.
  Color get blendedColor {
    if (activeColor != null && kElementColors.containsKey(activeColor)) {
      return kElementColors[activeColor]!;
    }
    return const Color(0xFF607D8B); // default gray
  }

  /// Visual growth: radius based on the *active* (selected) tier.
  /// Tiny→40, Small→80, Medium→130, Big→185, Huge→250.
  double get visualRadius {
    return switch (activeSizeTier.clamp(0, 4)) {
      0 => 40.0,
      1 => 80.0,
      2 => 130.0,
      3 => 185.0,
      _ => 250.0,
    };
  }

  /// Current (active) size tier name.
  String get sizeTier => tierNames[activeSizeTier.clamp(0, 4)];

  /// The index (0-4) of the active size tier.
  int get sizeTierIndex => activeSizeTier.clamp(0, 4);

  /// Cost in shards to upgrade to the next tier, or null if already max.
  int? get nextTierCost {
    if (sizeTierLevel >= 4) return null;
    return tierUpgradeCosts[sizeTierLevel + 1];
  }

  String serialise() {
    final parts = <String>[];
    parts.add(
      '${position.dx.toStringAsFixed(1)},${position.dy.toStringAsFixed(1)}',
    );
    parts.add(radius.toStringAsFixed(1));
    parts.add(
      colorMix.entries
          .where((e) => e.value > 0)
          .map((e) => '${e.key}=${e.value.toStringAsFixed(1)}')
          .join(';'),
    );
    parts.add(astralBank.toString());
    parts.add(sizeTierLevel.toString());
    parts.add(activeSizeTier.toString());
    parts.add(activeColor ?? '');
    parts.add(unlockedColors.join(','));
    return parts.join('|');
  }

  factory HomePlanet.deserialise(String raw) {
    final parts = raw.split('|');
    if (parts.length < 3) {
      return HomePlanet(position: const Offset(12000, 12000));
    }
    final posParts = parts[0].split(',');
    final pos = Offset(
      double.tryParse(posParts[0]) ?? 12000,
      double.tryParse(posParts[1]) ?? 12000,
    );
    final radius = double.tryParse(parts[1]) ?? 80;
    final colorMix = <String, double>{};
    if (parts[2].isNotEmpty) {
      for (final kv in parts[2].split(';')) {
        final pair = kv.split('=');
        if (pair.length == 2) {
          colorMix[pair[0]] = double.tryParse(pair[1]) ?? 0;
        }
      }
    }
    final bank = parts.length > 3 ? (int.tryParse(parts[3]) ?? 0) : 0;
    final tier = parts.length > 4 ? (int.tryParse(parts[4]) ?? 0) : 0;
    final active = parts.length > 5 ? (int.tryParse(parts[5]) ?? tier) : tier;
    final colorStr = parts.length > 6 ? parts[6] : '';
    final unlockedStr = parts.length > 7 ? parts[7] : '';
    final unlocked = unlockedStr.isNotEmpty
        ? unlockedStr.split(',').toSet()
        : <String>{};
    return HomePlanet(
      position: pos,
      radius: radius,
      colorMix: colorMix,
      astralBank: bank,
      sizeTierLevel: tier,
      activeSizeTier: active,
      activeColor: colorStr.isNotEmpty ? colorStr : null,
      unlockedColors: unlocked,
    );
  }
}

// ─────────────────────────────────────────────────────────
// HOME CUSTOMIZATION RECIPES
// ─────────────────────────────────────────────────────────

/// Category of a home customization recipe.
enum HomeRecipeCategory { visual, ammo, upgrade, equipment }

/// A single tuneable parameter for a visual customization.
class CustomizationParam {
  final String key;
  final String label;
  final List<String> options;
  final String defaultValue;

  const CustomizationParam({
    required this.key,
    required this.label,
    required this.options,
    required this.defaultValue,
  });
}

/// Per-recipe sub-customization options. Only visual recipes with
/// tuneable parameters appear here.
const Map<String, List<CustomizationParam>> kRecipeParams = {
  'flame_ring': [
    CustomizationParam(
      key: 'intensity',
      label: 'Intensity',
      options: ['Dim', 'Normal', 'Bright'],
      defaultValue: 'Normal',
    ),
    CustomizationParam(
      key: 'speed',
      label: 'Speed',
      options: ['Slow', 'Normal', 'Fast'],
      defaultValue: 'Normal',
    ),
  ],
  'vine_tendrils': [
    CustomizationParam(
      key: 'length',
      label: 'Length',
      options: ['Short', 'Medium', 'Long'],
      defaultValue: 'Medium',
    ),
    CustomizationParam(
      key: 'count',
      label: 'Count',
      options: ['Few', 'Some', 'Many'],
      defaultValue: 'Some',
    ),
  ],
  'crystal_spires': [
    CustomizationParam(
      key: 'height',
      label: 'Height',
      options: ['Short', 'Medium', 'Tall'],
      defaultValue: 'Medium',
    ),
    CustomizationParam(
      key: 'density',
      label: 'Density',
      options: ['Sparse', 'Normal', 'Dense'],
      defaultValue: 'Normal',
    ),
  ],
  'dark_void': [
    CustomizationParam(
      key: 'layers',
      label: 'Layers',
      options: ['Thin', 'Normal', 'Deep'],
      defaultValue: 'Normal',
    ),
  ],
  'radiant_halo': [
    CustomizationParam(
      key: 'glow',
      label: 'Glow',
      options: ['Subtle', 'Normal', 'Blinding'],
      defaultValue: 'Normal',
    ),
    CustomizationParam(
      key: 'position',
      label: 'Position',
      options: ['Close', 'Mid', 'Outer'],
      defaultValue: 'Mid',
    ),
  ],
  'ocean_mist': [
    CustomizationParam(
      key: 'density',
      label: 'Density',
      options: ['Light', 'Normal', 'Heavy'],
      defaultValue: 'Normal',
    ),
    CustomizationParam(
      key: 'position',
      label: 'Position',
      options: ['Close', 'Mid', 'Outer'],
      defaultValue: 'Mid',
    ),
  ],
  'blood_moon': [
    CustomizationParam(
      key: 'pulse',
      label: 'Pulse',
      options: ['Gentle', 'Normal', 'Intense'],
      defaultValue: 'Normal',
    ),
  ],
  'frozen_shell': [
    CustomizationParam(
      key: 'thickness',
      label: 'Thickness',
      options: ['Thin', 'Medium', 'Thick'],
      defaultValue: 'Medium',
    ),
  ],
  'poison_cloud': [
    CustomizationParam(
      key: 'spread',
      label: 'Spread',
      options: ['Tight', 'Normal', 'Wide'],
      defaultValue: 'Normal',
    ),
    CustomizationParam(
      key: 'position',
      label: 'Position',
      options: ['Close', 'Mid', 'Outer'],
      defaultValue: 'Mid',
    ),
  ],
  'dust_storm': [
    CustomizationParam(
      key: 'particles',
      label: 'Particles',
      options: ['Few', 'Normal', 'Swarm'],
      defaultValue: 'Normal',
    ),
    CustomizationParam(
      key: 'position',
      label: 'Position',
      options: ['Close', 'Mid', 'Outer'],
      defaultValue: 'Mid',
    ),
  ],
  'steam_vents': [
    CustomizationParam(
      key: 'jets',
      label: 'Jets',
      options: ['2', '4', '6'],
      defaultValue: '4',
    ),
  ],
  'lightning_rod': [
    CustomizationParam(
      key: 'frequency',
      label: 'Frequency',
      options: ['Rare', 'Normal', 'Frequent'],
      defaultValue: 'Normal',
    ),
  ],
  'spirit_wisps': [
    CustomizationParam(
      key: 'count',
      label: 'Count',
      options: ['Few', 'Some', 'Many'],
      defaultValue: 'Some',
    ),
    CustomizationParam(
      key: 'position',
      label: 'Position',
      options: ['Close', 'Mid', 'Outer'],
      defaultValue: 'Mid',
    ),
  ],
  'lava_moat': [
    CustomizationParam(
      key: 'width',
      label: 'Width',
      options: ['Thin', 'Normal', 'Wide'],
      defaultValue: 'Normal',
    ),
  ],
  'mud_fortress': [
    CustomizationParam(
      key: 'thickness',
      label: 'Thickness',
      options: ['Thin', 'Normal', 'Thick'],
      defaultValue: 'Normal',
    ),
  ],
  'natures_blessing': [
    CustomizationParam(
      key: 'brightness',
      label: 'Brightness',
      options: ['Dim', 'Normal', 'Bright'],
      defaultValue: 'Normal',
    ),
    CustomizationParam(
      key: 'position',
      label: 'Position',
      options: ['Close', 'Mid', 'Outer'],
      defaultValue: 'Mid',
    ),
  ],
  'orbiting_moon': [
    CustomizationParam(
      key: 'size',
      label: 'Moon Size',
      options: ['Small', 'Medium', 'Large'],
      defaultValue: 'Medium',
    ),
    CustomizationParam(
      key: 'speed',
      label: 'Orbit Speed',
      options: ['Slow', 'Normal', 'Fast'],
      defaultValue: 'Normal',
    ),
  ],
};

/// A hidden recipe that unlocks a cosmetic/functional upgrade for the home
/// planet or ship. Ingredients come from [ElementStorage].
class HomeRecipe {
  final String id;
  final String name;
  final String description;
  final HomeRecipeCategory category;
  final Map<String, int> ingredients; // element -> amount required
  final String iconName; // material icon name hint (resolved in UI)

  const HomeRecipe({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.ingredients,
    this.iconName = 'auto_awesome',
  });
}

/// The 20 built-in home customization recipes.
const List<HomeRecipe> kHomeRecipes = [
  // ── Visual (planet decorations) ──
  HomeRecipe(
    id: 'flame_ring',
    name: 'Flame Ring',
    description: 'A blazing ring of fire orbits your home planet.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Fire': 500},
    iconName: 'local_fire_department',
  ),
  HomeRecipe(
    id: 'vine_tendrils',
    name: 'Vine Tendrils',
    description: 'Living vines reach out from your planet\'s surface.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Plant': 100},
    iconName: 'eco',
  ),
  HomeRecipe(
    id: 'crystal_spires',
    name: 'Crystal Spires',
    description: 'Towering crystal formations erupt from the crust.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Crystal': 200, 'Earth': 100},
    iconName: 'diamond',
  ),
  HomeRecipe(
    id: 'dark_void',
    name: 'Dark Void',
    description: 'An ominous dark-matter aura warps space around your planet.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Dark': 300, 'Spirit': 100},
    iconName: 'brightness_3',
  ),
  HomeRecipe(
    id: 'radiant_halo',
    name: 'Radiant Halo',
    description: 'A golden halo of light crowns your world.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Light': 300, 'Air': 100},
    iconName: 'wb_sunny',
  ),
  HomeRecipe(
    id: 'ocean_mist',
    name: 'Ocean Mist',
    description: 'A fine water vapour shimmers around the planet.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Water': 200, 'Steam': 100},
    iconName: 'water',
  ),
  HomeRecipe(
    id: 'blood_moon',
    name: 'Blood Moon',
    description: 'The planet pulses with a deep crimson heartbeat.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Blood': 400},
    iconName: 'nightlight',
  ),
  HomeRecipe(
    id: 'frozen_shell',
    name: 'Frozen Shell',
    description: 'An icy crystalline shell encases the planet.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Ice': 200, 'Crystal': 50},
    iconName: 'ac_unit',
  ),
  HomeRecipe(
    id: 'poison_cloud',
    name: 'Poison Cloud',
    description: 'A toxic green miasma drifts around your world.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Poison': 150, 'Plant': 50},
    iconName: 'science',
  ),
  HomeRecipe(
    id: 'dust_storm',
    name: 'Dust Storm',
    description: 'Orbiting dust particles form a swirling storm.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Dust': 300, 'Air': 100},
    iconName: 'grain',
  ),
  HomeRecipe(
    id: 'steam_vents',
    name: 'Steam Vents',
    description: 'Erupting geysers blast jets of steam skyward.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Steam': 150, 'Fire': 100},
    iconName: 'hot_tub',
  ),
  HomeRecipe(
    id: 'lightning_rod',
    name: 'Lightning Rod',
    description: 'Bolts of electricity arc down to the surface.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Lightning': 200, 'Crystal': 100},
    iconName: 'flash_on',
  ),
  HomeRecipe(
    id: 'lava_moat',
    name: 'Lava Moat',
    description: 'A molten ring of lava guards your planet.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Lava': 300, 'Fire': 100},
    iconName: 'whatshot',
  ),
  HomeRecipe(
    id: 'spirit_wisps',
    name: 'Spirit Wisps',
    description: 'Ethereal ghost-lights float around your world.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Spirit': 200, 'Light': 100},
    iconName: 'blur_on',
  ),
  HomeRecipe(
    id: 'mud_fortress',
    name: 'Mud Fortress',
    description: 'A thick protective shell of hardened mud.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Mud': 200, 'Earth': 200},
    iconName: 'fort',
  ),
  HomeRecipe(
    id: 'natures_blessing',
    name: 'Nature\'s Blessing',
    description:
        'All 17 elements harmonise — your planet radiates every colour.',
    category: HomeRecipeCategory.visual,
    ingredients: {
      'Fire': 30,
      'Water': 30,
      'Earth': 30,
      'Air': 30,
      'Steam': 30,
      'Lava': 30,
      'Lightning': 30,
      'Mud': 30,
      'Ice': 30,
      'Dust': 30,
      'Crystal': 30,
      'Plant': 30,
      'Poison': 30,
      'Spirit': 30,
      'Dark': 30,
      'Light': 30,
      'Blood': 30,
    },
    iconName: 'all_inclusive',
  ),
  HomeRecipe(
    id: 'orbiting_moon',
    name: 'Orbiting Moon',
    description: 'A small moon orbits your planet. Requires Big size tier.',
    category: HomeRecipeCategory.visual,
    ingredients: {'Earth': 300, 'Crystal': 200, 'Dark': 100},
    iconName: 'nightlight_round',
  ),

  // Cargo Hold is handled specially as a leveled upgrade (see CargoUpgrade).

  // ── Base stations ──
  HomeRecipe(
    id: 'refuel_station',
    name: 'Refuel Station',
    description:
        'Constructs a fuel depot at your home base. Refuel for free when docked at home.',
    category: HomeRecipeCategory.upgrade,
    ingredients: {'Fire': 200, 'Crystal': 150, 'Lava': 100},
    iconName: 'local_gas_station',
  ),
  HomeRecipe(
    id: 'missile_station',
    name: 'Missile Station',
    description:
        'Constructs a missile fabricator at your home base. Reload missiles for free when docked at home.',
    category: HomeRecipeCategory.upgrade,
    ingredients: {'Dark': 200, 'Fire': 150, 'Crystal': 100},
    iconName: 'rocket',
  ),
  HomeRecipe(
    id: 'sentinel_station',
    name: 'Sentinel Station',
    description:
        'Constructs a sentinel bay at your home base. Replenish orbital sentinels for free when docked at home.',
    category: HomeRecipeCategory.upgrade,
    ingredients: {'Crystal': 250, 'Earth': 200, 'Dust': 150},
    iconName: 'shield',
  ),

  // ── Ammo upgrades ──
  HomeRecipe(
    id: 'storm_bolts',
    name: 'Storm Bolts',
    description: 'Electrified ammo that crackles with lightning.',
    category: HomeRecipeCategory.ammo,
    ingredients: {'Fire': 50, 'Lightning': 50},
    iconName: 'bolt',
  ),
  HomeRecipe(
    id: 'plasma_bolts',
    name: 'Plasma Bolts',
    description: 'Superheated plasma projectiles that glow white-hot.',
    category: HomeRecipeCategory.ammo,
    ingredients: {'Lightning': 100, 'Fire': 100},
    iconName: 'offline_bolt',
  ),
  HomeRecipe(
    id: 'ice_shards',
    name: 'Ice Shards',
    description: 'Frozen crystalline shards that shatter on impact.',
    category: HomeRecipeCategory.ammo,
    ingredients: {'Ice': 100, 'Crystal': 50},
    iconName: 'ac_unit',
  ),
  HomeRecipe(
    id: 'void_cannon',
    name: 'Void Cannon',
    description: 'Dark-energy projectiles that consume light.',
    category: HomeRecipeCategory.ammo,
    ingredients: {'Dark': 200, 'Blood': 100},
    iconName: 'remove_circle',
  ),

  // ── Equipment (ship systems) ──
  HomeRecipe(
    id: 'equip_booster',
    name: 'Ion Booster',
    description:
        'Enables afterburner boost. Consumes fuel from elemental particles.',
    category: HomeRecipeCategory.equipment,
    ingredients: {'Fire': 300, 'Crystal': 100},
    iconName: 'rocket_launch',
  ),
  HomeRecipe(
    id: 'equip_machinegun',
    name: 'Pulse Repeater',
    description:
        'Rapid-fire energy bolts. High fire rate, low damage per shot.',
    category: HomeRecipeCategory.equipment,
    ingredients: {'Fire': 150, 'Lava': 100},
    iconName: 'flash_on',
  ),
  HomeRecipe(
    id: 'equip_missiles',
    name: 'Seeker Missiles',
    description:
        'Homing projectiles that track the nearest enemy. Slower fire rate, devastating damage.',
    category: HomeRecipeCategory.equipment,
    ingredients: {'Dark': 150, 'Fire': 100, 'Crystal': 50},
    iconName: 'gps_fixed',
  ),
  HomeRecipe(
    id: 'equip_orbitals',
    name: 'Orbital Sentinels',
    description:
        'Shield drones orbit your ship and block enemies on contact. Up to 3 active; auto-replenish from stockpile of 50+.',
    category: HomeRecipeCategory.equipment,
    ingredients: {'Crystal': 200, 'Earth': 150, 'Lava': 100},
    iconName: 'shield',
  ),

  // ── Ship designs (skins) ──
  HomeRecipe(
    id: 'skin_phantom',
    name: 'Phantom Viper',
    description:
        'A stealth-plated hull with a dark-matter exhaust trail. The ship becomes a slender, angular silhouette with violet engine glow.',
    category: HomeRecipeCategory.equipment,
    ingredients: {'Dark': 250, 'Spirit': 150, 'Crystal': 100},
    iconName: 'visibility_off',
  ),
  HomeRecipe(
    id: 'skin_solar',
    name: 'Solar Dragoon',
    description:
        'A blazing golden hull forged from concentrated light and fire. Trailing solar flares and a radiant amber cockpit.',
    category: HomeRecipeCategory.equipment,
    ingredients: {'Fire': 200, 'Light': 200, 'Lava': 100},
    iconName: 'wb_sunny',
  ),
];

/// Persisted state of which home recipes are unlocked and which are active.
/// Also stores per-recipe sub-customization option values.
class HomeCustomizationState {
  final Set<String> unlockedIds;
  final Set<String> activeIds;

  /// Per-recipe sub-customization values.
  /// Key = 'recipeId.paramKey', Value = chosen option string.
  final Map<String, String> options;

  /// Power-up levels for ship ammo and missiles (0-5).
  int ammoUpgradeLevel;
  int missileUpgradeLevel;

  /// Fuel tank upgrade level (0-3). Level 3 = double capacity.
  int fuelUpgradeLevel;

  /// Shard costs for each upgrade stage (index 0 = cost for level 1, etc.).
  static const List<int> upgradeCosts = [100, 500, 1500, 3000, 5000];

  /// Fuel tank upgrade costs (3 levels). Level 3 = double capacity.
  static const List<int> fuelUpgradeCosts = [200, 800, 2000];

  /// Maximum fuel upgrade level.
  static const int maxFuelUpgradeLevel = 3;

  /// Maximum upgrade level.
  static const int maxUpgradeLevel = 5;

  /// Damage multiplier for a given upgrade level (80% at max).
  static double damageMultiplier(int level) => 1.0 + level * 0.16;

  HomeCustomizationState({
    Set<String>? unlockedIds,
    Set<String>? activeIds,
    Map<String, String>? options,
    this.ammoUpgradeLevel = 0,
    this.missileUpgradeLevel = 0,
    this.fuelUpgradeLevel = 0,
  }) : unlockedIds = unlockedIds ?? {},
       activeIds = activeIds ?? {},
       options = options ?? {};

  /// Get a sub-customization value, falling back to default.
  String getOption(String recipeId, String paramKey) {
    final stored = options['$recipeId.$paramKey'];
    if (stored != null) return stored;
    final params = kRecipeParams[recipeId];
    if (params != null) {
      for (final p in params) {
        if (p.key == paramKey) return p.defaultValue;
      }
    }
    return '';
  }

  /// Set a sub-customization value.
  void setOption(String recipeId, String paramKey, String value) {
    options['$recipeId.$paramKey'] = value;
  }

  bool isUnlocked(String id) => unlockedIds.contains(id);
  bool isActive(String id) => activeIds.contains(id);

  /// Try to unlock a recipe by spending from [storage].
  /// Returns true if successful.
  bool tryUnlock(String recipeId, ElementStorage storage) {
    if (unlockedIds.contains(recipeId)) return false;
    final recipe = kHomeRecipes.cast<HomeRecipe?>().firstWhere(
      (r) => r!.id == recipeId,
      orElse: () => null,
    );
    if (recipe == null) return false;

    // Check if all ingredients are available
    for (final e in recipe.ingredients.entries) {
      if ((storage.stored[e.key] ?? 0) < e.value) return false;
    }

    // Spend ingredients
    for (final e in recipe.ingredients.entries) {
      storage.stored[e.key] = (storage.stored[e.key] ?? 0) - e.value;
    }
    unlockedIds.add(recipeId);
    // Auto-activate on unlock, but respect mutual-exclusion groups
    if (_weaponIds.contains(recipeId)) {
      activeIds.removeAll(_weaponIds);
    }
    if (_ammoIds.contains(recipeId)) {
      activeIds.removeAll(_ammoIds);
    }
    if (_skinIds.contains(recipeId)) {
      activeIds.removeAll(_skinIds);
    }
    activeIds.add(recipeId);
    return true;
  }

  /// Weapon IDs that are mutually exclusive — only one active at a time.
  static const _weaponIds = {'equip_machinegun', 'equip_missiles'};

  /// Ammo IDs that are mutually exclusive — only one active at a time.
  static const _ammoIds = {
    'storm_bolts',
    'plasma_bolts',
    'ice_shards',
    'void_cannon',
  };

  /// Ship skin IDs that are mutually exclusive — only one active at a time.
  static const _skinIds = {'skin_phantom', 'skin_solar'};

  void toggle(String id) {
    if (!unlockedIds.contains(id)) return;
    if (activeIds.contains(id)) {
      activeIds.remove(id);
    } else {
      // If this is a weapon, deactivate other weapons first
      if (_weaponIds.contains(id)) {
        activeIds.removeAll(_weaponIds);
      }
      // If this is ammo, deactivate other ammo first
      if (_ammoIds.contains(id)) {
        activeIds.removeAll(_ammoIds);
      }
      // If this is a ship skin, deactivate other skins first
      if (_skinIds.contains(id)) {
        activeIds.removeAll(_skinIds);
      }
      activeIds.add(id);
    }
  }

  /// Get the currently active ammo recipe (only one at a time, last wins).
  HomeRecipe? get activeAmmo {
    for (final r in kHomeRecipes.reversed) {
      if (r.category == HomeRecipeCategory.ammo && activeIds.contains(r.id)) {
        return r;
      }
    }
    return null;
  }

  String serialise() {
    final u = unlockedIds.toList()..sort();
    final a = activeIds.toList()..sort();
    // Third segment: sub-customization options as key~value pairs
    final o = options.entries.map((e) => '${e.key}~${e.value}').toList()
      ..sort();
    // Fourth segment: power-up levels
    return '${u.join(",")}|${a.join(",")}|${o.join(",")}|$ammoUpgradeLevel,$missileUpgradeLevel,$fuelUpgradeLevel';
  }

  factory HomeCustomizationState.deserialise(String raw) {
    if (raw.isEmpty) return HomeCustomizationState();
    final parts = raw.split('|');
    final u = parts[0].isNotEmpty ? parts[0].split(',').toSet() : <String>{};
    final a = parts.length > 1 && parts[1].isNotEmpty
        ? parts[1].split(',').toSet()
        : <String>{};
    final opts = <String, String>{};
    if (parts.length > 2 && parts[2].isNotEmpty) {
      for (final kv in parts[2].split(',')) {
        final pair = kv.split('~');
        if (pair.length == 2) opts[pair[0]] = pair[1];
      }
    }
    // Fourth segment: power-up levels
    int ammoLvl = 0;
    int missileLvl = 0;
    int fuelLvl = 0;
    if (parts.length > 3 && parts[3].isNotEmpty) {
      final lvls = parts[3].split(',');
      if (lvls.isNotEmpty) ammoLvl = int.tryParse(lvls[0]) ?? 0;
      if (lvls.length > 1) missileLvl = int.tryParse(lvls[1]) ?? 0;
      if (lvls.length > 2) fuelLvl = int.tryParse(lvls[2]) ?? 0;
    }
    return HomeCustomizationState(
      unlockedIds: u,
      activeIds: a,
      options: opts,
      ammoUpgradeLevel: ammoLvl,
      missileUpgradeLevel: missileLvl,
      fuelUpgradeLevel: fuelLvl,
    );
  }

  /// Get the currently active primary weapon type (gun).
  String? get activeWeapon {
    const weapons = ['equip_machinegun'];
    for (final id in weapons.reversed) {
      if (activeIds.contains(id)) return id;
    }
    return null; // default gun
  }

  bool get hasBooster => activeIds.contains('equip_booster');
  bool get hasMissiles =>
      unlockedIds.contains('equip_missiles') &&
      activeIds.contains('equip_missiles');
  bool get hasOrbitals =>
      unlockedIds.contains('equip_orbitals') &&
      activeIds.contains('equip_orbitals');
  bool get hasRefuelStation => unlockedIds.contains('refuel_station');
  bool get hasMissileStation => unlockedIds.contains('missile_station');
  bool get hasSentinelStation => unlockedIds.contains('sentinel_station');

  /// Currently active ship skin ID (null = default look).
  String? get activeShipSkin {
    for (final id in _skinIds) {
      if (activeIds.contains(id)) return id;
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────
// SHIP FUEL
// ─────────────────────────────────────────────────────────

/// Fuel for the ship booster. Crafted from elemental particles at home.
class ShipFuel {
  double fuel;
  double capacity;

  ShipFuel({this.fuel = 0.0, this.capacity = 100.0});

  /// Compute capacity based on fuel upgrade level.
  /// Level 0 = 100, Level 1 = 125, Level 2 = 150, Level 3 = 200 (double).
  static double capacityForLevel(int level) {
    switch (level) {
      case 1:
        return 125.0;
      case 2:
        return 150.0;
      case 3:
        return 200.0;
      default:
        return 100.0;
    }
  }

  bool get isEmpty => fuel <= 0;
  bool get isFull => fuel >= capacity;
  double get fraction => capacity > 0 ? (fuel / capacity).clamp(0.0, 1.0) : 0;

  /// Consume fuel. Returns actual amount consumed.
  double consume(double amount) {
    final used = amount.clamp(0.0, fuel);
    fuel -= used;
    return used;
  }

  /// Add fuel (capped at capacity). Returns amount actually added.
  double add(double amount) {
    final space = capacity - fuel;
    final added = amount.clamp(0.0, space);
    fuel += added;
    return added;
  }

  /// Cost per fuel unit: specific elements.
  static const Map<String, int> fuelCost = {'Fire': 8, 'Crystal': 2};

  /// Cost per missile: specific elements.
  static const Map<String, int> missileCost = {'Dark': 3, 'Fire': 2};

  /// Max missiles that can be carried.
  static const int maxMissileAmmo = 50;

  String serialise() =>
      '${fuel.toStringAsFixed(2)}|${capacity.toStringAsFixed(2)}';

  factory ShipFuel.deserialise(String raw) {
    if (raw.isEmpty) return ShipFuel();
    final parts = raw.split('|');
    return ShipFuel(
      fuel: double.tryParse(parts[0]) ?? 0,
      capacity: parts.length > 1 ? (double.tryParse(parts[1]) ?? 100) : 100,
    );
  }
}

// ─────────────────────────────────────────────────────────
// ORBITAL SENTINEL
// ─────────────────────────────────────────────────────────

/// A defensive drone orbiting the ship.
class OrbitalSentinel {
  double angle; // current orbital angle
  double health; // dies at 0
  double spawnOpacity; // 0→1 fade-in on spawn
  static const double maxHealth = 1.0;
  static const double orbitRadius = 50.0;
  static const double orbitSpeed = 2.5; // radians/sec
  static const double hitboxRadius = 16.0;
  static const int maxActive = 3;
  static const int autoReplenishThreshold = 50;

  /// Seconds before a destroyed sentinel respawns.
  static const double respawnCooldown = 4.0;

  /// Seconds for the fade-in animation.
  static const double fadeInDuration = 0.8;

  /// Cost per sentinel: specific elements.
  static const Map<String, int> sentinelCost = {
    'Crystal': 4,
    'Earth': 3,
    'Lava': 1,
  };

  OrbitalSentinel({
    required this.angle,
    this.health = maxHealth,
    this.spawnOpacity = 0.0,
  });

  bool get dead => health <= 0;
  bool get fullyVisible => spawnOpacity >= 1.0;

  /// While fading in, the sentinel is invulnerable so it doesn't die instantly.
  bool get invulnerable => spawnOpacity < 1.0;

  Offset positionAround(Offset center) {
    return Offset(
      center.dx + cos(angle) * orbitRadius,
      center.dy + sin(angle) * orbitRadius,
    );
  }

  void update(double dt) {
    angle += orbitSpeed * dt;
    if (spawnOpacity < 1.0) {
      spawnOpacity = (spawnOpacity + dt / fadeInDuration).clamp(0.0, 1.0);
    }
  }
}

// ─────────────────────────────────────────────────────────
// CARGO UPGRADE (leveled)
// ─────────────────────────────────────────────────────────

/// Single upgradeable cargo system. Each level increases teleport capacity
/// and costs more particles. Max level 3.
class CargoUpgrade {
  static const int maxLevel = 3;

  /// Teleport capacity per level (fraction of meter you can carry home).
  static double capacityForLevel(int level) => switch (level) {
    0 => 0.20,
    1 => 0.50,
    2 => 0.80,
    _ => 1.00, // level 3 = infinite
  };

  /// Name shown in UI per level.
  static String nameForLevel(int level) => switch (level) {
    0 => 'Basic Hull',
    1 => 'Cargo Hold',
    2 => 'Void Hold',
    _ => 'Infinite Hold',
  };

  /// Description per level.
  static String nextDescription(int level) => switch (level) {
    0 => 'Reinforce hull to carry 50% meter when teleporting home.',
    1 => 'Warp-fold bay — carry up to 80% meter home.',
    2 => 'Master space-time — teleport at any meter level.',
    _ => 'Fully upgraded.',
  };

  /// Cost to upgrade TO the next level. Returns ingredient map.
  static Map<String, int> costForNextLevel(int currentLevel) =>
      switch (currentLevel) {
        0 => {'Earth': 200, 'Crystal': 150, 'Mud': 100},
        1 => {'Dark': 300, 'Spirit': 200, 'Crystal': 150},
        2 => {'Spirit': 400, 'Light': 400, 'Dark': 300, 'Blood': 200},
        _ => {}, // already maxed
      };
}

// ─────────────────────────────────────────────────────────
// SHIP WALLET
// ─────────────────────────────────────────────────────────

/// Astral Shards the ship is carrying. Must be deposited at home to bank them.
class ShipWallet {
  int shards;

  /// Default capacity — can be upgraded via home recipes.
  int shardCapacity;

  ShipWallet({this.shards = 0, this.shardCapacity = 50});

  bool get shardsFull => shards >= shardCapacity;

  /// Try to add shards. Returns amount actually added (capped at capacity).
  int addShards(int amount) {
    final space = shardCapacity - shards;
    final added = amount.clamp(0, space);
    shards += added;
    return added;
  }

  /// Empty the wallet, returning shards that were stored.
  int depositAll() {
    final s = shards;
    shards = 0;
    return s;
  }
}

// ─────────────────────────────────────────────────────────
// LOOT DROPS
// ─────────────────────────────────────────────────────────

/// Type of loot that can drop from enemies/bosses.
enum LootType { astralShard, elementParticle, item, healthOrb }

/// A collectible loot drop that sits in world space until the ship picks it up.
class LootDrop {
  Offset position;
  Offset velocity;
  final LootType type;
  final int amount; // silver/gold quantity, or element particle amount
  final String? element; // only for elementParticle type
  final String? itemKey; // only for item type (inventory key)
  final Color color;
  double life; // seconds alive
  bool collected;

  /// Loot drops expire after 15 seconds.
  static const double maxLifetime = 15.0;

  /// Pickup radius — ship must be within this distance.
  static const double pickupRadius = 40.0;

  /// Magnetic pull radius — loot gets sucked toward ship.
  static const double magnetRadius = 100.0;

  LootDrop({
    required this.position,
    required this.velocity,
    required this.type,
    required this.amount,
    this.element,
    this.itemKey,
    required this.color,
    this.life = 0,
    this.collected = false,
  });

  /// Whether this drop has expired.
  bool get expired => life >= maxLifetime;

  /// Update position and life.
  void update(double dt) {
    life += dt;
    // Friction to slow down after burst
    velocity *= 0.96;
    position += velocity * dt;
  }
}

// ─────────────────────────────────────────────────────────
// COSMIC ENEMIES
// ─────────────────────────────────────────────────────────

/// Tier of cosmic enemy.
enum EnemyTier {
  /// Tiny flickering orb — fast, fragile.
  wisp,

  /// Round body with orbiting satellites — mid-tier.
  sentinel,

  /// Heavy armored sphere with elemental cracks — tanky.
  brute,

  /// Small geometric diamond shape — very fast glass-cannon.
  drone,

  /// Ghostly semi-transparent enemy with pulsing cloak.
  phantom,

  /// Massive slow creature with tentacle appendages — HP tank.
  colossus,
}

/// Behavior archetype — determines how the enemy acts.
enum EnemyBehavior {
  /// Actively hunts the player on sight.
  aggressive,

  /// Drifts aimlessly; harmless unless cornered.
  drifting,

  /// Clusters near asteroid belts, "feeding" on rocks.
  /// Passive until the player attacks one — then the whole pack aggros.
  feeding,

  /// Patrols a territory near a planet; attacks if player enters zone.
  territorial,

  /// Follows the player from afar; strikes only when ship HP is low.
  stalking,

  /// Tiny fast enemies that cluster and swarm together.
  swarming,
}

/// A floating alchemical enemy in the cosmos.
class CosmicEnemy {
  Offset position;
  final String element;
  final EnemyTier tier;
  final double radius;
  double health; // ≤ 0 = dead
  double speed;
  double angle; // current facing direction
  double driftTimer; // for AI direction changes
  bool dead;

  /// Current behavior archetype.
  EnemyBehavior behavior;

  /// Whether this enemy has been provoked (feeding/territorial → aggressive).
  bool provoked;

  /// Pack identifier — enemies in the same pack provoke together.
  /// -1 = solo (no pack).
  int packId;

  /// Home position for territorial / feeding enemies.
  Offset? homePos;

  /// Radius within which territorial enemies detect intruders.
  double aggroRadius;

  /// For stalkers: how close they keep to the player.
  double stalkDistance;

  /// Galaxy whirl index this enemy belongs to (-1 = none).
  int whirlIndex;

  CosmicEnemy({
    required this.position,
    required this.element,
    required this.tier,
    required this.radius,
    required this.health,
    required this.speed,
    this.angle = 0,
    this.driftTimer = 0,
    this.dead = false,
    this.behavior = EnemyBehavior.aggressive,
    this.provoked = false,
    this.packId = -1,
    this.homePos,
    this.aggroRadius = 300,
    this.stalkDistance = 500,
    this.whirlIndex = -1,
  });

  Color get color => elementColor(element);

  /// How many projectile hits to kill.
  double get maxHealth => switch (tier) {
    EnemyTier.wisp => 1.0,
    EnemyTier.drone => 0.5,
    EnemyTier.sentinel => 3.0,
    EnemyTier.phantom => 4.0,
    EnemyTier.brute => 8.0,
    EnemyTier.colossus => 15.0,
  };

  /// Astral Shards dropped on kill.
  int get shardDrop => switch (tier) {
    EnemyTier.wisp => 1,
    EnemyTier.drone => 1,
    EnemyTier.sentinel => 3,
    EnemyTier.phantom => 4,
    EnemyTier.brute => 6,
    EnemyTier.colossus => 12,
  };

  /// Element particles dropped on kill (sometimes).
  double get particleDrop => switch (tier) {
    EnemyTier.wisp => 1.0,
    EnemyTier.drone => 0.5,
    EnemyTier.sentinel => 3.0,
    EnemyTier.phantom => 3.5,
    EnemyTier.brute => 5.0,
    EnemyTier.colossus => 10.0,
  };
}

/// Boss archetype — determines AI behaviour & attack patterns.
/// Assigned based on level: 1-3 Charger, 4-7 Gunner, 8-10 Warden.
enum BossType {
  /// Lv 1-3: Charges at the player in straight dashes with brief pauses.
  charger,

  /// Lv 4-7: Orbits at range and fires projectiles; periodically raises a shield.
  gunner,

  /// Lv 8-10: Multi-phase — projectile fans, summons minions, enrages at low HP.
  warden,
}

/// Derive the [BossType] from a boss level.
BossType bossTypeForLevel(int level) {
  if (level <= 3) return BossType.charger;
  if (level <= 7) return BossType.gunner;
  return BossType.warden;
}

/// A powerful boss enemy that drops significant rewards.
class CosmicBoss {
  Offset position;
  final String name;
  final String element;
  final int level; // 1-10
  final BossType type;
  final double radius;
  double health;
  final double maxHealth;
  double speed;
  final double baseSpeed;
  double angle;
  double phaseTimer; // for attack patterns
  bool dead;

  // ── Charger state ──
  bool charging; // true while dashing
  double chargeTimer; // cooldown between charges
  double chargeDashTimer; // remaining time in current dash
  double chargeAngle; // locked angle during dash
  static const double chargeCooldown = 3.0;
  static const double chargeDashDuration = 0.6;
  static const double chargeSpeedMultiplier = 3.5;

  // ── Gunner state ──
  double shootTimer; // cooldown between shots
  bool shieldUp;
  double shieldTimer; // time until shield drops / next shield
  double shieldHealth; // absorbs hits while up
  static const double shootCooldown = 1.8;
  static const double shieldDuration = 3.0;
  static const double shieldCooldown = 8.0;
  static const double shieldMaxHealth = 6.0;

  // ── Warden state ──
  int wardenPhase; // 0 = normal, 1 = summon, 2 = enraged
  double spreadTimer; // cooldown between projectile fans
  double summonTimer; // cooldown between minion summons
  bool enraged;
  static const double spreadCooldown = 2.5;
  static const double summonCooldown = 8.0;
  static const double enrageThreshold = 0.3; // 30% HP

  CosmicBoss({
    required this.position,
    required this.name,
    required this.element,
    required this.level,
    required this.radius,
    required this.maxHealth,
    required this.speed,
    this.angle = 0,
    this.phaseTimer = 0,
    this.dead = false,
    // Charger
    this.charging = false,
    this.chargeTimer = 2.0,
    this.chargeDashTimer = 0,
    this.chargeAngle = 0,
    // Gunner
    this.shootTimer = 1.0,
    this.shieldUp = false,
    this.shieldTimer = 5.0,
    this.shieldHealth = 0,
    // Warden
    this.wardenPhase = 0,
    this.spreadTimer = 2.0,
    this.summonTimer = 5.0,
    this.enraged = false,
  }) : health = maxHealth,
       baseSpeed = speed,
       type = bossTypeForLevel(level);

  Color get color => elementColor(element);
  double get healthPct => (health / maxHealth).clamp(0.0, 1.0);

  /// Rewards for defeating this boss — scale with level.
  int get shardReward => (8 + level * 4 + (maxHealth * 1.5)).round();
  double get particleReward => 3.0 + level * 2.0 + maxHealth * 0.2;
}

/// A projectile fired by a boss.
class BossProjectile {
  Offset position;
  final double angle;
  double life;
  final String element;
  final double damage;
  final double speed;
  final double radius;

  BossProjectile({
    required this.position,
    required this.angle,
    required this.element,
    this.life = 3.0,
    this.damage = 1.0,
    this.speed = 250.0,
    this.radius = 4.0,
  });
}

/// Named boss templates that can spawn.
class BossTemplate {
  final String name;
  final String element;
  final double radius;
  final double health;
  final double speed;

  const BossTemplate({
    required this.name,
    required this.element,
    required this.radius,
    required this.health,
    required this.speed,
  });
}

const List<BossTemplate> kBossTemplates = [
  // ── Volcanic ──
  BossTemplate(
    name: 'Infernal Wyrm',
    element: 'Fire',
    radius: 38,
    health: 35,
    speed: 55,
  ),
  BossTemplate(
    name: 'Molten Seraph',
    element: 'Lava',
    radius: 42,
    health: 45,
    speed: 38,
  ),
  BossTemplate(
    name: 'Storm Herald',
    element: 'Lightning',
    radius: 32,
    health: 28,
    speed: 80,
  ),
  // ── Oceanic ──
  BossTemplate(
    name: 'Abyssal Colossus',
    element: 'Water',
    radius: 44,
    health: 42,
    speed: 40,
  ),
  BossTemplate(
    name: 'Glacial Phantom',
    element: 'Ice',
    radius: 36,
    health: 36,
    speed: 50,
  ),
  BossTemplate(
    name: 'Mist Revenant',
    element: 'Steam',
    radius: 30,
    health: 25,
    speed: 72,
  ),
  // ── Earthen ──
  BossTemplate(
    name: 'Terravore',
    element: 'Earth',
    radius: 50,
    health: 65,
    speed: 22,
  ),
  BossTemplate(
    name: 'Mire Golem',
    element: 'Mud',
    radius: 46,
    health: 55,
    speed: 28,
  ),
  BossTemplate(
    name: 'Ashfall Djinn',
    element: 'Dust',
    radius: 28,
    health: 22,
    speed: 85,
  ),
  BossTemplate(
    name: 'Crystal Titan',
    element: 'Crystal',
    radius: 40,
    health: 50,
    speed: 35,
  ),
  // ── Verdant ──
  BossTemplate(
    name: 'Zephyr Sovereign',
    element: 'Air',
    radius: 26,
    health: 20,
    speed: 95,
  ),
  BossTemplate(
    name: 'Thornmother',
    element: 'Plant',
    radius: 44,
    health: 52,
    speed: 30,
  ),
  BossTemplate(
    name: 'Plague Wyrm',
    element: 'Poison',
    radius: 42,
    health: 48,
    speed: 34,
  ),
  // ── Arcane ──
  BossTemplate(
    name: 'Ethereal Oracle',
    element: 'Spirit',
    radius: 34,
    health: 32,
    speed: 62,
  ),
  BossTemplate(
    name: 'Shadow Wraith',
    element: 'Dark',
    radius: 38,
    health: 38,
    speed: 65,
  ),
  BossTemplate(
    name: 'Solaris Sentinel',
    element: 'Light',
    radius: 36,
    health: 35,
    speed: 58,
  ),
  BossTemplate(
    name: 'Blood Colossus',
    element: 'Blood',
    radius: 48,
    health: 60,
    speed: 25,
  ),
];

// ─────────────────────────────────────────────────────────
// BOSS LAIR (MAP POI)
// ─────────────────────────────────────────────────────────

/// State of a boss lair on the map.
enum BossLairState { waiting, fighting, defeated }

/// A discoverable point on the map where a boss awaits.
/// Always visible on the star map so the player can navigate to it.
class BossLair {
  Offset position;
  final BossTemplate template;
  final int level; // 1-10
  BossLairState state;
  double respawnTimer; // seconds until a new lair can spawn after defeat

  /// How close the player must be to trigger the boss fight.
  static const double activationRadius = 300.0;

  /// Delay before a new lair spawns after clearing one.
  static const double respawnDelay = 60.0;

  BossLair({
    required this.position,
    required this.template,
    required this.level,
    this.state = BossLairState.waiting,
    this.respawnTimer = 0,
  });

  /// Generate a single boss lair at a random position in deep space.
  static BossLair generate({
    required Random rng,
    required Size worldSize,
    required List<CosmicPlanet> planets,
    required List<GalaxyWhirl> whirls,
    List<BossLair> existing = const [],
  }) {
    const margin = 3000.0;
    const minPlanetDist = 2000.0;
    const minWhirlDist = 2500.0;
    const minLairDist = 4000.0;

    final template = kBossTemplates[rng.nextInt(kBossTemplates.length)];

    // Prefer a position near the matching element's planet
    final matchPlanet = planets.cast<CosmicPlanet?>().firstWhere(
      (p) => p!.element == template.element,
      orElse: () => null,
    );

    Offset pos;
    int tries = 0;
    do {
      if (matchPlanet != null && tries < 100) {
        // Place near the matching planet at a good orbit distance
        final angle = rng.nextDouble() * pi * 2;
        final dist = matchPlanet.radius * 5.0 + 300 + rng.nextDouble() * 800;
        pos = Offset(
          matchPlanet.position.dx + cos(angle) * dist,
          matchPlanet.position.dy + sin(angle) * dist,
        );
      } else {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
      }
      tries++;
    } while (tries < 200 &&
        (planets.any((p) => (p.position - pos).distance < minPlanetDist) ||
            whirls.any((w) => (w.position - pos).distance < minWhirlDist) ||
            existing.any((l) => (l.position - pos).distance < minLairDist)));

    // Level: 1-10, weighted toward the provided level hint
    final level = (rng.nextInt(3) - 1 + (rng.nextInt(10) + 1)).clamp(1, 10);

    return BossLair(position: pos, template: template, level: level);
  }

  /// Generate a lair with a specific level.
  static BossLair generateAtLevel({
    required Random rng,
    required int level,
    required Size worldSize,
    required List<CosmicPlanet> planets,
    required List<GalaxyWhirl> whirls,
    List<BossLair> existing = const [],
  }) {
    const margin = 3000.0;
    const minPlanetDist = 2000.0;
    const minWhirlDist = 2500.0;
    const minLairDist = 4000.0;

    final template = kBossTemplates[rng.nextInt(kBossTemplates.length)];

    final matchPlanet = planets.cast<CosmicPlanet?>().firstWhere(
      (p) => p!.element == template.element,
      orElse: () => null,
    );

    Offset pos;
    int tries = 0;
    do {
      if (matchPlanet != null && tries < 100) {
        final angle = rng.nextDouble() * pi * 2;
        final dist = matchPlanet.radius * 5.0 + 300 + rng.nextDouble() * 800;
        pos = Offset(
          matchPlanet.position.dx + cos(angle) * dist,
          matchPlanet.position.dy + sin(angle) * dist,
        );
      } else {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
      }
      tries++;
    } while (tries < 200 &&
        (planets.any((p) => (p.position - pos).distance < minPlanetDist) ||
            whirls.any((w) => (w.position - pos).distance < minWhirlDist) ||
            existing.any((l) => (l.position - pos).distance < minLairDist)));

    return BossLair(
      position: pos,
      template: template,
      level: level.clamp(1, 10),
    );
  }
}

// ─────────────────────────────────────────────────────────
// ASTEROID BELT
// ─────────────────────────────────────────────────────────

/// A ring of asteroids at a fixed location in the cosmos.
/// Deterministically generated from the world seed.
class Asteroid {
  Offset position;
  final double radius; // 4–18
  final double rotation; // initial rotation
  final double rotSpeed; // rad/s
  final int shape; // 0-2 for variety
  double health; // 1.0 = full, ≤ 0 = destroyed
  double orbitAngle; // current angle around belt center
  final double orbitDist; // distance from belt center
  final double orbitSpeed; // rad/s — slow drift

  Asteroid({
    required this.position,
    required this.radius,
    required this.rotation,
    required this.rotSpeed,
    required this.shape,
    this.health = 1.0,
    this.orbitAngle = 0,
    this.orbitDist = 0,
    this.orbitSpeed = 0,
  });

  bool get destroyed => health <= 0;
}

/// Generates an asteroid belt — a thick torus around a center point.
class AsteroidBelt {
  final Offset center;
  final double innerRadius;
  final double outerRadius;
  final List<Asteroid> asteroids;

  const AsteroidBelt({
    required this.center,
    required this.innerRadius,
    required this.outerRadius,
    required this.asteroids,
  });

  /// Generate a belt of 200–300 asteroids from seed.
  static AsteroidBelt generate({required int seed, required Size worldSize}) {
    final rng = Random(seed ^ 0xA57E01D);
    // Belt centered at ~1/3 of the world, offset from center
    final cx = worldSize.width * (0.25 + rng.nextDouble() * 0.50);
    final cy = worldSize.height * (0.25 + rng.nextDouble() * 0.50);
    final center = Offset(cx, cy);
    const innerR = 2000.0;
    const outerR = 3800.0;
    final count = 200 + rng.nextInt(100);

    final rocks = <Asteroid>[];
    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * pi * 2;
      final dist = innerR + rng.nextDouble() * (outerR - innerR);
      // Add some wobble so it's not a perfect ring
      final wobble = (rng.nextDouble() - 0.5) * 400;
      final actualDist = dist + wobble;
      final pos = Offset(
        cx + cos(angle) * actualDist,
        cy + sin(angle) * actualDist,
      );
      // Slow orbital drift — smaller rocks move a bit faster
      final orbSpeed =
          (0.003 + rng.nextDouble() * 0.006) * (rng.nextBool() ? 1 : -1);
      rocks.add(
        Asteroid(
          position: pos,
          radius: 4 + rng.nextDouble() * 14,
          rotation: rng.nextDouble() * pi * 2,
          rotSpeed: (rng.nextDouble() - 0.5) * 1.5,
          shape: rng.nextInt(3),
          orbitAngle: angle,
          orbitDist: actualDist,
          orbitSpeed: orbSpeed,
        ),
      );
    }

    return AsteroidBelt(
      center: center,
      innerRadius: innerR,
      outerRadius: outerR,
      asteroids: rocks,
    );
  }
}

// ─────────────────────────────────────────────────────────
// SHIP PROJECTILE
// ─────────────────────────────────────────────────────────

/// A laser bolt fired from the ship or a companion/garrison creature.
class Projectile {
  Offset position;
  double angle; // direction in radians (mutable for homing)
  double life; // seconds remaining
  final String? element; // element type (for companion projectiles)
  final double damage; // damage dealt on hit
  static const double speed = 600.0;
  static const double maxLife = 2.0;
  static const double radius = 3.0;

  /// Speed multiplier (1.0 = normal). Lava/Mud are slower, Lightning is faster.
  final double speedMultiplier;

  /// Radius multiplier for collision (e.g. 2.0 = bigger AoE hit).
  final double radiusMultiplier;

  /// If true, projectile passes through enemies instead of being consumed.
  final bool piercing;

  /// Number of enemies already hit (for piercing damage falloff).
  int pierceCount = 0;

  /// If true, projectile homes toward the nearest enemy each frame.
  final bool homing;

  /// Homing turn rate in radians per second.
  final double homingStrength;

  /// Visual scale multiplier for rendering (distinct from collision radius).
  final double visualScale;

  /// If true, projectile does not move — acts as a mine/trap.
  final bool stationary;

  /// Orbital state: if set, projectile orbits around this center point.
  Offset? orbitCenter;

  /// Current orbit angle (radians).
  double orbitAngle;

  /// Orbit radius.
  double orbitRadius;

  /// Orbit angular speed (radians/sec). When 0, orbit is disabled.
  double orbitSpeed;

  /// If > 0, projectile stays in orbit for this many seconds before launching.
  double orbitTime;

  // ── Decoy fields (Mask totem/turret) ──

  /// If true, this is a decoy — enemies target it instead of the ship.
  final bool decoy;

  /// HP the decoy has. Enemies deal contact damage to it. When ≤ 0 → explode.
  double decoyHp;

  /// Number of explosion projectiles to spawn when this decoy dies.
  final int deathExplosionCount;

  /// Damage multiplier for each death-explosion projectile.
  final double deathExplosionDamage;

  /// Radius of death-explosion scatter.
  final double deathExplosionRadius;

  // ── Taunt fields (Mask trap lures) ──

  /// If > 0, enemies inside this radius prioritize this projectile as a lure.
  final double tauntRadius;

  /// Turn/move aggression multiplier while enemies are taunted by this lure.
  final double tauntStrength;

  // ── Ricochet fields (Pip bounce) ──

  /// Number of remaining bounces to other enemies on hit.
  int bounceCount;

  // ── Trail fields (Wing residue) ──

  /// If > 0, drop a stationary residue projectile every N seconds.
  final double trailInterval;

  /// Damage of each trail residue projectile.
  final double trailDamage;

  /// Life of each trail residue projectile.
  final double trailLife;

  /// Internal timer for trail dropping.
  double trailTimer = 0;

  // ── Cluster fields (Let meteor fragmentation) ──

  /// If > 0, this projectile splits into N sub-projectiles at half-life.
  final int clusterCount;

  /// Damage of each cluster sub-projectile.
  final double clusterDamage;

  /// Whether the cluster split has already happened.
  bool clustered = false;

  Projectile({
    required this.position,
    required this.angle,
    this.life = maxLife,
    this.element,
    this.damage = 1.0,
    this.speedMultiplier = 1.0,
    this.radiusMultiplier = 1.0,
    this.piercing = false,
    this.homing = false,
    this.homingStrength = 3.0,
    this.visualScale = 1.0,
    this.stationary = false,
    this.orbitCenter,
    this.orbitAngle = 0,
    this.orbitRadius = 0,
    this.orbitSpeed = 0,
    this.orbitTime = 0,
    this.decoy = false,
    this.decoyHp = 0,
    this.deathExplosionCount = 0,
    this.deathExplosionDamage = 0,
    this.deathExplosionRadius = 1.5,
    this.tauntRadius = 0,
    this.tauntStrength = 0,
    this.bounceCount = 0,
    this.trailInterval = 0,
    this.trailDamage = 0,
    this.trailLife = 0,
    this.clusterCount = 0,
    this.clusterDamage = 0,
  });
}
// ═══════════════════════════════════════════════════════════
// PATCHED SECTION — drop this in to replace the old specials
// Covers: createCosmicSpecialAbility + all _horn/_wing/_let/
//         _pip/_mane/_mask/_kin/_mystic helpers + name tables
// ═══════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────
// COSMIC SPECIAL ABILITIES (Family × Element)  — OVERHAULED
// ─────────────────────────────────────────────────────────

/// Result of a cosmic special ability activation.
class CosmicSpecialResult {
  final List<Projectile> projectiles;
  final int shieldHp;
  final double chargeTimer;
  final double chargeDamage;
  final int selfHeal;
  final double blessingTimer;
  final double blessingHealPerTick;

  const CosmicSpecialResult({
    this.projectiles = const [],
    this.shieldHp = 0,
    this.chargeTimer = 0,
    this.chargeDamage = 0,
    this.selfHeal = 0,
    this.blessingTimer = 0,
    this.blessingHealPerTick = 0,
  });
}

CosmicSpecialResult createCosmicSpecialAbility({
  required Offset origin,
  required double baseAngle,
  required String family,
  required String element,
  required double damage,
  required int maxHp,
  Offset? targetPos,
}) {
  switch (family.toLowerCase()) {
    case 'horn':
      return _hornSpecial(origin, baseAngle, element, damage, maxHp, targetPos);
    case 'wing':
      return _wingSpecial(origin, baseAngle, element, damage);
    case 'let':
      return _letSpecial(origin, baseAngle, element, damage, targetPos);
    case 'pip':
      return _pipSpecial(origin, baseAngle, element, damage);
    case 'mane':
      return _maneSpecial(origin, baseAngle, element, damage);
    case 'mask':
      return _maskSpecial(origin, baseAngle, element, damage, targetPos);
    case 'kin':
      return _kinSpecial(origin, baseAngle, element, damage, maxHp);
    case 'mystic':
      return _mysticSpecial(origin, baseAngle, element, damage);
    default:
      return CosmicSpecialResult(
        projectiles: List.generate(3, (i) {
          final a = baseAngle + (i - 1) * 0.18;
          return Projectile(
            position: Offset(origin.dx + cos(a) * 18, origin.dy + sin(a) * 18),
            angle: a,
            element: element,
            damage: damage * 2.0,
          );
        }),
      );
  }
}

// ─────────────────────────────────────────────────────────
// HORN — Shield Charge + Nova
// Design: Big meaty damage, meaningful shields, satisfying nova
// ─────────────────────────────────────────────────────────
CosmicSpecialResult _hornSpecial(
  Offset origin,
  double baseAngle,
  String element,
  double damage,
  int maxHp,
  Offset? targetPos,
) {
  // Helper: full 360° ring
  List<Projectile> ring(
    int n,
    double dmgMul, {
    double life = 2.0,
    double speed = 1.0,
    double radius = 1.5,
    double vs = 1.4,
    bool pierce = false,
    bool home = false,
    double homeStr = 0,
  }) {
    return List.generate(n, (i) {
      final a = i * (pi * 2 / n);
      return Projectile(
        position: Offset(origin.dx + cos(a) * 14, origin.dy + sin(a) * 14),
        angle: a,
        element: element,
        damage: damage * dmgMul,
        life: life,
        speedMultiplier: speed,
        radiusMultiplier: radius,
        visualScale: vs,
        piercing: pierce,
        homing: home,
        homingStrength: homeStr,
      );
    });
  }

  // Helper: forward cone
  List<Projectile> cone(
    int n,
    double spread,
    double dmgMul, {
    double life = 2.0,
    double speed = 1.0,
    double vs = 1.2,
    double radius = 1.3,
    bool pierce = false,
  }) {
    return List.generate(n, (i) {
      final t = n > 1 ? (i / (n - 1)) - 0.5 : 0.0;
      final a = baseAngle + t * spread;
      return Projectile(
        position: Offset(origin.dx + cos(a) * 16, origin.dy + sin(a) * 16),
        angle: a,
        element: element,
        damage: damage * dmgMul,
        life: life,
        speedMultiplier: speed,
        radiusMultiplier: radius,
        visualScale: vs,
        piercing: pierce,
      );
    });
  }

  switch (element) {
    case 'Fire':
      // Aggressive nova — 10 fireballs radiate, fast charge
      return CosmicSpecialResult(
        shieldHp: (maxHp * 0.30).round(),
        chargeTimer: 0.55,
        chargeDamage: damage * 6.0,
        projectiles: ring(10, 1.8, life: 2.0, speed: 1.3, vs: 1.5),
      );

    case 'Lava':
      // Slow obliterating charge, 5 massive piercing magma boulders
      return CosmicSpecialResult(
        shieldHp: (maxHp * 0.50).round(),
        chargeTimer: 1.1,
        chargeDamage: damage * 9.0,
        projectiles: ring(
          5,
          3.5,
          life: 3.0,
          speed: 0.5,
          radius: 3.5,
          vs: 2.8,
          pierce: true,
        ),
      );

    case 'Lightning':
      // Instant teleport charge, 16 homing sparks
      return CosmicSpecialResult(
        shieldHp: (maxHp * 0.18).round(),
        chargeTimer: 0.25,
        chargeDamage: damage * 5.0,
        projectiles: ring(
          16,
          1.2,
          life: 1.2,
          speed: 2.5,
          radius: 1.0,
          vs: 0.9,
          home: true,
          homeStr: 5.0,
        ),
      );

    case 'Water':
      // Tidal guard — wide forward wave
      return CosmicSpecialResult(
        shieldHp: (maxHp * 0.35).round(),
        chargeTimer: 0.75,
        chargeDamage: damage * 6.5,
        projectiles: cone(9, pi * 0.65, 1.8, life: 2.2, speed: 0.9, vs: 1.3),
      );

    case 'Ice':
      // Glacier slam — 8 massive slow frost shards, huge shield
      return CosmicSpecialResult(
        shieldHp: (maxHp * 0.45).round(),
        chargeTimer: 0.9,
        chargeDamage: damage * 8.0,
        projectiles: ring(8, 2.0, life: 3.0, speed: 0.4, radius: 2.8, vs: 2.2),
      );

    case 'Steam':
      // Pressure crash — 6 large lingering piercing steam clouds
      return CosmicSpecialResult(
        shieldHp: (maxHp * 0.28).round(),
        chargeTimer: 0.65,
        chargeDamage: damage * 5.5,
        projectiles: ring(
          6,
          1.5,
          life: 4.0,
          speed: 0.3,
          radius: 3.5,
          vs: 2.8,
          pierce: true,
        ),
      );

    case 'Earth':
      // TANK — 60% shield, slow unstoppable charge, 4 colossal boulders
      return CosmicSpecialResult(
        shieldHp: (maxHp * 0.60).round(),
        chargeTimer: 1.4,
        chargeDamage: damage * 12.0,
        projectiles: ring(
          4,
          4.0,
          life: 2.5,
          speed: 0.4,
          radius: 4.0,
          vs: 3.0,
          pierce: true,
        ),
      );

    case 'Mud':
      // Quagmire crash — 4 massive mud blobs + sticky lingering hitbox
      return CosmicSpecialResult(
        shieldHp: (maxHp * 0.40).round(),
        chargeTimer: 1.0,
        chargeDamage: damage * 7.0,
        projectiles: ring(
          4,
          2.5,
          life: 3.5,
          speed: 0.35,
          radius: 3.2,
          vs: 2.5,
          pierce: true,
        ),
      );

    case 'Dust':
      // Glass cannon — tiny shield, ultra-fast charge, 18 sand grains
      return CosmicSpecialResult(
        shieldHp: (maxHp * 0.14).round(),
        chargeTimer: 0.40,
        chargeDamage: damage * 4.5,
        projectiles: ring(
          18,
          0.9,
          life: 1.4,
          speed: 2.2,
          radius: 0.9,
          vs: 0.65,
        ),
      );

    case 'Crystal':
      // Reflective shield — 8 homing crystal shards
      return CosmicSpecialResult(
        shieldHp: (maxHp * 0.38).round(),
        chargeTimer: 0.70,
        chargeDamage: damage * 6.0,
        projectiles: ring(
          8,
          1.8,
          life: 3.0,
          speed: 1.0,
          radius: 1.8,
          vs: 1.4,
          home: true,
          homeStr: 3.5,
        ),
      );

    case 'Air':
      // Ultra-fast gale crash — 8 spiral wind blades
      return CosmicSpecialResult(
        shieldHp: (maxHp * 0.20).round(),
        chargeTimer: 0.30,
        chargeDamage: damage * 4.5,
        projectiles: ring(8, 1.4, life: 1.8, speed: 1.8, radius: 1.3, vs: 1.1),
      );

    case 'Plant':
      // Thornguard — 6 vine whips forward + 4 stationary thorn traps behind
      final vines = cone(6, pi * 0.40, 1.8, life: 2.5, speed: 1.0, vs: 1.2);
      final thorns = List.generate(4, (i) {
        final a = baseAngle + pi + (i - 1.5) * 0.7;
        return Projectile(
          position: Offset(origin.dx + cos(a) * 35, origin.dy + sin(a) * 35),
          angle: a,
          element: element,
          damage: damage * 2.0,
          life: 6.0,
          stationary: true,
          radiusMultiplier: 2.5,
          piercing: true,
          visualScale: 1.8,
        );
      });
      return CosmicSpecialResult(
        shieldHp: (maxHp * 0.45).round(),
        chargeTimer: 0.85,
        chargeDamage: damage * 5.5,
        projectiles: [...vines, ...thorns],
      );

    case 'Poison':
      // Toxic ram — 7 huge lingering poison zones
      return CosmicSpecialResult(
        shieldHp: (maxHp * 0.25).round(),
        chargeTimer: 0.75,
        chargeDamage: damage * 5.0,
        projectiles: ring(
          7,
          1.2,
          life: 5.0,
          speed: 0.2,
          radius: 3.0,
          vs: 2.2,
          pierce: true,
        ),
      );

    case 'Spirit':
      // Ethereal bastion — 4 powerful homing spirit seekers, phase-through
      return CosmicSpecialResult(
        shieldHp: (maxHp * 0.25).round(),
        chargeTimer: 0.60,
        chargeDamage: damage * 6.0,
        projectiles: ring(
          4,
          2.5,
          life: 4.0,
          speed: 0.8,
          radius: 1.8,
          vs: 1.6,
          home: true,
          homeStr: 5.0,
          pierce: true,
        ),
      );

    case 'Dark':
      // Shadow crash — near-instant, devastating, 7 fast dark bolts
      return CosmicSpecialResult(
        shieldHp: (maxHp * 0.30).round(),
        chargeTimer: 0.40,
        chargeDamage: damage * 10.0,
        projectiles: ring(7, 3.0, life: 1.5, speed: 2.0, radius: 1.4, vs: 1.1),
      );

    case 'Light':
      // Radiant guard — 14 homing light orbs
      return CosmicSpecialResult(
        shieldHp: (maxHp * 0.25).round(),
        chargeTimer: 0.55,
        chargeDamage: damage * 4.5,
        projectiles: ring(
          14,
          1.0,
          life: 2.5,
          speed: 1.4,
          radius: 1.1,
          vs: 0.9,
          home: true,
          homeStr: 3.5,
        ),
      );

    case 'Blood':
      // Crimson fortress — 3 heavy homing blood orbs + meaningful self heal
      return CosmicSpecialResult(
        shieldHp: (maxHp * 0.35).round(),
        chargeTimer: 0.70,
        chargeDamage: damage * 8.0,
        selfHeal: (maxHp * 0.18).round(),
        projectiles: ring(
          3,
          3.5,
          life: 3.5,
          speed: 0.8,
          radius: 2.5,
          vs: 2.0,
          home: true,
          homeStr: 4.0,
        ),
      );

    default:
      return CosmicSpecialResult(
        shieldHp: (maxHp * 0.30).round(),
        chargeTimer: 0.70,
        chargeDamage: damage * 6.0,
        projectiles: ring(8, 1.8, life: 2.0, speed: 0.8, radius: 1.5, vs: 1.3),
      );
  }
}

// ─────────────────────────────────────────────────────────
// WING — Piercing Beam
// Design: Powerful beams that actually pierce and hurt
// ─────────────────────────────────────────────────────────
CosmicSpecialResult _wingSpecial(
  Offset origin,
  double baseAngle,
  String element,
  double damage,
) {
  final beamDmg = damage * _wingElementDamageMultiplier(element);
  final beamSpeed = _wingElementSpeed(element);
  final beamLife = _wingElementLife(element);
  final trail = _wingElementTrail(element);

  final projs = <Projectile>[
    // Primary beam — always large, always piercing
    Projectile(
      position: Offset(
        origin.dx + cos(baseAngle) * 20,
        origin.dy + sin(baseAngle) * 20,
      ),
      angle: baseAngle,
      element: element,
      damage: beamDmg,
      life: beamLife,
      speedMultiplier: beamSpeed,
      piercing: true,
      radiusMultiplier: _wingElementRadius(element),
      visualScale: 2.5,
      trailInterval: trail.$1,
      trailDamage: trail.$2,
      trailLife: trail.$3,
    ),
  ];

  // Element secondaries — all significantly buffed
  switch (element) {
    case 'Lightning':
      // Chain web: main beam + 6 branching piercing bolts
      for (var i = 0; i < 6; i++) {
        final a = baseAngle + (i - 2.5) * 0.28;
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 16, origin.dy + sin(a) * 16),
            angle: a,
            element: element,
            damage: damage * 1.8,
            life: 1.2,
            speedMultiplier: 2.5,
            piercing: true,
            visualScale: 1.1,
          ),
        );
      }
      break;

    case 'Crystal':
      // Prism refraction: 8 homing shards from beam tip
      for (var i = 0; i < 8; i++) {
        final a = baseAngle + (i - 3.5) * 0.22;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(baseAngle) * 90,
              origin.dy + sin(baseAngle) * 90,
            ),
            angle: a,
            element: element,
            damage: damage * 1.5,
            life: 2.0,
            speedMultiplier: 1.2,
            homing: true,
            homingStrength: 3.5,
            visualScale: 1.0,
          ),
        );
      }
      break;

    case 'Fire':
      // Sweeping inferno: 5 fire projectiles spreading sideways
      for (var i = 0; i < 5; i++) {
        final a = baseAngle + (i - 2) * 0.12;
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 14, origin.dy + sin(a) * 14),
            angle: a,
            element: element,
            damage: damage * 1.4,
            life: 2.5,
            speedMultiplier: 0.7,
            visualScale: 1.5,
          ),
        );
      }
      break;

    case 'Ice':
      // Frost burst: 6 homing shards launched backward from tip
      for (var i = 0; i < 6; i++) {
        final a = baseAngle + pi + (i - 2.5) * 0.3;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(baseAngle) * 70,
              origin.dy + sin(baseAngle) * 70,
            ),
            angle: a,
            element: element,
            damage: damage * 1.5,
            life: 3.0,
            speedMultiplier: 0.7,
            homing: true,
            homingStrength: 3.5,
            visualScale: 1.1,
          ),
        );
      }
      break;

    case 'Dark':
      // Void slash: 8 lingering stationary void zones along beam path
      for (var i = 0; i < 8; i++) {
        final dist = 18.0 + i * 22.0;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(baseAngle) * dist,
              origin.dy + sin(baseAngle) * dist,
            ),
            angle: baseAngle,
            element: element,
            damage: damage * 1.8,
            life: 3.5,
            stationary: true,
            radiusMultiplier: 2.5,
            visualScale: 1.8,
            piercing: true,
          ),
        );
      }
      break;

    case 'Blood':
      // Crimson lance: main beam + 3 strong homing blood bolts
      for (var i = 0; i < 3; i++) {
        final a = baseAngle + (i - 1) * 0.28;
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 16, origin.dy + sin(a) * 16),
            angle: a,
            element: element,
            damage: damage * 2.0,
            life: 3.5,
            speedMultiplier: 0.8,
            homing: true,
            homingStrength: 3.5,
            visualScale: 1.6,
          ),
        );
      }
      break;

    case 'Water':
      // Tidal beam: wide 7-bolt fan
      for (var i = 0; i < 7; i++) {
        final a = baseAngle + (i - 3) * 0.18;
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 14, origin.dy + sin(a) * 14),
            angle: a,
            element: element,
            damage: damage * 1.3,
            life: 2.0,
            speedMultiplier: 0.8,
            visualScale: 1.2,
          ),
        );
      }
      break;

    case 'Lava':
      // Eruption trench: 4 massive slow piercing magma chunks
      for (var i = 0; i < 4; i++) {
        final dist = 18.0 + i * 32.0;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(baseAngle) * dist,
              origin.dy + sin(baseAngle) * dist,
            ),
            angle: baseAngle + (i - 1.5) * 0.18,
            element: element,
            damage: damage * 2.8,
            life: 3.0,
            speedMultiplier: 0.25,
            radiusMultiplier: 3.0,
            piercing: true,
            visualScale: 2.5,
          ),
        );
      }
      break;

    case 'Steam':
      // Pressure jet: 5 large stationary steam columns
      for (var i = 0; i < 5; i++) {
        final dist = 22.0 + i * 26.0;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(baseAngle) * dist,
              origin.dy + sin(baseAngle) * dist,
            ),
            angle: baseAngle,
            element: element,
            damage: damage * 1.8,
            life: 4.0,
            stationary: true,
            radiusMultiplier: 3.0,
            piercing: true,
            visualScale: 2.3,
          ),
        );
      }
      break;

    case 'Earth':
      // Boulder beam: 2 enormous slow rocks + wide radius
      for (var i = 0; i < 2; i++) {
        final a = baseAngle + (i == 0 ? -0.22 : 0.22);
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 16, origin.dy + sin(a) * 16),
            angle: a,
            element: element,
            damage: damage * 3.5,
            life: 2.5,
            speedMultiplier: 0.55,
            radiusMultiplier: 3.5,
            visualScale: 2.8,
            piercing: true,
          ),
        );
      }
      break;

    case 'Mud':
      // Quicksand trail: 5 large slow lingering mud puddles
      for (var i = 0; i < 5; i++) {
        final dist = 14.0 + i * 22.0;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(baseAngle) * dist,
              origin.dy + sin(baseAngle) * dist,
            ),
            angle: baseAngle,
            element: element,
            damage: damage * 1.6,
            life: 4.5,
            stationary: true,
            radiusMultiplier: 2.8,
            piercing: true,
            visualScale: 2.0,
          ),
        );
      }
      break;

    case 'Dust':
      // Sandblast: 10 fast scattered shards
      final rng = Random();
      for (var i = 0; i < 10; i++) {
        final a = baseAngle + (rng.nextDouble() - 0.5) * 1.1;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(baseAngle) * 45,
              origin.dy + sin(baseAngle) * 45,
            ),
            angle: a,
            element: element,
            damage: damage * 1.0,
            life: 1.0,
            speedMultiplier: 2.0,
            visualScale: 0.7,
          ),
        );
      }
      break;

    case 'Air':
      // Tornado drill: 5 fast spiraling bolts
      for (var i = 0; i < 5; i++) {
        final a = baseAngle + (i * pi * 2 / 5);
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 22, origin.dy + sin(a) * 22),
            angle: baseAngle,
            element: element,
            damage: damage * 1.2,
            life: 1.8,
            speedMultiplier: 1.8,
            visualScale: 1.1,
          ),
        );
      }
      break;

    case 'Plant':
      // Vine beam: 5 homing vine tendrils
      for (var i = 0; i < 5; i++) {
        final a = baseAngle + (i - 2) * 0.38;
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 16, origin.dy + sin(a) * 16),
            angle: a,
            element: element,
            damage: damage * 1.5,
            life: 3.0,
            speedMultiplier: 0.7,
            homing: true,
            homingStrength: 2.8,
            visualScale: 1.2,
          ),
        );
      }
      break;

    case 'Poison':
      // Venom trail: 6 large lingering poison clouds
      for (var i = 0; i < 6; i++) {
        final dist = 14.0 + i * 19.0;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(baseAngle) * dist,
              origin.dy + sin(baseAngle) * dist,
            ),
            angle: baseAngle,
            element: element,
            damage: damage * 1.2,
            life: 5.0,
            stationary: true,
            radiusMultiplier: 2.5,
            piercing: true,
            visualScale: 2.0,
          ),
        );
      }
      break;

    case 'Spirit':
      // Reaper beam: 3 strong homing piercing spirits
      for (var i = 0; i < 3; i++) {
        final a = baseAngle + (i - 1) * 0.45;
        projs.add(
          Projectile(
            position: Offset(origin.dx + cos(a) * 16, origin.dy + sin(a) * 16),
            angle: a,
            element: element,
            damage: damage * 2.2,
            life: 4.5,
            speedMultiplier: 0.7,
            homing: true,
            homingStrength: 5.0,
            piercing: true,
            visualScale: 1.4,
          ),
        );
      }
      break;

    case 'Light':
      // Radiant burst: 8 light orbs scattering from tip
      for (var i = 0; i < 8; i++) {
        final a = i * (pi * 2 / 8);
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(baseAngle) * 65,
              origin.dy + sin(baseAngle) * 65,
            ),
            angle: a,
            element: element,
            damage: damage * 1.2,
            life: 2.0,
            speedMultiplier: 1.2,
            homing: true,
            homingStrength: 2.5,
            visualScale: 0.9,
          ),
        );
      }
      break;

    default:
      break;
  }

  return CosmicSpecialResult(projectiles: projs);
}

double _wingElementDamageMultiplier(String e) => switch (e) {
  'Dark' => 5.0,
  'Earth' => 4.5,
  'Lava' => 4.5,
  'Crystal' => 4.0,
  'Blood' => 4.0,
  'Spirit' => 3.8,
  'Lightning' => 3.0,
  'Ice' => 3.2,
  'Fire' => 3.5,
  'Water' => 3.0,
  'Mud' => 3.5,
  'Steam' => 3.0,
  'Plant' => 3.0,
  'Poison' => 2.8,
  'Air' => 2.8,
  'Dust' => 2.5,
  'Light' => 3.2,
  _ => 3.5,
};

double _wingElementSpeed(String e) => switch (e) {
  'Lightning' => 2.8,
  'Dark' => 2.2,
  'Air' => 2.2,
  'Fire' => 2.0,
  'Dust' => 2.0,
  'Light' => 1.8,
  'Crystal' => 1.6,
  'Ice' => 1.4,
  'Spirit' => 1.3,
  'Water' => 1.4,
  'Blood' => 1.1,
  'Steam' => 1.1,
  'Plant' => 1.1,
  'Poison' => 0.9,
  'Mud' => 0.8,
  'Earth' => 0.9,
  'Lava' => 0.7,
  _ => 1.6,
};

double _wingElementLife(String e) => switch (e) {
  'Poison' => 3.5,
  'Blood' => 3.0,
  'Mud' => 3.2,
  'Plant' => 3.0,
  'Steam' => 3.0,
  'Spirit' => 3.0,
  'Water' => 2.5,
  'Lava' => 3.0,
  'Ice' => 2.8,
  'Earth' => 2.5,
  'Crystal' => 2.2,
  'Fire' => 2.2,
  'Dark' => 2.0,
  'Lightning' => 1.4,
  'Air' => 1.8,
  'Dust' => 1.5,
  'Light' => 2.5,
  _ => 2.5,
};

double _wingElementRadius(String e) => switch (e) {
  'Earth' => 3.0,
  'Lava' => 2.8,
  'Mud' => 2.5,
  'Steam' => 2.5,
  'Plant' => 2.2,
  'Ice' => 2.2,
  'Water' => 2.0,
  'Blood' => 2.0,
  'Crystal' => 1.6,
  'Fire' => 1.8,
  'Dark' => 1.6,
  'Spirit' => 1.8,
  'Lightning' => 1.2,
  'Air' => 1.2,
  'Dust' => 1.1,
  'Poison' => 2.0,
  'Light' => 1.5,
  _ => 1.8,
};

(double, double, double) _wingElementTrail(String element) => switch (element) {
  'Poison' => (0.12, 8.0, 5.0),
  'Lava' => (0.18, 10.0, 4.0),
  'Fire' => (0.15, 7.0, 2.5),
  'Mud' => (0.18, 5.0, 6.0),
  'Steam' => (0.22, 4.5, 4.0),
  'Plant' => (0.20, 6.0, 5.0),
  _ => (0, 0, 0),
};

// ─────────────────────────────────────────────────────────
// LET — Meteor Strike
// Design: Impactful meteors, big AoE, element flavours matter
// ─────────────────────────────────────────────────────────
CosmicSpecialResult _letSpecial(
  Offset origin,
  double baseAngle,
  String element,
  double damage,
  Offset? targetPos,
) {
  final target =
      targetPos ??
      Offset(
        origin.dx + cos(baseAngle) * 150,
        origin.dy + sin(baseAngle) * 150,
      );
  final toTarget = target - origin;
  final angle = atan2(toTarget.dy, toTarget.dx);
  final projs = <Projectile>[];
  final cluster = _letElementCluster(element);

  // Main meteor — always large, always threatening
  projs.add(
    Projectile(
      position: Offset(
        origin.dx + cos(angle) * 22,
        origin.dy + sin(angle) * 22,
      ),
      angle: angle,
      element: element,
      damage: damage * 6.0,
      life: 1.8,
      speedMultiplier: 0.55,
      radiusMultiplier: 3.5,
      visualScale: 3.0,
      clusterCount: cluster.$1,
      clusterDamage: damage * cluster.$2,
    ),
  );

  // Element secondaries
  switch (element) {
    case 'Fire':
      // Burning crater: 7 lingering fire zones
      for (var i = 0; i < 7; i++) {
        final a = i * (pi * 2 / 7);
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(angle) * 90 + cos(a) * 25,
              origin.dy + sin(angle) * 90 + sin(a) * 25,
            ),
            angle: a,
            element: element,
            damage: damage * 2.0,
            life: 4.0,
            stationary: true,
            radiusMultiplier: 2.5,
            piercing: true,
            visualScale: 1.8,
          ),
        );
      }
      break;

    case 'Lightning':
      // Chain discharge: 6 fast piercing bolts radiating
      for (var i = 0; i < 6; i++) {
        final a = angle + (i - 2.5) * 0.45;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(angle) * 70,
              origin.dy + sin(angle) * 70,
            ),
            angle: a,
            element: element,
            damage: damage * 2.5,
            life: 1.2,
            speedMultiplier: 2.2,
            piercing: true,
            visualScale: 1.1,
          ),
        );
      }
      break;

    case 'Ice':
      // Freeze zone: 5 slow expanding ice chunks
      for (var i = 0; i < 5; i++) {
        final a = i * (pi * 2 / 5);
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(angle) * 80 + cos(a) * 18,
              origin.dy + sin(angle) * 80 + sin(a) * 18,
            ),
            angle: a,
            element: element,
            damage: damage * 2.2,
            life: 3.5,
            speedMultiplier: 0.25,
            radiusMultiplier: 3.0,
            piercing: true,
            visualScale: 2.5,
          ),
        );
      }
      break;

    case 'Earth':
      // Moon drop: ENORMOUS single boulder
      projs[0] = Projectile(
        position: projs[0].position,
        angle: angle,
        element: element,
        damage: damage * 12.0,
        life: 2.0,
        speedMultiplier: 0.38,
        radiusMultiplier: 5.0,
        visualScale: 4.0,
      );
      break;

    case 'Spirit':
      // Soul harvest: 5 homing spirit bolts from impact
      for (var i = 0; i < 5; i++) {
        final a = angle + (i - 2) * 0.5;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(angle) * 80,
              origin.dy + sin(angle) * 80,
            ),
            angle: a,
            element: element,
            damage: damage * 2.5,
            life: 3.5,
            speedMultiplier: 0.7,
            homing: true,
            homingStrength: 4.5,
            visualScale: 1.4,
          ),
        );
      }
      break;

    case 'Poison':
      // Toxic cloud: 8 massive long-lasting zones
      for (var i = 0; i < 8; i++) {
        final a = i * (pi * 2 / 8);
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(angle) * 85 + cos(a) * 28,
              origin.dy + sin(angle) * 85 + sin(a) * 28,
            ),
            angle: a,
            element: element,
            damage: damage * 1.4,
            life: 6.0,
            stationary: true,
            radiusMultiplier: 3.0,
            piercing: true,
            visualScale: 2.5,
          ),
        );
      }
      break;

    case 'Water':
      // Tidal splash: 8 water bolts radiating from impact
      for (var i = 0; i < 8; i++) {
        final a = i * (pi * 2 / 8);
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(angle) * 85 + cos(a) * 22,
              origin.dy + sin(angle) * 85 + sin(a) * 22,
            ),
            angle: a,
            element: element,
            damage: damage * 2.0,
            life: 2.5,
            speedMultiplier: 0.9,
            radiusMultiplier: 2.0,
            visualScale: 1.5,
          ),
        );
      }
      break;

    case 'Lava':
      // Volcanic debris: 4 massive slow piercing magma chunks
      for (var i = 0; i < 4; i++) {
        final a = angle + (i - 1.5) * 0.55;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(angle) * 80,
              origin.dy + sin(angle) * 80,
            ),
            angle: a,
            element: element,
            damage: damage * 3.5,
            life: 3.0,
            speedMultiplier: 0.35,
            radiusMultiplier: 3.0,
            piercing: true,
            visualScale: 2.5,
          ),
        );
      }
      break;

    case 'Steam':
      // Geyser eruptions: 6 stationary steam columns
      for (var i = 0; i < 6; i++) {
        final a = i * (pi * 2 / 6);
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(angle) * 88 + cos(a) * 28,
              origin.dy + sin(angle) * 88 + sin(a) * 28,
            ),
            angle: a,
            element: element,
            damage: damage * 1.8,
            life: 5.0,
            stationary: true,
            radiusMultiplier: 2.5,
            piercing: true,
            visualScale: 2.2,
          ),
        );
      }
      break;

    case 'Mud':
      // Quagmire impact: 6 large mud puddles
      for (var i = 0; i < 6; i++) {
        final a = i * (pi * 2 / 6);
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(angle) * 85 + cos(a) * 32,
              origin.dy + sin(angle) * 85 + sin(a) * 32,
            ),
            angle: a,
            element: element,
            damage: damage * 1.5,
            life: 5.5,
            stationary: true,
            radiusMultiplier: 2.8,
            piercing: true,
            visualScale: 2.0,
          ),
        );
      }
      break;

    case 'Dust':
      // Shrapnel burst: 12 fast fragments
      for (var i = 0; i < 12; i++) {
        final a = i * (pi * 2 / 12);
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(angle) * 75,
              origin.dy + sin(angle) * 75,
            ),
            angle: a,
            element: element,
            damage: damage * 1.2,
            life: 1.5,
            speedMultiplier: 2.2,
            visualScale: 0.7,
          ),
        );
      }
      break;

    case 'Crystal':
      // Starfall: 7 homing crystal shards
      for (var i = 0; i < 7; i++) {
        final a = angle + (i - 3) * 0.38;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(angle) * 80,
              origin.dy + sin(angle) * 80,
            ),
            angle: a,
            element: element,
            damage: damage * 2.5,
            life: 3.0,
            speedMultiplier: 0.9,
            homing: true,
            homingStrength: 3.5,
            visualScale: 1.2,
          ),
        );
      }
      break;

    case 'Air':
      // Shockwave ring: 8 fast air blasts radiating
      for (var i = 0; i < 8; i++) {
        final a = i * (pi * 2 / 8);
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(angle) * 80,
              origin.dy + sin(angle) * 80,
            ),
            angle: a,
            element: element,
            damage: damage * 1.5,
            life: 1.2,
            speedMultiplier: 2.8,
            radiusMultiplier: 1.6,
            visualScale: 1.1,
          ),
        );
      }
      break;

    case 'Plant':
      // Seed bombardment: 4 vine traps + 3 homing pods
      for (var i = 0; i < 4; i++) {
        final a = i * (pi * 2 / 4);
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(angle) * 88 + cos(a) * 28,
              origin.dy + sin(angle) * 88 + sin(a) * 28,
            ),
            angle: a,
            element: element,
            damage: damage * 2.0,
            life: 6.0,
            stationary: true,
            radiusMultiplier: 2.2,
            piercing: true,
            visualScale: 1.6,
          ),
        );
      }
      for (var i = 0; i < 3; i++) {
        final a = angle + (i - 1) * 0.42;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(angle) * 80,
              origin.dy + sin(angle) * 80,
            ),
            angle: a,
            element: element,
            damage: damage * 1.8,
            life: 3.5,
            speedMultiplier: 0.7,
            homing: true,
            homingStrength: 3.0,
            visualScale: 1.1,
          ),
        );
      }
      break;

    case 'Blood':
      // Bloodburst: 3 heavy homing blood orbs
      for (var i = 0; i < 3; i++) {
        final a = angle + (i - 1) * 0.32;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(angle) * 78,
              origin.dy + sin(angle) * 78,
            ),
            angle: a,
            element: element,
            damage: damage * 3.5,
            life: 4.0,
            speedMultiplier: 0.6,
            homing: true,
            homingStrength: 4.5,
            radiusMultiplier: 2.5,
            visualScale: 1.8,
          ),
        );
      }
      break;

    case 'Dark':
      // Void collapse: 4 large slow piercing dark orbs
      for (var i = 0; i < 4; i++) {
        final a = angle + (i - 1.5) * 0.45;
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(angle) * 78,
              origin.dy + sin(angle) * 78,
            ),
            angle: a,
            element: element,
            damage: damage * 3.5,
            life: 3.5,
            speedMultiplier: 0.45,
            radiusMultiplier: 3.0,
            piercing: true,
            visualScale: 2.5,
          ),
        );
      }
      break;

    case 'Light':
      // Celestial rain: 10 homing light orbs
      for (var i = 0; i < 10; i++) {
        final a = i * (pi * 2 / 10);
        projs.add(
          Projectile(
            position: Offset(
              origin.dx + cos(angle) * 88,
              origin.dy + sin(angle) * 88,
            ),
            angle: a,
            element: element,
            damage: damage * 1.5,
            life: 2.5,
            speedMultiplier: 0.7,
            homing: true,
            homingStrength: 2.8,
            visualScale: 0.9,
          ),
        );
      }
      break;

    default:
      break;
  }

  return CosmicSpecialResult(projectiles: projs);
}

(int, double) _letElementCluster(String element) => switch (element) {
  'Crystal' => (10, 1.2),
  'Dust' => (14, 0.8),
  'Ice' => (8, 1.2),
  'Water' => (7, 1.0),
  'Lava' => (5, 1.8),
  'Air' => (8, 0.8),
  'Fire' => (6, 1.0),
  'Lightning' => (6, 1.2),
  _ => (0, 0),
};

// ─────────────────────────────────────────────────────────
// PIP — Ricochet Salvo
// Design: Fast homing chains, bouncy, fun to watch
// ─────────────────────────────────────────────────────────
CosmicSpecialResult _pipSpecial(
  Offset origin,
  double baseAngle,
  String element,
  double damage,
) {
  final count = _pipElementCount(element);
  final bounces = _pipElementBounce(element);
  final projs = List.generate(count, (i) {
    final offset = (i - count / 2) * 0.22;
    final a = baseAngle + offset;
    return Projectile(
      position: Offset(
        origin.dx + cos(a) * (12 + i * 4),
        origin.dy + sin(a) * (12 + i * 4),
      ),
      angle: a,
      element: element,
      damage: damage * _pipElementDamageMultiplier(element),
      life: _pipElementLife(element),
      speedMultiplier: _pipElementSpeed(element),
      homing: bounces == 0,
      homingStrength: _pipElementHoming(element),
      piercing: element == 'Lightning' || element == 'Crystal',
      bounceCount: bounces,
      visualScale: 0.9,
    );
  });
  return CosmicSpecialResult(projectiles: projs);
}

int _pipElementBounce(String e) => switch (e) {
  'Crystal' => 5,
  'Lightning' => 4,
  'Air' => 4,
  'Light' => 3,
  'Fire' => 3,
  'Water' => 3,
  'Ice' => 3,
  'Dust' => 2,
  _ => 0,
};

int _pipElementCount(String e) => switch (e) {
  'Lightning' => 10,
  'Dust' => 14,
  'Crystal' => 8,
  'Air' => 9,
  'Fire' => 6,
  'Water' => 7,
  'Ice' => 6,
  'Steam' => 7,
  'Light' => 8,
  'Blood' => 4,
  'Lava' => 5,
  'Earth' => 4,
  'Mud' => 5,
  'Plant' => 6,
  'Poison' => 5,
  'Spirit' => 4,
  'Dark' => 5,
  _ => 6,
};

double _pipElementDamageMultiplier(String e) => switch (e) {
  'Blood' => 3.0,
  'Dark' => 2.8,
  'Lava' => 2.5,
  'Earth' => 2.5,
  'Spirit' => 2.2,
  'Crystal' => 1.8,
  'Fire' => 1.8,
  'Ice' => 1.8,
  'Water' => 1.6,
  'Mud' => 1.6,
  'Plant' => 1.6,
  'Poison' => 1.4,
  'Steam' => 1.4,
  'Lightning' => 1.4,
  'Air' => 1.2,
  'Light' => 1.4,
  'Dust' => 0.9,
  _ => 1.8,
};

double _pipElementLife(String e) => switch (e) {
  'Blood' => 3.5,
  'Spirit' => 4.0,
  'Poison' => 3.5,
  'Plant' => 3.0,
  'Mud' => 3.0,
  'Water' => 3.0,
  'Lava' => 2.5,
  'Ice' => 2.8,
  'Steam' => 2.5,
  'Earth' => 2.5,
  'Crystal' => 2.5,
  'Dark' => 2.5,
  'Fire' => 2.2,
  'Lightning' => 1.8,
  'Dust' => 1.8,
  'Air' => 1.8,
  'Light' => 3.0,
  _ => 2.5,
};

double _pipElementSpeed(String e) => switch (e) {
  'Lightning' => 2.3,
  'Air' => 2.0,
  'Dust' => 1.8,
  'Fire' => 1.6,
  'Light' => 1.5,
  'Crystal' => 1.4,
  'Dark' => 1.5,
  'Water' => 1.2,
  'Steam' => 1.2,
  'Ice' => 1.1,
  'Plant' => 1.1,
  'Earth' => 1.0,
  'Lava' => 0.9,
  'Mud' => 0.9,
  'Poison' => 1.0,
  'Spirit' => 0.9,
  'Blood' => 0.8,
  _ => 1.4,
};

double _pipElementHoming(String e) => switch (e) {
  'Spirit' => 6.0,
  'Blood' => 5.5,
  'Dark' => 4.5,
  'Plant' => 4.5,
  'Poison' => 4.5,
  'Crystal' => 4.0,
  'Mud' => 3.5,
  'Lava' => 3.5,
  'Ice' => 3.5,
  'Water' => 3.5,
  'Earth' => 3.0,
  'Fire' => 3.0,
  'Lightning' => 3.0,
  'Air' => 3.0,
  'Steam' => 3.0,
  'Light' => 3.5,
  'Dust' => 2.0,
  _ => 3.5,
};

// ─────────────────────────────────────────────────────────
// MANE — Barrage Volley
// Design: Dense, satisfying sprays — was way too weak before
// ─────────────────────────────────────────────────────────
CosmicSpecialResult _maneSpecial(
  Offset origin,
  double baseAngle,
  String element,
  double damage,
) {
  final count = _maneElementCount(element);
  final spread = _maneElementSpread(element);
  final projs = List.generate(count, (i) {
    final t = count > 1 ? (i / (count - 1)) - 0.5 : 0.0;
    final a = baseAngle + t * spread;
    return Projectile(
      position: Offset(origin.dx + cos(a) * 16, origin.dy + sin(a) * 16),
      angle: a,
      element: element,
      damage: damage * _maneElementDamageMultiplier(element),
      life: _maneElementLife(element),
      speedMultiplier: _maneElementSpeed(element),
      piercing:
          element == 'Spirit' || element == 'Light' || element == 'Crystal',
      visualScale: _maneElementVisualScale(element),
    );
  });
  return CosmicSpecialResult(projectiles: projs);
}

int _maneElementCount(String e) => switch (e) {
  'Fire' => 18,
  'Lightning' => 12,
  'Ice' => 14,
  'Dust' => 22,
  'Light' => 16,
  'Crystal' => 10,
  'Water' => 13,
  'Lava' => 7,
  'Steam' => 12,
  'Earth' => 6,
  'Mud' => 9,
  'Air' => 16,
  'Plant' => 12,
  'Poison' => 10,
  'Spirit' => 8,
  'Dark' => 9,
  'Blood' => 6,
  _ => 13,
};

double _maneElementSpread(String e) => switch (e) {
  'Fire' => pi * 2,
  'Ice' => pi * 2,
  'Light' => pi * 2,
  'Dust' => pi * 1.5,
  'Air' => pi * 1.5,
  'Water' => pi * 1.1,
  'Steam' => pi * 1.1,
  'Poison' => pi * 0.9,
  'Lightning' => pi * 0.75,
  'Crystal' => pi * 0.65,
  'Plant' => pi * 0.65,
  'Mud' => pi * 0.55,
  'Lava' => pi * 0.55,
  'Earth' => pi * 0.45,
  'Spirit' => pi * 0.55,
  'Dark' => pi * 0.55,
  'Blood' => pi * 0.35,
  _ => pi * 0.75,
};

// HUGE uplift here — was 0.3-0.5, now 1.2-2.5
double _maneElementDamageMultiplier(String e) => switch (e) {
  'Earth' => 2.8,
  'Dark' => 2.5,
  'Blood' => 2.5,
  'Lava' => 2.2,
  'Crystal' => 2.2,
  'Spirit' => 2.0,
  'Ice' => 1.8,
  'Mud' => 1.8,
  'Plant' => 1.6,
  'Lightning' => 1.6,
  'Water' => 1.5,
  'Poison' => 1.5,
  'Steam' => 1.4,
  'Fire' => 1.4,
  'Air' => 1.2,
  'Light' => 1.2,
  'Dust' => 1.0,
  _ => 1.5,
};

double _maneElementLife(String e) => switch (e) {
  'Poison' => 3.0,
  'Mud' => 2.5,
  'Plant' => 2.5,
  'Lava' => 2.5,
  'Earth' => 2.2,
  'Steam' => 2.5,
  'Spirit' => 2.5,
  'Blood' => 2.2,
  'Water' => 2.0,
  'Ice' => 2.0,
  'Crystal' => 2.0,
  'Dark' => 2.0,
  'Fire' => 1.6,
  'Lightning' => 1.3,
  'Dust' => 1.3,
  'Air' => 1.5,
  'Light' => 2.0,
  _ => 2.0,
};

double _maneElementSpeed(String e) => switch (e) {
  'Lightning' => 2.0,
  'Air' => 1.8,
  'Dust' => 1.6,
  'Fire' => 1.4,
  'Light' => 1.4,
  'Water' => 1.2,
  'Crystal' => 1.2,
  'Dark' => 1.2,
  'Spirit' => 1.1,
  'Ice' => 1.0,
  'Steam' => 0.9,
  'Plant' => 0.9,
  'Blood' => 0.9,
  'Poison' => 0.8,
  'Earth' => 0.6,
  'Mud' => 0.65,
  'Lava' => 0.6,
  _ => 1.1,
};

double _maneElementVisualScale(String e) => switch (e) {
  'Earth' => 1.8,
  'Lava' => 1.7,
  'Mud' => 1.6,
  'Blood' => 1.3,
  'Steam' => 1.2,
  'Crystal' => 0.9,
  'Ice' => 1.1,
  'Water' => 1.0,
  'Plant' => 1.0,
  'Poison' => 1.1,
  'Spirit' => 1.0,
  'Dark' => 1.1,
  'Fire' => 0.9,
  'Lightning' => 0.8,
  'Air' => 0.8,
  'Dust' => 0.7,
  'Light' => 0.9,
  _ => 1.0,
};

// ─────────────────────────────────────────────────────────
// MASK — Mine Field / Decoy Assault
// COMPLETE REWORK: Decoys now ACTIVELY SEEK enemies on spawn.
// Mine elements fire a burst of seeking/homing projectiles instead of
// sitting still hoping something walks into them.
// ─────────────────────────────────────────────────────────
CosmicSpecialResult _maskSpecial(
  Offset origin,
  double baseAngle,
  String element,
  double damage,
  Offset? targetPos,
) {
  final rng = Random();
  final projs = <Projectile>[];

  // Helper: spawn a projectile that homes aggressively from a nearby scatter pos.
  // This is our "active seeker" — it will immediately fly toward the nearest enemy.
  Projectile seeker(
    Offset pos,
    double dmgMul, {
    double life = 4.0,
    double speed = 0.7,
    double radius = 1.8,
    double vs = 1.4,
    bool pierce = false,
    double homeStr = 5.0,
    int bounces = 0,
  }) {
    return Projectile(
      position: pos,
      angle: baseAngle,
      element: element,
      damage: damage * dmgMul,
      life: life,
      speedMultiplier: speed,
      radiusMultiplier: radius,
      visualScale: vs,
      homing: true,
      homingStrength: homeStr,
      piercing: pierce,
      bounceCount: bounces,
    );
  }

  // Helper: scatter offset from origin
  Offset scatter({double maxDist = 60.0}) {
    final a = rng.nextDouble() * pi * 2;
    final d = 20 + rng.nextDouble() * maxDist;
    return Offset(origin.dx + cos(a) * d, origin.dy + sin(a) * d);
  }

  // Helper: decoy that actively seeks + explodes (homing decoy)
  Projectile homingDecoy(
    double dmgMul,
    double decoyHp,
    int explodeCount,
    double explodeDmg, {
    double life = 7.0,
    double radius = 2.5,
    double vs = 2.2,
    double speed = 0.6,
  }) {
    return Projectile(
      position: scatter(maxDist: 40),
      angle: baseAngle,
      element: element,
      damage: damage * dmgMul,
      life: life,
      speedMultiplier: speed,
      radiusMultiplier: radius,
      visualScale: vs,
      // Decoy + active homing: rushes to nearest enemy, survives hits, then explodes
      homing: true,
      homingStrength: 3.5,
      decoy: true,
      decoyHp: decoyHp,
      deathExplosionCount: explodeCount,
      deathExplosionDamage: damage * explodeDmg,
      deathExplosionRadius: 2.5,
      tauntRadius: 320,
      tauntStrength: 3.4,
    );
  }

  // Helper: stationary trap-totem that force-taunts nearby enemies.
  Projectile tauntTrap(
    Offset pos,
    double dmgMul, {
    double life = 8.0,
    double radius = 2.0,
    double vs = 1.9,
    double hp = 9.0,
    double tauntR = 420.0,
    double tauntStr = 4.4,
    int explodeCount = 8,
    double explodeDmg = 1.9,
  }) {
    return Projectile(
      position: pos,
      angle: 0,
      element: element,
      damage: damage * dmgMul,
      life: life,
      stationary: true,
      radiusMultiplier: radius,
      visualScale: vs,
      decoy: true,
      decoyHp: hp,
      deathExplosionCount: explodeCount,
      deathExplosionDamage: damage * explodeDmg,
      deathExplosionRadius: 2.2,
      tauntRadius: tauntR,
      tauntStrength: tauntStr,
    );
  }

  final trapAnchor =
      targetPos ??
      Offset(
        origin.dx + cos(baseAngle) * 120,
        origin.dy + sin(baseAngle) * 120,
      );
  final trapCount = switch (element) {
    'Lightning' || 'Air' => 4,
    'Earth' || 'Mud' || 'Dark' => 3,
    _ => 2,
  };
  final trapTauntRadius = switch (element) {
    'Dark' => 520.0,
    'Earth' => 490.0,
    'Mud' => 500.0,
    'Light' => 500.0,
    _ => 440.0,
  };
  final trapLife = switch (element) {
    'Earth' || 'Mud' => 10.0,
    'Ice' || 'Steam' => 9.0,
    'Dark' => 9.5,
    _ => 8.0,
  };
  for (var i = 0; i < trapCount; i++) {
    final a = baseAngle + ((i - (trapCount - 1) / 2) * 0.6);
    final spread = 30.0 + i * 16.0;
    final pos = Offset(
      trapAnchor.dx + cos(a) * spread,
      trapAnchor.dy + sin(a) * spread,
    );
    projs.add(
      tauntTrap(
        pos,
        0.85,
        life: trapLife,
        tauntR: trapTauntRadius,
        hp: element == 'Earth'
            ? 14
            : element == 'Mud'
            ? 12
            : 9,
      ),
    );
  }

  switch (element) {
    // ── Decoy elements: rush to enemy, tank hits, explode ──
    case 'Earth':
      // Monolith assault: 1 colossal homing decoy + ring of boulder seekers
      projs.add(
        homingDecoy(
          2.0,
          20,
          10,
          4.5,
          life: 9.0,
          radius: 3.5,
          vs: 3.0,
          speed: 0.45,
        ),
      );
      for (var i = 0; i < 5; i++) {
        projs.add(
          seeker(
            scatter(maxDist: 70),
            3.0,
            life: 3.0,
            speed: 0.55,
            radius: 2.8,
            vs: 2.2,
            pierce: true,
          ),
        );
      }
      break;

    case 'Lava':
      // Volcanic idol: 2 homing lava decoys that erupt into magma on death
      for (var i = 0; i < 2; i++) {
        projs.add(
          homingDecoy(
            2.5,
            14,
            8,
            5.0,
            life: 7.0,
            radius: 3.0,
            vs: 2.5,
            speed: 0.5,
          ),
        );
      }
      // Plus 4 seeking lava orbs
      for (var i = 0; i < 4; i++) {
        projs.add(
          seeker(
            scatter(maxDist: 80),
            2.5,
            life: 3.5,
            speed: 0.6,
            radius: 2.2,
            vs: 1.8,
          ),
        );
      }
      break;

    case 'Crystal':
      // Prism decoy: 2 homing crystal decoys → 12 homing shards on death
      for (var i = 0; i < 2; i++) {
        projs.add(
          homingDecoy(
            1.5,
            10,
            12,
            2.0,
            life: 7.5,
            radius: 2.2,
            vs: 2.0,
            speed: 0.65,
          ),
        );
      }
      // 5 extra homing crystal seekers
      for (var i = 0; i < 5; i++) {
        projs.add(
          seeker(
            scatter(maxDist: 70),
            2.0,
            life: 3.0,
            speed: 0.9,
            homeStr: 4.5,
            bounces: 3,
          ),
        );
      }
      break;

    case 'Spirit':
      // Phantom decoy: 3 fast homing spirit lures → homing spirit burst
      for (var i = 0; i < 3; i++) {
        projs.add(
          homingDecoy(
            1.5,
            8,
            6,
            3.0,
            life: 8.0,
            radius: 2.0,
            vs: 1.8,
            speed: 0.75,
          ),
        );
      }
      // 3 strong piercing homing spirits
      for (var i = 0; i < 3; i++) {
        projs.add(
          seeker(
            scatter(maxDist: 60),
            2.5,
            life: 5.0,
            speed: 0.8,
            pierce: true,
            homeStr: 6.0,
          ),
        );
      }
      break;

    case 'Dark':
      // Void well: 1 massive homing decoy + 5 fast dark seekers
      projs.add(
        homingDecoy(
          3.0,
          16,
          8,
          6.0,
          life: 7.0,
          radius: 3.2,
          vs: 2.8,
          speed: 0.55,
        ),
      );
      for (var i = 0; i < 5; i++) {
        projs.add(
          seeker(
            scatter(maxDist: 70),
            3.0,
            life: 2.5,
            speed: 1.0,
            homeStr: 5.0,
          ),
        );
      }
      break;

    case 'Water':
      // Bubble assault: 3 medium homing decoys + 5 water seekers
      for (var i = 0; i < 3; i++) {
        projs.add(
          homingDecoy(
            1.4,
            7,
            7,
            1.8,
            life: 6.0,
            radius: 2.5,
            vs: 2.0,
            speed: 0.7,
          ),
        );
      }
      for (var i = 0; i < 5; i++) {
        projs.add(
          seeker(
            scatter(maxDist: 80),
            1.8,
            life: 3.0,
            speed: 0.85,
            homeStr: 3.5,
          ),
        );
      }
      break;

    case 'Ice':
      // Frost decoy: 1 big homing decoy → slow ice shards + 5 slow seeking shards
      projs.add(
        homingDecoy(
          2.0,
          12,
          10,
          2.5,
          life: 8.0,
          radius: 3.0,
          vs: 2.5,
          speed: 0.50,
        ),
      );
      for (var i = 0; i < 5; i++) {
        projs.add(
          seeker(
            scatter(maxDist: 70),
            2.0,
            life: 4.0,
            speed: 0.5,
            radius: 2.5,
            vs: 1.8,
          ),
        );
      }
      break;

    case 'Plant':
      // Vine construct: 2 homing plant decoys + 6 seeking thorn pods
      for (var i = 0; i < 2; i++) {
        projs.add(
          homingDecoy(
            1.8,
            9,
            6,
            2.5,
            life: 9.0,
            radius: 2.2,
            vs: 2.0,
            speed: 0.60,
          ),
        );
      }
      for (var i = 0; i < 6; i++) {
        projs.add(
          seeker(
            scatter(maxDist: 80),
            1.8,
            life: 4.0,
            speed: 0.7,
            pierce: true,
            homeStr: 4.0,
          ),
        );
      }
      break;

    case 'Light':
      // Beacon assault: 3 homing light decoys + 6 seeking light bolts
      for (var i = 0; i < 3; i++) {
        projs.add(
          homingDecoy(
            1.4,
            8,
            9,
            1.5,
            life: 6.5,
            radius: 2.0,
            vs: 1.8,
            speed: 0.75,
          ),
        );
      }
      for (var i = 0; i < 6; i++) {
        projs.add(
          seeker(
            scatter(maxDist: 70),
            1.5,
            life: 2.5,
            speed: 1.0,
            homeStr: 3.5,
            bounces: 2,
          ),
        );
      }
      break;

    case 'Blood':
      // Blood obelisk: 1 tough homing decoy + 4 powerful seeking blood orbs
      projs.add(
        homingDecoy(
          2.5,
          15,
          5,
          5.0,
          life: 8.0,
          radius: 2.8,
          vs: 2.4,
          speed: 0.55,
        ),
      );
      for (var i = 0; i < 4; i++) {
        projs.add(
          seeker(
            scatter(maxDist: 60),
            3.5,
            life: 4.0,
            speed: 0.7,
            radius: 2.0,
            homeStr: 5.0,
          ),
        );
      }
      break;

    // ── "Mine" elements: converted from useless statics to aggressive homing swarms ──
    case 'Fire':
      // Inferno assault: 8 homing fire bolts
      for (var i = 0; i < 8; i++) {
        projs.add(
          seeker(
            scatter(maxDist: 70),
            2.0,
            life: 3.5,
            speed: 1.1,
            homeStr: 4.0,
          ),
        );
      }
      break;

    case 'Lightning':
      // Tesla chain: 10 fast bouncing lightning seekers
      for (var i = 0; i < 10; i++) {
        projs.add(
          Projectile(
            position: scatter(maxDist: 80),
            angle: baseAngle,
            element: element,
            damage: damage * 1.5,
            life: 2.5,
            speedMultiplier: 1.8,
            radiusMultiplier: 1.4,
            visualScale: 1.2,
            homing: true,
            homingStrength: 4.5,
            piercing: true,
            bounceCount: 3,
          ),
        );
      }
      break;

    case 'Steam':
      // Vent assault: 6 large homing steam seekers
      for (var i = 0; i < 6; i++) {
        projs.add(
          seeker(
            scatter(maxDist: 75),
            1.8,
            life: 5.0,
            speed: 0.55,
            radius: 3.0,
            vs: 2.0,
            homeStr: 3.0,
          ),
        );
      }
      break;

    case 'Mud':
      // Bog assault: 6 large slow homing mud blobs
      for (var i = 0; i < 6; i++) {
        projs.add(
          seeker(
            scatter(maxDist: 65),
            2.0,
            life: 5.5,
            speed: 0.45,
            radius: 3.0,
            vs: 2.2,
            homeStr: 3.0,
          ),
        );
      }
      break;

    case 'Dust':
      // Caltrop swarm: 12 fast tiny homing sand grains, ricochet
      for (var i = 0; i < 12; i++) {
        projs.add(
          Projectile(
            position: scatter(maxDist: 90),
            angle: baseAngle,
            element: element,
            damage: damage * 1.2,
            life: 2.0,
            speedMultiplier: 1.8,
            homing: true,
            homingStrength: 3.5,
            bounceCount: 2,
            visualScale: 0.7,
          ),
        );
      }
      break;

    case 'Poison':
      // Plague assault: 7 large slow homing toxic zones
      for (var i = 0; i < 7; i++) {
        projs.add(
          seeker(
            scatter(maxDist: 75),
            1.5,
            life: 7.0,
            speed: 0.45,
            radius: 3.0,
            vs: 2.2,
            homeStr: 3.0,
            pierce: true,
          ),
        );
      }
      break;

    case 'Air':
      // Wind assault: 8 fast homing wind blades
      for (var i = 0; i < 8; i++) {
        projs.add(
          seeker(
            scatter(maxDist: 80),
            1.5,
            life: 2.5,
            speed: 1.5,
            radius: 1.4,
            vs: 1.2,
            homeStr: 4.0,
          ),
        );
      }
      break;

    default:
      // Generic: 7 homing seekers
      for (var i = 0; i < 7; i++) {
        projs.add(
          seeker(
            scatter(maxDist: 70),
            2.0,
            life: 3.5,
            speed: 0.8,
            homeStr: 4.0,
          ),
        );
      }
  }

  return CosmicSpecialResult(projectiles: projs);
}

// ─────────────────────────────────────────────────────────
// KIN — Blessing Pulse
// Design: Meaningful heals + orbiting orbs that actually hurt
// ─────────────────────────────────────────────────────────
CosmicSpecialResult _kinSpecial(
  Offset origin,
  double baseAngle,
  String element,
  double damage,
  int maxHp,
) {
  final healAmount = (maxHp * _kinElementHealPercent(element)).round();
  final orbCount = _kinElementOrbCount(element);

  final projs = List.generate(orbCount, (i) {
    final a = i * (pi * 2 / orbCount);
    return Projectile(
      position: Offset(origin.dx + cos(a) * 45, origin.dy + sin(a) * 45),
      angle: a,
      element: element,
      damage: damage * _kinElementOrbDamage(element),
      life: _kinElementOrbLife(element),
      orbitCenter: origin,
      orbitAngle: a,
      orbitRadius: 45.0,
      orbitSpeed: _kinElementOrbSpeed(element),
      orbitTime: _kinElementOrbOrbitTime(element),
      homing: true,
      homingStrength: 3.5,
      radiusMultiplier: 1.8,
      visualScale: 1.4,
    );
  });

  return CosmicSpecialResult(
    projectiles: projs,
    selfHeal: healAmount,
    blessingTimer: _kinElementBlessingDuration(element),
    blessingHealPerTick: maxHp * 0.025,
  );
}

double _kinElementHealPercent(String e) => switch (e) {
  'Light' => 0.50,
  'Water' => 0.42,
  'Plant' => 0.38,
  'Blood' => 0.35,
  'Spirit' => 0.30,
  'Ice' => 0.28,
  'Steam' => 0.28,
  'Earth' => 0.25,
  'Crystal' => 0.25,
  'Air' => 0.22,
  'Mud' => 0.22,
  'Poison' => 0.18,
  'Fire' => 0.18,
  'Lightning' => 0.18,
  'Lava' => 0.15,
  'Dark' => 0.12,
  'Dust' => 0.18,
  _ => 0.25,
};

int _kinElementOrbCount(String e) => switch (e) {
  'Lightning' => 10,
  'Crystal' => 8,
  'Light' => 8,
  'Dust' => 9,
  'Air' => 8,
  'Fire' => 6,
  'Water' => 6,
  'Ice' => 6,
  'Steam' => 5,
  'Earth' => 4,
  'Lava' => 4,
  'Mud' => 5,
  'Plant' => 5,
  'Poison' => 5,
  'Spirit' => 4,
  'Dark' => 5,
  'Blood' => 4,
  _ => 5,
};

// Significantly buffed from 0.3-1.0 → 1.2-3.0
double _kinElementOrbDamage(String e) => switch (e) {
  'Dark' => 3.0,
  'Blood' => 2.8,
  'Fire' => 2.5,
  'Lava' => 2.5,
  'Earth' => 2.2,
  'Spirit' => 2.2,
  'Crystal' => 2.0,
  'Lightning' => 1.8,
  'Water' => 1.8,
  'Ice' => 1.8,
  'Steam' => 1.6,
  'Mud' => 1.6,
  'Plant' => 1.6,
  'Poison' => 1.5,
  'Air' => 1.4,
  'Dust' => 1.2,
  'Light' => 1.4,
  _ => 1.8,
};

double _kinElementOrbLife(String e) => switch (e) {
  'Poison' => 7.0,
  'Plant' => 6.5,
  'Mud' => 6.0,
  'Spirit' => 6.0,
  'Blood' => 6.0,
  'Earth' => 5.5,
  'Water' => 5.5,
  'Ice' => 5.5,
  'Steam' => 5.0,
  'Crystal' => 5.0,
  'Dark' => 4.5,
  'Lava' => 4.5,
  'Fire' => 4.5,
  'Light' => 5.0,
  'Air' => 4.0,
  'Dust' => 3.5,
  'Lightning' => 3.5,
  _ => 5.0,
};

double _kinElementOrbSpeed(String e) => switch (e) {
  'Lightning' => 7.0,
  'Air' => 6.5,
  'Fire' => 5.5,
  'Light' => 5.5,
  'Dust' => 5.5,
  'Crystal' => 5.0,
  'Water' => 4.5,
  'Dark' => 5.0,
  'Ice' => 4.0,
  'Steam' => 4.5,
  'Spirit' => 4.5,
  'Earth' => 3.5,
  'Lava' => 3.5,
  'Mud' => 3.0,
  'Plant' => 4.0,
  'Poison' => 3.8,
  'Blood' => 4.0,
  _ => 4.5,
};

double _kinElementOrbOrbitTime(String e) => switch (e) {
  'Earth' => 3.5,
  'Crystal' => 3.2,
  'Mud' => 3.2,
  'Plant' => 3.0,
  'Ice' => 3.0,
  'Water' => 2.8,
  'Steam' => 2.8,
  'Blood' => 3.0,
  'Spirit' => 2.8,
  'Lava' => 2.5,
  'Poison' => 2.5,
  'Dark' => 2.2,
  'Fire' => 2.0,
  'Lightning' => 1.5,
  'Air' => 1.8,
  'Dust' => 1.8,
  'Light' => 2.5,
  _ => 2.5,
};

double _kinElementBlessingDuration(String e) => switch (e) {
  'Light' => 8.0,
  'Water' => 6.5,
  'Plant' => 6.5,
  'Spirit' => 5.5,
  'Blood' => 5.0,
  'Ice' => 5.0,
  'Earth' => 5.0,
  'Crystal' => 4.5,
  'Steam' => 4.5,
  'Mud' => 4.5,
  'Poison' => 4.0,
  'Fire' => 3.5,
  'Lightning' => 3.5,
  'Air' => 4.0,
  'Lava' => 3.5,
  'Dark' => 3.0,
  'Dust' => 4.0,
  _ => 4.0,
};

// ─────────────────────────────────────────────────────────
// MYSTIC — Orbital Storm
// Design: Spiraling orbs that hurt AND seek enemies
// ─────────────────────────────────────────────────────────
CosmicSpecialResult _mysticSpecial(
  Offset origin,
  double baseAngle,
  String element,
  double damage,
) {
  final count = _mysticElementCount(element);
  final projs = List.generate(count, (i) {
    final a = i * (pi * 2 / count);
    final radius = 30.0 + i * 6.0;
    return Projectile(
      position: Offset(
        origin.dx + cos(a) * radius,
        origin.dy + sin(a) * radius,
      ),
      angle: a,
      element: element,
      damage: damage * _mysticElementDamageMultiplier(element),
      life: _mysticElementLife(element),
      orbitCenter: origin,
      orbitAngle: a,
      orbitRadius: radius,
      orbitSpeed: _mysticElementOrbSpeed(element),
      orbitTime: 1.8,
      homing: true,
      homingStrength: _mysticElementHoming(element),
      piercing:
          element == 'Spirit' || element == 'Dark' || element == 'Crystal',
      speedMultiplier: _mysticElementSpeed(element),
      visualScale: _mysticElementVisualScale(element),
    );
  });
  return CosmicSpecialResult(projectiles: projs);
}

int _mysticElementCount(String e) => switch (e) {
  'Crystal' => 12,
  'Lightning' => 10,
  'Light' => 10,
  'Dust' => 12,
  'Air' => 10,
  'Fire' => 8,
  'Water' => 8,
  'Ice' => 7,
  'Steam' => 7,
  'Earth' => 5,
  'Lava' => 5,
  'Mud' => 6,
  'Plant' => 7,
  'Poison' => 6,
  'Spirit' => 6,
  'Dark' => 6,
  'Blood' => 5,
  _ => 8,
};

// Buffed from 0.5-1.4 → 1.5-3.5
double _mysticElementDamageMultiplier(String e) => switch (e) {
  'Blood' => 3.5,
  'Dark' => 3.2,
  'Lava' => 3.0,
  'Earth' => 3.0,
  'Spirit' => 2.8,
  'Fire' => 2.5,
  'Ice' => 2.5,
  'Water' => 2.2,
  'Crystal' => 2.0,
  'Lightning' => 2.0,
  'Steam' => 2.0,
  'Mud' => 2.2,
  'Plant' => 2.0,
  'Poison' => 1.8,
  'Air' => 1.8,
  'Dust' => 1.5,
  'Light' => 2.0,
  _ => 2.2,
};

double _mysticElementLife(String e) => switch (e) {
  'Poison' => 5.0,
  'Spirit' => 4.5,
  'Plant' => 4.5,
  'Mud' => 4.5,
  'Blood' => 4.5,
  'Water' => 4.0,
  'Earth' => 4.0,
  'Ice' => 4.0,
  'Crystal' => 4.0,
  'Steam' => 3.8,
  'Dark' => 3.5,
  'Lava' => 3.5,
  'Fire' => 3.5,
  'Light' => 4.0,
  'Air' => 3.0,
  'Dust' => 2.5,
  'Lightning' => 2.5,
  _ => 3.8,
};

double _mysticElementOrbSpeed(String e) => switch (e) {
  'Lightning' => 8.0,
  'Air' => 7.0,
  'Fire' => 6.5,
  'Light' => 6.5,
  'Dust' => 6.0,
  'Crystal' => 6.0,
  'Dark' => 6.0,
  'Water' => 5.5,
  'Ice' => 5.0,
  'Steam' => 5.0,
  'Spirit' => 5.5,
  'Earth' => 4.0,
  'Lava' => 4.0,
  'Mud' => 3.5,
  'Plant' => 4.5,
  'Poison' => 4.0,
  'Blood' => 4.5,
  _ => 5.5,
};

double _mysticElementHoming(String e) => switch (e) {
  'Spirit' => 6.0,
  'Blood' => 5.5,
  'Dark' => 5.0,
  'Plant' => 4.5,
  'Poison' => 4.5,
  'Crystal' => 4.5,
  'Water' => 4.0,
  'Ice' => 4.0,
  'Mud' => 4.0,
  'Fire' => 3.5,
  'Lightning' => 3.5,
  'Earth' => 3.5,
  'Lava' => 3.5,
  'Steam' => 3.5,
  'Air' => 3.5,
  'Dust' => 2.5,
  'Light' => 4.0,
  _ => 4.0,
};

double _mysticElementSpeed(String e) => switch (e) {
  'Lightning' => 1.8,
  'Air' => 1.6,
  'Fire' => 1.4,
  'Light' => 1.4,
  'Dust' => 1.4,
  'Crystal' => 1.2,
  'Water' => 1.2,
  'Dark' => 1.2,
  'Ice' => 1.1,
  'Steam' => 1.0,
  'Spirit' => 1.0,
  'Blood' => 0.9,
  'Plant' => 1.0,
  'Poison' => 0.9,
  'Earth' => 0.8,
  'Mud' => 0.7,
  'Lava' => 0.65,
  _ => 1.2,
};

double _mysticElementVisualScale(String e) => switch (e) {
  'Lava' => 1.8,
  'Earth' => 1.7,
  'Mud' => 1.6,
  'Blood' => 1.5,
  'Ice' => 1.4,
  'Dark' => 1.4,
  'Water' => 1.3,
  'Steam' => 1.3,
  'Crystal' => 1.2,
  'Fire' => 1.2,
  'Plant' => 1.2,
  'Poison' => 1.2,
  'Spirit' => 1.2,
  'Light' => 1.1,
  'Air' => 1.0,
  'Dust' => 0.8,
  'Lightning' => 0.9,
  _ => 1.2,
};

// ─────────────────────────────────────────────────────────
// ABILITY NAMES (unchanged from original)
// ─────────────────────────────────────────────────────────
String cosmicSpecialAbilityName(String family, String element) {
  switch (family.toLowerCase()) {
    case 'horn':
      return switch (element) {
        'Fire' => 'Blazing Charge',
        'Lava' => 'Magma Ram',
        'Lightning' => 'Thunder Crash',
        'Water' => 'Tidal Guard',
        'Ice' => 'Glacier Slam',
        'Steam' => 'Pressure Crash',
        'Earth' => 'Cataclysmic Fortress',
        'Mud' => 'Quagmire Crash',
        'Dust' => 'Sandstorm Ram',
        'Crystal' => 'Crystal Bulwark',
        'Air' => 'Gale Crash',
        'Plant' => 'Thornguard Charge',
        'Poison' => 'Toxic Ram',
        'Spirit' => 'Spirit Bastion',
        'Dark' => 'Shadow Crash',
        'Light' => 'Radiant Guard',
        'Blood' => 'Crimson Fortress',
        _ => 'Shield Charge',
      };
    case 'wing':
      return switch (element) {
        'Fire' => 'Sweeping Flamebeam',
        'Lava' => 'Eruption Trench',
        'Lightning' => 'Chain Lightning Web',
        'Water' => 'Tidal Beam',
        'Ice' => 'Ice Lance Burst',
        'Steam' => 'Pressure Beam',
        'Earth' => 'Boulder Beam',
        'Mud' => 'Quicksand Trail',
        'Dust' => 'Sandstorm Beam',
        'Crystal' => 'Prism Refraction',
        'Air' => 'Tornado Drill',
        'Plant' => 'Vine Beam',
        'Poison' => 'Venom Trail',
        'Spirit' => 'Reaper Beam',
        'Dark' => 'Void Slash',
        'Light' => 'Radiant Beam',
        'Blood' => 'Crimson Lance',
        _ => 'Piercing Beam',
      };
    case 'let':
      return switch (element) {
        'Fire' => 'Flame Meteor',
        'Lava' => 'Volcanic Bombardment',
        'Lightning' => 'Orbital Strike',
        'Water' => 'Tidal Meteor',
        'Ice' => 'Comet Cluster',
        'Steam' => 'Geyser Strike',
        'Earth' => 'Moon Drop',
        'Mud' => 'Quagmire Meteor',
        'Dust' => 'Sandstorm Meteor',
        'Crystal' => 'Starfall',
        'Air' => 'Atmospheric Bomb',
        'Plant' => 'Seed Bombardment',
        'Poison' => 'Toxic Storm',
        'Spirit' => 'Soul Harvest',
        'Dark' => 'Void Meteor',
        'Light' => 'Celestial Rain',
        'Blood' => 'Transfusion Meteor',
        _ => 'Meteor Strike',
      };
    case 'pip':
      return switch (element) {
        'Fire' => 'Flame Ricochet',
        'Lava' => 'Magma Chain',
        'Lightning' => 'Thunder Chain',
        'Water' => 'Tidal Ricochet',
        'Ice' => 'Frost Chain',
        'Steam' => 'Steam Ricochet',
        'Earth' => 'Tremor Chain',
        'Mud' => 'Mire Ricochet',
        'Dust' => 'Sand Chain',
        'Crystal' => 'Crystal Shatter',
        'Air' => 'Cyclone Chain',
        'Plant' => 'Thorn Ricochet',
        'Poison' => 'Pandemic Chain',
        'Spirit' => 'Haunt Chain',
        'Dark' => 'Shadow Ricochet',
        'Light' => 'Blessing Chain',
        'Blood' => 'Hemorrhage Chain',
        _ => 'Ricochet Salvo',
      };
    case 'mane':
      return switch (element) {
        'Fire' => 'Spiraling Inferno',
        'Lava' => 'Volcanic Barrage',
        'Lightning' => 'Tempest Barrage',
        'Water' => 'Tsunami Barrage',
        'Ice' => 'Blizzard',
        'Steam' => 'Geyser Barrage',
        'Earth' => 'Earthquake',
        'Mud' => 'Quagmire Barrage',
        'Dust' => 'Desert Storm',
        'Crystal' => 'Prism Barrage',
        'Air' => 'Tornado',
        'Plant' => 'Overgrowth',
        'Poison' => 'Miasma',
        'Spirit' => 'Spirit Whirlwind',
        'Dark' => 'Dark Vortex',
        'Light' => 'Light Nova',
        'Blood' => 'Exsanguination',
        _ => 'Barrage Volley',
      };
    case 'mask':
      return switch (element) {
        'Fire' => 'Inferno Lure Grid',
        'Lava' => 'Volcanic Taunt Idol',
        'Lightning' => 'Tesla Snare Grid',
        'Water' => 'Tidal Lure Net',
        'Ice' => 'Frost Snare Totem',
        'Steam' => 'Steam Pressure Lure',
        'Earth' => 'Monolith Taunt Field',
        'Mud' => 'Bog Snare Pit',
        'Dust' => 'Caltrop Lure Field',
        'Crystal' => 'Prism Snare Totem',
        'Air' => 'Cyclone Lure Field',
        'Plant' => 'Vine Snare Construct',
        'Poison' => 'Plague Snare Grid',
        'Spirit' => 'Phantom Lure Totem',
        'Dark' => 'Void Taunt Well',
        'Light' => 'Beacon Snare Field',
        'Blood' => 'Blood Lure Obelisk',
        _ => 'Taunt Trap Field',
      };
    case 'kin':
      return switch (element) {
        'Fire' => 'Inferno Blessing',
        'Lava' => 'Volcanic Blessing',
        'Lightning' => 'Tempest Blessing',
        'Water' => 'Divine Fountain',
        'Ice' => 'Glacier Blessing',
        'Steam' => 'Thermal Sanctuary',
        'Earth' => 'Fortress Blessing',
        'Mud' => 'Quagmire Blessing',
        'Dust' => 'Sandstorm Blessing',
        'Crystal' => 'Crystal Blessing',
        'Air' => 'Hurricane Blessing',
        'Plant' => 'Divine Bloom',
        'Poison' => 'Plague Blessing',
        'Spirit' => 'Divine Ascension',
        'Dark' => 'Eclipse Blessing',
        'Light' => 'Divinity',
        'Blood' => 'Blood Well',
        _ => 'Blessing Pulse',
      };
    case 'mystic':
      return switch (element) {
        'Fire' => 'Burning Orbitals',
        'Lava' => 'Magma Orbitals',
        'Lightning' => 'Storm Nodes',
        'Water' => 'Tidal Orbitals',
        'Ice' => 'Frost Orbitals',
        'Steam' => 'Vapor Orbitals',
        'Earth' => 'Stone Orbitals',
        'Mud' => 'Mire Orbitals',
        'Dust' => 'Sand Orbitals',
        'Crystal' => 'Prismatic Swarm',
        'Air' => 'Cyclone Orbitals',
        'Plant' => 'Thorn Orbitals',
        'Poison' => 'Toxic Orbitals',
        'Spirit' => 'Spectral Swarm',
        'Dark' => 'Void Orbitals',
        'Light' => 'Holy Orbitals',
        'Blood' => 'Blood Orbitals',
        _ => 'Orbital Storm',
      };
    default:
      return 'Special Attack';
  }
}

/// Family basic attacks — unchanged from original
List<Projectile> createFamilyBasicAttack({
  required Offset origin,
  required double angle,
  required String element,
  required String family,
  required double damage,
}) {
  switch (family.toLowerCase()) {
    case 'mane':
      return [
        Projectile(
          position: Offset(
            origin.dx + cos(angle - 0.08) * 15,
            origin.dy + sin(angle - 0.08) * 15,
          ),
          angle: angle - 0.08,
          element: element,
          damage: damage * 0.65 * kDamageScale,
        ),
        Projectile(
          position: Offset(
            origin.dx + cos(angle + 0.08) * 15,
            origin.dy + sin(angle + 0.08) * 15,
          ),
          angle: angle + 0.08,
          element: element,
          damage: damage * 0.65 * kDamageScale,
        ),
      ];
    case 'horn':
      return [
        Projectile(
          position: Offset(
            origin.dx + cos(angle) * 18,
            origin.dy + sin(angle) * 18,
          ),
          angle: angle,
          element: element,
          damage: damage * 1.6 * kDamageScale,
          speedMultiplier: 0.65,
          radiusMultiplier: 1.8,
          visualScale: 1.5,
        ),
      ];
    case 'mask':
      return [
        Projectile(
          position: Offset(
            origin.dx + cos(angle) * 15,
            origin.dy + sin(angle) * 15,
          ),
          angle: angle,
          element: element,
          damage: damage * 0.9 * kDamageScale,
          speedMultiplier: 1.3,
          piercing: true,
          life: 1.2,
        ),
      ];
    case 'wing':
      return [
        Projectile(
          position: Offset(
            origin.dx + cos(angle) * 12,
            origin.dy + sin(angle) * 12,
          ),
          angle: angle,
          element: element,
          damage: damage * 0.5 * kDamageScale,
          speedMultiplier: 1.5,
          visualScale: 0.75,
        ),
        Projectile(
          position: Offset(
            origin.dx + cos(angle) * 8,
            origin.dy + sin(angle) * 8,
          ),
          angle: angle,
          element: element,
          damage: damage * 0.5 * kDamageScale,
          speedMultiplier: 1.4,
          visualScale: 0.75,
          life: 1.9,
        ),
      ];
    case 'kin':
      return [
        Projectile(
          position: Offset(
            origin.dx + cos(angle) * 15,
            origin.dy + sin(angle) * 15,
          ),
          angle: angle,
          element: element,
          damage: damage * 1.1 * kDamageScale,
          speedMultiplier: 0.7,
          homing: true,
          homingStrength: 2.5,
          life: 2.5,
          visualScale: 1.1,
        ),
      ];
    case 'mystic':
      return List.generate(3, (i) {
        final a = angle + (i - 1) * 0.12;
        return Projectile(
          position: Offset(origin.dx + cos(a) * 15, origin.dy + sin(a) * 15),
          angle: a,
          element: element,
          damage: damage * 0.4 * kDamageScale,
          visualScale: 0.7,
        );
      });
    default:
      return [
        Projectile(
          position: Offset(
            origin.dx + cos(angle) * 15,
            origin.dy + sin(angle) * 15,
          ),
          angle: angle,
          element: element,
          damage: damage * kDamageScale,
        ),
      ];
  }
}

// ─────────────────────────────────────────────────────────
// STAR DUST
// ─────────────────────────────────────────────────────────

/// 50 fixed star-dust collectibles scattered across the cosmos.
/// Positions are deterministic from the world seed so all players share them.
class StarDust {
  final Offset position;
  final int index;
  bool collected;

  StarDust({
    required this.position,
    required this.index,
    this.collected = false,
  });

  /// Generate the 50 star-dust positions for a given seed.
  /// Avoids spawning too close to any planet.
  static List<StarDust> generate({
    required int seed,
    required Size worldSize,
    required List<CosmicPlanet> planets,
  }) {
    final rng = Random(seed ^ 0xDEADBEEF);
    const count = 50;
    const margin = 2000.0;
    const minPlanetDist = 2000.0;

    final dusts = <StarDust>[];
    for (var i = 0; i < count; i++) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
        tries++;
      } while (tries < 200 &&
          planets.any((p) => (p.position - pos).distance < minPlanetDist));

      dusts.add(StarDust(position: pos, index: i));
    }
    return dusts;
  }

  /// Speed multiplier: 1.0 at 0 collected, 2.0 at 50 collected (linear).
  static double speedMultiplier(int collectedCount) =>
      1.0 + (collectedCount.clamp(0, 50) / 50.0);

  /// Serialise collected indices to a compact string.
  static String serialiseCollected(Set<int> collected) =>
      (collected.toList()..sort()).join(',');

  /// Deserialise collected indices from a string.
  static Set<int> deserialiseCollected(String raw) {
    if (raw.isEmpty) return {};
    return raw
        .split(',')
        .map((s) => int.tryParse(s) ?? -1)
        .where((i) => i >= 0)
        .toSet();
  }
}

// ─────────────────────────────────────────────────────────
// VFX PARTICLES (kill effects, death explosion, etc.)
// ─────────────────────────────────────────────────────────

class VfxParticle {
  double x, y;
  double vx, vy;
  double size;
  double life;
  final double maxLife;
  final Color color;
  final double drag;

  VfxParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.life,
    required this.color,
    this.drag = 0.92,
  }) : maxLife = life;

  double get alpha => (life / maxLife * 2).clamp(0.0, 1.0);
  bool get dead => life <= 0;

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vx *= drag;
    vy *= drag;
    life -= dt;
  }
}

class VfxShockRing {
  double x, y;
  double radius;
  final double maxRadius;
  final double expandSpeed;
  final Color color;

  VfxShockRing({
    required this.x,
    required this.y,
    required this.maxRadius,
    required this.color,
    this.expandSpeed = 400.0,
  }) : radius = 0;

  double get progress => (radius / maxRadius).clamp(0.0, 1.0);
  double get alpha => (1.0 - progress).clamp(0.0, 1.0);
  bool get dead => radius >= maxRadius;

  void update(double dt) {
    radius += expandSpeed * dt;
  }
}

// ─────────────────────────────────────────────────────────
// ORBITAL ALCHEMY CHAMBER
// ─────────────────────────────────────────────────────────

/// A floating creature bubble that orbits the home planet.
/// Physics: gravitational pull toward home planet centre, elastic
/// collisions with other chambers & projectiles, always settles
/// back into orbit.
class OrbitalChamber {
  /// World-space position.
  Offset position;

  /// World-space velocity (px/s).
  Offset velocity;

  /// Visual / collision radius.
  double radius;

  /// Element-based colour for the orb glow.
  Color color;

  /// Unique seed for per-bubble animation phase.
  double seed;

  /// Elapsed life (for wobble / animations).
  double life;

  /// Associated creature instance ID (may be null for empty slot).
  String? instanceId;

  /// Base creature ID for sprite display.
  String? baseCreatureId;

  /// Display name shown under the orb.
  String? displayName;

  /// Static image path for the creature (e.g. 'creatures/rare/HOR01_firehorn.png').
  String? imagePath;

  /// Desired orbital distance from home planet centre.
  double orbitDistance;

  /// Whether this chamber is currently "knocked" (recently hit).
  bool knocked;

  /// Knockback recovery timer — seconds until gravity fully returns.
  double knockTimer;

  OrbitalChamber({
    required this.position,
    required this.velocity,
    this.radius = 18,
    required this.color,
    required this.seed,
    this.life = 0,
    this.instanceId,
    this.baseCreatureId,
    this.displayName,
    this.imagePath,
    this.orbitDistance = 200,
    this.knocked = false,
    this.knockTimer = 0,
  });

  /// Gravity constant — strength of pull toward home planet.
  static const double gravityStrength = 4000.0;

  /// Damping: velocity decays to settle into orbit smoothly.
  /// High damping = less bouncing, smoother convergence.
  static const double damping = 0.94;

  /// Max speed clamp to keep orbits gentle.
  static const double maxSpeed = 80.0;

  /// After being hit, how long before gravity fully kicks back in.
  static const double knockRecoveryTime = 2.5;

  /// Update physics: maintain orbit at [orbitDistance], never fall into planet.
  void update(double dt, Offset homeCentre) {
    life += dt;

    // ── Radial spring toward orbitDistance ──
    final toHome = homeCentre - position;
    final dist = toHome.distance;

    if (dist > 1.0) {
      final dir = toHome / dist;

      // Radial error: positive = too far out, negative = too close
      final error = dist - orbitDistance;

      // Critically-damped spring toward orbit ring.
      // Gentle outward / inward — low stiffness to avoid oscillation.
      final springK = error > 0 ? 40.0 : 90.0;
      final radialForce = error * springK;
      velocity += dir * radialForce * dt;

      // Gentle tangential drift to keep them circling slowly.
      final tangent = Offset(-dir.dy, dir.dx);
      final orbitDriftStrength = 14.0 + 5.0 * sin(seed);
      velocity += tangent * orbitDriftStrength * dt;
    }

    // ── Knockback recovery ──
    if (knocked) {
      knockTimer -= dt;
      if (knockTimer <= 0) {
        knocked = false;
        knockTimer = 0;
      }
    }

    // ── Damping — stronger when not knocked, so they settle ──
    final d = knocked ? 0.995 : damping;
    velocity *= d;

    // ── Speed clamp ──
    final speed = velocity.distance;
    if (speed > maxSpeed) {
      velocity = velocity / speed * maxSpeed;
    }

    // ── Integrate ──
    position += velocity * dt;
  }

  /// Apply an impulse (e.g. from projectile hit or fling).
  void applyImpulse(Offset impulse) {
    velocity += impulse;
    knocked = true;
    knockTimer = knockRecoveryTime;
  }
}

// ─────────────────────────────────────────────────────────
// GALAXY WHIRL (HORDE ENCOUNTER)
// ─────────────────────────────────────────────────────────

/// State of a galaxy whirl encounter.
enum WhirlState { dormant, active, completed }

/// Horde archetype — determines wave composition & enemy behaviour.
/// Assigned based on level: 1-3 Skirmish, 4-7 Siege, 8-10 Onslaught.
enum HordeType {
  /// Lv 1-3: Simple waves, mostly wisps/sentinels, moderate pacing.
  skirmish,

  /// Lv 4-7: Formation bursts spawn all at once, brute tanks, mini-boss on final wave.
  siege,

  /// Lv 8-10: Fast spawns, mixed tiers from wave 1, swarm-dominant, mini-boss brute finale.
  onslaught,
}

/// Derive the [HordeType] from a whirl level.
HordeType hordeTypeForLevel(int level) {
  if (level <= 3) return HordeType.skirmish;
  if (level <= 7) return HordeType.siege;
  return HordeType.onslaught;
}

/// A swirling galaxy vortex that spawns waves of enemies when the player
/// enters its activation radius. Survive all waves to earn rewards.
class GalaxyWhirl {
  Offset position;
  final String element;
  final int level; // 1-10
  final HordeType hordeType;
  final double radius;
  WhirlState state;
  int currentWave;
  final int totalWaves;
  double waveTimer;
  double spawnTimer;
  int enemiesSpawnedInWave;
  int enemiesAlive;
  double rotation;
  double pulse;
  bool miniBossSpawned; // for siege/onslaught final wave mini-boss

  static const double activationRadius = 200.0;

  /// Spawn interval varies by horde type.
  double get waveSpawnInterval => switch (hordeType) {
    HordeType.skirmish => 1.5,
    HordeType.siege => 0.3, // burst — nearly simultaneous
    HordeType.onslaught => 0.8, // fast but not instant
  };

  GalaxyWhirl({
    required this.position,
    required this.element,
    required this.level,
    this.radius = 60,
    this.state = WhirlState.dormant,
    this.currentWave = 0,
    this.totalWaves = 5,
    this.waveTimer = 0,
    this.spawnTimer = 0,
    this.enemiesSpawnedInWave = 0,
    this.enemiesAlive = 0,
    this.rotation = 0,
    this.pulse = 0,
    this.miniBossSpawned = false,
  }) : hordeType = hordeTypeForLevel(level);

  /// Number of enemies per wave — varies by horde type & level.
  int enemiesForWave(int wave) {
    switch (hordeType) {
      case HordeType.skirmish:
        // Gentle ramp: 2-3 base + 1 per wave
        return 2 + (level / 3).ceil() + wave;
      case HordeType.siege:
        // Burst formation: 4-6 base + 2 per wave, fewer total waves
        return 4 + (level / 2).ceil() + wave * 2;
      case HordeType.onslaught:
        // Relentless: 5-8 base + 2-3 per wave
        return 5 + (level / 2).ceil() + wave * (1 + (level / 4).ceil());
    }
  }

  /// Time limit per wave in seconds.
  double timeForWave(int wave) => switch (hordeType) {
    HordeType.skirmish => 30.0 + wave * 10.0,
    HordeType.siege => 40.0 + wave * 8.0, // more time for formation
    HordeType.onslaught => 25.0 + wave * 6.0, // tight timer
  };

  /// Shard reward for clearing all waves — scales with level & type.
  int get shardReward {
    final typeBonus = switch (hordeType) {
      HordeType.skirmish => 0,
      HordeType.siege => 8,
      HordeType.onslaught => 18,
    };
    return (10 + level * 5) + totalWaves * 3 + typeBonus;
  }

  /// Element particle reward for clearing all waves — scales with level.
  double get particleReward {
    final typeBonus = switch (hordeType) {
      HordeType.skirmish => 0.0,
      HordeType.siege => 5.0,
      HordeType.onslaught => 12.0,
    };
    return 5.0 + level * 3.0 + totalWaves * 2.0 + typeBonus;
  }

  /// Enemy health multiplier based on whirl level.
  /// Lv1=1.0x  Lv5=2.0x  Lv10=4.0x
  double get enemyHealthScale => 1.0 + (level - 1) * 0.33;

  /// Enemy speed multiplier based on whirl level.
  /// Lv1=1.0x  Lv5=1.3x  Lv10=1.6x
  double get enemySpeedScale => 1.0 + (level - 1) * 0.067;

  /// Display name for the horde type.
  String get hordeTypeName => switch (hordeType) {
    HordeType.skirmish => 'SKIRMISH',
    HordeType.siege => 'SIEGE',
    HordeType.onslaught => 'ONSLAUGHT',
  };

  /// Generate 5 galaxy whirls scattered across the world.
  static List<GalaxyWhirl> generate({
    required int seed,
    required Size worldSize,
    required List<CosmicPlanet> planets,
  }) {
    final rng = Random(seed ^ 0x6A1A);
    const count = 5;
    const margin = 3000.0;
    const minPlanetDist = 2500.0;
    const minWhirlDist = 4000.0;

    final elements = kElementColors.keys.toList();
    final whirls = <GalaxyWhirl>[];
    for (var i = 0; i < count; i++) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
        tries++;
      } while (tries < 200 &&
          (planets.any((p) => (p.position - pos).distance < minPlanetDist) ||
              whirls.any((w) => (w.position - pos).distance < minWhirlDist)));

      whirls.add(
        GalaxyWhirl(
          position: pos,
          element: elements[rng.nextInt(elements.length)],
          level: rng.nextInt(10) + 1, // 1-10
          radius: 50 + rng.nextDouble() * 30,
          totalWaves: 3 + rng.nextInt(3),
        ),
      );
    }
    return whirls;
  }
}

// ─────────────────────────────────────────────────────────
// SPACE POINTS OF INTEREST
// ─────────────────────────────────────────────────────────

/// Type of space point of interest.
enum POIType {
  nebula,
  derelict,
  comet,
  warpAnomaly,
  harvesterMarket,
  riftKeyMarket,
  cosmicMarket,
  stardustScanner,
}

/// A discoverable point of interest in the cosmos.
class SpacePOI {
  Offset position;
  final POIType type;
  final String element;
  final double radius;
  bool discovered;
  bool interacted;
  double life;
  double angle;
  double speed;

  SpacePOI({
    required this.position,
    required this.type,
    required this.element,
    this.radius = 40,
    this.discovered = false,
    this.interacted = false,
    this.life = 0,
    this.angle = 0,
    this.speed = 0,
  });

  /// Generate space POIs across the cosmos.
  static List<SpacePOI> generate({
    required int seed,
    required Size worldSize,
    required List<CosmicPlanet> planets,
  }) {
    final rng = Random(seed ^ 0xBB22);
    const margin = 2500.0;
    const minPlanetDist = 2000.0;
    final elements = kElementColors.keys.toList();

    final pois = <SpacePOI>[];

    // 6 nebulae
    for (var i = 0; i < 6; i++) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
        tries++;
      } while (tries < 150 &&
          planets.any((p) => (p.position - pos).distance < minPlanetDist));
      pois.add(
        SpacePOI(
          position: pos,
          type: POIType.nebula,
          element: elements[rng.nextInt(elements.length)],
          radius: 80 + rng.nextDouble() * 60,
        ),
      );
    }

    // 1 derelict
    for (var i = 0; i < 1; i++) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
        tries++;
      } while (tries < 150 &&
          planets.any((p) => (p.position - pos).distance < minPlanetDist));
      pois.add(
        SpacePOI(
          position: pos,
          type: POIType.derelict,
          element: elements[rng.nextInt(elements.length)],
          radius: 25,
        ),
      );
    }

    // 1 meteor shower zone (hidden on the map; encountered in-world)
    for (var i = 0; i < 1; i++) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
        tries++;
      } while (tries < 150 &&
          planets.any((p) => (p.position - pos).distance < minPlanetDist));
      pois.add(
        SpacePOI(
          position: pos,
          type: POIType.comet,
          element: elements[rng.nextInt(elements.length)],
          radius: 620,
          angle: rng.nextDouble() * pi * 2,
          speed: 0,
        ),
      );
    }

    // 3 warp anomalies
    for (var i = 0; i < 3; i++) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
        tries++;
      } while (tries < 150 &&
          planets.any((p) => (p.position - pos).distance < minPlanetDist));
      pois.add(
        SpacePOI(
          position: pos,
          type: POIType.warpAnomaly,
          element: 'Spirit',
          radius: 35 + rng.nextDouble() * 15,
        ),
      );
    }

    // 4 stations (harvester + rift key + cosmic + stardust scanner)
    for (final mType in [
      POIType.harvesterMarket,
      POIType.riftKeyMarket,
      POIType.cosmicMarket,
      POIType.stardustScanner,
    ]) {
      Offset pos;
      int tries = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * (worldSize.width - margin * 2),
          margin + rng.nextDouble() * (worldSize.height - margin * 2),
        );
        tries++;
      } while (tries < 150 &&
          (planets.any((p) => (p.position - pos).distance < minPlanetDist) ||
              pois.any((p) => (p.position - pos).distance < minPlanetDist)));
      pois.add(
        SpacePOI(
          position: pos,
          type: mType,
          element: mType == POIType.stardustScanner ? 'Light' : 'Crystal',
          radius: mType == POIType.stardustScanner ? 120 : 60,
          discovered: false, // discovered when ship gets close
        ),
      );
    }

    return pois;
  }
}

// ─────────────────────────────────────────────────────────
// SPACE MARKET
// Discoverable trading posts — one sells harvesters, one sells rift keys.
// ─────────────────────────────────────────────────────────

/// A rotating elemental discount recipe for a space-market item.
/// If the player's alchemical meter has ≥ [threshold]% of [requiredElement],
/// they receive a 50% discount on that item.
class MarketDiscountRecipe {
  final String requiredElement;
  final double threshold; // fraction 0..1 (0.5 = 50%)

  const MarketDiscountRecipe({
    required this.requiredElement,
    this.threshold = 0.50,
  });

  /// Check if the player's meter qualifies for the discount.
  bool qualifies(Map<String, double> meterBreakdown, double meterTotal) {
    if (meterTotal <= 0) return false;
    final amt = meterBreakdown[requiredElement] ?? 0;
    return (amt / meterTotal) >= threshold;
  }
}

/// Generates a set of rotating discount recipes keyed by inventory item key.
/// Recipes change daily and use elements thematically tied to each item's faction.
class MarketRecipeTable {
  /// Elements grouped by faction — discounts use elements from the SAME family.
  static const _factionElements = <String, List<String>>{
    'volcanic': ['Fire', 'Lava', 'Steam', 'Lightning'],
    'oceanic': ['Water', 'Ice', 'Steam', 'Mud'],
    'verdant': ['Plant', 'Earth', 'Mud', 'Dust'],
    'earthen': ['Earth', 'Dust', 'Crystal', 'Lava'],
    'arcane': ['Spirit', 'Dark', 'Light', 'Blood'],
    'neutral': ['Crystal', 'Spirit', 'Light', 'Blood'],
  };

  /// Generates recipes for a list of items using a daily rotating seed.
  /// Each item's recipe picks from its own faction's element pool.
  static Map<String, MarketDiscountRecipe> generate({
    required List<MarketItemEntry> items,
  }) {
    // Seed rotates every day (UTC midnight)
    final epochDay =
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ (24 * 3600 * 1000);
    final rng = Random(epochDay ^ 0xDEAD0042);

    final recipes = <String, MarketDiscountRecipe>{};
    for (final item in items) {
      final pool =
          _factionElements[item.faction] ?? _factionElements['neutral']!;
      recipes[item.key] = MarketDiscountRecipe(
        requiredElement: pool[rng.nextInt(pool.length)],
      );
    }
    return recipes;
  }
}

/// Lightweight entry passed to [MarketRecipeTable.generate] so it knows
/// each item's key and faction.
class MarketItemEntry {
  final String key;
  final String faction;
  const MarketItemEntry({required this.key, required this.faction});
}

// ─────────────────────────────────────────────────────────
// COSMIC PARTY MEMBER
// An alchemon that patrols space with your ship.
// ─────────────────────────────────────────────────────────

class CosmicPartyMember {
  /// Associated creature instance ID.
  final String instanceId;

  /// Base creature ID for sprite / type lookup.
  final String baseId;

  /// Display name (nickname or species name).
  final String displayName;

  /// Creature image asset path.
  final String? imagePath;

  /// Primary element type.
  final String element;

  /// Family archetype (horn, wing, let, pip, mane, kin, mystic, mask).
  final String family;

  /// Creature level.
  final int level;

  /// Base stats from the CreatureInstance.
  final double statSpeed;
  final double statIntelligence;
  final double statStrength;
  final double statBeauty;

  /// Slot index in the party (0-2).
  final int slotIndex;

  /// Current effective stamina bars (after regen).
  final int staminaBars;

  /// Maximum stamina bars.
  final int staminaMax;

  /// Sprite sheet definition for animated rendering.
  final SpriteSheetDef? spriteSheet;

  /// Visual modifiers (genetics, effects).
  final SpriteVisuals? spriteVisuals;

  final String? visualVariant;
  final Offset? spawnPosition;

  CosmicPartyMember({
    required this.instanceId,
    required this.baseId,
    required this.displayName,
    this.imagePath,
    required this.element,
    required this.family,
    required this.level,
    required this.statSpeed,
    required this.statIntelligence,
    required this.statStrength,
    required this.statBeauty,
    required this.slotIndex,
    required this.staminaBars,
    required this.staminaMax,
    this.spriteSheet,
    this.spriteVisuals,
    this.visualVariant,
    this.spawnPosition,
  });
}

/// Runtime state for a summoned (active) party alchemon in cosmic space.
class CosmicCompanion with HasEffects {
  final CosmicPartyMember member;

  /// World-space position (current, moves around anchor).
  Offset position;

  /// Anchor position — where the companion was placed.
  Offset anchorPosition;

  /// Current angle (radians) — faces enemies / movement direction.
  double angle;

  /// HP derived from survival combat stats.
  int maxHp;
  int currentHp;

  /// Derived combat stats (from SurvivalUnit formulas).
  final int _basePhysAtk;
  final int _baseElemAtk;
  final int _basePhysDef;
  final int _baseElemDef;
  final double _baseCooldownReduction;
  final double _baseCritChance;
  final double _baseAttackRange;
  final double _baseSpecialAbilityRange;

  // Effects mixin provides dynamic modifiers (powered by systems/effects/has_effects.dart).
  // Use getters below to return modified values.

  /// Cooldown tracking.
  double basicCooldown;
  double specialCooldown;
  static const double baseSpecialCooldown = 15.0; // 15s base
  static const double baseBasicCooldown = 1.5;

  /// Wander state — meanders near anchor.
  static const double wanderRadius = 80.0;
  double wanderAngle;
  double wanderTimer;

  /// Time alive (for animation).
  double life;

  /// Whether the companion is returning (fading out).
  bool returning;
  double returnTimer;

  /// Invincibility after being summoned.
  double invincibleTimer;

  /// Species-based sprite scale factor.
  double speciesScale;

  /// Shield absorption HP (Horn special). Absorbs damage before HP.
  int shieldHp;

  /// Charging state (Horn special). When > 0, companion rushes toward target.
  double chargeTimer;

  /// Charge target position.
  Offset? chargeTarget;

  /// Charge speed multiplier.
  static const double chargeSpeed = 400.0;

  /// Charge damage dealt on impact.
  double chargeDamage;

  /// Blessing heal timer (Kin special). When > 0, companion heals over time.
  double blessingTimer;

  /// Blessing heal amount per tick.
  double blessingHealPerTick;

  final String? visualVariant;

  CosmicCompanion({
    required this.member,
    required this.position,
    Offset? anchor,
    this.angle = 0,
    required this.maxHp,
    required this.currentHp,
    required int physAtk,
    required int elemAtk,
    required int physDef,
    required int elemDef,
    required double cooldownReduction,
    required double critChance,
    required double attackRange,
    required double specialAbilityRange,
    this.basicCooldown = 0,
    this.specialCooldown = baseSpecialCooldown,
    this.wanderAngle = 0,
    this.wanderTimer = 0,
    this.life = 0,
    this.returning = false,
    this.returnTimer = 0,
    this.invincibleTimer = 2.0,
    this.speciesScale = 1.0,
    this.shieldHp = 0,
    this.chargeTimer = 0,
    this.chargeTarget,
    this.chargeDamage = 0,
    this.blessingTimer = 0,
    this.blessingHealPerTick = 0,
    this.visualVariant,
  }) : _basePhysAtk = physAtk,
       _baseElemAtk = elemAtk,
       _basePhysDef = physDef,
       _baseElemDef = elemDef,
       _baseCooldownReduction = cooldownReduction,
       _baseCritChance = critChance,
       _baseAttackRange = attackRange,
       _baseSpecialAbilityRange = specialAbilityRange,
       anchorPosition = anchor ?? position;

  int get physAtk => _maybeModifyStat('physAtk', _basePhysAtk).round();
  int get elemAtk => _maybeModifyStat('elemAtk', _baseElemAtk).round();
  int get physDef => _maybeModifyStat('physDef', _basePhysDef).round();
  int get elemDef => _maybeModifyStat('elemDef', _baseElemDef).round();
  double get cooldownReduction =>
      _maybeModifyStat('cooldownReduction', _baseCooldownReduction);
  double get critChance => _maybeModifyStat('critChance', _baseCritChance);
  double get attackRange => _maybeModifyStat('attackRange', _baseAttackRange);
  double get specialAbilityRange =>
      _maybeModifyStat('specialAbilityRange', _baseSpecialAbilityRange);

  /// Effective cooldowns that factor in stats (speed via `cooldownReduction`,
  /// and damage/strength so stronger alchemons get different timings).
  double get effectiveBasicCooldown {
    final base = CosmicCompanion.baseBasicCooldown / cooldownReduction;
    final factor = (1.0 + (physAtk - 1) * 0.05).clamp(0.5, 3.0);
    return base / factor;
  }

  double get effectiveSpecialCooldown {
    final base = CosmicCompanion.baseSpecialCooldown / cooldownReduction;
    final factor = (1.0 + (elemAtk / 6.0) * 0.2).clamp(0.5, 6.0);
    return base / factor;
  }

  double _maybeModifyStat(String name, num base) {
    try {
      // Lazy import to avoid circular import at file top-level.
      // If the HasEffects mixin is applied and provides `modifyStat`, call it.
      final self = this;
      if ((self as dynamic).modifyStat is Function) {
        return (self as dynamic).modifyStat(name, base.toDouble());
      }
    } catch (_) {}
    return base.toDouble();
  }

  bool get isAlive => currentHp > 0 && !returning;
  double get hpPercent => currentHp / maxHp;
  bool get hasShield => shieldHp > 0;
  bool get isCharging => chargeTimer > 0;
  bool get isBlessing => blessingTimer > 0;

  void takeDamage(int dmg) {
    if (invincibleTimer > 0) return;
    // Shield absorbs damage first
    if (shieldHp > 0) {
      final absorbed = min(dmg, shieldHp);
      shieldHp -= absorbed;
      final remaining = dmg - absorbed;
      if (remaining > 0) {
        currentHp = (currentHp - remaining).clamp(0, maxHp);
      }
    } else {
      currentHp = (currentHp - dmg).clamp(0, maxHp);
    }
  }
}
