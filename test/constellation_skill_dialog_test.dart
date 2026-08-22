// The old dialog let you press UNLOCK when you could not afford the skill and
// answered with a red SnackBar after the fact, and it never showed your point
// balance at all — so the one number the decision turns on was missing.
//
// These lock in the behaviour, not the styling.

import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:alchemons/screens/upgrade_tree/constellation_skill_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ConstellationSkill _skill({int cost = 3, List<String> prereqs = const []}) {
  return ConstellationSkill(
    id: 'test_skill',
    name: 'Test Skill',
    description: 'A skill used for testing.',
    tree: ConstellationTree.breeder,
    pointsCost: cost,
    prerequisites: prereqs,
    tier: 2,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required ConstellationSkill skill,
  required SkillDialogMode mode,
  required int points,
  Map<String, bool> prereqStates = const {},
  Future<void> Function()? onUnlock,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ConstellationSkillDialog(
          skill: skill,
          mode: mode,
          primary: const Color(0xFF4DA3FF),
          secondary: const Color(0xFFE8DCC8),
          pointsAvailable: points,
          prerequisiteStates: prereqStates,
          onUnlock: onUnlock,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('the cost is shown as a ledger, not a bare number', () {
    testWidgets('an affordable skill shows what you will have left', (
      tester,
    ) async {
      await _pump(
        tester,
        skill: _skill(cost: 3),
        mode: SkillDialogMode.available,
        points: 10,
      );
      expect(find.text('COST'), findsOneWidget);
      expect(find.text('BALANCE'), findsOneWidget);
      expect(find.text('REMAINING'), findsOneWidget);
      expect(find.text('7'), findsOneWidget); // 10 - 3
    });

    testWidgets('an unaffordable skill says how far short you are', (
      tester,
    ) async {
      await _pump(
        tester,
        skill: _skill(cost: 25),
        mode: SkillDialogMode.available,
        points: 4,
      );
      expect(find.text('SHORT BY'), findsOneWidget);
      expect(find.text('21'), findsOneWidget);
      expect(find.text('REMAINING'), findsNothing);
    });

    testWidgets('a locked skill shows the price but not a remainder', (
      tester,
    ) async {
      // "REMAINING" would imply you could buy it; prerequisites are the
      // actual blocker.
      await _pump(
        tester,
        skill: _skill(cost: 3, prereqs: const ['a']),
        mode: SkillDialogMode.locked,
        points: 10,
      );
      expect(find.text('COST'), findsOneWidget);
      expect(find.text('REMAINING'), findsNothing);
      expect(find.text('BALANCE'), findsNothing);
    });
  });

  group('an impossible purchase is never offered', () {
    testWidgets('the unlock button is replaced when you cannot afford it', (
      tester,
    ) async {
      var unlocked = false;
      await _pump(
        tester,
        skill: _skill(cost: 25),
        mode: SkillDialogMode.available,
        points: 4,
        onUnlock: () async => unlocked = true,
      );
      expect(find.text('NEED 21 MORE'), findsOneWidget);
      expect(find.textContaining('ATTUNE'), findsNothing);

      await tester.tap(find.text('NEED 21 MORE'));
      await tester.pump();
      expect(unlocked, isFalse, reason: 'a dead button must stay dead');
    });

    testWidgets('an affordable skill offers the purchase with its price', (
      tester,
    ) async {
      var unlocked = false;
      await _pump(
        tester,
        skill: _skill(cost: 3),
        mode: SkillDialogMode.available,
        points: 10,
        onUnlock: () async => unlocked = true,
      );
      final button = find.textContaining('ATTUNE');
      expect(button, findsOneWidget);
      expect(find.textContaining('3'), findsWidgets);

      await tester.tap(button);
      await tester.pump();
      expect(unlocked, isTrue);
    });

    testWidgets('an owned skill offers nothing to buy', (tester) async {
      await _pump(
        tester,
        skill: _skill(cost: 3),
        mode: SkillDialogMode.owned,
        points: 10,
      );
      expect(find.textContaining('ATTUNE  ·'), findsNothing);
      expect(find.text('CLOSE'), findsOneWidget);
      expect(find.text('ATTUNED'), findsOneWidget);
    });

    testWidgets('a locked skill offers nothing to buy even when rich', (
      tester,
    ) async {
      await _pump(
        tester,
        skill: _skill(cost: 3, prereqs: const ['a']),
        mode: SkillDialogMode.locked,
        points: 999,
      );
      expect(find.textContaining('ATTUNE'), findsNothing);
      expect(find.text('CLOSE'), findsOneWidget);
    });
  });

  group('prerequisites', () {
    testWidgets('are a checklist showing which ones you are missing', (
      tester,
    ) async {
      final real = ConstellationCatalog.allSkills
          .firstWhere((s) => s.prerequisites.isNotEmpty);
      final first = real.prerequisites.first;
      await _pump(
        tester,
        skill: real,
        mode: SkillDialogMode.locked,
        points: 0,
        prereqStates: {first: false},
      );
      expect(find.text('REQUIRES'), findsOneWidget);
      final name = ConstellationCatalog.byId(first)!.name;
      expect(find.text(name), findsOneWidget);
    });

    testWidgets('a met prerequisite is struck through', (tester) async {
      final real = ConstellationCatalog.allSkills
          .firstWhere((s) => s.prerequisites.isNotEmpty);
      final first = real.prerequisites.first;
      await _pump(
        tester,
        skill: real,
        mode: SkillDialogMode.locked,
        points: 0,
        prereqStates: {first: true},
      );
      final name = ConstellationCatalog.byId(first)!.name;
      final text = tester.widget<Text>(find.text(name));
      expect(text.style?.decoration, TextDecoration.lineThrough);
    });
  });

  testWidgets('a double-tap on unlock only spends once', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      skill: _skill(cost: 3),
      mode: SkillDialogMode.available,
      points: 10,
      onUnlock: () async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
    );
    final button = find.textContaining('ATTUNE');
    await tester.tap(button);
    await tester.pump();
    // Mid-flight the button is busy and must not re-enter.
    await tester.tap(find.textContaining('ATTUNING'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 80));
    expect(calls, 1);
  });

  group('layout survives a narrow phone', () {
    // The header row overflowed by 42px the first time this was written, with
    // a long tier name sitting next to the ATTUNED marker.
    for (final mode in SkillDialogMode.values) {
      testWidgets('${mode.name} does not overflow at 320dp', (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final long = ConstellationSkill(
          id: 'long_one',
          name: 'A Deliberately Long Skill Name For Layout',
          description:
              'A description long enough to wrap several times on a narrow '
              'handset, which is where these things break.',
          tree: ConstellationTree.breeder,
          pointsCost: 25,
          prerequisites: const ['breeder_cross_species'],
          tier: 5,
        );

        await _pump(
          tester,
          skill: long,
          mode: mode,
          points: 3,
          prereqStates: const {'breeder_cross_species': false},
          onUnlock: () async {},
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
