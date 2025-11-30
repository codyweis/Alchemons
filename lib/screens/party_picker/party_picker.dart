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
  const PartyPickerScreen({super.key});

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
                  theme.surfaceAlt.withOpacity(.6),
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
                  PartyFooter(theme: theme),
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

    return AllCreatureInstances(
      theme: theme,
      selectedInstanceIds: party.members.map((m) => m.instanceId).toList(),
      onTap: (inst) {
        context.read<SelectedPartyNotifier>().toggle(inst.instanceId);
      },
    );
  }
}
