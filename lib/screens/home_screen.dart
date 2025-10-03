// lib/screens/home_screen.dart
import 'dart:ui';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/screens/creatures_screen.dart';
import 'package:alchemons/screens/faction_picker.dart';
import 'package:alchemons/screens/feeding_screen.dart';
import 'package:alchemons/screens/field_screen.dart';
import 'package:alchemons/screens/harvest_screen.dart';
import 'package:alchemons/screens/map_screen.dart';
import 'package:alchemons/screens/profile_screen.dart';
import 'package:alchemons/screens/shop_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/harvest_service.dart';
import 'package:alchemons/test/dev_seeder.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/router/push_soft.dart';
import 'package:alchemons/widgets/background/interactive_background_widget.dart';
import 'package:alchemons/widgets/blob_party/overlays/floating_bubble_overlay.dart';
import 'package:alchemons/widgets/element_resource_widget.dart';
import 'package:alchemons/widgets/kpi/kpi_chip_widget.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_providers.dart';
import 'breed/breed_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _rotationController;
  late AnimationController _particleController;
  late AnimationController _waveController;
  late AnimationController _glowController;

  bool _isInitialized = false;

  Color get _softTextOnDark => Colors.white70;

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
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

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
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      await _initializeRepository();

      final factionSvc = context.read<FactionService>();
      final picked = await factionSvc.loadId();

      if (!mounted) return;

      if (picked == null) {
        final selected = await showDialog<FactionId>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const FactionPickerDialog(),
        );
        if (selected != null) {
          await factionSvc.setId(selected);
          if (!mounted) return;
        }
        await factionSvc.ensureAirExtraSlotUnlocked();
      }

      setState(() {
        _isInitialized = true;
      });
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

  @override
  Widget build(BuildContext context) {
    return Consumer2<GameStateNotifier, CatalogData?>(
      builder: (context, gameState, catalogData, child) {
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

        final factionSvc = context.read<FactionService>();
        factionSvc.setBlobSlotsUnlockedTest(); // DEV TEST

        final currentFaction = factionSvc.current;
        final (primary, secondary, accent) = getFactionColors(currentFaction);
        final speeds = _speedFor(currentFaction!);

        return Scaffold(
          body: Stack(
            children: [
              InteractiveBackground(
                particleController: _particleController,
                rotationController: _rotationController,
                waveController: _waveController,
                primaryColor: primary,
                secondaryColor: secondary,
                accentColor: accent,
                factionType: currentFaction,
                particleSpeed: speeds.particle,
                rotationSpeed: speeds.rotation,
                elementalSpeed: speeds.elemental,
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildEnhancedHeader(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            _buildNavigationBubbles(),
                            const SizedBox(height: 20),
                            _buildStatsHUD(gameState),
                            const SizedBox(height: 20),
                            ResourceCollectionWidget(accentColor: accent),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              FloatingBubblesOverlay(
                regionPadding: const EdgeInsets.fromLTRB(12, 140, 12, 140),
                discoveredCreatures:
                    gameState.discoveredCreatures, // 👈 add this
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingScreen(String message) {
    return Scaffold(
      body: Stack(
        children: [
          // Dark gradient veil so the background isn't blinding
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC0B0F14), Color(0x990B0F14)],
                ),
              ),
            ),
          ),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: _glass(
                    tint: Colors.black,
                    stroke: Colors.cyanAccent,
                    opacity: 0.18,
                  ),
                  width: 260,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: const AlwaysStoppedAnimation(
                            Colors.cyanAccent,
                          ),
                          backgroundColor: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _softTextOnDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(String error, VoidCallback onRetry) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC140B0B), Color(0x99140B0B)],
                ),
              ),
            ),
          ),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  width: 300,
                  decoration: _glass(
                    tint: Colors.black,
                    stroke: Colors.redAccent,
                    opacity: 0.16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.redAccent,
                        size: 34,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'System Error',
                        style: TextStyle(
                          color: _softTextOnDark,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error,
                        style: TextStyle(color: _mutedTextOnDark, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: onRetry,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.6),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.refresh,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Retry',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedHeader() {
    final f = context.read<FactionService>().current ?? FactionId.water;
    final accent = accentForFaction(f);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, _) {
          return Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withOpacity(0.6)),
                  ),
                  child: Icon(Icons.person_rounded, color: accent, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              // Title & subtitle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ALCHEMONS',
                    style: TextStyle(
                      color: _softTextOnDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 40,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'Research Facility',
                    style: TextStyle(
                      color: _mutedTextOnDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsHUD(GameStateNotifier gameState) {
    final f = context.read<FactionService>().current ?? FactionId.water;
    final accent = accentForFaction(f);

    final total = gameState.creatures.length;
    final discovered = gameState.discoveredCreatures.length;

    final completion = (total == 0)
        ? 0.0
        : (discovered / total).clamp(0.0, 1.0);

    // a subtle animated value so the ring gently “breathes”
    final breathe = _breathingController.value; // 0..1
    final shimmer = 0.85 + math.sin(breathe * math.pi) * 0.15; // 0.7..1.0

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedBuilder(
          animation: Listenable.merge([_glowController, _breathingController]),
          builder: (context, _) {
            return _PulsingBorder(
              anim: _glowController,
              color: accent,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: _glass(
                  tint: Colors.black,
                  stroke: accent,
                  opacity: 0.14,
                ),
                child: Row(
                  children: [
                    // Progress ring
                    SizedBox(
                      width: 86,
                      height: 86,
                      child: CustomPaint(
                        painter: _ProgressArcPainter(
                          progress: completion,
                          accent: accent,
                          glow: shimmer,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(completion * 100).round()}%',
                                style: TextStyle(
                                  color: _softTextOnDark,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Database',
                                style: TextStyle(
                                  color: _mutedTextOnDark,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // KPI stack
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _KpiRow(
                            label: 'Discovered',
                            value: '$discovered / $total',
                            accent: accent,
                          ),
                          const SizedBox(height: 8),
                          _BarMeter(
                            value: completion,
                            accent: accent,
                            labelLeft: '0%',
                            labelRight: '100%',
                          ),
                          const SizedBox(height: 12),

                          // KPIs: Incubating + Harvest (new KpiChip)
                          Builder(
                            builder: (context) {
                              final harvestSvc = context
                                  .watch<HarvestService>();

                              return StreamBuilder<List<IncubatorSlot>>(
                                stream: context
                                    .read<AlchemonsDatabase>()
                                    .watchSlots(),
                                builder: (context, snap) {
                                  final slots =
                                      snap.data ?? const <IncubatorSlot>[];
                                  final nowMs = DateTime.now()
                                      .toUtc()
                                      .millisecondsSinceEpoch;

                                  // ----- Incubator stats -----
                                  final unlockedSlots = slots
                                      .where((s) => s.unlocked)
                                      .toList();
                                  final totalUnlockedInc = unlockedSlots.length;

                                  final withEgg = unlockedSlots
                                      .where((s) => s.eggId != null)
                                      .toList();

                                  final readyIncubating = withEgg.where((s) {
                                    return s.hatchAtUtcMs != null &&
                                        nowMs >= s.hatchAtUtcMs!;
                                  }).length;

                                  final activeIncubating =
                                      (withEgg.length - readyIncubating).clamp(
                                        0,
                                        999,
                                      );

                                  final openInc =
                                      (totalUnlockedInc - withEgg.length).clamp(
                                        0,
                                        999,
                                      );

                                  // ✅ AVAILABLE = OPEN + READY

                                  // 👇 STATUS-ONLY STRINGS (what you asked for)
                                  final statusIncubating = (readyIncubating > 0)
                                      ? 'READY'
                                      : (totalUnlockedInc > 0 &&
                                            openInc == totalUnlockedInc)
                                      ? 'ALL AVAILABLE'
                                      : 'INCUBATING';

                                  // ----- Harvest stats (exclude locked farms for counts) -----
                                  final farms = harvestSvc.farms
                                      .where((f) => f.unlocked)
                                      .toList();
                                  final totalUnlockedFarms = farms.length;
                                  final activeHarvestTotal = farms
                                      .where((f) => f.active != null)
                                      .length;

                                  final readyHarvest = farms.where((f) {
                                    final j = f.active;
                                    if (j == null) return false;
                                    final endMs = j.startUtcMs + j.durationMs;
                                    return nowMs >= endMs;
                                  }).length;

                                  final activeHarvest =
                                      (activeHarvestTotal - readyHarvest).clamp(
                                        0,
                                        999,
                                      );

                                  final openFarms =
                                      (totalUnlockedFarms - activeHarvestTotal)
                                          .clamp(0, 999);

                                  final statusHarvest = (readyHarvest > 0)
                                      ? 'COLLECT'
                                      : (openFarms > 0)
                                      ? 'OPEN'
                                      : (activeHarvest > 0)
                                      ? 'EXTRACTING'
                                      : 'IDLE';

                                  final incubatorLines =
                                      _sentencesForIncubators(
                                        ready: readyIncubating,
                                        open: openInc,
                                        active: activeIncubating,
                                      );

                                  final harvestLines = _sentencesForHarvest(
                                    ready: readyHarvest,
                                    open: openFarms,
                                    active: activeHarvest,
                                  );

                                  return Row(
                                    children: [
                                      Expanded(
                                        child: KpiChip(
                                          heroTag: 'kpi-incubating',
                                          icon: Icons.egg_rounded,
                                          label: 'Incubating',
                                          // ✅ STATUS ONLY
                                          compactValue: statusIncubating,
                                          readyCount:
                                              readyIncubating, // blink only if READY
                                          accent: accentForFaction(
                                            context
                                                    .read<FactionService>()
                                                    .current ??
                                                FactionId.water,
                                          ),
                                          details: incubatorLines,
                                          breathe: _breathingController.value,
                                          onOpen: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const BreedScreen(
                                                      initialTab: 1,
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),

                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: KpiChip(
                                          heroTag: 'kpi-harvest',
                                          icon: Icons.agriculture_rounded,
                                          label: 'Harvest',
                                          compactValue:
                                              statusHarvest, // status ONLY ("COLLECT"/"OPEN"/"EXTRACTING"/"IDLE")
                                          readyCount: readyHarvest,
                                          accent: accentForFaction(
                                            context
                                                    .read<FactionService>()
                                                    .current ??
                                                FactionId.water,
                                          ),
                                          details: harvestLines,
                                          breathe: _breathingController.value,
                                          onOpen: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const HarvestScreen(),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavigationBubbles() {
    final f = context.read<FactionService>().current ?? FactionId.water;
    final accent = accentForFaction(f);

    final items = <({String title, IconData icon, VoidCallback onTap})>[
      (
        title: 'Database',
        icon: Icons.storage_rounded,
        onTap: () {
          HapticFeedback.lightImpact();
          context.pushSoft(const CreaturesScreen());
        },
      ),
      (
        title: 'Breed',
        icon: Icons.merge_type_rounded,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BreedScreen()),
          );
        },
      ),
      (
        title: 'Enhance',
        icon: Icons.science_outlined,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FeedingScreen()),
          );
        },
      ),
      (
        title: 'Field',
        icon: Icons.explore_rounded,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FieldScreen()),
          );
        },
      ),
      (
        title: 'Shop',
        icon: Icons.shopping_bag_rounded,
        onTap: () {
          HapticFeedback.lightImpact();
          context.pushSoft(const ShopScreen());
        },
      ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedBuilder(
          animation: Listenable.merge([_glowController, _breathingController]),
          builder: (context, _) {
            final pulse = 0.35 + _glowController.value * 0.4;
            return _PulsingBorder(
              anim: _glowController,
              color: accent,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: _glass(
                  tint: Colors.black,
                  stroke: accent,
                  opacity: 0.14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final it in items)
                      _DockButton(
                        icon: it.icon,
                        label: it.title,
                        accent: accent,
                        pulse: pulse,
                        onTap: it.onTap,
                        breathe: _breathingController.value,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _cardinal(int n) => n == 1 ? 'One' : n.toString();
  String _isAre(int n) => n == 1 ? 'is' : 'are';
  String _plural(int n, String singular, String plural) =>
      n == 1 ? singular : plural;

  /// More “scientific” phrasing for incubators.
  /// - “ready” and “active” are mutually exclusive (already enforced above).
  List<String> _sentencesForIncubators({
    required int ready,
    required int open,
    required int active,
  }) {
    final lines = <String>[];
    if (ready > 0) {
      lines.add(
        '${_cardinal(ready)} ${_plural(ready, "incubator", "incubators")} ready for extraction.',
      );
    }
    if (active > 0) {
      lines.add(
        '${_cardinal(active)} ${_plural(active, "incubator", "incubators")} ${_isAre(active)} under active incubation.',
      );
    }
    if (open > 0) {
      lines.add('${_cardinal(open)} ${_isAre(open)} available.');
    }
    if (lines.isEmpty) lines.add('All incubators are idle.');
    return lines;
  }

  /// Scientific phrasing for harvest sites (no “unlocked” line).
  List<String> _sentencesForHarvest({
    required int ready,
    required int open,
    required int active,
  }) {
    final lines = <String>[];
    if (ready > 0) {
      lines.add(
        '${_cardinal(ready)} ${_plural(ready, "site", "sites")} ready for collection.',
      );
    }
    if (active > 0) {
      lines.add(
        '${_cardinal(active)} ${_plural(active, "site", "sites")} ${_isAre(active)} harvesting in progress.',
      );
    }
    if (open > 0) {
      lines.add(
        '${_cardinal(open)} idle ${_plural(open, "site", "sites")} available.',
      );
    }
    if (lines.isEmpty) lines.add('No active harvesting detected.');
    return lines;
  }
}

class _KpiRow extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _KpiRow({
    required this.label,
    required this.value,
    required this.accent,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: _mutedTextOnDark,
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withOpacity(0.6)),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: _softTextOnDark,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _BarMeter extends StatelessWidget {
  final double value; // 0..1
  final Color accent;
  final String labelLeft;
  final String labelRight;
  const _BarMeter({
    required this.value,
    required this.accent,
    required this.labelLeft,
    required this.labelRight,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Compute pixel width; ensure a tiny visible sliver if v>0
                double w = constraints.maxWidth * v;
                if (v > 0 && w < 2) w = 2;

                return Stack(
                  children: [
                    // Background track
                    Positioned.fill(
                      child: Container(color: Colors.white.withOpacity(0.06)),
                    ),
                    // Filled segment, anchored left
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: w,
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [accent.withOpacity(0.18), accent],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              labelLeft,
              style: TextStyle(
                color: _mutedTextOnDark,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              labelRight,
              style: TextStyle(
                color: _mutedTextOnDark,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Circular progress arc with soft glow
class _ProgressArcPainter extends CustomPainter {
  final double progress; // 0..1
  final Color accent;
  final double glow; // ~0.7..1.0
  _ProgressArcPainter({
    required this.progress,
    required this.accent,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide / 2) - 4;

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8
      ..color = Colors.white.withOpacity(0.08);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2,
      false,
      bg,
    );

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + math.pi * 2,
        colors: [accent.withOpacity(0.25), accent, accent.withOpacity(0.9)],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final sweep = (progress.clamp(0.0, 1.0)) * math.pi * 2;
    // glow pass
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..color = accent.withOpacity(0.4 * glow);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      glowPaint,
    );

    // main arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.glow != glow;
  }
}

class _DockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final double pulse; // 0..1 shimmer
  final double breathe; // 0..1 float
  final VoidCallback onTap;

  const _DockButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.pulse,
    required this.breathe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final floatY = -2 * math.sin(breathe * math.pi);
    return Transform.translate(
      offset: Offset(0, floatY),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
                border: Border.all(
                  color: accent.withOpacity(0.6 + pulse * 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.20 + pulse * 0.15),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Icon(icon, color: _softTextOnDark, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: _mutedTextOnDark,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painters
class LoadingParticlePainter extends CustomPainter {
  final double animation;

  LoadingParticlePainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.indigo.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 20; i++) {
      final x = (size.width / 20 * i + animation * 100) % size.width;
      final y =
          (size.height / 20 * i + math.sin(animation * 2 * math.pi + i) * 80) %
          size.height;
      final radius = 4 + math.sin(animation * 2 * math.pi + i) * 2;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(LoadingParticlePainter oldDelegate) => true;
}

Color _softTextOnDark = const Color(0xFFE8EAED); // warm white
Color _mutedTextOnDark = const Color(0xFFB6C0CC);

BoxDecoration _glass({
  required Color tint,
  required Color stroke,
  double opacity = 0.10,
}) {
  return BoxDecoration(
    color: tint.withOpacity(opacity),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: stroke.withOpacity(0.35), width: 1),
    boxShadow: [
      BoxShadow(
        color: stroke.withOpacity(0.18),
        blurRadius: 18,
        spreadRadius: 1,
      ),
    ],
  );
}

/// A thin animated border “energy” ring
class _PulsingBorder extends StatelessWidget {
  final Animation<double> anim;
  final BorderRadius borderRadius;
  final Color color;
  final Widget child;
  const _PulsingBorder({
    required this.anim,
    required this.borderRadius,
    required this.color,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    final glow = 0.35 + anim.value * 0.4; // 0.35..0.75
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(glow * 0.4),
            blurRadius: 20 + anim.value * 14,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: color.withOpacity(glow), width: 1),
        ),
        child: child,
      ),
    );
  }
}
