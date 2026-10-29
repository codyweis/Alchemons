import 'dart:io';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic_survival/components/family_mastery_panel.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:alchemons/utils/faction_util.dart';
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

  /// The panel, with [manePoints] more Mane mastery banked first.
  Future<void> pumpPanel(WidgetTester tester, {int manePoints = 1000}) async {
    tester.view.physicalSize = const Size(412 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await mastery.addPoints({CreatureFamily.mane: manePoints});
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FamilyMasteryService>.value(value: mastery),
          // The notice a purchase or an equip raises is tinted from it.
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
        ],
        child: const MaterialApp(home: Scaffold(body: FamilyMasteryPanel())),
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

  String caption(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('mastery-family-caption')))
      .textSpan!
      .toPlainText();

  String balance(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('mastery-points-balance')))
      .textSpan!
      .toPlainText();

  testWidgets('opens on Mane with a connected family skill tree', (
    tester,
  ) async {
    await pumpPanel(tester);

    expect(caption(tester), startsWith('MANE'));
    expect(
      caption(tester),
      endsWith(FamilyMasteryCatalog.treeFor(CreatureFamily.mane).chassis),
    );
    expect(find.text('WAR RHYTHM'), findsOneWidget);
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

    expect(caption(tester), startsWith('PIP'));
    expect(find.text('SCATTERSHOT'), findsOneWidget);
  });

  testWidgets('Mystic\'s two branches line up under their headings', (
    tester,
  ) async {
    await pumpPanel(tester);

    await tester.tap(find.byKey(const ValueKey('mastery-family-mystic')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final paths = FamilyMasteryCatalog.treeFor(CreatureFamily.mystic).paths;
    expect(paths, hasLength(2));
    for (final path in paths) {
      final head = tester.getCenter(
        find.byKey(ValueKey('branch-head-${path.id}')),
      );
      for (final node in path.nodes) {
        final gem = tester.getCenter(
          find.byKey(ValueKey('mastery-node-${node.id}')),
        );
        expect(gem.dx, moreOrLessEquals(head.dx), reason: node.id);
      }
    }
  });

  testWidgets('shows the family\'s own mastery and prices in it', (
    tester,
  ) async {
    await mastery.addPoints(const {CreatureFamily.pip: 40});
    await pumpPanel(tester, manePoints: 120);

    expect(balance(tester), 'MANE MASTERY 120');
    // The dock's price, and the next node's on each of the two branches.
    expect(find.text('25 MASTERY'), findsNWidgets(3));

    await tester.tap(find.byKey(const ValueKey('mastery-family-pip')));
    await tester.pumpAndSettle();
    expect(balance(tester), 'PIP MASTERY 40');

    await tester.tap(find.byKey(const ValueKey('mastery-family-horn')));
    await tester.pumpAndSettle();
    expect(balance(tester), 'HORN MASTERY 0');
    expect(find.text('NEED'), findsOneWidget);
  });

  testWidgets('upgrade needs a second tap to confirm, then buys the node', (
    tester,
  ) async {
    await pumpPanel(tester, manePoints: 100);

    const nodeId = 'mane.resonance.measured_cuts';
    final button = find.byKey(const ValueKey('unlock-$nodeId'));
    expect(find.text('UPGRADE'), findsOneWidget);

    await tester.tap(button);
    await tester.pump();
    expect(find.text('TAP TO CONFIRM'), findsOneWidget);
    expect(mastery.isNodePurchased(nodeId), isFalse);

    await tester.tap(button);
    await settle(tester);

    expect(mastery.isNodePurchased(nodeId), isTrue);
    expect(
      mastery.selectedPathForFamily(CreatureFamily.mane),
      'mane.resonance',
    );
    expect(mastery.pointsFor(CreatureFamily.mane), 75);
    expect(balance(tester), 'MANE MASTERY 75');
    // The dock advances to the next tier of the same branch.
    expect(find.text('CROSSCUT'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('unlock-mane.resonance.crosscut')),
      findsOneWidget,
    );
  });

  testWidgets('an armed upgrade disarms when another node is focused', (
    tester,
  ) async {
    await pumpPanel(tester);

    await tester.tap(
      find.byKey(const ValueKey('unlock-mane.resonance.measured_cuts')),
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
    await pumpPanel(tester, manePoints: 10);

    expect(find.text('NEED'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('unlock-mane.resonance.measured_cuts')),
        matching: find.text('25 MASTERY'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('unlock-mane.resonance.measured_cuts')),
    );
    await tester.pump();
    expect(find.text('TAP TO CONFIRM'), findsNothing);

    final capstone = find.byKey(
      const ValueKey('mastery-node-mane.resonance.encore'),
    );
    await tester.tap(capstone);
    await tester.pump();
    expect(find.text('REQUIRES TEMPEST RING'), findsOneWidget);
    expect(find.text('CAPSTONE'), findsOneWidget);
  });

  testWidgets('tapping a locked branch\'s heading only shows it', (
    tester,
  ) async {
    await mastery.addPoints(const {CreatureFamily.mane: 25});
    await mastery.purchaseNode(
      family: CreatureFamily.mane,
      nodeId: 'mane.resonance.measured_cuts',
    );
    await pumpPanel(tester);

    await tester.tap(find.byKey(const ValueKey('branch-head-mane.limitless')));
    await settle(tester);
    expect(
      mastery.selectedPathForFamily(CreatureFamily.mane),
      'mane.resonance',
    );
    expect(find.text('FAR THROW'), findsNWidgets(2));
  });

  testWidgets('tapping a bought branch\'s heading equips it', (tester) async {
    await mastery.addPoints(const {CreatureFamily.mane: 50});
    await mastery.purchaseNode(
      family: CreatureFamily.mane,
      nodeId: 'mane.resonance.measured_cuts',
    );
    await mastery.purchaseNode(
      family: CreatureFamily.mane,
      nodeId: 'mane.limitless.far_throw',
    );
    await pumpPanel(tester);

    expect(
      mastery.selectedPathForFamily(CreatureFamily.mane),
      'mane.resonance',
    );
    expect(find.text('ACTIVE'), findsOneWidget);
    // Limitless is bought but not worn.
    expect(find.text('EQUIP'), findsOneWidget);

    // A bought one equips, and its next node comes into the dock.
    await tester.tap(find.byKey(const ValueKey('branch-head-mane.limitless')));
    await settle(tester);
    expect(
      mastery.selectedPathForFamily(CreatureFamily.mane),
      'mane.limitless',
    );
    expect(find.text("HUNTER'S ARC"), findsNWidgets(2));
    // War Rhythm is the one that now offers EQUIP.
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('EQUIP'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('branch-head-mane.resonance')),
        matching: find.text('EQUIP'),
      ),
      findsOneWidget,
    );
  });

  test('base-attack text describes only the basic attack', () {
    // The family rail shows this as what the family's attack does; specials
    // belong elsewhere.
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
          // The dock keeps room for the longest description, up to three
          // lines on a narrow phone.
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
