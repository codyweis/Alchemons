// SOLARIN — THE SHADOW FLOOR, pinned.
//
// Light's rule: light is nothing, only shadow holds your weight, and nothing
// stands on its own shadow. Every room was proved by exhaustive search in the
// prototype (docs/prototypes/light_shadow_floor); this file holds the same
// claims against the Dart rules the phone plays by:
//
//  1. SOLVABLE — each room's shortest plan (exported from the prototype's
//     solver) replays move by move as LEGAL moves here and ends solved.
//  2. DEEP — the tool each room is about is necessary: rooms I, III and IV
//     cannot be crossed without the pin, Room IV not without the veil, the
//     Room I habit (pin the first gap) is a dead end in Room IV.
//  3. THE KEY — exactly one of the twenty-one studs lays the key's shadow in
//     the lock.
//  4. PLAYED — the rules as the real game object runs them: the entry rite,
//     arrivals, a step onto bare light refused with a bare line, the pin,
//     the pipe, a pair of rooms banking a star, the spans, the maxim, and
//     Solarin's fight: its glass all floor but burning in its light, its
//     swing on its own rhythm, its flare, and blows only from its shadow.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_light.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shortest plans, exported from the prototype's solver (moves are
/// 'Name>x,y', 'pin', 'veil', 'pipe', 'crank', 'strike(Name)').
const Map<String, List<String>> _plans = {
  'eclipse_walk': [
    'Light>1,4',
    'Light>0,4',
    'Light>0,5',
    'Dark>1,0',
    'Dark>1,1',
    'Steam>0,2',
    'Dark>1,2',
    'Dark>1,3',
    'Dark>1,4',
    'Dark>1,5',
    'Steam>1,2',
    'Steam>1,3',
    'Steam>1,4',
    'veil',
    'Steam>1,3',
    'crank',
    'crank',
    'crank',
    'Dark>2,5',
    'Dark>3,5',
    'Dark>4,5',
    'Dark>4,4',
    'Dark>5,4',
    'crank',
    'Dark>6,4',
    'Dark>6,5',
    'pin',
    'Dark>7,5',
    'Steam>1,4',
    'Steam>1,5',
    'crank',
    'crank',
    'crank',
    'crank',
    'Steam>2,5',
    'Light>1,5',
    'Steam>3,5',
    'Light>2,5',
    'Steam>4,5',
    'Light>3,5',
    'Steam>4,4',
    'Light>4,5',
    'Steam>5,4',
    'Light>4,4',
    'Steam>6,4',
    'Light>5,4',
    'Steam>7,4',
    'Light>6,4',
    'Steam>8,4',
    'Light>7,4',
  ],
  'own_shadow': [
    'Dark>3,5',
    'Light>2,5',
    'Light>2,4',
    'Dark>4,5',
    'Dark>5,5',
    'Dark>6,5',
    'Steam>1,3',
    'Light>3,4',
    'Light>4,4',
    'Light>5,4',
    'Light>6,4',
    'Light>7,4',
    'Light>8,4',
    'Dark>7,5',
    'pin',
    'Dark>8,5',
    'Steam>2,3',
    'Steam>3,3',
    'Steam>4,3',
    'Steam>5,3',
    'Steam>6,3',
    'Steam>7,3',
    'Steam>8,3',
  ],
  'two_suns': [
    'Dark>0,4',
    'Steam>2,4',
    'Light>1,4',
    'Light>1,3',
    'Dark>1,4',
    'Steam>2,5',
    'Dark>2,4',
    'Steam>2,6',
    'pipe',
    'Steam>9,6',
    'Steam>9,5',
    'Steam>9,4',
    'Steam>9,3',
    'Dark>3,4',
    'Dark>4,4',
    'Dark>5,4',
    'Dark>6,4',
    'Light>2,3',
    'Dark>7,4',
    'pin',
    'Light>3,3',
    'Light>4,3',
    'Light>5,3',
    'Light>6,3',
    'Light>7,3',
    'Light>8,3',
    'Dark>8,4',
  ],
  'two_gaps': [
    'Light>2,1',
    'Light>3,1',
    'Light>3,2',
    'Dark>2,0',
    'Dark>3,0',
    'Dark>3,1',
    'Steam>1,0',
    'Steam>2,0',
    'Steam>2,1',
    'Steam>2,2',
    'Light>4,2',
    'Light>5,2',
    'Light>6,2',
    'Light>7,2',
    'Light>8,2',
    'Light>8,3',
    'Dark>3,2',
    'Dark>4,2',
    'Dark>5,2',
    'Dark>6,2',
    'Dark>7,2',
    'Dark>7,3',
    'Steam>2,1',
    'veil',
    'Steam>3,1',
    'Steam>3,0',
    'Steam>4,0',
    'Steam>5,0',
    'Steam>6,0',
    'Steam>6,1',
    'Steam>7,1',
    'Light>8,4',
    'Light>8,5',
    'Light>8,6',
    'Light>8,7',
    'Dark>7,4',
    'Dark>7,5',
    'Dark>7,6',
    'Steam>7,2',
    'Steam>7,3',
    'pin',
    'Dark>7,7',
    'Dark>6,7',
    'Steam>7,4',
    'Steam>7,5',
    'Steam>7,6',
    'Steam>7,7',
  ],
  'sunless_reliquary': [
    'Dark>0,3',
    'Light>0,2',
    'Dark>1,3',
    'Light>0,3',
    'Light>0,4',
    'Light>0,5',
    'Light>0,6',
    'Dark>2,3',
    'crank',
    'crank',
    'Dark>3,3',
    'Dark>4,3',
    'Dark>5,3',
  ],
  'door_of_shadow': [
    'Steam>2,3',
    'Light>1,6',
    'Light>0,6',
    'crank',
    'crank',
    'crank',
    'Dark>2,4',
    'Dark>3,4',
    'pin',
    'Light>1,6',
    'Light>2,6',
    'Light>2,5',
    'Light>2,4',
    'Dark>4,4',
    'Light>3,4',
    'Dark>5,4',
    'Light>4,4',
    'Light>4,5',
    'Light>5,5',
    'Light>6,5',
    'Light>7,5',
    'Light>8,5',
    'Light>9,5',
    'Dark>6,4',
    'Dark>7,4',
    'Dark>8,4',
    'Dark>9,4',
    'Steam>3,3',
    'Steam>4,3',
    'Steam>5,3',
    'Steam>6,3',
    'Steam>7,3',
    'Steam>8,3',
    'Steam>9,3',
  ],
};

ShadowState _replay(ShadowRoomDef d, List<String> plan) {
  var s = ShadowState.start(d);
  for (final m in plan) {
    final next = shadowMoves(d, s).where((e) => e.$1 == m);
    expect(next, isNotEmpty, reason: '${d.id}: "$m" is not a legal move here');
    s = next.first.$2;
  }
  return s;
}

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

PlanetDungeonGame _game({int stars = 0, void Function(String)? onCloud}) {
  final party = [
    _member(0, 'Light', 'horn'),
    _member(1, 'Dark', 'wing'),
    _member(2, 'Steam', 'pip'),
  ];
  final g = PlanetDungeonGame(
    element: 'Light',
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onCloudDiscovered: onCloud,
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.currentRoomId = g.layout.entranceRoomId;
  for (final m in party) {
    final c = DungeonCreature(member: m)
      ..position = g.layout.entranceSpawn
      ..lastSafe = g.layout.entranceSpawn;
    g.creatures.add(c);
    final st = deriveCosmicSurvivalCompanionStats(member: m);
    g.combatCompanions.add(
      CosmicSurvivalCompanion(
        member: m,
        slotIndex: m.slotIndex,
        position: c.position,
        anchor: c.position,
        maxHp: st.maxHp,
        currentHp: st.maxHp,
        physAtk: st.physAtk,
        elemAtk: st.elemAtk,
        abilityAtk: st.elemAtk,
        physDef: st.physDef,
        elemDef: st.elemDef,
        cooldownReduction: st.cooldownReduction,
        critChance: st.critChance,
        attackRange: st.attackRange,
        specialAbilityRange: st.specialAbilityRange,
        tethered: false,
        invincibleTimer: 0,
      ),
    );
  }
  return g;
}

final DungeonLayout _layout = kPlanetDungeonLayouts['Light']!;

/// Walk the party through the door from [from] to [to].
void _enter(PlanetDungeonGame g, String from, String to) {
  g.currentRoomId = from;
  g.passThroughDoor(
    _layout.rooms[from]!.doors.firstWhere((d) => d.targetRoomId == to),
  );
}

/// The party in Solarin's arena, the fight begun and Solarin settled.
PlanetDungeonGame _arena() {
  final g = _game()..entryDoorRevealed = true;
  g.starMask = 0x3;
  g.conduitEnergy['A'] = double.infinity;
  g.conduitEnergy['B'] = double.infinity;
  _enter(g, 'eclipse_walk', 'solarin_orbit');
  g.guardianAwake = true;
  g.setActive(0);
  for (var i = 0; i < 30 || (i < 900 && g.guardianArriving); i++) {
    g.update(1 / 60);
  }
  g.archive
    ..swingNext = 99
    ..flareNext = 99;
  // Solarin's body shoots as well; these tests read only its light and flare.
  for (final c in g.combatCompanions) {
    c.invincibleTimer = 999;
  }
  return g;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the rule', () {
    test('glass holds only in shadow, and never under what casts it', () {
      final d = kRoomOwnShadow;
      var s = ShadowState.start(d);
      // Light beside the starlight: its shadow fans across the glass.
      s = s.moved('Light', sq(1, 3));
      final glass = sq(3, 3);
      expect(shadowHolds(d, s, glass.x, glass.y, 'Dark'), isTrue);
      expect(
        shadowHolds(d, s, glass.x, glass.y, 'Light'),
        isFalse,
        reason: 'nothing stands on its own shadow',
      );
    });

    test('glass no starlight reaches is nothing, not floor', () {
      final d = kRoomTwoGaps;
      for (var y = 0; y < d.rows; y++) {
        for (var x = 0; x < d.cols; x++) {
          if (!d.isGlass(x, y)) continue;
          final lamps = shadowLamps(d, ShadowState.start(d));
          expect(
            lamps.any((l) => shadowLights(d, l, x, y)),
            isTrue,
            reason:
                'glass ($x,$y) is lit by no starlight: it would be free floor',
          );
        }
      }
    });
  });

  group('every room is solvable, and its tool is necessary', () {
    for (final e in _plans.entries) {
      test('${e.key}: the shortest plan replays and solves', () {
        final d = kShadowRooms[e.key]!;
        expect(shadowSolved(d, _replay(d, e.value)), isTrue);
      });
    }

    for (final id in ['own_shadow', 'two_suns', 'two_gaps']) {
      test('$id cannot be crossed without the pin', () {
        final d = kShadowRooms[id]!;
        final s0 = ShadowState.start(d).copyWith(pins: 0);
        expect(solveShadowRoom(d, from: s0).solvable, isFalse);
      });
    }

    test('THE ECLIPSE needs the pin, the veil and the crank, every one', () {
      final d = kRoomEclipse;
      expect(
        solveShadowRoom(
          d,
          from: ShadowState.start(d).copyWith(pins: 0),
        ).solvable,
        isFalse,
        reason: 'without the pin',
      );
      expect(
        solveShadowRoom(d, allow: (m) => m != 'veil').solvable,
        isFalse,
        reason: 'without the veil',
      );
      expect(
        solveShadowRoom(d, allow: (m) => m != 'crank').solvable,
        isFalse,
        reason: 'without the crank',
      );
    });

    test('THE ECLIPSE is long: no plan shorter than fifty moves', () {
      final r = solveShadowRoom(kRoomEclipse, limit: 900000);
      expect(r.solvable, isTrue);
      expect(r.plan.length, 50);
    });

    test('two_gaps cannot be crossed without the veil', () {
      final r = solveShadowRoom(
        kRoomTwoGaps,
        allow: (m) => m != 'veil',
        limit: 900000,
      );
      expect(r.solvable, isFalse);
      expect(r.states, lessThan(900000), reason: 'the search must finish');
    });

    test('THE TRAP: in two_gaps, pinning the first gap is a dead end', () {
      final d = kRoomTwoGaps;
      var s = ShadowState.start(d);
      // Light holds the first gap beside its starlight; Dark steps out onto
      // the shadow and pins it — the Room I habit.
      for (final m in [
        'Light>1,2',
        'Dark>2,0',
        'Dark>3,0',
        'Dark>3,1',
        'Dark>3,2',
        'Dark>4,2',
      ]) {
        final n = shadowMoves(d, s).firstWhere((e) => e.$1 == m);
        s = n.$2;
      }
      final cells = shadowPinCells(d, s);
      expect(cells, isNotNull);
      s = s.copyWith(pinned: {...cells!}, pins: 0);
      expect(solveShadowRoom(d, from: s, limit: 900000).solvable, isFalse);
    });

    test('the pipe is one way and spends itself', () {
      final d = kRoomTwoSuns;
      var s = ShadowState.start(d).moved('Steam', sq(2, 6));
      final up = shadowMoves(d, s).where((e) => e.$1 == 'pipe');
      expect(up, hasLength(1));
      s = up.first.$2;
      expect(s.pos['Steam'], sq(8, 6));
      expect(shadowMoves(d, s).where((e) => e.$1 == 'pipe'), isEmpty);
      s = s.moved('Steam', sq(2, 6));
      expect(
        shadowMoves(d, s).where((e) => e.$1 == 'pipe'),
        isEmpty,
        reason: 'once only',
      );
    });

    test('the Door of Shadow opens only to the monolith\'s shadow', () {
      final d = kRoomDoorOfShadow;
      // With the starlight where it starts, a body's shadow can bridge the
      // glass, but a pin of it never cuts the blank wall.
      var s = ShadowState.start(d);
      for (var y = 0; y < d.rows; y++) {
        for (var x = 0; x < d.cols; x++) {
          if (!d.isGlass(x, y)) continue;
          final t = s.moved('Dark', sq(x, y));
          final cells = shadowPinCells(d, t) ?? const <int>[];
          final monolith = shadowCasters(d, t).any((c) => c.id.startsWith('M'));
          expect(monolith, isTrue);
          for (final k in cells) {
            final q = sqOf(k);
            if (d.at(q.x, q.y) != 'B') continue;
            // A wall square only ever comes from the monolith's shadow.
            final lamps = shadowLamps(d, t);
            final byMonolith = lamps.any(
              (l) => d.fixedCasters.any(
                (f) =>
                    f.id.startsWith('M') &&
                    shadowCast(l, f.cx, f.cy, f.r, q.x, q.y),
              ),
            );
            expect(byMonolith, isTrue);
          }
        }
      }
    });
  });

  group('the key', () {
    test('exactly one stud lays the shadow in the lock', () {
      var fits = 0;
      for (final x in kKeyStudX) {
        for (final y in kKeyStudY) {
          if (keyFits(x, y)) fits++;
        }
      }
      expect(fits, 1);
      // And at that stud the key's shadow is magnified four times.
      expect(keyMagnify(kKeyAnswerY), closeTo(4, 1e-9));
    });
  });

  group('played', () {
    test('the entry rite: only Light wakes the hall\'s star', () {
      final g = _game();
      final dark = g.creatures[1], light = g.creatures[0];
      g.setActive(1);
      dark.position = kHallKindle;
      g.activateAbility();
      expect(g.entryDoorRevealed, isFalse);
      g.setActive(0);
      light.position = kHallKindle;
      g.activateAbility();
      expect(g.entryDoorRevealed, isTrue);
    });

    test('a grid room lays each body on its own square at the door', () {
      final g = _game()..entryDoorRevealed = true;
      _enter(g, 'light_hall', 'own_shadow');
      for (var i = 0; i < 3; i++) {
        final n = kShadowNames[i];
        final at = kRoomOwnShadow.start[n]!;
        expect(g.creatures[i].position, shadowCentre(at.x, at.y));
      }
    });

    test('a step onto bare light is refused, and says only what is wrong', () {
      final g = _game()..entryDoorRevealed = true;
      _enter(g, 'light_hall', 'own_shadow');
      g.setActive(1);
      // Dark up at the top of the ledge: the glass east of it is lit by the
      // starlight and shadowed by nobody.
      final dark = g.creatures[1]..position = shadowCentre(2, 0);
      final before = dark.position;
      for (var i = 0; i < 40; i++) {
        g.joystickDirection = const Offset(1, 0);
        g.update(1 / 60);
      }
      g.joystickDirection = Offset.zero;
      expect(
        shadowSquareAt(dark.position, 11, 7).x,
        2,
        reason: 'Dark must not have walked onto bare light',
      );
      expect(dark.position.dy, closeTo(before.dy, 1));
    });

    test('Dark pins the shadow it stands in, and the stone holds anyone', () {
      final g = _game()..entryDoorRevealed = true;
      _enter(g, 'light_hall', 'own_shadow');
      final d = kRoomOwnShadow;
      // Light beside the starlight; Dark out on its shadow.
      g.creatures[0].position = shadowCentre(1, 3);
      g.creatures[1].position = shadowCentre(3, 3);
      g.setActive(1);
      g.update(1 / 60);
      g.activateAbility();
      final s = g.archive.state(d.id);
      expect(s.pins, 0);
      expect(s.pinned.contains(sqKey(4, 3)), isTrue);
      // Now Light's own shadow is stone, and Light may walk it.
      expect(
        shadowCanStand(d, s.moved('Light', sq(1, 3)), 4, 3, 'Light'),
        isTrue,
      );
    });

    test('solving I and II banks the Shadow Star and sets two spans', () {
      final g = _game()..entryDoorRevealed = true;
      g.archive.solved.add('key_room');
      _enter(g, 'light_hall', 'own_shadow');
      // All three on the gold stone.
      g.creatures[0].position = shadowCentre(8, 1);
      g.creatures[1].position = shadowCentre(9, 1);
      g.creatures[2].position = shadowCentre(10, 1);
      g.update(1 / 60);
      expect(g.archive.solved, contains('own_shadow'));
      expect(g.hasStar(0), isTrue);
      _enter(g, 'own_shadow', 'light_hall');
      g.update(1 / 60);
      expect(g.archive.spanSet.keys, containsAll(['own_shadow', 'key_room']));
    });

    test('the hall\'s wells hold only their spans', () {
      final g = _game()..entryDoorRevealed = true;
      g.setActive(1);
      final dark = g.creatures[1]..position = shadowCentre(2, 3);
      for (var i = 0; i < 60; i++) {
        g.joystickDirection = const Offset(1, 0);
        g.update(1 / 60);
      }
      expect(shadowSquareAt(dark.position, kHallCols, kHallRows).x, 2);
      // Solve I and the span holds.
      g.archive.solved.add('own_shadow');
      for (var i = 0; i < 40; i++) {
        g.joystickDirection = const Offset(1, 0);
        g.update(1 / 60);
      }
      g.joystickDirection = Offset.zero;
      expect(shadowSquareAt(dark.position, kHallCols, kHallRows).x, 3);
    });

    test('THE LOST MAXIM: Light walks on light; nobody else does', () {
      final clouds = <String>[];
      final g = _game(onCloud: clouds.add)..entryDoorRevealed = true;
      g.setActive(1);
      final dark = g.creatures[1]..position = shadowCentre(7, 4);
      for (var i = 0; i < 40; i++) {
        g.joystickDirection = const Offset(1, 0);
        g.update(1 / 60);
      }
      expect(shadowSquareAt(dark.position, kHallCols, kHallRows).x, 7);
      dark.position = shadowCentre(6, 4);
      g.setActive(0);
      final light = g.creatures[0]..position = shadowCentre(7, 4);
      for (var i = 0; i < 40; i++) {
        g.joystickDirection = const Offset(1, 0);
        g.update(1 / 60);
      }
      g.joystickDirection = Offset.zero;
      expect(shadowSquareAt(light.position, kHallCols, kHallRows), kHallSun);
      for (var i = 0; i < 400; i++) {
        g.update(1 / 60);
      }
      expect(clouds, contains(kLightEggId));
    });

    test('with both stars the Door of Shadow opens, and its rite wakes '
        'Solarin and opens the stair', () {
      final g = _game()
        ..entryDoorRevealed = true
        ..starMask = 0x3; // both stars banked this run
      final hall = _layout.rooms['light_hall']!;
      final toRite = hall.doors.firstWhere(
        (d) => d.targetRoomId == 'door_of_shadow',
      );
      expect(g.isDoorLocked(hall, toRite), isFalse);
      _enter(g, 'light_hall', 'door_of_shadow');
      // The rite leads on to the Eclipse, and the Eclipse down to Solarin.
      final eclipse = _layout.rooms['eclipse_walk']!;
      final toArena = eclipse.doors.firstWhere(
        (d) => d.targetRoomId == 'solarin_orbit',
      );
      expect(
        g.isDoorLocked(eclipse, toArena),
        isTrue,
        reason: 'before the rite',
      );
      // All three through the shadow's doorway, onto the stair's landing.
      final d = kRoomDoorOfShadow;
      final s = g.archive.state(d.id);
      g.archive.rooms[d.id] = s.copyWith(
        pinned: {
          for (var y = 0; y < d.rows; y++)
            for (var x = 0; x < d.cols; x++)
              if (d.at(x, y) == '~' || d.at(x, y) == 'B') sqKey(x, y),
        },
      );
      g.creatures[0].position = shadowCentre(9, 1);
      g.creatures[1].position = shadowCentre(10, 4);
      g.creatures[2].position = shadowCentre(9, 5);
      for (var i = 0; i < 5; i++) {
        g.update(1 / 60);
      }
      expect(g.archive.solved, contains('door_of_shadow'));
      expect(g.guardianAwake, isTrue);
      expect(
        g.isDoorLocked(eclipse, toArena),
        isFalse,
        reason: 'after the rite',
      );
    });

    test('SOLARIN: three planned blows, each swinging it round its orbit', () {
      final g = _game()..entryDoorRevealed = true;
      g.starMask = 0x3;
      g.conduitEnergy['A'] = double.infinity;
      g.conduitEnergy['B'] = double.infinity;
      _enter(g, 'eclipse_walk', 'solarin_orbit');
      g.setActive(0);
      for (var i = 0; i < 30 || (i < 900 && g.guardianArriving); i++) {
        g.update(1 / 60);
      }
      expect(g.guardianStrikesNeeded, 3);
      // Behind the east pillar, two squares off: the lull is open.
      g.creatures[0].position = shadowCentre(7, 4);
      g.update(1 / 60);
      expect(g.guardianVulnerable, isTrue);
      g.activateAbility();
      expect(g.archive.state('solarin_orbit').orbit, 1, reason: 'it swung on');
      expect(g.guardianHpFractionForTest, closeTo(2 / 3, .02));
    });

    test('SOLARIN swings on by itself, and shows where first', () {
      final g = _arena();
      final s0 = g.archive.state('solarin_orbit').orbit;
      g.archive.swingNext = kSolarinWarn + .05;
      g.update(1 / 60);
      g.update(0.1);
      expect(g.archive.swingNext, lessThan(kSolarinWarn), reason: 'warning');
      expect(g.archive.state('solarin_orbit').orbit, s0, reason: 'not yet');
      for (var i = 0; i < 180; i++) {
        g.update(1 / 60);
      }
      expect(g.archive.state('solarin_orbit').orbit, (s0 + 1) % 3);
      // Mid-swing its light is on the way, not at either end: the shadows
      // sweep.
      final sun = g.archive.state('solarin_orbit').sun;
      expect(sun, isNotNull, reason: 'still swinging');
      final end = kRoomSolarin.orbit![(s0 + 1) % 3];
      expect((sun!.x - end.x).abs() + (sun.y - end.y).abs(), greaterThan(.3));
      for (var i = 0; i < 60 * 3; i++) {
        g.update(1 / 60);
      }
      expect(g.archive.state('solarin_orbit').sun, isNull, reason: 'settled');
    });

    test('SOLARIN fights in a debug rematch, its star already banked', () {
      final g = _game()..entryDoorRevealed = true;
      g.starMask = 0x7;
      g.debugSpawnGuardian();
      for (var i = 0; i < 900 && g.guardianArriving; i++) {
        g.update(1 / 60);
      }
      expect(g.guardianArriving, isFalse);
      final o = g.archive.state('solarin_orbit').orbit;
      for (var i = 0; i < 60 * 11; i++) {
        g.update(1 / 60);
      }
      expect(g.archive.state('solarin_orbit').orbit, isNot(o), reason: 'moved');
    });

    test('SOLARIN\'s glass is all floor: its light burns, it never drops', () {
      final g = _arena();
      final light = g.creatures[0];
      // (8,1) is bare glass in its light: walkable, and it burns.
      light.position = shadowCentre(8, 1);
      final hp = light.hp;
      for (var i = 0; i < 30; i++) {
        g.update(1 / 60);
      }
      final s = g.archive.state('solarin_orbit');
      expect(s.pos['Light'], sq(8, 1), reason: 'nothing fell');
      expect(light.hp, lessThan(hp - 10), reason: 'massive: ${light.hp}');
      // The east pillar's shadow down row 4 is safe; so is the ledge.
      for (final at in [sq(3, 4), sq(1, 3)]) {
        light.position = shadowCentre(at.x, at.y);
        g.update(1 / 60);
        final h = light.hp;
        for (var i = 0; i < 30; i++) {
          g.update(1 / 60);
        }
        expect(light.hp, h, reason: 'safe at $at');
      }
    });

    test('SOLARIN is struck only from its shadow: near in its light, no', () {
      final g = _arena();
      // (8,3): one square off, but in its light.
      g.creatures[0].position = shadowCentre(8, 3);
      g.update(1 / 60);
      expect(g.guardianVulnerable, isFalse);
      g.activateAbility();
      expect(g.guardianHpFractionForTest, closeTo(1, .02));
    });

    test('SOLARIN\'s flare lands on the square it marked', () {
      final g = _arena();
      final light = g.creatures[0];
      light.position = shadowCentre(3, 4);
      g.archive.flareNext = 0;
      g.update(1 / 60);
      expect(g.archive.flareSq, sq(3, 4));
      final hp = light.hp;
      for (var i = 0; i < 80; i++) {
        g.update(1 / 60);
      }
      expect(g.archive.flareSq, isNull);
      expect(light.hp, lessThan(hp - 15), reason: 'stood on the mark');
      // Step off the mark and it misses.
      g.archive.flareNext = 0;
      g.update(1 / 60);
      light.position = shadowCentre(4, 4);
      final hp2 = light.hp;
      for (var i = 0; i < 80; i++) {
        g.update(1 / 60);
      }
      expect(light.hp, hp2);
    });

    test(
      'Solarin\'s lull is a place: two squares off it, on floor that holds',
      () {
        final g = _game(stars: 0x3)..entryDoorRevealed = true;
        g.archive.solved.add('door_of_shadow');
        g.conduitEnergy['A'] = double.infinity;
        g.conduitEnergy['B'] = double.infinity;
        _enter(g, 'eclipse_walk', 'solarin_orbit');
        g.guardianAwake = true;
        g.setActive(0);
        // Let it come down and settle.
        for (var i = 0; i < 30 || (i < 900 && g.guardianArriving); i++) {
          g.update(1 / 60);
        }
        expect(g.guardianArriving, isFalse);
        g.creatures[0].position = shadowCentre(1, 3);
        g.update(1 / 60);
        expect(g.guardianVulnerable, isFalse, reason: 'on the ledge, far off');
        // Solarin starts east at (9,4); the pillar at (8,4) throws its shadow
        // west, and (7,4) is two squares off, on held glass.
        g.creatures[0].position = shadowCentre(7, 4);
        g.update(1 / 60);
        expect(g.guardianVulnerable, isTrue);
      },
    );
  });
}
