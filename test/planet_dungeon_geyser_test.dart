// Steam Star 1 — THE GEYSER FIELD.
//
// Six mouths breathe on one cycle. Four blow at the start (a fifth is choked
// with authored rubble), and the sixth sits under a slab at the heart. Capping
// a mouth — a body on the stone, the one rock an Earth hand can raise, or that
// rubble — takes it out of the system and sends its head to whatever is still
// open, so the field grows angrier the closer you get to solving it. Shut them
// all and the head has one place left to go: the slab.
//
// Three Alchemons plus one rock is exactly four caps. What the room asks is
// WHEN you spend the rock, because at full pressure the plumes throw bodies.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member(int slot, String element, String family) =>
    CosmicPartyMember(
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

PlanetDungeonGame _harness({void Function(int)? onStar}) {
  final party = [
    _member(0, 'Steam', 'pip'),
    _member(1, 'Earth', 'horn'),
    _member(2, 'Fire', 'mask'),
  ];
  final game = PlanetDungeonGame(
    element: 'Steam',
    party: party,
    initialStarMask: 0,
    onStarEarned: onStar ?? (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  game.currentRoomId = 'ember_causeway';
  for (final m in party) {
    final c = DungeonCreature(member: m)
      ..position = const Offset(350, 780)
      ..lastSafe = const Offset(350, 780);
    game.creatures.add(c);
    final stats = deriveCosmicSurvivalCompanionStats(member: m);
    game.combatCompanions.add(
      CosmicSurvivalCompanion(
        member: m,
        slotIndex: m.slotIndex,
        position: c.position,
        anchor: c.position,
        maxHp: stats.maxHp,
        currentHp: stats.maxHp,
        physAtk: stats.physAtk,
        elemAtk: stats.elemAtk,
        physDef: stats.physDef,
        elemDef: stats.elemDef,
        cooldownReduction: stats.cooldownReduction,
        critChance: stats.critChance,
        attackRange: stats.attackRange,
        specialAbilityRange: stats.specialAbilityRange,
        tethered: false,
        invincibleTimer: 0,
      ),
    );
  }
  return game;
}

void _step(PlanetDungeonGame game, [double seconds = 0.1]) {
  var t = 0.0;
  while (t < seconds) {
    game.update(1 / 60);
    t += 1 / 60;
  }
}

DungeonRoom _field(PlanetDungeonGame game) =>
    game.layout.rooms['ember_causeway']!;

GeyserMouth _mouth(PlanetDungeonGame game, String id) =>
    _field(game).geysers.firstWhere((g) => g.id == id);

/// Park a creature on a mouth and hold it there (idle creatures hold position,
/// which is what makes a body a cap).
void _stand(PlanetDungeonGame game, int slot, Offset at) {
  game.creatures[slot]
    ..position = at
    ..lastSafe = at;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the geyser field', () {
    test(
      'the field is authored: four blow, one is choked, one is the heart',
      () {
        final game = _harness();
        final room = _field(game);
        expect(room.geysers.length, 5);
        expect(
          room.geysers.where((g) => g.blockedAtStart).length,
          1,
          reason:
              'one mouth starts under rubble — which is why three bodies '
              'and one rock is exactly enough',
        );
        expect(room.capstone, isNotNull);
        expect(room.capstone!.starIndex, 0);
        _step(game);
        expect(
          game.geyserPressure,
          1,
          reason: 'the rubble counts from frame 1',
        );
      },
    );

    test('a body on the stone caps a mouth, and stepping off releases it', () {
      final game = _harness();
      _stand(game, 0, _mouth(game, 'g_north').position);
      _step(game);
      expect(game.cappedGeysers, contains('g_north'));
      expect(game.geyserPressure, 2);

      _stand(game, 0, const Offset(350, 780));
      _step(game);
      expect(
        game.cappedGeysers,
        isNot(contains('g_north')),
        reason: 'a cap is where a body IS, never an intention it had',
      );
      expect(game.geyserPressure, 1);
    });

    test('Earth raises ONE stone; pressing again unmakes it', () {
      final game = _harness();
      game.setActive(1); // the Earth horn
      _stand(game, 1, const Offset(350, 560));
      game.creatures[1].aimAngle = 0;
      game.activateAbility();
      expect(game.earthRock, isNotNull);
      final first = game.earthRock;

      // A second raise anywhere else is refused — there is only ever one.
      _stand(game, 1, const Offset(200, 560));
      game.activateAbility();
      expect(game.earthRock, first, reason: 'one stone in the world at a time');

      // Standing on your own stone and pressing again sinks it.
      _stand(game, 1, first!);
      game.activateAbility();
      expect(game.earthRock, isNull);
    });

    test('only Earth raises stone', () {
      final game = _harness();
      game.setActive(0); // Steam
      _stand(game, 0, const Offset(350, 560));
      game.activateAbility();
      expect(game.earthRock, isNull);
      game.askForRoomHint();
      expect(game.hintChannel, DungeonHintChannel.blocked);
    });

    test('the rock caps a mouth exactly like a body does', () {
      final game = _harness();
      game.setActive(1);
      final at = _mouth(game, 'g_east').position;
      _stand(game, 1, at + const Offset(0, 60));
      game.creatures[1].aimAngle = -1.5708; // facing up at the mouth
      game.activateAbility();
      expect(game.earthRock, isNotNull);
      _step(game, 0.8); // the stone heaves up
      // Move the Earth body away so only the ROCK can be the cap.
      _stand(game, 1, const Offset(350, 780));
      _step(game);
      expect(
        game.cappedGeysers,
        contains('g_east'),
        reason: 'the stone holds the mouth with nobody standing there',
      );
    });

    test('THE SOLVE: three bodies and the stone shut the field, and the '
        'heart takes the whole head', () {
      final earned = <int>[];
      final game = _harness(onStar: earned.add);

      // The stone goes down FIRST, while the field is still calm enough to
      // cross — that is the room's lesson.
      game.setActive(1);
      final east = _mouth(game, 'g_east').position;
      _stand(game, 1, east + const Offset(0, 60));
      game.creatures[1].aimAngle = -1.5708;
      game.activateAbility();
      _step(game, 0.8);
      expect(game.earthRock, isNotNull);

      // Then the three bodies take the three mouths still blowing.
      _stand(game, 0, _mouth(game, 'g_north').position);
      _stand(game, 1, _mouth(game, 'g_south').position);
      _stand(game, 2, _mouth(game, 'g_west').position);
      _step(game, 0.5);

      expect(game.geyserPressure, 5, reason: 'every mouth is shut');
      expect(game.capstoneBurst, isTrue);
      expect(game.hasStar(0), isTrue);
      expect(earned, [0]);
    });

    test('a field left open never bursts the heart, however long you wait', () {
      final game = _harness();
      _stand(game, 0, _mouth(game, 'g_north').position);
      _stand(game, 1, _mouth(game, 'g_south').position);
      // The west mouth is left roaring: four of five.
      _step(game, 20);
      expect(game.capstoneBurst, isFalse);
      expect(game.hasStar(0), isFalse);
    });

    test('a blast throws anyone caught in the plume, harder as it builds', () {
      final game = _harness();
      final west = _mouth(game, 'g_west').position;
      // Stand in the skirt of the west plume, not on the stone.
      final skirt = west + const Offset(70, 0);
      _stand(game, 2, skirt);
      game.setActive(2);
      _step(game, 6); // at least one full cycle
      expect(
        (game.creatures[2].position - west).distance,
        greaterThan((skirt - west).distance),
        reason: 'the plume throws you clear of the mouth',
      );
    });
  });

  // ── STAR 2 · THE LAUNCH ──────────────────────────────────

  group('the launch', () {
    DungeonRoom forge(PlanetDungeonGame game) =>
        game.layout.rooms['cinder_forge']!;

    GeyserMouth riser(PlanetDungeonGame game, String id) =>
        forge(game).geysers.firstWhere((g) => g.id == id);

    PlanetDungeonGame atForge({void Function(int)? onStar}) {
      final game = _harness(onStar: onStar);
      game.currentRoomId = 'cinder_forge';
      for (final c in game.creatures) {
        c
          ..position = const Offset(350, 200)
          ..lastSafe = const Offset(350, 200);
      }
      return game;
    }

    test('the chasm is real: the far shore cannot be walked to', () {
      final game = atForge();
      final room = forge(game);
      expect(room.platforms.length, 2);
      // The void between the shores is not standable.
      expect(room.platforms.first.contains(const Offset(350, 450)), isFalse);
      expect(room.platforms.last.contains(const Offset(350, 450)), isFalse);
    });

    test('a body does NOT cap a riser — it rides it', () {
      final game = atForge();
      final r = riser(game, 'r_short');
      _stand(game, 0, r.position);
      _step(game);
      expect(
        game.cappedGeysers,
        isNot(contains('r_short')),
        reason: "a riser's throat is too wide for one body",
      );
    });

    test('the stone DOES cap a riser', () {
      final game = atForge();
      game.setActive(1);
      final r = riser(game, 'r_short');
      _stand(game, 1, r.position + const Offset(0, -60));
      game.creatures[1].aimAngle = 1.5708; // face down at the riser
      game.activateAbility();
      _step(game, 0.8);
      _stand(game, 1, const Offset(350, 120));
      _step(game);
      expect(game.cappedGeysers, contains('r_short'));
    });

    test('the throw is only as long as the field you are holding', () {
      // One body riding, the others parked OFF the mouths: a weak field.
      final game = atForge();
      final r = riser(game, 'r_short');
      _stand(game, 1, const Offset(620, 60));
      _stand(game, 2, const Offset(60, 60));
      _stand(game, 0, r.position);
      game.creatures[0].aimAngle = 0; // aimed east at the far shore
      final before = game.creatures[0].position.dx;
      _step(game, 6);
      final weak = game.creatures[0].position.dx - before;

      // Now the same rider with the whole field shut behind him.
      final game2 = atForge();
      final r2 = riser(game2, 'r_short');
      _stand(game2, 1, riser(game2, 'r_hob_a').position);
      _stand(game2, 2, riser(game2, 'r_hob_b').position);
      _stand(game2, 0, r2.position);
      game2.creatures[0].aimAngle = 0;
      final before2 = game2.creatures[0].position.dx;
      _step(game2, 6);
      final strong = game2.creatures[0].position.dx - before2;

      expect(
        strong,
        greaterThan(weak),
        reason: 'every mouth shut behind a riser is more throw in front',
      );
    });

    test('THE SOLVE: send them in the order the decaying field allows', () {
      final earned = <int>[];
      final game = atForge(onStar: earned.add);
      final far = forge(game).platforms.last;

      // The stone caps first — it is the one cap that never has to leave.
      game.setActive(1);
      final hobC = riser(game, 'r_hob_c').position;
      _stand(game, 1, hobC + const Offset(0, -60));
      game.creatures[1].aimAngle = 1.5708;
      game.activateAbility();
      _step(game, 0.8);

      // Rider 0 takes the LONG riser while two bodies still hold the field.
      _stand(game, 1, riser(game, 'r_hob_a').position);
      _stand(game, 2, riser(game, 'r_hob_b').position);
      _stand(game, 0, riser(game, 'r_long').position);
      game.creatures[0].aimAngle = 0; // the chasm runs east now
      _step(game, 6);
      expect(
        far.inflate(2).contains(game.creatures[0].position),
        isTrue,
        reason: 'the long throw needs the fullest field',
      );

      // Then rider 1, with one body left behind plus the stone.
      _stand(game, 1, riser(game, 'r_short').position);
      game.creatures[1].aimAngle = 0;
      _step(game, 6);
      expect(far.inflate(2).contains(game.creatures[1].position), isTrue);

      // And the last one over, with only the stone and the rubble holding.
      _stand(game, 2, riser(game, 'r_short').position);
      game.creatures[2].aimAngle = 0;
      _step(game, 6);
      expect(
        far.inflate(2).contains(game.creatures[2].position),
        isTrue,
        reason: 'the short riser is what the last body can still afford',
      );

      _step(game, 0.5);
      expect(game.hasStar(1), isTrue);
      expect(earned, [1]);
    });
  });
}
