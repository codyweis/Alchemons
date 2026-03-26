// lib/screens/creatures_screen.dart
//
// REDESIGNED CREATURES SCREEN
// Aesthetic: Scorched Forge — dark metal chrome, amber reagent accents, monospace
// All sliver structure, filtering, sorting, routing, tutorial logic preserved.
// Public widget APIs (SectionCard, ProgressBar, SearchFieldSolid, etc.) preserved.
//

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/screens/breeding_milestones_screen.dart';
import 'package:alchemons/screens/progress_overview_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/utils/game_data_gate.dart';
import 'package:alchemons/widgets/all_specimens_page.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/bottom_sheet_shell.dart';
import 'package:alchemons/widgets/creature_image.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/loading_widget.dart';
import 'package:alchemons/widgets/silhouette_widget.dart';
import 'package:flame/image_composition.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';

import '../models/creature.dart';

// ──────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ──────────────────────────────────────────────────────────────────────────────

class _C {
  // Only textPrimary/textSecondary remain — used by _T static const TextStyles.
  static const textSecondary = Color(0xFF8A7B6A);
}

class _T {
  static const heading = TextStyle(
    fontFamily: 'monospace',
    color: Color.fromARGB(255, 67, 67, 67),
    fontSize: 13,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.0,
  );

  static const label = TextStyle(
    fontFamily: 'monospace',
    color: _C.textSecondary,
    fontSize: 9,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
  );
}

Color _rarityColorForge(String rarity) => switch (rarity.toLowerCase()) {
  'common' => const Color(0xFF6B7280),
  'uncommon' => const Color(0xFF34D399),
  'rare' => const Color(0xFF60A5FA),
  'mythic' => const Color(0xFFA855F7),
  'legendary' => const Color(0xFFF59E0B),
  _ => const Color(0xFF6B7280),
};

// ──────────────────────────────────────────────────────────────────────────────
// SCREEN STATE
// ──────────────────────────────────────────────────────────────────────────────

class CreaturesScreen extends StatefulWidget {
  const CreaturesScreen({super.key});

  @override
  State<CreaturesScreen> createState() => CreaturesScreenState();
}

class CreaturesScreenState extends State<CreaturesScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  void unfocusSearch() {
    _searchFocus.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Timer? _debounce;
  StreamSubscription<Map<String, int>>? _instanceCountsSub;
  Map<String, int> _instanceCounts = const {};

  bool _creaturesTutorialChecked = false;
  bool _highlightAllInstances = false;
  bool _tutorialScheduled = false;
  bool _showCatalogView = false;

  String _scope = 'Catalogued';
  String _sort = 'Acquisition Order';
  bool _isGrid = true;
  bool _showCounts = true;
  String _query = '';
  String? _typeFilter;

  late SettingsDao _settings;
  Timer? _saveTimer;

  static const _prefsKey = 'creatures_screen_prefs_v1';

  Map<String, dynamic> _toPrefs() => {
    'scope': _scope,
    'sort': _sort,
    'isGrid': _isGrid,
    'showCounts': _showCounts,
    'query': _query,
    'typeFilter': _typeFilter,
  };

  void _fromPrefs(Map<String, dynamic> p) {
    _scope = (p['scope'] as String?) ?? _scope;
    _sort = (p['sort'] as String?) ?? _sort;
    _isGrid = (p['isGrid'] as bool?) ?? _isGrid;
    _showCounts = (p['showCounts'] as bool?) ?? _showCounts;
    _query = (p['query'] as String?) ?? _query;
    _typeFilter = p['typeFilter'] as String?;
    _searchCtrl.text = _query;
  }

  void _queueSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () async {
      await _settings.setSetting(_prefsKey, jsonEncode(_toPrefs()));
    });
  }

  void _mutate(VoidCallback fn) {
    setState(fn);
    _queueSave();
  }

  void _cycleScope() {
    const scopes = ['All', 'Catalogued', 'Unknown'];
    _mutate(() {
      _scope = scopes[(scopes.indexOf(_scope) + 1) % scopes.length];
    });
  }

  void _cycleSort() {
    const options = [
      'Name',
      'Classification',
      'Type',
      'Count',
      'Acquisition Order',
    ];
    _mutate(() {
      _sort = options[(options.indexOf(_sort) + 1) % options.length];
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settings = context.read<AlchemonsDatabase>().settingsDao;
    _bindInstanceCounts();
    () async {
      final raw = await _settings.getSetting(_prefsKey);
      if (!mounted || raw == null || raw.isEmpty) return;
      setState(() => _fromPrefs(jsonDecode(raw) as Map<String, dynamic>));
    }();
    if (!_tutorialScheduled) _tutorialScheduled = true;
  }

  void _bindInstanceCounts() {
    if (_instanceCountsSub != null) return;
    final db = context.read<AlchemonsDatabase>();
    _instanceCountsSub = db.creatureDao.watchInstanceCountsBySpecies().listen((
      next,
    ) {
      if (!mounted) return;
      if (_mapEquals(_instanceCounts, next)) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _instanceCounts = Map<String, int>.from(next));
      });
    });
  }

  bool _mapEquals(Map<String, int> a, Map<String, int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  Future<void> maybeShowCreaturesTutorial() => _maybeShowCreaturesTutorial();

  Future<void> _maybeShowCreaturesTutorial() async {
    if (!mounted || _creaturesTutorialChecked) return;
    _creaturesTutorialChecked = true;
    final t = ForgeTokens(context.read<FactionTheme>());
    final hasSeen = await _settings.hasSeenCreaturesTutorial();
    if (hasSeen || !mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: t.bg1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: t.borderAccent, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 16,
                    color: t.amber,
                    margin: const EdgeInsets.only(right: 10),
                  ),
                  const Text('ALCHEMON DATABASE', style: _T.heading),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Browse every species you\'ve discovered, filter them, '
                'and inspect individual specimens.',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: t.textSecondary,
                  fontSize: 10,
                  letterSpacing: 0.3,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              _TutorialRow(
                icon: Icons.search_rounded,
                title: 'SEARCH & FILTER',
                body:
                    'Use the search bar and chips to filter by name, '
                    'type, rarity, and more.',
              ),
              const SizedBox(height: 8),
              _TutorialRow(
                icon: Icons.category_rounded,
                title: 'SPECIES CATALOG',
                body:
                    'Use the top-left button to switch to the species catalog, '
                    'then tap a species to view its specimens and details.',
              ),
              const SizedBox(height: 8),
              _TutorialRow(
                icon: Icons.grid_view_rounded,
                title: 'ALL SPECIMENS VIEW',
                body:
                    'This screen now opens on the full specimen list by '
                    'default. Use the top-left button to switch between '
                    'specimens and species.',
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: t.amberDim.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: t.borderAccent),
                  ),
                  child: Center(
                    child: Text(
                      'UNDERSTOOD',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: t.amberBright,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
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

    if (!mounted) return;
    await _settings.setCreaturesTutorialSeen();
    if (!mounted) return;
    setState(() => _highlightAllInstances = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _highlightAllInstances = false);
    });
  }

  @override
  void dispose() {
    _instanceCountsSub?.cancel();
    _saveTimer?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return withGameData(
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
            final total = entries.length;
            final discoveredCount = discovered.length;
            final pct = total == 0
                ? 0.0
                : (discoveredCount / total).clamp(0.0, 1.0);

            final filtered = _filterAndSort(entries, _instanceCounts);

            if (!_showCatalogView) {
              return AllSpecimensPage(
                theme: theme,
                showFloatingCloseButton: false,
                leadingIcon: Icons.category_rounded,
                leadingTooltip: 'Species Catalog',
                onLeadingTap: () {
                  unfocusSearch();
                  setState(() => _showCatalogView = true);
                },
                onInstanceTap: (inst) {
                  final creature = context
                      .read<CreatureCatalog>()
                      .getCreatureById(inst.baseId);
                  if (creature != null) {
                    _openDetailsForInstance(creature, inst);
                  }
                },
              );
            }

            return ParticleBackgroundScaffold(
              whiteBackground: theme.brightness == Brightness.light,
              body: Scaffold(
                backgroundColor: Colors.transparent,
                body: SafeArea(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      _SolidHeader(
                        theme: theme,
                        highlightAllInstances: _highlightAllInstances,
                        onOpenAllInstances: () {
                          unfocusSearch();
                          setState(() => _showCatalogView = false);
                        },
                      ),
                      SliverToBoxAdapter(
                        child: _StatsHeaderSolid(
                          theme: theme,
                          percent: pct,
                          discovered: discoveredCount,
                          total: total,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _FilterBarSolid(
                          theme: theme,
                          query: _query,
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          scope: _scope,
                          sort: _sort,
                          isGrid: _isGrid,
                          showCounts: _showCounts,
                          onQueryChanged: _onQueryChanged,
                          onScopeChanged: _cycleScope,
                          onSortTap: _cycleSort,
                          onToggleView: () => _mutate(() => _isGrid = !_isGrid),
                          onToggleCounts: () =>
                              _mutate(() => _showCounts = !_showCounts),
                        ),
                      ),
                      if (filtered.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyState(theme: theme),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(1, 0, 1, 16),
                          sliver: _isGrid
                              ? _CreatureGrid(
                                  theme: theme,
                                  creatures: filtered,
                                  showCounts: _showCounts,
                                  instanceCounts: _instanceCounts,
                                  onTap: (c, isDiscovered) =>
                                      _handleTap(c, isDiscovered, theme),
                                )
                              : _CreatureList(
                                  theme: theme,
                                  creatures: filtered,
                                  showCounts: _showCounts,
                                  instanceCounts: _instanceCounts,
                                  onTap: (c, isDiscovered) =>
                                      _handleTap(c, isDiscovered, theme),
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

  // ── LOGIC (unchanged) ──────────────────────────────────────────────────────

  void _onQueryChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _mutate(() => _query = text.trim());
    });
  }

  void _handleTap(Creature species, bool isDiscovered, FactionTheme theme) {
    unfocusSearch();
    if (isDiscovered) {
      _showInstancesSheet(species, theme);
    } else {
      _showSilhouettePopup(species, theme);
    }
  }

  void _showSilhouettePopup(Creature species, FactionTheme theme) {
    final t = ForgeTokens(theme);
    final spriteData = species.spriteData;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            decoration: BoxDecoration(
              color: t.bg1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.borderDim, width: 1.5),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Silhouette image
                SizedBox(
                  height: 320,
                  width: double.infinity,
                  child: Center(
                    child: Silhouette(
                      enabled: true,
                      child: spriteData != null
                          ? SizedBox(
                              width: 260,
                              height: 260,
                              child: CreatureSprite(
                                spritePath: spriteData.spriteSheetPath,
                                totalFrames: spriteData.totalFrames,
                                rows: spriteData.rows,
                                frameSize: Vector2(
                                  spriteData.frameWidth.toDouble(),
                                  spriteData.frameHeight.toDouble(),
                                ),
                                stepTime: spriteData.frameDurationMs / 1000.0,
                              ),
                            )
                          : SizedBox(
                              width: 260,
                              height: 260,
                              child: CreatureImage(
                                c: species,
                                discovered: false,
                                rounded: 6,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'UNKNOWN SPECIMEN',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Classification data unavailable.\nDiscover this species to reveal its true form.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                _RarityPill(rarity: 'CLASS ?'),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: t.borderDim.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: t.borderDim),
                    ),
                    child: Center(
                      child: Text(
                        'CLOSE',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: t.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
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

  List<CreatureEntry> _filterAndSort(
    List<CreatureEntry> all,
    Map<String, int> instanceCounts,
  ) {
    final scoped = all.where((m) {
      final isDiscovered = m.player.discovered == true;
      return switch (_scope) {
        'Catalogued' => isDiscovered,
        'Unknown' => !isDiscovered,
        _ => true,
      };
    });
    final q = _query.toLowerCase();
    final searched = q.isEmpty
        ? scoped
        : scoped.where((m) {
            final c = m.creature;
            return c.id.toLowerCase().contains(q) ||
                c.name.toLowerCase().contains(q) ||
                c.types.any((t) => t.toLowerCase().contains(q)) ||
                c.rarity.toLowerCase().contains(q);
          });
    final list = searched.toList();
    list.sort((a, b) {
      final A = a.creature;
      final B = b.creature;
      return switch (_sort) {
        'Name' => A.name.compareTo(B.name),
        'Classification' => _rarityRank(
          A.rarity,
        ).compareTo(_rarityRank(B.rarity)),
        'Type' => A.types.first.compareTo(B.types.first),
        'Count' => () {
          final diff = (instanceCounts[B.id] ?? 0).compareTo(
            instanceCounts[A.id] ?? 0,
          );
          return diff != 0 ? diff : A.name.compareTo(B.name);
        }(),
        'Acquisition Order' => () {
          final ad = a.player.discovered == true;
          final bd = b.player.discovered == true;
          if (ad && !bd) return -1;
          if (!ad && bd) return 1;
          return A.name.compareTo(B.name);
        }(),
        _ => 0,
      };
    });
    return list;
  }

  int _rarityRank(String rarity) => switch (rarity.toLowerCase()) {
    'common' => 0,
    'uncommon' => 1,
    'rare' => 2,
    'mythic' => 3,
    'legendary' => 4,
    _ => 0,
  };

  void _showInstancesSheet(Creature species, FactionTheme theme) {
    unfocusSearch();
    final t = ForgeTokens(theme);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BottomSheetShell(
        theme: theme,
        titleAction: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BreedingMilestoneScreen(speciesId: species.id),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: t.bg3,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: t.borderDim),
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.emoji_nature_rounded,
              size: 18,
              color: t.textSecondary,
            ),
          ),
        ),
        title: '${species.name} Specimens',
        child: InstancesSheet(
          species: species,
          theme: theme,
          onTap: (inst) {
            Navigator.of(context).pop();
            _openDetailsForInstance(species, inst);
          },
        ),
      ),
    );
  }

  void _openDetailsForInstance(Creature species, CreatureInstance inst) {
    unfocusSearch();
    CreatureDetailsDialog.show(
      context,
      species,
      true,
      instanceId: inst.instanceId,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// HEADER
// ──────────────────────────────────────────────────────────────────────────────

class _SolidHeader extends StatelessWidget {
  final FactionTheme theme;
  final bool highlightAllInstances;
  final VoidCallback onOpenAllInstances;

  const _SolidHeader({
    required this.theme,
    required this.onOpenAllInstances,
    this.highlightAllInstances = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return SliverAppBar(
      pinned: false,
      elevation: 0,
      backgroundColor: t.bg1,
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: t.bg1,
          border: Border(bottom: BorderSide(color: t.borderDim)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            // All instances button — highlights briefly after tutorial
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: highlightAllInstances
                    ? t.amber.withValues(alpha: 0.15)
                    : t.bg2,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: highlightAllInstances ? t.borderAccent : t.borderDim,
                  width: highlightAllInstances ? 1.5 : 1.0,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(3),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onOpenAllInstances();
                  },
                  child: Center(
                    child: Icon(
                      Icons.grid_view_rounded,
                      size: 18,
                      color: highlightAllInstances
                          ? t.amberBright
                          : t.textSecondary,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Title
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(right: 7, bottom: 1),
                        decoration: BoxDecoration(
                          color: t.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Text('ALCHEMON DATABASE', style: _T.heading),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text('SPECIMEN CATALOGUING SYSTEM', style: _T.label),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Constellation button
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ConstellationProgressOverviewScreen(),
                ),
              ),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: t.amberDim.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: t.borderAccent),
                ),
                child: Icon(
                  Icons.show_chart_rounded,
                  size: 18,
                  color: t.amberBright,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// STATS HEADER
// ──────────────────────────────────────────────────────────────────────────────

class _StatsHeaderSolid extends StatelessWidget {
  final FactionTheme theme;
  final double percent;
  final int discovered;
  final int total;
  const _StatsHeaderSolid({
    required this.theme,
    required this.percent,
    required this.discovered,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return SectionCard(
      theme: theme,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Arc progress indicator — amber fill
          SizedBox(
            width: 54,
            height: 54,
            child: CustomPaint(
              painter: _ArcPainter(
                progress: percent,
                color: t.amberBright,
                trackColor: t.borderMid,
              ),
              child: Center(
                child: Text(
                  '$discovered',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'DISCOVERY PROGRESS',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: t.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$discovered / $total',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: t.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ProgressBar(theme: theme, value: percent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// FILTER BAR
// ──────────────────────────────────────────────────────────────────────────────

class _FilterBarSolid extends StatelessWidget {
  final FactionTheme theme;
  final String query;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String scope;
  final String sort;
  final bool isGrid;
  final bool showCounts;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onScopeChanged;
  final VoidCallback onSortTap;
  final VoidCallback onToggleView;
  final VoidCallback onToggleCounts;

  const _FilterBarSolid({
    required this.theme,
    required this.query,
    required this.controller,
    this.focusNode,
    required this.scope,
    required this.sort,
    required this.isGrid,
    required this.showCounts,
    required this.onQueryChanged,
    required this.onScopeChanged,
    required this.onSortTap,
    required this.onToggleView,
    required this.onToggleCounts,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      theme: theme,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: SearchFieldSolid(
                  theme: theme,
                  controller: controller,
                  focusNode: focusNode,
                  hint: 'SEARCH ALCHEMONS...',
                  onChanged: onQueryChanged,
                ),
              ),
              const SizedBox(width: 4),
              PillButton(
                theme: theme,
                label: scope.toUpperCase(),
                icon: Icons.filter_list_rounded,
                onTap: onScopeChanged,
              ),
              const SizedBox(width: 4),
              IconButtonSolid(
                theme: theme,
                icon: showCounts
                    ? Icons.numbers_rounded
                    : Icons.numbers_outlined,
                onTap: onToggleCounts,
              ),
              const SizedBox(width: 4),
              IconButtonSolid(
                theme: theme,
                icon: isGrid
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded,
                onTap: onToggleView,
              ),
              const SizedBox(width: 4),
              IconButtonSolid(
                theme: theme,
                icon: Icons.sort_rounded,
                onTap: onSortTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// GRID / LIST
// ──────────────────────────────────────────────────────────────────────────────

class _CreatureGrid extends StatelessWidget {
  final FactionTheme theme;
  final List<CreatureEntry> creatures;
  final bool showCounts;
  final Map<String, int> instanceCounts;
  final void Function(Creature, bool) onTap;
  const _CreatureGrid({
    required this.theme,
    required this.creatures,
    required this.showCounts,
    required this.instanceCounts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        childAspectRatio: .88,
      ),
      delegate: SliverChildBuilderDelegate((ctx, i) {
        final data = creatures[i];
        final c = data.creature;
        final isDiscovered = data.player.discovered == true;
        return _CreatureCard(
          key: ValueKey<String>('species:${c.id}'),
          theme: theme,
          c: c,
          discovered: isDiscovered,
          instanceCount: instanceCounts[c.id] ?? 0,
          showCount: showCounts,
          onTap: () => onTap(c, isDiscovered),
        );
      }, childCount: creatures.length),
    );
  }
}

class _CreatureList extends StatelessWidget {
  final FactionTheme theme;
  final List<CreatureEntry> creatures;
  final bool showCounts;
  final Map<String, int> instanceCounts;
  final void Function(Creature, bool) onTap;
  const _CreatureList({
    required this.theme,
    required this.creatures,
    required this.showCounts,
    required this.instanceCounts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((ctx, i) {
        final data = creatures[i];
        final c = data.creature;
        final isDiscovered = data.player.discovered == true;
        return Padding(
          padding: const EdgeInsets.only(bottom: 1),
          child: _CreatureRow(
            key: ValueKey<String>('species:${c.id}'),
            theme: theme,
            c: c,
            discovered: isDiscovered,
            instanceCount: instanceCounts[c.id] ?? 0,
            showCount: showCounts,
            onTap: () => onTap(c, isDiscovered),
          ),
        );
      }, childCount: creatures.length),
    );
  }
}

class _CreatureCard extends StatelessWidget {
  final FactionTheme theme;
  final Creature c;
  final bool discovered;
  final int instanceCount;
  final bool showCount;
  final VoidCallback onTap;
  const _CreatureCard({
    super.key,
    required this.theme,
    required this.c,
    required this.discovered,
    required this.instanceCount,
    required this.showCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    final spriteData = c.spriteData;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: t.bg2),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Silhouette(
                        enabled: !discovered,
                        child: RepaintBoundary(
                          child: spriteData != null
                              ? CreatureSprite(
                                  spritePath: spriteData.spriteSheetPath,
                                  totalFrames: spriteData.totalFrames,
                                  rows: spriteData.rows,
                                  frameSize: Vector2(
                                    spriteData.frameWidth.toDouble(),
                                    spriteData.frameHeight.toDouble(),
                                  ),
                                  stepTime: spriteData.frameDurationMs / 1000.0,
                                )
                              : CreatureImage(
                                  c: c,
                                  discovered: discovered,
                                  rounded: 3,
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    discovered ? c.name : 'Unknown',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: discovered ? t.textPrimary : t.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _RarityPill(rarity: discovered ? c.rarity : 'CLASS ?'),
                  const SizedBox(height: 3),
                ],
              ),
            ),
            if (showCount && discovered && instanceCount > 0)
              Positioned(
                top: 4,
                right: 4,
                child: _CountBadge(theme: theme, count: instanceCount),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreatureRow extends StatelessWidget {
  final FactionTheme theme;
  final Creature c;
  final bool discovered;
  final int instanceCount;
  final bool showCount;
  final VoidCallback onTap;
  const _CreatureRow({
    super.key,
    required this.theme,
    required this.c,
    required this.discovered,
    required this.instanceCount,
    required this.showCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    final spriteData = c.spriteData;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: t.bg2,
          border: Border.all(color: t.borderDim),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Sprite plate
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: t.bg3,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: t.borderDim),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Silhouette(
                        enabled: !discovered,
                        child: RepaintBoundary(
                          child: spriteData != null
                              ? CreatureSprite(
                                  spritePath: spriteData.spriteSheetPath,
                                  totalFrames: spriteData.totalFrames,
                                  rows: spriteData.rows,
                                  frameSize: Vector2(
                                    spriteData.frameWidth.toDouble(),
                                    spriteData.frameHeight.toDouble(),
                                  ),
                                  stepTime: spriteData.frameDurationMs / 1000.0,
                                )
                              : CreatureImage(
                                  c: c,
                                  discovered: discovered,
                                  rounded: 3,
                                  size: 42,
                                ),
                        ),
                      ),
                    ),
                    if (showCount && discovered && instanceCount > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: _CountBadge(
                          theme: theme,
                          count: instanceCount,
                          small: true,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      discovered ? c.name.toUpperCase() : 'UNKNOWN SPECIMEN',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: discovered ? t.textPrimary : t.textMuted,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (discovered)
                      Row(
                        children: [
                          Wrap(
                            spacing: 5,
                            runSpacing: 3,
                            children: c.types
                                .take(2)
                                .map((t) => _TypeTiny(label: t))
                                .toList(),
                          ),
                          const SizedBox(width: 8),
                          _RarityPill(rarity: c.rarity, small: true),
                        ],
                      )
                    else
                      Text(
                        '— —',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: t.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: t.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// PUBLIC SHARED WIDGETS
// ──────────────────────────────────────────────────────────────────────────────

/// Section card — thin wrapper used by filter bar + stats header.
class SectionCard extends StatelessWidget {
  final FactionTheme theme;
  final EdgeInsets padding;
  final Widget child;
  const SectionCard({
    super.key,
    required this.theme,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return Container(
      color: t.bg1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 6, 5, 4),
        child: Container(padding: padding, child: child),
      ),
    );
  }
}

/// Slim progress bar — amber fill by default.
class ProgressBar extends StatelessWidget {
  final FactionTheme theme;
  final double value;
  const ProgressBar({super.key, required this.theme, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    final v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: LayoutBuilder(
          builder: (context, constraints) {
            double w = constraints.maxWidth * v;
            if (v > 0 && w < 2) w = 2;
            return Stack(
              children: [
                Positioned.fill(child: Container(color: t.borderMid)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: w,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: t.amberBright,
                      boxShadow: [
                        BoxShadow(
                          color: t.amber.withValues(alpha: 0.4),
                          blurRadius: 4,
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
    );
  }
}

/// Search field.
class SearchFieldSolid extends StatelessWidget {
  final FactionTheme theme;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  const SearchFieldSolid({
    super.key,
    required this.theme,
    required this.controller,
    this.focusNode,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: t.borderDim),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Icon(Icons.search_rounded, color: t.textMuted, size: 16),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.textPrimary,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  fontFamily: 'monospace',
                  color: t.textMuted,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 0,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.close_rounded, color: t.textMuted, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}

/// Icon-only button.
class IconButtonSolid extends StatelessWidget {
  final FactionTheme theme;
  final IconData icon;
  final VoidCallback onTap;
  const IconButtonSolid({
    super.key,
    required this.theme,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: t.bg2,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: t.borderDim),
        ),
        child: Icon(icon, color: t.textSecondary, size: 16),
      ),
    );
  }
}

/// Pill button (scope toggle etc).
class PillButton extends StatelessWidget {
  final FactionTheme theme;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const PillButton({
    super.key,
    required this.theme,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: t.amberDim.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: t.borderAccent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: t.amberBright),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.amberBright,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SMALL PRIVATE WIDGETS
// ──────────────────────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final int count;
  final bool small;
  final FactionTheme theme;
  const _CountBadge({
    required this.count,
    required this.theme,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 4 : 5,
        vertical: small ? 2 : 2,
      ),
      decoration: BoxDecoration(
        color: t.amberDim,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontFamily: 'monospace',
          color: t.bg0,
          fontSize: small ? 8 : 9,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }
}

class _RarityPill extends StatelessWidget {
  final String rarity;
  final bool small;
  const _RarityPill({required this.rarity, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = _rarityColorForge(rarity);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 5 : 7,
        vertical: small ? 2 : 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        rarity.toUpperCase(),
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontSize: small ? 7 : 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _TypeTiny extends StatelessWidget {
  final String label;
  const _TypeTiny({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = BreedConstants.getTypeColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        maxLines: 1,
        overflow: TextOverflow.visible,
      ),
    );
  }
}

// Tutorial step row used in the tutorial dialog
class _TutorialRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _TutorialRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: t.bg3,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: t.borderDim),
          ),
          child: Icon(icon, color: t.amberBright, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: t.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: t.textSecondary,
                  fontSize: 9,
                  letterSpacing: 0.2,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// ARC PAINTER  (unchanged logic, amber color injected)
// ──────────────────────────────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  _ArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = (size.shortestSide / 2) - 4;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 7
        ..color = trackColor,
    );

    final sweep = progress.clamp(0.0, 1.0) * math.pi * 2;

    // Glow
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.25),
    );

    // Fill
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + math.pi * 2,
          colors: [
            color.withValues(alpha: 0.3),
            color,
            color.withValues(alpha: 0.9),
          ],
          stops: const [0, .7, 1],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.progress != progress || old.color != color;
}

// ──────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ──────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final FactionTheme theme;
  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: t.bg2,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: t.borderAccent.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 30,
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'NO MATCHING SPECIMENS',
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different search, adjust filters,\nor clear the type chip.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.textSecondary,
                fontSize: 10,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
