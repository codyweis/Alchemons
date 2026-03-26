import 'dart:async';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_instaces_grid.dart';
import 'package:alchemons/widgets/floating_close_button_widget.dart';
import 'package:flutter/material.dart';

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
  });

  @override
  State<AllSpecimensPage> createState() => _AllSpecimensPageState();
}

class _AllSpecimensPageState extends State<AllSpecimensPage>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _searchController;
  late final AnimationController _blinkController;
  String _searchText = '';
  int _clearVersion = 0;
  bool _hasResettableState = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.3,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final t = ForgeTokens(theme);

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: widget.showFloatingCloseButton
          ? FloatingCloseButton(
              onTap: () => Navigator.of(context).pop(),
              theme: theme,
            )
          : null,
      backgroundColor: t.bg0,
      appBar: AppBar(
        backgroundColor: t.bg1,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: widget.leadingIcon == null
            ? null
            : Tooltip(
                message: widget.leadingTooltip,
                child: GestureDetector(
                  onTap:
                      widget.onLeadingTap ?? () => Navigator.of(context).pop(),
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.bg2,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: t.borderDim),
                    ),
                    child: Icon(
                      widget.leadingIcon,
                      color: t.textSecondary,
                      size: 16,
                    ),
                  ),
                ),
              ),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(
              child: GestureDetector(
                onTap: () => setState(() {
                  _searchText = '';
                  _searchController.clear();
                  _clearVersion++;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _hasResettableState
                        ? t.amberDim.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: _hasResettableState ? t.borderAccent : t.borderDim,
                    ),
                  ),
                  child: Text(
                    'CLEAR',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: _hasResettableState
                          ? t.amberBright
                          : t.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        title: Row(
          children: [
            FadeTransition(
              opacity: _blinkController,
              child: Container(
                width: 4,
                height: 14,
                color: t.amber,
                margin: const EdgeInsets.only(right: 8),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                cursorColor: t.amberBright,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: t.textPrimary,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: widget.searchHint,
                  hintStyle: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchText = value);
                },
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: t.borderDim),
        ),
      ),
      body: SafeArea(
        child: AllCreatureInstances(
          theme: theme,
          selectedInstanceIds: widget.selectedInstanceIds,
          searchTextOverride: _searchText,
          showInternalSearchBar: false,
          clearVersion: _clearVersion,
          onResettableStateChanged: (hasResettableState) {
            if (_hasResettableState == hasResettableState || !mounted) return;
            setState(() => _hasResettableState = hasResettableState);
          },
          selectionMode: widget.selectionMode,
          maxSelections: widget.maxSelections,
          onConfirmSelection: widget.onConfirmSelection,
          onTap: (inst) async {
            final navigator = Navigator.of(context);
            final shouldSelect =
                await widget.onWillSelectInstance?.call(inst) ?? true;
            if (!mounted || !shouldSelect) return;

            if (widget.popOnSelect) {
              navigator.pop(inst);
              return;
            }

            widget.onInstanceTap?.call(inst);
          },
        ),
      ),
    );
  }
}
