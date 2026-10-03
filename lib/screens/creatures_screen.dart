import 'package:alchemons/audio/audio.dart';
// lib/screens/creatures_screen.dart
//
// The Creatures tab (the Alchemon Database): one header — a search field and
// two tabs — over two views.
//
//   SPECIMENS  every Alchemon you own, as lit display cases
//              (specimen_case.dart, through AllCreatureInstances).
//   CATALOG    every species as a table, families across and elements down
//              (species_table.dart). Progress is the table filling in.
//
// Its two dialogs live in database_dialogs.dart.

import 'dart:async';

import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/screens/breeding_milestones_screen.dart';
import 'package:alchemons/screens/database_dialogs.dart';
import 'package:alchemons/screens/progress_overview_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/new_discovery_reveal_controller.dart';
import 'package:alchemons/utils/game_data_gate.dart';
import 'package:alchemons/widgets/all_instaces_grid.dart';
import 'package:alchemons/widgets/bottom_sheet_shell.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/catalog/species_table.dart';
import 'package:alchemons/widgets/loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';

import '../models/creature.dart';
import 'package:alchemons/widgets/app_icons.dart';

class CreaturesScreen extends StatefulWidget {
  const CreaturesScreen({super.key});

  @override
  State<CreaturesScreen> createState() => CreaturesScreenState();
}

class CreaturesScreenState extends State<CreaturesScreen> {
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

  /// 0 specimens, 1 catalog.
  int _tab = 0;

  /// The catalog is built the first time it is opened, then kept.
  bool _catalogBuilt = false;

  String _query = '';

  /// Bumped to clear the specimens' sort, filters and search together.
  int _clearVersion = 0;
  bool _specimensResettable = false;

  String? _revealCreatureId;
  Timer? _revealClearTimer;
  final ScrollController _catalogScrollCtl = ScrollController();

  late SettingsDao _settings;

  @override
  void initState() {
    super.initState();
    NewDiscoveryReveal.instance.pendingRevealCreatureId.addListener(
      _onPendingReveal,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settings = context.read<AlchemonsDatabase>().settingsDao;
    _bindInstanceCounts();
  }

  void _selectTab(int tab) {
    unfocusSearch();
    setState(() {
      _tab = tab;
      if (tab == 1) _catalogBuilt = true;
    });
  }

  void _onPendingReveal() {
    final id = NewDiscoveryReveal.instance.pendingRevealCreatureId.value;
    if (id == null || !mounted) return;
    setState(() {
      _revealCreatureId = id;
      _tab = 1;
      _catalogBuilt = true;
    });
    // The user's place is worth keeping, but the revealed cell is brought
    // into view: the card flies to that cell and cannot land on something
    // scrolled off the screen. The table builds every cell, so the cell's
    // own key is enough to find it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = NewDiscoveryReveal.instance.revealTileKey?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    });
    _revealClearTimer?.cancel();
    _revealClearTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      NewDiscoveryReveal.instance.pendingRevealCreatureId.value = null;
      NewDiscoveryReveal.instance.revealTileKey = null;
      setState(() => _revealCreatureId = null);
    });
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
    final theme = context.read<FactionTheme>();
    final hasSeen = await _settings.hasSeenCreaturesTutorial();
    if (hasSeen || !mounted) return;

    await showDatabaseTutorial(context, theme);

    if (!mounted) return;
    await _settings.setCreaturesTutorialSeen();
  }

  @override
  void dispose() {
    NewDiscoveryReveal.instance.pendingRevealCreatureId.removeListener(
      _onPendingReveal,
    );
    _revealClearTimer?.cancel();
    _catalogScrollCtl.dispose();
    _instanceCountsSub?.cancel();
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
            final palette = BracketPalette.fromTheme(theme);
            final accent = bracketReadableAccent(theme);
            final owned = _instanceCounts.values.fold<int>(0, (a, b) => a + b);

            return Scaffold(
              backgroundColor: palette.bg1,
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      child: _SearchBar(
                        palette: palette,
                        accent: accent,
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        hint: _tab == 0
                            ? 'Search your specimens'
                            : 'Search found species',
                        onChanged: _onQueryChanged,
                        showReset: _tab == 0 && _specimensResettable,
                        onReset: () {
                          _searchCtrl.clear();
                          setState(() {
                            _query = '';
                            _clearVersion++;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                      child: BracketTabs(
                        labels: [
                          'SPECIMENS  $owned',
                          'CATALOG  ${discovered.length}/${entries.length}',
                        ],
                        selected: _tab,
                        onSelect: _selectTab,
                        palette: palette,
                        accent: accent,
                      ),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _tab,
                        children: [
                          TickerMode(
                            enabled: _tab == 0,
                            child: AllCreatureInstances(
                              theme: theme,
                              caseCards: true,
                              prefsScopeKey: 'creatures_all_specimens',
                              searchTextOverride: _query,
                              showInternalSearchBar: false,
                              clearVersion: _clearVersion,
                              onResettableStateChanged: (value) {
                                if (!mounted || _specimensResettable == value) {
                                  return;
                                }
                                setState(() => _specimensResettable = value);
                              },
                              onTap: (inst) {
                                final creature = context
                                    .read<CreatureCatalog>()
                                    .getCreatureById(inst.baseId);
                                if (creature != null) {
                                  _openDetailsForInstance(creature, inst);
                                }
                              },
                            ),
                          ),
                          if (_catalogBuilt)
                            TickerMode(
                              enabled: _tab == 1,
                              child: SpeciesTable(
                                entries: entries,
                                counts: _instanceCounts,
                                palette: palette,
                                query: _query,
                                revealCreatureId: _revealCreatureId,
                                controller: _catalogScrollCtl,
                                onTap: (c, isDiscovered) =>
                                    _handleTap(c, isDiscovered, theme),
                                onOpenProgress: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ConstellationProgressOverviewScreen(),
                                  ),
                                ),
                              ),
                            )
                          else
                            const SizedBox(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
    );
  }

  // ── LOGIC ──────────────────────────────────────────────────────────────────

  void _onQueryChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _query = text.trim());
    });
  }

  void _handleTap(Creature species, bool isDiscovered, FactionTheme theme) {
    unfocusSearch();
    if (isDiscovered) {
      _showInstancesSheet(species, theme);
    } else {
      showUnknownSpeciesDialog(context, theme, species);
    }
  }

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
          onTap: context.soundAction(
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BreedingMilestoneScreen(speciesId: species.id),
              ),
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
              AppIcons.emoji_nature_rounded,
              size: 18,
              color: t.textSecondary,
            ),
          ),
        ),
        title: '${species.name} Specimens',
        child: InstancesSheet(
          species: species,
          theme: theme,
          prefsScopeKey: 'creatures_species_instances',
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

class _SearchBar extends StatefulWidget {
  const _SearchBar({
    required this.palette,
    required this.accent,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    required this.showReset,
    required this.onReset,
  });

  final BracketPalette palette;
  final Color accent;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool showReset;
  final VoidCallback onReset;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final hasText = widget.controller.text.isNotEmpty;
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: palette.ink,
    );
    return Row(
      children: [
        Expanded(
          child: CustomPaint(
            foregroundPainter: BracketFramePainter(
              color: palette.line.withValues(alpha: 0.6),
              bracketSize: 8,
            ),
            child: Container(
              height: 40,
              color: palette.chromeMutedFill(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(AppIcons.search_rounded, size: 15, color: palette.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      onChanged: widget.onChanged,
                      cursorColor: widget.accent,
                      style: style,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: widget.hint,
                        hintStyle: style.copyWith(color: palette.muted),
                      ),
                    ),
                  ),
                  if (hasText)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: context.soundAction(() {
                        widget.controller.clear();
                        widget.onChanged('');
                      }),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          AppIcons.close_rounded,
                          size: 14,
                          color: palette.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (widget.showReset) ...[
          const SizedBox(width: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: context.soundAction(widget.onReset),
            child: CustomPaint(
              foregroundPainter: BracketFramePainter(
                color: widget.accent,
                bracketSize: 7,
                strokeWidth: 1.2,
              ),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                color: palette.accentWash(widget.accent),
                child: Text(
                  'RESET',
                  style: style.copyWith(fontSize: 11, letterSpacing: 1.2),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
