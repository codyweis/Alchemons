import 'dart:async';
import 'dart:convert';

import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/nav_emblems.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  // BottomNav starts the dock's preload and builds the dock in the same
  // frame. Flame's cache lists a sheet from the moment its load starts, but
  // will not hand it over until it ends — reading it then threw, and the whole
  // home screen went white.
  testWidgets('the dock builds while its sheets are still loading', (
    tester,
  ) async {
    late CreatureCatalog catalog;
    await tester.runAsync(() async {
      final raw = await rootBundle.loadString(
        'assets/data/alchemons_creatures.json',
      );
      catalog = CreatureCatalog.fromList([
        for (final j in (jsonDecode(raw) as Map<String, dynamic>)['creatures']
            as List<dynamic>)
          Creature.fromJson(j as Map<String, dynamic>),
      ]);
    });

    unawaited(precacheNavLets(catalog, FactionId.volcanic));
    await tester.pumpWidget(
      Provider<CreatureCatalog>.value(
        value: catalog,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              for (final kind in NavEmblemKind.values)
                NavEmblem(
                  kind: kind,
                  faction: FactionId.volcanic,
                  size: 55,
                  animate: kind == NavEmblemKind.home,
                ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
