// lib/screens/party_picker/team_builder_dialog.dart
//
// Saved teams, over the team picker: the team now chosen with a way to save
// it, and the saved ones as rows of small lit cases — tap one to take it.
// Framed as every bracket dialog is (showBracketConfirm).

import 'dart:convert';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart'
    show CaseLightPainter, caseElementLight, caseMono, kCaseGilt;
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

  /// How many member slots to display per team.
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
  static const int _maxSavedTeams = 10;

  late AlchemonsDatabase _db;
  List<Map<String, dynamic>> _teams = [];
  bool _loading = true;
  Map<String, CreatureInstance> _instancesById = {};
  Map<String, Creature> _creaturesById = {};

  List<String> get _activeTeamMemberIds =>
      widget.activeMemberIds ??
      context
          .read<SelectedPartyNotifier>()
          .members
          .map((m) => m.instanceId)
          .toList();

  bool _isActiveTeam(List<String> members) {
    final active = _activeTeamMemberIds;
    if (members.length != active.length) return false;
    for (var i = 0; i < members.length; i++) {
      if (members[i] != active[i]) return false;
    }
    return true;
  }

  static List<String> _membersOf(Map<String, dynamic> team) =>
      (team['members'] as List<dynamic>?)?.whereType<String>().toList() ??
      const [];

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
    final members = _activeTeamMemberIds;
    if (members.isEmpty) return;

    if (_teams.length >= _maxSavedTeams) {
      showGameSnack(
        context,
        'You can save up to 10 teams. Delete one to add another.',
      );
      return;
    }

    setState(() => _teams.add({'members': members}));
    await _persist();
    if (mounted) showGameSnack(context, 'Team saved.');
  }

  Future<void> _applyTeam(int idx) async {
    final savedMembers = _membersOf(_teams[idx]);
    final members = savedMembers
        .where((id) => _instancesById.containsKey(id))
        .take(widget.slotCount)
        .toList();
    if (members.isEmpty) {
      showGameSnack(
        context,
        'That saved team no longer has any of its Alchemons.',
      );
      return;
    }

    if (widget.onApply != null) {
      widget.onApply!(members);
    } else {
      context.read<SelectedPartyNotifier>().setMembers([
        for (final id in members) PartyMember(instanceId: id),
      ]);
    }
    if (members.length != savedMembers.length) {
      showGameSnack(
        context,
        'Loaded ${members.length} of that team; the rest are gone.',
      );
    }
    Navigator.pop(context);
  }

  Future<void> _deleteTeam(int idx) async {
    final confirmed = await showBracketConfirm(
      context,
      palette: BracketPalette.fromTheme(widget.theme),
      accent: kLeaveDangerAccent,
      title: 'DELETE TEAM',
      message: 'Delete this saved team? The Alchemons in it stay yours.',
      confirmLabel: 'DELETE',
    );
    if (!confirmed || !mounted) return;
    setState(() => _teams.removeAt(idx));
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.fromTheme(widget.theme);
    final accent = bracketReadableAccent(widget.theme);
    final active = _activeTeamMemberIds;
    final alreadySaved = _teams.any((t) => _isActiveTeam(_membersOf(t)));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: accent.withValues(alpha: 0.9),
          strokeWidth: 1.3,
        ),
        child: Container(
          color: palette.bg1,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'SAVED TEAMS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: caseMono(14, palette.ink, spacing: 1.8),
                    ),
                  ),
                  if (!_loading)
                    Text(
                      '${_teams.length} / $_maxSavedTeams',
                      style: caseMono(10.5, palette.muted, spacing: 1.2),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _label('THIS TEAM', palette),
              const SizedBox(height: 8),
              if (active.isEmpty)
                Text(
                  'Choose a team in the picker to save it here.',
                  style: bracketText(context, 13, palette.muted),
                )
              else
                Row(
                  children: [
                    Expanded(child: _cases(active, palette)),
                    const SizedBox(width: 10),
                    Container(
                      width: 72,
                      color: palette.bg0,
                      child: BracketButton(
                        key: const ValueKey('savedTeams.save'),
                        label: alreadySaved ? 'SAVED' : 'SAVE',
                        height: 36,
                        primary: false,
                        enabled: !alreadySaved && !_loading,
                        palette: palette,
                        accent: accent,
                        onTap: _saveCurrentAs,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              _label('SAVED', palette),
              const SizedBox(height: 8),
              Flexible(
                child: _loading
                    ? const SizedBox(height: 48)
                    : _teams.isEmpty
                    ? Text(
                        'No saved teams yet.',
                        style: bracketText(context, 13, palette.muted),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _teams.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _savedRow(i, _membersOf(_teams[i]), palette),
                      ),
              ),
              const SizedBox(height: 18),
              BracketButton(
                label: 'CLOSE',
                height: 42,
                primary: false,
                palette: palette,
                accent: accent,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, BracketPalette palette) => Row(
    children: [
      Text(text, style: caseMono(10.5, palette.muted, spacing: 1.8)),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 1, color: palette.lineSoft)),
    ],
  );

  /// A saved team: its cases on a dark well, lit in gilt when it is the
  /// team now chosen. Tap to take it; the bin deletes it.
  Widget _savedRow(int i, List<String> members, BracketPalette palette) {
    final inUse = _isActiveTeam(members);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(() => _applyTeam(i)),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: inUse ? kCaseGilt : palette.line,
          strokeWidth: 1.4,
        ),
        child: Container(
          color: palette.bg0,
          padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
          child: Row(
            children: [
              Expanded(child: _cases(members, palette)),
              const SizedBox(width: 8),
              GestureDetector(
                key: ValueKey('savedTeams.delete.$i'),
                behavior: HitTestBehavior.opaque,
                onTap: context.soundAction(() => _deleteTeam(i)),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    AppIcons.delete_outline,
                    size: 16,
                    color: kLeaveDangerAccent.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One small case per slot, left to right; a slot past the team's end is
  /// plain ink, and one whose Alchemon has gone shows a question.
  Widget _cases(List<String> members, BracketPalette palette) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 5.0;
        final n = widget.slotCount;
        final size = ((box.maxWidth - gap * (n - 1)) / n).clamp(0.0, 44.0);
        return Row(
          children: [
            for (var j = 0; j < n; j++) ...[
              if (j > 0) const SizedBox(width: gap),
              SizedBox.square(
                dimension: size,
                child: _miniCase(
                  j < members.length ? members[j] : null,
                  size,
                  palette,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _miniCase(String? id, double size, BracketPalette palette) {
    if (id == null) {
      return ColoredBox(color: palette.bg1.withValues(alpha: 0.8));
    }
    final inst = _instancesById[id];
    final creature = inst == null ? null : _creaturesById[inst.baseId];
    if (inst == null || creature == null) {
      return ColoredBox(
        color: palette.bg1.withValues(alpha: 0.8),
        child: _loading
            ? null
            : Icon(
                AppIcons.help_outline,
                size: size * 0.4,
                color: palette.muted,
              ),
      );
    }
    return ClipRect(
      child: CustomPaint(
        painter: CaseLightPainter(color: caseElementLight(creature)),
        child: Center(
          child: InstanceSprite(
            creature: creature,
            instance: inst,
            size: size * 0.82,
          ),
        ),
      ),
    );
  }
}
