import 'dart:convert';
import 'dart:io';

import 'package:alchemons/widgets/creature_actions.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final creatures =
      (jsonDecode(
                File('assets/data/alchemons_creatures.json').readAsStringSync(),
              )
              as Map<String, dynamic>)['creatures']
          as List;
  String idleOf(String id) {
    final c = creatures.firstWhere((c) => c['id'] == id) as Map;
    return (c['image'] as String).replaceAll('.png', '_spritesheet.png');
  }

  test('every hop species has its sheet beside its idle sheet', () {
    expect(kHopSpecies, isNotEmpty);
    for (final id in kHopSpecies) {
      final def = actionSheetFor(idleOf(id), CreatureAction.hop);
      expect(def, isNotNull, reason: id);
      expect(def!.stepTimes.length, def.frames, reason: id);
      expect(
        File('assets/images/${def.path}').existsSync(),
        isTrue,
        reason: def.path,
      );
    }
  });

  test('every sleep species has its looping sheet beside its idle sheet', () {
    expect(kSleepSpecies, isNotEmpty);
    for (final id in kSleepSpecies) {
      final def = actionSheetFor(idleOf(id), CreatureAction.sleep);
      expect(def, isNotNull, reason: id);
      expect(def!.loop, isTrue);
      expect(def.stepTimes.length, def.frames, reason: id);
      expect(
        File('assets/images/${def.path}').existsSync(),
        isTrue,
        reason: def.path,
      );
    }
  });

  test('a species without a hop sheet has no hop', () {
    final without = creatures
        .map((c) => c['id'] as String)
        .where((id) => !kHopSpecies.contains(id))
        .where(
          (id) =>
              (creatures.firstWhere((c) => c['id'] == id) as Map)['spriteData']
                  is Map,
        );
    expect(without, isNotEmpty);
    for (final id in without) {
      expect(actionSheetFor(idleOf(id), CreatureAction.hop), isNull);
    }
  });

  testWidgets('IdleHops asks for a hop soon after it appears, then again', (
    tester,
  ) async {
    var asked = 0;
    CreatureActionController? seen;
    await tester.pumpWidget(
      IdleHops(
        builder: (context, actions) {
          if (seen == null) {
            seen = actions;
            actions.addListener(() {
              if (actions.take() == CreatureAction.hop) asked++;
            });
          }
          return const SizedBox();
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 2400));
    expect(asked, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(asked, 1);
    await tester.pump(const Duration(seconds: 7));
    expect(asked, 2);
    // Gone: its timer goes with it.
    await tester.pumpWidget(const SizedBox());
  });
}
