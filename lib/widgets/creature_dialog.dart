import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flame/components.dart';

import 'package:alchemons/widgets/creature_detail/detail_helper_widgets.dart';
import 'package:alchemons/widgets/creature_detail/lineage_block_widget.dart';
import 'package:alchemons/widgets/creature_detail/outcome_widget.dart';
import 'package:alchemons/widgets/creature_detail/parent_display_widget.dart';
import 'package:alchemons/widgets/creature_detail/section_block.dart';
import 'package:alchemons/widgets/creature_detail/stats_potential_widget.dart';
import 'package:alchemons/widgets/creature_detail/unknow_helper.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/nature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
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

  /// We render immediately with the base creature; if an instance is provided
  /// we hydrate it and update this field (with a soft fade) without changing the
  /// dialog size/layout.
  late Creature _effectiveCreature;

  /// While we’re hydrating the instance variant, show subtle placeholders but do
  /// NOT change the outer dialog.
  bool _hydratingInstance = false;

  final Set<String> _expandedParents = {};
  int _currentImageIndex = 0;

  CreatureInstance? _instance; // << keep instance row once
  int? _instanceLevel;

  @override
  void initState() {
    super.initState();
    _effectiveCreature = widget.creature;

    _tabController = TabController(
      length: widget.isDiscovered ? 2 : 1,
      vsync: this,
    );

    _pageController = PageController(viewportFraction: 1.0);
    _analysisScrollController = ScrollController();

    // If we have an instance, hydrate asynchronously but keep the same shell.
    if (widget.instanceId != null) {
      _hydrateFromInstance(widget.instanceId!);
    }
  }

  Future<void> _hydrateFromInstance(String instanceId) async {
    _hydratingInstance = true;
    if (mounted) setState(() {});

    try {
      final db = context.read<AlchemonsDatabase>();
      final repo = context.read<CreatureCatalog>();

      final row = await db.creatureDao.getInstance(instanceId);
      if (row == null) throw Exception('Instance not found');

      _instance = row; // store for children
      _instanceLevel = row.level;

      final base = repo.getCreatureById(row.baseId);
      if (base == null) {
        throw Exception('Catalog creature ${row.baseId} not loaded');
      }

      _effectiveCreature = _hydrateCatalogCreature(base, row, repo);
    } catch (_) {
      // Fall back to base creature; still stop the "hydrating" state.
    } finally {
      if (!mounted) return;
      _hydratingInstance = false;
      setState(() {});
    }
  }

  Creature _hydrateCatalogCreature(
    Creature base,
    CreatureInstance row,
    CreatureCatalog repo,
  ) {
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

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    _analysisScrollController.dispose();
    super.dispose();
  }

  // ---- data prep helpers ----------------------------------------------------

  Parentage? _decodeParentage(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return Parentage.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggleLock() async {
    final i = _instance;
    if (i == null) return;
    final db = context.read<AlchemonsDatabase>();
    await db.creatureDao.setLocked(i.instanceId, !i.locked);
    // refresh instance so UI updates
    await _hydrateFromInstance(i.instanceId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(!i.locked ? 'Locked' : 'Unlocked'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _editNickname() async {
    final i = _instance;
    if (i == null) return;
    final theme = context.read<FactionTheme>();

    final controller = TextEditingController(text: i.nickname ?? '');
    final newName = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Set Nickname', style: TextStyle(color: theme.text)),
          content: TextField(
            style: TextStyle(color: theme.text),
            controller: controller,
            maxLength: 24,
            decoration: InputDecoration(
              hintText: 'Enter nickname (leave blank to clear)',
              fillColor: Colors.white,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName == null) return; // cancelled

    final db = context.read<AlchemonsDatabase>();
    // Empty string → clear nickname (null)
    final normalized = newName.isEmpty ? null : newName;
    await db.creatureDao.setNickname(i.instanceId, normalized);
    await _hydrateFromInstance(i.instanceId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          normalized == null ? 'Nickname cleared' : 'Nickname saved',
        ),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  // ---- build root -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final factionTheme = context.read<FactionTheme>();

    // Always render the full dialog shell. Internals can show loading states.
    return _buildDialogShell(
      factionTheme,
      _effectiveCreature,
      hydrating: _hydratingInstance,
      instance: _instance,
    );
  }

  // ---- outer shell (header + tabs + body scroll) ---------------------------

  Widget _buildDialogShell(
    FactionTheme theme,
    Creature effective, {
    required bool hydrating,
    required CreatureInstance? instance,
  }) {
    final discovered = widget.isDiscovered;

    return Dialog(
      insetPadding: const EdgeInsets.all(2),
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.border, width: 1.5),
          // Slightly lighter shadows to avoid GPU stalls on first frame.
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.55),
              blurRadius: 28,
              spreadRadius: 6,
              offset: const Offset(0, 10),
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
              instance: instance, // NEW
              onClose: () => Navigator.of(context).pop(),
              onToggleLock: instance == null ? null : _toggleLock, // NEW
              onEditNickname: instance == null ? null : _editNickname, // NEW
            ),
            if (discovered)
              _DialogTabSelector(theme: theme, tabController: _tabController),
            Expanded(
              child: discovered
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        // Use AnimatedSwitcher so hydrated content fades in
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: _OverviewScrollArea(
                            key: ValueKey(
                              '${effective.id}-${hydrating ? 'loading' : 'ready'}',
                            ),
                            theme: theme,
                            instanceId: widget.instanceId,
                            instanceLevel: _instanceLevel,
                            instance: instance,
                            creature: effective,
                            pageController: _pageController,
                            currentImageIndex: _currentImageIndex,
                            onPageChanged: (i) {
                              setState(() {
                                _currentImageIndex = i;
                              });
                            },
                          ),
                        ),
                        _AnalysisScrollArea(
                          theme: theme,
                          parentage: effective.parentage,
                          controller: _analysisScrollController,
                          creature: effective,
                          isInstance: instance != null,
                          instance: instance,
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
                  : UnknownScrollArea(theme: theme),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HEADER BAR (unchanged except lighter shadow)
// ============================================================================

class _DialogHeaderBar extends StatelessWidget {
  final FactionTheme theme;
  final Creature creature;
  final CreatureInstance? instance; // NEW: if present, shows nickname/lock
  final int? level;
  final VoidCallback onClose;
  final VoidCallback? onToggleLock; // NEW
  final VoidCallback? onEditNickname; // NEW

  const _DialogHeaderBar({
    required this.theme,
    required this.creature,
    required this.level,
    required this.onClose,
    this.instance,
    this.onToggleLock,
    this.onEditNickname,
  });

  @override
  Widget build(BuildContext context) {
    final hasNickname =
        (instance?.nickname != null && instance!.nickname!.trim().isNotEmpty);
    final displayName = (hasNickname ? instance!.nickname! : creature.name)
        .toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: theme.surfaceAlt,
        border: Border(bottom: BorderSide(color: theme.border, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left glyph (unchanged visual)
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
                width: 1.2,
              ),
            ),
            child: Icon(Icons.biotech_rounded, color: theme.primary, size: 18),
          ),
          const SizedBox(width: 12),

          // Title + subtitle + (optional) lock button
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Title (tap to edit nickname when instance present)
                    Expanded(
                      child: GestureDetector(
                        onTap: onEditNickname, // null-safe: no-op if null
                        child: Text(
                          displayName,
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
                    ),

                    // Level badge (if provided)
                    if (level != null)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
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
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),

                Row(
                  children: [
                    // Subtitle: species name if nicknamed, else default subtitle
                    Expanded(
                      child: Text(
                        hasNickname
                            ? creature.name
                            : 'Specimen analysis report',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // Lock toggle (only if instance provided)
                    if (instance != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onToggleLock,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.border),
                          ),
                          child: Icon(
                            instance!.locked
                                ? Icons.lock_rounded
                                : Icons.lock_open_rounded,
                            color: instance!.locked
                                ? theme.primary
                                : theme.textMuted,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Close button (unchanged)
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
// TAB SELECTOR (unchanged)
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
              width: 1.2,
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
// OVERVIEW TAB (now consumes the instance directly)
// ============================================================================

class _OverviewScrollArea extends StatelessWidget {
  final FactionTheme theme;
  final Creature creature;
  final String? instanceId;
  final int? instanceLevel;
  final CreatureInstance? instance; // << NEW

  final PageController pageController;
  final int currentImageIndex;
  final ValueChanged<int> onPageChanged;

  const _OverviewScrollArea({
    super.key,
    required this.theme,
    required this.creature,
    required this.instanceId,
    required this.instanceLevel,
    required this.instance,
    required this.pageController,
    required this.currentImageIndex,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final List<Creature> entries = [creature];
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: _CreatureCarousel(
              theme: theme,
              entries: entries,
              pageController: pageController,
              currentIndex: currentImageIndex,
              onChanged: onPageChanged,
              instance: instance,
            ),
          ),
          const SizedBox(height: 20),

          if (instance != null) ...[
            SectionBlock(
              theme: theme,
              title: 'Specimen Status',
              child: Column(
                children: [
                  if (instanceLevel != null)
                    LabeledInlineValue(
                      label: 'Level',
                      valueText: '$instanceLevel',
                      valueColor: theme.primary,
                    ),
                  LabeledInlineValue(
                    label: 'Nickname',
                    valueText: (instance!.nickname?.isNotEmpty ?? false)
                        ? instance!.nickname!
                        : '—',
                    valueColor: theme.text,
                  ),
                  LabeledInlineValue(
                    label: 'Lock',
                    valueText: instance!.locked ? 'Locked' : 'Unlocked',
                    valueColor: instance!.locked
                        ? theme.primary
                        : theme.textMuted,
                  ),
                  StaminaInlineRow(
                    theme: theme,
                    label: 'Energy Level',
                    instanceId: instance!.instanceId,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ✨ ADD THE NEW DISCOVERY / SOURCE BLOCK HERE
            SectionBlock(
              theme: theme,
              title: 'Source / Discovery',
              child: Column(
                children: [
                  LabeledInlineValue(
                    label: 'Source Type',
                    // Assuming 'creationSource' is a field on CreatureInstance
                    valueText: _formatSource(instance!.source),
                    valueColor: theme.text,
                  ),
                  LabeledInlineValue(
                    label: 'Creation Date',
                    // Assuming 'createdAt' is a field on CreatureInstance (as a UTC timestamp in milliseconds)
                    valueText: _formatCreationDate(instance!.createdAtUtcMs),
                    valueColor: theme.text,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (instance?.variantFaction != null &&
              instance!.variantFaction!.isNotEmpty)
            Column(
              children: [
                SectionBlock(
                  theme: theme,
                  title: 'VARIANT',
                  child: LabeledInlineValue(
                    label: 'Type',
                    valueText: (instance!.variantFaction ?? 'Unknown')
                        .toUpperCase(),
                    valueColor: theme.text,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),

          SectionBlock(
            theme: theme,
            title: 'Specimen Classification',
            child: Column(
              children: [
                LabeledInlineValue(
                  label: 'Classification',
                  valueText: creature.rarity,
                  valueColor: theme.text,
                ),
                LabeledInlineValue(
                  label: 'Type Categories',
                  valueText: creature.types.join(', '),
                  valueColor: theme.text,
                ),
                if (creature.description.isNotEmpty)
                  LabeledInlineValue(
                    label: 'Description',
                    valueText: creature.description,
                    valueColor: theme.text,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (instance != null)
            Column(
              children: [
                SectionBlock(
                  theme: theme,
                  title: 'Physical Attributes',
                  child: Column(
                    children: [
                      StatBarRow(
                        theme: theme,
                        label: 'Speed',
                        value: instance!.statSpeed,
                      ),
                      StatBarRow(
                        theme: theme,
                        label: 'Intelligence',
                        value: instance!.statIntelligence,
                      ),
                      StatBarRow(
                        theme: theme,
                        label: 'Strength',
                        value: instance!.statStrength,
                      ),
                      StatBarRow(
                        theme: theme,
                        label: 'Beauty',
                        value: instance!.statBeauty,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),

          SectionBlock(
            theme: theme,
            title: 'Genetic Profile',
            child: Column(
              children: [
                LabeledInlineValue(
                  label: 'Size Variant',
                  valueText: _sizeLabels(creature),
                  valueColor: theme.text,
                ),
                LabeledInlineValue(
                  label: 'Pigmentation',
                  valueText: _tintLabels(creature),
                  valueColor: theme.text,
                ),
                if (creature.nature != null)
                  LabeledInlineValue(
                    label: 'Behavioral Pattern',
                    valueText: creature.nature!.id,
                    valueColor: theme.text,
                  ),
                if (creature.isPrismaticSkin == true)
                  LabeledInlineValue(
                    label: 'Special Trait',
                    valueText: 'Prismatic Phenotype',
                    valueColor: theme.text,
                  ),
              ],
            ),
          ),

          if (creature.specialBreeding != null) ...[
            const SizedBox(height: 16),
            SectionBlock(
              theme: theme,
              title: 'Synthesis Requirements',
              child: Column(
                children: [
                  const LabeledInlineValue(
                    label: 'Method',
                    valueText: 'Specialized Genetic Fusion',
                  ),
                  LabeledInlineValue(
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
    final mapLabel = sizeLabels[c.genetics?.get('size') ?? 'Normal'];
    return mapLabel ?? 'Standard';
  }

  String _tintLabels(Creature c) {
    final mapLabel = tintLabels[c.genetics?.get('tinting') ?? 'Normal'];
    return mapLabel ?? 'Standard';
  }
}

// ============================================================================
// ANALYSIS TAB (reads the same instance)
// ============================================================================

class _AnalysisScrollArea extends StatelessWidget {
  final FactionTheme theme;
  final ScrollController controller;
  final Creature creature;
  final bool isInstance;
  final CreatureInstance? instance; // << NEW
  final Set<String> isExpandedMap;
  final void Function(String parentKey) onToggleParent;
  final String? instanceId;
  final Parentage? parentage;
  const _AnalysisScrollArea({
    required this.theme,
    required this.controller,
    required this.creature,
    required this.isInstance,
    required this.instance,
    required this.isExpandedMap,
    required this.onToggleParent,
    required this.instanceId,
    required this.parentage,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionBlock(
            theme: theme,
            title: 'Behavioral Analysis',
            child: _BehaviorBlock(creature: creature, textColor: theme.text),
          ),
          const SizedBox(height: 16),
          SectionBlock(
            theme: theme,
            title: 'Genetic Analysis',
            child: _GeneticsBlock(creature: creature, textColor: theme.text),
          ),
          const SizedBox(height: 16),

          if (isInstance && instanceId != null)
            StatPotentialBlock(theme: theme, instanceId: instanceId),
          if (isInstance) const SizedBox(height: 16),

          if (isInstance && instance != null) ...[
            SectionBlock(
              theme: theme,
              title: 'Lineage',
              child: LineageBlock(theme: theme, instance: instance!),
            ),
            const SizedBox(height: 16),
          ],

          if (parentage != null) ...[
            SectionBlock(
              theme: theme,
              title: 'Synthesis Information',
              child: Column(
                children: [
                  LabeledInlineValue(
                    label: 'Method',
                    valueText: 'Genetic Fusion',
                    valueColor: theme.text,
                  ),
                  LabeledInlineValue(
                    label: 'Date',
                    valueText: _formatBreedLine(parentage!),
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

            ParentCard(
              theme: theme,
              snap: parentage!.parentA,
              parentKey: 'parentA',
              isExpanded: isExpandedMap.contains('parentA'),
              onToggle: () => onToggleParent('parentA'),
            ),
            const SizedBox(height: 10),
            ParentCard(
              theme: theme,
              snap: parentage!.parentB,
              parentKey: 'parentB',
              isExpanded: isExpandedMap.contains('parentB'),
              onToggle: () => onToggleParent('parentB'),
            ),
          ] else ...[
            SectionBlock(
              theme: theme,
              title: 'Acquisition Method',
              child: Column(
                children: const [
                  LabeledInlineValue(
                    label: 'Source',
                    valueText: 'Field Research',
                  ),
                  LabeledInlineValue(
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
// SMALL BUILDING BLOCKS / SUBWIDGETS
// ============================================================================

class _CreatureCarousel extends StatelessWidget {
  final FactionTheme theme;
  final PageController pageController;
  final int currentIndex;
  final List<Creature> entries;
  final ValueChanged<int> onChanged;
  final CreatureInstance? instance; // << NEW

  const _CreatureCarousel({
    required this.theme,
    required this.pageController,
    required this.currentIndex,
    required this.entries,
    required this.onChanged,
    this.instance,
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
              final creature = entries[i];
              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: instance == null
                      ? CreatureSprite(
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
                        )
                      : InstanceSprite(
                          creature: creature,
                          instance: instance!, // **always use instance sprite**
                          size: 72,
                        ),
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

// ============================================================================
// Behavior / Genetics / Breeding (unchanged from your version)
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
          LabeledInlineValue(
            label: 'Nature Type',
            valueText: n.id,
            valueColor: textColor,
          ),
          if (n.effect.modifiers.isNotEmpty)
            LabeledInlineValue(
              label: 'Active Effects',
              valueText: _formatNatureEffects(n.effect),
              valueColor: textColor,
            )
          else
            LabeledInlineValue(
              label: 'Effects',
              valueText: 'No special behavioral modifications known',
              valueColor: textColor,
            ),
        ],
      );
    } else {
      return LabeledInlineValue(
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
          LabeledInlineValue(
            label: 'Genetic Profile',
            valueText: 'Standard genotype - no variants detected',
            valueColor: textColor,
          ),
          LabeledInlineValue(
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
          LabeledInlineValue(
            label: 'Size Gene',
            valueText: sizeGene,
            valueColor: textColor,
          ),
        ] else ...[
          LabeledInlineValue(
            label: 'Size Gene',
            valueText: 'Normal',
            valueColor: textColor,
          ),
        ],
        if (tintGene != null) ...[
          LabeledInlineValue(
            label: 'Coloration',
            valueText: tintLabels[tintGene] ?? 'Unknown',
            valueColor: textColor,
          ),
          LabeledInlineValue(
            label: 'Color',
            valueText: _getGeneticDescription('tinting', tintGene),
            valueColor: textColor,
          ),
        ] else ...[
          LabeledInlineValue(
            label: 'Coloration Gene',
            valueText: 'Standard',
            valueColor: textColor,
          ),
          LabeledInlineValue(
            label: 'Color Expression',
            valueText: 'Natural coloration',
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
// BREEDING (unchanged, reads the same instanceId)
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
      final instance = await db.creatureDao.getInstance(instanceId);
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
          return SectionBlock(
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
        return SectionBlock(
          theme: theme,
          title: 'Breeding Analysis',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryBanner(theme: theme, report: report),
              const SizedBox(height: 12),
              OutcomeBadge(theme: theme, report: report),
              const SizedBox(height: 10),
              OutcomeExplanation(theme: theme, report: report),
              const SizedBox(height: 14),
              _InheritanceMechanicsSection(theme: theme, report: report),
              const SizedBox(height: 14),
              _InheritedTraitsSimple(theme: theme, analysis: report),
            ],
          ),
        );
      },
    );
  }
}

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

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(color: theme.surfaceAlt),
      child: Text(
        cross,
        style: TextStyle(
          color: theme.text,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

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
        ...mechanics.map((m) => _MechanicCard(theme: theme, mechanic: m)),
      ],
    );
  }
}

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
          borderRadius: BorderRadius.circular(6),
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
      child: Text(
        '${percentage.toStringAsFixed(0)}%',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
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

class _InheritedTraitsSimple extends StatelessWidget {
  final FactionTheme theme;
  final Map<String, dynamic> analysis;

  const _InheritedTraitsSimple({required this.theme, required this.analysis});

  IconData categoryIcon(String category) =>
      _MechanicCard._categoryIcon(category);

  @override
  Widget build(BuildContext context) {
    final traitJustifications = analysis['traitJustifications'] as List? ?? [];
    if (traitJustifications.isEmpty) return const SizedBox.shrink();

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
                    categoryIcon(category),
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
}

String _formatSource(String source) {
  switch (source) {
    case 'wild_capture':
      return 'Wild Capture';
    case 'wild_breeding':
      return 'Wild Bred';
    case 'breeding_vial':
      return 'Vial Bred';
    case 'starter':
      return 'Starter';
    case 'quest':
      return 'Quest Reward';
    default:
      return 'Discovery'; // Fallback for 'discovery' or unknown
  }
}

String _formatCreationDate(int? timestampMs) {
  if (timestampMs == null) return 'Unknown';
  final date = DateTime.fromMillisecondsSinceEpoch(
    timestampMs,
    isUtc: true,
  ).toLocal();
  // Example format: 11/10/2025 10:45 PM
  return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
