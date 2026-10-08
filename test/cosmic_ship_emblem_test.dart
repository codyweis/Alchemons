import 'dart:math' as math;

import 'package:alchemons/widgets/cosmic_ship_emblem.dart';
import 'package:alchemons/widgets/home_emblems.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The way into space from home's ship: it must lift off exactly where the
// icon's ship is, land exactly on the real one, and come home exactly onto
// the icon — any gap shows as the ship jumping.
void main() {
  const screen = Size(390, 844);
  const box = Rect.fromLTWH(300, 170, 75, 75);
  const target = ShipPassageTarget(
    centre: Offset(195, 430),
    scale: 0.72,
    heading: 0.4,
  );

  void samePose(ShipPose a, ShipPose b) {
    expect((a.at - b.at).distance, lessThan(0.01));
    expect((a.scale - b.scale).abs(), lessThan(1e-6));
    final dh = math.atan2(
      math.sin(a.heading - b.heading),
      math.cos(a.heading - b.heading),
    );
    expect(dh.abs(), lessThan(1e-6));
    expect((a.bank - b.bank).abs(), lessThan(1e-6));
  }

  final scene = CosmicShipPassage(target: ValueNotifier(target));
  EmblemStage stage(double open, double land, {bool closing = false}) =>
      EmblemStage(
        box: box,
        screen: screen,
        time: 7.3,
        open: open,
        land: land,
        closing: closing,
      );
  final icon = shipFlight(box.center, box.shortestSide, 7.3);

  test('the ship lifts off where the icon has it', () {
    samePose(scene.poseAt(stage(0, 0)), icon);
  });

  test('the ship lands on the real one', () {
    samePose(scene.poseAt(stage(1, 1)), target.pose);
  });

  test(
    'going back, it lifts off the real ship and comes home onto the icon',
    () {
      samePose(scene.poseAt(stage(1, 1, closing: true)), target.pose);
      samePose(scene.poseAt(stage(0, 0, closing: true)), icon);
    },
  );

  test('the icon flies inside its box, nose along its way', () {
    for (var t = 0.0; t < 9; t += 0.1) {
      final p = shipFlight(box.center, box.shortestSide, t);
      expect((p.at - box.center).dx.abs(), lessThan(box.width * 0.2));
      expect((p.at - box.center).dy.abs(), lessThan(box.height * 0.2));
      final next = shipFlight(box.center, box.shortestSide, t + 0.01);
      final way = next.at - p.at;
      // Forward points the way it is going.
      expect(way.dx * p.forward.dx + way.dy * p.forward.dy, greaterThan(0));
    }
  });

  testWidgets('every hull reads into grains', (tester) async {
    for (final skin in <String?>[
      null,
      'skin_phantom',
      'skin_solar',
      'skin_inferno',
      'skin_crystal',
    ]) {
      final g = (await tester.runAsync(() => ShipGrains.of(skin)))!;
      expect(g.length, greaterThan(600), reason: '$skin');
      expect(g.tail, greaterThan(10), reason: '$skin');
      expect(ShipGrains.now(skin), same(g));
    }
  });
}
