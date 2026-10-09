// lib/screens/party_picker/party_picker.dart
//
// The team picker: the wild's party, survival's team, a raid squad. It
// wears the slide-up specimen picker's look (all_specimens_page.dart) — the
// shared search bar and lit display cases — with the team over the grid as
// a row of small cases, the way the survival lobby shows it.

import 'dart:async';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/wilderness.dart' show PartyMember;
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_instaces_grid.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart'
    show
        CaseLightPainter,
        MarkDiamond,
        caseElementLight,
        caseMono,
        kCaseGilt,
        kCaseGlassInk;
import 'package:alchemons/widgets/specimen_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'party_picker_dialogs.dart';
import 'team_builder_dialog.dart';

class PartyPickerScreen extends StatefulWidget {
  const PartyPickerScreen({
    super.key,
    this.showDeployConfirm = true,
    this.enforceUniqueSpecies = true,
    this.enforceUniqueFamily = false,
    this.maxSelections,
    this.teamStorageKey = 'saved_teams_party_picker',
    this.initialSelection,
    this.confirmLabel,
    this.onConfirm,
    this.teamCaseWrapper,
  });

  /// When false the "Deploy Team?" confirmation dialog is skipped.
  final bool showDeployConfirm;

  /// When true, prevents selecting two instances of the same species.
  final bool enforceUniqueSpecies;

  /// When true, at most one Alchemon per mutation family may be selected —
  /// the raid rule. This is the existing "one Mystic per squad" restriction
  /// generalised to every family, which is what forces a raid roster to be
  /// broad instead of three copies of your best build.
  final bool enforceUniqueFamily;

  /// Override max team size. When null, uses the default from SelectedPartyNotifier.
  final int? maxSelections;

  /// Settings key used to persist saved teams for this picker context.
  final String teamStorageKey;

  /// Instance ids to open with already selected, in slot order (the team a
  /// screen already has). Null opens with nothing selected, on the shared
  /// selection as before; given, the picker keeps a selection of its own.
  final List<String>? initialSelection;

  /// The confirm button's words in place of "Deploy Team", for a screen that
  /// only sets a team rather than sending it out.
  final String? confirmLabel;

  /// Given the chosen team when it is confirmed, and awaited before the
  /// picker closes — so the screen beneath is already showing that team
  /// while the picker leaves (and anything flying has somewhere to land).
  final Future<void> Function(List<PartyMember> members)? onConfirm;

  /// Wraps each case in the team row, by slot and instance. The survival
  /// lobby wraps them in Heroes, so the chosen cases fly down into its own
  /// slots.
  final Widget Function(int slot, String instanceId, Widget teamCase)?
  teamCaseWrapper;

  @override
  State<PartyPickerScreen> createState() => _PartyPickerScreenState();
}

class _PartyPickerScreenState extends State<PartyPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchText = '';

  /// Incrementing this tells AllCreatureInstances to reset all filters.
  int _clearVersion = 0;

  /// Whether a search, sort or filter is set (shows the search bar's reset).
  bool _hasResettableState = false;

  /// True while [PartyPickerScreen.onConfirm] runs, so a second tap does not
  /// hand the team over twice.
  bool _handingOver = false;

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
    final db = context.watch<AlchemonsDatabase>();
    final theme = context.watch<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final accent = bracketReadableAccent(theme);

    Widget body = Scaffold(
      backgroundColor: palette.bg1,
      body: SafeArea(
        child: StreamBuilder<List<CreatureInstance>>(
          stream: db.creatureDao.watchAllInstances(),
          builder: (ctx, snap) {
            final allInstances = snap.data ?? [];
            return Consumer<SelectedPartyNotifier>(
              builder: (ctx2, party, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(ctx2, theme, palette, accent, party),
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 2),
                      child: _TeamRow(
                        party: party,
                        allInstances: allInstances,
                        palette: palette,
                        caseWrapper: widget.teamCaseWrapper,
                      ),
                    ),
                    Expanded(
                      child: AllCreatureInstances(
                        theme: theme,
                        caseCards: true,
                        prefsScopeKey: 'party_picker_all_instances',
                        searchTextOverride: _searchText,
                        showInternalSearchBar: false,
                        clearVersion: _clearVersion,
                        onResettableStateChanged: (hasResettableState) {
                          if (_hasResettableState == hasResettableState) {
                            return;
                          }
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            setState(
                              () => _hasResettableState = hasResettableState,
                            );
                          });
                        },
                        selectedInstanceIds: party.members
                            .map((m) => m.instanceId)
                            .toList(),
                        onTap: (inst) =>
                            _handleCardTap(ctx2, inst, party, allInstances),
                      ),
                    ),
                    _buildFooter(
                      ctx2,
                      party,
                      theme,
                      palette,
                      accent,
                      allInstances,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );

    // When maxSelections overrides the default, or the picker opens on a
    // team of its own, provide a scoped notifier.
    if (widget.maxSelections != null || widget.initialSelection != null) {
      body = ChangeNotifierProvider<SelectedPartyNotifier>(
        create: (_) {
          final party = SelectedPartyNotifier(maxSize: widget.maxSelections);
          final initial = widget.initialSelection;
          if (initial != null && initial.isNotEmpty) {
            party.setMembers([
              for (final id in initial) PartyMember(instanceId: id),
            ]);
          }
          return party;
        },
        child: body,
      );
    }

    return body;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HEADER
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext ctx,
    FactionTheme theme,
    BracketPalette palette,
    Color accent,
    SelectedPartyNotifier party,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Row(
        children: [
          BracketIconButton(
            icon: AppIcons.arrow_back_rounded,
            onTap: () => Navigator.of(ctx).pop(),
            palette: palette,
          ),
          const SizedBox(width: 12),
          // Shrinks rather than running into SAVED on a narrow phone with
          // large text.
          Expanded(
            child: Text(
              'CHOOSE A TEAM',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: caseMono(13, palette.ink, spacing: 1.6),
            ),
          ),
          const SizedBox(width: 10),
          // The quiet fill alone vanishes on the page's bg1.
          Container(
            width: 82,
            color: palette.bg0,
            child: BracketButton(
              key: const ValueKey('partyPicker.savedTeams'),
              label: 'SAVED',
              height: 38,
              primary: false,
              palette: palette,
              accent: accent,
              onTap: () => showDialog<void>(
                context: ctx,
                barrierColor: Colors.black.withValues(alpha: 0.7),
                builder: (_) => TeamBuilderDialog(
                  theme: theme,
                  storageKey: widget.teamStorageKey,
                  slotCount: party.maxSize,
                  activeMemberIds: party.members
                      .map((m) => m.instanceId)
                      .toList(),
                  onApply: (ids) => party.setMembers([
                    for (final id in ids) PartyMember(instanceId: id),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FOOTER
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildFooter(
    BuildContext ctx,
    SelectedPartyNotifier party,
    FactionTheme theme,
    BracketPalette palette,
    Color accent,
    List<CreatureInstance> allInstances,
  ) {
    final count = party.members.length;
    final canDeploy = count > 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.bg1,
        border: Border(top: BorderSide(color: palette.lineSoft)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: BracketButton(
          key: const ValueKey('partyPicker.confirm'),
          label: (widget.confirmLabel ?? 'Deploy Team').toUpperCase(),
          enabled: canDeploy,
          palette: palette,
          accent: accent,
          onTap: () async {
            if (_handingOver) return;
            if (widget.showDeployConfirm) {
              final confirmed = await showDialog<bool>(
                context: ctx,
                barrierDismissible: false,
                barrierColor: Colors.black.withValues(alpha: 0.7),
                builder: (_) => DeployConfirmDialog(
                  theme: theme,
                  partyCount: count,
                  maxSize: party.maxSize,
                  availableCount: allInstances.length,
                ),
              );
              if (confirmed != true) return;
            }
            final members = List.of(party.members);
            if (widget.onConfirm case final hand?) {
              setState(() => _handingOver = true);
              await hand(members);
              if (!mounted) return;
            }
            if (ctx.mounted) Navigator.pop(ctx, members);
          },
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CARD TAP HANDLER
  // ──────────────────────────────────────────────────────────────────────────

  void _handleCardTap(
    BuildContext ctx,
    CreatureInstance inst,
    SelectedPartyNotifier party,
    List<CreatureInstance> allInstances,
  ) {
    if (party.contains(inst.instanceId)) {
      party.toggle(inst.instanceId);
      return;
    }

    final repo = ctx.read<CreatureCatalog>();
    final species = repo.getCreatureById(inst.baseId);

    final hasSameSpecies =
        widget.enforceUniqueSpecies &&
        party.members.any((m) {
          final sel = allInstances.firstWhereOrNull(
            (x) => x.instanceId == m.instanceId,
          );
          return sel?.baseId == inst.baseId;
        });

    String? familyOf(String instanceId) {
      final sel = allInstances.firstWhereOrNull(
        (x) => x.instanceId == instanceId,
      );
      if (sel == null) return null;
      return repo.getCreatureById(sel.baseId)?.mutationFamily;
    }

    final family = species?.mutationFamily;
    final isMystic = family == 'Mystic';
    // Mystic is always unique. Under [enforceUniqueFamily] so is every other
    // family, so the general rule subsumes the Mystic one.
    final clashingFamily =
        family != null &&
        (isMystic || widget.enforceUniqueFamily) &&
        party.members.any((m) => familyOf(m.instanceId) == family);

    if (hasSameSpecies) {
      showGameSnack(
        ctx,
        '${species?.name ?? 'This species'} is already in your team.',
      );
      return;
    }
    if (clashingFamily) {
      showGameSnack(
        ctx,
        isMystic
            ? 'Only one Mystic is allowed per team.'
            : 'Only one $family is allowed in a raid squad.',
      );
      return;
    }
    party.toggle(inst.instanceId);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// THE TEAM
// ──────────────────────────────────────────────────────────────────────────────

/// The team over the grid: a heading with the count, then one small case
/// per slot — the creature in its element's light, its level in the corner,
/// its name engraved beneath. Tapping one takes it out.
class _TeamRow extends StatelessWidget {
  const _TeamRow({
    required this.party,
    required this.allInstances,
    required this.palette,
    this.caseWrapper,
  });

  final SelectedPartyNotifier party;
  final List<CreatureInstance> allInstances;
  final BracketPalette palette;
  final Widget Function(int slot, String instanceId, Widget teamCase)?
  caseWrapper;

  /// The widest a slot grows, so a four-slot team on a wide phone does not
  /// push the grid down with cases bigger than the grid's own.
  static const double _maxSlot = 76;
  static const double _gap = 6;
  static const int _perRow = 5;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CreatureCatalog>();
    final count = party.members.length;
    final maxSize = party.maxSize;

    final filled = <(CreatureInstance, Creature)?>[
      for (final m in party.members)
        () {
          final inst = allInstances.firstWhereOrNull(
            (i) => i.instanceId == m.instanceId,
          );
          final species = inst == null
              ? null
              : repo.getCreatureById(inst.baseId);
          return inst == null || species == null ? null : (inst, species);
        }(),
    ];

    // One height whatever the team: the grid under it must not jump when
    // the first one is picked, nor when the last is taken out.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 24,
          child: Row(
            children: [
              Text('TEAM', style: caseMono(10.5, palette.muted, spacing: 1.8)),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 1, color: palette.lineSoft)),
              const SizedBox(width: 10),
              Text(
                '$count / $maxSize',
                style: caseMono(10.5, palette.ink.withValues(alpha: 0.8)),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  key: const ValueKey('partyPicker.clear'),
                  behavior: HitTestBehavior.opaque,
                  onTap: context.soundAction(party.clear),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
                    child: Text(
                      'CLEAR',
                      style: caseMono(10.5, palette.muted, spacing: 1.4),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, box) {
            final perRow = maxSize < _perRow ? maxSize : _perRow;
            final slot = ((box.maxWidth - _gap * (perRow - 1)) / perRow).clamp(
              0.0,
              _maxSlot,
            );
            final rows = (maxSize / _perRow).ceil();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var r = 0; r < rows; r++) ...[
                  if (r > 0) const SizedBox(height: 8),
                  Row(
                    children: [
                      for (
                        var i = r * _perRow;
                        i < maxSize && i < (r + 1) * _perRow;
                        i++
                      ) ...[
                        if (i > r * _perRow) const SizedBox(width: _gap),
                        SizedBox(
                          width: slot,
                          child: i < filled.length
                              ? _TeamSlot(
                                  entry: filled[i],
                                  number: i + 1,
                                  palette: palette,
                                  wrapCase: caseWrapper == null
                                      ? null
                                      : (c) => caseWrapper!(
                                          i,
                                          party.members[i].instanceId,
                                          c,
                                        ),
                                  onRemove: () =>
                                      party.toggle(party.members[i].instanceId),
                                )
                              : _EmptySlot(palette: palette),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

const double _lineGap = 5;
const double _lineHeight = 12;

class _TeamSlot extends StatelessWidget {
  const _TeamSlot({
    required this.entry,
    required this.number,
    required this.palette,
    required this.onRemove,
    this.wrapCase,
  });

  /// Null while the instance is still being read, or if it has gone.
  final (CreatureInstance, Creature)? entry;
  final int number;
  final BracketPalette palette;
  final VoidCallback onRemove;

  /// Wraps the case (not its engraved line), e.g. in a Hero.
  final Widget Function(Widget teamCase)? wrapCase;

  static Widget _bare(Widget teamCase) => teamCase;

  @override
  Widget build(BuildContext context) {
    final entry = this.entry;
    final light = entry == null ? palette.muted : caseElementLight(entry.$2);
    final inst = entry?.$1;
    final species = entry?.$2;
    final name = inst?.nickname?.trim().isNotEmpty == true
        ? inst!.nickname!
        : species?.name ?? '';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onRemove),
      child: Semantics(
        button: true,
        label: inst == null
            ? 'Slot $number'
            : 'Remove $name, level ${inst.level}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: (wrapCase ?? _bare)(
                CustomPaint(
                  foregroundPainter: BracketFramePainter(
                    color: kCaseGilt,
                    strokeWidth: 1.6,
                  ),
                  child: ClipRect(
                    child: CustomPaint(
                      painter: CaseLightPainter(color: light),
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final art = box.maxWidth * 0.72;
                          return Stack(
                            children: [
                              if (inst != null && species != null)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: box.maxHeight * 0.08,
                                  child: Center(
                                    child: RepaintBoundary(
                                      child: species.spriteData != null
                                          ? InstanceSprite(
                                              creature: species,
                                              instance: inst,
                                              size: art,
                                            )
                                          : Image.asset(
                                              'assets/images/${species.image}',
                                              width: art,
                                              height: art,
                                              fit: BoxFit.contain,
                                            ),
                                    ),
                                  ),
                                ),
                              if (inst != null)
                                Positioned(
                                  top: 4,
                                  left: 5,
                                  child: Text(
                                    'LV ${inst.level}',
                                    style: caseMono(
                                      8.5,
                                      kCaseGlassInk.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: _lineGap),
            SizedBox(
              height: _lineHeight,
              child: Row(
                children: [
                  MarkDiamond(
                    color: light,
                    size: 5,
                    prismatic: inst?.isPrismaticSkin ?? false,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: caseMono(8.5, palette.ink, spacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.palette});

  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ColoredBox(
            color: palette.bg0.withValues(alpha: 0.7),
            child: Center(
              child: Icon(
                AppIcons.add_rounded,
                size: 16,
                color: palette.muted.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
        // A filled slot's engraved line, kept so the row never changes
        // height.
        const SizedBox(height: _lineGap + _lineHeight),
      ],
    );
  }
}
