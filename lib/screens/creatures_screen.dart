// lib/screens/creatures_screen.dart
//
// The Creatures tab (the Alchemon Database): one header — a search field and
// two tabs — over two views.
//
//   SPECIMENS  every Alchemon you own, as lit display cases
//              (specimen_case.dart, through AllCreatureInstances). Picking a
//              species in the catalog filters this to it, under a plate with
//              its breeding milestones (species_plate.dart).
//   CATALOG    every species, as family shelves or an element table
//              (species_table.dart). Progress is the catalog filling in.
//
// Its two dialogs live in database_dialogs.dart.

import 'dart:async';

import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/screens/database_dialogs.dart';
import 'package:alchemons/screens/progress_overview_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/new_discovery_reveal_controller.dart';
import 'package:alchemons/utils/game_data_gate.dart';
import 'package:alchemons/widgets/all_instaces_grid.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/catalog/species_plate.dart';
import 'package:alchemons/widgets/catalog/species_table.dart';
import 'package:alchemons/widgets/loading_widget.dart';
import 'package:alchemons/widgets/specimen_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/widgets/bracket_frame.dart';

import '../models/creature.dart';

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

  /// The species the specimens are filtered to, picked in the catalog.
  String? _speciesFilter;

  CatalogLayout _layout = CatalogLayout.shelves;
  static const _layoutKey = 'creatures_catalog_layout';

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
    if (!_layoutRead) {
      _layoutRead = true;
      () async {
        final raw = await _settings.getSetting(_layoutKey);
        if (!mounted || raw == null) return;
        final saved = CatalogLayout.values.where((l) => l.name == raw);
        if (saved.isNotEmpty) setState(() => _layout = saved.first);
      }();
    }
  }

  bool _layoutRead = false;

  void _setLayout(CatalogLayout layout) {
    setState(() => _layout = layout);
    _settings.setSetting(_layoutKey, layout.name);
  }

  /// The specimens tab, filtered to [speciesId].
  void _showSpecies(String speciesId) {
    unfocusSearch();
    _searchCtrl.clear();
    _debounce?.cancel();
    setState(() {
      _query = '';
      _speciesFilter = speciesId;
      _tab = 0;
    });
  }

  void _openMilestones() {
    unfocusSearch();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (routeContext) => ConstellationProgressOverviewScreen(
          onOpenSpecies: (id) {
            Navigator.of(routeContext).pop();
            _showSpecies(id);
          },
        ),
      ),
    );
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
            final filteredSpecies = _speciesFilter == null
                ? null
                : context.read<CreatureCatalog>().getCreatureById(
                    _speciesFilter!,
                  );

            return Scaffold(
              backgroundColor: palette.bg1,
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      child: SpecimenSearchBar(
                        palette: palette,
                        accent: accent,
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        hint: _tab == 1
                            ? 'Search found species'
                            : _speciesFilter != null
                            ? 'Search these specimens'
                            : 'Search your specimens',
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (filteredSpecies != null)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      6,
                                      12,
                                      0,
                                    ),
                                    child: SpeciesPlate(
                                      species: filteredSpecies,
                                      palette: palette,
                                      accent: accent,
                                      onClear: () =>
                                          setState(() => _speciesFilter = null),
                                    ),
                                  ),
                                Expanded(
                                  child: AllCreatureInstances(
                                    theme: theme,
                                    caseCards: true,
                                    speciesIdFilter: _speciesFilter,
                                    prefsScopeKey: 'creatures_all_specimens',
                                    searchTextOverride: _query,
                                    showInternalSearchBar: false,
                                    clearVersion: _clearVersion,
                                    onResettableStateChanged: (value) {
                                      if (!mounted ||
                                          _specimensResettable == value) {
                                        return;
                                      }
                                      setState(
                                        () => _specimensResettable = value,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_catalogBuilt)
                            TickerMode(
                              enabled: _tab == 1,
                              child: SpeciesTable(
                                entries: entries,
                                counts: _instanceCounts,
                                palette: palette,
                                accent: accent,
                                layout: _layout,
                                onLayoutChanged: _setLayout,
                                query: _query,
                                revealCreatureId: _revealCreatureId,
                                controller: _catalogScrollCtl,
                                onTap: (c, isDiscovered) =>
                                    _handleTap(c, isDiscovered, theme),
                                onOpenMilestones: _openMilestones,
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
      _showSpecies(species.id);
    } else {
      showUnknownSpeciesDialog(context, theme, species);
    }
  }
}
