import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/show_quick_instance_dialog.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'party_picker_dialogs.dart';
import 'team_builder_dialog.dart';

// ---------- Header ----------

class StageHeader extends StatelessWidget {
  final FactionTheme theme;

  const StageHeader({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    context.watch<SelectedPartyNotifier>();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).maybePop();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.surfaceAlt,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: theme.border),
              ),
              child: Icon(Icons.arrow_back, color: theme.text, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SELECT YOUR TEAM',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: theme.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap a creature to add or remove from squad',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Build teams button (replaces live count badge)
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              await showDialog<void>(
                context: context,
                builder: (_) => TeamBuilderDialog(theme: theme),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.surfaceAlt,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: theme.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder_open, color: theme.text, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Teams',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: theme.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Footer ----------

class PartyFooter extends StatelessWidget {
  const PartyFooter({
    super.key,
    required this.theme,
    this.showDeployConfirm = true,
  });

  final FactionTheme theme;

  /// When false the "Deploy Team?" confirmation dialog is skipped.
  final bool showDeployConfirm;

  @override
  Widget build(BuildContext context) {
    final party = context.watch<SelectedPartyNotifier>();
    final db = context.watch<AlchemonsDatabase>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cache all instances once instead of using StreamBuilder
          FutureBuilder<List<CreatureInstance>>(
            future: db.creatureDao.getAllInstances(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }

              final allInstances = snapshot.data!;
              final existingIds = allInstances
                  .map((inst) => inst.instanceId)
                  .toSet();

              final rawMembers = party.members;
              final validMembers = rawMembers
                  .where((m) => existingIds.contains(m.instanceId))
                  .toList();

              // Prune any ghost members (instances that no longer exist in DB)
              if (validMembers.length != rawMembers.length) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    context.read<SelectedPartyNotifier>().setMembers(
                      validMembers,
                    );
                  }
                });
              }

              // Map valid members to actual instances
              final selectedInstances = validMembers
                  .map(
                    (m) => allInstances.firstWhere(
                      (inst) => inst.instanceId == m.instanceId,
                    ),
                  )
                  .toList();

              if (selectedInstances.isEmpty) {
                return const SizedBox.shrink();
              }

              final count = validMembers.length;
              final canDeploy =
                  count > 0 && count <= SelectedPartyNotifier.maxSize;

              final stamina = context.read<StaminaService>();
              final hasZeroStamina = selectedInstances.any((inst) {
                final state = stamina.computeState(inst);
                return state.bars == 0;
              });

              return Column(
                children: [
                  TeamDisplay(
                    theme: theme,
                    selectedInstances: selectedInstances,
                  ),
                  const SizedBox(height: 12),

                  DeployButton(
                    theme: theme,
                    enabled: canDeploy,
                    selectedCount: count,
                    onTap: canDeploy
                        ? () async {
                            bool proceed = true;

                            if (hasZeroStamina) {
                              final warn = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) =>
                                    ZeroStaminaWarningDialog(theme: theme),
                              );
                              proceed = warn == true;
                            }

                            if (!proceed) return;

                            if (showDeployConfirm) {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) =>
                                    DeployConfirmDialog(theme: theme),
                              );
                              if (confirmed != true) return;
                            }

                            if (context.mounted) {
                              Navigator.pop(
                                context,
                                context.read<SelectedPartyNotifier>().members,
                              );
                            }
                          }
                        : null,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class TeamDisplay extends StatelessWidget {
  final FactionTheme theme;
  final List<CreatureInstance> selectedInstances;

  const TeamDisplay({
    super.key,
    required this.theme,
    required this.selectedInstances,
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CreatureCatalog>();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.greenAccent.shade400.withValues(alpha: .5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.groups_rounded,
                color: Colors.greenAccent.shade400,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'YOUR SQUAD',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: theme.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.shade400.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.greenAccent.shade400.withValues(alpha: .5),
                  ),
                ),
                child: Text(
                  '${selectedInstances.length} / ${SelectedPartyNotifier.maxSize}',
                  style: TextStyle(
                    color: Colors.greenAccent.shade400,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(SelectedPartyNotifier.maxSize, (i) {
              final inst = i < selectedInstances.length
                  ? selectedInstances[i]
                  : null;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                  child: inst == null
                      ? TeamSlotEmpty(theme: theme)
                      : TeamSlotFilled(
                          instance: inst,
                          theme: theme,
                          repo: repo,
                          onRemove: () => context
                              .read<SelectedPartyNotifier>()
                              .toggle(inst.instanceId),
                        ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class TeamSlotFilled extends StatelessWidget {
  const TeamSlotFilled({
    super.key,
    required this.instance,
    required this.theme,
    required this.repo,
    required this.onRemove,
  });

  final CreatureInstance instance;
  final FactionTheme theme;
  final CreatureCatalog repo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final base = repo.getCreatureById(instance.baseId);
    final name = base?.name ?? instance.baseId;

    return GestureDetector(
      onTap: onRemove,
      onLongPress: base == null
          ? null
          : () {
              showQuickInstanceDialog(
                context: context,
                theme: theme,
                creature: base,
                instance: instance,
              );
            },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: base != null
                  ? InstanceSprite(creature: base, instance: instance, size: 28)
                  : Icon(Icons.help_outline, size: 14, color: theme.textMuted),
            ),
            const SizedBox(height: 3),
            Text(
              name,
              style: TextStyle(
                color: theme.text,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'LV ${instance.level}',
              style: TextStyle(
                color: Colors.amber.shade400,
                fontSize: 7,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            // Stamina pips
            Builder(
              builder: (context) {
                final stamina = context.read<StaminaService>();
                final state = stamina.computeState(instance);
                final bars = state.bars.clamp(0, instance.staminaMax);
                final max = instance.staminaMax;
                final pipColor = bars == 0
                    ? Colors.red.shade400
                    : bars == 1 && max > 1
                    ? Colors.orange.shade400
                    : Colors.greenAccent.shade400;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(max, (i) {
                    final filled = i < bars;
                    return Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? pipColor
                            : pipColor.withValues(alpha: 0.15),
                        border: Border.all(
                          color: pipColor.withValues(alpha: filled ? 0.9 : 0.3),
                          width: 0.6,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class TeamSlotEmpty extends StatelessWidget {
  const TeamSlotEmpty({super.key, required this.theme});
  final FactionTheme theme;

  @override
  Widget build(BuildContext context) {
    final fg = theme.textMuted;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
            alignment: Alignment.center,
            child: Icon(Icons.add_outlined, size: 14, color: fg),
          ),
          const SizedBox(height: 3),
          Text(
            'Empty',
            style: TextStyle(
              color: fg,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '--',
            style: TextStyle(
              color: fg,
              fontSize: 7,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class DeployButton extends StatefulWidget {
  final FactionTheme theme;
  final bool enabled;
  final int selectedCount;
  final VoidCallback? onTap;

  const DeployButton({
    super.key,
    required this.theme,
    required this.enabled,
    required this.selectedCount,
    required this.onTap,
  });

  @override
  State<DeployButton> createState() => _DeployButtonState();
}

class _DeployButtonState extends State<DeployButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canTap = widget.enabled;

    return AnimatedBuilder(
      animation: _pressCtrl,
      builder: (context, _) {
        return GestureDetector(
          onTapDown: canTap ? (_) => _pressCtrl.forward() : null,
          onTapUp: canTap ? (_) => _pressCtrl.reverse() : null,
          onTapCancel: canTap ? () => _pressCtrl.reverse() : null,
          onTap: canTap ? widget.onTap : null,
          child: Transform.scale(
            scale: 1.0 - (_pressCtrl.value * 0.05),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: canTap ? Colors.greenAccent : widget.theme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: canTap
                      ? Colors.greenAccent.shade400
                      : widget.theme.border.withValues(alpha: .8),
                  width: 1.5,
                ),
                boxShadow: canTap
                    ? [
                        BoxShadow(
                          color: Colors.greenAccent.shade400.withValues(
                            alpha: .4,
                          ),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    color: canTap ? Colors.white : widget.theme.textMuted,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.selectedCount > 0
                        ? 'Confirm Team  (${widget.selectedCount})'
                        : 'Select Team Members',
                    style: TextStyle(
                      color: canTap ? Colors.white : widget.theme.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
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
}
