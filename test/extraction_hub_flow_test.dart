import 'package:alchemons/models/harvest_biome.dart';
import 'package:alchemons/widgets/fx/extraction_vessel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'extraction_hub_harness.dart';

// The harvest chamber's verbs on the real screen: the tap boost takes time
// off a running job, a full flask collects and empties, and ending a run
// asks first and then clears it.
void main() {
  setUp(muteNotifications);

  testWidgets('tapping a running flask takes time off its job', (tester) async {
    final h = await HubHarness.pump(tester);
    try {
      await h.select(0);
      expect(
        tester.widget<ExtractionVessel>(find.byType(ExtractionVessel)).mode,
        VesselMode.running,
      );
      final before = h.svc.biome(Biome.volcanic).remaining!;
      final vessel = tester.getCenter(find.byType(ExtractionVessel));
      // Throttled to one boost per quarter second.
      for (var i = 0; i < 3; i++) {
        await tester.tapAt(vessel);
        await h.settle(10);
      }
      final after = h.svc.biome(Biome.volcanic).remaining!;
      final saved = before - after;
      expect(saved, greaterThanOrEqualTo(const Duration(seconds: 14)));
      expect(saved, lessThan(const Duration(seconds: 30)));
      expect(tester.takeException(), isNull);
    } finally {
      await h.dispose();
      unmuteNotifications();
    }
  });

  testWidgets('a full flask collects, pours out and comes back empty', (
    tester,
  ) async {
    final h = await HubHarness.pump(tester);
    try {
      // Full chambers are shown first.
      expect(
        tester.widget<ExtractionVessel>(find.byType(ExtractionVessel)).mode,
        VesselMode.ready,
      );
      // The first: the second is the arrival task's own snack.
      await tester.tap(find.text('COLLECT').first);
      await h.settle(4);
      // Mid-pour it still looks like what it was, not a cold empty flask.
      final pouring = tester.widget<ExtractionVessel>(
        find.byType(ExtractionVessel),
      );
      expect(pouring.mode, VesselMode.ready);
      expect(pouring.creature, isNotNull);
      await h.settle(50);
      final done = tester.widget<ExtractionVessel>(
        find.byType(ExtractionVessel),
      );
      expect(done.mode, VesselMode.empty);
      expect(done.creature, isNull);
      expect(done.level.value, 0);
      expect(h.svc.biome(Biome.verdant).hasActive, isFalse);
      expect(find.text('INSERT ALCHEMON'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await h.dispose();
      unmuteNotifications();
    }
  });

  testWidgets('ending a run asks, then empties the flask', (tester) async {
    final h = await HubHarness.pump(tester);
    try {
      await h.select(0);
      await tester.tap(find.text('END RUN'));
      await h.settle(10);
      expect(find.text('END THIS RUN?'), findsOneWidget);
      await tester.tap(find.text('CANCEL'));
      await h.settle(10);
      expect(h.svc.biome(Biome.volcanic).hasActive, isTrue);

      await tester.tap(find.text('END RUN'));
      await h.settle(10);
      await tester.tap(find.text('END RUN').last);
      await h.settle(60);
      expect(h.svc.biome(Biome.volcanic).hasActive, isFalse);
      expect(
        tester.widget<ExtractionVessel>(find.byType(ExtractionVessel)).mode,
        VesselMode.empty,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await h.dispose();
      unmuteNotifications();
    }
  });

  test('the flask fills with the level, splashes and pours', () {
    final f = ExtractionVesselField()
      ..mode = VesselMode.running
      ..level = 0.6;
    f.layout(const Size.square(300));
    for (var i = 0; i < 120; i++) {
      f.step(1 / 60);
    }
    expect(f.shownLevel, closeTo(0.6, 0.02));
    // The surface stands higher the fuller it is.
    final at60 = f.surfaceBase();
    f.level = 0.2;
    for (var i = 0; i < 120; i++) {
      f.step(1 / 60);
    }
    expect(f.surfaceBase(), greaterThan(at60));
    // Full reads as full whatever the level says, until it pours.
    f.mode = VesselMode.ready;
    for (var i = 0; i < 120; i++) {
      f.step(1 / 60);
    }
    expect(f.shownLevel, closeTo(1, 0.02));
  });
}
