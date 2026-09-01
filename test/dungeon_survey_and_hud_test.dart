// Three playtest fixes that share one theme: the HUD getting out of the way.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _m(String element, String family) => CosmicPartyMember(
  instanceId: '$element$family',
  baseId: 'b',
  displayName: '$element $family',
  imagePath: '',
  element: element,
  family: family,
  level: 10,
  statSpeed: 4,
  statIntelligence: 4,
  statStrength: 4,
  statBeauty: 4,
  slotIndex: -1,
  staminaBars: 9,
  staminaMax: 9,
);

PlanetDungeonGame _game(String element, {String? room}) {
  final els = kCosmicPlanetEntry[element]!;
  final fams = kDungeonIdealFamilies[element]!;
  final party = [
    for (var i = 0; i < els.length; i++) _m(els[i], fams[i].toLowerCase()),
  ];
  final g = PlanetDungeonGame(
    element: element,
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.currentRoomId = room ?? g.layout.entranceRoomId;
  final at = g.currentRoom.bounds.center;
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = at
        ..lastSafe = at,
    );
  }
  g.onGameResize(Vector2(390, 844));
  return g;
}

void main() {
  group('the survey is a look, not a mode', () {
    test('it toggles, and moving snaps it home', () {
      final g = _game('Fire');
      expect(g.surveying, isFalse);
      g.toggleSurvey();
      expect(g.surveying, isTrue);
      expect(g.surveyZoom, PlanetDungeonGame.kSurveyZoom);

      // Pushing the stick ends it — on INTENT, so a shove or a gale carrying
      // you does not yank the camera back while you are reading.
      g.joystickDirection = const Offset(1, 0);
      g.update(1 / 60);
      expect(g.surveying, isFalse, reason: 'movement closes the survey');
      expect(g.surveyZoom, 1.0);
    });

    test('standing still keeps it open', () {
      final g = _game('Fire');
      g.toggleSurvey();
      for (var i = 0; i < 120; i++) {
        g.update(1 / 60);
      }
      expect(g.surveying, isTrue, reason: 'nothing moved, so nothing closed it');
    });

    test('worldToScreen follows the zoom', () {
      // The star fly-in reads this, so a survey mid-flight must not fling the
      // star off to a position the camera is no longer using.
      final g = _game('Fire');
      final world = g.currentRoom.bounds.center + const Offset(120, 0);
      final near = g.worldToScreen(world);
      g.toggleSurvey();
      final far = g.worldToScreen(world);
      expect(far, isNot(near));
    });

    test('a pulled-back view can be dragged, and a close one cannot', () {
      // The drag exists because the clamp centres any room small enough to fit
      // the pulled-back viewport, which is most of them — so without the pan
      // the survey was a fixed portrait of wherever the party stood.
      final g = _game('Fire');
      final home = g.worldToScreen(g.currentRoom.bounds.center);

      g.panSurvey(const Offset(-60, 0));
      expect(g.surveyPan, Offset.zero, reason: 'no dragging while closed in');
      expect(g.worldToScreen(g.currentRoom.bounds.center), home);

      g.toggleSurvey();
      final framed = g.worldToScreen(g.currentRoom.bounds.center);
      g.panSurvey(const Offset(-60, 0));
      expect(g.surveyPan, isNot(Offset.zero));
      expect(
        g.worldToScreen(g.currentRoom.bounds.center).dx,
        lessThan(framed.dx),
        reason: 'dragging left carries the room left with the finger',
      );
    });

    test('the drag cannot fling the room off the screen', () {
      final g = _game('Fire')..toggleSurvey();
      for (var i = 0; i < 200; i++) {
        g.panSurvey(const Offset(-90, -90));
      }
      final far = g.surveyPan;
      g.panSurvey(const Offset(-90, -90));
      expect(g.surveyPan, far, reason: 'the slack is bounded, not infinite');
    });

    test('closing in forgets where the survey was looking', () {
      // Otherwise the next survey opens somewhere the player did not leave it,
      // and worse, an ended survey would keep the offset at full zoom.
      final g = _game('Fire')..toggleSurvey();
      g.panSurvey(const Offset(-80, 40));
      expect(g.surveyPan, isNot(Offset.zero));

      g.joystickDirection = const Offset(1, 0);
      g.update(1 / 60);
      expect(g.surveying, isFalse);
      expect(g.surveyPan, Offset.zero);

      g.toggleSurvey();
      expect(g.surveyPan, Offset.zero);
      g.panSurvey(const Offset(-80, 40));
      g.toggleSurvey();
      expect(g.surveyPan, Offset.zero, reason: 'the toggle clears it too');
    });

    test('every dungeon can survey its entrance without leaving the room', () {
      // The camera clamps in world units; dividing by the zoom is what keeps
      // a pulled-back view from framing empty space outside the bounds.
      for (final element in kPlanetDungeonLayouts.keys) {
        final g = _game(element)..toggleSurvey();
        expect(g.surveying, isTrue, reason: element);
        expect(() => g.worldToScreen(g.currentRoom.bounds.center),
            returnsNormally, reason: element);
      }
    });
  });

  group('the action cluster only shows where there is something to do', () {
    test('a room with authored furniture offers action', () {
      // Fire's choir carries the ritual braziers.
      final g = _game('Fire', room: 'choir');
      expect(g.currentRoom.hasVerbs, isTrue);
      expect(g.roomOffersAction, isTrue);
    });

    test('a room you must ACT in offers the action cluster', () {
      // THE BLOCKER THIS EXISTS FOR: the cluster is hidden in rooms with
      // nothing to do, and `hasVerbs` is a hand-kept list of furniture types
      // that missed one. Air's entry rite is a Fire creature acting inside a
      // wind CURRENT, currents were not on the list, so the first room of the
      // Air dungeon showed no buttons and the run could not be started.
      //
      // Any layout that hides its entrance door behind a rite has to be able
      // to perform that rite.
      for (final element in kPlanetDungeonLayouts.keys) {
        final layout = kPlanetDungeonLayouts[element]!;
        if (layout.entranceRevealDoor == null) continue;
        final g = _game(element);
        expect(
          g.roomOffersAction,
          isTrue,
          reason:
              '$element hides its entrance door behind a rite performed in '
              '${g.currentRoomId}, but that room offers no action — the '
              'cluster is hidden and the dungeon cannot be started',
        );
      }
    });

    test('and stops offering it once the rite is done', () {
      // The exemption is for the rite, not for the room: an entrance you have
      // already opened is just a corridor again.
      for (final element in kPlanetDungeonLayouts.keys) {
        final layout = kPlanetDungeonLayouts[element]!;
        if (layout.entranceRevealDoor == null) continue;
        final g = _game(element);
        g.entryDoorRevealed = true;
        expect(g.entryRitePending, isFalse, reason: element);
      }
    });

    test('a current is a verb, wherever it is', () {
      // Fire-in-a-current is Air's recurring interaction, not just its entry.
      kPlanetDungeonLayouts.forEach((element, layout) {
        for (final room in layout.rooms.values) {
          if (room.currents.isEmpty) continue;
          expect(
            room.hasVerbs,
            isTrue,
            reason: '$element/${room.id} carries a current',
          );
        }
      });
    });

    test('geometry alone is not a verb', () {
      // Walls, doors, hazards, gaps and platforms are things you move
      // through. A room holding only those must not show a dead button.
      var checked = 0;
      kPlanetDungeonLayouts.forEach((element, layout) {
        for (final room in layout.rooms.values) {
          if (room.hasVerbs) continue;
          checked++;
          expect(room.guardian, isNull, reason: '$element/${room.id}');
          expect(room.vaultCache, isNull, reason: '$element/${room.id}');
          expect(room.conduits, isEmpty, reason: '$element/${room.id}');
        }
      });
      expect(checked, greaterThan(0),
          reason: 'some rooms really are just corridors');
    });

    test('every guardian room offers action', () {
      for (final entry in kPlanetDungeonLayouts.entries) {
        for (final room in entry.value.rooms.values) {
          if (room.guardian == null) continue;
          expect(room.hasVerbs, isTrue,
              reason: '${entry.key}/${room.id} holds a guardian');
        }
      }
    });
  });
}
