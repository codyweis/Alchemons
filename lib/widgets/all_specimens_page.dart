// lib/widgets/all_specimens_page.dart
//
// The picker that slides up whenever a specimen is wanted — fusion's pair,
// a harvester, the exchange, the home biome's residents. It is the
// Creatures tab's specimens view with a title over it: the same search bar,
// sort row and lit display cases (specimen_case.dart), so the two never
// look like different games.

import 'dart:async';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_instaces_grid.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart';
import 'package:alchemons/widgets/specimen_search_bar.dart';
import 'package:flutter/material.dart';

class AllSpecimensPage extends StatefulWidget {
  final FactionTheme theme;
  final FutureOr<bool> Function(CreatureInstance instance)?
  onWillSelectInstance;
  final bool popOnSelect;
  final bool selectionMode;
  final int maxSelections;
  final void Function(List<CreatureInstance>)? onConfirmSelection;
  final List<String> selectedInstanceIds;

  /// What the pick is for, over the search bar: CHOOSE TO FUSE.
  final String title;
  final List<String> allowedPrimaryTypes;
  final bool closeReturnsSelection;
  final String? instancePrefsScopeKey;

  /// Optional corner badge for every case, e.g. a sale value.
  final Widget? Function(CreatureInstance inst, Creature species)?
  cardBadgeBuilder;

  const AllSpecimensPage({
    super.key,
    required this.theme,
    this.onWillSelectInstance,
    this.popOnSelect = false,
    this.selectionMode = false,
    this.maxSelections = 0,
    this.onConfirmSelection,
    this.selectedInstanceIds = const [],
    this.title = 'ALL SPECIMENS',
    this.allowedPrimaryTypes = const [],
    this.closeReturnsSelection = false,
    this.instancePrefsScopeKey,
    this.cardBadgeBuilder,
  });

  @override
  State<AllSpecimensPage> createState() => _AllSpecimensPageState();
}

class _AllSpecimensPageState extends State<AllSpecimensPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchText = '';
  int _clearVersion = 0;
  bool _hasResettableState = false;
  List<CreatureInstance> _currentSelection = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _searchText = text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final palette = BracketPalette.fromTheme(theme);
    final accent = bracketReadableAccent(theme);

    return PopScope(
      canPop: !(widget.closeReturnsSelection && widget.selectionMode),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.closeReturnsSelection && widget.selectionMode) {
          _closePage();
        }
      },
      child: Scaffold(
        backgroundColor: palette.bg1,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Row(
                  children: [
                    BracketIconButton(
                      icon: AppIcons.close_rounded,
                      onTap: _closePage,
                      palette: palette,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: caseMono(13, palette.ink, spacing: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: SpecimenSearchBar(
                  palette: palette,
                  accent: accent,
                  controller: _searchController,
                  hint: 'Search your specimens',
                  onChanged: _onQueryChanged,
                  showReset: _hasResettableState,
                  onReset: () {
                    _debounce?.cancel();
                    _searchController.clear();
                    setState(() {
                      _searchText = '';
                      _clearVersion++;
                    });
                  },
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: AllCreatureInstances(
                  theme: theme,
                  caseCards: true,
                  prefsScopeKey: widget.instancePrefsScopeKey,
                  selectedInstanceIds: widget.selectedInstanceIds,
                  allowedPrimaryTypes: widget.allowedPrimaryTypes,
                  searchTextOverride: _searchText,
                  showInternalSearchBar: false,
                  clearVersion: _clearVersion,
                  onResettableStateChanged: (hasResettableState) {
                    if (_hasResettableState == hasResettableState || !mounted) {
                      return;
                    }
                    setState(() => _hasResettableState = hasResettableState);
                  },
                  selectionMode: widget.selectionMode,
                  maxSelections: widget.maxSelections,
                  onSelectionChanged: (selected) {
                    _currentSelection = selected;
                  },
                  onConfirmSelection: widget.onConfirmSelection,
                  cardBadgeBuilder: widget.cardBadgeBuilder,
                  onTap: widget.popOnSelect
                      ? (inst) async {
                          final navigator = Navigator.of(context);
                          final shouldSelect =
                              await widget.onWillSelectInstance?.call(inst) ??
                              true;
                          if (!mounted || !shouldSelect) return;
                          navigator.pop(inst);
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _closePage() {
    final navigator = Navigator.of(context);
    if (widget.closeReturnsSelection && widget.selectionMode) {
      navigator.pop(_currentSelection);
      return;
    }
    navigator.pop();
  }
}
