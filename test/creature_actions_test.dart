import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:alchemons/widgets/creature_actions.dart';
import 'package:alchemons/widgets/fx/albino_look.dart';
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

  test('every attack species has its ten-frame sheet beside its idle sheet', () {
    // All eight families: Horns, Wings, Pips, Lets, Manes, Masks, Kin, Mystics.
    expect(kFireSpecies.map((id) => id.substring(0, 3)).toSet(), {
      'HOR', 'WNG', 'PIP', 'LET', 'MAN', 'MSK', 'KIN', 'MYS', //
    });
    for (final id in kFireSpecies) {
      final c = creatures.firstWhere((c) => c['id'] == id) as Map;
      final idleFrame = ((c['spriteData'] as Map)['frameWidth'] as num)
          .toDouble();
      final def = actionSheetFor(
        idleOf(id),
        CreatureAction.fire,
        idleFrame: idleFrame,
      );
      expect(def, isNotNull, reason: id);
      expect(def!.frames, 10, reason: id);
      expect(def.stepTimes.length, def.frames, reason: id);
      final file = File('assets/images/${def.path}');
      expect(file.existsSync(), isTrue, reason: def.path);
      // A PNG's size is in its header: four columns of square frames, three
      // rows (the last two cells empty).
      final header = ByteData.sublistView(file.readAsBytesSync(), 16, 24);
      expect(header.getUint32(0), def.frameSize * def.cols, reason: def.path);
      expect(header.getUint32(4), def.frameSize * 3, reason: def.path);
    }
  });

  test('every wag species has its sheet beside its idle sheet', () {
    // Every Mane, Horn, Wing and Pip: its tail wag (or, with no tail to
    // wag, its shimmy).
    expect(kWagSpecies.where((s) => s.startsWith('MAN')), hasLength(18));
    expect(kWagSpecies.where((s) => s.startsWith('HOR')), hasLength(17));
    expect(kWagSpecies.where((s) => s.startsWith('WNG')), hasLength(17));
    expect(kWagSpecies.where((s) => s.startsWith('PIP')), hasLength(17));
    expect(kWagSpecies, hasLength(69));
    for (final id in kWagSpecies) {
      final def = actionSheetFor(idleOf(id), CreatureAction.wag);
      expect(def, isNotNull, reason: id);
      expect(
        File('assets/images/${def!.path}').existsSync(),
        isTrue,
        reason: def.path,
      );
    }
  });

  test('the wag: 16 frames beside the idle, played once, about a second', () {
    expect(kWagSpecies, contains('MAN11'));
    final idle = idleOf('MAN11');
    final def = actionSheetFor(idle, CreatureAction.wag, idleFrame: 1200)!;
    expect(def.path, idle.replaceAll('_spritesheet.png', '_wag.png'));
    expect(def.frames, 16);
    expect(def.cols, 4);
    expect(def.loop, isFalse);
    // A 1200 px species' actions are drawn at half its idle's size.
    expect(def.frameSize, 600);
    expect(def.stepTimes.length, def.frames);
    expect(def.stepTimes.reduce((a, b) => a + b), closeTo(1.0, 0.01));
    // Its albino wears red eyes through it, as through a hop.
    expect(albinoEyesPath(def.path), endsWith('_wag_albino_eyes.png'));
    // A species without a wag sheet has none.
    expect(actionSheetFor(idleOf('LET01'), CreatureAction.wag), isNull);
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
