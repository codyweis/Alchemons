// The leave-expedition dialog used to warn "your elemental cargo & shards will
// be lost" whatever the ship was carrying, with no amounts. Only two things in
// cosmic space are actually unbanked — the meter and the ship wallet — so these
// tests pin that the dialog names them with real numbers, and goes quiet
// instead of red when there is nothing to lose.

import 'package:alchemons/screens/cosmic/widgets/leave_expedition_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('loaded hold lists both losses with their amounts', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const LeaveExpeditionDialog(
          cargoUnits: 47.4,
          cargoBreakdown: {'Fire': 22.2, 'Water': 15.1, 'Earth': 10.1},
          unbankedShards: 240,
          bankedShards: 1204,
        ),
      ),
    );

    expect(find.text('THE HOLD IS STILL LOADED'), findsOneWidget);
    expect(find.text('240 unbanked Astral Shards'), findsOneWidget);
    expect(find.text('47 of 100 cargo units'), findsOneWidget);
    expect(find.text('Fire 22'), findsOneWidget);
    expect(find.text('Water 15'), findsOneWidget);
    expect(find.text('Earth 10'), findsOneWidget);
    expect(find.text('SPILLED INTO THE VOID'), findsOneWidget);
    // The vault balance is the proof that banked shards are untouched.
    expect(find.textContaining('1,204 shards'), findsOneWidget);
  });

  testWidgets('empty hold drops the warning entirely', (tester) async {
    await tester.pumpWidget(
      _host(
        const LeaveExpeditionDialog(
          cargoUnits: 0,
          cargoBreakdown: {},
          unbankedShards: 0,
          bankedShards: 1204,
        ),
      ),
    );

    expect(find.text('THE HOLD IS EMPTY'), findsOneWidget);
    expect(find.text('SPILLED INTO THE VOID'), findsNothing);
    expect(find.textContaining('Nothing is at risk.'), findsOneWidget);
  });

  testWidgets('without a home planet the hint says banking is impossible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const LeaveExpeditionDialog(
          cargoUnits: 12,
          cargoBreakdown: {'Fire': 12},
          unbankedShards: 5,
          bankedShards: null,
        ),
      ),
    );

    expect(
      find.textContaining('until you build a home planet'),
      findsOneWidget,
    );
    expect(find.textContaining('DEPOSIT ALL'), findsNothing);
  });
}
