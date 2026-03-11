import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TeamBuilderDialog extends StatefulWidget {
  const TeamBuilderDialog({
    super.key,
    required this.theme,
    this.storageKey = 'saved_teams',
    this.slotCount = 4,
    this.activeMemberIds,
    this.onApply,
  });
  final FactionTheme theme;

  /// Settings key used to persist teams. Pass a different key for survival.
  final String storageKey;

  /// How many member slots to display per team (use 10 for survival)
  final int slotCount;

  /// Optional current active member ids (instance ids) to save from.
  final List<String>? activeMemberIds;

  /// Optional callback invoked when a saved team is applied. If null,
  /// the dialog will default to writing into `SelectedPartyNotifier`.
  final ValueChanged<List<String>>? onApply;

  @override
  State<TeamBuilderDialog> createState() => _TeamBuilderDialogState();
}

class _TeamBuilderDialogState extends State<TeamBuilderDialog> {
  late AlchemonsDatabase _db;
  List<Map<String, dynamic>> _teams = [];
  bool _loading = true;
  Map<String, CreatureInstance> _instancesById = {};
  Map<String, Creature> _creaturesById = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    _db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final raw = await _db.settingsDao.getSetting(widget.storageKey);
    if (raw == null || raw.isEmpty) {
      setState(() {
        _teams = [];
        _loading = false;
      });
      return;
    }

    try {
      final parsed = jsonDecode(raw) as List<dynamic>;
      // load instance + species caches for sprite display
      final allInst = await _db.creatureDao.getAllInstances();
      _instancesById = {for (final i in allInst) i.instanceId: i};
      final Map<String, Creature> speciesMap = {};
      for (final inst in allInst) {
        final c = repo.getCreatureById(inst.baseId);
        if (c != null) speciesMap[inst.baseId] = c;
      }
      _creaturesById = speciesMap;

      setState(() {
        _teams = parsed
            .whereType<Map<String, dynamic>>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _teams = [];
        _loading = false;
      });
    }
  }

  Future<void> _persist() async {
    await _db.settingsDao.setSetting(widget.storageKey, jsonEncode(_teams));
  }

  Future<void> _saveCurrentAs() async {
    final membersList =
        widget.activeMemberIds ??
        context
            .read<SelectedPartyNotifier>()
            .members
            .map((m) => m.instanceId)
            .toList();
    if (membersList.isEmpty) return;

    final members = membersList;
    final entry = {'members': members};
    setState(() {
      _teams.add(entry);
    });
    final messenger = ScaffoldMessenger.of(context);
    await _persist();
    // show a quick confirmation
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Team saved'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _applyTeam(int idx) async {
    final t = _teams[idx];
    final members = (t['members'] as List<dynamic>)
        .whereType<String>()
        .toList();
    final partyMembers = members
        .map((id) => PartyMember(instanceId: id))
        .toList();
    if (widget.onApply != null) {
      widget.onApply!(members);
    } else {
      context.read<SelectedPartyNotifier>().setMembers(partyMembers);
    }
    Navigator.pop(context);
  }

  Future<void> _deleteTeam(int idx) async {
    final t = ForgeTokens(widget.theme);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: t.bg1,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: t.borderAccent, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: t.bg0,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                  border: Border(bottom: BorderSide(color: t.borderDim)),
                ),
                child: Text(
                  'DELETE TEAM',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  children: [
                    Text(
                      'Delete this saved team?',
                      style: TextStyle(color: t.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: t.bg2,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: t.borderDim),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'CANCEL',
                                style: TextStyle(
                                  color: t.textSecondary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: t.danger.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: t.danger.withValues(alpha: 0.4),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'DELETE',
                                style: TextStyle(
                                  color: t.danger,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
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
      ),
    );
    if (confirm != true) return;
    setState(() {
      _teams.removeAt(idx);
    });
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(widget.theme);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: t.bg1,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: t.borderAccent, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: t.bg0,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
                border: Border(bottom: BorderSide(color: t.borderDim)),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder_open, color: t.amber, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'TEAM BUILDER',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                children: [
                  if (_loading) const CircularProgressIndicator(),
                  if (!_loading && _teams.isEmpty)
                    Text(
                      'No saved teams',
                      style: TextStyle(color: t.textSecondary),
                    ),
                  if (!_loading && _teams.isNotEmpty)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_teams.length, (i) {
                        final team = _teams[i];
                        final members =
                            (team['members'] as List<dynamic>?)
                                ?.whereType<String>()
                                .toList() ??
                            [];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: t.bg2,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: t.borderDim),
                          ),
                          child: Row(
                            children: [
                              // Sprites row (replace name)
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: List.generate(widget.slotCount, (
                                      j,
                                    ) {
                                      if (j >= members.length) {
                                        return Container(
                                          width: 42,
                                          height: 42,
                                          margin: const EdgeInsets.only(
                                            right: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: t.bg1,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: t.borderDim,
                                            ),
                                          ),
                                        );
                                      }

                                      final id = members[j];
                                      final inst = _instancesById[id];
                                      if (inst == null) {
                                        return Container(
                                          width: 42,
                                          height: 42,
                                          margin: const EdgeInsets.only(
                                            right: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: t.bg1,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: t.borderDim,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.help_outline,
                                            color: t.textSecondary,
                                            size: 20,
                                          ),
                                        );
                                      }
                                      final creature =
                                          _creaturesById[inst.baseId];
                                      if (creature == null) {
                                        return Container(
                                          width: 42,
                                          height: 42,
                                          margin: const EdgeInsets.only(
                                            right: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: t.bg1,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: t.borderDim,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.help_outline,
                                            color: t.textSecondary,
                                            size: 20,
                                          ),
                                        );
                                      }

                                      return Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        width: 42,
                                        height: 42,
                                        child: InstanceSprite(
                                          creature: creature,
                                          instance: inst,
                                          size: 42,
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _applyTeam(i),
                                icon: Icon(Icons.upload, color: t.amber),
                                tooltip: 'Load team',
                              ),
                              IconButton(
                                onPressed: () => _deleteTeam(i),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: t.danger,
                                ),
                                tooltip: 'Delete team',
                              ),
                            ],
                          ),
                        );
                      }),
                    ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _saveCurrentAs,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: t.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: t.success.withValues(alpha: 0.4),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Save Selected Team',
                              style: TextStyle(
                                color: t.success,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: t.bg2,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: t.borderDim),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Close',
                              style: TextStyle(
                                color: t.textSecondary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
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
  }
}
