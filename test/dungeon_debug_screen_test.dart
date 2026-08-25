// The developer's way into all seventeen dungeons.
//
// The value of this screen is that it is COMPLETE and HONEST: every built
// dungeon is listed (a missing one reads as a broken build, not a missing
// row), and what it says about a planet — the trio it will fabricate, the
// stars already banked — matches what the descent actually does. Both are
// easy to break silently by editing a data table, so they are pinned here.

import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/screens/debug/dungeon_debug_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late CreatureCatalog catalog;
  late FactionTheme theme;

  setUpAll(() {
    final raw = File('assets/data/alchemons_creatures.json').readAsStringSync();
    final decoded = jsonDecode(raw);
    final list = (decoded is List ? decoded : decoded['creatures'] as List)
        .map((e) => Creature.fromJson(e as Map<String, dynamic>))
        .toList();
    catalog = CreatureCatalog.fromList(list);
    theme = factionThemeFor(FactionId.volcanic, brightness: Brightness.dark);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Two things fight a naive pump here. The particle background animates
  /// forever, so `pumpAndSettle` never returns — bounded pumps let the
  /// star-state future resolve instead. And a ListView only lays out what
  /// fits, so on a phone-sized surface the later planets genuinely are not
  /// built and every assertion about them is vacuous; the surface is made tall
  /// enough to hold all seventeen rows at once.
  Future<void> settle(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Widget harness() => MultiProvider(
    providers: [
      Provider<CreatureCatalog>.value(value: catalog),
      Provider<FactionTheme>.value(value: theme),
    ],
    child: const MaterialApp(home: DungeonDebugScreen()),
  );

  testWidgets('every built dungeon gets a row, named by its planet', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await settle(tester);

    for (final element in kPlanetDungeonLayouts.keys) {
      final name = (kPlanetDisplayName[element] ?? element).toUpperCase();
      expect(
        find.text(name),
        findsOneWidget,
        reason: '$element is built but has no row — a dungeon you cannot '
            'reach from here reads as a broken build',
      );
    }
  });

  testWidgets('the listed trio is the one the descent will fabricate', (
    tester,
  ) async {
    // The row is a promise about the run. If the label and the fabricator read
    // different tables, the tester plans around a team they will not get.
    await tester.pumpWidget(harness());
    await settle(tester);

    for (final element in kPlanetDungeonLayouts.keys) {
      final entry = kCosmicPlanetEntry[element]!;
      final families = kDungeonIdealFamilies[element]!;
      final expected = [
        for (var i = 0; i < entry.length; i++)
          '${entry[i]}${families[i].toLowerCase()}',
      ].join(' · ');
      expect(find.text(expected), findsOneWidget, reason: element);
    }
  });

  testWidgets('the count in the header matches the rows', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);
    expect(find.text('${kPlanetDungeonLayouts.length} built'), findsOneWidget);
  });

  testWidgets('star pips read the save rather than inventing progress', (
    tester,
  ) async {
    // Star 0 and star 2 banked on Fire — mask 0b101 — and nothing anywhere
    // else. The screen must show exactly that.
    SharedPreferences.setMockInitialValues({
      'cosmic_planet_stars': const PlanetStarState(
        starMasks: {'Fire': 0x5},
      ).serialise(),
    });

    await tester.pumpWidget(harness());
    await settle(tester);

    expect(
      find.byIcon(AppIcons.star_filled),
      findsNWidgets(2),
      reason: 'two banked stars across the whole roster, both on Fire',
    );
  });

  testWidgets('a fresh save shows no stars at all', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);
    expect(find.byIcon(AppIcons.star_filled), findsNothing);
    // Three hollow pips per planet, so the row still reads as "0 of 3".
    expect(
      find.byIcon(AppIcons.star_rounded),
      findsNWidgets(kPlanetDungeonLayouts.length * 3),
    );
  });
}
