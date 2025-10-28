// widgets/wilderness/encounter_scaffold.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/stamina_bar.dart';

import 'package:alchemons/models/wilderness.dart'; // PartyMember model you created

class EncounterScaffold extends StatelessWidget {
  final String chanceText;
  final String status;

  final List<PartyMember> party;
  final String? chosenInstanceId;

  final ValueChanged<String> onSelectParty;
  final VoidCallback? onTry;
  final VoidCallback onRun;

  const EncounterScaffold({
    super.key,
    required this.chanceText,
    required this.status,
    required this.party,
    required this.chosenInstanceId,
    required this.onSelectParty,
    required this.onTry,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    final canTry = onTry != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle
            Container(
              height: 5,
              width: 56,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade100,
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // Chance pill + status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: 16,
                        color: Colors.indigo.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        chanceText,
                        style: TextStyle(
                          color: Colors.indigo.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Party list
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose a partner',
                style: TextStyle(
                  color: Colors.indigo.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                itemCount: party.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final m = party[i];
                  final selected = m.instanceId == chosenInstanceId;
                  return _PartyMemberTile(
                    instanceId: m.instanceId,
                    luck: m.luck,
                    selected: selected,
                    onTap: () => onSelectParty(m.instanceId),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.favorite_rounded),
                    label: const Text('Try to Breed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canTry
                          ? Colors.green.shade600
                          : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: canTry ? 2 : 0,
                    ),
                    onPressed: canTry ? onTry : null,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.run_circle_rounded),
                  label: const Text('Run'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo.shade700,
                    side: BorderSide(color: Colors.indigo.shade200, width: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onRun,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Party member tile -------------------------------------------------------

class _PartyMemberTile extends StatelessWidget {
  final String instanceId;
  final double luck; // 0.0 .. e.g. 0.15
  final bool selected;
  final VoidCallback onTap;

  const _PartyMemberTile({
    required this.instanceId,
    required this.luck,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureRepository>();

    return FutureBuilder<CreatureInstance?>(
      future: db.getInstance(instanceId),
      builder: (context, snap) {
        final inst = snap.data;
        final base = inst == null ? null : repo.getCreatureById(inst.baseId);
        final name = base?.name ?? (inst?.baseId ?? 'Unknown');

        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 220,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: selected
                    ? Colors.green.shade500
                    : Colors.indigo.shade100,
                width: selected ? 3 : 2,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (selected)
                  BoxShadow(
                    color: Colors.green.shade100,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + level
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.indigo.shade800,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (inst != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.amber.shade300,
                                ),
                              ),
                              child: Text(
                                'L${inst.level}',
                                style: TextStyle(
                                  color: Colors.amber.shade800,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Stamina
                      if (inst != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: StaminaBadge(
                            instanceId: inst.instanceId,
                            showCountdown: true,
                          ),
                        ),

                      const SizedBox(height: 6),

                      // Luck
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: Colors.purple.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+${(luck * 100).toStringAsFixed(0)}% luck',
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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
}
