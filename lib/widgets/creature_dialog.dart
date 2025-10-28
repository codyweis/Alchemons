import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flame/components.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/nature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/providers/app_providers.dart';
import 'package:alchemons/screens/instance_selection_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:alchemons/widgets/creature_sprite.dart';

import '../models/creature.dart';

class CreatureDetailsDialog extends StatefulWidget {
  final Creature creature;
  final bool isDiscovered;
  final String? instanceId;

  const CreatureDetailsDialog({
    super.key,
    required this.creature,
    required this.isDiscovered,
    this.instanceId,
  });

  @override
  State<CreatureDetailsDialog> createState() => _CreatureDetailsDialogState();

  static Future<void> show(
    BuildContext context,
    Creature creature,
    bool isDiscovered, {
    String? instanceId,
  }) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => CreatureDetailsDialog(
        creature: creature,
        isDiscovered: isDiscovered || instanceId != null,
        instanceId: instanceId,
      ),
    );
  }
}

class _CreatureDetailsDialogState extends State<CreatureDetailsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  late ScrollController _analysisScrollController;

  Future<Creature>? _resolvedCreature;
  final Set<String> _expandedParents = {};

  int _currentImageIndex = 0;

  int? _instanceLevel;
  int? _instanceXp;
  int? _instanceXpToNext;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: widget.isDiscovered ? 2 : 1,
      vsync: this,
    );

    _pageController = PageController(viewportFraction: 1.0);
    _analysisScrollController = ScrollController();

    if (widget.instanceId != null) {
      _resolvedCreature = _displayCreatureForInstance(widget.instanceId!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    _analysisScrollController.dispose();
    super.dispose();
  }

  // ---- data prep helpers ----------------------------------------------------

  Future<Creature> _displayCreatureForInstance(String instanceId) async {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureRepository>();

    final row = await db.getInstance(instanceId);
    if (row == null) throw Exception('Instance not found');

    _instanceLevel = row.level;
    _instanceXp = row.xp;

    final base = repo.getCreatureById(row.baseId);
    if (base == null) {
      throw Exception('Catalog creature ${row.baseId} not loaded');
    }

    var out = base;

    if (row.isPrismaticSkin == true) {
      out = out.copyWith(isPrismaticSkin: true);
    }
    if (row.natureId != null && row.natureId!.isNotEmpty) {
      final n = NatureCatalog.byId(row.natureId!);
      if (n != null) out = out.copyWith(nature: n);
    }
    final g = decodeGenetics(row.geneticsJson);
    if (g != null) out = out.copyWith(genetics: g);

    final decoded = _decodeParentage(row.parentageJson);
    if (decoded != null) {
      final hydrated = decoded.rehydrate(repo);
      out = out.copyWith(parentage: hydrated);
    }

    return out;
  }

  Parentage? _decodeParentage(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return Parentage.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  String _sizeName(Creature c) =>
      sizeLabels[c.genetics?.get('size') ?? 'normal'] ?? 'Standard';

  String _tintName(Creature c) =>
      tintLabels[c.genetics?.get('tinting') ?? 'normal'] ?? 'Standard';

  // ---- build root -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final factionTheme = context.read<FactionTheme>();

    if (widget.instanceId == null) {
      // static species view
      return _buildDialogShell(factionTheme, widget.creature);
    }

    // instance view (hydrate first)
    return FutureBuilder<Creature>(
      future: _resolvedCreature,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _buildLoadingDialog(factionTheme);
        }
        if (snap.hasError || !snap.hasData) {
          return _buildDialogShell(factionTheme, widget.creature);
        }
        return _buildDialogShell(factionTheme, snap.data!);
      },
    );
  }

  // ---- outer shell (header + tabs + body scroll) ---------------------------

  Widget _buildDialogShell(FactionTheme theme, Creature effective) {
    final discovered = widget.isDiscovered;

    return Dialog(
      insetPadding: const EdgeInsets.all(2),
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: theme.border, width: 2),
          boxShadow: [
            BoxShadow(
              color: theme.accent.withOpacity(.4),
              blurRadius: 32,
              spreadRadius: 4,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(.8),
              blurRadius: 48,
              spreadRadius: 16,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _DialogHeaderBar(
              theme: theme,
              creature: effective,
              level: _instanceLevel,
              onClose: () => Navigator.of(context).pop(),
            ),

            if (discovered)
              _DialogTabSelector(theme: theme, tabController: _tabController),

            Expanded(
              child: discovered
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _OverviewScrollArea(
                          theme: theme,
                          instanceId: widget.instanceId,
                          instanceLevel: _instanceLevel,
                          creature: effective,
                          pageController: _pageController,
                          currentImageIndex: _currentImageIndex,
                          onPageChanged: (i) {
                            setState(() {
                              _currentImageIndex = i;
                            });
                          },
                        ),
                        _AnalysisScrollArea(
                          theme: theme,
                          controller: _analysisScrollController,
                          creature: effective,
                          isInstance: widget.instanceId != null,
                          isExpandedMap: _expandedParents,
                          onToggleParent: (parentKey) {
                            double? oldOffset;
                            if (_analysisScrollController.hasClients) {
                              oldOffset = _analysisScrollController.offset;
                            }

                            setState(() {
                              if (_expandedParents.contains(parentKey)) {
                                _expandedParents.remove(parentKey);
                              } else {
                                _expandedParents.add(parentKey);
                              }
                            });

                            if (oldOffset != null) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (_analysisScrollController.hasClients) {
                                  _analysisScrollController.jumpTo(oldOffset!);
                                }
                              });
                            }
                          },
                          instanceId: widget.instanceId,
                        ),
                      ],
                    )
                  : _UnknownScrollArea(theme: theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingDialog(FactionTheme theme) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.transparent,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.border, width: 2),
          boxShadow: [
            BoxShadow(
              color: theme.accent.withOpacity(.4),
              blurRadius: 32,
              spreadRadius: 4,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(.8),
              blurRadius: 48,
              spreadRadius: 16,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation(theme.primary),
        ),
      ),
    );
  }
}

// ============================================================================
// HEADER BAR
// ============================================================================

class _DialogHeaderBar extends StatelessWidget {
  final FactionTheme theme;
  final Creature creature;
  final int? level;
  final VoidCallback onClose;

  const _DialogHeaderBar({
    required this.theme,
    required this.creature,
    required this.level,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primary.withOpacity(.28),
                  theme.secondary.withOpacity(.2),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.primary.withOpacity(.45),
                width: 1.5,
              ),
            ),
            child: Icon(Icons.biotech_rounded, color: theme.primary, size: 18),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        creature.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                    if (level != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade600,
                              Colors.amber.shade700,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(.3),
                          ),
                        ),
                        child: Text(
                          'LV $level',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Specimen analysis report',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.border),
              ),
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

// ============================================================================
// TAB SELECTOR
// ============================================================================

class _DialogTabSelector extends StatelessWidget {
  final FactionTheme theme;
  final TabController tabController;

  const _DialogTabSelector({required this.theme, required this.tabController});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.surfaceAlt,
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.border),
        ),
        child: TabBar(
          controller: tabController,
          indicator: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.primary.withOpacity(.3),
                theme.secondary.withOpacity(.25),
              ],
            ),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: theme.primary.withOpacity(.45),
              width: 1.5,
            ),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: theme.text,
          unselectedLabelColor: theme.textMuted,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
          tabs: const [
            Tab(text: 'OVERVIEW'),
            Tab(text: 'ANALYSIS'),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// OVERVIEW TAB
// ============================================================================

class _OverviewScrollArea extends StatelessWidget {
  final FactionTheme theme;
  final Creature creature;
  final String? instanceId;
  final int? instanceLevel;

  final PageController pageController;
  final int currentImageIndex;
  final ValueChanged<int> onPageChanged;

  const _OverviewScrollArea({
    required this.theme,
    required this.creature,
    required this.instanceId,
    required this.instanceLevel,
    required this.pageController,
    required this.currentImageIndex,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Consumer<GameStateNotifier>(
            builder: (context, gameState, child) {
              final variants = gameState.discoveredCreatures.where((data) {
                final c2 = data['creature'] as Creature;
                return c2.rarity == 'Variant' &&
                    c2.id.startsWith('${creature.id}_');
              }).toList();

              final allVersions = [
                {'creature': creature, 'isVariant': false},
                ...variants.map(
                  (v) => {'creature': v['creature'], 'isVariant': true},
                ),
              ];

              return Center(
                child: _CreatureCarousel(
                  theme: theme,
                  entries: allVersions,
                  pageController: pageController,
                  currentIndex: currentImageIndex,
                  onChanged: onPageChanged,
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          if (instanceId != null) ...[
            _SectionBlock(
              theme: theme,
              title: 'Specimen Status',
              child: Column(
                children: [
                  if (instanceLevel != null)
                    _LabeledInlineValue(
                      label: 'Level',
                      valueText: '$instanceLevel',
                      valueColor: theme.primary,
                    ),
                  _StaminaInlineRow(
                    theme: theme,
                    label: 'Energy Level',
                    instanceId: instanceId!,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          _SectionBlock(
            theme: theme,
            title: 'Specimen Classification',
            child: Column(
              children: [
                _LabeledInlineValue(
                  label: 'Classification',
                  valueText: creature.rarity,
                  valueColor: theme.text,
                ),
                _LabeledInlineValue(
                  label: 'Type Categories',
                  valueText: creature.types.join(', '),
                  valueColor: theme.text,
                ),
                if (creature.description.isNotEmpty)
                  _LabeledInlineValue(
                    label: 'Description',
                    valueText: creature.description,
                    valueColor: theme.text,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (instanceId != null)
            FutureBuilder<CreatureInstance?>(
              future: context.read<AlchemonsDatabase>().getInstance(
                instanceId!,
              ),
              builder: (context, snap) {
                if (snap.hasData && snap.data != null) {
                  final inst = snap.data!;
                  return Column(
                    children: [
                      _SectionBlock(
                        theme: theme,
                        title: 'Physical Attributes',
                        child: Column(
                          children: [
                            _StatBarRow(
                              theme: theme,
                              label: 'Speed',
                              value: inst.statSpeed,
                            ),
                            _StatBarRow(
                              theme: theme,
                              label: 'Intelligence',
                              value: inst.statIntelligence,
                            ),
                            _StatBarRow(
                              theme: theme,
                              label: 'Strength',
                              value: inst.statStrength,
                            ),
                            _StatBarRow(
                              theme: theme,
                              label: 'Beauty',
                              value: inst.statBeauty,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),

          _SectionBlock(
            theme: theme,
            title: 'Genetic Profile',
            child: Column(
              children: [
                _LabeledInlineValue(
                  label: 'Size Variant',
                  valueText: _sizeLabels(creature),
                  valueColor: theme.text,
                ),
                _LabeledInlineValue(
                  label: 'Pigmentation',
                  valueText: _tintLabels(creature),
                  valueColor: theme.text,
                ),
                if (creature.nature != null)
                  _LabeledInlineValue(
                    label: 'Behavioral Pattern',
                    valueText: creature.nature!.id,
                    valueColor: theme.text,
                  ),
                if (creature.isPrismaticSkin == true)
                  _LabeledInlineValue(
                    label: 'Special Trait',
                    valueText: 'Prismatic Phenotype',
                    valueColor: theme.text,
                  ),
              ],
            ),
          ),

          if (creature.specialBreeding != null) ...[
            const SizedBox(height: 16),
            _SectionBlock(
              theme: theme,
              title: 'Synthesis Requirements',
              child: Column(
                children: [
                  _LabeledInlineValue(
                    label: 'Method',
                    valueText: 'Specialized Genetic Fusion',
                  ),
                  _LabeledInlineValue(
                    label: 'Required Components',
                    valueText: creature.specialBreeding!.requiredParentNames
                        .join(' + '),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _sizeLabels(Creature c) {
    final mapLabel = sizeLabels[c.genetics?.get('size') ?? 'normal'];
    return mapLabel ?? 'Standard';
  }

  String _tintLabels(Creature c) {
    final mapLabel = tintLabels[c.genetics?.get('tinting') ?? 'normal'];
    return mapLabel ?? 'Standard';
  }
}

// ============================================================================
// ANALYSIS TAB
// ============================================================================

class _AnalysisScrollArea extends StatelessWidget {
  final FactionTheme theme;
  final ScrollController controller;
  final Creature creature;
  final bool isInstance;
  final Set<String> isExpandedMap;
  final void Function(String parentKey) onToggleParent;
  final String? instanceId;

  const _AnalysisScrollArea({
    required this.theme,
    required this.controller,
    required this.creature,
    required this.isInstance,
    required this.isExpandedMap,
    required this.onToggleParent,
    required this.instanceId,
  });

  @override
  Widget build(BuildContext context) {
    final parentage = creature.parentage;

    return SingleChildScrollView(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionBlock(
            theme: theme,
            title: 'Behavioral Analysis',
            child: _BehaviorBlock(creature: creature, textColor: theme.text),
          ),

          const SizedBox(height: 16),

          _SectionBlock(
            theme: theme,
            title: 'Genetic Analysis',
            child: _GeneticsBlock(creature: creature, textColor: theme.text),
          ),

          const SizedBox(height: 16),

          if (isInstance)
            _StatPotentialBlock(theme: theme, instanceId: instanceId),
          if (isInstance) const SizedBox(height: 16),

          if (parentage != null) ...[
            _SectionBlock(
              theme: theme,
              title: 'Synthesis Information',
              child: Column(
                children: [
                  _LabeledInlineValue(
                    label: 'Method',
                    valueText: 'Genetic Fusion',
                    valueColor: theme.text,
                  ),
                  _LabeledInlineValue(
                    label: 'Date',
                    valueText: _formatBreedLine(parentage),
                    valueColor: theme.text,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'PARENT SPECIMENS',
              style: TextStyle(
                color: theme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 8),

            _ParentCard(
              theme: theme,
              snap: parentage.parentA,
              parentKey: 'parentA',
              isExpanded: isExpandedMap.contains('parentA'),
              onToggle: () => onToggleParent('parentA'),
            ),
            const SizedBox(height: 10),
            _ParentCard(
              theme: theme,
              snap: parentage.parentB,
              parentKey: 'parentB',
              isExpanded: isExpandedMap.contains('parentB'),
              onToggle: () => onToggleParent('parentB'),
            ),
          ] else ...[
            _SectionBlock(
              theme: theme,
              title: 'Acquisition Method',
              child: Column(
                children: const [
                  _LabeledInlineValue(
                    label: 'Source',
                    valueText: 'Field Research',
                  ),
                  _LabeledInlineValue(
                    label: 'Discovery',
                    valueText: 'Wild specimen - no synthesis data available',
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (parentage != null && isInstance && instanceId != null) ...[
            _BreedingAnalysisSection(theme: theme, instanceId: instanceId!),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  String _formatBreedLine(Parentage p) {
    final dt = p.bredAt;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}

// ============================================================================
// UNKNOWN TAB
// ============================================================================

class _UnknownScrollArea extends StatelessWidget {
  final FactionTheme theme;
  const _UnknownScrollArea({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(.15)),
              ),
              child: Icon(
                Icons.help_outline_rounded,
                color: Colors.white.withOpacity(.4),
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unknown Specimen',
              style: TextStyle(
                color: theme.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Specimen data unavailable\nContinue research to unlock analysis',
              style: TextStyle(
                color: theme.text.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SMALL BUILDING BLOCKS / SUBWIDGETS
// ============================================================================

class _CreatureCarousel extends StatelessWidget {
  final FactionTheme theme;
  final PageController pageController;
  final int currentIndex;
  final List<Map<String, dynamic>> entries;
  final ValueChanged<int> onChanged;

  const _CreatureCarousel({
    required this.theme,
    required this.pageController,
    required this.currentIndex,
    required this.entries,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          width: 160,
          child: PageView.builder(
            controller: pageController,
            itemCount: entries.length,
            onPageChanged: onChanged,
            itemBuilder: (_, i) {
              final data = entries[i];
              final creature = data['creature'] as Creature;
              final isVariant = data['isVariant'] as bool;

              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: CreatureSprite(
                          spritePath: creature.spriteData!.spriteSheetPath,
                          totalFrames: creature.spriteData!.totalFrames,
                          rows: creature.spriteData!.rows,
                          frameSize: Vector2(
                            creature.spriteData!.frameWidth.toDouble(),
                            creature.spriteData!.frameHeight.toDouble(),
                          ),
                          stepTime:
                              (creature.spriteData!.frameDurationMs / 1000.0),
                          scale: scaleFromGenes(creature.genetics),
                          saturation: satFromGenes(creature.genetics),
                          brightness: briFromGenes(creature.genetics),
                          hueShift: hueFromGenes(creature.genetics),
                          isPrismatic: creature.isPrismaticSkin,
                        ),
                      ),
                    ),

                    if (creature.isPrismaticSkin == true)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade400,
                                Colors.purple.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withOpacity(.3),
                            ),
                          ),
                          child: const Text(
                            'PRISMATIC',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),

                    if (isVariant)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade500,
                                Colors.orange.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withOpacity(.3),
                            ),
                          ),
                          child: const Text(
                            'VARIANT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),

        if (entries.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              entries.length,
              (i) => Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: currentIndex == i
                      ? theme.primary
                      : Colors.white.withOpacity(.3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final FactionTheme theme;
  final String title;
  final Widget child;

  const _SectionBlock({
    required this.theme,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: theme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.surfaceAlt,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: theme.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _LabeledInlineValue extends StatelessWidget {
  final String label;
  final String valueText;
  final Color? valueColor;

  const _LabeledInlineValue({
    required this.label,
    required this.valueText,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final vc = valueColor ?? const Color(0xFFE8EAED);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: vc,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(valueText, style: TextStyle(color: vc, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _StaminaInlineRow extends StatelessWidget {
  final FactionTheme theme;
  final String label;
  final String instanceId;
  const _StaminaInlineRow({
    required this.theme,
    required this.label,
    required this.instanceId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: theme.text.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: StaminaBadge(instanceId: instanceId, showCountdown: true),
          ),
        ],
      ),
    );
  }
}

class _StatBarRow extends StatelessWidget {
  final FactionTheme theme;
  final String label;
  final double value;

  const _StatBarRow({
    required this.theme,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final descriptor = getStatDescriptor(value, label.toLowerCase());
    final fill = (value / 5.0).clamp(0.0, 1.0);
    final isMaxed = value == 5.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: TextStyle(
                    color: theme.text.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.07),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: fill,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isMaxed
                                    ? [Colors.amber, Colors.amber.shade600]
                                    : [
                                        theme.primary,
                                        theme.secondary.withOpacity(.7),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isMaxed
                            ? Colors.amber.withOpacity(.2)
                            : theme.primary.withOpacity(.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isMaxed
                              ? Colors.amber.withOpacity(.4)
                              : theme.primary.withOpacity(.3),
                        ),
                      ),
                      child: Text(
                        value.toStringAsFixed(1),
                        style: TextStyle(
                          color: isMaxed ? Colors.amber : theme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 100),
            child: Text(
              descriptor,
              style: TextStyle(
                color: isMaxed
                    ? Colors.amber.withOpacity(.9)
                    : const Color(0xFF9AA6B2),
                fontSize: 10,
                fontStyle: FontStyle.italic,
                fontWeight: isMaxed ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Behavior / Genetics blocks
// ============================================================================

class _BehaviorBlock extends StatelessWidget {
  final Creature creature;
  final Color? textColor;

  const _BehaviorBlock({
    required this.creature,
    this.textColor = const Color(0xFFE8EAED),
  });

  @override
  Widget build(BuildContext context) {
    final n = creature.nature;
    if (n != null) {
      return Column(
        children: [
          _LabeledInlineValue(
            label: 'Nature Type',
            valueText: n.id,
            valueColor: textColor,
          ),
          if (n.effect.modifiers.isNotEmpty)
            _LabeledInlineValue(
              label: 'Active Effects',
              valueText: _formatNatureEffects(n.effect),
              valueColor: textColor,
            )
          else
            _LabeledInlineValue(
              label: 'Effects',
              valueText: 'No special behavioral modifications known',
              valueColor: textColor,
            ),
        ],
      );
    } else {
      return _LabeledInlineValue(
        label: 'Nature',
        valueText: 'Unspecified - Standard behavioral pattern',
        valueColor: textColor,
      );
    }
  }

  String _formatNatureEffects(NatureEffect effect) {
    if (effect.modifiers.isEmpty) return 'None';

    final effects = <String>[];
    effect.modifiers.forEach((key, value) {
      switch (key) {
        case 'stamina_extra':
          effects.add('Stamina +${value.toInt()}');
          break;
        case 'stamina_breeding_cost_mult':
          {
            final percent = ((1 - value) * 100).round();
            effects.add('Breeding cost -$percent%');
          }
          break;
        case 'stamina_wilderness_drain_mult':
          {
            final percent = ((1 - value) * 100).round();
            effects.add('Wilderness stamina -$percent%');
          }
          break;
        case 'breed_same_species_chance_mult':
          {
            final percent = ((value - 1) * 100).round();
            effects.add(
              'Same species breeding ${percent >= 0 ? '+' : ''}$percent%',
            );
          }
          break;
        case 'breed_same_type_chance_mult':
          {
            final percent = ((value - 1) * 100).round();
            effects.add(
              'Same type breeding (${percent >= 0 ? '+' : ''}$percent%)',
            );
          }
          break;
        case 'egg_hatch_time_mult':
          {
            final percent = ((1 - value) * 100).round();
            effects.add('Hatch time -$percent%');
          }
          break;
        case 'xp_gain_mult':
          {
            final percent = ((value - 1) * 100).round();
            effects.add('XP gain +$percent%');
          }
          break;
        default:
          effects.add('$key: ${value}x');
      }
    });

    return effects.join(', ');
  }
}

class _GeneticsBlock extends StatelessWidget {
  final Creature creature;
  final Color? textColor;

  const _GeneticsBlock({required this.creature, this.textColor});

  @override
  Widget build(BuildContext context) {
    final g = creature.genetics;

    if (g == null) {
      return Column(
        children: [
          _LabeledInlineValue(
            label: 'Genetic Profile',
            valueText: 'Standard genotype - no variants detected',
            valueColor: textColor,
          ),
          _LabeledInlineValue(
            label: 'Inheritance',
            valueText: 'Wild-type characteristics',
            valueColor: textColor,
          ),
        ],
      );
    }

    final sizeGene = g.get('size');
    final tintGene = g.get('tinting');

    return Column(
      children: [
        if (sizeGene != null) ...[
          _LabeledInlineValue(
            label: 'Size Gene',
            valueText: sizeGene,
            valueColor: textColor,
          ),
        ] else ...[
          _LabeledInlineValue(
            label: 'Size Gene',
            valueText: 'normal (default)',
            valueColor: textColor,
          ),
          _LabeledInlineValue(
            label: 'Size Expression',
            valueText: 'Standard morphology',
            valueColor: textColor,
          ),
        ],
        if (tintGene != null) ...[
          _LabeledInlineValue(
            label: 'Coloration',
            valueText: tintLabels[tintGene] ?? 'Unknown',
            valueColor: textColor,
          ),
          _LabeledInlineValue(
            label: 'Color',
            valueText: _getGeneticDescription('tinting', tintGene),
            valueColor: textColor,
          ),
        ] else ...[
          _LabeledInlineValue(
            label: 'Coloration Gene',
            valueText: 'normal (default)',
            valueColor: textColor,
          ),
          _LabeledInlineValue(
            label: 'Color Expression',
            valueText: 'Natural pigmentation',
            valueColor: textColor,
          ),
        ],
      ],
    );
  }

  static String _getGeneticDescription(String track, String variant) {
    try {
      final geneTrack = GeneticsCatalog.track(track);
      final geneVariant = geneTrack.byId(variant);
      return geneVariant.description;
    } catch (_) {
      return 'Unknown variant';
    }
  }
}

// ============================================================================
// STAT POTENTIAL SECTION
// ============================================================================

class _StatPotentialBar extends StatelessWidget {
  final FactionTheme theme;
  final String statName;
  final double currentValue;
  final double potential;
  final IconData icon;

  const _StatPotentialBar({
    required this.theme,
    required this.statName,
    required this.currentValue,
    required this.potential,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final currentPercent = (currentValue / 5.0).clamp(0.0, 1.0);
    final potentialPercent = (potential / 5.0).clamp(0.0, 1.0);
    final roomForGrowth = potential - currentValue;
    final isNearMax = roomForGrowth < 0.3;
    final isPerfectPotential = potential >= 4.8;

    return Row(
      children: [
        Icon(icon, size: 16, color: theme.textMuted),
        const SizedBox(width: 8),

        SizedBox(
          width: 85,
          child: Text(
            statName,
            style: TextStyle(
              color: theme.text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: theme.surfaceAlt,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: theme.border, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Row(
                        children: [
                          Container(
                            width: availableWidth * potentialPercent,
                            decoration: BoxDecoration(
                              color: isPerfectPotential
                                  ? Colors.purple.withOpacity(.15)
                                  : Colors.grey.withOpacity(.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Row(
                        children: [
                          Container(
                            width: availableWidth * currentPercent,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.accent,
                                  theme.accent.withOpacity(.7),
                                ],
                              ),
                            ),
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

        const SizedBox(width: 8),

        SizedBox(
          width: 70,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${currentValue.toStringAsFixed(1)} / ${potential.toStringAsFixed(1)}',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.clip,
                maxLines: 1,
              ),
              if (isNearMax)
                Text(
                  'Near Max',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  '+${roomForGrowth.toStringAsFixed(1)}',
                  style: TextStyle(color: theme.textMuted, fontSize: 8),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PotentialSummary extends StatelessWidget {
  final FactionTheme theme;
  final CreatureInstance instance;

  const _PotentialSummary({required this.theme, required this.instance});

  @override
  Widget build(BuildContext context) {
    final totalPotential =
        instance.statSpeedPotential +
        instance.statIntelligencePotential +
        instance.statStrengthPotential +
        instance.statBeautyPotential;

    final totalCurrent =
        instance.statSpeed +
        instance.statIntelligence +
        instance.statStrength +
        instance.statBeauty;

    final potentials = {
      'Speed': instance.statSpeedPotential,
      'Intelligence': instance.statIntelligencePotential,
      'Strength': instance.statStrengthPotential,
      'Beauty': instance.statBeautyPotential,
    };

    final highestPotential = potentials.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    final isHighPotential = totalPotential >= 18.0;
    final isLegendaryPotential = totalPotential >= 19.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isLegendaryPotential
            ? Colors.purple.withOpacity(.08)
            : isHighPotential
            ? Colors.blue.withOpacity(.08)
            : theme.surfaceAlt.withOpacity(.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLegendaryPotential
              ? Colors.purple.withOpacity(.3)
              : isHighPotential
              ? Colors.blue.withOpacity(.3)
              : theme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Growth Potential',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isLegendaryPotential
                      ? Colors.purple.withOpacity(.2)
                      : isHighPotential
                      ? Colors.blue.withOpacity(.2)
                      : Colors.grey.withOpacity(.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isLegendaryPotential
                      ? 'LEGENDARY'
                      : isHighPotential
                      ? 'EXCEPTIONAL'
                      : 'AVERAGE',
                  style: TextStyle(
                    color: isLegendaryPotential
                        ? Colors.purple
                        : isHighPotential
                        ? Colors.blue
                        : Colors.grey,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Total: ${totalCurrent.toStringAsFixed(1)} / ${totalPotential.toStringAsFixed(1)}',
            style: TextStyle(color: theme.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            'Best Gene: ${highestPotential.key} (${highestPotential.value.toStringAsFixed(1)})',
            style: TextStyle(
              color: theme.primary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPotentialBlock extends StatelessWidget {
  final FactionTheme theme;
  final String? instanceId;

  const _StatPotentialBlock({required this.theme, this.instanceId});

  Future<CreatureInstance?> _getInstance(BuildContext context) async {
    if (instanceId == null) return null;
    final db = context.read<AlchemonsDatabase>();
    return await db.getInstance(instanceId!);
  }

  @override
  Widget build(BuildContext context) {
    if (instanceId == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<CreatureInstance?>(
      future: _getInstance(context),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data == null) {
          return const SizedBox.shrink();
        }

        final instance = snap.data!;

        return _SectionBlock(
          theme: theme,
          title: 'Stat Potential',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.primary.withOpacity(.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: theme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Understanding Potential',
                          style: TextStyle(
                            color: theme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Each creature has a genetic potential cap for every stat. Feeding can increase stats up to their potential, but never beyond. Breed creatures with high potential to create powerful offspring!',
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _StatPotentialBar(
                theme: theme,
                statName: 'Speed',
                currentValue: instance.statSpeed,
                potential: instance.statSpeedPotential,
                icon: Icons.flash_on,
              ),
              const SizedBox(height: 8),
              _StatPotentialBar(
                theme: theme,
                statName: 'Intelligence',
                currentValue: instance.statIntelligence,
                potential: instance.statIntelligencePotential,
                icon: Icons.psychology,
              ),
              const SizedBox(height: 8),
              _StatPotentialBar(
                theme: theme,
                statName: 'Strength',
                currentValue: instance.statStrength,
                potential: instance.statStrengthPotential,
                icon: Icons.fitness_center,
              ),
              const SizedBox(height: 8),
              _StatPotentialBar(
                theme: theme,
                statName: 'Beauty',
                currentValue: instance.statBeauty,
                potential: instance.statBeautyPotential,
                icon: Icons.auto_awesome,
              ),

              const SizedBox(height: 12),

              _PotentialSummary(theme: theme, instance: instance),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// BREEDING ANALYSIS SECTION (the "final" version you want to ship)
// ============================================================================

class _BreedingAnalysisSection extends StatelessWidget {
  final FactionTheme theme;
  final String instanceId;

  const _BreedingAnalysisSection({
    required this.theme,
    required this.instanceId,
  });

  Future<Map<String, dynamic>?> _loadAnalysisReport(
    BuildContext context,
  ) async {
    try {
      final db = context.read<AlchemonsDatabase>();
      final instance = await db.getInstance(instanceId);

      if (instance?.likelihoodAnalysisJson == null ||
          instance!.likelihoodAnalysisJson!.isEmpty) {
        return null;
      }

      return jsonDecode(instance.likelihoodAnalysisJson!)
          as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadAnalysisReport(context),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data == null) {
          return _SectionBlock(
            theme: theme,
            title: 'Breeding Analysis',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No breeding data available',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This creature was not bred from parents',
                  style: TextStyle(color: theme.text, fontSize: 10),
                ),
              ],
            ),
          );
        }

        final report = snap.data!;

        return _SectionBlock(
          theme: theme,
          title: 'Breeding Analysis',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryBanner(theme: theme, report: report),

              const SizedBox(height: 12),

              _OutcomeBadge(theme: theme, report: report),

              const SizedBox(height: 10),

              _OutcomeExplanation(theme: theme, report: report),

              const SizedBox(height: 14),

              _InheritanceMechanicsSection(theme: theme, report: report),

              // if ((report['specialEvents'] as List?)?.isNotEmpty ?? false) ...[
              //   const SizedBox(height: 14),
              //   _SpecialEventsSection(theme: theme, report: report),
              // ],
              const SizedBox(height: 14),

              _InheritedTraitsSimple(theme: theme, analysis: report),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// Summary Banner
// ============================================================================

class _SummaryBanner extends StatelessWidget {
  final FactionTheme theme;
  final Map<String, dynamic> report;

  const _SummaryBanner({required this.theme, required this.report});

  @override
  Widget build(BuildContext context) {
    final summaryLine = report['summaryLine'] as String? ?? '';

    if (summaryLine.isEmpty) return const SizedBox.shrink();

    final parts = summaryLine.split(':');
    final cross = parts.isNotEmpty ? parts[0].trim() : summaryLine;
    final description = parts.length > 1 ? parts[1].trim() : '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(color: theme.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cross,
            style: TextStyle(
              color: theme.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Outcome Badge
// ============================================================================

class _OutcomeBadge extends StatelessWidget {
  final FactionTheme theme;
  final Map<String, dynamic> report;

  const _OutcomeBadge({required this.theme, required this.report});

  @override
  Widget build(BuildContext context) {
    final outcomeCategory = report['outcomeCategory'] as String? ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),

      child: Text(
        outcomeCategory,
        style: TextStyle(
          color: _outcomeColor(outcomeCategory),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static Color _outcomeColor(String category) {
    switch (category) {
      case 'Expected':
        return Colors.green;
      case 'Somewhat Unexpected':
        return Colors.lightBlue;
      case 'Surprising':
        return Colors.orange;
      case 'Rare':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

// ============================================================================
// Outcome Explanation
// ============================================================================

class _OutcomeExplanation extends StatelessWidget {
  final FactionTheme theme;
  final Map<String, dynamic> report;

  const _OutcomeExplanation({required this.theme, required this.report});

  @override
  Widget build(BuildContext context) {
    final explanation = report['outcomeExplanation'] as String? ?? '';

    if (explanation.isEmpty) return const SizedBox.shrink();

    return Text(
      explanation,
      style: TextStyle(color: theme.text, fontSize: 11, height: 1.4),
    );
  }
}

// ============================================================================
// Inheritance Mechanics Section
// ============================================================================

class _InheritanceMechanicsSection extends StatelessWidget {
  final FactionTheme theme;
  final Map<String, dynamic> report;

  const _InheritanceMechanicsSection({
    required this.theme,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final mechanics =
        (report['inheritanceMechanics'] as List?)
            ?.map((m) => m as Map<String, dynamic>)
            .toList() ??
        [];

    // IMPORTANT: we are NOT filtering anything out anymore.
    // Every mechanic (Size, Color Tinting, etc.) shows.

    if (mechanics.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INHERITANCE MECHANICS',
          style: TextStyle(
            color: theme.primary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 10),
        ...mechanics.map((mechanic) {
          return _MechanicCard(theme: theme, mechanic: mechanic);
        }).toList(),
      ],
    );
  }
}

// ============================================================================
// Mechanic Card
// ============================================================================

class _MechanicCard extends StatelessWidget {
  final FactionTheme theme;
  final Map<String, dynamic> mechanic;

  const _MechanicCard({required this.theme, required this.mechanic});

  @override
  Widget build(BuildContext context) {
    final category = mechanic['category'] as String? ?? '';
    final result = mechanic['result'] as String? ?? '';
    final mechanism = mechanic['mechanism'] as String? ?? '';
    final percentage = (mechanic['percentage'] as num?)?.toDouble() ?? 0.0;
    final likelihood = mechanic['likelihood'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: theme.border.withOpacity(.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_categoryIcon(category), size: 14, color: theme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$category: $result',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _LikelihoodBadge(
                  theme: theme,
                  likelihood: likelihood,
                  percentage: percentage,
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              mechanism,
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _categoryIcon(String category) {
    switch (category) {
      case 'Species':
        return Icons.pets;
      case 'Family Lineage':
        return Icons.family_restroom;
      case 'Elemental Type':
        return Icons.whatshot;
      case 'Color Tinting':
        return Icons.palette;
      case 'Size':
        return Icons.straighten;
      case 'Patterning':
        return Icons.gradient;
      case 'Nature':
        return Icons.psychology;
      default:
        return Icons.info_outline;
    }
  }
}

// ============================================================================
// Likelihood Badge
// ============================================================================

class _LikelihoodBadge extends StatelessWidget {
  final FactionTheme theme;
  final int likelihood;
  final double percentage;

  const _LikelihoodBadge({
    required this.theme,
    required this.likelihood,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final color = _likelihoodColor(likelihood);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static Color _likelihoodColor(int likelihood) {
    switch (likelihood) {
      case 3:
        return Colors.green;
      case 2:
        return Colors.lightBlue;
      case 1:
        return Colors.orange;
      case 0:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

// ============================================================================
// Inherited trait justifications
// ============================================================================

class _InheritedTraitsSimple extends StatelessWidget {
  final FactionTheme theme;
  final Map<String, dynamic> analysis;

  const _InheritedTraitsSimple({required this.theme, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final traitJustifications = analysis['traitJustifications'] as List? ?? [];

    if (traitJustifications.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INHERITED TRAITS',
          style: TextStyle(
            color: theme.primary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 8),
        ...traitJustifications.map((raw) {
          final trait = raw as Map;
          final traitName = trait['trait'] as String;
          final actualValue = trait['actualValue'] as String;
          final category = trait['category'] as String;
          final mechanism = trait['mechanism'] as String;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.primary.withOpacity(.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    _categoryIcon(category),
                    size: 12,
                    color: theme.primary,
                  ),
                ),
                const SizedBox(width: 8),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$traitName: $actualValue',
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        mechanism,
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  static IconData _categoryIcon(String category) {
    switch (category) {
      case 'familyLineage':
        return Icons.family_restroom;
      case 'elementalType':
        return Icons.whatshot;
      case 'genetics':
        return Icons.biotech;
      case 'nature':
        return Icons.psychology;
      case 'special':
        return Icons.star;
      default:
        return Icons.info;
    }
  }
}

// ============================================================================
// PARENT CARD
// ============================================================================

class _ParentCard extends StatelessWidget {
  final FactionTheme theme;
  final ParentSnapshot snap;
  final String parentKey;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _ParentCard({
    required this.theme,
    required this.snap,
    required this.parentKey,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(.12)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: snap.spriteData != null
                          ? CreatureSprite(
                              spritePath: snap.spriteData!.spriteSheetPath,
                              totalFrames: snap.spriteData!.totalFrames,
                              rows: snap.spriteData!.rows,
                              frameSize: Vector2(
                                snap.spriteData!.frameWidth.toDouble(),
                                snap.spriteData!.frameHeight.toDouble(),
                              ),
                              stepTime:
                                  snap.spriteData!.frameDurationMs / 1000.0,
                              scale: scaleFromGenes(snap.genetics),
                              saturation: satFromGenes(snap.genetics),
                              brightness: briFromGenes(snap.genetics),
                              hueShift: hueFromGenes(snap.genetics),
                              isPrismatic: snap.isPrismaticSkin,
                            )
                          : Image.asset(snap.image, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          snap.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          snap.types.join(' • '),
                          style: TextStyle(
                            color: theme.text.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          snap.rarity,
                          style: TextStyle(
                            color: theme.text.withOpacity(0.6),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Row(
                    children: [
                      if (snap.isPrismaticSkin)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade400.withOpacity(.3),
                                Colors.purple.shade600.withOpacity(.3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.purple.withOpacity(.4),
                            ),
                          ),
                          child: const Text(
                            'P',
                            style: TextStyle(
                              color: Colors.purple,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more,
                          color: theme.primary.withOpacity(.6),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          ClipRect(
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeInOut,
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Column(
                children: [
                  Divider(color: theme.border, height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _ParentSubSection(
                          theme: theme,
                          title: 'Genetic Profile',
                          children: [
                            if (snap.genetics?.get('size') != null)
                              _LabeledInlineValue(
                                label: 'Size Variant',
                                valueColor: theme.text,
                                valueText:
                                    sizeLabels[snap.genetics!.get('size')] ??
                                    'Standard',
                              ),
                            if (snap.genetics?.get('tinting') != null)
                              _LabeledInlineValue(
                                label: 'Pigmentation',
                                valueColor: theme.text,
                                valueText:
                                    tintLabels[snap.genetics!.get('tinting')] ??
                                    'Standard',
                              ),
                            if (snap.nature != null)
                              _LabeledInlineValue(
                                valueColor: theme.text,
                                label: 'Behavior',
                                valueText: snap.nature!.id,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PARENT SUBSECTION
// ============================================================================

class _ParentSubSection extends StatelessWidget {
  final FactionTheme theme;
  final String title;
  final List<Widget> children;

  const _ParentSubSection({
    required this.theme,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: theme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.02),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
