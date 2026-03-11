import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/services/alchemical_encyclopedia_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AlchemicalEncyclopediaScreen extends StatefulWidget {
  const AlchemicalEncyclopediaScreen({super.key});

  @override
  State<AlchemicalEncyclopediaScreen> createState() =>
      _AlchemicalEncyclopediaScreenState();
}

class _AlchemicalEncyclopediaScreenState
    extends State<AlchemicalEncyclopediaScreen> {
  late Future<AlchemicalEncyclopediaSnapshot> _snapshotFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showKnownOnly = false;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = AlchemicalEncyclopediaService.loadSnapshot(
      db: context.read<AlchemonsDatabase>(),
    );
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
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

                return DefaultTabController(
                  length: 2,
                  child: Column(
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
                          hasSearchQuery: _searchQuery.isNotEmpty,
                          showKnownOnly: _showKnownOnly,
                          onToggleKnownOnly: () {
                            setState(() => _showKnownOnly = !_showKnownOnly);
                          },
                          onClearSearch: () => _searchController.clear(),
                        ),
                      ),
                      _RecipeTabBar(
                        familyCount: visibleFamily.length,
                        elementCount: visibleElement.length,
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _RecipeTabList(
                              kind: EncyclopediaRecipeKind.family,
                              recipes: visibleFamily,
                              discoveredKeys: data.discoveredFamilyKeys,
                              query: _searchQuery,
                              knownOnly: _showKnownOnly,
                            ),
                            _RecipeTabList(
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _C {
  final Color bg0;
  final Color bg1;
  final Color bg2;
  final Color bg3;

  final Color amber;
  final Color amberBright;
  final Color amberGlow;
  final Color teal;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color borderDim;
  final Color borderAccent;

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

class _ScorchedLoading extends StatelessWidget {
  const _ScorchedLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: _C.of(context).amberBright),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  final VoidCallback onRetry;
  const _LoadFailure({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
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
                style: _T
                    .body(context)
                    .copyWith(color: _C.of(context).textMuted),
              ),
              const SizedBox(height: 12),
              _ActionButton(
                label: 'Retry',
                icon: Icons.refresh,
                onTap: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForgeBackdrop extends StatelessWidget {
  const _ForgeBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
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
                    _StatusDot(),
                    SizedBox(width: 8),
                    Text('ALCHEMICAL ENCYCLOPEDIA', style: _T.heading(context)),
                  ],
                ),
                SizedBox(height: 1),
                Text('DOMINANT EXTRACTION RECORDS', style: _T.label(context)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _C.of(context).bg2,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: _C.of(context).borderAccent.withValues(alpha: .75),
              ),
            ),
            child: Text(
              '$percent%',
              style: TextStyle(
                fontFamily: 'monospace',
                color: _C.of(context).amberBright,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  final int totalDiscovered;
  final int totalRecipes;
  final int discoveredFamily;
  final int totalFamily;
  final int discoveredElement;
  final int totalElement;

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
                    Text(
                      '$totalDiscovered / $totalRecipes formulas recovered',
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
          _CompletionBar(
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

class _FilterPanel extends StatelessWidget {
  final TextEditingController controller;
  final bool hasSearchQuery;
  final bool showKnownOnly;
  final VoidCallback onToggleKnownOnly;
  final VoidCallback onClearSearch;

  const _FilterPanel({
    required this.controller,
    required this.hasSearchQuery,
    required this.showKnownOnly,
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
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: _C.of(context).bg1,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: _C.of(context).borderDim),
            ),
            child: TextField(
              controller: controller,
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
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: _C.of(context).textSecondary,
                  size: 18,
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

class _RecipeTabBar extends StatelessWidget {
  final int familyCount;
  final int elementCount;

  const _RecipeTabBar({required this.familyCount, required this.elementCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _C.of(context).bg1,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _C.of(context).borderDim),
      ),
      child: TabBar(
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
}

class _RecipeTabList extends StatelessWidget {
  final EncyclopediaRecipeKind kind;
  final List<EncyclopediaRecipeEntry> recipes;
  final Set<String> discoveredKeys;
  final String query;
  final bool knownOnly;

  const _RecipeTabList({
    required this.kind,
    required this.recipes,
    required this.discoveredKeys,
    required this.query,
    required this.knownOnly,
  });

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return _EmptyTabState(kind: kind, query: query, knownOnly: knownOnly);
    }

    final knownCount = recipes
        .where((entry) => discoveredKeys.contains(entry.pairKey))
        .length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Row(
            children: [
              Text(
                '$knownCount discovered • ${recipes.length} shown',
                style: _T.label(context),
              ),
              const Spacer(),
              _KindTag(kind: kind),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: recipes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return _RecipeCard(
                recipe: recipe,
                unlocked: discoveredKeys.contains(recipe.pairKey),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final EncyclopediaRecipeEntry recipe;
  final bool unlocked;

  const _RecipeCard({required this.recipe, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final accent = _recipeResultColor(context, recipe);
    final pairText = unlocked
        ? '${recipe.parentA} + ${recipe.parentB}'
        : 'Unknown Parent Pair';
    final outcomeText = unlocked
        ? 'Dominant outcome ${recipe.topWeight}%'
        : 'Dominant outcome hidden';
    final resultText = unlocked ? recipe.result : '???';

    return _PlateFrame(
      accentColor: unlocked ? accent : accent.withValues(alpha: .38),
      highlight: unlocked,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                unlocked ? Icons.auto_awesome_rounded : Icons.help_outline,
                size: 14,
                color: unlocked ? accent : accent.withValues(alpha: .58),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  pairText,
                  style: TextStyle(
                    color: unlocked
                        ? _C.of(context).textPrimary
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
                  color: unlocked ? accent : accent.withValues(alpha: .58),
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _recipeResultColor(BuildContext context, EncyclopediaRecipeEntry recipe) {
  if (recipe.kind == EncyclopediaRecipeKind.element) {
    return BreedConstants.getTypeColor(recipe.result);
  }

  final normalized = recipe.result.trim().toLowerCase();
  for (final family in CreatureFamily.values) {
    if (family.displayName.toLowerCase() == normalized) {
      return family.color;
    }
  }

  return _C.of(context).amberBright;
}

class _DiscoveryStat extends StatelessWidget {
  final String label;
  final int discovered;
  final int total;
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
          _CompletionBar(progress: progress, color: color),
        ],
      ),
    );
  }
}

class _CompletionBar extends StatelessWidget {
  final double progress;
  final Color color;

  const _CompletionBar({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    final widthFactor = progress.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 7,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: _C.of(context).bg3),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: widthFactor,
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
}

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
  Widget build(BuildContext context) {
    return GestureDetector(
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
            Icon(
              enabled ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 12,
              color: enabled
                  ? _C.of(context).amberBright
                  : _C.of(context).textMuted,
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
}

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

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: _C.of(context).amberBright,
        shape: BoxShape.circle,
      ),
    );
  }
}

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
  Widget build(BuildContext context) {
    return GestureDetector(
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
}

class _PlateFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color accentColor;
  final bool highlight;

  const _PlateFrame({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.accentColor = const Color(0xFFD97706),
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.of(context).bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: highlight
              ? accentColor.withValues(alpha: 0.6)
              : _C.of(context).borderDim,
          width: highlight ? 1.4 : 1,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.12),
                  blurRadius: 18,
                  spreadRadius: 0,
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
