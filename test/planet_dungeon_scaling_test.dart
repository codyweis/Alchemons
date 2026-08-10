// Campaign difficulty scaling: dungeon enemies — and especially guardians —
// harden as more planets' guardians fall (stats run 0–5.0, so the final
// dungeons must demand near-perfect teams while the first stays approachable).

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member(int slot, String element, String family) {
  return CosmicPartyMember(
    instanceId: 'inst_$slot',
    baseId: 'base_$slot',
    displayName: '$element $family',
    element: element,
    family: family,
    level: 10,
    statSpeed: 3,
    statIntelligence: 3,
    statStrength: 3,
    statBeauty: 3,
    slotIndex: slot,
    staminaBars: 3,
    staminaMax: 3,
  );
}

PlanetDungeonGame _game(int cleared) => PlanetDungeonGame(
  element: 'Fire',
  party: [_member(0, 'Fire', 'mask')],
  initialStarMask: 0,
  onStarEarned: (_) {},
  onPlayerDown: () {},
  onChanged: () {},
  clearedGuardianCount: cleared,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('campaign difficulty scaling', () {
    test('a fresh save is the authored baseline', () {
      final g = _game(0);
      expect(g.progressHpMul, 1.0);
      expect(g.progressDmgMul, 1.0);
      expect(g.guardianStrikesNeeded, PlanetDungeonGame.maxGuardianHp);
    });

    test('the seventeenth dungeon is a different animal', () {
      final last = _game(16);
      expect(last.progressHpMul, closeTo(8.2, 0.001));
      expect(last.progressDmgMul, closeTo(2.92, 0.001));
      expect(last.guardianStrikesNeeded, 16); // 4 lull strikes → 16
    });

    test('scaling grows monotonically with each fallen guardian', () {
      for (var i = 0; i < 16; i++) {
        expect(_game(i + 1).progressHpMul, greaterThan(_game(i).progressHpMul));
        expect(
          _game(i + 1).guardianStrikesNeeded,
          greaterThan(_game(i).guardianStrikesNeeded),
        );
      }
    });
  });

  group('PlanetStarState.guardiansDefeated', () {
    test('counts star-3 clears, excluding the planet being entered', () {
      const state = PlanetStarState(
        starMasks: {
          'Air': 0x7, // 3 stars — guardian beaten
          'Fire': 0x4, // star 3 only — guardian beaten
          'Water': 0x3, // stars 1+2 — guardian still standing
        },
      );
      expect(state.guardiansDefeated(), 2);
      expect(state.guardiansDefeated(excluding: 'Fire'), 1);
      expect(state.guardiansDefeated(excluding: 'Water'), 2);
      expect(PlanetStarState.fresh().guardiansDefeated(), 0);
    });
  });
}
