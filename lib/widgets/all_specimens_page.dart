import 'dart:async';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_instaces_grid.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/floating_close_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';

class AllSpecimensPage extends StatefulWidget {
  final FactionTheme theme;
  final ValueChanged<CreatureInstance>? onInstanceTap;
  final FutureOr<bool> Function(CreatureInstance instance)?
  onWillSelectInstance;
  final bool popOnSelect;
  final bool selectionMode;
  final int maxSelections;
  final void Function(List<CreatureInstance>)? onConfirmSelection;
  final List<String> selectedInstanceIds;
  final IconData? leadingIcon;
  final String leadingTooltip;
  final VoidCallback? onLeadingTap;
  final String searchHint;
  final bool showFloatingCloseButton;
  final List<String> allowedPrimaryTypes;
  final bool closeReturnsSelection;
  final String? instancePrefsScopeKey;

  const AllSpecimensPage({
    super.key,
    required this.theme,
    this.onInstanceTap,
    this.onWillSelectInstance,
    this.popOnSelect = false,
    this.selectionMode = false,
    this.maxSelections = 0,
    this.onConfirmSelection,
    this.selectedInstanceIds = const [],
    this.leadingIcon,
    this.leadingTooltip = 'Close',
    this.onLeadingTap,
    this.searchHint = 'ALL SPECIMENS',
    this.showFloatingCloseButton = true,
    this.allowedPrimaryTypes = const [],
    this.closeReturnsSelection = false,
    this.instancePrefsScopeKey,
  });

  @override
  State<AllSpecimensPage> createState() => _AllSpecimensPageState();
}

class _AllSpecimensPageState extends State<AllSpecimensPage> {
  late final TextEditingController _searchController;
  String _searchText = '';
  int _clearVersion = 0;
  bool _hasResettableState = false;
  List<CreatureInstance> _currentSelection = const [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final palette = BracketPalette.fromTheme(theme);
    final activeAccent = bracketReadableAccent(theme);

    return PopScope(
      canPop: !(widget.closeReturnsSelection && widget.selectionMode),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.closeReturnsSelection && widget.selectionMode) {
          _closePage();
        }
      },
      child: Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: widget.showFloatingCloseButton
            ? FloatingCloseButton(onTap: _closePage, theme: theme)
            : null,
        backgroundColor: palette.bg1,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            decoration: BoxDecoration(
              color: palette.bg0,
              border: Border(
                bottom: BorderSide(
                  color: palette.line.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    if (widget.leadingIcon != null) ...[
                      _HeaderSquareButton(
                        icon: widget.leadingIcon!,
                        palette: palette,
                        accent: theme.accentSoft,
                        tooltip: widget.leadingTooltip,
                        onTap: widget.onLeadingTap ?? _closePage,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: CustomPaint(
                        painter: BracketFramePainter(
                          color: palette.line.withValues(alpha: 0.7),
                          bracketSize: 8,
                          strokeWidth: 1.05,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          color: palette.surfaceMutedFill(),
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.search_rounded,
                                size: 16,
                                color: palette.muted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  cursorColor: activeAccent,
                                  style: bracketText(
                                    context,
                                    14,
                                    palette.ink,
                                    weight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                  decoration: InputDecoration(
                                    isCollapsed: true,
                                    border: InputBorder.none,
                                    hintText: widget.searchHint,
                                    hintStyle: bracketText(
                                      context,
                                      14,
                                      palette.muted,
                                      weight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setState(() => _searchText = value);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => setState(() {
                        _searchText = '';
                        _searchController.clear();
                        _clearVersion++;
                      }),
                      child: CustomPaint(
                        painter: BracketFramePainter(
                          color: _hasResettableState
                              ? activeAccent
                              : palette.line.withValues(alpha: 0.6),
                          bracketSize: 7,
                          strokeWidth: _hasResettableState ? 1.2 : 1.0,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          color: _hasResettableState
                              ? palette.accentWash(theme.accent)
                              : palette.surfaceMutedFill(),
                          child: Text(
                            'Clear',
                            style: bracketText(
                              context,
                              12,
                              _hasResettableState
                                  ? palette.ink
                                  : palette.muted,
                              weight: _hasResettableState
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              letterSpacing: 0.6,
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
        ),
        body: SafeArea(
          child: AllCreatureInstances(
            theme: theme,
            prefsScopeKey: widget.instancePrefsScopeKey,
            selectedInstanceIds: widget.selectedInstanceIds,
            allowedPrimaryTypes: widget.allowedPrimaryTypes,
            searchTextOverride: _searchText,
            showInternalSearchBar: false,
            clearVersion: _clearVersion,
            onResettableStateChanged: (hasResettableState) {
              if (_hasResettableState == hasResettableState || !mounted) return;
              setState(() => _hasResettableState = hasResettableState);
            },
            selectionMode: widget.selectionMode,
            maxSelections: widget.maxSelections,
            onSelectionChanged: (selected) {
              _currentSelection = selected;
            },
            onConfirmSelection: widget.onConfirmSelection,
            onTap: widget.popOnSelect
                ? (inst) async {
                    final navigator = Navigator.of(context);
                    final shouldSelect =
                        await widget.onWillSelectInstance?.call(inst) ?? true;
                    if (!mounted || !shouldSelect) return;
                    navigator.pop(inst);
                  }
                : null,
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

class _HeaderSquareButton extends StatelessWidget {
  const _HeaderSquareButton({
    required this.icon,
    required this.palette,
    required this.accent,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final BracketPalette palette;
  final Color accent;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayAccent = bracketReadableAccent(
      context.read<FactionTheme>(),
      color: accent,
    );
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: BracketFramePainter(
            color: displayAccent.withValues(alpha: 0.82),
            bracketSize: 7,
            strokeWidth: 1.05,
          ),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            color: palette.surfaceFill(lightAlpha: 0.94),
            child: Icon(icon, color: displayAccent, size: 16),
          ),
        ),
      ),
    );
  }
}
