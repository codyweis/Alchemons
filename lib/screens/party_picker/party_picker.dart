// lib/screens/party_picker/party_picker.dart
//
// SQUAD PICKER — Scorched Forge header + squad panel,
//                original AllCreatureInstances filter/sort/card view.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_instaces_grid.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'party_picker_dialogs.dart';
import 'team_builder_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ──────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ──────────────────────────────────────────────────────────────────────────────

class _C {
  static ForgeTokens _t = ForgeTokens(factionThemeFor(null));
  static void bind(BuildContext context) {
    _t = ForgeTokens(context.read<FactionTheme>());
  }

  static Color get bg0 => _t.bg0;
  static Color get bg1 => _t.bg1;
  static Color get bg2 => _t.bg2;

  static Color get amber => _t.amber;

  static Color get success => _t.success;
  static Color get warn => const Color(0xFFF97316);

  static Color get textPrimary => _t.textPrimary;
  static Color get textSecondary => _t.textSecondary;
  static Color get textMuted => _t.textMuted;

  static Color get borderDim => _t.borderDim;
}

class _T {
  static TextStyle get heading => TextStyle(
    fontFamily: 'monospace',
    color: _C.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
  );

  static TextStyle get label => TextStyle(
    fontFamily: 'monospace',
    color: _C.textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
  );
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black.withValues(alpha: 0.07);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ──────────────────────────────────────────────────────────────────────────────
// SCREEN
// ──────────────────────────────────────────────────────────────────────────────

class PartyPickerScreen extends StatefulWidget {
  const PartyPickerScreen({
    super.key,
    this.showDeployConfirm = true,
    this.enforceUniqueSpecies = true,
    this.maxSelections,
    this.teamStorageKey = 'saved_teams_party_picker',
  });

  /// When false the "Deploy Team?" confirmation dialog is skipped.
  final bool showDeployConfirm;

  /// When true, prevents selecting two instances of the same species.
  final bool enforceUniqueSpecies;

  /// Override max team size. When null, uses the default from SelectedPartyNotifier.
  final int? maxSelections;

  /// Settings key used to persist saved teams for this picker context.
  final String teamStorageKey;

  @override
  State<PartyPickerScreen> createState() => _PartyPickerScreenState();
}

class _PartyPickerScreenState extends State<PartyPickerScreen> {
  /// Incrementing this tells AllCreatureInstances to reset all filters.
  int _clearVersion = 0;

  /// Tracks whether AllCreatureInstances has any active filters (drives the X button highlight).
  bool _hasActiveFilters = false;

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _C.bind(context);
    final db = context.watch<AlchemonsDatabase>();
    final theme = context.watch<FactionTheme>();

    Widget body = Scaffold(
      backgroundColor: _C.bg0,
      body: SafeArea(
        child: StreamBuilder<List<CreatureInstance>>(
          stream: db.creatureDao.watchAllInstances(),
          builder: (ctx, snap) {
            final allInstances = snap.data ?? [];
            return Consumer<SelectedPartyNotifier>(
              builder: (ctx2, party, _) {
                return Column(
                  children: [
                    _buildHeader(ctx2, theme, party),
                    _buildSquadPanel(allInstances, party, ctx2),
                    Expanded(
                      child: AllCreatureInstances(
                        theme: theme,
                        prefsScopeKey: 'party_picker_all_instances',
                        clearVersion: _clearVersion,
                        onResettableStateChanged: (hasResettableState) {
                          if (_hasActiveFilters == hasResettableState) return;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            setState(
                              () => _hasActiveFilters = hasResettableState,
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
                    _buildFooter(ctx2, party, theme, allInstances),
                  ],
                );
              },
            );
          },
        ),
      ),
    );

    // When maxSelections overrides the default, provide a scoped notifier
    if (widget.maxSelections != null) {
      body = ChangeNotifierProvider<SelectedPartyNotifier>(
        create: (_) => SelectedPartyNotifier(maxSize: widget.maxSelections),
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
    SelectedPartyNotifier party,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.borderDim)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _C.bg2,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: _C.borderDim),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: _C.textSecondary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 8, bottom: 1),
                      decoration: BoxDecoration(
                        color: _C.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text('ASSEMBLE SQUAD', style: _T.heading),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'SELECT UP TO ${party.maxSize} CREATURES',
                  style: _T.label.copyWith(color: _C.textMuted),
                ),
              ],
            ),
          ),
          // Teams button
          GestureDetector(
            onTap: () async {
              await showDialog<void>(
                context: ctx,
                builder: (_) => TeamBuilderDialog(
                  theme: theme,
                  storageKey: widget.teamStorageKey,
                  slotCount: party.maxSize,
                  activeMemberIds:
                      party.members.map((m) => m.instanceId).toList(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _C.bg2,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: _C.borderDim),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder_open, color: _C.textSecondary, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'TEAMS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: _C.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Clear filters button (X) — highlighted when filters are active
          GestureDetector(
            onTap: () => setState(() => _clearVersion++),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _hasActiveFilters
                    ? _C.amber.withValues(alpha: 0.16)
                    : _C.bg2,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: _hasActiveFilters ? _C.amber : _C.borderDim,
                ),
              ),
              child: Icon(
                Icons.close_rounded,
                color: _hasActiveFilters ? _C.amber : _C.textMuted,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SQUAD PANEL
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildSquadPanel(
    List<CreatureInstance> allInstances,
    SelectedPartyNotifier party,
    BuildContext ctx,
  ) {
    final repo = ctx.read<CreatureCatalog>();
    final count = party.members.length;
    final maxSize = party.maxSize;
    final isReady = count > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _C.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color:
              isReady ? _C.success.withValues(alpha: 0.55) : _C.borderDim,
          width: isReady ? 1.5 : 1,
        ),
        boxShadow: isReady
            ? [
                BoxShadow(
                  color: _C.success.withValues(alpha: 0.10),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _ScanlinePainter())),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Icon(
                        Icons.groups_rounded,
                        color: isReady ? _C.success : _C.textSecondary,
                        size: 13,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SQUAD  $count / $maxSize',
                        style: _T.label.copyWith(
                          color: isReady ? _C.success : _C.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (count > 0)
                        GestureDetector(
                          onTap: () =>
                              ctx.read<SelectedPartyNotifier>().clear(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _C.bg1,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: _C.borderDim),
                            ),
                            child: Text(
                              'CLEAR',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: _C.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: isReady
                            ? Row(
                                key: const ValueKey('ready'),
                                children: [
                                  Icon(
                                    Icons.check_rounded,
                                    color: _C.success,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'READY',
                                    style: _T.label.copyWith(
                                      color: _C.success,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                key: const ValueKey('empty'),
                                'SELECT CREATURES',
                                style: _T.label.copyWith(color: _C.warn),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Slot rows
                  _buildSlotRow(allInstances, party, repo, 0, maxSize.clamp(1, 5)),
                  if (maxSize > 5) ...[
                    const SizedBox(height: 6),
                    _buildSlotRow(allInstances, party, repo, 5, maxSize),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotRow(
    List<CreatureInstance> allInstances,
    SelectedPartyNotifier party,
    CreatureCatalog repo,
    int from,
    int to,
  ) {
    return Row(
      children: List.generate(to - from, (i) {
        final slotIndex = from + i;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < (to - from - 1) ? 5 : 0),
            child: _buildSquadSlot(allInstances, party, repo, slotIndex),
          ),
        );
      }),
    );
  }

  Widget _buildSquadSlot(
    List<CreatureInstance> allInstances,
    SelectedPartyNotifier party,
    CreatureCatalog repo,
    int slotIndex,
  ) {
    final member =
        slotIndex < party.members.length ? party.members[slotIndex] : null;
    final instanceId = member?.instanceId;
    final instance = instanceId != null
        ? allInstances.firstWhereOrNull((i) => i.instanceId == instanceId)
        : null;
    final isFilled = instance != null;
    final species = isFilled ? repo.getCreatureById(instance.baseId) : null;

    return GestureDetector(
      onTap: isFilled
          ? () => context.read<SelectedPartyNotifier>().toggle(instanceId!)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 58,
        decoration: BoxDecoration(
          color: isFilled ? _C.success.withValues(alpha: 0.10) : _C.bg1,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isFilled
                ? _C.success.withValues(alpha: 0.55)
                : _C.borderDim,
            width: isFilled ? 1.5 : 1,
          ),
        ),
        child: isFilled
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (species != null)
                    Expanded(
                      child: Center(
                        child: InstanceSprite(
                          creature: species,
                          instance: instance,
                          size: 28,
                        ),
                      ),
                    )
                  else
                    Icon(Icons.help_outline, size: 20, color: _C.textMuted),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    child: Text(
                      '${slotIndex + 1}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: _C.success,
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 16, color: _C.textMuted),
                  const SizedBox(height: 2),
                  Text(
                    '${slotIndex + 1}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: _C.textMuted,
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
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
    List<CreatureInstance> allInstances,
  ) {
    final count = party.members.length;
    final canDeploy = count > 0;
    final label = canDeploy
        ? 'Deploy Team  ·  $count Selected'
        : 'Select Creatures to Continue';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: _C.bg1,
        border: Border(top: BorderSide(color: _C.borderDim)),
      ),
      child: GestureDetector(
        onTap: canDeploy
            ? () async {
                final existingIds =
                    allInstances.map((i) => i.instanceId).toSet();
                final validMembers = party.members
                    .where((m) => existingIds.contains(m.instanceId))
                    .toList();
                final selectedInstances = validMembers
                    .map(
                      (m) => allInstances.firstWhere(
                        (i) => i.instanceId == m.instanceId,
                      ),
                    )
                    .toList();

                bool proceed = true;
                if (ctx.mounted) {
                  final stamina = ctx.read<StaminaService>();
                  final hasZeroStamina = selectedInstances.any((inst) {
                    final state = stamina.computeState(inst);
                    return state.bars == 0;
                  });

                  if (hasZeroStamina) {
                    final warn = await showDialog<bool>(
                      context: ctx,
                      barrierDismissible: false,
                      builder: (_) => ZeroStaminaWarningDialog(theme: theme),
                    );
                    proceed = warn == true;
                  }
                }

                if (!proceed) return;

                if (widget.showDeployConfirm && ctx.mounted) {
                  final confirmed = await showDialog<bool>(
                    context: ctx,
                    barrierDismissible: false,
                    builder: (_) => DeployConfirmDialog(theme: theme),
                  );
                  if (confirmed != true) return;
                }

                if (ctx.mounted) {
                  Navigator.pop(
                    ctx,
                    ctx.read<SelectedPartyNotifier>().members,
                  );
                }
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: canDeploy ? _C.success : _C.bg2,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: canDeploy
                  ? _C.success.withValues(alpha: 0.8)
                  : _C.borderDim,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                canDeploy
                    ? Icons.arrow_forward_rounded
                    : Icons.hourglass_empty_rounded,
                size: 14,
                color: canDeploy ? _C.bg0 : _C.textMuted,
              ),
              const SizedBox(width: 10),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: canDeploy ? _C.bg0 : _C.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
      ctx.read<SelectedPartyNotifier>().toggle(inst.instanceId);
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

    final isMystic = species?.mutationFamily == 'Mystic';
    final hasMysticAlready =
        isMystic &&
        party.members.any((m) {
          final sel = allInstances.firstWhereOrNull(
            (x) => x.instanceId == m.instanceId,
          );
          final selSp = sel != null ? repo.getCreatureById(sel.baseId) : null;
          return selSp?.mutationFamily == 'Mystic';
        });

    if (hasSameSpecies) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            '${species?.name ?? 'This species'} is already in your squad.',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          backgroundColor: _C.warn,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    if (hasMysticAlready) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text(
            'Only one Mystic is allowed per squad.',
            style: TextStyle(fontFamily: 'monospace'),
          ),
          backgroundColor: Color(0xFFF97316),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    ctx.read<SelectedPartyNotifier>().toggle(inst.instanceId);
  }
}

