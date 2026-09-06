import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/constants/unlock_costs.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/biome_farm_state.dart';
import 'package:alchemons/models/harvest_biome.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/harvest_service.dart';
import 'package:alchemons/services/push_notification_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/game_data_gate.dart';
import 'package:alchemons/utils/harvest_rate.dart';
import 'package:alchemons/widgets/all_specimens_page.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/floating_close_button_widget.dart';
import 'package:alchemons/widgets/fx/alchemy_tap_fx.dart';
import 'package:alchemons/widgets/loading_widget.dart';
import 'package:alchemons/widgets/tutorial_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';

// ---------------------------------------------------------------------------
// ExtractionHubScreen
// All 5 animated extraction chambers on one scrollable screen.
// Replaces both BiomeHarvestScreen and BiomeDetailScreen.
// ---------------------------------------------------------------------------

TextStyle _display(
  BuildContext context,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w500,
  double letterSpacing = 0,
  FontStyle fontStyle = FontStyle.normal,
}) {
  final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
  return base.copyWith(
    color: color,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
  );
}

class _BracketFramePainter extends CustomPainter {
  const _BracketFramePainter({
    required this.color,
    this.bracketSize = 10,
    this.strokeWidth = 1,
  });

  final Color color;
  final double bracketSize;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final s = bracketSize;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, s)
      ..lineTo(0, 0)
      ..lineTo(s, 0)
      ..moveTo(w - s, 0)
      ..lineTo(w, 0)
      ..lineTo(w, s)
      ..moveTo(0, h - s)
      ..lineTo(0, h)
      ..lineTo(s, h)
      ..moveTo(w - s, h)
      ..lineTo(w, h)
      ..lineTo(w, h - s);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BracketFramePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.bracketSize != bracketSize ||
      oldDelegate.strokeWidth != strokeWidth;
}

class ExtractionHubScreen extends StatefulWidget {
  const ExtractionHubScreen({super.key, this.service});

  final HarvestService? service;

  @override
  State<ExtractionHubScreen> createState() => _ExtractionHubScreenState();
}

class _ExtractionHubScreenState extends State<ExtractionHubScreen>
    with TickerProviderStateMixin {
  late HarvestService _svc;
  bool _tutorialChecked = false;
  String? _selectedBiomeId;

  @override
  void initState() {
    super.initState();
    _svc = widget.service ?? context.read<HarvestService>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  Future<void> _maybeShowTutorial() async {
    if (_tutorialChecked || !mounted) return;
    _tutorialChecked = true;
    final db = context.read<AlchemonsDatabase>();
    final hasSeen = await db.settingsDao.hasSeenBiomeHarvestTutorial();
    if (hasSeen || !mounted) return;
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: t.bg1,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: t.borderAccent, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.isDark ? 0.42 : 0.08,
                ),
                blurRadius: theme.isDark ? 24 : 16,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 26,
                    decoration: BoxDecoration(
                      color: t.amber,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    AppIcons.science_rounded,
                    color: t.amberBright,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'BIOME EXTRACTORS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: t.borderMid),
              const SizedBox(height: 12),
              Text(
                'Use biome extractors to slowly generate elemental resources over time.',
                style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              TutorialStep(
                theme: theme,
                icon: AppIcons.terrain_rounded,
                title: 'Step 1 – Pick a biome',
                body:
                    'Each biome specialises in certain elements. Some start '
                    'locked and require resources to unlock.',
              ),
              const SizedBox(height: 6),
              TutorialStep(
                theme: theme,
                icon: AppIcons.science_outlined,
                title: 'Step 2 – Insert an Alchemon',
                body:
                    'Tap a chamber and insert an Alchemon to start '
                    'extraction. Tap the orb to speed it up.',
              ),
              const SizedBox(height: 6),
              TutorialStep(
                theme: theme,
                icon: AppIcons.inventory_2_rounded,
                title: 'Step 3 – Collect your rewards',
                body:
                    'When complete, collect from each chamber individually '
                    'or tap Collect All at the top.',
              ),
              const SizedBox(height: 10),
              Text(
                'Higher-level Alchemons generate more resources.',
                style: TextStyle(
                  color: t.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          t.amberDim.withValues(alpha: 0.45),
                          t.amber.withValues(alpha: 0.28),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: t.amber.withValues(alpha: 0.7)),
                    ),
                    child: Text(
                      'GOT IT',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: t.amberBright,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
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
    if (mounted) await db.settingsDao.setBiomeHarvestTutorialSeen();
  }

  Future<void> _promptUnlock(BiomeFarmState farm) async {
    final costDb = UnlockCosts.biome(farm.biome);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _UnlockDialog(biome: farm.biome, costDb: costDb),
    );
    if (confirmed != true || !mounted) return;
    final ok = await _svc.unlock(farm.biome, cost: costDb);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Unlocked ${farm.biome.label}!' : 'Not enough resources',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  Future<void> _collectAll(List<BiomeFarmState> farms) async {
    HapticFeedback.mediumImpact();
    final completed = farms.where((f) => f.completed).toList();
    int total = 0;
    for (final farm in completed) {
      total += await _svc.collect(farm.biome);
    }
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Collected $total resources from ${completed.length} chamber${completed.length == 1 ? '' : 's'}',
        ),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ForcedFactionBrightness(
      brightness: Brightness.dark,
      child: Builder(
        builder: (context) {
          final theme = context.watch<FactionTheme>();
          final t = ForgeTokens(theme);
          return Scaffold(
            extendBody: true,
            backgroundColor: t.bg0,
            body: withGameData(
              context,
              loadingBuilder: buildLoadingScreen,
              builder:
                  (
                    context, {
                    required theme,
                    required catalog,
                    required entries,
                    required discovered,
                  }) {
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [t.bg0, t.bg1, t.bg0],
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: const Alignment(0, -0.7),
                                  radius: 1.15,
                                  colors: [
                                    t.amber.withValues(alpha: 0.12),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Positioned.fill(
                          child: AlchemicalParticleBackground(),
                        ),
                        SafeArea(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  4,
                                  18,
                                  4,
                                ),
                                child: Text(
                                  'Harvest',
                                  textAlign: TextAlign.center,
                                  style: _display(
                                    context,
                                    22,
                                    t.textPrimary,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ListenableBuilder(
                                  listenable: _svc,
                                  builder: (_, __) {
                                    final farms = _svc.biomes;
                                    final completedCount = farms
                                        .where((f) => f.completed)
                                        .length;
                                    return Column(
                                      children: [
                                        if (completedCount > 0)
                                          _CollectAllBanner(
                                            count: completedCount,
                                            theme: theme,
                                            onCollectAll: () =>
                                                _collectAll(farms),
                                          ),
                                        Expanded(
                                          child: _ExtractionBay(
                                            farms: farms,
                                            theme: theme,
                                            service: _svc,
                                            discoveredCreatures: discovered,
                                            selectedBiomeId: _selectedBiomeId,
                                            defaultDuration: const Duration(
                                              hours: 4,
                                            ),
                                            onSelect: (farm) {
                                              HapticFeedback.selectionClick();
                                              setState(
                                                () => _selectedBiomeId =
                                                    farm.biome.id,
                                              );
                                            },
                                            onUnlock: _promptUnlock,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 40,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: FloatingCloseButton(
                              theme: theme,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.of(context).maybePop();
                              },
                              accentColor: t.textPrimary,
                              iconColor: t.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ExtractionBay
// ---------------------------------------------------------------------------

class _ExtractionBay extends StatelessWidget {
  const _ExtractionBay({
    required this.farms,
    required this.theme,
    required this.service,
    required this.discoveredCreatures,
    required this.selectedBiomeId,
    required this.defaultDuration,
    required this.onSelect,
    required this.onUnlock,
  });

  final List<BiomeFarmState> farms;
  final FactionTheme theme;
  final HarvestService service;
  final List<CreatureEntry> discoveredCreatures;
  final String? selectedBiomeId;
  final Duration defaultDuration;
  final ValueChanged<BiomeFarmState> onSelect;
  final ValueChanged<BiomeFarmState> onUnlock;

  BiomeFarmState _selectedFarm() {
    if (farms.isEmpty) {
      throw StateError('Extraction bay requires at least one biome.');
    }
    for (final farm in farms) {
      if (farm.biome.id == selectedBiomeId) return farm;
    }
    final ready = farms.where((farm) => farm.completed);
    if (ready.isNotEmpty) return ready.first;
    final active = farms.where((farm) => farm.hasActive);
    if (active.isNotEmpty) return active.first;
    return farms.first;
  }

  @override
  Widget build(BuildContext context) {
    if (farms.isEmpty) return const SizedBox.shrink();
    final selected = _selectedFarm();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final bottomPad = wide ? 26.0 : 104.0;
        final rail = _BiomeSelectorRail(
          farms: farms,
          selectedBiomeId: selected.biome.id,
          theme: theme,
          vertical: wide,
          onSelect: onSelect,
        );
        final chamber = _EmbeddedChamber(
          key: ValueKey('bay-${selected.biome.id}'),
          farm: selected,
          theme: theme,
          service: service,
          discoveredCreatures: discoveredCreatures,
          defaultDuration: defaultDuration,
          featured: true,
          onUnlock: () => onUnlock(selected),
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(8, 4, 8, bottomPad),
          child: wide
              ? Row(
                  children: [
                    SizedBox(width: 154, child: rail),
                    const SizedBox(width: 10),
                    Expanded(child: chamber),
                  ],
                )
              : Column(
                  children: [
                    SizedBox(height: 78, child: rail),
                    const SizedBox(height: 10),
                    Expanded(child: chamber),
                  ],
                ),
        );
      },
    );
  }
}

class _BiomeSelectorRail extends StatelessWidget {
  const _BiomeSelectorRail({
    required this.farms,
    required this.selectedBiomeId,
    required this.theme,
    required this.vertical,
    required this.onSelect,
  });

  final List<BiomeFarmState> farms;
  final String selectedBiomeId;
  final FactionTheme theme;
  final bool vertical;
  final ValueChanged<BiomeFarmState> onSelect;

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: farms.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final farm = farms[index];
          return _BiomeSelectorChip(
            farm: farm,
            theme: theme,
            selected: farm.biome.id == selectedBiomeId,
            vertical: true,
            onTap: () => onSelect(farm),
          );
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      scrollDirection: Axis.horizontal,
      itemCount: farms.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, index) {
        final farm = farms[index];
        return SizedBox(
          width: 106,
          child: _BiomeSelectorChip(
            farm: farm,
            theme: theme,
            selected: farm.biome.id == selectedBiomeId,
            vertical: false,
            onTap: () => onSelect(farm),
          ),
        );
      },
    );
  }
}

class _BiomeSelectorChip extends StatelessWidget {
  const _BiomeSelectorChip({
    required this.farm,
    required this.theme,
    required this.selected,
    required this.vertical,
    required this.onTap,
  });

  final BiomeFarmState farm;
  final FactionTheme theme;
  final bool selected;
  final bool vertical;
  final VoidCallback onTap;

  double get _progress {
    final job = farm.activeJob;
    if (job == null || job.durationMs <= 0) return 0;
    if (farm.completed) return 1;
    final remaining = farm.remaining;
    if (remaining == null) return 0;
    return (1.0 - remaining.inMilliseconds / job.durationMs).clamp(0.0, 1.0);
  }

  String get _status {
    if (!farm.unlocked) return 'Locked';
    if (farm.completed) return 'Ready';
    if (farm.hasActive) return '${(_progress * 100).clamp(0, 99).floor()}%';
    return 'Open';
  }

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    final accent = farm.currentColor;
    final lineColor = selected
        ? accent
        : farm.completed
        ? t.success
        : t.borderDim;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(
          vertical ? 10 : 8,
          vertical ? 9 : 8,
          vertical ? 8 : 8,
          vertical ? 9 : 7,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: vertical
              ? Border(
                  left: BorderSide(
                    color: lineColor.withValues(alpha: selected ? 0.95 : 0.42),
                    width: selected ? 3 : 1,
                  ),
                )
              : Border(
                  bottom: BorderSide(
                    color: lineColor.withValues(alpha: selected ? 0.95 : 0.42),
                    width: selected ? 3 : 1,
                  ),
                ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.16),
                    border: Border.all(color: accent.withValues(alpha: 0.8)),
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: selected ? 8 : 5,
                      height: selected ? 8 : 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: farm.completed ? t.success : accent,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                if (farm.completed)
                  Icon(AppIcons.check_rounded, color: t.success, size: 16)
                else if (!farm.unlocked)
                  Icon(
                    AppIcons.lock_outline_rounded,
                    color: t.textMuted,
                    size: 15,
                  )
                else if (farm.hasActive)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 2,
                      color: accent,
                      backgroundColor: t.borderDim,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              farm.biome.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _display(
                context,
                vertical ? 13 : 12,
                t.textPrimary,
                weight: selected ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _display(
                context,
                10,
                farm.completed ? t.success : t.textSecondary,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CollectAllBanner
// ---------------------------------------------------------------------------

class _CollectAllBanner extends StatelessWidget {
  const _CollectAllBanner({
    required this.count,
    required this.theme,
    required this.onCollectAll,
  });
  final int count;
  final FactionTheme theme;
  final VoidCallback onCollectAll;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    final readyColor = t.success;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: CustomPaint(
        painter: _BracketFramePainter(
          color: readyColor.withValues(alpha: theme.isDark ? 0.55 : 0.35),
          bracketSize: 10,
          strokeWidth: 1.05,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: t.bg2.withValues(alpha: 0.96),
          child: Row(
            children: [
              Icon(
                AppIcons.check_circle_outline_rounded,
                color: readyColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$count chamber${count == 1 ? '' : 's'} ready to collect',
                  style: _display(
                    context,
                    12.5,
                    t.textPrimary,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              _OutlineBtn(
                label: 'Collect all',
                accent: readyColor,
                theme: theme,
                compact: true,
                minHeight: 38,
                onTap: onCollectAll,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EmbeddedChamber — full animated orb + all logic, no separate screen needed
// ---------------------------------------------------------------------------

class _EmbeddedChamber extends StatefulWidget {
  const _EmbeddedChamber({
    super.key,
    required this.farm,
    required this.theme,
    required this.service,
    required this.discoveredCreatures,
    required this.defaultDuration,
    required this.onUnlock,
    this.featured = false,
  });

  final BiomeFarmState farm;
  final FactionTheme theme;
  final HarvestService service;
  final List<CreatureEntry> discoveredCreatures;
  final Duration defaultDuration;
  final VoidCallback onUnlock;
  final bool featured;

  @override
  State<_EmbeddedChamber> createState() => _EmbeddedChamberState();
}

class _EmbeddedChamberState extends State<_EmbeddedChamber>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  double _tSeconds = 0.0;
  DateTime? _lastTapBoostAt;

  late final AnimationController _tapFxCtrl;
  Offset? _tapLocal;
  late final AnimationController _collectCtrl;
  late final AnimationController _jobCtrl;
  late final AnimationController _statusCtrl;

  Widget? _creatureWidget;
  String? _cachedInstanceId;

  @override
  void initState() {
    super.initState();
    _collectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _statusCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _tapFxCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _jobCtrl = AnimationController(
      vsync: this,
      lowerBound: 0,
      upperBound: 1,
      value: 0,
    );
    _ticker = createTicker((elapsed) {
      if (mounted) setState(() => _tSeconds = elapsed.inMicroseconds / 1e6);
    })..start();
    PushNotificationService().cancelHarvestSummaryNotification();
    _refreshCreatureCache();
  }

  @override
  void didUpdateWidget(covariant _EmbeddedChamber old) {
    super.didUpdateWidget(old);
    if (widget.farm.activeJob?.creatureInstanceId != _cachedInstanceId) {
      _refreshCreatureCache();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _jobCtrl.dispose();
    _collectCtrl.dispose();
    _tapFxCtrl.dispose();
    _statusCtrl.dispose();
    super.dispose();
  }

  // ── Creature cache ────────────────────────────────────────────────────────

  Future<void> _refreshCreatureCache() async {
    final job = widget.farm.activeJob;
    if (job == null) {
      _cachedInstanceId = null;
      if (mounted) {
        setState(() => _creatureWidget = null);
      }
      return;
    }
    if (_cachedInstanceId == job.creatureInstanceId &&
        _creatureWidget != null) {
      return;
    }
    _cachedInstanceId = job.creatureInstanceId;
    final db = context.read<AlchemonsDatabase>();
    final inst = await db.creatureDao.getInstance(job.creatureInstanceId);
    if (!mounted) return;
    if (inst == null) {
      setState(() => _creatureWidget = null);
      return;
    }
    final repo = context.read<CreatureCatalog>();
    final base = repo.getCreatureById(inst.baseId);
    if (base == null || base.spriteData == null) {
      setState(() => _creatureWidget = null);
      return;
    }
    setState(
      () => _creatureWidget = InstanceSprite(
        creature: base,
        instance: inst,
        size: widget.featured ? 112 : 72,
      ),
    );
  }

  // ── Progress sync ─────────────────────────────────────────────────────────

  _ProgressViewModel _syncAndComputeProgress(BiomeFarmState farm) {
    final job = farm.activeJob;
    if (job == null) {
      if (_jobCtrl.value != 0) _jobCtrl.value = 0;
      if (_jobCtrl.isAnimating) _jobCtrl.stop();
      return const _ProgressViewModel(
        progress: 0,
        effectiveFill: 0,
        remaining: null,
      );
    }
    final totalMs = job.durationMs;
    final rem = farm.remaining;
    final rawProgress = (rem == null || totalMs == 0)
        ? 0.0
        : (1.0 - rem.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final totalDur = Duration(milliseconds: totalMs);
    if (_jobCtrl.duration != totalDur) _jobCtrl.duration = totalDur;
    if (farm.completed) {
      if (_jobCtrl.value != 1.0) _jobCtrl.value = 1.0;
      if (_jobCtrl.isAnimating) _jobCtrl.stop();
    } else {
      const eps = 0.002;
      if ((_jobCtrl.value - rawProgress).abs() > eps || !_jobCtrl.isAnimating) {
        _jobCtrl.forward(from: rawProgress);
      }
    }
    final progress = _jobCtrl.value;
    final targetFill = farm.hasActive
        ? (0.0 + 0.85 * progress).clamp(0.0, 0.85)
        : 0.0;
    final curvedFill = Curves.easeOutCubic.transform(targetFill);
    final drainP = Curves.easeInOutCubic.transform(_collectCtrl.value);
    final effectiveFill = curvedFill * (1.0 - drainP);
    final Duration? remainingTime = farm.hasActive && _jobCtrl.duration != null
        ? _jobCtrl.duration! * (1 - _jobCtrl.value)
        : farm.remaining;
    return _ProgressViewModel(
      progress: progress,
      effectiveFill: effectiveFill,
      remaining: remainingTime,
    );
  }

  // ── Tap boost ─────────────────────────────────────────────────────────────

  void _handleTapBoost(BiomeFarmState farm) {
    if (!farm.hasActive || farm.completed) return;
    final now = DateTime.now();
    final lastBoost = _lastTapBoostAt;
    if (lastBoost != null &&
        now.difference(lastBoost) < HarvestService.tapBoostThrottle) {
      return;
    }
    _lastTapBoostAt = now;
    final totalMs = farm.activeJob!.durationMs;
    final boostMs = HarvestService.tapBoostStep.inMilliseconds;
    final currentMs = (1.0 - _jobCtrl.value) * totalMs;
    final newMs = (currentMs - boostMs).clamp(0, totalMs).toDouble();
    _jobCtrl.value = 1.0 - (newMs / totalMs);
    widget.service.nudge(widget.farm.biome, by: HarvestService.tapBoostStep);
  }

  // ── Start job ─────────────────────────────────────────────────────────────

  Future<void> _handlePickAndStart() async {
    final theme = widget.theme;
    final repo = context.read<CreatureCatalog>();
    final busyIds = widget.farm.activeJob != null
        ? [widget.farm.activeJob!.creatureInstanceId]
        : <String>[];
    final picked = await Navigator.of(context).push<CreatureInstance>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) => AllSpecimensPage(
          theme: theme,
          instancePrefsScopeKey: 'harvest_biome_${widget.farm.biome.id}',
          popOnSelect: true,
          searchHint: 'SELECT SPECIMEN',
          allowedPrimaryTypes: widget.farm.biome.elementTypes,
          onWillSelectInstance: (inst) async {
            if (busyIds.contains(inst.instanceId)) {
              _showToast(
                'That specimen is already extracting.',
                icon: AppIcons.block_rounded,
                color: Colors.orange.shade400,
              );
              return false;
            }

            final base = repo.getCreatureById(inst.baseId);
            if (base == null ||
                base.types.isEmpty ||
                !widget.farm.biome.elementTypes.contains(base.types.first)) {
              _showToast(
                'Only ${widget.farm.biome.label.toLowerCase()} specimens can work here.',
                icon: AppIcons.filter_alt_off_rounded,
                color: Colors.orange.shade400,
              );
              return false;
            }

            return true;
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
    if (picked == null || !mounted) return;

    final inst = picked;
    final base = repo.getCreatureById(inst.baseId);
    if (base == null || base.types.isEmpty) return;
    final creatureTypeId = base.types.first;
    await widget.service.setActiveElement(widget.farm.biome, creatureTypeId);
    final ok = await widget.service.startJob(
      biome: widget.farm.biome,
      creatureInstanceId: inst.instanceId,
      duration: widget.defaultDuration,
      ratePerMinute: computeHarvestRatePerMinute(
        inst,
        hasMatchingElement: widget.farm.biome.elementTypes.contains(
          creatureTypeId,
        ),
      ),
    );
    if (!mounted) return;
    if (ok) {
      await _collectCtrl.forward(from: 0);
      await _refreshCreatureCache();
    } else {
      _showToast(
        'Could not start extraction.',
        icon: AppIcons.error_outline,
        color: Colors.red.shade400,
      );
    }
  }

  // ── Collect ───────────────────────────────────────────────────────────────

  Future<void> _handleCollect(BiomeFarmState farm) async {
    final previousJob = farm.activeJob;
    HapticFeedback.mediumImpact();
    await _collectCtrl.forward(from: 0);
    final got = await widget.service.collect(widget.farm.biome);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Collected $got ${widget.farm.biome.resourceLabel}'),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        duration: const Duration(seconds: 2),
      ),
    );
    await _refreshCreatureCache();
    if (previousJob == null || !mounted) return;
    final constellations = context.read<ConstellationEffectsService>();
    if (!constellations.hasInstantReload()) return;
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    final shouldReload = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            decoration: BoxDecoration(
              color: t.bg1,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: t.borderAccent, width: 1),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 30,
                      decoration: BoxDecoration(
                        color: t.amber,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      AppIcons.refresh_rounded,
                      color: t.amberBright,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'EXTRACTION COMPLETE',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: t.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: t.borderMid),
                const SizedBox(height: 14),
                Text(
                  'Reload the same specimen with the same settings?',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.bg2,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: t.borderDim),
                          ),
                          child: Text(
                            'NOT NOW',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, true),
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                t.amberDim.withValues(alpha: 0.45),
                                t.amber.withValues(alpha: 0.35),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: t.amber.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Text(
                            'RELOAD',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.amberBright,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (shouldReload != true || !mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final inst = await db.creatureDao.getInstance(
      previousJob.creatureInstanceId,
    );
    if (inst == null) {
      _showToast(
        'That creature is no longer available.',
        icon: AppIcons.error_outline,
        color: Colors.red.shade400,
      );
      return;
    }
    final base = repo.getCreatureById(inst.baseId);
    if (base == null || base.types.isEmpty) return;
    final creatureTypeId = base.types.first;
    await widget.service.setActiveElement(widget.farm.biome, creatureTypeId);
    final ok = await widget.service.startJob(
      biome: widget.farm.biome,
      creatureInstanceId: inst.instanceId,
      duration: Duration(milliseconds: previousJob.durationMs),
      ratePerMinute: previousJob.ratePerMinute,
    );
    if (!mounted) return;
    if (ok) {
      HapticFeedback.mediumImpact();
      _showToast(
        'Chamber reloaded!',
        icon: AppIcons.refresh_rounded,
        color: theme.primary,
      );
      await _refreshCreatureCache();
    } else {
      _showToast(
        'Could not reload.',
        icon: AppIcons.error_outline,
        color: Colors.red.shade400,
      );
    }
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  Future<void> _handleCancel(FactionTheme theme) async {
    if (_collectCtrl.isAnimating) return;
    final t = ForgeTokens(theme);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            decoration: BoxDecoration(
              color: t.bg1,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: t.borderAccent, width: 1),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(width: 3, height: 26, color: t.danger),
                    const SizedBox(width: 10),
                    Text(
                      'CANCEL EXTRACTION',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: t.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: t.borderMid),
                const SizedBox(height: 14),
                Text(
                  'Your specimen will be returned, but current progress will be lost.',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.bg2,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: t.borderDim),
                          ),
                          child: Text(
                            'KEEP RUNNING',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, true),
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: t.danger.withValues(alpha: 0.55),
                            ),
                          ),
                          child: Text(
                            'TERMINATE',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    HapticFeedback.heavyImpact();
    await _collectCtrl.forward(from: 0);
    await widget.service.cancel(widget.farm.biome);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Extraction cancelled'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        showCloseIcon: true,
      ),
    );
    await _refreshCreatureCache();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showToast(
    String msg, {
    IconData icon = AppIcons.info_rounded,
    Color? color,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: color ?? Colors.indigo.shade400,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        showCloseIcon: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final t = ForgeTokens(theme);
    return ListenableBuilder(
      listenable: widget.service,
      builder: (_, __) {
        final farm = widget.service.biome(widget.farm.biome);
        final accent = farm.currentColor;
        final vm = _syncAndComputeProgress(farm);
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = widget.featured
                ? constraints.maxWidth < 320
                : constraints.maxWidth < 180;
            final panelHeight = widget.featured
                ? (farm.hasActive ? 104.0 : 64.0)
                : compact
                ? (farm.hasActive ? 82.0 : 48.0)
                : (farm.hasActive ? 86.0 : 50.0);

            Widget? badge;
            if (farm.completed) {
              badge = _AlchemyStatusBadge(
                controller: _statusCtrl,
                label: 'COMPLETE',
                color: t.success,
              );
            } else if (farm.unlocked && !farm.hasActive) {
              badge = _AlchemyStatusBadge(
                controller: _statusCtrl,
                label: 'READY',
                color: accent,
              );
            }

            if (widget.featured) {
              return Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 6,
                    right: 6,
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 38,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.45),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                farm.biome.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _display(
                                  context,
                                  22,
                                  t.textPrimary,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                farm.biome.elementTypes.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _display(
                                  context,
                                  12,
                                  t.textSecondary,
                                  weight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 54,
                    bottom: panelHeight + 30,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _ChamberView(
                          tSeconds: _tSeconds,
                          progress: vm.progress,
                          collectCtrl: _collectCtrl,
                          tapFxCtrl: _tapFxCtrl,
                          onTapBoost: () => _handleTapBoost(farm),
                          farm: farm,
                          accent: accent,
                          statusOverlay: badge,
                          effectiveFill: vm.effectiveFill,
                          creatureWidget: _creatureWidget,
                          onTapDown: (details, inner) {
                            final lp = details.localPosition;
                            final clamped = Offset(
                              lp.dx.clamp(inner.left + 6, inner.right - 6),
                              lp.dy.clamp(inner.top + 6, inner.bottom - 6),
                            );
                            setState(() => _tapLocal = clamped);
                            _tapFxCtrl.forward(from: 0);
                          },
                          tapLocal: _tapLocal,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 2,
                    right: 2,
                    bottom: 0,
                    child: CustomPaint(
                      painter: _BracketFramePainter(
                        color: accent.withValues(alpha: 0.46),
                        bracketSize: 12,
                        strokeWidth: 1,
                      ),
                      child: Container(
                        height: panelHeight + 18,
                        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              t.bg2.withValues(alpha: 0.18),
                              t.bg0.withValues(alpha: 0.54),
                            ],
                          ),
                          border: Border(
                            top: BorderSide(
                              color: accent.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        child: farm.hasActive
                            ? _ActivePanel(
                                color: accent,
                                theme: theme,
                                farm: farm,
                                biome: farm.biome,
                                remaining: vm.remaining,
                                compact: compact,
                                onCollect: farm.completed
                                    ? () => _handleCollect(farm)
                                    : null,
                                onCancel: () => _handleCancel(theme),
                              )
                            : !farm.unlocked
                            ? _LockedPanel(
                                color: accent,
                                theme: theme,
                                compact: compact,
                                onBack: widget.onUnlock,
                              )
                            : _StartPanel(
                                color: accent,
                                theme: theme,
                                biome: farm.biome,
                                defaultDuration: widget.defaultDuration,
                                compact: compact,
                                onPickAndStart: _handlePickAndStart,
                              ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: t.bg2.withValues(
                  alpha: widget.featured
                      ? (theme.isDark ? 0.64 : 0.88)
                      : (theme.isDark ? 0.54 : 0.82),
                ),
                borderRadius: BorderRadius.circular(widget.featured ? 8 : 6),
                border: Border.all(
                  color: farm.completed
                      ? t.success.withValues(alpha: theme.isDark ? 0.46 : 0.32)
                      : farm.hasActive
                      ? accent.withValues(alpha: theme.isDark ? 0.34 : 0.26)
                      : t.borderDim.withValues(alpha: 0.72),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: widget.featured
                          ? (theme.isDark ? 0.34 : 0.07)
                          : (theme.isDark ? 0.22 : 0.05),
                    ),
                    blurRadius: widget.featured
                        ? (theme.isDark ? 28 : 16)
                        : (theme.isDark ? 18 : 10),
                    offset: Offset(0, widget.featured ? 14 : 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      widget.featured ? 14 : (compact ? 8 : 10),
                      widget.featured ? 12 : (compact ? 7 : 8),
                      widget.featured ? 12 : (compact ? 7 : 9),
                      widget.featured ? 10 : (compact ? 5 : 6),
                    ),
                    decoration: BoxDecoration(
                      color: t.bg3.withValues(alpha: theme.isDark ? 0.46 : 0.5),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                farm.biome.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _display(
                                  context,
                                  widget.featured ? 20 : (compact ? 13 : 14),
                                  t.textPrimary,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                farm.biome.elementTypes.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _display(
                                  context,
                                  widget.featured ? 12 : (compact ? 9.5 : 10),
                                  t.textSecondary,
                                  weight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1,
                    color: t.borderDim.withValues(alpha: 0.62),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        widget.featured ? 12 : (compact ? 4 : 6),
                        widget.featured ? 10 : 4,
                        widget.featured ? 12 : (compact ? 4 : 6),
                        widget.featured ? 12 : (compact ? 6 : 7),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: AspectRatio(
                                aspectRatio: widget.featured
                                    ? 1.0
                                    : compact
                                    ? 1.14
                                    : 1.08,
                                child: _ChamberView(
                                  tSeconds: _tSeconds,
                                  progress: vm.progress,
                                  collectCtrl: _collectCtrl,
                                  tapFxCtrl: _tapFxCtrl,
                                  onTapBoost: () => _handleTapBoost(farm),
                                  farm: farm,
                                  accent: accent,
                                  statusOverlay: badge,
                                  effectiveFill: vm.effectiveFill,
                                  creatureWidget: _creatureWidget,
                                  onTapDown: (details, inner) {
                                    final lp = details.localPosition;
                                    final clamped = Offset(
                                      lp.dx.clamp(
                                        inner.left + 6,
                                        inner.right - 6,
                                      ),
                                      lp.dy.clamp(
                                        inner.top + 6,
                                        inner.bottom - 6,
                                      ),
                                    );
                                    setState(() => _tapLocal = clamped);
                                    _tapFxCtrl.forward(from: 0);
                                  },
                                  tapLocal: _tapLocal,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: panelHeight,
                            child: farm.hasActive
                                ? _ActivePanel(
                                    color: accent,
                                    theme: theme,
                                    farm: farm,
                                    biome: farm.biome,
                                    remaining: vm.remaining,
                                    compact: compact,
                                    onCollect: farm.completed
                                        ? () => _handleCollect(farm)
                                        : null,
                                    onCancel: () => _handleCancel(theme),
                                  )
                                : SizedBox(
                                    width: double.infinity,
                                    child: !farm.unlocked
                                        ? _LockedPanel(
                                            color: accent,
                                            theme: theme,
                                            compact: compact,
                                            onBack: widget.onUnlock,
                                          )
                                        : _StartPanel(
                                            color: accent,
                                            theme: theme,
                                            biome: farm.biome,
                                            defaultDuration:
                                                widget.defaultDuration,
                                            compact: compact,
                                            onPickAndStart: _handlePickAndStart,
                                          ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Progress view model
// ---------------------------------------------------------------------------

class _ProgressViewModel {
  const _ProgressViewModel({
    required this.progress,
    required this.effectiveFill,
    required this.remaining,
  });
  final double progress;
  final double effectiveFill;
  final Duration? remaining;
}

// ---------------------------------------------------------------------------
// Panels — identical to BiomeDetailScreen
// ---------------------------------------------------------------------------

class _StartPanel extends StatelessWidget {
  const _StartPanel({
    required this.color,
    required this.theme,
    required this.biome,
    required this.defaultDuration,
    required this.compact,
    required this.onPickAndStart,
  });
  final Color color;
  final FactionTheme theme;
  final Biome biome;
  final Duration defaultDuration;
  final bool compact;
  final VoidCallback onPickAndStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PrimaryBtn(
          label: 'Insert alchemon',
          accent: color,
          theme: theme,
          compact: compact,
          onTap: onPickAndStart,
        ),
      ],
    );
  }
}

class _ActivePanel extends StatelessWidget {
  const _ActivePanel({
    required this.color,
    required this.theme,
    required this.farm,
    required this.biome,
    required this.remaining,
    required this.compact,
    required this.onCollect,
    required this.onCancel,
  });
  final Color color;
  final FactionTheme theme;
  final BiomeFarmState farm;
  final Biome biome;
  final Duration? remaining;
  final bool compact;
  final VoidCallback? onCollect;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    final j = farm.activeJob!;
    final rate = j.ratePerMinute;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          farm.completed
              ? 'Ready to collect'
              : '${_formatHarvestRemaining(remaining)} · $rate/min',
          style: _display(
            context,
            compact ? 10.5 : 11.5,
            farm.completed ? t.success : color,
            weight: FontWeight.w700,
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        if (compact) ...[
          Row(
            children: [
              Expanded(
                child: _PrimaryBtn(
                  label: 'Collect',
                  accent: color,
                  theme: theme,
                  compact: compact,
                  minHeight: 38,
                  onTap: (farm.completed && onCollect != null)
                      ? onCollect!
                      : null,
                  disabled: !farm.completed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OutlineBtn(
                  label: 'End run',
                  accent: color,
                  theme: theme,
                  compact: compact,
                  minHeight: 38,
                  onTap: onCancel,
                ),
              ),
            ],
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: _PrimaryBtn(
                  label: 'Collect',
                  accent: color,
                  theme: theme,
                  compact: compact,
                  minHeight: 42,
                  onTap: (farm.completed && onCollect != null)
                      ? onCollect!
                      : null,
                  disabled: !farm.completed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OutlineBtn(
                  label: 'End run',
                  accent: color,
                  theme: theme,
                  compact: compact,
                  minHeight: 42,
                  onTap: onCancel,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

String _formatHarvestRemaining(Duration? d) {
  if (d == null) return '';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}

class _LockedPanel extends StatelessWidget {
  const _LockedPanel({
    required this.color,
    required this.theme,
    required this.compact,
    required this.onBack,
  });
  final Color color;
  final FactionTheme theme;
  final bool compact;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _OutlineBtn(
          label: 'Unlock chamber',
          accent: color,
          theme: theme,
          compact: compact,
          onTap: onBack,
        ),
      ],
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.label,
    required this.accent,
    required this.theme,
    required this.compact,
    required this.onTap,
    this.disabled = false,
    this.minHeight,
  });
  final String label;
  final Color accent;
  final FactionTheme theme;
  final bool compact;
  final VoidCallback? onTap;
  final bool disabled;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    final bg = disabled ? t.bg3 : accent.withValues(alpha: 0.16);
    final border = disabled ? t.borderDim : accent.withValues(alpha: 0.48);
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: CustomPaint(
          painter: _BracketFramePainter(
            color: border,
            bracketSize: 9,
            strokeWidth: 1.05,
          ),
          child: Container(
            constraints: BoxConstraints(minHeight: minHeight ?? 0),
            padding: EdgeInsets.symmetric(vertical: compact ? 9 : 11),
            color: bg,
            alignment: Alignment.center,
            child: Text(
              label,
              style: _display(
                context,
                compact ? 11 : 12.5,
                disabled ? t.textMuted : t.textPrimary,
                weight: FontWeight.w700,
                letterSpacing: 0.45,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({
    required this.label,
    required this.accent,
    required this.theme,
    required this.compact,
    required this.onTap,
    this.minHeight,
  });
  final String label;
  final Color accent;
  final FactionTheme theme;
  final bool compact;
  final VoidCallback onTap;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _BracketFramePainter(
          color: accent.withValues(alpha: 0.55),
          bracketSize: 9,
          strokeWidth: 1.05,
        ),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight ?? 0),
          padding: EdgeInsets.symmetric(vertical: compact ? 9 : 11),
          color: t.bg2,
          alignment: Alignment.center,
          child: Text(
            label,
            style: _display(
              context,
              compact ? 11 : 12.5,
              t.textPrimary,
              weight: FontWeight.w700,
              letterSpacing: 0.45,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ChamberView — verbatim from BiomeDetailScreen
// ---------------------------------------------------------------------------

class _ChamberView extends StatelessWidget {
  const _ChamberView({
    required this.tSeconds,
    required this.progress,
    required this.collectCtrl,
    required this.tapFxCtrl,
    required this.onTapBoost,
    required this.farm,
    required this.accent,
    required this.effectiveFill,
    required this.creatureWidget,
    required this.onTapDown,
    required this.tapLocal,
    this.statusOverlay,
  });
  final Widget? statusOverlay;
  final double tSeconds;
  final double progress;
  final AnimationController collectCtrl;
  final AnimationController tapFxCtrl;
  final VoidCallback onTapBoost;
  final BiomeFarmState farm;
  final Color accent;
  final double effectiveFill;
  final Widget? creatureWidget;
  final void Function(TapDownDetails details, RRect inner) onTapDown;
  final Offset? tapLocal;

  double _tempo() {
    final ramp = Curves.easeInQuart.transform(progress).clamp(0.0, 1.0);
    final nearDone = (progress > .85) ? (progress - .85) / .15 : 0.0;
    final endBoost = Curves.easeOutExpo.transform(nearDone.clamp(0, 1));
    final v = tapFxCtrl.value;
    final tapBell = (v == 0) ? 0 : (1 - (2 * (v - .5)).abs());
    final tapBoost = tapBell * 1.6;
    return 1.0 + 3.0 * ramp + 1.5 * endBoost + tapBoost;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final geo = _ChamberGeometry.fromSize(size);
        final inner = geo.inner;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            HapticFeedback.lightImpact();
            onTapBoost();
            onTapDown(d, inner);
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([collectCtrl, tapFxCtrl]),
            child: Stack(
              children: [
                Positioned.fromRect(
                  rect: inner.outerRect,
                  child: ClipRRect(
                    borderRadius: inner._toBorderRadius(),
                    child: Center(
                      child: _CreatureIdle(
                        tapFxCtrl: tapFxCtrl,
                        child:
                            creatureWidget ??
                            Icon(
                              AppIcons.science_outlined,
                              size: 28,
                              color: accent.withValues(alpha: 0.55),
                            ),
                      ),
                    ),
                  ),
                ),
                CustomPaint(
                  painter: _ChamberBackgroundPainter(
                    tSeconds: tSeconds,
                    tempo: _tempo(),
                    fill: effectiveFill,
                    color: accent,
                    active: farm.hasActive,
                  ),
                  size: size,
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: tapFxCtrl,
                      builder: (_, __) => AlchemyTapFX(
                        center: tapLocal,
                        progress: tapFxCtrl.value,
                        color: accent,
                      ),
                    ),
                  ),
                ),
                CustomPaint(
                  painter: _ChamberForegroundPainter(
                    tSeconds: tSeconds,
                    tempo: _tempo(),
                    color: accent,
                    active: farm.hasActive,
                  ),
                  size: size,
                ),
                if (statusOverlay != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Transform.translate(
                          offset: Offset(0, size.height * -0.08),
                          child: statusOverlay!,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            builder: (_, child) {
              final v = collectCtrl.value;
              final decay = 1.0 - v;
              final dx = math.sin(v * math.pi * 10) * 5.0 * decay;
              final dy = math.cos(v * math.pi * 8) * 4.0 * decay;
              final rot = math.sin(v * math.pi * 6) * 0.012 * decay;
              return Transform.translate(
                offset: Offset(dx, dy),
                child: Transform.rotate(angle: rot, child: child),
              );
            },
          ),
        );
      },
    );
  }
}

class _CreatureIdle extends StatelessWidget {
  const _CreatureIdle({required this.tapFxCtrl, required this.child});
  final AnimationController tapFxCtrl;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tapFxCtrl,
      builder: (context, _) {
        final v = tapFxCtrl.value;
        final osc = math.sin(v * math.pi * 10);
        final decay = 1.0 - v;
        final amp = 6.0 * decay;
        final dx = osc * amp * .55;
        final dy = -osc * amp * .35;
        final rot = osc * 0.02;
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(angle: rot, child: child),
        );
      },
    );
  }
}

extension _RRectBorderRadius on RRect {
  BorderRadius _toBorderRadius() => BorderRadius.only(
    topLeft: Radius.circular(tlRadiusX),
    topRight: Radius.circular(trRadiusX),
    bottomLeft: Radius.circular(blRadiusX),
    bottomRight: Radius.circular(brRadiusX),
  );
}

class _ChamberGeometry {
  _ChamberGeometry(this.outer, this.inner, this.center, this.radius);
  final RRect outer;
  final RRect inner;
  final Offset center;
  final double radius;

  static _ChamberGeometry fromSize(Size size) {
    final w = size.width;
    final h = size.height;
    final d = math.min(w, h * 0.78);
    final cx = w / 2;
    final cy = h * 0.42;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: d, height: d);
    final outer = RRect.fromRectAndRadius(rect, Radius.circular(d / 2));
    final inner = outer.deflate(d * 0.06);
    return _ChamberGeometry(outer, inner, Offset(cx, cy), d / 2);
  }
}

class _ChamberBackgroundPainter extends CustomPainter {
  _ChamberBackgroundPainter({
    required this.tSeconds,
    required this.tempo,
    required this.fill,
    required this.color,
    required this.active,
  });
  final double tSeconds;
  final double tempo;
  final double fill;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final geo = _ChamberGeometry.fromSize(size);
    final inner = geo.inner;
    final c = geo.center;
    final r = geo.radius * 0.92;
    canvas.save();
    canvas.clipRRect(inner);
    final back = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: .45),
          Colors.black.withValues(alpha: .70),
        ],
      ).createShader(inner.outerRect);
    canvas.drawRect(inner.outerRect, back);
    final beamAlpha = (0.20 + 0.65 * Curves.easeOutCubic.transform(fill)).clamp(
      0.0,
      0.85,
    );
    final beam = Paint()
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.55,
        colors: [
          color.withValues(alpha: beamAlpha * .9),
          color.withValues(alpha: beamAlpha * .35),
          Colors.transparent,
        ],
        stops: const [.0, .35, 1.0],
      ).createShader(inner.outerRect);
    canvas.drawCircle(c, r * 0.78, beam);
    final baseAngle = active ? tSeconds * tempo : 0.0;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: .40);
    final glyph = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: .85);

    void drawRing(double radius, double speed, int glyphs, double dash) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(baseAngle * speed);
      final dashCount = (math.pi * 2 * radius / dash).floor();
      final segment = (2 * math.pi) / dashCount;
      for (int i = 0; i < dashCount; i += 2) {
        final from = i * segment;
        final to = (i + 1) * segment;
        final p = Path()
          ..addArc(
            Rect.fromCircle(center: Offset.zero, radius: radius),
            from,
            to - from,
          );
        canvas.drawPath(p, ring);
      }
      for (int i = 0; i < glyphs; i++) {
        final ang = (i / glyphs) * (math.pi * 2);
        final x = math.cos(ang) * radius;
        final y = math.sin(ang) * radius;
        final sz = 2.6 + 1.2 * math.sin(baseAngle * (speed + .3) + i);
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-ang + baseAngle * (speed * .6));
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: sz,
          height: sz * 1.2,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(1.2)),
          glyph,
        );
        canvas.restore();
      }
      canvas.restore();
    }

    final intensity = (0.3 + 0.7 * fill).clamp(0.0, 1.0);
    drawRing(r * .68, 0.6 + intensity, 12, 10);
    drawRing(r * .51, 1.0 + intensity, 10, 9);
    drawRing(r * .36, 1.6 + intensity, 8, 8);

    final mote = Paint()..color = Colors.white.withValues(alpha: .70);
    final count = active ? 42 : 18;
    final suctionBase = 0.20 + 0.55 * Curves.easeOutCubic.transform(fill);
    final swirlBase = 0.60 + 0.80 * Curves.easeIn.transform(fill);
    for (int i = 0; i < count; i++) {
      final seed = i * 1337.0;
      final rand = (seed % 1000) / 1000.0;
      final r0 = r * (0.20 + 0.75 * rand);
      final a0 = (seed % (2 * math.pi));
      final speed = (0.35 + (seed % 17) / 40.0) * (0.8 + 0.6 * tempo);
      final t = (tSeconds * speed + (seed % 23) * .013) % 1.0;
      final suction = suctionBase * (0.65 + 0.35 * math.sin(seed));
      final rad = r0 * (1.0 - math.pow(t, 1.35) * suction).clamp(0.0, 1.0);
      final swirl = swirlBase * (1.0 + 0.7 * (1.0 - rad / r0));
      final ang = a0 + t * 2.0 * math.pi * swirl;
      final px = c.dx + math.cos(ang) * rad;
      final py = c.dy + math.sin(ang) * rad;
      if (inner.outerRect.contains(Offset(px, py))) {
        final sz = 1.1 + ((i % 5 == 0) ? 0.9 : 0.0);
        canvas.drawCircle(Offset(px, py), sz, mote);
        final trailT = (t - 0.06).clamp(0.0, 1.0);
        if (trailT > 0) {
          final rad2 = r0 * (1.0 - math.pow(trailT, 1.35) * suction);
          final ang2 = a0 + trailT * 2.0 * math.pi * swirl;
          final p2 = Offset(
            c.dx + math.cos(ang2) * rad2,
            c.dy + math.sin(ang2) * rad2,
          );
          canvas.drawCircle(
            p2,
            sz * 0.85,
            Paint()..color = Colors.white.withValues(alpha: .10),
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChamberBackgroundPainter old) =>
      old.tSeconds != tSeconds ||
      old.tempo != tempo ||
      old.fill != fill ||
      old.color != color ||
      old.active != active;
}

class _ChamberForegroundPainter extends CustomPainter {
  _ChamberForegroundPainter({
    required this.tSeconds,
    required this.tempo,
    required this.color,
    required this.active,
  });
  final double tSeconds;
  final double tempo;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final geo = _ChamberGeometry.fromSize(size);
    final outer = geo.outer;
    final inner = geo.inner;
    final c = geo.center;
    final r = geo.radius;
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (outer.width * 0.06).clamp(6, 18)
      ..shader = SweepGradient(
        colors: [
          Colors.white.withValues(alpha: .85),
          Colors.white.withValues(alpha: .45),
          Colors.white.withValues(alpha: .85),
        ],
      ).createShader(outer.outerRect);
    canvas.drawRRect(outer, rim);
    canvas.save();
    canvas.translate(.6, .6);
    canvas.drawRRect(
      outer.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFFF6B6B).withValues(alpha: .33),
    );
    canvas.restore();
    canvas.save();
    canvas.translate(-.6, -.6);
    canvas.drawRRect(
      outer.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF5EC8FF).withValues(alpha: .33),
    );
    canvas.restore();
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..shader =
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomLeft,
              colors: [Colors.white.withValues(alpha: .50), Colors.transparent],
            ).createShader(
              Rect.fromLTWH(outer.left - 6, outer.top, 10, outer.height),
            ),
    );
    final crown = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: active ? .65 : .25);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(active ? tSeconds * tempo * 1.2 : 0.0);
    final cr = r * 0.88;
    for (int i = 0; i < 24; i++) {
      final a = i / 24 * 2 * math.pi;
      canvas.drawLine(
        Offset(math.cos(a) * cr, math.sin(a) * cr),
        Offset(math.cos(a) * (cr - 10), math.sin(a) * (cr - 10)),
        crown,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = Colors.white.withValues(alpha: .45),
    );
  }

  @override
  bool shouldRepaint(covariant _ChamberForegroundPainter old) =>
      old.active != active ||
      old.color != color ||
      old.tempo != tempo ||
      (active && old.tSeconds != tSeconds);
}

class _AlchemyStatusBadge extends StatelessWidget {
  const _AlchemyStatusBadge({
    required this.controller,
    required this.label,
    required this.color,
  });
  final AnimationController controller;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final pulse = 0.65 + 0.35 * math.sin(t * math.pi * 2);
        final glow = 0.25 + 0.55 * (0.5 - (t - 0.5).abs()) * 2;
        return Opacity(
          opacity: 0.85,
          child: CustomPaint(
            painter: _AlchemyStatusPainter(
              t: t,
              pulse: pulse,
              glow: glow,
              color: color,
              label: label,
            ),
            size: const Size(160, 160),
          ),
        );
      },
    );
  }
}

class _AlchemyStatusPainter extends CustomPainter {
  _AlchemyStatusPainter({
    required this.t,
    required this.pulse,
    required this.glow,
    required this.color,
    required this.label,
  });
  final double t, pulse, glow;
  final Color color;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * 0.48;
    canvas.drawCircle(
      c,
      r * (1.05 + 0.02 * glow),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.08 * (0.7 + 0.3 * glow)),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.2)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + 1.8 * pulse
        ..color = Colors.white.withValues(alpha: 0.85),
    );
    canvas.save();
    canvas.translate(.8, .8);
    canvas.drawCircle(
      c,
      r * 0.985,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFFFF6B6B).withValues(alpha: .38),
    );
    canvas.restore();
    canvas.save();
    canvas.translate(-.8, -.8);
    canvas.drawCircle(
      c,
      r * 0.985,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFF5EC8FF).withValues(alpha: .38),
    );
    canvas.restore();
    final ticks = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: .75);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * math.pi * 2);
    final tr = r * 0.88;
    for (int i = 0; i < 24; i++) {
      final a = i / 24 * 2 * math.pi;
      canvas.drawLine(
        Offset(math.cos(a) * tr, math.sin(a) * tr),
        Offset(math.cos(a) * (tr - 10), math.sin(a) * (tr - 10)),
        ticks,
      );
    }
    canvas.restore();
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          color: Colors.white.withValues(alpha: .95),
          shadows: [
            Shadow(
              blurRadius: 6 + 10 * glow,
              color: color.withValues(alpha: .8),
            ),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    textPainter.paint(
      canvas,
      Offset(c.dx - textPainter.width / 2, c.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _AlchemyStatusPainter old) =>
      old.t != t ||
      old.pulse != pulse ||
      old.glow != glow ||
      old.color != color ||
      old.label != label;
}

// ---------------------------------------------------------------------------
// Unlock dialog
// ---------------------------------------------------------------------------

class _UnlockDialog extends StatelessWidget {
  const _UnlockDialog({required this.biome, required this.costDb});
  final Biome biome;
  final Map<String, int> costDb;

  @override
  Widget build(BuildContext context) {
    final color = biome.primaryColor;
    final theme = context.watch<FactionTheme>();
    final t = ForgeTokens(theme);
    final db = context.read<AlchemonsDatabase>();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: t.bg1.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: t.borderAccent, width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: theme.isDark ? 0.3 : 0.07),
              blurRadius: theme.isDark ? 20 : 14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<Map<String, int>>(
          stream: db.currencyDao.watchResourceBalances(),
          builder: (context, snap) {
            final bal = snap.data ?? {};
            bool hasShortage = false;
            for (final e in costDb.entries) {
              if ((bal[e.key] ?? 0) < e.value) {
                hasShortage = true;
                break;
              }
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(width: 3, height: 34, color: t.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'UNLOCK ${biome.label.toUpperCase()}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: t.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: t.borderMid),
                const SizedBox(height: 12),
                Text(
                  biome.description,
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'REQUIRED RESOURCES',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t.amberBright,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...costDb.entries.map((e) {
                  final have = bal[e.key] ?? 0;
                  final ok = have >= e.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: t.bg2,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: ok
                            ? color.withValues(alpha: 0.4)
                            : t.danger.withValues(alpha: 0.55),
                        width: 1.1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.key.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$have / ${e.value}',
                          style: TextStyle(
                            color: ok ? t.success : t.danger,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: t.bg2,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: t.borderDim),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'CANCEL',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Opacity(
                        opacity: hasShortage ? 0.5 : 1,
                        child: GestureDetector(
                          onTap: hasShortage
                              ? null
                              : () => Navigator.pop(context, true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  t.amberDim.withValues(alpha: 0.42),
                                  color.withValues(alpha: 0.18),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: hasShortage
                                    ? t.borderDim
                                    : t.amber.withValues(alpha: 0.65),
                                width: 1.1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              hasShortage ? 'NOT ENOUGH' : 'CONFIRM UNLOCK',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: hasShortage
                                    ? t.textMuted
                                    : t.amberBright,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
