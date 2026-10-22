// lib/screens/battle/battle_how_to.dart
//
// How a battle works, in the game's one dialog (widgets/story_dialog.dart):
// shown the first time a battle is opened — the battle hub, the Trials'
// BATTLE, the Emerald Cup's ladder — and again from RULES. Plain words, the
// rules as cosmic_game_battle.dart plays them.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart'
    show kBattleOvertime, kBattleSwaps, kBattleTimeLimit;
import 'package:alchemons/games/shared/battle_typing.dart';
import 'package:alchemons/widgets/story_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The rules, a page each: the field, the bench, the elements, the clock.
List<StoryBeat> get battleHowToBeats {
  final overtime = (kBattleTimeLimit - kBattleOvertime.at).round();
  final harder = ((kBattleTypeStrong - 1) * 100).round();
  return [
    const StoryBeat(
      title: 'BATTLE',
      message:
          'You bring four Alchemons. Two fight at a time; the other two wait '
          'on the bench.\n\n'
          'Attacks and specials fire on their own. Tap an enemy to focus '
          'it. Tap it again to let go.',
    ),
    StoryBeat(
      title: 'THE BENCH',
      message:
          'To swap, tap one on your bench, then the field card it replaces. '
          'You have $kBattleSwaps swaps a fight.\n\n'
          'When one of yours falls, the healthiest on the bench takes its '
          'place. If both on your field fall at once, the bench comes out. '
          'You lose when all of yours are down.',
    ),
    StoryBeat(
      title: 'ELEMENTS',
      message:
          'An element hits the ones it is strong against $harder% harder, '
          'and the ones it is weak against softer. Each element\'s page in '
          'the Codex says which.\n\n'
          'Fire and Lava burn: a burning Alchemon gets half of every heal. '
          'Poison hurts over time. A freeze holds back a special. Horns draw '
          'attacks to them unless you have picked a target. Swapping out '
          'ends a burn or a poison.',
    ),
    StoryBeat(
      title: 'OVERTIME',
      message:
          'The last $overtime seconds are overtime: heals and shields are '
          'weaker and hits grow harder. If time runs out, the side with the '
          'most health left wins.',
    ),
  ];
}

/// The rules, now.
Future<void> showBattleHowTo(BuildContext context) =>
    showStoryDialog(context, beats: battleHowToBeats, primaryLabel: 'OK');

bool _asking = false;

/// The rules, the first time a battle is opened; remembered in Settings so
/// they are shown once. Nothing without a save to remember it in.
Future<void> maybeShowBattleHowTo(BuildContext context) async {
  final settings = context.read<AlchemonsDatabase?>()?.settingsDao;
  if (settings == null || _asking) return;
  _asking = true;
  try {
    if (await settings.hasSeenBattleHowTo() || !context.mounted) return;
    await showBattleHowTo(context);
    await settings.setBattleHowToSeen();
  } finally {
    _asking = false;
  }
}
