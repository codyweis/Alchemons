// A finished survival run used to offer only ways to start another one, which
// left the back gesture as the sole exit. These pin QUIT onto the results panel
// and require it to stay on screen on a short landscape phone — the actions sit
// outside the scroll view precisely so a long reward list cannot bury them.

import 'package:alchemons/games/cosmic_survival/components/cosmic_survival_game_over_panel.dart';
import 'package:alchemons/widgets/animations/loot_open_popup.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LootOpeningEntry entry(int i) => LootOpeningEntry(
    icon: AppIcons.inventory_2_rounded,
    name: 'Reward $i',
    label: 'x$i',
    color: const Color(0xFFC4A35A),
  );

  Future<void> pump(
    WidgetTester tester, {
    required Size logical,
    int rewardCount = 0,
  }) async {
    tester.view.physicalSize = Size(logical.width * 2, logical.height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: CosmicSurvivalGameOverPanel(
          wave: 12,
          kills: 340,
          score: 98230,
          time: '07:41',
          rewards: [for (var i = 1; i <= rewardCount; i++) entry(i)],
          onQuit: () {},
          onNewTeam: () {},
          onReplay: () {},
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets('results offer a way out beside the retry actions', (
    tester,
  ) async {
    await pump(tester, logical: const Size(900, 460));

    expect(find.text('QUIT'), findsOneWidget);
    expect(find.text('DEPLOY AGAIN'), findsOneWidget);
    expect(find.text('NEW TEAM'), findsOneWidget);
  });

  testWidgets('QUIT stays on screen at 460 with a long reward list', (
    tester,
  ) async {
    await pump(tester, logical: const Size(900, 460), rewardCount: 10);

    final rect = tester.getRect(find.text('QUIT'));
    expect(rect.bottom, lessThanOrEqualTo(460));
    expect(rect.top, greaterThanOrEqualTo(0));
    // The retry actions share the row, so none of them may be clipped either.
    expect(
      tester.getRect(find.text('DEPLOY AGAIN')).bottom,
      lessThanOrEqualTo(460),
    );
  });

  testWidgets('QUIT is tappable and fires once', (tester) async {
    var quits = 0;
    tester.view.physicalSize = const Size(1560, 760);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: CosmicSurvivalGameOverPanel(
          wave: 3,
          kills: 20,
          score: 100,
          time: '01:00',
          rewards: [entry(1), entry(2)],
          onQuit: () => quits++,
          onNewTeam: () {},
          onReplay: () {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('QUIT'));
    await tester.pump();
    expect(quits, 1);
  });
}
