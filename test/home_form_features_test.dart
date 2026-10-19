// A realm turned into its form shows itself (form_feature_art.dart): a
// site revealed once, events on its own clock, and the residents taking
// part — sheltering from its rain, hopping in its tremors, stopping for
// the shadow, going to its site.

import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/screens/home_biome/home_biome_screen.dart'
    show homeFormSite;
import 'package:alchemons/widgets/fx/cosmetics/form_feature_art.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the events come round on their own clock', () {
    test('each form has its event, never in its first while', () {
      for (final f in kHomeForms) {
        expect(kFormEvents[f], isNotEmpty, reason: f);
        for (final e in kFormEvents[f]!) {
          expect(e.at(0), isNull);
          // Somewhere in its second time round it is under way.
          var seen = false;
          for (var t = e.period; t < e.period * 2.4; t += 0.5) {
            final at = e.at(t);
            if (at != null) {
              seen = true;
              expect(at.$2, inInclusiveRange(0, 1));
            }
          }
          expect(seen, isTrue, reason: '$f comes round');
        }
      }
    });

    test('rain falls in Oceanic showers and Blood\'s red rain', () {
      final shower = kShower.startOf(1) + kShower.duration / 2;
      expect(formRainingAt('Oceanic', shower), isTrue);
      expect(formRainingAt('Oceanic', kShower.startOf(1) - 1), isFalse);
      expect(formRainingAt('Blood', 1, fullMoonNight: true), isTrue);
      expect(formRainingAt('Dark', shower), isFalse);
    });
  });

  group('in the field', () {
    final json =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    Creature species(String id) => Creature.fromJson(
      (json['creatures'] as List).cast<Map<String, dynamic>>().firstWhere(
        (c) => c['id'] == id,
      ),
    );

    Future<SceneGame> mount(
      WidgetTester tester,
      HomeBiomeLayout layout,
      String form,
    ) async {
      tester.view.physicalSize = const Size(915, 412) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final game = SceneGame(scene: layout.scene((_) => false), showcase: true)
        ..fieldHourOverride = 12
        ..lively = true
        ..fieldForm = form
        ..fieldFormDeep = 1
        ..formSite = homeFormSite(layout);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: GameWidget(game: game),
        ),
      );
      for (var i = 0; i < 40 && !game.isLoaded; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
      for (final r in layout.residents) {
        await game.showResident(r.spawnId, species('HOR01'));
      }
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
      return game;
    }

    const home = HomeBiomeLayout(
      realm: HomeRealm.valley,
      pieces: {'valley': []},
      residents: [HomeResident(instanceId: 'a', x: 0.4)],
    );

    testWidgets('its features show once the land has turned, and its '
        'reveal plays once', (tester) async {
      final game = await mount(tester, home, 'Dark');
      expect(game.formFeatures, 1);
      game.revealForm();
      await tester.pump(const Duration(milliseconds: 33));
      // Six seconds and it is all there.
      for (var i = 0; i < 7 * 30; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      game.fieldFormDeep = 0.5;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      expect(game.formFeatures, 0, reason: 'not before it has turned');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('in a tremor the residents hop; in a shower they are wet', (
      tester,
    ) async {
      final earthen = await mount(tester, home, 'Earthen');
      earthen.debugForm(clock: kTremor.startOf(1) + 0.4);
      var hopped = 0.0;
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 33));
        final o = earthen.debugLifeOffset('HOME_a');
        if (o != null && -o.dy > hopped) hopped = -o.dy;
      }
      expect(hopped, greaterThan(1), reason: 'thrown up by the tremor');
      await tester.pumpWidget(const SizedBox());

      final oceanic = await mount(tester, home, 'Oceanic');
      oceanic.debugForm(clock: kShower.startOf(1) + 2);
      await tester.pump(const Duration(milliseconds: 33));
      expect(oceanic.formRaining, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
