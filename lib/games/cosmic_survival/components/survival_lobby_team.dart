// lib/games/cosmic_survival/components/survival_lobby_team.dart
//
// The team the run will take, in the survival lobby: one small specimen
// case per slot — the creature standing in its element's light, its level
// in the corner, its name engraved beneath — and empty slots as plain ink.
// Still art, not the animated sprite: the lobby is idle while the player
// reads it, and nothing here should repaint every frame.
//
// Each case flies between here and the team picker (SurvivalTeamHero): the
// chosen team comes down into its slots, and CHANGE TEAM carries it up.

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
    this.locked = false,
    this.note,
  });

  final List<CosmicPartyMember> members;
  final int slots;

  /// The team is a saved run's, and stays as that run left it: it cannot be
  /// changed until the run ends or is abandoned.
  final bool locked;

  /// A plain line under the slots saying why the team is as it is, in place
  /// of the empty team's prompt.
  final String? note;

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
                enabled: !locked,
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
          onTap: locked ? null : context.soundAction(onChoose),
          child: Row(
            children: [
              for (var i = 0; i < slots; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: i < members.length
                      ? _TeamSlot(member: members[i], slot: i)
                      // A row with nobody in it has no names to line up
                      // with, so its empty slots leave no room for one.
                      : _EmptySlot(nameLine: members.isNotEmpty),
                ),
              ],
            ],
          ),
        ),
        if (note != null || empty) ...[
          const SizedBox(height: 10),
          Text(
            note ??
                'Choose up to ${_count(slots)} Alchemons to take into the run.',
            key: note == null ? null : const ValueKey('survival.teamNote'),
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

/// The width a portrait is decoded at (the screen precaches at the same, so
/// a newly chosen case lands with its portrait already drawn).
const int kSurvivalTeamCaseCacheWidth = 192;

/// The case's height for its width, and the engraved line under it.
const double _caseAspect = 1.0;
const double _lineGap = 6;
const double _lineHeight = 13;

class _TeamSlot extends StatelessWidget {
  const _TeamSlot({required this.member, required this.slot});

  final CosmicPartyMember member;
  final int slot;

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
            child: SurvivalTeamHero(
              instanceId: member.instanceId,
              slot: slot,
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
                                      cacheWidth: kSurvivalTeamCaseCacheWidth,
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

// ──────────────────────────────────────────────────────────────────────────────
// THE FLIGHT
// ──────────────────────────────────────────────────────────────────────────────

/// How long the team picker takes to open and to close: long enough for the
/// cases' flight between it and the lobby to be followed by eye.
const Duration kSurvivalTeamPickerIn = Duration(milliseconds: 420);
const Duration kSurvivalTeamPickerOut = Duration(milliseconds: 620);

/// The team picker's route: the platform's own page transition, slowed to
/// the flight's pace.
class SurvivalTeamPickerRoute<T> extends MaterialPageRoute<T> {
  SurvivalTeamPickerRoute({required super.builder});

  @override
  Duration get transitionDuration => kSurvivalTeamPickerIn;

  @override
  Duration get reverseTransitionDuration => kSurvivalTeamPickerOut;
}

/// A team member's case, flying between the team picker's row and the
/// lobby's slots. Both ends wear one of these; the lobby's case (still art)
/// is what flies either way, so the flight never shows an empty case while
/// the picker is still reading its specimens.
class SurvivalTeamHero extends StatelessWidget {
  const SurvivalTeamHero({
    super.key,
    required this.instanceId,
    required this.slot,
    required this.child,
  });

  final String instanceId;

  /// Left to right: each slot leaves a beat after the one before it.
  final int slot;
  final Widget child;

  /// The share of the flight between one slot setting off and the next.
  static const double _beat = 0.07;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: ('survival.team', instanceId),
      createRectTween: (begin, end) =>
          _SlotFlight(slot.clamp(0, 4) * _beat, begin, end),
      flightShuttleBuilder: (_, _, direction, from, to) =>
          ((direction == HeroFlightDirection.push ? from : to).widget as Hero)
              .child,
      child: child,
    );
  }
}

/// An arc, travelled within its slot's share of the flight.
class _SlotFlight extends MaterialRectArcTween {
  _SlotFlight(double start, Rect? begin, Rect? end)
    : _within = Interval(start, start + 1 - 4 * SurvivalTeamHero._beat),
      super(begin: begin, end: end);

  final Interval _within;

  @override
  Rect lerp(double t) => super.lerp(_within.transform(t));
}
