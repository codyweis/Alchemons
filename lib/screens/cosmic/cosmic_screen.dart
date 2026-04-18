// Organized refactor of cosmic_screen.dart

import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/screens/cosmic/cosmic_summon_screen.dart';
import 'package:alchemons/screens/cosmic/space_market_sheet.dart';
import 'package:alchemons/screens/cosmic/cosmic_sell_sheet.dart';
import 'package:alchemons/screens/cosmic/gold_conversion_sheet.dart';
import 'package:alchemons/screens/scenes/scene_page.dart';
import 'package:alchemons/screens/scenes/landscape_dialog.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_screen.dart';
import 'package:alchemons/games/wilderness/rift_portal_component.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/scenes/poison/poison_scene.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/services/wildlife_generator.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/screens/scenes/rift_portal_screen.dart';
import 'package:alchemons/screens/cosmic/elemental_nexus_screen.dart';
import 'package:alchemons/screens/cosmic/blood_ring_ending_screen.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';

// Scorched Forge design tokens
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';

// Local widget imports
import 'models/map_marker.dart';
import 'models/cosmic_summon_result.dart';
import 'widgets/widgets.dart';
import 'widgets/mini_map_circle.dart';
import 'widgets/contest_arena_overlays.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';

class CosmicScreen extends StatefulWidget {
  const CosmicScreen({super.key});

  @override
  State<CosmicScreen> createState() => _CosmicScreenState();
}

class _CosmicScreenState extends State<CosmicScreen>
    with TickerProviderStateMixin {
  static const _prefsKey = 'cosmic_fog_state_v2';
  static const _seedKey = 'cosmic_world_seed_v2';
  static const _planetPathwayIntroSeenKey =
      'cosmic_planet_pathway_intro_seen_v1';
  static const _planetRecipeArrivalIntroSeenKey =
      'cosmic_planet_recipe_arrival_intro_seen_v1';
  static const _cosmicIntroPromptedKey = 'cosmic_intro_prompted_v1';
  static const _cosmicIntroCompletedKey = 'cosmic_intro_completed_v1';

  late int _worldSeed;
  late CosmicWorld _world;
  CosmicGame? _game;
  Map<String, Map<String, int>>? _recipes;
  bool _showMiniMap = false;
  bool _showPinnedMiniMap = true;
  bool _topHudCollapsed = false;
  String? _pinnedRecipeElement;
  CosmicSummonResult? _summonResult;
  bool _arcaneUnlocked = false;

  // Recipe & storage state
  CosmicPlanet? _nearPlanet;
  bool _showingPlanetRecipeArrivalIntro = false;
  CosmicRecipeState _recipeState = CosmicRecipeState.fresh();
  ElementStorage _elementStorage = ElementStorage();
  bool _showElementsCaptured = false;
  Map<String, double> _capturedBreakdown = {};

  // Star dust state
  Set<int> _collectedDust = {};
  static const _dustPrefsKey = 'cosmic_star_dust_v1';

  // Rift portal state
  bool _isNearRift = false;

  // Elemental Nexus state
  bool _isNearNexus = false;
  static const _nexusPrefsKey = 'cosmic_elemental_nexus_v1';
  String? _nearPocketPortalElement; // non-null when near a pocket portal

  // Battle Ring state
  bool _isNearBattleRing = false;
  static const _battleRingPrefsKey = 'cosmic_battle_ring_v1';

  // Trait contest state
  CosmicContestArena? _nearContestArena;
  CosmicContestProgress _contestProgress = CosmicContestProgress.fresh();
  Set<String> _knownContestHintIds = {};
  Map<int, int> _beautyContestRotationByLevel = {};
  static const _contestProgressPrefsKey = 'cosmic_trait_contests_v1';
  static const _contestHintsPrefsKey = 'cosmic_trait_hint_notes_v1';
  static const _beautyContestRotationPrefsKey =
      'cosmic_beauty_contest_rotation_v1';
  static const bool _contestDebugShowAllOnMap = false;
  static const bool _contestDebugAllowMapTeleport = false;
  static const Map<CosmicContestTrait, String>
  _contestMasteryEffectOfferByTrait = {
    CosmicContestTrait.beauty: ShopService.beautyContestEffectOfferId,
    CosmicContestTrait.speed: ShopService.speedContestEffectOfferId,
    CosmicContestTrait.strength: ShopService.strengthContestEffectOfferId,
    CosmicContestTrait.intelligence:
        ShopService.intelligenceContestEffectOfferId,
  };

  // Blood Ring state
  bool _isNearBloodRing = false;
  static const _bloodRingPrefsKey = 'cosmic_blood_ring_v1';
  bool _runningBloodEnding = false;

  // Space market state
  SpacePOI? _nearMarketPOI;

  // Home planet state
  HomePlanet? _homePlanet;
  static const _homePlanetPrefsKey = 'cosmic_home_planet_v1';

  // Shooting state
  bool _isShooting = false;
  bool _isShootingMissiles = false;
  bool _isBoosting = false;
  // Tracks which weapon the sliding finger is currently on (0=bullets, 1=missiles, -1=none)
  int _activeWeaponSlot = -1;
  final GlobalKey _weaponColumnKey = GlobalKey();

  // Slow-mode toggle
  bool _slowMode = false;

  // Companion tether toggle (magnet)
  bool _companionTethered = true;

  // Joystick toggle (on by default)
  bool _showJoystick = true;
  bool _largeJoystick = true;

  // Tap-to-shoot toggle (off by default)
  bool _tapToShoot = false;

  // Boost toggle mode (off = hold, on = tap to toggle)
  bool _boostToggleMode = false;
  int? _movePointerId;
  final Set<int> _tapShootPointerIds = {};

  // Cargo upgrade level (0-3)
  int _cargoLevel = 0;

  // Near-home state
  bool _isNearHome = false;
  double _healTimer = 0; // gradual healing accumulator

  // Map marker state
  static const _markersPrefsKey = 'cosmic_map_markers_v1';
  static const _pinnedRecipePrefsKey = 'cosmic_pinned_recipe_element_v1';
  List<MapMarker> _mapMarkers = [];

  // Home customization state
  HomeCustomizationState _customizationState = HomeCustomizationState();
  static const _customizationPrefsKey = 'cosmic_home_customization_v1';
  bool _showCustomizationMenu = false;
  bool _showChamberPicker = false;
  bool _showShipMenu = false;
  bool _showSettingsMenu = false;
  bool _showSandboxPanel = false;
  bool _sandboxMode = false;
  bool _showHomeMenu = false;
  bool _showPartyPicker = false;
  bool _showGarrisonPicker = false;
  bool _runningCosmicIntro = false;
  bool _awaitingShipMenuTap = false;
  bool _awaitingBuildHomeTap = false;

  // Cosmic party state
  int _cosmicPartySlotsUnlocked = 0;
  List<CosmicPartyMember?> _partyMembers =
      []; // length = _cosmicPartySlotsUnlocked
  int? _activeCompanionSlot; // which slot is currently summoned (-1=none)

  /// Tracks HP fraction (0.0–1.0) for each party slot between summons.
  /// 1.0 = full health, 0.0 = dead. Reset to 1.0 when near home.
  final Map<int, double> _companionHpFraction = {};
  final Map<int, double> _companionSpecialCooldown = {};
  Timer? _companionCooldownUiTimer;

  // Home garrison state (alchemons stationed at home planet)
  List<CosmicPartyMember?> _garrisonMembers = [];

  bool get _anyOverlayOpen =>
      _showCustomizationMenu ||
      _showChamberPicker ||
      _showShipMenu ||
      _showSettingsMenu ||
      _showSandboxPanel ||
      _showHomeMenu ||
      _showPartyPicker ||
      _showGarrisonPicker ||
      (_game?.beautyContestCinematicActive ?? false);

  int _sandboxCompanionStatTier = 4;
  int _sandboxEnemyCount = 1;
  int _sandboxBossLevel = 3;
  String _sandboxCreatureQuery = '';
  EnemyTier _sandboxEnemyTier = EnemyTier.sentinel;
  EnemyBehavior _sandboxEnemyBehavior = EnemyBehavior.aggressive;
  BossTemplate _sandboxBossTemplate = kBossTemplates.first;

  // Meter animation
  late AnimationController _meterPulse;
  late AnimationController _miniMapCtrl;
  late AnimationController _planetMeterCtrl;
  late AnimationController _bloodRitualCtrl;
  late AnimationController _screenShakeCtrl;
  late Animation<double> _screenShakeAnim;
  bool _showBloodRitualOverlay = false;

  // ── Discovery quote milestones ──
  static final _quoteThresholds = <List<Object>>[
    [
      0.01,
      'Two possibilities exist: either we are alone in the Universe or we are not.',
    ],
    [0.05, 'When you gaze long into the abyss, the abyss gazes also into you.'],
    [
      0.25,
      'The cosmos is within us. We are made of star-stuff. We are a way for the universe to know itself.',
    ],
    [
      0.50,
      'The real voyage of discovery consists not in seeking new landscapes, but in having new eyes.',
    ],
    [1.00, 'The answer is\u2026 don\'t think about it.'],
  ];
  Set<double> _triggeredQuotes = {};
  static const _quotesPrefsKey = 'cosmic_triggered_quotes_v1';
  String? _activeQuote;
  late AnimationController _quoteFade;

  // Periodic auto-save timer
  DateTime _lastSave = DateTime.now();
  static const _saveInterval = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<AudioController>().playCosmicExplorationMusic());
    });

    _meterPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _quoteFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _miniMapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _planetMeterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _bloodRitualCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _screenShakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _screenShakeAnim =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: -14.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -14.0, end: 14.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 14.0, end: -12.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _screenShakeCtrl, curve: Curves.easeInOut),
        );

    _companionCooldownUiTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) {
        if (!mounted) return;
        if (_activeCompanionSlot != null && _game?.activeCompanion != null) {
          setState(() {});
        }
      },
    );

    _initWorld();
  }

  Future<void> _initWorld() async {
    // Load recipes
    final raw = await rootBundle.loadString(
      'assets/data/alchemons_element_recipes.json',
    );
    final map = json.decode(raw) as Map<String, dynamic>;
    final src = map['recipes'] as Map<String, dynamic>;
    _recipes = {};
    for (final e in src.entries) {
      final rawKey = e.key.trim();
      final rawVal = e.value as Map<String, dynamic>;
      final inner = <String, int>{};
      for (final e2 in rawVal.entries) {
        inner[e2.key.trim()] = (e2.value as num).toInt();
      }
      if (rawKey.contains('+')) {
        final parts = rawKey.split('+').map((s) => s.trim()).toList();
        final k = ElementRecipeConfig.keyOf(parts[0], parts[1]);
        _recipes![k] = inner;
      } else {
        _recipes![rawKey] = inner;
      }
    }

    // Load / create world seed
    final prefs = await SharedPreferences.getInstance();
    _worldSeed =
        prefs.getInt(_seedKey) ?? DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_seedKey, _worldSeed);

    _world = CosmicWorld.generate(seed: _worldSeed);

    // Check arcane unlock
    if (mounted) {
      final db = context.read<AlchemonsDatabase>();
      final v = await db.settingsDao.getSetting('arcane_portal_unlocked');
      _arcaneUnlocked = v == '1';
    }

    // Load recipe state
    final recipeRaw = prefs.getString('cosmic_recipe_state');
    if (recipeRaw != null) {
      _recipeState = CosmicRecipeState.deserialise(recipeRaw);
    }

    // One-time cleanup: remove stale Poison pathway unlocks left from
    // earlier debug entry modes so recipe gating behaves normally again.
    const recipeDebugCleanupKey = 'cosmic_recipe_debug_cleanup_v1';
    final didRecipeDebugCleanup = prefs.getBool(recipeDebugCleanupKey) ?? false;
    if (!didRecipeDebugCleanup && _recipeState.isMaxMastered('Poison')) {
      final unlocked = Map<String, int>.from(_recipeState.unlockedLevels)
        ..remove('Poison');
      final masks = Map<String, int>.from(_recipeState.completedMasks)
        ..remove('Poison');
      final rolls = Map<String, int>.from(_recipeState.postMaxRollLevels)
        ..remove('Poison');
      _recipeState = CosmicRecipeState(
        unlockedLevels: unlocked,
        completedMasks: masks,
        postMaxRollLevels: rolls,
      );
      await prefs.setString('cosmic_recipe_state', _recipeState.serialise());
    }
    if (!didRecipeDebugCleanup) {
      await prefs.setBool(recipeDebugCleanupKey, true);
    }

    // Load element storage
    final storageRaw = prefs.getString('cosmic_element_storage');
    if (storageRaw != null) {
      _elementStorage = ElementStorage.deserialise(storageRaw);
    }

    // Load collected star dust
    final dustRaw = prefs.getString(_dustPrefsKey);
    if (dustRaw != null) {
      _collectedDust = StarDust.deserialiseCollected(dustRaw);
    }

    // Load trait contest progression + discovered hint notes
    final contestRaw = prefs.getString(_contestProgressPrefsKey);
    if (contestRaw != null && contestRaw.isNotEmpty) {
      _contestProgress = CosmicContestProgress.deserialise(contestRaw);
    }
    final contestHintRaw = prefs.getString(_contestHintsPrefsKey);
    if (contestHintRaw != null && contestHintRaw.isNotEmpty) {
      _knownContestHintIds = deserialiseContestHintIds(contestHintRaw);
    }
    final beautyRotationRaw = prefs.getString(_beautyContestRotationPrefsKey);
    if (beautyRotationRaw != null && beautyRotationRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(beautyRotationRaw);
        if (decoded is Map<String, dynamic>) {
          _beautyContestRotationByLevel = {
            for (final entry in decoded.entries)
              if (int.tryParse(entry.key) case final level?)
                level: (entry.value is num ? (entry.value as num).toInt() : 0),
          }..removeWhere((k, _) => k < 1 || k > 5);
        }
      } catch (_) {
        _beautyContestRotationByLevel = {};
      }
    }
    await _syncContestMasteryShopUnlocks();

    // Load home planet
    final homeRaw = prefs.getString(_homePlanetPrefsKey);
    if (homeRaw != null) {
      _homePlanet = HomePlanet.deserialise(homeRaw);
    }

    // Load customization state
    final customRaw = prefs.getString(_customizationPrefsKey);
    if (customRaw != null) {
      _customizationState = HomeCustomizationState.deserialise(customRaw);
    }

    // Load cargo upgrade level
    _cargoLevel = prefs.getInt('cosmic_cargo_level') ?? 0;

    // Load joystick preference
    _showJoystick = prefs.getBool('cosmic_joystick_enabled') ?? true;
    _largeJoystick = prefs.getBool('cosmic_large_joystick') ?? true;

    // Load tap-to-shoot preference
    _tapToShoot = prefs.getBool('cosmic_tap_to_shoot') ?? false;
    _game?.tapToShootMode = _tapToShoot;

    // Load boost toggle mode preference
    _boostToggleMode = prefs.getBool('cosmic_boost_toggle') ?? false;

    // Load fuel state
    final fuelRaw = prefs.getString('cosmic_ship_fuel');
    ShipFuel? savedFuel;
    if (fuelRaw != null) {
      savedFuel = ShipFuel.deserialise(fuelRaw);
    }

    // Load orbital stockpile
    final orbitalStock = prefs.getInt('cosmic_orbital_stockpile') ?? 0;

    // Load missile ammo
    final missileAmmo = prefs.getInt('cosmic_missile_ammo') ?? 0;

    // Load prismatic field reward flag
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final prismaticClaimed = await db.settingsDao
        .getCosmicPrismaticRewardClaimed();

    // Load elemental nexus state
    final nexusRaw = prefs.getString(_nexusPrefsKey);
    ElementalNexus? savedNexus;
    if (nexusRaw != null && nexusRaw.isNotEmpty) {
      savedNexus = ElementalNexus.deserialise(nexusRaw);
    }

    // Load battle ring state
    final battleRingRaw = prefs.getString(_battleRingPrefsKey);
    BattleRing? savedBattleRing;
    if (battleRingRaw != null && battleRingRaw.isNotEmpty) {
      savedBattleRing = BattleRing.deserialise(battleRingRaw);
    }

    // Load blood ring state
    final bloodRingRaw = prefs.getString(_bloodRingPrefsKey);
    BloodRing? savedBloodRing;
    if (bloodRingRaw != null && bloodRingRaw.isNotEmpty) {
      savedBloodRing = BloodRing.deserialise(bloodRingRaw);
    }

    // Load map markers
    final markersRaw = prefs.getString(_markersPrefsKey);
    if (markersRaw != null && markersRaw.isNotEmpty) {
      _mapMarkers = MapMarker.deserialiseList(markersRaw);
    }
    _pinnedRecipeElement = prefs.getString(_pinnedRecipePrefsKey);

    // Load triggered quotes
    final quotesRaw = prefs.getString(_quotesPrefsKey);
    if (quotesRaw != null && quotesRaw.isNotEmpty) {
      _triggeredQuotes = quotesRaw
          .split(',')
          .map((s) => double.tryParse(s) ?? -1)
          .where((d) => d >= 0)
          .toSet();
    }

    // Restore fog state
    final fogRaw = prefs.getString(_prefsKey);
    CosmicFogState? savedFog;
    if (fogRaw != null) {
      final parsed = CosmicFogState.deserialise(fogRaw);
      if (parsed.worldSeed == _worldSeed) {
        savedFog = parsed;
      }
    }

    final game = CosmicGame(
      world_: _world,
      onMeterChanged: _onMeterChanged,
      onPeriodicSave: _periodicSave,
      onNearPlanet: _onNearPlanet,
      onStarDustCollected: _onStarDustCollected,
      onNearRift: _onNearRift,
      onNearNexus: _onNearNexus,
      onNearBattleRing: _onNearBattleRing,
      onNearBloodRing: _onNearBloodRing,
      onBattleRingCancelled: _onBattleRingCancelled,
      onNearContestArena: _onNearContestArena,
      onContestHintCollected: _onContestHintCollected,
      onHomePlanetBuilt: _onHomePlanetBuilt,

      onBossSpawned: _onBossSpawned,
      onShipDied: _onShipDied,
      onLootCollected: _onLootCollected,
      onBossDefeated: _onBossDefeated,
      onPOIDiscovered: _onPOIDiscovered,
      onNearHome: _onNearHome,
      onNearMarket: _onNearMarket,
      onCompanionAutoReturned: _onCompanionAutoReturned,
      onCompanionDied: _onCompanionDied,
      initialCustomizations: _customizationState.activeIds,
      initialOptions: _customizationState.options,
      initialAmmoId: _customizationState.activeAmmo?.id,
    );
    game.activeWeaponId = _customizationState.activeWeapon;
    game.hasMissiles = _customizationState.hasMissiles;
    game.activeShipSkin = _customizationState.activeShipSkin;
    // Restore power-up levels
    game.ammoUpgradeLevel = _customizationState.ammoUpgradeLevel;
    game.missileUpgradeLevel = _customizationState.missileUpgradeLevel;
    // Restore fuel (apply upgrade capacity)
    final upgradedCapacity = ShipFuel.capacityForLevel(
      _customizationState.fuelUpgradeLevel,
    );
    game.shipFuel.capacity = upgradedCapacity;
    if (savedFuel != null) {
      game.shipFuel.fuel = savedFuel.fuel.clamp(0.0, upgradedCapacity);
    }
    // Restore orbital stockpile
    game.orbitalStockpile = orbitalStock;
    // Restore missile ammo
    game.missileAmmo = missileAmmo;
    // Restore prismatic reward flag
    game.prismaticRewardClaimed = prismaticClaimed;
    game.prismaticField.rewardClaimed = prismaticClaimed;
    game.onPrismaticRewardClaimed = _onPrismaticRewardClaimed;
    // Restore elemental nexus state
    if (savedNexus != null) {
      game.elementalNexus.discovered = savedNexus.discovered;
      game.elementalNexus.phase = savedNexus.phase;
      game.elementalNexus.chosenElement = savedNexus.chosenElement;
      game.elementalNexus.harvesterAwarded = savedNexus.harvesterAwarded;
      game.elementalNexus.inPocket = savedNexus.inPocket;
      game.elementalNexus.prePocketShipPos = savedNexus.prePocketShipPos;
    }
    // Wire pocket portal proximity callback
    game.onNearPocketPortal = _onNearPocketPortal;
    // If the nexus was in pocket mode when app was killed, resume pocket
    if (game.elementalNexus.inPocket) {
      game.inNexusPocket = true;
      // If they were mid-encounter, resume encounter
      if (game.elementalNexus.phase == NexusPhase.inEncounter &&
          game.elementalNexus.chosenElement != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openNexusEncounter(game.elementalNexus.chosenElement!);
        });
      }
    } else if (game.elementalNexus.phase != NexusPhase.outside) {
      // Legacy: was mid-screen when killed, enter pocket instead
      game.enterNexusPocket();
      _saveNexusState();
    }
    // Restore battle ring state
    if (savedBattleRing != null) {
      game.battleRing.discovered = savedBattleRing.discovered;
      game.battleRing.currentLevel = savedBattleRing.currentLevel;
      game.battleRing.inBattle = false; // always reset on load
    }
    if (savedBloodRing != null) {
      game.bloodRing.discovered = savedBloodRing.discovered;
      game.bloodRing.ritualCompleted = savedBloodRing.ritualCompleted;
      game.bloodRing.lastOfferingInstanceId =
          savedBloodRing.lastOfferingInstanceId;
      game.bloodRing.lastOfferingName = savedBloodRing.lastOfferingName;
      game.bloodRing.lastOfferingImagePath =
          savedBloodRing.lastOfferingImagePath;
      game.bloodRing.lastOfferingElement = savedBloodRing.lastOfferingElement;
      game.bloodRing.lastOfferingFamily = savedBloodRing.lastOfferingFamily;
      game.bloodRing.lastOfferingIntelligence =
          savedBloodRing.lastOfferingIntelligence;
      game.bloodRing.lastOfferingStrength = savedBloodRing.lastOfferingStrength;
      game.bloodRing.lastOfferingBeauty = savedBloodRing.lastOfferingBeauty;
    }
    game.onBattleRingWon = _onBattleRingWon;
    game.onBattleRingLost = _onBattleRingLost;
    // Deploy orbitals if equipped and have stockpile
    if (_customizationState.hasOrbitals && orbitalStock > 0) {
      final toDeploy = min(OrbitalSentinel.maxActive, orbitalStock);
      for (var i = 0; i < toDeploy; i++) {
        game.orbitals.add(
          OrbitalSentinel(angle: i * (2 * pi / OrbitalSentinel.maxActive)),
        );
        game.orbitalStockpile--;
      }
    }
    _game = game;
    await _saveBloodRingState();

    if (savedFog != null) {
      // Defer restoring fog until after onLoad
      WidgetsBinding.instance.addPostFrameCallback((_) {
        game.restoreFogState(savedFog!);
        // Restore star dust after fog
        if (_collectedDust.isNotEmpty) {
          game.restoreStarDust(_collectedDust);
        }
        if (_knownContestHintIds.isNotEmpty) {
          game.restoreCollectedContestHints(_knownContestHintIds);
        }
        // Restore home planet
        if (_homePlanet != null) {
          game.restoreHomePlanet(_homePlanet!);
          _initOrbitalChambers();
        }
        _initCosmicParty();
        _initGarrison();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_collectedDust.isNotEmpty) {
          game.restoreStarDust(_collectedDust);
        }
        if (_knownContestHintIds.isNotEmpty) {
          game.restoreCollectedContestHints(_knownContestHintIds);
        }
        if (_homePlanet != null) {
          game.restoreHomePlanet(_homePlanet!);
          _initOrbitalChambers();
        }
        _initCosmicParty();
        _initGarrison();
      });
    }

    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_maybeRunCosmicIntro());
      }
    });
  }

  /// Load creature blob slots and spawn orbital chambers around home planet.
  Future<void> _initOrbitalChambers() async {
    if (_game == null || _homePlanet == null || !mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();

    // Load unlocked blob slots (1–3)
    final slots = await db.settingsDao.getBlobSlotsUnlocked();
    final savedIds = await db.settingsDao.getBlobInstanceSlots();

    final chamberData =
        <(Color, String?, String?, String?, String?, SpriteVisuals?)>[];

    for (var i = 0; i < slots; i++) {
      final id = i < savedIds.length ? savedIds[i] : null;
      if (id != null) {
        final inst = await db.creatureDao.getInstance(id);
        if (inst != null) {
          final base = catalog.getCreatureById(inst.baseId);
          final typeName = (base?.types.isNotEmpty ?? false)
              ? base!.types.first
              : 'Earth';
          final color = BreedConstants.getTypeColor(typeName);
          final name = inst.nickname ?? base?.name ?? inst.baseId;
          final imgPath = base?.image;
          final visuals = visualsFromInstance(base, inst);
          chamberData.add((
            color,
            inst.instanceId,
            inst.baseId,
            name,
            imgPath,
            visuals,
          ));
          continue;
        }
      }
      // Empty / unassigned slot — tracked for picker but not rendered
      chamberData.add((
        Colors.white.withValues(alpha: 0.35),
        null,
        null,
        null,
        null,
        null,
      ));
    }

    _game!.spawnOrbitalChambers(chamberData);
  }

  /// Assign a creature instance to an orbital chamber slot.
  Future<void> _handleAssignChamber(int slotIndex, String instanceId) async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    // Save to blob slot in DB
    await db.settingsDao.setBlobSlotInstance(slotIndex, instanceId);
    // Re-init chambers to refresh
    await _initOrbitalChambers();
    if (mounted) setState(() {});
  }

  /// Clear a chamber slot.
  Future<void> _handleClearChamber(int slotIndex) async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    await db.settingsDao.setBlobSlotInstance(slotIndex, null);
    await _initOrbitalChambers();
    if (mounted) setState(() {});
  }

  // ── Cosmic Party ──

  Future<void> _initCosmicParty() async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final slots = await db.settingsDao.getCosmicPartySlotsUnlocked();
    final savedIds = await db.settingsDao.getCosmicPartySlots();

    final members = <CosmicPartyMember?>[];
    for (var i = 0; i < slots; i++) {
      final id = i < savedIds.length ? savedIds[i] : null;
      if (id != null) {
        final inst = await db.creatureDao.getInstance(id);
        if (inst != null) {
          // Compute effective stamina (with time-based regen)
          final elapsed =
              DateTime.now().toUtc().millisecondsSinceEpoch -
              inst.staminaLastUtcMs;
          final regenBars = elapsed ~/ (6 * 3600 * 1000); // 1 bar per 6 h
          final effectiveBars = (inst.staminaBars + regenBars).clamp(
            0,
            inst.staminaMax,
          );

          final base = catalog.getCreatureById(inst.baseId);
          final typeName = (base?.types.isNotEmpty ?? false)
              ? base!.types.first
              : 'Earth';
          final family = base?.mutationFamily ?? 'kin';
          final name = inst.nickname ?? base?.name ?? inst.baseId;
          final sheet = base?.spriteData != null
              ? sheetFromCreature(base!)
              : null;
          final visuals = visualsFromInstance(base, inst);
          members.add(
            CosmicPartyMember(
              instanceId: inst.instanceId,
              baseId: inst.baseId,
              displayName: name,
              imagePath: base?.image != null
                  ? 'assets/images/${base!.image}'
                  : null,
              element: typeName,
              family: family,
              level: inst.level,
              statSpeed: inst.statSpeed.toDouble(),
              statIntelligence: inst.statIntelligence.toDouble(),
              statStrength: inst.statStrength.toDouble(),
              statBeauty: inst.statBeauty.toDouble(),
              slotIndex: i,
              staminaBars: effectiveBars,
              staminaMax: inst.staminaMax,
              spriteSheet: sheet,
              spriteVisuals: visuals,
            ),
          );
          continue;
        }
      }
      members.add(null);
    }
    if (mounted) {
      setState(() {
        _cosmicPartySlotsUnlocked = slots;
        _partyMembers = members;
      });
    }
  }

  Future<void> _handleAssignPartySlot(int slotIndex, String instanceId) async {
    if (!mounted) return;
    // Block if already stationed in garrison
    if (_garrisonMembers.any((m) => m?.instanceId == instanceId)) {
      _showQuote('Already stationed at your home base!');
      return;
    }
    // If the slot being replaced has an active companion, return it first
    if (_activeCompanionSlot == slotIndex) {
      _handleReturnCompanion();
    }
    final db = context.read<AlchemonsDatabase>();
    // Clear the old instance from the slot first, then assign the new one
    await db.settingsDao.setCosmicPartySlotInstance(slotIndex, null);
    await db.settingsDao.setCosmicPartySlotInstance(slotIndex, instanceId);
    await _initCosmicParty();
  }

  Future<void> _handleClearPartySlot(int slotIndex) async {
    if (!mounted) return;
    // If the summoned companion is from this slot, return it first
    if (_activeCompanionSlot == slotIndex) {
      _handleReturnCompanion();
    }
    final db = context.read<AlchemonsDatabase>();
    await db.settingsDao.setCosmicPartySlotInstance(slotIndex, null);
    await _initCosmicParty();
  }

  void _handleSummonCompanion(int slotIndex) {
    _handleSummonCompanionAsync(slotIndex);
  }

  void _openPartyPickerFromSlotButton() {
    if (!_isNearHome) {
      _showQuote('Return home to manage your party.');
      return;
    }
    setState(() => _showPartyPicker = true);
  }

  Future<void> _handlePartySlotLongPress(int slotIndex) async {
    if (_isNearHome) {
      _openPartyPickerFromSlotButton();
      return;
    }

    if (slotIndex < 0 || slotIndex >= _partyMembers.length) return;
    final member = _partyMembers[slotIndex];
    if (member == null) {
      _showQuote('No Alchemon assigned to this slot.');
      return;
    }

    final catalog = context.read<CreatureCatalog>();
    final creature = catalog.getCreatureById(member.baseId);
    if (creature == null) {
      _showQuote('Unable to load Alchemon details.');
      return;
    }

    await CreatureDetailsDialog.show(
      context,
      creature,
      true,
      instanceId: member.instanceId,
    );
  }

  CosmicPartyMember _copyMemberWithStamina(
    CosmicPartyMember member, {
    required int staminaBars,
    int? staminaMax,
  }) {
    return CosmicPartyMember(
      instanceId: member.instanceId,
      baseId: member.baseId,
      displayName: member.displayName,
      imagePath: member.imagePath,
      element: member.element,
      family: member.family,
      level: member.level,
      statSpeed: member.statSpeed,
      statIntelligence: member.statIntelligence,
      statStrength: member.statStrength,
      statBeauty: member.statBeauty,
      slotIndex: member.slotIndex,
      staminaBars: staminaBars,
      staminaMax: staminaMax ?? member.staminaMax,
      spriteSheet: member.spriteSheet,
      spriteVisuals: member.spriteVisuals,
      visualVariant: member.visualVariant,
      spawnPosition: member.spawnPosition,
    );
  }

  Future<bool> _consumeContestStamina({
    required int slotIndex,
    required CosmicPartyMember member,
  }) async {
    final db = context.read<AlchemonsDatabase>();
    final staminaService = StaminaService(db);
    final refreshed = await staminaService.refreshAndGet(member.instanceId);
    if (refreshed == null) {
      _showQuote('Active companion missing.');
      return false;
    }

    if (refreshed.staminaBars < 1) {
      _showQuote(
        'No stamina left for contests. Return home or wait to recover.',
      );
      await _initCosmicParty();
      return false;
    }

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final remaining = refreshed.staminaBars - 1;
    await db.creatureDao.updateStamina(
      instanceId: refreshed.instanceId,
      staminaBars: remaining,
      staminaLastUtcMs: nowMs,
    );

    if (!mounted) return true;

    if (slotIndex >= 0 && slotIndex < _partyMembers.length) {
      final slotMember = _partyMembers[slotIndex];
      if (slotMember != null && slotMember.instanceId == member.instanceId) {
        setState(() {
          _partyMembers[slotIndex] = _copyMemberWithStamina(
            slotMember,
            staminaBars: remaining,
            staminaMax: refreshed.staminaMax,
          );
        });
      }
    }

    return true;
  }

  Future<void> _handleSummonCompanionAsync(int slotIndex) async {
    if (_game == null || slotIndex >= _partyMembers.length) return;
    // Block swapping companions during a ring battle
    if (_game!.battleRing.inBattle) {
      _showQuote('Cannot swap companions during a battle ring fight!');
      return;
    }
    var member = _partyMembers[slotIndex];
    if (member == null) return;

    // Refresh visuals at summon time so in-world rendering matches picker
    // previews after any recent alchemy/effect changes.
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final latestInst = await db.creatureDao.getInstance(member.instanceId);
    if (latestInst != null) {
      final latestBase = catalog.getCreatureById(latestInst.baseId);
      final latestSheet = latestBase?.spriteData != null
          ? sheetFromCreature(latestBase!)
          : member.spriteSheet;
      final latestVisuals = visualsFromInstance(latestBase, latestInst);
      member = CosmicPartyMember(
        instanceId: member.instanceId,
        baseId: member.baseId,
        displayName: member.displayName,
        imagePath: member.imagePath,
        element: member.element,
        family: member.family,
        level: member.level,
        statSpeed: member.statSpeed,
        statIntelligence: member.statIntelligence,
        statStrength: member.statStrength,
        statBeauty: member.statBeauty,
        slotIndex: member.slotIndex,
        staminaBars: member.staminaBars,
        staminaMax: member.staminaMax,
        spriteSheet: latestSheet,
        spriteVisuals: latestVisuals,
        visualVariant: member.visualVariant,
        spawnPosition: member.spawnPosition,
      );
      _partyMembers[slotIndex] = member;
    }

    // Block summon if this companion has 0 HP (dead)
    final hpFrac = _companionHpFraction[slotIndex] ?? 1.0;
    if (hpFrac <= 0) {
      _showQuote('This Alchemon is exhausted! Return home to heal.');
      return;
    }
    // Return any currently active companion (save its HP first)
    if (_activeCompanionSlot != null) {
      _saveCompanionHp();
      _game!.returnCompanion();
    }
    _game!.summonCompanion(
      member,
      hpFraction: hpFrac,
      initialSpecialCooldown: _companionSpecialCooldown[slotIndex] ?? 0.0,
    );
    setState(() => _activeCompanionSlot = slotIndex);
  }

  void _handleReturnCompanion() {
    if (_game == null || _activeCompanionSlot == null) return;
    // Block recall during a battle ring fight
    if (_game!.battleRing.inBattle) {
      _showQuote('Cannot recall during a battle ring fight!');
      return;
    }
    _saveCompanionHp();
    _game!.returnCompanion();
    setState(() => _activeCompanionSlot = null);
  }

  Offset get _sandboxAreaCenter {
    final candidates = <Offset>[
      Offset(_world.worldSize.width * 0.08, _world.worldSize.height * 0.08),
      Offset(_world.worldSize.width * 0.92, _world.worldSize.height * 0.08),
      Offset(_world.worldSize.width * 0.08, _world.worldSize.height * 0.92),
      Offset(_world.worldSize.width * 0.92, _world.worldSize.height * 0.92),
      Offset(_world.worldSize.width * 0.50, _world.worldSize.height * 0.10),
      Offset(_world.worldSize.width * 0.50, _world.worldSize.height * 0.90),
      Offset(_world.worldSize.width * 0.10, _world.worldSize.height * 0.50),
      Offset(_world.worldSize.width * 0.90, _world.worldSize.height * 0.50),
    ];

    double clearanceFor(Offset point) {
      var minDist = double.infinity;
      final pois = _game?.spacePOIs ?? const <SpacePOI>[];
      final whirls = _game?.galaxyWhirls ?? const <GalaxyWhirl>[];

      for (final planet in _world.planets) {
        minDist = min(
          minDist,
          (planet.position - point).distance - planet.radius,
        );
      }
      for (final poi in pois) {
        minDist = min(minDist, (poi.position - point).distance - poi.radius);
      }
      for (final whirl in whirls) {
        minDist = min(minDist, (whirl.position - point).distance - 240.0);
      }
      for (final arena in _world.contestArenas) {
        minDist = min(
          minDist,
          (arena.position - point).distance - CosmicContestArena.visualRadius,
        );
      }

      minDist = min(
        minDist,
        (_world.elementalNexus.position - point).distance -
            ElementalNexus.visualRadius,
      );
      minDist = min(
        minDist,
        (_world.battleRing.position - point).distance - BattleRing.visualRadius,
      );
      minDist = min(
        minDist,
        (_world.bloodRing.position - point).distance - BloodRing.visualRadius,
      );
      if (_homePlanet != null) {
        minDist = min(
          minDist,
          (_homePlanet!.position - point).distance - _homePlanet!.visualRadius,
        );
      }

      final beltOuter = _game?.asteroidBelt.outerRadius ?? 0.0;
      if (beltOuter > 0) {
        final beltCenter = _game!.asteroidBelt.center;
        final beltDist = (beltCenter - point).distance;
        if (beltDist < beltOuter + 500) {
          minDist = min(minDist, beltDist - (beltOuter + 500));
        }
      }

      return minDist;
    }

    return candidates.reduce(
      (best, candidate) =>
          clearanceFor(candidate) > clearanceFor(best) ? candidate : best,
    );
  }

  List<Creature> _sandboxCreatures(CreatureCatalog catalog) {
    final query = _sandboxCreatureQuery.trim().toLowerCase();
    final list =
        catalog.creatures
            .where((c) => c.spriteData != null)
            .where((c) => (c.mutationFamily ?? '').trim().isNotEmpty)
            .where((c) {
              if (query.isEmpty) return true;
              return c.name.toLowerCase().contains(query) ||
                  c.id.toLowerCase().contains(query) ||
                  c.types.any((t) => t.toLowerCase().contains(query)) ||
                  (c.mutationFamily?.toLowerCase().contains(query) ?? false);
            })
            .toList()
          ..sort((a, b) {
            final fam = (a.mutationFamily ?? '').compareTo(
              b.mutationFamily ?? '',
            );
            if (fam != 0) return fam;
            final elem = (a.types.firstOrNull ?? '').compareTo(
              b.types.firstOrNull ?? '',
            );
            if (elem != 0) return elem;
            return a.name.compareTo(b.name);
          });
    return list;
  }

  CosmicPartyMember _sandboxMemberFromCreature(Creature creature) {
    return CosmicPartyMember(
      instanceId:
          'sandbox_${creature.id}_${DateTime.now().microsecondsSinceEpoch}',
      baseId: creature.id,
      displayName: creature.name,
      imagePath: 'assets/images/${creature.image}',
      element: creature.types.firstOrNull ?? 'Fire',
      family: (creature.mutationFamily ?? 'Kin').toLowerCase(),
      level: 10,
      statSpeed: _sandboxCompanionStatTier.toDouble(),
      statIntelligence: _sandboxCompanionStatTier.toDouble(),
      statStrength: _sandboxCompanionStatTier.toDouble(),
      statBeauty: _sandboxCompanionStatTier.toDouble(),
      slotIndex: -1,
      staminaBars: 99,
      staminaMax: 99,
      spriteSheet: creature.spriteData != null
          ? sheetFromCreature(creature)
          : null,
    );
  }

  void _toggleSandboxPanel() {
    final game = _game;
    if (game == null) return;
    final opening = !_showSandboxPanel;
    if (opening) {
      if (!_sandboxMode) {
        _sandboxMode = true;
        game.setSandboxMode(enabled: true, center: _sandboxAreaCenter);
        _showQuote('Sandbox mode engaged.');
      }
    }
    setState(() => _showSandboxPanel = opening);
  }

  void _leaveSandboxMode() {
    final game = _game;
    if (game == null) return;
    game.setSandboxMode(enabled: false);
    setState(() {
      _showSandboxPanel = false;
      _sandboxMode = false;
    });
    _showQuote('Sandbox mode disabled.');
  }

  void _clearSandboxHostiles() {
    _game?.clearSandboxHostiles();
    HapticFeedback.selectionClick();
    setState(() {});
  }

  void _summonSandboxCompanion(Creature creature) {
    final game = _game;
    if (game == null) return;
    if (game.battleRing.inBattle) {
      _showQuote('Finish the battle ring fight before sandbox summoning.');
      return;
    }
    if (_activeCompanionSlot != null) {
      _saveCompanionHp();
    }
    setState(() => _activeCompanionSlot = null);
    game.summonCompanion(_sandboxMemberFromCreature(creature));
    HapticFeedback.mediumImpact();
    _showQuote(
      '${creature.name} summoned at Lv10 with all stats set to $_sandboxCompanionStatTier.',
    );
  }

  void _spawnSandboxEnemy() {
    final game = _game;
    if (game == null) return;
    game.spawnSandboxEnemy(
      tier: _sandboxEnemyTier,
      behavior: _sandboxEnemyBehavior,
      count: _sandboxEnemyCount,
    );
    HapticFeedback.lightImpact();
    _showQuote(
      '$_sandboxEnemyCount ${_sandboxEnemyBehavior.name.toUpperCase()} ${_sandboxEnemyTier.name.toUpperCase()} ${_sandboxEnemyCount == 1 ? 'enemy' : 'enemies'} spawned.',
    );
    setState(() {});
  }

  void _spawnSandboxDummy() {
    final game = _game;
    if (game == null) return;
    game.spawnSandboxDummy(count: _sandboxEnemyCount);
    HapticFeedback.lightImpact();
    _showQuote(
      '$_sandboxEnemyCount test ${_sandboxEnemyCount == 1 ? 'dummy' : 'dummies'} spawned.',
    );
    setState(() {});
  }

  void _spawnSandboxBoss() {
    final game = _game;
    if (game == null) return;
    game.spawnSandboxBoss(
      template: _sandboxBossTemplate,
      level: _sandboxBossLevel,
    );
    HapticFeedback.heavyImpact();
    _showQuote('${_sandboxBossTemplate.name} spawned at Lv$_sandboxBossLevel.');
    setState(() {});
  }

  /// Persist the active companion's current HP fraction before returning it.
  void _saveCompanionHp() {
    final comp = _game?.activeCompanion;
    if (comp != null && _activeCompanionSlot != null) {
      _companionHpFraction[_activeCompanionSlot!] = comp.hpPercent;
      _companionSpecialCooldown[_activeCompanionSlot!] = comp.specialCooldown
          .clamp(0.0, 100.0);
    }
  }

  void _onCompanionAutoReturned() {
    if (!mounted) return;
    // During a ring battle the companion must stay deployed.
    if (_game?.battleRing.inBattle == true) return;
    _saveCompanionHp();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _activeCompanionSlot = null);
    });
  }

  void _onCompanionDied(CosmicPartyMember member) {
    if (!mounted) return;
    // If in a ring battle the loss callback handles everything – just clean up here.
    if (_game?.battleRing.inBattle == true) {
      // Mark slot dead and clear, but don't drain stamina (ring is consequence-free).
      if (_activeCompanionSlot != null) {
        _companionHpFraction[_activeCompanionSlot!] = 0.0;
        _companionSpecialCooldown[_activeCompanionSlot!] = 0.0;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _activeCompanionSlot = null);
      });
      return;
    }
    // Mark this slot as dead (0 HP)
    if (_activeCompanionSlot != null) {
      _companionHpFraction[_activeCompanionSlot!] = 0.0;
      _companionSpecialCooldown[_activeCompanionSlot!] = 0.0;
    }
    // Drain the dead companion's stamina to 0, except for synthetic sandbox summons.
    if (!member.instanceId.startsWith('sandbox_')) {
      final db = context.read<AlchemonsDatabase>();
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      db.creatureDao.updateStamina(
        instanceId: member.instanceId,
        staminaBars: 0,
        staminaLastUtcMs: nowMs,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _activeCompanionSlot = null);
        _initCosmicParty();
      }
    });
  }

  /// Called when the prismatic field easter-egg reward is claimed.
  Future<void> _onPrismaticRewardClaimed() async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    await db.settingsDao.setCosmicPrismaticRewardClaimed(true);
    await db.currencyDao.addGold(10);
    if (mounted) setState(() {});
  }

  // ── Garrison (home base alchemons) ──

  /// Garrison slots unlocked by active size tier: 1, 3, 4, 7, 9.
  int get _garrisonSlots =>
      homeGarrisonSlotsForTier(_homePlanet?.activeSizeTier ?? 0);

  Future<void> _initGarrison() async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final savedIds = await db.settingsDao.getCosmicGarrisonSlots();
    final slots = _garrisonSlots;

    final members = <CosmicPartyMember?>[];
    final seenInstanceIds = <String>{};
    final duplicateSlotIndexes = <int>[];
    for (var i = 0; i < slots; i++) {
      final id = i < savedIds.length ? savedIds[i] : null;
      if (id != null) {
        if (seenInstanceIds.contains(id)) {
          duplicateSlotIndexes.add(i);
          members.add(null);
          continue;
        }
        final inst = await db.creatureDao.getInstance(id);
        if (inst != null) {
          seenInstanceIds.add(id);
          final base = catalog.getCreatureById(inst.baseId);
          final typeName = (base?.types.isNotEmpty ?? false)
              ? base!.types.first
              : 'Earth';
          final family = base?.mutationFamily ?? 'kin';
          final name = inst.nickname ?? base?.name ?? inst.baseId;
          final sheet = base?.spriteData != null
              ? sheetFromCreature(base!)
              : null;
          final visuals = visualsFromInstance(base, inst);
          members.add(
            CosmicPartyMember(
              instanceId: inst.instanceId,
              baseId: inst.baseId,
              displayName: name,
              imagePath: base?.image != null
                  ? 'assets/images/${base!.image}'
                  : null,
              element: typeName,
              family: family,
              level: inst.level,
              statSpeed: inst.statSpeed.toDouble(),
              statIntelligence: inst.statIntelligence.toDouble(),
              statStrength: inst.statStrength.toDouble(),
              statBeauty: inst.statBeauty.toDouble(),
              slotIndex: i,
              staminaBars: 3,
              staminaMax: inst.staminaMax,
              spriteSheet: sheet,
              spriteVisuals: visuals,
            ),
          );
          continue;
        }
      }
      members.add(null);
    }
    for (final index in duplicateSlotIndexes) {
      await db.settingsDao.setCosmicGarrisonSlotInstance(index, null);
    }
    if (mounted) {
      setState(() => _garrisonMembers = members);
      _spawnGarrisonInGame();
    }
  }

  void _spawnGarrisonInGame() {
    final filled = _garrisonMembers.whereType<CosmicPartyMember>().toList();
    _game?.spawnGarrison(filled);
  }

  Future<void> _handleAssignGarrisonSlot(
    int slotIndex,
    String instanceId,
  ) async {
    if (!mounted) return;
    // Block if already in ship party
    if (_partyMembers.any((m) => m?.instanceId == instanceId)) {
      _showQuote('Already assigned to your ship party!');
      return;
    }
    final alreadyGarrisonedElsewhere = _garrisonMembers.asMap().entries.any(
      (entry) =>
          entry.key != slotIndex && entry.value?.instanceId == instanceId,
    );
    if (alreadyGarrisonedElsewhere) {
      _showQuote('Already stationed in another garrison slot!');
      return;
    }
    final db = context.read<AlchemonsDatabase>();
    await db.settingsDao.setCosmicGarrisonSlotInstance(slotIndex, null);
    await db.settingsDao.setCosmicGarrisonSlotInstance(slotIndex, instanceId);
    await _initGarrison();
  }

  Future<void> _handleClearGarrisonSlot(int slotIndex) async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    await db.settingsDao.setCosmicGarrisonSlotInstance(slotIndex, null);
    await _initGarrison();
  }

  void _periodicSave() {
    final now = DateTime.now();
    if (now.difference(_lastSave) > _saveInterval) {
      _lastSave = now;
      _saveFogState();
      _saveFuelState();
      _saveOrbitalState();
      _saveMissileState();
      _saveNexusState();
      _saveBattleRingState();
      _saveBloodRingState();
    }
    _checkQuoteMilestones();
    // Gradual healing while near home planet
    _tickGradualHeal(0.5); // approximate dt for periodic callback
  }

  void _checkQuoteMilestones() {
    if (_game == null || _activeQuote != null) return;
    final pct = _game!.discoveryPct;
    for (final entry in _quoteThresholds) {
      final threshold = entry[0] as double;
      final quote = entry[1] as String;
      if (pct >= threshold && !_triggeredQuotes.contains(threshold)) {
        _triggeredQuotes.add(threshold);
        _saveTriggeredQuotes();
        _showQuote(quote);
        return;
      }
    }
  }

  void _showQuote(String quote) {
    void doShow() {
      if (!mounted) return;
      setState(() => _activeQuote = quote);
      _quoteFade.forward(from: 0).then((_) {
        // Hold for 2 seconds, then fade out
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          _quoteFade.reverse().then((_) {
            if (mounted) setState(() => _activeQuote = null);
          });
        });
      });
    }

    // Guard against being called during a build phase
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => doShow());
    } else {
      doShow();
    }
  }

  void _playCosmicSfx(SoundCue cue) {
    if (!mounted) return;
    unawaited(context.read<AudioController>().playSound(cue));
  }

  /// Display a brief pickup message for an item loot drop.
  void _showItemPickupMessage(String itemKey) {
    final name = switch (itemKey) {
      InvKeys.harvesterStdVolcanic => 'Volcanic Harvester',
      InvKeys.harvesterStdOceanic => 'Oceanic Harvester',
      InvKeys.harvesterStdVerdant => 'Verdant Harvester',
      InvKeys.harvesterStdEarthen => 'Earthen Harvester',
      InvKeys.harvesterStdArcane => 'Arcane Harvester',
      InvKeys.harvesterGuaranteed => 'Stabilized Harvester',
      InvKeys.portalKeyVolcanic => 'Volcanic Portal Key',
      InvKeys.portalKeyOceanic => 'Oceanic Portal Key',
      InvKeys.portalKeyVerdant => 'Verdant Portal Key',
      InvKeys.portalKeyEarthen => 'Earthen Portal Key',
      InvKeys.portalKeyArcane => 'Arcane Portal Key',
      _ => 'Unknown Item',
    };
    _showQuote('+1 $name');
  }

  Future<void> _saveTriggeredQuotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _quotesPrefsKey,
      _triggeredQuotes.map((d) => d.toString()).join(','),
    );
  }

  void _onMeterChanged() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {});
        if (_game != null && _game!.meter.isFull) {
          _meterPulse.repeat(reverse: true);
          HapticFeedback.heavyImpact();
        }
      });
    }
  }

  Future<void> _saveFogState() async {
    if (_game == null) return;
    final prefs = await SharedPreferences.getInstance();
    final state = _game!.getFogState(_worldSeed);
    await prefs.setString(_prefsKey, state.serialise());
  }

  void _onNearPlanet(CosmicPlanet? planet) {
    if (mounted && planet != _nearPlanet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _nearPlanet = planet);
          // animate planet-meter in/out
          if (planet != null) {
            _planetMeterCtrl.forward(from: 0.0);
            unawaited(_maybeShowPlanetRecipeArrivalIntro(planet));
          } else {
            _planetMeterCtrl.reverse();
          }
        }
      });
    }
  }

  Future<void> _maybeShowPlanetRecipeArrivalIntro(CosmicPlanet planet) async {
    if (_showingPlanetRecipeArrivalIntro || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final introSeen = prefs.getBool(_planetRecipeArrivalIntroSeenKey) ?? false;
    if (introSeen || !mounted || _nearPlanet != planet) return;

    _showingPlanetRecipeArrivalIntro = true;
    try {
      await LandscapeDialog.show(
        context,
        title: 'The Planet Whispers a Pattern',
        message:
            'Something in this sphere remembers an older design. An alchemical recipe lies veiled here. Gather the essences it asks for, and when the pattern is whole, let the summon answer.',
        typewriter: true,
        kind: LandscapeDialogKind.info,
        showIcon: false,
        primaryLabel: 'Heed the Sign',
      );
      await prefs.setBool(_planetRecipeArrivalIntroSeenKey, true);
    } finally {
      _showingPlanetRecipeArrivalIntro = false;
    }
  }

  void _onStarDustCollected(int index) {
    _collectedDust.add(index);
    _saveStarDust();
    final scannerCompleted = _game?.consumeCompletedScannerDustIndex();
    if (mounted) {
      HapticFeedback.lightImpact();
      _playCosmicSfx(SoundCue.cosmicOrbPickup);
      final totalDust = _game?.starDusts.length ?? 50;
      const perDustSpeedBonusPct = 2;
      final totalSpeedBonusPct = ((_collectedDust.length / totalDust) * 100)
          .round();
      final progressText =
          '${_collectedDust.length}/$totalDust STAR DUST COLLECTED • SHIP SPEED +$perDustSpeedBonusPct% (TOTAL +$totalSpeedBonusPct%)';
      if (scannerCompleted != null && scannerCompleted == index) {
        _showQuote('$progressText • Scanner signal cleared.');
      } else {
        _showQuote(progressText);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _saveStarDust() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _dustPrefsKey,
      StarDust.serialiseCollected(_collectedDust),
    );
  }

  void _onNearRift(bool isNear) {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isNearRift != isNear) {
          setState(() => _isNearRift = isNear);
        }
      });
    }
  }

  void _handleRiftTap() async {
    if (_game == null || !_game!.isNearRift) return;
    final rift = _game!.nearestRift;
    if (rift == null) return;
    HapticFeedback.heavyImpact();

    // Map the rift's faction string to the enum
    final faction = RiftFaction.values.firstWhere(
      (f) => f.name == rift.faction,
      orElse: () => RiftFaction.arcane,
    );

    // Require a portal key for this faction
    final db = context.read<AlchemonsDatabase>();
    final keyInvKey = InvKeys.portalKeyForFaction(faction.name);
    final keyQty = await db.inventoryDao.getItemQty(keyInvKey);
    if (keyQty <= 0) {
      _showQuote(
        'You need a ${faction.displayName} Portal Key to enter this rift!',
      );
      HapticFeedback.lightImpact();
      return;
    }

    // Consume one portal key
    await db.inventoryDao.consumeItem(keyInvKey);

    if (!mounted) return;
    _playCosmicSfx(SoundCue.cosmicPortalOpen);
    unawaited(context.read<AudioController>().playPortalMusic());
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RiftPortalScreen(faction: faction, party: const []),
      ),
    );
    if (mounted) {
      unawaited(
        context.read<AudioController>().playCosmicExplorationMusic(
          cycle: false,
        ),
      );
    }

    if (success == true && mounted) {
      _game?.relocateRift(rift);
      setState(() => _isNearRift = false);
    }
  }

  // ── Elemental Nexus handlers ──

  void _onNearNexus(bool isNear) {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isNearNexus != isNear) {
          setState(() => _isNearNexus = isNear);
        }
      });
    }
  }

  void _onNearPocketPortal(String? element) {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _nearPocketPortalElement != element) {
          setState(() => _nearPocketPortalElement = element);
        }
      });
    }
  }

  void _handleNexusTap() async {
    if (_game == null || !_game!.isNearNexus) return;
    HapticFeedback.heavyImpact();

    // Check boss keys: all 4 elemental boss keys required
    final db = context.read<AlchemonsDatabase>();
    final fireBossKey = await db.inventoryDao.getItemQty(
      BossLootKeys.traitKeyForElement('fire'),
    );
    final waterBossKey = await db.inventoryDao.getItemQty(
      BossLootKeys.traitKeyForElement('water'),
    );
    final earthBossKey = await db.inventoryDao.getItemQty(
      BossLootKeys.traitKeyForElement('earth'),
    );
    final airBossKey = await db.inventoryDao.getItemQty(
      BossLootKeys.traitKeyForElement('air'),
    );
    if (fireBossKey <= 0 ||
        waterBossKey <= 0 ||
        earthBossKey <= 0 ||
        airBossKey <= 0) {
      final missing = <String>[];
      if (fireBossKey <= 0) missing.add('Flame Feather');
      if (waterBossKey <= 0) missing.add('Leviathan Scale');
      if (earthBossKey <= 0) missing.add('Terra Core');
      if (airBossKey <= 0) missing.add('Gale Plume');
      _showQuote('Missing boss keys: ${missing.join(", ")}');
      HapticFeedback.lightImpact();
      return;
    }

    // Meter requirement: must be full and contain ≥ 20% of each element
    final meter = _game!.meter;
    if (!meter.isFull) {
      _showQuote('Alchemeal meter must be full to enter the Nexus.');
      HapticFeedback.lightImpact();
      return;
    }
    final nexus0 = _game!.elementalNexus;
    if (!nexus0.meetsRequirement(meter.breakdown, meter.total)) {
      _showQuote('Meter must contain ≥ 20% Fire, Water, Earth & Air.');
      HapticFeedback.lightImpact();
      return;
    }
    meter.reset();
    _game!.onMeterChanged();

    // Enter the pocket dimension
    _game!.enterNexusPocket();
    _playCosmicSfx(SoundCue.cosmicPortalOpen);
    _saveNexusState();

    // Award harvester
    final nexus = _game!.elementalNexus;
    if (!nexus.harvesterAwarded) {
      nexus.harvesterAwarded = true;
      await db.inventoryDao.addItemQty(InvKeys.harvesterGuaranteed, 1);
      _showQuote('Guarantee Harvester collected!');
      _saveNexusState();
    }

    setState(() {
      _isNearNexus = false;
    });
  }

  void _handlePocketPortalTap() {
    if (_game == null || _nearPocketPortalElement == null) return;
    final element = _nearPocketPortalElement!;
    HapticFeedback.heavyImpact();

    // Mark encounter phase and persist
    final nexus = _game!.elementalNexus;
    nexus.chosenElement = element;
    nexus.phase = NexusPhase.inEncounter;
    _saveNexusState();

    _openNexusEncounter(element);
  }

  void _openNexusEncounter(String element) async {
    final nexus = _game!.elementalNexus;
    _playCosmicSfx(SoundCue.cosmicPortalOpen);
    unawaited(context.read<AudioController>().playPortalMusic());
    final result = await Navigator.of(context).push<NexusResult>(
      MaterialPageRoute(
        builder: (_) => ElementalNexusScreen(
          resumePhase: NexusPhase.inEncounter,
          resumeElement: element,
          harvesterAlreadyAwarded: true, // already awarded on pocket entry
        ),
      ),
    );

    if (!mounted || _game == null) return;
    unawaited(
      context.read<AudioController>().playCosmicExplorationMusic(cycle: false),
    );

    if (result != null && result.caught) {
      // Encounter completed — exit pocket, return to normal world
      _game!.exitNexusPocket();
    } else {
      // Fled — stay in pocket so they can try another portal
      nexus.phase = NexusPhase.choosingPortal;
      nexus.chosenElement = null;
    }
    _saveNexusState();
    setState(() {});
  }

  Future<void> _saveNexusState() async {
    if (_game == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nexusPrefsKey, _game!.elementalNexus.serialise());
  }

  // ── Battle Ring handlers ──

  void _onNearBattleRing(bool isNear) {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isNearBattleRing != isNear) {
          setState(() => _isNearBattleRing = isNear);
        }
      });
    }
  }

  Future<void> _saveBattleRingState() async {
    if (_game == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_battleRingPrefsKey, _game!.battleRing.serialise());
  }

  void _onNearBloodRing(bool isNear) {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isNearBloodRing != isNear) {
          setState(() => _isNearBloodRing = isNear);
        }
      });
    }
  }

  Future<void> _saveBloodRingState() async {
    if (_game == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bloodRingPrefsKey, _game!.bloodRing.serialise());
  }

  // ── Trait Contest handlers ──

  void _onNearContestArena(CosmicContestArena? arena) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_nearContestArena != arena) {
        setState(() => _nearContestArena = arena);
      }
    });
  }

  Future<void> _saveContestProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _contestProgressPrefsKey,
      _contestProgress.serialise(),
    );
  }

  Future<void> _saveContestHints() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _contestHintsPrefsKey,
      serialiseContestHintIds(_knownContestHintIds),
    );
  }

  Future<void> _saveBeautyContestRotation() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, int>{
      for (final e in _beautyContestRotationByLevel.entries)
        '${e.key}': e.value,
    };
    await prefs.setString(_beautyContestRotationPrefsKey, jsonEncode(encoded));
  }

  CosmicContestOpponent _beautyOpponentForLevel(int level) {
    final pool = beautyContestOpponentsForLevel(level);
    if (pool.isEmpty) {
      final fallbackLevels = kCosmicContestLevels[CosmicContestTrait.beauty]!;
      return fallbackLevels[(level - 1).clamp(0, fallbackLevels.length - 1)]
          .opponent;
    }
    final idx = _beautyContestRotationByLevel[level] ?? 0;
    return pool[idx % pool.length];
  }

  void _rotateBeautyOpponentAfterLoss(int level) {
    final pool = beautyContestOpponentsForLevel(level);
    if (pool.length <= 1) return;
    final current = _beautyContestRotationByLevel[level] ?? 0;
    _beautyContestRotationByLevel[level] = (current + 1) % pool.length;
    _saveBeautyContestRotation();
  }

  String _contestOpponentDisplay(CosmicContestOpponent opponent) {
    if (opponent.visualTheme == CosmicContestVisualTheme.standard) {
      return opponent.name;
    }
    return '${opponent.name} (${opponent.visualTheme.label})';
  }

  Future<void> _syncContestMasteryShopUnlocks() async {
    final shop = context.read<ShopService>();
    for (final trait in CosmicContestTrait.values) {
      if (!_contestProgress.isMastered(trait)) continue;
      final offerId = _contestMasteryEffectOfferByTrait[trait];
      if (offerId == null) continue;
      await shop.unlockContestEffectOffer(offerId, freeQty: 1);
    }
  }

  Future<String?> _unlockContestMasteryEffect(CosmicContestTrait trait) async {
    final offerId = _contestMasteryEffectOfferByTrait[trait];
    if (offerId == null) return null;
    final shop = context.read<ShopService>();
    return shop.unlockContestEffectOffer(offerId, freeQty: 1);
  }

  void _onContestHintCollected(CosmicContestHintNote note) {
    if (_knownContestHintIds.contains(note.id)) return;
    _knownContestHintIds.add(note.id);
    _saveContestHints();
    _showQuote(note.text);
    HapticFeedback.selectionClick();
    if (mounted && _showPinnedMiniMap) {
      setState(() {});
    }
  }

  static const Map<CosmicContestTrait, Map<String, double>>
  _contestElementWeights = {
    CosmicContestTrait.beauty: {
      'Crystal': 0.32,
      'Light': 0.26,
      'Spirit': 0.18,
      'Ice': 0.17,
      'Fire': 0.15,
      'Steam': 0.10,
      'Air': 0.12,
      'Plant': 0.08,
      'Poison': -0.30,
      'Blood': -0.24,
      'Mud': -0.14,
    },
    CosmicContestTrait.speed: {
      'Lightning': 0.34,
      'Water': 0.26,
      'Ice': 0.23,
      'Air': 0.18,
      'Steam': 0.14,
      'Earth': -0.16,
      'Mud': -0.28,
      'Lava': -0.13,
    },
    CosmicContestTrait.strength: {
      'Earth': 0.34,
      'Lava': 0.29,
      'Fire': 0.23,
      'Mud': 0.16,
      'Crystal': 0.12,
      'Blood': 0.10,
      'Air': -0.19,
      'Water': -0.11,
    },
    CosmicContestTrait.intelligence: {
      'Spirit': 0.30,
      'Light': 0.25,
      'Dark': 0.22,
      'Crystal': 0.19,
      'Air': 0.11,
      'Water': 0.08,
      'Lava': -0.16,
      'Mud': -0.13,
      'Blood': -0.09,
    },
  };

  static const Map<CosmicContestTrait, Map<String, double>>
  _contestFamilyWeights = {
    CosmicContestTrait.beauty: {'wing': 0.07, 'mask': 0.12, 'kin': 0.05},
    CosmicContestTrait.speed: {'wing': 0.18, 'let': 0.07, 'kin': 0.06},
    CosmicContestTrait.strength: {'horn': 0.16, 'mane': 0.14, 'kin': 0.06},
    CosmicContestTrait.intelligence: {'mask': 0.14, 'kin': 0.12, 'pip': 0.06},
  };

  static const Map<CosmicContestTrait, double> _contestTraitBonusCaps = {
    CosmicContestTrait.beauty: 0.70,
    CosmicContestTrait.speed: 0.62,
    CosmicContestTrait.strength: 0.70,
    CosmicContestTrait.intelligence: 0.68,
  };

  double _contestBaseStat(CosmicContestTrait trait, CosmicPartyMember member) {
    return switch (trait) {
      CosmicContestTrait.beauty => member.statBeauty,
      CosmicContestTrait.speed => member.statSpeed,
      CosmicContestTrait.strength => member.statStrength,
      CosmicContestTrait.intelligence => member.statIntelligence,
    };
  }

  double _contestElementBonus(CosmicContestTrait trait, String element) {
    return _contestElementWeights[trait]?[element] ?? 0.0;
  }

  double _contestFamilyBonus(CosmicContestTrait trait, String family) {
    return _contestFamilyWeights[trait]?[family.toLowerCase().trim()] ?? 0.0;
  }

  int _lineageDiversityCount(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 0;
    try {
      final dec = jsonDecode(raw);
      if (dec is! Map<String, dynamic>) return 0;
      return dec.entries
          .where((e) => e.key.trim().isNotEmpty)
          .where((e) => (e.value is num ? (e.value as num).toDouble() : 0) > 0)
          .length;
    } catch (_) {
      return 0;
    }
  }

  Map<String, int> _decodeLineageCounts(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const {};
    try {
      final dec = jsonDecode(raw);
      if (dec is! Map<String, dynamic>) return const {};
      final out = <String, int>{};
      dec.forEach((k, v) {
        var key = k.toString().trim();
        if (key.startsWith('CreatureFamily.')) {
          key = key.split('.').last;
        }
        final n = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
        if (key.isNotEmpty && n > 0) out[key] = n;
      });
      return out;
    } catch (_) {
      return const {};
    }
  }

  String? _singleLineageKey(String? raw) {
    final parsed = _decodeLineageCounts(raw);
    if (parsed.length != 1) return null;
    return parsed.keys.first;
  }

  bool _isSpeciesPureFromParentage(String? parentageJson, String baseId) {
    if (parentageJson == null || parentageJson.trim().isEmpty) return true;
    try {
      final dec = jsonDecode(parentageJson);
      if (dec is! Map<String, dynamic>) return false;
      String? readBaseId(dynamic node) {
        if (node is! Map) return null;
        final raw = node['baseId'];
        if (raw is! String || raw.trim().isEmpty) return null;
        return raw.trim();
      }

      final a = readBaseId(dec['parentA']);
      final b = readBaseId(dec['parentB']);
      final ids = <String>[if (a != null) a, if (b != null) b];
      if (ids.isEmpty) return false;
      return ids.every((id) => id == baseId);
    } catch (_) {
      return false;
    }
  }

  double _natureContestBonus(CosmicContestTrait trait, String? natureId) {
    if (natureId == null || natureId.trim().isEmpty) return 0.0;
    final id = natureId.trim();
    final lowered = id.toLowerCase();
    final nature = NatureCatalog.byId(id);
    final effect = nature?.effect;
    double effectVal(String key, {double fallback = 0.0}) {
      final value = effect?[key];
      return value is num ? value.toDouble() : fallback;
    }

    var bonus = 0.0;
    if (trait == CosmicContestTrait.speed) {
      bonus += effectVal('stat_speed_bonus') * 0.42;
      if (lowered == 'swift' || lowered == 'hyperbolic') bonus += 0.18;
    }
    if (trait == CosmicContestTrait.intelligence) {
      bonus += effectVal('stat_intelligence_bonus') * 0.42;
      final xpMult = effectVal('xp_gain_mult', fallback: 1.0);
      if (xpMult > 1.0) bonus += (xpMult - 1.0) * 0.95;
      if (lowered == 'clever' || lowered == 'neuroadaptive') bonus += 0.16;
    }
    if (trait == CosmicContestTrait.strength) {
      bonus += effectVal('stat_strength_bonus') * 0.42;
      if (lowered == 'mighty') bonus += 0.16;
    }
    if (trait == CosmicContestTrait.beauty) {
      bonus += effectVal('stat_beauty_bonus') * 0.42;
      if (lowered == 'elegant') bonus += 0.16;
    }

    final sameSpeciesMult = effectVal(
      'breed_same_species_chance_mult',
      fallback: 1.0,
    );
    if (sameSpeciesMult > 1.0 &&
        (trait == CosmicContestTrait.beauty ||
            trait == CosmicContestTrait.intelligence)) {
      bonus += (sameSpeciesMult - 1.0) * 0.14;
    }

    final sameTypeMult = effectVal(
      'breed_same_type_chance_mult',
      fallback: 1.0,
    );
    if (sameTypeMult > 1.0 &&
        (trait == CosmicContestTrait.speed ||
            trait == CosmicContestTrait.strength)) {
      bonus += (sameTypeMult - 1.0) * 0.10;
    }
    return bonus;
  }

  Future<double> _computePlayerContestScore(
    CosmicContestTrait trait,
    CosmicPartyMember member,
  ) async {
    final baseStat = _contestBaseStat(trait, member);
    double traitBonus = _contestElementBonus(trait, member.element);
    traitBonus += _contestFamilyBonus(trait, member.family);

    final visuals = member.spriteVisuals;
    final db = context.read<AlchemonsDatabase>();
    final inst = await db.creatureDao.getInstance(member.instanceId);

    if (trait == CosmicContestTrait.beauty) {
      if (visuals?.isPrismatic == true) traitBonus += 0.24;
      final fx = visuals?.alchemyEffect;
      if (fx == 'prismatic_cascade') traitBonus += 0.18;
      if (fx == 'alchemy_glow' || fx == 'elemental_aura') traitBonus += 0.09;
      if (fx == 'beauty_radiance') traitBonus += 0.15;
      if ((member.visualVariant ?? '').trim().isNotEmpty) traitBonus += 0.12;
      if (visuals?.tint != null) traitBonus += 0.05;
      final variantKey = (inst?.variantFaction ?? '').trim().toLowerCase();
      if (variantKey.isNotEmpty && variantKey != 'bloodborn') {
        traitBonus += 0.06;
      }
    }
    if (trait == CosmicContestTrait.speed) {
      final scale = visuals?.scale ?? 1.0;
      final compactness = (1.0 - scale).clamp(0.0, 0.35).toDouble();
      traitBonus += compactness * 0.55;
      if (visuals?.alchemyEffect == 'speed_flux') traitBonus += 0.15;
    }
    if (trait == CosmicContestTrait.strength) {
      final scale = visuals?.scale ?? 1.0;
      final bulk = (scale - 1.0).clamp(0.0, 0.55).toDouble();
      traitBonus += bulk * 0.70;
      if (visuals?.alchemyEffect == 'strength_forge') traitBonus += 0.15;
    }
    if (trait == CosmicContestTrait.intelligence) {
      if (visuals?.alchemyEffect == 'intelligence_halo') traitBonus += 0.15;
    }

    if (inst != null) {
      if (trait == CosmicContestTrait.intelligence && mounted) {
        final elemKinds = _lineageDiversityCount(
          inst.elementLineageJson,
        ).clamp(0, 6);
        final factionKinds = _lineageDiversityCount(
          inst.factionLineageJson,
        ).clamp(0, 6);
        final familyKinds = _lineageDiversityCount(
          inst.familyLineageJson,
        ).clamp(0, 6);
        final genDepth = inst.generationDepth.clamp(0, 12);
        traitBonus += elemKinds * 0.024;
        traitBonus += factionKinds * 0.026;
        traitBonus += familyKinds * 0.020;
        traitBonus += genDepth * 0.011;
      }

      traitBonus += _natureContestBonus(trait, inst.natureId);

      final pureElement = _singleLineageKey(inst.elementLineageJson);
      final pureFamily = _singleLineageKey(
        inst.familyLineageJson,
      )?.toLowerCase().trim();
      final speciesPure = _isSpeciesPureFromParentage(
        inst.parentageJson,
        member.baseId,
      );

      if (pureElement != null) {
        final normalizedElement = pureElement.isEmpty
            ? pureElement
            : pureElement[0].toUpperCase() +
                  pureElement.substring(1).toLowerCase();
        if (trait == CosmicContestTrait.beauty) {
          traitBonus += 0.08;
        }
        final aligned = _contestElementBonus(trait, normalizedElement);
        if (aligned > 0) {
          traitBonus += 0.04 + aligned * 0.28;
        }
      }

      if (pureFamily != null && pureFamily.isNotEmpty) {
        if (trait == CosmicContestTrait.beauty) {
          traitBonus += 0.06;
        }
        final aligned = _contestFamilyBonus(trait, pureFamily);
        if (aligned > 0) {
          traitBonus += 0.03 + aligned * 0.26;
        }
      }

      if (speciesPure) {
        traitBonus += trait == CosmicContestTrait.beauty ? 0.08 : 0.03;
      }
    }

    traitBonus = traitBonus
        .clamp(-0.70, _contestTraitBonusCaps[trait]!)
        .toDouble();
    final variance = (Random().nextDouble() * 0.18) - 0.09;
    final score = baseStat + traitBonus + variance;
    return score.clamp(0.0, 5.65).toDouble();
  }

  double _computeOpponentContestScore(
    CosmicContestTrait trait,
    CosmicContestOpponent opponent,
  ) {
    double traitBonus = _contestElementBonus(trait, opponent.element) * 0.45;
    traitBonus += _contestFamilyBonus(trait, opponent.family) * 0.35;
    traitBonus = traitBonus.clamp(-0.35, 0.45).toDouble();
    final variance = (Random().nextDouble() * 0.16) - 0.08;
    final score = opponent.targetScore + traitBonus + variance;
    return score.clamp(0.0, 5.60).toDouble();
  }

  SpriteVisuals _applyContestThemeVisuals(
    SpriteVisuals base,
    CosmicContestVisualTheme theme,
  ) {
    return switch (theme) {
      CosmicContestVisualTheme.standard => base,
      CosmicContestVisualTheme.radiant => SpriteVisuals(
        scale: base.scale,
        saturation: base.saturation,
        brightness: base.brightness,
        hueShiftDeg: base.hueShiftDeg,
        isPrismatic: base.isPrismatic,
        tint: base.tint ?? const Color(0xFFFFF59D).withValues(alpha: 0.22),
        isAlbino: base.isAlbino,
        alchemyEffect: base.alchemyEffect ?? 'alchemy_glow',
        variantFaction: base.variantFaction,
        prismaticHueDeg: base.prismaticHueDeg,
      ),
      CosmicContestVisualTheme.thermal => SpriteVisuals(
        scale: base.scale,
        saturation: base.saturation,
        brightness: base.brightness,
        hueShiftDeg: base.hueShiftDeg,
        isPrismatic: base.isPrismatic,
        tint: base.tint ?? const Color(0xFFFF8A65).withValues(alpha: 0.30),
        isAlbino: base.isAlbino,
        alchemyEffect: 'elemental_aura',
        variantFaction: base.variantFaction ?? 'Pyro',
        prismaticHueDeg: base.prismaticHueDeg,
      ),
      CosmicContestVisualTheme.cryogenic => SpriteVisuals(
        scale: base.scale,
        saturation: base.saturation,
        brightness: base.brightness,
        hueShiftDeg: base.hueShiftDeg,
        isPrismatic: base.isPrismatic,
        tint: base.tint ?? const Color(0xFF81D4FA).withValues(alpha: 0.28),
        isAlbino: base.isAlbino,
        alchemyEffect: 'alchemy_glow',
        variantFaction: base.variantFaction ?? 'Aqua',
        prismaticHueDeg: base.prismaticHueDeg,
      ),
      CosmicContestVisualTheme.prismatic => SpriteVisuals(
        scale: base.scale,
        saturation: base.saturation,
        brightness: base.brightness,
        hueShiftDeg: base.hueShiftDeg,
        isPrismatic: true,
        tint: base.tint,
        isAlbino: false,
        alchemyEffect: 'prismatic_cascade',
        variantFaction: base.variantFaction,
        prismaticHueDeg: base.prismaticHueDeg,
      ),
    };
  }

  Future<bool> _canLoadSpriteSheet(SpriteSheetDef? sheet) async {
    if (sheet == null) return false;
    try {
      await rootBundle.load(sheet.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<CosmicPartyMember?> _buildBeautyContestOpponentMember(
    CosmicContestOpponent opponent,
    int level,
  ) async {
    final targetElement = opponent.element.toLowerCase().trim();
    final targetFamily = opponent.family.toLowerCase().trim();
    final rng = Random(
      _worldSeed ^ level ^ opponent.name.hashCode ^ DateTime.now().millisecond,
    );
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    if (!catalog.isLoaded || catalog.creatures.isEmpty) return null;
    final ownedInstances = await db.creatureDao.getAllInstances();
    if (!mounted) return null;
    if (ownedInstances.isEmpty) return null;

    final ownedCandidates = <(CreatureInstance, dynamic)>[];
    for (final inst in ownedInstances) {
      final base = catalog.getCreatureById(inst.baseId);
      if (base == null) continue;
      ownedCandidates.add((inst, base));
    }
    if (ownedCandidates.isEmpty) return null;
    final spriteReadyCandidates = ownedCandidates
        .where((entry) => entry.$2.spriteData != null)
        .toList();
    final candidateSource = spriteReadyCandidates.isNotEmpty
        ? spriteReadyCandidates
        : ownedCandidates;

    final exactMatches = candidateSource.where((entry) {
      final base = entry.$2;
      final elem = base.types.isNotEmpty
          ? base.types.first.toLowerCase().trim()
          : '';
      final fam = (base.mutationFamily ?? '').toLowerCase().trim();
      return elem == targetElement && fam == targetFamily;
    }).toList();
    final elementMatches = candidateSource.where((entry) {
      final base = entry.$2;
      final elem = base.types.isNotEmpty
          ? base.types.first.toLowerCase().trim()
          : '';
      return elem == targetElement;
    }).toList();
    final pool = exactMatches.isNotEmpty
        ? exactMatches
        : (elementMatches.isNotEmpty ? elementMatches : candidateSource);
    final shuffledPool = [...pool]..shuffle(rng);
    (CreatureInstance, dynamic)? picked;
    for (final candidate in shuffledPool) {
      final base = candidate.$2;
      final candidateSheet = base.spriteData != null
          ? sheetFromCreature(base)
          : null;
      if (await _canLoadSpriteSheet(candidateSheet)) {
        picked = candidate;
        break;
      }
    }
    picked ??= shuffledPool.first;
    final inst = picked.$1;
    final base = picked.$2;
    final typeName = (base.types.isNotEmpty)
        ? base.types.first
        : opponent.element;
    final family = base.mutationFamily ?? opponent.family;
    final sheet = base.spriteData != null ? sheetFromCreature(base) : null;
    // Use base visuals for contest opponents to keep rendering stable
    // (matches battle ring's opponent visual pipeline).
    var visuals = visualsFromInstance(base, null);
    final hasCustomLook =
        visuals.isPrismatic ||
        visuals.tint != null ||
        (visuals.alchemyEffect != null && visuals.alchemyEffect!.isNotEmpty);
    if (!hasCustomLook) {
      visuals = _applyContestThemeVisuals(visuals, opponent.visualTheme);
    }

    final beauty =
        ((inst.statBeauty.toDouble() * 0.72) +
                (opponent.targetScore * 0.28) +
                (rng.nextDouble() * 0.16 - 0.08))
            .clamp(1.0, 5.0)
            .toDouble();
    double blendSecondary(double source) =>
        ((source * 0.72) +
                (opponent.targetScore * 0.22) +
                (rng.nextDouble() * 0.20 - 0.10))
            .clamp(1.0, 5.0)
            .toDouble();

    return CosmicPartyMember(
      instanceId:
          'beauty_contest_${inst.instanceId}_${DateTime.now().millisecondsSinceEpoch}',
      baseId: inst.baseId,
      displayName: inst.nickname ?? base.name,
      imagePath: base.image != null ? 'assets/images/${base.image}' : null,
      element: typeName,
      family: family,
      level: (level + 4).clamp(5, 10),
      statSpeed: blendSecondary(inst.statSpeed.toDouble()),
      statIntelligence: blendSecondary(inst.statIntelligence.toDouble()),
      statStrength: blendSecondary(inst.statStrength.toDouble()),
      statBeauty: beauty,
      slotIndex: -1,
      staminaBars: 999,
      staminaMax: 999,
      spriteSheet: sheet,
      spriteVisuals: visuals,
      visualVariant: null,
      spawnPosition: null,
    );
  }

  Future<CosmicPartyMember?> _playBeautyContestPresentation({
    required CosmicPartyMember player,
    required CosmicContestOpponent opponent,
    required int level,
    required double playerScore,
    required double opponentScore,
  }) async {
    final game = _game;
    if (game == null || !mounted) return null;
    final opponentMember = await _buildBeautyContestOpponentMember(
      opponent,
      level,
    );
    if (!mounted) return null;
    if (opponentMember == null) {
      _showQuote('No owned creatures available for beauty contest opponents.');
      return null;
    }
    final arenaCenter = _nearContestArena?.position ?? game.ship.pos;
    game.beginBeautyContestCinematic(
      opponentMember: opponentMember,
      arenaCenter: arenaCenter,
      playerWon: playerScore >= opponentScore,
    );
    final introDelay = Duration(
      milliseconds: (game.beautyContestIntroDuration * 1000).round(),
    );

    try {
      if (introDelay > Duration.zero) {
        await Future<void>.delayed(introDelay);
        if (!mounted) {
          game.endBeautyContestCinematic();
          return opponentMember;
        }
      }
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Beauty Contest',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, _, __) => CosmicBeautyContestArenaOverlay(
          player: player,
          opponentMember: opponentMember,
          playerScore: playerScore,
          opponentScore: opponentScore,
        ),
        transitionBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        game.endBeautyContestCinematic();
      }
    }
    return opponentMember;
  }

  Future<String?> _playSpeedContestPresentation({
    required CosmicPartyMember player,
    required CosmicContestOpponent opponent,
    required int level,
    required double playerScore,
    required double opponentScore,
  }) async {
    final game = _game;
    if (game == null || !mounted) return null;
    final opponentMember = await _buildBeautyContestOpponentMember(
      opponent,
      level,
    );
    if (!mounted) return null;
    if (opponentMember == null) {
      _showQuote('No owned creatures available for speed contest opponents.');
      return null;
    }
    final arenaCenter = _nearContestArena?.position ?? game.ship.pos;
    game.beginSpeedContestCinematic(
      opponentMember: opponentMember,
      arenaCenter: arenaCenter,
      playerWon: playerScore >= opponentScore,
      playerScore: playerScore,
      opponentScore: opponentScore,
    );
    final introDelay = Duration(
      milliseconds: (game.speedContestIntroDuration * 1000).round(),
    );

    try {
      if (introDelay > Duration.zero) {
        await Future<void>.delayed(introDelay);
        if (!mounted) {
          game.endBeautyContestCinematic();
          return opponentMember.displayName;
        }
      }
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Speed Contest',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, _, __) => CosmicSpeedContestArenaOverlay(
          player: player,
          opponentMember: opponentMember,
          playerScore: playerScore,
          opponentScore: opponentScore,
        ),
        transitionBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        game.endBeautyContestCinematic();
      }
    }
    return opponentMember.displayName;
  }

  Future<String?> _playStrengthContestPresentation({
    required CosmicPartyMember player,
    required CosmicContestOpponent opponent,
    required int level,
    required double playerScore,
    required double opponentScore,
  }) async {
    final game = _game;
    if (game == null || !mounted) return null;
    final opponentMember = await _buildBeautyContestOpponentMember(
      opponent,
      level,
    );
    if (!mounted) return null;
    if (opponentMember == null) {
      _showQuote(
        'No owned creatures available for strength contest opponents.',
      );
      return null;
    }
    final arenaCenter = _nearContestArena?.position ?? game.ship.pos;
    game.beginStrengthContestCinematic(
      opponentMember: opponentMember,
      arenaCenter: arenaCenter,
      playerWon: playerScore >= opponentScore,
      playerScore: playerScore,
      opponentScore: opponentScore,
    );
    final introDelay = Duration(
      milliseconds: (game.strengthContestIntroDuration * 1000).round(),
    );

    try {
      if (introDelay > Duration.zero) {
        await Future<void>.delayed(introDelay);
        if (!mounted) {
          game.endBeautyContestCinematic();
          return opponentMember.displayName;
        }
      }
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Strength Contest',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, _, __) => CosmicStrengthContestArenaOverlay(
          player: player,
          opponentMember: opponentMember,
          playerScore: playerScore,
          opponentScore: opponentScore,
        ),
        transitionBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        game.endBeautyContestCinematic();
      }
    }
    return opponentMember.displayName;
  }

  Future<String?> _playIntelligenceContestPresentation({
    required CosmicPartyMember player,
    required CosmicContestOpponent opponent,
    required int level,
    required double playerScore,
    required double opponentScore,
  }) async {
    final game = _game;
    if (game == null || !mounted) return null;
    final opponentMember = await _buildBeautyContestOpponentMember(
      opponent,
      level,
    );
    if (!mounted) return null;
    if (opponentMember == null) {
      _showQuote(
        'No owned creatures available for intelligence contest opponents.',
      );
      return null;
    }
    final arenaCenter = _nearContestArena?.position ?? game.ship.pos;
    game.beginIntelligenceContestCinematic(
      opponentMember: opponentMember,
      arenaCenter: arenaCenter,
      playerWon: playerScore >= opponentScore,
      playerScore: playerScore,
      opponentScore: opponentScore,
    );
    final introDelay = Duration(
      milliseconds: (game.intelligenceContestIntroDuration * 1000).round(),
    );

    try {
      if (introDelay > Duration.zero) {
        await Future<void>.delayed(introDelay);
        if (!mounted) {
          game.endBeautyContestCinematic();
          return opponentMember.displayName;
        }
      }
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Intelligence Contest',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, _, __) => CosmicIntelligenceContestArenaOverlay(
          player: player,
          opponentMember: opponentMember,
          playerScore: playerScore,
          opponentScore: opponentScore,
        ),
        transitionBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        game.endBeautyContestCinematic();
      }
    }
    return opponentMember.displayName;
  }

  Future<void> _handleContestArenaTap() async {
    if (_game == null || _nearContestArena == null) return;
    if (_activeCompanionSlot == null) {
      _showQuote('Summon a companion first to enter a contest.');
      return;
    }
    final activeSlot = _activeCompanionSlot!;
    final member = _partyMembers[activeSlot];
    if (member == null) {
      _showQuote('Active companion missing.');
      return;
    }

    final trait = _nearContestArena!.trait;
    final completed = _contestProgress.completedLevels(trait);
    final levels = kCosmicContestLevels[trait]!;
    if (completed >= levels.length) {
      _showQuote('${trait.label} contest fully mastered.');
      HapticFeedback.selectionClick();
      return;
    }

    final staminaSpent = await _consumeContestStamina(
      slotIndex: activeSlot,
      member: member,
    );
    if (!staminaSpent) return;

    final level = levels[completed];
    final levelOpponent = trait == CosmicContestTrait.beauty
        ? _beautyOpponentForLevel(level.level)
        : level.opponent;
    final playerScore = await _computePlayerContestScore(trait, member);
    final opponentScore = _computeOpponentContestScore(trait, levelOpponent);
    final won = playerScore >= opponentScore;
    var opponentLabel = _contestOpponentDisplay(levelOpponent);

    if (trait == CosmicContestTrait.beauty) {
      final presentedOpponent = await _playBeautyContestPresentation(
        player: member,
        opponent: levelOpponent,
        level: level.level,
        playerScore: playerScore,
        opponentScore: opponentScore,
      );
      if (!mounted) return;
      if (presentedOpponent == null) return;
      opponentLabel = presentedOpponent.displayName;
    }
    if (trait == CosmicContestTrait.speed) {
      final presentedSpeedOpponent = await _playSpeedContestPresentation(
        player: member,
        opponent: levelOpponent,
        level: level.level,
        playerScore: playerScore,
        opponentScore: opponentScore,
      );
      if (!mounted) return;
      if (presentedSpeedOpponent == null) return;
      opponentLabel = presentedSpeedOpponent;
    }
    if (trait == CosmicContestTrait.strength) {
      final presentedStrengthOpponent = await _playStrengthContestPresentation(
        player: member,
        opponent: levelOpponent,
        level: level.level,
        playerScore: playerScore,
        opponentScore: opponentScore,
      );
      if (!mounted) return;
      if (presentedStrengthOpponent == null) return;
      opponentLabel = presentedStrengthOpponent;
    }
    if (trait == CosmicContestTrait.intelligence) {
      final presentedIntelligenceOpponent =
          await _playIntelligenceContestPresentation(
            player: member,
            opponent: levelOpponent,
            level: level.level,
            playerScore: playerScore,
            opponentScore: opponentScore,
          );
      if (!mounted) return;
      if (presentedIntelligenceOpponent == null) return;
      opponentLabel = presentedIntelligenceOpponent;
    }

    if (won) {
      final nextCompleted = completed + 1;
      _contestProgress = _contestProgress.withCompleted(trait, nextCompleted);
      await _saveContestProgress();
      _game!.shipWallet.shards += level.rewardShards;
      String masteryUnlockText = '';
      if (nextCompleted >= levels.length) {
        final unlockedEffectName = await _unlockContestMasteryEffect(trait);
        if (unlockedEffectName != null && unlockedEffectName.isNotEmpty) {
          masteryUnlockText =
              ' $unlockedEffectName unlocked in shop and +1 granted.';
        }
      }
      _showQuote(
        '${trait.label} Lv${level.level}: ${member.displayName} defeated $opponentLabel '
        '(${playerScore.toStringAsFixed(2)} vs ${opponentScore.toStringAsFixed(2)}). '
        '+${level.rewardShards} shards.$masteryUnlockText',
      );
      HapticFeedback.heavyImpact();
    } else {
      if (trait == CosmicContestTrait.beauty) {
        _rotateBeautyOpponentAfterLoss(level.level);
      }
      _showQuote(
        '${trait.label} Lv${level.level}: $opponentLabel wins '
        '(${playerScore.toStringAsFixed(2)} vs ${opponentScore.toStringAsFixed(2)}).',
      );
      HapticFeedback.mediumImpact();
    }
    if (mounted) setState(() {});
  }

  /// Fixed opponent roster for each battle ring level.
  static const _battleRingOpponents = <int, (String, String)>{
    0: ('LET13', 'common'), // Poisonlet
    1: ('WNG04', 'legendary'), // Airwing
    2: ('MAN14', 'uncommon'), // Spiritmane
    3: ('MSK09', 'rare'), // Icemask
    4: ('HOR16', 'rare'), // Lighthorn
    5: ('MAN05', 'uncommon'), // Steammane
    6: ('PIP06', 'uncommon'), // Lavapip
    7: ('MAN03', 'uncommon'), // Earthmane
    8: ('KIN12', 'legendary'), // Plantkin
    9: ('WNG01', 'legendary'), // Firewing
  };

  void _handleBattleRingTap() async {
    if (_game == null || !_game!.isNearBattleRing) return;
    HapticFeedback.heavyImpact();

    final br = _game!.battleRing;

    if (br.isCompleted) {
      // Practice arena now spawns a random opponent (level 10 strength)
      if (_activeCompanionSlot == null) {
        _showQuote('Summon a companion first to enter the ring!');
        return;
      }
      if (br.inBattle) return;

      // Choose a random species from the catalog and generate a hydrated creature
      final catalog = context.read<CreatureCatalog>();
      if (!catalog.isLoaded || catalog.creatures.isEmpty) {
        _showQuote('Creature catalog not available.');
        return;
      }
      final rng = Random();
      final choice = catalog.creatures[rng.nextInt(catalog.creatures.length)];
      final rarities = catalog.allRarities();
      String? chosenRarity;
      if (rarities.isNotEmpty) {
        // Pick a random rarity so practice opponents vary in type/strength.
        chosenRarity = rarities[rng.nextInt(rarities.length)];
      } else {
        chosenRarity = choice.rarity;
      }
      final gen = WildlifeGenerator(catalog);
      final hydrated = gen.generate(choice.id, rarity: chosenRarity);
      if (hydrated == null) {
        _showQuote('Could not generate opponent!');
        return;
      }

      final speed = CosmicBalance.rollArenaStat(10, rng);
      final intelligence = CosmicBalance.rollArenaStat(10, rng);
      final strength = CosmicBalance.rollArenaStat(10, rng);
      final beauty = CosmicBalance.rollArenaStat(10, rng);

      final base = catalog.getCreatureById(hydrated.id);
      final typeName = (base?.types.isNotEmpty ?? false)
          ? base!.types.first
          : 'Earth';
      final family = base?.mutationFamily ?? 'kin';
      final displayName = base?.name ?? hydrated.id;
      final sheet = base?.spriteData != null ? sheetFromCreature(base!) : null;
      final visuals = visualsFromInstance(base, null);

      final ringCenter = br.position;
      const ringRadius = 162.0;
      final companionPos = Offset(ringCenter.dx + ringRadius, ringCenter.dy);
      final opponentPos = Offset(ringCenter.dx - ringRadius, ringCenter.dy);

      final opponentMember = CosmicPartyMember(
        instanceId:
            'practice_opponent_${DateTime.now().millisecondsSinceEpoch}',
        baseId: hydrated.id,
        displayName: displayName,
        imagePath: base?.image != null ? 'assets/images/${base!.image}' : null,
        element: typeName,
        family: family,
        level: 10,
        statSpeed: speed,
        statIntelligence: intelligence,
        statStrength: strength,
        statBeauty: beauty,
        slotIndex: -1,
        staminaBars: 999,
        staminaMax: 999,
        spriteSheet: sheet,
        spriteVisuals: visuals,
        visualVariant: null,
        spawnPosition: opponentPos,
      );

      br.inBattle = true;
      _saveBattleRingState();
      _game!.spawnBattleRingOpponent(opponentMember);

      // Move companion anchor to its spawn position
      if (_game!.activeCompanion != null) {
        _game!.activeCompanion!.anchorPosition = companionPos;
        _game!.activeCompanion!.position = companionPos;
      }

      setState(() {});
      _showQuote('Practice Arena — $displayName enters the ring!');
      return;
    }

    // Normal level — deploy active companion into the ring in-world
    if (_activeCompanionSlot == null) {
      _showQuote('Summon a companion first to enter the ring!');
      return;
    }
    if (br.inBattle) return; // already fighting

    _startBattleRingFight();
  }

  /// Spawn the ring opponent in-world and start the 1v1.
  void _startBattleRingFight() {
    if (_game == null) return;
    final br = _game!.battleRing;
    final level = br.currentLevel;

    final entry = _battleRingOpponents[level];
    if (entry == null) return;
    final (speciesId, rarity) = entry;

    final catalog = context.read<CreatureCatalog>();
    final gen = WildlifeGenerator(catalog);
    final hydrated = gen.generate(speciesId, rarity: rarity);
    if (hydrated == null) {
      _showQuote('Could not generate opponent!');
      return;
    }

    final rng = Random();
    final arenaLevel = level + 1;
    final speed = CosmicBalance.rollArenaStat(arenaLevel, rng);
    final intelligence = CosmicBalance.rollArenaStat(arenaLevel, rng);
    final strength = CosmicBalance.rollArenaStat(arenaLevel, rng);
    final beauty = CosmicBalance.rollArenaStat(arenaLevel, rng);

    // Build a CosmicPartyMember for the opponent
    final base = catalog.getCreatureById(hydrated.id);
    final typeName = (base?.types.isNotEmpty ?? false)
        ? base!.types.first
        : 'Earth';
    final family = base?.mutationFamily ?? 'kin';
    final displayName = base?.name ?? speciesId;
    final sheet = base?.spriteData != null ? sheetFromCreature(base!) : null;
    var visuals = visualsFromInstance(base, null);

    // Calculate spawn positions at opposite ends of the ring
    final ringCenter = br.position;
    // Make the octagon battle ring 10% smaller for tighter fights
    const ringRadius = 162.0; // was 180.0
    // Player's companion at 0 degrees, opponent at 180 degrees
    final companionPos = Offset(ringCenter.dx + ringRadius, ringCenter.dy);
    final opponentPos = Offset(ringCenter.dx - ringRadius, ringCenter.dy);

    // Determine opponent tint/variant
    String? visualVariant;
    if (level == 9) {
      visualVariant = 'prismatic';
    } else if (level == 3 || level == 4) {
      visualVariant = 'cryogenic';
    } else if (level == 1 || level == 7) {
      visualVariant = 'albino';
    }
    if (visualVariant != null) {
      visuals = SpriteVisuals(
        scale: visuals.scale,
        saturation: visuals.saturation,
        brightness: visuals.brightness,
        hueShiftDeg: visuals.hueShiftDeg,
        isPrismatic: visualVariant == 'prismatic' ? true : visuals.isPrismatic,
        tint: visualVariant == 'cryogenic'
            ? const Color(0xFF7CC6FF).withValues(alpha: 0.35)
            : visualVariant == 'albino'
            ? null
            : visuals.tint,
        alchemyEffect: visuals.alchemyEffect,
        variantFaction: visuals.variantFaction,
      );
    }

    final opponentMember = CosmicPartyMember(
      instanceId: 'ring_opponent_$level',
      baseId: hydrated.id,
      displayName: displayName,
      imagePath: base?.image != null ? 'assets/images/${base!.image}' : null,
      element: typeName,
      family: family,
      level: level + 1,
      statSpeed: speed,
      statIntelligence: intelligence,
      statStrength: strength,
      statBeauty: beauty,
      slotIndex: -1,
      staminaBars: 999,
      staminaMax: 999,
      spriteSheet: sheet,
      spriteVisuals: visuals,
      visualVariant: visualVariant,
      spawnPosition: opponentPos,
    );

    br.inBattle = true;
    _saveBattleRingState();
    _game!.spawnBattleRingOpponent(opponentMember);

    // Move companion anchor to its spawn position
    if (_game!.activeCompanion != null) {
      _game!.activeCompanion!.anchorPosition = companionPos;
      _game!.activeCompanion!.position = companionPos;
    }

    setState(() {});
    _showQuote('Level ${level + 1} — $displayName enters the ring!');
  }

  void _onBattleRingWon() {
    if (!mounted || _game == null) return;
    final br = _game!.battleRing;
    final goldReward = br.goldReward;
    final completedLevel = br.currentLevel;

    br.inBattle = false;
    br.currentLevel = (br.currentLevel + 1).clamp(0, BattleRing.maxLevels);
    _saveBattleRingState();

    final db = context.read<AlchemonsDatabase>();
    if (goldReward > 0) {
      db.currencyDao.addGold(goldReward);
    }

    HapticFeedback.heavyImpact();
    if (completedLevel >= BattleRing.maxLevels) {
      _showQuote('Practice match complete.');
    } else if (br.currentLevel >= BattleRing.maxLevels) {
      _showQuote('Arena completed! +$goldReward gold');
    } else {
      _showQuote('Level ${completedLevel + 1} complete! +$goldReward gold');
    }
    setState(() {});
  }

  void _onBattleRingLost() {
    if (!mounted || _game == null) return;
    final br = _game!.battleRing;
    br.inBattle = false;
    _saveBattleRingState();

    HapticFeedback.mediumImpact();
    _showQuote('Your Alchemon was defeated! Try again.');
    setState(() {});
  }

  void _onBattleRingCancelled() {
    if (!mounted || _game == null) return;
    final br = _game!.battleRing;
    br.inBattle = false;
    _saveBattleRingState();

    HapticFeedback.mediumImpact();
    _showQuote('Battle canceled. Your Alchemon retreated.');
    setState(() {});
  }

  bool _isMysticBloodCompanion(CosmicPartyMember member) {
    final isBlood = member.element.trim().toLowerCase() == 'blood';
    final isMystic = member.family.trim().toLowerCase() == 'mystic';
    return isBlood && isMystic;
  }

  Future<CosmicPartyMember?> _pickBloodRingOffering(
    List<CosmicPartyMember> candidates,
  ) async {
    if (!mounted) return null;
    return showDialog<CosmicPartyMember>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF120607),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0x55FF8A80), width: 1.2),
          ),
          title: Text(
            'Choose Favorite Alchemon',
            style: TextStyle(
              color: Color(0xFFFFCDD2),
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Select one more companion from your ship party.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                  for (final c in candidates)
                    ListTile(
                      onTap: () => Navigator.of(context).pop(c),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF2B1011),
                        child: c.imagePath != null
                            ? ClipOval(
                                child: Image.asset(
                                  c.imagePath!,
                                  fit: BoxFit.cover,
                                  width: 34,
                                  height: 34,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.auto_awesome,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.auto_awesome,
                                color: Colors.white70,
                                size: 16,
                              ),
                      ),
                      title: Text(
                        c.displayName,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${c.element} · ${c.family}',
                        style: TextStyle(color: Colors.white60),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white54,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openBloodPortalCredits() async {
    final game = _game;
    if (game == null || _runningBloodEnding) return;
    final available = _partyMembers.whereType<CosmicPartyMember>().toList();
    if (available.isEmpty) {
      _showQuote('Bring one Alchemon in your ship party.');
      return;
    }
    final active = _activeCompanionSlot == null
        ? null
        : _partyMembers[_activeCompanionSlot!];
    final mysticMember = active != null && _isMysticBloodCompanion(active)
        ? active
        : available.first;
    final savedOffering = _findSavedBloodRingOffering(available);
    CosmicPartyMember? favoriteMember;
    for (final member in available) {
      if (member != mysticMember) {
        favoriteMember = member;
        break;
      }
    }
    final replayOffering = savedOffering ?? favoriteMember ?? mysticMember;
    final savedOfferingName = game.bloodRing.lastOfferingName?.trim();
    final storyName =
        (savedOfferingName != null && savedOfferingName.isNotEmpty)
        ? savedOfferingName
        : replayOffering.displayName;
    _runningBloodEnding = true;
    var shouldReturnHome = false;
    game.pauseEngine();
    try {
      await _pushFade<bool>(
        BloodRingStoryScenePage(offeringName: storyName),
        duration: const Duration(milliseconds: 280),
      );

      if (!mounted) return;
      await _pushFade<bool>(
        BloodRingValleyCreditsPage(
          mysticImagePath: mysticMember.imagePath,
          offeringImagePath:
              game.bloodRing.lastOfferingImagePath ?? replayOffering.imagePath,
          offeringElement:
              game.bloodRing.lastOfferingElement ?? replayOffering.element,
          offeringFamily:
              game.bloodRing.lastOfferingFamily ?? replayOffering.family,
          offeringIntelligence:
              game.bloodRing.lastOfferingIntelligence ??
              replayOffering.statIntelligence,
          offeringStrength:
              game.bloodRing.lastOfferingStrength ??
              replayOffering.statStrength,
          offeringBeauty:
              game.bloodRing.lastOfferingBeauty ?? replayOffering.statBeauty,
        ),
        duration: const Duration(milliseconds: 280),
      );
      shouldReturnHome = true;
    } finally {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      _runningBloodEnding = false;
      if (mounted && !shouldReturnHome) {
        game.resumeEngine();
      }
    }

    if (shouldReturnHome && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<T?> _pushFade<T>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 320),
    Duration reverseDuration = const Duration(milliseconds: 220),
  }) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder<T>(
        transitionDuration: duration,
        reverseTransitionDuration: reverseDuration,
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: child,
        ),
      ),
    );
  }

  Future<void> _playBloodRitualInSpace() async {
    if (!mounted) return;
    setState(() => _showBloodRitualOverlay = true);
    _bloodRitualCtrl.stop();
    _bloodRitualCtrl.value = 0;
    await _bloodRitualCtrl.forward();
  }

  void _resetBloodRitualOverlay() {
    if (!mounted) return;
    setState(() => _showBloodRitualOverlay = false);
    _bloodRitualCtrl.value = 0;
  }

  Map<String, int> _decodeLineageJson(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(
          key.toString(),
          value is num ? value.toInt() : int.tryParse(value.toString()) ?? 0,
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Map<String, String> _decodeGeneticsJson(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map((key, value) => MapEntry(key.toString(), '$value'));
    } catch (_) {
      return const {};
    }
  }

  void _rememberBloodRingOffering({
    required String offeringName,
    String? offeringInstanceId,
    String? offeringImagePath,
    String? offeringElement,
    String? offeringFamily,
    double? offeringIntelligence,
    double? offeringStrength,
    double? offeringBeauty,
  }) {
    final ring = _game?.bloodRing;
    if (ring == null) return;
    ring.lastOfferingInstanceId = offeringInstanceId;
    ring.lastOfferingName = offeringName;
    ring.lastOfferingImagePath = offeringImagePath;
    ring.lastOfferingElement = offeringElement;
    ring.lastOfferingFamily = offeringFamily;
    ring.lastOfferingIntelligence = offeringIntelligence;
    ring.lastOfferingStrength = offeringStrength;
    ring.lastOfferingBeauty = offeringBeauty;
  }

  CosmicPartyMember? _findSavedBloodRingOffering(
    List<CosmicPartyMember> available,
  ) {
    final savedId = _game?.bloodRing.lastOfferingInstanceId?.trim();
    if (savedId == null || savedId.isEmpty) return null;
    for (final member in available) {
      if (member.instanceId == savedId) return member;
    }
    return null;
  }

  Future<bool> _grantBloodbornRewardEgg(String sacrificedInstanceId) async {
    if (!mounted) return false;
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final sacrificed = await db.creatureDao.getInstance(sacrificedInstanceId);
    if (sacrificed == null) return false;
    final base = repo.getCreatureById(sacrificed.baseId);
    if (base == null) return false;

    final nativeFaction = elementalGroupNameOf(base);
    final factionLineage = _decodeLineageJson(sacrificed.factionLineageJson);
    final elementLineage = _decodeLineageJson(sacrificed.elementLineageJson);
    final familyLineage = _decodeLineageJson(sacrificed.familyLineageJson);
    final payload = EggPayload(
      baseId: sacrificed.baseId,
      rarity: base.rarity,
      source: 'bloodborn',
      vialName: 'Bloodborn Vial',
      natureId: sacrificed.natureId,
      isPrismaticSkin: sacrificed.isPrismaticSkin,
      genetics: _decodeGeneticsJson(sacrificed.geneticsJson),
      stats: CreatureStats(
        speed: sacrificed.statSpeed,
        intelligence: sacrificed.statIntelligence,
        strength: sacrificed.statStrength,
        beauty: sacrificed.statBeauty,
      ),
      potentials: const CreatureStatPotentials(
        speed: 5.0,
        intelligence: 5.0,
        strength: 5.0,
        beauty: 5.0,
      ),
      lineage: LineageData(
        generationDepth: sacrificed.generationDepth,
        nativeFaction: nativeFaction,
        variantFaction: 'bloodborn',
        factionLineage: factionLineage.isEmpty
            ? {nativeFaction: 1}
            : factionLineage,
        elementLineage: elementLineage.isEmpty && base.types.isNotEmpty
            ? {base.types.first: 1}
            : elementLineage,
        familyLineage:
            familyLineage.isEmpty &&
                base.mutationFamily != null &&
                base.mutationFamily!.trim().isNotEmpty
            ? {base.mutationFamily!.trim(): 1}
            : familyLineage,
        isPure: sacrificed.isPure,
      ),
      likelihoodAnalysisJson: sacrificed.likelihoodAnalysisJson,
    );
    final eggId = db.creatureDao.makeInstanceId('BLOOD');
    final rarityKey = base.rarity.toLowerCase();
    final hatchDelay =
        BreedConstants.rarityHatchTimes[rarityKey] ?? const Duration(hours: 8);
    final payloadJson = payload.toJsonString();
    final free = await db.incubatorDao.firstFreeSlot();
    if (free != null) {
      await db.incubatorDao.placeEgg(
        slotId: free.id,
        eggId: eggId,
        resultCreatureId: base.id,
        rarity: base.rarity,
        hatchAtUtc: DateTime.now().toUtc().add(hatchDelay),
        payloadJson: payloadJson,
      );
    } else {
      await db.incubatorDao.enqueueEgg(
        eggId: eggId,
        resultCreatureId: base.id,
        rarity: base.rarity,
        remaining: hatchDelay,
        payloadJson: payloadJson,
      );
    }
    await db.inventoryDao.addItemQty(InvKeys.alchemyBloodAura, 1);
    final freeText = free == null
        ? 'Bloodborn specimen transferred to cold storage'
        : 'Bloodborn specimen placed in incubation chamber ${free.id + 1}';
    if (!mounted) return false;
    final fc = FC.of(context);
    final ft = FT(fc);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: fc.bg2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: fc.success.withValues(alpha: 0.55)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 16, color: fc.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  freeText,
                  style: ft.body.copyWith(
                    color: fc.textPrimary,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return true;
  }

  Future<void> _runBloodRingEnding({
    required String storyAlchemonName,
    String? sacrificedInstanceId,
    String? mysticImagePath,
    String? offeringImagePath,
    String? offeringElement,
    String? offeringFamily,
    double? offeringIntelligence,
    double? offeringStrength,
    double? offeringBeauty,
  }) async {
    final game = _game;
    if (game == null || _runningBloodEnding) return;
    _runningBloodEnding = true;
    bool shouldReturnHome = false;
    game.pauseEngine();

    try {
      _rememberBloodRingOffering(
        offeringName: storyAlchemonName,
        offeringInstanceId: sacrificedInstanceId,
        offeringImagePath: offeringImagePath,
        offeringElement: offeringElement,
        offeringFamily: offeringFamily,
        offeringIntelligence: offeringIntelligence,
        offeringStrength: offeringStrength,
        offeringBeauty: offeringBeauty,
      );
      await _saveBloodRingState();

      await _playBloodRitualInSpace();

      if (!mounted) return;
      await _pushFade<bool>(
        BloodRingStoryScenePage(offeringName: storyAlchemonName),
        duration: const Duration(milliseconds: 360),
      );

      if (!mounted) return;
      await _pushFade<bool>(
        BloodRingValleyCreditsPage(
          mysticImagePath: mysticImagePath,
          offeringImagePath: offeringImagePath,
          offeringElement: offeringElement,
          offeringFamily: offeringFamily,
          offeringIntelligence: offeringIntelligence,
          offeringStrength: offeringStrength,
          offeringBeauty: offeringBeauty,
        ),
        duration: const Duration(milliseconds: 360),
      );

      if (sacrificedInstanceId != null && mounted) {
        await _grantBloodbornRewardEgg(sacrificedInstanceId);
      }

      game.bloodRing.ritualCompleted = true;
      await _saveBloodRingState();
      shouldReturnHome = true;
    } finally {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      _runningBloodEnding = false;
      if (mounted && !shouldReturnHome) {
        _resetBloodRitualOverlay();
        game.resumeEngine();
        setState(() {});
      }
    }

    if (shouldReturnHome && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleBloodRingTap() async {
    if (_game == null || !_game!.isNearBloodRing || _runningBloodEnding) return;
    HapticFeedback.heavyImpact();

    final ring = _game!.bloodRing;
    if (ring.ritualCompleted) {
      await _openBloodPortalCredits();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final planetIntroSeen = prefs.getBool(_planetPathwayIntroSeenKey) ?? false;
    if (!planetIntroSeen) {
      _showQuote('Complete planetary recipes to unlock a sacrifice.');
      return;
    }

    if (_activeCompanionSlot == null) {
      _showQuote('Mystic Blood required.');
      return;
    }

    final active = _partyMembers[_activeCompanionSlot!];
    if (active == null || !_isMysticBloodCompanion(active)) {
      _showQuote('Mystic Blood required.');
      return;
    }

    final offerings = <CosmicPartyMember>[];
    for (var i = 0; i < _partyMembers.length; i++) {
      if (i == _activeCompanionSlot) continue;
      final m = _partyMembers[i];
      if (m != null) offerings.add(m);
    }

    if (offerings.isEmpty) {
      _showQuote('Bring one more Alchemon in your ship party.');
      return;
    }

    final picked = await _pickBloodRingOffering(offerings);
    if (picked == null) return;

    await _runBloodRingEnding(
      storyAlchemonName: picked.displayName,
      sacrificedInstanceId: picked.instanceId,
      mysticImagePath: active.imagePath,
      offeringImagePath: picked.imagePath,
      offeringElement: picked.element,
      offeringFamily: picked.family,
      offeringIntelligence: picked.statIntelligence,
      offeringStrength: picked.statStrength,
      offeringBeauty: picked.statBeauty,
    );
  }

  void _onHomePlanetBuilt(HomePlanet planet) {
    _homePlanet = planet;
    _saveHomePlanet();
    _initOrbitalChambers();
    if (mounted) {
      final shouldShowTutorial = _awaitingBuildHomeTap;
      _awaitingBuildHomeTap = false;
      _awaitingShipMenuTap = false;
      HapticFeedback.heavyImpact();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {});
        if (shouldShowTutorial) {
          unawaited(_showHomeBuiltTutorial());
        }
      });
    }
  }

  void _onBossDefeated(String bossName) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    _showQuote('$bossName defeated!');
  }

  void _onLootCollected(LootDrop drop) {
    if (!mounted || _game == null) return;
    switch (drop.type) {
      case LootType.astralShard:
        final added = _game!.shipWallet.addShards(drop.amount);
        if (added == 0) {
          // Wallet full — loot stays on ground (don't collect)
          drop.collected = false;
        }
        break;
      case LootType.elementParticle:
        if (drop.element != null) {
          _elementStorage.addAll({drop.element!: drop.amount.toDouble()});
          // Also fill the meter so enemies contribute to teleport progress
          if (_game != null && !_game!.meter.isFull) {
            _game!.meter.add(drop.element!, drop.amount.toDouble());
            _game!.onMeterChanged();
          }
        }
        break;
      case LootType.item:
        if (drop.itemKey != null) {
          final db = context.read<AlchemonsDatabase>();
          db.inventoryDao.addItemQty(drop.itemKey!, 1);
          _showItemPickupMessage(drop.itemKey!);
        }
        break;
      case LootType.healthOrb:
        // Heal the ship by `amount` (integer -> treated as HP units)
        final healed = drop.amount.toDouble();
        _game!.shipHealth = (_game!.shipHealth + healed).clamp(
          0.0,
          CosmicGame.shipMaxHealth,
        );
        HapticFeedback.lightImpact();
        break;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {}); // refresh wallet display
    });
  }

  void _onBossSpawned(String bossName) {
    // No message — bosses appear silently
  }

  void _onShipDied() {
    if (!mounted) return;
    HapticFeedback.heavyImpact();

    // Return active companion
    if (_activeCompanionSlot != null) {
      _game?.returnCompanion();
      _activeCompanionSlot = null;
    }

    // Mark all party members as dead HP
    for (var i = 0; i < _partyMembers.length; i++) {
      if (_partyMembers[i] != null) {
        _companionHpFraction[i] = 0.0;
      }
    }

    // Drain ALL party Alchemon stamina to 0
    final db = context.read<AlchemonsDatabase>();
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final m in _partyMembers) {
      if (m == null) continue;
      db.creatureDao.updateStamina(
        instanceId: m.instanceId,
        staminaBars: 0,
        staminaLastUtcMs: nowMs,
      );
    }

    _showQuote(
      'Your ship was destroyed! Cargo and unbanked shards were lost. Your Alchemons are exhausted…',
    );
    // Refresh party so drained members are removed from slots
    _initCosmicParty();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  // ── Space Market ─────────────────────────────────────
  void _onNearMarket(SpacePOI? poi) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _nearMarketPOI = poi);
    });
  }

  void _onPOIDiscovered(SpacePOI poi) {
    if (poi.type == POIType.warpAnomaly) {
      _playCosmicSfx(SoundCue.cosmicAnomalyBurst);
    }
    if (poi.type == POIType.survivalPortal) {
      final db = context.read<AlchemonsDatabase>();
      db.settingsDao.setCosmicSurvivalPortalDiscovered();
    }
    _saveFogState();
    if (mounted && _showPinnedMiniMap) {
      setState(() {});
    }
  }

  void _openMarketShop() {
    if (_nearMarketPOI == null || _game == null) return;
    if (_nearMarketPOI!.type == POIType.survivalPortal) {
      _enterSurvivalPortal();
      return;
    }
    if (_nearMarketPOI!.type == POIType.stardustScanner) {
      _activateStarDustScanner();
      return;
    }
    if (_nearMarketPOI!.type == POIType.planetScanner) {
      _activatePlanetScanner();
      return;
    }
    if (_nearMarketPOI!.type == POIType.cosmicMarket) {
      CosmicSellSheet.show(context);
      return;
    }
    if (_nearMarketPOI!.type == POIType.goldConversion) {
      GoldConversionSheet.show(
        context,
        carriedShards: _game!.shipWallet.shards,
        shardCapacity: _game!.shipWallet.shardCapacity,
        addShards: (amount) {
          setState(() {
            _game!.shipWallet.shards += amount;
          });
        },
      );
      return;
    }
    SpaceMarketSheet.show(
      context,
      marketType: _nearMarketPOI!.type,
      meter: _game!.meter,
      carriedShards: _game!.shipWallet.shards,
      spendShards: (amount) {
        if (_game == null || _game!.shipWallet.shards < amount) return false;
        setState(() {
          _game!.shipWallet.shards -= amount;
        });
        return true;
      },
    );
  }

  void _activateStarDustScanner() {
    if (_game == null) return;
    final err = _game!.activateStarDustScanner(shardCost: _starDustScanCost);
    if (err != null) {
      _showQuote(err);
      HapticFeedback.heavyImpact();
      return;
    }
    _showQuote(
      'Scanner locked. Follow the radar beeper to the target star dust.',
    );
    HapticFeedback.mediumImpact();
    _saveFogState();
    if (mounted) setState(() {});
  }

  void _enterSurvivalPortal() {
    if (_game == null) return;
    HapticFeedback.mediumImpact();
    // Persist portal discovery
    final db = context.read<AlchemonsDatabase>();
    db.settingsDao.setCosmicSurvivalPortalDiscovered();
    // Navigate to cosmic survival screen
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CosmicSurvivalScreen()));
  }

  void _activatePlanetScanner() {
    if (_game == null || _nearMarketPOI == null) return;
    final err = _game!.activatePlanetScanner(
      _nearMarketPOI!,
      shardCost: _planetScanCost,
    );
    if (err != null) {
      _showQuote(err);
      HapticFeedback.heavyImpact();
      return;
    }
    _showQuote(
      'Planet scanner locked. Follow the beacon to the nearest undiscovered planet.',
    );
    HapticFeedback.mediumImpact();
    _saveFogState();
    if (mounted) setState(() {});
  }

  Future<void> _saveMapMarkers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _markersPrefsKey,
      MapMarker.serialiseList(_mapMarkers),
    );
  }

  Future<void> _saveHomePlanet() async {
    if (_homePlanet == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_homePlanetPrefsKey, _homePlanet!.serialise());
  }

  Future<void> _markCosmicIntroComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cosmicIntroPromptedKey, true);
    await prefs.setBool(_cosmicIntroCompletedKey, true);
  }

  Future<void> _maybeRunCosmicIntro() async {
    if (_runningCosmicIntro || !mounted || _game == null) return;

    final prefs = await SharedPreferences.getInstance();
    final prompted = prefs.getBool(_cosmicIntroPromptedKey) ?? false;
    final completed = prefs.getBool(_cosmicIntroCompletedKey) ?? false;
    if (completed) return;

    if (_homePlanet != null) {
      await _markCosmicIntroComplete();
      return;
    }

    if (!mounted) return;
    if (prompted) {
      setState(() {
        _awaitingShipMenuTap = true;
      });
      return;
    }

    _runningCosmicIntro = true;
    try {
      await LandscapeDialog.show(
        context,
        title: 'Reality Unfolds',
        message:
            '"We are travelers on a cosmic journey, stardust, swirling and dancing in the eddies and whirlpools of infinity."',
        typewriter: true,
        kind: LandscapeDialogKind.info,
        showIcon: false,
        primaryLabel: 'Continue',
        barrierDismissible: false,
      );

      if (!mounted) return;
      await LandscapeDialog.show(
        context,
        title: 'Discover the Cosmos',
        message:
            'Discover the secrets of the alchemical world. Planets, competitions, and markets await discovery. Tap mini map for discovered progress and teleport to discovered planets.',
        typewriter: true,
        kind: LandscapeDialogKind.info,
        showIcon: false,
        primaryLabel: 'Continue',
        barrierDismissible: false,
      );

      if (!mounted) return;
      await prefs.setBool(_cosmicIntroPromptedKey, true);
      setState(() {
        _awaitingShipMenuTap = true;
      });
    } finally {
      _runningCosmicIntro = false;
    }
  }

  Future<void> _showHomeBuiltTutorial() async {
    if (!mounted) return;
    await LandscapeDialog.show(
      context,
      title: 'Home Established',
      message:
          'Upgrade your ship and home base while at home. Collect resources and shards from planets and enemies to unlock special upgrades for the planet and your ship. Teleport to your home planet from your mini map.',
      typewriter: true,
      kind: LandscapeDialogKind.info,
      showIcon: false,
      primaryLabel: 'Continue',
      barrierDismissible: false,
    );
    await _markCosmicIntroComplete();
  }

  bool _handleBuildHomePlanet() {
    if (_game == null || _homePlanet != null) return false;
    final warning = _game!.buildHomePlanet();
    if (warning != null) {
      _showQuote(warning);
      return false;
    }
    return true;
  }

  static const int _relocateCost = 50;
  static const int _starDustScanCost = 50;
  static const int _planetScanCost = 50;

  void _handleMoveHomePlanet() {
    if (_game == null || _homePlanet == null) return;
    final wallet = _game!.shipWallet;
    if (wallet.shards < _relocateCost) {
      _showQuote(
        'Not enough ship shards! Need $_relocateCost carried to relocate.',
      );
      HapticFeedback.heavyImpact();
      return;
    }
    final warning = _game!.moveHomePlanet();
    if (warning != null) {
      _showQuote(warning);
      return;
    }
    wallet.shards -= _relocateCost;
    _saveHomePlanet();
    setState(() {});
  }

  /// Max meter fill % allowed for teleporting home.
  double get _teleportCapacity {
    return CargoUpgrade.capacityForLevel(_cargoLevel);
  }

  bool _handleGoHome() {
    if (_game == null || _homePlanet == null) return false;
    // Block teleport when meter is too full
    final meterPct = _game!.meter.fillPct;
    if (meterPct > _teleportCapacity) {
      final capPct = (_teleportCapacity * 100).round();
      _showQuote(
        'Too much elemental energy! Fly home or lighten below $capPct%.',
      );
      HapticFeedback.heavyImpact();
      return false;
    }
    _resetCosmicTouchState();
    _game!.teleportTo(_homePlanet!.position);
    HapticFeedback.lightImpact();
    return true;
  }

  /// Jettison all elemental cargo (meter) into the void.
  void _handleJettisonCargo() {
    if (_game == null) return;
    final meter = _game!.meter;
    if (meter.total <= 0) {
      _showQuote('Cargo hold is already empty.');
      return;
    }
    meter.reset();
    _game!.onMeterChanged();
    _showQuote('Elemental cargo jettisoned into the void.');
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  /// Dump wallet contents (silver & gold lost forever).
  void _handleDumpWallet() {
    if (_game == null) return;
    final wallet = _game!.shipWallet;
    if (wallet.shards <= 0) {
      _showQuote('Wallet is already empty.');
      return;
    }
    wallet.depositAll(); // discard — not banked
    _showQuote('Shards dumped overboard.');
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  void _onNearHome(bool isNear) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isNearHome = isNear;
        if (!isNear) _healTimer = 0;
        if (isNear) {
          // Heal all party companions to full HP when arriving home
          _companionHpFraction.clear();
        }
      });
    });
  }

  void _depositMeterAtHome() {
    final meter = _game!.meter;
    if (meter.total <= 0) return;
    final breakdown = Map<String, double>.from(meter.breakdown);

    // Deposit into home planet color mix (grows the planet)
    for (final e in breakdown.entries) {
      _homePlanet!.colorMix[e.key] =
          (_homePlanet!.colorMix[e.key] ?? 0) + e.value;
    }

    // Also store in element storage for crafting
    _elementStorage.addAll(breakdown);
    _saveElementStorage();

    // Build summary of deposited elements
    final parts = breakdown.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.key} ${e.value.toStringAsFixed(0)}')
        .toList();
    final elemSummary = parts.isNotEmpty ? parts.join(', ') : 'elements';

    // Clear meter
    meter.reset();
    _game!.onMeterChanged();
    _saveHomePlanet();

    _playCosmicSfx(SoundCue.cosmicOrbDeposit);
    _showQuote('Deposited $elemSummary at home!');
    HapticFeedback.mediumImpact();
  }

  /// Called every game tick while near home — heals HP, refuels, and rearms.
  void _tickGradualHeal(double dt) {
    if (_game == null || !_isNearHome) return;

    final needsHeal = _game!.shipHealth < CosmicGame.shipMaxHealth;
    final needsFuel = _customizationState.hasBooster && !_game!.shipFuel.isFull;
    final needsMissiles =
        _customizationState.hasMissiles &&
        _game!.missileAmmo < ShipFuel.maxMissileAmmo;
    final needsSentinels =
        _customizationState.hasOrbitals &&
        _customizationState.hasSentinelStation &&
        (_game!.orbitals.length < OrbitalSentinel.maxActive ||
            _game!.orbitalStockpile < OrbitalSentinel.autoReplenishThreshold);

    if (!needsHeal && !needsFuel && !needsMissiles && !needsSentinels) return;

    _healTimer += dt;
    if (_healTimer >= 1.0) {
      final ticks = _healTimer.floor();
      _healTimer -= ticks;

      // Heal 0.5 HP per second
      if (needsHeal) {
        const healRate = 0.5;
        final healed = ticks * healRate;
        _game!.shipHealth = (_game!.shipHealth + healed).clamp(
          0.0,
          CosmicGame.shipMaxHealth,
        );
      }

      // Refuel ~10 units per second
      if (needsFuel) {
        _game!.shipFuel.add(ticks * 10.0);
        _saveFuelState();
      }

      // Reload ~5 missiles per second
      if (needsMissiles) {
        _game!.missileAmmo = (_game!.missileAmmo + ticks * 5).clamp(
          0,
          ShipFuel.maxMissileAmmo,
        );
        _saveMissileState();
      }

      // Replenish sentinels (~2 per second into stockpile, auto-deploy)
      if (needsSentinels) {
        _game!.orbitalStockpile += ticks * 2;
        if (_game!.orbitalStockpile > OrbitalSentinel.autoReplenishThreshold) {
          _game!.orbitalStockpile = OrbitalSentinel.autoReplenishThreshold;
        }
        // Auto-deploy from stockpile
        while (_game!.orbitals.length < OrbitalSentinel.maxActive &&
            _game!.orbitalStockpile > 0) {
          _game!.orbitalStockpile--;
          final angle = _game!.orbitals.isEmpty
              ? 0.0
              : _game!.orbitals.last.angle +
                    (2 * pi / OrbitalSentinel.maxActive);
          _game!.orbitals.add(OrbitalSentinel(angle: angle));
        }
        _saveOrbitalState();
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _depositWalletAtHome() {
    if (_game == null) return;
    final wallet = _game!.shipWallet;
    if (wallet.shards <= 0) return;
    final shards = wallet.depositAll();
    _homePlanet!.astralBank += shards;
    _saveHomePlanet();
    _showQuote('Deposited $shards Astral Shards at home!');
    setState(() {});
  }

  /// Manual deposit: meter + wallet combined.
  void _handleDepositAll() {
    if (_game == null || _homePlanet == null || !_isNearHome) return;
    final hasMeter = _game!.meter.total > 0;
    final hasShards = _game!.shipWallet.shards > 0;
    if (!hasMeter && !hasShards) {
      _showQuote('Nothing to deposit.');
      return;
    }

    // Collect summary parts before depositing
    final summaryParts = <String>[];
    if (hasMeter) {
      final breakdown = _game!.meter.breakdown;
      for (final e in breakdown.entries) {
        if (e.value > 0) {
          summaryParts.add('${e.value.toStringAsFixed(0)} ${e.key}');
        }
      }
    }
    final shardCount = hasShards ? _game!.shipWallet.shards : 0;

    if (hasMeter) _depositMeterAtHome();
    if (hasShards) _depositWalletAtHome();

    // Show combined summary
    final msg = StringBuffer('Deposited ');
    if (summaryParts.isNotEmpty) {
      msg.write(summaryParts.join(', '));
    }
    if (shardCount > 0) {
      if (summaryParts.isNotEmpty) msg.write(' + ');
      msg.write('$shardCount Astral Shards');
    }
    msg.write('!');
    _showQuote(msg.toString());
    setState(() {});
  }

  Widget _buildShipButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showShipMenu = true;
          if (_awaitingShipMenuTap) {
            _awaitingShipMenuTap = false;
            _awaitingBuildHomeTap = _homePlanet == null;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: _awaitingShipMenuTap
              ? const Color(0xFF00E5FF).withValues(alpha: 0.18)
              : CosmicScreenStyles.bg1,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: _awaitingShipMenuTap
                ? const Color(0xFF00E5FF)
                : const Color(0xFF00E5FF).withValues(alpha: 0.6),
            width: _awaitingShipMenuTap ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF00E5FF,
              ).withValues(alpha: _awaitingShipMenuTap ? 0.45 : 0.18),
              blurRadius: _awaitingShipMenuTap ? 22 : 12,
              spreadRadius: _awaitingShipMenuTap ? 2 : 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          'SHIP',
          style: TextStyle(
            fontFamily: appFontFamily(context),
            color: CosmicScreenStyles.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }

  Widget _buildSlowModeButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _slowMode = !_slowMode);
        _game?.slowMode = _slowMode;
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _slowMode
              ? const Color(0xFFFFB300).withValues(alpha: 0.18)
              : Colors.black45,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _slowMode
                ? const Color(0xFFFFB300).withValues(alpha: 0.8)
                : Colors.white10,
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.slow_motion_video,
            color: _slowMode ? const Color(0xFFFFB300) : Colors.white38,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildCompanionTetherButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _companionTethered = !_companionTethered);
        _game?.companionTethered = _companionTethered;
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _companionTethered
              ? const Color(0xFF42A5F5).withValues(alpha: 0.18)
              : Colors.black45,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _companionTethered
                ? const Color(0xFF42A5F5).withValues(alpha: 0.8)
                : Colors.white10,
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            _companionTethered ? Icons.link : Icons.link_off,
            color: _companionTethered
                ? const Color(0xFF42A5F5)
                : Colors.white38,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildSandboxButton() {
    return GestureDetector(
      onTap: _toggleSandboxPanel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _sandboxMode
              ? const Color(0xFF7CFFB2).withValues(alpha: 0.18)
              : Colors.black45,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _sandboxMode
                ? const Color(0xFF7CFFB2).withValues(alpha: 0.8)
                : Colors.white10,
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.science_rounded,
            color: _sandboxMode ? const Color(0xFF7CFFB2) : Colors.white38,
            size: 20,
          ),
        ),
      ),
    );
  }

  /// Builds a single party-slot button for slot index [i].
  Widget _buildPartySlotButton(int i) {
    final member = i < _partyMembers.length ? _partyMembers[i] : null;
    final isActive = _activeCompanionSlot == i;
    final specialCooldown = isActive
        ? (_game?.activeCompanion?.specialCooldown ??
              (_companionSpecialCooldown[i] ?? 0.0))
        : (_companionSpecialCooldown[i] ?? 0.0);
    final showCooldown = member != null && specialCooldown > 0.05;
    final hpFrac = isActive
        ? (_game?.activeCompanion?.hpPercent ??
              (_companionHpFraction[i] ?? 1.0))
        : (_companionHpFraction[i] ?? 1.0);
    final isDead = member != null && hpFrac <= 0;
    final noStamina = member != null && member.staminaBars < 1;
    // Allow tapping another slot while a companion is active — tapping
    // will auto-recall the current companion and summon the new one.
    final isDisabled = member == null || isDead || noStamina;

    return GestureDetector(
      onTap: isDisabled
          ? ((isDead || noStamina) && _isNearHome
                ? _openPartyPickerFromSlotButton
                : isDead
                ? () => _showQuote(
                    'This Alchemon is exhausted! Return home to heal.',
                  )
                : noStamina
                ? () => _showQuote(
                    'No stamina! Use a potion or wait to regenerate.',
                  )
                : null)
          : isActive
          ? _handleReturnCompanion
          : () => _handleSummonCompanion(i),
      onLongPress: () => _handlePartySlotLongPress(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFE53935).withValues(alpha: 0.18)
              : isDead
              ? const Color(0xFFE53935).withValues(alpha: 0.06)
              : isDisabled
              ? Colors.black45
              : const Color(0xFF00E676).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive
                ? const Color(0xFFE53935).withValues(alpha: 0.8)
                : isDead
                ? const Color(0xFFE53935).withValues(alpha: 0.25)
                : isDisabled
                ? Colors.white10
                : const Color(0xFF00E676).withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: member != null
            ? Opacity(
                opacity: isDisabled ? 0.25 : 1.0,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Creature image as silhouette
                    if (member.imagePath != null)
                      ColorFiltered(
                        colorFilter: isActive
                            ? const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.dst,
                              )
                            : const ColorFilter.matrix(<double>[
                                0,
                                0,
                                0,
                                0,
                                80,
                                0,
                                0,
                                0,
                                0,
                                80,
                                0,
                                0,
                                0,
                                0,
                                80,
                                0,
                                0,
                                0,
                                1,
                                0,
                              ]),
                        child: Image.asset(
                          member.imagePath!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.catching_pokemon,
                            color: isActive
                                ? const Color(0xFFE53935)
                                : const Color(0xFF00E676),
                            size: 20,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.catching_pokemon,
                        color: isActive
                            ? const Color(0xFFE53935)
                            : const Color(0xFF00E676),
                        size: 20,
                      ),
                    // Show actual image when active
                    if (isActive && member.imagePath != null)
                      Image.asset(
                        member.imagePath!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                    // "RET" label when active
                    if (isActive)
                      Positioned(
                        bottom: 1,
                        child: Text(
                          'RET',
                          style: TextStyle(
                            fontFamily: appFontFamily(context),
                            color: const Color(
                              0xFFE53935,
                            ).withValues(alpha: 0.9),
                            fontSize: 6,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    if (showCooldown)
                      Positioned(
                        bottom: -2,
                        left: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isActive
                                  ? const Color(
                                      0xFFE53935,
                                    ).withValues(alpha: 0.8)
                                  : const Color(
                                      0xFF00E676,
                                    ).withValues(alpha: 0.75),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            specialCooldown.ceil().toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    // Dead "X" overlay
                    if (isDead)
                      const Icon(
                        Icons.close_rounded,
                        color: Color(0xFFE53935),
                        size: 28,
                      ),
                    // HP bar (when not full and not dead)
                    if (!isDead && hpFrac < 1.0)
                      Positioned(
                        bottom: 2,
                        left: 4,
                        right: 4,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: hpFrac,
                            child: Container(
                              decoration: BoxDecoration(
                                color: hpFrac > 0.5
                                    ? const Color(0xFF00E676)
                                    : hpFrac > 0.25
                                    ? const Color(0xFFFFAB00)
                                    : const Color(0xFFE53935),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Stamina dots (top of slot)
                    if (!isDead && member.staminaMax > 0)
                      Positioned(
                        top: 2,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            member.staminaMax,
                            (si) => Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: si < member.staminaBars
                                    ? const Color(0xFF00E676)
                                    : Colors.white12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // No stamina overlay
                    if (noStamina && !isDead)
                      Icon(
                        Icons.battery_0_bar_rounded,
                        color: const Color(0xFFFF9800).withValues(alpha: 0.8),
                        size: 18,
                      ),
                  ],
                ),
              )
            : Icon(
                Icons.add_circle_outline,
                color: Colors.white.withValues(alpha: 0.15),
                size: 18,
              ),
      ),
    );
  }

  void _startShooting() {
    _isShooting = true;
    _game?.shooting = true;
    HapticFeedback.selectionClick();
    setState(() {});
  }

  void _stopShooting() {
    _isShooting = false;
    _game?.shooting = false;
    setState(() {});
  }

  void _startShootingMissiles() {
    _isShootingMissiles = true;
    _game?.shootingMissiles = true;
    HapticFeedback.selectionClick();
    setState(() {});
  }

  void _stopShootingMissiles() {
    _isShootingMissiles = false;
    _game?.shootingMissiles = false;
    setState(() {});
  }

  void _startBoosting() {
    if (!_customizationState.hasBooster) return;
    _isBoosting = true;
    _game?.boosting = true;
    HapticFeedback.selectionClick();
    setState(() {});
  }

  void _stopBoosting() {
    _isBoosting = false;
    _game?.boosting = false;
    setState(() {});
  }

  void _toggleBoosting() {
    if (!_customizationState.hasBooster) return;
    if (_isBoosting) {
      _stopBoosting();
    } else {
      _startBoosting();
    }
  }

  /// Determine which weapon slot (0=bullets, 1=missiles) the pointer Y is over.
  /// Returns -1 if outside both.
  /// Column layout: [MISSILE(50)] [gap(10)] [BULLETS(50)] — or just [BULLETS(50)].
  int _weaponSlotAtY(double localY) {
    if (_customizationState.hasMissiles) {
      if (localY >= 0 && localY < 50) return 1; // missiles (top)
      if (localY >= 60 && localY < 110) return 0; // bullets (below)
    } else {
      if (localY >= 0 && localY < 50) return 0; // bullets only
    }
    return -1;
  }

  void _switchToWeaponSlot(int slot) {
    if (slot == _activeWeaponSlot) return;
    // Deactivate previous
    if (_activeWeaponSlot == 0) _stopShooting();
    if (_activeWeaponSlot == 1) _stopShootingMissiles();
    // Activate new
    _activeWeaponSlot = slot;
    if (slot == 0) _startShooting();
    if (slot == 1) _startShootingMissiles();
  }

  // ── Tap-to-shoot pointer handling ──

  void _handleTapShootPointerDown(PointerDownEvent e) {
    // When the joystick handles steering, every tap is a shoot tap.
    if (_showJoystick) {
      _tapShootPointerIds.add(e.pointer);
      if (!_isShooting) _startShooting();
      return;
    }
    if (_movePointerId == null) {
      _movePointerId = e.pointer;
      // Forward initial position to game for steering
      _game?.setDragTargetFromScreen(e.localPosition);
      return;
    }
    _tapShootPointerIds.add(e.pointer);
    if (!_isShooting) _startShooting();
  }

  void _handleTapShootPointerMove(PointerMoveEvent e) {
    // When joystick is active, steering is handled there — nothing to do.
    if (_showJoystick) return;
    // Only forward the move-pointer's drag to steer the ship
    if (e.pointer == _movePointerId) {
      _game?.setDragTargetFromScreen(e.localPosition);
    }
  }

  void _handleTapShootPointerUp(PointerUpEvent e) {
    if (_showJoystick) {
      _tapShootPointerIds.remove(e.pointer);
      if (_tapShootPointerIds.isEmpty && _isShooting) _stopShooting();
      return;
    }
    if (e.pointer == _movePointerId) {
      _movePointerId = null;
      return;
    }
    _tapShootPointerIds.remove(e.pointer);
    if (_tapShootPointerIds.isEmpty && _isShooting) {
      _stopShooting();
    }
  }

  void _handleTapShootPointerCancel(PointerCancelEvent e) {
    if (_showJoystick) {
      _tapShootPointerIds.remove(e.pointer);
      if (_tapShootPointerIds.isEmpty && _isShooting) _stopShooting();
      return;
    }
    if (e.pointer == _movePointerId) {
      _movePointerId = null;
      return;
    }
    _tapShootPointerIds.remove(e.pointer);
    if (_tapShootPointerIds.isEmpty && _isShooting) {
      _stopShooting();
    }
  }

  void _handleWeaponPointerDown(PointerDownEvent e) {
    final box =
        _weaponColumnKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(e.position);
    final slot = _weaponSlotAtY(local.dy);
    if (slot >= 0) _switchToWeaponSlot(slot);
  }

  void _handleWeaponPointerMove(PointerMoveEvent e) {
    if (_activeWeaponSlot < 0) return; // not tracking
    final box =
        _weaponColumnKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(e.position);
    final slot = _weaponSlotAtY(local.dy);
    if (slot >= 0) _switchToWeaponSlot(slot);
  }

  void _handleWeaponPointerUp(PointerUpEvent e) {
    if (_activeWeaponSlot == 0) _stopShooting();
    if (_activeWeaponSlot == 1) _stopShootingMissiles();
    _activeWeaponSlot = -1;
  }

  void _handleWeaponPointerCancel(PointerCancelEvent e) {
    if (_activeWeaponSlot == 0) _stopShooting();
    if (_activeWeaponSlot == 1) _stopShootingMissiles();
    _activeWeaponSlot = -1;
  }

  void _resetCosmicTouchState() {
    _movePointerId = null;
    _tapShootPointerIds.clear();
    _activeWeaponSlot = -1;
    if (_isShooting) _stopShooting();
    if (_isShootingMissiles) _stopShootingMissiles();
    _game?.clearSteeringInput();
  }

  Future<void> _saveCustomizationState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _customizationPrefsKey,
      _customizationState.serialise(),
    );
  }

  /// "Are you sure?" before leaving — warns that unsaved cargo/shards will be lost.
  Future<void> _confirmLeave() async {
    final hasCargo = (_game?.meter.total ?? 0) > 0;
    final hasShards = (_game?.shipWallet.shards ?? 0) > 0;
    final warningItems = <String>[
      if (hasCargo) 'elemental cargo',
      if (hasShards) 'shards',
    ];
    final warningText = warningItems.isEmpty
        ? 'Are you sure you want to leave?'
        : 'Your ${warningItems.join(' & ')} will be lost!\nAre you sure you want to leave?';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final fc = FC.of(ctx);
        final ft = FT(fc);
        return AlertDialog(
          backgroundColor: fc.bg2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: fc.borderDim),
          ),
          title: Text(
            'LEAVE EXPEDITION?',
            style: ft.heading.copyWith(fontSize: 15, color: fc.textPrimary),
          ),
          content: Text(
            warningText,
            style: ft.body.copyWith(color: fc.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Stay',
                style: ft.label.copyWith(color: fc.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: fc.danger,
                foregroundColor: fc.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Leave',
                style: ft.mono.copyWith(color: fc.textPrimary),
              ),
            ),
          ],
        );
      },
    );
    if (result == true && mounted) {
      await _saveFogState();
      if (mounted) VoidPortal.pop(context);
    }
  }

  /// Shows a simple "Are you sure?" confirmation dialog.
  /// Returns true if the user confirmed.
  Future<bool> _showConfirmPurchase({
    required String title,
    required String cost,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final fc = FC.of(ctx);
        final ft = FT(fc);
        return AlertDialog(
          backgroundColor: fc.bg2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: fc.borderDim),
          ),
          title: Text(
            title.toUpperCase(),
            style: ft.heading.copyWith(fontSize: 15, color: fc.textPrimary),
          ),
          content: Text(
            'Cost: $cost',
            style: ft.body.copyWith(color: fc.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: ft.label.copyWith(color: fc.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: fc.success,
                foregroundColor: fc.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Confirm', style: ft.mono.copyWith(color: fc.textPrimary)),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _handleTryRecipe(String recipeId) async {
    // If already unlocked, nothing to confirm
    if (_customizationState.unlockedIds.contains(recipeId)) return;
    final recipe = kHomeRecipes.cast<HomeRecipe?>().firstWhere(
      (r) => r!.id == recipeId,
      orElse: () => null,
    );
    if (recipe == null) return;
    // Check affordability first
    for (final e in recipe.ingredients.entries) {
      if ((_elementStorage.stored[e.key] ?? 0) < e.value) {
        HapticFeedback.lightImpact();
        setState(() {});
        return;
      }
    }
    final confirmed = await _showConfirmPurchase(
      title: 'Unlock ${recipe.name}?',
      cost: _formatCost(recipe.ingredients),
    );
    if (!confirmed || !mounted) return;
    final success = _customizationState.tryUnlock(recipeId, _elementStorage);
    if (success) {
      _saveCustomizationState();
      _saveElementStorage();
      // Update game visuals
      _game?.activeCustomizations = _customizationState.activeIds;
      _game?.activeAmmoId = _customizationState.activeAmmo?.id;
      _game?.activeWeaponId = _customizationState.activeWeapon;
      _game?.hasMissiles = _customizationState.hasMissiles;
      _game?.activeShipSkin = _customizationState.activeShipSkin;
      // If orbitals were just crafted, add to stockpile
      if (recipeId == 'equip_orbitals' && _game != null) {
        _game!.orbitalStockpile += OrbitalSentinel.autoReplenishThreshold;
        // Immediately deploy up to max
        while (_game!.orbitals.length < OrbitalSentinel.maxActive &&
            _game!.orbitalStockpile > 0) {
          _game!.orbitalStockpile--;
          final angle = _game!.orbitals.isEmpty
              ? 0.0
              : _game!.orbitals.last.angle +
                    (2 * pi / OrbitalSentinel.maxActive);
          _game!.orbitals.add(OrbitalSentinel(angle: angle));
        }
        _saveOrbitalState();
      }
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    setState(() {});
  }

  void _handleToggleRecipe(String recipeId) {
    _customizationState.toggle(recipeId);
    _saveCustomizationState();
    _game?.activeCustomizations = _customizationState.activeIds;
    _game?.activeAmmoId = _customizationState.activeAmmo?.id;
    _game?.activeWeaponId = _customizationState.activeWeapon;
    _game?.hasMissiles = _customizationState.hasMissiles;
    _game?.activeShipSkin = _customizationState.activeShipSkin;
    HapticFeedback.selectionClick();
    setState(() {});
  }

  void _handleUpgradePowerUp(String type) {
    if (_homePlanet == null) return;
    final state = _customizationState;

    if (type == 'fuel') {
      final level = state.fuelUpgradeLevel;
      if (level >= HomeCustomizationState.maxFuelUpgradeLevel) return;
      final cost = HomeCustomizationState.fuelUpgradeCosts[level];
      if (_homePlanet!.astralBank < cost) {
        _showQuote('Not enough Astral Shards! Need $cost ✦');
        return;
      }
      _homePlanet!.astralBank -= cost;
      state.fuelUpgradeLevel = (level + 1).clamp(
        0,
        HomeCustomizationState.maxFuelUpgradeLevel,
      );
      final newCap = ShipFuel.capacityForLevel(state.fuelUpgradeLevel);
      _game?.shipFuel.capacity = newCap;
      // Fill fuel to new capacity (free top-off on upgrade)
      _game?.shipFuel.fuel = newCap;
      _saveFuelState();
      _saveCustomizationState();
      _saveHomePlanet();
      _showQuote('Fuel Tank upgraded! Capacity: ${newCap.toInt()}');
      HapticFeedback.mediumImpact();
      setState(() {});
      return;
    }

    final level = type == 'ammo'
        ? state.ammoUpgradeLevel
        : state.missileUpgradeLevel;
    if (level >= HomeCustomizationState.maxUpgradeLevel) return;
    final cost = HomeCustomizationState.upgradeCosts[level];
    if (_homePlanet!.astralBank < cost) {
      _showQuote('Not enough Astral Shards! Need $cost ✦');
      return;
    }
    _homePlanet!.astralBank -= cost;
    if (type == 'ammo') {
      state.ammoUpgradeLevel = (level + 1).clamp(
        0,
        HomeCustomizationState.maxUpgradeLevel,
      );
      _game?.ammoUpgradeLevel = state.ammoUpgradeLevel;
    } else {
      state.missileUpgradeLevel = (level + 1).clamp(
        0,
        HomeCustomizationState.maxUpgradeLevel,
      );
      _game?.missileUpgradeLevel = state.missileUpgradeLevel;
    }
    _saveCustomizationState();
    _saveHomePlanet();
    final label = type == 'ammo' ? 'Ammo' : 'Missile';
    final newLvl = type == 'ammo'
        ? state.ammoUpgradeLevel
        : state.missileUpgradeLevel;
    _showQuote('$label Power upgraded to Lv$newLvl!');
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  void _handleOptionChanged(String recipeId, String paramKey, String value) {
    _customizationState.setOption(recipeId, paramKey, value);
    _saveCustomizationState();
    _game?.customizationOptions = _customizationState.options;
    setState(() {});
  }

  Future<void> _handleUpgradePlanetSize() async {
    if (_homePlanet == null) return;
    final cost = _homePlanet!.nextTierCost;
    if (cost == null) return; // already max
    if (_homePlanet!.astralBank < cost) {
      _showQuote('Not enough Astral Shards! Need $cost ✦');
      return;
    }
    final confirmed = await _showConfirmPurchase(
      title: 'Upgrade planet size?',
      cost: '$cost ✦ Astral Shards',
    );
    if (!confirmed || !mounted) return;
    _homePlanet!.astralBank -= cost;
    _homePlanet!.sizeTierLevel = (_homePlanet!.sizeTierLevel + 1).clamp(0, 4);
    _homePlanet!.activeSizeTier = _homePlanet!.sizeTierLevel;
    _saveHomePlanet();
    _showQuote('Unlocked ${_homePlanet!.sizeTier} size!');
    setState(() {});
  }

  void _handleSelectPlanetSize(int tier) async {
    if (_homePlanet == null) return;
    if (tier > _homePlanet!.sizeTierLevel) return;
    final oldSlots = _garrisonSlots;
    _homePlanet!.activeSizeTier = tier;
    _saveHomePlanet();
    final newSlots = _garrisonSlots;
    // Clear garrison slots that exceed the new tier's capacity
    if (newSlots < oldSlots) {
      final db = context.read<AlchemonsDatabase>();
      for (var i = newSlots; i < oldSlots; i++) {
        await db.settingsDao.setCosmicGarrisonSlotInstance(i, null);
      }
      await _initGarrison();
    }
    setState(() {});
  }

  Future<void> _handleUnlockColor(String element) async {
    if (_homePlanet == null) return;
    const cost = HomePlanet.colorUnlockCost;
    final have = (_elementStorage.stored[element] ?? 0);
    if (have < cost) {
      _showQuote('Need $cost $element elements! (have ${have.floor()})');
      return;
    }
    final confirmed = await _showConfirmPurchase(
      title: 'Unlock $element Color?',
      cost: '$cost $element',
    );
    if (!confirmed || !mounted) return;
    _elementStorage.stored[element] = have - cost;
    _saveElementStorage();
    _homePlanet!.unlockedColors.add(element);
    _homePlanet!.activeColor = element;
    _saveHomePlanet();
    _showQuote('Unlocked $element color!');
    setState(() {});
  }

  void _handleSelectColor(String? element) {
    if (_homePlanet == null) return;
    if (element != null && !_homePlanet!.unlockedColors.contains(element)) {
      return;
    }
    _homePlanet!.activeColor = element;
    _saveHomePlanet();
    setState(() {});
  }

  String get _activeWeaponName {
    final w = _customizationState.activeWeapon;
    return switch (w) {
      'equip_machinegun' => 'PULSE REPEATER',
      _ => 'STANDARD GUN',
    };
  }

  /// How many units of [item] we can afford given [cost] per unit.
  int _maxAffordable(Map<String, int> cost) {
    int result = 999;
    for (final e in cost.entries) {
      final have = (_elementStorage.stored[e.key] ?? 0).floor();
      result = min(result, have ~/ e.value);
    }
    return result;
  }

  /// Deduct [count] × [cost] from element storage.
  void _spendElements(Map<String, int> cost, int count) {
    for (final e in cost.entries) {
      _elementStorage.stored[e.key] =
          (_elementStorage.stored[e.key] ?? 0) - e.value * count;
    }
    _elementStorage.stored.removeWhere((_, v) => v <= 0.01);
  }

  Future<void> _handleRefuel() async {
    if (_game == null) return;
    if (!_isNearHome) {
      _showQuote('Return to your home planet to refuel!');
      return;
    }
    if (!_customizationState.hasBooster) {
      _showQuote('You need the Ion Booster first!');
      return;
    }
    final fuel = _game!.shipFuel;
    if (fuel.isFull) {
      _showQuote('Fuel tank is full!');
      return;
    }
    final cost = ShipFuel.fuelCost;
    final canAfford = _maxAffordable(cost);
    if (canAfford <= 0) {
      _showQuote('Need ${_formatCost(cost)} per fuel unit!');
      return;
    }
    final fuelNeeded = (fuel.capacity - fuel.fuel).ceil();
    final toCraft = min(canAfford, fuelNeeded);
    final confirmed = await _showConfirmPurchase(
      title: 'Refuel $toCraft units?',
      cost: _formatCost(cost.map((k, v) => MapEntry(k, v * toCraft))),
    );
    if (!confirmed || !mounted) return;
    _spendElements(cost, toCraft);
    fuel.add(toCraft.toDouble());
    _saveElementStorage();
    _saveFuelState();
    _showQuote('Refined $toCraft fuel.');
    HapticFeedback.mediumImpact();
  }

  void handleFreeRefuel() {
    if (_game == null || !_isNearHome) return;
    if (!_customizationState.hasBooster) {
      _showQuote('You need the Ion Booster first!');
      return;
    }
    final fuel = _game!.shipFuel;
    if (fuel.isFull) {
      _showQuote('Fuel tank is full!');
      return;
    }
    final fuelNeeded = fuel.capacity - fuel.fuel;
    fuel.add(fuelNeeded);
    _saveFuelState();
    _showQuote('Refuel station filled your tank!');
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  void handleFreeMissiles() {
    if (_game == null || !_isNearHome) return;
    if (!_customizationState.hasMissiles) {
      _showQuote('You need the Seeker Missiles first!');
      return;
    }
    final ammo = _game!.missileAmmo;
    if (ammo >= ShipFuel.maxMissileAmmo) {
      _showQuote('Missile bay is full! (${ShipFuel.maxMissileAmmo})');
      return;
    }
    _game!.missileAmmo = ShipFuel.maxMissileAmmo;
    _saveMissileState();
    _showQuote('Missile station fully loaded!');
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  Future<void> _handleCraftMissiles() async {
    if (_game == null) return;
    if (!_isNearHome) {
      _showQuote('Return to your home planet to craft missiles!');
      return;
    }
    if (!_customizationState.hasMissiles) {
      _showQuote('You need the Seeker Missiles first!');
      return;
    }
    final ammo = _game!.missileAmmo;
    if (ammo >= ShipFuel.maxMissileAmmo) {
      _showQuote('Missile bay is full! (${ShipFuel.maxMissileAmmo})');
      return;
    }
    final cost = ShipFuel.missileCost;
    final canAfford = _maxAffordable(cost);
    if (canAfford <= 0) {
      _showQuote('Need ${_formatCost(cost)} per missile!');
      return;
    }
    final missilesNeeded = ShipFuel.maxMissileAmmo - ammo;
    final toCraft = min(canAfford, missilesNeeded);
    final confirmed = await _showConfirmPurchase(
      title: 'Craft $toCraft missiles?',
      cost: _formatCost(cost.map((k, v) => MapEntry(k, v * toCraft))),
    );
    if (!confirmed || !mounted) return;
    _spendElements(cost, toCraft);
    _game!.missileAmmo = (ammo + toCraft).clamp(0, ShipFuel.maxMissileAmmo);
    _saveElementStorage();
    _saveMissileState();
    _showQuote('Crafted $toCraft missiles.');
    HapticFeedback.mediumImpact();
  }

  Future<void> _handleCraftSentinels() async {
    if (_game == null) return;
    if (!_isNearHome) {
      _showQuote('Return to your home planet to craft sentinels!');
      return;
    }
    if (!_customizationState.hasOrbitals) {
      _showQuote('You need Orbital Sentinels first!');
      return;
    }
    final cost = OrbitalSentinel.sentinelCost;
    final canAfford = _maxAffordable(cost);
    if (canAfford <= 0) {
      _showQuote('Need ${_formatCost(cost)} per sentinel!');
      return;
    }
    final toCraft = min(canAfford, 10); // up to 10 at a time
    final confirmed = await _showConfirmPurchase(
      title: 'Build $toCraft sentinels?',
      cost: _formatCost(cost.map((k, v) => MapEntry(k, v * toCraft))),
    );
    if (!confirmed || !mounted) return;
    _spendElements(cost, toCraft);
    _game!.orbitalStockpile += toCraft;
    // Immediately deploy if slots are free
    while (_game!.orbitals.length < OrbitalSentinel.maxActive &&
        _game!.orbitalStockpile > 0) {
      _game!.orbitalStockpile--;
      final angle = _game!.orbitals.isEmpty
          ? 0.0
          : _game!.orbitals.last.angle + (2 * pi / OrbitalSentinel.maxActive);
      _game!.orbitals.add(OrbitalSentinel(angle: angle));
    }
    _saveElementStorage();
    _saveOrbitalState();
    _showQuote('Built $toCraft sentinels.');
    HapticFeedback.mediumImpact();
  }

  /// Format a cost map for display, e.g. "8 Fire + 2 Crystal".
  static String _formatCost(Map<String, int> cost) {
    return cost.entries.map((e) => '${e.value} ${e.key}').join(' + ');
  }

  Future<void> _handleUpgradeCargo() async {
    if (!_isNearHome) {
      _showQuote('Return to your home planet to upgrade cargo!');
      return;
    }
    if (_cargoLevel >= CargoUpgrade.maxLevel) {
      _showQuote('Cargo is fully upgraded!');
      return;
    }
    final cost = CargoUpgrade.costForNextLevel(_cargoLevel);
    // Check can afford
    for (final e in cost.entries) {
      if ((_elementStorage.stored[e.key] ?? 0) < e.value) {
        _showQuote('Not enough elements!');
        HapticFeedback.lightImpact();
        return;
      }
    }
    final confirmed = await _showConfirmPurchase(
      title: 'Upgrade cargo hold?',
      cost: _formatCost(cost),
    );
    if (!confirmed || !mounted) return;
    // Deduct cost
    for (final e in cost.entries) {
      _elementStorage.stored[e.key] =
          (_elementStorage.stored[e.key] ?? 0) - e.value;
    }
    _elementStorage.stored.removeWhere((_, v) => v <= 0.01);
    _cargoLevel++;
    _saveElementStorage();
    _saveCargoLevel();
    _showQuote(
      'Upgraded to ${CargoUpgrade.nameForLevel(_cargoLevel)}! Teleport with ${(CargoUpgrade.capacityForLevel(_cargoLevel) * 100).round()}% meter.',
    );
    HapticFeedback.heavyImpact();
    setState(() {});
  }

  Future<void> _saveCargoLevel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cosmic_cargo_level', _cargoLevel);
  }

  Future<void> _saveMissileState() async {
    if (_game == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cosmic_missile_ammo', _game!.missileAmmo);
  }

  Future<void> _saveFuelState() async {
    if (_game == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cosmic_ship_fuel', _game!.shipFuel.serialise());
  }

  Future<void> _saveOrbitalState() async {
    if (_game == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cosmic_orbital_stockpile', _game!.orbitalStockpile);
  }

  PlanetRecipe _getRecipeForPlanet(CosmicPlanet planet) {
    final level = _recipeState.activeLevelFor(planet.element, seed: _worldSeed);
    return PlanetRecipe.generate(
      element: planet.element,
      seed: _worldSeed,
      level: level,
    );
  }

  List<String> _rarityPoolForRecipeLevel(int level) {
    return switch (level.clamp(1, 3)) {
      1 => const ['Common', 'Uncommon'],
      2 => const ['Uncommon', 'Rare'],
      _ => const ['Rare'],
    };
  }

  ({String sceneId, SceneDefinition scene}) _sceneForElement(String element) {
    // Cosmic planet encounters are fully decoupled from wilderness scene defs.
    // Use a single neutral scene layout and drive visuals via cosmic biomes.
    return (sceneId: 'cosmic_planet', scene: poisonScene);
  }

  List<PartyMember> _buildCosmicEncounterParty() {
    final members = <PartyMember>[];
    final seen = <String>{};
    for (final m in _partyMembers) {
      if (m == null) continue;
      if (!seen.add(m.instanceId)) continue;
      members.add(PartyMember(instanceId: m.instanceId));
    }
    return members;
  }

  Future<void> _enterPlanetForElement(String element) async {
    final game = _game;
    game?.pauseEngine();
    final prefs = await SharedPreferences.getInstance();
    final introSeen = prefs.getBool(_planetPathwayIntroSeenKey) ?? false;
    final shouldShowIntro = !introSeen;

    final target = _sceneForElement(element);
    final party = _buildCosmicEncounterParty();
    final approachColor = _nearPlanet?.color ?? elementColor(element);
    try {
      if (shouldShowIntro) {
        if (!mounted) return;
        await LandscapeDialog.show(
          context,
          title: 'Beauty Obstructs Reality',
          message: '',
          typewriter: true,
          kind: LandscapeDialogKind.info,
          showIcon: false,
          primaryLabel: 'Continue',
        );
      }

      if (!mounted) return;
      await Navigator.of(context).push<void>(
        PageRouteBuilder(
          opaque: false,
          barrierDismissible: false,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, __, ___) =>
              _PlanetApproachTransitionPage(color: approachColor),
        ),
      );

      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      if (shouldShowIntro) {
        if (!mounted) return;
        await Navigator.of(context).push<bool>(
          PageRouteBuilder(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) => _PlanetPathwayDisintegrationPage(
              targetScene: target.scene,
              showDreamDialog: true,
            ),
          ),
        );

        if (!introSeen) {
          await prefs.setBool(_planetPathwayIntroSeenKey, true);
        }
      }

      if (!mounted) return;
      await Navigator.of(context).push<bool>(
        PageRouteBuilder(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, __, ___) => ScenePage(
            scene: target.scene,
            sceneId: target.sceneId,
            party: party,
            isCosmicPlanetEntry: true,
            cosmicElementName: element,
            showCosmicDesolationPopup: shouldShowIntro,
          ),
        ),
      );
    } finally {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      if (mounted) {
        game?.resumeEngine();
      }
    }
  }

  Future<bool> _applyRecipeSuccessProgress(String element, int level) async {
    final firstTimeLevelClear = !_recipeState.isLevelCompleted(element, level);
    final rng = Random();
    _recipeState = _recipeState.onRecipeSuccess(element, level, rng: rng);
    await _saveRecipeState();

    final pathwayUnlocked =
        firstTimeLevelClear &&
        level == 3 &&
        _recipeState.isMaxMastered(element);

    if (pathwayUnlocked && mounted) {
      await LandscapeDialog.show(
        context,
        title: 'Elemental pathway discovered.',
        message:
            'A new route has opened. Recipes now reveal how to enter the planet.',
        typewriter: true,
        kind: LandscapeDialogKind.success,
        icon: Icons.auto_awesome,
        primaryLabel: 'Enter',
      );
    }

    if (!firstTimeLevelClear) return pathwayUnlocked;

    final rewardAmount = switch (level.clamp(1, 3)) {
      1 => 100.0,
      2 => 200.0,
      _ => 300.0,
    };

    _elementStorage.addAll({element: rewardAmount});
    await _saveElementStorage();

    if (_homePlanet != null) {
      _homePlanet!.colorMix[element] =
          (_homePlanet!.colorMix[element] ?? 0) + rewardAmount;
      await _saveHomePlanet();
    }

    if (mounted) {
      _showQuote(
        '${planetName(element)} recipe Lv.$level cleared: +${rewardAmount.toStringAsFixed(0)} $element deposited!',
      );
    }

    return pathwayUnlocked;
  }

  Future<void> _saveRecipeState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cosmic_recipe_state', _recipeState.serialise());
  }

  Future<void> _saveElementStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'cosmic_element_storage',
      _elementStorage.serialise(),
    );
  }

  Future<bool?> _openSummonEncounter({
    required String speciesId,
    required String rarity,
    required String elementName,
  }) async {
    final game = _game;
    game?.pauseEngine();
    try {
      return await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CosmicSummonScreen(
            speciesId: speciesId,
            rarity: rarity,
            elementName: elementName,
            portalColor: elementColor(elementName),
          ),
        ),
      );
    } finally {
      if (mounted) game?.resumeEngine();
    }
  }

  void _triggerScreenShakeAndSummon() {
    _screenShakeCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _handleRecipeSummon();
    });
  }

  void _handleRecipeSummon() async {
    if (_game == null || _nearPlanet == null) return;

    final planet = _nearPlanet!;
    final recipe = _getRecipeForPlanet(planet);
    final targetElement = planet.element;
    final pathwayUnlocked = _recipeState.isMaxMastered(targetElement);

    if (pathwayUnlocked) {
      await _enterPlanetForElement(targetElement);
      return;
    }

    if (recipe.matches(_game!.meter.breakdown, _game!.meter.total)) {
      // ── SUCCESS: either summon creature OR enter planet pathway ──
      final recipeLevel = recipe.level;
      final sceneKey = ElementMeter.sceneKeyForElement(targetElement);

      // Block arcane if not unlocked
      if (sceneKey == 'arcane' && !_arcaneUnlocked) {
        _handleElementsCaptured();
        return;
      }
      _playCosmicSfx(SoundCue.cosmicStarforgeActivate);

      if (pathwayUnlocked) {
        await _applyRecipeSuccessProgress(targetElement, recipeLevel);
        _game?.meter.reset();
        _meterPulse.stop();
        _meterPulse.value = 0;
        await _enterPlanetForElement(targetElement);
      } else {
        final catalog = context.read<CreatureCatalog>();
        final creatures = catalog.byType(targetElement);
        if (creatures.isEmpty) return;

        final rng = Random();
        final rarityPool = _rarityPoolForRecipeLevel(recipeLevel);
        final targetRarity = rarityPool[rng.nextInt(rarityPool.length)];

        var candidates = creatures
            .where((c) => c.rarity == targetRarity)
            .toList();
        if (candidates.isEmpty) {
          candidates = creatures
              .where((c) => rarityPool.contains(c.rarity))
              .toList();
        }
        if (candidates.isEmpty) candidates = creatures;
        // Exclude Mystics
        candidates = candidates
            .where((c) => c.mutationFamily != 'Mystic')
            .toList();
        if (candidates.isEmpty) candidates = creatures;

        final chosen = candidates[rng.nextInt(candidates.length)];

        await _applyRecipeSuccessProgress(targetElement, recipeLevel);

        // Reset meter
        _game?.meter.reset();
        _meterPulse.stop();
        _meterPulse.value = 0;

        final success = await _openSummonEncounter(
          speciesId: chosen.id,
          rarity: chosen.rarity,
          elementName: targetElement,
        );

        if (success == true && mounted) {
          _showQuote('${chosen.name} captured!');
        }
      }
    } else {
      // ── FAIL: recipe mismatch — particles lost ──
      _handleElementsCaptured();
    }
  }

  void _handleElementsCaptured() {
    final breakdown = Map<String, double>.from(_game!.meter.breakdown);

    // Particles are destroyed (not stored)

    // Reset meter
    _game!.meter.reset();
    _meterPulse.stop();
    _meterPulse.value = 0;

    _game?.pauseEngine();

    setState(() {
      _capturedBreakdown = breakdown;
      _showElementsCaptured = true;
    });
  }

  void _handleCompleteSummon() async {
    if (_summonResult == null) return;

    final result = _summonResult!;
    final recipeLevel = _recipeState.activeLevelFor(
      result.resolvedElement,
      seed: _worldSeed,
    );
    await _applyRecipeSuccessProgress(result.resolvedElement, recipeLevel);

    // Reset meter for next summon
    _game?.meter.reset();
    _meterPulse.stop();
    _meterPulse.value = 0;

    // Dismiss the summon popup
    setState(() => _summonResult = null);

    final success = await _openSummonEncounter(
      speciesId: result.speciesId,
      rarity: result.rarity,
      elementName: result.resolvedElement,
    );

    if (success == true && mounted) {
      _showQuote('${result.speciesName} captured!');
    }
  }

  void _handleReset() {
    _game?.meter.reset();
    _meterPulse.stop();
    _meterPulse.value = 0;
    setState(() {
      _summonResult = null;
    });
  }

  void _handleMeterTap() {
    if (_game == null) return;
    final meter = _game!.meter;
    if (meter.total <= 0) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MeterBreakdownSheet(
        meter: meter,
        onRemove: (element) {
          meter.removeElement(element);
          setState(() {});
        },
      ),
    );
  }

  @override
  void dispose() {
    try {
      unawaited(context.read<AudioController>().playHomeMusic());
    } catch (_) {}
    _companionCooldownUiTimer?.cancel();
    _meterPulse.dispose();
    _quoteFade.dispose();
    _miniMapCtrl.dispose();
    _planetMeterCtrl.dispose();
    _bloodRitualCtrl.dispose();
    _screenShakeCtrl.dispose();
    // Auto-save fog on exit
    _saveFogState();
    _saveBloodRingState();
    super.dispose();
  }

  void _toggleMiniMap() {
    if (!_showMiniMap) {
      _game?.pauseEngine();
      setState(() => _showMiniMap = true);
      _miniMapCtrl.forward(from: 0.0);
    } else {
      _miniMapCtrl.reverse().then((_) {
        if (!mounted) return;
        _game?.resumeEngine();
        setState(() => _showMiniMap = false);
      });
    }
  }

  void _closeMiniMap() {
    if (!_showMiniMap && !_miniMapCtrl.isAnimating) return;
    _miniMapCtrl.reverse().then((_) {
      if (!mounted) return;
      _game?.resumeEngine();
      setState(() => _showMiniMap = false);
    });
  }

  bool _dismissVisibleOverlayOrPopup() {
    if (_showBloodRitualOverlay || _runningBloodEnding) {
      return true;
    }
    if (_game?.beautyContestCinematicActive ?? false) {
      return true;
    }
    if (_showSettingsMenu) {
      setState(() => _showSettingsMenu = false);
      return true;
    }
    if (_showSandboxPanel) {
      setState(() => _showSandboxPanel = false);
      return true;
    }
    if (_showShipMenu) {
      if (_awaitingBuildHomeTap && _homePlanet == null) {
        return true;
      }
      setState(() => _showShipMenu = false);
      return true;
    }
    if (_showGarrisonPicker) {
      setState(() => _showGarrisonPicker = false);
      return true;
    }
    if (_showPartyPicker) {
      setState(() => _showPartyPicker = false);
      return true;
    }
    if (_showChamberPicker) {
      setState(() => _showChamberPicker = false);
      return true;
    }
    if (_showCustomizationMenu) {
      setState(() => _showCustomizationMenu = false);
      return true;
    }
    if (_showHomeMenu) {
      setState(() => _showHomeMenu = false);
      return true;
    }
    if (_showElementsCaptured) {
      setState(() => _showElementsCaptured = false);
      return true;
    }
    if (_summonResult != null) {
      _handleReset();
      return true;
    }
    if (_showMiniMap || _miniMapCtrl.isAnimating) {
      _closeMiniMap();
      return true;
    }
    if (_activeQuote != null) {
      _quoteFade.stop();
      setState(() => _activeQuote = null);
      return true;
    }
    return false;
  }

  void _togglePinnedMiniMap() {
    setState(() => _showPinnedMiniMap = !_showPinnedMiniMap);
    HapticFeedback.selectionClick();
    _showQuote(
      _showPinnedMiniMap
          ? 'Mini-map pinned. Long-press map icon to hide.'
          : 'Mini-map hidden.',
    );
  }

  CosmicPlanet? _planetForElement(String element) {
    for (final p in _world.planets) {
      if (p.element == element) return p;
    }
    return null;
  }

  Future<void> _togglePinnedRecipe(CosmicPlanet planet) async {
    final next = _pinnedRecipeElement == planet.element ? null : planet.element;
    final prefs = await SharedPreferences.getInstance();
    if (next == null) {
      await prefs.remove(_pinnedRecipePrefsKey);
    } else {
      await prefs.setString(_pinnedRecipePrefsKey, next);
    }
    if (!mounted) return;
    setState(() => _pinnedRecipeElement = next);
    HapticFeedback.selectionClick();
    _showQuote(next == null ? 'Recipe unpinned.' : 'Recipe pinned.');
  }

  Widget _buildPinnedRecipeMeter({
    required CosmicPlanet planet,
    required PlanetRecipe recipe,
    required VoidCallback onTogglePin,
  }) {
    final entries = recipe.components.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final usedPct = entries.fold<double>(0.0, (sum, e) => sum + e.value);
    final randomPct = (100.0 - usedPct).clamp(0.0, 100.0);

    return GestureDetector(
      onTap: onTogglePin,
      child: Container(
        height: 22,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.06),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: planet.color.withValues(alpha: 0.22),
            width: 0.9,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            children: [
              Row(
                children: [
                  for (final e in entries)
                    Expanded(
                      flex: (e.value * 10).round().clamp(1, 1000),
                      child: Container(color: elementColor(e.key)),
                    ),
                  if (randomPct > 0)
                    Expanded(
                      flex: (randomPct * 10).round().clamp(1, 1000),
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                ],
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.26),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  'PINNED ${planetName(planet.element).toUpperCase()} RECIPE',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 6),
                      Shadow(color: Colors.black, blurRadius: 3),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 6,
                top: 3,
                child: Icon(
                  Icons.push_pin,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();

    // Show loading while game initialises
    if (_game == null || _recipes == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF020010),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: theme.accent),
              const SizedBox(height: 16),
              Text(
                'ENTERING THE COSMOS...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pinnedPlanet = _pinnedRecipeElement != null
        ? _planetForElement(_pinnedRecipeElement!)
        : null;
    final hasPinnedRecipe = pinnedPlanet != null;
    final showingPinnedOnly = hasPinnedRecipe && _nearPlanet == null;
    final hudPlanet = hasPinnedRecipe ? pinnedPlanet : _nearPlanet;
    final hudPathwayUnlocked = hudPlanet != null
        ? _recipeState.isMaxMastered(hudPlanet.element)
        : false;
    final hudCanAct =
        _nearPlanet != null && (hudPathwayUnlocked || _game!.meter.isFull);
    final baseMapColumnTop =
        120.0 + (_nearPlanet != null && !_isNearHome ? 240.0 : 0.0);
    final mapColumnTop = (_topHudCollapsed ? 0.0 : baseMapColumnTop)
        .clamp(0.0, 400.0)
        .toDouble();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_dismissVisibleOverlayOrPopup()) return;
        await _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF020010),
        body: AnimatedBuilder(
          animation: _screenShakeAnim,
          builder: (context, child) => Transform.translate(
            offset: Offset(_screenShakeAnim.value, 0),
            child: child,
          ),
          child: Stack(
            children: [
              // ── Flame game canvas ──
              Positioned.fill(child: GameWidget(game: _game!)),

              // ── Tap-to-shoot full-screen listener ──
              if (_tapToShoot &&
                  !_anyOverlayOpen &&
                  _summonResult == null &&
                  !_showMiniMap)
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _handleTapShootPointerDown,
                    onPointerMove: _handleTapShootPointerMove,
                    onPointerUp: _handleTapShootPointerUp,
                    onPointerCancel: _handleTapShootPointerCancel,
                  ),
                ),

              // ── Map button (hidden when pinned mini-map is active) ──
              if (_summonResult == null &&
                  !_anyOverlayOpen &&
                  !_showPinnedMiniMap &&
                  !_awaitingShipMenuTap)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  top: mapColumnTop,
                  left: 12,
                  child: SafeArea(
                    child: GestureDetector(
                      onTap: _toggleMiniMap,
                      onLongPress: _togglePinnedMiniMap,
                      child: AnimatedBuilder(
                        animation: _miniMapCtrl,
                        builder: (context, child) {
                          final t = Curves.easeOutCubic.transform(
                            _miniMapCtrl.value,
                          );
                          final rot = (pi / 12) * t; // small tilt when open
                          final scale = 1.0 + 0.08 * t;
                          return Transform.rotate(
                            angle: rot,
                            child: Transform.scale(scale: scale, child: child),
                          );
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _showPinnedMiniMap
                                  ? const Color(0xFFFFB300)
                                  : Colors.white24,
                              width: _showPinnedMiniMap ? 1.5 : 1,
                            ),
                          ),
                          child: Icon(
                            Icons.map_rounded,
                            color: _showPinnedMiniMap
                                ? const Color(0xFFFFB300)
                                : Colors.white60,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Pinned mini-map replaces the map icon slot ──
              if (_showPinnedMiniMap &&
                  _summonResult == null &&
                  !_showMiniMap &&
                  !_anyOverlayOpen)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  top: mapColumnTop,
                  left: 12,
                  child: SafeArea(
                    child: CosmicMiniMapCircle(
                      world: _world,
                      game: _game!,
                      onTap: _toggleMiniMap,
                      onLongPress: _togglePinnedMiniMap,
                    ),
                  ),
                ),

              // ── Space Market Hub ──
              if (_nearMarketPOI != null &&
                  _nearPlanet == null &&
                  !_isNearHome &&
                  _summonResult == null &&
                  !_showElementsCaptured &&
                  !_showMiniMap &&
                  !_anyOverlayOpen)
                Builder(
                  builder: (_) {
                    final mType = _nearMarketPOI!.type;
                    final mColor = mType == POIType.harvesterMarket
                        ? const Color(0xFFFFB300)
                        : mType == POIType.riftKeyMarket
                        ? const Color(0xFF7C4DFF)
                        : mType == POIType.cosmicMarket
                        ? const Color(0xFF00E5FF)
                        : mType == POIType.stardustScanner
                        ? const Color(0xFF9CCC65)
                        : mType == POIType.goldConversion
                        ? const Color(0xFFFFD740)
                        : mType == POIType.survivalPortal
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF64B5F6);
                    final mLabel = mType == POIType.harvesterMarket
                        ? 'HARVESTER SHOP'
                        : mType == POIType.riftKeyMarket
                        ? 'RIFT KEY SHOP'
                        : mType == POIType.cosmicMarket
                        ? 'COSMIC MARKET'
                        : mType == POIType.stardustScanner
                        ? 'STAR DUST SCANNER'
                        : mType == POIType.goldConversion
                        ? 'GOLD CONVERSION'
                        : mType == POIType.survivalPortal
                        ? 'SURVIVAL PORTAL'
                        : 'PLANET SCANNER';
                    final scannerTrackingActive =
                        _game?.starDustScannerTargetIndex != null;
                    final planetTrackingActive =
                        _game?.planetScannerTargetIndex != null;
                    return Positioned(
                      bottom: 100,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _openMarketShop,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: CosmicScreenStyles.bg1,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: mColor.withValues(alpha: 0.7),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: mColor.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  mLabel,
                                  style: TextStyle(
                                    color: mColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: mColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: mColor.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    mType == POIType.cosmicMarket
                                        ? 'SELL ALCHEMONS'
                                        : mType == POIType.goldConversion
                                        ? 'CONVERT GOLD'
                                        : mType == POIType.stardustScanner
                                        ? (scannerTrackingActive
                                              ? 'TRACKING ACTIVE'
                                              : 'SCAN FOR $_starDustScanCost SHARDS')
                                        : mType == POIType.planetScanner
                                        ? (planetTrackingActive
                                              ? 'TRACKING ACTIVE'
                                              : 'SCAN FOR $_planetScanCost SHARDS')
                                        : mType == POIType.survivalPortal
                                        ? 'ENTER SURVIVAL PORTAL'
                                        : 'ENTER SHOP',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // ── Virtual joystick (bottom-left) ──
              if (_showJoystick &&
                  _summonResult == null &&
                  !_showMiniMap &&
                  !_anyOverlayOpen)
                Positioned(
                  bottom: 20,
                  left: 12,
                  child: SafeArea(
                    child: VirtualJoystick(
                      sizeMultiplier: _largeJoystick ? 1.35 : 1.0,
                      onDirectionChanged: (dir) {
                        _game?.joystickDirection = dir;
                      },
                    ),
                  ),
                ),

              // ── Planet recipe HUD (moved to top safe-area, compact)
              if (hudPlanet != null &&
                  !_isNearHome &&
                  _summonResult == null &&
                  !_showElementsCaptured &&
                  !_showMiniMap &&
                  !_anyOverlayOpen)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  top: 74,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated alchemical meter above the planet HUD
                        if (!showingPinnedOnly) ...[
                          AnimatedBuilder(
                            animation: _planetMeterCtrl,
                            builder: (context, child) {
                              final t = Curves.easeOut.transform(
                                _planetMeterCtrl.value,
                              );
                              return Opacity(
                                opacity: t.clamp(0.0, 1.0),
                                child: Transform.translate(
                                  offset: Offset(0, (1 - t) * 8),
                                  child: child,
                                ),
                              );
                            },
                            child: GestureDetector(
                              onTap: _handleMeterTap,
                              child: AnimatedBuilder(
                                animation: _meterPulse,
                                builder: (context, child) {
                                  final meter = _game!.meter;
                                  final glow = meter.isFull
                                      ? _meterPulse.value * 0.4
                                      : 0.0;
                                  return Container(
                                    height: 24,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withValues(alpha: 0.07),
                                          Colors.white.withValues(alpha: 0.02),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: meter.isFull
                                            ? Colors.amberAccent.withValues(
                                                alpha: 0.4 + glow,
                                              )
                                            : Colors.white.withValues(
                                                alpha: 0.06,
                                              ),
                                        width: meter.isFull ? 1.0 : 0.5,
                                      ),
                                      boxShadow: meter.isFull
                                          ? [
                                              BoxShadow(
                                                color: Colors.amberAccent
                                                    .withValues(
                                                      alpha: 0.12 + glow * 0.2,
                                                    ),
                                                blurRadius: 14,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: child,
                                    ),
                                  );
                                },
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final meter = _game!.meter;
                                    final breakdown = meter.breakdown;
                                    final total = meter.total;
                                    if (total <= 0) {
                                      return Container(
                                        alignment: Alignment.center,
                                        child: Text(
                                          'ALCHEMICAL METER',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.18,
                                            ),
                                            fontSize: 8,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      );
                                    }

                                    final sorted = breakdown.entries.toList()
                                      ..sort(
                                        (a, b) => b.value.compareTo(a.value),
                                      );

                                    return Stack(
                                      children: [
                                        Row(
                                          children: sorted.map((e) {
                                            final pct =
                                                e.value /
                                                ElementMeter.maxCapacity;
                                            return Expanded(
                                              flex: (pct * 1000).round().clamp(
                                                1,
                                                1000,
                                              ),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Color.lerp(
                                                        elementColor(e.key),
                                                        Colors.white,
                                                        0.2,
                                                      )!,
                                                      elementColor(e.key),
                                                      Color.lerp(
                                                        elementColor(e.key),
                                                        Colors.black,
                                                        0.25,
                                                      )!,
                                                    ],
                                                    stops: const [
                                                      0.0,
                                                      0.4,
                                                      1.0,
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                        Positioned(
                                          top: 0,
                                          left: 0,
                                          right: 0,
                                          height: 7,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.white.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.0,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: Text(
                                            meter.isFull
                                                ? 'METER FULL — FLY TO A PLANET'
                                                : '${(meter.fillPct * 100).toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.9,
                                              ),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                              shadows: const [
                                                Shadow(
                                                  color: Colors.black,
                                                  blurRadius: 6,
                                                ),
                                                Shadow(
                                                  color: Colors.black,
                                                  blurRadius: 3,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (hasPinnedRecipe)
                          _buildPinnedRecipeMeter(
                            planet: hudPlanet,
                            recipe: _getRecipeForPlanet(hudPlanet),
                            onTogglePin: () => _togglePinnedRecipe(hudPlanet),
                          )
                        else
                          PlanetRecipeHud(
                            planet: hudPlanet,
                            recipe: _getRecipeForPlanet(hudPlanet),
                            meter: _game!.meter,
                            actionLabel: hudPathwayUnlocked
                                ? 'ENTER PLANET'
                                : 'SUMMON',
                            hideLevel: hudPathwayUnlocked,
                            onSummon: hudCanAct
                                ? _triggerScreenShakeAndSummon
                                : null,
                            onTogglePin: () => _togglePinnedRecipe(hudPlanet),
                            isPinned: _pinnedRecipeElement == hudPlanet.element,
                          ),
                      ],
                    ),
                  ),
                ),

              // ── Top HUD ──
              if (!_anyOverlayOpen)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: TopHud(
                      theme: theme,
                      meter: _game!.meter,
                      meterPulse: _meterPulse,
                      discoveryPct: _game!.discoveryPct,
                      planetsFound: _world.discoveredCount,
                      planetsTotal: _world.totalCount,
                      dustCount: _collectedDust.length,
                      wallet: _game!.shipWallet,
                      onSettings: () =>
                          setState(() => _showSettingsMenu = true),
                      onMiniMap: _toggleMiniMap,
                      onMeterTap: _handleMeterTap,
                      showMeter: _nearPlanet == null || _isNearHome,
                      collapsed: _topHudCollapsed,
                      onCollapsedChanged: (collapsed) {
                        if (_topHudCollapsed == collapsed) return;
                        setState(() => _topHudCollapsed = collapsed);
                      },
                    ),
                  ),
                ),

              // ── Home planet HUD ──
              // ── Mini-map overlay (animated open/close) ──
              if (_showMiniMap || _miniMapCtrl.isAnimating)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _miniMapCtrl,
                    builder: (context, child) {
                      final t = Curves.easeOutCubic.transform(
                        _miniMapCtrl.value,
                      );
                      final translateY = (1 - t) * 40.0;
                      return Transform.translate(
                        offset: Offset(0, translateY),
                        child: child,
                      );
                    },
                    child: RepaintBoundary(
                      child: MiniMapOverlay(
                        world: _world,
                        game: _game!,
                        theme: theme,
                        markers: _mapMarkers,
                        hasHomePlanet: _homePlanet != null,
                        debugShowAllContestArenasOnMap:
                            _contestDebugShowAllOnMap,
                        debugEnableContestArenaTeleport:
                            _contestDebugAllowMapTeleport,
                        onTeleport: (pos) {
                          final meterPct = _game!.meter.fillPct;
                          if (meterPct > _teleportCapacity) {
                            final capPct = (_teleportCapacity * 100).round();
                            _showQuote(
                              'Too much elemental energy! Lighten below $capPct% to teleport.',
                            );
                            HapticFeedback.heavyImpact();
                            return;
                          }
                          _resetCosmicTouchState();
                          _game?.teleportTo(pos);
                          _closeMiniMap();
                        },
                        onNavigatePlanet: (planet) {
                          final meterPct = _game!.meter.fillPct;
                          if (meterPct > _teleportCapacity) {
                            final capPct = (_teleportCapacity * 100).round();
                            _showQuote(
                              'Too much elemental energy! Lighten below $capPct% to teleport.',
                            );
                            HapticFeedback.heavyImpact();
                            return;
                          }
                          _resetCosmicTouchState();
                          _game?.teleportTo(planet.position);
                          _showQuote(
                            'Teleported to ${planetName(planet.element)}.',
                          );
                          HapticFeedback.lightImpact();
                          _closeMiniMap();
                        },
                        onGoHome: () {
                          if (_handleGoHome()) {
                            _closeMiniMap();
                          }
                        },
                        onClose: _closeMiniMap,
                        onMarkersChanged: (markers) {
                          setState(() => _mapMarkers = markers);
                          _saveMapMarkers();
                        },
                      ),
                    ),
                  ),
                ),

              // ── Summon result popup ──
              if (_summonResult != null)
                Positioned.fill(
                  child: SummonPopup(
                    result: _summonResult!,
                    theme: theme,
                    onReset: _handleReset,
                    onComplete: _handleCompleteSummon,
                  ),
                ),

              // ── Elements captured popup ──
              if (_showElementsCaptured)
                Positioned.fill(
                  child: ElementsCapturedPopup(
                    breakdown: _capturedBreakdown,
                    onDismiss: () {
                      _game?.resumeEngine();
                      setState(() => _showElementsCaptured = false);
                    },
                  ),
                ),

              // ── Home planet menu overlay ──
              if (_showHomeMenu && _homePlanet != null)
                Positioned.fill(
                  child: HomePlanetMenuOverlay(
                    homePlanet: _homePlanet!,
                    elementStorage: _elementStorage,
                    onCustomize: () {
                      setState(() => _showHomeMenu = false);
                      setState(() => _showCustomizationMenu = true);
                    },
                    onGarrison: () {
                      setState(() => _showHomeMenu = false);
                      setState(() => _showGarrisonPicker = true);
                    },
                    onClose: () => setState(() => _showHomeMenu = false),
                  ),
                ),

              // ── Customization menu overlay ──
              if (_showCustomizationMenu)
                Positioned.fill(
                  child: CustomizationMenuOverlay(
                    customizationState: _customizationState,
                    elementStorage: _elementStorage,
                    homePlanet: _homePlanet,
                    onTryRecipe: _handleTryRecipe,
                    onToggleRecipe: _handleToggleRecipe,
                    onOptionChanged: _handleOptionChanged,
                    onUpgradeSize: _handleUpgradePlanetSize,
                    onSelectSize: _handleSelectPlanetSize,
                    onUnlockColor: _handleUnlockColor,
                    onSelectColor: _handleSelectColor,
                    onClose: () =>
                        setState(() => _showCustomizationMenu = false),
                    cargoLevel: _cargoLevel,
                    isNearHome: _isNearHome,
                    onUpgradeCargo: () async {
                      await _handleUpgradeCargo();
                      if (mounted) setState(() {});
                    },
                    onChambers: () {
                      setState(() => _showCustomizationMenu = false);
                      setState(() => _showChamberPicker = true);
                    },
                    onUpgradePowerUp: _handleUpgradePowerUp,
                  ),
                ),

              // ── Chamber picker overlay ──
              if (_showChamberPicker)
                Positioned.fill(
                  child: ChamberPickerOverlay(
                    chambers: _game?.orbitalChambers ?? [],
                    onAssign: _handleAssignChamber,
                    onClear: _handleClearChamber,
                    onClose: () => setState(() => _showChamberPicker = false),
                  ),
                ),

              // ── Party picker overlay ──
              if (_showPartyPicker)
                Positioned.fill(
                  child: CosmicPartyPickerOverlay(
                    slotsUnlocked: _cosmicPartySlotsUnlocked,
                    partyMembers: _partyMembers,
                    activeSlot: _activeCompanionSlot,
                    onAssign: _handleAssignPartySlot,
                    onClear: _handleClearPartySlot,
                    onSummon: _handleSummonCompanion,
                    onReturn: _handleReturnCompanion,
                    onClose: () => setState(() => _showPartyPicker = false),
                    excludeInstanceIds: _garrisonMembers
                        .whereType<CosmicPartyMember>()
                        .map((m) => m.instanceId)
                        .toSet(),
                  ),
                ),

              // ── Garrison picker overlay ──
              if (_showGarrisonPicker)
                Positioned.fill(
                  child: CosmicPartyPickerOverlay(
                    title: 'HOME GARRISON',
                    maxSlots: kHomeGarrisonMaxSlots,
                    slotsUnlocked: _garrisonSlots,
                    partyMembers: _garrisonMembers,
                    onAssign: _handleAssignGarrisonSlot,
                    onClear: _handleClearGarrisonSlot,
                    onClose: () => setState(() => _showGarrisonPicker = false),
                    hintText:
                        'Tap a slot to station an Alchemon.\nGarrison size grows with planet tier!',
                    excludeInstanceIds: _partyMembers
                        .whereType<CosmicPartyMember>()
                        .map((m) => m.instanceId)
                        .toSet(),
                  ),
                ),

              // ── Discovery quote overlay ──
              if (_activeQuote != null)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: MediaQuery.of(context).size.height * 0.35,
                  child: FadeTransition(
                    opacity: _quoteFade,
                    child: IgnorePointer(
                      child: Text(
                        _activeQuote!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                          shadows: [
                            Shadow(blurRadius: 12, color: Colors.black87),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Rift portal button ──
              if (_game != null &&
                  _isNearRift &&
                  _game!.nearestRift != null &&
                  _summonResult == null &&
                  !_showMiniMap &&
                  !_anyOverlayOpen)
                Builder(
                  builder: (context) {
                    final rift = _game!.nearestRift!;
                    final col = rift.color;
                    final core = rift.coreColor;
                    return Positioned(
                      bottom: 100,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _handleRiftTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: core.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: col, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: col.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.blur_on, color: col, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  'ENTER ${rift.displayName.toUpperCase()}',
                                  style: TextStyle(
                                    color: col,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // ── Blood Ring button ──
              if (_game != null &&
                  _isNearBloodRing &&
                  _summonResult == null &&
                  !_showMiniMap &&
                  !_anyOverlayOpen)
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _handleBloodRingTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.93),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFF8A80),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFB71C1C,
                              ).withValues(alpha: 0.55),
                              blurRadius: 24,
                            ),
                            BoxShadow(
                              color: const Color(
                                0xFFFFCDD2,
                              ).withValues(alpha: 0.16),
                              blurRadius: 40,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.brightness_2,
                                  color: Color(0xFFFF8A80),
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _game!.bloodRing.ritualCompleted
                                      ? 'ENTER BLOOD PORTAL'
                                      : 'BLOOD RITUAL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _game!.bloodRing.ritualCompleted
                                  ? 'Replay the ending credits'
                                  : 'Summon Mystic Blood + Choose One Offering',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Trait Contest button ──
              if (_game != null &&
                  _nearContestArena != null &&
                  _nearMarketPOI == null &&
                  !_isNearBattleRing &&
                  !_isNearBloodRing &&
                  _summonResult == null &&
                  !_showMiniMap &&
                  !_anyOverlayOpen)
                Builder(
                  builder: (_) {
                    final trait = _nearContestArena!.trait;
                    final done = _contestProgress.completedLevels(trait);
                    final nextLevel = (done + 1).clamp(1, 5);
                    final mastered = _contestProgress.isMastered(trait);
                    final accent = trait.color;
                    return Positioned(
                      bottom: 100,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _handleContestArenaTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: accent, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.5),
                                  blurRadius: 24,
                                ),
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.2),
                                  blurRadius: 36,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.emoji_events_rounded,
                                      color: accent,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${trait.label.toUpperCase()} CONTEST',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  mastered
                                      ? 'MASTERED (5/5)'
                                      : 'LEVEL $nextLevel / 5  •  TAP TO START',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // ── Battle Ring button ──
              if (_game != null &&
                  _isNearBattleRing &&
                  !_game!.battleRing.inBattle &&
                  _summonResult == null &&
                  !_showMiniMap &&
                  !_anyOverlayOpen)
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _handleBattleRingTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFFD740),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFFFD740,
                              ).withValues(alpha: 0.5),
                              blurRadius: 24,
                            ),
                            BoxShadow(
                              color: const Color(
                                0xFFFF6F00,
                              ).withValues(alpha: 0.2),
                              blurRadius: 40,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.sports_mma,
                                  color: Color(0xFFFFD740),
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _game!.battleRing.isCompleted
                                      ? 'PRACTICE ARENA'
                                      : 'DEPLOY ALCHEMON TO START',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _game!.battleRing.isCompleted
                                  ? 'Endless Battles'
                                  : _game!.battleRing.levelLabel,
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Elemental Nexus button (enter from normal world) ──
              // Hidden once the player has completed the nexus (harvester awarded).
              if (_game != null &&
                  _isNearNexus &&
                  !(_game!.inNexusPocket) &&
                  !_game!.elementalNexus.harvesterAwarded &&
                  _summonResult == null &&
                  !_showMiniMap &&
                  !_anyOverlayOpen)
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _handleNexusTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.deepPurpleAccent,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurpleAccent.withValues(
                                alpha: 0.5,
                              ),
                              blurRadius: 24,
                            ),
                            BoxShadow(
                              color: Colors.cyanAccent.withValues(alpha: 0.2),
                              blurRadius: 40,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.blur_circular,
                                  color: Colors.deepPurpleAccent,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'ENTER ELEMENTAL NEXUS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '4 Boss Keys + 25% Fire · Water · Air · Earth',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Pocket portal button (inside pocket dimension) ──
              if (_game != null &&
                  _game!.inNexusPocket &&
                  _nearPocketPortalElement != null &&
                  !_anyOverlayOpen)
                Builder(
                  builder: (context) {
                    final element = _nearPocketPortalElement!;
                    final col = {
                      'Fire': const Color(0xFFFF5722),
                      'Water': const Color(0xFF448AFF),
                      'Earth': const Color(0xFF795548),
                      'Air': const Color(0xFF81D4FA),
                    }[element]!;
                    return Positioned(
                      bottom: 100,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _handlePocketPortalTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: col, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: col.withValues(alpha: 0.5),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.blur_on, color: col, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  'ENTER ${element.toUpperCase()} PORTAL',
                                  style: TextStyle(
                                    color: col,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // ── Exit pocket button (top-left, inside pocket dimension) ──
              if (_game != null && _game!.inNexusPocket && !_anyOverlayOpen)
                Positioned(
                  top: 0,
                  left: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: GestureDetector(
                        onTap: () {
                          if (_game == null) return;
                          HapticFeedback.mediumImpact();
                          _game!.exitNexusPocket();
                          _saveNexusState();
                          setState(() {
                            _nearPocketPortalElement = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_back,
                                color: Colors.white54,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'EXIT NEXUS',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Companion HUD moved: small health bars are shown above each
              // companion slot button below (no floating HUD).
              // ── Home Base + Deposit buttons (bottom center, near home) ──
              if (_homePlanet != null)
                Positioned(
                  bottom: 20,
                  left: _showJoystick ? (_largeJoystick ? 146.0 : 120.0) : 0,
                  right: _showJoystick ? 74 : 0,
                  child: AnimatedOpacity(
                    opacity:
                        (_isNearHome &&
                            _summonResult == null &&
                            !_showElementsCaptured &&
                            !_showMiniMap &&
                            !_anyOverlayOpen)
                        ? 1.0
                        : 0.0,
                    duration: const Duration(milliseconds: 350),
                    child: AnimatedSlide(
                      offset:
                          (_isNearHome &&
                              _summonResult == null &&
                              !_showElementsCaptured &&
                              !_showMiniMap &&
                              !_anyOverlayOpen)
                          ? Offset.zero
                          : const Offset(0, 0.4),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      child: IgnorePointer(
                        ignoring:
                            !(_isNearHome &&
                                _summonResult == null &&
                                !_showElementsCaptured &&
                                !_showMiniMap &&
                                !_anyOverlayOpen),
                        child: SafeArea(
                          child: Center(
                            child: _showJoystick
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // HOME BASE button
                                      GestureDetector(
                                        onTap: () => setState(
                                          () => _showHomeMenu = true,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: CosmicScreenStyles.bg1,
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                            border: Border.all(
                                              color: CosmicScreenStyles.amber
                                                  .withValues(alpha: 0.6),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: CosmicScreenStyles.amber
                                                    .withValues(alpha: 0.25),
                                                blurRadius: 16,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 18,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: RadialGradient(
                                                    colors: [
                                                      Color.lerp(
                                                        _homePlanet!
                                                            .blendedColor,
                                                        Colors.white,
                                                        0.3,
                                                      )!,
                                                      _homePlanet!.blendedColor,
                                                    ],
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: _homePlanet!
                                                          .blendedColor
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'HOME BASE',
                                                style: TextStyle(
                                                  fontFamily: appFontFamily(
                                                    context,
                                                  ),
                                                  color: CosmicScreenStyles
                                                      .textPrimary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // SHIP button
                                      _buildShipButton(),
                                      const SizedBox(height: 6),
                                      // DEPOSIT button
                                      GestureDetector(
                                        onTap: _handleDepositAll,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: CosmicScreenStyles.amber,
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                            border: Border.all(
                                              color:
                                                  CosmicScreenStyles.amberGlow,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: CosmicScreenStyles.amber
                                                    .withValues(alpha: 0.35),
                                                blurRadius: 12,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'DEPOSIT',
                                            style: TextStyle(
                                              fontFamily: appFontFamily(
                                                context,
                                              ),
                                              color: CosmicScreenStyles.bg0,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // HOME BASE button
                                      GestureDetector(
                                        onTap: () => setState(
                                          () => _showHomeMenu = true,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: CosmicScreenStyles.bg1,
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                            border: Border.all(
                                              color: CosmicScreenStyles.amber
                                                  .withValues(alpha: 0.6),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: CosmicScreenStyles.amber
                                                    .withValues(alpha: 0.25),
                                                blurRadius: 16,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: RadialGradient(
                                                    colors: [
                                                      Color.lerp(
                                                        _homePlanet!
                                                            .blendedColor,
                                                        Colors.white,
                                                        0.3,
                                                      )!,
                                                      _homePlanet!.blendedColor,
                                                    ],
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: _homePlanet!
                                                          .blendedColor
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                'HOME BASE',
                                                style: TextStyle(
                                                  fontFamily: appFontFamily(
                                                    context,
                                                  ),
                                                  color: CosmicScreenStyles
                                                      .textPrimary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 2.0,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // SHIP button
                                      _buildShipButton(),
                                      const SizedBox(height: 6),
                                      // DEPOSIT button
                                      GestureDetector(
                                        onTap: _handleDepositAll,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: CosmicScreenStyles.amber,
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                            border: Border.all(
                                              color:
                                                  CosmicScreenStyles.amberGlow,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: CosmicScreenStyles.amber
                                                    .withValues(alpha: 0.35),
                                                blurRadius: 12,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            'DEPOSIT',
                                            style: TextStyle(
                                              fontFamily: appFontFamily(
                                                context,
                                              ),
                                              color: CosmicScreenStyles.bg0,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // (Fuel & missiles now auto-refill at home — no buttons needed)

              // ── SHIP button (bottom center, hidden when near home) ──
              Positioned(
                bottom: 20,
                left: _showJoystick ? (_largeJoystick ? 146.0 : 120.0) : 0,
                right: _showJoystick ? 74 : 0,
                child: AnimatedOpacity(
                  opacity:
                      (!_isNearHome &&
                          _summonResult == null &&
                          !_showMiniMap &&
                          !_anyOverlayOpen)
                      ? (_nearPlanet != null ? 0.25 : 1.0)
                      : 0.0,
                  duration: const Duration(milliseconds: 350),
                  child: AnimatedSlide(
                    offset:
                        (!_isNearHome &&
                            _summonResult == null &&
                            !_showMiniMap &&
                            !_anyOverlayOpen)
                        ? Offset.zero
                        : const Offset(0, 0.4),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    child: IgnorePointer(
                      ignoring:
                          _isNearHome ||
                          _summonResult != null ||
                          _showMiniMap ||
                          _anyOverlayOpen,
                      child: SafeArea(child: _buildShipButton()),
                    ),
                  ),
                ),
              ),

              // ── Combat buttons (right side) ──
              if (_summonResult == null && !_showMiniMap && !_anyOverlayOpen)
                Positioned(
                  bottom: 20,
                  right: 12,
                  child: AnimatedOpacity(
                    opacity: _nearPlanet != null && !_isNearHome ? 0.25 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Boost button
                          if (_customizationState.hasBooster)
                            GestureDetector(
                              onTapDown: _boostToggleMode
                                  ? null
                                  : (_) => _startBoosting(),
                              onTapUp: _boostToggleMode
                                  ? null
                                  : (_) => _stopBoosting(),
                              onTapCancel: _boostToggleMode
                                  ? null
                                  : _stopBoosting,
                              onTap: _boostToggleMode ? _toggleBoosting : null,
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: _isBoosting
                                      ? const Color(
                                          0xFFFF6F00,
                                        ).withValues(alpha: 0.2)
                                      : Colors.black54,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _isBoosting
                                        ? const Color(0xFFFF6F00)
                                        : Colors.white24,
                                    width: _isBoosting ? 2 : 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.local_fire_department_rounded,
                                  color: _isBoosting
                                      ? const Color(0xFFFF6F00)
                                      : Colors.white54,
                                  size: 25,
                                ),
                              ),
                            ),
                          if (_customizationState.hasBooster)
                            const SizedBox(height: 14),
                          // Weapon buttons (slide-to-switch)
                          Listener(
                            onPointerDown: _handleWeaponPointerDown,
                            onPointerMove: _handleWeaponPointerMove,
                            onPointerUp: _handleWeaponPointerUp,
                            onPointerCancel: _handleWeaponPointerCancel,
                            child: Column(
                              key: _weaponColumnKey,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_customizationState.hasMissiles)
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: _isShootingMissiles
                                          ? const Color(
                                              0xFFE53935,
                                            ).withValues(alpha: 0.2)
                                          : Colors.black54,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _isShootingMissiles
                                            ? const Color(0xFFE53935)
                                            : Colors.white24,
                                        width: _isShootingMissiles ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.gps_fixed_rounded,
                                          color: _isShootingMissiles
                                              ? const Color(0xFFE53935)
                                              : Colors.white54,
                                          size: 21,
                                        ),
                                        Text(
                                          '${_game?.missileAmmo ?? 0}',
                                          style: TextStyle(
                                            fontFamily: appFontFamily(context),
                                            color: _isShootingMissiles
                                                ? const Color(0xFFE53935)
                                                : Colors.white38,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_customizationState.hasMissiles)
                                  const SizedBox(height: 10),
                                if (!_tapToShoot)
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: _isShooting
                                          ? const Color(
                                              0xFF00E5FF,
                                            ).withValues(alpha: 0.2)
                                          : Colors.black54,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _isShooting
                                            ? const Color(0xFF00E5FF)
                                            : Colors.white24,
                                        width: _isShooting ? 2 : 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.flash_on_rounded,
                                      color: _isShooting
                                          ? const Color(0xFF00E5FF)
                                          : Colors.white54,
                                      size: 25,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (_awaitingShipMenuTap &&
                  _summonResult == null &&
                  !_showMiniMap &&
                  !_anyOverlayOpen)
                Positioned(
                  right: 72,
                  bottom: 84,
                  child: IgnorePointer(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 260),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(
                            0xFF00E5FF,
                          ).withValues(alpha: 0.65),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF00E5FF,
                            ).withValues(alpha: 0.22),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: Text(
                        'Tap the ship icon to open your ship console and build your home base.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Companion column (stacked on right side) ──
              if (_summonResult == null &&
                  !_showMiniMap &&
                  !_anyOverlayOpen &&
                  !_awaitingShipMenuTap)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  right: 12,
                  top:
                      120 + (_nearPlanet != null && !_isNearHome ? 240.0 : 0.0),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (kDebugMode) ...[
                          _buildSandboxButton(),
                          const SizedBox(height: 10),
                        ],
                        _buildSlowModeButton(),
                        const SizedBox(height: 10),
                        if (_activeCompanionSlot != null) ...[
                          _buildCompanionTetherButton(),
                          const SizedBox(height: 10),
                        ],
                        for (
                          var i = 0;
                          i < _cosmicPartySlotsUnlocked && i < 3;
                          i++
                        ) ...[
                          // Small health bar above each companion slot
                          Builder(
                            builder: (_) {
                              final isActive = _activeCompanionSlot == i;
                              final hpFrac = isActive
                                  ? (_game?.activeCompanion?.hpPercent ??
                                        (_companionHpFraction[i] ?? 1.0))
                                  : (_companionHpFraction[i] ?? 1.0);
                              return SizedBox(
                                width: 44,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? Colors.white12
                                            : Colors.white10,
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(
                                          color: isActive
                                              ? Colors.white10
                                              : Colors.white12,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: FractionallySizedBox(
                                          widthFactor: hpFrac.clamp(0.0, 1.0),
                                          child: Container(
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color:
                                                  (hpFrac > 0.5
                                                          ? const Color(
                                                              0xFF00E676,
                                                            )
                                                          : hpFrac > 0.25
                                                          ? const Color(
                                                              0xFFFFEA00,
                                                            )
                                                          : const Color(
                                                              0xFFE53935,
                                                            ))
                                                      .withValues(
                                                        alpha: isActive
                                                            ? 1.0
                                                            : 0.35,
                                                      ),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                ),
                              );
                            },
                          ),
                          _buildPartySlotButton(i),
                          if (i < _cosmicPartySlotsUnlocked - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),

              // ── Ship menu overlay ──
              if (_showShipMenu)
                ShipMenuOverlay(
                  hasHomePlanet: _homePlanet != null,
                  meterFill: _game?.meter.fillPct ?? 0,
                  walletShards: _game?.shipWallet.shards ?? 0,
                  shipHealth: _game?.shipHealth ?? 0,
                  shipMaxHealth: CosmicGame.shipMaxHealth,
                  fuelFraction: _game?.shipFuel.fraction ?? 0,
                  activeWeaponName: _activeWeaponName,
                  orbitalStockpile: _game?.orbitalStockpile ?? 0,
                  orbitalActive: _game?.orbitals.length ?? 0,
                  hasBooster: _customizationState.hasBooster,
                  hasOrbitals: _customizationState.hasOrbitals,
                  hasMissiles: _customizationState.hasMissiles,
                  missileAmmo: _game?.missileAmmo ?? 0,
                  hasRefuelStation: _customizationState.hasRefuelStation,
                  hasMissileStation: _customizationState.hasMissileStation,
                  hasSentinelStation: _customizationState.hasSentinelStation,
                  cargoLevel: _cargoLevel,
                  isNearHome: _isNearHome,
                  onClose: () {
                    if (_awaitingBuildHomeTap && _homePlanet == null) return;
                    setState(() => _showShipMenu = false);
                  },
                  onBuildHome: () {
                    final built = _handleBuildHomePlanet();
                    if (_awaitingBuildHomeTap &&
                        _homePlanet == null &&
                        !built) {
                      setState(() {
                        _showShipMenu = false;
                        _awaitingBuildHomeTap = false;
                        _awaitingShipMenuTap = true;
                      });
                      return;
                    }
                    setState(() => _showShipMenu = false);
                  },
                  onRelocateHome: () {
                    setState(() => _showShipMenu = false);
                    _handleMoveHomePlanet();
                  },
                  onJettisonCargo: () {
                    setState(() => _showShipMenu = false);
                    _handleJettisonCargo();
                  },
                  onDumpWallet: () {
                    setState(() => _showShipMenu = false);
                    _handleDumpWallet();
                  },
                  onRefuel: () async {
                    await _handleRefuel();
                    if (mounted) setState(() {});
                  },
                  onCraftMissiles: () async {
                    await _handleCraftMissiles();
                    if (mounted) setState(() {});
                  },
                  onCraftSentinels: () async {
                    await _handleCraftSentinels();
                    if (mounted) setState(() {});
                  },
                  onUpgradeCargo: () async {
                    await _handleUpgradeCargo();
                    if (mounted) setState(() {});
                  },
                  tutorialBuildHomeMode:
                      _awaitingBuildHomeTap && _homePlanet == null,
                  hasParty: _cosmicPartySlotsUnlocked > 0,
                  onParty: () {
                    setState(() {
                      _showShipMenu = false;
                      _showPartyPicker = true;
                    });
                  },
                ),

              // ── Settings overlay ──
              if (_showSettingsMenu)
                _CosmicSettingsOverlay(
                  joystickEnabled: _showJoystick,
                  largeJoystickEnabled: _largeJoystick,
                  tapToShootEnabled: _tapToShoot,
                  boostToggleEnabled: _boostToggleMode,
                  onClose: () => setState(() => _showSettingsMenu = false),
                  onLeaveSpace: () async {
                    setState(() => _showSettingsMenu = false);
                    await _confirmLeave();
                  },
                  onToggleJoystick: (v) async {
                    setState(() => _showJoystick = v);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('cosmic_joystick_enabled', v);
                  },
                  onToggleLargeJoystick: (v) async {
                    setState(() => _largeJoystick = v);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('cosmic_large_joystick', v);
                  },
                  onToggleTapToShoot: (v) async {
                    setState(() {
                      _tapToShoot = v;
                      _game?.tapToShootMode = v;
                      _movePointerId = null;
                      _tapShootPointerIds.clear();
                      if (!v && _isShooting) _stopShooting();
                    });
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('cosmic_tap_to_shoot', v);
                  },
                  onToggleBoostToggle: (v) async {
                    setState(() {
                      _boostToggleMode = v;
                      if (!v && _isBoosting) _stopBoosting();
                    });
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('cosmic_boost_toggle', v);
                  },
                ),

              if (_showSandboxPanel)
                Positioned.fill(
                  child: _CosmicSandboxOverlay(
                    creatures: _sandboxCreatures(
                      context.read<CreatureCatalog>(),
                    ),
                    query: _sandboxCreatureQuery,
                    onQueryChanged: (value) =>
                        setState(() => _sandboxCreatureQuery = value),
                    statTier: _sandboxCompanionStatTier,
                    onStatTierChanged: (value) =>
                        setState(() => _sandboxCompanionStatTier = value),
                    onSummonCreature: _summonSandboxCompanion,
                    enemyTier: _sandboxEnemyTier,
                    onEnemyTierChanged: (value) =>
                        setState(() => _sandboxEnemyTier = value),
                    enemyBehavior: _sandboxEnemyBehavior,
                    onEnemyBehaviorChanged: (value) =>
                        setState(() => _sandboxEnemyBehavior = value),
                    enemyCount: _sandboxEnemyCount,
                    onEnemyCountChanged: (value) =>
                        setState(() => _sandboxEnemyCount = value),
                    onSpawnEnemy: _spawnSandboxEnemy,
                    onSpawnDummy: _spawnSandboxDummy,
                    bossTemplate: _sandboxBossTemplate,
                    bossTemplates: kBossTemplates,
                    onBossTemplateChanged: (value) =>
                        setState(() => _sandboxBossTemplate = value),
                    bossLevel: _sandboxBossLevel,
                    onBossLevelChanged: (value) =>
                        setState(() => _sandboxBossLevel = value),
                    onSpawnBoss: _spawnSandboxBoss,
                    onClearHostiles: _clearSandboxHostiles,
                    onClose: _toggleSandboxPanel,
                    onLeaveSandbox: _leaveSandboxMode,
                  ),
                ),

              // ── In-space Blood Ritual overlay (fades space to black) ──
              if (_showBloodRitualOverlay && _game != null)
                Positioned.fill(
                  child: AbsorbPointer(
                    absorbing: true,
                    child: AnimatedBuilder(
                      animation: _bloodRitualCtrl,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _BloodRitualSpaceOverlayPainter(
                            game: _game!,
                            progress: _bloodRitualCtrl.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CosmicSandboxOverlay extends StatefulWidget {
  const _CosmicSandboxOverlay({
    required this.creatures,
    required this.query,
    required this.onQueryChanged,
    required this.statTier,
    required this.onStatTierChanged,
    required this.onSummonCreature,
    required this.enemyTier,
    required this.onEnemyTierChanged,
    required this.enemyBehavior,
    required this.onEnemyBehaviorChanged,
    required this.enemyCount,
    required this.onEnemyCountChanged,
    required this.onSpawnEnemy,
    required this.onSpawnDummy,
    required this.bossTemplate,
    required this.bossTemplates,
    required this.onBossTemplateChanged,
    required this.bossLevel,
    required this.onBossLevelChanged,
    required this.onSpawnBoss,
    required this.onClearHostiles,
    required this.onClose,
    required this.onLeaveSandbox,
  });

  final List<Creature> creatures;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final int statTier;
  final ValueChanged<int> onStatTierChanged;
  final ValueChanged<Creature> onSummonCreature;
  final EnemyTier enemyTier;
  final ValueChanged<EnemyTier> onEnemyTierChanged;
  final EnemyBehavior enemyBehavior;
  final ValueChanged<EnemyBehavior> onEnemyBehaviorChanged;
  final int enemyCount;
  final ValueChanged<int> onEnemyCountChanged;
  final VoidCallback onSpawnEnemy;
  final VoidCallback onSpawnDummy;
  final BossTemplate bossTemplate;
  final List<BossTemplate> bossTemplates;
  final ValueChanged<BossTemplate> onBossTemplateChanged;
  final int bossLevel;
  final ValueChanged<int> onBossLevelChanged;
  final VoidCallback onSpawnBoss;
  final VoidCallback onClearHostiles;
  final VoidCallback onClose;
  final VoidCallback onLeaveSandbox;

  @override
  State<_CosmicSandboxOverlay> createState() => _CosmicSandboxOverlayState();
}

class _CosmicSandboxOverlayState extends State<_CosmicSandboxOverlay>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _queryController;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.query);
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didUpdateWidget(covariant _CosmicSandboxOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _queryController.text) {
      _queryController.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = size.height > size.width;
    final width = isPortrait ? size.width - 12 : min(size.width - 20, 1040.0);
    final height = isPortrait ? size.height - 12 : min(size.height - 20, 780.0);
    return Material(
      color: Colors.black.withValues(alpha: 0.58),
      child: SafeArea(
        child: Center(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFF081017).withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF7CFFB2).withValues(alpha: 0.42),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7CFFB2).withValues(alpha: 0.08),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.science_rounded,
                            color: Color(0xFF7CFFB2),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'COSMIC SANDBOX',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  'Isolated combat lab with real cosmic combat rules',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.58),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: widget.onClose,
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: widget.onClearHostiles,
                            child: const Text('Clear Hostiles'),
                          ),
                          TextButton(
                            onPressed: widget.onLeaveSandbox,
                            child: const Text('Leave Sandbox'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: Color(0xFF7CFFB2),
                  tabs: const [
                    Tab(text: 'Alchemons'),
                    Tab(text: 'Enemies'),
                    Tab(text: 'Bosses'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCreatureTab(),
                      _buildEnemyTab(),
                      _buildBossTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreatureTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (compact) ...[
                TextField(
                  onChanged: widget.onQueryChanged,
                  controller: _queryController,
                  decoration: InputDecoration(
                    hintText: 'Search species, family, or element',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                _buildDropdownShell(
                  label: 'Stats',
                  width: double.infinity,
                  child: DropdownButton<int>(
                    value: widget.statTier,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF101A22),
                    style: const TextStyle(color: Colors.white),
                    underline: const SizedBox.shrink(),
                    items: List.generate(
                      5,
                      (i) => DropdownMenuItem<int>(
                        value: i + 1,
                        child: Text('${i + 1}/5'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) widget.onStatTierChanged(value);
                    },
                  ),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: widget.onQueryChanged,
                        controller: _queryController,
                        decoration: InputDecoration(
                          hintText: 'Search species, family, or element',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.white54,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildDropdownShell(
                      label: 'Stats',
                      width: 148,
                      child: DropdownButton<int>(
                        value: widget.statTier,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF101A22),
                        style: const TextStyle(color: Colors.white),
                        underline: const SizedBox.shrink(),
                        items: List.generate(
                          5,
                          (i) => DropdownMenuItem<int>(
                            value: i + 1,
                            child: Text('${i + 1}/5'),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null) widget.onStatTierChanged(value);
                        },
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Sandbox summons always enter at Lv10. The selected stat tier sets Speed, Intelligence, Strength, and Beauty evenly. Death resets the lab instead of costing anything.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: widget.creatures.length,
                  separatorBuilder: (_, __) => Divider(
                    color: Colors.white.withValues(alpha: 0.08),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final creature = widget.creatures[index];
                    final family = creature.mutationFamily ?? 'Unknown';
                    final element = creature.types.firstOrNull ?? 'Fire';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: elementColor(
                          element,
                        ).withValues(alpha: 0.22),
                        child: Text(
                          family.isNotEmpty ? family[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        creature.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '$element · $family',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                      trailing: FilledButton(
                        onPressed: () => widget.onSummonCreature(creature),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1C6F52),
                        ),
                        child: const Text('Summon'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnemyTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final tierLabel = _enemyTierLabel(widget.enemyTier);
        final tierDescription = _enemyTierDescription(widget.enemyTier);
        final behaviorLabel = _enemyBehaviorLabel(widget.enemyBehavior);
        final behaviorDescription = _enemyBehaviorDescription(
          widget.enemyBehavior,
        );
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                _buildDropdownShell(
                  label: 'Frame',
                  width: double.infinity,
                  child: DropdownButton<EnemyTier>(
                    value: widget.enemyTier,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF101A22),
                    style: const TextStyle(color: Colors.white),
                    underline: const SizedBox.shrink(),
                    items: EnemyTier.values
                        .map(
                          (tier) => DropdownMenuItem(
                            value: tier,
                            child: Text(_enemyTierLabel(tier).toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) widget.onEnemyTierChanged(value);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _buildDropdownShell(
                  label: 'Behavior',
                  width: double.infinity,
                  child: DropdownButton<EnemyBehavior>(
                    value: widget.enemyBehavior,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF101A22),
                    style: const TextStyle(color: Colors.white),
                    underline: const SizedBox.shrink(),
                    items: EnemyBehavior.values
                        .map(
                          (behavior) => DropdownMenuItem(
                            value: behavior,
                            child: Text(
                              _enemyBehaviorLabel(behavior).toUpperCase(),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) widget.onEnemyBehaviorChanged(value);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _buildDropdownShell(
                  label: 'Count',
                  width: double.infinity,
                  child: DropdownButton<int>(
                    value: widget.enemyCount,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF101A22),
                    style: const TextStyle(color: Colors.white),
                    underline: const SizedBox.shrink(),
                    items: List.generate(
                      2,
                      (i) => DropdownMenuItem(
                        value: i == 0 ? 1 : 10,
                        child: Text(i == 0 ? '1' : '10'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) widget.onEnemyCountChanged(value);
                    },
                  ),
                ),
              ] else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildDropdownShell(
                      label: 'Frame',
                      width: 180,
                      child: DropdownButton<EnemyTier>(
                        value: widget.enemyTier,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF101A22),
                        style: const TextStyle(color: Colors.white),
                        underline: const SizedBox.shrink(),
                        items: EnemyTier.values
                            .map(
                              (tier) => DropdownMenuItem(
                                value: tier,
                                child: Text(
                                  _enemyTierLabel(tier).toUpperCase(),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) widget.onEnemyTierChanged(value);
                        },
                      ),
                    ),
                    _buildDropdownShell(
                      label: 'Behavior',
                      width: 180,
                      child: DropdownButton<EnemyBehavior>(
                        value: widget.enemyBehavior,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF101A22),
                        style: const TextStyle(color: Colors.white),
                        underline: const SizedBox.shrink(),
                        items: EnemyBehavior.values
                            .map(
                              (behavior) => DropdownMenuItem(
                                value: behavior,
                                child: Text(
                                  _enemyBehaviorLabel(behavior).toUpperCase(),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            widget.onEnemyBehaviorChanged(value);
                          }
                        },
                      ),
                    ),
                    _buildDropdownShell(
                      label: 'Count',
                      width: 180,
                      child: DropdownButton<int>(
                        value: widget.enemyCount,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF101A22),
                        style: const TextStyle(color: Colors.white),
                        underline: const SizedBox.shrink(),
                        items: List.generate(
                          2,
                          (i) => DropdownMenuItem(
                            value: i == 0 ? 1 : 10,
                            child: Text(i == 0 ? '1' : '10'),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null) widget.onEnemyCountChanged(value);
                        },
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$tierLabel • $behaviorLabel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$tierDescription $behaviorDescription',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Enemy spawns use the actual roaming rules. You pick the body frame and behavior pattern, then the sandbox rolls a real enemy from that mechanical profile.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: widget.onSpawnEnemy,
                    icon: const Icon(Icons.flash_on),
                    label: const Text('Spawn Enemies'),
                  ),
                  FilledButton.icon(
                    onPressed: widget.onSpawnDummy,
                    icon: const Icon(Icons.sports_martial_arts),
                    label: const Text('Spawn Dummies'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBossTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDropdownShell(
                label: 'Boss',
                width: double.infinity,
                child: DropdownButton<BossTemplate>(
                  value: widget.bossTemplate,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF101A22),
                  style: const TextStyle(color: Colors.white),
                  underline: const SizedBox.shrink(),
                  items: widget.bossTemplates
                      .map(
                        (template) => DropdownMenuItem(
                          value: template,
                          child: Text(
                            '${template.name} · ${template.element}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) widget.onBossTemplateChanged(value);
                  },
                ),
              ),
              const SizedBox(height: 12),
              _buildDropdownShell(
                label: 'Level',
                width: compact ? double.infinity : 180,
                child: DropdownButton<int>(
                  value: widget.bossLevel,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF101A22),
                  style: const TextStyle(color: Colors.white),
                  underline: const SizedBox.shrink(),
                  items: List.generate(
                    5,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('Lv ${i + 1}'),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) widget.onBossLevelChanged(value);
                  },
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Bosses keep real cosmic level scaling because bosses actually have levels in gameplay. Preferred archetypes are preserved automatically.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: widget.onSpawnBoss,
                icon: const Icon(Icons.whatshot),
                label: const Text('Spawn Boss'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _enemyTierLabel(EnemyTier tier) => switch (tier) {
    EnemyTier.wisp => 'Spark',
    EnemyTier.drone => 'Dart',
    EnemyTier.sentinel => 'Guard',
    EnemyTier.phantom => 'Shade',
    EnemyTier.brute => 'Bruiser',
    EnemyTier.colossus => 'Titan',
  };

  String _enemyTierDescription(EnemyTier tier) => switch (tier) {
    EnemyTier.wisp =>
      'Light body with evasive movement and very low durability.',
    EnemyTier.drone =>
      'Fast striker frame that closes quickly and punishes openings.',
    EnemyTier.sentinel =>
      'Balanced midweight body with steady pressure and room control.',
    EnemyTier.phantom =>
      'Elusive hunter frame that feels slippery and harder to pin down.',
    EnemyTier.brute =>
      'Heavy close-range body that trades speed for force and staying power.',
    EnemyTier.colossus =>
      'Slow siege body with the biggest footprint and longest time-to-kill.',
  };

  String _enemyBehaviorLabel(EnemyBehavior behavior) => switch (behavior) {
    EnemyBehavior.aggressive => 'Hunter',
    EnemyBehavior.drifting => 'Drifter',
    EnemyBehavior.feeding => 'Feeder',
    EnemyBehavior.territorial => 'Guardian',
    EnemyBehavior.stalking => 'Stalker',
    EnemyBehavior.swarming => 'Swarm',
  };

  String _enemyBehaviorDescription(EnemyBehavior behavior) =>
      switch (behavior) {
        EnemyBehavior.aggressive =>
          'It immediately presses the ship and keeps combat live.',
        EnemyBehavior.drifting =>
          'It mostly roams until it gets pulled into the fight.',
        EnemyBehavior.feeding =>
          'It behaves more passively and anchors around its local space.',
        EnemyBehavior.territorial =>
          'It defends an area and punishes you for staying inside it.',
        EnemyBehavior.stalking =>
          'It hovers at threatening distance and looks for timing windows.',
        EnemyBehavior.swarming =>
          'It clumps tightly and creates volume pressure through numbers.',
      };

  Widget _buildDropdownShell({
    required String label,
    required Widget child,
    double width = 220,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _BloodRitualSpaceOverlayPainter extends CustomPainter {
  _BloodRitualSpaceOverlayPainter({required this.game, required this.progress});

  final CosmicGame game;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.clamp(0.0, 1.0);
    final ww = game.world_.worldSize.width;
    final wh = game.world_.worldSize.height;

    var dx = game.bloodRing.position.dx - game.ship.pos.dx;
    var dy = game.bloodRing.position.dy - game.ship.pos.dy;
    if (dx > ww / 2) dx -= ww;
    if (dx < -ww / 2) dx += ww;
    if (dy > wh / 2) dy -= wh;
    if (dy < -wh / 2) dy += wh;

    final ringCenter = Offset(size.width / 2 + dx, size.height / 2 + dy);
    final fade = Curves.easeInCubic.transform((t * 1.05).clamp(0.0, 1.0));
    final ringFadeOut =
        1.0 - Curves.easeInCubic.transform(((t - 0.74) / 0.26).clamp(0.0, 1.0));
    final engulfT = Curves.easeInCubic.transform(
      ((t - 0.46) / 0.54).clamp(0.0, 1.0),
    );

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = Colors.black.withValues(
          alpha: (0.08 + fade * 0.68).clamp(0.0, 1.0),
        ),
    );

    final collapse = (t - 0.1).clamp(0.0, 1.0);
    final lineAlpha = 0.35 * collapse * ringFadeOut;
    for (var i = 0; i < 48; i++) {
      final a = (i / 48) * pi * 2 + t * pi * 2.6;
      final edge = Offset(
        size.width / 2 + cos(a) * size.width * 0.9,
        size.height / 2 + sin(a) * size.height * 0.9,
      );
      canvas.drawLine(
        edge,
        ringCenter,
        Paint()
          ..color = const Color(0xFFFFCDD2).withValues(alpha: lineAlpha * 0.5)
          ..strokeWidth = 1.0 + (i % 3) * 0.2,
      );
    }

    final pulse = 0.8 + 0.2 * sin(t * pi * 22);
    final ringBase = 95 + 68 * Curves.easeOut.transform(t);
    final ringR = ringBase * pulse;

    canvas.drawCircle(
      ringCenter,
      ringR * 1.45,
      Paint()
        ..color = const Color(
          0xFFB71C1C,
        ).withValues(alpha: 0.42 * fade * ringFadeOut)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34),
    );

    canvas.drawCircle(
      ringCenter,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9.0
        ..color = const Color(0xFFFF6E6E).withValues(alpha: 0.95 * ringFadeOut),
    );

    canvas.drawCircle(
      ringCenter,
      ringR * 0.7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..color = const Color(0xFFFFCDD2).withValues(alpha: 0.8 * ringFadeOut),
    );

    final runeRot = t * pi * 3.8;
    for (var i = 0; i < 10; i++) {
      final a = runeRot + (i / 10) * pi * 2;
      final pos = Offset(
        ringCenter.dx + cos(a) * (ringR + 24),
        ringCenter.dy + sin(a) * (ringR + 24),
      );
      canvas.drawCircle(
        pos,
        3.8 + 0.7 * sin(t * pi * 14 + i),
        Paint()
          ..color = const Color(
            0xFFFF8A80,
          ).withValues(alpha: 0.9 * ringFadeOut),
      );
    }

    canvas.drawCircle(
      ringCenter,
      ringR * 0.22,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFFFFCDD2).withValues(alpha: 0.86),
                const Color(0xFF7F0000).withValues(alpha: 0.34 * ringFadeOut),
                const Color(0xFF000000).withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromCircle(center: ringCenter, radius: ringR * 0.34),
            ),
    );

    // Red engulf wave: expands out from the ring until it covers all corners.
    final corners = <Offset>[
      const Offset(0, 0),
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    var maxToCorner = 0.0;
    for (final c in corners) {
      final d = (c - ringCenter).distance;
      if (d > maxToCorner) maxToCorner = d;
    }
    final engulfRadius = ringR + (maxToCorner + 220) * engulfT;
    canvas.drawCircle(
      ringCenter,
      engulfRadius,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFFFF6E6E).withValues(alpha: 0.20 * engulfT),
                const Color(0xFFD32F2F).withValues(alpha: 0.55 * engulfT),
                const Color(0xFF8B0000).withValues(alpha: 0.92 * engulfT),
              ],
              stops: const [0.0, 0.55, 1.0],
            ).createShader(
              Rect.fromCircle(center: ringCenter, radius: engulfRadius),
            ),
    );

    final fullRed = Curves.easeInOutCubic.transform(
      ((t - 0.78) / 0.22).clamp(0.0, 1.0),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(0xFF7F0000).withValues(alpha: 0.94 * fullRed),
    );
  }

  @override
  bool shouldRepaint(covariant _BloodRitualSpaceOverlayPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.game != game;
  }
}

class _CosmicSettingsOverlay extends StatelessWidget {
  const _CosmicSettingsOverlay({
    required this.joystickEnabled,
    required this.largeJoystickEnabled,
    required this.tapToShootEnabled,
    required this.boostToggleEnabled,
    required this.onClose,
    required this.onLeaveSpace,
    required this.onToggleJoystick,
    required this.onToggleLargeJoystick,
    required this.onToggleTapToShoot,
    required this.onToggleBoostToggle,
  });

  final bool joystickEnabled;
  final bool largeJoystickEnabled;
  final bool tapToShootEnabled;
  final bool boostToggleEnabled;
  final VoidCallback onClose;
  final VoidCallback onLeaveSpace;
  final ValueChanged<bool> onToggleJoystick;
  final ValueChanged<bool> onToggleLargeJoystick;
  final ValueChanged<bool> onToggleTapToShoot;
  final ValueChanged<bool> onToggleBoostToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10151E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings_rounded, color: Colors.white70),
                      const SizedBox(width: 8),
                      Text(
                        'SETTINGS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white60,
                        splashRadius: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SettingsToggleRow(
                    icon: Icons.gamepad_rounded,
                    label: 'Joystick',
                    value: joystickEnabled,
                    onChanged: onToggleJoystick,
                  ),
                  const SizedBox(height: 8),
                  _SettingsToggleRow(
                    icon: Icons.open_in_full_rounded,
                    label: 'Large Joystick',
                    value: largeJoystickEnabled,
                    onChanged: onToggleLargeJoystick,
                  ),
                  const SizedBox(height: 8),
                  _SettingsToggleRow(
                    icon: Icons.touch_app_rounded,
                    label: 'Tap To Shoot',
                    value: tapToShootEnabled,
                    onChanged: onToggleTapToShoot,
                  ),
                  const SizedBox(height: 8),
                  _SettingsToggleRow(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Boost Toggle',
                    value: boostToggleEnabled,
                    onChanged: onToggleBoostToggle,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onLeaveSpace,
                      icon: const Icon(Icons.logout_rounded),
                      label: Text('Leave Space'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(
                          color: Colors.redAccent.withValues(alpha: 0.6),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white60, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _PlanetPathwayDisintegrationPage extends StatefulWidget {
  const _PlanetPathwayDisintegrationPage({
    required this.targetScene,
    this.showDreamDialog = false,
  });

  final SceneDefinition targetScene;
  final bool showDreamDialog;

  @override
  State<_PlanetPathwayDisintegrationPage> createState() =>
      _PlanetPathwayDisintegrationPageState();
}

class _PlanetPathwayDisintegrationPageState
    extends State<_PlanetPathwayDisintegrationPage>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _shakeController;
  Timer? _dreamTimer;
  bool _allowDissolve = false;
  bool _showDreamPrompt = false;
  bool _dissolveStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..repeat();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.stop();
      }
    });
    // Hard lock: never auto-start dissolve from lifecycle.
    // The only path is explicit user tap on the prompt button.
    _dreamTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showDreamPrompt = true);
    });
  }

  Future<void> _startDissolve() async {
    if (_dissolveStarted || !mounted) return;
    _dissolveStarted = true;
    _allowDissolve = true;
    setState(() {});
    await _controller.forward();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _dreamTimer?.cancel();
    _shakeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dissolve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([dissolve, _shakeController]),
        builder: (context, _) {
          final t = _allowDissolve ? dissolve.value.clamp(0.0, 1.0) : 0.0;
          final phase = _shakeController.value * pi * 2;
          final shakeStrength = 4.5 + 10.5 * t;
          final shakeX =
              sin(phase * 3.0) * shakeStrength +
              cos(phase * 9.0) * (1.2 + 1.8 * t);
          final shakeY =
              cos(phase * 2.2) * (shakeStrength * 0.48) +
              sin(phase * 6.4) * (0.8 + 1.4 * t);
          final valleyOpacity = (1.0 - pow(t, 0.58)).clamp(0.0, 1.0);
          final targetOpacity = Curves.easeOutCubic.transform(t);
          final targetScale = 1.08 - (0.08 * t);
          final valleyScale = 1.0 + (0.12 * t);
          final glitchPulse =
              (_allowDissolve ? (sin(phase * 13.0).abs() * 0.35 + 0.65) : 0.0) *
              t;
          final finaleFlash = t > 0.78
              ? ((t - 0.78) / 0.22).clamp(0.0, 1.0)
              : 0.0;
          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: targetOpacity,
                child: Transform.scale(
                  scale: targetScale,
                  child: _buildSceneLayers(widget.targetScene),
                ),
              ),
              Opacity(
                opacity: valleyOpacity,
                child: Transform.translate(
                  offset: Offset(shakeX, shakeY),
                  child: Transform.scale(
                    scale: valleyScale,
                    child: _buildSceneLayers(valleySceneCorrected),
                  ),
                ),
              ),
              IgnorePointer(
                child: AlchemicalParticleBackground(
                  opacity: (0.25 + 0.75 * t).clamp(0.0, 1.0),
                  backgroundColor: Colors.transparent,
                  colors: const [
                    Color(0xFF000000),
                    Color(0xFF120014),
                    Color(0xFF1A0A24),
                    Color(0xFF2B0052),
                    Color(0xFF4A148C),
                  ],
                ),
              ),
              IgnorePointer(
                child: Container(
                  color: const Color(
                    0xFFE6D8FF,
                  ).withValues(alpha: 0.10 * glitchPulse + 0.35 * finaleFlash),
                ),
              ),
              IgnorePointer(
                child: Container(
                  color: const Color(
                    0xFF8A2BE2,
                  ).withValues(alpha: 0.08 * glitchPulse),
                ),
              ),
              IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35 + 0.52 * t),
                ),
              ),
              if (_showDreamPrompt)
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 620),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                        width: 1.4,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'AM I DREAMING?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 2.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No, I am finally awake.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            height: 1.35,
                            fontFamily: appFontFamily(context),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton(
                          onPressed: () async {
                            setState(() => _showDreamPrompt = false);
                            await Future.delayed(
                              const Duration(milliseconds: 120),
                            );
                            await _startDissolve();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.7),
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          child: Text(
                            'ENTER',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSceneLayers(SceneDefinition scene) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final layer in scene.layers)
          if (layer.imagePath.isNotEmpty)
            Image.asset(
              'assets/images/${layer.imagePath}',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
            ),
      ],
    );
  }
}

class _PlanetApproachTransitionPage extends StatefulWidget {
  const _PlanetApproachTransitionPage({required this.color});

  final Color color;

  @override
  State<_PlanetApproachTransitionPage> createState() =>
      _PlanetApproachTransitionPageState();
}

class _PlanetApproachTransitionPageState
    extends State<_PlanetApproachTransitionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _controller.forward().whenComplete(() {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInCubic,
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: curve,
        builder: (context, _) {
          final t = curve.value.clamp(0.0, 1.0);
          final scale = 0.15 + (14.0 - 0.15) * t;
          final glow = (1.0 - t).clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black.withValues(alpha: 0.58 + 0.42 * t)),
              Center(
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          widget.color.withValues(alpha: 0.95),
                          widget.color.withValues(alpha: 0.65),
                          widget.color.withValues(alpha: 0.22),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.58 * glow),
                          blurRadius: 90,
                          spreadRadius: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// TOP HUD (meter + controls)
// ─────────────────────────────────────────────────────────
