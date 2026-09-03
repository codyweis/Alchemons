// A wheel you can turn is a wheel you can see.
//
// `_drawTideWheels` was called from ONE room's painter — the tide-works —
// while its own doc comment claimed it served the gallery's bank too. It did
// not: the gallery's three wheels were authored, interactive, and invisible.
// Moving the bank to the drowned court would have inherited exactly the same
// silence, because the court's painter had never been told to ask either.
//
// The fix was structural — the shared temple path draws any bank it finds —
// and this is the test that keeps it structural, because the failure mode is
// invisible by definition and no assertion about game state can catch it.

import 'dart:io';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/games/planet_dungeon/planet_dungeon_game_water.dart',
  ).readAsStringSync();

  test('the wheels are drawn from the shared path, not one room', () {
    final calls = RegExp(
      r'^\s*_drawTideWheels\(canvas, room\);',
      multiLine: true,
    ).allMatches(source);
    expect(
      calls,
      hasLength(1),
      reason:
          'exactly one call site — a second one is a room painter claiming '
          'the job back, and the first room it forgets goes silent',
    );
    // And that one site is in `_renderTemple`, which every room goes through.
    final entry = source.indexOf('void _renderTemple(');
    final next = source.indexOf('switch (room.id) {', entry);
    expect(
      calls.single.start,
      inInclusiveRange(entry, next),
      reason: 'it must run BEFORE the per-room switch, for every room',
    );
  });

  test('every room that carries a bank is a room the painter reaches', () {
    // The data half. If a planet ever grows a bank outside the temple's own
    // render path this says so rather than shipping invisible controls.
    final water = kPlanetDungeonLayouts['Water']!;
    final banked = [
      for (final r in water.rooms.values)
        if (r.tideValves.any((v) => !v.pipOnly)) r.id,
    ];
    expect(
      banked,
      containsAll(<String>['tide_works', 'drowned_court']),
      reason:
          'the tide-works keeps its masters; the court holds the bank '
          'that used to be in the canal gallery',
    );
    expect(
      banked,
      isNot(contains('ghost_gallery')),
      reason: 'the gallery gave its wheels up to the court',
    );
  });

  test('the court can still set every stand', () {
    final court = kPlanetDungeonLayouts['Water']!.rooms['drowned_court']!;
    expect(court.tideValves.map((v) => v.level).toSet(), {0, 1, 2});
  });
}
