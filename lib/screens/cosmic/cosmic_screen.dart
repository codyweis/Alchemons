// Organized refactor of cosmic_screen.dart

import 'dart:convert';
import 'dart:math';

import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/screens/cosmic/cosmic_summon_screen.dart';
import 'package:alchemons/screens/cosmic/space_market_sheet.dart';
import 'package:alchemons/screens/cosmic/cosmic_sell_sheet.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/wilderness/rift_portal_component.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/services/wildlife_generator.dart';
import 'package:alchemons/models/creature_stats.dart';
import 'package:alchemons/screens/scenes/rift_portal_screen.dart';
import 'package:alchemons/screens/cosmic/elemental_nexus_screen.dart';
import 'package:alchemons/screens/cosmic/battle_ring_screen.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/instance_widgets/intance_filter_panel.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Local widget imports
import 'models/map_marker.dart';
import 'models/cosmic_summon_result.dart';
import 'widgets/top_hud.dart';
import 'widgets/widgets.dart';
import 'widgets/mini_map_overlay.dart';
import 'widgets/summon_popup.dart';
import 'widgets/planet_recipe_hud.dart';
import 'widgets/home_planet_menu_overlay.dart';
import 'widgets/chamber_picker_overlay.dart';
import 'widgets/elements_captured_popup.dart';
import 'widgets/customization_menu_overlay.dart';
import 'widgets/ship_menu_overlay.dart';
import 'widgets/virtual_joystick.dart';
import 'widgets/cosmic_party_picker_overlay.dart';

class CosmicScreen extends StatefulWidget {
  const CosmicScreen({super.key});

  @override
  State<CosmicScreen> createState() => _CosmicScreenState();
}

class _CosmicScreenState extends State<CosmicScreen>
    with TickerProviderStateMixin {
  static const _prefsKey = 'cosmic_fog_state_v2';
  static const _seedKey = 'cosmic_world_seed_v2';

  late int _worldSeed;
  late CosmicWorld _world;
  CosmicGame? _game;
  Map<String, Map<String, int>>? _recipes;
  bool _showMiniMap = false;
  CosmicSummonResult? _summonResult;
  bool _arcaneUnlocked = false;

  // Recipe & storage state
  CosmicPlanet? _nearPlanet;
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

  // Joystick toggle (off by default)
  bool _showJoystick = false;

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
  List<MapMarker> _mapMarkers = [];

  // Home customization state
  HomeCustomizationState _customizationState = HomeCustomizationState();
  static const _customizationPrefsKey = 'cosmic_home_customization_v1';
  bool _showCustomizationMenu = false;
  bool _showChamberPicker = false;
  bool _showShipMenu = false;
  bool _showHomeMenu = false;
  bool _showPartyPicker = false;
  bool _showGarrisonPicker = false;

  // Cosmic party state
  int _cosmicPartySlotsUnlocked = 0;
  List<CosmicPartyMember?> _partyMembers =
      []; // length = _cosmicPartySlotsUnlocked
  int? _activeCompanionSlot; // which slot is currently summoned (-1=none)

  /// Tracks HP fraction (0.0–1.0) for each party slot between summons.
  /// 1.0 = full health, 0.0 = dead. Reset to 1.0 when near home.
  final Map<int, double> _companionHpFraction = {};

  // Home garrison state (alchemons stationed at home planet)
  List<CosmicPartyMember?> _garrisonMembers = [];

  bool get _anyOverlayOpen =>
      _showCustomizationMenu ||
      _showChamberPicker ||
      _showShipMenu ||
      _showHomeMenu ||
      _showPartyPicker ||
      _showGarrisonPicker;

  // Meter animation
  late AnimationController _meterPulse;
  late AnimationController _miniMapCtrl;
  late AnimationController _planetMeterCtrl;

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
      duration: const Duration(milliseconds: 320),
    );

    _planetMeterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
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
    _showJoystick = prefs.getBool('cosmic_joystick_enabled') ?? false;

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

    // Load map markers
    final markersRaw = prefs.getString(_markersPrefsKey);
    if (markersRaw != null && markersRaw.isNotEmpty) {
      _mapMarkers = MapMarker.deserialiseList(markersRaw);
    }

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
      onHomePlanetBuilt: _onHomePlanetBuilt,

      onBossSpawned: _onBossSpawned,
      onShipDied: _onShipDied,
      onLootCollected: _onLootCollected,
      onBossDefeated: _onBossDefeated,
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

    if (savedFog != null) {
      // Defer restoring fog until after onLoad
      WidgetsBinding.instance.addPostFrameCallback((_) {
        game.restoreFogState(savedFog!);
        // Restore star dust after fog
        if (_collectedDust.isNotEmpty) {
          game.restoreStarDust(_collectedDust);
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
        if (_homePlanet != null) {
          game.restoreHomePlanet(_homePlanet!);
          _initOrbitalChambers();
        }
        _initCosmicParty();
        _initGarrison();
      });
    }

    if (mounted) setState(() {});
  }

  /// Load creature blob slots and spawn orbital chambers around home planet.
  Future<void> _initOrbitalChambers() async {
    if (_game == null || _homePlanet == null || !mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();

    // Load unlocked blob slots (1–3)
    final slots = await db.settingsDao.getBlobSlotsUnlocked();
    final savedIds = await db.settingsDao.getBlobInstanceSlots();

    final chamberData = <(Color, String?, String?, String?, String?)>[];

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
          chamberData.add((color, inst.instanceId, inst.baseId, name, imgPath));
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
    if (_game == null || slotIndex >= _partyMembers.length) return;
    // Block swapping companions during a ring battle
    if (_game!.battleRing.inBattle) {
      _showQuote('Cannot swap companions during a battle ring fight!');
      return;
    }
    final member = _partyMembers[slotIndex];
    if (member == null) return;
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
    _game!.summonCompanion(member, hpFraction: hpFrac);
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

  /// Persist the active companion's current HP fraction before returning it.
  void _saveCompanionHp() {
    final comp = _game?.activeCompanion;
    if (comp != null && _activeCompanionSlot != null) {
      _companionHpFraction[_activeCompanionSlot!] = comp.hpPercent;
    }
  }

  void _onCompanionAutoReturned() {
    if (!mounted) return;
    // During a ring battle the companion must stay deployed.
    if (_game?.battleRing.inBattle == true) return;
    setState(() => _activeCompanionSlot = null);
  }

  void _onCompanionDied(CosmicPartyMember member) {
    if (!mounted) return;
    // If in a ring battle the loss callback handles everything – just clean up here.
    if (_game?.battleRing.inBattle == true) {
      // Mark slot dead and clear, but don't drain stamina (ring is consequence-free).
      if (_activeCompanionSlot != null) {
        _companionHpFraction[_activeCompanionSlot!] = 0.0;
      }
      setState(() => _activeCompanionSlot = null);
      return;
    }
    // Mark this slot as dead (0 HP)
    if (_activeCompanionSlot != null) {
      _companionHpFraction[_activeCompanionSlot!] = 0.0;
    }
    // Drain the dead companion's stamina to 0
    final db = context.read<AlchemonsDatabase>();
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    db.creatureDao.updateStamina(
      instanceId: member.instanceId,
      staminaBars: 0,
      staminaLastUtcMs: nowMs,
    );
    setState(() => _activeCompanionSlot = null);
    // Refresh party so the dead member is removed (stamina gate)
    _initCosmicParty();
  }

  /// Called when the prismatic field easter-egg reward is claimed.
  Future<void> _onPrismaticRewardClaimed() async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    await db.settingsDao.setCosmicPrismaticRewardClaimed(true);
    await db.currencyDao.addGold(50);
    if (mounted) setState(() {});
  }

  // ── Garrison (home base alchemons) ──

  /// Number of garrison slots = activeSizeTier + 1 (1-5).
  int get _garrisonSlots => (_homePlanet?.activeSizeTier ?? 0) + 1;

  Future<void> _initGarrison() async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final savedIds = await db.settingsDao.getCosmicGarrisonSlots();
    final slots = _garrisonSlots;

    final members = <CosmicPartyMember?>[];
    for (var i = 0; i < slots; i++) {
      final id = i < savedIds.length ? savedIds[i] : null;
      if (id != null) {
        final inst = await db.creatureDao.getInstance(id);
        if (inst != null) {
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
          if (planet != null)
            _planetMeterCtrl.forward(from: 0.0);
          else
            _planetMeterCtrl.reverse();
        }
      });
    }
  }

  void _onStarDustCollected(int index) {
    _collectedDust.add(index);
    _saveStarDust();
    if (mounted) {
      HapticFeedback.lightImpact();
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

    // Navigate to RiftPortalScreen with empty party (harvester-only capture)
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RiftPortalScreen(
          faction: faction,
          party: const [], // no Alchemons in space — harvester only
        ),
      ),
    );

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

      // Use level 9 stat-scaling (index 9 → level 10 equivalent)
      final levelForStats = 9;
      const startBase = 1.5;
      const maxCap = 4.75;
      final endBase = maxCap / 1.4;
      final statBase =
          startBase + (levelForStats * (endBase - startBase) / 9.0);
      double randStat() {
        return statBase + rng.nextDouble() * (statBase * 0.4);
      }

      final speed = randStat();
      final intelligence = randStat();
      final strength = randStat();
      final beauty = randStat();

      final base = catalog.getCreatureById(hydrated.id);
      final typeName = (base?.types.isNotEmpty ?? false)
          ? base!.types.first
          : 'Earth';
      final family = base?.mutationFamily ?? 'kin';
      final displayName = base?.name ?? hydrated.id;
      final sheet = base?.spriteData != null ? sheetFromCreature(base!) : null;

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
      _showQuote('Practice Arena — ${displayName} enters the ring!');
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

    // Stat scaling: base from 1.5 (level 0), max caps at 4.75 (level 9)
    const startBase = 1.5;
    const maxCap = 4.75;
    final endBase = maxCap / 1.4;
    final statBase = startBase + (level * (endBase - startBase) / 9.0);
    final rng = Random();
    double randStat() => statBase + rng.nextDouble() * (statBase * 0.4);

    final speed = randStat();
    final intelligence = randStat();
    final strength = randStat();
    final beauty = randStat();

    // Build a CosmicPartyMember for the opponent
    final base = catalog.getCreatureById(hydrated.id);
    final typeName = (base?.types.isNotEmpty ?? false)
        ? base!.types.first
        : 'Earth';
    final family = base?.mutationFamily ?? 'kin';
    final displayName = base?.name ?? speciesId;
    final sheet = base?.spriteData != null ? sheetFromCreature(base!) : null;

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
    _showQuote('Level ${level + 1} — ${displayName} enters the ring!');
  }

  void _onBattleRingWon() {
    if (!mounted || _game == null) return;
    final br = _game!.battleRing;
    final goldReward = br.goldReward;
    final completedLevel = br.currentLevel;

    br.inBattle = false;
    br.currentLevel = (br.currentLevel + 1).clamp(0, BattleRing.maxLevels);
    _saveBattleRingState();

    // Award gold
    final db = context.read<AlchemonsDatabase>();
    db.currencyDao.addGold(goldReward);

    HapticFeedback.heavyImpact();
    // If we've reached the practice arena (all levels beaten), show a
    // distinct completion message.
    if (br.currentLevel >= BattleRing.maxLevels) {
      _showQuote('Practice completed! +$goldReward gold');
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

  void _onHomePlanetBuilt(HomePlanet planet) {
    _homePlanet = planet;
    _saveHomePlanet();
    _initOrbitalChambers();
    if (mounted) {
      HapticFeedback.heavyImpact();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
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

    _showQuote('Your ship was destroyed! Your Alchemons are exhausted…');
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

  void _openMarketShop() {
    if (_nearMarketPOI == null || _game == null) return;
    if (_nearMarketPOI!.type == POIType.cosmicMarket) {
      CosmicSellSheet.show(context);
      return;
    }
    SpaceMarketSheet.show(
      context,
      marketType: _nearMarketPOI!.type,
      meter: _game!.meter,
    );
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

  void _handleBuildHomePlanet() {
    if (_game == null || _homePlanet != null) return;
    final warning = _game!.buildHomePlanet();
    if (warning != null) {
      _showQuote(warning);
    }
  }

  static const int _relocateCost = 50;

  void _handleMoveHomePlanet() {
    if (_game == null || _homePlanet == null) return;
    if (_homePlanet!.astralBank < _relocateCost) {
      _showQuote('Not enough shards! Need $_relocateCost to relocate.');
      HapticFeedback.heavyImpact();
      return;
    }
    final warning = _game!.moveHomePlanet();
    if (warning != null) {
      _showQuote(warning);
      return;
    }
    _homePlanet!.astralBank -= _relocateCost;
    _saveHomePlanet();
    setState(() {});
  }

  /// Max meter fill % allowed for teleporting home.
  double get _teleportCapacity {
    return CargoUpgrade.capacityForLevel(_cargoLevel);
  }

  void _handleGoHome() {
    if (_game == null || _homePlanet == null) return;
    // Block teleport when meter is too full
    final meterPct = _game!.meter.fillPct;
    if (meterPct > _teleportCapacity) {
      final capPct = (_teleportCapacity * 100).round();
      _showQuote(
        'Too much elemental energy! Fly home or lighten below $capPct%.',
      );
      HapticFeedback.heavyImpact();
      return;
    }
    _game!.teleportTo(_homePlanet!.position);
    HapticFeedback.lightImpact();
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

    // Deposit into home planet colour mix (grows the planet)
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

  /// Builds a single party-slot button for slot index [i].
  Widget _buildPartySlotButton(int i) {
    final member = i < _partyMembers.length ? _partyMembers[i] : null;
    final isActive = _activeCompanionSlot == i;
    final hasActive = _activeCompanionSlot != null;
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
          ? (isDead
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
      onLongPress: () {
        if (!_isNearHome) {
          _showQuote('Return home to manage your party.');
          return;
        }
        setState(() => _showPartyPicker = true);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFE53935).withValues(alpha: 0.2)
              : isDead
              ? const Color(0xFFE53935).withValues(alpha: 0.08)
              : isDisabled
              ? Colors.black38
              : const Color(0xFF00E676).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? const Color(0xFFE53935)
                : isDead
                ? const Color(0xFFE53935).withValues(alpha: 0.3)
                : isDisabled
                ? Colors.white12
                : const Color(0xFF00E676).withValues(alpha: 0.7),
            width: isActive ? 2 : 1,
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
                            fontFamily: 'monospace',
                            color: const Color(
                              0xFFE53935,
                            ).withValues(alpha: 0.9),
                            fontSize: 6,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
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
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white24),
        ),
        title: const Text(
          'LEAVE EXPEDITION?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        content: Text(
          warningText,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
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
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white24),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'Cost: $cost',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4FC3F7),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
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

  void _handleSelectPlanetSize(int tier) {
    if (_homePlanet == null) return;
    if (tier > _homePlanet!.sizeTierLevel) return;
    _homePlanet!.activeSizeTier = tier;
    _saveHomePlanet();
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
    _showQuote('Unlocked $element colour!');
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

  void _handleFreeRefuel() {
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

  void _handleFreeMissiles() {
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
    return PlanetRecipe.generate(
      element: planet.element,
      seed: _worldSeed,
      version: _recipeState.versionFor(planet.element),
    );
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

  void _handleRecipeSummon() async {
    if (_game == null || !_game!.meter.isFull || _nearPlanet == null) return;

    final planet = _nearPlanet!;
    final recipe = _getRecipeForPlanet(planet);

    if (recipe.matches(_game!.meter.breakdown, _game!.meter.total)) {
      // ── SUCCESS: go straight to summon screen ──
      final targetElement = planet.element;
      final sceneKey = ElementMeter.sceneKeyForElement(targetElement);

      // Block arcane if not unlocked
      if (sceneKey == 'arcane' && !_arcaneUnlocked) {
        _handleElementsCaptured();
        return;
      }

      final catalog = context.read<CreatureCatalog>();
      final creatures = catalog.byType(targetElement);
      if (creatures.isEmpty) return;

      // Weighted rarity roll
      final rng = Random();
      final roll = rng.nextDouble();
      String targetRarity;
      if (roll < 0.03) {
        targetRarity = 'Legendary';
      } else if (roll < 0.15) {
        targetRarity = 'Rare';
      } else if (roll < 0.40) {
        targetRarity = 'Uncommon';
      } else {
        targetRarity = 'Common';
      }

      var candidates = creatures
          .where((c) => c.rarity == targetRarity)
          .toList();
      if (candidates.isEmpty) candidates = creatures;
      // Exclude Mystics
      candidates = candidates
          .where((c) => c.mutationFamily != 'Mystic')
          .toList();
      if (candidates.isEmpty) candidates = creatures;

      final chosen = candidates[rng.nextInt(candidates.length)];

      // Increment recipe version
      _recipeState = _recipeState.increment(targetElement);
      _saveRecipeState();

      // Reset meter
      _game?.meter.reset();
      _meterPulse.stop();
      _meterPulse.value = 0;

      // Navigate directly to the summon screen
      final portalColor = elementColor(targetElement);
      final success = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CosmicSummonScreen(
            speciesId: chosen.id,
            rarity: chosen.rarity,
            elementName: targetElement,
            portalColor: portalColor,
          ),
        ),
      );

      if (success == true && mounted) {
        _showQuote('${chosen.name} captured!');
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

    setState(() {
      _capturedBreakdown = breakdown;
      _showElementsCaptured = true;
    });
  }

  void _handleCompleteSummon() async {
    if (_summonResult == null) return;

    final result = _summonResult!;

    // Increment recipe version for this planet
    _recipeState = _recipeState.increment(result.resolvedElement);
    await _saveRecipeState();

    // Reset meter for next summon
    _game?.meter.reset();
    _meterPulse.stop();
    _meterPulse.value = 0;

    // Dismiss the summon popup
    setState(() => _summonResult = null);

    // Navigate to the cosmic summon portal screen
    final portalColor = elementColor(result.resolvedElement);
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CosmicSummonScreen(
          speciesId: result.speciesId,
          rarity: result.rarity,
          elementName: result.resolvedElement,
          portalColor: portalColor,
        ),
      ),
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
    _meterPulse.dispose();
    _quoteFade.dispose();
    _miniMapCtrl.dispose();
    _planetMeterCtrl.dispose();
    // Auto-save fog on exit
    _saveFogState();
    super.dispose();
  }

  void _toggleMiniMap() {
    if (!_showMiniMap) {
      setState(() => _showMiniMap = true);
      _miniMapCtrl.forward(from: 0.0);
    } else {
      _miniMapCtrl.reverse().then((_) {
        if (!mounted) return;
        setState(() => _showMiniMap = false);
      });
    }
  }

  void _closeMiniMap() {
    if (!_showMiniMap && !_miniMapCtrl.isAnimating) return;
    _miniMapCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _showMiniMap = false);
    });
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF020010),
        body: Stack(
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

            // ── Small map button (aligned with companion column) ──
            if (_summonResult == null && !_anyOverlayOpen)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                top: 120 + (_nearPlanet != null && !_isNearHome ? 72.0 : 0.0),
                left: 12,
                child: SafeArea(
                  child: GestureDetector(
                    onTap: _toggleMiniMap,
                    child: AnimatedBuilder(
                      animation: _miniMapCtrl,
                      builder: (context, child) {
                        final t = Curves.easeOutCubic.transform(
                          _miniMapCtrl.value,
                        );
                        final rot = (pi / 12) * t; // small tilt when open
                        final scale = 1.0 + 0.08 * t;
                        final color =
                            Color.lerp(
                              Colors.white54,
                              const Color(0xFFFFB300),
                              t,
                            ) ??
                            Colors.white54;
                        return Transform.rotate(
                          angle: rot,
                          child: Transform.scale(scale: scale, child: child),
                        );
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: const Icon(
                          Icons.map_rounded,
                          color: Colors.white60,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Slow-mode toggle (aligned under map button at companion column) ──
            if (_summonResult == null &&
                !_showMiniMap &&
                !_anyOverlayOpen &&
                _cosmicPartySlotsUnlocked > 0)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                top: 176 + (_nearPlanet != null && !_isNearHome ? 72.0 : 0.0),
                left: 12,
                child: SafeArea(
                  child: GestureDetector(
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
                            ? const Color(0xFFFFB300).withValues(alpha: 0.22)
                            : Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _slowMode
                              ? const Color(0xFFFFB300)
                              : Colors.white24,
                          width: _slowMode ? 2 : 1,
                        ),
                        boxShadow: _slowMode
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFFB300,
                                  ).withValues(alpha: 0.06),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: AnimatedScale(
                          scale: _slowMode ? 1.12 : 1.0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.elasticOut,
                          child: Icon(
                            Icons.slow_motion_video,
                            color: _slowMode
                                ? const Color(0xFFFFB300)
                                : Colors.white54,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
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
                      : const Color(0xFF00E5FF);
                  final mLabel = mType == POIType.harvesterMarket
                      ? 'HARVESTER SHOP'
                      : mType == POIType.riftKeyMarket
                      ? 'RIFT KEY SHOP'
                      : 'COSMIC MARKET';
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
                                      : 'ENTER SHOP',
                                  style: const TextStyle(
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
                    onDirectionChanged: (dir) {
                      _game?.joystickDirection = dir;
                    },
                  ),
                ),
              ),

            // ── Top HUD ──
            if (!_anyOverlayOpen)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _nearPlanet != null && !_isNearHome ? 0.25 : 1.0,
                  duration: const Duration(milliseconds: 300),
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
                      onBack: () async {
                        await _confirmLeave();
                      },
                      onMiniMap: _toggleMiniMap,
                      onMeterTap: _handleMeterTap,
                      showMeter: _nearPlanet == null || _isNearHome,
                    ),
                  ),
                ),
              ),

            // ── Planet recipe HUD (moved to top safe-area, compact)
            if (_nearPlanet != null &&
                !_isNearHome &&
                _summonResult == null &&
                !_showElementsCaptured &&
                !_showMiniMap &&
                !_anyOverlayOpen)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Animated alchemical meter above the planet HUD
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
                          PlanetRecipeHud(
                            planet: _nearPlanet!,
                            recipe: _getRecipeForPlanet(_nearPlanet!),
                            meter: _game!.meter,
                            onSummon: _game!.meter.isFull
                                ? _handleRecipeSummon
                                : null,
                          ),
                        ],
                      ),
                    ),
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
                    final t = Curves.easeOutCubic.transform(_miniMapCtrl.value);
                    final opacity = t.clamp(0.0, 1.0);
                    final translateY = (1 - t) * 40.0;
                    final scale = 0.98 + 0.02 * t;
                    return Opacity(
                      opacity: opacity,
                      child: Transform.translate(
                        offset: Offset(0, translateY),
                        child: Transform.scale(scale: scale, child: child),
                      ),
                    );
                  },
                  child: MiniMapOverlay(
                    world: _world,
                    game: _game!,
                    theme: theme,
                    markers: _mapMarkers,
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
                      _game?.teleportTo(pos);
                      _closeMiniMap();
                    },
                    onClose: _closeMiniMap,
                    onMarkersChanged: (markers) {
                      setState(() => _mapMarkers = markers);
                      _saveMapMarkers();
                    },
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
                  onDismiss: () =>
                      setState(() => _showElementsCaptured = false),
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
                  onClose: () => setState(() => _showCustomizationMenu = false),
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
                ),
              ),

            // ── Garrison picker overlay ──
            if (_showGarrisonPicker)
              Positioned.fill(
                child: CosmicPartyPickerOverlay(
                  title: 'HOME GARRISON',
                  maxSlots: _garrisonSlots,
                  slotsUnlocked: _garrisonSlots,
                  partyMembers: _garrisonMembers,
                  onAssign: _handleAssignGarrisonSlot,
                  onClear: _handleClearGarrisonSlot,
                  onClose: () => setState(() => _showGarrisonPicker = false),
                  hintText:
                      'Tap a slot to station an Alchemon.\nGarrison size grows with planet tier!',
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
                      style: const TextStyle(
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
                                style: const TextStyle(
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
                            style: const TextStyle(
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
                            const Text(
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
            if (_isNearHome &&
                _homePlanet != null &&
                _summonResult == null &&
                !_showElementsCaptured &&
                !_showMiniMap &&
                !_anyOverlayOpen)
              Positioned(
                bottom: 20,
                left: _showJoystick ? 120 : 0,
                right: _showJoystick ? 74 : 0,
                child: SafeArea(
                  child: Center(
                    child: _showJoystick
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // HOME BASE button
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _showHomeMenu = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: CosmicScreenStyles.bg1,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: CosmicScreenStyles.amber.withValues(alpha: 0.6),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: CosmicScreenStyles.amber.withValues(
                                          alpha: 0.25,
                                        ),
                                        blurRadius: 16,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              Color.lerp(
                                                _homePlanet!.blendedColor,
                                                Colors.white,
                                                0.3,
                                              )!,
                                              _homePlanet!.blendedColor,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _homePlanet!.blendedColor
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'HOME BASE',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: CosmicScreenStyles.textPrimary,
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
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: CosmicScreenStyles.amberGlow),
                                    boxShadow: [
                                      BoxShadow(
                                        color: CosmicScreenStyles.amber.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'DEPOSIT',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
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
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _showHomeMenu = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: CosmicScreenStyles.bg1,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: CosmicScreenStyles.amber.withValues(alpha: 0.6),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: CosmicScreenStyles.amber.withValues(
                                          alpha: 0.25,
                                        ),
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
                                                _homePlanet!.blendedColor,
                                                Colors.white,
                                                0.3,
                                              )!,
                                              _homePlanet!.blendedColor,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _homePlanet!.blendedColor
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'HOME BASE',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: CosmicScreenStyles.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _handleDepositAll,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: CosmicScreenStyles.amber,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: CosmicScreenStyles.amberGlow),
                                    boxShadow: [
                                      BoxShadow(
                                        color: CosmicScreenStyles.amber.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'DEPOSIT',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
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
            // (Fuel & missiles now auto-refill at home — no buttons needed)

            // ── Action buttons (right side — 2-column grid) ──
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
                        // Top row: Ship Menu
                        GestureDetector(
                          onTap: () => setState(() => _showShipMenu = true),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(
                                  0xFF00E5FF,
                                ).withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.rocket_launch_rounded,
                              color: Color(0xFF00E5FF),
                              size: 23,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Middle row: boost (party slots moved to right column)
                        Row(
                          mainAxisSize: MainAxisSize.min,
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
                                onTap: _boostToggleMode
                                    ? _toggleBoosting
                                    : null,
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
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Bottom row: weapon buttons (party slots moved to right column)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
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
                                  // Missile button (only if equipped) — now on top
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
                                              fontFamily: 'monospace',
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
                                  const SizedBox(height: 10),
                                  // Shoot button (hidden when tap-to-shoot is on)
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
                      ],
                    ),
                  ),
                ),
              ),

            // ── Companion column (stacked on right side) ──
            if (_summonResult == null &&
                !_showMiniMap &&
                !_anyOverlayOpen &&
                _cosmicPartySlotsUnlocked > 0)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                right: 12,
                top: 120 + (_nearPlanet != null && !_isNearHome ? 72.0 : 0.0),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < _cosmicPartySlotsUnlocked && i < 3; i++) ...[
                        // Small health bar above each companion slot
                        Builder(builder: (_) {
                          final member = i < _partyMembers.length ? _partyMembers[i] : null;
                          final isActive = _activeCompanionSlot == i;
                          final hpFrac = isActive
                              ? (_game?.activeCompanion?.hpPercent ?? (_companionHpFraction[i] ?? 1.0))
                              : (_companionHpFraction[i] ?? 1.0);
                          return SizedBox(
                            width: 44,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isActive ? Colors.white12 : Colors.white10,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: isActive ? Colors.white10 : Colors.white12,
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
                                          color: (hpFrac > 0.5
                                                  ? const Color(0xFF00E676)
                                                  : hpFrac > 0.25
                                                      ? const Color(0xFFFFEA00)
                                                      : const Color(0xFFE53935))
                                              .withOpacity(isActive ? 1.0 : 0.35),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          );
                        }),
                        _buildPartySlotButton(i),
                        if (i < _cosmicPartySlotsUnlocked - 1) const SizedBox(height: 8),
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
                onClose: () => setState(() => _showShipMenu = false),
                onGoHome: () {
                  setState(() => _showShipMenu = false);
                  _handleGoHome();
                },
                onBuildHome: () {
                  setState(() => _showShipMenu = false);
                  _handleBuildHomePlanet();
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
                hasParty: _cosmicPartySlotsUnlocked > 0,
                onParty: () {
                  setState(() {
                    _showShipMenu = false;
                    _showPartyPicker = true;
                  });
                },
                joystickEnabled: _showJoystick,
                onToggleJoystick: (v) async {
                  setState(() => _showJoystick = v);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('cosmic_joystick_enabled', v);
                },
                tapToShootEnabled: _tapToShoot,
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
                boostToggleEnabled: _boostToggleMode,
                onToggleBoostToggle: (v) async {
                  setState(() {
                    _boostToggleMode = v;
                    if (!v && _isBoosting) _stopBoosting();
                  });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('cosmic_boost_toggle', v);
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// TOP HUD (meter + controls)
// ─────────────────────────────────────────────────────────

