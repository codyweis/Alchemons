import 'dart:io';
import 'dart:ui' as ui;
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/components/survival_hud.dart'
    show HudTubePainter;
import 'package:alchemons/games/cosmic_survival/components/survival_party_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember member({String? image}) => CosmicPartyMember(
  instanceId: 'test',
  baseId: 'PIP01',
  displayName: 'Firepip',
  family: 'pip',
  element: 'Fire',
  level: 10,
  slotIndex: 0,
  statSpeed: 3,
  statIntelligence: 3,
  statStrength: 3,
  statBeauty: 3,
  staminaBars: 3,
  staminaMax: 3,
  imagePath: image,
);

void main() {
  setUpAll(() async {
    for (final entry in {
      'Preview': 'C:/Windows/Fonts/arial.ttf',
      'MaterialIcons':
          'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final file = File(entry.value);
      if (file.existsSync()) {
        await (FontLoader(entry.key)..addFont(
              Future.value(ByteData.view(file.readAsBytesSync().buffer)),
            ))
            .load();
      }
    }
  });
  test('deployed health and cooldown override stale recall values', () {
    final game = CosmicSurvivalGame(party: [member()], onGameOver: () {});
    game.companionHpFraction[0] = 0.9;
    game.companionSpecialCooldown[0] = 11;
    game.activeCompanions[0] = CosmicSurvivalCompanion(
      member: member(),
      position: Offset.zero,
      anchor: Offset.zero,
      maxHp: 100,
      currentHp: 25,
      physAtk: 10,
      elemAtk: 10,
      abilityAtk: 10,
      physDef: 10,
      elemDef: 10,
      specialCooldown: 4,
    );
    final state = SurvivalPartySlotState.fromGame(game, 0);
    expect(state.hp, 0.25);
    expect(state.cooldown, 4);
    expect(state.label, 'ACTIVE');
    game.tetheredCompanionSlot = 0;
    expect(SurvivalPartySlotState.fromGame(game, 0).label, 'FOLLOW');
  });

  test(
    'removed defeated companions stay down instead of becoming reserves',
    () {
      final game = CosmicSurvivalGame(party: [member()], onGameOver: () {});
      game.defeatedCompanionSlots.add(0);
      final state = SurvivalPartySlotState.fromGame(game, 0);
      expect(state.dead, isTrue);
      expect(state.active, isFalse);
      expect(state.hp, 0);
      expect(state.label, 'DOWN');
      game.defeatedCompanionSlots.clear();
      game.companionHpFraction[0] = 0;
      expect(SurvivalPartySlotState.fromGame(game, 0).dead, isTrue);
    },
  );

  testWidgets('dead slots cannot trigger deployment or recall', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Preview'),
        home: Scaffold(
          body: Center(
            child: SurvivalPartySlot(
              member: member(),
              state: const SurvivalPartySlotState(
                active: false,
                following: false,
                dead: true,
                hp: 0,
                cooldown: 0,
              ),
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(SurvivalPartySlot));
    expect(taps, 0);
    // The case shows its state in light and tubes; the words are in its
    // semantics.
    expect(find.bySemanticsLabel(RegExp(r'^Firepip, DOWN,')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'all deployment states and cooldowns remain separate and readable',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final boundary = GlobalKey();
      const states = [
        SurvivalPartySlotState(
          active: true,
          following: true,
          dead: false,
          hp: 0.85,
          cooldown: 3,
        ),
        SurvivalPartySlotState(
          active: true,
          following: false,
          dead: false,
          hp: 0.45,
          cooldown: 0,
        ),
        SurvivalPartySlotState(
          active: false,
          following: false,
          dead: false,
          hp: 0.9,
          cooldown: 8,
        ),
        SurvivalPartySlotState(
          active: false,
          following: false,
          dead: true,
          hp: 0,
          cooldown: 0,
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Preview'),
          home: Scaffold(
            backgroundColor: const Color(0xFF060A12),
            body: Center(
              child: RepaintBoundary(
                key: boundary,
                child: Container(
                  color: const Color(0xFF060A12),
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final state in states)
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: SurvivalPartySlot(
                            member: member(
                              image:
                                  'assets/images/creatures/uncommon/PIP01_firepip.png',
                            ),
                            state: state,
                            onTap: () {},
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage(
            'assets/images/creatures/uncommon/PIP01_firepip.png',
          ),
          tester.element(find.byType(SurvivalPartySlot).first),
        );
      });
      await tester.pumpAndSettle();
      for (final label in [
        'Firepip, FOLLOW, 85 percent health, special in 3 s',
        'Firepip, ACTIVE, 45 percent health, special ready',
        'Firepip, RESERVE, 90 percent health, special in 8 s',
        'Firepip, DOWN, 0 percent health',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      // The special's tube: full when ready, empty on a fresh cooldown.
      final fills = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<HudTubePainter>()
          .map((t) => t.fraction)
          .toList();
      expect(fills, contains(1.0));
      expect(tester.takeException(), isNull);
      semantics.dispose();
      final out = Platform.environment['ENEMY_SHEET_OUT'];
      if (out != null) {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage(pixelRatio: 3);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory(out).createSync(recursive: true);
          File(
            '$out/survival_party_states.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );

  SurvivalPartyEntry entry(int slot, {required bool out}) => SurvivalPartyEntry(
    slot: slot,
    member: member(),
    state: SurvivalPartySlotState(
      active: out,
      following: false,
      dead: false,
      hp: 1,
      cooldown: 2,
    ),
  );

  Future<List<int>> pumpRow(
    WidgetTester tester,
    List<SurvivalPartyEntry> entries,
  ) async {
    final tapped = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Preview'),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: SurvivalPartyRow(
              entries: entries,
              maxActive: 2,
              tethered: true,
              onTapSlot: tapped.add,
              onFollow: () {},
              wrap: (slot, child) => child,
            ),
          ),
        ),
      ),
    );
    return tapped;
  }

  testWidgets('a party of five shows every case, each in its own place', (
    tester,
  ) async {
    final tapped = await pumpRow(tester, [
      entry(0, out: true),
      entry(1, out: true),
      for (var i = 2; i < 5; i++) entry(i, out: false),
    ]);
    expect(find.byType(SurvivalPartySlot), findsNWidgets(5));
    expect(find.textContaining('+'), findsNothing);
    expect(find.text('FOLLOW'), findsOneWidget);
    await tester.tap(find.byType(SurvivalPartySlot).at(3));
    await tester.pumpAndSettle();
    expect(tapped, [3]);
    // Deploying from the bench does not move anyone.
    expect(find.byType(SurvivalPartySlot), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('only a squad of more than five folds its bench', (tester) async {
    final tapped = await pumpRow(tester, [
      entry(0, out: true),
      entry(1, out: true),
      for (var i = 2; i < 9; i++) entry(i, out: false),
    ]);
    expect(find.byType(SurvivalPartySlot), findsNWidgets(2));
    expect(find.text('+7'), findsOneWidget);
    await tester.tap(find.text('+7'));
    await tester.pumpAndSettle();
    expect(find.byType(SurvivalPartySlot), findsNWidgets(9));
    // The tray sits above the row: its first case is the first reserve.
    await tester.tap(find.byType(SurvivalPartySlot).first);
    await tester.pumpAndSettle();
    expect(tapped, [2]);
    expect(find.byType(SurvivalPartySlot), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
