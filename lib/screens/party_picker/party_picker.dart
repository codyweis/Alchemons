// lib/games/survival/party_picker_screen.dart
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_instaces_grid.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'party_picker_empty_state.dart';
import 'party_picker_widgets.dart';

class PartyPickerScreen extends StatefulWidget {
  const PartyPickerScreen({
    super.key,
    this.showDeployConfirm = true,
    this.enforceUniqueSpecies = true,
  });

  /// When false the "Deploy Team?" confirmation dialog is skipped.
  /// Set to false when opening from contexts that don't deploy to the wild
  /// (e.g. boss squad selection).
  final bool showDeployConfirm;

  /// When true, prevents selecting two instances of the same species.
  /// Disable this for wild deployment where duplicate species are allowed.
  final bool enforceUniqueSpecies;

  @override
  State<PartyPickerScreen> createState() => _PartyPickerScreenState();
}

class _PartyPickerScreenState extends State<PartyPickerScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final db = context.watch<AlchemonsDatabase>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0),
                radius: 1.2,
                colors: [
                  theme.surface,
                  theme.surface,
                  theme.surfaceAlt.withValues(alpha: .6),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  StageHeader(theme: theme),
                  const SizedBox(height: 10),

                  // Main content
                  Expanded(
                    child: StreamBuilder<List<CreatureInstance>>(
                      stream: db.creatureDao.watchAllInstances(),
                      builder: (context, snap) {
                        final instances = snap.data ?? [];
                        return _buildAllInstancesView(theme, instances);
                      },
                    ),
                  ),

                  // Footer with party info
                  PartyFooter(
                    theme: theme,
                    showDeployConfirm: widget.showDeployConfirm,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllInstancesView(
    FactionTheme theme,
    List<CreatureInstance> instances,
  ) {
    if (instances.isEmpty) {
      return const NoSpeciesOwnedWrapper();
    }

    final party = context.watch<SelectedPartyNotifier>();
    final repo = context.read<CreatureCatalog>();

    return AllCreatureInstances(
      theme: theme,
      selectedInstanceIds: party.members.map((m) => m.instanceId).toList(),
      onTap: (inst) {
        // Already selected → deselect, no checks needed
        if (party.contains(inst.instanceId)) {
          context.read<SelectedPartyNotifier>().toggle(inst.instanceId);
          return;
        }

        final species = repo.getCreatureById(inst.baseId);

        // Block duplicate species (same baseId already in squad)
        final hasSameSpecies = party.members.any((m) {
          final sel = instances.firstWhere(
            (i) => i.instanceId == m.instanceId,
            orElse: () => inst,
          );
          return sel.baseId == inst.baseId && sel.instanceId != inst.instanceId;
        });

        // Block second Mystic
        final isThisMystic = species?.mutationFamily == 'Mystic';
        final hasMysticAlready =
            isThisMystic &&
            party.members.any((m) {
              final sel = instances.firstWhere(
                (i) => i.instanceId == m.instanceId,
                orElse: () => inst,
              );
              final selSp = repo.getCreatureById(sel.baseId);
              return selSp?.mutationFamily == 'Mystic';
            });

        if (widget.enforceUniqueSpecies && hasSameSpecies) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${species?.name ?? 'That creature'} is already in your squad.',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }

        if (hasMysticAlready) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only one Mystic is allowed per squad.'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        context.read<SelectedPartyNotifier>().toggle(inst.instanceId);
      },
    );
  }
}
