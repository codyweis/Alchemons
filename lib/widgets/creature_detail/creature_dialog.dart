// lib/widgets/creature_detail/creature_dialog.dart
//
// REDESIGNED CREATURE DETAILS DIALOG
// Aesthetic: Scorched Forge — matches survival / boss / formation screens
// Dark metal panels, amber reagent accents, monospace tactical typography
// All logic preserved exactly.
//

import 'dart:convert';
import 'dart:async';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/constants/creature_details_tutorials.dart';
import 'package:alchemons/widgets/creature_detail/battle_tab.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flame/components.dart';

import 'package:alchemons/widgets/creature_detail/lineage_block_widget.dart';
import 'package:alchemons/widgets/creature_detail/outcome_widget.dart';
import 'package:alchemons/widgets/creature_detail/parent_display_widget.dart';
import 'package:alchemons/widgets/creature_detail/stats_potential_widget.dart';
import 'package:alchemons/widgets/creature_detail/unknow_helper.dart';
import 'package:alchemons/widgets/tutorial_step.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:alchemons/widgets/wilderness/tutorial_highlight.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/models/nature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/utils/instance_purity_util.dart';
import 'package:alchemons/widgets/creature_sprite.dart';

import '../../models/creature.dart';

// ──────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ──────────────────────────────────────────────────────────────────────────────

class _C {
  _C(FactionTheme theme) : _t = ForgeTokens(theme);
  final ForgeTokens _t;
  static _C of(BuildContext context) => _C(context.read<FactionTheme>());
  bool get isDark => _t.isDark;

  Color get bg0 => _t.bg0;
  Color get bg1 => _t.bg1;
  Color get bg2 => _t.bg2;
  Color get bg3 => _t.bg3;
  Color get amber => _t.amber;
  Color get amberBright => _t.amberBright;
  Color get amberDim => _t.amberDim;
  Color get amberGlow => _t.amberGlow;
  Color get teal => _t.teal;
  Color get success => _t.success;
  Color get danger => _t.danger;
  Color get textPrimary => _t.textPrimary;
  Color get textSecondary => _t.textSecondary;
  Color get textMuted => _t.textMuted;
  Color get borderDim => _t.borderDim;
  Color get borderMid => _t.borderMid;
  Color get borderAccent => _t.borderAccent;
  Color get onAccent => _t.onAccent;
  Color onColor(Color background) => _t.onColor(background);
}

class _T {
  _T(this._c);
  final _C _c;

  TextStyle get heading => TextStyle(
    fontFamily: 'monospace',
    color: _c.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
  );

  TextStyle get label => TextStyle(
    fontFamily: 'monospace',
    color: _c.textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
  );

  TextStyle get body =>
      TextStyle(color: _c.textSecondary, fontSize: 12, height: 1.5);

  TextStyle get sectionTitle => TextStyle(
    fontFamily: 'monospace',
    color: _c.amberBright,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.0,
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// SHARED MICRO WIDGETS
// ──────────────────────────────────────────────────────────────────────────────

class _EtchedDivider extends StatelessWidget {
  final String? label;
  const _EtchedDivider({this.label});
  @override
  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final t = _T(c);
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: c.borderMid)),
        if (label != null) ...[
          const SizedBox(width: 10),
          Text(label!, style: t.label),
          const SizedBox(width: 10),
        ],
        Expanded(child: Container(height: 1, color: c.borderMid)),
      ],
    );
  }
}

/// Flat analysis section — label + thin rule, no box or background
class _AnalysisSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Color? accentColor;

  const _AnalysisSection({
    required this.title,
    required this.child,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final t = _T(c);
    final accent = accentColor ?? c.amber;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 3, height: 10, color: accent),
            const SizedBox(width: 7),
            Text(
              title.toUpperCase(),
              style: t.sectionTitle.copyWith(color: accent),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Container(height: 1, color: c.borderDim),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// Returns the signature color for a variant faction name.
Color _variantFactionColor(String faction) => switch (faction.toLowerCase()) {
  'volcanic' => const Color(0xFFFF5722),
  'oceanic' => const Color(0xFF2196F3),
  'earthen' => const Color(0xFF795548),
  'verdant' => const Color(0xFF4CAF50),
  'arcane' => const Color(0xFF9C27B0),
  _ => const Color(0xFF0EA5E9), // teal fallback
};

/// Lozenge badge — rarity / type tag
class _TagBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _TagBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
    ),
    child: Text(
      label.toUpperCase(),
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

/// Flat data row — label + value
class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DataRow({required this.label, required this.value, this.valueColor});
  @override
  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final t = _T(c);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label.toUpperCase(), style: t.label),
          ),
          Expanded(
            child: Text(
              value,
              style: t.body.copyWith(
                color: valueColor ?? c.textPrimary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Forge-style section container with etched header
class _ForgeSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Color? accentColor;

  const _ForgeSection({
    required this.title,
    required this.child,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final t = _T(c);
    final accent = accentColor ?? c.amber;
    return Container(
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: c.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: c.bg3,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
              border: Border(bottom: BorderSide(color: c.borderDim)),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 10,
                  color: accent,
                  margin: const EdgeInsets.only(right: 8),
                ),
                Text(
                  title.toUpperCase(),
                  style: t.sectionTitle.copyWith(color: accent),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black.withValues(alpha: 0.06);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ──────────────────────────────────────────────────────────────────────────────
// MAIN WIDGET
// ──────────────────────────────────────────────────────────────────────────────

class CreatureDetailsDialog extends StatefulWidget {
  final Creature creature;
  final bool isDiscovered;
  final String? instanceId;
  final bool openBattleTab;

  const CreatureDetailsDialog({
    super.key,
    required this.creature,
    required this.isDiscovered,
    this.instanceId,
    this.openBattleTab = false,
  });

  @override
  State<CreatureDetailsDialog> createState() => _CreatureDetailsDialogState();

  static Future<void> show(
    BuildContext context,
    Creature creature,
    bool isDiscovered, {
    String? instanceId,
    bool openBattleTab = false,
  }) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (context) => CreatureDetailsDialog(
        creature: creature,
        isDiscovered: isDiscovered || instanceId != null,
        instanceId: instanceId,
        openBattleTab: openBattleTab,
      ),
    );
  }
}

class _CreatureDetailsDialogState extends State<CreatureDetailsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  late ScrollController _analysisScrollController;
  final GlobalKey _behaviorSectionKey = GlobalKey();
  final GlobalKey _potentialSectionKey = GlobalKey();
  final GlobalKey _lineageSectionKey = GlobalKey();
  final GlobalKey _breedingAnalysisSectionKey = GlobalKey();

  late Creature _effectiveCreature;
  bool _hydratingInstance = false;
  bool _showingAnalyzerTutorial = false;
  Set<CreatureDetailsTutorialTarget> _activeTutorialTargets =
      <CreatureDetailsTutorialTarget>{};

  final Set<String> _expandedParents = {};
  int _currentImageIndex = 0;

  CreatureInstance? _instance;
  int? _instanceLevel;

  int _initialTabIndex() {
    if (!widget.isDiscovered) return 0;
    if (widget.openBattleTab && widget.instanceId != null) return 2;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _effectiveCreature = widget.creature;
    _tabController = TabController(
      length: widget.isDiscovered ? 3 : 1,
      vsync: this,
      initialIndex: _initialTabIndex(),
    );
    _pageController = PageController(viewportFraction: 1.0);
    _analysisScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowPendingAnalyzerTutorials();
    });
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
      _instance = row;
      _instanceLevel = row.level;
      final base = repo.getCreatureById(row.baseId);
      if (base == null) {
        throw Exception('Catalog creature ${row.baseId} not loaded');
      }
      _effectiveCreature = _hydrateCatalogCreature(base, row, repo);
    } catch (_) {
      // fall back to base creature
    } finally {
      if (mounted) {
        _hydratingInstance = false;
        setState(() {});
        unawaited(_maybeShowPendingAnalyzerTutorials());
      }
    }
  }

  Creature _hydrateCatalogCreature(
    Creature base,
    CreatureInstance row,
    CreatureCatalog repo,
  ) {
    var out = base;
    if (row.isPrismaticSkin == true) out = out.copyWith(isPrismaticSkin: true);
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

  Parentage? _decodeParentage(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return Parentage.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _maybeShowPendingAnalyzerTutorials() async {
    if (!mounted || _showingAnalyzerTutorial) return;

    final db = context.read<AlchemonsDatabase>();
    final pendingEntries = await Future.wait(
      CreatureDetailsTutorialTarget.values.map((target) async {
        final isPending =
            await db.settingsDao.getSetting(target.settingKey) == '1';
        return (target: target, isPending: isPending);
      }),
    );

    final eligibleTargets =
        pendingEntries
            .where((entry) => entry.isPending)
            .map((entry) => entry.target)
            .where(
              (target) =>
                  !target.requiresInstance ||
                  (_instance != null && widget.instanceId != null),
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (eligibleTargets.isEmpty) return;

    _showingAnalyzerTutorial = true;
    if (mounted) {
      setState(() {
        _activeTutorialTargets = {
          ..._activeTutorialTargets,
          ...eligibleTargets,
        };
      });
    }

    if (widget.isDiscovered &&
        _tabController.length > 1 &&
        _tabController.index != 1) {
      _tabController.animateTo(1);
      await Future<void>.delayed(const Duration(milliseconds: 240));
    }

    if (!mounted) return;
    await _showAnalyzerTutorialDialog(eligibleTargets);
    if (!mounted) return;

    for (final target in eligibleTargets) {
      await db.settingsDao.deleteSetting(target.settingKey);
    }

    await _scrollToTutorialTarget(eligibleTargets.first);
    _showingAnalyzerTutorial = false;
  }

  Future<void> _showAnalyzerTutorialDialog(
    List<CreatureDetailsTutorialTarget> targets,
  ) async {
    final c = _C.of(context);
    final theme = context.read<FactionTheme>();
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: c.bg1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: c.borderDim),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          title: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: c.amberBright),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  targets.length == 1
                      ? '${targets.first.title} Unlocked'
                      : 'New Creature Analysis Unlocked',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creature Details has new analysis data. The highlighted panels below are where those unlocks now appear.',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...targets.map(
                (target) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TutorialStep(
                    theme: theme,
                    icon: Icons.visibility_rounded,
                    title: target.title,
                    body: target.tutorialBody,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Show me',
                style: TextStyle(
                  color: c.amberBright,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _scrollToTutorialTarget(
    CreatureDetailsTutorialTarget target,
  ) async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = switch (target) {
        CreatureDetailsTutorialTarget.geneAnalyzer => _behaviorSectionKey,
        CreatureDetailsTutorialTarget.potentialAnalyzer => _potentialSectionKey,
        CreatureDetailsTutorialTarget.lineageAnalyzer =>
          _effectiveCreature.parentage != null
              ? _breedingAnalysisSectionKey
              : _lineageSectionKey,
      };
      final sectionContext = key.currentContext;
      if (sectionContext == null) return;
      Scrollable.ensureVisible(
        sectionContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return _buildShell(
      effective: _effectiveCreature,
      hydrating: _hydratingInstance,
      instance: _instance,
    );
  }

  Widget _buildShell({
    required Creature effective,
    required bool hydrating,
    required CreatureInstance? instance,
  }) {
    final c = _C.of(context);
    final shellColor = c.isDark ? c.bg1 : Colors.white;
    final discovered = widget.isDiscovered;

    return Dialog(
      insetPadding: const EdgeInsets.all(2),
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: shellColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: c.borderAccent, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: c.amber.withValues(alpha: 0.08),
              blurRadius: 32,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _HeaderBar(
              creature: effective,
              onClose: () => Navigator.of(context).pop(),
            ),
            if (discovered) _TabSelector(tabController: _tabController),
            Expanded(
              child: discovered
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        // OVERVIEW
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: _OverviewTab(
                            key: ValueKey(
                              '${effective.id}-${hydrating ? 'loading' : 'ready'}',
                            ),
                            creature: effective,
                            instanceLevel: _instanceLevel,
                            instance: instance,
                            pageController: _pageController,
                            currentImageIndex: _currentImageIndex,
                            onPageChanged: (i) =>
                                setState(() => _currentImageIndex = i),
                          ),
                        ),
                        // ANALYSIS
                        _AnalysisTab(
                          parentage: effective.parentage,
                          controller: _analysisScrollController,
                          creature: effective,
                          isInstance: instance != null,
                          instance: instance,
                          highlightedTargets: _activeTutorialTargets,
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
                          behaviorSectionKey: _behaviorSectionKey,
                          potentialSectionKey: _potentialSectionKey,
                          lineageSectionKey: _lineageSectionKey,
                          breedingAnalysisSectionKey:
                              _breedingAnalysisSectionKey,
                        ),
                        // BATTLE
                        if (instance != null)
                          ImprovedBattleScrollArea(
                            theme: context.read<FactionTheme>(),
                            creature: effective,
                            instance: instance,
                          )
                        else
                          const _LockedTabPlaceholder(
                            message: 'BATTLE DATA REQUIRES A LIVE SPECIMEN',
                          ),
                      ],
                    )
                  : UnknownScrollArea(theme: context.read<FactionTheme>()),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// HEADER BAR
// ──────────────────────────────────────────────────────────────────────────────

class _HeaderBar extends StatelessWidget {
  final Creature creature;
  final VoidCallback onClose;

  const _HeaderBar({required this.creature, required this.onClose});

  Color _rarityColor(String rarity, _C c) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return const Color(0xFFFFB020);
      case 'rare':
        return const Color(0xFF60A5FA);
      case 'uncommon':
        return const Color(0xFF34D399);
      default:
        return c.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final rarityColor = _rarityColor(creature.rarity, c);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.bg2,
        border: Border(bottom: BorderSide(color: c.borderDim)),
      ),
      child: Row(
        children: [
          // Left — name block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        creature.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: c.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _TagBadge(label: creature.rarity, color: rarityColor),
                    const SizedBox(width: 6),
                    ...creature.types
                        .take(2)
                        .map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _TagBadge(label: t, color: c.teal),
                          ),
                        ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Right — close
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: c.bg3,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: c.borderDim),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: c.textSecondary,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// TAB SELECTOR
// ──────────────────────────────────────────────────────────────────────────────

class _TabSelector extends StatelessWidget {
  final TabController tabController;
  const _TabSelector({required this.tabController});

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.bg2,
        border: Border(bottom: BorderSide(color: c.borderDim)),
      ),
      child: TabBar(
        controller: tabController,
        indicator: BoxDecoration(
          color: c.bg3,
          border: Border(bottom: BorderSide(color: c.amberBright, width: 2)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: c.amberBright,
        unselectedLabelColor: c.textMuted,
        labelStyle: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 1.8,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 1.8,
        ),
        tabs: const [
          Tab(text: 'OVERVIEW'),
          Tab(text: 'ANALYSIS'),
          Tab(text: 'BATTLE'),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// LOCKED TAB PLACEHOLDER
// ──────────────────────────────────────────────────────────────────────────────

class _LockedTabPlaceholder extends StatelessWidget {
  final String message;
  const _LockedTabPlaceholder({required this.message});
  @override
  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final t = _T(c);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.bg2,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: c.borderDim),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              color: c.textMuted,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(message, style: t.label.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// OVERVIEW TAB
// ──────────────────────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final Creature creature;
  final int? instanceLevel;
  final CreatureInstance? instance;
  final PageController pageController;
  final int currentImageIndex;
  final ValueChanged<int> onPageChanged;

  const _OverviewTab({
    super.key,
    required this.creature,
    required this.instanceLevel,
    required this.instance,
    required this.pageController,
    required this.currentImageIndex,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final purity = instance == null
        ? null
        : classifyInstancePurity(instance!, species: creature);
    final purityBonus = purity == null
        ? null
        : purityStatBonusForStatus(purity);
    final hasPurityBonus = purityBonus?.hasBonus == true;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Sprite hero ─────────────────────────────────────────────────────
          _buildSpriteHero(c),
          if (instance != null) ...[
            const SizedBox(height: 10),
            _StaminaRestoreButton(instanceId: instance!.instanceId),
          ],
          const SizedBox(height: 20),

          if (instance != null) ...[
            _ForgeSection(
              title: 'Genetic Profile',
              child: Column(
                children: [
                  _DataRow(label: 'Size Variant', value: _sizeLabel()),
                  _DataRow(label: 'Pigmentation', value: _tintLabel()),
                  if (creature.nature != null)
                    _DataRow(
                      label: 'Behavioral Pattern',
                      value: creature.nature!.id,
                    ),
                  if (creature.isPrismaticSkin == true)
                    _DataRow(
                      label: 'Special Trait',
                      value: 'Prismatic Phenotype',
                      valueColor: const Color(0xFFE879F9),
                    ),
                  if (hasPurityBonus && purity != null)
                    _DataRow(
                      label: 'Purity',
                      value: purity.label,
                      valueColor: _purityAccent(c, purity),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _ForgeSection(
              title: 'Source / Discovery',
              child: Column(
                children: [
                  _DataRow(
                    label: 'Source',
                    value: _formatSource(instance!.source),
                  ),
                  _DataRow(
                    label: 'Logged',
                    value: _formatCreationDate(instance!.createdAtUtcMs),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── Classification ───────────────────────────────────────────────────
          _ForgeSection(
            title: 'Specimen Classification',
            child: Column(
              children: [
                _DataRow(label: 'Classification', value: creature.rarity),
                _DataRow(
                  label: 'Type Categories',
                  value: creature.types.join(', '),
                ),
                if (creature.description.isNotEmpty)
                  _DataRow(label: 'Description', value: creature.description),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Physical attributes (instance only) ──────────────────────────────
          if (instance != null) ...[
            _ForgeSection(
              title: 'Physical Attributes',
              accentColor: c.amberBright,
              child: Column(
                children: [
                  _StatBar(label: 'Speed', value: instance!.statSpeed),
                  _StatBar(
                    label: 'Intelligence',
                    value: instance!.statIntelligence,
                  ),
                  _StatBar(label: 'Strength', value: instance!.statStrength),
                  _StatBar(label: 'Beauty', value: instance!.statBeauty),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── Special breeding ─────────────────────────────────────────────────
          if (creature.specialBreeding != null) ...[
            _ForgeSection(
              title: 'Synthesis Requirements',
              accentColor: c.danger,
              child: Column(
                children: [
                  _DataRow(
                    label: 'Method',
                    value: 'Specialized Genetic Fusion',
                  ),
                  _DataRow(
                    label: 'Required Components',
                    value: creature.specialBreeding!.requiredParentNames.join(
                      ' + ',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpriteHero(_C c) {
    return Stack(
      children: [
        // Background plate with scanlines
        Container(
          height: 210,
          decoration: BoxDecoration(
            color: c.bg2,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: c.borderDim),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _ScanlinePainter())),
              // Radial glow behind sprite
              Center(
                child: Container(
                  width: 175,
                  height: 175,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        c.amber.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Sprite
              Center(
                child: SizedBox(
                  width: 175,
                  height: 175,
                  child: Center(
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
                                creature.spriteData!.frameDurationMs / 1000.0,
                            scale: scaleFromGenes(creature.genetics),
                            saturation: satFromGenes(creature.genetics),
                            brightness: briFromGenes(creature.genetics),
                            hueShift: hueFromGenes(creature.genetics),
                            isPrismatic: creature.isPrismaticSkin,
                          )
                        : InstanceSprite(
                            creature: creature,
                            instance: instance!,
                            size: 162,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Prismatic shimmer badge (top-left)
        if (creature.isPrismaticSkin == true)
          Positioned(
            top: instanceLevel != null ? 44 : 10,
            left: 10,
            child: _TagBadge(
              label: 'Prismatic',
              color: const Color(0xFFE879F9),
            ),
          ),
        if (instanceLevel != null)
          Positioned(
            top: 10,
            left: 10,
            child: _HeroCornerBadge(
              label: 'LV $instanceLevel',
              color: c.amberBright,
            ),
          ),
        // Variant faction badge (top-right)
        if (instance?.variantFaction?.isNotEmpty == true)
          Positioned(
            top: 10,
            right: 10,
            child: Builder(
              builder: (context) {
                final fColor = _variantFactionColor(instance!.variantFaction!);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: fColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: fColor.withValues(alpha: 0.75),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: fColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: fColor, size: 9),
                      const SizedBox(width: 4),
                      Text(
                        instance!.variantFaction!.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: fColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (instance != null)
          Positioned(
            left: 10,
            bottom: 10,
            child: _HeroStaminaBadge(instanceId: instance!.instanceId),
          ),
      ],
    );
  }

  String _sizeLabel() {
    final mapLabel = sizeLabels[creature.genetics?.get('size') ?? 'Normal'];
    return mapLabel ?? 'Standard';
  }

  String _tintLabel() {
    final mapLabel = tintLabels[creature.genetics?.get('tinting') ?? 'Normal'];
    return mapLabel ?? 'Standard';
  }

  Color _purityAccent(_C c, InstancePurityStatus purity) {
    if (purity.isPure) return c.success;
    if (purity.isElementallyPure) return c.teal;
    if (purity.isSpeciesPure) return c.amberBright;
    return c.textMuted;
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// HERO BADGES
// ──────────────────────────────────────────────────────────────────────────────

class _HeroCornerBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _HeroCornerBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: c.bg1.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _HeroStaminaBadge extends StatelessWidget {
  final String instanceId;

  const _HeroStaminaBadge({required this.instanceId});

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: c.bg1.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: c.borderAccent.withValues(alpha: 0.75)),
      ),
      child: StaminaBadge(instanceId: instanceId, showCountdown: false),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// STAMINA RESTORE BUTTON
// ──────────────────────────────────────────────────────────────────────────────

class _StaminaRestoreButton extends StatelessWidget {
  final String instanceId;
  const _StaminaRestoreButton({required this.instanceId});

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final db = context.read<AlchemonsDatabase>();
    return StreamBuilder<List<InventoryItem>>(
      stream: db.inventoryDao.watchItemInventory(),
      builder: (context, snapshot) {
        int qty = 0;
        for (final item in snapshot.data ?? []) {
          if (item.key == InvKeys.staminaPotion) {
            qty = item.qty;
            break;
          }
        }
        if (qty <= 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: GestureDetector(
            onTap: () => _use(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.amberDim.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: c.borderAccent, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: c.amber.withValues(alpha: 0.10),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_drink_rounded,
                    color: c.amberBright,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'RESTORE STAMINA',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: c.amberBright,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: c.bg2,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: c.borderAccent, width: 1),
                    ),
                    child: Text(
                      '×$qty',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: c.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
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

  Future<void> _use(BuildContext context) async {
    final c = _C.of(context);
    final db = context.read<AlchemonsDatabase>();
    await db.inventoryDao.addItemQty(InvKeys.staminaPotion, -1);
    final staminaService = StaminaService(db);
    await staminaService.restoreToFull(instanceId);
    if (context.mounted) {
      final backgroundColor = c.amber;
      final foregroundColor = c.onColor(backgroundColor);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.local_drink_rounded, color: foregroundColor, size: 16),
              const SizedBox(width: 8),
              Text(
                'STAMINA RESTORED',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: foregroundColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
            side: BorderSide(color: c.borderAccent, width: 1),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// STAT BAR ROW
// ──────────────────────────────────────────────────────────────────────────────

class _StatBar extends StatelessWidget {
  final String label;
  final double value;
  static const double _maxStat = 5.0;

  const _StatBar({required this.label, required this.value});

  Color _barColor(_C c) {
    final ratio = value / _maxStat;
    if (ratio >= 0.7) return c.success;
    if (ratio >= 0.4) return c.amberBright;
    return c.danger;
  }

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final t = _T(c);
    final ratio = (value / _maxStat).clamp(0.0, 1.0);
    final color = _barColor(c);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label.toUpperCase(), style: t.label),
          ),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: c.bg3,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ratio,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                fontFamily: 'monospace',
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// ANALYSIS TAB
// ──────────────────────────────────────────────────────────────────────────────

class _AnalysisTab extends StatelessWidget {
  final ScrollController controller;
  final Creature creature;
  final bool isInstance;
  final CreatureInstance? instance;
  final Set<CreatureDetailsTutorialTarget> highlightedTargets;
  final Set<String> isExpandedMap;
  final void Function(String parentKey) onToggleParent;
  final String? instanceId;
  final Parentage? parentage;
  final GlobalKey behaviorSectionKey;
  final GlobalKey potentialSectionKey;
  final GlobalKey lineageSectionKey;
  final GlobalKey breedingAnalysisSectionKey;

  const _AnalysisTab({
    required this.controller,
    required this.creature,
    required this.isInstance,
    required this.instance,
    required this.highlightedTargets,
    required this.isExpandedMap,
    required this.onToggleParent,
    required this.instanceId,
    required this.parentage,
    required this.behaviorSectionKey,
    required this.potentialSectionKey,
    required this.lineageSectionKey,
    required this.breedingAnalysisSectionKey,
  });

  @override
  Widget build(BuildContext context) {
    final fTheme = context.read<FactionTheme>();
    final c = _C.of(context);
    final constellation = context.watch<ConstellationEffectsService>();
    final hasLineageAnalyzer = constellation.hasLineageAnalyzer();
    final hasGeneAnalyzer = constellation.hasGeneAnalyzer();
    final hasPotentialAnalyzer = constellation.hasPotentialAnalyzer();
    final highlightGene = highlightedTargets.contains(
      CreatureDetailsTutorialTarget.geneAnalyzer,
    );
    final highlightPotential = highlightedTargets.contains(
      CreatureDetailsTutorialTarget.potentialAnalyzer,
    );
    final highlightLineage = highlightedTargets.contains(
      CreatureDetailsTutorialTarget.lineageAnalyzer,
    );
    final showBreedingAnalysis =
        parentage != null && isInstance && instanceId != null;
    final highlightLineageOverview = highlightLineage && !showBreedingAnalysis;

    return SingleChildScrollView(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Behavioral Analysis
          _HighlightedAnalysisSection(
            sectionKey: behaviorSectionKey,
            enabled: highlightGene,
            label: CreatureDetailsTutorialTarget.geneAnalyzer.highlightLabel,
            child: _AnalysisSection(
              title: 'Behavioral Analysis',
              child: _BehaviorBlock(
                creature: creature,
                showNatureDetails: hasGeneAnalyzer,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Genetic Analysis
          _AnalysisSection(
            title: 'Genetic Analysis',
            child: _GeneticsBlock(creature: creature),
          ),
          const SizedBox(height: 18),

          // Stat Potentials
          if (isInstance && instanceId != null) ...[
            _HighlightedAnalysisSection(
              sectionKey: potentialSectionKey,
              enabled: highlightPotential,
              label: CreatureDetailsTutorialTarget
                  .potentialAnalyzer
                  .highlightLabel,
              child: hasPotentialAnalyzer
                  ? _AnalysisSection(
                      title: 'Stat Potentials',
                      accentColor: c.teal,
                      child: StatPotentialBlock(
                        theme: fTheme,
                        instanceId: instanceId!,
                      ),
                    )
                  : _AnalysisSection(
                      title: 'Stat Potentials',
                      child: _GatedContent(
                        message:
                            'Detailed stat potentials are currently obscured.',
                      ),
                    ),
            ),
            const SizedBox(height: 18),
          ],

          // Lineage
          if (isInstance && instance != null) ...[
            _HighlightedAnalysisSection(
              sectionKey: lineageSectionKey,
              enabled: highlightLineageOverview,
              label:
                  CreatureDetailsTutorialTarget.lineageAnalyzer.highlightLabel,
              child: _AnalysisSection(
                title: 'Lineage',
                accentColor: c.teal,
                child: LineageBlock(
                  theme: fTheme,
                  instance: instance!,
                  creature: creature,
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Parent specimens
          if (parentage != null && parentage?.parentA.baseId != '') ...[
            const _EtchedDivider(label: 'PARENT SPECIMENS'),
            const SizedBox(height: 12),
            ParentCard(
              theme: fTheme,
              snap: parentage!.parentA,
              parentKey: 'parentA',
              isExpanded: isExpandedMap.contains('parentA'),
              onToggle: () => onToggleParent('parentA'),
            ),
            const SizedBox(height: 8),
            ParentCard(
              theme: fTheme,
              snap: parentage!.parentB,
              parentKey: 'parentB',
              isExpanded: isExpandedMap.contains('parentB'),
              onToggle: () => onToggleParent('parentB'),
            ),
            const SizedBox(height: 18),
          ] else if (isInstance && instance != null) ...[
            _AnalysisSection(
              title: 'Acquisition Method',
              child: _DataRow(
                label: 'Source',
                value: _formatSource(instance!.source),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Breeding analysis
          if (showBreedingAnalysis) ...[
            _HighlightedAnalysisSection(
              sectionKey: breedingAnalysisSectionKey,
              enabled: highlightLineage,
              label:
                  CreatureDetailsTutorialTarget.lineageAnalyzer.highlightLabel,
              child: hasLineageAnalyzer
                  ? _AnalysisSection(
                      title: 'Breeding Analysis',
                      accentColor: const Color(0xFFA855F7),
                      child: _BreedingAnalysisSection(instanceId: instanceId!),
                    )
                  : _AnalysisSection(
                      title: 'Breeding Analysis',
                      child: _GatedContent(
                        message:
                            'Advanced lineage and outcome statistics obscured.',
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// HIGHLIGHTED ANALYSIS SECTION
// ──────────────────────────────────────────────────────────────────────────────

class _HighlightedAnalysisSection extends StatelessWidget {
  final GlobalKey sectionKey;
  final bool enabled;
  final String label;
  final Widget child;

  const _HighlightedAnalysisSection({
    required this.sectionKey,
    required this.enabled,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: sectionKey,
      child: TutorialHighlight(
        enabled: enabled,
        label: enabled ? label : null,
        child: child,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// GATED CONTENT PLACEHOLDER
// ──────────────────────────────────────────────────────────────────────────────

class _GatedContent extends StatelessWidget {
  final String message;
  const _GatedContent({required this.message});
  @override
  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final t = _T(c);
    return Row(
      children: [
        Icon(Icons.visibility_off_rounded, color: c.textMuted, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: t.body.copyWith(fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// BEHAVIOR BLOCK
// ──────────────────────────────────────────────────────────────────────────────

class _BehaviorBlock extends StatelessWidget {
  final Creature creature;
  final bool showNatureDetails;
  const _BehaviorBlock({
    required this.creature,
    required this.showNatureDetails,
  });

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final n = creature.nature;
    if (n == null) {
      return _DataRow(
        label: 'Nature',
        value: 'Unspecified — Standard behavioral pattern',
      );
    }
    return Column(
      children: [
        _DataRow(label: 'Nature Type', value: n.id),
        if (!showNatureDetails)
          _DataRow(
            label: 'Effects',
            value: 'Behavioral modifiers obscured.',
            valueColor: c.textMuted,
          )
        else if (n.effect.modifiers.isNotEmpty)
          _DataRow(
            label: 'Active Effects',
            value: _formatNatureEffects(n.effect),
          )
        else
          _DataRow(
            label: 'Effects',
            value: 'No special behavioral modifications known',
          ),
      ],
    );
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
          effects.add('Breeding cost -${((1 - value) * 100).round()}%');
          break;
        case 'stamina_wilderness_drain_mult':
          effects.add('Wilderness stamina -${((1 - value) * 100).round()}%');
          break;
        case 'breed_same_species_chance_mult':
          {
            final p = ((value - 1) * 100).round();
            effects.add('Same species breeding ${p >= 0 ? '+' : ''}$p%');
          }
          break;
        case 'breed_same_type_chance_mult':
          {
            final p = ((value - 1) * 100).round();
            effects.add('Same type breeding ${p >= 0 ? '+' : ''}$p%');
          }
          break;
        case 'egg_hatch_time_mult':
          effects.add('Hatch time -${((1 - value) * 100).round()}%');
          break;
        case 'xp_gain_mult':
          effects.add('XP gain +${((value - 1) * 100).round()}%');
          break;
        case 'stat_speed_bonus':
          effects.add('Speed +${_formatNatureStatBonus(value)}');
          break;
        case 'stat_intelligence_bonus':
          effects.add('Intelligence +${_formatNatureStatBonus(value)}');
          break;
        case 'stat_strength_bonus':
          effects.add('Strength +${_formatNatureStatBonus(value)}');
          break;
        case 'stat_beauty_bonus':
          effects.add('Beauty +${_formatNatureStatBonus(value)}');
          break;
        default:
          effects.add('${_humanizeNatureKey(key)}: $value');
      }
    });
    return effects.join(', ');
  }

  String _formatNatureStatBonus(num value) =>
      value.toStringAsFixed(value % 1 == 0 ? 0 : 1);

  String _humanizeNatureKey(String key) => key
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

// ──────────────────────────────────────────────────────────────────────────────
// GENETICS BLOCK
// ──────────────────────────────────────────────────────────────────────────────

class _GeneticsBlock extends StatelessWidget {
  final Creature creature;
  const _GeneticsBlock({required this.creature});

  @override
  Widget build(BuildContext context) {
    final g = creature.genetics;
    if (g == null) {
      return Column(
        children: const [
          _DataRow(
            label: 'Genetic Profile',
            value: 'Standard genotype — no variants detected',
          ),
          _DataRow(label: 'Inheritance', value: 'Wild-type characteristics'),
        ],
      );
    }
    final sizeGene = g.get('size');
    final tintGene = g.get('tinting');
    return Column(
      children: [
        _DataRow(
          label: 'Size Gene',
          value: sizeGene != null
              ? (sizeLabels[sizeGene] ?? 'Unknown')
              : 'Normal',
        ),
        _DataRow(
          label: 'Color Gene',
          value: tintGene != null
              ? (tintLabels[tintGene] ?? 'Unknown')
              : 'Standard',
        ),
        if (tintGene != null)
          _DataRow(label: 'Description', value: _geneDesc('tinting', tintGene)),
      ],
    );
  }

  static String _geneDesc(String track, String variant) {
    try {
      return GeneticsCatalog.track(track).byId(variant).description;
    } catch (_) {
      return 'Unknown variant';
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// BREEDING ANALYSIS SECTION
// ──────────────────────────────────────────────────────────────────────────────

class _BreedingAnalysisSection extends StatelessWidget {
  final String instanceId;
  const _BreedingAnalysisSection({required this.instanceId});

  Future<
    ({
      CreatureInstance? instance,
      Creature? species,
      Map<String, dynamic>? report,
    })
  >
  _loadData(BuildContext context) async {
    try {
      final db = context.read<AlchemonsDatabase>();
      final repo = context.read<CreatureCatalog>();
      final instance = await db.creatureDao.getInstance(instanceId);
      if (instance == null) {
        return (instance: null, species: null, report: null);
      }
      final species = repo.getCreatureById(instance.baseId);
      if (instance.likelihoodAnalysisJson == null ||
          instance.likelihoodAnalysisJson!.isEmpty) {
        return (instance: instance, species: species, report: null);
      }
      return (
        instance: instance,
        species: species,
        report:
            jsonDecode(instance.likelihoodAnalysisJson!)
                as Map<String, dynamic>,
      );
    } catch (_) {
      return (instance: null, species: null, report: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    return FutureBuilder<
      ({
        CreatureInstance? instance,
        Creature? species,
        Map<String, dynamic>? report,
      })
    >(
      future: _loadData(context),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return _DataRow(
            label: 'Status',
            value: 'No breeding record available',
            valueColor: c.textMuted,
          );
        }
        final instance = snap.data!.instance;
        final species = snap.data!.species;
        final report = snap.data!.report;
        final purity = instance == null
            ? null
            : classifyInstancePurity(instance, species: species);
        final purityBonus = purity == null
            ? null
            : purityStatBonusForStatus(purity);
        final hasPurityBonus = purityBonus?.hasBonus == true;
        if (report == null) {
          final hasParentage = _hasActualParentage(instance?.parentageJson);
          final sourceLabel = founderSourceLabel(
            instance?.source ?? '',
          ).toLowerCase();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DataRow(
                label: 'Status',
                value: hasParentage
                    ? 'Breeding record unavailable'
                    : 'No breeding record — founder specimen from $sourceLabel',
                valueColor: c.textMuted,
              ),
              if (hasPurityBonus && purity != null && purityBonus != null) ...[
                const SizedBox(height: 12),
                _PurityAnalysisCard(purity: purity, bonus: purityBonus),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryBanner(report: report),
            const SizedBox(height: 10),
            OutcomeBadge(theme: context.read<FactionTheme>(), report: report),
            const SizedBox(height: 8),
            OutcomeExplanation(
              theme: context.read<FactionTheme>(),
              report: report,
            ),
            const SizedBox(height: 12),
            _InheritanceMechanicsSection(report: report),
            if (hasPurityBonus && purity != null && purityBonus != null) ...[
              const SizedBox(height: 12),
              _PurityAnalysisCard(purity: purity, bonus: purityBonus),
            ],
            const SizedBox(height: 12),
            _InheritedTraitsSimple(analysis: report),
          ],
        );
      },
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  final Map<String, dynamic> report;
  const _SummaryBanner({required this.report});

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final summaryLine = report['summaryLine'] as String? ?? '';
    if (summaryLine.isEmpty) return const SizedBox.shrink();
    final parts = summaryLine.split(':');
    final cross = parts.isNotEmpty ? parts[0].trim() : summaryLine;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: c.borderDim),
      ),
      child: Text(
        cross.toUpperCase(),
        style: TextStyle(
          fontFamily: 'monospace',
          color: c.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _InheritanceMechanicsSection extends StatelessWidget {
  final Map<String, dynamic> report;
  const _InheritanceMechanicsSection({required this.report});

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
        const _EtchedDivider(label: 'INHERITANCE MECHANICS'),
        const SizedBox(height: 10),
        ...mechanics.map((m) => _MechanicCard(mechanic: m)),
      ],
    );
  }
}

class _PurityAnalysisCard extends StatelessWidget {
  final InstancePurityStatus purity;
  final PurityStatBonus bonus;

  const _PurityAnalysisCard({required this.purity, required this.bonus});

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final t = _T(c);
    final color = purity.isPure
        ? c.success
        : purity.isElementallyPure
        ? c.teal
        : purity.isSpeciesPure
        ? c.amberBright
        : c.textMuted;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: c.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, size: 13, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Purity Bonus: ${purity.label}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: c.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            bonus.summary,
            style: TextStyle(
              fontFamily: 'monospace',
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bonus.explanationFor(purity),
            style: t.body.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _MechanicCard extends StatelessWidget {
  final Map<String, dynamic> mechanic;
  const _MechanicCard({required this.mechanic});

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final t = _T(c);
    final category = mechanic['category'] as String? ?? '';
    final result = mechanic['result'] as String? ?? '';
    final mechanism = mechanic['mechanism'] as String? ?? '';
    final percentage = (mechanic['percentage'] as num?)?.toDouble() ?? 0.0;
    final likelihood = mechanic['likelihood'] as int? ?? 0;
    final color = _likelihoodColor(likelihood, c);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.bg3,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: c.borderDim),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_categoryIcon(category), size: 13, color: c.amberBright),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$category: $result',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: c.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: color.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(mechanism, style: t.body.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  static Color _likelihoodColor(int l, _C c) {
    switch (l) {
      case 3:
        return c.success;
      case 2:
        return c.teal;
      case 1:
        return c.amberBright;
      case 0:
        return const Color(0xFFA855F7);
      default:
        return c.textSecondary;
    }
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

class _InheritedTraitsSimple extends StatelessWidget {
  final Map<String, dynamic> analysis;
  const _InheritedTraitsSimple({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final t = _T(c);
    final traits = analysis['traitJustifications'] as List? ?? [];
    if (traits.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EtchedDivider(label: 'INHERITED TRAITS'),
        const SizedBox(height: 10),
        ...traits.map((raw) {
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
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: c.amberDim.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: c.borderAccent, width: 0.8),
                  ),
                  child: Icon(
                    _MechanicCard._categoryIcon(category),
                    size: 11,
                    color: c.amberBright,
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
                          fontFamily: 'monospace',
                          color: c.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        mechanism,
                        style: t.body.copyWith(
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
        }),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// HELPERS
// ──────────────────────────────────────────────────────────────────────────────

String _formatSource(String source) {
  switch (source) {
    case 'wild_capture':
      return 'Wild Capture';
    case 'wild_fusion':
      return 'Wild Fusion';
    case 'wild_breeding':
      return 'Wild Fusion'; // legacy key
    case 'wild':
      return 'Wild Capture'; // legacy key
    case 'standard_fusion':
      return 'Standard Fusion';
    case 'breeding':
      return 'Standard Fusion'; // legacy key
    case 'rift_portal':
      return 'Rift Portal';
    case 'planet_summon':
      return 'Planet Summon';
    case 'boss_summon':
      return 'Boss Summon';
    case 'breeding_vial':
    case 'vial':
      return 'Vial Extraction';
    case 'starter':
      return 'Starter';
    case 'quest':
      return 'Quest Reward';
    default:
      return 'Discovery';
  }
}

bool _hasActualParentage(String? parentageJson) {
  if (parentageJson == null || parentageJson.trim().isEmpty) return false;
  try {
    final decoded = jsonDecode(parentageJson);
    if (decoded is! Map<String, dynamic>) return false;

    bool hasBaseId(dynamic raw) {
      if (raw is! Map) return false;
      final baseId = raw['baseId'];
      return baseId is String && baseId.trim().isNotEmpty;
    }

    return hasBaseId(decoded['parentA']) && hasBaseId(decoded['parentB']);
  } catch (_) {
    return false;
  }
}

String _formatCreationDate(int? timestampMs) {
  if (timestampMs == null) return 'Unknown';
  final date = DateTime.fromMillisecondsSinceEpoch(
    timestampMs,
    isUtc: true,
  ).toLocal();
  return '${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.year}  '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}
