// The HUD is chrome, and chrome is not the game.
//
// The top-right column had grown to six full-width pills: a 112px strip down
// the side of the play field, permanently, in a game whose whole readability
// problem is seeing the room. Worse, the box was FIXED at 112 while the labels
// were not, so "RE-LAY ROOM" overflowed its own border by 8.7px and shipped
// that way — a red-and-yellow RenderFlex stripe across a playtest.
//
// The fix was to say the words only where a word is needed. Everything except
// the destructive action is an icon, and this reads the source to keep it
// that way, because nothing at runtime can tell you the HUD got fat again.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/games/planet_dungeon/planet_dungeon_screen.dart',
  ).readAsStringSync().replaceAll('\r\n', '\n');

  group('the top-right controls', () {
    test('only the destructive one spends a label', () {
      // _pillButton is the labelled control. END RUN cannot be a glyph: it is
      // the one press that throws the run away, and it should have to be read.
      final labelled = RegExp(
        r"_pillButton\(\s*'([^']+)'",
      ).allMatches(source).map((m) => m.group(1)).toList();
      expect(labelled, ['END RUN']);
    });

    test('the tools are icons, and there are several of them', () {
      final icons = RegExp(r'_iconButton\(').allMatches(source).length;
      expect(
        icons,
        greaterThanOrEqualTo(5),
        reason: 'regroup, survey, re-lay and the two debug tools',
      );
    });

    test('no control is pinned to a width its label can outgrow', () {
      // The overflow itself. A fixed box plus a variable string is the bug;
      // a minimum plus intrinsic sizing is not.
      expect(
        RegExp(r'width:\s*112').hasMatch(source),
        isFalse,
        reason: 'the fixed 112px pill is what overflowed',
      );
      expect(source, contains('minWidth: 76'));
    });

    test('every icon control says what it is to a screen reader', () {
      // A glyph-only button is mute unless it is labelled deliberately.
      final calls = RegExp(
        r'_iconButton\((?:[^()]|\([^()]*\))*\)',
        dotAll: true,
      ).allMatches(source).map((m) => m.group(0)!).toList();
      // The definition itself plus every call site.
      expect(calls.length, greaterThanOrEqualTo(5));
      for (final call in calls) {
        expect(
          call.contains('semantics:') || call.contains('required String'),
          isTrue,
          reason: 'unlabelled icon button: $call',
        );
      }
    });
  });

  group('Blood\'s RESET ROOM', () {
    test('is the one labelled tool, and only in a captive room, in the '
        'regroup icon\'s place', () {
      // The author, 2026-10-06: "make the reset room bigger in this
      // dungeon". The Blood Rites never say a room has jammed, so the way
      // out has to be found without being pointed at: a big labelled
      // button, standing where the regroup icon stands, only while a
      // captive room is being played.
      expect(source, contains('game.riteResetShown\n'));
      expect(source, contains('? _resetRoomButton('));
      expect(source, contains("'RESET\\nROOM'"));
      expect(RegExp(r'_resetRoomButton\(').allMatches(source).length, 2);
    });
  });

  group('the survey', () {
    test('reads as a magnifier in both directions', () {
      // zoom_out_map/zoom_in_map are the four-arrows glyphs, which read as
      // "fullscreen", not "look closer".
      expect(source, contains('Icons.zoom_out_rounded'));
      expect(source, contains('Icons.zoom_in_rounded'));
      expect(source.contains('zoom_out_map_rounded'), isFalse);
      expect(source.contains('zoom_in_map_rounded'), isFalse);
    });

    test('can be dragged only while it is open', () {
      expect(source, contains('onPanUpdate: (d) => game.panSurvey(d.delta)'));
      expect(
        RegExp(r'game\.surveying\s+\? GestureDetector').hasMatch(source),
        isTrue,
        reason: 'a full-screen drag catcher must not exist while closed in',
      );
    });
  });

  group('the action pad', () {
    String cluster() => source.substring(
      source.indexOf('Widget _actionCluster('),
      source.indexOf('Color _padInk('),
    );

    test('is a square grid: the verb across the top, weapons below', () {
      // 2026-09-26: three glowing round domes became a 2x2 grid of squares
      // in the same bracketed chrome as the top-right controls. The verb
      // spans the top row; ATTACK and SPECIAL share the bottom.
      expect(source, contains('Widget _padTile('));
      expect(source, contains('wide = cell * 2 + gap'));
      expect(
        cluster(),
        contains('top = KeyedSubtree(key: _tutUtilityKey, child: utility());'),
      );
      // A room with no verb at all (a guardian's arena): ATTACK takes the
      // top row, and that never changes mid-fight.
      expect(cluster(), contains('top = attack(wide);'));
    });

    test('it never swaps when enemies arrive', () {
      // Buttons that move under the thumb mid-fight (the author,
      // 2026-09-24). The layout may only depend on whether the room has a
      // verb, never on whether anything is shooting.
      expect(cluster(), contains('final hasUtility = game.utilityAvailable;'));
      expect(cluster().contains('hasCombatTargets'), isFalse);
    });

    test('the controls live in a tray the room never runs under', () {
      expect(source, contains('Widget _controlTray('));
      // (The room's tap catcher may sit between them: the game is still the
      // child of the box that stops at the tray.)
      expect(
        RegExp(
          r'bottom: _trayHeight\(context\),[\s\S]{0,500}?child: GameWidget\(game: game\)',
        ).hasMatch(source),
        isTrue,
        reason: 'the game is laid out ABOVE the tray, not under it',
      );
    });

    test('the countdown reuses the label slot', () {
      // A badge pinned to a corner would sit on top of the tile's brackets.
      expect(
        cluster(),
        contains("cooling ? game.autoCooldownLabel : 'ATTACK'"),
      );
      expect(
        cluster(),
        matches(RegExp(r'cooling\s*\?\s*game\.abilityCooldownLabel')),
      );
    });

    test('the glide meter lives on the utility tile', () {
      // One control showing flight, not a control plus a floating 90x6 bar.
      expect(
        cluster(),
        contains('charge: enabled && glide ? game.flightFraction : null'),
      );
      expect(
        RegExp(r'width: 90,\s*\n\s*height: 6').hasMatch(source),
        isFalse,
        reason: 'the separate flight bar is retired',
      );
    });

    test('the utility button wears the active creature\'s element', () {
      expect(cluster(), contains('Icon(elementIconFor(element)'));
      expect(
        cluster(),
        contains(
          "final element = game.active?.member.element ?? widget.element",
        ),
        reason: 'it must follow the ACTIVE creature, not the planet',
      );
    });

    test('the tiles carry no glow and no blur', () {
      // The HUD repaints on the game tick; a blurred edge is a filter pass
      // per tile per frame, and the glow read as cheap (the author,
      // 2026-09-26).
      final tile = source.substring(
        source.indexOf('Widget _padTile('),
        source.indexOf('Widget _swapRail('),
      );
      expect(tile.contains('MaskFilter'), isFalse);
      expect(tile.contains('boxShadow'), isFalse);
      expect(tile.contains('blurRadius'), isFalse);
    });

    test('the party is a list at full size, never scaled to fit', () {
      // It was a row of portraits the tray shrank to under half size to fit
      // between the stick and the pad.
      expect(source.contains('child: _swapRail(game),\n'), isTrue);
      expect(
        RegExp(r'FittedBox\([^)]*\n[^)]*_swapRail').hasMatch(source),
        isFalse,
      );
    });
  });

  group('the hint', () {
    test('is a circled question mark, filled when it has an answer', () {
      expect(source, contains('Icons.help_rounded'));
      expect(source, contains('Icons.help_outline_rounded'));
    });

    test('is its own round button at the top of the rail, with no glow', () {
      // 36px in a column of look-alike squares was easy to miss; now it is
      // a flat 50px circle, first under END RUN.
      final button = source.substring(
        source.indexOf('Widget _hintButton('),
        source.indexOf('Widget _buildControlsTutorial('),
      );
      expect(button, contains('BoxShape.circle'));
      expect(button.contains('boxShadow'), isFalse);
      expect(button.contains('blurRadius'), isFalse);
      final rail = source.substring(source.indexOf("'END RUN'"));
      expect(
        rail.indexOf('_hintButton('),
        lessThan(rail.indexOf('Icons.restore_rounded')),
        reason: 'the hint is the first tool under END RUN',
      );
    });

    test('the capsule wears the house chrome, not a soft pill', () {
      // It was the only rounded thing left on a screen of framed panels,
      // round glyph buttons and cornered banners — a component from an older
      // build parked over the game.
      final capsule = source.substring(
        source.indexOf('Widget _hintCapsule('),
        source.indexOf('/// PROGRESS READOUT'),
      );
      expect(
        capsule.contains('BorderRadius.circular(20)'),
        isFalse,
        reason: 'the pill is retired',
      );
      expect(capsule, contains('BracketFramePainter'));
    });

    test('the channel is a rule down the edge, not a tint all round', () {
      final capsule = source.substring(
        source.indexOf('Widget _hintCapsule('),
        source.indexOf('/// PROGRESS READOUT'),
      );
      expect(capsule, contains('BorderSide(color: accent, width: 3)'));
      // Every channel still has to be answered, or one of them renders bare.
      for (final ch in ['blocked', 'insight', 'objective', 'ambient']) {
        expect(
          capsule,
          contains('DungeonHintChannel.$ch'),
          reason: '$ch has no styling',
        );
      }
    });
  });
}
