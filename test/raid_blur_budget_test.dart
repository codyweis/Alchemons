// A raid frame must ask the GPU for no blur passes at all.
//
// Blur is invisible to frame timings — widget tests never rasterise — so a
// draw-call census is the only thing that catches one creeping back in. The
// dungeon mist used to draw eight large blurred ovals a frame (150x66 at
// blur 12) behind everything, which is what made a raid lag.
//
// This pumps a real GameWidget so onLoad runs and the fx sprites actually
// bake; without that the mist falls back to its blurred path and the count is
// meaningless.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _C implements Canvas {
  int blurs = 0;
  final List<double> sigmas = [];
  @override
  dynamic noSuchMethod(Invocation i) {
    for (final a in i.positionalArguments) {
      if (a is Paint && a.maskFilter != null) {
        blurs++;
        final m = a.maskFilter.toString();
        final d = RegExp(r'([\d.]+)\)').firstMatch(m);
        if (d != null) sigmas.add(double.parse(d.group(1)!));
      }
    }
    if (i.memberName.toString().contains('getSaveCount')) return 1;
    return null;
  }
}

void main() {
  testWidgets('a raid frame asks for no blur passes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    for (final el in ['Air', 'Earth']) {
      final party = [
        for (var i = 0; i < 5; i++)
          CosmicPartyMember(
            instanceId: 'i$i',
            baseId: 'b$i',
            displayName: 'A$i',
            element: el,
            family: const ['wing', 'horn', 'mane', 'pip', 'kin'][i],
            level: 20,
            statSpeed: 3.5,
            statIntelligence: 3.5,
            statStrength: 3.5,
            statBeauty: 3.5,
            slotIndex: i,
            staminaBars: 3,
            staminaMax: 3,
          ),
      ];
      final g = PlanetDungeonGame(
        element: el,
        party: party,
        initialStarMask: 0,
        onStarEarned: (_) {},
        onPlayerDown: () {},
        onChanged: () {},
        raid: const RaidConfig(),
        clearedGuardianCount: 6,
        layoutOverride: buildRaidArenaLayout(el),
      );

      // A real GameWidget so onLoad runs and the fx sprites actually bake.
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: GameWidget(game: g))),
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final c = _C();
      g.render(c as Canvas);
      expect(
        c.blurs,
        0,
        reason: '$el raid asked for ${c.blurs} blur passes '
            '(sigmas ${c.sigmas})',
      );
    }
  });
}
