// widgets/wilderness/encounter_scaffold.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/bracket_frame.dart';

import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/widgets/app_icons.dart';

// Encounter sheets sit on dark scene/space backdrops — always dark.
const _palette = BracketPalette.dark;
const _breedAccent = Color(0xFF22C55E);
const _runColor = Color(0xFFC0392B);

class EncounterScaffold extends StatelessWidget {
  final String chanceText;
  final String status;

  final List<PartyMember> party;
  final String? chosenInstanceId;

  final ValueChanged<String> onSelectParty;
  final VoidCallback? onTry;
  final VoidCallback onRun;
  final VoidCallback onMinimize;

  const EncounterScaffold({
    super.key,
    required this.chanceText,
    required this.status,
    required this.party,
    required this.chosenInstanceId,
    required this.onSelectParty,
    required this.onTry,
    required this.onRun,
    required this.onMinimize,
  });

  @override
  Widget build(BuildContext context) {
    final canTry = onTry != null;
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return CustomPaint(
      painter: BracketFramePainter(
        color: _breedAccent.withValues(alpha: 0.8),
        bracketSize: 14,
        strokeWidth: 1.4,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        decoration: BoxDecoration(
          color: _palette.surfaceFill(),
          border: Border(
            top: BorderSide(
              color: _breedAccent.withValues(alpha: 0.8),
              width: 2,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGrabHandle(),
              if (isLandscape)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 200,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildChancePill(context),
                          const SizedBox(height: 12),
                          _buildActionButtons(context, canTry),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusText(context),
                          const SizedBox(height: 12),
                          _buildPartySection(context),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _buildChancePill(context),
                        const SizedBox(width: 10),
                        Expanded(child: _buildStatusText(context)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPartySection(context),
                    const SizedBox(height: 16),
                    _buildActionButtons(context, canTry),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrabHandle() {
    return SizedBox(
      height: 26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(height: 4, width: 48, color: _palette.lineSoft),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onMinimize,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  AppIcons.keyboard_arrow_down_rounded,
                  color: _palette.muted,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChancePill(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _breedAccent.withValues(alpha: 0.14),
        border: const Border(left: BorderSide(color: _breedAccent, width: 2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.favorite_rounded, size: 14, color: _breedAccent),
          const SizedBox(width: 7),
          Text(
            chanceText,
            style: bracketText(
              context,
              12.5,
              _palette.ink,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText(BuildContext context) {
    return Text(
      status,
      style: bracketText(
        context,
        12.5,
        _palette.muted,
        weight: FontWeight.w500,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
    );
  }

  Widget _buildPartySection(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose a partner',
          style: bracketText(
            context,
            12,
            _palette.muted,
            weight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            itemCount: party.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final m = party[i];
              return _PartyMemberTile(
                instanceId: m.instanceId,
                selected: m.instanceId == chosenInstanceId,
                onTap: () => onSelectParty(m.instanceId),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, bool canTry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _EncounterButton(
          label: 'Try to breed',
          icon: AppIcons.favorite_rounded,
          color: _breedAccent,
          filled: true,
          large: true,
          onTap: canTry ? onTry : null,
        ),
        const SizedBox(height: 10),
        _EncounterButton(
          label: 'Run',
          icon: AppIcons.run_circle_rounded,
          color: _runColor,
          filled: false,
          large: false,
          onTap: onRun,
        ),
      ],
    );
  }
}

class _EncounterButton extends StatelessWidget {
  const _EncounterButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
    required this.large,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final bool large;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final baseColor = enabled ? color : _palette.muted;
    final fg = filled ? (enabled ? Colors.white : _palette.muted) : baseColor;
    final height = large ? 50.0 : 44.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: BracketFramePainter(
          color: enabled ? baseColor : _palette.line.withValues(alpha: 0.6),
          bracketSize: 9,
          strokeWidth: large ? 1.4 : 1.1,
        ),
        child: Container(
          height: height,
          alignment: Alignment.center,
          color: filled
              ? (enabled ? baseColor : _palette.surfaceMutedFill())
              : baseColor.withValues(alpha: enabled ? 0.12 : 0.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: large ? 17 : 15, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: bracketText(
                  context,
                  large ? 14 : 13,
                  fg,
                  weight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartyMemberTile extends StatelessWidget {
  final String instanceId;
  final bool selected;
  final VoidCallback onTap;

  const _PartyMemberTile({
    required this.instanceId,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();

    return FutureBuilder<CreatureInstance?>(
      future: db.creatureDao.getInstance(instanceId),
      builder: (context, snap) {
        final inst = snap.data;
        final base = inst == null ? null : repo.getCreatureById(inst.baseId);
        final name = base?.name ?? (inst?.baseId ?? 'Unknown');
        final frameColor = selected
            ? _breedAccent
            : _palette.line.withValues(alpha: 0.7);

        return GestureDetector(
          onTap: onTap,
          child: CustomPaint(
            painter: BracketFramePainter(
              color: frameColor,
              bracketSize: 8,
              strokeWidth: selected ? 1.4 : 1.05,
            ),
            child: Container(
              width: 210,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? _breedAccent.withValues(alpha: 0.10)
                    : _palette.surfaceMutedFill(),
                border: Border.all(
                  color: _palette.lineSoft.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _palette.bg0,
                      border: Border.all(
                        color: frameColor.withValues(alpha: 0.8),
                      ),
                    ),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: bracketText(
                        context,
                        18,
                        _palette.ink,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: bracketText(
                                  context,
                                  13,
                                  _palette.ink,
                                  weight: FontWeight.w700,
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
                                  color: const Color(
                                    0xFFE4C16A,
                                  ).withValues(alpha: 0.16),
                                  border: const Border(
                                    left: BorderSide(
                                      color: Color(0xFFE4C16A),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Lv ${inst.level}',
                                  style: bracketText(
                                    context,
                                    10.5,
                                    const Color(0xFFE4C16A),
                                    weight: FontWeight.w800,
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
      },
    );
  }
}
