import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/providers/app_providers.dart';
import 'package:alchemons/screens/breed/breed_tab.dart';
import 'package:alchemons/screens/breed/nursery_tab.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/glowing_icon.dart';

class BreedScreen extends StatefulWidget {
  /// 0 = Breeding, 1 = Incubator (Nursery)
  final int initialTab;
  const BreedScreen({super.key, this.initialTab = 0});

  @override
  State<BreedScreen> createState() => _BreedScreenState();
}

class _BreedScreenState extends State<BreedScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  Timer? _ticker;
  DateTime? _maxSeenNowUtc;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadHighWaterClock();
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _tabController.addListener(() {
      // pulse only when on Breeding tab (index 0)
      if (_tabController.index == 0) {
        _pulse.repeat(reverse: true);
      } else {
        _pulse.stop();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _pulse.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await _bumpHighWaterClock();
      setState(() {});
    }
  }

  Future<void> _loadHighWaterClock() async {
    final db = context.read<AlchemonsDatabase>();
    final s = await db.getSetting('max_seen_now_utc_ms');
    final ms = int.tryParse(s ?? '');
    _maxSeenNowUtc = (ms == null)
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    await _bumpHighWaterClock();
  }

  Future<void> _bumpHighWaterClock() async {
    final db = context.read<AlchemonsDatabase>();
    final nowUtc = DateTime.now().toUtc();
    if (_maxSeenNowUtc == null || nowUtc.isAfter(_maxSeenNowUtc!)) {
      _maxSeenNowUtc = nowUtc;
      await db.setSetting(
        'max_seen_now_utc_ms',
        nowUtc.millisecondsSinceEpoch.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();

    return Consumer<GameStateNotifier>(
      builder: (context, gameState, child) {
        if (gameState.isLoading) {
          return _buildLoadingScreen(theme, 'Loading specimen database...');
        }

        if (gameState.error != null) {
          return _buildErrorScreen(theme, gameState.error!, gameState.refresh);
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              // dark lab console background with faint faction glow
              gradient: RadialGradient(
                center: const Alignment(0, -0.6),
                radius: 1.2,
                colors: [
                  theme.surface,
                  theme.surface,
                  theme.surfaceAlt.withOpacity(.6),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderBar(theme: theme, controller: _pulse),
                  _TabSelector(theme: theme, tabController: _tabController),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        BreedingTab(
                          discoveredCreatures: gameState.discoveredCreatures,
                          onBreedingComplete: () async {
                            await _bumpHighWaterClock();
                            if (mounted) setState(() {});
                          },
                        ),
                        NurseryTab(
                          maxSeenNowUtc: _maxSeenNowUtc,
                          onHatchComplete: () {
                            if (mounted) setState(() {});
                          },
                          tabController: _tabController,
                        ),
                      ],
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

  // --- Loading / Error panels ----------------------------------------------

  Widget _buildLoadingScreen(FactionTheme theme, String message) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.2,
            colors: [
              theme.surface,
              theme.surface,
              theme.surfaceAlt.withOpacity(.6),
            ],
            stops: const [0, .6, 1],
          ),
        ),
        child: Center(
          child: Container(
            width: 240,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.border, width: 2),
              boxShadow: [
                BoxShadow(
                  color: theme.accent.withOpacity(.4),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(.8),
                  blurRadius: 40,
                  spreadRadius: 16,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(theme.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(
    FactionTheme theme,
    String error,
    VoidCallback onRetry,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.2,
            colors: [
              theme.surface,
              theme.surface,
              theme.surfaceAlt.withOpacity(.6),
            ],
            stops: const [0, .6, 1],
          ),
        ),
        child: Center(
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withOpacity(.4), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.redAccent,
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withOpacity(.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'SYSTEM ERROR DETECTED',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.redAccent.withOpacity(.9),
                          Colors.redAccent.withOpacity(.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withOpacity(.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(.4),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Text(
                      'RETRY CONNECTION',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HEADER BAR
// -----------------------------------------------------------------------------

class _HeaderBar extends StatelessWidget {
  final FactionTheme theme;
  final AnimationController controller;

  const _HeaderBar({required this.theme, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Sticky chrome top
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: theme.surfaceAlt,
        border: Border(bottom: BorderSide(color: theme.border, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.6),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: theme.accent.withOpacity(.25),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // left icon glow / info button
          GlowingIcon(
            icon: Icons.merge_type_rounded,
            color: theme.secondary,
            controller: controller,
            dialogTitle: "Breeding Protocols",
            dialogMessage:
                "Combine compatible specimens to synthesize new offspring with inherited traits. Offspring are sent to the Incubator. Certain elemental pairings and rare traits can unlock unique results.",
          ),

          const SizedBox(width: 12),

          // title / subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GENETICS LABORATORY',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  'Breeding protocols • Incubation systems',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB SELECTOR
// -----------------------------------------------------------------------------

class _TabSelector extends StatelessWidget {
  final FactionTheme theme;
  final TabController tabController;

  const _TabSelector({required this.theme, required this.tabController});

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: tabController,

      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelColor: theme.text,
      unselectedLabelColor: theme.textMuted,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 12,
        letterSpacing: 0.5,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      tabs: const [
        Tab(text: 'FUSION', height: 48),
        Tab(text: 'INCUBATOR', height: 48),
      ],
    );
  }
}
