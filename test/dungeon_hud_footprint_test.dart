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
  ).readAsStringSync();

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
        reason: 'regroup, survey, hint, re-lay and the debug reset',
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
    test('is round, the verb is the big seat, and it never swaps', () {
      // 2026-09-24: the planet's verb is the big disc (icon only), and the
      // pad never rearranges when enemies arrive; ATTACK is big only in a
      // room with no verb at all. The old layout (74px weapons, a 54px verb
      // above) put the thing you press most in the smallest spot.
      expect(source, contains('Widget _roundAction('));
      expect(source, contains('const big = 84.0, small = 44.0;'));
      expect(source, contains('primary = utility(big);'));
      expect(source, contains('primary = attack(big);'));
      expect(
        source,
        contains('final fighting = !hasUtility;'),
        reason: 'enemies arriving must not swap the buttons under the thumb',
      );
      expect(
        source.contains('BoxShape.circle'),
        isTrue,
        reason: 'the chassis is a circle, not a rounded box',
      );
    });

    test('the controls live in a tray the room never runs under', () {
      expect(source, contains('Widget _controlTray('));
      expect(
        source,
        contains(
          'bottom: _trayHeight(context),\n              child: GameWidget(game: game)',
        ),
        reason: 'the game is laid out ABOVE the tray, not under it',
      );
    });

    test('the countdown reuses the label slot', () {
      // A badge pinned to a corner would sit on top of the rim now.
      expect(
        source,
        contains('caption: cooldownText ?? (small ? null : label)'),
      );
    });

    test('the glide meter moved onto the utility rim', () {
      // One control showing flight, not a control plus a floating 90x6 bar.
      expect(source, contains('charge: glide ? game.flightFraction : 1.0'));
      expect(
        RegExp(r'width: 90,\s*\n\s*height: 6').hasMatch(source),
        isFalse,
        reason: 'the separate flight bar is retired',
      );
    });

    test('the utility button wears the active creature\'s element', () {
      // The old label was the literal word UTILITY on all seventeen planets.
      expect(source, contains('icon: elementIconFor(element)'));
      expect(
        source,
        contains("element: game.active?.member.element ?? widget.element"),
        reason: 'it must follow the ACTIVE creature, not the planet',
      );
    });
  });

  group('the ring painter', () {
    test('draws with strokes only', () {
      // The HUD repaints on the game tick; a blurred rim would be a filter
      // pass per button per frame, which is the jank this codebase fights.
      final painter = source.substring(
        source.indexOf('class _ActionRingPainter'),
        source.indexOf('const _starPrefsKey'),
      );
      expect(painter.contains('MaskFilter'), isFalse);
    });

    test('repaints when any of its state changes', () {
      final painter = source.substring(
        source.indexOf('class _ActionRingPainter'),
        source.indexOf('const _starPrefsKey'),
      );
      for (final field in [
        'charge',
        'spent',
        'denied',
        'teeth',
        'color',
        'thickness',
      ]) {
        expect(
          painter.contains('old.$field != $field'),
          isTrue,
          reason: 'shouldRepaint ignores $field',
        );
      }
    });
  });

  group('the hint', () {
    test('is a circled question mark, filled when it has an answer', () {
      expect(source, contains('Icons.help_rounded'));
      expect(source, contains('Icons.help_outline_rounded'));
    });

    test('the capsule wears the house chrome, not a soft pill', () {
      // It was the only rounded thing left on a screen of bracketed panels,
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
      expect(capsule, contains('DungeonBracketPainter'));
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
