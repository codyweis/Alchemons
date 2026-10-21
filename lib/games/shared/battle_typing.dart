// lib/games/shared/battle_typing.dart
//
// The battle's strategy rules that are not code paths but facts: what an
// element is good against and how much it counts, what lingers how long.
// The fight (games/cosmic/cosmic_game_battle_status.dart) runs them, and
// the encyclopedia (screens/alchemical_encyclopedia_screen.dart) tells them,
// from here, so the two never drift apart.

import 'package:alchemons/games/shared/type_effectiveness.dart';
import 'package:flutter/foundation.dart';

/// How hard an element hits one it is strong against, and one it is weak
/// against, in a battle: the chart's ×2 and ×½, softened so a matchup tilts
/// a fight rather than decides it.
const double kBattleTypeStrong = 1.25;
const double kBattleTypeWeak = 0.8;

/// How long a poison's harm takes to land.
const double kBattlePoisonSeconds = 4.0;

/// How much longer a frozen or stunned Alchemon's special waits, and how
/// long before it can be interrupted again.
const double kBattleInterruptSeconds = 1.0;
const double kBattleInterruptGap = 4.0;

/// How far past a taunt's own reach it still draws a battle's Alchemons:
/// the floor is wider than open space's fights.
const double kBattleTauntReach = 1.3;

/// Typing on (the game) or off (the harness, to see what it changes).
@visibleForTesting
bool battleTypingOn = true;

/// How much harder [attacker] hits [defender], by element, in a battle.
double battleTypeMultiplier(String attacker, String defender) {
  if (!battleTypingOn) return 1;
  final m = typeEffectivenessMultiplier(attacker, [defender]);
  if (m > 1) return kBattleTypeStrong;
  if (m < 1) return kBattleTypeWeak;
  return 1;
}

/// The elements [element] is strong against in a battle, and those strong
/// against it (the encyclopedia shows them).
List<String> battleStrongAgainst(String element) =>
    List.unmodifiable(kTypeChart[element] ?? const <String>[]);
List<String> battleWeakAgainst(String element) => [
  for (final e in kTypeChart.entries)
    if (e.value.contains(element)) e.key,
];

/// Whether [element]'s abilities burn.
bool battleBurns(String? element) => element == 'Fire' || element == 'Lava';

