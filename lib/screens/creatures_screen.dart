import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/utils/creature_filter_util.dart';
import 'package:alchemons/utils/game_data_gate.dart';
import 'package:alchemons/widgets/all_instaces_grid.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/bottom_sheet_shell.dart';
import 'package:alchemons/widgets/creature_image.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/draggable_sheet.dart';
import 'package:alchemons/widgets/filterchip_solod.dart';
import 'package:alchemons/widgets/loading_widget.dart';
import 'package:alchemons/widgets/silhouette_widget.dart';
import 'package:alchemons/widgets/tutorial_step.dart';
import 'package:flame/image_composition.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/utils/faction_util.dart'; // FactionTheme
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/widgets/creature_dialog.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';

import '../models/creature.dart';
import '../providers/app_providers.dart';

class CreaturesScreen extends StatefulWidget {
  const CreaturesScreen({super.key});

  @override
  State<CreaturesScreen> createState() => CreaturesScreenState();
}

class CreaturesScreenState extends State<CreaturesScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  // NEW: tutorial state
  bool _creaturesTutorialChecked = false;
  bool _highlightAllInstances = false;
  bool _tutorialScheduled = false;

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
    'scope': _scope, // 'All' | 'Catalogued' | 'Unknown'
    'sort': _sort, // 'Name' | 'Classification' | 'Type' | 'Acquisition Order'
    'isGrid': _isGrid, // bool
    'showCounts': _showCounts, // bool
    'query': _query, // String
    'typeFilter': _typeFilter, // String? (null == All)
  };

  void _fromPrefs(Map<String, dynamic> p) {
    _scope = (p['scope'] as String?) ?? _scope;
    _sort = (p['sort'] as String?) ?? _sort;
    _isGrid = (p['isGrid'] as bool?) ?? _isGrid;
    _showCounts = (p['showCounts'] as bool?) ?? _showCounts;
    _query = (p['query'] as String?) ?? _query;
    _typeFilter = p['typeFilter'] as String?;
    // sync controller with restored query (without re-triggering debounce)
    _searchCtrl.text = _query;
  }

  void _queueSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () async {
      await _settings.setSetting(_prefsKey, jsonEncode(_toPrefs()));
    });
  }

  /// Wrap setState so any change gets persisted with debounce
  void _mutate(VoidCallback fn) {
    setState(fn);
    _queueSave();
  }

  void _cycleScope() {
    const scopes = ['All', 'Catalogued', 'Unknown'];
    final currentIndex = scopes.indexOf(_scope);
    final nextIndex = (currentIndex + 1) % scopes.length;
    _mutate(() {
      _scope = scopes[nextIndex];
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

    final currentIndex = options.indexOf(_sort);
    final nextIndex = (currentIndex + 1) % options.length;

    _mutate(() {
      _sort = options[nextIndex];
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settings = context.read<AlchemonsDatabase>().settingsDao;

    // Restore prefs
    () async {
      final raw = await _settings.getSetting(_prefsKey);
      if (!mounted || raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      setState(() => _fromPrefs(map)); // no save during restore
    }();

    // NEW: schedule tutorial once
    if (!_tutorialScheduled) {
      _tutorialScheduled = true;
    }
  }

  Future<void> maybeShowCreaturesTutorial() async {
    await _maybeShowCreaturesTutorial();
  }

  Future<void> _maybeShowCreaturesTutorial() async {
    if (!mounted || _creaturesTutorialChecked) return;
    _creaturesTutorialChecked = true;

    final hasSeen = await _settings.hasSeenCreaturesTutorial();
    if (hasSeen || !mounted) return;

    final theme = context.read<FactionTheme>();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Text(
                'Alchemon Database',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Browse every species you\'ve discovered, filter them, and inspect individual specimens.',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TutorialStep(
                theme: theme,
                icon: Icons.search_rounded,
                title: 'Search & filter',
                body:
                    'Use the search bar and chips to filter by name, type, '
                    'rarity, and more.',
              ),
              const SizedBox(height: 6),
              TutorialStep(
                theme: theme,
                icon: Icons.category_rounded,
                title: 'Tap a species',
                body:
                    'Tap a species to view its specimens, animations, and '
                    'detailed stats.',
              ),
              const SizedBox(height: 6),
              TutorialStep(
                theme: theme,
                icon: Icons.grid_view_rounded,
                title: 'All specimens view',
                body:
                    'Use the grid button at the top left to open a global '
                    'specimen list across all species.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Got it',
                style: TextStyle(
                  color: theme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    await _settings.setCreaturesTutorialSeen();

    // Briefly highlight the All Instances button to draw attention
    if (!mounted) return;
    setState(() => _highlightAllInstances = true);

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _highlightAllInstances = false);
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();

    return StreamBuilder<Map<String, int>>(
      stream: db.creatureDao.watchInstanceCountsBySpecies(),
      builder: (context, countSnapshot) {
        final instanceCounts = countSnapshot.data ?? {};

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
                // stats
                final total = entries.length;
                final discoveredCount = discovered.length;
                final pct = total == 0
                    ? 0.0
                    : (discoveredCount / total).clamp(0.0, 1.0);

                // apply your filters/sorting to the typed entries
                final filtered = _filterAndSort(entries, instanceCounts);

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
                            onOpenAllInstances: () =>
                                _showAllInstancesView(theme),
                          ),
                          SliverToBoxAdapter(
                            child: _StatsHeaderSolid(
                              theme: theme,
                              percent: pct,
                              discovered: discoveredCount,
                              total: total,
                            ),
                          ),
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _StickyFilterBar(
                              height: 126,
                              scope: _scope,
                              typeFilter: _typeFilter,
                              isGrid: _isGrid,
                              showCounts: _showCounts,
                              theme: theme,
                              child: _FilterBarSolid(
                                theme: theme,
                                query: _query,
                                controller: _searchCtrl,
                                scope: _scope,
                                sort: _sort,
                                isGrid: _isGrid,
                                showCounts: _showCounts,
                                typeFilter: _typeFilter,
                                onQueryChanged: _onQueryChanged,
                                onScopeChanged: _cycleScope,
                                onSortTap: _cycleSort,
                                onToggleView: () =>
                                    _mutate(() => _isGrid = !_isGrid),
                                onToggleCounts: () =>
                                    _mutate(() => _showCounts = !_showCounts),
                                onTypeChanged: (t) => _mutate(
                                  () => _typeFilter = (t == 'All') ? null : t,
                                ),
                              ),
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
                                      creatures:
                                          filtered, // List<CreatureEntry>
                                      showCounts: _showCounts,
                                      instanceCounts: instanceCounts,
                                      onTap: (c, isDiscovered) =>
                                          _handleTap(c, isDiscovered, theme),
                                    )
                                  : _CreatureList(
                                      theme: theme,
                                      creatures:
                                          filtered, // List<CreatureEntry>
                                      showCounts: _showCounts,
                                      instanceCounts: instanceCounts,
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
      },
    );
  }

  void _onQueryChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _mutate(() => _query = text.trim());
    });
  }

  void _handleTap(Creature species, bool isDiscovered, FactionTheme theme) {
    if (isDiscovered) {
      _showInstancesSheet(species, theme);
    } else {
      _showCreatureDetails(species, false);
    }
  }

  List<CreatureEntry> _filterAndSort(
    List<CreatureEntry> all,
    Map<String, int> instanceCounts,
  ) {
    final scoped = all.where((m) {
      final isDiscovered = m.player.discovered == true;
      switch (_scope) {
        case 'All':
          return true;
        case 'Catalogued':
          return isDiscovered;
        case 'Unknown':
          return !isDiscovered;
        default:
          return true;
      }
    });

    final typed = _typeFilter == null
        ? scoped
        : scoped.where((m) => (m.creature).types.contains(_typeFilter));

    final q = _query.toLowerCase();
    final searched = q.isEmpty
        ? typed
        : typed.where((m) {
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
      switch (_sort) {
        case 'Name':
          return A.name.compareTo(B.name);
        case 'Classification':
          return _rarityRank(A.rarity).compareTo(_rarityRank(B.rarity));
        case 'Type':
          return A.types.first.compareTo(B.types.first);
        case 'Count':
          final countA = instanceCounts[A.id] ?? 0;
          final countB = instanceCounts[B.id] ?? 0;
          // Sort descending (highest count first), then by name
          final countCompare = countB.compareTo(countA);
          return countCompare != 0 ? countCompare : A.name.compareTo(B.name);
        case 'Acquisition Order':
          final ad = a.player.discovered == true;
          final bd = b.player.discovered == true;
          if (ad && !bd) return -1;
          if (!ad && bd) return 1;
          return A.name.compareTo(B.name);
        default:
          return 0;
      }
    });

    return list;
  }

  int _rarityRank(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return 0;
      case 'uncommon':
        return 1;
      case 'rare':
        return 2;
      case 'mythic':
        return 3;
      case 'legendary':
        return 4;
      default:
        return 0;
    }
  }

  void _showCreatureDetails(Creature c, bool isDiscovered) {
    CreatureDetailsDialog.show(context, c, isDiscovered);
  }

  void _showInstancesSheet(Creature species, FactionTheme theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return BottomSheetShell(
          theme: theme,
          title: '${species.name} Specimens',
          child: InstancesSheet(
            species: species,
            theme: theme,
            onTap: (inst) {
              Navigator.of(context).pop();
              _openDetailsForInstance(species, inst);
            },
          ),
        );
      },
    );
  }

  void _openDetailsForInstance(Creature species, CreatureInstance inst) {
    CreatureDetailsDialog.show(
      context,
      species,
      true,
      instanceId: inst.instanceId,
    );
  }

  void _showAllInstancesView(FactionTheme theme) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) {
          return DraggableSheet(
            animation: animation,
            theme: theme,
            onInstanceTap: (inst) {
              final repo = context.read<CreatureCatalog>();
              final creature = repo.getCreatureById(inst.baseId);
              if (creature != null) {
                Navigator.pop(context);
                _openDetailsForInstance(creature, inst);
              }
            },
          );
        },
      ),
    );
  }
}

/// ---------------------------- SOLID UI --------------------------------

class _SolidHeader extends StatelessWidget {
  final FactionTheme theme;
  final VoidCallback onOpenAllInstances;

  const _SolidHeader({required this.theme, required this.onOpenAllInstances});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: false,
      elevation: 0,
      backgroundColor: theme.surface,
      automaticallyImplyLeading: false,
      toolbarHeight: 72,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: theme.surface,
          border: Border(bottom: BorderSide(color: theme.border, width: 1)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            // New button on the left
            GestureDetector(
              onTap: onOpenAllInstances,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.border),
                ),
                child: const Icon(Icons.grid_view_rounded, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ALCHEMON DATABASE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Specimen cataloguing system',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    return SectionCard(
      theme: theme,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CustomPaint(
              painter: _ArcPainter(progress: percent, color: theme.accent),
              child: Center(
                child: Text(
                  '$discovered',
                  style: TextStyle(
                    color: theme.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
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
                        color: theme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .6,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$discovered / $total',
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 12,
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

class _FilterBarSolid extends StatelessWidget {
  final FactionTheme theme;
  final String query;
  final TextEditingController controller;
  final String scope;
  final String sort;
  final bool isGrid;
  final bool showCounts;
  final String? typeFilter;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onScopeChanged;
  final VoidCallback onSortTap;
  final VoidCallback onToggleView;
  final VoidCallback onToggleCounts;
  final ValueChanged<String> onTypeChanged;

  const _FilterBarSolid({
    required this.theme,
    required this.query,
    required this.controller,
    required this.scope,
    required this.sort,
    required this.isGrid,
    required this.showCounts,
    required this.typeFilter,
    required this.onQueryChanged,
    required this.onScopeChanged,
    required this.onSortTap,
    required this.onToggleView,
    required this.onToggleCounts,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final types = CreatureFilterUtils.filterOptions;
    return SectionCard(
      theme: theme,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: SearchFieldSolid(
                  theme: theme,
                  controller: controller,
                  hint: 'Search Alchemons...',
                  onChanged: onQueryChanged,
                ),
              ),
              const SizedBox(width: 4),
              PillButton(
                theme: theme,
                label: scope,
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
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = types[i];
                final selected = (typeFilter ?? 'All') == t;
                final color = t == 'All'
                    ? theme.accent
                    : BreedConstants.getTypeColor(t);
                return FilterChipSolid(
                  label: t,
                  color: color,
                  selected: selected,
                  onTap: () => onTypeChanged(t),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// --------------------------- LIST / GRID ----------------------------

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
        final instanceCount = instanceCounts[c.id] ?? 0;
        return _CreatureCard(
          key: ValueKey<String>('species:${c.id}'),
          theme: theme,
          c: c,
          discovered: isDiscovered,
          instanceCount: instanceCount,
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
        final instanceCount = instanceCounts[c.id] ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 1),
          child: _CreatureRow(
            key: ValueKey<String>('species:${c.id}'),
            theme: theme,
            c: c,
            discovered: isDiscovered,
            instanceCount: instanceCount,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: theme.surface),
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
                          child: CreatureSprite(
                            spritePath: c.spriteData!.spriteSheetPath,
                            totalFrames: c.spriteData!.totalFrames,
                            rows: c.spriteData!.rows,
                            frameSize: Vector2(
                              c.spriteData!.frameWidth.toDouble(),
                              c.spriteData!.frameHeight.toDouble(),
                            ),
                            stepTime: c.spriteData!.frameDurationMs / 1000.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    discovered ? c.name : 'Unknown',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: discovered
                          ? theme.text
                          : theme.textMuted.withOpacity(.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _RarityPill(rarity: discovered ? c.rarity : 'Class ?'),
                  const SizedBox(height: 4),
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
    final typeColor = discovered
        ? BreedConstants.getTypeColor(c.types.first)
        : theme.textMuted.withOpacity(.5);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: theme.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  children: [
                    Silhouette(
                      enabled: !discovered,
                      child: RepaintBoundary(
                        child: CreatureSprite(
                          spritePath: c.spriteData!.spriteSheetPath,
                          totalFrames: c.spriteData!.totalFrames,
                          rows: c.spriteData!.rows,
                          frameSize: Vector2(
                            c.spriteData!.frameWidth.toDouble(),
                            c.spriteData!.frameHeight.toDouble(),
                          ),
                          stepTime: c.spriteData!.frameDurationMs / 1000.0,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            discovered ? c.name : 'Unknown Specimen',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: discovered ? theme.text : theme.textMuted,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (discovered)
                      Row(
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: c.types
                                .take(2)
                                .map((t) => _TypeTiny(theme: theme, label: t))
                                .toList(),
                          ),
                          const SizedBox(width: 8),
                          _RarityPill(
                            small: true,
                            rarity: discovered ? c.rarity : 'Class ?',
                          ),
                        ],
                      )
                    else
                      Text(
                        '— —',
                        style: TextStyle(color: theme.textMuted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: theme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// -------------------------- SMALL PIECES ----------------------------

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
    return Container(
      color: theme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 8, 5, 6),
        child: Container(padding: padding, child: child),
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  final FactionTheme theme;
  final double value;
  const ProgressBar({super.key, required this.theme, required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: LayoutBuilder(
          builder: (context, constraints) {
            double w = constraints.maxWidth * v;
            if (v > 0 && w < 2) w = 2;
            return Stack(
              children: [
                Positioned.fill(child: Container(color: theme.meterTrack)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: w,
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: theme.meterFill,
                      ),
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

class SearchFieldSolid extends StatelessWidget {
  final FactionTheme theme;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const SearchFieldSolid({
    super.key,
    required this.theme,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(Icons.search_rounded, color: theme.textMuted, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                color: theme.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: theme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
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
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(
                  Icons.close_rounded,
                  color: theme.textMuted,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.border),
        ),
        child: Icon(icon, color: theme.text, size: 18),
      ),
    );
  }
}

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.accent),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: theme.text,
                fontWeight: FontWeight.w700,
                fontSize: 13,
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
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 4 : 6,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: theme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.3),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: theme.text,
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
    final bg = _rarityColor(rarity);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 3,
      ),
      child: Text(
        rarity,
        style: TextStyle(
          color: bg, // keeps strong contrast on rarity colors
          fontSize: small ? 8 : 9,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  static Color _rarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey.shade700;
      case 'uncommon':
        return Colors.green.shade600;
      case 'rare':
        return Colors.blue.shade600;
      case 'mythic':
        return Colors.purple.shade600;
      case 'legendary':
        return Colors.orange.shade600;
      default:
        return Colors.purple.shade600;
    }
  }
}

class _TypeTiny extends StatelessWidget {
  final FactionTheme theme;
  final String label;
  const _TypeTiny({required this.theme, required this.label});
  @override
  Widget build(BuildContext context) {
    final color = BreedConstants.getTypeColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: theme.text,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.visible,
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  _ArcPainter({required this.progress, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = (size.shortestSide / 2) - 4;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8
      ..color = Colors.white.withOpacity(.08);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      math.pi * 2,
      false,
      base,
    );

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(.35);
    final sweep = progress.clamp(0.0, 1.0) * math.pi * 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      sweep,
      false,
      glow,
    );

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + math.pi * 2,
        colors: [color.withOpacity(.25), color, color.withOpacity(.9)],
        stops: const [0, .7, 1],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      sweep,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.progress != progress || old.color != color;
}

/// ------------------------ States -----------------------------

class _EmptyState extends StatelessWidget {
  final FactionTheme theme;
  const _EmptyState({required this.theme});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 40, color: theme.textMuted),
            const SizedBox(height: 10),
            Text(
              'No matching specimens',
              style: TextStyle(
                color: theme.text,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different search, adjust filters, or clear the type chip.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class LoadingScaffold extends StatelessWidget {
  const LoadingScaffold();
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    return Scaffold(
      backgroundColor: theme.surface,
      body: const Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}

/// --------------------- Sticky Filter Header -------------------

class _StickyFilterBar extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  final String scope;
  final String? typeFilter;
  final bool isGrid;
  final bool showCounts;
  final FactionTheme theme;

  _StickyFilterBar({
    required this.height,
    required this.child,
    required this.scope,
    required this.typeFilter,
    required this.isGrid,
    required this.showCounts,
    required this.theme,
  });

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ClipRect(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 2),
      child: child,
    ),
  );

  @override
  bool shouldRebuild(covariant _StickyFilterBar old) =>
      old.scope != scope ||
      old.typeFilter != typeFilter ||
      old.isGrid != isGrid ||
      old.showCounts != showCounts ||
      old.theme != theme;
}
