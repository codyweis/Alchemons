// A wild Alchemon in open space fights with the same abilities the party's
// companions use (cosmic_game_duel.dart). Every family but Mystic (which
// never wanders) and every element: it must cast its special, its abilities
// must reach the party, the party's must reach it, and the bodies that stand
// in for either side must never leak into the world.
//
// WILD_DUEL_REPORT=1 prints one line per matchup.

import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
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

Future<(CosmicGame, Offset)> _arena() async {
  final game = CosmicGame(
    world_: CosmicWorld.generate(seed: 37),
    onMeterChanged: () {},
  );
  game.ship = ShipComponent(pos: Offset.zero);
  game.onGameResize(Vector2(900, 700));
  await game.onLoad();
  // Deep space, away from every planet.
  final world = game.world_;
  var home = Offset.zero;
  var best = -1.0;
  for (var gx = 1; gx < 20; gx++) {
    for (var gy = 1; gy < 20; gy++) {
      final p = Offset(
        world.worldSize.width * gx / 20,
        world.worldSize.height * gy / 20,
      );
      var nearest = double.infinity;
      for (final planet in world.planets) {
        nearest = min(nearest, (planet.position - p).distance);
      }
      if (nearest > best) {
        best = nearest;
        home = p;
      }
    }
  }
  game.teleportTo(home);
  game.enemies.clear();
  game.activeBoss = null;
  for (final m in [
    _member('Pip', 'Fire', 0),
    _member('Wing', 'Air', 1),
    _member('Horn', 'Fire', 2),
  ]) {
    game.summonCompanion(m, slotIndex: m.slotIndex);
  }
  for (final c in game.activeCompanions.values) {
    c.invincibleTimer = 0;
    c.maxHp = 1 << 20;
    c.currentHp = 1 << 20;
  }
  return (game, home);
}

/// A body left in the world would be fought, drawn and counted as an enemy.
bool _leaked(CosmicGame game) => game.enemies.any((e) => e.health > 1e5);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final report = Platform.environment['WILD_DUEL_REPORT'] != null;

  for (final family in ['Horn', 'Wing', 'Let', 'Pip', 'Mane', 'Mask', 'Kin']) {
    for (final element in kCosmicAbilityElements) {
      test('a wild $element $family fights with its abilities', () async {
        final (game, home) = await _arena();
        final wild = SpaceWildAlchemon(
          id: 'wild-$family-$element',
          member: _member(family, element, -1),
          rarity: 'Common',
          position: home + const Offset(260, 40),
        );
        game.addWildAlchemon(wild);
        WildDuelEnd? ended;
        game.onWildDuelEnded = (_, how) => ended = how;
        game.engageWild(wild);
        final opp = game.duelOpponent!;
        expect(opp.member.slotIndex, kWildCasterSlot);
        opp.maxHp = 1 << 20;
        opp.currentHp = 1 << 20;
        opp.specialCooldown = 0;
        opp.invincibleTimer = 0;

        final party = game.activeCompanions.values.toList();
        final partyStart = {for (final c in party) c: c.currentHp};
        final shipStart = game.shipHealth;
        // A Horn's shield soaks the party's hits first; count those too.
        var oppLost = 0;
        var oppHealth = opp.currentHp + opp.shieldHp;
        var casts = 0;
        var lastCooldown = opp.specialCooldown;
        var peakInFlight = 0;
        var leakedFrames = 0;
        const dt = 1 / 60;
        for (var f = 0; f < 60 * 8; f++) {
          game.enemies.clear();
          game.update(dt);
          if (_leaked(game)) leakedFrames++;
          final health = opp.currentHp + opp.shieldHp;
          if (health < oppHealth) oppLost += oppHealth - health;
          oppHealth = health;
          if (opp.specialCooldown > lastCooldown + 0.5) casts++;
          lastCooldown = opp.specialCooldown;
          peakInFlight = max(peakInFlight, game.duelOpponentProjectiles.length);
          if (ended != null) break;
        }
        final partyLost = party.fold<int>(
          0,
          (sum, c) => sum + partyStart[c]! - c.currentHp,
        );
        if (report) {
          // ignore: avoid_print
          print(
            '$family $element: casts $casts, in flight ≤$peakInFlight, '
            'party lost $partyLost, ship lost '
            '${(shipStart - game.shipHealth).toStringAsFixed(2)}, '
            'wild lost $oppLost, ended $ended',
          );
        }
        expect(leakedFrames, 0, reason: 'a combat body leaked into enemies');
        expect(game.lootDrops, isEmpty, reason: 'a combat body dropped loot');
        expect(ended, isNull, reason: 'the fight ended: $ended');
        if (!isPassiveOnlyCosmicAbility(family, element)) {
          expect(
            casts,
            greaterThan(0),
            reason: 'the wild $element $family never cast its special',
          );
        }
        expect(partyLost, greaterThan(0), reason: 'nothing reached the party');
        expect(oppLost, greaterThan(0), reason: 'nothing reached the wild one');
      });
    }
  }
}
