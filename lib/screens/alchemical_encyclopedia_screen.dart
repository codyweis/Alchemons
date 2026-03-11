import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/services/alchemical_encyclopedia_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class AlchemicalEncyclopediaScreen extends StatefulWidget {
  final List<EncyclopediaRecipeEntry> unlockShowcase;

  const AlchemicalEncyclopediaScreen({
    super.key,
    this.unlockShowcase = const [],
  });

  @override
  State<AlchemicalEncyclopediaScreen> createState() =>
      _AlchemicalEncyclopediaScreenState();
}

class _AlchemicalEncyclopediaScreenState
    extends State<AlchemicalEncyclopediaScreen>
    with SingleTickerProviderStateMixin {
  late Future<AlchemicalEncyclopediaSnapshot> _snapshotFuture;
  late final TabController _tabController;
  final GlobalKey<_RecipeTabListState> _familyListKey =
      GlobalKey<_RecipeTabListState>();
  final GlobalKey<_RecipeTabListState> _elementListKey =
      GlobalKey<_RecipeTabListState>();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _showKnownOnly = false;
  bool _showcaseQueued = false;
  bool _showcaseRunning = false;
  bool _searchFocused = false;

  // Whether we've shown the initial entry animation
  bool _hasAnimatedIn = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _snapshotFuture = AlchemicalEncyclopediaService.loadSnapshot(
      db: context.read<AlchemonsDatabase>(),
    );
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchFocusChanged() {
    setState(() => _searchFocused = _searchFocusNode.hasFocus);
  }

  void _queueShowcaseIfNeeded({
    required AlchemicalEncyclopediaSnapshot data,
    required List<EncyclopediaRecipeEntry> visibleFamily,
    required List<EncyclopediaRecipeEntry> visibleElement,
  }) {
    if (_showcaseQueued || widget.unlockShowcase.isEmpty) return;
    _showcaseQueued = true;

    final targets = _resolveShowcaseTargets(
      data: data,
      visibleFamily: visibleFamily,
      visibleElement: visibleElement,
    );
    if (targets.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runUnlockShowcase(targets);
    });
  }

  List<_UnlockShowcaseTarget> _resolveShowcaseTargets({
    required AlchemicalEncyclopediaSnapshot data,
    required List<EncyclopediaRecipeEntry> visibleFamily,
    required List<EncyclopediaRecipeEntry> visibleElement,
  }) {
    final seen = <String>{};
    final targets = <_UnlockShowcaseTarget>[];

    for (final entry in widget.unlockShowcase) {
      final token = '${entry.kind.name}:${entry.pairKey}';
      if (!seen.add(token)) continue;

      final visible = switch (entry.kind) {
        EncyclopediaRecipeKind.family => visibleFamily.any(
          (r) => r.pairKey == entry.pairKey,
        ),
        EncyclopediaRecipeKind.element => visibleElement.any(
          (r) => r.pairKey == entry.pairKey,
        ),
      };
      if (!visible) continue;

      final discovered = switch (entry.kind) {
        EncyclopediaRecipeKind.family => data.discoveredFamilyKeys.contains(
          entry.pairKey,
        ),
        EncyclopediaRecipeKind.element => data.discoveredElementKeys.contains(
          entry.pairKey,
        ),
      };
      if (!discovered) continue;

      targets.add(
        _UnlockShowcaseTarget(kind: entry.kind, pairKey: entry.pairKey),
      );
    }

    return targets;
  }

  Future<void> _runUnlockShowcase(List<_UnlockShowcaseTarget> targets) async {
    if (_showcaseRunning || targets.isEmpty) return;
    _showcaseRunning = true;

    for (final target in targets) {
      if (!mounted) break;

      final desiredTabIndex = target.kind == EncyclopediaRecipeKind.family
          ? 0
          : 1;
      if (_tabController.index != desiredTabIndex) {
        _tabController.animateTo(
          desiredTabIndex,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        );
        await Future<void>.delayed(const Duration(milliseconds: 430));
      }

      if (!mounted) break;

      final listState = desiredTabIndex == 0
          ? _familyListKey.currentState
          : _elementListKey.currentState;
      if (listState == null) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        continue;
      }

      await listState.focusAndPulse(target.pairKey);
      if (!mounted) break;
      await Future<void>.delayed(const Duration(milliseconds: 160));
    }

    _showcaseRunning = false;
  }

  void _onSearchChanged() {
    final next = _searchController.text.trim().toLowerCase();
    if (next == _searchQuery) return;
    setState(() => _searchQuery = next);
  }

  void _reloadSnapshot() {
    setState(() {
      _snapshotFuture = AlchemicalEncyclopediaService.loadSnapshot(
        db: context.read<AlchemonsDatabase>(),
      );
    });
  }

  List<EncyclopediaRecipeEntry> _visibleRecipes({
    required List<EncyclopediaRecipeEntry> recipes,
    required Set<String> discoveredKeys,
  }) {
    final out = <EncyclopediaRecipeEntry>[];
    for (final recipe in recipes) {
      final unlocked = discoveredKeys.contains(recipe.pairKey);
      if (_showKnownOnly && !unlocked) continue;

      if (_searchQuery.isNotEmpty) {
        if (!unlocked) continue;
        final haystack = '${recipe.parentA} ${recipe.parentB} ${recipe.result}'
            .toLowerCase();
        if (!haystack.contains(_searchQuery)) continue;
      }
      out.add(recipe);
    }

    out.sort((a, b) {
      final aKnown = discoveredKeys.contains(a.pairKey);
      final bKnown = discoveredKeys.contains(b.pairKey);
      if (aKnown != bKnown) return aKnown ? -1 : 1;

      final first = a.parentA.compareTo(b.parentA);
      if (first != 0) return first;
      final second = a.parentB.compareTo(b.parentB);
      if (second != 0) return second;
      return a.result.compareTo(b.result);
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.of(context).bg0,
      body: Stack(
        children: [
          const _ForgeBackdrop(),
          SafeArea(
            child: FutureBuilder<AlchemicalEncyclopediaSnapshot>(
              future: _snapshotFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _LoadFailure(onRetry: _reloadSnapshot);
                }

                if (!snapshot.hasData) {
                  return const _ScorchedLoading();
                }

                final data = snapshot.data!;
                final discoveredFamily = data.familyRecipes
                    .where((e) => data.discoveredFamilyKeys.contains(e.pairKey))
                    .length;
                final discoveredElement = data.elementRecipes
                    .where(
                      (e) => data.discoveredElementKeys.contains(e.pairKey),
                    )
                    .length;
                final totalDiscovered = discoveredFamily + discoveredElement;
                final totalRecipes =
                    data.familyRecipes.length + data.elementRecipes.length;
                final completion = totalRecipes == 0
                    ? 0.0
                    : totalDiscovered / totalRecipes;

                final visibleFamily = _visibleRecipes(
                  recipes: data.familyRecipes,
                  discoveredKeys: data.discoveredFamilyKeys,
                );
                final visibleElement = _visibleRecipes(
                  recipes: data.elementRecipes,
                  discoveredKeys: data.discoveredElementKeys,
                );
                _queueShowcaseIfNeeded(
                  data: data,
                  visibleFamily: visibleFamily,
                  visibleElement: visibleElement,
                );

                // Trigger entry animation once data loads
                if (!_hasAnimatedIn) {
                  _hasAnimatedIn = true;
                }

                return _StaggeredEntrance(
                  children: [
                    _ForgeTopBar(
                      completion: completion,
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                      child: _OverviewPanel(
                        totalDiscovered: totalDiscovered,
                        totalRecipes: totalRecipes,
                        discoveredFamily: discoveredFamily,
                        totalFamily: data.familyRecipes.length,
                        discoveredElement: discoveredElement,
                        totalElement: data.elementRecipes.length,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _FilterPanel(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        hasSearchQuery: _searchQuery.isNotEmpty,
                        showKnownOnly: _showKnownOnly,
                        isFocused: _searchFocused,
                        onToggleKnownOnly: () {
                          HapticFeedback.lightImpact();
                          setState(() => _showKnownOnly = !_showKnownOnly);
                        },
                        onClearSearch: () {
                          _searchController.clear();
                          HapticFeedback.selectionClick();
                        },
                      ),
                    ),
                    _RecipeTabBar(
                      controller: _tabController,
                      familyCount: visibleFamily.length,
                      elementCount: visibleElement.length,
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _RecipeTabList(
                            key: _familyListKey,
                            kind: EncyclopediaRecipeKind.family,
                            recipes: visibleFamily,
                            discoveredKeys: data.discoveredFamilyKeys,
                            query: _searchQuery,
                            knownOnly: _showKnownOnly,
                          ),
                          _RecipeTabList(
                            key: _elementListKey,
                            kind: EncyclopediaRecipeKind.element,
                            recipes: visibleElement,
                            discoveredKeys: data.discoveredElementKeys,
                            query: _searchQuery,
                            knownOnly: _showKnownOnly,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Staggered entrance animation for top-level sections ───────────────────

class _StaggeredEntrance extends StatefulWidget {
  final List<Widget> children;
  const _StaggeredEntrance({required this.children});

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  @override
  void initState() {
    super.initState();
    final count = widget.children.length;
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 320 + count * 60),
    );

    _fadeAnims = List.generate(count, (i) {
      final start = (i * 0.12).clamp(0.0, 0.7);
      final end = (start + 0.35).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _slideAnims = List.generate(count, (i) {
      final start = (i * 0.12).clamp(0.0, 0.7);
      final end = (start + 0.35).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < widget.children.length; i++)
          widget.children[i] is Expanded
              ? Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnims[i],
                    child: SlideTransition(
                      position: _slideAnims[i],
                      child: (widget.children[i] as Expanded).child,
                    ),
                  ),
                )
              : FadeTransition(
                  opacity: _fadeAnims[i],
                  child: SlideTransition(
                    position: _slideAnims[i],
                    child: widget.children[i],
                  ),
                ),
      ],
    );
  }
}

// ─── Showcase target ────────────────────────────────────────────────────────

class _UnlockShowcaseTarget {
  final EncyclopediaRecipeKind kind;
  final String pairKey;
  const _UnlockShowcaseTarget({required this.kind, required this.pairKey});
}

// ─── Color palette ──────────────────────────────────────────────────────────

class _C {
  final Color bg0, bg1, bg2, bg3;
  final Color amber, amberBright, amberGlow, teal;
  final Color textPrimary, textSecondary, textMuted;
  final Color borderDim, borderAccent;

  const _C._({
    required this.bg0,
    required this.bg1,
    required this.bg2,
    required this.bg3,
    required this.amber,
    required this.amberBright,
    required this.amberGlow,
    required this.teal,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderDim,
    required this.borderAccent,
  });

  static const _C _dark = _C._(
    bg0: Color(0xFF080A0E),
    bg1: Color(0xFF0E1117),
    bg2: Color(0xFF141820),
    bg3: Color(0xFF1C2230),
    amber: Color(0xFFD97706),
    amberBright: Color(0xFFF59E0B),
    amberGlow: Color(0xFFFFB020),
    teal: Color(0xFF0EA5E9),
    textPrimary: Color(0xFFE8DCC8),
    textSecondary: Color(0xFF8A7B6A),
    textMuted: Color(0xFF4A3F35),
    borderDim: Color(0xFF252D3A),
    borderAccent: Color(0xFF6B4C20),
  );

  static const _C _light = _C._(
    bg0: Color(0xFFF5F7FB),
    bg1: Color(0xFFFFFFFF),
    bg2: Color(0xFFFFFFFF),
    bg3: Color(0xFFE8EDF5),
    amber: Color(0xFFD97706),
    amberBright: Color(0xFFB45309),
    amberGlow: Color(0xFFF59E0B),
    teal: Color(0xFF0E7490),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF4B5563),
    textMuted: Color(0xFF6B7280),
    borderDim: Color(0xFFD0D7E2),
    borderAccent: Color(0xFFB8C3D3),
  );

  static _C of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;
}

// ─── Text styles ────────────────────────────────────────────────────────────

class _T {
  static TextStyle heading(BuildContext context) => TextStyle(
    fontFamily: 'monospace',
    color: _C.of(context).textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
  );
  static TextStyle label(BuildContext context) => TextStyle(
    fontFamily: 'monospace',
    color: _C.of(context).textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
  );
  static TextStyle body(BuildContext context) => TextStyle(
    color: _C.of(context).textSecondary,
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );
}

// ─── Loading / error ────────────────────────────────────────────────────────

class _ScorchedLoading extends StatelessWidget {
  const _ScorchedLoading();
  @override
  Widget build(BuildContext context) => Center(
    child: CircularProgressIndicator(color: _C.of(context).amberBright),
  );
}

class _LoadFailure extends StatelessWidget {
  final VoidCallback onRetry;
  const _LoadFailure({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: _PlateFrame(
        accentColor: _C.of(context).amber,
        highlight: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: _C.of(context).amberBright,
            ),
            const SizedBox(height: 10),
            Text(
              'ENCYCLOPEDIA DATA LINK LOST',
              style: _T.heading(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Could not load extraction records. Reconnect and retry.',
              textAlign: TextAlign.center,
              style: _T.body(context).copyWith(color: _C.of(context).textMuted),
            ),
            const SizedBox(height: 12),
            _ActionButton(label: 'Retry', icon: Icons.refresh, onTap: onRetry),
          ],
        ),
      ),
    ),
  );
}

// ─── Backdrop ───────────────────────────────────────────────────────────────

class _ForgeBackdrop extends StatelessWidget {
  const _ForgeBackdrop();
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_C.of(context).bg1, _C.of(context).bg0],
          ),
        ),
      ),
      Positioned(
        top: -120,
        left: -40,
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _C.of(context).amber.withValues(alpha: .08),
          ),
        ),
      ),
      Positioned(
        bottom: -140,
        right: -80,
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _C.of(context).teal.withValues(alpha: .06),
          ),
        ),
      ),
      IgnorePointer(
        child: CustomPaint(
          painter: _ScanlinePainter(),
          child: const SizedBox.expand(),
        ),
      ),
    ],
  );
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black.withValues(alpha: 0.08);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Top bar ────────────────────────────────────────────────────────────────

class _ForgeTopBar extends StatelessWidget {
  final double completion;
  final VoidCallback onBack;
  const _ForgeTopBar({required this.completion, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final percent = (completion * 100).round().clamp(0, 100);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _C.of(context).bg2,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: _C.of(context).borderDim),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: _C.of(context).textSecondary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Pulsing status dot
                    _PulsingStatusDot(),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'ALCHEMY',
                        style: _T.heading(context),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  'DOMINANT EXTRACTION RECORDS',
                  style: _T.label(context),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          // Animated percentage badge
          _AnimatedPercentBadge(percent: percent),
        ],
      ),
    );
  }
}

// ─── Pulsing status dot ─────────────────────────────────────────────────────

class _PulsingStatusDot extends StatefulWidget {
  const _PulsingStatusDot();
  @override
  State<_PulsingStatusDot> createState() => _PulsingStatusDotState();
}

class _PulsingStatusDotState extends State<_PulsingStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: false);

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.55,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.55,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 45),
    ]).animate(_ctrl);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.9,
          end: 0.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.3,
          end: 0.9,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(tween: ConstantTween(0.9), weight: 45),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding ring
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Opacity(
              opacity: (1.0 - _ctrl.value).clamp(0.0, 1.0) * 0.55,
              child: Transform.scale(
                scale: _scale.value,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _C.of(context).amberBright,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Core dot
          AnimatedBuilder(
            animation: _opacity,
            builder: (_, __) => Opacity(
              opacity: _opacity.value,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _C.of(context).amberBright,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated % badge (counts up on entry) ──────────────────────────────────

class _AnimatedPercentBadge extends StatefulWidget {
  final int percent;
  const _AnimatedPercentBadge({required this.percent});
  @override
  State<_AnimatedPercentBadge> createState() => _AnimatedPercentBadgeState();
}

class _AnimatedPercentBadgeState extends State<_AnimatedPercentBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<int> _value;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _value = IntTween(
      begin: 0,
      end: widget.percent,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void didUpdateWidget(_AnimatedPercentBadge old) {
    super.didUpdateWidget(old);
    if (old.percent != widget.percent) {
      _value = IntTween(
        begin: _value.value,
        end: widget.percent,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _value,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _C.of(context).bg2,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: _C.of(context).borderAccent.withValues(alpha: .75),
          ),
        ),
        child: Text(
          '${_value.value}%',
          style: TextStyle(
            fontFamily: 'monospace',
            color: _C.of(context).amberBright,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ─── Overview panel ─────────────────────────────────────────────────────────

class _OverviewPanel extends StatelessWidget {
  final int totalDiscovered, totalRecipes;
  final int discoveredFamily, totalFamily;
  final int discoveredElement, totalElement;

  const _OverviewPanel({
    required this.totalDiscovered,
    required this.totalRecipes,
    required this.discoveredFamily,
    required this.totalFamily,
    required this.discoveredElement,
    required this.totalElement,
  });

  @override
  Widget build(BuildContext context) {
    final completion = totalRecipes == 0 ? 0.0 : totalDiscovered / totalRecipes;
    return _PlateFrame(
      accentColor: _C.of(context).amber,
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.of(context).amber.withValues(alpha: .18),
                  border: Border.all(
                    color: _C.of(context).amber.withValues(alpha: .4),
                  ),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: _C.of(context).amberBright,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Count-up number display
                    _CountUpText(
                      value: totalDiscovered,
                      total: totalRecipes,
                      style: TextStyle(
                        color: _C.of(context).textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Archive completion ${(completion * 100).toStringAsFixed(1)}%',
                      style: _T.body(context).copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AnimatedCompletionBar(
            progress: completion,
            color: _C.of(context).amberBright,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DiscoveryStat(
                  label: 'Family',
                  discovered: discoveredFamily,
                  total: totalFamily,
                  color: _C.of(context).amberBright,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DiscoveryStat(
                  label: 'Element',
                  discovered: discoveredElement,
                  total: totalElement,
                  color: _C.of(context).teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Count-up text ───────────────────────────────────────────────────────────

class _CountUpText extends StatefulWidget {
  final int value;
  final int total;
  final TextStyle style;
  const _CountUpText({
    required this.value,
    required this.total,
    required this.style,
  });
  @override
  State<_CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<_CountUpText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<int> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _anim = IntTween(
      begin: 0,
      end: widget.value,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void didUpdateWidget(_CountUpText old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = IntTween(
        begin: _anim.value,
        end: widget.value,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Text(
      '${_anim.value} / ${widget.total} formulas recovered',
      style: widget.style,
    ),
  );
}

// ─── Animated completion bar (fills on mount) ────────────────────────────────

class _AnimatedCompletionBar extends StatefulWidget {
  final double progress;
  final Color color;
  const _AnimatedCompletionBar({required this.progress, required this.color});
  @override
  State<_AnimatedCompletionBar> createState() => _AnimatedCompletionBarState();
}

class _AnimatedCompletionBarState extends State<_AnimatedCompletionBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = Tween<double>(
      begin: 0.0,
      end: widget.progress,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void didUpdateWidget(_AnimatedCompletionBar old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _anim = Tween<double>(
        begin: _anim.value,
        end: widget.progress,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) =>
        _CompletionBar(progress: _anim.value, color: widget.color),
  );
}

// ─── Filter panel ────────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasSearchQuery;
  final bool showKnownOnly;
  final bool isFocused;
  final VoidCallback onToggleKnownOnly;
  final VoidCallback onClearSearch;

  const _FilterPanel({
    required this.controller,
    required this.focusNode,
    required this.hasSearchQuery,
    required this.showKnownOnly,
    required this.isFocused,
    required this.onToggleKnownOnly,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return _PlateFrame(
      accentColor: _C.of(context).borderAccent,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Search bar with animated focus border
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: 40,
            decoration: BoxDecoration(
              color: _C.of(context).bg1,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: isFocused
                    ? _C.of(context).amberBright.withValues(alpha: .7)
                    : _C.of(context).borderDim,
                width: isFocused ? 1.5 : 1.0,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: _C.of(context).amber.withValues(alpha: .12),
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: TextStyle(color: _C.of(context).textPrimary, fontSize: 13),
              cursorColor: _C.of(context).amberBright,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search known parent or result names',
                hintStyle: TextStyle(
                  color: _C.of(context).textMuted.withValues(alpha: .75),
                  fontSize: 12,
                ),
                prefixIcon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.search_rounded,
                    key: ValueKey(isFocused),
                    color: isFocused
                        ? _C.of(context).amberBright
                        : _C.of(context).textSecondary,
                    size: 18,
                  ),
                ),
                suffixIcon: hasSearchQuery
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: _C.of(context).textSecondary,
                          size: 18,
                        ),
                        onPressed: onClearSearch,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ToggleChip(
                label: 'Known only',
                enabled: showKnownOnly,
                onTap: onToggleKnownOnly,
              ),
              const Spacer(),
              Text(
                'Unknown entries stay masked',
                style: _T
                    .label(context)
                    .copyWith(fontSize: 9, letterSpacing: 1.2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tab bar ─────────────────────────────────────────────────────────────────

class _RecipeTabBar extends StatelessWidget {
  final TabController controller;
  final int familyCount, elementCount;

  const _RecipeTabBar({
    required this.controller,
    required this.familyCount,
    required this.elementCount,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: _C.of(context).bg1,
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: _C.of(context).borderDim),
    ),
    child: TabBar(
      controller: controller,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        color: _C.of(context).bg3,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: _C.of(context).borderAccent.withValues(alpha: .85),
        ),
      ),
      labelColor: _C.of(context).amberBright,
      unselectedLabelColor: _C.of(context).textSecondary,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
      ),
      tabs: [
        Tab(text: 'FAMILY ($familyCount)'),
        Tab(text: 'ELEMENT ($elementCount)'),
      ],
    ),
  );
}

// ─── Tab list ────────────────────────────────────────────────────────────────

class _RecipeTabList extends StatefulWidget {
  final EncyclopediaRecipeKind kind;
  final List<EncyclopediaRecipeEntry> recipes;
  final Set<String> discoveredKeys;
  final String query;
  final bool knownOnly;

  const _RecipeTabList({
    super.key,
    required this.kind,
    required this.recipes,
    required this.discoveredKeys,
    required this.query,
    required this.knownOnly,
  });

  @override
  State<_RecipeTabList> createState() => _RecipeTabListState();
}

class _RecipeTabListState extends State<_RecipeTabList>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  late final AnimationController _focusController;
  String? _activePairKey;

  // Phase boundaries (0..1 on the controller):
  //  0.00–0.12  → flash burst (screen-level white flash on card)
  //  0.12–0.35  → bounce scale up + border surge
  //  0.35–0.68  → peak glow + diagonal shimmer sweep
  //  0.68–1.00  → settle back, sustained soft glow fades out

  @override
  void initState() {
    super.initState();
    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..addListener(_onFocusTick);
  }

  @override
  void dispose() {
    _focusController.removeListener(_onFocusTick);
    _focusController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocusTick() {
    if (!mounted || _activePairKey == null) return;
    setState(() {});
  }

  Future<bool> focusAndPulse(String pairKey) async {
    final targetIndex = widget.recipes.indexWhere(
      (entry) =>
          entry.pairKey == pairKey &&
          widget.discoveredKeys.contains(entry.pairKey),
    );
    if (targetIndex < 0) return false;

    _activePairKey = pairKey;
    _focusController.value = 0;
    if (mounted) setState(() {});

    await _scrollToIndex(targetIndex, pairKey);
    if (!mounted || _activePairKey != pairKey) return false;

    // Brief settle pause so the card is fully visible before flash
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted || _activePairKey != pairKey) return false;

    HapticFeedback.mediumImpact();
    await _focusController.forward(from: 0);
    if (!mounted || _activePairKey != pairKey) return true;

    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (mounted && _activePairKey == pairKey) {
      setState(() => _activePairKey = null);
    }
    return true;
  }

  Future<void> _scrollToIndex(int index, String pairKey) async {
    if (!_scrollController.hasClients) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    if (!_scrollController.hasClients) return;

    const estimatedItemExtent = 116.0;
    final estimatedOffset = (index * estimatedItemExtent).toDouble().clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    await _scrollController.animateTo(
      estimatedOffset,
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeInOutCubic,
    );

    await Future<void>.delayed(const Duration(milliseconds: 32));
    final targetContext = _rowKeys[pairKey]?.currentContext;
    if (targetContext == null || !mounted) return;
    if (!targetContext.mounted) return;

    await Scrollable.ensureVisible(
      targetContext,
      alignment: 0.18,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  _FocusState _focusStateForPair(String pairKey) {
    if (_activePairKey != pairKey) return const _FocusState.idle();
    final t = _focusController.value;

    // Phase 0: flash burst (0..0.12) — near-white fill explodes outward
    if (t <= 0.12) {
      final p = t / 0.12;
      return _FocusState(
        flash: Curves.easeOut.transform(p),
        glow: 0.0,
        scale: 1.0 + Curves.easeOut.transform(p) * 0.04,
        sweep: 0.0,
        badge: 0.0,
      );
    }

    // Phase 1: bounce + border surge (0.12..0.35)
    if (t <= 0.35) {
      final p = (t - 0.12) / 0.23;
      final flashFade = 1.0 - Curves.easeIn.transform(p);
      // Overshoot bounce: peaks at ~p=0.4 then settles
      final scaleOvershoot = p <= 0.4
          ? 1.04 + Curves.easeOut.transform(p / 0.4) * 0.04
          : 1.08 - Curves.easeOutCubic.transform((p - 0.4) / 0.6) * 0.06;
      return _FocusState(
        flash: flashFade * 0.85,
        glow: Curves.easeOut.transform(p),
        scale: scaleOvershoot,
        sweep: 0.0,
        badge: Curves.easeOut.transform(p),
      );
    }

    // Phase 2: peak glow + diagonal shimmer sweep (0.35..0.68)
    if (t <= 0.68) {
      final p = (t - 0.35) / 0.33;
      return _FocusState(
        flash: 0.0,
        glow: 1.0 - Curves.easeIn.transform(p) * 0.3,
        scale: 1.02 - Curves.easeOut.transform(p) * 0.02,
        sweep: Curves.easeInOut.transform(p), // drives shimmer position
        badge: 1.0,
      );
    }

    // Phase 3: settle + sustained glow fades (0.68..1.0)
    final p = (t - 0.68) / 0.32;
    return _FocusState(
      flash: 0.0,
      glow: 0.7 - Curves.easeInCubic.transform(p) * 0.65,
      scale: 1.0,
      sweep: 1.0,
      badge: 1.0 - Curves.easeIn.transform(p),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.recipes.isEmpty) {
      return _EmptyTabState(
        kind: widget.kind,
        query: widget.query,
        knownOnly: widget.knownOnly,
      );
    }

    final knownCount = widget.recipes
        .where((e) => widget.discoveredKeys.contains(e.pairKey))
        .length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Row(
            children: [
              Text(
                '$knownCount discovered • ${widget.recipes.length} shown',
                style: _T.label(context),
              ),
              const Spacer(),
              _KindTag(kind: widget.kind),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: widget.recipes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final recipe = widget.recipes[index];
              final rowKey = _rowKeys.putIfAbsent(
                recipe.pairKey,
                () => GlobalKey(debugLabel: 'recipe-${recipe.pairKey}'),
              );
              final focusState = _focusStateForPair(recipe.pairKey);
              return KeyedSubtree(
                key: rowKey,
                // Staggered entrance per card
                child: _AnimatedCardEntrance(
                  index: index,
                  child: _RecipeCard(
                    recipe: recipe,
                    unlocked: widget.discoveredKeys.contains(recipe.pairKey),
                    focusState: focusState,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Per-card staggered entrance ─────────────────────────────────────────────

class _AnimatedCardEntrance extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedCardEntrance({required this.index, required this.child});
  @override
  State<_AnimatedCardEntrance> createState() => _AnimatedCardEntranceState();
}

class _AnimatedCardEntranceState extends State<_AnimatedCardEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Stagger delay — cap at 8 cards worth so long lists don't lag
    final delayMs = (widget.index.clamp(0, 8) * 42);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

// ─── Focus state value object ─────────────────────────────────────────────────

class _FocusState {
  /// 0..1 — white/accent flash fill at start of reveal
  final double flash;

  /// 0..1 — overall glow intensity driving border + shadow
  final double glow;

  /// scale multiplier for the card
  final double scale;

  /// 0..1 — diagonal shimmer sweep progress across card
  final double sweep;

  /// 0..1 — "UNLOCKED" badge opacity
  final double badge;

  const _FocusState({
    required this.flash,
    required this.glow,
    required this.scale,
    required this.sweep,
    required this.badge,
  });

  const _FocusState.idle()
    : flash = 0,
      glow = 0,
      scale = 1,
      sweep = 0,
      badge = 0;

  bool get isActive => glow > 0.01 || flash > 0.01;
}

// ─── Recipe card ─────────────────────────────────────────────────────────────

class _RecipeCard extends StatelessWidget {
  final EncyclopediaRecipeEntry recipe;
  final bool unlocked;
  final _FocusState focusState;

  const _RecipeCard({
    required this.recipe,
    required this.unlocked,
    this.focusState = const _FocusState.idle(),
  });

  @override
  Widget build(BuildContext context) {
    final accent = _recipeResultColor(context, recipe);
    final fs = focusState;
    final glow = fs.glow.clamp(0.0, 1.0);
    final flash = fs.flash.clamp(0.0, 1.0);

    final pairText = unlocked
        ? '${recipe.parentA} + ${recipe.parentB}'
        : 'Unknown Parent Pair';
    final outcomeText = unlocked
        ? 'Dominant outcome ${recipe.topWeight}%'
        : 'Dominant outcome hidden';
    final resultText = unlocked ? recipe.result : '???';

    return Transform.scale(
      scale: fs.scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Base plate with amplified glow ──────────────────────────────
          _PlateFrame(
            accentColor: unlocked ? accent : accent.withValues(alpha: .38),
            highlight: unlocked || fs.isActive,
            glowBoost: glow,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      unlocked
                          ? Icons.auto_awesome_rounded
                          : Icons.help_outline,
                      size: 14,
                      color: unlocked
                          ? Color.lerp(accent, Colors.white, flash * 0.6)!
                          : accent.withValues(alpha: .58),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        pairText,
                        style: TextStyle(
                          color: unlocked
                              ? Color.lerp(
                                  _C.of(context).textPrimary,
                                  Colors.white,
                                  flash * 0.45,
                                )
                              : accent.withValues(alpha: .65),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        outcomeText,
                        style: _T
                            .body(context)
                            .copyWith(
                              fontSize: 11,
                              color: unlocked
                                  ? _C.of(context).textSecondary
                                  : _C.of(context).textMuted,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      resultText,
                      style: TextStyle(
                        color: unlocked
                            ? Color.lerp(accent, Colors.white, flash * 0.5)
                            : accent.withValues(alpha: .58),
                        fontWeight: FontWeight.w900,
                        letterSpacing: .4,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Flash burst overlay (phase 0) ───────────────────────────────
          if (flash > 0.01)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.2,
                      colors: [
                        accent.withValues(alpha: flash * 0.55),
                        Colors.white.withValues(alpha: flash * 0.18),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),

          // ── Radial glow (phases 1-3) ────────────────────────────────────
          if (glow > 0.01)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: RadialGradient(
                      center: const Alignment(0.0, 0.0),
                      radius: 1.4,
                      colors: [
                        accent.withValues(alpha: glow * 0.28),
                        accent.withValues(alpha: glow * 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),

          // ── Diagonal shimmer sweep (phase 2) ────────────────────────────
          if (fs.sweep > 0.01 && fs.sweep < 0.99)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CustomPaint(
                    painter: _ShimmerSweepPainter(
                      progress: fs.sweep,
                      color: accent,
                    ),
                  ),
                ),
              ),
            ),

          // ── "NEWLY UNLOCKED" badge ──────────────────────────────────────
          if (fs.badge > 0.01)
            Positioned(
              top: -8,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: fs.badge.clamp(0.0, 1.0),
                child: Center(
                  child: Transform.scale(
                    scale: 0.85 + fs.badge * 0.15,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.6),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(
                        '★  NEWLY UNLOCKED  ★',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.black.withValues(alpha: 0.85),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Outer ring pulse (extends beyond card bounds) ───────────────
          if (glow > 0.05)
            Positioned(
              top: -(glow * 6),
              left: -(glow * 6),
              right: -(glow * 6),
              bottom: -(glow * 6),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4 + glow * 6),
                    border: Border.all(
                      color: accent.withValues(alpha: glow * 0.4),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Diagonal shimmer sweep painter ──────────────────────────────────────────

class _ShimmerSweepPainter extends CustomPainter {
  final double progress; // 0..1, drives diagonal band position
  final Color color;

  const _ShimmerSweepPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Band sweeps diagonally from top-left to bottom-right
    final diagonal = size.width + size.height;
    final bandCenter = progress * (diagonal + 80) - 40;
    final bandHalf = 55.0;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.transparent,
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.22),
        Colors.white.withValues(alpha: 0.15),
        color.withValues(alpha: 0.22),
        color.withValues(alpha: 0.0),
        Colors.transparent,
      ],
      stops: [
        0.0,
        ((bandCenter - bandHalf) / diagonal).clamp(0.0, 1.0),
        ((bandCenter - bandHalf * 0.3) / diagonal).clamp(0.0, 1.0),
        (bandCenter / diagonal).clamp(0.0, 1.0),
        ((bandCenter + bandHalf * 0.3) / diagonal).clamp(0.0, 1.0),
        ((bandCenter + bandHalf) / diagonal).clamp(0.0, 1.0),
        1.0,
      ],
    );

    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_ShimmerSweepPainter old) =>
      old.progress != progress || old.color != color;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

Color _recipeResultColor(BuildContext context, EncyclopediaRecipeEntry recipe) {
  if (recipe.kind == EncyclopediaRecipeKind.element) {
    return BreedConstants.getTypeColor(recipe.result);
  }
  final normalized = recipe.result.trim().toLowerCase();
  for (final family in CreatureFamily.values) {
    if (family.displayName.toLowerCase() == normalized) return family.color;
  }
  return _C.of(context).amberBright;
}

// ─── Discovery stat ──────────────────────────────────────────────────────────

class _DiscoveryStat extends StatelessWidget {
  final String label;
  final int discovered, total;
  final Color color;

  const _DiscoveryStat({
    required this.label,
    required this.discovered,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : discovered / total;
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: _C.of(context).bg1,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label.toUpperCase(),
                style: _T
                    .label(context)
                    .copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                    ),
              ),
              const Spacer(),
              Text(
                '$discovered/$total',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: _C.of(context).textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _AnimatedCompletionBar(progress: progress, color: color),
        ],
      ),
    );
  }
}

// ─── Completion bar (static, used by animated wrapper) ───────────────────────

class _CompletionBar extends StatelessWidget {
  final double progress;
  final Color color;
  const _CompletionBar({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(99),
    child: SizedBox(
      height: 7,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: _C.of(context).bg3),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: .65), color],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Toggle chip ─────────────────────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: enabled
            ? _C.of(context).amber.withValues(alpha: .16)
            : _C.of(context).bg1,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: enabled
              ? _C.of(context).amberBright.withValues(alpha: .6)
              : _C.of(context).borderDim,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              enabled ? Icons.check_circle_rounded : Icons.circle_outlined,
              key: ValueKey(enabled),
              size: 12,
              color: enabled
                  ? _C.of(context).amberBright
                  : _C.of(context).textMuted,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
              color: enabled
                  ? _C.of(context).amberBright
                  : _C.of(context).textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Kind tag ────────────────────────────────────────────────────────────────

class _KindTag extends StatelessWidget {
  final EncyclopediaRecipeKind kind;
  const _KindTag({required this.kind});

  @override
  Widget build(BuildContext context) {
    final isFamily = kind == EncyclopediaRecipeKind.family;
    final color = isFamily ? _C.of(context).amberBright : _C.of(context).teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: .45), width: 0.8),
      ),
      child: Text(
        isFamily ? 'FAMILY MATRIX' : 'ELEMENT MATRIX',
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyTabState extends StatelessWidget {
  final EncyclopediaRecipeKind kind;
  final String query;
  final bool knownOnly;

  const _EmptyTabState({
    required this.kind,
    required this.query,
    required this.knownOnly,
  });

  @override
  Widget build(BuildContext context) {
    final isFamily = kind == EncyclopediaRecipeKind.family;
    final color = isFamily ? _C.of(context).amberBright : _C.of(context).teal;
    final title = query.isNotEmpty
        ? 'No known records match "$query"'
        : knownOnly
        ? 'No known ${isFamily ? 'family' : 'element'} formulas yet'
        : 'No ${isFamily ? 'family' : 'element'} formulas available';
    final subtitle = query.isNotEmpty
        ? 'Try a different parent/result name.'
        : knownOnly
        ? 'Breed more pairs to unlock this matrix.'
        : 'Recipe data for this matrix is empty.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _PlateFrame(
          accentColor: color,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_stories_rounded, color: color, size: 24),
              const SizedBox(height: 10),
              Text(
                title,
                style: _T.heading(context).copyWith(fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: _T.body(context).copyWith(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Action button ───────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _C.of(context).amber,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _C.of(context).amberGlow),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _C.of(context).bg0, size: 14),
          const SizedBox(width: 7),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              color: _C.of(context).bg0,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Plate frame ─────────────────────────────────────────────────────────────

class _PlateFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color accentColor;
  final bool highlight;
  final double glowBoost;

  const _PlateFrame({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.accentColor = const Color(0xFFD97706),
    this.highlight = false,
    this.glowBoost = 0,
  });

  @override
  Widget build(BuildContext context) {
    final boostedGlow = glowBoost.clamp(0.0, 1.0).toDouble();
    final borderAlpha = highlight ? (0.6 + boostedGlow * 0.4) : 0.18;
    final borderWidth = highlight ? (1.4 + boostedGlow * 1.2) : 1.0;
    final baseShadowAlpha = highlight ? 0.12 : 0.0;
    final shadowAlpha = baseShadowAlpha + boostedGlow * 0.45;
    final shadowBlur = 18 + boostedGlow * 40;
    final shadowSpread = boostedGlow * 4;

    return Container(
      decoration: BoxDecoration(
        color: _C.of(context).bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: highlight
              ? accentColor.withValues(alpha: borderAlpha)
              : _C.of(context).borderDim,
          width: borderWidth,
        ),
        boxShadow: (highlight || boostedGlow > 0.01)
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: shadowAlpha),
                  blurRadius: shadowBlur,
                  spreadRadius: shadowSpread,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Padding(padding: padding, child: child),
          Positioned(
            top: 0,
            left: 0,
            child: _CornerNotch(accent: accentColor, topLeft: true),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: _CornerNotch(accent: accentColor, topLeft: false),
          ),
        ],
      ),
    );
  }
}

class _CornerNotch extends StatelessWidget {
  final Color accent;
  final bool topLeft;
  const _CornerNotch({required this.accent, required this.topLeft});

  @override
  Widget build(BuildContext context) {
    final side = accent.withValues(alpha: 0.45);
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        border: topLeft
            ? Border(
                top: BorderSide(color: side, width: 1.5),
                left: BorderSide(color: side, width: 1.5),
              )
            : Border(
                bottom: BorderSide(color: side, width: 1.5),
                right: BorderSide(color: side, width: 1.5),
              ),
      ),
    );
  }
}
