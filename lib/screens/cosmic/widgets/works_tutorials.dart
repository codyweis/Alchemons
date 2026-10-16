// lib/screens/cosmic/widgets/works_tutorials.dart
//
// What each building of the Works does, in a few short pages: shown once,
// the first time that building is built, and again from the ? beside its
// name. Plain words that name what the panel shows (HOPPER, SEND HOME,
// COLLECT, KEEP OF EACH, MAKE, OPEN THE ARMORY) and the stat each job reads.

import 'package:alchemons/games/cosmic/works.dart';
import 'package:alchemons/widgets/story_dialog.dart';
import 'package:flutter/material.dart';

import 'cosmic_panel_kit.dart';

/// The pages for [b]; an extractor's name its planet's [element].
List<StoryBeat> worksTutorial(WorksBuilding b, {String? element}) {
  switch (b) {
    case WorksBuilding.extractor:
      final e = element;
      final mines = e == null
          ? "Mines this planet's element"
          : 'Mines $e from this planet';
      final who = e == null
          ? "an Alchemon of this planet's element"
          : '${_aOrAn(e)} $e Alchemon';
      return [
        StoryBeat(
          title: 'EXTRACTOR',
          message:
              '$mines, even while you are away. What it mines goes into its '
              'hopper.',
        ),
        StoryBeat(
          title: 'MINER',
          message: 'Assign $who as its miner. A better harvester mines faster.',
        ),
        StoryBeat(
          title: 'HOPPER',
          message:
              'The hopper holds ${WorkRules.hopperCap(1)} and stops filling '
              'when full. Fly here and tap SEND HOME to move it into home '
              'storage. At tier 2, a courier flies it home for you.',
        ),
      ];
    case WorksBuilding.scavengerBay:
      return [
        const StoryBeat(
          title: 'SCAVENGER BAY',
          message:
              'Scavengers fly to planets you have found and bring back '
              'elements. Some trips bring astral shards too.',
        ),
        const StoryBeat(
          title: 'SCAVENGERS',
          message:
              'Assign an Alchemon to send it out. Speed makes trips shorter, '
              'Strength brings back more, and Intelligence finds shards more '
              'often.',
        ),
        StoryBeat(
          title: 'CRATES',
          message:
              'Each trip fills a crate. Tap COLLECT to move them into home '
              'storage. When all ${WorkRules.crateCap(1)} crates are full, '
              'scavengers wait. Upgrades add scavengers and crates.',
        ),
      ];
    case WorksBuilding.silverPress:
      return const [
        StoryBeat(
          title: 'SILVER PRESS',
          message:
              'Turns spare elements in home storage into silver. '
              '${WorkRules.grainsPerSilver} elements make 1 silver.',
        ),
        StoryBeat(
          title: 'PRESSER',
          message:
              'Assign an Alchemon to run it. Higher Beauty presses faster, '
              'and so do upgrades.',
        ),
        StoryBeat(
          title: 'KEEP OF EACH',
          message:
              'It never presses an element below the amount set under KEEP '
              'OF EACH. Raise it to keep more for building and upgrades.',
        ),
      ];
    case WorksBuilding.refinery:
      return const [
        StoryBeat(
          title: 'REFINERY',
          message:
              'Makes one element out of two others, using recipes you have '
              'found by fusing. Tap CODEX to see them.',
        ),
        StoryBeat(
          title: 'MAKE',
          message:
              'Pick a recipe under MAKE. At tier 1, every 2 elements in make '
              '1 out. Upgrades waste less.',
        ),
        StoryBeat(
          title: 'REFINER',
          message:
              'Assign an Alchemon to run it. Higher Intelligence refines '
              'faster. It leaves the amount set under KEEP OF EACH INPUT '
              'alone.',
        ),
      ];
    case WorksBuilding.armory:
      return [
        const StoryBeat(
          title: 'ARMORY',
          message:
              "Your ship's weapons, systems, ammo, home stations and upgrades "
              'are made here. Tap OPEN THE ARMORY.',
        ),
        StoryBeat(
          title: 'TIERS',
          message:
              'No Alchemon works here. Its tier sets how far ship upgrades '
              'go: at tier 1, ammo and missile power reach level '
              '${WorkRules.armoryPowerCap(1)}, and the fuel tank and cargo '
              'hold reach level ${WorkRules.armoryTankCap(1)}. Upgrade it to '
              'go further.',
        ),
      ];
  }
}

String _aOrAn(String word) =>
    'AEIOU'.contains(word.isEmpty ? 'x' : word[0].toUpperCase()) ? 'an' : 'a';

Future<void> showWorksTutorial(
  BuildContext context,
  WorksBuilding b, {
  String? element,
}) => showStoryDialog(
  context,
  beats: worksTutorial(b, element: element),
  primaryLabel: 'OK',
);

/// The ? beside a building's name: opens its tutorial again.
class WorksHelpButton extends StatelessWidget {
  const WorksHelpButton({
    super.key,
    required this.building,
    required this.accent,
    this.element,
  });

  final WorksBuilding building;
  final Color accent;
  final String? element;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey('works.help.${building.name}'),
    behavior: HitTestBehavior.opaque,
    onTap: () => showWorksTutorial(context, building, element: element),
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accent.withValues(alpha: 0.6)),
        ),
        child: Text('?', style: panelLabel(10.5, accent, spacing: 0)),
      ),
    ),
  );
}
