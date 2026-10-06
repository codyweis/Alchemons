// lib/games/cosmic/cosmic_game.dart
//
// Flame game for the Cosmic Alchemy Explorer.
// Player pilots a ship through a star field, discovers element planets,
// collects particles to fill a meter, and summons creatures.

import 'dart:math';
import 'package:alchemons/audio/sound_cue.dart';
import 'dart:ui' as ui;

import 'cosmic_contests.dart';
import 'cosmic_ability_runtime.dart';
import 'mask_trap_placement.dart';
import 'cosmic_projectile_vfx.dart';
import 'hostile_shot_vfx.dart';
import 'horn_runtime.dart';
import 'kin_support_runtime.dart';
import 'mane_runtime.dart';
import 'mane_alchemical_vfx.dart' show maneLavaPoolCrowd;
import 'cosmic_enemy_vfx.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/utils/effect_size.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/widgets/portal_key_glyph.dart';
import 'package:alchemons/widgets/inventory_item_artwork.dart';
import 'package:flame/components.dart' show Anchor;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'cosmic_data.dart';
import 'cosmic_cache_data.dart';
import 'cosmic_cache_vfx.dart';
import 'portal_tear_paint.dart';
import 'planets/planet_art.dart';
import 'gravity_ring_art.dart';
import 'ship_art.dart';
import 'station_art.dart';
import 'contest_art.dart';
import 'poi_art.dart';
import 'asteroid_art.dart';
import 'landmark_art.dart';
import 'obsidian_kit.dart' show paintDisc, stoneLightFor;
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
import 'package:alchemons/games/shared/enemy_flight_steering.dart';
import 'package:alchemons/systems/effects/effect.dart';
import 'package:alchemons/systems/effects/effect_loader.dart';
import 'package:alchemons/systems/effects/effect_registry.dart';
import 'package:alchemons/widgets/fx/rift_vortex.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart';
import 'package:alchemons/widgets/fx/costume_paint.dart';
import 'package:alchemons/widgets/fx/darklet_ring.dart';
import 'package:alchemons/widgets/fx/grain_assembly.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show SpecimenGrains;

part 'cosmic_game_helpers.dart';
part 'cosmic_game_components.dart';
part 'cosmic_game_companions_contests.dart';
part 'cosmic_game_world_systems.dart';
part 'cosmic_game_home_visuals.dart';
part 'cosmic_game_caches.dart';
part 'cosmic_game_mask.dart';
part 'cosmic_game_wild.dart';
part 'cosmic_game_companion_motion.dart';
part 'cosmic_game_ability_render.dart';
part 'cosmic_game_combat_actions.dart';
part 'cosmic_game_ability_pass.dart';
part 'cosmic_game_duel.dart';
part 'cosmic_game_wing.dart';
part 'cosmic_game_horn.dart';
part 'cosmic_game_kin.dart';
part 'cosmic_game_mane.dart';

/// Cached icon-glyph painters for item loot drops — same shop icon set
/// resolved via [InventoryItemArtwork.offerFor], baked once per (icon, color)
/// rather than laid out every frame.
final Map<String, TextPainter> _itemIconPainters = {};

TextPainter _itemIconPainter(IconData icon, Color color) {
  final key = '${icon.codePoint}:${icon.fontFamily}:${color.toARGB32()}';
  // A fading drop asks for up to 33 alphas of its tint; keep it bounded.
  if (_itemIconPainters.length > 256 && !_itemIconPainters.containsKey(key)) {
    _itemIconPainters.clear();
  }
  return _itemIconPainters.putIfAbsent(
    key,
    () => TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
          fontSize: 24,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(),
  );
}

/// World labels (planet names, POI tags, whirl counters, …) laid out once
/// per distinct (text, colour, size, weight, spacing) instead of every
/// frame. Keyed on the colour's 8-bit ARGB — all the canvas can show — so a
/// cached label paints exactly what a fresh one would. Callers whose colour
/// animates quantize it first. Cleared wholesale if it ever grows past 512.
final Map<(String, int, double, FontWeight?, double?), TextPainter>
_worldLabelPainters = {};

TextPainter _worldLabel(
  String text, {
  required Color color,
  required double fontSize,
  FontWeight? fontWeight,
  double? letterSpacing,
}) {
  final key = (text, color.toARGB32(), fontSize, fontWeight, letterSpacing);
  final hit = _worldLabelPainters[key];
  if (hit != null) return hit;
  if (_worldLabelPainters.length >= 512) _worldLabelPainters.clear();
  return _worldLabelPainters[key] = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

/// What a stroke of [width] under MaskFilter.blur(normal, [sigma]) drew,
/// without the blur: a wide faint pass under a narrower brighter one (the
/// [paintSoftRing] recipe), handed to [draw] for the shape's geometry.
void _softStroke(
  Paint p,
  Color col,
  double width,
  double sigma,
  void Function(Paint) draw,
) {
  if (col.a <= 0) return;
  final peak = 1 - exp(-width / (1.9 * max(sigma, 0.01)));
  draw(
    p
      ..maskFilter = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = width + sigma * 4
      ..color = col.withValues(alpha: col.a * peak * 0.45),
  );
  draw(
    p
      ..strokeWidth = width + sigma * 1.5
      ..color = col.withValues(alpha: col.a * peak * 0.6),
  );
}

final Paint _softLinePaint = Paint();

/// [_softStroke] for a blurred line.
void _softLine(
  Canvas c,
  Offset a,
  Offset b,
  Color col,
  double width,
  double sigma, {
  StrokeCap cap = StrokeCap.butt,
}) => _softStroke(
  _softLinePaint..strokeCap = cap,
  col,
  width,
  sigma,
  (p) => c.drawLine(a, b, p),
);

// ─────────────────────────────────────────────────────────
// MAIN GAME
// ─────────────────────────────────────────────────────────

class _BeamFx {
  _BeamFx({
    required this.start,
    required this.end,
    required this.color,
    required this.width,
    required this.life,
    this.wingElement,
  }) : maxLife = life;

  Offset start;
  Offset end;
  final Color color;
  final String? wingElement;
  final double width;
  double life;
  final double maxLife;

  bool get dead => life <= 0;
  double get alpha => (life / maxLife).clamp(0.0, 1.0);

  void update(double dt) {
    life -= dt;
  }
}

/// True when [p] is far enough outside the viewport to skip drawing.
///
/// [cx]/[cy] are the viewport's top-left in world coordinates, so the test is
/// against the distance from its centre. [margin] is in screen-fulls beyond
/// that centre: 1.0 keeps roughly half a screen of slack past each edge.
///
/// Extracted because the four cull sites in the render loop were written out
/// by hand and one of them had `&&` where the others had `||` — a planet was
/// only skipped when it was off screen horizontally AND vertically, so
/// anything off to the side but vertically aligned still drew in full, blurs
/// and all.
@visibleForTesting
bool isOutsideViewport(
  Offset p,
  double cx,
  double cy,
  double screenW,
  double screenH, {
  double margin = 1.0,
}) {
  return (p.dx - cx - screenW / 2).abs() > screenW * margin ||
      (p.dy - cy - screenH / 2).abs() > screenH * margin;
}

class CosmicGame extends FlameGame with PanDetector {
  static const double _planetRecipeParticleCollectionMultiplier = 1.15;
  static const double _planetRecipeParticlePickupRadius =
      30.0 * _planetRecipeParticleCollectionMultiplier;

  CosmicGame({
    required this.world_,
    required this.onMeterChanged,
    this.onSound,
    this.onBoostActiveChanged,
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
    this.onNearBloodRing,
    this.onNearContestArena,
    this.onContestHintCollected,
    Set<String>? initialCustomizations,
    Map<String, String>? initialOptions,
    String? initialAmmoId,
    this.startCloserToSurvivalSignal = false,
    int guardiansDefeated = 0,
  }) : activeCustomizations = initialCustomizations ?? {},
       _guardiansDefeated = max(0, guardiansDefeated),
       customizationOptions = initialOptions ?? {},
       activeAmmoId = initialAmmoId;

  final CosmicWorld world_;
  int _guardiansDefeated;
  int get guardiansDefeated => _guardiansDefeated;

  /// New ambient contacts near home stay at starter difficulty, including
  /// across the world's wrapped edges. Enemies already pursuing can follow.
  bool isHomeRecoveryArea(Offset position) {
    final home = homePlanet;
    if (home == null) return false;
    final width = world_.worldSize.width;
    final height = world_.worldSize.height;
    final dx = (position.dx - home.position.dx).abs() % width;
    final dy = (position.dy - home.position.dy).abs() % height;
    final x = min(dx, width - dx);
    final y = min(dy, height - dy);
    return x * x + y * y <= pow(home.visualRadius + 900, 2);
  }

  /// Refresh idle encounters after returning from a planet. Active fights
  /// retain their level, health, wave composition, and rewards.
  void syncGuardianProgress(int count) {
    count = max(0, count);
    if (count == _guardiansDefeated) return;
    final previousLevel = CosmicBalance.spaceLevel(_guardiansDefeated);
    _guardiansDefeated = count;
    if (!isLoaded || previousLevel == CosmicBalance.spaceLevel(count)) return;
    final rng = Random(world_.planets.first.element.hashCode ^ count);
    for (final lair in bossLairs) {
      if (lair.state == BossLairState.waiting) {
        lair.level = CosmicBalance.rollSpaceLevel(count, rng);
      }
    }
    for (final whirl in galaxyWhirls) {
      if (whirl.state == WhirlState.dormant) {
        whirl.level = CosmicBalance.rollSpaceLevel(count, rng);
      }
    }
  }

  final bool startCloserToSurvivalSignal;
  final VoidCallback onMeterChanged;
  final void Function(SoundCue cue)? onSound;

  /// Fires when boost starts or stops ACTUALLY applying, which is not the
  /// same as the button being held: an empty tank means a held button does
  /// nothing. Anything that represents boost to the player — the engine
  /// loop, most obviously — belongs on this rather than on the input.
  final void Function(bool active)? onBoostActiveChanged;
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

  /// Element of the planet currently overrun by a timed raid (set by the
  /// screen). The planet gets a pulsing crimson corruption aura.
  String? raidElement;
  final void Function(GalaxyWhirl whirl)? onWhirlActivated;
  final void Function(GalaxyWhirl whirl, int wave)? onWhirlWaveComplete;
  final void Function(GalaxyWhirl whirl)? onWhirlComplete;
  final void Function(SpacePOI poi)? onPOIDiscovered;
  final void Function(SpacePOI? poi)? onNearMarket;
  final void Function(CosmicPartyMember member)? onCompanionAutoReturned;
  final void Function(CosmicPartyMember member)? onCompanionDied;
  final void Function(CosmicContestArena? arena)? onNearContestArena;
  final void Function(CosmicContestHintNote note)? onContestHintCollected;

  /// Fires when the ship parks at (or leaves) a sealed elemental cache.
  void Function(ElementalCache? cache)? onNearCache;

  /// Fires once the three-second unsealing ritual completes.
  void Function(ElementalCache cache)? onCacheOpened;

  /// Fires the first time the ship gets right on top of a cache.
  void Function(ElementalCache cache)? onCacheDiscovered;

  /// Fires when a claimed cache re-forms elsewhere in the cosmos.
  void Function(ElementalCache cache)? onCacheRespawned;

  // ── state ──────────────────────────────────────────────
  final ElementMeter meter = ElementMeter();
  CosmicPlanet? nearPlanet;
  SpacePOI? nearMarket;
  int? _starDustScannerTargetIndex;
  int? _scannerCompletedDustIndex;
  int? _planetScannerTargetIndex;

  late ShipComponent ship;
  bool runtimeReady = false;
  // Loaded effect prototypes from assets
  List<Effect> _loadedEffectPrototypes = [];
  final List<PlanetComponent> planetComps = [];
  final List<ElementParticle> elemParticles = [];

  // Stars stored in spatial grid for fast rendering
  static const double _starChunkSize = 800.0;
  late int _starGridW;
  late int _starGridH;
  late List<List<_StarParticle>> _starGrid;

  // Parallax depth layers — small star tiles repeated across the viewport
  // and scrolled at fractional camera rates so the foreground grid passes
  // faster than the background, giving the ship a sense of depth.
  static const double _parallaxTile = 1100.0;
  final List<_ParallaxLayer> _parallaxLayers = [];

  // Fog: each pixel in a conceptual grid is revealed when ship is nearby.
  // We use a Set of grid-cell keys for discovered cells.
  static const double fogCellSize = 120.0;
  final Set<int> revealedCells = {};

  // Star dust collectibles
  late List<StarDust> starDusts;
  int collectedDustCount = 0;

  // Rift portals (5 permanent, one per faction)
  double _riftPulse = 0;
  final Map<String, RiftVortexField> _riftFields = {};
  final Map<String, RiftPalette> _riftPalettes = {};
  final Map<String, double> _riftFieldTimes = {};
  RiftPortal? _nearestRift; // closest rift within interact range
  bool _wasNearRift = false;

  // Elemental Nexus (black portal easter-egg)
  late ElementalNexus elementalNexus = world_.elementalNexus;
  bool _wasNearNexus = false;
  bool _isNearNexus = false;
  void Function(bool isNear)? onNearNexus;

  // Blood Ring (ending ritual portal)
  late BloodRing bloodRing = world_.bloodRing;
  bool _wasNearBloodRing = false;
  bool _isNearBloodRing = false;
  bool get isNearBloodRing => _isNearBloodRing;
  void Function(bool isNear)? onNearBloodRing;

  // Trait contest arenas + hint notes
  late List<CosmicContestArena> contestArenas = world_.contestArenas;
  late List<CosmicContestHintNote> contestHintNotes = world_.contestHintNotes;
  CosmicContestArena? nearContestArena;

  // The one Alchemon fighting the player in-world: a wild one in a duel, or
  // a contest rival during a contest cinematic. Contests only stage it; the
  // duel update runs only while [wildDuelActive].
  CosmicCompanion? duelOpponent;
  final List<Projectile> duelOpponentProjectiles = CappedProjectileList();

  // The wild Alchemon's side of a duel (cosmic_game_duel.dart). The party's
  // abilities reach it as a body in the enemy list; its own abilities
  // resolve in a world where the party's bodies are the enemies and it is
  // the only ally.
  final _WildSide _wildSide = _WildSide();
  final Map<CosmicEnemy, _CombatBody> _combatBodies = {};
  _CombatBody? _wildBody;
  final Map<Object, _CombatBody> _partyBodies = {};
  bool _onWildSideNow = false;

  // Wild Alchemons drifting in space — see cosmic_game_wild.dart.
  final List<SpaceWildAlchemon> wildAlchemons = [];
  String? _duelWildId;
  bool get wildDuelActive => _duelWildId != null;
  // Starts most of the way to the first arrival so space is not empty for
  // the first stretch of a visit.
  double _wildSpawnTimer = 3.0;
  bool _wildSpawnRequested = false;
  bool _wildContactPending = false;
  SpaceWildAlchemon? nearWild;

  /// Potential readouts over wild Alchemons (Wild Potential Scanner).
  bool showWildPotentials = false;

  /// Asks the screen for a creature at [position]. [element] is the nearby
  /// planet's element, or null in open space.
  void Function(Offset position, String? element)? onWildSpawnWanted;

  /// The ship rammed [wild]; space should pause and the portal open.
  void Function(SpaceWildAlchemon wild)? onWildContact;
  void Function(SpaceWildAlchemon? wild)? onNearWild;
  void Function(SpaceWildAlchemon wild)? onWildDuelStarted;
  void Function(SpaceWildAlchemon wild, WildDuelEnd how)? onWildDuelEnded;

  // The portal tear played in space when the ship rams one: time slows, the
  // camera leans in on the creature, and the tear opens until it swallows
  // the screen. The encounter opens behind that dark.
  SpaceWildAlchemon? _tearWild;
  bool _tearHandedOff = false;
  double _tearT = 0;
  double _tearCloseT = -1;
  double _tearClock = 0;
  Offset _tearWorld = Offset.zero;
  Color _tearColor = Colors.white;
  Offset _camPan = Offset.zero;
  Offset _camPanFrom = Offset.zero;
  double _camZoomMul = 1.0;
  static const double _tearOpenSeconds = 0.95;
  static const double _tearCloseSeconds = 0.55;

  /// The tear has started; the screen clears its HUD for the shot.
  VoidCallback? onWildTearStarted;

  // Territories are lived in; the deep space between them is sparse.
  static const int _maxWildInTerritory = 5;
  static const double _wildIntervalInTerritory = 6.0;
  static const int _maxWildInDeepSpace = 2;
  static const double _wildIntervalInDeepSpace = 15.0;

  /// Share of a territory's arrivals that are its own element; the rest are
  /// strays from anywhere already discovered.
  static const double _wildTerritoryNativeShare = 0.8;
  static const double _wildDespawnRange = 3400.0;
  static const double _wildNearRange = 360.0;
  static const double _wildLabelRange = 480.0;
  static const double _wildContactRange = 42.0;
  static const double _wildTerritoryRange = 250.0;
  static const double _wildCompanionEngageRange = 200.0;
  static const double _wildTetherRadius = 320.0;
  static const double _wildDisengageRange = 1400.0;
  static const double _wildExhaustedSeconds = 30.0;

  /// Ship shots are tuned against enemy health; an Alchemon's companion-scale
  /// HP needs them heavier so a ship alone can still win a fight.
  static const double _wildShipShotScale = 4.0;

  SpriteAnimationTicker? _duelOpponentTicker;
  SpriteVisuals? _duelOpponentVisuals;
  double _duelOpponentSpriteScale = 1.0;
  Sprite? _duelOpponentFallbackSprite;
  double _duelOpponentFallbackScale = 1.0;
  int _duelOpponentFallbackLoadToken = 0;
  int _duelOpponentSpriteLoadToken = 0;
  double _duelOpponentSpriteRetryTimer = 0.0;
  int _duelOpponentSpriteLoadsInFlight = 0;

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

  /// Whether each weapon aims itself.
  ///
  /// On, the trigger is an armed state: the weapon picks a target inside
  /// [autoFireRange] and holds fire when there is nothing there. Off, it is a
  /// held trigger firing along the hull, and where the ship points is where
  /// the shot goes.
  bool autoAimGun = true;
  bool autoAimMissiles = true;
  double _missileShootCooldown = 0;
  bool _wasNearHome = false; // for change detection

  // Active home customizations (recipe IDs)
  Set<String> activeCustomizations;
  Map<String, String> customizationOptions; // 'recipeId.paramKey' -> value
  String? activeAmmoId;
  String? activeWeaponId; // 'equip_machinegun' or null (default)
  bool hasMissiles = false; // whether missile launcher is equipped

  /// Whether the Matter Injector is fitted — the booster may burn cargo
  /// once the fuel tank is dry.
  bool hasMatterInjector = false;
  String? activeShipSkin; // 'skin_phantom', 'skin_solar', or null (default)

  // Power-up levels (0-5), each level adds 12% damage (60% at max)
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

  /// Raw matter burned per second when the tank is dry and the booster falls
  /// back to the cargo meter. Deliberately steeper than refined fuel: the
  /// meter is what the run is *for*, so flying on it should cost the trip.
  static const double boostMeterPerSecond = 4.0;

  /// True while the booster is running on cargo rather than refined fuel —
  /// read by the HUD so the player can see what is being spent.
  bool boostingOnMatter = false;

  /// Throttle for telling the HUD the meter is shrinking under a matter
  /// boost — about ten readings a second rather than one per frame.
  double _matterBoostHudTimer = 0;

  // Orbital sentinels
  final List<OrbitalSentinel> orbitals = [];
  int orbitalStockpile = 0; // built sentinels not yet deployed
  double _orbitalReplenishTimer = 0;

  // Missile tracking
  int missileAmmo = 0; // consumable ammo for homing missiles
  final List<_HomingMissile> _missiles = [];

  // Boost visual state (set in update, read in render)
  bool isBoosting = false;
  double _boostTrailVisual = 0.0;
  bool _boostTrailWasActive = false;

  // Active companions (summoned party alchemons), keyed by party slot index.
  // Multiple can be summoned simultaneously, up to [maxActiveCompanions].
  // Not final: while the wild Alchemon's abilities resolve, this and the
  // other per-side lists below hold its side (see _onWildSide).
  Map<int, CosmicCompanion> activeCompanions = {};
  static const int maxActiveCompanions = 3;

  /// The "primary" active companion (first summoned), used by systems that
  /// only make sense for a single target (boss set-pieces, ring duels, heal
  /// beams). Kept for compatibility with those single-target systems.
  CosmicCompanion? get activeCompanion =>
      activeCompanions.isNotEmpty ? activeCompanions.values.first : null;
  int? get _primaryCompanionSlot =>
      activeCompanions.isEmpty ? null : activeCompanions.keys.first;
  List<Projectile> companionProjectiles = CappedProjectileList();

  // Let meteor craters. Shared struct + shared painter, so open space draws
  // the identical landing survival and the dungeon do.
  final List<LetSkyfallImpact> _letSkyfallImpacts = [];
  final List<LetFx> _letFx = [];
  final List<HornFx> _hornFx = [];
  final List<_BeamFx> _beamFx = [];
  double _openKinPrevShipHealth = -1;
  double _openKinLastShipDamage = 0;

  /// Kin lasers being drawn, from either side of a duel (cosmic_game_kin.dart).
  final List<KinLaserBeam> _kinLaserBeams = [];

  /// A Kin Plant garden's flowers waiting to be collected; on the wild side
  /// of a duel, the wild one's (cosmic_game_kin.dart).
  List<_KinFlower> _kinFlowers = [];
  final MaskTrapVisuals _maskTrapVisuals = MaskTrapVisuals();
  Set<CosmicEnemy> _maskBloodMarked = {};
  Map<int, int> _maskSpiritBank = {};
  double _maskBloodTimer = 0;
  double _maskBloodHealing = 0;

  /// Spirit wisps waiting on the field for the ship (cosmic_game_mask.dart).
  List<MaskSpiritWisp> _maskSpiritWisps = [];

  /// How many times each slot's Plant vine has been fed, kept past the vine
  /// itself so a redeployed caster regrows it from where it was.
  Map<int, int> _maskPlantFeeds = {};

  /// A Spirit clear's flash, 1→0, and where it went off.
  double _maskSpiritNukeFlash = 0;
  Offset _maskSpiritNukeOrigin = Offset.zero;
  List<_ActiveWingBeam> _activeWingBeams = [];
  List<_ActiveWingBeam> _pendingWingBeams = [];
  final List<_WingFlower> _wingFlowers = [];
  final Map<int, SpriteAnimationTicker> _companionTickers = {};
  final Map<int, SpriteVisuals?> _companionVisualsBySlot = {};
  final Map<int, double> _companionSpriteScales = {};

  /// Each companion read into grains of itself (with the instance they were
  /// read from), for its summoning and its recall.
  final Map<int, (String, GrainAssembly)> _companionGrains = {};
  Iterable<CosmicCompanion> get _livingActiveCompanions =>
      activeCompanions.values.where((comp) => comp.isAlive && !comp.returning);

  CosmicCompanion? _nearestActiveCompanion(Offset position) {
    CosmicCompanion? nearest;
    var nearestDistance = double.infinity;
    for (final comp in _livingActiveCompanions) {
      final distance = (comp.position - position).distanceSquared;
      if (distance < nearestDistance) {
        nearest = comp;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  // Open-space companion steering (cosmic_game_companion_motion.dart).
  final Map<int, _CompanionEngagement> _companionEngagements = {};
  final Map<int, Offset> _companionGoals = {};
  final Map<int, int> _companionPlaceRanks = {};
  Offset _shipVelocity = Offset.zero;
  Offset? _lastShipPosForCompanions;
  double _formationHeading = 0;
  CosmicCompanion? _wildDuelTargetCompanion;

  bool _companionTethered = true;
  static const double _companionTetherAnchorFollowSpeed = 5.5;
  static const double _companionTetherReturnSpeed = 260.0;
  static const double _companionTetherHardRadius = 240.0;
  static const double _companionTetherEngageRange = 340.0;

  bool get companionTethered => _companionTethered;
  set companionTethered(bool value) {
    if (_companionTethered == value) return;
    _companionTethered = value;
    if (value) {
      for (final comp in activeCompanions.values) {
        _enforceCompanionTether(comp, immediate: true);
      }
    }
  }

  final Random _rng = Random();

  // Home garrison (stationed alchemons inside home planet)
  List<_GarrisonCreature> _garrison = [];

  // Enemies & bosses
  List<CosmicEnemy> enemies = [];
  CosmicBoss? activeBoss;
  final List<BossProjectile> bossProjectiles = [];
  bool sandboxMode = false;
  Offset? sandboxAreaCenter;
  Offset? sandboxReturnPosition;
  double? sandboxArenaRadius;
  static const double sandboxAreaRevealRadius = 900.0;
  final Random sandboxRng = Random(0x5A4E4442);

  // Loot drops on the ground
  final List<LootDrop> lootDrops = [];
  final ShipWallet shipWallet = ShipWallet();
  double _enemySpawnTimer = 0;
  int _nextPackId = 0; // unique pack ID counter

  /// Each roaming wisp flock's centre and heading this frame, by pack. See
  /// `_gatherFlocks`.
  final Map<int, _FlockCentre> _flockCentres = {};
  static const int _maxEnemies = 220;

  /// Stalkers (or stalker flocks) shadowing the ship at once.
  static const int _maxStalkerGroups = 2;

  /// Squared distance between two world points, respecting the world's
  /// toroidal wrap — a naive distance would read two points either side of the
  /// seam as maximally far apart.
  double _wrappedDistanceSq(Offset a, Offset b) {
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    var dx = (a.dx - b.dx).abs();
    var dy = (a.dy - b.dy).abs();
    if (dx > ww / 2) dx = ww - dx;
    if (dy > wh / 2) dy = wh - dy;
    return dx * dx + dy * dy;
  }

  /// How far from the ship an unanchored enemy may drift before it is
  /// despawned. Generous enough that nothing vanishes on screen or just past
  /// the edge — roughly three screens out.
  static const double _enemyCullDist = 3600.0;
  static const double _enemyCullDistSq = _enemyCullDist * _enemyCullDist;

  /// The ring round a contest that is kept clear of enemies while it plays.
  static const double _contestClearDist = _enemyCullDist;
  static const double _contestClearDistSq =
      _contestClearDist * _contestClearDist;
  static const double _enemySpawnInterval = 1.0; // seconds between checks
  static const double _meterPickupMultiplier = 3.0;

  // Swarm cluster spawn timer
  double _swarmSpawnTimer = 0;
  static const double _swarmSpawnInterval =
      16.0; // seconds between swarm spawns
  bool _initialSwarmsSpawned = false;

  // Random boss spawn timer
  double _bossSpawnTimer = 0;
  static const double _bossSpawnInterval = 22.5;

  /// A boss only thinks — moves, fires, calls escorts, pulses its colossal
  /// trait — while the ship is within this range. Past it the boss is dormant:
  /// its attacks were audible and its escort packs kept filling the enemy cap
  /// from the far side of the map. Every attack range is well inside this.
  static const double _bossEngageDist = 1400.0;
  static const double _bossEngageDistSq = _bossEngageDist * _bossEngageDist;

  /// A boss the ship has left this far behind for [_bossLeashGrace] seconds is
  /// despawned (a lair it came from goes back to waiting). Matches the enemy
  /// cull so nothing vanishes on screen.
  static const double _bossLeashDistSq = _enemyCullDistSq;
  static const double _bossLeashGrace = 5.0;
  double _bossLeashTimer = 0;

  // Boss lairs (always at least 1 on the map)
  late List<BossLair> bossLairs;

  // Galaxy whirls (horde encounters)
  late List<GalaxyWhirl> galaxyWhirls;
  GalaxyWhirl? activeWhirl;

  // Space POIs
  late List<SpacePOI> spacePOIs;

  // Sealed elemental caches — one per element, cracked by summoning a
  // companion of the matching element beside them. Built lazily so the screen
  // can restore saved cache state without racing onLoad.
  late final ElementalCacheField elementalCacheField =
      ElementalCacheField.generate(
        seed:
            world_.planets.first.position.dx.round() ^
            world_.planets.first.position.dy.round(),
        worldSize: world_.worldSize,
        planets: world_.planets,
        landmarks: [
          world_.elementalNexus.position,
          world_.retiredArenaPosition,
          world_.bloodRing.position,
          world_.prismaticField.position,
          ...world_.riftPortals.map((r) => r.position),
          ...world_.contestArenas.map((a) => a.position),
        ],
      );
  ElementalCache? _nearestCache;
  ElementalCache? openingCache;

  // Prismatic Field (aurora easter-egg)
  late PrismaticField prismaticField = world_.prismaticField;
  bool prismaticRewardClaimed = false;
  double _prismaticCelebTimer = -1; // ≥ 0 while celebration running
  Offset? _prismaticCelebCenter; // orbit centre during celebration
  int? _prismaticCelebCompanionSlot;
  static const double _prismaticCelebDuration = 3.5; // seconds
  VoidCallback? onPrismaticRewardClaimed;

  // Pocket dimension cached render-to-texture
  ui.Image? _pocketCachedImage;
  static const int _pocketTexSize = 512;
  final Paint _pocketPaint = Paint()..filterQuality = FilterQuality.low;

  // Feeding-pack spawn: separate timer, spawns near asteroid belt
  double _feedingPackTimer = 0;
  static const double _feedingPackInterval = 10.0;

  // Ship health
  double shipHealth = CosmicBalance.shipMaxHealth;
  static const double shipMaxHealth = CosmicBalance.shipMaxHealth;

  /// Trails stop being laid at this many live ability projectiles (60% of
  /// the list's 220), as survival's do: a source that generates itself gives
  /// way to what the player cast.
  static const int _trailProjectileCeiling = (220 * 0.60) ~/ 1;
  double _shipInvincible = 0; // invincibility timer after hit
  bool _shipDead = false;
  double _respawnTimer = 0;

  // Visual effects
  final List<VfxParticle> vfxParticles = [];

  /// Shared combat-ability particles (zone wisps, hit sparks, bursts). Kept
  /// separate from [vfxParticles] (which also holds ship/celebration flavor
  /// VFX) so abilities render identically to Cosmic Survival via the shared
  /// canonical renderer.
  final AbilityVfxPool _abilityVfx = AbilityVfxPool();
  final List<VfxShockRing> vfxRings = [];

  /// Scratch for the batched soft dots of swarms and galaxy whirls.
  final GlowDots _swarmDots = GlowDots(6);

  // Camera offset (ship is always centred; camera follows ship)
  // Three zoom presets: current (closest), medium, wide.
  static const double _zoomClose = 0.85;
  static const double _zoomMid = 0.72;
  static const double _zoomFar = 0.504;
  static const List<double> _zoomPresets = [_zoomClose, _zoomMid, _zoomFar];

  /// ARRIVE AT MID. Space opened at the closest of the three, which shows a
  /// couple of planets and none of the shape of the place; the middle
  /// setting is what you would pick anyway on the way to anywhere.
  static const int _zoomDefaultIndex = 1;
  int _zoomLevelIndex = _zoomDefaultIndex;
  double _currentZoom = _zoomPresets[_zoomDefaultIndex];
  double _zoomAnimFrom = _zoomPresets[_zoomDefaultIndex];
  double _zoomAnimTo = _zoomPresets[_zoomDefaultIndex];
  double _zoomAnimTimer = 0;
  static const double _zoomAnimDuration = 0.42;
  bool _zoomAnimComplete = true;

  /// Current zoom level index (0 = close, 1 = mid, 2 = far).
  int get currentZoomLevel => _zoomLevelIndex;

  /// The zoom the world is drawn at: the player's preset, pushed in further
  /// while a portal tear plays.
  double get cameraZoom {
    var z = _currentZoom * _camZoomMul;
    if (_contestPullBack > 0) {
      // A contest frames the whole arena, whatever the player's zoom.
      final frame = size.x / (CosmicContestArena.visualRadius * 2 * 1.06);
      z += (min(z, frame) - z) * Curves.easeInOut.transform(_contestPullBack);
    }
    if (_bloodFrame > 0) {
      // The ritual frames the whole crown and the light round it.
      final frame = size.x / (BloodRing.visualRadius * 2 * 1.5);
      z += (min(z, frame) - z) * Curves.easeInOut.transform(_bloodFrame);
    }
    return z;
  }

  /// 0 normally, easing to 1 while a contest plays (see update).
  double _contestPullBack = 0;

  /// The Blood Ring's ritual, 0..1, while it plays (the screen drives it);
  /// null otherwise. The ritual happens to the ring in the world: the camera
  /// eases back and over to frame the whole crown, the well runs faster and
  /// the thorns ignite (see update and paintBloodRing). Clearing it puts the
  /// camera straight back, under the red the ritual ends in.
  double? get bloodRitualProgress => _bloodRitual;
  set bloodRitualProgress(double? v) {
    _bloodRitual = v;
    if (v == null) {
      _bloodFrame = 0;
      _camPan = Offset.zero;
    }
  }

  double? _bloodRitual;

  /// 0..1: how far the camera has come round to frame the Blood Ring.
  double _bloodFrame = 0;

  /// The Blood Ring well's clock: it runs faster through the ritual.
  double _bloodFlow = 0;

  /// 0..1, easing toward whether a Mystic Blood companion is out.
  double _bloodArmed = 0;

  void cycleZoomLevel() {
    _zoomLevelIndex = (_zoomLevelIndex + 1) % _zoomPresets.length;
    _zoomAnimFrom = _currentZoom;
    _zoomAnimTo = _zoomPresets[_zoomLevelIndex];
    _zoomAnimTimer = 0;
    _zoomAnimComplete = false;
  }

  double get camX => ship.pos.dx + _camPan.dx - size.x / (2 * cameraZoom);
  double get camY => ship.pos.dy + _camPan.dy - size.y / (2 * cameraZoom);

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

    // Parallax depth layers (far + mid) — drawn behind the foreground grid.
    _parallaxLayers
      ..clear()
      ..add(
        _ParallaxLayer(
          factor: 0.18,
          count: 26,
          tile: _parallaxTile,
          maxSize: 1.3,
          maxBrightness: 0.4,
          seed: 7,
        ),
      )
      ..add(
        _ParallaxLayer(
          factor: 0.45,
          count: 20,
          tile: _parallaxTile,
          maxSize: 1.8,
          maxBrightness: 0.6,
          seed: 23,
        ),
      );

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
      guardiansDefeated: _guardiansDefeated,
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
    if (startCloserToSurvivalSignal) {
      final portalPos = _survivalPortalPosition();
      if (portalPos != null) {
        final center = Offset(
          world_.worldSize.width / 2,
          world_.worldSize.height / 2,
        );
        ship.pos = Offset.lerp(center, portalPos, 0.24)!;
      }
    }
    syncStarDustScannerAvailability();
    syncPlanetScannerAvailability();

    // Generate initial boss lairs (3-4 spread around the world)
    final lairRng = Random(world_.planets.first.element.hashCode ^ 0xCC33);
    final lairCount = 3 + lairRng.nextInt(2); // 3 or 4
    bossLairs = [];
    for (int i = 0; i < lairCount; i++) {
      bossLairs.add(
        BossLair.generate(
          guardiansDefeated: _guardiansDefeated,
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
    } finally {
      runtimeReady = true;
    }
  }

  // ── input ──────────────────────────────────────────────

  Offset? _dragTarget;

  /// Normalised steering direction from the virtual joystick (null = idle).
  Offset? joystickDirection;

  /// How far a weapon will reach on its own. Roughly a screen at default
  /// zoom, so it engages what the player can see rather than things off it.
  static const double autoFireRange = 520.0;

  @override
  void onPanStart(DragStartInfo info) {
    _dragTarget = _wrap(
      Offset(
        info.eventPosition.global.x / cameraZoom + camX,
        info.eventPosition.global.y / cameraZoom + camY,
      ),
    );
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    _dragTarget = _wrap(
      Offset(
        info.eventPosition.global.x / cameraZoom + camX,
        info.eventPosition.global.y / cameraZoom + camY,
      ),
    );
  }

  @override
  void onPanEnd(DragEndInfo info) {
    // Keep drifting toward last target — don't null it
  }

  /// The closest living enemy inside [range] of [from], or null.
  /// The nearest thing worth shooting inside [range], or null.
  ///
  /// The boss is not in [enemies] — it is its own field — so a search that
  /// only walked the list went blind in the one fight where holding fire is
  /// least forgivable: alone with the boss and no minions up, an armed ship
  /// simply never shot. The homing missiles already knew to check both, and
  /// this is the same pair.
  Offset? _nearestEnemyWithin(Offset from, double range) {
    Offset? best;
    var bestDist2 = range * range;
    for (final e in enemies) {
      if (e.dead) continue;
      final dx = e.position.dx - from.dx;
      final dy = e.position.dy - from.dy;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestDist2) {
        bestDist2 = d2;
        best = e.position;
      }
    }
    // A wild Alchemon is a target only once the player has picked the
    // fight. Asteroids are deliberately NOT here: they take fire too, but
    // they are scenery to be mined, and an armed ship would otherwise chew
    // through every rock it drifted past.
    final opp = duelOpponent;
    if (wildDuelActive && opp != null && opp.isAlive) {
      final dx = opp.position.dx - from.dx;
      final dy = opp.position.dy - from.dy;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestDist2) {
        bestDist2 = d2;
        best = opp.position;
      }
    }
    final boss = activeBoss;
    if (boss != null && !boss.dead) {
      final dx = boss.position.dx - from.dx;
      final dy = boss.position.dy - from.dy;
      final d2 = dx * dx + dy * dy;
      // Measured to the hull, not the centre: a titanic boss can have the
      // ship inside its own radius and still read as hundreds of units away.
      final reach = range + boss.radius;
      if (d2 < reach * reach && d2 < bestDist2) {
        best = boss.position;
      }
    }
    return best;
  }

  /// Set drag target from screen coordinates.
  void setDragTargetFromScreen(Offset screenPos) {
    _dragTarget = _wrap(
      Offset(
        screenPos.dx / cameraZoom + camX,
        screenPos.dy / cameraZoom + camY,
      ),
    );
  }

  /// Set a world travel target and steer using shortest toroidal path.
  void setTravelTarget(Offset worldPos) {
    _dragTarget = _wrap(worldPos);
    joystickDirection = null;
  }

  /// Clear any live steering input so movement does not continue after jumps.
  void clearSteeringInput() {
    _dragTarget = null;
    joystickDirection = null;
  }

  /// Teleport ship directly (for mini-map clicks).
  void teleportTo(Offset worldPos) {
    clearSteeringInput();
    ship.pos = worldPos;
    _revealAround(ship.pos, 300);
  }

  Offset? _survivalPortalPosition() {
    for (final poi in spacePOIs) {
      if (poi.type == POIType.survivalPortal) return poi.position;
    }
    return null;
  }

  // ── Companion (party alchemon) ──

  /// Species-type scale factors for sprites in cosmic space. Survival uses
  /// [kCompanionSpeciesScale] as is; space draws wings and horns half again
  /// as large, and mystics as large as wings, so the big families read as
  /// big against the dark.
  /// Every Alchemon in space — summoned, garrisoned, wild, fighting or a
  /// contest rival — is fitted to this box before its family and size
  /// genetics scale it, so the same creature is the same size everywhere.
  static const double spriteBox = 74.88;

  /// The family scale space draws [family] at (see [_companionSpeciesScale]).
  static double spaceSpeciesScale(String family) =>
      _companionSpeciesScale[family.toLowerCase()] ?? 1.0;

  static final Map<String, double> _companionSpeciesScale = {
    ...kCompanionSpeciesScale,
    'wing': kCompanionSpeciesScale['wing']! * 1.5,
    'horn': kCompanionSpeciesScale['horn']! * 1.5,
    // Mystics stand as large as wings.
    'mystic': kCompanionSpeciesScale['wing']! * 1.5,
  };

  static double _clampDouble(double value, double minValue, double maxValue) {
    return value.clamp(minValue, maxValue).toDouble();
  }

  double _combatAcquireRange({
    required String family,
    required double attackRange,
    required double specialRange,
  }) {
    final engageRange = max(attackRange, specialRange);
    final floor = switch (family.toLowerCase()) {
      'horn' => 460.0,
      'mane' => 420.0,
      'wing' || 'mystic' => 480.0,
      _ => 400.0,
    };
    return max(engageRange + 150.0, floor);
  }

  double _effectiveCombatAcquireRange(double baseRange) {
    if (!sandboxMode || sandboxArenaRadius == null) return baseRange;
    return max(baseRange, sandboxArenaRadius! * 2.0 + 160.0);
  }

  double _preferredCombatDistance({
    required String family,
    required double attackRange,
    required double specialRange,
  }) {
    switch (family.toLowerCase()) {
      case 'horn':
        return _clampDouble(attackRange * 0.72, 72.0, 120.0);
      case 'mane':
        return _clampDouble(attackRange * 0.82, 84.0, 140.0);
      case 'mask':
        return _clampDouble(specialRange * 0.80, 130.0, 210.0);
      case 'kin':
        return _clampDouble(specialRange * 0.72, 110.0, 180.0);
      case 'wing':
        return _clampDouble(specialRange * 0.85, 165.0, 280.0);
      case 'let':
        return _clampDouble(specialRange * 0.90, 170.0, 280.0);
      case 'pip':
        return _clampDouble(attackRange * 0.72, 115.0, 175.0);
      case 'mystic':
        return _clampDouble(specialRange * 0.90, 170.0, 300.0);
      default:
        return _clampDouble(
          max(attackRange, specialRange) * 0.80,
          120.0,
          220.0,
        );
    }
  }

  double _combatHoldDistance({
    required String family,
    required double attackRange,
    required double specialRange,
    required double basicCooldown,
    required double specialCooldown,
  }) {
    final preferred = _preferredCombatDistance(
      family: family,
      attackRange: attackRange,
      specialRange: specialRange,
    );
    final basicBuffer = max(48.0, attackRange - 18.0);
    final specialBuffer = max(basicBuffer, specialRange - 18.0);

    if (specialCooldown <= 0) {
      return min(preferred, specialBuffer);
    }
    return min(preferred, basicBuffer);
  }

  double _combatChaseSpeed(String family, double speedStat) {
    final effectiveSpeed = AlchemonStatSystem.legacyGameplayRating(speedStat);
    final base = 100.0 + (effectiveSpeed * 10.0);
    switch (family.toLowerCase()) {
      case 'horn':
        return base * 1.40;
      case 'mane':
        return base * 1.18;
      case 'mask':
        return base * 1.08;
      case 'wing':
        return base * 1.05;
      default:
        return base;
    }
  }

  double _combatStrafeSpeed(String family, double speedStat) {
    final effectiveSpeed = AlchemonStatSystem.legacyGameplayRating(speedStat);
    final base = 34.0 + effectiveSpeed * 7.0;
    switch (family.toLowerCase()) {
      case 'wing':
      case 'pip':
        return base * 1.55;
      case 'let':
      case 'mystic':
        return base * 1.25;
      case 'horn':
        return base * 0.55;
      default:
        return base;
    }
  }

  double _combatRetreatDistance({
    required String family,
    required double holdDistance,
    required double attackRange,
  }) {
    switch (family.toLowerCase()) {
      case 'horn':
        return max(54.0, min(holdDistance * 0.42, attackRange * 0.48));
      case 'mane':
        return max(64.0, min(holdDistance * 0.52, attackRange * 0.58));
      case 'wing':
      case 'pip':
      case 'let':
      case 'mystic':
        return max(84.0, min(holdDistance * 0.82, attackRange * 0.76));
      default:
        return max(68.0, min(holdDistance * 0.65, attackRange * 0.62));
    }
  }

  int _combatStrafeDirection(String id) {
    final hash = id.codeUnits.fold<int>(0, (acc, c) => acc + c);
    return hash.isEven ? 1 : -1;
  }

  /// Creature-on-creature damage in a duel. Measured with the wild duel
  /// harness so a duel lasts as long as it did before open space moved onto
  /// the shared power model, whose hits outgrew its health pools.
  static const double _duelDamageMultiplier = 0.5;
  static const double _duelDefenseScale = 0.68;

  int _duelDamageAfterDefense(double rawDamage, int defense) {
    return max(
      1,
      (rawDamage *
              _duelDamageMultiplier *
              100 /
              (100 + defense * _duelDefenseScale))
          .round(),
    );
  }

  Offset _updateDuelMovement({
    required Offset actorPos,
    required Offset targetPos,
    Offset? ringCenter,
    required double dt,
    required String family,
    required String idSeed,
    required double speedStat,
    required double holdDistance,
    required double attackRange,
    required double specialRange,
    required double life,
  }) {
    final toTarget = targetPos - actorPos;
    final dist = toTarget.distance;
    if (dist <= 0.001) return actorPos;

    final radialDir = toTarget / dist;
    final retreatDistance = _combatRetreatDistance(
      family: family,
      holdDistance: holdDistance,
      attackRange: attackRange,
    );
    final radialSpeed = _combatChaseSpeed(family, speedStat);
    final strafeSpeed = _combatStrafeSpeed(family, speedStat);
    final strafeDirection = _combatStrafeDirection(idSeed).toDouble();

    var move = Offset.zero;
    if (dist > holdDistance + 10.0) {
      move += radialDir * radialSpeed;
    } else if (dist < retreatDistance) {
      move -= radialDir * (radialSpeed * 0.92);
    } else {
      final tangent = Offset(-radialDir.dy, radialDir.dx) * strafeDirection;
      final weave =
          0.65 + 0.35 * sin(life * (1.4 + speedStat * 0.12) + strafeDirection);
      move += tangent * (strafeSpeed * weave);

      if (dist > holdDistance * 0.96) {
        move += radialDir * (radialSpeed * 0.18);
      } else if (dist < holdDistance * 0.82) {
        move -= radialDir * (radialSpeed * 0.22);
      }
    }

    var nextPos = actorPos + move * dt;

    // Keep a fenced duel inside its circle instead of letting strafe
    // movement drift fighters outward over time. Open-space duels pass no
    // centre and range freely.
    if (ringCenter != null) {
      const ringLimit = 168.0;
      final fromCenter = nextPos - ringCenter;
      final fromCenterDist = fromCenter.distance;
      if (fromCenterDist > ringLimit) {
        nextPos = ringCenter + (fromCenter / fromCenterDist) * ringLimit;
      }
    }

    final minTargetGap = min(attackRange, specialRange) * 0.28;
    final nextToTarget = targetPos - nextPos;
    final nextDist = nextToTarget.distance;
    if (nextDist < minTargetGap && nextDist > 0.001) {
      nextPos = targetPos - (nextToTarget / nextDist) * minTargetGap;
    }

    return nextPos;
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;
    final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
    if (lengthSquared <= 0.0001) return (point - start).distance;
    final t =
        (((point.dx - start.dx) * segment.dx) +
            ((point.dy - start.dy) * segment.dy)) /
        lengthSquared;
    final clampedT = t.clamp(0.0, 1.0);
    final projection = Offset(
      start.dx + segment.dx * clampedT,
      start.dy + segment.dy * clampedT,
    );
    return (point - projection).distance;
  }

  /// After a horn charge ends, re-anchor the companion at its landing spot.
  /// If it landed inside a boss, push it out to the far side so it doesn't
  /// get stuck orbiting on top of the boss.
  void _postChargeReanchor(CosmicCompanion comp) {
    Offset pos = comp.position;

    if (activeBoss != null) {
      final toBoss = activeBoss!.position - pos;
      final dist = toBoss.distance;
      final clearance = activeBoss!.radius + 40.0;
      if (dist < clearance && dist > 0.1) {
        // Push outward from boss center
        final awayDir = (pos - activeBoss!.position) / dist;
        pos = activeBoss!.position + awayDir * clearance;
        comp.position = pos;
      } else if (dist <= 0.1) {
        // Exactly on top — push in the direction the charge was heading
        final chargeDir = Offset(cos(comp.angle), sin(comp.angle));
        pos = activeBoss!.position + chargeDir * clearance;
        comp.position = pos;
      }
    }

    comp.anchorPosition = pos;
  }

  /// [pull] false leaves the body where it stands: a special that holds or
  /// carries its body (a Horn's wind-up, ram or circle, a Wing's Lightning
  /// brew, a Light barrier) owns its position, as in survival, which has no
  /// leash. A charge that carries it too far is still called off below.
  void _enforceCompanionTether(
    CosmicCompanion comp, {
    bool immediate = false,
    double dt = 0,
    bool pull = true,
  }) {
    if (!companionTethered) return;

    final shipPos = ship.pos;
    comp.anchorPosition = immediate
        ? shipPos
        : Offset.lerp(
            comp.anchorPosition,
            shipPos,
            (_companionTetherAnchorFollowSpeed * dt).clamp(0.0, 1.0),
          )!;

    final toComp = comp.position - shipPos;
    final dist = toComp.distance;
    if (pull && dist > _companionTetherHardRadius && dist > 0.001) {
      final returnStep = min(
        _companionTetherReturnSpeed * max(dt, 0.0),
        dist - _companionTetherHardRadius,
      );
      if (returnStep > 0) {
        comp.position -= (toComp / dist) * returnStep;
      }
    }

    if (comp.isCharging && comp.chargeTarget != null) {
      final chargeTargetDist = (comp.chargeTarget! - shipPos).distance;
      // A charge runs through its target and overshoots, so it may end past
      // the engage range while its target sits inside it (targets are
      // allowed by their surface; a boss is up to ~240 across).
      final target = comp.combatTarget;
      final targetRadius = target is CosmicBoss
          ? target.radius
          : target is CosmicEnemy
          ? target.radius
          : 0.0;
      // How far past its target a ram may end is the ram's own: its
      // overshoot, Ice's sideways wall, Dark's long carry.
      if (chargeTargetDist >
          _companionTetherEngageRange +
              targetRadius * 2 +
              comp.chargeLeashAllowance) {
        _releaseCompanionChargeBurst(comp, slam: false);
        comp
          ..chargeTimer = 0
          ..chargeTarget = null
          ..chargeHitIds = null
          ..chargePathType = ''
          ..chargeCircleCenter = null
          ..iceWallTrailTimer = 0
          ..hornDarkCaptured = null;
        comp.specialCooldown = max(
          comp.specialCooldown,
          comp.effectiveSpecialCooldown * 0.35,
        );
      }
    }
  }

  bool _companionTetherAllowsTarget(Offset targetPos, {double radius = 0}) {
    if (!companionTethered || wildDuelActive) return true;
    return (targetPos - ship.pos).distance - radius <=
        _companionTetherEngageRange;
  }

  void _spawnBeamFx(
    Offset start,
    Offset end,
    Color color, {
    String? wingElement,
    double width = 8,
    double life = 0.08,
  }) {
    _beamFx.add(
      _BeamFx(
        start: start,
        end: end,
        color: color,
        width: width,
        life: life,
        wingElement: wingElement,
      ),
    );
    if (_beamFx.length > 42) _beamFx.removeAt(0);
  }

  bool _isPipMember(CosmicPartyMember member, String element) =>
      member.family.toLowerCase() == 'pip' && member.element == element;

  void _tagSource(List<Projectile> projectiles, int? sourceSlotIndex) {
    for (final p in projectiles) {
      p.sourceSlotIndex = sourceSlotIndex;
    }
  }

  CosmicCompanion? _sourceCompanion(Projectile p) {
    final slot = p.sourceSlotIndex;
    if (slot == null) return null;
    final comp = activeCompanions[slot];
    return comp != null && comp.isAlive ? comp : null;
  }

  _GarrisonCreature? _sourceGarrison(Projectile p) {
    final slot = p.sourceSlotIndex;
    if (slot == null) return null;
    for (final g in _garrison) {
      if (g.member.slotIndex == slot && g.hp > 0) return g;
    }
    return null;
  }

  CosmicPartyMember? _sourceMember(Projectile p) =>
      _sourceCompanion(p)?.member ?? _sourceGarrison(p)?.member;

  /// Where a projectile's caster is now, companion or garrison.
  Offset? _sourcePosition(Projectile p) =>
      _sourceCompanion(p)?.position ?? _sourceGarrison(p)?.position;

  /// Every frame, before anything moves: a piece that follows its caster
  /// (Horn Crystal's shards, Kin Spirit's wisp, a Mane Light ring) orbits the
  /// live creature rather than the spot it was cast from, and an attached
  /// piece (Mask Dust's shields, Kin Water's rain cloud, Kin Air's updraft)
  /// rides its host and goes when the host does. Survival does the same for
  /// every projectile.
  void updateAttachedAbilityPieces() {
    for (final p in companionProjectiles) {
      if (p.life <= 0) continue;
      if (p.followSourceCompanion) {
        final host = _sourcePosition(p);
        if (host != null) p.orbitCenter = host;
      }
      if (p.attachedToSlot != -2) {
        final host = _attachHostPosition(p.attachedToSlot);
        if (host != null) {
          p.position = host;
        } else {
          p.life = 0;
        }
      }
    }
  }

  /// Where an attached piece's host is: -1 is the ship, a slot is the
  /// companion or garrison creature in it. Null once the host is gone.
  Offset? _attachHostPosition(int slot) {
    if (slot == -1) return ship.pos;
    final comp = activeCompanions[slot];
    if (comp != null && comp.isAlive && !comp.returning) return comp.position;
    for (final g in _garrison) {
      if (g.member.slotIndex == slot && g.hp > 0) return g.position;
    }
    return null;
  }

  /// A garrison Alchemon attacks on the same rule as a summoned one.
  double _openGarrisonBasicCooldown(_GarrisonCreature g) =>
      alchemonBasicAttackInterval(
        family: g.member.family,
        element: g.member.element,
        cooldownReduction: g.stats.cooldownReduction,
        physAtk: g.stats.physAtk,
        haste: g.basicHasteTimer > 0 ? g.basicHasteMultiplier : 1.0,
        elementPassive: pipElementBasicPassive(
          family: g.member.family,
          element: g.member.element,
          spiritEmpowerTimer: g.pipSpiritEmpowerTimer,
          steamWindowTimer: g.pipSteamWindowTimer,
          steamWindowDuration: CosmicCompanion.pipSteamWindowDuration,
        ),
      );

  double _openGarrisonDamageAmp(_GarrisonCreature g) => g.damageAmpTimer > 0
      ? g.damageAmpMultiplier.clamp(1.0, 4.0).toDouble()
      : 1.0;

  void _tickOpenCompanionIdentity(CosmicCompanion comp, double dt) {
    if (comp.pipSpiritEmpowerTimer > 0) {
      comp.pipSpiritEmpowerTimer = max(0, comp.pipSpiritEmpowerTimer - dt);
    }
    if (comp.damageAmpTimer > 0) {
      comp.damageAmpTimer = max(0, comp.damageAmpTimer - dt);
    }
    if (_isPipMember(comp.member, 'Steam')) {
      comp.pipSteamWindowTimer += dt;
      if (comp.pipSteamWindowTimer >= CosmicCompanion.pipSteamWindowDuration) {
        comp.pipSteamWindowTimer -= CosmicCompanion.pipSteamWindowDuration;
      }
    }
  }

  /// [engaged] is whether the creature is out fighting rather than flying
  /// in formation; Horn Mud trails sludge only then, as survival's does only
  /// off the ship's magnet.
  void _tickOpenFamilyPassives(
    int slotIndex,
    CosmicCompanion comp,
    double dt, {
    bool engaged = true,
  }) {
    // A Fire kin's reborn flame is its support tick's (cosmic_game_kin.dart).
    // Horn's passives are survival's (cosmic_game_horn.dart).
    if (comp.member.family.toLowerCase() == 'horn') {
      _tickOpenHornPassive(comp, dt, engaged: engaged);
    }
  }

  void _tickOpenGarrisonIdentity(_GarrisonCreature g, double dt) {
    if (g.pipSpiritEmpowerTimer > 0) {
      g.pipSpiritEmpowerTimer = max(0, g.pipSpiritEmpowerTimer - dt);
    }
    if (g.damageAmpTimer > 0) {
      g.damageAmpTimer = max(0, g.damageAmpTimer - dt);
    }
    if (_isPipMember(g.member, 'Steam')) {
      g.pipSteamWindowTimer += dt;
      if (g.pipSteamWindowTimer >= CosmicCompanion.pipSteamWindowDuration) {
        g.pipSteamWindowTimer -= CosmicCompanion.pipSteamWindowDuration;
      }
    }
  }

  /// [slam] is false when the charge is cut short (tether) rather than landed.
  void _releaseCompanionChargeBurst(CosmicCompanion comp, {bool slam = true}) {
    final pending = comp.pendingChargeBurst;
    if (pending == null) return;
    if (slam) {
      pushHornFx(
        _hornFx,
        HornFx.slam(
          position: comp.position,
          angle: comp.angle,
          radius: comp.chargeFinalSweepRadius,
          element: comp.member.element,
        ),
      );
      _soundHornSlam(comp.member.element);
    }
    final delta = comp.position - (comp.pendingChargeOrigin ?? comp.position);
    for (final p in pending) {
      p.position += delta;
      p.sourceSlotIndex = comp.member.slotIndex;
    }
    companionProjectiles.addAll(pending);
    comp.pendingChargeBurst = null;
    comp.pendingChargeOrigin = null;
  }

  void _releaseGarrisonChargeBurst(_GarrisonCreature g) {
    final pending = g.pendingChargeBurst;
    if (pending == null) return;
    pushHornFx(
      _hornFx,
      HornFx.slam(
        position: g.position,
        angle: g.faceAngle,
        radius: g.chargeFinalSweepRadius,
        element: g.member.element,
      ),
    );
    _soundHornSlam(g.member.element);
    final delta = g.position - (g.pendingChargeOrigin ?? g.position);
    for (final p in pending) {
      p.position += delta;
      p.sourceSlotIndex = g.member.slotIndex;
    }
    companionProjectiles.addAll(pending);
    g.pendingChargeBurst = null;
    g.pendingChargeOrigin = null;
  }

  double _openSourceElementPower(Projectile p) {
    final comp = _sourceCompanion(p);
    if (comp != null) return comp.abilityAtk.toDouble();
    final g = _sourceGarrison(p);
    if (g != null) return g.specialDamage;
    return max(4.0, p.damage);
  }

  void _spawnOpenPipKillPlacement(
    Projectile source,
    CosmicPartyMember member,
    Offset position,
  ) {
    if (member.family.toLowerCase() != 'pip') return;
    // Per the design board, as Survival gates it: Fire, Dust and Crystal
    // placements come from the special's kills; Dark is the passive that
    // fires on every other kill.
    final fromPipSpecial =
        source.abilityFamily == 'pip' &&
        source.visualStyle == ProjectileVisualStyle.dart;
    final allowedBySource = switch (member.element) {
      'Dark' => !fromPipSpecial,
      'Fire' || 'Dust' || 'Crystal' => fromPipSpecial,
      _ => true,
    };
    if (!allowedBySource) return;
    final scale = _openSourceElementPower(source) * 0.20 + 4.0;
    switch (member.element) {
      case 'Fire':
        companionProjectiles.add(
          Projectile(
            position: position,
            angle: 0,
            element: 'Fire',
            damage: 0,
            life: 4.5,
            speedMultiplier: 0,
            stationary: true,
            piercing: true,
            radiusMultiplier: 1.6,
            visualScale: 1.4,
            visualStyle: ProjectileVisualStyle.sigil,
            sourceSlotIndex: source.sourceSlotIndex,
            abilityFamily: 'pip',
            tickEffect: AbilityEffectKind.burn,
            effectPower: scale * 0.45,
            effectRadius: 60,
            effectDuration: 4.5,
          ),
        );
        break;
      case 'Dust':
        companionProjectiles.add(
          Projectile(
            position: position,
            angle: 0,
            element: 'Dust',
            damage: 0,
            life: 3.5,
            speedMultiplier: 0,
            stationary: true,
            piercing: true,
            radiusMultiplier: 1.4,
            visualScale: 1.3,
            visualStyle: ProjectileVisualStyle.sigil,
            sourceSlotIndex: source.sourceSlotIndex,
            abilityFamily: 'pip',
            tickEffect: AbilityEffectKind.slow,
            effectPower: scale * 0.18,
            effectRadius: 70,
            effectDuration: 1.6,
          ),
        );
        break;
      case 'Crystal':
        companionProjectiles.add(
          Projectile(
            position: position,
            angle: 0,
            element: 'Crystal',
            damage: 0,
            life: 9.0,
            speedMultiplier: 0,
            stationary: true,
            piercing: true,
            decoy: true,
            decoyHp: 18.0 + _openSourceElementPower(source) * 0.6,
            tauntRadius: 130,
            tauntStrength: 3.6,
            effectRadius: 38,
            radiusMultiplier: 0.7,
            visualScale: 0.75,
            visualStyle: ProjectileVisualStyle.sigil,
            sourceSlotIndex: source.sourceSlotIndex,
            abilityFamily: 'pip',
          ),
        );
        break;
      case 'Dark':
        // Pip+Dark never casts; the void opening is its special's sound.
        onSound?.call(SoundCue.specialPipVoid);
        companionProjectiles.add(
          Projectile(
            position: position,
            angle: 0,
            element: 'Dark',
            damage: 0,
            life: 3.6,
            speedMultiplier: 0,
            stationary: true,
            piercing: true,
            radiusMultiplier: 1.5,
            visualScale: 1.4,
            visualStyle: ProjectileVisualStyle.sigil,
            sourceSlotIndex: source.sourceSlotIndex,
            abilityFamily: 'pip',
            tickEffect: AbilityEffectKind.blackHole,
            effectPower: scale * 0.32,
            effectRadius: 120,
            effectDuration: 3.6,
          ),
        );
        break;
    }
  }

  void _applyOpenKillIdentityHooks(Projectile source, CosmicEnemy enemy) {
    // What any kill sets off — a Mane Plant root, a Spirit kin's wisp — is
    // the same however the kill was made (cosmic_game_kin.dart).
    _onOpenKill(source.sourceSlotIndex, enemy);
    final member = _sourceMember(source);
    if (member == null) return;
    final family = member.family.toLowerCase();
    // Any kill a Horn's hits make inside its special's window (a basic, a
    // Lava flame) pays the cast's kill effect, as in survival.
    if (family == 'horn') _creditHornKill(_sourceCompanion(source), enemy);
    if (family == 'pip') {
      _spawnOpenPipKillPlacement(source, member, enemy.position);
      if (member.element == 'Spirit') {
        final comp = _sourceCompanion(source);
        final g = _sourceGarrison(source);
        if (comp != null) {
          comp.abilityKillStacks++;
          if (comp.abilityKillStacks >= 8) {
            comp.abilityKillStacks = 0;
            comp.pipSpiritEmpowerTimer = max(comp.pipSpiritEmpowerTimer, 6.0);
            _spawnHitSpark(comp.position, elementColor('Spirit'));
          }
        } else if (g != null) {
          g.abilityKillStacks++;
          if (g.abilityKillStacks >= 8) {
            g.abilityKillStacks = 0;
            g.pipSpiritEmpowerTimer = max(g.pipSpiritEmpowerTimer, 6.0);
            _spawnHitSpark(g.position, elementColor('Spirit'));
          }
        }
      }
      if (member.element == 'Water' && source.bounceCount <= 0) {
        for (final target in enemies) {
          if (target.dead || identical(target, enemy)) continue;
          if ((target.position - enemy.position).distance <= 160) {
            _damageOpenEnemy(target, source.damage * 2.4, element: 'Water');
          }
        }
        _spawnHitSpark(enemy.position, elementColor('Water'));
      }
    } else if (family == 'mask' && member.element == 'Spirit') {
      final comp = _sourceCompanion(source);
      final g = _sourceGarrison(source);
      if (comp != null) {
        comp.abilityKillStacks++;
        if (comp.abilityKillStacks >= 6) {
          comp.abilityKillStacks = 0;
          _openSpiritMaskBurst(comp.position, comp.abilityAtk * 1.6, member);
        }
      } else if (g != null) {
        g.abilityKillStacks++;
        if (g.abilityKillStacks >= 6) {
          g.abilityKillStacks = 0;
          _openSpiritMaskBurst(g.position, g.specialDamage * 1.6, member);
        }
      }
    }
  }

  void _openSpiritMaskBurst(
    Offset center,
    double damage,
    CosmicPartyMember member,
  ) {
    for (final target in enemies) {
      if (target.dead) continue;
      if ((target.position - center).distance <= 220) {
        _damageOpenEnemy(target, damage, element: member.element);
      }
    }
    // Enemies only, as Survival's burst: the boss is not in the list.
    _spawnHitSpark(center, elementColor('Spirit'));
  }

  void _applyOpenBasicHitIdentityHooks(
    Projectile p,
    CosmicEnemy enemy, {
    required bool killed,
  }) {
    final member = _sourceMember(p);
    if (member == null || member.family.toLowerCase() != 'pip') return;
    // Mud's trail comes from the basic attack; Poison's web from the
    // special's darts, as Survival lays them.
    final isBasic = p.abilityFamily.isEmpty;
    final isPipSpecialDart =
        p.abilityFamily == 'pip' && p.visualStyle == ProjectileVisualStyle.dart;
    if (isBasic && p.element == 'Mud' && !killed) {
      enemy.pipMudTrail = true;
      enemy.pipMudTrailTimer = max(enemy.pipMudTrailTimer, 0.2);
    } else if (isPipSpecialDart && p.element == 'Poison') {
      final comp = _sourceCompanion(p);
      final g = _sourceGarrison(p);
      final prev = comp?.lastPipPoisonHitPos ?? g?.lastPipPoisonHitPos;
      if (prev != null) {
        final delta = enemy.position - prev;
        final dist = delta.distance;
        if (dist < 600) {
          final segCount = (dist / 36).ceil().clamp(1, 18);
          for (var s = 0; s < segCount; s++) {
            final t = (s + 0.5) / segCount;
            companionProjectiles.add(
              Projectile(
                position: Offset(
                  prev.dx + delta.dx * t,
                  prev.dy + delta.dy * t,
                ),
                angle: 0,
                element: 'Poison',
                damage: 0,
                life: 6.5,
                speedMultiplier: 0,
                stationary: true,
                piercing: true,
                radiusMultiplier: 0.95,
                visualScale: 0.85,
                visualStyle: ProjectileVisualStyle.sigil,
                sourceSlotIndex: p.sourceSlotIndex,
                abilityFamily: 'pip',
                tickEffect: AbilityEffectKind.poison,
                effectPower: p.damage * 0.22,
                effectRadius: 32,
                effectDuration: 1.5,
              ),
            );
          }
        }
      }
      if (comp != null) comp.lastPipPoisonHitPos = enemy.position;
      if (g != null) g.lastPipPoisonHitPos = enemy.position;
    }
  }

  /// Pip Poison's web lasts until the next cast: a new special clears the
  /// caster's old lines and starts a fresh web from its first hit.
  void _clearPipPoisonWeb(CosmicPartyMember member) {
    if (member.family.toLowerCase() != 'pip' || member.element != 'Poison') {
      return;
    }
    for (final existing in companionProjectiles) {
      if (existing.sourceSlotIndex == member.slotIndex &&
          existing.abilityFamily == 'pip' &&
          existing.element == 'Poison' &&
          existing.stationary) {
        existing.life = 0;
      }
    }
    for (final comp in activeCompanions.values) {
      if (identical(comp.member, member)) comp.lastPipPoisonHitPos = null;
    }
    for (final g in _garrison) {
      if (identical(g.member, member)) g.lastPipPoisonHitPos = null;
    }
  }

  CosmicEnemy? _nearestOpenEnemy(Offset origin, double range) {
    CosmicEnemy? target;
    var best = range;
    for (final enemy in enemies) {
      if (enemy.dead) continue;
      final d = (enemy.position - origin).distance;
      if (d < best) {
        best = d;
        target = enemy;
      }
    }
    return target;
  }

  /// A puff of the mud a Pip Mud-marked body trails, slowing what follows.
  Projectile _pipMudTrailPuff(Offset at) => Projectile(
    position: at,
    angle: 0,
    element: 'Mud',
    damage: 0,
    life: 5.5,
    speedMultiplier: 0,
    stationary: true,
    piercing: true,
    radiusMultiplier: 1.1,
    visualScale: 1.0,
    visualStyle: ProjectileVisualStyle.sigil,
    abilityFamily: 'pip',
    tickEffect: AbilityEffectKind.slow,
    effectPower: 1.0,
    effectRadius: 38,
    effectDuration: 1.2,
  );

  /// Adds a shove along [direction]. [byMass] makes heavier tiers take less,
  /// as Survival's area shoves (Let Air's gust) do; contact knockback does
  /// not scale.
  void _knockOpenEnemy(
    CosmicEnemy enemy,
    Offset direction,
    double force, {
    bool byMass = false,
  }) {
    final d = direction.distance;
    if (d <= 0.01 || force <= 0) return;
    final impulse = byMass
        ? force * CosmicAbilityRuntime.knockbackMassScale(enemy.tier)
        : force;
    enemy.knockbackVelocity += direction / d * impulse;
  }

  /// Crowd control on a body, as Survival applies it: a timed slow at the
  /// effect's strength (root holds it still, freeze very nearly), and a
  /// frozen or rooted body stops being carried by a shove. Suppressing shots
  /// does nothing to a body that never fires, and open space's roaming
  /// bodies do not.
  void _crowdControlOpenEnemy(
    CosmicEnemy enemy,
    AbilityEffectKind effect,
    double duration,
  ) {
    switch (effect) {
      case AbilityEffectKind.slow:
      case AbilityEffectKind.freeze:
      case AbilityEffectKind.root:
      case AbilityEffectKind.stun:
        enemy.applySlow(
          CosmicAbilityRuntime.survivalSlowMultiplier(effect),
          CosmicAbilityRuntime.survivalCrowdControlDuration(effect, duration),
        );
        if (effect == AbilityEffectKind.freeze ||
            effect == AbilityEffectKind.root) {
          enemy.knockbackVelocity = Offset.zero;
        }
      default:
        break;
    }
  }

  void _integrateEnemyKnockback(CosmicEnemy enemy, double dt) {
    final v = enemy.knockbackVelocity;
    if (v == Offset.zero) return;
    enemy.position += v * dt;
    final next = v * exp(-CosmicAbilityRuntime.knockbackDamping * dt);
    enemy.knockbackVelocity =
        next.distance < CosmicAbilityRuntime.knockbackRestSpeed
        ? Offset.zero
        : next;
  }

  /// [sourceSlot], when given, is whose kill it is: a kill then sets off
  /// what any kill credited to that slot does (see [_onOpenKill]).
  bool _damageOpenEnemy(
    CosmicEnemy enemy,
    double damage, {
    String? element,
    int? sourceSlot,
  }) {
    if (enemy.dead) return false;
    // An Alchemon standing in as a body is never killed by an ability; the
    // instant kill is booked as a heavy hit (cosmic_game_duel.dart).
    if (damage >= enemy.health && _bookExecute(enemy)) return false;
    final wasAlive = enemy.health > 0;
    enemy.health -= damage;
    final killed = wasAlive && enemy.health <= 0;
    if (killed) {
      enemy.dead = true;
      _spawnKillVfx(
        enemy.position,
        elementColor(element ?? enemy.element),
        enemy.radius,
        false,
      );
      _spawnLootDrops(
        enemy.position,
        enemy.element,
        enemy.shardDrop,
        enemy.particleDrop,
      );
      if (sourceSlot != null) _onOpenKill(sourceSlot, enemy);
    }
    return killed;
  }

  void _damageOpenBoss(double damage, {String? element}) {
    final boss = activeBoss;
    if (boss == null || boss.dead) return;
    if (boss.shieldUp &&
        (boss.type == BossType.gunner || boss.type == BossType.bulwark)) {
      boss.shieldHealth -= damage;
      if (boss.shieldHealth <= 0) {
        boss.shieldUp = false;
        boss.shieldTimer = CosmicBoss.shieldCooldown;
      }
      _spawnHitSpark(boss.position, Colors.cyanAccent);
      return;
    }
    boss.health -= damage;
    _spawnHitSpark(boss.position, elementColor(element ?? boss.element));
    if (boss.health <= 0) _handleBossKill(boss);
  }

  void _applyOpenWingEffect(
    AbilityEffectKind effect,
    CosmicEnemy enemy,
    Offset origin,
    double power,
    double radius,
    double duration,
  ) {
    if (effect == AbilityEffectKind.none || enemy.dead) return;
    switch (effect) {
      case AbilityEffectKind.knockback:
        _knockOpenEnemy(
          enemy,
          enemy.position - origin,
          CosmicAbilityRuntime.knockbackImpulse(power),
        );
        break;
      case AbilityEffectKind.slow:
      case AbilityEffectKind.root:
      case AbilityEffectKind.freeze:
      case AbilityEffectKind.stun:
      case AbilityEffectKind.suppressShooting:
        _crowdControlOpenEnemy(enemy, effect, duration);
        if (effect == AbilityEffectKind.root) _damageOpenEnemy(enemy, power);
        break;
      case AbilityEffectKind.pull:
      case AbilityEffectKind.blackHole:
        for (final other in enemies) {
          if (other.dead) continue;
          final dir = origin - other.position;
          final dist = dir.distance;
          if (dist > 0.01 && dist <= radius) {
            other.position += (dir / dist) * min(22.0, radius / 14.0);
          }
          if (effect == AbilityEffectKind.blackHole &&
              other.health / other.maxHealth <= 0.12) {
            _damageOpenEnemy(other, other.health + 1);
          }
        }
        break;
      case AbilityEffectKind.execute:
        final execute = enemy.health / enemy.maxHealth <= 0.20;
        _damageOpenEnemy(enemy, execute ? enemy.health + 1 : power);
        break;
      case AbilityEffectKind.splash:
      case AbilityEffectKind.split:
      case AbilityEffectKind.chain:
        for (final other in enemies) {
          if (other.dead || identical(other, enemy)) continue;
          if ((other.position - enemy.position).distance <= radius) {
            _damageOpenEnemy(
              other,
              power * CosmicAbilityRuntime.splashMultiplier(effect),
            );
          }
        }
        break;
      case AbilityEffectKind.leech:
      case AbilityEffectKind.zoneHeal:
        shipHealth = min(shipMaxHealth, shipHealth + power * 0.35);
        _damageOpenEnemy(enemy, power * 0.45);
        break;
      case AbilityEffectKind.flower:
      case AbilityEffectKind.alchemyBonus:
        break;
      case AbilityEffectKind.burn:
      case AbilityEffectKind.poison:
      case AbilityEffectKind.zoneDamage:
      case AbilityEffectKind.geyser:
      case AbilityEffectKind.refraction:
      case AbilityEffectKind.chargeBlast:
        _damageOpenEnemy(enemy, power);
        break;
      case AbilityEffectKind.buff:
      case AbilityEffectKind.cooldownRefund:
      case AbilityEffectKind.taunt:
      case AbilityEffectKind.carry:
      case AbilityEffectKind.none:
        break;
    }
  }

  // ── update loop ────────────────────────────────────────

  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (_tearWild != null || _tearCloseT >= 0) dt = _tickPortalTear(dt);
    _elapsed += dt;
    // The party's abilities touch the wild Alchemon being fought as they
    // touch any body, but only while they resolve: the ship's guns, enemy AI
    // and the spawner never see it in the enemy list.
    _admitWildBody();
    _ageBeamFx(dt);
    _updateOpenWingBeams(dt);
    _updateWingFlowers(dt);
    _updateKinFlowers(dt);
    updateAttachedAbilityPieces();
    updateMaskRuntime(dt);
    _updateMaskVisuals(dt);
    _releaseWildBody();
    updateLetSkyfallImpacts(_letSkyfallImpacts, dt);
    updateLetFx(_letFx, dt);
    updateHornFx(_hornFx, dt);
    updateKinLaserBeams(_kinLaserBeams, dt);

    // ── zoom animation ──
    if (!_zoomAnimComplete) {
      _zoomAnimTimer += dt;
      final t = (_zoomAnimTimer / _zoomAnimDuration).clamp(0.0, 1.0);
      final ease = 1.0 - pow(1.0 - t, 3).toDouble(); // ease-out cubic
      _currentZoom = _zoomAnimFrom + (_zoomAnimTo - _zoomAnimFrom) * ease;
      if (t >= 1.0) {
        _currentZoom = _zoomAnimTo;
        _zoomAnimComplete = true;
      }
    }

    // The camera eases back while a contest plays, so the whole arena is in
    // view, and forward again after.
    final contestTarget = _beautyContestCinematicActive ? 1.0 : 0.0;
    _contestPullBack += (contestTarget - _contestPullBack) * min(1.0, dt * 2.6);
    if ((_contestPullBack - contestTarget).abs() < 0.002) {
      _contestPullBack = contestTarget;
    }

    final ritual = _bloodRitual;
    _bloodFlow += dt * (1 + 5 * pow(ritual ?? 0, 2));
    final armed = activeCompanions.values.any(
      (c) =>
          c.member.element.toLowerCase() == 'blood' &&
          c.member.family.toLowerCase() == 'mystic',
    );
    _bloodArmed += ((armed ? 1 : 0) - _bloodArmed) * min(1.0, dt * 1.5);
    if (ritual != null) {
      // The world holds still for the ritual; only the ring moves.
      _riftPulse += dt;
      _bloodFrame += (1 - _bloodFrame) * min(1.0, dt * 1.4);
      _camPan =
          (bloodRing.position - ship.pos) *
          Curves.easeInOut.transform(_bloodFrame);
      return;
    }

    if (_beautyContestCinematicActive) {
      _updateBeautyContestCinematic(dt);
      return;
    }

    // ── ship movement ──
    double baseSpeed = _shipDead
        ? 0.0
        : 220.0 * StarDust.speedMultiplier(collectedDustCount);

    // Apply boost if booster is equipped and player is holding boost
    final boostWasActive = isBoosting;
    isBoosting = false;
    final matterWasBurning = boostingOnMatter;
    boostingOnMatter = false;
    if (boosting && !_shipDead) {
      var fuelUsed = shipFuel.consume(boostFuelPerSecond * dt);
      if (fuelUsed <= 0 && hasMatterInjector) {
        // Dry tank, injector fitted. Rather than the booster simply dying
        // mid-hold, it feeds on the raw matter in the hold — the ship can
        // always get home, it just arrives with less than it caught.
        fuelUsed = meter.drain(boostMeterPerSecond * dt);
        if (fuelUsed > 0) boostingOnMatter = true;
      }
      if (fuelUsed > 0) {
        baseSpeed *= boostSpeedMultiplier;
        isBoosting = true;
      }
    }
    if (isBoosting != boostWasActive) onBoostActiveChanged?.call(isBoosting);
    // The meter is spent as the ship burns it, so the HUD has to fall with
    // it — not jump once on release.
    if (boostingOnMatter) {
      _matterBoostHudTimer -= dt;
      if (_matterBoostHudTimer <= 0) {
        _matterBoostHudTimer = 0.1;
        onMeterChanged();
      }
    } else if (matterWasBurning) {
      _matterBoostHudTimer = 0;
      onMeterChanged();
    }
    if (isBoosting && !_boostTrailWasActive) {
      _boostTrailVisual = 1.0;
    }
    final boostTrailTarget = isBoosting
        ? (boostingOnMatter ? meter.fillPct : shipFuel.fraction)
        : 0.0;
    final boostTrailStep = (isBoosting ? 0.9 : 1.8) * dt;
    if (_boostTrailVisual > boostTrailTarget) {
      _boostTrailVisual = max(
        boostTrailTarget,
        _boostTrailVisual - boostTrailStep,
      );
    } else if (_boostTrailVisual < boostTrailTarget) {
      _boostTrailVisual = min(
        boostTrailTarget,
        _boostTrailVisual + boostTrailStep,
      );
    }
    _boostTrailWasActive = isBoosting;
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
    _clampShipToSandboxArena();

    // ── reveal fog ──
    _revealAround(ship.pos, 280);

    // ── discover planets ──
    var discoveredPlanetThisFrame = false;
    for (var i = 0; i < world_.planets.length; i++) {
      final p = world_.planets[i];
      if (!p.discovered) {
        final dist = (p.position - ship.pos).distance;
        if (dist < p.radius + 200) {
          p.discovered = true;
          discoveredPlanetThisFrame = true;
          if (_planetScannerTargetIndex == i) {
            _planetScannerTargetIndex = null;
          }
          // Guarantee a boss on first discovery
          _spawnDiscoveryBoss(p);
        }
      }
    }
    if (discoveredPlanetThisFrame) {
      syncPlanetScannerAvailability();
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
          poi.type != POIType.stardustScanner &&
          poi.type != POIType.planetScanner &&
          poi.type != POIType.goldConversion &&
          poi.type != POIType.survivalPortal) {
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
      if (dx * dx + dy * dy <
          _planetRecipeParticlePickupRadius *
              _planetRecipeParticlePickupRadius) {
        // Collected! Silent when the meter is full: nothing went in, and a
        // pickup sound over a hold that cannot take it is a lie.
        if (!meter.isFull) {
          meter.add(p.element, 0.5 * _meterPickupMultiplier);
          onMeterChanged();
          onSound?.call(SoundCue.cosmicMatterCollect);
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
            onSound?.call(SoundCue.cosmicMatterCollect);
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
        ? 0.12
        : shootInterval;
    // An auto weapon needs something to shoot at; a manual one fires wherever
    // the nose is pointing, so it is only looked up when a weapon wants it.
    final wantsTarget =
        (shooting && autoAimGun) || (shootingMissiles && autoAimMissiles);
    final autoTarget = wantsTarget && !_shipDead
        ? _nearestEnemyWithin(ship.pos, autoFireRange)
        : null;
    // On auto the trigger is an armed state, so holding fire over empty space
    // is the point of it. On manual the trigger is a trigger.
    final gunFiring = shooting && (!autoAimGun || autoTarget != null);
    if (gunFiring && !_shipDead && _shootCooldown <= 0) {
      _shootCooldown = fireRate;
      final angle = autoAimGun && autoTarget != null
          ? atan2(autoTarget.dy - ship.pos.dy, autoTarget.dx - ship.pos.dx)
          : ship.angle;
      onSound?.call(SoundCue.shipBolt);
      projectiles.add(
        Projectile(
          position: Offset(
            ship.pos.dx + cos(angle) * 20,
            ship.pos.dy + sin(angle) * 20,
          ),
          angle: angle,
        ),
      );
    }

    // ── missile launcher (secondary weapon, fires independently) ──
    if (_missileShootCooldown > 0) _missileShootCooldown -= dt;
    // Missiles home, so a manual launch still finds its own way; auto only
    // spends one when there is something in range worth spending it on.
    final missilesFiring =
        shootingMissiles && (!autoAimMissiles || autoTarget != null);
    if (missilesFiring &&
        hasMissiles &&
        !_shipDead &&
        _missileShootCooldown <= 0) {
      if (missileAmmo > 0) {
        _missileShootCooldown = 0.85;
        missileAmmo--;
        onSound?.call(SoundCue.shipMissile);
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
      bool missileHit = false;
      for (final e in enemies) {
        if (e.dead) continue;
        final edx = m.position.dx - e.position.dx;
        final edy = m.position.dy - e.position.dy;
        if (edx * edx + edy * edy < (e.radius + 6) * (e.radius + 6)) {
          e.health -= HomeCustomizationState.missileHitDamage(
            level: missileUpgradeLevel,
            vsBoss: false,
          );
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
          if (boss.shieldUp &&
              (boss.type == BossType.gunner || boss.type == BossType.bulwark)) {
            boss.shieldHealth -= HomeCustomizationState.missileHitDamage(
              level: missileUpgradeLevel,
              vsBoss: true,
            );
            _spawnHitSpark(m.position, Colors.cyanAccent);
            if (boss.shieldHealth <= 0) {
              boss.shieldUp = false;
              boss.shieldTimer = CosmicBoss.shieldCooldown;
            }
          } else {
            boss.health -= HomeCustomizationState.missileHitDamage(
              level: missileUpgradeLevel,
              vsBoss: true,
            );
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
            orbitals[i].health -= 0.4;
            e.health -= 2.2 * CosmicBalance.spaceWorldScale;
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
      final isMachineGun = activeWeaponId == 'equip_machinegun';
      final projDmg = HomeCustomizationState.shipProjectileAsteroidDamage(
        level: ammoUpgradeLevel,
        machineGun: isMachineGun,
      );
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
            final eDmg = HomeCustomizationState.shipProjectileHitDamage(
              level: ammoUpgradeLevel,
              machineGun: isMachineGun,
            );
            enemy.health -= eDmg * maskShipDamageAmp;
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

      // ── projectile vs a wild Alchemon you are fighting ──
      // Only the one in a duel takes fire. Grazing ones are not targets, so
      // a stray shot at an enemy never starts a fight the player did not ask
      // for.
      if (i < projectiles.length && projectiles[i] == p) {
        final opp = duelOpponent;
        if (wildDuelActive && opp != null && opp.isAlive) {
          final odx = p.position.dx - opp.position.dx;
          final ody = p.position.dy - opp.position.dy;
          final oHitR = 18.0 + Projectile.radius;
          if (odx * odx + ody * ody < oHitR * oHitR) {
            final projDmg = HomeCustomizationState.shipProjectileHitDamage(
              level: ammoUpgradeLevel,
              machineGun: isMachineGun,
            );
            opp.takeDamage(
              _duelDamageAfterDefense(
                projDmg * _wildShipShotScale,
                opp.physDef,
              ),
            );
            _spawnHitSpark(p.position, elementColor(opp.member.element));
            projectiles.removeAt(i);
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
          final projBossDmg = HomeCustomizationState.shipProjectileHitDamage(
            level: ammoUpgradeLevel,
            machineGun: isMachineGun,
          );
          if (boss.shieldUp &&
              (boss.type == BossType.gunner || boss.type == BossType.bulwark)) {
            boss.shieldHealth -= projBossDmg * maskShipDamageAmp;
            _spawnHitSpark(p.position, Colors.cyanAccent);
            projectiles.removeAt(i);
            if (boss.shieldHealth <= 0) {
              boss.shieldUp = false;
              boss.shieldTimer = CosmicBoss.shieldCooldown;
            }
          } else {
            boss.health -= projBossDmg * maskShipDamageAmp;
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
    _admitWildBody();
    // Keep the party in the ship's frame across the world's wrapped edge.
    for (final comp in activeCompanions.values) {
      comp.position = _nearestImage(comp.position, ship.pos);
    }
    _planCompanionMotion(dt);
    final companionsToRemove = <int>[];
    for (final entry in activeCompanions.entries.toList()) {
      final slot = entry.key;
      final comp = entry.value;
      comp.life += dt;
      comp.invincibleTimer = (comp.invincibleTimer - dt).clamp(0.0, 10.0);

      // Advance sprite animation
      _companionTickers[slot]?.update(dt);

      // Returning fade-out
      if (comp.returning) {
        comp.returnTimer -= dt;
        if (comp.returnTimer <= 0) {
          companionsToRemove.add(slot);
          _companionTickers.remove(slot);
          _companionVisualsBySlot.remove(slot);
          _companionSpriteScales.remove(slot);
          _companionGrains.remove(slot);
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
        companionsToRemove.add(slot);
        _companionTickers.remove(slot);
        _companionVisualsBySlot.remove(slot);
        _companionSpriteScales.remove(slot);
        _companionGrains.remove(slot);
        onCompanionDied?.call(diedMember);
      } else {
        // Auto-return if companion is far off screen (skip mid-duel)
        final margin = 350.0;
        final dx = (comp.position.dx - ship.pos.dx).abs();
        final dy = (comp.position.dy - ship.pos.dy).abs();
        if (!wildDuelActive &&
            sandboxArenaRadius == null &&
            (dx > size.x / (2 * cameraZoom) + margin ||
                dy > size.y / (2 * cameraZoom) + margin)) {
          comp.returning = true;
          comp.returnTimer = 0.6;
          onCompanionAutoReturned?.call(comp.member);
        } else {
          // A Horn special holding its body — a ram, a wind-up, Lightning's
          // brew — owns the frame, as in survival: the body holds still or
          // rams, and its cooldowns, timers, passives, basics and special
          // wait (cosmic_game_horn.dart).
          if (_updateHornPhases(comp, dt)) {
            _enforceCompanionTether(comp, dt: dt, pull: false);
          } else {
            if (comp.basicHasteTimer > 0) {
              comp.basicHasteTimer = max(0.0, comp.basicHasteTimer - dt);
              if (comp.basicHasteTimer <= 0) {
                comp.basicHasteMultiplier = 1.0;
              }
            }
            _tickOpenCompanionIdentity(comp, dt);
            _tickOpenFamilyPassives(
              slot,
              comp,
              dt,
              engaged:
                  !companionTethered || _companionEngagements[slot] != null,
            );
            // A Light horn holds its ground, both cooldowns waiting, while
            // its barrier stands.
            final lightHeld = _hornLightChanneling(comp);
            if (!lightHeld) {
              comp.basicCooldown = (comp.basicCooldown - dt).clamp(0.0, 100.0);
              comp.specialCooldown = (comp.specialCooldown - dt).clamp(
                0.0,
                100.0,
              );
            }

            // Fly to its place in the follow formation, or its station in
            // the fight (cosmic_game_companion_motion.dart). A Wing charging
            // its beam holds where it committed (cosmic_game_wing.dart).
            final held = _heldByWingCharge(comp) || lightHeld;
            // A Kin holds still while it gathers its laser, charges its Ice
            // or channels its tesla (cosmic_game_kin.dart); the tether
            // still reels it in.
            final kinHeld = _kinHoldsBody(
              comp,
              comp.member,
              engaged: _companionEngagements[slot] != null,
            );
            if (held || kinHeld) {
              comp.velocity = Offset.zero;
              comp.steerGoal = null;
            } else {
              _steerCompanion(slot, comp, dt);
            }
            _enforceCompanionTether(comp, dt: dt, pull: !held);

            _tickCompanionBlessing(comp, dt);

            final engagement = _companionEngagements[slot];
            if (engagement != null) {
              final targetPos = engagement.position;
              // Face target (for sprite flipping & shooting direction)
              final toTarget = targetPos - comp.position;
              comp.angle = atan2(toTarget.dy, toTarget.dx);
              // Reach is measured to the target's hitbox, not its centre. A
              // boss is up to ~240 across: its centre can sit out of range
              // while its edge is well inside it.
              final distToTarget = max(
                0.0,
                toTarget.distance - engagement.hitRadius,
              );
              // Unlinked, it holds whatever ground the fight carries it to.
              if (!companionTethered) comp.anchorPosition = comp.position;
              // Basic attack — family-specific pattern. A Kin's is a charged
              // laser (cosmic_game_kin.dart).
              if (_isKinMember(comp.member)) {
                _tickOpenKinChargedAuto(comp, targetPos, distToTarget, dt);
              } else if (comp.basicCooldown <= 0 &&
                  distToTarget <= comp.attackRange) {
                _fireCompanionBasic(comp);
              }

              // Special attack. Each family has a unique ability, flavored by
              // element.
              if (_companionSpecialReady(comp) &&
                  distToTarget <= comp.specialAbilityRange) {
                _castCompanionSpecial(comp, targetPos);
              }
            } else {
              // Nothing to fight: face the way it is flying, or the ship's way
              // once it has settled into its place.
              comp.angle = comp.velocity.distance > 30
                  ? atan2(comp.velocity.dy, comp.velocity.dx)
                  : _formationHeading;
            }
          }

          // Companion takes damage from enemies that touch it
          for (final e in enemies) {
            if (e.dead || _isCombatBody(e)) continue;
            final d = (e.position - comp.position).distance;
            if (d < e.radius + 15) {
              final contactDmg = CosmicBalance.enemyCompanionContactDamage(
                e.tier,
              );
              _openCompanionIncomingDamage(
                comp,
                contactDmg * 100 / (100 + comp.physDef),
              );
              _spawnHitSpark(comp.position, elementColor(e.element));
            }
          }
        }
      }
    }
    for (final slot in companionsToRemove) {
      activeCompanions.remove(slot);
    }
    _updateOpenKinSupports(dt);
    _releaseWildBody();

    // ── update the wild Alchemon being fought ──
    // It moves by the duel's steering; everything else it does is a
    // companion's turn, taken on its own side (cosmic_game_duel.dart).
    if (duelOpponent != null && wildDuelActive) {
      final opp = duelOpponent!;
      opp.life += dt;
      opp.invincibleTimer = (opp.invincibleTimer - dt).clamp(0.0, 10.0);
      _duelOpponentTicker?.update(dt);

      // A wild Fire kin's phoenix catches it once, as a party one catches
      // the ship (cosmic_game_kin.dart).
      if (opp.currentHp <= 0 && !_tryWildKinPhoenixSave(opp)) {
        // Beaten, not killed: it collapses and can be rammed.
        _endWildDuel(WildDuelEnd.exhausted);
      } else if (_shipDead) {
        _endWildDuel(WildDuelEnd.shipDown);
      } else if (_toroidalDistance(opp.position, ship.pos) >
          _wildDisengageRange) {
        _endWildDuel(WildDuelEnd.disengaged);
      } else {
        _tickCombatBodies(dt);
        // It fights the nearest companion out (the ship when none is).
        final duelTarget = _pickWildDuelTarget(opp);
        final target = _WildDuelTarget(this, duelTarget);
        final targetRadius = duelTarget != null
            ? _companionBodyRadius(duelTarget)
            : 20.0;

        final stepFrom = opp.position;
        // A Horn special holding it (a ram, a wind-up, a brew, a Light
        // barrier) holds it here too, as it holds a companion.
        if (!opp.hornHoldsBody &&
            !_hornLightChanneling(opp, duelOpponentProjectiles) &&
            !_heldByWingCharge(opp) &&
            !_kinHoldsBody(opp, opp.member)) {
          final family = opp.member.family.toLowerCase();
          final holdDistance = _combatHoldDistance(
            family: family,
            attackRange: opp.attackRange,
            specialRange: opp.specialAbilityRange,
            basicCooldown: opp.basicCooldown,
            specialCooldown: opp.specialCooldown,
          );
          final moved = _updateDuelMovement(
            actorPos: opp.position,
            targetPos: target.position,
            dt: dt,
            family: family,
            idSeed: opp.member.instanceId,
            speedStat: opp.member.statSpeed.toDouble(),
            holdDistance: holdDistance,
            attackRange: opp.attackRange,
            specialRange: opp.specialAbilityRange,
            life: opp.life,
          );
          // What the party's abilities left on it (a slow, a root) holds it.
          opp.position = stepFrom + (moved - stepFrom) * opp.ccMoveFactor;
        }

        _onWildSide(opp, () => _wildTurn(opp, target, targetRadius, dt));

        // Contact with the ship is a ram and opens the portal, so neither its
        // steering nor a charge carries it into the hull.
        opp.position = _wildStepClearOfShip(stepFrom, opp.position);
      }
    }

    // ── update companion projectiles ──
    _admitWildBody();
    _updateAbilityProjectiles(dt);

    // ── update garrison creatures (home-planet patrol & combat) ──
    if (homePlanet != null) {
      final hp = homePlanet!;
      final hpCenter = hp.position;
      final patrolRadius = _garrison.isEmpty
          ? hp.visualRadius + 72.0
          : _garrison.map((g) => g.guardRadius).reduce(max).toDouble() + 28.0;

      for (final g in _garrison) {
        g.ticker?.update(dt);
        if (g.basicHasteTimer > 0) {
          g.basicHasteTimer = max(0.0, g.basicHasteTimer - dt);
          if (g.basicHasteTimer <= 0) {
            g.basicHasteMultiplier = 1.0;
          }
        }
        _tickOpenGarrisonIdentity(g, dt);
        _updateOpenGarrisonKinSupport(g, dt);
        g.attackCooldown = (g.attackCooldown - dt).clamp(0.0, 100.0);
        g.specialCooldown = (g.specialCooldown - dt).clamp(0.0, 100.0);

        // ── Horn charge: rush through target, damage en route ──
        if (g.chargeTimer > 0) {
          g.chargeTimer -= dt;
          if (g.chargeTarget != null) {
            final startPos = g.position;
            final toTarget = g.chargeTarget! - g.position;
            final dist = toTarget.distance;
            if (dist > 10) {
              final step = 400.0 * g.chargeSpeedMultiplier * dt;
              g.position += (toTarget / dist) * min(step, dist);
              g.faceAngle = atan2(toTarget.dy, toTarget.dx);
              // Damage enemies along the charge path
              for (final e in enemies) {
                if (e.dead) continue;
                final d = _distanceToSegment(e.position, startPos, g.position);
                if (d < e.radius + g.chargeSweepRadius) {
                  e.health -= g.chargeDamage;
                  _spawnHitSpark(e.position, elementColor(g.member.element));
                  if (!e.provoked) _provokePackOf(e);
                }
              }
              if (activeBoss != null) {
                final d = _distanceToSegment(
                  activeBoss!.position,
                  startPos,
                  g.position,
                );
                if (d < activeBoss!.radius + g.chargeSweepRadius) {
                  activeBoss!.health -= g.chargeDamage;
                  _spawnHitSpark(g.position, elementColor(g.member.element));
                }
              }
            } else {
              // Arrived at overshoot point — final AoE sweep and stop.
              for (final e in enemies) {
                if (e.dead) continue;
                final d = (e.position - g.position).distance;
                if (d < g.chargeFinalSweepRadius) {
                  e.health -= g.chargeDamage;
                  _spawnHitSpark(e.position, elementColor(g.member.element));
                  if (!e.provoked) _provokePackOf(e);
                }
              }
              if (activeBoss != null) {
                final bd = (activeBoss!.position - g.position).distance;
                if (bd < g.chargeFinalSweepRadius) {
                  activeBoss!.health -= g.chargeDamage;
                  _spawnHitSpark(g.position, elementColor(g.member.element));
                }
              }
              _releaseGarrisonChargeBurst(g);
              g.chargeTimer = 0;
              g.chargeTarget = null;
            }
          }
          if (g.chargeTimer <= 0) {
            _releaseGarrisonChargeBurst(g);
            g.chargeTarget = null;
          }
        }

        // ── Kin blessing: heal over time ──
        if (g.blessingTimer > 0) {
          g.blessingTimer -= dt;
          g.blessingCarry += g.blessingHealPerTick * dt;
          final heal = g.blessingCarry.floor();
          g.blessingCarry -= heal;
          g.hp = min(g.maxHp, g.hp + heal);
        }

        final family = g.member.family.toLowerCase();
        final gBasicCooldownDuration = _openGarrisonBasicCooldown(g);
        final acquireRange = _combatAcquireRange(
          family: family,
          attackRange: g.attackRange,
          specialRange: g.specialRange,
        );
        final preferredDistance = _preferredCombatDistance(
          family: family,
          attackRange: g.attackRange,
          specialRange: g.specialRange,
        );
        CosmicEnemy? nearestEnemy;
        final effectiveAcquireRange = _effectiveCombatAcquireRange(
          acquireRange,
        );
        double nearestDist = effectiveAcquireRange;
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

        final hasCombatTarget =
            nearestEnemy != null ||
            (activeBoss != null && nearestDist < effectiveAcquireRange);

        if (hasCombatTarget) {
          // ── Chase & attack ──
          final targetPos = nearestEnemy?.position ?? activeBoss!.position;
          final toTarget = targetPos - g.position;
          g.faceAngle = atan2(toTarget.dy, toTarget.dx);

          if (toTarget.distance > preferredDistance &&
              !_heldByWingCharge(g) &&
              !_kinHoldsBody(g, g.member)) {
            final chaseSpeed =
                _combatChaseSpeed(family, g.member.statSpeed.toDouble()) * dt;
            g.position +=
                (toTarget / toTarget.distance) *
                min(chaseSpeed, toTarget.distance);
          }

          // Basic attack — family-specific pattern. A Kin's is a charged
          // laser (cosmic_game_kin.dart).
          if (_isKinMember(g.member)) {
            _tickOpenGarrisonKinChargedAuto(
              g,
              targetPos,
              toTarget.distance,
              gBasicCooldownDuration,
              dt,
            );
          } else if (g.attackCooldown <= 0 &&
              toTarget.distance <= g.attackRange) {
            g.attackCooldown = gBasicCooldownDuration;
            final basics = createFamilyBasicAttack(
              origin: g.position,
              angle: g.faceAngle,
              element: g.member.element,
              family: g.member.family,
              damage: g.attackDamage * _openGarrisonDamageAmp(g),
            );
            _tagSource(basics, g.member.slotIndex);
            if (_openKinLightningActive) {
              for (final projectile in basics) {
                projectile.chainLightningCharges = max(
                  projectile.chainLightningCharges,
                  3,
                );
              }
            }
            companionProjectiles.addAll(basics);
            _soundOpenBasic(g.member.family);
          }

          // Special attack — family+element ability!
          // A Mystic's world is a Survival ability; a garrisoned one casts
          // nothing here, the same as a summoned one.
          if (g.specialCooldown <= 0 &&
              toTarget.distance <= g.specialRange &&
              castsSpecialOutsideSurvival(g.member.family) &&
              !isPassiveOnlyCosmicAbility(g.member.family, g.member.element)) {
            g.specialCooldown = alchemonSpecialInterval(
              family: g.member.family,
              element: g.member.element,
              specialCooldownReduction: g.stats.specialCooldownReduction,
              abilityAtk: g.stats.abilityAtk,
            );
            _clearPipPoisonWeb(g.member);
            _soundOpenSpecial(
              g.member.family,
              g.member.element,
              garrison: true,
            );
            final result = createCosmicSpecialAbility(
              origin: g.position,
              baseAngle: g.faceAngle,
              family: g.member.family,
              element: g.member.element,
              damage: g.specialDamage * 0.8 * _openGarrisonDamageAmp(g),
              maxHp: g.maxHp,
              casterPower: g.member.statIntelligence.toDouble(),
              casterBeauty: g.member.statBeauty.toDouble(),
              casterIntelligence: g.member.statIntelligence.toDouble(),
              casterStrength: g.member.statStrength.toDouble(),
              casterBeautyPotential: g.member.statBeautyPotential,
              targetPos: targetPos,
            );
            _tagSource(result.projectiles, g.member.slotIndex);
            _applyOpenManeSpecialRuntime(
              member: g.member,
              projectiles: result.projectiles,
              origin: g.position,
              angle: g.faceAngle,
              currentStack: g.abilityKillStacks,
              setStack: (stack) => g.abilityKillStacks = stack,
            );
            final isHornCharge =
                g.member.family.toLowerCase() == 'horn' &&
                result.chargeTimer > 0;
            if (isHornCharge) {
              g.pendingChargeBurst = result.projectiles;
              g.pendingChargeOrigin = g.position;
              g.pendingChargeAngle = g.faceAngle;
            } else if (!activateMaskPlacements(
              result.projectiles,
              caster: g.position,
              target: targetPos,
              fromGarrison: true,
            )) {
              companionProjectiles.addAll(result.projectiles);
            }
            _activateWingBeamEffects(
              result.beams,
              caster: _WingCaster.garrison(g),
              angle: g.faceAngle,
            );
            // Apply garrison state changes
            if (result.shieldHp > 0) g.shieldHp = result.shieldHp;
            if (result.chargeTimer > 0) {
              g.chargeDamage = result.chargeDamage;
              g.chargeSpeedMultiplier = result.chargeSpeedMultiplier;
              g.chargeSweepRadius = result.chargeSweepRadius;
              g.chargeOvershootDistance = result.chargeOvershootDistance;
              g.chargeFinalSweepRadius = result.chargeFinalSweepRadius;
              if (!isHornCharge) {
                g.pendingChargeBurst = null;
                g.pendingChargeOrigin = null;
              }
              // Overshoot varies per element so Horn charges read differently.
              final dir = targetPos - g.position;
              final dist = dir.distance;
              if (dist > 1) {
                final overshootTarget =
                    targetPos + (dir / dist) * g.chargeOvershootDistance;
                g.chargeTarget = overshootTarget;
                final travelDist = (overshootTarget - g.position).distance;
                final travelTime =
                    travelDist / (400.0 * g.chargeSpeedMultiplier);
                g.chargeTimer = (travelTime + 0.15).clamp(0.3, 3.0);
              } else {
                g.chargeTarget = targetPos;
                g.chargeTimer = result.chargeTimer;
              }
            }
            if (result.selfHeal > 0) {
              g.hp = min(g.maxHp, g.hp + result.selfHeal);
            }
            if (result.blessingTimer > 0) {
              g.blessingTimer = max(g.blessingTimer, result.blessingTimer);
              g.blessingHealPerTick = max(
                g.blessingHealPerTick,
                result.blessingHealPerTick,
              );
            }
            if (result.basicHasteTimer > 0) {
              g.basicHasteTimer = result.basicHasteTimer;
              g.basicHasteMultiplier = result.basicHasteMultiplier;
            }
            if (g.member.family.toLowerCase() == 'kin') {
              _activateOpenGarrisonKinSupport(g, targetPos);
            }
            _spawnHitSpark(g.position, elementColor(g.member.element));
          }
        } else {
          // ── No enemy — hold a distinct orbital lane around the planet ──
          final orbitAngle =
              g.guardAngle +
              (_elapsed * 0.08) +
              sin(_elapsed * 0.45 + g.guardPhase) * 0.22;
          final orbitRadius =
              g.guardRadius + sin(_elapsed * 0.75 + g.guardPhase) * 8.0;
          final wanderTarget = Offset(
            hpCenter.dx + cos(orbitAngle) * orbitRadius,
            hpCenter.dy + sin(orbitAngle) * orbitRadius,
          );
          final toW = wanderTarget - g.position;
          final wDist = toW.distance;
          final fromCenterNow = g.position - hpCenter;
          final radialDist = fromCenterNow.distance;
          final laneBandMin = max(hp.visualRadius + 20.0, g.guardRadius - 18.0);
          final laneBandMax = g.guardRadius + 18.0;
          final needsLaneRecovery =
              radialDist < laneBandMin || radialDist > laneBandMax;
          if (wDist > 1.0 && !_heldByWingCharge(g)) {
            final step =
                (needsLaneRecovery
                    ? 220.0
                    : _GarrisonCreature.wanderSpeed * 1.4) *
                dt;
            g.position += (toW / wDist) * min(step, wDist);
            g.faceAngle = atan2(toW.dy, toW.dx);
          }
          final correctedFromCenter = g.position - hpCenter;
          final correctedDist = correctedFromCenter.distance;
          if (correctedDist < laneBandMin) {
            final laneDir = correctedDist > 0.001
                ? correctedFromCenter / correctedDist
                : Offset(cos(orbitAngle), sin(orbitAngle));
            g.position = hpCenter + laneDir * laneBandMin;
          }
          g.wanderAngle = orbitAngle + pi / 2;
        }

        // Clamp within patrol zone (beacon ring) around home planet
        final fromCenter = g.position - hpCenter;
        if (fromCenter.distance > patrolRadius) {
          g.position =
              hpCenter + (fromCenter / fromCenter.distance) * patrolRadius;
        }
      }
    }

    _releaseWildBody();

    _updateWildAlchemons(dt);

    // ── enemy spawning (random, scattered) — paused mid-duel and while a
    // contest plays ──
    if (!wildDuelActive && !sandboxMode && !_beautyContestCinematicActive) {
      _enemySpawnTimer += dt;
      if (_enemySpawnTimer >= _enemySpawnInterval &&
          enemies.length < _maxEnemies) {
        _enemySpawnTimer = 0;
        // ~82% chance each interval — space stays populated while roaming
        if (Random().nextDouble() < 0.82) {
          _spawnEnemy();
        }
      }

      // ── feeding pack spawn near asteroid belt ──
      _feedingPackTimer += dt;
      if (_feedingPackTimer >= _feedingPackInterval &&
          enemies.length < _maxEnemies - 2) {
        _feedingPackTimer = 0;
        // 65% chance — prey packs appear often enough to chase
        if (Random().nextDouble() < 0.65) {
          _spawnFeedingPack();
        }
      }
    } // end !wildDuelActive guard

    // ── enemy AI update ──
    _gatherFlocks();
    for (var i = enemies.length - 1; i >= 0; i--) {
      final e = enemies[i];
      if (e.dead) {
        enemies.removeAt(i);
        continue;
      }
      // A contest's surroundings stay clear (_clearContestHostiles).
      if (_beautyContestCinematicActive &&
          _wrappedDistanceSq(e.position, _beautyContestCenter) <
              _contestClearDistSq) {
        enemies.removeAt(i);
        continue;
      }

      // Distance cull.
      //
      // Enemies were ONLY ever removed when killed, so the population climbed
      // to _maxEnemies and stayed there for the session — every one of them
      // steering and rendering, including ones far off-screen, and the
      // aggressive/stalking ones walking toward the player the whole time.
      // Parking at base for a while therefore ended in a permanent crowd.
      //
      // Anything anchored to a place is exempt: territorial patrols guard a
      // homePos, whirl guardians belong to a whirl, and pack members are
      // culled with their pack rather than piecemeal (dropping half a swarm
      // looks worse than keeping it). A roaming wisp flock is small and
      // flies as one, so it crosses the cull line together — it goes like a
      // solo body.
      if (!e.provoked &&
          e.homePos == null &&
          e.whirlIndex < 0 &&
          (e.packId < 0 || e.flock) &&
          _wrappedDistanceSq(e.position, ship.pos) > _enemyCullDistSq) {
        enemies.removeAt(i);
        continue;
      }
      if (e.maneRootTimer > 0) {
        e.maneRootTimer = max(0.0, e.maneRootTimer - dt);
        if (e.maneRootTimer <= 0) e.maneRootSlot = null;
      }
      if (e.pipMudTrail) {
        e.pipMudTrailTimer -= dt;
        if (e.pipMudTrailTimer <= 0) {
          e.pipMudTrailTimer = 0.42;
          companionProjectiles.add(_pipMudTrailPuff(e.position));
        }
      }
      if (e.hornPlantRootTimer > 0) {
        e.hornPlantRootTimer = max(0.0, e.hornPlantRootTimer - dt);
      }
      e.tickSlow(dt);
      _integrateEnemyKnockback(e, dt);
      if (e.maneRootTimer <= 0) {
        _updateEnemyAI(e, dt);
      }
    }

    // ── initial swarm clusters (seeded at first update) ──
    if (!_initialSwarmsSpawned) {
      _initialSwarmsSpawned = true;
      final swarmRng = Random(0x5A4E3D2C);
      // Spawn 9-12 swarm clusters scattered around the world
      final clusterCount = 9 + swarmRng.nextInt(4);
      for (int c = 0; c < clusterCount; c++) {
        final cx =
            2000.0 + swarmRng.nextDouble() * (world_.worldSize.width - 4000);
        final cy =
            2000.0 + swarmRng.nextDouble() * (world_.worldSize.height - 4000);
        _spawnSwarmCluster(center: Offset(cx, cy), rng: swarmRng);
      }
    }

    // ── periodic swarm cluster spawns ──
    if (!sandboxMode && !_beautyContestCinematicActive) {
      _swarmSpawnTimer += dt;
      if (_swarmSpawnTimer >= _swarmSpawnInterval &&
          enemies.length < _maxEnemies) {
        _swarmSpawnTimer = 0;
        // 72% chance each interval — keeps ambient prey density up
        if (Random().nextDouble() < 0.72) {
          _spawnSwarmCluster();
        }
      }
    }

    // ── boss lair proximity check & respawn ──
    _updateBossLairs(dt);

    // ── random boss spawn (in addition to lairs) ──
    if (!sandboxMode && !_beautyContestCinematicActive) {
      _bossSpawnTimer += dt;
      if (_bossSpawnTimer >= _bossSpawnInterval) {
        _bossSpawnTimer = 0;
        if (activeBoss == null && Random().nextDouble() < 0.25) {
          _spawnBoss();
        }
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
        final bossDistSq = _wrappedDistanceSq(activeBoss!.position, ship.pos);
        if (!sandboxMode && bossDistSq > _bossLeashDistSq) {
          _bossLeashTimer += dt;
          if (_bossLeashTimer >= _bossLeashGrace) _despawnActiveBoss();
        } else {
          _bossLeashTimer = 0;
        }
        if (activeBoss != null && bossDistSq <= _bossEngageDistSq) {
          _updateBossAI(activeBoss!, dt);
        }
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
        _despawnActiveBoss();
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
            _maskTrapVisuals.contact(decoy);
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
          final variantMult = switch (e.variant) {
            CosmicEnemyVariant.crusher => 1.45,
            CosmicEnemyVariant.pouncer => 0.9,
            CosmicEnemyVariant.standard => 1.0,
          };
          final contactDmg =
              CosmicBalance.enemyShipContactDamage(e.tier) * variantMult;
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
        _damageShip(
          CosmicBalance.bossCollisionDamage(
            level: boss.level,
            type: boss.type,
            charging: boss.type == BossType.charger && boss.charging,
          ),
        );
      }

      // Boss collision → companion damage
      for (final comp in _livingActiveCompanions) {
        if (comp.invincibleTimer > 0) continue;
        final cdx = comp.position.dx - boss.position.dx;
        final cdy = comp.position.dy - boss.position.dy;
        final compHitR = boss.radius + 15;
        if (cdx * cdx + cdy * cdy < compHitR * compHitR) {
          final rawDmg = CosmicBalance.bossCollisionDamage(
            level: boss.level,
            type: boss.type,
            charging: boss.type == BossType.charger && boss.charging,
          );
          final scaledDmg = rawDmg * 30.0;
          _openCompanionIncomingDamage(
            comp,
            scaledDmg * 100 / (100 + comp.physDef),
          );
          _spawnHitSpark(comp.position, elementColor(boss.element));
        }
      }
    }

    // ── the edge of each pull, shown while a home is being placed ──
    {
      final want = homePlanet == null || _homePlacementPreview ? 1.0 : 0.0;
      // In quickly; out over a few seconds, so it is still there to see
      // when the console closes.
      _captureBandFade = want > _captureBandFade
          ? min(want, _captureBandFade + dt * 1.6)
          : max(want, _captureBandFade - dt * 0.25);
    }

    // ── orbital gravity between home planet and nearby cosmic planet ──
    if (homePlanet != null && _orbitalPartner != null) {
      _orbitAngle += _orbitSpeed * dt;
      if (_homeOrbitsPartner) {
        // Home planet orbits the larger cosmic planet
        final center = _orbitalPartner!.position;
        homePlanet!.position = _wrap(
          Offset(
            center.dx + cos(_orbitAngle) * _orbitRadius,
            center.dy + sin(_orbitAngle) * _orbitRadius,
          ),
        );
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

    // ── update VFX particles & rings ──
    _abilityVfx.update(dt);
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
      final comp = _prismaticCelebCompanionSlot == null
          ? null
          : activeCompanions[_prismaticCelebCompanionSlot];
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
        _prismaticCelebCompanionSlot = null;
        onPrismaticRewardClaimed?.call();
      }
    }

    // Trigger celebration if prismatic companion enters the central ring
    if (!prismaticRewardClaimed &&
        _prismaticCelebTimer < 0 &&
        activeCompanions.isNotEmpty) {
      for (final entry in activeCompanions.entries) {
        final comp = entry.value;
        if (!comp.isAlive ||
            comp.returning ||
            _companionVisualsBySlot[entry.key]?.isPrismatic != true) {
          continue;
        }
        final dist = (comp.position - prismaticField.position).distance;
        final ringR = prismaticField.radius * 0.12;
        if (dist < ringR + 30) {
          // Start celebration at the centre!
          _prismaticCelebTimer = 0;
          _prismaticCelebCenter = prismaticField.position;
          _prismaticCelebCompanionSlot = entry.key;
          break;
        }
      }
    }

    // ── sealed elemental caches ──
    _updateElementalCaches(dt);

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
          poi.type == POIType.stardustScanner ||
          poi.type == POIType.planetScanner ||
          poi.type == POIType.goldConversion) {
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

      // Interaction check (ship must be close). The wreck is drawn far
      // larger than its 25 radius, so it answers to the whole hull.
      final reach = poi.type == POIType.derelict ? 60.0 : poi.radius * 0.8;
      if (poiDist < reach) {
        poi.interacted = true;
        onPOIDiscovered?.call(poi);

        switch (poi.type) {
          case POIType.nebula:
            if (!meter.isFull) {
              meter.add(poi.element, 8.0 * _meterPickupMultiplier);
              onMeterChanged();
              onSound?.call(SoundCue.cosmicMatterCollect);
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
          case POIType.planetScanner:
          case POIType.goldConversion:
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
          case POIType.survivalPortal:
            // Handled via nearMarket proximity HUD, not one-shot.
            break;
        }
      }
    }

    // ── periodic save ──
    onPeriodicSave?.call();
  }

  /// Per-frame ambient zone wisps. Graphics are defined once in
  /// [emitZoneParticles] (Cosmic Survival is the source of truth); this just
  /// routes them into cosmic space's [VfxParticle] pool. Caller gates on the
  /// pool cap.
  void _spawnZoneParticles(Projectile p) {
    emitZoneParticles(p, _rng, (
      x,
      y,
      vx,
      vy,
      size,
      life,
      color, {
      arc = false,
    }) {
      _abilityVfx.add(x, y, vx, vy, size, life, color);
    });
  }

  /// Plant wards grow writhing tendrils toward nearby enemies — the same
  /// authored overlay survival draws. Gathers in-reach enemies nearest-first
  /// and hands off to the shared renderer.
  void _drawMaskPlantTendrils(Canvas canvas, Projectile vine, Color color) {
    final reach = max(vine.snareRadius, vine.effectRadius);
    final reachSq = reach * reach;
    final targets = <Offset>[];
    if (reach > 10) {
      for (final e in enemies) {
        if (e.dead) continue;
        if ((e.position - vine.position).distanceSquared > reachSq) continue;
        targets.add(e.position);
      }
      if (targets.length > 1) {
        targets.sort(
          (a, b) => (a - vine.position).distanceSquared.compareTo(
            (b - vine.position).distanceSquared,
          ),
        );
      }
    }
    drawMaskPlantWormyTendrils(
      canvas: canvas,
      vine: vine,
      color: color,
      time: _elapsed,
      targetsInReach: targets,
    );
  }

  // ── render ─────────────────────────────────────────────

  // Draws the parallax star layers. Each layer is a single small star tile
  // repeated across the viewport; drawing it at world coord
  // `base + cam * (1 - factor)` makes it scroll at `factor` of camera speed.
  void _renderParallaxLayers(
    Canvas canvas,
    double cx,
    double cy,
    double screenW,
    double screenH,
  ) {
    final dots = _starDots..clear();
    for (final layer in _parallaxLayers) {
      final f = layer.factor;
      final ox = cx * f;
      final oy = cy * f;
      final minCol = (ox / _parallaxTile).floor();
      final maxCol = ((ox + screenW) / _parallaxTile).floor();
      final minRow = (oy / _parallaxTile).floor();
      final maxRow = ((oy + screenH) / _parallaxTile).floor();
      final shiftX = cx * (1 - f);
      final shiftY = cy * (1 - f);
      for (var col = minCol; col <= maxCol; col++) {
        for (var row = minRow; row <= maxRow; row++) {
          final tileX = col * _parallaxTile + shiftX;
          final tileY = row * _parallaxTile + shiftY;
          for (final s in layer.stars) {
            final twinkle = 0.6 + 0.4 * sin(_elapsed * s.twinkleSpeed + s.x);
            _addStar(
              dots,
              tileX + s.x,
              tileY + s.y,
              s.size,
              s.brightness * twinkle,
            );
          }
        }
      }
    }
    _drawStars(canvas, dots);
  }

  /// Stars go in batches — four sizes by eight brightnesses, each drawn
  /// once — instead of a circle apiece: the starfield was most of a
  /// frame's draw calls (~850 of ~900).
  final GlowDots _starDots = GlowDots(32);

  static void _addStar(
    GlowDots dots,
    double x,
    double y,
    double size,
    double alpha,
  ) {
    if (alpha < 0.02) return;
    final sb = ((size - 0.5) * 2).floor().clamp(0, 3);
    final ab = (alpha * 8).floor().clamp(0, 7);
    dots.add(sb * 8 + ab, x, y);
  }

  static void _drawStars(Canvas canvas, GlowDots dots) {
    for (var sb = 0; sb < 4; sb++) {
      for (var ab = 0; ab < 8; ab++) {
        dots.drawDots(
          canvas,
          sb * 8 + ab,
          0.75 + sb * 0.5,
          Colors.white.withValues(alpha: (ab + 0.5) / 8),
        );
      }
    }
  }

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
    final screenW = size.x / cameraZoom;
    final screenH = size.y / cameraZoom;

    canvas.save();
    canvas.scale(cameraZoom, cameraZoom);
    canvas.translate(-cx, -cy);

    // ── parallax depth layers (behind the foreground grid) ──
    _renderParallaxLayers(canvas, cx, cy, screenW, screenH);

    // ── background stars (spatial grid lookup) ──
    final stars = _starDots..clear();
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
          _addStar(stars, star.x, star.y, star.size, star.brightness * twinkle);
        }
      }
    }
    _drawStars(canvas, stars);

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

    _renderOpenWingBeams(canvas);
    _renderWildWingBeams(canvas);
    _renderWingFlowers(canvas);
    _renderKinFlowers(canvas);

    // ── particle swarms ──
    final ww3 = world_.worldSize.width;
    final wh3 = world_.worldSize.height;
    for (final swarm in world_.particleSwarms) {
      final elColor = elementColor(swarm.element);
      final pulseAlpha = 0.6 + 0.3 * sin(swarm.pulse * 1.8);
      // Batched: every mote in the swarm goes in one of six classes (two
      // sizes, three brightnesses) and each class is drawn once.
      final motes = _swarmDots..clear();

      // The swarm's own light pooled under it, so it reads as one cloud and
      // fades as it is gathered.
      {
        var relX = swarm.center.dx - cx, relY = swarm.center.dy - cy;
        if (relX > ww3 / 2) relX -= ww3;
        if (relX < -ww3 / 2) relX += ww3;
        if (relY > wh3 / 2) relY -= wh3;
        if (relY < -wh3 / 2) relY += wh3;
        const reach = ParticleSwarm.cloudRadius * 1.2;
        if (relX > -reach &&
            relX < screenW + reach &&
            relY > -reach &&
            relY < screenH + reach) {
          paintDisc(
            canvas,
            stoneLightFor(elColor).pool,
            Offset(cx + relX, cy + relY),
            reach,
            pulseAlpha * swarm.remaining / max(1, swarm.motes.length),
          );
        }
      }

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

        final bright = moteAlpha < 0.5 ? 0 : (moteAlpha < 0.72 ? 1 : 2);
        motes.add((mote.size < 2.75 ? 0 : 3) + bright, mx, my);
      }
      for (var k = 0; k < 6; k++) {
        final size = k < 3 ? 2.1 : 3.4;
        final a = const [0.42, 0.61, 0.8][k % 3];
        motes.drawGlow(
          canvas,
          k,
          size + 4,
          6,
          elColor.withValues(alpha: a * 0.25),
        );
        motes.drawDots(canvas, k, size, elColor.withValues(alpha: a * 0.9));
      }
    }

    // ── planet territories: a faint wash of each element ──
    _renderTerritories(canvas, cx, cy, screenW, screenH);

    // ── gravity rings ──
    _renderGravityRings(canvas, cx, cy, screenW, screenH);

    // ── planets ──
    for (final pc in planetComps) {
      final planet = pc.planet;
      // Culled by what it actually covers — body, glow, rings — not by its
      // centre: Etherion and Cindrath are big enough that their centres can
      // be a screen away while their edges are in view.
      final reach = planet.radius * 2.6;
      if ((planet.position.dx - cx - screenW / 2).abs() > screenW / 2 + reach ||
          (planet.position.dy - cy - screenH / 2).abs() > screenH / 2 + reach) {
        continue;
      }

      // Raid takeover: a slow crimson storm-pulse wraps the overrun planet.
      if (raidElement != null &&
          planet.element == raidElement &&
          planet.discovered) {
        final pp = planet.position;
        final r = planet.radius;
        final pulse = 0.5 + 0.5 * sin(_elapsed * 1.6);
        paintSoftCircle(
          canvas,
          pp,
          r * (1.5 + pulse * 0.25),
          const Color(0xFFE25544).withValues(alpha: 0.10 + pulse * 0.08),
          30,
        );
        canvas.drawCircle(
          pp,
          r * (1.28 + pulse * 0.10),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..color = const Color(
              0xFFE25544,
            ).withValues(alpha: 0.35 + pulse * 0.25),
        );
      }

      // The ship, so a planet's loose matter can part round it.
      pc.art.wake = ship.pos;
      pc.render(canvas, _elapsed);
    }

    // ── star dust ──
    for (final dust in starDusts) {
      if (dust.collected) continue;
      final dp = dust.position;
      if (isOutsideViewport(dp, cx, cy, screenW, screenH)) {
        continue;
      }

      // Outer glow
      final glowAlpha = 0.3 + 0.2 * sin(_elapsed * 2.0 + dust.index * 0.7);
      paintSoftCircle(
        canvas,
        dp,
        14,
        const Color(0xFFFFD700).withValues(alpha: glowAlpha),
        10,
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
    final anyWhirlAwake = galaxyWhirls.any((w) => w.state == WhirlState.active);
    for (final whirl in galaxyWhirls) {
      final wp = whirl.position;
      if (isOutsideViewport(wp, cx, cy, screenW, screenH, margin: 1.5)) {
        continue;
      }

      final wColor = elementColor(whirl.element);
      final isActive = whirl.state == WhirlState.active;
      final isComplete = whirl.state == WhirlState.completed;

      // A spiral galaxy of grains (landmark_art.dart). Asleep, a faint ring
      // marks where it wakes — unless another whirl is already awake, for
      // only one can be at a time.
      paintGalaxyWhirl(
        canvas,
        at: wp,
        radius: whirl.radius,
        color: wColor,
        spin: whirl.rotation,
        t: whirl.pulse,
        look: isActive
            ? WhirlLook.active
            : isComplete
            ? WhirlLook.spent
            : WhirlLook.dormant,
        wake: whirl.state == WhirlState.dormant && !anyWhirlAwake
            ? GalaxyWhirl.activationRadius
            : null,
      );
      final labelLift = whirl.radius * 2.4;

      // Status label / indicators
      if (isActive) {
        // Wave indicator
        final waveTp = _worldLabel(
          'Lv${whirl.level} ${whirl.hordeTypeName} ${whirl.currentWave + 1}/${whirl.totalWaves}',
          color: wColor.withValues(alpha: 0.9),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        );
        waveTp.paint(
          canvas,
          Offset(wp.dx - waveTp.width / 2, wp.dy - labelLift - 20),
        );
        // Timer
        final timerSec = whirl.waveTimer.ceil();
        final timerTp = _worldLabel(
          '${timerSec}s',
          color: timerSec <= 10
              ? Colors.redAccent
              : Colors.white.withValues(alpha: 0.8),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        );
        timerTp.paint(
          canvas,
          Offset(wp.dx - timerTp.width / 2, wp.dy - labelLift - 34),
        );
      } else if (!isComplete) {
        final dormantTp = _worldLabel(
          'Lv${whirl.level} ${whirl.hordeTypeName}',
          color: wColor.withValues(alpha: 0.5),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        );
        dormantTp.paint(
          canvas,
          Offset(wp.dx - dormantTp.width / 2, wp.dy + labelLift + 8),
        );
      } else {
        final completeTp = _worldLabel(
          'CLEARED',
          color: Colors.greenAccent.withValues(alpha: 0.6),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        );
        completeTp.paint(
          canvas,
          Offset(wp.dx - completeTp.width / 2, wp.dy + labelLift + 8),
        );
      }
    }

    // ── prismatic field (aurora easter-egg) ──
    _renderPrismaticField(canvas, cx, cy, screenW, screenH);

    // ── sealed elemental caches ──
    _renderElementalCaches(canvas, cx, cy, screenW, screenH);

    // ── space POIs ──
    for (final poi in spacePOIs) {
      final pp = poi.position;
      if (isOutsideViewport(pp, cx, cy, screenW, screenH, margin: 1.5)) {
        continue;
      }

      // All POI types stay visible after interaction (just dimmed)

      switch (poi.type) {
        case POIType.nebula:
          paintNebula(
            canvas,
            at: pp,
            radius: poi.radius,
            color: elementColor(poi.element),
            t: poi.life,
            spent: poi.interacted,
            ship: ship.pos,
          );
          if (!poi.interacted) {
            final nebTp = _worldLabel(
              '${poi.element.toUpperCase()} NEBULA',
              color: elementColor(poi.element).withValues(alpha: 0.7),
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            );
            nebTp.paint(
              canvas,
              Offset(pp.dx - nebTp.width / 2, pp.dy + poi.radius * 1.2 + 10),
            );
          }
          break;
        case POIType.derelict:
          paintDerelict(canvas, at: pp, t: poi.life, looted: poi.interacted);
          if (!poi.interacted) {
            final derelictTp = _worldLabel(
              'DERELICT',
              color: const Color(0xFFB9CCDE).withValues(alpha: 0.7),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            );
            derelictTp.paint(
              canvas,
              Offset(pp.dx - derelictTp.width / 2, pp.dy + 64),
            );
          }
          break;
        case POIType.comet:
          // The shower falls thick while the encounter runs (speed is its
          // clock; ten seconds).
          final showering = poi.interacted && poi.speed < 10.0;
          paintMeteorZone(
            canvas,
            at: pp,
            radius: poi.radius,
            color: elementColor(poi.element),
            fall: poi.angle + 0.35 * sin(poi.life * 0.2),
            t: poi.life,
            shower: showering ? 1 : 0,
          );
          break;
        case POIType.warpAnomaly:
          paintWarpAnomaly(canvas, at: pp, radius: poi.radius, t: poi.life);
          if (!poi.interacted) {
            final anomTp = _worldLabel(
              'ANOMALY',
              color: const Color(0xFFB388FF).withValues(alpha: 0.7),
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            );
            anomTp.paint(
              canvas,
              Offset(pp.dx - anomTp.width / 2, pp.dy + poi.radius * 1.6 + 10),
            );
          }
          break;
        case POIType.harvesterMarket:
        case POIType.riftKeyMarket:
        case POIType.cosmicMarket:
        case POIType.stardustScanner:
        case POIType.planetScanner:
        case POIType.goldConversion:
          final kind = stationKindFor(poi.type)!;
          final mColor = kind.accent;
          final stationScale =
              kind == StationKind.starDustScanner ||
                  kind == StationKind.planetScanner
              ? 1.6
              : 1.5;
          // A scanner that is tracking turns to its target.
          final Offset? target = switch (kind) {
            StationKind.starDustScanner => starDustScannerTarget?.position,
            StationKind.planetScanner => planetScannerTarget?.position,
            _ => null,
          };
          // The light inside rises as the ship comes alongside.
          final dockReach = poi.radius * 2.5;
          final shipGap = (ship.pos - pp).distance;
          paintStation(
            canvas,
            kind,
            at: pp,
            t: poi.life,
            scale: stationScale,
            wake: (1 - (shipGap - dockReach * 0.5) / dockReach).clamp(0.0, 1.0),
            aim: target == null ? null : (target - pp).direction,
          );
          // Label
          final mTp = _worldLabel(
            kind.title,
            color: mColor.withValues(alpha: 0.7),
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          );
          mTp.paint(
            canvas,
            Offset(
              pp.dx - mTp.width / 2,
              pp.dy + kind.reach * stationScale * 0.82 + 6,
            ),
          );
          break;

        case POIType.survivalPortal:
          final gateGap = (ship.pos - pp).distance;
          paintSurvivalGate(
            canvas,
            at: pp,
            t: poi.life,
            near: (1 - (gateGap - 60) / 200).clamp(0.0, 1.0),
          );
          final portalTp = _worldLabel(
            poi.discovered ? 'SURVIVAL PORTAL' : 'UNKNOWN SIGNAL',
            color: const Color(0xFFB388FF).withValues(alpha: 0.75),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          );
          portalTp.paint(
            canvas,
            Offset(pp.dx - portalTp.width / 2, pp.dy + 130),
          );
          break;
      }
    }

    // ── rift portals (all 5) ──
    // The same grain vortex the wilderness rifts and their threshold use,
    // so the rift you fly up to is the one that opens. Each steps only while
    // it is near enough to see.
    for (final rift in world_.riftPortals) {
      final rp = rift.position;
      if ((rp.dx - cx - screenW / 2).abs() < screenW * 1.5 &&
          (rp.dy - cy - screenH / 2).abs() < screenH * 1.5) {
        final field = _riftFields.putIfAbsent(
          rift.faction,
          () => RiftVortexField(
            grains: 520,
            ringGrains: 120,
            motes: 30,
            core: 0.27,
            grainSize: 2.4,
          )..open = 1,
        );
        final last = _riftFieldTimes[rift.faction] ?? _riftPulse;
        _riftFieldTimes[rift.faction] = _riftPulse;
        field.step((_riftPulse - last).clamp(0.0, 0.05));
        field.paint(
          canvas,
          Size.zero,
          rp,
          // The core as wide as the old dark disc.
          28 / field.core,
          _riftPalettes.putIfAbsent(
            rift.faction,
            () => RiftPalette(rift.color),
          ),
          backdrop: false,
        );
      }
    }

    // ── elemental nexus ──
    {
      final nx = elementalNexus;
      final np = nx.position;
      if ((np.dx - cx - screenW / 2).abs() < screenW * 2.5 &&
          (np.dy - cy - screenH / 2).abs() < screenH * 2.5) {
        // A black hole the four elements pour into (landmark_art.dart);
        // the streams quicken when the meter carries all four in balance,
        // which is what it asks to be let in.
        final ready =
            meter.isFull && nx.meetsRequirement(meter.breakdown, meter.total);
        paintElementalNexus(
          canvas,
          at: np,
          radius: 520,
          t: _riftPulse,
          near: ready ? 1 : 0,
        );

        // Label when close (cheap — drawn every frame)
        if (_isNearNexus || (np - ship.pos).distance < 400) {
          final textPainter = _worldLabel(
            'NEXUS',
            color: const Color(0x99FFFFFF),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          );
          textPainter.paint(
            canvas,
            Offset(np.dx - textPainter.width / 2, np.dy + 170),
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
        // The end of the game: a crown of blood-glass thorns round a well of
        // blood and an eclipsed heart (landmark_art.dart). It stirs when a
        // Mystic Blood companion is out, which is what the ritual needs; the
        // ritual itself plays on it; once done, its heart is clear.
        paintBloodRing(
          canvas,
          at: rp,
          radius: BloodRing.visualRadius,
          t: _riftPulse,
          flow: _bloodFlow,
          opened: ring.ritualCompleted && _bloodRitual == null,
          armed: _bloodArmed,
          ritual: _bloodRitual ?? 0,
        );
        final outerR = BloodRing.visualRadius;

        if (_bloodRitual == null &&
            (_isNearBloodRing || (rp - ship.pos).distance < 550)) {
          final label = ring.ritualCompleted ? 'BLOOD PORTAL' : 'BLOOD RING';
          final textPainter = _worldLabel(
            label,
            color: const Color(0x99FF8A80),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
          );
          textPainter.paint(
            canvas,
            Offset(rp.dx - textPainter.width / 2, rp.dy + outerR + 60),
          );
        }
      }
    }

    // ── trait contest arenas ──
    // The arena is the contest's stage: in one, it rises to it and draws the
    // point being fought over (contest_art.dart).
    for (final arena in contestArenas) {
      final ap = arena.position;
      if (isOutsideViewport(
        ap,
        cx,
        cy,
        screenW,
        screenH,
        // A mastered arena's beacon climbs well above its rim.
        margin: 1 + CosmicContestArena.visualRadius * 1.7 / screenW,
      )) {
        continue;
      }
      final staging =
          _beautyContestCinematicActive &&
          (ap - _beautyContestCenter).distance < 1;
      final masteredAt = arena.masteredAt;
      paintContestArena(
        canvas,
        arena.trait,
        at: ap,
        t: _elapsed,
        active: staging ? _contestStageLight : 0,
        focus: staging ? _contestFocus() : null,
        // Held back while a contest is staged in it: it is the stage then.
        mastery: masteredAt == null || staging ? null : _elapsed - masteredAt,
      );

      if (!staging &&
          (nearContestArena == arena || (ap - ship.pos).distance < 520)) {
        final mastered = arena.masteredAt != null;
        final col = mastered ? kContestChampionGold : arena.trait.color;
        final labelPainter = _worldLabel(
          mastered
              ? '${arena.trait.arenaLabel.toUpperCase()} · MASTERED'
              : arena.trait.arenaLabel.toUpperCase(),
          color: col.withValues(alpha: 0.86),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.8,
        );
        labelPainter.paint(
          canvas,
          Offset(
            ap.dx - labelPainter.width / 2,
            ap.dy + CosmicContestArena.visualRadius + 14,
          ),
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
      paintLoreNote(canvas, at: np, t: _elapsed, seed: note.id.length);
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
        _paintHomeAura(canvas, hpPos, vr, col);

        // ── Customization visual effects (rendered behind planet body) ──
        _renderHomeEffectsBehind(canvas, hpPos, vr, col);

        // Planet body
        _paintHomeSphere(canvas, hpPos, vr, col);

        // ── Customization visual effects (rendered in front of planet) ──
        _renderHomeEffectsFront(canvas, hpPos, vr, col);

        // ── Garrison creatures inside planet ──
        for (final g in _garrison) {
          final eColor = elementColor(g.member.element);

          canvas.save();
          canvas.translate(g.position.dx, g.position.dy);

          // Subtle aura glow
          final auraPulse = 0.4 + 0.2 * sin(_elapsed * 2.5 + g.position.dx);
          paintSoftCircle(
            canvas,
            Offset.zero,
            18 * g.spriteScale,
            eColor.withValues(alpha: auraPulse * 0.25),
            8,
          );

          // A Kin's running support, its laser gathering — and a raised
          // Lava plate on the rest (cosmic_game_kin.dart).
          _renderKinOverlay(
            canvas,
            g,
            g.member,
            position: g.position,
            lavaTeam: _openKinLavaPlateActive,
          );

          // ── Shield bubble (Horn special) ──
          if (g.shieldHp > 0) {
            drawAdvancedCompanionShield(
              canvas: canvas,
              time: _elapsed,
              scale: g.spriteScale,
            );
          }

          // ── Charge trail (Horn charging) ──
          if (g.chargeTimer > 0) {
            drawAdvancedChargeTrail(
              canvas: canvas,
              color: eColor,
              angle: g.faceAngle,
              sweepRadius: g.chargeSweepRadius,
              overshootDistance: g.chargeOvershootDistance,
              element: g.member.element,
              time: _elapsed,
              scale: g.spriteScale,
            );
          }

          // ── Blessing aura (Kin healing) ──
          if (g.blessingTimer > 0) {
            drawAdvancedBlessingAura(
              canvas: canvas,
              time: _elapsed,
              scale: g.spriteScale,
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
                auraElement: g.visuals?.auraElement,
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
            _drawDarkletRing(
              canvas,
              sprite,
              g.ticker!.currentIndex,
              _elapsed,
              1,
              front: false,
            );
            sprite.render(canvas, anchor: Anchor.center, overridePaint: paint);
            _drawCostumeOnSprite(
              canvas,
              g.visuals?.costumes,
              sprite,
              g.ticker!.currentIndex,
              _elapsed,
              1,
            );
            _drawDarkletRing(
              canvas,
              sprite,
              g.ticker!.currentIndex,
              _elapsed,
              1,
              front: true,
            );
            canvas.restore();
            if (g.visuals?.alchemyEffect != null) {
              _drawAlchemyEffectCanvas(
                canvas: canvas,
                effect: g.visuals!.alchemyEffect!,
                spriteScale: g.spriteScale,
                baseSpriteSize: 40.0,
                auraElement: g.visuals?.auraElement,
                elapsed: _elapsed,
                opacity: 0.95,
                front: true,
              );
            }
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
        final homeLabel = _worldLabel(
          'HOME',
          color: const Color(0xFF00E5FF).withValues(alpha: 0.9),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        );
        homeLabel.paint(
          canvas,
          Offset(hpPos.dx - homeLabel.width / 2, hpPos.dy + vr + 12),
        );
      }
    }

    // ── asteroids ──
    // Near-black stone lit by the key light, and dust through the belt
    // (asteroid_art.dart): the whole belt is one atlas draw.
    paintAsteroidBelt(
      canvas,
      asteroidBelt,
      view: Rect.fromLTWH(cx, cy, screenW, screenH),
      elapsed: _elapsed,
    );

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
          paintAstralShard(
            canvas,
            at: drawPos,
            t: drop.life + drop.position.dx * 0.01,
            alpha: fadeAlpha,
          );
          break;
        case LootType.healthOrb:
        case LootType.elementParticle:
          // A glass orb of light, grains of its colour circling it
          // (poi_art.dart).
          paintLootOrb(
            canvas,
            at: drawPos,
            color: drop.color,
            t: drop.life + drop.position.dy * 0.02,
            r: drop.type == LootType.healthOrb ? 7.5 : 6.5,
            alpha: fadeAlpha,
          );
          break;
        case LootType.item:
          final itemKey = drop.itemKey;
          final portalBiome = PortalKeyGlyph.biomeForInventoryKey(itemKey);
          final offer = (itemKey != null && portalBiome == null)
              ? InventoryItemArtwork.offerFor(itemKey)
              : null;

          if (portalBiome != null) {
            // Real rift-key glyph — same art as the shop/inventory.
            final tint =
                ElementResources.byBiomeId[portalBiome]?.color ?? drop.color;
            final pulse = 0.85 + 0.15 * sin(drop.life * 3.0);
            paintSoftCircle(
              canvas,
              drawPos,
              19.2,
              tint.withValues(alpha: 0.28 * fadeAlpha * pulse),
              12,
            );
            PortalKeyGlyph.paintGlyph(
              canvas,
              drawPos,
              31.2,
              tint,
              drop.life,
              fade: fadeAlpha,
            );
          } else if (offer?.icon != null) {
            // Real shop icon (harvesters etc.) — same glyph as the shop.
            final tint = offer!.iconColor ?? drop.color;
            final pulse = 0.85 + 0.15 * sin(drop.life * 3.0);
            paintSoftCircle(
              canvas,
              drawPos,
              16.8,
              tint.withValues(alpha: 0.28 * fadeAlpha * pulse),
              12,
            );
            // One glyph, so its fade goes in its colour — no layer. Alpha in
            // 1/32 steps keeps the painter cache to a few entries per icon.
            final fadeQ = (fadeAlpha.clamp(0.0, 1.0) * 32).round() / 32;
            if (fadeQ > 0) {
              final tp = _itemIconPainter(
                offer.icon,
                fadeQ < 1 ? tint.withValues(alpha: tint.a * fadeQ) : tint,
              );
              tp.paint(canvas, drawPos - Offset(tp.width / 2, tp.height / 2));
            }
          } else {
            paintLootOrb(
              canvas,
              at: drawPos,
              color: drop.color,
              t: drop.life,
              r: 8,
              alpha: fadeAlpha,
            );
          }
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

      // Body drawing lives in the shared cosmic enemy VFX layer so the
      // preview harness can render the open-world roster, and so this pass can
      // be compared against survival's.
      drawOpenWorldEnemy(canvas: canvas, e: e, time: _elapsed);
    }

    // ── boss lairs (waiting markers) ──
    for (final lair in bossLairs) {
      if (lair.state != BossLairState.waiting) continue;
      final lp = lair.position;
      if ((lp.dx - cx - screenW / 2).abs() > screenW * 1.5 ||
          (lp.dy - cy - screenH / 2).abs() > screenH * 1.5) {
        continue;
      }
      paintBossLair(
        canvas,
        at: lp,
        element: elementColor(lair.template.element),
        wakeRadius: BossLair.activationRadius,
        t: _elapsed,
      );
      final lairTp = _worldLabel(
        'LV${lair.level} ${lair.template.name.toUpperCase()}',
        color: const Color(0xFFFF6B5E).withValues(alpha: 0.8),
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      );
      lairTp.paint(canvas, Offset(lp.dx - lairTp.width / 2, lp.dy + 46));
    }

    // ── boss ──
    if (activeBoss != null && !activeBoss!.dead) {
      final boss = activeBoss!;
      final bp = boss.position;
      // Cull stays here — this pass owns the camera. The body itself lives in
      // the shared cosmic enemy VFX layer.
      if ((bp.dx - cx - screenW / 2).abs() < screenW * 1.2 &&
          (bp.dy - cy - screenH / 2).abs() < screenH * 1.2) {
        drawOpenWorldBoss(canvas: canvas, boss: boss, time: _elapsed);
      }
    }

    // ── boss projectiles ──
    for (final bp in bossProjectiles) {
      final pp = bp.position;
      if ((pp.dx - cx - screenW / 2).abs() > screenW ||
          (pp.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }

      // The same hostile shot Survival draws.
      paintHostileShot(
        canvas,
        pp,
        bp.angle,
        bp.radius,
        bp.element,
        heavy: true,
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
      paintSoftCircle(canvas, pp, 6, ammoColor.withValues(alpha: 0.3), 6);
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
      paintSoftCircle(
        canvas,
        mp,
        10,
        const Color(0xFFFF6F00).withValues(alpha: 0.3),
        8,
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
      paintSoftCircle(
        canvas,
        const Offset(0, 6),
        3,
        const Color(0xFFFFAB40).withValues(alpha: 0.6),
        4,
      );
      canvas.restore();
    }

    // ── orbital sentinels: beads of the hull's light held in glass ──
    if (orbitals.isNotEmpty) {
      final light = shipLight(activeShipSkin);
      for (var i = 0; i < orbitals.length; i++) {
        final o = orbitals[i];
        paintOrbitalSentinel(
          canvas,
          o.positionAround(ship.pos),
          light,
          time: _elapsed,
          seed: i * 1.7,
          radius: OrbitalSentinel.hitboxRadius * 0.6,
          opacity: o.spawnOpacity,
        );
      }
    }

    // ── incoming Let meteors: the ground they are committed to ──
    // Before the projectiles themselves, so the mark sits under everything.
    for (final cp in companionProjectiles) {
      if (!cp.isDescending) continue;
      final mark = cp.skyfallImpact;
      if ((mark.dx - cx - screenW / 2).abs() > screenW ||
          (mark.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }
      drawLetSkyfallTelegraph(
        canvas: canvas,
        centre: mark,
        color: elementColor(cp.element ?? 'Fire'),
        radius: letSkyfallBlastRadius(cp),
        progress: cp.skyfallProgress,
        time: _elapsed,
      );
    }

    // ── Let meteor craters ──
    for (final impact in _letSkyfallImpacts) {
      drawLetSkyfallImpact(
        canvas: canvas,
        centre: impact.position,
        color: impact.color,
        element: impact.element,
        minor: impact.minor,
        radius: impact.radius,
        age: impact.t,
      );
    }
    drawLetFx(canvas, _letFx);

    drawHornFx(canvas, _hornFx);

    // ── companion projectiles, then the wild Alchemon's: the same
    // abilities, drawn the same way ──
    // Many Mane Lava pools on the field draw a lighter pool, as survival's.
    maneLavaPoolCrowd =
        ManeRuntime.countLavaPools(companionProjectiles) +
        ManeRuntime.countLavaPools(duelOpponentProjectiles);
    for (final list in [companionProjectiles, duelOpponentProjectiles]) {
      for (final cp in list) {
        final cpp = cp.position;
        if ((cpp.dx - cx - screenW / 2).abs() > screenW ||
            (cpp.dy - cy - screenH / 2).abs() > screenH) {
          continue;
        }
        _renderAbilityProjectile(canvas, cp);
      }
    }
    _renderMaskOverlays(canvas, Rect.fromLTWH(cx, cy, screenW, screenH));

    // ── wild Alchemons (behind the companions that fight them) ──
    _renderWildAlchemons(canvas, cx, cy, screenW, screenH);

    // ── companions ──
    for (final entry in activeCompanions.entries) {
      final slotIndex = entry.key;
      final comp = entry.value;
      if (!comp.isAlive) continue;
      final companionTicker = _companionTickers[slotIndex];
      final companionVisuals = _companionVisualsBySlot[slotIndex];
      final companionSpriteScale = _companionSpriteScales[slotIndex] ?? 1.0;
      final compPos = comp.position;
      final eColor = elementColor(comp.member.element);

      // Animation timing
      const summonDur = 0.9; // summon animation duration
      const retreatDur = 0.6;
      final isSummoning = comp.life < summonDur && !comp.returning;
      final summonT = isSummoning
          ? (comp.life / summonDur).clamp(0.0, 1.0)
          : 1.0;
      final retreatT = comp.returning
          ? (comp.returnTimer / retreatDur).clamp(0.0, 1.0)
          : 1.0;

      // It gathers out of grains of itself where it will stand, and comes
      // apart into them and streams back into the ship when recalled —
      // the particle language of the fusion and the harvest. Until its
      // grains have been read it steps out of a tear of its element, as it
      // used to.
      final grainEntry = _companionGrains[slotIndex];
      final assembly =
          grainEntry != null && grainEntry.$1 == comp.member.instanceId
          ? grainEntry.$2
          : null;
      final emerge = isSummoning && assembly == null
          ? Curves.easeOutBack.transform(
              ((summonT - 0.18) / 0.55).clamp(0.0, 1.0),
            )
          : 1.0;
      final summonScale =
          (0.25 + 0.75 * emerge) * _beautyContestCompVisualScale;
      final retreatScale = comp.returning && assembly == null
          ? Curves.easeInBack.transform(retreatT)
          : 1.0;
      final animScale = summonScale * retreatScale;
      final opacity = comp.returning
          ? (assembly != null
                ? GrainAssembly.spriteOpacityScattering(1 - retreatT)
                : retreatT)
          : isSummoning
          ? (assembly != null
                ? GrainAssembly.spriteOpacityGathering(summonT)
                : ((summonT - 0.15) / 0.3).clamp(0.0, 1.0))
          : 1.0;

      canvas.save();
      canvas.translate(compPos.dx, compPos.dy);

      final tearHeight = 74.88 * comp.speciesScale * 1.35;
      if (assembly != null) {
        // Its element's light, where it gathers or comes apart.
        final k = isSummoning
            ? sin(pi * summonT)
            : comp.returning
            ? sin(pi * (1 - retreatT))
            : 0.0;
        if (k > 0) {
          paintSoftCircle(
            canvas,
            Offset.zero,
            assembly.reach * 1.6,
            eColor.withValues(alpha: 0.28 * k),
            14,
          );
        }
      } else if (isSummoning) {
        paintSummonTear(
          canvas,
          centre: Offset.zero,
          height: tearHeight,
          t: summonT,
          color: eColor,
        );
      } else if (comp.returning) {
        paintSummonTear(
          canvas,
          centre: Offset.zero,
          height: tearHeight,
          t: 1 - retreatT,
          color: eColor,
        );
      }

      // Outer aura glow
      final auraPulse = 0.5 + 0.3 * sin(_elapsed * 3.0);
      paintSoftCircle(
        canvas,
        Offset.zero,
        33.6 * animScale,
        eColor.withValues(alpha: auraPulse * 0.3 * opacity),
        14,
      );

      // A Kin's running support, its laser gathering — and a raised Lava
      // plate on everyone else (cosmic_game_kin.dart).
      _renderKinOverlay(
        canvas,
        comp,
        comp.member,
        position: compPos,
        lavaTeam: _openKinLavaPlateActive,
      );
      // Horn Poison's reach, a shield, a ram's wake — worn by the wild
      // Alchemon it fights as well (cosmic_game_horn.dart).
      _renderCasterOverlay(canvas, comp, scale: animScale);

      // ── Blessing aura (Kin healing) ──
      if (comp.isBlessing) {
        drawAdvancedBlessingAura(
          canvas: canvas,
          time: _elapsed,
          scale: animScale,
          opacity: opacity,
        );
      }

      // Render sprite if loaded, otherwise fallback to circles
      if (companionTicker != null) {
        final sprite = companionTicker.getSprite();
        final paint = Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..filterQuality = ui.FilterQuality.high;

        // Apply genetics color filter if visuals available
        if (companionVisuals != null) {
          final v = companionVisuals;
          final isAlbino = v.brightness == 1.45 && !v.isPrismatic;
          if (isAlbino) {
            paint.colorFilter = _albinoColorFilter(v.brightness);
          } else {
            paint.colorFilter = _geneticsColorFilter(v);
          }
        }
        _applyCasterHitFlash(paint, comp);

        // Simple canvas-based effect overlays for companion (behind sprite)
        if (companionVisuals?.alchemyEffect != null) {
          final companionScale = companionSpriteScale * animScale;
          _drawAlchemyEffectCanvas(
            canvas: canvas,
            effect: companionVisuals!.alchemyEffect!,
            spriteScale: companionScale,
            baseSpriteSize: 48.0,
            auraElement: companionVisuals.auraElement,
            elapsed: _elapsed,
            opacity: opacity,
          );
        }

        // Flip sprite horizontally to face shooting direction
        // Default sprites face left; flip when target is to the right
        final facingRight = cos(comp.angle) > 0;
        final totalScale = companionSpriteScale * animScale;
        canvas.save();
        if (facingRight) {
          canvas.scale(-totalScale, totalScale);
        } else {
          canvas.scale(totalScale);
        }
        _drawDarkletRing(
          canvas,
          sprite,
          companionTicker.currentIndex,
          _elapsed,
          opacity,
          front: false,
        );
        sprite.render(canvas, anchor: Anchor.center, overridePaint: paint);
        _drawCostumeOnSprite(
          canvas,
          companionVisuals?.costumes,
          sprite,
          companionTicker.currentIndex,
          _elapsed,
          opacity,
        );
        _drawDarkletRing(
          canvas,
          sprite,
          companionTicker.currentIndex,
          _elapsed,
          opacity,
          front: true,
        );
        canvas.restore();
        if (companionVisuals?.alchemyEffect != null) {
          _drawAlchemyEffectCanvas(
            canvas: canvas,
            effect: companionVisuals!.alchemyEffect!,
            spriteScale: companionSpriteScale * animScale,
            baseSpriteSize: 48.0,
            auraElement: companionVisuals.auraElement,
            elapsed: _elapsed,
            opacity: opacity,
            front: true,
          );
        }
        if (assembly != null && isSummoning) {
          assembly.paintGather(
            canvas,
            Offset.zero,
            summonT,
            mirror: facingRight,
            scale: _beautyContestCompVisualScale,
          );
        } else if (assembly != null && comp.returning) {
          assembly.paintScatter(
            canvas,
            Offset.zero,
            1 - retreatT,
            to: ship.pos - compPos,
            mirror: facingRight,
            scale: _beautyContestCompVisualScale,
          );
        }
      } else {
        // Fallback: colored circle
        canvas.drawCircle(
          Offset.zero,
          16.8 * animScale,
          Paint()..color = eColor.withValues(alpha: 0.85 * opacity),
        );
        canvas.drawCircle(
          Offset.zero,
          7.2 * animScale,
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

    // ── duel opponent (a fought wild Alchemon, or a contest rival) ──
    if (duelOpponent != null && duelOpponent!.isAlive) {
      final opp = duelOpponent!;
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
        paintSoftRing(
          canvas,
          Offset.zero,
          ringRadius,
          const Color(0xFFFF4040).withValues(alpha: ringAlpha),
          3.0 * (1.0 - summonT) + 0.5,
          8,
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

      // Red-tinted aura glow (enemy) — not on a contest rival.
      if (!_beautyContestCinematicActive) {
        final auraPulse = 0.5 + 0.3 * sin(_elapsed * 3.0);
        paintSoftCircle(
          canvas,
          Offset.zero,
          28 * summonScale,
          const Color(0xFFFF4040).withValues(alpha: auraPulse * 0.25),
          14,
        );
      }

      // What it wears of its own abilities, as a companion does.
      _renderKinOverlay(
        canvas,
        opp,
        opp.member,
        position: oppPos,
        lavaTeam: false,
      );
      _renderCasterOverlay(canvas, opp, scale: summonScale);

      // Render sprite
      if (_duelOpponentTicker != null) {
        final sprite = _duelOpponentTicker!.getSprite();
        final paint = Paint()
          ..color = Colors.white
          ..filterQuality = ui.FilterQuality.high;

        if (_duelOpponentVisuals != null) {
          final v = _duelOpponentVisuals!;
          final isAlbino = v.brightness == 1.45 && !v.isPrismatic;
          if (isAlbino) {
            paint.colorFilter = _albinoColorFilter(v.brightness);
          } else {
            paint.colorFilter = _geneticsColorFilter(v);
          }
        }
        _applyCasterHitFlash(paint, opp);

        // Simple effect overlays for ring opponent (behind sprite)
        if (_duelOpponentVisuals?.alchemyEffect != null) {
          final opponentScale = _duelOpponentSpriteScale * summonScale;
          _drawAlchemyEffectCanvas(
            canvas: canvas,
            effect: _duelOpponentVisuals!.alchemyEffect!,
            spriteScale: opponentScale,
            baseSpriteSize: 48.0,
            auraElement: _duelOpponentVisuals?.auraElement,
            elapsed: _elapsed,
            opacity: 0.95,
          );
        }

        final facingRight = cos(opp.angle) > 0;
        final totalScale = _duelOpponentSpriteScale * summonScale;
        canvas.save();
        if (facingRight) {
          canvas.scale(-totalScale, totalScale);
        } else {
          canvas.scale(totalScale);
        }
        _drawDarkletRing(
          canvas,
          sprite,
          _duelOpponentTicker!.currentIndex,
          _elapsed,
          1,
          front: false,
        );
        sprite.render(canvas, anchor: Anchor.center, overridePaint: paint);
        _drawCostumeOnSprite(
          canvas,
          _duelOpponentVisuals?.costumes,
          sprite,
          _duelOpponentTicker!.currentIndex,
          _elapsed,
          1,
        );
        _drawDarkletRing(
          canvas,
          sprite,
          _duelOpponentTicker!.currentIndex,
          _elapsed,
          1,
          front: true,
        );
        canvas.restore();
        if (_duelOpponentVisuals?.alchemyEffect != null) {
          _drawAlchemyEffectCanvas(
            canvas: canvas,
            effect: _duelOpponentVisuals!.alchemyEffect!,
            spriteScale: _duelOpponentSpriteScale * summonScale,
            baseSpriteSize: 48.0,
            auraElement: _duelOpponentVisuals?.auraElement,
            elapsed: _elapsed,
            opacity: 0.95,
            front: true,
          );
        }
      } else if (_duelOpponentFallbackSprite != null) {
        final paint = Paint()
          ..color = Colors.white
          ..filterQuality = ui.FilterQuality.high;
        final totalScale = _duelOpponentFallbackScale * summonScale;
        canvas.save();
        canvas.scale(totalScale);
        _duelOpponentFallbackSprite!.render(
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

    // ── ship ──
    // Once a contest has begun the ship is parked at the arena's heart, where
    // it would sit on the stage; it is left out until the contest ends.
    final shipOffStage =
        _beautyContestCinematicActive && !_beautyContestIntroActive;
    if (!_shipDead && !shipOffStage) {
      // A Lava plate's glow, a tesla channel's current (cosmic_game_kin.dart).
      _renderKinShipOverlay(canvas);
      // Invincibility flash
      // The flicker's dim half fades the ship as one piece; its bright
      // half is full opacity, which needs no layer at all.
      if (_shipInvincible > 0 && sin(_elapsed * 30) > 0) {
        canvas.saveLayer(
          _shipLayerBounds(boost: _boostTrailVisual),
          Paint()..color = Colors.white.withValues(alpha: 0.4),
        );
        ship.render(
          canvas,
          _elapsed,
          skin: activeShipSkin,
          boost: _boostTrailVisual,
        );
        canvas.restore();
      } else {
        // Boosting opens the engines up and thickens the wake.
        ship.render(
          canvas,
          _elapsed,
          skin: activeShipSkin,
          boost: _boostTrailVisual,
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
        _shipLayerBounds(),
        Paint()..color = Colors.white.withValues(alpha: ghostAlpha),
      );
      ship.render(canvas, _elapsed, skin: activeShipSkin);
      canvas.restore();
    }
    // A Blood pact's threads and the Kin lasers, over the world.
    _renderKinWorld(canvas);
    _renderMaskSpiritNukeFlash(canvas, Rect.fromLTWH(cx, cy, screenW, screenH));

    // ── VFX particles ──
    _abilityVfx.render(canvas);
    for (final p in vfxParticles) {
      final a = p.alpha;
      final sz = p.size * a;
      if (sz <= 0) continue;
      // Glow
      paintSoftCircle(
        canvas,
        Offset(p.x, p.y),
        sz * 2,
        p.color.withValues(alpha: a * 0.3),
        sz * 2,
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
      final sw = size.x / cameraZoom;
      final sh = size.y / cameraZoom;
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
        paintSoftCircle(
          canvas,
          center,
          sw * 0.8 * flashT,
          Color.fromRGBO(124, 77, 255, flashT * 0.5),
          60 * flashT,
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
          _softLine(
            canvas,
            Offset(
              center.dx + cos(angle) * innerR,
              center.dy + sin(angle) * innerR,
            ),
            Offset(
              center.dx + cos(angle) * outerR,
              center.dy + sin(angle) * outerR,
            ),
            Color.fromRGBO(179, 136, 255, alpha),
            streakWidth,
            3,
          );
        }
        // Vignette ring
        paintSoftRing(
          canvas,
          center,
          sw * 0.6,
          Color.fromRGBO(124, 77, 255, tunnelT * 0.15),
          sw * 0.4,
          sw * 0.2,
        );
      }

      canvas.restore();
    }

    canvas.restore();

    _renderPortalTear(canvas);
  }

  /// World-space bounds for a layer that fades the whole ship: the hull
  /// with its glow and engine plumes, and every grain of its wake. The wake
  /// is advanced to this frame first (the render's own update is then free)
  /// so the box holds what is about to be drawn.
  Rect _shipLayerBounds({double boost = 0}) {
    ship.wake.update(
      _elapsed,
      ship.pos,
      ship.angle,
      activeShipSkin,
      boost: boost,
    );
    // Hulls are ~45 units tall; their light pool reaches 36 and a boosted
    // plume ~30 past the tail. 96 covers all of it with room to spare.
    final hull = Rect.fromCircle(center: ship.pos, radius: 96);
    final wake = ship.wake.bounds;
    // Grains are points up to ~8 across.
    return wake == null ? hull : hull.expandToInclude(wake.inflate(12));
  }

  // ── fog ────────────────────────────────────────────────

  CosmicPlanet? _orbitalPartner;

  /// Draws every planet's pull as a ring of grains (gravity_ring_art.dart).
  final GrainRingPainter _gravityRings = GrainRingPainter();

  /// Set by the screen while the ship console is open, where a home is
  /// built or moved: the edge of each planet's pull is shown, so it can be
  /// seen whether a home placed here would orbit. It comes on at once (the
  /// world is held still under the console) and fades slowly once the
  /// console closes. Before there is a home at all it shows anyway.
  bool get homePlacementPreview => _homePlacementPreview;
  set homePlacementPreview(bool v) {
    _homePlacementPreview = v;
    if (v) _captureBandFade = 1;
  }

  bool _homePlacementPreview = false;

  /// 0..1, easing toward whether the pull's edge is shown.
  double _captureBandFade = 0;
  bool _homeOrbitsPartner =
      false; // true → home orbits partner; false → partner orbits home
  double _orbitAngle = 0;
  double _orbitRadius = 0;
  double _orbitSpeed = 0; // rad/sec
}
