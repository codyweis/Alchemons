// The Athanor screen's rules that matter outside the look: the odds sheet
// shows exactly what the service rolls on, gold pours are absent where they
// are off, a gold pour asks before it spends, and the free daily is a pour
// while there is something to pour for and a plain collect when there is
// not.

import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/screens/athanor/athanor_piece_art.dart';
import 'package:alchemons/screens/athanor/athanor_reveal.dart';
import 'package:alchemons/screens/athanor/athanor_screen.dart';
import 'package:alchemons/screens/athanor/athanor_tone.dart';
import 'package:alchemons/services/athanor_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

AthanorPiece _piece(String id, AthanorRarity r) => AthanorPiece(
  id: id,
  name: 'Piece $id',
  description: 'A piece.',
  kind: AthanorPieceKind.title,
  rarity: r,
  grantRef: id,
);

final _batch = AthanorBatch(
  id: 'b',
  name: 'Test Batch',
  description: 'For the test.',
  pieces: [
    _piece('c1', AthanorRarity.common),
    _piece('c2', AthanorRarity.common),
    _piece('r1', AthanorRarity.rare),
    _piece('e1', AthanorRarity.epic),
  ],
  capstone: _piece('cap', AthanorRarity.epic),
);

void main() {
  late AlchemonsDatabase db;

  Future<AthanorService> open(
    WidgetTester tester, {
    List<AthanorBatch>? batches,
    String country = 'US',
    int gold = 0,
    bool dailyTaken = false,
    bool introSeen = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late AthanorService svc;
    await tester.runAsync(() async {
      db = AlchemonsDatabase(NativeDatabase.memory());
      await db.settingsDao.setSetting(
        AthanorState.key,
        AthanorState(
          firstFire: true,
          dailyKey: dailyTaken ? '2026-10-10' : null,
        ).encode(),
      );
      final have = await db.currencyDao.getGoldBalance();
      await db.currencyDao.addGold(gold - have);
      await db.inventoryDao.addItemQty(InvKeys.athanorTincture, 40);
      if (introSeen) {
        await db.settingsDao.setSetting(kAthanorIntroSeenKey, '1');
      }
      svc = AthanorService(
        db,
        batches: batches ?? [_batch],
        random: Random(1),
        storefrontCountry: () async => country,
        clock: () => DateTime.utc(2026, 10, 10, 12),
      );
      await svc.load();
    });
    addTearDown(() => tester.runAsync(db.close));
    final theme = factionThemeFor(FactionId.volcanic);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AthanorService>.value(value: svc),
          Provider<FactionTheme>.value(value: theme),
        ],
        child: const MaterialApp(home: AthanorScreen()),
      ),
    );
    await settle(tester);
    return svc;
  }

  testWidgets('the odds sheet shows the service odds, to one decimal', (
    tester,
  ) async {
    final svc = await open(tester);
    await tester.tap(find.text('ODDS'));
    await settle(tester);
    final odds = svc.nextPourOdds(_batch.id);
    expect(odds, hasLength(4));
    for (final (piece, chance) in odds) {
      expect(find.text(piece.name), findsWidgets);
      expect(find.text(athanorPercent(chance)), findsWidgets);
    }
    // 10 + 10 + 5 + 2 = 27.
    expect(find.text('37.0%'), findsNWidgets(2));
    expect(find.text('18.5%'), findsOneWidget);
    expect(find.text('7.4%'), findsOneWidget);
    expect(
      find.text("Every pour gives a piece you don't own yet."),
      findsOneWidget,
    );
    expect(find.text('Comes with the last piece.'), findsOneWidget);
  });

  testWidgets('the first open explains how it works, once; the sparks '
      'balance explains it again', (tester) async {
    final svc = await open(tester, introSeen: false);
    await settle(tester);
    expect(find.text('THE FURNACE'), findsWidgets);
    expect(find.textContaining('Every pour gives a piece'), findsOneWidget);
    // Through its three pages: NEXT, NEXT, CONTINUE.
    for (final button in ['NEXT', 'NEXT', 'CONTINUE']) {
      await tester.tap(find.text(button).last);
      await settle(tester);
    }
    expect(find.textContaining('Every pour gives a piece'), findsNothing);
    expect(svc.introSeen, isTrue);

    await tester.tap(find.bySemanticsLabel(RegExp('How the Furnace works')));
    await settle(tester);
    expect(find.textContaining('Every pour gives a piece'), findsOneWidget);
  });

  testWidgets('no gold pour where gold pours are off', (tester) async {
    await open(tester, country: 'BE', gold: 500);
    expect(
      find.bySemanticsLabel('POUR · $kAthanorTincturePerPour SPARKS'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('POUR · 50 GOLD'), findsNothing);
  });

  testWidgets('a paid pour is held: a tap or an early let-go spends '
      'nothing, a full hold pours', (tester) async {
    final svc = await open(tester, gold: 500, dailyTaken: true);
    expect(find.text('FREE POUR'), findsNothing);
    final gold = find.bySemanticsLabel('POUR · 50 GOLD');

    await tester.tap(gold);
    await settle(tester);
    final early = await tester.startGesture(tester.getCenter(gold));
    await tester.pump(const Duration(milliseconds: 400));
    await early.up();
    await settle(tester);
    expect(svc.gold, 500);
    expect(svc.drawnIn(_batch.id), isEmpty);

    await holdPour(tester, gold);
    for (var i = 0; i < 40 && svc.drawnIn(_batch.id).isEmpty; i++) {
      await settle(tester);
    }
    expect(svc.drawnIn(_batch.id), hasLength(1));
    expect(svc.gold, 500 - kAthanorGoldPerPour);
  });

  testWidgets('the free daily: a pour, or a collect with nothing to pour for', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('FREE POUR'), findsOneWidget);
    expect(find.text('COLLECT DAILY'), findsNothing);

    await open(tester, batches: const []);
    expect(find.text('No batches yet'), findsOneWidget);
    expect(find.text('COLLECT DAILY'), findsOneWidget);
    expect(find.text('FREE POUR'), findsNothing);
  });

  testWidgets('a pour shows nothing of its draw until CONTINUE', (
    tester,
  ) async {
    final svc = await open(tester, dailyTaken: true);
    // The tile of a piece, as the panel shows it (the reveal's own look of
    // the drawn piece is the animated one).
    Finder tile(String id, AthanorPieceLook look) => find.byWidgetPredicate(
      (w) =>
          w is AthanorPieceArt &&
          !w.animate &&
          w.piece.id == id &&
          w.look == look,
    );
    AthanorReveal? reveal() {
      final f = find.byType(AthanorRevealView);
      return f.evaluate().isEmpty
          ? null
          : tester.widget<AthanorRevealView>(f).reveal;
    }

    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (i.isEven) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
        }
      }
    }

    expect(find.text('4 OF 4 LEFT'), findsOneWidget);
    await holdPour(
      tester,
      find.bySemanticsLabel('POUR · $kAthanorTincturePerPour SPARKS'),
    );
    // The pour's transaction is done within a few frames.
    for (var i = 0; i < 40 && svc.drawnIn(_batch.id).isEmpty; i++) {
      await frames(1);
    }
    final drawn = svc.drawnIn(_batch.id).single;

    // Through every beat to its rest, the panel still shows the batch as
    // it was: the drawn piece a ghost, nothing fewer left; only the paid
    // tincture has left the balance.
    var beats = 0;
    for (var i = 0; i < 400 && !(reveal()?.atRest ?? false); i++) {
      await frames(1);
      if (i % 10 == 0) {
        expect(tile(drawn, AthanorPieceLook.lit), findsNothing);
        expect(tile(drawn, AthanorPieceLook.ghost), findsOneWidget);
        expect(find.text('4 OF 4 LEFT'), findsOneWidget);
        expect(find.text('3 OF 4 LEFT'), findsNothing);
        beats++;
      }
    }
    expect(reveal()?.atRest, isTrue);
    expect(beats, greaterThan(5));
    expect(tile(drawn, AthanorPieceLook.lit), findsNothing);
    expect(find.text('${40 - kAthanorTincturePerPour}'), findsOneWidget);

    await tester.tap(find.text('CONTINUE'));
    await frames(40);
    expect(reveal(), isNull);
    expect(tile(drawn, AthanorPieceLook.lit), findsOneWidget);
    expect(tile(drawn, AthanorPieceLook.ghost), findsNothing);
    expect(find.text('3 OF 4 LEFT'), findsOneWidget);
  });
}

/// The furnace never stops burning: frames, with real time let through for
/// the database.
/// Presses [button] and holds it until the pour goes (it fills in 0.85 s).
Future<void> holdPour(WidgetTester tester, Finder button) async {
  final g = await tester.startGesture(tester.getCenter(button));
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await g.up();
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}
