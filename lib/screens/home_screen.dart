import 'package:alchemons/models/shop_scenes.dart';
import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:alchemons/utils/section_router.dart';
import 'package:alchemons/widgets/exit_game_dialog.dart';
import 'package:alchemons/widgets/half_cultivation_chip.dart';
import 'package:alchemons/widgets/particle_title.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/audio/audio.dart';
// (imports unchanged except where noted)
import 'dart:async' as async;
import 'dart:math';

import 'package:alchemons/screens/extraction_hub_screen.dart';
import 'package:alchemons/screens/pureblood_rite_screen.dart';
import 'package:alchemons/screens/splash_screen.dart';
import 'package:alchemons/models/biome_farm_state.dart';
import 'package:alchemons/navigation/home_descent.dart';
import 'package:alchemons/games/heart_puzzle/alchemy_unlock.dart';
import 'package:alchemons/navigation/emblem_passage.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/games/cosmic_survival/components/survival_lobby_stage.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_screen.dart';
import 'package:alchemons/screens/competition_hub_screen.dart';
import 'package:alchemons/screens/cosmic/cosmic_screen.dart';
import 'package:alchemons/screens/inventory_screen.dart';
import 'package:alchemons/screens/map_screen.dart';
import 'package:alchemons/screens/upgrade_tree/constellation_points_widget.dart';
import 'package:alchemons/screens/mystic_altar/mystic_altar_screen.dart';
import 'package:alchemons/data/mystic_altar_data.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alchemons/services/harvest_service.dart';
import 'package:alchemons/services/notification_preferences_service.dart';
import 'package:alchemons/services/push_notification_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/cosmic_memory_tutorial_service.dart';
import 'package:alchemons/services/encounter_service.dart';
import 'package:alchemons/services/new_discovery_reveal_controller.dart';
import 'package:alchemons/services/opening_wilderness_service.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/game_data_gate.dart';
import 'package:alchemons/utils/specimen_picker_route.dart';
import 'package:alchemons/widgets/avatar_widget.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';

import 'package:alchemons/widgets/creature_showcase_widget.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/currency_display_widget.dart';
import 'package:alchemons/widgets/daily_reliquary.dart';
import 'package:alchemons/widgets/loading_widget.dart';
import 'package:alchemons/widgets/notification_banner_system.dart';
import 'package:alchemons/services/survival_upgrade_service.dart';
import 'package:alchemons/widgets/dock_passages.dart';
import 'package:alchemons/widgets/dock_emblems.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show SpecimenGrains;
import 'package:alchemons/widgets/side_dock_widget.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flame/flame.dart' show Flame;
import 'package:flutter/cupertino.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/fx/starter_vial_handoff.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/screens/creatures_screen.dart';
import 'package:alchemons/screens/feeding/feeding_screen.dart';
import 'package:alchemons/screens/profile_screen.dart';
import 'package:alchemons/widgets/campaign_rewards_button.dart';
import 'package:alchemons/screens/shop/shop_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/starter_grant_service.dart';
import 'package:alchemons/widgets/background/faction_realm.dart';
import 'package:alchemons/screens/home_biome/home_biome_window.dart';
import 'package:alchemons/widgets/alchemy_emblem.dart';
import 'package:alchemons/widgets/home_emblems.dart';
import 'package:alchemons/screens/heart_puzzle/altar_levels_screen.dart';
import 'package:alchemons/screens/alchemical_encyclopedia_screen.dart';
import 'package:alchemons/widgets/home_portal.dart';
import 'package:alchemons/widgets/story_dialog.dart';
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';
import 'breed/breed_screen.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';

const bool kEnableCosmicShip = true;

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  NavSection _currentSection = NavSection.home;
  final Set<int> _warmedNavigationIndexes = {0};
  bool _warmingNavigation = true;

  /// True once the warm-up splash has finished fading out and is unmounted.
  bool _splashFaded = false;
  String _warmupStatus = 'Preparing home';
  double _warmupProgress = 0.76;

  final GlobalKey<CreaturesScreenState> _creaturesKey =
      GlobalKey<CreaturesScreenState>();

  // NEW: guard so we only request once per launch
  bool _creaturesTutorialRequested = false;

  /// Bumped every time something asks to land on the cultivations side of the
  /// breed tab. The breed screen owns its own mode and remembers it, so
  /// naming the section is not enough — a player who left it on Fusion would
  /// arrive at Fusion. A counter rather than a flag so a second request
  /// still registers as a change.
  int _breedCultivationsFocus = 0;

  @override
  void initState() {
    super.initState();
    NewDiscoveryReveal.instance.onSwitchSection = (section) {
      if (!mounted) return;
      _goToSection(section, withHaptic: false);
    };
    SectionRouter.instance.onSwitchSection =
        (section, {SectionFocus focus = SectionFocus.none}) {
          if (!mounted) return;
          _goToSection(section, withHaptic: false, focus: focus);
        };
    StarterVialHandoff.instance.markShellWarming();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A notification tap can cold-start the app and be read before this
      // shell exists; the request parks on the router until now.
      SectionRouter.instance.drainPending();
      _warmNavigationScreens();
    });
  }

  Future<void> _warmNavigationScreens() async {
    const screens = <(int, String, double)>[
      (1, 'Organizing your Alchemons', 0.82),
      (2, 'Stocking the markets', 0.88),
      (3, 'Preparing the breeding lab', 0.94),
      (4, 'Sorting your inventory', 0.98),
    ];

    // Render the message before mounting each expensive destination. This
    // spreads the work across frames while keeping it behind the splash.
    for (final (index, status, progress) in screens) {
      if (!mounted) return;
      setState(() {
        _warmupStatus = status;
        _warmupProgress = progress;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      setState(() => _warmedNavigationIndexes.add(index));
      await WidgetsBinding.instance.endOfFrame;
    }

    if (!mounted) return;
    setState(() {
      _warmupStatus = 'Ready';
      _warmupProgress = 1;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) setState(() => _warmingNavigation = false);
  }

  @override
  void dispose() {
    if (NewDiscoveryReveal.instance.onSwitchSection != null) {
      NewDiscoveryReveal.instance.onSwitchSection = null;
    }
    // A singleton holding a closure over a dead State is how the account
    // reset used to leave a grey screen behind.
    SectionRouter.instance.onSwitchSection = null;
    super.dispose();
  }

  void _goToSection(
    NavSection section, {
    int? breedInitialTab,
    bool withHaptic = true,
    SectionFocus focus = SectionFocus.none,
  }) {
    // breedInitialTab 1 is the old name for the cultivations side; the
    // tutorial hand-offs still pass it, and it used to be ignored, so a player
    // who last left Breed on FUSION was sent there instead of to their vial.
    final wantsCultivations =
        focus == SectionFocus.cultivations ||
        (section == NavSection.breed && breedInitialTab == 1);

    // Already there and nothing to re-aim: nothing to do. The focus request
    // is checked first so a tap that lands on the tab the player is already
    // looking at still swings it to the cultivations side.
    if (section == _currentSection && !wantsCultivations) return;

    if (section == _currentSection) {
      setState(() => _breedCultivationsFocus++);
      return;
    }

    if (withHaptic) HapticFeedback.selectionClick();

    // Unfocus the creatures search field when leaving that tab
    if (_currentSection == NavSection.creatures) {
      _creaturesKey.currentState?.unfocusSearch();
    }

    setState(() {
      _currentSection = section;
      if (wantsCultivations) _breedCultivationsFocus++;
    });
    if (withHaptic) {
      HapticFeedback.mediumImpact();
    }

    // The tab destinations record their task here rather than in their own
    // initState, because the shell MOUNTS them at startup to warm them —
    // so initState fires for the shop and the inventory on a save that has
    // never opened either, and both tasks completed themselves. Being
    // built is not being visited.
    final arrived = switch (section) {
      NavSection.shop => 'shop',
      NavSection.inventory => 'inventory',
      _ => null,
    };
    if (arrived != null) {
      OnboardingTaskService.recordArrival(context, arrived);
    }

    // Trigger tutorials when user actually visits these sections:
    //
    // Not when a new discovery brought us here. The reveal switches to this
    // section itself, so the first extraction opened the database tutorial on
    // top of the extraction result — and the pop that was meant to dismiss the
    // result closed the tutorial instead, leaving the result stranded, while
    // the filing-away card flew at a catalog hidden behind a modal. The flag
    // stays unset, so the tutorial greets them on their next real visit.
    final revealInFlight =
        NewDiscoveryReveal.instance.pendingRevealCreatureId.value != null;
    if (section == NavSection.creatures &&
        !_creaturesTutorialRequested &&
        !revealInFlight) {
      _creaturesTutorialRequested = true;
      _creaturesKey.currentState?.maybeShowCreaturesTutorial();
    }
  }

  int get _navIndex {
    switch (_currentSection) {
      case NavSection.home:
        return 0;
      case NavSection.creatures:
        return 1;
      case NavSection.shop:
        return 2;
      case NavSection.breed:
        return 3;
      case NavSection.inventory:
        return 4;
    }
  }

  Widget _buildNavigationScreen(int index) {
    switch (index) {
      case 0:
        return HomeScreen(
          isActive: _currentSection == NavSection.home,
          onNavigateSection: _goToSection,
        );
      case 1:
        return CreaturesScreen(key: _creaturesKey);
      case 2:
        return const ShopScreen();
      case 3:
        return BreedScreen(
          onGoToSection: _goToSection,
          isActive: _currentSection == NavSection.breed,
          cultivationsFocusToken: _breedCultivationsFocus,
        );
      case 4:
        return const InventoryScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _handleExitAttempt() async {
    if (_currentSection != NavSection.home) {
      _goToSection(NavSection.home);
      return;
    }

    final shouldExit = await showExitGameDialog(context);

    if (shouldExit == true) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !mounted) return;
        await _handleExitAttempt();
      },
      child: Stack(
        children: [
          Scaffold(
            extendBody: true,
            body: IndexedStack(
              index: _navIndex,
              children: List.generate(5, (index) {
                if (!_warmedNavigationIndexes.contains(index)) {
                  return const SizedBox.shrink();
                }
                return TickerMode(
                  enabled: index == _navIndex,
                  child: _buildNavigationScreen(index),
                );
              }),
            ),
            bottomNavigationBar: BottomNav(
              current: _currentSection,
              onSelect: (s) => _goToSection(s, withHaptic: false),
              theme: theme,
              faction: context.watch<FactionService>().current,
            ),
          ),
          // The splash dissolves into home rather than cutting: touches pass
          // through the moment warm-up ends, and it unmounts once faded.
          if (!_splashFaded)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_warmingNavigation,
                child: AnimatedOpacity(
                  opacity: _warmingNavigation ? 1 : 0,
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOut,
                  onEnd: () {
                    if (mounted && !_warmingNavigation) {
                      setState(() => _splashFaded = true);
                      StarterVialHandoff.instance.markShellReady();
                    }
                  },
                  child: AlchemonsSplash(
                    status: _warmupStatus,
                    progress: _warmupProgress,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Wrapper that pulses the cosmic orb when the ship home-animation flag is pending.
class _AnimatedCosmicOrb extends StatefulWidget {
  final VoidCallback? onPulse;
  final bool animate;
  const _AnimatedCosmicOrb({this.onPulse, this.animate = true});

  @override
  State<_AnimatedCosmicOrb> createState() => _AnimatedCosmicOrbState();
}

class _AnimatedCosmicOrbState extends State<_AnimatedCosmicOrb>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  Animation<double>? _scale;
  bool _visible = false;
  bool _wiredSettings = false;
  bool _isPulsing = false;
  async.StreamSubscription<String?>? _shipUnlockedSub;
  async.StreamSubscription<String?>? _shipAnimPendingSub;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.42), weight: 44),
      TweenSequenceItem(tween: Tween(begin: 1.42, end: 1.08), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.34), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 1.34, end: 1.0), weight: 18),
    ]).animate(CurvedAnimation(parent: _ctrl!, curve: Curves.easeInOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wiredSettings) return;
    _wiredSettings = true;
    final db = context.read<AlchemonsDatabase>();

    _shipUnlockedSub = db.settingsDao
        .watchSetting('cosmic_ship_unlocked')
        .listen((raw) {
          final unlocked = raw == '1';
          if (!mounted || unlocked == _visible) return;
          setState(() => _visible = unlocked);
        });

    _shipAnimPendingSub = db.settingsDao
        .watchSetting('cosmic_ship_home_anim_pending')
        .listen((raw) {
          if (raw == '1') {
            _consumePendingPulse(db);
          }
        });
  }

  Future<void> _consumePendingPulse(AlchemonsDatabase db) async {
    if (!mounted || _isPulsing) return;
    _isPulsing = true;
    widget.onPulse?.call();

    try {
      _ctrl?.stop();
      _ctrl?.reset();
      await _ctrl?.forward();
      await Future.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      _ctrl?.reset();
      await _ctrl?.forward();
    } catch (_) {
      // ignore animation errors if lifecycle changes mid-pulse
    } finally {
      try {
        await db.settingsDao.deleteSetting('cosmic_ship_home_anim_pending');
      } catch (_) {}
      _isPulsing = false;
    }
  }

  @override
  void dispose() {
    _shipUnlockedSub?.cancel();
    _shipAnimPendingSub?.cancel();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _ctrl!,
      builder: (context, child) {
        final s = _scale?.value ?? 1.0;
        return Transform.scale(scale: s, child: child);
      },
      child: CosmicOrbWidget(animate: widget.animate),
    );
  }
}

class _AnimatedPurebloodRiteIcon extends StatefulWidget {
  const _AnimatedPurebloodRiteIcon({
    required this.enabled,
    required this.onTap,
    this.onPulse,
  });

  final bool enabled;

  /// Opens the rite through the emblem under [from]; [lifted] is held true
  /// while it is away.
  final void Function(GlobalKey from, ValueNotifier<bool> lifted) onTap;
  final VoidCallback? onPulse;

  @override
  State<_AnimatedPurebloodRiteIcon> createState() =>
      _AnimatedPurebloodRiteIconState();
}

class _AnimatedPurebloodRiteIconState extends State<_AnimatedPurebloodRiteIcon>
    with SingleTickerProviderStateMixin {
  static const String _seenKey = 'pureblood_rite_home_seen';

  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  final GlobalKey _emblem = GlobalKey();
  final ValueNotifier<bool> _lifted = ValueNotifier(false);
  bool _checkingSeen = false;
  bool _resolvedSeen = false;
  bool _isPulsing = false;
  bool _isNew = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybePulseOnFirstShow();
  }

  @override
  void didUpdateWidget(covariant _AnimatedPurebloodRiteIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled) {
      _maybePulseOnFirstShow();
    }
  }

  Future<void> _maybePulseOnFirstShow() async {
    if (!widget.enabled || _checkingSeen || _resolvedSeen) {
      return;
    }

    _checkingSeen = true;
    try {
      final db = context.read<AlchemonsDatabase>();
      final seen = await db.settingsDao.getSetting(_seenKey) == '1';
      if (!mounted) {
        return;
      }

      if (seen) {
        _resolvedSeen = true;
        return;
      }

      _resolvedSeen = true;
      _isNew = true;
      if (!mounted || !widget.enabled) {
        return;
      }
      await _playPulse();
    } finally {
      _checkingSeen = false;
    }
  }

  Future<void> _playPulse() async {
    if (_isPulsing || !mounted) {
      return;
    }

    _isPulsing = true;
    widget.onPulse?.call();
    try {
      _ctrl.stop();
      _ctrl.reset();
      for (var i = 0; i < 3; i++) {
        _ctrl.reset();
        await _ctrl.forward();
        if (i < 2) {
          await Future.delayed(const Duration(milliseconds: 120));
          if (!mounted) return;
        }
      }
    } catch (_) {
      // Ignore animation interruptions during navigation/lifecycle changes.
    } finally {
      _isPulsing = false;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _lifted.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final pulse = sin(_ctrl.value * pi).clamp(0.0, 1.0);
        return Transform.scale(
          scale: _scale.value,
          child: GestureDetector(
            onTap: context.soundAction(() async {
              if (_isNew) {
                final db = context.read<AlchemonsDatabase>();
                await db.settingsDao.setSetting(_seenKey, '1');
                if (mounted) setState(() => _isNew = false);
              }
              widget.onTap(_emblem, _lifted);
            }),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    HomeEmblem(
                      key: _emblem,
                      kind: HomeEmblemKind.rite,
                      size: 68,
                      animate: widget.enabled,
                      lifted: _lifted,
                    ),
                    if (_isNew)
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB91C1C),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white70),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: Text(
                    'RITE',
                    style: TextStyle(
                      color: Color.lerp(
                        theme.text,
                        const Color(0xFFFFC9C9),
                        pulse,
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  final bool isActive;
  final void Function(NavSection section, {int? breedInitialTab})
  onNavigateSection;

  const HomeScreen({
    super.key,
    required this.isActive,
    required this.onNavigateSection,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, RouteAware, WidgetsBindingObserver {
  static const List<String> _coreWildernessBiomes = [
    'valley',
    'sky',
    'volcano',
    'swamp',
  ];

  late AnimationController _breathingController;
  late AnimationController _shakeController;
  late AnimationController _enhanceRevealController;
  bool? _lastEnhanceUnlocked;
  bool _enhanceCelebrationChecking = false;
  bool _enhanceHighlightActive = false;

  /// The achievements bar can be swiped right to park against the edge.
  static const _achievementsDockedKey = 'home_achievements_docked';
  bool _achievementsDocked = false;

  Future<void> _loadAchievementsDocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final docked = prefs.getBool(_achievementsDockedKey) ?? false;
      if (mounted && docked != _achievementsDocked) {
        setState(() => _achievementsDocked = docked);
      }
    } catch (_) {}
  }

  void _setAchievementsDocked(bool docked) {
    if (docked == _achievementsDocked) return;
    HapticFeedback.selectionClick();
    setState(() => _achievementsDocked = docked);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_achievementsDockedKey, docked))
        .catchError((_) => false);
  }

  final PushNotificationService _pushNotifications = PushNotificationService();
  static const String _eggNotificationStateType = 'egg_ready';
  static const String _harvestNotificationStateType = 'harvest_ready';
  String? _lastEggStateKey;
  String? _lastHarvestStateKey;
  String? _lastWildernessStateKey;
  final Map<int, int> _lastScheduledEggHatchMsBySlot = {};
  Set<int> _lastReadyEggSlotIds = <int>{};
  Set<int> _lastReadyHarvestBiomeIds = <int>{};
  bool _eggNotificationStateHydrated = false;
  bool _harvestNotificationStateHydrated = false;

  bool _isFieldTutorialActive = false;

  /// Held from setup so teardown never has to consult the provider tree.
  WildernessSpawnService? _spawnServiceForTeardown;

  bool _hasAnyRelic = false;

  /// Survival is hidden, not disabled, until the cosmic portal is found. The
  /// button used to sit there permanently and answer a tap with "discover the
  /// cosmic portal to unlock Survival" — advertising a mode and naming the
  /// thing that gates it, which is both a spoiler and a dead control.
  bool _survivalUnlocked = false;
  bool _tutorialCheckInProgress =
      false; // prevents double-fire from didUpdateWidget + didPopNext
  bool _arcanePortalUnlocked = false;
  bool _isAppInForeground = true;
  bool _memoryHomeEventBusy = false;
  bool _memoryStoryShowing = false;

  bool _isInitialized = false;

  // ── Where the notices rest ─────────────────────────────────────────────
  //
  // In the open band between the featured specimen and the chest: up in the
  // toolbar they covered the player's coins, and lower down the title. Read
  // off the laid-out screen, because the header has no fixed height.
  final GlobalKey _homeStackKey = GlobalKey();
  final GlobalKey _headerKey = GlobalKey();
  final GlobalKey _heroSlotKey = GlobalKey();

  // ── The portal home ─────────────────────────────────────────────────────
  // Opened by the first descent from space: a circle drawn round the
  // featured Alchemon opens a window onto the home planet (home_portal.dart).

  /// The home background's sand, held here so the portal can stir and
  /// swirl it as well as a finger on the background does.
  FactionRealmField? _realmField;

  /// Round the featured sprite alone, read into grains as it falls in.
  final GlobalKey _heroSpriteKey = GlobalKey();

  /// The home portal round the featured Alchemon: where the way down to
  /// the home biome starts, and where the sand comes back to.
  final GlobalKey _homePortalKey = GlobalKey();

  bool _homePortalUnlocked = false;
  bool _homePortalOpen = false;

  /// Traces the circle until the first one is drawn.
  bool _homePortalGuide = false;
  bool _homePortalTelling = false;
  bool _homePortalDescending = false;

  /// Bumped on each return from the home biome: the window rebuilds it.
  int _homeBiomeVisit = 0;
  double? _noticeRestTop;

  void _measureNoticeRest() {
    if (!mounted) return;
    final stack = _homeStackKey.currentContext?.findRenderObject();
    final anchor = (_heroSlotKey.currentContext ?? _headerKey.currentContext)
        ?.findRenderObject();
    if (stack is! RenderBox || anchor is! RenderBox) return;
    if (!stack.hasSize || !anchor.hasSize) return;
    final bottom = stack
        .globalToLocal(anchor.localToGlobal(Offset(0, anchor.size.height)))
        .dy;
    final next = bottom + 6;
    if (_noticeRestTop == null || (next - _noticeRestTop!).abs() > 0.5) {
      setState(() => _noticeRestTop = next);
    }
  }

  // Notification banners
  final List<NotificationBanner> _activeNotifications = [];

  // Stream subscriptions for reactive notifications
  async.StreamSubscription<List<IncubatorSlot>>? _slotsSubscription;
  async.StreamSubscription<Set<String>>? _rosterSubscription;
  async.StreamSubscription<List<BiomeFarm>>? _biomesSubscription;

  // FEATURED HERO STATE
  PresentationData? _featuredData;
  String? _featuredInstanceId;

  /// Set when a new featured specimen is chosen: it gathers out of its
  /// element. Not on the home screen's own loads.
  EssenceReveal? _featuredReveal;
  bool _animationsEnabled = false;

  /// RELICS: the altar emblem the way into the Mystic Altar grows out of,
  /// and whether it is away doing so.
  final GlobalKey _relicEmblem = GlobalKey();
  final ValueNotifier<bool> _relicLifted = ValueNotifier(false);

  /// ALCHEMY: open once every formula is found; until then shown locked,
  /// lit as far as the player has come.
  AlchemyUnlock _alchemy = AlchemyUnlock.none;
  final GlobalKey _alchemyEmblem = GlobalKey();
  final ValueNotifier<bool> _alchemyLifted = ValueNotifier(false);

  Future<void> _refreshAlchemy() async {
    try {
      final u = await AlchemyUnlock.load(
        db: context.read<AlchemonsDatabase>(),
        catalog: context.read<CreatureCatalog>(),
      );
      if (mounted) setState(() => _alchemy = u);
    } catch (_) {}
  }

  Future<void> _openAlchemy() async {
    final u = _alchemy;
    if (!u.open) {
      HapticFeedback.selectionClick();
      // The way on is the encyclopedia: what is left to find is there.
      final go = await showStoryDialog(
        context,
        beats: [
          StoryBeat(
            title: 'Alchemy',
            message:
                'Opens once every element and species formula in the '
                'encyclopedia has been found.\n\n${u.found} of ${u.total} found.',
          ),
        ],
        primaryLabel: 'ENCYCLOPEDIA',
        secondaryLabel: 'CLOSE',
        barrierDismissible: true,
      );
      if (go == true && mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => const AlchemicalEncyclopediaScreen(),
          ),
        );
        // Formulas may have been seen there; read the count again.
        if (mounted) await _refreshAlchemy();
      }
      return;
    }
    HapticFeedback.heavyImpact();
    EmblemPassage.pushScene<void>(
      context,
      scene: const AlchemyPassageScene(),
      from: _alchemyEmblem,
      page: const AltarLevelsScreen(),
      lifted: _alchemyLifted,
    );
  }

  /// The dock's Field, Harvest, Survival and Enhance emblems, which carry
  /// the player to their screens the same way, and whether each is away
  /// doing so.
  final GlobalKey _fieldEmblem = GlobalKey();
  final GlobalKey _harvestEmblem = GlobalKey();
  final GlobalKey _survivalEmblem = GlobalKey();
  final GlobalKey _enhanceEmblem = GlobalKey();
  final ValueNotifier<bool> _fieldLifted = ValueNotifier(false);
  final ValueNotifier<bool> _harvestLifted = ValueNotifier(false);
  final ValueNotifier<bool> _survivalLifted = ValueNotifier(false);
  final ValueNotifier<bool> _enhanceLifted = ValueNotifier(false);

  void _updateAnimationState() {
    // home tab active AND this route is the top-most one
    final modalRoute = ModalRoute.of(context);
    final routeIsCurrent = modalRoute?.isCurrent ?? true;
    final shouldEnable =
        widget.isActive && routeIsCurrent && !_isFieldTutorialActive;

    if (shouldEnable == _animationsEnabled) return;

    setState(() {
      _animationsEnabled = shouldEnable;
    });

    if (shouldEnable) {
      async.unawaited(context.read<AudioController>().playHomeMusic());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAchievementsDocked();
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isAppInForeground =
        lifecycleState == null ||
        lifecycleState == AppLifecycleState.resumed ||
        lifecycleState == AppLifecycleState.inactive;

    _breathingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _enhanceRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      value: 1.0, // assume already revealed; will reset if a celebration fires
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeApp();
      if (mounted) {
        await _checkFieldTutorial();
        await _refreshNotificationsNow();
        await _maybeRunCosmicMemoryHomeEvent();
        await _maybePlayEnhanceCelebration();
        await _syncHomePortal();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
    _updateAnimationState();
  }

  @override
  void didPushNext() {
    _updateAnimationState(); // route no longer current → disables TickerMode
  }

  // MODIFY didUpdateWidget to call it:

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _updateAnimationState();

      if (widget.isActive) {
        // 🔄 Always sync from DB when Home becomes active
        async.unawaited(_checkFieldTutorial());
        async.unawaited(_maybeRunCosmicMemoryHomeEvent());
        async.unawaited(_maybePlayEnhanceCelebration());
        async.unawaited(_syncHomePortal());
        async.unawaited(_refreshSurvivalUnlocked());
      }
    }
  }

  @override
  void didPopNext() {
    _updateAnimationState();

    if (widget.isActive) {
      // 🔄 When returning to Home, sync from DB
      async.unawaited(_checkFieldTutorial());
      async.unawaited(_maybeRunCosmicMemoryHomeEvent());
      async.unawaited(_maybePlayEnhanceCelebration());
      async.unawaited(_syncHomePortal());
      async.unawaited(_refreshAlchemy());
      // Survival opens in space, behind a route home stays mounted under;
      // read only at start-up, its button waited for the next launch.
      async.unawaited(_refreshSurvivalUnlocked());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _breathingController.dispose();
    _shakeController.dispose();
    _realmField?.dispose();
    _enhanceRevealController.dispose();
    _relicLifted.dispose();
    _fieldLifted.dispose();
    _harvestLifted.dispose();
    _survivalLifted.dispose();
    _enhanceLifted.dispose();
    _slotsSubscription?.cancel();
    _rosterSubscription?.cancel();
    _biomesSubscription?.cancel();

    // Remove wilderness spawn listener.
    //
    // This used to be a context.read, which works right up until the provider
    // above is being disposed in the same pass — which is exactly what a
    // progress reset does. Provider.of then dereferences a null element, the
    // throw aborts this dispose part-way, and every unmount behind it fails
    // in turn: the grey screen after a reset was this one line.
    _spawnServiceForTeardown?.removeListener(_checkWildernessNotifications);
    _spawnServiceForTeardown = null;

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _isAppInForeground;
    _isAppInForeground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (_isAppInForeground == wasForeground) return;
    // Set here, not left to the audio controller's observer: both observers
    // see the same event and their order is not defined, and a restore that
    // ran while the flag still said "foreground" would be refused outright
    // — leaving the player with no notifications at all.
    _pushNotifications.setAppInForeground(_isAppInForeground);
    async.unawaited(
      _isAppInForeground ? _dropScheduledPushes() : _restoreScheduledPushes(),
    );
  }

  /// Take the scheduled pushes down while the player is here.
  ///
  /// Suppressing them at the moment they fire is not possible — Android
  /// posts a scheduled local notification whether or not the app is open,
  /// which is how a cultivation finishing on the cultivations screen still
  /// buzzed the tray. So they are removed on the way in and put back on the
  /// way out.
  ///
  /// Losing one is not a real risk: every schedule here is derived from the
  /// database rather than remembered, so [_restoreScheduledPushes] rebuilds
  /// them exactly. And a process killed hard enough to skip that also has
  /// its alarms dropped by the system.
  Future<void> _dropScheduledPushes() async {
    await _pushNotifications.cancelEggNotification();
    await _pushNotifications.cancelHarvestScheduledNotification();
    await _pushNotifications.cancelWildernessSpawnNotification();
  }

  Future<void> _restoreScheduledPushes() async {
    if (!mounted) return;
    // Order matters only in that all three read the database; none of them
    // remember anything, so this is the whole schedule rebuilt from state.
    await _rehydrateEggSchedules();
    if (!mounted) return;
    await context.read<AlchemonsDatabase>().biomeDao.syncHarvestNotifications();
    if (!mounted) return;
    await _checkWildernessNotifications();
  }

  Set<int> _parseNotificationStateIds(String? stateKey, String prefix) {
    if (stateKey == null || !stateKey.startsWith(prefix)) return <int>{};
    final rawIds = stateKey.substring(prefix.length);
    if (rawIds.isEmpty) return <int>{};
    return rawIds.split(',').map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> _seedOpeningBiomeSpawns(
    WildernessSpawnService spawnService,
    Set<String> allowedScenes,
  ) async {
    final db = context.read<AlchemonsDatabase>();

    for (final sceneId in _coreWildernessBiomes) {
      await spawnService.clearSceneSpawns(sceneId);
    }

    for (final sceneId in allowedScenes) {
      final spawnId = OpeningWildernessService.tutorialSpawnPointForScene(
        sceneId,
      );
      final encounter = EncounterRoll(
        speciesId: OpeningWildernessService.mainLetForScene(sceneId),
        rarity: EncounterRarity.common,
        spawnId: spawnId,
      );

      spawnService.forceSpawnAt(sceneId, spawnId, encounter);
      await db
          .into(db.activeSpawns)
          .insert(
            ActiveSpawnsCompanion.insert(
              id: '${sceneId}_$spawnId',
              sceneId: sceneId,
              spawnPointId: spawnId,
              speciesId: encounter.speciesId,
              rarity: encounter.rarity.name,
              spawnedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }

  Future<void> _ensureOpeningWildernessReady(
    FactionId faction,
    WildernessSpawnService spawnService,
  ) async {
    final settings = context.read<AlchemonsDatabase>().settingsDao;
    if (!await OpeningWildernessService.isRestrictionActive(settings)) {
      await OpeningWildernessService.activateForFaction(settings, faction);
    }

    var allowedScenes = await OpeningWildernessService.allowedScenes(settings);
    if (allowedScenes.isEmpty) {
      await OpeningWildernessService.activateForFaction(settings, faction);
      allowedScenes = await OpeningWildernessService.allowedScenes(settings);
    }
    final hasUnexpectedSpawn = _coreWildernessBiomes.any(
      (sceneId) =>
          !allowedScenes.contains(sceneId) &&
          spawnService.getSceneSpawnCount(sceneId) > 0,
    );
    final missingAllowedSpawn = allowedScenes.any(
      (sceneId) => spawnService.getSceneSpawnCount(sceneId) == 0,
    );

    if (allowedScenes.isEmpty || hasUnexpectedSpawn || missingAllowedSpawn) {
      await _seedOpeningBiomeSpawns(spawnService, allowedScenes);
    }
  }

  Future<void> _checkFieldTutorial() async {
    if (_tutorialCheckInProgress) return;
    _tutorialCheckInProgress = true;
    try {
      final db = context.read<AlchemonsDatabase>();
      final spawnService = context.read<WildernessSpawnService>();
      final factionService = context.read<FactionService>();

      // 🔹 First: if tutorial is already completed in DB, make sure local state matches
      final completed = await db.settingsDao.hasCompletedFieldTutorial();

      if (completed) {
        // unlock nav just in case
        await db.settingsDao.setNavLocked(false);

        if (_isFieldTutorialActive) {
          if (!mounted) return;
          setState(() {
            _isFieldTutorialActive = false;
            _activeNotifications.clear();
          });
          _updateAnimationState();
        }

        return; // nothing else to do
      } // Check if extraction tutorial is still pending
      final extractionPending =
          await db.settingsDao.getSetting('tutorial_extraction_pending') == '1';
      if (extractionPending) {
        debugPrint(
          '🎓 Tutorial: Extraction pending, redirecting to breed screen',
        );
        await db.settingsDao.setNavLocked(true);
        widget.onNavigateSection(NavSection.breed, breedInitialTab: 1);
        return;
      }

      if (!completed) {
        // 🔑 STEP 3: Verify user actually has creatures before starting field tutorial
        final instances = await db.creatureDao.listAllInstances();

        if (instances.isEmpty) {
          debugPrint('🎓 Tutorial: No creatures found, checking for eggs...');

          // No creatures yet - check if there's an egg they need to extract
          final slots = await db.incubatorDao.watchSlots().first;
          final hasEgg = slots.any((s) => s.unlocked && s.eggId != null);

          if (hasEgg) {
            // Has egg but no creatures - send to extraction
            debugPrint('🎓 Tutorial: Found egg, redirecting to extraction');
            await db.settingsDao.setNavLocked(true);
            // Mark extraction as pending since they clearly need to do it
            await db.settingsDao.setSetting('tutorial_extraction_pending', '1');
            widget.onNavigateSection(NavSection.breed, breedInitialTab: 1);
          } else {
            // No egg and no creatures - check if starter was ever granted
            final starterGranted =
                await db.settingsDao.getSetting('starter_granted_v1') == '1';

            if (!starterGranted) {
              // Let normal starter flow handle it in _grantStarterIfNeeded
              debugPrint(
                '🎓 Tutorial: No starter granted yet, waiting for grant flow',
              );
            } else {
              // Edge case: starter was granted but egg is gone and no creatures
              // This shouldn't happen, but if it does, skip tutorial
              debugPrint(
                '🎓 Tutorial: Edge case - starter granted but no egg/creatures, skipping field tutorial',
              );
              await db.settingsDao.setFieldTutorialCompleted();
              await db.settingsDao.setNavLocked(false);
            }
          }
          return;
        }

        // User has creatures - proceed with field tutorial
        debugPrint('🎓 Tutorial: Starting field tutorial');
        await db.settingsDao.setNavLocked(true);
        final faction = factionService.current;
        if (faction != null) {
          await _ensureOpeningWildernessReady(faction, spawnService);
        }

        setState(() {
          _isFieldTutorialActive = true;
          _activeNotifications.clear();
        });

        _updateAnimationState();
      }
    } finally {
      _tutorialCheckInProgress = false;
    }
  }

  /// The map, through the Field emblem: its hills come loose and drift down
  /// into the realm circles.
  Future<bool?> _openField({bool tutorial = false}) {
    final ready = ValueNotifier<bool>(false);
    final circles = ValueNotifier<List<FieldCircle>?>(null);
    return EmblemPassage.pushScene<bool>(
      context,
      scene: FieldPassage(target: circles),
      from: _fieldEmblem,
      page: MapScreen(
        isTutorial: tutorial,
        onNavigateSection: tutorial ? widget.onNavigateSection : null,
        revealReady: ready,
        passageTarget: circles,
      ),
      ready: ready,
      lifted: _fieldLifted,
    );
  }

  /// The harvest, through its flask: it settles onto the chamber's own.
  void _openHarvest() {
    final ready = ValueNotifier<bool>(false);
    final place = ValueNotifier<HarvestFlaskTarget?>(null);
    EmblemPassage.pushScene<void>(
      context,
      scene: HarvestPassage(target: place),
      from: _harvestEmblem,
      page: ExtractionHubScreen(revealReady: ready, passageTarget: place),
      ready: ready,
      lifted: _harvestLifted,
    );
  }

  /// Enhance, through its creature of grains: it comes apart into a band
  /// of light that opens on the picker.
  void _openEnhance() {
    final ready = ValueNotifier<bool>(false);
    final revealed = ValueNotifier<bool>(false);
    final creature = ValueNotifier<SpecimenGrains?>(null);
    DockEmblem.creatureGrains(
      fine: true,
    ).then((g) => creature.value = g, onError: (_) {});
    EmblemPassage.pushScene<void>(
      context,
      scene: EnhancePassage(creature: creature),
      from: _enhanceEmblem,
      page: FeedingScreen(revealReady: ready, revealed: revealed),
      ready: ready,
      revealed: revealed,
      lifted: _enhanceLifted,
    );
  }

  Future<void> _handleFieldTutorialTap() async {
    if (!_isFieldTutorialActive) return;

    HapticFeedback.mediumImpact();

    // We don't care about the bool now, Scene/Map writes to DB
    await _openField(tutorial: true);

    if (!mounted) return;

    // 🔄 After returning, always sync with DB flag
    await _checkFieldTutorial();
  }

  Future<void> _initializeApp() async {
    // A save that has not extracted its first vial yet is in the opening;
    // the permission prompt waits until after that extraction.
    final pastOpening =
        await context.read<AlchemonsDatabase>().settingsDao.getSetting(
          'first_extraction_done',
        ) ==
        '1';
    await _pushNotifications.initialize(requestPermission: pastOpening);
    try {
      if (!mounted) return;
      final factionSvc = context.read<FactionService>();

      await factionSvc.loadId();
      var faction = factionSvc.current;

      if (!mounted) return;

      // First-time intro is handled in AppGate now.
      // If somehow we still don't have a faction yet, just bail for now.
      if (faction == null) {
        debugPrint(
          'HomeScreen._initializeApp: faction is null; intro flow should have run in AppGate.',
        );
        return;
      }

      if (!mounted) return;
      final spawnService = context.read<WildernessSpawnService>();

      await _grantStarterIfNeeded(faction, spawnService);
      await _migrateLegacyBossRelics();
      await _refreshHasAnyRelic();
      await _refreshSurvivalUnlocked();
      await _refreshAlchemy();

      // Load featured hero
      await _refreshFeatured(notify: false);
      // Before the first frame shows it: an open portal stands in for it.
      await _loadHomePortal();

      setState(() => _isInitialized = true);

      // Reactive watchers (streams)
      _setupNotificationWatchers();

      // Check wilderness now
      _checkWildernessNotifications();

      await _pushNotifications.debugPrintPendingNotifications();

      // Recreate per-egg schedules on cold start
      // Nothing scheduled while the player is here. A cold start is a
      // foreground start, so this clears whatever the last session left
      // pending; the schedule is rebuilt when the app goes away again.
      _pushNotifications.setAppInForeground(true);
      await _dropScheduledPushes();
    } catch (e, st) {
      debugPrint('Error during app initialization: $e');
      debugPrint('Error during app initialization: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initialize app: $e'),
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  // ============================================================
  // REACTIVE NOTIFICATION SYSTEM
  // ============================================================

  /// The featured Alchemon, inside the portal once that is open to the
  /// player.
  Widget _buildHero(FactionTheme theme) {
    final hero = FeaturedHeroInteractive(
      data: _featuredData!,
      theme: theme,
      breathing: _breathingController,
      onLongPressChoose: _handleChooseFeaturedInstance,
      onTapDetails: _handleOpenFeaturedDetails,
      instance: _featuredData!.instance,
      creature: _featuredData!.creature,
      reveal: _featuredReveal,
      spriteKey: _homePortalUnlocked ? _heroSpriteKey : null,
    );
    if (!_homePortalUnlocked) return hero;
    return SizedBox.expand(
      child: HomePortalHero(
        key: _homePortalKey,
        open: _homePortalOpen,
        spriteKey: _heroSpriteKey,
        tone: theme.primary,
        // The home biome, live. Not while the player is down in it (two
        // fields at once), and fresh each time they come back up, since
        // they may have rearranged it.
        window: _homePortalDescending
            ? null
            : (context, onReady) => HomeBiomeWindow(
                key: ValueKey(_homeBiomeVisit),
                active: _animationsEnabled,
                onReady: onReady,
              ),
        guide: _homePortalGuide,
        onToggle: _onHomePortalToggled,
        onEnter: _enterHomePortal,
        onStir: (global, delta, dt) {
          final at = _realmLocal(global);
          if (at != null) _realmField?.stir(at, delta, dt);
        },
        onTapSand: (global) {
          final at = _realmLocal(global);
          if (at != null) _realmField?.ripple(at);
        },
        onSwirl: (global, reach, spin, pull) {
          final at = _realmLocal(global);
          if (at != null) {
            _realmField?.swirl(at, reach, spin: spin, pull: pull);
          }
        },
        child: Center(child: hero),
      ),
    );
  }

  /// Reads the featured hero and prepares its sprite.
  ///
  /// At startup the player's first Alchemon is still an egg, so this finds
  /// nothing; it has to run again when one actually exists, or the home
  /// screen stays empty until the app is restarted.
  Future<void> _refreshFeatured({bool notify = true}) async {
    if (!mounted) return;
    final featuredInstance = await _loadFeaturedInstanceOrAuto();
    if (!mounted) return;

    if (featuredInstance != null) {
      final repo = context.read<CreatureCatalog>();
      await _prewarmFeaturedSprite(featuredInstance, repo);
      if (!mounted) return;
      _featuredInstanceId = featuredInstance.instanceId;
      _featuredData = _presentationFromInstance(featuredInstance, repo);
    } else {
      _featuredInstanceId = null;
      _featuredData = null;
    }
    // The startup path sets state itself once everything else is ready.
    if (notify) setState(() {});
  }

  void _setupNotificationWatchers() {
    final db = context.read<AlchemonsDatabase>();
    final spawnService = context.read<WildernessSpawnService>();

    // Eggs: react to slot changes (schedule/cancel per-egg notis, show in-app banner)
    _slotsSubscription = db.incubatorDao.watchSlots().listen(
      _checkEggNotifications,
    );

    // The roster: the first Alchemon arrives long after startup — it hatches
    // out of the starter egg — and the home screen has nothing to feature
    // until it does. Watched rather than polled so the hero appears the
    // moment it exists.
    _rosterSubscription = db.creatureDao.watchSpeciesWithInstances().listen((
      species,
    ) {
      if (!mounted) return;
      // Only fills a gap. Picking a different favourite is the profile's
      // job, and re-running this on every roster change would fight it.
      if (_featuredInstanceId != null || species.isEmpty) return;
      async.unawaited(_refreshFeatured());
    });

    // Harvests: react to biome changes
    _biomesSubscription = db.biomeDao.watchBiomes().listen(
      _checkBiomeNotifications,
    );

    // Wilderness spawns.
    //
    // The service is held rather than looked up again at teardown: dispose
    // cannot reach a provider once the tree above it has gone, and a progress
    // reset tears the whole tree down at once.
    _spawnServiceForTeardown = spawnService;
    spawnService.addListener(_checkWildernessNotifications);
  }

  // Manual refresh when landing on Home / returning to Home
  Future<void> _refreshNotificationsNow() async {
    if (!mounted || _isFieldTutorialActive) return;

    final db = context.read<AlchemonsDatabase>();
    final slots = await db.incubatorDao.watchSlots().first;
    await _checkEggNotifications(slots);

    final biomes = await db.biomeDao.watchBiomes().first;
    await _checkBiomeNotifications(biomes);

    await _checkWildernessNotifications();
  }

  // Wilderness
  Future<void> _checkWildernessNotifications() async {
    if (!mounted) return;
    final enabled = await NotificationPreferencesService()
        .isWildernessEnabled();
    if (!mounted) return;
    if (!enabled) {
      _lastWildernessStateKey = null;
      await _pushNotifications.cancelWildernessNotifications();
      _clearNotification(NotificationBannerType.wildernessSpawn);
      return;
    }

    final spawnService = context.read<WildernessSpawnService>();
    final visibleBiomes = await _visibleWildernessBiomes();
    if (!mounted) return;
    final totalSpawns = visibleBiomes.fold<int>(
      0,
      (sum, biomeId) => sum + spawnService.getSceneSpawnCount(biomeId),
    );
    final scenesWithSpawns = visibleBiomes.where((biomeId) {
      return spawnService.getSceneSpawnCount(biomeId) > 0;
    }).length;

    if (totalSpawns > 0) {
      final stateKey = 'spawns:$totalSpawns/$scenesWithSpawns';

      debugPrint(
        '🌲 Wilderness notification check: $totalSpawns visible spawns across $scenesWithSpawns scenes',
      );

      if (_lastWildernessStateKey == stateKey) return;
      _lastWildernessStateKey = stateKey;

      _showNotification(
        NotificationBanner(
          type: NotificationBannerType.wildernessSpawn,
          title: 'Wild Alchemons',
          subtitle:
              'Detected in $scenesWithSpawns realm${scenesWithSpawns > 1 ? 's' : ''}',
          count: totalSpawns,
          stateKey: stateKey,
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (_) => const MapScreen(),
                fullscreenDialog: true,
              ),
            );
          },
        ),
      );
    } else {
      debugPrint('🌲 Clearing wilderness notification (no active spawns)');
      _lastWildernessStateKey = null;
      _clearNotification(NotificationBannerType.wildernessSpawn);
    }
  }

  Future<List<String>> _visibleWildernessBiomes() async {
    final db = context.read<AlchemonsDatabase>();
    final arcaneUnlocked =
        await db.settingsDao.getSetting('arcane_portal_unlocked') == '1';
    if (mounted && _arcanePortalUnlocked != arcaneUnlocked) {
      setState(() => _arcanePortalUnlocked = arcaneUnlocked);
    }
    return [
      ..._coreWildernessBiomes,
      if (arcaneUnlocked) 'arcane',
      // The shop's realms: spawns exist there only once they are bought
      // (and never in one that is a home only).
      for (final s in kShopScenes)
        if (!s.homeOnly) s.sceneId,
    ];
  }

  // Eggs: keep per-egg schedules current and silently update the consolidated
  // summary notification while ready eggs remain unresolved.
  Future<void> _checkEggNotifications(List<IncubatorSlot> slots) async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final enabled = await NotificationPreferencesService()
        .isCultivationsEnabled();
    if (!enabled) {
      _lastEggStateKey = null;
      _lastScheduledEggHatchMsBySlot.clear();
      _lastReadyEggSlotIds.clear();
      _eggNotificationStateHydrated = false;
      await db.settingsDao.setNotificationSummaryState(
        _eggNotificationStateType,
        null,
      );
      await _pushNotifications.cancelEggNotification();
      await _pushNotifications.cancelEggReadySummaryNotification();
      _clearNotification(NotificationBannerType.eggReady);
      return;
    }

    final initialSync = !_eggNotificationStateHydrated;
    _eggNotificationStateHydrated = true;

    int readyEggs = 0;
    final nowUtc = DateTime.now().toUtc();
    final List<Future> scheduleTasks = [];
    final List<int> slotsToCancel = [];
    final List<int> readySlotIds = [];
    final List<({int slotId, DateTime hatchUtc, int hatchMs, String eggId})>
    futureHatches = [];
    final Set<int> activeSlotIds = <int>{};

    for (final slot in slots) {
      if (slot.unlocked && slot.eggId != null && slot.hatchAtUtcMs != null) {
        activeSlotIds.add(slot.id);
        final hatchUtc = DateTime.fromMillisecondsSinceEpoch(
          slot.hatchAtUtcMs!,
          isUtc: true,
        );

        if (!hatchUtc.isAfter(nowUtc)) {
          readyEggs++;
          readySlotIds.add(slot.id);
          // Cancel per-slot scheduled notification (it would be in the past now)
          slotsToCancel.add(slot.id);
          _lastScheduledEggHatchMsBySlot.remove(slot.id);
        } else {
          futureHatches.add((
            slotId: slot.id,
            hatchUtc: hatchUtc,
            hatchMs: slot.hatchAtUtcMs!,
            eggId: slot.eggId!,
          ));
        }
      } else {
        // Slot is empty/invalid -> ensure any stale scheduled notification is cleared.
        slotsToCancel.add(slot.id);
        _lastScheduledEggHatchMsBySlot.remove(slot.id);
      }
    }

    // Keep only one upcoming scheduled push: the earliest hatch.
    // This avoids "4 cultivations finishing back-to-back = 4 pushes" spam.
    futureHatches.sort((a, b) => a.hatchMs.compareTo(b.hatchMs));
    final earliestFuture = futureHatches.isNotEmpty
        ? futureHatches.first
        : null;

    if (earliestFuture != null) {
      final lastScheduledMs =
          _lastScheduledEggHatchMsBySlot[earliestFuture.slotId];
      if (lastScheduledMs != earliestFuture.hatchMs) {
        scheduleTasks.add(
          _pushNotifications.scheduleEggHatchingNotification(
            hatchTime: earliestFuture.hatchUtc.toLocal(),
            eggId: earliestFuture.eggId,
            slotIndex: earliestFuture.slotId,
          ),
        );
      }
      _lastScheduledEggHatchMsBySlot[earliestFuture.slotId] =
          earliestFuture.hatchMs;
    }

    for (final future in futureHatches.skip(1)) {
      slotsToCancel.add(future.slotId);
      _lastScheduledEggHatchMsBySlot.remove(future.slotId);
    }

    // If slot list changed, clean up removed slot IDs too.
    final staleTrackedSlots = _lastScheduledEggHatchMsBySlot.keys
        .where((slotId) => !activeSlotIds.contains(slotId))
        .toList();
    for (final slotId in staleTrackedSlots) {
      slotsToCancel.add(slotId);
      _lastScheduledEggHatchMsBySlot.remove(slotId);
    }

    for (final slotId in slotsToCancel) {
      await _pushNotifications.cancelEggNotification(slotIndex: slotId);
    }
    if (scheduleTasks.isNotEmpty) {
      await Future.wait(scheduleTasks);
    }

    debugPrint('🥚 Egg notification check: $readyEggs eggs ready');

    if (readyEggs > 0) {
      readySlotIds.sort();
      final readySlotIdSet = readySlotIds.toSet();
      final stateKey = 'slots:${readySlotIds.join(",")}';
      final previousStateKey = initialSync
          ? await db.settingsDao.getNotificationSummaryState(
              _eggNotificationStateType,
            )
          : _lastEggStateKey;
      final previousReadySlotIds = initialSync
          ? _parseNotificationStateIds(previousStateKey, 'slots:')
          : Set<int>.from(_lastReadyEggSlotIds);
      final shouldNotify = previousStateKey != stateKey;
      _lastEggStateKey = stateKey;
      _lastReadyEggSlotIds = readySlotIdSet;

      if (shouldNotify) {
        final newlyReadySlotIds = readySlotIdSet.difference(
          previousReadySlotIds,
        );
        if (_isAppInForeground) {
          await _pushNotifications.cancelEggReadySummaryNotification();
        } else if (initialSync) {
          await _pushNotifications.showEggReadyNotification(
            count: readyEggs,
            silentUpdate: true,
          );
        } else if (newlyReadySlotIds.isNotEmpty) {
          await _pushNotifications.showEggReadyNotification(
            count: readyEggs,
            silentUpdate: previousReadySlotIds.isNotEmpty,
          );
        } else {
          await _pushNotifications.cancelEggReadySummaryNotification();
        }
        await db.settingsDao.setNotificationSummaryState(
          _eggNotificationStateType,
          stateKey,
        );
      }

      _showNotification(
        NotificationBanner(
          type: NotificationBannerType.eggReady,
          title: readyEggs > 1
              ? '$readyEggs cultivations ready'
              : 'Cultivation ready',
          subtitle: readyEggs > 1 ? 'Tap to extract them' : 'Tap to extract it',
          count: readyEggs,
          stateKey: stateKey,
          onTap: () {
            widget.onNavigateSection(NavSection.breed, breedInitialTab: 1);
          },
        ),
      );
    } else {
      _lastEggStateKey = null; // reset de-dupe
      _lastReadyEggSlotIds.clear();
      await db.settingsDao.setNotificationSummaryState(
        _eggNotificationStateType,
        null,
      );
      await _pushNotifications.cancelEggReadySummaryNotification();
      _clearNotification(NotificationBannerType.eggReady);
    }
  }

  Future<void> _checkBiomeNotifications(List<BiomeFarm> biomes) async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final enabled = await NotificationPreferencesService()
        .isExtractionsEnabled();
    if (!enabled) {
      _lastHarvestStateKey = null;
      _lastReadyHarvestBiomeIds.clear();
      _harvestNotificationStateHydrated = false;
      await db.settingsDao.setNotificationSummaryState(
        _harvestNotificationStateType,
        null,
      );
      await _pushNotifications.cancelHarvestNotification();
      _clearNotification(NotificationBannerType.harvestReady);
      return;
    }

    final initialSync = !_harvestNotificationStateHydrated;
    _harvestNotificationStateHydrated = true;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (!mounted) return;

    // Build futures for unlocked biomes
    final futures = <Future<({BiomeFarm farm, HarvestJob? job})>>[];

    for (final farm in biomes) {
      if (!farm.unlocked) continue;

      futures.add(() async {
        final job = await db.biomeDao.getActiveJobForBiome(farm.id);
        return (farm: farm, job: job);
      }());
    }

    final results = await Future.wait(futures);

    int readyHarvests = 0;
    final List<int> readyBiomeIds = [];

    for (final result in results) {
      final job = result.job;
      if (job == null) continue;

      final endMs = job.startUtcMs + job.durationMs;
      if (endMs <= nowMs) {
        readyHarvests++;
        readyBiomeIds.add(result.farm.id);
      }
    }

    debugPrint('⚗️ Harvest notification check: $readyHarvests ready');

    if (readyHarvests > 0) {
      readyBiomeIds.sort();
      final readyBiomeIdSet = readyBiomeIds.toSet();
      final stateKey = 'biomes:${readyBiomeIds.join(",")}';
      final previousStateKey = initialSync
          ? await db.settingsDao.getNotificationSummaryState(
              _harvestNotificationStateType,
            )
          : _lastHarvestStateKey;
      final previousReadyBiomeIds = initialSync
          ? _parseNotificationStateIds(previousStateKey, 'biomes:')
          : Set<int>.from(_lastReadyHarvestBiomeIds);
      final shouldNotify = previousStateKey != stateKey;
      _lastHarvestStateKey = stateKey;
      _lastReadyHarvestBiomeIds = readyBiomeIdSet;

      if (shouldNotify) {
        final newlyReadyBiomeIds = readyBiomeIdSet.difference(
          previousReadyBiomeIds,
        );
        if (_isAppInForeground) {
          await _pushNotifications.cancelHarvestSummaryNotification();
        } else if (initialSync) {
          await _pushNotifications.showHarvestReadyNotification(
            count: readyHarvests,
            silentUpdate: true,
          );
        } else if (newlyReadyBiomeIds.isNotEmpty) {
          await _pushNotifications.showHarvestReadyNotification(
            count: readyHarvests,
            silentUpdate: previousReadyBiomeIds.isNotEmpty,
          );
        } else {
          await _pushNotifications.cancelHarvestSummaryNotification();
        }
        await db.settingsDao.setNotificationSummaryState(
          _harvestNotificationStateType,
          stateKey,
        );
      }

      _showNotification(
        NotificationBanner(
          type: NotificationBannerType.harvestReady,
          title: readyHarvests > 1
              ? '$readyHarvests harvests ready'
              : 'Harvest ready',
          subtitle: 'Tap to collect',
          count: readyHarvests,
          stateKey: stateKey,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExtractionHubScreen()),
            );
          },
        ),
      );
    } else {
      _lastHarvestStateKey = null;
      _lastReadyHarvestBiomeIds.clear();
      await db.settingsDao.setNotificationSummaryState(
        _harvestNotificationStateType,
        null,
      );
      await _pushNotifications.cancelHarvestSummaryNotification();
      _clearNotification(NotificationBannerType.harvestReady);
    }
  }

  // Restore per-egg schedules on app start so OS will fire them even if app is killed
  Future<void> _rehydrateEggSchedules() async {
    final db = context.read<AlchemonsDatabase>();
    final slots = await db.incubatorDao.watchSlots().first;
    final now = DateTime.now().toUtc();
    final List<({int slotId, DateTime hatchUtc, String eggId})> futureHatches =
        [];

    for (final s in slots) {
      // Reset each slot's scheduled push so startup never duplicates stale jobs.
      await _pushNotifications.cancelEggNotification(slotIndex: s.id);
      if (!(s.unlocked && s.eggId != null && s.hatchAtUtcMs != null)) continue;

      final hatchUtc = DateTime.fromMillisecondsSinceEpoch(
        s.hatchAtUtcMs!,
        isUtc: true,
      );

      if (hatchUtc.isAfter(now)) {
        futureHatches.add((slotId: s.id, hatchUtc: hatchUtc, eggId: s.eggId!));
      }
    }

    if (futureHatches.isEmpty) return;
    futureHatches.sort((a, b) => a.hatchUtc.compareTo(b.hatchUtc));
    final earliest = futureHatches.first;
    await _pushNotifications.scheduleEggHatchingNotification(
      hatchTime: earliest.hatchUtc.toLocal(),
      eggId: earliest.eggId,
      slotIndex: earliest.slotId,
    );
  }

  void _showNotification(NotificationBanner banner) {
    if (!mounted || _isFieldTutorialActive) return; // 🔹 block during tutorial

    for (final existing in _activeNotifications) {
      if (existing.type == banner.type &&
          existing.stateKey == banner.stateKey) {
        return;
      }
    }

    setState(() {
      // Ensure ONLY ONE banner per type at a time.
      _activeNotifications.removeWhere((n) => n.type == banner.type);
      _activeNotifications.add(banner);
      debugPrint(
        '📢 Showing notification: ${banner.type} (${banner.title}) [${banner.stateKey}]',
      );
    });
  }

  void _clearNotification(NotificationBannerType type) async {
    if (!mounted) return;

    try {
      final db = context.read<AlchemonsDatabase>();
      // Clear all dismissals for this type (any prior state).
      // We want future states to be eligible again.
      await (db.delete(
        db.notificationDismissals,
      )..where((t) => t.notificationType.like('${type.toKey()}%'))).go();
    } catch (e) {
      debugPrint('Error clearing notification dismissal: $e');
    }

    setState(() {
      final hadAny = _activeNotifications.any((n) => n.type == type);
      _activeNotifications.removeWhere((n) => n.type == type);
      if (hadAny) {
        debugPrint('🗑️  Cleared notification: $type');
      }
    });
  }

  // ============================================================
  // FEATURED HERO HELPERS
  // ============================================================

  Future<CreatureInstance?> _loadFeaturedInstanceOrAuto() async {
    final db = context.read<AlchemonsDatabase>();

    // Attempt to load saved featured instance
    final savedId = await db.settingsDao.getFeaturedInstanceId();
    if (savedId != null && savedId.isNotEmpty) {
      final chosen = await db.creatureDao.getInstance(savedId);
      if (chosen != null) {
        return chosen;
      }
    }

    // Auto-pick fallback
    final all = await db.creatureDao.listAllInstances();
    if (all.isEmpty) return null;

    // prefer prismatic
    final prismatics = all.where((ci) => ci.isPrismaticSkin == true).toList();
    if (prismatics.isNotEmpty) {
      return prismatics.first;
    }

    // else best "rarity" via stat potential heuristic
    all.sort((a, b) {
      final aScore =
          (a.statSpeedPotential +
                  a.statIntelligencePotential +
                  a.statStrengthPotential +
                  a.statBeautyPotential)
              .toDouble();
      final bScore =
          (b.statSpeedPotential +
                  b.statIntelligencePotential +
                  b.statStrengthPotential +
                  b.statBeautyPotential)
              .toDouble();
      return bScore.compareTo(aScore);
    });

    return all.first;
  }

  /// Pre-loads the featured creature's sprite sheet into Flame's image cache
  /// so that [CreatureSprite] can display it synchronously (no loading flash).
  Future<void> _prewarmFeaturedSprite(
    CreatureInstance inst,
    CreatureCatalog repo,
  ) async {
    try {
      final base = repo.getCreatureById(inst.baseId);
      if (base?.spriteData == null) return;
      // A mutated one is baked here too, so it never flashes plain first.
      final sheet = mutatedSheet(
        sheetFromCreature(base!),
        mutation: inst.mutation,
        prismatic: inst.isPrismaticSkin,
      );
      await loadCreatureSheet(Flame.images, sheet.path);
    } catch (_) {}
  }

  PresentationData? _presentationFromInstance(
    CreatureInstance pick,
    CreatureCatalog repo,
  ) {
    final base = repo.getCreatureById(pick.baseId);
    if (base == null) {
      debugPrint(
        'FeaturedPresentation: could not find base creature for ${pick.baseId}',
      );
      return null;
    }

    final sprite = base.spriteData;
    if (sprite == null) {
      debugPrint('FeaturedPresentation: no spriteData for ${base.id}');
      return null;
    }

    // Title line: nickname or species name
    final displayTitle =
        (pick.nickname != null && pick.nickname!.trim().isNotEmpty)
        ? pick.nickname!.trim()
        : base.name;

    // Flavor subtitle
    final primaryType = (base.types.isNotEmpty) ? base.types.first : '???';

    // specimen short tag
    final shortTag = (pick.instanceId.length <= 4)
        ? pick.instanceId.toUpperCase()
        : pick.instanceId.substring(pick.instanceId.length - 4).toUpperCase();

    final subtitleLine = [
      'LVL ${pick.level}',
      primaryType.toUpperCase(),
      'SPECIMEN #$shortTag',
    ].join(' • ');

    final mutation = AlchemonMutation.byId(pick.mutation);
    final finalSubtitle = [
      if (mutation != null) mutation.label.toUpperCase(),
      if (pick.isPrismaticSkin) 'PRISMATIC VARIANT',
      subtitleLine,
    ].join(' • ');

    return PresentationData(
      displayName: displayTitle,
      subtitle: finalSubtitle,
      instance: pick,
      creature: base,
    );
  }

  Future<void> _handleChooseFeaturedInstance() async {
    HapticFeedback.mediumImpact();

    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final theme = context.read<FactionTheme>();

    final hasInstances = (await db.creatureDao.listAllInstances()).isNotEmpty;
    if (!hasInstances) return;

    if (!mounted) return;
    final pickedInstance = await showSpecimenPickerRoute(
      context: context,
      theme: theme,
      searchHint: 'SELECT SPECIMEN',
      prefsScopeKey: 'home_featured_specimens',
    );
    if (pickedInstance == null) return;

    await db.settingsDao.setFeaturedInstanceId(pickedInstance.instanceId);

    await _prewarmFeaturedSprite(pickedInstance, repo);
    final newPresentation = _presentationFromInstance(pickedInstance, repo);
    if (!mounted) return;
    setState(() {
      _featuredInstanceId = pickedInstance.instanceId;
      _featuredData = newPresentation;
      _featuredReveal = EssenceReveal.once();
    });

    HapticFeedback.lightImpact();
  }

  Future<void> _handleOpenFeaturedDetails() async {
    final repo = context.read<CreatureCatalog>();
    final db = context.read<AlchemonsDatabase>();

    final id = _featuredInstanceId;
    if (id == null) return;

    final inst = await db.creatureDao.getInstance(id);
    if (inst == null) return;

    final base = repo.getCreatureById(inst.baseId);
    if (base == null) return;

    if (!mounted) return;
    CreatureDetailsDialog.show(
      context,
      base,
      true,
      instanceId: inst.instanceId,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return withGameData(
      context,
      isInitialized: _isInitialized,
      loadingBuilder: buildLoadingScreen,
      builder:
          (
            context, {
            required theme,
            required catalog,
            required entries,
            required discovered,
          }) {
            final factionSvc = context.watch<FactionService>();
            final currentFaction = factionSvc.current ?? FactionId.oceanic;
            final hasLineageAnalyzer = context
                .select<ConstellationEffectsService, bool>(
                  (service) => service.hasLineageAnalyzer(),
                );
            final enhanceUnlocked = context.select<ShopService, bool>(
              (shop) => shop.hasElementalCreatorUnlocked(),
            );

            // Detect the moment of unlock and trigger shake + reveal.
            if (_lastEnhanceUnlocked != null &&
                _lastEnhanceUnlocked == false &&
                enhanceUnlocked == true) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _maybePlayEnhanceCelebration();
              });
            }
            _lastEnhanceUnlocked = enhanceUnlocked;

            return AnimatedBuilder(
              animation: _shakeController,
              builder: (ctx, child) {
                final t = _shakeController.value;
                final damp = (1.0 - t);
                final dx = sin(t * pi * 12) * 18.0 * damp;
                final dy = sin(t * pi * 10) * 8.0 * damp;
                return Transform.translate(
                  offset: Offset(dx, dy),
                  child: child,
                );
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // One factor for every hard-coded dimension below; see
                  // _homeScaleFor.
                  final hs = _homeScaleFor(constraints.maxHeight);
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _measureNoticeRest(),
                  );
                  return Stack(
                    key: _homeStackKey,
                    fit: StackFit.expand,
                    children: [
                      // Background is always the home background here
                      Positioned.fill(
                        child: TickerMode(
                          enabled: _animationsEnabled,
                          child: RepaintBoundary(
                            // The faction's realm in grains; drag through
                            // it and it stirs like the wild map's sand.
                            child: FactionRealmView(
                              faction: currentFaction,
                              ink: theme.brightness == Brightness.light,
                              field: _realmField ??= FactionRealmField(
                                faction: currentFaction,
                                ink: theme.brightness == Brightness.light,
                              ),
                            ),
                          ),
                        ),
                      ),

                      SafeArea(
                        top: true,
                        child: Column(
                          children: [
                            KeyedSubtree(
                              key: _headerKey,
                              child: _buildHeader(theme),
                            ),

                            if (_featuredData != null) ...[
                              SizedBox(height: 20 * hs),
                              // Flexible, not fixed: SizedBox's tight height is
                              // normalised against the incoming constraint, so on
                              // a short viewport the hero takes whatever is left
                              // instead of overflowing the column by the
                              // difference. This is what actually fixes the
                              // overflow; the scale factor only makes it
                              // proportionate on the way down.
                              Flexible(
                                child: SizedBox(
                                  key: _heroSlotKey,
                                  height: 260 * hs,
                                  child: Center(
                                    child: TickerMode(
                                      enabled: _animationsEnabled,
                                      child: _buildHero(theme),
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            // Renders nothing today; it used to be wrapped in an
                            // Expanded, which would now compete with the hero's
                            // Flexible for the same remaining space.
                            _buildHomeContent(theme, hs),
                          ],
                        ),
                      ),

                      // Docked above the bottom navigation rather than up in
                      // the toolbar: on a tablet the row stretched it across
                      // the whole width, which read as an empty trough. Down
                      // here it is a fixed-width slab that sits with the other
                      // navigation, and it stays out of the hero's way.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 8,
                        child: SafeArea(
                          top: false,
                          left: false,
                          right: false,
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            alignment: _achievementsDocked
                                ? Alignment.centerRight
                                : Alignment.center,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onHorizontalDragEnd: (d) {
                                final v = d.primaryVelocity ?? 0;
                                if (v > 150) _setAchievementsDocked(true);
                                if (v < -150) _setAchievementsDocked(false);
                              },
                              child: AnimatedSize(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.centerRight,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: _achievementsDocked ? 64 : 460,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      left: _achievementsDocked ? 0 : 16,
                                      right: _achievementsDocked ? 0 : 16,
                                    ),
                                    child: CampaignRewardsButton(
                                      style: CampaignRewardsStyle.bar,
                                      docked: _achievementsDocked,
                                      enabled: !_isFieldTutorialActive,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 140 * hs,
                        left: 0,
                        child: Consumer<WildernessSpawnService>(
                          builder: (context, spawnService, child) {
                            final visibleBiomes = [
                              ..._coreWildernessBiomes,
                              if (_arcanePortalUnlocked) 'arcane',
                              for (final s in kShopScenes)
                                if (!s.homeOnly) s.sceneId,
                            ];
                            final hasSpawns = visibleBiomes.any(
                              (biomeId) =>
                                  spawnService.getSceneSpawnCount(biomeId) > 0,
                            );
                            return Stack(
                              children: [
                                child!,
                                if (hasSpawns)
                                  // Field's icon is centred in the dock column
                                  // and 70 wide: the dot rides its upper-right
                                  // rim rather than the column's corner.
                                  Positioned(
                                    top: 8,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Transform.translate(
                                        offset: const Offset(21, 0),
                                        child: HomeNoticeDot(
                                          color: homeNoticeAccent(
                                            NotificationBannerType
                                                .wildernessSpawn,
                                            dark: theme.isDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                          child: SideDockFloating(
                            theme: theme,
                            lockNonField: _isFieldTutorialActive,
                            lockEnhance: !enhanceUnlocked,
                            hideSurvival: !_survivalUnlocked,
                            enhanceRevealAnimation: _enhanceRevealController,
                            highlightEnhance: _enhanceHighlightActive,
                            showHarvestDot:
                                !_isFieldTutorialActive &&
                                context.select<HarvestService, bool>(
                                  (s) => s.biomes.any(
                                    (f) => f.unlocked && f.completed,
                                  ),
                                ),
                            highlightField: _isFieldTutorialActive,
                            onField: () {
                              if (_isFieldTutorialActive) {
                                _handleFieldTutorialTap();
                              } else {
                                _openField();
                              }
                            },
                            onEnhance:
                                _isFieldTutorialActive || !enhanceUnlocked
                                ? () {}
                                : () {
                                    HapticFeedback.mediumImpact();
                                    if (_enhanceHighlightActive) {
                                      setState(
                                        () => _enhanceHighlightActive = false,
                                      );
                                    }
                                    _openEnhance();
                                  },
                            onHarvest: _isFieldTutorialActive
                                ? () {}
                                : () {
                                    HapticFeedback.mediumImpact();
                                    _openHarvest();
                                  },
                            onCompetitions: _isFieldTutorialActive
                                ? () {}
                                : () {
                                    HapticFeedback.mediumImpact();
                                    Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                        builder: (_) =>
                                            const CompetitionHubScreen(),
                                        fullscreenDialog: true,
                                      ),
                                    );
                                  },

                            onBattle: _isFieldTutorialActive
                                ? () {}
                                : () => async.unawaited(_openCosmicSurvival()),
                            onMysticAltar: null,
                            fieldKey: _fieldEmblem,
                            harvestKey: _harvestEmblem,
                            survivalKey: _survivalEmblem,
                            fieldLifted: _fieldLifted,
                            harvestLifted: _harvestLifted,
                            survivalLifted: _survivalLifted,
                            enhanceKey: _enhanceEmblem,
                            enhanceLifted: _enhanceLifted,
                          ),
                        ),
                      ),

                      // RIGHT-SIDE BUTTON (new)
                      Stack(
                        children: [
                          // --- 1. First Icon (Your existing "BATTLE" icon) ---
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 125 * hs,
                            right: 0,
                            child: Opacity(
                              opacity: _isFieldTutorialActive ? 0.4 : 1.0,
                              child: IgnorePointer(
                                ignoring: _isFieldTutorialActive,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _AnimatedCosmicOrb(
                                      onPulse: _playHomeShake,
                                      animate: _animationsEnabled,
                                    ),
                                    const SizedBox(height: 4),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Transform.translate(
                                          offset: const Offset(0, 6),
                                          child: ConstellationPointsWidget(
                                            animate: _animationsEnabled,
                                          ),
                                        ),
                                        Transform.translate(
                                          offset: const Offset(0, -6),
                                          child: Text(
                                            'UPGRADE',
                                            style: TextStyle(
                                              color: theme.text,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_hasAnyRelic) ...[
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: context.soundAction(() {
                                          HapticFeedback.heavyImpact();
                                          final ready = ValueNotifier<bool>(
                                            false,
                                          );
                                          EmblemPassage.push<void>(
                                            context,
                                            kind: HomeEmblemKind.altar,
                                            from: _relicEmblem,
                                            page: MysticAltarScreen(
                                              revealReady: ready,
                                            ),
                                            ready: ready,
                                            lifted: _relicLifted,
                                          );
                                        }),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            HomeEmblem(
                                              key: _relicEmblem,
                                              kind: HomeEmblemKind.altar,
                                              size: 80,
                                              animate: _animationsEnabled,
                                              lifted: _relicLifted,
                                            ),
                                            Transform.translate(
                                              offset: const Offset(0, -6),
                                              child: Text(
                                                'RELICS',
                                                style: TextStyle(
                                                  color: theme.text,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1.1,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (hasLineageAnalyzer) ...[
                                      const SizedBox(height: 4),
                                      _AnimatedPurebloodRiteIcon(
                                        enabled: _animationsEnabled,
                                        onPulse: _playHomeShake,
                                        onTap: (from, lifted) {
                                          HapticFeedback.heavyImpact();
                                          EmblemPassage.push<void>(
                                            context,
                                            kind: HomeEmblemKind.rite,
                                            from: from,
                                            page: const PurebloodRiteScreen(),
                                            lifted: lifted,
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Daily Treasure Chest — bottom center above nav bar.
                      // 106 + 128 keeps its centre where the old 160 box
                      // (on 90) had it, clear of the notices under it.
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 106 * hs),
                          child: Opacity(
                            opacity: _isFieldTutorialActive ? 0.35 : 1.0,
                            child: IgnorePointer(
                              ignoring: _isFieldTutorialActive,
                              child: _DailyTreasureChest(scale: hs),
                            ),
                          ),
                        ),
                      ),

                      if (_activeNotifications.isNotEmpty)
                        NotificationBannerStack(
                          key: ValueKey(
                            _activeNotifications
                                .map((n) => '${n.type.toKey()}|${n.stateKey}')
                                .join(','),
                          ),
                          notifications: _activeNotifications,
                          restTop: _noticeRestTop,
                        ),
                    ],
                  );
                },
              ),
            );
          },
    );
  }

  /// Under the hero: ALCHEMY, open or locked (the author, 2026-10-08: "in
  /// the middle, under the portal/showcase area").
  Widget _buildHomeContent(FactionTheme theme, double hs) {
    final u = _alchemy;
    if (u.total == 0 && !u.debug) return const SizedBox.shrink();
    final label = TextStyle(
      color: theme.text,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    );
    return Opacity(
      opacity: _isFieldTutorialActive ? 0.4 : 1.0,
      child: IgnorePointer(
        ignoring: _isFieldTutorialActive,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openAlchemy,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AlchemyEmblem(
                key: _alchemyEmblem,
                size: 84 * hs,
                open: u.open,
                progress: u.progress,
                animate: _animationsEnabled,
                lifted: _alchemyLifted,
              ),
              Transform.translate(
                offset: const Offset(0, -6),
                child: Text('ALCHEMY', style: label),
              ),
              if (!u.open)
                Transform.translate(
                  offset: const Offset(0, -4),
                  child: Text(
                    '${u.found} / ${u.total} FORMULAS',
                    style: label.copyWith(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: theme.text.withValues(alpha: .6),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _playHomeShake() {
    try {
      _shakeController.forward(from: 0.0);
    } catch (_) {}
  }

  /// Reads the portal's state, and tells the player about it the first time
  /// home is shown after it opened (the first descent from space).
  Future<void> _syncHomePortal() async {
    if (!mounted || !await _loadHomePortal() || !mounted) return;
    final settings = context.read<AlchemonsDatabase>().settingsDao;
    final told = await settings.getSetting(HomePortalKeys.told) == '1';
    if (!mounted) return;
    if (told ||
        _homePortalTelling ||
        !widget.isActive ||
        _isFieldTutorialActive ||
        _memoryHomeEventBusy ||
        _memoryStoryShowing ||
        _featuredData == null) {
      return;
    }
    // Claimed before the wait: this runs from several hooks at once.
    _homePortalTelling = true;
    try {
      await settings.setSetting(HomePortalKeys.told, '1');
      // Home settles first; the guide is already going round behind it.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      await showStoryDialog(
        context,
        beats: const [
          StoryBeat(
            title: 'A Way Home',
            message:
                'You can reach your home planet from here now. Draw a circle '
                'around your Alchemon to open a window onto it, and tap the '
                'window to go down.\n\nDraw the circle again to bring your '
                'Alchemon back. The window stays open until you do.',
          ),
        ],
        primaryLabel: 'GOT IT',
      );
    } finally {
      _homePortalTelling = false;
    }
  }

  /// Reads whether the portal is unlocked, open and still to be drawn.
  /// True when it is unlocked.
  Future<bool> _loadHomePortal() async {
    final settings = context.read<AlchemonsDatabase>().settingsDao;
    final unlocked = await settings.getSetting(HomePortalKeys.unlocked) == '1';
    if (!mounted) return false;
    if (!unlocked) {
      if (_homePortalUnlocked) setState(() => _homePortalUnlocked = false);
      return false;
    }
    final open = await settings.getSetting(HomePortalKeys.open) == '1';
    final drawn = await settings.getSetting(HomePortalKeys.drawn) == '1';
    if (!mounted) return false;
    setState(() {
      _homePortalUnlocked = true;
      _homePortalOpen = open;
      _homePortalGuide = !drawn;
    });
    return true;
  }

  void _onHomePortalToggled(bool open) {
    final settings = context.read<AlchemonsDatabase>().settingsDao;
    setState(() {
      _homePortalOpen = open;
      _homePortalGuide = false;
      // Closed: the Alchemon gathers back out of its element.
      if (!open) _featuredReveal = EssenceReveal.once();
    });
    async.unawaited(settings.setSetting(HomePortalKeys.open, open ? '1' : '0'));
    async.unawaited(settings.setSetting(HomePortalKeys.drawn, '1'));
  }

  Future<void> _enterHomePortal(GlobalKey picture, Rect hole) async {
    if (_homePortalDescending) return;
    setState(() => _homePortalDescending = true);
    try {
      async.unawaited(
        context.read<AudioController>().playSound(SoundCue.cosmicPortalOpen),
      );
      // Down through the window as sand, and back up into it the same way.
      await descendToHomeBiome(
        context,
        from: SandSource(picture: picture, circle: hole),
        back: (element) => SandLanding(
          element: element,
          circle: () => HomePortalHero.holeOf(_homePortalKey),
          onLanded: () {
            final hole = HomePortalHero.holeOf(_homePortalKey);
            final at = hole == null ? null : _realmLocal(hole.center);
            if (at != null) _realmField?.ripple(at);
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _homePortalDescending = false;
          _homeBiomeVisit++;
        });
      }
    }
  }

  /// [global] in the home background's own coordinates.
  Offset? _realmLocal(Offset global) {
    final box = _homeStackKey.currentContext?.findRenderObject();
    return box is RenderBox && box.attached ? box.globalToLocal(global) : null;
  }

  Future<void> _maybePlayEnhanceCelebration() async {
    if (_enhanceCelebrationChecking) return;
    _enhanceCelebrationChecking = true;
    try {
      final shop = context.read<ShopService>();
      final shouldCelebrate = await shop.consumeEnhanceCelebration();
      if (!shouldCelebrate || !mounted) return;

      HapticFeedback.heavyImpact();
      setState(() => _enhanceHighlightActive = true);

      _enhanceRevealController
        ..value = 0.0
        ..forward();
      _playHomeShake();
    } finally {
      _enhanceCelebrationChecking = false;
    }
  }

  Future<void> _playHomeShakeFor(Duration duration) async {
    final previousDuration = _shakeController.duration;
    try {
      _shakeController.duration = const Duration(milliseconds: 450);
      _shakeController.repeat(reverse: true);
      await Future.delayed(duration);
    } finally {
      if (mounted) {
        _shakeController
          ..stop()
          ..value = 0.0
          ..duration = previousDuration;
      }
    }
  }

  Future<void> _maybeRunCosmicMemoryHomeEvent() async {
    if (!mounted ||
        !widget.isActive ||
        _isFieldTutorialActive ||
        _memoryHomeEventBusy ||
        _memoryStoryShowing) {
      return;
    }

    // Claim the guard before the first await. This runs from initState,
    // didUpdateWidget and didPopNext, and the portal below returns straight
    // into another didPopNext. If the flag were only set further down, two of
    // those could sail past the check during the awaits and each push their own
    // memory screen — which is how the "Is this a memory?" dialogs stacked.
    _memoryHomeEventBusy = true;
    try {
      await _runCosmicMemoryHomeEvent();
    } finally {
      _memoryHomeEventBusy = false;
    }
  }

  Future<void> _runCosmicMemoryHomeEvent() async {
    final db = context.read<AlchemonsDatabase>();
    final settings = db.settingsDao;
    final storyPending = await CosmicMemoryTutorialService.isStoryPending(
      settings,
    );
    if (!mounted || !widget.isActive) return;

    if (storyPending) {
      _memoryStoryShowing = true;
      try {
        // The memory itself prompts each control as it is needed; a recap
        // here (once a dialog, then a six-second snack) only repeated it.
        await CosmicMemoryTutorialService.acknowledgeStory(settings);
      } finally {
        _memoryStoryShowing = false;
      }
      return;
    }

    // An unfinished memory from earlier in this session stays queued for next
    // launch, but must not relaunch the moment we land back on home.
    if (CosmicMemoryTutorialService.isDeferredThisSession) return;

    final ownedInstanceCount = (await db.creatureDao.listAllInstances()).length;
    await CosmicMemoryTutorialService.recoverPendingForExistingProfile(
      settings,
      ownedInstanceCount: ownedInstanceCount,
    );
    if (!mounted || !widget.isActive) return;

    final pending = await CosmicMemoryTutorialService.isHomePortalPending(
      settings,
    );
    if (!mounted || !widget.isActive || !pending) return;

    await _playHomeShakeFor(const Duration(seconds: 3));
    if (!mounted || !widget.isActive) return;

    await CosmicMemoryTutorialService.markHomePortalLaunched(settings);
    if (!mounted || !widget.isActive) return;
    await VoidPortal.push<void>(
      context,
      page: const CosmicScreen(memoryTutorial: true),
      config: VoidPortalConfig.cinematic,
    );

    if (!await CosmicMemoryTutorialService.isCompleted(settings)) {
      // The player left the memory early. `recoverPendingForExistingProfile`
      // will re-queue it from the leftover launch marker, so holding off for
      // the rest of this session is what keeps that from becoming a relaunch
      // loop they cannot escape.
      CosmicMemoryTutorialService.deferForThisSession();
      return;
    }

    // Completing it queued the closing line. Show it now rather than waiting
    // for home to become active again — didPopNext is already blocked by the
    // busy guard we are still holding.
    if (mounted && widget.isActive) {
      await _runCosmicMemoryHomeEvent();
    }
  }

  /// One-time migration: saves that defeated turn-based gauntlet bosses
  /// (feature removed) keep the relics those defeats earned.
  Future<void> _migrateLegacyBossRelics() async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final done = await db.settingsDao.getSetting(
      'legacy_boss_relic_migration_done',
    );
    if (done == '1') return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('boss_progress');
    if (raw != null && raw.isNotEmpty) {
      final data = Uri.splitQueryString(raw);
      for (final entry in kLegacyBossIdToElement.entries) {
        final count = int.tryParse(data[entry.key] ?? '0') ?? 0;
        if (count <= 0) continue;
        final traitKey = BossLootKeys.traitKeyForElement(entry.value);
        final qty = await db.inventoryDao.getItemQty(traitKey);
        if (qty == 0) {
          await db.inventoryDao.addItemQty(traitKey, 1);
          debugPrint('🔑 Migrated legacy boss relic: $traitKey');
        }
      }
    }
    await db.settingsDao.setSetting('legacy_boss_relic_migration_done', '1');
  }

  /// The Mystic Altar shortcut shows once the player owns (or has placed)
  /// any relic.
  Future<void> _refreshHasAnyRelic() async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    var found = false;
    for (final entry in kAltarEntries) {
      final qty = await db.inventoryDao.getItemQty(
        BossLootKeys.traitKeyForElement(entry.element),
      );
      if (qty > 0) {
        found = true;
        break;
      }
    }
    if (!found) {
      final placed = await db.altarDao.getRelicPlacedIds(
        kAltarEntries.map((e) => e.id).toList(),
      );
      found = placed.isNotEmpty;
    }
    if (mounted && found != _hasAnyRelic) {
      setState(() => _hasAnyRelic = found);
    }
  }

  Future<void> _refreshSurvivalUnlocked() async {
    final db = context.read<AlchemonsDatabase>();
    var unlocked = await db.settingsDao.isCosmicSurvivalPortalDiscovered();
    if (!unlocked) {
      // A save that followed the signal before its tutorial wrote the row:
      // it was told the portal was unlocked, so it is.
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(CosmicScreen.survivalIntroCompletedPrefsKey) ?? false) {
        await db.settingsDao.setCosmicSurvivalPortalDiscovered();
        unlocked = true;
      }
    }
    if (mounted && unlocked != _survivalUnlocked) {
      setState(() => _survivalUnlocked = unlocked);
    }
  }

  Future<void> _openCosmicSurvival() async {
    HapticFeedback.mediumImpact();
    final db = context.read<AlchemonsDatabase>();
    final unlocked = await db.settingsDao.isCosmicSurvivalPortalDiscovered();
    if (!mounted) return;
    if (!unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Discover the cosmic portal to unlock Survival.'),
        ),
      );
      return;
    }
    // The equipped orb grows out of the dock onto the hub's own.
    final ready = ValueNotifier<bool>(false);
    EmblemPassage.pushScene<void>(
      context,
      scene: SurvivalPassage(
        skin: context.read<SurvivalUpgradeService>().state.equippedSkin,
        target: survivalLobbyOrbFor,
      ),
      from: _survivalEmblem,
      page: CosmicSurvivalScreen(revealReady: ready),
      ready: ready,
      lifted: _survivalLifted,
    );
  }

  Future<void> _grantStarterIfNeeded(
    FactionId faction,
    WildernessSpawnService spawnService,
  ) async {
    final db = context.read<AlchemonsDatabase>();
    final starterService = context.read<StarterGrantService>();

    // Ensure at least one slot is unlocked
    final slots = await db.incubatorDao.watchSlots().first;
    final anyUnlocked = slots.any((s) => s.unlocked);
    if (!anyUnlocked) {
      await db.incubatorDao.unlockSlot(0);
    }

    final granted = await starterService.ensureStarterGranted(
      faction,
      tutorialHatch: const Duration(seconds: 10),
    );

    if (granted) {
      // The opening day of halved cultivation. Given here rather than on
      // first launch because this is the moment the save actually begins —
      // a faction is chosen and the first vial exists — so the day is not
      // burned by someone who opened the app and went away again.
      if (mounted) {
        await context.read<TimedBoostService>().giveOpeningGrant();
      }

      // 🔑 Set extraction pending IMMEDIATELY after grant (before any UI)
      // This ensures restart will know to redirect to extraction
      await db.settingsDao.setSetting('tutorial_extraction_pending', '1');
      await db.settingsDao.setNavLocked(true);
      await OpeningWildernessService.activateForFaction(
        db.settingsDao,
        faction,
      );
      await _ensureOpeningWildernessReady(faction, spawnService);

      if (!mounted) return;

      // No "Vial secured" dialog: the vial the player just chose is carried
      // straight into its chamber by the faction picker's handoff
      // (starter_vial_handoff.dart), which lands once this tab is showing.
      widget.onNavigateSection(NavSection.breed, breedInitialTab: 1);
      StarterVialHandoff.instance.land();
    } else {
      StarterVialHandoff.instance.cancel();
    }
  }

  Widget _buildHeader(FactionTheme theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 🔹 Disable + dim Profile button during Field Tutorial
            if (_isFieldTutorialActive)
              Opacity(
                opacity: 0.35,
                child: IgnorePointer(
                  ignoring: true,
                  child: AvatarButton(
                    theme: theme,
                    onTap: () {}, // disabled during tutorial
                  ),
                ),
              )
            else
              AvatarButton(
                theme: theme,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, ProfileScreen.route());
                },
              ),

            const Spacer(),
            // Absent unless a boost is running, so it costs the header
            // nothing the rest of the time.
            if (!_isFieldTutorialActive)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: HalfCultivationChip(),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Opacity(
                opacity: _isFieldTutorialActive ? 0.35 : 1.0,
                child: IgnorePointer(
                  ignoring: _isFieldTutorialActive,
                  child: const CurrencyDisplayWidget(),
                ),
              ),
            ),
          ],
        ),
        Column(
          children: [
            // The title in particles: it fills in letter by letter at
            // launch; drag through it, tap it, hold it to recolour it.
            ParticleTitle(
              darkBackdrop: theme.brightness == Brightness.dark,
              active: _animationsEnabled,
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily Treasure Chest
// ─────────────────────────────────────────────────────────────────────────────

/// Home is a fixed-composition screen: a hero, a side dock, a right-hand orb
/// column and the daily chest, all anchored to the edges at hard-coded pixel
/// sizes. On a short viewport they collide — the hero ends around 348px down,
/// the chest occupies the bottom 250px, and the side dock runs down from 140.
/// That is roughly 600px of committed height before anything flexes.
///
/// Rather than reposition each piece independently, every fixed dimension is
/// multiplied by one factor derived from the available height. Screens at or
/// above the height the layout was composed for are untouched (k == 1).
const double _kHomeDesignHeight = 780.0;

/// Floor chosen so text and touch targets stay usable — below this the screen
/// is too short for this composition and shrinking further would not help.
const double _kHomeMinScale = 0.68;

double _homeScaleFor(double availableHeight) =>
    (availableHeight / _kHomeDesignHeight).clamp(_kHomeMinScale, 1.0);

/// Test hooks — the layout maths is worth pinning, the widget tree needs a
/// database and fifteen providers to pump.
@visibleForTesting
double homeScaleForTest(double availableHeight) =>
    _homeScaleFor(availableHeight);

@visibleForTesting
const double homeMinScaleForTest = _kHomeMinScale;

class _DailyTreasureChest extends StatefulWidget {
  const _DailyTreasureChest({this.scale = 1.0});

  /// Shrinks the chest on short screens so it does not run into the hero
  /// above it. See [_homeScaleFor].
  final double scale;

  @override
  State<_DailyTreasureChest> createState() => _DailyTreasureChestState();
}

/// Every timing in the daily-chest sequence is scaled by this. The original
/// pacing was correct in shape but slow to sit through once a day, every day.
const double _kTreasureSpeedUp = 0.70;

Duration _treasureMs(int ms) =>
    Duration(milliseconds: (ms * _kTreasureSpeedUp).round());

class _DailyTreasureChestState extends State<_DailyTreasureChest>
    with SingleTickerProviderStateMixin {
  /// The unsealing, 0 → 1. The rewards land as it ends. Long enough for
  /// it to flow: at 1.4s the element's motion was a rush.
  late final AnimationController _openCtrl = AnimationController(
    vsync: this,
    duration: _treasureMs(3000),
  );
  bool _isClaimed = false;
  bool _isPlaying = false;

  static const _settingKey = 'daily_loot_key';

  String get _todayKey =>
      DateTime.now().toUtc().toIso8601String().split('T').first;

  @override
  void initState() {
    super.initState();
    _checkClaimed();
  }

  Future<void> _checkClaimed() async {
    final db = context.read<AlchemonsDatabase>();
    final saved = await db.settingsDao.getSetting(_settingKey);
    if (!mounted) return;
    setState(() {
      _isClaimed = saved == _todayKey;
    });
  }

  @override
  void dispose() {
    _openCtrl.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_isClaimed || _isPlaying) return;
    // Tap: you touched it.
    HapticFeedback.lightImpact();
    setState(() => _isPlaying = true);

    _openCtrl.forward(from: 0);

    // The seal cracking is the moment worth feeling, so land a heavier beat
    // there rather than only at the ends.
    Future.delayed(_openCtrl.duration! * 0.4, () {
      if (mounted) HapticFeedback.mediumImpact();
    });

    await Future.delayed(_openCtrl.duration!);

    if (!mounted) return;

    // Grant rewards
    final rng = Random();
    final db = context.read<AlchemonsDatabase>();
    // Read before the awaits below — this context must not be used after them.
    final catalog = context.read<CreatureCatalog>();
    final silver = 150 + rng.nextInt(351); // 150–500
    final int gold = rng.nextDouble() < 0.15 ? 1 : 0;
    final bool givesVial = rng.nextDouble() < 0.25;

    await db.currencyDao.addSilver(silver);
    if (gold > 0) await db.currencyDao.addGold(gold);
    // Held so the reward row can name the group the player actually got —
    // it used to say "COMMON VIAL" in verdant green whatever came out.
    ElementalGroup? vialGroup;
    if (givesVial) {
      try {
        // Only groups that can actually yield a Common specimen. Arcane
        // starts at Uncommon, so an arcane worn vial is a dead item that
        // answers "No creatures available for this vial type" forever.
        final groups = groupsWithSpecimensAt(
          catalog.creatures,
          VialRarity.common,
        );
        if (groups.isNotEmpty) {
          final group = groups[rng.nextInt(groups.length)];
          await db.inventoryDao.addVial('Daily Vial', group, VialRarity.common);
          vialGroup = group;
        }
      } catch (_) {}
    }

    // Persist claim
    await db.settingsDao.setSetting(_settingKey, _todayKey);
    if (!mounted) return;
    setState(() {
      _isClaimed = true;
      _isPlaying = false;
    });

    // Build loot rewards
    final rewards = [
      _TreasureReward(
        coin: CoinKind.silver,
        amount: '+$silver',
        name: 'SILVER',
        color: const Color(0xFFB0BEC5),
      ),
      if (gold > 0)
        _TreasureReward(
          coin: CoinKind.gold,
          amount: '+$gold',
          name: 'GOLD',
          color: const Color(0xFFFFD700),
        ),
      if (vialGroup != null)
        _TreasureReward(
          // The game's own test-tube glyph. `science_rounded` is a conical
          // flask, which is the alchemy-effect mark, not a vial.
          icon: AppIcons.biotech_rounded,
          amount: '×1',
          name: '${vialGroup.displayName.toUpperCase()} VIAL',
          color: vialGroup.skin.badge,
        ),
    ];

    if (!mounted) return;
    await _showTreasureLootDialog(context, rewards);
  }

  @override
  Widget build(BuildContext context) {
    if (_isClaimed) return const SizedBox.shrink();
    final faction = context.watch<FactionService>().current;
    return GestureDetector(
      onTap: context.soundAction(_onTap),
      behavior: HitTestBehavior.opaque,
      child: DailyReliquary(
        element: dailyCacheElementFor(faction),
        size: 128 * widget.scale,
        opening: _openCtrl,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Treasure Loot Dialog — sleek animated reward reveal
// ─────────────────────────────────────────────────────────────────────────────

class _TreasureReward {
  /// Only read when [coin] is null — a coin always draws its own SVG.
  final IconData? icon;
  final CoinKind? coin;
  final String amount;
  final String name;
  final Color color;

  const _TreasureReward({
    this.icon,
    this.coin,
    required this.amount,
    required this.name,
    required this.color,
  });
}

Future<void> _showTreasureLootDialog(
  BuildContext context,
  List<_TreasureReward> rewards,
) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.80),
    transitionDuration: _treasureMs(350),
    transitionBuilder: (ctx, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
    pageBuilder: (ctx, _, __) => _TreasureLootDialog(rewards: rewards),
  );
}

class _TreasureLootDialog extends StatefulWidget {
  final List<_TreasureReward> rewards;
  const _TreasureLootDialog({required this.rewards});

  @override
  State<_TreasureLootDialog> createState() => _TreasureLootDialogState();
}

class _TreasureLootDialogState extends State<_TreasureLootDialog>
    with TickerProviderStateMixin {
  late final List<AnimationController> _rowCtrls;
  late final List<Animation<double>> _rowFade;
  late final List<Animation<Offset>> _rowSlide;
  late final AnimationController _btnCtrl;
  late final Animation<double> _btnFade;

  @override
  void initState() {
    super.initState();

    _rowCtrls = List.generate(
      widget.rewards.length,
      (_) => AnimationController(vsync: this, duration: _treasureMs(480)),
    );
    _rowFade = _rowCtrls
        .map(
          (c) => CurvedAnimation(
            parent: c,
            curve: Curves.easeOut,
          ).drive(Tween(begin: 0.0, end: 1.0)),
        )
        .toList();
    _rowSlide = _rowCtrls
        .map(
          (c) => CurvedAnimation(
            parent: c,
            curve: Curves.easeOutCubic,
          ).drive(Tween(begin: const Offset(0, 0.25), end: Offset.zero)),
        )
        .toList();

    _btnCtrl = AnimationController(vsync: this, duration: _treasureMs(380));
    _btnFade = CurvedAnimation(
      parent: _btnCtrl,
      curve: Curves.easeIn,
    ).drive(Tween(begin: 0.0, end: 1.0));

    // Stagger rows then button. Each row gets its own tick as it lands — the
    // count-up is the part that should feel like receiving something, and it
    // was silent.
    for (int i = 0; i < _rowCtrls.length; i++) {
      Future.delayed(_treasureMs(300 + i * 240), () {
        if (!mounted) return;
        _rowCtrls[i].forward();
        // Gold is the 15% drop — it should land harder than the silver that
        // arrives every single day.
        if (widget.rewards[i].coin == CoinKind.gold) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.selectionClick();
        }
      });
    }
    final btnDelay = 300 + widget.rewards.length * 240 + 180;
    Future.delayed(_treasureMs(btnDelay), () {
      if (mounted) _btnCtrl.forward();
    });
  }

  @override
  void dispose() {
    for (final c in _rowCtrls) {
      c.dispose();
    }
    _btnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFFFAA00);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'DAILY REWARDS',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 5.0,
                ),
              ),
              const SizedBox(height: 8),
              Container(height: 1, color: amber.withValues(alpha: 0.25)),
              const SizedBox(height: 36),

              // Reward rows
              ...List.generate(widget.rewards.length, (i) {
                final r = widget.rewards[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: FadeTransition(
                    opacity: _rowFade[i],
                    child: SlideTransition(
                      position: _rowSlide[i],
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: r.color.withValues(alpha: 0.12),
                              border: Border.all(
                                color: r.color.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: r.coin != null
                                ? CoinIcon(kind: r.coin!, size: 24)
                                : Icon(r.icon, color: r.color, size: 22),
                          ),
                          const SizedBox(width: 18),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.amount,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: r.color,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                r.name,
                                style: const TextStyle(
                                  color: Color(0xFF7A7A8A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 8),

              // Collect button
              FadeTransition(
                opacity: _btnFade,
                child: GestureDetector(
                  onTap: context.soundAction(() {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  }),
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: amber, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: amber.withValues(alpha: 0.22),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'COLLECT',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Color(0xFFFFCC44),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.0,
                        ),
                      ),
                    ),
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
