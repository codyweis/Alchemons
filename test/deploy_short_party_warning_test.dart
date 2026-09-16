import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/screens/party_picker/party_picker_dialogs.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter_test/flutter_test.dart';

/// The short-party warning has three rules, all of which were broken before:
///  * it triggers on the real party limit, not a hardcoded 5
///  * it stays quiet when the player cannot field a full team anyway
///  * it stays quiet when the team is already full
void main() {
  final theme = FactionTheme.scorchForge();

  bool warns({
    required int partyCount,
    required int availableCount,
    int maxSize = SelectedPartyNotifier.defaultMaxSize,
  }) => DeployConfirmDialog(
    theme: theme,
    partyCount: partyCount,
    maxSize: maxSize,
    availableCount: availableCount,
  ).shortHandedForTest;

  test('the party limit is 4, not 5', () {
    expect(SelectedPartyNotifier.defaultMaxSize, 4);
  });

  test('warns when short and the player owns enough', () {
    expect(warns(partyCount: 2, availableCount: 9), isTrue);
    expect(warns(partyCount: 3, availableCount: 4), isTrue);
  });

  test('silent when the player cannot fill the team', () {
    // The bug: someone with three creatures was told they were short of four.
    expect(warns(partyCount: 3, availableCount: 3), isFalse);
    expect(warns(partyCount: 1, availableCount: 1), isFalse);
    expect(warns(partyCount: 2, availableCount: 3), isFalse);
  });

  test('silent when the team is full', () {
    expect(warns(partyCount: 4, availableCount: 12), isFalse);
  });

  test('silent when no limit is supplied', () {
    expect(warns(partyCount: 1, availableCount: 9, maxSize: 0), isFalse);
  });
}
