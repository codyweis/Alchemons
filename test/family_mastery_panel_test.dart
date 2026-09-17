import 'dart:io';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic_survival/components/family_mastery_panel.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late AlchemonsDatabase db;
  late FamilyMasteryService mastery;

  setUp(() async {
    db = AlchemonsDatabase(NativeDatabase.memory());
    mastery = FamilyMasteryService(db);
    await mastery.load();
  });

  tearDown(() async {
    mastery.dispose();
    await db.close();
  });

  Future<void> pumpPanel(
    WidgetTester tester, {
    int silver = 20000,
    int gold = 20,
  }) async {
    tester.view.physicalSize = const Size(412 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<FamilyMasteryService>.value(
        value: mastery,
        child: MaterialApp(
          home: Scaffold(
            body: FamilyMasteryPanel(
              silverBalance: silver,
              goldBalance: gold,
              onCurrencyChanged: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Purchases hit a real (in-memory) database, which needs real async time.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('opens on Mane with a connected family skill tree', (
    tester,
  ) async {
    await pumpPanel(tester);

    expect(find.text('MANE MASTERY'), findsOneWidget);
    expect(find.text('TWIN FANG'), findsOneWidget);
    expect(find.text('ALL MANES'), findsOneWidget);
    expect(find.byKey(const ValueKey('family-skill-tree')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mastery-node-inspector')),
      findsOneWidget,
    );
    for (final path in FamilyMasteryCatalog.treeFor(
      CreatureFamily.mane,
    ).paths) {
      for (final node in path.nodes) {
        expect(find.byKey(ValueKey('mastery-node-${node.id}')), findsOneWidget);
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('family selector switches to another mastery tree', (
    tester,
  ) async {
    await pumpPanel(tester);

    await tester.tap(find.byKey(const ValueKey('mastery-family-pip')));
    await tester.pumpAndSettle();

    expect(find.text('PIP MASTERY'), findsOneWidget);
    expect(find.text('NEEDLEPOINT'), findsOneWidget);
    expect(find.text('ALL PIPS'), findsOneWidget);
  });

  testWidgets('upgrade needs a second tap to confirm, then buys the node', (
    tester,
  ) async {
    await db.currencyDao.addSilver(5000);
    await pumpPanel(tester, silver: 5000);

    const nodeId = 'mane.assault.honed_pair';
    final button = find.byKey(const ValueKey('unlock-$nodeId'));
    expect(find.text('UPGRADE'), findsOneWidget);

    await tester.tap(button);
    await tester.pump();
    expect(find.text('TAP TO CONFIRM'), findsOneWidget);
    expect(mastery.isNodePurchased(nodeId), isFalse);

    await tester.tap(button);
    await settle(tester);

    expect(mastery.isNodePurchased(nodeId), isTrue);
    expect(mastery.selectedPathForFamily(CreatureFamily.mane), 'mane.assault');
    // The dock advances to the next tier of the same branch.
    expect(find.text('CROSSCUT'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('unlock-mane.assault.crosscut')),
      findsOneWidget,
    );
  });

  testWidgets('an armed upgrade disarms when another node is focused', (
    tester,
  ) async {
    await pumpPanel(tester);

    await tester.tap(
      find.byKey(const ValueKey('unlock-mane.assault.honed_pair')),
    );
    await tester.pump();
    expect(find.text('TAP TO CONFIRM'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('mastery-node-mane.limitless.far_throw')),
    );
    await tester.pump();
    expect(find.text('TAP TO CONFIRM'), findsNothing);
    expect(find.text('UPGRADE'), findsOneWidget);
  });

  testWidgets('unaffordable and locked nodes cannot be bought', (tester) async {
    await pumpPanel(tester, silver: 10);

    expect(find.text('NEED'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('unlock-mane.assault.honed_pair')),
    );
    await tester.pump();
    expect(find.text('TAP TO CONFIRM'), findsNothing);

    // Capstones sit at the bottom of the tree, below the fold.
    final capstone = find.byKey(
      const ValueKey('mastery-node-mane.assault.blade_dance'),
    );
    await tester.ensureVisible(capstone);
    await tester.pumpAndSettle();
    await tester.tap(capstone);
    await tester.pump();
    expect(find.text('REQUIRES PREDATOR STEP'), findsOneWidget);
    expect(find.text('CAPSTONE'), findsOneWidget);
  });

  testWidgets('banner equip switches the family branch', (tester) async {
    await db.currencyDao.addSilver(2000);
    await mastery.purchaseNode(
      family: CreatureFamily.mane,
      nodeId: 'mane.assault.honed_pair',
    );
    await mastery.purchaseNode(
      family: CreatureFamily.mane,
      nodeId: 'mane.limitless.far_throw',
    );
    await pumpPanel(tester);

    expect(find.byKey(const ValueKey('select-mane.assault')), findsNothing);
    // Tap the banner's title, not its EQUIP chip: the whole banner is the
    // button.
    await tester.tap(find.text('LIMITLESS'));
    await settle(tester);

    expect(
      mastery.selectedPathForFamily(CreatureFamily.mane),
      'mane.limitless',
    );
    expect(find.byKey(const ValueKey('select-mane.assault')), findsOneWidget);
  });

  test('base-attack text describes only the basic attack', () {
    // The crown labels this text BASE ATTACK; specials belong elsewhere.
    for (final tree in kFamilyMasteryTrees) {
      expect(
        tree.chassis.toLowerCase(),
        isNot(anyOf(contains('special'), contains('world'))),
        reason: '${tree.family.name}: ${tree.chassis}',
      );
    }
  });

  test('node text is written for players, not for the combat code', () {
    // Internal terms the player never sees anywhere else in the game.
    const jargon = [
      'payload',
      'dual hit',
      'full volley hit',
      'per cast',
      'th cast',
      'basic',
    ];
    for (final tree in kFamilyMasteryTrees) {
      for (final path in tree.paths) {
        for (final text in [
          path.role,
          ...path.nodes.map((n) => n.description),
        ]) {
          for (final term in jargon) {
            expect(
              text.toLowerCase().contains(term),
              isFalse,
              reason: '"$text" uses "$term"',
            );
          }
        }
        for (final node in path.nodes) {
          // The dock shows three lines of description.
          expect(
            node.description.length,
            lessThanOrEqualTo(140),
            reason: node.id,
          );
        }
      }
    }
  });

  test('every mastery node has its own icon', () {
    for (final tree in kFamilyMasteryTrees) {
      for (final path in tree.paths) {
        for (final node in path.nodes) {
          expect(
            kFamilyMasteryNodeIcons.containsKey(node.id),
            isTrue,
            reason: '${node.id} has no icon',
          );
        }
      }
    }
  });

  test('the mastery panel paints without gaussian blur', () {
    // Blur passes are this app's main jank source (see
    // constellation_render_budget_test.dart); the tree fakes its glows with
    // layered translucent strokes instead.
    final source = File(
      'lib/games/cosmic_survival/components/family_mastery_panel.dart',
    ).readAsStringSync();
    expect(source.contains('MaskFilter.blur('), isFalse);
    expect(source.contains('blurRadius:'), isFalse);
    expect(source.contains('ImageFilter.'), isFalse);
  });
}
