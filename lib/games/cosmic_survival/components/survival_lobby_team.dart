// lib/games/cosmic_survival/components/survival_lobby_team.dart
//
// The team the run will take, in the survival lobby: one small specimen
// case per slot — the creature standing in its element's light, its level
// in the corner, its name engraved beneath — and empty slots as plain ink.
// Still art, not the animated sprite: the lobby is idle while the player
// reads it, and nothing here should repaint every frame.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_panel_kit.dart'
    show panelLabel, panelPalette;
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart'
    show CaseLightPainter, MarkDiamond, caseMono, elementLight;
import 'package:flutter/material.dart';

/// The lobby's TEAM section: a heading with the count and a way to change
/// it, the slots, and — while it is empty — what to do.
class SurvivalLobbyTeam extends StatelessWidget {
  const SurvivalLobbyTeam({
    super.key,
    required this.members,
    required this.slots,
    required this.loaded,
    required this.accent,
    required this.onChoose,
  });

  final List<CosmicPartyMember> members;
  final int slots;

  /// False until the saved team has been read, so an empty row does not
  /// tell the player to choose a team they already have.
  final bool loaded;
  final Color accent;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final empty = loaded && members.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'TEAM',
              style: panelLabel(10.5, panelPalette.muted, spacing: 1.8),
            ),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 1, color: panelPalette.lineSoft)),
            const SizedBox(width: 10),
            Text(
              '${members.length} / $slots',
              style: panelLabel(10.5, panelPalette.ink.withValues(alpha: 0.8)),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 118,
              child: BracketButton(
                key: const ValueKey('survival.changeTeam'),
                label: members.isEmpty ? 'CHOOSE TEAM' : 'CHANGE TEAM',
                height: 30,
                primary: false,
                palette: panelPalette,
                accent: accent,
                onTap: onChoose,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          key: const ValueKey('survival.teamSlots'),
          behavior: HitTestBehavior.opaque,
          onTap: context.soundAction(onChoose),
          child: Row(
            children: [
              for (var i = 0; i < slots; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: i < members.length
                      ? _TeamSlot(member: members[i])
                      // A row with nobody in it has no names to line up
                      // with, so its empty slots leave no room for one.
                      : _EmptySlot(nameLine: members.isNotEmpty),
                ),
              ],
            ],
          ),
        ),
        if (empty) ...[
          const SizedBox(height: 10),
          Text(
            'Choose up to ${_count(slots)} Alchemons to take into the run.',
            style: TextStyle(
              color: panelPalette.muted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

String _count(int n) => switch (n) {
  1 => 'one',
  2 => 'two',
  3 => 'three',
  4 => 'four',
  5 => 'five',
  6 => 'six',
  _ => '$n',
};

/// The case's height for its width, and the engraved line under it.
const double _caseAspect = 1.0;
const double _lineGap = 6;
const double _lineHeight = 13;

class _TeamSlot extends StatelessWidget {
  const _TeamSlot({required this.member});

  final CosmicPartyMember member;

  @override
  Widget build(BuildContext context) {
    final light = elementLight(member.element);
    final name = member.displayName.isEmpty ? 'Alchemon' : member.displayName;
    return Semantics(
      label: '$name, level ${member.level}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: _caseAspect,
            child: ClipRect(
              child: CustomPaint(
                painter: CaseLightPainter(color: light),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final art = box.maxWidth * 0.74;
                    return Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: box.maxHeight * 0.08,
                          child: Center(
                            child: member.imagePath == null
                                ? SizedBox.square(dimension: art)
                                : Image.asset(
                                    member.imagePath!,
                                    width: art,
                                    height: art,
                                    fit: BoxFit.contain,
                                    cacheWidth: 192,
                                    errorBuilder: (_, _, _) =>
                                        SizedBox.square(dimension: art),
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 5,
                          left: 6,
                          child: Text(
                            'LV ${member.level}',
                            style: caseMono(
                              9,
                              panelPalette.ink.withValues(alpha: 0.85),
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
          const SizedBox(height: _lineGap),
          SizedBox(
            height: _lineHeight,
            child: Row(
              children: [
                MarkDiamond(color: light, size: 5),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: caseMono(9, panelPalette.ink, spacing: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.nameLine});

  /// Keeps the height of a filled slot's engraved line.
  final bool nameLine;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: _caseAspect,
          child: ColoredBox(
            color: panelPalette.bg1.withValues(alpha: 0.7),
            child: Center(
              child: Icon(
                AppIcons.add_rounded,
                size: 16,
                color: panelPalette.muted.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
        if (nameLine) const SizedBox(height: _lineGap + _lineHeight),
      ],
    );
  }
}
