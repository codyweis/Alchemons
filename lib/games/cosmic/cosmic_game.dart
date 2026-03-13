// lib/games/cosmic/cosmic_game.dart
//
// Flame game for the Cosmic Alchemy Explorer.
// Player pilots a ship through a star field, discovers element planets,
// collects particles to fill a meter, and summons creatures.

import 'dart:math';
import 'dart:ui' as ui;

import 'cosmic_contests.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/utils/color_util.dart';
import 'package:alchemons/utils/effect_size.dart';
import 'package:flame/components.dart' show Anchor;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'cosmic_data.dart';
import 'package:alchemons/systems/effects/effect.dart';
import 'package:alchemons/systems/effects/effect_loader.dart';
import 'package:alchemons/systems/effects/effect_registry.dart';

part 'cosmic_game_helpers.dart';
part 'cosmic_game_components.dart';
part 'cosmic_game_companions_contests.dart';
part 'cosmic_game_world_systems.dart';
part 'cosmic_game_home_visuals.dart';

// ─────────────────────────────────────────────────────────
// MAIN GAME
// ─────────────────────────────────────────────────────────

class CosmicGame extends FlameGame with PanDetector {
  CosmicGame({
    required this.world_,
    required this.onMeterChanged,
    this.onPeriodicSave,
    this.onNearPlanet,
    this.onStarDustCollected,
    this.onNearRift,
    this.onHomePlanetBuilt,
    this.onAsteroidDestroyed,
    this.onNearHome,
    this.onBossSpawned,
    this.onShipDied,
    this.onLootCollected,
    this.onBossDefeated,
    this.onWhirlActivated,
    this.onWhirlWaveComplete,
    this.onWhirlComplete,
    this.onPOIDiscovered,
    this.onNearMarket,
    this.onCompanionAutoReturned,
    this.onCompanionDied,
    this.onNearNexus,
    this.onNearBattleRing,
    this.onNearBloodRing,
    this.onNearContestArena,
    this.onContestHintCollected,
    Set<String>? initialCustomizations,
    Map<String, String>? initialOptions,
    String? initialAmmoId,
  }) : activeCustomizations = initialCustomizations ?? {},
       customizationOptions = initialOptions ?? {},
       activeAmmoId = initialAmmoId;

  final CosmicWorld world_;
  final VoidCallback onMeterChanged;
  final VoidCallback? onPeriodicSave;
  final void Function(CosmicPlanet? planet)? onNearPlanet;
  final void Function(int index)? onStarDustCollected;
  final void Function(bool isNear)? onNearRift;
  final void Function(HomePlanet planet)? onHomePlanetBuilt;
  final void Function()? onAsteroidDestroyed;
  final void Function(bool isNear)? onNearHome;
  final void Function(String bossName)? onBossSpawned;
  final VoidCallback? onShipDied;
  final void Function(LootDrop drop)? onLootCollected;
  final void Function(String bossName)? onBossDefeated;
  final void Function(GalaxyWhirl whirl)? onWhirlActivated;
  final void Function(GalaxyWhirl whirl, int wave)? onWhirlWaveComplete;
  final void Function(GalaxyWhirl whirl)? onWhirlComplete;
  final void Function(SpacePOI poi)? onPOIDiscovered;
  final void Function(SpacePOI? poi)? onNearMarket;
  final VoidCallback? onCompanionAutoReturned;
  final void Function(CosmicPartyMember member)? onCompanionDied;
  final void Function(CosmicContestArena? arena)? onNearContestArena;
  final void Function(CosmicContestHintNote note)? onContestHintCollected;

  // ── state ──────────────────────────────────────────────
  final ElementMeter meter = ElementMeter();
  CosmicPlanet? nearPlanet;
  SpacePOI? nearMarket;
  int? _starDustScannerTargetIndex;
  int? _scannerCompletedDustIndex;

  late ShipComponent ship;
  // Loaded effect prototypes from assets
  List<Effect> _loadedEffectPrototypes = [];
  final List<PlanetComponent> planetComps = [];
  final List<ElementParticle> elemParticles = [];

  // Orbital alchemy chambers (floating creature bubbles around home planet)
  final List<OrbitalChamber> orbitalChambers = [];

  // Cached creature images for orbital chamber sprites
  final Map<String, ui.Image> _chamberSpriteCache = {};

  ui.Picture? _staticEffectsPicture;
  Set<String> _cachedCustomizations = {};
  double _cachedVr = 0;
  Offset _cachedPictureOffset = Offset.zero;

  // Stars stored in spatial grid for fast rendering
  static const double _starChunkSize = 800.0;
  late int _starGridW;
  late int _starGridH;
  late List<List<_StarParticle>> _starGrid;

  // Fog: each pixel in a conceptual grid is revealed when ship is nearby.
  // We use a Set of grid-cell keys for discovered cells.
  static const double fogCellSize = 120.0;
  final Set<int> revealedCells = {};

  // Star dust collectibles
  late List<StarDust> starDusts;
  int collectedDustCount = 0;

  // Rift portals (5 permanent, one per faction)
  double _riftPulse = 0;
  RiftPortal? _nearestRift; // closest rift within interact range
  bool _wasNearRift = false;

  // Elemental Nexus (black portal easter-egg)
  late ElementalNexus elementalNexus = world_.elementalNexus;
  bool _wasNearNexus = false;
  bool _isNearNexus = false;
  void Function(bool isNear)? onNearNexus;

  // Battle Ring (octagonal arena)
  late BattleRing battleRing = world_.battleRing;
  bool _wasNearBattleRing = false;
  bool _isNearBattleRing = false;
  bool get isNearBattleRing => _isNearBattleRing;
  void Function(bool isNear)? onNearBattleRing;

  // Blood Ring (ending ritual portal)
  late BloodRing bloodRing = world_.bloodRing;
  bool _wasNearBloodRing = false;
  bool _isNearBloodRing = false;
  bool get isNearBloodRing => _isNearBloodRing;
  void Function(bool isNear)? onNearBloodRing;

  // Trait contest arenas + hint notes (separate system from battle ring)
  late List<CosmicContestArena> contestArenas = world_.contestArenas;
  late List<CosmicContestHintNote> contestHintNotes = world_.contestHintNotes;
  CosmicContestArena? nearContestArena;

  // Battle Ring opponent (in-world 1v1)
  CosmicCompanion? battleRingOpponent;
  final List<Projectile> ringOpponentProjectiles = [];
  // Lightweight minions summoned to assist the ring opponent.
  // These are local to the ring fight and only target the player's companion.
  final List<RingMinion> ringMinions = [];
  // Pending minion spawn data: we spawn helpers only once the opponent
  // drops below half health. These fields store the planned spawn so we can
  // delay visual portal emergence until the threshold is reached.
  bool _ringMinionsSpawnedForCurrentOpponent = false;
  int _pendingRingMinionCount = 0;
  int _pendingRingMinionLevel = 0;
  String? _pendingRingMinionElement;

  // Lightweight ring-minion type
  // Local to this file: small helpers that assist the ring opponent.
  // They only target the player's companion and can be shot by the ship.
  // Keep this small to avoid pulling in extra dependencies.

  SpriteAnimationTicker? _ringOpponentTicker;
  SpriteVisuals? _ringOpponentVisuals;
  double _ringOpponentSpriteScale = 1.0;
  Sprite? _ringOpponentFallbackSprite;
  double _ringOpponentFallbackScale = 1.0;
  int _ringOpponentFallbackLoadToken = 0;
  int _ringOpponentSpriteLoadToken = 0;
  double _ringOpponentSpriteRetryTimer = 0.0;
  int _ringOpponentSpriteLoadsInFlight = 0;
  VoidCallback? onBattleRingWon;
  VoidCallback? onBattleRingLost;

  // Beauty contest in-arena cinematic (non-combat showcase)
  bool _beautyContestCinematicActive = false;
  Offset _beautyContestCenter = Offset.zero;
  double _beautyContestTimer = 0;
  bool _beautyContestCompAbilityA = false;
  bool _beautyContestOppAbilityA = false;
  bool _beautyContestCompAbilityB = false;
  bool _beautyContestOppAbilityB = false;
  double _beautyContestCompHopTimer = 0;
  double _beautyContestOppHopTimer = 0;
  static const double _beautyContestHopDuration = 0.82;
  static const double _beautyContestHopHeight = 24.0;
  static const double _beautyContestOrbitSpeed = 0.82;
  static const double _beautyContestCompAbilityATime = 3.0;
  static const double _beautyContestOppAbilityATime = 6.8;
  static const double _beautyContestCompAbilityBTime = 10.6;
  static const double _beautyContestOppAbilityBTime = 14.4;
  static const double _beautyContestIntroDuration = 0.95;
  static const double _beautyContestFinalPoseTime = 16.5;
  static const double _beautyContestFinalPoseBlendDuration = 0.9;
  bool _beautyContestPlayerWon = true;
  double _beautyContestCompVisualScale = 1.0;
  double _beautyContestOppVisualScale = 1.0;
  bool _beautyContestIntroActive = false;
  double _beautyContestIntroTimer = 0;
  Offset _beautyContestShipIntroStart = Offset.zero;
  Offset _beautyContestCompIntroStart = Offset.zero;
  Offset _beautyContestOppIntroStart = Offset.zero;
  _ContestCinematicMode _contestCinematicMode = _ContestCinematicMode.beauty;
  double _speedContestRaceDuration = 11.0;
  double _speedContestCompRate = 1.0;
  double _speedContestOppRate = 1.0;
  double _speedContestCompProgress = pi * 0.5;
  double _speedContestOppProgress = pi * 0.5 - 0.18;
  double _strengthContestDuration = 11.0;
  double _strengthContestCompForce = 1.0;
  double _strengthContestOppForce = 1.0;
  double _strengthContestShift = 0.0;
  double _intelligenceContestDuration = 11.0;
  double _intelligenceContestCompFocus = 1.0;
  double _intelligenceContestOppFocus = 1.0;
  double _intelligenceContestBias = 0.0;
  double _intelligenceContestOrbit = 0.0;
  Offset _intelligenceContestOrbPos = Offset.zero;
  bool get beautyContestCinematicActive => _beautyContestCinematicActive;
  double get beautyContestIntroDuration => _beautyContestIntroDuration;
  double get speedContestIntroDuration => _beautyContestIntroDuration;
  double get strengthContestIntroDuration => _beautyContestIntroDuration;
  double get intelligenceContestIntroDuration => _beautyContestIntroDuration;

  // Nexus pocket dimension
  bool inNexusPocket = false;
  String? nearPocketPortalElement; // element of closest pocket portal in range
  void Function(String? element)? onNearPocketPortal;

  // Warp anomaly flash animation
  double _warpFlash = 0; // counts down from 1.0

  // Home planet (player-built)
  HomePlanet? homePlanet;

  // Asteroid belt
  late AsteroidBelt asteroidBelt;

  // Ship weapons
  final List<Projectile> projectiles = [];
  double _shootCooldown = 0;
  static const double shootInterval = 0.25; // seconds between shots
  bool shooting = false; // controlled by UI
  bool shootingMissiles = false; // secondary missile fire (controlled by UI)
  double _missileShootCooldown = 0;
  bool _wasNearHome = false; // for change detection

  // Active home customizations (recipe IDs)
  Set<String> activeCustomizations;
  Map<String, String> customizationOptions; // 'recipeId.paramKey' -> value
  String? activeAmmoId;
  String? activeWeaponId; // 'equip_machinegun' or null (default)
  bool hasMissiles = false; // whether missile launcher is equipped
  String? activeShipSkin; // 'skin_phantom', 'skin_solar', or null (default)

  // Power-up levels (0-5), each level adds 16% damage (80% at max)
  int ammoUpgradeLevel = 0;
  int missileUpgradeLevel = 0;

  // ── Ship equipment ──
  // Fuel & booster
  final ShipFuel shipFuel = ShipFuel();
  bool boosting = false; // controlled by UI hold
  static const double boostSpeedMultiplier = 2.5;
  static const double slowSpeedMultiplier = 0.35;

  /// When true the ship moves at ~35% speed.
  bool slowMode = false;
  static const double boostFuelPerSecond =
      8.0; // fuel consumed/sec while boosting

  // Orbital sentinels
  final List<OrbitalSentinel> orbitals = [];
  int orbitalStockpile = 0; // built sentinels not yet deployed
  double _orbitalReplenishTimer = 0;

  // Missile tracking
  int missileAmmo = 0; // consumable ammo for homing missiles
  final List<_HomingMissile> _missiles = [];

  // Boost visual state (set in update, read in render)
  bool isBoosting = false;

  // Active companion (summoned party alchemon)
  CosmicCompanion? activeCompanion;
  final List<Projectile> companionProjectiles = [];
  SpriteAnimationTicker? _companionTicker;
  SpriteVisuals? _companionVisuals;
  double _companionSpriteScale = 1.0;
  final Random _rng = Random();

  // Home garrison (stationed alchemons inside home planet)
  final List<_GarrisonCreature> _garrison = [];

  // Enemies & bosses
  final List<CosmicEnemy> enemies = [];
  CosmicBoss? activeBoss;
  final List<BossProjectile> bossProjectiles = [];

  // Loot drops on the ground
  final List<LootDrop> lootDrops = [];
  final ShipWallet shipWallet = ShipWallet();
  double _enemySpawnTimer = 0;
  int _bossesDefeated = 0;
  int _nextPackId = 0; // unique pack ID counter
  static const int _maxEnemies = 160;
  static const double _enemySpawnInterval = 1.2; // seconds between checks
  static const double _meterPickupMultiplier = 3.0;

  // Swarm cluster spawn timer
  double _swarmSpawnTimer = 0;
  static const double _swarmSpawnInterval =
      20.0; // seconds between swarm spawns
  bool _initialSwarmsSpawned = false;

  // Random boss spawn timer
  double _bossSpawnTimer = 0;
  static const double _bossSpawnInterval = 22.5;

  // Boss lairs (always at least 1 on the map)
  late List<BossLair> bossLairs;

  // Galaxy whirls (horde encounters)
  late List<GalaxyWhirl> galaxyWhirls;
  GalaxyWhirl? activeWhirl;

  // Space POIs
  late List<SpacePOI> spacePOIs;

  // Prismatic Field (aurora easter-egg)
  late PrismaticField prismaticField = world_.prismaticField;
  bool prismaticRewardClaimed = false;
  double _prismaticCelebTimer = -1; // ≥ 0 while celebration running
  Offset? _prismaticCelebCenter; // orbit centre during celebration
  static const double _prismaticCelebDuration = 3.5; // seconds
  VoidCallback? onPrismaticRewardClaimed;

  // Prismatic field cached render-to-texture (~10fps refresh, full blur beauty)
  ui.Image? _prismaticCachedImage;
  double _prismaticCacheLife = -1; // life value when cache was built
  static const int _prismaticTexSize = 512; // render target size
  static const double _prismaticCacheInterval =
      0.1; // seconds between refreshes

  // Elemental nexus cached render-to-texture (same trick as prismatic aurora)
  ui.Image? _nexusCachedImage;
  double _nexusCacheTime = -1;
  static const int _nexusTexSize = 512;
  static const double _nexusCacheInterval = 0.1;
  // World-unit radius the texture covers (gravitational well glow = 600 + margin)
  static const double _nexusTexWorldR = 750.0;

  // Pocket dimension cached render-to-texture
  ui.Image? _pocketCachedImage;
  double _pocketCacheTime = -1;
  static const int _pocketTexSize = 512;
  static const double _pocketCacheInterval = 0.1;

  // Battle Ring cached render-to-texture
  ui.Image? _battleRingCachedImage;
  double _battleRingCacheTime = -1;
  static const int _battleRingTexSize = 512;
  static const double _battleRingCacheInterval = 0.1;
  static const double _battleRingTexWorldR = 550.0;

  // Feeding-pack spawn: separate timer, spawns near asteroid belt
  double _feedingPackTimer = 0;
  static const double _feedingPackInterval = 12.5;

  // Ship health
  double shipHealth = 5.0;
  static const double shipMaxHealth = 5.0;
  double _shipInvincible = 0; // invincibility timer after hit
  bool _shipDead = false;
  double _respawnTimer = 0;

  // Visual effects
  final List<VfxParticle> vfxParticles = [];
  final List<VfxShockRing> vfxRings = [];

  // Camera offset (ship is always centred; camera follows ship)
  double get camX => ship.pos.dx - size.x / 2;
  double get camY => ship.pos.dy - size.y / 2;

  // ── lifecycle ──────────────────────────────────────────

  @override
  Color backgroundColor() => const Color(0xFF020010);

  @override
  Future<void> onLoad() async {
    // Ship starts at the center of the world
    ship = ShipComponent(
      pos: Offset(world_.worldSize.width / 2, world_.worldSize.height / 2),
    );

    // Build planet components
    for (final planet in world_.planets) {
      planetComps.add(PlanetComponent(planet: planet));
    }

    // Seed background stars (procedural, dense) — stored in spatial grid
    final rng = Random(42);
    _starGridW = (world_.worldSize.width / _starChunkSize).ceil();
    _starGridH = (world_.worldSize.height / _starChunkSize).ceil();
    _starGrid = List.generate(
      _starGridW * _starGridH,
      (_) => <_StarParticle>[],
    );
    final starCount = (world_.worldSize.width * world_.worldSize.height / 20000)
        .round();
    for (var i = 0; i < starCount; i++) {
      final sx = rng.nextDouble() * world_.worldSize.width;
      final sy = rng.nextDouble() * world_.worldSize.height;
      final gx = (sx / _starChunkSize).floor().clamp(0, _starGridW - 1);
      final gy = (sy / _starChunkSize).floor().clamp(0, _starGridH - 1);
      _starGrid[gy * _starGridW + gx].add(
        _StarParticle(
          x: sx,
          y: sy,
          brightness: 0.2 + rng.nextDouble() * 0.8,
          size: 0.5 + rng.nextDouble() * 2.0,
          twinkleSpeed: 0.5 + rng.nextDouble() * 2.0,
        ),
      );
    }

    // Generate star dust collectibles
    starDusts = StarDust.generate(
      seed: world_.planets.first.element.hashCode ^ 0xC05,
      worldSize: world_.worldSize,
      planets: world_.planets,
    );

    // Generate asteroid belt
    asteroidBelt = AsteroidBelt.generate(
      seed: world_.planets.first.element.hashCode ^ 0xBEEF,
      worldSize: world_.worldSize,
    );

    // Generate galaxy whirls (horde encounters)
    galaxyWhirls = GalaxyWhirl.generate(
      seed: world_.planets.first.element.hashCode ^ 0xAA11,
      worldSize: world_.worldSize,
      planets: world_.planets,
    );

    // Generate space POIs
    spacePOIs = SpacePOI.generate(
      seed: world_.planets.first.element.hashCode ^ 0xBB22,
      worldSize: world_.worldSize,
      planets: world_.planets,
    );
    syncStarDustScannerAvailability();

    // Generate initial boss lairs (3-4 spread around the world)
    final lairRng = Random(world_.planets.first.element.hashCode ^ 0xCC33);
    final lairCount = 3 + lairRng.nextInt(2); // 3 or 4
    bossLairs = [];
    for (int i = 0; i < lairCount; i++) {
      bossLairs.add(
        BossLair.generate(
          rng: lairRng,
          worldSize: world_.worldSize,
          planets: world_.planets,
          whirls: galaxyWhirls,
          existing: bossLairs,
        ),
      );
    }

    // Reveal initial area around ship
    _revealAround(ship.pos, 300);

    // Load effect prototypes from JSON (non-blocking for gameplay setup)
    try {
      _loadedEffectPrototypes = await loadEffectsFromAsset(
        'assets/data/effects.json',
      );
    } catch (e) {
      // ignore - optional
    }
  }

  // ── input ──────────────────────────────────────────────

  Offset? _dragTarget;

  /// Normalised steering direction from the virtual joystick (null = idle).
  Offset? joystickDirection;

  /// When true, pan gestures are ignored (tap-to-shoot handles input instead).
  bool tapToShootMode = false;

  @override
  void onPanStart(DragStartInfo info) {
    if (tapToShootMode) return;
    _dragTarget = _wrap(
      Offset(
        info.eventPosition.global.x + camX,
        info.eventPosition.global.y + camY,
      ),
    );
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (tapToShootMode) return;
    _dragTarget = _wrap(
      Offset(
        info.eventPosition.global.x + camX,
        info.eventPosition.global.y + camY,
      ),
    );
  }

  @override
  void onPanEnd(DragEndInfo info) {
    // Keep drifting toward last target — don't null it
  }

  /// Set drag target from screen coordinates (used by tap-to-shoot mode).
  void setDragTargetFromScreen(Offset screenPos) {
    _dragTarget = _wrap(Offset(screenPos.dx + camX, screenPos.dy + camY));
  }

  /// Set a world travel target and steer using shortest toroidal path.
  void setTravelTarget(Offset worldPos) {
    _dragTarget = _wrap(worldPos);
    joystickDirection = null;
  }

  /// Teleport ship directly (for mini-map clicks).
  void teleportTo(Offset worldPos) {
    ship.pos = worldPos;
    _revealAround(ship.pos, 300);
  }

  // ── Companion (party alchemon) ──

  /// Species-type scale factors for companion sprites (from survival mode).
  static const Map<String, double> _companionSpeciesScale = {
    'let': 1.0,
    'pip': 1.0,
    'mane': 1.2,
    'horn': 1.7,
    'mask': 1.5,
    'wing': 2.0,
    'kin': 2.0,
    'mystic': 2.4,
  };

  // ── update loop ────────────────────────────────────────

  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    if (_beautyContestCinematicActive) {
      _updateBeautyContestCinematic(dt);
      return;
    }

    // ── ship movement ──
    double baseSpeed = _shipDead
        ? 0.0
        : 220.0 * StarDust.speedMultiplier(collectedDustCount);

    // Apply boost if booster is equipped and player is holding boost
    isBoosting = false;
    if (boosting && !_shipDead && !shipFuel.isEmpty) {
      final fuelUsed = shipFuel.consume(boostFuelPerSecond * dt);
      if (fuelUsed > 0) {
        baseSpeed *= boostSpeedMultiplier;
        isBoosting = true;
      }
    }
    if (slowMode && !_shipDead) baseSpeed *= slowSpeedMultiplier;
    final shipSpeed = baseSpeed;

    bool shipIsIdle = false;
    // ── Joystick steering takes priority over drag-target ──
    if (joystickDirection != null) {
      final jx = joystickDirection!.dx;
      final jy = joystickDirection!.dy;
      final mag = sqrt(jx * jx + jy * jy);
      if (mag > 0.05) {
        final nx = jx / mag;
        final ny = jy / mag;
        // Use magnitude (0-1) to scale speed for analogue feel
        final move = shipSpeed * mag.clamp(0.0, 1.0) * dt;
        ship.pos = Offset(ship.pos.dx + nx * move, ship.pos.dy + ny * move);
        ship.angle = atan2(ny, nx);
        // Clear drag target so ship doesn't snap back
        _dragTarget = null;
      } else {
        shipIsIdle = true;
      }
    } else if (_dragTarget != null) {
      var dx = _dragTarget!.dx - ship.pos.dx;
      var dy = _dragTarget!.dy - ship.pos.dy;
      final ww = world_.worldSize.width;
      final wh = world_.worldSize.height;
      if (dx > ww / 2) dx -= ww;
      if (dx < -ww / 2) dx += ww;
      if (dy > wh / 2) dy -= wh;
      if (dy < -wh / 2) dy += wh;
      final dist = sqrt(dx * dx + dy * dy);

      if (dist > 5) {
        final nx = dx / dist;
        final ny = dy / dist;
        final move = min(shipSpeed * dt, dist);
        ship.pos = Offset(ship.pos.dx + nx * move, ship.pos.dy + ny * move);
        ship.angle = atan2(ny, nx);
      } else {
        shipIsIdle = true;
      }
    } else {
      shipIsIdle = true;
    }

    // ── Nexus pocket dimension mode ──
    if (inNexusPocket) {
      _updatePocketMode(dt);
      return; // skip normal world update
    }

    // ── gravity from planets ──
    double gx = 0, gy = 0;
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    CosmicPlanet? orbitPlanet;
    double orbitDist = double.infinity;
    for (final planet in world_.planets) {
      // Shortest distance accounting for wrapping
      var pdx = planet.position.dx - ship.pos.dx;
      var pdy = planet.position.dy - ship.pos.dy;
      if (pdx > ww / 2) pdx -= ww;
      if (pdx < -ww / 2) pdx += ww;
      if (pdy > wh / 2) pdy -= wh;
      if (pdy < -wh / 2) pdy += wh;
      final dist2 = pdx * pdx + pdy * pdy;
      final dist = sqrt(dist2);
      // Only apply gravity within ~600 units; prevent extreme close forces
      if (dist < 600 && dist > planet.radius * 0.5) {
        final force = planet.gravityStrength / dist2;
        gx += (pdx / dist) * force;
        gy += (pdy / dist) * force;
      }
      // Track closest planet for orbit
      if (dist < planet.radius * 3.5 && dist < orbitDist) {
        orbitPlanet = planet;
        orbitDist = dist;
      }
    }

    // ── gravity from home planet ──
    double homeOrbitR = 0;
    bool nearHomePlanet = false;
    if (homePlanet != null) {
      final hp = homePlanet!;
      final hpR = hp.visualRadius;
      var hdx = hp.position.dx - ship.pos.dx;
      var hdy = hp.position.dy - ship.pos.dy;
      if (hdx > ww / 2) hdx -= ww;
      if (hdx < -ww / 2) hdx += ww;
      if (hdy > wh / 2) hdy -= wh;
      if (hdy < -wh / 2) hdy += wh;
      final hDist2 = hdx * hdx + hdy * hdy;
      final hDist = sqrt(hDist2);
      // Gravity pull within 500 units
      if (hDist < 500 && hDist > hpR * 0.4) {
        final hForce = 25000.0 / hDist2;
        gx += (hdx / hDist) * hForce;
        gy += (hdy / hDist) * hForce;
      }
      // Home planet can be an orbit target too (prioritise over cosmic planets
      // when closer)
      homeOrbitR = hpR * 2.2;
      if (hDist < hpR * 4.0 && hDist < orbitDist) {
        nearHomePlanet = true;
        orbitDist = hDist;
        orbitPlanet = null; // clear cosmic orbit — home takes priority
      }
    }

    ship.pos = Offset(ship.pos.dx + gx * dt, ship.pos.dy + gy * dt);

    // ── ship orbit when idle near a planet ──
    if (shipIsIdle && !_shipDead && (orbitPlanet != null || nearHomePlanet)) {
      // Determine orbit centre, radius
      final Offset orbitCentre;
      final double desiredR;
      if (nearHomePlanet) {
        orbitCentre = homePlanet!.position;
        desiredR = homeOrbitR;
      } else {
        orbitCentre = orbitPlanet!.position;
        desiredR = orbitPlanet.radius * 2.0;
      }
      var pdx = orbitCentre.dx - ship.pos.dx;
      var pdy = orbitCentre.dy - ship.pos.dy;
      if (pdx > ww / 2) pdx -= ww;
      if (pdx < -ww / 2) pdx += ww;
      if (pdy > wh / 2) pdy -= wh;
      if (pdy < -wh / 2) pdy += wh;
      final dist = sqrt(pdx * pdx + pdy * pdy);
      if (dist > 1.0) {
        final dir = Offset(pdx / dist, pdy / dist);
        // Gently pull/push toward orbit radius
        final radialError = dist - desiredR;
        final radialForce = radialError.clamp(-80.0, 80.0) * 0.8;
        ship.pos = Offset(
          ship.pos.dx + dir.dx * radialForce * dt,
          ship.pos.dy + dir.dy * radialForce * dt,
        );
        // Tangential orbit drift
        final tangent = Offset(-dir.dy, dir.dx);
        final orbitSpeed = nearHomePlanet
            ? 30.0 + homePlanet!.visualRadius * 0.2
            : 35.0 + orbitPlanet!.radius * 0.25;
        ship.pos = Offset(
          ship.pos.dx + tangent.dx * orbitSpeed * dt,
          ship.pos.dy + tangent.dy * orbitSpeed * dt,
        );
        // Smoothly rotate ship to face tangent direction
        ship.angle = atan2(tangent.dy, tangent.dx);
        // Update drag target to follow orbit so ship doesn't snap back
        _dragTarget = ship.pos;
      }
    }

    // ── wrap ship position ──
    ship.pos = _wrap(ship.pos);

    // ── reveal fog ──
    _revealAround(ship.pos, 280);

    // ── discover planets ──
    for (var i = 0; i < world_.planets.length; i++) {
      final p = world_.planets[i];
      if (!p.discovered) {
        final dist = (p.position - ship.pos).distance;
        if (dist < p.radius + 200) {
          p.discovered = true;
          // Guarantee a boss on first discovery
          _spawnDiscoveryBoss(p);
        }
      }
    }

    // ── detect nearest planet for recipe HUD ──
    CosmicPlanet? closest;
    double closestDist = double.infinity;
    for (final p in world_.planets) {
      if (!p.discovered) continue;
      var pdx = p.position.dx - ship.pos.dx;
      var pdy = p.position.dy - ship.pos.dy;
      if (pdx > ww / 2) pdx -= ww;
      if (pdx < -ww / 2) pdx += ww;
      if (pdy > wh / 2) pdy -= wh;
      if (pdy < -wh / 2) pdy += wh;
      final dist = sqrt(pdx * pdx + pdy * pdy);
      if (dist < p.radius * 4 && dist < closestDist) {
        closest = p;
        closestDist = dist;
      }
    }
    if (closest != nearPlanet) {
      nearPlanet = closest;
      onNearPlanet?.call(closest);
    }

    // ── detect nearest market POI ──
    SpacePOI? closestMarket;
    double closestMarketDist = double.infinity;
    for (final poi in spacePOIs) {
      if (poi.type != POIType.harvesterMarket &&
          poi.type != POIType.riftKeyMarket &&
          poi.type != POIType.cosmicMarket &&
          poi.type != POIType.stardustScanner) {
        continue;
      }
      var mdx = poi.position.dx - ship.pos.dx;
      var mdy = poi.position.dy - ship.pos.dy;
      if (mdx > ww / 2) mdx -= ww;
      if (mdx < -ww / 2) mdx += ww;
      if (mdy > wh / 2) mdy -= wh;
      if (mdy < -wh / 2) mdy += wh;
      final dist = sqrt(mdx * mdx + mdy * mdy);
      // Discover market when ship is within visual range
      if (!poi.discovered && dist < poi.radius * 4) {
        poi.discovered = true;
      }
      if (dist < poi.radius * 2.5 && dist < closestMarketDist) {
        closestMarket = poi;
        closestMarketDist = dist;
      }
    }
    if (closestMarket != nearMarket) {
      nearMarket = closestMarket;
      onNearMarket?.call(closestMarket);
    }

    // ── detect near home planet ──
    final nearHome = isNearHome;
    if (nearHome != _wasNearHome) {
      _wasNearHome = nearHome;
      onNearHome?.call(nearHome);
    }

    // ── emit element particles from planets ──
    final rng = Random();
    const maxParticles = 600;
    for (final planet in world_.planets) {
      // Use wrapped distance for emission check
      var edx = planet.position.dx - ship.pos.dx;
      var edy = planet.position.dy - ship.pos.dy;
      if (edx > ww / 2) edx -= ww;
      if (edx < -ww / 2) edx += ww;
      if (edy > wh / 2) edy -= wh;
      if (edy < -wh / 2) edy += wh;
      final screenDist = sqrt(edx * edx + edy * edy);
      if (screenDist > 4000) continue;
      if (elemParticles.length >= maxParticles) break;

      // Emit rate scales with proximity: faster when close
      final emitRate = screenDist < 2000 ? 12.0 : 6.0;
      if (rng.nextDouble() < dt * emitRate) {
        final angle = rng.nextDouble() * pi * 2;
        final spawnDist =
            planet.radius + rng.nextDouble() * planet.particleFieldRadius;
        elemParticles.add(
          ElementParticle(
            x: planet.position.dx + cos(angle) * spawnDist,
            y: planet.position.dy + sin(angle) * spawnDist,
            vx: cos(angle) * (15 + rng.nextDouble() * 45),
            vy: sin(angle) * (15 + rng.nextDouble() * 45),
            element: planet.element,
            life: 8.0 + rng.nextDouble() * 10.0,
            size: 2.0 + rng.nextDouble() * 3.0,
          ),
        );
      }
    }

    // ── update & collect element particles ──
    for (var i = elemParticles.length - 1; i >= 0; i--) {
      final p = elemParticles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;

      if (p.life <= 0) {
        elemParticles.removeAt(i);
        continue;
      }

      // Check collection by ship
      final dx = p.x - ship.pos.dx;
      final dy = p.y - ship.pos.dy;
      if (dx * dx + dy * dy < 30 * 30) {
        // Collected!
        if (!meter.isFull) {
          meter.add(p.element, 0.5 * _meterPickupMultiplier);
          onMeterChanged();
        }
        elemParticles.removeAt(i);
      }
    }

    // ── warp flash animation ──
    if (_warpFlash > 0) {
      _warpFlash -= dt * 1.2; // ~0.85 sec total
      if (_warpFlash < 0) _warpFlash = 0;
    }

    // ── particle swarms: drift, orbit motes, collect ──
    final ww2 = world_.worldSize.width;
    final wh2 = world_.worldSize.height;
    for (final swarm in world_.particleSwarms) {
      swarm.pulse += dt;

      // Drift the swarm centre slowly (always, even off-screen)
      swarm.driftTimer -= dt;
      if (swarm.driftTimer <= 0) {
        swarm.driftAngle += (Random().nextDouble() - 0.5) * 1.2;
        swarm.driftTimer = 3.0 + Random().nextDouble() * 4.0;
      }
      swarm.center = _wrap(
        Offset(
          swarm.center.dx +
              cos(swarm.driftAngle) * ParticleSwarm.driftSpeed * dt,
          swarm.center.dy +
              sin(swarm.driftAngle) * ParticleSwarm.driftSpeed * dt,
        ),
      );

      // Distance cull: skip per-mote work if swarm centre is far from ship
      var sdx = swarm.center.dx - ship.pos.dx;
      var sdy = swarm.center.dy - ship.pos.dy;
      if (sdx > ww2 / 2) sdx -= ww2;
      if (sdx < -ww2 / 2) sdx += ww2;
      if (sdy > wh2 / 2) sdy -= wh2;
      if (sdy < -wh2 / 2) sdy += wh2;
      final swarmDist2 = sdx * sdx + sdy * sdy;
      // Only update motes within ~1200 units (cloudRadius + comfortable margin)
      const swarmCullRange = 1200.0;
      if (swarmDist2 > swarmCullRange * swarmCullRange) continue;

      // Update each mote — gentle orbit + collection
      for (final mote in swarm.motes) {
        if (mote.collected) continue;

        // Gentle orbital motion around the swarm centre
        mote.orbitPhase += mote.orbitSpeed * dt;
        final wobbleX = cos(mote.orbitPhase) * 8.0 * dt;
        final wobbleY = sin(mote.orbitPhase * 1.3) * 8.0 * dt;
        mote.offsetX += wobbleX;
        mote.offsetY += wobbleY;

        // Soft cohesion: pull back toward centre if too far
        final dist = sqrt(
          mote.offsetX * mote.offsetX + mote.offsetY * mote.offsetY,
        );
        if (dist > ParticleSwarm.cloudRadius) {
          final pull = (dist - ParticleSwarm.cloudRadius) * 0.5 * dt;
          mote.offsetX -= (mote.offsetX / dist) * pull;
          mote.offsetY -= (mote.offsetY / dist) * pull;
        }

        // World-space position of this mote
        final mx = swarm.center.dx + mote.offsetX;
        final my = swarm.center.dy + mote.offsetY;

        // Toroidal distance to ship
        var mdx = mx - ship.pos.dx;
        var mdy = my - ship.pos.dy;
        if (mdx > ww2 / 2) mdx -= ww2;
        if (mdx < -ww2 / 2) mdx += ww2;
        if (mdy > wh2 / 2) mdy -= wh2;
        if (mdy < -wh2 / 2) mdy += wh2;
        final mDist2 = mdx * mdx + mdy * mdy;

        // Magnetic pull when close
        if (mDist2 < ParticleSwarm.magnetRadius * ParticleSwarm.magnetRadius) {
          final mDist = sqrt(mDist2);
          if (mDist > 1) {
            final pull =
                180.0 * (1.0 - mDist / ParticleSwarm.magnetRadius) * dt;
            // Pull mote toward ship by adjusting its offset
            mote.offsetX -= (mdx / mDist) * pull;
            mote.offsetY -= (mdy / mDist) * pull;
          }
        }

        // Collect when very close
        if (mDist2 <
            ParticleSwarm.collectRadius * ParticleSwarm.collectRadius) {
          mote.collected = true;
          if (!meter.isFull) {
            meter.add(swarm.element, 1.0 * _meterPickupMultiplier);
            onMeterChanged();
          }
        }
      }

      // If swarm is depleted, respawn it elsewhere
      if (swarm.depleted) {
        _respawnSwarm(swarm);
      }
    }

    // ── collect star dust ──
    for (final dust in starDusts) {
      if (dust.collected) continue;
      final ddx = dust.position.dx - ship.pos.dx;
      final ddy = dust.position.dy - ship.pos.dy;
      if (ddx * ddx + ddy * ddy < 50 * 50) {
        dust.collected = true;
        collectedDustCount++;
        if (_starDustScannerTargetIndex == dust.index) {
          _starDustScannerTargetIndex = null;
          _scannerCompletedDustIndex = dust.index;
        }
        syncStarDustScannerAvailability();
        onStarDustCollected?.call(dust.index);
      }
    }

    // ── loot drops: update, magnetic pull, collection ──
    for (var i = lootDrops.length - 1; i >= 0; i--) {
      final drop = lootDrops[i];
      if (drop.collected || drop.expired) {
        lootDrops.removeAt(i);
        continue;
      }
      drop.update(dt);
      // Wrap to world
      drop.position = _wrap(drop.position);

      // Magnetic pull toward ship when close
      final ldx = ship.pos.dx - drop.position.dx;
      final ldy = ship.pos.dy - drop.position.dy;
      final ldist2 = ldx * ldx + ldy * ldy;
      if (ldist2 < LootDrop.magnetRadius * LootDrop.magnetRadius &&
          ldist2 > 1) {
        final ldist = sqrt(ldist2);
        final pullStrength = 300.0 * (1.0 - ldist / LootDrop.magnetRadius);
        drop.velocity += Offset(
          ldx / ldist * pullStrength * dt,
          ldy / ldist * pullStrength * dt,
        );
      }

      // Pickup
      if (ldist2 < LootDrop.pickupRadius * LootDrop.pickupRadius) {
        drop.collected = true;
        onLootCollected?.call(drop);
      }
    }

    // ── ship shooting (primary weapon) ──
    if (_shootCooldown > 0) _shootCooldown -= dt;
    final fireRate = activeWeaponId == 'equip_machinegun'
        ? 0.10
        : shootInterval;
    if (shooting && !_shipDead && _shootCooldown <= 0) {
      _shootCooldown = fireRate;
      projectiles.add(
        Projectile(
          position: Offset(
            ship.pos.dx + cos(ship.angle) * 20,
            ship.pos.dy + sin(ship.angle) * 20,
          ),
          angle: ship.angle,
        ),
      );
    }

    // ── missile launcher (secondary weapon, fires independently) ──
    if (_missileShootCooldown > 0) _missileShootCooldown -= dt;
    if (shootingMissiles &&
        hasMissiles &&
        !_shipDead &&
        _missileShootCooldown <= 0) {
      if (missileAmmo > 0) {
        _missileShootCooldown = 0.60;
        missileAmmo--;
        _missiles.add(
          _HomingMissile(
            position: Offset(
              ship.pos.dx + cos(ship.angle) * 20,
              ship.pos.dy + sin(ship.angle) * 20,
            ),
            angle: ship.angle,
          ),
        );
      }
    }

    // ── update homing missiles ──
    for (var i = _missiles.length - 1; i >= 0; i--) {
      final m = _missiles[i];
      // Find nearest enemy to track
      Offset? target;
      double bestDist2 = double.infinity;
      for (final e in enemies) {
        if (e.dead) continue;
        final edx = e.position.dx - m.position.dx;
        final edy = e.position.dy - m.position.dy;
        final d2 = edx * edx + edy * edy;
        if (d2 < bestDist2) {
          bestDist2 = d2;
          target = e.position;
        }
      }
      if (activeBoss != null) {
        final bdx = activeBoss!.position.dx - m.position.dx;
        final bdy = activeBoss!.position.dy - m.position.dy;
        final bd2 = bdx * bdx + bdy * bdy;
        if (bd2 < bestDist2) {
          target = activeBoss!.position;
        }
      }
      // Steer toward target
      if (target != null) {
        final desired = atan2(
          target.dy - m.position.dy,
          target.dx - m.position.dx,
        );
        var diff = desired - m.angle;
        // Normalise to -pi..pi
        while (diff > pi) {
          diff -= 2 * pi;
        }
        while (diff < -pi) {
          diff += 2 * pi;
        }
        m.angle += diff.clamp(
          -_HomingMissile.turnRate * dt,
          _HomingMissile.turnRate * dt,
        );
      }
      m.position = Offset(
        m.position.dx + cos(m.angle) * _HomingMissile.speed * dt,
        m.position.dy + sin(m.angle) * _HomingMissile.speed * dt,
      );
      m.life -= dt;
      if (m.life <= 0) {
        _missiles.removeAt(i);
        continue;
      }
      // Check collision with enemies
      final missileMult = HomeCustomizationState.damageMultiplier(
        missileUpgradeLevel,
      );
      bool missileHit = false;
      for (final e in enemies) {
        if (e.dead) continue;
        final edx = m.position.dx - e.position.dx;
        final edy = m.position.dy - e.position.dy;
        if (edx * edx + edy * edy < (e.radius + 6) * (e.radius + 6)) {
          e.health -= 5.0 * missileMult; // missiles do heavy damage
          _spawnHitSpark(m.position, const Color(0xFFFF6F00));
          if (!e.provoked &&
              (e.behavior == EnemyBehavior.feeding ||
                  e.behavior == EnemyBehavior.territorial ||
                  e.behavior == EnemyBehavior.drifting)) {
            _provokePackOf(e);
          }
          if (e.health <= 0) {
            e.dead = true;
            _spawnKillVfx(e.position, elementColor(e.element), e.radius, false);
            _spawnLootDrops(e.position, e.element, e.shardDrop, e.particleDrop);
          }
          missileHit = true;
          break;
        }
      }
      // Check boss
      if (!missileHit && activeBoss != null) {
        final boss = activeBoss!;
        final bdx = m.position.dx - boss.position.dx;
        final bdy = m.position.dy - boss.position.dy;
        if (bdx * bdx + bdy * bdy < (boss.radius + 6) * (boss.radius + 6)) {
          if (boss.shieldUp && boss.type == BossType.gunner) {
            boss.shieldHealth -= 5.0 * missileMult;
            _spawnHitSpark(m.position, Colors.cyanAccent);
            if (boss.shieldHealth <= 0) {
              boss.shieldUp = false;
              boss.shieldTimer = CosmicBoss.shieldCooldown;
            }
          } else {
            boss.health -= 5.0 * missileMult;
            _spawnHitSpark(m.position, const Color(0xFFFF6F00));
            if (boss.health <= 0) {
              _handleBossKill(boss);
            }
          }
          missileHit = true;
        }
      }
      if (missileHit) {
        _missiles.removeAt(i);
      }
    }

    // ── update orbital sentinels ──
    for (var i = orbitals.length - 1; i >= 0; i--) {
      orbitals[i].update(dt);
      final oPos = orbitals[i].positionAround(ship.pos);
      // Skip collision while fading in (invulnerable)
      if (!orbitals[i].invulnerable) {
        // Check collision with enemies
        for (final e in enemies) {
          if (e.dead) continue;
          final edx = oPos.dx - e.position.dx;
          final edy = oPos.dy - e.position.dy;
          if (edx * edx + edy * edy <
              (OrbitalSentinel.hitboxRadius + e.radius) *
                  (OrbitalSentinel.hitboxRadius + e.radius)) {
            // Both take damage
            orbitals[i].health -=
                0.2; // sentinel takes a hit but survives several
            e.health -= 3.5; // orbitals deal heavy damage
            _spawnHitSpark(oPos, const Color(0xFF42A5F5));
            if (!e.provoked &&
                (e.behavior == EnemyBehavior.feeding ||
                    e.behavior == EnemyBehavior.territorial ||
                    e.behavior == EnemyBehavior.drifting)) {
              _provokePackOf(e);
            }
            if (e.health <= 0) {
              e.dead = true;
              _spawnKillVfx(
                e.position,
                elementColor(e.element),
                e.radius,
                false,
              );
              _spawnLootDrops(
                e.position,
                e.element,
                e.shardDrop,
                e.particleDrop,
              );
            }
            break;
          }
        }
      }
      if (orbitals[i].dead) {
        _spawnKillVfx(oPos, const Color(0xFF42A5F5), 8, false);
        orbitals.removeAt(i);
      }
    }
    // Auto-respawn destroyed sentinels after cooldown (requires stockpile)
    if (orbitals.length < OrbitalSentinel.maxActive && orbitalStockpile > 0) {
      _orbitalReplenishTimer += dt;
      if (_orbitalReplenishTimer >= OrbitalSentinel.respawnCooldown) {
        _orbitalReplenishTimer = 0;
        orbitalStockpile--;
        final angle = orbitals.isEmpty
            ? 0.0
            : orbitals.last.angle + (2 * pi / OrbitalSentinel.maxActive);
        orbitals.add(OrbitalSentinel(angle: angle));
      }
    } else {
      _orbitalReplenishTimer = 0;
    }

    // ── update projectiles ──
    for (var i = projectiles.length - 1; i >= 0; i--) {
      final p = projectiles[i];
      p.position = Offset(
        p.position.dx + cos(p.angle) * Projectile.speed * dt,
        p.position.dy + sin(p.angle) * Projectile.speed * dt,
      );
      p.life -= dt;
      if (p.life <= 0) {
        projectiles.removeAt(i);
        continue;
      }

      // ── projectile vs asteroid collision ──
      final ammoMult = HomeCustomizationState.damageMultiplier(
        ammoUpgradeLevel,
      );
      final projDmg =
          (activeWeaponId == 'equip_machinegun' ? 0.15 : 0.34) * ammoMult;
      for (final rock in asteroidBelt.asteroids) {
        if (rock.destroyed) continue;
        final rdx = p.position.dx - rock.position.dx;
        final rdy = p.position.dy - rock.position.dy;
        if (rdx * rdx + rdy * rdy <
            (rock.radius + Projectile.radius) *
                (rock.radius + Projectile.radius)) {
          rock.health -= projDmg;
          _spawnHitSpark(p.position, const Color(0xFF8B7355));
          projectiles.removeAt(i);
          if (rock.destroyed) {
            _spawnKillVfx(
              rock.position,
              const Color(0xFF8B7355),
              rock.radius,
              false,
            );
            // ~40% chance to drop 1-2 shards
            if (Random().nextDouble() < 0.4) {
              _spawnLootDrops(
                rock.position,
                'Earth',
                Random().nextInt(2) + 1,
                0,
              );
            }
            onAsteroidDestroyed?.call();
          }
          break;
        }
      }

      // ── projectile vs enemy collision ──
      if (i < projectiles.length && projectiles[i] == p) {
        for (var ei = enemies.length - 1; ei >= 0; ei--) {
          final enemy = enemies[ei];
          if (enemy.dead) continue;
          final edx = p.position.dx - enemy.position.dx;
          final edy = p.position.dy - enemy.position.dy;
          final hitR = enemy.radius + Projectile.radius;
          if (edx * edx + edy * edy < hitR * hitR) {
            // Machine gun: lower damage per shot but rapid fire
            final eDmg =
                ((activeWeaponId == 'equip_machinegun' ? 0.35 : 1.0) *
                    HomeCustomizationState.damageMultiplier(ammoUpgradeLevel)) *
                kDamageScale;
            enemy.health -= eDmg;
            // Hit spark
            _spawnHitSpark(p.position, elementColor(enemy.element));
            // Provoke pack if passive enemy was hit
            if (!enemy.provoked &&
                (enemy.behavior == EnemyBehavior.feeding ||
                    enemy.behavior == EnemyBehavior.territorial ||
                    enemy.behavior == EnemyBehavior.drifting)) {
              _provokePackOf(enemy);
            }
            projectiles.removeAt(i);
            if (enemy.health <= 0) {
              enemy.dead = true;
              _spawnKillVfx(
                enemy.position,
                elementColor(enemy.element),
                enemy.radius,
                false,
              );
              _spawnLootDrops(
                enemy.position,
                enemy.element,
                enemy.shardDrop,
                enemy.particleDrop,
              );
            }
            break;
          }
        }
      }

      // ── projectile vs ring-minion collision (ring fight only) ──
      if (i < projectiles.length &&
          projectiles[i] == p &&
          battleRing.inBattle &&
          ringMinions.isNotEmpty) {
        for (var ri = ringMinions.length - 1; ri >= 0; ri--) {
          final rm = ringMinions[ri];
          if (rm.dead) continue;
          final rdx = p.position.dx - rm.position.dx;
          final rdy = p.position.dy - rm.position.dy;
          final rHitR = rm.radius + Projectile.radius;
          if (rdx * rdx + rdy * rdy < rHitR * rHitR) {
            final projDmg =
                ((activeWeaponId == 'equip_machinegun' ? 0.35 : 1.0) *
                    HomeCustomizationState.damageMultiplier(ammoUpgradeLevel)) *
                kDamageScale;
            rm.health -= projDmg;
            _spawnHitSpark(p.position, elementColor(rm.element));
            projectiles.removeAt(i);
            if (rm.health <= 0) {
              rm.dead = true;
              _spawnKillVfx(
                rm.position,
                elementColor(rm.element),
                rm.radius,
                false,
              );
            }
            break;
          }
        }
      }

      // ── projectile vs orbital chamber collision ──
      if (i < projectiles.length && projectiles[i] == p) {
        for (final chamber in orbitalChambers) {
          final cdx = p.position.dx - chamber.position.dx;
          final cdy = p.position.dy - chamber.position.dy;
          final cHitR = chamber.radius + Projectile.radius;
          if (cdx * cdx + cdy * cdy < cHitR * cHitR) {
            // Apply impulse in projectile direction
            final pDir = Offset(cos(p.angle), sin(p.angle));
            chamber.applyImpulse(pDir * 280.0);
            _spawnHitSpark(p.position, chamber.color);
            projectiles.removeAt(i);
            break;
          }
        }
      }

      // ── projectile vs boss collision ──
      if (activeBoss != null &&
          !activeBoss!.dead &&
          i < projectiles.length &&
          projectiles[i] == p) {
        final boss = activeBoss!;
        final bdx = p.position.dx - boss.position.dx;
        final bdy = p.position.dy - boss.position.dy;
        final bHitR = boss.radius + Projectile.radius;
        if (bdx * bdx + bdy * bdy < bHitR * bHitR) {
          // Gunner shield absorbs damage
          final projBossDmg =
              (1.0 *
                  HomeCustomizationState.damageMultiplier(ammoUpgradeLevel)) *
              kDamageScale;
          if (boss.shieldUp && boss.type == BossType.gunner) {
            boss.shieldHealth -= projBossDmg;
            _spawnHitSpark(p.position, Colors.cyanAccent);
            projectiles.removeAt(i);
            if (boss.shieldHealth <= 0) {
              boss.shieldUp = false;
              boss.shieldTimer = CosmicBoss.shieldCooldown;
            }
          } else {
            boss.health -= projBossDmg;
            _spawnHitSpark(p.position, elementColor(boss.element));
            projectiles.removeAt(i);
            if (boss.health <= 0) {
              _handleBossKill(boss);
            }
          }
        }
      }
    }

    // ── asteroid orbital drift ──
    final beltCx = asteroidBelt.center.dx;
    final beltCy = asteroidBelt.center.dy;
    for (final rock in asteroidBelt.asteroids) {
      if (rock.destroyed) continue;
      rock.orbitAngle += rock.orbitSpeed * dt;
      rock.position = Offset(
        beltCx + cos(rock.orbitAngle) * rock.orbitDist,
        beltCy + sin(rock.orbitAngle) * rock.orbitDist,
      );
    }

    // ── update companion (summoned party alchemon) ──
    if (activeCompanion != null) {
      final comp = activeCompanion!;
      comp.life += dt;
      comp.invincibleTimer = (comp.invincibleTimer - dt).clamp(0.0, 10.0);

      // Advance sprite animation
      _companionTicker?.update(dt);

      // Returning fade-out
      if (comp.returning) {
        comp.returnTimer -= dt;
        if (comp.returnTimer <= 0) {
          activeCompanion = null;
          _companionTicker = null;
          _companionVisuals = null;
        }
      } else if (comp.currentHp <= 0) {
        // Companion died — auto return
        _spawnKillVfx(
          comp.position,
          elementColor(comp.member.element),
          12,
          false,
        );
        final diedMember = comp.member;
        activeCompanion = null;
        _companionTicker = null;
        _companionVisuals = null;
        onCompanionDied?.call(diedMember);
      } else {
        // Auto-return if companion is far off screen (skip during ring battle)
        final margin = 350.0;
        final dx = (comp.position.dx - ship.pos.dx).abs();
        final dy = (comp.position.dy - ship.pos.dy).abs();
        if (!battleRing.inBattle &&
            (dx > size.x / 2 + margin || dy > size.y / 2 + margin)) {
          comp.returning = true;
          comp.returnTimer = 0.6;
          onCompanionAutoReturned?.call();
        } else {
          comp.wanderTimer -= dt;
          if (comp.wanderTimer <= 0) {
            // Pick a new wander direction every 2-3s
            comp.wanderAngle = _rng.nextDouble() * 2 * pi;
            comp.wanderTimer = 2.0 + _rng.nextDouble();
          }

          // Drift gently toward the wander target (stays within radius)
          final wanderTarget = Offset(
            comp.anchorPosition.dx +
                cos(comp.wanderAngle) * CosmicCompanion.wanderRadius * 0.6,
            comp.anchorPosition.dy +
                sin(comp.wanderAngle) * CosmicCompanion.wanderRadius * 0.6,
          );
          final toWander = wanderTarget - comp.position;
          final wanderDist = toWander.distance;
          if (wanderDist > 2.0) {
            final wanderSpeed = 40.0 * dt; // gentle drift
            comp.position +=
                (toWander / wanderDist) * min(wanderSpeed, wanderDist);
          }

          // Clamp within wander radius of anchor
          final fromAnchor = comp.position - comp.anchorPosition;
          if (fromAnchor.distance > CosmicCompanion.wanderRadius) {
            final clamped =
                (fromAnchor / fromAnchor.distance) *
                CosmicCompanion.wanderRadius;
            comp.position = comp.anchorPosition + clamped;
          }

          // Auto-attack nearest enemy
          comp.basicCooldown = (comp.basicCooldown - dt).clamp(0.0, 100.0);
          comp.specialCooldown = (comp.specialCooldown - dt).clamp(0.0, 100.0);

          // ── Horn charge: rush toward target, AoE on arrival ──
          if (comp.isCharging) {
            comp.chargeTimer -= dt;
            if (comp.chargeTarget != null) {
              final toTarget = comp.chargeTarget! - comp.position;
              final dist = toTarget.distance;
              if (dist > 10) {
                final step = CosmicCompanion.chargeSpeed * dt;
                comp.position += (toTarget / dist) * min(step, dist);
                comp.angle = atan2(toTarget.dy, toTarget.dx);
              } else {
                // Arrived — deal AoE damage to nearby enemies
                for (final e in enemies) {
                  if (e.dead) continue;
                  final d = (e.position - comp.position).distance;
                  if (d < 60) {
                    e.health -= comp.chargeDamage;
                    _spawnHitSpark(
                      e.position,
                      elementColor(comp.member.element),
                    );
                    if (!e.provoked) _provokePackOf(e);
                  }
                }
                if (activeBoss != null) {
                  final bd = (activeBoss!.position - comp.position).distance;
                  if (bd < 60) {
                    activeBoss!.health -= comp.chargeDamage;
                    _spawnHitSpark(
                      comp.position,
                      elementColor(comp.member.element),
                    );
                  }
                }
                // Ring opponent charge hit
                if (battleRingOpponent != null && battleRingOpponent!.isAlive) {
                  final rd =
                      (battleRingOpponent!.position - comp.position).distance;
                  if (rd < 60) {
                    battleRingOpponent!.takeDamage(comp.chargeDamage.round());
                    _spawnHitSpark(
                      battleRingOpponent!.position,
                      elementColor(comp.member.element),
                    );
                  }
                }
                comp.chargeTimer = 0;
                comp.chargeTarget = null;
              }
            }
            if (comp.chargeTimer <= 0) {
              comp.chargeTarget = null;
            }
          }

          // ── Kin blessing: heal over time ──
          if (comp.isBlessing) {
            comp.blessingTimer -= dt;
            // Heal a small tick each frame
            comp.currentHp = min(
              comp.maxHp,
              comp.currentHp + (comp.blessingHealPerTick * dt).round(),
            );
          }

          // Find nearest enemy in engage range (basic or special).
          final engageRange = max(comp.attackRange, comp.specialAbilityRange);
          CosmicEnemy? nearestEnemy;
          double nearestDist = engageRange;

          // During ring battle, prioritise the ring opponent
          bool targetIsRingOpponent = false;
          if (battleRingOpponent != null &&
              battleRingOpponent!.isAlive &&
              battleRing.inBattle) {
            final rd = (battleRingOpponent!.position - comp.position).distance;
            if (rd < nearestDist) {
              nearestDist = rd;
              targetIsRingOpponent = true;
            }
          }

          if (!targetIsRingOpponent) {
            for (final e in enemies) {
              if (e.dead) continue;
              final d = (e.position - comp.position).distance;
              if (d < nearestDist) {
                nearestDist = d;
                nearestEnemy = e;
              }
            }
          }

          // Also check boss
          if (!targetIsRingOpponent && activeBoss != null) {
            final bd = (activeBoss!.position - comp.position).distance;
            if (bd < nearestDist) {
              nearestEnemy = null; // handled separately below
              nearestDist = bd;
            }
          }

          if (targetIsRingOpponent ||
              nearestEnemy != null ||
              (activeBoss != null && nearestDist < engageRange)) {
            final targetPos = targetIsRingOpponent
                ? battleRingOpponent!.position
                : (nearestEnemy?.position ?? activeBoss!.position);
            // Face target (for sprite flipping & shooting direction)
            final toTarget = targetPos - comp.position;
            comp.angle = atan2(toTarget.dy, toTarget.dx);

            // If the target is out of special range, move toward it.
            final distToTarget = toTarget.distance;
            if (distToTarget > comp.specialAbilityRange) {
              final chaseSpeed = 100.0 + (comp.member.statSpeed * 10.0);
              final step = chaseSpeed * dt;
              comp.position +=
                  (toTarget / distToTarget) * min(step, distToTarget);
            }

            // Basic attack — family-specific pattern
            if (comp.basicCooldown <= 0 && distToTarget <= comp.attackRange) {
              comp.basicCooldown = comp.effectiveBasicCooldown;
              final basics = createFamilyBasicAttack(
                origin: comp.position,
                angle: comp.angle,
                element: comp.member.element,
                family: comp.member.family,
                damage: comp.physAtk.toDouble(),
              );
              companionProjectiles.addAll(basics);
            }

            // Special attack (every 30s base, scaled by cooldownReduction)
            // Each family has a unique ability, flavored by element!
            if (comp.specialCooldown <= 0 &&
                distToTarget <= comp.specialAbilityRange) {
              comp.specialCooldown = comp.effectiveSpecialCooldown;
              // Generate family+element special ability
              final result = createCosmicSpecialAbility(
                origin: comp.position,
                baseAngle: comp.angle,
                family: comp.member.family,
                element: comp.member.element,
                damage: comp.elemAtk * 2.0,
                maxHp: comp.maxHp,
                targetPos: targetPos,
              );
              companionProjectiles.addAll(result.projectiles);
              // Apply companion state changes from ability
              if (result.shieldHp > 0) comp.shieldHp = result.shieldHp;
              if (result.chargeTimer > 0) {
                comp.chargeTimer = result.chargeTimer;
                comp.chargeDamage = result.chargeDamage;
                comp.chargeTarget = targetPos;
              }
              if (result.selfHeal > 0) {
                comp.currentHp = min(
                  comp.maxHp,
                  comp.currentHp + result.selfHeal,
                );
              }
              if (result.blessingTimer > 0) {
                comp.blessingTimer = result.blessingTimer;
                comp.blessingHealPerTick = result.blessingHealPerTick;
              }
              // VFX burst
              _spawnHitSpark(comp.position, elementColor(comp.member.element));
            }
          } else {
            // No enemy — face wander direction
            comp.angle = comp.wanderAngle;
          }

          // Companion takes damage from enemies that touch it
          for (final e in enemies) {
            if (e.dead) continue;
            final d = (e.position - comp.position).distance;
            if (d < e.radius + 15) {
              final contactDmg = switch (e.tier) {
                EnemyTier.colossus => 25.0,
                EnemyTier.brute => 15.0,
                EnemyTier.phantom => 10.0,
                EnemyTier.sentinel => 8.0,
                EnemyTier.drone => 5.0,
                EnemyTier.wisp => 3.0,
              };
              final dmg = max(
                1,
                (contactDmg * 100 / (100 + comp.physDef)).round(),
              );
              comp.takeDamage(dmg);
              _spawnHitSpark(comp.position, elementColor(e.element));
            }
          }
        }
      }
    }

    // ── update battle ring opponent ──
    if (battleRingOpponent != null && battleRing.inBattle) {
      final opp = battleRingOpponent!;
      opp.life += dt;
      opp.invincibleTimer = (opp.invincibleTimer - dt).clamp(0.0, 10.0);
      _ringOpponentTicker?.update(dt);

      if (opp.currentHp <= 0) {
        // Ring opponent died — player wins
        _spawnKillVfx(
          opp.position,
          elementColor(opp.member.element),
          16,
          false,
        );
        dismissBattleRingOpponent();
        onBattleRingWon?.call();
      } else {
        // Wander near ring center
        opp.wanderTimer -= dt;
        if (opp.wanderTimer <= 0) {
          opp.wanderAngle = _rng.nextDouble() * 2 * pi;
          opp.wanderTimer = 2.0 + _rng.nextDouble();
        }
        final wanderTargetO = Offset(
          opp.anchorPosition.dx +
              cos(opp.wanderAngle) * CosmicCompanion.wanderRadius * 0.6,
          opp.anchorPosition.dy +
              sin(opp.wanderAngle) * CosmicCompanion.wanderRadius * 0.6,
        );
        final toWanderO = wanderTargetO - opp.position;
        final wanderDistO = toWanderO.distance;
        if (wanderDistO > 2.0) {
          final wanderSpeedO = 40.0 * dt;
          opp.position +=
              (toWanderO / wanderDistO) * min(wanderSpeedO, wanderDistO);
        }
        // Clamp within wander radius
        final fromAnchorO = opp.position - opp.anchorPosition;
        if (fromAnchorO.distance > CosmicCompanion.wanderRadius) {
          opp.position =
              opp.anchorPosition +
              (fromAnchorO / fromAnchorO.distance) *
                  CosmicCompanion.wanderRadius;
        }

        // Cooldowns
        opp.basicCooldown = (opp.basicCooldown - dt).clamp(0.0, 100.0);
        opp.specialCooldown = (opp.specialCooldown - dt).clamp(0.0, 100.0);

        // If we haven't spawned helper minions for this opponent yet,
        // check whether the opponent has dropped below half HP and
        // trigger the portal/orbital spawn then.
        if (!_ringMinionsSpawnedForCurrentOpponent &&
            battleRingOpponent != null &&
            battleRingOpponent!.currentHp <=
                (battleRingOpponent!.maxHp * 0.5)) {
          _spawnPendingRingMinions();
        }

        // Target the player's companion
        if (activeCompanion != null && activeCompanion!.isAlive) {
          final comp = activeCompanion!;
          final toComp = comp.position - opp.position;
          var distToComp = toComp.distance;
          opp.angle = atan2(toComp.dy, toComp.dx);

          if (opp.isBlessing) {
            opp.blessingTimer -= dt;
            opp.currentHp = min(
              opp.maxHp,
              opp.currentHp + (opp.blessingHealPerTick * dt).round(),
            );
          }

          var skipActions = false;
          if (opp.isCharging) {
            opp.chargeTimer -= dt;
            opp.chargeTarget = comp.position;
            final toTarget = opp.chargeTarget! - opp.position;
            final dist = toTarget.distance;
            if (dist > 10) {
              final step = CosmicCompanion.chargeSpeed * dt;
              opp.position += (toTarget / dist) * min(step, dist);
              opp.angle = atan2(toTarget.dy, toTarget.dx);
            } else {
              final dmg = max(
                1,
                (opp.chargeDamage * 100 / (100 + comp.physDef)).round(),
              );
              comp.takeDamage(dmg);
              _spawnHitSpark(comp.position, elementColor(opp.member.element));
              opp.chargeTimer = 0;
              opp.chargeTarget = null;
            }
            if (opp.chargeTimer > 0) {
              skipActions = true;
            } else {
              final refreshToComp = comp.position - opp.position;
              distToComp = refreshToComp.distance;
              opp.angle = atan2(refreshToComp.dy, refreshToComp.dx);
            }
          }

          if (!skipActions) {
            final engageRange = max(opp.attackRange, opp.specialAbilityRange);
            final toCompNow = comp.position - opp.position;
            distToComp = toCompNow.distance;
            // If the player's companion is out of engage range, move toward it.
            if (distToComp > engageRange) {
              final chaseSpeedOpp = 100.0 + (opp.member.statSpeed * 10.0);
              final stepOpp = chaseSpeedOpp * dt;
              opp.position +=
                  (toCompNow / distToComp) * min(stepOpp, distToComp);
            }

            // Basic attack
            if (distToComp <= opp.attackRange && opp.basicCooldown <= 0) {
              opp.basicCooldown = opp.effectiveBasicCooldown;
              final basics = createFamilyBasicAttack(
                origin: opp.position,
                angle: opp.angle,
                element: opp.member.element,
                family: opp.member.family,
                damage: opp.physAtk.toDouble(),
              );
              ringOpponentProjectiles.addAll(basics);
            }

            // Special attack
            if (distToComp <= opp.specialAbilityRange &&
                opp.specialCooldown <= 0) {
              opp.specialCooldown = opp.effectiveSpecialCooldown;
              final result = createCosmicSpecialAbility(
                origin: opp.position,
                baseAngle: opp.angle,
                family: opp.member.family,
                element: opp.member.element,
                damage: opp.elemAtk * 2.0,
                maxHp: opp.maxHp,
                targetPos: comp.position,
              );
              ringOpponentProjectiles.addAll(result.projectiles);
              if (result.shieldHp > 0) opp.shieldHp = result.shieldHp;
              if (result.chargeTimer > 0) {
                opp.chargeTimer = result.chargeTimer;
                opp.chargeDamage = result.chargeDamage;
                opp.chargeTarget = comp.position;
              }
              if (result.selfHeal > 0) {
                opp.currentHp = min(opp.maxHp, opp.currentHp + result.selfHeal);
              }
              if (result.blessingTimer > 0) {
                opp.blessingTimer = result.blessingTimer;
                opp.blessingHealPerTick = result.blessingHealPerTick;
              }
              _spawnHitSpark(opp.position, elementColor(opp.member.element));
            }
          }
        } else if (activeCompanion == null || !activeCompanion!.isAlive) {
          // Companion died during ring battle — player loses
          dismissBattleRingOpponent();
          onBattleRingLost?.call();
        }
      }
    }

    // ── update ring opponent projectiles ──
    for (var i = ringOpponentProjectiles.length - 1; i >= 0; i--) {
      final p = ringOpponentProjectiles[i];

      if (p.homing && activeCompanion != null && activeCompanion!.isAlive) {
        final target = activeCompanion!.position;
        final desired = atan2(
          target.dy - p.position.dy,
          target.dx - p.position.dx,
        );
        double diff = desired - p.angle;
        while (diff > pi) {
          diff -= 2 * pi;
        }
        while (diff < -pi) {
          diff += 2 * pi;
        }
        final maxTurn = p.homingStrength * dt;
        p.angle += diff.clamp(-maxTurn, maxTurn);
      }

      final pSpeed = Projectile.speed * p.speedMultiplier;

      // Handle orbital projectiles
      if (p.orbitCenter != null && p.orbitTime > 0) {
        p.orbitTime -= dt;
        p.orbitAngle += p.orbitSpeed * dt;
        p.orbitRadius += dt * 8.0;
        p.position = Offset(
          p.orbitCenter!.dx + cos(p.orbitAngle) * p.orbitRadius,
          p.orbitCenter!.dy + sin(p.orbitAngle) * p.orbitRadius,
        );
        if (p.orbitTime <= 0) {
          p.angle = atan2(
            p.position.dy - p.orbitCenter!.dy,
            p.position.dx - p.orbitCenter!.dx,
          );
          p.orbitCenter = null;
        }
      } else if (p.stationary) {
        // no movement
      } else {
        p.position = Offset(
          p.position.dx + cos(p.angle) * pSpeed * dt,
          p.position.dy + sin(p.angle) * pSpeed * dt,
        );
      }

      if (p.trailInterval > 0 && !p.stationary && p.orbitCenter == null) {
        p.trailTimer += dt;
        if (p.trailTimer >= p.trailInterval) {
          p.trailTimer -= p.trailInterval;
          ringOpponentProjectiles.add(
            Projectile(
              position: p.position,
              angle: 0,
              element: p.element,
              damage: p.trailDamage,
              life: p.trailLife,
              stationary: true,
              radiusMultiplier: 1.5,
              piercing: true,
              visualScale: 1.2,
            ),
          );
        }
      }

      if (p.clusterCount > 0 && !p.clustered && p.life < 0.75) {
        p.clustered = true;
        for (var ci = 0; ci < p.clusterCount; ci++) {
          final ca = ci * (pi * 2 / p.clusterCount);
          ringOpponentProjectiles.add(
            Projectile(
              position: Offset(
                p.position.dx + cos(ca) * 10,
                p.position.dy + sin(ca) * 10,
              ),
              angle: ca,
              element: p.element,
              damage: p.clusterDamage,
              life: 1.5,
              speedMultiplier: 0.7,
              radiusMultiplier: 1.5,
              piercing: true,
              visualScale: 1.0,
            ),
          );
        }
      }

      p.life -= dt;
      if (p.life <= 0) {
        ringOpponentProjectiles.removeAt(i);
        continue;
      }

      // Hit player's companion
      if (activeCompanion != null && activeCompanion!.isAlive) {
        final comp = activeCompanion!;
        final hitRadius = Projectile.radius * p.radiusMultiplier;
        final dx = p.position.dx - comp.position.dx;
        final dy = p.position.dy - comp.position.dy;
        if (dx * dx + dy * dy < (hitRadius + 15) * (hitRadius + 15)) {
          final pierceFalloff = p.piercing
              ? pow(0.7, p.pierceCount).toDouble()
              : 1.0;
          final dmg = max(
            1,
            (p.damage * pierceFalloff * 100 / (100 + comp.elemDef)).round(),
          );
          comp.takeDamage(dmg);
          _spawnHitSpark(
            p.position,
            elementColor(battleRingOpponent?.member.element ?? 'Earth'),
          );
          if (p.piercing) {
            p.pierceCount++;
          } else if (p.bounceCount > 0) {
            p.bounceCount--;
            p.pierceCount++;
            p.angle += pi * 0.65 + (_rng.nextDouble() * pi * 0.7);
          } else {
            ringOpponentProjectiles.removeAt(i);
          }
          continue;
        }
      }
    }

    _updateRingMinions(dt);

    // ── update companion projectiles ──
    for (var i = companionProjectiles.length - 1; i >= 0; i--) {
      final p = companionProjectiles[i];

      // Homing: steer toward nearest enemy
      if (p.homing) {
        double bestDist = double.infinity;
        Offset? bestTarget;
        for (final e in enemies) {
          if (e.dead) continue;
          final d = (e.position - p.position).distance;
          if (d < bestDist) {
            bestDist = d;
            bestTarget = e.position;
          }
        }
        // Also allow companion projectiles to home onto ring minions during a ring fight
        if (battleRing.inBattle) {
          for (final rm in ringMinions) {
            if (rm.dead) continue;
            final d = (rm.position - p.position).distance;
            if (d < bestDist) {
              bestDist = d;
              bestTarget = rm.position;
            }
          }
        }
        if (activeBoss != null) {
          final bd = (activeBoss!.position - p.position).distance;
          if (bd < bestDist) {
            bestTarget = activeBoss!.position;
          }
        }
        if (bestTarget != null) {
          final desired = atan2(
            bestTarget.dy - p.position.dy,
            bestTarget.dx - p.position.dx,
          );
          // Shortest-arc turn
          double diff = desired - p.angle;
          while (diff > pi) {
            diff -= 2 * pi;
          }
          while (diff < -pi) {
            diff += 2 * pi;
          }
          final maxTurn = p.homingStrength * dt;
          p.angle += diff.clamp(-maxTurn, maxTurn);
        }
      }

      final pSpeed = Projectile.speed * p.speedMultiplier;

      // Orbital projectiles: orbit their center before launching
      if (p.orbitCenter != null && p.orbitTime > 0) {
        p.orbitTime -= dt;
        p.orbitAngle += p.orbitSpeed * dt;
        p.orbitRadius += dt * 8.0; // slowly expand orbit
        p.position = Offset(
          p.orbitCenter!.dx + cos(p.orbitAngle) * p.orbitRadius,
          p.orbitCenter!.dy + sin(p.orbitAngle) * p.orbitRadius,
        );
        // When orbit time expires, launch outward
        if (p.orbitTime <= 0) {
          p.angle = p.orbitAngle; // launch in current orbital direction
          p.orbitCenter = null; // stop orbiting
        }
      } else if (p.stationary) {
        // Stationary projectiles don't move (mines, lingering clouds)
        // no position change
      } else {
        p.position = Offset(
          p.position.dx + cos(p.angle) * pSpeed * dt,
          p.position.dy + sin(p.angle) * pSpeed * dt,
        );
      }
      // Trail-dropping: spawn stationary residue projectiles periodically
      if (p.trailInterval > 0 && !p.stationary && p.orbitCenter == null) {
        p.trailTimer += dt;
        if (p.trailTimer >= p.trailInterval) {
          p.trailTimer -= p.trailInterval;
          companionProjectiles.add(
            Projectile(
              position: p.position,
              angle: 0,
              element: p.element,
              damage: p.trailDamage,
              life: p.trailLife,
              stationary: true,
              radiusMultiplier: 1.5,
              piercing: true,
              visualScale: 1.2,
            ),
          );
        }
      }

      // Cluster fragmentation: split into sub-projectiles at half-life
      if (p.clusterCount > 0 && !p.clustered) {
        // Estimate initial life by checking if we're past halfway
        // We trigger when remaining life < 50% of original
        // Since we don't store original life, trigger when life < 0.75s for meteors
        if (p.life < 0.75) {
          p.clustered = true;
          for (var ci = 0; ci < p.clusterCount; ci++) {
            final ca = ci * (pi * 2 / p.clusterCount);
            companionProjectiles.add(
              Projectile(
                position: Offset(
                  p.position.dx + cos(ca) * 10,
                  p.position.dy + sin(ca) * 10,
                ),
                angle: ca,
                element: p.element,
                damage: p.clusterDamage,
                life: 1.5,
                speedMultiplier: 0.7,
                radiusMultiplier: 1.5,
                piercing: true,
                visualScale: 1.0,
              ),
            );
          }
        }
      }

      p.life -= dt;
      if (p.life <= 0) {
        // If this is a decoy, spawn death explosion
        if (p.decoy && p.deathExplosionCount > 0) {
          _spawnDecoyExplosion(p);
        }
        companionProjectiles.removeAt(i);
        continue;
      }

      final hitRadius = Projectile.radius * p.radiusMultiplier;
      bool consumed = false;

      // Decoys/taunt traps resolve damage through the dedicated
      // enemy->decoy collision path so they persist as lures.
      if (p.decoy) {
        continue;
      }

      // Hit enemies
      for (var ei = enemies.length - 1; ei >= 0; ei--) {
        final enemy = enemies[ei];
        if (enemy.dead) continue;
        final edx = p.position.dx - enemy.position.dx;
        final edy = p.position.dy - enemy.position.dy;
        final hitR = enemy.radius + hitRadius;
        if (edx * edx + edy * edy < hitR * hitR) {
          // Piercing projectiles deal reduced damage after first hit
          final pierceFalloff = p.piercing
              ? pow(0.7, p.pierceCount).toDouble()
              : 1.0;
          enemy.health -= p.damage * pierceFalloff;
          _spawnHitSpark(p.position, elementColor(enemy.element));
          if (!enemy.provoked &&
              (enemy.behavior == EnemyBehavior.feeding ||
                  enemy.behavior == EnemyBehavior.territorial ||
                  enemy.behavior == EnemyBehavior.drifting)) {
            _provokePackOf(enemy);
          }
          if (p.piercing) {
            p.pierceCount++;
            // Don't consume — keep going
          } else if (p.bounceCount > 0) {
            // Ricochet: redirect toward nearest OTHER enemy
            p.bounceCount--;
            p.pierceCount++;
            double bestBounce = double.infinity;
            Offset? bounceTarget;
            for (final other in enemies) {
              if (other.dead || other == enemy) continue;
              final bd = (other.position - p.position).distance;
              if (bd < bestBounce && bd < 500) {
                bestBounce = bd;
                bounceTarget = other.position;
              }
            }
            if (bounceTarget != null) {
              p.angle = atan2(
                bounceTarget.dy - p.position.dy,
                bounceTarget.dx - p.position.dx,
              );
            } else {
              // No nearby target — bounce in a random direction
              p.angle += pi * 0.6 + Random().nextDouble() * pi * 0.8;
            }
            // Don't consume — keep going as a bounce
          } else {
            consumed = true;
          }
          if (enemy.health <= 0) {
            enemy.dead = true;
            _spawnKillVfx(
              enemy.position,
              elementColor(enemy.element),
              enemy.radius,
              false,
            );
            _spawnLootDrops(
              enemy.position,
              enemy.element,
              enemy.shardDrop,
              enemy.particleDrop,
            );
          }
          if (consumed) break;
        }
      }
      if (consumed) {
        companionProjectiles.removeAt(i);
        continue;
      }

      // Hit boss
      if (i < companionProjectiles.length && activeBoss != null) {
        final cp = companionProjectiles[i];
        final boss = activeBoss!;
        final bdx = cp.position.dx - boss.position.dx;
        final bdy = cp.position.dy - boss.position.dy;
        if (bdx * bdx + bdy * bdy <
            (boss.radius + hitRadius) * (boss.radius + hitRadius)) {
          final pierceFalloff = cp.piercing
              ? pow(0.7, cp.pierceCount).toDouble()
              : 1.0;
          if (boss.shieldUp && boss.type == BossType.gunner) {
            boss.shieldHealth -= cp.damage * pierceFalloff;
            _spawnHitSpark(cp.position, Colors.cyanAccent);
            if (boss.shieldHealth <= 0) {
              boss.shieldUp = false;
              boss.shieldTimer = CosmicBoss.shieldCooldown;
            }
          } else {
            boss.health -= cp.damage * pierceFalloff;
            _spawnHitSpark(cp.position, elementColor(boss.element));
            if (boss.health <= 0) {
              _handleBossKill(boss);
            }
          }
          if (cp.piercing) {
            cp.pierceCount++;
          } else {
            companionProjectiles.removeAt(i);
          }
        }
      }

      // Hit ring minions (when in a ring fight)
      if (i < companionProjectiles.length &&
          battleRing.inBattle &&
          ringMinions.isNotEmpty) {
        final cp = companionProjectiles[i];
        for (var ri = ringMinions.length - 1; ri >= 0; ri--) {
          final rm = ringMinions[ri];
          if (rm.dead) continue;
          final rdx = cp.position.dx - rm.position.dx;
          final rdy = cp.position.dy - rm.position.dy;
          final hitRadius = Projectile.radius * cp.radiusMultiplier;
          if (rdx * rdx + rdy * rdy <
              (rm.radius + hitRadius) * (rm.radius + hitRadius)) {
            final pierceFalloff = cp.piercing
                ? pow(0.7, cp.pierceCount).toDouble()
                : 1.0;
            final dmg = cp.damage * pierceFalloff;
            rm.health -= dmg;
            _spawnHitSpark(cp.position, elementColor(rm.element));
            if (cp.piercing) {
              cp.pierceCount++;
            } else {
              companionProjectiles.removeAt(i);
            }
            if (rm.health <= 0) {
              rm.dead = true;
              _spawnKillVfx(
                rm.position,
                elementColor(rm.element),
                rm.radius,
                false,
              );
            }
            break;
          }
        }
      }

      // Hit ring opponent
      if (i < companionProjectiles.length &&
          battleRingOpponent != null &&
          battleRingOpponent!.isAlive &&
          battleRing.inBattle) {
        final cp = companionProjectiles[i];
        final opp = battleRingOpponent!;
        final odx = cp.position.dx - opp.position.dx;
        final ody = cp.position.dy - opp.position.dy;
        if (odx * odx + ody * ody < (15 + hitRadius) * (15 + hitRadius)) {
          final pierceFalloff = cp.piercing
              ? pow(0.7, cp.pierceCount).toDouble()
              : 1.0;
          final dmg = max(
            1,
            (cp.damage * pierceFalloff * 100 / (100 + opp.elemDef)).round(),
          );
          opp.takeDamage(dmg);
          _spawnHitSpark(cp.position, elementColor(opp.member.element));
          if (cp.piercing) {
            cp.pierceCount++;
          } else {
            companionProjectiles.removeAt(i);
          }
        }
      }
    }

    // ── update garrison creatures (home-planet patrol & combat) ──
    if (homePlanet != null) {
      final hp = homePlanet!;
      final hpCenter = hp.position;
      // Patrol zone = beacon ring radius
      final patrolRadius = hp.visualRadius + 8.0;

      for (final g in _garrison) {
        g.ticker?.update(dt);
        g.attackCooldown = (g.attackCooldown - dt).clamp(0.0, 100.0);
        g.specialCooldown = (g.specialCooldown - dt).clamp(0.0, 100.0);

        // ── Horn charge: rush toward target, AoE on arrival ──
        if (g.chargeTimer > 0) {
          g.chargeTimer -= dt;
          if (g.chargeTarget != null) {
            final toTarget = g.chargeTarget! - g.position;
            final dist = toTarget.distance;
            if (dist > 10) {
              final step = 400.0 * dt;
              g.position += (toTarget / dist) * min(step, dist);
              g.faceAngle = atan2(toTarget.dy, toTarget.dx);
            } else {
              // AoE damage on arrival
              for (final e in enemies) {
                if (e.dead) continue;
                final d = (e.position - g.position).distance;
                if (d < 50) {
                  e.health -= g.chargeDamage;
                  _spawnHitSpark(e.position, elementColor(g.member.element));
                  if (!e.provoked) _provokePackOf(e);
                }
              }
              if (activeBoss != null) {
                final bd = (activeBoss!.position - g.position).distance;
                if (bd < 50) {
                  activeBoss!.health -= g.chargeDamage;
                  _spawnHitSpark(g.position, elementColor(g.member.element));
                }
              }
              g.chargeTimer = 0;
              g.chargeTarget = null;
            }
          }
          if (g.chargeTimer <= 0) g.chargeTarget = null;
        }

        // ── Kin blessing: heal over time ──
        if (g.blessingTimer > 0) {
          g.blessingTimer -= dt;
          g.hp = min(g.maxHp, g.hp + (g.blessingHealPerTick * dt).round());
        }

        // ── Find nearest enemy within engage range (basic or special) ──
        final engageRange = max(g.attackRange, g.specialRange);
        CosmicEnemy? nearestEnemy;
        double nearestDist = engageRange;
        for (final e in enemies) {
          if (e.dead) continue;
          final d = (e.position - g.position).distance;
          if (d < nearestDist) {
            nearestDist = d;
            nearestEnemy = e;
          }
        }
        // Also check boss
        if (activeBoss != null) {
          final bd = (activeBoss!.position - g.position).distance;
          if (bd < nearestDist) {
            nearestEnemy = null;
            nearestDist = bd;
          }
        }

        if (nearestEnemy != null ||
            (activeBoss != null && nearestDist < engageRange)) {
          // ── Chase & attack ──
          final targetPos = nearestEnemy?.position ?? activeBoss!.position;
          final toTarget = targetPos - g.position;
          g.faceAngle = atan2(toTarget.dy, toTarget.dx);

          // Move toward enemy only when outside special-cast range.
          if (toTarget.distance > g.specialRange) {
            final chaseSpeed = _GarrisonCreature.wanderSpeed * 3.5 * dt;
            g.position +=
                (toTarget / toTarget.distance) *
                min(chaseSpeed, toTarget.distance);
          }

          // Basic attack — family-specific pattern
          if (g.attackCooldown <= 0 && toTarget.distance <= g.attackRange) {
            g.attackCooldown = 1.2;
            final basics = createFamilyBasicAttack(
              origin: g.position,
              angle: g.faceAngle,
              element: g.member.element,
              family: g.member.family,
              damage: g.attackDamage,
            );
            companionProjectiles.addAll(basics);
          }

          // Special attack — family+element ability!
          if (g.specialCooldown <= 0 && toTarget.distance <= g.specialRange) {
            g.specialCooldown =
                (14.0 -
                        (g.member.statSpeed * 0.6) -
                        (g.member.statIntelligence * 0.4))
                    .clamp(6.0, 14.0);
            final result = createCosmicSpecialAbility(
              origin: g.position,
              baseAngle: g.faceAngle,
              family: g.member.family,
              element: g.member.element,
              damage: g.specialDamage,
              maxHp: g.maxHp,
              targetPos: targetPos,
            );
            companionProjectiles.addAll(result.projectiles);
            // Apply garrison state changes
            if (result.shieldHp > 0) g.shieldHp = result.shieldHp;
            if (result.chargeTimer > 0) {
              g.chargeTimer = result.chargeTimer;
              g.chargeDamage = result.chargeDamage;
              g.chargeTarget = targetPos;
            }
            if (result.selfHeal > 0) {
              g.hp = min(g.maxHp, g.hp + result.selfHeal);
            }
            if (result.blessingTimer > 0) {
              g.blessingTimer = result.blessingTimer;
              g.blessingHealPerTick = result.blessingHealPerTick;
            }
            _spawnHitSpark(g.position, elementColor(g.member.element));
          }
        } else {
          // ── No enemy — wander patrol ──
          g.faceAngle = g.wanderAngle;
          g.wanderAngle += (sin(_elapsed * 0.7 + g.position.dx) * 0.4) * dt;
          final wanderTarget = Offset(
            g.position.dx + cos(g.wanderAngle) * 40.0,
            g.position.dy + sin(g.wanderAngle) * 40.0,
          );
          final toW = wanderTarget - g.position;
          final wDist = toW.distance;
          if (wDist > 1.0) {
            final step = _GarrisonCreature.wanderSpeed * dt;
            g.position += (toW / wDist) * min(step, wDist);
          }
        }

        // Clamp within patrol zone (beacon ring) around home planet
        final fromCenter = g.position - hpCenter;
        if (fromCenter.distance > patrolRadius) {
          g.position =
              hpCenter + (fromCenter / fromCenter.distance) * patrolRadius;
        }
      }
    }

    // ── enemy spawning (random, scattered) — paused during battle ring ──
    if (!battleRing.inBattle) {
      _enemySpawnTimer += dt;
      if (_enemySpawnTimer >= _enemySpawnInterval &&
          enemies.length < _maxEnemies) {
        _enemySpawnTimer = 0;
        // ~70% chance each interval — enemies are common
        if (Random().nextDouble() < 0.7) {
          _spawnEnemy();
        }
      }

      // ── feeding pack spawn near asteroid belt ──
      _feedingPackTimer += dt;
      if (_feedingPackTimer >= _feedingPackInterval &&
          enemies.length < _maxEnemies - 2) {
        _feedingPackTimer = 0;
        // 40% chance — packs are moderately rare
        if (Random().nextDouble() < 0.4) {
          _spawnFeedingPack();
        }
      }
    } // end !battleRing.inBattle guard

    // ── enemy AI update ──
    for (var i = enemies.length - 1; i >= 0; i--) {
      final e = enemies[i];
      if (e.dead) {
        enemies.removeAt(i);
        continue;
      }
      _updateEnemyAI(e, dt);
    }

    // ── initial swarm clusters (seeded at first update) ──
    if (!_initialSwarmsSpawned) {
      _initialSwarmsSpawned = true;
      final swarmRng = Random(0x5A4E3D2C);
      // Spawn 6-8 swarm clusters scattered around the world
      final clusterCount = 6 + swarmRng.nextInt(3);
      for (int c = 0; c < clusterCount; c++) {
        final cx =
            2000.0 + swarmRng.nextDouble() * (world_.worldSize.width - 4000);
        final cy =
            2000.0 + swarmRng.nextDouble() * (world_.worldSize.height - 4000);
        _spawnSwarmCluster(center: Offset(cx, cy), rng: swarmRng);
      }
    }

    // ── periodic swarm cluster spawns ──
    _swarmSpawnTimer += dt;
    if (_swarmSpawnTimer >= _swarmSpawnInterval &&
        enemies.length < _maxEnemies) {
      _swarmSpawnTimer = 0;
      // 50% chance each interval — keeps the world populated
      if (Random().nextDouble() < 0.5) {
        _spawnSwarmCluster();
      }
    }

    // ── boss lair proximity check & respawn ──
    _updateBossLairs(dt);

    // ── random boss spawn (in addition to lairs) ──
    _bossSpawnTimer += dt;
    if (_bossSpawnTimer >= _bossSpawnInterval) {
      _bossSpawnTimer = 0;
      if (activeBoss == null && Random().nextDouble() < 0.25) {
        _spawnBoss();
      }
    }

    // ── boss AI update ──
    if (activeBoss != null) {
      if (activeBoss!.dead) {
        // Mark the lair as defeated
        for (final lair in bossLairs) {
          if (lair.state == BossLairState.fighting) {
            lair.state = BossLairState.defeated;
            lair.respawnTimer = BossLair.respawnDelay;
          }
        }
        activeBoss = null;
        bossProjectiles.clear(); // remove lingering projectiles
      } else {
        _updateBossAI(activeBoss!, dt);
      }
    }

    // ── boss projectile update ──
    _updateBossProjectiles(dt);

    // ── ship death / respawn ──
    if (_shipDead) {
      _respawnTimer -= dt;
      if (_respawnTimer <= 0) {
        _shipDead = false;
        shipHealth = shipMaxHealth;
        _shipInvincible = 3.0; // 3s invincibility on respawn
        // Clear nearby threats
        enemies.clear();
        activeBoss = null;
        bossProjectiles.clear();
        // Cancel any active whirl
        if (activeWhirl != null && activeWhirl!.state == WhirlState.active) {
          activeWhirl!.state = WhirlState.dormant;
          activeWhirl!.currentWave = 0;
          activeWhirl = null;
        }
        // Teleport home if home planet exists
        if (homePlanet != null) {
          final hp = homePlanet!;
          final hpR = hp.visualRadius;
          ship.pos = Offset(hp.position.dx + hpR + 60, hp.position.dy);
          _dragTarget = ship.pos;
          _revealAround(ship.pos, 300);
        }
      }
    }

    // ── ship invincibility cooldown ──
    if (_shipInvincible > 0) _shipInvincible -= dt;

    // ── enemy → decoy collision (enemies attack decoys) ──
    {
      final ww = world_.worldSize.width;
      final wh = world_.worldSize.height;
      for (final e in enemies) {
        if (e.dead) continue;
        // Passive enemies still engage if a taunt trap is actively luring them.
        if (!e.provoked &&
            (e.behavior == EnemyBehavior.feeding ||
                e.behavior == EnemyBehavior.drifting)) {
          var taunted = false;
          for (final cp in companionProjectiles) {
            if (!cp.decoy || cp.decoyHp <= 0 || cp.tauntRadius <= 0) continue;
            var tdx = cp.position.dx - e.position.dx;
            var tdy = cp.position.dy - e.position.dy;
            if (tdx > ww / 2) tdx -= ww;
            if (tdx < -ww / 2) tdx += ww;
            if (tdy > wh / 2) tdy -= wh;
            if (tdy < -wh / 2) tdy += wh;
            final dd = sqrt(tdx * tdx + tdy * tdy);
            if (dd <= cp.tauntRadius) {
              taunted = true;
              break;
            }
          }
          if (!taunted) continue;
        }
        for (var di = companionProjectiles.length - 1; di >= 0; di--) {
          final decoy = companionProjectiles[di];
          if (!decoy.decoy || decoy.decoyHp <= 0) continue;
          var ddx = decoy.position.dx - e.position.dx;
          var ddy = decoy.position.dy - e.position.dy;
          if (ddx > ww / 2) ddx -= ww;
          if (ddx < -ww / 2) ddx += ww;
          if (ddy > wh / 2) ddy -= wh;
          if (ddy < -wh / 2) ddy += wh;
          final hitR = e.radius + Projectile.radius * decoy.radiusMultiplier;
          if (ddx * ddx + ddy * ddy < hitR * hitR) {
            // Enemy damages the decoy
            final contactDmg = switch (e.tier) {
              EnemyTier.colossus => 5.0,
              EnemyTier.brute => 3.0,
              EnemyTier.phantom => 2.5,
              EnemyTier.sentinel => 2.0,
              EnemyTier.drone => 1.5,
              EnemyTier.wisp => 1.0,
            };
            decoy.decoyHp -= contactDmg;
            // Enemy takes damage from bumping into it
            e.health -= decoy.damage * 0.3;
            _spawnHitSpark(
              decoy.position,
              elementColor(decoy.element ?? 'Fire'),
            );
            if (e.health <= 0) {
              e.dead = true;
              _spawnKillVfx(
                e.position,
                elementColor(e.element),
                e.radius,
                false,
              );
              _spawnLootDrops(
                e.position,
                e.element,
                e.shardDrop,
                e.particleDrop,
              );
            }
            // Check if decoy died from this hit
            if (decoy.decoyHp <= 0) {
              _spawnDecoyExplosion(decoy);
              companionProjectiles.removeAt(di);
            }
            break; // one enemy hits one decoy per frame
          }
        }
      }
    }

    // ── enemy → ship collision (contact damage) ──
    if (!_shipDead && _shipInvincible <= 0) {
      for (final e in enemies) {
        if (e.dead) continue;
        // Passive enemies (feeding/drifting that aren't provoked) don't damage
        if (!e.provoked &&
            (e.behavior == EnemyBehavior.feeding ||
                e.behavior == EnemyBehavior.drifting)) {
          continue;
        }
        // Stalkers only attack when ship HP is low
        if (e.behavior == EnemyBehavior.stalking && shipHealth > 2.0) {
          continue;
        }
        final ww = world_.worldSize.width;
        final wh = world_.worldSize.height;
        var edx = ship.pos.dx - e.position.dx;
        var edy = ship.pos.dy - e.position.dy;
        if (edx > ww / 2) edx -= ww;
        if (edx < -ww / 2) edx += ww;
        if (edy > wh / 2) edy -= wh;
        if (edy < -wh / 2) edy += wh;
        final hitR = e.radius + 14; // ship collision radius ~14
        if (edx * edx + edy * edy < hitR * hitR) {
          final contactDmg = switch (e.tier) {
            EnemyTier.colossus => 4.0,
            EnemyTier.brute => 2.5,
            EnemyTier.phantom => 2.0,
            EnemyTier.sentinel => 1.5,
            EnemyTier.drone => 1.0,
            EnemyTier.wisp => 0.5,
          };
          _damageShip(contactDmg);
          e.dead = true;
          _spawnKillVfx(e.position, elementColor(e.element), e.radius, false);
          break; // only one hit per frame
        }
      }
    }

    // ── boss → ship collision ──
    if (!_shipDead &&
        _shipInvincible <= 0 &&
        activeBoss != null &&
        !activeBoss!.dead) {
      final boss = activeBoss!;
      final ww = world_.worldSize.width;
      final wh = world_.worldSize.height;
      var bdx = ship.pos.dx - boss.position.dx;
      var bdy = ship.pos.dy - boss.position.dy;
      if (bdx > ww / 2) bdx -= ww;
      if (bdx < -ww / 2) bdx += ww;
      if (bdy > wh / 2) bdy -= wh;
      if (bdy < -wh / 2) bdy += wh;
      final bHitR = boss.radius + 14;
      if (bdx * bdx + bdy * bdy < bHitR * bHitR) {
        _damageShip(2.0);
      }
    }

    // ── orbital gravity between home planet and nearby cosmic planet ──
    if (homePlanet != null && _orbitalPartner != null) {
      _orbitAngle += _orbitSpeed * dt;
      if (_homeOrbitsPartner) {
        // Home planet orbits the larger cosmic planet
        final oldHP = homePlanet!.position;
        final center = _orbitalPartner!.position;
        homePlanet!.position = _wrap(
          Offset(
            center.dx + cos(_orbitAngle) * _orbitRadius,
            center.dy + sin(_orbitAngle) * _orbitRadius,
          ),
        );
        // Shift orbital chambers by the same delta so they rigidly
        // follow the home planet's orbital motion instead of lagging.
        final hpDelta = homePlanet!.position - oldHP;
        for (final c in orbitalChambers) {
          c.position = _wrap(c.position + hpDelta);
        }
      } else {
        // Cosmic planet orbits the larger home planet
        final center = homePlanet!.position;
        _orbitalPartner!.position = _wrap(
          Offset(
            center.dx + cos(_orbitAngle) * _orbitRadius,
            center.dy + sin(_orbitAngle) * _orbitRadius,
          ),
        );
      }
    }

    // ── orbital chambers physics ──
    if (homePlanet != null && orbitalChambers.isNotEmpty) {
      final hpCentre = homePlanet!.position;
      for (final c in orbitalChambers) {
        c.update(dt, hpCentre);
        // Wrap to toroidal world
        c.position = _wrap(c.position);
      }
      // Chamber-chamber elastic collision
      for (var i = 0; i < orbitalChambers.length; i++) {
        for (var j = i + 1; j < orbitalChambers.length; j++) {
          final a = orbitalChambers[i];
          final b = orbitalChambers[j];
          final delta = b.position - a.position;
          final dist = delta.distance;
          final minDist = a.radius + b.radius;
          if (dist > 0 && dist < minDist) {
            final n = delta / dist;
            final push = (minDist - dist) * 0.6;
            a.position -= n * push * 0.5;
            b.position += n * push * 0.5;
            // Exchange velocity along normal
            final va = a.velocity.dx * n.dx + a.velocity.dy * n.dy;
            final vb = b.velocity.dx * n.dx + b.velocity.dy * n.dy;
            final impulse = (vb - va) * 0.75;
            a.velocity += n * impulse;
            b.velocity -= n * impulse;
            _spawnHitSpark(
              (a.position + b.position) / 2.0,
              Color.lerp(a.color, b.color, 0.5)!,
            );
          }
        }
      }
      // Chamber-ship collision (bounce off each other)
      if (!_shipDead) {
        for (final c in orbitalChambers) {
          final delta = ship.pos - c.position;
          final dist = delta.distance;
          final minDist = c.radius + 14.0; // ship radius ~14
          if (dist > 0 && dist < minDist) {
            final n = delta / dist;
            final push = (minDist - dist) * 0.6;
            c.position -= n * push;
            c.velocity -= n * 60.0; // gentle bounce away
            c.knocked = true;
            c.knockTimer = 0.5;
          }
        }
      }
    }

    // ── update VFX particles & rings ──
    for (var i = vfxParticles.length - 1; i >= 0; i--) {
      vfxParticles[i].update(dt);
      if (vfxParticles[i].dead) vfxParticles.removeAt(i);
    }
    for (var i = vfxRings.length - 1; i >= 0; i--) {
      vfxRings[i].update(dt);
      if (vfxRings[i].dead) vfxRings.removeAt(i);
    }

    // ── rift portal proximity ──
    _riftPulse += dt;
    {
      final ww = world_.worldSize.width;
      final wh = world_.worldSize.height;
      RiftPortal? closest;
      double closestDist = double.infinity;
      for (final rift in world_.riftPortals) {
        var rdx = rift.position.dx - ship.pos.dx;
        var rdy = rift.position.dy - ship.pos.dy;
        if (rdx > ww / 2) rdx -= ww;
        if (rdx < -ww / 2) rdx += ww;
        if (rdy > wh / 2) rdy -= wh;
        if (rdy < -wh / 2) rdy += wh;
        final d2 = rdx * rdx + rdy * rdy;
        final threshold = _wasNearRift
            ? RiftPortal.exitRadius
            : RiftPortal.interactRadius;
        if (d2 < threshold * threshold && d2 < closestDist) {
          closestDist = d2;
          closest = rift;
        }
      }
      _nearestRift = closest;
      final nowNear = closest != null;
      if (nowNear != _wasNearRift) {
        _wasNearRift = nowNear;
        onNearRift?.call(nowNear);
      }
    }

    // ── elemental nexus proximity ──
    {
      final nx = elementalNexus;
      var ndx = nx.position.dx - ship.pos.dx;
      var ndy = nx.position.dy - ship.pos.dy;
      if (ndx > ww / 2) ndx -= ww;
      if (ndx < -ww / 2) ndx += ww;
      if (ndy > wh / 2) ndy -= wh;
      if (ndy < -wh / 2) ndy += wh;
      final nd = sqrt(ndx * ndx + ndy * ndy);
      final threshold = _wasNearNexus
          ? ElementalNexus.exitRadius
          : ElementalNexus.interactRadius;
      final nowNearNexus = nd < threshold;
      if (nowNearNexus != _wasNearNexus) {
        _wasNearNexus = nowNearNexus;
        _isNearNexus = nowNearNexus;
        onNearNexus?.call(nowNearNexus);
      }
      // Discover on approach
      if (!nx.discovered && nd < ElementalNexus.interactRadius + 300) {
        nx.discovered = true;
      }
    }

    // ── battle ring proximity ──
    {
      final br = battleRing;
      var bdx = br.position.dx - ship.pos.dx;
      var bdy = br.position.dy - ship.pos.dy;
      if (bdx > ww / 2) bdx -= ww;
      if (bdx < -ww / 2) bdx += ww;
      if (bdy > wh / 2) bdy -= wh;
      if (bdy < -wh / 2) bdy += wh;
      final bd = sqrt(bdx * bdx + bdy * bdy);
      final threshold = _wasNearBattleRing
          ? BattleRing.exitRadius
          : BattleRing.interactRadius;
      final nowNearBR = bd < threshold;
      if (nowNearBR != _wasNearBattleRing) {
        _wasNearBattleRing = nowNearBR;
        _isNearBattleRing = nowNearBR;
        onNearBattleRing?.call(nowNearBR);
      }
      // Discover on approach
      if (!br.discovered && bd < BattleRing.interactRadius + 300) {
        br.discovered = true;
      }
    }

    // ── blood ring proximity ──
    {
      final ring = bloodRing;
      var bdx = ring.position.dx - ship.pos.dx;
      var bdy = ring.position.dy - ship.pos.dy;
      if (bdx > ww / 2) bdx -= ww;
      if (bdx < -ww / 2) bdx += ww;
      if (bdy > wh / 2) bdy -= wh;
      if (bdy < -wh / 2) bdy += wh;
      final bd = sqrt(bdx * bdx + bdy * bdy);
      final threshold = _wasNearBloodRing
          ? BloodRing.exitRadius
          : BloodRing.interactRadius;
      final nowNear = bd < threshold;
      if (nowNear != _wasNearBloodRing) {
        _wasNearBloodRing = nowNear;
        _isNearBloodRing = nowNear;
        onNearBloodRing?.call(nowNear);
      }
      if (!ring.discovered && bd < BloodRing.interactRadius + 300) {
        ring.discovered = true;
      }
    }

    // ── trait contest arena proximity ──
    {
      CosmicContestArena? closest;
      double closestDist = double.infinity;
      for (final arena in contestArenas) {
        var adx = arena.position.dx - ship.pos.dx;
        var ady = arena.position.dy - ship.pos.dy;
        if (adx > ww / 2) adx -= ww;
        if (adx < -ww / 2) adx += ww;
        if (ady > wh / 2) ady -= wh;
        if (ady < -wh / 2) ady += wh;
        final ad = sqrt(adx * adx + ady * ady);

        if (!arena.discovered && ad < CosmicContestArena.interactRadius + 320) {
          arena.discovered = true;
        }

        final threshold = nearContestArena == arena
            ? CosmicContestArena.exitRadius
            : CosmicContestArena.interactRadius;
        if (ad < threshold && ad < closestDist) {
          closestDist = ad;
          closest = arena;
        }
      }
      if (closest != nearContestArena) {
        nearContestArena = closest;
        onNearContestArena?.call(closest);
      }
    }

    // ── collectible contest hint notes ──
    for (final note in contestHintNotes) {
      if (note.collected) continue;
      var hdx = note.position.dx - ship.pos.dx;
      var hdy = note.position.dy - ship.pos.dy;
      if (hdx > ww / 2) hdx -= ww;
      if (hdx < -ww / 2) hdx += ww;
      if (hdy > wh / 2) hdy -= wh;
      if (hdy < -wh / 2) hdy += wh;
      final hd = sqrt(hdx * hdx + hdy * hdy);
      if (hd < CosmicContestHintNote.interactRadius) {
        note.collected = true;
        onContestHintCollected?.call(note);
      }
    }

    // ── galaxy whirl update ──
    for (final whirl in galaxyWhirls) {
      whirl.rotation += dt * 0.8;
      whirl.pulse += dt;
      if (whirl.state == WhirlState.completed) continue;

      // Check activation
      if (whirl.state == WhirlState.dormant && activeWhirl == null) {
        var wdx = whirl.position.dx - ship.pos.dx;
        var wdy = whirl.position.dy - ship.pos.dy;
        if (wdx > ww / 2) wdx -= ww;
        if (wdx < -ww / 2) wdx += ww;
        if (wdy > wh / 2) wdy -= wh;
        if (wdy < -wh / 2) wdy += wh;
        final wDist = sqrt(wdx * wdx + wdy * wdy);
        if (wDist < GalaxyWhirl.activationRadius) {
          whirl.state = WhirlState.active;
          whirl.currentWave = 0;
          whirl.enemiesSpawnedInWave = 0;
          whirl.enemiesAlive = 0;
          whirl.waveTimer = whirl.timeForWave(0);
          activeWhirl = whirl;
          onWhirlActivated?.call(whirl);
        }
      }
    }

    // Update active whirl
    if (activeWhirl != null && activeWhirl!.state == WhirlState.active) {
      final aw = activeWhirl!;
      final whirlIdx = galaxyWhirls.indexOf(aw);

      // Count living whirl enemies
      aw.enemiesAlive = enemies
          .where((e) => !e.dead && e.whirlIndex == whirlIdx)
          .length;

      // Spawn enemies for current wave
      final totalForWave = aw.enemiesForWave(aw.currentWave);
      if (aw.enemiesSpawnedInWave < totalForWave) {
        aw.spawnTimer += dt;
        if (aw.spawnTimer >= aw.waveSpawnInterval) {
          aw.spawnTimer = 0;
          _spawnWhirlEnemy(aw, whirlIdx);
          aw.enemiesSpawnedInWave++;
        }
      }

      // Count down wave timer
      aw.waveTimer -= dt;

      // Wave complete: all spawned and killed, OR timer ran out
      if ((aw.enemiesSpawnedInWave >= totalForWave && aw.enemiesAlive <= 0) ||
          aw.waveTimer <= 0) {
        onWhirlWaveComplete?.call(aw, aw.currentWave);
        aw.currentWave++;

        if (aw.currentWave >= aw.totalWaves) {
          // All waves complete — reward!
          aw.state = WhirlState.completed;
          activeWhirl = null;
          _spawnLootDrops(
            aw.position,
            aw.element,
            aw.shardReward,
            aw.particleReward,
          );
          // Item drops based on horde level
          _spawnWhirlItemDrops(aw);
          onWhirlComplete?.call(aw);
        } else {
          // Next wave
          aw.enemiesSpawnedInWave = 0;
          aw.waveTimer = aw.timeForWave(aw.currentWave);
          aw.spawnTimer = 0;
        }
      }
    }

    // ── prismatic field update ──
    prismaticField.life += dt;

    // Discover prismatic field when ship gets close
    if (!prismaticField.discovered) {
      final pfDist = (prismaticField.position - ship.pos).distance;
      if (pfDist < prismaticField.radius + 200) {
        prismaticField.discovered = true;
      }
    }

    // Check for prismatic celebration animation in progress
    if (_prismaticCelebTimer >= 0) {
      _prismaticCelebTimer += dt;
      final comp = activeCompanion;
      if (comp != null && _prismaticCelebCenter != null) {
        // Override companion movement: rapid orbit around the center
        final orbitProgress = (_prismaticCelebTimer / _prismaticCelebDuration)
            .clamp(0.0, 1.0);
        final orbitAngle = orbitProgress * pi * 6; // 3 full circles
        final orbitRadius = 80.0;
        comp.position = Offset(
          _prismaticCelebCenter!.dx + cos(orbitAngle) * orbitRadius,
          _prismaticCelebCenter!.dy + sin(orbitAngle) * orbitRadius,
        );
        comp.angle = orbitAngle + pi / 2; // face tangent direction
        comp.anchorPosition = comp.position; // prevent auto-return
        comp.invincibleTimer = 0.5; // keep invincible during celebration

        // Sparkle trail VFX along the orbit
        if (_rng.nextDouble() < 0.6) {
          final trailColor = PrismaticField
              .auroraColors[_rng.nextInt(PrismaticField.auroraColors.length)];
          vfxParticles.add(
            VfxParticle(
              x: comp.position.dx + (_rng.nextDouble() - 0.5) * 10,
              y: comp.position.dy + (_rng.nextDouble() - 0.5) * 10,
              vx: (_rng.nextDouble() - 0.5) * 40,
              vy: (_rng.nextDouble() - 0.5) * 40,
              life: 0.8,
              color: trailColor,
              size: 3 + _rng.nextDouble() * 3,
            ),
          );
        }
      }

      // Celebration complete — award 50 gold
      if (_prismaticCelebTimer >= _prismaticCelebDuration) {
        _prismaticCelebTimer = -1;
        prismaticRewardClaimed = true;
        prismaticField.rewardClaimed = true;

        final center = _prismaticCelebCenter ?? prismaticField.position;

        // Big VFX burst (gold-colored)
        for (int i = 0; i < 30; i++) {
          final a = _rng.nextDouble() * pi * 2;
          final s = 60 + _rng.nextDouble() * 120;
          vfxParticles.add(
            VfxParticle(
              x: center.dx,
              y: center.dy,
              vx: cos(a) * s,
              vy: sin(a) * s,
              life: 1.2,
              color: const Color(0xFFFFD700),
              size: 4 + _rng.nextDouble() * 5,
            ),
          );
        }
        vfxRings.add(
          VfxShockRing(
            x: center.dx,
            y: center.dy,
            maxRadius: 200,
            color: const Color(0xFFFFDD00),
          ),
        );

        _prismaticCelebCenter = null;
        onPrismaticRewardClaimed?.call();
      }
    }

    // Trigger celebration if prismatic companion enters the central ring
    if (!prismaticRewardClaimed &&
        _prismaticCelebTimer < 0 &&
        activeCompanion != null &&
        _companionVisuals?.isPrismatic == true) {
      final comp = activeCompanion!;
      final dist = (comp.position - prismaticField.position).distance;
      final ringR = prismaticField.radius * 0.12;
      if (dist < ringR + 30) {
        // Start celebration at the centre!
        _prismaticCelebTimer = 0;
        _prismaticCelebCenter = prismaticField.position;
      }
    }

    // ── space POI update ──
    for (final poi in spacePOIs) {
      poi.life += dt;

      // Hidden meteor-shower zone: encounter in-world, then relocate far away.
      if (poi.type == POIType.comet) {
        var cdx = poi.position.dx - ship.pos.dx;
        var cdy = poi.position.dy - ship.pos.dy;
        if (cdx > ww / 2) cdx -= ww;
        if (cdx < -ww / 2) cdx += ww;
        if (cdy > wh / 2) cdy -= wh;
        if (cdy < -wh / 2) cdy += wh;
        final cometDist = sqrt(cdx * cdx + cdy * cdy);

        if (!poi.discovered && cometDist < poi.radius + 300) {
          poi.discovered = true;
        }

        const encounterDuration = 10.0;
        const pulseEvery = 1.25;
        final insideShower = cometDist < poi.radius * 0.95;

        // Entering the shower starts a timed encounter (instead of instant relocate).
        if (insideShower && !poi.interacted) {
          poi.interacted = true;
          poi.speed = 0; // re-used as elapsed encounter time
          onPOIDiscovered?.call(poi);
          _spawnLootDrops(ship.pos, poi.element, 5, 5.5);
        }

        if (insideShower && poi.interacted) {
          final prevElapsed = poi.speed;
          final prevPulse = (prevElapsed / pulseEvery).floor();
          poi.speed += dt;
          final nextPulse = (poi.speed / pulseEvery).floor();

          if (nextPulse > prevPulse) {
            final burstRng = Random(
              nextPulse * 911 + poi.position.dx.toInt() ^
                  poi.position.dy.toInt(),
            );
            final a = burstRng.nextDouble() * 2 * pi;
            final r = poi.radius * (0.2 + burstRng.nextDouble() * 0.65);
            final burstPos = _wrap(
              Offset(
                poi.position.dx + cos(a) * r,
                poi.position.dy + sin(a) * r,
              ),
            );
            _spawnLootDrops(burstPos, poi.element, 4, 6.0);
          }

          if (prevElapsed < encounterDuration &&
              poi.speed >= encounterDuration) {
            _spawnLootDrops(ship.pos, poi.element, 10, 6.5);
          }
        }

        // Only relocate once the encounter has completed and the player leaves.
        if (poi.interacted &&
            !insideShower &&
            poi.speed >= encounterDuration &&
            cometDist > poi.radius * 1.2) {
          _relocateMeteorShower(poi);
        }
        continue;
      }

      if (poi.interacted) continue;

      // Markets use proximity detection (nearMarket), not one-shot interaction
      if (poi.type == POIType.harvesterMarket ||
          poi.type == POIType.riftKeyMarket ||
          poi.type == POIType.cosmicMarket ||
          poi.type == POIType.stardustScanner) {
        continue;
      }

      // Proximity check
      var pdx2 = poi.position.dx - ship.pos.dx;
      var pdy2 = poi.position.dy - ship.pos.dy;
      if (pdx2 > ww / 2) pdx2 -= ww;
      if (pdx2 < -ww / 2) pdx2 += ww;
      if (pdy2 > wh / 2) pdy2 -= wh;
      if (pdy2 < -wh / 2) pdy2 += wh;
      final poiDist = sqrt(pdx2 * pdx2 + pdy2 * pdy2);

      if (!poi.discovered && poiDist < poi.radius + 200) {
        poi.discovered = true;
      }

      // Interaction check (ship must be close)
      if (poiDist < poi.radius * 0.8) {
        poi.interacted = true;
        onPOIDiscovered?.call(poi);

        switch (poi.type) {
          case POIType.nebula:
            if (!meter.isFull) {
              meter.add(poi.element, 8.0 * _meterPickupMultiplier);
              onMeterChanged();
            }
            break;
          case POIType.derelict:
            _spawnLootDrops(poi.position, poi.element, 8, 3.0);
            break;
          case POIType.comet:
            // Handled above as meteor-shower zone.
            break;
          case POIType.harvesterMarket:
          case POIType.riftKeyMarket:
          case POIType.cosmicMarket:
          case POIType.stardustScanner:
            // Markets are handled via nearMarket proximity, not one-shot.
            break;
          case POIType.warpAnomaly:
            final warpRng = Random();
            final newPos = Offset(
              2000 + warpRng.nextDouble() * (world_.worldSize.width - 4000),
              2000 + warpRng.nextDouble() * (world_.worldSize.height - 4000),
            );
            // Trigger warp flash animation
            _warpFlash = 1.0;
            ship.pos = newPos;
            _dragTarget = newPos;
            _revealAround(ship.pos, 300);
            break;
        }
      }
    }

    // ── periodic save ──
    onPeriodicSave?.call();
  }

  // ── render ─────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Pocket dimension takes over all rendering
    if (inNexusPocket) {
      _renderPocket(canvas);
      return;
    }

    final cx = camX;
    final cy = camY;
    final screenW = size.x;
    final screenH = size.y;

    canvas.save();
    canvas.translate(-cx, -cy);

    // ── background stars (spatial grid lookup) ──
    final starPaint = Paint();
    final minCX = ((cx / _starChunkSize).floor() - 1).clamp(0, _starGridW - 1);
    final maxCX = (((cx + screenW) / _starChunkSize).floor() + 1).clamp(
      0,
      _starGridW - 1,
    );
    final minCY = ((cy / _starChunkSize).floor() - 1).clamp(0, _starGridH - 1);
    final maxCY = (((cy + screenH) / _starChunkSize).floor() + 1).clamp(
      0,
      _starGridH - 1,
    );
    for (var gy = minCY; gy <= maxCY; gy++) {
      for (var gx = minCX; gx <= maxCX; gx++) {
        for (final star in _starGrid[gy * _starGridW + gx]) {
          final twinkle =
              0.5 + 0.5 * sin(_elapsed * star.twinkleSpeed + star.x * 0.01);
          starPaint.color = Colors.white.withValues(
            alpha: star.brightness * twinkle,
          );
          canvas.drawCircle(Offset(star.x, star.y), star.size, starPaint);
        }
      }
    }

    // ── element particles ──
    for (final p in elemParticles) {
      if (p.x < cx - 20 ||
          p.x > cx + screenW + 20 ||
          p.y < cy - 20 ||
          p.y > cy + screenH + 20) {
        continue;
      }

      final alpha = (p.life / 5.0).clamp(0.0, 1.0);
      final color = elementColor(p.element).withValues(alpha: alpha * 0.9);
      final glow = elementColor(p.element).withValues(alpha: alpha * 0.3);

      canvas.drawCircle(Offset(p.x, p.y), p.size + 3, Paint()..color = glow);
      canvas.drawCircle(Offset(p.x, p.y), p.size, Paint()..color = color);
    }

    if (_beautyContestCinematicActive) {
      final introFade = _beautyContestIntroActive
          ? Curves.easeOutCubic.transform(
              (_beautyContestIntroTimer / _beautyContestIntroDuration).clamp(
                0.0,
                1.0,
              ),
            )
          : 1.0;
      final center = _beautyContestCenter;
      if (_contestCinematicMode == _ContestCinematicMode.beauty) {
        final pulse = 0.5 + 0.5 * sin(_elapsed * 1.8);
        final haloR = 300.0 + 24.0 * sin(_elapsed * 0.9);
        final sweepR = 212.0 + 12.0 * sin(_elapsed * 1.6);

        canvas.drawCircle(
          center,
          haloR,
          Paint()
            ..color = const Color(
              0xFFF06292,
            ).withValues(alpha: (0.18 + pulse * 0.10) * introFade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
        );
        canvas.drawCircle(
          center,
          220,
          Paint()
            ..color = const Color(
              0xFF80DEEA,
            ).withValues(alpha: 0.14 * introFade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38),
        );
        canvas.drawCircle(
          center,
          170,
          Paint()
            ..shader = ui.Gradient.radial(center, 170, [
              const Color(
                0xFFFFF8E1,
              ).withValues(alpha: (0.16 + pulse * 0.06) * introFade),
              Colors.transparent,
            ]),
        );
        for (var i = 0; i < 10; i++) {
          final a = _elapsed * 0.26 + i * (pi * 2 / 10);
          final p = Offset(
            center.dx + cos(a) * sweepR,
            center.dy + sin(a) * sweepR * 0.58,
          );
          canvas.drawCircle(
            p,
            7.0 + 1.2 * sin(_elapsed * 2.2 + i),
            Paint()
              ..color = const Color(
                0xFFFFE082,
              ).withValues(alpha: 0.24 * introFade)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
          );
        }
      } else if (_contestCinematicMode == _ContestCinematicMode.speed) {
        final pulse = 0.5 + 0.5 * sin(_elapsed * 2.2);
        const outerRx = 246.0;
        const outerRy = 138.0;
        const innerRx = 208.0;
        const innerRy = 114.0;
        final outerRect = Rect.fromCenter(
          center: center,
          width: outerRx * 2,
          height: outerRy * 2,
        );
        final innerRect = Rect.fromCenter(
          center: center,
          width: innerRx * 2,
          height: innerRy * 2,
        );

        canvas.drawOval(
          outerRect,
          Paint()
            ..color = const Color(
              0xFF4FC3F7,
            ).withValues(alpha: (0.26 + pulse * 0.10) * introFade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        canvas.drawOval(
          innerRect,
          Paint()
            ..color = const Color(
              0xFFB3E5FC,
            ).withValues(alpha: (0.20 + pulse * 0.08) * introFade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        for (var i = 0; i < 16; i++) {
          final a = _elapsed * 2.8 + i * (pi * 2 / 16);
          final p = Offset(
            center.dx + cos(a) * (innerRx + 8),
            center.dy + sin(a) * (innerRy + 6),
          );
          canvas.drawCircle(
            p,
            2.6,
            Paint()
              ..color = const Color(
                0xFFE1F5FE,
              ).withValues(alpha: (0.16 + pulse * 0.08) * introFade),
          );
        }
      } else if (_contestCinematicMode == _ContestCinematicMode.strength) {
        final pulse = 0.5 + 0.5 * sin(_elapsed * 3.0);
        const laneHalfExtent = 118.0;
        final clashCenterBase = Offset(center.dx, center.dy + 24);
        final clashCenter = Offset(
          center.dx + _strengthContestShift,
          center.dy + 24,
        );
        final shiftNorm = (_strengthContestShift / laneHalfExtent).clamp(
          -1.0,
          1.0,
        );
        final markerColor = Color.lerp(
          const Color(0xFFFFAB91),
          const Color(0xFFFFCC80),
          ((shiftNorm + 1) / 2).clamp(0.0, 1.0),
        )!;
        final laneLeft = Offset(
          clashCenterBase.dx - laneHalfExtent,
          clashCenterBase.dy,
        );
        final laneRight = Offset(
          clashCenterBase.dx + laneHalfExtent,
          clashCenterBase.dy,
        );
        var markerPos = clashCenter;
        if (_beautyContestTimer >= _strengthContestDuration) {
          final revealT = Curves.easeOutCubic.transform(
            ((_beautyContestTimer - _strengthContestDuration) / 1.0).clamp(
              0.0,
              1.0,
            ),
          );
          final winner = _beautyContestPlayerWon
              ? activeCompanion
              : battleRingOpponent;
          if (winner != null) {
            markerPos = Offset.lerp(clashCenter, winner.position, revealT)!;
          }
        }

        // Strength lane + neutral alchemical center marker.
        canvas.drawLine(
          laneLeft,
          laneRight,
          Paint()
            ..color = const Color(
              0xFFFFE0B2,
            ).withValues(alpha: 0.08 * introFade)
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawLine(
          laneLeft,
          laneRight,
          Paint()
            ..color = const Color(
              0xFFFFE0B2,
            ).withValues(alpha: 0.16 * introFade)
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round,
        );
        for (var i = 0; i < 8; i++) {
          final travel = (_elapsed * 0.24 + i / 8) % 1.0;
          final laneX = laneLeft.dx + (laneRight.dx - laneLeft.dx) * travel;
          final laneY = clashCenterBase.dy + sin(_elapsed * 2.8 + i) * 1.5;
          canvas.drawCircle(
            Offset(laneX, laneY),
            1.8 + (i % 2) * 0.5,
            Paint()
              ..color = const Color(
                0xFFFFF3E0,
              ).withValues(alpha: (0.10 + pulse * 0.06) * introFade)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }
        canvas.drawCircle(
          clashCenterBase,
          16,
          Paint()
            ..color = const Color(
              0xFFFFF3E0,
            ).withValues(alpha: 0.24 * introFade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        final hexPath = Path();
        for (var i = 0; i < 6; i++) {
          final a = -pi / 2 + i * (pi * 2 / 6);
          final pt = Offset(
            clashCenterBase.dx + cos(a) * 8,
            clashCenterBase.dy + sin(a) * 8,
          );
          if (i == 0) {
            hexPath.moveTo(pt.dx, pt.dy);
          } else {
            hexPath.lineTo(pt.dx, pt.dy);
          }
        }
        hexPath.close();
        canvas.drawPath(
          hexPath,
          Paint()
            ..color = const Color(
              0xFFFFE0B2,
            ).withValues(alpha: 0.36 * introFade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );

        canvas.drawCircle(
          clashCenter,
          170,
          Paint()
            ..color = const Color(
              0xFFFFA65A,
            ).withValues(alpha: (0.13 + pulse * 0.08) * introFade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
        );
        canvas.drawCircle(
          clashCenter,
          108,
          Paint()
            ..color = const Color(
              0xFFFFE0B2,
            ).withValues(alpha: (0.08 + pulse * 0.06) * introFade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
        for (var i = 0; i < 12; i++) {
          final a = _elapsed * 2.4 + i * (pi * 2 / 12);
          final p = Offset(
            clashCenter.dx + cos(a) * 116,
            clashCenter.dy + sin(a) * 62,
          );
          canvas.drawCircle(
            p,
            4.0 + (i % 3) * 0.8,
            Paint()
              ..color = const Color(
                0xFFFFCC80,
              ).withValues(alpha: (0.15 + pulse * 0.06) * introFade),
          );
        }

        // Moving alchemical force marker tracks control of the center.
        canvas.drawCircle(
          markerPos,
          20,
          Paint()
            ..color = markerColor.withValues(
              alpha: (0.15 + pulse * 0.12) * introFade,
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        canvas.drawCircle(
          markerPos,
          10.5,
          Paint()..color = markerColor.withValues(alpha: 0.92 * introFade),
        );
        canvas.drawCircle(
          markerPos,
          4,
          Paint()
            ..color = const Color(
              0xFFFFFFFF,
            ).withValues(alpha: 0.92 * introFade),
        );
      } else if (_contestCinematicMode == _ContestCinematicMode.intelligence) {
        final pulse = 0.5 + 0.5 * sin(_elapsed * 2.6);
        final latticeCenter = Offset(center.dx, center.dy + 16);
        final orbPos = _intelligenceContestOrbPos;
        final biasNorm = ((_intelligenceContestBias + 1.0) * 0.5).clamp(
          0.0,
          1.0,
        );
        final orbColor = Color.lerp(
          const Color(0xFF9FA8DA),
          const Color(0xFFD1C4E9),
          biasNorm,
        )!;

        canvas.drawCircle(
          latticeCenter,
          240,
          Paint()
            ..color = const Color(
              0xFF7E57C2,
            ).withValues(alpha: (0.14 + pulse * 0.07) * introFade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 46),
        );
        canvas.drawCircle(
          latticeCenter,
          146,
          Paint()
            ..color = const Color(
              0xFFB3E5FC,
            ).withValues(alpha: (0.08 + pulse * 0.04) * introFade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
        );

        for (var i = 0; i < 3; i++) {
          final radius = 62.0 + i * 44.0;
          canvas.drawCircle(
            latticeCenter,
            radius,
            Paint()
              ..color = const Color(
                0xFFD1C4E9,
              ).withValues(alpha: (0.09 - i * 0.02) * introFade)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }

        final nodePoints = <Offset>[];
        for (var i = 0; i < 10; i++) {
          final a = _elapsed * 0.78 + i * (pi * 2 / 10);
          final p = Offset(
            latticeCenter.dx + cos(a) * 168.0,
            latticeCenter.dy + sin(a) * 92.0,
          );
          nodePoints.add(p);
          canvas.drawCircle(
            p,
            2.8 + (i % 3) * 0.6,
            Paint()
              ..color = const Color(
                0xFFEDE7F6,
              ).withValues(alpha: (0.14 + pulse * 0.05) * introFade),
          );
          canvas.drawLine(
            p,
            orbPos,
            Paint()
              ..color = const Color(
                0xFFB39DDB,
              ).withValues(alpha: (0.08 + ((i % 4) * 0.01)) * introFade)
              ..strokeWidth = 1.0,
          );
        }
        for (var i = 0; i < nodePoints.length; i++) {
          final a = nodePoints[i];
          final b = nodePoints[(i + 2) % nodePoints.length];
          canvas.drawLine(
            a,
            b,
            Paint()
              ..color = const Color(
                0xFF9575CD,
              ).withValues(alpha: 0.06 * introFade)
              ..strokeWidth = 0.8,
          );
        }

        canvas.drawCircle(
          orbPos,
          32,
          Paint()
            ..color = orbColor.withValues(
              alpha: (0.22 + pulse * 0.09) * introFade,
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
        canvas.drawCircle(
          orbPos,
          14,
          Paint()..color = orbColor.withValues(alpha: 0.95 * introFade),
        );
        canvas.drawCircle(
          orbPos,
          4.5,
          Paint()
            ..color = const Color(
              0xFFFFFFFF,
            ).withValues(alpha: 0.9 * introFade),
        );
      }
    }

    // ── particle swarms ──
    final ww3 = world_.worldSize.width;
    final wh3 = world_.worldSize.height;
    for (final swarm in world_.particleSwarms) {
      final elColor = elementColor(swarm.element);
      final pulseAlpha = 0.6 + 0.3 * sin(swarm.pulse * 1.8);

      for (final mote in swarm.motes) {
        if (mote.collected) continue;

        // World-space position
        var mx = swarm.center.dx + mote.offsetX;
        var my = swarm.center.dy + mote.offsetY;

        // Toroidal screen-space
        var relX = mx - cx;
        var relY = my - cy;
        if (relX > ww3 / 2) relX -= ww3;
        if (relX < -ww3 / 2) relX += ww3;
        if (relY > wh3 / 2) relY -= wh3;
        if (relY < -wh3 / 2) relY += wh3;
        mx = cx + relX;
        my = cy + relY;

        // Cull off-screen
        if (mx < cx - 20 ||
            mx > cx + screenW + 20 ||
            my < cy - 20 ||
            my > cy + screenH + 20) {
          continue;
        }

        // Gentle per-mote pulse using orbitPhase offset
        final moteAlpha =
            (pulseAlpha *
                    (0.7 + 0.3 * sin(swarm.pulse * 2.5 + mote.orbitPhase)))
                .clamp(0.0, 1.0);

        // Outer glow
        canvas.drawCircle(
          Offset(mx, my),
          mote.size + 4,
          Paint()
            ..color = elColor.withValues(alpha: moteAlpha * 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        // Core
        canvas.drawCircle(
          Offset(mx, my),
          mote.size,
          Paint()..color = elColor.withValues(alpha: moteAlpha * 0.9),
        );
      }
    }

    // ── planets ──
    for (final pc in planetComps) {
      final planet = pc.planet;
      if ((planet.position.dx - cx - screenW / 2).abs() > screenW &&
          (planet.position.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }

      pc.render(canvas, _elapsed);
    }

    // ── star dust ──
    for (final dust in starDusts) {
      if (dust.collected) continue;
      final dp = dust.position;
      if ((dp.dx - cx - screenW / 2).abs() > screenW ||
          (dp.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }

      // Outer glow
      final glowAlpha = 0.3 + 0.2 * sin(_elapsed * 2.0 + dust.index * 0.7);
      canvas.drawCircle(
        dp,
        14,
        Paint()
          ..color = const Color(0xFFFFD700).withValues(alpha: glowAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      // Core sparkle
      final coreAlpha = 0.7 + 0.3 * sin(_elapsed * 3.0 + dust.index * 1.3);
      canvas.drawCircle(
        dp,
        4,
        Paint()..color = const Color(0xFFFFFFE0).withValues(alpha: coreAlpha),
      );
      // Tiny rays
      final rayPaint = Paint()
        ..color = const Color(0xFFFFD700).withValues(alpha: 0.25)
        ..strokeWidth = 1;
      for (var r = 0; r < 4; r++) {
        final a = _elapsed * 0.5 + r * pi / 2;
        canvas.drawLine(
          Offset(dp.dx + cos(a) * 6, dp.dy + sin(a) * 6),
          Offset(dp.dx + cos(a) * 14, dp.dy + sin(a) * 14),
          rayPaint,
        );
      }
    }

    // ── galaxy whirls ──
    for (final whirl in galaxyWhirls) {
      final wp = whirl.position;
      if ((wp.dx - cx - screenW / 2).abs() > screenW * 1.5 ||
          (wp.dy - cy - screenH / 2).abs() > screenH * 1.5) {
        continue;
      }

      final wColor = elementColor(whirl.element);
      final isActive = whirl.state == WhirlState.active;
      final isComplete = whirl.state == WhirlState.completed;
      final baseAlpha = isComplete ? 0.15 : (isActive ? 1.0 : 0.6);

      // Outer spiral arms
      for (var arm = 0; arm < 3; arm++) {
        final armOffset = arm * pi * 2 / 3;
        for (var i = 0; i < 20; i++) {
          final frac = i / 20.0;
          final spiralAngle = whirl.rotation + armOffset + frac * pi * 2.5;
          final spiralR = whirl.radius * (0.15 + frac * 0.85);
          final sx = wp.dx + cos(spiralAngle) * spiralR;
          final sy = wp.dy + sin(spiralAngle) * spiralR;
          final dotAlpha = (1.0 - frac) * 0.5 * baseAlpha;
          final dotSize = 2.5 + (1.0 - frac) * 2.0;
          canvas.drawCircle(
            Offset(sx, sy),
            dotSize,
            Paint()
              ..color = wColor.withValues(alpha: dotAlpha)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, dotSize),
          );
        }
      }

      // Core glow
      final coreSize = whirl.radius * (isActive ? 0.35 : 0.25);
      final corePulse = 0.8 + 0.2 * sin(whirl.pulse * 3);
      canvas.drawCircle(
        wp,
        coreSize * corePulse,
        Paint()
          ..color = wColor.withValues(alpha: 0.4 * baseAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, coreSize),
      );
      canvas.drawCircle(
        wp,
        coreSize * 0.4,
        Paint()..color = Colors.white.withValues(alpha: 0.5 * baseAlpha),
      );

      // Orbiting motes
      for (var m = 0; m < 8; m++) {
        final mAngle = whirl.rotation * 1.5 + m * pi / 4;
        final mR = whirl.radius * (0.5 + 0.3 * sin(whirl.pulse * 2 + m));
        canvas.drawCircle(
          Offset(wp.dx + cos(mAngle) * mR, wp.dy + sin(mAngle) * mR),
          2.0,
          Paint()..color = wColor.withValues(alpha: 0.6 * baseAlpha),
        );
      }

      // Status label / indicators
      if (isActive) {
        // Activation ring
        canvas.drawCircle(
          wp,
          GalaxyWhirl.activationRadius,
          Paint()
            ..color = wColor.withValues(alpha: 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        // Wave indicator
        final waveTp = TextPainter(
          text: TextSpan(
            text:
                'Lv${whirl.level} ${whirl.hordeTypeName} ${whirl.currentWave + 1}/${whirl.totalWaves}',
            style: TextStyle(
              color: wColor.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        waveTp.paint(
          canvas,
          Offset(wp.dx - waveTp.width / 2, wp.dy - whirl.radius - 20),
        );
        // Timer
        final timerSec = whirl.waveTimer.ceil();
        final timerTp = TextPainter(
          text: TextSpan(
            text: '${timerSec}s',
            style: TextStyle(
              color: timerSec <= 10
                  ? Colors.redAccent
                  : Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        timerTp.paint(
          canvas,
          Offset(wp.dx - timerTp.width / 2, wp.dy - whirl.radius - 34),
        );
      } else if (!isComplete) {
        final dormantTp = TextPainter(
          text: TextSpan(
            text: 'Lv${whirl.level} ${whirl.hordeTypeName}',
            style: TextStyle(
              color: wColor.withValues(alpha: 0.5),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        dormantTp.paint(
          canvas,
          Offset(wp.dx - dormantTp.width / 2, wp.dy + whirl.radius + 8),
        );
      } else {
        final completeTp = TextPainter(
          text: TextSpan(
            text: 'CLEARED',
            style: TextStyle(
              color: Colors.greenAccent.withValues(alpha: 0.6),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        completeTp.paint(
          canvas,
          Offset(wp.dx - completeTp.width / 2, wp.dy + whirl.radius + 8),
        );
      }
    }

    // ── prismatic field (aurora easter-egg) — hidden after reward claimed ──
    if (!prismaticRewardClaimed) {
      _renderPrismaticField(canvas, cx, cy, screenW, screenH);
    }

    // ── space POIs ──
    for (final poi in spacePOIs) {
      final pp = poi.position;
      if ((pp.dx - cx - screenW / 2).abs() > screenW * 1.5 ||
          (pp.dy - cy - screenH / 2).abs() > screenH * 1.5) {
        continue;
      }

      // All POI types stay visible after interaction (just dimmed)

      switch (poi.type) {
        case POIType.nebula:
          final nColor = elementColor(poi.element);
          final nAlpha = poi.interacted ? 0.24 : 0.3;
          for (var layer = 0; layer < 5; layer++) {
            final nR = poi.radius * (0.5 + layer * 0.3);
            final drift = sin(poi.life * 0.2 + layer * 0.8) * 15;
            canvas.drawCircle(
              Offset(pp.dx + drift, pp.dy + drift * 0.7),
              nR,
              Paint()
                ..color = nColor.withValues(
                  alpha: nAlpha * (1.0 - layer * 0.15),
                )
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, nR * 0.8),
            );
          }
          for (var s = 0; s < 6; s++) {
            final sa = poi.life * 0.3 + s * pi / 3;
            final sr = poi.radius * 0.4 * (0.5 + 0.5 * sin(poi.life + s));
            canvas.drawCircle(
              Offset(pp.dx + cos(sa) * sr, pp.dy + sin(sa) * sr),
              2,
              Paint()
                ..color = Colors.white.withValues(
                  alpha: 0.3 + 0.2 * sin(poi.life * 2 + s),
                ),
            );
          }
          if (!poi.interacted) {
            final nebTp = TextPainter(
              text: TextSpan(
                text: '${poi.element.toUpperCase()} NEBULA',
                style: TextStyle(
                  color: nColor.withValues(alpha: 0.6),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            nebTp.paint(
              canvas,
              Offset(pp.dx - nebTp.width / 2, pp.dy + poi.radius + 10),
            );
          }
          break;
        case POIType.derelict:
          final dAlphaScale = poi.interacted ? 0.7 : 1.0;
          // Ambient distress beacon glow
          if (!poi.interacted) {
            final beaconPulse = 0.15 + 0.1 * sin(poi.life * 2.5);
            canvas.drawCircle(
              pp,
              45,
              Paint()
                ..color = const Color(0xFFFF6F00).withValues(alpha: beaconPulse)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25),
            );
          }
          canvas.save();
          canvas.translate(pp.dx, pp.dy);
          canvas.rotate(sin(poi.life * 0.1) * 0.15);

          // Main hull (larger)
          final hullPath = Path()
            ..moveTo(-22, -12)
            ..lineTo(18, -10)
            ..lineTo(28, -2)
            ..lineTo(24, 6)
            ..lineTo(14, 12)
            ..lineTo(-8, 10)
            ..lineTo(-18, 8)
            ..lineTo(-26, 2)
            ..close();
          // Hull shadow
          canvas.drawPath(
            hullPath,
            Paint()
              ..color = const Color(
                0xFF37474F,
              ).withValues(alpha: 0.8 * dAlphaScale),
          );
          // Hull gradient overlay for depth
          canvas.drawPath(
            hullPath,
            Paint()
              ..shader = ui.Gradient.linear(
                const Offset(-22, -12),
                const Offset(24, 12),
                [
                  const Color(0xFF607D8B).withValues(alpha: 0.5 * dAlphaScale),
                  const Color(0xFF263238).withValues(alpha: 0.6 * dAlphaScale),
                ],
              ),
          );
          // Hull edge
          canvas.drawPath(
            hullPath,
            Paint()
              ..color = const Color(
                0xFF90A4AE,
              ).withValues(alpha: 0.5 * dAlphaScale)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );

          // Broken wing / fin piece (detached)
          final finPath = Path()
            ..moveTo(-10, -14)
            ..lineTo(-4, -20)
            ..lineTo(6, -18)
            ..lineTo(2, -12)
            ..close();
          canvas.drawPath(
            finPath,
            Paint()
              ..color = const Color(
                0xFF546E7A,
              ).withValues(alpha: 0.6 * dAlphaScale),
          );
          canvas.drawPath(
            finPath,
            Paint()
              ..color = const Color(
                0xFF90A4AE,
              ).withValues(alpha: 0.3 * dAlphaScale)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8,
          );

          // Damage scorch marks
          canvas.drawLine(
            const Offset(-5, -6),
            const Offset(8, 2),
            Paint()
              ..color = const Color(
                0xFF1B1B1B,
              ).withValues(alpha: 0.4 * dAlphaScale)
              ..strokeWidth = 1.5
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            const Offset(10, -4),
            const Offset(18, 4),
            Paint()
              ..color = const Color(
                0xFF1B1B1B,
              ).withValues(alpha: 0.3 * dAlphaScale)
              ..strokeWidth = 1.0
              ..strokeCap = StrokeCap.round,
          );

          // Flickering fire/sparks (multiple points)
          final spark1 = sin(poi.life * 5) > 0.6;
          final spark2 = sin(poi.life * 3.7 + 1.5) > 0.5;
          if (spark1) {
            canvas.drawCircle(
              const Offset(8, -3),
              4,
              Paint()
                ..color = const Color(0xFFFF6F00).withValues(alpha: 0.6)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
            );
          }
          if (spark2) {
            canvas.drawCircle(
              const Offset(-12, 4),
              3,
              Paint()
                ..color = const Color(0xFFFFAB00).withValues(alpha: 0.4)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
            );
          }

          // Floating debris pieces
          for (var d = 0; d < 6; d++) {
            final da = poi.life * 0.12 + d * pi / 3;
            final dr = 30.0 + 8 * sin(poi.life * 0.25 + d);
            final debrisSize = 1.0 + (d % 3) * 0.8;
            canvas.drawCircle(
              Offset(cos(da) * dr, sin(da) * dr),
              debrisSize,
              Paint()..color = const Color(0xFF78909C).withValues(alpha: 0.4),
            );
          }

          // Small blinking red distress light
          if (!poi.interacted && sin(poi.life * 4) > 0.8) {
            canvas.drawCircle(
              const Offset(-20, -6),
              2.5,
              Paint()
                ..color = const Color(0xFFFF1744).withValues(alpha: 0.8)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
            );
          }

          canvas.restore();
          if (!poi.interacted) {
            final derelictTp = TextPainter(
              text: const TextSpan(
                text: 'DERELICT',
                style: TextStyle(
                  color: Color(0xCC90A4AE),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            derelictTp.paint(
              canvas,
              Offset(pp.dx - derelictTp.width / 2, pp.dy + 28),
            );
          }
          break;
        case POIType.comet:
          final mColor = elementColor(poi.element);
          final zoneR = poi.radius;
          final fallAngle = poi.angle + 0.35 * sin(poi.life * 0.2);
          final baseDir = Offset(cos(fallAngle), sin(fallAngle));

          // Broad atmospheric haze so it reads like a moving storm region.
          canvas.drawCircle(
            pp,
            zoneR * 0.9,
            Paint()
              ..color = mColor.withValues(alpha: 0.05)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, zoneR * 0.22),
          );
          canvas.drawCircle(
            pp,
            zoneR * 0.45,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.03)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, zoneR * 0.15),
          );

          // Meteors fly through one-after-another (not static floating dots).
          const slots = 14;
          const cycleSeconds = 14.0;
          final spacing = cycleSeconds / slots;
          final activeWindow =
              spacing * 0.72; // leaves a short gap between meteors
          final cycleT = poi.life % cycleSeconds;

          for (var i = 0; i < slots; i++) {
            var local = cycleT - i * spacing;
            if (local < 0) local += cycleSeconds;
            if (local > activeWindow) continue;

            final t = local / activeWindow; // 0..1 for this meteor life
            final smooth = t * t * (3 - 2 * t); // smoothstep
            final fade = t < 0.2
                ? (t / 0.2)
                : (t > 0.82 ? ((1 - t) / 0.18).clamp(0.0, 1.0) : 1.0);

            final lane = ((i * 37) % 100) / 100.0 * 2 - 1; // -1..1
            final laneAngle = fallAngle + lane * 0.32;
            final dir = Offset(cos(laneAngle), sin(laneAngle));
            final perp = Offset(-dir.dy, dir.dx);

            final travel = zoneR * 2.4;
            final lateral = lane * zoneR * 0.55;
            final start = pp - dir * (travel * 0.54) + perp * lateral;
            final head = start + dir * (travel * smooth);
            final tailLen = 70.0 + (i % 4) * 18.0;
            final tail = head - dir * tailLen;
            final alpha = (0.18 + (1 - t) * 0.52) * fade;

            canvas.drawLine(
              tail,
              head,
              Paint()
                ..color = mColor.withValues(alpha: alpha * 0.95)
                ..strokeWidth = 1.6 + (i % 2) * 0.5
                ..strokeCap = StrokeCap.round
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.8),
            );

            canvas.drawLine(
              head - dir * 16,
              head,
              Paint()
                ..color = Colors.white.withValues(alpha: alpha * 0.9)
                ..strokeWidth = 0.9
                ..strokeCap = StrokeCap.round
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
            );

            canvas.drawCircle(
              head,
              1.9 + (i % 2) * 0.5,
              Paint()
                ..color = Colors.white.withValues(alpha: alpha)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
            );
          }

          // Light drifting dust behind the active stream direction.
          for (var d = 0; d < 10; d++) {
            final drift =
                poi.life * (0.16 + d * 0.011) + d * 1.23 + baseDir.dx * 1.7;
            final r = zoneR * (0.22 + (d % 7) * 0.09);
            final p = Offset(
              pp.dx + cos(drift) * r,
              pp.dy + sin(drift * 1.2) * r * 0.7,
            );
            canvas.drawCircle(
              p,
              1.2 + (d % 3) * 0.35,
              Paint()..color = mColor.withValues(alpha: 0.12),
            );
          }
          break;
        case POIType.warpAnomaly:
          final wAlphaScale = poi.interacted ? 0.8 : 1.0;
          for (var ring = 0; ring < 4; ring++) {
            final anomR =
                poi.radius * (0.3 + ring * 0.25) + sin(poi.life * 3 + ring) * 5;
            canvas.drawCircle(
              pp,
              anomR,
              Paint()
                ..color = const Color(
                  0xFF7C4DFF,
                ).withValues(alpha: (0.12 - ring * 0.02) * wAlphaScale)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
            );
          }
          canvas.drawCircle(
            pp,
            poi.radius * 0.2,
            Paint()
              ..color = const Color(
                0xFFB388FF,
              ).withValues(alpha: 0.4 + 0.2 * sin(poi.life * 4))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
          if (!poi.interacted) {
            final anomTp = TextPainter(
              text: const TextSpan(
                text: 'ANOMALY',
                style: TextStyle(
                  color: Color(0x99B388FF),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            anomTp.paint(
              canvas,
              Offset(pp.dx - anomTp.width / 2, pp.dy + poi.radius + 10),
            );
          }
          break;
        case POIType.harvesterMarket:
        case POIType.riftKeyMarket:
        case POIType.cosmicMarket:
        case POIType.stardustScanner:
          final mColor = poi.type == POIType.harvesterMarket
              ? const Color(0xFFFFB300) // amber/gold
              : poi.type == POIType.riftKeyMarket
              ? const Color(0xFF7C4DFF) // purple
              : poi.type == POIType.cosmicMarket
              ? const Color(0xFF00E5FF) // cyan/teal for cosmic
              : const Color(0xFF9CCC65); // green for scanner
          // Rotating hexagonal station
          canvas.save();
          canvas.translate(pp.dx, pp.dy);
          canvas.rotate(poi.life * 0.15);
          // Outer hex
          final hexPath = Path();
          for (var i = 0; i < 6; i++) {
            final a = i * pi / 3;
            final hx = cos(a) * poi.radius * 0.7;
            final hy = sin(a) * poi.radius * 0.7;
            if (i == 0) {
              hexPath.moveTo(hx, hy);
            } else {
              hexPath.lineTo(hx, hy);
            }
          }
          hexPath.close();
          canvas.drawPath(
            hexPath,
            Paint()
              ..color = mColor.withValues(alpha: 0.15)
              ..style = PaintingStyle.fill,
          );
          canvas.drawPath(
            hexPath,
            Paint()
              ..color = mColor.withValues(alpha: 0.6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
          // Inner glow
          canvas.drawCircle(
            Offset.zero,
            poi.radius * 0.3,
            Paint()
              ..color = mColor.withValues(alpha: 0.3 + 0.15 * sin(poi.life * 2))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
          // Center icon dot
          canvas.drawCircle(
            Offset.zero,
            4,
            Paint()..color = Colors.white.withValues(alpha: 0.8),
          );
          // Orbiting sparkles
          for (var s = 0; s < 4; s++) {
            final sa = poi.life * 0.5 + s * pi / 2;
            final sr = poi.radius * 0.5;
            canvas.drawCircle(
              Offset(cos(sa) * sr, sin(sa) * sr),
              1.5,
              Paint()
                ..color = mColor.withValues(
                  alpha: 0.5 + 0.3 * sin(poi.life * 3 + s),
                ),
            );
          }
          canvas.restore();
          // Label
          final marketLabel = poi.type == POIType.harvesterMarket
              ? 'HARVESTER SHOP'
              : poi.type == POIType.riftKeyMarket
              ? 'RIFT KEY SHOP'
              : poi.type == POIType.cosmicMarket
              ? 'COSMIC MARKET'
              : 'STAR DUST SCANNER';
          final mTp = TextPainter(
            text: TextSpan(
              text: marketLabel,
              style: TextStyle(
                color: mColor.withValues(alpha: 0.7),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          mTp.paint(
            canvas,
            Offset(pp.dx - mTp.width / 2, pp.dy + poi.radius * 0.8 + 8),
          );
          break;
      }
    }

    // ── rift portal ──
    // ── rift portals (all 5) ──
    for (final rift in world_.riftPortals) {
      final rp = rift.position;
      if ((rp.dx - cx - screenW / 2).abs() < screenW * 1.5 &&
          (rp.dy - cy - screenH / 2).abs() < screenH * 1.5) {
        final col = rift.color;
        final core = rift.coreColor;
        // Outer glow
        canvas.drawCircle(
          rp,
          48,
          Paint()
            ..color = col.withValues(alpha: 0.08)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
        );
        // Dark void core
        canvas.drawCircle(rp, 28, Paint()..color = core);
        // Pulsing rings (faction-coloured)
        for (var i = 0; i < 3; i++) {
          final ringR = 30.0 + i * 12 + 4 * sin(_riftPulse * 2 + i);
          canvas.drawCircle(
            rp,
            ringR,
            Paint()
              ..color = col.withValues(alpha: 0.3 - i * 0.08)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
        // Orbiting sparks
        for (var j = 0; j < 6; j++) {
          final a = _riftPulse * 1.2 + j * pi / 3;
          final sr = 36.0 + 8 * sin(_riftPulse * 3 + j);
          canvas.drawCircle(
            Offset(rp.dx + cos(a) * sr, rp.dy + sin(a) * sr),
            2.5,
            Paint()..color = col.withValues(alpha: 0.6),
          );
        }
      }
    }

    // ── elemental nexus (massive black portal – 5× scale, cached texture) ──
    {
      final nx = elementalNexus;
      final np = nx.position;
      if ((np.dx - cx - screenW / 2).abs() < screenW * 2.5 &&
          (np.dy - cy - screenH / 2).abs() < screenH * 2.5) {
        // Rebuild cached texture ~10 fps
        if (_nexusCachedImage == null ||
            (_riftPulse - _nexusCacheTime).abs() >= _nexusCacheInterval) {
          _nexusCachedImage?.dispose();
          _nexusCachedImage = _buildNexusTexture(_riftPulse);
          _nexusCacheTime = _riftPulse;
        }

        // Draw cached texture scaled to world coordinates
        final img = _nexusCachedImage!;
        const texR = _nexusTexWorldR;
        canvas.save();
        canvas.translate(np.dx - texR, np.dy - texR);
        canvas.scale(texR * 2 / _nexusTexSize, texR * 2 / _nexusTexSize);
        canvas.drawImage(img, Offset.zero, Paint());
        canvas.restore();

        // Label when close (cheap — drawn every frame)
        if (_isNearNexus || (np - ship.pos).distance < 400) {
          final textPainter = TextPainter(
            text: const TextSpan(
              text: 'NEXUS',
              style: TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(
            canvas,
            Offset(np.dx - textPainter.width / 2, np.dy + 70),
          );
        }
      }
    }

    // ── battle ring (octagonal arena – cached texture) ──
    {
      final br = battleRing;
      final bp = br.position;
      if ((bp.dx - cx - screenW / 2).abs() < screenW * 2.5 &&
          (bp.dy - cy - screenH / 2).abs() < screenH * 2.5) {
        // Rebuild cached texture ~10 fps
        if (_battleRingCachedImage == null ||
            (_riftPulse - _battleRingCacheTime).abs() >=
                _battleRingCacheInterval) {
          _battleRingCachedImage?.dispose();
          _battleRingCachedImage = _buildBattleRingTexture(_riftPulse);
          _battleRingCacheTime = _riftPulse;
        }

        // Draw cached texture scaled to world coordinates
        final img = _battleRingCachedImage!;
        const texR = _battleRingTexWorldR;
        canvas.save();
        canvas.translate(bp.dx - texR, bp.dy - texR);
        canvas.scale(
          texR * 2 / _battleRingTexSize,
          texR * 2 / _battleRingTexSize,
        );
        canvas.drawImage(img, Offset.zero, Paint());
        canvas.restore();

        // Label when nearby
        if (_isNearBattleRing || (bp - ship.pos).distance < 500) {
          final label = br.isCompleted ? 'BATTLE ARENA' : 'BATTLE RING';
          final textPainter = TextPainter(
            text: TextSpan(
              text: label,
              style: const TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(
            canvas,
            Offset(bp.dx - textPainter.width / 2, bp.dy + 80),
          );
        }
      }
    }

    // ── blood ring (ending ritual portal) ──
    {
      final ring = bloodRing;
      final rp = ring.position;
      if ((rp.dx - cx - screenW / 2).abs() < screenW * 2.5 &&
          (rp.dy - cy - screenH / 2).abs() < screenH * 2.5) {
        final pulse = 0.82 + 0.18 * sin(_riftPulse * 2.2);
        final outerR =
            BloodRing.visualRadius * (0.92 + 0.06 * sin(_riftPulse * 1.4));

        // Outer blood haze
        canvas.drawCircle(
          rp,
          outerR * 1.18,
          Paint()
            ..color = const Color(0xFF7F0000).withValues(alpha: 0.22 * pulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
        );

        // Main ritual ring
        canvas.drawCircle(
          rp,
          outerR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10
            ..color = const Color(0xFFB71C1C).withValues(alpha: 0.8 * pulse),
        );

        // Inner ring
        canvas.drawCircle(
          rp,
          outerR * 0.72,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFFFCDD2).withValues(alpha: 0.5 * pulse),
        );

        // Orbiting ritual marks
        for (var i = 0; i < 8; i++) {
          final a = _riftPulse * 0.65 + (i * pi / 4);
          final markPos = Offset(
            rp.dx + cos(a) * (outerR + 24),
            rp.dy + sin(a) * (outerR + 24),
          );
          canvas.drawCircle(
            markPos,
            4.5,
            Paint()..color = const Color(0xFFFF8A80).withValues(alpha: 0.8),
          );
        }

        // Core state changes after ending completion.
        if (ring.ritualCompleted) {
          canvas.drawCircle(
            rp,
            outerR * 0.24,
            Paint()
              ..shader = ui.Gradient.radial(rp, outerR * 0.26, [
                const Color(0xFFB2EBF2).withValues(alpha: 0.85),
                const Color(0xFF1A0000).withValues(alpha: 0.0),
              ]),
          );
        } else {
          canvas.drawCircle(
            rp,
            outerR * 0.18,
            Paint()
              ..color = const Color(0xFF4A0000).withValues(alpha: 0.65 * pulse),
          );
        }

        if (_isNearBloodRing || (rp - ship.pos).distance < 550) {
          final label = ring.ritualCompleted ? 'BLOOD PORTAL' : 'BLOOD RING';
          final textPainter = TextPainter(
            text: TextSpan(
              text: label,
              style: const TextStyle(
                color: Color(0x99FF8A80),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(
            canvas,
            Offset(rp.dx - textPainter.width / 2, rp.dy + outerR * 0.45),
          );
        }
      }
    }

    // ── trait contest arenas ──
    for (final arena in contestArenas) {
      final ap = arena.position;
      if ((ap.dx - cx - screenW / 2).abs() > screenW * 2.5 ||
          (ap.dy - cy - screenH / 2).abs() > screenH * 2.5) {
        continue;
      }

      final col = arena.trait.color;
      final pulse = 0.82 + 0.18 * sin(_riftPulse * 1.9 + arena.trait.index);

      canvas.drawCircle(
        ap,
        CosmicContestArena.visualRadius * 0.95,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = col.withValues(alpha: 0.42 * pulse),
      );
      canvas.drawCircle(
        ap,
        CosmicContestArena.visualRadius * 0.62,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = col.withValues(alpha: 0.76 * pulse),
      );
      canvas.drawCircle(
        ap,
        CosmicContestArena.visualRadius * 0.22,
        Paint()
          ..color = col.withValues(alpha: 0.28 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      if (nearContestArena == arena || (ap - ship.pos).distance < 520) {
        final labelPainter = TextPainter(
          text: TextSpan(
            text: arena.trait.arenaLabel.toUpperCase(),
            style: TextStyle(
              color: col.withValues(alpha: 0.86),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        labelPainter.paint(
          canvas,
          Offset(ap.dx - labelPainter.width / 2, ap.dy + 90),
        );
      }
    }

    // ── floating trait hint notes ──
    for (final note in contestHintNotes) {
      if (note.collected) continue;
      final np = note.position;
      if ((np.dx - cx - screenW / 2).abs() > screenW * 1.2 ||
          (np.dy - cy - screenH / 2).abs() > screenH * 1.2) {
        continue;
      }
      final nPulse = 0.5 + 0.5 * sin(_elapsed * 3.4 + note.id.hashCode * 0.01);
      canvas.drawCircle(
        np,
        18 + nPulse * 4,
        Paint()
          ..color = const Color(
            0xFFB3E5FC,
          ).withValues(alpha: 0.1 + nPulse * 0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        np,
        4,
        Paint()..color = const Color(0xFFE1F5FE).withValues(alpha: 0.9),
      );
    }

    // ── home planet ──
    if (homePlanet != null) {
      final hp = homePlanet!;
      final vr = hp.visualRadius;
      final hpPos = _wrappedRenderPos(hp.position, cx, cy, screenW, screenH);
      // Keep rendering longer so large outer cosmetics don't pop off-screen.
      final homeVisualMargin = vr * 4.5 + 240.0;
      if ((hpPos.dx - cx - screenW / 2).abs() < screenW + homeVisualMargin &&
          (hpPos.dy - cy - screenH / 2).abs() < screenH + homeVisualMargin) {
        final col = hp.blendedColor;

        // Warm aura
        canvas.drawCircle(
          hpPos,
          vr * 2.5,
          Paint()
            ..color = col.withValues(alpha: 0.12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25),
        );

        // ── Customization visual effects (rendered behind planet body) ──
        _renderHomeEffectsBehind(canvas, hpPos, vr, col);

        // Planet body — gradient sphere
        final bodyPaint = Paint()
          ..shader = ui.Gradient.radial(
            Offset(hpPos.dx - vr * 0.3, hpPos.dy - vr * 0.3),
            vr * 1.5,
            [
              Color.lerp(col, Colors.white, 0.35)!,
              col,
              Color.lerp(col, Colors.black, 0.5)!,
            ],
            [0.0, 0.5, 1.0],
          );
        canvas.drawCircle(hpPos, vr, bodyPaint);

        // ── Customization visual effects (rendered in front of planet) ──
        _renderHomeEffectsFront(canvas, hpPos, vr, col);

        // ── Garrison creatures inside planet ──
        for (final g in _garrison) {
          final eColor = elementColor(g.member.element);

          canvas.save();
          canvas.translate(g.position.dx, g.position.dy);

          // Subtle aura glow
          final auraPulse = 0.4 + 0.2 * sin(_elapsed * 2.5 + g.position.dx);
          canvas.drawCircle(
            Offset.zero,
            18 * g.spriteScale,
            Paint()
              ..color = eColor.withValues(alpha: auraPulse * 0.25)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );

          // ── Shield bubble (Horn special) ──
          if (g.shieldHp > 0) {
            final shieldPulse = 0.6 + 0.3 * sin(_elapsed * 5.0);
            canvas.drawCircle(
              Offset.zero,
              22 * g.spriteScale,
              Paint()
                ..color = eColor.withValues(alpha: shieldPulse * 0.35)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.5
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
            );
          }

          // ── Charge trail (Horn charging) ──
          if (g.chargeTimer > 0) {
            for (var t = 0; t < 4; t++) {
              final trailAngle = g.faceAngle + pi;
              final trailDist = 6.0 + t * 6.0;
              final tAlpha = (1.0 - t / 4.0) * 0.4;
              canvas.drawCircle(
                Offset(
                  cos(trailAngle) * trailDist,
                  sin(trailAngle) * trailDist,
                ),
                (4.0 - t) * g.spriteScale,
                Paint()
                  ..color = eColor.withValues(alpha: tAlpha)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
              );
            }
          }

          // ── Blessing aura (Kin healing) ──
          if (g.blessingTimer > 0) {
            final blessPulse = 0.5 + 0.4 * sin(_elapsed * 4.0);
            canvas.drawCircle(
              Offset.zero,
              16 * g.spriteScale,
              Paint()
                ..color = Colors.greenAccent.withValues(
                  alpha: blessPulse * 0.25,
                )
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
            );
          }

          if (g.ticker != null) {
            final sprite = g.ticker!.getSprite();
            final paint = Paint()..filterQuality = ui.FilterQuality.high;

            // Apply genetics color filter
            if (g.visuals != null) {
              final v = g.visuals!;
              final isAlbino = v.brightness == 1.45 && !v.isPrismatic;
              if (isAlbino) {
                paint.colorFilter = _albinoColorFilter(v.brightness);
              } else {
                paint.colorFilter = _geneticsColorFilter(v);
              }
            }

            // Render simple effect overlays for alchemy/variant effects (behind sprite)
            if (g.visuals?.alchemyEffect != null) {
              _drawAlchemyEffectCanvas(
                canvas: canvas,
                effect: g.visuals!.alchemyEffect!,
                spriteScale: g.spriteScale,
                baseSpriteSize: 40.0,
                variantFaction: g.visuals?.variantFaction,
                elapsed: _elapsed,
                opacity: 0.95,
              );
            }

            // Flip based on facing direction
            final facingRight = cos(g.faceAngle) > 0;
            canvas.save();
            if (facingRight) {
              canvas.scale(-g.spriteScale, g.spriteScale);
            } else {
              canvas.scale(g.spriteScale);
            }
            sprite.render(canvas, anchor: Anchor.center, overridePaint: paint);
            canvas.restore();
          } else {
            // Fallback: colored circle
            canvas.drawCircle(
              Offset.zero,
              10,
              Paint()..color = eColor.withValues(alpha: 0.8),
            );
          }

          canvas.restore();
        }

        // Home beacon ring
        final beaconAlpha = 0.3 + 0.2 * sin(_elapsed * 2.0);
        canvas.drawCircle(
          hpPos,
          vr + 8,
          Paint()
            ..color = const Color(0xFF00E5FF).withValues(alpha: beaconAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );

        // Label
        final homeLabel = TextPainter(
          text: TextSpan(
            text: 'HOME',
            style: TextStyle(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        homeLabel.paint(
          canvas,
          Offset(hpPos.dx - homeLabel.width / 2, hpPos.dy + vr + 12),
        );

        // ── Orbital path ring ──
        if (_orbitalPartner != null) {
          final center = _homeOrbitsPartner
              ? _wrappedRenderPos(
                  _orbitalPartner!.position,
                  cx,
                  cy,
                  screenW,
                  screenH,
                )
              : hpPos;
          // Dashed orbital ring
          final orbitPaint = Paint()
            ..color = const Color(0xFF00E5FF).withValues(alpha: 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawCircle(center, _orbitRadius, orbitPaint);
        }
      }
    }

    // ── orbital chambers ──
    for (final chamber in orbitalChambers) {
      // Skip empty (unassigned) chambers — no visual orb
      if (chamber.instanceId == null) continue;
      final cp = chamber.position;
      // Cull off-screen
      if ((cp.dx - cx - screenW / 2).abs() > screenW ||
          (cp.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }

      final r = chamber.radius;
      final col = chamber.color;
      final pulse = 1.0 + sin(chamber.life * 1.5 + chamber.seed) * 0.15;

      // 1. Outer aura (pulsing glow)
      canvas.drawCircle(
        cp,
        r * 2.5 * pulse,
        Paint()
          ..color = col.withValues(alpha: 0.18)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.5),
      );

      // 2. Glass orb body — radial gradient sphere
      final bodyPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(cp.dx - r * 0.3, cp.dy - r * 0.3),
          r * 1.5,
          [
            Color.lerp(col, Colors.white, 0.25)!,
            col,
            Color.lerp(col, Colors.black, 0.4)!,
          ],
          [0.0, 0.65, 1.0],
        );
      canvas.drawCircle(cp, r, bodyPaint);

      // 2b. Creature sprite inside the orb (clipped to circle)
      if (chamber.imagePath != null &&
          _chamberSpriteCache.containsKey(chamber.imagePath)) {
        final img = _chamberSpriteCache[chamber.imagePath]!;
        canvas.save();
        final clipPath = Path()
          ..addOval(Rect.fromCircle(center: cp, radius: r * 0.85));
        canvas.clipPath(clipPath);
        // Draw creature image centered and scaled to fill the orb
        final imgSize = r * 1.7;
        final srcRect = Rect.fromLTWH(
          0,
          0,
          img.width.toDouble(),
          img.height.toDouble(),
        );
        final dstRect = Rect.fromCenter(
          center: cp,
          width: imgSize,
          height: imgSize,
        );
        canvas.drawImageRect(img, srcRect, dstRect, Paint());
        canvas.restore();
      }

      // 3. Inner core sparkle
      final coreAlpha = 0.5 + 0.3 * sin(chamber.life * 3.0 + chamber.seed * 2);
      canvas.drawCircle(
        cp,
        r * 0.25,
        Paint()..color = Colors.white.withValues(alpha: coreAlpha),
      );

      // 5. Orbit ring indicator (faint) when near home planet
      if (homePlanet != null) {
        final distToHome = (cp - homePlanet!.position).distance;
        if (distToHome < chamber.orbitDistance * 2) {
          final ringAlpha =
              (0.12 *
              (1.0 -
                  (distToHome / (chamber.orbitDistance * 2)).clamp(0.0, 1.0)));
          canvas.drawCircle(
            homePlanet!.position,
            chamber.orbitDistance,
            Paint()
              ..color = col.withValues(alpha: ringAlpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8,
          );
        }
      }
    }

    // ── asteroids ──
    // Rock colour palettes (indexed by shape for variety)
    const rockBaseColors = [
      Color(0xFF5D4037), // warm brown
      Color(0xFF616161), // grey
      Color(0xFF4E342E), // dark brown
    ];
    const rockLightColors = [
      Color(0xFF8D6E63), // light brown
      Color(0xFF9E9E9E), // light grey
      Color(0xFF795548), // medium brown
    ];
    const rockDarkColors = [
      Color(0xFF3E2723), // very dark brown
      Color(0xFF424242), // dark grey
      Color(0xFF321911), // almost black brown
    ];

    for (final rock in asteroidBelt.asteroids) {
      if (rock.destroyed) continue;
      final rp = rock.position;
      if ((rp.dx - cx - screenW / 2).abs() > screenW ||
          (rp.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }

      canvas.save();
      canvas.translate(rp.dx, rp.dy);
      final spin = rock.rotation + _elapsed * rock.rotSpeed;
      canvas.rotate(spin);

      final si = rock.shape % 3;
      final healthFrac = rock.health.clamp(0.0, 1.0);
      final baseColor = Color.lerp(
        rockDarkColors[si],
        rockBaseColors[si],
        healthFrac,
      )!;
      final lightColor = rockLightColors[si];

      // Jagged shape
      final path = Path();
      final r = rock.radius;
      final int verts;
      switch (rock.shape) {
        case 0:
          verts = 5;
        case 1:
          verts = 6;
        default:
          verts = 8;
      }
      final offsets = <Offset>[];
      for (var i = 0; i < verts; i++) {
        final a = i * pi * 2 / verts;
        final rr =
            r *
            (0.7 +
                0.3 *
                    ((i.isEven ? 1.0 : 0.0) * 0.6 +
                        0.4 * (i % 3 == 0 ? 1.0 : 0.5)));
        final pt = Offset(cos(a) * rr, sin(a) * rr);
        offsets.add(pt);
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();

      // Radial gradient fill for depth
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(r * -0.2, r * -0.25), // light source offset
            r * 1.4,
            [lightColor.withValues(alpha: 0.9), baseColor],
            [0.0, 1.0],
          ),
      );

      // Surface cracks / detail lines (for rocks radius > 8)
      if (r > 8) {
        // Two crack lines across the surface
        final crackPaint = Paint()
          ..color = rockDarkColors[si].withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round;
        // Crack 1: from vertex 0 towards center-ish
        canvas.drawLine(
          offsets[0] * 0.85,
          offsets[verts ~/ 2] * 0.3,
          crackPaint,
        );
        // Crack 2: perpendicular-ish
        canvas.drawLine(
          offsets[1] * 0.6,
          offsets[(verts * 3 ~/ 4).clamp(0, verts - 1)] * 0.5,
          crackPaint,
        );
        // Small crater dot
        canvas.drawCircle(
          Offset(r * 0.15, r * -0.1),
          r * 0.12,
          Paint()..color = rockDarkColors[si].withValues(alpha: 0.3),
        );
      }

      // Edge highlight (lit side)
      canvas.drawPath(
        path,
        Paint()
          ..color = lightColor.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      // Dark rim on shadow side (bottom-right)
      if (r > 6) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFF000000).withValues(alpha: 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6,
        );
      }

      canvas.restore();
    }

    // ── loot drops ──
    for (final drop in lootDrops) {
      if (drop.collected) continue;
      final dp = drop.position;
      if ((dp.dx - cx - screenW / 2).abs() > screenW ||
          (dp.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }

      final fadeAlpha = drop.life > LootDrop.maxLifetime - 5.0
          ? ((LootDrop.maxLifetime - drop.life) / 5.0).clamp(0.0, 1.0)
          : 1.0;
      final bob = sin(drop.life * 3.0 + drop.position.dx * 0.01) * 2.0;
      final drawPos = Offset(dp.dx, dp.dy + bob);

      switch (drop.type) {
        case LootType.astralShard:
          // Astral Shard — floating crystal with purple glow
          final shimmer = 0.6 + 0.4 * sin(drop.life * 4.0);
          final spin = drop.life * 2.5 + drop.position.dx * 0.02;
          // Outer glow
          canvas.drawCircle(
            drawPos,
            8,
            Paint()
              ..color = const Color(
                0xFF7C4DFF,
              ).withValues(alpha: 0.3 * fadeAlpha)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
          // Diamond shape
          canvas.save();
          canvas.translate(drawPos.dx, drawPos.dy);
          canvas.rotate(spin);
          final shardPath = Path()
            ..moveTo(0, -5)
            ..lineTo(3.5, 0)
            ..lineTo(0, 5)
            ..lineTo(-3.5, 0)
            ..close();
          canvas.drawPath(
            shardPath,
            Paint()
              ..shader =
                  ui.Gradient.linear(const Offset(-3, -5), const Offset(3, 5), [
                    Color.lerp(
                      const Color(0xFFB388FF),
                      Colors.white,
                      shimmer,
                    )!.withValues(alpha: fadeAlpha),
                    const Color(0xFF7C4DFF).withValues(alpha: fadeAlpha),
                  ]),
          );
          // Bright core
          canvas.drawCircle(
            Offset.zero,
            1.5,
            Paint()..color = Colors.white.withValues(alpha: 0.7 * fadeAlpha),
          );
          canvas.restore();
          break;
        case LootType.healthOrb:
          // Health orb — soft red glowing orb
          final hpPulse =
              0.9 + 0.2 * sin(drop.life * 4.5 + drop.position.dy * 0.02);
          canvas.drawCircle(
            drawPos,
            12,
            Paint()
              ..color = drop.color.withValues(alpha: 0.22 * fadeAlpha * hpPulse)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
          );
          canvas.drawCircle(
            drawPos,
            6,
            Paint()
              ..shader = ui.Gradient.radial(
                Offset(drawPos.dx - 1.0, drawPos.dy - 1.0),
                6,
                [
                  Color.lerp(
                    drop.color,
                    Colors.white,
                    0.45,
                  )!.withValues(alpha: fadeAlpha * hpPulse),
                  drop.color.withValues(alpha: fadeAlpha * hpPulse),
                ],
              ),
          );
          canvas.drawCircle(
            drawPos,
            2,
            Paint()..color = Colors.white.withValues(alpha: 0.85 * fadeAlpha),
          );
          break;
        case LootType.elementParticle:
          // Element orb — coloured glow
          final pulse =
              0.8 + 0.2 * sin(drop.life * 4.5 + drop.position.dy * 0.02);
          canvas.drawCircle(
            drawPos,
            10,
            Paint()
              ..color = drop.color.withValues(alpha: 0.25 * fadeAlpha * pulse)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
          canvas.drawCircle(
            drawPos,
            5,
            Paint()
              ..shader = ui.Gradient.radial(
                Offset(drawPos.dx - 1.5, drawPos.dy - 1.5),
                6,
                [
                  Color.lerp(
                    drop.color,
                    Colors.white,
                    0.35,
                  )!.withValues(alpha: fadeAlpha * pulse),
                  drop.color.withValues(alpha: fadeAlpha * pulse),
                ],
              ),
          );
          // Tiny core
          canvas.drawCircle(
            drawPos,
            2,
            Paint()..color = Colors.white.withValues(alpha: 0.6 * fadeAlpha),
          );
          break;
        case LootType.item:
          // Item drop — pulsing hexagonal capsule with bright glow
          final pulse = 0.7 + 0.3 * sin(drop.life * 5.0);
          final spin = drop.life * 1.8;
          // Large outer glow
          canvas.drawCircle(
            drawPos,
            14,
            Paint()
              ..color = drop.color.withValues(alpha: 0.3 * fadeAlpha * pulse)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
          );
          // Hexagonal shape
          canvas.save();
          canvas.translate(drawPos.dx, drawPos.dy);
          canvas.rotate(spin);
          final hexPath = Path();
          for (var h = 0; h < 6; h++) {
            final ha = h * pi / 3 - pi / 6;
            final hp = Offset(cos(ha) * 6, sin(ha) * 6);
            if (h == 0) {
              hexPath.moveTo(hp.dx, hp.dy);
            } else {
              hexPath.lineTo(hp.dx, hp.dy);
            }
          }
          hexPath.close();
          canvas.drawPath(
            hexPath,
            Paint()
              ..shader =
                  ui.Gradient.linear(const Offset(-6, -6), const Offset(6, 6), [
                    Colors.white.withValues(alpha: 0.9 * fadeAlpha),
                    drop.color.withValues(alpha: fadeAlpha),
                  ]),
          );
          // Outline
          canvas.drawPath(
            hexPath,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.5 * fadeAlpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );
          // Bright center star
          canvas.drawCircle(
            Offset.zero,
            2.5,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.9 * fadeAlpha * pulse),
          );
          canvas.restore();
          break;
      }
    }

    // ── enemies ──
    for (final e in enemies) {
      if (e.dead) continue;
      final ep = e.position;
      if ((ep.dx - cx - screenW / 2).abs() > screenW ||
          (ep.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }

      final eColor = elementColor(e.element);

      canvas.save();
      canvas.translate(ep.dx, ep.dy);

      // Outer elemental aura
      canvas.drawCircle(
        Offset.zero,
        e.radius * 2.0,
        Paint()
          ..color = eColor.withValues(alpha: 0.10)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, e.radius * 1.2),
      );

      if (e.tier == EnemyTier.wisp) {
        // Wisps: ethereal flickering orb with soft radial gradient
        final flicker = 0.7 + 0.3 * sin(_elapsed * 6 + e.angle * 5);
        final wobble = e.radius * flicker;
        canvas.drawCircle(
          Offset.zero,
          wobble,
          Paint()
            ..shader = ui.Gradient.radial(
              const Offset(-1, -1),
              wobble,
              [
                Colors.white.withValues(alpha: 0.7 * flicker),
                eColor.withValues(alpha: 0.5 * flicker),
                eColor.withValues(alpha: 0.0),
              ],
              [0.0, 0.5, 1.0],
            ),
        );
        // Tiny red dot at center — marks them as hostile
        canvas.drawCircle(
          Offset.zero,
          e.radius * 0.15,
          Paint()
            ..color = Colors.red.withValues(alpha: 0.9 * flicker)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
        );
      } else if (e.tier == EnemyTier.sentinel) {
        // Sentinels: round body with orbiting satellites
        final r = e.radius;

        // Main body — solid sphere with gradient
        canvas.drawCircle(
          Offset.zero,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(-r * 0.25, -r * 0.25),
              r * 1.2,
              [
                Color.lerp(eColor, Colors.white, 0.35)!.withValues(alpha: 0.9),
                eColor.withValues(alpha: 0.8),
                Color.lerp(eColor, Colors.black, 0.5)!.withValues(alpha: 0.7),
              ],
              [0.0, 0.5, 1.0],
            ),
        );

        // Specular highlight on sphere
        canvas.drawCircle(
          Offset(-r * 0.2, -r * 0.25),
          r * 0.3,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );

        // Orbiting ring track (faint ellipse)
        canvas.save();
        canvas.rotate(_elapsed * 0.3 + e.angle);
        final ringR = r * 1.8;
        canvas.drawCircle(
          Offset.zero,
          ringR,
          Paint()
            ..color = eColor.withValues(alpha: 0.12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );

        // 3 orbiting satellites at different speeds/phases
        for (var i = 0; i < 3; i++) {
          final orbitAngle = _elapsed * (1.2 + i * 0.4) + i * pi * 2 / 3;
          final ox = cos(orbitAngle) * ringR;
          final oy = sin(orbitAngle) * ringR;
          final satR = r * (0.18 + i * 0.04);

          // Satellite glow
          canvas.drawCircle(
            Offset(ox, oy),
            satR * 2,
            Paint()
              ..color = eColor.withValues(alpha: 0.2)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, satR),
          );

          // Satellite body
          canvas.drawCircle(
            Offset(ox, oy),
            satR,
            Paint()
              ..shader = ui.Gradient.radial(
                Offset(ox - satR * 0.3, oy - satR * 0.3),
                satR,
                [
                  Colors.white.withValues(alpha: 0.7),
                  eColor.withValues(alpha: 0.8),
                ],
              ),
          );
        }
        canvas.restore();

        // Inner glow core
        canvas.drawCircle(
          Offset.zero,
          r * 0.25,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      } else if (e.tier == EnemyTier.drone) {
        // Drones: small angular hexagon, fast & twitchy
        final r = e.radius;
        final twitch = sin(_elapsed * 12 + e.angle * 7) * r * 0.08;

        // Hexagon body
        final hexPath = Path();
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3 - pi / 6; // flat-top hexagon
          final hr = r * (1.0 + (i.isEven ? twitch / r : -twitch / r));
          final hx = cos(a) * hr;
          final hy = sin(a) * hr;
          if (i == 0) {
            hexPath.moveTo(hx, hy);
          } else {
            hexPath.lineTo(hx, hy);
          }
        }
        hexPath.close();

        canvas.drawPath(
          hexPath,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, -r),
              Offset(0, r),
              [
                Color.lerp(eColor, Colors.white, 0.4)!.withValues(alpha: 0.9),
                eColor.withValues(alpha: 0.85),
                Color.lerp(eColor, Colors.black, 0.3)!.withValues(alpha: 0.7),
              ],
              [0.0, 0.5, 1.0],
            ),
        );

        // Sharp edge highlight
        canvas.drawPath(
          hexPath,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );

        // Central eye/core — bright flickering dot
        final eyePulse = 0.6 + 0.4 * sin(_elapsed * 8 + e.angle * 3);
        canvas.drawCircle(
          Offset.zero,
          r * 0.2,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.9 * eyePulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );

        // Exhaust trail sparks (2 small behind)
        for (var s = 0; s < 2; s++) {
          final sparkAngle = e.angle + pi + (s - 0.5) * 0.4;
          final sparkDist = r * (1.2 + 0.3 * sin(_elapsed * 10 + s * 3));
          canvas.drawCircle(
            Offset(cos(sparkAngle) * sparkDist, sin(sparkAngle) * sparkDist),
            r * 0.12,
            Paint()
              ..color = eColor.withValues(alpha: 0.5 * eyePulse)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }
      } else if (e.tier == EnemyTier.phantom) {
        // Phantoms: ghostly, semi-transparent with wispy tendrils
        final r = e.radius;
        final ghostPhase = _elapsed * 1.5 + e.angle * 2;
        final breathe = 1.0 + 0.12 * sin(ghostPhase);

        // Outer ghostly cloak — large soft blur
        canvas.drawCircle(
          Offset.zero,
          r * 1.6 * breathe,
          Paint()
            ..color = eColor.withValues(alpha: 0.06 + 0.03 * sin(ghostPhase))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8),
        );

        // Main body — translucent oval
        canvas.save();
        canvas.scale(0.8, 1.1 * breathe);
        canvas.drawCircle(
          Offset.zero,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(-r * 0.15, -r * 0.2),
              r * 1.2,
              [
                Colors.white.withValues(alpha: 0.25),
                eColor.withValues(alpha: 0.18),
                eColor.withValues(alpha: 0.04),
              ],
              [0.0, 0.4, 1.0],
            ),
        );
        canvas.restore();

        // Wispy tendrils trailing downward
        for (var t = 0; t < 4; t++) {
          final tAngle = t * pi / 2 + ghostPhase * 0.3;
          final tLen = r * (1.5 + 0.4 * sin(ghostPhase + t * 1.5));
          final tendril = Path()
            ..moveTo(cos(tAngle) * r * 0.4, sin(tAngle) * r * 0.4);

          final ctrlX = cos(tAngle + 0.3 * sin(ghostPhase + t)) * r * 1.0;
          final ctrlY = sin(tAngle + 0.3 * sin(ghostPhase + t)) * r * 1.0;
          tendril.quadraticBezierTo(
            ctrlX,
            ctrlY,
            cos(tAngle) * tLen,
            sin(tAngle) * tLen,
          );

          canvas.drawPath(
            tendril,
            Paint()
              ..color = eColor.withValues(
                alpha: 0.15 + 0.08 * sin(ghostPhase + t * 2),
              )
              ..strokeWidth = 1.5
              ..style = PaintingStyle.stroke
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }

        // Hollow eyes — two dim points
        final eyeSpread = r * 0.25;
        final eyeY = -r * 0.15;
        for (final ex in [-eyeSpread, eyeSpread]) {
          canvas.drawCircle(
            Offset(ex, eyeY),
            r * 0.1,
            Paint()
              ..color = Colors.white.withValues(
                alpha: 0.4 + 0.2 * sin(ghostPhase * 2),
              )
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
          );
        }
      } else if (e.tier == EnemyTier.colossus) {
        // Colossi: massive armored body with tentacle appendages + HP bar
        final r = e.radius;
        final pulse = 0.95 + 0.05 * sin(_elapsed * 1.2 + e.angle);

        // Armored core — large dark sphere with elemental tint
        canvas.drawCircle(
          Offset.zero,
          r * pulse,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(-r * 0.3, -r * 0.3),
              r * 1.5,
              [
                Color.lerp(eColor, Colors.white, 0.15)!.withValues(alpha: 0.85),
                Color.lerp(eColor, Colors.black, 0.3)!.withValues(alpha: 0.8),
                Colors.black.withValues(alpha: 0.7),
              ],
              [0.0, 0.4, 1.0],
            ),
        );

        // Tentacle appendages radiating outward
        for (var t = 0; t < 6; t++) {
          final baseAngle = t * pi / 3 + _elapsed * 0.08;
          final wave = sin(_elapsed * 1.5 + t * 1.2) * 0.3;
          final tentacle = Path()
            ..moveTo(cos(baseAngle) * r * 0.8, sin(baseAngle) * r * 0.8);

          final midDist = r * 1.6;
          final tipDist = r * (2.2 + 0.3 * sin(_elapsed * 0.8 + t));
          final ctrlAngle = baseAngle + wave;
          tentacle.quadraticBezierTo(
            cos(ctrlAngle) * midDist,
            sin(ctrlAngle) * midDist,
            cos(baseAngle + wave * 0.5) * tipDist,
            sin(baseAngle + wave * 0.5) * tipDist,
          );

          canvas.drawPath(
            tentacle,
            Paint()
              ..color = eColor.withValues(
                alpha: 0.35 + 0.15 * sin(_elapsed + t),
              )
              ..strokeWidth = 2.5 - t * 0.2
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }

        // Central maw — glowing core
        canvas.drawCircle(
          Offset.zero,
          r * 0.35,
          Paint()
            ..color = eColor.withValues(alpha: 0.4 + 0.2 * sin(_elapsed * 2))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.2),
        );
        canvas.drawCircle(
          Offset.zero,
          r * 0.15,
          Paint()..color = Colors.white.withValues(alpha: 0.5),
        );

        // Heavy pulsing aura
        canvas.drawCircle(
          Offset.zero,
          r * 1.5,
          Paint()
            ..color = eColor.withValues(alpha: 0.05)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
        );

        // Health bar (colossi are very tanky)
        final levHpFrac = (e.health / e.maxHealth).clamp(0.0, 1.0);
        if (levHpFrac < 1.0) {
          final barW = r * 3.0;
          final barH = 4.0;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(0, -r - 10),
                width: barW,
                height: barH,
              ),
              const Radius.circular(2),
            ),
            Paint()..color = Colors.black.withValues(alpha: 0.6),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                -barW / 2,
                -r - 10 - barH / 2,
                barW * levHpFrac,
                barH,
              ),
              const Radius.circular(2),
            ),
            Paint()..color = Color.lerp(Colors.red, eColor, levHpFrac)!,
          );
        }
      } else if (e.tier == EnemyTier.brute) {
        // Brutes: heavy armored body with elemental cracks
        final r = e.radius;

        // Dark armored body
        canvas.drawCircle(
          Offset.zero,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(-r * 0.2, -r * 0.2),
              r * 1.3,
              [
                Color.lerp(eColor, Colors.black, 0.3)!.withValues(alpha: 0.9),
                Color.lerp(eColor, Colors.black, 0.6)!.withValues(alpha: 0.8),
                Colors.black.withValues(alpha: 0.7),
              ],
              [0.0, 0.5, 1.0],
            ),
        );

        // Elemental cracks glowing through armor
        for (var crack = 0; crack < 5; crack++) {
          final ca = crack * pi * 2 / 5 + _elapsed * 0.2;
          final crackPath = Path()
            ..moveTo(0, 0)
            ..lineTo(cos(ca) * r * 0.9, sin(ca) * r * 0.9);
          canvas.drawPath(
            crackPath,
            Paint()
              ..color = eColor.withValues(
                alpha: 0.6 + 0.2 * sin(_elapsed * 2 + crack),
              )
              ..strokeWidth = 2.0
              ..style = PaintingStyle.stroke
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }

        // Heavy pulsing aura
        canvas.drawCircle(
          Offset.zero,
          r * 1.3,
          Paint()
            ..color = eColor.withValues(alpha: 0.08)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5),
        );

        // Health bar (brutes are tanky)
        final bruteHpFrac = (e.health / e.maxHealth).clamp(0.0, 1.0);
        if (bruteHpFrac < 1.0) {
          final barW = r * 2.5;
          final barH = 3.0;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(0, -r - 8),
                width: barW,
                height: barH,
              ),
              const Radius.circular(1.5),
            ),
            Paint()..color = Colors.black.withValues(alpha: 0.6),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                -barW / 2,
                -r - 8 - barH / 2,
                barW * bruteHpFrac,
                barH,
              ),
              const Radius.circular(1.5),
            ),
            Paint()..color = Color.lerp(Colors.red, eColor, bruteHpFrac)!,
          );
        }
      }

      canvas.restore();
    }

    // ── boss lairs (waiting markers) ──
    for (final lair in bossLairs) {
      if (lair.state != BossLairState.waiting) continue;
      final lp = lair.position;
      if ((lp.dx - cx - screenW / 2).abs() > screenW * 1.5 ||
          (lp.dy - cy - screenH / 2).abs() > screenH * 1.5) {
        continue;
      }

      final lColor = elementColor(lair.template.element);
      final pulse = 0.5 + 0.3 * sin(_elapsed * 2.0);

      // Ominous aura
      canvas.drawCircle(
        Offset(lp.dx, lp.dy),
        BossLair.activationRadius * 0.4,
        Paint()
          ..color = const Color(0xFFFF1744).withValues(alpha: 0.06 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
      );

      // Rotating diamond shape
      canvas.save();
      canvas.translate(lp.dx, lp.dy);
      canvas.rotate(_elapsed * 0.5);
      final diamondPath = Path()
        ..moveTo(0, -18)
        ..lineTo(14, 0)
        ..lineTo(0, 18)
        ..lineTo(-14, 0)
        ..close();
      canvas.drawPath(
        diamondPath,
        Paint()..color = lColor.withValues(alpha: 0.25 * pulse),
      );
      canvas.drawPath(
        diamondPath,
        Paint()
          ..color = const Color(0xFFFF1744).withValues(alpha: 0.4 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.restore();

      // Inner glow dot
      canvas.drawCircle(
        Offset(lp.dx, lp.dy),
        6,
        Paint()
          ..color = const Color(0xFFFF1744).withValues(alpha: 0.5 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        Offset(lp.dx, lp.dy),
        3,
        Paint()..color = lColor.withValues(alpha: 0.7),
      );

      // Level label
      final lairLabel = TextPainter(
        text: TextSpan(
          text: 'Lv${lair.level} ${lair.template.name}',
          style: TextStyle(
            color: const Color(0xFFFF5252).withValues(alpha: 0.7 * pulse),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      lairLabel.paint(canvas, Offset(lp.dx - lairLabel.width / 2, lp.dy + 22));
    }

    // ── boss ──
    if (activeBoss != null && !activeBoss!.dead) {
      final boss = activeBoss!;
      final bp = boss.position;
      if ((bp.dx - cx - screenW / 2).abs() < screenW * 1.2 &&
          (bp.dy - cy - screenH / 2).abs() < screenH * 1.2) {
        final bColor = elementColor(boss.element);

        canvas.save();
        canvas.translate(bp.dx, bp.dy);

        // Outer aura — breathing glow (warden enrage turns it red)
        final pulse = 0.8 + 0.2 * sin(_elapsed * 2.5);
        final auraColor = (boss.enraged)
            ? Color.lerp(bColor, Colors.red, 0.6)!
            : bColor;
        canvas.drawCircle(
          Offset.zero,
          boss.radius * 3.0 * pulse,
          Paint()
            ..color = auraColor.withValues(alpha: boss.enraged ? 0.12 : 0.06)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, boss.radius * 1.5),
        );
        // Secondary aura ring
        canvas.drawCircle(
          Offset.zero,
          boss.radius * 2.0 * pulse,
          Paint()
            ..color = auraColor.withValues(alpha: boss.enraged ? 0.15 : 0.08)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, boss.radius * 0.8),
        );

        // ── Charger: directional wedge indicator + charge trail ──
        if (boss.type == BossType.charger) {
          canvas.save();
          canvas.rotate(boss.angle);
          // Pointed wedge in front
          final wedge = Path()
            ..moveTo(boss.radius * 1.5, 0)
            ..lineTo(boss.radius * 0.4, -boss.radius * 0.5)
            ..lineTo(boss.radius * 0.4, boss.radius * 0.5)
            ..close();
          canvas.drawPath(
            wedge,
            Paint()
              ..color = bColor.withValues(alpha: boss.charging ? 0.8 : 0.3)
              ..maskFilter = boss.charging
                  ? const MaskFilter.blur(BlurStyle.normal, 4)
                  : null,
          );
          // Charge trail glow behind boss when dashing
          if (boss.charging) {
            canvas.drawCircle(
              Offset(-boss.radius * 1.5, 0),
              boss.radius * 0.8,
              Paint()
                ..color = bColor.withValues(alpha: 0.4)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
            );
          }
          canvas.restore();
        }

        // ── Gunner: shield ring ──
        if (boss.type == BossType.gunner && boss.shieldUp) {
          final shieldAlpha = (boss.shieldHealth / CosmicBoss.shieldMaxHealth)
              .clamp(0.0, 1.0);
          canvas.drawCircle(
            Offset.zero,
            boss.radius * 1.6,
            Paint()
              ..color = Colors.cyanAccent.withValues(alpha: 0.2 * shieldAlpha)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
          canvas.drawCircle(
            Offset.zero,
            boss.radius * 1.4,
            Paint()
              ..color = Colors.cyanAccent.withValues(alpha: 0.5 * shieldAlpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0,
          );
        }

        // Orbiting rune motes
        final moteCount = switch (boss.type) {
          BossType.charger => 4,
          BossType.gunner => 6,
          BossType.warden => 8,
        };
        for (var i = 0; i < moteCount; i++) {
          final moteA = _elapsed * 1.2 + i * pi * 2 / moteCount;
          final moteR = boss.radius * (1.3 + 0.15 * sin(_elapsed * 3 + i));
          final mp = Offset(cos(moteA) * moteR, sin(moteA) * moteR);
          canvas.drawCircle(
            mp,
            2.5,
            Paint()
              ..color = (boss.enraged ? Colors.red : bColor).withValues(
                alpha: 0.7,
              )
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }

        // Core body — radial gradient orb
        canvas.drawCircle(
          Offset.zero,
          boss.radius,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(-boss.radius * 0.2, -boss.radius * 0.2),
              boss.radius * 1.1,
              [
                Colors.white.withValues(alpha: 0.5 * pulse),
                Color.lerp(
                  bColor,
                  Colors.white,
                  0.2,
                )!.withValues(alpha: 0.8 * pulse),
                bColor.withValues(alpha: 0.6 * pulse),
                bColor.withValues(alpha: 0.0),
              ],
              [0.0, 0.25, 0.6, 1.0],
            ),
        );

        // Inner sigil — type determines complexity
        canvas.save();
        canvas.rotate(_elapsed * 0.6);
        final sigR = boss.radius * 0.55;
        canvas.drawCircle(
          Offset.zero,
          sigR,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
        // Star points scale with type
        final starPoints = switch (boss.type) {
          BossType.charger => 5,
          BossType.gunner => 7,
          BossType.warden => 9,
        };
        final sigPath = Path();
        for (var i = 0; i < starPoints; i++) {
          final a1 = i * pi * 2 / starPoints - pi / 2;
          final a2 = a1 + pi * 2 / starPoints * 3;
          final p1 = Offset(cos(a1) * sigR, sin(a1) * sigR);
          final p2 = Offset(cos(a2) * sigR, sin(a2) * sigR);
          sigPath.moveTo(p1.dx, p1.dy);
          sigPath.lineTo(p2.dx, p2.dy);
        }
        canvas.drawPath(
          sigPath,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
        // Warden: second inner inscribed ring when enraged
        if (boss.type == BossType.warden && boss.enraged) {
          canvas.drawCircle(
            Offset.zero,
            sigR * 0.6,
            Paint()
              ..color = Colors.red.withValues(alpha: 0.3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
        canvas.restore();

        // Health bar above boss
        final barWidth = boss.radius * 2.5;
        final barHeight = 4.0;
        final barY = -boss.radius - 14.0;
        final hpFrac = (boss.health / boss.maxHealth).clamp(0.0, 1.0);

        // Background
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(0, barY),
              width: barWidth,
              height: barHeight,
            ),
            const Radius.circular(2),
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.6),
        );
        // Fill
        final fillW = barWidth * hpFrac;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              -barWidth / 2,
              barY - barHeight / 2,
              fillW,
              barHeight,
            ),
            const Radius.circular(2),
          ),
          Paint()..color = Color.lerp(Colors.red, bColor, hpFrac)!,
        );

        // Boss name + level + type
        final typeTag = switch (boss.type) {
          BossType.charger => '⚡',
          BossType.gunner => '🔫',
          BossType.warden => '👑',
        };
        final namePainter = TextPainter(
          text: TextSpan(
            text: '$typeTag Lv${boss.level} ${boss.name}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        namePainter.paint(
          canvas,
          Offset(-namePainter.width / 2, barY - barHeight - 14),
        );

        canvas.restore();
      }
    }

    // ── boss projectiles ──
    for (final bp in bossProjectiles) {
      final pp = bp.position;
      if ((pp.dx - cx - screenW / 2).abs() > screenW ||
          (pp.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }

      final bpColor = elementColor(bp.element);
      // Glow
      canvas.drawCircle(
        pp,
        bp.radius * 2.5,
        Paint()
          ..color = bpColor.withValues(alpha: 0.25)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, bp.radius * 2),
      );
      // Core
      canvas.drawCircle(pp, bp.radius, Paint()..color = bpColor);
      // Bright center
      canvas.drawCircle(
        pp,
        bp.radius * 0.4,
        Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
    }

    // ── projectiles ──
    for (final p in projectiles) {
      final pp = p.position;
      if ((pp.dx - cx - screenW / 2).abs() > screenW ||
          (pp.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }

      // Ammo color based on active customization
      final ammoColor = _ammoColor;
      // Glow trail
      canvas.drawCircle(
        pp,
        6,
        Paint()
          ..color = ammoColor.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Core bolt
      final tailX = pp.dx - cos(p.angle) * 10;
      final tailY = pp.dy - sin(p.angle) * 10;
      canvas.drawLine(
        Offset(tailX, tailY),
        pp,
        Paint()
          ..color = ammoColor
          ..strokeWidth = activeWeaponId == 'equip_machinegun' ? 1.5 : 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── homing missiles ──
    for (final m in _missiles) {
      final mp = m.position;
      if ((mp.dx - cx - screenW / 2).abs() > screenW ||
          (mp.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }
      // Missile glow
      canvas.drawCircle(
        mp,
        10,
        Paint()
          ..color = const Color(0xFFFF6F00).withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      // Missile body (small triangle)
      canvas.save();
      canvas.translate(mp.dx, mp.dy);
      canvas.rotate(m.angle + pi / 2);
      final missilePath = Path()
        ..moveTo(0, -6)
        ..lineTo(-3, 4)
        ..lineTo(3, 4)
        ..close();
      canvas.drawPath(missilePath, Paint()..color = const Color(0xFFFF8F00));
      // Exhaust trail
      canvas.drawCircle(
        const Offset(0, 6),
        3,
        Paint()
          ..color = const Color(0xFFFFAB40).withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.restore();
    }

    // ── orbital sentinels ──
    for (final o in orbitals) {
      final op = o.positionAround(ship.pos);
      final a = o.spawnOpacity; // fade-in alpha
      // Outer glow
      canvas.drawCircle(
        op,
        OrbitalSentinel.hitboxRadius,
        Paint()
          ..color = const Color(0xFF42A5F5).withValues(alpha: 0.15 * a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      // Core
      canvas.drawCircle(
        op,
        OrbitalSentinel.hitboxRadius * 0.6,
        Paint()..color = const Color(0xFF42A5F5).withValues(alpha: 0.7 * a),
      );
      // Inner bright dot
      canvas.drawCircle(
        op,
        3,
        Paint()..color = const Color(0xFFBBDEFB).withValues(alpha: a),
      );
    }

    // ── companion projectiles ──
    for (final cp in companionProjectiles) {
      final cpp = cp.position;
      if ((cpp.dx - cx - screenW / 2).abs() > screenW ||
          (cpp.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }
      final projColor = cp.element != null
          ? elementColor(cp.element!)
          : const Color(0xFF42A5F5);
      final vs = cp.visualScale;

      if (cp.decoy && cp.decoyHp > 0) {
        // ── Decoy totem rendering (Mask decoys that enemies target) ──
        final pulse = 0.7 + 0.3 * sin(cp.life * 4.0);
        final totemR = 8.0 * vs;
        // Aggro aura: large pulsing ring that draws enemies
        canvas.drawCircle(
          cpp,
          totemR * 3.0 * pulse,
          Paint()
            ..color = projColor.withValues(alpha: 0.08)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, totemR * 2),
        );
        // Outer diamond shape (rotating)
        final rotAngle = cp.life * 2.0;
        final path = Path();
        for (var j = 0; j < 4; j++) {
          final da = rotAngle + j * (pi / 2);
          final pt = Offset(
            cpp.dx + cos(da) * totemR * 1.2,
            cpp.dy + sin(da) * totemR * 1.2,
          );
          if (j == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()..color = projColor.withValues(alpha: 0.4 * pulse),
        );
        // Inner core
        canvas.drawCircle(
          cpp,
          totemR * 0.5,
          Paint()..color = projColor.withValues(alpha: 0.85),
        );
        // Bright center pip
        canvas.drawCircle(
          cpp,
          totemR * 0.2,
          Paint()..color = Color.lerp(projColor, const Color(0xFFFFFFFF), 0.8)!,
        );
      } else if (cp.piercing && vs >= 1.5) {
        // ── Beam-style rendering (Crystal, Lightning piercing) ──
        final tailLen = 16.0 * vs;
        final tailX = cpp.dx - cos(cp.angle) * tailLen;
        final tailY = cpp.dy - sin(cp.angle) * tailLen;
        // Outer glow
        canvas.drawLine(
          Offset(tailX, tailY),
          cpp,
          Paint()
            ..color = projColor.withValues(alpha: 0.3)
            ..strokeWidth = 6.0 * vs
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        // Core beam
        canvas.drawLine(
          Offset(tailX, tailY),
          cpp,
          Paint()
            ..color = projColor
            ..strokeWidth = 3.0 * vs
            ..strokeCap = StrokeCap.round,
        );
        // Bright tip
        canvas.drawCircle(
          cpp,
          3.0 * vs,
          Paint()..color = Color.lerp(projColor, const Color(0xFFFFFFFF), 0.6)!,
        );
      } else if (cp.homing) {
        // ── Homing orb rendering (Spirit, Blood) ──
        // Pulsating outer glow
        final pulse = 0.6 + 0.4 * sin(cp.life * 8.0);
        canvas.drawCircle(
          cpp,
          10.0 * vs * pulse,
          Paint()
            ..color = projColor.withValues(alpha: 0.2)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
        // Inner orb
        canvas.drawCircle(
          cpp,
          5.0 * vs,
          Paint()..color = projColor.withValues(alpha: 0.85),
        );
        // Bright center
        canvas.drawCircle(
          cpp,
          2.5 * vs,
          Paint()..color = Color.lerp(projColor, const Color(0xFFFFFFFF), 0.7)!,
        );
      } else if (vs >= 1.6 && cp.speedMultiplier < 0.5) {
        // ── Cloud/AoE rendering (Steam, Ice nova, Mud) ──
        final cloudR = 8.0 * vs;
        canvas.drawCircle(
          cpp,
          cloudR,
          Paint()
            ..color = projColor.withValues(alpha: 0.18)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, cloudR * 0.8),
        );
        canvas.drawCircle(
          cpp,
          cloudR * 0.5,
          Paint()
            ..color = projColor.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      } else if (cp.stationary) {
        // ── Mine/trap rendering (Mask specials, lingering zones) ──
        final pulse = 0.7 + 0.3 * sin(cp.life * 6.0);
        final mineR = 6.0 * vs;
        // Danger zone glow
        canvas.drawCircle(
          cpp,
          mineR * 1.5,
          Paint()
            ..color = projColor.withValues(alpha: 0.12 * pulse)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, mineR),
        );
        // Mine body
        canvas.drawCircle(
          cpp,
          mineR * 0.6,
          Paint()..color = projColor.withValues(alpha: 0.7 * pulse),
        );
        // Warning pip
        canvas.drawCircle(
          cpp,
          mineR * 0.25,
          Paint()
            ..color = Color.lerp(
              projColor,
              const Color(0xFFFFFFFF),
              0.8,
            )!.withValues(alpha: pulse),
        );
      } else if (cp.orbitCenter != null) {
        // ── Orbital rendering (Mystic/Kin orbiting projectiles) ──
        final pulse = 0.8 + 0.2 * sin(cp.orbitAngle * 3);
        // Orbit trail
        canvas.drawCircle(
          cpp,
          5.0 * vs * pulse,
          Paint()
            ..color = projColor.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        // Core orb
        canvas.drawCircle(
          cpp,
          3.5 * vs,
          Paint()..color = projColor.withValues(alpha: 0.9),
        );
        // Bright center
        canvas.drawCircle(
          cpp,
          1.5 * vs,
          Paint()..color = Color.lerp(projColor, const Color(0xFFFFFFFF), 0.7)!,
        );
      } else {
        // ── Standard bolt rendering (with visual scale) ──
        final glowR = 8.0 * vs;
        final tailLen = 8.0 * vs;
        // Glow trail
        canvas.drawCircle(
          cpp,
          glowR,
          Paint()
            ..color = projColor.withValues(alpha: 0.25)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6.0 * vs),
        );
        // Core bolt
        final tailX = cpp.dx - cos(cp.angle) * tailLen;
        final tailY = cpp.dy - sin(cp.angle) * tailLen;
        canvas.drawLine(
          Offset(tailX, tailY),
          cpp,
          Paint()
            ..color = projColor
            ..strokeWidth = (cp.damage > 10 ? 3.0 : 2.0) * vs
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // ── companion ──
    if (activeCompanion != null && activeCompanion!.isAlive) {
      final comp = activeCompanion!;
      final compPos = comp.position;
      final eColor = elementColor(comp.member.element);

      // Animation timing
      const summonDur = 0.7; // summon animation duration
      const retreatDur = 0.6;
      final isSummoning = comp.life < summonDur && !comp.returning;
      final summonT = isSummoning
          ? (comp.life / summonDur).clamp(0.0, 1.0)
          : 1.0;
      final retreatT = comp.returning
          ? (comp.returnTimer / retreatDur).clamp(0.0, 1.0)
          : 1.0;

      // Ease curves
      final summonScale =
          (isSummoning ? Curves.elasticOut.transform(summonT) : 1.0) *
          _beautyContestCompVisualScale;
      final retreatScale = comp.returning
          ? Curves.easeInBack.transform(retreatT)
          : 1.0;
      final animScale = summonScale * retreatScale;
      final opacity = comp.returning ? retreatT : 1.0;

      canvas.save();
      canvas.translate(compPos.dx, compPos.dy);

      // ── Summon VFX: expanding ring + converging particles ──
      if (isSummoning) {
        // Expanding flash ring
        final ringRadius = 12.0 + summonT * 60.0;
        final ringAlpha = (1.0 - summonT) * 0.7;
        canvas.drawCircle(
          Offset.zero,
          ringRadius,
          Paint()
            ..color = eColor.withValues(alpha: ringAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0 * (1.0 - summonT) + 0.5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        // Inner flash glow
        canvas.drawCircle(
          Offset.zero,
          20 * summonT,
          Paint()
            ..color = Colors.white.withValues(alpha: (1.0 - summonT) * 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
        // Converging particle dots (6 swirling inward)
        for (var i = 0; i < 6; i++) {
          final pAngle = (i / 6) * pi * 2 + comp.life * 8;
          final pDist = 50.0 * (1.0 - summonT);
          final px = cos(pAngle) * pDist;
          final py = sin(pAngle) * pDist;
          canvas.drawCircle(
            Offset(px, py),
            2.5 * (1.0 - summonT * 0.5),
            Paint()..color = eColor.withValues(alpha: (1.0 - summonT) * 0.8),
          );
        }
      }

      // ── Retreat VFX: dispersing particles + shrinking ring ──
      if (comp.returning) {
        // Shrinking ring
        final ringRadius = 40.0 * retreatT;
        final ringAlpha = retreatT * 0.5;
        canvas.drawCircle(
          Offset.zero,
          ringRadius,
          Paint()
            ..color = eColor.withValues(alpha: ringAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 * retreatT + 0.5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        // Dispersing particles (8 flying outward)
        for (var i = 0; i < 8; i++) {
          final pAngle = (i / 8) * pi * 2 + _elapsed * 3;
          final pDist = 15.0 + 60.0 * (1.0 - retreatT);
          final px = cos(pAngle) * pDist;
          final py = sin(pAngle) * pDist;
          canvas.drawCircle(
            Offset(px, py),
            2.0 * retreatT,
            Paint()..color = eColor.withValues(alpha: retreatT * 0.6),
          );
        }
      }

      // Outer aura glow
      final auraPulse = 0.5 + 0.3 * sin(_elapsed * 3.0);
      canvas.drawCircle(
        Offset.zero,
        28 * animScale,
        Paint()
          ..color = eColor.withValues(alpha: auraPulse * 0.3 * opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );

      // ── Shield bubble (Horn special) ──
      if (comp.hasShield) {
        final shieldPulse = 0.6 + 0.3 * sin(_elapsed * 5.0);
        // Outer shield ring
        canvas.drawCircle(
          Offset.zero,
          32 * animScale,
          Paint()
            ..color = eColor.withValues(alpha: shieldPulse * 0.4 * opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        // Inner shield fill
        canvas.drawCircle(
          Offset.zero,
          30 * animScale,
          Paint()
            ..color = eColor.withValues(alpha: 0.15 * opacity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }

      // ── Charge trail (Horn charging) ──
      if (comp.isCharging) {
        for (var t = 0; t < 5; t++) {
          final trailAngle = comp.angle + pi; // behind companion
          final trailDist = 8.0 + t * 8.0;
          final tAlpha = (1.0 - t / 5.0) * 0.5 * opacity;
          canvas.drawCircle(
            Offset(cos(trailAngle) * trailDist, sin(trailAngle) * trailDist),
            (5.0 - t) * animScale,
            Paint()
              ..color = eColor.withValues(alpha: tAlpha)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
      }

      // ── Blessing aura (Kin healing) ──
      if (comp.isBlessing) {
        final blessingPulse = 0.5 + 0.4 * sin(_elapsed * 4.0);
        // Approximate a soft glow without MaskFilter.blur for performance by
        // drawing several concentric stroked rings with decreasing alpha and
        // increasing stroke width. This avoids expensive mask blurs on some
        // platforms while preserving a soft aura look (similar to prismatic
        // optimizations elsewhere).
        // Increase brightness: raise base alpha and widen rings for stronger
        // visual presence while still avoiding MaskFilter.blur.
        final baseAlpha = blessingPulse * 0.65 * opacity;
        final centerR = 24 * animScale;

        // When the pulse is at its brightest, draw a solid, more-inset
        // filled core to produce a very solid color. Otherwise, draw the
        // multi-ring approximation used for the softer glow.
        final isPeak = blessingPulse > 0.82;
        if (isPeak) {
          // Strong, solid core at peak
          canvas.drawCircle(
            Offset.zero,
            centerR * 0.48,
            Paint()
              ..color = Colors.greenAccent.withValues(
                alpha: (baseAlpha * 1.7).clamp(0.0, 1.0),
              ),
          );
        } else {
          // Bright core fill for punch
          canvas.drawCircle(
            Offset.zero,
            centerR * 0.22,
            Paint()
              ..color = Colors.greenAccent.withValues(alpha: baseAlpha * 0.95),
          );

          // Core thin ring (more visible)
          canvas.drawCircle(
            Offset.zero,
            centerR,
            Paint()
              ..color = Colors.greenAccent.withValues(alpha: baseAlpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.0,
          );

          // Wider, stronger rings to emulate a brighter glow
          canvas.drawCircle(
            Offset.zero,
            centerR,
            Paint()
              ..color = Colors.greenAccent.withValues(alpha: baseAlpha * 0.85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8.0,
          );
          canvas.drawCircle(
            Offset.zero,
            centerR,
            Paint()
              ..color = Colors.greenAccent.withValues(alpha: baseAlpha * 0.55)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 18.0,
          );
        }

        // Floating + particles
        for (var p = 0; p < 4; p++) {
          final pAng = (p / 4) * pi * 2 + _elapsed * 2;
          final pDist = 18.0 + 4 * sin(_elapsed * 3 + p);
          canvas.drawCircle(
            Offset(cos(pAng) * pDist, sin(pAng) * pDist),
            2.5,
            Paint()
              ..color = Colors.greenAccent.withValues(alpha: 0.6 * opacity),
          );
        }
      }

      // Render sprite if loaded, otherwise fallback to circles
      if (_companionTicker != null) {
        final sprite = _companionTicker!.getSprite();
        final paint = Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..filterQuality = ui.FilterQuality.high;

        // Apply genetics color filter if visuals available
        if (_companionVisuals != null) {
          final v = _companionVisuals!;
          final isAlbino = v.brightness == 1.45 && !v.isPrismatic;
          if (isAlbino) {
            paint.colorFilter = _albinoColorFilter(v.brightness);
          } else {
            paint.colorFilter = _geneticsColorFilter(v);
          }
        }

        // Simple canvas-based effect overlays for companion (behind sprite)
        if (_companionVisuals?.alchemyEffect != null) {
          final companionScale = _companionSpriteScale * animScale;
          _drawAlchemyEffectCanvas(
            canvas: canvas,
            effect: _companionVisuals!.alchemyEffect!,
            spriteScale: companionScale,
            baseSpriteSize: 48.0,
            variantFaction: _companionVisuals?.variantFaction,
            elapsed: _elapsed,
            opacity: opacity,
          );
        }

        // Flip sprite horizontally to face shooting direction
        // Default sprites face left; flip when target is to the right
        final facingRight = cos(comp.angle) > 0;
        final totalScale = _companionSpriteScale * animScale;
        canvas.save();
        if (facingRight) {
          canvas.scale(-totalScale, totalScale);
        } else {
          canvas.scale(totalScale);
        }
        sprite.render(canvas, anchor: Anchor.center, overridePaint: paint);
        canvas.restore();
      } else {
        // Fallback: colored circle
        canvas.drawCircle(
          Offset.zero,
          14 * animScale,
          Paint()..color = eColor.withValues(alpha: 0.85 * opacity),
        );
        canvas.drawCircle(
          Offset.zero,
          6 * animScale,
          Paint()..color = Colors.white.withValues(alpha: 0.9 * opacity),
        );
      }

      // Health bar above companion (only show after summon animation,
      // but hidden during contest cinematics).
      if (!isSummoning && !_beautyContestCinematicActive) {
        final hpW = 30.0;
        final hpH = 3.0;
        final hpX = -hpW / 2;
        final hpY = -30.0;
        // BG
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(hpX, hpY, hpW, hpH),
            const Radius.circular(2),
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.5 * opacity),
        );
        // Fill
        final hpFill = comp.hpPercent.clamp(0.0, 1.0);
        final hpColor = hpFill > 0.5
            ? Color.lerp(Colors.yellow, Colors.green, (hpFill - 0.5) * 2)!
            : Color.lerp(Colors.red, Colors.yellow, hpFill * 2)!;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(hpX, hpY, hpW * hpFill, hpH),
            const Radius.circular(2),
          ),
          Paint()..color = hpColor.withValues(alpha: opacity),
        );
      }

      // Invincibility flash overlay
      if (comp.invincibleTimer > 0 &&
          !isSummoning &&
          !_beautyContestCinematicActive) {
        final flash = sin(_elapsed * 20) > 0 ? 0.4 : 0.0;
        canvas.drawCircle(
          Offset.zero,
          14 * animScale,
          Paint()..color = Colors.white.withValues(alpha: flash * opacity),
        );
      }

      canvas.restore();
    }

    // ── battle ring opponent ──
    if (battleRingOpponent != null && battleRingOpponent!.isAlive) {
      final opp = battleRingOpponent!;
      final oppPos = opp.position;
      final eColor = elementColor(opp.member.element);

      const summonDur = 1.0;
      final isSummoning = opp.life < summonDur;
      final summonT = isSummoning
          ? (opp.life / summonDur).clamp(0.0, 1.0)
          : 1.0;
      final summonScale =
          (isSummoning ? Curves.elasticOut.transform(summonT) : 1.0) *
          _beautyContestOppVisualScale;

      canvas.save();
      canvas.translate(oppPos.dx, oppPos.dy);

      // Summon VFX: portal-like arrival
      if (isSummoning) {
        final ringRadius = 12.0 + summonT * 80.0;
        final ringAlpha = (1.0 - summonT) * 0.7;
        canvas.drawCircle(
          Offset.zero,
          ringRadius,
          Paint()
            ..color = const Color(0xFFFF4040).withValues(alpha: ringAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0 * (1.0 - summonT) + 0.5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        for (var i = 0; i < 8; i++) {
          final pAngle = (i / 8) * pi * 2 + opp.life * 6;
          final pDist = 60.0 * (1.0 - summonT);
          final px = cos(pAngle) * pDist;
          final py = sin(pAngle) * pDist;
          canvas.drawCircle(
            Offset(px, py),
            3.0 * (1.0 - summonT * 0.5),
            Paint()..color = eColor.withValues(alpha: (1.0 - summonT) * 0.8),
          );
        }
      }

      // Red-tinted aura glow (enemy)
      final auraPulse = 0.5 + 0.3 * sin(_elapsed * 3.0);
      canvas.drawCircle(
        Offset.zero,
        28 * summonScale,
        Paint()
          ..color = const Color(0xFFFF4040).withValues(alpha: auraPulse * 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );

      // Render sprite
      if (_ringOpponentTicker != null) {
        final sprite = _ringOpponentTicker!.getSprite();
        final paint = Paint()
          ..color = Colors.white
          ..filterQuality = ui.FilterQuality.high;

        if (_ringOpponentVisuals != null) {
          final v = _ringOpponentVisuals!;
          final isAlbino = v.brightness == 1.45 && !v.isPrismatic;
          if (isAlbino) {
            paint.colorFilter = _albinoColorFilter(v.brightness);
          } else {
            paint.colorFilter = _geneticsColorFilter(v);
          }
        }

        // Simple effect overlays for ring opponent (behind sprite)
        if (_ringOpponentVisuals?.alchemyEffect != null) {
          final opponentScale = _ringOpponentSpriteScale * summonScale;
          _drawAlchemyEffectCanvas(
            canvas: canvas,
            effect: _ringOpponentVisuals!.alchemyEffect!,
            spriteScale: opponentScale,
            baseSpriteSize: 48.0,
            variantFaction: _ringOpponentVisuals?.variantFaction,
            elapsed: _elapsed,
            opacity: 0.95,
          );
        }

        final facingRight = cos(opp.angle) > 0;
        final totalScale = _ringOpponentSpriteScale * summonScale;
        canvas.save();
        if (facingRight) {
          canvas.scale(-totalScale, totalScale);
        } else {
          canvas.scale(totalScale);
        }
        sprite.render(canvas, anchor: Anchor.center, overridePaint: paint);
        canvas.restore();
      } else if (_ringOpponentFallbackSprite != null) {
        final paint = Paint()
          ..color = Colors.white
          ..filterQuality = ui.FilterQuality.high;
        final totalScale = _ringOpponentFallbackScale * summonScale;
        canvas.save();
        canvas.scale(totalScale);
        _ringOpponentFallbackSprite!.render(
          canvas,
          anchor: Anchor.center,
          overridePaint: paint,
        );
        canvas.restore();
      } else {
        // Fallback: red-tinted circle
        canvas.drawCircle(
          Offset.zero,
          14 * summonScale,
          Paint()..color = eColor.withValues(alpha: 0.85),
        );
        canvas.drawCircle(
          Offset.zero,
          6 * summonScale,
          Paint()..color = const Color(0xFFFF6060).withValues(alpha: 0.9),
        );
      }

      // HP bar (red-tinted for opponent), hidden during contest cinematics.
      if (!isSummoning && !_beautyContestCinematicActive) {
        final hpW = 30.0;
        final hpH = 3.0;
        final hpX = -hpW / 2;
        final hpY = -30.0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(hpX, hpY, hpW, hpH),
            const Radius.circular(2),
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.5),
        );
        final hpFill = opp.hpPercent.clamp(0.0, 1.0);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(hpX, hpY, hpW * hpFill, hpH),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFFFF4040),
        );
      }

      // Invincibility flash
      if (opp.invincibleTimer > 0 &&
          !isSummoning &&
          !_beautyContestCinematicActive) {
        final flash = sin(_elapsed * 20) > 0 ? 0.4 : 0.0;
        canvas.drawCircle(
          Offset.zero,
          14 * summonScale,
          Paint()..color = Colors.white.withValues(alpha: flash),
        );
      }

      canvas.restore();
    }

    // ── render ring opponent projectiles ──
    for (final rp in ringOpponentProjectiles) {
      final rpPos = rp.position;
      final projColor = elementColor(
        battleRingOpponent?.member.element ?? 'Fire',
      );
      final vs = rp.radiusMultiplier.clamp(0.5, 3.0);
      // Red-tinted glow trail
      canvas.drawCircle(
        rpPos,
        8.0 * vs,
        Paint()
          ..color = projColor.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawLine(
        rpPos,
        Offset(
          rpPos.dx - cos(rp.angle) * 10 * vs,
          rpPos.dy - sin(rp.angle) * 10 * vs,
        ),
        Paint()
          ..color = projColor.withValues(alpha: 0.5)
          ..strokeWidth = 2.0 * vs
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        rpPos,
        3.0 * vs,
        Paint()..color = projColor.withValues(alpha: 0.9),
      );
    }

    // ── render ring minions (assistants) ──
    for (final m in ringMinions) {
      if (m.dead) continue;
      final mPos = m.position;
      final mColor = elementColor(m.element);
      // If still in orbit (portal), draw a shimmer ring
      if (m.orbitTime > 0 && m.orbitCenter != null) {
        final ringR = m.orbitRadius;
        canvas.drawCircle(
          mPos,
          ringR * 0.6,
          Paint()
            ..color = mColor.withValues(alpha: 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        canvas.drawCircle(
          mPos,
          4.0,
          Paint()..color = mColor.withValues(alpha: 0.95),
        );
        continue;
      }

      // Glow + core
      canvas.drawCircle(
        mPos,
        m.radius * 1.8,
        Paint()..color = mColor.withValues(alpha: 0.18),
      );
      canvas.drawCircle(
        mPos,
        m.radius,
        Paint()..color = mColor.withValues(alpha: 0.95),
      );
      // Small red dot if hostile (marks them as enemy)
      canvas.drawCircle(
        Offset(mPos.dx, mPos.dy),
        2.0,
        Paint()..color = Colors.black.withValues(alpha: 0.9),
      );
    }

    // ── ship ──
    if (!_shipDead) {
      // Invincibility flash
      if (_shipInvincible > 0) {
        final flash = (sin(_elapsed * 30) > 0) ? 0.4 : 1.0;
        canvas.saveLayer(
          null,
          Paint()..color = Colors.white.withValues(alpha: flash),
        );
        ship.render(canvas, _elapsed, skin: activeShipSkin);
        canvas.restore();
      } else {
        ship.render(canvas, _elapsed, skin: activeShipSkin);
      }

      // Boost exhaust trail
      if (isBoosting) {
        final exX = ship.pos.dx - cos(ship.angle) * 22;
        final exY = ship.pos.dy - sin(ship.angle) * 22;
        canvas.drawCircle(
          Offset(exX, exY),
          8 + 3 * sin(_elapsed * 15),
          Paint()
            ..color = const Color(0xFFFF6F00).withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
        canvas.drawCircle(
          Offset(exX, exY),
          4,
          Paint()..color = const Color(0xFFFFAB40).withValues(alpha: 0.8),
        );
      }

      // Ship health bar (below ship)
      if (shipHealth < shipMaxHealth) {
        final barW = 30.0;
        final barH = 3.0;
        final barX = ship.pos.dx - barW / 2;
        final barY = ship.pos.dy + 22;
        final hpFrac = (shipHealth / shipMaxHealth).clamp(0.0, 1.0);

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(barX, barY, barW, barH),
            const Radius.circular(1.5),
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.6),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(barX, barY, barW * hpFrac, barH),
            const Radius.circular(1.5),
          ),
          Paint()..color = Color.lerp(Colors.red, Colors.greenAccent, hpFrac)!,
        );
      }
    } else {
      // Dead: show ghost outline pulsing
      final ghostAlpha = 0.15 + 0.1 * sin(_elapsed * 4);
      canvas.saveLayer(
        null,
        Paint()..color = Colors.white.withValues(alpha: ghostAlpha),
      );
      ship.render(canvas, _elapsed, skin: activeShipSkin);
      canvas.restore();
    }

    // ── VFX particles ──
    for (final p in vfxParticles) {
      final a = p.alpha;
      final sz = p.size * a;
      if (sz <= 0) continue;
      // Glow
      canvas.drawCircle(
        Offset(p.x, p.y),
        sz * 2,
        Paint()
          ..color = p.color.withValues(alpha: a * 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sz * 2),
      );
      // Core
      canvas.drawCircle(
        Offset(p.x, p.y),
        sz,
        Paint()..color = p.color.withValues(alpha: a),
      );
    }

    // ── VFX shock rings ──
    for (final ring in vfxRings) {
      final strokeW = 3.0 * ring.alpha;
      if (strokeW <= 0) continue;
      canvas.drawCircle(
        Offset(ring.x, ring.y),
        ring.radius,
        Paint()
          ..color = ring.color.withValues(alpha: ring.alpha * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW,
      );
    }

    // Fog is tracked for the mini-map only — no overlay on the live view.

    // ── warp flash overlay ──
    if (_warpFlash > 0) {
      canvas.save();
      canvas.translate(-cx, -cy); // move to screen-space

      final t = _warpFlash; // 1.0 → 0.0
      final sw = size.x;
      final sh = size.y;
      final center = Offset(sw / 2, sh / 2);

      // Phase 1 (t > 0.5): bright purple/white flash from centre
      if (t > 0.5) {
        final flashT = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
        // Full-screen white flash
        canvas.drawRect(
          Rect.fromLTWH(0, 0, sw, sh),
          Paint()..color = Color.fromRGBO(255, 255, 255, flashT * 0.8),
        );
        // Central purple burst
        canvas.drawCircle(
          center,
          sw * 0.8 * flashT,
          Paint()
            ..color = Color.fromRGBO(124, 77, 255, flashT * 0.5)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 60 * flashT),
        );
      }

      // Phase 2 (t <= 0.5): speed-line tunnel effect fading out
      if (t <= 0.6) {
        final tunnelT = (t / 0.6).clamp(0.0, 1.0);
        // Radial streaks
        for (var i = 0; i < 32; i++) {
          final angle = (i / 32.0) * pi * 2;
          final innerR = sw * 0.05 * (1.0 - tunnelT);
          final outerR = sw * 0.9;
          final streakWidth = 1.5 + 1.5 * sin(i * 3.7);
          final alpha = tunnelT * 0.35;
          canvas.drawLine(
            Offset(
              center.dx + cos(angle) * innerR,
              center.dy + sin(angle) * innerR,
            ),
            Offset(
              center.dx + cos(angle) * outerR,
              center.dy + sin(angle) * outerR,
            ),
            Paint()
              ..color = Color.fromRGBO(179, 136, 255, alpha)
              ..strokeWidth = streakWidth
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
        // Vignette ring
        canvas.drawCircle(
          center,
          sw * 0.6,
          Paint()
            ..color = Color.fromRGBO(124, 77, 255, tunnelT * 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw * 0.4
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, sw * 0.2),
        );
      }

      canvas.restore();
    }

    canvas.restore();
  }

  // ── fog ────────────────────────────────────────────────

  CosmicPlanet? _orbitalPartner;
  bool _homeOrbitsPartner =
      false; // true → home orbits partner; false → partner orbits home
  double _orbitAngle = 0;
  double _orbitRadius = 0;
  double _orbitSpeed = 0; // rad/sec
}
