// lib/widgets/creature_detail/creature_dialog.dart
//
// The full details of one Alchemon.
//   Overview — the creature itself: its stage, vitals, what it wears, its
//              four stats, its traits, and a few words about it.
//   Lineage  — where it came from and what it passes down: its line, its
//              parents, and how the fusion came out.
//   Battle   — battle_sheet.dart.
// Each fact is shown once. A species opened from the catalog has only its
// overview.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/constants/creature_details_tutorials.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/models/purity_stat_bonus.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/color_util.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/utils/instance_purity_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_detail/battle_tab.dart';
import 'package:alchemons/widgets/creature_detail/creature_background_pref.dart';
import 'package:alchemons/widgets/creature_detail/creature_display_view.dart';
import 'package:alchemons/widgets/creature_detail/specimen_readouts.dart';
import 'package:alchemons/widgets/creature_detail/unknow_helper.dart';
import 'package:alchemons/widgets/creature_detail/worn_strip.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:alchemons/widgets/story_dialog.dart';
import 'package:alchemons/widgets/wilderness/tutorial_highlight.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
  );

  TextStyle get body =>
      TextStyle(color: _c.textSecondary, fontSize: 12, height: 1.5);

  TextStyle get sectionTitle => TextStyle(
    fontFamily: 'monospace',
    color: _c.amberBright,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.0,
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// BRACKET STYLE — shared helpers used by the redesigned dialog
// ──────────────────────────────────────────────────────────────────────────────

/// Returns the active bracket palette for the dialog. Centralized so future
/// tweaks happen in one place.
BracketPalette _bp(BuildContext context) => BracketPalette.of(context);

Color _dialogAccent(BuildContext context, {Color? color}) {
  return bracketReadableAccent(context.read<FactionTheme>(), color: color);
}

// ──────────────────────────────────────────────────────────────────────────────
// SHARED MICRO WIDGETS
// ──────────────────────────────────────────────────────────────────────────────

/// Returns the signature color for a variant faction name.
Color _variantFactionColor(String faction) => switch (faction.toLowerCase()) {
  'volcanic' => const Color(0xFFFF5722),
  'oceanic' => const Color(0xFF2196F3),
  'earthen' => const Color(0xFF795548),
  'verdant' => const Color(0xFF4CAF50),
  'arcane' => const Color(0xFF9C27B0),
  'bloodborn' => const Color(0xFFFF5252),
  _ => const Color(0xFF0EA5E9), // teal fallback
};

String _displayVariantFaction(String faction) {
  final trimmed = faction.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.toLowerCase() == 'bloodborn') return 'Bloodborn';
  return trimmed[0].toUpperCase() + trimmed.substring(1);
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
  static const _tabSwipeDuration = Duration(milliseconds: 150);
  static const _tabSwipePhysics = _CreatureDetailsTabPhysics();

  late TabController _tabController;
  final GlobalKey _attributesKey = GlobalKey();
  final GlobalKey _traitsKey = GlobalKey();
  final GlobalKey _lineKey = GlobalKey();
  final GlobalKey _oddsKey = GlobalKey();

  late Creature _effectiveCreature;
  bool _hydratingInstance = false;
  bool _showingAnalyzerTutorial = false;
  Set<CreatureDetailsTutorialTarget> _activeTutorialTargets =
      <CreatureDetailsTutorialTarget>{};

  CreatureInstance? _instance;
  StreamSubscription<CreatureInstance?>? _effectSub;
  bool _favoriteBusy = false;
  bool _nicknameBusy = false;
  CreatureBgOption? _bgOption;

  /// Overview, Lineage and Battle are all about one specimen. A species
  /// looked up from the catalog has only its overview.
  bool get _hasTabs => widget.isDiscovered && widget.instanceId != null;

  /// The creature gathers out of its element once per opening: not again
  /// when the Overview tab comes back.
  final EssenceReveal _heroReveal = EssenceReveal.once();

  int _initialTabIndex() =>
      _hasTabs && widget.openBattleTab ? _battleTabIndex : 0;

  static const _battleTabIndex = 2;

  @override
  void initState() {
    super.initState();
    _effectiveCreature = widget.creature;
    _tabController = TabController(
      length: _hasTabs ? 3 : 1,
      vsync: this,
      initialIndex: _initialTabIndex(),
      animationDuration: _tabSwipeDuration,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowPendingAnalyzerTutorials();
    });
    if (widget.instanceId != null) {
      _hydrateFromInstance(widget.instanceId!);
      _watchAlchemyEffect(widget.instanceId!);
    }
    unawaited(_reloadBgOption());
  }

  /// The dialog holds one copy of the specimen, so an effect or costume put
  /// on from here would not show until it was reopened. Follow the saved
  /// ones.
  void _watchAlchemyEffect(String instanceId) {
    final db = context.read<AlchemonsDatabase>();
    _effectSub = db.creatureDao.watchInstanceById(instanceId).listen((row) {
      final current = _instance;
      if (!mounted || row == null || current == null) return;
      if (row.alchemyEffect == current.alchemyEffect &&
          row.costumes == current.costumes) {
        return;
      }
      setState(() {
        _instance = current.copyWith(
          alchemyEffect: Value(row.alchemyEffect),
          costumes: Value(row.costumes),
        );
      });
    });
  }

  Future<void> _openDisplayView() async {
    final saved = await CreatureDisplayView.show(
      context,
      creature: _effectiveCreature,
      instance: _instance,
      initialBg: _bgOption ?? defaultCreatureBg,
    );
    if (!mounted) return;
    if (saved != null) {
      await _reloadBgOption();
    }
  }

  Future<void> _reloadBgOption() async {
    final db = context.read<AlchemonsDatabase>();
    final option = await loadCreatureBg(
      db,
      baseId: widget.creature.id,
      instanceId: widget.instanceId,
    );
    if (!mounted) return;
    setState(() => _bgOption = option);
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

  Future<void> _toggleFavorite() async {
    final instance = _instance;
    final instanceId = widget.instanceId;
    if (instance == null || instanceId == null || _favoriteBusy) return;

    final nextFavorite = !instance.isFavorite;
    if (nextFavorite) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _favoriteBusy = true;
      _instance = instance.copyWith(
        isFavorite: nextFavorite,
        locked: nextFavorite,
      );
    });

    try {
      final db = context.read<AlchemonsDatabase>();
      await db.creatureDao.setFavorite(instanceId, nextFavorite);
      final refreshed = await db.creatureDao.getInstance(instanceId);
      if (!mounted) return;
      setState(() {
        _instance = refreshed ?? _instance;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _instance = instance;
      });
    } finally {
      if (mounted) {
        setState(() {
          _favoriteBusy = false;
        });
      }
    }
  }

  Future<void> _editNickname() async {
    final instance = _instance;
    final instanceId = widget.instanceId;
    if (instance == null || instanceId == null || _nicknameBusy) return;

    final controller = TextEditingController(
      text: instance.nickname?.trim() ?? '',
    );
    try {
      final submitted = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          final c = _C.of(dialogContext);
          final t = _T(c);
          return AlertDialog(
            backgroundColor: c.bg2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: c.borderDim),
            ),
            title: Text(
              'Edit Nickname',
              style: t.heading.copyWith(
                color: c.textPrimary,
                fontSize: 14,
                letterSpacing: 1.4,
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Leave blank for ${widget.creature.name}',
                hintStyle: TextStyle(color: c.textMuted),
                filled: true,
                fillColor: c.bg3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: c.borderDim),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: c.borderDim),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: c.amberBright),
                ),
              ),
              onSubmitted: (value) =>
                  Navigator.of(dialogContext).pop(value.trim()),
            ),
            actions: [
              TextButton(
                onPressed: context.soundAction(
                  () => Navigator.of(dialogContext).pop(),
                ),
                child: Text(
                  'CANCEL',
                  style: t.label.copyWith(color: c.textMuted),
                ),
              ),
              TextButton(
                onPressed: context.soundAction(
                  () => Navigator.of(dialogContext).pop(controller.text.trim()),
                ),
                child: Text(
                  'SAVE',
                  style: t.label.copyWith(color: c.amberBright),
                ),
              ),
            ],
          );
        },
      );

      if (!mounted || submitted == null) return;

      final normalized = submitted.trim();
      final nextNickname = normalized.isEmpty ? null : normalized;
      final currentNickname = instance.nickname?.trim();
      final currentNormalized =
          currentNickname == null || currentNickname.isEmpty
          ? null
          : currentNickname;

      if (nextNickname == currentNormalized) return;

      setState(() {
        _nicknameBusy = true;
        _instance = instance.copyWith(nickname: Value(nextNickname));
      });

      try {
        final db = context.read<AlchemonsDatabase>();
        await db.creatureDao.setNickname(instanceId, nextNickname);
        final refreshed = await db.creatureDao.getInstance(instanceId);
        if (!mounted) return;
        setState(() {
          _instance = refreshed ?? _instance;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _instance = instance;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update nickname.')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _nicknameBusy = false;
          });
        }
      }
    } finally {
      controller.dispose();
    }
  }

  Creature _hydrateCatalogCreature(
    Creature base,
    CreatureInstance row,
    CreatureCatalog repo,
  ) {
    var out = base;
    if (row.isPrismaticSkin == true) out = out.copyWith(isPrismaticSkin: true);
    if (row.mutation != null) out = out.copyWith(wildMutation: row.mutation);
    if (row.natureId != null && row.natureId!.isNotEmpty) {
      final n = NatureCatalog.byId(row.natureId!);
      if (n != null) out = out.copyWith(nature: n);
    }
    if (row.natureId2 != null && row.natureId2!.isNotEmpty) {
      final n = NatureCatalog.byId(row.natureId2!);
      if (n != null) out = out.copyWith(nature2: n);
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
    _effectSub?.cancel();
    _tabController.dispose();
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

    // Every readout belongs to a specimen. Opened on a species, they stay
    // pending until one is opened.
    if (_instance == null || !_hasTabs) return;
    final eligibleTargets =
        pendingEntries
            .where((entry) => entry.isPending)
            .map((entry) => entry.target)
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

    final tab = _tabFor(eligibleTargets.first);
    if (_tabController.index != tab) {
      _tabController.animateTo(tab);
      await Future<void>.delayed(_tabSwipeDuration);
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
    final lines = [
      for (final target in targets) '${target.title}: ${target.tutorialBody}',
    ].join('\n\n');
    await showStoryDialog(
      context,
      primaryLabel: 'SHOW ME',
      barrierDismissible: true,
      beats: [
        StoryBeat(
          title: targets.length == 1
              ? '${targets.first.title} unlocked'
              : 'New analysis unlocked',
          message: 'New readouts are highlighted below.\n\n$lines',
        ),
      ],
    );
  }

  /// Potential and nature effects read on the creature itself; the
  /// Lineage Analyzer reads its fusion.
  static int _tabFor(CreatureDetailsTutorialTarget target) =>
      target == CreatureDetailsTutorialTarget.lineageAnalyzer ? 1 : 0;

  Future<void> _scrollToTutorialTarget(
    CreatureDetailsTutorialTarget target,
  ) async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = switch (target) {
        CreatureDetailsTutorialTarget.geneAnalyzer => _traitsKey,
        CreatureDetailsTutorialTarget.potentialAnalyzer => _attributesKey,
        CreatureDetailsTutorialTarget.lineageAnalyzer =>
          _oddsKey.currentContext != null ? _oddsKey : _lineKey,
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
    final palette = _bp(context);
    final activeAccent = _dialogAccent(context);

    final overview = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      // Fill the page: the default loose stack centres a short overview.
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: _OverviewTab(
        key: ValueKey('${effective.id}-${hydrating ? 'loading' : 'ready'}'),
        creature: effective,
        instance: instance,
        bgOption: _bgOption,
        onSpriteLongPress: _openDisplayView,
        reveal: _heroReveal,
        highlightedTargets: _activeTutorialTargets,
        attributesKey: _attributesKey,
        traitsKey: _traitsKey,
        // The specimen is still being read: no sprite yet, or the
        // species' would show and then be swapped for it.
        spriteLoading: hydrating && widget.instanceId != null,
      ),
    );

    // Tabs about a specimen that is still loading stay empty; one that
    // could not be found says so.
    Widget needsSpecimen(Widget Function(CreatureInstance) build) {
      if (instance != null) return build(instance);
      if (hydrating) return const SizedBox.shrink();
      return const _LockedTabPlaceholder(
        message: 'This specimen could not be found.',
      );
    }

    final Widget body;
    if (!widget.isDiscovered) {
      body = UnknownScrollArea(theme: context.read<FactionTheme>());
    } else if (!_hasTabs) {
      body = overview;
    } else {
      body = TabBarView(
        controller: _tabController,
        physics: _tabSwipePhysics,
        children: [
          _TabPage(index: 0, controller: _tabController, child: overview),
          _TabPage(
            index: 1,
            controller: _tabController,
            child: needsSpecimen(
              (inst) => _LineageTab(
                creature: effective,
                instance: inst,
                highlightedTargets: _activeTutorialTargets,
                lineKey: _lineKey,
                oddsKey: _oddsKey,
              ),
            ),
          ),
          _TabPage(
            index: _battleTabIndex,
            controller: _tabController,
            child: needsSpecimen(
              (inst) => ImprovedBattleScrollArea(
                theme: context.read<FactionTheme>(),
                creature: effective,
                instance: inst,
              ),
            ),
          ),
        ],
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(4),
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height * 0.88,
        child: CustomPaint(
          painter: BracketFramePainter(
            color: activeAccent.withValues(alpha: 0.86),
            bracketSize: 14,
            strokeWidth: 1.3,
          ),
          child: Container(
            color: palette.bg1,
            child: Column(
              children: [
                _HeaderBar(
                  creature: effective,
                  instance: instance,
                  favoriteBusy: _favoriteBusy,
                  nicknameBusy: _nicknameBusy,
                  onToggleFavorite: _toggleFavorite,
                  onEditName: _editNickname,
                  onClose: () => Navigator.of(context).pop(),
                ),
                if (_hasTabs) _TabSelector(tabController: _tabController),
                Expanded(child: body),
              ],
            ),
          ),
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
  final CreatureInstance? instance;
  final bool favoriteBusy;
  final bool nicknameBusy;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEditName;
  final VoidCallback onClose;

  const _HeaderBar({
    required this.creature,
    required this.instance,
    required this.favoriteBusy,
    required this.nicknameBusy,
    required this.onToggleFavorite,
    required this.onEditName,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _bp(context);
    final instance = this.instance;
    final isFavorite = instance?.isFavorite ?? false;
    final trimmedNickname = instance?.nickname?.trim();
    final hasNickname = trimmedNickname?.isNotEmpty == true;
    final displayName = hasNickname ? trimmedNickname! : creature.name;
    final favoriteAccent = const Color(0xFFE91E63);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
      decoration: BoxDecoration(
        color: palette.bg0,
        border: Border(
          bottom: BorderSide(color: palette.line.withValues(alpha: 0.5)),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: instance != null
                            ? InkWell(
                                onTap: context.soundAction(
                                  nicknameBusy
                                      ? null
                                      : () {
                                          HapticFeedback.lightImpact();
                                          onEditName();
                                        },
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: bracketText(
                                            context,
                                            20,
                                            palette.ink,
                                            weight: FontWeight.w600,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (nicknameBusy)
                                        SizedBox(
                                          width: 13,
                                          height: 13,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.6,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  _dialogAccent(context),
                                                ),
                                          ),
                                        )
                                      else
                                        Icon(
                                          AppIcons.edit_outlined,
                                          size: 14,
                                          color: palette.muted,
                                        ),
                                    ],
                                  ),
                                ),
                              )
                            : Text(
                                creature.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: bracketText(
                                  context,
                                  20,
                                  palette.ink,
                                  weight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                              ),
                      ),
                    ],
                  ),
                  if (hasNickname) ...[
                    const SizedBox(height: 2),
                    Text(
                      creature.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bracketText(
                        context,
                        12,
                        palette.muted,
                        weight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  RarityElementMark(
                    species: creature,
                    prismatic: creature.isPrismaticSkin == true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (instance != null) ...[
              _HeaderIconButton(
                // star_rounded and star_border_rounded are the same outline
                // glyph, so the "on" state never actually filled.
                icon: isFavorite
                    ? AppIcons.star_filled
                    : AppIcons.star_border_rounded,
                iconColor: isFavorite ? favoriteAccent : palette.muted,
                frameColor: isFavorite ? favoriteAccent : palette.line,
                busy: favoriteBusy,
                onTap: favoriteBusy ? null : onToggleFavorite,
              ),
              const SizedBox(width: 8),
            ],
            _HeaderIconButton(
              icon: AppIcons.close_rounded,
              iconColor: palette.muted,
              frameColor: palette.line,
              onTap: context.soundAction(onClose),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.iconColor,
    required this.frameColor,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color frameColor;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: context.soundAction(
        onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
      ),
      child: CustomPaint(
        painter: BracketFramePainter(
          color: frameColor.withValues(alpha: 0.8),
          bracketSize: 9,
          strokeWidth: 1,
        ),
        child: Container(
          width: 52,
          alignment: Alignment.center,
          child: busy
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                  ),
                )
              : Icon(icon, color: iconColor, size: 24),
        ),
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

  static const _labels = ['Overview', 'Lineage', 'Battle'];

  @override
  Widget build(BuildContext context) {
    final palette = _bp(context);
    final theme = context.read<FactionTheme>();
    final activeAccent = _dialogAccent(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: AnimatedBuilder(
        // The page's live position, not the settled index: the tab under
        // the finger lights as soon as the page is over halfway.
        animation: tabController.animation!,
        builder: (context, _) => Row(
          children: List.generate(_labels.length, (index) {
            final selected = tabController.animation!.value.round() == index;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == _labels.length - 1 ? 0 : 8,
                ),
                child: GestureDetector(
                  onTap: context.soundAction(() {
                    HapticFeedback.selectionClick();
                    tabController.animateTo(index);
                  }),
                  child: CustomPaint(
                    painter: BracketFramePainter(
                      color: selected
                          ? activeAccent
                          : palette.line.withValues(alpha: 0.55),
                      bracketSize: 10,
                      strokeWidth: selected ? 1.4 : 1.0,
                    ),
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      color: selected
                          ? palette.accentWash(theme.accent, darkAlpha: 0.32)
                          : palette.surfaceMutedFill(),
                      child: Text(
                        _labels[index],
                        style: bracketText(
                          context,
                          13,
                          selected ? palette.ink : palette.muted,
                          weight: selected ? FontWeight.w800 : FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// One tab's page, kept alive so coming back to it is instant (the Battle
/// stage would otherwise build a new game on every visit). Its tickers run
/// only while it is on screen, mid-swipe included.
class _TabPage extends StatefulWidget {
  const _TabPage({
    required this.index,
    required this.controller,
    required this.child,
  });

  final int index;
  final TabController controller;
  final Widget child;

  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage> with AutomaticKeepAliveClientMixin {
  late bool _onScreen = _computeOnScreen();

  bool _computeOnScreen() =>
      (widget.controller.animation!.value - widget.index).abs() < 1;

  @override
  void initState() {
    super.initState();
    widget.controller.animation!.addListener(_onMove);
  }

  @override
  void dispose() {
    widget.controller.animation!.removeListener(_onMove);
    super.dispose();
  }

  void _onMove() {
    final onScreen = _computeOnScreen();
    if (onScreen != _onScreen) setState(() => _onScreen = onScreen);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TickerMode(enabled: _onScreen, child: widget.child);
  }
}

/// Tabs that follow the finger and land quickly. The old spring (soft and a
/// little overdamped) took over half a second to creep the last few pixels
/// home, and the tab label waited for it.
class _CreatureDetailsTabPhysics extends ScrollPhysics {
  const _CreatureDetailsTabPhysics({super.parent});

  @override
  _CreatureDetailsTabPhysics applyTo(ScrollPhysics? ancestor) {
    return _CreatureDetailsTabPhysics(parent: buildParent(ancestor));
  }

  @override
  double? get dragStartDistanceMotionThreshold => 12;

  @override
  double get minFlingDistance => 18;

  /// A short, quick swipe turns the page; a slow drag under halfway
  /// springs back.
  @override
  double get minFlingVelocity => 300;

  @override
  SpringDescription get spring =>
      SpringDescription.withDampingRatio(mass: 0.4, stiffness: 520, ratio: 1.0);

  /// Done once it is within half a pixel, not a thousandth.
  @override
  Tolerance toleranceFor(ScrollMetrics metrics) =>
      const Tolerance(distance: 0.5, velocity: 20);
}

// ──────────────────────────────────────────────────────────────────────────────
// LOCKED TAB PLACEHOLDER
// ──────────────────────────────────────────────────────────────────────────────

class _LockedTabPlaceholder extends StatelessWidget {
  final String message;
  const _LockedTabPlaceholder({required this.message});
  @override
  Widget build(BuildContext context) {
    final palette = _bp(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            painter: BracketFramePainter(
              color: palette.line.withValues(alpha: 0.85),
              bracketSize: 10,
              strokeWidth: 1.1,
            ),
            child: Container(
              padding: const EdgeInsets.all(18),
              color: palette.surfaceFill(),
              child: Icon(
                AppIcons.lock_outline_rounded,
                color: palette.muted,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: bracketText(
              context,
              12,
              palette.muted,
              weight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// OVERVIEW TAB — the creature itself
// ──────────────────────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final Creature creature;
  final CreatureInstance? instance;
  final CreatureBgOption? bgOption;

  /// Opens the background picker. A tap plays the elemental essence.
  final VoidCallback? onSpriteLongPress;
  final EssenceReveal? reveal;
  final bool spriteLoading;
  final Set<CreatureDetailsTutorialTarget> highlightedTargets;
  final GlobalKey attributesKey;
  final GlobalKey traitsKey;

  const _OverviewTab({
    super.key,
    required this.creature,
    required this.instance,
    required this.bgOption,
    required this.onSpriteLongPress,
    required this.highlightedTargets,
    required this.attributesKey,
    required this.traitsKey,
    this.reveal,
    this.spriteLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final effects = context.watch<ConstellationEffectsService>();
    final inst = instance;
    // While the specimen is read, only the empty stage: the species' traits
    // would show and then be swapped, and this page fades out under the
    // ready one, which carries the same section keys.
    final traits = spriteLoading
        ? const <TraitRow>[]
        : specimenTraitRows(
            context,
            creature,
            inst,
            natureEffects: effects.hasGeneAnalyzer(),
          );
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Stage(
            creature: creature,
            instance: inst,
            bgOption: bgOption,
            onLongPress: onSpriteLongPress,
            reveal: reveal,
            spriteLoading: spriteLoading,
          ),
          if (inst != null) ...[
            const SizedBox(height: 10),
            _VitalsRow(instance: inst, creatureName: creature.name),
            const SizedBox(height: 10),
            WornStrip(instance: inst, creatureName: creature.name),
            const SizedBox(height: 16),
            _Highlighted(
              sectionKey: attributesKey,
              target: CreatureDetailsTutorialTarget.potentialAnalyzer,
              highlightedTargets: highlightedTargets,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BracketSectionDivider(label: 'ATTRIBUTES'),
                  const SizedBox(height: 8),
                  StatTileGrid(
                    stats: statTilesFor(
                      inst,
                      showPotential: effects.hasPotentialAnalyzer(),
                      showDominants: effects.hasDominantAnalyzer(),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (traits.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Highlighted(
              sectionKey: traitsKey,
              target: CreatureDetailsTutorialTarget.geneAnalyzer,
              highlightedTargets: highlightedTargets,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BracketSectionDivider(label: 'TRAITS'),
                  const SizedBox(height: 4),
                  ...traits,
                ],
              ),
            ),
          ],
          if (!spriteLoading) _AboutBlock(creature: creature, instance: inst),
        ],
      ),
    );
  }
}

/// The creature on its backdrop, with a soft pool to stand in. Tap plays its
/// element; long press picks the backdrop.
class _Stage extends StatelessWidget {
  final Creature creature;
  final CreatureInstance? instance;
  final CreatureBgOption? bgOption;
  final VoidCallback? onLongPress;
  final EssenceReveal? reveal;
  final bool spriteLoading;

  const _Stage({
    required this.creature,
    required this.instance,
    required this.bgOption,
    required this.onLongPress,
    required this.reveal,
    required this.spriteLoading,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _bp(context);
    final accent = _dialogAccent(context);
    final c = _C.of(context);
    final bg = bgOption;
    final inst = instance;
    // White and grey want a shadow under the creature, not a glow.
    final light =
        bg != null &&
        bg.kind == CreatureBgKind.color &&
        bg.color.computeLuminance() > 0.35;
    final variant = (inst?.variantFaction ?? '').trim();
    final prismatic = creature.isPrismaticSkin == true;

    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: accent.withValues(alpha: 0.82),
        bracketSize: 12,
        strokeWidth: 1.1,
      ),
      child: ClipRect(
        child: SizedBox(
          height: 240,
          child: Stack(
            children: [
              Positioned.fill(
                child: bg == null
                    ? ColoredBox(color: palette.bg0)
                    : CreatureBgLayer(option: bg),
              ),
              Center(
                child: IgnorePointer(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          (light ? Colors.black : accent).withValues(
                            alpha: light ? 0.06 : 0.12,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: spriteLoading
                      ? null
                      : ElementalEssence(
                          key: ValueKey(inst?.instanceId ?? creature.id),
                          element: creature.types.isEmpty
                              ? null
                              : creature.types.first,
                          dark: !light,
                          onLongPress: onLongPress,
                          reveal: reveal,
                          child: Center(
                            child: inst == null
                                ? SizedBox.square(
                                    dimension: 186,
                                    child: _speciesSprite(creature),
                                  )
                                : InstanceSprite(
                                    creature: creature,
                                    instance: inst,
                                    size: 186,
                                  ),
                          ),
                        ),
                ),
              ),
              if (inst != null)
                Positioned(
                  top: 10,
                  left: 10,
                  child: _HeroCornerBadge(
                    label: 'LV ${inst.level}',
                    color: c.amberBright,
                  ),
                ),
              if (prismatic || variant.isNotEmpty)
                Positioned(
                  top: 10,
                  right: 10,
                  child: _HeroCornerBadge(
                    label: prismatic
                        ? 'Prismatic'
                        : _displayVariantFaction(variant),
                    color: prismatic
                        ? const Color(0xFFE879F9)
                        : _variantFactionColor(variant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _speciesSprite(Creature creature) {
    final sd = creature.spriteData;
    if (sd == null) return const SizedBox.shrink();
    return CreatureSprite(
      spritePath: sd.spriteSheetPath,
      totalFrames: sd.totalFrames,
      rows: sd.rows,
      frameSize: Vector2(sd.frameWidth.toDouble(), sd.frameHeight.toDouble()),
      stepTime: sd.frameDurationMs / 1000.0,
      scale: scaleFromGenes(creature.genetics),
      saturation: satFromGenes(creature.genetics),
      brightness: briFromGenes(creature.genetics),
      hueShift: hueFromGenes(creature.genetics),
      isPrismatic: creature.isPrismaticSkin,
    );
  }
}

/// XP, breeding stamina, and an elixir when one would help.
class _VitalsRow extends StatelessWidget {
  final CreatureInstance instance;
  final String creatureName;

  const _VitalsRow({required this.instance, required this.creatureName});

  @override
  Widget build(BuildContext context) {
    final palette = _bp(context);
    return Row(
      children: [
        Text(
          '${instance.xp} XP',
          style: TextStyle(
            fontFamily: 'monospace',
            color: palette.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(width: 12),
        StaminaBadge(instanceId: instance.instanceId, showCountdown: true),
        const Spacer(),
        StaminaRestoreChip(
          instanceId: instance.instanceId,
          creatureName: creatureName,
        ),
      ],
    );
  }
}

/// The species' description, how it is made if it can only be made one way,
/// and where this one came from.
class _AboutBlock extends StatelessWidget {
  final Creature creature;
  final CreatureInstance? instance;

  const _AboutBlock({required this.creature, required this.instance});

  @override
  Widget build(BuildContext context) {
    final palette = _bp(context);
    final special = creature.specialBreeding;
    final inst = instance;
    final hasAny =
        creature.description.isNotEmpty || special != null || inst != null;
    if (!hasAny) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BracketSectionDivider(label: 'ABOUT'),
          const SizedBox(height: 8),
          if (creature.description.isNotEmpty)
            Text(
              creature.description,
              style: bracketText(
                context,
                13,
                palette.ink.withValues(alpha: 0.88),
                weight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
              strutStyle: const StrutStyle(height: 1.45),
            ),
          if (special != null) ...[
            const SizedBox(height: 8),
            Text(
              'Only made by fusing '
              '${special.requiredParentNames.join(' + ')}.',
              style: bracketText(
                context,
                12.5,
                palette.ink,
                weight: FontWeight.w600,
              ),
            ),
          ],
          if (inst != null) ...[
            const SizedBox(height: 10),
            Text(
              [
                _formatSource(inst.source),
                _formatDate(inst.createdAtUtcMs),
              ].join('  ·  '),
              style: TextStyle(
                fontFamily: 'monospace',
                color: palette.muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ],
      ),
    );
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
    final palette = _bp(context);
    return CustomPaint(
      painter: BracketFramePainter(
        color: color.withValues(alpha: 0.8),
        bracketSize: 6,
        strokeWidth: 1,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        color: palette.surfaceFill(lightAlpha: 0.96),
        child: Text(
          label.toUpperCase(),
          style: bracketText(
            context,
            11,
            color,
            weight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// LINEAGE TAB — what it came from and what it passes down
// ──────────────────────────────────────────────────────────────────────────────

class _LineageTab extends StatelessWidget {
  final Creature creature;
  final CreatureInstance instance;
  final Set<CreatureDetailsTutorialTarget> highlightedTargets;
  final GlobalKey lineKey;
  final GlobalKey oddsKey;

  const _LineageTab({
    required this.creature,
    required this.instance,
    required this.highlightedTargets,
    required this.lineKey,
    required this.oddsKey,
  });

  @override
  Widget build(BuildContext context) {
    final effects = context.watch<ConstellationEffectsService>();
    final tokens = ForgeTokens(context.read<FactionTheme>());
    final palette = _bp(context);
    final purity = classifyInstancePurity(instance, species: creature);
    final parentage = creature.parentage;
    final hasParents =
        parentage != null &&
        parentage.parentA.baseId.isNotEmpty &&
        parentage.parentB.baseId.isNotEmpty;

    final bonus = resolvePurityStatBonus(
      instanceId: instance.instanceId,
      isElementallyPure: purity.isElementallyPure,
      isSpeciesPure: purity.isSpeciesPure,
    );
    final families = <String, int>{};
    purity.speciesLineage.forEach((k, v) {
      final code = FamilyColors.code(k);
      families[code] = (families[code] ?? 0) + v;
    });

    final line = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BracketSectionDivider(label: 'LINE'),
        const SizedBox(height: 4),
        TraitRow(
          label: 'GENERATION',
          value: generationLabel(instance.generationDepth),
        ),
        TraitRow(
          label: 'PURITY',
          value: purity.label,
          color: _purityColor(tokens, palette, purity),
          note: purity.description,
        ),
        if (!bonus.isNone)
          effects.hasGeneAnalyzer()
              ? TraitRow(
                  label: 'BONUS',
                  value: _bonusText(bonus),
                  note: 'From its ${bonus.lineageLabel} line.',
                )
              : TraitRow(
                  label: 'BONUS',
                  value: 'Unread',
                  color: palette.muted,
                  note:
                      'Its pure line raises a stat. The Gene Analyzer reads '
                      'which.',
                  noteMuted: true,
                ),
        effects.hasDominantAnalyzer()
            ? TraitRow(
                label: 'DOMINANT',
                value: dominantStatsOf(
                  instance,
                ).all.map((k) => k.label).join(' · '),
                color: tokens.dominant,
                note: 'The two stats it passes down most reliably.',
              )
            : TraitRow(
                label: 'DOMINANT',
                value: 'Unread',
                color: palette.muted,
                note: 'Read by the Dominant Analyzer.',
                noteMuted: true,
              ),
        if (purity.elementLineage.isNotEmpty)
          _AncestryBar(
            label: 'ELEMENTS',
            data: purity.elementLineage,
            colorOf: BreedConstants.getTypeColor,
            labelOf: (k) => k,
          ),
        if (families.isNotEmpty)
          _AncestryBar(
            label: 'FAMILIES',
            data: families,
            colorOf: FamilyColors.of,
            labelOf: FamilyColors.label,
          ),
      ],
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A founder has no fusion to read, so a new Lineage Analyzer
          // points at its line instead.
          if (hasParents)
            KeyedSubtree(key: lineKey, child: line)
          else
            _Highlighted(
              sectionKey: lineKey,
              target: CreatureDetailsTutorialTarget.lineageAnalyzer,
              highlightedTargets: highlightedTargets,
              child: line,
            ),
          if (hasParents) ...[
            const SizedBox(height: 16),
            const BracketSectionDivider(label: 'PARENTS'),
            const SizedBox(height: 10),
            _ParentsRow(parentage: parentage),
            const SizedBox(height: 16),
            _Highlighted(
              sectionKey: oddsKey,
              target: CreatureDetailsTutorialTarget.lineageAnalyzer,
              highlightedTargets: highlightedTargets,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BracketSectionDivider(label: 'PROBABILITY'),
                  const SizedBox(height: 8),
                  if (effects.hasLineageAnalyzer())
                    _FusionOdds(instance: instance)
                  else
                    _QuietLine(
                      'The probability of each trait is read by the '
                      'Lineage Analyzer.',
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _bonusText(PurityStatBonus bonus) {
    final key = bonus.statKey;
    if (key == null || key.isEmpty) return bonus.lineageLabel;
    return '+${(bonus.bonus * 100).round()}% '
        '${key[0].toUpperCase()}${key.substring(1)}';
  }

  static Color _purityColor(
    ForgeTokens t,
    BracketPalette palette,
    InstancePurityStatus purity,
  ) {
    if (purity.isPure) return t.success;
    if (purity.isElementallyPure) return t.teal;
    if (purity.isSpeciesPure) return t.amberBright;
    return palette.ink;
  }
}

/// A muted italic sentence: something not read yet, or not kept.
class _QuietLine extends StatelessWidget {
  final String text;
  const _QuietLine(this.text);

  @override
  Widget build(BuildContext context) {
    final palette = _bp(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: bracketText(
          context,
          12,
          palette.muted,
          weight: FontWeight.w500,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

/// A share of the line as one filled bar, largest first, with its parts
/// named under it.
///
/// A long line can carry every element there is. The bar takes them all
/// (each part keeps at least a sliver), but the names stop at the largest
/// few, with the rest one tap away.
class _AncestryBar extends StatefulWidget {
  final String label;
  final Map<String, int> data;
  final Color Function(String key) colorOf;
  final String Function(String key) labelOf;

  const _AncestryBar({
    required this.label,
    required this.data,
    required this.colorOf,
    required this.labelOf,
  });

  /// Names shown before "+n more".
  static const namedParts = 5;

  @override
  State<_AncestryBar> createState() => _AncestryBarState();
}

class _AncestryBarState extends State<_AncestryBar> {
  bool _all = false;

  static String _percent(int part, int total) {
    final p = part * 100 / total;
    if (p > 0 && p < 1) return '<1%';
    return '${p.round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final palette = _bp(context);
    final entries = widget.data.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    if (total == 0) return const SizedBox.shrink();
    // Every part keeps at least a fiftieth of the bar, so a trace of one
    // element is still a visible sliver.
    final floor = total / 50;
    int flex(int v) => (math.max(v, floor) * 1000 / total).round();
    final hidden = _all
        ? 0
        : (entries.length - _AncestryBar.namedParts).clamp(0, entries.length);
    final named = entries.take(entries.length - hidden);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              widget.label,
              style: TextStyle(
                fontFamily: 'monospace',
                color: palette.muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 6,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < entries.length; i++) ...[
                          if (i > 0) const SizedBox(width: 1.5),
                          Expanded(
                            flex: flex(entries[i].value),
                            child: ColoredBox(
                              color: widget.colorOf(entries[i].key),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    for (final e in named)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: widget.colorOf(e.key),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${widget.labelOf(e.key)} '
                            '${_percent(e.value, total)}',
                            style: bracketText(
                              context,
                              12,
                              palette.ink,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    if (hidden > 0)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: context.soundAction(
                          () => setState(() => _all = true),
                        ),
                        child: Text(
                          '+$hidden more',
                          style: bracketText(
                            context,
                            12,
                            palette.muted,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The two parents side by side. One still kept opens its own details.
class _ParentsRow extends StatelessWidget {
  final Parentage parentage;
  const _ParentsRow({required this.parentage});

  @override
  Widget build(BuildContext context) {
    final palette = _bp(context);
    final bredAt = parentage.bredAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _ParentTile(snap: parentage.parentA)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('×', style: bracketText(context, 18, palette.muted)),
            ),
            Expanded(child: _ParentTile(snap: parentage.parentB)),
          ],
        ),
        if (bredAt.millisecondsSinceEpoch > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Fused ${_formatDate(bredAt.millisecondsSinceEpoch)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              color: palette.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ],
    );
  }
}

class _ParentTile extends StatefulWidget {
  final ParentSnapshot snap;
  const _ParentTile({required this.snap});

  @override
  State<_ParentTile> createState() => _ParentTileState();
}

class _ParentTileState extends State<_ParentTile> {
  CreatureInstance? _kept;
  bool _looked = false;

  @override
  void initState() {
    super.initState();
    _look();
  }

  Future<void> _look() async {
    final id = widget.snap.instanceId;
    CreatureInstance? row;
    if (id != null && id.isNotEmpty) {
      row = await context.read<AlchemonsDatabase>().creatureDao.getInstance(id);
    }
    if (!mounted) return;
    setState(() {
      _kept = row;
      _looked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = _bp(context);
    final snap = widget.snap;
    final species = context.read<CreatureCatalog>().getCreatureById(
      snap.baseId,
    );
    final kept = _kept;
    final openable = kept != null && species != null;

    final Widget sprite;
    if (kept != null && species != null) {
      sprite = InstanceSprite(creature: species, instance: kept, size: 72);
    } else if (snap.image.isNotEmpty) {
      sprite = Image.asset(
        'assets/images/${snap.image}',
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    } else {
      sprite = const SizedBox.shrink();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: openable
          ? context.soundAction(() {
              HapticFeedback.selectionClick();
              CreatureDetailsDialog.show(
                context,
                species,
                true,
                instanceId: kept.instanceId,
              );
            })
          : null,
      child: Container(
        color: palette.surfaceFill(),
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Column(
          children: [
            SizedBox(width: 72, height: 72, child: Center(child: sprite)),
            const SizedBox(height: 6),
            Text(
              snap.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bracketText(
                context,
                13,
                palette.ink,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              snap.types.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bracketText(context, 11.5, palette.muted),
            ),
            if (_looked && kept == null) ...[
              const SizedBox(height: 2),
              Text(
                'No longer kept',
                style: bracketText(
                  context,
                  11,
                  palette.muted.withValues(alpha: 0.75),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The fusion's probability: whether it was the likely result, then each
/// trait with the chance it had.
class _FusionOdds extends StatelessWidget {
  final CreatureInstance instance;
  const _FusionOdds({required this.instance});

  Map<String, dynamic>? _report() {
    final raw = instance.likelihoodAnalysisJson;
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report();
    if (report == null) {
      return const _QuietLine('No record of this fusion was kept.');
    }
    final palette = _bp(context);
    final t = ForgeTokens(context.read<FactionTheme>());
    final outcome = report['outcomeCategory'] as String? ?? '';
    final explanation = report['outcomeExplanation'] as String? ?? '';
    final rows = [
      ...?(report['inheritanceMechanics'] as List?),
      ...?(report['specialEvents'] as List?),
    ].whereType<Map>().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (outcome.isNotEmpty)
          Text(
            outcome,
            style: bracketText(
              context,
              15,
              _outcomeColor(outcome, t, palette),
              weight: FontWeight.w700,
            ),
          ),
        if (explanation.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            explanation,
            style: bracketText(context, 12, palette.muted),
            strutStyle: const StrutStyle(height: 1.3),
          ),
        ],
        const SizedBox(height: 8),
        for (final m in rows)
          TraitRow(
            label: _categoryLabel(m['category'] as String? ?? ''),
            value: m['result'] as String? ?? '',
            note: m['mechanism'] as String?,
            trailing: Text(
              '${((m['percentage'] as num?) ?? 0).round()}%',
              style: TextStyle(
                fontFamily: 'monospace',
                color: _likelihoodColor(m['likelihood'] as int?, t, palette),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  static String _categoryLabel(String category) => switch (category) {
    'Elemental Type' => 'ELEMENT',
    'Family Lineage' => 'FAMILY',
    'Color Tinting' => 'TINT',
    'Patterning' => 'PATTERN',
    _ => category.toUpperCase(),
  };

  static Color _outcomeColor(String o, ForgeTokens t, BracketPalette p) =>
      switch (o) {
        'Expected' => t.success,
        'Somewhat Unexpected' => t.teal,
        'Surprising' => t.amberBright,
        'Rare' => const Color(0xFFA855F7),
        _ => p.ink,
      };

  static Color _likelihoodColor(int? l, ForgeTokens t, BracketPalette p) =>
      switch (l) {
        3 => t.success,
        2 => t.teal,
        1 => t.amberBright,
        0 => const Color(0xFFA855F7),
        _ => p.muted,
      };
}

// ──────────────────────────────────────────────────────────────────────────────
// TUTORIAL HIGHLIGHT
// ──────────────────────────────────────────────────────────────────────────────

/// A section a newly unlocked analyzer points at: keyed so the dialog can
/// scroll to it, and lit while its tutorial is showing.
class _Highlighted extends StatelessWidget {
  final GlobalKey sectionKey;
  final CreatureDetailsTutorialTarget target;
  final Set<CreatureDetailsTutorialTarget> highlightedTargets;
  final Widget child;

  const _Highlighted({
    required this.sectionKey,
    required this.target,
    required this.highlightedTargets,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = highlightedTargets.contains(target);
    return KeyedSubtree(
      key: sectionKey,
      child: TutorialHighlight(
        enabled: enabled,
        label: enabled ? target.highlightLabel : null,
        child: child,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// HELPERS
// ──────────────────────────────────────────────────────────────────────────────

/// Where a specimen came from, in words. The one labeller for the dialog:
/// a second, founders-only one used to call every fusion a "Discovery".
String _formatSource(String source) {
  switch (source) {
    case 'wild_capture':
    case 'wild':
      return 'Wild Capture';
    case 'wild_fusion':
    case 'wild_breeding':
      return 'Wild Fusion';
    case 'standard_fusion':
    case 'breeding':
      return 'Fusion';
    case 'rift_portal':
      return 'Rift Portal';
    case 'planet_summon':
      return 'Planet Summon';
    case 'boss_summon':
      return 'Altar Summon';
    case 'breeding_vial':
    case 'vial':
      return 'Vial Extraction';
    case 'elemental_nexus':
      return 'Elemental Nexus';
    case 'starter':
      return 'Starter';
    case 'quest':
      return 'Quest Reward';
    default:
      return 'Discovery';
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(int utcMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true).toLocal();
  return '${_months[d.month - 1]} ${d.day}, ${d.year}';
}
