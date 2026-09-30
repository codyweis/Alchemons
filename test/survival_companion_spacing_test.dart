// Survival companions keep their own space: a full party, including five of
// one family, spreads round its patrol rings and its targets instead of
// stacking, and keeps off the ship.
//
// Before body-sized spacing, five Mystics overlapped on 66% of frames (worst
// by 97 units) and five Kins on 34%.

import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member(String family, String element, int slot) =>
    CosmicPartyMember(
      instanceId: '$family-$element-$slot',
      baseId: '${family.substring(0, 3).toUpperCase()}01',
      displayName: '$element $family',
      family: family,
      element: element,
      level: 10,
      slotIndex: slot,
      statSpeed: 3,
      statIntelligence: 3,
      statStrength: 3,
      statBeauty: 3,
      staminaBars: 5,
      staminaMax: 5,
    );

/// The creature's radius on screen: survival draws it in a 62.4 box scaled
/// by family, and it fills about two thirds of that.
double _body(CosmicSurvivalCompanion c) =>
    62.4 *
    (kCompanionSpeciesScale[c.member.family.toLowerCase()] ?? 1.3) *
    0.34;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const elements = ['Fire', 'Water', 'Air', 'Earth', 'Ice'];
  final parties = <String, List<CosmicPartyMember>>{
    'Pip, Wing, Horn': [
      _member('Pip', 'Fire', 0),
      _member('Wing', 'Air', 1),
      _member('Horn', 'Fire', 2),
    ],
    'two Wings, Mystic, Pip, Kin': [
      _member('Wing', 'Air', 0),
      _member('Wing', 'Fire', 1),
      _member('Mystic', 'Light', 2),
      _member('Pip', 'Water', 3),
      _member('Kin', 'Plant', 4),
    ],
    for (final family in ['Mystic', 'Kin', 'Horn'])
      'five ${family}s': [
        for (var i = 0; i < 5; i++) _member(family, elements[i], i),
      ],
  };

  for (final entry in parties.entries) {
    test('${entry.key}: no stacking, clear of the ship', () async {
      final party = entry.value;
      final game = CosmicSurvivalGame(
        party: party,
        random: Random(11),
        onGameOver: () {},
      );
      game.onGameResize(Vector2(900, 700));
      await game.onLoad();
      game.startGame();
      final packLeader = kRarePerks.firstWhere((d) => d.id == 'pack_leader');
      for (var i = 1; i < party.length; i++) {
        game.powerUps.apply(packLeader);
      }
      for (final m in party) {
        game.summonCompanion(m.slotIndex);
      }
      for (var w = 1; w < 6; w++) {
        game.spawner.forceNextWaveForTest();
      }

      var frames = 0, stackedFrames = 0, onShipFrames = 0;
      var worst = double.infinity;
      for (var f = 0; f < 60 * 20; f++) {
        game.update(1 / 60);
        if (game.showingPowerUpSelection) {
          game.alchemicalMeter = 0;
          game.dismissPowerUpSelection();
        }
        game.orb.currentHp = game.orb.maxHp;
        game.ship.currentHp = game.ship.maxHp.toDouble();
        game.isGameOver = false;
        if (f < 120) continue; // let them step out of their tears
        frames++;
        final comps = game.activeCompanions.values
            .where((c) => !c.isDead)
            .toList();
        var stacked = false;
        for (var i = 0; i < comps.length; i++) {
          final a = comps[i];
          if ((a.position - game.ship.position).distance < _body(a)) {
            onShipFrames++;
          }
          for (var j = i + 1; j < comps.length; j++) {
            final b = comps[j];
            // A horn's charge dashes through whatever is in the way.
            if (a.chargeTimer > 0 || b.chargeTimer > 0) continue;
            final gap =
                (a.position - b.position).distance - _body(a) - _body(b);
            worst = min(worst, gap);
            // A graze of a few units at the sprites' edges is fine; this
            // counts one creature drawn over another.
            if (gap < -15) stacked = true;
          }
        }
        if (stacked) stackedFrames++;
      }
      game.onRemove();

      // ignore: avoid_print
      print(
        '${entry.key}: stacked on '
        '${(100 * stackedFrames / frames).toStringAsFixed(1)}% of frames, '
        'worst ${worst.toStringAsFixed(0)}, '
        'over the ship ${(100 * onShipFrames / frames).toStringAsFixed(1)}%',
      );
      expect(stackedFrames / frames, lessThan(0.06));
      expect(onShipFrames / frames, lessThan(0.03));
    });
  }
}
