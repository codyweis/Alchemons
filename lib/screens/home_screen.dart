// lib/screens/home_screen.dart

import 'dart:ui';
import 'dart:math' as math;

import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/screens/competition_hub_screen.dart';
import 'package:alchemons/screens/map_screen.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/avatar_widget.dart';
import 'package:alchemons/widgets/blob_party/overlays/floating_bubble_overlay.dart';
import 'package:alchemons/widgets/creature_showcase_widget.dart';
import 'package:alchemons/widgets/side_dock_widget.dart';
import 'package:alchemons/widgets/theme_switch_widget.dart';
import 'package:flame/components.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/widgets/game_card.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/screens/creatures_screen.dart';
import 'package:alchemons/screens/faction_picker.dart';
import 'package:alchemons/screens/feeding_screen.dart';
import 'package:alchemons/screens/field_screen.dart';
import 'package:alchemons/screens/harvest_screen.dart';
import 'package:alchemons/screens/profile_screen.dart';
import 'package:alchemons/screens/shop_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/harvest_service.dart';
import 'package:alchemons/services/starter_grant_service.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/background/interactive_background_widget.dart';
import 'package:alchemons/widgets/element_resource_widget.dart';
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/creature_dialog.dart';
import '../providers/app_providers.dart';
import 'breed/breed_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

const double _kNavHeight = 92;
const double _kNavReserve = _kNavHeight + 12; // extra breathing room

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _rotationController;
  late AnimationController _particleController;
  late AnimationController _waveController;
  late AnimationController _glowController;
  late AnimationController _navAnimController;

  bool _isInitialized = false;
  NavSection _currentSection = NavSection.home;
  int? _pendingBreedInitialTab;

  // Notification banners
  final List<_NotificationBanner> _activeNotifications = [];

  // FEATURED HERO STATE
  PresentationData? _featuredData;
  String? _featuredInstanceId;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _particleController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
    _waveController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);
    _navAnimController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeApp();
    });
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    _waveController.dispose();
    _glowController.dispose();
    _navAnimController.dispose();
    super.dispose();
  }

  void _goToSection(NavSection section, {int? breedInitialTab}) {
    setState(() {
      _currentSection = section;
      if (section == NavSection.breed) {
        _pendingBreedInitialTab = breedInitialTab;
      }
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _initializeApp() async {
    try {
      await _initializeRepository();
      final factionSvc = context.read<FactionService>();

      await factionSvc.loadId();
      var faction = factionSvc.current;

      if (!mounted) return;

      if (faction == null) {
        final selected = await showDialog<FactionId>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const FactionPickerDialog(),
        );
        if (!mounted || selected == null) return;
        await factionSvc.setId(selected);
        faction = selected;
      }

      await factionSvc.ensureAirExtraSlotUnlocked();
      await _grantStarterIfNeeded(faction);

      // Load featured hero selection from settings, or autopick fallback
      final db = context.read<AlchemonsDatabase>();
      final repo = context.read<CreatureRepository>();

      final featuredInstance = await _loadFeaturedInstanceOrAuto();
      if (featuredInstance != null) {
        _featuredInstanceId = featuredInstance.instanceId;
        _featuredData = _presentationFromInstance(featuredInstance, repo);
      } else {
        _featuredInstanceId = null;
        _featuredData = null;
      }

      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Error during app initialization: $e');
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

  Future<void> _initializeRepository() async {
    try {
      final repository = context.read<CreatureRepository>();
      await repository.loadCreatures();
    } catch (e) {
      debugPrint('Error loading creature repository: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load specimen database: $e'),
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  ({double particle, double rotation, double elemental}) _speedFor(
    FactionId faction,
  ) {
    switch (faction) {
      case FactionId.fire:
        return (particle: .1, rotation: 0.1, elemental: .3);
      case FactionId.water:
        return (particle: 1, rotation: 0.1, elemental: .5);
      case FactionId.air:
        return (particle: 1, rotation: 0.1, elemental: 1);
      case FactionId.earth:
        return (particle: 1, rotation: 0.1, elemental: 0.2);
    }
  }

  void _navigateToSection(NavSection section) {
    _goToSection(section);
  }

  void _showNotification(_NotificationBanner banner) {
    setState(() {
      // Remove duplicates of same type
      _activeNotifications.removeWhere((n) => n.type == banner.type);
      _activeNotifications.add(banner);
    });
  }

  void _clearNotification(_NotificationBannerType type) {
    setState(() {
      _activeNotifications.removeWhere((n) => n.type == type);
    });
  }

  void _removeNotification(_NotificationBanner banner) {
    setState(() {
      _activeNotifications.remove(banner);
    });
  }

  // ============================================================
  // FEATURED HERO HELPERS
  // ============================================================

  Future<CreatureInstance?> _loadFeaturedInstanceOrAuto() async {
    final db = context.read<AlchemonsDatabase>();

    // Attempt to load saved featured instance
    final savedId = await db.getFeaturedInstanceId();
    if (savedId != null && savedId.isNotEmpty) {
      final chosen = await db.getInstance(savedId);
      if (chosen != null) {
        return chosen;
      }
    }

    // Auto-pick fallback
    final all = await db.listAllInstances();
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

  PresentationData? _presentationFromInstance(
    CreatureInstance pick,
    CreatureRepository repo,
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

    // decode cosmetics
    final geneticsJson = pick.geneticsJson ?? '{}';
    final genes = decodeGenetics(geneticsJson);

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

    final finalSubtitle = pick.isPrismaticSkin
        ? 'PRISMATIC VARIANT • $subtitleLine'
        : subtitleLine;

    return PresentationData(
      displayName: displayTitle,
      subtitle: finalSubtitle,
      spritePath: sprite.spriteSheetPath,
      totalFrames: sprite.totalFrames,
      rows: sprite.rows,
      frameSize: Vector2(
        sprite.frameWidth.toDouble(),
        sprite.frameHeight.toDouble(),
      ),
      stepTime: sprite.frameDurationMs / 1000.0,
      scale: scaleFromGenes(genes),
      saturation: satFromGenes(genes),
      brightness: briFromGenes(genes),
      hueShift: hueFromGenes(genes),
      isPrismatic: pick.isPrismaticSkin,
      tint: null,
    );
  }

  Future<void> _handleChooseFeaturedInstance() async {
    // Long press handler:
    // 1) choose species
    // 2) choose specific instance
    // 3) persist + update state

    HapticFeedback.mediumImpact();

    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureRepository>();
    final theme = context.read<FactionTheme>();
    final gameState = context.read<GameStateNotifier>();

    // Step 1: pick species
    final pickedSpeciesId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return CreatureSelectionSheet(
              scrollController: scrollController,
              discoveredCreatures: gameState.discoveredCreatures,
              onSelectCreature: (creatureId) {
                Navigator.pop(context, creatureId);
              },
            );
          },
        );
      },
    );

    if (pickedSpeciesId == null) return;

    final species = repo.getCreatureById(pickedSpeciesId);
    if (species == null) return;

    // Step 2: pick instance of that species
    final pickedInstance = await showModalBottomSheet<CreatureInstance>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return InstancesSheet(
          theme: theme,
          species: species,
          onTap: (CreatureInstance ci) {
            Navigator.pop(context, ci);
          },
        );
      },
    );

    if (pickedInstance == null) return;

    // Step 3: persist choice
    await db.setFeaturedInstanceId(pickedInstance.instanceId);

    // Step 4: update local state
    final newPresentation = _presentationFromInstance(pickedInstance, repo);
    if (!mounted) return;
    setState(() {
      _featuredInstanceId = pickedInstance.instanceId;
      _featuredData = newPresentation;
    });

    HapticFeedback.lightImpact();
  }

  Future<void> _handleOpenFeaturedDetails() async {
    // Tap handler:
    // Open details dialog for currently featured instance (if any)
    final repo = context.read<CreatureRepository>();
    final db = context.read<AlchemonsDatabase>();

    final id = _featuredInstanceId;
    if (id == null) return;

    final inst = await db.getInstance(id);
    if (inst == null) return;

    final base = repo.getCreatureById(inst.baseId);
    if (base == null) return;

    CreatureDetailsDialog.show(
      context,
      base,
      false, // "isDiscovered" - we treat true if instanceId is provided
      instanceId: inst.instanceId,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Consumer2<GameStateNotifier, CatalogData?>(
      builder: (context, gameState, catalogData, _) {
        if (catalogData == null ||
            !catalogData.isFullyLoaded ||
            !_isInitialized) {
          return _buildLoadingScreen('Initializing research facility...');
        }
        if (gameState.isLoading) {
          return _buildLoadingScreen('Loading specimen database...');
        }
        if (gameState.error != null) {
          return _buildErrorScreen(gameState.error!, gameState.refresh);
        }

        final factionSvc = context.watch<FactionService>();
        final currentFaction =
            factionSvc.current ?? FactionId.water; // safe fallback
        final theme = context.watch<FactionTheme>();
        final speeds = _speedFor(currentFaction);

        return Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              // Background (theme-driven)
              InteractiveBackground(
                particleController: _particleController,
                rotationController: _rotationController,
                waveController: _waveController,
                primaryColor: theme.primary,
                secondaryColor: theme.secondary,
                accentColor: theme.accent,
                factionType: currentFaction,
                particleSpeed: speeds.particle,
                rotationSpeed: speeds.rotation,
                elementalSpeed: speeds.elemental,
              ),
              // Side floating dock (only on Home)

              // Main content
              SafeArea(
                top: _currentSection == NavSection.home ? true : false,
                bottom: false,
                child: Column(
                  children: [
                    if (_currentSection == NavSection.home) _buildHeader(theme),
                    // ==== HERO SHOWCASE ====
                    if (_featuredData != null &&
                        _currentSection == NavSection.home) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 260,
                        child: Center(
                          child: FeaturedHeroInteractive(
                            data: _featuredData!,
                            theme: theme,
                            breathing: _breathingController,
                            onLongPressChoose: _handleChooseFeaturedInstance,
                            onTapDetails: _handleOpenFeaturedDetails,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        child: _buildSectionContent(
                          gameState,
                          theme,
                          key: ValueKey(_currentSection),
                        ),
                      ),
                    ),

                    // Bottom Navigation Bar
                    BottomNav(
                      current: _currentSection,
                      onSelect: (s) => _navigateToSection(s),
                      theme: theme,
                    ),
                  ],
                ),
              ),
              if (_currentSection == NavSection.home)
                Positioned(
                  // tweak these numbers until it sits where you want
                  top: MediaQuery.of(context).padding.top + 140,
                  left: 0,
                  child: SideDockFloating(
                    theme: theme,
                    onEnhance: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => const FeedingScreen(),
                          fullscreenDialog: true,
                        ),
                      );
                    },
                    onHarvest: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => const BiomeHarvestScreen(),
                          fullscreenDialog: true,
                        ),
                      );
                    },
                    onCompetitions: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => const CompetitionHubScreen(),
                          fullscreenDialog: true,
                        ),
                      );
                    },
                  ),
                ),

              // Blob party overlay floats above content;
              // if you want hero OVER bubbles, move this below SafeArea in the Stack.
              if (_currentSection == NavSection.home)
                FloatingBubblesOverlay(
                  regionPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                  discoveredCreatures: gameState.discoveredCreatures,
                  theme: theme,
                ),

              // Notification banner stack (floats on top)
              if (_currentSection == NavSection.home &&
                  _activeNotifications.isNotEmpty)
                _NotificationBannerStack(
                  notifications: _activeNotifications,
                  onDismiss: _removeNotification,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionContent(
    GameStateNotifier gameState,
    FactionTheme theme, {
    Key? key,
  }) {
    switch (_currentSection) {
      case NavSection.home:
        return _buildHomeContent(gameState, theme);
      case NavSection.creatures:
        return const CreaturesScreen();
      case NavSection.field:
        return const MapScreen();
      case NavSection.shop:
        return const ShopScreen();
      case NavSection.breed:
        final tabToOpen = _pendingBreedInitialTab ?? 0;
        // clear it so if user manually comes back later we don't force tab 1 again
        _pendingBreedInitialTab = null;
        return BreedScreen(initialTab: tabToOpen);
      case NavSection.enhance:
        return const FeedingScreen();
    }
  }

  Widget _buildHomeContent(GameStateNotifier gameState, FactionTheme theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          const SizedBox(height: 80), // breathing room above bottom nav
        ],
      ),
    );
  }

  Future<void> _grantStarterIfNeeded(FactionId faction) async {
    final db = context.read<AlchemonsDatabase>();
    final slots = await db.watchSlots().first;
    final anyUnlocked = slots.any((s) => s.unlocked);
    if (!anyUnlocked) {
      await db.unlockSlot(0);
    }

    final granted = await db.ensureStarterGranted(
      faction,
      tutorialHatch: const Duration(seconds: 10),
    );
    if (!mounted) return;
    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🧪 Your starter Alchemon has been placed in Chamber 1!',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // ========= HEADER (clean) =========
  Widget _buildHeader(FactionTheme theme) {
    return Column(
      children: [
        // Resource strip
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AvatarButton(
              theme: theme,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: ResourceCollectionWidget(theme: theme),
              ),
            ),
          ],
        ),
        Column(
          children: [
            Text(
              'ALCHEMONS',
              style: GoogleFonts.cinzelDecorative(
                color: theme.text,
                fontWeight: FontWeight.w800,
                fontSize: 40,
                letterSpacing: 1,
              ),
            ),
            Text(
              'Research Facility',
              style: GoogleFonts.cinzelDecorative(
                color: theme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingScreen(String message) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 24),
            Text(
              'Please wait…',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error, VoidCallback onRetry) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade400, size: 64),
              const SizedBox(height: 16),
              Text(
                'Error Loading',
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// NOTIFICATION BANNER SYSTEM
// (unchanged from your version except for being moved down a bit)
// ============================================================================

enum _NotificationBannerType {
  eggReady,
  harvestReady,
  dailyReward,
  bossAvailable,
  eventActive,
}

class _NotificationBanner {
  final _NotificationBannerType type;
  final String title;
  final String? subtitle;
  final int count;
  final VoidCallback onTap;

  _NotificationBanner({
    required this.type,
    required this.title,
    this.subtitle,
    this.count = 1,
    required this.onTap,
  });
}

class _NotificationBannerWidget extends StatefulWidget {
  final _NotificationBanner notification;
  final VoidCallback onDismiss;

  const _NotificationBannerWidget({
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<_NotificationBannerWidget> createState() =>
      _NotificationBannerWidgetState();
}

class _NotificationBannerWidgetState extends State<_NotificationBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _isCollapsed = false;
  double _dragPosition = 0.0; // 0 = expanded, 1 = collapsed

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5)),
    );

    _controller.forward();

    // auto-collapse
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_isCollapsed) _collapse();
    });
  }

  void _collapse() {
    setState(() => _isCollapsed = true);
    HapticFeedback.lightImpact();
  }

  void _expand() {
    setState(() => _isCollapsed = false);
    HapticFeedback.mediumImpact();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragPosition = (_dragPosition + details.primaryDelta! / 200).clamp(
        0.0,
        1.0,
      );
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragPosition > 0.5) {
      _collapse();
    } else {
      _expand();
    }
    setState(() => _dragPosition = 0.0);
  }

  Color _getBannerColor() {
    switch (widget.notification.type) {
      case _NotificationBannerType.eggReady:
        return const Color.fromARGB(255, 255, 240, 217);
      case _NotificationBannerType.harvestReady:
        return const Color.fromARGB(255, 217, 255, 218);
      case _NotificationBannerType.dailyReward:
        return const Color(0xFF9C27B0);
      case _NotificationBannerType.bossAvailable:
        return const Color(0xFFF44336);
      case _NotificationBannerType.eventActive:
        return const Color(0xFF2196F3);
    }
  }

  IconData _getBannerIcon() {
    switch (widget.notification.type) {
      case _NotificationBannerType.eggReady:
        return Icons.egg_rounded;
      case _NotificationBannerType.harvestReady:
        return Icons.agriculture_rounded;
      case _NotificationBannerType.dailyReward:
        return Icons.card_giftcard_rounded;
      case _NotificationBannerType.bossAvailable:
        return Icons.warning_rounded;
      case _NotificationBannerType.eventActive:
        return Icons.event_rounded;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActuallyCollapsed = _isCollapsed && _dragPosition < 0.5;
    final collapseProgress = _isCollapsed ? 1.0 - _dragPosition : _dragPosition;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          // horizontal drag still works globally to collapse/expand
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,

          // 🔴 we REMOVE the old onTap from here,
          // because tap is now handled inside the child rows
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.only(
              right: isActuallyCollapsed ? 0 : 12,
              top: 8,
              bottom: 8,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isActuallyCollapsed ? 8 : 16,
              vertical: 12,
            ),
            width: isActuallyCollapsed ? 48 : null,
            decoration: BoxDecoration(
              color: _getBannerColor(),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(8),
                bottomLeft: const Radius.circular(8),
                topRight: isActuallyCollapsed
                    ? const Radius.circular(8)
                    : Radius.zero,
                bottomRight: isActuallyCollapsed
                    ? const Radius.circular(8)
                    : Radius.zero,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(-2, 2),
                ),
              ],
            ),
            child: isActuallyCollapsed
                ? _buildCollapsedTab()
                : _buildExpandedBannerRowSplit(), // 👈 new
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedBannerRowSplit() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // LEFT: icon + text (navigate)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // navigating behavior only
            HapticFeedback.mediumImpact();
            widget.notification.onTap();
            _collapse();
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getBannerIcon(),
                color: const Color.fromARGB(255, 0, 0, 0),
                size: 24,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.notification.title,
                        style: const TextStyle(
                          color: Color.fromARGB(255, 0, 0, 0),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (widget.notification.count > 1) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(
                              255,
                              0,
                              0,
                              0,
                            ).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${widget.notification.count}',
                            style: const TextStyle(
                              color: Color.fromARGB(255, 0, 0, 0),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (widget.notification.subtitle != null)
                    Text(
                      widget.notification.subtitle!,
                      style: TextStyle(
                        color: const Color.fromARGB(
                          255,
                          0,
                          0,
                          0,
                        ).withOpacity(0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // RIGHT: chevron (collapse only)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // only collapse/expand logic, no navigation
            if (_isCollapsed) {
              _expand();
            } else {
              _collapse();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.7),
              size: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedTab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _getBannerIcon(),
          color: const Color.fromARGB(255, 0, 0, 0),
          size: 20,
        ),
        if (widget.notification.count > 1) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${widget.notification.count}',
              style: const TextStyle(
                color: Color.fromARGB(255, 0, 0, 0),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NotificationBannerStack extends StatelessWidget {
  final List<_NotificationBanner> notifications;
  final Function(_NotificationBanner) onDismiss;

  const _NotificationBannerStack({
    required this.notifications,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 120,
      right: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: notifications
            .map(
              (notification) => _NotificationBannerWidget(
                notification: notification,
                onDismiss: () => onDismiss(notification),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ============================================================================
// UNIFIED OPERATIONS PANEL - Scientific/Lab Display
// ============================================================================

class _OperationsPanel extends StatefulWidget {
  final FactionTheme theme;
  final AnimationController breathing;
  final Function(_NotificationBanner) onNotify;
  final Function(_NotificationBannerType) onClearNotification;
  final void Function(NavSection section, {int? breedInitialTab})
  onRequestNavigate;

  const _OperationsPanel({
    required this.theme,
    required this.breathing,
    required this.onNotify,
    required this.onClearNotification,
    required this.onRequestNavigate,
  });

  @override
  State<_OperationsPanel> createState() => _OperationsPanelState();
}

class _OperationsPanelState extends State<_OperationsPanel>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<double> _ease = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
    HapticFeedback.selectionClick();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _checkNotifications(
    int readyEggs,
    int readyHarvest,
    BuildContext context,
  ) {
    if (readyEggs > 0) {
      widget.onNotify(
        _NotificationBanner(
          type: _NotificationBannerType.eggReady,
          title: 'EGGS READY',
          subtitle: 'Tap to hatch',
          count: readyEggs,
          onTap: () {
            widget.onRequestNavigate(
              NavSection.breed,
              breedInitialTab: 1, // go straight to Incubation tab
            );
          },
        ),
      );
    } else {
      widget.onClearNotification(_NotificationBannerType.eggReady);
    }

    if (readyHarvest > 0) {
      widget.onNotify(
        _NotificationBanner(
          type: _NotificationBannerType.harvestReady,
          title: 'HARVEST READY',
          subtitle: 'Collect resources',
          count: readyHarvest,
          onTap: () {
            // You have choices here.
            // OPTION A: keep modal for harvest (if harvest is not in bottom nav)
            // Navigator.of(context).push(...)

            // OPTION B: if Harvest actually maps to a nav section,
            // call widget.onRequestNavigate(<that section>);
            //
            // I'll leave OPTION A for now, but you can swap the same pattern.
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => const BiomeHarvestScreen(),
                fullscreenDialog: true,
              ),
            );
          },
        ),
      );
    } else {
      widget.onClearNotification(_NotificationBannerType.harvestReady);
    }
  }

  @override
  Widget build(BuildContext context) {
    final harvestSvc = context.watch<HarvestService>();
    final t = widget.theme;
    final floatY = -2 * math.sin(widget.breathing.value * math.pi);

    return StreamBuilder<List<IncubatorSlot>>(
      stream: context.read<AlchemonsDatabase>().watchSlots(),
      builder: (context, snap) {
        final slots = snap.data ?? const <IncubatorSlot>[];
        final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

        // ----- Incubator Stats -----
        final unlocked = slots.where((s) => s.unlocked).toList();
        final withEgg = unlocked.where((s) => s.eggId != null).toList();
        final readyInc = withEgg
            .where((s) => s.hatchAtUtcMs != null && nowMs >= s.hatchAtUtcMs!)
            .length;
        final activeInc = (withEgg.length - readyInc).clamp(0, 999);
        final openInc = (unlocked.length - withEgg.length).clamp(0, 999);

        // ----- Harvest Stats -----
        final biomes = harvestSvc.biomes.where((b) => b.unlocked).toList();
        final unlockedCount = biomes.length;

        final readyHarvest = biomes.where((b) {
          final j = b.activeJob;
          if (j == null) return false;
          final endMs = j.startUtcMs + j.durationMs;
          return nowMs >= endMs;
        }).length;

        final activeHarvest = biomes.where((b) {
          final j = b.activeJob;
          if (j == null) return false;
          final endMs = j.startUtcMs + j.durationMs;
          return nowMs < endMs;
        }).length;

        final openBiomes = (unlockedCount - (readyHarvest + activeHarvest))
            .clamp(0, 999);

        final totalReady = readyInc + readyHarvest;

        // Notifications
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkNotifications(readyInc, readyHarvest, context);
        });

        return Transform.translate(
          offset: Offset(0, floatY),
          child: GestureDetector(
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(14),
              decoration: t.chipDecoration(rim: t.accent),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Icon(Icons.science_rounded, color: t.text, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'OPERATIONS',
                        style: TextStyle(
                          color: t.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Spacer(),
                      if (totalReady > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: t.accent,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '$totalReady',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      RotationTransition(
                        turns: Tween<double>(begin: 0, end: 0.5).animate(_ease),
                        child: Icon(
                          Icons.expand_more_rounded,
                          color: t.textMuted,
                          size: 20,
                        ),
                      ),
                    ],
                  ),

                  // Compact stats row when collapsed
                  if (!_expanded) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _CompactStat(
                          icon: Icons.egg_rounded,
                          ready: readyInc,
                          active: activeInc,
                          theme: t,
                        ),
                        const SizedBox(width: 12),
                        _CompactStat(
                          icon: Icons.agriculture_rounded,
                          ready: readyHarvest,
                          active: activeHarvest,
                          theme: t,
                        ),
                      ],
                    ),
                  ],

                  // Expanded details
                  SizeTransition(
                    sizeFactor: _ease,
                    axisAlignment: -1,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _OperationSection(
                            icon: Icons.egg_rounded,
                            title: 'INCUBATION',
                            ready: readyInc,
                            active: activeInc,
                            open: openInc,
                            theme: t,
                            onOpen: () {
                              widget.onRequestNavigate(
                                NavSection.breed,
                                breedInitialTab: 1,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _OperationSection(
                            icon: Icons.agriculture_rounded,
                            title: 'HARVEST',
                            ready: readyHarvest,
                            active: activeHarvest,
                            open: openBiomes,
                            theme: t,
                            onOpen: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => const BiomeHarvestScreen(),
                                  fullscreenDialog: true,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// Compact stat display (collapsed state)
// ============================================================================

class _CompactStat extends StatelessWidget {
  final IconData icon;
  final int ready;
  final int active;
  final FactionTheme theme;

  const _CompactStat({
    required this.icon,
    required this.ready,
    required this.active,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: theme.textMuted, size: 16),
          const SizedBox(width: 6),
          if (ready > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.accent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$ready',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            active > 0 ? '$active active' : 'idle',
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Expanded operation section
// ============================================================================

class _OperationSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final int ready;
  final int active;
  final int open;
  final FactionTheme theme;
  final VoidCallback onOpen;

  const _OperationSection({
    required this.icon,
    required this.title,
    required this.ready,
    required this.active,
    required this.open,
    required this.theme,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ready > 0
              ? theme.accent.withOpacity(0.4)
              : theme.textMuted.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.text, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (ready > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: theme.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$ready READY',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatChip(label: 'Active', value: active, theme: theme),
              const SizedBox(width: 8),
              _StatChip(label: 'Available', value: open, theme: theme),
              const Spacer(),
              GestureDetector(
                onTap: onOpen,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.accentSoft,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'OPEN',
                        style: TextStyle(
                          color: theme.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: theme.text,
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final FactionTheme theme;

  const _StatChip({
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(
              color: theme.text,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
