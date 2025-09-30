import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/creature_filter_util.dart';
import 'package:alchemons/widgets/creature_dialog.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';

import '../models/creature.dart';
import '../providers/app_providers.dart';

class CreaturesScreen extends StatefulWidget {
  const CreaturesScreen({super.key});

  @override
  State<CreaturesScreen> createState() => _CreaturesScreenState();
}

class _CreaturesScreenState extends State<CreaturesScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  String _scope = 'Catalogued';
  String _sort = 'Acquisition Order';
  bool _isGrid = true;
  String _query = '';
  String? _typeFilter;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;

    // Get faction colors - replace with actual faction from game state
    final factionColors = getFactionColors(currentFaction);
    final primaryColor = factionColors.$1;
    final secondaryColor = factionColors.$2;
    return Consumer<GameStateNotifier>(
      builder: (context, game, _) {
        if (game.isLoading) return const _LoadingScaffold();
        if (game.error != null) {
          return _ErrorScaffold(error: game.error!, onRetry: game.refresh);
        }

        final filtered = _filterAndSort(game.creatures);
        final discovered = game.discoveredCreatures.length;
        final total = game.creatures.length;
        final pct = total == 0 ? 0.0 : (discovered / total).clamp(0.0, 1.0);

        return RefreshIndicator.adaptive(
          onRefresh: () async => game.refresh(),
          edgeOffset: 100,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0B0F14).withOpacity(0.92),
                    const Color(0xFF0B0F14).withOpacity(0.92),
                  ],
                ),
              ),
              child: SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    _GlassAppBar(pulse: _pulse, accentColor: primaryColor),
                    SliverToBoxAdapter(
                      child: _StatsHeader(
                        percent: pct,
                        discovered: discovered,
                        total: total,
                        pulse: _pulse,
                        primaryColor: primaryColor,
                        secondaryColor: secondaryColor,
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyFilterBar(
                        height: 124,
                        scope: _scope,
                        typeFilter: _typeFilter,
                        isGrid: _isGrid,
                        child: _FilterBar(
                          query: _query,
                          controller: _searchCtrl,
                          scope: _scope,
                          sort: _sort,
                          isGrid: _isGrid,
                          typeFilter: _typeFilter,
                          accentColor: primaryColor,
                          onQueryChanged: _onQueryChanged,
                          onScopeChanged: _showScopeSheet,
                          onSortTap: _showSortSheet,
                          onToggleView: () =>
                              setState(() => _isGrid = !_isGrid),
                          onTypeChanged: (t) => setState(
                            () => _typeFilter = t == 'All' ? null : t,
                          ),
                        ),
                      ),
                    ),
                    if (filtered.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                        sliver: _isGrid
                            ? _CreatureGrid(
                                creatures: filtered,
                                onTap: _handleTap,
                              )
                            : _CreatureList(
                                creatures: filtered,
                                onTap: _handleTap,
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onQueryChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      setState(() => _query = text.trim());
    });
  }

  Future<void> _showSortSheet() async {
    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;
    final factionColors = getFactionColors(currentFaction);
    final accentColor = factionColors.$1;

    const options = ['Name', 'Classification', 'Type', 'Acquisition Order'];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _GlassSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Sort by',
                style: TextStyle(
                  color: Color(0xFFE8EAED),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ...options.map(
                (o) => _RadioTile(
                  label: o,
                  selected: o == _sort,
                  accentColor: accentColor,
                  onTap: () => Navigator.pop(ctx, o),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
    if (picked != null) setState(() => _sort = picked);
  }

  Future<void> _showScopeSheet() async {
    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;
    final factionColors = getFactionColors(currentFaction);
    final accentColor = factionColors.$1;

    const scopes = ['All', 'Catalogued', 'Unknown'];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _GlassSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Discovery Scope',
                style: TextStyle(
                  color: Color(0xFFE8EAED),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ...scopes.map(
                (s) => _RadioTile(
                  label: s,
                  accentColor: accentColor,
                  selected: s == _scope,
                  onTap: () => Navigator.pop(ctx, s),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
    if (picked != null) setState(() => _scope = picked);
  }

  void _handleTap(Creature species, bool isDiscovered) {
    if (isDiscovered) {
      _showInstancesSheet(species);
    } else {
      _showCreatureDetails(species, false);
    }
  }

  List<Map<String, dynamic>> _filterAndSort(List<Map<String, dynamic>> all) {
    final scoped = all.where((m) {
      final isDiscovered = m['player'].discovered == true;
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
        : scoped.where(
            (m) => (m['creature'] as Creature).types.contains(_typeFilter),
          );

    final q = _query.toLowerCase();
    final searched = q.isEmpty
        ? typed
        : typed.where((m) {
            final c = m['creature'] as Creature;
            return c.id.toLowerCase().contains(q) ||
                c.name.toLowerCase().contains(q) ||
                c.types.any((t) => t.toLowerCase().contains(q)) ||
                c.rarity.toLowerCase().contains(q);
          });

    final list = searched.toList();

    list.sort((a, b) {
      final A = a['creature'] as Creature;
      final B = b['creature'] as Creature;
      switch (_sort) {
        case 'Name':
          return A.name.compareTo(B.name);
        case 'Classification':
          return _rarityRank(A.rarity).compareTo(_rarityRank(B.rarity));
        case 'Type':
          return A.types.first.compareTo(B.types.first);
        case 'Acquisition Order':
          final ad = a['player'].discovered == true;
          final bd = b['player'].discovered == true;
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

  void _showInstancesSheet(Creature species) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _GlassSheet(
          child: InstancesSheet(
            species: species,
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
}

// =============== UI building blocks ===============
class _GlassAppBar extends StatelessWidget {
  final AnimationController pulse;
  final Color accentColor;
  const _GlassAppBar({required this.pulse, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      expandedHeight: 77,
      collapsedHeight: 77,
      flexibleSpace: ClipRect(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: _Glass(
            borderRadius: 16,
            stroke: accentColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _IconButtonGlass(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ALCHEMON DATABASE',
                          style: TextStyle(
                            color: Color(0xFFE8EAED),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Specimen cataloguing system',
                          style: TextStyle(
                            color: Color(0xFFB6C0CC),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _PulseBadge(controller: pulse, accentColor: accentColor),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final double percent;
  final int discovered;
  final int total;
  final AnimationController pulse;
  final Color primaryColor;
  final Color secondaryColor;
  const _StatsHeader({
    required this.percent,
    required this.discovered,
    required this.total,
    required this.pulse,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: _Glass(
        borderRadius: 18,
        stroke: primaryColor,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: CustomPaint(
                  painter: _ArcPainter(progress: percent, color: primaryColor),
                  child: Center(
                    child: Text(
                      '$discovered',
                      style: const TextStyle(
                        color: Color(0xFFE8EAED),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'DISCOVERY PROGRESS',
                          style: TextStyle(
                            color: Color(0xFFB6C0CC),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$discovered / $total',
                          style: const TextStyle(
                            color: Color(0xFFE8EAED),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 20,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(.35),
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            color: Colors.white.withOpacity(.12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: percent.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        primaryColor.withOpacity(.7),
                                        secondaryColor,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String query;
  final TextEditingController controller;
  final String scope;
  final String sort;
  final bool isGrid;
  final String? typeFilter;
  final Color accentColor;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onScopeChanged;
  final VoidCallback onSortTap;
  final VoidCallback onToggleView;
  final ValueChanged<String> onTypeChanged;

  const _FilterBar({
    required this.query,
    required this.controller,
    required this.scope,
    required this.sort,
    required this.isGrid,
    required this.typeFilter,
    required this.accentColor,
    required this.onQueryChanged,
    required this.onScopeChanged,
    required this.onSortTap,
    required this.onToggleView,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final types = CreatureFilterUtils.filterOptions;
    return _Glass(
      borderRadius: 16,
      stroke: accentColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _SearchField(
                    controller: controller,
                    hint: 'Search creatures…',
                    onChanged: onQueryChanged,
                  ),
                ),
                const SizedBox(width: 6),
                _ToggleChip(
                  label: scope,
                  icon: Icons.filter_list_rounded,
                  onTap: onScopeChanged,
                  accentColor: accentColor,
                ),
                const SizedBox(width: 6),
                _IconButtonGlass(
                  icon: isGrid
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  onTap: onToggleView,
                ),
                const SizedBox(width: 6),
                _IconButtonGlass(icon: Icons.sort_rounded, onTap: onSortTap),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: types.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final t = types[i];
                  final selected = (typeFilter ?? 'All') == t;
                  final color = t == 'All'
                      ? accentColor
                      : BreedConstants.getTypeColor(t);
                  return _TypeChip(
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
      ),
    );
  }
}

class _CreatureGrid extends StatelessWidget {
  final List<Map<String, dynamic>> creatures;
  final void Function(Creature, bool) onTap;
  const _CreatureGrid({required this.creatures, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: .88,
      ),
      delegate: SliverChildBuilderDelegate((ctx, i) {
        final data = creatures[i];
        final c = data['creature'] as Creature;
        final isDiscovered = data['player'].discovered == true;
        return _CreatureCard(
          c: c,
          discovered: isDiscovered,
          onTap: () => onTap(c, isDiscovered),
        );
      }, childCount: creatures.length),
    );
  }
}

class _CreatureList extends StatelessWidget {
  final List<Map<String, dynamic>> creatures;
  final void Function(Creature, bool) onTap;
  const _CreatureList({required this.creatures, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((ctx, i) {
        final data = creatures[i];
        final c = data['creature'] as Creature;
        final isDiscovered = data['player'].discovered == true;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _CreatureRow(
            c: c,
            discovered: isDiscovered,
            onTap: () => onTap(c, isDiscovered),
          ),
        );
      }, childCount: creatures.length),
    );
  }
}

class _CreatureCard extends StatelessWidget {
  final Creature c;
  final bool discovered;
  final VoidCallback onTap;
  const _CreatureCard({
    required this.c,
    required this.discovered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<GameStateNotifier>(
      builder: (context, game, _) {
        final variants = game.discoveredCreatures.where((m) {
          final v = m['creature'] as Creature;
          return v.rarity == 'Variant' && v.id.startsWith('${c.id}_');
        }).length;

        final border = discovered
            ? BreedConstants.getTypeColor(c.types.first).withOpacity(.55)
            : Colors.grey.shade400;

        return GestureDetector(
          onTap: onTap,
          child: _Glass(
            borderRadius: 12,
            stroke: border,
            fillOpacity: .12,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    children: [
                      Expanded(
                        child: _CreatureImage(c: c, discovered: discovered),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        discovered ? c.name : 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: discovered
                              ? const Color(0xFFE8EAED)
                              : Colors.grey.shade500,
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
                if (variants > 0 && discovered)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: _Badge(text: '+$variants'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CreatureRow extends StatelessWidget {
  final Creature c;
  final bool discovered;
  final VoidCallback onTap;
  const _CreatureRow({
    required this.c,
    required this.discovered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = discovered
        ? BreedConstants.getTypeColor(c.types.first)
        : Colors.grey.shade400;
    return GestureDetector(
      onTap: onTap,
      child: _Glass(
        borderRadius: 12,
        stroke: color,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: _CreatureImage(c: c, discovered: discovered, rounded: 8),
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
                              color: discovered
                                  ? const Color(0xFFE8EAED)
                                  : Colors.grey.shade500,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RarityPill(
                          small: true,
                          rarity: discovered ? c.rarity : 'Class ?',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (discovered)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: c.types
                            .take(2)
                            .map((t) => _TypeTiny(label: t))
                            .toList(),
                      )
                    else
                      const Text(
                        '— —',
                        style: TextStyle(
                          color: Color(0xFFB6C0CC),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFB6C0CC)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatureImage extends StatelessWidget {
  final Creature c;
  final bool discovered;
  final double rounded;
  const _CreatureImage({
    required this.c,
    required this.discovered,
    this.rounded = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (!discovered) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(rounded),
        ),
        child: const Center(
          child: Icon(
            Icons.help_outline_rounded,
            color: Color(0xFFB6C0CC),
            size: 24,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(rounded),
        boxShadow: [
          BoxShadow(
            color: BreedConstants.getTypeColor(c.types.first).withOpacity(.18),
            blurRadius: 6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rounded),
        child: Image.asset(
          'assets/images/creatures/${c.rarity.toLowerCase()}/${c.id.toUpperCase()}_${c.name.toLowerCase()}.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              color: BreedConstants.getTypeColor(
                c.types.first,
              ).withOpacity(.12),
              borderRadius: BorderRadius.circular(rounded),
            ),
            child: Icon(
              BreedConstants.getTypeIcon(c.types.first),
              color: BreedConstants.getTypeColor(c.types.first),
            ),
          ),
        ),
      ),
    );
  }
}

// =============== tiny widgets ===============
class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.shade600,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
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
    final color = _rarityColor(rarity);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        rarity,
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 9 : 10,
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
        return Colors.grey.shade600;
      case 'uncommon':
        return Colors.green.shade500;
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
  final String label;
  const _TypeTiny({required this.label});
  @override
  Widget build(BuildContext context) {
    final color = BreedConstants.getTypeColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.visible,
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(.22)
              : Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.white.withOpacity(.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != 'All')
              Icon(BreedConstants.getTypeIcon(label), size: 14, color: color)
            else
              Icon(Icons.all_inclusive, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(.25)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.search_rounded, color: Color(0xFFB6C0CC), size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                color: Color(0xFFE8EAED),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFF9AA6B2),
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
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(
                  Icons.close_rounded,
                  color: Color(0xFFB6C0CC),
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IconButtonGlass extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconButtonGlass({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(.25)),
        ),
        child: Icon(icon, color: const Color(0xFFE8EAED), size: 18),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;
  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.accentColor,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: accentColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
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

class _RadioTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accentColor;
  const _RadioTile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accentColor,
  });
  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      dense: true,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? accentColor : Colors.white.withOpacity(.35),
      ),
      title: Text(
        label,
        style: TextStyle(color: accentColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  const _Kpi({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFB6C0CC),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .6,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(.25)),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE8EAED),
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..color = color.withOpacity(.4);
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

class _StickyFilterBar extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  final String scope;
  final String? typeFilter;
  final bool isGrid;

  _StickyFilterBar({
    required this.height,
    required this.child,
    required this.scope,
    required this.typeFilter,
    required this.isGrid,
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
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: child,
    ),
  );
  @override
  bool shouldRebuild(covariant _StickyFilterBar old) =>
      old.scope != scope ||
      old.typeFilter != typeFilter ||
      old.isGrid != isGrid;
}

class _PulseBadge extends StatelessWidget {
  final AnimationController controller;
  final Color accentColor;
  const _PulseBadge({required this.controller, required this.accentColor});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final glow = 0.35 + controller.value * 0.4;
        return Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accentColor.withOpacity(glow)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(glow * .4),
                blurRadius: 20 + controller.value * 14,
              ),
            ],
            gradient: RadialGradient(
              colors: [accentColor.withOpacity(.55), Colors.transparent],
            ),
          ),
          child: const Icon(
            Icons.storage_rounded,
            size: 16,
            color: Colors.white,
          ),
        );
      },
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color stroke;
  final double fillOpacity;
  const _Glass({
    required this.child,
    this.borderRadius = 16,
    this.stroke = Colors.white,
    this.fillOpacity = .14,
  });
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(fillOpacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: stroke.withOpacity(.35)),
            boxShadow: [
              BoxShadow(
                color: stroke.withOpacity(.18),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  final Widget child;
  const _GlassSheet({required this.child});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: _Glass(child: child),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 40, color: Color(0xFFB6C0CC)),
            SizedBox(height: 10),
            Text(
              'No matching specimens',
              style: TextStyle(
                color: Color(0xFFE8EAED),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Try a different search, adjust filters, or clear the type chip.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFB6C0CC), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorScaffold({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _Glass(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 34,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Database Connection Error',
                    style: TextStyle(
                      color: Color(0xFFE8EAED),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB6C0CC),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
